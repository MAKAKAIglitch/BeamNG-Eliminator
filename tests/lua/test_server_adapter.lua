-- Integration-adapter tests with a mocked BeamMP API.
-- This verifies registration and adapter behavior, not a live BeamMP server.

package.path = "./server-plugin/?.lua;./server-plugin/?/init.lua;" .. package.path

local registered = {}
local sent_events = {}
local chat_messages = {}
local player_names = {
    [7] = "Driver Seven",
    [8] = "Driver Eight",
    [9] = "Late Spectator"
}
local timer_intervals = {}
local cancelled_timers = {}
local fake_time = 1000
local original_os_time = os.time
os.time = function()
    return fake_time
end

MP = {
    RegisterEvent = function(event_name, function_name)
        registered[event_name] = function_name
    end,
    GetPlayerName = function(player_id)
        return player_names[player_id] or ("Player " .. tostring(player_id))
    end,
    SendChatMessage = function(player_id, message)
        chat_messages[#chat_messages + 1] = {
            player_id = player_id,
            message = message
        }
    end,
    TriggerClientEventJson = function(player_id, event_name, envelope)
        sent_events[#sent_events + 1] = {
            player_id = player_id,
            event_name = event_name,
            envelope = envelope
        }
        return true, nil
    end,
    CreateEventTimer = function(event_name, interval_ms)
        timer_intervals[event_name] = interval_ms
    end,
    CancelEventTimer = function(event_name)
        cancelled_timers[event_name] = true
    end
}

local function expect(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

dofile("server-plugin/main.lua")
expect(type(onInit) == "function", "plugin must expose onInit")
expect(type(onShutdown) == "function", "plugin must expose onShutdown")
onInit()

expect(registered.onPlayerJoin == "onEliminatorPlayerJoin",
    "player join event should be registered")
expect(registered.onPlayerDisconnect == "onEliminatorPlayerDisconnect",
    "player disconnect event should be registered")
expect(registered["eliminator:request_snapshot"] == "onEliminatorSnapshotRequest",
    "client snapshot request event should be registered")
expect(registered.onConsoleInput == "onEliminatorConsoleInput",
    "console command event should be registered")
expect(registered.onChatMessage == "onEliminatorChatMessage",
    "chat status command event should be registered")
expect(registered.EliminatorCountdownTick == "onEliminatorCountdownTick",
    "countdown timer event should be registered")

local before_invalid_snapshot_request = #sent_events
onEliminatorSnapshotRequest(9, "not-a-valid-request")
expect(#sent_events == before_invalid_snapshot_request,
    "invalid snapshot request payload must be ignored")
onEliminatorSnapshotRequest(7,
    '{"type":"match.snapshot.request","version":1,"request_id":"lobby-ui","payload":{}}')
expect(sent_events[#sent_events].player_id == 7,
    "snapshot request must reply only to the requesting player")
expect(sent_events[#sent_events].event_name == "eliminator:match_snapshot",
    "snapshot request must use the normal snapshot event")
expect(sent_events[#sent_events].envelope.type == "match.snapshot",
    "snapshot request response must use the snapshot envelope")
local snapshot_response_count = #sent_events
onEliminatorSnapshotRequest(7,
    '{"type":"match.snapshot.request","version":1,"request_id":"lobby-ui","payload":{}}')
expect(#sent_events == snapshot_response_count,
    "snapshot requests should be rate-limited per player")
fake_time = fake_time + 1
onEliminatorSnapshotRequest(7,
    '{"type":"match.snapshot.request","version":1,"request_id":"lobby-ui","payload":{}}')
expect(#sent_events == snapshot_response_count + 1,
    "a new snapshot request should be allowed after the rate limit expires")

onEliminatorPlayerJoin(7)
onEliminatorPlayerJoin(8)
expect(#sent_events >= 2, "joining players should trigger state broadcasts")
expect(sent_events[#sent_events].event_name == "eliminator:match_snapshot",
    "server should broadcast match snapshots")
expect(sent_events[#sent_events].envelope.type == "match.snapshot",
    "snapshot must use the versioned protocol envelope")
expect(sent_events[#sent_events].envelope.version == 1,
    "snapshot protocol version should be 1")
expect(type(sent_events[#sent_events].envelope.request_id) == "string",
    "snapshot should include a unique server event ID")
expect(#sent_events[#sent_events].envelope.payload.competitors == 20,
    "snapshot should expose all twenty roster slots")

local status = onEliminatorConsoleInput("eliminator status")
expect(type(status) == "string" and status:find("phase=lobby", 1, true),
    "console status should report lobby phase")

local start_result = onEliminatorConsoleInput("eliminator start")
expect(type(start_result) == "string" and start_result:find("countdown started", 1, true),
    "console start should lock roster and start countdown")
expect(timer_intervals.EliminatorCountdownTick == 1000,
    "countdown timer should tick once per second")

for _ = 1, 10 do
    onEliminatorCountdownTick()
end

local active_status = onEliminatorConsoleInput("eliminator status")
expect(active_status:find("phase=active", 1, true),
    "countdown should transition the match to active")
expect(cancelled_timers.EliminatorCountdownTick,
    "countdown timer should be cancelled after reaching zero")

onEliminatorPlayerJoin(9)
expect(sent_events[#sent_events].envelope.payload.spectators[1].player_id == "player:9",
    "late joiner should be represented as a spectator")

onEliminatorPlayerDisconnect(7)
expect(sent_events[#sent_events].envelope.payload.competitors[1].connection_status
    == "disconnected", "disconnect should be broadcast without eliminating competitor")

local chat_result = onEliminatorChatMessage(8, "Driver Eight", "!eliminator")
expect(chat_result == 1, "status chat command should be hidden from public chat")

local stop_result = onEliminatorConsoleInput("eliminator stop")
expect(type(stop_result) == "string" and stop_result:find("stopped", 1, true),
    "console stop should stop the match")
expect(sent_events[#sent_events].envelope.payload.phase == "stopped",
    "stopped phase should be broadcast")

local new_lobby = onEliminatorConsoleInput("eliminator lobby")
expect(type(new_lobby) == "string" and new_lobby:find("Lobby created", 1, true),
    "server should be able to create the next lobby")
onEliminatorPlayerJoin(8)
local second_start = onEliminatorConsoleInput("eliminator start")
expect(type(second_start) == "string" and second_start:find("countdown started", 1, true),
    "second lobby should start countdown")
onEliminatorPlayerDisconnect(8)
onEliminatorCountdownTick()
local aborted_status = onEliminatorConsoleInput("eliminator status")
expect(aborted_status:find("phase=lobby", 1, true),
    "disconnect during countdown should abort back to lobby")
expect(sent_events[#sent_events].envelope.payload.roster_locked == false,
    "aborted countdown should unlock the roster")
expect(sent_events[#sent_events].envelope.payload.competitors[2].status == "vacant",
    "aborted countdown should clear generated AI placeholders")

onShutdown()
os.time = original_os_time

print("PASS: BeamMP adapter (events, console commands, countdown, snapshots, disconnect)")

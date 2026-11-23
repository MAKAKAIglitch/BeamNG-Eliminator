-- BeamNG Eliminator - BeamMP server plugin entry point.
-- Tested against the documented BeamMP Server 3.x event model.
-- Runtime integration still requires a live server smoke test.

local MatchManager = require("modules.match_manager")

local PROTOCOL_VERSION = 1
local SNAPSHOT_EVENT = "eliminator:match_snapshot"
local COUNTDOWN_EVENT = "eliminator:match_countdown"
local COUNTDOWN_SECONDS = 10

local match_sequence = 0
local countdown_remaining = nil
local countdown_timer_running = false

local function cancel_countdown()
    if countdown_timer_running and MP and MP.CancelEventTimer then
        MP.CancelEventTimer("EliminatorCountdownTick")
    end
    countdown_timer_running = false
    countdown_remaining = nil
end

local function send_event(player_id, event_name, envelope)
    if not MP then
        return false, "beammp_api_unavailable"
    end

    if type(MP.TriggerClientEventJson) == "function" then
        local ok, result, err = pcall(
            MP.TriggerClientEventJson,
            player_id,
            event_name,
            envelope
        )
        if not ok then
            return false, tostring(result)
        end
        return result, err
    end

    if type(MP.TriggerClientEvent) == "function"
        and Util and type(Util.JsonEncode) == "function" then
        local encoded = Util.JsonEncode(envelope)
        return MP.TriggerClientEvent(player_id, event_name, encoded)
    end

    return false, "no_supported_json_event_transport"
end

local function broadcast_snapshot()
    local envelope = {
        type = "match.snapshot",
        version = PROTOCOL_VERSION,
        payload = MatchManager.snapshot()
    }
    local ok, err = send_event(-1, SNAPSHOT_EVENT, envelope)
    if not ok then
        print("[BeamNG Eliminator] Snapshot broadcast failed: " .. tostring(err))
    end
    return ok
end

local function send_countdown(remaining)
    local envelope = {
        type = "match.countdown",
        version = PROTOCOL_VERSION,
        payload = {
            remaining_seconds = remaining,
            phase = MatchManager.snapshot().phase
        }
    }
    local ok, err = send_event(-1, COUNTDOWN_EVENT, envelope)
    if not ok then
        print("[BeamNG Eliminator] Countdown broadcast failed: " .. tostring(err))
    end
    return ok
end

local function has_disconnected_human(snapshot)
    for _, competitor in ipairs(snapshot.competitors) do
        if competitor.kind == "human"
            and competitor.status == "active"
            and competitor.connection_status == "disconnected" then
            return true
        end
    end
    return false
end

local function start_lobby()
    match_sequence = match_sequence + 1
    local match_id = "match-" .. tostring(os.time()) .. "-" .. tostring(match_sequence)
    return MatchManager.create_lobby(match_id)
end

function onEliminatorPlayerJoin(player_id)
    local phase = MatchManager.snapshot().phase
    if phase == MatchManager.PHASE.WAITING
        or phase == MatchManager.PHASE.FINISHED
        or phase == MatchManager.PHASE.STOPPED then
        local created, create_result = start_lobby()
        if not created then
            print("[BeamNG Eliminator] Could not create lobby: " .. tostring(create_result))
            return
        end
    end

    local player_name = MP.GetPlayerName(player_id)
    local ok, result = MatchManager.add_player(player_id, player_name)
    if not ok then
        MP.SendChatMessage(player_id,
            "[Eliminator] Could not join the current match: " .. tostring(result))
        return
    end

    if result.role == "spectator" then
        MP.SendChatMessage(player_id,
            "[Eliminator] Match already started. You joined as a spectator.")
    elseif result.reconnected then
        MP.SendChatMessage(player_id,
            "[Eliminator] Reconnected to your existing match slot.")
    else
        MP.SendChatMessage(player_id,
            "[Eliminator] You joined the lobby in slot " .. tostring(result.slot) .. ".")
    end

    broadcast_snapshot()
end

function onEliminatorPlayerDisconnect(player_id)
    local ok, result = MatchManager.disconnect_player(player_id)
    if ok then
        print("[BeamNG Eliminator] Player disconnected from " .. result.role
            .. " slot/state: " .. tostring(result.competitor_id))
        broadcast_snapshot()
    end
end

function onEliminatorCountdownTick()
    if countdown_remaining == nil then
        cancel_countdown()
        return
    end

    local snapshot = MatchManager.snapshot()
    if snapshot.phase ~= MatchManager.PHASE.STARTING then
        cancel_countdown()
        return
    end

    if has_disconnected_human(snapshot) then
        cancel_countdown()
        local aborted, abort_result =
            MatchManager.abort_starting("human_disconnected_during_countdown")
        if aborted then
            broadcast_snapshot()
            MP.SendChatMessage(-1,
                "[Eliminator] Countdown cancelled: a competitor disconnected. Reconnect and start again.")
            print("[BeamNG Eliminator] Countdown aborted because a human competitor disconnected.")
        else
            print("[BeamNG Eliminator] Could not abort countdown: " .. tostring(abort_result))
        end
        return
    end

    countdown_remaining = countdown_remaining - 1
    if countdown_remaining > 0 then
        send_countdown(countdown_remaining)
        return
    end

    cancel_countdown()
    local ok, reason = MatchManager.start_match()
    if not ok then
        print("[BeamNG Eliminator] Countdown could not start match: " .. tostring(reason))
        broadcast_snapshot()
        return
    end

    broadcast_snapshot()
    MP.SendChatMessage(-1, "[Eliminator] The match has started!")
    print("[BeamNG Eliminator] Match is now active.")
end

function onEliminatorConsoleInput(input)
    if type(input) ~= "string" then
        return nil
    end

    local command = input:match("^%s*(.-)%s*$")
    if command == "eliminator" or command == "eliminator help" then
        return "Commands: eliminator status | eliminator start | eliminator stop | eliminator lobby"
    end

    if command == "eliminator status" then
        local snapshot = MatchManager.snapshot()
        return "[Eliminator] phase=" .. snapshot.phase
            .. ", active=" .. tostring(snapshot.active_competitors)
            .. ", spectators=" .. tostring(#snapshot.spectators)
            .. ", match=" .. tostring(snapshot.match_id)
    end

    if command == "eliminator lobby" then
        local ok, result = start_lobby()
        if not ok then
            return "[Eliminator] Cannot create lobby: " .. tostring(result)
        end
        broadcast_snapshot()
        return "[Eliminator] Lobby created: " .. tostring(result.match_id)
    end

    if command == "eliminator start" then
        local ok, result = MatchManager.lock_roster()
        if not ok then
            return "[Eliminator] Cannot start: " .. tostring(result)
        end

        cancel_countdown()
        countdown_remaining = COUNTDOWN_SECONDS
        countdown_timer_running = true
        MP.CreateEventTimer("EliminatorCountdownTick", 1000)
        broadcast_snapshot()
        send_countdown(countdown_remaining)
        MP.SendChatMessage(-1,
            "[Eliminator] Roster locked. Match starts in " .. COUNTDOWN_SECONDS .. " seconds.")
        return "[Eliminator] Roster locked; countdown started."
    end

    if command == "eliminator stop" then
        cancel_countdown()
        local ok, reason = MatchManager.stop("server_console")
        if not ok then
            return "[Eliminator] Cannot stop: " .. tostring(reason)
        end
        broadcast_snapshot()
        MP.SendChatMessage(-1, "[Eliminator] The current match was stopped by the server.")
        return "[Eliminator] Match stopped."
    end

    return nil
end

function onEliminatorChatMessage(player_id, player_name, message)
    if type(message) ~= "string" then
        return
    end

    if string.lower(message) == "!eliminator" then
        local snapshot = MatchManager.snapshot()
        MP.SendChatMessage(player_id,
            "[Eliminator] phase=" .. snapshot.phase
            .. ", active competitors=" .. tostring(snapshot.active_competitors)
            .. ", spectators=" .. tostring(#snapshot.spectators))
        return 1
    end
end

function onInit()
    local initialized, reason = MatchManager.initialize()
    if not initialized then
        error("[BeamNG Eliminator] Initialization failed: " .. tostring(reason))
    end

    MP.RegisterEvent("onPlayerJoin", "onEliminatorPlayerJoin")
    MP.RegisterEvent("onPlayerDisconnect", "onEliminatorPlayerDisconnect")
    MP.RegisterEvent("onConsoleInput", "onEliminatorConsoleInput")
    MP.RegisterEvent("onChatMessage", "onEliminatorChatMessage")
    MP.RegisterEvent("EliminatorCountdownTick", "onEliminatorCountdownTick")

    print("[BeamNG Eliminator] Server plugin initialized; awaiting players.")
end

function onShutdown()
    cancel_countdown()
    MatchManager.shutdown()
    print("[BeamNG Eliminator] Server plugin stopped.")
end

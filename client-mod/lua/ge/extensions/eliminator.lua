-- BeamNG Eliminator client extension.
-- Receives authoritative match snapshots from the BeamMP server and forwards
-- them to the native BeamNG UI app through guihooks.

local M = {}

local extension_loaded = false
local latest_snapshot = nil
local countdown_seconds = nil

local SNAPSHOT_REQUEST_EVENT = "eliminator:request_snapshot"
local SNAPSHOT_REQUEST_DATA =
    '{"type":"match.snapshot.request","version":1,"request_id":"lobby-ui","payload":{}}'
local LOBBY_ACTION_EVENT = "eliminator:lobby_action"
local READY_ON_DATA = '{"type":"lobby.ready","version":1,"request_id":"lobby-ui","payload":{"ready":true}}'
local READY_OFF_DATA = '{"type":"lobby.ready","version":1,"request_id":"lobby-ui","payload":{"ready":false}}'
local SPAWN_REGION_DATA = {
    north = '{"type":"spawn.select","version":1,"request_id":"lobby-ui","payload":{"region":"north"}}',
    east = '{"type":"spawn.select","version":1,"request_id":"lobby-ui","payload":{"region":"east"}}',
    south = '{"type":"spawn.select","version":1,"request_id":"lobby-ui","payload":{"region":"south"}}',
    west = '{"type":"spawn.select","version":1,"request_id":"lobby-ui","payload":{"region":"west"}}'
}
local local_competitor_id = nil

local function publish_ui_update()
    if type(guihooks) == "table" and type(guihooks.trigger) == "function" then
        guihooks.trigger("EliminatorLobbyUpdate", {
            snapshot = latest_snapshot,
            countdown_seconds = countdown_seconds
        })
    end
end

local function decode_envelope(raw_data, expected_type)
    if type(raw_data) ~= "string" or type(jsonDecode) ~= "function" then
        return nil
    end

    local ok, envelope = pcall(jsonDecode, raw_data)
    if not ok or type(envelope) ~= "table" then
        return nil
    end
    if envelope.version ~= 1 or envelope.type ~= expected_type then
        return nil
    end
    if type(envelope.payload) ~= "table" then
        return nil
    end
    return envelope.payload
end

local function onMatchSnapshot(raw_data)
    local snapshot = decode_envelope(raw_data, "match.snapshot")
    if not snapshot then
        log("W", "BeamNGEliminator", "Ignored invalid match snapshot.")
        return
    end

    if type(snapshot.local_competitor_id) == "string" then
        local_competitor_id = snapshot.local_competitor_id
    elseif local_competitor_id then
        snapshot.local_competitor_id = local_competitor_id
    end
    latest_snapshot = snapshot
    if snapshot.phase ~= "starting" then
        countdown_seconds = nil
    end
    publish_ui_update()

    log("I", "BeamNGEliminator",
        "Match state updated: " .. tostring(snapshot.phase)
        .. ", active competitors: " .. tostring(snapshot.active_competitors))
end

local function onMatchCountdown(raw_data)
    local countdown = decode_envelope(raw_data, "match.countdown")
    if not countdown or type(countdown.remaining_seconds) ~= "number" then
        log("W", "BeamNGEliminator", "Ignored invalid match countdown.")
        return
    end

    countdown_seconds = countdown.remaining_seconds
    publish_ui_update()
    log("I", "BeamNGEliminator",
        "Match starts in " .. tostring(countdown_seconds) .. " seconds.")
end

local function request_server_snapshot()
    if type(TriggerServerEvent) == "function" then
        TriggerServerEvent(SNAPSHOT_REQUEST_EVENT, SNAPSHOT_REQUEST_DATA)
    end
end

local function requestLobbySnapshot()
    publish_ui_update()
    request_server_snapshot()
end

local function send_lobby_action(data)
    if type(data) == "string" and type(TriggerServerEvent) == "function" then
        TriggerServerEvent(LOBBY_ACTION_EVENT, data)
    end
end
local function setReady(ready)
    if ready == true then send_lobby_action(READY_ON_DATA)
    elseif ready == false then send_lobby_action(READY_OFF_DATA) end
end
local function selectSpawnRegion(region)
    local data = SPAWN_REGION_DATA[region]
    if data then send_lobby_action(data) end
end

function M.onExtensionLoaded()
    extension_loaded = true
    if type(AddEventHandler) == "function" then
        AddEventHandler("eliminator:match_snapshot", onMatchSnapshot)
        AddEventHandler("eliminator:match_countdown", onMatchCountdown)
    end
    log("I", "BeamNGEliminator", "Client extension loaded.")
    publish_ui_update()
    request_server_snapshot()
end

function M.onExtensionUnloaded()
    if type(RemoveEventHandler) == "function" then
        RemoveEventHandler("eliminator:match_snapshot")
        RemoveEventHandler("eliminator:match_countdown")
    end
    extension_loaded = false
    latest_snapshot = nil
    countdown_seconds = nil
    local_competitor_id = nil
    publish_ui_update()
    log("I", "BeamNGEliminator", "Client extension unloaded.")
end

function M.isLoaded()
    return extension_loaded
end

function M.getMatchSnapshot()
    return latest_snapshot
end

function M.getCountdown()
    return countdown_seconds
end

M.requestLobbySnapshot = requestLobbySnapshot
M.setReady = setReady
M.selectSpawnRegion = selectSpawnRegion

return M

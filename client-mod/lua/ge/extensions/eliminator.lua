-- BeamNG Eliminator client extension.
-- Receives authoritative match snapshots from the BeamMP server.
-- Gameplay UI, vehicle control and AI synchronization are separate milestones.

local M = {}

local extension_loaded = false
local latest_snapshot = nil
local countdown_seconds = nil

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

    latest_snapshot = snapshot
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
    log("I", "BeamNGEliminator",
        "Match starts in " .. tostring(countdown_seconds) .. " seconds.")
end

function M.onExtensionLoaded()
    extension_loaded = true
    if type(AddEventHandler) == "function" then
        AddEventHandler("eliminator:match_snapshot", onMatchSnapshot)
        AddEventHandler("eliminator:match_countdown", onMatchCountdown)
    end
    log("I", "BeamNGEliminator", "Client extension loaded.")
end

function M.onExtensionUnloaded()
    if type(RemoveEventHandler) == "function" then
        RemoveEventHandler("eliminator:match_snapshot")
        RemoveEventHandler("eliminator:match_countdown")
    end
    extension_loaded = false
    latest_snapshot = nil
    countdown_seconds = nil
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

return M

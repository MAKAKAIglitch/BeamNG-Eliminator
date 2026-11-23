local registered_handlers = {}
local ui_events = {}
local log_messages = {}

function AddEventHandler(name, callback)
    registered_handlers[name] = callback
end

function RemoveEventHandler(name)
    registered_handlers[name] = nil
end

function jsonDecode(raw_data)
    if raw_data == "snapshot" then
        return {
            version = 1,
            type = "match.snapshot",
            payload = {
                phase = "lobby",
                active_competitors = 2,
                competitors = {},
                spectators = {},
                roster_locked = false
            }
        }
    end
    if raw_data == "countdown" then
        return {
            version = 1,
            type = "match.countdown",
            payload = {
                remaining_seconds = 7
            }
        }
    end
    if raw_data == "invalid" then
        return {
            version = 2,
            type = "match.snapshot",
            payload = {}
        }
    end
    error("unexpected test payload")
end

guihooks = {
    trigger = function(event_name, payload)
        ui_events[#ui_events + 1] = {
            name = event_name,
            payload = payload
        }
    end
}

function log(level, tag, message)
    log_messages[#log_messages + 1] = {
        level = level,
        tag = tag,
        message = message
    }
end

local Extension = dofile("client-mod/lua/ge/extensions/eliminator.lua")

assert(type(Extension) == "table")
Extension.onExtensionLoaded()
assert(Extension.isLoaded())
assert(type(registered_handlers["eliminator:match_snapshot"]) == "function")
assert(type(registered_handlers["eliminator:match_countdown"]) == "function")

registered_handlers["eliminator:match_snapshot"]("snapshot")
assert(type(Extension.getMatchSnapshot()) == "table")
assert(Extension.getMatchSnapshot().phase == "lobby")
assert(ui_events[#ui_events].name == "EliminatorLobbyUpdate")
assert(ui_events[#ui_events].payload.snapshot.phase == "lobby")

registered_handlers["eliminator:match_countdown"]("countdown")
assert(Extension.getCountdown() == 7)
assert(ui_events[#ui_events].payload.countdown_seconds == 7)

Extension.requestLobbySnapshot()
assert(ui_events[#ui_events].payload.snapshot.phase == "lobby")
assert(ui_events[#ui_events].payload.countdown_seconds == 7)

registered_handlers["eliminator:match_snapshot"]("invalid")
assert(Extension.getMatchSnapshot().phase == "lobby")

Extension.onExtensionUnloaded()
assert(not Extension.isLoaded())
assert(Extension.getMatchSnapshot() == nil)
assert(Extension.getCountdown() == nil)
assert(registered_handlers["eliminator:match_snapshot"] == nil)
assert(registered_handlers["eliminator:match_countdown"] == nil)
assert(ui_events[#ui_events].payload.snapshot == nil)
assert(ui_events[#ui_events].payload.countdown_seconds == nil)

print("Client extension UI bridge tests passed.")

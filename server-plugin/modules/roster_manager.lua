-- Tracks the target competitor roster.
-- This module is pure Lua and does not assume a server-side AI vehicle API.

local RosterManager = {}

RosterManager.CAPACITY = 20

function RosterManager.create_empty_roster()
    local roster = {}
    for slot = 1, RosterManager.CAPACITY do
        roster[slot] = {
            slot = slot,
            kind = "empty",
            status = "vacant",
            competitor_id = nil
        }
    end
    return roster
end

return RosterManager

-- AI competitor prototype boundary.
-- This module intentionally does not spawn vehicles or issue driving commands.
-- First prove one AI vehicle can be controlled and observed consistently by
-- two clients before implementing roster-scale AI behaviour.

local M = {}

function M.getPrototypeStatus()
    return {
        implemented = false,
        reason = "Awaiting BeamNG vehicle-control and BeamMP synchronization prototype."
    }
end

return M

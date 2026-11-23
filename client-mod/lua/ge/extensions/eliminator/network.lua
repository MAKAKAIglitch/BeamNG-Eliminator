-- Client-side network boundary.
-- BeamMP event registration and payload handling will be added after the
-- shared protocol has been validated against a real server/client session.

local M = {}

M.PROTOCOL_VERSION = 1

function M.isSupportedProtocol(version)
    return version == M.PROTOCOL_VERSION
end

return M

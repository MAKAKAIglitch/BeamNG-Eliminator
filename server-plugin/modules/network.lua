-- Network boundary for future server/client messages.
-- Wire this module to BeamMP's documented TriggerClientEvent APIs only after
-- the protocol and exact target server signatures have been tested.

local Network = {}

Network.PROTOCOL_VERSION = 1

function Network.is_supported_protocol(version)
    return version == Network.PROTOCOL_VERSION
end

return Network

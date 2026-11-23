-- BeamNG Eliminator - BeamMP server plugin entry point.
-- Keep this as the only Lua file in the plugin root.
-- Gameplay systems are intentionally not started until their API contracts
-- and lifecycle have been verified against the target BeamMP Server build.

local MatchManager = require("modules.match_manager")

local Plugin = {}

function Plugin.init()
    MatchManager.initialize()
    print("[BeamNG Eliminator] Server plugin scaffold loaded.")
end

function Plugin.shutdown()
    MatchManager.shutdown()
    print("[BeamNG Eliminator] Server plugin scaffold stopped.")
end

-- BeamMP lifecycle hooks and module-loading behaviour must be confirmed
-- against the exact server version before wiring these functions globally.
return Plugin

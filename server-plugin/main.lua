-- BeamNG Eliminator - BeamMP server plugin entry point.
-- BeamMP loads root-level Lua files and calls the registered global lifecycle
-- functions. Keep reusable modules under modules/ and load them explicitly.

local MatchManager = require("modules.match_manager")

function onInit()
    MatchManager.initialize()
    print("[BeamNG Eliminator] Server plugin scaffold loaded.")
end

function onShutdown()
    MatchManager.shutdown()
    print("[BeamNG Eliminator] Server plugin scaffold stopped.")
end

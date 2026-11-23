-- BeamNG Eliminator client extension scaffold.
-- Loaded as a GE extension from lua/ge/extensions/eliminator/main.lua.
-- No gameplay or network API is invoked until verified in-game.

local M = {}

local extension_loaded = false

function M.onExtensionLoaded()
    extension_loaded = true
    log("I", "BeamNGEliminator", "Client extension scaffold loaded.")
end

function M.onExtensionUnloaded()
    extension_loaded = false
    log("I", "BeamNGEliminator", "Client extension scaffold unloaded.")
end

function M.isLoaded()
    return extension_loaded
end

return M

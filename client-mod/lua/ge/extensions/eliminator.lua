-- BeamNG Eliminator client extension.
-- Loaded by scripts/modScript.lua through load("eliminator").
-- Gameplay and BeamMP networking remain unimplemented in this foundation release.

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

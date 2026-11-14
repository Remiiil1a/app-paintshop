-- Session lifecycle: starting and finishing an editing session.
--
-- Everything created while a mesh is selected belongs to the session and is released here.
-- Missing one of these is what made the previous version keep stale canvases and geometry
-- shots bound to the previous mesh.

local M = {}

---@param env table
---@param S table
---@param canvas table core/canvas.lua
---@param history table core/history.lua
---@param camera table core/camera.lua
---@param projection table core/projection.lua
---@param masking table core/masking.lua
function M.init(env, S, canvas, history, camera, projection, masking)
    M.env, M.S, M.canvas, M.history, M.camera, M.projection, M.masking =
        env, S, canvas, history, camera, projection, masking
    M.disposeToolResources = nil ---@type function?
end

---Registers the callback that frees per-tool resources. Set by the tool registry.
---@param fn function
function M.setToolDisposer(fn)
    M.disposeToolResources = fn
end

---Releases every resource that belongs to one editing session.
function M.releaseResources()
    local S = M.S
    if M.disposeToolResources then
        M.disposeToolResources()
    end
    if S.carPreview then
        S.carPreview:dispose()
        S.carPreview = nil
    end
    M.projection.dispose()
    M.canvas.disposeAll()
    M.masking.reset()

    S.lastRay = nil
    S.smoothRayDir = nil
    S.brushDistance = 1
    S.drawing = false
    S.ignoreMousePress = true
end

---Ends the current session and restores the car's original texture.
function M.finish()
    local S = M.S
    if S.selectedMeshes then
        S.selectedMeshes:setMaterialTexture('txDiffuse', S.carTexture):setMotionStencil(M.env.taaFix.Off)
    end
    S.selectedMeshes = nil
    S.carTexture = nil
    S.aoTexture = nil
    S.saveFilename = nil
    S.changesMade = 0
    M.history.clear()
    M.releaseResources()
    M.camera.release()
    ac.setWindowTitle('paintshop', nil)
end

return M

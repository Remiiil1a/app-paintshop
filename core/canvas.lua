-- Canvas lifecycle. The editing, AO and masking canvases are created together and destroyed
-- together, and they must all share `env.texSize`: the masking canvas is sampled through the
-- editing canvas' UVs, so a size mismatch shifts the mask.
--
-- `canvasPhase` is a monotonic counter bumped whenever the editing canvas changes. Autosave
-- and the other-side projection both watch it instead of comparing pixels.

local M = {}

---@param env table
---@param S table
---@param stored table
function M.init(env, S, stored)
    M.env, M.S, M.stored = env, S, stored
end

---Creates the canvases for a new session. Safe to call every frame.
function M.ensure()
    local S = M.S
    if S.editingCanvas ~= nil then
        return
    end
    if S.selectedMeshes == nil then
        return
    end
    S.editingCanvas = ui.ExtraCanvas(M.env.texSize):clear(rgbm.new(M.stored.bgColor.rgb, 1))
    S.aoCanvas = ui.ExtraCanvas(M.env.texSize, 4, render.AntialiasingMode.CMAA)
    S.selectedMeshes:setMaterialTexture('txDiffuse', S.aoCanvas)
end

---Marks the editing canvas as changed.
function M.bumpPhase()
    M.S.canvasPhase = M.S.canvasPhase + 1
end

---Releases every canvas and canvas-derived resource. Called when a session ends.
function M.disposeAll()
    local S = M.S
    if S.accessibleData then
        S.accessibleData:dispose()
        S.accessibleData = nil
    end
    if S.selectedBrushOutline then
        S.selectedBrushOutline:dispose()
        S.selectedBrushOutline = nil
    end
    S.editingCanvas = nil
    S.aoCanvas = nil
    S.maskingCanvas = nil
    S.maskingDirty = true
    S.selectedBrushOutlineDirty = true
end

---Re-reads the editing canvas into `accessibleData` for the eyedropper.
function M.updateAccessibleData()
    local S = M.S
    if S.editingCanvas == nil then
        return
    end
    M.bumpPhase()
    if S.accessibleData then
        S.accessibleData:dispose()
        S.accessibleData = nil
    end
    S.editingCanvas:accessData(function(err, data)
        if data then
            S.accessibleData = data
        elseif err then
            ac.warn('Failed to access canvas: ' .. tostring(err))
        end
    end)
end

return M

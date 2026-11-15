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
    -- This is the only place the editing canvases are bound to the car. If the mesh reference
    -- is empty (a material query that matched nothing), the call silently does nothing and the
    -- user paints into a canvas that is never displayed, so report it instead of failing mute.
    local ok, err = pcall(S.selectedMeshes.setMaterialTexture, S.selectedMeshes, 'txDiffuse', S.aoCanvas)
    if not ok then
        ac.warn('Paintshop: could not bind the editing canvas to the selected mesh: ' .. tostring(err))
    end
end

---Marks the editing canvas as changed.
function M.bumpPhase()
    M.S.canvasPhase = M.S.canvasPhase + 1
end

---Releases every canvas and canvas-derived resource. Called when a session ends.
---
---Dropping the reference is what matters: the host frees the texture once nothing points at
---it. `dispose()` is called when the object provides one, but a missing method must not
---abort the teardown half-way, or the stale canvas would survive into the next session and
---`ensure()` would never bind a fresh one to the car.
local function release(canvas)
    if canvas == nil then
        return
    end
    if type(canvas.dispose) == 'function' then
        pcall(canvas.dispose, canvas)
    end
end

function M.disposeAll()
    local S = M.S
    release(S.accessibleData)
    S.accessibleData = nil
    release(S.selectedBrushOutline)
    S.selectedBrushOutline = nil
    release(S.editingCanvas)
    S.editingCanvas = nil
    release(S.aoCanvas)
    S.aoCanvas = nil
    release(S.maskingCanvas)
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

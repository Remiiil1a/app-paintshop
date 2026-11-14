-- Mirroring stamp: renders the mesh from the opposite side and stamps that as the brush.
--
-- The shot samples the mesh with the editing canvas bound, so `txDiffuse` and `ksAmbient`
-- are swapped around the update and restored even when it throws.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local S, env, widgets, brush, projection = deps.S, deps.env, deps.widgets, deps.brush, deps.projection

    return {
        name = 'Mirroring stamp (K)',
        key = deps.shortcuts.toolMirroringStamp,
        icon = deps.icons.MirroringStamp,
        ui = function(s)
            ui.header('Mirroring stamp:')
            widgets.BrushBlock(s.brush)
            widgets.BrushBaseBlock(s.brush, 0.5, false, true, true)
        end,
        brush = brush.params('mirroringStamp'),
        procBrushTex = function(s, ray, previewMode)
            if S.selectedMeshes == nil then
                return nil
            end
            if not s._shot then
                s._shot = ac.GeometryShot(S.selectedMeshes, 256):setShadersType(render.ShadersType.SampleColor)
                s._ksAmbient = S.selectedMeshes:getMaterialPropertyValue('ksAmbient')
            end
            local up = projection.getBrushUp(ray.dir, s)
            S.selectedMeshes:setMaterialTexture('txDiffuse', S.editingCanvas)
            S.selectedMeshes:setMaterialProperty('ksAmbient', 1)
            s._shot:clear(table.random(rgbm.colors))
            local lpos, ldir, lup = env.car.worldToLocal:transformPoint(ray.pos),
                env.car.worldToLocal:transformVector(ray.dir), env.car.worldToLocal:transformVector(up)
            lpos.x, ldir.x, lup.x = -lpos.x, -ldir.x, -lup.x
            local ipos, idir, iup = env.car.bodyTransform:transformPoint(lpos),
                env.car.bodyTransform:transformVector(ldir), env.car.bodyTransform:transformVector(lup)
            local brushSize = previewMode and s.brush.brushSize or
                                  s.brush.brushSize * brush.sizeMult(s.brush, deps.stored)
            s._shot:setOrthogonalParams(vec2(brushSize, brushSize), 100):update(ipos, idir, iup, 0)
            S.selectedMeshes:setMaterialTexture('txDiffuse', S.aoCanvas)
            S.selectedMeshes:setMaterialProperty('ksAmbient', s._ksAmbient)
            return s._shot
        end,
        procProjParams = function(s, pr)
            pr.mask2 = s.brush.brushTex
            pr.mask2Flags = render.TextureMaskFlags.UseAlpha
        end,
        brushColor = function(s)
            return rgbm(1, 1, 1, s.brush.brushAlpha)
        end,
        brushSize = function(s)
            return vec2(-s.brush.brushSize, s.brush.brushSize)
        end,
        stickerMode = true,
        stickerNoAlignment = true,
        stickerContinious = true
    }
end

return M

-- Blur / smudge tool: samples the mesh under the cursor, blurs it, and stamps the result.
--
-- The sample position lags behind the cursor by the smudge amount, which is what produces the
-- smearing. The shot's material swap is restored immediately after the update.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local S, widgets, brush, projection = deps.S, deps.widgets, deps.brush, deps.projection

    return {
        name = 'Blur/Smudge (Alt+B)',
        key = deps.shortcuts.toolBlurTool,
        icon = deps.icons.BlurTool,
        ui = function(s)
            ui.header('Blur tool:')
            widgets.BrushBlock(s.brush)
            widgets.BrushBaseBlock(s.brush, 0.5, false, true, true)

            s.brush.blur = ui.slider('##blur', s.brush.blur * 1000, 0, 100, 'Blur: %.0f%%') / 1000
            s.brush.smudge = ui.slider('##smudge', s.brush.smudge * 100, 0, 100, 'Smudge: %.0f%%', 0.5) / 100

            ui.offsetCursorY(20)
            ui.header('Sharpness boost:')
            if ui.checkbox('Active', s.brush.sharpnessMode) then
                s.brush.sharpnessMode = not s.brush.sharpnessMode
            end
            s.brush.sharpness = ui.slider('##sharpness', s.brush.sharpness * 100, 0, 500, 'Intensity: %.0f%%', 2) / 100
            ui.textWrapped(
                'Sharpness boost is some sort of an inverse to blur. Might help to increase local sharpness a bit or, with less well tuned settings, achieve some other strange effects.')
        end,
        brush = brush.params('blurTool', nil, nil, {
            blur = 0.01,
            smudge = 0,
            sharpnessMode = false,
            sharpness = 1.5
        }),
        procBrushTex = function(s, ray, previewMode)
            if S.selectedMeshes == nil then
                return nil
            end
            if not s._shot then
                s._shot = ac.GeometryShot(S.selectedMeshes, 256):setShadersType(render.ShadersType.SampleColor)
                s._shotBlurred = ui.ExtraCanvas(vec2(128, 128))
                s._shotSharpened = ui.ExtraCanvas(vec2(128, 128))
                s._ksAmbient = S.selectedMeshes:getMaterialPropertyValue('ksAmbient')
            end
            if previewMode or not s._rayPos then
                s._rayPos = ray.pos:clone()
                s._rayDir = ray.dir:clone()
                if previewMode then
                    return nil
                end
            else
                s._rayPos = math.applyLag(s._rayPos, ray.pos, s.brush.smudge, ac.getDeltaT())
                s._rayDir = math.applyLag(s._rayDir, ray.dir, s.brush.smudge, ac.getDeltaT()):normalize()
            end
            local up = projection.getBrushUp(s._rayDir, s)
            S.selectedMeshes:setMaterialTexture('txDiffuse', S.editingCanvas)
            S.selectedMeshes:setMaterialProperty('ksAmbient', 1)
            s._shot:clear(table.random(rgbm.colors))
            local brushSize = s.brush.brushSize * brush.sizeMult(s.brush, deps.stored)
            s._shot:setOrthogonalParams(vec2(brushSize, brushSize), 100):update(s._rayPos, s._rayDir, up, 0)
            S.selectedMeshes:setMaterialTexture('txDiffuse', S.aoCanvas)
            S.selectedMeshes:setMaterialProperty('ksAmbient', s._ksAmbient)
            if s.brush.blur <= 0.0001 then
                return s._shot
            end
            s._shotBlurred:clear(rgbm.colors.transparent):update(function(dt)
                ui.beginBlurring()
                ui.drawImage(s._shot, 0, 128)
                ui.endBlurring(s.brush.blur)
            end)
            if s.brush.sharpnessMode then
                s._shotSharpened:update(function(dt)
                    ui.renderShader({
                        p1 = vec2(0, 0),
                        p2 = vec2(128, 128),
                        blendMode = render.BlendMode.Opaque,
                        textures = {
                            txBlurred = s._shotBlurred,
                            txBase = s._shot
                        },
                        values = {
                            gIntensity = tonumber(s.brush.sharpness)
                        },
                        shader = [[float4 main(PS_IN pin) {
              float4 r = lerp(txBlurred.Sample(samLinear, pin.Tex), txBase.Sample(samLinear, pin.Tex), gIntensity);
              r.a = 1;
              return r;
            }]]
                    })
                end)
                return s._shotSharpened
            end
            return s._shotBlurred
        end,
        procProjParams = function(s, pr)
            pr.mask2 = s.brush.brushTex
            pr.mask2Flags = render.TextureMaskFlags.UseAlpha
        end,
        brushColor = function(s)
            return rgbm(1, 1, 1, s.brush.brushAlpha)
        end,
        brushSize = function(s)
            return vec2(s.brush.brushSize, s.brush.brushSize)
        end,
        stickerMode = true,
        stickerNoAlignment = true,
        stickerContinious = true
    }
end

return M

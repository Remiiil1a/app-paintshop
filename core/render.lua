-- The AO compositing pass and the masking canvas.
--
-- Both are "render the scene into a canvas" passes that run once per frame from the world
-- update. They are kept together because they share the same material-swap discipline: the
-- mesh's `txDiffuse` and `ksAmbient` are temporarily replaced and must be restored.

local M = {}

---@param env table
---@param S table
---@param stored table
---@param projection table core/projection.lua
function M.init(env, S, stored, projection)
    M.env, M.S, M.stored, M.projection = env, S, stored, projection
end

---Draws the editing canvas with the AO map multiplied in.
---@param baseCanvas any
---@param aoMap any
function M.drawWithAO(baseCanvas, aoMap)
    -- Draw base editing canvas and apply AO to it. One way of doing it is to use shading offset:
    -- ui.drawImage(aoTexture, 0, ui.windowSize())
    -- ui.setShadingOffset(0, 0, 0, -1)
    -- ui.drawImage(aoTexture, 0, ui.windowSize(), rgbm.colors.black)
    -- ui.resetShadingOffset()
    --
    -- But now there is another way, to use a custom shader:
    ui.renderShader({
        p1 = vec2(),
        p2 = ui.windowSize(),
        blendMode = render.BlendMode.Opaque,
        textures = {
            txBase = baseCanvas,
            txAO = aoMap
        },
        shader = [[float4 main(PS_IN pin) {
      float4 diffuseColor = txAO.SampleLevel(samLinear, pin.Tex, 0);
      float4 canvasColor = txBase.SampleLevel(samLinear, pin.Tex, 0);
      canvasColor.rgb *= max(diffuseColor.r, max(diffuseColor.g, diffuseColor.b)); // use maximum value of AO RGB color
      canvasColor.a = 1; // return fully opaque texture so that txDetail would not bleed and CMAA2 would be happy
      return canvasColor;
    }]]
    })
end

---Rebuilds the brush outline canvas (the cursor preview).
---@param tool table active tool
---@param stickerMode boolean
function M.updateBrushOutline(tool, stickerMode)
    local S = M.S
    if not S.selectedBrushOutline then
        S.selectedBrushOutline = ui.ExtraCanvas(vec2(128, 128), 4)
    end
    S.selectedBrushOutlineDirty = false
    if not tool.brush or stickerMode then
        S.selectedBrushOutline:clear(rgbm.colors.transparent)
        return
    end
    -- prepare brush outline in two stages: first, boost alpha and draw brush in white and draw it
    -- again in black and smaller to get a black and white mask, and then draw that mask with different
    -- shading params to turn black and white mask into transparency
    S.selectedBrushOutline:clear(rgbm.colors.black)
    S.selectedBrushOutline:update(function(dt)
        ui.renderShader({
            p1 = vec2(0, 0),
            p2 = vec2(128, 128),
            blendMode = render.BlendMode.Opaque,
            textures = {
                txBrush = tool.brush.brushTex
            },
            values = {
                gMargin = (0.5 / 128) / math.max(tool.brush.brushSize, 1e-4)
            },
            shader = [[float4 main(PS_IN pin) {
        float tx = txBrush.Sample(samLinearBorder0, pin.Tex + float2(gMargin, gMargin)).w
          + txBrush.Sample(samLinearBorder0, pin.Tex + float2(gMargin, -gMargin)).w
          + txBrush.Sample(samLinearBorder0, pin.Tex + float2(-gMargin, gMargin)).w
          + txBrush.Sample(samLinearBorder0, pin.Tex + float2(-gMargin, -gMargin)).w;
        tx = saturate(tx * 20 - 1);
        tx *= 1 - saturate(txBrush.Sample(samLinear, pin.Tex).w * 20 - 1);
        return float4(1, 1, 1, tx);
      }]]
        })
    end)
end

---Per-frame AO pass: composites the editing canvas with the AO map and draws the brush preview.
---@param tool table active tool
function M.updateAOCanvas(tool)
    local S, stored = M.S, M.stored
    -- Both canvases are created and destroyed together, but the AO pass also reads the
    -- editing canvas and the selected mesh, so guard on all three.
    if S.aoCanvas == nil or S.editingCanvas == nil or S.selectedMeshes == nil then
        return
    end

    local projectDir = M.projection.updateOtherSide()

    local ray = render.createMouseRay()
    local tex
    if tool.stickerMode then
        if tool.procBrushTex then
            tex = tool:procBrushTex(ray, true)
        else
            tex = tool.brush.brushTex
        end
    end

    if S.selectedBrushOutlineDirty then
        M.updateBrushOutline(tool, tool.stickerMode and tex ~= nil)
    end

    S.aoCanvas:update(function(dt)
        M.drawWithAO(S.editingCanvas, S.aoTexture or S.carTexture)

        if stored.projectOtherSide and projectDir then
            M.projection.projectOtherSide(projectDir)
        end

        if tex then
            M.projection.project(tool, tex, ray.pos, ray.dir, tool:brushColor() * rgbm(1, 1, 1, 0.3), nil, true)
        elseif S.selectedBrushOutline then
            M.projection.project(tool, S.selectedBrushOutline, ray.pos, ray.dir, rgbm.colors.gray, nil, true,
                tool.stickerMode)
        end
    end)
end

---Per-frame masking pass: white where the plane allows painting, black where it does not.
function M.updateMaskingCanvas()
    local S, env = M.S, M.env
    if not S.maskingActive then
        if S.maskingCanvas and S.maskingDirty then
            S.maskingDirty = false
            S.maskingCanvas:clear(rgbm.colors.white)
        end
        return
    end

    if S.selectedMeshes == nil then
        return
    end

    if not S.maskingCanvas then
        S.maskingCanvas = ui.ExtraCanvas(env.texSize)
    end

    S.maskingDirty = true
    S.maskingCanvas:clear(rgbm.colors.black)
    S.maskingCanvas:update(function(dt)
        local mdir = S.maskingDir
        if mdir:dot(env.car.worldToLocal:transformPoint(ac.getCameraPosition()) - S.maskingPos) < 0 then
            mdir = mdir:clone():scale(-1)
        end
        local pos = S.maskingPos + mdir * 5
        local dir = math.cross(mdir, vec3(0, 0, 1))
        S.selectedMeshes:projectTexture({
            filename = 'color::#ffffff',
            pos = env.car.bodyTransform:transformPoint(pos),
            look = env.car.bodyTransform:transformVector(dir),
            up = env.car.bodyTransform:transformVector(mdir),
            color = rgbm.colors.white,
            size = vec2(10, 10),
            depth = 1e9,
            doubleSided = true
        })
    end)
end

return M

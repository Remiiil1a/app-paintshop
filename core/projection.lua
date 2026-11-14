-- Texture projection: turns a brush texture plus a ray into a `projectTexture` call, and
-- handles the mirror copy and the "project other side" pass.
--
-- The tool contract used here is documented in `core/types.lua`.

local M = {}

---@param env table
---@param S table
---@param stored table
---@param brush table core/brush.lua
---@param masking table core/masking.lua
function M.init(env, S, stored, brush, masking)
    M.env, M.S, M.stored, M.brush, M.masking = env, S, stored, brush, masking
    M.pdistance, M.pnormal, M.pdir = 1, vec3(), vec3(1, 0, 0)
    M.otherSideShot = nil
    M.otherSidePhase = -1
    M.otherSideSide = 0
    M.bakKsAmbient = nil
end

---Rotation applied to the car's up vector, so the brush can be rotated around the ray.
---@param dir vec3
---@param tool table
---@return vec3
function M.getBrushUp(dir, tool)
    local brush = tool.brush
    -- __brushRandomAngle is written by project(); fall back to the configured angle so the
    -- first call of a session cannot rotate by nil.
    local angle = brush.brushRandomizedAngle and (tool.__brushRandomAngle or brush.brushAngle) or brush.brushAngle
    return mat4x4.rotation(math.rad(angle), dir):transformVector(M.env.car.up)
end

---Projects one brush stamp.
---@param tool table active tool
---@param tex any texture (string path or canvas)
---@param pos vec3
---@param dir vec3
---@param color rgbm
---@param distance number?
---@param previewMode boolean?
---@param doNotUseToolProjParams boolean?
function M.project(tool, tex, pos, dir, color, distance, previewMode, doNotUseToolProjParams)
    local S, env, stored = M.S, M.env, M.stored
    local brush = tool.brush
    if not brush or S.selectedMeshes == nil then
        return
    end

    if tool.stickerMode and not tool.stickerNoAlignment and (stored.alignSticker or 1) > 1 then
        local d, m = S.selectedMeshes:raycast(render.createRay(pos, dir), true, nil, M.pnormal)
        if d ~= -1 then
            M.pdir = m:getWorldTransformationRaw():transformVector(M.pnormal):scale(-1)
            M.pdistance = d
        else
            d = M.pdistance
        end
        pos = pos + dir * d
        dir = M.pdir:clone()
        if stored.alignSticker == 3 then
            dir = dir - env.car.up * dir:dot(env.car.up)
        end
        distance = 0.2
    end

    local size = tool:brushSize()
    if not previewMode and (not tool.stickerMode or tool.stickerContinious) then
        size = size * M.brush.sizeMult(brush, stored)
    end
    -- brushAspectMult is user-editable and can reach zero through a stale saved config.
    local aspect = math.max(brush.brushAspectMult or 1, 1e-3)
    if aspect > 1 then
        size.x = size.x * aspect
    else
        size.y = size.y / aspect
    end
    if brush.brushMirror then
        size.x = -size.x
    end
    if not tool.__brushRandomAngle or previewMode then
        tool.__brushRandomAngle = brush.brushAngle
    else
        tool.__brushRandomAngle = math.random() * 360
    end
    local up = M.getBrushUp(dir, tool)
    local pr = {
        filename = tex,
        pos = pos,
        look = dir,
        up = up,
        color = color,
        size = size,
        depth = brush.paintThrough and 1e9 or distance,
        doubleSided = brush.paintThrough,
        mask1 = S.maskingCanvas,
        mask1Flags = bit.bor(render.TextureMaskFlags.AltUV, render.TextureMaskFlags.Default),
        blendMode = not previewMode and tool.blendMode or nil
    }
    if tool.procProjParams and not doNotUseToolProjParams then
        tool:procProjParams(pr)
    end
    S.selectedMeshes:projectTexture(pr)
    if brush.withMirror then
        local lpos, ldir, lup = env.car.worldToLocal:transformPoint(pos), env.car.worldToLocal:transformVector(dir),
            env.car.worldToLocal:transformVector(up)
        lpos.x, ldir.x, lup.x = -lpos.x, -ldir.x, -lup.x
        pr.pos, pr.look, pr.up = env.car.bodyTransform:transformPoint(lpos),
            env.car.bodyTransform:transformVector(ldir), env.car.bodyTransform:transformVector(lup)
        pr.size.x = -pr.size.x
        S.selectedMeshes:projectTexture(pr)
    end
end

---Releases the other-side shot and its cached material value.
function M.dispose()
    if M.otherSideShot then
        M.otherSideShot:dispose()
        M.otherSideShot = nil
    end
    M.otherSidePhase = -1
    M.otherSideSide = 0
    M.bakKsAmbient = nil
end

---Refreshes the other-side shot when the editing canvas changed.
---@param projectDir vec3? set when the shot was refreshed
---@return vec3? projectDir
function M.updateOtherSide()
    local S, env, stored = M.S, M.env, M.stored
    if not stored.projectOtherSide or S.selectedMeshes == nil or S.editingCanvas == nil then
        return nil
    end

    if not M.otherSideShot then
        M.bakKsAmbient = S.selectedMeshes:getMaterialPropertyValue('ksAmbient')
        M.otherSideShot = ac.GeometryShot(S.selectedMeshes, 4096):setOrthogonalParams(vec2(6, 4), 10)
            :setClippingPlanes(-10, 0):setShadersType(render.ShadersType.SampleColor)
    end

    local projectDir = env.car.side
    local s = math.sign(projectDir:dot(ac.getCameraForward()))
    if s > 0 then
        projectDir = -projectDir
    end
    if s ~= M.otherSideSide then
        M.otherSidePhase, M.otherSideSide = -1, s
    end

    if M.otherSidePhase ~= S.canvasPhase then
        M.otherSidePhase = S.canvasPhase
        -- The shot samples the mesh with the editing canvas bound, so the material has to be
        -- restored even if the update throws.
        S.selectedMeshes:setMaterialTexture('txDiffuse', S.editingCanvas)
        S.selectedMeshes:setMaterialProperty('ksAmbient', 1)
        local ok, err = pcall(M.otherSideShot.update, M.otherSideShot, env.car.position, projectDir, env.car.up, 0)
        S.selectedMeshes:setMaterialTexture('txDiffuse', S.aoCanvas)
        S.selectedMeshes:setMaterialProperty('ksAmbient', M.bakKsAmbient)
        if not ok then
            ac.warn('Failed to update the other-side shot: ' .. tostring(err))
        end
    end
    return projectDir
end

---Projects the other-side shot onto the current side.
---@param projectDir vec3
function M.projectOtherSide(projectDir)
    local S, env = M.S, M.env
    if not M.otherSideShot or S.selectedMeshes == nil then
        return
    end
    S.selectedMeshes:projectTexture({
        filename = M.otherSideShot,
        pos = env.car.position,
        look = -projectDir,
        up = env.car.up,
        color = rgbm(1, 1, 1, 0.1),
        size = vec2(-6, 4),
        depth = 1e9,
        doubleSided = false
    })
end

return M

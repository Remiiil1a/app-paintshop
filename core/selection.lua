-- Mesh selection: hover a car mesh, preview it, and start editing on Shift+click.

local M = {}

---@param env table
---@param S table
---@param camera table core/camera.lua
function M.init(env, S, camera)
    M.env, M.S, M.camera = env, S, camera
end

---Builds the mesh query for one material.
---
---The query parser reads the material name verbatim up to the next space or `&`, so the name
---must NOT be quoted: `material:"foo"` looks for a material literally named `"foo"` and
---matches nothing. A query that matches nothing still returns a valid (empty) reference, so
---the caller cannot tell the difference from a successful match.
---@param materialName string?
---@return ac.SceneReference? nil when there is no name to query
function M.findMeshesByMaterial(materialName)
    if materialName == nil or materialName == '' then
        return nil
    end
    return M.env.carNode:findMeshes('{ material:' .. materialName .. ' & lod:A }')
end

---Starts an editing session on the hovered material.
---@param materialName string
---@param textureFilename string
---@param aoMap string? custom AO map, nil to reuse the car texture
function M.startEditing(materialName, textureFilename, aoMap)
    local S = M.S
    local meshes = M.findMeshesByMaterial(materialName)
    if meshes == nil then
        return false
    end
    S.selectedMeshes = meshes
    S.carTexture = textureFilename
    S.aoTexture = aoMap
    M.camera.grab()
    return true
end

---Draws the mesh picker window.
function M.draw()
    local S, env = M.S, M.env
    local ray = render.createMouseRay()
    local ref = ac.emptySceneReference()
    if not (env.sim.isWindowForeground and env.carMeshes:raycast(ray, ref) ~= -1) then
        ui.text('Hover a car mesh to start drawing…')
        return
    end

    ui.text('Found:')
    ui.pushFont(ui.Font.Small)
    ui.text('\tMesh: ' .. tostring(ref:name()))
    ui.text('\tMaterial: ' .. tostring(ref:materialName()))
    ui.text('\tTexture: ' .. tostring(ref:getTextureSlotFilename('txDiffuse')))
    ui.popFont()
    ui.offsetCursorY(20)

    if S.hoveredMaterial ~= ref:materialName() then
        S.hoveredMaterial = ref:materialName()
        if S.carPreview then
            S.carPreview:dispose()
            S.carPreview = nil
        end
        local meshes = M.findMeshesByMaterial(S.hoveredMaterial)
        if meshes then
            S.carPreview = ac.GeometryShot(meshes, vec2(420, 320))
            S.carPreview:setClearColor(rgbm(0.14, 0.14, 0.14, 1))
        end
    end

    if S.carPreview then
        local mat = mat4x4.rotation(ui.time() * 0.1, vec3(0, 1, 0)):mul(env.car.bodyTransform)
        S.carPreview:update(mat:transformPoint(env.car.aabbCenter + vec3(0, 2, 4)),
            mat:transformVector(vec3(0, -1, -2)), nil, 50)
        ui.image(S.carPreview, vec2(210, 160))
        ui.offsetCursorY(20)
    end

    local textureFilename = ref:getTextureSlotFilename('txDiffuse')
    local size = textureFilename and ui.imageSize(textureFilename) or vec2()
    if size.x <= 0 or size.y <= 0 then
        ui.text('Texture is missing')
        return
    end

    ui.textWrapped(
        '• Hold Shift and click to start drawing.\n• Hold Ctrl+Shift and click to start drawing using custom AO map.')

    ui.offsetCursorY(20)
    ui.pushFont(ui.Font.Small)
    ui.textWrapped(
        'For best results, either use a custom AO map or make sure this texture is an AO map (grayscale colors with nothing but shadows).')
    ui.popFont()

    ui.setShadingOffset(1, 0, 1, 1)
    ui.image(textureFilename, vec2(210, 210 * size.y / size.x))
    ui.resetShadingOffset()

    if not (env.uiState.shiftDown and not env.uiState.altDown and env.uiState.isMouseLeftKeyClicked and
        not env.uiState.wantCaptureMouse) then
        return
    end

    if env.uiState.ctrlDown then
        -- Capture the material now: the dialog is async and the hovered material will have
        -- changed by the time the callback runs.
        local materialName = S.hoveredMaterial
        os.openFileDialog({
            title = 'Open Base AO Map',
            folder = env.carDir,
            fileTypes = {{
                name = 'Images',
                mask = '*.png;*.jpg;*.jpeg;*.dds'
            }},
            addAllFilesFileType = true,
            flags = bit.bor(os.DialogFlags.PathMustExist, os.DialogFlags.FileMustExist)
        }, function(err, filename)
            if not err and filename then
                M.startEditing(materialName, textureFilename, filename)
            end
        end)
    else
        M.startEditing(S.hoveredMaterial, textureFilename, nil)
    end
end

return M

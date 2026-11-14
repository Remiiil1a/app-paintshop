-- Tool panel: the tool button row plus the active tool's own controls.

local M = {}

---@param deps table
function M.init(deps)
    M.env, M.S, M.stored = deps.env, deps.S, deps.stored
    M.shortcuts, M.icons, M.widgets = deps.shortcuts, deps.icons, deps.widgets
    M.registry, M.toolbar = deps.registry, deps.toolbar
end

function M.draw()
    local S, stored = M.S, M.stored
    M.toolbar.draw()
    if S.selectedMeshes == nil then
        return
    end
    ui.offsetCursorY(20)

    local tools = M.registry.getAll()

    ui.header('Tools:')
    for i = 1, #tools do
        local v = tools[i]
        -- Re-read the active tool every iteration: clicking a button mid-loop changes it.
        local activeTool = M.registry.getActive()
        local temporary = activeTool == v and M.registry.toolSwitched ~= 0 and
                              ui.time() > M.registry.toolSwitched + 0.2
        local bg = temporary and rgbm(0.5, 0.5, 0, 1) or
                       activeTool == v and M.env.uiState.accentColor * rgbm(1, 1, 1, 0.5)
        if bg then
            ui.pushStyleColor(ui.StyleColor.Button, bg)
        end
        if M.widgets.IconButton(v.icon, v.name, activeTool == v) or v.key and v.key(false) then
            M.registry.select(i, v.key ~= nil)
        end
        if bg then
            ui.popStyleColor()
        end
        ui.sameLine(0, 4)
        if ui.availableSpaceX() < 12 then
            ui.newLine(4)
        end
    end
    if M.widgets.IconButton(M.icons.Camera,
        'Orbit camera (Ctrl+Space)\nUse middle mouse button or hold space to rotate camera', stored.orbitCamera) or
        M.shortcuts.toggleOrbitCamera() then
        stored.orbitCamera = not stored.orbitCamera
    end
    ui.sameLine(0, 4)
    if ui.availableSpaceX() < 32 then
        ui.newLine(4)
    end
    if M.widgets.IconButton(M.icons.MirroringHelper,
        'Project other side (Ctrl+E)\nProject other side on current side to make making things symmetrical easier',
        stored.projectOtherSide) or M.shortcuts.toggleProjectOtherSide() then
        stored.projectOtherSide = not stored.projectOtherSide
    end

    ui.offsetCursorY(20)

    -- Temporary tool switch: holding a tool's key shows that tool, releasing it goes back.
    local current = M.registry.getActive()
    if M.registry.toolSwitched ~= 0 and not (current.key and current.key:down()) then
        if ui.time() > M.registry.toolSwitched + 0.2 then
            M.registry.restorePrevious()
        else
            M.registry.toolSwitched = 0
        end
    end

    if M.shortcuts.toggleMasking() then
        S.maskingActive = not S.maskingActive
    end

    local activeTool = M.registry.getActive()
    ui.pushID(activeTool.name)
    ui.pushFont(ui.Font.Small)
    activeTool:ui()
    ui.popFont()
    ui.popID()
end

return M

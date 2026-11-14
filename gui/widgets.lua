-- Shared widgets: icon button, colour picker block, brush base controls, brush list.
--
-- These are used by every tool panel, so they take their dependencies explicitly instead of
-- closing over module-level state.

local M = {}

---@param deps table {env, S, stored, shortcuts, palette, assets}
function M.init(deps)
    M.env, M.S, M.stored = deps.env, deps.S, deps.stored
    M.shortcuts, M.palette, M.assets = deps.shortcuts, deps.palette, deps.assets
    M.colorFlags = bit.bor(ui.ColorPickerFlags.NoAlpha, ui.ColorPickerFlags.NoSidePreview,
        ui.ColorPickerFlags.PickerHueWheel, ui.ColorPickerFlags.DisplayHex)
end

---@param icon any
---@param tooltip string?
---@param active boolean?
---@param enabled boolean?
---@return boolean
function M.IconButton(icon, tooltip, active, enabled)
    local r = ui.button('##' .. icon, vec2(32, 32), enabled == false and ui.ButtonFlags.Disabled or active and
        ui.ButtonFlags.Active or ui.ButtonFlags.None)
    ui.addIcon(icon, 24, 0.5, nil, 0)
    if tooltip and ui.itemHovered() then
        ui.setTooltip(tooltip)
    end
    return r
end

---@param color rgbm
function M.ColorTooltip(color)
    ui.tooltip(0, function()
        ui.dummy(20)
        ui.drawRectFilled(0, 20, color)
        ui.drawRect(0, 20, rgbm.colors.black)
    end)
end

---Colour picker plus the built-in and user swatch rows.
---@param key string? storage field, defaults to 'color'
function M.ColorBlock(key)
    local S, stored, palette = M.S, M.stored, M.palette
    key = key or 'color'
    local col = stored[key]:clone()
    ui.colorPicker('##color', col, M.colorFlags)
    if ui.itemEdited() then
        stored[key] = col
        S.colorPickerEditing = true
    elseif S.colorPickerEditing and not ui.itemActive() then
        S.colorPickerEditing = false
        palette.addToUserPalette(col)
    end
    for i = 1, #palette.builtin do
        ui.drawRectFilled(ui.getCursor(), ui.getCursor() + 14, palette.builtin[i])
        if ui.invisibleButton(i, 14) then
            stored[key] = palette.builtin[i]:clone()
            palette.addToUserPalette(stored[key])
        end
        if ui.itemHovered() then
            M.ColorTooltip(palette.builtin[i])
        end
        ui.sameLine(0, 0)
        if ui.availableSpaceX() < 14 then
            ui.newLine(0)
        end
    end
    for i = 1, #palette.user do
        ui.drawRectFilled(ui.getCursor(), ui.getCursor() + 14, palette.user[i])
        if ui.invisibleButton(100 + i, 14) then
            stored[key] = palette.user[i]:clone()
            palette.addToUserPalette(stored[key])
        end
        if ui.itemHovered() then
            M.ColorTooltip(palette.user[i])
        end
        ui.sameLine(0, 0)
    end
    ui.newLine()
    if M.shortcuts.swapColors() and #palette.user > 0 then
        -- Swap between the two most recently used colours.
        local last = palette.user[#palette.user]
        local previous = palette.user[#palette.user - 1] or last
        stored[key] = stored[key] == last and previous or last
        palette.addToUserPalette(stored[key])
    end
end

---Size, opacity, angle, symmetry and paint-through controls shared by every brush tool.
---@param brush table
---@param maxSize number metres
---@param stickerMode boolean?
---@param noStepSize boolean?
---@param noSymmetry boolean?
function M.BrushBaseBlock(brush, maxSize, stickerMode, noStepSize, noSymmetry)
    local S, stored, shortcuts = M.S, M.stored, M.shortcuts
    if not ui.mouseBusy() then
        local w = ui.mouseWheel()
        if ui.keyboardButtonPressed(ui.KeyIndex.SquareOpenBracket, true) then
            w = w - 1
        end
        if ui.keyboardButtonPressed(ui.KeyIndex.SquareCloseBracket, true) then
            w = w + 1
        end
        if w ~= 0 then -- changing brush size with mouse wheel
            if M.env.uiState.shiftDown then
                w = w / 10
            end
            if M.env.uiState.altDown then
                brush.brushAngle = brush.brushAngle + w * 30
            elseif not M.env.uiState.ctrlDown then
                brush.brushSize = math.clamp(brush.brushSize * (1 + w * 0.15), 0.001, maxSize)
            elseif stickerMode then
                brush.brushAspectMult = math.clamp(brush.brushAspectMult * (1 + w * 0.25), 0.04, 25)
            end
            S.selectedBrushOutlineDirty = true
        end
        for i = 0, 9 do -- changing opacity photoshop style
            local shortcut = shortcuts.opacity[i]
            if shortcut and shortcut() then
                brush.brushAlpha = i == 0 and 1 or i / 10
            end
        end
    end

    if stickerMode then
        if ui.checkbox('Flip sticker', brush.brushMirror) or shortcuts.flipSticker() then
            brush.brushMirror = not brush.brushMirror
        end
        if ui.itemHovered() then
            ui.setTooltip('Flip sticker (Z)')
        end
    end

    brush.brushSize = ui.slider('##brushSize', brush.brushSize * 100, 0.1, maxSize * 100, 'Size: %.1f cm', 2) / 100
    if ui.itemHovered() then
        ui.setTooltip('Use mouse wheel to quickly change size')
    end
    if ui.itemEdited() then
        S.selectedBrushOutlineDirty = true
    end

    if stored.hasPen then
        brush.penMinRadiusMult = ui.slider('##penMinRadiusMult', brush.penMinRadiusMult * 100, 0, 100,
            'Minimum size: %.1f%%') / 100
        if ui.itemHovered() then
            ui.setTooltip('Size of a brush with minimum pen pressure')
        end
    end

    if stickerMode then
        ui.setNextItemWidth(ui.availableSpaceX() - 60)
        brush.brushAspectMult = ui.slider('##brushAspectMult', brush.brushAspectMult * 100, 4, 2500, 'Stretch: %.0f%%',
            4) / 100
        if ui.itemHovered() then
            ui.setTooltip('Use mouse wheel and hold Ctrl to quickly change size')
        end
        if ui.itemEdited() then
            S.selectedBrushOutlineDirty = true
        end
        ui.sameLine(0, 4)
        if ui.button('Reset', vec2(56, 0)) then
            brush.brushAspectMult = 1
            S.selectedBrushOutlineDirty = true
        end
    end

    if not stickerMode and not noStepSize then
        brush.brushStepSize =
            ui.slider('##brushStepSize', brush.brushStepSize * 100, 0.1, 50, 'Step size: %.1f cm', 2) / 100
    end

    brush.brushAlpha = ui.slider('##alpha', brush.brushAlpha * 100, 0, 100, 'Opacity: %.1f%%') / 100
    if ui.itemHovered() then
        ui.setTooltip('Use digit buttons to quickly change opacity')
    end

    if ui.checkbox('##randomAngle', brush.brushRandomizedAngle) then
        brush.brushRandomizedAngle = not brush.brushRandomizedAngle
    end
    if ui.itemHovered() then
        ui.setTooltip('Randomize angle when drawing')
    end
    ui.sameLine(0, 4)
    ui.setNextItemWidth(210 - 22 - 4 - 60)
    brush.brushAngle = (brush.brushAngle % 360 + 360) % 360
    brush.brushAngle = ui.slider('##brushAngle', brush.brushAngle, 0, 360, 'Angle: %.0f°')
    if ui.itemHovered() then
        ui.setTooltip('Use mouse wheel and hold Alt to quickly change angle')
    end
    ui.sameLine(0, 4)
    if ui.button('Reset##angle', vec2(56, 0)) then
        brush.brushAngle = 0
    end

    if not stickerMode and not noStepSize then
        brush.smoothing = ui.slider('##smoothing', brush.smoothing * 100, 0, 100, 'Smoothing: %.1f%%') / 100
        if ui.itemHovered() then
            ui.setTooltip('Smoothing makes brush move smoother and slower')
        end
    end

    if not noSymmetry then
        if ui.checkbox('With symmetry', brush.withMirror) or shortcuts.toggleSymmetry() then
            brush.withMirror = not brush.withMirror
        end
        if ui.itemHovered() then
            ui.setTooltip('Paith with symmetry (Y)\nMirrors things from one side of a car to another')
        end
    end

    if ui.checkbox('Paint through', brush.paintThrough) or shortcuts.toggleDrawThrough() then
        brush.paintThrough = not brush.paintThrough
    end
    if ui.itemHovered() then
        ui.setTooltip(
            'Paint through model (R)\nIf enabled, drawings would go through model and leave traces on the opposite side as well')
    end
end

---Horizontal brush picker with a context menu for opening the folder and rescanning.
---@param brush table
function M.BrushBlock(brush)
    local S, env, assets = M.S, M.env, M.assets
    local brushes = S.brushes or {}
    if #brushes == 0 then
        ui.textWrapped('No brushes found. Add PNG files to the brushes directory.')
        return
    end
    if brush.brushTex == '' then
        brush.brushTex = brushes[1][2]
    end
    local anySelected = false
    ui.childWindow('brushesList', vec2(210, 60), false, bit.bor(ui.WindowFlags.HorizontalScrollbar,
        ui.WindowFlags.AlwaysHorizontalScrollbar, ui.WindowFlags.NoBackground), function()
        ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.transparent)
        for i = 1, #brushes do
            local selected = brushes[i][2] == brush.brushTex
            if ui.button('##' .. i, 48, selected and ui.ButtonFlags.Active or ui.ButtonFlags.None) then
                brush.brushTex = brushes[i][2]
                S.selectedBrushOutlineDirty = true
            end
            if selected then
                anySelected = true
            end
            ui.addIcon(brushes[i][2], 36, 0.5, nil, 0)
            if ui.itemHovered() then
                ui.setTooltip('Brush: ' .. brushes[i][1])
            end
            ui.sameLine(0, 4)
        end
        ui.popStyleColor()
        ui.newLine()
    end)
    if not anySelected then
        brush.brushTex = brushes[1][2]
    end
    ui.itemPopup(function()
        if ui.selectable('Open in Explorer') then
            os.openInExplorer(env.brushesDir)
        end
        if ui.selectable('Refresh') then
            assets.rescanBrushes()
        end
    end)
end

return M

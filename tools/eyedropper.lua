-- Eyedropper: samples a colour from the editing canvas under the cursor.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local S, stored, widgets, palette = deps.S, deps.stored, deps.widgets, deps.palette

    return {
        name = 'Eyedropper (I)',
        key = deps.shortcuts.toolEyeDropper,
        icon = deps.icons.EyeDropper,
        ui = function(s)
            ui.header('Color:')
            widgets.ColorBlock()
            ui.offsetCursorY(20)

            ui.header('Eyedropper:')
            ui.alignTextToFramePadding()
            ui.text('Sample size:')
            ui.sameLine()
            ui.setNextItemWidth(ui.availableSpaceX())
            stored.eyeDropperRange = ui.combo('##sampleSize', stored.eyeDropperRange, ui.ComboFlags.None,
                {'Point sample', '3 by 3 average', '5 by 5 average', '7 by 7 average', '9 by 9 average'})
            if s._color and not ui.mouseBusy() then
                widgets.ColorTooltip(s._color)
                if deps.env.uiState.isMouseLeftKeyDown then
                    -- Clone: stored.color must not alias the tool's scratch colour, or later
                    -- sampling would silently rewrite the saved foreground colour.
                    stored.color = s._color:clone()
                    s._changing = true
                elseif s._changing then
                    s._changing = false
                    palette.addToUserPalette(s._color)
                end
            end
        end,
        action = function(s)
            if S.accessibleData == nil or S.selectedMeshes == nil then
                return
            end
            local ray = render.createMouseRay()
            local uv = vec2()
            if S.selectedMeshes:raycast(ray, false, nil, nil, uv) == -1 then
                return
            end
            uv.x = uv.x - math.floor(uv.x)
            uv.y = uv.y - math.floor(uv.y)
            local canvasSize = S.accessibleData:size()
            local c = uv * canvasSize
            local range = 1 + (math.clamp(stored.eyeDropperRange or 1, 1, 5) - 1) * 2
            local offset = -math.ceil(range / 2)
            local cx, cy = math.floor(c.x) + offset, math.floor(c.y) + offset
            local colorPick = rgbm()
            s._color:set(colorPick)
            for x = 1, range do
                for y = 1, range do
                    -- Sampling near an edge would read outside the canvas.
                    local px = math.clamp(cx + x, 0, canvasSize.x - 1)
                    local py = math.clamp(cy + y, 0, canvasSize.y - 1)
                    s._color:add(S.accessibleData:colorTo(colorPick, px, py))
                end
            end
            s._color:scale(1 / (range * range))
        end,
        _color = rgbm(1, 1, 1, 1),
        _changing = false
    }
end

return M

-- Brush tool: paints with the foreground colour using the selected brush texture.

local M = {}

---@param deps table {env, S, stored, shortcuts, icons, widgets, palette, brush}
---@return table tool
function M.create(deps)
    local stored, widgets, brush = deps.stored, deps.widgets, deps.brush

    return {
        name = 'Brush (B)',
        key = deps.shortcuts.toolBrush,
        icon = deps.icons.Brush,
        ui = function(s)
            ui.header('Color:')
            widgets.ColorBlock()
            ui.offsetCursorY(20)
            ui.header('Brush:')
            widgets.BrushBlock(s.brush)
            widgets.BrushBaseBlock(s.brush, 0.5)
        end,
        brush = brush.params('brush'),
        brushColor = function(s)
            return rgbm.new(stored.color.rgb, s.brush.brushAlpha)
        end,
        brushSize = function(s)
            return vec2(s.brush.brushSize, s.brush.brushSize)
        end
        -- blendMode = render.BlendMode.BlendAccurate,
    }
end

return M

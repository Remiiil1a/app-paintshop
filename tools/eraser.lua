-- Eraser tool: paints with the background colour.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local stored, widgets, brush = deps.stored, deps.widgets, deps.brush

    return {
        name = 'Eraser (E)',
        key = deps.shortcuts.toolEraser,
        icon = deps.icons.Eraser,
        ui = function(s)
            ui.header('Background color:')
            widgets.ColorBlock('bgColor')
            ui.offsetCursorY(20)
            ui.header('Eraser:')
            widgets.BrushBlock(s.brush)
            widgets.BrushBaseBlock(s.brush, 0.5)
        end,
        brush = brush.params('eraser'),
        brushColor = function(s)
            return stored.bgColor
        end,
        brushSize = function(s)
            return vec2(s.brush.brushSize, s.brush.brushSize)
        end
    }
end

return M

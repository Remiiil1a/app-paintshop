-- Tool registry: the ordered tool list, the active tool, and the temporary switch.
--
-- `stored.activeToolIndex` is a 1-based position in this array, so it goes stale whenever the
-- list changes; it is clamped here instead of being trusted downstream.
--
-- Holding a tool's key shows that tool and releasing it goes back to the previous one, which
-- is why `previousToolIndex` and `toolSwitched` exist.

local M = {}

local TOOL_MODULES = {
    'tools/brush',
    'tools/eraser',
    'tools/stamp',
    'tools/mirroring_stamp',
    'tools/blur',
    'tools/text',
    'tools/masking',
    'tools/eyedropper'
}

---@param deps table
function M.init(deps)
    M.S, M.stored = deps.S, deps.stored
    M.tools = {}
    for _, name in ipairs(TOOL_MODULES) do
        table.insert(M.tools, deps.load(name).create(deps))
    end

    M.stored.activeToolIndex = math.clamp(M.stored.activeToolIndex or 1, 1, #M.tools)
    M.activeTool = M.tools[M.stored.activeToolIndex]
    M.previousToolIndex = M.stored.activeToolIndex
    M.toolSwitched = 0
    return M
end

---@return table active tool
function M.getActive()
    return M.activeTool
end

---@return table[] tools
function M.getAll()
    return M.tools
end

---Switches to a tool and remembers the previous one.
---@param index integer
---@param temporary boolean
function M.select(index, temporary)
    index = math.clamp(index, 1, #M.tools)
    M.previousToolIndex = M.stored.activeToolIndex
    M.activeTool = M.tools[index]
    M.stored.activeToolIndex = index
    M.toolSwitched = temporary and tonumber(ui.time()) or 0
    M.S.selectedBrushOutlineDirty = true
end

---Restores the tool that was active before a temporary switch.
function M.restorePrevious()
    M.previousToolIndex = math.clamp(M.previousToolIndex, 1, #M.tools)
    M.activeTool = M.tools[M.previousToolIndex]
    M.stored.activeToolIndex = M.previousToolIndex
    M.toolSwitched = 0
    M.S.selectedBrushOutlineDirty = true
end

---Releases every resource a tool created for the current session.
function M.disposeResources()
    for _, tool in ipairs(M.tools) do
        if tool._shot then
            tool._shot:dispose()
            tool._shot = nil
        end
        if tool._shotBlurred then
            tool._shotBlurred:dispose()
            tool._shotBlurred = nil
        end
        if tool._shotSharpened then
            tool._shotSharpened:dispose()
            tool._shotSharpened = nil
        end
        if tool._labelCanvas then
            tool._labelCanvas:dispose()
            tool._labelCanvas = nil
        end
        if tool._previewCanvas then
            tool._previewCanvas:dispose()
            tool._previewCanvas = nil
        end
        tool._rayPos, tool._rayDir = nil, nil
        tool._ksAmbient = nil
        tool._moving = false
        tool._d = nil
    end
end

return M

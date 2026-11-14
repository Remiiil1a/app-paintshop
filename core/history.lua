-- Undo/redo history.
--
-- An entry is a closure taking an optional action:
--   entry()                    – restore the state
--   entry('update')            – return a fresh entry for the current state
--   entry('dispose')           – free whatever the entry holds
--   entry('memoryFootprint')   – bytes held, for the tooltip
--
-- The stack is capped at 30 entries; the oldest is disposed when it overflows.

local M = {}

local MAX_ENTRIES = 30

---@param S table
---@param canvas table
function M.init(S, canvas)
    M.S, M.canvas = S, canvas
end

---@param entry function
function M.add(entry)
    local S = M.S
    if #S.undoStack > MAX_ENTRIES - 1 then
        S.undoStack[1]('dispose')
        table.remove(S.undoStack, 1)
    end
    table.insert(S.undoStack, entry)
    table.clear(S.redoStack)
    S.changesMade = S.changesMade + 1
end

function M.undo()
    local S = M.S
    local last = S.undoStack[#S.undoStack]
    if not last then
        return
    end
    table.insert(S.redoStack, last('update'))
    last()
    last('dispose')
    table.remove(S.undoStack)
    S.changesMade = S.changesMade - 1
    M.canvas.bumpPhase()
end

function M.redo()
    local S = M.S
    local last = S.redoStack[#S.redoStack]
    if not last then
        return
    end
    table.insert(S.undoStack, last('update'))
    last()
    last('dispose')
    table.remove(S.redoStack)
    S.changesMade = S.changesMade + 1
    M.canvas.bumpPhase()
end

---@return number bytes
function M.memoryFootprint()
    local S = M.S
    return table.sum(S.undoStack, function(u)
        return u('memoryFootprint')
    end) + table.sum(S.redoStack, function(u)
        return u('memoryFootprint')
    end)
end

function M.clear()
    local S = M.S
    S.undoStack = {}
    S.redoStack = {}
end

return M

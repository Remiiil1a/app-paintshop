-- Autosave: every 20 frames, if the editing canvas changed and the user is not mid-stroke,
-- write a zipped DDS into the autosave folder, cycling through 9 slots.

local M = {}

local AUTOSAVE_INTERVAL = 20
local AUTOSAVE_SLOTS = 9

---@param env table
---@param S table
---@param canvas table
function M.init(env, S, canvas)
    M.env, M.S, M.canvas = env, S, canvas
    M.index = 1
    M.phase = 0
end

function M.start()
    setInterval(function()
        local S = M.S
        if not S.editingCanvas or M.phase == S.canvasPhase or M.env.uiState.isMouseLeftKeyDown then
            return
        end
        M.phase = S.canvasPhase
        io.createDir(M.env.autosaveDir)
        S.editingCanvas:save(string.format('%s/autosave-%s.zip', M.env.autosaveDir, M.index),
            ac.ImageFormat.ZippedDDS)
        M.index = M.index + 1
        if M.index > AUTOSAVE_SLOTS then
            M.index = 1
        end
    end, AUTOSAVE_INTERVAL)
end

return M

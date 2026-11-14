-- Brush parameter defaults and the pen-pressure size multiplier.
--
-- `brushParams(key, ...)` returns an `ac.storage` table: `key` is the persistence key, so
-- renaming one drops the user's saved brush settings for that tool.

local M = {}

---@param key string
---@param defaultSize number?
---@param defaultAlpha number?
---@param extraFields table?
---@return table
function M.params(key, defaultSize, defaultAlpha, extraFields)
    local t = {
        brushTex = '',
        brushSize = defaultSize or 0.05,
        brushAspectMult = 1,
        brushStepSize = 0.005,
        brushAngle = 0,
        brushRandomizedAngle = false,
        brushAlpha = defaultAlpha or 0.5,
        brushMirror = false,
        penMinRadiusMult = 0.05,
        withMirror = false,
        paintThrough = false,
        smoothing = 0
    }
    if extraFields then
        for k, v in pairs(extraFields) do
            t[k] = v
        end
    end
    return ac.storage(t, key)
end

---@param brush table
---@param stored table
---@return number
function M.sizeMult(brush, stored)
    local p = ac.getPenPressure()
    if p ~= 1 and not stored.hasPen then
        stored.hasPen = true
    end
    -- penMinRadiusMult is user-editable; keep the multiplier in a sane range.
    return math.lerp(math.clamp(brush.penMinRadiusMult or 0.05, 0, 1), 1, math.clamp(p or 1, 0, 1))
end

return M

-- Colour palette: a fixed built-in row plus a persisted user row.
--
-- The user row is stored as a stringified list of colours. A corrupted or empty saved value
-- would break every colour widget, so the parsed result is validated before use.

local M = {}

local USER_PALETTE_SIZE = 15

local function randomPalette()
    return table.range(USER_PALETTE_SIZE, function(index, callbackData)
        return rgbm(math.random(), math.random(), math.random(), 1)
    end)
end

local function loadUserPalette()
    local parsed = stringify.tryParse(ac.storage.palette)
    if type(parsed) ~= 'table' or #parsed == 0 then
        return randomPalette()
    end
    local result = {}
    for _, color in ipairs(parsed) do
        if type(color) == 'table' and color.r ~= nil then
            table.insert(result, rgbm(color.r, color.g, color.b, color.a or 1))
        end
    end
    if #result == 0 then
        return randomPalette()
    end
    return result
end

function M.init()
    M.builtin = {rgbm(1, 1, 1, 1), rgbm(0.8, 0.8, 0.8, 1), rgbm(0.6, 0.6, 0.6, 1), rgbm(1, 0, 0, 1),
                 rgbm(1, 0.5, 0, 1), rgbm(1, 1, 0, 1), rgbm(0.5, 1, 0, 1), rgbm(0, 1, 0, 1), rgbm(0, 1, 0.5, 1),
                 rgbm(0, 1, 1, 1), rgbm(0, 0.5, 1, 1), rgbm(0, 0, 1, 1), rgbm(0.5, 0, 1, 1), rgbm(1, 0, 1, 1),
                 rgbm(1, 0, 0.5, 1), rgbm(0, 0, 0, 1), rgbm(0.2, 0.2, 0.2, 1), rgbm(0.4, 0.4, 0.4, 1),
                 rgbm(1, 0, 0, 1):scale(0.5), rgbm(1, 0.5, 0, 1):scale(0.5), rgbm(1, 1, 0, 1):scale(0.5),
                 rgbm(0.5, 1, 0, 1):scale(0.5), rgbm(0, 1, 0, 1):scale(0.5), rgbm(0, 1, 0.5, 1):scale(0.5),
                 rgbm(0, 1, 1, 1):scale(0.5), rgbm(0, 0.5, 1, 1):scale(0.5), rgbm(0, 0, 1, 1):scale(0.5),
                 rgbm(0.5, 0, 1, 1):scale(0.5), rgbm(1, 0, 1, 1):scale(0.5), rgbm(1, 0, 0.5, 1):scale(0.5)}
    M.user = loadUserPalette()
    return M
end

---Moves a colour to the front of the user palette, persisting the result.
---@param color rgbm
function M.addToUserPalette(color)
    local _, i = table.findFirst(M.user, function(item)
        return item == color
    end)
    if i ~= nil then
        table.remove(M.user, i)
    elseif #M.user > 0 then
        table.remove(M.user, 1)
    end
    table.insert(M.user, color:clone())
    -- ac.storage is a dynamic table in AC, not a read-only one.
    ac.storage.palette = stringify(M.user, true) -- luacheck: ignore 122
end

return M

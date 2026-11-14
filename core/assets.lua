-- Asset scanning: brushes, sticker categories and fonts.
--
-- Lists may legitimately be empty (a user can delete every brush or decal), so consumers
-- must check `#list` before indexing. `selectedStickerSet` is clamped here so the rest of
-- the app can assume it is either nil or a valid entry.

local M = {}

---@param env table
---@param S table
---@param stored table
function M.init(env, S, stored)
    M.env, M.S, M.stored = env, S, stored
end

function M.rescanBrushes()
    M.S.brushes = table.map(io.scanDir(M.env.brushesDir, '*.png'), function(x)
        return {string.sub(x, 1, #x - 4), M.env.brushesDir .. '/' .. x}
    end)
end

function M.rescanStickers()
    local list = table.map(io.scanDir(M.env.decalsDir, '*'), function(x)
        return {
            name = x,
            items = table.map(io.scanDir(M.env.decalsDir .. '/' .. x, '*.png'), function(y)
                return {string.sub(y, 1, #y - 4), M.env.decalsDir .. '/' .. x .. '/' .. y}
            end)
        }
    end)
    M.S.stickers = list

    -- The stored index is a 1-based position in the scanned list, so it goes stale as soon as
    -- a category is added or removed. Clamp it before it is used to index `stickers`.
    if #list == 0 then
        M.S.selectedStickerSet = nil
        return
    end
    M.stored.selectedStickerSet = math.clamp(M.stored.selectedStickerSet or 1, 1, #list)
    M.S.selectedStickerSet = list[M.stored.selectedStickerSet]
end

function M.rescanFonts()
    local list = {{
        name = 'Arial',
        source = 'Arial:@System'
    }, {
        name = 'Bahnschrift',
        source = 'Bahnschrift:@System'
    }, {
        name = 'Calibri',
        source = 'Calibri:@System'
    }, {
        name = 'Comic Sans MS',
        source = 'Comic Sans MS:@System'
    }, {
        name = 'Consolas',
        source = 'Consolas'
    }, {
        name = 'Courier New',
        source = 'Courier New:@System'
    }, {
        name = 'Impact',
        source = 'Impact:@System'
    }, {
        name = 'Orbitron',
        source = 'Orbitron'
    }, {
        name = 'Segoe UI',
        source = 'Segoe UI'
    }, {
        name = 'Times New Roman',
        source = 'Times New Roman:@System'
    }, {
        name = 'VCR OSD Mono',
        source = 'VCR OSD Mono'
    }, {
        name = 'Webdings',
        source = 'Webdings:@System'
    }}
    for _, v in ipairs(io.scanDir(M.env.fontsDir, '*.ttf')) do
        table.insert(list, {
            name = v:sub(1, #v - 4),
            source = v:sub(1, #v - 4) .. ':' .. M.env.fontsDir
        })
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    M.S.fonts = list
end

---Scans everything once. Safe to call repeatedly.
function M.rescanAll()
    M.rescanBrushes()
    M.rescanStickers()
    M.rescanFonts()
end

return M

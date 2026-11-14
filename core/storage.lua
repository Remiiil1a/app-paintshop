-- Persisted settings. `ac.storage` keeps whatever an older version of the app wrote, so every
-- field is re-validated once at load; without that a stale or hand-edited config reaches the
-- UI and the projection code as a wrong type.
--
-- Field names are the persistence keys: renaming one silently drops the user's setting.

---@return table
return function()
    local stored = ac.storage {
        color = rgbm(0, 0.2, 1, 0.5),
        bgColor = rgbm(1, 1, 1, 1),
        orbitCamera = true,
        projectOtherSide = false,
        eyeDropperRange = 1,
        selectedStickerSet = 2,
        alignSticker = 3,
        activeToolIndex = 1,
        selectedFont = '',
        fontBold = false,
        fontItalic = false,
        hasPen = false
    }

    local function asColor(value, fallback)
        if type(value) == 'table' and value.r ~= nil then
            return value
        end
        return fallback
    end

    stored.color = asColor(stored.color, rgbm(0, 0.2, 1, 0.5))
    stored.bgColor = asColor(stored.bgColor, rgbm(1, 1, 1, 1))
    stored.orbitCamera = stored.orbitCamera and true or false
    stored.projectOtherSide = stored.projectOtherSide and true or false
    stored.fontBold = stored.fontBold and true or false
    stored.fontItalic = stored.fontItalic and true or false
    stored.hasPen = stored.hasPen and true or false
    stored.eyeDropperRange = math.clamp(tonumber(stored.eyeDropperRange) or 1, 1, 5)
    stored.alignSticker = math.clamp(tonumber(stored.alignSticker) or 1, 1, 3)
    stored.selectedStickerSet = math.max(tonumber(stored.selectedStickerSet) or 1, 1)
    stored.activeToolIndex = math.max(tonumber(stored.activeToolIndex) or 1, 1)
    stored.selectedFont = type(stored.selectedFont) == 'string' and stored.selectedFont or ''

    return stored
end

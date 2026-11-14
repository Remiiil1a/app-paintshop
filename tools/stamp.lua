-- Stamp tool: places a decal from the sticker library.
--
-- The sticker list can be empty (a user may delete every category or every PNG in one), so
-- the panel bails out with a message instead of indexing a missing entry.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local S, stored, env, widgets, brush, assets = deps.S, deps.stored, deps.env, deps.widgets, deps.brush,
        deps.assets
    local shortcuts = deps.shortcuts

    return {
        name = 'Stamp (S)',
        key = shortcuts.toolStamp,
        icon = deps.icons.Stamp,
        ui = function(s)
            ui.header('Color:')
            widgets.ColorBlock()
            ui.offsetCursorY(20)

            ui.header('Stamp:')
            local stickers = S.stickers or {}
            ui.combo('##set', string.format('Set: %s', S.selectedStickerSet and S.selectedStickerSet.name or 'none'),
                ui.ComboFlags.None, function()
                    for i = 1, #stickers do
                        if ui.selectable(stickers[i].name, stickers[i] == S.selectedStickerSet) then
                            S.selectedStickerSet = stickers[i]
                            stored.selectedStickerSet = i
                        end
                    end
                    if ui.selectable('New category…') then
                        ui.modalPrompt('Create new category', 'Category name:', nil, function(value)
                            if #value > 0 and io.createDir(env.decalsDir .. '/' .. value) then
                                ui.toast(ui.Icons.Confirm, 'New category created: ' .. tostring(value))
                                assets.rescanStickers()
                                S.selectedStickerSet = table.findFirst(S.stickers, function(item)
                                    return item.name == value
                                end)
                            else
                                ui.toast(ui.Icons.Warning, 'Couldn’t create a new category: ' .. tostring(value))
                            end
                        end)
                    end
                end)

            if S.selectedStickerSet == nil then
                ui.textWrapped('No sticker categories found. Add a folder with PNG files to the decals directory.')
                return
            end

            local items = S.selectedStickerSet.items
            if #items == 0 then
                ui.textWrapped('This category has no stickers yet.')
                return
            end
            if s.brush.brushTex == '' then
                s.brush.brushTex = items[1][2]
            end
            ui.childWindow('stickersList', vec2(210, 210), false, ui.WindowFlags.AlwaysVerticalScrollbar, function()
                ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.transparent)
                local itemSize = vec2(100, 60)
                for i = 1, #items do
                    if ui.areaVisible(itemSize) then
                        local size = ui.imageSize(items[i][2])
                        if ui.button('##' .. i, vec2(100, 60),
                            s.brush.brushTex == items[i][2] and ui.ButtonFlags.Active or ui.ButtonFlags.None) then
                            s.brush.brushTex = items[i][2]
                            S.selectedBrushOutlineDirty = true
                        end
                        local iconSize = vec2(90, 90 * size.y / math.max(size.x, 1))
                        if iconSize.y > 54 then
                            iconSize:scale(54 / iconSize.y)
                        end
                        ui.addIcon(items[i][2], iconSize, 0.5, nil, 0)
                        if ui.itemHovered() then
                            ui.setTooltip('Brush: ' .. items[i][1])
                        end
                    else
                        ui.dummy(itemSize)
                    end
                    if i % 2 == 1 then
                        ui.sameLine(0, 0)
                    end
                end
                ui.popStyleColor()
                ui.newLine()
            end)

            local _, i = table.findFirst(items, function(item, _, tex)
                return item[2] == tex
            end, s.brush.brushTex)
            i = i or 0

            if shortcuts.arrowRight() then
                s.brush.brushTex = items[i % #items + 1][2]
                S.selectedBrushOutlineDirty = true
            end

            if shortcuts.arrowDown() then
                s.brush.brushTex = items[(i + 1) % #items + 1][2]
                S.selectedBrushOutlineDirty = true
            end

            if shortcuts.arrowLeft() then
                s.brush.brushTex = items[(i - 2 + #items) % #items + 1][2]
                S.selectedBrushOutlineDirty = true
            end

            if shortcuts.arrowUp() then
                s.brush.brushTex = items[(i - 3 + #items) % #items + 1][2]
                S.selectedBrushOutlineDirty = true
            end

            if ui.itemHovered() then
                ui.setTooltip('Use arrow keys to quickly switch between items')
            end

            ui.itemPopup(function()
                if ui.selectable('Add new decal…') then
                    os.openFileDialog({
                        title = 'Add new decal',
                        defaultFolder = ac.getFolder(ac.FolderID.Root),
                        fileTypes = {{
                            name = 'Images',
                            mask = '*.png'
                        }},
                        addAllFilesFileType = true,
                        flags = bit.bor(os.DialogFlags.PathMustExist, os.DialogFlags.FileMustExist)
                    }, function(err, filename)
                        if filename then
                            local fileName = filename:gsub('.+[/\\\\]', '')
                            if io.copyFile(filename, env.decalsDir .. '/' .. S.selectedStickerSet.name .. '/' .. fileName,
                                true) then
                                local categoryName = S.selectedStickerSet.name
                                assets.rescanStickers()
                                S.selectedStickerSet = table.findFirst(S.stickers, function(item)
                                    return item.name == categoryName
                                end)
                                if S.selectedStickerSet then
                                    s.brush.brushTex = env.decalsDir .. '/' .. categoryName .. '/' .. fileName
                                end
                                ui.toast(ui.Icons.Confirm, 'New decal added: ' .. fileName:sub(1, #fileName - 4))
                                return
                            end
                        end
                        if err or filename then
                            ui.toast(ui.Icons.Warning, 'Couldn’t add a new decal: ' .. (err or 'unknown error'))
                        end
                    end)
                end
                if ui.selectable('Open in Explorer') then
                    os.openInExplorer(env.decalsDir)
                end
                if ui.selectable('Refresh') then
                    assets.rescanStickers()
                end
            end)

            ui.alignTextToFramePadding()
            ui.text('Align sticker:')
            ui.sameLine()
            ui.setNextItemWidth(ui.availableSpaceX())
            stored.alignSticker = ui.combo('##alignSticker', stored.alignSticker, ui.ComboFlags.None,
                {'No', 'Align to surface', 'Fully align'})

            widgets.BrushBaseBlock(s.brush, 4, true)
        end,
        brush = brush.params('stamp', 0.2, 1),
        brushColor = function(s)
            return rgbm.new(stored.color.rgb, s.brush.brushAlpha)
        end,
        brushSize = function(s)
            -- A stamp with no texture yet (empty category) would divide by a zero width.
            local size = s.brush.brushTex ~= '' and ui.imageSize(s.brush.brushTex) or vec2(1, 1)
            if size.x <= 0 then
                size = vec2(1, 1)
            end
            return vec2(s.brush.brushSize, s.brush.brushSize * size.y / size.x)
        end,
        stickerMode = true,
        stickerContinious = false
    }
end

return M

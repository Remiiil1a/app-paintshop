-- Text tool: renders the typed label into a canvas and stamps it.
--
-- The canvas cannot live in `ac.storage` (it is not serializable), so it is kept in tool
-- state and handed to the projection code through `procBrushTex`.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local S, stored, widgets, brush, assets = deps.S, deps.stored, deps.widgets, deps.brush, deps.assets

    return {
        name = 'Text (T)',
        key = deps.shortcuts.toolText,
        icon = deps.icons.Text,
        ui = function(s)
            if S.fonts == nil or #S.fonts == 0 then
                assets.rescanFonts()
            end
            if #S.fonts == 0 then
                ui.textWrapped('No fonts available.')
                return
            end

            local selectedFont = table.findFirst(S.fonts, function(item, _, sf)
                return item.source == sf
            end, stored.selectedFont)
            if selectedFont == nil then
                selectedFont = S.fonts[1]
                stored.selectedFont = selectedFont.source
            end

            ui.header('Color:')
            widgets.ColorBlock()
            ui.offsetCursorY(20)

            ui.beginGroup()
            ui.header('Text:')
            s._labelText = ui.inputText('Text', s._labelText, ui.InputTextFlags.Placeholder)
            if ui.itemEdited() then
                s._labelDirty = true
            end

            ui.combo('##fonts', 'Font: ' .. tostring(selectedFont.name), ui.ComboFlags.None, function()
                for i = 1, #S.fonts do
                    if ui.selectable(S.fonts[i].name, S.fonts[i] == selectedFont) then
                        selectedFont = S.fonts[i]
                        stored.selectedFont, s._labelDirty = selectedFont.source, true
                    end

                    if ui.itemHovered() then
                        ui.tooltip(function()
                            if s._previewCanvas ~= nil then
                                s._previewCanvas:dispose()
                                s._previewCanvas = nil
                            end

                            local font = S.fonts[i].source
                            if stored.fontBold then
                                font = font .. ';Weight=Bold'
                            end
                            if stored.fontItalic then
                                font = font .. ';Style=Italic'
                            end
                            ui.pushDWriteFont(font)
                            local canvasSize = ui.measureDWriteText(s._labelText, 24)
                            canvasSize.x, canvasSize.y = math.max(canvasSize.x, 24), canvasSize.y + 8
                            s._previewCanvas = ui.ExtraCanvas(canvasSize):clear(rgbm.colors.transparent):update(
                                function(dt)
                                    ui.dwriteTextAligned(s._labelText, 24, ui.Alignment.Center,
                                        ui.Alignment.Center, ui.availableSpace(), false, rgbm.colors.white)
                                end)
                            ui.popDWriteFont()
                            ui.image(s._previewCanvas, canvasSize)
                        end)
                    end
                end
            end)
            ui.itemPopup(function()
                if ui.selectable('Open in Explorer') then
                    os.openInExplorer(deps.env.fontsDir)
                end
                if ui.selectable('Refresh') then
                    assets.rescanFonts()
                end
            end)

            if ui.checkbox('Bold', stored.fontBold) then
                stored.fontBold, s._labelDirty = not stored.fontBold, true
            end
            if ui.checkbox('Italic', stored.fontItalic) then
                stored.fontItalic, s._labelDirty = not stored.fontItalic, true
            end
            ui.endGroup()

            if ui.itemHovered() and not s._labelDirty and s._labelCanvas then
                ui.tooltip(function()
                    ui.image(s._labelCanvas, ui.imageSize(s._labelCanvas):scale(0.5))
                end)
            end

            ui.alignTextToFramePadding()
            ui.text('Align text:')
            ui.sameLine()
            ui.setNextItemWidth(ui.availableSpaceX())
            stored.alignSticker = ui.combo('##alignSticker', stored.alignSticker, ui.ComboFlags.None,
                {'No', 'Align to surface', 'Fully align'})

            widgets.BrushBaseBlock(s.brush, 4, true)

            if s._labelDirty then
                if s._labelCanvas then
                    s._labelCanvas:dispose()
                    s._labelCanvas = nil
                end
                local font = selectedFont.source
                if stored.fontBold then
                    font = font .. ';Weight=Bold'
                end
                if stored.fontItalic then
                    font = font .. ';Style=Italic'
                end
                ui.pushDWriteFont(font)
                local fontSize = 256
                local canvasSize = ui.measureDWriteText(s._labelText, fontSize)
                canvasSize.x, canvasSize.y = math.max(canvasSize.x, fontSize), canvasSize.y + fontSize * 0.1
                s._labelCanvas = ui.ExtraCanvas(canvasSize):clear(rgbm.colors.transparent):update(function(dt)
                    ui.dwriteTextAligned(s._labelText, fontSize, ui.Alignment.Center, ui.Alignment.Center,
                        ui.availableSpace(), false, rgbm.colors.white)
                end)
                ui.popDWriteFont()
                s._labelDirty = false
            end
        end,
        -- The label is rendered into a canvas, which cannot be persisted in ac.storage, so it
        -- lives in tool state and is handed to the projection code through procBrushTex.
        procBrushTex = function(s)
            return s._labelCanvas
        end,
        brush = brush.params('text', 0.2, 1),
        brushColor = function(s)
            return rgbm.new(stored.color.rgb, s.brush.brushAlpha)
        end,
        brushSize = function(s)
            local size = s._labelCanvas and ui.imageSize(s._labelCanvas) or vec2(1, 1)
            if size.x <= 0 then
                size = vec2(1, 1)
            end
            return vec2(s.brush.brushSize, s.brush.brushSize * size.y / size.x)
        end,
        stickerMode = true,
        stickerContinious = false,
        blendMode = render.BlendMode.BlendPremultiplied,
        _labelText = ac.getDriverName(0),
        _labelDirty = true,
        _labelCanvas = nil
    }
end

return M

-- Toolbar: undo/redo, open, save, export, finish.
--
-- The canvas is created by the camera update on the first frame of a session, so the toolbar
-- can be drawn before it exists; every canvas-dependent action is disabled until then and
-- re-checked inside the async file dialog callbacks.

local M = {}

---@param deps table
function M.init(deps)
    M.env, M.S, M.stored = deps.env, deps.S, deps.stored
    M.shortcuts, M.icons, M.widgets = deps.shortcuts, deps.icons, deps.widgets
    M.history, M.canvas, M.session, M.renderer = deps.history, deps.canvas, deps.session, deps.renderer
end

local function stripPath(path)
    return string.gsub(path, '.+[/\\:]', '')
end

function M.draw()
    local S, env, stored = M.S, M.env, M.stored
    local title = S.saveFilename or (S.carTexture and (S.carTexture .. ' (new)')) or 'new texture'
    ac.setWindowTitle('paintshop', stripPath(title) .. (S.changesMade ~= 0 and '*' or ''))

    local canvasReady = S.editingCanvas ~= nil

    if M.widgets.IconButton(M.icons.Undo, nil, false, #S.undoStack > 0) or
        #S.undoStack > 0 and M.shortcuts.undo() then
        M.history.undo()
    end
    if ui.itemHovered() then
        ui.setTooltip(string.format('Undo (Ctrl+Z)\n%d steps, %.1f MB', #S.undoStack,
            M.history.memoryFootprint() / (1024 * 1024)))
    end
    ui.sameLine(0, 4)
    if M.widgets.IconButton(M.icons.Redo, string.format('Redo (Ctrl+Y)', #S.redoStack), false, #S.redoStack > 0) or
        #S.redoStack > 0 and M.shortcuts.redo() then
        M.history.redo()
    end
    ui.sameLine(0, 4)
    if M.widgets.IconButton(M.icons.Open,
        'Load image (Ctrl+O)\n\nChoose an image without ambient occlusion, preferably one saved earlier with “Save” button of this tool.\n\nIf you accidentally forgot to save or a crash happened, there are some automatically saved backups\nin “Documents/Assetto Corsa”/cfg/apps/paintshop/autosave”.\n\n(There is also an “Import” option in context menu of this button to add a semi-transparent image on top\nof current one.)') or
        M.shortcuts.load() then
        os.openFileDialog({
            title = 'Open',
            folder = env.skinDir,
            fileTypes = {{
                name = 'Images',
                mask = '*.png;*.jpg;*.jpeg;*.dds'
            }}
        }, function(err, filename)
            if not err and filename and S.editingCanvas then
                ui.setAsynchronousImagesLoading(false)
                M.history.add(S.editingCanvas:backup())
                S.editingCanvas:clear(rgbm.new(stored.bgColor.rgb, 1)):update(function()
                    ui.unloadImage(filename)
                    ui.drawImage(filename, 0, ui.windowSize())
                end)
                setTimeout(M.canvas.updateAccessibleData)
                if not filename:lower():match('%.dds$') then
                    S.saveFilename = filename
                end
                S.changesMade = 0
            end
        end)
    end
    ui.itemPopup('openMenu', function()
        if ui.selectable('Clear canvas') and S.editingCanvas then
            M.history.add(S.editingCanvas:backup())
            S.editingCanvas:clear(rgbm.new(stored.bgColor.rgb, 1))
        end
        if ui.itemHovered() then
            ui.setTooltip('Clears canvas using background (eraser) color')
        end
        if ui.selectable('Import…') then
            os.openFileDialog({
                title = 'Import',
                folder = env.skinDir,
                fileTypes = {{
                    name = 'Images',
                    mask = '*.png;*.jpg;*.jpeg;*.dds'
                }}
            }, function(err, filename)
                if not err and filename and S.editingCanvas then
                    ui.setAsynchronousImagesLoading(false)
                    M.history.add(S.editingCanvas:backup())
                    S.editingCanvas:update(function()
                        ui.unloadImage(filename)
                        ui.drawImage(filename, 0, ui.windowSize())
                    end)
                    setTimeout(M.canvas.updateAccessibleData)
                end
            end)
        end
        if env.autosaveDir and ui.selectable('Open autosaves folder') then
            io.createDir(env.autosaveDir)
            os.openInExplorer(env.autosaveDir)
        end
    end)
    ui.sameLine(0, 4)
    if M.widgets.IconButton(M.icons.Save,
        'Save image (Ctrl+S)\n\nImage saved like that would not have antialiasing or ambient occlusion. To apply texture, use “Export texture”\nbutton on the right.\n\n(There is also a “Save as” option in context menu of this button.)',
        false, canvasReady) or canvasReady and M.shortcuts.save() then
        if S.saveFilename ~= nil then
            S.editingCanvas:save(S.saveFilename)
            S.changesMade = 0
        else
            os.saveFileDialog({
                title = 'Save Image',
                folder = env.skinDir,
                fileTypes = {{
                    name = 'PNG',
                    mask = '*.png'
                }, {
                    name = 'JPEG',
                    mask = '*.jpg;*.jpeg'
                }},
                fileName = S.carTexture and stripPath(S.carTexture):gsub('%.[a-zA-Z]+$', '.png'),
                defaultExtension = 'dds'
            }, function(err, filename)
                if not err and filename and S.editingCanvas then
                    S.editingCanvas:save(filename)
                    S.saveFilename = filename
                    S.changesMade = 0
                end
            end)
        end
    end
    ui.itemPopup('saveMenu', function()
        if ui.selectable('Save as…') then
            os.saveFileDialog({
                title = 'Save Image As',
                folder = env.skinDir,
                fileTypes = {{
                    name = 'PNG',
                    mask = '*.png'
                }, {
                    name = 'JPEG',
                    mask = '*.jpg;*.jpeg'
                }},
                fileName = S.carTexture and stripPath(S.carTexture):gsub('%.[a-zA-Z]+$', '.png'),
                defaultExtension = 'dds'
            }, function(err, filename)
                if not err and filename and S.editingCanvas then
                    S.editingCanvas:save(filename)
                    S.saveFilename = filename
                    S.changesMade = 0
                end
            end)
        end
        if env.autosaveDir and ui.selectable('Open autosaves folder') then
            io.createDir(env.autosaveDir)
            os.openInExplorer(env.autosaveDir)
        end
    end)
    ui.sameLine(0, 4)
    if M.widgets.IconButton(M.icons.Export,
        'Export texture (Ctrl+Shift+Alt+S)\n\nImage saved like that is ready to use, with ambient occlusion and everything. To save an intermediate\nresult and continue working on it later, use “Save” button on the left.',
        false, canvasReady) or canvasReady and M.shortcuts.export() then
        os.saveFileDialog({
            title = 'Export Texture',
            folder = env.skinDir,
            fileTypes = {{
                name = 'PNG',
                mask = '*.png'
            }, {
                name = 'JPEG',
                mask = '*.jpg;*.jpeg'
            }, {
                name = 'DDS',
                mask = '*.dds'
            }},
            fileName = S.carTexture and stripPath(S.carTexture),
            fileTypeIndex = 3,
            defaultExtension = 'dds'
        }, function(err, filename)
            if not err and filename and S.aoCanvas and S.editingCanvas then
                S.aoCanvas:update(function(dt)
                    M.renderer.drawWithAO(S.editingCanvas, S.aoTexture or S.carTexture)
                end):save(filename)
            end
        end)
    end
    ui.sameLine(0, 4)
    if M.widgets.IconButton(ui.Icons.Leave,
        S.changesMade == 0 and 'Finish editing' or 'Cancel editing\nThere are some unsaved changes') then
        if S.changesMade ~= 0 then
            ui.modalPopup('Cancel editing', 'Are you sure to exit without saving changes?', function(okPressed)
                if okPressed then
                    M.session.finish()
                end
            end)
        else
            M.session.finish()
        end
    end
end

return M

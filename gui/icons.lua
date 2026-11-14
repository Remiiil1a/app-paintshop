-- Keyboard shortcuts and the icon atlas.
--
-- Both are created exactly once at load: `ui.shortcut` registers a key binding with the host
-- and `ui.atlasIcons` loads a texture, so re-creating them per frame would leak.

local M = {}

function M.init()
    -- Digit keys 0..9 set brush opacity, Photoshop style. Built as an explicit map keyed by
    -- the digit itself, so the lookup in the brush panel (`shortcuts.opacity[i]`, i = 0..9)
    -- always hits a real entry instead of depending on table.range's index base.
    local opacityShortcuts = {}
    for digit = 0, 9 do
        opacityShortcuts[digit] = ui.shortcut(ui.KeyIndex.D0 + digit)
    end

    M.shortcuts = {
        undo = ui.shortcut({
            key = ui.KeyIndex.Z,
            ctrl = true
        }, ui.KeyIndex.XButton1),
        redo = ui.shortcut({
            key = ui.KeyIndex.Y,
            ctrl = true
        }, ui.KeyIndex.XButton2),
        save = ui.shortcut {
            key = ui.KeyIndex.S,
            ctrl = true
        },
        export = ui.shortcut {
            key = ui.KeyIndex.S,
            ctrl = true,
            shift = true,
            alt = true
        },
        load = ui.shortcut {
            key = ui.KeyIndex.O,
            ctrl = true
        },
        swapColors = ui.shortcut(ui.KeyIndex.X),
        flipSticker = ui.shortcut(ui.KeyIndex.Z),
        toggleSymmetry = ui.shortcut(ui.KeyIndex.Y),
        toggleDrawThrough = ui.shortcut(ui.KeyIndex.R),
        toolBrush = ui.shortcut(ui.KeyIndex.B),
        toolEraser = ui.shortcut(ui.KeyIndex.E),
        toolStamp = ui.shortcut(ui.KeyIndex.S),
        toolMirroringStamp = ui.shortcut(ui.KeyIndex.K),
        toolBlurTool = ui.shortcut({
            key = ui.KeyIndex.B,
            alt = true
        }),
        toolEyeDropper = ui.shortcut(ui.KeyIndex.I),
        toolMasking = ui.shortcut(ui.KeyIndex.M),
        toolText = ui.shortcut(ui.KeyIndex.T),
        toggleMasking = ui.shortcut({
            key = ui.KeyIndex.M,
            ctrl = true
        }),
        toggleOrbitCamera = ui.shortcut({
            key = ui.KeyIndex.Space,
            ctrl = true
        }),
        toggleProjectOtherSide = ui.shortcut({
            key = ui.KeyIndex.E,
            ctrl = true
        }),
        arrowLeft = ui.shortcut(ui.KeyIndex.Left),
        arrowRight = ui.shortcut(ui.KeyIndex.Right),
        arrowUp = ui.shortcut(ui.KeyIndex.Up),
        arrowDown = ui.shortcut(ui.KeyIndex.Down),
        opacity = opacityShortcuts
    }

    M.icons = ui.atlasIcons('res/icons.png', 4, 4, {
        Brush = {1, 1},
        Eraser = {1, 2},
        Undo = {1, 3},
        Redo = {1, 4},
        EyeDropper = {2, 1},
        Camera = {2, 2},
        Save = {2, 3},
        Open = {2, 4},
        Stamp = {3, 1},
        Masking = {3, 2},
        Stencil = {3, 3},
        Export = {3, 4},
        Text = {4, 1},
        MirroringStamp = {4, 2},
        BlurTool = {4, 3},
        MirroringHelper = {4, 4}
    })

    return M
end

return M

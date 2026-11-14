--[[
  Paintshop — drawing on car skins in Assetto Corsa.

  This file is the entry point only: it wires the modules together and forwards the callbacks
  the manifest asks for. The actual work lives in:

    core/   environment, state, storage, canvases, history, projection, painting, session
    tools/  one file per tool plus the registry
    gui/    icons, palette, shared widgets, toolbar, tool panel, 3D gizmo

  Dependency direction is gui -> tools -> core -> AC API. Nothing in core/ may reference a
  tool or a widget.

  Modules are loaded with dofile() against __dirname rather than require(), because the app
  folder is not guaranteed to be on package.path and __dirname is the one path the host
  documents for apps. Each module is loaded exactly once, here.

  The tool contract is documented in core/types.lua.
]]

local appDir = __dirname

---Loads a module file relative to the app folder.
---@param name string path without the .lua extension
---@return any
local function load(name)
    return dofile(appDir .. '/' .. name .. '.lua')
end

local env = load('core/env')(appDir)
local S = load('core/state')()
local stored = load('core/storage')()

local brush = load('core/brush')
local assets = load('core/assets')
local canvas = load('core/canvas')
local history = load('core/history')
local autosave = load('core/autosave')
local camera = load('core/camera')
local masking = load('core/masking')
local projection = load('core/projection')
local renderer = load('core/render')
local painting = load('core/painting')
local selection = load('core/selection')
local session = load('core/session')

local icons = load('gui/icons').init()
local palette = load('gui/palette').init()
local widgets = load('gui/widgets')
local toolbar = load('gui/toolbar')
local toolPanel = load('gui/tool_panel')
local gizmo = load('gui/masking_gizmo')
local registry = load('tools/registry')

assets.init(env, S, stored)
canvas.init(env, S, stored)
history.init(S, canvas)
autosave.init(env, S, canvas)
camera.init(env, S, stored)
masking.init(env, S)
projection.init(env, S, stored, brush, masking)
renderer.init(env, S, stored, projection)
painting.init(env, S, canvas, history, projection, renderer)
selection.init(env, S, camera)
session.init(env, S, canvas, history, camera, projection, masking)

widgets.init({
    env = env,
    S = S,
    stored = stored,
    shortcuts = icons.shortcuts,
    palette = palette,
    assets = assets
})

registry.init({
    env = env,
    S = S,
    stored = stored,
    shortcuts = icons.shortcuts,
    icons = icons.icons,
    widgets = widgets,
    palette = palette,
    brush = brush,
    assets = assets,
    history = history,
    masking = masking,
    projection = projection,
    load = load
})
session.setToolDisposer(registry.disposeResources)

toolbar.init({
    env = env,
    S = S,
    stored = stored,
    shortcuts = icons.shortcuts,
    icons = icons.icons,
    widgets = widgets,
    history = history,
    canvas = canvas,
    session = session,
    renderer = renderer
})

toolPanel.init({
    env = env,
    S = S,
    stored = stored,
    shortcuts = icons.shortcuts,
    icons = icons.icons,
    widgets = widgets,
    registry = registry,
    toolbar = toolbar
})

gizmo.init({env = env, S = S, masking = masking, history = history})

-- Restore the car's original texture when the game is released, so a crash mid-session does
-- not leave the car painted with the editing canvas.
ac.onRelease(function()
    if S.carTexture and S.selectedMeshes then
        S.selectedMeshes:setMaterialTexture('txDiffuse', S.carTexture):setMotionStencil(env.taaFix.Off)
    end
end)

autosave.start()

function script.update(dt)
    if not S.appVisible then
        camera.dispose()
        return
    end
    if S.selectedMeshes ~= nil then
        canvas.ensure()
        camera.update()
    end
end

function script.onWorldUpdate(dt)
    if S.appVisible and S.selectedMeshes ~= nil then
        -- when painting, easier to not wait for async images to load
        ui.setAsynchronousImagesLoading(false)
        -- The world update can run before script.update in a frame, so make sure the canvases
        -- exist before anything tries to draw into them.
        canvas.ensure()
        painting.update(registry.getActive())
    end
end

function script.draw3D()
    gizmo.draw()
end

function script.windowMain(dt)
    if S.brushes == nil then
        assets.rescanAll()
    end

    ui.pushItemWidth(210)
    ui.setAsynchronousImagesLoading(true)
    if S.selectedMeshes == nil then
        selection.draw()
    else
        toolPanel.draw()
    end
    ui.popItemWidth()

    if S.debugTex then
        ui.setShadingOffset(1, 0, 1, 1)
        ui.image(S.debugTex, 210, rgbm.colors.white, rgbm.colors.red)
        ui.resetShadingOffset()
    end
end

function script.onShowWindowMain()
    S.appVisible = true
end

function script.onHideWindowMain()
    S.appVisible = false
    if S.selectedMeshes == nil then
        setTimeout(ac.unloadApp, 1)
    end
end

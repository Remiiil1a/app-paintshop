-- Read-only environment snapshot. Everything here is captured once when the app loads and
-- is never written afterwards, so any module can depend on it without ordering concerns.
--
-- Loaded as a factory: the entry point calls it with the app directory and gets a table back.

---@param appDir string
---@return table
return function(appDir)
    local env = {
        appDir = appDir,

        sim = ac.getSim(),
        uiState = ac.getUI(),
        car = ac.getCar(0),

        carNode = nil, ---@type ac.SceneReference
        carMeshes = nil, ---@type ac.SceneReference

        carDir = '',
        skinDir = '',

        -- Size of every full-resolution canvas (editing, AO and masking). All three have to
        -- match: the masking canvas is sampled through UVs of the editing canvas.
        texSize = vec2(4096, 4096),

        -- Motion stencil values used to keep TAA from smearing the texture while painting.
        taaFix = {On = 1, Off = 0},

        brushesDir = appDir .. '/brushes',
        decalsDir = appDir .. '/decals',
        fontsDir = appDir .. '/fonts',
        autosaveDir = ac.getFolder(ac.FolderID.Cfg) .. '/apps/paintshop/autosave',
    }

    env.carDir = ac.getFolder(ac.FolderID.ContentCars) .. '/' .. ac.getCarID(env.car.index)
    env.skinDir = env.carDir .. '/skins/' .. ac.getCarSkinID(0)
    env.carNode = ac.findNodes('carRoot:0')
    env.carMeshes = env.carNode:findMeshes('{ ! material:DAMAGE_GLASS & lod:A }')

    -- Calling it once at the start to initialize RealTimeStylus API and get Assetto Corsa to
    -- work nicely with pens and styluses (check `ac.getPenPressure()` description for more
    -- information).
    ac.getPenPressure()

    return env
end

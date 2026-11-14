-- Luacheck configuration for the Paintshop Assetto Corsa app.
-- Assetto Corsa injects its own globals and extends math/table/string,
-- so they are declared here instead of being reported as undefined.
-- Note: this luacheck build only accepts plain global names (no `fields` form),
-- so `math`/`table`/`string` are redeclared wholesale to allow AC's extensions.

std = 'lua54'
codes = true
max_line_length = false

-- AC runtime globals (injected by the app host).
read_globals = {
    'ac',
    'ui',
    'render',
    'io',
    'os',
    'vec2',
    'vec3',
    'vec4',
    'rgbm',
    'mat4x4',
    'stringify',
    'bit',
    '__dirname',
    'setTimeout',
    'setInterval',
    'clearInterval',
    'ray',
    'car',
    'sim',
    'uiState',
    'carDir',
    'skinDir',
    'carNode',
    'carMeshes',

    -- Redeclared so AC's extensions (math.cross, table.findFirst, ...) are allowed.
    'math',
    'table',
    'string',
}

-- Callback signatures are fixed by the AC API, so unused `dt`/`s` arguments
-- are expected and not worth reporting.
ignore = { '212' }

-- `script` is a write-only callback sink: the host reads it, the app assigns to it.
files['Paintshop.lua'] = { globals = { 'script' } }

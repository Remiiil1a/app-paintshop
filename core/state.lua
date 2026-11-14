-- The single mutable session state. Every module receives this table instead of closing over
-- file-level locals, so ownership is explicit and teardown is one function call.
--
-- Field groups:
--   session   – what is being edited
--   canvas    – full-resolution canvases and their dirty flags
--   history   – undo/redo stacks
--   masking   – masking plane state
--   painting  – stroke state
--   camera    – grabbed camera and orbit angle
--   assets    – scanned brushes, stickers, fonts
--   ui        – transient widget state

---@return table
return function()
    local S = {}

    -- session
    S.selectedMeshes = nil ---@type ac.SceneReference
    S.carTexture = nil ---@type string
    S.aoTexture = nil ---@type string
    S.saveFilename = nil ---@type string
    S.changesMade = 0
    S.appVisible = false
    S.hoveredMaterial = nil ---@type string
    S.carPreview = nil ---@type ac.GeometryShot

    -- canvas
    S.editingCanvas = nil ---@type ui.ExtraCanvas
    S.aoCanvas = nil ---@type ui.ExtraCanvas
    S.maskingCanvas = nil ---@type ui.ExtraCanvas
    S.selectedBrushOutline = nil ---@type ui.ExtraCanvas
    S.selectedBrushOutlineDirty = true
    S.accessibleData = nil ---@type ui.ExtraCanvasData
    S.canvasPhase = 0

    -- history
    S.undoStack = {}
    S.redoStack = {}

    -- masking
    S.maskingActive = false
    S.maskingPos = vec3(0, 0.3, 0)
    S.maskingDir = vec3(0, 1, 0)
    S.maskingPoints = {vec3(0, 0.3, -1), vec3(0, 0.3, 1), vec3(-1, 0.3, 0), vec3(1, 0.3, 0)}
    S.maskingCreatingFrom = nil ---@type vec3
    S.maskingCreatingTo = nil ---@type vec3
    S.maskingDragging = 0
    S.maskingStartMousePos = nil ---@type vec2
    S.maskingDirty = true

    -- painting
    S.drawing = false
    S.ignoreMousePress = true
    S.lastRay = nil ---@type ray
    S.brushDistance = 1
    S.smoothRayDir = nil ---@type vec3

    -- camera
    S.camera = nil ---@type ac.GrabbedCamera
    S.cameraAngle = vec2(-2.6, 0.1)

    -- assets
    S.brushes = nil
    S.stickers = nil
    S.selectedStickerSet = nil
    S.fonts = nil

    -- ui
    S.debugTex = nil
    S.colorPickerEditing = false

    return S
end

-- Stroke handling: press, drag with interpolation, release.
--
-- A stroke is a sequence of brush stamps placed along the mouse ray. Between two frames the
-- ray moves, so the gap is filled with `steps` interpolated stamps to keep the line solid.
-- Sticker tools place a single stamp and stop.

local M = {}

---@param env table
---@param S table
---@param canvas table core/canvas.lua
---@param history table core/history.lua
---@param projection table core/projection.lua
---@param renderer table core/render.lua
function M.init(env, S, canvas, history, projection, renderer)
    M.env, M.S, M.canvas, M.history, M.projection, M.renderer = env, S, canvas, history, projection, renderer
end

---@param tool table active tool
function M.update(tool)
    local S, env = M.S, M.env
    -- The canvases are created by the camera update, which runs from script.update; the world
    -- update callback can fire first, so nothing here may assume they exist yet.
    if S.editingCanvas == nil or S.selectedMeshes == nil then
        return
    end

    if tool.brush then
        if env.uiState.isMouseLeftKeyDown then
            if S.drawing then
                M.continueStroke(tool)
            elseif not S.ignoreMousePress then
                S.ignoreMousePress = ui.mouseBusy()
                if not S.ignoreMousePress then
                    M.beginStroke(tool)
                end
            end
        else
            if S.drawing then
                M.canvas.updateAccessibleData()
                S.selectedMeshes:setMotionStencil(env.taaFix.Off)
                S.drawing = false
            end
            S.ignoreMousePress = false
        end
    elseif tool.action then
        tool:action()
    end

    M.renderer.updateMaskingCanvas()
    M.renderer.updateAOCanvas(tool)
end

---@param tool table
function M.beginStroke(tool)
    local S, env = M.S, M.env
    S.drawing = true
    S.selectedMeshes:setMotionStencil(env.taaFix.On)
    if not env.uiState.shiftDown then
        S.lastRay = nil
    end
    setTimeout(function()
        -- adding undo in the next frame, so that dragging mask could cancel drawing operation
        if S.drawing and S.editingCanvas then
            M.history.add(S.editingCanvas:backup())
        end
    end)
end

---@param tool table
function M.continueStroke(tool)
    local S, env = M.S, M.env
    local ray = render.createMouseRay()
    local brush = tool.brush
    local tex = tool.procBrushTex and tool:procBrushTex(ray, false) or brush.brushTex
    -- Tools that generate their texture on demand (text, blur) can return nothing on the first
    -- frame; projecting a nil texture would draw garbage.
    if tex == nil or tex == '' then
        return
    end

    S.editingCanvas:update(function()
        local lastBrushDistance = S.brushDistance
        local hitDistance = S.selectedMeshes:raycast(ray)
        if hitDistance ~= -1 then
            S.brushDistance = hitDistance
        end

        if tool.stickerMode then
            M.projection.project(tool, tex, ray.pos, ray.dir, tool:brushColor(), S.brushDistance)
            if not tool.stickerContinious then
                -- projection happens a bit later, so updating data should also be delayed
                setTimeout(M.canvas.updateAccessibleData)
                S.drawing = false
                S.selectedMeshes:setMotionStencil(env.taaFix.Off)
                S.ignoreMousePress = true
            end
            return
        end

        if S.lastRay then
            local color = tool:brushColor()

            if brush.smoothing > 0 then
                -- smoothRayDir is nil on the first frame of a stroke.
                S.smoothRayDir = S.smoothRayDir and
                                     math.applyLag(S.smoothRayDir, ray.dir, brush.smoothing ^ 0.3 * 0.9, 0.02) or
                                     ray.dir:clone()
                ray.dir:set(S.smoothRayDir)
            end

            local distance = ray.pos:clone():addScaled(ray.dir, S.brushDistance):distance(S.lastRay.pos:clone()
                :addScaled(S.lastRay.dir, lastBrushDistance))
            -- A zero step size (possible with an old saved config) would divide by zero.
            local stepSize = math.max(brush.brushStepSize, 1e-4)
            if distance > stepSize then
                local steps = math.min(100, math.floor(0.5 + distance / stepSize))
                for i = 1, steps do
                    local p = math.lerp(S.lastRay.pos, ray.pos, i / steps)
                    local d = math.lerp(S.lastRay.dir, ray.dir, i / steps)
                    M.projection.project(tool, tex, p, d, color,
                        math.lerp(lastBrushDistance, S.brushDistance, i / steps))
                end
                S.lastRay = ray
            end
        else
            M.projection.project(tool, tex, ray.pos, ray.dir, tool:brushColor(), S.brushDistance)
            S.lastRay = ray
        end
        S.smoothRayDir = ray.dir:clone()
    end)
end

return M

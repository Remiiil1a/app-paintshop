-- 3D overlay: the masking plane gizmo and its four draggable control points.

local M = {}

---@param deps table
function M.init(deps)
    M.env, M.S = deps.env, deps.S
    M.masking, M.history = deps.masking, deps.history
end

local function rayPlane(env, ray, opposite)
    local s = opposite and env.car.look or env.car.side
    return ray:plane(env.car.position, s)
end

---@param index integer
---@param point vec3
---@param ray ray
local function draggingPoint(self, index, point, ray)
    local S, env = self.S, self.env
    local pos = env.car.bodyTransform:transformPoint(point)
    local hovered = ray:sphere(pos, 0.04) ~= -1
    render.circle(pos, -ac.getCameraForward(), 0.04,
        rgbm(hovered and env.sim.whiteReferencePoint or 0, env.sim.whiteReferencePoint, env.sim.whiteReferencePoint, 0.3),
        rgbm(0, env.sim.whiteReferencePoint, env.sim.whiteReferencePoint, 1))
    if S.maskingDragging == 0 and env.uiState.isMouseLeftKeyClicked and hovered then
        S.maskingStartMousePos = ui.projectPoint(pos)
        S.maskingDragging = index
        S.ignoreMousePress = true
        S.drawing = false
        S.maskingCreatingFrom = nil
        self.history.add(self.masking.backup())
    elseif S.maskingDragging == index then
        -- maskingStartMousePos is only set when a drag starts, but guard anyway: a stale index
        -- from a previous session would otherwise index nil here.
        if S.maskingStartMousePos == nil then
            S.maskingDragging = 0
            return
        end
        S.maskingStartMousePos:add(env.uiState.mouseDelta)
        local r = render.createPointRay(S.maskingStartMousePos)
        local d = rayPlane(env, r, index > 2)
        if d ~= -1 then
            point:set(env.car.worldToLocal:transformPoint(r.pos + r.dir * d))
        end
    end
end

function M.draw()
    local S, env = M.S, M.env
    if not (S.appVisible and S.selectedMeshes ~= nil and S.maskingActive) then
        return
    end

    if S.maskingCreatingFrom ~= nil and S.maskingCreatingTo ~= nil then
        M.masking.applyQuick(S.maskingCreatingFrom, S.maskingCreatingTo)
        render.circle(env.car.bodyTransform:transformPoint(S.maskingPos),
            env.car.bodyTransform:transformVector(S.maskingDir), 3,
            rgbm(env.sim.whiteReferencePoint, 0, 0, 0.1))
        return
    end

    render.circle(env.car.bodyTransform:transformPoint(S.maskingPos),
        env.car.bodyTransform:transformVector(S.maskingDir), 3,
        rgbm(env.sim.whiteReferencePoint, 0, 0, 0.3))

    local ray = render.createMouseRay()
    if not ui.mouseDown() then
        S.maskingDragging = 0
    end
    render.setDepthMode(render.DepthMode.Off)
    for i = 1, 4 do
        draggingPoint(M, i, S.maskingPoints[i], ray)
    end

    if S.maskingDragging == 1 or S.maskingDragging == 2 then
        M.masking.fitPoints(true)
    elseif S.maskingDragging == 3 or S.maskingDragging == 4 then
        M.masking.fitPoints(false)
    end
end

return M

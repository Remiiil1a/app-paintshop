-- Masking plane: the four draggable control points, the derived plane, and the undo entry
-- that snapshots them.
--
-- The plane normal is the cross product of the two point pairs. Both orthogonal bases used
-- to push the remaining points onto the plane are cross products with that normal, so their
-- Z and X components are proportional to `normal.y`: when the normal is horizontal the plane
-- does not constrain Y at all and the divisions would produce inf/NaN. Those cases are
-- handled explicitly instead of dividing.

local M = {}

---@param env table
---@param S table
function M.init(env, S)
    M.env, M.S = env, S
end

---Rebuilds the plane from the control points.
---@param fitFirst boolean true = points 1/2 define the plane, false = points 3/4 do
function M.fitPoints(fitFirst)
    local S = M.S
    local points = S.maskingPoints
    local normal = math.cross(points[1] - points[2], points[4] - points[3])
    if normal:dot(normal) < 1e-12 then
        -- Control points are collinear: there is no plane to fit.
        return
    end
    S.maskingDir = normal:normalize()

    if math.abs(S.maskingDir.y) < 1e-6 then
        -- Plane is parallel to the Y axis, so Y is unconstrained: keep the points as they are.
        S.maskingPos = fitFirst and (points[1] + points[2]) / 2 or (points[3] + points[4]) / 2
        return
    end

    if fitFirst then
        S.maskingPos = (points[1] + points[2]) / 2
        local ort1 = math.cross(S.maskingDir, vec3(1, 0, 0)):normalize()
        local ort2 = math.cross(S.maskingDir, vec3(0, 0, 1)):normalize()
        points[3] = vec3(points[3].x,
            S.maskingPos.y - S.maskingPos.z * ort1.y / ort1.z + ort2.y * points[3].x / ort2.x, 0)
        points[4] = vec3(points[4].x,
            S.maskingPos.y - S.maskingPos.z * ort1.y / ort1.z + ort2.y * points[4].x / ort2.x, 0)
    else
        S.maskingPos = (points[3] + points[4]) / 2
        local ort2 = math.cross(S.maskingDir, vec3(0, 0, 1)):normalize()
        local ort1 = math.cross(S.maskingDir, vec3(1, 0, 0)):normalize()
        points[1] = vec3(0, S.maskingPos.y - S.maskingPos.x * ort2.y / ort2.x + ort1.y * points[1].z / ort1.z,
            points[1].z)
        points[2] = vec3(0, S.maskingPos.y - S.maskingPos.x * ort2.y / ort2.x + ort1.y * points[2].z / ort1.z,
            points[2].z)
    end
end

---Builds a plane from a quick drag between two points on the model.
---@param from vec3
---@param to vec3
function M.applyQuick(from, to)
    local S = M.S
    local points = S.maskingPoints
    if math.abs(from.x - to.x) < math.abs(from.z - to.z) then
        points[1] = vec3(0, from.y, from.z)
        points[2] = vec3(0, to.y, to.z)
        points[3] = vec3(-1, 0, 0)
        points[4] = vec3(1, 0, 0)
        M.fitPoints(true)
    else
        points[1] = vec3(0, 0, -1)
        points[2] = vec3(0, 0, 1)
        points[3] = vec3(from.x, from.y, 0)
        points[4] = vec3(to.x, to.y, 0)
        M.fitPoints(false)
    end
end

---Snapshot of the masking state, as an undo entry.
---@return function
function M.backup()
    local S = M.S
    local snapshot = stringify({S.maskingPos, S.maskingDir, S.maskingPoints}, true)
    return function(action)
        if action == 'memoryFootprint' then
            return 0
        end
        if action == 'update' then
            return M.backup()
        end
        if action == 'dispose' then
            return
        end
        S.maskingPos, S.maskingDir, S.maskingPoints = table.unpack(stringify.parse(snapshot))
        S.maskingActive = true
    end
end

---Resets the plane to its default position.
function M.reset()
    local S = M.S
    S.maskingPos = vec3(0, 0.3, 0)
    S.maskingDir = vec3(0, 1, 0)
    S.maskingPoints = {vec3(0, 0.3, -1), vec3(0, 0.3, 1), vec3(-1, 0.3, 0), vec3(1, 0.3, 0)}
    S.maskingCreatingFrom, S.maskingCreatingTo = nil, nil
    S.maskingDragging = 0
    S.maskingStartMousePos = nil
    S.maskingDirty = true
end

return M

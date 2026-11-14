-- Grabbed camera and orbit controls.
--
-- The camera is grabbed when a mesh is selected and released with a short fade so the
-- transition is not jarring. `ownShare` is the blend weight; the camera is disposed once it
-- reaches zero.

local M = {}

---@param env table
---@param S table
---@param stored table
function M.init(env, S, stored)
    M.env, M.S, M.stored = env, S, stored
end

---Grabs the camera for a new session.
function M.grab()
    local S = M.S
    S.camera = ac.grabCamera('Paintshop')
    if S.camera then
        S.camera.ownShare = 0
    end
end

---Fades the camera out and disposes it. Used when a session ends.
function M.release()
    local S = M.S
    if not S.camera then
        return
    end
    local camera = S.camera
    local releaseID
    releaseID = setInterval(function()
        -- The camera may have been disposed elsewhere (hiding the window does that), in which
        -- case this interval has nothing left to fade.
        if S.camera ~= camera then
            clearInterval(releaseID)
            return
        end
        camera.ownShare = math.applyLag(camera.ownShare, 0, 0.85, ac.getDeltaT())
        if camera.ownShare < 0.001 then
            clearInterval(releaseID)
            camera:dispose()
            S.camera = nil
        end
    end)
end

---Drops the camera immediately, without the fade.
function M.dispose()
    local S = M.S
    if S.camera then
        S.camera:dispose()
        S.camera = nil
    end
end

---Per-frame camera update: orbit angle, position and blend weight.
function M.update()
    local S, env, stored = M.S, M.env, M.stored
    if S.camera then
        local mat = mat4x4.rotation(S.cameraAngle.y, vec3(1, 0, 0)):mul(mat4x4.rotation(S.cameraAngle.x,
            vec3(0, 1, 0))):mul(env.car.bodyTransform)
        S.camera.transform.position = mat:transformPoint(vec3(0, env.car.aabbCenter.y *
            math.smoothstep(math.lerpInvSat(S.cameraAngle.y, 0.5, 0)), -8))
        S.camera.transform.look = mat:transformVector(vec3(0, 0, 1))
        S.camera.transform.up = mat:transformVector(vec3(0, 1, 0))
        S.camera.fov = 24

        S.camera.ownShare = math.applyLag(S.camera.ownShare, stored.orbitCamera and 1 or 0, 0.85, ac.getDeltaT())
        if stored.orbitCamera and
            (ui.keyboardButtonDown(ui.KeyIndex.Space) or ui.mouseDown(ui.MouseButton.Middle)) then
            S.cameraAngle:add(env.uiState.mouseDelta * vec2(-0.003, 0.003))
        end
        if not stored.orbitCamera and S.camera.ownShare < 0.001 then
            S.camera:dispose()
            S.camera = nil
        end
    elseif stored.orbitCamera then
        M.grab()
    end
end

return M

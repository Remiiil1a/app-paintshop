-- Masking tool: toggles the masking plane and lets the user drag a new one on the model.

local M = {}

---@param deps table
---@return table tool
function M.create(deps)
    local S, env, masking, history = deps.S, deps.env, deps.masking, deps.history

    return {
        name = 'Masking (M)',
        key = deps.shortcuts.toolMasking,
        icon = deps.icons.Masking,
        ui = function(s)
            if ui.checkbox('Masking is active', S.maskingActive) then
                S.maskingActive = not S.maskingActive
            end
            if ui.itemHovered() then
                ui.setTooltip('Toggle masking (Ctrl+M)')
            end

            ui.textWrapped(
                'Masking tool is a plane separating model in two halves. When you draw a thing, it would only get drawn on the side of a plane with camera. Might help in masking things quickly. For something more complex, use stencils.\n\nClick model and drag mouse to quickly create a new plane.\n\nPro tip: when using brush, hold M for more than 0.2 seconds: tool will switch to masking temporary, so you can quickly put a mask and go back to brush by releasing M.')
        end,
        action = function(s)
            if S.selectedMeshes == nil then
                return
            end
            local ray = render.createMouseRay()
            local d = S.selectedMeshes:raycast(ray)
            if d ~= -1 then
                s._d = d
            end
            if d ~= -1 and env.uiState.isMouseLeftKeyClicked then
                S.maskingCreatingFrom = env.car.worldToLocal:transformPoint(ray.pos + ray.dir * d)
                s._moving = false
            elseif S.maskingCreatingFrom then
                -- When the cursor leaves the mesh mid-drag, raycast returns -1; fall back to the
                -- last hit distance instead of projecting a point behind the camera.
                local hitDistance = d ~= -1 and d or s._d
                if not env.uiState.isMouseLeftKeyDown then
                    if s._moving and hitDistance then
                        local endingPos = env.car.worldToLocal:transformPoint(ray.pos + ray.dir * hitDistance)
                        masking.applyQuick(S.maskingCreatingFrom, endingPos)
                        s._moving = false
                    end
                    S.maskingCreatingFrom, S.maskingCreatingTo = nil, nil
                end
                if not s._moving and #ui.mouseDragDelta() > 0 then
                    history.add(masking.backup())
                    s._moving = true
                    S.maskingActive = true
                end
                if s._moving and hitDistance then
                    S.maskingCreatingTo = env.car.worldToLocal:transformPoint(ray.pos + ray.dir * hitDistance)
                end
            end
        end
    }
end

return M

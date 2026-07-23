-- ═══════════════════════════════════════════════════════════════════════
--                           CAMERA SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

CameraSystem = {}

CameraSystem.activeCamera = nil
CameraSystem.currentPosition = 'face'
-- Locked coords/heading captured at Create time so the angle never shifts
CameraSystem.lockedCoords  = nil
CameraSystem.lockedHeading = nil
CameraSystem.dofActive     = false

-- ── Zoom state ───────────────────────────────────────────────────────
-- User-controlled FOV override via scroll wheel on the ped drag zone.
-- Resets on every SetPosition call so each camera preset (face/upper/
-- full/etc.) starts at its intended framing.
CameraSystem.currentFov = nil  -- nil = fall back to Config.Camera.DefaultFov

local ZOOM_MIN_FOV = 20.0  -- tight zoom — see small details (tattoos, makeup)
local ZOOM_MAX_FOV = 65.0  -- slight zoom-out — broader context
local ZOOM_STEP    = 3.0   -- degrees per wheel tick

-- ── Vertical pan state ──────────────────────────────────────────────
-- User-controlled vertical offset applied to both camCoords.z and
-- pointAtCoords.z so the camera slides up/down along the ped while the
-- view stays level (pure crane-camera pan, not tilt). Reset on every
-- SetPosition the same way zoom is.
CameraSystem.baseCoords        = nil
CameraSystem.basePointAt       = nil
CameraSystem.verticalPanOffset = 0.0

local PAN_MIN_OFFSET = -0.6  -- metres below the preset (toward feet)
local PAN_MAX_OFFSET =  0.8  -- metres above the preset (toward head)
local PAN_STEP       =  0.04 -- metres per drag tick (matches rotation DRAG_THRESHOLD feel)

-- ── Wall / prop collision avoidance ──────────────────────────────────────
-- The camera sits a fixed distance in front of the ped. In a tight interior that
-- can land it inside — or behind — a wall or prop. Streaming already stays put
-- (the creator focuses the ped, see main.lua), but the SHOT still looks wrong from
-- inside a wall, so we pull the lens in to just short of anything between the ped
-- and the desired camera spot.

local CAM_COLLISION_MARGIN = 0.25   -- metres to keep the lens off the surface
local CAM_MIN_DISTANCE     = 0.5    -- never frame the subject closer than this

-- Pure: origin (at the ped), the desired camera point, and where the ray hit a
-- surface → where the camera should actually sit. Pulled in short of the wall but
-- never past a minimum framing distance, and never PAST the desired point.
local function PullInFromHit(fromCoords, toCoords, hitCoords)
    local dir  = toCoords - fromCoords
    local dist = #dir
    if dist < 0.001 then return toCoords end
    local nrm     = dir / dist
    local hitDist = #(hitCoords - fromCoords)
    local newDist = hitDist - CAM_COLLISION_MARGIN
    if newDist >= dist then return toCoords end     -- hit is beyond the camera: fine
    if newDist < CAM_MIN_DISTANCE then newDist = CAM_MIN_DISTANCE end
    return fromCoords + (nrm * newDist)
end
CameraSystem._PullInFromHit = PullInFromHit  -- exposed for tests

-- Cast from the look-at point (on the ped) to the desired camera spot; if a wall
-- or prop is in the way, return a pulled-in position. Ignores the subject ped.
local function ClampToCollision(fromCoords, toCoords)
    local ignore = CameraSystem.subjectPed or PlayerPedId()
    -- flags: 1 = world/map, 16 = objects/props (NOT peds or vehicles).
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x,   toCoords.y,   toCoords.z,
        1 + 16, ignore, 4)
    local _, hit, hitCoords = GetShapeTestResult(handle)
    if hit and hit ~= 0 then
        return PullInFromHit(fromCoords, toCoords, vector3(hitCoords.x, hitCoords.y, hitCoords.z))
    end
    return toCoords
end

function CameraSystem.Create(ped)
    if not DoesEntityExist(ped) then
        return false
    end

    CameraSystem.Destroy()

    -- Ped the camera frames — used to ignore it in collision probes.
    CameraSystem.subjectPed = ped

    -- Lock the ped's position and heading at creation so all subsequent
    -- SetPosition calls use the same angle
    CameraSystem.lockedCoords  = GetEntityCoords(ped)
    CameraSystem.lockedHeading = GetEntityHeading(ped)

    CameraSystem.activeCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(CameraSystem.activeCamera, true)
    SetCamNearClip(CameraSystem.activeCamera, 0.05)
    RenderScriptCams(true, false, 0, true, true)

    CameraSystem.SetPosition('face', ped)

    if Config.Debug then
        print('[CameraSystem] Camera created')
    end

    return true
end

-- Duration in ms for camera transitions between positions
local CAMERA_TRANSITION_MS = 600

-- Internal: compute camera coords + pointAt from a position key
local function ComputeCameraCoords(position, anchorCoords, anchorHeading)
    local camData = Config.Camera.Positions[position] or Config.Camera.Positions.Face
    local angleRad = math.rad(anchorHeading)

    local offsetX = camData.offset.x * math.cos(angleRad) - camData.offset.y * math.sin(angleRad)
    local offsetY = camData.offset.x * math.sin(angleRad) + camData.offset.y * math.cos(angleRad)

    local camCoords = vector3(
        anchorCoords.x + offsetX,
        anchorCoords.y + offsetY,
        anchorCoords.z + camData.offset.z
    )

    local pointAtCoords = vector3(
        anchorCoords.x,
        anchorCoords.y,
        anchorCoords.z + camData.pointAt.z
    )

    return camCoords, pointAtCoords
end

-- Internal: compute and apply camera from explicit anchor coords+heading
-- Apply DOF settings to a camera if blur is active
local function ApplyDof(cam)
    if CameraSystem.dofActive then
        SetCamUseShallowDofMode(cam, true)
        SetCamNearDof(cam, 0.3)
        SetCamFarDof(cam, 3.5)
        SetCamDofStrength(cam, 1.0)
    end
end

local function ApplyCameraPosition(position, anchorCoords, anchorHeading, smooth)
    local camCoords, pointAtCoords = ComputeCameraCoords(position, anchorCoords, anchorHeading)

    -- Keep the lens out of walls/props between the ped and the desired spot.
    camCoords = ClampToCollision(pointAtCoords, camCoords)

    local fov = Config.Camera.DefaultFov

    -- Reset any user zoom when switching presets — each camera position is
    -- framed intentionally, user zoom is re-applied only within a preset.
    CameraSystem.currentFov = nil

    -- Cache base coords for AdjustVerticalPan and reset the pan offset so
    -- each preset starts at its intended framing.
    CameraSystem.baseCoords        = camCoords
    CameraSystem.basePointAt       = pointAtCoords
    CameraSystem.verticalPanOffset = 0.0

    -- Smooth interpolation: create a new cam and lerp from old to new
    if smooth and CameraSystem.activeCamera then
        local newCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(newCam, camCoords.x, camCoords.y, camCoords.z)
        PointCamAtCoord(newCam, pointAtCoords.x, pointAtCoords.y, pointAtCoords.z)
        SetCamFov(newCam, fov)
        SetCamNearClip(newCam, 0.05)

        ApplyDof(newCam)
        SetCamActiveWithInterp(newCam, CameraSystem.activeCamera, CAMERA_TRANSITION_MS, 1, 1)

        -- Destroy the old camera after the transition finishes
        local oldCam = CameraSystem.activeCamera
        CameraSystem.activeCamera = newCam
        CameraSystem.currentPosition = position

        SetTimeout(CAMERA_TRANSITION_MS + 100, function()
            if DoesCamExist(oldCam) then
                DestroyCam(oldCam, false)
            end
        end)
    else
        -- Instant snap (first placement or no smooth requested)
        SetCamCoord(CameraSystem.activeCamera, camCoords.x, camCoords.y, camCoords.z)
        PointCamAtCoord(CameraSystem.activeCamera, pointAtCoords.x, pointAtCoords.y, pointAtCoords.z)
        SetCamFov(CameraSystem.activeCamera, fov)
        ApplyDof(CameraSystem.activeCamera)
        CameraSystem.currentPosition = position
    end
end

-- Anchor coords used when pedPosition is set — camera orbits this point, not the real ped
CameraSystem.anchorCoords  = nil
CameraSystem.anchorHeading = nil

function CameraSystem.SetPosition(position, ped)
    if not CameraSystem.activeCamera or not DoesEntityExist(ped) then
        return false
    end

    -- Priority: explicit anchor > locked (from Create) > live ped (fallback)
    local coords  = CameraSystem.anchorCoords  or CameraSystem.lockedCoords  or GetEntityCoords(ped)
    local heading = CameraSystem.anchorHeading or CameraSystem.lockedHeading or GetEntityHeading(ped)

    -- Smooth transition when changing between positions, instant on first set
    local smooth = CameraSystem.currentPosition ~= nil and CameraSystem.currentPosition ~= position
    ApplyCameraPosition(position, coords, heading, smooth)

    if Config.Debug then
        print(string.format('[CameraSystem] Camera position set to: %s', position))
    end

    return true
end

-- Set an explicit anchor point so the camera orbits a fixed location independent of ped position
function CameraSystem.SetAnchor(coords, heading)
    CameraSystem.anchorCoords  = coords
    CameraSystem.anchorHeading = heading
end

function CameraSystem.ClearAnchor()
    CameraSystem.anchorCoords  = nil
    CameraSystem.anchorHeading = nil
end

function CameraSystem.Destroy()
    if CameraSystem.activeCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(CameraSystem.activeCamera, false)
        CameraSystem.activeCamera  = nil
        CameraSystem.lockedCoords  = nil
        CameraSystem.lockedHeading = nil
        CameraSystem.subjectPed    = nil

        if Config.Debug then
            print('[CameraSystem] Camera destroyed')
        end
    end
end

-- Place camera at an explicit world position, looking at an explicit point.
-- Used when caller computes coords directly (e.g. barber chair with known heading).
function CameraSystem.SetCoordsDirectly(camPos, lookAt)
    if not CameraSystem.activeCamera then return false end
    SetCamCoord(CameraSystem.activeCamera, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(CameraSystem.activeCamera, lookAt.x, lookAt.y, lookAt.z)
    SetCamFov(CameraSystem.activeCamera, Config.Camera.DefaultFov)
    return true
end

function CameraSystem.IsActive()
    return CameraSystem.activeCamera ~= nil
end

function CameraSystem.GetCurrentPosition()
    return CameraSystem.currentPosition
end

-- Adjust FOV by wheel-tick delta. Positive = zoom in, negative = zoom out.
-- Clamped to [ZOOM_MIN_FOV, ZOOM_MAX_FOV]. Zoom is reset automatically on
-- every SetPosition so switching presets re-frames the camera cleanly.
function CameraSystem.AdjustZoom(delta)
    if not CameraSystem.activeCamera then return end
    local base = CameraSystem.currentFov or Config.Camera.DefaultFov
    -- Subtract: higher FOV = wider angle = zoomed OUT, so a positive delta
    -- (user scrolled up / wanted zoom-in) must DECREASE the FOV.
    local newFov = base - (delta * ZOOM_STEP)
    if newFov < ZOOM_MIN_FOV then newFov = ZOOM_MIN_FOV end
    if newFov > ZOOM_MAX_FOV then newFov = ZOOM_MAX_FOV end
    CameraSystem.currentFov = newFov
    SetCamFov(CameraSystem.activeCamera, newFov)
end

-- Slide the camera up/down while keeping the view level. Both camCoords.z
-- and pointAtCoords.z get shifted by the accumulated offset so the angle
-- doesn't tilt — it's a crane-camera pan along the ped's vertical axis.
-- Positive delta = camera moves UP (reveals more of the head / upper body).
-- Negative delta = camera moves DOWN (reveals more of the feet / lower body).
-- Clamped to [PAN_MIN_OFFSET, PAN_MAX_OFFSET] metres from the preset base.
function CameraSystem.AdjustVerticalPan(delta)
    if not CameraSystem.activeCamera or not CameraSystem.baseCoords then return end
    local newOffset = CameraSystem.verticalPanOffset + (delta * PAN_STEP)
    if newOffset < PAN_MIN_OFFSET then newOffset = PAN_MIN_OFFSET end
    if newOffset > PAN_MAX_OFFSET then newOffset = PAN_MAX_OFFSET end
    CameraSystem.verticalPanOffset = newOffset

    local bc = CameraSystem.baseCoords
    local bp = CameraSystem.basePointAt
    local lookAt = vector3(bp.x, bp.y, bp.z + newOffset)
    local target = ClampToCollision(lookAt, vector3(bc.x, bc.y, bc.z + newOffset))
    SetCamCoord(CameraSystem.activeCamera, target.x, target.y, target.z)
    PointCamAtCoord(CameraSystem.activeCamera, lookAt.x, lookAt.y, lookAt.z)
end


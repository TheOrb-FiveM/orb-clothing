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
CameraSystem.baseCoords          = nil
CameraSystem.basePointAt         = nil
CameraSystem.verticalPanOffset   = 0.0
CameraSystem.horizontalPanOffset = 0.0

-- True only during a smooth preset interp (see ApplyCameraPosition). The ownership
-- guard skips this window so it can't snap the blend short.
CameraSystem.transitioning       = false

local PAN_MIN_OFFSET = -0.6  -- metres below the preset (toward feet)
local PAN_MAX_OFFSET =  0.8  -- metres above the preset (toward head)
local PAN_STEP       =  0.04 -- metres per drag tick (matches rotation DRAG_THRESHOLD feel)

local HPAN_MIN_OFFSET = -1.0  -- metres to the left of the preset
local HPAN_MAX_OFFSET =  1.0  -- metres to the right of the preset
local HPAN_STEP       =  0.05 -- metres per drag tick

-- ── Wall / prop collision avoidance ──────────────────────────────────────
-- The camera sits a fixed distance in front of the ped. In a tight interior that
-- can land it inside — or behind — a wall or prop. Streaming already stays put
-- (the creator focuses the ped, see main.lua), but the SHOT still looks wrong from
-- inside a wall, so we pull the lens in to just short of anything between the ped
-- and the desired camera spot.

local CAM_COLLISION_MARGIN = 0.3    -- metres to keep the lens off the surface
local CAM_MIN_DISTANCE     = 0.5    -- preferred minimum framing distance
local CAM_ABS_MIN_DISTANCE = 0.2    -- hard floor when a wall forces a tighter shot
                                    -- (better a very close shot than clipping through)

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
    -- Prefer the min framing distance, but NEVER go past the wall: a camera behind
    -- the wall is judged outside the room and the whole interior culls ("disappears").
    -- If the wall is closer than the min, accept the tighter shot instead of clipping.
    if newDist > CAM_MIN_DISTANCE then
        -- room to spare: nothing to do
    elseif hitDist - CAM_COLLISION_MARGIN >= CAM_ABS_MIN_DISTANCE then
        newDist = math.max(CAM_ABS_MIN_DISTANCE, hitDist - CAM_COLLISION_MARGIN)
    else
        newDist = CAM_ABS_MIN_DISTANCE
    end
    return fromCoords + (nrm * newDist)
end
CameraSystem._PullInFromHit = PullInFromHit  -- exposed for tests

-- Portal-culling guard. A camera that lands OUTSIDE the ped's MLO interior (behind
-- a wall / past the room bounds) makes the engine cull the whole interior — it just
-- vanishes. The geometry ray above can miss this (e.g. a lateral pan slides the lens
-- sideways past a wall the ped→cam ray never crossed). So: if the ped is in an
-- interior and the chosen camera point is NOT in that same interior, step back toward
-- the ped until it is. Purely defensive — it only ever pulls the lens IN, and if it
-- can't confirm an inside point (flaky native) it keeps the geometry-clamped spot.
local function KeepInInterior(fromCoords, camCoords, pedInterior)
    if GetInteriorAtCoords(camCoords.x, camCoords.y, camCoords.z) == pedInterior then
        return camCoords
    end
    local dir  = camCoords - fromCoords
    local dist = #dir
    if dist < 0.001 then return camCoords end
    local nrm = dir / dist
    local d = dist - 0.1
    while d > CAM_ABS_MIN_DISTANCE do
        local p = fromCoords + (nrm * d)
        if GetInteriorAtCoords(p.x, p.y, p.z) == pedInterior then
            return p
        end
        d = d - 0.1
    end
    return camCoords   -- never found an inside point → don't over-tighten
end

-- Cast from the look-at point (on the ped) to the desired camera spot; if a wall
-- or prop is in the way, return a pulled-in position. Ignores the subject ped.
-- Then keep the lens inside the ped's interior so the room can't cull.
local function ClampToCollision(fromCoords, toCoords)
    local subject = CameraSystem.subjectPed or PlayerPedId()
    -- flags: 1 = world/map, 16 = objects/props (NOT peds or vehicles).
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        fromCoords.x, fromCoords.y, fromCoords.z,
        toCoords.x,   toCoords.y,   toCoords.z,
        1 + 16, subject, 4)
    local _, hit, hitCoords = GetShapeTestResult(handle)
    local cam = toCoords
    if hit and hit ~= 0 then
        cam = PullInFromHit(fromCoords, toCoords, vector3(hitCoords.x, hitCoords.y, hitCoords.z))
    end

    -- Only relevant inside an MLO — outdoors GetInteriorFromEntity is 0, nothing culls.
    local pedInterior = GetInteriorFromEntity(subject)
    if pedInterior and pedInterior ~= 0 then
        cam = KeepInInterior(fromCoords, cam, pedInterior)
    end
    return cam
end

-- Anchor world/interior STREAMING + culling to the camera position. The engine
-- renders and portal-culls a scripted cam from where the CAMERA is; when we instead
-- pinned focus to the ped (SetFocusEntity), the interior stayed loaded but rendered
-- CULLED from the camera's viewpoint until the camera moved — which is why nudging
-- the pan "fixed" it. Focusing the camera keeps the room both loaded AND rendered,
-- refreshed every time the camera is (re)positioned. The camera is kept inside the
-- interior by ClampToCollision/KeepInInterior, so this never focuses into the void.
-- Cleared by ClearFocus() in CloseCreator.
local function FocusOnCamera(camCoords)
    SetFocusPosAndVel(camCoords.x, camCoords.y, camCoords.z, 0.0, 0.0, 0.0)
end

-- Force the engine to recompute interior/portal occlusion for the scripted camera.
-- WHY: fivem-appearance / illenium customize the ped IN PLACE (open, already-streamed
-- spot) so their static camera renders the room fine. We teleport the ped to a
-- configured store spot — often near a wall/prop — inside a private routing bucket,
-- behind the entry fade. A scripted camera created in that state can leave the room
-- CULLED (interior "breaks"/goes black) until it MOVES, which is exactly why the user
-- found that panning fixes it. We reproduce that motion: a brief slide toward the
-- subject (into the room, so it can't clip the wall behind) and back, over a few
-- frames while the entry fade still hides it. The movement makes the engine re-evaluate
-- occlusion and the interior pops in.
function CameraSystem.NudgeToRefresh()
    local cam = CameraSystem.activeCamera
    if not cam or not DoesCamExist(cam) or not CameraSystem.baseCoords or not CameraSystem.basePointAt then return end
    local bc = CameraSystem.baseCoords
    local bp = CameraSystem.basePointAt
    local dir = vector3(bp.x - bc.x, bp.y - bc.y, bp.z - bc.z)
    local len = #dir
    if len < 0.001 then return end
    dir = dir / len
    CreateThread(function()
        for i = 6, 1, -1 do
            local k = 0.04 * i   -- 24cm → 4cm toward the subject, easing back in
            SetCamCoord(cam, bc.x + dir.x * k, bc.y + dir.y * k, bc.z + dir.z * k)
            FocusOnCamera(vector3(bc.x + dir.x * k, bc.y + dir.y * k, bc.z + dir.z * k))
            Wait(0)
        end
        SetCamCoord(cam, bc.x, bc.y, bc.z)
        PointCamAtCoord(cam, bp.x, bp.y, bp.z)
        FocusOnCamera(bc)
    end)
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
        -- Keep in sync with the toggleBlur callback (which drives SetUseHiDof per frame).
        SetCamUseShallowDofMode(cam, true)
        SetCamNearDof(cam, 0.4)
        SetCamFarDof(cam, 3.5)
        SetCamDofStrength(cam, 1.5)
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

    -- Cache base coords for the pan helpers and reset BOTH pan offsets so each
    -- preset starts at its intended framing.
    CameraSystem.baseCoords          = camCoords
    CameraSystem.basePointAt         = pointAtCoords
    CameraSystem.verticalPanOffset   = 0.0
    CameraSystem.horizontalPanOffset = 0.0

    -- Keep interior streaming + culling anchored to the new camera spot.
    FocusOnCamera(camCoords)

    -- Smooth interpolation: create a new cam and lerp from old to new
    if smooth and CameraSystem.activeCamera then
        local newCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(newCam, camCoords.x, camCoords.y, camCoords.z)
        PointCamAtCoord(newCam, pointAtCoords.x, pointAtCoords.y, pointAtCoords.z)
        SetCamFov(newCam, fov)
        SetCamNearClip(newCam, 0.05)

        ApplyDof(newCam)
        CameraSystem.transitioning = true
        SetCamActiveWithInterp(newCam, CameraSystem.activeCamera, CAMERA_TRANSITION_MS, 1, 1)

        -- Destroy the old camera after the transition finishes
        local oldCam = CameraSystem.activeCamera
        CameraSystem.activeCamera = newCam
        CameraSystem.currentPosition = position

        SetTimeout(CAMERA_TRANSITION_MS + 100, function()
            CameraSystem.transitioning = false
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

-- Re-assert OUR camera as the one being rendered. In the character-creation flow
-- the multicharacter (e.g. Exo) tears down its OWN selector camera a beat AFTER it
-- hands off to us, and that teardown calls RenderScriptCams(false), which is GLOBAL
-- and also kills OUR scripted camera. The player then drops back to the gameplay
-- (third-person) camera with the creator UI still open, and zoom/pan die. Reclaim
-- rendering whenever our cam is not the one showing. No-op when nothing fights us.
function CameraSystem.EnsureOwnership()
    local cam = CameraSystem.activeCamera
    if not cam or not DoesCamExist(cam) then return end
    if CameraSystem.transitioning then return end
    if GetRenderingCam() ~= cam then
        RenderScriptCams(true, false, 0, true, true)
        SetCamActive(cam, true)
    end
end

-- Per-frame ownership guard, active ONLY while a creator camera exists. It reclaims
-- rendering within a single frame of any external RenderScriptCams(false), so the
-- multicharacter's late selector-camera teardown can't detach us. Cheap: one
-- GetRenderingCam compare per frame while open, and it sleeps when no creator is up.
CreateThread(function()
    while true do
        if CameraSystem.activeCamera then
            CameraSystem.EnsureOwnership()
            Wait(0)
        else
            Wait(500)
        end
    end
end)

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

    CameraSystem._ApplyPanOffsets()
end

-- Slide the camera sideways, perpendicular to the view direction. The camera
-- shifts opposite the drag so the PED appears to move with it: delta > 0 → the ped
-- slides RIGHT in frame (camera pans left), delta < 0 → left. Clamped to [HPAN_MIN, HPAN_MAX].
function CameraSystem.AdjustHorizontalPan(delta)
    if not CameraSystem.activeCamera or not CameraSystem.baseCoords then return end
    local newOffset = CameraSystem.horizontalPanOffset + (delta * HPAN_STEP)
    if newOffset < HPAN_MIN_OFFSET then newOffset = HPAN_MIN_OFFSET end
    if newOffset > HPAN_MAX_OFFSET then newOffset = HPAN_MAX_OFFSET end
    CameraSystem.horizontalPanOffset = newOffset

    CameraSystem._ApplyPanOffsets()
end

-- Compose BOTH pan offsets onto the preset base and push to the camera. Both
-- axes MUST route through here — each recomputes from baseCoords, so applying one
-- inline would wipe the other. Horizontal shifts along the flattened right-vector
-- (perpendicular to the view), so the view stays parallel (a lateral crane, not a yaw).
function CameraSystem._ApplyPanOffsets()
    if not CameraSystem.activeCamera or not CameraSystem.baseCoords then return end

    local bc = CameraSystem.baseCoords
    local bp = CameraSystem.basePointAt
    local v  = CameraSystem.verticalPanOffset
    local h  = CameraSystem.horizontalPanOffset

    -- Flattened forward (XY) → right vector = rotate forward 90°.
    local forward = vector3(bp.x - bc.x, bp.y - bc.y, 0.0)
    local len = math.sqrt(forward.x * forward.x + forward.y * forward.y)
    if len > 0.001 then
        forward = vector3(forward.x / len, forward.y / len, 0.0)
    else
        forward = vector3(1.0, 0.0, 0.0)
    end
    local right = vector3(-forward.y, forward.x, 0.0)

    local lookAt = vector3(bp.x + right.x * h, bp.y + right.y * h, bp.z + v)
    local camPos = vector3(bc.x + right.x * h, bc.y + right.y * h, bc.z + v)
    local target = ClampToCollision(lookAt, camPos)
    SetCamCoord(CameraSystem.activeCamera, target.x, target.y, target.z)
    PointCamAtCoord(CameraSystem.activeCamera, lookAt.x, lookAt.y, lookAt.z)
    -- Follow the pan with the streaming focus so the interior stays rendered.
    FocusOnCamera(target)
end


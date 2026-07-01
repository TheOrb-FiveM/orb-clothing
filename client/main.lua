-- ═══════════════════════════════════════════════════════════════════════
--                          MAIN CLIENT SCRIPT
-- ═══════════════════════════════════════════════════════════════════════

local isCreatorOpen  = false
local isClosing      = false
local isFirstTime    = false
local creatorPed     = nil
local originalCoords = nil
local originalHeading = nil
local wasSaved       = false
local pinnedInterior = nil

-- Current store context (nil when opened via /tc command)
local activeStoreContext = nil

-- Full ped appearance snapshot taken when the store opens.
-- Restored on cancel (ESC) so that trying-on changes don't persist.
-- Format: { components={[0..11]={d,t}}, props={[0..7]={d,t}},
--           hairStyle, hairColors={primary,highlight},
--           overlays={[0..12]={variation,opacity,color,secondColor}},
--           faceFeatures={[0..19]=value},
--           eyeColor, headBlend={...}, tattoos={...} }
local appearanceSnapshot = nil

-- Props removed on barber entry so hair is fully visible; restored on exit
-- Format: { [propId] = { drawable, texture } }
local barberPropSnapshot = nil

-- Whether the player is currently sitting in a barber chair
local isSeatedInChair = false

-- Prop IDs to hide in the barber (hat=0, glasses=1)
local BARBER_HIDDEN_PROPS = { 0, 1 }

-- Clothing/props stripped at tattoo entry so tattoos are visible; restored on exit
-- Format: { components = { [id] = {d,t} }, props = { [id] = {d,t} } }
local tattooClothingSnapshot = nil

-- All prop IDs to strip for tattoo preview (hat=0, glasses=1, earrings=2, watch=6, bracelet=7)
local TATTOO_STRIP_PROPS = { 0, 1, 2, 6, 7 }
-- All clothing component IDs (to snapshot before stripping)
local TATTOO_SNAPSHOT_COMPONENTS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
-- Per-zone naked component overrides and camera positions.
-- Only components that need to change from the snapshot are listed.
-- camera matches Config.Camera.Positions keys.
local TATTOO_ZONE_CONFIG = {
    ZONE_TORSO = {
        camera = 'upper',
        male   = { [3]=15, [5]=0, [7]=0, [8]=15, [9]=0, [10]=0, [11]=15 }, -- bare torso
        female = { [3]=15, [5]=0, [7]=0, [8]=14, [9]=0, [10]=0, [11]=14 },
    },
    ZONE_LEFT_ARM = {
        camera = 'upper',
        male   = { [3]=15, [5]=0, [7]=0, [8]=15, [9]=0, [10]=0, [11]=15 },
        female = { [3]=15, [5]=0, [7]=0, [8]=14, [9]=0, [10]=0, [11]=14 },
    },
    ZONE_RIGHT_ARM = {
        camera = 'upper',
        male   = { [3]=15, [5]=0, [7]=0, [8]=15, [9]=0, [10]=0, [11]=15 },
        female = { [3]=15, [5]=0, [7]=0, [8]=14, [9]=0, [10]=0, [11]=14 },
    },
    ZONE_HEAD = {
        camera = 'face',
        male   = { [1]=0 },   -- just remove mask, keep shirt
        female = { [1]=0 },
    },
    ZONE_HAIR = {
        camera = 'face',
        male   = { [1]=0 },
        female = { [1]=0 },
    },
    ZONE_LEFT_LEG = {
        camera = 'lower',
        male   = { [4]=14, [5]=0 },  -- remove pants (14=invisible for male pants)
        female = { [4]=14, [5]=0 },
    },
    ZONE_RIGHT_LEG = {
        camera = 'lower',
        male   = { [4]=14, [5]=0 },
        female = { [4]=14, [5]=0 },
    },
}

-- Applies a zone's naked overrides to the ped without touching the snapshot
local function applyTattooZoneStrip(ped, zone)
    local cfg = TATTOO_ZONE_CONFIG[zone]
    if not cfg then return end
    local overrides = Config.IsMale(ped) and cfg.male or cfg.female
    -- First restore snapshot components, then apply only this zone's overrides
    if tattooClothingSnapshot then
        for compId, snap in pairs(tattooClothingSnapshot.components) do
            SetPedComponentVariation(ped, compId, snap.d, snap.t, 2)
        end
    end
    for compId, drawable in pairs(overrides) do
        SetPedComponentVariation(ped, compId, drawable, 0, 2)
    end
    -- Props always stay cleared regardless of zone
    for _, propId in ipairs(TATTOO_STRIP_PROPS) do
        ClearPedProp(ped, propId)
    end
    -- Move camera
    if cfg.camera then
        CameraSystem.SetPosition(cfg.camera, ped)
    end
end

-- Exposed for nui_callbacks.lua
function TattooZoneChanged(zone)
    if not tattooClothingSnapshot then return end
    applyTattooZoneStrip(PlayerPedId(), zone)
end

-- Exposed so nui_callbacks.lua (loaded before main.lua) can read it at call-time
function GetActiveStoreContext()
    return activeStoreContext
end

-- Exposed so interaction.lua can check if the creator is open
function IsCreatorOpen()
    return isCreatorOpen
end

-- Signal that the current session was saved (called by nui_callbacks before close)
function MarkSessionSaved()
    wasSaved = true
end

-- ── BuildAutoCounts ──────────────────────────────────────────────────
-- Queries FiveM natives for the actual drawable / prop / overlay counts
-- available on the given ped, so the NUI renders cards for EVERY slot
-- the engine can address — including add-on clothing packs that extend
-- vanilla drawable ranges.
--
-- Returns a { sectionId = count } table keyed by Config.UIMapping section
-- IDs, which the JS side merges into getExtendedCount() alongside the
-- manual Config.CustomClothing overrides.
--
-- Called from OpenCreator (initial load) and from nui_callbacks when the
-- player switches gender, because freemode M/F peds expose different
-- drawable ranges and add-on packs often differ per gender.
--
-- Exposed as a global (no `local`) so nui_callbacks.lua can call it at
-- runtime — fxmanifest load order is nui_callbacks.lua → main.lua, and
-- event-handler bodies run after both files are fully loaded.
function BuildAutoCounts(ped)
    if not ped or not DoesEntityExist(ped) then return {} end

    local counts = {}
    for sectionId, mapping in pairs(Config.UIMapping or {}) do
        local t = mapping.type

        if t == 'clothing' and mapping.componentId ~= nil then
            local n = GetNumberOfPedDrawableVariations(ped, mapping.componentId)
            if n and n > 0 then counts[sectionId] = n end

        elseif t == 'prop' and mapping.propId ~= nil then
            local n = GetNumberOfPedPropDrawableVariations(ped, mapping.propId)
            if n and n > 0 then
                -- Props with gameOffset = -1 reserve UI slot 0 for "remove",
                -- so the UI-facing card count is native count + 1.
                counts[sectionId] = n + (mapping.gameOffset == -1 and 1 or 0)
            end

        elseif t == 'hair' then
            -- Hair lives on component 2 on freemode peds
            local n = GetNumberOfPedDrawableVariations(ped, 2)
            if n and n > 0 then counts[sectionId] = n end

        elseif t == 'overlay' and mapping.overlayId ~= nil then
            -- Head overlays (beard, eyebrows, lipstick, blush)
            local n = GetNumHeadOverlayValues(mapping.overlayId)
            if n and n > 0 then counts[sectionId] = n end
        end
    end

    return counts
end

-- ── Full ped appearance snapshot ────────────────────────────────────────
-- Captures every visual aspect of the ped so we can revert on cancel/ESC.

local function TakeAppearanceSnapshot(ped)
    if not DoesEntityExist(ped) then return nil end

    local snap = { components = {}, props = {}, overlays = {}, faceFeatures = {} }

    -- Clothing components 0-11
    for i = 0, 11 do
        snap.components[i] = {
            d = GetPedDrawableVariation(ped, i),
            t = GetPedTextureVariation(ped, i)
        }
    end

    -- Props 0-7
    for i = 0, 7 do
        snap.props[i] = {
            d = GetPedPropIndex(ped, i),
            t = GetPedPropTextureIndex(ped, i)
        }
    end

    -- Hair
    snap.hairStyle = GetPedDrawableVariation(ped, 2)
    snap.hairColors = {
        primary   = GetPedHairColor(ped),
        highlight = GetPedHairHighlightColor(ped)
    }

    -- Head overlays 0-12
    for i = 0, 12 do
        local success, overlayValue, colourType, firstColour, secondColour, overlayOpacity = GetPedHeadOverlayData(ped, i)
        if success then
            snap.overlays[i] = {
                variation   = overlayValue,
                opacity     = overlayOpacity,
                color       = firstColour,
                secondColor = secondColour
            }
        end
    end

    -- Face features 0-19
    for i = 0, 19 do
        snap.faceFeatures[i] = GetPedFaceFeature(ped, i)
    end

    -- Eye color
    snap.eyeColor = GetPedEyeColor(ped)

    -- Head blend (heritage)
    local hasBlend, shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix = GetPedHeadBlendData(ped)
    if hasBlend then
        snap.headBlend = {
            shapeFirst = shapeFirst, shapeSecond = shapeSecond, shapeThird = shapeThird,
            skinFirst = skinFirst, skinSecond = skinSecond, skinThird = skinThird,
            shapeMix = shapeMix, skinMix = skinMix, thirdMix = thirdMix
        }
    end

    -- Tattoos (copy from DataCache — can't read decorations from ped natively)
    local existingTattoos = DataCache.GetTattoos()
    snap.tattoos = {}
    for _, t in ipairs(existingTattoos) do
        snap.tattoos[#snap.tattoos + 1] = { collection = t.collection, hash = t.hash }
    end

    return snap
end

local function RestoreAppearanceSnapshot(ped, snap)
    if not DoesEntityExist(ped) or not snap then return end

    -- Clothing components
    for i = 0, 11 do
        local c = snap.components[i]
        if c then
            SetPedComponentVariation(ped, i, c.d, c.t, 2)
        end
    end

    -- Props
    for i = 0, 7 do
        local p = snap.props[i]
        if p then
            if p.d >= 0 then
                SetPedPropIndex(ped, i, p.d, p.t, true)
            else
                ClearPedProp(ped, i)
            end
        end
    end

    -- Hair style (component 2 is already restored above, but set color separately)
    if snap.hairColors then
        SetPedHairColor(ped, snap.hairColors.primary, snap.hairColors.highlight)
    end

    -- Head blend (heritage)
    if snap.headBlend then
        local hb = snap.headBlend
        SetPedHeadBlendData(ped, hb.shapeFirst, hb.shapeSecond, hb.shapeThird,
            hb.skinFirst, hb.skinSecond, hb.skinThird,
            hb.shapeMix, hb.skinMix, hb.thirdMix, false)
    end

    -- Head overlays
    for i = 0, 12 do
        local o = snap.overlays[i]
        if o then
            SetPedHeadOverlay(ped, i, o.variation, o.opacity)
            local colorType = 0
            if i == 1 or i == 2 or i == 10 then
                colorType = 1
            elseif i == 4 or i == 5 or i == 8 then
                colorType = 2
            end
            SetPedHeadOverlayColor(ped, i, colorType, o.color, o.secondColor)
        end
    end

    -- Face features
    for i = 0, 19 do
        if snap.faceFeatures[i] then
            SetPedFaceFeature(ped, i, snap.faceFeatures[i])
        end
    end

    -- Eye color
    if snap.eyeColor then
        SetPedEyeColor(ped, snap.eyeColor)
    end

    -- Tattoos
    ClearPedDecorations(ped)
    if snap.tattoos then
        for _, t in ipairs(snap.tattoos) do
            AddPedDecorationFromHashes(ped, GetHashKey(t.collection), GetHashKey(t.hash))
        end
        DataCache.StoreTattoos(snap.tattoos)
    end
end

local function DebugPrint(message)
    if Config.Debug then
        print('[orb-clothing] ' .. message)
    end
end

-- Reset ped appearance to the snapshot taken when the menu opened
function ResetToSnapshot()
    local ped = PlayerPedId()
    if appearanceSnapshot and DoesEntityExist(ped) then
        RestoreAppearanceSnapshot(ped, appearanceSnapshot)
        DebugPrint('Appearance reset to entry snapshot')
    end
end

-- ── Barber camera (Nation Barbershop approach) ──────────────────────────
-- Uses GetOffsetFromEntityInWorldCoords so the camera is always positioned
-- relative to the ped's facing direction — no manual heading math needed.

local BARBER_CAM_PRESETS = {
    face = { coords = vector3(-0.15, 0.65, 0.12),  bone = 'IK_Head' },
    head = { coords = vector3(-0.10, 0.50, 0.07), bone = 'IK_Head' },
    full = { coords = vector3(0.0, 1.0, 0.15),  bone = 'IK_Head' },
}

function CreateBarberCamera(ped, preset)
    local cam = BARBER_CAM_PRESETS[preset] or BARBER_CAM_PRESETS.face
    local boneIdx    = GetEntityBoneIndexByName(ped, cam.bone)
    local boneCoords = GetWorldPositionOfEntityBone(ped, boneIdx)

    -- XY from ped-relative offset (automatically uses ped heading), Z from bone + preset offset
    local worldPos = GetOffsetFromEntityInWorldCoords(ped, cam.coords.x, cam.coords.y, 0.0)
    local camZ     = boneCoords.z + cam.coords.z

    local newCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', worldPos.x, worldPos.y, camZ, 0, 0, 0, 50.0)
    SetCamNearClip(newCam, 0.05)
    -- Point slightly above the head bone so the camera looks at the face, not the chest
    PointCamAtCoord(newCam, boneCoords.x, boneCoords.y, boneCoords.z + 0.12)
    SetCamActive(newCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Store in CameraSystem so Destroy/transitions still work
    if CameraSystem.activeCamera and DoesCamExist(CameraSystem.activeCamera) then
        DestroyCam(CameraSystem.activeCamera, false)
    end
    CameraSystem.activeCamera = newCam
    CameraSystem.currentPosition = preset
end

-- ── Barber chair animations ──────────────────────────────────────────────

local BARBER_ANIM_DICT = 'misshair_shop@barbers'

local function PlayAnimAndWait(ped, dict, anim, duration)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, -1, 1, 0, false, false, false)
    Wait(duration)
end

-- chairData: { coords, h, offset, dict (optional), anim (optional) }
local function SeatInBarberChair(ped, chairData)
    isSeatedInChair = true

    local chairCoords = chairData.coords
    local chairHeading = chairData.h
    local chairOffset = chairData.offset or vector3(0.03, -0.7, 0.0)

    -- Idle dict/anim — some chairs use custom sitting animations
    local idleDict = chairData.dict or BARBER_ANIM_DICT
    local idleAnim = chairData.anim or 'player_base'

    RequestAnimDict(BARBER_ANIM_DICT)
    while not HasAnimDictLoaded(BARBER_ANIM_DICT) do Wait(10) end
    if idleDict ~= BARBER_ANIM_DICT then
        RequestAnimDict(idleDict)
        while not HasAnimDictLoaded(idleDict) do Wait(10) end
    end

    -- Position ped at chair, set heading, then move to start position (beside/behind chair)
    SetEntityCoordsNoOffset(ped, chairCoords.x, chairCoords.y, chairCoords.z, false, false, false)
    SetEntityHeading(ped, chairHeading)
    FreezeEntityPosition(ped, true)
    Wait(50)

    -- Start position: offset to the side so enter animation doesn't clip through the chair
    local startCoords = GetOffsetFromEntityInWorldCoords(ped, 0.45, -0.7, 0.0)
    SetEntityCoordsNoOffset(ped, startCoords.x, startCoords.y, startCoords.z, false, false, false)

    -- Disable collision during sit animation to prevent clipping with chair geometry
    SetEntityCollision(ped, false, false)

    -- Play enter animation
    PlayAnimAndWait(ped, BARBER_ANIM_DICT, 'player_enterchair', 1700)

    -- Move to final sitting offset
    local finalCoords = GetOffsetFromEntityInWorldCoords(ped, chairOffset.x, chairOffset.y, chairOffset.z)
    SetEntityCoordsNoOffset(ped, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false)

    -- Re-enable collision, play idle sit animation
    SetEntityCollision(ped, true, true)
    TaskPlayAnim(ped, idleDict, idleAnim, 2.0, 2.0, -1, 1, 0, false, false, false)
    FreezeEntityPosition(ped, true)
end

local function StandFromBarberChair(ped)
    if not isSeatedInChair then return end

    -- Calculate exit position (forward from chair) while still frozen in place
    local exitCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.7, 0.0)

    -- Keep frozen during exit animation so ped doesn't fall through the floor
    FreezeEntityPosition(ped, true)

    -- Play exit animation
    PlayAnimAndWait(ped, BARBER_ANIM_DICT, 'player_exitchair', 1800)

    -- Move to exit position, then unfreeze
    SetEntityCoordsNoOffset(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false)
    FreezeEntityPosition(ped, false)

    ClearPedTasks(ped)
    ClearFacialIdleAnimOverride(ped)
    RemoveAnimDict(BARBER_ANIM_DICT)

    isSeatedInChair = false
end

-- ── Creator open/close ───────────────────────────────────────────────────

local function OpenCreator(appearanceData, storeContext)
    if isCreatorOpen then
        DebugPrint('Creator already open')
        return
    end

    activeStoreContext = storeContext  -- may be nil for /tc
    wasSaved = false

    -- Move player to their own routing bucket so others can't interfere
    -- Skip for barber shops — routing bucket unloads the interior
    if not (storeContext and storeContext.chair) then
        TriggerServerEvent('orb-clothing:server:enterBucket')
    end

    -- Hide HUD and minimap
    Bridge.HideHUD()
    DisplayRadar(false)

    local playerPed = PlayerPedId()

    originalCoords  = GetEntityCoords(playerPed)
    originalHeading = GetEntityHeading(playerPed)

    creatorPed = playerPed

    -- Snapshot the full ped appearance BEFORE any changes so we can revert on cancel
    appearanceSnapshot = TakeAppearanceSnapshot(playerPed)

    -- Teleport ped to the store's pedPosition so the camera frames them correctly.
    -- Skip for barber chairs — SeatInBarberChair handles positioning.
    if storeContext and storeContext.pedPosition and not storeContext.chair then
        local pp = storeContext.pedPosition

        -- Force-stream collision + interior at the target coords BEFORE teleporting.
        -- Without this, stores whose pedPosition falls inside a GTA interior shell
        -- spawn the player into empty/ungrounded space because the interior hasn't
        -- been streamed in (map streaming only triggers at entry points, not teleports).
        RequestCollisionAtCoord(pp.x, pp.y, pp.z)
        NewLoadSceneStart(pp.x, pp.y, pp.z, 0.0, 0.0, 0.0, 20.0, 0)

        SetEntityCoordsNoOffset(creatorPed, pp.x, pp.y, pp.z, false, false, false)
        SetEntityHeading(creatorPed, pp.w)
        FreezeEntityPosition(creatorPed, true)

        -- Pin the interior if the pedPosition is inside one, so it doesn't
        -- unload during the routing-bucket swap on enterBucket.
        local interiorId = GetInteriorAtCoords(pp.x, pp.y, pp.z)
        if interiorId and interiorId ~= 0 then
            LoadInterior(interiorId)
            PinInteriorInMemory(interiorId)
            local waited = 0
            while not IsInteriorReady(interiorId) and waited < 2000 do
                Wait(50)
                waited = waited + 50
            end
            pinnedInterior = interiorId
        end

        if IsNewLoadSceneActive() then NewLoadSceneStop() end
        Wait(50)
    end
    CameraSystem.ClearAnchor()

    -- Skip initial camera for barber chairs — CreateBarberCamera handles it after sitting
    local isBarberChair = storeContext and storeContext.chair
    if not isBarberChair then
        CameraSystem.Create(creatorPed)
    end

    FreezeEntityPosition(creatorPed, true)

    -- Disable idle/ambient animations so the ped stands perfectly still
    -- Skip for barber chairs — the sitting animation handles this
    if not (storeContext and storeContext.chair) then
        ClearPedTasks(creatorPed)
        ClearPedSecondaryTask(creatorPed)
        SetPedCanPlayAmbientAnims(creatorPed, false)
        SetPedCanPlayAmbientBaseAnims(creatorPed, false)
        SetPedCanPlayGestureAnims(creatorPed, false)
        SetPedConfigFlag(creatorPed, 36, true)   -- CPED_CONFIG_FLAG_BlockNonTemporaryEvents
        TaskStandStill(creatorPed, -1)
    end

    if appearanceData then
        AppearanceSystem.ApplyFullAppearance(creatorPed, appearanceData.appearance)
        HairSystem.ApplyFullHair(creatorPed, appearanceData.hair)
        ClothingSystem.ApplyFullClothing(creatorPed, appearanceData.clothing, appearanceData.props)
        TattooSystem.ApplyTattoos(creatorPed, appearanceData.tattoos)
    end

    -- Build openUI message
    local storeName = nil
    if storeContext then
        local st = Config.StoreTypes[storeContext.storeType]
        storeName = storeContext.label or (st and st.blip and st.blip.name) or nil
    end
    local msg = {
        action      = 'openUI',
        isFirstTime = isFirstTime,
        storeType   = storeContext and storeContext.storeType or nil,
        storeName   = storeName,
        selections  = appearanceData and appearanceData.selections or {},
        sliders     = appearanceData and appearanceData.sliders    or {},
        numbers     = appearanceData and appearanceData.numbers    or {},
    }

    -- Send pricing data to NUI when opening a store (not /tc creator)
    if storeContext and Config.Pricing and Config.Pricing.enabled then
        local multiplier = Config.Pricing.storeMultiplier[storeContext.storeType] or 1.0
        msg.pricing = {
            enabled    = true,
            items      = Config.Pricing.items,
            multiplier = multiplier,
        }
    end

    -- Send custom ped list to NUI (only in full creator, not stores)
    if not storeContext and Config.CustomPeds and Config.CustomPeds.enabled and PedModels then
        msg.customPeds = PedModels
    end

    -- Send custom clothing overrides (add-on drawable images/labels/counts)
    if Config.CustomClothing then
        msg.customClothing = Config.CustomClothing
    end

    -- Auto-detect drawable/prop/overlay counts from the creator ped so add-on
    -- packs render in the UI out of the box without manual Config.CustomClothing
    -- entries. Re-queried on gender swap via nui_callbacks.lua.
    msg.autoCounts = BuildAutoCounts(creatorPed)

    -- If a store context is provided, filter tabs and set opening camera
    if storeContext then
        msg.allowedTabs = storeContext.allowedTabs
        msg.allowedSubs = storeContext.allowedSubs
        if storeContext.openCamera and not isBarberChair then
            CameraSystem.SetPosition(storeContext.openCamera, creatorPed)
        end

        -- Barber: snapshot and remove hat + glasses so hair is fully visible
        if storeContext.storeType == 'barber' then
            barberPropSnapshot = {}
            for _, propId in ipairs(BARBER_HIDDEN_PROPS) do
                local drawable = GetPedPropIndex(creatorPed, propId)
                local texture  = GetPedPropTextureIndex(creatorPed, propId)
                barberPropSnapshot[propId] = { drawable = drawable, texture = texture }
                ClearPedProp(creatorPed, propId)
            end
            DebugPrint('Barber: hat/glasses removed (snapshot saved)')

            -- Sit in barber chair if a chair was selected
            if storeContext.chair then
                SeatInBarberChair(creatorPed, storeContext.chair)

                -- Re-create camera using Nation Barbershop approach:
                -- GetOffsetFromEntityInWorldCoords positions camera relative to ped's
                -- facing direction, so it automatically ends up in front of the face.
                CameraSystem.Destroy()
                CameraSystem.ClearAnchor()
                CreateBarberCamera(creatorPed, storeContext.openCamera or 'face')
            end
        end

        -- Tattoo: snapshot all clothing + props, apply initial zone strip (Torso), send list to NUI
        if storeContext.storeType == 'tattoo' then
            tattooClothingSnapshot = { components = {}, props = {} }
            -- Snapshot all components
            for _, compId in ipairs(TATTOO_SNAPSHOT_COMPONENTS) do
                tattooClothingSnapshot.components[compId] = {
                    d = GetPedDrawableVariation(creatorPed, compId),
                    t = GetPedTextureVariation(creatorPed, compId)
                }
            end
            -- Snapshot all props
            for _, propId in ipairs(TATTOO_STRIP_PROPS) do
                tattooClothingSnapshot.props[propId] = {
                    d = GetPedPropIndex(creatorPed, propId),
                    t = GetPedPropTextureIndex(creatorPed, propId)
                }
            end
            -- Apply initial zone strip (Torso is default first tab)
            applyTattooZoneStrip(creatorPed, 'ZONE_TORSO')
            msg.tattooList = TattooSystem.GetTattooList()
            -- Send already-applied tattoos so NUI can mark them as active (REMOVE button)
            local existingTattoos = DataCache.GetTattoos()
            local activeTattooKeys = {}
            for _, t in ipairs(existingTattoos) do
                activeTattooKeys[t.collection .. ':' .. t.hash] = true
            end
            msg.activeTattoos = activeTattooKeys
            DebugPrint('Tattoo: clothing stripped for ZONE_TORSO, tattoo list sent to NUI')
        end
    end

    -- Outfits config (costs/cap) for the Outfits tab. The list itself is lazy-
    -- fetched by the NUI via the 'outfitListRequest' callback so OpenCreator
    -- never blocks on a server round-trip.
    if Config.Outfits and Config.Outfits.enabled then
        msg.outfitConfig = {
            enabled      = true,
            max          = Config.Outfits.maxPerPlayer,
            saveCost     = Config.Outfits.saveCost,
            applyCost    = Config.Outfits.applyCost,
            shareEnabled = Config.Outfits.shareEnabled,
        }
    end

    SetNuiFocus(true, true)
    SendNUIMessage(msg)

    isCreatorOpen = true

    DebugPrint('Creator opened' .. (storeContext and (' [' .. storeContext.storeType .. ']') or ' [/tc]'))
end

local function CloseCreator()
    if not isCreatorOpen or isClosing then
        return
    end

    isClosing = true
    DebugPrint('Closing creator...')

    -- Clean up scene effects (DOF blur + light)
    CameraSystem.dofActive = false
    local cam = CameraSystem.activeCamera
    if cam then
        SetCamUseShallowDofMode(cam, false)
        SetCamDofStrength(cam, 0.0)
    end
    SceneEffects.DisableLight()

    -- Restore HUD and minimap
    Bridge.ShowHUD()
    DisplayRadar(true)

    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'hideUI' })

    Wait(100)

    local currentPed = PlayerPedId()

    -- Stand up from barber chair BEFORE destroying camera so the transition isn't visible
    local wasInChair = isSeatedInChair
    if DoesEntityExist(currentPed) and isSeatedInChair then
        StandFromBarberChair(currentPed)
    end

    CameraSystem.Destroy()
    CameraSystem.ClearAnchor()

    if DoesEntityExist(currentPed) then
        FreezeEntityPosition(currentPed, false)

        -- Re-enable idle/ambient animations
        ClearPedTasks(currentPed)
        SetPedCanPlayAmbientAnims(currentPed, true)
        SetPedCanPlayAmbientBaseAnims(currentPed, true)
        SetPedCanPlayGestureAnims(currentPed, true)
        SetPedConfigFlag(currentPed, 36, false)

        -- If the player cancelled (ESC) without saving, revert all appearance changes
        if not wasSaved and appearanceSnapshot then
            RestoreAppearanceSnapshot(currentPed, appearanceSnapshot)
            DebugPrint('Appearance reverted (cancel/ESC)')
        end

        -- Teleport ped back — skip for barber chairs (ped is already standing next to the chair)
        if not wasInChair then
            if originalCoords then
                SetEntityCoordsNoOffset(currentPed, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false)
            end
            if originalHeading then
                SetEntityHeading(currentPed, originalHeading)
            end
        end
    end

    if creatorPed and creatorPed ~= currentPed and DoesEntityExist(creatorPed) then
        FreezeEntityPosition(creatorPed, false)
    end

    DataCache.Clear()
    -- Do NOT reset scale — it is part of the saved character appearance

    -- Restore hat/glasses removed at barber entry (only matters on save — on cancel the full snapshot already restored them)
    if wasSaved and barberPropSnapshot then
        local ped = PlayerPedId()
        for propId, snap in pairs(barberPropSnapshot) do
            if snap.drawable >= 0 then
                SetPedPropIndex(ped, propId, snap.drawable, snap.texture, true)
            end
        end
        DebugPrint('Barber: hat/glasses restored (after save)')
    end
    barberPropSnapshot = nil

    -- Restore clothing stripped at tattoo entry (only matters on save — on cancel the full snapshot already restored them)
    if wasSaved and tattooClothingSnapshot then
        local ped = PlayerPedId()
        for compId, snap in pairs(tattooClothingSnapshot.components) do
            SetPedComponentVariation(ped, compId, snap.d, snap.t, 2)
        end
        for propId, snap in pairs(tattooClothingSnapshot.props) do
            if snap.d >= 0 then
                SetPedPropIndex(ped, propId, snap.d, snap.t, true)
            end
        end
        DebugPrint('Tattoo: clothing restored (after save)')
    end
    tattooClothingSnapshot = nil

    -- Unpin interior if we pinned one for the barber
    if pinnedInterior then
        UnpinBarberInterior(pinnedInterior)
        pinnedInterior = nil
    end

    -- Return player to the default routing bucket
    TriggerServerEvent('orb-clothing:server:exitBucket')

    appearanceSnapshot = nil
    activeStoreContext = nil
    creatorPed         = nil
    isCreatorOpen      = false
    isClosing          = false
    wasSaved           = false
    isSeatedInChair    = false

    DebugPrint('Creator closed')
end

-- ── Client events ─────────────────────────────────────────────────────────

-- Fired by interaction.lua when player enters a store and presses E
AddEventHandler('orb-clothing:client:openCreator', function(storeContext)
    OpenCreator(nil, storeContext)
end)

-- Net event (from server) and local event (from NUI callbacks via TriggerEvent)
RegisterNetEvent('orb-clothing:client:close', function()
    CloseCreator()
end)

-- Apply appearance data directly onto the ped (e.g. from server push)
RegisterNetEvent('orb-clothing:client:applyAppearance', function(data)
    local playerPed = PlayerPedId()

    if data.appearance then AppearanceSystem.ApplyFullAppearance(playerPed, data.appearance) end
    if data.hair       then HairSystem.ApplyFullHair(playerPed, data.hair)                   end
    if data.clothing   then ClothingSystem.ApplyFullClothing(playerPed, data.clothing, data.props) end
    if data.tattoos    then TattooSystem.ApplyTattoos(playerPed, data.tattoos)               end

    DebugPrint('Appearance applied from server')
end)

-- ── Outfits ───────────────────────────────────────────────────────────────
-- Expose the player's pre-store position so the share picker can sort targets
-- (the store teleports the ped, so its current coords are useless for "nearest").
function GetCreatorOriginCoords()
    return originalCoords
end

-- Apply an outfit pushed from the server (after a successful apply / share-accept).
RegisterNetEvent('orb-clothing:client:applyOutfitData', function(outfit)
    if not outfit then return end
    local ped = PlayerPedId()
    if OutfitSystem.GenderMismatch(ped, outfit) then
        lib.notify({ title = L('outfit_title'), description = L('outfit_gender_mismatch'), type = 'inform' })
    end
    OutfitSystem.Apply(ped, outfit)

    -- Sync NUI selections so the clothing/accessory cards highlight the applied
    -- items when the player switches back to those tabs.
    local sel = {}
    for sectionId, mapping in pairs(Config.UIMapping or {}) do
        if mapping.type == 'clothing' and mapping.componentId ~= nil then
            local item = outfit.components and outfit.components[tostring(mapping.componentId)]
            if item then sel[sectionId] = item.d end
        elseif mapping.type == 'prop' and mapping.propId ~= nil then
            local item = outfit.props and outfit.props[tostring(mapping.propId)]
            if item then sel[sectionId] = item.d - (mapping.gameOffset or 0) end
        end
    end
    SendNUIMessage({ action = 'mergeSelections', selections = sel })
end)

-- Server pushed a fresh outfit list (after save / rename / delete / share-accept).
RegisterNetEvent('orb-clothing:client:outfitsUpdated', function(outfits)
    SendNUIMessage({ action = 'outfitList', outfits = outfits or {} })
end)

-- Localized result toast for an outfit action + re-enable NUI buttons.
RegisterNetEvent('orb-clothing:client:outfitResult', function(res)
    if not res or not res.key then return end
    local message = res.arg and L(res.key, res.arg) or L(res.key)
    lib.notify({ title = L('outfit_title'), description = message, type = res.ok and 'success' or 'error' })
    SendNUIMessage({ action = 'outfitResult', ok = res.ok })
end)

-- Incoming share invite — accept/decline prompt. Uses ox_lib alertDialog so it
-- works even when the recipient is not currently in the creator.
RegisterNetEvent('orb-clothing:client:outfitShareInvite', function(info)
    info = info or {}
    local accepted = lib.alertDialog({
        header   = L('outfit_share_title'),
        content  = L('outfit_share_body', info.fromName or '?', info.outfitName or '?'),
        centered = true,
        cancel   = true,
        labels   = { confirm = L('accept'), cancel = L('decline') },
    })
    TriggerServerEvent('orb-clothing:server:shareResponse', accepted == 'confirm')
end)

-- Triggered by multichar after a new character is created — opens creator in first-time mode
AddEventHandler('orb-clothing:client:openForNewCharacter', function(gender)
    isFirstTime = true

    local isMale    = gender ~= 'female'
    local modelName = isMale and Config.PedModels.Male or Config.PedModels.Female
    local modelHash = GetHashKey(modelName)

    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 200 do
        Wait(10)
        timeout = timeout + 1
    end

    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
    DataCache.StoreHeritage({ mother = 0, father = 0, shapeValue = 0.5, colorValue = 0.5 })

    local defaultClothing = isMale and Config.DefaultClothing.male or Config.DefaultClothing.female
    for componentId, item in pairs(defaultClothing) do
        SetPedComponentVariation(ped, componentId, item.drawable, item.texture, 2)
    end
    local defaultProps = isMale and Config.DefaultProps.male or Config.DefaultProps.female
    for propId, item in pairs(defaultProps) do
        if item.drawable == -1 then
            ClearPedProp(ped, propId)
        else
            SetPedPropIndex(ped, propId, item.drawable, item.texture, true)
        end
    end

    SetTimecycleModifier('default')
    SetTimecycleModifierStrength(1.0)
    DoScreenFadeIn(500)
    Wait(300)

    OpenCreator(nil, nil)
end)

-- Server confirms save
RegisterNetEvent('orb-clothing:client:creatorSaved', function(success, reason)
    if success then
        CloseCreator()
        if isFirstTime then
            isFirstTime = false
            TriggerEvent('orb-clothing:client:characterCreationComplete')
        end
    else
        if reason == 'no_money' then
            lib.notify({ title = L('store_title'), description = L('no_money'), type = 'error' })
            -- Re-enable the save button in NUI so they can try again or exit
            SendNUIMessage({ action = 'paymentFailed' })
        end
        DebugPrint('creatorSaved: server reported failure' .. (reason and (' (' .. reason .. ')') or ''))
    end
end)

-- Restore appearance on character load (auto-detects framework event)
Bridge.OnPlayerLoaded(function()
    lib.callback('orb-clothing:server:loadAppearance', false, function(data)
        if not data then return end
        local ped = PlayerPedId()
        ApplyAppearanceFromState(ped, data)
        DebugPrint('Appearance restored from DB')
    end)
end)

-- ── Apply saved UI state onto ped ─────────────────────────────────────────

function ApplyAppearanceFromState(ped, data)
    local selections = data.selections or {}
    local sliders    = data.sliders    or {}
    local numbers    = data.numbers    or {}

    -- STEP 1: player model
    local modelSelection = selections['identity_gender']
    if modelSelection ~= nil then
        local mapping = Config.UIMapping and Config.UIMapping['identity_gender']
        if mapping and mapping.values then
            local model = mapping.values[modelSelection + 1]
            if model then
                local modelHash = GetHashKey(model)
                RequestModel(modelHash)
                local timeout = 0
                while not HasModelLoaded(modelHash) and timeout < 200 do
                    Wait(10)
                    timeout = timeout + 1
                end
                if HasModelLoaded(modelHash) then
                    SetPlayerModel(PlayerId(), modelHash)
                    SetModelAsNoLongerNeeded(modelHash)
                    ped = PlayerPedId()
                    SetPedDefaultComponentVariation(ped)
                end
            end
        end
    end

    -- STEP 2: heritage (collect from all sources, apply once)
    local heritage = { mother = 0, father = 0, shapeValue = 0.5, colorValue = 0.5 }
    for sectionId, index in pairs(selections) do
        local mapping = Config.UIMapping and Config.UIMapping[sectionId]
        if mapping and mapping.type == 'heritage' then
            heritage[mapping.param] = index
        end
    end
    for sliderId, rawValue in pairs(sliders) do
        local mapping = Config.SliderMapping and Config.SliderMapping[sliderId]
        if mapping and mapping.type == 'heritage' then
            heritage[mapping.param] = rawValue / 100.0
        end
    end
    DataCache.StoreHeritage(heritage)
    SetPedHeadBlendData(ped,
        heritage.mother, heritage.father, 0,
        heritage.mother, heritage.father, 0,
        heritage.shapeValue, heritage.colorValue, 0.0, false)

    -- STEP 3: non-model, non-heritage selections
    for sectionId, index in pairs(selections) do
        if sectionId ~= 'identity_gender' then
            local mapping = Config.UIMapping and Config.UIMapping[sectionId]
            if mapping then
                if mapping.type == 'overlay' then
                    local overlay = DataCache.GetOverlay(mapping.overlayId) or { variation = 0, opacity = 1.0, color = 0 }
                    overlay.variation = index
                    DataCache.StoreOverlay(mapping.overlayId, overlay)
                    AppearanceSystem.UpdateOverlay(ped, mapping.overlayId, overlay)
                elseif mapping.type == 'eyeColor' then
                    AppearanceSystem.UpdateEyeColor(ped, index)
                elseif mapping.type == 'hair' then
                    HairSystem.UpdateHairStyle(ped, index)
                elseif mapping.type == 'clothing' then
                    ClothingSystem.UpdateClothing(ped, mapping.componentId, index, 0)
                elseif mapping.type == 'prop' then
                    -- Apply gameOffset so the saved UI index matches the in-session
                    -- apply path. Without this, props with a "remove" slot at UI
                    -- index 0 (hats, glasses) come back +1 drawable on reload.
                    local drawable = index + (mapping.gameOffset or 0)
                    ClothingSystem.UpdateProp(ped, mapping.propId, drawable, 0)
                end
            end
        end
    end

    -- STEP 3b: re-apply clothing/prop TEXTURES from the saved per-item snapshot.
    -- Selections (STEP 3) only carry the drawable and always apply texture 0;
    -- the real texture/palette lives in data.clothing/data.props so outfits and
    -- manually-picked textures survive a reload. Apply the top (11) first so it
    -- doesn't reset the undershirt (8) we set afterwards.
    if data.clothing then
        local top = data.clothing['11'] or data.clothing[11]
        if top then ClothingSystem.UpdateClothing(ped, 11, top.d, top.t or 0) end
        for cidKey, item in pairs(data.clothing) do
            local cid = tonumber(cidKey)
            if cid and cid ~= 11 then ClothingSystem.UpdateClothing(ped, cid, item.d, item.t or 0) end
        end
    end
    if data.props then
        for pidKey, item in pairs(data.props) do
            local pid = tonumber(pidKey)
            if pid then ClothingSystem.UpdateProp(ped, pid, item.d, item.t or 0) end
        end
    end

    -- STEP 4: non-heritage sliders
    for sliderId, rawValue in pairs(sliders) do
        local mapping = Config.SliderMapping and Config.SliderMapping[sliderId]
        if mapping and mapping.type ~= 'ignore' and mapping.type ~= 'heritage' then
            local value = rawValue / 100.0
            if mapping.type == 'faceFeature' then
                AppearanceSystem.UpdateFaceFeature(ped, mapping.featureId, (value * 2.0) - 1.0)
            elseif mapping.type == 'overlayOpacity' then
                local overlay = DataCache.GetOverlay(mapping.overlayId) or { variation = 0, opacity = 1.0, color = 0 }
                overlay.opacity = value
                DataCache.StoreOverlay(mapping.overlayId, overlay)
                AppearanceSystem.UpdateOverlay(ped, mapping.overlayId, overlay)
            elseif mapping.type == 'pedScale' then
                local scale = 0.85 + (value * 0.30)
                AppearanceSystem.UpdateScale(ped, scale)
            end
        end
    end

    -- STEP 5: numbers (collect hair colors, apply once)
    local hairPrimary, hairHighlight
    for controlId, value in pairs(numbers) do
        local mapping = Config.NumberMapping and Config.NumberMapping[controlId]
        if mapping then
            if mapping.type == 'faceFeature' then
                AppearanceSystem.UpdateFaceFeature(ped, mapping.featureId, (value / 50.0) - 1.0)
            elseif mapping.type == 'hairColor' then
                if mapping.param == 'primary' then hairPrimary = value
                else hairHighlight = value end
            elseif mapping.type == 'overlayColor' then
                local overlay = DataCache.GetOverlay(mapping.overlayId) or { variation = 0, opacity = 1.0, color = 0 }
                overlay.color = value
                DataCache.StoreOverlay(mapping.overlayId, overlay)
                AppearanceSystem.UpdateOverlay(ped, mapping.overlayId, overlay)
            end
        end
    end
    if hairPrimary or hairHighlight then
        local colors = DataCache.GetHairColors()
        hairPrimary   = hairPrimary   or colors.primary   or 0
        hairHighlight = hairHighlight or colors.highlight or 0
        DataCache.StoreHairColors(hairPrimary, hairHighlight)
        HairSystem.UpdateHairColor(ped, hairPrimary, hairHighlight)
    end

    -- STEP 6: tattoos — apply saved tattoos and seed DataCache so remove/add stays in sync
    if data.tattoos and #data.tattoos > 0 then
        TattooSystem.ApplyTattoos(ped, data.tattoos)
    end
end

-- ── setPedAppearance export ───────────────────────────────────────────────
-- Called by multichar and qbx_core to preview a character's appearance.
-- `data` is the JSON-decoded character_appearance blob: { selections, sliders, numbers }
-- `ped`  is the ped to apply to (defaults to PlayerPedId() if nil)
exports('setPedAppearance', function(ped, data)
    if not data then return end
    ped = ped or PlayerPedId()
    if not DoesEntityExist(ped) then return end
    -- Re-use the same logic that restores appearance on login
    ApplyAppearanceFromState(ped, data)
end)

-- ── Scale tick loop ───────────────────────────────────────────────────────

-- Local player scale maintenance
-- SetEntityMatrix must be reapplied every frame because the game engine
-- overwrites the ped matrix each tick. Using Wait(200) or higher causes
-- visible flickering as the scale resets between applications.
--
-- Skip when the ped is frozen — that's an external resource (greenscreener,
-- cutscene, cinematic sequence, etc.) that has taken control of the ped's
-- transform, and SetEntityMatrix would otherwise override its freeze and
-- potentially displace the ped via the Z correction branch, breaking that
-- resource's workflow.
CreateThread(function()
    while true do
        if AppearanceSystem._pedScale ~= 1.0 then
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and not IsEntityPositionFrozen(ped) then
                AppearanceSystem.UpdateScale(ped, AppearanceSystem._pedScale, true)
            end
            Wait(0) -- must run every frame to prevent flickering
        else
            Wait(500)
        end
    end
end)

-- Other players scale sync via state bags
local otherPlayerScales = {}

AddStateBagChangeHandler('orb-clothing:scale', nil, function(bagName, _, value)
    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == 0 or playerId == PlayerId() then return end
    if value and value ~= 1.0 then
        otherPlayerScales[playerId] = value
    else
        otherPlayerScales[playerId] = nil
    end
end)

CreateThread(function()
    while true do
        local hasScales = next(otherPlayerScales) ~= nil
        if hasScales then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for playerId, scale in pairs(otherPlayerScales) do
                local ped = GetPlayerPed(playerId)
                if ped ~= 0 and DoesEntityExist(ped) then
                    local otherCoords = GetEntityCoords(ped)
                    if #(playerCoords - otherCoords) < 75.0 then
                        AppearanceSystem.UpdateScale(ped, scale, true)
                    end
                end
            end
            Wait(0) -- must run every frame (same reason as local player)
        else
            Wait(1000)
        end
    end
end)

-- ── Initialisation ────────────────────────────────────────────────────────

CreateThread(function()
    NUICallbacks.Register()
    -- Tell the NUI page which resource it lives in so fetch() URLs are correct,
    -- and hand it the active locale dictionary so all UI text is translated.
    SendNUIMessage({ action = 'init', resourceName = GetCurrentResourceName(), locale = GetLocaleTable() })

    -- Load admin stores and merge into Config.StoreLocations BEFORE creating zones/blips
    local adminStores = lib.callback.await('orb-clothing:server:getAdminStores', false)
    if adminStores then
        MergeAdminStores(adminStores)
    end

    CreateStoreZones()
    CreateStoreBlips()

    DebugPrint('Client initialized')
end)

-- ── Cleanup ───────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    SetNuiFocus(false, false)

    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)

        -- Restore ped to original position if we teleported them into a store
        if originalCoords then
            SetEntityCoordsNoOffset(ped, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false)
        end
        if originalHeading then
            SetEntityHeading(ped, originalHeading)
        end

        -- Restore appearance snapshot so try-on changes don't persist after restart
        if appearanceSnapshot then
            RestoreAppearanceSnapshot(ped, appearanceSnapshot)
        end
    end

    CameraSystem.Destroy()
    AppearanceSystem.ResetScale()

    -- Ensure player returns to default routing bucket and HUD is restored
    if isCreatorOpen then
        TriggerServerEvent('orb-clothing:server:exitBucket')
        Bridge.ShowHUD()
        DisplayRadar(true)
    end

    originalCoords     = nil
    originalHeading    = nil
    appearanceSnapshot = nil
    isCreatorOpen      = false
    isClosing          = false
    creatorPed         = nil
    activeStoreContext = nil

    DebugPrint('Resource stopped - cleanup complete')
end)

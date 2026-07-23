-- ═══════════════════════════════════════════════════════════════════════
--                         NUI CALLBACKS HANDLER
-- ═══════════════════════════════════════════════════════════════════════

NUICallbacks = {}

-- Scene effects state (accessible from main.lua for cleanup on close)
SceneEffects = {}
SceneEffects._lightActive = false

function SceneEffects.DisableLight()
    SceneEffects._lightActive = false
end

function NUICallbacks.Register()
    RegisterNUICallback('closeCreator', function(data, cb)
        TriggerEvent('orb-clothing:client:close')
        cb('ok')
    end)

    RegisterNUICallback('updateHeritage', function(data, cb)
        local ped = PlayerPedId()
        AppearanceSystem.UpdateHeritage(ped, data)
        cb('ok')
    end)

    RegisterNUICallback('updateFaceFeature', function(data, cb)
        local ped = PlayerPedId()
        AppearanceSystem.UpdateFaceFeature(ped, data.featureId, data.value)
        cb('ok')
    end)

    RegisterNUICallback('updateOverlay', function(data, cb)
        local ped = PlayerPedId()
        AppearanceSystem.UpdateOverlay(ped, data.overlayId, {
            variation = data.variation,
            opacity = data.opacity,
            color = data.color,
            secondColor = data.secondColor
        })
        cb('ok')
    end)

    RegisterNUICallback('updateEyeColor', function(data, cb)
        local ped = PlayerPedId()
        AppearanceSystem.UpdateEyeColor(ped, data.colorId)
        cb('ok')
    end)

    RegisterNUICallback('updateHairStyle', function(data, cb)
        local ped = PlayerPedId()
        HairSystem.UpdateHairStyle(ped, data.styleId)
        cb('ok')
    end)

    RegisterNUICallback('updateHairColor', function(data, cb)
        local ped = PlayerPedId()
        HairSystem.UpdateHairColor(ped, data.primaryColor, data.highlightColor)
        cb('ok')
    end)

    RegisterNUICallback('updateClothing', function(data, cb)
        local ped = PlayerPedId()
        ClothingSystem.UpdateClothing(ped, data.componentId, data.drawable, data.texture)
        cb('ok')
    end)

    RegisterNUICallback('updateProp', function(data, cb)
        local ped = PlayerPedId()
        ClothingSystem.UpdateProp(ped, data.propId, data.drawable, data.texture)
        cb('ok')
    end)

    RegisterNUICallback('addTattoo', function(data, cb)
        local ped = PlayerPedId()
        TattooSystem.AddTattoo(ped, data.collection, data.hash)
        cb('ok')
    end)

    RegisterNUICallback('removeTattoo', function(data, cb)
        local ped = PlayerPedId()
        TattooSystem.RemoveTattoo(ped, data.collection, data.hash)
        cb('ok')
    end)

    RegisterNUICallback('clearTattoos', function(data, cb)
        local ped = PlayerPedId()
        TattooSystem.ClearAllTattoos(ped)
        cb('ok')
    end)

    RegisterNUICallback('tattooZoneChanged', function(data, cb)
        TattooZoneChanged(data.zone)
        cb('ok')
    end)

    RegisterNUICallback('updateCamera', function(data, cb)
        local ped = PlayerPedId()
        local ctx = GetActiveStoreContext and GetActiveStoreContext()
        if ctx and ctx.chair then
            -- Barber chair: use Nation-style camera (ped-relative offset)
            CreateBarberCamera(ped, data.position)
        else
            CameraSystem.SetPosition(data.position, ped)
        end
        cb('ok')
    end)

    -- ── Scene toolbar: background blur (camera DOF — keeps ped in focus) ──
    RegisterNUICallback('toggleBlur', function(data, cb)
        local enabled = data.enabled == true
        CameraSystem.dofActive = enabled
        local cam = CameraSystem.activeCamera
        if cam then
            if enabled then
                SetCamUseShallowDofMode(cam, true)
                SetCamNearDof(cam, 0.3)
                SetCamFarDof(cam, 3.5)
                SetCamDofStrength(cam, 1.0)
            else
                SetCamUseShallowDofMode(cam, false)
                SetCamDofStrength(cam, 0.0)
            end
        end
        cb('ok')
    end)

    -- ── Scene toolbar: spotlight on ped ──
    RegisterNUICallback('toggleLight', function(data, cb)
        if data.enabled then
            if not SceneEffects._lightActive then
                SceneEffects._lightActive = true
                CreateThread(function()
                    while SceneEffects._lightActive do
                        local ped = PlayerPedId()
                        if DoesEntityExist(ped) then
                            local coords = GetEntityCoords(ped)
                            -- Soft white light above the ped pointing down
                            DrawLightWithRange(coords.x, coords.y, coords.z + 2.0, 255, 255, 255, 6.0, 3.0)
                            -- Front-facing fill light
                            local heading = GetEntityHeading(ped)
                            local rad = math.rad(heading)
                            local frontX = coords.x + math.sin(rad) * -2.0
                            local frontY = coords.y + math.cos(rad) * -2.0
                            DrawLightWithRange(frontX, frontY, coords.z + 0.5, 255, 255, 255, 5.0, 2.5)
                        end
                        Wait(0)
                    end
                end)
            end
        else
            SceneEffects.DisableLight()
        end
        cb('ok')
    end)

    -- ── Custom ped model selection ──
    RegisterNUICallback('selectCustomPed', function(data, cb)
        local modelName = data.model
        if not modelName or type(modelName) ~= 'string' then
            cb({ success = false })
            return
        end

        local modelHash = GetHashKey(modelName)
        if not IsModelValid(modelHash) then
            cb({ success = false })
            return
        end

        -- Hardened swap (see SwapPlayerModel in main.lua): refuses to swap onto
        -- an unstreamed model and waits for the NEW ped handle to settle. The
        -- old code re-grabbed PlayerPedId() the same frame — under load that's
        -- the dying ped, so the heading/freeze below landed on a corpse and the
        -- real new ped came in unfrozen and facing the wrong way.
        local ped = SwapPlayerModel(modelHash, 8000)
        if not ped then
            cb({ success = false })
            return
        end

        SetEntityHeading(ped, CameraSystem.lockedHeading or 0.0)
        FreezeEntityPosition(ped, true)
        TaskStandStill(ped, -1)

        if Config.Debug then
            print('[NUICallbacks] Custom ped set: ' .. modelName)
        end

        cb({ success = true })
    end)

    RegisterNUICallback('rotatePed', function(data, cb)
        local ped = PlayerPedId()
        local currentHeading = GetEntityHeading(ped)
        local newHeading = currentHeading + (data.direction * 10.0)
        SetEntityHeading(ped, newHeading)
        -- Do NOT update camera position — camera stays fixed, ped turns in place
        cb('ok')
    end)

    -- Scroll-to-zoom on the ped drag-zone. delta is +1 (zoom in) or -1 (out).
    -- CameraSystem.AdjustZoom clamps the result to [ZOOM_MIN_FOV, ZOOM_MAX_FOV]
    -- and resets automatically on every SetPosition preset change.
    RegisterNUICallback('zoomPed', function(data, cb)
        local delta = tonumber(data.delta) or 0
        if delta ~= 0 and CameraSystem and CameraSystem.AdjustZoom then
            CameraSystem.AdjustZoom(delta)
        end
        cb('ok')
    end)

    -- Vertical drag-pan on the ped drag-zone. delta is +1 (camera slides up,
    -- reveals head/upper body) or -1 (camera slides down, reveals feet).
    -- CameraSystem.AdjustVerticalPan clamps to [PAN_MIN_OFFSET, PAN_MAX_OFFSET]
    -- metres from the preset base and resets on every SetPosition change.
    RegisterNUICallback('panCamera', function(data, cb)
        local delta = tonumber(data.delta) or 0
        if delta ~= 0 and CameraSystem and CameraSystem.AdjustVerticalPan then
            CameraSystem.AdjustVerticalPan(delta)
        end
        cb('ok')
    end)

    RegisterNUICallback('requestAppearanceData', function(data, cb)
        local ped = PlayerPedId()
        local appearanceData = AppearanceSystem.GetCurrentAppearance(ped)
        cb(appearanceData)
    end)

    RegisterNUICallback('requestMaxValue', function(data, cb)
        local ped = PlayerPedId()
        local result = {}

        if data.type == 'hairStyles' then
            result.max = HairSystem.GetMaxHairStyles(ped)
        elseif data.type == 'clothing' then
            result = ClothingSystem.GetMaxValues(ped, data.id, data.drawable or 0, false)
        elseif data.type == 'prop' then
            result = ClothingSystem.GetMaxValues(ped, data.id, data.drawable or 0, true)
        end

        cb(result)
    end)

    -- Callbacks para la nueva UI (charactercreator style)
    RegisterNUICallback('selectItem', function(data, cb)
        local ped = PlayerPedId()
        local section = data.section
        local index = data.index

        if Config.Debug then
            print('[NUICallbacks] selectItem:', section, index)
        end

        local mapping = Config.UIMapping[section]
        if not mapping then
            if Config.Debug then
                print('[NUICallbacks] No mapping found for section:', section)
            end
            cb({success = false})
            return
        end

        if mapping.type == "model" then
            local model = mapping.values[index + 1]
            if model then
                local modelHash = GetHashKey(model)
                -- Hardened swap (see SwapPlayerModel in main.lua). The old code
                -- here gave the other gender's model ONE second, then blended on
                -- a possibly-dying ped handle the same frame — clicking the
                -- male/female heads on a slow client was the single most likely
                -- trigger for the stretched-polygon character in the creator.
                local newPed = SwapPlayerModel(modelHash, 8000)
                if newPed then
                    local heritage = DataCache.GetHeritage() or {
                        mother = 0,
                        father = 0,
                        shapeValue = 0.5,
                        colorValue = 0.5
                    }
                    SetPedHeadBlendData(newPed, heritage.mother, heritage.father, 0, heritage.mother, heritage.father, 0, heritage.shapeValue, heritage.colorValue, 0.0, false)
                    SetPedDefaultComponentVariation(newPed)

                    -- Re-query auto-counts for the new gender: add-on packs
                    -- often have different drawable ranges per model, so we
                    -- push fresh counts to the NUI so the options grid
                    -- renders accurate slots immediately.
                    if BuildAutoCounts then
                        SendNUIMessage({
                            action = 'updateAutoCounts',
                            counts = BuildAutoCounts(newPed)
                        })
                    end
                end
            end

        elseif mapping.type == "heritage" then
            local currentHeritage = DataCache.GetHeritage() or {
                mother = 0,
                father = 0,
                shapeValue = 0.5,
                colorValue = 0.5
            }
            currentHeritage[mapping.param] = index
            DataCache.StoreHeritage(currentHeritage)
            AppearanceSystem.UpdateHeritage(ped, currentHeritage)

        elseif mapping.type == "overlay" then
            local currentOverlay = DataCache.GetOverlay(mapping.overlayId) or { variation = 0, opacity = 1.0, color = 0 }
            currentOverlay.variation = index
            DataCache.StoreOverlay(mapping.overlayId, currentOverlay)
            AppearanceSystem.UpdateOverlay(ped, mapping.overlayId, currentOverlay)

        elseif mapping.type == "eyeColor" then
            AppearanceSystem.UpdateEyeColor(ped, index)

        elseif mapping.type == "hair" then
            HairSystem.UpdateHairStyle(ped, index)

        elseif mapping.type == "clothing" then
            ClothingSystem.UpdateClothing(ped, mapping.componentId, index, 0)
            DataCache.SetActiveClothing(mapping.componentId, index)

        elseif mapping.type == "prop" then
            ClothingSystem.UpdateProp(ped, mapping.propId, index, 0)
            DataCache.SetActiveProp(mapping.propId, index)
        end

        cb({success = true})
    end)

    RegisterNUICallback('updateSlider', function(data, cb)
        local ped = PlayerPedId()
        local sliderId = data.slider
        local value = data.value / 100.0

        if Config.Debug then
            print('[NUICallbacks] updateSlider:', sliderId, value)
        end

        local mapping = Config.SliderMapping[sliderId]
        if not mapping then
            cb({success = false})
            return
        end

        if mapping.type == "ignore" then
            cb({success = true})
            return
        end

        if mapping.type == "heritage" then
            local currentHeritage = DataCache.GetHeritage() or {
                mother = 0,
                father = 0,
                shapeValue = 0.5,
                colorValue = 0.5
            }
            currentHeritage[mapping.param] = value
            DataCache.StoreHeritage(currentHeritage)
            AppearanceSystem.UpdateHeritage(ped, currentHeritage)

        elseif mapping.type == "faceFeature" then
            local featureValue = (value * 2.0) - 1.0
            AppearanceSystem.UpdateFaceFeature(ped, mapping.featureId, featureValue)

        elseif mapping.type == "overlayOpacity" then
            local currentOverlay = DataCache.GetOverlay(mapping.overlayId) or { variation = 0, opacity = 1.0, color = 0 }
            currentOverlay.opacity = value
            DataCache.StoreOverlay(mapping.overlayId, currentOverlay)
            AppearanceSystem.UpdateOverlay(ped, mapping.overlayId, currentOverlay)

        elseif mapping.type == "pedScale" then
            -- Map 0–1 slider to 0.85–1.15 scale range
            local scale = 0.85 + (value * 0.30)
            AppearanceSystem.UpdateScale(ped, scale)
        end

        cb({success = true})
    end)

    RegisterNUICallback('updateNumber', function(data, cb)
        local ped = PlayerPedId()
        local controlId = data.control
        local value = data.value

        if Config.Debug then
            print('[NUICallbacks] updateNumber:', controlId, value)
        end

        local mapping = Config.NumberMapping[controlId]
        if not mapping then
            cb({success = false})
            return
        end

        if mapping.type == "faceFeature" then
            local featureValue = (value / 50.0) - 1.0
            AppearanceSystem.UpdateFaceFeature(ped, mapping.featureId, featureValue)

        elseif mapping.type == "hairColor" then
            local currentColors = DataCache.GetHairColors()
            if mapping.param == "primary" then
                currentColors.primary = value
            else
                currentColors.highlight = value
            end
            DataCache.StoreHairColors(currentColors.primary, currentColors.highlight)
            HairSystem.UpdateHairColor(ped, currentColors.primary, currentColors.highlight)

        elseif mapping.type == "overlayColor" then
            local currentOverlay = DataCache.GetOverlay(mapping.overlayId) or { variation = 0, opacity = 1.0, color = 0 }
            currentOverlay.color = value
            DataCache.StoreOverlay(mapping.overlayId, currentOverlay)
            AppearanceSystem.UpdateOverlay(ped, mapping.overlayId, currentOverlay)

        elseif mapping.type == "texture" then
            local activeClothing = DataCache.GetActiveClothing()
            local activeProp = DataCache.GetActiveProp()
            if activeClothing then
                ClothingSystem.UpdateClothing(ped, activeClothing.componentId, activeClothing.drawable, value)
            elseif activeProp then
                ClothingSystem.UpdateProp(ped, activeProp.propId, activeProp.drawable, value)
            end

        elseif mapping.type == "palette" then
            -- Palette changes are handled similar to texture
            local activeClothing = DataCache.GetActiveClothing()
            if activeClothing then
                ClothingSystem.UpdateClothing(ped, activeClothing.componentId, activeClothing.drawable, value)
            end
        end

        cb({success = true})
    end)

    RegisterNUICallback('saveCharacter', function(data, cb)
        if Config.Debug then
            print('[NUICallbacks] saveCharacter')
        end
        local ctx = GetActiveStoreContext()
        -- Snapshot the ped's clothing/props (with real textures) so per-item
        -- textures survive a relog — selections only carry the drawable.
        local look = OutfitSystem.BuildSnapshot(PlayerPedId())
        -- Merge current tattoos from DataCache into the save payload
        local payload = {
            selections = data.selections,
            sliders    = data.sliders,
            numbers    = data.numbers,
            tattoos    = DataCache.GetTattoos(),
            clothing   = look.components,
            props      = look.props,
        }
        -- Mark the session as saved so CloseCreator keeps changes instead of reverting
        MarkSessionSaved()
        TriggerServerEvent('orb-clothing:server:saveAppearance', {
            appearance    = payload,
            storeIndex    = ctx and ctx.storeIndex or nil,
            changedItems  = data.changedItems or {},  -- list of changed subcategory IDs from checkout
        })
        -- Close is handled by orb-clothing:client:creatorSaved (server confirms save first)
        cb('ok')
    end)

    RegisterNUICallback('resetAppearance', function(data, cb)
        ResetToSnapshot()
        cb('ok')
    end)

    RegisterNUICallback('closeUI', function(data, cb)
        TriggerEvent('orb-clothing:client:close')
        cb('ok')
    end)

    -- ── Outfits ──────────────────────────────────────────────────────
    RegisterNUICallback('outfitListRequest', function(data, cb)
        cb(lib.callback.await('orb-clothing:server:listOutfits', false) or {})
    end)

    RegisterNUICallback('outfitSave', function(data, cb)
        local look = OutfitSystem.BuildSnapshot(PlayerPedId())
        TriggerServerEvent('orb-clothing:server:saveOutfit', { name = data.name, data = look })
        cb('ok')
    end)

    RegisterNUICallback('outfitApply', function(data, cb)
        TriggerServerEvent('orb-clothing:server:applyOutfit', { id = data.id })
        cb('ok')
    end)

    RegisterNUICallback('outfitRename', function(data, cb)
        TriggerServerEvent('orb-clothing:server:renameOutfit', { id = data.id, newName = data.name })
        cb('ok')
    end)

    RegisterNUICallback('outfitDelete', function(data, cb)
        TriggerServerEvent('orb-clothing:server:deleteOutfit', { id = data.id })
        cb('ok')
    end)

    -- Player picker source: online players sorted by distance to where the
    -- sharer was standing BEFORE entering the store (the store teleports them).
    RegisterNUICallback('outfitShareTargets', function(data, cb)
        local origin = GetCreatorOriginCoords and GetCreatorOriginCoords()
        local originTbl = origin and { x = origin.x, y = origin.y, z = origin.z } or nil
        cb(lib.callback.await('orb-clothing:server:getShareTargets', false, originTbl) or {})
    end)

    RegisterNUICallback('outfitShare', function(data, cb)
        TriggerServerEvent('orb-clothing:server:shareOutfit', { id = data.id, targetId = data.targetId })
        cb('ok')
    end)

    if Config.Debug then
        print('[NUICallbacks] All callbacks registered')
    end
end

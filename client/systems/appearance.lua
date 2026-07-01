-- ═══════════════════════════════════════════════════════════════════════
--                         APPEARANCE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

AppearanceSystem = {}

function AppearanceSystem.UpdateHeritage(ped, data)
    if not DoesEntityExist(ped) then
        return false
    end

    local mother = Validation.ParentIndex(data.mother or 0)
    local father = Validation.ParentIndex(data.father or 0)
    local thirdParent = Validation.ParentIndex(data.thirdParent or 0)
    local shapeValue = Validation.BlendValue(data.shapeValue or 0.5)
    local colorValue = Validation.BlendValue(data.colorValue or 0.5)

    SetPedHeadBlendData(ped, mother, father, thirdParent, mother, father, thirdParent, shapeValue, colorValue, 0.0, false)

    if Config.Debug then
        print(string.format('[AppearanceSystem] Heritage updated: M=%d, F=%d, Shape=%.2f, Color=%.2f',
            mother, father, shapeValue, colorValue))
    end

    return true
end

function AppearanceSystem.UpdateFaceFeature(ped, featureId, value)
    if not DoesEntityExist(ped) then
        return false
    end

    featureId = tonumber(featureId) or 0
    value = Validation.FaceFeature(value or 0.0)

    SetPedFaceFeature(ped, featureId, value)

    if Config.Debug then
        print(string.format('[AppearanceSystem] Face feature updated: ID=%d, Value=%.2f', featureId, value))
    end

    return true
end

function AppearanceSystem.UpdateOverlay(ped, overlayId, data)
    if not DoesEntityExist(ped) then
        return false
    end

    overlayId = tonumber(overlayId) or 0
    local variation = Validation.OverlayVariation(data.variation or 0)
    local opacity = Validation.OverlayOpacity(data.opacity or 1.0)
    local color = data.color and Validation.OverlayColor(data.color) or 0
    local secondColor = data.secondColor and Validation.OverlayColor(data.secondColor) or 0

    SetPedHeadOverlay(ped, overlayId, variation, opacity)

    if data.color ~= nil then
        local colorType = 0
        if overlayId == 1 or overlayId == 2 or overlayId == 10 then
            colorType = 1
        elseif overlayId == 4 or overlayId == 5 or overlayId == 8 then
            colorType = 2
        end
        SetPedHeadOverlayColor(ped, overlayId, colorType, color, secondColor)
    end

    if Config.Debug then
        print(string.format('[AppearanceSystem] Overlay updated: ID=%d, Var=%d, Opacity=%.2f, Color=%d',
            overlayId, variation, opacity, color))
    end

    return true
end


-- Active ped scale (1.0 = default). Stored so the tick thread can reapply it.
AppearanceSystem._pedScale = 1.0

local function _norm(v)
    local mag = math.sqrt(v.x^2 + v.y^2 + v.z^2)
    if mag == 0 then return v end
    return vector3(v.x/mag, v.y/mag, v.z/mag)
end

-- fromTick: true when called by the reapply loop
function AppearanceSystem.UpdateScale(ped, scale, fromTick)
    if not DoesEntityExist(ped) then return false end
    if IsPedInAnyVehicle(ped, false) then return false end

    scale = math.max(0.85, math.min(1.15, scale))
    AppearanceSystem._pedScale = scale

    local forward, right, upVec, position = GetEntityMatrix(ped)

    local fNorm = _norm(forward) * scale
    local rNorm = _norm(right)   * scale
    local uNorm = _norm(upVec)   * scale

    -- Z correction matching TGIANN's production formula:
    -- stationary & near ground → use height above ground
    -- moving or airborne       → use upright value
    local speed       = GetEntitySpeed(ped)
    local heightAbove = GetEntityHeightAboveGround(ped)
    local adjustedZ
    if speed <= 0 and heightAbove < 2 then
        adjustedZ = position.z - (heightAbove - scale)
    else
        adjustedZ = position.z - (GetEntityUprightValue(ped) - scale)
    end

    SetEntityMatrix(ped,
        fNorm.x, fNorm.y, fNorm.z,
        rNorm.x, rNorm.y, rNorm.z,
        uNorm.x, uNorm.y, uNorm.z,
        position.x, position.y, adjustedZ)

    if Config.Debug and not fromTick then
        print(string.format('[AppearanceSystem] Ped scale set: %.3f', scale))
    end

    return true
end

function AppearanceSystem.ResetScale()
    AppearanceSystem._pedScale  = 1.0
end

function AppearanceSystem.UpdateEyeColor(ped, colorId)
    if not DoesEntityExist(ped) then
        return false
    end

    colorId = Validation.EyeColor(colorId or 0)
    SetPedEyeColor(ped, colorId)

    if Config.Debug then
        print(string.format('[AppearanceSystem] Eye color updated: %d', colorId))
    end

    return true
end

function AppearanceSystem.ApplyFullAppearance(ped, data)
    if not DoesEntityExist(ped) then
        return false
    end

    if data.heritage then
        AppearanceSystem.UpdateHeritage(ped, data.heritage)
    end

    if data.eyeColor then
        AppearanceSystem.UpdateEyeColor(ped, data.eyeColor)
    end

    if data.faceFeatures then
        for featureId, value in pairs(data.faceFeatures) do
            AppearanceSystem.UpdateFaceFeature(ped, featureId, value)
        end
    end

    if data.overlays then
        for overlayKey, overlayData in pairs(data.overlays) do
            local overlayId = Config.HeadOverlays[overlayKey]
            if overlayId then
                AppearanceSystem.UpdateOverlay(ped, overlayId, overlayData)
            end
        end
    end

    DataCache.StoreAppearance(data)

    if Config.Debug then
        print('[AppearanceSystem] Full appearance applied')
    end

    return true
end

function AppearanceSystem.GetCurrentAppearance(ped)
    if not DoesEntityExist(ped) then
        return {}
    end

    return DataCache.GetAppearance()
end

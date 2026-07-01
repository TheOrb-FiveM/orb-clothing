-- ═══════════════════════════════════════════════════════════════════════
--                          CLOTHING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

ClothingSystem = {}

function ClothingSystem.UpdateClothing(ped, componentId, drawable, texture)
    if not DoesEntityExist(ped) then
        return false
    end

    componentId = tonumber(componentId) or 0
    local maxDrawables = GetNumberOfPedDrawableVariations(ped, componentId) - 1
    drawable = Validation.ClothingDrawable(drawable, maxDrawables)

    local maxTextures = 0
    if drawable >= 0 then
        maxTextures = GetNumberOfPedTextureVariations(ped, componentId, drawable) - 1
    end
    texture = Validation.ClothingTexture(texture, maxTextures)

    SetPedComponentVariation(ped, componentId, drawable, texture, 0)
    DataCache.StoreClothing(componentId, drawable, texture)

    -- When changing tops (11), reset undershirt (8) to bare default so the old layer
    -- doesn't clip through. Arms (3) are left alone — the player picks them manually.
    local gender = Config.IsMale(ped) and 'male' or 'female'
    local defaults = Config.DefaultClothing[gender]
    if componentId == 11 and defaults then
        if defaults[8] then
            SetPedComponentVariation(ped, 8, defaults[8].drawable, defaults[8].texture, 0)
            DataCache.StoreClothing(8, defaults[8].drawable, defaults[8].texture)
        end
    end

    if Config.Debug then
        print(string.format('[ClothingSystem] Clothing updated: Component=%d, Drawable=%d, Texture=%d',
            componentId, drawable, texture))
    end

    return true
end

function ClothingSystem.UpdateProp(ped, propId, drawable, texture)
    if not DoesEntityExist(ped) then
        return false
    end

    propId = tonumber(propId) or 0
    local maxDrawables = GetNumberOfPedPropDrawableVariations(ped, propId) - 1
    drawable = Validation.PropDrawable(drawable, maxDrawables)

    if drawable < 0 then
        ClearPedProp(ped, propId)
        DataCache.StoreProp(propId, -1, 0)

        if Config.Debug then
            print(string.format('[ClothingSystem] Prop cleared: PropId=%d', propId))
        end

        return true
    end

    local maxTextures = GetNumberOfPedPropTextureVariations(ped, propId, drawable) - 1
    texture = Validation.PropTexture(texture, maxTextures)

    SetPedPropIndex(ped, propId, drawable, texture, true)
    DataCache.StoreProp(propId, drawable, texture)

    if Config.Debug then
        print(string.format('[ClothingSystem] Prop updated: PropId=%d, Drawable=%d, Texture=%d',
            propId, drawable, texture))
    end

    return true
end

function ClothingSystem.ApplyFullClothing(ped, clothing, props)
    if not DoesEntityExist(ped) then
        return false
    end

    if clothing then
        for componentId, data in pairs(clothing) do
            ClothingSystem.UpdateClothing(ped, componentId, data.drawable, data.texture)
        end
    end

    if props then
        for propId, data in pairs(props) do
            ClothingSystem.UpdateProp(ped, propId, data.drawable, data.texture)
        end
    end

    if Config.Debug then
        print('[ClothingSystem] Full clothing applied')
    end

    return true
end

function ClothingSystem.GetMaxValues(ped, componentId, drawable, isProp)
    if not DoesEntityExist(ped) then
        return { maxDrawables = 0, maxTextures = 0 }
    end

    local maxDrawables, maxTextures

    if isProp then
        maxDrawables = GetNumberOfPedPropDrawableVariations(ped, componentId) - 1
        maxTextures = drawable >= 0 and GetNumberOfPedPropTextureVariations(ped, componentId, drawable) - 1 or 0
    else
        maxDrawables = GetNumberOfPedDrawableVariations(ped, componentId) - 1
        maxTextures = drawable >= 0 and GetNumberOfPedTextureVariations(ped, componentId, drawable) - 1 or 0
    end

    return {
        maxDrawables = maxDrawables,
        maxTextures = maxTextures
    }
end

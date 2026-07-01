-- ═══════════════════════════════════════════════════════════════════════
--                            HAIR SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

HairSystem = {}

function HairSystem.UpdateHairStyle(ped, styleId)
    if not DoesEntityExist(ped) then
        return false
    end

    local maxStyles = GetNumberOfPedDrawableVariations(ped, 2) - 1
    styleId = Validation.HairStyle(styleId, maxStyles)

    SetPedComponentVariation(ped, 2, styleId, 0, 0)

    if Config.Debug then
        print(string.format('[HairSystem] Hair style updated: %d', styleId))
    end

    return true
end

function HairSystem.UpdateHairColor(ped, primaryColor, highlightColor)
    if not DoesEntityExist(ped) then
        return false
    end

    primaryColor = Validation.HairColor(primaryColor or 0)
    highlightColor = Validation.HairColor(highlightColor or 0)

    SetPedHairColor(ped, primaryColor, highlightColor)

    if Config.Debug then
        print(string.format('[HairSystem] Hair color updated: Primary=%d, Highlight=%d',
            primaryColor, highlightColor))
    end

    return true
end

function HairSystem.ApplyFullHair(ped, data)
    if not DoesEntityExist(ped) then
        return false
    end

    if data.style ~= nil then
        HairSystem.UpdateHairStyle(ped, data.style)
    end

    if data.color ~= nil or data.highlightColor ~= nil then
        HairSystem.UpdateHairColor(ped, data.color, data.highlightColor)
    end

    if Config.Debug then
        print('[HairSystem] Full hair applied')
    end

    return true
end

function HairSystem.GetMaxHairStyles(ped)
    if not DoesEntityExist(ped) then
        return 0
    end

    return GetNumberOfPedDrawableVariations(ped, 2) - 1
end

-- ═══════════════════════════════════════════════════════════════════════
--                          DATA CACHE UTILITY
-- ═══════════════════════════════════════════════════════════════════════

DataCache = {}

DataCache.currentAppearance = {}
DataCache.currentClothing = {}
DataCache.currentProps = {}
DataCache.currentTattoos = {}
DataCache.currentHeritage = {}
DataCache.currentOverlays = {}
DataCache.currentHairColors = { primary = 0, highlight = 0 }
DataCache.activeClothing = nil
DataCache.activeProp = nil

function DataCache.StoreAppearance(data)
    DataCache.currentAppearance = data
end

function DataCache.GetAppearance()
    return DataCache.currentAppearance
end

function DataCache.StoreClothing(componentId, drawable, texture)
    DataCache.currentClothing[componentId] = {
        drawable = drawable,
        texture = texture
    }
end

function DataCache.GetClothing(componentId)
    return DataCache.currentClothing[componentId]
end

function DataCache.StoreProp(propId, drawable, texture)
    DataCache.currentProps[propId] = {
        drawable = drawable,
        texture = texture
    }
end

function DataCache.GetProp(propId)
    return DataCache.currentProps[propId]
end

function DataCache.StoreTattoos(tattoos)
    DataCache.currentTattoos = tattoos
end

function DataCache.GetTattoos()
    return DataCache.currentTattoos
end

function DataCache.Clear()
    DataCache.currentAppearance = {}
    DataCache.currentClothing = {}
    DataCache.currentProps = {}
    -- NOTE: tattoos are NOT cleared here — they persist between store sessions
    -- because GTA V has no native to read decorations from a ped, so we must
    -- keep our own list in memory. Tattoos are only reset on full character reload.
    DataCache.currentHeritage = {}
    DataCache.currentOverlays = {}
    DataCache.currentHairColors = { primary = 0, highlight = 0 }
    DataCache.activeClothing = nil
    DataCache.activeProp = nil
end

-- Heritage
function DataCache.StoreHeritage(data)
    for k, v in pairs(data) do
        DataCache.currentHeritage[k] = v
    end
end

function DataCache.GetHeritage()
    return DataCache.currentHeritage
end

-- Overlays
function DataCache.StoreOverlay(overlayId, data)
    DataCache.currentOverlays[overlayId] = data
end

function DataCache.GetOverlay(overlayId)
    return DataCache.currentOverlays[overlayId]
end

-- Hair Colors
function DataCache.StoreHairColors(primary, highlight)
    DataCache.currentHairColors = {
        primary = primary or 0,
        highlight = highlight or 0
    }
end

function DataCache.GetHairColors()
    return DataCache.currentHairColors
end

-- Active Clothing/Prop tracking
function DataCache.SetActiveClothing(componentId, drawable)
    DataCache.activeClothing = {
        componentId = componentId,
        drawable = drawable
    }
end

function DataCache.GetActiveClothing()
    return DataCache.activeClothing
end

function DataCache.SetActiveProp(propId, drawable)
    DataCache.activeProp = {
        propId = propId,
        drawable = drawable
    }
end

function DataCache.GetActiveProp()
    return DataCache.activeProp
end

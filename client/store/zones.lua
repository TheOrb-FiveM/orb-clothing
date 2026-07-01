-- ═══════════════════════════════════════════════════════════════════════
--                         STORE ZONES
-- Creates ox_lib enter zones around each store location.
-- When the player enters a zone, fires:
--   orb-clothing:client:enterStore(storeIndex)
-- When they leave:
--   orb-clothing:client:exitStore()
-- ═══════════════════════════════════════════════════════════════════════

local zones = {}

function CreateStoreZones()
    for i, store in ipairs(Config.StoreLocations) do
        local storeType = Config.StoreTypes[store.type]
        if not storeType then goto continue end

        local size   = store.size or storeType.defaultSize or vector2(8.0, 8.0)
        local coords = vector3(store.coords.x, store.coords.y, store.coords.z)
        local heading = store.coords.w or 0.0

        local zone = lib.zones.box({
            coords  = coords,
            size    = vector3(size.x, size.y, 3.0),
            rotation = heading,
            debug   = Config.Debug,
            onEnter = function()
                TriggerEvent('orb-clothing:client:enterStore', i)
            end,
            onExit = function()
                TriggerEvent('orb-clothing:client:exitStore')
            end
        })

        zones[i] = zone

        ::continue::
    end
end

function RemoveStoreZones()
    for _, zone in pairs(zones) do
        zone:remove()
    end
    zones = {}
end

function ReloadStoreZones()
    RemoveStoreZones()
    CreateStoreZones()
end

-- NOTE: zones are NOT auto-created here. main.lua calls CreateStoreZones()
-- after admin stores have been merged into Config.StoreLocations.

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveStoreZones()
end)

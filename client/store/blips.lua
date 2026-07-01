-- ═══════════════════════════════════════════════════════════════════════
--                         STORE BLIPS
-- ═══════════════════════════════════════════════════════════════════════

local blipHandles = {}

function CreateStoreBlips()
    for _, store in ipairs(Config.StoreLocations) do
        local storeType = Config.StoreTypes[store.type]
        if not storeType then goto continue end

        local blipCfg = storeType.blip
        local blip = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)

        SetBlipSprite(blip, blipCfg.sprite)
        SetBlipColour(blip, blipCfg.color)
        SetBlipScale(blip, blipCfg.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(store.label or blipCfg.name)
        EndTextCommandSetBlipName(blip)

        blipHandles[#blipHandles + 1] = blip

        ::continue::
    end
end

function RemoveStoreBlips()
    for _, blip in ipairs(blipHandles) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    blipHandles = {}
end

function ReloadStoreBlips()
    RemoveStoreBlips()
    CreateStoreBlips()
end

-- NOTE: blips are NOT auto-created here. main.lua calls CreateStoreBlips()
-- after admin stores have been merged into Config.StoreLocations.

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    RemoveStoreBlips()
end)

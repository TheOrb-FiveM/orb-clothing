-- ═══════════════════════════════════════════════════════════════════════
--                    ADMIN NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════

RegisterNUICallback('adminClosePanel', function(_, cb)
    CloseAdminPanel()
    cb('ok')
end)

RegisterNUICallback('adminStartPlacement', function(data, cb)
    StartPlacement(data.field)  -- 'zone' or 'ped'
    cb('ok')
end)

RegisterNUICallback('adminPreviewCamera', function(data, cb)
    StartCameraPreview(data.pedPosition, data.cameraPreset)
    cb('ok')
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    TeleportToStore(data.coords)
    cb('ok')
end)

RegisterNUICallback('adminSaveStore', function(data, cb)
    TriggerServerEvent('orb-clothing:server:adminSaveStore', data)
    cb('ok')
end)

RegisterNUICallback('adminDeleteStore', function(data, cb)
    TriggerServerEvent('orb-clothing:server:adminDeleteStore', data)
    cb('ok')
end)

-- Update zone marker size when admin changes it in the NUI
RegisterNUICallback('adminUpdateMarkerSize', function(data, cb)
    UpdateMarkerZoneSize(data.width, data.length)
    cb('ok')
end)

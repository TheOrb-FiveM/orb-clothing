-- ═══════════════════════════════════════════════════════════════════════
--                      ADMIN STORE MANAGER
-- Handles the /storeadmin command, placement mode, 3D markers,
-- camera preview, and admin store merging/reload.
-- ═══════════════════════════════════════════════════════════════════════

local adminPanelOpen = false
local placementMode  = nil    -- 'zone' or 'ped'
local placementHeading = 0.0
local previewActive  = false
local previewSavedCoords  = nil
local previewSavedHeading = nil

-- Positions currently being configured (for 3D marker rendering)
local markerZone = nil   -- { x, y, z, w, sizeX, sizeY }
local markerPed  = nil   -- { x, y, z, w }

-- ── Admin store merge ───────────────────────────────────────────────────

-- Stores live entirely in the admin storage now — config defaults are seeded
-- into it on first run (server side), so the live list is built purely from
-- the admin store list the server sends. Everything is managed via /storeadmin.
function MergeAdminStores(adminStores)
    Config.StoreLocations = {}
    if not adminStores then return end
    for _, s in ipairs(adminStores) do
        Config.StoreLocations[#Config.StoreLocations + 1] = {
            coords      = vector4(s.coords.x, s.coords.y, s.coords.z, s.coords.w),
            type        = s.type,
            pedPosition = s.pedPosition and vector4(s.pedPosition.x, s.pedPosition.y, s.pedPosition.z, s.pedPosition.w) or nil,
            size        = s.size and vector2(s.size.x, s.size.y) or nil,
            label       = s.label,
            jobLock     = s.jobLock,
            showBlip    = s.showBlip ~= false,   -- default true; only explicit false hides it
            _adminId    = s.id
        }
    end
end

-- ── Live reload (from server after create/update/delete) ────────────────

RegisterNetEvent('orb-clothing:client:reloadStores', function(adminStores)
    MergeAdminStores(adminStores)
    ReloadStoreZones()
    ReloadStoreBlips()
end)

-- ── Notifications from server ───────────────────────────────────────────

RegisterNetEvent('orb-clothing:client:adminNotify', function(data)
    lib.notify(data)
end)

-- ── /storeadmin command ─────────────────────────────────────────────────

RegisterCommand('storeadmin', function()
    if adminPanelOpen then return end
    adminPanelOpen = true

    -- Request store list from server then open NUI
    local stores = lib.callback.await('orb-clothing:server:getAdminStores', false)
    if not stores then stores = {} end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdminPanel',
        stores = stores,
        storeTypes = GetStoreTypeNames()
    })
end, false) -- Permission checked server-side via IsAdmin()

-- Helper: build a simple list of store type info for the NUI
function GetStoreTypeNames()
    local result = {}
    for key, st in pairs(Config.StoreTypes) do
        result[key] = {
            name       = st.blip.name,
            openCamera = st.openCamera or 'full',
            defaultSize = { x = st.defaultSize.x, y = st.defaultSize.y }
        }
    end
    return result
end

-- ── Public state accessor (used by interaction.lua) ─────────────────────

function IsAdminPanelActive()
    return adminPanelOpen or placementMode ~= nil or previewActive
end

-- ── Marker accessors (for nui_admin.lua) ────────────────────────────────

function UpdateMarkerZoneSize(width, length)
    if markerZone then
        markerZone.sizeX = width
        markerZone.sizeY = length
    end
end

-- ── Close admin panel ───────────────────────────────────────────────────

function CloseAdminPanel()
    adminPanelOpen = false
    placementMode = nil
    previewActive = false
    markerZone = nil
    markerPed = nil
    SetNuiFocus(false, false)
    lib.hideTextUI()
    SendNUIMessage({ action = 'hideAdminPanel' })
end

-- ── Placement mode ──────────────────────────────────────────────────────
-- Admin walks to a position and presses E to confirm it.

function StartPlacement(field)
    placementMode = field  -- 'zone' or 'ped'
    placementHeading = GetEntityHeading(PlayerPedId())
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminHidePanel' })  -- hide UI so admin can see the world

    local label = field == 'zone' and L('admin_zone_center') or L('admin_ped_position')
    lib.showTextUI(L('admin_confirm', label), {
        position = 'bottom-center'
    })
end

function CancelPlacement()
    placementMode = nil
    lib.hideTextUI()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'adminShowPanel' })  -- bring UI back
end

function ConfirmPlacement()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local field = placementMode

    placementMode = nil
    lib.hideTextUI()

    -- Store for 3D marker
    local posData = { x = coords.x, y = coords.y, z = coords.z, w = placementHeading }
    if field == 'zone' then
        markerZone = posData
    elseif field == 'ped' then
        markerPed = posData
    end

    -- Re-open NUI and send position back
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'adminPositionSet',
        field  = field,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = placementHeading
    })
end

-- ── Camera preview ──────────────────────────────────────────────────────

function StartCameraPreview(pedPos, cameraPreset)
    if not pedPos then return end
    previewActive = true

    local ped = PlayerPedId()
    previewSavedCoords  = GetEntityCoords(ped)
    previewSavedHeading = GetEntityHeading(ped)

    SetNuiFocus(false, false)

    -- Teleport to ped position
    SetEntityCoordsNoOffset(ped, pedPos.x, pedPos.y, pedPos.z, false, false, false)
    SetEntityHeading(ped, pedPos.w)
    FreezeEntityPosition(ped, true)
    Wait(100)

    -- Create camera
    CameraSystem.Create(ped)
    CameraSystem.SetPosition(cameraPreset or 'full', ped)

    lib.showTextUI(L('admin_return'), { position = 'bottom-center' })
end

function StopCameraPreview()
    previewActive = false
    lib.hideTextUI()

    CameraSystem.Destroy()

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    if previewSavedCoords then
        SetEntityCoordsNoOffset(ped, previewSavedCoords.x, previewSavedCoords.y, previewSavedCoords.z, false, false, false)
    end
    if previewSavedHeading then
        SetEntityHeading(ped, previewSavedHeading)
    end

    previewSavedCoords = nil
    previewSavedHeading = nil

    -- Re-open NUI
    SetNuiFocus(true, true)
end

-- ── Teleport to store ────────────────────────────────────────────────────
-- Closes the admin panel and drops the admin at the store being edited so they
-- can inspect/adjust it in the world.
function TeleportToStore(coords)
    if not coords or coords.x == nil then return end
    CloseAdminPanel()
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false)
    if coords.w then SetEntityHeading(ped, coords.w + 0.0) end
end

-- ── Server result handlers ──────────────────────────────────────────────

RegisterNetEvent('orb-clothing:client:adminSaveResult', function(data)
    if data.success then
        lib.notify({ title = L('store_admin_title'), description = L('store_saved'), type = 'success' })
        -- Update the NUI sidebar with fresh list. Pass the saved store's id so the
        -- NUI can keep (or, for a brand-new store, switch into) edit mode on it —
        -- otherwise a create leaves the editor in "new" mode and the next save
        -- silently makes a duplicate instead of updating.
        SendNUIMessage({
            action = 'adminStoresSynced',
            stores = data.stores,
            savedId = data.store and data.store.id or nil,
        })
    end
end)

RegisterNetEvent('orb-clothing:client:adminDeleteResult', function(data)
    if data.success then
        lib.notify({ title = L('store_admin_title'), description = L('store_deleted'), type = 'success' })
        SendNUIMessage({ action = 'adminStoresSynced', stores = data.stores })
        -- Clear markers for deleted store
        markerZone = nil
        markerPed = nil
    end
end)

-- ── Placement & preview input loop ──────────────────────────────────────

local ENTER_KEY     = 38   -- E
local BACKSPACE_KEY = 194  -- Backspace
local SCROLL_UP     = 241
local SCROLL_DOWN   = 242
local ESC_KEY       = 200  -- ESC (for camera preview)

CreateThread(function()
    while true do
        Wait(0)

        -- Placement mode input
        if placementMode then
            -- Heading adjustment with scroll
            if IsControlJustPressed(0, SCROLL_UP) then
                placementHeading = (placementHeading + 5.0) % 360.0
            end
            if IsControlJustPressed(0, SCROLL_DOWN) then
                placementHeading = (placementHeading - 5.0) % 360.0
            end

            -- Confirm
            if IsControlJustReleased(0, ENTER_KEY) then
                ConfirmPlacement()
            end

            -- Cancel
            if IsControlJustReleased(0, BACKSPACE_KEY) then
                CancelPlacement()
            end

        -- Camera preview input
        elseif previewActive then
            if IsControlJustReleased(0, ENTER_KEY) or IsControlJustReleased(0, ESC_KEY) then
                StopCameraPreview()
            end

        -- When neither placement nor preview is active, sleep longer
        elseif not adminPanelOpen then
            Wait(500)
        end
    end
end)

-- ── 3D Marker rendering ────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)

        if not adminPanelOpen and not placementMode then
            Wait(500)
            goto continue
        end

        -- Draw zone marker (green transparent box)
        if markerZone then
            local sizeX = markerZone.sizeX or 14.0
            local sizeY = markerZone.sizeY or 10.0
            DrawMarker(1, -- cylinder
                markerZone.x, markerZone.y, markerZone.z - 0.98,
                0.0, 0.0, 0.0,
                0.0, 0.0, markerZone.w or 0.0,
                sizeX, sizeY, 0.5,
                0, 200, 0, 60,  -- green transparent
                false, false, 2, false, nil, nil, false)
        end

        -- Draw ped position marker (blue cone)
        if markerPed then
            DrawMarker(2, -- cone
                markerPed.x, markerPed.y, markerPed.z + 0.5,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0.4, 0.4, 0.6,
                0, 120, 255, 150,  -- blue
                false, false, 2, false, nil, nil, false)

            -- Direction arrow (small marker offset in heading direction)
            local rad = math.rad(markerPed.w)
            local arrowX = markerPed.x + math.sin(rad) * -1.0
            local arrowY = markerPed.y + math.cos(rad) * 1.0
            DrawMarker(2,
                arrowX, arrowY, markerPed.z + 0.15,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0.2, 0.2, 0.3,
                0, 120, 255, 150,
                false, false, 2, false, nil, nil, false)
        end

        -- During placement: draw helper marker following player
        if placementMode then
            local ped = PlayerPedId()
            local pCoords = GetEntityCoords(ped)

            -- Green circle at feet
            DrawMarker(1,
                pCoords.x, pCoords.y, pCoords.z - 0.98,
                0.0, 0.0, 0.0,
                0.0, 0.0, placementHeading,
                2.0, 2.0, 0.3,
                148, 216, 45, 120,  -- APX green
                false, false, 2, false, nil, nil, false)

            -- Direction arrow
            local rad = math.rad(placementHeading)
            local arrowX = pCoords.x + math.sin(rad) * -1.5
            local arrowY = pCoords.y + math.cos(rad) * 1.5
            DrawMarker(2,
                arrowX, arrowY, pCoords.z - 0.5,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0.3, 0.3, 0.5,
                148, 216, 45, 180,
                false, false, 2, false, nil, nil, false)
        end

        ::continue::
    end
end)

-- ── Cleanup ─────────────────────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if adminPanelOpen then
        CloseAdminPanel()
    end
end)

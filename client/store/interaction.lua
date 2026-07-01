-- ═══════════════════════════════════════════════════════════════════════
--                       STORE INTERACTION
-- Handles [E] prompt inside store zones and opens the correct creator.
-- For barber shops: draws chair markers, detects nearest chair, and
-- requires the player to stand near a chair before pressing [E].
-- ═══════════════════════════════════════════════════════════════════════

local currentStoreIndex = nil
local promptActive      = false
local inputThreadActive = false

local ENTER_KEY = 38 -- INPUT_ENTER (E key in FiveM)
local CHAIR_INTERACT_DIST = 2.0 -- metres: max distance to interact with a chair

-- ── Chair helpers ──────────────────────────────────────────────────────

local function getNearestChair(store)
    if not store or not store.chairs then return nil end
    local myCoords = GetEntityCoords(PlayerPedId())
    local bestChair, bestDist = nil, CHAIR_INTERACT_DIST
    for _, chair in ipairs(store.chairs) do
        local dist = #(myCoords - chair.coords)
        if dist < bestDist then
            bestChair = chair
            bestDist = dist
        end
    end
    return bestChair
end

-- ── Interior pinning ───────────────────────────────────────────────────
-- Pin the barbershop interior so it doesn't unload during routing bucket changes

function PinBarberInterior(coords)
    local interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        return interiorId
    end
    return nil
end

function UnpinBarberInterior(interiorId)
    if interiorId and interiorId ~= 0 then
        UnpinInterior(interiorId)
    end
end

-- ── Input + marker thread ──────────────────────────────────────────────
-- Single per-frame thread that handles BOTH marker drawing and key detection.
-- Only alive while the player is inside a store zone.
-- Self-terminates when they leave or open the creator.

local function startInputThread()
    if inputThreadActive then return end
    inputThreadActive = true
    CreateThread(function()
        while currentStoreIndex do
            local adminActive = IsAdminPanelActive and IsAdminPanelActive() or false
            local creatorOpen = IsCreatorOpen and IsCreatorOpen() or false

            -- Hide prompt while creator is open
            if creatorOpen and promptActive then
                lib.hideTextUI()
                promptActive = false
            end

            if not adminActive and not creatorOpen then
                -- Draw barber chair markers
                local store = Config.StoreLocations[currentStoreIndex]
                if store and store.chairs then
                    local chairs = store.chairs
                    for i = 1, #chairs do
                        local c = chairs[i].coords
                        DrawMarker(0, c.x, c.y, c.z + 0.5, 0, 0, 0, 0, 0, 0,
                            0.25, 0.25, 0.25, 255, 255, 255, 50, true, true, 2, false, nil, nil, false)
                    end
                end

                -- Key detection
                if IsControlJustReleased(0, ENTER_KEY) then
                    TriggerEvent('orb-clothing:client:openStore', currentStoreIndex)
                end
            end

            Wait(0)
        end
        inputThreadActive = false
    end)
end

-- ── Zone enter / exit events ──────────────────────────────────────────────

AddEventHandler('orb-clothing:client:enterStore', function(storeIndex)
    currentStoreIndex = storeIndex

    local store = Config.StoreLocations[storeIndex]
    local storeType = store and Config.StoreTypes[store.type]
    if storeType then
        if store.chairs then
            lib.showTextUI(L('tu_sit_chair'), { position = 'bottom-center' })
        else
            local label = store.label or storeType.blip.name or L('store_title')
            lib.showTextUI(L('tu_enter', label), { position = 'bottom-center' })
        end
        promptActive = true
    end

    startInputThread()
end)

AddEventHandler('orb-clothing:client:exitStore', function()
    currentStoreIndex = nil
    if promptActive then
        lib.hideTextUI()
        promptActive = false
    end
end)

-- ── Open store ────────────────────────────────────────────────────────────

AddEventHandler('orb-clothing:client:openStore', function(storeIndex)
    local store = Config.StoreLocations[storeIndex]
    if not store then return end

    local storeType = Config.StoreTypes[store.type]
    if not storeType then return end

    -- Job restriction check (client-side guard — server re-validates on save)
    if store.jobLock then
        local playerData = Bridge.GetPlayerData()
        local job = playerData and playerData.job and playerData.job.name
        if not job or job ~= store.jobLock then
            lib.notify({ title = L('access_denied_title'), description = L('access_denied_desc'), type = 'error' })
            return
        end
    end

    -- For barber shops with chairs, require the player to be near one
    local selectedChair = nil
    if store.chairs then
        selectedChair = getNearestChair(store)
        if not selectedChair then
            lib.notify({ title = L('barber_title'), description = L('barber_walk_closer'), type = 'info' })
            return
        end
    end

    -- Hide prompt once opening
    if promptActive then
        lib.hideTextUI()
        promptActive = false
    end

    local storeContext = {
        storeType   = store.type,
        storeIndex  = storeIndex,
        coords      = vector3(store.coords.x, store.coords.y, store.coords.z),
        pedPosition = store.pedPosition or nil,
        jobLock     = store.jobLock or nil,
        allowedTabs = storeType.tabs,
        openCamera  = storeType.openCamera or 'full',
        chair       = selectedChair,
    }

    TriggerEvent('orb-clothing:client:openCreator', storeContext)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if promptActive then
        lib.hideTextUI()
        promptActive = false
    end
end)

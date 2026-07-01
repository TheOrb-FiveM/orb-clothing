-- ═══════════════════════════════════════════════════════════════════════
--                    SERVER-SIDE STORE VALIDATION
-- Called before any save is committed to DB.
-- Returns true if the source is legitimately at the given store.
-- ═══════════════════════════════════════════════════════════════════════

local MAX_STORE_DISTANCE = 30.0  -- metres; generous to cover large store interiors

StoreValidation = {}

function StoreValidation.IsNearStore(src, storeIndex)
    local store = Config.StoreLocations[storeIndex]
    if not store then
        lib.print.warn(('[StoreValidation] Invalid storeIndex %s from source %s'):format(tostring(storeIndex), tostring(src)))
        return false
    end

    -- GetEntityCoords on a player ped (server-side)
    local ped    = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    local storeCoords = vector3(store.coords.x, store.coords.y, store.coords.z)
    local dist        = #(coords - storeCoords)

    if dist > MAX_STORE_DISTANCE then
        lib.print.warn(('[StoreValidation] Source %s is %.1f m from store %s (max %s) — rejecting save'):format(
            tostring(src), dist, tostring(storeIndex), MAX_STORE_DISTANCE))
        return false
    end

    return true
end

function StoreValidation.HasJobAccess(src, storeIndex)
    local store = Config.StoreLocations[storeIndex]
    if not store or not store.jobLock then return true end  -- no restriction

    local jobData = Bridge.GetJob(src)
    if not jobData then return false end

    local job = jobData.name
    if job ~= store.jobLock then
        lib.print.warn(('[StoreValidation] Source %s job "%s" does not match required "%s" for store %s'):format(
            tostring(src), tostring(job), store.jobLock, tostring(storeIndex)))
        return false
    end

    return true
end

-- Combined check: proximity + job
function StoreValidation.CanSave(src, storeIndex)
    return StoreValidation.IsNearStore(src, storeIndex)
       and StoreValidation.HasJobAccess(src, storeIndex)
end

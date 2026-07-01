-- ═══════════════════════════════════════════════════════════════════════
--                      ADMIN STORE COMMANDS
-- Net events and callbacks for admin store CRUD operations.
-- ═══════════════════════════════════════════════════════════════════════

-- ── Rebuild server-side Config.StoreLocations ───────────────────────────

-- Stores live entirely in the admin storage now (config defaults are seeded
-- into it on first run — see AdminStorage.SeedDefaultsIfNeeded). The config
-- list is only a one-time seed, never the live source.
local function RebuildServerStoreLocations()
    Config.StoreLocations = {}
    for _, s in ipairs(AdminStorage.GetAll()) do
        Config.StoreLocations[#Config.StoreLocations + 1] = {
            coords      = vector4(s.coords.x, s.coords.y, s.coords.z, s.coords.w),
            type        = s.type,
            pedPosition = s.pedPosition and vector4(s.pedPosition.x, s.pedPosition.y, s.pedPosition.z, s.pedPosition.w) or nil,
            size        = s.size and vector2(s.size.x, s.size.y) or nil,
            label       = s.label,
            jobLock     = s.jobLock,
            _adminId    = s.id
        }
    end
end

-- ── Callback: get admin stores list ─────────────────────────────────────

lib.callback.register('orb-clothing:server:getAdminStores', function(source)
    return AdminStorage.GetAll()
end)

-- ── Net event: save (create or update) ──────────────────────────────────

RegisterNetEvent('orb-clothing:server:adminSaveStore', function(data)
    local src = source
    if not AdminStorage.IsAdmin(src) then
        lib.print.warn(('[AdminCommands] Non-admin %s attempted adminSaveStore'):format(tostring(src)))
        return
    end

    -- Validate
    local valid, err = AdminStorage.ValidateStoreData(data)
    if not valid then
        TriggerClientEvent('orb-clothing:client:adminNotify', src, {
            title = L('store_admin_title'), description = err, type = 'error'
        })
        return
    end

    local result
    if data.id then
        -- Update existing
        result = AdminStorage.Update(data.id, data)
    else
        -- Create new — attach admin identity
        local identifiers = GetPlayerIdentifiers(src)
        local license = nil
        for _, id in ipairs(identifiers) do
            if id:find('license:') then
                license = id
                break
            end
        end
        data.createdBy = license or ('source:' .. tostring(src))
        result = AdminStorage.Add(data)
    end

    if result then
        -- Rebuild server store list
        RebuildServerStoreLocations()
        -- Notify all clients to reload
        TriggerClientEvent('orb-clothing:client:reloadStores', -1, AdminStorage.GetAll())
        -- Confirm to the admin
        TriggerClientEvent('orb-clothing:client:adminSaveResult', src, {
            success = true,
            store = result,
            stores = AdminStorage.GetAll()
        })
    else
        TriggerClientEvent('orb-clothing:client:adminNotify', src, {
            title = L('store_admin_title'), description = L('store_save_failed'), type = 'error'
        })
    end
end)

-- ── Net event: delete ───────────────────────────────────────────────────

RegisterNetEvent('orb-clothing:server:adminDeleteStore', function(data)
    local src = source
    if not AdminStorage.IsAdmin(src) then
        lib.print.warn(('[AdminCommands] Non-admin %s attempted adminDeleteStore'):format(tostring(src)))
        return
    end

    if not data or not data.id then
        TriggerClientEvent('orb-clothing:client:adminNotify', src, {
            title = L('store_admin_title'), description = L('store_no_id'), type = 'error'
        })
        return
    end

    local success = AdminStorage.Delete(data.id)
    if success then
        RebuildServerStoreLocations()
        TriggerClientEvent('orb-clothing:client:reloadStores', -1, AdminStorage.GetAll())
        TriggerClientEvent('orb-clothing:client:adminDeleteResult', src, {
            success = true,
            stores = AdminStorage.GetAll()
        })
    else
        TriggerClientEvent('orb-clothing:client:adminNotify', src, {
            title = L('store_admin_title'), description = L('store_not_found'), type = 'error'
        })
    end
end)

-- ── Initial rebuild on resource start ───────────────────────────────────

RebuildServerStoreLocations()

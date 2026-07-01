-- ═══════════════════════════════════════════════════════════════════════
--                      ADMIN STORE STORAGE
-- JSON file persistence for admin-created stores.
-- ═══════════════════════════════════════════════════════════════════════

AdminStorage = {}

local adminStores = {}
local resourceName = GetCurrentResourceName()
local filePath = Config.AdminStoreFile

-- ── Load / Save ─────────────────────────────────────────────────────────

function AdminStorage.Load()
    local raw = LoadResourceFile(resourceName, filePath)
    if raw and raw ~= '' then
        local decoded = json.decode(raw)
        if type(decoded) == 'table' then
            adminStores = decoded
            lib.print.info(('[AdminStorage] Loaded %d admin store(s)'):format(#adminStores))
            return
        end
    end
    adminStores = {}
    lib.print.info('[AdminStorage] No admin stores found, starting fresh')
end

function AdminStorage.Save()
    local encoded = json.encode(adminStores, { indent = true })
    SaveResourceFile(resourceName, filePath, encoded, -1)
end

-- ── CRUD ────────────────────────────────────────────────────────────────

function AdminStorage.GetAll()
    return adminStores
end

function AdminStorage.FindById(id)
    for i, store in ipairs(adminStores) do
        if store.id == id then
            return store, i
        end
    end
    return nil, nil
end

function AdminStorage.Add(data)
    -- Generate unique id
    data.id = ('store_%d_%d'):format(os.time(), math.random(1000, 9999))
    data.createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

    adminStores[#adminStores + 1] = data
    AdminStorage.Save()

    lib.print.info(('[AdminStorage] Created store %s (%s)'):format(data.id, data.type))
    return data
end

function AdminStorage.Update(id, data)
    local existing, idx = AdminStorage.FindById(id)
    if not existing then
        lib.print.warn(('[AdminStorage] Store %s not found for update'):format(tostring(id)))
        return nil
    end

    -- Preserve id, createdBy, createdAt
    data.id = existing.id
    data.createdBy = existing.createdBy
    data.createdAt = existing.createdAt

    adminStores[idx] = data
    AdminStorage.Save()

    lib.print.info(('[AdminStorage] Updated store %s'):format(id))
    return data
end

function AdminStorage.Delete(id)
    local _, idx = AdminStorage.FindById(id)
    if not idx then
        lib.print.warn(('[AdminStorage] Store %s not found for delete'):format(tostring(id)))
        return false
    end

    table.remove(adminStores, idx)
    AdminStorage.Save()

    lib.print.info(('[AdminStorage] Deleted store %s'):format(id))
    return true
end

-- ── Permission Check ────────────────────────────────────────────────────

function AdminStorage.IsAdmin(src)
    if not src or src <= 0 then return false end
    local permission = Config.AdminPermission or 'admin'
    return Bridge.HasPermission(src, permission)
end

-- ── Validation ──────────────────────────────────────────────────────────

function AdminStorage.ValidateStoreData(data)
    if not data then return false, 'No data provided' end

    -- Type
    if not data.type or not Config.StoreTypes[data.type] then
        return false, 'Invalid store type: ' .. tostring(data.type)
    end

    -- Coords
    if not data.coords or type(data.coords.x) ~= 'number' or type(data.coords.y) ~= 'number'
        or type(data.coords.z) ~= 'number' or type(data.coords.w) ~= 'number' then
        return false, 'Invalid zone coordinates'
    end

    -- Ped position
    if not data.pedPosition or type(data.pedPosition.x) ~= 'number' or type(data.pedPosition.y) ~= 'number'
        or type(data.pedPosition.z) ~= 'number' or type(data.pedPosition.w) ~= 'number' then
        return false, 'Invalid ped position'
    end

    -- Size (optional, use defaults if not set)
    if data.size then
        if type(data.size.x) ~= 'number' or type(data.size.y) ~= 'number'
            or data.size.x <= 0 or data.size.y <= 0 then
            return false, 'Invalid zone size'
        end
    end

    -- Camera preset
    if data.cameraPreset and not Config.Camera.Positions[data.cameraPreset] then
        return false, 'Invalid camera preset: ' .. tostring(data.cameraPreset)
    end

    return true, nil
end

-- ── Seed defaults ────────────────────────────────────────────────────────
-- One-time migration: copy the default stores defined in config into the
-- editable admin storage so EVERYTHING is managed in-game via /storeadmin.
-- Runs once (guarded by a marker file) so stores deleted in /storeadmin are
-- NOT resurrected on the next restart.
local SEED_MARKER = 'data/.stores_seeded'

-- Accept a vector4/vector2 or a {x,y,z,w}/{x,y} table → plain number table.
local function toCoordTable(v, withW)
    if not v then return nil end
    local t = { x = (v.x or 0.0) + 0.0, y = (v.y or 0.0) + 0.0, z = (v.z or 0.0) + 0.0 }
    if withW then t.w = (v.w or 0.0) + 0.0 end
    return t
end

function AdminStorage.SeedDefaultsIfNeeded()
    local marker = LoadResourceFile(resourceName, SEED_MARKER)
    if marker and marker ~= '' then return end -- already seeded once

    local base = (Config.TestMode and Config.TestStoreLocations) or Config.AllStoreLocations or {}
    local seeded = 0
    for i, s in ipairs(base) do
        local storeType = Config.StoreTypes[s.type]
        adminStores[#adminStores + 1] = {
            id           = ('store_default_%d'):format(i),
            type         = s.type,
            coords       = toCoordTable(s.coords, true),
            pedPosition  = toCoordTable(s.pedPosition or s.coords, true),
            size         = s.size and { x = s.size.x + 0.0, y = s.size.y + 0.0 } or nil,
            cameraPreset = (storeType and storeType.openCamera) or 'full',
            label        = s.label,
            jobLock      = s.jobLock,
            default      = true,
            createdBy    = 'config_seed',
            createdAt    = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }
        seeded = seeded + 1
    end

    AdminStorage.Save()
    SaveResourceFile(resourceName, SEED_MARKER, os.date('!%Y-%m-%dT%H:%M:%SZ'), -1)
    lib.print.info(('[AdminStorage] Seeded %d default store(s) into editable storage'):format(seeded))
end

-- ── Init ────────────────────────────────────────────────────────────────

AdminStorage.Load()
AdminStorage.SeedDefaultsIfNeeded()

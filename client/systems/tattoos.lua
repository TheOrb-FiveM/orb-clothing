-- ═══════════════════════════════════════════════════════════════════════
--                          TATTOO SYSTEM
-- ═══════════════════════════════════════════════════════════════════════

TattooSystem = {}

-- Returns true if the current player ped is using a female model
local function IsFemale()
    local model = GetEntityModel(PlayerPedId())
    return model == GetHashKey('mp_f_freemode_01')
end

-- Resolve the correct hash for the current gender.
-- Entry format: { hashMale, hashFemale } or legacy { hash } (single hash)
local function ResolveHash(entry)
    if entry.hash then
        -- Legacy single-hash format
        return entry.hash
    end
    local female = IsFemale()
    local h = female and entry.hashFemale or entry.hashMale
    -- Fall back to the other gender if the preferred one is absent
    if not h or h == '' then
        h = female and entry.hashMale or entry.hashFemale
    end
    return h
end

function TattooSystem.AddTattoo(ped, collection, hash)
    if not DoesEntityExist(ped) then
        return false
    end

    AddPedDecorationFromHashes(ped, GetHashKey(collection), GetHashKey(hash))

    local currentTattoos = DataCache.GetTattoos()
    table.insert(currentTattoos, {
        collection = collection,
        hash = hash
    })
    DataCache.StoreTattoos(currentTattoos)

    if Config.Debug then
        print(string.format('[TattooSystem] Tattoo added: %s / %s', collection, hash))
    end

    return true
end

-- Add a tattoo from a TattooData entry (gender-aware)
function TattooSystem.AddTattooEntry(ped, entry)
    if not DoesEntityExist(ped) then return false end

    local hash = ResolveHash(entry)
    if not hash or hash == '' then
        if Config.Debug then
            print('[TattooSystem] No valid hash for entry: ' .. (entry.name or '?'))
        end
        return false
    end

    local collection = entry.collection
    AddPedDecorationFromHashes(ped, GetHashKey(collection), GetHashKey(hash))

    local currentTattoos = DataCache.GetTattoos()
    table.insert(currentTattoos, { collection = collection, hash = hash })
    DataCache.StoreTattoos(currentTattoos)

    if Config.Debug then
        print(string.format('[TattooSystem] Tattoo added (entry): %s / %s', collection, hash))
    end

    return true
end

function TattooSystem.RemoveTattoo(ped, collection, hash)
    if not DoesEntityExist(ped) then
        return false
    end

    ClearPedDecorations(ped)

    local currentTattoos = DataCache.GetTattoos()
    local newTattoos = {}

    for _, tattoo in ipairs(currentTattoos) do
        if tattoo.collection ~= collection or tattoo.hash ~= hash then
            table.insert(newTattoos, tattoo)
            AddPedDecorationFromHashes(ped, GetHashKey(tattoo.collection), GetHashKey(tattoo.hash))
        end
    end

    DataCache.StoreTattoos(newTattoos)

    if Config.Debug then
        print(string.format('[TattooSystem] Tattoo removed: %s / %s', collection, hash))
    end

    return true
end

function TattooSystem.ClearAllTattoos(ped)
    if not DoesEntityExist(ped) then
        return false
    end

    ClearPedDecorations(ped)
    DataCache.StoreTattoos({})

    if Config.Debug then
        print('[TattooSystem] All tattoos cleared')
    end

    return true
end

function TattooSystem.ApplyTattoos(ped, tattoos)
    if not DoesEntityExist(ped) or not tattoos then
        return false
    end

    ClearPedDecorations(ped)

    for _, tattoo in ipairs(tattoos) do
        AddPedDecorationFromHashes(ped, GetHashKey(tattoo.collection), GetHashKey(tattoo.hash))
    end

    DataCache.StoreTattoos(tattoos)

    if Config.Debug then
        print(string.format('[TattooSystem] Applied %d tattoos', #tattoos))
    end

    return true
end

-- Build a serialisable version of TattooData for the NUI.
-- Returns { ZONE_TORSO = [...], ZONE_LEFT_ARM = [...], ... }
-- Each entry exposes only: name, label, collection, zone
-- The hash is NOT sent to the client NUI — it is resolved server-side in AddTattooEntry.
function TattooSystem.GetTattooList()
    local female = IsFemale()
    local result = {}
    for zone, entries in pairs(TattooData) do
        result[zone] = {}
        for _, entry in ipairs(entries) do
            -- Only include if a hash exists for this gender
            local hash = female and entry.hashFemale or entry.hashMale
            if not hash or hash == '' then
                hash = female and entry.hashMale or entry.hashFemale
            end
            if hash and hash ~= '' then
                table.insert(result[zone], {
                    name       = entry.name,
                    label      = entry.label,
                    collection = entry.collection,
                    hash       = hash,
                    zone       = zone,
                })
            end
        end
    end
    return result
end

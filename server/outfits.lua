-- ═══════════════════════════════════════════════════════════════════════
--                          OUTFITS — SERVER
-- ═══════════════════════════════════════════════════════════════════════
-- Saved outfits = a snapshot of clothing + props + accessories (with textures).
-- CRUD + sharing between players (with accept/decline). Server-authoritative:
-- caps, costs, ownership and share targeting are all validated here.

if not (Config.Outfits and Config.Outfits.enabled) then return end

-- ── Auto-migration ───────────────────────────────────────────────────
MySQL.ready(function()
    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS `orb_clothing_outfits` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `name` VARCHAR(50) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_owner_name` (`identifier`, `name`),
            KEY `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]], {})
    if Config.Debug then print('[orb-clothing] Outfits table verified') end
end)

-- Component / prop allowlist — an outfit is clothing + props ONLY (no hair/face).
local CLOTHING_IDS = { [1] = true, [3] = true, [4] = true, [5] = true, [6] = true, [8] = true, [11] = true }
local PROP_IDS     = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }

local maxPerPlayer = Config.Outfits.maxPerPlayer or 10

-- ── Helpers ──────────────────────────────────────────────────────────
local function sanitizeName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if #name < 1 or #name > 30 then return nil end
    if name:find('[%z\1-\31]') then return nil end -- reject control characters
    return name
end

local function clampInt(v, lo, hi, default)
    v = tonumber(v)
    if not v then return default end
    v = math.floor(v)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Validate + normalise an incoming outfit payload (trust boundary).
local function validateOutfitData(data)
    if type(data) ~= 'table' then return nil end
    local out = {
        gender     = (data.gender == 'female') and 'female' or 'male',
        components = {},
        props      = {},
    }
    if type(data.components) == 'table' then
        for k, item in pairs(data.components) do
            local id = tonumber(k)
            if id and CLOTHING_IDS[id] and type(item) == 'table' then
                out.components[tostring(id)] = { d = clampInt(item.d, -1, 5000, 0), t = clampInt(item.t, 0, 255, 0) }
            end
        end
    end
    if type(data.props) == 'table' then
        for k, item in pairs(data.props) do
            local id = tonumber(k)
            if id and PROP_IDS[id] and type(item) == 'table' then
                out.props[tostring(id)] = { d = clampInt(item.d, -1, 5000, -1), t = clampInt(item.t, 0, 255, 0) }
            end
        end
    end
    return out
end

local function countOutfits(identifier)
    return MySQL.scalar.await('SELECT COUNT(*) FROM orb_clothing_outfits WHERE identifier = ?', { identifier }) or 0
end

local function fetchOutfits(identifier)
    local rows = MySQL.query.await(
        'SELECT id, name, data FROM orb_clothing_outfits WHERE identifier = ? ORDER BY created_at DESC',
        { identifier }
    ) or {}
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = { id = row.id, name = row.name, data = json.decode(row.data) }
    end
    return list
end

local function pushList(src, identifier)
    TriggerClientEvent('orb-clothing:client:outfitsUpdated', src, fetchOutfits(identifier))
end

local function notify(src, ok, key, arg)
    TriggerClientEvent('orb-clothing:client:outfitResult', src, { ok = ok, key = key, arg = arg })
end

local function isOnline(pid)
    return pid and GetPlayerName(pid) ~= nil
end

-- Persist the outfit's clothing/props (with real textures) into the player's
-- saved appearance so the look survives a relog. The merge path in
-- server/main.lua keeps these keys on subsequent normal saves.
local function persistLook(identifier, outfit)
    local existingJson = MySQL.scalar.await('SELECT appearance FROM character_appearance WHERE identifier = ?', { identifier })
    local appearance = existingJson and json.decode(existingJson) or {}
    appearance.clothing = outfit.components
    appearance.props = outfit.props
    MySQL.update.await(
        'INSERT INTO character_appearance (identifier, appearance) VALUES (?, ?) ON DUPLICATE KEY UPDATE appearance = VALUES(appearance), updated_at = CURRENT_TIMESTAMP',
        { identifier, json.encode(appearance) }
    )
end

-- ── List ─────────────────────────────────────────────────────────────
lib.callback.register('orb-clothing:server:listOutfits', function(src)
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return {} end
    return fetchOutfits(identifier)
end)

-- ── Save ──────────────────────────────────────────────────────────────
RegisterNetEvent('orb-clothing:server:saveOutfit', function(payload)
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local name = sanitizeName(payload and payload.name)
    if not name then notify(src, false, 'outfit_name_invalid'); return end

    local data = validateOutfitData(payload and payload.data)
    if not data then notify(src, false, 'outfit_name_invalid'); return end

    -- Cap only applies to NEW names (overwriting an existing outfit is allowed).
    local existing = MySQL.scalar.await('SELECT id FROM orb_clothing_outfits WHERE identifier = ? AND name = ?', { identifier, name })
    if not existing and countOutfits(identifier) >= maxPerPlayer then
        notify(src, false, 'outfit_cap_reached', tostring(maxPerPlayer))
        return
    end

    local cost = Config.Outfits.saveCost or 0
    if cost > 0 and not Bridge.RemoveMoney(src, cost, 'orb-clothing outfit save') then
        notify(src, false, 'no_money'); return
    end

    MySQL.update.await(
        'INSERT INTO orb_clothing_outfits (identifier, name, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { identifier, name, json.encode(data) }
    )
    notify(src, true, 'outfit_saved')
    pushList(src, identifier)
end)

-- ── Apply ─────────────────────────────────────────────────────────────
RegisterNetEvent('orb-clothing:server:applyOutfit', function(payload)
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local outfitId = tonumber(payload and payload.id)
    if not outfitId then return end

    local row = MySQL.single.await('SELECT data FROM orb_clothing_outfits WHERE id = ? AND identifier = ?', { outfitId, identifier })
    if not row then notify(src, false, 'outfit_name_invalid'); return end

    local data = validateOutfitData(json.decode(row.data))
    if not data then return end

    local cost = Config.Outfits.applyCost or 0
    if cost > 0 and not Bridge.RemoveMoney(src, cost, 'orb-clothing outfit apply') then
        notify(src, false, 'no_money'); return
    end

    persistLook(identifier, data)
    TriggerClientEvent('orb-clothing:client:applyOutfitData', src, data)
    notify(src, true, 'outfit_applied')
end)

-- ── Rename ────────────────────────────────────────────────────────────
RegisterNetEvent('orb-clothing:server:renameOutfit', function(payload)
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local outfitId = tonumber(payload and payload.id)
    local newName = sanitizeName(payload and payload.newName)
    if not outfitId or not newName then notify(src, false, 'outfit_name_invalid'); return end

    local clash = MySQL.scalar.await('SELECT id FROM orb_clothing_outfits WHERE identifier = ? AND name = ? AND id <> ?', { identifier, newName, outfitId })
    if clash then notify(src, false, 'outfit_name_invalid'); return end

    local affected = MySQL.update.await('UPDATE orb_clothing_outfits SET name = ? WHERE id = ? AND identifier = ?', { newName, outfitId, identifier })
    if affected and affected > 0 then
        notify(src, true, 'outfit_renamed')
        pushList(src, identifier)
    end
end)

-- ── Delete ────────────────────────────────────────────────────────────
RegisterNetEvent('orb-clothing:server:deleteOutfit', function(payload)
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local outfitId = tonumber(payload and payload.id)
    if not outfitId then return end

    local affected = MySQL.update.await('DELETE FROM orb_clothing_outfits WHERE id = ? AND identifier = ?', { outfitId, identifier })
    if affected and affected > 0 then
        notify(src, true, 'outfit_deleted')
        pushList(src, identifier)
    end
end)

-- ── Sharing ───────────────────────────────────────────────────────────
-- [targetSrc] = { from, fromName, name, data, expires }
local pendingShares = {}
-- [senderSrc] = os.time of last share (cooldown)
local lastShareAt = {}

-- Picker data: online players sorted by distance to the sharer's pre-store origin.
lib.callback.register('orb-clothing:server:getShareTargets', function(src, origin)
    if not Config.Outfits.shareEnabled then return {} end
    local ox, oy, oz
    if type(origin) == 'table' then ox, oy, oz = origin.x, origin.y, origin.z end
    local radius = Config.Outfits.shareRadius or 0.0

    local list = {}
    for _, pidStr in ipairs(GetPlayers()) do
        local pid = tonumber(pidStr)
        if pid and pid ~= src then
            local dist = nil
            if ox then
                local ped = GetPlayerPed(pid)
                if ped and ped ~= 0 then
                    dist = #(vector3(ox + 0.0, oy + 0.0, oz + 0.0) - GetEntityCoords(ped))
                end
            end
            if radius <= 0 or (dist and dist <= radius) then
                list[#list + 1] = { id = pid, name = GetPlayerName(pid), dist = dist and math.floor(dist + 0.5) or nil }
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.dist or math.huge) < (b.dist or math.huge)
    end)
    return list
end)

RegisterNetEvent('orb-clothing:server:shareOutfit', function(payload)
    local src = source
    if not Config.Outfits.shareEnabled then return end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local outfitId = tonumber(payload and payload.id)
    local targetId = tonumber(payload and payload.targetId)
    if not outfitId or not targetId or targetId == src then notify(src, false, 'outfit_no_target'); return end
    if not isOnline(targetId) then notify(src, false, 'outfit_no_target'); return end

    local now = os.time()
    local cd = Config.Outfits.shareCooldown or 0
    if cd > 0 and lastShareAt[src] and (now - lastShareAt[src]) < cd then
        notify(src, false, 'outfit_share_cooldown'); return
    end

    local row = MySQL.single.await('SELECT name, data FROM orb_clothing_outfits WHERE id = ? AND identifier = ?', { outfitId, identifier })
    if not row then notify(src, false, 'outfit_name_invalid'); return end

    lastShareAt[src] = now
    pendingShares[targetId] = {
        from = src, fromName = GetPlayerName(src),
        name = row.name, data = json.decode(row.data),
        expires = now + 30,
    }
    TriggerClientEvent('orb-clothing:client:outfitShareInvite', targetId, { fromName = GetPlayerName(src), outfitName = row.name })
    notify(src, true, 'outfit_shared', GetPlayerName(targetId))
end)

RegisterNetEvent('orb-clothing:server:shareResponse', function(accept)
    local src = source
    local pending = pendingShares[src]
    pendingShares[src] = nil
    if not pending or os.time() > pending.expires then return end

    local senderSrc = pending.from
    if not accept then
        if isOnline(senderSrc) then notify(senderSrc, false, 'outfit_share_declined') end
        return
    end

    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local existing = MySQL.scalar.await('SELECT id FROM orb_clothing_outfits WHERE identifier = ? AND name = ?', { identifier, pending.name })
    if not existing and countOutfits(identifier) >= maxPerPlayer then
        notify(src, false, 'outfit_cap_reached', tostring(maxPerPlayer))
        return
    end

    local data = validateOutfitData(pending.data)
    if not data then return end

    MySQL.update.await(
        'INSERT INTO orb_clothing_outfits (identifier, name, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
        { identifier, pending.name, json.encode(data) }
    )
    notify(src, true, 'outfit_share_received', pending.fromName)
    if isOnline(senderSrc) then notify(senderSrc, true, 'outfit_shared', GetPlayerName(src)) end
    pushList(src, identifier)
end)

AddEventHandler('playerDropped', function()
    local src = source
    pendingShares[src] = nil
    lastShareAt[src] = nil
    for target, pending in pairs(pendingShares) do
        if pending.from == src then pendingShares[target] = nil end
    end
end)

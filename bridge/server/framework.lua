-- ═══════════════════════════════════════════════════════════════════════
--                    SERVER BRIDGE - FRAMEWORK
-- Provides unified API for player data across QBX, QBCore, ESX, Standalone
-- ═══════════════════════════════════════════════════════════════════════

Bridge = Bridge or {}

-- Lazy-load framework objects on first use (not at file load time)
-- so we don't block the server thread waiting for qb-core / es_extended to start.
local QBCore, ESX

local function getQBCore()
    if not QBCore then
        local ok, obj = pcall(exports['qb-core'].GetCoreObject, exports['qb-core'])
        QBCore = ok and obj or nil
    end
    return QBCore
end

local function getESX()
    if not ESX then
        local ok, obj = pcall(exports['es_extended'].getSharedObject, exports['es_extended'])
        ESX = ok and obj or nil
    end
    return ESX
end

-- ── GetIdentifier ────────────────────────────────────────────────────
-- Returns the unique player identifier (citizenid, identifier, license)

function Bridge.GetIdentifier(src)
    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.citizenid

    elseif Bridge.Framework == 'qbcore' then
        local qb = getQBCore()
        if not qb then return nil end
        local player = qb.Functions.GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.citizenid

    elseif Bridge.Framework == 'esx' then
        local esx = getESX()
        if not esx then return nil end
        local xPlayer = esx.GetPlayerFromId(src)
        return xPlayer and xPlayer.identifier

    else -- standalone
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            if id:find('license:') then return id end
        end
        return nil
    end
end

-- ── GetJob ───────────────────────────────────────────────────────────
-- Returns { name = "jobname", grade = N } or nil

function Bridge.GetJob(src)
    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.job

    elseif Bridge.Framework == 'qbcore' then
        local qb = getQBCore()
        if not qb then return nil end
        local player = qb.Functions.GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.job

    elseif Bridge.Framework == 'esx' then
        local esx = getESX()
        if not esx then return nil end
        local xPlayer = esx.GetPlayerFromId(src)
        return xPlayer and xPlayer.job

    else
        return nil -- standalone has no job system
    end
end

-- ── HasPermission ────────────────────────────────────────────────────
-- Checks if player has admin permission

function Bridge.HasPermission(src, permission)
    -- ACE always checked first (works on all frameworks)
    if IsPlayerAceAllowed(tostring(src), ('command.%s'):format('storeadmin')) then
        return true
    end

    if Bridge.Framework == 'qbx' then
        local ok, result = pcall(exports.qbx_core.HasPermission, exports.qbx_core, src, permission)
        return ok and result

    elseif Bridge.Framework == 'qbcore' then
        local qb = getQBCore()
        if not qb then return nil end
        local player = qb.Functions.GetPlayer(src)
        if player then
            local group = player.PlayerData and player.PlayerData.group
            return group == 'admin' or group == 'god' or group == permission
        end

    elseif Bridge.Framework == 'esx' then
        local esx = getESX()
        if not esx then return nil end
        local xPlayer = esx.GetPlayerFromId(src)
        if xPlayer then
            local group = xPlayer.getGroup()
            return group == 'admin' or group == 'superadmin' or group == permission
        end
    end

    return false
end

-- ── MirrorSkin ───────────────────────────────────────────────────────
-- Mirrors appearance data to framework-specific skin tables
-- so character select previews keep working

function Bridge.MirrorSkin(identifier, model, skinJson)
    if not identifier then return end

    if Bridge.Framework == 'qbx' or Bridge.Framework == 'qbcore' then
        -- QBCore uses `playerskins` table for character select preview.
        -- IMPORTANT: qb-multicharacter's client does `tonumber(result.model)`
        -- on the DB value and falls back to a random ped if the tonumber fails.
        -- Stock qb-clothing stored the string model name and thus always
        -- triggered the random-preview fallback (a latent qb-clothing bug).
        -- We store the numeric joaat hash as a string so tonumber() succeeds
        -- and the character-select preview actually matches the saved gender.
        local modelForPreview = tostring(joaat(model))
        MySQL.Async.execute('UPDATE playerskins SET active = 0 WHERE citizenid = ?', { identifier }, function()
            MySQL.Async.execute(
                'INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1) ON DUPLICATE KEY UPDATE model = VALUES(model), skin = VALUES(skin), active = 1',
                { identifier, modelForPreview, skinJson },
                function() end
            )
        end)

    elseif Bridge.Framework == 'esx' then
        -- ESX commonly uses `skin` table
        pcall(function()
            MySQL.Async.execute(
                'INSERT INTO skin (identifier, model, skin) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE model = VALUES(model), skin = VALUES(skin)',
                { identifier, model, skinJson },
                function() end
            )
        end)
    end
    -- standalone: no skin mirror needed
end

-- ── RemoveMoney ──────────────────────────────────────────────────────
-- Removes money from player (for future store pricing)
-- Returns true if successful

function Bridge.RemoveMoney(src, amount, reason)
    if Bridge.Framework == 'qbx' then
        local player = exports.qbx_core:GetPlayer(src)
        if player then
            return player.Functions.RemoveMoney('cash', amount, reason)
                or player.Functions.RemoveMoney('bank', amount, reason)
        end

    elseif Bridge.Framework == 'qbcore' then
        local qb = getQBCore()
        if not qb then return nil end
        local player = qb.Functions.GetPlayer(src)
        if player then
            return player.Functions.RemoveMoney('cash', amount, reason)
                or player.Functions.RemoveMoney('bank', amount, reason)
        end

    elseif Bridge.Framework == 'esx' then
        local esx = getESX()
        if not esx then return nil end
        local xPlayer = esx.GetPlayerFromId(src)
        if xPlayer then
            if xPlayer.getMoney() >= amount then
                xPlayer.removeMoney(amount, reason)
                return true
            elseif xPlayer.getAccount('bank').money >= amount then
                xPlayer.removeAccountMoney('bank', amount, reason)
                return true
            end
        end

    else -- standalone
        return true -- standalone: no money system, always allow
    end

    return false
end

-- ── Auto-migrate database ────────────────────────────────────────────
-- Creates the table if it doesn't exist so customers don't need to import SQL
-- Uses MySQL.ready() to wait for the connection pool inside its own thread,
-- avoiding any blocking of the server main thread.

MySQL.ready(function()
    MySQL.update.await([[
        CREATE TABLE IF NOT EXISTS `character_appearance` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(60) NOT NULL,
            `appearance` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `idx_identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    ]], {})

    -- Also ensure `playerskins` exists on QBCore/QBX so that
    -- qb-multicharacter:server:getSkin doesn't error on a fresh install.
    -- MirrorSkin keeps this table in sync with character_appearance on every
    -- save, which in turn lets the char-select preview work unmodified.
    -- Schema matches stock qb-clothing so it's a drop-in.
    --
    -- Wait for detection to SETTLE first (see bridge/_detect.lua): if the
    -- framework started after us, the load-time snapshot says 'standalone' and
    -- this whole block would be skipped — no playerskins mirror, broken
    -- char-select previews — purely because of server.cfg ordering.
    while not Bridge.FrameworkSettled do Wait(250) end

    if Bridge.Framework == 'qbcore' or Bridge.Framework == 'qbx' then
        MySQL.update.await([[
            CREATE TABLE IF NOT EXISTS `playerskins` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `model` VARCHAR(255) NOT NULL,
                `skin` LONGTEXT NOT NULL,
                `active` TINYINT(1) NOT NULL DEFAULT 1,
                PRIMARY KEY (`id`),
                KEY `citizenid` (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
        ]], {})

        -- Heal legacy skins: stock qb-clothing stored the model as a STRING
        -- ("mp_m_freemode_01"), but qb-multicharacter runs tonumber(model) and
        -- falls back to a RANDOM PED when that fails — so characters created
        -- before orb-clothing spawn as a random ped. Convert the two freemode
        -- model names to their numeric joaat hash (the exact value MirrorSkin
        -- writes for new characters). Idempotent — already-numeric rows are left
        -- untouched. Runs once per boot.
        MySQL.update.await("UPDATE playerskins SET model = ? WHERE model = 'mp_m_freemode_01'", { tostring(joaat('mp_m_freemode_01')) })
        MySQL.update.await("UPDATE playerskins SET model = ? WHERE model = 'mp_f_freemode_01'", { tostring(joaat('mp_f_freemode_01')) })
    end

    if Config.Debug then
        print('[orb-clothing] Database tables verified')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
--                    CLIENT BRIDGE - FRAMEWORK
-- Provides unified API for player data and events across frameworks
-- ═══════════════════════════════════════════════════════════════════════

Bridge = Bridge or {}

-- Lazy-load framework objects on first use (not at file load time)
-- so we don't block the client thread waiting for qb-core / es_extended to start.
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

-- ── GetPlayerData ────────────────────────────────────────────────────
-- Returns normalized player data table with .job.name

function Bridge.GetPlayerData()
    if Bridge.Framework == 'qbx' then
        return exports.qbx_core:GetPlayerData()

    elseif Bridge.Framework == 'qbcore' then
        local qb = getQBCore()
        return qb and qb.Functions.GetPlayerData()

    elseif Bridge.Framework == 'esx' then
        local esx = getESX()
        return esx and esx.GetPlayerData()

    else
        return nil -- standalone: no player data
    end
end

-- ── OnPlayerLoaded ───────────────────────────────────────────────────
-- Registers a callback for when the player character is fully loaded

function Bridge.OnPlayerLoaded(cb)
    if Bridge.Framework == 'qbx' or Bridge.Framework == 'qbcore' then
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', cb)

    elseif Bridge.Framework == 'esx' then
        RegisterNetEvent('esx:playerLoaded', function(xPlayerData)
            cb()
        end)

    else -- standalone
        AddEventHandler('playerSpawned', function()
            cb()
        end)
    end
end

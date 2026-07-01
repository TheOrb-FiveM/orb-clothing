-- ═══════════════════════════════════════════════════════════════════════
--          SERVER COMPATIBILITY SHIM — qb-clothing / rcore_clothes
-- ═══════════════════════════════════════════════════════════════════════
-- Mirrors the qb-clothing server API so consumer resources (qb-prison,
-- qb-adminmenu, etc.) that fire server events against qb-clothing keep
-- working after qb-clothing is removed and orb-clothing is installed.
--
-- Gated by Config.CompatMode.qbClothing — zero cost when disabled.
-- See docs/COMPAT_MODE.md for the full coverage matrix.
-- ═══════════════════════════════════════════════════════════════════════

if not (Config.CompatMode and Config.CompatMode.qbClothing) then return end

-- ── qb-clothing:saveSkin ─────────────────────────────────────────────
-- Legacy save-skin event. orb-clothing has its own save path
-- (orb-clothing:server:saveAppearance with merge semantics) that consumer
-- resources do NOT call directly — only qb-clothing's internal menu did.
-- No-op to prevent "unknown event" noise.
RegisterNetEvent('qb-clothing:saveSkin', function() end)

-- ── qb-clothes:loadPlayerSkin ────────────────────────────────────────
-- Triggered by qb-prison (and others) on release / uniform change to
-- force a reload of the player's saved look. We bounce a client event
-- that the client shim catches and resolves against the orb DB.
RegisterNetEvent('qb-clothes:loadPlayerSkin', function()
    local src = source
    -- Passing nil skinData triggers the client shim's fallback path,
    -- which calls orb-clothing:server:loadAppearance callback.
    TriggerClientEvent('qb-clothes:loadSkin', src, false, nil, nil)
end)

-- ── qb-clothes:saveOutfit ────────────────────────────────────────────
-- orb-clothing has no outfit slot system — no-op.
RegisterNetEvent('qb-clothes:saveOutfit', function() end)

-- ── qb-clothing:server:removeOutfit ──────────────────────────────────
-- Same as above — no slots to remove.
RegisterNetEvent('qb-clothing:server:removeOutfit', function() end)

-- ── qb-clothing:server:getOutfits ────────────────────────────────────
-- Callback used by qb-apartments / qb-houses / qb-management wardrobes
-- to list saved outfits. Return an empty list so callers see "no outfits"
-- instead of erroring.
local function registerEmptyOutfitCallback()
    local ok, QBCore = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if not ok or not QBCore or not QBCore.Functions or not QBCore.Functions.CreateCallback then
        return
    end

    QBCore.Functions.CreateCallback('qb-clothing:server:getOutfits', function(_, cb)
        cb({})
    end)
end

CreateThread(function()
    -- Delay so qb-core has time to initialize on startup
    Wait(1000)
    registerEmptyOutfitCallback()
end)

if Config.Debug then
    print('^2[orb-clothing] qb-clothing compat mode: server shim loaded^7')
end

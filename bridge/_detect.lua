-- ═══════════════════════════════════════════════════════════════════════
--                    ORB-CLOTHING - AUTO DETECTION
-- Detects framework, HUD, target system, and other dependencies
-- automatically at startup. No manual configuration required.
-- ═══════════════════════════════════════════════════════════════════════

-- Resource lists below are ORDERED ARRAYS walked with ipairs — never hash
-- tables walked with pairs(). pairs() iteration order is non-deterministic in
-- Lua and can differ between server restarts. On QBox BOTH `qbx_core` and
-- `qb-core` report 'started' (qbx_core provides the qb-core alias), so a
-- pairs() walk returned 'qbx' on one boot and 'qbcore' on the next, at random.
-- That flipped the model format MirrorSkin writes into `playerskins` (model
-- NAME for qbx vs numeric joaat hash for qb), so on a bad boot qbx_core
-- joaat()'d an already-numeric hash into an invalid model and the
-- character-select loading screen hung forever. First match wins, so priority
-- is explicit and stable across restarts.
function CheckDependency(resourceList)
    for _, entry in ipairs(resourceList) do
        local state = GetResourceState(entry[1])
        if state and state:find('started') then
            return entry[2]
        end
    end
    return false
end

-- ── Framework Detection ──────────────────────────────────────────────
-- ORDER MATTERS: qbx_core MUST be checked before qb-core — a QBox server
-- reports both as started, and QBox has to win.
local frameworks = {
    { 'qbx_core',    'qbx'    },
    { 'qb-core',     'qbcore' },
    { 'es_extended', 'esx'    },
}

-- ── HUD Detection ────────────────────────────────────────────────────
local hudSystems = {
    { 'hud_apx',      'hud_apx'      },
    { 'ps-hud',       'ps-hud'       },
    { 'qb-hud',       'qb-hud'       },
    { 'esx_hud',      'esx_hud'      },
    { 'qs-hud',       'qs-hud'       },
    { '17mov_Carhud', '17mov_Carhud' },
    { 'ox_hud',       'ox_hud'       },
    { 'r_hud',        'r_hud'        },
}

-- ── Detect ───────────────────────────────────────────────────────────

Bridge = Bridge or {}

-- Manual overrides from config.lua take priority over auto-detection.
-- This file is loaded AFTER config.lua (see fxmanifest shared_scripts) exactly
-- so Config can be read synchronously right here.
local VALID_FRAMEWORKS = { qbx = true, qbcore = true, esx = true, standalone = true }

local frameworkOverride = Config and Config.FrameworkOverride or nil
if frameworkOverride and not VALID_FRAMEWORKS[frameworkOverride] then
    print(('^1[orb-clothing] Config.FrameworkOverride = "%s" is not a valid value (use "qbx", "qbcore", "esx" or "standalone"). Ignoring it and auto-detecting instead.^0'):format(tostring(frameworkOverride)))
    frameworkOverride = nil
end

Bridge.Framework = frameworkOverride or CheckDependency(frameworks) or 'standalone'

-- HUDOverride = false is a MEANINGFUL value ("disable HUD handling"), so only
-- nil counts as "auto-detect".
local hudOverridden = Config ~= nil and Config.HUDOverride ~= nil
if hudOverridden then
    Bridge.HUD = Config.HUDOverride
else
    Bridge.HUD = CheckDependency(hudSystems) or false
end

-- ── Startup Banner ───────────────────────────────────────────────────

local function StatusTag(val, overridden)
    if val then
        return '^2' .. tostring(val) .. '^0' .. (overridden and ' ^3(override)^0' or '')
    end
    if overridden then return '^3disabled (override)^0' end
    return '^1none^0'
end

-- Print banner on server only, at load time (no CreateThread) so it's not
-- delayed by oxmysql connection wait or other blocking startup scripts.
if IsDuplicityVersion() then
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?'
    print('^5══════════════════════════════════════════^0')
    print('^5  orb-clothing ^0v' .. version)
    print('^5══════════════════════════════════════════^0')
    print('  Framework : ' .. StatusTag(Bridge.Framework, frameworkOverride ~= nil))
    print('  HUD       : ' .. StatusTag(Bridge.HUD, hudOverridden))
    print('  ox_lib    : ' .. StatusTag(GetResourceState('ox_lib') == 'started' and 'ok' or nil))
    print('  oxmysql   : ' .. StatusTag(GetResourceState('oxmysql') == 'started' and 'ok' or nil))
    print('^5══════════════════════════════════════════^0')
end

-- ── Late-start settling ──────────────────────────────────────────────
-- The snapshot above runs the instant this file loads. If the framework is
-- ensured AFTER this resource (or was still 'starting' at that instant), we'd
-- wrongly commit to 'standalone': appearances stop mirroring into playerskins,
-- and the character-select preview breaks. So a 'standalone' verdict stays
-- PROVISIONAL for a while: keep re-polling and upgrade the moment the real
-- framework finishes starting. Consumers branch on Bridge.Framework at call
-- time, so the upgrade applies everywhere. Bridge.FrameworkSettled gates the
-- framework-conditional DB migration (the playerskins mirror).
--
-- An explicit override is never provisional — it is already the final answer.
Bridge.FrameworkSettled = frameworkOverride ~= nil or Bridge.Framework ~= 'standalone'

if not Bridge.FrameworkSettled then
    CreateThread(function()
        local deadline = GetGameTimer() + 60000
        while GetGameTimer() < deadline do
            local found = CheckDependency(frameworks)
            if found then
                Bridge.Framework = found
                if IsDuplicityVersion() then
                    print(('^3[orb-clothing] Framework detected LATE (%s started after this resource). Recovered automatically — but fix your server.cfg: the framework must be ensured BEFORE orb-clothing.^0'):format(found))
                end
                break
            end
            Wait(500)
        end
        Bridge.FrameworkSettled = true
    end)
end

-- The HUD can also finish starting after us; adopt it when it does.
-- Skipped entirely when the operator set an explicit HUDOverride.
if not hudOverridden and not Bridge.HUD then
    CreateThread(function()
        local deadline = GetGameTimer() + 60000
        while GetGameTimer() < deadline do
            Bridge.HUD = CheckDependency(hudSystems) or false
            if Bridge.HUD then break end
            Wait(1000)
        end
    end)
end

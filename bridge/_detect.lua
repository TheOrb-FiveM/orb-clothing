-- ═══════════════════════════════════════════════════════════════════════
--                    ORB-CLOTHING - AUTO DETECTION
-- Detects framework, HUD, target system, and other dependencies
-- automatically at startup. No manual configuration required.
-- ═══════════════════════════════════════════════════════════════════════

function CheckDependency(resourceTable)
    for resourceName, id in pairs(resourceTable) do
        local state = GetResourceState(resourceName)
        if state and state:find('started') then
            return id
        end
    end
    return false
end

-- ── Framework Detection ──────────────────────────────────────────────
local frameworks = {
    ['qbx_core']     = 'qbx',
    ['qb-core']      = 'qbcore',
    ['es_extended']   = 'esx',
}

-- ── HUD Detection ────────────────────────────────────────────────────
local hudSystems = {
    ['hud_apx']      = 'hud_apx',
    ['ps-hud']       = 'ps-hud',
    ['qb-hud']       = 'qb-hud',
    ['esx_hud']      = 'esx_hud',
    ['qs-hud']       = 'qs-hud',
    ['17mov_Carhud'] = '17mov_Carhud',
    ['ox_hud']       = 'ox_hud',
    ['r_hud']        = 'r_hud',
}

-- ── Detect ───────────────────────────────────────────────────────────

Bridge = Bridge or {}

Bridge.Framework      = CheckDependency(frameworks)      or 'standalone'
Bridge.HUD            = CheckDependency(hudSystems)       or false

-- ── Startup Banner ───────────────────────────────────────────────────

local function StatusTag(val)
    if val then return '^2' .. val .. '^0' end
    return '^1none^0'
end

-- Print banner on server only, at load time (no CreateThread) so it's not
-- delayed by oxmysql connection wait or other blocking startup scripts.
if IsDuplicityVersion() then
    local version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '?'
    print('^5══════════════════════════════════════════^0')
    print('^5  orb-clothing ^0v' .. version)
    print('^5══════════════════════════════════════════^0')
    print('  Framework : ' .. StatusTag(Bridge.Framework))
    print('  HUD       : ' .. StatusTag(Bridge.HUD))
    print('  ox_lib    : ' .. StatusTag(GetResourceState('ox_lib') == 'started' and 'ok' or nil))
    print('  oxmysql   : ' .. StatusTag(GetResourceState('oxmysql') == 'started' and 'ok' or nil))
    print('^5══════════════════════════════════════════^0')
end

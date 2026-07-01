-- ═══════════════════════════════════════════════════════════════════════
--                    CLIENT BRIDGE - HUD
-- Auto-detects and controls HUD visibility across different HUD resources
-- ═══════════════════════════════════════════════════════════════════════

Bridge = Bridge or {}

local function SafeExport(resource, exportName, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local ok = pcall(exports[resource][exportName], exports[resource], ...)
    return ok
end

function Bridge.HideHUD()
    local hud = Bridge.HUD
    if not hud then return end

    if hud == 'hud_apx' then
        SafeExport('hud_apx', 'HideHUD')
    elseif hud == 'ps-hud' then
        SafeExport('ps-hud', 'HideHUD')
    elseif hud == 'qb-hud' then
        TriggerEvent('qb-hud:client:Toggle', false)
    elseif hud == 'esx_hud' then
        TriggerEvent('esx_hud:onToggle', false)
    elseif hud == 'qs-hud' then
        SafeExport('qs-hud', 'HideHUD')
    elseif hud == 'ox_hud' then
        SafeExport('ox_hud', 'setHudVisible', false)
    end
end

function Bridge.ShowHUD()
    local hud = Bridge.HUD
    if not hud then return end

    if hud == 'hud_apx' then
        SafeExport('hud_apx', 'ShowHUD')
    elseif hud == 'ps-hud' then
        SafeExport('ps-hud', 'ShowHUD')
    elseif hud == 'qb-hud' then
        TriggerEvent('qb-hud:client:Toggle', true)
    elseif hud == 'esx_hud' then
        TriggerEvent('esx_hud:onToggle', true)
    elseif hud == 'qs-hud' then
        SafeExport('qs-hud', 'ShowHUD')
    elseif hud == 'ox_hud' then
        SafeExport('ox_hud', 'setHudVisible', true)
    end
end

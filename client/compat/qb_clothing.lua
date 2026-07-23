-- ═══════════════════════════════════════════════════════════════════════
--          CLIENT COMPATIBILITY SHIM — qb-clothing / rcore_clothes
-- ═══════════════════════════════════════════════════════════════════════
-- Registers the legacy qb-clothing / qb-clothes event names so third-party
-- resources (qb-multicharacter, qb-policejob, qb-prison, qb-apartments,
-- qb-houses, qb-management, qb-smallresources, qb-adminmenu, qb-interior,
-- rcore_clothes consumers, etc.) keep working unmodified.
--
-- Gated by Config.CompatMode.qbClothing — zero cost when disabled.
-- See docs/COMPAT_MODE.md for the full coverage matrix.
-- ═══════════════════════════════════════════════════════════════════════

if not (Config.CompatMode and Config.CompatMode.qbClothing) then return end

-- Warn if a SEPARATE clothing/appearance resource is still running alongside us
-- — two clothing systems (and/or duplicate qb-clothing event handlers) cause
-- unpredictable behavior.
--
-- We intentionally do NOT check 'qb-clothing' here: orb-clothing declares
-- `provides { 'qb-clothing' }`, so GetResourceState('qb-clothing') always
-- reports 'started' (this resource is providing the alias) — checking it would
-- print a false "qb-clothing is also started" even on a clean install. We only
-- check REAL resource folders that we do not provide, so the state is reliable.
CreateThread(function()
    Wait(500) -- let other resources finish starting
    local selfName = GetCurrentResourceName()
    local conflicts = { 'rcore_clothes', 'illenium-appearance', 'fivem-appearance', 'qb-clothes' }
    for _, name in ipairs(conflicts) do
        if name ~= selfName and GetResourceState(name) == 'started' then
            print(('^3[orb-clothing] Compat mode is ON and "%s" is also running — stop it to avoid two clothing systems / duplicate event handlers.^7'):format(name))
        end
    end
end)

-- ── Component mapping ────────────────────────────────────────────────
-- qb-clothing stores outfits as { ['t-shirt'] = { item, texture }, ... }.
-- Those string keys are qb-clothing aliases — they need translation to raw
-- GTA component IDs before we can call SetPedComponentVariation.
-- Double entries cover fork variations (arms/uppr, pants/lowr, etc.).

local UNIFORM_COMPONENTS = {
    ['mask']         = 1,
    ['arms']         = 3,  ['uppr']         = 3,
    ['pants']        = 4,  ['lowr']         = 4,
    ['bag']          = 5,  ['bags']         = 5,  ['parachute'] = 5,
    ['shoes']        = 6,  ['feet']         = 6,
    ['accessory']    = 7,  ['accessories']  = 7,  ['chain']     = 7,
    ['t-shirt']      = 8,  ['tshirt']       = 8,  ['undershirt'] = 8,
    ['vest']         = 9,  ['bproof']       = 9,  ['kevlar']    = 9,
    ['decals']       = 10, ['badges']       = 10,
    ['torso']        = 11, ['torso2']       = 11, ['jbib']      = 11, ['top'] = 11,
}

local UNIFORM_PROPS = {
    ['hat']      = 0, ['helmet'] = 0,
    ['glass']    = 1, ['glasses'] = 1,
    ['ear']      = 2, ['earring'] = 2,
    ['watch']    = 6, ['watches'] = 6,
    ['bracelet'] = 7, ['bracelets'] = 7,
}

local function decodeIfString(data)
    if type(data) == 'string' then
        local ok, decoded = pcall(json.decode, data)
        if ok then return decoded end
    end
    return data
end

-- Detect orb-clothing's own appearance format (selections/sliders/numbers).
-- Legacy qb-clothing skin format looks like { ['t-shirt'] = {...}, ... }.
local function isOrbFormat(data)
    return type(data) == 'table' and (data.selections ~= nil or data.sliders ~= nil or data.numbers ~= nil)
end

-- Apply qb-clothing-style outfit data (component/prop alias map) to a ped.
local function applyLegacyOutfit(ped, outfitData)
    if not DoesEntityExist(ped) or not outfitData then return end

    for key, value in pairs(outfitData) do
        if type(value) == 'table' and value.item ~= nil then
            local comp = UNIFORM_COMPONENTS[key]
            if comp then
                local drawable = (value.item == -1) and 0 or value.item
                SetPedComponentVariation(ped, comp, drawable, value.texture or 0, 0)
            else
                local prop = UNIFORM_PROPS[key]
                if prop ~= nil then
                    if value.item == -1 then
                        ClearPedProp(ped, prop)
                    else
                        SetPedPropIndex(ped, prop, value.item, value.texture or 0, true)
                    end
                end
            end
        end
    end
end

-- Apply orb-clothing appearance to a ped, optionally stripping identity_gender
-- when the target is not the local player (multichar preview case).
local function applyOrbAppearance(ped, data, stripGender)
    if not data or not DoesEntityExist(ped) then return end
    if stripGender and data.selections then
        -- Clone so we don't mutate the caller's table
        local cloned = { selections = {}, sliders = data.sliders, numbers = data.numbers, tattoos = data.tattoos }
        for k, v in pairs(data.selections) do
            if k ~= 'identity_gender' then cloned.selections[k] = v end
        end
        data = cloned
    end
    exports['orb-clothing']:setPedAppearance(ped, data)
end

-- ═══════════════════════════════════════════════════════════════════════
-- CLIENT EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════

-- qb-clothing:client:loadPlayerClothing
-- Triggered by qb-multicharacter to preview a character's appearance on
-- the char-select ped. `data` may be either orb or legacy qb-clothing format.
AddEventHandler('qb-clothing:client:loadPlayerClothing', function(data, ped)
    data = decodeIfString(data)
    ped  = ped or PlayerPedId()
    if not DoesEntityExist(ped) then return end

    if isOrbFormat(data) then
        -- Strip identity_gender: on a non-local preview ped, orb's export
        -- would otherwise call SetPlayerModel on the LOCAL player.
        local isLocal = (ped == PlayerPedId())
        applyOrbAppearance(ped, data, not isLocal)
    elseif type(data) == 'table' then
        -- Legacy qb-clothing raw component format
        applyLegacyOutfit(ped, data)
    else
        SetPedDefaultComponentVariation(ped)
    end
end)

-- qb-clothes:client:CreateFirstCharacter
-- Triggered by qb-multicharacter / qb-interior right after a new character
-- is created. Opens the creator in first-time mode.
AddEventHandler('qb-clothes:client:CreateFirstCharacter', function()
    TriggerEvent('orb-clothing:client:openForNewCharacter', 'male')
end)

-- qb-clothing:client:openMenu
-- Triggered by qb-adminmenu to open the clothing menu on the current player.
AddEventHandler('qb-clothing:client:openMenu', function()
    TriggerEvent('orb-clothing:client:openCreator', nil)
end)

-- qb-clothes:loadSkin
-- Legacy signature: (isNew, model, skinData). Reapplies the local player's look.
AddEventHandler('qb-clothes:loadSkin', function(_, _, skinData)
    skinData = decodeIfString(skinData)
    local ped = PlayerPedId()

    if isOrbFormat(skinData) then
        applyOrbAppearance(ped, skinData, false)
    elseif type(skinData) == 'table' then
        applyLegacyOutfit(ped, skinData)
    else
        -- No payload: fetch from DB
        lib.callback('orb-clothing:server:loadAppearance', false, function(data)
            if data then applyOrbAppearance(PlayerPedId(), data, false) end
        end)
    end
end)

-- qb-clothing:client:loadOutfit
-- Used by qb-policejob / qb-prison / qb-smallresources to force a specific
-- outfit (police tracker, prison uniform, parachute bag). These pass the
-- legacy component alias format; translate and apply directly.
AddEventHandler('qb-clothing:client:loadOutfit', function(outfitData)
    outfitData = decodeIfString(outfitData)
    if not outfitData then return end

    local ped = PlayerPedId()

    -- Shape: { outfitData = { ['t-shirt'] = {...}, ... } }
    if type(outfitData.outfitData) == 'table' then
        applyLegacyOutfit(ped, outfitData.outfitData)
        return
    end

    -- Shape: direct map { ['t-shirt'] = {...}, ... }
    if type(outfitData) == 'table' then
        applyLegacyOutfit(ped, outfitData)
    end
end)

-- qb-clothing:client:openOutfitMenu
-- Called by qb-apartments / qb-houses / qb-management (wardrobe interactions).
-- orb-clothing has no outfit slot system — monolithic appearance only.
-- Notify the player instead so the interaction isn't silently broken.
AddEventHandler('qb-clothing:client:openOutfitMenu', function()
    lib.notify({
        title = L('wardrobe_title'),
        description = L('wardrobe_desc'),
        type = 'inform',
    })
end)

-- qb-clothing:client:reloadOutfits
-- No outfit list to reload in orb-clothing — no-op.
AddEventHandler('qb-clothing:client:reloadOutfits', function() end)

-- qb-clothing:client:adjustfacewear
-- Used by mask/hat items to toggle a specific prop. The per-item logic lives
-- in the item script; no-op here prevents console errors.
AddEventHandler('qb-clothing:client:adjustfacewear', function() end)

if Config.Debug then
    print('^2[orb-clothing] qb-clothing compat mode: client shim loaded^7')
end

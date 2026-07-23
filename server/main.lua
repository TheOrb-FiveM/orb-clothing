-- ═══════════════════════════════════════════════════════════════════════
--                        SERVER MAIN - SAVE APPEARANCE
-- ═══════════════════════════════════════════════════════════════════════

-- ── Routing Buckets ─────────────────────────────────────────────────────
-- Each player gets their own bucket (using their server id) while in a store
-- so other players can't see or interfere with them.
--
-- These are CALLBACKS, not fire-and-forget net events, on purpose. The client
-- must be able to WAIT for the bucket swap to actually take effect before it
-- touches the interior — otherwise the interior pin races the swap and, on slow
-- machines, the interior never re-streams in the new bucket (see the client's
-- OpenCreator for the full explanation).

lib.callback.register('orb-clothing:server:enterBucket', function(source)
    SetPlayerRoutingBucket(source, source)
    return true
end)

lib.callback.register('orb-clothing:server:exitBucket', function(source)
    SetPlayerRoutingBucket(source, 0)
    return true
end)

-- Fire-and-forget reset for cleanup paths (client resource stop) where the
-- client can't block on a round-trip. Safe to call even if already in bucket 0.
RegisterNetEvent('orb-clothing:server:resetBucket', function()
    SetPlayerRoutingBucket(source, 0)
end)

AddEventHandler('playerDropped', function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

-- Resource restart with players still mid-creator: pull everyone back to the
-- default bucket so nobody is stranded alone in a private instance.
AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end
    for _, pid in ipairs(GetPlayers()) do
        SetPlayerRoutingBucket(tonumber(pid), 0)
    end
end)

-- Shallow-merge: copy all keys from `src` into `dst`, overwriting conflicts.
-- Only merges one level deep (each top-level key like selections, sliders, etc.).
local function shallowMerge(dst, src)
    if not src then return dst end
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

-- ── Calculate total cost from changed items ─────────────────────────
local function CalculateTotalCost(changedItems, storeType)
    if not Config.Pricing or not Config.Pricing.enabled then return 0 end
    if not changedItems or #changedItems == 0 then return 0 end

    local prices = Config.Pricing.items or {}
    local multiplier = (Config.Pricing.storeMultiplier and Config.Pricing.storeMultiplier[storeType]) or 1.0
    local total = 0

    for _, itemId in ipairs(changedItems) do
        local basePrice = prices[itemId] or 0
        total = total + basePrice
    end

    return math.floor(total * multiplier)
end

RegisterNetEvent('orb-clothing:server:saveAppearance', function(data)
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then
        lib.print.warn('[orb-clothing] saveAppearance: no identifier for source ' .. tostring(src))
        return
    end

    -- Server-side store validation: proximity + job check
    -- data.storeIndex is provided when opened via a store zone; nil = /tc command (skip check)
    if data.storeIndex then
        if not StoreValidation.CanSave(src, data.storeIndex) then
            lib.print.warn('[orb-clothing] saveAppearance: validation failed for source ' .. tostring(src))
            TriggerClientEvent('orb-clothing:client:creatorSaved', src, false)
            return
        end
    end

    -- ── Pricing: charge the player before saving ──
    local changedItems = data.changedItems or {}
    local storeType = nil
    if data.storeIndex then
        local storeData = Config.StoreLocations and Config.StoreLocations[data.storeIndex]
        storeType = storeData and storeData.type or nil
    end

    local totalCost = CalculateTotalCost(changedItems, storeType)
    if totalCost > 0 then
        local paid = Bridge.RemoveMoney(src, totalCost, 'orb-clothing store purchase')
        if not paid then
            TriggerClientEvent('orb-clothing:client:creatorSaved', src, false, 'no_money')
            return
        end
        if Config.Debug then
            print(('[orb-clothing] Charged $%d to source %d (%d items)'):format(totalCost, src, #changedItems))
        end
    end

    -- Payload is { appearance={...}, storeIndex=n } when from store, or raw state when from /tc
    local incoming = data.appearance or data

    -- ── Merge with existing saved data so partial saves don't wipe fields ──
    local existing = {}
    local existingJson = MySQL.scalar.await(
        'SELECT appearance FROM character_appearance WHERE identifier = ?',
        { identifier }
    )
    if existingJson then
        existing = json.decode(existingJson) or {}
    end

    -- Deep-merge each sub-table: incoming keys overwrite, existing keys are kept
    local merged = {
        selections = shallowMerge(existing.selections or {}, incoming.selections),
        sliders    = shallowMerge(existing.sliders    or {}, incoming.sliders),
        numbers    = shallowMerge(existing.numbers    or {}, incoming.numbers),
        tattoos    = incoming.tattoos or existing.tattoos or {},
        -- Per-item clothing/prop snapshot with real textures (full replace, not a
        -- merge — it's the complete current look). Lets textures survive a relog
        -- and keeps outfit-applied looks persisted between normal saves.
        clothing   = incoming.clothing or existing.clothing or nil,
        props      = incoming.props    or existing.props    or nil,
    }

    local mergedJson = json.encode(merged)

    -- Derive ped model from gender selection (0 = male, 1 = female)
    local genderIndex = merged.selections and merged.selections['identity_gender']
    local model = (genderIndex == 1) and 'mp_f_freemode_01' or 'mp_m_freemode_01'

    local rowsChanged = MySQL.update.await(
        'INSERT INTO character_appearance (identifier, appearance) VALUES (?, ?) ON DUPLICATE KEY UPDATE appearance = VALUES(appearance), updated_at = CURRENT_TIMESTAMP',
        { identifier, mergedJson }
    )

    if rowsChanged and rowsChanged > 0 then
        -- Mirror into framework skin table so character-select preview keeps working
        Bridge.MirrorSkin(identifier, model, mergedJson)

        -- Broadcast ped scale to other players via state bag
        local heightSlider = merged.sliders and merged.sliders['bodyHeight']
        local scale = heightSlider and (0.85 + (heightSlider / 100.0 * 0.30)) or 1.0
        local player = Player(src)
        if player then
            player.state:set('orb-clothing:scale', scale, true)
        end

        TriggerClientEvent('orb-clothing:client:creatorSaved', src, true)
    else
        lib.print.warn('[orb-clothing] saveAppearance: upsert returned 0 rows for ' .. identifier)
        TriggerClientEvent('orb-clothing:client:creatorSaved', src, false)
    end
end)

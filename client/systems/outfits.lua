-- ═══════════════════════════════════════════════════════════════════════
--                          OUTFIT SYSTEM
-- ═══════════════════════════════════════════════════════════════════════
-- An outfit is a snapshot of clothing components + props (with textures).
-- It deliberately ignores hair (component 2), face, heritage and body so
-- applying an outfit only swaps the player's clothes, not their identity.

OutfitSystem = {}

-- Clothing components that make up an outfit (NO hair=2, NO head=0).
local CLOTHING_COMPONENTS = { 1, 3, 4, 5, 6, 8, 11 }
-- Props: hats=0, glasses=1, ears=2, watches=6, bracelets=7.
local PROP_IDS = { 0, 1, 2, 6, 7 }

-- Read the current ped into an outfit snapshot. Textures come straight from
-- the ped natives (the NUI state only tracks the active item's texture).
function OutfitSystem.BuildSnapshot(ped)
    ped = ped or PlayerPedId()
    local snap = { components = {}, props = {} }

    for _, cid in ipairs(CLOTHING_COMPONENTS) do
        snap.components[tostring(cid)] = {
            d = GetPedDrawableVariation(ped, cid),
            t = GetPedTextureVariation(ped, cid),
        }
    end
    for _, pid in ipairs(PROP_IDS) do
        snap.props[tostring(pid)] = {
            d = GetPedPropIndex(ped, pid),
            t = GetPedPropTextureIndex(ped, pid),
        }
    end

    snap.gender = (Config.IsMale and Config.IsMale(ped)) and 'male' or 'female'
    return snap
end

-- Apply an outfit onto a ped. UpdateClothing/UpdateProp clamp ranges and keep
-- DataCache in sync. Top (11) is applied FIRST because changing the top resets
-- the undershirt (8) to the gender default — see ClothingSystem.UpdateClothing.
function OutfitSystem.Apply(ped, outfit)
    ped = ped or PlayerPedId()
    if not outfit then return end

    local comps = outfit.components or {}
    local top = comps['11'] or comps[11]
    if top then
        ClothingSystem.UpdateClothing(ped, 11, top.d, top.t or 0)
    end
    for k, item in pairs(comps) do
        local cid = tonumber(k)
        if cid and cid ~= 11 then
            ClothingSystem.UpdateClothing(ped, cid, item.d, item.t or 0)
        end
    end
    for k, item in pairs(outfit.props or {}) do
        local pid = tonumber(k)
        if pid then
            ClothingSystem.UpdateProp(ped, pid, item.d, item.t or 0)
        end
    end
end

-- True when the outfit was built on a different gender ped than the current one
-- (drawables won't map 1:1, so the look may differ — caller warns the player).
function OutfitSystem.GenderMismatch(ped, outfit)
    ped = ped or PlayerPedId()
    if not outfit or not outfit.gender then return false end
    local current = (Config.IsMale and Config.IsMale(ped)) and 'male' or 'female'
    return current ~= outfit.gender
end

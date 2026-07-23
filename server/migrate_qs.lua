-- ═══════════════════════════════════════════════════════════════════════
--         CLOTHING MIGRATION → orb-clothing  (qs-appearance + qb-clothing)
--
-- For servers switching TO orb-clothing from another clothing resource. Reads the
-- other script's tables and rewrites the data into orb's own schema so players
-- keep their face, body, clothing and saved outfits. The source rows are only
-- ever READ — nothing is deleted or edited in the other script's tables.
--
--   /migrateclothing                  → DRY RUN. Reports what it WOULD do.
--   /migrateclothing confirm          → migrate. Skips citizenids that already
--                                       have an orb look (safe to re-run).
--   /migrateclothing confirm overwrite→ also overwrite existing orb looks.
--   (/migrateqs and /migrateqb are aliases of the same command.)
--
-- Automatic import on resource start is opt-in via Config.AutoImport.
--
-- Both qs-appearance and qb-clothing store the active look in the SAME table,
-- `playerskins.skin`, but in DIFFERENT JSON shapes:
--   qs  → fivem-appearance ({ headBlend, faceFeatures, headOverlays, components[],
--         props[], hair, tattoos }).
--   qb  → flat named keys ({ face, face2, facemix, nose_0.., beard, t-shirt,
--         hat, hair, eye_color, ... }); each value is { item, texture }.
-- orb stores its OWN indirect format in `character_appearance.appearance`
-- ({ selections, sliders, numbers, clothing, props, tattoos }) which the client
-- turns back into natives via Config.*Mapping. The pure mappers below do that
-- translation and are free of DB/native calls so they can be tested off-server.
-- ═══════════════════════════════════════════════════════════════════════

QsMigrate = {}

-- ── Mapping tables (INVERSE of Config.UIMapping / SliderMapping / NumberMapping) ──
-- Kept local + explicit rather than derived from Config so a future config edit
-- can't silently change what a migration produces.

-- GTA face-feature index (0-19) → the orb SLIDER id that drives it.
local FEATURE_TO_SLIDER = {
    [0]  = 'noseWidth',      [1]  = 'noseHeight',   [2]  = 'noseBridge',
    [4]  = 'noseTip',        [5]  = 'noseTwist',    [6]  = 'eyebrowHeight',
    [7]  = 'eyebrowDepth',   [8]  = 'cheekboneHeight', [9] = 'cheekboneWidth',
    [10] = 'cheeksWidth',    [11] = 'eyeOpening',   [12] = 'chestSize',
    [13] = 'waistSize',      [14] = 'hipSize',      [15] = 'armSize',
    [16] = 'chinDepth',      [17] = 'chinWidth',    [18] = 'chinHoleSize',
    [19] = 'bodyWeight',
}
-- Feature index 3 is driven by a NUMBER control in orb (labelled "age").
local FEATURE_TO_NUMBER = { [3] = 'age' }

-- fivem-appearance faceFeatures object keys → GTA index (also accepts a plain
-- 0..19 array).
local FF_NAME_TO_INDEX = {
    noseWidth = 0, nosePeakHigh = 1, nosePeakSize = 2, noseBoneHigh = 3,
    nosePeakLowering = 4, noseBoneTwist = 5, eyeBrowHigh = 6, eyeBrowForward = 7,
    cheeksBoneHigh = 8, cheeksBoneWidth = 9, cheeksWidth = 10, eyesOpening = 11,
    lipsThickness = 12, jawBoneWidth = 13, jawBoneBackSize = 14,
    chinBoneLowering = 15, chinBoneLength = 16, chinBoneSize = 17,
    chinBoneHole = 18, chinHole = 18, neckThickness = 19,
}

-- fivem-appearance headOverlays keys → { overlay id, and the orb targets }.
-- Only the overlays orb actually applies are listed; the rest are dropped (orb
-- has no UI or applier for them, so carrying them would be a dead promise).
--   sel = selection id for the style/variation
--   op  = slider id for opacity      (nil if orb has no opacity control for it)
--   col = number id for the colour   (nil if none)
local OVERLAY_MAP = {
    beard    = { sel = 'hair_beard',       op = 'beardOpacity',    col = 'beardColor' },
    eyebrows = { sel = 'features_eyebrows', op = nil,              col = 'eyebrowColor' },
    blush    = { sel = 'makeup_blush',     op = 'blushOpacity',    col = 'blushColor' },
    lipstick = { sel = 'makeup_lipstick',  op = 'lipstickOpacity', col = 'lipstickColor' },
}

-- Components orb treats as clothing (0 face + 2 hair are handled elsewhere and
-- excluded). Props orb tracks.
local CLOTHING_COMPONENTS = { [1]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true,[8]=true,[9]=true,[10]=true,[11]=true }

-- ── Small helpers ─────────────────────────────────────────────────────────

local function num(v, default)
    v = tonumber(v)
    if v == nil then return default end
    return v
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Face-feature value in qs is -1.0..1.0. Both orb slider and number controls
-- decode as ((raw/50) - 1) / ((raw/100*2) - 1) respectively, and both invert to
-- the SAME formula: raw = (feature + 1) * 50, clamped to the 0..100 UI range.
local function featureToRaw(featureVal)
    return clamp((num(featureVal, 0) + 1.0) * 50.0, 0, 100)
end

-- Read a value out of a fivem-appearance sub-object that may be either a named
-- object ({ noseWidth = .. }) or a positional array ({ [1] = .. } 0-indexed logic).
local function readFeature(faceFeatures, gtaIndex, name)
    if type(faceFeatures) ~= 'table' then return nil end
    if faceFeatures[name] ~= nil then return faceFeatures[name] end          -- named
    if faceFeatures[gtaIndex] ~= nil then return faceFeatures[gtaIndex] end   -- 0-based numeric
    if faceFeatures[gtaIndex + 1] ~= nil then return faceFeatures[gtaIndex + 1] end -- 1-based array
    return nil
end

-- Gender from a model name or joaat hash. Defaults to male.
local FEMALE_HASH = 2627665880  -- joaat('mp_f_freemode_01')
local function isFemaleModel(model)
    if type(model) == 'string' then
        local m = model:lower()
        if m:find('mp_f_') or m:find('f_freemode') then return true end
        if m == tostring(FEMALE_HASH) then return true end
        return false
    end
    if type(model) == 'number' then
        return model == FEMALE_HASH
    end
    return false
end

-- ── The character-appearance mapper (pure) ────────────────────────────────
-- `skin` = the decoded fivem-appearance object from playerskins.skin.
-- Returns an orb appearance table ready to json.encode into character_appearance.
function QsMigrate.MapSkin(skin)
    if type(skin) ~= 'table' then return nil, 'skin is not a table' end

    local selections, sliders, numbers = {}, {}, {}
    local clothing, props, tattoos = {}, {}, {}

    -- Gender / model
    local female = isFemaleModel(skin.model)
    selections['identity_gender'] = female and 1 or 0

    -- Heritage (headBlend). orb uses one parent index for both shape & skin.
    local hb = skin.headBlend
    if type(hb) == 'table' then
        selections['heritage_mother'] = math.floor(num(hb.shapeFirst or hb.skinFirst, 0))
        selections['heritage_father'] = math.floor(num(hb.shapeSecond or hb.skinSecond, 0))
        sliders['resemblance'] = clamp(num(hb.shapeMix, 0.5) * 100.0, 0, 100)
        sliders['skinTone']    = clamp(num(hb.skinMix,  0.5) * 100.0, 0, 100)
    end

    -- Face features → sliders (+ the one "age" number)
    local ff = skin.faceFeatures
    if type(ff) == 'table' then
        for gtaIndex, sliderId in pairs(FEATURE_TO_SLIDER) do
            local name
            for k, v in pairs(FF_NAME_TO_INDEX) do if v == gtaIndex then name = k break end end
            local val = readFeature(ff, gtaIndex, name)
            if val ~= nil then sliders[sliderId] = featureToRaw(val) end
        end
        for gtaIndex, numberId in pairs(FEATURE_TO_NUMBER) do
            local name
            for k, v in pairs(FF_NAME_TO_INDEX) do if v == gtaIndex then name = k break end end
            local val = readFeature(ff, gtaIndex, name)
            if val ~= nil then numbers[numberId] = featureToRaw(val) end
        end
    end

    -- Head overlays (only the ones orb can apply)
    local ov = skin.headOverlays
    if type(ov) == 'table' then
        for key, target in pairs(OVERLAY_MAP) do
            local o = ov[key]
            if type(o) == 'table' then
                local style = math.floor(num(o.style, 0))
                if style == 255 then style = 0 end   -- 255 = none → orb variation 0
                selections[target.sel] = style
                if target.op  then sliders[target.op]  = clamp(num(o.opacity, 1.0) * 100.0, 0, 100) end
                if target.col then numbers[target.col] = math.floor(num(o.color, 0)) end
            end
        end
    end

    -- Hair
    local hair = skin.hair
    if type(hair) == 'table' then
        selections['hair_hairstyle'] = math.floor(num(hair.style, 0))
        numbers['hairColor']     = math.floor(num(hair.color, 0))
        numbers['hairHighlight'] = math.floor(num(hair.highlight, 0))
    end

    -- Eyes
    if skin.eyeColor ~= nil then
        selections['features_eyes'] = math.floor(num(skin.eyeColor, 0))
    end

    -- Components → clothing snapshot (drawable + REAL texture). Accepts both the
    -- array form [{component_id,drawable,texture}] and the object form {["11"]={...}}.
    local comps = skin.components
    if type(comps) == 'table' then
        for k, c in pairs(comps) do
            if type(c) == 'table' then
                local id = num(c.component_id, num(k, nil))
                if id ~= nil then
                    id = math.floor(id)
                    if CLOTHING_COMPONENTS[id] then
                        clothing[tostring(id)] = {
                            d = math.floor(num(c.drawable, 0)),
                            t = math.floor(num(c.texture, 0)),
                        }
                    end
                end
            end
        end
    end

    -- Props → props snapshot
    local pr = skin.props
    if type(pr) == 'table' then
        for k, p in pairs(pr) do
            if type(p) == 'table' then
                local id = num(p.prop_id, num(k, nil))
                if id ~= nil then
                    props[tostring(math.floor(id))] = {
                        d = math.floor(num(p.drawable, -1)),
                        t = math.floor(num(p.texture, 0)),
                    }
                end
            end
        end
    end

    -- Tattoos → { collection, hash }. Best-effort across the common shapes.
    if type(skin.tattoos) == 'table' then
        for _, t in pairs(skin.tattoos) do
            if type(t) == 'table' then
                local collection = t.collection or t.dlc
                local hash = t.hash
                if not hash then
                    hash = female and (t.hashFemale or t.hashMale) or (t.hashMale or t.hashFemale)
                end
                if collection and hash then
                    tattoos[#tattoos + 1] = { collection = collection, hash = hash }
                end
            end
        end
    end

    return {
        selections = selections,
        sliders    = sliders,
        numbers    = numbers,
        clothing   = clothing,
        props      = props,
        tattoos    = tattoos,
    }
end

-- ── The outfit mapper (pure) ──────────────────────────────────────────────
-- qs stores outfit `components`/`props` as fivem-appearance arrays (or objects).
-- orb stores an outfit as { components = {["id"]={d,t}}, props = {["id"]={d,t}} }
-- limited to the clothing/prop allowlist. Returns that shape.
function QsMigrate.MapOutfit(components, props)
    local outComps, outProps = {}, {}

    if type(components) == 'table' then
        for k, c in pairs(components) do
            if type(c) == 'table' then
                local id = num(c.component_id, num(k, nil))
                if id ~= nil then
                    id = math.floor(id)
                    if CLOTHING_COMPONENTS[id] then
                        outComps[tostring(id)] = {
                            d = math.floor(num(c.drawable, 0)),
                            t = math.floor(num(c.texture, 0)),
                        }
                    end
                end
            end
        end
    end

    if type(props) == 'table' then
        for k, p in pairs(props) do
            if type(p) == 'table' then
                local id = num(p.prop_id, num(k, nil))
                if id ~= nil then
                    outProps[tostring(math.floor(id))] = {
                        d = math.floor(num(p.drawable, -1)),
                        t = math.floor(num(p.texture, 0)),
                    }
                end
            end
        end
    end

    return { components = outComps, props = outProps }
end

-- ═══════════════════════════════════════════════════════════════════════
--                       qb-clothing MAPPERS (pure)
-- ═══════════════════════════════════════════════════════════════════════
-- qb-clothing's skin is a FLAT dict of named keys, each { item, texture }.
-- Confirmed against qb-clothing/client.lua (the SetPed* calls).

-- Named face-feature key → GTA index. qb applies `item / 10`, so the real
-- feature value is item/10 in the -1..1 range (item is roughly -10..10).
local QB_FEATURE_KEYS = {
    nose_0 = 0, nose_1 = 1, nose_2 = 2, nose_3 = 3, nose_4 = 4, nose_5 = 5,
    eyebrown_high = 6, eyebrown_forward = 7,
    cheek_1 = 8, cheek_2 = 9, cheek_3 = 10,
    eye_opening = 11, lips_thickness = 12,
    jaw_bone_width = 13, jaw_bone_back_lenght = 14,
    chimp_bone_lowering = 15, chimp_bone_lenght = 16, chimp_bone_width = 17,
    chimp_hole = 18, neck_thikness = 19,
}

-- qb overlay key → { orb selection, orb opacity slider (or nil), orb colour number }.
-- qb stores { item = style, texture = colour } and always applies opacity 1.0.
local QB_OVERLAY_MAP = {
    beard    = { sel = 'hair_beard',        op = 'beardOpacity',    col = 'beardColor' },
    eyebrows = { sel = 'features_eyebrows',  op = nil,               col = 'eyebrowColor' },
    blush    = { sel = 'makeup_blush',       op = 'blushOpacity',    col = 'blushColor' },
    lipstick = { sel = 'makeup_lipstick',    op = 'lipstickOpacity', col = 'lipstickColor' },
}

-- qb clothing key → component id (hair=2 is handled via the hair block, not here).
local QB_COMPONENTS = {
    mask = 1, arms = 3, pants = 4, bag = 5, shoes = 6, accessory = 7,
    ['t-shirt'] = 8, vest = 9, decals = 10, torso2 = 11,
}

-- qb prop key → prop id.
local QB_PROPS = { hat = 0, glass = 1, ear = 2, watch = 6, bracelet = 7 }

-- Read a qb sub-table's numeric field ({ item = .. } / { texture = .. }).
local function qbField(entry, field, default)
    if type(entry) ~= 'table' then return default end
    return num(entry[field], default)
end

-- Map a whole qb-clothing skin → orb appearance. Same output shape as MapSkin.
function QsMigrate.MapQbSkin(skin)
    if type(skin) ~= 'table' then return nil, 'skin is not a table' end

    local selections, sliders, numbers = {}, {}, {}
    local clothing, props = {}, {}

    -- Gender
    selections['identity_gender'] = isFemaleModel(skin.model) and 1 or 0

    -- Heritage: face.item = parent1, face2.item = parent2; facemix 0..1.
    if type(skin.face) == 'table' or type(skin.facemix) == 'table' then
        selections['heritage_mother'] = math.floor(qbField(skin.face,  'item', 0))
        selections['heritage_father'] = math.floor(qbField(skin.face2, 'item', 0))
        sliders['resemblance'] = clamp(qbField(skin.facemix, 'shapeMix', 0.5) * 100.0, 0, 100)
        sliders['skinTone']    = clamp(qbField(skin.facemix, 'skinMix',  0.5) * 100.0, 0, 100)
    end

    -- Face features: value = item/10, then to orb slider/number via the shared maps.
    for key, gtaIndex in pairs(QB_FEATURE_KEYS) do
        local entry = skin[key]
        if type(entry) == 'table' and entry.item ~= nil then
            local raw = featureToRaw(num(entry.item, 0) / 10.0)
            local sliderId = FEATURE_TO_SLIDER[gtaIndex]
            local numberId = FEATURE_TO_NUMBER[gtaIndex]
            if sliderId then sliders[sliderId] = raw
            elseif numberId then numbers[numberId] = raw end
        end
    end

    -- Overlays (opacity always 1.0 in qb → full slider)
    for key, target in pairs(QB_OVERLAY_MAP) do
        local entry = skin[key]
        if type(entry) == 'table' then
            selections[target.sel] = math.floor(qbField(entry, 'item', 0))
            if target.op  then sliders[target.op]  = 100 end
            if target.col then numbers[target.col] = math.floor(qbField(entry, 'texture', 0)) end
        end
    end

    -- Hair: item = style, texture = colour (qb has no highlight → mirror the colour).
    if type(skin.hair) == 'table' then
        selections['hair_hairstyle'] = math.floor(qbField(skin.hair, 'item', 0))
        local hc = math.floor(qbField(skin.hair, 'texture', 0))
        numbers['hairColor']     = hc
        numbers['hairHighlight'] = hc
    end

    -- Eyes
    if type(skin.eye_color) == 'table' then
        selections['features_eyes'] = math.floor(qbField(skin.eye_color, 'item', 0))
    end

    -- Clothing components
    for key, id in pairs(QB_COMPONENTS) do
        local entry = skin[key]
        if type(entry) == 'table' then
            clothing[tostring(id)] = {
                d = math.floor(qbField(entry, 'item', 0)),
                t = math.floor(qbField(entry, 'texture', 0)),
            }
        end
    end

    -- Props
    for key, id in pairs(QB_PROPS) do
        local entry = skin[key]
        if type(entry) == 'table' then
            props[tostring(id)] = {
                d = math.floor(qbField(entry, 'item', -1)),
                t = math.floor(qbField(entry, 'texture', 0)),
            }
        end
    end

    return {
        selections = selections,
        sliders    = sliders,
        numbers    = numbers,
        clothing   = clothing,
        props      = props,
        tattoos    = {},   -- qb-clothing does not store tattoos
    }
end

-- A qb outfit is stored as a full qb skin; an orb outfit is clothing + props only.
function QsMigrate.MapQbOutfit(skin)
    local outComps, outProps = {}, {}
    if type(skin) == 'table' then
        for key, id in pairs(QB_COMPONENTS) do
            local entry = skin[key]
            if type(entry) == 'table' then
                outComps[tostring(id)] = {
                    d = math.floor(qbField(entry, 'item', 0)),
                    t = math.floor(qbField(entry, 'texture', 0)),
                }
            end
        end
        for key, id in pairs(QB_PROPS) do
            local entry = skin[key]
            if type(entry) == 'table' then
                outProps[tostring(id)] = {
                    d = math.floor(qbField(entry, 'item', -1)),
                    t = math.floor(qbField(entry, 'texture', 0)),
                }
            end
        end
    end
    return { components = outComps, props = outProps }
end

-- ═══════════════════════════════════════════════════════════════════════
--                       COMMAND + DATABASE I/O
-- ═══════════════════════════════════════════════════════════════════════

-- Classify a playerskins row's format. orb writes its OWN format into playerskins
-- (via Bridge.MirrorSkin), so a row with `selections` is already ours → skip. qb
-- uses flat named keys (facemix / nose_0 / torso2 / t-shirt); qs uses
-- fivem-appearance (headBlend / faceFeatures / components[]).
local function detectFormat(skin)
    if type(skin) ~= 'table' then return nil end
    if skin.selections ~= nil then return 'orb' end
    if skin.facemix ~= nil or skin['nose_0'] ~= nil or skin['torso2'] ~= nil
        or skin['t-shirt'] ~= nil then return 'qb' end
    if skin.headBlend ~= nil or skin.components ~= nil or skin.faceFeatures ~= nil then return 'qs' end
    return nil
end

local function mapByFormat(skin, fmt)
    if fmt == 'qs' then return QsMigrate.MapSkin(skin) end
    if fmt == 'qb' then return QsMigrate.MapQbSkin(skin) end
    return nil
end

QsMigrate._detectFormat = detectFormat  -- exposed for tests

local function tableExists(name)
    local ok, res = pcall(function()
        return MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
            { name })
    end)
    return ok and (res or 0) > 0
end

local function columnExists(tbl, col)
    local ok, res = pcall(function()
        return MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?',
            { tbl, col })
    end)
    return ok and (res or 0) > 0
end

local function decode(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, v = pcall(json.decode, raw)
    if ok and type(v) == 'table' then return v end
    return nil
end

-- Report sink: server console always; a short summary notify to the admin ped.
local function report(src, lines, summary)
    for _, line in ipairs(lines) do print('^3[orb-migrate]^0 ' .. line) end
    if src and src ~= 0 and summary then
        TriggerClientEvent('orb-clothing:client:adminNotify', src, {
            title = L('qs_migrate_title'), description = summary, type = 'inform', duration = 12000,
        })
    end
end

-- ── Appearance migration ──────────────────────────────────────────────────
-- accept: 'qs' | 'qb' | 'auto' (any recognised source). overwrite replaces looks
-- players already have in orb.
--
-- We do NOT join playerskins to character_appearance in SQL: the two tables can
-- carry different collations (e.g. MariaDB's utf8mb4_uca1400_ai_ci vs a script's
-- utf8mb4_general_ci) and a column=column JOIN then throws "Illegal mix of
-- collations". Instead we scan playerskins and test existence per row with a
-- BOUND parameter (column = ?), which compares against the column's own
-- collation and never clashes. It stays cheap on re-runs anyway: once a player is
-- migrated, MirrorSkin makes their active playerskins row orb-format, so
-- detectFormat filters them out BEFORE any existence check runs.
local function migrateAppearances(dryRun, overwrite, accept)
    accept = accept or 'auto'
    local rows = MySQL.query.await('SELECT citizenid, model, skin FROM playerskins WHERE active = 1') or {}

    local seen = {}
    local stat = { total = 0, found = 0, migrated = 0, failed = 0 }

    for _, row in ipairs(rows) do
        stat.total = stat.total + 1
        local cid = row.citizenid
        if cid and not seen[cid] then
            local skin = decode(row.skin)
            local fmt  = detectFormat(skin)
            local want = (accept == 'auto' and (fmt == 'qs' or fmt == 'qb')) or (fmt == accept)
            if want then
                seen[cid] = true

                -- Bound-param existence check — no column-vs-column collation clash.
                local exists = MySQL.scalar.await(
                    'SELECT 1 FROM character_appearance WHERE identifier = ?', { cid })

                if exists and not overwrite then
                    -- already has an orb look → leave it
                else
                    stat.found = stat.found + 1
                    if not dryRun then
                        local ok, mapped = pcall(mapByFormat, skin, fmt)
                        if ok and mapped then
                            local wok = pcall(function()
                                MySQL.update.await(
                                    'INSERT INTO character_appearance (identifier, appearance) VALUES (?, ?) ' ..
                                    'ON DUPLICATE KEY UPDATE appearance = VALUES(appearance), updated_at = CURRENT_TIMESTAMP',
                                    { cid, json.encode(mapped) })
                                -- Mirror orb's format into playerskins so the char-select
                                -- preview matches. This deactivates the old source row
                                -- (active=0) but never deletes it.
                                local model = (mapped.selections['identity_gender'] == 1)
                                    and 'mp_f_freemode_01' or 'mp_m_freemode_01'
                                if Bridge.MirrorSkin then Bridge.MirrorSkin(cid, model, json.encode(mapped)) end
                            end)
                            if wok then stat.migrated = stat.migrated + 1 else stat.failed = stat.failed + 1 end
                        else
                            stat.failed = stat.failed + 1
                        end
                    else
                        stat.migrated = stat.migrated + 1   -- dry-run: would migrate
                    end
                end
            end
        end
    end

    return stat
end

-- ── Outfit migration ──────────────────────────────────────────────────────
-- Handles all three source shapes:
--   clothing_player_outfits (qs native)  → owner/label + components/props columns
--   player_outfits with `skin` column    → qb-clothing (full skin JSON per outfit)
--   player_outfits with `components` col  → qs-style components/props
-- Duplicates (same identifier + name) are skipped, so re-runs are safe.
local function outfitAlreadyThere(identifier, name)
    return (MySQL.scalar.await(
        'SELECT 1 FROM orb_clothing_outfits WHERE identifier = ? AND name = ?',
        { identifier, name })) ~= nil
end

local function insertOutfit(ident, name, data, dryRun, acc)
    if not ident or not name or name == '' then return end
    acc.found = acc.found + 1
    if outfitAlreadyThere(ident, name) then acc.dupes = acc.dupes + 1; return end
    if dryRun then acc.migrated = acc.migrated + 1; return end
    local ok = pcall(function()
        MySQL.update.await(
            'INSERT INTO orb_clothing_outfits (identifier, name, data) VALUES (?, ?, ?) ' ..
            'ON DUPLICATE KEY UPDATE data = VALUES(data)',
            { ident, name:sub(1, 30), json.encode(data) })
    end)
    if ok then acc.migrated = acc.migrated + 1 else acc.failed = acc.failed + 1 end
end

-- Rows with components/props columns (qs-style).
local function migrateComponentsOutfits(tbl, idCol, nameCol, dryRun, acc)
    local rows = MySQL.query.await(('SELECT %s AS ident, %s AS oname, components, props FROM %s')
        :format(idCol, nameCol, tbl)) or {}
    for _, row in ipairs(rows) do
        insertOutfit(row.ident, row.oname, QsMigrate.MapOutfit(decode(row.components), decode(row.props)), dryRun, acc)
    end
end

-- Rows with a `skin` column holding a full qb-clothing skin.
local function migrateQbOutfits(tbl, idCol, nameCol, dryRun, acc)
    local rows = MySQL.query.await(('SELECT %s AS ident, %s AS oname, skin FROM %s')
        :format(idCol, nameCol, tbl)) or {}
    for _, row in ipairs(rows) do
        insertOutfit(row.ident, row.oname, QsMigrate.MapQbOutfit(decode(row.skin)), dryRun, acc)
    end
end

local function migrateOutfits(dryRun, accept)
    accept = accept or 'auto'
    local acc = { found = 0, dupes = 0, migrated = 0, failed = 0 }

    if (accept == 'auto' or accept == 'qs') and tableExists('clothing_player_outfits') then
        migrateComponentsOutfits('clothing_player_outfits', 'owner', 'label', dryRun, acc)
    end

    if tableExists('player_outfits') then
        if columnExists('player_outfits', 'skin') and (accept == 'auto' or accept == 'qb') then
            migrateQbOutfits('player_outfits', 'citizenid', 'outfitname', dryRun, acc)
        elseif columnExists('player_outfits', 'components') and (accept == 'auto' or accept == 'qs') then
            migrateComponentsOutfits('player_outfits', 'citizenid', 'outfitname', dryRun, acc)
        end
    end

    return acc
end

-- ── Command ───────────────────────────────────────────────────────────────
-- /migrateclothing → auto (qs + qb). /migrateqs and /migrateqb pin the source.
local function runMigration(src, args, accept)
    if src ~= 0 and not (AdminStorage and AdminStorage.IsAdmin(src)) then
        TriggerClientEvent('orb-clothing:client:adminNotify', src, {
            title = L('qs_migrate_title'), description = L('qs_migrate_no_perm'), type = 'error',
        })
        return
    end

    local mode      = (args[1] or ''):lower()
    local dryRun    = mode ~= 'confirm'
    local overwrite = (args[2] or ''):lower() == 'overwrite'

    CreateThread(function()
        if not tableExists('playerskins') then
            report(src, { L('qs_migrate_no_table') }, L('qs_migrate_no_table'))
            return
        end

        local a = migrateAppearances(dryRun, overwrite, accept)
        local o = migrateOutfits(dryRun, accept)

        local head = dryRun and '── DRY RUN (nothing written) ──' or '── MIGRATION COMPLETE ──'
        report(src, {
            head,
            ('source                   : %s'):format(accept),
            ('playerskins rows scanned : %d'):format(a.total),
            ('  recognised & new       : %d'):format(a.found),
            ('  appearances %s : %d'):format(dryRun and 'to migrate' or 'migrated  ', a.migrated),
            ('  appearances failed     : %d'):format(a.failed),
            ('outfits found            : %d'):format(o.found),
            ('  duplicates skipped     : %d'):format(o.dupes),
            ('  outfits %s     : %d'):format(dryRun and 'to migrate' or 'migrated  ', o.migrated),
            ('  outfits failed         : %d'):format(o.failed),
            dryRun and 'Run the same command with ^2confirm^0 to apply (add ^2overwrite^0 to replace existing orb looks).' or 'Done.',
        }, dryRun
            and L('qs_migrate_dry', a.migrated, o.migrated)
            or  L('qs_migrate_done', a.migrated, a.failed, o.migrated))
    end)
end

RegisterCommand('migrateclothing', function(source, args) runMigration(source, args, 'auto') end, false)
RegisterCommand('migrateqs',       function(source, args) runMigration(source, args, 'qs')   end, false)
RegisterCommand('migrateqb',       function(source, args) runMigration(source, args, 'qb')   end, false)

-- ── Automatic import on resource start (opt-in) ────────────────────────────
-- Config.AutoImport = 'off' | 'qb' | 'qs' | 'auto'. Runs ONCE per player:
-- migrateAppearances skips anyone who already has an orb look, and migrated
-- players become orb-format in playerskins (so they're filtered out on the next
-- boot), so leaving this on is harmless — after everyone is migrated it does
-- nothing. Source tables are only read; nothing there is deleted.
CreateThread(function()
    local mode = (Config.AutoImport or 'off'):lower()
    if mode == 'off' then return end

    -- Wait for orb's own tables and any DB to be ready.
    local waited = 0
    while not (tableExists('character_appearance') and tableExists('playerskins')) and waited < 60000 do
        Wait(1000); waited = waited + 1000
    end
    if not (tableExists('character_appearance') and tableExists('playerskins')) then return end

    local accept = (mode == 'qb' or mode == 'qs') and mode or 'auto'
    local a = migrateAppearances(false, false, accept)
    local o = migrateOutfits(false, accept)
    if a.migrated > 0 or o.migrated > 0 or a.failed > 0 then
        print(('^2[orb-clothing]^0 Auto-import (%s): imported ^2%d^0 appearance(s) and ^2%d^0 outfit(s) from another clothing script (^1%d^0 failed).')
            :format(mode, a.migrated, o.migrated, a.failed))
    end
end)


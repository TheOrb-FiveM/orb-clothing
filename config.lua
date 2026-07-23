-- ═══════════════════════════════════════════════════════════════════════
--                      ORB-CLOTHING - CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════

Config = {}

-- ═══════════════════════════════════════════════════════════════════════
--                              CORE SETTINGS
-- ═══════════════════════════════════════════════════════════════════════

Config.Debug = false

-- UI / notification language. Must match a file in locales/ (en, es).
-- Falls back to English for any missing key.
Config.Language = 'en'

-- ═══════════════════════════════════════════════════════════════════════
--                        COMPATIBILITY MODE
-- ═══════════════════════════════════════════════════════════════════════
-- Drop-in replacement flags for legacy clothing resources.
-- When a compat flag is enabled, orb-clothing registers the legacy events
-- that other resources (qb-multicharacter, qb-policejob, qb-prison,
-- qb-apartments, qb-houses, qb-management, qb-smallresources, qb-adminmenu,
-- qb-interior) trigger — so you do NOT have to patch their files.
--
-- ENABLE when replacing the matching legacy script:
--   qbClothing   → replaces qb-clothing (and rcore_clothes, which provides it)
--   skinchanger  → replaces ESX skinchanger              [v2 — not yet implemented]
--   esxSkin      → replaces esx_skin                      [v2 — not yet implemented]
--
-- DISABLE (the default) for clean installs, custom frameworks, or when you
-- prefer to patch consumer resources manually (see docs/INSTALL_QBCORE.md).
--
-- Each flag is zero-overhead when off — the shim files early-return.
--
-- See docs/COMPAT_MODE.md for the full coverage matrix (what's 100% covered,
-- what's partially covered, and what has no equivalent).

Config.CompatMode = {
    qbClothing  = true,
    skinchanger = false,  -- reserved for v2
    esxSkin     = false,  -- reserved for v2
}

-- ═══════════════════════════════════════════════════════════════════════
--                           PRICING SYSTEM
-- ═══════════════════════════════════════════════════════════════════════
-- Prices are charged when the player saves at a STORE (not in /tc creator).
-- Set a category to 0 to make it free. Set Config.Pricing.enabled = false
-- to disable pricing entirely.

Config.Pricing = {
    enabled = true,
    currency = "cash",         -- "cash" or "bank" (fallback: tries cash first, then bank)

    -- Per-subcategory prices (matches JS subcategory IDs)
    -- These apply to ITEM SELECTIONS (clothing, accessories, hair, etc.)
    items = {
        -- Clothing
        hats         = 150,
        masks        = 200,
        glasses      = 100,
        tops         = 250,
        undershirts  = 100,
        arms         = 50,
        pants        = 200,
        backpacks    = 300,
        shoes        = 150,
        -- Accessories
        watches      = 500,
        bracelets    = 250,
        earrings     = 200,
        -- Hair
        hairstyle    = 100,
        beard        = 75,
        -- Makeup
        lipstick     = 50,
        blush        = 50,
        -- Tattoos (per tattoo added)
        tattoo       = 500,
    },

    -- Per-store-type price multiplier (1.0 = normal, 0.5 = half price)
    -- Allows "luxury" stores to charge more without changing base prices
    storeMultiplier = {
        clothing    = 1.0,
        accessories = 1.0,
        barber      = 1.0,
        tattoo      = 1.0,
    },

    -- Sliders/colors (hair color, beard opacity, etc.) are free —
    -- only the base item selection is charged.
    -- Heritage, identity, and face features are always free.
}

-- ═══════════════════════════════════════════════════════════════════════
--                          CUSTOM PED MODELS
-- ═══════════════════════════════════════════════════════════════════════
-- When enabled, the Identity tab shows a "Custom Ped" section allowing
-- players to pick from all GTA V ped models (replaces the freemode ped).
-- Only shown in the full character creator (/tc), not in stores.

Config.CustomPeds = {
    enabled = true,
}

-- Framework, HUD, and target system are auto-detected.
-- Override only if auto-detection doesn't work for your setup:
-- Config.FrameworkOverride = "qbx"    -- "qbx", "qbcore", "esx", "standalone"
-- Config.HUDOverride       = false    -- "hud_apx", "ps-hud", false (disable)

-- ═══════════════════════════════════════════════════════════════════════
--                           GAME CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════

Config.PedModels = {
    Male = "mp_m_freemode_01",
    Female = "mp_f_freemode_01"
}

Config.PedModelHashes = {
    Male = `mp_m_freemode_01`,
    Female = `mp_f_freemode_01`
}

-- ═══════════════════════════════════════════════════════════════════════
--                        CLOTHING CATEGORIES
-- ═══════════════════════════════════════════════════════════════════════

Config.ClothingCategories = {
    -- Format: { label, componentId, isProp, icon }
    {
        name = "jacket",
        label = "Jacket",
        componentId = 11,
        isProp = false,
        icon = "jacket"
    },
    {
        name = "tshirt",
        label = "T-Shirt",
        componentId = 8,
        isProp = false,
        icon = "tshirt"
    },
    {
        name = "hands",
        label = "Gloves",
        componentId = 3,
        isProp = false,
        icon = "gloves"
    },
    {
        name = "pants",
        label = "Pants",
        componentId = 4,
        isProp = false,
        icon = "pants"
    },
    {
        name = "bags",
        label = "Bags",
        componentId = 5,
        isProp = false,
        icon = "bag"
    },
    {
        name = "shoes",
        label = "Shoes",
        componentId = 6,
        isProp = false,
        icon = "shoes"
    },
    {
        name = "glasses",
        label = "Glasses",
        componentId = 1,
        isProp = true,
        icon = "glasses"
    },
    {
        name = "watches",
        label = "Watch",
        componentId = 6,
        isProp = true,
        icon = "watch"
    },
    {
        name = "earrings",
        label = "Earrings",
        componentId = 2,
        isProp = true,
        icon = "earring"
    },
    {
        name = "masks",
        label = "Mask",
        componentId = 1,
        isProp = false,
        icon = "mask"
    },
    {
        name = "necklaces",
        label = "Necklace",
        componentId = 7,
        isProp = false,
        icon = "necklace"
    },
    {
        name = "hats",
        label = "Hat",
        componentId = 0,
        isProp = true,
        icon = "hat"
    },
    {
        name = "bracelets",
        label = "Bracelet",
        componentId = 7,
        isProp = true,
        icon = "bracelet"
    },
    {
        name = "vests",
        label = "Vest",
        componentId = 9,
        isProp = false,
        icon = "vest"
    },
    {
        name = "decals",
        label = "Decal",
        componentId = 10,
        isProp = false,
        icon = "decal"
    }
}

-- ═══════════════════════════════════════════════════════════════════════
--                         HEAD OVERLAY IDS
-- ═══════════════════════════════════════════════════════════════════════

Config.HeadOverlays = {
    Blemishes = 0,
    FacialHair = 1,
    Eyebrows = 2,
    Ageing = 3,
    Makeup = 4,
    Blush = 5,
    Complexion = 6,
    SunDamage = 7,
    Lipstick = 8,
    Moles = 9,
    ChestHair = 10,
    BodyBlemishes = 11
}

-- ═══════════════════════════════════════════════════════════════════════
--                        DEFAULT CLOTHING
-- ═══════════════════════════════════════════════════════════════════════

Config.DefaultClothing = {
    male = {
        [11] = { drawable = 15, texture = 0 },  -- Jacket
        [8] = { drawable = 15, texture = 0 },   -- Undershirt
        [3] = { drawable = 15, texture = 0 },   -- Torso/Arms
        [4] = { drawable = 61, texture = 0 },   -- Pants
        [6] = { drawable = 34, texture = 0 },   -- Shoes
        [5] = { drawable = 0, texture = 0 },    -- Bag
        [1] = { drawable = 0, texture = 0 },    -- Mask
        [7] = { drawable = 0, texture = 0 },    -- Accessories
        [9] = { drawable = 0, texture = 0 },    -- Vest
        [10] = { drawable = 0, texture = 0 }    -- Decals
    },
    female = {
        [11] = { drawable = 15, texture = 0 },
        [8] = { drawable = 3, texture = 0 },
        [3] = { drawable = 15, texture = 0 },
        [4] = { drawable = 15, texture = 0 },
        [6] = { drawable = 35, texture = 0 },
        [5] = { drawable = 0, texture = 0 },
        [1] = { drawable = 0, texture = 0 },
        [7] = { drawable = 0, texture = 0 },
        [9] = { drawable = 0, texture = 0 },
        [10] = { drawable = 0, texture = 0 }
    }
}

Config.DefaultProps = {
    male = {
        [0] = { drawable = -1, texture = 0 },  -- Hat
        [1] = { drawable = -1, texture = 0 },  -- Glasses
        [2] = { drawable = -1, texture = 0 },  -- Earrings
        [6] = { drawable = -1, texture = 0 },  -- Watch
        [7] = { drawable = -1, texture = 0 }   -- Bracelet
    },
    female = {
        [0] = { drawable = -1, texture = 0 },
        [1] = { drawable = -1, texture = 0 },
        [2] = { drawable = -1, texture = 0 },
        [6] = { drawable = -1, texture = 0 },
        [7] = { drawable = -1, texture = 0 }
    }
}

-- ═══════════════════════════════════════════════════════════════════════
--                        CAMERA SETTINGS
-- ═══════════════════════════════════════════════════════════════════════

Config.Camera = {
    DefaultFov = 50.0,

    Positions = {
        -- Full body — default view
        full    = { offset = vector3(0.0, 2.8, 0.0),  pointAt = vector3(0.0, 0.0, 0.0) },
        -- Face / head close-up (standing ped)
        face    = { offset = vector3(0.0, 1.6, 0.6),  pointAt = vector3(0.0, 0.0, 0.65) },
        -- Head tight close-up (eyes, glasses, hats)
        head    = { offset = vector3(0.0, 1.0, 0.65), pointAt = vector3(0.0, 0.0, 0.68) },
        -- Upper body (tops, torso)
        upper   = { offset = vector3(0.0, 1.8, 0.15), pointAt = vector3(0.0, 0.0, 0.2) },
        -- Lower body (pants, shoes)
        lower   = { offset = vector3(0.0, 2, -0.4), pointAt = vector3(0.0, 0.0, -0.45) },
        -- Feet close-up (shoes)
        feet    = { offset = vector3(0.0, 1.8, -0.7), pointAt = vector3(0.0, 0.0, -0.75) },
        -- Legacy aliases kept for compatibility
        Face    = { offset = vector3(0.0, 1.6, 0.6),  pointAt = vector3(0.0, 0.0, 0.65) },
        Hair    = { offset = vector3(0.0, 1.6, 0.6),  pointAt = vector3(0.0, 0.0, 0.65) },
        Body    = { offset = vector3(0.0, 3.2, 0.0),  pointAt = vector3(0.0, 0.0, 0.0) },
        Legs    = { offset = vector3(0.0, 2, -0.4), pointAt = vector3(0.0, 0.0, -0.45) }
    }
}

-- ═══════════════════════════════════════════════════════════════════════
--                        STORE LOCATIONS
-- ═══════════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════════
--                              OUTFITS
-- ═══════════════════════════════════════════════════════════════════════
-- Saved outfits = a snapshot of clothing + props + accessories (with textures).
-- Face, heritage, body and hair are NOT part of an outfit.
Config.Outfits = {
    enabled      = true,    -- master switch: adds the "Outfits" tab to clothing stores
    maxPerPlayer = 10,      -- cap on saved outfits per player (server-enforced)
    saveCost     = 0,       -- money charged when saving an outfit (0 = free)
    applyCost    = 0,       -- money charged when applying an outfit (0 = free)
    shareEnabled = true,    -- allow sharing an outfit to another player
    shareRadius  = 0.0,     -- 0 = any online player; >0 = only players within N metres
                            -- of the sharer's pre-store position appear in the picker
    shareCooldown = 10,     -- seconds between shares per player (anti-spam)
}

Config.StoreTypes = {
    clothing = {
        tabs = { "clothing" },
        blip = { sprite = 73, color = 33, scale = 0.8, name = "Clothing Store" },
        defaultSize = vector2(14.0, 10.0),
        openCamera = "full"
    },
    accessories = {
        tabs = { "accessories" },
        blip = { sprite = 617, color = 44, scale = 0.8, name = "Accessories Store" },
        defaultSize = vector2(10.0, 10.0),
        openCamera = "upper"
    },
    barber = {
        tabs = { "hair", "features", "makeup" },
        blip = { sprite = 71, color = 51, scale = 0.8, name = "Barber Shop" },
        defaultSize = vector2(4.0, 6.0),
        openCamera = "face"
    },
    tattoo = {
        tabs = { "tattoos" },
        blip = { sprite = 75, color = 1, scale = 0.8, name = "Tattoo Parlor" },
        defaultSize = vector2(7.0, 4.5),
        openCamera = "full"
    }
}

-- Add the Outfits tab to clothing stores when the feature is enabled.
if Config.Outfits and Config.Outfits.enabled then
    Config.StoreTypes.clothing.tabs[#Config.StoreTypes.clothing.tabs + 1] = "outfits"
end

-- ═════════════════════════════════════════════════════════════════════
-- STORE LOCATIONS — SEED DATA ONLY
-- ─────────────────────────────────────────────────────────────────────
-- These lists are NOT the live source of stores. On the FIRST server start
-- they are copied once into the editable admin storage (data/admin_stores.json)
-- and from then on EVERY store is created, edited and deleted in-game through
-- the /storeadmin panel. Editing the lists below only affects a brand-new
-- install (before the one-time seed runs). To reset to these defaults: delete
-- data/admin_stores.json AND data/.stores_seeded, then restart.
-- ═════════════════════════════════════════════════════════════════════

-- TEST MODE: when true, the FIRST-RUN seed uses the 3 test stores below
-- instead of the full production list. No effect after the initial seed.
Config.TestMode = false

-- Full production store list — seeded into /storeadmin on first run.
-- pedPosition: where the ped is teleported when opening the store (faces away from walls so camera has clear space)
Config.AllStoreLocations = {
    -- Clothing Stores (Binco)
    { coords = vector4(76.198, -1393.723, 29.375, 90.717), type = "clothing", pedPosition = vector4(75.39, -1398.28, 29.38, 6.73) },
    { coords = vector4(-822.722, -1074.729, 11.327, 30.255), type = "clothing", pedPosition = vector4(-828.71, -1075.23, 11.18, 294.94) },
    { coords = vector4(424.863, -805.347, 29.490, 271.37), type = "clothing", pedPosition = vector4(425.91, -801.03, 29.49, 177.79) },
    { coords = vector4(-1101.625, 2709.397, 19.107, 42.847), type = "clothing", pedPosition = vector4(-1108.21, 2707.88, 19.11, 309.12) },
    { coords = vector4(1195.747, 2709.454, 38.222, 3.044), type = "clothing", pedPosition = vector4(1190.36, 2712.46, 38.22, 269.51) },
    { coords = vector4(1693.129, 4823.581, 42.062, 278.209), type = "clothing", pedPosition = vector4(1696.07, 4829.06, 42.06, 194.47) },
    { coords = vector4(4.914, 6513.571, 31.877, 224.153), type = "clothing", pedPosition = vector4(11.34, 6515.15, 31.88, 131.93) },

    -- Clothing Stores (Suburban)
    { coords = vector4(-1194.865, -773.079, 17.323, 307.0), type = "clothing", size = vector2(11.0, 13.0), pedPosition = vector4(-1194.86, -773.08, 17.32, 130.71) },
    { coords = vector4(124.709, -218.522, 54.557, 158.388), type = "clothing", size = vector2(11.0, 13.0), pedPosition = vector4(124.48, -218.84, 54.56, 334.06) },
    { coords = vector4(-3171.362, 1049.043, 20.863, 157.856), type = "clothing", size = vector2(11.0, 13.0), pedPosition = vector4(-3171.36, 1049.04, 20.86, 334.06) },
    { coords = vector4(617.452, 2758.469, 42.087, 181.575), type = "clothing", size = vector2(11.0, 13.0), pedPosition = vector4(617.54, 2759.23, 42.09, 182.67) },

    -- Clothing Stores (Ponsonbys)
    { coords = vector4(-1452.207, -235.670, 49.532, 227.456), type = "clothing", size = vector2(18.0, 8.0), pedPosition = vector4(-1447.48, -242.89, 49.82, 328.28) },
    { coords = vector4(-161.482, -303.730, 39.460, 71.126), type = "clothing", size = vector2(10.0, 10.0), pedPosition = vector4(-168.04, -299.29, 39.73, 121.44) },

    -- Barber Shops
    -- chairs: array of { coords, h (heading), offset, dict (optional), anim (optional) }
    -- Player walks to nearest chair marker and sits down with enter animation.

    -- Downtown Barber
    { coords = vector4(-33.675, -152.162, 57.076, 158.017), type = "barber",
      chairs = {
          { coords = vector3(-34.89, -150.09, 57.09), h = 65.31,  offset = vector3(0.03, -0.75, 0.0) },
          { coords = vector3(-35.39, -151.48, 57.09), h = 67.31,  offset = vector3(-0.02, -0.75, 0.0) },
          { coords = vector3(-35.81, -152.85, 57.09), h = 62.77,  offset = vector3(-0.04, -0.75, 0.0) },
      }
    },
    -- Vinewood Barber
    { coords = vector4(1212.354, -473.242, 66.208, 253.283), type = "barber",
      chairs = {
          { coords = vector3(1210.24, -474.85, 66.22), h = 168.42, offset = vector3(-0.05, -0.75, 0.0) },
          { coords = vector3(1211.76, -475.23, 66.22), h = 164.1,  offset = vector3(0.05, -0.75, 0.0) },
          { coords = vector3(1213.23, -475.43, 66.22), h = 164.1,  offset = vector3(0.02, -0.5, 0.0) },
      }
    },
    -- Paleto Barber
    { coords = vector4(-278.563, 6227.902, 31.695, 226.669), type = "barber",
      chairs = {
          { coords = vector3(-281.05, 6227.46, 31.73), h = 133.0, offset = vector3(0.02, -0.7, 0.0) },
          { coords = vector3(-279.99, 6226.4, 31.73),  h = 133.0, offset = vector3(0.02, -0.7, 0.0) },
          { coords = vector3(-279.0, 6225.42, 31.73),  h = 133.0, offset = vector3(-0.09, -0.7, 0.0) },
      }
    },
    -- Vespucci Barber (custom sitting anim — different chair model)
    { coords = vector4(-814.228, -184.899, 37.568, 297.271), type = "barber", size = vector2(6.0, 14.0),
      chairs = {
          { coords = vector3(-813.06, -180.41, 37.47), h = 28.83, offset = vector3(-0.04, -0.6, -0.25), dict = "anim@amb@clubhouse@boardroom@crew@female@var_a@base@", anim = "base" },
          { coords = vector3(-814.8, -181.37, 37.57),  h = 28.83, offset = vector3(-0.04, -0.6, -0.35), dict = "anim@amb@clubhouse@boardroom@crew@female@var_a@base@", anim = "base" },
          { coords = vector3(-816.54, -182.32, 37.57), h = 28.83, offset = vector3(-0.08, -0.6, -0.35), dict = "anim@amb@clubhouse@boardroom@crew@female@var_a@base@", anim = "base" },
          { coords = vector3(-818.3, -183.29, 37.57),  h = 28.83, offset = vector3(-0.08, -0.6, -0.35), dict = "anim@amb@clubhouse@boardroom@crew@female@var_a@base@", anim = "base" },
      }
    },
    -- South LS Barber
    { coords = vector4(136.800, -1708.709, 29.291, 318.318), type = "barber",
      chairs = {
          { coords = vector3(137.85, -1710.83, 29.3), h = 229.45, offset = vector3(-0.02, -0.7, 0.0) },
          { coords = vector3(138.83, -1709.68, 29.3), h = 229.45, offset = vector3(-0.02, -0.7, 0.0) },
          { coords = vector3(139.78, -1708.58, 29.3), h = 220.45, offset = vector3(0.02, -0.7, 0.0) },
      }
    },
    -- Sandy Shores Barber
    { coords = vector4(1934.55, 3730.16, 32.86, 296.86), type = "barber",
      chairs = {
          { coords = vector3(1934.55, 3730.16, 32.86), h = 296.86, offset = vector3(0.02, -0.6, 0.0) },
          { coords = vector3(1933.87, 3731.52, 32.86), h = 296.86, offset = vector3(0.02, -0.7, 0.0) },
          { coords = vector3(1933.23, 3732.79, 32.86), h = 295.86, offset = vector3(-0.04, -0.75, 0.0) },
      }
    },
    -- Rockford Hills Barber
    { coords = vector4(-1283.248, -1117.705, 6.990, 269.854), type = "barber",
      chairs = {
          { coords = vector3(-1284.31, -1119.68, 7.01), h = 182.68, offset = vector3(-0.04, -0.68, 0.0) },
          { coords = vector3(-1282.81, -1119.66, 7.01), h = 183.68, offset = vector3(-0.04, -0.6, 0.0) },
          { coords = vector3(-1281.35, -1119.68, 7.01), h = 173.68, offset = vector3(-0.01, -0.6, 0.0) },
      }
    },

    -- Tattoo Parlors
    { coords = vector4(322.934, 180.964, 103.586, 339.768), type = "tattoo", pedPosition = vector4(322.62, 180.34, 103.59, 156.2) },
    { coords = vector4(-1153.866, -1426.274, 4.954, 218.423), type = "tattoo", pedPosition = vector4(-1154.01, -1425.31, 4.95, 23.21) },
    { coords = vector4(1322.814, -1652.563, 52.275, 220.931), type = "tattoo", pedPosition = vector4(1322.6, -1651.9, 51.2, 42.47) },
    { coords = vector4(-3170.346, 1075.743, 20.829, 64.88), type = "tattoo", pedPosition = vector4(-3169.52, 1074.86, 20.83, 253.29) },
    { coords = vector4(-293.290, 6199.581, 31.487, 129.26), type = "tattoo", pedPosition = vector4(-294.24, 6200.12, 31.49, 195.72) },
    { coords = vector4(1863.838, 3748.420, 33.031, 304.471), type = "tattoo", pedPosition = vector4(1864.1, 3747.91, 33.03, 17.23) },

    -- Accessories Stores (Ponsonbys — luxury jewellery / accessories)
    { coords = vector4(-1452.207, -235.670, 49.532, 227.456), type = "accessories", size = vector2(18.0, 8.0), pedPosition = vector4(-1452.0, -236.0, 49.53, 47.46) },
    { coords = vector4(-161.482, -303.730, 39.460, 71.126),   type = "accessories", size = vector2(10.0, 10.0), pedPosition = vector4(-161.7, -303.5, 39.46, 251.13) }
}

-- 4 test stores: one per type, all in/near downtown LS
Config.TestStoreLocations = {
    {
        coords = vector4(76.198, -1393.723, 29.375, 90.717),
        type   = "clothing",
        label  = "Binco (TEST)",
        pedPosition = vector4(75.39, -1398.28, 29.38, 6.73)
    },
    {
        coords = vector4(-161.482, -303.730, 39.460, 71.126),
        type   = "accessories",
        label  = "Ponsonbys Accessories (TEST)",
        size   = vector2(10.0, 10.0),
        pedPosition = vector4(-161.7, -303.5, 39.46, 251.13)
    },
    {
        coords = vector4(-33.675, -152.162, 57.076, 158.017),
        type   = "barber",
        label  = "Downtown Barber (TEST)",
        chairs = {
            { coords = vector3(-34.89, -150.09, 57.09), h = 65.31,  offset = vector3(0.03, -0.75, 0.0) },
            { coords = vector3(-35.39, -151.48, 57.09), h = 67.31,  offset = vector3(-0.02, -0.75, 0.0) },
            { coords = vector3(-35.81, -152.85, 57.09), h = 62.77,  offset = vector3(-0.04, -0.75, 0.0) },
        }
    },
    {
        coords = vector4(-1153.866, -1426.274, 4.954, 218.423),
        type   = "tattoo",
        label  = "South LS Tattoo (TEST)",
        pedPosition = vector4(-1154.01, -1425.31, 4.95, 23.21)
    }
}

Config.StoreLocations = Config.TestMode and Config.TestStoreLocations or Config.AllStoreLocations

-- ── Admin store settings ────────────────────────────────────────────────
Config.AdminPermission = 'admin'              -- qbx_core permission group required
Config.AdminStoreFile  = 'data/admin_stores.json'

-- ── Import from another clothing script ─────────────────────────────────
-- If you're switching TO orb-clothing from qb-clothing or qs-appearance, orb can
-- import every player's saved look (face, body, clothing, props, tattoos) and
-- their saved outfits into its own tables. It only READS the other script's
-- tables — nothing there is deleted or edited.
--
-- Manual, anytime (admin command, always available):
--     /migrateclothing            → dry run, reports what it would import
--     /migrateclothing confirm     → import (skips players who already have an
--                                    orb look; add `overwrite` to replace them)
--     /migrateqb  /  /migrateqs    → same, but pinned to one source format
--
-- Automatic on resource start (this setting). Idempotent: only players WITHOUT an
-- orb look are touched, so it self-completes and leaving it on costs nothing after
-- the first run. Recommended flow: run the dry-run command once, eyeball it, then
-- switch this on (or just run `confirm` manually).
--     'off'  (default) — never auto-import; use the command when you're ready
--     'qb'             — auto-import qb-clothing rows on start
--     'qs'             — auto-import qs-appearance rows on start
--     'auto'           — auto-import whichever of the two each row looks like
Config.AutoImport = 'off'

-- ═══════════════════════════════════════════════════════════════════════
--                        UTILITY FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════

function Config.IsMale(ped)
    return GetEntityModel(ped) == Config.PedModelHashes.Male
end


-- ═══════════════════════════════════════════════════════════════════════
--                  CUSTOM CLOTHING (ADD-ON SUPPORT)
-- ═══════════════════════════════════════════════════════════════════════
-- Provide per-drawable metadata for ADD-ON clothing packs (YMT add-ons that
-- append new drawables beyond the vanilla count). REPLACE packs are handled
-- automatically because they reuse vanilla drawable IDs — the default CDN
-- images still apply to them.
--
-- Structure, per gender:
--   Config.CustomClothing.<gender>.<sectionId> = { count, items }
--
--   sectionId — must match a key from Config.UIMapping, e.g.:
--               clothing_tops, clothing_pants, clothing_hats,
--               clothing_shoes, clothing_undershirts, clothing_masks,
--               clothing_backpacks, clothing_glasses, clothing_arms,
--               accessories_watches, accessories_bracelets, accessories_earrings
--
--   count     — (optional) total number of drawables in this subcategory,
--               INCLUDING vanilla ones. Defaults to the hardcoded UI count if
--               omitted. Set this when your add-on pack adds new drawables
--               beyond the default range so the UI renders cards for them.
--
--   items     — (optional) table keyed by raw GTA drawable index. Each entry:
--                 image = string   -- absolute URL (https://...) or a path
--                                     starting with '/' that gets prefixed
--                                     with the CDN base from config_ui.js.
--                                     If omitted, the UI shows a numbered
--                                     placeholder card (same as a missing
--                                     vanilla image).
--                 label = string   -- optional tooltip shown on hover.
--
-- Example:
--   Config.CustomClothing = {
--       male = {
--           clothing_tops = {
--               count = 450,
--               items = {
--                   [400] = { label = 'Cyber Jacket', image = 'https://i.imgur.com/abc.webp' },
--                   [401] = { label = 'Neon Hoodie' },
--                   [402] = { image = '/custom/tops/402.webp' },
--               }
--           },
--           clothing_pants = {
--               count = 160,
--               items = {
--                   [151] = { label = 'Tactical Pants' },
--               }
--           },
--       },
--       female = {
--           clothing_tops = {
--               count = 420,
--               items = {
--                   [398] = { label = 'Winter Coat', image = 'https://...' },
--               }
--           },
--       },
--   }
--
-- Notes:
--   - Default value below is empty — customers fill it in per their add-ons.
--   - Changes require a `restart orb-clothing` to propagate to open UIs.
--   - Custom images can be hosted anywhere (imgur, GitHub raw, your CDN) as
--     long as the URL is publicly reachable from the player's browser.

Config.CustomClothing = {
    male   = {},
    female = {},
}

-- ═══════════════════════════════════════════════════════════════════════
--                        UI MAPPING (charactercreator style)
-- ═══════════════════════════════════════════════════════════════════════

Config.UIMapping = {
    -- Identity
    identity_gender = { type = "model", values = {"mp_m_freemode_01", "mp_f_freemode_01"} },

    -- Heritage
    heritage_mother = { type = "heritage", param = "mother" },
    heritage_father = { type = "heritage", param = "father" },

    -- Features
    features_eyebrows = { type = "overlay", overlayId = 2 },
    features_eyes = { type = "eyeColor" },

    -- Hair
    hair_hairstyle = { type = "hair" },
    hair_beard = { type = "overlay", overlayId = 1 },

    -- Makeup
    makeup_lipstick = { type = "overlay", overlayId = 8 },
    makeup_blush = { type = "overlay", overlayId = 5 },

    -- Clothing (por subcategoría)
    -- gameOffset: added to the stored UI index before applying to the ped.
    -- Matches the JS-side IMAGE_MAPPING.gameOffset so the save round-trip
    -- (in-session apply → save → reload) stays consistent. Only props with
    -- a "remove" slot at UI index 0 need gameOffset = -1.
    clothing_hats = { type = "prop", propId = 0, gameOffset = -1 },
    clothing_masks = { type = "clothing", componentId = 1 },
    clothing_glasses = { type = "prop", propId = 1, gameOffset = -1 },
    clothing_tops = { type = "clothing", componentId = 11 },
    clothing_undershirts = { type = "clothing", componentId = 8 },
    clothing_arms = { type = "clothing", componentId = 3 },
    clothing_pants = { type = "clothing", componentId = 4 },
    clothing_backpacks = { type = "clothing", componentId = 5 },
    clothing_shoes = { type = "clothing", componentId = 6 },
    clothing_items = { type = "clothing", componentId = 11 },

    -- Accessories (props with a "remove" slot at UI index 0 → gameOffset = -1,
    -- same as hats/glasses, so the UI card lines up with the in-game drawable)
    accessories_watches = { type = "prop", propId = 6, gameOffset = -1 },
    accessories_bracelets = { type = "prop", propId = 7, gameOffset = -1 },
    accessories_earrings = { type = "prop", propId = 2, gameOffset = -1 },
    accessories_items = { type = "prop", propId = 0 }
}

Config.SliderMapping = {
    -- Heritage
    resemblance = { type = "heritage", param = "shapeValue" },
    skinTone = { type = "heritage", param = "colorValue" },

    -- Features — eyebrows
    eyebrowHeight = { type = "faceFeature", featureId = 6 },
    eyebrowDepth  = { type = "faceFeature", featureId = 7 },

    -- Features — eyes
    eyeOpening = { type = "faceFeature", featureId = 11 },

    -- Features — nose
    noseWidth  = { type = "faceFeature", featureId = 0 },
    noseHeight = { type = "faceFeature", featureId = 1 },
    noseBridge = { type = "faceFeature", featureId = 2 },
    noseTip    = { type = "faceFeature", featureId = 4 },
    noseTwist  = { type = "faceFeature", featureId = 5 },

    -- Features — cheeks
    cheekboneHeight = { type = "faceFeature", featureId = 8 },
    cheekboneWidth  = { type = "faceFeature", featureId = 9 },
    cheeksWidth     = { type = "faceFeature", featureId = 10 },

    -- Features — lips, jaw, chin (legacy IDs kept for saved data compatibility)
    chestSize    = { type = "faceFeature", featureId = 12 },  -- Lip Thickness
    waistSize    = { type = "faceFeature", featureId = 13 },  -- Jaw Width
    hipSize      = { type = "faceFeature", featureId = 14 },  -- Jaw Length
    armSize      = { type = "faceFeature", featureId = 15 },  -- Chin Height
    chinDepth    = { type = "faceFeature", featureId = 16 },
    chinWidth    = { type = "faceFeature", featureId = 17 },
    chinHoleSize = { type = "faceFeature", featureId = 18 },

    -- Body sliders
    bodyWeight = { type = "faceFeature", featureId = 19 },  -- NeckThickness
    bodyHeight = { type = "pedScale" },

    -- Hair/Makeup opacity
    hairOpacity     = { type = "ignore" },
    beardOpacity    = { type = "overlayOpacity", overlayId = 1 },
    lipstickOpacity = { type = "overlayOpacity", overlayId = 8 },
    blushOpacity    = { type = "overlayOpacity", overlayId = 5 },

    -- Clothing
    itemOpacity = { type = "ignore" }
}

Config.NumberMapping = {
    -- Identity
    age = { type = "faceFeature", featureId = 3 },

    -- Hair colors
    hairColor = { type = "hairColor", param = "primary" },
    hairHighlight = { type = "hairColor", param = "highlight" },

    -- Overlay colors
    beardColor = { type = "overlayColor", overlayId = 1 },
    eyebrowColor = { type = "overlayColor", overlayId = 2 },
    lipstickColor = { type = "overlayColor", overlayId = 8 },
    blushColor = { type = "overlayColor", overlayId = 5 },

    -- Clothing
    texture = { type = "texture" },
    palette = { type = "palette" }
}

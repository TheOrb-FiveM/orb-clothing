// CDN clothing images: https://cdn.jsdelivr.net/gh/TheOrb-FiveM/images-cdn@main/clothing/
// model = mp_m_freemode_01 or mp_f_freemode_01
// imageOffset: added to UI index to get image file index
// gameOffset: added to UI index before sending to Lua (e.g. -1 so UI slot 0 sends -1 = clear prop)
// CDN base is set by config_ui.js (edit there, not here) so customers can
// self-host add-on clothing images without touching escrow-protected code.
const CDN_BASE = window.ORB_CDN_BASE || 'https://cdn.jsdelivr.net/gh/TheOrb-FiveM/images-cdn@main/clothing';
// Image file extension — 'webp' for the upstream CDN, 'png' when using
// orb-clothing_companion's local NUI serving.
const IMAGE_EXT = window.ORB_IMAGE_EXT || 'webp';

// ── Greenscreen mode (fully automated) ──────────────────────────────
// When set, getImageUrl() builds URLs that point directly at the output
// of orb-greenscreen / fivem-greenscreener (e.g. "male_prop_0_5.png")
// via the cfx-nui-<resource> protocol. No renaming, no copying needed.
const GREENSCREEN_RESOURCE = window.ORB_GREENSCREEN_RESOURCE || null;
const GREENSCREEN_BASE = GREENSCREEN_RESOURCE
    ? `https://cfx-nui-${GREENSCREEN_RESOURCE}/images`
    : null;

// Maps sectionId → { type, id } so we can construct greenscreen filenames.
// type 'clothing' → "{gender}_{id}_{drawable}.png"
// type 'prop'     → "{gender}_prop_{id}_{drawable}.png"
const GREENSCREEN_MAP = {
    'clothing_masks':        { type: 'clothing', id: 1 },
    'clothing_arms':         { type: 'clothing', id: 3 },
    'clothing_pants':        { type: 'clothing', id: 4 },
    'clothing_backpacks':    { type: 'clothing', id: 5 },
    'clothing_shoes':        { type: 'clothing', id: 6 },
    'clothing_undershirts':  { type: 'clothing', id: 8 },
    'clothing_tops':         { type: 'clothing', id: 11 },
    'clothing_hats':         { type: 'prop', id: 0 },
    'clothing_glasses':      { type: 'prop', id: 1 },
    'accessories_earrings':  { type: 'prop', id: 2 },
    'accessories_watches':   { type: 'prop', id: 6 },
    'accessories_bracelets': { type: 'prop', id: 7 },
    'hair_hairstyle':        { type: 'clothing', id: 2 },
};

function getGreenscreenUrl(sectionId, index) {
    const gsMap = GREENSCREEN_MAP[sectionId];
    if (!gsMap) return null;

    // Compute the actual game drawable from the UI card index.
    // Props with gameOffset (hats, glasses) have a "remove" slot at UI
    // card 0, so game drawable = index + gameOffset. Skip if negative.
    const imgMapping = IMAGE_MAPPING[sectionId];
    const gameDrawable = index + (imgMapping && imgMapping.gameOffset ? imgMapping.gameOffset : 0);
    if (gameDrawable < 0) return null;

    const gender = (currentGender === 'female') ? 'female' : 'male';

    if (gsMap.type === 'prop') {
        return `${GREENSCREEN_BASE}/clothing/${gender}_prop_${gsMap.id}_${gameDrawable}.png`;
    }
    return `${GREENSCREEN_BASE}/clothing/${gender}_${gsMap.id}_${gameDrawable}.png`;
}
const IMAGE_MAPPING = {
    // Clothing (webp, in clothing_images/)
    'clothing_hats':         { prefix: 'helmet_1', gameOffset: -1 },
    'clothing_masks':        { prefix: 'mask_1' },
    'clothing_glasses':      { prefix: 'glasses_1', gameOffset: -1 },
    'clothing_tops':         { prefix: 'torso_1' },
    'clothing_undershirts':  { prefix: 'tshirt_1' },
    'clothing_arms':         { prefix: 'arms' },
    'clothing_pants':        { prefix: 'pants_1' },
    'clothing_backpacks':    { prefix: 'bags_1' },
    'clothing_shoes':        { prefix: 'shoes_1' },
    'accessories_watches':   { prefix: 'watches_1', gameOffset: -1 },
    'accessories_bracelets': { prefix: 'bracelets_1', gameOffset: -1 },
    'accessories_earrings':  { prefix: 'ear_1', gameOffset: -1 },
    'hair_hairstyle':        { prefix: 'hair_1' },
    'heritage_mother':       { prefix: 'mom', fixedGender: 'female' },
    'heritage_father':       { prefix: 'dad', fixedGender: 'male' },
    // Face features (png, in creator_images/)
    'features_eyebrows':     { creator: 'eyebrows', hasGender: true },
    'features_eyes':         { creator: 'eyes', hasGender: true },
    'hair_beard':            { creator: 'facialHair', hasGender: true },
    'makeup_lipstick':       { creator: 'lipstick', hasGender: true },
    'makeup_blush':          { creator: 'blush', hasGender: true },
};

// Camera position to use per category (matches Config.Camera.Positions keys)
const CATEGORY_CAMERA = {
    identity:    'face',
    heritage:    'face',
    features:    'face',
    body:        'full',
    hair:        'face',
    makeup:      'face',
    clothing:    'full',
    outfits:     'full',
    accessories: 'upper',
    tattoos:     'full'
};

// Camera per clothing subcategory (overrides category default)
const SUBCATEGORY_CAMERA = {
    hats:       'head',
    masks:      'face',
    glasses:    'head',
    tops:       'upper',
    backpacks:  'full',
    pants:      'lower',
    shoes:      'feet',
    watches:    'upper',
    bracelets:  'upper',
    earrings:   'face',
    eyes:       'head',
    undershirts:'upper',
    arms:       'upper'
};

let currentGender = 'male';
let isFirstTime = false;
let allowedTabs = null; // null = all tabs visible; array = only these tab ids visible
let allowedSubs = null; // null = all subcategories; array = only these subcategory ids
let currentStoreType = null; // 'clothing', 'barber', 'tattoo', etc. — set on openUI
let resourceName = 'orb-clothing'; // overwritten by 'init' NUI message

// ── i18n ─────────────────────────────────────────────────────────────
// Locale dictionary handed over by Lua (GetLocaleTable) on the 'init'
// message. t() returns the translation for a key, falling back to the
// provided English text (or the key itself) so the UI never shows blanks.
let LOCALE = {};
function t(key, fallback) {
    const v = LOCALE[key];
    if (v !== undefined && v !== null) return v;
    return fallback !== undefined ? fallback : key;
}
// Like t() but substitutes %d / %s placeholders with the given args in order.
function tf(key, fallback, ...args) {
    let i = 0;
    return t(key, fallback).replace(/%[ds]/g, () => (i < args.length ? String(args[i++]) : ''));
}
// Translate the static markup (index.html) in place: any element tagged with
// data-i18n gets its text replaced, data-i18n-ph swaps its placeholder. The
// current text/placeholder is used as the English fallback.
function translateStaticDOM() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        el.textContent = t(el.getAttribute('data-i18n'), el.textContent);
    });
    document.querySelectorAll('[data-i18n-ph]').forEach(el => {
        el.setAttribute('placeholder', t(el.getAttribute('data-i18n-ph'), el.getAttribute('placeholder')));
    });
}
let tattooList = null;  // gender-resolved tattoo data sent from Lua: { ZONE_TORSO: [...], ... }
let activeTattoos = {}; // key = "collection:hash" → true (applied)

// ── Pricing System ──────────────────────────────────────────────────
let pricingData = null;          // { enabled, items: {subcatId: price}, multiplier }
let initialSelections = {};      // snapshot of selections when UI opened (to diff changes)
let initialActiveTattoos = {};   // snapshot of active tattoos when UI opened

// ── Custom Peds ─────────────────────────────────────────────────────
let customPedsData = null;       // array of { name, label, category } — sent from Lua when enabled
const PED_IMAGE_CDN = 'https://docs.fivem.net/peds';  // {PED_IMAGE_CDN}/{name}.webp

// ── Custom Clothing (add-on support) ────────────────────────────────
// Sent by Lua from Config.CustomClothing. Shape:
// { male: { clothing_tops: { count: 450, items: { 400: { image, label } } } }, female: {...} }
// - count: optional number to extend a subcategory's drawable range beyond
//          the hardcoded SUBCATEGORIES count (used for add-on drawables).
// - items: map of drawable index → { image, label }. image may be an absolute
//          URL or a path starting with '/' (prefixed with CDN_BASE at runtime).
let customClothingData = null;

// ── Auto-detected counts from FiveM natives ─────────────────────────
// Sent by Lua (BuildAutoCounts) at openUI time and refreshed on gender
// swap via the 'updateAutoCounts' NUI message. Shape: { sectionId: count }.
// Covers add-on clothing packs without manual Config.CustomClothing entries.
let autoCountsData = null;

// ── Outfits ─────────────────────────────────────────────────────────
let outfitsData = null;   // array of { id, name, data } — lazy-loaded from Lua
let outfitConfig = null;  // { enabled, max, saveCost, applyCost, shareEnabled }

const STORE_LABELS = {
    clothing:    { title: 'CLOTHING STORE',    subtitle: 'Browse and change your outfit' },
    accessories: { title: 'ACCESSORIES STORE', subtitle: 'Browse watches, glasses and more' },
    barber:      { title: 'BARBER SHOP',       subtitle: 'Change your hair, beard and makeup' },
    tattoo:      { title: 'TATTOO PARLOR',     subtitle: 'Add or remove tattoos' },
    default:     { title: 'CHARACTER CREATOR', subtitle: 'Customize your character appearance' }
};

const panelTitle    = document.getElementById('panelTitle');
const panelSubtitle = document.getElementById('panelSubtitle');

function applyStoreLabels(storeType, storeName) {
    const labels = STORE_LABELS[storeType] || STORE_LABELS.default;
    const key = STORE_LABELS[storeType] ? storeType : 'default';
    panelTitle.textContent    = storeName ? storeName.toUpperCase() : t('store_' + key + '_title', labels.title);
    panelSubtitle.textContent = t('store_' + key + '_subtitle', labels.subtitle);
}

// Look up a custom clothing override for the current gender.
// Returns { image?, label?, count? } or null.
function getCustomClothingEntry(sectionId, index) {
    if (!customClothingData) return null;
    const genderSet = customClothingData[currentGender];
    if (!genderSet) return null;
    const section = genderSet[sectionId];
    if (!section || !section.items) return null;
    return section.items[index] || null;
}

// Extended drawable count for a subcategory (add-on support).
// Priority (max wins, so legitimate vanilla slots are never truncated):
//   1. Manual Config.CustomClothing.<gender>.<section>.count (customer explicit)
//   2. Auto-detected count from FiveM natives (BuildAutoCounts)
//   3. Hardcoded base count in SUBCATEGORIES (fallback)
// The max() stacking means any add-on pack picked up by natives becomes
// visible automatically, and the customer can still bump the ceiling higher
// via Config.CustomClothing if they want extra empty slots for planning.
function getExtendedCount(sectionId, baseCount) {
    let max = baseCount;

    if (autoCountsData && typeof autoCountsData[sectionId] === 'number') {
        if (autoCountsData[sectionId] > max) max = autoCountsData[sectionId];
    }

    if (customClothingData) {
        const genderSet = customClothingData[currentGender];
        if (genderSet) {
            const section = genderSet[sectionId];
            if (section && typeof section.count === 'number' && section.count > max) {
                max = section.count;
            }
        }
    }

    return max;
}

// Optional tooltip label for a drawable — shown as the native title= attribute.
function getCustomLabel(sectionId, index) {
    const entry = getCustomClothingEntry(sectionId, index);
    return entry && entry.label ? entry.label : null;
}

function getImageUrl(sectionId, index) {
    // Custom override: takes priority over everything.
    const customEntry = getCustomClothingEntry(sectionId, index);
    if (customEntry && customEntry.image) {
        const img = customEntry.image;
        if (/^https?:\/\//i.test(img)) return img;
        if (img.startsWith('/')) return `${CDN_BASE}${img}`;
        return `${CDN_BASE}/${img}`;
    }

    // Greenscreen mode: read directly from orb-greenscreen output folder.
    // Uses the raw filename format (male_prop_0_5.png) via cfx-nui protocol.
    if (GREENSCREEN_BASE) {
        const gsUrl = getGreenscreenUrl(sectionId, index);
        if (gsUrl) return gsUrl;
        // Fall through to CDN for sections not in GREENSCREEN_MAP
        // (identity_gender, heritage, creator images, etc.)
    }

    // Gender cards: male → dad face #1, female → mom face #1
    if (sectionId === 'identity_gender') {
        if (index === 0) return `${CDN_BASE}/clothing_images/mp_m_freemode_01-dad-1.${IMAGE_EXT}`;
        if (index === 1) return `${CDN_BASE}/clothing_images/mp_f_freemode_01-mom-1.${IMAGE_EXT}`;
        return null;
    }

    const mapping = IMAGE_MAPPING[sectionId];
    if (!mapping) return null;

    // Skip specific drawable indices that have no image (e.g. "no hat" at index 0)
    if (mapping.skipIndex !== undefined && index === mapping.skipIndex) return null;

    // Creator images (face features: eyebrows, eyes, makeup, etc.)
    if (mapping.creator) {
        const gender = mapping.fixedGender || currentGender;
        return `${CDN_BASE}/creator_images/${gender}/${mapping.creator}/${index}.png`;
    }

    // Apply offset to convert drawable index to image file index
    const imageIndex = index + (mapping.imageOffset || 0);
    if (imageIndex < 0) return null;

    const gender = mapping.fixedGender || currentGender;
    const model = gender === 'male' ? 'mp_m_freemode_01' : 'mp_f_freemode_01';
    return `${CDN_BASE}/clothing_images/${model}-${mapping.prefix}-${imageIndex}.${IMAGE_EXT}`;
}

const CATEGORIES = [
    { id: 'identity', name: 'Identity', icon: 'assets/icon-face.svg' },
    { id: 'heritage', name: 'Heritage', icon: 'assets/icon-heritage.svg' },
    { id: 'features', name: 'Features', icon: 'assets/icon-features.svg' },
    { id: 'hair', name: 'Hair', icon: 'assets/icon-hair.svg' },
    { id: 'makeup', name: 'Makeup', icon: 'assets/icon-makeup.svg' },
    { id: 'clothing', name: 'Clothing', icon: 'assets/icon-clothing.svg' },
    { id: 'outfits', name: 'Outfits', icon: 'assets/icon-outfits.svg' },
    { id: 'accessories', name: 'Accessories', icon: 'assets/icon-accessories.svg' },
    { id: 'tattoos', name: 'Tattoos', icon: 'assets/icon-tattoo.svg' }
];

const SUBCATEGORIES = {
    features: [
        { id: 'eyebrows', name: 'Eyebrows', icon: 'assets/icon-features.svg', count: 34 },
        { id: 'eyes', name: 'Eyes', icon: 'assets/icon-features.svg', count: 12 },
        { id: 'nose', name: 'Nose', icon: 'assets/icon-features.svg' },
        { id: 'cheeks', name: 'Cheeks', icon: 'assets/icon-features.svg' },
        { id: 'lips', name: 'Lips', icon: 'assets/icon-features.svg' },
        { id: 'jaw', name: 'Jaw', icon: 'assets/icon-features.svg' },
        { id: 'chin', name: 'Chin', icon: 'assets/icon-features.svg' }
    ],
    hair: [
        { id: 'hairstyle', name: 'Hairstyle', icon: 'assets/icon-hair.svg', count: 78 },
        { id: 'beard', name: 'Beard', icon: 'assets/icon-hair.svg', count: 36 }
    ],
    makeup: [
        { id: 'lipstick', name: 'Lipstick', icon: 'assets/icon-makeup.svg', count: 10 },
        { id: 'blush', name: 'Blush', icon: 'assets/icon-makeup.svg', count: 7 }
    ],
    clothing: [
        { id: 'hats', name: 'Hats', icon: 'assets/icon-hat.svg', count: 150 },
        { id: 'masks', name: 'Masks', icon: 'assets/icon-mask.svg', count: 200 },
        { id: 'glasses', name: 'Glasses', icon: 'assets/icon-glasses.svg', count: 40 },
        { id: 'tops', name: 'Tops', icon: 'assets/icon-top.svg', count: 400 },
        { id: 'undershirts', name: 'Undershirts', icon: 'assets/icon-top.svg', count: 200 },
        { id: 'arms', name: 'Arms', icon: 'assets/icon-arms.svg', count: 20, hiddenItems: [3,7,9,10,13] },
        { id: 'pants', name: 'Pants', icon: 'assets/icon-pants.svg', count: 150 },
        { id: 'backpacks', name: 'Backpacks', icon: 'assets/icon-backpack.svg', count: 100 },
        { id: 'shoes', name: 'Shoes', icon: 'assets/icon-shoes.svg', count: 120 }
    ],
    accessories: [
        { id: 'watches', name: 'Watches', icon: 'assets/icon-watch.svg', count: 40 },
        { id: 'bracelets', name: 'Bracelets', icon: 'assets/icon-bracelet.svg', count: 20 },
        { id: 'earrings', name: 'Earrings', icon: 'assets/icon-earring.svg', count: 40 }
    ],
    tattoos: [
        { id: 'ZONE_TORSO',     name: 'Torso',     icon: 'assets/icon-tattoo.svg' },
        { id: 'ZONE_LEFT_ARM',  name: 'Left Arm',  icon: 'assets/icon-tattoo.svg' },
        { id: 'ZONE_RIGHT_ARM', name: 'Right Arm', icon: 'assets/icon-tattoo.svg' },
        { id: 'ZONE_HEAD',      name: 'Head',       icon: 'assets/icon-tattoo.svg' },
        { id: 'ZONE_LEFT_LEG',  name: 'Left Leg',  icon: 'assets/icon-tattoo.svg' },
        { id: 'ZONE_RIGHT_LEG', name: 'Right Leg', icon: 'assets/icon-tattoo.svg' },
        { id: 'ZONE_HAIR',      name: 'Hair',       icon: 'assets/icon-tattoo.svg' }
    ]
};

const CATEGORY_CONTENT = {
    identity: {
        sections: [
            { id: 'gender', title: 'Gender', type: 'items', count: 2 }
        ],
        sliders: [
            { id: 'bodyHeight', label: 'Height', prominent: true }
        ]
    },
    heritage: {
        sections: [
            { id: 'mother', title: 'Mother', type: 'items', count: 45 },
            { id: 'father', title: 'Father', type: 'items', count: 45 }
        ],
        sliders: [
            { id: 'resemblance', label: 'Resemblance' },
            { id: 'skinTone', label: 'Skin Tone' }
        ]
    },
    features: {
        subcategoryContent: {
            eyebrows: {
                sections: [{ id: 'eyebrows', title: 'Eyebrows', type: 'items', count: 34 }],
                sliders: [
                    { id: 'eyebrowHeight', label: 'Eyebrow Height' },
                    { id: 'eyebrowDepth', label: 'Eyebrow Depth' }
                ],
                controls: [
                    { id: 'eyebrowColor', label: 'Eyebrow Color', type: 'color', min: 0, max: 63 }
                ]
            },
            eyes: {
                sections: [{ id: 'eyes', title: 'Eyes', type: 'items', count: 12 }],
                sliders: [
                    { id: 'eyeOpening', label: 'Eye Opening' }
                ]
            },
            nose: {
                sliders: [
                    { id: 'noseWidth',  label: 'Nose Width' },
                    { id: 'noseHeight', label: 'Nose Height' },
                    { id: 'noseBridge', label: 'Nose Bridge' },
                    { id: 'noseTip',    label: 'Nose Tip' },
                    { id: 'noseTwist',  label: 'Nose Twist' }
                ]
            },
            cheeks: {
                sliders: [
                    { id: 'cheekboneHeight', label: 'Cheekbone Height' },
                    { id: 'cheekboneWidth',  label: 'Cheekbone Width' },
                    { id: 'cheeksWidth',     label: 'Cheeks Width' }
                ]
            },
            lips: {
                sliders: [
                    { id: 'chestSize', label: 'Lip Thickness' }
                ]
            },
            jaw: {
                sliders: [
                    { id: 'waistSize', label: 'Jaw Width' },
                    { id: 'hipSize',   label: 'Jaw Length' }
                ]
            },
            chin: {
                sliders: [
                    { id: 'armSize',      label: 'Chin Height' },
                    { id: 'chinDepth',    label: 'Chin Depth' },
                    { id: 'chinWidth',    label: 'Chin Width' },
                    { id: 'chinHoleSize', label: 'Chin Hole Size' }
                ]
            }
        }
    },
    body: {
        sliders: [
            { id: 'bodyWeight',  label: 'Body Weight' },
            { id: 'bodyHeight',  label: 'Height' }
        ]
    },
    hair: {
        subcategoryContent: {
            hairstyle: {
                sections: [{ id: 'hairstyle', title: 'Hairstyle', type: 'items', count: 78 }],
                controls: [
                    { id: 'hairColor',     label: 'Hair Color', type: 'color', min: 0, max: 63 },
                    { id: 'hairHighlight', label: 'Highlight',  type: 'color', min: 0, max: 63 }
                ]
            },
            beard: {
                sections: [{ id: 'beard', title: 'Beard', type: 'items', count: 36 }],
                sliders: [
                    { id: 'beardOpacity', label: 'Beard Opacity' }
                ],
                controls: [
                    { id: 'beardColor', label: 'Beard Color', type: 'color', min: 0, max: 63 }
                ]
            }
        }
    },
    makeup: {
        subcategoryContent: {
            lipstick: {
                sections: [{ id: 'lipstick', title: 'Lipstick', type: 'items', count: 10 }],
                sliders: [
                    { id: 'lipstickOpacity', label: 'Lipstick Opacity' }
                ],
                controls: [
                    { id: 'lipstickColor', label: 'Lipstick Color', type: 'color', min: 0, max: 63 }
                ]
            },
            blush: {
                sections: [{ id: 'blush', title: 'Blush', type: 'items', count: 7 }],
                sliders: [
                    { id: 'blushOpacity', label: 'Blush Opacity' }
                ],
                controls: [
                    { id: 'blushColor', label: 'Blush Color', type: 'color', min: 0, max: 63 }
                ]
            }
        }
    },
    clothing: {
        sections: [
            { id: 'items', title: 'Items', type: 'items', count: 155 }
        ],
        sliders: [
            { id: 'itemOpacity', label: 'Opacity' }
        ],
        controls: [
            { id: 'texture', label: 'Texture', type: 'number', min: 0, max: 15 },
            { id: 'palette', label: 'Palette', type: 'number', min: 0, max: 15 }
        ]
    },
    accessories: {
        sections: [
            { id: 'items', title: 'Items', type: 'items', count: 45 }
        ],
        controls: [
            { id: 'texture', label: 'Texture', type: 'number', min: 0, max: 15 },
            { id: 'palette', label: 'Palette', type: 'number', min: 0, max: 15 }
        ]
    },
    tattoos: {
        type: 'tattoo'  // special renderer — uses tattooList data, not numeric counts
    },
    outfits: {
        type: 'outfits'  // special renderer — saved outfit list, not numeric counts
    }
};

let state = {
    activeCategory: 'identity',
    activeSubcategory: null,
    selections: {},
    sliders: {},
    numbers: {},
    expanded: {}
};

let loadedIcons = {};

const container = document.getElementById('container');
const categoryTabs = document.getElementById('categoryTabs');
const subcategoryTabs = document.getElementById('subcategoryTabs');
const optionsPanel = document.getElementById('optionsPanel');
const detailPanel = document.getElementById('detailPanel');
const saveBtn = document.getElementById('saveBtn');
const scrollbarThumb = document.getElementById('scrollbarThumb');

async function loadIcon(path) {
    if (loadedIcons[path]) return loadedIcons[path];
    try {
        const response = await fetch(path);
        const svg = await response.text();
        loadedIcons[path] = svg;
        return svg;
    } catch (e) {
        return '';
    }
}

async function init() {
    await preloadIcons();
    initializeDefaults();
    renderCategoryTabs();
    renderContent();
    bindEvents();
    updateProgress();
}

// Pre-fetch CDN images in background so they're browser-cached before the user scrolls to them.
// Runs in small batches to avoid flooding the network.
function preloadCDNImages() {
    const BATCH_SIZE = 20;
    const urls = [];

    // Collect all possible image URLs for current gender
    for (const [sectionId, mapping] of Object.entries(IMAGE_MAPPING)) {
        // Find max count from CATEGORY_CONTENT
        let maxCount = 0;
        for (const cat of Object.values(CATEGORY_CONTENT)) {
            if (cat.sections) {
                for (const s of cat.sections) {
                    if (`${Object.keys(CATEGORY_CONTENT).find(k => CATEGORY_CONTENT[k] === cat)}_${s.id}` === sectionId) {
                        maxCount = s.count;
                    }
                }
            }
            if (cat.subcategoryContent) {
                for (const [subId, sub] of Object.entries(cat.subcategoryContent)) {
                    if (sub.sections) {
                        for (const s of sub.sections) {
                            const catId = Object.keys(CATEGORY_CONTENT).find(k => CATEGORY_CONTENT[k] === cat);
                            if (`${catId}_${s.id}` === sectionId) {
                                maxCount = s.count;
                            }
                        }
                    }
                }
            }
        }
        if (maxCount === 0) maxCount = 200; // fallback for clothing/accessories subcategories

        for (let i = 0; i < maxCount; i++) {
            const url = getImageUrl(sectionId, i);
            if (url && url.startsWith('http')) urls.push(url);
        }
    }

    // Load in batches to avoid network flood
    let idx = 0;
    function loadBatch() {
        const batch = urls.slice(idx, idx + BATCH_SIZE);
        if (batch.length === 0) return;
        batch.forEach(url => {
            const img = new Image();
            img.src = url;
        });
        idx += BATCH_SIZE;
        setTimeout(loadBatch, 100);
    }
    loadBatch();
}

async function preloadIcons() {
    const iconPaths = [];
    CATEGORIES.forEach(cat => iconPaths.push(cat.icon));
    Object.values(SUBCATEGORIES).forEach(subs => {
        subs.forEach(sub => iconPaths.push(sub.icon));
    });
    iconPaths.push('assets/icon-expand.svg', 'assets/icon-prev.svg', 'assets/icon-next.svg');
    await Promise.all(iconPaths.map(path => loadIcon(path)));
}

function initializeDefaults() {
    CATEGORIES.forEach(cat => {
        const content = CATEGORY_CONTENT[cat.id];
        if (content && content.type !== 'tattoo' && content.type !== 'outfits') {
            if (content.sections) {
                content.sections.forEach((section, idx) => {
                    state.expanded[`${cat.id}_${section.id}`] = true;
                    state.selections[`${cat.id}_${section.id}`] = 0;
                });
            }
            if (content.subcategoryContent) {
                Object.entries(content.subcategoryContent).forEach(([subId, subContent]) => {
                    if (subContent.sections) {
                        subContent.sections.forEach(section => {
                            state.expanded[`${cat.id}_${section.id}`] = true;
                            state.selections[`${cat.id}_${section.id}`] = 0;
                        });
                    }
                    if (subContent.sliders) {
                        subContent.sliders.forEach(slider => {
                            state.sliders[slider.id] = 50;
                        });
                    }
                    if (subContent.controls) {
                        subContent.controls.forEach(control => {
                            state.numbers[control.id] = control.min || 0;
                        });
                    }
                });
            }
            if (content.sliders) {
                content.sliders.forEach(slider => {
                    state.sliders[slider.id] = 50;
                });
            }
            if (content.controls) {
                content.controls.forEach(control => {
                    state.numbers[control.id] = control.min || 0;
                });
            }
        }
    });
}

function getVisibleCategories() {
    // No store context (character creator / /tc): show everything except
    // tattoos, and only show Outfits when the feature is enabled (config sent).
    if (!allowedTabs) return CATEGORIES.filter(cat => cat.id !== 'tattoos' && (cat.id !== 'outfits' || outfitConfig));
    return CATEGORIES.filter(cat => allowedTabs.includes(cat.id));
}

function renderCategoryTabs() {
    categoryTabs.innerHTML = '';
    getVisibleCategories().forEach((cat) => {
        const tab = document.createElement('div');
        tab.className = `category-tab ${cat.id === state.activeCategory ? 'active' : ''}`;
        tab.dataset.category = cat.id;
        const iconSvg = loadedIcons[cat.icon] || '';
        tab.innerHTML = `<span class="category-icon">${iconSvg}</span><span class="category-tab-label">${t('cat_' + cat.id, cat.name)}</span>`;
        tab.addEventListener('click', () => selectCategory(cat.id));
        categoryTabs.appendChild(tab);
    });
}

function renderDetailPanel(sliders, controls) {
    detailPanel.innerHTML = '';
    const hasContent = (sliders && sliders.length > 0) || (controls && controls.length > 0);
    if (!hasContent) {
        detailPanel.classList.add('hidden');
        return;
    }
    detailPanel.classList.remove('hidden');
    if (sliders) {
        sliders.forEach(slider => {
            detailPanel.appendChild(createSliderSection(slider.label, slider.id));
        });
    }
    if (controls && controls.length > 0) {
        detailPanel.appendChild(createNumberControls(controls));
    }
}

function renderSubcategoryTabs() {
    subcategoryTabs.innerHTML = '';
    let subs = SUBCATEGORIES[state.activeCategory];
    if (!subs || subs.length === 0) {
        subcategoryTabs.style.display = 'none';
        return;
    }
    // Filter subcategories if allowedSubs is set
    if (allowedSubs) {
        subs = subs.filter(s => allowedSubs.includes(s.id));
    }
    // Barber store: only show eyebrows in features
    if (currentStoreType === 'barber' && state.activeCategory === 'features') {
        subs = subs.filter(s => s.id === 'eyebrows');
    }
    subcategoryTabs.style.display = 'flex';
    if (!state.activeSubcategory || !subs.find(s => s.id === state.activeSubcategory)) {
        state.activeSubcategory = subs[0].id;
    }
    const useLabelPills = state.activeCategory === 'tattoos' || state.activeCategory === 'features' || state.activeCategory === 'hair' || state.activeCategory === 'makeup';
    subs.forEach((sub) => {
        const tab = document.createElement('div');
        tab.className = `subcategory-tab ${useLabelPills ? 'subcategory-tab--labeled' : ''} ${state.activeSubcategory === sub.id ? 'active' : ''}`;
        tab.dataset.subcategory = sub.id;
        const iconSvg = loadedIcons[sub.icon] || '';
        const subLabel = t('sub_' + sub.id, sub.name);
        tab.innerHTML = useLabelPills ? `<span class="subcategory-label">${subLabel}</span>` : `<span class="subcategory-icon">${iconSvg}</span>`;
        tab.addEventListener('click', () => selectSubcategory(sub.id));
        subcategoryTabs.appendChild(tab);
    });
}

function renderContent() {
    renderSubcategoryTabs();
    renderOptionsPanel();
}

function renderOptionsPanel() {
    optionsPanel.innerHTML = '';
    let detailSliders = null;
    let detailControls = null;

    const content = CATEGORY_CONTENT[state.activeCategory];

    // Subcategory-based content (features, hair, makeup, etc.)
    if (content && content.subcategoryContent) {
        const subId = state.activeSubcategory;
        const subContent = subId && content.subcategoryContent[subId];
        if (subContent) {
            if (subContent.sections) {
                subContent.sections.forEach(section => {
                    const sectionKey = `${state.activeCategory}_${section.id}`;
                    const sectionEl = createItemSection(section.title, sectionKey, section.count, section.hiddenItems);
                    optionsPanel.appendChild(sectionEl);
                });
            }
            // Sliders without item sections go in main panel (e.g. nose/cheeks/jaw sliders)
            if (!subContent.sections && subContent.sliders) {
                subContent.sliders.forEach(slider => {
                    optionsPanel.appendChild(createSliderSection(slider.label, slider.id));
                });
            } else {
                detailSliders = subContent.sliders;
            }
            detailControls = subContent.controls;
        }
        renderDetailPanel(detailSliders, detailControls);
        requestAnimationFrame(() => { updateOptionsPanelHeight(); updateScrollbar(); });
        return;
    }

    // Tattoo category — special renderer
    if (content && content.type === 'tattoo') {
        const zoneId = state.activeSubcategory || 'ZONE_TORSO';
        const tattooPanel = createTattooPanel(zoneId);
        optionsPanel.appendChild(tattooPanel);
        renderDetailPanel(null, null);
        requestAnimationFrame(() => { updateOptionsPanelHeight(); updateScrollbar(); });
        return;
    }

    // Outfits category — saved outfit list (no numeric item grid)
    if (content && content.type === 'outfits') {
        optionsPanel.appendChild(createOutfitsPanel());
        renderDetailPanel(null, null);
        requestAnimationFrame(() => { updateOptionsPanelHeight(); updateScrollbar(); });
        return;
    }

    // Subcategory with item grid (clothing, accessories)
    const subs = SUBCATEGORIES[state.activeCategory];
    if (subs && subs.length > 0 && state.activeSubcategory) {
        const activeSub = subs.find(s => s.id === state.activeSubcategory);
        if (activeSub) {
            const sectionKey = `${state.activeCategory}_${activeSub.id}`;
            const sectionEl = createItemSection(t('sub_' + activeSub.id, activeSub.name), sectionKey, activeSub.count, activeSub.hiddenItems);
            optionsPanel.appendChild(sectionEl);
            detailControls = content && content.controls;
            renderDetailPanel(null, detailControls);
            requestAnimationFrame(() => { updateOptionsPanelHeight(); updateScrollbar(); });
            return;
        }
    }

    if (!content) {
        renderDetailPanel(null, null);
        return;
    }

    // Default: sections in main panel, sliders/controls in detail panel
    if (content.sections) {
        content.sections.forEach(section => {
            const sectionKey = `${state.activeCategory}_${section.id}`;
            const sectionEl = createItemSection(section.title, sectionKey, section.count);
            optionsPanel.appendChild(sectionEl);
        });
    }

    // Heritage/body sliders stay in main panel (no item selection needed)
    if (content.sliders) {
        content.sliders.forEach(slider => {
            optionsPanel.appendChild(createSliderSection(slider.label, slider.id, slider.prominent));
        });
    }

    // Custom peds grid (only in identity category when data is available)
    if (state.activeCategory === 'identity' && customPedsData && customPedsData.length > 0) {
        optionsPanel.appendChild(createCustomPedSection());
    }

    renderDetailPanel(null, content.controls);
    requestAnimationFrame(() => { updateOptionsPanelHeight(); updateScrollbar(); });
}

function addNoImageContent(item, displayNum) {
    const numEl = document.createElement('span');
    numEl.className = 'card-index';
    numEl.textContent = displayNum;
    const labelEl = document.createElement('span');
    labelEl.className = 'card-label';
    labelEl.textContent = t('card_variant', 'variant');
    item.appendChild(numEl);
    item.appendChild(labelEl);
}

function createItemSection(title, sectionId, itemCount, hiddenItems, cappedGrid) {
    const section = document.createElement('div');
    section.className = 'option-section';

    const header = document.createElement('div');
    header.className = 'section-header expanded';
    header.innerHTML = `
        <div class="section-title">
            <div class="status-dot"></div>
            <span>${t('ui_section_' + sectionId, title)}</span>
        </div>
    `;

    const content = document.createElement('div');
    content.className = 'section-content visible';
    content.id = `content-${sectionId}`;

    const grid = document.createElement('div');
    grid.className = cappedGrid ? 'items-grid items-grid--capped' : 'items-grid';

    const selectedIndex = state.selections[sectionId] || 0;
    const hiddenSet = hiddenItems ? new Set(hiddenItems) : null;

    // Extend item range for add-on clothing drawables (Config.CustomClothing.count).
    const effectiveCount = getExtendedCount(sectionId, itemCount);

    let displayNum = 0;
    for (let i = 0; i < effectiveCount; i++) {
        if (hiddenSet && hiddenSet.has(i)) continue;
        displayNum++;
        const num = displayNum; // capture for closure
        const item = document.createElement('div');
        item.className = `item-card ${i === selectedIndex ? 'active' : ''}`;
        item.dataset.index = i;

        // Native browser tooltip for custom-labeled drawables (add-on clothing).
        const customLabel = getCustomLabel(sectionId, i);
        if (customLabel) item.title = customLabel;

        const imageUrl = getImageUrl(sectionId, i);
        if (imageUrl) {
            item.classList.add('has-image');
            const img = document.createElement('img');
            img.alt = '';
            img.onload = function() {
                this.classList.add('loaded');
            };
            img.onerror = function() {
                this.style.display = 'none';
                item.classList.remove('has-image');
                item.classList.add('no-image');
                addNoImageContent(item, num);
            };
            img.src = imageUrl;
            item.appendChild(img);
        } else {
            item.classList.add('no-image');
            addNoImageContent(item, num);
        }

        item.addEventListener('click', () => selectItem(sectionId, i));
        grid.appendChild(item);
    }

    content.appendChild(grid);
    section.appendChild(header);
    section.appendChild(content);
    return section;
}

// ── Custom Ped Selector ─────────────────────────────────────────────
let customPedActiveCategory = null;
let selectedCustomPed = null;

function createCustomPedSection() {
    const section = document.createElement('div');
    section.className = 'option-section custom-ped-section';

    // Group peds by category
    const categories = {};
    customPedsData.forEach(ped => {
        if (!categories[ped.category]) categories[ped.category] = [];
        categories[ped.category].push(ped);
    });
    const categoryNames = Object.keys(categories).sort();

    // Default to first category
    if (!customPedActiveCategory || !categories[customPedActiveCategory]) {
        customPedActiveCategory = categoryNames[0];
    }

    // Header
    const header = document.createElement('div');
    header.className = 'section-header expanded';
    header.innerHTML = `
        <div class="section-title">
            <div class="status-dot"></div>
            <span>${t('custom_ped', 'Custom Ped')}</span>
            <span class="ped-count">${tf('ped_models_count', '%d models', customPedsData.length)}</span>
        </div>
    `;

    // Category filter tabs
    const filterRow = document.createElement('div');
    filterRow.className = 'ped-category-tabs';
    categoryNames.forEach(catName => {
        const btn = document.createElement('button');
        btn.className = 'ped-cat-btn' + (catName === customPedActiveCategory ? ' active' : '');
        btn.textContent = catName;
        btn.addEventListener('click', () => {
            customPedActiveCategory = catName;
            // Re-render just this section
            const parent = section.parentNode;
            if (parent) {
                const newSection = createCustomPedSection();
                parent.replaceChild(newSection, section);
                requestAnimationFrame(() => { updateOptionsPanelHeight(); updateScrollbar(); });
            }
        });
        filterRow.appendChild(btn);
    });

    // Ped grid
    const grid = document.createElement('div');
    grid.className = 'items-grid items-grid--capped';

    const peds = categories[customPedActiveCategory] || [];
    peds.forEach(ped => {
        const card = document.createElement('div');
        card.className = 'item-card ped-card' + (selectedCustomPed === ped.name ? ' active' : '');
        card.dataset.ped = ped.name;

        const img = document.createElement('img');
        img.loading = 'lazy';
        img.alt = ped.label;
        img.src = `${PED_IMAGE_CDN}/${ped.name}.webp`;
        img.onerror = function() {
            this.style.display = 'none';
            card.classList.add('no-image');
            const numEl = document.createElement('span');
            numEl.className = 'card-index';
            numEl.textContent = ped.label;
            card.appendChild(numEl);
        };
        img.onload = function() { this.classList.add('loaded'); };
        card.appendChild(img);

        const label = document.createElement('span');
        label.className = 'ped-card-label';
        label.textContent = ped.label;
        card.appendChild(label);

        card.addEventListener('click', () => {
            selectedCustomPed = ped.name;
            // Update active state visually
            grid.querySelectorAll('.ped-card').forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            // Tell Lua to change the ped model
            sendToGame('selectCustomPed', { model: ped.name });
        });

        grid.appendChild(card);
    });

    const content = document.createElement('div');
    content.className = 'section-content visible';
    content.appendChild(filterRow);
    content.appendChild(grid);

    section.appendChild(header);
    section.appendChild(content);
    return section;
}

function createSliderSection(label, sliderId, prominent) {
    const section = document.createElement('div');
    section.className = prominent ? 'slider-section slider-section--prominent' : 'slider-section';
    const value = state.sliders[sliderId] !== undefined ? state.sliders[sliderId] : 50;

    if (prominent) {
        // Prominent slider: title bar + large value display + wider track
        const displayValue = Math.round(0.85 * 100 + (value / 100) * 30);
        section.innerHTML = `
            <div class="slider-prominent-header">
                <span class="slider-prominent-label">${t('ui_' + sliderId, label)}</span>
                <span class="slider-prominent-value" id="prominent-${sliderId}">${displayValue}%</span>
            </div>
            <div class="slider-track slider-track--prominent" data-slider="${sliderId}">
                <div class="slider-fill" style="width: ${value}%"></div>
                <div class="slider-thumb" style="left: ${value}%"></div>
            </div>
        `;
    } else {
        section.innerHTML = `
            <div class="slider-header">
                <div class="status-dot"></div>
                <span>${t('ui_' + sliderId, label)}</span>
            </div>
            <div class="slider-track" data-slider="${sliderId}">
                <div class="slider-fill" style="width: ${value}%"></div>
                <div class="slider-thumb" style="left: ${value}%"></div>
            </div>
        `;
    }

    const track = section.querySelector('.slider-track');
    track.addEventListener('mousedown', (e) => startSliderDrag(e, sliderId));
    return section;
}

// GTA V hair color palette (indices 0–63)
const GTA_HAIR_COLORS = [
    '#1c1f21','#272a2c','#312e2c','#35261c','#4b321f','#5c3b24','#6d4c35','#6b503b',
    '#765c45','#7f684e','#99815d','#a79369','#af9c70','#bba063','#d6b97b','#dac38e',
    '#9f7f59','#845039','#682b1f','#61120c','#640f0a','#7c140f','#a02e19','#b64b28',
    '#a2502f','#aa4e2b','#626262','#808080','#aaaaaa','#c5c5c5','#463955','#5a3f6b',
    '#763c76','#ed74e3','#eb4b93','#f299bc','#04959e','#025f86','#023974','#3fa16a',
    '#217c61','#185c55','#b6c034','#70a90b','#439d13','#dcb857','#e5b103','#e69102',
    '#f28831','#fb8057','#e28b58','#d1593c','#ce3120','#ad0903','#880302','#1f1814',
    '#291f19','#2e221b','#37291e','#2e2218','#231b15','#020202','#706c66','#9d7a50'
];

function createColorPicker(control) {
    const wrapper = document.createElement('div');
    wrapper.className = 'color-picker-control';

    const label = document.createElement('span');
    label.className = 'control-label';
    label.textContent = t('ui_' + control.id, control.label);
    wrapper.appendChild(label);

    const grid = document.createElement('div');
    grid.className = 'color-swatch-grid';

    const current = state.numbers[control.id] !== undefined ? state.numbers[control.id] : control.min;

    for (let i = control.min; i <= control.max; i++) {
        const swatch = document.createElement('button');
        swatch.className = 'color-swatch' + (i === current ? ' active' : '');
        swatch.style.background = GTA_HAIR_COLORS[i] || '#888';
        swatch.title = i;
        swatch.dataset.index = i;
        swatch.addEventListener('click', () => {
            grid.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('active'));
            swatch.classList.add('active');
            state.numbers[control.id] = i;
            sendToGame('updateNumber', { control: control.id, value: i });
        });
        grid.appendChild(swatch);
    }

    wrapper.appendChild(grid);
    return wrapper;
}

function createNumberControls(controls) {
    const container = document.createElement('div');
    container.className = 'number-controls';

    const prevIcon = loadedIcons['assets/icon-prev.svg'] || '';
    const nextIcon = loadedIcons['assets/icon-next.svg'] || '';

    controls.forEach(control => {
        if (control.type === 'color') {
            container.appendChild(createColorPicker(control));
            return;
        }

        const value = state.numbers[control.id] !== undefined ? state.numbers[control.id] : control.min;
        const controlEl = document.createElement('div');
        controlEl.className = 'number-control';
        controlEl.innerHTML = `
            <span class="control-label">${t('ui_' + control.id, control.label)}</span>
            <div class="control-row">
                <button class="control-btn prev" data-control="${control.id}" data-action="prev">
                    <span class="control-icon">${prevIcon}</span>
                </button>
                <div class="control-value">
                    <span class="current">${value}</span>
                    <span class="max">/${control.max}</span>
                </div>
                <button class="control-btn next" data-control="${control.id}" data-action="next">
                    <span class="control-icon">${nextIcon}</span>
                </button>
            </div>
        `;

        const prevBtn = controlEl.querySelector('.prev');
        const nextBtn = controlEl.querySelector('.next');

        prevBtn.addEventListener('click', () => updateNumber(control.id, -1, control.min, control.max, controlEl));
        nextBtn.addEventListener('click', () => updateNumber(control.id, 1, control.min, control.max, controlEl));

        container.appendChild(controlEl);
    });

    return container;
}

function tattooKey(entry) {
    return entry.collection + ':' + entry.hash;
}

// Hair / micropigmentation overlays use the NUMERIC image set on the CDN
// (tattoo_images/{gender}/{N}.png), indexed by position in the source overlay
// list. Body tattoos use hash-named images; hair maps through this table.
const TATTOO_HAIR_IMAGE_INDEX = {
    male: {
        'FM_Hair_Fuzz': 1, 'MP_Biker_Hair_000_M': 2, 'MP_Biker_Hair_001_M': 3, 'MP_Biker_Hair_002_M': 4,
        'MP_Biker_Hair_003_M': 5, 'MP_Biker_Hair_004_M': 6, 'MP_Biker_Hair_005_M': 7, 'MP_Biker_Hair_006_M': 8,
        'FM_Bus_M_Hair_000_a': 9, 'FM_Bus_M_Hair_000_b': 10, 'FM_Bus_M_Hair_000_c': 11, 'FM_Bus_M_Hair_000_d': 12,
        'FM_Bus_M_Hair_000_e': 13, 'FM_Bus_M_Hair_001_a': 14, 'FM_Bus_M_Hair_001_b': 15, 'FM_Bus_M_Hair_001_c': 16,
        'FM_Bus_M_Hair_001_d': 17, 'FM_Bus_M_Hair_001_e': 18, 'MP_Gunrunning_Hair_M_000_M': 19, 'MP_Gunrunning_Hair_M_001_M': 20,
        'FM_Hip_M_Hair_000_a': 21, 'FM_Hip_M_Hair_000_b': 22, 'FM_Hip_M_Hair_000_c': 23, 'FM_Hip_M_Hair_000_d': 24,
        'FM_Hip_M_Hair_000_e': 25, 'FM_Hip_M_Hair_001_a': 26, 'FM_Hip_M_Hair_001_b': 27, 'FM_Hip_M_Hair_001_c': 28,
        'FM_Hip_M_Hair_001_d': 29, 'FM_Hip_M_Hair_001_e': 30, 'FM_Disc_M_Hair_001_a': 31, 'FM_Disc_M_Hair_001_b': 32,
        'FM_Disc_M_Hair_001_c': 33, 'FM_Disc_M_Hair_001_d': 34, 'FM_Disc_M_Hair_001_e': 35, 'LR_M_Hair_004': 36,
        'LR_M_Hair_005': 37, 'LR_M_Hair_006': 38, 'LR_M_Hair_000': 39, 'LR_M_Hair_001': 40, 'LR_M_Hair_002': 41,
        'LR_M_Hair_003': 42, 'MP_Vinewood_Hair_M_000_M': 43, 'FM_M_Hair_001_a': 44, 'FM_M_Hair_001_b': 45,
        'FM_M_Hair_001_c': 46, 'FM_M_Hair_001_d': 47, 'FM_M_Hair_001_e': 48, 'FM_M_Hair_003_a': 49, 'FM_M_Hair_003_b': 50,
        'FM_M_Hair_003_c': 51, 'FM_M_Hair_003_d': 52, 'FM_M_Hair_003_e': 53, 'FM_M_Hair_006_a': 54, 'FM_M_Hair_006_b': 55,
        'FM_M_Hair_006_c': 56, 'FM_M_Hair_006_d': 57, 'FM_M_Hair_006_e': 58, 'FM_M_Hair_008_a': 59, 'FM_M_Hair_008_b': 60,
        'FM_M_Hair_008_c': 61, 'FM_M_Hair_008_d': 62, 'FM_M_Hair_008_e': 63, 'FM_M_Hair_long_a': 64, 'FM_M_Hair_long_b': 65,
        'FM_M_Hair_long_c': 66, 'FM_M_Hair_long_d': 67, 'FM_M_Hair_long_e': 68, 'NG_F_Hair_013': 69, 'NG_M_Hair_001': 70,
        'NG_M_Hair_002': 71, 'NG_M_Hair_003': 72, 'NG_M_Hair_004': 73, 'NG_M_Hair_005': 74, 'NG_M_Hair_006': 75,
        'NG_M_Hair_007': 76, 'NG_M_Hair_008': 77, 'NG_M_Hair_009': 78, 'NG_M_Hair_011': 79, 'NG_M_Hair_012': 80,
        'NG_M_Hair_013': 81, 'NG_M_Hair_014': 82, 'NG_M_Hair_015': 83, 'NGBus_M_Hair_000': 84, 'NGBus_M_Hair_001': 85,
        'NGHip_M_Hair_000': 86, 'NGHip_M_Hair_001': 87, 'NGInd_M_Hair_000': 88,
    },
    female: {
        'FM_Hair_Fuzz': 1, 'MP_Biker_Hair_000_F': 2, 'MP_Biker_Hair_001_F': 3, 'MP_Biker_Hair_002_F': 4,
        'MP_Biker_Hair_003_F': 5, 'MP_Biker_Hair_004_F': 6, 'MP_Biker_Hair_005_F': 7, 'MP_Biker_Hair_006_F': 8,
        'FM_Bus_F_Hair_a': 9, 'FM_Bus_F_Hair_b': 10, 'FM_Bus_F_Hair_c': 11, 'FM_Bus_F_Hair_d': 12, 'FM_Bus_F_Hair_e': 13,
        'MP_Gunrunning_Hair_F_000_F': 14, 'MP_Gunrunning_Hair_F_001_F': 15, 'FM_Hip_F_Hair_000_a': 16, 'FM_Hip_F_Hair_000_b': 17,
        'FM_Hip_F_Hair_000_c': 18, 'FM_Hip_F_Hair_000_d': 19, 'FM_Hip_F_Hair_000_e': 20, 'FM_F_Hair_017_a': 21,
        'FM_F_Hair_017_b': 22, 'FM_F_Hair_017_c': 23, 'FM_F_Hair_017_d': 24, 'FM_F_Hair_017_e': 25, 'FM_F_Hair_020_a': 26,
        'FM_F_Hair_020_b': 27, 'FM_F_Hair_020_c': 28, 'FM_F_Hair_020_d': 29, 'FM_F_Hair_020_e': 30, 'LR_F_Hair_003': 31,
        'LR_F_Hair_004': 32, 'LR_F_Hair_006': 33, 'LR_F_Hair_000': 34, 'LR_F_Hair_001': 35, 'LR_F_Hair_002': 36,
        'MP_Vinewood_Hair_F_000_F': 37, 'FM_F_Hair_005_a': 38, 'FM_F_Hair_005_b': 39, 'FM_F_Hair_005_c': 40,
        'FM_F_Hair_005_d': 41, 'FM_F_Hair_005_e': 42, 'FM_F_Hair_006_a': 43, 'FM_F_Hair_006_b': 44, 'FM_F_Hair_006_c': 45,
        'FM_F_Hair_006_d': 46, 'FM_F_Hair_006_e': 47, 'FM_F_Hair_013_a': 48, 'FM_F_Hair_013_b': 49, 'FM_F_Hair_013_c': 50,
        'FM_F_Hair_013_d': 51, 'FM_F_Hair_013_e': 52, 'FM_F_Hair_014_a': 53, 'FM_F_Hair_014_b': 54, 'FM_F_Hair_014_c': 55,
        'FM_F_Hair_014_d': 56, 'FM_F_Hair_014_e': 57, 'FM_F_Hair_long_a': 58, 'FM_F_Hair_long_b': 59, 'FM_F_Hair_long_c': 60,
        'FM_F_Hair_long_d': 61, 'FM_F_Hair_long_e': 62, 'NG_F_Hair_001': 63, 'NG_F_Hair_002': 64, 'NG_F_Hair_003': 65,
        'NG_F_Hair_004': 66, 'NG_F_Hair_005': 67, 'NG_F_Hair_006': 68, 'NG_F_Hair_007': 69, 'NG_F_Hair_008': 70,
        'NG_F_Hair_009': 71, 'NG_F_Hair_010': 72, 'NG_F_Hair_011': 73, 'NG_F_Hair_012': 74, 'NG_F_Hair_013': 75,
        'NG_M_Hair_014': 76, 'NG_M_Hair_015': 77, 'NGBea_F_Hair_000': 78, 'NGBea_F_Hair_001': 79, 'NGBus_F_Hair_000': 80,
        'NGBus_F_Hair_001': 81, 'NGHip_F_Hair_000': 82, 'NGInd_F_Hair_000': 83,
    }
};

function createTattooPanel(zoneId) {
    const panel = document.createElement('div');
    panel.className = 'option-section';

    const entries = (tattooList && tattooList[zoneId]) ? tattooList[zoneId] : [];

    if (entries.length === 0) {
        panel.innerHTML = `<div class="tattoo-empty">${t('tattoo_empty', 'No tattoos available for this zone.')}</div>`;
        return panel;
    }

    const countActive = () => entries.reduce((n, e) => n + (activeTattoos[tattooKey(e)] ? 1 : 0), 0);

    // Toolbar: live search + active-count badge + clear all
    const toolbar = document.createElement('div');
    toolbar.className = 'tattoo-toolbar';

    const search = document.createElement('input');
    search.type = 'text';
    search.className = 'admin-input tattoo-search';
    search.placeholder = t('tattoo_search_ph', 'Search tattoos...');

    const activeBadge = document.createElement('span');
    activeBadge.className = 'tattoo-active-count';

    const clearBtn = document.createElement('button');
    clearBtn.className = 'tattoo-clear-btn';
    clearBtn.textContent = t('tattoo_clear_all', 'CLEAR ALL TATTOOS');

    toolbar.appendChild(search);
    toolbar.appendChild(activeBadge);
    toolbar.appendChild(clearBtn);
    panel.appendChild(toolbar);

    const grid = document.createElement('div');
    grid.className = 'tattoo-grid';
    panel.appendChild(grid);

    const noResults = document.createElement('div');
    noResults.className = 'tattoo-empty tattoo-no-results';
    noResults.style.display = 'none';
    noResults.textContent = t('tattoo_no_results', 'No tattoos match your search.');
    panel.appendChild(noResults);

    function updateBadge() {
        activeBadge.textContent = tf('tattoo_active_count', '%d active', countActive());
    }

    function buildGrid(query) {
        grid.innerHTML = '';
        const q = (query || '').trim().toLowerCase();
        let shown = 0;
        entries.forEach(entry => {
            if (q && !(entry.label || '').toLowerCase().includes(q)) return;
            shown++;
            const key = tattooKey(entry);
            const card = document.createElement('div');
            card.className = 'tattoo-card' + (activeTattoos[key] ? ' active' : '');
            card.dataset.key = key;

            // Thumbnail from the CDN, keyed by the GTA overlay hash (same naming
            // nation_tattoos uses): tattoo_images/{gender}/{hash}.png. Cards
            // whose image is missing fall back to the text-only layout.
            if (entry.hash) {
                const thumb = document.createElement('img');
                thumb.className = 'tattoo-thumb';
                thumb.alt = '';
                thumb.loading = 'lazy';
                thumb.onerror = function () { this.remove(); card.classList.add('tattoo-card--noimg'); };
                // Hair/micropigmentation overlays use the numeric image set; body
                // tattoos are hash-named. Fall back to hash if not a known overlay.
                const hairIdx = TATTOO_HAIR_IMAGE_INDEX[currentGender] && TATTOO_HAIR_IMAGE_INDEX[currentGender][entry.hash];
                const file = hairIdx ? hairIdx : entry.hash;
                thumb.src = `${CDN_BASE}/tattoo_images/${currentGender}/${file}.png`;
                card.appendChild(thumb);
            }

            const label = document.createElement('span');
            label.className = 'tattoo-label';
            label.textContent = entry.label;

            const toggle = document.createElement('button');
            toggle.className = 'tattoo-toggle-btn';
            toggle.textContent = activeTattoos[key] ? t('tattoo_remove', 'REMOVE') : t('tattoo_add', 'ADD');
            toggle.addEventListener('click', () => {
                if (activeTattoos[key]) {
                    delete activeTattoos[key];
                    card.classList.remove('active');
                    toggle.textContent = t('tattoo_add', 'ADD');
                    sendToGame('removeTattoo', { collection: entry.collection, hash: entry.hash });
                } else {
                    activeTattoos[key] = true;
                    card.classList.add('active');
                    toggle.textContent = t('tattoo_remove', 'REMOVE');
                    sendToGame('addTattoo', { collection: entry.collection, hash: entry.hash });
                }
                updateBadge();
            });

            card.appendChild(label);
            card.appendChild(toggle);
            grid.appendChild(card);
        });
        noResults.style.display = shown === 0 ? 'block' : 'none';
    }

    clearBtn.addEventListener('click', () => {
        activeTattoos = {};
        panel.querySelectorAll('.tattoo-card.active').forEach(c => c.classList.remove('active'));
        panel.querySelectorAll('.tattoo-toggle-btn').forEach(b => { b.textContent = t('tattoo_add', 'ADD'); });
        updateBadge();
        sendToGame('clearTattoos', {});
    });

    search.addEventListener('input', () => buildGrid(search.value));
    updateBadge();
    buildGrid('');

    return panel;
}

// ── Outfits panel ───────────────────────────────────────────────────
async function fetchOutfits() {
    const list = await sendToGameAsync('outfitListRequest', {});
    outfitsData = Array.isArray(list) ? list : [];
    if (state.activeCategory === 'outfits') renderOptionsPanel();
}

function createOutfitsPanel() {
    const panel = document.createElement('div');
    panel.className = 'option-section';

    // Save-current-look row
    const saveRow = document.createElement('div');
    saveRow.className = 'outfit-save-row';

    const nameInput = document.createElement('input');
    nameInput.type = 'text';
    nameInput.className = 'admin-input outfit-name-input';
    nameInput.placeholder = t('outfit_name_ph', 'Outfit name...');
    nameInput.maxLength = 30;

    const saveBtn = document.createElement('button');
    saveBtn.className = 'tattoo-clear-btn outfit-save-btn';
    const saveCost = (outfitConfig && outfitConfig.saveCost) ? outfitConfig.saveCost : 0;
    saveBtn.textContent = saveCost > 0
        ? tf('outfit_cost_save', 'SAVE OUTFIT (%s)', formatMoney(saveCost))
        : t('outfit_save_btn', 'SAVE OUTFIT');

    const doSave = () => {
        const name = (nameInput.value || '').trim();
        if (!name) { nameInput.focus(); return; }
        saveBtn.disabled = true;
        sendToGame('outfitSave', { name: name });
        nameInput.value = '';
    };
    saveBtn.addEventListener('click', doSave);
    nameInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') doSave(); });

    saveRow.appendChild(nameInput);
    saveRow.appendChild(saveBtn);
    panel.appendChild(saveRow);

    // Cap line
    if (outfitConfig && outfitConfig.max) {
        const cap = document.createElement('div');
        cap.className = 'outfit-cap';
        cap.textContent = tf('outfit_count', '%d / %d', outfitsData ? outfitsData.length : 0, outfitConfig.max);
        panel.appendChild(cap);
    }

    // List (lazy-load on first open)
    if (!outfitsData) {
        const loading = document.createElement('div');
        loading.className = 'tattoo-empty';
        loading.textContent = t('outfit_loading', 'Loading...');
        panel.appendChild(loading);
        fetchOutfits();
        return panel;
    }
    if (outfitsData.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'tattoo-empty';
        empty.textContent = t('outfit_empty', "You haven't saved any outfits yet.");
        panel.appendChild(empty);
        return panel;
    }

    const grid = document.createElement('div');
    grid.className = 'tattoo-grid outfit-grid';
    const applyCost = (outfitConfig && outfitConfig.applyCost) ? outfitConfig.applyCost : 0;
    const shareEnabled = outfitConfig && outfitConfig.shareEnabled;

    outfitsData.forEach(outfit => {
        const card = document.createElement('div');
        card.className = 'tattoo-card outfit-card';

        const label = document.createElement('span');
        label.className = 'tattoo-label outfit-label';
        label.textContent = outfit.name;
        card.appendChild(label);

        const actions = document.createElement('div');
        actions.className = 'outfit-actions';

        const applyBtn = document.createElement('button');
        applyBtn.className = 'tattoo-toggle-btn outfit-apply-btn';
        applyBtn.textContent = applyCost > 0
            ? tf('outfit_cost_apply', 'WEAR (%s)', formatMoney(applyCost))
            : t('outfit_apply', 'WEAR');
        applyBtn.addEventListener('click', () => sendToGame('outfitApply', { id: outfit.id }));
        actions.appendChild(applyBtn);

        if (shareEnabled) {
            const shareBtn = document.createElement('button');
            shareBtn.className = 'outfit-mini-btn';
            shareBtn.textContent = t('outfit_share', 'SHARE');
            shareBtn.addEventListener('click', () => openSharePicker(outfit));
            actions.appendChild(shareBtn);
        }

        const renameBtn = document.createElement('button');
        renameBtn.className = 'outfit-mini-btn';
        renameBtn.textContent = t('outfit_rename', 'RENAME');
        renameBtn.addEventListener('click', () => startOutfitRename(card, outfit));
        actions.appendChild(renameBtn);

        const delBtn = document.createElement('button');
        delBtn.className = 'outfit-mini-btn danger';
        delBtn.textContent = t('outfit_delete', 'DELETE');
        delBtn.addEventListener('click', () => sendToGame('outfitDelete', { id: outfit.id }));
        actions.appendChild(delBtn);

        card.appendChild(actions);
        grid.appendChild(card);
    });

    panel.appendChild(grid);
    return panel;
}

// Inline rename: swap the label for an input, commit on Enter / blur.
function startOutfitRename(card, outfit) {
    const label = card.querySelector('.outfit-label');
    if (!label) return;
    const input = document.createElement('input');
    input.type = 'text';
    input.className = 'admin-input outfit-rename-input';
    input.value = outfit.name;
    input.maxLength = 30;
    label.replaceWith(input);
    input.focus();
    input.select();

    let done = false;
    const commit = () => {
        if (done) return;
        done = true;
        const newName = (input.value || '').trim();
        if (newName && newName !== outfit.name) {
            sendToGame('outfitRename', { id: outfit.id, name: newName });
        } else {
            renderOptionsPanel();
        }
    };
    input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') commit();
        else if (e.key === 'Escape') { done = true; renderOptionsPanel(); }
    });
    input.addEventListener('blur', commit);
}

// Share picker modal: nearby online players + manual server-ID entry.
async function openSharePicker(outfit) {
    const existing = document.querySelector('.outfit-share-panel');
    if (existing) existing.remove();

    const targets = await sendToGameAsync('outfitShareTargets', {});
    const list = Array.isArray(targets) ? targets : [];

    const panel = document.createElement('div');
    panel.className = 'confirm-panel outfit-share-panel';

    let listHtml = list.map(tg =>
        `<button class="outfit-target" data-id="${tg.id}">
            <span class="outfit-target-name">${escapeHtml(tg.name)} <span class="outfit-target-id">[${tg.id}]</span></span>
            ${tg.dist != null ? `<span class="outfit-target-dist">${tg.dist}m</span>` : ''}
        </button>`).join('');
    if (!listHtml) listHtml = `<div class="tattoo-empty">${t('outfit_share_none', 'No other players online.')}</div>`;

    panel.innerHTML = `
        <div class="confirm-content">
            <div class="confirm-header">
                <h2 class="confirm-title">${t('outfit_share', 'SHARE')} — ${escapeHtml(outfit.name)}</h2>
                <p class="confirm-subtitle">${t('outfit_share_pick', 'Pick a player or enter a server ID')}</p>
            </div>
            <div class="outfit-target-list">${listHtml}</div>
            <div class="outfit-share-manual">
                <input type="text" class="admin-input" id="outfitShareId" placeholder="${t('outfit_share_id_ph', 'Server ID...')}">
                <button class="confirm-btn accept" id="outfitShareIdBtn">${t('outfit_share', 'SHARE')}</button>
            </div>
            <div class="confirm-buttons">
                <button class="confirm-btn cancel" id="outfitShareCancel">${t('cancel', 'CANCEL')}</button>
            </div>
        </div>
    `;
    container.appendChild(panel);
    setTimeout(() => panel.classList.add('visible'), 10);

    const close = () => { panel.classList.remove('visible'); setTimeout(() => panel.remove(), 250); };

    panel.querySelectorAll('.outfit-target').forEach(btn => {
        btn.addEventListener('click', () => {
            sendToGame('outfitShare', { id: outfit.id, targetId: parseInt(btn.dataset.id, 10) });
            close();
        });
    });
    panel.querySelector('#outfitShareIdBtn').addEventListener('click', () => {
        const idVal = parseInt(panel.querySelector('#outfitShareId').value, 10);
        if (!isNaN(idVal)) {
            sendToGame('outfitShare', { id: outfit.id, targetId: idVal });
            close();
        }
    });
    panel.querySelector('#outfitShareCancel').addEventListener('click', close);
}

function updateNumber(controlId, delta, min, max, controlEl) {
    let value = state.numbers[controlId] || min;
    value = Math.max(min, Math.min(max, value + delta));
    state.numbers[controlId] = value;

    const currentSpan = controlEl.querySelector('.current');
    currentSpan.textContent = value;

    sendToGame('updateNumber', { control: controlId, value: value });
}

function selectCategory(categoryId) {
    state.activeCategory = categoryId;
    state.activeSubcategory = null;
    updateCategoryTabs();
    renderContent();
    updateProgress();
    // Move camera to the appropriate position for this category
    const subs = SUBCATEGORIES[categoryId];
    const firstSub = subs && subs.length > 0 ? subs[0].id : null;
    const camPos = (firstSub && SUBCATEGORY_CAMERA[firstSub]) || CATEGORY_CAMERA[categoryId] || 'full';
    sendToGame('updateCamera', { position: camPos });
}

function updateCategoryTabs() {
    const tabs = categoryTabs.querySelectorAll('.category-tab');
    tabs.forEach(tab => {
        if (tab.dataset.category === state.activeCategory) {
            tab.classList.add('active');
        } else {
            tab.classList.remove('active');
        }
    });
}

function selectSubcategory(subcategoryId) {
    state.activeSubcategory = subcategoryId;
    renderSubcategoryTabs();
    renderOptionsPanel();
    const camPos = SUBCATEGORY_CAMERA[subcategoryId] || CATEGORY_CAMERA[state.activeCategory] || 'full';
    sendToGame('updateCamera', { position: camPos });
    // For tattoo zones, tell Lua so it can swap the clothing strip and camera focus
    if (state.activeCategory === 'tattoos') {
        sendToGame('tattooZoneChanged', { zone: subcategoryId });
    }
}

function toggleSection(sectionId) {
    state.expanded[sectionId] = !state.expanded[sectionId];
    const content = document.getElementById(`content-${sectionId}`);
    const header = content.previousElementSibling;
    if (state.expanded[sectionId]) {
        content.classList.add('visible');
        header.classList.add('expanded');
        // Activate deferred images (data-src → src)
        content.querySelectorAll('img[data-src]').forEach(img => {
            img.src = img.dataset.src;
            delete img.dataset.src;
        });
    } else {
        content.classList.remove('visible');
        header.classList.remove('expanded');
    }
    requestAnimationFrame(() => {
        updateOptionsPanelHeight();
        updateScrollbar();
    });
}

function selectItem(sectionId, index) {
    state.selections[sectionId] = index;
    const content = document.getElementById(`content-${sectionId}`);
    const items = content.querySelectorAll('.item-card');
    items.forEach(item => item.classList.remove('active'));
    const target = content.querySelector(`.item-card[data-index="${index}"]`);
    if (target) target.classList.add('active');
    // Apply gameOffset for props where UI index 0 = "remove" (sends -1 to Lua)
    const mapping = IMAGE_MAPPING[sectionId];
    const gameIndex = index + (mapping && mapping.gameOffset ? mapping.gameOffset : 0);
    sendToGame('selectItem', { section: sectionId, index: gameIndex });

    // Reset texture/palette to 0 when switching items (clothing & accessories)
    const parentCat = state.activeCategory;
    if (parentCat === 'clothing' || parentCat === 'accessories') {
        state.numbers.texture = 0;
        state.numbers.palette = 0;
        // Update the visible number controls if detail panel is showing
        const detailPanel = document.getElementById('detailPanel');
        if (detailPanel && !detailPanel.classList.contains('hidden')) {
            detailPanel.querySelectorAll('.number-control').forEach(ctrl => {
                const currentSpan = ctrl.querySelector('.current');
                if (currentSpan) currentSpan.textContent = '0';
            });
        }
    }

    // Actualizar género cuando se cambia en identity_gender
    if (sectionId === 'identity_gender') {
        const newGender = index === 0 ? 'male' : 'female';
        if (currentGender !== newGender) {
            currentGender = newGender;
            // Recargar secciones que dependen del género
            reloadGenderDependentSections();
        }
    }
}

function reloadGenderDependentSections() {
    // Solo recargar si hay secciones con imágenes dependientes del género visibles
    const genderDependentSections = Object.keys(IMAGE_MAPPING).filter(key => IMAGE_MAPPING[key].hasGender);

    genderDependentSections.forEach(sectionId => {
        const content = document.getElementById(`content-${sectionId}`);
        if (content) {
            const grid = content.querySelector('.items-grid');
            if (grid) {
                const items = grid.querySelectorAll('.item-card');
                items.forEach((item, i) => {
                    const img = item.querySelector('img');
                    if (img) {
                        const newUrl = getImageUrl(sectionId, i);
                        if (newUrl && img.src !== newUrl) {
                            img.classList.remove('loaded');
                            img.src = newUrl;
                        }
                    }
                });
            }
        }
    });
}

function startSliderDrag(e, sliderId) {
    const track = e.currentTarget;
    const rect = track.getBoundingClientRect();
    const updateSlider = (clientX) => {
        let percent = ((clientX - rect.left) / rect.width) * 100;
        percent = Math.max(0, Math.min(100, percent));
        state.sliders[sliderId] = Math.round(percent);
        track.querySelector('.slider-fill').style.width = `${percent}%`;
        track.querySelector('.slider-thumb').style.left = `${percent}%`;
        // Update prominent value display if present
        const prominentVal = document.getElementById(`prominent-${sliderId}`);
        if (prominentVal) {
            const displayValue = Math.round(85 + (percent / 100) * 30);
            prominentVal.textContent = `${displayValue}%`;
        }
        sendToGame('updateSlider', { slider: sliderId, value: percent });
    };
    updateSlider(e.clientX);
    const onMove = (e) => updateSlider(e.clientX);
    const onUp = () => {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
    };
    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
}

function updateOptionsPanelHeight() {
    const contentArea = optionsPanel.parentElement;
    if (!contentArea) return;
    const subcatTabs = document.getElementById('subcategoryTabs');
    const subcatVisible = subcatTabs && subcatTabs.style.display !== 'none';
    const subcatHeight = subcatVisible ? subcatTabs.offsetHeight : 0;
    const saveBtnHeight = saveBtn ? saveBtn.offsetHeight : 0;
    const totalHeight = contentArea.clientHeight;
    const gap = parseFloat(getComputedStyle(contentArea).gap) || 0;
    const available = totalHeight - subcatHeight - saveBtnHeight - (gap * 2);
    optionsPanel.style.maxHeight = available + 'px';
}

function updateScrollbar() {
    const panel = optionsPanel;
    const scrollHeight = panel.scrollHeight;
    const clientHeight = panel.clientHeight;
    if (scrollHeight <= clientHeight) {
        scrollbarThumb.style.height = '100%';
        return;
    }
    const thumbHeight = (clientHeight / scrollHeight) * 100;
    scrollbarThumb.style.height = `${thumbHeight}%`;
}

function updateProgress() {
    const visible = getVisibleCategories();
    const currentIndex = visible.findIndex(c => c.id === state.activeCategory);
    const total = visible.length || 1;
    const progress = ((currentIndex + 1) / total) * 100;
    const progressFill = document.querySelector('.progress-fill');
    if (progressFill) {
        progressFill.style.width = `${progress}%`;
    }
}

function bindEvents() {
    saveBtn.addEventListener('click', () => showConfirmPanel());

    const resetBtn = document.getElementById('resetBtn');
    const exitBtn = document.getElementById('exitBtn');
    if (resetBtn) resetBtn.addEventListener('click', () => showResetConfirm());
    if (exitBtn) exitBtn.addEventListener('click', () => showExitConfirm());

    // Scene toolbar: blur + light toggles
    const btnBlur = document.getElementById('btnBlur');
    const btnLight = document.getElementById('btnLight');
    if (btnBlur) {
        btnBlur.addEventListener('click', () => {
            btnBlur.classList.toggle('active');
            sendToGame('toggleBlur', { enabled: btnBlur.classList.contains('active') });
        });
    }
    if (btnLight) {
        btnLight.addEventListener('click', () => {
            btnLight.classList.toggle('active');
            sendToGame('toggleLight', { enabled: btnLight.classList.contains('active') });
        });
    }

    document.addEventListener('keydown', handleKeydown);
    optionsPanel.addEventListener('scroll', handleScroll);

    // Force scroll via JS wheel handler (FiveM CEF compatibility).
    // Walk up from the cursor to the first scrollable container (clothing grid,
    // tattoo/outfit list, etc.); fall back to scrolling the main panel.
    optionsPanel.onwheel = function(e) {
        e.preventDefault();
        e.stopPropagation();
        const delta = e.deltaY > 0 ? 40 : -40;
        let el = e.target;
        while (el && el !== this) {
            const oy = getComputedStyle(el).overflowY;
            if ((oy === 'auto' || oy === 'scroll') && el.scrollHeight > el.clientHeight + 1) {
                el.scrollTop += delta;
                updateScrollbar();
                return false;
            }
            el = el.parentElement;
        }
        this.scrollTop += delta;
        updateScrollbar();
        return false;
    };

    window.addEventListener('resize', function() {
        updateOptionsPanelHeight();
        updateScrollbar();
    });

    // Rotation buttons
    document.getElementById('rotatLeft').addEventListener('click', () => {
        sendToGame('rotatePed', { direction: -1 });
    });
    document.getElementById('rotatRight').addEventListener('click', () => {
        sendToGame('rotatePed', { direction: 1 });
    });

    // Drag-to-rotate + drag-to-pan on the right-side drag zone.
    // Horizontal delta → ped rotation (rotatePed, unchanged behavior).
    // Vertical delta   → camera vertical pan (panCamera, new).
    const dragZone = document.getElementById('dragZone');
    let dragStartX = null;
    let dragStartY = null;
    let lastDragX = null;
    let lastDragY = null;
    let dragAxis = null; // 'x' (rotate) or 'y' (pan) — locked per drag
    const DRAG_THRESHOLD = 8;     // px per rotation / pan step
    const AXIS_LOCK_THRESHOLD = 6; // px of movement before locking the axis

    dragZone.addEventListener('mousedown', (e) => {
        // Don't drag when confirm panel is visible
        const confirmPanel = document.querySelector('.confirm-panel');
        if (confirmPanel && confirmPanel.classList.contains('visible')) return;
        dragStartX = e.clientX;
        dragStartY = e.clientY;
        lastDragX = e.clientX;
        lastDragY = e.clientY;
        dragZone.classList.add('dragging');
        e.preventDefault();
    });

    document.addEventListener('mousemove', (e) => {
        if (dragStartX === null) return;

        // Lock to a single axis per drag (whichever direction the user moved
        // more) so a vertical drag never also rotates and vice versa.
        if (dragAxis === null) {
            const totalX = Math.abs(e.clientX - dragStartX);
            const totalY = Math.abs(e.clientY - dragStartY);
            if (Math.max(totalX, totalY) < AXIS_LOCK_THRESHOLD) return; // wait for intent
            dragAxis = totalX >= totalY ? 'x' : 'y';
        }

        if (dragAxis === 'x') {
            // Horizontal: rotate the ped in place
            const deltaX = e.clientX - lastDragX;
            if (Math.abs(deltaX) >= DRAG_THRESHOLD) {
                sendToGame('rotatePed', { direction: deltaX > 0 ? 1 : -1 });
                lastDragX = e.clientX;
            }
        } else {
            // Vertical: slide the camera up/down along the ped.
            // Screen Y grows downward, so dragging UP (deltaY < 0) → see HEAD
            // (pan +1); dragging DOWN → see FEET (pan -1).
            const deltaY = e.clientY - lastDragY;
            if (Math.abs(deltaY) >= DRAG_THRESHOLD) {
                sendToGame('panCamera', { delta: deltaY < 0 ? 1 : -1 });
                lastDragY = e.clientY;
            }
        }
    });

    document.addEventListener('mouseup', () => {
        if (dragStartX === null) return;
        dragStartX = null;
        dragStartY = null;
        lastDragX = null;
        lastDragY = null;
        dragAxis = null;
        dragZone.classList.remove('dragging');
    });

    // Scroll-to-zoom on the ped drag-zone. Wheel up = zoom in, wheel down = zoom out.
    // Lua clamps the final FOV to [ZOOM_MIN_FOV, ZOOM_MAX_FOV] and resets on every
    // camera-preset change. Throttled to ~20 events/sec so fast trackpad scrolling
    // doesn't flood the NUI callback queue.
    let zoomCooldown = false;
    dragZone.addEventListener('wheel', (e) => {
        // Don't zoom while the confirm panel is visible
        const confirmPanel = document.querySelector('.confirm-panel');
        if (confirmPanel && confirmPanel.classList.contains('visible')) return;

        e.preventDefault();
        if (zoomCooldown) return;
        zoomCooldown = true;
        setTimeout(() => { zoomCooldown = false; }, 50);

        // deltaY < 0 means wheel rolled forward / user scrolled up → zoom in (+1)
        const direction = e.deltaY < 0 ? 1 : -1;
        sendToGame('zoomPed', { delta: direction });
    }, { passive: false });
}

function handleKeydown(e) {
    if (e.key === 'Escape') {
        // Close any open generic confirm first (e.g. exit/reset dialogs)
        const genericConfirm = document.querySelector('.generic-confirm-panel');
        if (genericConfirm) {
            genericConfirm.remove();
            return;
        }
        // Close legacy confirm panel if visible
        const confirmPanel = document.querySelector('.confirm-panel');
        if (confirmPanel && confirmPanel.classList.contains('visible')) {
            hideConfirmPanel();
            return;
        }
        // Show exit confirmation (same as Exit button)
        if (!isFirstTime) {
            showExitConfirm();
        }
    }
}

function handleScroll() {
    const panel = optionsPanel;
    const scrollTop = panel.scrollTop;
    const scrollHeight = panel.scrollHeight - panel.clientHeight;
    if (scrollHeight > 0) {
        const scrollPercent = (scrollTop / scrollHeight) * 100;
        const trackHeight = document.querySelector('.scrollbar-track').clientHeight;
        const thumbHeight = scrollbarThumb.clientHeight;
        const maxTop = trackHeight - thumbHeight;
        scrollbarThumb.style.top = `${(scrollPercent / 100) * maxTop}px`;
    }
}

// ── Pricing: compute changed items and their costs ──────────────────
function getChangedItems() {
    const changes = [];

    // Map subcategory IDs to their human-readable labels
    const SUBCAT_LABELS = {};
    for (const [catId, subs] of Object.entries(SUBCATEGORIES)) {
        for (const sub of subs) {
            SUBCAT_LABELS[sub.id] = sub.name;
        }
    }

    // Check clothing & accessories subcategory selections
    const priceableCategories = ['clothing', 'accessories', 'hair', 'makeup'];
    for (const catId of priceableCategories) {
        const subs = SUBCATEGORIES[catId];
        if (!subs) continue;
        for (const sub of subs) {
            const selKey = `${catId}_${sub.id}`;
            const current = state.selections[selKey];
            const initial = initialSelections[selKey];
            if (current !== undefined && current !== initial) {
                changes.push({
                    id: sub.id,
                    label: SUBCAT_LABELS[sub.id] || sub.id,
                    category: catId,
                });
            }
        }
    }

    // Check tattoos: count newly added tattoos
    if (currentStoreType === 'tattoo') {
        let newTattooCount = 0;
        for (const key of Object.keys(activeTattoos)) {
            if (!initialActiveTattoos[key]) {
                newTattooCount++;
            }
        }
        for (let i = 0; i < newTattooCount; i++) {
            changes.push({
                id: 'tattoo',
                label: 'Tattoo',
                category: 'tattoos',
            });
        }
    }

    return changes;
}

function getItemPrice(itemId) {
    if (!pricingData || !pricingData.items) return 0;
    const basePrice = pricingData.items[itemId] || 0;
    return Math.floor(basePrice * (pricingData.multiplier || 1));
}

function formatMoney(amount) {
    return '$' + amount.toLocaleString();
}

function showConfirmPanel() {
    // Remove existing confirm panel if any
    const existing = document.querySelector('.confirm-panel');
    if (existing) existing.remove();

    const changes = pricingData ? getChangedItems() : [];
    const hasChanges = changes.length > 0;
    const totalCost = changes.reduce((sum, item) => sum + getItemPrice(item.id), 0);
    const showCheckout = pricingData && pricingData.enabled && !isFirstTime && hasChanges && totalCost > 0;

    const confirmPanel = document.createElement('div');
    confirmPanel.className = 'confirm-panel';

    if (showCheckout) {
        // Checkout modal with item breakdown
        const itemsHtml = changes.map(item => {
            const price = getItemPrice(item.id);
            return `
                <div class="checkout-item">
                    <span class="checkout-item-name">${item.label}</span>
                    <span class="checkout-item-price">${formatMoney(price)}</span>
                </div>
            `;
        }).join('');

        confirmPanel.innerHTML = `
            <div class="confirm-content checkout-content">
                <div class="confirm-header">
                    <div class="confirm-icon">
                        <svg viewBox="0 0 24 24" fill="none">
                            <path d="M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49A1.003 1.003 0 0020.01 4H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z" fill="currentColor"/>
                        </svg>
                    </div>
                    <h2 class="confirm-title">${t('checkout_title', 'CHECKOUT')}</h2>
                    <p class="confirm-subtitle">${tf('checkout_items_changed', '%d item(s) changed', changes.length)}</p>
                </div>
                <div class="checkout-items">
                    ${itemsHtml}
                </div>
                <div class="checkout-total">
                    <span class="checkout-total-label">${t('checkout_total', 'TOTAL')}</span>
                    <span class="checkout-total-price">${formatMoney(totalCost)}</span>
                </div>
                <div class="confirm-buttons">
                    <button class="confirm-btn cancel" id="confirmCancel">${t('checkout_cancel', 'CANCEL')}</button>
                    <button class="confirm-btn accept" id="confirmAccept">${t('checkout_pay', 'PAY & SAVE')}</button>
                </div>
            </div>
        `;
    } else {
        // Simple confirm (no pricing, first time, or no changes)
        confirmPanel.innerHTML = `
            <div class="confirm-content">
                <div class="confirm-header">
                    <div class="confirm-icon">
                        <svg viewBox="0 0 24 24" fill="none">
                            <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" fill="currentColor"/>
                        </svg>
                    </div>
                    <h2 class="confirm-title">${isFirstTime ? t('create_title', 'CREATE CHARACTER') : t('save_title', 'SAVE CHARACTER')}</h2>
                    <p class="confirm-subtitle">${isFirstTime ? t('create_subtitle', 'Are you sure you want to create this character?') : t('save_subtitle', 'Are you sure you want to save this character?')}</p>
                </div>
                <div class="confirm-buttons">
                    <button class="confirm-btn cancel" id="confirmCancel">${t('cancel', 'CANCEL')}</button>
                    <button class="confirm-btn accept" id="confirmAccept">${t('confirm', 'CONFIRM')}</button>
                </div>
            </div>
        `;
    }

    container.appendChild(confirmPanel);

    document.getElementById('confirmCancel').addEventListener('click', hideConfirmPanel);
    document.getElementById('confirmAccept').addEventListener('click', confirmSave);

    setTimeout(() => {
        confirmPanel.classList.add('visible');
    }, 10);
}

function hideConfirmPanel() {
    const confirmPanel = document.querySelector('.confirm-panel');
    if (confirmPanel) {
        confirmPanel.classList.remove('visible');
        setTimeout(() => confirmPanel.remove(), 300);
    }
}

function confirmSave() {
    // Disable the accept button to prevent double-clicks
    const acceptBtn = document.getElementById('confirmAccept');
    if (acceptBtn) {
        acceptBtn.disabled = true;
        acceptBtn.textContent = t('checkout_processing', 'PROCESSING...');
    }
    saveCharacter();
}

// ── Reset Confirm (restore to entry state) ──────────────────────────
function showResetConfirm() {
    showGenericConfirm(
        t('reset_title', 'RESET APPEARANCE'),
        t('reset_subtitle', 'Restore your character to how it looked when you opened this menu?'),
        t('reset_btn', 'RESET'),
        () => {
            sendToGame('resetAppearance', {});
            // Reset local state numbers
            state.numbers = {};
            // Re-render current panel to reflect reset
            renderContent();
        }
    );
}

// ── Exit Confirm (close without saving) ─────────────────────────────
function showExitConfirm() {
    showGenericConfirm(
        t('exit_title', 'EXIT WITHOUT SAVING'),
        t('exit_subtitle', 'Any unsaved changes will be lost. Are you sure?'),
        t('exit_btn', 'EXIT'),
        () => {
            sendToGame('closeUI', {});
        }
    );
}

// ── Generic confirmation dialog ─────────────────────────────────────
function showGenericConfirm(title, subtitle, actionLabel, onConfirm) {
    // Remove any existing generic confirm
    const existing = document.querySelector('.generic-confirm-panel');
    if (existing) existing.remove();

    const panel = document.createElement('div');
    panel.className = 'confirm-panel generic-confirm-panel';
    panel.innerHTML = `
        <div class="confirm-content">
            <div class="confirm-header">
                <div class="confirm-icon warning">
                    <svg viewBox="0 0 24 24" fill="none">
                        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z" fill="currentColor"/>
                    </svg>
                </div>
                <h2 class="confirm-title">${title}</h2>
                <p class="confirm-subtitle">${subtitle}</p>
            </div>
            <div class="confirm-buttons">
                <button class="confirm-btn cancel" id="genericConfirmCancel">${t('cancel', 'CANCEL')}</button>
                <button class="confirm-btn accept warning" id="genericConfirmAccept">${actionLabel}</button>
            </div>
        </div>
    `;
    container.appendChild(panel);

    document.getElementById('genericConfirmCancel').addEventListener('click', () => {
        panel.classList.remove('visible');
        setTimeout(() => panel.remove(), 300);
    });
    document.getElementById('genericConfirmAccept').addEventListener('click', () => {
        panel.classList.remove('visible');
        setTimeout(() => panel.remove(), 300);
        onConfirm();
    });

    setTimeout(() => panel.classList.add('visible'), 10);
}

function saveCharacter() {
    // Build list of changed subcategory IDs for server-side pricing
    const changes = pricingData ? getChangedItems() : [];
    const changedItems = changes.map(c => c.id);

    const data = {
        selections: toPlainObject(state.selections),
        sliders: toPlainObject(state.sliders),
        numbers: toPlainObject(state.numbers),
        changedItems: changedItems,
    };
    sendToGame('saveCharacter', data);
    saveBtn.style.transform = 'scale(0.95)';
    setTimeout(() => {
        saveBtn.style.transform = '';
    }, 150);
}

function sendToGame(action, data) {
    try {
        fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).catch(() => {});
    } catch (e) {}
}

// Like sendToGame but resolves with the Lua callback's response (cb(...) body).
async function sendToGameAsync(action, data) {
    try {
        const resp = await fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        });
        return await resp.json();
    } catch (e) {
        return null;
    }
}

// Escape user-provided text before injecting into innerHTML. Outfit names are
// player-controlled AND shareable across players, so this is a security must.
function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
}

function toPlainObject(val) {
    // FiveM sends empty Lua tables as [] — convert to {} so string keys work
    if (Array.isArray(val)) return {};
    if (val && typeof val === 'object') return val;
    return {};
}

function openUI(data) {
    if (data) {
        isFirstTime = data.isFirstTime || false;
        state.selections = toPlainObject(data.selections);
        state.sliders = toPlainObject(data.sliders);
        state.numbers = toPlainObject(data.numbers);

        // Receive gender-resolved tattoo list from Lua (only sent for tattoo stores)
        if (data.tattooList && typeof data.tattooList === 'object') {
            tattooList = data.tattooList;
        } else if (!data.storeType || data.storeType !== 'tattoo') {
            tattooList = null;
        }

        // Seed active tattoos from already-applied tattoos sent by Lua
        activeTattoos = (data.activeTattoos && typeof data.activeTattoos === 'object') ? data.activeTattoos : {};

        currentStoreType = data.storeType || null;

        // Pricing data from Lua (only sent for stores with pricing enabled)
        if (data.pricing && data.pricing.enabled) {
            pricingData = data.pricing;
        } else {
            pricingData = null;
        }

        // Custom peds data (only sent in full creator, not stores)
        if (data.customPeds && Array.isArray(data.customPeds)) {
            customPedsData = data.customPeds;
        } else {
            customPedsData = null;
        }

        // Custom clothing overrides (add-on support) — sent every openUI
        if (data.customClothing && typeof data.customClothing === 'object') {
            customClothingData = data.customClothing;
        } else {
            customClothingData = null;
        }

        // Auto-detected drawable counts from FiveM natives — covers add-on
        // packs without any manual config. Refreshed on gender swap via the
        // 'updateAutoCounts' message above.
        if (data.autoCounts && typeof data.autoCounts === 'object') {
            autoCountsData = data.autoCounts;
        } else {
            autoCountsData = null;
        }

        // Outfits config (the saved list is lazy-fetched when the tab opens)
        outfitConfig = (data.outfitConfig && data.outfitConfig.enabled) ? data.outfitConfig : null;
        outfitsData = null;
        customPedActiveCategory = null;
        selectedCustomPed = null;

        // Snapshot initial selections to diff against on save
        initialSelections = JSON.parse(JSON.stringify(toPlainObject(data.selections)));
        initialActiveTattoos = (data.activeTattoos && typeof data.activeTattoos === 'object')
            ? JSON.parse(JSON.stringify(data.activeTattoos))
            : {};

        // Apply tab filter if store type is restricted
        if (data.allowedTabs && Array.isArray(data.allowedTabs)) {
            allowedTabs = data.allowedTabs;
            // Set active category to first allowed tab if current isn't visible
            const visible = getVisibleCategories();
            if (visible.length > 0 && !visible.find(c => c.id === state.activeCategory)) {
                state.activeCategory = visible[0].id;
                state.activeSubcategory = null;
            }
        } else {
            allowedTabs = null;
        }

        // Apply subcategory filter if store restricts to specific subcategories
        if (data.allowedSubs && Array.isArray(data.allowedSubs)) {
            allowedSubs = data.allowedSubs;
        } else {
            allowedSubs = null;
        }

        // Update header title + subtitle to match the store type (custom name takes priority)
        applyStoreLabels(data.storeType || 'default', data.storeName || null);
    }
    saveBtn.textContent = isFirstTime ? t('save_btn_create', 'CREATE CHARACTER') : t('save_btn', 'SAVE');

    // Reset scene toolbar toggles
    const btnBlur = document.getElementById('btnBlur');
    const btnLight = document.getElementById('btnLight');
    if (btnBlur) btnBlur.classList.remove('active');
    if (btnLight) btnLight.classList.remove('active');

    renderCategoryTabs();
    renderContent();
    updateProgress();
    container.classList.remove('hidden');

    // Pre-fetch all CDN images in background so browsing feels instant
    preloadCDNImages();
}

function closeUI() {
    container.classList.add('hidden');
    const confirmPanel = document.querySelector('.confirm-panel');
    if (confirmPanel) confirmPanel.remove();
    const genericConfirm = document.querySelector('.generic-confirm-panel');
    if (genericConfirm) genericConfirm.remove();
    sendToGame('closeUI', {});
}

window.addEventListener('message', (event) => {
    const data = event.data;
    switch (data.action) {
        case 'init':
            // Sent on resource start so fetch URLs point to the right resource
            if (data.resourceName) resourceName = data.resourceName;
            if (data.locale) { LOCALE = data.locale; translateStaticDOM(); }
            break;
        case 'openUI':
            openUI(data);
            break;
        case 'hideUI':
            // Called from Lua - just hide UI, don't send callback back (avoids loop)
            container.classList.add('hidden');
            {
                const cp = document.querySelector('.confirm-panel');
                if (cp) cp.remove();
                const gc = document.querySelector('.generic-confirm-panel');
                if (gc) gc.remove();
            }
            break;
        case 'closeUI':
            closeUI();
            break;
        case 'paymentFailed':
            // Re-enable the checkout panel so the player can try again or exit
            hideConfirmPanel();
            break;
        case 'updateData':
            state.selections = data.selections || state.selections;
            state.sliders = data.sliders || state.sliders;
            state.numbers = data.numbers || state.numbers;
            renderContent();
            break;
        case 'outfitList':
            outfitsData = Array.isArray(data.outfits) ? data.outfits : [];
            if (state.activeCategory === 'outfits') renderOptionsPanel();
            break;
        case 'outfitResult':
            // Re-enable the save button (the fresh list arrives via 'outfitList').
            document.querySelectorAll('.outfit-save-btn').forEach(b => { b.disabled = false; });
            break;
        case 'mergeSelections':
            // After applying an outfit, merge the new clothing/prop selections so
            // the cards highlight correctly without wiping other selections.
            if (data.selections && typeof data.selections === 'object') {
                Object.assign(state.selections, data.selections);
            }
            break;
        case 'updateAutoCounts':
            // Pushed by Lua after gender swap so add-on packs that differ
            // per model stay in sync. Re-render current section so new
            // drawable cards appear (or disappear) immediately.
            autoCountsData = (data.counts && typeof data.counts === 'object') ? data.counts : null;
            if (typeof renderOptionsPanel === 'function') {
                renderOptionsPanel();
            }
            break;
        // ── Admin panel messages ──
        case 'openAdminPanel':
            adminOpenPanel(data.stores, data.storeTypes);
            break;
        case 'hideAdminPanel':
        case 'adminHidePanel':
            adminHidePanel();
            break;
        case 'adminShowPanel':
            adminShowPanel();
            break;
        case 'adminPositionSet':
            adminPositionSet(data.field, data.x, data.y, data.z, data.w);
            adminShowPanel();
            break;
        case 'adminStoresSynced':
            adminSyncStores(data.stores);
            break;
    }
});

document.addEventListener('DOMContentLoaded', () => {
    init();
    adminInit();
});

// ═══════════════════════════════════════════════════════════════════════
//                        ADMIN STORE MANAGER
// ═══════════════════════════════════════════════════════════════════════

let adminState = {
    stores: [],
    storeTypes: {},
    selectedId: null,    // null = creating new, string = editing existing
    editor: {
        type: 'clothing',
        coords: null,       // { x, y, z, w }
        pedPosition: null,  // { x, y, z, w }
        size: { x: 14.0, y: 10.0 },
        cameraPreset: 'full',
        label: '',
        jobLock: ''
    }
};

// ── DOM refs (set in adminInit) ──

let adminOverlay, adminStoreList, adminEditor;
let adminTypeGrid, adminCameraGrid;
let adminWidthEl, adminLengthEl;
let adminLabelEl, adminJobLockEl;
let adminDeleteBtn, adminSaveBtn;
let adminConfirmOverlay;
let zoneXEl, zoneYEl, zoneZEl, zoneWEl;
let pedXEl, pedYEl, pedZEl, pedWEl;

function adminInit() {
    adminOverlay = document.getElementById('adminOverlay');
    adminStoreList = document.getElementById('adminStoreList');
    adminEditor = document.getElementById('adminEditor');
    adminTypeGrid = document.getElementById('adminTypeGrid');
    adminCameraGrid = document.getElementById('adminCameraGrid');
    adminWidthEl = document.getElementById('adminWidth');
    adminLengthEl = document.getElementById('adminLength');
    adminLabelEl = document.getElementById('adminLabel');
    adminJobLockEl = document.getElementById('adminJobLock');
    adminDeleteBtn = document.getElementById('adminDeleteBtn');
    adminSaveBtn = document.getElementById('adminSaveBtn');
    adminConfirmOverlay = document.getElementById('adminConfirmOverlay');
    zoneXEl = document.getElementById('zoneX');
    zoneYEl = document.getElementById('zoneY');
    zoneZEl = document.getElementById('zoneZ');
    zoneWEl = document.getElementById('zoneW');
    pedXEl = document.getElementById('pedX');
    pedYEl = document.getElementById('pedY');
    pedZEl = document.getElementById('pedZ');
    pedWEl = document.getElementById('pedW');

    // Type cards
    adminTypeGrid.addEventListener('click', (e) => {
        const card = e.target.closest('.admin-type-card');
        if (!card) return;
        adminState.editor.type = card.dataset.type;
        // Update default size from store type
        const st = adminState.storeTypes[card.dataset.type];
        if (st && st.defaultSize) {
            adminState.editor.size = { x: st.defaultSize.x, y: st.defaultSize.y };
            adminWidthEl.textContent = adminState.editor.size.x.toFixed(1);
            adminLengthEl.textContent = adminState.editor.size.y.toFixed(1);
            sendToGame('adminUpdateMarkerSize', { width: adminState.editor.size.x, length: adminState.editor.size.y });
        }
        if (st && st.openCamera) {
            adminState.editor.cameraPreset = st.openCamera;
            adminRenderCameraCards();
        }
        adminRenderTypeCards();
    });

    // Camera cards
    adminCameraGrid.addEventListener('click', (e) => {
        const card = e.target.closest('.admin-camera-card');
        if (!card) return;
        adminState.editor.cameraPreset = card.dataset.preset;
        adminRenderCameraCards();
    });

    // Size +/- buttons
    document.querySelectorAll('.admin-num-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const field = btn.dataset.field;  // 'width' or 'length'
            const dir = parseInt(btn.dataset.dir);
            const key = field === 'width' ? 'x' : 'y';
            adminState.editor.size[key] = Math.max(1.0, adminState.editor.size[key] + dir * 1.0);
            const el = field === 'width' ? adminWidthEl : adminLengthEl;
            el.textContent = adminState.editor.size[key].toFixed(1);
            sendToGame('adminUpdateMarkerSize', { width: adminState.editor.size.x, length: adminState.editor.size.y });
        });
    });

    // SET TO MY POSITION buttons
    document.getElementById('adminSetZone').addEventListener('click', () => {
        sendToGame('adminStartPlacement', { field: 'zone' });
    });
    document.getElementById('adminSetPed').addEventListener('click', () => {
        sendToGame('adminStartPlacement', { field: 'ped' });
    });

    // Teleport to the store currently being edited (uses the zone coords)
    document.getElementById('adminTeleport').addEventListener('click', () => {
        const target = adminState.editor.coords || adminState.editor.pedPosition;
        if (!target) return; // nothing positioned yet
        sendToGame('adminTeleport', { coords: target });
    });

    // Preview camera
    document.getElementById('adminPreviewBtn').addEventListener('click', () => {
        if (!adminState.editor.pedPosition) {
            return; // Can't preview without ped position
        }
        sendToGame('adminPreviewCamera', {
            pedPosition: adminState.editor.pedPosition,
            cameraPreset: adminState.editor.cameraPreset
        });
    });

    // New store button
    document.getElementById('adminNewBtn').addEventListener('click', () => {
        adminState.selectedId = null;
        adminResetEditor();
        adminRenderSidebar();
    });

    // Save button
    adminSaveBtn.addEventListener('click', () => {
        // Validate required fields
        if (!adminState.editor.coords) {
            return;
        }
        if (!adminState.editor.pedPosition) {
            return;
        }

        const payload = {
            type: adminState.editor.type,
            coords: adminState.editor.coords,
            pedPosition: adminState.editor.pedPosition,
            size: adminState.editor.size,
            cameraPreset: adminState.editor.cameraPreset,
            label: adminLabelEl.value.trim() || null,
            jobLock: adminJobLockEl.value.trim() || null
        };

        if (adminState.selectedId) {
            payload.id = adminState.selectedId;
        }

        sendToGame('adminSaveStore', payload);
    });

    // Delete button → show confirmation
    adminDeleteBtn.addEventListener('click', () => {
        if (!adminState.selectedId) return;
        adminConfirmOverlay.classList.remove('hidden');
    });

    // Confirm delete
    document.getElementById('adminConfirmDelete').addEventListener('click', () => {
        adminConfirmOverlay.classList.add('hidden');
        if (adminState.selectedId) {
            sendToGame('adminDeleteStore', { id: adminState.selectedId });
        }
    });

    // Cancel delete
    document.getElementById('adminConfirmCancel').addEventListener('click', () => {
        adminConfirmOverlay.classList.add('hidden');
    });

    // Close button
    document.getElementById('adminCloseBtn').addEventListener('click', () => {
        sendToGame('adminClosePanel', {});
    });

    // ESC key in admin panel
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && adminOverlay && !adminOverlay.classList.contains('hidden')) {
            if (!adminConfirmOverlay.classList.contains('hidden')) {
                adminConfirmOverlay.classList.add('hidden');
            } else {
                sendToGame('adminClosePanel', {});
            }
        }
    });
}

// ── Open / close ──

function adminOpenPanel(stores, storeTypes) {
    adminState.stores = stores || [];
    adminState.storeTypes = storeTypes || {};
    adminState.selectedId = null;
    adminResetEditor();
    adminRenderSidebar();
    adminOverlay.classList.remove('hidden');
}

function adminHidePanel() {
    adminOverlay.classList.add('hidden');
    adminConfirmOverlay.classList.add('hidden');
}

function adminShowPanel() {
    adminOverlay.classList.remove('hidden');
}

// ── Sync stores after save/delete ──

function adminSyncStores(stores) {
    adminState.stores = stores || [];
    // If editing a store that was just saved, find it and keep selection
    if (adminState.selectedId) {
        const stillExists = stores.find(s => s.id === adminState.selectedId);
        if (!stillExists) {
            adminState.selectedId = null;
            adminResetEditor();
        }
    }
    adminRenderSidebar();
}

// ── Position confirmed from placement mode ──

function adminPositionSet(field, x, y, z, w) {
    const pos = { x: parseFloat(x.toFixed(2)), y: parseFloat(y.toFixed(2)), z: parseFloat(z.toFixed(2)), w: parseFloat(w.toFixed(1)) };
    if (field === 'zone') {
        adminState.editor.coords = pos;
        zoneXEl.textContent = pos.x.toFixed(2);
        zoneYEl.textContent = pos.y.toFixed(2);
        zoneZEl.textContent = pos.z.toFixed(2);
        zoneWEl.textContent = pos.w.toFixed(1);
    } else if (field === 'ped') {
        adminState.editor.pedPosition = pos;
        pedXEl.textContent = pos.x.toFixed(2);
        pedYEl.textContent = pos.y.toFixed(2);
        pedZEl.textContent = pos.z.toFixed(2);
        pedWEl.textContent = pos.w.toFixed(1);
    }
}

// ── Reset editor to defaults ──

function adminResetEditor() {
    adminState.editor = {
        type: 'clothing',
        coords: null,
        pedPosition: null,
        size: { x: 14.0, y: 10.0 },
        cameraPreset: 'full',
        label: '',
        jobLock: ''
    };

    // Update DOM
    adminRenderTypeCards();
    adminRenderCameraCards();
    adminWidthEl.textContent = '14.0';
    adminLengthEl.textContent = '10.0';
    zoneXEl.textContent = '---';
    zoneYEl.textContent = '---';
    zoneZEl.textContent = '---';
    zoneWEl.textContent = '---';
    pedXEl.textContent = '---';
    pedYEl.textContent = '---';
    pedZEl.textContent = '---';
    pedWEl.textContent = '---';
    adminLabelEl.value = '';
    adminJobLockEl.value = '';
    adminDeleteBtn.classList.add('hidden');
    adminSaveBtn.textContent = t('admin_create_store', 'CREATE STORE');
}

// ── Load a store into editor for editing ──

function adminLoadStore(store) {
    adminState.selectedId = store.id;
    adminState.editor = {
        type: store.type || 'clothing',
        coords: store.coords || null,
        pedPosition: store.pedPosition || null,
        size: store.size ? { x: store.size.x, y: store.size.y } : { x: 14.0, y: 10.0 },
        cameraPreset: store.cameraPreset || 'full',
        label: store.label || '',
        jobLock: store.jobLock || ''
    };

    adminRenderTypeCards();
    adminRenderCameraCards();
    adminWidthEl.textContent = adminState.editor.size.x.toFixed(1);
    adminLengthEl.textContent = adminState.editor.size.y.toFixed(1);

    if (adminState.editor.coords) {
        zoneXEl.textContent = adminState.editor.coords.x.toFixed(2);
        zoneYEl.textContent = adminState.editor.coords.y.toFixed(2);
        zoneZEl.textContent = adminState.editor.coords.z.toFixed(2);
        zoneWEl.textContent = adminState.editor.coords.w.toFixed(1);
    } else {
        zoneXEl.textContent = '---'; zoneYEl.textContent = '---';
        zoneZEl.textContent = '---'; zoneWEl.textContent = '---';
    }

    if (adminState.editor.pedPosition) {
        pedXEl.textContent = adminState.editor.pedPosition.x.toFixed(2);
        pedYEl.textContent = adminState.editor.pedPosition.y.toFixed(2);
        pedZEl.textContent = adminState.editor.pedPosition.z.toFixed(2);
        pedWEl.textContent = adminState.editor.pedPosition.w.toFixed(1);
    } else {
        pedXEl.textContent = '---'; pedYEl.textContent = '---';
        pedZEl.textContent = '---'; pedWEl.textContent = '---';
    }

    adminLabelEl.value = adminState.editor.label;
    adminJobLockEl.value = adminState.editor.jobLock;
    adminDeleteBtn.classList.remove('hidden');
    adminSaveBtn.textContent = t('admin_save_store', 'SAVE STORE');
    adminRenderSidebar();
}

// ── Render type cards ──

function adminRenderTypeCards() {
    adminTypeGrid.querySelectorAll('.admin-type-card').forEach(card => {
        card.classList.toggle('active', card.dataset.type === adminState.editor.type);
    });
}

// ── Render camera cards ──

function adminRenderCameraCards() {
    adminCameraGrid.querySelectorAll('.admin-camera-card').forEach(card => {
        card.classList.toggle('active', card.dataset.preset === adminState.editor.cameraPreset);
    });
}

// ── Render sidebar ──

const trashSvg = '<svg viewBox="0 0 24 24" fill="none"><path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2m3 0v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

function adminRenderSidebar() {
    adminStoreList.innerHTML = '';

    adminState.stores.forEach(store => {
        const card = document.createElement('div');
        card.className = 'admin-store-card' + (store.id === adminState.selectedId ? ' active' : '');

        const displayLabel = store.label || store.type;
        card.innerHTML = `
            <div class="admin-store-card-info">
                <span class="admin-store-card-label">${displayLabel}</span>
                <span class="admin-store-card-type">${store.type}</span>
            </div>
            <button class="admin-store-card-delete" data-id="${store.id}">${trashSvg}</button>
        `;

        // Click card → load into editor
        card.addEventListener('click', (e) => {
            if (e.target.closest('.admin-store-card-delete')) return;
            adminLoadStore(store);
        });

        // Delete icon → show confirmation
        const delBtn = card.querySelector('.admin-store-card-delete');
        delBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            adminState.selectedId = store.id;
            adminConfirmOverlay.classList.remove('hidden');
        });

        adminStoreList.appendChild(card);
    });

    if (adminState.stores.length === 0) {
        const empty = document.createElement('div');
        empty.style.cssText = 'font-family:Montserrat,sans-serif;font-size:0.95vh;color:rgba(255,255,255,0.25);text-align:center;padding:3vh 0;';
        empty.textContent = t('admin_no_stores', 'No admin stores yet');
        adminStoreList.appendChild(empty);
    }
}

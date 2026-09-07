# Adding Custom Clothing & Generating Images

**A guide for server owners.** No coding required. This explains how to add **more clothing** to your server and how to get **preview images (thumbnails)** for it, including the free **screenshot** tool.

---

## Read this first — how clothing works in ORB Clothing

There are **two separate things**, and it helps to keep them apart:

1. **The clothing items** (the actual garments on the ped) — these come from **add-on / EUP clothing packs**. ORB Clothing does not contain the garments themselves; it **shows whatever your ped supports**.
2. **The preview images** (the little thumbnails in the menu) — these come from the built-in CDN for vanilla GTA clothing, or you **generate them** for add-on clothing.

Two things worth knowing:

- **Vanilla GTA clothing works out of the box**, with images, nothing to do.
- ORB Clothing **counts your clothing automatically** by reading the ped. So when you add an add-on pack, **the new items appear in the menu by themselves** — you never edit counts or lists. You only need to generate their **images**.

---

## Part 1 — Adding more clothing items (add-on / EUP packs)

"Add-on clothing" (also called EUP or MP clothing packs) are normal FiveM streaming resources that add extra tops, pants, shoes, masks, etc. They are made by clothing creators, **not part of ORB Clothing**.

1. Get an add-on clothing pack and drop it into `resources/`.
2. `ensure` it in your `server.cfg` like any other resource (it streams `.ydd` / `.ytd` / meta files).
3. Restart the server.

That's it — the extra items now appear automatically inside the ORB creator and stores, because ORB reads the new item counts from the ped. The only thing missing is their **images** — that's Part 2.

> Follow the pack's own install notes too. Some EUP packs only show for certain jobs or need `eup-ui` / a compatible loader. That behaviour belongs to the pack, not to ORB Clothing.

---

## Part 2 — Getting preview images for your clothing

The default CDN only has images for **vanilla GTA** clothing. For **add-on** items you generate the images yourself. Pick **ONE** of the three options below and set it in `orb-clothing/html/config_ui.js` (that file is editable and survives updates).

### ⭐ Option 1 — orb-greenscreen (easiest, fully automatic)

The free companion **`orb-greenscreen`** photographs every clothing item in-game, and ORB Clothing reads those photos directly. No renaming, no copying, no hosting.

1. Install **`orb-greenscreen`** and `ensure` it in `server.cfg`.
2. Join the server and run the command:
   ```
   /screenshots
   ```
3. A menu opens. Choose what to capture:
   - **Capture EVERYTHING** — all components + props, male **and** female (use this the first time).
   - **Components only** / **Props only** / **Hair only** / **By gender** — for targeted re-captures.
   - **Textures: ON/OFF** — turn ON to also capture every colour/pattern variation (much slower, many more files).
4. Let it run. It photographs each item for both genders and saves the images inside `orb-greenscreen` automatically.
5. **Restart `orb-greenscreen`** so the new images are served.
6. Open `orb-clothing/html/config_ui.js` and set the resource name:
   ```js
   greenscreenResource: 'orb-greenscreen',
   ```
7. **Restart `orb-clothing`.** Done — the creator now shows real thumbnails for every item, add-ons included.

> Capturing EVERYTHING takes a while and makes a lot of images — that's normal. You only do it once, and again whenever you add a new clothing pack.

### Option 2 — Local PNG folder

If you already have PNG images (for example produced by a capture tool):

1. Drop them into `orb-clothing/html/assets/clothing_images/`.
   Filename format: `{model}-{prefix}-{index}.png` (e.g. `mp_m_freemode_01-torso_1-12.png`).
2. In `config_ui.js`, switch the CDN lines to local:
   ```js
   cdnBase:        'assets',
   imageExtension: 'png',
   ```
3. Restart `orb-clothing`.

### Option 3 — Your own CDN (advanced)

For large networks that want to host images themselves:

1. Fork the image CDN repo, generate WebP files, and upload them to jsDelivr / Cloudflare R2 / your own host.
2. Point `config_ui.js` at your host:
   ```js
   cdnBase:        'https://your-host.com/clothing',
   imageExtension: 'webp',
   ```
3. Restart `orb-clothing`.

---

## Which image mode am I using? (quick reference)

| Mode | What to set in `config_ui.js` | Best for |
|---|---|---|
| **CDN (default)** | `cdnBase` = the jsDelivr URL (shipped default) | Vanilla GTA clothing only |
| **Greenscreen** ⭐ | `greenscreenResource: 'orb-greenscreen'` | Add-on packs — easiest, no hosting |
| **Local PNG** | `cdnBase: 'assets'` + `imageExtension: 'png'` | Self-hosted PNG images |

Only one is active at a time. Greenscreen mode takes priority when `greenscreenResource` is set.

---

## Screenshot commands (orb-greenscreen)

| Command | What it does |
|---|---|
| `/screenshots` | **Opens the capture menu** — recommended, pick exactly what you need. |
| `/screenshot` | Capture the full default batch directly. |
| `/screenshothair` | Capture only hair. |
| `/screenshotfemale` | Capture the female set. |
| `/customscreenshot` | Capture a specific component/range (advanced). |

Use `/screenshots` for almost everything — the other commands are shortcuts.

---

## Troubleshooting

**An item shows in the menu but its image is blank.**
That item hasn't been photographed yet. Run `/screenshots` → capture it, restart the image source (orb-greenscreen), and restart orb-clothing.

**Greenscreen mode shows no images at all.**
`greenscreenResource` in `config_ui.js` must **exactly match** the orb-greenscreen folder name. Restart both `orb-greenscreen` and `orb-clothing` after capturing.

**I added a clothing pack but the new items don't appear.**
The pack isn't streaming. Check your server console for errors from that pack, confirm it's `ensure`d, and restart. ORB shows the items automatically once the ped actually has them.

**Colours / patterns (textures) are missing from the thumbnails.**
Turn the **Textures** toggle **ON** in the `/screenshots` menu and re-capture. It's slower and makes many more files, so it's OFF by default.

**Do I need to re-capture after a server restart?**
No. Images are saved to disk. You only re-capture when you **add new clothing**.

---

Made by **TheOrb** · [theorb.tech](https://theorb.tech)

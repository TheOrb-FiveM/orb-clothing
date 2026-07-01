<div align="center">

# ORB Clothing

**Advanced character creator & clothing system for FiveM**

Character creator · Clothing / Barber / Tattoo / Accessories stores · Saved & shareable outfits · In‑game store admin · Multi‑framework · EN / ES

![version](https://img.shields.io/badge/version-1.3.1-00f0ff)
![frameworks](https://img.shields.io/badge/framework-QBox%20·%20QBCore%20·%20ESX%20·%20Standalone-informational)
![deps](https://img.shields.io/badge/deps-ox__lib%20·%20oxmysql-blueviolet)
![license](https://img.shields.io/badge/license-Proprietary-red)

[**🛒 Get it on TheOrb Store**](https://theorb.tech)
[**📃 Docs**](https://theorb.tech/docs/orb-clothing-overview)

![ORB Clothing](https://dunb17ur4ymx4.cloudfront.net/packages/images/71de3a363f9cf17c03cc9e2255803dd0d926f339.png)

</div>

---

## ✨ Features

- 🎭 **Full character creator** — identity, heritage (parents / resemblance / skin tone), face features, hair, makeup, clothing, accessories and tattoos, with an **auto‑framing orbit camera** that focuses the part you're editing.
- 🏪 **Physical stores on the map** — Clothing, Barber, Tattoo parlor and Accessories, with 25+ default locations, blips, interaction zones and per‑player **routing‑bucket privacy**.
- 🛠️ **In‑game store admin (`/storeadmin`)** — create, edit, move, **teleport to** and delete every store from inside the game. The default stores are seeded into the panel on first run — no config editing, no restarts.
- 👕 **Outfits system** — save the current look as a named outfit, wear / rename / delete, and **share an outfit with another player** (they get an accept / decline prompt). Configurable **cost** and **per‑player cap**.
- 🖋️ **Tattoo studio** — hundreds of tattoos by body zone, **live search**, active‑count badge and **real preview thumbnails** served from the CDN.
- 🖼️ **Images from a CDN** — clothing & tattoo previews stream from a CDN. **No image hosting required** for base content.
- 🌍 **Multi‑framework** — auto‑detects **QBox, QBCore, ESX and standalone**. Drop‑in replacement for `qb-clothing` (compat mode keeps apartments, multichar, job uniforms, etc. working).
- 🗣️ **Localization** — ships with **English and Spanish**, switchable with one config line and easy to extend.
- 💰 **Pricing system** — per‑category prices and per‑store multipliers, or free.
- 🔒 **Secure** — server‑side validation on everything (proximity, permissions, ranges, ownership, anti‑spam), proper cleanup and FiveM Asset Escrow ready.

---

## 📦 Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## 🚀 Installation

1. Download and drop the **`orb-clothing`** folder into your `resources/`.
2. Add it to your `server.cfg` **after** its dependencies:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure orb-clothing
   ```
3. **Start the server.** On first boot it automatically:
   - detects your framework (QBox / QBCore / ESX / standalone),
   - creates its database tables (no `.sql` import),
   - seeds the default stores into `/storeadmin`.
4. *(Optional)* set the language in `config.lua`:
   ```lua
   Config.Language = 'es' -- 'en' | 'es'
   ```

> You do **not** need to import SQL, host any images, or set store coordinates by hand.

Framework‑specific integration (multichar / character select) is documented in https://theorb.tech/docs/orb-clothing-overview.

---

## 🎮 Commands

| Command | Permission | Description |
|---|---|---|
| `/storeadmin` | Admin | Open the in‑game store admin panel |

Players open a store by walking into its zone and pressing **E** — no command needed.

---

## 🧩 Framework support

| Framework | Status |
|---|---|
| **QBox** | ✅ Drop‑in |
| **QBCore** | ✅ Drop‑in (replaces `qb-clothing`) |
| **ESX** | ✅ Supported *(esx_skin / skinchanger drop‑in planned — see docs for character‑select integration)* |
| **Standalone** | ✅ Supported |

---

## 🔌 Integration (exports & events)

```lua
-- Open the creator for a new character (optional gender: 'male' | 'female')
TriggerEvent('orb-clothing:client:openForNewCharacter', 'male')

-- Load a saved appearance and apply it (e.g. on character select)
local data = lib.callback.await('orb-clothing:server:loadAppearance', false)
exports['orb-clothing']:setPedAppearance(PlayerPedId(), data)
```

Full events & exports: [`docs/`](docs/).

---

## 🖼️ Add‑on clothing (optional)

Base GTA content works out of the box via the CDN. For custom add‑on clothing you can point the UI at your own CDN, serve images locally, or use the free companion **`orb-greenscreen`** (`/screenshots` menu) to capture them. See https://theorb.tech/docs/orb-clothing-overview

---

## 📄 License

This project is released under a **proprietary license** — you may use and run it on your own server, but **selling, reselling, redistributing or rebranding it is not allowed**. See [`LICENSE`](LICENSE).

The companion tool `orb-greenscreen` is distributed separately under GPL‑3.0.

---

<div align="center">

Made by **TheOrb** · [theorb.tech](https://theorb.tech)

</div>

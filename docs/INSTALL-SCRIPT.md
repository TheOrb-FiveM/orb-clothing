# Installing ORB Clothing

**A guide for server owners.** No coding required. This covers **QBCore** and **QBox** (Qbox). Follow the steps in order.

ORB Clothing is a **drop-in replacement** for your current clothing/appearance script. It brings its own character creator, stores, barber, tattoos and outfits, detects your framework automatically, and creates its own database tables on first start. You do **not** import any `.sql` file and you do **not** host any images.

---

## Before you start

You need these two resources already installed and running (almost every server has them):

- **ox_lib** — https://github.com/overextended/ox_lib
- **oxmysql** — https://github.com/overextended/oxmysql

> ### ⚠️ If your server runs "GTA V Enhanced" (early access)
> ORB Clothing works on both the normal (Legacy) and the new **Enhanced** build, but the Enhanced build had an **engine bug** that crashed the client when opening the character creator (`GetPedHeadBlendData`). Cfx fixed it in the **Enhanced Early Access patch of August 4, 2026**.
>
> **Update your FiveM client and your server artifacts to a build from August 4, 2026 or newer.** If you are on an older Enhanced build you will get a crash creating characters and appearances will not load — that is the FiveM build, not ORB Clothing.

---

## Step 1 — Add the files

Drop the **`orb-clothing`** folder into your server's `resources/` folder (or inside a category folder like `[standalone]` / `[qb]` — anywhere that gets loaded is fine).

---

## Step 2 — Remove your OLD clothing script

You must run **only one** clothing/appearance system. Stop and remove the one your server came with, otherwise you'll get two systems fighting and character creation will misbehave.

| Your framework | Remove this (the default clothing script) |
|---|---|
| **QBCore** | `qb-clothing` |
| **QBox** | `illenium-appearance` **or** `fivem-appearance` (whichever your pack shipped) |

Also make sure none of these are still started anywhere in your config: `qb-clothes`, `rcore_clothes`, `illenium-appearance`, `fivem-appearance`.

> If one of them is still running, ORB Clothing prints a yellow warning in your server console telling you exactly which one to stop. Watch the console on first start.

You do **not** need to edit any other resource (jobs, apartments, prison, admin menu). ORB Clothing answers the old `qb-clothing` events for them automatically (this is "Compat Mode", already ON by default).

---

## Step 3 — Edit your `server.cfg`

Make sure ORB Clothing starts **after** its dependencies:

```cfg
ensure ox_lib
ensure oxmysql
ensure orb-clothing
```

Remember to also **delete the `ensure` line of your old clothing script** (the one from Step 2).

---

## Step 4 — Start the server and test

On the **first start**, ORB Clothing automatically:

- detects your framework (QBox / QBCore / ESX / standalone),
- creates its database tables (no SQL import),
- seeds the default stores into the map and into `/storeadmin`.

Then check the two things that matter:

1. **Make a new character.** Go through your multicharacter screen and create one — the ORB creator should open by itself.
2. **Walk into a clothing store** on the map and press **E** — the store menu should open.

If both work, you're done. ✅

---

## Step 5 — (Only if you already had players) Migrate their old looks

If this is a brand-new server, **skip this step**.

If players already had saved characters from your old clothing script, run this **once** in your **server console** to import their existing looks:

```
migrateclothing
```

It reads your existing `playerskins` / `character_appearance` data (qb-clothing, illenium-appearance, fivem-appearance or qs-appearance) and converts it to ORB's format. It is safe to run; already-migrated players are skipped automatically. (`migrateqb` and `migrateqs` are the same command under different names.)

---

## Optional settings — `config.lua`

Everything works out of the box. Open `config.lua` only if you want to change something:

| Setting | What it does |
|---|---|
| `Config.Language` | `'en'`, `'es'` or `'de'` for the menu language. |
| `Config.Pricing.enabled` | `true` charges players when they buy clothes at a store; set `false` to make everything free. |
| `Config.Pricing.items` | Price per category (hats, tops, tattoos, …). Set any to `0` for free. |
| `Config.Pricing.currency` | `"cash"` or `"bank"`. |
| `Config.CustomPeds.enabled` | Let players pick any GTA ped model in the full creator. |
| `Config.FrameworkOverride` | Only if auto-detect gets it wrong: `"qbx"`, `"qbcore"`, `"esx"` or `"standalone"`. |
| `Config.HUDOverride` | Only if your HUD isn't hidden correctly in the creator: `"hud_apx"`, `"ps-hud"`, or `false`. |

> `config.lua` is not encrypted — you can edit it freely and it survives updates as long as you keep your copy.

---

## Commands

| Command | Who | What it does |
|---|---|---|
| *(walk into a store + press **E**)* | Players | Open that store. No command needed. |
| `/rs` | Players | Re-apply your saved outfit if another script messed up your character. |
| `/storeadmin` | Admins | Create, move, edit, teleport to and delete stores from inside the game. |
| `/skin [id]` | Admins | Open the full editor on yourself, or on player `[id]`. |
| `/checkskin [id]` | Admins | Show what appearance is actually saved for a player (support tool). |
| `migrateclothing` | Console | One-time import of old looks (see Step 5). |

---

## Framework notes

### QBCore
- ORB Clothing replaces **`qb-clothing`** and announces itself as `qb-clothing`, so `qb-multicharacter`, jobs (`qb-policejob`, `qb-prison`), `qb-apartments`, `qb-houses` and the admin menu keep working without any edits.
- Creating the first character on the multichar screen opens the ORB creator automatically.

### QBox (Qbox)
- QBox usually ships with **`illenium-appearance`** (or `fivem-appearance`) as its clothing — remove that one in Step 2, **not** `qb-clothing`.
- Works automatically with **`qbx_core`** multicharacter and with **`qbx_properties`** apartment spawns (both trigger the standard new-character handoff, which ORB answers by default).
- If for any reason the framework is detected as something else, set `Config.FrameworkOverride = "qbx"` in `config.lua`.

---

## Troubleshooting

**The creator crashes when I create a character / appearances don't load, and I'm on the Enhanced build.**
This is the FiveM Enhanced early-access engine bug. **Update your FiveM client and server artifacts to an August 4, 2026 build or newer.** (See the warning box at the top.)

**The creator doesn't open when I make a new character.**
Your old clothing script is probably still running and stealing the event. Recheck Step 2 — stop `qb-clothing` (QBCore) or `illenium-appearance` / `fivem-appearance` (QBox), and any of the conflicting scripts listed there. Watch the server console for the yellow "two clothing systems" warning.

**A character spawns in the wrong outfit or as a random ped.**
Have the player run `/rs` once. If it happens to everyone, you likely still have a second clothing/spawn script applying an outfit after ORB — remove it.

**Existing players lost their look after switching.**
Run `migrateclothing` in the server console once (Step 5) to import their old appearances.

**The console says the framework was detected wrong.**
Set `Config.FrameworkOverride` in `config.lua` to `"qbx"`, `"qbcore"`, `"esx"` or `"standalone"` and restart.

---

Made by **TheOrb** · [theorb.tech](https://theorb.tech)

## 23. Monetization

> **Owner:** A14 Social & Economy. **Binding inputs:** canon §C4.1 ("Robux purchases buy cosmetics only … no premium soft
> currency and no paid random rewards"), §C4.7 (capsules are earnable, never sold), §C17.4 (reward vocabulary).
> **Implementation anchors in other sections:** receipt processing §28.18 (`ProcessReceipt`, `rbx:<PurchaseId>`,
> `wallet.receipts`, `MMR_Receipts_v1`), Marketplace screen §24.30, Looks (cosmetic loadouts) §13, restaurant theme
> rules §15, reason code `robux_cosmetic` §29.14.

### 23.1 Purpose and Principles

**Purpose.** Fund the game with purchases that make players *look* ridiculous, never *play* better — so that parents can
trust it, kids never feel pressured, and every leaderboard, showcase and arena match is decided by play.

**Principles (requirements, not tunables):**
1. **Cosmetic-only.** Every Robux product changes appearance, animation or presentation and nothing else: no stats,
   abilities, currency (MB/MS/RT), capsules, parts, staff, offline time, timers, slots that affect play, XP or
   atmosphere beyond the earnable item it skins (§23.4).
2. **No paid randomness at all.** Every product shows exactly what you get before you pay. No loot boxes, no mystery
   bundles, no gacha, no "spin" (§23.8).
3. **Kid-appropriate.** Prices are modest (no single product above 499 R$, no bundle above 799 R$), copy is plain, and the
   art is as kid-safe as the rest of the game (no realistic weapons, no scary themes outside the friendly October event).
4. **No dark patterns, no FOMO pressure** (table below). Seasonal cosmetics return every year with their event.
5. **Nothing during the tutorial.** The Marketplace is hidden until `QST_TUT_012` is complete and the player is level 5;
   no purchase prompt, store pop-up or "starter pack" ever appears in the first session.
6. **The game is complete without paying.** Every system, tier, recipe, mutation, employee, district, quest and story
   chapter is reachable by play alone (§23.7). Offline earnings never depend on Robux.
7. **Server-authoritative and idempotent.** Grants happen only in `ProcessReceipt` or after `UserOwnsGamePassAsync`
   (§28.18, §29 TM-13); a purchase is never lost and never granted twice.

**Dark patterns we never use:**

| Pattern | Our rule |
|---|---|
| Countdown timers / "only X left" / fake scarcity | Forbidden on every product card (§24.30); rotation exists only in a "Featured" shelf with no timers |
| Premium currency that hides real prices | None — prices are shown in Robux only (§C4.1) |
| Prompts after failure (KO, storm-out, burned dish) | Forbidden; no prompts in combat, in menus opened by the game, or in the first session |
| Confirm-shaming ("No thanks, I like being boring") | Forbidden; the decline button always says "Not now" |
| Pay-to-skip waiting | Nothing to skip: no paid timers exist anywhere |
| Pay-to-win / pay-for-income | Forbidden; stats, currency, staff, caps and atmosphere are never sold |
| Paid random rewards | Forbidden (§23.8) |
| Unclear bundles | Bundles list every item, show "you already own" items, and cost ≤ 80 % of the sum of their unowned parts |
| Social pressure ("your friend bought…") | No purchase broadcasts, no gifting nags, no "rich" leaderboards |
| Ads to children | No immersive ads at launch; any future ad placement requires `PolicyInfo.AreAdsAllowed` and a §38 decision |

### 23.2 Catalog and Robux Price Bands

**Product lines [TUNABLE prices]:**

| Product line | What it is | Delivery | Price band (R$) | Earnable equivalent (so non-payers are never "naked") |
|---|---|---|---|---|
| Morph skins | material/finish overlays applied to mutation parts the player **already owns** (per part, per category or whole morph) | developer product | 149–299 | Starter + earnable palettes (§13), Body Mods MB palettes (2,500–25,000 MB, §13) |
| Colour palettes | swatch packs for the §13 tint system | developer product | 79–99 | 16 starter swatches + quest/event/achievement palettes |
| Restaurant themes | re-skins of walls, floors, counters, stations, sign and façade trim (§15 re-skin rule) | developer product | 299–499 | one earnable theme per season (§33), set façades (§15) |
| Decorative furniture packs | style skins for earnable catalog furniture/decor (§23.4) | developer product | 149–299 | the earnable catalog itself (§36.13) |
| Emotes | animation + sound emotes for the emote wheel | developer product | 49–99 | 26 earnable emotes (§21.8.5) |
| Extra Looks (cosmetic loadout slots) | +4 Look slots each (Looks 3–6, then 7–10, §13) | game pass ×2 | 199 each | Looks 1–2 free, +1 Look from an event reward (§13) |
| VIP Visual Effects | purely visual flourishes (§23.5) | game pass | 399 | earnable titles, palettes, trophy decor |
| Nonessential customization | nameplate styles, restaurant sign fonts and neon colours, plate and tray styles | developer product | 49–149 | default styles + earnable titles |

**Launch catalog (examples; art and final prices in live-ops planning, §34):**

| Product | Line | Contents | Price (R$) |
|---|---|---|---|
| Disco Chrome Finish | Morph skin | mirror-chrome finish for owned ROBOT and OBJECT parts | 249 |
| Lava Lamp Glow | Morph skin | slow animated gradient for any owned part (respects Reduced VFX) | 199 |
| Gummy Glass | Morph skin | translucent candy finish for any owned part | 199 |
| Cardboard Costume | Morph skin | "homemade costume" texture for any owned part | 149 |
| Neon Outline | Morph skin | glowing edge lines (off under Reduced VFX) | 249 |
| Royal Velvet | Morph skin | plush velvet with gold stitching | 299 |
| Sundae Swirl Palette | Palette | 12 dessert swatches | 99 |
| Midnight Diner Palette | Palette | 12 neon-night swatches | 99 |
| Spooky Pastels Palette | Palette (seasonal) | 12 friendly-ghost swatches; on sale every October | 79 |
| Disco Fryer Theme | Restaurant theme | mirror-ball ceiling, checker floor, glitter counters, disco sign | 399 |
| Underwater Galley Theme | Restaurant theme | bubble walls, porthole windows, coral counters | 499 |
| Space Station Snack Bar Theme | Restaurant theme | panel walls, star windows, chrome stations | 499 |
| Haunted Bistro Theme | Restaurant theme (seasonal) | friendly cobwebs, candle lamps, ghost-sheet curtains; every October | 399 |
| Jungle Booth Pack | Decor pack | skins for 6 earnable booth, plant and lamp items | 249 |
| Arcade Corner Pack | Decor pack | skins for 6 earnable table, sign and lighting items | 299 |
| Cozy Lantern Pack | Decor pack | skins for 4 earnable lighting and wall items | 199 |
| Spatula Moonwalk | Emote | moonwalk with spatula flourish | 75 |
| Tray Spin Juggle | Emote | spins three trays on available arms | 99 |
| Dramatic Faint | Emote | cartoon swoon with little tweeting birds | 75 |
| Pizza Toss Dance | Emote | dough-spin dance | 99 |
| Extra Looks I | Game pass | Look slots 3–6 | 199 |
| Extra Looks II | Game pass | Look slots 7–10 (needs Extra Looks I) | 199 |
| VIP Visual Effects | Game pass | §23.5 effects | 399 |
| Nameplate Styles Pack | Customization | 8 nameplate frames | 99 |
| Neon Sign Studio | Customization | 6 sign fonts + 10 neon colours for your restaurant sign | 149 |
| Fancy Plates Pack | Customization | 6 plate and tray styles shown on dishes served in *your* restaurant | 149 |

Every card carries the **COSMETIC** badge and the line "No gameplay effect" (§24.30). Each skin ships in two colourways;
owners of one colourway get the other free (also the fallback for accidental duplicate purchases, §23.12).

### 23.3 Morph Skins and Palettes

**Rules & Mechanics.**
- Skins are **overlays**: they swap `SurfaceAppearance`/`TextureID`/material on the visual MeshParts of parts the player
  owns (§C13.7). They never add parts, slots, geometry that changes silhouettes beyond ±5 %, hitboxes, abilities or stats.
- A skin can be applied per part, per §C13.1 UI group, or to the whole morph, and is saved in the active **Look** (§13).
- Arena and showcase fairness: arena hurtboxes are standard R15 capsules regardless of skins (§21.9.3); showcase theme
  scoring ignores paid overlays (§21.8.6).
- Customer and employee NPCs never wear paid skins (they are procedurally assembled, §8), so paid looks stay personal.
- Palettes extend the §13 swatch grid; Robux palettes may only recolour owned parts (§12 rule).

**UI.** The Marketplace preview (§24.30) renders the player's *current* morph with the skin applied; the Morph screen
shows a "Skins" tab beside "Palettes" with owned skins only and a "Get more" link that opens the Marketplace (no
pop-ups). **Accessibility:** animated and glowing skins respect Reduced VFX (§24) and never flash faster than 3 Hz.

### 23.4 Restaurant Themes and Decorative Furniture Packs

- **Themes are re-skins** (§15): a theme changes the look of walls, floors, counters, stations, the sign and façade trim,
  with identical stats. It **never adds atmosphere, appliance slots, seats or durability** — no pay-for-income.
- **Decor packs are style skins for earnable furniture.** Each pack item is a style variant of an item in the earnable
  catalog (§36.13). The player still buys (MB) and places the earnable item; the skin changes only its look.
- **Atmosphere rule:** a skinned item has **exactly** the atmosphere value, durability and footprint of its earnable base
  item — never higher — and it counts toward the same atmosphere cap of 100 (§C11.4 DecorMult ≤ ×1.2, §22.9.2). Purely
  decorative standalone Robux props (if ever sold) carry **0** atmosphere.
- Theme and skin choices are saved per restaurant layout; tier upgrades carry them to the new shell (§15 migration).
- Co-op visitors see the owner's theme (that is the point of showing off) but cannot change it (§21.3).

### 23.5 Emotes, Looks, VIP Visual Effects and Nonessential Customization

- **Emotes:** go on the 8-slot emote wheel with earnable ones (§21.8.5); same rate limit (1/s) and same no-combat-zone rules.
  Paid emotes never have gameplay hitboxes, never push other players and are silent under "Mute others' emotes".
- **Looks (cosmetic loadout slots):** §13 gives 2 free Looks plus one from an event; the two Extra Looks passes add Looks
  3–6 and 7–10. Looks store appearance only (tints, skins, FX visibility, title, pedestal) and never parts, stats or
  ability order; **functional loadouts (5) stay fully earnable** (§13).
- **VIP Visual Effects pass (399 R$):** sparkle footsteps, a golden glow on the player's own nameplate, a confetti "poof" on
  the Return Door, a VIP pedestal style in the Morph screen and a chat tag. Rules: no VIP-only areas, quests, rewards,
  queues, caps or customers; effects are client-rendered, off under Reduced VFX and can be hidden by any viewer
  (Settings → "Hide others' VIP effects").
- **Nonessential customization:** nameplate frames, sign fonts and neon colours, plate and tray styles in the player's own
  restaurant. Sign text remains player-authored and filtered (§21.6).


## 23. Monetization

> **Binding inputs:** canon §C4.1 ("Robux purchases buy cosmetics only … no premium soft
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

### 23.6 Game Passes vs Developer Products

| Use a… | When | Products | Ownership check | Grant path |
|---|---|---|---|---|
| **Game pass** | a single permanent perk that is the same for everyone and few in number | Extra Looks I, Extra Looks II, VIP Visual Effects | `MarketplaceService:UserOwnsGamePassAsync(userId, passId)` at join (cached for the session, `pcall` + retry 1/2/4 s) and on `PromptGamePassPurchaseFinished` (server re-checks; the client signal alone grants nothing) | no ledger needed: ownership is Roblox's record; perks are recomputed from ownership at every join |
| **Developer product** | the large, growing catalog of individual cosmetics (skins, palettes, themes, decor packs, emotes, customization) | every other SKU | server catalog maps `ProductId → SKU`; owned SKUs live in `inventory.cosmetics` (§28) | `MarketplaceService.ProcessReceipt` → zero-delta `EconomyService:TransactWith` (reason `robux_cosmetic`, key `rbx:<PurchaseId>`) → `InventoryService:GrantCosmetic` (§28.18) |

**Developer products are "consumable" to Roblox but permanent in our game:** the grant writes the SKU into
`inventory.cosmetics`, so it is owned forever, survives server changes, and is restored from the receipt ledger if a
profile is ever rolled back (§28 re-applies receipts newer than a restored version).

**`ProcessReceipt` rules (implemented in §28.18, summarised here):**
1. Player not in this server, profile not loaded, or Safe Mode → `NotProcessedYet` (Roblox re-delivers later).
2. `PurchaseId` already in `wallet.receipts` (ring of 100) or the write-once `MMR_Receipts_v1` ledger → `PurchaseGranted`
   without granting again (**idempotent by PurchaseId**).
3. Unknown `ProductId` → `NotProcessedYet` + engineering alert (never guess a grant).
4. Otherwise grant inside one `TransactWith` critical section (cosmetic + receipt record), then `SaveNowAsync`; return
   `PurchaseGranted` **only after the save commits**, else `NotProcessedYet` (the item stays visible in-session).
5. Purchases are requested through the server: the client calls `Market.RequestPurchase {sku}`; the server checks the
   Marketplace is unlocked (§23.1 rule 5), the SKU is on sale and **not already owned**, then calls
   `MarketplaceService:PromptProductPurchase(player, productId)` or `PromptGamePassPurchase`.
6. **No gifting** of Robux items between players (consistent with §22.14.4); there is no trade or resale.

### 23.7 Exclusively Earnable — Never Sold for Robux

The following are obtainable **only** through play. No developer product, game pass, bundle, season track or promotion may
grant, accelerate, discount or unlock them (audited per AC-23-03 and §35 TC-MUT-13):

| Category | Items |
|---|---|
| Currencies | Morph Bucks, Mutation Shards, Research Tokens (§C4.1) — no premium currency exists |
| Mutations | every gameplay mutation part `MUT_001`–`MUT_280` (incl. FX and Secret parts), their stats, abilities, passives, upgrade levels, duplicates, Lab fusions, Mystery Market access and rotations |
| Morph Capsules | all capsules, their odds and the pity counter (§C4.7) |
| Employees | hiring, rerolls, training, promotions, raises, managers and therefore **offline caps** (§C14.3) and offline income |
| Restaurant | tiers and City Hall permits (§C6), stations and station levels, appliance/menu/seat capacity, earnable furniture and its atmosphere and durability, repairs |
| Recipes | every recipe `RCP_*` and its learning |
| Progression | XP, levels, stat points, skill points, stat and skill respecs (no paid respec), achievements, milestones, titles |
| Quests & story | all quests, story chapters, event participation and event rewards |
| Trophies | `FRN_901`–`FRN_910` (§C16.6) |
| Social & arena | arena ratings, brackets, season rewards, showcase wins, co-op rewards, the 26 earnable emotes (§21.8.5) |
| Customization basics | 5 functional loadouts, Looks 1–2 (+1 event Look), starter and earnable palettes, Body Mods MB palettes |
| Travel & access | every district, Metro station, building and event (no paid areas, no paid queue priority) |

### 23.8 Paid Random Items: None

- **Policy:** the game sells **no paid random items** of any kind (§C4.1). Morph Capsules are earnable only, their odds are
  always disclosed in the UI and the pity counter persists (§C4.7). The Marketplace never shows a "mystery" product.
- **Future-proofing (required if this policy is ever revisited through §38):**
  1. Call `PolicyService:GetPolicyInfoForPlayerAsync(player)` on join (wrapped in `pcall`; on failure assume the **most
     restrictive** policy) and cache it for the session.
  2. If `ArePaidRandomItemsRestricted` is `true`, the product is hidden and not purchasable for that player (server-
     enforced in `Market.RequestPurchase`, not just hidden in UI).
  3. Odds for every possible outcome must be shown on the product card **before** the purchase prompt, as percentages that
     sum to 100 %, with no hidden rarity tiers, no dynamic odds and the same odds for every player.
  4. The realised distribution is audited with the §22.15 χ² check; any pity rule is disclosed.
  5. Random items could still never contain stats, currencies, capsules or anything listed in §23.7.
- Other `PolicyInfo` fields: `IsPaidItemTradingAllowed` is irrelevant (no trading); `AreAdsAllowed` gates any future ad
  placement; `AllowedExternalLinkReferences` — the game shows no external links.

### 23.9 Premium Payouts

Roblox Premium Payouts reward engagement time of Premium subscribers, which suits a game built around daily returns and
long, relaxed sessions. Rules:
- **No Premium-only gameplay**, areas, currency, caps or offline bonuses. Premium members may receive one cosmetic
  welcome gift (a palette) detected via `player.MembershipType == Enum.MembershipType.Premium` and
  `Players.PlayerMembershipChanged`.
- `MarketplaceService:PromptPremiumPurchase` is called **only** when the player taps the neutral "About Premium" info
  button in Settings — never automatically.
- Engagement is pursued through fun (co-op, events, offline return loop), never through manipulative retention mechanics
  (no streak-loss punishment beyond the gentle login streak in §20, no "you'll lose your stuff" messaging).

### 23.10 Revenue Expectations (hypotheses, to be validated)

All values below are **hypotheses** for planning, not commitments; live telemetry (§31) replaces them within 4 weeks of
launch.

```
MonthlyRobux ≈ MAU × PayerConversion × ARPPU_month + PremiumPayouts
```

| Hypothesis | Low | Base | High | Rationale |
|---|---|---|---|---|
| Payer conversion (monthly payers ÷ MAU) | 1.0 % | 2.0 % | 3.0 % | cosmetic-only catalog, young audience, no random items |
| ARPPU per month (R$) | 200 | 325 | 450 | typical basket: one theme or VIP + a skin or emote |
| Premium Payouts share of total Robux | 20 % | 30 % | 40 % | engagement-heavy design (daily returns, long sessions) |
| Top-selling lines (share of product revenue) | — | themes 30 %, skins 25 %, VIP 15 %, Looks 10 %, emotes 10 %, other 10 % | — | showing off restaurants and morphs to friends |
| Example at 100,000 MAU (base) | — | 100,000 × 2 % × 325 = 650,000 R$ + ≈ 280,000 R$ Premium Payouts ≈ 930,000 R$/month | — | — |

**Decision rules:** if conversion is below the low case, improve catalog breadth, previews and show-off moments (photo mode,
showcases) — **never** add pressure, timers or power. If any cohort shows spend concentration (top 1 % of payers > 50 % of
product revenue) the catalog is reviewed for kid-appropriateness. Revenue goals never override §23.1.

### 23.11 Roblox Implementation

- **Catalog config:** `ReplicatedStorage/Shared/Config/Marketplace` (display) and a server-only mirror with
  `ProductId`/`PassId` ↔ SKU, line, price band, colourways, seasonal window and `onSale` flag; the build validator (§35)
  fails if a SKU references anything in §23.7 or lacks the COSMETIC flag.
- **Remotes:** `Market.RequestPurchase` (RF C2S `{ sku }`, 0.5/s b2) and `Market.OwnershipChanged` (Event S2C); grants only
  from `ProcessReceipt` / pass checks (§29 TM-13).
- **Unlock gate:** `Market.RequestPurchase` returns `LOCKED` until `QST_TUT_012` is complete and level ≥ 5; the Marketplace
  button is hidden until then.
- **Spending summary for families:** Settings → Account lists the player's Robux purchases in this game (from
  `wallet.receipts` and `MMR_Receipts_v1`: date, item, price) — transparency for parents; Roblox's own parental spend
  controls always apply.
- **Analytics:** `mmr_market_view`, `mmr_market_preview`, `mmr_market_prompt`, `mmr_market_purchase` (sku, line, price),
  `mmr_market_cancel` (§31); purchases are excluded from the §29.14 income anomaly metric.

### 23.12 Edge Cases

| # | Situation | Expected behaviour |
|---|---|---|
| 1 | Receipt arrives while the player is in another server or offline | `NotProcessedYet`; Roblox re-delivers when the player is in a server with the profile loaded (§28.18). |
| 2 | Save fails after the grant | Item visible in-session; `NotProcessedYet` until a save commits; never granted twice (`rbx:` key + receipt ring + ledger). |
| 3 | Same receipt delivered three times | Granted once; later deliveries return `PurchaseGranted` immediately (§35 TC-DATA-11). |
| 4 | Accidental duplicate purchase of an owned SKU (race across two devices) | Server pre-check normally blocks it; if both receipts arrive, the second grants the item's alternate colourway (still cosmetic, never currency) and support is flagged. |
| 5 | Game-pass ownership check fails at join (Marketplace outage) | Perks default off, retry 1/2/4 s and on next join; no permanent loss. |
| 6 | Profile rolled back to an older version | All receipts newer than the restored version are re-applied (§28). |
| 7 | Hostile customer auto-closes the Marketplace mid-purchase (E2) | Roblox's prompt is CoreGui and stays up; the result arrives as a toast (§24.30). |
| 8 | Player under a policy that restricts a product type | `PolicyInfo` hides it and the server refuses the request. |
| 9 | Seasonal product outside its window | Not purchasable; owners keep it forever; it returns next year (no permanent scarcity). |
| 10 | Chargeback / refunded purchase reported by Roblox | The cosmetic is not revoked automatically (kid-friendly); repeated abuse is handled by moderation (§29.17). |
| 11 | Paid skin on a part that is later unequipped or fused | The skin stays owned and can be applied to any other owned part. |
| 12 | Theme applied, then the restaurant upgrades tier | Theme carries to the new shell; unmatched pieces fall back to default looks without loss (§15). |

### 23.13 Acceptance Criteria

- **AC-23-01:** No Robux product changes any number used by gameplay (stats, damage, cooldowns, atmosphere, seats, slots,
  income, XP, odds, timers) — verified by diffing a full gameplay-state snapshot before and after granting every SKU.
- **AC-23-02:** The catalog contains no random-outcome product; every product card lists its exact contents before the
  purchase prompt opens.
- **AC-23-03:** An automated audit finds 0 products or passes that grant MB, MS, RT, capsules, mutation parts, employees,
  offline time, recipes, skill points, respecs or anything in §23.7 (shared with AC-01-02, AC-12-09).
- **AC-23-04:** The Marketplace button is hidden and `Market.RequestPurchase` returns `LOCKED` until `QST_TUT_012` is complete
  and the player is level ≥ 5; no purchase prompt appears in a player's first session (funnel test).
- **AC-23-05:** No product card shows a countdown timer, stock counter or urgency text; every card shows the COSMETIC badge.
- **AC-23-06:** No single product costs more than 499 R$ and no bundle more than 799 R$; bundles cost ≤ 80 % of their unowned
  contents.
- **AC-23-07:** Replaying a `ProcessReceipt` delivery for the same `PurchaseId` 3 times grants the cosmetic exactly once and
  returns `PurchaseGranted` only after the grant is saved (with AC-28-06, TC-DATA-11).
- **AC-23-08:** Game-pass perks are granted only after a server-side `UserOwnsGamePassAsync` returns true; a forged
  `PromptGamePassPurchaseFinished` grants nothing.
- **AC-23-09:** A skinned furniture item has exactly the atmosphere, durability and footprint of its earnable base item, and
  Robux themes add 0 atmosphere (unit test over every decor/theme SKU).
- **AC-23-10:** Arena hurtboxes and showcase theme scores are identical with and without paid skins (§21.9.3, §21.8.6).
- **AC-23-11:** `PolicyService:GetPolicyInfoForPlayerAsync` is called once per session with a most-restrictive fallback, and
  any product restricted by policy is refused server-side.
- **AC-23-12:** Seasonal cosmetics are offered again at their next yearly event (catalog schedule check).
- **AC-23-13:** `PromptPremiumPurchase` is only reachable from the Settings "About Premium" button; no Premium-only gameplay
  exists (code search + UI audit).
- **AC-23-14:** The Settings spending summary lists every Robux purchase in this game with date, item and price within 2 s.

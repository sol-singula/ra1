## 33. Content Expansion

> **Owner:** A1 Vision & Onboarding. This section covers how Mystery Morph Restaurant grows after launch: eleven
> expansion mini-designs, the identifier plan for new content, a 12-month roadmap, the live-ops cadence, and the
> data-driven pipeline that lets content ship without code changes. Launch scope and phases are in §34, and the
> economy validation of each drop is in §22.

### 33.1 Purpose and Expansion Laws

**Purpose.** Keep players returning for a year or more by adding *reasons to morph, cook and explore*, without
breaking the economy, the canon identifiers, or the kid-safe tone.

**Expansion laws (binding on every content drop).**
1. **Morph-first.** Every monthly drop adds mutation parts (Law L1, §2.9). The morph is the retention engine.
2. **No power creep beyond the budget formula.** New parts use canon C13.4 budgets, there is no 8th rarity, and new
   abilities fit the §11 damage and cooldown envelope for their rarity.
3. **No new currencies.** MB, MS and RT only (canon C4.1). Event progress is a *track* (milestone bar), never a
   spendable token.
4. **No paid power, no paid randomness.** Robux content is cosmetic (§23). Themes reskin and never add Atmosphere
   beyond the equivalent earnable item.
5. **Nothing permanently missable that matters.** Seasonal parts return every year and have stat-equivalent
   year-round alternatives in the same slot and tag family.
6. **Every new system declares its offline interaction** (contribution formula, or "none") against canon C15.
7. **Synergies stay automatic.** New parts use existing families, categories and tags (canon C13.5), so they join
   old builds without new synergy rows. Any new family must come with ≥ 2 synergy rows (§36.4).
8. **Kid-safe review, performance budget and accessibility review** before every release (§35).

### 33.2 Expansion Mini-Designs

Each design lists the concept, content, new mechanics, systems touched, effort (S ≤ 2 weeks, M ≤ 6 weeks, L > 6
weeks for a 6-person content team) [TUNABLE], KPI goal and main risk.

#### 33.2.1 New districts

- **Concept:** three districts that each change how you move or cook:
  - **Sunken Snack Reef**: an underwater district reached by submarine-bus. Aquatic parts move faster here.
  - **Mt. Mustard**: a volcanic spice district with heat-hazard kitchens.
  - **Retro Rocket Port**: an alien spaceport selling Alien Cuisine ingredients.
- **Content per district:** 2–3 buildings, 15 NPCs, 12 themed parts, 10 recipes, 8 quests, 1 district event, 1
  Secret part.
- **New mechanics:** a district movement modifier (e.g. "swim" for `aquatic`-tagged parts: MOVE +20 % in water
  volumes) and a district kitchen modifier for a pop-up stall (Mt. Mustard: grill `T_ready` −10 %, burn window −1 s).
- **Systems:** §18 (connections, Metro stations), §19, §20, §30 streaming.
- **Effort:** L each.
- **KPI:** ≥ 60 % of active D7+ players visit the new district within 2 weeks.
- **Risk:** city sprawl and streaming memory on phones. Mitigation: districts load as streaming regions and are
  connected only through the Metro.

#### 33.2.2 Restaurant themes

- **Concept:** full-restaurant themes that reskin furniture, walls, floor, uniforms and music: Haunted Diner, Space
  Station Galley, Pirate Cook-Ship, Candy Castle.
- **Content:** one earnable theme per season (event track reward) and one cosmetic Robux theme per quarter.
- **Rules:** themes are *skins over owned items*. Atmosphere and durability are unchanged. Applying or removing a
  theme is free and instant out of combat.
- **Systems:** §15 (render layer), §23, §25.
- **Effort:** M.
- **KPI:** ≥ 30 % of TIER_03+ players apply a theme within 30 days.
- **Risk:** readability, since station silhouettes must stay recognizable. Rule: station meshes keep their base
  silhouette; only materials, colors and trims change.

#### 33.2.3 Seasonal mutation events

- **Concept:** the three canon seasonal events become tentpole seasons of 2–3 weeks:
  - Haunted Kitchen Night (`EVT_029`), October.
  - Snowmorph Holiday (`EVT_030`), December.
  - Spring Sprout Bloom (`EVT_031`), April.
- **Content:** 10–12 seasonal parts (Common → Legendary, plus 1 seasonal Secret), 5 seasonal recipes, a decor set
  and an earnable theme.
- **Mechanics:** a 30-milestone **Event Track** filled by event quests and seasonal orders. Rewards follow the canon
  C17.4 vocabulary (parts, MS, capsules, trophies). Seasonal parts return each year, and owners keep them forever.
- **Systems:** §18, §20, §36.3, §36.11.
- **Effort:** M per season.
- **KPI:** event participation ≥ 50 % of DAU; D7 during the season ≥ the baseline + 2 pp.
- **Risk:** FOMO pressure. Mitigation: the track can be completed in ≈ 45 min/day over 60 % of the season's days,
  and the Secret condition is skill- or discovery-based, not time-based.

#### 33.2.4 New food categories

- **Concept:** new categories, each with one new cooking verb or station gimmick:
  - **Snack Street** (street food): a skewer station.
  - **Noodle Bar**: a pull-noodle rhythm verb.
  - **BBQ Smokehouse**: a long-smoke station that keeps cooking while you serve.
- **Content:** 10 recipes per category, 6–10 ingredients, 1 station (with the 5 canon C4.9 upgrade levels), 3
  order modifications (§6.18).
- **Rules:** a new category needs a new 3-letter category code. The ID regex in `gdd/tools/gddlib.py` must be
  extended in the same change. Price curve and ingredient cost targets follow canon C4.2.
- **Systems:** §5, §6, §7, §15 (appliance slots).
- **Effort:** L.
- **KPI:** ≥ 40 % of eligible players put ≥ 1 new-category recipe on their menu.
- **Risk:** appliance-slot pressure at low tiers. Mitigation: new stations unlock at TIER_04+.

#### 33.2.5 New employee professions

- **Concept:** new roles that fill gaps:
  - **Entertainer**: boosts Atmosphere while working, offline +3 % DecorMult.
  - **Valet**: queue speed and +1 queue spot online; offline none.
  - **Food Taster**: catches wrong orders before serving; offline accuracy q +0.02.
- **Content:** 1–2 roles per year, 8 archetypes each.
- **Rules:** a new role gets a new `ROLE_` code. Its offline contribution must be expressed as a bounded term in the
  canon C15 formula, and the total remains ≤ 60 % of active per hour.
- **Systems:** §16, §17, §36.8.
- **Effort:** M.
- **KPI:** new-role hire rate ≥ 35 % of eligible players in 30 days.
- **Risk:** offline inflation. Mitigation: §17 regression fixtures must pass before release.

#### 33.2.6 Legendary customers

- **Concept:** rare, named "legend" versions of personalities that visit at most once per day per restaurant, for
  example "The Ancient Karenosaurus Queen" (with a crown and an even bigger handbag) and "The Grand Gourmet
  Gremlin".
- **Content:** 2 per quarter, each with a signature 3-dish order, a unique tantrum chain, and a special reward
  (RT 1–3, a trophy decoration).
- **Rules:** a new personality takes the next `PER_` number (§33.3). A legend appears only at TIER_05+ with
  reputation ≥ 4.0 ★. Its order is always achievable with the player's menu (R-FAIR-3).
- **Systems:** §8, §9, §10, §11.
- **Effort:** M.
- **KPI:** ≥ 70 % of eligible players meet a legend within 7 days of release.
- **Risk:** difficulty spikes. Mitigation: patience multiplier ≥ 1.2 and a telegraphed chain.

#### 33.2.7 Restaurant competitions

- **Concept:** **Row Rumble**, a weekly 15-minute window in which all 8 restaurants on a server compete on a
  *service score* = Σ(S × items) normalized by tier seats and base demand, so a TIER_02 can beat a TIER_08.
- **Content:** weekly rotating rule twists (e.g. "Desserts double points", "Chaos Hour: escalation +25 %"),
  trophies (`FRN_` 911+ range), titles.
- **Rules:** opt-in by keeping your restaurant open during the window. Rewards are MS, capsules and cosmetics, never
  MB multipliers. Guests can help (co-op counts).
- **Systems:** §21, `CityEventService` (§27), §36.11.
- **Effort:** M.
- **KPI:** ≥ 35 % of players online during a window participate.
- **Risk:** toxicity or griefing. Mitigation: no direct interaction between restaurants; scores are server-computed
  (§29).

#### 33.2.8 Co-op cooking tournaments

- **Concept:** weekend brackets in which teams of 2–4 run a tournament kitchen instance (a Showcase Stage `BLD_22`
  variant) through 3 escalating rounds. It is a celebratory echo of the Legendary Chef Tournament (`EVT_005`).
- **Content:** 3 tournament kitchens, 1 season of cosmetic rewards per quarter.
- **Rules:** matchmaking by tier band (T1–3, T4–6, T7–10). Loadout stats are normalized to the band median ± 15 %, so
  skill dominates. Rewards: MS, RT, titles, emotes.
- **Systems:** §21 (matchmaking via `MemoryStoreService` queues, `TeleportService:ReserveServer`), §5, §11.
- **Effort:** L.
- **KPI:** ≥ 25 % of D30 players enter ≥ 1 tournament per month.
- **Risk:** queue times at low concurrency. Mitigation: fill with bot cooks after 60 s.

#### 33.2.9 Mutation discovery events

- **Concept:** **Meteor Hunts**, an extension of the Mutation Meteor Shower (`EVT_006`). Meteor fragments land in
  random districts, and players chain clues to find them.
- **Content:** 1 new Secret discovery condition per hunt, plus community goals ("the whole city finds 10,000
  fragments") that unlock a new part *for everyone* who participated.
- **Rules:** community progress is aggregated cross-server in `MemoryStoreService` sorted maps and committed
  hourly to a DataStore. Secret conditions follow the canon C13.8 style (in-world clues).
- **Systems:** §12, §18, `CityEventService`.
- **Effort:** M.
- **KPI:** participation ≥ 45 % of DAU; the community goal completes in 60–90 % of the planned time.
- **Risk:** guide-site spoilers. Mitigation: per-server seeded fragment positions.

#### 33.2.10 New combat arenas

- **Concept:** new opt-in PvP maps for the Morph Arena (`BLD_08`):
  - **Grease Pit**: slippery floors give `STS_GREASY` zones.
  - **Conveyor Chaos**: moving belts.
  - **Pie Factory**: environmental pie launchers.
- A PvE **Boss Rush** against King Ratbeard (`NPC_020`) variants for players who avoid PvP.
- **Rules:** PvP stays opt-in (§21). Arena-only balance multipliers. Rewards MS and RT by season, plus cosmetics.
- **Systems:** §11, §21, §30 (physics props ≤ 30).
- **Effort:** M per map.
- **KPI:** arena opt-in ≥ 15 % of L12+ players, and Boss Rush ≥ 25 %.
- **Risk:** balance drift in PvP. Mitigation: per-ability arena multipliers held in remote config.

#### 33.2.11 Additional restaurant properties

- **Concept:** a **Food Truck**, a second property that parks in any unlocked district, plus later a **Franchise**
  location. Canon C3 sets one restaurant per player at launch; this expansion adds the second.
- **Rules:**
  - The truck has its own small menu (4 slots), stations (4 appliance slots) and staff (2).
  - It runs its own offline simulation with its own cap.
  - Combined offline net is limited to ≤ 1.3 × the main restaurant's offline net for the same interval [TUNABLE],
    so it adds variety rather than doubling income.
  - Only one property is active (owner-present) at a time.
  - Interiors are instanced as in canon C3.
- **Systems:** §15, §16, §17, §18, §28 (schema adds a `properties[]` array; migration from the single-restaurant
  schema).
- **Effort:** L.
- **KPI:** ≥ 30 % of TIER_05+ players buy the truck within 30 days; the offline-share guardrail (§1.7) still holds.
- **Risk:** economy inflation. Mitigation: the 1.3× cap is enforced in `OfflineEarningsService`.

### 33.3 Identifier Plan for New Content

IDs are permanent, never reused and never renumbered (canon C2, §36.1). New content continues each sequence. The
notation `MUT_nnn` below means "the next free three-digit number". Placeholders are written that way on purpose,
so that no undefined ID appears in this document.

| Family | Launch range (canon / owner) | Expansion continues at | Notes |
|---|---|---|---|
| Mutation parts | 280 parts (canon C13.6) | `MUT_nnn` with nnn ≥ 281; seasonal sets get contiguous blocks of 12 | must use existing slots, categories (C13.2), rarities (C13.3), tag vocabulary (C13.5) |
| Recipes | 150 in 15 categories (canon C10) | per category: BRG / PIZ / DES / DRK continue at 016; TAC / SAN / SOP / PST / BRK / SEA / ALN at 011; SAL / FRI / MUT / LEG at 006 (e.g. `RCP_SEA_nnn`, nnn ≥ 011) | new categories need a new 3-letter code and a validator regex update |
| Ingredients | §7 set | new `ING_` names | tags from the canon C9 vocabulary only |
| Order modifications | §6.18 set | next `MOD_nnn` after §6.18's last | each must name its mechanic |
| Personalities | 32 (canon C11.1) | `PER_nnn`, nnn ≥ 033 (legendary customers included) | combat style from canon C11.6 |
| Abilities | 70 (canon C12.2) | `ABL_nnn`, nnn = 071–099 | animations follow the +300 rule (`ANM_` 371–399). An ability beyond 099 needs a new canon mapping rule |
| Status effects | 20 (canon C12.3) | new `STS_` names | buffs are explicitly marked |
| Districts / buildings | 10 / 22 (canon C16) | `DST_nn`, nn ≥ 11 · `BLD_nn`, nn ≥ 23 | Metro station required per district |
| Named NPCs | §19 range | next `NPC_nnn` after §19's last | |
| City events | 32 (canon C16.5) | `EVT_nnn`, nnn ≥ 033 | Row Rumble, Meteor Hunts and new district events get EVT rows |
| Employee roles / archetypes | 12 roles / §36.8 range | new `ROLE_` names · next `EMP_nnn` | offline term required (Law 6) |
| Offline incidents | §36.9 range | next `INC_nnn` | ≤ 10 % / 15 % bounds apply |
| Furniture / trophies | regular range up to 899; trophies 901–910 | regular `FRN_nnn` ≤ 899; trophies 911–999 | trophies are non-purchasable |
| Synergies / combos | §36.4 / §36.5 ranges | next `SYN_nnn` / `CMB_nnn` | family/category/tag based only |
| Quests | §20 ranges | next `QST_<TYPE>_nnn` per type | tutorial IDs stay fixed |
| Achievements / milestones | §36.16 / §36.17 | next `ACH_nnn` / `MLS_nnn` | |
| Animations / sounds | general up to 300, abilities 301–370 (canon C21); §36.15 | general animations at 400+; abilities 371–399; next `SFX_nnn` / `MUS_nnn` | |
| Restaurant tiers | 10 (canon C6) | **no new tiers planned** | late-game growth comes from properties (§33.2.11), themes and collection |

**Process.** The content designer reserves IDs in the data repo (a pull request adding rows with `status =
"reserved"`). The validator rejects duplicates, gaps are allowed, and deprecated IDs keep their rows with
`deprecated = true`.

### 33.4 12-Month Roadmap

This assumes a September launch. If launch moves, the seasonal months stay pinned to the calendar (`EVT_029` October,
`EVT_030` December, `EVT_031` April), and the other drops slide around them. Content counts are targets [TUNABLE].

| Month | Calendar | Theme | Content drop | Events (canon) | Systems | KPI goal |
|---|---|---|---|---|---|---|
| M1 | Sep | **Grand Opening** | Launch content (§34); first Mystery Market rotations; hotfix cadence | `EVT_003` Citywide Restaurant Rush, `EVT_001` Giant Food Festival | live-ops remote config, dashboards (§31) | D1 ≥ 35 %, tutorial completion ≥ 80 % |
| M2 | Oct | **Spooky-Silly Season** | 12 seasonal parts (bedsheet-ghost family), 5 seasonal recipes, Haunted Diner earnable theme | `EVT_029` Haunted Kitchen Night, `EVT_009` Blackout Night | Event Track v1 | event participation ≥ 50 % of DAU; D7 ≥ 15 % |
| M3 | Nov | **Feast Mode** | New category *Snack Street* (10 recipes, skewer station), 10 FOOD-category parts, 5 employee archetypes | `EVT_001` Giant Food Festival, `EVT_008` Food Critic Convention, `EVT_023` Delivery Frenzy | content pipeline v2 (category codes) | avg session ≥ 22 min |
| M4 | Dec | **Snowmorph Holiday** | 12 winter parts (`ice` tag), 5 recipes, winter decor set (earnable + cosmetic) | `EVT_030` Snowmorph Holiday, `EVT_020` Frozen Snap | co-op tournament closed beta | holiday DAU peak; D30 ≥ 6 % |
| M5 | Jan | **Row Rumble** | Weekly restaurant competitions, 3 trophies, 4 new personalities, legendary customer #1 | `EVT_005` Legendary Chef Tournament, `EVT_027` Downtown Dance-Off | competition scoring, non-pay leaderboards | sessions/DAU ≥ 2.0 |
| M6 | Feb | **Sunken Snack Reef** | District 11 (2 buildings, 15 NPCs), 12 aquatic parts, 10 seafood recipes | `EVT_022` Lost Pet Kraken, `EVT_013` Sewer Flood | swim modifier, district streaming | ≥ 60 % of D7+ visit the new district |
| M7 | Mar | **Arena Season Finale** | 3 arena maps, PvE Boss Rush, 8 new abilities with parts | `EVT_025` Arena Brawl Bash, `EVT_007` Giant Rat King Attack | arena seasons v2, ability animation range | arena opt-in ≥ 15 % of L12+ (never forced) |
| M8 | Apr | **Spring Sprout Bloom** | 12 plant parts, 5 salads, garden decor, first Meteor Hunt | `EVT_031` Spring Sprout Bloom, `EVT_032` Bug Swarm Brunch, `EVT_012` Pickle Rain | community goals (MemoryStore) | parts owned per D30 player +10 % |
| M9 | May | **Franchise Fever** | Food Truck property, 6 truck-only recipes, 2 incident sets | `EVT_023` Delivery Frenzy, `EVT_018` Alien Tourist Season | second property, capped combined offline (1.3×) | offline collect ≥ 95 %; offline guardrail held |
| M10 | Jun | **Co-op Cook-Off** | Co-op tournaments live, Entertainer role + 8 archetypes | `EVT_003` Citywide Restaurant Rush, `EVT_014` Celebrity Chef Visit | team matchmaking, reserved servers | ≥ 25 % of D7 players co-op |
| M11 | Jul | **Mt. Mustard Heatwave** | District 12, 12 fire parts, 10 spicy recipes, legendary customer #2 | `EVT_019` Hot Sauce Heatwave, `EVT_028` Neon Lights Festival | heat-hazard kitchen modifier | D30 ≥ 7 % |
| M12 | Aug | **Morph City's Birthday** | Anniversary part set (top reward Mythic-grade), *Noodle Bar* category, museum anniversary exhibit | `EVT_002` Mutation Parade, `EVT_006` Mutation Meteor Shower, `EVT_021` Morph Swap Hour, `EVT_005` Legendary Chef Tournament | year-2 planning, prestige research | 12-month cohort retention ≥ 2 % |

**Year-one totals (targets):** ≈ +84 parts (≈ 364 total), ≈ +56 recipes (≈ 206 total) in 2 new categories, 2
districts, ≈ 6 personalities, ≈ 13 employee archetypes, 1 role, 3 arenas, 1 property. Every canon event runs at
least twice in the year through the base rotation (§36.11).

### 33.5 Live-Ops Cadence

| Cadence | What happens | Owner |
|---|---|---|
| Daily, 00:00 UTC | Daily quests reset, login streak, daily capsule source (canon C3, C4.7) | `QuestService` |
| Several times daily | Rotating city events from the §36.11 pool (no repeat within 3 days, R-REP-2) | `CityEventService` |
| Weekly, Monday 00:00 UTC | Weekly quests, Mystery Market Legendary rotation (canon C4.5), Row Rumble (from M5), patch notes | `QuestService`, `CityEventService` |
| Bi-weekly | Data-only balance patch through remote config (prices, probabilities, multipliers) | Economy and live ops |
| Monthly | Content update per §33.4 (parts, recipes, NPCs, quests) shipped dark and switched on by flag | Content team |
| Seasonal (Oct / Dec / Apr) | 2–3-week tentpole season with an Event Track | Live ops |
| Quarterly | Major expansion (district, system or property); earnable and Robux themes | Production (§34) |
| Annually (August) | Anniversary, returning seasonal parts on their dates | Live ops |

**Calendar rules [TUNABLE].**
- At most one tentpole season and one major city event run at the same time.
- No two reward-heavy events overlap on the same weekend.
- A 7-day cool-down after a season before the next Event Track.
- Every live event has a kill switch (remote config flag).

### 33.6 Data-Driven Content Pipeline

**Purpose.** Ship most content as data, enabled on a schedule, with automated validation, so that monthly drops
don't need risky code changes.

**Rules & Mechanics.**
1. **Content is data.** Every database (parts, recipes, ingredients, personalities, events, quests, furniture,
   employees, incidents) is authored as JSON in the repository (`gdd/data/<domain>.json` style). A build step
   converts it into typed Luau ModuleScripts under `ReplicatedStorage/Shared/Data/<Domain>`, synced into Studio with
   a file-sync tool such as Rojo.
2. **Content packs.** A drop is a pack with `packId`, `startUtc` and `endUtc` (optional for seasonal packs), a list
   of IDs, and a feature flag. Packs ship *dark* in a normal server update, and the flag turns them on at the
   scheduled time. No update is needed at event start.
3. **Remote config.** Flags and tunables live in a versioned DataStore key. It is polled every 60 s, with a
   `MessagingService` fast path for instant flips (§27). Servers fall back to the bundled defaults if the read fails
   (fail-safe, §27 P7).
4. **Assets.** Meshes and textures are uploaded through Studio or the Open Cloud assets API, and their asset IDs live
   in the data rows. Models are stored in `ServerStorage` and streamed per §30. Every part row references its
   `MMR_` attachment names (canon C13.7).
5. **Validation gates (CI, blocking):**
   - ID uniqueness and reference resolution (the GDD validator style).
   - Mutation stat budgets equal canon C13.4.
   - Morph mesh budgets: ≤ 40 MeshParts / 15,000 triangles for players, ≤ 24 / 6,000 for NPCs (canon C13.7).
   - Recipe stations available at the recipe's unlock level (canon C7.1).
   - Prices within ±15 % of the canon C4.2 curve; ingredient cost 25–40 %.
   - Tags only from the canon C9 and C13.5 vocabularies.
   - Every animation and sound reference resolves (§36.14, §36.15).
   - Every new string has a localization key.
   - The offline simulator regression fixtures pass (§17).
6. **Economy check.** Each pack runs through the §22 simulator. Merge is blocked if any tier's time-to-next-tier
   moves by more than ±10 % or if mutation-acquisition pacing moves by more than ±15 %.
7. **Staging.** A separate staging place in the same universe receives packs first. QA and playtest sign-off are
   recorded in the pack manifest (§35).
8. **Analytics hooks.** Economy and progression events carry `packId` and content IDs in their custom fields
   (`LogEconomyEvent`, `LogProgressionEvent`; schema in §31), so every drop is measured against its KPI goal.
9. **Deprecation.** Content is never deleted. Rows get `deprecated = true`, owners keep their items, and the ID stays
   reserved.

**Roblox implementation sketch.**

```lua
--!strict
-- ReplicatedStorage/Shared/Content/PackGate.lua (excerpt): decides whether a content row is live
local PackGate = {}

export type Pack = { packId: string, startUtc: number, endUtc: number?, enabled: boolean }

function PackGate.isLive(pack: Pack, nowUtc: number): boolean
	if not pack.enabled then
		return false -- kill switch from remote config
	end
	if nowUtc < pack.startUtc then
		return false
	end
	return pack.endUtc == nil or nowUtc < (pack.endUtc :: number)
end

return PackGate
```

The server evaluates `isLive` with `os.time()`. Clients receive only the resulting live ID set, so a client clock
can never unlock content early (§29).

**Edge cases.**
- An event ends while a player is mid-quest: progress is kept, and rewards for completed milestones are claimable
  for 7 days [TUNABLE].
- A pack is disabled by the kill switch: shop rows hide, owned items stay usable, and active event quests freeze
  (they do not fail).
- A player on an old server version: content gates are server-side, so an old server simply doesn't show new
  packs.
- Seasonal Secret conditions are re-armed each year. Players who already own the part get MS instead (canon C4.7
  duplicate rules).

### 33.7 Acceptance Criteria

- **AC-33-01:** Every roadmap month in §33.4 ships ≥ 8 new mutation parts or a documented exception in §38.
- **AC-33-02:** New IDs added after launch never collide with existing ones and follow §33.3. The CI validator rejects a duplicate or reused ID in 100 % of test cases.
- **AC-33-03:** A content pack can be enabled and disabled through remote config in production without a server update. The flip takes effect in all servers within 60 s (5 s via the MessagingService path in ≥ 95 % of servers).
- **AC-33-04:** No Robux product in any expansion grants stats, currency, staff, caps, multipliers or random rewards (re-audit of §23 per drop).
- **AC-33-05:** Each seasonal part set has a stat-equivalent non-seasonal alternative in the same slot and with ≥ 1 shared tag (data lint).
- **AC-33-06:** With the Food Truck owned, combined offline net never exceeds 1.3 × the main restaurant's offline net for the same interval (property test over 10,000 seeded simulations).
- **AC-33-07:** Every content drop passes the §33.6 validation gates and the §22 economy check before release, recorded in the pack manifest.
- **AC-33-08:** Each drop's KPI goal from §33.4 has a dashboard query in §31 before the drop goes live.

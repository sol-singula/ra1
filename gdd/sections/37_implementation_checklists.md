## 37. Implementation Checklists

These checklists convert the design into trackable work items. Each box is closed only when the referenced
behavior exists in a build **and** its tests (§35) pass. Section references point to the specification;
test IDs point to the verification. Counts come from canon and are minimums unless stated. Phase tags
(**P1**…**P5**) say by which roadmap phase (§34) the item must be done.

### 37.1 How to Use

- One checklist per service (§37.2), per content type (§37.3), plus the launch checklist (§37.4) and the
  live-release checklist (§37.5).
- The producer mirrors every top-level box as a tracker ticket; the ticket links the build ID and the
  passing test IDs.
- A box may be marked "N/A" only by the producer with a written reason (e.g. a §34.13 scope cut).
- Checklists are reviewed at every phase gate (§35.12); unchecked boxes tagged with the current phase
  block the gate.

### 37.2 Service Implementation Checklists

#### 37.2.1 `PlayerDataService` (§27, §28)

- [ ] **P1** Profile schema v1 covers progression, currencies, mutation inventory, equipped parts, loadouts, restaurant tier & upgrades, furniture layout, employees & assignments, recipe unlocks, quests, offline-earnings state, achievements (§28).
- [ ] **P1** Session locking on load; a second server cannot load a locked profile (TC-DATA-02).
- [ ] **P1** Autosave every 120 s [TUNABLE]; save on purchases ≥ 10,000 MB, on PlayerRemoving and in BindToClose (TC-DATA-01).
- [ ] **P2** Retry with exponential backoff 1, 2, 4, 8, 16 s (max 5); Safe Mode and 60 s kick on load failure (TC-EDGE-10).
- [ ] **P2** Versioned migrations with fixtures for every prior version; idempotent (TC-DATA-03).
- [ ] **P2** Corrupt-profile detection and last-good restore (TC-DATA-06).
- [ ] **P3** Profile-size budget ≤ 1 MB, typical ≤ 200 KB (TC-DATA-09).
- [ ] **P4** Erasure-request procedure documented and tested (TC-DATA-10).
- [ ] **P5** Production key namespace separate from Dev/Staging; restore runbook rehearsed.

#### 37.2.2 `RestaurantService` (§15, §C3, §C16.4)

- [ ] **P1** Plot assignment on Restaurant Row (`BLD_17`), one per player, 8 per server.
- [ ] **P1** Instanced interior in the far-off Interiors region; door transfer moves player/guest in and out.
- [ ] **P2** Façade upgrades visibly per tier for all clients (TC-BUILD-08).
- [ ] **P2** Closing state on owner disconnect exactly per §C22 E1 (TC-EDGE-01, TC-EDGE-02).
- [ ] **P3** Guest entry/exit and street eject; re-entrant interior lifecycle.
- [ ] **P4** Tier state for `TIER_01`–`TIER_10` applied atomically on upgrade (TC-BUILD-03).
- [ ] **P4** Shutdown persistence per §C22 E13 (TC-EDGE-20).

#### 37.2.3 `OrderService` (§6.18, §8)

- [ ] **P1** Order generation from the menu (avg 1.4 items per customer, 40 % add-on chance; parties order per member).
- [ ] **P1** Tickets on the ticket rail; serve validation against ticket and modifications; plate consumed on serve (TC-ECON-03).
- [ ] **P2** ≥ 20 modifications live; every modification achievable or flagged joke-with-alternative (§6.18).
- [ ] **P2** SOLD OUT for empty special stock; `RCP_BRG_001` auto-fallback when all items are sold out (TC-EDGE-14).
- [ ] **P3** ≥ 75 modifications live.
- [ ] **P4** Alien, Mutation and Legendary ordering rules and legendary dish orders (§6).

#### 37.2.4 `RecipeService` (§6, §7, §C9, §C10)

- [ ] **P1** Recipe and ingredient definitions as data modules generated from the content pipeline.
- [ ] **P2** Learning at the Cooking Academy (`BLD_06`) for 5 × price; L1 recipes known at start (TC-BUILD-11).
- [ ] **P2** Menu-slot limits per tier.
- [ ] **P3** Data validator: price curve §C4.2 (±15 % + rounding), ingredient cost 25–40 % of price, stations available at the recipe's unlock level (§C7.1).
- [ ] **P4** All 150 recipes; Alien Cuisine course gate, `STN_INFUSER` gate for MUT dishes, Legendary Recipe quest gate.

#### 37.2.5 `CookingService` (§5, §C7, §C8, §C4.9)

- [ ] **P1** Station state machines for the 12 starter-kit stations; heat timing model; chopping; quality grades (TC-COOK-01…03).
- [ ] **P1** Per-slot station locks (TC-EDGE-12); carry capacity 1 → hard max 3 (TC-COOK-12).
- [ ] **P1** Server-side timers; client quality ignored (TC-COOK-11).
- [ ] **P2** All 22 non-late stations; station Lv1–Lv3; MIX-by-hand at `STN_PREP` (TC-COOK-09).
- [ ] **P2** Touch, KBM and gamepad schemes; Auto-Rhythm (TC-COOK-04).
- [ ] **P3** Station Lv4; fire & extinguish polish (`ANM_030`); co-op shared items.
- [ ] **P4** Station Lv5 gimmicks; `STN_ANTIGRAV` (L30, `TIER_05`) and `STN_INFUSER` (L40, `TIER_06`).

#### 37.2.6 `CustomerAIService` (§8, §9, §10, §C11)

- [ ] **P1** SPCV: anchored invisible server proxy + client visual built only inside the interior (TC-CUST-11).
- [ ] **P1** State machine states 1–16 and conditional states; patience formula (TC-CUST-01, TC-CUST-03).
- [ ] **P1** Anger meter and levels with escalation rolls (TC-CUST-06, TC-CUST-07).
- [ ] **P2** Satisfaction, payment, tips, jackpot, reputation via formula modules (TC-SAT suite).
- [ ] **P2** Poof rule on path failure (TC-EDGE-16); caps of seats + 4 queue (TC-CUST-04).
- [ ] **P3** 24 personalities; all 7 combat styles; 160-proxy server cap (TC-CUST-05); LOD impostors.
- [ ] **P4** All 32 personalities; chaos level 6 polish; event modifiers.

#### 37.2.7 `CombatService` (§11, §C12, §36.6, §36.7)

- [ ] **P1** `ABL_001`–`ABL_006`; Huff Points; KO/respawn with zero loss (TC-CMBT-07).
- [ ] **P1** Server hit validation and server cooldowns (TC-CMBT-10).
- [ ] **P2** `ABL_007`, `ABL_008`; In Combat flag 6 s (TC-CMBT-08); menu rules E2 (TC-EDGE-03, TC-EDGE-04).
- [ ] **P3** 50 abilities and all 20 status effects with stacking/cleanse per §36.7.
- [ ] **P4** All 70 abilities; environmental combat; protective upgrades; arena rule set.
- [ ] **P4** Kid-safety visual review of every ability and status (TC-CMBT-13).

#### 37.2.8 `MutationService` (§12, §C13, §C4.5–§C4.7)

- [ ] **P1** Ownership, equip rules (level requirements), stat contributions (TC-MUT-01, TC-MUT-03).
- [ ] **P2** Upgrades with MB/MS/RT/duplicate rules (TC-MUT-05, TC-MUT-06).
- [ ] **P2** Earnable capsules with disclosed odds and persistent 40-capsule pity (TC-MUT-07, TC-MUT-08).
- [ ] **P2** Duplicate auto-conversion with "keep" toggle (TC-MUT-09).
- [ ] **P3** Lab fusion (atomic) and Mystery Market rotation (TC-MUT-10).
- [ ] **P4** All 280 parts; 7 secret discovery conditions (§C13.8); Mythic fusion.
- [ ] **P4** Audit: no Robux path grants parts, capsules, MS or RT (TC-MUT-13).

#### 37.2.9 `MorphAssemblyService` (§13, §C13.7)

- [ ] **P1** Hide default R15 meshes; weld parts to `MMR_` attachments; Massless, non-colliding (TC-MORPH-02).
- [ ] **P1** `LegLength` → HipHeight; `NeckLength` → head offset (TC-MORPH-03).
- [ ] **P2** Client SPCV builder with identical output to server build (TC-MORPH-08); loadouts (TC-MORPH-07).
- [ ] **P3** LOD impostor beyond 60 studs; per-frame build budget (TC-MORPH-10).
- [ ] **P4** CI asset-budget validator (≤ 40 MeshParts / 15,000 tris player; ≤ 24 / 6,000 NPC) (TC-MORPH-04).

#### 37.2.10 `EmployeeService` (§16, §C4.8, §C14)

- [ ] **P2** Recruitment board, hire flow, wages from income, Unpaid Break (TC-EMP-01, TC-EDGE-13).
- [ ] **P2** `EMP_001` granted by `QST_TUT_012` with exact canon stats (TC-EMP-03).
- [ ] **P2** Online work AI for 7 roles; per-slot locks shared with players (TC-EMP-08).
- [ ] **P3** All 12 roles; 40 archetypes; repair-job damage absorption per E3 (TC-EDGE-05, TC-EDGE-06).
- [ ] **P4** ≥ 75 archetypes incl. the 7 brief examples; training, promotion, salary, performance reviews.
- [ ] **P4** Manager-based offline caps (TC-EMP-06); no hire/fire currency loop (TC-EMP-11).

#### 37.2.11 `OfflineEarningsService` (§17, §C15)

- [ ] **P2** Canon model with server clock, cap, seed = hash(UserId, lastSimAt, SIM_VERSION) (TC-OFF-01…05).
- [ ] **P2** One session-locked `UpdateAsync` writes the pending report and `lastSimAt`; idempotent Collect with ring buffer of 20 (TC-EDGE-17, TC-EDGE-18).
- [ ] **P2** Welcome Back screen with all 6 buttons (TC-OFF-13).
- [ ] **P3** Pending-report merge with separate caps (TC-OFF-12); ≥ 25 incidents.
- [ ] **P4** ≥ 50 incidents with bounded effects (TC-OFF-07); discoveries (TC-OFF-09); offline/active ratio validated per tier (TC-OFF-10).
- [ ] **P5** SIM_VERSION bump procedure documented (§39) and tested (TC-EDGE-26).

#### 37.2.12 `EconomyService` (§22, §C4)

- [ ] **P1** Single module that mutates currency; transaction log with reason, delta and balance (TC-DATA-07).
- [ ] **P1** Balance never negative (TC-COOK-10, TC-EDGE-38).
- [ ] **P2** MS sources/sinks; sink/source dashboard.
- [ ] **P3** RT; anomaly detector (MB/h > 3× tier target) (TC-ECON-12).
- [ ] **P4** Price-table validator for furniture, stations, mutations, employees against §C4 bands.

#### 37.2.13 `InventoryService` (§7, §15, §C9)

- [ ] **P1** Furniture inventory (owned vs placed).
- [ ] **P2** Special-ingredient stock in the Pantry; crates from `BLD_03` and `STN_DELIVERY`.
- [ ] **P4** Cosmetics inventory; trophies `FRN_901`–`FRN_910` as non-purchasable rewards.

#### 37.2.14 `QuestService` (§20, §32, §C17)

- [ ] **P2** `QST_TUT_001`–`QST_TUT_012` in order with recovery (TC-QST-01, TC-QST-02).
- [ ] **P2** Daily reset 00:00 UTC, weekly Monday 00:00 UTC (TC-QST-06).
- [ ] **P3** Story chapters 1–6, weeklies, challenge types CHF/CBT/RPR/EXP/EMP/RST, Expansion Permit flow.
- [ ] **P4** Story chapters 7–10; ≥ 100 quests; reward-vocabulary validator (TC-QST-07…09).

#### 37.2.15 `CityEventService` (§18, §36.11)

- [ ] **P3** Single-server prototype of `EVT_003`.
- [ ] **P4** Cross-server schedule via MemoryStore + MessagingService announcements; per-server fallback.
- [ ] **P4** The 20 launch events of §34.12; once-per-user reward claims (TC-ECON-11); mid-event join (TC-EDGE-43).

#### 37.2.16 `MultiplayerService` (§21)

- [ ] **P2** Owner-only interiors; friend-join via TeleportService (TC-MP-02).
- [ ] **P3** Co-op visits, permission matrix, guest rewards, Co-op Insurance (TC-MP-03, TC-EDGE-19).
- [ ] **P4** Casual opt-in arena 1v1/2v2; no PvP outside the Arena (TC-MP-06, TC-MP-07).

#### 37.2.17 `BuildingService` (§15, §36.12, §36.13)

- [ ] **P2** Grid placement with server re-validation (TC-BUILD-06); door-to-seat path validation (TC-EDGE-15).
- [ ] **P2** Appliance-slot accounting (TC-BUILD-04); station availability schedule (TC-BUILD-05).
- [ ] **P3** Decor/atmosphere scoring and DecorMult (TC-BUILD-10).
- [ ] **P4** Tier upgrades with level and permit requirements through `TIER_10` (TC-BUILD-01, TC-BUILD-02).

#### 37.2.18 `RepairService` (§15, §C6)

- [ ] **P2** Five damage states with exact thresholds (TC-DEST-01); Broken = unusable (TC-DEST-02).
- [ ] **P2** Repair minigame on all input modes (TC-RPR-04); Destroyed → rebuild ≤ 25 % (TC-DEST-03).
- [ ] **P3** Employee repair jobs; co-op repair; Co-op Insurance repairs (TC-RPR-10).
- [ ] **P4** Offline damage auto-repair with discount (TC-RPR-08); protective upgrades.

#### 37.2.19 `ProgressionService` (§14, §C5, §C18)

- [ ] **P1** XP curve, levels to 100, 2 stat points per level (max 50 per stat), stat caps with "MAXED".
- [ ] **P2** Respec (free once per 24 h, else 500 MB × level) (TC-ECON-14); level-up toast without modal (TC-EDGE-21).
- [ ] **P3** CHEF, CMBT and RPR trees (≥ 20 nodes each); skill points 1 per level from L2.
- [ ] **P4** SVC and MGMT specializations (≥ 10 nodes each); achievements (§36.16); milestones (§36.17); free tree respec every 7 days.

#### 37.2.20 `UIController` (§24)

- [ ] **P1** HUD, order queue, basic Morph screen, level-up panel.
- [ ] **P2** 18 screens; input-mode adaptation (TC-UI-02); Welcome Back; capsule odds display (TC-UI-07).
- [ ] **P3** 30 screens; city map; quest journal; pseudo-localization pass (TC-UI-05).
- [ ] **P4** ≈ 36 screens; settings persistence (TC-UI-09); full gamepad navigation (TC-UI-08); colorblind review (TC-UI-03).

#### 37.2.21 Cross-cutting (§29, §30, §31, accessibility, localization)

- [ ] **P3** Remote inventory with schema, rate limit and caller rules for every remote (§35.11).
- [ ] **P3** Performance pass 1; **P4** full performance matrix met (§35.10).
- [ ] **P2** Onboarding funnel events; **P4** full §31 schema with ≤ 1 % errors.
- [ ] **P4** Accessibility: KBM, touch, gamepad, Reduced Effects, separate audio sliders, color-independent status, Auto-Rhythm, camera-shake toggle.
- [ ] **P4** All player-facing strings in a LocalizationTable; no text baked into textures; string freeze at W50.
- [ ] **P5** LiveConfig with versioning, kill switches per system, rollback ≤ 15 min (AC-34-35).

### 37.3 Content Production Checklists

#### 37.3.1 Content volume tracker (exact canon counts; minimums where "+")

- [ ] **150 recipes** (§6, §C10): BRG 15 · PIZ 15 · TAC 10 · SAN 10 · SOP 10 · PST 10 · BRK 10 · DES 15 · DRK 15 · SEA 10 · SAL 5 · FRI 5 · ALN 10 · MUT 5 · LEG 5 — every row with all 20 brief fields (Part 4).
- [ ] **75+ order modifications** (§6.18), each achievable or joke-with-alternative.
- [ ] **48 guaranteed core ingredients** (§C9) + every additional ingredient used by a recipe (§7).
- [ ] **280 mutation parts** (§36.3, §C13.6): by rarity Common 63 · Uncommon 84 · Rare 75 · Epic 36 · Legendary 10 · Mythic 5 · Secret 7; by slot HEAD 40 · FACE 8 · NOSE 10 · MOUTH 12 · EYES 14 · EARS 12 · HORNS 12 · NECK 8 · TORSO 22 · ARM 30 · HANDS 10 · LEG 22 · FEET 10 · TAIL 20 · WINGS 12 · BACK 10 · SKIN 6 · FUR 6 · SCALES 6 · FX 10; 62 parts with an active ability.
- [ ] **7 secret discovery conditions** placed in the city (§C13.8).
- [ ] **70 abilities** (§36.6): base kit 8 (`ABL_001`–`ABL_008`) · mutation combat 52 (`ABL_009`–`ABL_060`) · mutation utility 10 (`ABL_061`–`ABL_070`); NPC-tuned variants where a customer can use them.
- [ ] **20 status effects** (§36.7): `STS_STUN`, `STS_DIZZY`, `STS_KNOCKDOWN`, `STS_SLOW`, `STS_STICKY`, `STS_SHOCKED`, `STS_TOASTY`, `STS_FROZEN`, `STS_SOAKED`, `STS_CONFUSED`, `STS_STINKY`, `STS_CHARMED`, `STS_SLEEPY`, `STS_FLOATING`, `STS_WOOZY`, `STS_BLINDED`, `STS_GREASY`, `STS_INSPIRED`, `STS_HYPED`, `STS_SHIELDED`.
- [ ] **32 customer personalities** (§9): `PER_001`–`PER_032`, each with combat style (§C11.6) and all brief Part 5.2 fields.
- [ ] **10 restaurant tiers** (§36.12): `TIER_01`–`TIER_10` with exterior, interior, upgrade animation and the §C6 values.
- [ ] **24 kitchen stations** (§5, §C7) with Lv1–Lv5 visuals and the Lv5 gimmick.
- [ ] **12 employee roles** (§16, §C14.1).
- [ ] **75+ employee archetypes** (§36.8) incl. `EMP_001` and the brief examples: Octopus Chef, Cheetah Waiter, Rhino Security Guard, Spider Repair Technician, Robot Cashier, Sloth Dishwasher, Dragon Chef.
- [ ] **50+ offline incidents** (§36.9) covering all 10 brief categories (angry customers, broken furniture, equipment failure, employee mistakes, ingredient shortages, rushes, inspections, celebrity customers, hero moments, mutation discoveries).
- [ ] **10 districts** (§18): `DST_01`–`DST_10`, with Metro stations.
- [ ] **22 buildings** (§36.10): `BLD_01`–`BLD_22`, each with exterior, interior, NPCs, services and UI.
- [ ] **100+ named NPCs** (§19): `NPC_001`–`NPC_030` fixed + ≥ 70 more.
- [ ] **100+ quests** (§20): `QST_TUT_001`–`QST_TUT_012` + story (10 chapters) + daily + weekly + CHF, CBT, RPR, EXP, EMP, RST challenges.
- [ ] **32 city events** (§36.11): `EVT_001`–`EVT_032` designed; 20 live at launch (§34.12).
- [ ] **150+ animations** (§36.14) incl. the 52 fixed core IDs of §C21, plus the 70 ability animations (one per `ABL_` row).
- [ ] **150+ sounds** (§36.15): kitchen, customer voice blips, creature noises, combat, destruction, repair, currency, level-up, mutation unlock, city ambience, restaurant music.
- [ ] **100+ furniture & equipment items** (§36.13) + 10 trophies `FRN_901`–`FRN_910` (non-purchasable).
- [ ] **75+ mutation synergies** (§36.4), defined on families/categories/slots/tags only.
- [ ] **100+ morph combination examples** (§36.5).
- [ ] **≥ 80 skill nodes** (§14, §C18): CHEF ≥ 20, CMBT ≥ 20, RPR ≥ 20, SVC ≥ 10, MGMT ≥ 10.
- [ ] Achievements (§36.16) and milestones (§36.17) at the counts their sections define.

#### 37.3.2 Per-asset checklists (definition of ready → done)

**Mutation part**

- [ ] Data row complete in §36.3 (unlock, acquisition code, stats summing to the §C13.4 budget, passive, active, upgrade levels, balance limits).
- [ ] Mesh on the 0.25-stud grid at R15 scale; within its share of the 40-MeshPart / 15,000-tri player budget; NPC variant ≤ 6,000-tri visual budget.
- [ ] Correct `MMR_` attachment(s); `LegLength`/`NeckLength` attribute where applicable; ARM/LEG mirror tested.
- [ ] SKIN/FUR/SCALES surface variants authored; FX part has no stats.
- [ ] Rarity icon uses color + shape; inventory thumbnail rendered.
- [ ] Active ability hooked (animation + VFX + sound described in §26); paired bonus for arms/legs if any.
- [ ] Verified in the morph test scene with ≥ 5 reference combos (TC-MORPH-09); kid-safety checklist §37.3.3 passed.
- [ ] Display name, description and ability text in the LocalizationTable.

**Recipe**

- [ ] Row complete in §6 (20 brief fields); price within §C4.2 ±15 %; ingredient cost 25–40 %.
- [ ] Uses only stations available at its unlock level (§C7.1); special ingredients flagged for stock.
- [ ] Dish model composed from ingredient meshes where possible; PERFECT/BURNED/UNDERCOOKED reads at 10 studs on a phone.
- [ ] Assembly order defined for stacked dishes; plating visual; mutation interactions noted.
- [ ] Localization strings; tutorial or learning path assigned.

**Customer personality**

- [ ] Row complete in §9 (patience multiplier, preferences, thresholds, anger probability, combat style, spending, tips, animations, dialogue, specials).
- [ ] Dialogue lines kid-safe, no real groups targeted; voice-blip set assigned (§26).
- [ ] Combat style AI tested at anger levels 3–5 (TC-CUST-09 for PACIFIST types).

**Ability / status effect**

- [ ] Row complete in §36.6 / §36.7 (cooldown, damage, range, animation, effects, balance, counters / duration, magnitude, stacking, cleanse).
- [ ] Ability animation present; VFX respects Reduced Effects; status icon has a unique shape.
- [ ] Server validation (range, cooldown) and NPC-tuned variant tested.

**Employee archetype / offline incident**

- [ ] Archetype: role, rarity band (§C4.8), stats within band, traits, mutation look, personality, potential.
- [ ] Incident: weight, conditions, bounded effect, report text; contributes to the ≤ 10 % / ≤ 15 % caps.

**NPC / quest / event**

- [ ] NPC: morph, location, role, dialogue, quest hooks, interaction behavior (§19).
- [ ] Quest: objectives, prerequisites, completion conditions, rewards within the §C17.4 vocabulary, failure conditions (§20).
- [ ] Event: schedule, rules, rewards, server-load budget (§36.11); tested in P-04.

**Furniture / animation / sound / UI screen**

- [ ] Furniture: price, Atmosphere value, durability, five damage-state visuals, destruction and restoration animation, footprint.
- [ ] Animation: plays on extreme morph combos without rig breakage; loop points clean; priority set.
- [ ] Sound: normalized loudness, category bus assigned (music/SFX/voice), no copyrighted samples.
- [ ] UI screen: phone, tablet, PC and console layouts; gamepad navigation; pseudo-localized; colorblind-safe.

#### 37.3.3 Art style and kid-safety sign-off checklist (art director + producer)

- [ ] No blood, gore, death or realistic weapons; defeat shown as "Seeing Stars"/"Dizzy".
- [ ] Damage feedback limited to cartoon stars, feathers, sauce splats, confetti and soot puffs; `STS_TOASTY` is soot, never flames on bodies.
- [ ] "Gross" foods are kid-friendly versions (gummy eyeballs, squishy tentacles, candy bug crunch, fruit-jelly slime).
- [ ] No real brands, logos, copyrighted characters or real people; no mean-spirited humor about real groups.
- [ ] Silhouettes readable at 30 studs on the low-phone class; status never conveyed by color alone.
- [ ] Destroyed objects become cartoon rubble, never permanently lost.

### 37.4 Launch Checklist (Roblox Experience Settings and Operations)

#### 37.4.1 Experience basics

- [ ] Experience name, description and genre set (Simulation / tycoon-style per current Roblox taxonomy); description accurate (no misleading claims).
- [ ] Icon and ≥ 5 thumbnails created from real gameplay; comply with Roblox thumbnail policy.
- [ ] Supported devices: Computer, Phone, Tablet, Console (VR off) — console only if TC-UI-08 passes (OD-16).
- [ ] Avatar settings: R15 enforced; collision and scaling compatible with the morph rig (§C13.7).
- [ ] Access set to Public only at M5c; copying disabled; third-party sales and teleports off unless required.

#### 37.4.2 Maturity, age and content compliance

- [ ] Maturity & Compliance Questionnaire completed honestly; expected label **Mild** (repeated cartoon violence, no blood) — confirm per OD-09.
- [ ] Re-check Roblox's current age-access rules for the resulting label before launch and record the outcome.
- [ ] Kid-safety checklist §37.3.3 signed for every asset class.
- [ ] Earnable Morph Capsules display odds in-game (§C4.7); no paid random items exist.

#### 37.4.3 Privacy, safety and communication

- [ ] Text chat through `TextChatService` with Roblox filtering; in-restaurant chat behavior per OD-10.
- [ ] All user-entered text (restaurant names, morph names, loadout names, signs) filtered with `TextService` before storage and display (TC-MORPH-11, TC-MP-08).
- [ ] Voice chat setting per OD-06.
- [ ] No collection of personal data; analytics events contain no free text or personal data (§31).
- [ ] No external links in-game; social links only through Roblox's experience social-link feature, respecting platform age rules.
- [ ] Data-erasure request procedure live (TC-DATA-10).

#### 37.4.4 Monetization setup (cosmetics only, §23)

- [ ] Developer products and game passes created for cosmetics only; price list approved.
- [ ] `ProcessReceipt` idempotent by PurchaseId; grant saved before returning `PurchaseGranted` (TC-DATA-11).
- [ ] `PolicyService:GetPolicyInfoForPlayerAsync` checked (paid random items and paid-item trading restrictions honored; none offered).
- [ ] Audit confirms no Robux path to mutations, capsules, MB, MS, RT, offline caps or power (TC-MUT-13).
- [ ] Private-server pricing per OD-12; Premium benefits per OD-21.

#### 37.4.5 Servers and places

- [ ] Max players per server = 8 (§C3) in place settings; server-fill and reserved-slot policy per OD-13.
- [ ] Workspace StreamingEnabled with interiors and districts configured per §30.
- [ ] Dev, Staging, Production experiences separated; Studio API access to Production DataStores disabled.
- [ ] Team Create permissions reviewed; only release managers can publish to Production.

#### 37.4.6 Localization

- [ ] English source strings complete in the LocalizationTable; string freeze honored since W50.
- [ ] Reviewed translations for the launch languages of OD-18; automatic translation enabled for the rest.
- [ ] Pseudo-localization pass clean on all screens (TC-UI-05).

#### 37.4.7 Data, live ops and support readiness

- [ ] LiveConfig production defaults equal the §39 values; kill switches per system tested.
- [ ] Rollback rehearsal ≤ 15 min (AC-34-35); previous place version tagged.
- [ ] Dashboards live: CCU, D1/D7/D30, crash-free, DataStore errors, economy sinks/sources, offline ratio.
- [ ] On-call rota for launch + 14 days with S0 response ≤ 1 h (AC-34-34).
- [ ] Player-facing status channel (group shout / experience update notes) and support macros prepared.

#### 37.4.8 Go / No-Go sign-off

- [ ] G5 gate evidence complete (§35.12).
- [ ] Producer sign-off · Lead engineer sign-off · Designer sign-off · Art director kid-safety sign-off.

### 37.5 Live-Release Checklist (every Phase 6 release)

- [ ] Release notes drafted; LiveConfig diff reviewed by designer and lead engineer.
- [ ] Live-patch test suite passed (§35.9); no open S0, no new S1 (G6).
- [ ] New remotes added to the remote inventory with schema and rate limit.
- [ ] Schema migration (if any) tested on fixtures and gated behind a flag.
- [ ] SIM_VERSION bumped if any offline parameter changed; goldens re-approved.
- [ ] New content passes its §37.3.2 checklist and the kid-safety checklist.
- [ ] Rollback plan and owner named; monitoring window (2 h) staffed after publish.

### 37.6 Phase Gate Checklists

**G1 — Core Prototype (W12)**

- [ ] AC-34-01…AC-34-06 evidenced (playtest sheet, CI run, capture files).
- [ ] All P1-tagged boxes of §37.2 closed.
- [ ] Style guide v1 approved; rig/attachment contract validated with 30 parts.
- [ ] Risk register (§34.14) reviewed; Phase 2 plan re-baselined.

**G2 — Vertical Slice (W25; MVP check at W19)**

- [ ] Every row of the MVP table (§34.4) implemented by W19 (AC-34-07…AC-34-12).
- [ ] Vertical-slice content list (§34.6.2) complete (AC-34-13…AC-34-18).
- [ ] TC-EDGE-01…TC-EDGE-21 pass; offline goldens committed.
- [ ] Contract art pipeline delivering on schedule (≥ 80 % batches accepted on time).

**G3 — Alpha (W41)**

- [ ] All P3-tagged boxes of §37.2 closed; AC-34-19…AC-34-24 evidenced.
- [ ] Content counts at the Alpha column of §34.11.2.
- [ ] Remote inventory complete; exploit pass 1 complete.
- [ ] Economy simulation within ±20 % of §C4.4 pacing to `TIER_06`.

**G4 — Beta (W55)**

- [ ] §37.3.1 volume tracker 100 % checked (launch scope) and every item passed its §37.3.2 checklist.
- [ ] AC-34-25…AC-34-30 evidenced; full performance matrix met.
- [ ] External exploit review closed with 0 open S0/S1.
- [ ] Localization string freeze held since W50.

**G5 — Launch (W59)**

- [ ] §37.4 launch checklist 100 % checked and signed.
- [ ] AC-34-31…AC-34-35 evidenced; soft-launch metrics green.

### 37.7 Acceptance Criteria

- **AC-37-01:** Every service in §C19 has a checklist in §37.2 with phase tags and at least one linked test ID per box where a test exists.
- **AC-37-02:** The §37.3.1 tracker lists every canon content count (recipes, parts, abilities, statuses, personalities, tiers, stations, roles, archetypes, incidents, districts, buildings, NPCs, quests, events, animations, sounds, furniture, synergies, combos) with the canon number.
- **AC-37-03:** No gate closes while a box tagged with that gate's phase is unchecked and not marked N/A by the producer.
- **AC-37-04:** The launch checklist (§37.4) is fully checked and signed before Access is set to Public.


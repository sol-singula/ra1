# MYSTERY MORPH RESTAURANT — DESIGN CANON (Single Source of Truth)

> **Every contributor must read this file in full before writing.** It fixes identifiers, master
> content lists, global constants, and core formulas so that all 40 sections of
> `MYSTERY_MORPH_RESTAURANT_GDD.md` agree. If your section needs a value defined here, **use this
> value**. If you need something not defined here and it belongs to *your* domain, define it in your
> own section. Never invent an ID in another contributor's domain (see §C1 ownership).
>
> Values marked **[TUNABLE]** are balancing assumptions: you must keep them as stated (so systems
> agree) but you may describe how they would be tuned.

---

## C0. Contributor Rules (Style & Format Contract)

1. **Headings.** Your file's first line is the section heading exactly as allocated in §C1, as an H2:
   `## 5. Cooking Mechanics`. Subsections are H3 `### 5.1 Title`, then H4/H5 freely. Never emit an H1.
   Files that contribute subsections to another file's section (e.g. `06b_...`, `12b_...`, `36_xx_...`)
   start with their allocated H3 heading instead of an H2.
2. **Template for every major system** (use these labelled sub-blocks, in this order, wherever a system
   is specified): **Purpose · Rules & Mechanics · Variables (with [TUNABLE] values) · UI · Progression ·
   Player Interactions · Dependencies · Roblox Implementation · Edge Cases · Acceptance Criteria.**
3. **Acceptance criteria** are measurable and IDed `AC-<SS>-<NN>` where `SS` is your two-digit section
   number, e.g. `AC-05-07: A Perfect grill window is ≥ 1.5 s at station Lv1 and is shown with a green band
   plus a ✓ icon.`
4. **Tables** for all databases. The **first column of every database table is the ID** (in backticks is
   fine: `` `RCP_BRG_001` ``). One row per entity. The build validator treats an ID in the first cell of
   a table row as the *definition* of that entity; everywhere else it is a *reference*. Every reference
   must resolve to a definition somewhere in the final document.
5. **Mermaid diagrams** use fenced ```` ```mermaid ```` blocks and the **first line inside the block** must be a
   comment naming the diagram key from §C1.3, e.g. `%% diagram: cooking-workflow`. Keep Mermaid syntax
   conservative (flowchart/stateDiagram-v2/sequenceDiagram; quote labels containing punctuation).
6. **Code** examples are Luau (```` ```lua ````), typed where helpful (`--!strict`), Roblox-realistic APIs only.
7. **Tone:** ridiculous on the surface, rigorous underneath. Jokes in names/dialogue/flavor; precision in
   rules/numbers. Kid-safe (ages 8–16): **no gore, no blood, no realistic weapons, no death** — defeat is
   "Seeing Stars"/"Dizzy", damage shows as cartoon stars, feathers, sauce splats, confetti, soot puffs.
   No real brands, no copyrighted characters, no real people. No mean-spirited humor about real groups.
8. **Cross references:** refer to other sections as `§N` (section number only) — you cannot know other
   contributors' subsection numbers, except the fixed allocations in §C1.2 (e.g. `§36.6` Ability Database).
9. **Numbers:** use the canon economy (§C4). Use thousands separators (12,500). Currency abbreviations:
   **MB** (Morph Bucks), **MS** (Mutation Shards), **RT** (Research Tokens). Time in seconds `s`,
   minutes `min`, hours `h`. Distances in Roblox studs.
10. **Do not silently omit.** If a list requires N items, deliver ≥ N complete rows. If you run long,
    write your file in several appends — never truncate a table.
11. **Write only your own files** (listed in §C1). Do not edit other files, do not `git commit`/`push`.
12. **Data-backed tables are encouraged.** For large databases with computed columns, author data in
    `gdd/data/<domain>.json` and a renderer `gdd/tools/render_<domain>.py` (Python 3 stdlib only) that
    writes your markdown file(s). The renderer must be idempotent and runnable as
    `python3 gdd/tools/render_<domain>.py` from the repo root.

---

## C1. Document Structure & Ownership

### C1.1 Section files (assembled in filename order into the final GDD)

| File (in `gdd/sections/`) | Heading | Owner |
|---|---|---|
| `00_front_matter.md` | Title, conventions, manifest, TOC (generated) | Integrator |
| `01_executive_summary.md` | `## 1. Executive Summary` | A1 Vision |
| `02_game_vision.md` | `## 2. Game Vision` | A1 Vision |
| `03_design_pillars.md` | `## 3. Design Pillars` | A1 Vision |
| `04_core_gameplay_loops.md` | `## 4. Core Gameplay Loops` | A1 Vision |
| `05_cooking_mechanics.md` | `## 5. Cooking Mechanics` | A2 Cooking |
| `06_recipe_database.md` | `## 6. Recipe Database` (subsections 6.1–6.17) | A3 Recipes |
| `06b_order_modifications.md` | `### 6.18 Ridiculous Order Modifications` | A2 Cooking |
| `07_ingredient_database.md` | `## 7. Ingredient Database` | A3 Recipes |
| `08_customer_ai.md` | `## 8. Customer AI` | A5 Customers |
| `09_customer_personalities.md` | `## 9. Customer Personalities` | A5 Customers |
| `10_satisfaction_tantrum.md` | `## 10. Satisfaction and Tantrum Systems` | A5 Customers |
| `11_combat_system.md` | `## 11. Combat System` | A6 Combat |
| `12_mutation_system.md` | `## 12. Mutation System` (subsections 12.1–12.8) | A7 Mutations |
| `12b_combinations_synergies.md` | `### 12.9 Morph Combinations` and `### 12.10 Mutation Synergy Rules` | A8 Morph UI |
| `13_morph_customization.md` | `## 13. Morph Customization` | A8 Morph UI |
| `14_player_progression.md` | `## 14. Player Progression` | A9 Progression |
| `15_restaurant_building.md` | `## 15. Restaurant Building` | A10 Restaurant |
| `16_employee_management.md` | `## 16. Employee Management` | A11 Employees |
| `17_offline_simulation.md` | `## 17. Offline Restaurant Simulation` | A11 Employees |
| `18_morph_city.md` | `## 18. Morph City` | A12 City |
| `19_city_npcs.md` | `## 19. City NPCs` | A13 NPCs & Quests |
| `20_quests.md` | `## 20. Quests` | A13 NPCs & Quests |
| `21_multiplayer.md` | `## 21. Multiplayer` | A14 Social & Economy |
| `22_economy.md` | `## 22. Economy` | A14 Social & Economy |
| `23_monetization.md` | `## 23. Monetization` | A14 Social & Economy |
| `24_ui_ux.md` | `## 24. UI/UX` | A15 UI |
| `25_art_direction.md` | `## 25. Art Direction` | A16 Art & Audio |
| `26_animation_audio.md` | `## 26. Animation and Audio` | A16 Art & Audio |
| `27_roblox_architecture.md` | `## 27. Roblox Architecture` | A17 Architecture |
| `28_data_persistence.md` | `## 28. Data Persistence` | A18 Data & Ops |
| `29_security_anti_exploit.md` | `## 29. Security and Anti-Exploit` | A18 Data & Ops |
| `30_performance_optimization.md` | `## 30. Performance Optimization` | A18 Data & Ops |
| `31_analytics.md` | `## 31. Analytics` | A18 Data & Ops |
| `32_tutorial.md` | `## 32. Tutorial` | A1 Vision |
| `33_content_expansion.md` | `## 33. Content Expansion` | A1 Vision |
| `34_development_roadmap.md` | `## 34. Development Roadmap` | A19 Production |
| `35_testing_qa.md` | `## 35. Testing and QA` | A19 Production |
| `36_00_index.md` | `## 36. Content Database Appendices` + `### 36.1` | Integrator |
| `36_02_recipe_quick_reference.md` | `### 36.2 Recipe Quick Reference` | A3 Recipes |
| `36_03_mutation_parts.md` | `### 36.3 Mutation Parts Database` | A7 Mutations |
| `36_04_mutation_synergies.md` | `### 36.4 Mutation Synergies Database` | A8 Morph UI |
| `36_05_morph_combinations.md` | `### 36.5 Morph Combination Examples` | A8 Morph UI |
| `36_06_abilities.md` | `### 36.6 Ability Database` | A6 Combat |
| `36_07_status_effects.md` | `### 36.7 Status Effects Database` | A6 Combat |
| `36_08_employee_archetypes.md` | `### 36.8 Employee Archetypes Database` | A11 Employees |
| `36_09_offline_incidents.md` | `### 36.9 Offline Incidents Database` | A11 Employees |
| `36_10_city_buildings.md` | `### 36.10 City Buildings Database` | A12 City |
| `36_11_city_events.md` | `### 36.11 City Events Database` | A12 City |
| `36_12_restaurant_tiers_upgrades.md` | `### 36.12 Restaurant Tiers and Upgrades Database` | A10 Restaurant |
| `36_13_furniture_catalog.md` | `### 36.13 Furniture and Equipment Catalog` | A10 Restaurant |
| `36_14_animation_library.md` | `### 36.14 Animation Library` | A16 Art & Audio |
| `36_15_sound_library.md` | `### 36.15 Sound Library` | A16 Art & Audio |
| `36_16_achievements.md` | `### 36.16 Achievements Database` | A9 Progression |
| `36_17_milestones.md` | `### 36.17 Progression Milestones Database` | A9 Progression |
| `37_implementation_checklists.md` | `## 37. Implementation Checklists` | A19 Production |
| `38_open_design_decisions.md` | `## 38. Open Design Decisions` | A19 Production |
| `39_balancing_assumptions.md` | `## 39. Balancing Assumptions` | A19 Production |
| `40_definition_of_done.md` | `## 40. Definition of Done` | A19 Production |

Where a Part-27 section *is* a database, the database lives in that section: Recipes §6,
Ingredients §7, Personalities §9, NPCs §19, Quests §20. All other databases live in §36.

### C1.2 Fixed cross-reference anchors
§6 Recipes · §6.18 Order Modifications · §7 Ingredients · §9 Personalities · §19 NPCs · §20 Quests ·
§36.2 Recipe Quick Reference · §36.3 Mutation Parts · §36.4 Synergies · §36.5 Morph Combos ·
§36.6 Abilities · §36.7 Status Effects · §36.8 Employees · §36.9 Offline Incidents · §36.10 Buildings ·
§36.11 Events · §36.12 Tiers & Upgrades · §36.13 Furniture · §36.14 Animations · §36.15 Sounds ·
§36.16 Achievements · §36.17 Milestones.

### C1.3 Required Mermaid diagrams (key → owner)
| Key | Section | Owner |
|---|---|---|
| `core-gameplay-loop` | §4 | A1 |
| `cooking-workflow` | §5 | A2 |
| `customer-state-machine` | §8 | A5 |
| `combat-state-machine` | §11 | A6 |
| `player-progression` | §14 | A9 |
| `employee-management` | §16 | A11 |
| `offline-earnings` | §17 | A11 |
| `service-architecture` | §27 | A17 |
| `data-persistence-flow` | §28 | A18 |

Additional diagrams are welcome (give them any other key).

---

## C2. Identifier Conventions

All IDs are UPPER_SNAKE, ASCII, stable forever (never re-used; deprecated IDs stay reserved).

| Prefix / Pattern | Entity | Owner (defines rows) | Example |
|---|---|---|---|
| `RCP_<CAT>_<NNN>` | Recipe | A3 (names fixed in §C10) | `RCP_BRG_001` |
| `ING_<NAME>` | Ingredient | A3 (core set fixed in §C9) | `ING_BEEF_PATTY` |
| `MOD_<NNN>` | Order modification | A2 | `MOD_017` |
| `STN_<NAME>` | Kitchen station type | Canon §C7 (detailed by A2) | `STN_GRILL` |
| `PER_<NNN>` | Customer personality | Canon §C11 names; A5 details | `PER_001` |
| `ABL_<NNN>` | Ability (combat & utility) | Canon §C12 names; A6 details | `ABL_018` |
| `STS_<NAME>` | Status effect | Canon §C12 names; A6 details | `STS_DIZZY` |
| `MUT_<NNN>` | Mutation part | Canon §C13 names; A7 details | `MUT_216` |
| `SYN_<NNN>` | Mutation synergy | A8 | `SYN_001` |
| `CMB_<NNN>` | Example morph combination | A8 | `CMB_001` |
| `SKL_<TREE>_<NN>` | Skill node; TREE ∈ CHEF, CMBT, RPR, SVC, MGMT | A9 | `SKL_CHEF_07` |
| `ACH_<NNN>` | Achievement | A9 | `ACH_001` |
| `MLS_<NNN>` | Progression milestone | A9 | `MLS_001` |
| `TIER_<NN>` | Restaurant tier 01–10 | Canon §C6; A10 details | `TIER_03` |
| `FRN_<NNN>` | Furniture / decor / appliance item | A10 (trophies fixed §C16.6) | `FRN_042` |
| `UPG_<NNN>` | Restaurant upgrade (non-furniture) | A10 | `UPG_012` |
| `ROLE_<NAME>` | Employee role | Canon §C14 | `ROLE_CHEF` |
| `EMP_<NNN>` | Employee archetype | A11 (EMP_001 fixed) | `EMP_001` |
| `INC_<NNN>` | Offline incident | A11 | `INC_001` |
| `DST_<NN>` | City district | Canon §C16 | `DST_01` |
| `BLD_<NN>` | City building | Canon §C16; A12 details | `BLD_09` |
| `NPC_<NNN>` | Named NPC | Canon NPC_001–030; A13 adds 031+ | `NPC_016` |
| `QST_<TYPE>_<NNN>` | Quest; TYPE ∈ TUT, STY, DLY, WKY, CHF, CBT, RPR, EXP, EMP, RST | A13 (TUT IDs fixed §C17) | `QST_TUT_003` |
| `EVT_<NNN>` | City event | Canon §C16.5; A12 details | `EVT_007` |
| `ANM_<NNN>` | Animation | A16 (core set fixed §C21) | `ANM_010` |
| `SFX_<NNN>` / `MUS_<NNN>` | Sound effect / music track | A16 | `SFX_101` |

Non-database names: Roblox services use PascalCase (`CookingService`); remotes use
`<Domain>.<Action>` (e.g. `Cooking.InteractStation`); analytics events use `snake_case` prefixed `mmr_`.

---

## C3. Global Constants

| Constant | Value | Notes |
|---|---|---|
| Max players per server | **8** [TUNABLE] | 8 restaurant plots on Restaurant Row per server |
| Restaurant model | Exterior façade on a plot in `DST_01`; **instanced interior** in a far-off `Interiors` region; entering the door moves the player/guest into the interior | One restaurant per player at launch |
| Player WalkSpeed | 16 base → 20.8 max from stats (MOVE cap) | Abilities may exceed briefly (dash) |
| Carry capacity | 1 item (ingredient, plate, tray, prop) | +1 per carry-boosting part (Octopus Arm, Monkey Tail, Extra Arm Backpack); hard max **3** |
| Interaction range | 7 studs (stations), 10 studs (customers) | Server re-validates with +2 stud tolerance |
| Autosave interval | 120 s [TUNABLE] | Plus save on purchase ≥ 10,000 MB, on PlayerRemoving, on BindToClose |
| Customer NPC cap | seats of tier (max 24) + 4 queue per restaurant; server hard cap 160 customer proxies | §30 |
| NPC pattern | **Server Proxy + Client Visual (SPCV)**: server owns an anchored, invisible hitbox proxy part + state; each client builds the morph visual locally for proxies within its streaming/interior | Customers, employees, named NPCs. City crowds are client-only cosmetic. |
| Loose physics props | ≤ 30 per restaurant interior; thrown food is a scripted arc (raycast), not physics; debris is client-only and despawns in 4 s | §11, §30 |
| Day/time | Real-world UTC for daily/weekly resets (00:00 UTC daily; Monday 00:00 UTC weekly) | City lighting cycle is cosmetic, 24 min loop |
| Level cap | 100 | |
| Rating scale | Restaurant Reputation 1.0–5.0 ★ (start 2.5 ★) | §C11.4 |

---

## C4. Currencies & Economy Anchors

### C4.1 Currencies (no others may be introduced)
| Currency | Code | Earned from | Spent on |
|---|---|---|---|
| Morph Bucks | MB | customer payments, tips, quests, milestones, events, deliveries, offline earnings, achievements | ingredients (special), furniture, equipment, repairs, wages, hiring, tier upgrades, mutation purchases & upgrades, recipe learning, cosmetics (earnable ones) |
| Mutation Shards | MS | quests, dailies/weeklies, events, arena, duplicate mutation conversion, offline discoveries, achievements | mutation upgrades, Lab fusion, Rare+ mutation purchases, Mystery Market |
| Research Tokens | RT | weekly quests, story quests, legendary dish orders, arena seasons, achievements, events (**never offline**) | Epic+ mutation upgrades (Lv4+), Mythic fusion, Legendary purchases, advanced Lab research |

Robux purchases buy **cosmetics only** (§23). There is no premium soft currency and **no paid random rewards**.

### C4.2 Recipe price curve [TUNABLE]
`BasePrice(L) = 10 × 1.05^(L − 1)` where L = recipe unlock level, then
× difficulty factor `(0.8 + 0.1 × D)` (D = 1..5) × category factor (Drinks/Fried/Salads ×0.7; Desserts ×0.8;
Legendary ×2.5; others ×1.0) ± up to 15 % flavor variance. Round to whole MB.
Reference values: L1 ≈ 10, L10 ≈ 16, L20 ≈ 25, L30 ≈ 41, L40 ≈ 67, L50 ≈ 109, L60 ≈ 177, L70 ≈ 288,
L80 ≈ 469, L90 ≈ 764, L95 ≈ 975.
**Ingredient cost target:** 25–40 % of price (higher difficulty → lower ratio). Profit margin = (price − ingredient cost) / price.

### C4.3 Customer spend
Average items per customer: **1.4** (main + 40 % chance of a drink/side/dessert; parties order per member).
Average ticket = 1.4 × menu-weighted average item price.

### C4.4 Target active income & pacing (per active hour, including tips, after ingredient costs & online wages, plus ~15 % quests/events) [TUNABLE]
| Tier | Player level on entry | Cum. active hours to reach | Net MB / active hour | Next tier cost (MB) |
|---|---|---|---|---|
| TIER_01 | 1 | 0 | 630 | 1,000 |
| TIER_02 | 5 | 1 | 1,080 | 2,000 |
| TIER_03 | 10 | 3 | 1,730 | 5,000 |
| TIER_04 | 18 | 7 | 3,100 | 15,000 |
| TIER_05 | 26 | 14 | 5,400 | 40,000 |
| TIER_06 | 35 | 25 | 9,600 | 100,000 |
| TIER_07 | 45 | 40 | 17,400 | 225,000 |
| TIER_08 | 56 | 60 | 32,800 | 525,000 |
| TIER_09 | 68 | 85 | 63,700 | 1,500,000 |
| TIER_10 | 80 | 120 | 120,500 | — |

Design intent: ~50 % of income goes to tier/expansion, ~50 % to mutations, furniture, staff and upgrades.
Level 100 ≈ 200 active hours.

### C4.5 Mutation shop prices (Mutation Mart / Mystery Market) [TUNABLE]
| Rarity | MB price | Extra cost | Default equip level req. | Primary source |
|---|---|---|---|---|
| Common | 150–400 | — | 1 | Mutation Mart, capsules |
| Uncommon | 800–2,000 | — | 5 | Mutation Mart, capsules, quests |
| Rare | 4,000–10,000 | 20 MS | 12 | Mart (rotating), capsules, quests, Lab fusion |
| Epic | 25,000–60,000 | 80 MS | 25 | Mystery Market rotation, Lab fusion, events, arena |
| Legendary | 150,000–400,000 | 250 MS + 10 RT | 40 | Mystery Market (weekly), Lab fusion, story/events |
| Mythic | not sold | Lab fusion: 3 Legendary of same category + 600 MS + 40 RT | 60 | fusion, story finale, top event rewards |
| Secret | not sold | hidden discovery condition | special | secret conditions only |

### C4.6 Mutation upgrade costs [TUNABLE]
Upgrading level `L → L+1`: `MB = BaseMB[r] × 1.5^(L−1)`, `MS = BaseMS[r] × L`,
`RT = (r ≥ Epic and L ≥ 4) ? RTBase[r] × (L − 3) : 0`, plus **one duplicate copy** of the part *or*
`DupeSubstituteMS[r]` extra MS.

| Rarity | Max level | BaseMB | BaseMS | RTBase | Dupe→MS conversion / DupeSubstituteMS |
|---|---|---|---|---|---|
| Common | 5 | 100 | 2 | — | 5 / 10 |
| Uncommon | 6 | 300 | 4 | — | 12 / 25 |
| Rare | 7 | 900 | 8 | — | 30 / 60 |
| Epic | 8 | 3,000 | 15 | 1 | 80 / 160 |
| Legendary | 9 | 10,000 | 30 | 2 | 200 / 400 |
| Mythic | 10 | 30,000 | 50 | 4 | 500 / 1,000 |
| Secret | 10 | 15,000 | 40 | 3 | — (secrets cannot duplicate) / 600 |

### C4.7 Earnable Morph Capsules (free, never sold for Robux)
Sources: daily login streak, dailies, weeklies, milestones, events, offline discovery (max 1/day).
Odds (disclosed in UI): Common 55 % · Uncommon 27 % · Rare 12 % · Epic 4.5 % · Legendary 1.3 % · Mythic 0.2 % · Secret 0 %.
**Pity:** guaranteed Epic-or-better at the 40th capsule without one; counter persists.
Duplicates auto-convert to MS (table above) unless the player chooses to keep them for upgrades.

### C4.8 Employee rarity bands [TUNABLE]
| Rarity | Hire cost (MB) | Wage (MB / h worked) | Stat range (1–100) | Potential cap | Typical tier |
|---|---|---|---|---|---|
| Common | 200–600 | 10–25 | 15–40 | 55 | T1–T3 |
| Uncommon | 1,200–3,000 | 30–70 | 30–55 | 70 | T3–T5 |
| Rare | 6,000–15,000 | 90–200 | 45–70 | 82 | T5–T7 |
| Epic | 30,000–80,000 | 250–600 | 60–85 | 92 | T7–T9 |
| Legendary | 180,000–450,000 | 700–1,500 | 75–100 | 100 | T9–T10 |

### C4.9 Station upgrade levels (all cooking/processing stations) [TUNABLE]
| Level | Name | Effect (cumulative, replaces previous) | Cost × station base price | Requires |
|---|---|---|---|---|
| Lv1 | Stock | baseline | (purchase) | — |
| Lv2 | Tuned | process time × 0.90 | × 1.5 | TIER_02 |
| Lv3 | Pro | process time × 0.80; Perfect window × 1.25 | × 4 | TIER_04 |
| Lv4 | Mutant | process time × 0.70; Perfect window × 1.25; burn grace +3 s (non-heat stations: failure chance −50 %) | × 10 | TIER_06 |
| Lv5 | Ridiculous | process time × 0.60; Perfect window × 1.5; station-specific gimmick (defined in §5) | × 25 | TIER_08 |

---

## C5. Player Statistics (9) & Formulas [TUNABLE]

Stat points come from: **level-up allocation** (2 points per level gained, max 50 allocated per stat, total
198 at L100; free respec once per 24 h, otherwise 500 MB × level), **mutations** (§C13.4), **skill nodes** (§14).
Effective stat `S` is capped (cap below); excess is wasted and the UI shows "MAXED".

| Code | Name (UI) | Effect formula | Cap |
|---|---|---|---|
| `COOK_SPD` | Cooking Speed | station process & chop time × `1 / (1 + 0.006·S)` | 150 (→ ×0.526) |
| `COOK_QLT` | Cooking Quality | Perfect window × `(1 + 0.005·S)`; burn delay +0.4 %/pt | 150 (→ ×1.75) |
| `STR` | Strength | damage × `(1 + 0.008·S)`; knockback +0.4 %/pt | 150 (→ ×2.2) |
| `DEF` | Defense | damage taken × `100 / (100 + S)` | 200 (→ ×0.333) |
| `REPAIR` | Repair Speed | repair speed × `(1 + 0.01·S)`; repair material cost −0.2 %/pt (max −30 %) | 150 (→ ×2.5) |
| `MOVE` | Movement Speed | WalkSpeed `16 × (1 + 0.003·S)` | 100 (→ 20.8) |
| `LUCK` | Luck | rare-drop weight × `(1 + 0.004·S)`; "Jackpot Tip" chance +0.1 %/pt | 150 (→ ×1.6) |
| `CHARM` | Customer Charm | customer patience × `(1 + 0.004·S)`; anger-escalation chance × `100 / (100 + S)` | 150 (→ ×1.6) |
| `EFFICIENCY` | Restaurant Efficiency | ingredient cost × `(1 − 0.0015·S)`; employee output +0.1 %/pt | 150 (→ ×0.775, +15 %) |

The mockup's level-up panel shows **Cooking, Strength, Repair, Luck** with "+" buttons: the default allocation
view features these four (Cooking button allocates to COOK_SPD and COOK_QLT alternately), with a
"More Stats" expander for all nine.

Player HP = `100 + 2 × (Level − 1) + mutation HP bonuses`.

### C5.1 XP curve (fixed formula, calibrated to §C4.4 pacing) [TUNABLE]
- XP required to go from level L to L+1: **`XPReq(L) = round((180 + 30·L) × 1.045^(L−1))`**.
- Reference XP rate for a competent player at level L: **`XPRate(L) = 900 × 1.045^(L−1)` XP per active hour**
  (≈ 75 % from cooking/serving, 25 % from quests, combat, repairs, exploration, events). XP rewards for any
  activity must be expressed relative to this rate (e.g. a daily quest ≈ 0.25 × XPRate(L)).
- Reference values: XPReq(1)=210, XPReq(10)=713, XPReq(26)=2,885, XPReq(45)=10,612, XPReq(68)=42,378,
  XPReq(80)=83,523; cumulative XP to reach L10 = 3,661, L26 = 28,402, L45 = 139,261, L80 = 1,365,697,
  L100 = 4,319,405. Resulting pacing: L5 ≈ 1.1 h, L10 ≈ 3.3 h, L18 ≈ 8.5 h, L26 ≈ 15.8 h, L35 ≈ 26.6 h,
  L45 ≈ 41.8 h, L56 ≈ 62 h, L68 ≈ 89 h, L80 ≈ 121 h, L100 ≈ 185 h of active play.

---

## C6. Restaurant Tiers (fixed values) [TUNABLE]

| Tier | Name | Upgrade cost (MB) | Req. level | Seats (= max concurrent customers) | Appliance slots | Menu slots | Employee cap | Base demand (customers/h) |
|---|---|---|---|---|---|---|---|---|
| `TIER_01` | Broken Burger Shack | 0 (start) | 1 | 4 | 6 | 4 | 2 | 50 |
| `TIER_02` | Tiny Mutation Diner | 1,000 | 5 | 6 | 8 | 5 | 3 | 65 |
| `TIER_03` | Neighborhood Freak Café | 2,000 | 10 | 8 | 10 | 6 | 4 | 80 |
| `TIER_04` | Morph City Grill | 5,000 | 18 | 10 | 12 | 8 | 6 | 95 |
| `TIER_05` | Mutant Family Restaurant | 15,000 | 26 | 12 | 14 | 10 | 8 | 110 |
| `TIER_06` | Monster Food Court | 40,000 | 35 | 14 | 16 | 12 | 10 | 125 |
| `TIER_07` | Mutation Megadiner | 100,000 | 45 | 16 | 18 | 14 | 12 | 140 |
| `TIER_08` | Luxury Freak Restaurant | 225,000 | 56 | 18 | 20 | 16 | 14 | 155 |
| `TIER_09` | Morph City Food Palace | 525,000 | 68 | 20 | 22 | 20 | 16 | 170 |
| `TIER_10` | Legendary Mutation Restaurant | 1,500,000 | 80 | 24 | 24 | 24 | 20 | 190 |

- **Appliance slots** count cooking/processing appliances only (cutting board, grill, fryer, oven, pizza oven,
  stove, soup pot, steamer, blender, mixer, drink dispenser, ice cream machine, infuser, anti-grav wok).
  Utility fixtures (pantry, fridge, freezer, prep counter, assembly, plating, serving window, dishwasher,
  trash, delivery station) do not use slots but occupy floor space.
- **Service style:** TIER_01–02 are *counter service* (food handed over the serving window/counter;
  customers sit at nearby seats); TIER_03+ are *table service*.
- **Demand:** online customers/h = `BaseDemand × RepMult × DecorMult × EventMult`; offline uses ×0.6 (§C15).
- **Damage states** (all destructible furniture & appliances; A10 owns details): **Pristine** (durability
  100–76 %), **Scuffed** (75–51 %), **Cracked** (50–26 %), **Broken** (25–1 %: seats/appliances unusable),
  **Destroyed** (0 %: becomes a cartoon rubble pile; auto-rebuild offered for ≤ 25 % of item price — objects are
  **never permanently lost**).
- Tier upgrade also requires a **City Hall Expansion Permit** for TIER_04+ (permit cost included in the price above; permit is a quest-gated formality — see §18/§20).

---

## C7. Kitchen Stations (fixed list; A2 specifies every field)

| ID | Name | Kind | Slots (items processed at once, Lv1) | Starting kit at TIER_01? |
|---|---|---|---|---|
| `STN_PANTRY` | Ingredient Storage (Pantry Shelf) | utility | dispenses | yes |
| `STN_FRIDGE` | Refrigerator | utility | dispenses chilled | yes |
| `STN_FREEZER` | Freezer | utility + process (FREEZE) | 2 | no (T2) |
| `STN_CUT` | Cutting Board | appliance (CHOP) | 1 | yes |
| `STN_PREP` | Preparation Counter | utility (holding/combining) | 3 holds | yes |
| `STN_GRILL` | Grill | appliance (GRILL) | 2 | yes |
| `STN_FRYER` | Fryer | appliance (FRY) | 1 basket | yes |
| `STN_OVEN` | Oven | appliance (BAKE) | 2 | no |
| `STN_PIZZA_OVEN` | Pizza Oven | appliance (BAKE pizza) | 1 | no |
| `STN_STOVE` | Stovetop | appliance (pan: SAUTÉ/BOIL small) | 2 burners | no |
| `STN_SOUP_POT` | Soup Pot | appliance (BOIL/SIMMER) | 1 pot = 4 servings | no |
| `STN_STEAMER` | Steamer | appliance (STEAM) | 2 | no |
| `STN_BLENDER` | Blender | appliance (BLEND) | 1 | no |
| `STN_MIXER` | Mixer | appliance (MIX) | 1 bowl | no |
| `STN_DRINK` | Drink Dispenser | appliance (POUR) | 1 nozzle | yes |
| `STN_ICECREAM` | Ice Cream Machine | appliance (SCOOP/SWIRL) | 1 | no |
| `STN_ASSEMBLY` | Food Assembly Counter | utility (ASSEMBLE) | 2 boards | yes |
| `STN_PLATING` | Plating Station | utility (PLATE, garnish) | 2 | no (assembly doubles as plating at T1–T2) |
| `STN_WINDOW` | Serving Window | utility (hand-off, ticket rail) | 4 pickup spots | yes |
| `STN_DISHWASH` | Dishwashing Station | utility (WASH) | 1 rack = 4 plates | yes |
| `STN_TRASH` | Trash Disposal | utility | ∞ | yes |
| `STN_DELIVERY` | Ingredient Delivery Station | utility (receives crates) | 1 dock | yes |
| `STN_INFUSER` | Mutagen Infuser (late-game) | appliance (INFUSE) | 1 | no (unlock L40, T6) |
| `STN_ANTIGRAV` | Anti-Gravity Wok (late-game) | appliance (FLOAT-fry) | 1 | no (unlock L30, T5) |

### C7.1 Station availability schedule (purchasable from Restaurant Supplies `BLD_03`)
A recipe with unlock level L may only use stations available at a level ≤ L. Tier minimums apply.

| Station(s) | Available from level | Min tier |
|---|---|---|
| `STN_PANTRY`, `STN_FRIDGE`, `STN_CUT`, `STN_PREP`, `STN_GRILL`, `STN_FRYER`, `STN_DRINK`, `STN_ASSEMBLY`, `STN_WINDOW`, `STN_DISHWASH`, `STN_TRASH`, `STN_DELIVERY` | 1 (starter kit) | TIER_01 |
| `STN_STOVE` | 2 | TIER_01 |
| `STN_OVEN`, `STN_PIZZA_OVEN` | 3 | TIER_01 |
| `STN_SOUP_POT`, `STN_ICECREAM` | 4 | TIER_01 |
| `STN_BLENDER` | 5 | TIER_01 |
| `STN_MIXER`, `STN_FREEZER`, `STN_PLATING` | 5 | TIER_02 |
| `STN_STEAMER` | 7 | TIER_02 |
| `STN_ANTIGRAV` | 30 | TIER_05 |
| `STN_INFUSER` | 40 | TIER_06 |

The starter kit occupies 4 of TIER_01's 6 appliance slots (CUT, GRILL, FRYER, DRINK), so early players must
choose two of STOVE / OVEN / PIZZA_OVEN / SOUP_POT / ICECREAM / BLENDER until TIER_02 — a deliberate menu choice.
Before `STN_MIXER` exists, dough/batter is combined by hand at `STN_PREP` (MIX by hand: 1.5× slower).

---

## C8. Preparation Actions, Ingredient States, Quality

**Actions (verbs):** CHOP, GRILL, FRY, BAKE, SAUTE, BOIL, STEAM, FREEZE, MIX, BLEND, POUR, SCOOP, ASSEMBLE,
PLATE, SERVE, CLEAN, WASH, INFUSE, FLOAT.

**Ingredient states:** RAW, CHOPPED, GRILLED, FRIED, BAKED, SAUTEED, BOILED, STEAMED, FROZEN, MIXED,
BLENDED, POURED, SCOOPED, INFUSED, FLOATED; failure states UNDERCOOKED, BURNED, ON_FIRE (station fire —
must be extinguished), MUSHY (over-blended/over-chopped), SPILLED.

**Heat timing model (GRILL, FRY, BAKE, SAUTE, BOIL, STEAM, FLOAT, INFUSE):** each component has
`T_ready` (becomes cooked), Perfect window `[T_ready, T_ready + W_perfect]`, Good until `T_burn`, BURNED
after `T_burn`, ON_FIRE at `T_burn + 4 s` (heat stations only). Before `T_ready` = UNDERCOOKED.
Defaults [TUNABLE]: `W_perfect = 2.0 s`, `T_burn = T_ready + 6 s` at Lv1 before COOK_QLT and upgrades.

**Quality grades (dish component score):** PERFECT 1.00 · GOOD 0.80 · OK 0.60 · UNDERCOOKED 0.35 · BURNED 0.15 ·
RUINED 0.00. A dish's **Food Quality Q** = mean component score × assembly-order factor (1.0 correct order,
0.85 one swap, 0.7 worse) × plating factor (1.0 plated, 0.9 un-plated at T3+).

**Chopping:** N taps (default 4); each tap has a timing ring — hit in the green zone = "Clean cut" (1.0),
yellow = 0.8, miss = 0.6; final CHOPPED quality = average. Over-chopping (> N + 3 taps) → MUSHY (0.35).
Mobile: tap the big CHOP button; accessibility "Auto-Rhythm" setting makes every tap count as yellow (0.8).

---

## C9. Ingredient Tags & Guaranteed Core Ingredients

**Tag vocabulary (ingredients must use only these):** `bread, meat, poultry, seafood, cheese, dairy, veg, fruit,
grain, noodle, sauce, spice, spicy, sweet, frozen, liquid, egg, fried, crunchy, round, square, pickle,
tentacle, eyeball, slime, bug, alien, mutagen, glowing, legendary, gold, plant, nut, caffeine, fizzy`.
(All "gross" ingredients are kid-friendly versions: eyeballs are gummy/jelly, tentacles are squishy
calamari-style, bugs are crunchy candy-like "Bug Crunch", slime is fruit jelly.)

**Guaranteed core ingredient IDs** (A3 must define all of these; others may reference them):
`ING_BUN, ING_BEEF_PATTY, ING_CHEESE, ING_LETTUCE, ING_TOMATO, ING_ONION, ING_PICKLE, ING_BACON, ING_KETCHUP,
ING_MUSTARD, ING_POTATO, ING_DOUGH, ING_TOMATO_SAUCE, ING_MOZZARELLA, ING_PEPPERONI, ING_PINEAPPLE,
ING_TORTILLA, ING_BEANS, ING_RICE, ING_BREAD_SLICE, ING_HAM, ING_PASTA, ING_EGG, ING_MILK, ING_FLOUR,
ING_SUGAR, ING_BUTTER, ING_CHOCOLATE, ING_STRAWBERRY, ING_ICE, ING_SODA_SYRUP, ING_LEMON, ING_FISH_FILLET,
ING_SHRIMP, ING_TENTACLE, ING_GUMMY_EYEBALL, ING_HOT_SAUCE, ING_MUTAGEN_GOO, ING_MOON_CHEESE,
ING_GOLDEN_PATTY, ING_STARDUST, ING_ICE_CREAM_BASE, ING_TAPIOCA, ING_TEA, ING_COFFEE_BEANS, ING_SLIME_JELLY,
ING_BUG_CRUNCH, ING_LAVA_PEPPER`.

**Supply model:** *Basic* ingredients (unlock ≤ L20, no special tag) are **unlimited**: their cost is netted
from the sale when the dish is served (never paid upfront; wasted food costs are charged at the trash, never
below 0 MB balance). *Special* ingredients (tags alien, mutagen, legendary, gold, glowing, or unlock > L20 with
rarity flag) are **stocked**: bought as crates (Restaurant Supplies / delivery station / Mystery Market /
foraging) and consumed from Pantry stock. A recipe whose special stock is empty shows **SOLD OUT** and
customers cannot order it.

---

## C10. Recipe Master List (150 — names, IDs, categories, unlock levels are fixed)

Category codes: BRG Burgers · PIZ Pizza · TAC Tacos & Mexican-Inspired · SAN Sandwiches · SOP Soups ·
PST Pasta · BRK Breakfast · DES Desserts · DRK Drinks & Smoothies · SEA Seafood · SAL Salads · FRI Fried Foods ·
ALN Alien Cuisine · MUT Mutation Cuisine · LEG Legendary Dishes.

Learning: L1 recipes are known from the start. Others become *learnable* at their unlock level and are
learned at the Cooking Academy (`BLD_06`) for `5 × price` MB, or granted by a quest. ALN requires the
Alien Cuisine course (story chapter 5), MUT requires `STN_INFUSER`, LEG requires a Legendary Recipe quest.

| ID | Name | Unlock L |
|---|---|---|
| `RCP_BRG_001` | Basic Burger | 1 |
| `RCP_BRG_002` | Cheeseburger | 1 |
| `RCP_BRG_003` | Double Cheeseburger | 4 |
| `RCP_BRG_004` | Triple Stack Burger | 9 |
| `RCP_BRG_005` | Bacon Monster Burger | 7 |
| `RCP_BRG_006` | Pickle Mountain Burger | 5 |
| `RCP_BRG_007` | Volcano Burger | 15 |
| `RCP_BRG_008` | Frozen Burger | 12 |
| `RCP_BRG_009` | Rainbow Burger | 20 |
| `RCP_BRG_010` | Mystery Meat Burger | 25 |
| `RCP_BRG_011` | Tentacle Burger | 30 |
| `RCP_BRG_012` | Exploding Burger | 40 |
| `RCP_BRG_013` | Upside-Down Burger | 18 |
| `RCP_BRG_014` | Invisible Burger | 50 |
| `RCP_BRG_015` | The Unreasonably Large Burger | 60 |
| `RCP_PIZ_001` | Cheese Pizza | 3 |
| `RCP_PIZ_002` | Pepperoni Pizza | 3 |
| `RCP_PIZ_003` | Veggie Pizza | 6 |
| `RCP_PIZ_004` | Pineapple Pizza (Controversial) | 8 |
| `RCP_PIZ_005` | Meat Mountain Pizza | 11 |
| `RCP_PIZ_006` | Eyeball Pizza | 16 |
| `RCP_PIZ_007` | Tentacle Supreme | 28 |
| `RCP_PIZ_008` | Lava Pizza | 34 |
| `RCP_PIZ_009` | Screaming Cheese Pizza | 22 |
| `RCP_PIZ_010` | Pizza With No Crust | 14 |
| `RCP_PIZ_011` | Pizza With Only Crust | 10 |
| `RCP_PIZ_012` | Backwards Pizza | 26 |
| `RCP_PIZ_013` | Pizza Inside Another Pizza | 45 |
| `RCP_PIZ_014` | Square Circle Pizza | 19 |
| `RCP_PIZ_015` | Galaxy Pizza | 55 |
| `RCP_TAC_001` | Basic Taco | 5 |
| `RCP_TAC_002` | Crunchy Cheese Taco | 6 |
| `RCP_TAC_003` | Burrito Blob | 9 |
| `RCP_TAC_004` | Quesadilla Squish | 8 |
| `RCP_TAC_005` | Nacho Avalanche | 13 |
| `RCP_TAC_006` | Fish Taco of Destiny | 17 |
| `RCP_TAC_007` | Inside-Out Taco | 24 |
| `RCP_TAC_008` | Hot Sauce Volcano Burrito | 32 |
| `RCP_TAC_009` | Ghost Pepper Ghost Taco | 38 |
| `RCP_TAC_010` | Mega Taco Tower | 48 |
| `RCP_SAN_001` | Grilled Cheese | 2 |
| `RCP_SAN_002` | Ham & Cheese Sandwich | 4 |
| `RCP_SAN_003` | Hot Dog Classic | 3 |
| `RCP_SAN_004` | Club Sandwich Stack | 10 |
| `RCP_SAN_005` | Peanut Butter & Jellyfish | 12 |
| `RCP_SAN_006` | Chili Dog Disaster | 14 |
| `RCP_SAN_007` | BLT (Bacon Lettuce Tentacle) | 21 |
| `RCP_SAN_008` | Sandwich With Bread in the Middle | 23 |
| `RCP_SAN_009` | Sub of Unreasonable Length | 33 |
| `RCP_SAN_010` | The Sandwich Sandwich | 42 |
| `RCP_SOP_001` | Tomato Soup | 4 |
| `RCP_SOP_002` | Chicken Noodle-ish Soup | 7 |
| `RCP_SOP_003` | Soupsicle (Frozen Soup) | 13 |
| `RCP_SOP_004` | Alphabet Grumble Soup | 16 |
| `RCP_SOP_005` | Eyeball Broth | 20 |
| `RCP_SOP_006` | Pumpkin Screamer Soup | 24 |
| `RCP_SOP_007` | Swamp Stew | 27 |
| `RCP_SOP_008` | Lava Lentil Soup | 29 |
| `RCP_SOP_009` | Bread Bowl in a Bread Bowl | 37 |
| `RCP_SOP_010` | Bottomless Soup | 52 |
| `RCP_PST_001` | Butter Noodles | 2 |
| `RCP_PST_002` | Mac & Cheese | 5 |
| `RCP_PST_003` | Spaghetti & Meatballs | 6 |
| `RCP_PST_004` | Lasagna Tower | 18 |
| `RCP_PST_005` | Spaghetti Tornado | 23 |
| `RCP_PST_006` | Tentacle Carbonara | 31 |
| `RCP_PST_007` | Glow-in-the-Dark Ravioli | 35 |
| `RCP_PST_008` | The Infinite Noodle | 39 |
| `RCP_PST_009` | Pasta Shaped Like the Customer | 44 |
| `RCP_PST_010` | Spicy Lava Lasagna | 47 |
| `RCP_BRK_001` | Pancake Stack | 2 |
| `RCP_BRK_002` | Fried Egg Plate | 3 |
| `RCP_BRK_003` | Waffles | 5 |
| `RCP_BRK_004` | Breakfast Burrito | 11 |
| `RCP_BRK_005` | Upside-Down Pancakes | 15 |
| `RCP_BRK_006` | Omelette of Questionable Origin | 19 |
| `RCP_BRK_007` | Cereal With Soup Instead of Milk | 22 |
| `RCP_BRK_008` | Bacon Waterfall | 26 |
| `RCP_BRK_009` | Breakfast-for-Dinner-for-Breakfast | 36 |
| `RCP_BRK_010` | Dragon Egg Benedict | 41 |
| `RCP_DES_001` | Chocolate Chip Cookie | 3 |
| `RCP_DES_002` | Vanilla Ice Cream | 4 |
| `RCP_DES_003` | Donut Ring | 6 |
| `RCP_DES_004` | Strawberry Sundae | 7 |
| `RCP_DES_005` | Brownie Brick | 9 |
| `RCP_DES_006` | Birthday Cake Slice | 10 |
| `RCP_DES_007` | Pie in the Face (Edible) | 14 |
| `RCP_DES_008` | Rainbow Slime Jelly | 17 |
| `RCP_DES_009` | Exploding Cupcake | 21 |
| `RCP_DES_010` | Bug Brittle | 25 |
| `RCP_DES_011` | Frozen Lava Cake | 27 |
| `RCP_DES_012` | Cloud Cotton Candy | 30 |
| `RCP_DES_013` | Screaming Sorbet | 34 |
| `RCP_DES_014` | Galaxy Cheesecake | 46 |
| `RCP_DES_015` | The Dessert That Bites Back | 58 |
| `RCP_DRK_001` | Fizzy Soda | 1 |
| `RCP_DRK_002` | Lemonade | 2 |
| `RCP_DRK_003` | Chocolate Milkshake | 5 |
| `RCP_DRK_004` | Strawberry Smoothie | 6 |
| `RCP_DRK_005` | Bubble Tea | 8 |
| `RCP_DRK_006` | Rainbow Slushie | 11 |
| `RCP_DRK_007` | Angry Coffee | 13 |
| `RCP_DRK_008` | Swamp Water Smoothie | 16 |
| `RCP_DRK_009` | Ice Ice Smoothie | 18 |
| `RCP_DRK_010` | Hot Sauce Latte | 20 |
| `RCP_DRK_011` | Tentacle Tea | 24 |
| `RCP_DRK_012` | Volcano Float | 29 |
| `RCP_DRK_013` | Glowing Mutagen Juice | 33 |
| `RCP_DRK_014` | Cloud Juice | 38 |
| `RCP_DRK_015` | Liquid Lightning | 49 |
| `RCP_SEA_001` | Fish Sticks | 7 |
| `RCP_SEA_002` | Fried Shrimp Basket | 10 |
| `RCP_SEA_003` | Sushi Roll Block | 12 |
| `RCP_SEA_004` | Lobster-ish Roll | 19 |
| `RCP_SEA_005` | Waving Calamari Rings | 22 |
| `RCP_SEA_006` | Crab Cake Kerfuffle | 25 |
| `RCP_SEA_007` | Fish That's Still Looking At You | 28 |
| `RCP_SEA_008` | Jellyfish Jiggle Bowl | 31 |
| `RCP_SEA_009` | Sea Monster Steak | 37 |
| `RCP_SEA_010` | Kraken Platter | 54 |
| `RCP_SAL_001` | Garden Salad | 3 |
| `RCP_SAL_002` | Caesar Salad With Tiny Crown | 9 |
| `RCP_SAL_003` | Fruit Salad Explosion | 15 |
| `RCP_SAL_004` | Salad With No Lettuce | 23 |
| `RCP_SAL_005` | Carnivore "Salad" | 32 |
| `RCP_FRI_001` | French Fries | 1 |
| `RCP_FRI_002` | Onion Rings | 4 |
| `RCP_FRI_003` | Fried Pickles | 8 |
| `RCP_FRI_004` | Fried Ice Cream | 21 |
| `RCP_FRI_005` | Fried Everything Basket | 43 |
| `RCP_ALN_001` | Moon Cheese Nuggets | 30 |
| `RCP_ALN_002` | Zero-Gravity Noodles | 35 |
| `RCP_ALN_003` | Crater Crêpes | 38 |
| `RCP_ALN_004` | Martian Meatloaf | 40 |
| `RCP_ALN_005` | Nebula Nachos | 43 |
| `RCP_ALN_006` | UFO Saucer Pancakes | 45 |
| `RCP_ALN_007` | Comet Kebab | 50 |
| `RCP_ALN_008` | Asteroid Rock Candy | 53 |
| `RCP_ALN_009` | Glorp Stew | 57 |
| `RCP_ALN_010` | Black Hole Bagel | 62 |
| `RCP_MUT_001` | Mutagen Meatballs | 42 |
| `RCP_MUT_002` | Morph Smoothie | 48 |
| `RCP_MUT_003` | Shapeshifter Sushi | 55 |
| `RCP_MUT_004` | Chimera Casserole | 63 |
| `RCP_MUT_005` | Evolution Burrito | 70 |
| `RCP_LEG_001` | The Golden Patty Supreme | 65 |
| `RCP_LEG_002` | Dragon Feast | 72 |
| `RCP_LEG_003` | Infinity Pizza | 80 |
| `RCP_LEG_004` | Kraken King Banquet | 88 |
| `RCP_LEG_005` | The Mystery Morph Meal | 95 |

**Mutation Cuisine rule:** a customer who eats a MUT dish gains a *temporary cosmetic* random mutation part
(client-visual only, 60 s) — pure comedy, plus a +10 satisfaction "Whoa!" bonus.

---

## C11. Customers: Personalities, Satisfaction, Payment, Anger

### C11.1 Personality master list (A5 defines every field; others may reference)
| ID | Name |
|---|---|
| `PER_001` | The Karenosaurus |
| `PER_002` | The Hungry Hippo-Spider |
| `PER_003` | The Polite Demon |
| `PER_004` | The Food Critic |
| `PER_005` | The Impatient Goblin |
| `PER_006` | The Sleepy Sloth-Rocket |
| `PER_007` | The Chaos Gremlin |
| `PER_008` | The Rich Mutant |
| `PER_009` | The Influencer |
| `PER_010` | The Bodybuilder Pigeon |
| `PER_011` | The Conspiracy Moth |
| `PER_012` | The Nervous Newt |
| `PER_013` | The Grandma Golem |
| `PER_014` | The Picky Platypus |
| `PER_015` | The Robot Accountant |
| `PER_016` | The Party Pack |
| `PER_017` | The Pirate Crab |
| `PER_018` | The Drama Llama |
| `PER_019` | The Mime Mantis |
| `PER_020` | The Toddler Titan |
| `PER_021` | The Health Nut Hamster |
| `PER_022` | The Spicy Salamander |
| `PER_023` | The Frozen Yeti-Fish |
| `PER_024` | The Time-Traveler Tortoise |
| `PER_025` | The Undercover Inspector |
| `PER_026` | The Speedrunner Squirrel |
| `PER_027` | The Lovebird Jellyfish Couple |
| `PER_028` | The Haunted Toaster |
| `PER_029` | The Alien Tourist |
| `PER_030` | The Retired Wrestler Walrus |
| `PER_031` | The Birthday Beast |
| `PER_032` | The Mystery Mutant |

Customer *appearance* is procedurally assembled from mutation parts (§12) — personalities define behavior,
not a fixed body (except signature looks noted by A5, e.g. the Bodybuilder Pigeon always has a pigeon head).

### C11.2 Patience [TUNABLE]
`Patience (s) = (70 + 20 × (items − 1) + 5 × ΣDifficulty) × PersonalityPatienceMult × (1 + 0.004 × CHARM)`.
Ordering phase: a seated customer waits up to 30 s × PersonalityPatienceMult for the order to be taken.

### C11.3 Satisfaction formula (exact; A5 elaborates)
```
S_base = 100 × (0.25·A + 0.20·Q + 0.15·C + 0.20·W + 0.10·K + 0.10·M)
  A = order accuracy (0–1): correct dish & every requested modification (§6.18) satisfied
  Q = food quality (0–1) per §C8 (chop, assembly order, plating)
  C = cooking accuracy (0–1): doneness score of heat-cooked components
  W = wait factor: 1.0 if served within 50 % of patience, linear to 0.0 at 100 % of patience
  K = cleanliness / 100 (trash, spills, broken objects in the dining room)
  M = atmosphere / 100 (decor score, §15)
S = clamp( S_base × P_mult + P_offset + MutationBonus(≤ +10) + EventModifier(−15..+15), 0, 100 )
```
Thresholds (defaults; personalities may shift them): **Delighted ≥ 90 · Happy 70–89 · Meh 50–69 ·
Unhappy 30–49 · Furious < 30.**

### C11.4 Payment, tips, reputation
- **Pay** = Σ item menu prices × PayFactor: `1.0` if S ≥ 50; `0.8` if 30 ≤ S < 50; customers who become
  hostile and are calmed by combat pay an **Apology Payment of 40 %** (no tip); customers who storm out pay 0.
- **Tip** = Σ prices × TipRate(S) × PersonalityTipMult; TipRate: S < 70 → 0; 70–79 → 5 %; 80–89 → 10 %;
  90–97 → 18 %; 98–100 → 25 % ("Chef's Kiss"). Target: competent play averages ≈ 10 % tips.
- **Jackpot Tip:** chance `0.5 % + 0.1 %·LUCK` on S ≥ 90 for ×5 tip (capped at 500 MB below TIER_05, 5,000 MB above).
- **Reputation** (★ 1.0–5.0): after each customer `Stars += 0.02 × (S/20 − Stars)`; `RepMult = 0.5 + 0.25 × Stars`
  (1 ★ ×0.75 … 5 ★ ×1.75). Storm-outs apply an extra −0.03 ★. Offline uses the same Stars.
- **DecorMult** = `0.9 + 0.003 × Atmosphere` (Atmosphere 0–100 → ×0.9–×1.2).

### C11.5 Anger levels (A5 designs escalation; A6 designs fights)
Anger meter 0–100 per customer. **0 Happy** (0–14) · **1 Annoyed** (15–29) · **2 Complaining** (30–44) ·
**3 Throwing food** (45–59) · **4 Destroying furniture** (60–74) · **5 Fighting the player** (75–89) ·
**6 Restaurant-wide chaos** (90–100; requires ≥ 3 customers at level ≥ 3 simultaneously, or an event).
Crossing into levels 3, 4 and 5 each requires a personality **escalation roll** (`AngerProbability ×
100/(100+CHARM)`); a failed roll means the customer *sulks, complains, or leaves* instead — not every unhappy
customer attacks. Being hit by thrown food: +25 anger × personality sensitivity.
**De-escalation:** `ABL_006` Calm Down!, a free dessert/drink ("Peace Offering"), Chill Aura effects, a
Security Guard employee, or finishing their order Perfect while they're at level ≤ 2.

### C11.6 NPC combat styles (A5 assigns one per personality; A6 defines the AI for each)
| Style | Behavior summary |
|---|---|
| `PACIFIST` | never attacks; at levels 3–5 sulks, cries dramatically, or storms out |
| `THROWER` | ranged: lobs food/plates in scripted arcs, keeps distance |
| `BRAWLER` | melee combos, chases the nearest target |
| `CHARGER` | wind-up rush with knockback, smashes furniture in its path |
| `TANK` | slow, high Huff Points, ground slams, hard to knock back |
| `TRICKSTER` | debuffs (sticky, stinky, confused), steals plates, flees and returns |
| `INSTIGATOR` | rarely fights itself; yells to raise nearby customers' anger (+anger aura) |

A customer may use the **active ability of one of its own visible mutation parts** (NPC-tuned version per §36.6).

---

## C12. Combat Constants, Abilities, Status Effects

### C12.1 Constants [TUNABLE]
- Basic attack (`ABL_001`) 8 dmg × STR mult, 3-hit combo (0.35 s per hit); Heavy (`ABL_002`) 20 dmg, 0.6 s charge.
- Block (`ABL_003`): −70 % damage; Guard meter 60 → guard break = 1.0 s `STS_STUN`; regen 20/s after 2 s.
- Dodge (`ABL_004`): 0.4 s roll, 0.25 s invulnerability, 1.2 s cooldown.
- Customer combat HP ("Huff Points"): 40–300 by personality. At 0 → `STS_DIZZY` 3 s → *Calming down* →
  *Apologizing* → Apology Payment → escorted out.
- Player KO ("Seeing Stars"): 4 s animation, respawn at kitchen spawn with 60 % HP and `STS_WOOZY` (−15 % move,
  10 s). **No loss of mutations, items, or currency, ever.** The customer who KO'd you does `ANM_051` victory
  dance and leaves without paying (unless chaos level 6 continues).
- "In Combat" flag: dealt or took damage within the last 6 s. Blocks loadout swaps and full-screen menus.
- Max 4 equipped active mutation abilities on the ability bar (+ fixed basic kit). Abilities come from
  equipped parts only.

### C12.2 Ability master list (A6 specifies cooldown, damage, range, animation, effects, balance, counters)
`ABL_001`–`ABL_008` are the base kit; `ABL_009`–`ABL_060` are mutation combat abilities;
`ABL_061`–`ABL_070` are mutation utility abilities. Source parts are fixed in §C13.6.

| ID | Name | Type |
|---|---|---|
| `ABL_001` | Swipe Combo | base melee |
| `ABL_002` | Wallop | base heavy |
| `ABL_003` | Block | base defense |
| `ABL_004` | Dodge Roll | base mobility |
| `ABL_005` | Grab & Throw | base environmental |
| `ABL_006` | Calm Down! | base de-escalation |
| `ABL_007` | Pan Bonk | utensil melee (held frying pan) |
| `ABL_008` | Tray Shield | utensil defense (held tray) |
| `ABL_009` | Scorpion Tail Swipe | mutation |
| `ABL_010` | Bear Slam | mutation |
| `ABL_011` | Kangaroo Kick | mutation |
| `ABL_012` | Octo-Flurry | mutation |
| `ABL_013` | Rhino Charge | mutation |
| `ABL_014` | Eel Zap | mutation |
| `ABL_015` | Spine Burst | mutation |
| `ABL_016` | Tongue Yank | mutation |
| `ABL_017` | Claw Grab & Toss | mutation |
| `ABL_018` | Dragon Breath | mutation |
| `ABL_019` | Shark Chomp | mutation |
| `ABL_020` | Web Shot | mutation |
| `ABL_021` | Ground Pound | mutation |
| `ABL_022` | Flap Hover | mutation |
| `ABL_023` | Bat Screech | mutation |
| `ABL_024` | Skunk Cloud | mutation |
| `ABL_025` | Puff Up | mutation |
| `ABL_026` | Mantis Chop | mutation |
| `ABL_027` | Armadillo Roll | mutation |
| `ABL_028` | Trunk Spray | mutation |
| `ABL_029` | Peacock Dazzle | mutation |
| `ABL_030` | Owl Spin Counter | mutation |
| `ABL_031` | Rocket Punch | mutation |
| `ABL_032` | Laser Eyes | mutation |
| `ABL_033` | Magnet Pull | mutation |
| `ABL_034` | Toast Barrage | mutation |
| `ABL_035` | Vacuum Suck | mutation |
| `ABL_036` | Umbrella Parry | mutation |
| `ABL_037` | Jelly Bounce | mutation |
| `ABL_038` | Cactus Hug | mutation |
| `ABL_039` | Flytrap Snap | mutation |
| `ABL_040` | Spore Puff | mutation |
| `ABL_041` | Frost Blast | mutation |
| `ABL_042` | Thunder Clap | mutation |
| `ABL_043` | Lava Slam | mutation |
| `ABL_044` | Gust Kick | mutation |
| `ABL_045` | Tractor Beam | mutation |
| `ABL_046` | Comet Blink | mutation |
| `ABL_047` | Mind Buzz | mutation |
| `ABL_048` | Slime Trail | mutation |
| `ABL_049` | Tentacle Whip | mutation |
| `ABL_050` | Beak Peck Combo | mutation |
| `ABL_051` | Wing Buffet | mutation |
| `ABL_052` | Horn Toss | mutation |
| `ABL_053` | Tail Spin | mutation |
| `ABL_054` | Hammerhead Bash | mutation |
| `ABL_055` | Mole Burrow | mutation |
| `ABL_056` | Stink Bomb | mutation |
| `ABL_057` | Firefly Flash | mutation |
| `ABL_058` | Goat Headbutt | mutation |
| `ABL_059` | Ghost Phase | mutation |
| `ABL_060` | Kraken Grasp | mutation (ultimate) |
| `ABL_061` | Extra Hands | utility (carry +1, operate 2 stations) |
| `ABL_062` | Repair Burst | utility |
| `ABL_063` | Cheetah Dash | utility |
| `ABL_064` | Super Sniff | utility (reveal hidden preferences/mods) |
| `ABL_065` | Soothing Song | utility (area de-escalation) |
| `ABL_066` | Microwave Zap-Cook | utility (instantly finish a cooking item at GOOD) |
| `ABL_067` | Freeze Touch | utility (instant FREEZE) |
| `ABL_068` | Web Sweep | utility (clean trash in radius) |
| `ABL_069` | Hover Serve | utility (fly over tables while carrying) |
| `ABL_070` | Eagle Eye | utility (show all patience/anger meters) |

### C12.3 Status effects (A6 defines duration, magnitude, stacking, visuals, cleanse)
`STS_STUN, STS_DIZZY, STS_KNOCKDOWN, STS_SLOW, STS_STICKY, STS_SHOCKED, STS_TOASTY, STS_FROZEN, STS_SOAKED,
STS_CONFUSED, STS_STINKY, STS_CHARMED, STS_SLEEPY, STS_FLOATING, STS_WOOZY, STS_BLINDED, STS_GREASY,
STS_INSPIRED, STS_HYPED, STS_SHIELDED`.
(`STS_TOASTY` = cartoon soot, never visible flames on bodies. `STS_INSPIRED`/`HYPED`/`SHIELDED` are buffs.)

---

## C13. Mutation System Constants & Master List

### C13.1 Slots (22 anatomy slots) and part slot codes
Character anatomy slots: `HEAD, FACE, NOSE, MOUTH, EYES, EARS, HORNS, NECK, TORSO, ARM_L, ARM_R, HANDS, LEG_L,
LEG_R, FEET, TAIL, WINGS, BACK, SKIN, FUR, SCALES, FX`.
Part slot codes in the database: `ARM` parts fit `ARM_L` or `ARM_R` (mirrored automatically); `LEG` parts fit
`LEG_L` or `LEG_R`; all other codes equal the anatomy slot. `FUR` and `SCALES` are mutually exclusive
coverings over `SKIN`. UI groups (mockup): **Head** (HEAD, FACE, NOSE, MOUTH), **Ears** (EARS, HORNS),
**Eyes** (EYES), **Arms** (ARM_L, ARM_R, HANDS), **Legs** (LEG_L, LEG_R, FEET), **Tails** (TAIL),
**Extras** (NECK, TORSO, WINGS, BACK, SKIN, FUR, SCALES, FX).

### C13.2 Categories (16)
`MAMMAL, BIRD, REPTILE, AMPHIBIAN, FISH, INSECT, ARACHNID, MARINE, DINOSAUR, MYTHOLOGICAL, ROBOT, OBJECT,
FOOD, PLANT, ALIEN, ELEMENTAL`.

### C13.3 Rarities (color + shape so status is never color-only)
| Rarity | Color | Icon shape | Equip level req. (default) |
|---|---|---|---|
| Common | gray `#9AA0A6` | ● circle | 1 |
| Uncommon | green `#3DDC84` | ▲ triangle | 5 |
| Rare | blue `#3A8DFF` | ■ square | 12 |
| Epic | purple `#A15CFF` | ⬟ pentagon | 25 |
| Legendary | orange `#FF9F1C` | ★ star | 40 |
| Mythic | magenta `#FF3EA5` | ⬢ hexagon | 60 |
| Secret | rainbow shimmer on black | ? glyph | condition-based |

### C13.4 Stat budgets [TUNABLE]
Each part grants stat points (the 9 stats of §C5) totalling its **budget**:
`Budget = BaseBudget[rarity] × SlotWeight × (1 + 0.12 × (UpgradeLevel − 1))`.

| Rarity | Common | Uncommon | Rare | Epic | Legendary | Mythic | Secret |
|---|---|---|---|---|---|---|---|
| BaseBudget | 4 | 7 | 11 | 16 | 22 | 28 | 24 |

| SlotWeight | Slots |
|---|---|
| 1.0 (Major) | HEAD, TORSO, ARM (each arm), TAIL, WINGS, BACK |
| 0.5 (Minor) | FACE, NOSE, MOUTH, EYES, EARS, HORNS, NECK, HANDS, FEET, SKIN, FUR, SCALES, **each LEG** |
| 0.0 (Cosmetic) | FX (flavor passive only, no stats) |

**Matched pair bonus:** both legs (or both arms) the same part → +25 % to that pair's stats and the part's
leg/arm ability gains its "paired" bonus. Mismatched legs are allowed and play a "wobbly gait" animation (no penalty).
Each part has at most **one active ability** and at most **one passive**. Not every part has an active.

### C13.5 Tag vocabulary for synergies (parts use only these)
`chef, fighter, repair, speed, tank, charm, luck, fire, ice, electric, water, stinky, sticky, tentacle, claw,
horn, flying, light, heavy, armored, aquatic, robotic, plant, alien, cosmic, glow, grabby, multi, loud, regen,
tall, gold, sweet`.
Synergies (§36.4) are defined against **families** (the `Family` column), **categories**, **slots**, and
**tags** — never against single IDs only — so new parts automatically participate.

### C13.6 Mutation master list (280 parts — ID, name, slot, category, rarity, family, tags, active ability are fixed)
A7 adds: unlock requirement, acquisition, visual description, model & animation requirements, stat
distribution (cook / combat / repair / movement bonuses expressed as §C5 stats), passive, upgrade levels,
balance limits.

| ID | Name | Slot | Category | Rarity | Family | Tags | Active |
|---|---|---|---|---|---|---|---|
| `MUT_001` | Bear Head | HEAD | MAMMAL | Common | bear | fighter, tank | — |
| `MUT_002` | Cat Head | HEAD | MAMMAL | Common | cat | speed, charm | — |
| `MUT_003` | Dog Head | HEAD | MAMMAL | Common | dog | charm, luck | — |
| `MUT_004` | Pigeon Head | HEAD | BIRD | Common | pigeon | luck, loud | — |
| `MUT_005` | Frog Head | HEAD | AMPHIBIAN | Common | frog | sticky, speed | — |
| `MUT_006` | Rat Head | HEAD | MAMMAL | Common | rat | speed, repair | — |
| `MUT_007` | Goat Head | HEAD | MAMMAL | Common | goat | fighter, horn | — |
| `MUT_008` | Chicken Head | HEAD | BIRD | Common | chicken | chef, loud | — |
| `MUT_009` | Fish Head | HEAD | FISH | Common | fish | aquatic | — |
| `MUT_010` | Toaster Head | HEAD | OBJECT | Common | toaster | chef, fire | `ABL_034` |
| `MUT_011` | Shark Head | HEAD | FISH | Uncommon | shark | fighter, aquatic | — |
| `MUT_012` | Wolf Head | HEAD | MAMMAL | Uncommon | wolf | fighter, speed | — |
| `MUT_013` | Deer Head | HEAD | MAMMAL | Uncommon | deer | charm | — |
| `MUT_014` | Axolotl Head | HEAD | AMPHIBIAN | Uncommon | axolotl | charm, aquatic, regen | — |
| `MUT_015` | Giraffe Head | HEAD | MAMMAL | Uncommon | giraffe | charm, tall | — |
| `MUT_016` | Owl Head | HEAD | BIRD | Uncommon | owl | luck, charm | `ABL_030` |
| `MUT_017` | Lizard Head | HEAD | REPTILE | Uncommon | lizard | speed | — |
| `MUT_018` | Pumpkin Head | HEAD | PLANT | Uncommon | pumpkin | plant, glow | — |
| `MUT_019` | Fire Hydrant Head | HEAD | OBJECT | Uncommon | hydrant | water, tank | — |
| `MUT_020` | Snake Head | HEAD | REPTILE | Uncommon | snake | fighter, speed | — |
| `MUT_021` | TV Head | HEAD | OBJECT | Rare | tv | charm, glow, robotic | — |
| `MUT_022` | Robot Head | HEAD | ROBOT | Rare | robot | robotic, repair | — |
| `MUT_023` | Crocodile Head | HEAD | REPTILE | Rare | crocodile | fighter, aquatic, armored | — |
| `MUT_024` | Gorilla Head | HEAD | MAMMAL | Rare | gorilla | fighter, tank | — |
| `MUT_025` | Hammerhead Shark Head | HEAD | FISH | Rare | hammerhead | fighter, aquatic | `ABL_054` |
| `MUT_026` | Mantis Head | HEAD | INSECT | Rare | mantis | fighter, speed | — |
| `MUT_027` | Fly Head | HEAD | INSECT | Rare | fly | speed, luck | — |
| `MUT_028` | Tarantula Head | HEAD | ARACHNID | Rare | spider | sticky, fighter | `ABL_020` |
| `MUT_029` | Octopus Head | HEAD | MARINE | Rare | octopus | chef, tentacle, aquatic | — |
| `MUT_030` | Broccoli Head | HEAD | FOOD | Rare | broccoli | plant, chef | — |
| `MUT_031` | Dragon Head | HEAD | MYTHOLOGICAL | Epic | dragon | fire, fighter, chef | `ABL_018` |
| `MUT_032` | T-Rex Head | HEAD | DINOSAUR | Epic | trex | fighter, loud, heavy | — |
| `MUT_033` | Alien Grey Head | HEAD | ALIEN | Epic | alien_grey | alien, charm | `ABL_047` |
| `MUT_034` | Lava Rock Head | HEAD | ELEMENTAL | Epic | lava | fire, armored | — |
| `MUT_035` | Venus Flytrap Head | HEAD | PLANT | Epic | flytrap | plant, grabby | `ABL_039` |
| `MUT_036` | Microwave Head | HEAD | OBJECT | Epic | microwave | chef, electric | `ABL_066` |
| `MUT_037` | Phoenix Head | HEAD | MYTHOLOGICAL | Legendary | phoenix | fire, regen, flying | — |
| `MUT_038` | Kraken Head | HEAD | MARINE | Legendary | kraken | tentacle, fighter, aquatic | — |
| `MUT_039` | Golden Burger Head | HEAD | FOOD | Mythic | burger | chef, luck, gold | — |
| `MUT_040` | Glitch Head | HEAD | ALIEN | Secret | glitch | luck, cosmic | — |
| `MUT_041` | Whisker Mask | FACE | MAMMAL | Common | cat | charm | — |
| `MUT_042` | Bandit Raccoon Mask | FACE | MAMMAL | Common | raccoon | luck, speed | — |
| `MUT_043` | Croaky Frog Cheeks | FACE | AMPHIBIAN | Common | frog | loud | — |
| `MUT_044` | Robot Visor | FACE | ROBOT | Uncommon | robot | robotic, luck | — |
| `MUT_045` | Moth Fuzz Face | FACE | INSECT | Uncommon | moth | charm | — |
| `MUT_046` | Fish Gill Cheeks | FACE | FISH | Uncommon | fish | aquatic | — |
| `MUT_047` | Mustache of Destiny | FACE | OBJECT | Rare | mustache | charm, chef | — |
| `MUT_048` | Cosmic Void Face | FACE | ALIEN | Secret | void | cosmic, alien | — |
| `MUT_049` | Rat Nose | NOSE | MAMMAL | Common | rat | luck | — |
| `MUT_050` | Pig Snout | NOSE | MAMMAL | Common | pig | chef | — |
| `MUT_051` | Clown Nose | NOSE | OBJECT | Common | clown | charm, loud | — |
| `MUT_052` | Dog Nose | NOSE | MAMMAL | Common | dog | luck | — |
| `MUT_053` | Elephant Trunk | NOSE | MAMMAL | Uncommon | elephant | water, grabby | `ABL_028` |
| `MUT_054` | Star-Nosed Mole Nose | NOSE | MAMMAL | Uncommon | mole | luck, repair | — |
| `MUT_055` | Anteater Snoot | NOSE | MAMMAL | Rare | anteater | grabby | — |
| `MUT_056` | Faucet Nose | NOSE | OBJECT | Rare | faucet | water, repair | — |
| `MUT_057` | Carrot Nose | NOSE | FOOD | Uncommon | carrot | plant, charm | — |
| `MUT_058` | Truffle Pig Super-Snout | NOSE | MAMMAL | Epic | pig | chef, luck | `ABL_064` |
| `MUT_059` | Duck Bill | MOUTH | BIRD | Common | duck | loud | — |
| `MUT_060` | Beaver Teeth | MOUTH | MAMMAL | Common | beaver | repair | — |
| `MUT_061` | Frog Tongue | MOUTH | AMPHIBIAN | Uncommon | frog | sticky, grabby | `ABL_016` |
| `MUT_062` | Shark Jaws | MOUTH | FISH | Uncommon | shark | fighter | `ABL_019` |
| `MUT_063` | Toucan Beak | MOUTH | BIRD | Uncommon | toucan | charm, chef | `ABL_050` |
| `MUT_064` | Walrus Tusks | MOUTH | MARINE | Rare | walrus | fighter, tank | — |
| `MUT_065` | Snake Fangs | MOUTH | REPTILE | Rare | snake | fighter | — |
| `MUT_066` | Vacuum Mouth | MOUTH | OBJECT | Rare | vacuum | repair | `ABL_035` |
| `MUT_067` | Piranha Grin | MOUTH | FISH | Rare | piranha | fighter | — |
| `MUT_068` | Megaphone Mouth | MOUTH | OBJECT | Epic | megaphone | loud, charm | — |
| `MUT_069` | Blender Mouth | MOUTH | OBJECT | Epic | blender | chef | — |
| `MUT_070` | Black Hole Mouth | MOUTH | ALIEN | Mythic | void | cosmic, grabby | — |
| `MUT_071` | Googly Eyes | EYES | OBJECT | Common | googly | luck, charm | — |
| `MUT_072` | Cat Eyes | EYES | MAMMAL | Common | cat | luck | — |
| `MUT_073` | Fly Compound Eyes | EYES | INSECT | Uncommon | fly | luck, speed | — |
| `MUT_074` | Owl Eyes | EYES | BIRD | Uncommon | owl | luck | — |
| `MUT_075` | Sea Slug Eye Stalks | EYES | MARINE | Uncommon | seaslug | charm | — |
| `MUT_076` | Spider Eyes | EYES | ARACHNID | Uncommon | spider | luck, fighter | — |
| `MUT_077` | Chameleon Eyes | EYES | REPTILE | Rare | chameleon | luck, charm | — |
| `MUT_078` | Laser Eyes | EYES | ROBOT | Epic | robot | robotic, fighter | `ABL_032` |
| `MUT_079` | Eagle Eyes | EYES | BIRD | Rare | eagle | luck | `ABL_070` |
| `MUT_080` | Gummy Bear Eyes | EYES | FOOD | Uncommon | gummy | sweet, charm | — |
| `MUT_081` | Lightning Eyes | EYES | ELEMENTAL | Epic | storm | electric | — |
| `MUT_082` | Alien Eye-Stalk Trio | EYES | ALIEN | Rare | alien_grey | alien, luck | — |
| `MUT_083` | Firefly Glow Eyes | EYES | INSECT | Rare | firefly | glow | `ABL_057` |
| `MUT_084` | Crystal Ball Eyes | EYES | MYTHOLOGICAL | Legendary | oracle | luck, cosmic | — |
| `MUT_085` | Bunny Ears | EARS | MAMMAL | Common | rabbit | speed, charm | — |
| `MUT_086` | Bear Ears | EARS | MAMMAL | Common | bear | tank | — |
| `MUT_087` | Mouse Ears | EARS | MAMMAL | Common | mouse | luck | — |
| `MUT_088` | Elephant Ears | EARS | MAMMAL | Uncommon | elephant | tank, charm | — |
| `MUT_089` | Bat Ears | EARS | MAMMAL | Uncommon | bat | loud, luck | `ABL_023` |
| `MUT_090` | Fox Ears | EARS | MAMMAL | Uncommon | fox | speed, luck | — |
| `MUT_091` | Fin Ears | EARS | FISH | Uncommon | fish | aquatic, speed | — |
| `MUT_092` | Satellite Dish Ears | EARS | ROBOT | Rare | robot | robotic, luck | — |
| `MUT_093` | Leaf Ears | EARS | PLANT | Uncommon | plant | plant | — |
| `MUT_094` | Moth Feather Antennae | EARS | INSECT | Rare | moth | charm, luck | — |
| `MUT_095` | Headphone Ears | EARS | OBJECT | Rare | headphones | loud, charm | — |
| `MUT_096` | Dragon Fin Ears | EARS | MYTHOLOGICAL | Epic | dragon | fire, fighter | — |
| `MUT_097` | Goat Horns | HORNS | MAMMAL | Common | goat | horn, fighter | `ABL_058` |
| `MUT_098` | Deer Antlers | HORNS | MAMMAL | Uncommon | deer | horn, charm | — |
| `MUT_099` | Rhino Horn | HORNS | MAMMAL | Rare | rhino | horn, fighter, tank | `ABL_013` |
| `MUT_100` | Bull Horns | HORNS | MAMMAL | Uncommon | bull | horn, fighter | `ABL_052` |
| `MUT_101` | Unicorn Horn | HORNS | MYTHOLOGICAL | Epic | unicorn | horn, charm, glow | — |
| `MUT_102` | Chef Hat Crest | HORNS | OBJECT | Uncommon | chef | chef | — |
| `MUT_103` | Antenna Bobbles | HORNS | ALIEN | Uncommon | alien_grey | alien, electric | — |
| `MUT_104` | Triceratops Frill | HORNS | DINOSAUR | Rare | triceratops | horn, armored | — |
| `MUT_105` | Lightning Rod Horn | HORNS | ELEMENTAL | Rare | storm | electric, horn | `ABL_042` |
| `MUT_106` | Narwhal Tusk | HORNS | MARINE | Rare | narwhal | horn, aquatic | — |
| `MUT_107` | Sprout Antlers | HORNS | PLANT | Rare | plant | plant, horn, regen | — |
| `MUT_108` | Demon Horns | HORNS | MYTHOLOGICAL | Legendary | demon | horn, fire, fighter | — |
| `MUT_109` | Turtle Neck | NECK | REPTILE | Common | turtle | armored, tank | — |
| `MUT_110` | Giraffe Neck | NECK | MAMMAL | Uncommon | giraffe | tall, charm | — |
| `MUT_111` | Flamingo Neck | NECK | BIRD | Uncommon | flamingo | charm | — |
| `MUT_112` | Accordion Neck | NECK | OBJECT | Secret | accordion | loud, tall | — |
| `MUT_113` | Spring Neck | NECK | ROBOT | Rare | robot | robotic, speed | — |
| `MUT_114` | Brachiosaurus Neck | NECK | DINOSAUR | Epic | brachio | tall, tank | — |
| `MUT_115` | Frill Lizard Collar | NECK | REPTILE | Uncommon | lizard | charm, loud | — |
| `MUT_116` | Noodle Neck | NECK | FOOD | Secret | noodle | tall, chef | — |
| `MUT_117` | Plain Human Torso | TORSO | MAMMAL | Common | human | charm | — |
| `MUT_118` | Bear Body | TORSO | MAMMAL | Common | bear | tank, fighter | — |
| `MUT_119` | Fish Body | TORSO | FISH | Common | fish | aquatic, speed | — |
| `MUT_120` | Cow Body | TORSO | MAMMAL | Common | cow | tank, chef | — |
| `MUT_121` | Chicken Body | TORSO | BIRD | Common | chicken | chef, light | — |
| `MUT_122` | Turtle Shell Torso | TORSO | REPTILE | Uncommon | turtle | armored, tank | — |
| `MUT_123` | Robot Body | TORSO | ROBOT | Uncommon | robot | robotic, repair | — |
| `MUT_124` | Muscle Torso | TORSO | MAMMAL | Uncommon | muscle | fighter, heavy | — |
| `MUT_125` | Penguin Body | TORSO | BIRD | Uncommon | penguin | ice, aquatic | — |
| `MUT_126` | Bee Body | TORSO | INSECT | Uncommon | bee | chef, speed | — |
| `MUT_127` | Crab Shell Torso | TORSO | MARINE | Rare | crab | armored, claw | — |
| `MUT_128` | Armadillo Body | TORSO | MAMMAL | Rare | armadillo | armored | `ABL_027` |
| `MUT_129` | Pufferfish Body | TORSO | FISH | Rare | pufferfish | tank | `ABL_025` |
| `MUT_130` | Jellyfish Body | TORSO | MARINE | Rare | jellyfish | electric, light, glow | — |
| `MUT_131` | Fridge Body | TORSO | OBJECT | Rare | fridge | ice, chef, tank | — |
| `MUT_132` | Cactus Body | TORSO | PLANT | Rare | cactus | plant, armored | `ABL_038` |
| `MUT_133` | Stegosaurus Body | TORSO | DINOSAUR | Epic | stegosaurus | armored, tank | — |
| `MUT_134` | Slime Body | TORSO | ALIEN | Epic | slime | sticky, regen | `ABL_037` |
| `MUT_135` | Golem Rock Body | TORSO | ELEMENTAL | Epic | golem | tank, armored, heavy | — |
| `MUT_136` | Pizza Box Body | TORSO | FOOD | Epic | pizza | chef, luck | — |
| `MUT_137` | Kraken Core | TORSO | MARINE | Legendary | kraken | tentacle, tank | — |
| `MUT_138` | Cosmic Nebula Body | TORSO | ALIEN | Mythic | nebula | cosmic, glow, luck | — |
| `MUT_139` | Plain Human Arm | ARM | MAMMAL | Common | human | charm | — |
| `MUT_140` | Bear Arm | ARM | MAMMAL | Common | bear | fighter, heavy | `ABL_010` |
| `MUT_141` | Chicken Wing Arm | ARM | BIRD | Common | chicken | light, chef | — |
| `MUT_142` | Frog Arm | ARM | AMPHIBIAN | Common | frog | sticky | — |
| `MUT_143` | Noodle Arm | ARM | FOOD | Common | noodle | chef, tall | — |
| `MUT_144` | Crab Claw Arm | ARM | MARINE | Uncommon | crab | claw, grabby, fighter | `ABL_017` |
| `MUT_145` | Octopus Arm | ARM | MARINE | Uncommon | octopus | tentacle, chef, multi | `ABL_012` |
| `MUT_146` | Squid Tentacle Arm | ARM | MARINE | Uncommon | squid | tentacle, grabby | `ABL_049` |
| `MUT_147` | Robot Arm | ARM | ROBOT | Uncommon | robot | robotic, repair | — |
| `MUT_148` | Gorilla Arm | ARM | MAMMAL | Uncommon | gorilla | fighter, heavy | `ABL_021` |
| `MUT_149` | Kangaroo Boxing Arm | ARM | MAMMAL | Uncommon | kangaroo | fighter, speed | — |
| `MUT_150` | Spider Arm Bundle | ARM | ARACHNID | Uncommon | spider | multi, repair, sticky | `ABL_068` |
| `MUT_151` | Mantis Scythe Arm | ARM | INSECT | Rare | mantis | fighter, speed | `ABL_026` |
| `MUT_152` | Lobster Crusher Arm | ARM | MARINE | Rare | lobster | claw, fighter, heavy | — |
| `MUT_153` | Wrench Claw Arm | ARM | ROBOT | Rare | robot | repair, claw | `ABL_062` |
| `MUT_154` | Rocket Fist Arm | ARM | ROBOT | Rare | robot | robotic, fighter | `ABL_031` |
| `MUT_155` | Magnet Hand Arm | ARM | ROBOT | Rare | robot | electric, grabby | `ABL_033` |
| `MUT_156` | Spatula Arm | ARM | OBJECT | Uncommon | utensil | chef | — |
| `MUT_157` | Umbrella Arm | ARM | OBJECT | Rare | umbrella | tank, water | `ABL_036` |
| `MUT_158` | Vine Arm | ARM | PLANT | Uncommon | plant | plant, grabby, sticky | — |
| `MUT_159` | Electric Eel Arm | ARM | FISH | Rare | eel | electric | — |
| `MUT_160` | Bodybuilder Arm | ARM | MAMMAL | Rare | muscle | fighter, heavy | — |
| `MUT_161` | Tiny T-Rex Arm | ARM | DINOSAUR | Uncommon | trex | charm, light | — |
| `MUT_162` | Ice Crystal Arm | ARM | ELEMENTAL | Epic | ice | ice | `ABL_041` |
| `MUT_163` | Lava Fist Arm | ARM | ELEMENTAL | Epic | lava | fire, fighter | `ABL_043` |
| `MUT_164` | Dragon Claw Arm | ARM | MYTHOLOGICAL | Epic | dragon | fire, claw, fighter | — |
| `MUT_165` | Kraken Tentacle Arm | ARM | MARINE | Legendary | kraken | tentacle, multi, fighter | `ABL_060` |
| `MUT_166` | Alien Tractor Arm | ARM | ALIEN | Epic | alien_grey | alien, grabby | `ABL_045` |
| `MUT_167` | Whisk Arm | ARM | OBJECT | Uncommon | utensil | chef | — |
| `MUT_168` | Cosmic Chef Arm | ARM | ALIEN | Mythic | nebula | chef, cosmic | — |
| `MUT_169` | Mitten Paws | HANDS | MAMMAL | Common | bear | tank | — |
| `MUT_170` | Sticky Gecko Hands | HANDS | REPTILE | Uncommon | gecko | sticky, grabby | — |
| `MUT_171` | Oven Mitt Hands | HANDS | OBJECT | Common | utensil | chef, fire | — |
| `MUT_172` | Eagle Talons | HANDS | BIRD | Uncommon | eagle | claw, fighter | — |
| `MUT_173` | Whisk Fingers | HANDS | OBJECT | Uncommon | utensil | chef | — |
| `MUT_174` | Wrench Fingers | HANDS | ROBOT | Rare | robot | repair | — |
| `MUT_175` | Boxing Gloves | HANDS | OBJECT | Rare | boxing | fighter | — |
| `MUT_176` | Frost Fingers | HANDS | ELEMENTAL | Rare | ice | ice, chef | `ABL_067` |
| `MUT_177` | Leaf Hands | HANDS | PLANT | Uncommon | plant | plant, regen | — |
| `MUT_178` | Golden Chef Hands | HANDS | OBJECT | Legendary | gold | chef, gold, luck | — |
| `MUT_179` | Plain Human Leg | LEG | MAMMAL | Common | human | charm | — |
| `MUT_180` | Chicken Leg | LEG | BIRD | Common | chicken | speed, light | — |
| `MUT_181` | Frog Leg | LEG | AMPHIBIAN | Common | frog | speed | — |
| `MUT_182` | Bear Leg | LEG | MAMMAL | Common | bear | tank | — |
| `MUT_183` | Fish Tail Hopper | LEG | FISH | Common | fish | aquatic, charm | — |
| `MUT_184` | Kangaroo Leg | LEG | MAMMAL | Uncommon | kangaroo | speed, fighter | `ABL_011` |
| `MUT_185` | Spider Leg Cluster | LEG | ARACHNID | Uncommon | spider | multi, speed, repair | — |
| `MUT_186` | Cheetah Leg | LEG | MAMMAL | Rare | cheetah | speed | `ABL_063` |
| `MUT_187` | Robot Leg | LEG | ROBOT | Uncommon | robot | robotic, tank | — |
| `MUT_188` | Ostrich Leg | LEG | BIRD | Uncommon | ostrich | speed | — |
| `MUT_189` | Elephant Leg | LEG | MAMMAL | Uncommon | elephant | tank, heavy | — |
| `MUT_190` | Grasshopper Leg | LEG | INSECT | Rare | grasshopper | speed | — |
| `MUT_191` | Pogo Stick Leg | LEG | OBJECT | Rare | pogo | speed, loud | — |
| `MUT_192` | Unicycle Wheel Leg | LEG | ROBOT | Rare | wheel | speed, robotic | — |
| `MUT_193` | Tree Trunk Leg | LEG | PLANT | Rare | tree | tank, plant, regen | — |
| `MUT_194` | Raptor Leg | LEG | DINOSAUR | Epic | raptor | speed, fighter | — |
| `MUT_195` | Octopus Tentacle Legs | LEG | MARINE | Epic | octopus | tentacle, multi | — |
| `MUT_196` | Mole Digger Leg | LEG | MAMMAL | Rare | mole | speed, repair | `ABL_055` |
| `MUT_197` | Cloud Leg | LEG | ELEMENTAL | Epic | cloud | light, flying | `ABL_044` |
| `MUT_198` | Rocket Booster Leg | LEG | ROBOT | Epic | robot | speed, fire | — |
| `MUT_199` | Goat Hoof Leg | LEG | MAMMAL | Common | goat | speed, fighter | — |
| `MUT_200` | Phoenix Talon Leg | LEG | MYTHOLOGICAL | Legendary | phoenix | fire, speed, regen | — |
| `MUT_201` | Duck Feet | FEET | BIRD | Common | duck | aquatic, loud | — |
| `MUT_202` | Bunny Slippers | FEET | OBJECT | Common | rabbit | charm, speed | — |
| `MUT_203` | Gecko Toes | FEET | REPTILE | Uncommon | gecko | sticky | — |
| `MUT_204` | Roller Skates | FEET | OBJECT | Uncommon | skate | speed | — |
| `MUT_205` | Hooves | FEET | MAMMAL | Common | goat | tank | — |
| `MUT_206` | Suction Cup Feet | FEET | MARINE | Uncommon | octopus | sticky | — |
| `MUT_207` | Ice Skates | FEET | ELEMENTAL | Rare | ice | speed, ice | — |
| `MUT_208` | Spring Boots | FEET | ROBOT | Rare | robot | speed | — |
| `MUT_209` | Root Feet | FEET | PLANT | Rare | tree | tank, regen | — |
| `MUT_210` | Moon Boots | FEET | ALIEN | Epic | alien_grey | light, alien | — |
| `MUT_211` | Cat Tail | TAIL | MAMMAL | Common | cat | charm | — |
| `MUT_212` | Dog Tail | TAIL | MAMMAL | Common | dog | charm, luck | — |
| `MUT_213` | Pig Curly Tail | TAIL | MAMMAL | Common | pig | luck | — |
| `MUT_214` | Fish Tail | TAIL | FISH | Common | fish | aquatic, speed | — |
| `MUT_215` | Lizard Tail | TAIL | REPTILE | Common | lizard | regen | — |
| `MUT_216` | Scorpion Tail | TAIL | ARACHNID | Rare | scorpion | fighter | `ABL_009` |
| `MUT_217` | Monkey Tail | TAIL | MAMMAL | Uncommon | monkey | grabby, chef | — |
| `MUT_218` | Beaver Tail | TAIL | MAMMAL | Uncommon | beaver | repair | — |
| `MUT_219` | Peacock Tail | TAIL | BIRD | Rare | peacock | charm | `ABL_029` |
| `MUT_220` | Skunk Tail | TAIL | MAMMAL | Rare | skunk | stinky | `ABL_024` |
| `MUT_221` | Crocodile Tail | TAIL | REPTILE | Uncommon | crocodile | fighter, aquatic | — |
| `MUT_222` | Rattlesnake Tail | TAIL | REPTILE | Uncommon | snake | loud | — |
| `MUT_223` | Stegosaurus Tail | TAIL | DINOSAUR | Rare | stegosaurus | fighter, armored | — |
| `MUT_224` | Extension Cord Tail | TAIL | OBJECT | Uncommon | cord | electric, repair | — |
| `MUT_225` | Mermaid Fin Tail | TAIL | FISH | Rare | mermaid | aquatic, charm | — |
| `MUT_226` | Fluffy Fox Tail | TAIL | MAMMAL | Uncommon | fox | luck, speed | — |
| `MUT_227` | Dragon Tail | TAIL | MYTHOLOGICAL | Epic | dragon | fire, fighter | `ABL_053` |
| `MUT_228` | Comet Tail | TAIL | ALIEN | Epic | comet | cosmic, speed, glow | `ABL_046` |
| `MUT_229` | Nine Fox Tails | TAIL | MYTHOLOGICAL | Legendary | fox_spirit | luck, charm, glow | — |
| `MUT_230` | Lightning Tail | TAIL | ELEMENTAL | Epic | storm | electric, speed | — |
| `MUT_231` | Tiny Chicken Wings | WINGS | BIRD | Common | chicken | light | `ABL_022` |
| `MUT_232` | Butterfly Wings | WINGS | INSECT | Uncommon | butterfly | charm, light | — |
| `MUT_233` | Moth Wings | WINGS | INSECT | Uncommon | moth | light, glow | — |
| `MUT_234` | Bat Wings | WINGS | MAMMAL | Uncommon | bat | flying, loud | — |
| `MUT_235` | Pigeon Wings | WINGS | BIRD | Common | pigeon | flying, luck | — |
| `MUT_236` | Bee Wings | WINGS | INSECT | Uncommon | bee | speed, light | — |
| `MUT_237` | Paper Airplane Wings | WINGS | OBJECT | Secret | paper | light, flying | — |
| `MUT_238` | Dragon Wings | WINGS | MYTHOLOGICAL | Epic | dragon | flying, fire | `ABL_051` |
| `MUT_239` | Helicopter Rotor | WINGS | ROBOT | Rare | robot | flying, robotic | — |
| `MUT_240` | Pterodactyl Wings | WINGS | DINOSAUR | Epic | ptero | flying, fighter | — |
| `MUT_241` | Fairy Wings | WINGS | MYTHOLOGICAL | Rare | fairy | charm, glow | `ABL_065` |
| `MUT_242` | Phoenix Wings | WINGS | MYTHOLOGICAL | Mythic | phoenix | flying, fire, regen | — |
| `MUT_243` | Porcupine Spines | BACK | MAMMAL | Uncommon | porcupine | armored, fighter | `ABL_015` |
| `MUT_244` | Turtle Backpack Shell | BACK | REPTILE | Common | turtle | armored | — |
| `MUT_245` | Jetpack | BACK | ROBOT | Epic | robot | flying, speed | `ABL_069` |
| `MUT_246` | Hermit Crab Shell | BACK | MARINE | Common | crab | armored, tank | — |
| `MUT_247` | Camel Humps | BACK | MAMMAL | Uncommon | camel | tank | — |
| `MUT_248` | Mushroom Cap | BACK | PLANT | Uncommon | mushroom | plant | `ABL_040` |
| `MUT_249` | Extra Arm Backpack | BACK | ROBOT | Rare | robot | multi, chef | `ABL_061` |
| `MUT_250` | Fire Extinguisher Tank | BACK | OBJECT | Rare | extinguisher | water, repair | — |
| `MUT_251` | Stink Bug Shell | BACK | INSECT | Rare | stinkbug | stinky | `ABL_056` |
| `MUT_252` | Ghost Sheet Cape | BACK | MYTHOLOGICAL | Epic | ghost | light | `ABL_059` |
| `MUT_253` | Electric Eel Skin | SKIN | FISH | Rare | eel | electric | `ABL_014` |
| `MUT_254` | Fireproof Skin | SKIN | ELEMENTAL | Uncommon | fire | fire, armored | — |
| `MUT_255` | Chameleon Skin | SKIN | REPTILE | Rare | chameleon | luck, speed | — |
| `MUT_256` | Frog Slime Skin | SKIN | AMPHIBIAN | Common | frog | sticky, regen | `ABL_048` |
| `MUT_257` | Rubber Skin | SKIN | OBJECT | Uncommon | rubber | tank | — |
| `MUT_258` | Golden Skin | SKIN | OBJECT | Legendary | gold | gold, luck, charm | — |
| `MUT_259` | Bear Fur | FUR | MAMMAL | Common | bear | tank | — |
| `MUT_260` | Sheep Wool | FUR | MAMMAL | Common | sheep | tank, charm | — |
| `MUT_261` | Tiger Stripe Fur | FUR | MAMMAL | Uncommon | tiger | fighter, speed | — |
| `MUT_262` | Yeti Frost Fur | FUR | MYTHOLOGICAL | Rare | yeti | ice, tank | — |
| `MUT_263` | Moss Fur | FUR | PLANT | Uncommon | plant | plant, regen | — |
| `MUT_264` | Static Fluff Fur | FUR | ELEMENTAL | Rare | storm | electric | — |
| `MUT_265` | Snake Scales | SCALES | REPTILE | Common | snake | speed | — |
| `MUT_266` | Fish Scales | SCALES | FISH | Common | fish | aquatic | — |
| `MUT_267` | Crocodile Scales | SCALES | REPTILE | Uncommon | crocodile | armored | — |
| `MUT_268` | Dragon Scales | SCALES | MYTHOLOGICAL | Epic | dragon | fire, armored | — |
| `MUT_269` | Pangolin Plates | SCALES | MAMMAL | Rare | pangolin | armored, tank | — |
| `MUT_270` | Rainbow Holo Scales | SCALES | ALIEN | Rare | holo | glow, charm | — |
| `MUT_271` | Cobweb Drape | FX | ARACHNID | Common | spider | sticky | — |
| `MUT_272` | Sparkle Aura | FX | MYTHOLOGICAL | Uncommon | sparkle | charm, glow | — |
| `MUT_273` | Flame Aura | FX | ELEMENTAL | Rare | fire | fire, glow | — |
| `MUT_274` | Storm Cloud Hat | FX | ELEMENTAL | Rare | storm | electric | — |
| `MUT_275` | Bubble Trail | FX | MARINE | Uncommon | bubble | aquatic | — |
| `MUT_276` | Pixel Glitch | FX | ROBOT | Secret | glitch | robotic, luck | — |
| `MUT_277` | Orbiting Meatballs | FX | FOOD | Rare | meatball | chef, luck | — |
| `MUT_278` | Falling Leaves | FX | PLANT | Common | plant | plant | — |
| `MUT_279` | Tiny Moons | FX | ALIEN | Epic | moon | cosmic | — |
| `MUT_280` | Mystery Fog | FX | ALIEN | Secret | glitch | cosmic, luck | — |

### C13.7 Rig & attachment contract ("skin-over-rig")
All characters (players, customers, employees, NPCs) use a standard **R15** rig for animation. The default body
part meshes are hidden (Transparency 1) and mutation visual MeshParts (Massless, CanCollide/CanTouch/CanQuery
false) are welded to the rig via named Attachments that `MorphAssemblyService` inserts. Baseline character
height 5.5 studs; parts are authored on a 0.25-stud grid at R15 standard scale; LEG parts carry a `LegLength`
attribute that sets `Humanoid.HipHeight`; NECK parts carry `NeckLength` that offsets the head.

| Slot | Host rig part | Attachment name(s) |
|---|---|---|
| HEAD | Head | `MMR_HeadCore` |
| FACE | Head | `MMR_FaceFront` |
| NOSE | Head | `MMR_Nose` |
| MOUTH | Head | `MMR_Mouth` |
| EYES | Head | `MMR_Eyes` |
| EARS | Head | `MMR_EarL`, `MMR_EarR` |
| HORNS | Head | `MMR_HeadTop` |
| NECK | UpperTorso | `MMR_Neck` |
| TORSO | UpperTorso, LowerTorso | `MMR_TorsoCore`, `MMR_Hips` |
| ARM_L / ARM_R | (Left/Right)UpperArm, LowerArm, Hand | `MMR_ArmL_Upper`, `MMR_ArmL_Lower`, `MMR_ArmL_Hand` (R mirrored) |
| HANDS | LeftHand, RightHand | `MMR_HandL`, `MMR_HandR` |
| LEG_L / LEG_R | (Left/Right)UpperLeg, LowerLeg | `MMR_LegL_Upper`, `MMR_LegL_Lower` (R mirrored) |
| FEET | LeftFoot, RightFoot | `MMR_FootL`, `MMR_FootR` |
| TAIL | LowerTorso | `MMR_TailBase` |
| WINGS | UpperTorso | `MMR_WingL`, `MMR_WingR` |
| BACK | UpperTorso | `MMR_Back` |
| SKIN / FUR / SCALES | all visual parts | surface variant swap (SurfaceAppearance/TextureID set), plus optional thin shell meshes |
| FX | HumanoidRootPart | `MMR_FXRoot` (ParticleEmitters, Beams, Trails) |

Part budgets: player morph ≤ 40 MeshParts and ≤ 15,000 triangles total; customer/employee visuals ≤ 24
MeshParts and ≤ 6,000 triangles (LOD swap beyond 60 studs to a 1,500-triangle impostor).

### C13.8 Secret mutation discovery conditions (fixed; A7 lists them, A12 places the secrets in the city)
| Part | Discovery condition |
|---|---|
| `MUT_040` Glitch Head | During `EVT_009` Blackout Night, interact with the flickering "ERROR" billboard in `DST_03` three times. |
| `MUT_048` Cosmic Void Face | Own ≥ 100 different mutation parts, then inspect the "Empty Exhibit" in the Morph Museum (`BLD_16`). |
| `MUT_112` Accordion Neck | Play the five busker instruments in `DST_07` in the order shown on a torn poster in a hidden alley. |
| `MUT_116` Noodle Neck | Serve `RCP_PST_008` The Infinite Noodle 10 times at PERFECT quality. |
| `MUT_237` Paper Airplane Wings | From the roof of City Hall (`BLD_09`), throw a paper menu (`ABL_005`) so it lands in the Downtown fountain. |
| `MUT_276` Pixel Glitch | Find all 8 hidden "dead pixels" (one each in DST_01–DST_08). |
| `MUT_280` Mystery Fog | Hold 5.0 ★ reputation for 50 consecutive customers, then visit the Mystery Market (`BLD_13`) during the city night cycle. |

**Tutorial first mutation** (QST_TUT_010): choose one of `MUT_145` Octopus Arm (Chef), `MUT_144` Crab Claw
Arm (Fighter), `MUT_153` Wrench Claw Arm (Repair) — granted free at Lv1 regardless of rarity requirement.

**Acquisition method codes** (A7 uses these): `SHOP_MART`, `SHOP_ROTATION` (Mystery Market), `LAB_FUSION`,
`CAPSULE` (earnable Morph Capsule), `QUEST`, `EVENT`, `ARENA`, `OFFLINE_FIND`, `ACHIEVEMENT`, `SECRET`,
`STARTER`.

**Default starter morph** (all new players): `MUT_117` Plain Human Torso, `MUT_139` ×2 arms, `MUT_179` ×2 legs,
and a random Common HEAD from {`MUT_001`, `MUT_002`, `MUT_003`, `MUT_004`, `MUT_005`, `MUT_006`, `MUT_008`} —
all `STARTER` acquisition.

---

## C14. Employees

### C14.1 Roles (fixed; A11 defines responsibilities)
| ID | Role | Online behavior summary | Offline contribution |
|---|---|---|---|
| `ROLE_CHEF` | Chef | cooks full recipes at assigned stations | kitchen capacity (required for offline) |
| `ROLE_PREP` | Prep Cook | chops/prepares components, feeds chefs | +15 % kitchen capacity per prep (max +45 %) |
| `ROLE_WAITER` | Waiter | seats customers, takes orders, delivers food | service capacity (needed at TIER_03+) |
| `ROLE_CASHIER` | Cashier | processes payments, boosts tips | +10 % service capacity, +1 % tip rate per 20 skill |
| `ROLE_DISH` | Dishwasher | washes plates | prevents "No Clean Plates" stalls (−20 % kitchen cap if absent at T4+) |
| `ROLE_CLEANER` | Cleaner | removes trash/spills | keeps cleanliness K high |
| `ROLE_REPAIR` | Repair Technician | repairs damaged objects | auto-repairs offline damage at discount |
| `ROLE_SECURITY` | Security Guard | intercepts angry customers | mitigates incident losses |
| `ROLE_MANAGER` | Restaurant Manager | buffs morale, coordinates | sets offline time cap |
| `ROLE_DELIVERY` | Delivery Worker | runs delivery orders | adds delivery revenue stream (+X % revenue) |
| `ROLE_STOCKER` | Ingredient Stocker | restocks special ingredients | ingredient discount 5–15 %, auto-buys special stock within player budget |
| `ROLE_ASST_MGR` | Assistant Manager | covers manager tasks | +2 h offline cap (requires Manager), −20 % incident losses |

### C14.2 Employee statistics (1–100 unless noted)
`Cooking Skill, Service Speed, Accuracy, Repair Skill, Combat Strength, Reliability, Energy (0–100 %, drains
while working), Morale (0–100), Salary (= wage MB/h), Efficiency (derived), Special Abilities (traits)`.
**Efficiency** = `RoleStatAvg × (0.6 + 0.4 × Morale/100) × (0.7 + 0.3 × Energy/100) × (1 + 0.001 × player EFFICIENCY)`.

### C14.3 Offline time caps (from the best assigned Manager)
| Manager | Cap |
|---|---|
| none | 2 h |
| Common / Uncommon Manager ("Basic") | 4 h |
| Rare Manager ("Experienced") | 8 h |
| Epic Manager ("Elite") | 12 h |
| Legendary Manager | 24 h |
| + Assistant Manager | +2 h (absolute max 24 h) |

### C14.4 Fixed archetypes
`EMP_001` = **"Ollie" the Octopus Intern** — ROLE_CHEF, Common, hire cost 0 (tutorial gift via QST_TUT_012),
wage 12 MB/h, Cooking 30, Service 15, Accuracy 28, Reliability 40; trait "Eight Arms, One Brain Cell"
(cooks 2 items at once, 5 % chance to put a pickle on everything). A11 defines EMP_002+ (≥ 75 total).
Must include the brief's examples: Octopus Chef, Cheetah Waiter, Rhino Security Guard, Spider Repair
Technician, Robot Cashier, Sloth Dishwasher, Dragon Chef.

---

## C15. Offline Simulation — Canonical Model (A11 elaborates with worked examples)

**Principles:** server-authoritative; timestamp-based (`os.time()` on the server only); deterministic (seeded RNG);
capped; idempotent claims; offline net/hour targets **35–50 %** of active net/hour at the same tier for a
well-staffed restaurant, never above 60 % [TUNABLE].

```
H_elapsed = max(0, now − lastSimAt) / 3600            -- server clock; negative → 0, flagged
H         = min(H_elapsed, OfflineCap)                -- §C14.3
Seed      = hash(UserId, lastSimAt, SIM_VERSION)      -- same inputs → same report
Steps     = hourly steps, last step fractional

Demand_off   = BaseDemand[tier] × RepMult × DecorMult × 0.6            -- OFFLINE_DEMAND_FACTOR [TUNABLE]
Cap_seat     = Seats × 3600 / 300                                      -- VISIT_SECONDS_OFFLINE = 300 [TUNABLE]
Cap_kitchen  = Σ_chefs (3600 / PrepSec_avg) × Eff_chef / 1.4 × (1 + 0.15 × min(3, preps)) × DishFactor
Cap_service  = (tier ≤ 2) ? Cap_kitchen
             : waiters ≥ 1 ? Σ_waiters (3600 / 45) × Eff_waiter × (1 + 0.10 × cashiers)
             : 0.30 × Cap_kitchen                                       -- chef shouts orders out the window
Q            = min(Demand_off, Cap_seat, Cap_kitchen, Cap_service)      -- customers / hour
N_step       = Q × stepHours (fractional accumulator, deterministic rounding)
PrepSec_avg  = menu-weighted mean recipe base prep time (only recipes whose stations exist, whose special stock
               remains, and whose difficulty ≤ chef skill tier: D ≤ 1 + floor(CookingSkill / 25))
AvgTicket    = 1.4 × menu-weighted mean price of those recipes
Quality q    = min(0.95, 0.70 + 0.25 × avgChefAccuracy / 100)
Revenue      = N × AvgTicket × q
Tips         = Revenue × (0.04 + 0.04 × avgWaiterService / 100) × (1 + 0.01 × floor(cashierSkill / 20))
IngredientCost = N × AvgIngredientCost × (1 − StockerDiscount) × (1 − 0.0015 × EFFICIENCY)
Wages        = Σ wage_i × hoursWorked_i
Incidents    = count = floor(H × 0.6 × (1 − SecurityMitigation)) + seeded extra roll; each picks from §36.9 by
               weight; Σ negative effects ≤ 10 % of (Revenue + Tips); Σ positive ≤ 15 %
Repairs      = offline damage points × cost/pt; auto-paid at −(RepairSkill/200) discount if a Repair Tech exists,
               else left as damaged objects for the player to fix (cheaper than replacing; atmosphere −)
Net_step     = Revenue + Tips − IngredientCost − Wages − AutoRepairs ± Incidents
Rule         = if Net_step < 0 the Manager "closes early": simulation stops, that step's wages are not charged
Energy       = −8 %/h per employee (−5 %/h with a Manager); Efficiency uses Energy each step; Morale −1/h offline
Discoveries  = per hour: 8 % chance of 1–3 MS; 1 % chance of a rare ingredient crate; ≤ 1 Morph Capsule per real day
Net          = max(0, Σ Net_step)
```
**Requirement to run:** ≥ 1 `ROLE_CHEF` assigned. Without one the report shows 0 customers and a hint.

**Persistence & idempotency:** in **one** session-locked `UpdateAsync` the server computes the report, stores
`pendingOfflineReport = {reportId, fromTs, toTs, ...}` and sets `lastSimAt = toTs`. **Collect** moves the
amount to the wallet if `reportId ∉ claimedReportIds` (ring buffer of last 20) and appends it. Reconnects
reload the same pending report; nothing is recomputed for an interval already simulated. If a pending report
exists when a new interval is simulated, the new values are merged into it (each interval capped separately).

---

## C16. Morph City

### C16.1 Districts (fixed)
| ID | District | Unlock | Connects to |
|---|---|---|---|
| `DST_01` | Restaurant Row | start | DST_02, DST_03, DST_08 |
| `DST_02` | Mutation Market | start | DST_01, DST_03, DST_06 |
| `DST_03` | Downtown Morph City | start (tutorial step 10) | DST_01, DST_02, DST_04, DST_05, DST_07, DST_10 |
| `DST_04` | Industrial District | L8 | DST_03, DST_09 |
| `DST_05` | Monster Mall | L6 | DST_03, DST_07 |
| `DST_06` | Mutation Research District | L15 | DST_02, DST_09 |
| `DST_07` | Entertainment District | L10 | DST_03, DST_05, DST_10 |
| `DST_08` | Residential District | L4 | DST_01, DST_09 |
| `DST_09` | Underground Mutation Sewers | L20 | DST_04, DST_06, DST_08 (hidden manholes) |
| `DST_10` | Arena District | L12 | DST_03, DST_07 |

Travel: walking/sprinting; **Morph Metro** fast-travel between district stations once each station is
discovered (free); **Pigeon Taxi** from any street corner to any discovered district (25 MB × tier,
cosmetic ride); restaurant **Return Door** button (free, 10 s cooldown) from anywhere in the city.

### C16.2 Buildings (fixed; A12 specifies every field)
| ID | Building | District |
|---|---|---|
| `BLD_01` | Mutation Mart | DST_02 |
| `BLD_02` | Body Mods | DST_02 |
| `BLD_03` | Restaurant Supplies | DST_01 |
| `BLD_04` | Recruitment Office | DST_03 |
| `BLD_05` | Training Gym | DST_10 |
| `BLD_06` | Cooking Academy | DST_03 |
| `BLD_07` | Repair Workshop | DST_04 |
| `BLD_08` | Morph Arena | DST_10 |
| `BLD_09` | City Hall | DST_03 |
| `BLD_10` | Job Board | DST_01 |
| `BLD_11` | Mutation Laboratory | DST_06 |
| `BLD_12` | Monster Mall | DST_05 |
| `BLD_13` | Mystery Market | DST_09 |
| `BLD_14` | Food Critic Headquarters | DST_07 |
| `BLD_15` | Delivery Depot | DST_04 |
| `BLD_16` | Morph Museum | DST_06 |
| `BLD_17` | Restaurant Row Plots (player restaurants) | DST_01 |
| `BLD_18` | Central Morph Metro Station | DST_03 |
| `BLD_19` | Morph Park & Fountain | DST_08 |
| `BLD_20` | Weird Produce Stand | DST_02 |
| `BLD_21` | Sewer King's Throne Room | DST_09 |
| `BLD_22` | Showcase Stage | DST_07 |

### C16.3 Key named NPCs (fixed; A13 adds NPC_031+ for ≥ 100 total and fully specifies all)
| ID | Name | Morph | Role | Location |
|---|---|---|---|---|
| `NPC_001` | Nana Gristle | Tortoise head + Toaster torso + oven-mitt hands | Tutorial mentor; your great-aunt who left you the shack (appears via a cranky hologram menu board) | BLD_17 |
| `NPC_002` | Mayor Moosington | Moose head + Penguin body | Mayor; issues permits | BLD_09 |
| `NPC_003` | Baron Von Bistro | Shark head + Peacock tail + monocle | Comedic rival restaurateur (story antagonist), runs "Le Fancy Fin" | DST_01 |
| `NPC_004` | Mutty McMutface | Chameleon head + vending-machine torso | Mutation Mart shopkeeper | BLD_01 |
| `NPC_005` | Glamtrax | Flamingo neck + Robot body | Body Mods stylist | BLD_02 |
| `NPC_006` | Bolt Butterworth | Beaver head + forklift legs | Restaurant Supplies clerk | BLD_03 |
| `NPC_007` | Ms. Hirewell | Owl head + filing-cabinet torso | Recruitment officer | BLD_04 |
| `NPC_008` | Coach Crunch | Gorilla arms + Pigeon head | Training Gym coach | BLD_05 |
| `NPC_009` | Professor Saucington | Octopus head + tweed torso | Cooking Academy dean | BLD_06 |
| `NPC_010` | Wrenchy | Spider legs + Robot head | Repair Workshop mechanic | BLD_07 |
| `NPC_011` | Rex Rumbleton | T-Rex head + microphone hand | Arena announcer | BLD_08 |
| `NPC_012` | Pinboard Pete | Pigeon head + corkboard torso | Job Board keeper | BLD_10 |
| `NPC_013` | Dr. Splice | Axolotl head + lab coat + Robot arm | Mutation Lab scientist | BLD_11 |
| `NPC_014` | Mallory Megamall | Peacock tail + escalator legs | Monster Mall manager | BLD_12 |
| `NPC_015` | The Hooded Hagfish | Hagfish head + mysterious cloak | Mystery Market merchant | BLD_13 |
| `NPC_016` | Madame Fourchette | Giraffe neck + Squid tentacles | Chief food critic | BLD_14 |
| `NPC_017` | Dispatch Dot | Snail head + rocket boots | Delivery Depot boss | BLD_15 |
| `NPC_018` | Curator Fossilbottom | Triceratops head + grandfather-clock torso | Museum curator | BLD_16 |
| `NPC_019` | Conductor Choo | Centipede body + train-engine head | Morph Metro conductor | BLD_18 |
| `NPC_020` | King Ratbeard | Giant Rat head + crown + Crab claws | Sewer King (event boss for EVT_007) | BLD_21 |
| `NPC_021` | Vlogzilla | Lizard head + smartphone face | Influencer celebrity | DST_07 |
| `NPC_022` | Inspector Grimewell | Mole head + clipboard hands | Health inspector | DST_03 |
| `NPC_023` | Farmer Fungus | Mushroom cap + Cow body | Weird produce vendor | BLD_20 |
| `NPC_024` | DJ Morphenstein | Bat ears + boombox torso | Showcase Stage host | BLD_22 |
| `NPC_025` | Old Man Pigeon | Pigeon head + Muscle torso | Park regular, gossip & tips | BLD_19 |
| `NPC_026` | Sergeant Rhonda | Rhino horn + traffic-cone body | City security chief | DST_03 |
| `NPC_027` | Zorp | Alien Grey head + tour-bus torso | Alien tour guide | DST_07 |
| `NPC_028` | Sous-Chef Sniffles | Rat head + mop arm | Baron's sidekick (redeemable later) | DST_01 |
| `NPC_029` | Chef Supreme Omnivora | Dragon head + Kraken tentacle arms | Legendary chef; story finale & tournament host | DST_07 |
| `NPC_030` | Anchor Andy | Anglerfish head + news desk | City news anchor (event announcements) | DST_03 |

### C16.4 Restaurant Row plot model
8 plots per server (`BLD_17`), each holding a player's exterior façade that visibly upgrades with tier;
interiors are instanced (§C3). Visiting a friend = walking into their door (same server) or joining their
server via the friends list (TeleportService to their server).

### C16.5 City events master list (A12 defines schedule, rules, rewards; others may reference)
| ID | Event |
|---|---|
| `EVT_001` | Giant Food Festival |
| `EVT_002` | Mutation Parade |
| `EVT_003` | Citywide Restaurant Rush |
| `EVT_004` | Angry Customer Invasion |
| `EVT_005` | Legendary Chef Tournament |
| `EVT_006` | Mutation Meteor Shower |
| `EVT_007` | Giant Rat King Attack |
| `EVT_008` | Food Critic Convention |
| `EVT_009` | Blackout Night |
| `EVT_010` | Restaurant Repair Emergency |
| `EVT_011` | Upside-Down Day |
| `EVT_012` | Pickle Rain |
| `EVT_013` | Sewer Flood |
| `EVT_014` | Celebrity Chef Visit |
| `EVT_015` | Tiny Day |
| `EVT_016` | Giant Day |
| `EVT_017` | Polite Robot Uprising |
| `EVT_018` | Alien Tourist Season |
| `EVT_019` | Hot Sauce Heatwave |
| `EVT_020` | Frozen Snap |
| `EVT_021` | Morph Swap Hour |
| `EVT_022` | Lost Pet Kraken |
| `EVT_023` | Delivery Frenzy |
| `EVT_024` | Mystery Market Midnight Sale |
| `EVT_025` | Arena Brawl Bash |
| `EVT_026` | Health Inspector Sweep |
| `EVT_027` | Downtown Dance-Off |
| `EVT_028` | Neon Lights Festival |
| `EVT_029` | Haunted Kitchen Night (seasonal: October) |
| `EVT_030` | Snowmorph Holiday (seasonal: December) |
| `EVT_031` | Spring Sprout Bloom (seasonal: April) |
| `EVT_032` | Bug Swarm Brunch |

### C16.6 Trophy decorations (quest/event rewards; A10 must list them in §36.13 as non-purchasable)
`FRN_901` Golden Spatula Trophy · `FRN_902` Rat King's Crown Display · `FRN_903` Critic's Five-Star Plaque ·
`FRN_904` Arena Champion Belt Case · `FRN_905` Baron's Defeated Mustache Portrait · `FRN_906` Meteor Chunk Lamp ·
`FRN_907` Parade Float Mini · `FRN_908` Kraken Plush · `FRN_909` Museum Replica Fossil · `FRN_910` Omnivora's
Signed Apron. (Regular furniture uses `FRN_001`–`FRN_899`.)

---

## C17. Quests

### C17.1 Tutorial quest IDs (fixed; A13 defines rows in §20, A1 scripts them in §32)
| ID | Title | Teaches |
|---|---|---|
| `QST_TUT_001` | Welcome to the Shack | movement, entering the restaurant |
| `QST_TUT_002` | Your First Order | taking an order |
| `QST_TUT_003` | Burger 101 | gathering, grilling, assembling `RCP_BRG_001` |
| `QST_TUT_004` | Plate It, Serve It | plating & serving |
| `QST_TUT_005` | Happy Customer, Happy Wallet | satisfaction, payment, tips |
| `QST_TUT_006` | Uh-Oh, Karenosaurus | first tantrum (scripted `PER_001`) |
| `QST_TUT_007` | Defend the Diner | block, dodge, swipe, Calm Down! |
| `QST_TUT_008` | Fix It Up | repairing a broken table |
| `QST_TUT_009` | Cash In | collecting earnings, the wallet |
| `QST_TUT_010` | Your First Mutation | Mutation Mart, free starter part choice, equip |
| `QST_TUT_011` | Fancy Upgrades | buying the first restaurant upgrade |
| `QST_TUT_012` | Hire Help | hiring `EMP_001`, offline income preview |

### C17.2 Quest type codes
TUT tutorial · STY story · DLY daily · WKY weekly · CHF cooking challenge · CBT combat challenge · RPR repair
challenge · EXP exploration challenge · EMP employee management challenge · RST restaurant expansion challenge.

### C17.3 Story frame (A13 writes the campaign; others may allude to it)
Ten chapters, one per restaurant tier. You inherit Nana Gristle's shack; the snooty rival **Baron Von Bistro**
(`NPC_003`) wants Restaurant Row for his luxury chain; **Madame Fourchette** (`NPC_016`) holds the city's star
ratings; **King Ratbeard** (`NPC_020`) keeps "borrowing" ingredients from below; the finale is the
**Legendary Chef Tournament** (`EVT_005`) hosted by **Chef Supreme Omnivora** (`NPC_029`). The Baron is defeated
by cooking, not combat, and ends up a (grumpy) friend. Chapter 5 unlocks Alien Cuisine (Zorp, `NPC_027`).

### C17.4 Reward vocabulary (quests, achievements, milestones, events may grant only these)
MB, MS, RT, XP, Morph Capsules, specific `MUT_` parts, recipe unlocks (`RCP_`), trophy decorations
(`FRN_901`–`FRN_910`), skill points, stat respec tokens, titles (plain text, cosmetic), emotes (plain text,
cosmetic, earnable), cosmetic color palettes.

---

## C18. Skill Trees (IDs)
`SKL_CHEF_01`–`SKL_CHEF_20+`, `SKL_CMBT_01`–`SKL_CMBT_20+`, `SKL_RPR_01`–`SKL_RPR_20+` (primary trees, ≥ 20
nodes each), `SKL_SVC_01`–`SKL_SVC_10+` (Customer Service specialization), `SKL_MGMT_01`–`SKL_MGMT_10+`
(Employee Management specialization). **Skill points:** 1 per level from L2 (99 by L100) + quest/achievement
grants; total node cost must exceed available points so players must choose. Free full respec once per 7 days.

---

## C19. Roblox Services (fixed names; A17 specifies every field)
| Service | One-line responsibility |
|---|---|
| `PlayerDataService` | load/save profiles with session locking, schema migration, autosave |
| `RestaurantService` | restaurant instance lifecycle, plot assignment, interior spawning, tier state |
| `OrderService` | order generation (menu + modifications), tickets, order validation at serve |
| `RecipeService` | recipe/ingredient definitions, learning, menu management |
| `CookingService` | station state machines, timers, quality scoring, station locks |
| `CustomerAIService` | customer spawning, SPCV proxies, state machines, satisfaction & anger |
| `CombatService` | hit validation, damage, abilities, status effects, KO/respawn |
| `MutationService` | mutation ownership, equip rules, stats, upgrades, fusion, capsules |
| `MorphAssemblyService` | builds morph models from part lists (server for players, client builder for SPCV) |
| `EmployeeService` | hiring, roster, assignments, online work AI, wages, morale/energy |
| `OfflineEarningsService` | deterministic offline simulation, reports, idempotent claims |
| `EconomyService` | the only module that mutates currency; transaction log; sinks/sources |
| `InventoryService` | items, stock (special ingredients), furniture inventory |
| `QuestService` | quest state, objectives, rewards, daily/weekly resets |
| `CityEventService` | event scheduling (cross-server via MemoryStore), event runtime |
| `MultiplayerService` | co-op permissions, guests, visits, arena matchmaking |
| `BuildingService` | furniture placement grid, validation (path connectivity), tier upgrades |
| `RepairService` | durability, damage states, repair jobs/minigame |
| `ProgressionService` | XP, levels, stats allocation, skill trees, achievements, milestones |
| `UIController` | client UI state machine, screens, HUD, input-mode adaptation |

---

## C20. Analytics
Use Roblox `AnalyticsService` (`LogOnboardingFunnelStepEvent`, `LogFunnelStepEvent`, `LogEconomyEvent`,
`LogProgressionEvent`, `LogCustomEvent`) plus an internal event schema; internal names `mmr_<snake_case>`.

---

## C21. Animation & Sound IDs
`ANM_001`–`ANM_300` general library (A16), `ANM_301`–`ANM_370` = ability animations for `ABL_001`–`ABL_070`
(ANM_3xx ↔ ABL_0xx, same last two digits; `ANM_370` ↔ `ABL_070`).
**Core animations (fixed IDs; A16 must define them, anyone may reference):**

| ID | Animation | ID | Animation |
|---|---|---|---|
| `ANM_001` | Idle | `ANM_025` | Scoop ice cream |
| `ANM_002` | Walk | `ANM_026` | Pizza peel slide |
| `ANM_003` | Run | `ANM_027` | Steamer lid lift |
| `ANM_004` | Jump | `ANM_028` | Infuse (mutagen pump) |
| `ANM_005` | Fall/land | `ANM_029` | Anti-grav toss |
| `ANM_006` | Carry item (upper body) | `ANM_030` | Extinguish fire |
| `ANM_007` | Carry tray | `ANM_040` | Customer sit |
| `ANM_008` | Wobbly gait (mismatched legs) | `ANM_041` | Read menu |
| `ANM_010` | Chop | `ANM_042` | Order wave |
| `ANM_011` | Grill flip | `ANM_043` | Eat |
| `ANM_012` | Fryer dunk | `ANM_044` | Pay |
| `ANM_013` | Oven load | `ANM_045` | Tip flourish |
| `ANM_014` | Stir pot | `ANM_046` | Impatient foot tap |
| `ANM_015` | Blend (hold lid) | `ANM_047` | Complain (arms flail) |
| `ANM_016` | Mix bowl | `ANM_048` | Throw food |
| `ANM_017` | Assemble stack | `ANM_049` | Flip table |
| `ANM_018` | Plate & garnish | `ANM_050` | Tantrum stomp |
| `ANM_019` | Serve (hand-off) | `ANM_051` | Victory dance |
| `ANM_020` | Pour drink | `ANM_052` | Dizzy stars |
| `ANM_021` | Wash dishes | `ANM_053` | Apologize bow |
| `ANM_022` | Mop / clean | `ANM_054` | Flee (cartoon scramble) |
| `ANM_023` | Trash toss | `ANM_055` | Escorted out (grumble shuffle) |
| `ANM_024` | Sauté pan toss | `ANM_060` | Hammer repair |
| `ANM_061` | Weld / bolt repair | `ANM_062` | Seeing Stars (KO) |
| `ANM_063` | Respawn poof | `ANM_064` | Level-up celebrate |
| `ANM_065` | Mutation equip flex | `ANM_066` | Cash register cha-ching |

Sound IDs `SFX_001`+ and music `MUS_001`+ are defined only by A16; other sections describe audio in words.

---

## C22. Edge-Case Rulings (all sections must agree with these)
| # | Situation | Ruling |
|---|---|---|
| E1 | Owner disconnects while cooking | Restaurant enters **Closing**: online employees finish current tickets; otherwise seated customers leave paying 0 with a "Closed for the day!" sign (no reputation loss). In-progress basic food is discarded (no charge); special ingredients in stations return to stock. Profile saves on PlayerRemoving; `lastSimAt` = save time. Guests are moved to the street. |
| E2 | Customer attacks while player is in a menu | Full-screen menus cannot be opened while In Combat or while a level-5 customer targets you ("Can't shop during a brawl!"). If a customer turns hostile while a full-screen menu is open, the menu auto-closes and the player gets 1.5 s of invulnerability. Overlay panels (order queue, map) stay usable. |
| E3 | Restaurant damaged while an employee repairs it | The repair job absorbs new damage (remaining work grows); if the object reaches Destroyed, the job converts to Rebuild. Cost is charged once at completion for damage actually repaired — never double. |
| E4 | Changing mutations during combat | Blocked while In Combat (6 s). Otherwise a loadout swap is a 3 s channel (interrupted by damage) with a 10 s cooldown; single-part equips in the Morph menu are instant (menu itself unavailable in combat). |
| E5 | Returning after 30 days | Offline time capped at the manager cap (≤ 24 h); report shows "capped". Wages only for simulated hours. Absence ≥ 7 days grants a "Welcome Back Crate" (1 Morph Capsule + 50 MS). No decay of restaurant, employees, or mutations. |
| E6 | DataStore failure | Reads/writes retry with exponential backoff (1, 2, 4, 8, 16 s; max 5). If the profile cannot be loaded, the player enters **Safe Mode** (cannot earn/spend; friendly banner) and is kicked with a retry message after 60 s. Saves on leave retry within BindToClose budget; session lock prevents other servers overwriting. Max data-loss window = autosave interval. |
| E7 | Two players use the same station | Locks are **per station slot**: one interactor per slot; multi-slot stations (grill 2+, stove burners) allow simultaneous use on different slots. Items are restaurant-owned, so co-op players may finish each other's items. |
| E8 | No money to pay employees | Balance never goes negative. Wages are paid from income; if a wage tick can't be covered, employees take an **Unpaid Break** (stop working, Morale −5/h) until funds exist. Offline: net floored at 0 and the manager closes early. |
| E9 | No ingredients | Basic ingredients are unlimited (cost netted at serve). Special-ingredient recipes go SOLD OUT and are not ordered. If every menu item is sold out, `RCP_BRG_001` is auto-added as a fallback. |
| E10 | Customer cannot reach the table | Placement validation rejects layouts that disconnect the door from any seat. At runtime, if a path fails twice or the customer is stuck > 6 s, they "poof" (cartoon puff, "Pardon me!") to the seat. |
| E11 | Offline earnings received twice after a reconnect | Impossible by design: report + `lastSimAt` written atomically under session lock; claims are idempotent by `reportId` with a `claimedReportIds` ring buffer; a second server cannot load the profile while locked. |
| E12 | Guest damages a friend's restaurant | Damage from guests and from customers during co-op is repaired free by the owner's "Co-op Insurance" after the visit; guests cannot sell, move, or store owner furniture, nor spend owner currency. |
| E13 | Server shutdown | BindToClose saves all profiles; restaurant states (damage, stock, pending tickets discarded) persist; players get a teleport to a new server. |
| E14 | Player levels up mid-rush | Level-up toast only; stat-point allocation is deferred until the player opens the menu (never interrupts cooking). |

## 1. Executive Summary

> This section summarizes the whole document for decision makers and points
> to the sections that specify each system. Where a number appears here it is quoted from canon; every system
> section that owns the number is authoritative for its details.

### 1.1 The Pitch

**Mystery Morph Restaurant** is a chaotic cooking-tycoon brawler for Roblox. You inherit your great-aunt Nana
Gristle's Broken Burger Shack in Morph City, where every citizen is a bolted-together mutant: bear heads on fish
bodies, toasters with chicken legs, giraffe-necked squids with opinions about cheese. You cook ridiculous food
for ridiculous customers, and when a Karenosaurus decides her pizza is "too circular," a flung pickle can start a
chain reaction that ends in a full restaurant brawl, a flipped table, and you calmly repairing it with a wrench
claw you got from the Mutation Mart. Every Morph Buck you earn goes back into **your own body**. You collect and
equip any of 280 swappable mutation parts across 22 anatomy slots, so you become a faster cook, a tougher bouncer,
a quicker repairer, and a funnier-looking creature. You grow the shack into the Legendary Mutation Restaurant
and hire a mutant staff who keep cooking while you're offline. Then you come back to a "WELCOME BACK, YOU WEIRDO!"
report, a pile of money, and a new mutation to try on.

### 1.2 Key Facts

| Fact | Value | Source |
|---|---|---|
| Title | Mystery Morph Restaurant | brief |
| Genre | Restaurant simulation · cooking chaos · creature collection · character customization · action combat · tycoon · social multiplayer · idle economy | brief |
| Platform | Roblox: desktop (keyboard and mouse), tablet and phone (touch), console and PC controller | §24, §30 |
| Audience | Ages 8–16. Two design segments: 8–11 ("Gigglers & Collectors") and 12–16 ("Optimizers & Show-Offs"); see §2 | §2 |
| Server size | 8 players, with 8 restaurant plots on Restaurant Row per server; instanced interiors | canon C3, §27 |
| Session targets | First session ≥ 20 min (15-min tutorial + first free play). Short session 5–15 min. Medium session 15–45 min. 2–3 check-ins per day to collect offline earnings | §4, §32 |
| Recipes | **150** recipes in **15** categories (Burgers 15, Pizza 15, Tacos 10, Sandwiches 10, Soups 10, Pasta 10, Breakfast 10, Desserts 15, Drinks 15, Seafood 10, Salads 5, Fried 5, Alien 10, Mutation 5, Legendary 5) | §6, §36.2 |
| Order modifications | ≥ 75 ridiculous but achievable requests | §6.18 |
| Kitchen stations | 24 station types (22 standard + Mutagen Infuser and Anti-Gravity Wok late-game) with 5 upgrade levels | §5 |
| Mutation parts | **280** parts · **22** anatomy slots · **16** categories · **7** rarities (63 Common, 84 Uncommon, 75 Rare, 36 Epic, 10 Legendary, 5 Mythic, 7 Secret) | §12, §36.3 |
| Synergies / example combos | ≥ 75 synergy rules (family/category/tag based) · ≥ 100 documented example morphs | §12.9, §12.10, §36.4, §36.5 |
| Customer personalities | **32** personalities, each with 1 of 7 NPC combat styles | §9 |
| Abilities / status effects | **70** abilities (8 base kit, 52 mutation combat, 10 mutation utility) · 20 status effects | §11, §36.6, §36.7 |
| Restaurant | **10** tiers, from Broken Burger Shack (4 seats) to Legendary Mutation Restaurant (24 seats); ≥ 100 furniture items + 10 trophies | §15, §36.12, §36.13 |
| Employees | **12** roles · **75+** archetypes · 5 rarities · offline cap 2 h → 24 h by Manager quality | §16, §17, §36.8 |
| Morph City | **10** districts · **22** buildings · **100+** named NPCs · **100+** quests · **32** city events (3 seasonal) | §18–§20, §36.10, §36.11 |
| Progression | Level cap 100 (≈ 185–200 active hours) · 9 stats · 3 primary + 2 specialization skill trees | §14 |
| Currencies | Morph Bucks (MB), Mutation Shards (MS), Research Tokens (RT). No other currencies | §22 |
| Monetization | Cosmetics only. No paid random items, no pay-to-win, offline earnings never tied to Robux | §23 |

### 1.3 Unique Selling Points

1. **A morph-centric economy.** Most restaurant tycoons run out of things to buy once the dining room is full.
   Here the restaurant is the *engine* and the player's own body is the *destination*. Every part changes
   gameplay: an Octopus Arm (`MUT_145`) adds a carry slot and Octo-Flurry (`ABL_012`), a Wrench Claw Arm
   (`MUT_153`) adds Repair Burst (`ABL_062`), and a Cheetah Leg (`MUT_186`) adds Cheetah Dash (`ABL_063`). Each one
   is also a visual joke worth showing off. 280 parts in 22 slots support millions of distinct creatures, so
   collection and optimization never hit a ceiling (§12, §13).
2. **Emergent chaos chain reactions.** Customers are systemic actors. A 7-level anger model (canon C11.5), 7
   combat styles, thrown food as scripted arcs, and destructible furniture with 5 damage states combine into
   unscripted brawls: a dodged burger hits a Polite Demon (`PER_003`), who stops being polite, who knocks over a
   table, which you then repair. No two rushes play out the same (§8, §10, §11).
3. **An employee-run offline restaurant.** Hired mutants (Ollie the Octopus Intern `EMP_001` is your first) run
   the restaurant while you are away. A deterministic, server-authoritative, capped simulation (canon C15) turns
   staff quality, menu, reputation and decor into an offline report full of incidents ("Your Sloth Dishwasher
   washed exactly four plates"). It gives players a reason to come back daily without replacing active play (§16,
   §17).

### 1.4 The Core Loop

> **Cook → Earn → Morph → Become More Powerful → Run a Better Restaurant → Earn More → Discover Rarer Morphs**,
> and when the player logs off, employees keep that loop turning.

Cooking and serving well raises satisfaction, which raises payment, tips and reputation (canon C11). Reputation
raises demand. The Morph Bucks go into mutations (stats, abilities, carry capacity, looks) and into the restaurant
(tiers, stations, decor, staff), which makes the next shift faster, calmer and more profitable. Canon C4.4 states
the split as about **50 % of income to tiers and expansion, about 50 % to mutations, furniture, staff and
upgrades**. The full loop, including the offline branch, is diagrammed in §4 (`core-gameplay-loop`).

### 1.5 Monetization Stance

- **Robux buy cosmetics only** (§23): morph skins and color palettes, restaurant themes, decorative furniture packs,
  emotes, extra *cosmetic* loadout slots, VIP visual effects.
- **Never sold for Robux:** mutation parts with stats, abilities, currencies (MB/MS/RT), employees, offline time
  caps or offline multipliers, recipes, tiers, skill points, capsules.
- **No paid random rewards.** Morph Capsules are earnable only, and their odds are disclosed in the UI (canon C4.7,
  with a 40-capsule pity).
- **Everything needed to finish the game is earnable**, including all Legendary, Mythic and Secret parts and every
  story chapter.

### 1.6 MVP vs Launch (summary; schedule in §34)

The scope below is indicative. §34 is authoritative for what each phase contains and for its completion criteria.

| Scope | Contents (summary) |
|---|---|
| **MVP / vertical slice** | TIER_01–TIER_03; the 4 starter stations plus STOVE/OVEN; ~25 recipes; ~60 mutation parts including the three tutorial parts; ~10 personalities including `PER_001`; base combat kit `ABL_001`–`ABL_008`; damage and repair; `EMP_001` plus ~10 archetypes; offline simulation with 2 h / 4 h caps; full tutorial (§32); `DST_01`–`DST_03`; basic quests; analytics funnel |
| **Launch** | All 10 tiers; 150 recipes; 280 parts; 32 personalities; 70 abilities; 12 roles / 75+ archetypes; all 10 districts and 22 buildings; 100+ NPCs and quests; 32 events on rotation; co-op visits; opt-in arena; cosmetic shop |
| **Live operations** | Seasonal events (`EVT_029` October, `EVT_030` December, `EVT_031` April), new parts, recipes, districts and personalities on the 12-month plan in §33 |

### 1.7 KPI Targets [TUNABLE]

Targets for the first 90 days after launch. Measurement definitions and event schemas belong to §31. Tuning
levers are listed so that a missed KPI maps to a specific system.

| KPI | Target | Primary lever if missed |
|---|---|---|
| D1 retention | ≥ 35 % [TUNABLE] | tutorial pacing (§32), first offline report hook (§17) |
| D7 retention | ≥ 15 % [TUNABLE] | mutation pacing (§12, §22), story chapters 1–3 (§20) |
| D30 retention | ≥ 6 % [TUNABLE] | mid-game tiers 4–6, events (§18), arena (§21) |
| Average session length | ≥ 22 min [TUNABLE] | medium-session activity menu (§4.3) |
| Sessions per DAU | ≥ 2.0 [TUNABLE] | offline caps and check-in rhythm (§4.5, §17) |
| Tutorial completion (step 12 ÷ step 1 of `mmr_tutorial_step_NN`) | ≥ 80 % [TUNABLE] | §32 step timings, skip and recovery rules |
| Tutorial skip rate (of players offered the skip) | ≤ 15 % [TUNABLE] | the skip should be rare because the tutorial is fun |
| New players who hire their first employee in session 1 | ≥ 75 % [TUNABLE] | `QST_TUT_012` placement and offline preview card |
| New players who equip their first mutation in session 1 | ≥ 85 % [TUNABLE] | `QST_TUT_010` ceremony |
| Median active time to TIER_02 | ≤ 90 min [TUNABLE] (a saver gets there in ≈ 70 min; canon pacing ≈ 60 min) | tutorial MB rewards, TIER_01 income (canon C4.4) |
| Offline report collect rate (collected ÷ shown) | ≥ 95 % [TUNABLE] | Welcome Back screen clarity (§17, §24) |
| D1 returners whose first screen is a Welcome Back report | ≥ 70 % [TUNABLE] | `EMP_001` hire rate, cap messaging |
| Offline share of MB income (guardrail, L5) | D7 median ≤ 60 %, D30 median ≤ 70 % [TUNABLE]; see §4.5 for the canon-default forecast | OFFLINE_DEMAND_FACTOR first, then cap semantics (canon C14.3, C15) |
| D7 players owning ≥ 15 distinct mutation parts | ≥ 50 % [TUNABLE] | capsule sources, Mart prices (canon C4.5–C4.7) |
| Sessions of ≥ 10 min with ≥ 1 brawl (anger level ≥ 5) | ≥ 70 % [TUNABLE] | escalation probabilities (§10), brawl cadence targets (§3.2.3) |
| Players who visit or co-op another restaurant by D7 | ≥ 20 % [TUNABLE] | §21 social features, events |
| Paid random-reward purchases | **0** (hard rule, not tunable) | §23 |
| Crash-free sessions / join→HUD p95 | ≥ 99.5 % / ≤ 20 s | §27, §30 |

### 1.8 Document Map: How to Read This GDD

**Conventions.** Every value tagged **[TUNABLE]** is a balancing assumption: implement it exactly as written, and
keep it data-driven so it can be tuned. IDs (`RCP_`, `MUT_`, `PER_`, …) are permanent and must resolve to a
database row. Acceptance criteria are tagged `AC-<section>-<NN>` and are the test oracle for §35 and §40. If a
section and the canon file ever disagree, canon wins until the canon is amended.

| Sections | What you will find | Read first if you are… |
|---|---|---|
| §1–§4 | Vision, tone, pillars, cross-cutting rules, the five gameplay timescales including offline | everyone |
| §5–§7 | Cooking stations, actions, timing and quality; recipe and ingredient databases; order modifications (§6.18) | gameplay and content designers |
| §8–§11 | Customer AI state machine, 32 personalities, satisfaction and tantrums, combat | AI and combat engineers |
| §12–§14 | Mutation system, synergies, morph customization screen, levels, stats, skill trees | systems designers, UI |
| §15–§17 | Restaurant tiers, building and repair, employees, offline simulation | economy and backend engineers |
| §18–§21 | Morph City districts and buildings, NPCs, quests and story, multiplayer and arena | world and narrative designers |
| §22–§23 | Economy formulas and simulations, ethical monetization | economy designers, producers |
| §24–§26 | UI/UX for all devices, art direction, animation and audio | UI, art and audio teams |
| §27–§31 | Roblox architecture, persistence, security, performance, analytics | engineers, data |
| §32–§33 | Tutorial (first 15 minutes, scripted line by line), content expansion and 12-month live-ops roadmap | onboarding, live ops |
| §34–§40 | Roadmap, QA, database appendices, checklists, open decisions, balancing assumptions, definition of done | production, QA |

**Where the databases live** (canon C1.1). Recipes are in **§6**, ingredients in **§7**, customer personalities in
**§9**, named NPCs in **§19**, and quests in **§20**. Everything else is in §36: §36.2 Recipe Quick Reference ·
§36.3 Mutation Parts · §36.4 Synergies · §36.5 Morph Combos · §36.6 Abilities · §36.7 Status Effects ·
§36.8 Employees · §36.9 Offline Incidents · §36.10 Buildings · §36.11 Events · §36.12 Tiers & Upgrades ·
§36.13 Furniture · §36.14 Animations · §36.15 Sounds · §36.16 Achievements · §36.17 Milestones. The index of
roles, districts and other small enumerations is §36.1.

**Suggested reading paths.**
- *Engineer onboarding:* §1 → §4 → §27 → §28 → §29 → the system section you own → §35.
- *Designer onboarding:* §1 → §2 → §3 → §4 → §22 → the system section you own → §39.
- *Producer:* §1 → §3 → §34 → §37 → §38 → §40.

### 1.9 Acceptance Criteria

- **AC-01-01:** Every content count in §1.2 matches the definitions in the assembled GDD (validator manifest): 150 recipes in 15 categories, 280 parts, 32 personalities, 70 abilities, 10 tiers, 12 roles, ≥ 75 archetypes, 10 districts, 22 buildings, ≥ 100 NPCs, ≥ 100 quests, 32 events.
- **AC-01-02:** No Robux product grants a stat-bearing mutation part, a currency, an employee, an offline cap or multiplier, or any random reward (audited against the §23 product list before launch).
- **AC-01-03:** Every KPI in §1.7 has a named analytics event or dashboard query in §31 before beta.
- **AC-01-04:** The core loop sentence in §1.4 appears unchanged in §2 and §3, and the §4 diagram `core-gameplay-loop` contains every node of that sentence plus the offline branch.
- **AC-01-05:** A new tester can name the three USPs and the core loop after reading only §1 (5 of 5 internal readers in the doc review).

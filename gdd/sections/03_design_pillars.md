## 3. Design Pillars

> **Owner:** A1 Vision & Onboarding. The seven pillars come from brief Part 1.2. Each pillar below states the promise
> to the player, its verbs, the systems that deliver it, how we measure it, the rules that protect it, the traps to
> avoid, and the kind of unscripted funny moment it should produce. §3.4 makes the brief's Part 26 requirements
> enforceable across every system.

### 3.1 Pillar Overview

| # | Pillar | One-line promise | Primary sections |
|---|---|---|---|
| 1 | **Cook** | Prepare increasingly ridiculous meals with tactile, readable mechanics | §5, §6, §6.18, §7 |
| 2 | **Serve** | Read and satisfy unpredictable customers | §8, §9, §10 |
| 3 | **Survive** | Defend yourself and your restaurant when things go sideways | §10, §11 |
| 4 | **Morph** | Collect, combine and upgrade body parts that change how you play | §12, §13, §36.3–§36.6 |
| 5 | **Build** | Expand, decorate, repair and automate your restaurant | §15, §16, §36.12, §36.13 |
| 6 | **Explore** | Discover Morph City's shops, quests, secrets, characters and events | §18, §19, §20 |
| 7 | **Earn** | Run a business that keeps making money, even while you're offline | §16, §17, §22 |

### 3.2 The Seven Pillars

#### 3.2.1 Pillar 1: Cook

- **Player promise:** "I can make anything, from a Basic Burger to the Mystery Morph Meal, and I get visibly better
  at it."
- **Core verbs:** CHOP, GRILL, FRY, BAKE, SAUTE, BOIL, STEAM, FREEZE, MIX, BLEND, POUR, SCOOP, ASSEMBLE, PLATE,
  CLEAN, WASH, INFUSE, FLOAT (canon C8).
- **Systems involved:** station state machines and timing (§5), the 150 recipes (§6), order modifications (§6.18),
  ingredients and supply (§7), chef mutations and utility abilities such as `ABL_061` Extra Hands and `ABL_066`
  Microwave Zap-Cook (§12, §36.6), COOK_SPD, COOK_QLT and the Chef tree (§14), station upgrades Lv1–Lv5 (canon
  C4.9, §15), chefs and prep cooks (§16).
- **Key metrics [TUNABLE]:** PERFECT component rate 35–55 % for an engaged player at their current tier; burn rate
  ≤ 8 % of heat components; median ticket completion ≤ 50 % of patience (so W = 1.0); station fires ≤ 1 per 15 min
  of active play.
- **Design rules:**
  1. Every station interaction is a single input (press, hold, or tap) plus timing. No multi-key chords, so the
     same verbs work on touch and controller (§24).
  2. Every Perfect window is ≥ 1.5 s at station Lv1 with 0 COOK_QLT (canon default `W_perfect = 2.0 s`). Windows
     only grow with stats and upgrades.
  3. Every failure state is comedic *and* recoverable. BURNED goes to the trash (cost netted, balance never
     negative). ON_FIRE gets extinguished (`ANM_030`). MUSHY is re-chopped. Nothing soft-locks a ticket.
  4. Every timer is shown as a ring with color, icon and fill. The player never has to read numbers to cook.
  5. A new recipe category introduces at most **one** new verb at a time (§6 unlock order follows canon C7.1).
  6. Mutations change *how* you cook (carry slots, parallel stations, instant freeze), not just how fast.
- **Anti-patterns:** quick-time-event spam; recipes that test memorization rather than flow; idle waits over 20 s
  with nothing parallel to do; burns that wipe a ticket's profit *and* punish further.
- **Emergent funny moment:** A Dragon Chef employee (§36.8, "occasionally burns food") sets the grill alight in
  the middle of a rush. You sprint over with a milkshake still held in your Octopus Arm's (`MUT_145`) extra carry
  slot, put out the fire, and serve the shake with the patty still at GOOD.

#### 3.2.2 Pillar 2: Serve

- **Player promise:** "I can read any weirdo in Morph City and give them exactly what they (unreasonably) want."
- **Core verbs:** greet, seat, take order, prioritize, deliver, read moods, de-escalate, apologize.
- **Systems involved:** customer state machine (§8), 32 personalities (§9), satisfaction, payment, tips and
  reputation (canon C11.3–C11.4, §10), CHARM, `ABL_064` Super Sniff, `ABL_070` Eagle Eye (§12, §14), waiters and
  cashiers (§16).
- **Key metrics [TUNABLE]:** mean satisfaction S ≥ 75 for engaged players; tips ≈ 10 % of revenue (canon target);
  storm-outs ≤ 5 % of customers; the share of customers reaching Delighted (S ≥ 90) rises with tier and loadout.
- **Design rules:**
  1. Each personality must be readable within 3 s of entering, through silhouette, signature animation and a bark.
  2. Every customer shows patience as a ring and mood as an icon plus a number, never color alone.
  3. Modifications must be achievable or explicitly flagged as joke requests with an alternative satisfaction
     mechanic (§6.18).
  4. The satisfaction formula is visible in the post-meal reaction. The bubble names the biggest positive and
     negative factor ("Perfect patty!", "Took forever…").
  5. Service style changes at TIER_03 (counter → table service, canon C6), and the tutorial for table service
     fires then.
- **Anti-patterns:** hidden preferences the player cannot discover; personalities that are just stat tweaks;
  patience so short at low tiers that new players cannot recover from one mistake.
- **Emergent funny moment:** The Sleepy Sloth-Rocket (`PER_006`) takes so long to order that the Impatient Goblin
  (`PER_005`) behind him starts an Impatient foot tap (`ANM_046`). You take the Goblin's order first, serve him, and
  he leaves Delighted before the Sloth-Rocket has finished reading the menu (`ANM_041`).

#### 3.2.3 Pillar 3: Survive

- **Player promise:** "When a customer loses it, I can handle it, and it's hilarious."
- **Core verbs:** block, dodge, swipe, wallop, grab & throw, calm down, protect, escort.
- **Systems involved:** anger ladder and escalation rolls (canon C11.5, §10), base kit `ABL_001`–`ABL_008` and
  52 mutation combat abilities (§11, §36.6), 20 status effects (§36.7), NPC combat styles (canon C11.6), Security
  Guards (§16), destructible furniture (§15).
- **Key metrics [TUNABLE]:** a brawl (anger level ≥ 5) about every 8–12 min of active play at TIER_01–03,
  6–9 min at TIER_04–07, and 5–7 min at TIER_08–10. Player KO rate ≤ 10 % of brawls. Median brawl length 20–45 s.
  Median MB cost of a brawl ≤ 5 min of that tier's net income.
- **Design rules:**
  1. Not every unhappy customer attacks. Escalation into levels 3, 4 and 5 requires a roll (canon C11.5), and
     PACIFIST personalities never attack.
  2. Every hostile attack is telegraphed (a wind-up with both a visual and an audio cue; durations in §11).
  3. A peaceful path always exists: `ABL_006` Calm Down!, Peace Offerings, Perfect food at level ≤ 2, Security
     Guards.
  4. Defeat is temporary and free: Seeing Stars for 4 s, respawn at 60 % HP with `STS_WOOZY`, no loss of parts,
     items or currency (canon C12.1).
  5. A fight always ends in comedy: Dizzy (`ANM_052`), then an Apologize bow (`ANM_053`), then an Apology Payment
     of 40 %, then Escorted out (`ANM_055`).
- **Anti-patterns:** fights that interrupt cooking more than once every few minutes at low tiers; enemies that
  are damage sponges; combat that is required to progress the story (the Baron is beaten by cooking).
- **Emergent funny moment:** A Bodybuilder Pigeon (`PER_010`) charges you. You Dodge Roll (`ABL_004`), and he
  smashes through a table, which flips the Lovebird Jellyfish Couple's (`PER_027`) dessert into the air. Now *they*
  are Annoyed, and you have three problems and one repair job.

#### 3.2.4 Pillar 4: Morph

- **Player promise:** "Every new part makes me play differently and look funnier, and there's always a rarer one."
- **Core verbs:** collect, equip, combine, upgrade, fuse, discover, save loadout, show off.
- **Systems involved:** 280 parts, 22 slots, 16 categories and 7 rarities (canon C13, §12, §36.3), synergies and
  combinations (§12.9–§12.10, §36.4–§36.5), customization screen and loadouts (§13), Mutation Mart, Mutation Lab,
  Mystery Market and Body Mods (`BLD_01`, `BLD_11`, `BLD_13`, `BLD_02`), Morph Capsules (canon C4.7), and the
  Morph Museum (`BLD_16`).
- **Key metrics [TUNABLE]:** ≥ 40 % of cumulative MB spent on mutations by the D30 median player (L1); distinct parts
  owned at D7 ≥ 15 (median); loadout swaps ≥ 1 per session for players at L12+; no single part present in > 60 % of
  top-quartile loadouts at any tier band.
- **Design rules:**
  1. Every part except FX parts has a gameplay identity: stats, an ability, a passive, carry or movement (canon
     C13.4).
  2. Synergies key off families, categories, slots and tags, never single IDs, so new parts join existing builds
     automatically (canon C13.5).
  3. Rarity communicates power *and* status, with a color plus a shape on every surface (canon C13.3).
  4. Parts are never lost: there is no durability or decay, and duplicates convert to MS or feed upgrades (canon
     C4.6–C4.7).
  5. Swapping is fast outside combat (single-part equips are instant; loadout swap is a 3 s channel with a 10 s
     cooldown) and blocked in combat (canon E4).
- **Anti-patterns:** "number-only" parts; a strictly dominant build; purchase gates so steep that a session
  passes without any morph progress; paid randomness.
- **Emergent funny moment:** A player in mismatched Chicken Leg (`MUT_180`) and Pogo Stick Leg (`MUT_191`) wobbles
  around the dining room (`ANM_008`). Mid-rush they swap to their Repair loadout and fix three cracked chairs with
  Repair Burst (`ABL_062`) from a Wrench Claw Arm (`MUT_153`) while the customers clap.

#### 3.2.5 Pillar 5: Build

- **Player promise:** "I turned a shack into a palace, and it looks and works the way I designed it."
- **Core verbs:** upgrade tier, place, decorate, repair, rebuild, hire, assign, automate.
- **Systems involved:** 10 tiers (canon C6, §15, §36.12), furniture and appliances (§36.13), damage states and
  repair (canon C6, §15), placement validation (canon E10), employees (§16), City Hall permits for TIER_04+
  (`BLD_09`).
- **Key metrics [TUNABLE]:** median tier-upgrade times within ±25 % of canon C4.4; ≥ 70 % of players place ≥ 1
  decor item by D1; repair backlog (objects Cracked or worse) cleared within 2 min of a brawl in ≥ 80 % of cases.
- **Design rules:**
  1. Each tier visibly changes the façade on Restaurant Row and the interior silhouette (§25).
  2. Atmosphere is the decor stat that matters (it feeds M in satisfaction and DecorMult in demand, canon C11.3–C11.4),
     and it is shown on every decor card.
  3. Damage is spectacular and always fixable (Destroyed → rebuild ≤ 25 % of price, canon C6).
  4. The layout can never break pathing (placement validation and the runtime poof rule, canon E10).
  5. Automation (employees) is earned, visible and characterful. Staff walk the floor and have funny traits.
- **Anti-patterns:** upgrades that are only number bumps; decor with no gameplay value; repair as a chore with no
  skill or mutation interaction.
- **Emergent funny moment:** You buy a fancy aquarium to push Atmosphere over 50. The very next customer, a
  Karenosaurus, throws a plate at it. It goes Cracked, and the cartoon fish inside look deeply offended.

#### 3.2.6 Pillar 6: Explore

- **Player promise:** "Morph City is full of weird people, shops and secrets, and leaving my restaurant is always
  worth it."
- **Core verbs:** travel, discover, talk, shop, learn, quest, deliver, compete, find secrets.
- **Systems involved:** 10 districts and 22 buildings (canon C16, §18, §36.10), 100+ NPCs (§19), 100+ quests (§20),
  32 events (§36.11), Morph Metro, Pigeon Taxi and Return Door (canon C16.1), Secret conditions (canon C13.8),
  the opt-in arena (§21).
- **Key metrics [TUNABLE]:** ≥ 60 % of D3 players have visited ≥ 4 districts; ≥ 35 % of sessions include a city trip
  of ≥ 3 min; event participation ≥ 40 % of online players when an event is live.
- **Design rules:**
  1. Every district has at least one *reason to return* (a shop rotation, a daily NPC, an event venue, a secret).
  2. Travel is never a tax: the Return Door is free with a 10 s cooldown, and Metro stations are free once
     discovered.
  3. Events pull players outside, and their rewards are worth the trip (§18).
  4. Secrets are discoverable through in-world clues, never only through external guides.
- **Anti-patterns:** empty districts with nothing to do; long walks without points of interest; secrets that are
  pure pixel hunts with no clue.
- **Emergent funny moment:** During Blackout Night (`EVT_009`) a player notices the flickering "ERROR" billboard in
  Downtown (`DST_03`), pokes it three times out of curiosity, and walks away wearing the Secret Glitch Head
  (`MUT_040`).

#### 3.2.7 Pillar 7: Earn

- **Player promise:** "My restaurant is a money machine that keeps running while I sleep, and I always have
  something great to spend on."
- **Core verbs:** earn, collect, invest, hire, manage, claim, spend.
- **Systems involved:** payments, tips and Jackpot Tips (canon C11.4), the economy and its sinks (§22), employees
  and managers (§16), the offline simulation and Welcome Back report (canon C15, §17), quests, milestones and
  achievements (§20, §36.16, §36.17).
- **Key metrics [TUNABLE]:** active net income within ±15 % of canon C4.4 per tier; offline net/h at 35–50 % of
  active for a well-staffed restaurant (never > 60 %); offline report collect rate ≥ 95 %; ≥ 1 purchase decision
  per session.
- **Design rules:**
  1. The Welcome Back report is the first thing a returning player sees when one is pending.
  2. Offline is capped, deterministic, idempotent and never pays out twice (canon C15, E11).
  3. Offline income buys mutations; it never grants XP, RT or story (Law L5, §2.9).
  4. Wages and costs are always visible before purchase or hire, and balance never goes negative (canon E8).
- **Anti-patterns:** inflation (late-game MB with nothing to buy, which L1 prevents); offline being the dominant
  income source for an active player; confusing net and gross numbers.
- **Emergent funny moment:** The offline report reads: "Ollie put a pickle on 7 milkshakes. 3 customers asked for
  more pickles. Nobody knows why." (Ollie's trait, canon C14.4.)

### 3.3 How the Pillars Reinforce Each Other

#### 3.3.1 Reinforcement matrix (row *feeds* column)

| From ↓ / To → | Cook | Serve | Survive | Morph | Build | Explore | Earn |
|---|---|---|---|---|---|---|---|
| **Cook** | — | Q and C raise satisfaction | Perfect food de-escalates at anger ≤ 2 | Some Secrets need cooking (`MUT_116` via `RCP_PST_008`) | Station use drives upgrade demand | Recipes are learned at the Academy (`BLD_06`) | Price × PayFactor × tips |
| **Serve** | Modifications demand new verbs | — | Low S raises anger | CHARM and charm-tag parts become valuable | Reputation unlocks demand worth expanding for | Critic HQ (`BLD_14`) challenges | Tips, reputation → RepMult |
| **Survive** | Protects stations from damage | Calming restores the dining room | — | Combat abilities come from parts | Damage creates repair work | Arena (`BLD_08`), boss events (`EVT_007`) | Apology Payment 40 % instead of a 0 storm-out |
| **Morph** | COOK_SPD/QLT, +carry, `ABL_066` | CHARM patience, `ABL_064`, `ABL_070` | STR/DEF, 52 combat abilities | — | REPAIR, `ABL_062`, `ABL_068` | Movement and Secret conditions | EFFICIENCY, LUCK Jackpot Tips |
| **Build** | Station Lv2–Lv5 (canon C4.9) | Seats, Atmosphere M, DecorMult | Sturdier furniture, Security Guards | Tier gates for `STN_INFUSER` → MUT dishes | — | Permits from City Hall (`BLD_09`) | Seats, demand, offline caps |
| **Explore** | Ingredients (`BLD_20`), recipes | NPC quests raise reputation | Training Gym (`BLD_05`) | Mart, Lab, Mystery Market, Secrets | Restaurant Supplies (`BLD_03`) | — | Quests, deliveries (`BLD_15`), events |
| **Earn** | Buy stations and upgrades | Buy decor | Hire guards, rebuild | Buy and upgrade parts | Buy tiers, hire staff | Taxi fares, learning fees | — |

#### 3.3.2 The explicit economic chain

The brief's chain, made precise with canon formulas. The numbers in brackets are an illustrative TIER_04 example
and are [TUNABLE].

1. **Cook well** → component grades raise Q and C (canon C8, C11.3).
2. **Satisfaction** → `S_base` rises. Moving a typical order from S = 85 to S = 91 lifts TipRate from 10 % to 18 %
   (canon C11.4). [On ≈ 3,500 MB/h of TIER_04 menu sales that is ≈ +280 MB/h in tips.]
3. **Reputation** → Stars drift toward S/20 (`Stars += 0.02 × (S/20 − Stars)`). Holding S at 91 instead of 85
   converges to 4.55 ★ instead of 4.25 ★, so RepMult rises from 1.5625 to 1.6375 (+4.8 % demand).
4. **Demand and pay** → more customers per hour (`BaseDemand × RepMult × DecorMult × EventMult`, canon C6) →
   more MB.
5. **Spend on Morph** (≈ 50 % of income, canon C4.4) → stat budgets (canon C13.4). [A Rare major-slot chef part has a
   budget of 11 points. +8 COOK_SPD alone makes stations ×1/(1 + 0.048) ≈ 4.6 % faster.]
6. **Become more powerful** → faster tickets keep W at 1.0, PERFECT windows widen, CHARM stretches patience,
   STR/DEF shorten brawls, and REPAIR shortens downtime.
7. **Spend on Build** (≈ 50 %) → tiers add seats, demand, menu slots and employee capacity (canon C6).
8. **Employees** → online throughput and **offline income** (canon C15), which returns as MB and MS with no
   active time.
9. **Discover rarer morphs** → the higher income opens Rare/Epic purchases, Lab fusion and Mystery Market
   rotations (canon C4.5), and the loop repeats at a higher tier.

### 3.4 Cross-Cutting Design Requirements (brief Part 26)

These rules apply to **every** system section. Rule codes (e.g. R-HUM-1) are cited in §35 test plans and §40.

#### 3.4.1 Humor (26.1)

- **R-HUM-1:** Every failure state has comedic feedback: an animation or VFX plus a bark or sound. No silent
  failure (burned → soot puff and a sizzle groan; KO → Seeing Stars `ANM_062`).
- **R-HUM-2:** At least half of the humor must be *systemic*, emerging from rules (wrong-target throws, mismatched
  gaits, incident rolls, personality clashes) rather than one-off scripted gags. Content review tags every joke as
  systemic or scripted.
- **R-HUM-3:** Repetition control: the same speaker never repeats the same bark within 60 s [TUNABLE], and an
  offline report never shows the same incident line twice.
- **R-HUM-4:** Every personality (§9), part (§36.3), incident (§36.9) and event (§36.11) has at least one flavor line
  or visual gag in its database row.
- **QA verification:** a playtest "laugh log" in which testers mark funny moments, target ≥ 3 per 10-minute session
  [TUNABLE]; a telemetry query for bark repeats within 60 s, which must be 0; a database lint for empty flavor
  fields.

#### 3.4.2 Readability (26.2)

- **R-READ-1:** The current ticket, customer patience rings, and (while In Combat) HP and guard meters are never
  covered by VFX, popups or toasts (§24 layering).
- **R-READ-2:** Every timer and state is a shape plus a color plus an icon. Numbers are optional extras.
- **R-READ-3:** Combat and destruction VFX cover no more than 15 % of the screen for more than 0.5 s [TUNABLE].
  Customer anger icons draw above VFX.
- **R-READ-4:** Every interactable shows its prompt within its interaction range (7 studs for stations, 10 for
  customers, canon C3).
- **R-READ-5:** A customer's anger level can be read at 30 studs through icon, posture and numeral.
- **QA verification:** an automated screenshot capture at peak-chaos test scenes (6 customers, 1 fire, 1 brawl)
  checked against the HUD-occlusion rules; the "2-second next action" playtest at ≥ 90 % (Law L7).

#### 3.4.3 Accessibility (26.3)

- **R-ACC-1:** Every action can be performed on keyboard and mouse, controller, and touch (bindings in §24). Touch
  never requires more than the thumbstick plus one button at a time.
- **R-ACC-2:** Reduced Motion (seeded from `GuiService.ReducedMotionEnabled`) removes camera shake, screen splats,
  rapid flashes and pulsing tweens. Reduced VFX halves particle counts.
- **R-ACC-3:** Separate volume sliders for Master, Music, SFX, Voice barks and UI. Every bark is subtitled.
- **R-ACC-4:** No status is color-only: rarity shapes (canon C13.3), satisfaction faces plus numbers, anger numerals.
- **R-ACC-5:** Auto-Rhythm chopping (canon C8), plus hold-or-toggle options for Block and Sprint.
- **R-ACC-6:** No flashing faster than 3 Hz anywhere, events included.
- **R-ACC-7:** Every tutorial line can be replayed from the Quest Journal.
- **QA verification:** a device matrix (phone, tablet, PC, console controller) completing the full tutorial with
  each input; colorblind-filter screenshots (protanopia, deuteranopia, tritanopia); a frame-by-frame flash analysis
  of all VFX at 60 fps.

#### 3.4.4 Fairness (26.4)

- **R-FAIR-1:** No permanent loss from failure (canon C12.1, C6, E8).
- **R-FAIR-2:** The median MB cost of one brawl (repairs plus lost payments) is ≤ 5 minutes of that tier's net
  income [TUNABLE].
- **R-FAIR-3:** Every order generated is completable with the restaurant's current stations, stock and menu (SOLD
  OUT logic, canon C9 and E9).
- **R-FAIR-4:** Offline incidents are bounded (negative effects ≤ 10 %, positive ≤ 15 % of revenue, canon C15).
- **R-FAIR-5:** Randomness that gates rewards has a disclosed rate and a pity counter where it can repeat (capsules,
  canon C4.7).
- **QA verification:** an order-generation fuzz test (10,000 orders per tier against random legal kitchens, 0
  impossible orders); brawl-cost telemetry; offline simulation property tests (§17).

#### 3.4.5 Progression (26.5)

- **R-PROG-1:** Every session of ≥ 5 minutes advances at least one visible bar (Law L8).
- **R-PROG-2:** The HUD always shows the next objective (§24). After the tutorial this is the story or daily quest,
  or, failing those, "Save for: <next tier / wishlist part>".
- **R-PROG-3:** No dead levels: every level grants 2 stat points and (from L2) 1 skill point (canon C5, C18), plus the
  unlock table in §14.
- **R-PROG-4:** The median time to the next tier never exceeds 1.5 × the canon C4.4 interval [TUNABLE].
- **QA verification:** a bot-driven economy simulation per tier (§22); progression telemetry dashboards (§31).

#### 3.4.6 Replayability (26.6)

- **R-REP-1:** The same personality is never drawn more than 2 times in a row for one restaurant [TUNABLE]
  (§8 spawner).
- **R-REP-2:** Daily quests, Mystery Market rotations and city events rotate on fixed UTC cadences (canon C3) and
  avoid repeating the same event within 3 days [TUNABLE] (§18).
- **R-REP-3:** At least 3 viable loadout archetypes (Chef, Fighter, Repair) exist per tier band, and the meta-health
  rule from §3.2.4 applies.
- **R-REP-4:** Offline incidents within one report are drawn without replacement while eligible types remain.
- **QA verification:** a loadout diversity telemetry query; spawner unit tests for streak limits.

#### 3.4.7 Social appeal (26.7)

- **R-SOC-1:** Other players' morphs render at full fidelity within 60 studs and as a LOD impostor beyond (canon
  C13.7). Every part is visible; there are no hidden slots except FX at low graphics settings.
- **R-SOC-2:** Any player can *inspect* another player's morph (part names, rarities, morph name) from the city or
  in a restaurant, and a Showcase Stage (`BLD_22`) exists for posing.
- **R-SOC-3:** Co-op guests are rewarded and can never grief (canon E12, §21).
- **R-SOC-4:** Photo mode (hides the HUD, pose emotes) is available from L5 [TUNABLE].
- **QA verification:** a multiplayer test with 8 clients in the city at the morph budget (§30); a guest permission
  test suite (§35).

#### 3.4.8 Offline engagement (26.8)

- **R-OFF-1:** Every player can earn offline from session 1 (`EMP_001` is hired in `QST_TUT_012`, §32).
- **R-OFF-2:** On login, a pending Welcome Back report is shown before any other popup (daily reward, news).
- **R-OFF-3:** Every report contains at least one funny incident or flavor line and at least one actionable
  suggestion (an upgrade, hire, repair or recipe).
- **R-OFF-4:** The offline cap is communicated *before* the player leaves: the Restaurant Hub shows "Your staff
  works up to N h", and the hire screen previews it.
- **R-OFF-5:** Offline grants MB, MS (discoveries), rare ingredient crates and at most 1 capsule per day, and never
  XP or RT (canon C4.1, C15).
- **QA verification:** collect-rate telemetry; report values compared against §17 fixture cases; a login popup
  ordering test.

### 3.5 Acceptance Criteria

- **AC-03-01:** Each of the 7 pillars has ≥ 3 key metrics with a defined analytics query in §31 before beta.
- **AC-03-02:** Every system section (§5–§31) cites the R-codes from §3.4 that apply to it, or explicitly declares none (doc review).
- **AC-03-03:** The reinforcement matrix has no empty off-diagonal cell, and every cell's claim is backed by a rule in the cited section (doc review).
- **AC-03-04:** The economic chain in §3.3.2 reproduces from canon formulas: the S 85 → 91 tip delta (10 % → 18 %) and the RepMult values 1.5625 → 1.6375 are recomputed by the §22 economy spreadsheet within ±0.001.
- **AC-03-05:** In a 10-minute playtest at any tier, ≥ 1 emergent moment of the type listed for Survive or Serve occurs in ≥ 70 % of sessions [TUNABLE].

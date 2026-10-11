## 9. Customer Personalities

> **Owner:** A5 Customers. This section is the **personality database** (§C1.1): the table in §9.3 defines
> `PER_001`–`PER_032` (names fixed by §C11.1); §9.4 specifies every field for each. Spawning, bodies and the state
> machine are in §8; the satisfaction, anger and chaos math these parameters feed is in §10.

### 9.1 Purpose

A personality is a **behavior package** worn by a procedurally assembled body. The body (§8.3) makes every
customer look new; the personality makes every customer *act* recognisably, so players learn to read the room:
"a Karenosaurus just walked in — triple-check her modifications", "that's a Speedrunner Squirrel — drop everything
for the fries". Thirty-two personalities give each tier band fresh faces, and every one has at least one special
mechanic that creates a funny situation on its own, without a script.

### 9.2 Rules & Mechanics — How Personalities Layer on Bodies

#### 9.2.1 Layering

1. **Body first, personality on top.** §8.3 rolls the body from `CustomerSeed`, then **signature parts** listed in
   §9.4 overwrite their slots (e.g. PER_010 always has `MUT_004` Pigeon Head, per §C11.1). "Optional signature"
   parts are rolled with the stated chance. Everything else stays procedural, so two Karenosauruses never match.
2. **Behavior parameters** (§9.3) plug into the formulas of §8 and §10. Nothing in a personality bypasses those
   formulas; personalities only change inputs, thresholds and which special hooks fire.
3. **Animation set.** Each personality has a locomotion/idle variant set built on the core library (§C21); new
   variants are listed in words and receive IDs from A16 in §36.14.
4. **Dialogue.** Bubble lines are chosen client-side from the personality's pools keyed by emote code (`ORDER`,
   `DELIGHT`, `HAPPY`, `MEH`, `UNHAPPY`, `FURIOUS`, `HOSTILE`, `CALM`, `APOLOGY`, `LEAVE`). Launch requires ≥ 3 lines
   per pool per personality; §9.4 lists the canonical ordering / delighted / furious examples. Lines are
   localization keys (`PER_001.ORDER.1`) in `LocalizationService` tables and pass the kid-safety checklist (§9.11).

#### 9.2.2 Parameter semantics

| Parameter | Meaning | Used in |
|---|---|---|
| Patience× | `PersonalityPatienceMult` in §C11.2 and the ordering window | §8.9 |
| P_mult / P_offset | personality terms of §C11.3. The effective offset adds preference adjustments: +5 preferred recipe, +3 preferred category, −8 disliked recipe or category, −5 forced order (§8.8), plus the dynamic hooks named in §9.4. Effective P_offset is clamped to [−20, +15]. | §10.3 |
| Thresholds D/H/M/U | personality bands for Delighted / Happy / Meh / Unhappy (below U = Furious). They drive the reaction emote, the evaluation anger delta and Regular loyalty. **Pay, tips and reputation always use raw S** (§C11.4). | §10.2, §10.6 |
| AngerP | base `AngerProbability` of the escalation roll at levels 3/4/5 | §10.7 |
| Sens | sensitivity: multiplies every anger **gain** (never decay) | §10.6 |
| Style / Huff | NPC combat style (§C11.6) and Huff Points (40–300, inside the §11.5.2 style bands) | §10.7, §11 |
| DEF / Dmg× | `PersonalityDEF` (0–40, added to the tier DEF term) and `PersonalityDamageMult` (multiplies NPC damage) | §11.5.1 |
| Items / γ | item range for §8.2.6; price bias γ for menu weighting (§8.8) | §8 |
| ModAffinity | §6.18.3 affinity group with its Aff / JokeAff / HidAff multipliers ("Aff / Joke / Hidden" in §9.4) plus the favored modification categories, derived from §6.18's "Favored by" column (favored mods get ×3 pick weight) | §6.18, §8.8 |
| Tip× | `PersonalityTipMult` in §C11.4 | §10.5 |
| Timing | WalkMult · MenuMult · InspectMult · EatMult (§9.4) | §8 |
| Unlock / Base wt | first tier it may spawn; spawn weight in band C (all bands in §8.2.5) | §8.2.5 |

#### 9.2.3 Combat ability selection

Per §C11.6 a customer may use the **active ability of one of its own visible parts**. Selection and use follow
§11.8.3 (owned by A6): each customer has at most one **Signature Move**, chosen among its visible parts whose §36.6
"NPC use" entry lists the customer's style; it is used only at anger level 5 or in a scuffle, never by `PACIFIST`
customers, and utilities are never used (the only exception is the §36.6 flee entry of `ABL_063`). NPC numbers are
the §36.6 "NPC use" values. **A5 extension:** when a personality's signature part grants an eligible ability, that
ability is chosen before §11.8.3's slot priority, so recurring personalities keep a recognisable move. The §9.4
"Abilities" lists show, in priority order, the eligible options that personality's signature and commonly rolled
parts can provide; a customer whose body carries none of them fights with its style's basic attacks only (§11.8.2).

#### 9.2.4 Spawn bands

Personalities unlock by restaurant tier and stay eligible forever after; weights shift by band (§8.2.5). Band A
(`TIER_01`–`TIER_02`) is deliberately gentle — Newts, Grandmas and Sloths dominate — and every `INSTIGATOR` /
`BRAWLER` arrives no earlier than the tier at which the player has learned to fight (QST_TUT_007).

### 9.3 Personality Summary Table

Thresholds are Delighted / Happy / Meh / Unhappy lower bounds (canon default 90 / 70 / 50 / 30). DEF = `PersonalityDEF`
(0–40) and Dmg× = `PersonalityDamageMult` as consumed by the §11.5.1 damage formula ("—" = never attacks). Huff
values sit inside the §11.5.2 recommended band of each style, except the PER_016 minis (three small bodies, 150
total). PER_032 copies every value from the personality it reveals (pre-reveal values in brackets).

| ID | Name | Patience× | P_mult | P_offset | Thresholds D/H/M/U | AngerP | Sens | Style | Huff | DEF | Dmg× | Items | Tip× | Unlock | Base wt |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `PER_001` | The Karenosaurus | 0.85 | 0.85 | −5 | 95/80/60/40 | 0.45 | 1.3 | `INSTIGATOR` | 100 | 10 | 0.8 | 1–2 | 0.6 | `TIER_01` | 6 |
| `PER_002` | The Hungry Hippo-Spider | 1.20 | 1.00 | +5 | 90/70/50/30 | 0.30 | 0.8 | `TANK` | 260 | 30 | 1.0 | 3–5 | 0.9 | `TIER_02` | 5 |
| `PER_003` | The Polite Demon | 1.15 | 1.05 | +5 | 88/65/45/25 | 0.12 (0.90 provoked) | 1.0 (1.8 provoked) | `BRAWLER` | 180 | 15 | 1.2 | 1–2 | 1.3 | `TIER_01` | 6 |
| `PER_004` | The Food Critic | 1.00 | 0.90 | 0 | 95/80/60/40 | 0.05 | 0.6 | `PACIFIST` | 60 | 0 | — | 2 | 1.0 | `TIER_03` | 2 |
| `PER_005` | The Impatient Goblin | 0.55 | 1.00 | 0 | 90/70/50/30 | 0.40 | 1.2 | `TRICKSTER` | 70 | 5 | 0.8 | 1 | 0.8 | `TIER_01` | 7 |
| `PER_006` | The Sleepy Sloth-Rocket | 1.80 | 1.05 | +5 | 85/65/45/25 | 0.15 | 0.7 | `CHARGER` | 120 | 20 | 1.1 | 1–2 | 1.1 | `TIER_01` | 6 |
| `PER_007` | The Chaos Gremlin | 0.90 | 1.00 | 0 | 90/70/50/30 | 0.50 | 1.2 | `TRICKSTER` | 80 | 5 | 0.9 | 1–2 | 1.0 | `TIER_02` | 5 |
| `PER_008` | The Rich Mutant | 0.90 | 0.90 | 0 | 96/85/65/45 | 0.20 | 1.0 | `PACIFIST` | 80 | 10 | — | 1–3 | 2.5 | `TIER_03` | 3 |
| `PER_009` | The Influencer | 0.80 | 1.00 | 0 | 92/75/55/35 | 0.30 | 1.1 | `INSTIGATOR` | 75 | 5 | 0.7 | 1–2 | 1.2 | `TIER_02` | 3 |
| `PER_010` | The Bodybuilder Pigeon | 0.90 | 1.00 | 0 | 90/70/50/30 | 0.55 | 1.6 | `BRAWLER` | 180 | 30 | 1.25 | 1–3 | 1.0 | `TIER_02` | 5 |
| `PER_011` | The Conspiracy Moth | 1.00 | 0.95 | 0 | 90/70/50/30 | 0.30 | 1.0 | `TRICKSTER` | 70 | 5 | 0.8 | 1–2 | 0.9 | `TIER_03` | 4 |
| `PER_012` | The Nervous Newt | 1.10 | 1.10 | 0 | 85/65/45/25 | 0.05 | 1.5 | `PACIFIST` | 40 | 0 | — | 1 | 1.2 | `TIER_01` | 5 |
| `PER_013` | The Grandma Golem | 1.40 | 1.05 | +5 | 85/60/40/20 | 0.10 | 0.5 | `TANK` | 300 | 40 | 0.9 | 1–2 | 1.5 | `TIER_01` | 5 |
| `PER_014` | The Picky Platypus | 1.00 | 0.90 | −5 | 92/75/55/35 | 0.35 | 1.1 | `THROWER` | 90 | 10 | 1.0 | 1–2 | 1.0 | `TIER_01` | 6 |
| `PER_015` | The Robot Accountant | 1.00 | 1.00 | 0 | 90/70/50/30 | 0.25 | 0.9 | `TANK` | 200 | 35 | 1.0 | 1–2 | 1.0 | `TIER_02` | 4 |
| `PER_016` | The Party Pack | 0.90 | 1.00 | 0 | 90/70/50/30 | 0.35 | 1.2 | `BRAWLER` | 50 ×3 | 0 | 0.5 | 1 each ×3 | 1.1 | `TIER_03` | 3 |
| `PER_017` | The Pirate Crab | 1.00 | 1.00 | 0 | 90/70/50/30 | 0.40 | 1.1 | `THROWER` | 120 | 15 | 1.0 | 1–2 | 1.0 | `TIER_02` | 4 |
| `PER_018` | The Drama Llama | 0.90 | 0.95 | 0 | 92/72/52/32 | 0.35 | 1.4 | `INSTIGATOR` | 100 | 10 | 0.8 | 1–2 | 1.0 | `TIER_02` | 4 |
| `PER_019` | The Mime Mantis | 1.10 | 1.00 | 0 | 90/70/50/30 | 0.25 | 1.0 | `TRICKSTER` | 100 | 10 | 0.9 | 1–2 | 1.2 | `TIER_03` | 3 |
| `PER_020` | The Toddler Titan | 0.70 | 1.00 | 0 | 85/65/45/25 | 0.45 | 1.3 | `THROWER` | 120 | 20 | 0.9 | 1–2 | 0.8 | `TIER_02` | 4 |
| `PER_021` | The Health Nut Hamster | 1.00 | 0.95 | 0 | 90/70/50/30 | 0.25 | 1.0 | `CHARGER` | 110 | 15 | 1.0 | 1–2 | 1.1 | `TIER_02` | 4 |
| `PER_022` | The Spicy Salamander | 1.00 | 1.00 | 0 | 90/70/50/30 | 0.35 | 1.0 | `THROWER` | 120 | 15 | 1.1 | 1–2 | 1.0 | `TIER_03` | 4 |
| `PER_023` | The Frozen Yeti-Fish | 1.10 | 1.00 | 0 | 90/70/50/30 | 0.25 | 0.9 | `CHARGER` | 170 | 25 | 1.0 | 1–2 | 1.0 | `TIER_03` | 4 |
| `PER_024` | The Time-Traveler Tortoise | 1.50 | 1.00 | +5 | 85/65/45/25 | 0.10 | 0.6 | `PACIFIST` | 80 | 40 | — | 1–2 | 1.3 | `TIER_04` | 2 |
| `PER_025` | The Undercover Inspector | 1.00 | 1.00 | 0 | 90/70/50/30 | 0.00 | 0.5 | `PACIFIST` | 80 | 10 | — | 1 | 1.0 | `TIER_03` | 2 |
| `PER_026` | The Speedrunner Squirrel | 0.60 | 1.00 | 0 | 90/70/50/30 | 0.40 | 1.2 | `CHARGER` | 110 | 5 | 0.9 | 1 | 1.0 | `TIER_04` | 3 |
| `PER_027` | The Lovebird Jellyfish Couple | 1.30 | 1.05 | +5 | 88/68/48/28 | 0.10 | 1.2 | `PACIFIST` | 70 ×2 | 0 | — | 1–2 each ×2 | 1.3 | `TIER_03` | 3 |
| `PER_028` | The Haunted Toaster | 1.00 | 1.00 | 0 | 90/70/50/30 | 0.35 | 1.0 | `THROWER` | 100 | 15 | 1.0 | 1–2 | 1.0 | `TIER_04` | 3 |
| `PER_029` | The Alien Tourist | 1.20 | 1.05 | +5 | 85/65/45/25 | 0.20 | 1.0 | `TRICKSTER` | 100 | 15 | 0.9 | 1–3 | 1.2 | `TIER_05` | 3 |
| `PER_030` | The Retired Wrestler Walrus | 1.00 | 1.00 | 0 | 90/70/50/30 | 0.40 | 1.3 | `BRAWLER` | 180 | 35 | 1.2 | 1–3 | 1.1 | `TIER_05` | 3 |
| `PER_031` | The Birthday Beast | 1.00 | 1.10 | +5 | 92/72/52/32 | 0.40 | 1.5 | `THROWER` | 120 | 10 | 1.0 | 2 | 1.5 | `TIER_03` | 3 |
| `PER_032` | The Mystery Mutant | [1.00] | [1.00] | [0] | [90/70/50/30] | as revealed | as revealed | as revealed | as revealed | as revealed | as revealed | as revealed [1–2] | revealed × 1.2 | `TIER_06` | 2 |

**Style distribution:** `PACIFIST` 6 · `THROWER` 6 · `TRICKSTER` 5 · `BRAWLER` 4 · `CHARGER` 4 · `TANK` 3 ·
`INSTIGATOR` 3 · inherited 1 = 32. Weighted by band-C spawn weights (party members counted), ≈ 15 % of arrivals can never attack
(`PACIFIST`; ≈ 20 % at `TIER_01`), which keeps "not every unhappy customer attacks" true even before escalation rolls.

### 9.4 Personality Detail Blocks

Each block lists every brief field. "Ref. spend" uses the `TIER_03` reference average ticket of ≈ 20 MB
(1.4 items × ≈ 14 MB); actual prices come from §6. Ability lists are in priority order (§9.2.3).

#### PER_001 — The Karenosaurus
*Complains about almost everything, with tiny arms and an enormous voice.*
- **Patience:** ×0.85 (ordering window 25.5 s). Timing: walk ×1.0 · menu ×1.2 · inspect ×1.5 · eat ×1.0.
- **Preferred foods:** BRG, SAL; `RCP_BRG_002` Cheeseburger, `RCP_SAL_002` Caesar Salad With Tiny Crown, `RCP_PIZ_001` Cheese Pizza, `RCP_DRK_002` Lemonade.
- **Disliked foods:** `RCP_PIZ_004` Pineapple Pizza (Controversial), `RCP_BRG_013` Upside-Down Burger.
- **Satisfaction thresholds:** 95 / 80 / 60 / 40; P_mult 0.85, P_offset −5.
- **Anger probability:** 0.45; sensitivity 1.3.
- **Combat behavior:** `INSTIGATOR`, Huff 100, DEF 10, Dmg ×0.8. She may Yell (§10.6) from level 2, one level early. Abilities: `ABL_023` Bat Screech (`MUT_089`), `ABL_029` Peacock Dazzle (`MUT_219`), `ABL_047` Mind Buzz (`MUT_033`). Her thrown food falls 30 % short (tiny arms).
- **Mod affinity:** Very picky (Aff ×2.0 · Joke ×0.5 · Hidden ×1.0) · favors OMIT, SHAPE, SEQUENCE.
- **Spending range:** 1–2 items, γ 0 → ref. spend 10–30 MB. **Tip behavior:** ×0.6.
- **Unique animations:** "Manager Summon" megaphone-hands stomp (variant of `ANM_050`); clipboard tap with tiny arms; holding the plate up to the light, appalled.
- **Dialogue:** Ordering — "One cheeseburger. The cheese must be room temperature. Not warm. Not cool. *Room.*" · Delighted — "Hmph. Acceptable. I'll only write you a *four*-paragraph review." · Furious — "I want to speak to the MANAGER! ...You ARE the manager? Then your manager's MANAGER!"
- **Special interactions:** *Manager!* — at level 2 the HUD pings "A customer demands the manager!"; if a player lands `ABL_006` on her within 20 s the calm amount is doubled, otherwise +10 anger. *Take it back!* — any item with A < 1 or Q < 0.80 is handed back; a remake served within 60 s replaces that item's S (the remake keeps the original W).
- **Tutorial variant (QST_TUT_006 → QST_TUT_007):** scripted by §32 and bound to its values (§32.3): fixed tutorial look (signature parts plus cosmetic sunglasses and handbag props), orders `RCP_BRG_002`, escalation rolls bypassed and anger driven through the scripted beats 32 → 48 → 63 → 78 (complain → soggy-pickle throw → table flip to Broken → fight). Fight values: Huff 48, 4 damage per hit, 1.0 s wind-up (1.5 s after two missed blocks), ≥ 3.0 s between attacks; the player has Plot Armor (≥ 1 HP). Calm Down! is refused at level 5 ("She's past talking"); at 0 Huff she goes Dizzy, apologizes and pays the Apology Payment (40 % of 10 MB = 4 MB). The variant is exempt from new-player protection (§10.11) and cannot storm out. Normal §9 values apply to every later Karenosaurus.
- **Signature look:** `MUT_032` T-Rex Head, `MUT_161` Tiny T-Rex Arm ×2. **Tier band:** `TIER_01`+ (A 3 · B–E 6).

#### PER_002 — The Hungry Hippo-Spider
*Eight legs, one bottomless stomach.*
- **Patience:** ×1.2 (the formula already adds +20 s per extra item). Timing: walk ×0.8 · menu ×0.8 · inspect ×0.6 · eat ×0.5 per item.
- **Preferred foods:** BRG, PIZ, FRI; `RCP_BRG_015` The Unreasonably Large Burger, `RCP_PIZ_005` Meat Mountain Pizza, `RCP_FRI_005` Fried Everything Basket, `RCP_TAC_005` Nacho Avalanche, `RCP_SOP_010` Bottomless Soup, `RCP_FRI_001` French Fries.
- **Disliked foods:** `RCP_SAL_004` Salad With No Lettuce, `RCP_BRG_014` Invisible Burger ("Where's the FOOD?").
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset +5.
- **Anger probability:** 0.30; sensitivity 0.8.
- **Combat behavior:** `TANK`, Huff 260, DEF 30, Dmg ×1.0. Abilities: `ABL_021` Ground Pound (`MUT_148`), `ABL_010` Bear Slam (`MUT_140`), `ABL_025` Puff Up (`MUT_129`). (Its signature Vacuum Mouth is not `TANK`-eligible for `ABL_035`; the snack trick below is a personality hook.)
- **Mod affinity:** Low-fuss (Aff ×0.6 · Joke ×0.5 · Hidden ×0.5) · favors EXTRA, COUNT.
- **Spending range:** 3–5 items, γ +0.5, plus "Seconds!" → ref. spend 60–120 MB. **Tip behavior:** ×0.9.
- **Unique animations:** four-handed eating blur (`ANM_043` at 2× speed); belly-pat; spider-leg tap-dance of joy.
- **Dialogue:** Ordering — "One of everything. Then the same again, but louder." · Delighted — "Eight legs, one stomach, ZERO regrets!" · Furious — "You call that a PORTION? I've had bigger crumbs!"
- **Special interactions:** *Seconds!* — after the last item, 30 % chance to order 1–2 more items as a new ticket with fresh patience. *Free snack* (personality hook) — thrown food aimed at it, or passing within 2 studs, is slurped out of the air and eaten: no hit, anger −5 instead of +25 (the projectile is consumed and cannot continue).
- **Signature look:** `MUT_066` Vacuum Mouth, `MUT_185` Spider Leg Cluster ×2, `MUT_120` Cow Body. **Tier band:** `TIER_02`+ (A 4 · B–E 5).

#### PER_003 — The Polite Demon
*Courteous, considerate, apologetic — until provoked.*
- **Patience:** ×1.15. Timing: walk ×1.0 · menu ×1.0 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** spicy and elegant; `RCP_BRG_007` Volcano Burger, `RCP_PST_010` Spicy Lava Lasagna, `RCP_DRK_007` Angry Coffee, `RCP_DES_007` Pie in the Face (Edible).
- **Disliked foods:** `RCP_DES_012` Cloud Cotton Candy, `RCP_DRK_014` Cloud Juice ("A little too heavenly for me, thank you").
- **Satisfaction thresholds:** 88 / 65 / 45 / 25; P_mult 1.05, P_offset +5.
- **Anger probability:** 0.12; **provoked** → 0.90 and sensitivity 1.8 for the rest of the visit.
- **Combat behavior:** `BRAWLER`, Huff 180, DEF 15, Dmg ×1.2. Abilities: `ABL_043` Lava Slam (`MUT_163`, signature), `ABL_031` Rocket Punch (`MUT_154`), `ABL_042` Thunder Clap (`MUT_105`).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors OMIT, DONENESS, MOOD.
- **Spending range:** 1–2 items → ref. spend 14–30 MB. **Tip behavior:** ×1.3 (always rounds up).
- **Unique animations:** deep courtly bow on arrival; napkin tucked into collar; at level 4 he slowly rolls up the sleeve over the Lava Fist (the "aggressive form" reveal, horns glow).
- **Dialogue:** Ordering — "Good evening! If it's no trouble at all, might I have the Volcano Burger? Only if convenient!" · Delighted — "Exquisite. My compliments to the chef, the sous-chef, and the very kind grill." · Furious — "I asked SO nicely. Excuse me while I roll up my sleeve. I do apologise in advance."
- **Special interactions:** *Provoked* flag — set when hit by thrown food, hit by any player attack, or served a wrong dish twice. Unprovoked, he is the calmest customer in the game; provoked, he skips sulking. *Gentleman's apology* — when calmed by combat he pays 10 % extra on top of the Apology Payment ("For the table, with my sincerest regrets"). **Tutorial:** the step-5 customer and the soda-splashed bystander of QST_TUT_007, calmed with Calm Down! (§32).
- **Signature look:** `MUT_108` Demon Horns, `MUT_047` Mustache of Destiny, `MUT_163` Lava Fist Arm (right arm only). **Tier band:** `TIER_01`+ (A–C 6 · D–E 5).

#### PER_004 — The Food Critic
*Evaluates every aspect. Out loud. In a notebook.*
- **Patience:** ×1.0. Timing: walk ×1.0 · menu ×1.5 · inspect ×2.0 (magnifying glass, 3 s) · eat ×1.2.
- **Preferred foods:** whatever on the menu has the highest difficulty (+1.8 weight per difficulty point above 2); `RCP_PST_004` Lasagna Tower, `RCP_SEA_003` Sushi Roll Block, `RCP_BRK_010` Dragon Egg Benedict, `RCP_DES_014` Galaxy Cheesecake, any LEG recipe.
- **Disliked foods:** `RCP_FRI_001` French Fries, `RCP_DRK_001` Fizzy Soda ("Pedestrian").
- **Satisfaction thresholds:** 95 / 80 / 60 / 40; P_mult 0.90, P_offset 0.
- **Anger probability:** 0.05; sensitivity 0.6.
- **Combat behavior:** `PACIFIST`, Huff 60, DEF 0. Never attacks; when upset she writes furiously (sulk) or leaves.
- **Mod affinity:** Very picky (Aff ×2.0 · Joke ×0.5 · Hidden ×1.0) · favors DONENESS, COUNT, PRESENT.
- **Spending range:** exactly 2 items (main + drink or dessert) → ref. spend 25–40 MB. **Tip behavior:** ×1.0.
- **Unique animations:** notebook scribble; pinky-raised tasting; dramatic pen-click verdict.
- **Dialogue:** Ordering — "Bring me your most ambitious dish. And a pen that hasn't been chewed." · Delighted — "Five stars. Six, if I were allowed. I am not allowed." · Furious — "This dish has the emotional depth of a puddle. A shallow one."
- **Special interactions:** *The Review.* On leaving she scores 5 categories, each 0–5 ★ in half steps: Taste = 5·Q, Technique = 5·C, Accuracy = 5·A, Speed = 5·W (price-weighted over items), Ambience = 5·(K + M)/200. If the average ≥ 4.5 **and** S ≥ 90 she awards a **Critic's Star**: +0.05 ★ reputation applied directly, a newspaper review card, and +1 to the profile's `criticStars` counter (read by §20's critic quest line). Average < 2.0 → −0.05 ★. During `EVT_008` she visits up to twice per restaurant on the §36.11 schedule and her verdict is also converted to Forks (`BLD_14` formula). Worked example in §10.4.
- **Signature look:** `MUT_016` Owl Head, `MUT_110` Giraffe Neck (looking down her nose). **Tier band:** `TIER_03`+ (B–C 2 · D–E 3).

#### PER_005 — The Impatient Goblin
*Wanted it five minutes ago.*
- **Patience:** ×0.55 (ordering window 16.5 s). Timing: walk ×1.3 · menu ×0.5 · inspect ×0.5 · eat ×0.6.
- **Preferred foods:** fastest prep; `RCP_FRI_001` French Fries, `RCP_SAN_003` Hot Dog Classic, `RCP_TAC_001` Basic Taco, `RCP_DRK_001` Fizzy Soda, `RCP_DES_001` Chocolate Chip Cookie.
- **Disliked foods:** `RCP_SOP_010` Bottomless Soup, `RCP_PST_004` Lasagna Tower, `RCP_PIZ_013` Pizza Inside Another Pizza.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0.
- **Anger probability:** 0.40; sensitivity 1.2.
- **Combat behavior:** `TRICKSTER`, Huff 70, DEF 5, Dmg ×0.8: plate theft and hit-and-run per §11.8.2. Abilities: `ABL_016` Tongue Yank (`MUT_061`), `ABL_048` Slime Trail (`MUT_256`), `ABL_024` Skunk Cloud (`MUT_220`).
- **Mod affinity:** Low-fuss (Aff ×0.6 · Joke ×0.5 · Hidden ×0.5) · favors MOOD, TEMP.
- **Spending range:** 1 item → ref. spend 8–16 MB. **Tip behavior:** ×0.8, but ×2 if the item lands within 25 % of patience ("FAST! GOOD!").
- **Unique animations:** constant `ANM_046` foot tap from the moment he sits; wrist-tapping (no watch); vibrating with impatience.
- **Dialogue:** Ordering — "Burger. Fast. Faster than that. Why are you still listening? GO." · Delighted — "FAST! GOOD! MORE FAST NEXT TIME!" · Furious — "I've been waiting since I was BORN!"
- **Special interactions:** *Line Cutter* — in the outside queue he jumps to the front (impossible once a `FRN_433` Bouncer Rope lines the queue, §15); everyone he passes gains +5 anger on entry. *Speed reader* — orders without a menu phase if a ticket card is free.
- **Signature look:** `MUT_017` Lizard Head, `MUT_090` Fox Ears, `MUT_204` Roller Skates. **Tier band:** `TIER_01`+ (A 4 · B–E 7).

#### PER_006 — The Sleepy Sloth-Rocket
*Takes forever to order; leaves at rocket speed.*
- **Patience:** ×1.8. Timing: walk ×0.6 · menu ×3.0 (18 s) · inspect ×1.2 · eat ×1.8.
- **Preferred foods:** breakfast and caffeine; `RCP_BRK_001` Pancake Stack, `RCP_BRK_003` Waffles, `RCP_DRK_007` Angry Coffee, `RCP_DRK_015` Liquid Lightning, `RCP_SOP_001` Tomato Soup.
- **Disliked foods:** `RCP_DES_009` Exploding Cupcake, `RCP_BRG_012` Exploding Burger ("Too... loud...").
- **Satisfaction thresholds:** 85 / 65 / 45 / 25; P_mult 1.05, P_offset +5.
- **Anger probability:** 0.15; sensitivity 0.7.
- **Combat behavior:** `CHARGER`, Huff 120, DEF 20, Dmg ×1.1. His rush (§11.8.2) gets a cosmetic rocket ignition; he only escalates past level 4 after a nap is interrupted. Abilities: `ABL_013` Rhino Charge (`MUT_099`), `ABL_027` Armadillo Roll (`MUT_128`), `ABL_044` Gust Kick (`MUT_197`).
- **Mod affinity:** Low-fuss (Aff ×0.6 · Joke ×0.5 · Hidden ×0.5) · favors OMIT, TEMP, MOOD.
- **Spending range:** 1–2 items → ref. spend 12–28 MB. **Tip behavior:** ×1.1.
- **Unique animations:** slow-motion menu page turn; snore bubble with drool-free "Zzz"; rocket exhaust puffs when startled.
- **Dialogue:** Ordering — "I'll have the... (yaaawn)... the... what was the question?" · Delighted — "Mmm... so good... I'm gonna blast off... in a minute... or five..." · Furious — "You woke me up for THIS? Initiating... ROCKET MODE!"
- **Special interactions:** *Nap* — in `WAIT`, 20 % chance to fall asleep (`STS_SLEEPY` visual) for up to 15 s; patience is paused while asleep. A loud event within 10 studs (thrown food, breaking furniture) wakes him with +10 anger. Caffeine dishes add +3 P_offset.
- **Signature look:** `MUT_198` Rocket Booster Leg ×2, `MUT_259` Bear Fur, `MUT_202` Bunny Slippers. **Tier band:** `TIER_01`+ (A 7 · B–C 6 · D–E 5).

#### PER_007 — The Chaos Gremlin
*Occasionally causes trouble even when perfectly happy.*
- **Patience:** ×0.9. Timing: walk ×1.2 · menu ×0.8 · inspect ×1.0 · eat ×0.8.
- **Preferred foods:** `RCP_BRG_012` Exploding Burger, `RCP_DES_009` Exploding Cupcake, `RCP_PIZ_012` Backwards Pizza, `RCP_DRK_006` Rainbow Slushie, `RCP_DES_007` Pie in the Face (Edible).
- **Disliked foods:** `RCP_SAL_001` Garden Salad, `RCP_PST_001` Butter Noodles ("Boooring").
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0.
- **Anger probability:** 0.50; sensitivity 1.2.
- **Combat behavior:** `TRICKSTER`, Huff 80, DEF 5, Dmg ×0.9. Abilities: `ABL_056` Stink Bomb (`MUT_251`), `ABL_048` Slime Trail (`MUT_256`), `ABL_057` Firefly Flash (`MUT_083`).
- **Mod affinity:** Chaotic (Aff ×1.7 · Joke ×2.5 · Hidden ×1.0) · favors JOKE, SEQUENCE, TEMP.
- **Spending range:** 1–2 items → ref. spend 10–30 MB. **Tip behavior:** ×1.0.
- **Unique animations:** rubbing hands with a cackle; tiptoe sneak; innocent whistle after every prank.
- **Dialogue:** Ordering — "Something that explodes, please. Or something that WILL explode if I shake it." · Delighted — "Perfect! Now watch this—" · Furious — "Oh, you've done it now. I'm going to be SO MUCH TROUBLE."
- **Special interactions:** *Happy Prank* — once per visit, after paying and regardless of S, 15 % chance of one prank: knock a cup off a neighbour's table (spill), loosen a chair (−15 % durability), or swipe a neighbour's plate (+15 × sens anger to the victim). A `ROLE_SECURITY` employee within 15 studs reduces the chance by 80 %. Pranks count as chain-reaction sources (§10.8).
- **Signature look:** `MUT_089` Bat Ears, `MUT_067` Piranha Grin, `MUT_071` Googly Eyes. **Tier band:** `TIER_02`+ (A 3 · B–C 5 · D–E 6).

#### PER_008 — The Rich Mutant
*Pays exceptionally well. Expects perfection.*
- **Patience:** ×0.9. Timing: walk ×0.9 · menu ×1.2 · inspect ×1.5 · eat ×1.0.
- **Preferred foods:** the priciest dishes (γ +1.5); `RCP_SEA_004` Lobster-ish Roll, `RCP_SEA_010` Kraken Platter, `RCP_LEG_001` The Golden Patty Supreme, `RCP_DES_014` Galaxy Cheesecake, `RCP_PIZ_015` Galaxy Pizza.
- **Disliked foods:** `RCP_SAN_003` Hot Dog Classic, `RCP_PST_001` Butter Noodles ("Peasant noodles").
- **Satisfaction thresholds:** 96 / 85 / 65 / 45; P_mult 0.90, P_offset 0.
- **Anger probability:** 0.20; sensitivity 1.0.
- **Combat behavior:** `PACIFIST`, Huff 80, DEF 10. Storms out loudly instead ("I'll buy this restaurant and close it!").
- **Mod affinity:** Fancy (Aff ×1.5 · Joke ×1.0 · Hidden ×1.0) · favors DONENESS, PRESENT.
- **Spending range:** 1–3 items at top prices → ref. spend 30–70 MB. **Tip behavior:** ×2.5; Jackpot Tip chance doubled.
- **Unique animations:** monocle polish; tosses a coin to the server (cosmetic sparkle); fainting-couch swoon when displeased.
- **Dialogue:** Ordering — "Your most expensive item. Twice. Gold-plated, if you own a plater." · Delighted — "Splendid! Keep the change. Keep ALL the change." · Furious — "Disgraceful! I shall buy this restaurant just to close it! ...It's not for sale? DISGRACEFUL!"
- **Special interactions:** *Perfectionist* — any item with A < 1 or C < 0.8 applies P_offset −10 to the whole visit. *Round for the house* — at `TIER_05`+, when Delighted, 10 % chance that every other customer gets anger −15. MUT_258 Golden Skin on the server adds +2 MutationBonus (§10.3).
- **Signature look:** `MUT_258` Golden Skin, `MUT_047` Mustache of Destiny, `MUT_272` Sparkle Aura. **Tier band:** `TIER_03`+ (B 2 · C 3 · D 4 · E 5).

#### PER_009 — The Influencer
*Can make your restaurant famous — or infamous — in one post.*
- **Patience:** ×0.8. Timing: walk ×1.0 · menu ×1.0 · inspect ×2.0 (photo session) · eat ×1.0.
- **Preferred foods:** photogenic; `RCP_BRG_009` Rainbow Burger, `RCP_DRK_005` Bubble Tea, `RCP_DRK_006` Rainbow Slushie, `RCP_DES_008` Rainbow Slime Jelly, `RCP_DES_012` Cloud Cotton Candy, `RCP_PIZ_015` Galaxy Pizza.
- **Disliked foods:** `RCP_SOP_007` Swamp Stew ("Not aesthetic"), `RCP_BRG_014` Invisible Burger ("Can't post what I can't see").
- **Satisfaction thresholds:** 92 / 75 / 55 / 35; P_mult 1.0, P_offset 0 (+3 if the table's local décor ≥ 60).
- **Anger probability:** 0.30; sensitivity 1.1.
- **Combat behavior:** `INSTIGATOR`, Huff 75, DEF 5, Dmg ×0.7: livestreams the tantrum ("Chat, should I flip this table?") — her Yell (§10.6) reaches 20 studs instead of 12. Abilities: `ABL_029` Peacock Dazzle (`MUT_219`, signature: the ring-light dazzle), `ABL_023` Bat Screech (`MUT_089`), `ABL_047` Mind Buzz (`MUT_033`).
- **Mod affinity:** Fancy (Aff ×1.5 · Joke ×1.0 · Hidden ×1.0) · favors DONENESS, PRESENT, EXTRA.
- **Spending range:** 1–2 items → ref. spend 12–30 MB. **Tip behavior:** ×1.2.
- **Unique animations:** selfie-angle hold; ring-light spin; dramatic "unfollow" swipe.
- **Dialogue:** Ordering — "Hi chat! I'm getting the Rainbow Burger! Make it, like, extra photogenic?" · Delighted — "OMG, everybody come here RIGHT NOW!" · Furious — "Chat, zero stars. Negative stars. UNFOLLOWED."
- **Special interactions:** *The Post.* On leaving: S ≥ 90 → +0.1 ★ applied directly and 2–4 **Follower** customers arrive within 60 s (bonus arrivals outside base demand, random personalities, each 30 % likely to copy her order). S < 50 → −0.1 ★ (−0.05 ★ while the owner is below level 5) and one queued customer leaves. Max one Post effect per restaurant per 10 min. Posts appear as a "Morph Feed" toast.
- **Signature look:** `MUT_021` TV Head, `MUT_219` Peacock Tail (her ring light), `MUT_272` Sparkle Aura. **Tier band:** `TIER_02`+ (A 2 · B–C 3 · D–E 4).

#### PER_010 — The Bodybuilder Pigeon
*Extremely strong. Extremely easily offended. Never skips arm day; always skips leg day.*
- **Patience:** ×0.9. Timing: walk ×1.0 · menu ×0.8 · inspect ×1.0 · eat ×0.7.
- **Preferred foods:** protein; `RCP_BRG_004` Triple Stack Burger, `RCP_BRG_005` Bacon Monster Burger, `RCP_BRK_002` Fried Egg Plate, `RCP_BRK_008` Bacon Waterfall, `RCP_SAL_005` Carnivore "Salad", `RCP_DRK_003` Chocolate Milkshake ("protein shake").
- **Disliked foods:** `RCP_SAL_004` Salad With No Lettuce, `RCP_DES_012` Cloud Cotton Candy.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0.
- **Anger probability:** 0.55; sensitivity 1.6.
- **Combat behavior:** `BRAWLER`, Huff 180, DEF 30, Dmg ×1.25 (the hardest-hitting customer). Abilities: `ABL_010` Bear Slam (`MUT_140`), `ABL_031` Rocket Punch (`MUT_154`), `ABL_050` Beak Peck Combo (`MUT_063`), `ABL_017` Claw Grab & Toss (`MUT_144`).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors OMIT, EXTRA, DONENESS.
- **Spending range:** 1–3 items → ref. spend 15–45 MB. **Tip behavior:** ×1.0.
- **Unique animations:** double-bicep flex on entry; head-bob strut; offended chest-puff (feathers fluff).
- **Dialogue:** Ordering — "Protein. Double protein. And a protein on the side, bro." · Delighted — "That burger just gave ME a pump. COO-COO, LET'S GO!" · Furious — "Did you just call my legs skinny?! Nobody did? WELL, I HEARD IT!"
- **Special interactions:** *Easily Offended* — a thrown-food hit forces his next escalation roll to succeed. *Respect* — if the server has `MUT_124` Muscle Torso or `MUT_160` Bodybuilder Arm equipped, P_offset +5 ("Respect, bro"). *Spotter* — when Delighted he stays 10 s and, if a hostile customer comes within 8 studs, flexes at them (anger −10, once per visit).
- **Signature look:** `MUT_004` Pigeon Head, `MUT_124` Muscle Torso, `MUT_160` Bodybuilder Arm ×2, `MUT_180` Chicken Leg ×2. **Tier band:** `TIER_02`+ (A 3 · B–E 5).

#### PER_011 — The Conspiracy Moth
*Knows the truth about the pickles.*
- **Patience:** ×1.0 (+5 % per light fixture within 10 studs, max +20 %). Timing: walk ×1.0 · menu ×1.5 · inspect ×1.5 · eat ×1.0.
- **Preferred foods:** glowing or suspicious; `RCP_PST_007` Glow-in-the-Dark Ravioli, `RCP_DRK_013` Glowing Mutagen Juice, `RCP_SOP_004` Alphabet Grumble Soup ("hidden messages"), `RCP_BRG_010` Mystery Meat Burger.
- **Disliked foods:** `RCP_BRG_014` Invisible Burger ("That's what THEY want"), `RCP_PIZ_014` Square Circle Pizza ("geometrically suspicious").
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 0.95, P_offset 0.
- **Anger probability:** 0.30; sensitivity 1.0.
- **Combat behavior:** `TRICKSTER`, Huff 70, DEF 5, Dmg ×0.8: flutters between ceiling lights, debuffs, never stays in melee. Abilities: `ABL_057` Firefly Flash (`MUT_083`), `ABL_040` Spore Puff (`MUT_248`), `ABL_046` Comet Blink (`MUT_228`).
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×2.0) · favors OMIT, SEQUENCE, MOOD.
- **Spending range:** 1–2 items → ref. spend 10–28 MB. **Tip behavior:** ×0.9.
- **Unique animations:** red-string corkboard pantomime; circling the nearest lamp; peering at food through antennae.
- **Dialogue:** Ordering — "I'll have the soup. Not the soup on the menu — the REAL soup." · Delighted — "Delicious... TOO delicious. Who sent you? ...Never mind, another, please." · Furious — "The fries are ROUND on the INSIDE. Wake UP, people!"
- **Special interactions:** *Rumor Mill* — while `COMPLAINING`, customers within 8 studs who are at level ≥ 1 gain +0.3 anger/s ("The pickles are WATCHING us"). *Lamp Lover* — lights calm him (patience bonus above); during `EVT_009` Blackout Night his patience bonus is lost and sensitivity becomes 1.5.
- **Signature look:** `MUT_094` Moth Feather Antennae, `MUT_233` Moth Wings, `MUT_045` Moth Fuzz Face. **Tier band:** `TIER_03`+ (B–E 4).

#### PER_012 — The Nervous Newt
*Apologizes for existing; flees at the first raised voice.*
- **Patience:** ×1.1. Timing: walk ×1.1 · menu ×1.5 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** mild; `RCP_PST_001` Butter Noodles, `RCP_SAN_001` Grilled Cheese, `RCP_DRK_002` Lemonade, `RCP_DES_002` Vanilla Ice Cream. **Disliked:** `RCP_BRG_012` Exploding Burger, `RCP_PIZ_009` Screaming Cheese Pizza, `RCP_DES_013` Screaming Sorbet.
- **Satisfaction thresholds:** 85 / 65 / 45 / 25; P_mult 1.10, P_offset 0. **Anger probability:** 0.05; sensitivity 1.5 (startles easily).
- **Combat behavior:** `PACIFIST`, Huff 40, DEF 0. No abilities (flees at ×1.3 only if a `MUT_186` Cheetah Leg rolled, §36.6).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors OMIT, MOOD.
- **Spending range:** 1 item → ref. spend 8–16 MB. **Tip behavior:** ×1.2; ×1.5 more if served with W = 1 ("You're so nice!").
- **Unique animations:** hides behind the menu; startled hop with tail curl; tiny happy wiggle.
- **Dialogue:** Ordering — "Um, h-hi, sorry, could I maybe have the noodles? Only if it's okay? Sorry. Hi." · Delighted — "You remembered my order! Nobody remembers my order!" · Furious — "Oh no oh no — I'm very upset — sorry — bye!"
- **Special interactions:** *Startle* — any thrown food, broken object or fight within 10 studs adds +15 × 1.5 anger; at level ≥ 3 she flees (`FLEEING`, leaving the price of already-eaten items on the table — the only fleeing customer who pays). With the highest band-A weight she is most players' first unscripted customer.
- **Signature look:** `MUT_014` Axolotl Head, `MUT_256` Frog Slime Skin, `MUT_181` Frog Leg ×2. **Tier band:** `TIER_01`+ (A 8 · B 6 · C 5 · D–E 4).

#### PER_013 — The Grandma Golem
*Four hundred years old, made of rock, and worried you're not eating enough.*
- **Patience:** ×1.4. Timing: walk ×0.8 · menu ×1.2 · inspect ×1.0 · eat ×1.3.
- **Preferred foods:** comfort food; `RCP_SOP_001` Tomato Soup, `RCP_SOP_002` Chicken Noodle-ish Soup, `RCP_PST_002` Mac & Cheese, `RCP_BRG_002` Cheeseburger, `RCP_DES_001` Chocolate Chip Cookie, `RCP_DES_006` Birthday Cake Slice. **Disliked:** `RCP_DRK_015` Liquid Lightning ("In MY day lightning stayed in the sky"), `RCP_PIZ_012` Backwards Pizza.
- **Satisfaction thresholds:** 85 / 60 / 40 / 20; P_mult 1.05, P_offset +5. **Anger probability:** 0.10; sensitivity 0.5.
- **Combat behavior:** `TANK`, Huff 300, DEF 40, Dmg ×0.9 (the sturdiest customer): her slams also wobble every table within 10 studs (20 % spill chance per plate). Abilities: `ABL_021` Ground Pound (`MUT_148`), `ABL_010` Bear Slam (`MUT_140`), `ABL_025` Puff Up (`MUT_129`).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors DONENESS, OMIT.
- **Spending range:** 1–2 items → ref. spend 10–26 MB. **Tip behavior:** ×1.5 ("Buy yourself a sweater, dear").
- **Unique animations:** knitting while waiting; cheek-pinch wave at the server (air pinch); rock-crumble chuckle.
- **Dialogue:** Ordering — "A nice bowl of soup for me, sweetie. You look thin. Eat something too." · Delighted — "Just like I made in the Stone Age!" · Furious — "Young chef, I have been around four hundred years and I have NEVER been so disappointed."
- **Special interactions:** *Calming Presence* — while she is at level 0 and seated, customers within 8 studs decay anger 0.3/s faster (a Chill Aura, §10.10). *Second Helping* — Delighted at the end: 25 % chance she pre-pays a free cookie for the next customer (that customer's P_offset +3). **Tutorial:** QST_TUT_002's first customer, with a fixed look and patience ×3 (§32).
- **Signature look:** `MUT_135` Golem Rock Body, `MUT_169` Mitten Paws, `MUT_260` Sheep Wool (her shawl). **Tier band:** `TIER_01`+ (A 7 · B–C 5 · D–E 4).

#### PER_014 — The Picky Platypus
*Nothing may touch anything. Ever.*
- **Patience:** ×1.0. Timing: walk ×1.0 · menu ×1.5 · inspect ×2.0 (3 s of picking) · eat ×1.2.
- **Preferred foods:** `RCP_SEA_001` Fish Sticks, `RCP_SEA_003` Sushi Roll Block, `RCP_SAN_005` Peanut Butter & Jellyfish, `RCP_BRG_001` Basic Burger. **Disliked:** `RCP_FRI_005` Fried Everything Basket ("too many things TOUCHING"), `RCP_SAN_008` Sandwich With Bread in the Middle, `RCP_PIZ_013` Pizza Inside Another Pizza.
- **Satisfaction thresholds:** 92 / 75 / 55 / 35; P_mult 0.90, P_offset −5. **Anger probability:** 0.35; sensitivity 1.1.
- **Combat behavior:** `THROWER`, Huff 90, DEF 10, Dmg ×1.0: flicks offending garnishes with half the normal aim error. Abilities: `ABL_028` Trunk Spray (`MUT_053`), `ABL_034` Toast Barrage (`MUT_010`), `ABL_041` Frost Blast (`MUT_162`).
- **Mod affinity:** Very picky (Aff ×2.0 · Joke ×0.5 · Hidden ×1.0) · favors OMIT, COUNT, PRESENT.
- **Spending range:** 1–2 items → ref. spend 10–28 MB. **Tip behavior:** ×1.0.
- **Unique animations:** bill-tweezers garnish removal; lines up fries by size; horrified recoil when sauce touches bun.
- **Dialogue:** Ordering — "Fish sticks, cut into rectangles that are less rectangular. And nothing may touch anything." · Delighted — "Nothing is touching. Nothing is TOUCHING! Best day of my life." · Furious — "A pea touched my fry. I'm throwing BOTH."
- **Special interactions:** *Quality Gate* — an item with Q < 0.60 is rejected exactly like a wrong dish (§8.4.2). Serving with `STN_PLATING` plating (plating factor 1.0) earns P_offset +3.
- **Signature look:** `MUT_059` Duck Bill, `MUT_218` Beaver Tail, `MUT_201` Duck Feet. **Tier band:** `TIER_01`+ (A–E 6).

#### PER_015 — The Robot Accountant
*Calculates everything, including your tip, to the decimal.*
- **Patience:** ×1.0 (exactly). Timing: walk ×1.0 · menu ×0.8 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** efficient and square; `RCP_PIZ_014` Square Circle Pizza, `RCP_SEA_003` Sushi Roll Block, `RCP_DES_005` Brownie Brick, `RCP_SAN_002` Ham & Cheese Sandwich (γ −0.5: likes cheap). **Disliked:** `RCP_PST_008` The Infinite Noodle ("UNBOUNDED VALUE ERROR"), `RCP_SOP_010` Bottomless Soup.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0 (+5 during `EVT_017`). **Anger probability:** 0.25; sensitivity 0.9.
- **Combat behavior:** `TANK`, Huff 200, DEF 35, Dmg ×1.0: marches in straight lines, "AUDIT" stomp. Abilities: `ABL_032` Laser Eyes (`MUT_078`, optional signature 30 %), `ABL_021` Ground Pound (`MUT_148`), `ABL_042` Thunder Clap (`MUT_105`).
- **Mod affinity:** Very picky (Aff ×2.0 · Joke ×0.5 · Hidden ×1.0) · favors COUNT, SHAPE.
- **Spending range:** 1–2 cheap items → ref. spend 8–22 MB. **Tip behavior:** ×1.0, rounded to the nearest whole MB; never Jackpots ("RANDOMNESS NOT PERMITTED").
- **Unique animations:** calculator-finger typing; receipt printing from the chest; precise 90° turns.
- **Dialogue:** Ordering — "ORDER: ONE (1) SQUARE CIRCLE PIZZA. BUDGET: OPTIMAL." · Delighted — "SATISFACTION 97.2 PERCENT. TIP CALCULATED. THANK YOU, HUMAN-ISH." · Furious — "ERROR. CALCULATING DAMAGES. RESULT: YOUR TABLE."
- **Special interactions:** *Itemized Receipt* — after paying, the server sees a receipt pop-up with that customer's A, Q, C, W, K, M, P_mult, P_offset, bonuses and S (the in-game satisfaction tutor).
- **Signature look:** `MUT_022` Robot Head, `MUT_123` Robot Body, `MUT_044` Robot Visor. **Tier band:** `TIER_02`+ (A 3 · B–E 4).

#### PER_016 — The Party Pack
*Three mini-mutants, one table, zero indoor voices.*
- **Patience:** ×0.9 (shared). Timing: walk ×1.3 · menu ×0.7 · inspect ×0.5 · eat ×0.7.
- **Preferred foods:** kid classics; `RCP_FRI_001` French Fries, `RCP_PIZ_001` Cheese Pizza, `RCP_SAN_003` Hot Dog Classic, `RCP_DES_002` Vanilla Ice Cream, `RCP_DES_003` Donut Ring, `RCP_DRK_001` Fizzy Soda. **Disliked:** `RCP_SAL_001` Garden Salad, `RCP_SOP_007` Swamp Stew.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.35; sensitivity 1.2.
- **Combat behavior:** `BRAWLER`, Huff 50 each (×3), DEF 0, Dmg ×0.5, body scale 0.6: they dog-pile one target (still bound by the §11.8.1 two-attacker token limit). Abilities: `ABL_011` Kangaroo Kick (`MUT_184`), `ABL_050` Beak Peck Combo (`MUT_063`), `ABL_037` Jelly Bounce (`MUT_134`).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors EXTRA, PRESENT.
- **Spending range:** 1 item each, one ticket → ref. spend 24–40 MB per party. **Tip behavior:** ×1.1 on the shared bill.
- **Unique animations:** triple high-five; chair-hopping; synchronized "WHOAAA" when food arrives.
- **Dialogue:** Ordering — "FRIES! — NO, PIZZA! — I WANT WHAT SHE'S HAVING!" · Delighted — "BEST! PARTY! EVER!" · Furious — "Mini-mutants... ASSEMBLE!"
- **Special interactions:** spawns as **one party of 3** (§8.2.4) on one table and one ticket; S is the price-weighted mean of the three. *Shared Mood* — when one member gains anger from a hit or defect, the other two gain 40 % of it. Escalation is rolled once for the trio. One mini calmed = all three calm.
- **Signature look:** all three wear `MUT_051` Clown Nose and `MUT_272` Sparkle Aura; bodies otherwise procedural. **Tier band:** `TIER_03`+ (B–C 3 · D–E 4).

#### PER_017 — The Pirate Crab
*Sails in sideways, pays in "doubloons", fires meatballs.*
- **Patience:** ×1.0. Timing: walk ×0.8 (peg leg) · menu ×1.0 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** SEA; `RCP_SEA_001` Fish Sticks, `RCP_SEA_002` Fried Shrimp Basket, `RCP_SEA_005` Waving Calamari Rings, `RCP_SEA_009` Sea Monster Steak, `RCP_TAC_006` Fish Taco of Destiny, `RCP_DRK_011` Tentacle Tea. **Disliked:** `RCP_SEA_006` Crab Cake Kerfuffle ("That be me Uncle Pinchy!"), `RCP_SAL_001` Garden Salad.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.40; sensitivity 1.1.
- **Combat behavior:** `THROWER`, Huff 120, DEF 15, Dmg ×1.0: "cannonball" meatball lobs with +5-stud range. Abilities: `ABL_049` Tentacle Whip (`MUT_146`), `ABL_031` Rocket Punch (`MUT_154`, "the cannon arm"), `ABL_028` Trunk Spray (`MUT_053`). His crab claw is for show (its `ABL_017` is not `THROWER`-eligible).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors EXTRA, COUNT, DONENESS.
- **Spending range:** 1–2 items → ref. spend 12–30 MB. **Tip behavior:** ×1.0; *Buried Treasure* — Jackpot chance ×2.
- **Unique animations:** sideways scuttle with `ANM_008` peg-leg wobble; spyglass menu read; telescope-sighting the kitchen.
- **Dialogue:** Ordering — "Arr! Fetch me yer finest fish sticks, and be quick about it, matey!" · Delighted — "Shiver me shell! Worth its weight in doubloons!" · Furious — "Ready the meatball cannons! FIRE!"
- **Special interactions:** *Treasure Map* — on Delight, 5 % chance to "bury" his tip: a sparkle appears at a random dining spot and the first player to step on it collects tip ×1.5. Displays all prices as "doubloons" (still MB).
- **Signature look:** `MUT_127` Crab Shell Torso, `MUT_144` Crab Claw Arm (one arm), `MUT_193` Tree Trunk Leg as a peg leg (other leg `MUT_179`). **Tier band:** `TIER_02`+ (A 3 · B–E 4).

#### PER_018 — The Drama Llama
*Every feeling at maximum volume.*
- **Patience:** ×0.9. Timing: walk ×1.0 · menu ×1.3 · inspect ×1.3 · eat ×1.0.
- **Preferred foods:** theatrical; `RCP_BRG_007` Volcano Burger, `RCP_PIZ_009` Screaming Cheese Pizza, `RCP_DES_013` Screaming Sorbet, `RCP_SOP_006` Pumpkin Screamer Soup, `RCP_DES_007` Pie in the Face (Edible). **Disliked:** `RCP_PST_001` Butter Noodles ("So... beige").
- **Satisfaction thresholds:** 92 / 72 / 52 / 32; P_mult 0.95, P_offset 0. **Anger probability:** 0.35; sensitivity 1.4.
- **Combat behavior:** `INSTIGATOR`, Huff 100, DEF 10, Dmg ×0.8: monologues (her Yell) that rile up the room. Abilities: `ABL_023` Bat Screech (`MUT_089`), `ABL_029` Peacock Dazzle (`MUT_219`), `ABL_047` Mind Buzz (`MUT_033`).
- **Mod affinity:** Chaotic (Aff ×1.7 · Joke ×2.5 · Hidden ×1.0) · favors SHAPE, SEQUENCE, JOKE.
- **Spending range:** 1–2 items → ref. spend 12–28 MB. **Tip behavior:** ×1.0.
- **Unique animations:** back-of-hoof forehead swoon; standing ovation; slow-motion faint onto the floor.
- **Dialogue:** Ordering — "I would like... (dramatic pause)... the Volcano Burger. And I would like it to CHANGE MY LIFE." · Delighted — "BRAVO! I'm weeping! Somebody bring me a tissue and a second burger!" · Furious — "This is the WORST thing that has EVER happened to ANYONE!" *(faints)*
- **Special interactions:** *Amplified* — evaluation anger deltas ×1.5 in **both** directions. *Dramatic Faint* — at level 2 she faints for 4 s, blocking her aisle cell (paths reroute). *Standing Ovation* — when Delighted, every customer within 10 studs gets anger −10.
- **Signature look:** `MUT_110` Giraffe Neck, `MUT_260` Sheep Wool, `MUT_205` Hooves. **Tier band:** `TIER_02`+ (A 3 · B–E 4).

#### PER_019 — The Mime Mantis
*Orders only in pictograms. Applauds silently. Fights invisibly.*
- **Patience:** ×1.1. Timing: walk ×1.0 · menu ×1.2 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** quiet food; `RCP_BRG_014` Invisible Burger (a mime's dream), `RCP_DES_002` Vanilla Ice Cream, `RCP_SEA_003` Sushi Roll Block, `RCP_PST_001` Butter Noodles. **Disliked:** loud food; `RCP_PIZ_009` Screaming Cheese Pizza, `RCP_DES_013` Screaming Sorbet, `RCP_SOP_006` Pumpkin Screamer Soup, `RCP_SOP_004` Alphabet Grumble Soup.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0 (+5 when the pictogram order is fully correct). **Anger probability:** 0.25; sensitivity 1.0.
- **Combat behavior:** `TRICKSTER`, Huff 100, DEF 10, Dmg ×0.9: its debuff throw is mimed as an "invisible box" (`STS_STICKY`, §36.7). Abilities: `ABL_020` Web Shot (`MUT_028`, the "invisible rope"), `ABL_016` Tongue Yank (`MUT_061`), `ABL_046` Comet Blink (`MUT_228`). The scythe arms are for (silent) show.
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×1.0) · favors JOKE, COUNT, SHAPE.
- **Spending range:** 1–2 items → ref. spend 10–28 MB. **Tip behavior:** ×1.2.
- **Unique animations:** walking against invisible wind; pulling an invisible rose from an invisible sleeve; trapped-in-a-box routine.
- **Dialogue (pictogram bubbles):** Ordering — *burger icon · crossed-out tomato · two fingers* while miming careful eating · Delighted — *silent applause, invisible rose, deep bow* · Furious — *mimes being trapped in a box... then mimes building one around YOU.*
- **Special interactions:** *Pictogram Order* — the ticket shows icons only (recipe category, ingredients, modification glyphs). Text appears with `ABL_064` Super Sniff, `ABL_070` Eagle Eye, or after 5 s with the accessibility setting "Pictogram Hints" (default ON in band B). A wrong dish caused by misreading still counts as wrong. Ordering never uses voice SFX.
- **Signature look:** `MUT_026` Mantis Head, `MUT_151` Mantis Scythe Arm ×2. **Tier band:** `TIER_03`+ (B–E 3).

#### PER_020 — The Toddler Titan
*Enormous. Adorable. Throws everything.*
- **Patience:** ×0.7. Timing: walk ×0.9 · menu ×0.6 · inspect ×0.5 · eat ×1.4 (messy).
- **Preferred foods:** sweets; `RCP_DES_002` Vanilla Ice Cream, `RCP_DES_004` Strawberry Sundae, `RCP_DES_003` Donut Ring, `RCP_BRK_001` Pancake Stack, `RCP_DRK_003` Chocolate Milkshake, `RCP_SAN_001` Grilled Cheese. **Disliked:** `RCP_SAL_001` Garden Salad ("NO GREEN!"), `RCP_SOP_007` Swamp Stew, `RCP_DRK_008` Swamp Water Smoothie.
- **Satisfaction thresholds:** 85 / 65 / 45 / 25; P_mult 1.0, P_offset 0 (+5 for any DES item). **Anger probability:** 0.45; sensitivity 1.3.
- **Combat behavior:** `THROWER`, Huff 120, DEF 20, Dmg ×0.9, body scale 1.35 (needs a booth or a 2-seat table): its aim error is doubled — a menace to bystanders. Abilities: `ABL_034` Toast Barrage (`MUT_010`), `ABL_028` Trunk Spray (`MUT_053`), `ABL_041` Frost Blast (`MUT_162`).
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×1.0) · favors EXTRA, OMIT, JOKE.
- **Spending range:** 1–2 items → ref. spend 8–24 MB. **Tip behavior:** ×0.8.
- **Unique animations:** spoon-banging; floor-kicking tantrum (variant of `ANM_050`); sticky-hug lunge when happy.
- **Dialogue:** Ordering — "WANT ICE CREAM! WANT IT NOW! WANT IT YESTERDAY!" · Delighted — "YAAAY! You're my BEST FRIEND!" · Furious — "NO! NO! NOOOOO!"
- **Special interactions:** *Sweet Tooth* — a Peace Offering dessert drops anger by **two full levels** (§10.10). *Nap Time* — after a dessert, 20 % chance to doze for 10 s before paying (`STS_SLEEPY` visual, immune to auras).
- **Signature look:** `MUT_118` Bear Body, `MUT_071` Googly Eyes, `MUT_202` Bunny Slippers; scale 1.35. **Tier band:** `TIER_02`+ (A 3 · B–E 4).

#### PER_021 — The Health Nut Hamster
*Counts every vitamin; rolls out of here in a ball when wronged.*
- **Patience:** ×1.0. Timing: walk ×1.2 · menu ×1.4 (reads labels) · inspect ×1.2 · eat ×0.9.
- **Preferred foods:** SAL, smoothies; `RCP_SAL_001` Garden Salad, `RCP_SAL_003` Fruit Salad Explosion, `RCP_DRK_004` Strawberry Smoothie, `RCP_DRK_008` Swamp Water Smoothie, `RCP_SEA_003` Sushi Roll Block. **Disliked:** FRI; `RCP_FRI_001` French Fries, `RCP_FRI_004` Fried Ice Cream, `RCP_FRI_005` Fried Everything Basket, `RCP_BRG_015` The Unreasonably Large Burger.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 0.95, P_offset 0. **Anger probability:** 0.25; sensitivity 1.0.
- **Combat behavior:** `CHARGER`, Huff 110, DEF 15, Dmg ×1.0: curls into a hamster ball and rolls through furniture. Abilities: `ABL_027` Armadillo Roll (`MUT_128`, signature), `ABL_011` Kangaroo Kick (`MUT_184`).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors OMIT, TEMP.
- **Spending range:** 1–2 items → ref. spend 10–26 MB. **Tip behavior:** ×1.1.
- **Unique animations:** jogging in place while waiting; label-squint; protein-free victory jumping jacks.
- **Dialogue:** Ordering — "One Garden Salad, extra garden. Is the lettuce free-range?" · Delighted — "So many vitamins! I'll run nine miles on my wheel tonight!" · Furious — "Is that... GREASE?! I'm rolling OUT of here!"
- **Special interactions:** *Label Reader* — any item whose recipe has the `fried` ingredient tag (§C9) applies P_offset −10, even if it was what she ordered by mistake. *Workout* — while waiting she jogs in place: patience drains 10 % slower, but she blocks her aisle cell.
- **Signature look:** `MUT_087` Mouse Ears, `MUT_057` Carrot Nose, `MUT_128` Armadillo Body. **Tier band:** `TIER_02`+ (A–E 4).

#### PER_022 — The Spicy Salamander
*Nothing is ever spicy enough.*
- **Patience:** ×1.0. Timing: walk ×1.0 · menu ×1.0 · inspect ×1.0 · eat ×0.8.
- **Preferred foods:** `spicy` tag; `RCP_BRG_007` Volcano Burger, `RCP_PIZ_008` Lava Pizza, `RCP_TAC_008` Hot Sauce Volcano Burrito, `RCP_TAC_009` Ghost Pepper Ghost Taco, `RCP_SOP_008` Lava Lentil Soup, `RCP_DRK_010` Hot Sauce Latte, `RCP_PST_010` Spicy Lava Lasagna. **Disliked:** frozen; `RCP_BRG_008` Frozen Burger, `RCP_SOP_003` Soupsicle (Frozen Soup), `RCP_DRK_009` Ice Ice Smoothie.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0 (−5 for any item without the `spicy` tag unless it carries a heat modification from §6.18). **Anger probability:** 0.35; sensitivity 1.0.
- **Combat behavior:** `THROWER`, Huff 120, DEF 15, Dmg ×1.1: prefers `spicy` food as ammunition (`STS_TOASTY` on hit per §11.6.1). Abilities: `ABL_032` Laser Eyes (`MUT_078`, "heat vision"), `ABL_034` Toast Barrage (`MUT_010`), `ABL_031` Rocket Punch (`MUT_154`).
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×1.0) · favors EXTRA, TEMP, MOOD.
- **Spending range:** 1–2 items → ref. spend 14–32 MB. **Tip behavior:** ×1.0.
- **Unique animations:** fanning mouth with delight; steam-ear puffs; drinking hot sauce like soda.
- **Dialogue:** Ordering — "Volcano Burger. Hotter. Hotter than that. Make the volcano nervous." · Delighted — "PERFECT! My tongue just took a vacation to the sun!" · Furious — "This is MILD. Do you know what I do to MILD things?"
- **Special interactions:** *Heat Seeker* — sits nearest the kitchen when possible (§8.6); the `EVT_019` EventModifier (+5 for spicy dishes served with a drink) stacks with his spicy preference. A station going `ON_FIRE` does **not** anger him (he cheers instead: anger −5).
- **Signature look:** `MUT_254` Fireproof Skin, `MUT_215` Lizard Tail, `MUT_115` Frill Lizard Collar. **Tier band:** `TIER_03`+ (B–E 4).

#### PER_023 — The Frozen Yeti-Fish
*Likes it cold. Melts into a bad mood near hot grills.*
- **Patience:** ×1.1 (×0.87 effective drain if ≥ 4 heat stations are running within 20 studs). Timing: walk ×0.9 · menu ×1.0 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** cold; `RCP_BRG_008` Frozen Burger, `RCP_SOP_003` Soupsicle (Frozen Soup), `RCP_DES_002` Vanilla Ice Cream, `RCP_DES_013` Screaming Sorbet, `RCP_DES_011` Frozen Lava Cake, `RCP_DRK_006` Rainbow Slushie, `RCP_DRK_009` Ice Ice Smoothie. **Disliked:** `RCP_SOP_008` Lava Lentil Soup, `RCP_PIZ_008` Lava Pizza, `RCP_DRK_010` Hot Sauce Latte.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.25; sensitivity 0.9.
- **Combat behavior:** `CHARGER`, Huff 170, DEF 25, Dmg ×1.0: his rush is a belly slide that leaves a 6-stud ice streak (players crossing it get `STS_SLOW`, §36.7). Abilities: `ABL_054` Hammerhead Bash (`MUT_025`), `ABL_044` Gust Kick (`MUT_197`), `ABL_013` Rhino Charge (`MUT_099`).
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×1.0) · favors TEMP, EXTRA.
- **Spending range:** 1–2 items → ref. spend 10–28 MB. **Tip behavior:** ×1.0.
- **Unique animations:** fanning himself with a menu; shiver of joy; ice-skating belly slide.
- **Dialogue:** Ordering — "Brrr-illiant. One Frozen Burger, colder than a snowball's snowball." · Delighted — "Chilly perfection! I'm so happy I could hibernate." · Furious — "It's WARM. You served me WARM. Prepare for... the BELLY SLIDE!"
- **Special interactions:** *Meltdown* — seated within 20 studs of ≥ 4 running heat stations, patience drains ×1.15; the host seats him by the door (§8.6). Hot-served frozen dishes (temperature modifications of §6.18) count as defects. During `EVT_020` Frozen Snap he is Delighted at 85.
- **Signature look:** `MUT_262` Yeti Frost Fur, `MUT_009` Fish Head, `MUT_214` Fish Tail. **Tier band:** `TIER_03`+ (B–E 4).

#### PER_024 — The Time-Traveler Tortoise
*Orders from the future; politely accepts the present.*
- **Patience:** ×1.5. Timing: walk ×0.5 · menu ×1.5 · inspect ×1.0 · eat ×1.5.
- **Preferred foods:** breakfast at all hours; `RCP_BRK_009` Breakfast-for-Dinner-for-Breakfast, `RCP_BRK_005` Upside-Down Pancakes, `RCP_BRK_007` Cereal With Soup Instead of Milk, `RCP_SOP_003` Soupsicle (Frozen Soup). **Disliked:** `RCP_DRK_015` Liquid Lightning ("Last time I drank that I ended up in next Tuesday").
- **Satisfaction thresholds:** 85 / 65 / 45 / 25; P_mult 1.0, P_offset +5. **Anger probability:** 0.10; sensitivity 0.6.
- **Combat behavior:** `PACIFIST`, Huff 80, DEF 40 (it is mostly shell). No abilities; when upset it retreats into its shell and sulks.
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×1.0) · favors DONENESS, TEMP, SEQUENCE.
- **Spending range:** 1–2 items → ref. spend 12–30 MB. **Tip behavior:** ×1.3.
- **Unique animations:** pocket-watch check; slow-motion everything; a brief rewind shimmer when sitting.
- **Dialogue:** Ordering — "I'd like the Galaxy Pizza, please. Oh — you won't know it for another forty levels? Then whatever's closest." · Delighted — "Marvelous! I'll tip you now AND last Tuesday." · Furious — "I have waited CENTURIES! ...Well, it felt like centuries. It was ninety seconds."
- **Special interactions:** *Order From the Future* — the main is a recipe the owner has **not learned**, chosen from recipes with unlock level in (L, L + 10] in a category the menu serves; the ticket reads "From the Future". Any recipe of the same category is accepted as a substitute with A = 0.8 (+5 P_offset if the substitute's unlock level ≥ requested − 10). Serving the real recipe (if learned meanwhile) gives A = 1 and Tip× +0.5 ("Paradox!"). Either way the requested recipe is revealed as a *Recipe Preview* in the Cooking Academy (`BLD_06`) at −10 % learning cost (once per recipe).
- **Signature look:** `MUT_244` Turtle Backpack Shell, `MUT_109` Turtle Neck, `MUT_272` Sparkle Aura (time sparkles). **Tier band:** `TIER_04`+ (B–C 2 · D–E 3).

#### PER_025 — The Undercover Inspector
*Definitely just a normal customer. Sniff sniff.*
- **Patience:** ×1.0. Timing: walk ×1.0 · menu ×1.0 · inspect ×1.5 · eat ×1.0.
- **Preferred foods:** deliberately ordinary; `RCP_SAN_002` Ham & Cheese Sandwich, `RCP_SOP_001` Tomato Soup, `RCP_DRK_002` Lemonade. **Disliked:** `RCP_BRG_010` Mystery Meat Burger ("Where did this meat come from? Asking for... no one.").
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.00 (would blow the cover); sensitivity 0.5.
- **Combat behavior:** `PACIFIST`, Huff 80, DEF 10. No abilities.
- **Mod affinity:** Fancy (Aff ×1.5 · Joke ×1.0 · Hidden ×2.0) · favors PRESENT, SEQUENCE.
- **Spending range:** 1 item → ref. spend 10–18 MB. **Tip behavior:** ×1.0.
- **Unique animations:** table-top finger swipe for dust; hidden notepad scribble; badge half-flash, quickly hidden.
- **Dialogue:** Ordering — "One perfectly normal sandwich, for me, a perfectly normal customer." · Delighted — "Very... clean. I mean TASTY. Tasty is what I meant." · Furious (cover blown) — "Alright, FINE! INSPECTOR! You have a SPILL in aisle three!"
- **Special interactions:** *Inspection* — tracks the minimum dining cleanliness K seen during the visit (§10.2). On leaving: K_min ≥ 80 → "Spotless" certificate, +0.05 ★ and a cosmetic façade badge for 1 h; K_min < 50 → "Citation", −0.05 ★. *Blown Cover* — if hit by anything, or revealed by `ABL_064` Super Sniff and then served last, he flashes the badge and leaves after paying: the inspection completes immediately using the current K. Cousin of `NPC_022` Inspector Grimewell, who runs the official `EVT_026` sweeps (§36.11); the undercover visits keep their normal weight during a sweep.
- **Signature look:** `MUT_047` Mustache of Destiny (obviously fake), `MUT_054` Star-Nosed Mole Nose. **Tier band:** `TIER_03`+ (B–E 2).

#### PER_026 — The Speedrunner Squirrel
*Going for the world record in eating fries.*
- **Patience:** ×0.6 — a visible speedrun timer floats above the head. Timing: walk ×1.6 · menu ×0.3 · inspect ×0.3 · eat ×0.4.
- **Preferred foods:** nuts and quick bites; `RCP_SAN_005` Peanut Butter & Jellyfish, `RCP_DES_010` Bug Brittle, `RCP_DES_001` Chocolate Chip Cookie, `RCP_FRI_001` French Fries, `RCP_DRK_001` Fizzy Soda. **Disliked:** `RCP_PST_008` The Infinite Noodle ("unskippable cutscene"), `RCP_SOP_010` Bottomless Soup.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.40; sensitivity 1.2.
- **Combat behavior:** `CHARGER`, Huff 110, DEF 5, Dmg ×0.9: zig-zag rush approach. Abilities: `ABL_011` Kangaroo Kick (`MUT_184`), `ABL_044` Gust Kick (`MUT_197`), `ABL_058` Goat Headbutt (`MUT_097`).
- **Mod affinity:** Low-fuss (Aff ×0.6 · Joke ×0.5 · Hidden ×0.5) · favors JOKE, DONENESS.
- **Spending range:** 1 item → ref. spend 8–16 MB. **Tip behavior:** ×1.0; ×2 if served within 25 % of patience ("WORLD RECORD!").
- **Unique animations:** split-timer tap on arrival and at every state change; frame-perfect chair slide; reset-facepalm.
- **Dialogue:** Ordering — "Fries. GO GO GO — timer's running!" · Delighted — "NEW PERSONAL BEST! Frame-perfect fries!" · Furious — "RESET! RESET! This run is RUINED!"
- **Special interactions:** *Splits* — the timer shows green/red segment glyphs (▲ ahead / ▼ behind, never color-only) against his personal best stored per restaurant; beating it adds P_offset +5. *Speed Skip* — he never waits in the outside queue (walk-by instead).
- **Signature look:** `MUT_186` Cheetah Leg ×2, `MUT_226` Fluffy Fox Tail, `MUT_090` Fox Ears. **Tier band:** `TIER_04`+ (B–E 3).

#### PER_027 — The Lovebird Jellyfish Couple
*Two jellyfish, one sundae, a lot of glowing.*
- **Patience:** ×1.3 (shared). Timing: walk ×0.9 · menu ×1.3 · inspect ×1.0 · eat ×1.3.
- **Preferred foods:** shareable; `RCP_DES_004` Strawberry Sundae, `RCP_DES_006` Birthday Cake Slice, `RCP_DRK_004` Strawberry Smoothie, `RCP_PIZ_002` Pepperoni Pizza, `RCP_PST_003` Spaghetti & Meatballs. **Disliked:** `RCP_SEA_008` Jellyfish Jiggle Bowl ("We don't talk about the Jiggle Bowl").
- **Satisfaction thresholds:** 88 / 68 / 48 / 28; P_mult 1.05, P_offset +5. **Anger probability:** 0.10; sensitivity 1.2.
- **Combat behavior:** `PACIFIST`, Huff 70 each, DEF 0. No abilities; they leave together.
- **Mod affinity:** Fancy (Aff ×1.5 · Joke ×1.0 · Hidden ×1.0) · favors SHAPE, PRESENT.
- **Spending range:** 1–2 items each on one ticket → ref. spend 26–56 MB per couple. **Tip behavior:** ×1.3.
- **Unique animations:** tentacle hand-holding; synchronized pink glow pulses; sharing one milkshake with two straws.
- **Dialogue:** Ordering — "We'll share the sundae! — Two spoons! — One cherry, cut in half!" · Delighted — "Best anniversary EVER!" *(both glow)* · Furious — "Sweetie, let's go. — Yes, darling. We are VERY disappointed. Together."
- **Special interactions:** always a **party of 2** (§8.2.4). *Shared Feelings* — anger gains on one apply 100 % to the other. *Anniversary Moment* — if both are Delighted, 5 % chance of a confetti moment: every customer within 15 studs gets anger −20 and the couple's tip is ×2.
- **Signature look:** both wear `MUT_130` Jellyfish Body, `MUT_111` Flamingo Neck, `MUT_272` Sparkle Aura (hearts). **Tier band:** `TIER_03`+ (B–E 3).

#### PER_028 — The Haunted Toaster
*A ghost who loves bread and hates soggy things.*
- **Patience:** ×1.0. Timing: walk ×1.0 (floats) · menu ×1.0 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** bread; `RCP_SAN_001` Grilled Cheese, `RCP_SAN_004` Club Sandwich Stack, `RCP_SAN_010` The Sandwich Sandwich, `RCP_BRK_001` Pancake Stack, `RCP_SOP_009` Bread Bowl in a Bread Bowl. **Disliked:** wet; `RCP_SOP_007` Swamp Stew, `RCP_DRK_008` Swamp Water Smoothie.
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.35; sensitivity 1.0.
- **Combat behavior:** `THROWER`, Huff 100, DEF 15, Dmg ×1.0. Abilities: `ABL_034` Toast Barrage (`MUT_010`, signature), `ABL_028` Trunk Spray (`MUT_053`). *Ghostly* (personality hook): 25 % of thrown-food hits pass straight through him (no anger) and keep flying.
- **Mod affinity:** Chaotic (Aff ×1.7 · Joke ×2.5 · Hidden ×1.0) · favors DONENESS, JOKE, TEMP.
- **Spending range:** 1–2 items → ref. spend 10–28 MB. **Tip behavior:** ×1.0.
- **Unique animations:** toast pops from the head when happy; spooky float-bob; slots glowing when annoyed.
- **Dialogue:** Ordering — "Grilled cheeeeese... ooooOOOooo..." · Delighted — "Toasty! I haven't felt this warm since I was plugged in!" · Furious — "SOGGY BREAD? Taste my TOAST BARRAGE!"
- **Special interactions:** *Poltergeist* — at level 2 a random plate within 6 studs floats for 3 s (`STS_FLOATING` visual; cosmetic, the food is unharmed). *Haunted Night* — weight ×4 during `EVT_029`; while that event runs, his Delighted threshold drops to 85.
- **Signature look:** `MUT_010` Toaster Head, `MUT_252` Ghost Sheet Cape. **Tier band:** `TIER_04`+ (B–E 3).

#### PER_029 — The Alien Tourist
*Here to try authentic Earth discs ("burgers").*
- **Patience:** ×1.2. Timing: walk ×1.0 · menu ×1.5 (translating) · inspect ×1.5 (photos) · eat ×1.0.
- **Preferred foods:** ALN plus Earth classics; `RCP_ALN_001` Moon Cheese Nuggets, `RCP_ALN_006` UFO Saucer Pancakes, `RCP_BRG_001` Basic Burger, `RCP_DRK_001` Fizzy Soda, `RCP_PIZ_015` Galaxy Pizza. **Disliked:** `RCP_ALN_009` Glorp Stew ("Tastes like home. TOO much like home."), `RCP_PIZ_014` Square Circle Pizza.
- **Satisfaction thresholds:** 85 / 65 / 45 / 25; P_mult 1.05, P_offset +5. **Anger probability:** 0.20; sensitivity 1.0.
- **Combat behavior:** `TRICKSTER`, Huff 100, DEF 15, Dmg ×0.9: its plate thefts are "beamed up as evidence", angering those diners. Abilities: `ABL_045` Tractor Beam (`MUT_166`, optional signature 50 %), `ABL_046` Comet Blink (`MUT_228`), `ABL_020` Web Shot (`MUT_028`).
- **Mod affinity:** Quirky (Aff ×1.2 · Joke ×1.5 · Hidden ×1.0) · favors JOKE, OMIT, COUNT.
- **Spending range:** 1–3 items → ref. spend 14–45 MB. **Tip behavior:** ×1.2.
- **Unique animations:** photographing every plate; antenna wiggle while reading; awestruck slow-clap with three hands.
- **Dialogue (glyph bubbles + subtitles):** Ordering — "Greetings, Earth cook! I wish to sample your famous Basic Burger disc." · Delighted — "I will tell all eleven of my moons about this!" · Furious — "Reporting this to the Galactic Tourism Board. Beaming up your plates as evidence."
- **Special interactions:** *Tour Group* — during `EVT_018` (weight ×4) 40 % of Alien Tourists arrive as a party of 3–4, all PER_029. *Souvenir* — Delighted: tips an extra 5 % if the restaurant serves any ALN dish. Speech uses glyphs with subtitles (no translation needed by the player).
- **Signature look:** `MUT_033` Alien Grey Head, `MUT_103` Antenna Bobbles, `MUT_210` Moon Boots. **Tier band:** `TIER_05`+ (C–D 3 · E 4).

#### PER_030 — The Retired Wrestler Walrus
*Hung up the singlet years ago. Will come out of retirement for bad service.*
- **Patience:** ×1.0. Timing: walk ×0.8 · menu ×1.0 · inspect ×1.0 · eat ×0.8.
- **Preferred foods:** big plates; `RCP_SEA_009` Sea Monster Steak, `RCP_SEA_002` Fried Shrimp Basket, `RCP_BRG_015` The Unreasonably Large Burger, `RCP_SAN_009` Sub of Unreasonable Length, `RCP_DRK_003` Chocolate Milkshake. **Disliked:** `RCP_SEA_005` Waving Calamari Rings ("They're waving at me. I can't eat a fan.").
- **Satisfaction thresholds:** 90 / 70 / 50 / 30; P_mult 1.0, P_offset 0. **Anger probability:** 0.40; sensitivity 1.3.
- **Combat behavior:** `BRAWLER`, Huff 180, DEF 35, Dmg ×1.2: grapples and body-splashes. Abilities: `ABL_010` Bear Slam (`MUT_140`, signature — "The Body Splash"), `ABL_042` Thunder Clap (`MUT_105`), `ABL_053` Tail Spin (`MUT_227`).
- **Mod affinity:** Standard (Aff ×1.0 · Joke ×1.0 · Hidden ×1.0) · favors EXTRA, MOOD.
- **Spending range:** 1–3 items → ref. spend 18–50 MB. **Tip behavior:** ×1.1.
- **Unique animations:** championship-belt raise (imaginary); turnbuckle pose on his chair; tusk-gleam grin.
- **Dialogue:** Ordering — "Biggest steak you've got, kid. I used to bench-press these." · Delighted — "That meal just won the CHAMPIONSHIP BELT! OOOH YEAH!" · Furious — "Ding ding ding! The Walrus is coming OUT OF RETIREMENT!"
- **Special interactions:** *Tag Team* — if Delighted and still seated, he intercepts the first hostile customer that comes within 15 studs: a harmless headlock that drops its anger by 25 (once per visit; counts as a Chill effect, not combat). *Tag In* — if a player is fighting another customer within 12 studs while he is at level ≥ 2, 25 % chance he joins the fight on the *customer's* side.
- **Signature look:** `MUT_064` Walrus Tusks, `MUT_047` Mustache of Destiny, `MUT_124` Muscle Torso, `MUT_140` Bear Arm ×2. **Tier band:** `TIER_05`+ (C–E 3).

#### PER_031 — The Birthday Beast
*It's their birthday. It's always their birthday.*
- **Patience:** ×1.0. Timing: walk ×1.1 · menu ×0.8 · inspect ×1.0 · eat ×1.0.
- **Preferred foods:** party food; `RCP_DES_006` Birthday Cake Slice (always the extra item; any DES if absent), `RCP_PIZ_002` Pepperoni Pizza, `RCP_DES_009` Exploding Cupcake, `RCP_DRK_006` Rainbow Slushie, `RCP_BRG_009` Rainbow Burger. **Disliked:** `RCP_SAL_004` Salad With No Lettuce ("No salad on my BIRTHDAY").
- **Satisfaction thresholds:** 92 / 72 / 52 / 32; P_mult 1.10, P_offset +5. **Anger probability:** 0.40; sensitivity 1.5.
- **Combat behavior:** `THROWER`, Huff 120, DEF 10, Dmg ×1.0: hurls cake slices (confetti bursts on impact). Abilities: `ABL_031` Rocket Punch (`MUT_154`, "confetti cannon"), `ABL_049` Tentacle Whip (`MUT_146`), `ABL_034` Toast Barrage (`MUT_010`).
- **Mod affinity:** Fancy (Aff ×1.5 · Joke ×1.0 · Hidden ×1.0) · favors PRESENT, EXTRA.
- **Spending range:** exactly 2 items (main + cake) → ref. spend 20–36 MB. **Tip behavior:** ×1.5.
- **Unique animations:** party-horn toot; candle-blowing on anything round; confetti stomp when upset.
- **Dialogue:** Ordering — "It's my BIRTHDAY! Pizza, cake, and everyone has to sing. Those are the rules." · Delighted — "Best. Birthday. EVER! I'm having another one next week!" · Furious — "Nobody SANG! IT'S MY BIRTHDAY!"
- **Special interactions:** *Sing!* — a "Sing" prompt appears on the customer while the cake is on the ticket; any player who holds it for 2 s within 10 studs gives P_offset +8 and anger −15 (once per visit; co-op players singing together each add +2 more, max +12 total). *No Cake?!* — if the dessert isn't delivered before patience ends, anger +20 × sens. At table service, 60 % of Birthday Beasts arrive with a party of 3–4.
- **Signature look:** `MUT_101` Unicorn Horn (worn as a party hat, probably), `MUT_272` Sparkle Aura. **Tier band:** `TIER_03`+ (B–E 3).

#### PER_032 — The Mystery Mutant
*Arrives under a sheet with a question mark. Could be anyone.*
- **Patience / thresholds / anger / style / Huff / items:** pre-reveal ×1.0 · 90/70/50/30 · P_mult 1.0 · P_offset 0; at reveal **every** parameter, ability list, preference and special interaction switches to the revealed personality.
- **Preferred / disliked foods:** hidden ("???" on the ticket until reveal; the order itself is generated from the revealed personality at `PLACE_ORDER`).
- **Combat behavior:** as revealed (the reveal happens before it could ever become hostile).
- **Mod affinity:** Chaotic (Aff ×1.7 · Joke ×2.5 · Hidden ×1.0) · favors JOKE, COUNT, SEQUENCE. The Mystery Mutant keeps this affinity for its order even after the reveal ("the mystery lingers").
- **Spending range:** as revealed. **Tip behavior:** revealed Tip× × 1.2 ("Mystery Bonus").
- **Unique animations:** sheet-wobble walk; the **Reveal** — the sheet is whipped away in a confetti burst, the revealed personality's signature parts pop on, and it strikes that personality's pose.
- **Dialogue:** Ordering (pre-reveal) — "? ?? ????" · Reveal — "Ta-daaa! Bet you didn't see THAT coming!" · Delighted — "Was it me you were expecting? No? Even better!" · Furious — the revealed personality's lines.
- **Special interactions:** *Reveal on first interaction* — when a player or waiter first seats it, takes its order or serves it, the server rolls a personality from the current tier's eligible pool (excluding PER_016, PER_027, PER_032; PER_025 is allowed — "It was the Inspector all along!"), sets `PersonalityId`, and plays the reveal. If never interacted with, it leaves unrevealed. A revealed Mystery Mutant that becomes a Regular stores its revealed personality.
- **Signature look:** `MUT_252` Ghost Sheet Cape with a "?" decal (pre-reveal only; removed at reveal, so it never grants `ABL_059`). **Tier band:** `TIER_06`+ (C 2 · D–E 3).

### 9.5 Variables

| Variable | Value [TUNABLE] | Notes |
|---|---|---|
| Effective P_offset clamp | [−20, +15] | after preference and hook adjustments |
| Preference adjustments | +5 recipe · +3 category · −8 disliked · −5 forced order | §9.2.2 |
| Influencer Post | ±0.1 ★ (−0.05 ★ below owner level 5); 2–4 followers within 60 s; 1 per 10 min | PER_009 |
| Critic's Star | average ≥ 4.5 ★ and S ≥ 90 → +0.05 ★; average < 2.0 → −0.05 ★ | PER_004 |
| Inspection | K_min ≥ 80 → +0.05 ★; K_min < 50 → −0.05 ★ | PER_025 |
| Mystery Bonus | Tip× × 1.2 | PER_032 |
| Hook chances | Seconds 30 % · Happy Prank 15 % · Nap 20 % (≤ 15 s) · Anniversary 5 % · Treasure Map 5 % | per visit |
| Remake window (Karenosaurus) | 60 s | |
| Quality gate (Picky Platypus) | Q < 0.60 = rejected | |
| Sing bonus (Birthday Beast) | P_offset +8, anger −15; +2 per extra singer, max +12 | |

### 9.6 UI

- **Personality glyph** on the ticket card and overhead widget (e.g. tiny T-Rex arms for PER_001, a stopwatch for
  PER_026), so the player recognises the personality even when the body is new. PER_032 shows "?".
- **Customer Codex** (journal tab): an entry unlocks the first time each personality is served; it shows the
  glyph, flavor line, "Likes / Dislikes" (category-level), patience hint (Short / Normal / Long), style icon and
  a hint for its special interaction. Hidden fields (exact numbers) stay hidden; `ABL_064` Super Sniff reveals
  the current customer's preferred recipe and pending hook (e.g. "Will post a review").
- **Special prompts** use the standard interaction prompt: "Sing!" (PER_031), "Manager!" ping (PER_001),
  buried-treasure sparkle (PER_017), pictogram hint timer (PER_019), the "From the Future" ticket badge (PER_024).
- Feed toasts: Influencer Posts, Critic reviews and Inspector results show as a newspaper-style card with icon,
  headline and ★ change text (never color alone).

### 9.7 Progression

| Tier # | New personalities | Total eligible |
|---|---|---|
| 1 | PER_001, PER_003, PER_005, PER_006, PER_012, PER_013, PER_014 | 7 |
| 2 | PER_002, PER_007, PER_009, PER_010, PER_015, PER_017, PER_018, PER_020, PER_021 | 16 |
| 3 | PER_004, PER_008, PER_011, PER_016, PER_019, PER_022, PER_023, PER_025, PER_027, PER_031 | 26 |
| 4 | PER_024, PER_026, PER_028 | 29 |
| 5 | PER_029, PER_030 | 31 |
| 6 | PER_032 | 32 |

Codex completion (all 32 served) is a natural achievement hook for §36.16.

### 9.8 Player Interactions

Reading the glyph and overhead cues · prioritising tickets by personality (Goblins and Squirrels first,
Sloths and Grandmas can wait) · plating for the Platypus · singing for the Birthday Beast · rushing the
Karenosaurus's remake · cleaning before an Inspector leaves · decoding the Mime's pictograms · substituting for
the Tortoise · keeping Polite Demons un-provoked (never throw near them) · using a Delighted Walrus or Pigeon as
an unpaid bouncer.

### 9.9 Dependencies

§6 (recipe list, categories, difficulty), §6.18 (modifications incl. heat/temperature mods), §7/§C9 (ingredient
tags used by hooks: `fried`, `spicy`), §8 (spawn, bodies, states), §10 (formulas), §11 (style AI), §36.6 (NPC
ability variants), §36.7 (status effects), §15 (light fixtures, décor, plating station), §16 (Security Guard,
Cashier), §20 (critic quest line reading `criticStars`), §24 (ticket cards, Codex), §26/§36.14 (animation
variants named here), §36.11 (event schedules that change weights).

### 9.10 Roblox Implementation

Personality data is a shared, read-only ModuleScript so clients can pick animations, glyphs and dialogue
locally; behavior hooks are server-only and dispatched by name.

```lua
--!strict
-- ReplicatedStorage/Shared/PersonalityDefs.lua (excerpt; generated from the §9.3 table)
export type PersonalityDef = {
	id: string, patience: number, pMult: number, pOffset: number,
	thresholds: { delighted: number, happy: number, meh: number, unhappy: number },
	angerP: number, sens: number, style: string, huff: number, def: number, dmgMult: number,
	modAffinity: { aff: number, jokeAff: number, hidAff: number, favored: { string } },
	items: { number }, gamma: number, tipMult: number, unlockTier: number,
	timing: { walk: number, menu: number, inspect: number, eat: number },
	signature: { string }, abilities: { { part: string, ability: string } }, hooks: { string },
}

local Defs: { [string]: PersonalityDef } = {
	PER_014 = {
		id = "PER_014", patience = 1.0, pMult = 0.90, pOffset = -5,
		thresholds = { delighted = 92, happy = 75, meh = 55, unhappy = 35 },
		angerP = 0.35, sens = 1.1, style = "THROWER", huff = 90,
		items = { 1, 2 }, gamma = 0, tipMult = 1.0, unlockTier = 1,
		timing = { walk = 1.0, menu = 1.5, inspect = 2.0, eat = 1.2 },
		signature = { "MUT_059", "MUT_218", "MUT_201" },
		def = 10, dmgMult = 1.0,
		modAffinity = { aff = 2.0, jokeAff = 0.5, hidAff = 1.0, favored = { "OMIT", "COUNT", "PRESENT" } },
		abilities = { { part = "MUT_053", ability = "ABL_028" }, { part = "MUT_010", ability = "ABL_034" },
			{ part = "MUT_162", ability = "ABL_041" } },
		hooks = { "AlwaysMod", "QualityGate", "PlatingBonus" },
	},
}
return table.freeze(Defs)
```

```lua
--!strict
-- ServerScriptService/CustomerAI/PersonalityHooks.lua : server-only behavior hooks
local Hooks = {}

Hooks.QualityGate = {
	onInspect = function(c, result) -- result from OrderService:ValidateServe
		if result.match and result.Q < 0.60 then result.match = false end -- treated as a wrong dish
	end,
}

function Hooks.pickSignatureMove(c, def, npcUse: (string, string) -> boolean): string?
	-- A5 extension: signature parts first, then §11.8.3 slot priority (performed by CombatService)
	for _, entry in def.abilities do
		if c.signatureParts[entry.part] and npcUse(entry.ability, def.style) then return entry.ability end
	end
	return nil -- CombatService falls back to the §11.8.3 slot-priority scan of the visible parts
end

function Hooks.dispatch(c, def, event: string, ...)
	for _, name in def.hooks do
		local h = Hooks[name]
		if h and h[event] then h[event](c, ...) end
	end
end

return Hooks
```

Kid-safety checklist for every dialogue line (§9.11): no insults about real groups or bodies, no real brands or
people, no threats of real harm (cartoon threats only: "TOAST BARRAGE!"), no romance beyond holding hands, and a
second-reviewer sign-off before localization.

### 9.11 Edge Cases

| # | Situation | Ruling |
|---|---|---|
| 1 | PER_024 requests a recipe but the owner has learned every recipe in range | It requests the highest-level learned recipe of that category instead, flagged "Paradox!" (A = 1 if served) |
| 2 | PER_031's cake (`RCP_DES_006`) is not on the menu | Any dessert on the menu replaces it; if no dessert exists, the party orders 1 item and "No Cake?!" never fires |
| 3 | PER_009's Post would push Stars above 5.0 or below 1.0 | Clamped to [1.0, 5.0] (§C3) |
| 4 | PER_032 reveals as a personality whose unlock tier exceeds the restaurant tier | Impossible: the pool is the current tier's eligible set |
| 5 | PER_016 or PER_027 rolled but no table fits the party | They queue; if the queue lacks room for the whole party → walk-by |
| 6 | PER_025 inspected while chaos is active | K_min freezes at chaos start (the inspector is hiding under a table) — chaos never auto-fails an inspection |
| 7 | PER_002's Free snack during level-6 chaos | Still counts as eating it (anger −5); the projectile is consumed and cannot hit anyone behind |
| 8 | PER_003 provoked by a co-op guest's accidental hit | Provoked regardless of who hit him; guest damage rules follow E12 |
| 9 | PER_019 order on a mobile screen too small for pictograms | Pictogram Hints is forced ON below 6-inch screens (text after 5 s) |
| 10 | Two Influencer Posts in the same 10 min | The second Post shows the toast but applies no ★ change and spawns no followers |
| 11 | PER_013's Calming Presence and a hostile neighbour | Aura still applies; it cannot drop a hostile customer's anger faster than its own decay rule allows (§10.6) |

### 9.12 Acceptance Criteria

- **AC-09-01:** §9.3 contains exactly 32 rows `PER_001`–`PER_032` with the §C11.1 names, and every row has all 14
  columns filled.
- **AC-09-02:** Every personality's Huff Points lie within 40–300 and every combat style is one of the 7 §C11.6
  styles (PER_032 inherits).
- **AC-09-03:** Every signature part and ability reference resolves to §C13.6 / §C12.2, each listed ability is the
  canon active of the listed part, and each is eligible for that personality's style in §36.6 "NPC use".
- **AC-09-04:** In 10,000 simulated spawns per personality, signature parts appear on 100 % of bodies and
  optional signatures within ± 2 percentage points of their stated chance.
- **AC-09-05:** A `PACIFIST` customer never deals damage in 1,000 simulated chaos events.
- **AC-09-06:** PER_001's tutorial variant plays the §32.3 beats (32 → 48 → 63 → 78) in order, reaches level 5 and
  never KOs the player in 200 scripted runs, and later Karenosauruses use only §9.3 values.
- **AC-09-07:** PER_009 with S ≥ 90 changes Stars by exactly +0.10 (clamped) and spawns 2–4 followers within
  60 s; a second Post within 10 min changes nothing.
- **AC-09-08:** PER_004's five category scores equal the formulas in §9.4 to the half-star, and a Critic's Star is
  awarded if and only if average ≥ 4.5 and S ≥ 90.
- **AC-09-09:** PER_019 tickets display no recipe text until Super Sniff, Eagle Eye or the 5 s hint fires.
- **AC-09-10:** PER_024 always requests an unlearned recipe with unlock level in (L, L + 10] when one exists in a
  served category, and any same-category substitute yields A = 0.8.
- **AC-09-11:** PER_025 applies +0.05 ★ when K_min ≥ 80 and −0.05 ★ when K_min < 50, and never enters a hostile
  state.
- **AC-09-12:** PER_032 is revealed within one tick of its first interaction, and all subsequent behavior uses the
  revealed personality's parameters with Tip× × 1.2.
- **AC-09-13:** PER_016 always spawns 3 minis on one ticket and PER_027 always 2 on one ticket.
- **AC-09-14:** Every personality has ≥ 3 approved lines in each of the ORDER, DELIGHT and FURIOUS pools at launch.

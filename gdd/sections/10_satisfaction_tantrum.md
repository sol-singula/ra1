## 10. Satisfaction and Tantrum Systems

> **Owner:** A5 Customers. Implements §C11.3 (satisfaction), §C11.4 (payment, tips, reputation) and §C11.5
> (anger levels), using personality parameters from §9.3 and customer states from §8.4. Fight AI per combat style
> belongs to §11; ability and status numbers to §36.6 / §36.7. Values marked **[TUNABLE]** are balancing
> assumptions.

### 10.1 Purpose

Every customer carries two independent meters:

| Meter | Range | When it changes | What it decides |
|---|---|---|---|
| **Satisfaction S** | 0–100 | computed per item at `EVALUATE`; final value at `PAY` | payment, tip, Jackpot, reputation, reaction emote, Regular loyalty |
| **Anger** | 0–100 | continuously, every 4 Hz tick | mood overlays, escalation rolls, hostile behavior, chain reactions, chaos |

They are coupled in one direction only: each evaluated item pushes anger up or down (§10.6). Anger never feeds
back into S — the canon formula stays pure, and a player who calms a tantrum and then serves a perfect plate is
paid for a perfect plate. Design goals: (1) the player can always tell *why* a customer is unhappy; (2) failure
is funny and recoverable, never ruinous; (3) one unhappy customer *can* start a brawl, but only through visible,
bounded chain reactions.

### 10.2 Rules & Mechanics — The Satisfaction Formula

The canon formula (§C11.3), applied **per delivered item i**:

```
S_base = 100 × (0.25·A + 0.20·Q + 0.15·C + 0.20·W + 0.10·K + 0.10·M)
S_i    = clamp( S_base × P_mult + P_offset_eff + MutationBonus(≤ +10) + EventModifier(−15..+15), 0, 100 )
S      = Σ_i (S_i × Price_i) / Σ_i Price_i          -- final, price-weighted over the whole ticket
```

Thresholds (defaults, shifted per personality, §9.3): **Delighted ≥ 90 · Happy 70–89 · Meh 50–69 · Unhappy
30–49 · Furious < 30.** Lower bounds are inclusive. Labels drive reactions and anger only; money and reputation
always use the raw number S.

**Undelivered items** (patience expired, §8.4.2) are scored A = Q = C = W = 0 with K and M measured at the moment
patience ends, so an abandoned item contributes at most `(0.10·K + 0.10·M) × 100 × P_mult + P_offset_eff`.

#### 10.2.1 A — order accuracy

A is computed by `OrderService` exactly as §6.18.4 specifies (owned by A2) and consumed here:

```
DishMatch = 0 → wrong dish: rejected at INSPECT_FOOD, never evaluated (anger +20 × sens, §10.6)
          = max(0.4, 1 − 0.15 × (missing non-core components + unrequested extras)) otherwise
ModScore  = (1 + Σ sat_j) / (1 + n)     sat_j = 1 satisfied · 0 failed · 0.5 COUNT near miss ·
                                          0.75 joke "Straight Answer" · 1 waived (station broke after ordering)
A_item    = DishMatch × ModScore
```

Accepted substitutes (PER_024) score A = 0.8. For a DONENESS modification, §6.18.4 also remaps C for the targeted
component (requested band 1.00, an ordinary PERFECT 0.80).

| Requested mods | Outcome | A (DishMatch 1) |
|---|---|---|
| 0 | — | 1.00 |
| 1 | failed | 0.50 |
| 1 | joke, Straight Answer | 0.875 |
| 2 | one failed | 0.667 |
| 3 | one near miss, one failed | 0.625 |

#### 10.2.2 Q — food quality

Per §C8: `Q = mean component score × assembly-order factor (1.0 / 0.85 / 0.7) × plating factor (1.0 plated;
0.9 un-plated at TIER_03+)`. Component scores: PERFECT 1.00 · GOOD 0.80 · OK 0.60 · UNDERCOOKED 0.35 · BURNED 0.15 ·
RUINED 0.00; components that need no processing score 1.00 unless SPILLED (0.00) or MUSHY (0.35). Chopped
components use the chop rhythm average (§C8).

#### 10.2.3 C — cooking accuracy

`C = mean doneness score of the heat-cooked components` (GRILL, FRY, BAKE, SAUTE, BOIL, STEAM, FLOAT, INFUSE) using
the same grade values; ON_FIRE components count as RUINED (0.00). Items finished with `ABL_066` Microwave Zap-Cook
count as GOOD. **Dishes with no heat-cooked component score C = 1.00** — cold dishes are judged through Q.

#### 10.2.4 W — wait factor

`t_i` = item placement time − ticket creation time; `P` = patience (§C11.2).
`W = 1` if `t_i ≤ 0.5·P`, else `W = max(0, 2 − 2·t_i / P)`.

| t / P | ≤ 50 % | 60 % | 75 % | 90 % | 100 % |
|---|---|---|---|---|---|
| W | 1.00 | 0.80 | 0.50 | 0.20 | 0.00 |

Patience pauses (chaos, restaurant-caused `CONFUSED`, PER_006 naps, hostile states) stop `t_i` as well.

#### 10.2.5 K — cleanliness

K is the dining-room cleanliness (0–100) sampled at `EVALUATE`, computed per customer:

```
K = clamp(100 − Σ_mess Points(mess) × (1.5 if within 12 studs of the customer else 1.0), 0, 100)
```

| Mess (dining area only) | Points each | Category cap |
|---|---|---|
| Trash piece (dropped garnish, wrapper, leftover debris that persists) | 3 | 30 |
| Spill / sauce splat (thrown food that landed, dropped plate, Gremlin prank) | 4 | 32 |
| Dirty table (not bussed 20 s after its customers left) | 2 | 12 |
| Cracked object (durability 50–26 %) | 1 | 10 |
| Broken object (25–1 %) | 5 | 30 (shared with rubble) |
| Destroyed rubble pile (0 %) | 8 | (shared) |
| Smoke from a station `ON_FIRE` | 10 | 10 |

Messes persist until cleaned (§5 CLEAN; `ROLE_CLEANER`; `ABL_068` Web Sweep). This is the bridge from chaos to
money: every food fight leaves splats that quietly lower K for everyone still eating.

#### 10.2.6 M — atmosphere

`M = Atmosphere / 100`, the restaurant's décor score from §15 (damaged décor counts at its §15 reduced value),
sampled at `EVALUATE`. The same Atmosphere drives DecorMult (§C11.4).

### 10.3 Rules & Mechanics — Personality, Mutation and Event Modifiers

**Personality.** `P_mult` and the effective `P_offset` come from §9.3/§9.4: base offset + preference
adjustment (+5 preferred recipe, +3 preferred category, −8 disliked, −5 forced order) + the personality's dynamic
hooks (e.g. PER_008 Perfectionist −10, PER_031 Sing +8), clamped to [−20, +15].

**MutationBonus** (≤ +10 total per item; evaluated on the deliverer — the player or employee who delivered it):

| Source | Part | Bonus | Condition |
|---|---|---|---|
| Charm-tagged parts | any | +1 each, max +4 | equipped parts carrying the `charm` tag (§C13.5) |
| Mustache of Destiny | `MUT_047` | +2 | "dashing service" (stacks with its charm tag) |
| Chef Hat Crest | `MUT_102` | +1 | looks professional |
| Sparkle Aura | `MUT_272` | +1 | |
| Nine Fox Tails | `MUT_229` | +2 | |
| Golden Burger Head | `MUT_039` | +3 | |
| Golden Skin | `MUT_258` | +2 | customer is PER_008 |
| TV Head | `MUT_021` | +2 | customer is PER_009 ("on camera") |
| Family Resemblance | any | +2 | deliverer wears a part of the same family as the customer's HEAD |
| Mutation Cuisine "Whoa!" | — | +10 | the item is a MUT recipe (§C10) |
| §12 part passives | as defined in §12 | as defined | add into this same pool; the +10 cap always holds |

**EventModifier** (sum of active events, clamped to −15..+15 per §C11.3 and §36.11). Event schedules and rules are
owned by §36.11; where §36.11 states an EventModifier (marked **§36.11**) that value is repeated here, the other
values are A5's satisfaction effects. Unlisted events give 0 — including `EVT_003`, `EVT_004`, `EVT_008` and
`EVT_026`, whose challenge comes from their own rules (extra demand, invaders, critics, inspections).

| Event | ID | Modifier |
|---|---|---|
| Giant Food Festival | `EVT_001` | +3 all items (festive mood) |
| Legendary Chef Tournament | `EVT_005` | +5 LEG items |
| Mutation Meteor Shower | `EVT_006` | +10 MUT items and items with the `mutagen` tag |
| Blackout Night | `EVT_009` | +5 all items — candlelit dining (**§36.11**, which also grants Atmosphere +10) |
| Upside-Down Day | `EVT_011` | +5 `RCP_BRG_013`, `RCP_BRK_005`, `RCP_PIZ_012` and items carrying an upside-down modification |
| Pickle Rain | `EVT_012` | +5 items with the `pickle` tag |
| Sewer Flood | `EVT_013` | −3 all items (soggy socks) |
| Celebrity Chef Visit | `EVT_014` | +3 all items (star-struck diners) |
| Polite Robot Uprising | `EVT_017` | +5 for customers whose HEAD or TORSO is ROBOT category |
| Alien Tourist Season | `EVT_018` | +5 ALN items |
| Hot Sauce Heatwave | `EVT_019` | +5 `spicy` items served together with a drink (**§36.11**) |
| Frozen Snap | `EVT_020` | +5 SOP items, `RCP_DRK_007` and `RCP_DRK_010`; −5 `frozen` items |
| Neon Lights Festival | `EVT_028` | +5 all items |
| Haunted Kitchen Night | `EVT_029` | +5 spooky-themed items, e.g. `RCP_SOP_006`, `RCP_SOP_005`, `RCP_PIZ_006` (**§36.11**) |
| Snowmorph Holiday | `EVT_030` | +5 SOP items and hot drinks |
| Spring Sprout Bloom | `EVT_031` | +5 SAL items |
| Bug Swarm Brunch | `EVT_032` | +5 items with the `bug` tag |

### 10.4 Worked Satisfaction Examples

Recipe prices and difficulties below are illustrative (§6 is authoritative); every formula is exact.

**Example 1 — Grandma Golem (PER_013), `TIER_01`, one Cheeseburger (10 MB, D 1), CHARM 10.**
- Patience = (70 + 0 + 5·1) × 1.4 × 1.04 = **109.2 s**. Served at 70 s → t/P = 0.641 → W = 2 − 1.282 = **0.718**.
- Patty GOOD (0.80), bun and cheese 1.00 → Q = **0.933** (no plating penalty below `TIER_03`); C = **0.80**; A = **1.00**.
- K = 92 (two spills across the room), M = 30 (shack décor).
- S_base = 100 × (0.25 + 0.1867 + 0.120 + 0.1436 + 0.092 + 0.030) = **82.23**.
- P_offset_eff = +5 base + 5 (Cheeseburger is a preferred recipe) = +10; MutationBonus +1 (server wears `MUT_002`
  Cat Head, `charm` tag); no event.
- S = 82.23 × 1.05 + 10 + 1 = **97.34** → Delighted (her threshold 85). Pay 10 MB; TipRate 18 % → tip = 10 × 0.18 ×
  1.5 = 2.7 → **3 MB**. Stars 2.50 → 2.50 + 0.02 × (4.867 − 2.50) = **2.547 ★**.

**Example 2 — Karenosaurus (PER_001), `TIER_04`, Bacon Monster Burger (15 MB, D 3, one modification) + Fizzy Soda
(6 MB, D 1), CHARM 20.**
- Patience = (70 + 20 + 5·4) × 0.85 × 1.08 = **100.98 s**. Soda at 30 s (W 1.0); burger at 75.7 s (75 %, **W 0.50**)
  with the modification missed (**A 0.50**), Q 0.88, C 1.00. K 85, M 55.
- Burger: S_base = 100 × (0.125 + 0.176 + 0.150 + 0.100 + 0.085 + 0.055) = 69.10; P_offset_eff = −5 + 3 (BRG is a
  preferred category) = −2 → S_burger = 69.10 × 0.85 − 2 = **56.74**.
- Soda: S_base = 94.00 → S_soda = 94.00 × 0.85 − 5 = **74.90**.
- S = (56.74 × 15 + 74.90 × 6) / 21 = **61.93** → "Meh" by her bands (60–79). Pay 21 MB (S ≥ 50), tip 0.
  Stars 3.20 → **3.198 ★**.
- *Take it back!* (§9.4) lets the cook remake the burger within 60 s; the remake keeps the original W (0.50) and,
  with A = 1.00, scores 81.60 × 0.85 − 2 = 67.36 → S = **69.51** (and the burger now earns its §6.18.5 modification
  bonus). Still under 70: no tip. The Karenosaurus is hard to please, by design.
- Anger along the way: 25.2 s of patience pressure (50–75 %) at 0.6 × 1.3 /s = **19.7**; failed modification
  ("Wrong Order?!") +5 × 1.3 = **26.2**; Unhappy evaluation +18 × 1.3 × 15/21 = **42.9** → level 2, Complaining, and
  the "Manager!" ping. One more insult — a splash from a nearby food fight (+6 × 1.3) — would cross 45 and trigger an
  escalation roll of p = 0.45 × 100/120 = **37.5 %** (§10.7).

**Example 3 — Rich Mutant (PER_008), `TIER_07`, three premium items (ΣD 9, ticket 412 MB), CHARM 60, LUCK 40, during
`EVT_028` Neon Lights Festival.**
- Patience = (70 + 40 + 45) × 0.9 × 1.24 = **172.98 s**; all items by 70 s (40 %) → W = 1.00.
- A 1.00, Q 0.97, C 0.95, K 96, M 88 → S_base = **97.05**. No preference matches → P_offset_eff 0.
- MutationBonus +4 (`MUT_047` Mustache of Destiny +2 and its `charm` tag +1, plus one other charm part +1); Event +5.
- S = 97.05 × 0.90 + 0 + 4 + 5 = **96.35** → Delighted (his bar is 96). TipRate 18 % → tip = 412 × 0.18 × 2.5 =
  **185 MB**. Jackpot chance = (0.5 % + 0.1 % × 40) × 2 (Rich Mutant) = **9 %** → on a hit, tip ×5 = **927 MB**
  (cap 5,000 at `TIER_05`+). Stars 4.40 → **4.408 ★**.

**Example 4 — Food Critic (PER_004), `TIER_05`, Lasagna Tower (31 MB, D 3) + Bubble Tea (9 MB, D 2), CHARM 35.**
- Patience = (70 + 20 + 5·5) × 1.0 × 1.14 = **131.1 s**; drink at 39.3 s, main at 59.0 s → W = 1.00 for both.
- Main: A 1.00, Q 0.92, C 0.90, K 90, M 72 → S_base 93.10; preferred recipe +5; MutationBonus +2 →
  S_main = 93.10 × 0.90 + 5 + 2 = **90.79**. Drink: S_base 96.20 → 96.20 × 0.90 + 2 = **88.58**.
- S = (90.79 × 31 + 88.58 × 9) / 40 = **90.29** → "Happy" by her bands; TipRate 18 % → **7 MB**.
- Review: Taste 5 × 0.938 = 4.69 → **4.5 ★**; Technique 5 × 0.9225 → **4.5 ★**; Accuracy **5 ★**; Speed **5 ★**;
  Ambience 5 × (90 + 72)/200 = 4.05 → **4.0 ★**. Average **4.6** ≥ 4.5 and S ≥ 90 → **Critic's Star**: Stars 3.80 →
  3.814 (base update) + 0.05 = **3.864 ★**.

**Example 5 — Mystery Mutant revealed as Spicy Salamander (PER_032 → PER_022), `TIER_06`, Mutagen Meatballs (60 MB,
D 4) during `EVT_006` Mutation Meteor Shower, after a food fight; CHARM 50.**
- Patience = (70 + 20) × 1.0 × 1.20 = **108 s**; served at 86.4 s (80 %) → W = **0.40**.
- A 1.00, Q 0.84, C 0.80, K 70 (six splats), M 60 → S_base = **74.80**.
- P_offset_eff −5 (not spicy, Salamander hook); MutationBonus +10 (Mutation Cuisine "Whoa!" fills the cap, so the
  server's charm parts add nothing more); Event +10 (MUT item).
- S = 74.80 − 5 + 10 + 10 = **89.80** → Happy, TipRate 10 % → tip = 60 × 0.10 × (1.0 × 1.2 Mystery Bonus) = **7 MB**.
  Cleaning up the splats (K 70 → 100) would have added 3 points and crossed 90 (18 % tip). Stars 3.00 → **3.030 ★**.

### 10.5 Rules & Mechanics — Payment, Tips and Reputation

**Payment** (§C11.4 with the §6.18.5 modification bonus): `Pay = Σ_i round(Price_i × (1 + ModBonusPct_i)) × PayFactor`,
where `ModBonusPct_i` is the capped sum of the pay bonuses of item i's satisfied modifications (§6.18.5), and PayFactor **1.0** if S ≥ 50, **0.8** if 30 ≤ S < 50,
and **0.6** if S < 30 for a customer who stays to pay (canon is silent on this case; [TUNABLE]). Only delivered
items are charged. Rounding is half-up to whole MB.

**Tip:** `Tip = round(Σ Price_i × (TipRate(S) + CashierBonus) × TipMult)` where TipRate(S) = 0 (S < 70), 5 %
(70–79), 10 % (80–89), 18 % (90–97), 25 % (98–100, "Chef's Kiss"); CashierBonus = +1 % per 20 Cashier skill (§C14.1)
and applies only when TipRate(S) > 0; TipMult = personality Tip× (+0.10 for a Loyal Regular, ×1.2 for PER_032). A
positive tip is at least 1 MB.

**Jackpot Tip:** on S ≥ 90, chance `0.5 % + 0.1 % × LUCK` (LUCK of the delivering player, else the owner's) for tip
×5, capped at 500 MB below `TIER_05` and 5,000 MB at `TIER_05` and above. PER_008 and PER_017 double the chance;
PER_015 never Jackpots.

**Reputation:** after each customer, `Stars += 0.02 × (S_rep / 20 − Stars)`, then the outcome's extra change,
then personality hooks (PER_004, PER_009, PER_025), clamped to [1.0, 5.0]. `RepMult = 0.5 + 0.25 × Stars`.

| Outcome | Pay | Tip | S_rep | Extra ★ |
|---|---|---|---|---|
| Normal visit | per S | per S | S | — |
| Hostile, calmed **without** combat (Calm Down!, Peace Offering, aura) | per S | per S | S | — |
| Hostile, calmed **by** combat (Huff 0, Security intercept, or took damage this episode) | 40 % Apology Payment | 0 | min(S, 40); 30 if never evaluated | — |
| Storm-out (fallback leave, ordering or patience expiry with nothing delivered, KO'd a player) | 0 | 0 | 20 [TUNABLE] | −0.03 |
| Fled during chaos (the Nervous Newt pays eaten items) | 0 | 0 | not counted | — |
| Walk-by (never entered) | — | — | not counted | — |
| Closed (E1, E13, Away Mode) | 0 | 0 | not counted | — |

**More examples.**
- *Apology Payment:* a Bodybuilder Pigeon (ticket 15 + 12 MB) is beaten to Huff 0 before being served: pays
  round(27 × 0.4) = **11 MB**, no tip; S_rep 30 → Stars 3.00 → **2.970 ★**.
- *Storm-out:* an Impatient Goblin's patience expires with nothing delivered at 2.80 ★: pays 0; 2.80 + 0.02 × (1 −
  2.80) = 2.764, then −0.03 → **2.734 ★**.
- *Jackpot cap:* at `TIER_04` a 120 MB tip hits the Jackpot: ×5 = 600 → capped at **500 MB**.

### 10.6 Rules & Mechanics — The Anger Meter

Anger is a float 0–100 per customer, updated every 4 Hz brain tick. Levels follow §C11.5: **0 Happy** (0–14) ·
**1 Annoyed** (15–29) · **2 Complaining** (30–44) · **3 Throwing food** (45–59) · **4 Destroying furniture**
(60–74) · **5 Fighting** (75–89) · **6 Restaurant-wide chaos** (90–100, only during chaos, §10.9). Outside chaos the
meter is clamped at 89. Every **gain** is multiplied by the personality sensitivity (§9.3); decay never is.
Amounts that originate in combat rules are restated from §11 so both sections agree.

**Continuous gains (per second)**

| Source | Rate × sens [TUNABLE] | Condition |
|---|---|---|
| Patience pressure | +0.6 /s from 50 % to 75 % of patience; +1.0 /s from 75 % to 100 % | `WAIT` with items pending |
| Ordering pressure | +0.5 /s after 50 % of the ordering window; +1.0 /s in the last-chance window | `PLACE_ORDER` |
| Long seat wait | +0.5 /s after 10 s unseated at the podium (table service) or un-served in the counter line | `REQUEST_SEAT` |
| Dirty room | +0.005 × max(0, 60 − K) /s (K 40 → +0.10 /s; K 0 → +0.30 /s) | any Core state |
| Fire | +0.3 /s | a station `ON_FIRE` within 30 studs (PER_022 is exempt) |
| Complaining aura | +0.15 /s | a level-2 customer within 6 studs |
| Tantrum aura | +0.4 /s (the strongest single tantrum aura only) | a level ≥ 3 customer within 12 studs |
| Mob aura | +0.3 /s | inside a mob cluster (§10.8) |
| Rumor Mill | +0.3 /s | PER_011 complaining within 8 studs |

All aura-type gains together (complaining, tantrum, mob, rumor) are capped at **+2.0 /s** per customer before
sensitivity, so a crowded room escalates quickly but never instantly.

**One-off gains**

| Event | Amount × sens | Defined in |
|---|---|---|
| Wrong dish (rejected at inspect) | +20 | §8.4.2 |
| Burned or ruined component | +12 (once per item) | A5 |
| Undercooked component | +8 | A5 |
| Each failed non-joke modification — the "Wrong Order?!" reaction (COUNT near miss +2.5; joke mods never add anger) | +5 | §6.18.4, A5 |
| MUSHY or SPILLED component | +6 | A5 |
| *Per-item defect cap* | *+30* | A5 |
| Evaluation label × item price share | Delighted −25 · Happy −12 · Meh +6 · Unhappy +18 · Furious +32 (negative values are not × sens; PER_018 ×1.5 both ways) | A5 |
| Hit by a thrown object of any kind, from anyone | +25 | §C11.5, §11.2.2 |
| Splash: within 4 studs of a food impact but not hit | +6 | A5 |
| Player melee or area contact while not hostile (0 damage, 0.3 s flinch) | +8 | §11.2.2 |
| `PACIFIST` hit by anything (cries and flees 8 studs) | +10 extra | §11.8.2 |
| Watching a scuffle hit within 10 studs | +3 per hit | §11.6.4 |
| Instigator Yell (12 studs; the Influencer 20 studs) | +4 every 2 s, max +20 per customer per yelling session | §11.8.2 |
| INSTIGATOR Bat Screech / Mind Buzz (NPC versions) | +10 to each affected customer | §36.6 (`ABL_023`, `ABL_047`) |
| Plate stolen from its table (theft, food grab, tractor beam) | +15 | §11.6.4 |
| A table within 6 studs flipped / its own table flipped | +10 / +25 | A5 (flip execution §11.6.3) |
| Its seat or table becomes Broken under it | +15 | A5 |
| Its reserved seat taken | +10 | A5 |
| Personality hooks (Karenosaurus ignored "Manager!" +10, Sloth-Rocket woken +10, Newt startle +15, Birthday Beast "No Cake?!" +20) | as listed | §9.4 |
| Regular with a grudge | starts at 15 × Grudge | §8.12 |

**Decay and resets**

| Rule | Value [TUNABLE] |
|---|---|
| Calm decay | −0.5 /s at levels 0–2 once no gain has applied for 5 s |
| Eating | −1.0 /s at levels 0–2 while in `EAT` (replaces calm decay) |
| Hostile fatigue | −0.2 /s at levels 3–4 once the customer has not been hit for 5 s; level 5 does not tire (resolved by combat or talk-down) |
| Chill effects | Chill décor scales gains (§10.10); chill auras add decay; total decay capped at 3.0 /s |
| Sheepish | for 30 s after calming: all gains ×0.5 and escalation rolls ×0.5 |
| Perfect Recovery | finishing the whole order Perfect (every item A = 1, Q ≥ 0.95, C ≥ 0.95) at level ≤ 2 → anger 0 (§C11.5) |

**Tick order:** queued one-off events → continuous gains → decay → clamp → threshold crossings in ascending order
with escalation rolls (§10.7) → level-6 gate → replicate `Anger`/`AngerLevel` (§8.18).

### 10.7 Rules & Mechanics — Escalation Rolls and Behavior by Level

#### 10.7.1 The escalation roll

Crossing into levels 3, 4 and 5 requires a roll (§C11.5):

```
p = clamp( AngerP × 100 / (100 + CHARM) × EventMul + Adds − EscalationDampener , 0 , 0.95 ) × Dampers
CHARM              = highest effective CHARM among players inside the interior
EventMul           = 1.5 during EVT_004 (§36.11), else 1.0
EscalationDampener = calm décor/security subtraction from §15 (e.g. FRN_214 Soothing Seafoam Paint 0.05;
                     sum capped at 0.15; 0 by default)
Adds               = +0.10 in a mob · +0.10 retaliation (hit by a thrown object or attack in the last 10 s)
                     · +0.15 while chaos is active
Dampers            = ×0.5 each for Sheepish, Rough Patch and Bad-Luck Breaker (§10.11); ×0.75 on a 2nd attempt
```

- **Forced results:** PER_010 after a thrown-object hit (success); PER_003 when provoked uses AngerP 0.90; the
  QST_TUT_006/007 beats bypass rolls (§32).
- **Deferred (no roll spent):** when the hostile cap (level 3), the fighter cap (level 5) or new-player protection
  (level 5, owner below level 5) blocks the crossing, anger is held at threshold − 1 and the customer keeps its
  current behavior until a slot frees — the same "deferred" rule §11.7 uses for its absolute caps.
- **Failure:** anger is held at threshold − 1 (44 / 59 / 74), the customer draws a fallback reaction (table
  below), and that threshold's attempt counter increases. After 2 failures at the same threshold, the next crossing
  automatically picks **Leave** (a storm-out) — nobody sulks forever.
- **`PACIFIST` success** lets the meter cross, but the customer only uses the pacifist rows below.

| Fallback after a failed roll | Sulk | Complain | Leave |
|---|---|---|---|
| `PACIFIST` | 30 % | 30 % (cries dramatically) | 40 % |
| `THROWER` | 30 % | 50 % | 20 % |
| `BRAWLER` | 35 % | 45 % | 20 % |
| `CHARGER` | 40 % | 35 % | 25 % |
| `TANK` | 55 % | 35 % | 10 % |
| `TRICKSTER` | 25 % | 45 % | 30 % |
| `INSTIGATOR` | 10 % | 80 % | 10 % |

*Sulk* = arms crossed for 12 s with anger frozen, then decay at double rate for 10 s. *Complain* = `ANM_047` for
6 s with its complaining aura doubled. *Leave* = storm-out (pay 0, §10.5).

#### 10.7.2 Behavior per level

| Level | State / overlay | What the customer does | Hostile flag (§11.2.1) |
|---|---|---|---|
| 0 Happy | — | normal service; happy idles and emotes | no |
| 1 Annoyed | `IMPATIENT` | `ANM_046` foot tap, grumble bubbles; no mechanical effect | no |
| 2 Complaining | `COMPLAINING` | `ANM_047`; complaining aura; PER_001 "Manager!", PER_018 faint, PER_028 poltergeist | no |
| 3 Throwing food | `ANGRY` | draws a mode each ModeTick from the level-3 table; throws follow the §11.2.1 cadence and §11.6.2 arcs | for 6 s after throwing at a player, and in scuffles |
| 4 Destroying furniture | `ENRAGED` | level-4 table; smashing and flips per §11.6.3 | yes |
| 5 Fighting the player | `FIGHTING` | the §11.8 style AI, Signature Move (§9.2.3), Huff Points | yes |
| 6 Restaurant-wide chaos | `FIGHTING` (Ringleader) + restaurant chaos | §10.9 | every customer at level ≥ 3 |

**ModeTick:** a mode is drawn on entering a level and every 6 s while there (4 s for `THROWER` and `TRICKSTER`);
the mode runs, executed by §11, until the next draw. *Special* = the style's own trick from §11.8.2 (`TRICKSTER`:
plate theft or condiment debuff; `INSTIGATOR`: climb a chair and Yell). *Fight* is only possible at level 5.

| Level 3 mode draw | Sulk | Complain | Leave | Throw | Break | Fight | Special |
|---|---|---|---|---|---|---|---|
| `PACIFIST` | 40 % | 35 % | 25 % | — | — | — | — |
| `THROWER` | 5 % | 10 % | 0 % | 85 % | 0 % | — | 0 % |
| `BRAWLER` | 10 % | 25 % | 0 % | 65 % | 0 % | — | 0 % |
| `CHARGER` | 15 % | 25 % | 0 % | 60 % | 0 % | — | 0 % |
| `TANK` | 25 % | 25 % | 0 % | 50 % | 0 % | — | 0 % |
| `TRICKSTER` | 10 % | 15 % | 0 % | 50 % | 0 % | — | 25 % |
| `INSTIGATOR` | 5 % | 20 % | 0 % | 25 % | 0 % | — | 50 % |

| Level 4 mode draw | Sulk | Complain | Leave | Throw | Break | Fight | Special |
|---|---|---|---|---|---|---|---|
| `PACIFIST` | 25 % | 35 % | 40 % | — | — | — | — |
| `THROWER` | 0 % | 5 % | 0 % | 60 % | 35 % | — | 0 % |
| `BRAWLER` | 0 % | 10 % | 0 % | 30 % | 60 % | — | 0 % |
| `CHARGER` | 0 % | 5 % | 0 % | 15 % | 80 % | — | 0 % |
| `TANK` | 5 % | 5 % | 0 % | 20 % | 70 % | — | 0 % |
| `TRICKSTER` | 0 % | 5 % | 0 % | 30 % | 30 % | — | 35 % |
| `INSTIGATOR` | 0 % | 15 % | 0 % | 20 % | 25 % | — | 40 % |

| Level 5 mode draw | Sulk | Complain | Leave | Throw | Break | Fight | Special |
|---|---|---|---|---|---|---|---|
| `PACIFIST` | 0 % | 30 % | 70 % | — | — | — | — |
| `THROWER` | 0 % | 0 % | 0 % | 15 % | 10 % | 75 % | 0 % |
| `BRAWLER` | 0 % | 0 % | 0 % | 5 % | 10 % | 85 % | 0 % |
| `CHARGER` | 0 % | 0 % | 0 % | 0 % | 20 % | 80 % | 0 % |
| `TANK` | 0 % | 0 % | 0 % | 5 % | 15 % | 80 % | 0 % |
| `TRICKSTER` | 0 % | 0 % | 0 % | 10 % | 10 % | 50 % | 30 % |
| `INSTIGATOR` | 0 % | 10 % | 0 % | 10 % | 10 % | 30 % | 40 % |

### 10.8 Rules & Mechanics — Chain Reactions (Emergent Chaos)

A brawl is never scripted; it emerges from these rules, each of which is visible and bounded.

1. **Thrown-food arcs.** Every throw is a scripted arc (§11.6.2: launch 45 studs/s, fake gravity 60 studs/s², apex
   ≤ 6 studs, 0.5 s telegraph with a landing reticle). A dodged, phased or missed projectile **keeps flying** and
   hits whoever is next on its path. A direct hit on a customer applies +25 × sens; the impact point spawns a splat
   (K −4) and splashes everyone within **4 studs** (+6 × sens).
2. **Bystanders fight back.** A hit customer records the thrower as its grievance target and gets the +0.10
   retaliation add for 10 s. If it then passes a level-3 roll it starts a **scuffle** with the thrower even below
   level 5 (§11.6.4), and every scuffle hit adds +3 to customers within 10 studs ("Ooh, a fight!").
3. **Mob mentality.** When ≥ 3 customers at level ≥ 2 stand within 15 studs of one another (single-link cluster,
   computed on a 15-stud spatial hash every tick), they form a **mob**: every customer within 15 studs of any
   member gains +0.3 /s and +0.10 on escalation rolls. A mob dissolves when fewer than 3 members remain at level ≥ 2.
4. **Furniture knock-ons.** Smashes, flips, charges and wall splats damage objects per §11.6.3. Their anger effects
   are A5's: a table flipped within 6 studs +10 × sens, one's own table flipped +25 × sens (dish handling §8.5),
   a seat turning Broken under someone +15 × sens. Spilled plates become splats (K).
5. **Chain depth limit.** Each anger event carries a `chainDepth`: 0 for a direct cause (bad food, waiting, a
   player's throw); an event produced by a customer whose hostility came from a depth-d event carries d + 1.
   Escalation rolls triggered by events of depth ≥ 3 automatically fail (fallback). Cascades therefore stop after
   three links unless the player keeps feeding them.
6. **Caps** (escalations beyond a cap are deferred, §10.7.1). §11.7's absolute limit of 6 fighting customers
   (8 during chaos) is never exceeded.

| Tier | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Max customers at level ≥ 3 | 2 | 3 | 3 | 3 | 4 | 4 | 5 | 5 | 6 | 6 |
| Max customers at level 5 | 1 | 1 | 2 | 2 | 2 | 2 | 3 | 3 | 3 | 3 |
| During chaos (each +2, absolute max 8 fighters) | 4 / 3 | 5 / 3 | 5 / 4 | 5 / 4 | 6 / 4 | 6 / 4 | 7 / 5 | 7 / 5 | 8 / 5 | 8 / 5 |

7. **New-player protection.** While the owner is below level 5 (the scripted tutorial excepted): no customer may
   reach level 5, chaos cannot ignite, the level-3 cap is min(tier cap, 2) and the damage budget (§10.11) is
   halved. Escalation still reaches level 4 — tantrums stay memorable.

**Worked chain reaction** (`TIER_04`, owner level 20, CHARM 20 → charm factor 100/120 = 0.833):

| t (s) | What happens | Numbers | Rule |
|---|---|---|---|
| 0.0 | A Picky Platypus (anger 47, level 3) draws Throw and lobs her fries at the player | `THROWER` level 3: Throw 85 % | §10.7.2 |
| 0.5 | The player dodges; the fries keep flying and hit a Bodybuilder Pigeon (anger 12) | +25 × 1.6 = **+40 → 52** | rule 1 |
| 0.5 | The Pigeon crosses 45: *Easily Offended* forces success → `ANGRY`, grievance = Platypus | forced roll | §9.4, §10.7.1 |
| 0.5 | Splash 3 studs from a Grandma Golem (anger 5): +6 × 0.5 → 8. A Nervous Newt startles: +15 × 1.5 → 32.5 | level 2 for the Newt | rule 1, §9.4 |
| 1.5 | The Pigeon throws his burger back and hits the Platypus | +25 × 1.1 = 27.5 → **74.5** → crosses 60: p = 0.35 × 0.833 + 0.10 = **0.39** → passes → `ENRAGED` | rule 2 |
| 2.0 | The burger lands: a splat (K −4 room-wide, −6 within 12 studs) | | §10.2.5 |
| 4.0 | The Platypus draws Break (35 %) and smashes her table; its plates spill (two more splats) | §11.6.3 values | §10.7.2 |
| 4.0 | The Newt's table is 5 studs away: +10 × 1.5 → 47.5 → crosses 45: p = 0.05 × 0.833 = 0.04 → fails → fallback draws Leave | storm-out: pays 0, Stars −0.06 | §10.5 |
| 6.0 | The player uses Calm Down! on the Pigeon: −(20 + 0.1 × 20) = −22 → 30 → `CALMING_DOWN`, Sheepish | §36.6 | §10.10 |
| 8.0 | A free Strawberry Smoothie (Peace Offering) to the Platypus: −35 → 39.5 → `CALMING_DOWN`, Sheepish | | §10.10 |
| after | One storm-out, three splats to mop, one table to repair; both calmed customers will still pay by S | | §10.11 |

Only two customers ever reached level 3, so chaos never ignited — with one more angry diner it would have.

### 10.9 Rules & Mechanics — Level 6: Restaurant-wide Chaos

- **Ignition:** (a) ≥ 3 customers at level ≥ 3 on two consecutive brain ticks (0.5 s; §11.6.4-6); or (b) a
  chaos command from an event (§36.11). Never while the owner is below level 5, while the restaurant is `Closing`,
  or within the **3-minute chaos cooldown** after the previous chaos ended.
- **On ignition:** the hostile with the highest anger becomes the **Ringleader** (anger set to ≥ 90, crown glyph);
  every other customer at level ≥ 3 gains +10 (rolls apply, with the +0.15 chaos add); every customer at level ≤ 2
  rolls a chaos reaction — `PACIFIST`: 60 % flee / 40 % hide; others: 45 % flee / 35 % hide / 20 % join (anger set to
  45 without a roll if the chaos cap allows, otherwise hide). Hiding customers crouch under the nearest table,
  ignore auras and are untargetable.
- **During chaos (max 45 s):** arrivals are held, the outside queue and every patience clock pause, caps rise per
  §10.8, the 89 clamp is lifted, the "CHAOS!" banner and music sting play (§11.2.1, §26). A KO'd player's KO'er
  stays in the fight (§C12.1).
- **Chaos Meter:** `CM = 100 × Σ_hostile max(0, anger − 44) / CM₀`, where CM₀ is that sum at ignition (joins add to
  CM₀). It falls as hostiles are calmed, talked down, defeated or leave. Calming or defeating the Ringleader first
  removes 25 points at once and gives every hostile −10 anger ("Without a leader, the mob loses steam").
- **Resolution:** *Resolved* when fewer than 2 customers remain at level ≥ 3 for 8 consecutive seconds
  (§11.6.4-6) → **"BRAWL SURVIVED!"**; the last hostile, if any, continues as a normal hostile. *Fizzled* at 45 s →
  every remaining hostile storms out (pay 0; the chaos's total extra reputation loss is capped at −0.10 ★); hiding
  customers resume with patience restored to at least 50 %. *Closed* if the owner disconnects (E1): no reward and no
  reputation loss.
- **"Brawl Survived" reward:** XP `round(0.03 × XPRate(L))` to each participating player (dealt or blocked damage,
  calmed or talked down a customer, or was targeted) — 62 XP at level 20 — and MB `round(0.02 × NetMB/h[tier])` (§C4.4)
  to the owner: 13 MB at `TIER_01`, 35 MB at `TIER_03`, 192 MB at `TIER_06`, 2,410 MB at `TIER_10`. Guests follow §21.
  **Anti-farm:** no reward if ≥ 50 % of the anger that carried the hostiles past 45 came from player-caused sources
  (player-thrown objects, player contact), and at most one reward per restaurant per 15 min.
- **Afterwards:** the 3-minute cooldown starts; "Calm Afterglow" halves anger gains for the next 5 arrivals;
  Aftermath (Furniture Homing, repair markers) runs per §11.6.3.

### 10.10 Rules & Mechanics — De-escalation and Recovery

| Method | Effect | Defined in |
|---|---|---|
| Calm Down! | anger −(20 + 0.1 × CHARM), max −35; at level ≤ 4 drops at least one level; at level 5 works only on a Winded or ≤ 50 % Huff customer (`TRICKSTER` ≤ 25 %) and then **talks it down** to level 2; ×2 against `INSTIGATOR` and inside PER_001's "Manager!" window (never more than ×2) | §36.6 (`ABL_006`), §11.10.1 |
| Soothing Song | −15 (−25 at level ≤ 2) within 12 studs; talks down level-5 hostiles at ≤ 70 % Huff; silences `INSTIGATOR` 8 s | §36.6 (`ABL_065`) |
| **Peace Offering** | serve any off-ticket DES or DRK dish to a customer at level ≥ 1 — the only thing that can be handed to a hostile customer: −35 anger (PER_020: −2 full levels); a second offering in the same visit −10; free for the customer, ingredient cost charged; at level 0 it is simply nice (P_offset +3) | A5 |
| Chill décor | `FRN_146` Lava Lamp Floor Lamp: anger **gains** ×0.90 within 6 studs · `FRN_434` Chill-Out Beanbag Corner: ×0.85 within 8 studs; the strongest applies, never stacked | §15 |
| Chill auras (customers) | PER_013 Grandma Golem and Superfan Regulars: +0.3 /s decay within 8 studs | §9.4, §8.12 |
| One-off personality calms | PER_030 Tag Team −25 · PER_027 Anniversary −20 (15 studs) · PER_008 Round for the house −15 · PER_010 Spotter −10 · PER_018 Standing Ovation −10 | §9.4 |
| Security Guard employee | interpose, Bouncer Hug, talk-down every 4 s; a Security stop always counts as calmed by combat | §11.10.6 (`ROLE_SECURITY`) |
| Perfect Recovery | finishing the whole order Perfect at level ≤ 2 → anger 0 | §C11.5 |
| Angry Customer Invasion: Perfect dish | instantly calms an invader | §36.11 (`EVT_004`) |

**Recovery rules**
- Anger falling below 45 (or a level-5 talk-down) sends a hostile customer through `CALMING_DOWN` (2.5 s).
  **Calmed without combat** — it took no player or employee damage during this hostile episode — it returns to its
  seat (`resumeState`), its patience clock resumes, and it pays and tips by S. **Calmed by combat** — it took damage,
  reached 0 Huff, or was stopped by Security — it apologizes and pays the 40 % Apology Payment with no tip (§10.5,
  §11.10.1).
- **Sheepish** (30 s after any calm): anger gains ×0.5 and escalation rolls ×0.5, so customers do not ping-pong
  between calm and furious.
- A calmed customer is served normally again; later items are evaluated with the normal formula (anger never
  enters S).

### 10.11 Rules & Mechanics — Consequences and Fairness Safeguards

| Consequence | Rule |
|---|---|
| Money | pay/tip per the §10.5 outcome table; storm-outs and fleeing customers pay 0 |
| Reputation | storm-out −0.03 ★ extra; a fizzled chaos loses at most −0.10 ★ extra in total; PER_004/PER_009/PER_025 hooks |
| Damage | durability per §11.6.3 (throws, smashes, flips, charges, wall splats); repaired through `RepairService` (§15); nothing is ever permanently lost (§C6) |
| Cleanliness | splats, spills and trash lower K for every diner (§10.2.5) until cleaned |
| Time | hostile customers' patience is paused, but every other ticket keeps running |
| Player KO | §11.10.2: no loss of anything; the KO'er dances and leaves without paying (storm-out) |

**Fairness safeguards** (failure must be funny, not devastating — Part 26.4):
1. **Chaos cooldown:** 3 min between chaos events; Calm Afterglow afterwards (§10.9).
2. **Caps:** per-tier hostile and fighter caps (§10.8) inside §11.7's absolute limits; escalations beyond a cap are
   deferred, never converted into something worse.
3. **New-player protection:** owner below level 5 → no level 5, no chaos, level-3 cap ≤ 2, damage budget halved
   (scripted tutorial excepted).
4. **Damage budget:** the repair-cost value of customer-caused durability damage in any rolling 10 min is capped at
   15 % of the tier's NetMB/h (§C4.4) — 95 MB at `TIER_01`, 260 MB at `TIER_03`, 1,440 MB at `TIER_06`, 18,075 MB at
   `TIER_10`. Beyond it, customer hits on furniture are cosmetic (splats still appear but auto-clean after 20 s).
   §11.10.5 `FurnitureCombatDamageMult` upgrades apply before the budget.
5. **Essential-station floor:** customer actions cannot push the last usable instance of any station a menu recipe
   needs — or the last `STN_WINDOW` / `STN_ASSEMBLY` — below Cracked (26 %). Cooking never becomes impossible
   because of customers.
6. **Rough Patch:** ≥ 3 storm-outs within 5 min → for 2 min `PACIFIST` spawn weights ×2, escalation rolls ×0.5, and
   the next 3 arrivals get patience ×1.2.
7. **Bad-Luck Breaker:** if 2 escalation rolls succeeded in this restaurant within 60 s, the next roll is ×0.5.
8. **Sheepish**, the **chain-depth limit** (§10.8 rule 5) and the **anti-farm** chaos reward rule (§10.9).
9. Combat-side protections, restated: Mercy Rule after 3 KOs in 10 min (§11.10.2), reduced damage while the owner is
   KO'd (§11.10.3), the leash when every player leaves (§11.8.1), and menu safety (§C22 E2).

### 10.12 Variables

| Variable | Value [TUNABLE] | Section |
|---|---|---|
| Satisfaction weights | 0.25 / 0.20 / 0.15 / 0.20 / 0.10 / 0.10 (canon, fixed) | §10.2 |
| PayFactor below S 30 (customer stays) | 0.6 | §10.5 |
| Storm-out S_rep | 20 | §10.5 |
| Patience pressure | +0.6 /s (50–75 %), +1.0 /s (75–100 %) | §10.6 |
| Aura cap | +2.0 /s before sensitivity | §10.6 |
| Calm decay / eating / fatigue | −0.5 /s / −1.0 /s / −0.2 /s | §10.6 |
| Evaluation deltas | −25 / −12 / +6 / +18 / +32 | §10.6 |
| Splash radius / mob radius | 4 studs / 15 studs | §10.8 |
| Escalation adds | mob +0.10, retaliation +0.10, chaos +0.15; max p 0.95 | §10.7 |
| ModeTick | 6 s (`THROWER`, `TRICKSTER` 4 s) | §10.7 |
| Chaos | ignition 2 ticks; 45 s max; resolve < 2 hostiles for 8 s; cooldown 3 min | §10.9 |
| Brawl Survived | 0.03 × XPRate(L) XP; 0.02 × NetMB/h MB; 1 per 15 min | §10.9 |
| Peace Offering | −35, second −10 | §10.10 |
| Damage budget | 15 % of NetMB/h per rolling 10 min | §10.11 |

### 10.13 UI — Color-Independent Indicators

Every status uses **shape + glyph + text**, with color only as reinforcement; ≥ 3 levels also add a fill pattern.

| Anger level | Shape | Glyph | Text label | Color (secondary) | Pattern / motion |
|---|---|---|---|---|---|
| 0 Happy | circle | smile | "Happy" | green | none |
| 1 Annoyed | triangle | single steam puff | "Annoyed" | yellow | none |
| 2 Complaining | square | speech bubble with "!" | "Complaining" | orange | slow wobble |
| 3 Throwing food | pentagon | flying plate | "Throwing!" | red-orange | diagonal stripes |
| 4 Destroying furniture | hexagon | broken chair | "Smashing!" | red | cross-hatch |
| 5 Fighting | octagon (stop-sign) | boxing glove | "Fighting!" | crimson | double border, pulse |
| 6 Chaos | star burst | "!!" | "CHAOS!" | magenta | screen-edge banner |

| Satisfaction band | Glyph | Text | Notes |
|---|---|---|---|
| Delighted | heart | "WOW!" | Chef's Kiss (S ≥ 98) adds a sparkle burst and "CHEF'S KISS!" |
| Happy | thumbs-up | "Nice!" | |
| Meh | flat wavy line | "Meh" | |
| Unhappy | down arrow | "Ugh" | |
| Furious | storm cloud | "FURIOUS" | |

- The **anger icon** sits beside the patience ring (§8.14) and shows the level numeral (0–6) inside the shape.
- **Chaos Meter** (top-center while chaos is active): star-burst icon, "CHAOS" label, a hatched bar with the CM
  percentage as text, and a 45-second countdown ring with seconds ("0:32"). The Ringleader wears a crown glyph.
  Resolution shows "BRAWL SURVIVED!" with the reward lines; a fizzle shows "The chaos fizzled out…" with a summary
  (storm-outs, objects damaged, Apology Payments).
- **Reduced effects:** no pulsing or screen-edge flashing (static outlines instead), no camera shake; the banner
  becomes a static strip. Audio cues for level changes are described in §26 and always have a visual twin.
- `ABL_070` Eagle Eye shows every customer's anger icon and patience ring through walls; the Robot Accountant's
  itemized receipt (§9.4) shows the full satisfaction breakdown.

### 10.14 Progression

- Below owner level 5: tantrums up to level 4 only (learning phase). From level 5 (`TIER_02` entry) fights and,
  from three simultaneous hostiles, chaos become possible.
- Caps, party sizes, modification counts and personalities scale with tier (§10.8, §8, §9); chaos rewards scale
  with NetMB/h.
- Players counter escalation with CHARM (longer patience, lower roll chance), Customer Service specialization
  skill nodes (§14, which may modify these values within the caps here), calm décor and security upgrades (§15),
  and `ROLE_SECURITY` employees (§16).

### 10.15 Player Interactions

Serve accurately and fast (S) · keep the room clean (K) and pretty (M) · equip charm parts (MutationBonus) · read
anger icons and act early · Calm Down! grumblers before they throw · Peace Offerings for hostile customers · dodge
or block thrown food (and mind who stands behind you) · defend until Winded, then talk (no Apology loss) · break up
mobs by calming the loudest member · go after the Ringleader first during chaos · mop splats and repair afterwards.

### 10.16 Dependencies

§C11 (formulas), §5 (component grades, cleaning verb), §6/§6.18 (prices, A, ModBonusPct, mod generation), §8
(states, patience, hostile pauses), §9 (personality parameters and hooks), §11 (fight execution, projectiles,
furniture damage, caps, talk-down, Security), §14 (Customer Service specialization, XPRate), §15 (Atmosphere, LocalAtmosphere, Chill
décor, EscalationDampener, repairs), §16 (Security, Cashier, Cleaner), §21 (guest rewards), §22 (economy), §24
(HUD), §26 (audio stings), §36.6/§36.7 (calm abilities, statuses), §36.11 (event effects).

### 10.17 Roblox Implementation

`CustomerAIService` owns `Satisfaction` (pure functions, unit-tested against §10.4) and `Anger` (below). Both run on
the server only; clients receive `Anger`, `AngerLevel` and `ItemS` attributes (§8.18).

```lua
--!strict
-- ServerScriptService/CustomerAI/Anger.lua : per-tick anger update, escalation rolls, level-6 gate
local Anger = {}
local THRESH = { [3] = 45, [4] = 60, [5] = 75 }

function Anger.levelOf(a: number): number
	if a >= 90 then return 6 elseif a >= 75 then return 5 elseif a >= 60 then return 4
	elseif a >= 45 then return 3 elseif a >= 30 then return 2 elseif a >= 15 then return 1 end
	return 0
end

local function rollEscalation(c, level: number, ctx): (boolean, boolean) -- (passed, deferred)
	if ctx.capReached(level) or (level == 5 and ctx.ownerLevel < 5 and not c.scripted) then
		return false, true                                     -- deferred: no attempt spent
	end
	local tries = c.rollTries[level] or 0
	c.rollTries[level] = tries + 1
	if tries >= 2 then ctx.forceLeave(c) return false, false end  -- nobody sulks forever
	if c.forcedNextRoll then c.forcedNextRoll = false return true, false end
	if c.chainDepth >= 3 then return false, false end           -- cascade limit (§10.8)
	local p = c.def.angerP * 100 / (100 + ctx.charm) * ctx.eventMul
	p += (ctx.inMob(c) and 0.10 or 0) + (c.retaliateUntil > ctx.now and 0.10 or 0) + (ctx.chaos and 0.15 or 0)
	p = math.clamp(p - ctx.escalationDampener, 0, 0.95)
	if tries == 1 then p *= 0.75 end
	if c.sheepishUntil > ctx.now then p *= 0.5 end
	if ctx.roughPatch then p *= 0.5 end
	if ctx.badLuckBreaker then p *= 0.5 end
	return c.rng:NextNumber() < p, false
end

function Anger.update(c, dt: number, ctx)
	local sens = c.def.sens
	local gainMult = (c.sheepishUntil > ctx.now and 0.5 or 1) * ctx.chillDecorMult(c) -- 0.85 / 0.90 / 1.0
	local burst = 0
	for _, ev in c.angerEvents do                               -- hits, defects, evaluation deltas
		burst += if ev.amount > 0 then ev.amount * sens * gainMult else ev.amount
		c.chainDepth = math.max(c.chainDepth, ev.depth)
	end
	table.clear(c.angerEvents)
	local rate = ctx.patienceRate(c) + ctx.orderRate(c) + ctx.seatRate(c)
		+ 0.005 * math.max(0, 60 - ctx.K(c)) + ctx.fireRate(c) + math.min(2.0, ctx.auraRate(c))
	local gain = rate * sens * gainMult * dt
	if gain > 0 or burst > 0 then c.lastGainAt = ctx.now end
	local decay = math.min(3.0, ctx.decayRate(c)) * dt         -- calm / eating / fatigue + chill auras
	local a = math.clamp(c.anger + burst + gain - decay, 0, 100)

	local old, new = Anger.levelOf(c.anger), Anger.levelOf(a)
	for L = old + 1, math.min(new, 5) do
		if L >= 3 then
			local passed, deferred = rollEscalation(c, L, ctx)
			if not passed then
				a = THRESH[L] - 1
				if not deferred then ctx.fallback(c, L) end        -- sulk / complain / leave table
				break
			end
		end
	end
	if a >= 90 and not ctx.chaos then a = 89 end              -- level 6 exists only during chaos
	c.anger = a
	c.proxy:SetAttribute("Anger", math.floor(a))              -- engine skips unchanged values; §8.18 writes on change
	local lvl = Anger.levelOf(a)
	if lvl ~= c.level then
		c.level = lvl
		c.proxy:SetAttribute("AngerLevel", lvl)
		ctx.onLevelChanged(c, old, lvl)                       -- state machine, modes, analytics
	end
end

return Anger
```

Mob detection uses a 15-stud spatial hash rebuilt once per brain tick per interior (≤ 28 customers, O(n)); chaos
is a per-restaurant controller holding `ChaosStartedAt`, `CM0`, `RingleaderId` and the cooldown timestamp, replicated
to clients as interior attributes (`ChaosActive`, `ChaosPercent`, `ChaosEndsAt`). Analytics: `mmr_first_tantrum`,
`mmr_customer_escalated`, `mmr_customer_storm_out`, `mmr_chaos_start`, `mmr_chaos_end` (§31).

### 10.18 Edge Cases

| # | Situation | Ruling |
|---|---|---|
| 1 | Anger crosses two thresholds in one tick (e.g. 40 → 70) | Rolls run in ascending order; a failure or deferral stops at that threshold − 1 |
| 2 | S lands exactly on a boundary (50.0, 70.0, 98.0) | Lower bounds are inclusive: PayFactor 1.0, TipRate 5 %, 25 % respectively |
| 3 | A projectile is in flight when its target despawns | It keeps flying along its arc and may hit someone else (§11.6.2) |
| 4 | Peace Offering to a level-0 customer | Free gift: P_offset +3, no anger change; counts as that visit's one full-strength offering |
| 5 | Owner disconnects during chaos | §C22 E1: chaos ends at once, no reward, no reputation loss, everyone leaves "closed" |
| 6 | A second chaos trigger during chaos | Ignored; one chaos per restaurant at a time |
| 7 | The player is KO'd during chaos | The KO'er stays in the fight (§C12.1); the 45 s cap still applies |
| 8 | A forced roll (PER_010) meets a full cap | The cap wins: the escalation is deferred |
| 9 | A player-thrown object misses a hostile and hits a bystander | +25 × sens to the bystander; counts as player-caused for the chaos anti-farm rule |
| 10 | Damage budget exhausted mid-brawl | Durability stops dropping; splats auto-clean after 20 s; anger rules continue normally |
| 11 | A customer calmed without combat is hit again within its Sheepish window | Gains ×0.5; if it turns hostile again and then takes damage, the Apology Payment applies |
| 12 | All items undelivered when patience expires but the customer already ate one | It pays for the eaten item by S (failed items included at A = Q = C = W = 0) — not a storm-out |
| 13 | Two players calm the same customer in one tick | Both effects apply (max −35 each per §36.6); calm credit is shared |
| 14 | A hostile customer is offered a normal (on-ticket) plate | Refused: "Can't serve an angry customer!" — only Peace Offerings are accepted |

### 10.19 Acceptance Criteria

- **AC-10-01:** For the five §10.4 examples, the server's S values match to ± 0.01 and pay/tip match exactly.
- **AC-10-02:** Item S is always clamped to 0–100; final S equals the price-weighted mean of item S.
- **AC-10-03:** MutationBonus never exceeds +10 per item and EventModifier never leaves −15..+15, in 100,000 random
  combinations.
- **AC-10-04:** K equals 100 minus the §10.2.5 deductions (with 1.5× local weighting and category caps) in 50 scripted
  mess layouts.
- **AC-10-05:** Reputation after each outcome type in §10.5 matches the formula to 4 decimals, including the −0.03 ★
  storm-out extra and the [1.0, 5.0] clamp.
- **AC-10-06:** Jackpot tips are capped at 500 MB in `TIER_01`–`TIER_04` and 5,000 MB in `TIER_05`+, and never occur
  for PER_015.
- **AC-10-07:** Over 10,000 simulated crossings, escalation success rates match p from §10.7.1 within ± 1 percentage
  point for each style, and no `PACIFIST` ever deals damage.
- **AC-10-08:** After 2 failed rolls at a threshold, the next crossing produces a storm-out 100 % of the time.
- **AC-10-09:** The number of customers at level ≥ 3 and at level 5 never exceeds the §10.8 caps (outside chaos) or
  the chaos caps (during chaos), and never exceeds §11.7's absolute limits.
- **AC-10-10:** With the owner below level 5 (non-tutorial), no customer reaches level 5 and chaos never ignites in
  1,000 simulated hours.
- **AC-10-11:** Chaos ignites within 0.5 s of a third simultaneous level-3 customer (owner ≥ level 5, no cooldown),
  never lasts more than 45 s, resolves after 8 s with fewer than 2 hostiles, and cannot re-ignite within 3 min.
- **AC-10-12:** "Brawl Survived" grants exactly round(0.03 × XPRate(L)) XP per participant and round(0.02 × NetMB/h)
  MB, at most once per 15 min, and nothing when ≥ 50 % of the triggering anger was player-caused.
- **AC-10-13:** Customers calmed without taking damage pay and tip by S; customers that took damage, hit 0 Huff or
  were stopped by Security pay exactly 40 % with no tip.
- **AC-10-14:** Every anger level and satisfaction band is distinguishable in grayscale screenshots (shape + glyph +
  text), verified by an accessibility review.
- **AC-10-15:** Customer-caused durability damage per rolling 10 min never exceeds the damage budget, and no customer
  action reduces the last required station below Cracked.
- **AC-10-16:** In the §10.8 worked chain reaction, a scripted replay reproduces every anger value in the table to
  ± 0.1.

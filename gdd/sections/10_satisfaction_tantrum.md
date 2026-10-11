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

- A wrong dish is rejected at `INSPECT_FOOD` and never evaluated (anger +20 × sens, §10.6).
- For the correct recipe: `A = (1 + Σ_m sat_m) / (1 + n_mods)`, where each requested §6.18 modification scores
  `sat_m = 1` satisfied, `0.5` partially satisfied (only where §6.18 defines a partial outcome), `0` missing.
  Joke modifications score through their alternative satisfaction mechanic defined in §6.18.
- Accepted substitutes (PER_024) score A = 0.8.

| Requested mods | Outcome | A |
|---|---|---|
| 0 | — | 1.00 |
| 1 | missed | 0.50 |
| 2 | one missed | 0.667 |
| 3 | all satisfied | 1.00 |
| 3 | one partial, one missed | 0.625 |

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

| Source | Bonus | Condition |
|---|---|---|
| Charm-tagged parts | +1 each, max +4 | equipped parts carrying the `charm` tag (§C13.5) |
| `MUT_047` Mustache of Destiny | +2 | "dashing service" (stacks with its charm tag) |
| `MUT_102` Chef Hat Crest | +1 | looks professional |
| `MUT_272` Sparkle Aura | +1 | |
| `MUT_229` Nine Fox Tails | +2 | |
| `MUT_039` Golden Burger Head | +3 | |
| `MUT_258` Golden Skin | +2 | customer is PER_008 |
| `MUT_021` TV Head | +2 | customer is PER_009 ("on camera") |
| Family Resemblance | +2 | deliverer wears a part of the same family as the customer's HEAD |
| Mutation Cuisine "Whoa!" | +10 | the item is a MUT recipe (§C10) |
| §12 part passives | as defined in §12 | add into this same pool; the +10 cap always holds |

**EventModifier** (sum of active events, clamped to −15..+15; event schedules and rules are owned by §36.11, the
satisfaction effects below are owned here; unlisted events give 0):

| Event | ID | Modifier |
|---|---|---|
| Giant Food Festival | `EVT_001` | +5 all items |
| Mutation Parade | `EVT_002` | +3 all items |
| Citywide Restaurant Rush | `EVT_003` | −5 all items (everyone is in a hurry) |
| Angry Customer Invasion | `EVT_004` | −10 all items; escalation rolls ×1.5 (§10.7) |
| Legendary Chef Tournament | `EVT_005` | +5 LEG items |
| Mutation Meteor Shower | `EVT_006` | +10 MUT items and items with the `mutagen` tag |
| Food Critic Convention | `EVT_008` | −5 all items (everyone is a critic) |
| Blackout Night | `EVT_009` | −5 all items unless Atmosphere ≥ 50 ("candlelit charm") |
| Upside-Down Day | `EVT_011` | +10 `RCP_BRG_013`, `RCP_BRK_005`, `RCP_PIZ_012` and upside-down modifications |
| Pickle Rain | `EVT_012` | +8 items with the `pickle` tag |
| Sewer Flood | `EVT_013` | −5 all items |
| Celebrity Chef Visit | `EVT_014` | +5 all items |
| Polite Robot Uprising | `EVT_017` | +10 for customers whose HEAD or TORSO is ROBOT category |
| Alien Tourist Season | `EVT_018` | +10 ALN items |
| Hot Sauce Heatwave | `EVT_019` | +10 `spicy` items; +5 `frozen` drinks |
| Frozen Snap | `EVT_020` | +10 SOP items, `RCP_DRK_007` and `RCP_DRK_010`; −5 `frozen` items |
| Health Inspector Sweep | `EVT_026` | −(100 − K) / 10 (0 to −10) |
| Neon Lights Festival | `EVT_028` | +5 all items |
| Haunted Kitchen Night | `EVT_029` | +8 `RCP_SOP_006`, `RCP_SOP_005`, `RCP_PIZ_006` |
| Snowmorph Holiday | `EVT_030` | +8 DES items |
| Spring Sprout Bloom | `EVT_031` | +10 SAL items |
| Bug Swarm Brunch | `EVT_032` | +10 items with the `bug` tag; −3 all others |

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
  with A = 1.00, scores 81.60 × 0.85 − 2 = 67.36 → S = **69.51**. Still under 70: no tip. The Karenosaurus is hard
  to please, by design.
- Anger along the way: 25.2 s of patience pressure (50–75 %) at 0.6 × 1.3 /s = **19.7**; missing mod +8 × 1.3 =
  **30.1** (level 2, "Manager!" ping); Unhappy evaluation +18 × 1.3 × 15/21 = **46.8** → crosses 45 → escalation roll
  p = 0.45 × 100/120 = **37.5 %** (§10.7).

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

**Payment** (§C11.4): `Pay = round(Σ Price_i × PayFactor)` with PayFactor **1.0** if S ≥ 50, **0.8** if 30 ≤ S < 50,
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
| Fled during chaos (PER_012 pays eaten items) | 0 | 0 | not counted | — |
| Walk-by (never entered) | — | — | not counted | — |
| Closed (E1, E13, Away Mode) | 0 | 0 | not counted | — |

**More examples.**
- *Apology Payment:* a Bodybuilder Pigeon (ticket 15 + 12 MB) is beaten to Huff 0 before being served: pays
  round(27 × 0.4) = **11 MB**, no tip; S_rep 30 → Stars 3.00 → **2.970 ★**.
- *Storm-out:* an Impatient Goblin's patience expires with nothing delivered at 2.80 ★: pays 0; 2.80 + 0.02 × (1 −
  2.80) = 2.764, then −0.03 → **2.734 ★**.
- *Jackpot cap:* at `TIER_04` a 120 MB tip hits the Jackpot: ×5 = 600 → capped at **500 MB**.


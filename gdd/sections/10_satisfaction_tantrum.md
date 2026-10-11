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


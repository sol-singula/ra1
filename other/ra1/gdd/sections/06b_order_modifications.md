### 6.18 Ridiculous Order Modifications

> Morph City customers do not just order food; they order *experiences*: "Make my burger upside
> down." "Make my drink angry." This subsection defines how modifications ("mods") are generated, how each one is
> completed with the cooking system of §5, how the server verifies it on the Dish object (§5.6.4), how it affects order
> accuracy `A` (canon §C11.3) and pay, and lists **93 modifications** (`MOD_001`–`MOD_093`). Golden rule: **no impossible
> orders** — every mod is completable with stations the restaurant already owns, or is a clearly marked joke with an
> alternative way to satisfy the customer.

| Template block | Where |
|---|---|
| Purpose | this intro, §6.18.1 |
| Rules & Mechanics | §6.18.2 (categories), §6.18.3 (generation), §6.18.4 (verification), §6.18.5 (pay) |
| Variables | §6.18.3 tables, §6.18.5 — all [TUNABLE] |
| UI | §6.18.7 |
| Progression | unlock levels in §6.18.6; tier tables in §6.18.3 |
| Player Interactions | "What the player must do" column; actions defined in §5.4.12 |
| Dependencies | §5 (stations, verbs, Dish), §6 (recipes: core components, canonical stack, sequences), §7 (ingredients), §8–§10 (orders, satisfaction), §16 (employees), §36.6 (`ABL_064`, `ABL_067`) |
| Roblox Implementation | §6.18.8 |
| Edge Cases | §6.18.9 |
| Acceptance Criteria | §6.18.10 (`AC-06-81` … `AC-06-96`; the 81+ range is reserved for §6.18 so it never collides with §6.1–6.17) |

#### 6.18.1 Design rules

1. **Achievable:** a mod may only be generated if every station and action it needs is owned, placed and usable in that
   restaurant *now* (stronger than canon §C7.1's level availability), and the item's estimated prep time plus the mod's
   extra time fits the customer's patience (§6.18.3).
2. **Readable:** every mod is shown as a chip (icon + ≤ 14 characters) on the ticket rail, the HUD queue and the held dish,
   with live ✓ / ✗ marks (§6.18.7). The customer's full quote is always one tap away.
3. **Mechanical:** every non-joke mod maps to a concrete verb, station action or serve variant from §5.4.12; every joke mod
   has a **Play Along** action (full credit + bonus) *and* a **Straight Answer** (serve the normal dish: partial credit,
   never anger).
4. **Fair:** mods add pay bonus on success and cost at most a fraction of order accuracy on failure — a missed mod is a
   funny complaint, not a disaster (Part 26.4).
5. **Morph-aware:** a few mods reward what you are (tails, extra arms) — always with an alternative route.

#### 6.18.2 Mod categories

| Code | Category | Player task pattern | Pay bonus band | Extra time budget | Employee difficulty (§16) | Conflict group |
|---|---|---|---|---|---|---|
| `OMIT` | Omit | leave a component (or a whole tag) out | 5–6 % | 0 s | 1 | `ING:<ingredient or tag>` |
| `EXTRA` | Extra | add more of a component | 5–8 % | +3 s | 1 | `ING:<ingredient or tag>` |
| `COUNT` | Exact count | Count Mode / Count Out to an exact number | 10–15 % | +6 s (+0.3 s per unit above default; +6 s per extra cooked unit) | 2 | `ING:<ingredient>` |
| `DONENESS` | Doneness / method | pull in a specific heat band, bake dial, double fry, crosshatch, method swap | 8–15 % | +4 s | 2 | `DONE:<component>` |
| `TEMP` | Temperature | freeze, chill, keep sizzling, let cool, lamp-warm | 8–15 % | +8 s (lukewarm +20 s) | 2 | `TEMP` |
| `SHAPE` | Shape / orientation | cut modes, Flip Stack, Fold, Tip Over | 10–18 % | +4 s | 2 | `SHAPE:<component>`, `ORIENT` |
| `PRESENT` | Presentation | garnish, drizzle art, wrap, spread out, flourish, sparkling plate | 8–12 % | +4 s | 2 | `PRESENT`, `CONTAINER` |
| `SEQUENCE` | Sequence / order | a specific stack, topping or insertion order | 10–14 % | +2 s | 2 | `STACK` |
| `MOOD` | Drink mood | Agitate / Rest to a mood (§5.4.8) | 10–15 % | +4 s | 2 | `MOOD` |
| `JOKE` | Joke | absurd request; Play Along action or Straight Answer | 15–25 % | +5 s | 3 | `JOKE` (+ `KIND`/`CONTAINER` where noted) |

**Conflict rules** (at most one mod per group per item): one OMIT/EXTRA/COUNT per ingredient, and any mod that *adds* an
ingredient conflicts with an OMIT of that ingredient or of a tag it carries (e.g. `MOD_062` ketchup smiley vs `MOD_006`
no sauce); one DONENESS per component; one TEMP, one MOOD, one PRESENT (except `MOD_066` Flourish, combinable) per item;
`STACK` and `ORIENT` are mutually exclusive; dish-replacing jokes (`KIND`: `MOD_082`, `MOD_084`, `MOD_088`, `MOD_089`,
`MOD_092`) are always the item's only mod; max 1 JOKE per item.

#### 6.18.3 Generation rules

**Per-tier probabilities** (rolled per order item by `OrderService` when the order is placed):

| Tier # | Tier ID | P(item has ≥ 1 mod) | Max mods per item | P(2nd mod given 1st) | P(3rd given 2nd) | Joke share of 1st pick | Hidden-mod chance |
|---|---|---|---|---|---|---|---|
| 1 | `TIER_01` | 10 % | 1 | — | — | 10 % | 0 % |
| 2 | `TIER_02` | 14 % | 1 | — | — | 10 % | 0 % |
| 3 | `TIER_03` | 18 % | 1 | — | — | 12 % | 0 % |
| 4 | `TIER_04` | 22 % | 2 | 25 % | — | 12 % | 0 % |
| 5 | `TIER_05` | 26 % | 2 | 30 % | — | 14 % | 5 % |
| 6 | `TIER_06` | 30 % | 2 | 33 % | — | 14 % | 8 % |
| 7 | `TIER_07` | 33 % | 2 | 36 % | — | 15 % | 10 % |
| 8 | `TIER_08` | 36 % | 3 | 40 % | 20 % | 15 % | 12 % |
| 9 | `TIER_09` | 40 % | 3 | 42 % | 25 % | 16 % | 12 % |
| 10 | `TIER_10` | 45 % | 3 | 45 % | 30 % | 16 % | 15 % |

**Personality affinity** (defaults; §9 may override per personality with a `ModAffinity` field). `Aff` multiplies the
three mod-count probabilities (each clamped to ≤ 85 %); `JokeAff` multiplies the joke share; `HidAff` the hidden chance.

| Affinity group | Aff | JokeAff | HidAff | Personalities |
|---|---|---|---|---|
| Very picky | 2.0 | 0.5 | 1.0 | `PER_001`, `PER_004`, `PER_014`, `PER_015` |
| Chaotic | 1.7 | 2.5 | 1.0 | `PER_007`, `PER_018`, `PER_028`, `PER_032` |
| Fancy | 1.5 | 1.0 | 1.0 (`PER_025`: 2.0) | `PER_008`, `PER_009`, `PER_025`, `PER_027`, `PER_031` |
| Quirky | 1.2 | 1.5 | 1.0 (`PER_011`: 2.0) | `PER_011`, `PER_019`, `PER_020`, `PER_022`, `PER_023`, `PER_024`, `PER_029` |
| Standard | 1.0 | 1.0 | 1.0 | `PER_003`, `PER_010`, `PER_012`, `PER_013`, `PER_016`, `PER_017`, `PER_021`, `PER_030` |
| Low-fuss | 0.6 | 0.5 | 0.5 | `PER_002`, `PER_005`, `PER_006`, `PER_026` |

`PER_019` The Mime Mantis never speaks: its mods appear as pictogram chips only (same icons everyone sees). Party orders
(`PER_016`) roll each member's items separately.

**Eligibility filter** — a mod is a candidate for an item only if **all** hold:
1. Owner level ≥ the mod's unlock level, and the tutorial gate is passed (below).
2. The item matches the mod's *Applies to* (category code, §C9 ingredient tag, `ING_` or `RCP_` id) and the recipe actually
   contains any ingredient the mod omits/counts/doubles (unless the mod explicitly adds it).
3. Every station named in the mod's task is **owned, placed and not Broken/Destroyed** in this restaurant (`MOD_087` also
   needs the owner to own ≥ 1 TAIL part or a tailed employee assigned to a heat station).
4. Special ingredients the mod needs (e.g. extra `ING_STARDUST`) can be reserved from stock now.
5. No conflict with mods already chosen for the item (§6.18.2).
6. **Time budget:** `EstPrep(item) + Σ ExtraTime(mod) ≤ 0.6 × Patience(item)` (EstPrep = recipe base prep time from §6,
   Patience per canon §C11.2 — mods never change the canon patience formula).

**Selection** (deterministic per order: `Random.new(hash(orderId))`, server only):
```
p1 = min(0.85, P1[tier] × Aff);  n = rng:NextNumber() < p1 and 1 or 0
if n == 1 and MaxMods[tier] >= 2 and rng:NextNumber() < min(0.85, P2[tier] × Aff) then n = 2 end
if n == 2 and MaxMods[tier] >= 3 and rng:NextNumber() < min(0.85, P3[tier] × Aff) then n = 3 end
for k = 1, n do
  pool = Eligible(item) minus Conflicts(chosen)
  if k == 1 and rng:NextNumber() < JokeShare[tier] × JokeAff then pool = Jokes(pool) else pool = NonJokes(pool) end
  -- empty pool falls back to the other half; still empty -> stop
  weight(m) = 1 × (3 if personality ∈ m.FavoredBy) × (0.5 if m.Bonus ≥ 15 % and tier ≤ TIER_03)
  chosen += WeightedPick(pool, weight, rng)
end
hidden(m) = m.Category ∈ {OMIT, EXTRA, TEMP, DONENESS} and rng:NextNumber() < Hidden[tier] × HidAff
```

**Hidden mods** appear as "???" chips. They are revealed by **Ask Again** (Use on the customer, 1.5 s, free once per
order — the customer repeats the request, louder) or instantly by `ABL_064` Super Sniff (`MUT_058`) for every customer in
its radius. Hidden mods are verified like any other; COUNT and JOKE mods are never hidden.

**Tutorial gate & pacing:** no mods during `QST_TUT_001`–`QST_TUT_005`; the first mod after that is a scripted `MOD_001`
with a tooltip (scripted in §32); the next 3 mods are drawn only from OMIT/EXTRA. **Accessibility — "Fewer Weird
Requests":** P(≥ 1 mod) × 0.5, no hidden mods, and joke chips show a "Play along?" hint naming the action.

#### 6.18.4 Server verification, order accuracy `A`, and mismatch

At serve (§5.6.5, step 7) the server evaluates each mod's **predicate** against the Dish. Predicate vocabulary:
`count(ING)` (sum of component `count`), `tagCount(tag)`, `base(ING)` (recipe default count), `doneness(c)` / `grade(c)`
(last heat step of component *c*; "protein" = every instance of the recipe's main heat component, e.g. both patties of a double burger), `state(c)`, `shape(c)`,
`stackIndex(ING)`, `orientation`, `layout`, `cut`, `fold`, `container`, `kind`, `boxType`, `wrapped`, `garnish`, `drizzle`,
`plateGrade`, `temp`, `hotFrac` (remaining HOT time / 20 s; the heat lamp pauses it), `lampSec`, `frosty`, `wasHeated`,
`mood`, `moodHistory`, `shaken(c)`, `fryCount(c)`, `gridMarks(c)`, `bakeDial(c)`, `dialCorrect(c)`, `seqReversed(c)`,
`sourceRecipeId`, `hoverUntil`, `serve.flourish`, `serve.airborne`, `lastHeatActor.slots`, `customer.offered`.

```
Expected set  = recipe components (§6) transformed by the item's mods (OMIT removes, EXTRA/COUNT add, method swaps
                replace, Flip Stack reverses the expected stack); dish-replacing jokes use their own predicate instead.
DishMatch     = 0 (not a match → §5.6.5 wrong-dish handling) if any core component (§6; default: the base and every
                heat-processed component) is missing; else max(0.4, 1 − 0.15 × (missing non-core + unrequested extras))
sat_j         = 1 satisfied · 0 failed · 0.5 near miss (COUNT off by exactly 1) · 0.75 joke Straight Answer ·
                1 waived (required station Broken/Destroyed since the order was placed — no bonus)
ModScore      = (1 + Σ sat_j) / (1 + n)            n = number of mods on the item (0 → ModScore 1)
A_item        = DishMatch × ModScore               (canon §C11.3 order accuracy; §10 averages items per order)
```
**Doneness remap for `C`:** for the targeted component, the requested band scores 1.00 (RARE, WELL_DONE, SCREAMING,
BURNED…) and an ordinary PERFECT scores 0.80 ("Tasty, but not what I asked for"); other bands keep their normal grade.

**What a mismatch costs:** each failed mod forfeits its bonus and lowers `A`. One failed mod on a one-mod item → `A` =
0.5 → −12.5 satisfaction points (0.25 × 0.5 × 100); a 16-pickle near miss → `A` = 0.75 → −6.25 points; a joke Straight
Answer → `A` = 0.875 → −3.1 points. The customer delivers a comedic complaint line (§9); §10 may add a small anger bump
(suggested +5 × sensitivity per failed non-joke mod). Joke mods never add anger.

#### 6.18.5 Pay bonus formula

```
b_j           = the mod's Pay bonus (database column), 5–25 %                                   [TUNABLE]
ModBonusPct_i = min(0.40, Σ b_j over mods with sat_j = 1 and not waived)                         [TUNABLE cap]
Pay           = Σ_i round(Price_i × (1 + ModBonusPct_i)) × PayFactor     -- PayFactor, Apology Payment and storm-out
                                                                            rules exactly as canon §C11.4
Tip           = Σ_i Price_i × TipRate(S) × PersonalityTipMult           -- unchanged: tips use menu prices only
```
*Example:* `RCP_BRG_002` priced 10 MB with `MOD_052` (18 %) satisfied → round(11.8) = 12 MB (S ≥ 50). Dish-replacing jokes
still pay the full menu price plus bonus while only the ingredients actually used are netted (an empty box costs 0 MB) —
a deliberate comedy reward, bounded by joke frequency. *Economy impact* (for §22): at TIER_05, 0.26 items modded × 1.3
mods × 11.5 % mean bonus × 80 % success ≈ **+3.1 % of item revenue** (range +1 % at TIER_01 to +5 % at TIER_10).

#### 6.18.6 Modification database

Columns: *Applies to* uses category codes (§C10), ingredient tags (§C9), `ING_` and `RCP_` ids. *What the player must do*
uses the stations of §5.3 and the actions of §5.4.12. *Unlock level* is the owner level from which the mod can appear
(all stations it needs are available at that level per canon §C7.1; the eligibility filter additionally requires them to
be owned). *Favored by* personalities pick that mod with × 3 weight. The seven brief examples are `MOD_020`, `MOD_029`,
`MOD_043`, `MOD_051`, `MOD_052`, `MOD_076` and `MOD_082`.

| ID | Customer says | Category | Applies to | What the player must do | Server verification rule | Pay bonus | Unlock level | Favored by | Joke? |
|---|---|---|---|---|---|---|---|---|---|
| `MOD_001` | "Hold the pickles. Hold them far, far away." | OMIT | items containing ING_PICKLE | Don't add ING_PICKLE at STN_ASSEMBLY | count(ING_PICKLE) = 0 | 5 % | 1 | PER_014, PER_001 | No |
| `MOD_002` | "One cheeseburger, no cheese. I know what I said." | OMIT | RCP_BRG_002, RCP_BRG_003, any item with a `cheese` component | Skip every `cheese` component at STN_ASSEMBLY (pizza: top without cheese) | tagCount(cheese) = 0 | 5 % | 1 | PER_018, PER_021 | No |
| `MOD_003` | "No onions. They make all nine of my eyes cry." | OMIT | items containing ING_ONION | Skip ING_ONION (don't chop or add it) | count(ING_ONION) = 0 | 5 % | 1 | PER_012, PER_029 | No |
| `MOD_004` | "No lettuce. Leaves are for trees." | OMIT | items containing ING_LETTUCE | Skip ING_LETTUCE | count(ING_LETTUCE) = 0 | 5 % | 1 | PER_010, PER_030 | No |
| `MOD_005` | "No tomato. It looked at me funny." | OMIT | items containing ING_TOMATO | Skip ING_TOMATO (ING_TOMATO_SAUCE is fine) | count(ING_TOMATO) = 0 | 5 % | 1 | PER_011, PER_013 | No |
| `MOD_006` | "No sauce. Sauce is too loud." | OMIT | items with a `sauce` component | Leave out every `sauce` component (ING_KETCHUP, ING_MUSTARD, ING_TOMATO_SAUCE…) | tagCount(sauce) = 0 | 6 % | 1 | PER_006, PER_014 | No |
| `MOD_007` | "No bun. Buns are a conspiracy." | OMIT | BRG items | Build the stack straight onto a plate at STN_ASSEMBLY without ING_BUN | count(ING_BUN) = 0 | 6 % | 1 | PER_011, PER_021 | No |
| `MOD_008` | "No ice. Ice is just water showing off." | OMIT | DRK items whose recipe has ING_ICE | Pour at STN_DRINK without tapping the ice chute | count(ING_ICE) = 0 | 5 % | 1 | PER_013, PER_003 | No |
| `MOD_009` | "Nothing spicy. My tongue is on vacation." | OMIT | items with a `spicy` component (ING_HOT_SAUCE, ING_LAVA_PEPPER) | Leave out all `spicy` components | tagCount(spicy) = 0 | 6 % | 8 | PER_012, PER_020 | No |
| `MOD_010` | "No eyeballs. I don't like being watched while I eat." | OMIT | items containing ING_GUMMY_EYEBALL | Skip ING_GUMMY_EYEBALL | count(ING_GUMMY_EYEBALL) = 0 | 6 % | 16 | PER_012, PER_003 | No |
| `MOD_011` | "Extra cheese. Like, a worrying amount." | EXTRA | items with a `cheese` component | Add the cheese component a second time at STN_ASSEMBLY (pizza: second cheese layer before baking) | tagCount(cheese) ≥ base + 1 | 6 % | 1 | PER_002, PER_020 | No |
| `MOD_012` | "Double the patty, double the party." | EXTRA | items containing ING_BEEF_PATTY | GRILL one more ING_BEEF_PATTY at STN_GRILL and stack it | count(ING_BEEF_PATTY) ≥ base + 1 and every patty grade ≥ OK | 8 % | 1 | PER_002, PER_010, PER_030 | No |
| `MOD_013` | "Extra pickles. Pickle me, chef." | EXTRA | items containing ING_PICKLE | Add 2 more pickle slices (the counter chip shows the target) | count(ING_PICKLE) ≥ base + 2 | 5 % | 1 | PER_017, PER_016 | No |
| `MOD_014` | "Extra ice. I'm melting over here." | EXTRA | DRK items | Tap the ice chute at STN_DRINK at least 2 more times than the recipe | count(ING_ICE) ≥ base + 2 | 5 % | 1 | PER_023, PER_022 | No |
| `MOD_015` | "Extra bacon. Bacon is my love language." | EXTRA | items containing ING_BACON | GRILL one more ING_BACON and add it | count(ING_BACON) ≥ base + 1 | 6 % | 7 | PER_030, PER_002 | No |
| `MOD_016` | "Extra hot sauce. I want to see through time." | EXTRA | BRG, SAN, TAC, FRI, PIZ, SOP items | Add one ING_HOT_SAUCE portion at STN_ASSEMBLY or STN_PREP | count(ING_HOT_SAUCE) ≥ base + 1 | 6 % | 8 | PER_022, PER_024 | No |
| `MOD_017` | "More chocolate. Then a little more chocolate." | EXTRA | DES items, RCP_DRK_003 | Add one more ING_CHOCOLATE (topping, or into the blender jar) | count(ING_CHOCOLATE) ≥ base + 1 | 6 % | 3 | PER_031, PER_020 | No |
| `MOD_018` | "Extra eyeballs. I want it to watch me back." | EXTRA | items containing ING_GUMMY_EYEBALL | Add 2 more ING_GUMMY_EYEBALL | count(ING_GUMMY_EYEBALL) ≥ base + 2 | 7 % | 16 | PER_007, PER_028 | No |
| `MOD_019` | "Extra boba. A whole beach of boba." | EXTRA | RCP_DRK_005 and drinks containing ING_TAPIOCA | Add one more ING_TAPIOCA scoop to the cup before pouring | count(ING_TAPIOCA) ≥ base + 1 | 6 % | 8 | PER_009, PER_026 | No |
| `MOD_020` | "I want exactly seventeen pickles." | COUNT | BRG and SAN items (adds ING_PICKLE even if the recipe has none) | At STN_ASSEMBLY use Count Mode: tap = +1 slice, hold = +5, empty-hand Grab = −1, until the chip reads 17/17 ✓ | count(ING_PICKLE) = 17 (16 or 18 → near miss 0.5) | 15 % | 5 | PER_015, PER_014 | No |
| `MOD_021` | "Exactly three ice cubes. Not two. Not four. THREE." | COUNT | DRK items | Tap the ice chute at STN_DRINK exactly 3 times | count(ING_ICE) = 3 | 10 % | 1 | PER_015, PER_004 | No |
| `MOD_022` | "Five pepperonis. One for each of my eyes." | COUNT | PIZ items containing ING_PEPPERONI | Count Mode on the raw pizza at STN_ASSEMBLY before baking | count(ING_PEPPERONI) = 5 | 12 % | 3 | PER_029, PER_032 | No |
| `MOD_023` | "Give me eleven fries. I will be counting." | COUNT | RCP_FRI_001 | Count Out at STN_ASSEMBLY/STN_PLATING: each tap moves one fry from the basket portion onto the plate | count(fried ING_POTATO pieces) = 11 (10 or 12 → 0.5) | 12 % | 1 | PER_015, PER_026 | No |
| `MOD_024` | "Six shrimp. Six! Like my legs!" | COUNT | RCP_SEA_002 and items containing ING_SHRIMP | Count Out exactly six FRIED ING_SHRIMP | count(ING_SHRIMP) = 6 | 12 % | 10 | PER_017, PER_002 | No |
| `MOD_025` | "Exactly two scoops, stacked like a snowman." | COUNT | RCP_DES_002, RCP_DES_004 | Tap SCOOP exactly twice at STN_ICECREAM into one cone/bowl | count(scoops) = 2 | 10 % | 4 | PER_020, PER_023 | No |
| `MOD_026` | "Seven pancakes tall. I measured my mouth." | COUNT | RCP_BRK_001, RCP_BRK_005 | SAUTE seven pancakes at STN_STOVE (both burners) and stack exactly 7 at STN_ASSEMBLY | count(pancake layers) = 7 | 14 % | 2 | PER_002, PER_013 | No |
| `MOD_027` | "Just one noodle. One. Single. Noodle." | COUNT | RCP_PST_001 | Count Out exactly 1 noodle from the BOILED ING_PASTA portion | count(ING_PASTA pieces) = 1 | 12 % | 2 | PER_019, PER_006 | No |
| `MOD_028` | "Nine sugar sprinkles. I'm superstitious." | COUNT | DES items | Tap the ING_SUGAR shaker exactly 9 times at STN_ASSEMBLY/STN_PLATING | count(ING_SUGAR sprinkles) = 9 | 10 % | 3 | PER_011, PER_024 | No |
| `MOD_029` | "Cook my steak until it screams." | DONENESS | RCP_SEA_009 and any GRILL-cooked `meat`/`seafood` component (in Morph City every patty is a "steak") | Leave it on STN_GRILL past PERFECT and pull it in the SCREAMING band [T_burn − 1.5 s, T_burn), when it squeaks like a kettle ("EEEEE!") | doneness(protein) = SCREAMING | 15 % | 10 | PER_022, PER_030, PER_018 | No |
| `MOD_030` | "Rare, please. Just introduce it to the grill." | DONENESS | GRILL-cooked `meat`/`seafood` components | Pull it from STN_GRILL in the RARE band [T_ready − 1 s, T_ready) | doneness(protein) = RARE | 12 % | 1 | PER_010, PER_004 | No |
| `MOD_031` | "Well done. Retirement-home well done." | DONENESS | GRILL- or FRY-cooked `meat`/`poultry`/`seafood` | Pull it in the WELL_DONE band [T_pe + 1 s, T_burn − 1.5 s) | doneness(protein) = WELL_DONE | 10 % | 1 | PER_013, PER_024 | No |
| `MOD_032` | "Burn it. On purpose. I like it crunchy-dark." | DONENESS | GRILL, BAKE or FRY items | Pull it in the BURNED band [T_burn, T_burn + 4 s) — before it ignites | doneness(protein) = BURNED (remapped to 1.00 for C) | 14 % | 3 | PER_028, PER_007 | No |
| `MOD_033` | "Extra crispy. I want to hear it from across the room." | DONENESS | FRI items, RCP_SEA_001, RCP_SEA_002 | Shake in window at STN_FRYER, then pull in WELL_DONE | doneness = WELL_DONE and shaken = true | 10 % | 1 | PER_026, PER_009 | No |
| `MOD_034` | "Toast my bun. Just a little tan." | DONENESS | items containing ING_BUN or ING_BREAD_SLICE | GRILL the bread 3 s at STN_GRILL (or toast it in a Toaster Head, MUT_010) | state(bread) = GRILLED and grade ≥ GOOD | 8 % | 1 | PER_028, PER_013 | No |
| `MOD_035` | "Al dente. The noodles should fight back a little." | DONENESS | PST items with BOILED ING_PASTA | Pull the pasta pot at STN_STOVE in the RARE band | doneness(ING_PASTA) = RARE | 10 % | 2 | PER_004, PER_008 | No |
| `MOD_036` | "Runny egg. I like my yolks adventurous." | DONENESS | items with ING_EGG cooked at STN_STOVE | Pull the egg in the RARE band | doneness(ING_EGG) = RARE | 10 % | 3 | PER_013, PER_003 | No |
| `MOD_037` | "Golden brown. Not tan. Not bronze. GOLDEN." | DONENESS | BAKE items (DES, PIZ, RCP_PST_004, RCP_SOP_009) | Bake at the correct dial on STN_OVEN (or STN_PIZZA_OVEN) and pull strictly inside PERFECT | doneness = PERFECT and dialCorrect | 12 % | 3 | PER_004, PER_008 | No |
| `MOD_038` | "Gooey in the middle, please." | DONENESS | RCP_DES_001, RCP_DES_005, RCP_DES_011 | Pull from STN_OVEN in the RARE band | doneness = RARE | 10 % | 3 | PER_020, PER_031 | No |
| `MOD_039` | "Low and slow. Let it think about its life." | DONENESS | BAKE items whose correct dial is MED or HIGH | Bake one dial step lower on STN_OVEN (× 1.5 time; the usual low-dial GOOD cap is lifted) and reach ≥ GOOD | bakeDial = correct − 1 and grade ≥ GOOD | 12 % | 3 | PER_006, PER_024 | No |
| `MOD_040` | "Fry it twice. Then tell it it did a good job." | DONENESS | FRI items | After a ≥ GOOD fry, put it back into STN_FRYER for a second cycle (0.5 × T_ready) and pull ≥ GOOD | fryCount = 2 and grade ≥ GOOD | 12 % | 1 | PER_017, PER_026 | No |
| `MOD_041` | "Steam it instead of frying it. I'm being healthy-ish." | DONENESS | FRI items, RCP_SEA_001 (their FRY component) | Cook that component at STN_STEAMER instead of the fryer and pull ≥ GOOD | state(component) = STEAMED, no FRIED component | 12 % | 7 | PER_021, PER_013 | No |
| `MOD_042` | "Criss-cross grill marks. Like a tic-tac-toe board." | DONENESS | GRILL items that need a flip | Flip in the window at STN_GRILL, then Turn (tap Use within 1 s) | gridMarks = CROSSHATCH and grade ≥ GOOD | 10 % | 4 | PER_009, PER_008 | No |
| `MOD_043` | "I want my soup frozen." | TEMP | SOP items except RCP_SOP_003 | Ladle into a bowl, then FREEZE it 8 s at STN_FREEZER (or instantly with ABL_067 Freeze Touch) | temp = FROZEN | 15 % | 5 | PER_023, PER_007 | No |
| `MOD_044` | "Extra hot! Steam should come out of my ears." | TEMP | heat-cooked items | Serve while Sizzling: within 10 s of leaving heat (a STN_WINDOW heat-lamp spot pauses the clock) | hotFrac ≥ 0.5 | 10 % | 1 | PER_022, PER_005 | No |
| `MOD_045` | "Lukewarm. Like a bath a duck already used." | TEMP | heat-cooked items | Let it cool out of HOT into WARM (≥ 20 s off heat), never chilled or frozen | temp = WARM and wasHeated | 8 % | 1 | PER_006, PER_024 | No |
| `MOD_046` | "So cold it hurts my feelings." | TEMP | DRK items | Add ≥ 2 ING_ICE, then set the cup on the STN_FRIDGE Chill Shelf for 3 s | temp = COLD and frosty | 10 % | 1 | PER_023, PER_021 | No |
| `MOD_047` | "Frozen salad. A freezing salad. A salad-sicle." | TEMP | SAL items | FREEZE the plated salad 10 s at STN_FREEZER | temp = FROZEN | 12 % | 5 | PER_023, PER_021 | No |
| `MOD_048` | "Freeze my fries. I want fry-sicles." | TEMP | RCP_FRI_001, RCP_FRI_002 | FRY at STN_FRYER, then FREEZE 5 s at STN_FREEZER | temp = FROZEN and fry grade ≥ GOOD | 12 % | 5 | PER_023, PER_007 | No |
| `MOD_049` | "Warm my ice cream. Don't let it melt. Good luck." | TEMP | RCP_DES_002, RCP_DES_004, RCP_DES_013 | Set it on a STN_WINDOW heat-lamp spot for 2–4 s, then serve | lampSec ∈ [2, 4] and not MELTY | 12 % | 4 | PER_024, PER_018 | No |
| `MOD_050` | "Hot milkshake. I know. I KNOW." | TEMP | RCP_DRK_003, RCP_DRK_004 | Warm It: pour the shake into the small pot on STN_STOVE (4 s BOIL) and back into a cup | temp = HOT | 10 % | 5 | PER_013, PER_028 | No |
| `MOD_051` | "Make my burger upside down." | SHAPE | BRG items except RCP_BRG_013 | Build normally, then Flip Stack at STN_ASSEMBLY (hold Use 0.6 s) — or build it in exact reverse order | orientation = INVERTED (stack = reverse of canonical) | 15 % | 1 | PER_024, PER_007 | No |
| `MOD_052` | "I want a cheeseburger, but I'm allergic to circles." | SHAPE | RCP_BRG_002 (this exact line); any other item with a `round` component uses "I want a {item}, but I'm allergic to circles." | Square Cut every `round` component (bun, patty, round cheese) at STN_CUT (SQUARE mode, N taps), raw or cooked; for PIZ items, serving RCP_PIZ_014 Square Circle Pizza from the menu also counts | every component with tag `round` has shape = SQUARE (or recipe = RCP_PIZ_014) | 18 % | 5 | PER_014, PER_015 | No |
| `MOD_053` | "Make my Upside-Down Burger right-side up. Upside-up. You know." | SHAPE | RCP_BRG_013 | Flip Stack the finished RCP_BRG_013 at STN_ASSEMBLY | stack = reverse of RCP_BRG_013 canonical | 15 % | 18 | PER_018, PER_011 | No |
| `MOD_054` | "Square pizza. Circles are overrated." | SHAPE | PIZ items | Square Cut ING_DOUGH at STN_CUT before topping and baking, or serve RCP_PIZ_014 | shape(base) = SQUARE (or recipe = RCP_PIZ_014) | 12 % | 3 | PER_015, PER_001 | No |
| `MOD_055` | "Cut it in half. Diagonally. Like a professional." | SHAPE | SAN items | Put the assembled sandwich on STN_CUT in HALVE mode (2 taps) | cut = HALVED_DIAGONAL | 10 % | 2 | PER_004, PER_013 | No |
| `MOD_056` | "Heart-shaped pancakes for my sweetie." | SHAPE | RCP_BRK_001, RCP_BRK_003, RCP_BRK_005 | Heart Cut each cooked pancake/waffle at STN_CUT | every pancake layer shape = HEART | 12 % | 2 | PER_027, PER_031 | No |
| `MOD_057` | "Spiral fries. Twirly. Like my mood." | SHAPE | RCP_FRI_001 | Spiral Cut ING_POTATO at STN_CUT before frying | shape(ING_POTATO) = SPIRAL | 10 % | 1 | PER_009, PER_018 | No |
| `MOD_058` | "Chop it super tiny. But NOT mushy." | SHAPE | items with ≥ 1 CHOPPED `veg` component | Chop with N + 2 or N + 3 taps (TINY zone); the N + 4th tap turns it MUSHY | every chopped veg: shape = TINY and state ≠ MUSHY | 12 % | 1 | PER_020, PER_012 | No |
| `MOD_059` | "Fold my pizza like a taco. I contain multitudes." | SHAPE | PIZ items | Fold the baked pizza at STN_ASSEMBLY or STN_PLATING (hold Use 0.6 s) | fold = true | 12 % | 3 | PER_026, PER_032 | No |
| `MOD_060` | "Lay my burger on its side. It's had a long day." | SHAPE | BRG items | Tip Over at STN_PLATING | orientation = SIDEWAYS | 12 % | 5 | PER_006, PER_019 | No |
| `MOD_061` | "Make it fancy. Put a little leaf on it." | PRESENT | any plated item | Garnish (sprig) at STN_PLATING or STN_ASSEMBLY | garnish = SPRIG | 10 % | 1 | PER_004, PER_008 | No |
| `MOD_062` | "Draw a smiley face on it with ketchup." | PRESENT | BRG, FRI, SAN items, RCP_BRK_002 | Drizzle Art "Smiley" with ING_KETCHUP at STN_PLATING | drizzle = SMILEY with ING_KETCHUP | 12 % | 5 | PER_020, PER_031 | No |
| `MOD_063` | "Put a candle on it. It's my birthday. Again." | PRESENT | DES items | Garnish "Candle" at STN_PLATING or STN_ASSEMBLY | garnish = CANDLE | 10 % | 3 | PER_031, PER_016 | No |
| `MOD_064` | "Don't let any of the foods touch each other." | PRESENT | plated items with ≥ 3 components (BRK, SEA, SAL, FRI) | Spread Out at STN_PLATING (each component in its own plate zone) | layout = SEPARATED | 12 % | 5 | PER_014, PER_012 | No |
| `MOD_065` | "Wrap it like a present. I'll act surprised." | PRESENT | DES items and any boxable item | Box It, then Gift Wrap at STN_PLATING | container = BOX and wrapped | 12 % | 5 | PER_031, PER_027 | No |
| `MOD_066` | "Serve it with a dramatic 'TA-DA!'" | PRESENT | any item | Flourish Serve: hold Use 0.8 s while serving | serve.flourish = true | 8 % | 1 | PER_018, PER_009 | No |
| `MOD_067` | "Chocolate drizzle. Zig-zag. Make it art." | PRESENT | DES items, RCP_BRK_001, RCP_BRK_003 | Drizzle Art "Zig-Zag" with ING_CHOCOLATE at STN_PLATING | drizzle = ZIGZAG with ING_CHOCOLATE | 10 % | 5 | PER_009, PER_008 | No |
| `MOD_068` | "Squeaky-clean plate. I want to see my faces in it." | PRESENT | any plated item | Sparkle Polish a clean plate at STN_DISHWASH (3 green taps), then plate on it | plateGrade = SPARKLING | 10 % | 1 | PER_025, PER_013 | No |
| `MOD_069` | "Cheese UNDER the patty. I'm a rebel." | SEQUENCE | BRG items with a `cheese` component | Place each cheese layer before its patty at STN_ASSEMBLY | stackIndex(cheese) < stackIndex(patty) for every pair | 12 % | 1 | PER_007, PER_018 | No |
| `MOD_070` | "Sauce goes on first. Everything else is a guest." | SEQUENCE | stacked items (BRG, SAN, TAC) with a `sauce` component | Put the sauce directly on the base (bottom bun, bread or tortilla) | stack position 2 has tag `sauce` | 10 % | 1 | PER_004, PER_001 | No |
| `MOD_071` | "Swap the buns. Top on bottom, bottom on top. Middle stays." | SEQUENCE | BRG items | Place the bun TOP half first and the bun BOTTOM half last; middle in normal order | stack[1] = bun TOP, stack[n] = bun BOTTOM, interior canonical | 14 % | 1 | PER_024, PER_011 | No |
| `MOD_072` | "Put the fries IN the burger." | SEQUENCE | BRG items | Add a FRIED ING_POTATO layer directly under the top bun | stack position n − 1 = fried ING_POTATO | 10 % | 1 | PER_002, PER_007 | No |
| `MOD_073` | "Pepperoni under the cheese, like a secret." | SEQUENCE | PIZ items with ING_PEPPERONI and ING_MOZZARELLA | Place pepperoni on the dough before the mozzarella at STN_ASSEMBLY | stackIndex(ING_PEPPERONI) < stackIndex(ING_MOZZARELLA) | 12 % | 3 | PER_011, PER_025 | No |
| `MOD_074` | "Mix it backwards. I want to taste the chaos." | SEQUENCE | items with a MIXED component (batter, dough) | Insert the mix ingredients in exact reverse order at STN_MIXER (or hand-mix at STN_PREP) | seqReversed(mixed component) = true (sequence factor treated as 1.0) | 14 % | 6 | PER_007, PER_032 | No |
| `MOD_075` | "Soup first, THEN the cereal. Fight me." | SEQUENCE | RCP_BRK_007 | Ladle the soup into the bowl before adding the cereal (Combine at STN_PREP) | stackIndex(soup) < stackIndex(cereal) | 12 % | 22 | PER_018, PER_028 | No |
| `MOD_076` | "Make my drink angry." | MOOD | DRK items except RCP_DRK_007 | After POUR, Agitate at STN_DRINK (hold Use) until the shake meter sits in ANGRY (70–95), release and pick the cup up before it settles below 70 | mood = ANGRY (FURIOUS also counts) | 12 % | 3 | PER_022, PER_030, PER_005 | No |
| `MOD_077` | "Make my drink calm. It's had a long day." | MOOD | DRK items (incl. RCP_DRK_007: "calm my Angry Coffee down") | Never agitate; leave the cup resting on STN_DRINK for 4 s after pouring | mood = CALM | 10 % | 1 | PER_003, PER_006, PER_012 | No |
| `MOD_078` | "Make my drink happy! Birthday happy!" | MOOD | DRK items | Add 1 ING_SUGAR, then Agitate lightly into the 30–55 band | mood = HAPPY | 12 % | 2 | PER_031, PER_020 | No |
| `MOD_079` | "I want a sad drink. It can cry. It's okay." | MOOD | DRK items | Add ING_LEMON and ≥ 1 ING_ICE, never agitate, rest 4 s | mood = SAD | 12 % | 2 | PER_018, PER_012 | No |
| `MOD_080` | "Make it confused. Angry, then calm. Like my uncle." | MOOD | DRK items | Agitate into ANGRY, then let it rest on STN_DRINK until the meter decays to ≤ 15 before pickup | mood = CONFUSED (peak ≥ 70, final ≤ 15) | 15 % | 8 | PER_007, PER_011 | No |
| `MOD_081` | "Make my Angry Coffee FURIOUS." | MOOD | RCP_DRK_007 | Agitate into the narrow FURIOUS band (88–95) and pick up immediately | mood = FURIOUS | 15 % | 13 | PER_030, PER_005 | No |
| `MOD_082` | "Give me a pizza with absolutely no pizza." | JOKE | PIZ items | Play Along: Box It an EMPTY pizza box at STN_PLATING (or STN_ASSEMBLY) and serve the box | kind = EMPTY_BOX and boxType = PIZZA | 20 % | 3 | PER_019, PER_007, PER_032 | Yes — Straight Answer: serve the real pizza ("Fine. I'll eat the pizza.") → sat 0.75, no bonus |
| `MOD_083` | "Can I get that to go? I'm staying here." | JOKE | BRG, PIZ, FRI, TAC, SAN items | Play Along: Box It with the finished food inside, then serve it at their seat | container = BOX and contents match the item | 15 % | 3 | PER_026, PER_011 | Yes — Straight Answer: serve on a plate → 0.75 |
| `MOD_084` | "I want a burger, but hold the burger." | JOKE | BRG items | Play Along: assemble a "Bun Sandwich" — only the ING_BUN halves | components ⊆ {ING_BUN} and count(ING_BUN) ≥ 1 | 15 % | 1 | PER_019, PER_021 | Yes — Straight Answer: the normal burger → 0.75 |
| `MOD_085` | "Hold the ketchup. No, literally. HOLD it." | JOKE | items containing ING_KETCHUP | Play Along: leave ketchup off the dish AND either serve while carrying an ING_KETCHUP bottle as a second item, or first Offer the bottle (Use on the customer while holding it) | count(ING_KETCHUP) = 0 and (bottle in server carry stack or customer.offered = ING_KETCHUP) | 15 % | 1 | PER_028, PER_007 | Yes — Straight Answer: simply omit the ketchup → 0.75 |
| `MOD_086` | "Bring it to me while hopping." | JOKE | any item | Play Along: Hop Serve — jump and serve while airborne or ≤ 0.5 s after landing | serve.airborne = true | 15 % | 1 | PER_020, PER_026 | Yes — Straight Answer: normal serve → 0.75 (wobbly-gait morphs with mismatched legs pass automatically) |
| `MOD_087` | "I only eat food cooked by someone with a tail." | JOKE | heat-cooked items | Play Along: the final heat step must be done by a player or employee wearing a TAIL part (generated only if the owner owns one or a tailed employee works a heat station) | lastHeatActor.slots contains TAIL | 20 % | 5 | PER_032, PER_029 | Yes — Straight Answer: normal dish → 0.75 |
| `MOD_088` | "Just bring me the plate. I'll imagine the rest." | JOKE | any plated item | Play Along: Present Nothing at STN_PLATING (clean plate + garnish) | kind = EMPTY_PLATE and garnish ≠ NONE | 20 % | 5 | PER_019, PER_006 | Yes — Straight Answer: the real dish → 0.75 |
| `MOD_089` | "Surprise me! But not THAT surprising." | JOKE | DRK items | Play Along: serve a Mystery Smoothie (any non-recipe blend from STN_BLENDER) instead of the drink | kind = MYSTERY and container = CUP | 18 % | 5 | PER_007, PER_032 | Yes — Straight Answer: the ordered drink → 0.75 |
| `MOD_090` | "I want my soup… as a hat." | JOKE | SOP items | Play Along: FREEZE the soup bowl at STN_FREEZER, then Flip Out at STN_PLATING (a wobbly soup dome) | temp = FROZEN and orientation = INVERTED and container = PLATE | 22 % | 5 | PER_007, PER_018 | Yes — Straight Answer: normal soup → 0.75 |
| `MOD_091` | "Make my pancakes fly." | JOKE | RCP_BRK_001, RCP_BRK_005, RCP_ALN_006 | Play Along: FLOAT the cooked pancakes at STN_ANTIGRAV and serve within the 6 s hover | state = FLOATED and now < hoverUntil | 20 % | 30 | PER_029, PER_026 | Yes — Straight Answer: normal pancakes → 0.75 |
| `MOD_092` | "Blend my burger. I want to drink it." | JOKE | BRG items | Play Along: put every finished component of the burger into STN_BLENDER and blend to SMOOTH ("Burger Smoothie") | kind = MYSTERY and sourceRecipeId = ordered recipe and blend grade ≥ GOOD | 20 % | 5 | PER_007, PER_002 | Yes — Straight Answer: the normal burger → 0.75 |
| `MOD_093` | "Add a little chaos. A smidge of mutation." | JOKE | any non-MUT item with a cooked component | Play Along: INFUSE one cooked component at STN_INFUSER with ING_MUTAGEN_GOO (the canon Mutation Cuisine effect applies: 60 s cosmetic part) | any component state = INFUSED | 25 % | 40 | PER_032, PER_007 | Yes — Straight Answer: the normal dish → 0.75 |

#### 6.18.7 UI

- **Taking the order:** the customer's speech bubble shows the quote (2.5 s + 0.05 s per character, gibberish voice in the
  personality's register); chips then fly onto the ticket.
- **Chips** (ticket rail, HUD ticket strip, held-dish checklist): category icon + ≤ 14-character text. Icons are
  shape-coded so colour is never required: OMIT slashed circle, EXTRA plus, COUNT hash with the number, DONENESS flame
  gauge, TEMP thermometer/snowflake, SHAPE outline (square/heart/arrow), PRESENT sparkle, SEQUENCE stacked arrows, MOOD
  tiny drink face, JOKE jester hat with a dashed chip border. Hidden mods: "???" with an ear icon ("Ask Again").
- **Station hints for the pinned ticket:** target bands drawn on meters (purple striped SCREAM band, RARE and WELL_DONE
  bands on heat bars, the ANGRY/HAPPY band on the shake meter), the count chip at `STN_ASSEMBLY`, a snowflake badge on
  `STN_FREEZER`, a box badge on the box stack.
- **Held-dish checklist:** chips float above the carried dish with ✓ (satisfied), ✗ (broken), ○ (pending) — distinct
  shapes; predicted on the client from the replicated `DishSummary`, confirmed by the server at serve.
- **Serve result:** pop-up over the customer with quality stars, each mod's ✓/✗, and "+18 % Weird Bonus!" when earned.
- **Jokes:** the first time a player meets each joke mod, a one-time tooltip explains Play Along vs Straight Answer; with
  "Fewer Weird Requests" the hint is always shown. `MOD_085`'s **Offer** prompt appears when holding a sauce bottle within
  10 studs of that customer.
- **Weird Request Journal** (Restaurant menu → Orders tab): lists every mod met and satisfied at least once (93 entries,
  silhouettes until met) — a light collection hook that §14 may tie to achievements.

#### 6.18.8 Roblox implementation

| Location | Module | Contents |
|---|---|---|
| `ReplicatedStorage/Shared/Data/ModDefs` | shared data | per mod: `Id`, `Quote`, `Chip`, `Icon`, `Category`, `AppliesTo` (categories/tags/ids), `RequiredStations`, `Unlock`, `Bonus`, `ExtraTime`, `ConflictGroups`, `FavoredBy`, `IsJoke`, `ReplacesDish` |
| `ServerScriptService/Services/OrderService/ModGenerator` | server | §6.18.3 eligibility + seeded selection (`Random.new(seed)`) |
| `ServerScriptService/Services/OrderService/ModPredicates` | server only | one predicate per mod returning `sat_j` |
| boot validator (`TestService`/CI) | server | asserts every `ModDefs` entry has a predicate, every required station's canon §C7.1 level ≤ `Unlock`, and every referenced `PER_`/`RCP_`/`ING_` id exists in `RecipeService`/`CustomerAIService` data |

```lua
--!strict
-- ServerScriptService/Services/OrderService/ModPredicates.lua (excerpt)
local Dishes = require(script.Parent.Parent.CookingService.Dishes)
local ModDefs = require(game:GetService("ReplicatedStorage").Shared.Data.ModDefs)

export type Ctx = {
	dish: Dishes.Dish, recipe: any, servedRecipeId: string, dishMatchesItem: boolean,
	serve: { flourish: boolean, airborne: boolean, now: number }, offered: string?, carried: { string },
	waived: { [string]: boolean },
}

local function count(d: Dishes.Dish, ing: string): number
	local n = 0
	for _, c in d.components do
		if c.ing == ing then n += c.count end
	end
	return n
end

local P: { [string]: (Ctx) -> number } = {}
P.MOD_001 = function(x) return if count(x.dish, "ING_PICKLE") == 0 then 1 else 0 end
P.MOD_020 = function(x)
	local d = math.abs(count(x.dish, "ING_PICKLE") - 17)
	return if d == 0 then 1 elseif d == 1 then 0.5 else 0
end
P.MOD_029 = function(x) return if Dishes.ProteinBand(x.dish, x.recipe) == "SCREAMING" then 1 else 0 end
P.MOD_043 = function(x) return if x.dish.temp == "FROZEN" then 1 else 0 end
P.MOD_051 = function(x) return if Dishes.IsReverseOf(x.dish, x.recipe.CanonicalStack) then 1 else 0 end
P.MOD_052 = function(x)
	if x.servedRecipeId == "RCP_PIZ_014" then return 1 end
	return if Dishes.AllTaggedHaveShape(x.dish, "round", "SQUARE") then 1 else 0
end
P.MOD_076 = function(x) return if x.dish.mood == "ANGRY" or x.dish.mood == "FURIOUS" then 1 else 0 end
P.MOD_082 = function(x)
	if x.dish.kind == "EMPTY_BOX" and x.dish.boxType == "PIZZA" then return 1 end
	return if x.dishMatchesItem then 0.75 else 0 -- Straight Answer
end

-- Returns ModScore, bonus fraction (capped), per-mod results. Called by OrderService at serve (§5.6.5 step 7).
local function Evaluate(ctx: Ctx, mods: { string }): (number, number, { [string]: number })
	local sum, bonus, results = 0, 0, {}
	for _, id in mods do
		local waived = ctx.waived[id] == true
		local sat = if waived then 1 else P[id](ctx)
		results[id] = sat
		sum += sat
		if sat == 1 and not waived then bonus += ModDefs[id].Bonus end
	end
	return (1 + sum) / (1 + #mods), math.min(0.40, bonus), results
end

return { Predicates = P, Evaluate = Evaluate }
```
Analytics (§31): `mmr_mod_generated` {modId, tier, personalityId, hidden}, `mmr_mod_result` {modId, sat, waived, bonusPct}.

#### 6.18.9 Edge cases

| # | Situation | Ruling |
|---|---|---|
| M1 | A required station breaks or is destroyed after the order was placed | The mod is **waived** (sat 1, no bonus, chip shows "WAIVED"); the customer shrugs ("Eh, forget the frozen thing."). |
| M2 | `EMP_001` Ollie's 5 % stray-pickle trait hits a modded order | The pickle is real: `MOD_001` fails, `MOD_020` becomes a near miss; the ticket shows "Ollie strikes again!" — canon trait, pure comedy. |
| M3 | Same recipe ordered twice with different mods (one customer or a party) | The dish is assigned to the open item where it scores the highest `A` (§5.6.5 step 6); window binding does the same across tickets. |
| M4 | Customer leaves; their modded dish is reused (orphan) | Mods are re-evaluated against the new item's mods; the orphan's extra work earns nothing unless it matches. |
| M5 | A hidden mod is never revealed and fails | Verified normally, but §10 applies no anger bump for unrevealed hidden mods; the complaint line reveals it ("I SAID no onions! …I think I said it."). |
| M6 | `ABL_066` used on a component that has a doneness mod | Finished-at-GOOD never satisfies a band-specific doneness mod (§5.11 X12); TEMP "extra hot" is still satisfiable (the item is HOT). |
| M7 | Temperature mods at TIER_03+ table service (long walks) | A heat-lamp spot pauses the HOT clock; FROZEN lasts 45 s outside; `ABL_069` Hover Serve shortens trips; the time-budget filter already accounts for the walk via EstPrep. |
| M8 | Dish-replacing joke (empty box, bun sandwich, empty plate) | Pays full price + bonus; only ingredients actually used are netted; the reserved special stock is released. |
| M9 | Recipe data changes so an omitted ingredient is no longer in the recipe | New orders filter the mod out (eligibility rule 2); an existing OMIT for an absent ingredient auto-passes. |
| M10 | `MOD_087` (tail) and the player unequips their tail mid-order | Straight Answer (0.75) remains; eligibility is checked only at order time. |
| M11 | Counter service: an empty pizza box is placed on a window spot | It binds only to an open item carrying `MOD_082`; otherwise the spot shows "?". |
| M12 | Mods that need several steps in sequence (FREEZE then Flip Out) | Allowed; only the final Dish state is verified, so step order matters only where the predicate says so. |
| M13 | Offline and employee handling | Offline simulation ignores individual mods (§17 uses aggregate quality). Online employee chefs attempt mods with a success chance defined in §16 from their Accuracy and the category difficulty (§6.18.2). |
| M14 | "Fewer Weird Requests" toggled mid-service | Applies to orders placed after the change only. |
| M15 | Co-op | Any player may perform any mod step (canon E7); the bonus is part of the restaurant's pay as usual. |

#### 6.18.10 Acceptance criteria

- **AC-06-81** — `ModDefs` contains `MOD_001`–`MOD_093` (93 entries), each with a server predicate; the boot validator fails the
  build if any predicate, station reference or `PER_`/`RCP_`/`ING_` reference is missing.
- **AC-06-82** — In 100,000 simulated orders over all tiers with randomised kitchens, 0 mods are generated whose required
  stations are not owned, placed and usable.
- **AC-06-83** — Max mods per item (1 at TIER_01–03, 2 at TIER_04–07, 3 at TIER_08+) is never exceeded, and the observed
  P(item has ≥ 1 mod) per tier is within ± 1.5 percentage points of `min(0.85, P1 × Aff)` (with eligible mods available).
- **AC-06-84** — No item ever carries two mods from the same conflict group (100,000-order simulation).
- **AC-06-85** — For 100 % of generated items, `EstPrep + Σ ExtraTime ≤ 0.6 × Patience`.
- **AC-06-86** — Regenerating an order from the same `orderId` seed reproduces exactly the same mods.
- **AC-06-87** — A scripted bot completes each of the seven brief examples (`MOD_020`, `MOD_029`, `MOD_043`, `MOD_051`, `MOD_052`,
  `MOD_076`, `MOD_082`) in a test restaurant at the mod's unlock level using only stations available at that level, and the
  server returns sat = 1 for each.
- **AC-06-88** — A joke Straight Answer yields sat 0.75, no bonus and no anger change.
- **AC-06-89** — COUNT mods: exact → 1; off by 1 → 0.5; off by ≥ 2 → 0.
- **AC-06-90** — Pay: bonuses apply only to satisfied, non-waived mods, are capped at 40 % per item, and tips are computed from
  menu prices only; the §6.18.5 example pays exactly 12 MB.
- **AC-06-91** — `A_item` reproduces the §6.18.4 examples (0.5, 0.75, 0.875) to ± 0.001.
- **AC-06-92** — Every mod chip shows a shape-coded icon plus ≤ 14 characters of text on the ticket rail, HUD strip and held
  dish; ✓ / ✗ / ○ states are distinguishable in greyscale.
- **AC-06-93** — Hidden mods are never COUNT or JOKE; Ask Again reveals them in 1.5 s; `ABL_064` reveals all hidden mods within
  its radius instantly.
- **AC-06-94** — Breaking a required station after ordering marks the mod "WAIVED" with sat 1 and 0 bonus.
- **AC-06-95** — No mods appear during `QST_TUT_001`–`QST_TUT_005`; the first mod afterwards is `MOD_001`.
- **AC-06-96** — In a 10-hour simulated TIER_05 session, mod bonuses add between +2 % and +5 % to item revenue.

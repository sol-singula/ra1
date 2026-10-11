## 39. Balancing Assumptions

This section consolidates every balancing assumption fixed in canon into one tuning reference, grouped by
system. The **Value** column is the launch value and must equal the canon value; the other columns say why
it is that number, how we will know it is wrong, how far it may move without a redesign, and who owns it.
Sections §5–§33 remain the specification of each rule — this is the dashboard. LiveConfig production
defaults are generated from these tables (AC-39-02).

### 39.1 How to Read the Tables

- **[T]** in the Parameter cell = marked [TUNABLE] in canon. Rows without [T] are canon-fixed balancing
  values: they are listed because they shape the economy, but changing them needs a canon change and a
  section update, not just a LiveConfig edit.
- **Safe tuning range** = the band inside which the value may move by LiveConfig (or a data release)
  without re-validating dependent systems. "Locked" = do not tune live.
- **Telemetry signal** = the metric (§31) that tells us the value is off. "Median" is over active players
  of the relevant tier/level band, computed weekly.
- **Owner roles** (team of §34.1): **Design-Econ**, **Design-Sys**, **Design-Cbt** (hats of the designer),
  **Lead Eng**, **Producer**, **Art Dir**.

### 39.2 Global Constants (§C3, §C16.1)

| Parameter | Value | Unit | Rationale | Telemetry signal | Safe tuning range | Owner |
|---|---|---|---|---|---|---|
| Max players per server [T] | 8 | players | 8 plots on Restaurant Row; mobile server budget | avg players/server; P-03 heartbeat; friend-join failures | 6–12 (major update only, OD-01) | Lead Eng |
| Restaurants per player | 1 | restaurant | launch scope | — | Locked (OD-05) | Design-Sys |
| Autosave interval [T] | 120 | s | caps data-loss window vs DataStore budget | DataStore request rate; throttle warnings; lost-progress reports | 60–180 | Lead Eng |
| Extra save on purchase | ≥ 10,000 | MB | protects big purchases between autosaves | saves per minute | 5,000–25,000 | Lead Eng |
| Base WalkSpeed | 16 | studs/s | familiar Roblox feel | — | Locked | Design-Sys |
| Max WalkSpeed (MOVE cap) | 20.8 (labelled ≈ 21) | studs/s | faster kitchens without breaking validation | median station-to-station time | 19–22 | Design-Sys |
| Carry capacity: base / per boosting part / hard max | 1 / +1 / 3 | items | juggling skill; prevents hoarding | items carried per serve | hard max 2–4 | Design-Sys |
| Interaction range: stations / customers / server tolerance | 7 / 10 / +2 | studs | phone reach; anti-teleport | rejected interactions per 1,000 | 6–9 / 8–12 / 1–3 | Lead Eng |
| Customers per restaurant | seats + 4 queue (max 28) | customers | throughput vs crowding | queue abandonment rate | queue 2–6 | Design-Sys |
| Server customer-proxy hard cap | 160 | proxies | server CPU at 8 busy restaurants | P-03 heartbeat; throttled spawns | 120–200 | Lead Eng |
| Loose physics props per interior | 30 | props | physics budget during chaos | physics step time | 20–40 | Lead Eng |
| Client debris lifetime | 4 | s | readability vs clutter | client particle count | 2–6 | Art Dir |
| City lighting cycle | 24 | min | cosmetic; night-only discoveries | — | 16–40 | Art Dir |
| Daily / weekly reset | 00:00 UTC / Monday 00:00 UTC | clock | one global rule | — | Locked | Producer |
| Level cap | 100 | level | ≈ 200-hour arc | % of players at cap | Locked at launch | Design-Sys |
| Reputation start / range | 2.5 / 1.0–5.0 | ★ | start mid-scale | Stars distribution by tier | Locked | Design-Sys |
| Return Door cooldown | 10 | s | free fast return without abuse | uses per session | 5–30 | Design-Sys |
| Pigeon Taxi fare | 25 × tier | MB | small convenience sink | rides per DAU | 10–50 × tier | Design-Econ |

### 39.3 Currencies and Economy (§C4.2–§C4.9)

#### 39.3.1 Prices, spend and pacing

| Parameter | Value | Unit | Rationale | Telemetry signal | Safe tuning range | Owner |
|---|---|---|---|---|---|---|
| Recipe base price [T] | `10 × 1.05^(L−1)` (L1 ≈ 10 … L95 ≈ 975) | MB | smooth value growth with unlock level | median ticket by tier vs §C4.3 | growth 1.04–1.06 | Design-Econ |
| Difficulty factor [T] | `0.8 + 0.1 × D` (D 1–5) | × | harder dishes pay more | orders/h and margin by difficulty | slope 0.05–0.15 | Design-Econ |
| Category factor [T] | Drinks/Fried/Salads 0.7 · Desserts 0.8 · Legendary 2.5 · others 1.0 | × | add-ons cheaper; Legendary aspirational | revenue share by category | ±0.1 (Legendary 2.0–3.0) | Design-Econ |
| Flavor variance [T] | ±15 | % | dish identity | — | 0–20 | Design-Econ |
| Ingredient cost target [T] | 25–40 % of price | % | 60–75 % gross margin | realized margin per recipe | 20–45 | Design-Econ |
| Items per customer | 1.4 (main + 40 % add-on) | items | ticket size | items per customer | 1.2–1.8 | Design-Econ |
| Recipe learning cost | 5 × price | MB | sink and pacing gate | days from unlock to learn | 3–8 × price | Design-Econ |
| Net income target by tier [T] | 630 · 1,080 · 1,730 · 3,100 · 5,400 · 9,600 · 17,400 · 32,800 · 63,700 · 120,500 (`TIER_01` → `TIER_10`) | MB / active h | pacing anchor incl. tips, after ingredients and online wages, ~15 % quests/events | median net MB per active hour by tier | retune if outside ±15 % for 2 weeks | Design-Econ |
| Cumulative active hours to reach tier [T] | 0 · 1 · 3 · 7 · 14 · 25 · 40 · 60 · 85 · 120 | h | first tier upgrade inside session 1 | median active hours to each tier | ±20 % | Design-Econ |
| Spend split intent [T] | ≈ 50 % tier/expansion · ≈ 50 % mutations, furniture, staff, upgrades | % | morph-centric economy | sink share by category | 40–60 % | Design-Econ |
| Time to L100 [T] | ≈ 200 (formula gives ≈ 185) | active h | long-term arc | median time-to-L100 (cohort) | 160–240 | Design-Sys |
| Stat respec | free once per 24 h, else 500 × level | MB | encourage experimenting | respecs per week | 250–1,000 × level | Design-Econ |
| Auto-rebuild of Destroyed object | ≤ 25 % of item price | % | destruction funny, not punishing | rebuilds per day; rebuild MB share | 10–35 % | Design-Econ |

#### 39.3.2 Mutation shop, upgrades and capsules

| Parameter | Value | Unit | Rationale | Telemetry signal | Safe tuning range | Owner |
|---|---|---|---|---|---|---|
| Shop price — Common [T] | 150–400 | MB | first purchase within session 1 | time to first purchase | ±25 % | Design-Econ |
| Shop price — Uncommon [T] | 800–2,000 | MB | | purchases per week by rarity | ±25 % | Design-Econ |
| Shop price — Rare [T] | 4,000–10,000 + 20 MS | MB, MS | Mart rotation aspiration | | ±25 % (MS 10–40) | Design-Econ |
| Shop price — Epic [T] | 25,000–60,000 + 80 MS | MB, MS | mid-game goal | | ±25 % (MS 50–120) | Design-Econ |
| Shop price — Legendary [T] | 150,000–400,000 + 250 MS + 10 RT | MB, MS, RT | weekly Mystery Market chase | | ±25 % (RT 5–20) | Design-Econ |
| Mythic fusion | 3 Legendary (same category) + 600 MS + 40 RT | — | prestige, never sold | fusions per week | MS 400–900; RT 25–60 | Design-Econ |
| Upgrade MB [T] | `BaseMB × 1.5^(L−1)`; BaseMB 100 · 300 · 900 · 3,000 · 10,000 · 30,000 · Secret 15,000 | MB | exponential late sink | upgrades per level band | growth 1.4–1.6 | Design-Econ |
| Upgrade MS [T] | `BaseMS × L`; BaseMS 2 · 4 · 8 · 15 · 30 · 50 · Secret 40 | MS | shard sink | median MS balance | ±30 % | Design-Econ |
| Upgrade RT [T] | `RTBase × (L − 3)` for Epic+ at L ≥ 4; RTBase 1 · 2 · 4 · Secret 3 | RT | gates the top levels | median RT balance; RT earned/week | ±1 per base | Design-Econ |
| Max upgrade level | 5 · 6 · 7 · 8 · 9 · 10 · Secret 10 | level | rarity ceiling | % parts at max | Locked | Design-Sys |
| Duplicate → MS / DupeSubstituteMS [T] | 5/10 · 12/25 · 30/60 · 80/160 · 200/400 · 500/1,000 · Secret —/600 | MS | duplicates always useful | dupes kept vs converted | ±30 % | Design-Econ |
| Capsule odds (disclosed) | Common 55 · Uncommon 27 · Rare 12 · Epic 4.5 · Legendary 1.3 · Mythic 0.2 · Secret 0 | % | earnable only, transparent | observed vs disclosed | change only with a same-release disclosure update | Design-Econ |
| Capsule pity | 40 | capsules | guaranteed Epic+ | capsules to first Epic+ | 30–50 (never raised on existing counters) | Design-Econ |
| Offline capsule discovery | ≤ 1 per real day | capsules | offline complements, not replaces | capsules per DAU by source | Locked | Design-Econ |
| Welcome Back Crate | 1 capsule + 50 MS after ≥ 7 days away | — | lapsed-player return | reactivation rate | 5–14 days; 25–100 MS | Design-Econ |

#### 39.3.3 Station upgrades (§C4.9)

| Parameter | Value | Unit | Rationale | Telemetry signal | Safe tuning range | Owner |
|---|---|---|---|---|---|---|
| Upgrade cost multiplier Lv2 / Lv3 / Lv4 / Lv5 [T] | × 1.5 / × 4 / × 10 / × 25 of station base price | × | late levels are big goals | station level distribution by tier | ±25 % each | Design-Econ |
| Process-time multiplier Lv2 / Lv3 / Lv4 / Lv5 [T] | 0.90 / 0.80 / 0.70 / 0.60 | × | felt speed-ups | median ticket time by station level | ±0.05 each | Design-Sys |
| Perfect-window multiplier Lv3–Lv4 / Lv5 [T] | × 1.25 / × 1.5 | × | skill forgiveness | PERFECT rate by station level | 1.1–1.4 / 1.3–1.7 | Design-Sys |
| Lv4 burn grace / non-heat failure reduction [T] | +3 s / −50 % | s, % | fewer fires late game | burns per 100 items | +2–5 s / −30–70 % | Design-Sys |
| Tier required for Lv2 / Lv3 / Lv4 / Lv5 | `TIER_02` / `TIER_04` / `TIER_06` / `TIER_08` | tier | pacing | — | Locked | Design-Sys |

### 39.4 Player Statistics and XP (§C5, §C5.1, §C18)

| Parameter | Value | Unit | Rationale | Telemetry signal | Safe tuning range | Owner |
|---|---|---|---|---|---|---|
| Stat points per level / max allocated per stat / total at L100 [T] | 2 / 50 / 198 | points | specialization without min-maxing one stat | allocation distribution | 1–3 / 40–60 | Design-Sys |
| COOK_SPD [T] | time × `1/(1 + 0.006·S)`, cap 150 (× 0.526) | — | visible speed-up | median process time by stat band | coeff 0.004–0.008 | Design-Sys |
| COOK_QLT [T] | window × `(1 + 0.005·S)`, burn delay +0.4 %/pt, cap 150 (× 1.75) | — | forgiveness for skill builds | PERFECT rate by stat band | coeff 0.003–0.007 | Design-Sys |
| STR [T] | dmg × `(1 + 0.008·S)`, knockback +0.4 %/pt, cap 150 (× 2.2) | — | combat build identity | TTK of customers by stat band | coeff 0.006–0.01 | Design-Cbt |
| DEF [T] | taken × `100/(100 + S)`, cap 200 (× 0.333) | — | diminishing returns | KOs per hour by stat band | cap 150–250 | Design-Cbt |
| REPAIR [T] | speed × `(1 + 0.01·S)`, cost −0.2 %/pt (max −30 %), cap 150 (× 2.5) | — | repair build identity | repair seconds per object | coeff 0.007–0.013 | Design-Sys |
| MOVE [T] | WalkSpeed `16 × (1 + 0.003·S)`, cap 100 (20.8) | studs/s | bounded for validation | movement-violation false positives | cap 80–120 | Design-Sys |
| LUCK [T] | drop weight × `(1 + 0.004·S)`, Jackpot +0.1 %/pt, cap 150 (× 1.6) | — | fun spikes | jackpot rate by LUCK band (15.5 % at cap) | jackpot coeff 0.05–0.1 %/pt | Design-Econ |
| CHARM [T] | patience × `(1 + 0.004·S)`, escalation × `100/(100 + S)`, cap 150 (× 1.6) | — | service build identity | storm-outs per 100 customers | coeff 0.003–0.005 | Design-Sys |
| EFFICIENCY [T] | ingredient cost × `(1 − 0.0015·S)`, employee output +0.1 %/pt, cap 150 (× 0.775, +15 %) | — | manager build identity | realized margin by stat band | coeff 0.001–0.002 | Design-Econ |
| Player HP | `100 + 2 × (Level − 1)` + mutation bonuses | HP | gentle growth | KOs per hour by level | Locked | Design-Cbt |
| XP to next level [T] | `round((180 + 30·L) × 1.045^(L−1))` (L1 210 · L10 713 · L80 83,523) | XP | calibrated to tier pacing | median hours per level band | growth 1.04–1.05 | Design-Sys |
| Reference XP rate [T] | `900 × 1.045^(L−1)` per active h (≈ 75 % cooking/serving) | XP/h | all rewards expressed against it | median XP/h by level band | ±15 % before retune | Design-Sys |
| Daily-quest XP | ≈ 0.25 × XPRate(L) | XP | dailies matter without dominating | XP share by source | 0.15–0.35 × | Design-Sys |
| Skill points | 1 per level from L2 (99 by L100) + grants; free tree respec every 7 days | points | meaningful choices | nodes bought per tree | Locked | Design-Sys |

### 39.5 Restaurant Tiers (§C6)

| Parameter | Value (`TIER_01` → `TIER_10`) | Unit | Rationale | Telemetry signal | Safe tuning range | Owner |
|---|---|---|---|---|---|---|
| Upgrade cost [T] | 0 · 1,000 · 2,000 · 5,000 · 15,000 · 40,000 · 100,000 · 225,000 · 525,000 · 1,500,000 | MB | ≈ 50 % of income goes to tiers | median hours saving for next tier | ±20 % | Design-Econ |
| Required level [T] | 1 · 5 · 10 · 18 · 26 · 35 · 45 · 56 · 68 · 80 | level | level and money gates arrive together | % blocked by level vs by money | ±2 levels | Design-Sys |
| Seats (max concurrent customers) [T] | 4 · 6 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 24 | seats | throughput and chaos scale | seat utilization % | ±2 (perf permitting) | Design-Sys |
| Appliance slots [T] | 6 · 8 · 10 · 12 · 14 · 16 · 18 · 20 · 22 · 24 | slots | early menu choices | % of slots used | ±2 | Design-Sys |
| Menu slots [T] | 4 · 5 · 6 · 8 · 10 · 12 · 14 · 16 · 20 · 24 | recipes | menu variety grows | distinct dishes ordered per hour | ±2 | Design-Sys |
| Employee cap [T] | 2 · 3 · 4 · 6 · 8 · 10 · 12 · 14 · 16 · 20 | employees | automation grows with tier | employees hired vs cap | ±2 | Design-Sys |
| Base demand [T] | 50 · 65 · 80 · 95 · 110 · 125 · 140 · 155 · 170 · 190 | customers/h | busy, not overwhelming | queue abandonment; idle seats | ±10 % | Design-Sys |
| Service style | counter (`TIER_01`–`TIER_02`), table (`TIER_03`+) | — | simple start | — | Locked | Design-Sys |
| Expansion Permit | required for `TIER_04`+ (cost included) | — | story gate (§20) | permit-quest completion time | Locked | Design-Sys |


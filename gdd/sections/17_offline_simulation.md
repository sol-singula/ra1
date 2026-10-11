## 17. Offline Restaurant Simulation

> Owner: A11 (Employees). Binding inputs: canon §C15 (model, persistence, idempotency), §C14.3 (caps), §C4.4 (active
> net per hour), §C22 E5 / E8 / E11. Staff, traits and management live in §16; archetypes in §36.8; incidents in §36.9.
> The reference implementation is `gdd/tools/offline_sim_examples.py` (Python 3 stdlib), which produced every number
> in §17.9 and is the golden source for the Luau `OfflineEarningsService` tests.

### 17.1 Purpose and principles

**Purpose.** When the player is in **no server at all**, their staffed restaurant keeps "operating" and they come back
to a Welcome Back report with real money, funny employee stories and a list of things to improve — the reason to
return every day (brief Part 2.5, 11, 26.8). Time spent online in the city is *not* offline time: that is Away Mode,
which runs live (§16.3.4, §18).

| Principle | How it is guaranteed |
|---|---|
| No server needs to stay running | Nothing is simulated while the player is away; the whole interval is computed once, on the next join, from persisted state |
| Server-authoritative | Only `os.time()` on a game server and the saved profile are inputs; the client sends nothing but a `reportId` to collect |
| Timestamp-based | `H_elapsed = max(0, now − lastSimAt) / 3600`; `lastSimAt` is written by every save while online and at leave (canon E1) |
| Deterministic | `Seed = FNV-1a-32("<UserId>:<lastSimAt>:<SIM_VERSION>")` → `Random.new(seed)`; fixed draw order (§17.5); money kept as fractions, rounded half-up only at payout (canon C0) |
| Capped | interval cap from the best Manager (canon §C14.3); incident caps 10 % / 15 %; hard ceiling 60 % of the tier's active net per hour |
| Idempotent | the report and `lastSimAt` are written in one session-locked `UpdateAsync`; Collect is keyed by `reportId` with a 20-entry `claimedReportIds` ring (canon E11) |
| Complements active play | target 35–50 % of active net/hour for a well-staffed restaurant (proved in §17.9); no XP, no Research Tokens, no recipes or quests offline |

### 17.2 The return procedure

The brief's 13 steps (Part 11.6) mapped onto the canon model. Steps 1–12 run inside one pure function executed in the
profile-load `UpdateAsync` transform (no yields); step 13 is the client screen.

| # | Brief step | Server action | Canon §C15 term |
|---|---|---|---|
| 1 | Retrieve last saved logout/simulation timestamp | read `profile.lastSimAt` (unset → set to `now`, no report) | `lastSimAt` |
| 2 | Determine elapsed offline time | `elapsed = now − lastSimAt`; < 0 → 0 + `mmr_offline_clock_skew`; < 300 s → no report, `lastSimAt` unchanged | `H_elapsed` |
| 3 | Apply the offline earnings cap | `H = min(H_elapsed, CapHours(best Manager, Assistant))`; hours beyond the cap are forfeited | `H`, §C14.3 |
| 4 | Calculate employee productivity | per step: RoleStatAvg → Efficiency(Morale, Energy, EFFICIENCY) → `Eff = Efficiency/100` → Contribution = Eff × TraitMult | §C14.2 |
| 5 | Estimate customer throughput | `Q = min(Demand_off, Cap_seat, Cap_kitchen, Cap_service)`; N via fractional accumulator | `Q`, `N_step` |
| 6 | Calculate revenue | `N × AvgTicket × q` (+ tips, + delivery) on the live menu (skill gate, stations, special stock) | `Revenue`, `Tips` |
| 7 | Deduct ingredient costs | basic ingredients netted per dish; special stock consumed; Stocker auto-buy inside the step | `IngredientCost` |
| 8 | Deduct employee wages | `Σ wage × hours worked` (only employees on Always/Offline Only, not training) | `Wages` |
| 9 | Apply equipment and mutation bonuses | station levels (§C4.9), traits & signatures (§16.5), Manager coordination, Glow-Up decor | elaboration |
| 10 | Calculate incidents and operational losses | incident count & draws (§36.9), caps, damage → auto-repair or deferred | `Incidents`, `Repairs` |
| 11 | Determine net profit | `Net = max(0, Σ Net_step)` with close-early rule and the 60 % ceiling | `Net_step`, `Net` |
| 12 | Save the resulting state | write `pendingOfflineReport` (merged if one exists), Energy/Morale/hours, stock, damage, `lastSimAt = now` — same `UpdateAsync` | persistence |
| 13 | Present an offline earnings report | client receives `Offline.ReportReady` → Welcome Back screen (§17.10) → `Offline.Collect(reportId)` | Collect |

```mermaid
%% diagram: offline-earnings
flowchart TD
    J["Player joins any server"] --> L["PlayerDataService UpdateAsync + session lock"]
    L --> A{"lastSimAt set?"}
    A -->|"no (new player)"| Z["lastSimAt = now, no report"]
    A -->|"yes"| B["elapsed = now - lastSimAt (server os.time)"]
    B --> C{"elapsed >= 300 s?"}
    C -->|"no"| Z2["no report, lastSimAt unchanged"]
    C -->|"yes"| D["H = min(elapsed, cap from best Manager + Assistant)"]
    D --> E{"at least 1 Chef on an offline shift?"}
    E -->|"no"| R0["zero report + hint: hire a Chef"]
    E -->|"yes"| S["Seed = FNV-1a(UserId:lastSimAt:SIM_VERSION), Random.new(seed)"]
    S --> F["for each hourly step (last one fractional)"]
    F --> G["Efficiency from Morale and Energy, Contribution with traits"]
    G --> H2["Q = min(Demand_off, Cap_seat, Cap_kitchen, Cap_service)"]
    H2 --> I["Revenue + Tips + Delivery - Ingredients (incl. auto-buy) - Wages"]
    I --> K{"Net_step < 0 ?"}
    K -->|"yes"| X["Manager closes early: void step, stop"]
    K -->|"no"| M["decay Energy and Morale, consume special stock"]
    M --> F
    X --> N["incidents: count, draws, caps; damage to auto-repair or deferred"]
    M --> N
    N --> O["discoveries: MS, crate, capsule (max 1 per UTC day)"]
    O --> P["Net = max(0, min(sum, 0.6 x active net x H)), round half-up"]
    P --> Q2["merge into pendingOfflineReport, lastSimAt = now, save atomically"]
    Q2 --> W["Welcome Back screen"]
    W --> CL["Offline.Collect(reportId): idempotent grant, ring buffer"]
```

### 17.3 Variables [TUNABLE]

| Variable | Default | Meaning |
|---|---|---|
| `SIM_VERSION` | 1 | bumped whenever any formula or table below changes; part of the seed and `reportId` |
| `MIN_OFFLINE_SECONDS` | 300 | shorter absences produce no report (server hops, teleports) |
| `OFFLINE_DEMAND_FACTOR` | 0.6 (canon) | offline share of online demand |
| `VISIT_SECONDS_OFFLINE` | 300 (canon) | seat turnover; Cap_seat = Seats × 12 /h |
| `WAITER_SECONDS` | 45 (canon) | per waiter: 80 customers/h at Contribution 1.0 |
| `ITEMS_PER_CUSTOMER` | 1.4 (canon §C4.3) | dishes per customer |
| `PREP_BONUS` / `MAX_PREPS` | 0.15 / 3 (canon) | kitchen bonus per prep |
| `CASHIER_BONUS` / `MAX_CASHIERS` | 0.10 / 3 | service bonus per cashier (`EMP_038` counts 2) |
| `NO_WAITER_FACTOR` | 0.30 (canon) | service at `TIER_03`+ without waiters |
| `DISH_FACTOR_ABSENT` | 0.80 at `TIER_04`+ (canon) | no dishwasher |
| `CLEAN_FACTOR_ABSENT` | 0.95 (`TIER_04`–`TIER_06`), 0.92 (`TIER_07`+) | no cleaner (multiplies q) |
| `Q_BASE` / `Q_SLOPE` / `Q_MAX` | 0.70 / 0.25 / 0.95 (canon) | quality from avg chef Accuracy |
| `TIP_BASE` / `TIP_SLOPE` | 0.04 / 0.04 (canon) | tip rate from avg waiter Service |
| `PROCESS_SHARE` | 0.5 | share of a dish's base time spent in station processing (station level applies to it) |
| `STATION_MULT` | Lv1 1.0 · Lv2 0.9 · Lv3 0.8 · Lv4 0.7 · Lv5 0.6 (canon §C4.9) | process-time multiplier |
| `UNFAMILIAR_PENALTY` | 0.85 | off-native role |
| `TRAIT_MULT_CAP` | 1.5 | per employee |
| `COORD_MANAGER` | min(0.10, 0.03 + 0.07 × Contribution) (+0.02 Loudmouth / `EMP_072`) | capacity multiplier |
| `COORD_ASSISTANT` | min(0.05, 0.02 + 0.03 × Contribution); total ≤ 0.15 | capacity multiplier |
| `DELIVERY_PER_COURIER` / `DELIVERY_CAP` | 0.06 × Contribution / 0.15 (+0.02 `EMP_084`) | share of revenue, limited by kitchen headroom |
| `STOCKER_DISCOUNT` | 0.05 + 0.10 × min(1, Contribution) (+0.02 Sniffer, +0.02 `EMP_088`/`EMP_090`), max 0.15 | ingredient discount |
| `SPECIAL_BASIC_SHARE` | 0.6 | part of a special recipe's ingredient cost netted per dish (the rest is pre-paid stock) |
| `ENERGY_DECAY` / `ENERGY_DECAY_MGR` / `ENERGY_DECAY_FLOOR` | 8 / 5 / 3 %/h (canon + floor) | per simulated hour |
| `MORALE_DECAY` | 1 /h (canon) | Zen Noodle 0.5 |
| `CLOSED_HOURS_ENERGY_RECOVERY` | +10 %/h | for elapsed hours beyond the cap |
| `INCIDENT_RATE` | 0.6 /h (canon) | before Security Mitigation |
| `SECURITY_MITIGATION` | Σ (0.25 × Contribution + 0.10 Bouncer + 0.05 Heavyweight), max 0.60 | incident count reduction |
| `NEG_CAP` / `POS_CAP` | 10 % / 15 % of Revenue + Tips (canon) | incident caps |
| `MAX_SAME_INCIDENT` | 2 per report | variety |
| `ASST_LOSS_MULT` | 0.8 (canon −20 %) | negative incident magnitudes |
| `COST_PER_DAMAGE_POINT` | T1 1 · T2 1.5 · T3 2.5 · T4 4 · T5 7 · T6 12 · T7 20 · T8 35 · T9 60 · T10 100 MB | damage points shown on objects |
| `REPAIR_DISCOUNT` | min(0.60, bestRepair/200 + 0.10 Wall Crawler) (canon base) | auto-repair |
| `MS_CHANCE` / `CRATE_CHANCE` / `CAPSULE_CHANCE` | 8 % / 1 % / 5 % per simulated hour (first two canon) | discoveries |
| `DISCOVERY_BOOST_CAP` | ×1.25 | Sniffer ×1.10, Lucky Charm ×1.15 |
| `OFFLINE_CEILING_SHARE` | 0.60 of §C4.4 active net/h × H | hard clamp (canon "never above 60 %") |
| `CAP_HOURS` | none 2 · Basic 4 · Experienced 8 · Elite 12 · Legendary 24; Assistant +2; max 24 (canon) | interval cap |
| `CLAIMED_RING` | 20 (canon) | idempotency ring buffer |
| `WELCOME_BACK_CRATE_DAYS` | 7 (canon E5) | absence for the crate |

### 17.4 The model in detail (A11 elaborations of canon §C15)

**Snapshot.** Everything is read from the profile as saved at `lastSimAt`: tier, reputation ★, Atmosphere, station
levels, menu (or Night Menu), special stock, roster with stats/Energy/Morale/shift/training, auto-buy budget, player
EFFICIENCY. Nothing that happened online after that time can leak in, and the snapshot never changes mid-interval.

**Who works.** Employees on *Always* or *Offline Only* shifts and not in training; a course whose `endsAt` falls inside
the interval adds the employee from the next step. No working `ROLE_CHEF` → zero report with the hint "Hire a Chef!".

**Per step k** (step length h = 1, last one fractional):

```
Eff_i          = RoleStatAvg_i × (0.6 + 0.4·M_i/100) × (0.7 + 0.3·E_i/100) × (1 + 0.001·EFFICIENCY) / 100
Contribution_i = Eff_i × TraitMult_i(role)                     (§16.5, max ×1.5)
live menu      = recipes with D ≤ 1 + floor(bestChefCook/25), stations owned, special stock ≥ 1
PrepSec_avg    = mean over live menu of PrepSec_base × (1 − PROCESS_SHARE × (1 − STATION_MULT[level]))
AvgTicket      = 1.4 × mean live price;  AvgIngredientCost = 1.4 × mean live netted ingredient cost
Coord          = COORD_MANAGER + COORD_ASSISTANT (≤ 0.15)
Demand_off     = BaseDemand × (0.5 + 0.25·★) × (0.9 + 0.003·Atmosphere + GlowUp) × 0.6
Cap_seat       = Seats × 3600 / 300
Cap_kitchen    = Σ_chefs 3600/PrepSec_avg × Contribution_c / 1.4 × (1 + 0.15·min(3, preps)) × DishFactor × (1 + Coord)
Cap_service    = tier ≤ 2 ? Cap_kitchen : waiters ≥ 1 ? Σ 80 × Contribution_w × (1 + 0.10·min(3, cashiers)) × (1 + Coord)
                                        : 0.30 × Cap_kitchen
Q              = min(Demand_off, Cap_seat, Cap_kitchen, Cap_service);  N = floor(carry + Q·h); carry keeps the fraction
q              = min(0.95, 0.70 + 0.25·avgChefAcc/100 + ChefsInstinct − GrillMaster) × CleanFactor
Revenue        = N × AvgTicket × q
Tips           = Revenue × (0.04 + 0.04·avgWaiterService/100) × (1 + 0.01·floor(cashierSkill/20)) × TipTraitMult (≤ 1.25)
Delivery       = Revenue × min(DELIVERY_CAP, Σ 0.06·Contribution_d, Cap_kitchen/Q − 1)
Ingredients    = (N + N_delivery) × AvgIngredientCost × (1 − StockerDiscount) × (1 − 0.0015·EFFICIENCY) + AutoBuy_k
Wages          = Σ wage_i × h
Net_step       = Revenue + Tips + Delivery − Ingredients − Wages
if Net_step < 0: the Manager closes early — the step is voided (no customers, no wages, its auto-buy rolled back), stop
Energy_i      −= decay_i × h   (8 %/h, 5 %/h with a Manager, minus signature/Night Owl bonuses, floor 3 %/h;
                                 Regenerator ×0.75, Unhurried ×0.5);   Morale_i −= 1 × h
special stock −= (N + N_delivery) × 1.4 × (users of that ingredient / live recipes)
```

- **Special stock and auto-buy.** At the start of each step, if a Stocker works and budget remains, each special pool is
  topped up to that step's expected need at `unit = mean(price × ratio(D) × 0.4)` × (1 − discount); the cost lands in that
  step's Ingredients, so it can never push the wallet negative (a voided step rolls it back). When a pool hits 0, every
  recipe using it is **SOLD OUT** from the next step and PrepSec_avg / AvgTicket are recomputed (§17.9 Examples D, E).
- **Incidents** (after the step loop, over operated hours H_op): `λ = H_op × 0.6 × (1 − SM)`,
  `count = floor(λ) + (rng < frac(λ))`; each draw picks an eligible §36.9 row by effective weight, a step uniformly, and
  `{n}`. Effects are fractions of `Rh` (interval Revenue+Tips+Delivery per operated hour); negatives (MB + damage
  value) are scaled to ≤ 10 % of Revenue+Tips, positives to ≤ 15 %. They are booked into their step for the report but
  do not feed the close-early test (the caps depend on the interval total, so the test uses the operating result).
- **Repairs.** Damage value → points = ceil(value / CostPerPoint[tier]) on random destructible objects (never past
  Broken). With a Repair Technician it is auto-paid at `value × (1 − discount)`; otherwise it stays visible and costs
  nothing until the player repairs (cheaper manual repair, §15).
- **Discoveries** per operated step: MS `rng < 0.08 × boost × h` → 1–3 MS; crate `rng < 0.01 × h` (×1.5 `EMP_091`) →
  5–15 units of a special ingredient the restaurant can use; capsule `rng < 0.05 × h`, at most **one per report and one
  per UTC day** (`lastOfflineCapsuleDay`).
- **Totals.** `Net = max(0, Σ Net_step + incidents − auto-repairs)`, clamped to `0.60 × ActiveNet[tier] × H_op`
  (`mmr_offline_ceiling_hit`), then rounded half-up to whole MB — the only money rounding (canon C0).
- **Closed hours.** For `elapsed − H` beyond the cap employees recover Energy +10 %/h (staff went home); Morale is
  unchanged.

### 17.5 Deterministic RNG and hourly stepping

```lua
--!strict
local function fnv1a32(s: string): number
    local h = 2166136261
    for i = 1, #s do
        h = bit32.bxor(h, string.byte(s, i))
        h = (bit32.lshift(h, 24) + h * 403) % 4294967296   -- h * 16777619 mod 2^32 without float overflow
    end
    return h
end
local seed = fnv1a32(string.format("%d:%d:%d", userId, profile.lastSimAt, SIM_VERSION))
local rng = Random.new(seed)
```

Draw order is fixed and part of `SIM_VERSION`: (1) incident extra roll, (2) per incident: row pick, step, `{n}`,
(3) per operated step in order: MS roll (+ amount), crate roll (+ units), capsule roll. Every roll is consumed even when
its result is unused (e.g. zero operated hours), so adding an incident row changes only weights, never the alignment
of later draws within a version. The deterministic economy (steps 4–9, 11) uses no RNG at all; the Python reference
reproduces it to the MB, while its incident/discovery draws use Python's generator with the same seed (different
numbers, same distribution).

### 17.6 Caps and the tuning plan

The cap ladder (canon §C14.3) is the progression spine of management: a Basic Manager doubles a newcomer's offline
income per absence, an Experienced one covers a school day, an Elite one an evening + night, a Legendary one a full
day. Tuning uses §31 telemetry, always changes **one variable at a time** behind a server config flag, bumps
`SIM_VERSION`, and is A/B tested on new cohorts for ≥ 14 days.

| Signal (§31) | Healthy band | If too low | If too high |
|---|---|---|---|
| D1 / D7 retention of players who hired ≥ 1 employee vs not | hired cohort ≥ +5 pp D7 | make the first Manager cheaper/earlier (Common Manager in `TIER_02` pools 1.5× weight); Forecast more prominent | — |
| Share of returns that hit the cap | 30–60 % | caps feel generous — keep | > 70 % for 7 days: raise the Basic cap 4 → 5 h in a test cohort, or add Assistant earlier |
| Median hours between sessions vs cap | median ≤ cap | — | median ≫ cap and falling D7: test +2 h for Basic/Experienced |
| Report collect rate (collected within 24 h) | ≥ 90 % | simplify the screen; auto-collect on Continue (already) | — |
| Offline ÷ active net per hour (per tier, logged per report) | 35–50 % | raise `OFFLINE_DEMAND_FACTOR` 0.6 → 0.65 | lower it to 0.55; ceiling hits > 1 % of reports → investigate |
| Offline share of all MB earned (T5+) | 25–40 % | as above | > 45 %: lower demand factor or raise `ENERGY_DECAY` 8 → 9 |
| Inflation: median wallet ÷ next-tier cost (§C4.4) | ≤ 1.5 for 7 days | — | > 3: raise sinks (training growth 1.08 → 1.10) before touching caps |
| Closed-early reports | < 5 % | — | > 10 %: stronger Forecast warnings and "you are paying for idle staff" suggestions |
| Incident net / R | −3 % … +3 % | soften negative weights | raise negative weights or lower positives |

### 17.7 Persistence and idempotency (canon §C15, E11)

**Profile fields** (schema owned by §28; A11 defines the contents):

```lua
--!strict
export type OfflineReport = {
    reportId: string,            -- "<UserId>:<firstFromTs>:<lastToTs>:v<SIM_VERSION>"
    simVersion: number, segments: { { fromTs: number, toTs: number, simulatedSec: number, capHours: number,
                                      capped: boolean, tier: number, closedEarlyStep: number? } },
    customers: number, revenue: number, tips: number, delivery: number, ingredients: number,
    wages: number, autoRepairs: number, incidentNet: number, net: number,          -- fractions kept
    ms: number, capsules: number, crates: { { ing: string, units: number } },
    damage: { { objectId: string, points: number } }, deferredRepairMB: number,
    incidents: { { id: string, step: number, mb: number, employeeUid: string?, n: number } },  -- ≤ 20 kept
    employeeLines: { { uid: string, kpi: { [string]: number } } }, soldOut: { { rcp: string, step: number } },
    suggestions: { string }, welcomeBackCrate: boolean,
}
-- profile.lastSimAt: number            profile.lastLogoutAt: number     profile.lastOfflineCapsuleDay: number
-- profile.pendingOfflineReport: OfflineReport?                          profile.claimedReportIds: { string } (≤ 20)
```

**Simulate on join** — runs inside the session-locked load (`PlayerDataService`), as a pure function: no yields, no
remote calls, no analytics until the write succeeds (an `UpdateAsync` transform may run more than once).

```lua
--!strict
local OfflineEarningsService = {}
local SIM_VERSION, MIN_OFFLINE, RING = 1, 300, 20

-- called by PlayerDataService inside DataStore:UpdateAsync(key, function(old) ... end) after the lock is acquired
function OfflineEarningsService.SimulateOnJoin(data: any, userId: number, now: number): any
    if data.lastSimAt == nil then data.lastSimAt = now; return nil end
    local elapsed = now - data.lastSimAt
    if elapsed < 0 then data._flags.clockSkew = elapsed; elapsed = 0 end   -- negative → 0, flagged (canon)
    if elapsed < MIN_OFFLINE then return nil end                            -- lastSimAt untouched
    local capSec = OfflineModel.CapHours(data.staff) * 3600
    local simSec = math.min(elapsed, capSec)
    local rng = Random.new(fnv1a32(string.format("%d:%d:%d", userId, data.lastSimAt, SIM_VERSION)))
    local seg = OfflineModel.Run(OfflineModel.Snapshot(data), simSec, rng, now)  -- §17.4, deterministic
    OfflineModel.ApplyState(data, seg, elapsed - simSec)  -- Energy/Morale/hours, stock, damage, ★, capsule day
    local fromTs = data.lastSimAt
    data.pendingOfflineReport = OfflineEarningsService.Merge(data.pendingOfflineReport, seg, userId, fromTs, now)
    if now - (data.lastLogoutAt or now) >= 7 * 86400 then data.pendingOfflineReport.welcomeBackCrate = true end
    data.lastSimAt = now                                     -- toTs = now: forfeited hours are never re-simulated
    return data.pendingOfflineReport
end

function OfflineEarningsService.Merge(old: any?, seg: any, userId: number, fromTs: number, toTs: number): any
    local r = old or OfflineModel.EmptyReport()
    local first = (old and old.segments[1].fromTs) or fromTs
    OfflineModel.AddTotals(r, seg)                           -- sums; each segment was capped on its own
    table.insert(r.segments, seg.summary)
    r.reportId = string.format("%d:%d:%d:v%d", userId, first, toTs, SIM_VERSION)
    r.net = math.max(0, r.net)
    return r
end

-- RemoteFunction Offline.Collect(reportId): the only way money from offline time reaches the wallet
function OfflineEarningsService.Collect(player: Player, reportId: string)
    if not RateLimiter:Allow(player, "Offline.Collect", 1) then return { ok = false, reason = "RateLimited" } end
    local profile = PlayerDataService:Get(player)
    if not profile or profile.safeMode then return { ok = false, reason = "NotLoaded" } end
    local data = profile.data
    if typeof(reportId) ~= "string" or #reportId > 64 then return { ok = false, reason = "Bad" } end
    if table.find(data.claimedReportIds, reportId) then return { ok = true, alreadyClaimed = true } end
    local r = data.pendingOfflineReport
    if not r or r.reportId ~= reportId then return { ok = false, reason = "Stale", current = r and r.reportId } end
    -- one synchronous block: grant + ring + clear mutate the same in-memory profile, then one save
    local mb = math.floor(r.net + 0.5)                        -- canon C0: round half-up at payout only
    EconomyService:Grant(player, "MB", mb, "offline_report", reportId)
    if r.ms > 0 then EconomyService:Grant(player, "MS", r.ms, "offline_report", reportId .. ":ms") end
    for _, c in r.crates do InventoryService:AddStock(player, c.ing, c.units, "offline_find") end
    if r.capsules > 0 then MutationService:GrantCapsules(player, r.capsules, "OFFLINE_FIND") end
    if r.welcomeBackCrate then MutationService:GrantCapsules(player, 1, "welcome_back")
        EconomyService:Grant(player, "MS", 50, "welcome_back", reportId .. ":wb") end
    table.insert(data.claimedReportIds, reportId)
    if #data.claimedReportIds > RING then table.remove(data.claimedReportIds, 1) end
    data.pendingOfflineReport = nil
    PlayerDataService:SaveNow(player, "offline_collect")       -- retried with backoff (canon E6)
    Analytics:Log("mmr_offline_collected", { reportId = reportId, mb = mb })
    return { ok = true, mb = mb }
end
```

Why it cannot pay twice (canon E11): (1) the report and `lastSimAt = now` are written in the same `UpdateAsync`, so an
interval can never be simulated twice; (2) a second server cannot load the profile while it is locked; (3) Collect
grants, appends the `reportId` to the ring and clears the pending report in one synchronous block of the same
in-memory profile that `SaveNow` writes — if the server dies before the save, the DataStore still holds the unpaid
pending report and no grant (nothing lost, nothing doubled); (4) if a stale copy ever resurfaced with an
already-claimed report, the ring rejects it; (5) `EconomyService` also refuses a repeated idempotency key. Reconnects
reload the same pending report; nothing is recomputed. If a pending report exists when a new interval is simulated
(the player left without collecting), the new segment is merged into it with a new `reportId`; old IDs were never
paid, so nothing is lost.

**While online**, every autosave (120 s) and every save writes `lastSimAt = now`, so a crash without
`PlayerRemoving` starts offline time at most one autosave interval early (accepted; ≤ 2 min of overlap with Away
Mode/live play). `PlayerRemoving` and `BindToClose` write `lastSimAt` and `lastLogoutAt` (canon E1, E13).

### 17.8 Anti-exploit

| Threat | Defense |
|---|---|
| Client-supplied time or earnings | Only server `os.time()` and persisted data are inputs; `Offline.Collect` accepts a `reportId` string and nothing else; amounts come from the stored report |
| Device clock changes | Irrelevant — the client clock is never read |
| Server clock skew between servers | Negative elapsed → 0 and `mmr_offline_clock_skew`; elapsed is clamped to ≤ 30 days before capping; any skew is bounded by the cap and the 60 % ceiling |
| Multiple servers / two devices | Session lock: one server owns the profile; the second join waits or is kicked with a friendly message; only the lock owner simulates |
| Rejoin spam / server hopping | `MIN_OFFLINE_SECONDS` = 300; leaving to earn offline pays 35–50 % of staying, so there is no incentive; teleports between servers produce no report |
| Collect replay or double-click | `claimedReportIds` ring (20) + `EconomyService` idempotency key; Collect rate-limited 1/s |
| Hire-before-logout, fire-for-refund | Probation refund only within 15 real minutes of hiring; payroll for the interval is already paid |
| Roster or menu edits during the screen | The report was computed from the snapshot at `lastSimAt`; later edits only affect the next interval |
| Forged remote spam on Welcome Back buttons | Every button maps to a validated server action (§17.10); tabs read the already-sent report |
| Inflating via Away Mode then crashing | Away Mode pays live and writes `lastSimAt` every autosave; the overlap is ≤ 1 autosave |
| Data rollback to an older save | `lastSimAt` rolls back with it, so the restored interval is simulated once; claimed IDs in the ring block replays of the same report |

### 17.9 Worked examples

Generated by `python3 gdd/tools/offline_sim_examples.py` (stdlib only; `--check` asserts the band). Five well-staffed
restaurants at different progression points plus one deliberately bad roster. Shared assumptions, so each example
only lists what differs:

- **Canon constants unchanged** (§C15 as written); A11 elaborations exactly as §17.3–§17.4. Employees use their §36.8
  values (trained stats are starred).
- **Menus** use real recipe IDs from §C10 with prices from the canon curve (§C4.2, no flavor variance). Difficulty D,
  base prep seconds (mains 10 + 7D, desserts/fried/salads 8 + 5D, drinks 4 + 3D, legendary 20 + 10D) and ingredient
  ratios (D1 36 % … D5 26 %, inside the canon 25–40 % band) are *assumed for the examples*; the live game reads §6.
  Special-ingredient mappings (alien → `ING_MOON_CHEESE` / `ING_STARDUST`, mutation → `ING_MUTAGEN_GOO`, legendary →
  `ING_GOLDEN_PATTY`) are assumptions too; §7 owns them.
- **Reputation / Atmosphere** are typical for a competent player at that tier; player EFFICIENCY grows with level.
- **Incident and discovery draws** come from the Python generator with the real seed; the economy columns are what
  the Luau service must reproduce exactly. "Base economy" in the result is the run without incidents.

#### 17.9.1 Example A — TIER_01 — Ollie alone, back after 9 h (cap 2 h)

**Inputs**

| Parameter | Value | Derivation |
|---|---|---|
| Tier | `TIER_01` Broken Burger Shack | seats 4, base demand 50/h, employee cap 2 (§C6) |
| Player | level 4, EFFICIENCY 0 | Efficiency × 1.000; ingredient cost × 1.0000 |
| Reputation | 3.8 ★ | RepMult = 0.5 + 0.25 × 3.8 = 1.450 |
| Atmosphere | 45 | DecorMult = 0.9 + 0.003 × 45 = 1.035 |
| Stations | starter kit, all Lv1 | PrepSec × (1 − 0.5 × (1 − 1.00)) = × 1.000 |
| Offline cap | 2 h | no Manager → 2 h |
| Elapsed / simulated | 9 h 00 min / **2 h 00 min** (capped) | H = min(H_elapsed, cap) |
| Seed | `0xDD6C3873` | FNV-1a-32("81234567:1760131800:1") |

**Roster**

| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |
|---|---|---|---|---|---|---|---|---|---|---|
| Ollie | `EMP_001` | Chef | Common | Cook 30, Acc 28, Rel 40 | 30.4 | 90 / 100 | 29.2 | ×1.25 | 0.365 | 12 |

**Menu** (skill gate: D ≤ 1 + floor(30 / 25) = 2)

| Recipe | ID | L | D | Price (MB) | Ingredients/item (MB) | PrepSec base → eff (s) | Offline? |
|---|---|---|---|---|---|---|---|
| Double Cheeseburger | `RCP_BRG_003` | 4 | 2 | 12 | 3.96 | 24 → 24.0 | yes |
| Ham & Cheese Sandwich | `RCP_SAN_002` | 4 | 2 | 12 | 3.96 | 24 → 24.0 | yes |
| Cheeseburger | `RCP_BRG_002` | 1 | 1 | 9 | 3.24 | 17 → 17.0 | yes |
| Lemonade | `RCP_DRK_002` | 2 | 1 | 7 | 2.52 | 7 → 7.0 | yes |

**Interval constants**

- Demand_off = 50 × 1.450 × 1.035 × 0.6 = **45.0 customers/h**; Cap_seat = 4 × 3600 / 300 = **48/h**.
- Step-1 PrepSec_avg = 18.00 s; AvgTicket = 1.4 × mean price = 14.00 MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 +0.00) × CleanFactor 1.00 = 0.770.
- Preps counted 0.00 (+0 %), cashiers counted 0, DishFactor 1.00, Manager/Assistant coordination +0.0 %, stocker discount 0.0 %, delivery share 0.0 %, tip trait multiplier ×1.00.

**Hourly steps**

| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 100.0 | 0.365 | 52.1 | 52.1 | 45.0 | Demand | 45 | 485 | 19 | 0 | 215 | 12 | 277 |
| 2 | 1.00 | 92.0 | 0.355 | 50.7 | 50.7 | 45.0 | Demand | 45 | 485 | 19 | 0 | 215 | 12 | 277 |
| **Σ** | 2.00 | | | | | | | **90** | **970** | **39** | **0** | **431** | **24** | **554** |

**Incidents & discoveries**

- Security Mitigation SM = 0.000; λ = 2.00 h × 0.6 × (1 − SM) = 1.200 → count = floor(λ) + roll(0.200) = **1**; eligible pool 21 incidents; Rh = 505 MB/h.
- Caps: negatives 15 ≤ 10 % of R (101) → scale ×1.00; positives 0 ≤ 15 % of R (151) → scale ×1.00.

| # | Step | Incident | MB effect | Damage value | Report line |
|---|---|---|---|---|---|
| 1 | 1 | `INC_032` Bun Shortage | −15 | — | We ran out of buns. Ollie served 5 burgers between two slices of pizza. Reviews: mixed. |

- Discoveries (MS chance 8.0 %/h after trait boost ×1.00; crate 1 %/h; capsule 5 %/h, ≤ 1 per UTC day): none this time.

**Result**

| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 90 | 970 | 39 | 0 | −431 | −24 | 0 | −15 | **539** | 269 | 630 | **42.8 %** (base economy 44.0 %) |

#### 17.9.2 Example B — TIER_03 — basic staff + Basic Manager, 4 h

**Inputs**

| Parameter | Value | Derivation |
|---|---|---|
| Tier | `TIER_03` Neighborhood Freak Café | seats 8, base demand 80/h, employee cap 4 (§C6) |
| Player | level 12, EFFICIENCY 10 | Efficiency × 1.010; ingredient cost × 0.9850 |
| Reputation | 3.9 ★ | RepMult = 0.5 + 0.25 × 3.9 = 1.475 |
| Atmosphere | 50 | DecorMult = 0.9 + 0.003 × 50 = 1.050 |
| Stations | all Lv2 Tuned | PrepSec × (1 − 0.5 × (1 − 0.90)) = × 0.950 |
| Offline cap | 4 h | Barnaby Hoot (Common) → 4 h |
| Elapsed / simulated | 5 h 20 min / **4 h 00 min** (capped) | H = min(H_elapsed, cap) |
| Seed | `0x9D1F42EB` | FNV-1a-32("81234567:1760380200:1") |

**Roster**

| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |
|---|---|---|---|---|---|---|---|---|---|---|
| Octavia | `EMP_005` | Chef | Uncommon | Cook 52, Acc 46, Rel 42 | 49.2 | 82 / 92 | 45.0 | ×1.25 | 0.563 | 50 |
| Skates McGee | `EMP_026` | Waiter | Uncommon | Svc 53, Acc 43, Rel 39 | 48.6 | 80 / 90 | 43.8 | ×1.20 | 0.526 | 55 |
| Benny Bun | `EMP_023` | Waiter | Common | Svc 38, Acc 26, Rel 23 | 32.9 | 85 / 95 | 30.8 | ×1.20 | 0.369 | 18 |
| Barnaby Hoot | `EMP_070` | Manager | Common | Rel 31, Svc 30, Acc 31 | 30.7 | 80 / 95 | 28.1 | ×1.00 | 0.281 | 17 |

**Menu** (skill gate: D ≤ 1 + floor(52 / 25) = 3)

| Recipe | ID | L | D | Price (MB) | Ingredients/item (MB) | PrepSec base → eff (s) | Offline? |
|---|---|---|---|---|---|---|---|
| Sushi Roll Block | `RCP_SEA_003` | 12 | 2 | 17 | 5.61 | 24 → 22.8 | yes |
| Club Sandwich Stack | `RCP_SAN_004` | 10 | 2 | 16 | 5.28 | 24 → 22.8 | yes |
| Meat Mountain Pizza | `RCP_PIZ_005` | 11 | 2 | 16 | 5.28 | 24 → 22.8 | yes |
| Fried Shrimp Basket | `RCP_SEA_002` | 10 | 2 | 16 | 5.28 | 24 → 22.8 | yes |
| Breakfast Burrito | `RCP_BRK_004` | 11 | 2 | 16 | 5.28 | 24 → 22.8 | yes |
| Rainbow Slushie | `RCP_DRK_006` | 11 | 2 | 11 | 3.63 | 10 → 9.5 | yes |

**Interval constants**

- Demand_off = 80 × 1.475 × 1.050 × 0.6 = **74.3 customers/h**; Cap_seat = 8 × 3600 / 300 = **96/h**.
- Step-1 PrepSec_avg = 20.58 s; AvgTicket = 1.4 × mean price = 21.47 MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 +0.00) × CleanFactor 1.00 = 0.815.
- Preps counted 0.00 (+0 %), cashiers counted 0, DishFactor 1.00, Manager/Assistant coordination +5.0 %, stocker discount 0.0 %, delivery share 0.0 %, tip trait multiplier ×1.10.

**Hourly steps**

| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 93.0 | 0.563 | 73.8 | 75.1 | 73.8 | Kitchen | 73 | 1,277 | 82 | 0 | 509 | 140 | 710 |
| 2 | 1.00 | 89.2 | 0.553 | 72.5 | 73.9 | 72.5 | Kitchen | 73 | 1,277 | 82 | 0 | 509 | 140 | 710 |
| 3 | 1.00 | 85.5 | 0.544 | 71.3 | 72.6 | 71.3 | Kitchen | 71 | 1,242 | 80 | 0 | 495 | 140 | 686 |
| 4 | 1.00 | 81.8 | 0.535 | 70.1 | 71.4 | 70.1 | Kitchen | 70 | 1,225 | 78 | 0 | 488 | 140 | 675 |
| **Σ** | 4.00 | | | | | | | **287** | **5,021** | **321** | **0** | **2,003** | **560** | **2,780** |

**Incidents & discoveries**

- Security Mitigation SM = 0.000; λ = 4.00 h × 0.6 × (1 − SM) = 2.400 → count = floor(λ) + roll(0.400) = **2**; eligible pool 38 incidents; Rh = 1,336 MB/h.
- Caps: negatives 147 ≤ 10 % of R (534) → scale ×1.00; positives 0 ≤ 15 % of R (801) → scale ×1.00.

| # | Step | Incident | MB effect | Damage value | Report line |
|---|---|---|---|---|---|
| 1 | 1 | `INC_006` Drama Llama Monologue | −40 | — | A Drama Llama performed a monologue about lukewarm soup. 3 customers left before the second act. |
| 2 | 3 | `INC_002` Meatball Food Fight | −53 | 53 | One meatball was thrown. Then 24 meatballs were thrown. Octavia is still finding them. |

- Damage value 53 MB (22 damage points) is **left for the player** (no Repair Technician): shown in the Restaurant Damage tab, not deducted.
- Discoveries (MS chance 9.2 %/h after trait boost ×1.15; crate 1 %/h; capsule 5 %/h, ≤ 1 per UTC day): none this time.

**Result**

| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 287 | 5,021 | 321 | 0 | −2,003 | −560 | 0 | −93 | **2,687** | 672 | 1,730 | **38.8 %** (base economy 40.2 %) |

#### 17.9.3 Example C — TIER_05 — Experienced Manager, 8 h

**Inputs**

| Parameter | Value | Derivation |
|---|---|---|
| Tier | `TIER_05` Mutant Family Restaurant | seats 12, base demand 110/h, employee cap 8 (§C6) |
| Player | level 28, EFFICIENCY 25 | Efficiency × 1.025; ingredient cost × 0.9625 |
| Reputation | 4.1 ★ | RepMult = 0.5 + 0.25 × 4.1 = 1.525 |
| Atmosphere | 60 | DecorMult = 0.9 + 0.003 × 60 = 1.080 |
| Stations | mix of Lv2 and Lv3 (mean process multiplier 0.85) | PrepSec × (1 − 0.5 × (1 − 0.85)) = × 0.925 |
| Offline cap | 8 h | Mister Mustache (Rare) → 8 h |
| Elapsed / simulated | 8 h 00 min / **8 h 00 min** | H = min(H_elapsed, cap) |
| Seed | `0x8B08E0D0` | FNV-1a-32("81234567:1761085800:1") |

**Roster**

| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |
|---|---|---|---|---|---|---|---|---|---|---|
| Mister Mustache | `EMP_073` | Manager | Rare | Rel 68, Svc 61, Acc 59 | 63.2 | 80 / 95 | 58.7 | ×1.00 | 0.587 | 160 |
| Sir Loin | `EMP_008` | Chef | Rare | Cook 67, Acc 62, Rel 56 | 64.9 | 78 / 90 | 58.8 | ×1.00 | 0.588 | 160 |
| Octavia | `EMP_005` | Chef | Uncommon | Cook 58*, Acc 52*, Rel 42 | 54.6 | 80 / 90 | 49.9 | ×1.25 | 0.624 | 50 |
| Benny Bun | `EMP_023` | Waiter | Common | Svc 38, Acc 26, Rel 23 | 32.9 | 85 / 92 | 30.9 | ×1.20 | 0.371 | 18 |
| Chet Speedwell | `EMP_028` | Waiter | Rare | Svc 68, Acc 58, Rel 53 | 63.5 | 80 / 88 | 57.7 | ×1.20 | 0.693 | 165 |
| Skates McGee | `EMP_026` | Waiter | Uncommon | Svc 53, Acc 43, Rel 39 | 48.6 | 78 / 90 | 44.1 | ×1.20 | 0.529 | 55 |
| Sloane | `EMP_039` | Dish | Common | Svc 15, Rel 40 | 27.5 | 90 / 100 | 27.1 | ×0.60 | 0.162 | 10 |
| Dusty | `EMP_048` | Cleaner | Common | Svc 37, Rel 26, Acc 31 | 32.5 | 75 / 90 | 29.1 | ×1.20 | 0.349 | 18 |

\* trained above the archetype value (within the potential cap, §16.6).

**Menu** (skill gate: D ≤ 1 + floor(67 / 25) = 3)

| Recipe | ID | L | D | Price (MB) | Ingredients/item (MB) | PrepSec base → eff (s) | Offline? |
|---|---|---|---|---|---|---|---|
| Upside-Down Burger | `RCP_BRG_013` | 18 | 3 | 25 | 7.50 | 31 → 28.7 | yes |
| Square Circle Pizza | `RCP_PIZ_014` | 19 | 3 | 26 | 7.80 | 31 → 28.7 | yes |
| Inside-Out Taco | `RCP_TAC_007` | 24 | 3 | 34 | 10.20 | 31 → 28.7 | yes |
| Sandwich With Bread in the Middle | `RCP_SAN_008` | 23 | 3 | 32 | 9.60 | 31 → 28.7 | yes |
| Spaghetti Tornado | `RCP_PST_005` | 23 | 3 | 32 | 9.60 | 31 → 28.7 | yes |
| Crab Cake Kerfuffle | `RCP_SEA_006` | 25 | 3 | 35 | 10.50 | 31 → 28.7 | yes |
| Bacon Waterfall | `RCP_BRK_008` | 26 | 3 | 37 | 11.10 | 31 → 28.7 | yes |
| Exploding Cupcake | `RCP_DES_009` | 21 | 2 | 21 | 6.93 | 18 → 16.7 | yes |
| Tentacle Tea | `RCP_DRK_011` | 24 | 2 | 22 | 7.26 | 10 → 9.2 | yes |
| Pumpkin Screamer Soup | `RCP_SOP_006` | 24 | 3 | 34 | 10.20 | 31 → 28.7 | yes |

**Interval constants**

- Demand_off = 110 × 1.525 × 1.080 × 0.6 = **108.7 customers/h**; Cap_seat = 12 × 3600 / 300 = **144/h**.
- Step-1 PrepSec_avg = 25.53 s; AvgTicket = 1.4 × mean price = 41.72 MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 +0.02) × CleanFactor 1.00 = 0.862.
- Preps counted 0.00 (+0 %), cashiers counted 0, DishFactor 1.00, Manager/Assistant coordination +7.1 %, stocker discount 0.0 %, delivery share 0.0 %, tip trait multiplier ×1.10.

**Hourly steps**

| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 91.9 | 1.213 | 130.8 | 136.5 | 108.7 | Demand | 108 | 3,886 | 262 | 0 | 1,320 | 636 | 2,192 |
| 2 | 1.00 | 87.4 | 1.189 | 128.2 | 133.7 | 108.7 | Demand | 109 | 3,922 | 264 | 0 | 1,332 | 636 | 2,218 |
| 3 | 1.00 | 83.0 | 1.165 | 125.5 | 130.9 | 108.7 | Demand | 109 | 3,922 | 264 | 0 | 1,332 | 636 | 2,218 |
| 4 | 1.00 | 78.6 | 1.141 | 122.9 | 128.2 | 108.7 | Demand | 108 | 3,886 | 262 | 0 | 1,320 | 636 | 2,192 |
| 5 | 1.00 | 74.1 | 1.118 | 120.3 | 125.5 | 108.7 | Demand | 109 | 3,922 | 264 | 0 | 1,332 | 636 | 2,218 |
| 6 | 1.00 | 69.7 | 1.095 | 117.7 | 122.8 | 108.7 | Demand | 109 | 3,922 | 264 | 0 | 1,332 | 636 | 2,218 |
| 7 | 1.00 | 65.2 | 1.071 | 115.1 | 120.1 | 108.7 | Demand | 108 | 3,886 | 262 | 0 | 1,320 | 636 | 2,192 |
| 8 | 1.00 | 60.8 | 1.048 | 112.6 | 117.4 | 108.7 | Demand | 109 | 3,922 | 264 | 0 | 1,332 | 636 | 2,218 |
| **Σ** | 8.00 | | | | | | | **869** | **31,270** | **2,105** | **0** | **10,620** | **5,088** | **17,667** |

**Incidents & discoveries**

- Security Mitigation SM = 0.000; λ = 8.00 h × 0.6 × (1 − SM) = 4.800 → count = floor(λ) + roll(0.800) = **5**; eligible pool 47 incidents; Rh = 4,172 MB/h.
- Caps: negatives 918 ≤ 10 % of R (3,337) → scale ×1.00; positives 209 ≤ 15 % of R (5,006) → scale ×1.00.

| # | Step | Incident | MB effect | Damage value | Report line |
|---|---|---|---|---|---|
| 1 | 5 | `INC_008` Wrong Table Waltz | −125 | — | Chet Speedwell delivered 8 orders to the wrong table. The wrong tables said thank you. |
| 2 | 4 | `INC_049` Rich Mutant Big Tipper | 209 | — | A Rich Mutant tipped 268 shiny coins and a monocle. We kept the coins. |
| 3 | 8 | `INC_002` Meatball Food Fight | −167 | 167 | One meatball was thrown. Then 12 meatballs were thrown. Dusty is still finding them. |
| 4 | 8 | `INC_014` Grill Soot Sneeze | −125 | 125 | The grill sneezed a soot cloud. Octavia now has a cartoon soot mustache and 7 extra-crispy patties. |
| 5 | 7 | `INC_010` Chair Domino Effect | 0 | 209 | 4 chairs fell over like dominoes. Octavia called it modern art and left them for later. |

- Damage value 501 MB (72 damage points) is **left for the player** (no Repair Technician): shown in the Restaurant Damage tab, not deducted.
- Discoveries (MS chance 9.2 %/h after trait boost ×1.15; crate 1 %/h; capsule 5 %/h, ≤ 1 per UTC day): step 7: +3 MS.

**Result**

| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 869 | 31,270 | 2,105 | 0 | −10,620 | −5,088 | 0 | −209 | **17,459** | 2,182 | 5,400 | **40.4 %** (base economy 40.9 %) |

#### 17.9.4 Example D — TIER_07 — Elite Manager, 12 h, special stock runs out

**Inputs**

| Parameter | Value | Derivation |
|---|---|---|
| Tier | `TIER_07` Mutation Megadiner | seats 16, base demand 140/h, employee cap 12 (§C6) |
| Player | level 48, EFFICIENCY 45 | Efficiency × 1.045; ingredient cost × 0.9325 |
| Reputation | 4.3 ★ | RepMult = 0.5 + 0.25 × 4.3 = 1.575 |
| Atmosphere | 70 | DecorMult = 0.9 + 0.003 × 70 + Glow-Up = 1.116 |
| Stations | mostly Lv3–Lv4 (mean process multiplier 0.75) | PrepSec × (1 − 0.5 × (1 − 0.75)) = × 0.875 |
| Offline cap | 12 h | Megaphone Maxine (Epic) → 12 h |
| Elapsed / simulated | 14 h 30 min / **12 h 00 min** (capped) | H = min(H_elapsed, cap) |
| Seed | `0x52BD87E4` | FNV-1a-32("81234567:1762378200:1") |
| Special stock at logout | `ING_MOON_CHEESE` × 70, `ING_MUTAGEN_GOO` × 400 | consumed 1 unit per special dish |

**Roster**

| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |
|---|---|---|---|---|---|---|---|---|---|---|
| Megaphone Maxine | `EMP_075` | Manager | Epic | Rel 79, Svc 77, Acc 72 | 76.3 | 80 / 95 | 72.3 | ×1.00 | 0.723 | 500 |
| Ember | `EMP_009` | Chef | Epic | Cook 84, Acc 62, Rel 74 | 76.4 | 75 / 90 | 69.7 | ×1.15 | 0.802 | 515 |
| Frostina | `EMP_007` | Chef | Rare | Cook 63, Acc 55, Rel 53 | 59.6 | 80 / 92 | 55.9 | ×1.00 | 0.559 | 135 |
| Sir Loin | `EMP_008` | Chef | Rare | Cook 67, Acc 62, Rel 56 | 64.9 | 80 / 90 | 60.5 | ×1.00 | 0.605 | 160 |
| Mantis Mandy | `EMP_019` | Prep | Rare | Cook 65, Svc 66, Acc 57 | 63.8 | 80 / 90 | 59.5 | ×1.00 | 0.595 | 155 |
| Twinkle Thistlewing | `EMP_030` | Waiter | Epic | Svc 82, Acc 77, Rel 71 | 79.4 | 85 / 95 | 76.8 | ×1.00 | 0.768 | 500 |
| Chet Speedwell | `EMP_028` | Waiter | Rare | Svc 68, Acc 58, Rel 53 | 63.5 | 80 / 90 | 59.2 | ×1.20 | 0.711 | 165 |
| Ozzie | `EMP_029` | Waiter | Rare | Svc 65, Acc 57, Rel 55 | 61.6 | 80 / 90 | 57.4 | ×1.20 | 0.689 | 135 |
| Cassie Cassette | `EMP_036` | Cashier | Rare | Acc 63, Svc 66, Rel 59 | 64.3 | 80 / 95 | 60.9 | ×1.00 | 0.609 | 160 |
| Drippy | `EMP_043` | Dish | Rare | Svc 64, Rel 62 | 63.0 | 80 / 95 | 59.7 | ×1.10 | 0.656 | 145 |
| Vacuuma Vera | `EMP_051` | Cleaner | Rare | Svc 65, Rel 60, Acc 58 | 62.1 | 80 / 92 | 58.3 | ×1.20 | 0.699 | 155 |
| Rocco | `EMP_066` | Security | Rare | Cmb 70, Rel 62, Svc 56 | 65.6 | 85 / 95 | 63.5 | ×1.00 | 0.635 | 170 |

**Menu** (skill gate: D ≤ 1 + floor(84 / 25) = 4)

| Recipe | ID | L | D | Price (MB) | Ingredients/item (MB) | PrepSec base → eff (s) | Offline? |
|---|---|---|---|---|---|---|---|
| Exploding Burger | `RCP_BRG_012` | 40 | 4 | 80 | 22.40 | 38 → 33.2 | yes |
| Pizza Inside Another Pizza | `RCP_PIZ_013` | 45 | 4 | 103 | 28.84 | 38 → 33.2 | yes |
| Mega Taco Tower | `RCP_TAC_010` | 48 | 4 | 119 | 33.32 | 38 → 33.2 | yes |
| The Sandwich Sandwich | `RCP_SAN_010` | 42 | 3 | 81 | 24.30 | 31 → 27.1 | yes |
| Pasta Shaped Like the Customer | `RCP_PST_009` | 44 | 3 | 90 | 27.00 | 31 → 27.1 | yes |
| Sea Monster Steak | `RCP_SEA_009` | 37 | 3 | 64 | 19.20 | 31 → 27.1 | yes |
| Dragon Egg Benedict | `RCP_BRK_010` | 41 | 3 | 77 | 23.10 | 31 → 27.1 | yes |
| Galaxy Cheesecake | `RCP_DES_014` | 46 | 3 | 79 | 23.70 | 23 → 20.1 | yes |
| Glowing Mutagen Juice | `RCP_DRK_013` | 33 | 3 | 37 | 6.66 | 13 → 11.4 | yes · stock `ING_MUTAGEN_GOO` |
| Bread Bowl in a Bread Bowl | `RCP_SOP_009` | 37 | 3 | 64 | 19.20 | 31 → 27.1 | yes |
| Fried Everything Basket | `RCP_FRI_005` | 43 | 3 | 60 | 18.00 | 23 → 20.1 | yes |
| Mutagen Meatballs | `RCP_MUT_001` | 42 | 3 | 81 | 14.58 | 31 → 27.1 | yes · stock `ING_MUTAGEN_GOO` |
| Martian Meatloaf | `RCP_ALN_004` | 40 | 3 | 74 | 13.32 | 31 → 27.1 | yes · stock `ING_MOON_CHEESE` |
| Moon Cheese Nuggets | `RCP_ALN_001` | 30 | 2 | 41 | 8.12 | 24 → 21.0 | yes · stock `ING_MOON_CHEESE` |

**Interval constants**

- Demand_off = 140 × 1.575 × 1.116 × 0.6 = **147.6 customers/h**; Cap_seat = 16 × 3600 / 300 = **192/h**.
- Step-1 PrepSec_avg = 25.88 s; AvgTicket = 1.4 × mean price = 105.00 MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 +0.00) × CleanFactor 1.00 = 0.849.
- Preps counted 1.00 (+15 %), cashiers counted 1, DishFactor 1.00, Manager/Assistant coordination +10.1 %, stocker discount 0.0 %, delivery share 0.0 %, tip trait multiplier ×1.10.

**Hourly steps**

| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 92.4 | 1.966 | 247.3 | 210.0 | 147.6 | Demand | 147 | 13,107 | 1,030 | 0 | 3,862 | 2,895 | 7,380 |
| 2 | 1.00 | 87.4 | 1.927 | 242.2 | 205.8 | 147.6 | Demand | 148 | 13,196 | 1,037 | 0 | 3,888 | 2,895 | 7,449 |
| 3 | 1.00 | 82.4 | 1.889 | 237.1 | 201.7 | 147.6 | Demand | 147 | 13,107 | 1,030 | 0 | 3,862 | 2,895 | 7,380 |
| 4 | 1.00 | 77.4 | 1.850 | 229.4 | 197.6 | 147.6 | Demand | 148 | 13,709 | 1,077 | 0 | 4,191 | 2,895 | 7,700 |
| 5 | 1.00 | 72.4 | 1.812 | 224.5 | 193.6 | 147.6 | Demand | 148 | 13,709 | 1,077 | 0 | 4,191 | 2,895 | 7,700 |
| 6 | 1.00 | 67.4 | 1.774 | 219.6 | 189.6 | 147.6 | Demand | 147 | 13,617 | 1,070 | 0 | 4,163 | 2,895 | 7,628 |
| 7 | 1.00 | 62.4 | 1.737 | 214.8 | 185.6 | 147.6 | Demand | 148 | 13,709 | 1,077 | 0 | 4,191 | 2,895 | 7,700 |
| 8 | 1.00 | 57.4 | 1.700 | 210.0 | 181.6 | 147.6 | Demand | 148 | 13,709 | 1,077 | 0 | 4,191 | 2,895 | 7,700 |
| 9 | 1.00 | 52.4 | 1.663 | 205.3 | 177.7 | 147.6 | Demand | 147 | 13,617 | 1,070 | 0 | 4,163 | 2,895 | 7,628 |
| 10 | 1.00 | 47.4 | 1.626 | 200.6 | 173.8 | 147.6 | Demand | 148 | 13,709 | 1,077 | 0 | 4,191 | 2,895 | 7,700 |
| 11 | 1.00 | 42.4 | 1.590 | 195.9 | 169.9 | 147.6 | Demand | 148 | 13,709 | 1,077 | 0 | 4,191 | 2,895 | 7,700 |
| 12 | 1.00 | 37.4 | 1.553 | 191.3 | 166.0 | 147.6 | Demand | 147 | 13,617 | 1,070 | 0 | 4,163 | 2,895 | 7,628 |
| **Σ** | 12.00 | | | | | | | **1,771** | **162,515** | **12,766** | **0** | **49,248** | **34,740** | **91,294** |

Special stock used: `ING_MOON_CHEESE` 70, `ING_MUTAGEN_GOO` 398 (left: 0, 2). **SOLD OUT** from step 4: `RCP_ALN_004`, `RCP_ALN_001` — later steps recompute PrepSec_avg and AvgTicket without those dishes.

**Incidents & discoveries**

- Security Mitigation SM = 0.309; λ = 12.00 h × 0.6 × (1 − SM) = 4.977 → count = floor(λ) + roll(0.977) = **5**; eligible pool 52 incidents; Rh = 14,607 MB/h.
- Caps: negatives 876 ≤ 10 % of R (17,528) → scale ×1.00; positives 2,337 ≤ 15 % of R (26,292) → scale ×1.00.

| # | Step | Incident | MB effect | Damage value | Report line |
|---|---|---|---|---|---|
| 1 | 12 | `INC_051` Brawl Stopped Cold | 730 | — | Rocco stopped 2 angry customers with one very stern eyebrow. |
| 2 | 10 | `INC_003` Goblin Dine-and-Dash | −584 | — | 2 Impatient Goblins sprinted out before paying. Twinkle Thistlewing chased them to the corner, then waved. |
| 3 | 12 | `INC_034` Surprise Lunch Rush | 1,169 | — | A surprise rush of 14 hungry mutants arrived at once. Ember handled it like a pro. |
| 4 | 12 | `INC_053` Cake Catch of the Century | 438 | — | Twinkle Thistlewing caught a falling birthday cake 4 centimeters from the floor. Standing ovation. |
| 5 | 2 | `INC_019` Dish Station Foam Party | −292 | — | The dishwasher made 197 cubic studs of foam. Three customers asked if it was dessert. |

- Discoveries (MS chance 8.0 %/h after trait boost ×1.00; crate 1 %/h; capsule 5 %/h, ≤ 1 per UTC day): none this time.

**Result**

| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1,771 | 162,515 | 12,766 | 0 | −49,248 | −34,740 | 0 | +1,461 | **92,754** | 7,730 | 17,400 | **44.4 %** (base economy 43.7 %) |

#### 17.9.5 Example E — TIER_10 — Legendary Manager, 24 h

**Inputs**

| Parameter | Value | Derivation |
|---|---|---|
| Tier | `TIER_10` Legendary Mutation Restaurant | seats 24, base demand 190/h, employee cap 20 (§C6) |
| Player | level 85, EFFICIENCY 80 | Efficiency × 1.080; ingredient cost × 0.8800 |
| Reputation | 4.6 ★ | RepMult = 0.5 + 0.25 × 4.6 = 1.650 |
| Atmosphere | 85 | DecorMult = 0.9 + 0.003 × 85 + Glow-Up = 1.173 |
| Stations | mostly Lv4–Lv5 (mean process multiplier 0.65) | PrepSec × (1 − 0.5 × (1 − 0.65)) = × 0.825 |
| Offline cap | 24 h | The Oracle of Orders (Legendary) → 24 h (+2 h Assistant, absolute max 24 h) |
| Elapsed / simulated | 31 h 00 min / **24 h 00 min** (capped) | H = min(H_elapsed, cap) |
| Seed | `0x00F61938` | FNV-1a-32("81234567:1764970200:1") |
| Special stock at logout | `ING_GOLDEN_PATTY` × 700, `ING_MUTAGEN_GOO` × 900, `ING_STARDUST` × 900 | consumed 1 unit per special dish |

**Roster**

| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |
|---|---|---|---|---|---|---|---|---|---|---|
| The Oracle of Orders | `EMP_076` | Manager | Legendary | Rel 95, Svc 88, Acc 90 | 91.4 | 85 / 95 | 91.4 | ×1.00 | 0.914 | 1,480 |
| Lady Luckfeather | `EMP_097` | Asst Mgr | Legendary | Rel 97, Svc 91, Acc 89 | 92.8 | 85 / 95 | 92.8 | ×1.00 | 0.928 | 1,410 |
| Captain Calamari | `EMP_011` | Chef | Legendary | Cook 100*, Acc 90, Rel 88 | 95.8 | 85 / 95 | 95.8 | ×1.35 | 1.293 | 1,480 |
| Goldie Gourmand | `EMP_012` | Chef | Legendary | Cook 97, Acc 87, Rel 90 | 93.3 | 85 / 95 | 93.3 | ×1.00 | 0.933 | 1,340 |
| Ember | `EMP_009` | Chef | Epic | Cook 84, Acc 62, Rel 74 | 76.4 | 80 / 95 | 74.8 | ×1.15 | 0.860 | 515 |
| Professor Dice | `EMP_021` | Prep | Epic | Cook 83, Svc 77, Acc 73 | 78.6 | 80 / 95 | 76.9 | ×1.00 | 0.769 | 500 |
| Hoverina | `EMP_031` | Waiter | Legendary | Svc 94, Acc 91, Rel 88 | 92.5 | 85 / 95 | 92.5 | ×1.15 | 1.064 | 1,410 |
| Twinkle Thistlewing | `EMP_030` | Waiter | Epic | Svc 82, Acc 77, Rel 71 | 79.4 | 85 / 95 | 79.4 | ×1.00 | 0.794 | 500 |
| Chet Speedwell | `EMP_028` | Waiter | Rare | Svc 68, Acc 58, Rel 53 | 63.5 | 80 / 95 | 62.1 | ×1.20 | 0.746 | 165 |
| Ozzie | `EMP_029` | Waiter | Rare | Svc 65, Acc 57, Rel 55 | 61.6 | 80 / 95 | 60.3 | ×1.20 | 0.723 | 135 |
| Sterling Silverfin | `EMP_037` | Cashier | Epic | Acc 80, Svc 77, Rel 71 | 77.9 | 80 / 95 | 76.2 | ×1.00 | 0.762 | 500 |
| The Rinse-o-Tron 3000 | `EMP_045` | Dish | Epic | Svc 83, Rel 81 | 84.5 | 80 / 95 | 82.7 | ×1.25 | 1.034 | 500 |
| Gale Force | `EMP_052` | Cleaner | Epic | Svc 83, Rel 75, Acc 77 | 79.4 | 80 / 95 | 77.7 | ×1.00 | 0.777 | 455 |
| Gearhart | `EMP_060` | Repair | Epic | Rep 79, Rel 75, Svc 68 | 78.1 | 80 / 95 | 76.4 | ×1.25 | 0.955 | 500 |
| Steggy | `EMP_068` | Security | Epic | Cmb 77, Rel 77, Svc 74 | 76.4 | 80 / 95 | 74.8 | ×1.00 | 0.748 | 465 |
| Golem Gary | `EMP_069` | Security | Legendary | Cmb 93, Rel 91, Svc 90 | 92.0 | 85 / 95 | 92.0 | ×1.00 | 0.920 | 1,410 |
| Comet Carla | `EMP_083` | Delivery | Epic | Svc 81, Rel 71, Cmb 72 | 77.1 | 80 / 95 | 75.5 | ×1.20 | 0.905 | 465 |
| Tractor Trixie | `EMP_090` | Stocker | Epic | Acc 83, Rel 71, Svc 71 | 77.0 | 80 / 95 | 75.4 | ×1.00 | 0.754 | 440 |

\* trained above the archetype value (within the potential cap, §16.6).

**Menu** (skill gate: D ≤ 1 + floor(100 / 25) = 5)

| Recipe | ID | L | D | Price (MB) | Ingredients/item (MB) | PrepSec base → eff (s) | Offline? |
|---|---|---|---|---|---|---|---|
| The Golden Patty Supreme | `RCP_LEG_001` | 65 | 5 | 738 | 115.13 | 70 → 57.8 | yes · stock `ING_GOLDEN_PATTY` |
| Dragon Feast | `RCP_LEG_002` | 72 | 5 | 1,038 | 161.93 | 70 → 57.8 | yes · stock `ING_GOLDEN_PATTY` |
| Infinity Pizza | `RCP_LEG_003` | 80 | 5 | 1,534 | 239.30 | 70 → 57.8 | yes · stock `ING_GOLDEN_PATTY` |
| Chimera Casserole | `RCP_MUT_004` | 63 | 4 | 247 | 41.50 | 38 → 31.3 | yes · stock `ING_MUTAGEN_GOO` |
| Evolution Burrito | `RCP_MUT_005` | 70 | 4 | 348 | 58.46 | 38 → 31.3 | yes · stock `ING_MUTAGEN_GOO` |
| Black Hole Bagel | `RCP_ALN_010` | 62 | 4 | 235 | 39.48 | 38 → 31.3 | yes · stock `ING_STARDUST` |
| Glorp Stew | `RCP_ALN_009` | 57 | 4 | 184 | 30.91 | 38 → 31.3 | yes · stock `ING_STARDUST` |
| The Unreasonably Large Burger | `RCP_BRG_015` | 60 | 4 | 213 | 59.64 | 38 → 31.3 | yes |
| Galaxy Pizza | `RCP_PIZ_015` | 55 | 4 | 167 | 46.76 | 38 → 31.3 | yes |
| Kraken Platter | `RCP_SEA_010` | 54 | 4 | 159 | 44.52 | 38 → 31.3 | yes |
| The Dessert That Bites Back | `RCP_DES_015` | 58 | 4 | 155 | 43.40 | 28 → 23.1 | yes |
| Bottomless Soup | `RCP_SOP_010` | 52 | 4 | 144 | 40.32 | 38 → 31.3 | yes |
| Shapeshifter Sushi | `RCP_MUT_003` | 55 | 4 | 167 | 28.06 | 38 → 31.3 | yes · stock `ING_MUTAGEN_GOO` |
| Asteroid Rock Candy | `RCP_ALN_008` | 53 | 4 | 152 | 25.54 | 38 → 31.3 | yes · stock `ING_STARDUST` |
| Pizza Inside Another Pizza | `RCP_PIZ_013` | 45 | 4 | 103 | 28.84 | 38 → 31.3 | yes |
| Invisible Burger | `RCP_BRG_014` | 50 | 4 | 131 | 36.68 | 38 → 31.3 | yes |
| Comet Kebab | `RCP_ALN_007` | 50 | 4 | 131 | 22.01 | 38 → 31.3 | yes · stock `ING_STARDUST` |
| Liquid Lightning | `RCP_DRK_015` | 49 | 4 | 87 | 24.36 | 16 → 13.2 | yes |
| Mega Taco Tower | `RCP_TAC_010` | 48 | 4 | 119 | 33.32 | 38 → 31.3 | yes |
| Morph Smoothie | `RCP_MUT_002` | 48 | 4 | 119 | 19.99 | 38 → 31.3 | yes · stock `ING_MUTAGEN_GOO` |
| Spicy Lava Lasagna | `RCP_PST_010` | 47 | 3 | 104 | 31.20 | 31 → 25.6 | yes |
| Galaxy Cheesecake | `RCP_DES_014` | 46 | 3 | 79 | 23.70 | 23 → 19.0 | yes |
| The Sandwich Sandwich | `RCP_SAN_010` | 42 | 3 | 81 | 24.30 | 31 → 25.6 | yes |
| UFO Saucer Pancakes | `RCP_ALN_006` | 45 | 3 | 94 | 16.92 | 31 → 25.6 | yes · stock `ING_STARDUST` |

**Interval constants**

- Demand_off = 190 × 1.650 × 1.173 × 0.6 = **220.6 customers/h**; Cap_seat = 24 × 3600 / 300 = **288/h**.
- Step-1 PrepSec_avg = 32.31 s; AvgTicket = 1.4 × mean price = 380.86 MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 +0.01) × CleanFactor 1.00 = 0.909.
- Preps counted 1.50 (+22 %), cashiers counted 1, DishFactor 1.00, Manager/Assistant coordination +14.2 %, stocker discount 14.5 %, delivery share 5.4 %, tip trait multiplier ×1.20.

**Hourly steps**

| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 95.0 | 3.086 | 343.5 | 334.3 | 220.6 | Demand | 220 | 76,178 | 6,676 | 4,139 | 12,580 | 13,670 | 60,742 |
| 2 | 1.00 | 91.0 | 3.035 | 337.5 | 328.6 | 220.6 | Demand | 221 | 76,524 | 6,706 | 4,089 | 12,645 | 13,670 | 61,004 |
| 3 | 1.00 | 87.0 | 2.985 | 331.5 | 322.9 | 220.6 | Demand | 220 | 76,178 | 6,676 | 4,003 | 12,595 | 13,670 | 60,591 |
| 4 | 1.00 | 83.0 | 2.935 | 325.6 | 317.3 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,953 | 12,660 | 13,670 | 60,853 |
| 5 | 1.00 | 79.0 | 2.885 | 319.7 | 311.7 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,886 | 12,668 | 13,670 | 60,779 |
| 6 | 1.00 | 75.0 | 2.836 | 313.9 | 306.2 | 220.6 | Demand | 220 | 76,178 | 6,676 | 3,802 | 12,617 | 13,670 | 60,368 |
| 7 | 1.00 | 71.0 | 2.787 | 308.1 | 300.7 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,753 | 12,682 | 13,670 | 60,631 |
| 8 | 1.00 | 67.0 | 2.738 | 302.4 | 295.3 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,687 | 12,689 | 13,670 | 60,558 |
| 9 | 1.00 | 63.0 | 2.690 | 296.7 | 289.9 | 220.6 | Demand | 220 | 76,178 | 6,676 | 3,605 | 12,639 | 13,670 | 60,150 |
| 10 | 1.00 | 59.0 | 2.642 | 291.1 | 284.6 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,557 | 12,703 | 13,670 | 60,414 |
| 11 | 1.00 | 55.0 | 2.594 | 285.5 | 279.3 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,492 | 12,710 | 13,670 | 60,342 |
| 12 | 1.00 | 51.0 | 2.547 | 280.0 | 274.0 | 220.6 | Demand | 220 | 76,178 | 6,676 | 3,413 | 12,659 | 13,670 | 59,937 |
| 13 | 1.00 | 47.0 | 2.500 | 274.5 | 268.8 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,365 | 12,724 | 13,670 | 60,201 |
| 14 | 1.00 | 43.0 | 2.453 | 269.0 | 263.6 | 220.6 | Demand | 220 | 76,178 | 6,676 | 3,286 | 13,317 | 13,670 | 59,153 |
| 15 | 1.00 | 39.0 | 2.406 | 263.6 | 258.4 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,239 | 13,734 | 13,670 | 59,065 |
| 16 | 1.00 | 35.0 | 2.360 | 258.3 | 253.3 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,176 | 13,741 | 13,670 | 58,996 |
| 17 | 1.00 | 31.0 | 2.314 | 253.0 | 248.3 | 220.6 | Demand | 220 | 76,178 | 6,676 | 3,100 | 14,005 | 13,670 | 58,279 |
| 18 | 1.00 | 27.0 | 2.269 | 247.8 | 243.3 | 220.6 | Demand | 221 | 76,524 | 6,706 | 3,053 | 17,393 | 13,670 | 55,221 |
| 19 | 1.00 | 23.0 | 2.224 | 242.6 | 238.3 | 220.6 | Demand | 221 | 76,524 | 6,706 | 2,992 | 18,671 | 13,670 | 53,881 |
| 20 | 1.00 | 19.0 | 2.179 | 237.4 | 233.4 | 220.6 | Demand | 220 | 76,178 | 6,676 | 2,918 | 18,206 | 13,670 | 53,896 |
| 21 | 1.00 | 15.0 | 2.134 | 276.4 | 228.5 | 220.6 | Demand | 221 | 36,147 | 3,168 | 1,356 | 9,033 | 13,670 | 17,968 |
| 22 | 1.00 | 11.0 | 2.090 | 270.4 | 223.7 | 220.6 | Demand | 221 | 36,147 | 3,168 | 1,328 | 9,037 | 13,670 | 17,935 |
| 23 | 1.00 | 7.0 | 2.046 | 264.4 | 218.8 | 218.8 | Service | 218 | 35,656 | 3,125 | 1,282 | 8,918 | 13,670 | 17,474 |
| 24 | 1.00 | 3.0 | 2.003 | 258.5 | 214.1 | 214.1 | Service | 215 | 35,165 | 3,082 | 1,238 | 8,800 | 13,670 | 17,015 |
| **Σ** | 24.00 | | | | | | | **5,287** | **1,670,830** | **146,419** | **75,712** | **309,427** | **328,080** | **1,255,453** |

Special stock used: `ING_GOLDEN_PATTY` 804, `ING_MUTAGEN_GOO` 1,071, `ING_STARDUST` 1,305 (left: 0, 0, 0). Stocker auto-buy: 14 top-ups in steps 14–20 costing 19,989 MB (charged inside those steps' Ingredients) until the 20,000 MB budget ran out. **SOLD OUT** from step 21: `RCP_LEG_001`, `RCP_LEG_002`, `RCP_LEG_003`, `RCP_MUT_004`, `RCP_MUT_005`, `RCP_ALN_010`, `RCP_ALN_009`, `RCP_MUT_003`, `RCP_ALN_008`, `RCP_ALN_007`, `RCP_MUT_002`, `RCP_ALN_006` — later steps recompute PrepSec_avg and AvgTicket without those dishes.

**Incidents & discoveries**

- Security Mitigation SM = 0.567; λ = 24.00 h × 0.6 × (1 − SM) = 6.236 → count = floor(λ) + roll(0.236) = **7**; eligible pool 53 incidents; Rh = 78,873 MB/h.
- Caps: negatives 5,048 ≤ 10 % of R (189,296) → scale ×1.00; positives 11,831 ≤ 15 % of R (283,944) → scale ×1.00.

| # | Step | Incident | MB effect | Damage value | Report line |
|---|---|---|---|---|---|
| 1 | 22 | `INC_053` Cake Catch of the Century | 2,366 | — | Hoverina caught a falling birthday cake 9 centimeters from the floor. Standing ovation. |
| 2 | 10 | `INC_040` Baron's Coupon Blitz | −2,524 | — | Baron Von Bistro handed out 45 coupons for Le Fancy Fin right outside our door. Rude. Effective. |
| 3 | 7 | `INC_031` Ratbeard's "Borrowing" | −631 | — | King Ratbeard's minions borrowed 4 crates and left an IOU written in cheese. |
| 4 | 20 | `INC_053` Cake Catch of the Century | 2,366 | — | Hoverina caught a falling birthday cake 8 centimeters from the floor. Standing ovation. |
| 5 | 24 | `INC_052` Grill Saved Mid-Sizzle | 2,366 | — | Gearhart fixed the grill mid-sizzle. 10 patties were saved and are grateful. |
| 6 | 23 | `INC_050` Omnivora Sniffs the Air | 4,732 | — | Chef Supreme Omnivora walked past, sniffed, and nodded 3 times. The kitchen hasn't stopped grinning. |
| 7 | 4 | `INC_038` Rainy-Day Lull | −1,893 | — | It rained 4 different flavors of weather. Customers stayed home. |

- Discoveries (MS chance 9.2 %/h after trait boost ×1.15; crate 1 %/h; capsule 5 %/h, ≤ 1 per UTC day): step 7: +1 MS; step 22: +3 MS; step 24: +3 MS; 1 Morph Capsule.

**Result**

| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 5,287 | 1,670,830 | 146,419 | 75,712 | −309,427 | −328,080 | 0 | +6,783 | **1,262,237** | 52,593 | 120,500 | **43.6 %** (base economy 43.4 %) |

#### 17.9.6 Example F — what goes wrong — TIER_04, one weak chef carrying an expensive floor team (closes early)

**Inputs**

| Parameter | Value | Derivation |
|---|---|---|
| Tier | `TIER_04` Morph City Grill | seats 10, base demand 95/h, employee cap 6 (§C6) |
| Player | level 19, EFFICIENCY 10 | Efficiency × 1.010; ingredient cost × 0.9850 |
| Reputation | 3.4 ★ | RepMult = 0.5 + 0.25 × 3.4 = 1.350 |
| Atmosphere | 40 | DecorMult = 0.9 + 0.003 × 40 = 1.020 |
| Stations | all Lv2 Tuned | PrepSec × (1 − 0.5 × (1 − 0.90)) = × 0.950 |
| Offline cap | 4 h | Gus (Common) → 4 h |
| Elapsed / simulated | 6 h 00 min / **4 h 00 min** (capped) | H = min(H_elapsed, cap) |
| Seed | `0xF442C339` | FNV-1a-32("81234567:1760650200:1") |

**Roster**

| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |
|---|---|---|---|---|---|---|---|---|---|---|
| Gus | `EMP_071` | Manager | Common | Rel 34, Svc 26, Acc 27 | 29.5 | 70 / 80 | 24.6 | ×1.00 | 0.246 | 17 |
| Toastmaster Tim | `EMP_003` | Chef | Common | Cook 33, Acc 31, Rel 25 | 31.6 | 70 / 80 | 26.4 | ×1.15 | 0.304 | 15 |
| Chet Speedwell | `EMP_028` | Waiter | Rare | Svc 68, Acc 58, Rel 53 | 63.5 | 70 / 80 | 53.1 | ×1.20 | 0.637 | 165 |
| Rocco | `EMP_066` | Security | Rare | Cmb 70, Rel 62, Svc 56 | 65.6 | 70 / 80 | 54.8 | ×1.00 | 0.548 | 170 |
| Skates McGee | `EMP_026` | Waiter | Uncommon | Svc 53, Acc 43, Rel 39 | 48.6 | 70 / 80 | 40.6 | ×1.20 | 0.487 | 55 |


**Interval constants**

- Demand_off = 95 × 1.350 × 1.020 × 0.6 = **78.5 customers/h**; Cap_seat = 10 × 3600 / 300 = **120/h**.
- Step-1 PrepSec_avg = 20.42 s; AvgTicket = 1.4 × mean price = 29.75 MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 +0.00) × CleanFactor 0.95 = 0.739.
- Preps counted 0.00 (+0 %), cashiers counted 0, DishFactor 0.80, Manager/Assistant coordination +4.7 %, stocker discount 0.0 %, delivery share 0.0 %, tip trait multiplier ×1.05.

**Hourly steps**

| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 1.00 | 80.0 | 0.304 | 32.0 | 94.2 | 32.0 | Kitchen | 32 | 703 | 47 | 0 | 309 | 422 | 19 |
| 2 | 1.00 | 75.0 | 0.297 | 31.4 | 92.2 | 31.4 | Kitchen | 31 | 681 | 46 | 0 | 300 | 422 | 5 |
| 3 | 1.00 | 70.0 | 0.291 | 30.7 | 90.3 | 30.7 | Kitchen | 31 | 681 | 46 | 0 | 300 | 422 | 5 |
| 4 (voided) | 1.00 | 65.0 | 0.285 | 30.0 | 88.3 | 30.0 | Kitchen | 30 | 659 | 44 | 0 | 290 | 422 | −8 |
| **Σ** | 3.00 | | | | | | | **94** | **2,066** | **139** | **0** | **909** | **1,266** | **30** |

Step 4 would have lost money (Net_step < 0), so the Manager **closed early**: that step is voided (no customers, no wages) and the simulation stops.

Incidents: λ = 1.28 → 1 drawn (29 MB net, within caps); discoveries: none.

**Result**

| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 94 | 2,066 | 139 | 0 | −909 | −1,266 | 0 | +29 | **59** | 20 | 3,100 | **0.6 %** (base economy 0.3 %) |

#### 17.9.7 Summary of the worked examples

| Example | Tier | Staff | Simulated | Customers | Net | Net / h | Active net / h (C4.4) | Offline ÷ active | Band 35–50 % |
|---|---|---|---|---|---|---|---|---|---|
| A | `TIER_01` | 1 | 2 h 00 min | 90 | 539 | 269 | 630 | 42.8 % | ✓ |
| B | `TIER_03` | 4 | 4 h 00 min | 287 | 2,687 | 672 | 1,730 | 38.8 % | ✓ |
| C | `TIER_05` | 8 | 8 h 00 min | 869 | 17,459 | 2,182 | 5,400 | 40.4 % | ✓ |
| D | `TIER_07` | 12 | 12 h 00 min | 1,771 | 92,754 | 7,730 | 17,400 | 44.4 % | ✓ |
| E | `TIER_10` | 18 | 24 h 00 min | 5,287 | 1,262,237 | 52,593 | 120,500 | 43.6 % | ✓ |
| F | `TIER_04` | 5 | 3 h 00 min | 94 | 59 | 20 | 3,100 | 0.6 % | ✗ (intentional) |

**What the examples show.**

- Every well-staffed example lands in the canon band (38.8–44.4 %); none approaches the 60 % ceiling, so the clamp is a
  safety net, not a balancing tool.
- The binding constraint teaches the next purchase: Example B is kitchen-bound until its single chef cooks a fast D2
  Night Menu; Example C swapped an unnecessary prep for a third waiter; Example E's Stocker budget ran dry in step 20
  and the special menu sold out for the last 4 h — the Welcome Back screen turns exactly these facts into Upgrade
  Suggestions (§17.10.4).
- Energy decay matters only for long caps: Example E's kitchen falls from 404 to 263 customers/h of capacity over
  24 h but stays above demand, because the roster was sized for the end of the shift.
- Example F shows the canon close-early rule: a single weak Common chef cannot feed a Rare/Uncommon floor team at
  `TIER_04` without a dishwasher; profit per step falls as Energy drops and step 4 is voided. The player still gets
  59 MB instead of a loss, and the report says why.


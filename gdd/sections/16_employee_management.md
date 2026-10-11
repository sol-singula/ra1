## 16. Employee Management

> Owner: A11 (Employees). Binding inputs: canon §C14 (roles, statistics, offline caps, `EMP_001`), §C4.8 (rarity
> bands), §C6 (employee cap per tier), §C22 E8 (wages). The offline half of this system is specified in §17; the
> archetype database is §36.8 and the offline incident database is §36.9. Every value marked **[TUNABLE]** is a
> balancing assumption that the systems in §17 and §22 already agree on.

### 16.1 Purpose

**Purpose.** Employees are the second engine of Mystery Morph Restaurant. While the player is online they absorb the
repetitive half of the restaurant (washing, re-stocking, seating, standard tickets), so the player can chase the
fun half: tricky orders, brawls, repairs, the city. While the player is offline they keep the restaurant open and
turn hours away into a **Welcome Back** report (§17) — the single strongest daily-return driver in the game. The
brief calls this "a major gameplay system"; we design it as a full management sim layered on top of the action game,
never as a passive bonus.

Design rules (they settle every later trade-off):

1. **Offline complements, never replaces.** A well-staffed restaurant earns 35–50 % of active net per hour offline
   (canon §C15; proven in §17.9). Research Tokens, recipe learning, quests, combat, skill points and most XP stay
   active-only.
2. **Every hire is a decision.** A candidate always trades something: wage vs output, a great trait vs a funny
   drawback (the Dragon Chef burns 6 % of grill items), rarity vs the employee cap of the tier. There is no "best
   employee" for every restaurant — the bottleneck decides (§16.9 ROI table).
3. **Employees are morphs.** Their mutations are canon parts (§12, §36.3) and those parts *are* their abilities:
   an octopus cooks two things at once, a cheetah delivers fast, a rhino stops brawls. The same family/tag system that
   drives player synergies drives employee traits (§16.5), so new mutation parts automatically create new employees.
4. **Earnable only.** Hiring, rerolls, training and raises cost MB; nothing in this system is sold for Robux and
   offline earnings never depend on purchases (§23).
5. **Failure is funny, not devastating.** Bad staffing produces sulky cartoon moments and smaller reports, never
   debt: balances cannot go negative (E8) and the Manager closes early instead of losing money (§17).

### 16.2 Employee Roles

**Rules & Mechanics.** Each employee has a *native role* (from its archetype, §36.8) and an *assigned role* (default =
native). An employee can be assigned any unlocked role; off-native assignments use that role's stat weights and an
**Unfamiliar ×0.85** penalty to RoleStatAvg until a Cross-Training course (§16.7.4) removes it. Roles unlock by tier;
the employee cap is canon §C6. Only one Manager and one Assistant Manager may be assigned at a time.

| ID | Role | Unlock | RoleStatAvg weights | Online responsibilities (task types, §16.3) | Offline contribution (canon §C14.1, formulas §17.4) | Limit |
|---|---|---|---|---|---|---|
| `ROLE_CHEF` | Chef | `TIER_01` | 0.6 Cook + 0.3 Accuracy + 0.1 Reliability | `CookTicket` at assigned station group: claims a station slot, fetches, cooks, assembles, plates to `STN_WINDOW`; at `TIER_01`–`TIER_02` also hands food over the counter | Kitchen capacity: Σ (3600 / PrepSec_avg) × Contribution / 1.4. **Required** — no Chef, no offline customers | — |
| `ROLE_PREP` | Prep Cook | `TIER_01` | 0.4 Cook + 0.4 Service + 0.2 Accuracy | `PrepComponent`: chops, mixes and pre-cooks components into the `STN_PREP` holds the chefs pull from; washes produce | +15 % kitchen capacity per prep (Multi-Tasker prep counts 1.25, `EMP_021` counts 1.5), max +45 % | 3 counted |
| `ROLE_WAITER` | Waiter | `TIER_03` | 0.6 Service + 0.3 Accuracy + 0.1 Reliability | `SeatParty`, `TakeOrder`, `DeliverPlate`, bussing; carries 1 tray (+1 Grabby, max 3) | Service capacity Σ (3600 / 45) × Contribution × (1 + 0.10 × cashiers); needed at `TIER_03`+ (else 30 % of kitchen) | — |
| `ROLE_CASHIER` | Cashier | `TIER_01` | 0.5 Accuracy + 0.4 Service + 0.1 Reliability | `ProcessPayment` at the register (`ANM_066`); at `TIER_01`–`TIER_02` also `TakeOrder` at the counter | +10 % service capacity each (max 3 counted); tips × (1 + 0.01 × floor(cashierSkill / 20)) | 3 counted |
| `ROLE_DISH` | Dishwasher | `TIER_01` | 0.5 Service + 0.5 Reliability | `WashRack` at `STN_DISHWASH` (`ANM_021`); keeps ≥ 4 clean plates ready | Prevents "No Clean Plates": without one, kitchen capacity × 0.80 at `TIER_04`+ | — |
| `ROLE_CLEANER` | Cleaner | `TIER_01` | 0.5 Service + 0.3 Reliability + 0.2 Accuracy | `CleanMess` (trash, spills, broken plates; `ANM_022`, `ANM_023`); keeps cleanliness K high | Without one, offline quality q × 0.95 (`TIER_04`–`TIER_06`) / × 0.92 (`TIER_07`+); enables passing inspections (§36.9) | — |
| `ROLE_REPAIR` | Repair Technician | `TIER_02` | 0.7 Repair + 0.2 Reliability + 0.1 Service | `RepairObject` jobs from `RepairService` (`ANM_060`, `ANM_061`); `ExtinguishFire` | Auto-repairs offline damage at −(Repair / 200) discount (+10 pp Wall Crawler, max 60 %) | — |
| `ROLE_SECURITY` | Security Guard | `TIER_03` | 0.6 Combat + 0.2 Reliability + 0.2 Service | `InterceptHostile`: calms or subdues customers at anger level ≥ 3 (§16.3.3) | Security Mitigation SM = Σ (0.25 × Contribution + 0.10 Bouncer + 0.05 Heavyweight), max 0.60: incident count × (1 − SM) | — |
| `ROLE_MANAGER` | Restaurant Manager | `TIER_02` | 0.4 Reliability + 0.3 Service + 0.3 Accuracy | `Coordinate` aura: team Morale baseline +5 (+10 Epic+), schedules breaks, takes over `SeatParty` when idle | Sets the offline cap by rarity (canon §C14.3); Energy decay 5 %/h instead of 8; coordination +3–10 % capacity | 1 |
| `ROLE_DELIVERY` | Delivery Worker | `TIER_04` | 0.6 Service + 0.3 Reliability + 0.1 Combat | `RunDelivery`: carries bagged orders from `STN_WINDOW` to city doorsteps (cosmetic run; revenue on hand-off) | Delivery revenue = Revenue × min(15 %, Σ 0.06 × Contribution), limited by spare kitchen capacity | — |
| `ROLE_STOCKER` | Ingredient Stocker | `TIER_04` | 0.5 Accuracy + 0.3 Reliability + 0.2 Service | `Restock`: unloads `STN_DELIVERY` crates, refills Pantry, warns before SOLD OUT | Ingredient discount 5–15 % (0.05 + 0.10 × Contribution); auto-buys special stock within the player's budget | — |
| `ROLE_ASST_MGR` | Assistant Manager | `TIER_05` | 0.4 Reliability + 0.3 Service + 0.3 Accuracy | Covers Manager tasks when the Manager is on break; settles staff arguments | +2 h offline cap (requires a Manager; absolute max 24 h), −20 % incident losses, coordination +2–5 % | 1 |

**Role behavior notes (online).**

- **Chef.** Works only recipes whose difficulty D ≤ 1 + floor(Cooking / 25) (canon skill gate) and whose stations
  exist; anything harder stays on the ticket rail for the player, highlighted "Chef can't do this one!". A chef never
  starts a ticket the player has already claimed (§16.3.1 reservation).
- **Waiter.** Seats in arrival order except Rich/celebrity personalities (`PER_008`, `PER_009`) who are seated first;
  delivers to the ticket's seat; on a missed modification the customer gets the normal Accuracy penalty (§10).
- **Security Guard.** Patrols an assigned post (Door / Dining / Kitchen). Never attacks a customer below anger 45.
- **Manager.** Never cooks; is the only role allowed to "close" the restaurant in Away Mode (§16.3.4).

### 16.3 Online Work AI

#### 16.3.1 Task board and utility scoring

Other services post **tasks** to a per-restaurant `TaskBoard`; each idle or re-evaluating employee picks the task with
the highest utility. Tasks are *reserved* by one actor (player or employee) — players always win a reservation
conflict, and an employee whose task is claimed by a player drops it within 0.25 s.

```
U(task, emp) = RoleFit(task, emp.role) × (Base + Urgency) × (0.5 + Contribution) × ZoneBonus
               − 0.02 × pathDistanceStuds − SwitchPenalty
RoleFit   : 1.0 native task of the role, listed secondary fit (0.3–0.6), else 0 (never chosen)
ZoneBonus : 1.3 inside the employee's assigned workstation/zone, else 1.0
SwitchPenalty : 15 if the employee would abandon an in-progress task, else 0
Contribution  : Efficiency/100 × trait multiplier (§16.4), recomputed every 10 s
```

| Task type | Posted by | Roles (RoleFit) | Base | Urgency term |
|---|---|---|---|---|
| `CookTicket` | `OrderService` | Chef 1.0, Prep 0.4 | 50 | + 40 × (oldest ticket wait ÷ its patience) |
| `PrepComponent` | `CookingService` | Prep 1.0, Chef 0.5 | 40 | + 20 × queued components ÷ 3 |
| `SeatParty` | `CustomerAIService` | Waiter 1.0, Manager 0.5 | 45 | + 30 × queue wait ÷ 30 s |
| `TakeOrder` | `CustomerAIService` | Waiter 1.0, Cashier 0.4 (1.0 at `TIER_01`–`TIER_02`) | 55 | + 45 × ordering-patience used |
| `DeliverPlate` | `CookingService` (window) | Waiter 1.0, any role 0.3 | 60 | + 50 × patience used |
| `ProcessPayment` | `CustomerAIService` | Cashier 1.0, Waiter 0.5 | 40 | + 20 |
| `WashRack` | `CookingService` | Dishwasher 1.0, Prep 0.3 | 30 | + 50 if clean plates < 4 |
| `CleanMess` | `RepairService` (mess list) | Cleaner 1.0, Dishwasher 0.3 | 25 | + 3 per point of cleanliness below 90 |
| `RepairObject` | `RepairService` | Repair 1.0, Cleaner 0.3 | 35 | + 40 if Broken, + 20 if Cracked |
| `ExtinguishFire` | `CookingService` | any 1.0 (Splash Zone ×2) | 95 | — |
| `InterceptHostile` | `CustomerAIService` | Security 1.0, Manager 0.3 | 80 | + 15 × anger level |
| `Restock` | `InventoryService` | Stocker 1.0 | 30 | + 60 if a menu recipe goes SOLD OUT within 5 min |
| `RunDelivery` | `OrderService` | Delivery 1.0 | 40 | + 30 × order age ÷ 120 s |
| `Break` | `EmployeeService` | self | 70 if Energy < 25 % (forced < 10 %) | — |
| `IdleTidy` | `EmployeeService` | any | 5 | — (wipes tables, poses, hums) |

**Scheduler.** One `EmployeeBrain` loop per restaurant runs at **4 Hz** [TUNABLE], staggered by plot index
(offset 0.03 s × plotIndex) so 8 restaurants never tick on the same frame. Each tick re-evaluates at most 5
employees round-robin plus any employee whose task just finished or failed; interruptible tasks are re-scored every
1.5 s. A task that fails twice (path blocked, station destroyed) is released with a 5 s cooldown for that employee.

#### 16.3.2 Action timing and quality

| Quantity | Formula [TUNABLE] | Notes |
|---|---|---|
| Walk speed (studs/s) | `(12 + 0.06 × Service) × move` (Speedster 1.35, Heavyweight 0.9, Unhurried 0.6), max 21 | Players walk 16–21 (§C3) |
| Floor handling time (seat, order entry, hand-off, payment) | `Base × 1 / (0.6 + 0.8 × Service/100)` | Calculator Brain payment 0.5 s flat |
| Kitchen handling time (fetch, assemble, plate) | `Base × 1 / (0.6 + 0.8 × Cook/100)` | Station process time is physical (§5, §C4.9) and identical for everyone |
| Heat item grade | P(PERFECT) = 0.05 + 0.55·Acc/100 + 0.15·Cook/100; P(BURNED) = max(0.01, 0.12 − 0.10·Acc/100) + trait burn chance; P(UNDERCOOKED) = max(0.01, 0.08 − 0.07·Cook/100); else GOOD | Ember adds 6 % burn; Toastmaster Tim halves burns |
| Chop grade | Clean cut chance 0.2 + 0.7·Acc/100, else yellow (0.8) | never MUSHY |
| Order mistake (waiter/cashier) | `0.10 × (1 − Acc/100) × (1.5 − Rel/100)` per order | wrong table or a dropped modification |
| Wander-off (Reliability) | `0.2 × (1 − Rel/100)` per online hour: 2 min idle "daydream" | shown as a thought bubble |

A typical Uncommon chef produces Food Quality around 0.75–0.80 and a Legendary one around 0.92 — a skilled player at
PERFECT timing (1.00) stays the best cook in the building, by design.

#### 16.3.3 Customers, combat and repairs

- **Interception (Security).** Trigger: a customer reaches anger ≥ 45 (level 3) within 30 studs of the guard's post
  (anywhere if no post). The guard walks over and channels **Calm Talk** for 2.0 s:
  `P(calm) = clamp(0.25 + 0.6 × Combat/100 + 0.25 [Bouncer] − 0.10 × (angerLevel − 3), 0.10, 0.95)`. Success: anger
  −40 and the customer enters *Calming down*. Failure: the guard **subdues** — 4 + Combat/10 Huff Points per hit every
  1.2 s until the customer is `STS_DIZZY` and is escorted out with the canon Apology Payment (40 %, no tip). At
  level 6 chaos guards target the angriest customer first.
- **Staff safety.** Employee HP = 60 + Combat. At 0 the employee plays Seeing Stars (`ANM_062`) for 8 s and returns
  at 50 % HP and −5 Morale — never removed, never "lost". Non-guard staff within 8 studs of a hostile customer flee
  (`ANM_054`) and resume after 4 s; a thrown item that hits a carrying employee drops the plate 50 % of the time
  (0 % with Sticky Grip). Employees never damage customers except guards subduing a level ≥ 3 customer.
- **Repairs.** Repair Technicians take `RepairService` jobs; repair rate = base × (0.5 + Repair/100) × traits (Electric
  appliances ×1.3, Wall Crawler travel ×0.6). Material cost × (1 − Repair/400). A job absorbs new damage and converts to
  Rebuild if the object reaches Destroyed; cost is charged once at completion (canon E3).
- **Co-op.** Guests' actions reserve tasks like the owner's; employees obey the owner's assignments only.

#### 16.3.4 Away Mode (owner online, outside the restaurant) [TUNABLE]

When the owner is in the server but no player has been inside the interior for 60 s, the interior finishes its current
customers (≤ 60 s), despawns the proxies and runs the **§17 model in real time** with 60-second steps (same
formulas, demand factor 0.6, incidents and discoveries off, Energy/Morale use the offline rates). Income is credited
every 60 s through `EconomyService` with source `away_mode`; wages are paid by the normal wage tick. Away Mode needs
≥ 1 Chef and stops ("Closed — owner napping") when the owner has made no validated gameplay action for 15 min; at that
moment `lastSimAt` is written, so AFK time becomes ordinary capped offline time instead of an exploit. This lets a
player explore Morph City (§18) without abandoning the restaurant — the brief's "events should encourage players to
leave their restaurants". Flagged for review in §38.


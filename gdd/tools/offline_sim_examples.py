#!/usr/bin/env python3
"""Reference implementation of the section 17 offline model + the five worked examples.

Python 3 stdlib only. Run from the repo root:
    python3 gdd/tools/offline_sim_examples.py            # prints the markdown used in section 17.9
    python3 gdd/tools/offline_sim_examples.py --check    # asserts the canon C15 target band, prints a summary

The deterministic economy (demand, capacities, revenue, tips, ingredients, wages, energy, morale,
special-stock depletion, close-early rule, caps) is computed exactly as specified in section 17 and must
match the Luau OfflineEarningsService to the MB (golden tests, section 17.14). Random draws (incident count
extra roll, incident picks, discoveries) use Python's random.Random(seed) here; the live game uses Luau
Random.new(seed) with the same seed, so the *draws* differ from this reference while the distribution,
weights and caps are identical. Seed = FNV-1a-32("<UserId>:<lastSimAt>:<SIM_VERSION>").
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import a11_canon as C  # noqa: E402

TIERS = C.tiers()
RECIPES = C.recipes()
EMP = {a["id"]: a for a in json.load(open(os.path.join(C.DATA, "employees.json"), encoding="utf-8"))["archetypes"]}
EMPDATA = json.load(open(os.path.join(C.DATA, "employees.json"), encoding="utf-8"))
INCIDENTS = json.load(open(os.path.join(C.DATA, "offline_incidents.json"), encoding="utf-8"))["incidents"]
ROLE_W = EMPDATA["role_weights"]

# ---------------------------------------------------------------- constants (section 17.3) [TUNABLE]
SIM_VERSION = 1
OFFLINE_DEMAND_FACTOR = 0.6          # canon C15
VISIT_SECONDS_OFFLINE = 300          # canon C15
WAITER_SECONDS_PER_CUSTOMER = 45     # canon C15 (3600/45 per waiter)
ITEMS_PER_CUSTOMER = 1.4             # canon C4.3
PREP_BONUS, MAX_PREPS = 0.15, 3      # canon C14.1 / C15
CASHIER_BONUS, MAX_CASHIERS = 0.10, 3
NO_WAITER_FACTOR = 0.30              # canon C15
DISH_FACTOR_ABSENT = 0.80            # canon C14.1 (T4+)
CLEAN_FACTOR_ABSENT = {4: .95, 5: .95, 6: .95, 7: .92, 8: .92, 9: .92, 10: .92}
Q_BASE, Q_SLOPE, Q_MAX = 0.70, 0.25, 0.95
TIP_BASE, TIP_SLOPE = 0.04, 0.04
INCIDENT_RATE = 0.6
NEG_CAP, POS_CAP = 0.10, 0.15
ENERGY_DECAY, ENERGY_DECAY_MGR, ENERGY_DECAY_FLOOR = 8.0, 5.0, 3.0
MORALE_DECAY = 1.0
MS_CHANCE, CRATE_CHANCE, CAPSULE_CHANCE = 0.08, 0.01, 0.05
DISCOVERY_BOOST_CAP = 1.25
STATION_MULT = {1: 1.0, 2: 0.9, 3: 0.8, 4: 0.7, 5: 0.6}  # canon C4.9 process time
PROCESS_SHARE = 0.5
OFF_ROLE_PENALTY = 0.85
TRAIT_MULT_CAP = 1.5
OFFLINE_CEILING_SHARE = 0.60         # canon C15 "never above 60 %" -> hard clamp
CAP_HOURS = {None: 2, "Common": 4, "Uncommon": 4, "Rare": 8, "Epic": 12, "Legendary": 24}
ASST_CAP_BONUS, ABS_CAP = 2, 24
COST_PER_DAMAGE_POINT = {1: 1, 2: 1.5, 3: 2.5, 4: 4, 5: 7, 6: 12, 7: 20, 8: 35, 9: 60, 10: 100}

CAT_FACTOR = {"DRK": .7, "FRI": .7, "SAL": .7, "DES": .8, "LEG": 2.5}
ING_RATIO = {1: .36, 2: .33, 3: .30, 4: .28, 5: .26}
SPECIAL_BASIC_SHARE = 0.6


def prep_sec_base(cat, d):
    if cat == "DRK":
        return 4 + 3 * d
    if cat in ("DES", "FRI", "SAL"):
        return 8 + 5 * d
    if cat == "LEG":
        return 20 + 10 * d
    return 10 + 7 * d


def price(level, d, cat):
    return int(round(10 * 1.05 ** (level - 1) * (0.8 + 0.1 * d) * CAT_FACTOR.get(cat, 1.0)))


def fnv1a32(s):
    h = 2166136261
    for ch in s.encode():
        h ^= ch
        h = (((h << 24) & 0xFFFFFFFF) + h * 403) % 4294967296  # == h * 16777619 mod 2^32
    return h


def fmt(x, d=0):
    if d == 0:
        v = int(round(x))
        return ("−" if v < 0 else "") + "{:,}".format(abs(v))
    return ("−" if x < 0 else "") + ("{:,.%df}" % d).format(abs(x))


# ---------------------------------------------------------------- employee helpers
class Staff:
    def __init__(self, spec):
        a = EMP[spec["id"]]
        self.a = a
        self.id = a["id"]
        self.short = a["name"].split('"')[1] if '"' in a["name"] else a["name"].split()[0]
        self.role = spec.get("role", a["role"])
        self.stats = dict(a["stats"])
        self.stats.update(spec.get("trained", {}))
        self.morale0 = spec["morale"]
        self.energy0 = spec["energy"]
        self.wage = spec.get("wage", a["wage"])
        self.traits = list(a["traits"])
        self.pers = a["personality"]
        fams = [C.mutations()[p]["family"] for p in a["parts"]] if False else None
        self.kraken = any(p in ("MUT_038", "MUT_137", "MUT_165") for p in a["parts"])

    def eff_stats(self):
        s = dict(self.stats)
        if "Calculator Brain" in self.traits:
            s["rel"] = min(100, s["rel"] + 5)
        return s

    def role_stat_avg(self):
        s = self.eff_stats()
        v = sum(s[k] * w for k, w in ROLE_W[self.role].items())
        if self.role != self.a["role"]:
            v *= OFF_ROLE_PENALTY
        return v

    def trait_mult(self, ctx):
        m = 1.0
        r = self.role
        t = self.traits
        if "Multi-Tasker" in t and r in ("ROLE_CHEF", "ROLE_DISH", "ROLE_REPAIR", "ROLE_CLEANER"):
            m *= 1.35 if self.kraken else 1.25
        if "Speedster" in t and r in ("ROLE_WAITER", "ROLE_DELIVERY", "ROLE_CLEANER"):
            m *= 1.20
        if "Flying" in t and r in ("ROLE_WAITER", "ROLE_DELIVERY"):
            m *= 1.15
        if "Grabby" in t and r == "ROLE_WAITER":
            m *= 1.10
        if "Grill Master" in t and r == "ROLE_CHEF":
            m *= 1.15
        if "Ice Hands" in t and r == "ROLE_CHEF":
            share = ctx.get("drk_des_share", 0)
            m *= 1.10 if share >= 0.5 else (1.05 if share >= 0.25 else 1.0)
        if "Splash Zone" in t and r == "ROLE_DISH":
            m *= 1.10
        if "Unhurried" in t:
            m *= 0.6
        return min(TRAIT_MULT_CAP, m)

    def decay(self, has_mgr, extra_mgr_bonus):
        d = ENERGY_DECAY_MGR if has_mgr else ENERGY_DECAY
        d -= extra_mgr_bonus
        if self.pers == "Night Owl":
            d -= 2
        d = max(ENERGY_DECAY_FLOOR, d)
        if "Regenerator" in self.traits:
            d *= 0.75
        if "Unhurried" in self.traits:
            d *= 0.5
        return d


def efficiency(st, morale, energy, eff_stat):
    """canon C14.2, returned on the 0-100+ scale"""
    return st.role_stat_avg() * (0.6 + 0.4 * morale / 100) * (0.7 + 0.3 * energy / 100) * (1 + 0.001 * eff_stat)


# ---------------------------------------------------------------- the simulation
def simulate(ex):
    T = TIERS[ex["tier"]]
    tier = ex["tier"]
    staff = [Staff(s) for s in ex["roster"]]
    by_role = {}
    for s in staff:
        by_role.setdefault(s.role, []).append(s)
    mgrs = by_role.get("ROLE_MANAGER", [])
    assts = by_role.get("ROLE_ASST_MGR", [])
    has_mgr = bool(mgrs)
    best_mgr_rarity = None
    if mgrs:
        order = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
        best_mgr_rarity = max((m.a["rarity"] for m in mgrs), key=order.index)
    cap = CAP_HOURS[best_mgr_rarity]
    if has_mgr and assts:
        cap = min(ABS_CAP, cap + ASST_CAP_BONUS)
    H_el = ex["elapsed_h"]
    H = min(H_el, cap)
    steps = []
    k = 0
    while k < H - 1e-9:
        steps.append(min(1.0, H - k))
        k += 1
    seed = fnv1a32("%d:%d:%d" % (ex["user_id"], ex["last_sim_at"], SIM_VERSION))
    rng = random.Random(seed)

    # restaurant-level snapshot
    eff_stat = ex["player_eff"]
    stars = ex["stars"]
    atm = ex["atmosphere"]
    glow = min(0.02, 0.006 * sum(1 for s in staff if "Glow-Up" in s.traits))
    rep_mult = 0.5 + 0.25 * stars
    decor_mult = 0.9 + 0.003 * atm + glow
    demand = T["base_demand"] * rep_mult * decor_mult * OFFLINE_DEMAND_FACTOR
    cap_seat = T["seats"] * 3600 / VISIT_SECONDS_OFFLINE
    st_mult = STATION_MULT_AVG = ex["station_mult"]
    chefs = by_role.get("ROLE_CHEF", [])
    best_cook = max(s.stats["cook"] for s in chefs) if chefs else 0
    dmax = 1 + best_cook // 25
    menu = []
    for m in ex["menu"]:
        r = RECIPES[m["rcp"]]
        p = price(r["level"], m["d"], r["cat"])
        ing = p * ING_RATIO[m["d"]] * (SPECIAL_BASIC_SHARE if m.get("special") else 1.0)
        ps = prep_sec_base(r["cat"], m["d"])
        menu.append(dict(m, name=r["name"], level=r["level"], cat=r["cat"], price=p, ing=ing, prep=ps,
                         prep_eff=ps * (1 - PROCESS_SHARE * (1 - st_mult)), cookable=m["d"] <= dmax))
    stock = dict(ex.get("stock", {}))
    stock0 = dict(stock)
    ctx = {"drk_des_share": sum(1 for m in menu if m["cat"] in ("DRK", "DES")) / len(menu)}

    # modifiers that do not change per step
    stockers = by_role.get("ROLE_STOCKER", [])
    cashiers = by_role.get("ROLE_CASHIER", [])
    waiters = by_role.get("ROLE_WAITER", [])
    preps = by_role.get("ROLE_PREP", [])
    dishes = by_role.get("ROLE_DISH", [])
    cleaners = by_role.get("ROLE_CLEANER", [])
    repairs = by_role.get("ROLE_REPAIR", [])
    guards = by_role.get("ROLE_SECURITY", [])
    couriers = by_role.get("ROLE_DELIVERY", [])
    prep_count = min(MAX_PREPS, sum(1.5 if p.id == "EMP_021" else (1.25 if "Multi-Tasker" in p.traits else 1.0) for p in preps))
    cashier_count = min(MAX_CASHIERS, sum(2 if c.id == "EMP_038" else 1 for c in cashiers))
    dish_factor = DISH_FACTOR_ABSENT if (tier >= 4 and not dishes) else 1.0
    clean_factor = CLEAN_FACTOR_ABSENT.get(tier, 1.0) if not cleaners else 1.0
    mgr_bonus_decay = (1 if any(m.id == "EMP_070" for m in mgrs) else 0) + (1 if any(a.id == "EMP_097" for a in assts) else 0)
    q_adj = min(0.03, 0.02 * sum(1 for c in chefs if "Chef's Instinct" in c.traits)) \
        - min(0.04, 0.02 * sum(1 for c in chefs if "Grill Master" in c.traits))
    tip_trait = 1 + min(0.10, 0.05 * sum(1 for s in waiters + cashiers if "Charmer" in s.traits)) \
        + (0.10 if any("Golden Touch" in s.traits for s in staff) else 0)
    tip_trait = min(1.25, tip_trait)
    deliv_cap = 0.15 + (0.02 if any(c.id == "EMP_084" for c in couriers) else 0)

    E = {s.id: s.energy0 for s in staff}
    Mo = {s.id: s.morale0 for s in staff}
    rows = []
    carry = 0.0
    closed_at = None
    tot = dict(N=0, rev=0.0, tips=0.0, deliv=0.0, ing=0.0, wages=0.0, hours=0.0)
    stock_used = {}
    sold_out = []
    first_ctx = None
    budget = float(ex.get("stocker_budget", 0))
    autobuy_log = []
    for i, hstep in enumerate(steps):
        autobuy_step = 0.0
        eff = {s.id: efficiency(s, Mo[s.id], E[s.id], eff_stat) for s in staff}
        contrib = {s.id: eff[s.id] / 100 * s.trait_mult(ctx) for s in staff}
        coord = 0.0
        if mgrs:
            bm = max(mgrs, key=lambda m: contrib[m.id])
            coord = min(0.10, 0.03 + 0.07 * contrib[bm.id])
            if bm.id == "EMP_072" or "Loudmouth" in bm.traits:
                coord = min(0.12, coord + 0.02)
        if assts:
            ba = max(assts, key=lambda a: contrib[a.id])
            coord += min(0.05, 0.02 + 0.03 * contrib[ba.id])
        coord = min(0.15, coord)
        # Stocker auto-buy (section 17.4): top up each special pool to this step's expected need, within budget
        if stockers and budget > 0:
            cand = [m for m in menu if m["cookable"]]
            q_est = rows[-1]["Q"] if rows else demand
            for ingr in sorted(set(m["special"] for m in cand if m.get("special"))):
                users = [m for m in cand if m.get("special") == ingr]
                need = q_est * hstep * ITEMS_PER_CUSTOMER * len(users) / len(cand)
                short = math.ceil(max(0.0, need - stock.get(ingr, 0)))
                if short <= 0:
                    continue
                unit = sum(m["price"] * ING_RATIO[m["d"]] * (1 - SPECIAL_BASIC_SHARE) for m in users) / len(users)
                bs0 = max(stockers, key=lambda x: x.role_stat_avg())
                disc0 = min(0.15, 0.05 + 0.10 * min(1, bs0.role_stat_avg() / 100) + (0.02 if bs0.id in ("EMP_088", "EMP_090") else 0))
                units = min(short, int(budget // (unit * (1 - disc0))))
                if units > 0:
                    cost = units * unit * (1 - disc0)
                    budget -= cost
                    stock[ingr] = stock.get(ingr, 0) + units
                    autobuy_step += cost
                    autobuy_log.append((i + 1, ingr, units, cost))
        live = [m for m in menu if m["cookable"] and (not m.get("special") or stock.get(m["special"], 0) >= 1)]
        for m in menu:
            if m["cookable"] and m not in live and m["rcp"] not in [x[0] for x in sold_out]:
                sold_out.append((m["rcp"], i + 1))
        prep_avg = sum(m["prep_eff"] for m in live) / len(live)
        ticket = ITEMS_PER_CUSTOMER * sum(m["price"] for m in live) / len(live)
        ing_avg = ITEMS_PER_CUSTOMER * sum(m["ing"] for m in live) / len(live)
        cap_k = sum(3600 / prep_avg * contrib[c.id] / ITEMS_PER_CUSTOMER for c in chefs) \
            * (1 + PREP_BONUS * prep_count) * dish_factor * (1 + coord)
        if tier <= 2:
            cap_s = cap_k
        elif waiters:
            cap_s = sum(3600 / WAITER_SECONDS_PER_CUSTOMER * contrib[w.id] for w in waiters) \
                * (1 + CASHIER_BONUS * cashier_count) * (1 + coord)
        else:
            cap_s = NO_WAITER_FACTOR * cap_k
        Q = min(demand, cap_seat, cap_k, cap_s)
        lim = min([("Demand", demand), ("Seats", cap_seat), ("Kitchen", cap_k), ("Service", cap_s)], key=lambda x: x[1])[0]
        x = Q * hstep + carry
        N = math.floor(x + 1e-9)
        carry = x - N
        avg_acc = sum(c.stats["acc"] for c in chefs) / len(chefs)
        q = min(Q_MAX, Q_BASE + Q_SLOPE * avg_acc / 100 + q_adj) * clean_factor
        rev = N * ticket * q
        avg_wsvc = sum(w.stats["svc"] for w in waiters) / len(waiters) if waiters else 0
        cash_skill = 0
        if cashiers:
            bc = max(cashiers, key=lambda c: c.role_stat_avg())
            cash_skill = min(100, bc.role_stat_avg() * (1.5 if "Calculator Brain" in bc.traits else 1))
        tips = rev * (TIP_BASE + TIP_SLOPE * avg_wsvc / 100) * (1 + 0.01 * math.floor(cash_skill / 20)) * tip_trait
        dpct = min(deliv_cap, sum(0.06 * contrib[c.id] for c in couriers)) if couriers else 0
        if Q > 0:
            dpct = min(dpct, max(0.0, cap_k / Q - 1))
        deliv = rev * dpct
        n_del = N * dpct
        sdisc = 0.0
        if stockers:
            bs = max(stockers, key=lambda s: contrib[s.id])
            sdisc = 0.05 + 0.10 * min(1, contrib[bs.id])
            if any("Sniffer" in s.traits for s in stockers):
                sdisc += 0.02
            if any(s.id in ("EMP_088", "EMP_090") for s in stockers):
                sdisc += 0.02
            sdisc = min(0.15, sdisc)
        ing = (N + n_del) * ing_avg * (1 - sdisc) * (1 - 0.0015 * eff_stat) + autobuy_step
        wages = sum(s.wage for s in staff) * hstep
        net = rev + tips + deliv - ing - wages
        # special stock consumption
        for m in live:
            if m.get("special"):
                want = (N + n_del) * ITEMS_PER_CUSTOMER / len(live)
                use = min(stock[m["special"]], want)
                stock[m["special"]] -= use
                stock_used[m["special"]] = stock_used.get(m["special"], 0) + use

        row = dict(step=i + 1, h=hstep, E=sum(E.values()) / len(E), M=sum(Mo.values()) / len(Mo),
                   chef_contrib=sum(contrib[c.id] for c in chefs), prep_avg=prep_avg, ticket=ticket,
                   cap_k=cap_k, cap_s=cap_s, Q=Q, lim=lim, N=N, q=q, rev=rev, tips=tips, deliv=deliv,
                   ing=ing, wages=wages, net=net, coord=coord, live=len(live), sdisc=sdisc, dpct=dpct,
                   eff=eff, contrib=contrib, autobuy=autobuy_step)
        if first_ctx is None:
            first_ctx = row
        if net < 0:
            closed_at = i + 1
            row["voided"] = True
            rows.append(row)
            break
        rows.append(row)
        for kk in ("rev", "tips", "deliv", "ing", "wages"):
            tot[kk] += row[kk]
        tot["N"] += N
        tot["hours"] += hstep
        for s in staff:
            E[s.id] = max(0.0, E[s.id] - s.decay(has_mgr, mgr_bonus_decay) * hstep)
            Mo[s.id] = max(0.0, Mo[s.id] - MORALE_DECAY * hstep * (0.5 if s.pers == "Zen Noodle" else 1))
    H_op = tot["hours"]
    R_total = tot["rev"] + tot["tips"] + tot["deliv"]
    Rh = R_total / H_op if H_op else 0

    # ---------------- incidents (count over operated hours, canon C15)
    sm = 0.0
    for g in guards:
        c = first_ctx["contrib"][g.id]
        sm += 0.25 * c + (0.10 if "Bouncer" in g.traits else 0) + (0.05 if "Heavyweight" in g.traits else 0)
    sm = min(0.60, sm)
    lam = H_op * INCIDENT_RATE * (1 - sm)
    count = math.floor(lam) + (1 if rng.random() < (lam - math.floor(lam)) else 0)
    if H_op <= 0:
        count = 0  # nothing operated -> nothing happened (the roll is still consumed to keep the draw order fixed)
    present_roles = set(s.role for s in staff)
    all_traits = set(t for s in staff for t in s.traits)
    min_E = min([r["E"] for r in rows if not r.get("voided")] or [100])
    min_M = min([r["M"] for r in rows if not r.get("voided")] or [100])
    headroom = min(cap_seat, first_ctx["cap_k"], first_ctx["cap_s"]) / max(1e-9, first_ctx["Q"])
    stations = set(ex["stations"])
    special_menu = any(m.get("special") for m in menu)
    night = ex.get("covers_night", False)

    def eligible(inc):
        if inc["cat"] == "discovery":
            return False
        if inc.get("tier_min", 1) > tier or inc.get("rep_min", 0) > stars:
            return False
        if any(r not in present_roles for r in inc.get("req_roles", [])):
            return False
        if inc.get("req_any_trait") and not (set(inc["req_any_trait"]) & all_traits):
            return False
        if inc.get("req_archetype") and inc["req_archetype"] not in [s.id for s in staff]:
            return False
        if inc.get("req_personality") and inc["req_personality"] not in [s.pers for s in staff]:
            return False
        if inc.get("station") and inc["station"] not in stations:
            return False
        if "chaos" in inc.get("tags", []) and any(s.id == "EMP_069" for s in guards):
            return False
        c = inc.get("cond")
        if c == "headroom_ge_10" and headroom < 1.10: return False
        if c == "headroom_lt_10" and headroom >= 1.10: return False
        if c == "no_cleaner" and cleaners: return False
        if c == "cleaner_ok" and not cleaners: return False
        if c == "q_ge_085" and first_ctx["q"] < 0.85: return False
        if c == "q_lt_085" and first_ctx["q"] >= 0.85: return False
        if c == "low_energy" and min_E >= 40: return False
        if c == "low_morale" and min_M >= 50: return False
        if c == "low_chef_acc" and sum(x.stats["acc"] for x in chefs) / len(chefs) >= 50: return False
        if c == "staff_ge_4" and len(staff) < 4: return False
        if c == "special_menu" and not special_menu: return False
        if c == "night" and not night: return False
        if c == "chef_cook_ge_60" and best_cook < 60: return False
        if inc["id"] == "INC_032" and not any(m["cat"] in ("BRG", "SAN") for m in menu): return False
        return True

    def weight(inc):
        w = inc["weight"]
        neg = inc["sign"] == "-"
        for role in inc.get("mitig", []):
            if neg and role in by_role:
                best = max(first_ctx["contrib"][s.id] for s in by_role[role])
                w *= max(0.4, 1 - 0.6 * min(1, best))
        if inc.get("hero"):
            role = (inc.get("req_roles") or ["ROLE_CHEF"])[0]
            pool = by_role.get(role, chefs)
            w *= 0.5 + min(1, max(first_ctx["contrib"][s.id] for s in pool))
        for t, m in inc.get("trait_mult", {}).items():
            if t in all_traits:
                w *= m
        tags = inc.get("tags", [])
        if "fire" in tags and "Splash Zone" in all_traits: w *= 0.3
        if "breakage" in tags and "Sticky Grip" in all_traits and inc["id"] != "INC_022": w *= 0.3
        if "equipment" in tags and any("Electric" in r.traits for r in repairs): w *= 0.7
        if "celebrity" in tags and any(s.id == "EMP_077" for s in mgrs): w *= 2
        if inc.get("acc_scaled") and waiters:
            w *= 1.5 - sum(x.stats["acc"] for x in waiters) / len(waiters) / 100
        if neg and any(s.id == "EMP_076" for s in mgrs): w *= 0.8
        if inc["sign"] == "+" and (any(s.id == "EMP_096" for s in assts) or
                                   any("Cosmic Intuition" in s.traits for s in mgrs + assts)):
            w *= 1.15
        for p, m in inc.get("personality_mult", {}).items():
            w *= m ** sum(1 for s in staff if s.pers == p)
        return w

    pool = [(inc, weight(inc)) for inc in INCIDENTS if eligible(inc)]
    W = sum(w for _, w in pool)
    drawn = []
    op_steps = [r for r in rows if not r.get("voided")]
    for _ in range(count):
        x = rng.random() * W
        acc = 0
        for inc, w in pool:
            acc += w
            if x <= acc:
                break
        st_idx = rng.randrange(len(op_steps)) + 1
        n = rng.randint(inc["n"][0], inc["n"][1]) if isinstance(inc["n"], list) else 1
        drawn.append(dict(inc=inc, step=st_idx, n=n))
    # cancels (INC_052 cancels one equipment incident)
    if any(d["inc"]["id"] == "INC_052" for d in drawn):
        for d in drawn:
            if d["inc"]["cat"] == "equipment" and not d.get("cancelled"):
                d["cancelled"] = True
                break
    asst_mult = 0.8 if assts else 1.0
    shell_mult = 0.9 if any("Tough Shell" in g.traits for g in guards) else 1.0
    neg_mb = pos_mb = dmg = 0.0
    for d in drawn:
        inc = d["inc"]
        if d.get("cancelled"):
            d["mb"] = d["dmg"] = 0.0
            continue
        mb = inc.get("mb", 0) * Rh
        dm = inc.get("dmg", 0) * Rh
        if inc["id"] == "INC_031" and not special_menu:
            mb = -0.02 * Rh
        if inc["id"] == "INC_059" and not special_menu:
            mb = 0.02 * Rh
        if mb < 0 or dm > 0:
            mult = asst_mult * (shell_mult if inc["cat"] == "customer" else 1.0)
            mb = mb * mult if mb < 0 else mb
            dm *= mult
        d["mb"], d["dmg"] = mb, dm
        if mb < 0: neg_mb += -mb
        else: pos_mb += mb
        dmg += dm
    neg_total = neg_mb + dmg
    neg_scale = min(1.0, NEG_CAP * R_total / neg_total) if neg_total > 0 else 1.0
    pos_scale = min(1.0, POS_CAP * R_total / pos_mb) if pos_mb > 0 else 1.0
    for d in drawn:
        if d.get("mb", 0) < 0:
            d["mb"] *= neg_scale
        elif d.get("mb", 0) > 0:
            d["mb"] *= pos_scale
        d["dmg"] = d.get("dmg", 0) * neg_scale
    inc_mb = sum(d["mb"] for d in drawn)
    dmg_val = sum(d["dmg"] for d in drawn)
    rep_disc = 0.0
    auto_rep = 0.0
    deferred = 0.0
    if repairs:
        best = max(r.stats["rep"] for r in repairs)
        rep_disc = min(0.60, best / 200 + (0.10 if any("Wall Crawler" in r.traits for r in repairs) else 0))
        auto_rep = dmg_val * (1 - rep_disc)
    else:
        deferred = dmg_val
    dmg_points = int(math.ceil(dmg_val / COST_PER_DAMAGE_POINT[tier])) if dmg_val > 0 else 0

    # ---------------- discoveries
    disc_boost = 1.0
    if any("Sniffer" in s.traits for s in staff):
        disc_boost *= 1.10
    if any("Lucky Charm" in s.traits for s in staff):
        disc_boost *= 1.15
    disc_boost = min(DISCOVERY_BOOST_CAP, disc_boost)
    crate_boost = 1.5 if any(s.id == "EMP_091" for s in stockers) else 1.0
    ms = 0
    ms_events = []
    crates = []
    capsules = 0
    day_of_last = ex.get("last_capsule_day", -1)
    for r in op_steps:
        if rng.random() < MS_CHANCE * disc_boost * r["h"]:
            amt = rng.randint(1, 3)
            ms += amt
            ms_events.append((r["step"], amt))
        if rng.random() < CRATE_CHANCE * crate_boost * r["h"]:
            crates.append((r["step"], rng.randint(5, 15)))
        step_day = (ex["last_sim_at"] + int((r["step"] - 1) * 3600)) // 86400
        if rng.random() < CAPSULE_CHANCE * r["h"] and step_day > day_of_last:
            capsules += 1
            day_of_last = step_day

    base_net = tot["rev"] + tot["tips"] + tot["deliv"] - tot["ing"] - tot["wages"]
    net = base_net + inc_mb - auto_rep
    ceiling = OFFLINE_CEILING_SHARE * T["active_net"] * H_op
    clamped = net > ceiling
    net = max(0.0, min(net, ceiling)) if H_op > 0 else 0.0
    return dict(ex=ex, T=T, staff=staff, cap=cap, H=H, H_el=H_el, steps=steps, seed=seed, demand=demand,
                rep_mult=rep_mult, decor_mult=decor_mult, cap_seat=cap_seat, menu=menu, dmax=dmax,
                best_cook=best_cook, rows=rows, tot=tot, closed_at=closed_at, R_total=R_total, Rh=Rh, sm=sm,
                lam=lam, count=count, drawn=drawn, neg_scale=neg_scale, pos_scale=pos_scale, inc_mb=inc_mb,
                dmg_val=dmg_val, rep_disc=rep_disc, auto_rep=auto_rep, deferred=deferred, dmg_points=dmg_points,
                ms=ms, ms_events=ms_events, crates=crates, capsules=capsules, base_net=base_net, net=net,
                clamped=clamped, ceiling=ceiling, stock_used=stock_used, sold_out=sold_out,
                prep_count=prep_count, cashier_count=cashier_count, autobuy_log=autobuy_log, stock_end=stock, stock0=stock0, dish_factor=dish_factor,
                clean_factor=clean_factor, q_adj=q_adj, tip_trait=tip_trait, headroom=headroom,
                disc_boost=disc_boost, H_op=H_op, pool_size=len(pool))


# ---------------------------------------------------------------- the five worked examples
def M(rcp, d, special=None):
    return {"rcp": rcp, "d": d, "special": special}


EXAMPLES = [
    {
        "key": "A", "title": "TIER_01 — Ollie alone, back after 9 h (cap 2 h)",
        "tier": 1, "player_level": 4, "player_eff": 0, "stars": 3.8, "atmosphere": 45, "station_mult": 1.0,
        "station_note": "starter kit, all Lv1", "user_id": 81234567, "last_sim_at": 1760131800, "elapsed_h": 9.0,
        "stations": ["STN_CUT", "STN_GRILL", "STN_FRYER", "STN_DRINK", "STN_STOVE", "STN_OVEN"],
        "menu": [M("RCP_BRG_003", 2), M("RCP_SAN_002", 2), M("RCP_BRG_002", 1), M("RCP_DRK_002", 1)],
        "roster": [{"id": "EMP_001", "morale": 90, "energy": 100}],
    },
    {
        "key": "B", "title": "TIER_03 — basic staff + Basic Manager, 4 h",
        "tier": 3, "player_level": 12, "player_eff": 10, "stars": 3.9, "atmosphere": 50, "station_mult": 0.9,
        "station_note": "all Lv2 Tuned", "user_id": 81234567, "last_sim_at": 1760380200, "elapsed_h": 5 + 20 / 60,
        "stations": ["STN_CUT", "STN_GRILL", "STN_FRYER", "STN_DRINK", "STN_STOVE", "STN_OVEN", "STN_PIZZA_OVEN",
                     "STN_BLENDER", "STN_ICECREAM", "STN_SOUP_POT"],
        "menu": [M("RCP_SEA_003", 2), M("RCP_SAN_004", 2), M("RCP_PIZ_005", 2), M("RCP_SEA_002", 2),
                 M("RCP_BRK_004", 2), M("RCP_DRK_006", 2)],
        "roster": [{"id": "EMP_005", "morale": 82, "energy": 92},
                   {"id": "EMP_026", "morale": 80, "energy": 90},
                   {"id": "EMP_023", "morale": 85, "energy": 95},
                   {"id": "EMP_070", "morale": 80, "energy": 95}],
    },
    {
        "key": "C", "title": "TIER_05 — Experienced Manager, 8 h",
        "tier": 5, "player_level": 28, "player_eff": 25, "stars": 4.1, "atmosphere": 60, "station_mult": 0.85,
        "station_note": "mix of Lv2 and Lv3 (mean process multiplier 0.85)", "user_id": 81234567,
        "last_sim_at": 1761085800, "elapsed_h": 8.0,
        "stations": ["STN_CUT", "STN_GRILL", "STN_FRYER", "STN_DRINK", "STN_STOVE", "STN_OVEN", "STN_PIZZA_OVEN",
                     "STN_BLENDER", "STN_ICECREAM", "STN_SOUP_POT", "STN_MIXER", "STN_STEAMER", "STN_ANTIGRAV"],
        "menu": [M("RCP_BRG_013", 3), M("RCP_PIZ_014", 3), M("RCP_TAC_007", 3), M("RCP_SAN_008", 3),
                 M("RCP_PST_005", 3), M("RCP_SEA_006", 3), M("RCP_BRK_008", 3), M("RCP_DES_009", 2),
                 M("RCP_DRK_011", 2), M("RCP_SOP_006", 3)],
        "roster": [{"id": "EMP_073", "morale": 80, "energy": 95},
                   {"id": "EMP_008", "morale": 78, "energy": 90},
                   {"id": "EMP_005", "morale": 80, "energy": 90, "trained": {"cook": 58, "acc": 52}},
                   {"id": "EMP_023", "morale": 85, "energy": 92},
                   {"id": "EMP_028", "morale": 80, "energy": 88},
                   {"id": "EMP_026", "morale": 78, "energy": 90},
                   {"id": "EMP_039", "morale": 90, "energy": 100},
                   {"id": "EMP_048", "morale": 75, "energy": 90}],
    },
    {
        "key": "D", "title": "TIER_07 — Elite Manager, 12 h, special stock runs out",
        "tier": 7, "player_level": 48, "player_eff": 45, "stars": 4.3, "atmosphere": 70, "station_mult": 0.75,
        "station_note": "mostly Lv3–Lv4 (mean process multiplier 0.75)", "user_id": 81234567,
        "last_sim_at": 1762378200, "elapsed_h": 14.5, "covers_night": True,
        "stations": ["STN_CUT", "STN_GRILL", "STN_FRYER", "STN_DRINK", "STN_STOVE", "STN_OVEN", "STN_PIZZA_OVEN",
                     "STN_BLENDER", "STN_ICECREAM", "STN_SOUP_POT", "STN_MIXER", "STN_STEAMER", "STN_ANTIGRAV",
                     "STN_INFUSER"],
        "menu": [M("RCP_BRG_012", 4), M("RCP_PIZ_013", 4), M("RCP_TAC_010", 4), M("RCP_SAN_010", 3),
                 M("RCP_PST_009", 3), M("RCP_SEA_009", 3), M("RCP_BRK_010", 3), M("RCP_DES_014", 3),
                 M("RCP_DRK_013", 3, special="ING_MUTAGEN_GOO"), M("RCP_SOP_009", 3), M("RCP_FRI_005", 3),
                 M("RCP_MUT_001", 3, special="ING_MUTAGEN_GOO"), M("RCP_ALN_004", 3, special="ING_MOON_CHEESE"),
                 M("RCP_ALN_001", 2, special="ING_MOON_CHEESE")],
        "stock": {"ING_MOON_CHEESE": 70, "ING_MUTAGEN_GOO": 400},
        "roster": [{"id": "EMP_075", "morale": 80, "energy": 95},
                   {"id": "EMP_009", "morale": 75, "energy": 90},
                   {"id": "EMP_007", "morale": 80, "energy": 92},
                   {"id": "EMP_008", "morale": 80, "energy": 90},
                   {"id": "EMP_019", "morale": 80, "energy": 90},
                   {"id": "EMP_030", "morale": 85, "energy": 95},
                   {"id": "EMP_028", "morale": 80, "energy": 90},
                   {"id": "EMP_029", "morale": 80, "energy": 90},
                   {"id": "EMP_036", "morale": 80, "energy": 95},
                   {"id": "EMP_043", "morale": 80, "energy": 95},
                   {"id": "EMP_051", "morale": 80, "energy": 92},
                   {"id": "EMP_066", "morale": 85, "energy": 95}],
    },
    {
        "key": "E", "title": "TIER_10 — Legendary Manager, 24 h",
        "tier": 10, "player_level": 85, "player_eff": 80, "stars": 4.6, "atmosphere": 85, "station_mult": 0.65,
        "station_note": "mostly Lv4–Lv5 (mean process multiplier 0.65)", "user_id": 81234567,
        "last_sim_at": 1764970200, "elapsed_h": 31.0, "covers_night": True,
        "stations": ["STN_CUT", "STN_GRILL", "STN_FRYER", "STN_DRINK", "STN_STOVE", "STN_OVEN", "STN_PIZZA_OVEN",
                     "STN_BLENDER", "STN_ICECREAM", "STN_SOUP_POT", "STN_MIXER", "STN_STEAMER", "STN_ANTIGRAV",
                     "STN_INFUSER"],
        "menu": [M("RCP_LEG_001", 5, special="ING_GOLDEN_PATTY"), M("RCP_LEG_002", 5, special="ING_GOLDEN_PATTY"),
                 M("RCP_LEG_003", 5, special="ING_GOLDEN_PATTY"),
                 M("RCP_MUT_004", 4, special="ING_MUTAGEN_GOO"), M("RCP_MUT_005", 4, special="ING_MUTAGEN_GOO"),
                 M("RCP_ALN_010", 4, special="ING_STARDUST"), M("RCP_ALN_009", 4, special="ING_STARDUST"),
                 M("RCP_BRG_015", 4), M("RCP_PIZ_015", 4), M("RCP_SEA_010", 4), M("RCP_DES_015", 4),
                 M("RCP_SOP_010", 4), M("RCP_MUT_003", 4, special="ING_MUTAGEN_GOO"),
                 M("RCP_ALN_008", 4, special="ING_STARDUST"), M("RCP_PIZ_013", 4),
                 M("RCP_BRG_014", 4), M("RCP_ALN_007", 4, special="ING_STARDUST"), M("RCP_DRK_015", 4),
                 M("RCP_TAC_010", 4), M("RCP_MUT_002", 4, special="ING_MUTAGEN_GOO"), M("RCP_PST_010", 3),
                 M("RCP_DES_014", 3), M("RCP_SAN_010", 3), M("RCP_ALN_006", 3, special="ING_STARDUST")],
        "stock": {"ING_GOLDEN_PATTY": 700, "ING_MUTAGEN_GOO": 900, "ING_STARDUST": 900},
        "stocker_budget": 20000,
        "roster": [{"id": "EMP_076", "morale": 85, "energy": 95},
                   {"id": "EMP_097", "morale": 85, "energy": 95},
                   {"id": "EMP_011", "morale": 85, "energy": 95, "trained": {"cook": 100}},
                   {"id": "EMP_012", "morale": 85, "energy": 95},
                   {"id": "EMP_009", "morale": 80, "energy": 95},
                   {"id": "EMP_021", "morale": 80, "energy": 95},
                   {"id": "EMP_031", "morale": 85, "energy": 95},
                   {"id": "EMP_030", "morale": 85, "energy": 95},
                   {"id": "EMP_028", "morale": 80, "energy": 95},
                   {"id": "EMP_029", "morale": 80, "energy": 95},
                   {"id": "EMP_037", "morale": 80, "energy": 95},
                   {"id": "EMP_045", "morale": 80, "energy": 95},
                   {"id": "EMP_052", "morale": 80, "energy": 95},
                   {"id": "EMP_060", "morale": 80, "energy": 95},
                   {"id": "EMP_068", "morale": 80, "energy": 95},
                   {"id": "EMP_069", "morale": 85, "energy": 95},
                   {"id": "EMP_083", "morale": 80, "energy": 95},
                   {"id": "EMP_090", "morale": 80, "energy": 95}],
    },
    {
        "key": "F", "title": "what goes wrong — TIER_04, one weak chef carrying an expensive floor team (closes early)",
        "negative_example": True,
        "tier": 4, "player_level": 19, "player_eff": 10, "stars": 3.4, "atmosphere": 40, "station_mult": 0.9,
        "station_note": "all Lv2 Tuned", "user_id": 81234567, "last_sim_at": 1760650200, "elapsed_h": 6.0,
        "stations": ["STN_CUT", "STN_GRILL", "STN_FRYER", "STN_DRINK", "STN_STOVE", "STN_OVEN"],
        "menu": [M("RCP_BRG_013", 2), M("RCP_PST_004", 2), M("RCP_DRK_009", 2), M("RCP_SEA_004", 2),
                 M("RCP_PIZ_014", 2), M("RCP_BRK_006", 2), M("RCP_SAL_003", 2), M("RCP_TAC_006", 2)],
        "roster": [{"id": "EMP_071", "morale": 70, "energy": 80},
                   {"id": "EMP_003", "morale": 70, "energy": 80},
                   {"id": "EMP_028", "morale": 70, "energy": 80},
                   {"id": "EMP_066", "morale": 70, "energy": 80},
                   {"id": "EMP_026", "morale": 70, "energy": 80}],
    },
]


ROLE_SHORT = {"ROLE_CHEF": "Chef", "ROLE_PREP": "Prep", "ROLE_WAITER": "Waiter", "ROLE_CASHIER": "Cashier",
              "ROLE_DISH": "Dish", "ROLE_CLEANER": "Cleaner", "ROLE_REPAIR": "Repair", "ROLE_SECURITY": "Security",
              "ROLE_MANAGER": "Manager", "ROLE_DELIVERY": "Delivery", "ROLE_STOCKER": "Stocker",
              "ROLE_ASST_MGR": "Asst Mgr"}


def subject_name(r, inc):
    staff = r["staff"]
    subj = inc.get("subject", "any")
    c1 = r["rows"][0]["contrib"]
    if isinstance(subj, str) and subj.startswith("trait:"):
        pool = [s for s in staff if subj[6:] in s.traits]
    elif isinstance(subj, str) and subj.startswith("personality:"):
        pool = [s for s in staff if s.pers == subj[12:]]
    elif subj == "lowest_energy":
        pool = sorted(staff, key=lambda s: s.energy0)[:1]
    elif subj == "any":
        pool = [s for s in staff if s.role == "ROLE_CHEF"]
    else:
        pool = [s for s in staff if s.role == subj]
    if not pool:
        pool = [s for s in staff if s.role in ("ROLE_MANAGER", "ROLE_CHEF")]
    if not pool:
        return "the team"
    return max(pool, key=lambda s: c1[s.id]).short


def report_line(r, d):
    return d["inc"]["text"].replace("{employee}", subject_name(r, d["inc"])).replace("{n}", str(d["n"]))


def employee_lines(r):
    """Deterministic KPI lines for the Employee Report tab (section 17.11)."""
    out = []
    tot = r["tot"]
    plates = tot["N"] * ITEMS_PER_CUSTOMER
    c1 = r["rows"][0]["contrib"]
    chefs = [s for s in r["staff"] if s.role == "ROLE_CHEF"]
    sc = sum(c1[s.id] for s in chefs) or 1
    for s in r["staff"]:
        if s.role == "ROLE_CHEF":
            dishes = round(plates * c1[s.id] / sc)
            if "Multi-Tasker" in s.traits:
                out.append((s, "%s cooked %s dishes — %s of them simultaneously, with arms to spare." % (
                    s.short, fmt(dishes), fmt(round(dishes * (1 - 1 / (1.35 if s.kraken else 1.25)))))))
            elif "Grill Master" in s.traits:
                out.append((s, "%s grilled %s dishes and only set the mood (not the kitchen) on fire." % (s.short, fmt(dishes))))
            else:
                out.append((s, "%s cooked %s dishes without a single tantrum (from %s)." % (s.short, fmt(dishes), s.short)))
        elif s.role == "ROLE_WAITER":
            ws = [w for w in r["staff"] if w.role == "ROLE_WAITER"]
            n = round(tot["N"] * c1[s.id] / sum(c1[w.id] for w in ws))
            out.append((s, "%s served %s tables%s." % (s.short, fmt(n), " at roughly the speed of sound" if "Speedster" in s.traits else "")))
        elif s.role == "ROLE_DISH":
            if "Unhurried" in s.traits:
                out.append((s, "%s washed %s plates, very thoroughly. The other %s are \"soaking\"." % (
                    s.short, fmt(round(plates * 0.6)), fmt(round(plates * 0.4)))))
            else:
                out.append((s, "%s washed %s plates." % (s.short, fmt(round(plates)))))
        elif s.role == "ROLE_CLEANER":
            out.append((s, "%s cleaned up %s messes and found 1 sock (unclaimed)." % (s.short, fmt(round(tot["N"] * 0.12)))))
        elif s.role == "ROLE_MANAGER":
            out.append((s, "%s kept the doors open for %s and approved %d snack breaks." % (
                s.short, hm(r["H_op"]), max(1, round(r["H_op"] * 1.5)))))
        elif s.role == "ROLE_SECURITY":
            out.append((s, "%s stopped %d angry customers with one very stern eyebrow." % (s.short, max(1, round(tot["N"] * 0.012)))))
    return out


def hm(h):
    mins = int(round(h * 60))
    return "%d h %02d min" % (mins // 60, mins % 60)


def render_example(r, idx):
    ex, T = r["ex"], r["T"]
    L = []
    w = L.append
    n_active = T["active_net"]
    w("#### 17.9.%d Example %s — %s" % (idx, ex["key"], ex["title"]))
    w("")
    w("**Inputs**")
    w("")
    w("| Parameter | Value | Derivation |")
    w("|---|---|---|")
    w("| Tier | `%s` %s | seats %d, base demand %d/h, employee cap %d (§C6) |" % (T["id"], T["name"], T["seats"], T["base_demand"], T["employee_cap"]))
    w("| Player | level %d, EFFICIENCY %d | Efficiency × %.3f; ingredient cost × %.4f |" % (ex["player_level"], ex["player_eff"], 1 + 0.001 * ex["player_eff"], 1 - 0.0015 * ex["player_eff"]))
    w("| Reputation | %.1f ★ | RepMult = 0.5 + 0.25 × %.1f = %.3f |" % (ex["stars"], ex["stars"], r["rep_mult"]))
    w("| Atmosphere | %d | DecorMult = 0.9 + 0.003 × %d%s = %.3f |" % (ex["atmosphere"], ex["atmosphere"], " + Glow-Up" if r["decor_mult"] > 0.9 + 0.003 * ex["atmosphere"] + 1e-9 else "", r["decor_mult"]))
    w("| Stations | %s | PrepSec × (1 − 0.5 × (1 − %.2f)) = × %.3f |" % (ex["station_note"], ex["station_mult"], 1 - PROCESS_SHARE * (1 - ex["station_mult"])))
    mgr = [s for s in r["staff"] if s.role == "ROLE_MANAGER"]
    mtxt = ("%s (%s) → %d h" % (mgr[0].short, mgr[0].a["rarity"], CAP_HOURS[mgr[0].a["rarity"]])) if mgr else "no Manager → 2 h"
    if any(s.role == "ROLE_ASST_MGR" for s in r["staff"]) and mgr:
        mtxt += " (+2 h Assistant, absolute max 24 h)"
    w("| Offline cap | %d h | %s |" % (r["cap"], mtxt))
    w("| Elapsed / simulated | %s / **%s**%s | H = min(H_elapsed, cap) |" % (hm(r["H_el"]), hm(r["H"]), " (capped)" if r["H_el"] > r["cap"] else ""))
    w("| Seed | `0x%08X` | FNV-1a-32(\"%d:%d:%d\") |" % (r["seed"], ex["user_id"], ex["last_sim_at"], SIM_VERSION))
    if ex.get("stock"):
        w("| Special stock at logout | %s | consumed 1 unit per special dish |" % ", ".join("`%s` × %d" % kv for kv in ex["stock"].items()))
    w("")
    w("**Roster**")
    w("")
    w("| Employee | Archetype | Role | Rarity | Role stats | RoleStatAvg | Morale₀ / Energy₀ | Efficiency (step 1) | Trait mult | Contribution | Wage (MB/h) |")
    w("|---|---|---|---|---|---|---|---|---|---|---|")
    row1 = r["rows"][0]
    for s in r["staff"]:
        rs = ", ".join("%s %d%s" % ({"cook": "Cook", "svc": "Svc", "acc": "Acc", "rep": "Rep", "cmb": "Cmb", "rel": "Rel"}[k], s.stats[k],
                                     "*" if k in dict((x for x in [(kk, 1) for kk in next(sp for sp in ex["roster"] if sp["id"] == s.id).get("trained", {})])) else "")
                       for k in ROLE_W[s.role])
        tm = row1["contrib"][s.id] / (row1["eff"][s.id] / 100) if row1["eff"][s.id] else 1
        w("| %s | `%s` | %s | %s | %s | %.1f | %d / %d | %.1f | ×%.2f | %.3f | %s |" % (
            s.short, s.id, ROLE_SHORT[s.role], s.a["rarity"], rs, s.role_stat_avg(), s.morale0, s.energy0,
            row1["eff"][s.id], tm, row1["contrib"][s.id], fmt(s.wage)))
    w("")
    if any(sp.get("trained") for sp in ex["roster"]):
        w("\\* trained above the archetype value (within the potential cap, §16.6).")
        w("")
    compact = ex.get("negative_example")
    if not compact:
        w("**Menu** (skill gate: D ≤ 1 + floor(%d / 25) = %d)" % (r["best_cook"], r["dmax"]))
        w("")
    if not compact:
        w("| Recipe | ID | L | D | Price (MB) | Ingredients/item (MB) | PrepSec base → eff (s) | Offline? |")
        w("|---|---|---|---|---|---|---|---|")
    for m in ([] if compact else r["menu"]):
        w("| %s | `%s` | %d | %d | %s | %.2f | %d → %.1f | %s |" % (
            m["name"], m["rcp"], m["level"], m["d"], fmt(m["price"]), m["ing"], m["prep"], m["prep_eff"],
            ("yes" if m["cookable"] else "no (skill gate)") + (" · stock `%s`" % m["special"] if m.get("special") else "")))
    w("")
    w("**Interval constants**")
    w("")
    w("- Demand_off = %d × %.3f × %.3f × 0.6 = **%.1f customers/h**; Cap_seat = %d × 3600 / 300 = **%.0f/h**." % (
        T["base_demand"], r["rep_mult"], r["decor_mult"], r["demand"], T["seats"], r["cap_seat"]))
    w("- Step-1 PrepSec_avg = %.2f s; AvgTicket = 1.4 × mean price = %.2f MB; q = min(0.95, 0.70 + 0.25 × avgChefAcc/100 %+.2f) × CleanFactor %.2f = %.3f." % (
        row1["prep_avg"], row1["ticket"], r["q_adj"], r["clean_factor"], row1["q"]))
    w("- Preps counted %.2f (+%.0f %%), cashiers counted %d, DishFactor %.2f, Manager/Assistant coordination %+.1f %%, stocker discount %.1f %%, delivery share %.1f %%, tip trait multiplier ×%.2f." % (
        r["prep_count"], 100 * PREP_BONUS * r["prep_count"], r["cashier_count"], r["dish_factor"], 100 * row1["coord"], 100 * row1["sdisc"], 100 * row1["dpct"], r["tip_trait"]))
    w("")
    w("**Hourly steps**")
    w("")
    w("| Step | h | Avg Energy % | Σ chef contrib | Cap_kitchen | Cap_service | Q | Limit | N | Revenue | Tips | Delivery | Ingredients | Wages | Net_step |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for row in r["rows"]:
        w("| %d%s | %.2f | %.1f | %.3f | %.1f | %.1f | %.1f | %s | %d | %s | %s | %s | %s | %s | %s |" % (
            row["step"], " (voided)" if row.get("voided") else "", row["h"], row["E"], row["chef_contrib"], row["cap_k"], row["cap_s"],
            row["Q"], row["lim"], row["N"], fmt(row["rev"]), fmt(row["tips"]), fmt(row["deliv"]), fmt(row["ing"]),
            fmt(row["wages"]), fmt(row["net"])))
    tot = r["tot"]
    w("| **Σ** | %.2f | | | | | | | **%s** | **%s** | **%s** | **%s** | **%s** | **%s** | **%s** |" % (
        r["H_op"], fmt(tot["N"]), fmt(tot["rev"]), fmt(tot["tips"]), fmt(tot["deliv"]), fmt(tot["ing"]), fmt(tot["wages"]), fmt(r["base_net"])))
    w("")
    if r["closed_at"]:
        w("Step %d would have lost money (Net_step < 0), so the Manager **closed early**: that step is voided (no customers, no wages) and the simulation stops." % r["closed_at"])
        w("")
    if r["stock_used"]:
        by_step = {}
        for rc, stp in r["sold_out"]:
            by_step.setdefault(stp, []).append("`%s`" % rc)
        txt = "Special stock used: %s (left: %s)." % (
            ", ".join("`%s` %s" % (k, fmt(v)) for k, v in sorted(r["stock_used"].items())),
            ", ".join("%s" % fmt(v) for k, v in sorted(r["stock_end"].items())))
        if r["autobuy_log"]:
            txt += " Stocker auto-buy: %d top-ups in steps %d–%d costing %s MB (charged inside those steps' Ingredients) until the %s MB budget ran out." % (
                len(r["autobuy_log"]), r["autobuy_log"][0][0], r["autobuy_log"][-1][0],
                fmt(sum(a[3] for a in r["autobuy_log"])), fmt(ex.get("stocker_budget", 0)))
        if by_step:
            txt += " **SOLD OUT** from " + "; ".join("step %d: %s" % (k, ", ".join(v)) for k, v in sorted(by_step.items())) + \
                " — later steps recompute PrepSec_avg and AvgTicket without those dishes."
        w(txt)
        w("")
    if compact:
        w("Incidents: λ = %.2f → %d drawn (%s MB net, within caps); discoveries: %s." % (
            r["lam"], r["count"], fmt(r["inc_mb"]), "none" if not (r["ms_events"] or r["crates"] or r["capsules"]) else "see report"))
        w("")
    w("**Incidents & discoveries**" if not compact else "")
    w("")
    if not compact:
        w("- Security Mitigation SM = %.3f; λ = %.2f h × 0.6 × (1 − SM) = %.3f → count = floor(λ) + roll(%.3f) = **%d**; eligible pool %d incidents; Rh = %s MB/h." % (
            r["sm"], r["H_op"], r["lam"], r["lam"] - math.floor(r["lam"]), r["count"], r["pool_size"], fmt(r["Rh"])))
        neg = -sum(d["mb"] for d in r["drawn"] if d["mb"] < 0) + r["dmg_val"]
        pos = sum(d["mb"] for d in r["drawn"] if d["mb"] > 0)
        w("- Caps: negatives %s ≤ 10 %% of R (%s) → scale ×%.2f; positives %s ≤ 15 %% of R (%s) → scale ×%.2f." % (
            fmt(neg), fmt(0.10 * r["R_total"]), r["neg_scale"], fmt(pos), fmt(0.15 * r["R_total"]), r["pos_scale"]))
        if r["drawn"]:
            w("")
            w("| # | Step | Incident | MB effect | Damage value | Report line |")
            w("|---|---|---|---|---|---|")
            for j, d in enumerate(r["drawn"], 1):
                w("| %d | %d | `%s` %s%s | %s | %s | %s |" % (j, d["step"], d["inc"]["id"], d["inc"]["name"], " (cancelled by `INC_052`)" if d.get("cancelled") else "",
                                                    fmt(d["mb"]) if d["mb"] else "0", fmt(d["dmg"]) if d["dmg"] else "—", report_line(r, d)))
        w("")
        if r["dmg_val"] > 0:
            if r["auto_rep"] > 0:
                w("- Damage value %s MB (%d damage points at %s MB/pt) auto-repaired by the Repair Technician at −%.0f %% → **%s MB**." % (
                    fmt(r["dmg_val"]), r["dmg_points"], fmt(COST_PER_DAMAGE_POINT[ex["tier"]], 1), 100 * r["rep_disc"], fmt(r["auto_rep"])))
            else:
                w("- Damage value %s MB (%d damage points) is **left for the player** (no Repair Technician): shown in the Restaurant Damage tab, not deducted." % (
                    fmt(r["dmg_val"]), r["dmg_points"]))
        disc = []
        for stp, amt in r["ms_events"]:
            disc.append("step %d: +%d MS" % (stp, amt))
        for stp, units in r["crates"]:
            disc.append("step %d: rare crate (%d units)" % (stp, units))
        if r["capsules"]:
            disc.append("%d Morph Capsule" % r["capsules"])
        w("- Discoveries (MS chance %.1f %%/h after trait boost ×%.2f; crate 1 %%/h; capsule 5 %%/h, ≤ 1 per UTC day): %s." % (
            100 * MS_CHANCE * r["disc_boost"], r["disc_boost"], "; ".join(disc) if disc else "none this time"))
        w("")
    nph = r["net"] / r["H_op"] if r["H_op"] else 0
    bph = r["base_net"] / r["H_op"] if r["H_op"] else 0
    w("**Result**")
    w("")
    w("| Customers | Revenue | Tips | Delivery | Ingredients | Wages | Auto-repairs | Incidents | **Net** | Net / h | C4.4 active net / h | Offline ÷ active |")
    w("|---|---|---|---|---|---|---|---|---|---|---|---|")
    w("| %s | %s | %s | %s | −%s | −%s | −%s | %s | **%s** | %s | %s | **%.1f %%** (base economy %.1f %%) |" % (
        fmt(tot["N"]), fmt(tot["rev"]), fmt(tot["tips"]), fmt(tot["deliv"]), fmt(tot["ing"]), fmt(tot["wages"]),
        fmt(r["auto_rep"]).replace("−", ""), ("+" if r["inc_mb"] >= 0 else "") + fmt(r["inc_mb"]), fmt(r["net"]), fmt(nph), fmt(n_active),
        100 * nph / n_active, 100 * bph / n_active))
    w("")
    return "\n".join(L)


def render_all(results):
    L = []
    for i, r in enumerate(results, 1):
        L.append(render_example(r, i))
    L.append("#### 17.9.%d Summary of the worked examples" % (len(results) + 1))
    L.append("")
    L.append("| Example | Tier | Staff | Simulated | Customers | Net | Net / h | Active net / h (C4.4) | Offline ÷ active | Band 35–50 % |")
    L.append("|---|---|---|---|---|---|---|---|---|---|")
    for r in results:
        s = summary_line(r)
        L.append("| %s | `%s` | %d | %s | %s | %s | %s | %s | %.1f %% | %s |" % (
            s["key"], s["tier"], len(r["staff"]), hm(r["H_op"]), fmt(r["tot"]["N"]), fmt(r["net"]), fmt(s["nph"]), fmt(s["active"]),
            s["pct"], "✓" if 35 <= s["pct"] <= 50 else ("✗ (intentional)" if r["ex"].get("negative_example") else "✗")))
    L.append("")
    return "\n".join(L)


def summary_line(r):
    T = r["T"]
    nph = r["net"] / r["H_op"] if r["H_op"] else 0
    bph = r["base_net"] / r["H_op"] if r["H_op"] else 0
    return dict(key=r["ex"]["key"], tier=T["id"], H=r["H_op"], net=r["net"], nph=nph, bph=bph,
                active=T["active_net"], pct=100 * nph / T["active_net"], bpct=100 * bph / T["active_net"])


if __name__ == "__main__":
    results = [simulate(e) for e in EXAMPLES]
    if "--check" in sys.argv:
        ok = True
        for r in results:
            s = summary_line(r)
            band = (35 <= s["pct"] <= 50 and 35 <= s["bpct"] <= 50) or bool(r["ex"].get("negative_example"))
            ok &= band
            print("%s %s H=%.2f net=%s net/h=%s (base %s) active=%s -> %.1f%% (base %.1f%%) %s" % (
                s["key"], s["tier"], s["H"], fmt(s["net"]), fmt(s["nph"]), fmt(s["bph"]), fmt(s["active"]),
                s["pct"], s["bpct"], "OK" if band else "OUT OF BAND"))
        sys.exit(0 if ok else 1)
    print(render_all(results))

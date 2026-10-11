#!/usr/bin/env python3
"""economy_sim.py - Mystery Morph Restaurant economy model & simulations (GDD section 22).

Python 3 standard library only. Deterministic (no randomness): expected values everywhere.

Usage (from repo root):
    python3 gdd/tools/economy_sim.py --list          # list table names
    python3 gdd/tools/economy_sim.py --table calib   # print one markdown table
    python3 gdd/tools/economy_sim.py --all           # print every table
    python3 gdd/tools/economy_sim.py --check         # validate against canon C4.4 / C5.1 (exit 1 on failure)
    python3 gdd/tools/economy_sim.py --render gdd/sections/22_economy.md   # refresh <!-- sim:NAME --> blocks

All numbers marked [TUNABLE] in section 22 come from the constants below. Canon anchors (C4.x, C5.1, C6,
C14.3, C15) are reproduced verbatim and must not be edited here without a canon change.
"""
import math
import sys

# ----------------------------------------------------------------------------------------------
# CANON ANCHORS (do not edit without a canon change)
# ----------------------------------------------------------------------------------------------
TIERS = list(range(1, 11))
TIER_COST = {1: 0, 2: 1000, 3: 2000, 4: 5000, 5: 15000, 6: 40000, 7: 100000, 8: 225000, 9: 525000, 10: 1500000}
TIER_REQ_LVL = {1: 1, 2: 5, 3: 10, 4: 18, 5: 26, 6: 35, 7: 45, 8: 56, 9: 68, 10: 80}
TIER_SEATS = {1: 4, 2: 6, 3: 8, 4: 10, 5: 12, 6: 14, 7: 16, 8: 18, 9: 20, 10: 24}
TIER_DEMAND = {1: 50, 2: 65, 3: 80, 4: 95, 5: 110, 6: 125, 7: 140, 8: 155, 9: 170, 10: 190}
TIER_EMP_CAP = {1: 2, 2: 3, 3: 4, 4: 6, 5: 8, 6: 10, 7: 12, 8: 14, 9: 16, 10: 20}
TIER_MENU_SLOTS = {1: 4, 2: 5, 3: 6, 4: 8, 5: 10, 6: 12, 7: 14, 8: 16, 9: 20, 10: 24}
CANON_HOURS = {1: 0, 2: 1, 3: 3, 4: 7, 5: 14, 6: 25, 7: 40, 8: 60, 9: 85, 10: 120}
CANON_NET = {1: 630, 2: 1080, 3: 1730, 4: 3100, 5: 5400, 6: 9600, 7: 17400, 8: 32800, 9: 63700, 10: 120500}
TIER_NAME = {1: "Broken Burger Shack", 2: "Tiny Mutation Diner", 3: "Neighborhood Freak Café",
             4: "Morph City Grill", 5: "Mutant Family Restaurant", 6: "Monster Food Court",
             7: "Mutation Megadiner", 8: "Luxury Freak Restaurant", 9: "Morph City Food Palace",
             10: "Legendary Mutation Restaurant"}

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
MUT_PRICE_MID = {"Common": 275, "Uncommon": 1400, "Rare": 7000, "Epic": 42500, "Legendary": 275000}
MUT_PRICE_EXTRA_MS = {"Common": 0, "Uncommon": 0, "Rare": 20, "Epic": 80, "Legendary": 250}
MUT_PRICE_EXTRA_RT = {"Common": 0, "Uncommon": 0, "Rare": 0, "Epic": 0, "Legendary": 10}
MUT_EQUIP_LVL = {"Common": 1, "Uncommon": 5, "Rare": 12, "Epic": 25, "Legendary": 40, "Mythic": 60}
MUT_MAX_LVL = {"Common": 5, "Uncommon": 6, "Rare": 7, "Epic": 8, "Legendary": 9, "Mythic": 10}
MUT_BASE_MB = {"Common": 100, "Uncommon": 300, "Rare": 900, "Epic": 3000, "Legendary": 10000, "Mythic": 30000}
MUT_BASE_MS = {"Common": 2, "Uncommon": 4, "Rare": 8, "Epic": 15, "Legendary": 30, "Mythic": 50}
MUT_RT_BASE = {"Common": 0, "Uncommon": 0, "Rare": 0, "Epic": 1, "Legendary": 2, "Mythic": 4}
DUPE_TO_MS = {"Common": 5, "Uncommon": 12, "Rare": 30, "Epic": 80, "Legendary": 200, "Mythic": 500}
DUPE_SUB_MS = {"Common": 10, "Uncommon": 25, "Rare": 60, "Epic": 160, "Legendary": 400, "Mythic": 1000}
CAPSULE_ODDS = {"Common": 0.55, "Uncommon": 0.27, "Rare": 0.12, "Epic": 0.045, "Legendary": 0.013, "Mythic": 0.002}

EMP_HIRE_MID = {"Common": 400, "Uncommon": 2100, "Rare": 10500, "Epic": 55000, "Legendary": 315000}
EMP_WAGE_MID = {"Common": 18, "Uncommon": 50, "Rare": 140, "Epic": 420, "Legendary": 1100}
EMP_STAT_MID = {"Common": 28, "Uncommon": 42, "Rare": 57, "Epic": 72, "Legendary": 88}
OFFLINE_CAP_BY_MGR = {None: 2, "Common": 4, "Uncommon": 4, "Rare": 8, "Epic": 12, "Legendary": 24}

STATION_MULT = {2: 1.5, 3: 4, 4: 10, 5: 25}
STATION_TIME = {1: 1.00, 2: 0.90, 3: 0.80, 4: 0.70, 5: 0.60}
STATION_LVL_TIER = {2: 2, 3: 4, 4: 6, 5: 8}

# Canon C10 recipe unlock levels, in ID order per category.
RECIPE_LEVELS = {
    "BRG": [1, 1, 4, 9, 7, 5, 15, 12, 20, 25, 30, 40, 18, 50, 60],
    "PIZ": [3, 3, 6, 8, 11, 16, 28, 34, 22, 14, 10, 26, 45, 19, 55],
    "TAC": [5, 6, 9, 8, 13, 17, 24, 32, 38, 48],
    "SAN": [2, 4, 3, 10, 12, 14, 21, 23, 33, 42],
    "SOP": [4, 7, 13, 16, 20, 24, 27, 29, 37, 52],
    "PST": [2, 5, 6, 18, 23, 31, 35, 39, 44, 47],
    "BRK": [2, 3, 5, 11, 15, 19, 22, 26, 36, 41],
    "DES": [3, 4, 6, 7, 9, 10, 14, 17, 21, 25, 27, 30, 34, 46, 58],
    "DRK": [1, 2, 5, 6, 8, 11, 13, 16, 18, 20, 24, 29, 33, 38, 49],
    "SEA": [7, 10, 12, 19, 22, 25, 28, 31, 37, 54],
    "SAL": [3, 9, 15, 23, 32],
    "FRI": [1, 4, 8, 21, 43],
    "ALN": [30, 35, 38, 40, 43, 45, 50, 53, 57, 62],
    "MUT": [42, 48, 55, 63, 70],
    "LEG": [65, 72, 80, 88, 95],
}
CAT_FACTOR = {"DRK": 0.7, "FRI": 0.7, "SAL": 0.7, "DES": 0.8, "LEG": 2.5}


def base_price(level):
    """Canon C4.2 BasePrice(L) = 10 x 1.05^(L-1) (unrounded)."""
    return 10.0 * 1.05 ** (level - 1)


def recipe_price(level, difficulty, cat):
    """Canon C4.2 nominal price (no flavor variance), rounded to whole MB."""
    return round(base_price(level) * (0.8 + 0.1 * difficulty) * CAT_FACTOR.get(cat, 1.0))


def ingredient_ratio(difficulty):
    """[TUNABLE] C4.2 says 25-40 % of price, higher difficulty -> lower ratio. Linear: D1 40 % ... D5 25 %."""
    return 0.40 - 0.0375 * (difficulty - 1)


def level_at(hours):
    """Canon C5.1: time to level L = [180(L-1) + 15 L(L-1)] / 900 h at the reference XPRate. Inverted."""
    lv = (-165.0 + math.sqrt(27225.0 + 60.0 * (180.0 + 900.0 * hours))) / 30.0
    return min(100, int(math.floor(lv + 1e-9)))


def hours_to_level(level):
    return (180.0 * (level - 1) + 15.0 * level * (level - 1)) / 900.0


# ----------------------------------------------------------------------------------------------
# SECTION 22 MODEL PARAMETERS [TUNABLE] - state of a competent reference player at tier entry
# ----------------------------------------------------------------------------------------------
P = {
    "stars":      [2.6, 3.0, 3.3, 3.55, 3.75, 3.95, 4.1, 4.25, 4.4, 4.55],
    "atmosphere": [10, 20, 30, 40, 50, 58, 66, 74, 82, 90],
    "serve_rate": [0.92, 0.93, 0.94, 0.945, 0.95, 0.955, 0.96, 0.965, 0.97, 0.97],
    "icr_base":   [0.38, 0.37, 0.36, 0.35, 0.34, 0.33, 0.32, 0.31, 0.30, 0.30],
    "eff_stat":   [0, 3, 8, 15, 22, 30, 38, 46, 54, 60],
    "luck_stat":  [2, 5, 10, 16, 22, 30, 38, 46, 54, 60],
    "quest_share": [0.25, 0.22, 0.19, 0.17, 0.15, 0.15, 0.15, 0.15, 0.15, 0.15],
    "repair_rate": [0.030, 0.030, 0.028, 0.026, 0.024, 0.022, 0.020, 0.018, 0.016, 0.015],
    # satisfied order-modification pay bonus (section 6.18: +5-25 % per mod, cap +40 %/item; tips unaffected),
    # as a share of item payments
    "mod_bonus":  [0.010, 0.010, 0.010, 0.020, 0.025, 0.030, 0.035, 0.050, 0.050, 0.050],
}
VISIT_SEC_ACTIVE = 225          # [TUNABLE] active seat turnover -> seat cap = seats x 16 / h
MENU_MIX = 1.08                 # [TUNABLE] menu-weighted difficulty x category factor
MENU_LEVEL_RATIO = 0.825        # [TUNABLE] menu level Lm = 1 + 0.825 (L - 1)
PERSONALITY_TIP_MULT = 1.10     # [TUNABLE] order-weighted mean PersonalityTipMult
OFFLINE_RATIO = 0.42            # [TUNABLE] offline net/h as share of active net/h (canon 35-50 %)
ONBOARDING_GRANT = 400          # [TUNABLE] one-time MB budget across QST_TUT_001-012 (paid in first 0.25 h)
ONBOARDING_HOURS = 0.25

# Satisfaction distribution of served customers (shares sum to 1) by tier band.
# bands: 98-100, 90-97, 80-89, 70-79, 50-69, 30-49, <30 (calmed / apology)
SAT_BANDS = ["98-100", "90-97", "80-89", "70-79", "50-69", "30-49", "<30"]
SAT_TIP = [0.25, 0.18, 0.10, 0.05, 0.0, 0.0, 0.0]
SAT_PAY = [1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 0.4]
SAT_DIST = {
    "early": [0.03, 0.15, 0.25, 0.25, 0.22, 0.07, 0.03],
    "mid":   [0.05, 0.21, 0.28, 0.22, 0.17, 0.05, 0.02],
    "late":  [0.06, 0.24, 0.30, 0.20, 0.14, 0.05, 0.01],
}


def band_of(tier):
    return "early" if tier <= 3 else ("mid" if tier <= 6 else "late")


# Quest/event share split: quests, milestones+achievements, events, deliveries (fractions of QuestShare)
OTHER_SPLIT = {"early": (0.60, 0.27, 0.07, 0.06), "mid": (0.60, 0.13, 0.17, 0.10), "late": (0.58, 0.10, 0.20, 0.12)}

# Reference roster at tier entry: counts by rarity + best manager rarity (+ assistant manager flag)
ROSTER = {
    1: ({"Common": 1}, None, False),
    2: ({"Common": 2}, "Common", False),
    3: ({"Common": 3, "Uncommon": 1}, "Common", False),
    4: ({"Common": 3, "Uncommon": 2}, "Common", False),
    5: ({"Common": 2, "Uncommon": 4, "Rare": 1}, "Rare", False),
    6: ({"Common": 1, "Uncommon": 5, "Rare": 3}, "Rare", False),
    7: ({"Uncommon": 4, "Rare": 5, "Epic": 2}, "Epic", False),
    8: ({"Uncommon": 2, "Rare": 6, "Epic": 5}, "Epic", True),
    9: ({"Rare": 6, "Epic": 7, "Legendary": 2}, "Legendary", False),
    10: ({"Rare": 4, "Epic": 10, "Legendary": 5}, "Legendary", False),
}
OLLIE_WAGE = 12  # canon C14.4 EMP_001


def roster_wages(counts):
    w = 0
    for r, n in counts.items():
        w += n * EMP_WAGE_MID[r]
    if counts.get("Common", 0) >= 1:
        w -= EMP_WAGE_MID["Common"] - OLLIE_WAGE  # one of the Commons is Ollie (12 MB/h)
    return w


def roster_cap(tier):
    _, mgr, asst = ROSTER[tier]
    return min(24, OFFLINE_CAP_BY_MGR[mgr] + (2 if asst and mgr else 0))


# ----------------------------------------------------------------------------------------------
# INCOME MODEL
# ----------------------------------------------------------------------------------------------
def tier_param(name, tier, level):
    """Linear interpolation by level between the tier-entry state of `tier` and of `tier+1`."""
    vals = P[name]
    i = tier - 1
    if tier >= 10:
        return vals[9]
    l0, l1 = TIER_REQ_LVL[tier], TIER_REQ_LVL[tier + 1]
    f = max(0.0, min(1.0, (level - l0) / float(l1 - l0)))
    return vals[i] + (vals[i + 1] - vals[i]) * f


def sat_mix(tier, level):
    """Pay factor and tip rate (incl. Jackpot Tips) from the satisfaction distribution."""
    dist = SAT_DIST[band_of(tier)]
    pf = sum(s * p for s, p in zip(dist, SAT_PAY))
    tip = sum(s * t for s, t in zip(dist, SAT_TIP)) * PERSONALITY_TIP_MULT
    luck = tier_param("luck_stat", tier, level)
    delighted = dist[0] + dist[1]
    avg_del_tip = (dist[0] * 0.25 + dist[1] * 0.18) / max(1e-9, delighted) * PERSONALITY_TIP_MULT
    jackpot = delighted * (0.005 + 0.001 * luck) * 4.0 * avg_del_tip  # x5 tip = +4 extra tips
    return pf, tip + jackpot


def menu_price(level):
    lm = 1.0 + MENU_LEVEL_RATIO * (level - 1)
    return MENU_MIX * base_price(lm)


def income(tier, level, wages=None):
    """Return dict of per-active-hour flows for a competent player at (tier, level)."""
    stars = tier_param("stars", tier, level)
    atm = tier_param("atmosphere", tier, level)
    rep_mult = 0.5 + 0.25 * stars
    decor_mult = 0.9 + 0.003 * atm
    demand = TIER_DEMAND[tier] * rep_mult * decor_mult
    seat_cap = TIER_SEATS[tier] * 3600.0 / VISIT_SEC_ACTIVE
    n = min(demand, seat_cap) * tier_param("serve_rate", tier, level)
    ticket = 1.4 * menu_price(level)
    pf, tip = sat_mix(tier, level)
    icr = tier_param("icr_base", tier, level) * (1 - 0.0015 * tier_param("eff_stat", tier, level))
    mod_bonus = n * ticket * pf * tier_param("mod_bonus", tier, level)
    revenue = n * ticket * pf + mod_bonus
    tips = n * ticket * tip
    ingredients = n * ticket * icr
    if wages is None:
        wages = roster_wages(ROSTER[tier][0])
    service = revenue + tips - ingredients - wages
    qs = tier_param("quest_share", tier, level)
    other = service * qs
    return {"demand": demand, "seat_cap": seat_cap, "customers": n, "ticket": ticket, "pf": pf, "tip": tip,
            "icr": icr, "revenue": revenue, "tips": tips, "ingredients": ingredients, "wages": wages,
            "service": service, "other": other, "net": service + other, "stars": stars, "atm": atm,
            "rep_mult": rep_mult, "decor_mult": decor_mult, "quest_share": qs, "mod_bonus": mod_bonus,
            "repairs": tier_param("repair_rate", tier, level) * (revenue + tips)}


# ----------------------------------------------------------------------------------------------
# SESSION SIMULATION [TUNABLE policy]
# ----------------------------------------------------------------------------------------------
STEPS_PER_HOUR = 60
HOURS_PER_DAY = 1.5             # reference player: 1.5 active h/day = 10.5 h/week
STEPS_PER_DAY = int(STEPS_PER_HOUR * HOURS_PER_DAY)
TIER_FUND_SHARE = {1: 0.90, 2: 0.75, 3: 0.55, 4: 0.50, 5: 0.50, 6: 0.50, 7: 0.48, 8: 0.48, 9: 0.50, 10: 0.0}
# non-tier spend weights: mutations, staff, stations & equipment, furniture & decor, recipes & misc
SPEND_W = {"early": (0.30, 0.30, 0.12, 0.10, 0.18), "mid": (0.42, 0.24, 0.14, 0.13, 0.07),
           "late": (0.46, 0.26, 0.10, 0.12, 0.06)}
MUT_PURCHASE_SPLIT = 0.55       # share of mutation budget for new parts (rest: upgrades)
MUT_PRICE_HOURS = {"early": 1.0, "mid": 2.5, "late": 6.0}  # buy best rarity priced <= N h of net income
DUPE_FROM_CAPSULE = 0.30        # share of Rare+ upgrades paid with a kept duplicate instead of substitute MS
TRAINING_SHARE_CAP = 0.06       # staff budget overflow (roster complete) spent on training/promotions, <= 6 % of net
BUFFER_HOURS = 6.0              # cash a player keeps; held MB above this goes to MB cosmetics & prestige sinks
MISC_SHARE = 0.02               # Pigeon Taxi (25 MB x tier), respecs (500 MB x level), earnable palettes
EARLY_FIXED = (0.15, 0.10)      # early band: stations & furniture shares; rest goes to one priority goal
RECIPE_CAP_PER_SLOT = 2         # learned recipes <= 2 x menu slots + 4 (players learn what they can field)
CAPSULES_PER_DAY = 0.65         # login streak + weekly chest + events (milestone capsules are one-time)
DUPE_FRAC = {"early": 0.25, "mid": 0.45, "late": 0.70}
# MS / RT budgets (binding targets for section 20 / section 36.11 reward tables) by band
DAILY_MS = {"early": 6, "mid": 10, "late": 15}          # per daily quest, 3 dailies per day
EVENT_MS = {"early": 15, "mid": 30, "late": 45}         # per city event completion, ~1 per play day
WEEKLY_MS = {"early": 40, "mid": 70, "late": 110}       # per weekly quest, 5 per week
WEEKLY_RT = {"early": 0, "mid": 1, "late": 2}           # per weekly quest, 5 per week
STORY_RT = {1: 0, 2: 0, 3: 0, 4: 5, 5: 8, 6: 10, 7: 12, 8: 15, 9: 20, 10: 25}  # on finishing chapter N
EVENT_RT_WEEK = {"early": 1, "mid": 3, "late": 5}     # RT from city events per week (§18.8.4 cap: <= 10/week)
LEG_DISH_RT_PER_HOUR = 0.5      # RT per active hour from Legendary dish orders once RCP_LEG_001 is known (L65+)
STORY_PART = {1: "Uncommon", 2: "Uncommon", 3: "Rare", 4: "Rare", 5: "Epic", 6: "Epic", 7: "Epic",
              8: "Legendary", 9: "Legendary", 10: "Mythic"}
OFFLINE_MS_PER_H = 0.08 * 2     # canon C15 discoveries: 8 %/h chance of 1-3 MS (mean 2)
ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]


class Sim:
    def __init__(self, offline=False, end_hours=140.0):
        self.offline = offline
        self.end_steps = int(end_hours * STEPS_PER_HOUR)
        self.n = 0
        self.tier = 1
        self.level = 1
        self.tier_fund = 0.0
        self.bud = {"mut_buy": 0.0, "mut_upg": 0.0, "staff": 0.0, "recipes": 0.0}
        self.ms = 0.0
        self.rt = 0.0
        self.hired = {"Common": 1}           # Ollie (EMP_001) from QST_TUT_012
        # starter morph: 4 distinct STARTER Commons + tutorial Uncommon arm (QST_TUT_010)
        self.parts = [["Common", 1], ["Common", 1], ["Common", 1], ["Common", 1], ["Uncommon", 1]]
        self.learned = sum(1 for lv in RECIPE_LEVELS.values() for x in lv if x == 1)
        self.recipe_stack = []
        self.reach = {1: 0.0}
        self.money_ready = {}
        self.story_done = 0
        self.weeks = {}
        self.bought_in_tier = 0

    @property
    def t(self):
        return self.n / float(STEPS_PER_HOUR)

    @staticmethod
    def add(bucket, key, v):
        bucket[key] = bucket.get(key, 0.0) + v

    def wages(self):
        return roster_wages(self.hired)

    def target(self):
        return ROSTER[self.tier][0]

    def roster_size(self):
        return sum(self.hired.values())

    def needed_hire(self):
        tgt = self.target()
        for r in ORDER:
            if self.hired.get(r, 0) < tgt.get(r, 0):
                return r
        return None

    def release_surplus(self, below):
        tgt = self.target()
        for r in ORDER[:ORDER.index(below)]:
            if self.hired.get(r, 0) > tgt.get(r, 0):
                self.hired[r] -= 1
                return True
        return False

    # --- allocation -----------------------------------------------------------------------
    def early_priority(self):
        """Early band: discretionary MB goes to one goal at a time (hire -> first part -> recipes)."""
        if self.bought_in_tier < 1 and self.level >= 2:
            return "mut_buy"                     # first MB-bought mutation of each early tier comes first
        if self.tier >= 2 and self.hired.get("Common", 0) < 2:
            return "staff"                       # then the Common Manager (offline cap 2 h -> 4 h)
        if self.needed_hire() is not None:
            return "staff"
        if self.recipe_stack and self.learned < RECIPE_CAP_PER_SLOT * TIER_MENU_SLOTS[self.tier] + 4:
            return "recipes"
        return "mut_upg"

    def allocate(self, bucket, net, repairs):
        f = TIER_FUND_SHARE[self.tier]
        if self.tier < 10 and self.tier_fund >= TIER_COST[self.tier + 1]:
            f = 0.0  # fund complete: waiting only for the level gate, stop saving
        self.tier_fund += net * f
        self.add(bucket, "tier_save", net * f)
        pool = net * (1 - f) - repairs
        self.add(bucket, "repairs", repairs)
        self.add(bucket, "misc", pool * MISC_SHARE)          # taxi rides, respecs, earnable palettes
        pool *= (1 - MISC_SHARE)
        band = band_of(self.tier)
        wm, ws, wst, wf, wr = SPEND_W[band]
        if band == "early":
            self.add(bucket, "stations", pool * EARLY_FIXED[0])
            self.add(bucket, "furniture", pool * EARLY_FIXED[1])
            self.bud[self.early_priority()] += pool * (1 - EARLY_FIXED[0] - EARLY_FIXED[1])
            return
        self.bud["mut_buy"] += pool * wm * MUT_PURCHASE_SPLIT
        self.bud["mut_upg"] += pool * wm * (1 - MUT_PURCHASE_SPLIT)
        self.bud["staff"] += pool * ws
        self.add(bucket, "stations", pool * wst)
        self.add(bucket, "furniture", pool * wf)
        self.bud["recipes"] += pool * wr

    def step(self, bucket):
        b = band_of(self.tier)
        week = self.n // STEPS_PER_DAY // 7 + 1
        wk = self.weeks.setdefault(week, {})
        self.add(wk, "hours", 1.0 / STEPS_PER_HOUR)
        inc = income(self.tier, self.level, self.wages())
        dt = 1.0 / STEPS_PER_HOUR
        net = inc["net"] * dt
        for k in ("revenue", "tips", "ingredients", "wages", "other"):
            self.add(bucket, k, inc[k] * dt)
        if self.t < ONBOARDING_HOURS:
            g = ONBOARDING_GRANT * dt / ONBOARDING_HOURS
            net += g
            self.add(bucket, "other", g)
        self.add(bucket, "net", net)
        self.add(wk, "net", net)
        self.allocate(bucket, net, inc["repairs"] * dt)
        # MS / RT / capsules (calendar: one play day = HOURS_PER_DAY active hours)
        ms_h = (3 * DAILY_MS[b] + EVENT_MS[b]) / HOURS_PER_DAY
        cap_h = CAPSULES_PER_DAY / HOURS_PER_DAY
        dupe_h = cap_h * sum(CAPSULE_ODDS[r] * DUPE_TO_MS[r] for r in RARITIES) * DUPE_FRAC[b]
        self.ms += (ms_h + dupe_h) * dt
        self.add(wk, "ms_daily_events", ms_h * dt)
        self.add(wk, "ms_dupes", dupe_h * dt)
        for r in RARITIES:
            self.add(wk, "cap_" + r, cap_h * CAPSULE_ODDS[r] * (1 - DUPE_FRAC[b]) * dt)
        if self.level >= 65:
            self.rt += LEG_DISH_RT_PER_HOUR * dt
            self.add(wk, "rt_leg", LEG_DISH_RT_PER_HOUR * dt)
        self.spend(bucket, wk, inc)
        if (self.n + 1) % STEPS_PER_DAY == 0:
            day = (self.n + 1) // STEPS_PER_DAY
            if self.offline:
                self.offline_day(bucket, wk)
            if day % 7 == 0:
                self.ms += 5 * WEEKLY_MS[b]
                self.rt += 5 * WEEKLY_RT[b] + EVENT_RT_WEEK[b]
                self.add(wk, "ms_weekly", 5 * WEEKLY_MS[b])
                self.add(wk, "rt_weekly", 5 * WEEKLY_RT[b])
                self.add(wk, "rt_events", EVENT_RT_WEEK[b])
        self.n += 1

    def offline_day(self, bucket, wk):
        """Two offline windows per day (overnight + school/work), each capped by the roster manager."""
        hours = min(22.5, 2 * roster_cap(self.tier))
        inc = income(self.tier, self.level, self.wages())
        off = OFFLINE_RATIO * inc["net"] * hours
        self.add(bucket, "offline", off)
        self.add(bucket, "net", off)
        self.add(wk, "net", off)
        self.add(wk, "offline", off)
        self.allocate(bucket, off, 0.0)
        self.ms += OFFLINE_MS_PER_H * hours
        self.add(wk, "ms_offline", OFFLINE_MS_PER_H * hours)

    def try_buy_mutation(self, bucket, wk, hourly):
        best = None
        for r in ORDER:
            if MUT_EQUIP_LVL[r] <= self.level and MUT_PRICE_MID[r] <= MUT_PRICE_HOURS[band_of(self.tier)] * hourly:
                best = r
        if best is None:
            return
        cands = [best] + ([ORDER[ORDER.index(best) - 1]] if ORDER.index(best) > 0 else [])
        for r in cands:
            if self.ms >= MUT_PRICE_EXTRA_MS[r] and self.rt >= MUT_PRICE_EXTRA_RT[r]:
                if self.bud["mut_buy"] >= MUT_PRICE_MID[r]:
                    self.bud["mut_buy"] -= MUT_PRICE_MID[r]
                    self.ms -= MUT_PRICE_EXTRA_MS[r]
                    self.rt -= MUT_PRICE_EXTRA_RT[r]
                    self.add(wk, "ms_spent", MUT_PRICE_EXTRA_MS[r])
                    self.add(wk, "rt_spent", MUT_PRICE_EXTRA_RT[r])
                    self.parts.append([r, 1])
                    self.bought_in_tier += 1
                    self.add(bucket, "mutations", MUT_PRICE_MID[r])
                    self.add(wk, "buy_" + r, 1)
                return  # hold the budget for this rarity (MS/RT gate respected)

    def try_upgrade(self, bucket, wk):
        owned = sorted(set(RARITIES.index(p[0]) for p in self.parts), reverse=True)[:2]
        best = None
        for p in self.parts:
            ri = RARITIES.index(p[0])
            if ri not in owned or p[1] >= MUT_MAX_LVL[p[0]]:
                continue
            lv = p[1]
            mb = MUT_BASE_MB[p[0]] * 1.5 ** (lv - 1)
            ms = MUT_BASE_MS[p[0]] * lv
            if ri >= 2:
                ms += DUPE_SUB_MS[p[0]] * (1 - DUPE_FROM_CAPSULE)
            else:
                mb += MUT_PRICE_MID[p[0]]  # Common/Uncommon: buy a second copy as the duplicate
            rt = MUT_RT_BASE[p[0]] * (lv - 3) if (ri >= 3 and lv >= 4) else 0
            if best is None or mb < best[0]:
                best = (mb, ms, rt, p)
        if best is None:
            return False
        mb, ms, rt, p = best
        if self.bud["mut_upg"] >= mb and self.ms >= ms and self.rt >= rt:
            self.bud["mut_upg"] -= mb
            self.ms -= ms
            self.rt -= rt
            p[1] += 1
            self.add(bucket, "mutations", mb)
            self.add(wk, "upgrades", 1)
            self.add(wk, "ms_spent", ms)
            self.add(wk, "rt_spent", rt)
            return True
        return False

    def spend(self, bucket, wk, inc):
        net_h = max(1.0, inc["net"])
        # tier upgrade (needs MB in the tier fund AND the C6 level requirement)
        if self.tier < 10:
            nt = self.tier + 1
            if self.tier_fund >= TIER_COST[nt] and nt not in self.money_ready:
                self.money_ready[nt] = self.t
            if self.tier_fund >= TIER_COST[nt] and self.level >= TIER_REQ_LVL[nt]:
                self.tier_fund -= TIER_COST[nt]
                self.add(bucket, "tier_spend", TIER_COST[nt])
                self.tier = nt
                self.bought_in_tier = 0
                self.reach[nt] = self.t
                bucket.setdefault("notes", []).append("TIER_%02d" % nt)
                ch = nt - 1
                self.story_done = ch
                self.parts.append([STORY_PART[ch], 1])
                self.add(wk, "quest_" + STORY_PART[ch], 1)
                self.rt += STORY_RT[ch]
                self.add(wk, "rt_story", STORY_RT[ch])
                if nt == 10:  # no further tiers: release the fund to mutations & staff
                    self.bud["mut_buy"] += self.tier_fund * 0.6
                    self.bud["staff"] += self.tier_fund * 0.4
                    self.tier_fund = 0.0
        elif self.story_done < 10 and self.t >= self.reach[10] + 10:
            self.story_done = 10
            self.parts.append([STORY_PART[10], 1])
            self.add(wk, "quest_Mythic", 1)
            self.rt += STORY_RT[10]
            self.add(wk, "rt_story", STORY_RT[10])
        # level-ups -> recipes become learnable (Legendary recipes are quest-granted)
        new_level = level_at(self.t)
        while self.level < new_level:
            self.level += 1
            for c, lv in RECIPE_LEVELS.items():
                for x in lv:
                    if x == self.level and c != "LEG":
                        self.recipe_stack.append((c, x))
        cap = RECIPE_CAP_PER_SLOT * TIER_MENU_SLOTS[self.tier] + 4
        while self.recipe_stack and self.learned < cap:
            c, x = self.recipe_stack[-1]          # newest first
            cost = 5 * recipe_price(x, 3, c)
            if self.bud["recipes"] < cost:
                break
            self.bud["recipes"] -= cost
            self.add(bucket, "recipes", cost)
            self.learned += 1
            self.recipe_stack.pop()
        if (not self.recipe_stack or self.learned >= cap) and self.bud["recipes"] > 0:
            left = self.bud["recipes"]                        # nothing left to learn: back to mutations
            self.bud["mut_buy"] += left * MUT_PURCHASE_SPLIT
            self.bud["mut_upg"] += left * (1 - MUT_PURCHASE_SPLIT)
            self.bud["recipes"] = 0.0
        # staff: hire towards the reference roster, replacing surplus low-rarity staff at the cap
        r = self.needed_hire()
        while r is not None and self.bud["staff"] >= EMP_HIRE_MID[r]:
            if self.roster_size() >= TIER_EMP_CAP[self.tier] and not self.release_surplus(r):
                break
            self.bud["staff"] -= EMP_HIRE_MID[r]
            self.hired[r] = self.hired.get(r, 0) + 1
            self.add(bucket, "staff", EMP_HIRE_MID[r])
            self.add(bucket, "hires", 1)
            r = self.needed_hire()
        if r is None and self.bud["staff"] > 0:
            tr = min(self.bud["staff"], TRAINING_SHARE_CAP * net_h / STEPS_PER_HOUR)
            self.bud["staff"] -= tr
            self.add(bucket, "staff", tr)
        # mutations
        self.try_buy_mutation(bucket, wk, net_h)
        for _ in range(4):
            if not self.try_upgrade(bucket, wk):
                break
        # cash buffer: held MB above BUFFER_HOURS of income flows into MB cosmetics & prestige sinks
        held = sum(self.bud.values())
        buf = BUFFER_HOURS * net_h
        if held > buf:
            excess = held - buf
            for k in ("staff", "mut_upg", "recipes", "mut_buy"):
                take = min(self.bud[k], excess)
                self.bud[k] -= take
                excess -= take
                self.add(bucket, "cosmetics", take)
                if excess <= 0:
                    break

    def balance(self):
        return self.tier_fund + sum(self.bud.values())

    def snapshot(self, bucket):
        bucket["level"] = self.level
        bucket["tier"] = self.tier
        bucket["balance"] = self.balance()
        bucket["staff_n"] = self.roster_size()
        bucket["staff_tgt"] = sum(self.target().values())
        bucket["ms_bal"] = self.ms
        bucket["rt_bal"] = self.rt

    def run(self, keyfn):
        """keyfn(sim) -> hashable key or None. Returns ordered dict-like list of (key, bucket)."""
        out = {}
        order = []
        while self.n < self.end_steps:
            k = keyfn(self)
            bucket = out.get(k)
            if bucket is None:
                bucket = {}
                out[k] = bucket
                order.append(k)
            self.step(bucket)
            self.snapshot(bucket)
        return [(k, out[k]) for k in order if k is not None]


WINDOWS = [(0.0, 3.5, 0.25), (14.0, 41.0, 1.5), (85.0, 135.0, 2.5)]


def window_key(sim):
    t = sim.t
    for wi, (a, b, s) in enumerate(WINDOWS):
        if a - 1e-9 <= t < b - 1e-9:
            return (wi, int((t - a + 1e-9) // s))
    return None


def phase_key(sim):
    return sim.tier


# ----------------------------------------------------------------------------------------------
# TABLE RENDERERS
# ----------------------------------------------------------------------------------------------
def fm(x):
    return f"{x:,.0f}"


def pct(x, d=0):
    return f"{x * 100:.{d}f} %"


def md(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "|".join(["---"] * len(header)) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


_CACHE = {}


def cached(name, fn):
    if name not in _CACHE:
        _CACHE[name] = fn()
    return _CACHE[name]


def sim_sessions(offline=False):
    def go():
        s = Sim(offline=offline)
        return s, s.run(window_key)
    return cached(("sess", offline), go)


def sim_phases(offline=False):
    def go():
        s = Sim(offline=offline)
        return s, s.run(phase_key)
    return cached(("phase", offline), go)


def t_calib():
    rows = []
    for t in TIERS:
        L = TIER_REQ_LVL[t]
        m = income(t, L)
        d = m["net"] / CANON_NET[t] - 1
        rows.append([f"`TIER_{t:02d}`", L, f"{m['stars']:.2f} ★ / {m['atm']:.0f}", f"{m['customers']:.0f}",
                     f"{m['ticket']:.1f}", fm(m["revenue"]), fm(m["tips"]), fm(m["ingredients"]), fm(m["wages"]),
                     fm(m["other"]), fm(m["net"]), fm(CANON_NET[t]), f"{d * 100:+.1f} %"])
    return md(["Tier", "Entry L", "Stars / Atmos.", "Customers/h", "Avg ticket", "Payments", "Tips",
               "Ingredients", "Online wages", "Quests/events/other", "Model net/h", "Canon C4.4", "Δ"], rows)


def t_customer():
    rows = []
    for t in TIERS:
        L = TIER_REQ_LVL[t]
        m = income(t, L)
        dist = SAT_DIST[band_of(t)]
        per = m["ticket"] * (m["pf"] + m["tip"] - m["icr"])
        rows.append([f"`TIER_{t:02d}`", L, f"{menu_price(L):.1f}", f"{m['ticket']:.1f}",
                     " / ".join(f"{int(round(x * 100))}" for x in dist), f"{m['pf']:.3f}", pct(m["tip"], 1),
                     pct(m["icr"], 1), f"{per:.1f}"])
    return md(["Tier", "Entry L", "Menu-weighted item price", "Avg ticket (×1.4)",
               "Satisfaction mix % (98+/90/80/70/50/30/<30)", "Pay factor", "Tip rate (incl. Jackpot)",
               "Ingredient ratio", "Net per customer (MB)"], rows)


def t_recipes():
    ex = [("RCP_BRG_001", "BRG", 1, 1), ("RCP_DRK_001", "DRK", 1, 1), ("RCP_PIZ_002", "PIZ", 3, 2),
          ("RCP_PST_003", "PST", 6, 3), ("RCP_DES_006", "DES", 10, 3), ("RCP_TAC_006", "TAC", 17, 3),
          ("RCP_BRG_010", "BRG", 25, 3), ("RCP_SEA_008", "SEA", 31, 4), ("RCP_ALN_004", "ALN", 40, 4),
          ("RCP_PIZ_015", "PIZ", 55, 4), ("RCP_MUT_005", "MUT", 70, 5), ("RCP_LEG_003", "LEG", 80, 5),
          ("RCP_LEG_005", "LEG", 95, 5)]
    rows = []
    for rid, c, L, D in ex:
        pr = recipe_price(L, D, c)
        ic = round(pr * ingredient_ratio(D))
        tip = pr * 0.10
        learn = 0 if (L == 1 or c == "LEG") else 5 * pr
        rows.append([f"`{rid}`", L, D, c, fm(pr), fm(ic), pct((pr - ic) / pr), f"{pr - ic + tip:,.1f}",
                     ("start" if L == 1 else ("quest" if c == "LEG" else fm(learn))),
                     ("—" if not learn else f"{learn / (pr - ic + tip):.1f}")])
    return md(["Recipe", "Unlock L", "D (assumed)", "Cat.", "Price", "Ingredient cost", "Margin",
               "Profit + 10 % tip / item", "Learn cost (5 × price)", "Servings to repay learning"], rows)


def t_roster():
    rows = []
    cum = 0
    prev = {}
    for t in TIERS:
        counts, mgr, asst = ROSTER[t]
        add = 0
        for r, n in counts.items():
            extra = max(0, n - prev.get(r, 0))
            if r == "Common" and t == 1:
                extra -= 1  # Ollie is free
            add += max(0, extra) * EMP_HIRE_MID[r]
        cum += add
        prev = counts
        comp = ", ".join(f"{n} {r[0]}" for r, n in counts.items())
        rows.append([f"`TIER_{t:02d}`", f"{sum(counts.values())} / {TIER_EMP_CAP[t]}", comp,
                     (mgr or "none") + (" + Asst. Mgr" if asst else ""), f"{roster_cap(t)} h",
                     fm(roster_wages(counts)), fm(add), fm(cum)])
    return md(["Tier", "Staff / cap", "Mix (C/U/R/E/L)", "Best manager", "Offline cap (C14.3)",
               "Wages MB/h", "New hire spend", "Cumulative hire spend"], rows)


def emp_marginal(rarity, tier, prep_sec):
    stat = EMP_STAT_MID[rarity]
    eff = stat / 100.0 * (0.6 + 0.4 * 0.80) * (0.7 + 0.3 * 0.80)
    cust = 3600.0 / prep_sec * eff / 1.4
    m = income(tier, TIER_REQ_LVL[tier])
    per = m["ticket"] * (0.92 + 0.07 - m["icr"])
    return eff, cust, per, cust * per - EMP_WAGE_MID[rarity]


def t_emp_roi():
    cases = [("Common", 2, 40), ("Uncommon", 4, 50), ("Rare", 6, 60), ("Epic", 8, 75), ("Legendary", 10, 90)]
    rows = []
    for r, t, ps in cases:
        eff, cust, per, marg = emp_marginal(r, t, ps)
        hire = EMP_HIRE_MID[r]
        op_h = HOURS_PER_DAY + min(22.5, 2 * roster_cap(t))
        rows.append([r, f"`TIER_{t:02d}`", EMP_STAT_MID[r], f"{eff:.3f}", f"{ps} s", f"{cust:.1f}", f"{per:.1f}",
                     fm(EMP_WAGE_MID[r]), fm(marg), fm(hire), f"{hire / marg:.1f} h", f"{op_h:.1f} h",
                     f"{hire / (marg * op_h):.1f} d"])
    return md(["Chef rarity", "Typical tier", "Cooking stat", "Efficiency (C14.2; morale 80, energy 80)",
               "PrepSec_avg (assumed)", "Customers/h added", "Net per customer", "Wage/h",
               "Marginal net/h", "Hire cost", "Payback (operating h)", "Operating h/day (ref. player)",
               "Payback (days)"], rows)


STATION_CLASSES = [("Starter (e.g. `STN_GRILL`)", 150, 0.35, 1), ("Mid (e.g. `STN_MIXER`)", 400, 0.25, 2),
                   ("Late (e.g. `STN_INFUSER`)", 2000, 0.15, 6)]
BOTTLENECK = 0.5   # share of active time a busy station is the bottleneck (rush hours)
QUALITY_GAIN = 0.03  # Perfect-window / burn-grace uplift on its orders (tips, fewer re-cooks)
PAYBACK_TARGET_H = 10.0


def station_payback(B, share, lv, tier):
    m = income(tier, TIER_REQ_LVL[tier])
    g = STATION_TIME[lv - 1] / STATION_TIME[lv] - 1
    delta = m["service"] * share * (BOTTLENECK * g + QUALITY_GAIN)
    cost = B * STATION_MULT[lv]
    return g, delta, cost, cost / delta


def t_stations():
    rows = []
    for name, B, share, min_tier in STATION_CLASSES:
        for lv in (2, 3, 4, 5):
            t0 = max(min_tier, STATION_LVL_TIER[lv])
            g, d, cost, pb = station_payback(B, share, lv, t0)
            rec = "—"
            for t in range(t0, 11):
                if station_payback(B, share, lv, t)[3] <= PAYBACK_TARGET_H:
                    rec = f"`TIER_{t:02d}` ({station_payback(B, share, lv, t)[3]:.1f} h)"
                    break
            rows.append([name, fm(B), f"{int(share * 100)} %", f"Lv{lv - 1}→Lv{lv}", f"×{STATION_MULT[lv]}",
                         fm(cost), f"+{g * 100:.1f} %", f"`TIER_{t0:02d}`", fm(d), f"{pb:.1f} h", rec])
    return md(["Station class", "Base price B (illustrative)", "Order share", "Upgrade", "Cost mult. (C4.9)",
               "Cost (MB)", "Speed gain", "Earliest tier", "ΔNet/h there", "Payback there",
               "First tier with payback ≤ 10 h"], rows)


def t_decor():
    rows = []
    for t in TIERS:
        m = income(t, TIER_REQ_LVL[t])
        dm = m["decor_mult"]
        d10 = m["service"] * (0.03 / dm)
        cpp = 10.0 * m["service"] * 0.003 / dm
        rows.append([f"`TIER_{t:02d}`", f"{m['atm']:.0f}", f"×{dm:.3f}", fm(m["service"]),
                     fm(d10), fm(cpp), fm(cpp * 10)])
    return md(["Tier", "Typical atmosphere", "DecorMult (C11.4)", "Service net/h", "ΔNet/h per +10 atmosphere",
               "Target MB per atmosphere point (10 h payback)", "Cost of +10 points"], rows)


def t_expansion():
    rows = []
    for t in TIERS[1:]:
        L = TIER_REQ_LVL[t]
        before = income(t - 1, L)["net"]
        after = income(t, L)["net"]
        cost = TIER_COST[t]
        rows.append([f"`TIER_{t:02d}`", TIER_NAME[t], fm(cost), L, f"{TIER_SEATS[t - 1]}→{TIER_SEATS[t]}",
                     f"{TIER_DEMAND[t - 1]}→{TIER_DEMAND[t]}", f"{TIER_EMP_CAP[t - 1]}→{TIER_EMP_CAP[t]}",
                     f"{TIER_MENU_SLOTS[t - 1]}→{TIER_MENU_SLOTS[t]}", fm(before), fm(after),
                     f"{(after / before - 1) * 100:+.1f} %", f"{cost / (after - before):.1f} h",
                     f"{cost / CANON_NET[t - 1]:.1f} h"])
    return md(["Tier", "Name", "Cost (C6)", "Req. L", "Seats", "Base demand", "Staff cap", "Menu slots",
               "Net/h before (at req. L)", "Net/h after", "Step", "Payback of the seat/demand step",
               "Cost ÷ prev. canon net/h"], rows)


def t_offline():
    rows = []
    for t in TIERS:
        cap = roster_cap(t)
        on = CANON_NET[t]
        off = OFFLINE_RATIO * on
        hrs = min(22.5, 2 * cap)
        day = off * hrs
        act = on * HOURS_PER_DAY
        rows.append([f"`TIER_{t:02d}`", fm(on), f"{fm(0.35 * on)}–{fm(0.50 * on)}", fm(off), f"{cap} h",
                     fm(off * cap), f"{hrs:g} h", fm(day), fm(act), f"{day / (day + act) * 100:.0f} %"])
    return md(["Tier", "Active net/h (C4.4)", "Offline net/h band (35–50 %)", "Model offline net/h (42 %)",
               "Ref. cap", "Per capped window", "Offline h/day (2 check-ins)", "Offline MB/day",
               "Active MB/day (1.5 h)", "Offline share of daily MB"], rows)


def sim_table(wi, offline=False):
    s, rows = sim_sessions(offline)
    a, b, sl = WINDOWS[wi]
    out = []
    for (w, idx), r in rows:
        if w != wi:
            continue
        t0 = a + idx * sl
        notes = ", ".join("→ `%s`" % n for n in r.get("notes", []))
        out.append([idx + 1, f"{t0:.2f}–{t0 + sl:.2f}", r["level"], f"`TIER_{r['tier']:02d}`", fm(r.get("net", 0)),
                    fm(r.get("tier_spend", 0)), fm(r.get("mutations", 0)), fm(r.get("staff", 0)),
                    fm(r.get("stations", 0)), fm(r.get("furniture", 0)), fm(r.get("repairs", 0)),
                    fm(r.get("recipes", 0)), fm(r.get("misc", 0) + r.get("cosmetics", 0)), fm(r["balance"]),
                    f"{r['staff_n']}/{r['staff_tgt']}", notes or "—"])
    return md(["#", "Active h", "Lvl (end)", "Tier (end)", "Net income", "Tier upgrade", "Mutations",
               "Staff (hire/train)", "Stations & equip.", "Furniture & decor", "Repairs", "Recipes",
               "Cosmetics & misc", "Balance (end)", "Staff/ref.", "Events"], out)


def t_pacing():
    sA, _ = sim_sessions(False)
    sB, _ = sim_sessions(True)
    rows = []
    for t in TIERS[1:]:
        c = CANON_HOURS[t]
        lg = hours_to_level(TIER_REQ_LVL[t])
        mA, rA = sA.money_ready[t], sA.reach[t]
        mB, rB = sB.money_ready[t], sB.reach[t]
        bind = "level (C5.1)" if rA <= lg + 0.05 else "money"
        rows.append([f"`TIER_{t:02d}`", fm(TIER_COST[t]), c, f"{lg:.2f}", f"{mA:.2f}", f"{(mA / c - 1) * 100:+.0f} %",
                     f"{rA:.2f}", f"{(rA / c - 1) * 100:+.0f} %", bind, f"{mB:.2f}", f"{rB:.2f}",
                     f"{math.ceil(rB / HOURS_PER_DAY - 1e-9)}"])
    return md(["Tier", "Cost", "Canon h (C4.4)", "Level gate h (C5.1)", "A: money-ready h", "Δ money",
               "A: reached h", "Δ reach", "A: binding", "B: money-ready h", "B: reached h", "B: play day"], rows)


def t_phase_mix(offline=False):
    s, rows = sim_phases(offline)
    out = []
    for t, b in rows:
        net = b.get("net", 0)
        vals = [b.get("tier_save", 0), b.get("mutations", 0), b.get("staff", 0), b.get("stations", 0),
                b.get("furniture", 0), b.get("repairs", 0), b.get("recipes", 0) + b.get("misc", 0),
                b.get("cosmetics", 0)]
        held = net - sum(vals)
        hours = sum(1 for _ in [0])  # placeholder to keep structure simple
        out.append([f"`TIER_{t:02d}`", fm(net), fm(b.get("offline", 0))] + [pct(v / net) for v in vals] +
                   [pct(held / net)])
    return md(["Tier phase", "Net income in phase", "of which offline", "Tier fund", "Mutations", "Staff",
               "Stations & equip.", "Furniture & decor", "Repairs", "Recipes & misc", "Cosmetics & prestige",
               "Held (Δ balance)"], out)


def t_flows():
    rows = []
    for t in TIERS:
        L = TIER_REQ_LVL[t]
        m = income(t, L)
        q, ma, ev, dl = OTHER_SPLIT[band_of(t)]
        o = m["other"]
        margin = (m["service"] - m["repairs"]) / (m["revenue"] + m["tips"])
        rows.append([f"`TIER_{t:02d}`", fm(m["revenue"]), fm(m["tips"]), fm(o * q), fm(o * ma), fm(o * ev),
                     fm(o * dl), fm(m["ingredients"]), fm(m["wages"]), fm(m["net"]), fm(m["repairs"]), pct(margin)])
    return md(["Tier (at entry)", "Customer payments", "Tips", "Quests", "Milestones & achievements", "Events",
               "Deliveries", "− Ingredients", "− Online wages", "= Net/h (C4.4 basis)", "Repairs (from net)",
               "Operating margin"], rows)


def t_mut_weekly():
    s, _ = sim_sessions(False)
    rows = []
    cum = {r: 0.0 for r in RARITIES}
    for w in sorted(s.weeks):
        wk = s.weeks[w]
        if wk.get("hours", 0) < 1.0:
            continue
        cells = []
        bought = 0
        for r in RARITIES:
            b = wk.get("buy_" + r, 0)
            bought += b
            v = b + wk.get("cap_" + r, 0) + wk.get("quest_" + r, 0)
            cum[r] += v
            cells.append(f"{v:.1f}")
        rows.append([w, f"{(w - 1) * 7 * HOURS_PER_DAY:.1f}–{(w - 1) * 7 * HOURS_PER_DAY + wk['hours']:.1f}"] + cells
                    + [fm(bought), fm(wk.get("upgrades", 0)), f"{sum(cum.values()):.0f}"])
    return md(["Week", "Active h", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic",
               "Bought with MB", "Upgrades done", "Cumulative new parts"], rows)


def t_ms_rt():
    s, _ = sim_sessions(False)
    rows = []
    msb = 0.0
    rtb = 0.0
    for w in sorted(s.weeks):
        wk = s.weeks[w]
        if wk.get("hours", 0) < 1.0:
            continue
        msin = wk.get("ms_daily_events", 0) + wk.get("ms_dupes", 0) + wk.get("ms_weekly", 0)
        rtin = wk.get("rt_weekly", 0) + wk.get("rt_events", 0) + wk.get("rt_story", 0) + wk.get("rt_leg", 0)
        msb += msin - wk.get("ms_spent", 0)
        rtb += rtin - wk.get("rt_spent", 0)
        rows.append([w, fm(wk.get("ms_daily_events", 0)), fm(wk.get("ms_weekly", 0)), fm(wk.get("ms_dupes", 0)),
                     fm(msin), fm(wk.get("ms_spent", 0)), fm(msb), fm(wk.get("rt_weekly", 0)),
                     fm(wk.get("rt_events", 0)), fm(wk.get("rt_story", 0)), fm(wk.get("rt_leg", 0)), fm(rtin),
                     fm(wk.get("rt_spent", 0)), fm(rtb)])
    return md(["Week", "MS dailies+events", "MS weeklies", "MS dupes", "MS in", "MS spent", "MS balance",
               "RT weeklies", "RT events", "RT story", "RT Legendary dishes", "RT in", "RT spent", "RT balance"], rows)


def guest_tier(level):
    return max(t for t in TIERS if TIER_REQ_LVL[t] <= level)


def t_coop():
    rows = []
    cases = [(2, 5, 5), (5, 26, 26), (5, 26, 10), (8, 56, 56), (10, 80, 30), (3, 10, 80)]
    for ot, ol, gl in cases:
        val = menu_price(ol) * 1.4
        lm = 1.0 + MENU_LEVEL_RATIO * (ol - 1)
        scale = 1.05 ** (-max(0.0, lm - gl))
        per = 0.5 * val * scale
        orders_h = income(ot, ol)["customers"] * 0.30
        gross_h = per * orders_h
        gt = guest_tier(gl)
        cap = 1.5 * CANON_NET[gt]
        rows.append([f"`TIER_{ot:02d}`", ol, gl, f"`TIER_{gt:02d}`", f"{val:.1f}", f"{scale:.2f}", f"{per:.1f}",
                     f"{orders_h:.0f}", fm(gross_h), fm(cap), f"{gross_h / CANON_NET[gt] * 100:.1f} %",
                     (f"{cap / gross_h:.1f} h" if cap / gross_h <= 24 else "never (> 24 h)")])
    return md(["Owner tier", "Owner L", "Guest L", "Guest's own tier", "Avg order base value", "Level scale",
               "Guest MB / order (50 %)", "Orders/h credited (30 %)", "Guest MB/h", "Daily guest MB cap",
               "Guest MB/h ÷ own-tier net/h", "Hours to reach cap"], rows)


def t_mut_costs():
    rows = []
    for r in RARITIES + ["Secret"]:
        if r == "Secret":
            base_mb, base_ms, rtb, mx, sub = 15000, 40, 3, 10, 600
        else:
            base_mb, base_ms, rtb, mx, sub = MUT_BASE_MB[r], MUT_BASE_MS[r], MUT_RT_BASE[r], MUT_MAX_LVL[r], DUPE_SUB_MS[r]
        epic_plus = r in ("Epic", "Legendary", "Mythic", "Secret")
        mb = sum(base_mb * 1.5 ** (L - 1) for L in range(1, mx))
        ms = sum(base_ms * L for L in range(1, mx))
        rt = sum(rtb * (L - 3) for L in range(4, mx)) if epic_plus else 0
        buy = {"Common": "150–400", "Uncommon": "800–2,000", "Rare": "4,000–10,000 + 20 MS",
               "Epic": "25,000–60,000 + 80 MS", "Legendary": "150,000–400,000 + 250 MS + 10 RT",
               "Mythic": "fusion: 3 Legendary + 600 MS + 40 RT", "Secret": "discovery only"}[r]
        hours_ref = {"Common": 1, "Uncommon": 5, "Rare": 12, "Epic": 25, "Legendary": 40, "Mythic": 60, "Secret": 40}[r]
        t_eq = max(t for t in TIERS if TIER_REQ_LVL[t] <= max(hours_ref, 1))
        rows.append([r, buy, mx, fm(mb), fm(ms), mx - 1, fm((mx - 1) * sub) if r != "Secret" else fm((mx - 1) * 600),
                     fm(rt), f"{mb / CANON_NET[t_eq]:.1f} h @ `TIER_{t_eq:02d}`"])
    return md(["Rarity", "Acquisition price (C4.5)", "Max Lv", "MB to max (C4.6)", "MS to max (base)",
               "Duplicates needed", "…or substitute MS", "RT to max", "MB to max ÷ net/h at equip tier"], rows)


TABLES = {
    "calib": t_calib, "customer": t_customer, "recipes": t_recipes, "roster": t_roster, "emp_roi": t_emp_roi,
    "stations": t_stations, "decor": t_decor, "expansion": t_expansion, "offline": t_offline,
    "sim_early": lambda: sim_table(0), "sim_mid": lambda: sim_table(1), "sim_late": lambda: sim_table(2),
    "pacing": t_pacing, "phase_mix": lambda: t_phase_mix(False), "phase_mix_offline": lambda: t_phase_mix(True),
    "flows": t_flows, "mut_weekly": t_mut_weekly, "ms_rt": t_ms_rt, "coop": t_coop, "mut_costs": t_mut_costs,
}


def check():
    ok = True
    print("Calibration vs canon C4.4 (tolerance ±5 %):")
    for t in TIERS:
        m = income(t, TIER_REQ_LVL[t])["net"]
        d = m / CANON_NET[t] - 1
        flag = abs(d) <= 0.05
        ok &= flag
        print(f"  TIER_{t:02d} model {m:,.0f} canon {CANON_NET[t]:,} Δ {d * 100:+.1f} % {'PASS' if flag else 'FAIL'}")
    sA, _ = sim_sessions(False)
    print("Scenario A pacing vs canon C4.4 (±20 %; a level-gated tier must equal its C5.1 gate):")
    for t in TIERS[1:]:
        c = CANON_HOURS[t]
        mr, r = sA.money_ready[t], sA.reach[t]
        lg = hours_to_level(TIER_REQ_LVL[t])
        dm, dr = mr / c - 1, r / c - 1
        gated = abs(r - lg) <= 0.05
        good = abs(dm) <= 0.20 and (abs(dr) <= 0.20 or gated)
        ok &= good
        note = " (level-gated: C5.1 L%d = %.2f h)" % (TIER_REQ_LVL[t], lg) if gated else ""
        print(f"  TIER_{t:02d} money {mr:6.2f} h ({dm * 100:+.0f} %) reach {r:6.2f} h ({dr * 100:+.0f} %)"
              f" canon {c} h {'PASS' if good else 'FAIL'}{note}")
    sB, _ = sim_sessions(True)
    print("Scenario B (with offline): reach must never precede the C5.1 level gate:")
    for t in TIERS[1:]:
        lg = hours_to_level(TIER_REQ_LVL[t])
        r = sB.reach[t]
        flag = r >= lg - 1e-6
        ok &= flag
        print(f"  TIER_{t:02d} reach {r:6.2f} h gate {lg:6.2f} h {'PASS' if flag else 'FAIL'}")
    print("RESULT:", "PASS" if ok else "FAIL")
    return ok


def render(path):
    """Replace every <!-- sim:NAME --> ... <!-- /sim:NAME --> block in `path` with fresh output (idempotent)."""
    import re
    text = open(path, encoding="utf-8").read()
    pat = re.compile(r"(<!-- sim:([a-z_]+) -->)\n(?:.*?\n)??(<!-- /sim:\2 -->)", re.S)
    n = [0]

    def sub(m):
        n[0] += 1
        return m.group(1) + "\n" + TABLES[m.group(2)]() + "\n" + m.group(3)
    text = pat.sub(sub, text)
    open(path, "w", encoding="utf-8").write(text)
    print(f"rendered {n[0]} table(s) into {path}")


def main(argv):
    if "--render" in argv:
        render(argv[argv.index("--render") + 1])
        return 0
    if "--list" in argv:
        print("\n".join(TABLES))
        return 0
    if "--check" in argv:
        return 0 if check() else 1
    if "--table" in argv:
        print(TABLES[argv[argv.index("--table") + 1]]())
        return 0
    for k, fn in TABLES.items():
        print(f"\n<!-- table: {k} -->\n")
        print(fn())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

#!/usr/bin/env python3
"""Mystery Morph Restaurant -- recipe & ingredient database renderer (owner: A3 Recipes).

Run from the repo root:   python3 gdd/tools/render_recipes.py [--report] [--check]

Reads   gdd/canon.md                         (binding: recipe master list C10, tags/core IDs C9,
                                              stations C7/C7.1, actions/states C8, price curve C4.2,
                                              personalities C11.1, abilities C12.2, parts C13.6, ANM C21)
        gdd/data/ingredients*.json           (ingredient rows)
        gdd/data/recipes.json                (recipe meta: category order, schema notes)
        gdd/data/recipes_part*.json          (recipe rows)
Writes  gdd/sections/06_recipe_database.md
        gdd/sections/07_ingredient_database.md
        gdd/sections/36_02_recipe_quick_reference.md

Python 3 standard library only. Idempotent: identical inputs give byte-identical outputs.
Exit code 1 on any validation error (nothing is written in that case).
"""
import glob
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GDD = os.path.dirname(HERE)
CANON = os.path.join(GDD, "canon.md")
DATA = os.path.join(GDD, "data")
OUT = os.path.join(GDD, "sections")

ERRORS = []
WARNINGS = []


def err(msg):
    ERRORS.append(msg)


def warn(msg):
    WARNINGS.append(msg)


# --------------------------------------------------------------------------------------------
# Fixed rule tables (canon C4.2 / C7 / C8) -- the canon file itself is parsed for ID lists.
# --------------------------------------------------------------------------------------------
CAT_ORDER = ["BRG", "PIZ", "TAC", "SAN", "SOP", "PST", "BRK", "DES", "DRK", "SEA", "SAL", "FRI",
             "ALN", "MUT", "LEG"]
CAT_NAME = {"BRG": "Burgers", "PIZ": "Pizza", "TAC": "Tacos & Mexican-Inspired", "SAN": "Sandwiches",
            "SOP": "Soups", "PST": "Pasta", "BRK": "Breakfast", "DES": "Desserts",
            "DRK": "Drinks & Smoothies", "SEA": "Seafood", "SAL": "Salads", "FRI": "Fried Foods",
            "ALN": "Alien Cuisine", "MUT": "Mutation Cuisine", "LEG": "Legendary Dishes"}
CAT_COUNT = {"BRG": 15, "PIZ": 15, "TAC": 10, "SAN": 10, "SOP": 10, "PST": 10, "BRK": 10, "DES": 15,
             "DRK": 15, "SEA": 10, "SAL": 5, "FRI": 5, "ALN": 10, "MUT": 5, "LEG": 5}
CAT_FACTOR = {"DRK": 0.7, "FRI": 0.7, "SAL": 0.7, "DES": 0.8, "LEG": 2.5}

ACTIONS = ["CHOP", "GRILL", "FRY", "BAKE", "SAUTE", "BOIL", "STEAM", "FREEZE", "MIX", "BLEND", "POUR",
           "SCOOP", "ASSEMBLE", "PLATE", "SERVE", "CLEAN", "WASH", "INFUSE", "FLOAT"]
ACTION_STATE = {"CHOP": "CHOPPED", "GRILL": "GRILLED", "FRY": "FRIED", "BAKE": "BAKED",
                "SAUTE": "SAUTEED", "BOIL": "BOILED", "STEAM": "STEAMED", "FREEZE": "FROZEN",
                "MIX": "MIXED", "BLEND": "BLENDED", "POUR": "POURED", "SCOOP": "SCOOPED",
                "INFUSE": "INFUSED", "FLOAT": "FLOATED"}
STATE_ACTION = {v: k for k, v in ACTION_STATE.items()}
HEAT = ["GRILL", "FRY", "BAKE", "SAUTE", "BOIL", "STEAM", "FLOAT", "INFUSE"]
FIRE_RISK = ["GRILL", "FRY", "BAKE", "SAUTE", "FLOAT"]
ACTION_STATIONS = {
    "CHOP": ["STN_CUT"], "GRILL": ["STN_GRILL"], "FRY": ["STN_FRYER"],
    "BAKE": ["STN_OVEN", "STN_PIZZA_OVEN"], "SAUTE": ["STN_STOVE"],
    "BOIL": ["STN_STOVE", "STN_SOUP_POT"], "STEAM": ["STN_STEAMER"], "FREEZE": ["STN_FREEZER"],
    "MIX": ["STN_MIXER", "STN_PREP"], "BLEND": ["STN_BLENDER"], "POUR": ["STN_DRINK"],
    "SCOOP": ["STN_ICECREAM"], "ASSEMBLE": ["STN_ASSEMBLY"],
    "PLATE": ["STN_PLATING", "STN_ASSEMBLY"], "SERVE": ["STN_WINDOW"],
    "INFUSE": ["STN_INFUSER"], "FLOAT": ["STN_ANTIGRAV"],
}
ACTION_ANM = {"CHOP": "ANM_010", "GRILL": "ANM_011", "FRY": "ANM_012", "BAKE": "ANM_013",
              "SAUTE": "ANM_024", "BOIL": "ANM_014", "STEAM": "ANM_027", "MIX": "ANM_016",
              "BLEND": "ANM_015", "POUR": "ANM_020", "SCOOP": "ANM_025", "ASSEMBLE": "ANM_017",
              "PLATE": "ANM_018", "SERVE": "ANM_019", "INFUSE": "ANM_028", "FLOAT": "ANM_029",
              "FREEZE": "ANM_006"}
STORAGE = ["STN_PANTRY", "STN_FRIDGE", "STN_FREEZER"]
SPECIAL_TAGS = {"alien", "mutagen", "legendary", "gold", "glowing"}
W_PERFECT = 2.0      # canon C8 default
BURN_AFTER = 6.0     # T_burn = T_ready + 6 s
FIRE_AFTER = 4.0     # ON_FIRE at T_burn + 4 s
LOVE_PTS = 8
HATE_PTS = -8
PERFECT_PLATE = 5
# Difficulty model (6.1.5): numbered steps (excluding the auto SERVE), prep band (s), cost-ratio target.
DIFF = {
    1: {"steps": (2, 4), "prep": (15, 30), "ratio": (0.33, 0.40)},
    2: {"steps": (3, 5), "prep": (20, 45), "ratio": (0.31, 0.38)},
    3: {"steps": (4, 7), "prep": (35, 80), "ratio": (0.29, 0.35)},
    4: {"steps": (5, 9), "prep": (55, 125), "ratio": (0.27, 0.33)},
    5: {"steps": (6, 12), "prep": (80, 150), "ratio": (0.25, 0.30)},
}
LEG_PREP = (150, 240)
GROUP_NAME = {"BRD": "Breads, Doughs & Shells", "MEA": "Meat & Poultry", "SEA": "Seafood",
              "DAI": "Dairy & Eggs", "VEG": "Vegetables & Fungi", "FRU": "Fruits",
              "GRN": "Grains, Pasta & Noodles", "SAU": "Sauces & Condiments",
              "SPC": "Spices & Seasonings", "SWT": "Sweets & Baking", "LIQ": "Drinks, Liquids & Ice",
              "GRS": "Gross-but-Cute (kid-safe candy & jelly)", "ALN": "Alien Imports",
              "MUT": "Mutagenic", "LEG": "Legendary"}
GROUP_ORDER = list(GROUP_NAME.keys())
ID_RE = re.compile(r"\b(?:RCP|ING|STN|PER|ABL|STS|MUT|ANM|SFX|MUS|BLD|NPC|QST|EVT|TIER|FRN|ROLE|EMP|"
                   r"DST|SKL|MOD|SYN|CMB|ACH|MLS|UPG|INC)_[A-Z0-9_]*[A-Z0-9]\b")


def r_half_up(x):
    return int(math.floor(x + 0.5))


def fmt_mb(x):
    return ("%.2f" % x).rstrip("0").rstrip(".") if abs(x - round(x)) > 1e-9 else "%d" % round(x)


def thousands(n):
    return "{:,}".format(n)


# --------------------------------------------------------------------------------------------
# Canon parsing
# --------------------------------------------------------------------------------------------
def parse_canon():
    with open(CANON, encoding="utf-8") as f:
        text = f.read()
    c = {"text": text}
    c["recipes"] = {}
    for m in re.finditer(r"^\| `(RCP_[A-Z]{3}_\d{3})` \| (.+?) \| (\d+) \|\s*$", text, re.M):
        c["recipes"][m.group(1)] = {"name": m.group(2), "unlock": int(m.group(3))}
    m = re.search(r"Tag vocabulary \(ingredients must use only these\):\*\* `(.+?)`", text, re.S)
    c["tags"] = [t.strip() for t in m.group(1).replace("\n", " ").split(",")]
    m = re.search(r"\*\*Guaranteed core ingredient IDs\*\*(.+?)\*\*Supply model", text, re.S)
    c["core"] = re.findall(r"ING_[A-Z_]+", m.group(1))
    sec7 = text[text.index("## C7."):text.index("### C7.1")]
    c["stations"] = {}
    for m in re.finditer(r"^\| `(STN_[A-Z_]+)` \| (.+?) \|", sec7, re.M):
        c["stations"][m.group(1)] = m.group(2)
    sec71 = text[text.index("### C7.1"):text.index("## C8.")]
    c["avail"] = {}
    for m in re.finditer(r"^\| (`STN_.+?) \| (\d+)[^|]*\| (TIER_\d\d) \|", sec71, re.M):
        for s in re.findall(r"STN_[A-Z_]+", m.group(1)):
            c["avail"][s] = (int(m.group(2)), m.group(3))
    c["per"] = dict(re.findall(r"^\| `(PER_\d{3})` \| (.+?) \|\s*$", text, re.M))
    c["abl"] = {m.group(1): m.group(2) for m in
                re.finditer(r"^\| `(ABL_\d{3})` \| (.+?) \| .+? \|\s*$", text, re.M)}
    c["mut"] = {}
    for m in re.finditer(r"^\| `(MUT_\d{3})` \| (.+?) \| (\w+) \| (\w+) \| (\w+) \| (\w+) \| (.+?) \| "
                         r"(.+?) \|\s*$", text, re.M):
        c["mut"][m.group(1)] = {"name": m.group(2), "slot": m.group(3), "cat": m.group(4),
                                "rarity": m.group(5), "family": m.group(6),
                                "tags": [t.strip() for t in m.group(7).split(",")]}
    sec21 = text[text.index("## C21."):text.index("## C22.")]
    c["anm"] = dict((a, n.strip()) for a, n in re.findall(r"`(ANM_\d{3})` \| ([^|`]+?) \|", sec21))
    c["tiers"] = []
    for m in re.finditer(r"^\| `(TIER_\d\d)` \| (.+?) \| (.+?) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \| "
                         r"(\d+) \| (\d+) \|\s*$", text, re.M):
        c["tiers"].append({"id": m.group(1), "name": m.group(2), "level": int(m.group(4)),
                           "menu": int(m.group(7))})
    c["tokens"] = set(ID_RE.findall(text))
    if len(c["recipes"]) != 150:
        err("canon parse: expected 150 recipes in C10, found %d" % len(c["recipes"]))
    if len(c["avail"]) != 24:
        err("canon parse: expected 24 stations in C7.1, found %d" % len(c["avail"]))
    return c


# --------------------------------------------------------------------------------------------
# Data loading
# --------------------------------------------------------------------------------------------
def load_json(path):
    with open(path, encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError as e:
            err("%s: JSON error %s" % (os.path.basename(path), e))
            return {}


def load_data():
    ings, recs = [], []
    for p in sorted(glob.glob(os.path.join(DATA, "ingredients*.json"))):
        ings.extend(load_json(p).get("ingredients", []))
    meta = load_json(os.path.join(DATA, "recipes.json"))
    for p in sorted(glob.glob(os.path.join(DATA, "recipes_part*.json"))):
        recs.extend(load_json(p).get("recipes", []))
    return ings, meta, recs


# --------------------------------------------------------------------------------------------
# Validation & derived values
# --------------------------------------------------------------------------------------------
def ing_supply(i):
    if SPECIAL_TAGS.intersection(i["tags"]) or i["unlock"] > 20:
        return "SPECIAL"
    return "BASIC"


def ing_states(i):
    return ["RAW"] + [ACTION_STATE[a] for a in i["actions"] if a in ACTION_STATE]


def mentions(text):
    return re.findall(r"ING_[A-Z0-9_]*[A-Z0-9]", text)


def validate_ingredients(c, ings):
    by_id = {}
    for i in ings:
        iid = i.get("id", "?")
        for k in ("id", "name", "tags", "group", "cost", "unlock", "storage", "actions", "asset", "look"):
            if k not in i:
                err("%s: missing field %s" % (iid, k))
        if iid in by_id:
            err("duplicate ingredient %s" % iid)
        by_id[iid] = i
        if not re.match(r"^ING_[A-Z0-9_]+$", iid):
            err("bad ingredient id %s" % iid)
        for t in i.get("tags", []):
            if t not in c["tags"]:
                err("%s: tag '%s' not in canon C9 vocabulary" % (iid, t))
        if i.get("group") not in GROUP_NAME:
            err("%s: unknown group %s" % (iid, i.get("group")))
        st = i.get("storage")
        if st not in STORAGE:
            err("%s: storage %s is not a storage station" % (iid, st))
        elif c["avail"][st][0] > i.get("unlock", 0):
            err("%s: storage %s unavailable at ingredient unlock L%s" % (iid, st, i.get("unlock")))
        for a in i.get("actions", []):
            if a not in ACTION_STATE:
                err("%s: '%s' is not a state-changing canon action" % (iid, a))
        sup = ing_supply(i)
        i["supply"] = sup
        i["states"] = ing_states(i)
        if sup == "BASIC" and not (0.5 <= i["cost"] <= 6):
            err("%s: basic unit cost %.2f outside 0.5-6 MB" % (iid, i["cost"]))
        if sup == "SPECIAL":
            if not i.get("crate"):
                err("%s: SPECIAL ingredient needs a crate size" % iid)
            else:
                i["crate_price"] = r_half_up(i["crate"] * i["cost"])
            if i["cost"] < 5:
                warn("%s: SPECIAL unit cost %.2f is low (< 5 MB)" % (iid, i["cost"]))
        elif i.get("crate"):
            err("%s: BASIC ingredient must not have a crate" % iid)
    for core in c["core"]:
        if core not in by_id:
            err("canon core ingredient %s missing" % core)
    return by_id


def validate_recipes(c, recs, ib):
    by_id = {}
    for r in recs:
        rid = r.get("id", "?")
        if rid in by_id:
            err("duplicate recipe %s" % rid)
        by_id[rid] = r
        cr = c["recipes"].get(rid)
        if not cr:
            err("%s not in canon C10" % rid)
            continue
        if r.get("name") != cr["name"]:
            err("%s: name '%s' != canon '%s'" % (rid, r.get("name"), cr["name"]))
        if r.get("unlock") != cr["unlock"]:
            err("%s: unlock %s != canon %s" % (rid, r.get("unlock"), cr["unlock"]))
        for k in ("d", "var", "prep", "desc", "ing", "steps", "loves", "hates", "cx", "look", "anim",
                  "vfx", "mut"):
            if k not in r:
                err("%s: missing field %s" % (rid, k))
        if any(k not in r for k in ("d", "var", "prep", "ing", "steps")):
            continue
        r["cat"] = rid[4:7]
        L, D = r["unlock"], r["d"]
        if D not in DIFF:
            err("%s: difficulty %s" % (rid, D))
            continue
        if not (0.85 <= r["var"] <= 1.15):
            err("%s: variance %.3f outside 0.85-1.15" % (rid, r["var"]))
        used = {}
        for row in r["ing"]:
            iid, qty, state = row
            if iid not in ib:
                err("%s: unknown ingredient %s" % (rid, iid))
                continue
            if iid in used:
                err("%s: ingredient %s listed twice" % (rid, iid))
            used[iid] = (qty, state)
            ing = ib[iid]
            if qty <= 0:
                err("%s: qty for %s" % (rid, iid))
            if state not in ing["states"]:
                err("%s: %s state %s not in its prep states %s" % (rid, iid, state, ing["states"]))
            if ing["unlock"] > L:
                err("%s (L%d): ingredient %s unlocks at L%d" % (rid, L, iid, ing["unlock"]))
        heat = []
        mentioned = set()
        n_steps = 0
        for s in r["steps"]:
            a, stn, text = s[0], s[1], s[2]
            n_steps += 1
            if a not in ACTIONS or a == "SERVE":
                err("%s: step action %s invalid (SERVE is appended automatically)" % (rid, a))
                continue
            if stn not in c["stations"]:
                err("%s: unknown station %s" % (rid, stn))
                continue
            if stn not in ACTION_STATIONS.get(a, []):
                err("%s: action %s not performed at %s" % (rid, a, stn))
            if c["avail"][stn][0] > L:
                err("%s (L%d): station %s available only from L%d" % (rid, L, stn, c["avail"][stn][0]))
            ms = mentions(text)
            for m in ms:
                mentioned.add(m)
                if m not in used:
                    err("%s: step mentions %s which is not in the ingredient list" % (rid, m))
                elif a in ACTION_STATE and a not in ib[m]["actions"]:
                    err("%s: %s cannot be %s (ingredient actions %s)" % (rid, m, a, ib[m]["actions"]))
            if a in HEAT:
                if len(s) < 4 or not isinstance(s[3], (int, float)):
                    err("%s: heat step '%s' needs T_ready" % (rid, text[:30]))
                    continue
                label = s[4] if len(s) > 4 else (ms[0] if ms else None)
                if not label:
                    err("%s: heat step needs a component" % rid)
                heat.append((label, a, stn, s[3]))
        for iid, (qty, state) in used.items():
            if iid not in mentioned:
                err("%s: ingredient %s never used in a step" % (rid, iid))
            if state != "RAW":
                need = STATE_ACTION[state]
                ok = any(s[0] == need and iid in mentions(s[2]) for s in r["steps"])
                if not ok:
                    err("%s: %s required %s but no %s step mentions it" % (rid, iid, state, need))
        for p in r.get("loves", []) + r.get("hates", []):
            if p not in c["per"]:
                err("%s: unknown personality %s" % (rid, p))
        if set(r.get("loves", [])) & set(r.get("hates", [])):
            err("%s: personality both loves and hates" % rid)
        r["heat"] = heat
        r["n_steps"] = n_steps
        lo, hi = DIFF[D]["steps"]
        if r["cat"] != "LEG" and not (lo <= n_steps <= hi):
            warn("%s: %d steps outside D%d band %d-%d" % (rid, n_steps, D, lo, hi))
        plo, phi = LEG_PREP if r["cat"] == "LEG" else DIFF[D]["prep"]
        if not (plo <= r["prep"] <= phi):
            warn("%s: prep %ss outside band %s-%s" % (rid, r["prep"], plo, phi))
        if heat and r["prep"] < max(h[3] for h in heat) + 4:
            warn("%s: prep %ss shorter than longest heat step + 4 s" % (rid, r["prep"]))
        if r["cat"] == "MUT":
            if not any(s[0] == "INFUSE" for s in r["steps"]):
                err("%s: Mutation Cuisine must INFUSE at STN_INFUSER" % rid)
        if r["cat"] == "ALN" and not any("alien" in ib[i]["tags"] for i in used if i in ib):
            err("%s: Alien Cuisine needs an alien-tagged ingredient" % rid)
        if r["cat"] == "LEG":
            if not any("legendary" in ib[i]["tags"] for i in used if i in ib):
                err("%s: Legendary dish needs a legendary ingredient" % rid)
            cook = {s[1] for s in r["steps"] if s[0] not in ("ASSEMBLE", "PLATE")}
            if len(cook) < 4:
                err("%s: Legendary dish should span >= 4 processing stations" % rid)
        # derived economics
        catf = CAT_FACTOR.get(r["cat"], 1.0)
        raw = 10 * 1.05 ** (L - 1) * (0.8 + 0.1 * D) * catf * r["var"]
        r["price_raw"] = raw
        r["price"] = r_half_up(raw)
        r["cost"] = round(sum(q * ib[i]["cost"] for i, (q, _s) in used.items() if i in ib), 2)
        r["ratio"] = r["cost"] / r["price"] if r["price"] else 0
        r["margin"] = 1 - r["ratio"]
        r["learn"] = 0 if L == 1 else 5 * r["price"]
        if not (0.25 <= r["ratio"] <= 0.40):
            warn("%s: cost ratio %.1f %% outside 25-40 %%" % (rid, 100 * r["ratio"]))
        stations = []
        for iid in used:
            if iid in ib and ib[iid]["storage"] not in stations:
                stations.append(ib[iid]["storage"])
        stations.sort(key=STORAGE.index)
        for s in r["steps"]:
            if s[1] not in stations:
                stations.append(s[1])
        stations.append("STN_WINDOW")
        r["stations"] = stations
        r["specials"] = [i for i in used if i in ib and ib[i]["supply"] == "SPECIAL"]
    for rid in c["recipes"]:
        if rid not in by_id:
            err("canon recipe %s missing from data" % rid)
    for cat in CAT_ORDER:
        n = sum(1 for r in recs if r.get("id", "")[4:7] == cat)
        if n != CAT_COUNT[cat]:
            err("category %s has %d recipes, expected %d" % (cat, n, CAT_COUNT[cat]))
    return by_id


def compute_compat(ings, recs):
    for i in ings:
        i["compat"] = []
    ib = {i["id"]: i for i in ings}
    for r in sorted(recs, key=lambda x: x["id"]):
        for row in r.get("ing", []):
            if row[0] in ib:
                ib[row[0]]["compat"].append(r["id"])
    for i in ings:
        if not i["compat"]:
            warn("%s is not used by any recipe" % i["id"])


def report(recs):
    print("%-12s %3s %1s %4s %6s %8s %6s  %s" % ("id", "L", "D", "var", "price", "cost", "ratio", "band"))
    for r in sorted(recs, key=lambda x: (CAT_ORDER.index(x["id"][4:7]), x["id"])):
        if "price" not in r:
            continue
        lo, hi = DIFF[r["d"]]["ratio"]
        flag = "" if lo <= r["ratio"] <= hi else ("LOW" if r["ratio"] < lo else "HIGH")
        hard = "" if 0.25 <= r["ratio"] <= 0.40 else " !!"
        print("%-12s %3d %1d %4.2f %6d %8.2f %5.1f%%  %2.0f-%2.0f %s%s  target~%.1f" % (
            r["id"], r["unlock"], r["d"], r["var"], r["price"], r["cost"], 100 * r["ratio"],
            100 * lo, 100 * hi, flag, hard, r["price"] * (lo + hi) / 2))


# --------------------------------------------------------------------------------------------
# Mutation affinity hooks (recipe-side; see 6.1.9)
# --------------------------------------------------------------------------------------------
HOOKS = [
    ("Hot Hands", "`fire`", "GRILL / FRY / BAKE / SAUTE steps", "T_ready x0.92 per part", "2 parts (x0.85)"),
    ("Cold Snap", "`ice`", "FREEZE steps", "freeze time x0.6; `ABL_067` Freeze Touch completes one FREEZE "
     "step instantly", "1 part"),
    ("Zap-Cook", "`ABL_066` (`MUT_036`)", "any one running heat component", "finishes it instantly at GOOD "
     "(forfeits Perfect Plate)", "cooldown per §36.6"),
    ("Many Hands", "`tentacle` or `multi`", "ASSEMBLE steps", "each input places 2 layers; `ABL_061` Extra "
     "Hands runs 2 stations", "1 part"),
    ("Kitchen Pro", "`chef`", "all heat components", "Perfect window +0.2 s per part", "3 parts (+0.6 s)"),
    ("Spark Blend", "`electric`", "BLEND / MIX steps", "process time x0.85", "1 part"),
    ("Steam Team", "`water`", "BOIL / STEAM steps", "T_ready x0.9; `ANM_030` extinguish 50 % faster", "1 part"),
    ("Pincer Prep", "`claw`", "CHOP of meat / poultry / seafood / tentacle items", "taps -1 (min 2)", "1 part"),
    ("Green Thumb", "`plant`", "CHOP of veg / fruit / plant items", "green timing zone +20 % width", "1 part"),
    ("Space Chef", "`alien` or `cosmic`", "INFUSE / FLOAT steps; CHOP of alien items",
     "Perfect window +0.5 s; alien CHOP taps -1", "1 part"),
    ("Sweet Tooth", "`sweet`", "SCOOP / POUR / MIX on dishes with a sweet item", "process time x0.85", "1 part"),
    ("Sticky Grip", "`sticky`", "carrying a soup or drink", "never SPILLED when bumped", "1 part"),
    ("Sea Legs", "`aquatic`", "seafood / tentacle heat components", "T_burn +1 s", "1 part"),
    ("Glow Guide", "`glow`", "glowing-item components", "Perfect window +0.25 s", "1 part"),
]


def recipe_hooks(r, ib):
    acts = {s[0] for s in r["steps"]}
    tags = set()
    for row in r["ing"]:
        tags.update(ib[row[0]]["tags"])
    chop_tags = set()
    for s in r["steps"]:
        if s[0] == "CHOP":
            for m in mentions(s[2]):
                chop_tags.update(ib[m]["tags"])
    heat_tags = set()
    for h in r["heat"]:
        if h[0] in ib:
            heat_tags.update(ib[h[0]]["tags"])
    out = []
    if acts & {"GRILL", "FRY", "BAKE", "SAUTE"}:
        out.append("Hot Hands")
    if "FREEZE" in acts or "frozen" in tags:
        out.append("Cold Snap")
    if r["heat"]:
        out.append("Zap-Cook")
    if "ASSEMBLE" in acts:
        out.append("Many Hands")
    if r["heat"]:
        out.append("Kitchen Pro")
    if acts & {"BLEND", "MIX"}:
        out.append("Spark Blend")
    if acts & {"BOIL", "STEAM"}:
        out.append("Steam Team")
    if chop_tags & {"meat", "poultry", "seafood", "tentacle"}:
        out.append("Pincer Prep")
    if chop_tags & {"veg", "fruit", "plant"}:
        out.append("Green Thumb")
    if acts & {"INFUSE", "FLOAT"} or "alien" in chop_tags:
        out.append("Space Chef")
    if "sweet" in tags and acts & {"SCOOP", "POUR", "MIX"}:
        out.append("Sweet Tooth")
    if r["cat"] in ("SOP", "DRK"):
        out.append("Sticky Grip")
    if heat_tags & {"seafood", "tentacle"}:
        out.append("Sea Legs")
    if "glowing" in tags:
        out.append("Glow Guide")
    return out


# --------------------------------------------------------------------------------------------
# Section 6 rendering
# --------------------------------------------------------------------------------------------
def md_table(header, rows):
    out = ["| " + " | ".join(header) + " |", "|" + "|".join("---" for _ in header) + "|"]
    for row in rows:
        out.append("| " + " | ".join(str(x) for x in row) + " |")
    return "\n".join(out)


def pct(x):
    return "%.1f %%" % (100 * x)


def stars(d):
    return "D%d" % d


def heat_line(h):
    label, a, stn, t = h
    lab = "`%s`" % label if label.startswith("ING_") else label
    t_burn = t + BURN_AFTER
    if a in FIRE_RISK:
        tail = "ON_FIRE %s s" % fmt_mb(t_burn + FIRE_AFTER)
    elif a == "INFUSE":
        tail = "over-infused (BURNED grade) after %s s" % fmt_mb(t_burn)
    else:
        tail = "boil-dry (BURNED grade) after %s s" % fmt_mb(t_burn)
    return "%s %s @ `%s`: T_ready %s s · Perfect %s–%s s · Good to %s s · %s" % (
        lab, a, stn, fmt_mb(t), fmt_mb(t), fmt_mb(t + W_PERFECT), fmt_mb(t_burn), tail)


def learn_text(r):
    if r["unlock"] == 1:
        return "known from start"
    base = "%s MB at Cooking Academy `BLD_06` (5 × price) or quest grant" % thousands(r["learn"])
    if r["cat"] == "ALN":
        return base + "; needs the Alien Cuisine course (story chapter 5)"
    if r["cat"] == "MUT":
        return base + "; needs an owned `STN_INFUSER`"
    if r["cat"] == "LEG":
        return "granted only by its Legendary Recipe quest (see §20)"
    return base


def render_detail(r, c, ib):
    o = []
    o.append("#### %s — %s" % (r["id"], r["name"]))
    o.append("")
    o.append("> %s" % r["desc"])
    o.append("")
    o.append("- **Category:** %s %s · **Unlock:** L%d · **Difficulty:** %d/5 · **Base prep time:** %d s · "
             "**Learn:** %s" % (r["cat"], CAT_NAME[r["cat"]], r["unlock"], r["d"], r["prep"], learn_text(r)))
    o.append("- **Base selling price:** %s MB · **Ingredient cost:** %s MB · **Profit margin:** %s "
             "(cost ratio %s; variance ×%.2f)" % (thousands(r["price"]), fmt_mb(r["cost"]), pct(r["margin"]),
                                                  pct(r["ratio"]), r["var"]))
    parts = []
    for iid, q, st in r["ing"]:
        sp = "★" if ib[iid]["supply"] == "SPECIAL" else ""
        parts.append("`%s`%s ×%s (%s)" % (iid, sp, fmt_mb(q), st))
    o.append("- **Ingredients:** " + " · ".join(parts))
    o.append("- **Stations:** " + ", ".join("`%s`" % s for s in r["stations"]))
    o.append("- **Steps:**")
    o.append("  1. Fetch from storage: " + "; ".join(
        "`%s` ← %s" % (stn, ", ".join("`%s`" % i for i, _q, _s in r["ing"] if ib[i]["storage"] == stn))
        for stn in STORAGE if any(ib[i]["storage"] == stn for i, _q, _s in r["ing"])) + ".")
    for s in r["steps"]:
        extra = " *(T_ready %s s)*" % fmt_mb(s[3]) if s[0] in HEAT else ""
        o.append("  1. **%s** @ `%s` — %s%s" % (s[0], s[1], s[2], extra))
    o.append("  1. **SERVE** @ `STN_WINDOW` — %s" % r.get("serve", "ticket rail hand-off (T1–T2) or "
                                                           "table delivery (T3+)."))
    if r.get("order"):
        o.append("- **Assembly order:** %s" % r["order"])
    if r["heat"]:
        o.append("- **Ideal cooking time:** " + " ‖ ".join(heat_line(h) for h in r["heat"]))
    else:
        o.append("- **Ideal cooking time:** no heat component (graded on chop/blend/pour/scoop quality only).")
    sat = ["+%d Perfect Plate (every graded component PERFECT)" % PERFECT_PLATE]
    if r["cat"] == "MUT":
        sat.append("+10 \"Whoa!\" MutationBonus + 60 s cosmetic mutation part (C10 rule)")
    if r.get("loves"):
        sat.append("Loves (+%d): %s" % (LOVE_PTS, ", ".join("`%s` %s" % (p, c["per"][p]) for p in r["loves"])))
    if r.get("hates"):
        sat.append("Hates (%d): %s" % (HATE_PTS, ", ".join("`%s` %s" % (p, c["per"][p]) for p in r["hates"])))
    if r.get("sat"):
        sat.append(r["sat"])
    o.append("- **Satisfaction modifiers:** " + "; ".join(sat) + ".")
    o.append("- **Complaints:** " + " · ".join("\"%s\"" % q for q in r["cx"]))
    o.append("- **Visual:** %s" % r["look"])
    anms = []
    for s in r["steps"]:
        a = ACTION_ANM.get(s[0])
        if s[0] == "BAKE" and s[1] == "STN_PIZZA_OVEN":
            a = "ANM_026"
        if a and a not in anms:
            anms.append(a)
    for a in ("ANM_019", "ANM_043"):
        if a not in anms:
            anms.append(a)
    if any(h[1] in FIRE_RISK for h in r["heat"]):
        anms.append("ANM_030")
    o.append("- **Animation:** %s. %s" % (", ".join("`%s` %s" % (a, c["anm"][a]) for a in anms), r["anim"]))
    o.append("- **Special effects:** %s" % r["vfx"])
    o.append("- **Mutation interactions:** %s *Hooks:* %s." % (r["mut"], ", ".join(recipe_hooks(r, ib))))
    o.append("")
    return "\n".join(o)


def overview_table(rs):
    rows = []
    for r in rs:
        rows.append(["`%s`" % r["id"], r["name"], r["unlock"], r["d"], r["prep"], thousands(r["price"]),
                     fmt_mb(r["cost"]), pct(r["margin"]), "★" * len(r["specials"]) or "—",
                     thousands(r["learn"]) if r["learn"] else "known"])
    return md_table(["ID", "Name", "Unlock L", "Diff", "Prep s", "Price MB", "Cost MB", "Margin",
                     "Special", "Learn MB"], rows)


def render_rules(c, recs, ib, ings):
    by_cat = {k: sorted([r for r in recs if r["cat"] == k], key=lambda r: r["id"]) for k in CAT_ORDER}
    n_basic = sum(1 for i in ings if i["supply"] == "BASIC")
    n_spec = len(ings) - n_basic
    n_rs = sum(1 for r in recs if r["specials"])
    first_spec = min(r["unlock"] for r in recs if r["specials"])
    o = []
    A = o.append
    A("## 6. Recipe Database")
    A("")
    A("> **Owner:** A3 Recipes. **Data-backed:** every table and number in §6, §7 and §36.2 is generated by "
      "`python3 gdd/tools/render_recipes.py` from `gdd/data/ingredients*.json` and `gdd/data/recipes*.json`, "
      "which validates the data against the canon (150 recipes with fixed IDs, names and unlock levels; C9 tag "
      "vocabulary and core ingredient IDs; C7.1 station availability; C8 actions and states; C4.2 price curve). "
      "Edit the JSON, never the markdown. Ingredient rows live in §7; the one-line-per-recipe index is §36.2.")
    A("")
    A("Mystery Morph Restaurant ships **150 recipes in 15 categories** (%s). Every recipe is a small, "
      "deterministic program — ingredients in required states, an ordered list of canon actions at canon "
      "stations, timed heat components — wrapped in a ridiculous costume. %d ingredients feed them (§7): "
      "%d unlimited BASIC and %d stocked SPECIAL." % (
          ", ".join("%s %d" % (k, len(by_cat[k])) for k in CAT_ORDER), len(ings), n_basic, n_spec))
    A("")
    A("### 6.1 Recipe System Rules")
    A("")
    A("#### Purpose")
    A("")
    A("Recipes convert player skill (chop rhythm, heat timing, assembly order, multitasking) into Morph Bucks. "
      "They are the main *content* ladder of the restaurant pillar: each level-up unlocks something new to "
      "cook, each restaurant tier gives more menu slots to show it off, and high-difficulty dishes pay more per "
      "second of effort, funding the mutation loop (Cook → Earn → Morph).")
    A("")
    A("#### Rules & Mechanics")
    A("")
    A("##### 6.1.1 Recipe data schema")
    A("")
    A(md_table(["Field", "Type", "Source", "Meaning"], [
        ["`id`", "string", "canon C10", "`RCP_<CAT>_<NNN>`, stable forever"],
        ["`name`", "string", "canon C10", "display name (localization key = id)"],
        ["`category`", "enum", "derived from id", "BRG PIZ TAC SAN SOP PST BRK DES DRK SEA SAL FRI ALN MUT LEG"],
        ["`unlock`", "int 1–95", "canon C10", "level at which the recipe becomes learnable"],
        ["`d`", "int 1–5", "data", "difficulty (6.1.5); feeds price factor and customer patience (C11.2)"],
        ["`var`", "float 0.85–1.15", "data", "fixed per-recipe flavor variance multiplier in the price"],
        ["`prep`", "int s", "data", "base preparation time: one competent player, Lv1 stations, no stats, "
         "heat steps run in parallel; used by offline `PrepSec_avg` (C15) and employee cook time"],
        ["`ing[]`", "{ingId, qty, state}", "data", "required ingredients, quantity and the C8 state they must "
         "be in when the dish is assembled"],
        ["`steps[]`", "{action, station, text, tReady?, component?}", "data", "ordered canon actions at canon "
         "stations; heat actions carry `tReady` (s, Lv1 baseline)"],
        ["`order`", "string", "data", "assembly order (layer order is graded per C8)"],
        ["`stations[]`", "STN ids", "derived", "storage used + step stations + `STN_WINDOW`"],
        ["`heat[]`", "{component, action, station, tReady}", "derived", "graded heat components (6.1.6)"],
        ["`price` / `cost` / `margin`", "MB / MB / %", "derived", "6.2 formula; cost = Σ qty × unit cost"],
        ["`learnCost`", "MB", "derived", "5 × price (0 for L1 recipes)"],
        ["`specials[]`", "ING ids", "derived", "stocked ingredients → SOLD OUT logic"],
        ["`loves[]` / `hates[]`", "PER ids", "data", "personality dish modifiers (6.1.8)"],
        ["`cx[]`, `look`, `anim`, `vfx`, `mut`", "strings", "data", "complaints, visual, animation, effects, "
         "mutation notes"],
    ]))
    A("")
    A("##### 6.1.2 Learning recipes")
    A("")
    A("L1 recipes (%s) are known from the start. Every other recipe becomes *learnable* at its unlock level and "
      "is learned at the **Cooking Academy** (`BLD_06`, dean Professor Saucington `NPC_009`) for **5 × its base "
      "price** in MB, or is granted free by a quest (recipe unlocks are a C17.4 reward type). Learning is "
      "permanent and account-wide. A learned recipe can be put on the menu only when every station in its "
      "station list is owned and placed (exception: `STN_PLATING` steps use `STN_ASSEMBLY` at TIER_01–02)." % (
          ", ".join("`%s`" % r["id"] for r in recs if r["unlock"] == 1)))
    A("")
    A(md_table(["Category", "Recipes", "Unlock range", "Extra gate"], [
        ["%s %s" % (k, CAT_NAME[k]), len(by_cat[k]), "L%d–L%d" % (min(r["unlock"] for r in by_cat[k]),
                                                                max(r["unlock"] for r in by_cat[k])),
         {"ALN": "Alien Cuisine course — story chapter 5 (Zorp `NPC_027`); no ALN recipe can be bought before it",
          "MUT": "must own an `STN_INFUSER` (L40, TIER_06) before learning; every MUT dish INFUSEs",
          "LEG": "a Legendary Recipe quest (see §20) per dish; never sold at the Academy"}.get(k, "—")]
        for k in CAT_ORDER]))
    A("")
    A("##### 6.1.3 Menu slots")
    A("")
    A("The menu is the set of learned recipes the restaurant currently offers; drinks, sides and desserts use "
      "slots like mains. Menu edits are made at the Menu Board (part of `STN_WINDOW`) at any time and affect only "
      "*new* orders. If every menu item is SOLD OUT, `RCP_BRG_001` is auto-added without using a slot (C22 E9).")
    A("")
    rows = []
    for t in c["tiers"]:
        rows.append(["`%s`" % t["id"], t["name"], "L%d" % t["level"], t["menu"],
                     sum(1 for r in recs if r["unlock"] <= t["level"])])
    A(md_table(["Tier", "Name", "Entry level", "Menu slots", "Recipes learnable at entry level"], rows))
    A("")
    A("##### 6.1.4 From recipe to ticket to dish to validation")
    A("")
    A("```mermaid")
    A("%% diagram: recipe-ticket-dish")
    A("flowchart LR")
    A('  M["Menu (learned recipes in slots)"] --> O["OrderService picks recipe + mods (§6.18)"]')
    A('  O --> R{"Special stock available?"}')
    A('  R -- "no" --> S["SOLD OUT: recipe not offered"]')
    A('  R -- "yes" --> T["Ticket: recipeId, mods, price snapshot, reserved specials"]')
    A('  T --> C["Cook: fetch, CHOP / heat / MIX ... (CookingService grades components)"]')
    A('  C --> A["ASSEMBLE: board matches the ticket ingredient set"]')
    A('  A --> P["PLATE"]')
    A('  P --> V["SERVE: OrderService validates dish vs ticket"]')
    A('  V --> Y["Satisfaction (C11.3) and Pay (C11.4)"]')
    A("```")
    A("")
    A("1. **Order.** When a customer orders, `OrderService` draws a recipe from the menu with weight 1.0, ×2.0 for "
      "recipes the personality *loves*, ×0.25 for recipes it *hates* [TUNABLE]; recipes that are SOLD OUT or need "
      "a Broken/Destroyed station are excluded. Modifications are rolled per §6.18.")
    A("2. **Ticket.** `{ticketId, recipeId, mods[], expectedSet, priceSnapshot, customerId, createdAt}`. "
      "`expectedSet` = the recipe's ingredient multiset adjusted by the mods (e.g. \"no cheese\" removes "
      "`ING_CHEESE`). One unit of every SPECIAL ingredient in `expectedSet` is **reserved** from stock at ticket "
      "creation; reservations are released if the ticket is cancelled before the item is taken from storage.")
    A("3. **Cook.** Taking an ingredient from storage spawns an item in state RAW; every step changes its state "
      "(C8). `CookingService` stores a grade per graded component: chop quality, heat grade (6.1.6), blend/pour/"
      "scoop result.")
    A("4. **Assemble.** Items dropped on an `STN_ASSEMBLY` board form an *Unfinished Stack*; when the stack's "
      "(ingredient, qty, state) multiset equals a ticket's `expectedSet` it becomes a **Dish** tagged with that "
      "recipe, and its layer order is recorded for the assembly-order factor. No two recipes share an identical "
      "multiset (validated by the renderer), so recognition is unambiguous.")
    A("5. **Plate** at `STN_PLATING` (`STN_ASSEMBLY` at TIER_01–02); un-plated dishes take the 0.9 plating "
      "factor at TIER_03+ (C8). Drinks are \"plated\" by lidding the cup at the same station.")
    A("6. **Serve.** `OrderService` validates server-side: correct recipe → A starts at 1.0 and loses 0.25 per "
      "unsatisfied modification (min 0); wrong dish or an Unfinished Stack → A = 0 (the customer may still accept "
      "it per §9). Q and C are computed from the stored grades (C8, C11.3). Pay and tip use the ticket's "
      "`priceSnapshot` (C11.4).")
    A("")
    A("##### 6.1.5 Difficulty model")
    A("")
    rows = []
    prec = {1: "≤3 ordered layers; chop N = 4 taps; one heat component at most",
            2: "≤4 ordered layers; one or two heat components",
            3: "5–6 ordered layers or a two-stage state chain; 2 heat components in parallel",
            4: "≥3 parallel heat components across ≥2 stations; ≥6 ordered layers or 3-stage chains",
            5: "≥4 heat components, multi-stage chains (e.g. CHOP → FRY → INFUSE), long ordered stacks"}
    for d in range(1, 6):
        rs = [r for r in recs if r["d"] == d]
        lo, hi = DIFF[d]["ratio"]
        rows.append(["D%d" % d, "%d–%d" % DIFF[d]["steps"], prec[d], "%d–%d" % DIFF[d]["prep"],
                     "+%d s" % (5 * d), "%.0f–%.0f %%" % (100 * lo, 100 * hi), len(rs),
                     "%.0f s" % (sum(r["prep"] for r in rs) / max(1, len(rs))),
                     pct(sum(r["ratio"] for r in rs) / max(1, len(rs)))])
    A(md_table(["Diff", "Numbered steps", "Precision demands", "Prep band s", "Patience (C11.2)",
                "Cost-ratio target", "Recipes", "Avg prep", "Avg cost ratio"], rows))
    A("")
    A("Legendary dishes ignore the step band (they are multi-station showpieces of 9–13 steps) and use a "
      "%d–%d s prep band. The difficulty price factor is `0.8 + 0.1 × D` (C4.2), so a D5 dish earns 44 %% more "
      "than a D1 dish of the same level." % LEG_PREP)
    A("")
    A("##### 6.1.6 Ideal cooking time (heat components)")
    A("")
    A("Each heat step (GRILL, FRY, BAKE, SAUTE, BOIL, STEAM, FLOAT, INFUSE) is a graded component with an "
      "authored `T_ready` at Lv1 with no stats. Canon C8 then fixes: **Perfect** `[T_ready, T_ready + 2.0 s]`, "
      "**Good** until `T_burn = T_ready + 6 s`, **BURNED** after, **ON_FIRE** at `T_burn + 4 s` on open-heat "
      "stations (GRILL, FRY, BAKE, SAUTE, FLOAT; BOIL/STEAM boil dry and INFUSE over-infuses to a BURNED grade "
      "instead), UNDERCOOKED before `T_ready`. Effective values: `T_ready_eff = T_ready × StationTimeMult "
      "(C4.9) / (1 + 0.006 × COOK_SPD)` and `W_eff = 2.0 × StationWindowMult × (1 + 0.005 × COOK_QLT)` (§5 owns "
      "the station state machines). Non-heat components (CHOP, MIX, BLEND, POUR, SCOOP, FREEZE) are graded by "
      "§5's minigames.")
    A("")
    A("##### 6.1.7 Ingredient supply, stock and SOLD OUT")
    A("")
    A("Per C9, **BASIC** ingredients (unlock ≤ L20, no special tag) are unlimited: their cost is netted from the "
      "sale at serve, and wasted basic food is charged at `STN_TRASH` (never below 0 MB). **SPECIAL** ingredients "
      "(tags alien, mutagen, legendary, gold, glowing — or unlock > L20, which this database always flags as "
      "rarity stock) are bought as crates (§7), stored in `STN_PANTRY`/`STN_FRIDGE`/`STN_FREEZER` stock and "
      "consumed per unit. %d of 150 recipes use at least one SPECIAL ingredient (marked ★); the first appears at "
      "L%d. When any SPECIAL ingredient of a recipe has 0 unreserved units, the recipe shows **SOLD OUT** on the "
      "menu board and in the Recipe Book and cannot be ordered; it returns automatically when stock arrives." % (
          n_rs, first_spec))
    A("")
    A("##### 6.1.8 Customer satisfaction modifiers")
    A("")
    A("Dish modifiers are added inside the `P_offset` term of the C11.3 satisfaction formula as a **dish offset**, "
      "clamped to −15…+15 in total: **Perfect Plate +%d** when every graded component is PERFECT; **Loves +%d** and "
      "**Hates %d** for the listed personalities (C11.1; §9 may list further preferences, which stack inside the "
      "same clamp). Mutation Cuisine applies the C10 rule: +10 \"Whoa!\" as the `MutationBonus` term plus a 60 s "
      "client-only cosmetic mutation part. Complaint lines are barks played at *Inspect food* (§8) when a "
      "component grades below GOOD or a *hates* modifier fires." % (PERFECT_PLATE, LOVE_PTS, HATE_PTS))
    A("")
    A("##### 6.1.9 Mutation affinity hooks")
    A("")
    A("Recipes expose *hooks* — properties that equipped mutation parts react to through their C13.5 tags. The "
      "defaults below apply automatically to every equipped part carrying the tag; §12 passives and §36.4 "
      "synergies multiply on top within their own caps. Each recipe lists the hooks that apply to it; the "
      "signature line names the parts and abilities that make that dish shine.")
    A("")
    A(md_table(["Hook", "Part tag / ability", "Applies to", "Default effect [TUNABLE]", "Stack cap"],
               [list(h) for h in HOOKS]))
    A("")
    return "\n".join(o)


def render_rules2(c, recs, ib, ings):
    o = []
    A = o.append
    A("#### Variables")
    A("")
    A(md_table(["Variable", "Value", "Notes"], [
        ["Learn cost multiplier", "5 × price [canon]", "L1 recipes free"],
        ["Perfect window `W_perfect`", "2.0 s [canon TUNABLE]", "per heat component, Lv1"],
        ["Burn offset", "T_ready + 6 s [canon TUNABLE]", "ON_FIRE 4 s later on open heat"],
        ["Perfect Plate bonus", "+%d [TUNABLE]" % PERFECT_PLATE, "dish offset"],
        ["Love / hate modifier", "+%d / %d [TUNABLE]" % (LOVE_PTS, HATE_PTS), "dish offset"],
        ["Dish offset clamp", "−15…+15 [TUNABLE]", "inside `P_offset`"],
        ["Order weight love / hate", "×2.0 / ×0.25 [TUNABLE]", "menu draw"],
        ["Hand-mix penalty", "1.5 × MIX time [canon]", "MIX at `STN_PREP` before `STN_MIXER`"],
        ["Modification surcharge", "+10 % of base price per satisfied mod, max +30 % [TUNABLE]", "6.2.4"],
        ["Cost-ratio target band", "25–40 % [canon]", "per difficulty in 6.1.5"],
        ["Variance multiplier", "0.85–1.15 [canon]", "fixed per recipe, stored in data"],
    ]))
    A("")
    A("#### UI")
    A("")
    A("- **Recipe Book** (Cooking Academy counter and the restaurant's Menu Board): a grid of recipe cards — "
      "isometric dish render, name, category icon, difficulty shown as *D3* text **and** three pips (never "
      "colour-only), price, ingredient cost, margin bar, station icons (greyed with a lock if not owned), ★ "
      "special-stock counter, SOLD OUT stamp, and a LEARN button showing 5 × price. Filters: category, "
      "learnable, on menu, needs station.")
    A("- **Ticket card** (ticket rail at `STN_WINDOW` and the HUD order queue): recipe icon, customer patience "
      "ring, modification text, and a component checklist where each component shows its target state icon "
      "(e.g. a flame for GRILLED) and fills with its live grade.")
    A("- **Station overlay** (§5): the heat bar shows the Perfect band in green **with** a ✓ notch and the burn "
      "zone with a ✗ notch; the ideal times in each recipe's detail block are exactly what this bar draws at Lv1.")
    A("")
    A("#### Progression")
    A("")
    bands = [(1, 10), (11, 20), (21, 30), (31, 40), (41, 50), (51, 60), (61, 70), (71, 80), (81, 95)]
    rows = []
    for lo, hi in bands:
        rs = [r for r in recs if lo <= r["unlock"] <= hi]
        rows.append(["L%d–L%d" % (lo, hi), len(rs), ", ".join(sorted({r["cat"] for r in rs},
                                                                    key=CAT_ORDER.index)),
                     "%s–%s" % (thousands(min(r["price"] for r in rs)), thousands(max(r["price"] for r in rs))),
                     sum(1 for r in rs if r["specials"])])
    A(md_table(["Level band", "New recipes", "Categories", "Price range MB", "With SPECIAL stock"], rows))
    A("")
    A("Roughly one new recipe per level through L60 keeps every level-up exciting; the sparse L60+ tail is "
      "reserved for Mutation and Legendary showpieces that pair with RT-gated mutation upgrades (§22).")
    A("")
    A("#### Player Interactions")
    A("")
    A("- **Co-op (§21):** items are restaurant-owned, so any co-op player may perform any step of any ticket "
      "(C22 E7); station slots lock per interactor.")
    A("- **Employees (§16):** a `ROLE_CHEF` cooks a recipe only if `D ≤ 1 + floor(CookingSkill / 25)` (C15); "
      "`ROLE_PREP` performs CHOP and MIX steps and stages items at `STN_PREP`; `ROLE_STOCKER` re-buys SPECIAL "
      "crates (§7).")
    A("- **Customers:** personalities pick favourites by the love/hate lists; dish complaints feed anger (§10).")
    A("")
    A("#### Dependencies")
    A("")
    A("§5 Cooking Mechanics (station timing, minigames, failure states) · §6.18 Order Modifications · §7 "
      "Ingredients · §8–§10 customer evaluation · §12 / §36.4 mutation passives and synergies · §14 XP per dish · "
      "§16–§17 employees and offline `PrepSec_avg`/`AvgTicket` · §20 quests granting recipes · §22 economy · "
      "§27 `RecipeService`/`OrderService`/`CookingService` · §28 recipe-unlock persistence.")
    A("")
    A("#### Roblox Implementation")
    A("")
    A("The renderer's JSON is also exported (build step) to `ReplicatedStorage.Shared.Data.RecipeDefs` as a "
      "frozen Luau table; `RecipeService` owns learning and menus, `OrderService` builds tickets, "
      "`CookingService` grades components. Clients only *display* prices and timings; the server recomputes "
      "every grade and payment.")
    A("")
    A("```lua")
    A("--!strict")
    A("export type IngredientReq = { id: string, qty: number, state: string }")
    A("export type Step = { action: string, station: string, tReady: number?, component: string? }")
    A("export type RecipeDef = {")
    A("  id: string, category: string, unlock: number, difficulty: number,")
    A("  prepSec: number, price: number, cost: number, ingredients: { IngredientReq },")
    A("  steps: { Step }, stations: { string }, specials: { string }, loves: { string }, hates: { string },")
    A("}")
    b = next(r for r in recs if r["id"] == "RCP_BRG_001")
    A("local RecipeDefs: { [string]: RecipeDef } = table.freeze({")
    A("  RCP_BRG_001 = table.freeze({")
    A("    id = \"RCP_BRG_001\", category = \"BRG\", unlock = 1, difficulty = %d," % b["d"])
    A("    prepSec = %d, price = %d, cost = %s," % (b["prep"], b["price"], fmt_mb(b["cost"])))
    A("    ingredients = { " + ", ".join("{ id = \"%s\", qty = %s, state = \"%s\" }" % (i, fmt_mb(q), s)
                                      for i, q, s in b["ing"][:3]) + ", --[[ ... ]] },")
    A("    steps = { { action = \"GRILL\", station = \"STN_GRILL\", tReady = %s, component = \"ING_BEEF_PATTY\" }"
      ", --[[ ... ]] }," % fmt_mb(b["heat"][0][3]))
    A("    stations = { " + ", ".join("\"%s\"" % s for s in b["stations"]) + " },")
    A("    specials = {}, loves = { " + ", ".join("\"%s\"" % p for p in b["loves"]) + " }, hates = { " +
      ", ".join("\"%s\"" % p for p in b["hates"]) + " },")
    A("  }),")
    A("})")
    A("")
    A("-- Server-side dish check used by OrderService at SERVE.")
    A("local function matchesTicket(dishSet: { [string]: { qty: number, state: string } },")
    A("    expected: { IngredientReq }): boolean")
    A("  local count = 0")
    A("  for _, req in expected do")
    A("    local got = dishSet[req.id]")
    A("    if not got or got.qty ~= req.qty or got.state ~= req.state then return false end")
    A("    count += 1")
    A("  end")
    A("  for _ in dishSet do count -= 1 end")
    A("  return count == 0 -- no extra ingredients")
    A("end")
    A("```")
    A("")
    A("#### Edge Cases")
    A("")
    A("- **Stock runs out mid-rush:** units already reserved by open tickets are untouchable; only *new* orders "
      "see SOLD OUT. Cancelled tickets release unreserved units.")
    A("- **Recipe removed from the menu with open tickets:** open tickets stay valid and pay their snapshot price.")
    A("- **Station destroyed mid-cook:** the item pops out onto the nearest free `STN_PREP` hold with its current "
      "state and timer frozen; tickets needing that station hide from new orders until repaired.")
    A("- **MUT dish served to a customer who already wears a cosmetic part:** the new 60 s part replaces it; the "
      "+10 bonus applies once per customer visit.")
    A("- **Owner disconnects (C22 E1):** in-progress basic food is discarded free; SPECIAL items return to stock.")
    A("- **Two players finish the same ticket:** the first validated SERVE wins; the duplicate dish becomes a "
      "*spare* that may satisfy another ticket of the same recipe within 60 s, else it is trashed at cost.")
    A("- **Modification removes a SPECIAL ingredient:** that unit is not reserved, so the dish can be ordered even "
      "while the ingredient is SOLD OUT.")
    A("")
    A("#### Acceptance Criteria")
    A("")
    acs = [
        "All 150 canon recipes exist with IDs, names and unlock levels exactly matching C10; the renderer exits 0.",
        "Every recipe's base price equals `round(10 × 1.05^(L−1) × (0.8 + 0.1·D) × CategoryFactor × var)` "
        "with `var` in 0.85–1.15.",
        "Every recipe's ingredient cost ratio is within 25–40 % and the mean ratio falls as difficulty rises.",
        "No recipe uses a station before that station's C7.1 availability level.",
        "Every non-RAW required ingredient state is produced by a step of the matching action.",
        "A recipe whose SPECIAL ingredient has 0 unreserved units is never offered by `OrderService` and shows "
        "SOLD OUT within 1 s.",
        "Learning a recipe at `BLD_06` deducts exactly 5 × price MB and persists across sessions.",
        "ALN recipes cannot be learned before the Alien Cuisine course, MUT recipes before an owned "
        "`STN_INFUSER`, LEG recipes except via their Legendary Recipe quest.",
        "A heat component removed inside its Perfect window grades PERFECT (1.00) and the ticket checklist "
        "shows it within 0.2 s.",
        "Serving a dish whose multiset differs from the ticket `expectedSet` yields A = 0 server-side regardless "
        "of client claims.",
        "A menu shows at most the C6 menu-slot count for the current tier.",
        "Eating a MUT dish shows a cosmetic part on the customer for 60 s ± 0.5 s and adds +10 satisfaction.",
    ]
    for n, a in enumerate(acs, 1):
        A("- **AC-06-%02d:** %s" % (n, a))
    A("")
    return "\n".join(o)


def worked_example(r, ib):
    L, D = r["unlock"], r["d"]
    catf = CAT_FACTOR.get(r["cat"], 1.0)
    base = 10 * 1.05 ** (L - 1)
    lines = ["**%s %s** (L%d, D%d, %s): `10 × 1.05^%d = %.2f` × difficulty `%.1f` × category `%.1f` × "
             "variance `%.2f` = %.2f → **%s MB**. Cost = %s = **%s MB** → ratio %s, margin **%s**." % (
                 r["id"], r["name"], L, D, r["cat"], L - 1, base, 0.8 + 0.1 * D, catf, r["var"], r["price_raw"],
                 thousands(r["price"]),
                 " + ".join("%s×%s" % (fmt_mb(q), fmt_mb(ib[i]["cost"])) for i, q, _s in r["ing"]),
                 fmt_mb(r["cost"]), pct(r["ratio"]), pct(r["margin"]))]
    return lines[0]


def render_pricing(c, recs, ib, meta):
    rb = {r["id"]: r for r in recs}
    o = []
    A = o.append
    A("### 6.2 Pricing & Profitability")
    A("")
    A("#### 6.2.1 Price formula (canon C4.2)")
    A("")
    A("```text")
    A("BasePrice  = 10 × 1.05^(L − 1)                  L = recipe unlock level")
    A("Price      = round_half_up( BasePrice × (0.8 + 0.1 × D) × CategoryFactor × var )")
    A("CategoryFactor: DRK, FRI, SAL ×0.7 · DES ×0.8 · LEG ×2.5 · all others ×1.0")
    A("var        = fixed per-recipe flavor variance, 0.85–1.15, stored in the recipe data")
    A("Cost       = Σ qty × ingredient unit cost (§7)  ·  Margin = (Price − Cost) / Price")
    A("```")
    A("")
    refs = [(1, 10), (10, 16), (20, 25), (30, 41), (40, 67), (50, 109), (60, 177), (70, 288), (80, 469),
            (90, 764), (95, 975)]
    A(md_table(["L", "10 × 1.05^(L−1)", "Canon reference", "Recipes unlocking at L"],
               [[L, "%.2f" % (10 * 1.05 ** (L - 1)), "≈ %d" % ref,
                 ", ".join("`%s`" % r["id"] for r in recs if r["unlock"] == L) or "—"] for L, ref in refs]))
    A("")
    A("#### 6.2.2 Worked examples")
    A("")
    for rid in meta.get("worked_examples", []):
        A("- " + worked_example(rb[rid], ib))
    A("")
    A("#### 6.2.3 Margin targets and actuals")
    A("")
    A("Ingredient cost targets 25–40 % of price (C4.2), falling with difficulty so that hard dishes reward skill "
      "with both a higher price factor *and* a fatter margin. Actual values below are computed from the data.")
    A("")
    rows = []
    for d in range(1, 6):
        rs = [r for r in recs if r["d"] == d]
        lo, hi = DIFF[d]["ratio"]
        rows.append(["D%d" % d, len(rs), "%.0f–%.0f %%" % (100 * lo, 100 * hi),
                     pct(min(r["ratio"] for r in rs)), pct(sum(r["ratio"] for r in rs) / len(rs)),
                     pct(max(r["ratio"] for r in rs)), pct(1 - sum(r["ratio"] for r in rs) / len(rs))])
    A(md_table(["Diff", "Recipes", "Target ratio", "Min ratio", "Mean ratio", "Max ratio", "Mean margin"], rows))
    A("")
    rows = []
    for k in CAT_ORDER:
        rs = [r for r in recs if r["cat"] == k]
        rows.append(["%s %s" % (k, CAT_NAME[k]), len(rs), "×%.1f" % CAT_FACTOR.get(k, 1.0),
                     "%s–%s" % (thousands(min(r["price"] for r in rs)), thousands(max(r["price"] for r in rs))),
                     pct(sum(r["margin"] for r in rs) / len(rs)),
                     "%.0f" % (sum(r["prep"] for r in rs) / len(rs)),
                     "%.2f" % (sum((r["price"] - r["cost"]) / r["prep"] for r in rs) / len(rs))])
    A(md_table(["Category", "Recipes", "Cat. factor", "Price MB", "Mean margin", "Mean prep s",
                "Mean profit MB per prep-second"], rows))
    A("")
    A("Drinks, fried sides and salads are priced at ×0.7 but are quick: they exist to raise the C4.3 average "
      "ticket (1.4 items per customer) and to be the cheap \"Peace Offering\" freebie of C11.5.")
    A("")
    A("#### 6.2.4 How modifications add pay")
    A("")
    A("Each **satisfied** mechanical modification (§6.18) adds **+10 %% of the base price** to that item's ticket "
      "price, capped at +30 %% per item [TUNABLE]; the surcharge is part of `priceSnapshot`, so tips scale with it. "
      "Mods that *add* ingredients also add those ingredients' unit cost; mods that *remove* ingredients do not "
      "discount the price (the customer is paying for the inconvenience). Joke requests resolved by §6.18's "
      "alternative satisfaction mechanic carry no surcharge. Example: `RCP_BRG_002` with \"exactly seventeen "
      "pickles\" and \"upside down\" → %s × 1.20 = %s MB, cost + 16 × `ING_PICKLE` (%s MB each)." % (
          rb["RCP_BRG_002"]["price"], r_half_up(rb["RCP_BRG_002"]["price"] * 1.2), fmt_mb(ib["ING_PICKLE"]["cost"])))
    A("")
    A("#### 6.2.5 Learning payback")
    A("")
    A("Learn cost is 5 × price, so a recipe repays itself after `5 / margin` servings — about 7–8 orders. "
      "Examples:")
    A("")
    rows = []
    for rid in meta.get("payback_examples", []):
        r = rb[rid]
        rows.append(["`%s`" % rid, r["name"], thousands(r["learn"]), "%.2f" % (r["price"] - r["cost"]),
                     "%.1f" % (r["learn"] / (r["price"] - r["cost"]))])
    A(md_table(["ID", "Name", "Learn MB", "Profit per serving MB", "Servings to repay"], rows))
    A("")
    A("#### 6.2.6 Economy hooks")
    A("")
    A("- Customer pay and tips use the ticket price (C11.4). Ingredient cost is reduced by player EFFICIENCY "
      "(`× (1 − 0.0015 × S)`, C5) and, for SPECIAL crates, by the Ingredient Stocker discount (5–15 %, §7).")
    A("- Offline simulation (C15) uses each menu recipe's `price` (AvgTicket), `cost` (AvgIngredientCost), `prep` "
      "(PrepSec_avg) and `d` (chef skill gate); SOLD OUT recipes drop out of the offline menu.")
    A("- Menu-weighted average item price at each tier's entry level is the input for §22's pacing simulation.")
    A("")
    return "\n".join(o)


def render_s6(c, recs, ib, ings, meta):
    parts = [render_rules(c, recs, ib, ings), render_rules2(c, recs, ib, ings), render_pricing(c, recs, ib, meta)]
    for n, k in enumerate(CAT_ORDER, 3):
        rs = sorted([r for r in recs if r["cat"] == k], key=lambda r: r["id"])
        sec = ["### 6.%d %s (%d)" % (n, CAT_NAME[k], len(rs)), "", meta["category_intro"][k], "",
               overview_table(rs), ""]
        for r in rs:
            sec.append(render_detail(r, c, ib))
        parts.append("\n".join(sec))
    return "\n".join(parts).rstrip() + "\n"

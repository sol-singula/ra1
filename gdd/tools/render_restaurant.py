#!/usr/bin/env python3
"""Render the A10 Restaurant databases for MYSTERY MORPH RESTAURANT.

Reads  gdd/data/furniture.json
Writes gdd/sections/36_12_restaurant_tiers_upgrades.md
       gdd/sections/36_13_furniture_catalog.md
       and refreshes the AUTO blocks inside gdd/sections/15_restaurant_building.md
       (text between "<!-- AUTO:render_restaurant:<key> BEGIN -->" and "... END -->").

Python 3 standard library only. Idempotent. Run from the repo root:
    python3 gdd/tools/render_restaurant.py
Exit code 1 if validation fails (files are still written so the problem is visible).
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "gdd", "data", "furniture.json")
SEC = os.path.join(ROOT, "gdd", "sections")
OUT_12 = os.path.join(SEC, "36_12_restaurant_tiers_upgrades.md")
OUT_13 = os.path.join(SEC, "36_13_furniture_catalog.md")
SEC_15 = os.path.join(SEC, "15_restaurant_building.md")

CANON_STATIONS = [
    "STN_PANTRY", "STN_FRIDGE", "STN_FREEZER", "STN_CUT", "STN_PREP", "STN_GRILL", "STN_FRYER",
    "STN_OVEN", "STN_PIZZA_OVEN", "STN_STOVE", "STN_SOUP_POT", "STN_STEAMER", "STN_BLENDER",
    "STN_MIXER", "STN_DRINK", "STN_ICECREAM", "STN_ASSEMBLY", "STN_PLATING", "STN_WINDOW",
    "STN_DISHWASH", "STN_TRASH", "STN_DELIVERY", "STN_INFUSER", "STN_ANTIGRAV",
]
SLOT_STATIONS = {  # canon C6: these use appliance slots
    "STN_CUT", "STN_GRILL", "STN_FRYER", "STN_OVEN", "STN_PIZZA_OVEN", "STN_STOVE", "STN_SOUP_POT",
    "STN_STEAMER", "STN_BLENDER", "STN_MIXER", "STN_DRINK", "STN_ICECREAM", "STN_INFUSER", "STN_ANTIGRAV",
}
TROPHY_NAMES = {  # canon C16.6
    "FRN_901": "Golden Spatula Trophy", "FRN_902": "Rat King's Crown Display",
    "FRN_903": "Critic's Five-Star Plaque", "FRN_904": "Arena Champion Belt Case",
    "FRN_905": "Baron's Defeated Mustache Portrait", "FRN_906": "Meteor Chunk Lamp",
    "FRN_907": "Parade Float Mini", "FRN_908": "Kraken Plush", "FRN_909": "Museum Replica Fossil",
    "FRN_910": "Omnivora's Signed Apron",
}
ROLE_LABEL = {"chef": "Chef", "prep": "Prep", "waiter": "Waiter", "cashier": "Cashier", "dish": "Dish",
              "security": "Security", "repair": "Repair", "stocker": "Stocker", "manager": "Manager",
              "asst": "Asst Mgr"}

ERRORS = []


def err(msg):
    ERRORS.append(msg)


def fmt(n, dec=0):
    if n is None:
        return "\u2014"
    if dec:
        return f"{n:,.{dec}f}"
    return f"{int(round(n)):,}"


def pol(text):
    """Typographic polish for JSON-sourced prose: section refs, multiplication signs, minus signs."""
    if not text:
        return text
    text = re.sub(r"\bsections? (\d+(?:\.\d+)*)", "\u00a7\\1", text)
    text = re.sub(r"(^|[\s(])x(\d)", "\\1\u00d7\\2", text)
    text = re.sub(r"(^|[\s(])-(\d)", "\\1\u2212\\2", text)
    text = text.replace(" -> ", " \u2192 ").replace(">=", "\u2265")
    return text


def fp(s):
    return re.sub(r"(\d)x(\d)", "\\1\u00d7\\2", s)


def tnum(tid):
    return int(tid.split("_")[1])


# ----------------------------------------------------------------------------- economics
def tier_econ(d, t):
    """Online throughput estimate + canon C15 offline estimate for the tier's crews."""
    c = d["constants"]
    prof = d["rarity_profiles"]
    rep = 0.5 + 0.25 * t["stars"]
    dec = 0.9 + 0.003 * t["atmos"]
    seat_cap_on = t["seats"] * 3600 / c["visit_seconds_online"]
    demand_on = t["demand"] * rep * dec
    thr = min(demand_on, seat_cap_on)
    full_wages = sum(prof[r]["wage"] * n for _, r, n in t["crew_full"])
    # Calibrate the menu-weighted mean item price P so that active net matches canon C4.4.
    margin = 1 - t["ing_ratio"] + c["online_tip_rate"]
    price = (t["net_active"] / (1 + c["quest_share"]) + full_wages) / (thr * c["items_per_customer"] * margin)
    out = {"rep": rep, "dec": dec, "thr": thr, "demand_on": demand_on, "seat_cap_on": seat_cap_on, "P": price}
    for key in ("crew_full", "crew_lean"):
        out[key] = offline(d, t, t[key], price)
    return out


def offline(d, t, crew, price):
    c = d["constants"]
    prof = d["rarity_profiles"]
    tid = tnum(t["id"])
    members = []
    for role, r, n in crew:
        members += [(role, r)] * n
    mgr = [r for role, r in members if role == "manager"]
    hours = d["manager_caps"][mgr[0]] if mgr else 2
    if any(role == "asst" for role, _ in members) and mgr:
        hours = min(24, hours + 2)
    drain = 0.05 if mgr else 0.08
    energy = max(0.0, 1 - drain * hours / 2)  # average energy over the shift
    morale = c["morale_assumed"] / 100

    def eff(r):
        return prof[r]["stat"] * (0.6 + 0.4 * morale) * (0.7 + 0.3 * energy) * (1 + 0.001 * t["player_eff"]) / 100

    chefs = [r for role, r in members if role == "chef"]
    preps = sum(1 for role, _ in members if role == "prep")
    waiters = [r for role, r in members if role == "waiter"]
    cashiers = [r for role, r in members if role == "cashier"]
    has_dish = any(role == "dish" for role, _ in members)
    has_stock = any(role == "stocker" for role, _ in members)
    dish_factor = 0.8 if (tid >= 4 and not has_dish) else 1.0
    cap_k = sum((3600 / t["prep_sec"]) * eff(r) / c["items_per_customer"] for r in chefs)
    cap_k *= (1 + 0.15 * min(3, preps)) * dish_factor
    if tid <= 2:
        cap_s = cap_k
    elif waiters:
        cap_s = sum(80 * eff(r) for r in waiters) * (1 + 0.10 * len(cashiers))
    else:
        cap_s = 0.3 * cap_k
    dem = t["demand"] * (0.5 + 0.25 * t["stars"]) * (0.9 + 0.003 * t["atmos"]) * c["offline_demand_factor"]
    cap_seat = t["seats"] * 3600 / c["visit_seconds_offline"]
    q_cust = min(dem, cap_seat, cap_k, cap_s)
    ticket = c["items_per_customer"] * price
    qual = min(0.95, 0.70 + 0.25 * (sum(prof[r]["acc"] for r in chefs) / len(chefs)) / 100)
    revenue = q_cust * ticket * qual
    w_svc = (sum(prof[r]["svc"] for r in waiters) / len(waiters)) if (waiters and tid > 2) else 0
    cash_sk = max((prof[r]["stat"] for r in cashiers), default=0)
    tips = revenue * (0.04 + 0.04 * w_svc / 100) * (1 + 0.01 * math.floor(cash_sk / 20))
    ingr = q_cust * ticket * t["ing_ratio"] * (1 - (0.10 if has_stock else 0)) * (1 - 0.0015 * t["player_eff"])
    wages = sum(prof[r]["wage"] for _, r in members)
    net = max(0.0, revenue + tips - ingr - wages)
    binding = min((("demand", dem), ("seats", cap_seat), ("kitchen", cap_k), ("service", cap_s)), key=lambda z: z[1])[0]
    return {"H": hours, "E": energy, "dem": dem, "cap_seat": cap_seat, "cap_k": cap_k, "cap_s": cap_s,
            "Q": q_cust, "ticket": ticket, "q": qual, "rev": revenue, "tips": tips, "ingr": ingr,
            "wages": wages, "net": net, "pct": net / t["net_active"], "session": net * hours,
            "binding": binding, "size": len(members)}


def crew_text(d, crew):
    parts = []
    for role, r, n in crew:
        lab = "Ollie" if r == "OLLIE" else d["rarity_profiles"][r]["label"][0]
        parts.append(f"{n}\u00d7{ROLE_LABEL[role]}" + ("" if r == "OLLIE" else f" ({lab})") if r != "OLLIE" else "Ollie (EMP_001)")
    return ", ".join(parts)


# ----------------------------------------------------------------------------- 36.12
def station_path(d, u, items):
    base = items[u["base_item"]]
    mults = d["constants"]["station_mults"]
    tiers = d["constants"]["station_level_tiers"]
    costs = [m * base[5] for m in mults]
    k = u["kind"]
    effect = (f"Canon \u00a7C4.9 **{k}** profile for every owned `{u['path_station']}` (stock + premium): "
              f"time \u00d70.90 \u2192 \u00d70.80 \u2192 \u00d70.70 \u2192 \u00d70.60 + Lv5 gimmick (\u00a75)")
    cost = " \u00b7 ".join(f"Lv{i + 2} {fmt(cv)}" for i, cv in enumerate(costs))
    cost += f" (\u00d71.5/\u00d74/\u00d710/\u00d725 of `{u['base_item']}` {fmt(base[5])})"
    req = " \u00b7 ".join(f"Lv{i + 2} T{tt}" for i, tt in enumerate(tiers)) + f"; station from L{u['level']}"
    return effect, cost, req, costs


def ukey(d, key):
    for u in d["upgrades"]:
        if u.get("key") == key:
            return u["id"]
    err(f"missing upgrade key {key}")
    return "UPG_???"


def render_36_12(d, econ, items):
    L = []
    a = L.append
    a("### 36.12 Restaurant Tiers and Upgrades Database")
    a("")
    a("> Generated by `python3 gdd/tools/render_restaurant.py` from `gdd/data/furniture.json` (owner A10). "
      "Edit the JSON, not this file. Canon values (cost, level, seats, appliance slots, menu slots, employee cap, "
      "base demand) are copied verbatim from canon \u00a7C6; everything else is defined here and in \u00a715. "
      "All economy figures are **[TUNABLE]** balancing assumptions.")
    a("")
    a("**How to read the tier table.** *Table capacity* = canon Seats = the hard cap on attached seats a layout may "
      "contain (\u00a715.5). *Kitchen capacity* = canon appliance slots (only the 14 slot-using appliances count; "
      "utility fixtures are free but need floor space) plus the kitchen floor area. *Customer throughput* is the "
      "online planning estimate `min(BaseDemand \u00d7 RepMult \u00d7 DecorMult, Seats \u00d7 3600 / 240 s)` at the "
      "tier's typical reputation and atmosphere, and the offline value is the canon \u00a7C15 `Q` for the full crew. "
      "*Offline earning potential* is canon \u00a7C15 net MB per offline hour for a lean crew (1 chef, +1 waiter from "
      "TIER_03, no manager) and a full tier-typical crew (\u00a736.12.3), with the full crew's offline cap and the "
      "resulting maximum per collected session.")
    a("")
    a("#### 36.12.1 Tier Database")
    a("")
    a("| ID | Name | Upgrade cost (MB) | Unlock requirements | Floor area (studs) | Table capacity | Kitchen capacity | "
      "Menu slots | Customer throughput (cust/h) | Available equipment (new at this tier) | Decoration options | "
      "Employee capacity | Offline earning potential |")
    a("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    prev = None
    for t in d["tiers"]:
        e = econ[t["id"]]
        n = tnum(t["id"])
        if n == 1:
            req = "Start (Level 1); granted by the story intro (Nana Gristle's shack)"
        else:
            req = f"L{t['level']} \u00b7 {fmt(t['cost'])} MB \u00b7 owns `{prev}`"
            if t["permit"]:
                req += " \u00b7 City Hall Expansion Permit (\u00a720)"
            req += " \u00b7 empty dining room (\u00a715.3)"
        area = t["W"] * t["D"]
        fa = f"{t['W']}\u00d7{t['D']} = {fmt(area)}"
        if t["patio"][0]:
            fa += f" + patio {t['patio'][0]}\u00d7{t['patio'][1]} ({fmt(t['patio'][0] * t['patio'][1])}, needs `{ukey(d, 'patio_permit')}`)"
        kc = (f"{t['slots']} appliance slots \u00b7 kitchen {t['W']}\u00d7{t['Dk']} = {fmt(t['W'] * t['Dk'])} sq studs "
              f"\u00b7 utility fixtures slot-free")
        thr = f"online \u2248 {fmt(e['thr'])} \u00b7 offline \u2248 {fmt(e['crew_full']['Q'])}"
        f = e["crew_full"]
        lean = e["crew_lean"]
        off = (f"{fmt(lean['net'])}\u2013{fmt(f['net'])} MB/h \u00b7 cap {f['H']} h \u2192 \u2264 {fmt(f['session'])} MB "
               f"per session ({round(100 * f['pct'])} % of active)")
        a(f"| `{t['id']}` | {t['name']} | {fmt(t['cost'])} | {req} | {fa} | {t['seats']} seats "
          f"({t['service']} service) | {kc} | {t['menu']} | {thr} | {pol(t['equipment'])} | {pol(t['decor'])} | "
          f"{t['emp']} | {off} |")
        prev = t["id"]
    a("")
    a("#### 36.12.2 Layout Limits per Tier")
    a("")
    a("Grid cell = 2 studs. The interior origin is the front-left corner; the patio grid sits at negative x "
      f"(\u00a715.12). Kitchen expansion upgrades (`{ukey(d, 'kitchen_exp_1')}`\u2013`{ukey(d, 'kitchen_exp_3')}`) add 4 studs of kitchen depth each on top "
      "of these values.")
    a("")
    a("| # | Tier | Interior W\u00d7D | Kitchen depth / dining depth | Grid cells (interior + patio) | Max placed items | "
      "Window sockets | Curb sockets | Max serving windows | Atmosphere cap | Furniture points target |")
    a("|---|---|---|---|---|---|---|---|---|---|---|")
    for t in d["tiers"]:
        n = tnum(t["id"])
        cells = (t["W"] // 2) * (t["D"] // 2)
        pc = (t["patio"][0] // 2) * (t["patio"][1] // 2)
        sp, fc = ukey(d, "second_pass"), ukey(d, "food_court_pass")
        mw = "1" if n < 4 else (f"2 (`{sp}`)" if n < 6 else f"3 (`{sp}` + `{fc}`)")
        a(f"| {n} | `{t['id']}` | {t['W']}\u00d7{t['D']} | {t['Dk']} / {t['D'] - t['Dk']} | {fmt(cells)}"
          f"{' + ' + fmt(pc) if pc else ''} | {t['max_items']} | {t['wall_sockets']} | {t['curb_sockets']} | {mw} | "
          f"{t['atmos_cap']} | {t['pts_target']} |")
    a("")
    a("#### 36.12.3 Economy Assumptions and Offline Calculation (canon \u00a7C15)")
    a("")
    a("Assumptions per tier **[TUNABLE]**: typical reputation (Stars) and Atmosphere; `PrepSec_avg` (menu-weighted "
      "recipe base prep time, final values come from \u00a76); ingredient cost ratio inside the canon 25\u201340 % band; "
      "player EFFICIENCY stat. The menu-weighted mean item price `P` is **calibrated** so that the online model "
      "reproduces canon \u00a7C4.4 net income: `P = (NetActive / 1.15 + OnlineWages) / (Throughput \u00d7 1.4 \u00d7 "
      "(1 \u2212 ingRatio + 0.10))` (0.10 = average online tip rate, 1.15 = quests/events share). Employee stats use "
      "the middle of the canon \u00a7C4.8 band (Common 30 \u00b7 Uncommon 45 \u00b7 Rare 58 \u00b7 Epic 72 \u00b7 "
      "Legendary 88; wages 18/50/140/400/1,000 MB/h); `Eff = RoleStatAvg \u00d7 (0.6 + 0.4\u00b7Morale) \u00d7 "
      "(0.7 + 0.3\u00b7E_avg) \u00d7 (1 + 0.001\u00b7EFFICIENCY) / 100` with Morale 80 and `E_avg = 1 \u2212 drain "
      "\u00d7 H / 2` (drain 8 %/h, 5 %/h with a Manager). Incidents (\u00b110/15 % caps) and auto-repairs are excluded.")
    a("")
    a("| # | Tier | Stars \u2192 RepMult | Atmosphere \u2192 DecorMult | Online demand / seat cap (cust/h) | "
      "Calibrated mean item price P (MB) | Avg ticket (MB) | PrepSec_avg (s) | Ingredient ratio | Player EFFICIENCY |")
    a("|---|---|---|---|---|---|---|---|---|---|")
    for t in d["tiers"]:
        e = econ[t["id"]]
        n = tnum(t["id"])
        a(f"| {n} | `{t['id']}` | {t['stars']} \u2192 \u00d7{e['rep']:.3f} | {t['atmos']} \u2192 \u00d7{e['dec']:.3f} | "
          f"{fmt(e['demand_on'], 1)} / {fmt(e['seat_cap_on'])} | {fmt(e['P'], 1)} | {fmt(1.4 * e['P'], 1)} | "
          f"{t['prep_sec']} | {t['ing_ratio']:.2f} | {t['player_eff']} |")
    a("")
    a("**Full tier-typical crew (well-staffed):**")
    a("")
    a("| # | Tier | Crew | Cap H | Demand_off | Cap_seat | Cap_kitchen | Cap_service | Q (binding) | q | Revenue | "
      "Tips | Ingredients | Wages | Net / h | % of active | Max per session |")
    a("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for t in d["tiers"]:
        f = econ[t["id"]]["crew_full"]
        n = tnum(t["id"])
        a(f"| {n} | `{t['id']}` | {crew_text(d, t['crew_full'])} | {f['H']} | {fmt(f['dem'], 1)} | {fmt(f['cap_seat'])} | "
          f"{fmt(f['cap_k'], 1)} | {fmt(f['cap_s'], 1)} | {fmt(f['Q'], 1)} ({f['binding']}) | {f['q']:.2f} | "
          f"{fmt(f['rev'])} | {fmt(f['tips'])} | {fmt(f['ingr'])} | {fmt(f['wages'])} | **{fmt(f['net'])}** | "
          f"{round(100 * f['pct'])} % | {fmt(f['session'])} |")
    a("")
    a("**Lean crew (minimum viable):**")
    a("")
    a("| # | Tier | Crew | Cap H | Q (binding) | Revenue | Net / h | % of active | Max per session |")
    a("|---|---|---|---|---|---|---|---|---|")
    for t in d["tiers"]:
        f = econ[t["id"]]["crew_lean"]
        n = tnum(t["id"])
        a(f"| {n} | `{t['id']}` | {crew_text(d, t['crew_lean'])} | {f['H']} | {fmt(f['Q'], 1)} ({f['binding']}) | "
          f"{fmt(f['rev'])} | **{fmt(f['net'])}** | {round(100 * f['pct'])} % | {fmt(f['session'])} |")
    a("")
    pf = [round(100 * econ[t["id"]]["crew_full"]["pct"]) for t in d["tiers"]]
    a(f"**Reading the result.** A well-staffed restaurant returns {min(pf[5:])}\u2013{max(pf[5:])} % of active income per "
      f"offline hour from `TIER_06` (reaching the canon 35\u201350 % band from `TIER_08`) and never approaches the 60 % "
      f"ceiling. `TIER_01`\u2013`TIER_05` land at {min(pf[:5])}\u2013{max(pf[:5])} % because canon quality `q` is capped by "
      "low chef accuracy and, from `TIER_03`, `Cap_service = 80 \u00d7 Eff` per waiter binds while employee caps are "
      "small. This is intentional early pacing (offline is a teaser until the player can staff properly); \u00a717 owns "
      "any retuning.")
    a("")
    a("#### 36.12.4 Restaurant Upgrades")
    a("")
    a("Upgrades are permanent, per-restaurant purchases made in Build Mode \u2192 Upgrades (no edit session needed; "
      "blocked only while In Combat, canon E2). They survive every tier upgrade. Station paths implement canon "
      "\u00a7C4.9 **per station type**: one purchase upgrades every owned instance of that station, including "
      "premium variants and copies bought later, priced from the stock item's Lv1 base price.")
    a("")
    a("**Station path profiles** (canon \u00a7C4.9 as interpreted by \u00a75; multipliers replace the previous level, "
      "the Lv4 bonus is kept at Lv5):")
    a("")
    a("| Profile | Stations | Lv2 Tuned (T2) | Lv3 Pro (T4) | Lv4 Mutant (T6) | Lv5 Ridiculous (T8) |")
    a("|---|---|---|---|---|---|")
    a("| heat | GRILL, FRYER, OVEN, PIZZA_OVEN, STOVE, SOUP_POT, STEAMER, INFUSER, ANTIGRAV | `T_ready` \u00d70.90 | "
      "\u00d70.80, `W_perfect` \u00d71.25 | \u00d70.70, \u00d71.25, burn grace +3 s | \u00d70.60, \u00d71.5, +3 s, gimmick |")
    a("| process | CUT, BLENDER, MIXER, DRINK, ICECREAM, FREEZER | process time \u00d70.90 | \u00d70.80, green zone \u00d71.25 | "
      "\u00d70.70, \u00d71.25, failure chance \u221250 % | \u00d70.60, \u00d71.5, \u221250 %, gimmick |")
    a("| utility | PANTRY, FRIDGE, PREP, ASSEMBLY, PLATING, WINDOW, DISHWASH, TRASH, DELIVERY | channel time \u00d70.90 | "
      "\u00d70.80, timing windows \u00d71.25 | \u00d70.70, \u00d71.25, failure \u221250 % | \u00d70.60, \u00d71.5, \u221250 %, gimmick |")
    a("")
    a("| ID | Name | Category | Effect | Cost (MB) | Req tier / level | Prereq | Notes |")
    a("|---|---|---|---|---|---|---|---|")
    path_total = 0
    other_total = 0
    path_costs = {}
    for u in d["upgrades"]:
        if u["cat"] == "station upgrade path":
            effect, cost, req, costs = station_path(d, u, items)
            path_total += sum(costs)
            path_costs[u["path_station"]] = sum(costs)
            pre = f"owns \u2265 1 `{u['path_station']}`; previous level"
            a(f"| `{u['id']}` | {u['name']} | {u['cat']} | {effect} | {cost} | {req} | {pre} | {pol(u['notes']) or '\u2014'} |")
        else:
            other_total += u["cost"]
            pre = f"`{u['prereq']}`" if u["prereq"] else "\u2014"
            a(f"| `{u['id']}` | {u['name']} | {u['cat']} | {pol(u['effect'])} | {fmt(u['cost'])} | T{u['tier']} / L{u['level']} | "
              f"{pre} | {pol(u['notes']) or '\u2014'} |")
    a("")
    a("#### 36.12.5 Upgrade Economy Summary")
    a("")
    cats = {}
    for u in d["upgrades"]:
        cats[u["cat"]] = cats.get(u["cat"], 0) + 1
    a("| Category | Rows | Notes |")
    a("|---|---|---|")
    for k, v in cats.items():
        a(f"| {k} | {v} | {'cost = canon \u00a7C4.9 multiplier \u00d7 stock FRN price' if k == 'station upgrade path' else 'flat MB'} |")
    a("")
    n_paths = len(path_costs)
    late = path_costs.get("STN_INFUSER", 0) + path_costs.get("STN_ANTIGRAV", 0)
    a(f"Total MB to buy every station level on all {n_paths} paths: **{fmt(path_total)} MB**; all other upgrades: "
      f"**{fmt(other_total)} MB**. For scale, the canon tier costs sum to {fmt(sum(t['cost'] for t in d['tiers']))} MB. "
      "Upgrades sit in the \"~50 % to mutations, furniture, staff and upgrades\" half of canon \u00a7C4.4, and are "
      f"deliberately optional: the Infuser and Anti-Gravity Wok paths alone are {round(100 * late / path_total)} % of the "
      "station-path total, and no recipe requires any level above Lv1.")
    a("")
    return "\n".join(L) + "\n"


# ----------------------------------------------------------------------------- 36.13
def render_36_13(d, items_by_id):
    L = []
    a = L.append
    groups = d["groups"]
    n_items = sum(len(g["items"]) for g in groups)
    sets = d["sets"]
    a("### 36.13 Furniture and Equipment Catalog")
    a("")
    a("> Generated by `python3 gdd/tools/render_restaurant.py` from `gdd/data/furniture.json` (owner A10). "
      f"**{n_items} purchasable items** (`FRN_001`\u2013`FRN_899` range) plus the **10 canon trophy decorations** "
      "(`FRN_901`\u2013`FRN_910`, not purchasable). Prices, atmosphere points and durability are **[TUNABLE]**.")
    a("")
    a("**Column legend.** *Station* = canon station type if the item is a kitchen appliance or utility fixture. "
      "*Req tier* `T3` = needs `TIER_03` or higher (stations also need their canon unlock level, shown in notes). "
      "*Price* = Morph Bucks at Restaurant Supplies (`BLD_03`, kitchen items) or Monster Mall (`BLD_12`, everything "
      "else); once an item has been seen in its shop it can be re-bought from the Build Mode catalog. The **price of "
      "a station's stock item is that station's Lv1 base price** used by canon \u00a7C4.9 upgrade multipliers "
      "(\u00a736.12). *Footprint* in studs (W\u00d7D on the 2-stud grid; `wall N` = N studs of wall socket; "
      "`ceiling` items use the ceiling layer and never block floor cells; `zone` = whole-zone finish). "
      "*Atmosphere pts* feed the \u00a715.6 formula. *Durability* = max durability points (\u2014 = indestructible); "
      "damage states are percentages of it (Pristine 100\u201376 \u00b7 Scuffed 75\u201351 \u00b7 Cracked 50\u201326 "
      "\u00b7 Broken 25\u20131 \u00b7 Destroyed 0, canon \u00a7C6) and repair costs are a share of *Price* "
      "(\u00a715.9: 4 % / 8 % / 15 % / 25 % rebuild).")
    a("")
    a("**Default placement zones by category** (K Kitchen \u00b7 D Dining \u00b7 L Lobby/showcase \u00b7 "
      "O Outside patio \u00b7 C Curb on the Restaurant Row plot \u00b7 W wall socket \u00b7 Ce ceiling):")
    a("")
    a("| Category | Zones | Blocks floor cells | Notes |")
    a("|---|---|---|---|")
    zone_rows = [
        ("Appliance", "K", "yes", "uses 1 appliance slot (canon \u00a7C6 list)"),
        ("Utility fixture", "K (window on divider, dock at back door)", "yes", "no appliance slot; some are Essential (cannot store the last one)"),
        ("Table / Counter", "D (patio tables: O)", "yes", "surfaces; chairs attach to them"),
        ("Chair / Booth", "D (Outside-rated chairs: O)", "yes", "only source of seats; total \u2264 tier Seats"),
        ("Lighting", "Ce, W or floor (D, L, O)", "floor lamps only", "coverage radius r"),
        ("Flooring / Wall finish", "one per zone", "no", "indestructible"),
        ("Window / Door", "W / door sockets", "no", "Broken doors never block paths"),
        ("Sign", "W, D, L or C", "floor signs only", "curb signs indestructible"),
        ("Plant / Sculpture / Accessory", "D, L, O (some C)", "yes (rugs no)", ""),
        ("Aquarium", "D, L", "yes", "glass: Shatterproof applies"),
        ("Interactive", "D, L (wall items W)", "yes", "per-item max counts in notes"),
        ("Security / Safety", "any incl. K", "floor items only", "auras never stack"),
        ("Patio", "O (curb items C)", "yes", "curb items indestructible"),
        ("Trophy", "D, L, W", "yes", "indestructible, unsellable"),
    ]
    for r in zone_rows:
        a("| " + " | ".join(r) + " |")
    a("")
    a("**Price bands** (canon \u00a7C4.4 income per active hour in brackets): T1 25\u2013750 (630) \u00b7 T2 140\u20131,400 "
      "(1,080) \u00b7 T3 200\u20132,400 (1,730) \u00b7 T4 450\u20132,500 (3,100) \u00b7 T5 1,800\u201312,000 (5,400) \u00b7 "
      "T6 1,500\u201324,000 (9,600) \u00b7 T7 3,600\u201360,000 (17,400) \u00b7 T8 7,500\u2013110,000 (32,800) \u00b7 "
      "T9 16,000\u201375,000 (63,700) \u00b7 T10 120,000\u2013300,000 (120,500). Rule of thumb: everyday pieces cost "
      "\u2248 0.05\u20130.3 h of tier income, set signatures 0.5\u20132 h, showpieces 2\u20135 h.")
    a("")
    head = ("| ID | Name | Category | Station | Req tier | Price (MB) | Footprint (studs) | Seats / capacity | "
            "Atmosphere pts | Durability | Theme / set | Interactive / notes |")
    sep = "|---|---|---|---|---|---|---|---|---|---|---|---|"

    def row(it):
        iid, name, cat, stn, tier, price, foot, cap, atm, dur, st, notes = it
        stn_s = f"`{stn}`" if stn else "\u2014"
        tier_s = f"T{tier}" if tier else "\u2014"
        price_s = fmt(price) if price is not None else "\u2014 (not sold)"
        set_s = sets[st]["name"] if st else "\u2014"
        return (f"| `{iid}` | {name} | {cat} | {stn_s} | {tier_s} | {price_s} | {fp(foot)} | {pol(cap)} | {atm} | "
                f"{fmt(dur) if dur is not None else '\u2014'} | {set_s} | {pol(notes) or '\u2014'} |")

    for gi, g in enumerate(groups, 1):
        a(f"#### 36.13.{gi} {g['title']}")
        a("")
        a(head)
        a(sep)
        for it in g["items"]:
            a(row(it))
        a("")
    k = len(groups) + 1
    a(f"#### 36.13.{k} Trophy Decorations (canon \u00a7C16.6 \u2014 not purchasable)")
    a("")
    a("Trophies are granted only by quests, story chapters and events (canon \u00a7C17.4 reward vocabulary). They are "
      "indestructible, cannot be sold or traded, may be stored and re-placed freely, never count against the tier's "
      "Max placed items, and gain +20 % atmosphere on a Trophy Shelf (`FRN_397`).")
    a("")
    a(head)
    a(sep)
    for it in d["trophies"]:
        a(row(it))
    a("")
    k += 1
    a(f"#### 36.13.{k} Theme Sets")
    a("")
    a("A set counts **distinct** member items that are placed and Pristine or Scuffed (Cracked or worse do not count "
      "until repaired). 3\u20135 pieces = *partial* (+3 atmosphere); \u2265 6 pieces = *complete* (first complete set +10, "
      "each further complete set +5; total theme term capped at 15, \u00a715.6). Completing a set indoors unlocks its "
      f"fa\u00e7ade skin with `{ukey(d, 'facelift')}`. Robux theme packs (\u00a723) are re-skins of these earnable items with identical "
      "stats and never add atmosphere.")
    a("")
    a("| Set | Unlock tier | Vibe | Pieces | Members |")
    a("|---|---|---|---|---|")
    members = {}
    for g in groups:
        for it in g["items"]:
            if it[10]:
                members.setdefault(it[10], []).append(it[0])
    for key, s in sets.items():
        m = members.get(key, [])
        a(f"| {s['name']} | T{s['tier']} | {s['vibe']} | {len(m)} | " + ", ".join(f"`{x}`" for x in m) + " |")
    a("")
    k += 1
    a(f"#### 36.13.{k} Station Coverage")
    a("")
    a("Every canon station has a stock item (its Lv1 base price) and, for most, premium variants that share the "
      "station type's upgrade level. Premium variants never change processing speed (that is canon \u00a7C4.9 and "
      "\u00a75); they add durability, atmosphere, theme-set membership, cosmetic gimmicks and sometimes built-in fire "
      "resistance.")
    a("")
    a("| Station | Canon ID | Uses appliance slot | Stock item (base price) | Premium variants | Upgrade path |")
    a("|---|---|---|---|---|---|")
    stock = {}
    prem = {}
    for g in groups:
        for it in g["items"]:
            if it[3]:
                if g["key"] == "kitchen_stock":
                    stock[it[3]] = it
                else:
                    prem.setdefault(it[3], []).append(it[0])
    path_of = {u["path_station"]: u["id"] for u in d["upgrades"] if u.get("path_station")}
    for stn in CANON_STATIONS:
        s = stock.get(stn)
        stock_s = f"`{s[0]}` {s[1]} ({fmt(s[5])} MB)" if s else "MISSING"
        a(f"| {s[1] if s else stn} | `{stn}` | {'yes' if stn in SLOT_STATIONS else 'no'} | {stock_s} | "
          + (", ".join(f"`{x}`" for x in prem.get(stn, [])) or "\u2014") + " | "
          + (f"`{path_of[stn]}`" if stn in path_of else "utility upgrades only (\u00a736.12)") + " |")
    a("")
    k += 1
    a(f"#### 36.13.{k} Catalog Counts")
    a("")
    a("| Group | Items |")
    a("|---|---|")
    for g in groups:
        a(f"| {g['title']} | {len(g['items'])} |")
    a(f"| **Purchasable total** | **{n_items}** |")
    a(f"| Trophy decorations (not purchasable) | {len(d['trophies'])} |")
    a("")
    return "\n".join(L) + "\n"


# ----------------------------------------------------------------------------- section 15 AUTO blocks
def block_tier_summary(d, econ):
    L = ["| # | Tier | Cost (MB) | Level | Permit | Interior W\u00d7D (sq studs) | Patio | Seats | Appliance slots "
         "| Kitchen area | Menu | Staff cap | Base demand | Online throughput | Offline net/h lean\u2013full | Max offline session |",
         "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for t in d["tiers"]:
        e = econ[t["id"]]
        n = tnum(t["id"])
        f = e["crew_full"]
        patio = f"{t['patio'][0]}\u00d7{t['patio'][1]}" if t["patio"][0] else "\u2014"
        L.append(f"| {n} | `{t['id']}` {t['name']} | {fmt(t['cost'])} | {t['level']} | {'yes' if t['permit'] else 'no'} | "
                 f"{t['W']}\u00d7{t['D']} ({fmt(t['W'] * t['D'])}) | {patio} | {t['seats']} | {t['slots']} | "
                 f"{t['W']}\u00d7{t['Dk']} | {t['menu']} | {t['emp']} | {t['demand']} | \u2248 {fmt(e['thr'])}/h | "
                 f"{fmt(e['crew_lean']['net'])}\u2013{fmt(f['net'])} | {fmt(f['session'])} ({f['H']} h) |")
    return "\n".join(L)


def block_offline_calc(d, econ):
    L = ["| # | Full crew | Demand_off = Base \u00d7 Rep \u00d7 Decor \u00d7 0.6 | min(Cap_seat, Cap_kitchen, Cap_service) | "
         "Q | Revenue = Q \u00d7 1.4P \u00d7 q | + Tips \u2212 Ingredients \u2212 Wages | Net / h (% of active) |",
         "|---|---|---|---|---|---|---|---|"]
    for t in d["tiers"]:
        e = econ[t["id"]]
        f = e["crew_full"]
        n = tnum(t["id"])
        L.append(f"| {n} | {crew_text(d, t['crew_full'])} | {t['demand']} \u00d7 {e['rep']:.3f} \u00d7 {e['dec']:.3f} \u00d7 0.6 "
                 f"= {fmt(f['dem'], 1)} | {fmt(f['cap_seat'])}, {fmt(f['cap_k'], 1)}, {fmt(f['cap_s'], 1)} | "
                 f"{fmt(f['Q'], 1)} | {fmt(f['Q'], 1)} \u00d7 {fmt(f['ticket'], 1)} \u00d7 {f['q']:.2f} = {fmt(f['rev'])} | "
                 f"+{fmt(f['tips'])} \u2212{fmt(f['ingr'])} \u2212{fmt(f['wages'])} | **{fmt(f['net'])}** "
                 f"({round(100 * f['pct'])} %) |")
    return "\n".join(L)


def refresh_blocks(path, blocks):
    if not os.path.exists(path):
        return False
    with open(path, encoding="utf-8") as fh:
        txt = fh.read()
    changed = txt
    for key, body in blocks.items():
        pat = re.compile(r"(<!-- AUTO:render_restaurant:%s BEGIN -->\n)(.*?)(\n<!-- AUTO:render_restaurant:%s END -->)"
                         % (re.escape(key), re.escape(key)), re.S)
        if not pat.search(changed):
            err(f"section 15 is missing AUTO block '{key}'")
            continue
        changed = pat.sub(lambda m: m.group(1) + body + m.group(3), changed)
    if changed != txt:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(changed)
    return True


# ----------------------------------------------------------------------------- validation
def validate(d):
    items = {}
    for g in d["groups"]:
        for it in g["items"]:
            if len(it) != 12:
                err(f"{it[0]} has {len(it)} columns")
            if it[0] in items:
                err(f"duplicate {it[0]}")
            if not re.fullmatch(r"FRN_\d{3}", it[0]) or not (1 <= int(it[0][4:]) <= 899):
                err(f"bad purchasable id {it[0]}")
            if it[5] is None or it[5] <= 0:
                err(f"{it[0]} purchasable item without price")
            if not (1 <= it[4] <= 10):
                err(f"{it[0]} tier out of range")
            if it[3] and it[3] not in CANON_STATIONS:
                err(f"{it[0]} unknown station {it[3]}")
            if it[10] and it[10] not in d["sets"]:
                err(f"{it[0]} unknown set {it[10]}")
            items[it[0]] = it
    for it in d["trophies"]:
        if TROPHY_NAMES.get(it[0]) != it[1]:
            err(f"trophy {it[0]} name mismatch with canon")
        items[it[0]] = it
    if sorted(TROPHY_NAMES) != sorted(i[0] for i in d["trophies"]):
        err("trophy list must be exactly FRN_901-FRN_910")
    stock = {it[3] for it in d["groups"][0]["items"]}
    for s in CANON_STATIONS:
        if s not in stock:
            err(f"no stock item for {s}")
    for key in d["sets"]:
        cnt = sum(1 for g in d["groups"] for it in g["items"] if it[10] == key)
        if cnt < 6:
            err(f"set {key} has only {cnt} members")
    seen = set()
    for i, u in enumerate(d["upgrades"], 1):
        if u["id"] != f"UPG_{i:03d}":
            err(f"upgrade numbering gap at {u['id']}")
        if u["id"] in seen:
            err(f"duplicate {u['id']}")
        seen.add(u["id"])
        if u.get("path_station"):
            b = items.get(u["base_item"])
            if not b or b[3] != u["path_station"]:
                err(f"{u['id']} base item mismatch")
        elif u["prereq"] and u["prereq"] not in seen:
            err(f"{u['id']} prereq {u['prereq']} not defined earlier")
    if len([t for t in d["tiers"]]) != 10:
        err("need 10 tiers")
    return items


def main():
    with open(DATA, encoding="utf-8") as fh:
        d = json.load(fh)
    items = validate(d)
    econ = {t["id"]: tier_econ(d, t) for t in d["tiers"]}
    os.makedirs(SEC, exist_ok=True)
    with open(OUT_12, "w", encoding="utf-8") as fh:
        fh.write(render_36_12(d, econ, items))
    with open(OUT_13, "w", encoding="utf-8") as fh:
        fh.write(render_36_13(d, items))
    had15 = refresh_blocks(SEC_15, {"tier-summary": block_tier_summary(d, econ),
                                    "offline-calc": block_offline_calc(d, econ)})
    n_items = sum(len(g["items"]) for g in d["groups"])
    print(f"render_restaurant: {n_items} purchasable FRN + {len(d['trophies'])} trophies, "
          f"{len(d['upgrades'])} UPG, {len(d['tiers'])} tiers; section 15 blocks "
          f"{'refreshed' if had15 else 'skipped (file missing)'}")
    for t in d["tiers"]:
        f = econ[t["id"]]["crew_full"]
        print(f"  {t['id']}: thr {econ[t['id']]['thr']:.0f}/h, P {econ[t['id']]['P']:.1f}, offline full {f['net']:.0f}/h "
              f"({100 * f['pct']:.0f} %), lean {econ[t['id']]['crew_lean']['net']:.0f}/h, cap {f['H']} h")
    if ERRORS:
        print("VALIDATION ERRORS:")
        for e in ERRORS:
            print("  -", e)
        sys.exit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Render the Mutation Parts Database (§36.3) and the computed tables of §12 from gdd/data/mutations.json.

Owner: A7 Mutations. Python 3 stdlib only. Idempotent. Run from the repo root:

    python3 gdd/tools/render_mutations.py            # validate + render
    python3 gdd/tools/render_mutations.py --check    # validate only (no files written)

What it validates (exit code 1 on any error):
  * canon fidelity: the 280 parts, and for each part its ID, name, slot, category, rarity, family, tags and
    active ability exactly as gdd/canon.md §C13.6 (parsed from canon, never hard-coded);
  * stat budgets: sum of Lv1 stat points == round_half_up(BaseBudget[rarity] × SlotWeight[slot]) (canon §C13.4,
    parsed); FX parts carry no stats; only the 9 canon stats; positive integers;
  * enums: acquisition codes (§C13.8), passive effect keys (documented in §12.8), motion types, size classes;
  * economy: SHOP prices inside the canon §C4.5 range for the rarity; Mythic/Secret never sold; max level = §C4.6;
    equip level = §C13.3 default; Secret parts use exactly the canon §C13.8 discovery condition; STARTER only on the
    canon starter parts; the tutorial choice parts are the three canon parts;
  * rig contract: attachment names exist in canon §C13.7; LegLength on every LEG part (1.4–3.0), NeckLength on
    every NECK part (0–2.5); faceLocked only on HEAD, handsLocked only on ARM, blocksWings only on BACK;
    triangle and MeshPart counts within the per-slot budgets of §12.3;
  * references: every identifier token in the data and in the rendered/owned markdown exists in canon or is a MUT_
    part; SYN_/CMB_ identifiers are never used (owned by §12.9–12.10 / §36.4–36.5).

What it writes:
  * gdd/sections/36_03_mutation_parts.md (whole file);
  * the regions between `<!-- BEGIN GENERATED: <key> -->` and `<!-- END GENERATED: <key> -->` inside
    gdd/sections/12_mutation_system.md (budget growth, upgrade costs, prices, counts, combination maths, passive caps).
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANON = ROOT / "gdd" / "canon.md"
DATA = ROOT / "gdd" / "data" / "mutations.json"
OUT_DB = ROOT / "gdd" / "sections" / "36_03_mutation_parts.md"
OUT_SYS = ROOT / "gdd" / "sections" / "12_mutation_system.md"

RARITIES = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"]
STATS = ["COOK_SPD", "COOK_QLT", "STR", "DEF", "REPAIR", "MOVE", "LUCK", "CHARM", "EFFICIENCY"]
SLOT_ORDER = ["HEAD", "FACE", "NOSE", "MOUTH", "EYES", "EARS", "HORNS", "NECK", "TORSO", "ARM", "HANDS", "LEG",
              "FEET", "TAIL", "WINGS", "BACK", "SKIN", "FUR", "SCALES", "FX"]
SLOT_TITLE = {
    "HEAD": "Heads", "FACE": "Faces", "NOSE": "Noses", "MOUTH": "Mouths", "EYES": "Eyes", "EARS": "Ears",
    "HORNS": "Horns & crests", "NECK": "Necks", "TORSO": "Torsos", "ARM": "Arms (fit ARM_L or ARM_R)",
    "HANDS": "Hands", "LEG": "Legs (fit LEG_L or LEG_R)", "FEET": "Feet", "TAIL": "Tails", "WINGS": "Wings",
    "BACK": "Back attachments", "SKIN": "Skins (surface)", "FUR": "Furs (covering)", "SCALES": "Scales (covering)",
    "FX": "Special effects (cosmetic)",
}
UI_GROUP = {"HEAD": "Head", "FACE": "Head", "NOSE": "Head", "MOUTH": "Head", "EARS": "Ears", "HORNS": "Ears",
            "EYES": "Eyes", "ARM": "Arms", "HANDS": "Arms", "LEG": "Legs", "FEET": "Legs", "TAIL": "Tails"}
RARITY_ICON = {"Common": "●", "Uncommon": "▲", "Rare": "■", "Epic": "⬟", "Legendary": "★", "Mythic": "⬢", "Secret": "?"}
ACQ_CODES = ["STARTER", "SHOP_MART", "SHOP_ROTATION", "LAB_FUSION", "CAPSULE", "QUEST", "EVENT", "ARENA",
             "OFFLINE_FIND", "ACHIEVEMENT", "SECRET"]
MOTIONS = ["none", "spring", "spring_chain", "flap", "hover", "orbit", "particles", "screen_emote", "wheel",
           "jiggle", "sway", "flicker", "rotor"]
MOTION_TEXT = {"spring": "spring bones", "spring_chain": "spring chain", "flap": "flap joints", "hover": "hover bob",
               "orbit": "orbit", "particles": "particles", "screen_emote": "screen-emote", "wheel": "wheel spin",
               "jiggle": "jiggle", "sway": "sway", "flicker": "flicker", "rotor": "rotor spin"}
SIZES = ["tiny", "normal", "huge"]

# Per-slot asset budgets (§12.3). Player Hi LOD tris, NPC Lo LOD tris, max MeshParts per part.
TRI_HI = {"HEAD": 1500, "FACE": 300, "NOSE": 250, "MOUTH": 350, "EYES": 300, "EARS": 400, "HORNS": 400, "NECK": 500,
          "TORSO": 2000, "ARM": 1100, "HANDS": 600, "LEG": 1000, "FEET": 500, "TAIL": 900, "WINGS": 1200, "BACK": 900,
          "SKIN": 0, "FUR": 500, "SCALES": 500, "FX": 200}
TRI_LO = {"HEAD": 600, "FACE": 100, "NOSE": 80, "MOUTH": 120, "EYES": 100, "EARS": 150, "HORNS": 150, "NECK": 180,
          "TORSO": 800, "ARM": 400, "HANDS": 150, "LEG": 350, "FEET": 150, "TAIL": 350, "WINGS": 450, "BACK": 320,
          "SKIN": 0, "FUR": 0, "SCALES": 0, "FX": 0}
MESH_MAX = {"HEAD": 3, "FACE": 1, "NOSE": 1, "MOUTH": 1, "EYES": 2, "EARS": 2, "HORNS": 2, "NECK": 1, "TORSO": 2,
            "ARM": 3, "HANDS": 2, "LEG": 2, "FEET": 2, "TAIL": 1, "WINGS": 2, "BACK": 3, "SKIN": 0, "FUR": 3,
            "SCALES": 3, "FX": 1}

# Passive effect vocabulary (§12.8). key -> (group, what it does, combined cap / stacking rule) [TUNABLE caps]
PASSIVE_KEYS: "OrderedDict[str, tuple[str, str, str]]" = OrderedDict([
    ("station_speed", ("Cooking", "Process/action time −X % at named stations, tagged ingredients or recipe categories", "−25 % per station (multiplies with COOK_SPD and station level)")),
    ("perfect_window", ("Cooking", "Perfect window +X s", "+0.8 s per station")),
    ("burn_grace", ("Cooking", "Burn delay +X s", "+2.0 s per station")),
    ("chop", ("Cooking", "Fewer chop taps", "−2 taps; minimum 2 taps; timing ring always kept")),
    ("ingredient_save", ("Cooking", "Chance an ingredient is not consumed / cost refunded", "15 %")),
    ("dish_quality", ("Cooking", "+Food Quality on matching dishes, Golden-dish chance", "+0.10 Q (Q ≤ 1.00)")),
    ("plating", ("Cooking", "Plating & garnish time", "−40 % time")),
    ("cleanup", ("Cooking", "Trash / spill / debris cleaning speed or auto-clean", "−40 % time; auto-clean interval ≥ 2 s")),
    ("fire_safety", ("Cooking", "Station-fire extinguish speed / range", "−60 % extinguish time")),
    ("service_speed", ("Service", "Order-taking and hand-off time", "−40 % time")),
    ("patience", ("Service", "Customer patience +X % (after CHARM)", "+25 %")),
    ("tip_bonus", ("Service", "Tips × (1 + X)", "+30 %")),
    ("satisfaction", ("Service", "+N satisfaction on serve", "shares the MutationBonus cap of +10 (§10)")),
    ("reputation", ("Service", "Reputation gain multiplier", "+50 %")),
    ("anger_resist", ("Service", "Anger gain / escalation-roll multiplier", "combined multiplier floor ×0.70")),
    ("calm_bonus", ("Service", "Calm Down! range/cooldown/targets; passive anger removal", "range +3 studs; cooldown −20 %; +1 target; 1 removal per customer per 30 s")),
    ("reveal", ("Service", "Information & telegraphs (UI only)", "binary; telegraph leads never stack (longest wins)")),
    ("employee_boost", ("Service", "Efficiency of nearby employees", "+10 %; online only")),
    ("damage_bonus", ("Combat", "+X % damage (often conditional)", "+30 % combined, applied before STR")),
    ("attack_speed", ("Combat", "Swipe Combo hit interval", "−10 %")),
    ("cleave", ("Combat", "Extra targets on a hit", "+1 target")),
    ("damage_reduction", ("Combat", "−X % damage taken (typed or directional)", "35 % combined, applied before DEF")),
    ("knockback_resist", ("Combat", "Knockback received −X %", "60 %; immunity only from conditional parts")),
    ("knockback_bonus", ("Combat", "Knockback dealt +X %", "+40 %")),
    ("throw_power", ("Combat", "Grab & Throw range / damage / knockback", "+30 %")),
    ("on_hit_status", ("Combat", "Status applied on hit (chance or conditional)", "max 2 proc sources active; each ICD ≥ 4 s")),
    ("thorns", ("Combat", "Damage or status returned to melee attackers", "8 damage per hit; ICD ≥ 1.5 s; status thorns use an on-hit proc slot")),
    ("status_resist", ("Combat", "Status duration −X % or immunity", "−60 % per status; immunity only where listed")),
    ("guard", ("Combat", "Block guard meter / block reduction", "+20 guard; block reduction ≤ 80 %")),
    ("dodge", ("Combat", "Dodge cooldown / i-frames / distance; projectile miss", "cooldown ≥ 0.9 s; i-frames ≤ 0.40 s; distance +25 %; miss 25 %")),
    ("regen", ("Combat", "HP regeneration", "3 HP/s combined")),
    ("max_hp", ("Combat", "+max HP", "+60")),
    ("revive", ("Combat", "KO prevention / faster KO recovery", "one trigger per KO; 180 s shared cooldown; off in ranked Arena")),
    ("aggro", ("Combat", "Targeting priority / stealth", "binary")),
    ("aura", ("Combat", "Area effect on hostile customers", "same-type auras never stack (strongest wins)")),
    ("repair_speed", ("Repair", "Repair speed +X %", "+40 % (multiplies with REPAIR)")),
    ("repair_cost", ("Repair", "Repair material cost −X %", "−15 % (≤ −40 % together with REPAIR)")),
    ("sprint", ("Movement", "+MOVE while running or under a condition", "+8 MOVE; MOVE cap 100; WalkSpeed ≤ 20.8")),
    ("jump", ("Movement", "Jump height / extra jump", "+40 % height; max 1 extra jump")),
    ("glide", ("Movement", "Fall-speed reduction, glide, apex hover", "−60 % fall speed; no sustained flight")),
    ("swim", ("Movement", "Sewer-water speed / soaked penalty", "+30 %")),
    ("move_terrain", ("Movement", "Immunity to floor slowdowns (spills, sticky, greasy)", "binary per terrain")),
    ("reach", ("Movement", "+studs interaction or pickup range", "+2 studs stations/customers; +4 studs pickup; server re-validates")),
    ("grip", ("Movement", "Keep carried item when knocked back", "100 %; KO always drops")),
    ("carry", ("Movement", "+1 carry capacity", "hard max 3 items (§12.8)")),
    ("drop_luck", ("Luck", "Rare-drop weight / finds", "+30 %; never changes Morph Capsule odds")),
    ("jackpot", ("Luck", "Jackpot Tip chance +pp", "+2.0 pp")),
    ("cosmetic", ("Cosmetic", "FX flavor only", "no stats, no gameplay effect")),
])

ID_RE = re.compile(r"(?<![A-Za-z0-9_])(?:RCP|ING|MOD|STN|PER|ABL|STS|MUT|SYN|CMB|SKL|ACH|MLS|TIER|FRN|UPG|ROLE|EMP|INC|DST|BLD|NPC|QST|EVT|ANM|SFX|MUS)_[A-Z0-9]+(?:_[A-Z0-9]+)*(?![A-Za-z0-9_])")


def rhu(x: float) -> int:
    """Round half up (canon rounding for budgets and costs)."""
    return int(math.floor(x + 0.5))


def fmt(n: int) -> str:
    return f"{n:,}"


def num(s: str) -> int:
    return int(s.replace(",", "").strip())


# ----------------------------------------------------------------------------- canon parsing
class Canon:
    def __init__(self, text: str):
        self.text = text
        self.errors: list[str] = []
        self.parts = self._parts()
        self.base_budget, self.slot_weight = self._budgets()
        self.price, self.extra = self._prices()
        self.upg = self._upgrades()
        self.equip = self._equip()
        self.abilities = self._abilities()
        self.secrets = self._secrets()
        self.odds = self._odds()
        self.attachments = self._attachments()
        self.ids = set(ID_RE.findall(text))

    def _section(self, start: str, end: str) -> str:
        i = self.text.find(start)
        j = self.text.find(end, i + 1)
        if i < 0 or j < 0:
            self.errors.append(f"canon: cannot find section {start!r}")
            return ""
        return self.text[i:j]

    def _parts(self):
        sec = self._section("### C13.6", "### C13.7")
        rows = re.findall(r"^\| `(MUT_\d{3})` \| ([^|]+?) \| (\w+) \| (\w+) \| (\w+) \| (\w+) \| ([^|]+?) \| ([^|]+?) \|$", sec, re.M)
        parts = OrderedDict()
        for pid, name, slot, cat, rar, fam, tags, act in rows:
            act = act.strip().strip("`")
            parts[pid] = dict(name=name.strip(), slot=slot, category=cat, rarity=rar, family=fam,
                              tags=[t.strip() for t in tags.split(",")], active=None if act == "—" else act)
        if len(parts) != 280:
            self.errors.append(f"canon: expected 280 mutation rows in §C13.6, parsed {len(parts)}")
        return parts

    def _budgets(self):
        sec = self._section("### C13.4", "### C13.5")
        m = re.search(r"^\| BaseBudget \|(.+)\|$", sec, re.M)
        base = {}
        if m:
            vals = [v.strip() for v in m.group(1).split("|")]
            base = {r: int(v) for r, v in zip(RARITIES, vals)}
        weight = {}
        for w, slots in re.findall(r"^\| (\d\.\d) \([A-Za-z]+\) \| (.+) \|$", sec, re.M):
            for tok in re.findall(r"\b[A-Z]{2,}\b", slots):
                weight[tok] = float(w)
        if len(base) != 7 or not {"HEAD", "LEG", "FX", "ARM"} <= set(weight):
            self.errors.append("canon: could not parse §C13.4 budgets")
        return base, weight

    def _prices(self):
        sec = self._section("### C4.5", "### C4.6")
        price, extra = {}, {}
        for r in RARITIES:
            m = re.search(rf"^\| {r} \| ([^|]+) \| ([^|]+) \|", sec, re.M)
            if not m:
                self.errors.append(f"canon: §C4.5 row for {r} missing")
                continue
            rng = re.match(r"\s*([\d,]+)\s*–\s*([\d,]+)", m.group(1))
            price[r] = (num(rng.group(1)), num(rng.group(2))) if rng else None
            extra[r] = m.group(2).strip()
        return price, extra

    def _upgrades(self):
        sec = self._section("### C4.6", "### C4.7")
        upg = {}
        for r in RARITIES:
            m = re.search(rf"^\| {r} \| (\d+) \| ([\d,]+) \| (\d+) \| ([^|]+) \| ([^|]+) \|$", sec, re.M)
            if not m:
                self.errors.append(f"canon: §C4.6 row for {r} missing")
                continue
            rt = m.group(4).strip()
            conv = m.group(5).strip()
            sub = int(re.findall(r"(\d[\d,]*)\s*$", conv)[0].replace(",", ""))
            dup = re.match(r"\s*(\d+)\s*/", conv)
            upg[r] = dict(max=int(m.group(1)), mb=num(m.group(2)), ms=int(m.group(3)),
                          rt=0 if rt == "—" else int(rt), conv=int(dup.group(1)) if dup else None, sub=sub)
        return upg

    def _equip(self):
        sec = self._section("### C13.3", "### C13.4")
        eq = {}
        for r in RARITIES:
            m = re.search(rf"^\| {r} \| [^|]+ \| [^|]+ \| ([^|]+) \|$", sec, re.M)
            if m:
                v = m.group(1).strip()
                eq[r] = int(v) if v.isdigit() else None
        return eq

    def _abilities(self):
        sec = self._section("### C12.2", "### C12.3")
        return {a: n.strip() for a, n in re.findall(r"^\| `(ABL_\d{3})` \| ([^|]+) \|", sec, re.M)}

    def _secrets(self):
        sec = self._section("### C13.8", "**Tutorial first mutation**")
        return {pid: cond.strip() for pid, cond in re.findall(r"^\| `(MUT_\d{3})` [^|]+\| (.+?) \|$", sec, re.M)}

    def _odds(self):
        sec = self._section("### C4.7", "### C4.8")
        return {r: m for r, m in re.findall(r"(Common|Uncommon|Rare|Epic|Legendary|Mythic|Secret) ([\d.]+ %)", sec)}

    def _attachments(self):
        sec = self._section("### C13.7", "### C13.8")
        names = set(re.findall(r"`(MMR_[A-Za-z_]+)`", sec))
        return names

    def starter_parts(self):
        m = re.search(r"\*\*Default starter morph\*\*(.+?)all `STARTER` acquisition", self.text, re.S)
        return set(re.findall(r"MUT_\d{3}", m.group(1))) if m else set()

    def tutorial_parts(self):
        m = re.search(r"\*\*Tutorial first mutation\*\*(.+?)regardless of rarity requirement", self.text, re.S)
        return set(re.findall(r"MUT_\d{3}", m.group(1))) if m else set()


# ----------------------------------------------------------------------------- validation
def budget(canon: Canon, rarity: str, slot: str, level: int = 1) -> int:
    return rhu(canon.base_budget[rarity] * canon.slot_weight[slot] * (1 + 0.12 * (level - 1)))


def validate(canon: Canon, parts: list[dict]) -> list[str]:
    err = list(canon.errors)
    ids = [p.get("id") for p in parts]
    if len(parts) != 280:
        err.append(f"data: expected 280 parts, found {len(parts)}")
    dup = [k for k, v in Counter(ids).items() if v > 1]
    if dup:
        err.append(f"data: duplicate IDs {dup}")
    missing = set(canon.parts) - set(ids)
    extra = set(ids) - set(canon.parts)
    if missing:
        err.append(f"data: canon parts missing from data: {sorted(missing)}")
    if extra:
        err.append(f"data: non-canon IDs in data: {sorted(extra)}")
    starters = canon.starter_parts()
    tutorial = canon.tutorial_parts()
    if len(starters) != 10 or len(tutorial) != 3:
        err.append(f"canon: starter/tutorial parse failed ({len(starters)}, {len(tutorial)})")
    for p in parts:
        pid = p.get("id")
        c = canon.parts.get(pid)
        if not c:
            continue
        where = f"{pid}"
        for k in ("name", "slot", "category", "rarity", "family", "tags", "active"):
            if p.get(k) != c[k]:
                err.append(f"{where}: {k} {p.get(k)!r} != canon {c[k]!r}")
        r, slot = c["rarity"], c["slot"]
        # stats
        st = p.get("stats", {})
        bad = [k for k in st if k not in STATS]
        if bad:
            err.append(f"{where}: unknown stats {bad}")
        if any((not isinstance(v, int)) or v <= 0 for v in st.values()):
            err.append(f"{where}: stat values must be positive integers")
        want = budget(canon, r, slot)
        if sum(st.values()) != want:
            err.append(f"{where}: Lv1 stat sum {sum(st.values())} != budget {want} ({r} × {slot})")
        if slot == "FX" and st:
            err.append(f"{where}: FX parts carry no stats")
        # level / equip
        if p.get("maxLevel") != canon.upg[r]["max"]:
            err.append(f"{where}: maxLevel {p.get('maxLevel')} != canon {canon.upg[r]['max']}")
        if p["unlock"].get("equipLevel") != canon.equip.get(r):
            err.append(f"{where}: equipLevel {p['unlock'].get('equipLevel')} != canon default {canon.equip.get(r)}")
        # passive
        pk = p.get("passive", {}).get("key")
        if pk not in PASSIVE_KEYS:
            err.append(f"{where}: passive key {pk!r} not in vocabulary")
        if (slot == "FX") != (pk == "cosmetic"):
            err.append(f"{where}: FX parts (and only FX parts) use the cosmetic passive")
        if not p.get("passive", {}).get("name") or not p.get("passive", {}).get("text"):
            err.append(f"{where}: passive name/text missing")
        if p.get("active") and p["active"] not in canon.abilities:
            err.append(f"{where}: active {p['active']} not in canon §C12.2")
        # acquisition
        acq = p.get("acquisition", [])
        codes = [a.get("code") for a in acq]
        for cd in codes:
            if cd not in ACQ_CODES:
                err.append(f"{where}: unknown acquisition code {cd}")
        if r == "Secret":
            if codes != ["SECRET"]:
                err.append(f"{where}: Secret parts are obtainable only via SECRET")
            elif acq[0].get("detail") != canon.secrets.get(pid):
                err.append(f"{where}: SECRET detail must equal the canon §C13.8 condition")
        else:
            if "SECRET" in codes:
                err.append(f"{where}: SECRET code on a non-Secret part")
            if "CAPSULE" not in codes:
                err.append(f"{where}: every non-Secret part is capsule-eligible (§C4.7)")
            cap = [a for a in acq if a["code"] == "CAPSULE"]
            if cap and canon.odds.get(r) and canon.odds[r] not in cap[0].get("detail", ""):
                err.append(f"{where}: CAPSULE detail must show the disclosed tier odds {canon.odds[r]}")
        if ("STARTER" in codes) != (pid in starters):
            err.append(f"{where}: STARTER code must appear exactly on the canon starter parts")
        tut = any(a["code"] == "QUEST" and "QST_TUT_010" in a.get("detail", "") for a in acq)
        if tut != (pid in tutorial):
            err.append(f"{where}: QST_TUT_010 grant must appear exactly on the canon tutorial choice parts")
        shop = [a for a in acq if a["code"] in ("SHOP_MART", "SHOP_ROTATION")]
        rng = canon.price.get(r)
        if r in ("Mythic", "Secret"):
            if shop or p.get("priceMB") is not None:
                err.append(f"{where}: {r} parts are never sold")
        else:
            if not shop:
                err.append(f"{where}: {r} parts must have a shop source")
            pr = p.get("priceMB")
            if rng is None or pr is None or not (rng[0] <= pr <= rng[1]):
                err.append(f"{where}: price {pr} outside canon range {rng}")
            if shop and f"{pr:,} MB" not in shop[0].get("detail", ""):
                err.append(f"{where}: shop detail must show the price {pr:,} MB")
            if r == "Rare" and "20 MS" not in shop[0]["detail"]:
                err.append(f"{where}: Rare shop cost must include 20 MS")
            if r == "Epic" and "80 MS" not in shop[0]["detail"]:
                err.append(f"{where}: Epic shop cost must include 80 MS")
            if r == "Legendary" and ("250 MS" not in shop[0]["detail"] or "10 RT" not in shop[0]["detail"]):
                err.append(f"{where}: Legendary shop cost must include 250 MS + 10 RT")
        if r == "Mythic":
            lab = [a for a in acq if a["code"] == "LAB_FUSION"]
            if not lab or "600 MS" not in lab[0]["detail"] or "40 RT" not in lab[0]["detail"] or "3 " not in lab[0]["detail"]:
                err.append(f"{where}: Mythic fusion must cost 3 Legendary + 600 MS + 40 RT (§C4.5)")
        # rig & budgets
        m = p.get("model", {})
        if m.get("motion") not in MOTIONS:
            err.append(f"{where}: motion {m.get('motion')!r} not in enum")
        if m.get("size") not in SIZES:
            err.append(f"{where}: size {m.get('size')!r} not in enum")
        for a in m.get("attachment", []):
            if a not in canon.attachments:
                err.append(f"{where}: attachment {a} not in canon §C13.7")
        if m.get("faceLocked") and slot != "HEAD":
            err.append(f"{where}: faceLocked only on HEAD parts")
        if m.get("handsLocked") and slot != "ARM":
            err.append(f"{where}: handsLocked only on ARM parts")
        if m.get("blocksWings") and slot != "BACK":
            err.append(f"{where}: blocksWings only on BACK parts")
        for h in m.get("hides", []):
            if h not in ("FACE", "NOSE", "MOUTH", "EYES", "HANDS", "FEET"):
                err.append(f"{where}: cannot hide slot {h}")
        ll, nl = m.get("legLength"), m.get("neckLength")
        if (slot == "LEG") != (ll is not None) or (ll is not None and not 1.4 <= ll <= 3.0):
            err.append(f"{where}: LEG parts need LegLength 1.4–3.0 (got {ll})")
        if (slot == "NECK") != (nl is not None) or (nl is not None and not 0.0 <= nl <= 2.5):
            err.append(f"{where}: NECK parts need NeckLength 0–2.5 (got {nl})")
        if m.get("tris", 0) > TRI_HI[slot] or m.get("trisNpc", 0) > TRI_LO[slot]:
            err.append(f"{where}: triangle budget exceeded ({m.get('tris')}/{TRI_HI[slot]}, {m.get('trisNpc')}/{TRI_LO[slot]})")
        if m.get("meshParts", 0) > MESH_MAX[slot]:
            err.append(f"{where}: MeshPart budget exceeded ({m.get('meshParts')}/{MESH_MAX[slot]})")
        for fld in ("visual", "limit"):
            if not p.get(fld):
                err.append(f"{where}: {fld} missing")
        # references inside data text
        blob = json.dumps(p, ensure_ascii=False)
        for tok in set(ID_RE.findall(blob)):
            if tok.startswith(("SYN_", "CMB_")):
                err.append(f"{where}: {tok} — synergy/combination IDs belong to §36.4/§36.5")
            elif tok not in canon.ids and not tok.startswith("MUT_"):
                err.append(f"{where}: unknown identifier {tok}")
    return err


def check_markdown_refs(canon: Canon, path: Path, known: set[str]) -> list[str]:
    if not path.exists():
        return []
    err = []
    for i, ln in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for tok in ID_RE.findall(ln):
            if tok.startswith(("SYN_", "CMB_")):
                err.append(f"{path.name}:{i}: {tok} — synergy/combination IDs belong to §36.4/§36.5")
            elif tok not in canon.ids and tok not in known:
                err.append(f"{path.name}:{i}: unknown identifier {tok}")
    return err


# ----------------------------------------------------------------------------- rendering helpers
def esc(s: str) -> str:
    return str(s).replace("|", "\\|").replace("\n", " ")


def stats_cell(st: dict) -> str:
    return ", ".join(f"{k} +{v}" for k, v in st.items()) if st else "— (FX: no stats)"


def unlock_cell(p: dict) -> str:
    u = p["unlock"]
    if u["equipLevel"] is None:
        return "On discovery"
    s = f"Lv{u['equipLevel']}"
    return f"{s} ({u['note']})" if u.get("note") else s


def acq_cell(p: dict) -> str:
    out = []
    for a in p["acquisition"]:
        d = a.get("detail", "")
        if a["code"] == "SECRET":
            out.append(f"**SECRET:** {d}")
        else:
            out.append(f"{a['code']} {d}".strip())
    return " · ".join(out)


def model_cell(p: dict) -> str:
    m = p["model"]
    bits = []
    if p["slot"] in ("SKIN", "SCALES") and m["tris"] == 0:
        bits.append("surface swap, 0 MP")
    elif p["slot"] == "FUR":
        bits.append(f"surface swap + ≤ {m['meshParts']} shells ({fmt(m['tris'])} tris, Hi only)")
    elif p["slot"] == "FX" and m["meshParts"] == 0:
        bits.append("emitters only, 0 MP")
    else:
        lo = f" (NPC {fmt(m['trisNpc'])})" if m["trisNpc"] else " (NPC: skipped)"
        bits.append(f"{m['meshParts']} MP · ≤ {fmt(m['tris'])} tris{lo}")
    if m["faceLocked"]:
        bits.append("**faceLocked**")
    elif m["hides"]:
        bits.append("hides " + "/".join(m["hides"]))
    if m["handsLocked"]:
        bits.append("**handsLocked**")
    if m["blocksWings"]:
        bits.append("**blocksWings**")
    if m["size"] != "normal":
        bits.append(f"size {m['size']}")
    if m["legLength"] is not None:
        bits.append(f"LegLength {m['legLength']:.1f}")
    if m["neckLength"] is not None:
        bits.append(f"NeckLength {m['neckLength']:.1f}")
    if m["motion"] not in ("none", "particles", "screen_emote"):
        bits.append(f"motion: {MOTION_TEXT[m['motion']]}")
    bits.append(m["note"])
    return " · ".join(bits)


def active_cell(p: dict, canon: Canon) -> str:
    a = p["active"]
    return f"`{a}` {canon.abilities.get(a, '')}".strip() if a else "—"


def row(p: dict, canon: Canon) -> str:
    cells = [f"`{p['id']}`", p["name"], p["slot"], p["category"], f"{RARITY_ICON[p['rarity']]} {p['rarity']}",
             unlock_cell(p), acq_cell(p), stats_cell(p["stats"]),
             f"*{p['passive']['name']}:* {p['passive']['text']}", active_cell(p, canon), str(p["maxLevel"]),
             p["visual"], model_cell(p), p["limit"]]
    return "| " + " | ".join(esc(c) for c in cells) + " |"


HEADER = ("| ID | Name | Slot | Cat | Rarity | Unlock | Acquisition | Stats Lv1 | Passive | Active | Max Lv | "
          "Visual description | Model & animation requirements | Balance limitation |\n"
          "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")


def counts_by(parts, key):
    c = Counter((p[key], p["rarity"]) for p in parts)
    keys = []
    for p in parts:
        if p[key] not in keys:
            keys.append(p[key])
    return keys, c


def count_table(parts, key, label, order=None) -> str:
    keys, c = counts_by(parts, key)
    if order:
        keys = [k for k in order if k in keys]
    lines = [f"| {label} | " + " | ".join(RARITIES) + " | Total |", "|---|" + "---|" * (len(RARITIES) + 1)]
    for k in keys:
        vals = [c[(k, r)] for r in RARITIES]
        lines.append(f"| {k} | " + " | ".join(str(v) if v else "·" for v in vals) + f" | **{sum(vals)}** |")
    tot = [sum(c[(k, r)] for k in keys) for r in RARITIES]
    lines.append("| **Total** | " + " | ".join(f"**{v}**" for v in tot) + f" | **{sum(tot)}** |")
    return "\n".join(lines)


# ----------------------------------------------------------------------------- §36.3
def render_db(canon: Canon, parts: list[dict]) -> str:
    by_slot = {s: [p for p in parts if p["slot"] == s] for s in SLOT_ORDER}
    o = []
    o.append("### 36.3 Mutation Parts Database\n")
    o.append(
        "All **280** mutation parts with their full specification. Identity columns (ID, name, slot, category, rarity, "
        "family, tags, active ability) are canon-fixed; everything else is defined here by the Mutation System owner. "
        "Rules that govern these rows (slots, compatibility, rig assembly, rarities, upgrades, generation, balance caps) "
        "live in §12. Synergies between parts are in §36.4, example combinations in §36.5, abilities in §36.6 and "
        "status effects in §36.7.\n")
    o.append(
        "> **Data-backed table.** Source of truth: `gdd/data/mutations.json`. Rendered by "
        "`python3 gdd/tools/render_mutations.py`, which also validates canon fidelity, stat budgets, prices, enums, rig "
        "flags and triangle budgets. Never edit this file by hand; edit the JSON and re-render. The same JSON feeds the "
        "generated `MutationDefs` Luau module (§27).\n")
    o.append("#### 36.3.1 Legend and column rules\n")
    o.append("| Column | Meaning |\n|---|---|")
    legend = [
        ("ID / Name / Slot / Cat / Rarity", "Canon identity. `ARM` parts fit ARM_L or ARM_R (mirrored); `LEG` parts fit LEG_L or LEG_R. Rarity is shown with its shape icon (● ▲ ■ ⬟ ★ ⬢ ?) so it never relies on color."),
        ("Unlock", "Equip level requirement (default per rarity: Common Lv1 · Uncommon Lv5 · Rare Lv12 · Epic Lv25 · Legendary Lv40 · Mythic Lv60). Parts can be *owned* earlier (capsules) but not equipped. Secret parts equip on discovery. Tutorial copies (QST_TUT_010) equip at Lv1."),
        ("Acquisition", "Canon acquisition codes. **SHOP_MART** = Mutation Mart (`BLD_01`; Rare parts appear in its rotating stock) and **SHOP_ROTATION** = Mystery Market (`BLD_13`; Legendary in the weekly slot), with the MB price and canon extra cost. **LAB_FUSION** = Mutation Laboratory (`BLD_11`) recipe for the rarity (§12.5): Rare ← 3 Uncommon + 40 MS + 1,000 MB · Epic ← 3 Rare + 150 MS + 5,000 MB · Legendary ← 3 Epic + 400 MS + 8 RT + 20,000 MB; Mythic rows name their fusion route. **QUEST** gives the quest line; **EVENT** names the city event whose reward track and capsule pool feature the part (×3 weight); **ARENA** = Arena season reward track; **OFFLINE_FIND ×3** = triple weight in offline-discovery capsules; **ACHIEVEMENT** = Mutation Catalog collection milestone (§12.1); **CAPSULE** shows the disclosed rarity-tier odds. Secret parts list their exact discovery condition."),
        ("Stats Lv1", "Stat points at level 1, in canon stat codes. Their sum equals `round(BaseBudget[rarity] × SlotWeight)` (§12.6). **Cooking bonus** = COOK_SPD / COOK_QLT / EFFICIENCY · **Combat bonus** = STR / DEF · **Repair bonus** = REPAIR · **Movement bonus** = MOVE · **Other** = LUCK / CHARM. Stats grow +12 % of the Lv1 budget per level; a matched arm or leg pair gets +25 %."),
        ("Passive", "Exactly one passive per part. Values are Lv1; numeric magnitudes scale ×(1 + 0.05 × (Lv − 1)), while cooldowns (ICD), durations, radii, counts and flat triggers never scale (§12.6). Each passive has an engineering key (`passive.key` in the JSON) with a combined cap (§12.8). A passive applies once even if the same part sits in both slots of a pair."),
        ("Active", "At most one active ability per part (canon). Tuning, cooldowns, counters and the matched-pair bonus are in §36.6. Up to 4 actives may be slotted on the ability bar."),
        ("Max Lv", "Maximum upgrade level for the rarity (C 5 · U 6 · R 7 · E 8 · L 9 · M 10 · S 10). Costs in §12.6."),
        ("Visual description", "Art brief for the character artist; kid-safe (no gore, no realistic weapons; teeth/fangs/claws are soft and rounded)."),
        ("Model & animation requirements", "MP = MeshParts in the part (player Hi LOD); tris = player Hi LOD budget; NPC = Lo LOD tris used for customers/employees (§12.3). Flags: **faceLocked** (hides FACE/NOSE/MOUTH/EYES visuals and shows a screen-emote; those parts stay active), **handsLocked** (hides the HANDS part on that side; the arm supplies its own grip point), **blocksWings** (cannot be worn with WINGS), `hides` (visual only), size class, LegLength / NeckLength (studs), procedural motion type, then part-specific rig notes. Named Motor6D joints are used by the ability clips in §36.14."),
        ("Balance limitation", "Part-specific limits on top of the global caps in §12.8 (stacking, PvP conversion, scope)."),
    ]
    for a, b in legend:
        o.append(f"| {a} | {esc(b)} |")
    o.append("")
    o.append("#### 36.3.2 Counts by slot and rarity\n")
    o.append(count_table(parts, "slot", "Part slot code", SLOT_ORDER))
    o.append("")
    o.append("Totals by rarity: " + " · ".join(f"{RARITY_ICON[r]} {r} {sum(1 for p in parts if p['rarity'] == r)}" for r in RARITIES)
             + f" · parts with an active ability: {sum(1 for p in parts if p['active'])} · faceLocked heads: "
             + f"{sum(1 for p in parts if p['model']['faceLocked'])} · handsLocked arms: {sum(1 for p in parts if p['model']['handsLocked'])}"
             + f" · wing-blocking back parts: {sum(1 for p in parts if p['model']['blocksWings'])}.\n")
    n = 3
    for s in SLOT_ORDER:
        lst = by_slot[s]
        w = canon.slot_weight[s]
        wl = {1.0: "Major", 0.5: "Minor", 0.0: "Cosmetic"}[w]
        att = ", ".join(f"`{a}`" for a in lst[0]["model"]["attachment"]) or "surface swap on all organic parts (MaterialVariant + Color)"
        if s in ("ARM", "LEG"):
            att += " (R side mirrored)"
        buds = " / ".join(f"{RARITY_ICON[r]} {budget(canon, r, s)}" for r in RARITIES)
        o.append(f"#### 36.3.{n} {s} — {SLOT_TITLE[s]} ({len(lst)})\n")
        o.append(f"Slot weight **{w} ({wl})** · Lv1 stat budget by rarity {buds} · attachment {att} · "
                 f"budget per part: ≤ {MESH_MAX[s]} MP, ≤ {fmt(TRI_HI[s])} tris Hi / ≤ {fmt(TRI_LO[s])} tris NPC.\n")
        o.append(HEADER)
        for p in lst:
            o.append(row(p, canon))
        o.append("")
        n += 1
    o.append("Every passive above maps to one engineering key (`passive.key`); the key vocabulary and its combined caps are "
             "listed in §12.8 and enforced by `MutationService`.\n")
    return "\n".join(o) + "\n"


def passive_table(parts) -> str:
    c = Counter(p["passive"]["key"] for p in parts)
    lines = ["| Passive key (group) | Effect | Combined cap / stacking [TUNABLE] | Parts |", "|---|---|---|---|"]
    for k, (g, d, cap) in PASSIVE_KEYS.items():
        if c[k]:
            lines.append(f"| `{k}` ({g.lower()}) | {esc(d)} | {esc(cap)} | {c[k]} |")
    return "\n".join(lines)


# ----------------------------------------------------------------------------- §12 generated regions
def gen_budget_growth(canon: Canon) -> str:
    o = ["Total stat points per part, shown as **major / minor** slot (major = HEAD, TORSO, each ARM, TAIL, WINGS, BACK; "
         "minor = FACE, NOSE, MOUTH, EYES, EARS, HORNS, NECK, HANDS, each LEG, FEET, SKIN, FUR, SCALES; FX = 0 at every level):\n",
         "| Level | Multiplier | " + " | ".join(f"{RARITY_ICON[r]} {r}" for r in RARITIES) + " |",
         "|---|---|" + "---|" * len(RARITIES)]
    for L in range(1, 11):
        cells = []
        for r in RARITIES:
            if L > canon.upg[r]["max"]:
                cells.append("—")
            else:
                k = 1 + 0.12 * (L - 1)
                cells.append(f"{rhu(canon.base_budget[r] * k)} / {rhu(canon.base_budget[r] * 0.5 * k)}")
        o.append(f"| Lv{L} | ×{1 + 0.12 * (L - 1):.2f} | " + " | ".join(cells) + " |")
    return "\n".join(o)


def upgrade_steps(canon: Canon, r: str):
    u = canon.upg[r]
    steps = []
    epic_plus = RARITIES.index(r) >= RARITIES.index("Epic")
    for L in range(1, u["max"]):
        mb = rhu(u["mb"] * 1.5 ** (L - 1))
        ms = u["ms"] * L
        rt = u["rt"] * (L - 3) if (epic_plus and L >= 4) else 0
        steps.append((L, mb, ms, rt))
    return steps


def gen_upgrade_costs(canon: Canon) -> str:
    o = []
    o.append("| Rarity | Max Lv | Total MB to max | Total MS to max | Total RT to max | Copies used (or extra MS) | Spare copy → MS |")
    o.append("|---|---|---|---|---|---|---|")
    for r in RARITIES:
        st = upgrade_steps(canon, r)
        u = canon.upg[r]
        n = len(st)
        dup = "— (cannot duplicate)" if u["conv"] is None else f"{u['conv']} MS"
        copies = f"{n} copies or {fmt(n * u['sub'])} MS" if u["conv"] is not None else f"no copies: {fmt(n * u['sub'])} MS"
        o.append(f"| {RARITY_ICON[r]} {r} | {u['max']} | {fmt(sum(s[1] for s in st))} | {fmt(sum(s[2] for s in st))} | "
                 f"{fmt(sum(s[3] for s in st)) if sum(s[3] for s in st) else '—'} | {copies} | {dup} |")
    o.append("")
    o.append("Per-step cost of upgrading **Lv L → L+1** (cell = MB · MS · RT; every step also consumes the duplicate shown in the last row):\n")
    o.append("| Step | " + " | ".join(f"{RARITY_ICON[r]} {r}" for r in RARITIES) + " |")
    o.append("|---|" + "---|" * len(RARITIES))
    steps = {r: {L: (mb, ms, rt) for L, mb, ms, rt in upgrade_steps(canon, r)} for r in RARITIES}
    for L in range(1, 10):
        cells = []
        for r in RARITIES:
            if L in steps[r]:
                mb, ms, rt = steps[r][L]
                cells.append(f"{fmt(mb)} MB · {ms} MS" + (f" · {rt} RT" if rt else ""))
            else:
                cells.append("—")
        o.append(f"| Lv{L} → {L + 1} | " + " | ".join(cells) + " |")
    dupe = []
    for r in RARITIES:
        u = canon.upg[r]
        dupe.append(f"1 copy or {fmt(u['sub'])} MS" if u["conv"] is not None else f"{fmt(u['sub'])} MS (no copies)")
    o.append("| **Duplicate per step** | " + " | ".join(dupe) + " |")
    return "\n".join(o)


def gen_prices(canon: Canon, parts) -> str:
    o = ["| Rarity | Canon range (MB) | Extra cost | Minor slot | Minor + active | Major slot | Major + active | FX (cosmetic) | Parts sold |",
         "|---|---|---|---|---|---|---|---|---|"]
    for r in RARITIES:
        rng = canon.price.get(r)
        sold = [p for p in parts if p["rarity"] == r and p["priceMB"] is not None]

        def pick(w, act):
            v = sorted({p["priceMB"] for p in sold if canon.slot_weight[p["slot"]] == w and bool(p["active"]) == act})
            return " / ".join(fmt(x) for x in v) if v else "·"
        if rng is None:
            o.append(f"| {RARITY_ICON[r]} {r} | not sold | {esc(canon.extra.get(r, ''))} | · | · | · | · | · | 0 |")
        else:
            o.append(f"| {RARITY_ICON[r]} {r} | {fmt(rng[0])}–{fmt(rng[1])} | {esc(canon.extra.get(r, ''))} | {pick(0.5, False)} | "
                     f"{pick(0.5, True)} | {pick(1.0, False)} | {pick(1.0, True)} | {pick(0.0, False)} | {len(sold)} |")
    return "\n".join(o)


def gen_counts(parts) -> str:
    cats = ["MAMMAL", "BIRD", "REPTILE", "AMPHIBIAN", "FISH", "INSECT", "ARACHNID", "MARINE", "DINOSAUR",
            "MYTHOLOGICAL", "ROBOT", "OBJECT", "FOOD", "PLANT", "ALIEN", "ELEMENTAL"]
    return count_table(parts, "category", "Category", cats)


def gen_combo(parts) -> str:
    cnt = Counter(p["slot"] for p in parts)
    face_locked = sum(1 for p in parts if p["model"]["faceLocked"])
    heads = cnt["HEAD"]
    core = heads * cnt["TORSO"] * cnt["ARM"] ** 2 * cnt["LEG"] ** 2
    bulky = sum(1 for p in parts if p["model"]["blocksWings"])
    wings_back = (cnt["BACK"] - bulky + 1) * (cnt["WINGS"] + 1) + bulky
    silhouette = core * (cnt["TAIL"] + 1) * wings_back
    opt = 1
    for s in ("FACE", "NOSE", "MOUTH", "EYES", "EARS", "HORNS", "NECK", "HANDS", "FEET", "SKIN", "FX"):
        opt *= cnt[s] + 1
    covering = cnt["FUR"] + cnt["SCALES"] + 1
    full = silhouette * opt * covering
    face_group = (cnt["FACE"] + 1) * (cnt["NOSE"] + 1) * (cnt["MOUTH"] + 1) * (cnt["EYES"] + 1)
    rest = full // (heads * face_group)
    visible = (heads - face_locked) * face_group * rest + face_locked * 1 * rest
    sym_core = heads * cnt["TORSO"] * cnt["ARM"] * cnt["LEG"]
    o = ["| Scope | How it is counted | Distinct combinations |", "|---|---|---|",
         f"| Matched core body | HEAD × TORSO × (one ARM part on both sides) × (one LEG part on both sides) = {heads} × {cnt['TORSO']} × {cnt['ARM']} × {cnt['LEG']} | {fmt(sym_core)} |",
         f"| Core body | HEAD × TORSO × ARM_L × ARM_R × LEG_L × LEG_R = {heads} × {cnt['TORSO']} × {cnt['ARM']}² × {cnt['LEG']}² | {fmt(core)} |",
         f"| Silhouette | core × TAIL ({cnt['TAIL']} + empty) × WINGS/BACK pairs that respect blocksWings ({wings_back}) | {fmt(silhouette)} |",
         f"| Full loadout | silhouette × optional FACE, NOSE, MOUTH, EYES, EARS, HORNS, NECK, HANDS, FEET, SKIN, FX (each + empty) × covering (FUR {cnt['FUR']} ⊕ SCALES {cnt['SCALES']} ⊕ none) | {fmt(full)} (≈ {full:.2e}) |",
         f"| Visually distinct | full loadout, collapsing face-group choices under the {face_locked} faceLocked heads | {fmt(visible)} (≈ {visible:.2e}) |",
         f"| With palettes | visually distinct × 24 palettes (§12.7) | ≈ {visible * 24:.2e} |"]
    o.append("")
    o.append(f"Art builds **{len(parts)}** parts (of which {cnt['FX']} are emitter-only FX and {cnt['SKIN'] + cnt['FUR'] + cnt['SCALES']} are surface swaps), "
             f"yet the matched core alone yields {sym_core / 1e6:.1f} million bodies and the full space exceeds 10^{int(math.log10(full))}. "
             "No combination is ever authored by hand.")
    return "\n".join(o)


def replace_region(text: str, key: str, body: str) -> tuple[str, bool]:
    pat = re.compile(rf"(<!-- BEGIN GENERATED: {re.escape(key)} -->\n)(.*?)(<!-- END GENERATED: {re.escape(key)} -->)", re.S)
    if not pat.search(text):
        return text, False
    return pat.sub(lambda m: m.group(1) + body.rstrip() + "\n" + m.group(3), text), True


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="validate only; write nothing")
    a = ap.parse_args()
    canon = Canon(CANON.read_text(encoding="utf-8"))
    data = json.loads(DATA.read_text(encoding="utf-8"))
    parts = data["parts"]
    errors = validate(canon, parts)
    known = {p["id"] for p in parts}
    if not errors and not a.check:
        OUT_DB.write_text(render_db(canon, parts), encoding="utf-8")
        if OUT_SYS.exists():
            txt = OUT_SYS.read_text(encoding="utf-8")
            regions = {"budget-growth": gen_budget_growth(canon), "upgrade-costs": gen_upgrade_costs(canon),
                       "price-points": gen_prices(canon, parts), "category-counts": gen_counts(parts),
                       "combination-math": gen_combo(parts), "passive-caps": passive_table(parts)}
            missing = []
            for k, body in regions.items():
                txt, ok = replace_region(txt, k, body)
                if not ok:
                    missing.append(k)
            OUT_SYS.write_text(txt, encoding="utf-8")
            if missing:
                print(f"note: {OUT_SYS.name} has no region(s) for: {', '.join(missing)}")
    errors += check_markdown_refs(canon, OUT_DB, known) + check_markdown_refs(canon, OUT_SYS, known)
    if errors:
        print(f"render_mutations: {len(errors)} validation error(s)")
        for e in errors[:200]:
            print("  -", e)
        return 1
    by_r = Counter(p["rarity"] for p in parts)
    print(f"render_mutations: OK — {len(parts)} parts ({', '.join(f'{r} {by_r[r]}' for r in RARITIES)}); "
          f"{'checked' if a.check else 'wrote ' + OUT_DB.name + (' + regions in ' + OUT_SYS.name if OUT_SYS.exists() else '')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

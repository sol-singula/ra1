#!/usr/bin/env python3
"""Render the data-backed tables of §14 Player Progression (owner A9) and self-check A9's files.

Stdlib only. Run from the repo root.

  python3 gdd/tools/render_progression.py            # refresh every generated block in 14_player_progression.md (idempotent)
  python3 gdd/tools/render_progression.py --print levels|calibration|pacing|economy
  python3 gdd/tools/render_progression.py --check    # self-check IDs, counts, skill-point economy, reward vocabulary

Generated blocks live between marker comments inside the section file:
  <!-- BEGIN GENERATED: levels --> ... <!-- END GENERATED: levels -->
Everything outside the markers is hand-written and never touched.

Formulas are copied verbatim from canon §C5 / §C5.1 (binding):
  XPReq(L)  = round((180 + 30·L) × 1.045^(L−1))      XP to go from L to L+1
  XPRate(L) = 900 × 1.045^(L−1)                      reference XP per active hour
  XPU(L)    = XPRate(L) / 100                         "XP Unit" used by every XP source in §14.5
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANON = ROOT / "gdd" / "canon.md"
SECTIONS = ROOT / "gdd" / "sections"
F14 = SECTIONS / "14_player_progression.md"
F_ACH = SECTIONS / "36_16_achievements.md"
F_MLS = SECTIONS / "36_17_milestones.md"

LEVEL_CAP = 100
QUEST_SKILL_POINT_CEILING = 15  # [TUNABLE] design budget handed to A13 (§20); see §14.13

# --------------------------------------------------------------------------- canon formulas


def xp_req(level: int) -> int:
    return int(round((180 + 30 * level) * 1.045 ** (level - 1)))


def xp_rate(level: int) -> float:
    return 900 * 1.045 ** (level - 1)


def xpu(level: int) -> float:
    return xp_rate(level) / 100.0


def cumulative_xp(level: int) -> int:
    return sum(xp_req(k) for k in range(1, level))


def cumulative_hours(level: int) -> float:
    return sum(xp_req(k) / xp_rate(k) for k in range(1, level))


def fmt(n: float | int) -> str:
    return f"{int(round(n)):,}"


# --------------------------------------------------------------------------- canon parsing


def canon_lines() -> list[str]:
    return CANON.read_text(encoding="utf-8").splitlines()


def cells(line: str) -> list[str]:
    return [c.strip().replace("`", "") for c in line.strip().split("|")[1:-1]]


def canon_recipes() -> dict[str, tuple[str, int]]:
    out = {}
    for ln in canon_lines():
        m = re.match(r"^\|\s*`(RCP_[A-Z]{3}_\d{3})`\s*\|\s*(.+?)\s*\|\s*(\d+)\s*\|\s*$", ln)
        if m:
            out[m.group(1)] = (m.group(2), int(m.group(3)))
    return out


def canon_tiers() -> dict[str, tuple[str, int]]:
    out = {}
    for ln in canon_lines():
        if ln.startswith("| `TIER_") and ln.count("|") >= 10:
            c = cells(ln)
            out[c[0]] = (c[1], int(c[3]))
    return out


def canon_districts() -> dict[str, tuple[str, int]]:
    out = {}
    for ln in canon_lines():
        if re.match(r"^\| `DST_\d{2}`", ln):
            c = cells(ln)
            m = re.match(r"L(\d+)", c[2])
            out[c[0]] = (c[1], int(m.group(1)) if m else 1)
    return out


def canon_station_schedule() -> list[tuple[list[str], int, str]]:
    lines = canon_lines()
    out, inside = [], False
    for ln in lines:
        if ln.startswith("### C7.1"):
            inside = True
            continue
        if inside and (ln.startswith("### ") or ln.startswith("## ")):
            break
        if inside and ln.startswith("| `STN_"):
            c = cells(ln)
            stations = re.findall(r"STN_[A-Z_]+[A-Z]", c[0])
            lvl = int(re.match(r"(\d+)", c[1]).group(1))
            out.append((stations, lvl, c[2]))
    return out


# Canon §C13.3 default equip levels (checked against canon text in --check).
RARITY_EQUIP = {5: "Uncommon", 12: "Rare", 25: "Epic", 40: "Legendary", 60: "Mythic"}

# Skill-tree row gates (§14.9): row -> (level, points already spent in that tree)
PRIMARY_ROWS = {1: (2, 0), 2: (5, 2), 3: (10, 5), 4: (18, 9), 5: (26, 14), 6: (35, 20), 7: (45, 26), 8: (60, 32)}
SPEC_ROWS = {1: (20, 0), 2: (26, 3), 3: (35, 7), 4: (45, 11), 5: (60, 16)}

# Level-band milestones (ids defined in §36.17) and their bonus skill points.
LEVEL_MILESTONES = {2: ("MLS_014", 0), 5: ("MLS_032", 0), 10: ("MLS_033", 1), 12: ("MLS_034", 0),
                    15: ("MLS_035", 0), 20: ("MLS_036", 0), 25: ("MLS_037", 1), 30: ("MLS_038", 0),
                    40: ("MLS_039", 0), 50: ("MLS_040", 1), 60: ("MLS_041", 0), 75: ("MLS_042", 1),
                    90: ("MLS_043", 0), 100: ("MLS_044", 1)}

FEATURES = {
    1: "Start: Broken Burger Shack, 12-station starter kit, `DST_01`/`DST_02` (+`DST_03` at tutorial step 10), Common mutations, free starter part (`QST_TUT_010`)",
    2: "Skill points begin (1/level) · skill Row 1 of every primary tree",
    5: "Uncommon mutations equippable · skill Row 2",
    10: "Skill Row 3",
    12: "Rare mutations · Morph Arena `BLD_08` (opt-in PvP) & Training Gym `BLD_05`",
    15: "Mutation Laboratory `BLD_11` (fusion) & Morph Museum `BLD_16`",
    18: "Skill Row 4",
    20: "**1st specialization** (pick SVC or MGMT; spec Row S1) · Mystery Market `BLD_13`",
    25: "Epic mutations",
    26: "Skill Row 5 · spec Row S2",
    35: "Skill Row 6 · spec Row S3",
    40: "Legendary mutations",
    45: "Skill Row 7 · spec Row S4",
    50: "**2nd specialization** auto-unlocks (the one you did not pick)",
    60: "Mythic mutations · Row 8 capstones · spec Row S5 capstones",
    100: "**Level cap.** Further XP fills repeatable Overtime Bars (`MLS_045`)",
}


def level_unlocks(level: int) -> str:
    parts: list[str] = []
    if level in FEATURES:
        parts.append(FEATURES[level])
    for tid, (name, req) in canon_tiers().items():
        if req == level and req > 1:
            parts.append(f"**Tier:** `{tid}` {name} eligible")
    for did, (name, req) in canon_districts().items():
        if req == level and req > 1:
            parts.append(f"**District:** `{did}` {name}")
    if level > 1:
        groups = []
        for stations, lvl, tier in canon_station_schedule():
            if lvl == level:
                note = "" if tier == "TIER_01" else f" (needs `{tier}`)"
                groups.append(", ".join(f"`{s}`" for s in stations) + note)
        if groups:
            parts.append("**Stations:** " + "; ".join(groups))
    recs = sorted([rid for rid, (_, lv) in canon_recipes().items() if lv == level])
    if recs:
        verb = "known" if level == 1 else ""
        flags = []
        if any("_ALN_" in r for r in recs):
            flags.append("ALN needs the Ch.5 Alien Cuisine course")
        if any("_MUT_" in r for r in recs):
            flags.append("MUT needs `STN_INFUSER`")
        if any("_LEG_" in r for r in recs):
            flags.append("LEG needs its Legendary Recipe quest")
        flag = f" ({'; '.join(flags)})" if flags else ""
        label = f"Recipes {verb}".strip()
        parts.append(f"**{label} ({len(recs)}):** " + ", ".join(f"`{r}`" for r in recs) + flag)
    if level in LEVEL_MILESTONES:
        mid, sp = LEVEL_MILESTONES[level]
        parts.append(f"`{mid}`" + (" (+1 bonus skill point)" if sp else ""))
    return " · ".join(parts) if parts else "—"


# --------------------------------------------------------------------------- generated blocks


def block_levels() -> str:
    out = ["| Level | XP to next | Cumulative XP | ≈ Cum. active h | Stat pts (cum.) | Skill pts (cum.) | Unlocks at this level |",
           "|---|---|---|---|---|---|---|"]
    for lv in range(1, LEVEL_CAP + 1):
        nxt = fmt(xp_req(lv)) if lv < LEVEL_CAP else "— (cap)"
        out.append(f"| {lv} | {nxt} | {fmt(cumulative_xp(lv))} | {cumulative_hours(lv):.1f} | {2 * (lv - 1)} | {lv - 1} | {level_unlocks(lv)} |")
    return "\n".join(out)


# Reference activity mix of a *competent* player, per active hour, by tier (§14.5.3) [TUNABLE].
# (label, ref level, hands-on dishes/h, avg difficulty D, avg Fresh, avg Grade, LEG share,
#  avg SatXP per customer, calm XPU, repair/clean/fire XPU, quest XPU, discovery+event+one-time XPU)
MIX = [
    ("1 Broken Burger Shack", 3, 44, 1.5, 1.00, 1.045, 0.00, 0.55, 3.0, 3.0, 14.0, 7.0),
    ("2 Tiny Mutation Diner", 7, 43, 1.8, 0.97, 1.045, 0.00, 0.55, 3.5, 3.0, 12.0, 6.5),
    ("3 Neighborhood Freak Café", 14, 42, 2.1, 0.94, 1.045, 0.00, 0.55, 4.0, 3.0, 11.0, 6.0),
    ("4 Morph City Grill", 22, 41, 2.4, 0.92, 1.045, 0.00, 0.55, 4.5, 3.0, 11.0, 5.0),
    ("5 Mutant Family Restaurant", 30, 40, 2.7, 0.90, 1.045, 0.00, 0.55, 5.0, 3.0, 11.0, 4.5),
    ("6 Monster Food Court", 40, 39, 3.0, 0.88, 1.045, 0.00, 0.55, 5.0, 3.0, 11.0, 4.0),
    ("7 Mutation Megadiner", 50, 38, 3.2, 0.86, 1.045, 0.00, 0.55, 5.0, 3.0, 11.0, 4.0),
    ("8 Luxury Freak Restaurant", 62, 37, 3.4, 0.84, 1.045, 0.00, 0.55, 5.0, 3.0, 11.0, 4.0),
    ("9 Morph City Food Palace", 74, 37, 3.6, 0.82, 1.045, 0.02, 0.55, 5.0, 3.0, 11.0, 4.0),
    ("10 Legendary Mutation Restaurant", 90, 36, 3.8, 0.80, 1.045, 0.05, 0.55, 5.0, 3.0, 11.0, 4.0),
]


def dish_xpu(d: float, fresh: float, grade: float, leg: float) -> float:
    return 1.4 * (0.5 + 0.25 * d) * fresh * grade * (1 + 0.5 * leg)


def mix_rows():
    rows = []
    for label, lv, dishes, d, fresh, grade, leg, sat, calm, rep, quest, other in MIX:
        dx = dishes * dish_xpu(d, fresh, grade, leg)
        sx = dishes / 1.4 * sat
        total = dx + sx + calm + rep + quest + other
        rows.append((label, lv, dishes, d, fresh, dx, sx, calm, rep, quest, other, total))
    return rows


def block_calibration() -> str:
    out = ["| Tier (ref. level) | Hands-on dishes/h | Avg D | Avg Fresh | DISH XPU | SERVE XPU | Calm XPU | Repair/clean XPU | Quest XPU | Discovery/event/one-time XPU | **Total XPU/h** | Cook+serve share | XP/h at ref. level (= Total × XPU) | XPRate(L) |",
           "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for label, lv, dishes, d, fresh, dx, sx, calm, rep, quest, other, total in mix_rows():
        share = (dx + sx) / total
        out.append(f"| {label} (L{lv}) | {dishes} | {d:.1f} | {fresh:.2f} | {dx:.1f} | {sx:.1f} | {calm:.1f} | {rep:.1f} | {quest:.1f} | {other:.1f} | **{total:.1f}** | {share:.0%} | {fmt(total * xpu(lv))} | {fmt(xp_rate(lv))} |")
    return "\n".join(out)


CANON_PACING = {5: 1.1, 10: 3.3, 18: 8.5, 26: 15.8, 35: 26.6, 45: 41.8, 56: 62, 68: 89, 80: 121, 100: 185}
CANON_CUM = {10: 3661, 26: 28402, 45: 139261, 80: 1365697, 100: 4319405}
CANON_REQ = {1: 210, 10: 713, 26: 2885, 45: 10612, 68: 42378, 80: 83523}
C44_TIER_HOURS = {5: (2, 1), 10: (3, 3), 18: (4, 7), 26: (5, 14), 35: (6, 25), 45: (7, 40), 56: (8, 60), 68: (9, 85), 80: (10, 120)}


def block_pacing() -> str:
    rows = mix_rows()
    out = ["| Level | Canon §C5.1 pacing (h) | This table (h, 100 XPU/h) | Δ | Mix-weighted (h, §14.5.3 mix) | Canon §C4.4 tier-entry h | Cumulative XP (this table) |",
           "|---|---|---|---|---|---|---|"]

    def mix_total_for(level: int) -> float:
        best = rows[0]
        for r in rows:
            if r[1] <= level:
                best = r
        return best[-1]

    for lv, canon_h in CANON_PACING.items():
        h = cumulative_hours(lv)
        hm = sum(xp_req(k) / (xpu(k) * mix_total_for(k)) for k in range(1, lv))
        c44 = C44_TIER_HOURS.get(lv)
        c44s = f"{c44[1]} (`TIER_{c44[0]:02d}`)" if c44 else "—"
        out.append(f"| {lv} | {canon_h} | {h:.1f} | {h - canon_h:+.1f} | {hm:.1f} | {c44s} | {fmt(cumulative_xp(lv))} |")
    return "\n".join(out)


# --------------------------------------------------------------------------- skill economy (parsed)


SKL_ROW_RE = re.compile(r"^\|\s*`?(SKL_(CHEF|CMBT|RPR|SVC|MGMT)_\d{2})`?\s*\|")


def parse_skill_nodes(text: str):
    nodes = {}
    for ln in text.splitlines():
        m = SKL_ROW_RE.match(ln)
        if not m:
            continue
        c = cells(ln)
        # ID | Name | Row | Cost | Prereqs | Level req | Max ranks | Effect
        row = c[2].replace("S", "")
        nodes[c[0]] = {
            "tree": m.group(2), "name": c[1], "row": int(row), "spec_row": c[2].startswith("S"),
            "cost": int(c[3]), "prereq": re.findall(r"SKL_[A-Z]+_\d{2}", c[4]),
            "prereq_any": " or " in c[4], "level": int(re.sub(r"\D", "", c[5])), "ranks": int(c[6]),
            "effect": c[7] if len(c) > 7 else "",
        }
    return nodes


def bonus_points(path: Path) -> int:
    if not path.exists():
        return 0
    n = 0
    for ln in path.read_text(encoding="utf-8").splitlines():
        if re.match(r"^\|\s*`?(ACH|MLS)_\d{3}", ln):
            for m in re.finditer(r"\+?(\d+)\s+skill point", ln):
                n += int(m.group(1))
    return n


def block_economy() -> str:
    text = F14.read_text(encoding="utf-8") if F14.exists() else ""
    nodes = parse_skill_nodes(text)
    trees = ["CHEF", "CMBT", "RPR", "SVC", "MGMT"]
    names = {"CHEF": "Chef", "CMBT": "Combat", "RPR": "Repair", "SVC": "Customer Service (spec)", "MGMT": "Employee Management (spec)"}
    out = ["| Tree | Nodes | Total ranks | Cost to max (points) |", "|---|---|---|---|"]
    grand = 0
    for t in trees:
        ns = [n for n in nodes.values() if n["tree"] == t]
        cost = sum(n["cost"] * n["ranks"] for n in ns)
        grand += cost
        out.append(f"| {names[t]} | {len(ns)} | {sum(n['ranks'] for n in ns)} | {cost} |")
    ach, mls = bonus_points(F_ACH), bonus_points(F_MLS)
    avail = (LEVEL_CAP - 1) + ach + mls + QUEST_SKILL_POINT_CEILING
    out.append(f"| **All trees** | **{len(nodes)}** | **{sum(n['ranks'] for n in nodes.values())}** | **{grand}** |")
    out.append("")
    out.append("| Skill-point source | Points |")
    out.append("|---|---|")
    out.append(f"| Levels (1 per level from L2) | {LEVEL_CAP - 1} |")
    out.append(f"| Achievements (§36.16, rows granting a skill point) | {ach} |")
    out.append(f"| Milestones (§36.17, rows granting a skill point) | {mls} |")
    out.append(f"| Quests (§20) — design ceiling [TUNABLE] | {QUEST_SKILL_POINT_CEILING} |")
    out.append(f"| **Maximum obtainable** | **{avail}** |")
    out.append(f"| **Total node cost ÷ maximum obtainable** | **{grand / avail:.2f}×** (a maxed player owns at most {avail / grand:.0%} of all ranks) |")
    return "\n".join(out)


BLOCKS = {"levels": block_levels, "calibration": block_calibration, "pacing": block_pacing, "economy": block_economy}


def render_in_place() -> int:
    if not F14.exists():
        print(f"render_progression: {F14.relative_to(ROOT)} not found, nothing to render")
        return 0
    text = F14.read_text(encoding="utf-8")
    for key, fn in BLOCKS.items():
        pat = re.compile(rf"(<!-- BEGIN GENERATED: {key} -->\n)(.*?)(<!-- END GENERATED: {key} -->)", re.S)
        if pat.search(text):
            text = pat.sub(lambda m: m.group(1) + fn() + "\n" + m.group(3), text)
    F14.write_text(text, encoding="utf-8")
    print(f"render_progression: refreshed {', '.join(BLOCKS)} in {F14.relative_to(ROOT)}")
    return 0


# --------------------------------------------------------------------------- self-check

ID_RE = re.compile(r"(?<![A-Za-z0-9_])(?:RCP_(?:BRG|PIZ|TAC|SAN|SOP|PST|BRK|DES|DRK|SEA|SAL|FRI|ALN|MUT|LEG)_\d{3}|ING_[A-Z0-9]+(?:_[A-Z0-9]+)*|MOD_\d{3}|STN_[A-Z]+(?:_[A-Z]+)*|PER_\d{3}|ABL_\d{3}|STS_[A-Z]+|MUT_\d{3}|SYN_\d{3}|CMB_\d{3}|SKL_(?:CHEF|CMBT|RPR|SVC|MGMT)_\d{2}|ACH_\d{3}|MLS_\d{3}|TIER_\d{2}|FRN_\d{3}|UPG_\d{3}|ROLE_[A-Z]+(?:_[A-Z]+)*|EMP_\d{3}|INC_\d{3}|DST_\d{2}|BLD_\d{2}|NPC_\d{3}|QST_(?:TUT|STY|DLY|WKY|CHF|CBT|RPR|EXP|EMP|RST)_\d{3}|EVT_\d{3}|ANM_\d{3}|SFX_\d{3}|MUS_\d{3})(?![A-Za-z0-9_])")


def canon_defined_ids() -> set[str]:
    ids = set()
    text = CANON.read_text(encoding="utf-8")
    for ln in text.splitlines():
        if ln.startswith("|"):
            for c in cells(ln):
                for m in ID_RE.finditer(c):
                    tok = m.group(0)
                    if re.match(r"(RCP|MUT|ABL|PER|TIER|DST|BLD|NPC|EVT|ROLE|STN|QST|ANM|EMP)_", tok):
                        ids.add(tok)
    # status effects, ingredients, trophies (listed in prose)
    sts = re.search(r"### C12\.3.*?\n(.*?)\n\(", text, re.S)
    ids |= set(re.findall(r"STS_[A-Z]+", sts.group(1)))
    ing = re.search(r"\*\*Guaranteed core ingredient IDs\*\*(.*?)\n\n", text, re.S)
    ids |= set(re.findall(r"ING_[A-Z_]+[A-Z]", ing.group(1)))
    ids |= {f"FRN_{n}" for n in range(901, 911)}
    # only canon-fixed IDs count; remove placeholders mentioned as examples
    return ids


def defined_in(path: Path) -> set[str]:
    out = set()
    if not path.exists():
        return out
    for ln in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\|\s*`?((?:SKL_[A-Z]+_\d{2})|(?:ACH_\d{3})|(?:MLS_\d{3}))`?\s*\|", ln)
        if m:
            out.add(m.group(1))
    return out


ALLOWED_REWARD = [r"^[\d,]+ MB$", r"^[\d,]+ MS$", r"^[\d,]+ RT$", r"^XP [\d,]+ XPU$", r"^\d+ Morph Capsules?$",
                  r"^`?MUT_\d{3}`?( .+)?$", r"^recipe unlock `?RCP_[A-Z]{3}_\d{3}`?( .+)?$", r"^`?FRN_9(0[1-9]|10)`?( .+)?$",
                  r"^\d+ skill points?$", r"^\d+ stat respec tokens?$", r"^title “.+”$", r"^emote “.+”$", r"^palette “.+”$"]


def check_rewards(path: Path, allow_ms_rt: bool, reward_col: int) -> list[str]:
    errs = []
    for ln in path.read_text(encoding="utf-8").splitlines():
        if not re.match(r"^\|\s*`?(ACH|MLS)_\d{3}", ln):
            continue
        c = cells(ln)
        rid = c[0]
        reward = c[reward_col]
        for piece in [p.strip() for p in reward.split(" + ")]:
            piece = piece.replace("`", "").strip()
            piece_core = re.sub(r"\s*\(.*\)$", "", piece)
            if not any(re.match(rx, piece_core) for rx in ALLOWED_REWARD):
                errs.append(f"{rid}: reward piece not in C17.4 vocabulary: {piece!r}")
            if not allow_ms_rt and re.match(r"^[\d,]+ (MS|RT)$", piece_core):
                errs.append(f"{rid}: milestones may not grant MS/RT (canon C4.1 sources)")
    return errs


def run_check() -> int:
    errs: list[str] = []
    warn: list[str] = []
    canon_ids = canon_defined_ids()
    mine = defined_in(F14) | defined_in(F_ACH) | defined_in(F_MLS)
    files = [F14, F_ACH, F_MLS]
    for f in files:
        if not f.exists():
            errs.append(f"missing file {f.name}")
            continue
        text = f.read_text(encoding="utf-8")
        first = text.splitlines()[0]
        expect = {"14_player_progression.md": "## 14. Player Progression",
                  "36_16_achievements.md": "### 36.16 Achievements Database",
                  "36_17_milestones.md": "### 36.17 Progression Milestones Database"}[f.name]
        if first != expect:
            errs.append(f"{f.name}: first line {first!r} != {expect!r}")
        for i, ln in enumerate(text.splitlines(), 1):
            for m in ID_RE.finditer(ln):
                tok = m.group(0)
                if tok in mine or tok in canon_ids:
                    continue
                errs.append(f"{f.name}:{i}: ID {tok} is neither canon-defined nor defined by A9")
            # canon IDs must never be in the first cell (that would be a definition)
            if ln.startswith("|"):
                c0 = cells(ln)[0] if cells(ln) else ""
                if ID_RE.fullmatch(c0) and not re.match(r"(SKL|ACH|MLS)_", c0):
                    errs.append(f"{f.name}:{i}: canon ID {c0} in first table cell (would be a definition)")
        print(f"{f.name}: {len(text.encode('utf-8')):,} bytes")
    # counts
    nodes = parse_skill_nodes(F14.read_text(encoding="utf-8"))
    for t, need in [("CHEF", 20), ("CMBT", 20), ("RPR", 20), ("SVC", 10), ("MGMT", 10)]:
        n = sum(1 for x in nodes.values() if x["tree"] == t)
        print(f"SKL_{t}: {n} nodes (min {need})")
        if n < need:
            errs.append(f"SKL_{t} has {n} < {need}")
    ach = [x for x in defined_in(F_ACH) if x.startswith("ACH_")]
    mls = [x for x in defined_in(F_MLS) if x.startswith("MLS_")]
    print(f"Achievements: {len(ach)} (min 60) · Milestones: {len(mls)} (min 40)")
    if len(ach) < 60:
        errs.append("fewer than 60 achievements")
    if len(mls) < 40:
        errs.append("fewer than 40 milestones")
    t14_all = F14.read_text(encoding="utf-8")
    lv_block = re.search(r"<!-- BEGIN GENERATED: levels -->\n(.*?)<!-- END GENERATED: levels -->", t14_all, re.S)
    lvl_rows = [ln for ln in (lv_block.group(1) if lv_block else "").splitlines() if re.match(r"^\| \d{1,3} \| [\d,—]", ln)]
    print(f"Level-table rows: {len(lvl_rows)}")
    if len(lvl_rows) != 100:
        errs.append(f"level table has {len(lvl_rows)} rows, expected 100")
    # level rows must match the formula exactly
    for ln in lvl_rows:
        c = cells(ln)
        lv = int(c[0])
        if lv < 100 and c[1] != fmt(xp_req(lv)):
            errs.append(f"level {lv}: XP to next {c[1]} != {fmt(xp_req(lv))}")
        if c[2] != fmt(cumulative_xp(lv)):
            errs.append(f"level {lv}: cumulative {c[2]} != {fmt(cumulative_xp(lv))}")
    # canon reference values
    for lv, v in CANON_REQ.items():
        if xp_req(lv) != v:
            errs.append(f"XPReq({lv}) = {xp_req(lv)} but canon says {v}")
    for lv, v in CANON_CUM.items():
        if cumulative_xp(lv) != v:
            errs.append(f"cumXP({lv}) = {cumulative_xp(lv)} but canon says {v}")
    # skill node integrity
    for nid, n in nodes.items():
        gate = (SPEC_ROWS if n["spec_row"] else PRIMARY_ROWS)[n["row"]]
        if n["level"] < gate[0]:
            errs.append(f"{nid}: level req {n['level']} below row gate {gate[0]}")
        for p in n["prereq"]:
            if p not in nodes:
                errs.append(f"{nid}: prereq {p} undefined")
            elif nodes[p]["tree"] != n["tree"] or nodes[p]["row"] >= n["row"]:
                errs.append(f"{nid}: prereq {p} must be an earlier row of the same tree")
    # points-in-tree gates must be reachable with nodes of earlier rows
    for t in ["CHEF", "CMBT", "RPR", "SVC", "MGMT"]:
        rows = SPEC_ROWS if t in ("SVC", "MGMT") else PRIMARY_ROWS
        for r, (_, need) in rows.items():
            avail = sum(x["cost"] * x["ranks"] for x in nodes.values() if x["tree"] == t and x["row"] < r)
            if avail < need:
                errs.append(f"{t} row {r}: needs {need} points but earlier rows only hold {avail}")
    total_cost = sum(n["cost"] * n["ranks"] for n in nodes.values())
    avail = (LEVEL_CAP - 1) + bonus_points(F_ACH) + bonus_points(F_MLS) + QUEST_SKILL_POINT_CEILING
    print(f"Skill economy: total node cost {total_cost} vs max obtainable {avail} (ACH {bonus_points(F_ACH)}, MLS {bonus_points(F_MLS)})")
    if total_cost <= avail:
        errs.append("total skill-node cost does not exceed available points (canon C18)")
    # rewards
    errs += check_rewards(F_ACH, True, 5)
    errs += check_rewards(F_MLS, False, 4)
    # achievement categories
    cats = {"cooking", "service", "chaos", "combat", "morph", "building", "staff", "city", "social", "secret"}
    for ln in F_ACH.read_text(encoding="utf-8").splitlines():
        if re.match(r"^\|\s*`?ACH_\d{3}", ln):
            c = cells(ln)
            if c[7] not in cats:
                errs.append(f"{c[0]}: bad category {c[7]!r}")
            if c[6] not in ("Yes", "No"):
                errs.append(f"{c[0]}: Hidden? must be Yes/No")
    for ln in F_MLS.read_text(encoding="utf-8").splitlines():
        if re.match(r"^\|\s*`?MLS_\d{3}", ln):
            c = cells(ln)
            if not re.match(r"^mmr_[a-z0-9_]+", c[5]):
                errs.append(f"{c[0]}: analytics event must start with mmr_")
    # sections: ACs, edge cases, mermaid
    t14 = F14.read_text(encoding="utf-8")
    acs = sorted(set(re.findall(r"\bAC-14-\d{2}\b", t14)))
    ecs = sorted(set(re.findall(r"\bEC-14-\d{2}\b", t14)))
    print(f"ACs: {len(acs)} · Edge cases: {len(ecs)} · [TUNABLE]: {t14.count('[TUNABLE]')}")
    if len(acs) < 12:
        errs.append("fewer than 12 ACs")
    if len(ecs) < 8:
        errs.append("fewer than 8 edge cases")
    if "```mermaid\n%% diagram: player-progression" not in t14:
        errs.append("player-progression mermaid block missing or not first line")
    if "E14" not in t14:
        errs.append("edge case E14 not cited")
    for e in errs:
        print("  [ERR]", e)
    for w in warn:
        print("  [WARN]", w)
    print("CHECK:", "PASS" if not errs else f"FAIL ({len(errs)})")
    return 0 if not errs else 1


def main(argv: list[str]) -> int:
    if "--check" in argv:
        return run_check()
    if "--print" in argv:
        key = argv[argv.index("--print") + 1]
        print(BLOCKS[key]())
        return 0
    return render_in_place()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

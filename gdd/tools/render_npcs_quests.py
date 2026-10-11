#!/usr/bin/env python3
"""Render §19 City NPCs and §20 Quests (owner: A13 NPCs & Quests).

Inputs (all under gdd/):
  data/npcs.jsonl                 one NPC per line   (keys below)
  data/quests.jsonl               one quest per line (keys below)
  data/npcs_quests/19_intro.md    prose before the NPC database
  data/npcs_quests/19_outro.md    prose after the NPC database
  data/npcs_quests/20_intro.md    prose before the quest database
  data/npcs_quests/20_outro.md    prose after the quest database
Outputs:
  sections/19_city_npcs.md, sections/20_quests.md

NPC keys:   id, n (name), m (morph), p (personality), dst, bld (opt), at (opt location note),
            r (role), d (list of dialogue lines), b (interaction behavior), q (opt extra quest ids)
Quest keys: id, n (name), de (description), npc (giver), inv (opt involved NPCs), loc,
            o (list of typed objectives), pre (prerequisites), cc (completion conditions),
            rw (rewards spec), f (failure conditions), t (reference tier 1-10), l (reference level)
Reward spec rw:
  {"MB":abs, "XP":abs}                 fixed values (tutorial)
  {"mb":h, "xp":f}                     MB = h x IncH(t) (canon C4.4), XP = f x XPRate(l) (canon C5.1)
  {"sc":1, "mb":"0.15", "xp":"0.25"}   scales with the player's tier/level at accept time
  optional: ms, rt (int or str), cap (Morph Capsules), sp (skill points), x (list of extra rewards)

Usage: python3 gdd/tools/render_npcs_quests.py [--check]
  --check  also verifies every ID token against canon.md + the IDs defined here (exit 1 on error).
Idempotent; Python 3 stdlib only.
"""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, OrderedDict
from pathlib import Path

GDD = Path(__file__).resolve().parent.parent
DATA = GDD / "data"
FRAG = DATA / "npcs_quests"
OUT19 = GDD / "sections" / "19_city_npcs.md"
OUT20 = GDD / "sections" / "20_quests.md"
CANON = GDD / "canon.md"

# canon C4.4 net MB per active hour by tier, canon C5.1 XP rate
INC = {1: 630, 2: 1080, 3: 1730, 4: 3100, 5: 5400, 6: 9600, 7: 17400, 8: 32800, 9: 63700, 10: 120500}


# Tier pacing factors [TUNABLE] (§20.6): early tiers are short (1–7 h) but carry many teaching quests, late tiers are long.
P_MB = {1: 0.3, 2: 0.3, 3: 0.35, 4: 0.4, 5: 0.47, 6: 0.8, 7: 1.35, 8: 1.9, 9: 2.5, 10: 3.4}
P_XP = {1: 0.15, 2: 0.14, 3: 0.18, 4: 0.21, 5: 0.33, 6: 0.6, 7: 1.0, 8: 1.4, 9: 1.7, 10: 2.8}


def fixed_mb(q: dict) -> int:
    f = q["rw"].get("mb", 0)
    return nice(f * INC[q["t"]] * P_MB[q["t"]]) if f else 0


def fixed_xp(q: dict) -> int:
    f = q["rw"].get("xp", 0)
    return nice(f * xprate(q["l"]) * P_XP[q["t"]]) if f else 0


def xprate(level: int) -> float:
    return 900 * 1.045 ** (level - 1)


def nice(v: float) -> int:
    """Round a reward to a friendly number (TUNABLE presentation rule, see §20.6)."""
    if v < 100:
        step = 5
    elif v < 1000:
        step = 10
    elif v < 10000:
        step = 50
    elif v < 100000:
        step = 100
    else:
        step = 1000
    return max(step, int(round(v / step)) * step)


DISTRICTS = OrderedDict([
    ("DST_01", "Restaurant Row"), ("DST_02", "Mutation Market"), ("DST_03", "Downtown Morph City"),
    ("DST_04", "Industrial District"), ("DST_05", "Monster Mall"), ("DST_06", "Mutation Research District"),
    ("DST_07", "Entertainment District"), ("DST_08", "Residential District"),
    ("DST_09", "Underground Mutation Sewers"), ("DST_10", "Arena District"),
])
QTYPES = OrderedDict([
    ("TUT", "Tutorial quests"), ("STY", "Story quests (campaign)"), ("DLY", "Daily quest pool"),
    ("WKY", "Weekly quest pool"), ("CHF", "Cooking challenges (incl. Legendary Recipe quests)"),
    ("CBT", "Combat challenges"), ("RPR", "Repair challenges"), ("EXP", "Exploration challenges"),
    ("EMP", "Employee management challenges"), ("RST", "Restaurant expansion challenges (incl. City Hall permits)"),
])
MINIMUMS = {"TUT": 12, "STY": 30, "DLY": 20, "WKY": 12, "CHF": 10, "CBT": 10, "RPR": 8, "EXP": 10, "EMP": 8, "RST": 10}

ID_RE = re.compile(
    r"(?<![A-Za-z0-9_])(?:RCP_(?:BRG|PIZ|TAC|SAN|SOP|PST|BRK|DES|DRK|SEA|SAL|FRI|ALN|MUT|LEG)_\d{3}|"
    r"ING_[A-Z0-9]+(?:_[A-Z0-9]+)*|MOD_\d{3}|STN_[A-Z]+(?:_[A-Z]+)*|PER_\d{3}|ABL_\d{3}|STS_[A-Z]+|"
    r"MUT_\d{3}|SYN_\d{3}|CMB_\d{3}|SKL_(?:CHEF|CMBT|RPR|SVC|MGMT)_\d{2}|ACH_\d{3}|MLS_\d{3}|TIER_\d{2}|"
    r"FRN_\d{3}|UPG_\d{3}|ROLE_[A-Z]+(?:_[A-Z]+)*|EMP_\d{3}|INC_\d{3}|DST_\d{2}|BLD_\d{2}|NPC_\d{3}|"
    r"QST_(?:TUT|STY|DLY|WKY|CHF|CBT|RPR|EXP|EMP|RST)_\d{3}|EVT_\d{3}|ANM_\d{3}|SFX_\d{3}|MUS_\d{3})"
    r"(?![A-Za-z0-9_])")
# Families A13 may never define or invent (EMP_001, trophies and canon-core ANM ids excepted).
FORBIDDEN = re.compile(r"^(?:SYN|CMB|SKL|ACH|MLS|UPG|INC|MOD|SFX|MUS)_")


def load_jsonl(path: Path) -> list[dict]:
    rows = []
    for i, ln in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        ln = ln.strip()
        if not ln or ln.startswith("//"):
            continue
        try:
            rows.append(json.loads(ln))
        except json.JSONDecodeError as e:
            sys.exit(f"{path.name}:{i}: bad JSON: {e}")
    return rows


def cell(s: str) -> str:
    return str(s).replace("|", "\\|").replace("\n", " ").strip()


def tick(i: str) -> str:
    return f"`{i}`"


def render_rewards(q: dict) -> str:
    rw = q.get("rw", {})
    parts = []
    if rw.get("sc"):
        parts.append(f"{rw['mb']}·IncH MB")
        parts.append(f"{rw['xp']}·XPR XP")
    elif "MB" in rw:
        for key in ("MB", "XP"):
            v = rw[key]
            if isinstance(v, str):
                parts.append(f"{v} {key}")
            elif v:
                parts.append(f"{v:,} {key}")
    else:
        if rw.get("mb"):
            parts.append(f"{fixed_mb(q):,} MB")
        if rw.get("xp"):
            parts.append(f"{fixed_xp(q):,} XP")
    if rw.get("ms"):
        parts.append(f"{rw['ms']} MS")
    if rw.get("rt"):
        parts.append(f"{rw['rt']} RT")
    if rw.get("cap"):
        parts.append(f"{rw['cap']} Morph Capsule" + ("s" if rw["cap"] != 1 else ""))
    if rw.get("sp"):
        parts.append(f"{rw['sp']} skill point" + ("s" if rw["sp"] != 1 else ""))
    parts.extend(rw.get("x", []))
    return " · ".join(parts)


ENTRY_L = {1: 1, 2: 5, 3: 10, 4: 18, 5: 26, 6: 35, 7: 45, 8: 56, 9: 68, 10: 80}
CUM_H = {1: 0, 2: 1, 3: 3, 4: 7, 5: 14, 6: 25, 7: 40, 8: 60, 9: 85, 10: 120, 11: 200}  # canon C4.4 (+ L100 ≈ 200 h)


def xpreq(level: int) -> int:
    return round((180 + 30 * level) * 1.045 ** (level - 1))


def scale_table() -> str:
    rows = ["| Tier | Entry L | IncH (MB/h) | Daily MB (0.02·IncH) | Daily XP (0.25·XPR) | Daily MS (2+T) | "
            "Weekly MB (0.08·IncH) | Weekly XP (0.5·XPR) | Weekly MS (5×T) | Weekly RT |",
            "|---|---|---|---|---|---|---|---|---|---|"]
    for t in range(1, 11):
        L = ENTRY_L[t]
        rows.append(f"| T{t} · `TIER_{t:02d}` | {L} | {INC[t]:,} | {nice(0.02 * INC[t]):,} | {nice(0.25 * xprate(L)):,} | "
                    f"{2 + t} | {nice(0.08 * INC[t]):,} | {nice(0.5 * xprate(L)):,} | {5 * t} | {1 + (t - 1) // 4} |")
    return "\n".join(rows)


def budget_table(quests: list[dict]) -> str:
    rows = ["| Tier | P_MB | P_XP | Hours in tier | Income in tier (MB) | One-time quests | Quest MB | MB share | "
            "XP to cross band | Quest XP | XP share |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    for t in range(1, 11):
        hours = CUM_H[t + 1] - CUM_H[t]
        income = INC[t] * hours
        lo, hi = ENTRY_L[t], (ENTRY_L[t + 1] if t < 10 else 100)
        xpband = sum(xpreq(L) for L in range(lo, hi))
        qs = [q for q in quests if q["id"][4:7] not in ("DLY", "WKY") and q.get("t") == t]
        mb = xp = 0
        for q in qs:
            rw = q["rw"]
            if "MB" in rw:
                mb += rw["MB"]
                xp += rw["XP"] if isinstance(rw["XP"], int) else 50  # formula XP counted at its 50 XP floor
            else:
                mb += fixed_mb(q)
                xp += fixed_xp(q)
        rows.append(f"| T{t} · `TIER_{t:02d}` | ×{P_MB[t]} | ×{P_XP[t]} | {hours} | {income:,} | {len(qs)} | {mb:,} | {100 * mb / income:.1f} % | "
                    f"{xpband:,} | {xp:,} | {100 * xp / xpband:.1f} % |")
    return "\n".join(rows)


def main() -> int:
    check = "--check" in sys.argv
    npcs = load_jsonl(DATA / "npcs.jsonl")
    quests = load_jsonl(DATA / "quests.jsonl")
    errors: list[str] = []

    npc_by = {}
    for n in npcs:
        if n["id"] in npc_by:
            errors.append(f"duplicate NPC {n['id']}")
        npc_by[n["id"]] = n
    q_by = {}
    for q in quests:
        if q["id"] in q_by:
            errors.append(f"duplicate quest {q['id']}")
        q_by[q["id"]] = q

    # NPC <-> quest cross links
    links: dict[str, set] = {k: set() for k in npc_by}
    for q in quests:
        for nid in [q["npc"]] + q.get("inv", []):
            if nid not in npc_by:
                errors.append(f"{q['id']}: unknown NPC {nid}")
            else:
                links[nid].add(q["id"])
        for tok in re.findall(r"QST_[A-Z]{3}_\d{3}", q.get("pre", "") + " " + q.get("cc", "")):
            if tok not in q_by:
                errors.append(f"{q['id']}: prerequisite/completion references unknown {tok}")
    for n in npcs:
        for qid in n.get("q", []):
            if qid not in q_by:
                errors.append(f"{n['id']}: unknown quest {qid}")
            else:
                links[n["id"]].add(qid)
        if not links[n["id"]]:
            errors.append(f"{n['id']} has no quest possibilities")

    # ---------- §19 ----------
    out = [FRAG.joinpath("19_intro.md").read_text(encoding="utf-8").rstrip(), ""]
    hdr = ("| ID | Name | Morph combination | Personality | Location | Role | Dialogue | "
           "Quest possibilities | Interaction behavior |\n|---|---|---|---|---|---|---|---|---|")
    for k, (dst, dname) in enumerate(DISTRICTS.items(), 1):
        rows = [n for n in npcs if n["dst"] == dst]
        out.append(f"#### 19.9.{k} {dname} (`{dst}`) — {len(rows)} NPCs\n")
        out.append(hdr)
        for n in rows:
            loc = tick(dst) + (" · " + tick(n["bld"]) if n.get("bld") else "")
            if n.get("at"):
                loc += f" ({n['at']})"
            lines = n["d"] if n["b"].startswith(("[STORY]", "[BOSS]")) else n["d"][:2]
            dlg = " / ".join(f"“{d}”" for d in lines)
            ql = ", ".join(sorted(links[n["id"]]))
            out.append("| " + " | ".join(cell(x) for x in [
                tick(n["id"]), f"**{n['n']}**", n["m"], n["p"], loc, n["r"], dlg, ql, n["b"]]) + " |")
        out.append("")
    out.append(FRAG.joinpath("19_outro.md").read_text(encoding="utf-8").rstrip())
    OUT19.write_text("\n".join(out) + "\n", encoding="utf-8")

    # ---------- §20 ----------
    intro20 = FRAG.joinpath("20_intro.md").read_text(encoding="utf-8").rstrip()
    sp_total = sum(q.get("rw", {}).get("sp", 0) for q in quests)
    intro20 = (intro20.replace("{{QUEST_TOTAL}}", str(len(quests)))
               .replace("{{SP_TOTAL}}", str(sp_total))
               .replace("{{SCALE_TABLE}}", scale_table())
               .replace("{{BUDGET_TABLE}}", budget_table(quests)))
    out = [intro20, ""]
    hdr = ("| ID | Name | Description | NPC | Location | Objectives | Prerequisites | "
           "Completion conditions | Rewards | Failure conditions |\n|---|---|---|---|---|---|---|---|---|---|")
    counts = Counter(q["id"][4:7] for q in quests)
    out.append("| Type | Code | Count | Minimum |\n|---|---|---|---|")
    for code, label in QTYPES.items():
        out.append(f"| {label} | {code} | {counts[code]} | {MINIMUMS[code]} |")
    out.append(f"| **Total** | — | **{len(quests)}** | 125 |\n")
    for k, (code, label) in enumerate(QTYPES.items(), 1):
        rows = [q for q in quests if q["id"][4:7] == code]
        out.append(f"#### 20.9.{k} {label} — {len(rows)} quests\n")
        out.append(hdr)
        for q in rows:
            g = npc_by.get(q["npc"], {"n": "?"})
            who = f"{tick(q['npc'])} {g['n']}"
            if q.get("inv"):
                who += " (with " + ", ".join(tick(x) for x in q["inv"]) + ")"
            objs = " ".join(f"{i}) {o}" for i, o in enumerate(q["o"], 1))
            out.append("| " + " | ".join(cell(x) for x in [
                tick(q["id"]), f"**{q['n']}**", q["de"], who, q["loc"], objs, q["pre"], q["cc"],
                render_rewards(q), q["f"]]) + " |")
        out.append("")
    out.append(FRAG.joinpath("20_outro.md").read_text(encoding="utf-8").rstrip())
    OUT20.write_text("\n".join(out) + "\n", encoding="utf-8")

    for code, m in MINIMUMS.items():
        if counts[code] < m:
            errors.append(f"quest type {code}: {counts[code]} < {m}")
    if len(npcs) < 110:
        errors.append(f"only {len(npcs)} NPCs (< 110)")
    sp_total = sum(q.get("rw", {}).get("sp", 0) for q in quests)
    if sp_total > 15:  # §14 skill-point budget: quests grant at most 15 in total
        errors.append(f"quest skill points total {sp_total} > 15")
    print(f"Skill points granted by quests: {sp_total} (budget 15)")

    if check:
        canon_text = CANON.read_text(encoding="utf-8")
        known = set(ID_RE.findall(canon_text)) | set(npc_by) | set(q_by)
        for path in (OUT19, OUT20):
            for i, ln in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for tok in ID_RE.findall(ln):
                    bad = tok not in known or FORBIDDEN.match(tok)
                    if tok.startswith("EMP_") and tok != "EMP_001":
                        bad = True
                    if tok.startswith("FRN_") and not re.fullmatch(r"FRN_9(0[1-9]|10)", tok):
                        bad = True
                    if tok.startswith("NPC_") and tok not in npc_by:
                        bad = True
                    if tok.startswith("QST_") and tok not in q_by:
                        bad = True
                    if bad:
                        errors.append(f"{path.name}:{i}: unresolved/forbidden ID {tok}")

    print(f"NPCs: {len(npcs)}  ->  {OUT19.relative_to(GDD.parent)} ({OUT19.stat().st_size:,} B)")
    print(f"Quests: {len(quests)} " + " ".join(f"{c}={counts[c]}" for c in QTYPES)
          + f"  ->  {OUT20.relative_to(GDD.parent)} ({OUT20.stat().st_size:,} B)")
    for e in errors:
        print("ERROR:", e)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

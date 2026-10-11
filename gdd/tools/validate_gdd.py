#!/usr/bin/env python3
"""Validate the Mystery Morph Restaurant GDD section sources.

Checks
  1. All 40 required sections exist, in order, with the exact Part-27 titles.
  2. Every identifier reference (RCP_, MUT_, ABL_, ...) resolves to a definition
     (an ID in the first cell of a table row, or an ID-led heading) somewhere in the document.
  3. Content counts meet the brief's minimums (completion manifest).
  4. Canonical master-list entries (recipes, mutations, personalities, abilities, events,
     buildings, key NPCs, tutorial quests) keep their canonical names.
  5. The nine required Mermaid diagrams are present (`%% diagram: <key>`).
  6. Per-section stats: size, acceptance criteria, [TUNABLE] markers.

Usage:  python3 gdd/tools/validate_gdd.py [--json OUT] [--quiet]
Exit code 1 if any hard check fails.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict

sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))
import gddlib as g  # noqa: E402

# Requirement -> (id family / regex over defined IDs, minimum, where)
COUNT_REQUIREMENTS = [
    ("Recipes (≥150 across ≥15 categories)", r"RCP_.*", 150, "§6, §36.2"),
    ("Ingredients (complete; all canon core IDs)", r"ING_.*", 48, "§7"),
    ("Order modifications (≥75)", r"MOD_.*", 75, "§6.18"),
    ("Kitchen stations (all 22 brief stations + 2 late-game)", r"STN_.*", 24, "§5"),
    ("Customer personalities (≥30)", r"PER_.*", 30, "§9"),
    ("Abilities (≥50 combat)", r"ABL_.*", 70, "§36.6"),
    ("Status effects", r"STS_.*", 20, "§36.7"),
    ("Mutation parts (≥250)", r"MUT_.*", 250, "§36.3"),
    ("Mutation synergies (≥75)", r"SYN_.*", 75, "§36.4"),
    ("Morph combination examples (≥100)", r"CMB_.*", 100, "§36.5"),
    ("Chef skill-tree upgrades (≥20)", r"SKL_CHEF_.*", 20, "§14"),
    ("Combat skill-tree upgrades (≥20)", r"SKL_CMBT_.*", 20, "§14"),
    ("Repair skill-tree upgrades (≥20)", r"SKL_RPR_.*", 20, "§14"),
    ("Customer-service specialization nodes", r"SKL_SVC_.*", 10, "§14"),
    ("Employee-management specialization nodes", r"SKL_MGMT_.*", 10, "§14"),
    ("Restaurant tiers (≥10)", r"TIER_.*", 10, "§15, §36.12"),
    ("Furniture & equipment (≥100 purchasable)", r"FRN_(?!9[0-9]{2}).*", 100, "§36.13"),
    ("Trophy decorations", r"FRN_9\d\d", 10, "§36.13"),
    ("Restaurant upgrades", r"UPG_.*", 40, "§36.12"),
    ("Employee roles (12)", r"ROLE_.*", 12, "§16, §36.1"),
    ("Employee archetypes (≥75)", r"EMP_.*", 75, "§36.8"),
    ("Offline incidents (≥50)", r"INC_.*", 50, "§36.9"),
    ("City districts (≥10)", r"DST_.*", 10, "§18, §36.1"),
    ("City buildings (≥16)", r"BLD_.*", 16, "§36.10"),
    ("Named NPCs (≥100)", r"NPC_.*", 100, "§19"),
    ("Quests (≥100)", r"QST_.*", 100, "§20"),
    ("City events (≥30)", r"EVT_.*", 30, "§36.11"),
    ("Animations (≥150)", r"ANM_.*", 150, "§36.14"),
    ("Sound effects", r"SFX_.*", 100, "§36.15"),
    ("Music tracks", r"MUS_.*", 10, "§36.15"),
    ("Achievements", r"ACH_.*", 50, "§36.16"),
    ("Progression milestones", r"MLS_.*", 30, "§36.17"),
]

CANON_NAME_CHECKS = [
    ("Recipes", r"RCP_[A-Z]{3}_\d{3}"),
    ("Mutation parts", r"MUT_\d{3}"),
    ("Personalities", r"PER_\d{3}"),
    ("Abilities", r"ABL_\d{3}"),
    ("Events", r"EVT_\d{3}"),
    ("Buildings", r"BLD_\d{2}"),
    ("Key NPCs", r"NPC_\d{3}"),
    ("Tutorial quests", r"QST_TUT_\d{3}"),
    ("Districts", r"DST_\d{2}"),
]


def check_sections(sections):
    problems, rows = [], []
    by_num = {s.number: s for s in sections if s.number is not None}
    last = 0
    for idx, title in enumerate(g.REQUIRED_SECTIONS, start=1):
        s = by_num.get(idx)
        if not s:
            problems.append(f"Missing section {idx}. {title}")
            rows.append((idx, title, None, False))
            continue
        ok_title = s.title == title
        if not ok_title:
            problems.append(f"Section {idx} title is '{s.title}', expected '{title}' ({s.name})")
        if idx < last:
            problems.append(f"Section {idx} out of order")
        last = idx
        rows.append((idx, title, s.name, ok_title))
    # Contribution files must start with an H3 that belongs to their section number.
    for s in sections:
        if s.number is None:
            first = s.lines[0] if s.lines else ""
            num = g.section_number_for_file(s.name)
            if not re.match(rf"^###\s+{num}\.\d+\s", first):
                problems.append(f"{s.name}: contribution file must start with '### {num}.N ...' (found: {first[:60]!r})")
    return problems, rows


def check_references(sections, defs, refs):
    undefined = {}
    for tok, locs in refs.items():
        if tok not in defs:
            undefined[tok] = locs
    return undefined


def check_counts(defs):
    rows = []
    ids = list(defs.keys())
    for label, rx, minimum, where in COUNT_REQUIREMENTS:
        r = re.compile(rf"^{rx}$")
        n = sum(1 for t in ids if r.match(t))
        rows.append((label, minimum, n, n >= minimum, where))
    # Recipe categories
    cats = Counter(t[4:7] for t in ids if t.startswith("RCP_"))
    rows.append(("Recipe categories (≥15)", 15, len(cats), len(cats) >= 15, "§6"))
    return rows


def check_canon_names(defs):
    issues = []
    for label, rx in CANON_NAME_CHECKS:
        canon = g.parse_canon_table(rx)
        for cid, cname in canon.items():
            if cid not in defs:
                issues.append(f"{label}: canonical {cid} ({cname}) is never defined")
                continue
            target = g.norm(re.sub(r"\(.*?\)", "", cname))
            if not target:
                continue
            if not any(target in g.norm(line) for _, _, line in defs[cid]):
                issues.append(f"{label}: {cid} definition does not carry canonical name '{cname}'")
    return issues


def check_diagrams(sections):
    found = defaultdict(list)
    total = 0
    for s in sections:
        inside, first = False, False
        for i, ln in enumerate(s.lines):
            st = ln.strip()
            if st.startswith("```mermaid"):
                inside, first = True, True
                total += 1
                continue
            if inside and st.startswith("```"):
                inside = False
                continue
            if inside and first:
                first = False
                m = re.match(r"%%\s*diagram:\s*([a-z0-9\-]+)", st)
                if m:
                    found[m.group(1)].append(s.name)
    rows = [(k, v, found.get(k, [])) for k, v in g.REQUIRED_DIAGRAMS.items()]
    return rows, total, dict(found)


def section_stats(sections):
    rows = []
    for s in sections:
        ac = len(set(re.findall(r"\bAC-\d{2}-\d{2,3}\b", s.text)))
        tun = s.text.count("[TUNABLE]")
        rows.append((s.name, len(s.text.encode("utf-8")), ac, tun))
    return rows


def run(quiet=False):
    sections = g.load_sections()
    defs = g.collect_definitions(sections)
    refs = g.collect_references(sections)
    sec_problems, sec_rows = check_sections(sections)
    undefined = check_references(sections, defs, refs)
    count_rows = check_counts(defs)
    canon_issues = check_canon_names(defs)
    diag_rows, diag_total, diag_found = check_diagrams(sections)
    stats = section_stats(sections)
    dup = {k: v for k, v in defs.items() if len({f for f, _, _ in v}) > 1}

    result = {
        "sections": sec_rows,
        "section_problems": sec_problems,
        "undefined": {k: v[:5] for k, v in sorted(undefined.items())},
        "undefined_count": len(undefined),
        "counts": count_rows,
        "canon_issues": canon_issues,
        "diagrams": diag_rows,
        "diagram_total": diag_total,
        "stats": stats,
        "definitions": len(defs),
        "references": sum(len(v) for v in refs.values()),
        "multi_file_definitions": len(dup),
    }
    hard_fail = bool(sec_problems or undefined or canon_issues
                     or any(not ok for _, _, _, ok, _ in count_rows)
                     or any(not f for _, _, f in diag_rows))
    result["ok"] = not hard_fail

    if not quiet:
        print(f"Sections: {len(sections)} files; definitions: {len(defs)}; references: {result['references']}")
        for p in sec_problems:
            print("  [SECTION]", p)
        print(f"Undefined references: {len(undefined)}")
        by_fam = defaultdict(list)
        for tok in sorted(undefined):
            by_fam[g.family_of(tok)].append(tok)
        for fam, toks in sorted(by_fam.items(), key=lambda kv: str(kv[0])):
            locs = sorted({f for t in toks for f, _ in undefined[t]})
            print(f"  [{fam}] {len(toks)}: {', '.join(toks[:25])}{' …' if len(toks) > 25 else ''}  in {', '.join(locs)}")
        print("Counts:")
        for label, minimum, n, ok, where in count_rows:
            print(f"  {'OK ' if ok else 'LOW'} {label}: {n} (min {minimum}) {where}")
        print(f"Canon name issues: {len(canon_issues)}")
        for c in canon_issues[:60]:
            print("  [CANON]", c)
        print(f"Mermaid diagrams: {diag_total} total")
        for k, desc, where in diag_rows:
            print(f"  {'OK ' if where else 'MISSING'} {k}: {', '.join(where)}")
        print("RESULT:", "PASS" if result["ok"] else "FAIL")
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="write machine-readable results to this path")
    ap.add_argument("--quiet", action="store_true")
    a = ap.parse_args()
    res = run(quiet=a.quiet)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as fh:
            json.dump(res, fh, indent=1, default=str)
    sys.exit(0 if res["ok"] else 1)


if __name__ == "__main__":
    main()

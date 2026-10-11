#!/usr/bin/env python3
"""Assemble MYSTERY_MORPH_RESTAURANT_GDD.md from gdd/sections/*.md.

Steps
  1. (optional, --render) run every gdd/tools/render_*.py so data-backed tables are fresh.
  2. Validate all sections (validate_gdd.run) and turn the results into a completion manifest.
  3. Generate the front matter (title, conventions, manifest, brief-coverage map, table of contents).
  4. Concatenate front matter + sections in filename order and write the final document.

Usage:  python3 gdd/tools/build_gdd.py [--render] [--allow-fail]
"""
from __future__ import annotations

import argparse
import datetime as dt
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gddlib as g  # noqa: E402
import validate_gdd  # noqa: E402

VERSION = "1.0"

PART_COVERAGE = [
    ("1 Game Identity", "§1 Executive Summary, §2 Game Vision, §3 Design Pillars"),
    ("2 Gameplay Loops (5 timescales, offline)", "§4 Core Gameplay Loops, §17"),
    ("3 Cooking System", "§5 Cooking Mechanics"),
    ("4 Recipe & Food Database, 4.16 Modifications", "§6 (6.1–6.17), §6.18, §7, §36.2"),
    ("5 Customer AI & Behavior", "§8, §9, §10"),
    ("6 Combat System", "§11, §36.6, §36.7"),
    ("7 Morph System", "§12 (12.1–12.10), §36.3, §36.4, §36.5"),
    ("8 Morph Customization Interface", "§13"),
    ("9 Player Progression", "§14, §36.16, §36.17"),
    ("10 Restaurant Building & Upgrades", "§15, §36.12, §36.13"),
    ("11 Employees & Offline Operations", "§16, §17, §36.8, §36.9"),
    ("12 Morph City", "§18, §19, §36.10, §36.11"),
    ("13 Quests & Missions", "§20"),
    ("14 Multiplayer", "§21"),
    ("15 Economy", "§22"),
    ("16 Monetization", "§23"),
    ("17 User Interface", "§24 (plus §13 morph screen, §17 Welcome Back screen)"),
    ("18 Art Direction, Animation, Sound", "§25, §26, §36.14, §36.15"),
    ("19 Roblox Technical Architecture", "§27, §28, §29, §30"),
    ("20 Analytics & Retention", "§31"),
    ("21 Tutorial / FTUE", "§32"),
    ("22 Content Expansion", "§33"),
    ("23 Complete Content Databases", "§36 (index in §36.1) plus §6, §7, §9, §19, §20"),
    ("24 Development Roadmap", "§34"),
    ("25 Testing & QA", "§35"),
    ("26 Cross-cutting Requirements", "§3 (Cross-Cutting Design Requirements) and every system section"),
    ("27 Output Structure", "This document: 40 numbered sections in the required order"),
    ("28 Execution Instructions", "Completion Manifest (below), gdd/tools/validate_gdd.py"),
]


def run_renderers():
    for script in sorted((g.GDD_DIR / "tools").glob("render_*.py")):
        print(f"render: {script.name}")
        subprocess.run([sys.executable, str(script)], cwd=g.ROOT, check=True)


APPENDIX_TITLE = "Appendix A. Design Canon — Identifiers, Constants and Formulas"


def canon_appendix() -> str:
    """The design canon, demoted one heading level, as the document's final appendix.

    Sections cite canon clauses as `canon C4.4` / `§C4.4`; this appendix is where those resolve.
    It is not used for identifier definitions (the validator reads gdd/sections only), so a missing
    database row can never be masked by the canon's master lists.
    """
    lines = g.CANON_PATH.read_text(encoding="utf-8").splitlines()
    mask = g.iter_code_fence_mask(lines)
    out = [f"## {APPENDIX_TITLE}", "",
           "> The canon is the single source of truth that every section above is built on: identifier rules, the fixed "
           "master lists, global constants, economy anchors, core formulas and edge-case rulings. References written "
           "as `canon C4.4` or `§C4.4` point to the numbered clauses below. Where a section elaborates a value, the "
           "section's detail governs only if it does not contradict this appendix.", ""]
    started = False
    for i, ln in enumerate(lines):
        if not started:
            if ln.startswith("# "):
                started = True
            continue
        if not mask[i] and ln.startswith("#"):
            ln = "#" + ln
        out.append(ln)
    return "\n".join(out).rstrip() + "\n"


class _Pseudo:
    def __init__(self, text):
        self.lines = text.splitlines()


def toc(sections, preceding_text: str) -> list[str]:
    seen: dict[str, int] = {}
    # Headings that precede the sections (front matter) consume anchor slugs first, as on GitHub.
    for ln in preceding_text.splitlines():
        if ln.startswith("#"):
            g.github_slug(ln.lstrip("#").strip(), seen)
    out = []
    for s in sections:
        mask = g.iter_code_fence_mask(s.lines)
        for i, ln in enumerate(s.lines):
            if mask[i] or not ln.startswith("#"):
                continue
            level = len(ln) - len(ln.lstrip("#"))
            text = ln[level:].strip()
            if level < 2 or level > 6:
                continue
            slug = g.github_slug(text, seen)
            if level == 2:
                out.append(f"- [{text}](#{slug})")
            elif level == 3:
                out.append(f"  - [{text}](#{slug})")
    return out


def manifest(res) -> list[str]:
    L = []
    status = "✅ PASS" if res["ok"] else "⚠️ ISSUES FOUND"
    L.append(f"**Automated validation:** {status} — {res['definitions']:,} defined identifiers, "
             f"{res['references']:,} identifier references, **{res['undefined_count']} unresolved**, "
             f"{len(res['canon_issues'])} canonical-name mismatches, {res['diagram_total']} Mermaid diagrams. "
             f"Re-run with `python3 gdd/tools/validate_gdd.py`.")
    L.append("")
    L.append("#### Content counts")
    L.append("")
    L.append("| Requirement | Minimum | Delivered | Status | Location |")
    L.append("|---|---|---|---|---|")
    for label, minimum, n, ok, where in res["counts"]:
        L.append(f"| {label} | {minimum} | {n} | {'✅' if ok else '❌'} | {where} |")
    L.append("")
    L.append("#### Required diagrams")
    L.append("")
    L.append("| Diagram | Key | Status | Source file |")
    L.append("|---|---|---|---|")
    for key, desc, where in res["diagrams"]:
        L.append(f"| {desc} | `{key}` | {'✅' if where else '❌'} | {', '.join(where) or '—'} |")
    L.append("")
    L.append("#### Sections")
    L.append("")
    L.append("| # | Section | Status |")
    L.append("|---|---|---|")
    for idx, title, name, ok in res["sections"]:
        L.append(f"| {idx} | {title} | {'✅' if name and ok else '❌'} |")
    L.append("")
    L.append("<details><summary>Source files, size, acceptance criteria and [TUNABLE] markers per file</summary>")
    L.append("")
    L.append("| Source file | Size (KB) | Acceptance criteria | [TUNABLE] markers |")
    L.append("|---|---|---|---|")
    tot_ac = tot_t = tot_b = 0
    for name, size, ac, tun in res["stats"]:
        L.append(f"| `gdd/sections/{name}` | {size/1024:.0f} | {ac} | {tun} |")
        tot_ac += ac
        tot_t += tun
        tot_b += size
    L.append(f"| **Total** | **{tot_b/1024:.0f}** | **{tot_ac}** | **{tot_t}** |")
    L.append("")
    L.append("</details>")
    if res["undefined_count"]:
        L.append("")
        L.append("Unresolved identifiers: " + ", ".join(f"`{k}`" for k in list(res["undefined"])[:50]))
    return L


def front_matter(sections, res) -> str:
    today = dt.date.today().isoformat()
    L = [
        "# MYSTERY MORPH RESTAURANT",
        "",
        "**Game Design Document & Roblox Development Specification**",
        "",
        "> *Serve. Cook. Upgrade. Survive.* — Everything should be just a little bit ridiculous.",
        "",
        "| Field | Value |",
        "|---|---|",
        "| Document | `MYSTERY_MORPH_RESTAURANT_GDD.md` |",
        f"| Version | {VERSION} (assembled {today}) |",
        "| Platform | Roblox (Luau), desktop · tablet · mobile · console |",
        "| Audience | Players aged ~8–16, with depth for older players |",
        "| Genre | Restaurant sim · cooking chaos · creature collection · character customization · action combat · tycoon · social · idle economy |",
        "| Sources | `gdd/sections/*.md` (prose), `gdd/data/*.json` (data-backed tables), `gdd/canon.md` (identifiers and constants), `gdd/brief/MASTER_PROMPT.md` (client brief) |",
        "",
        "## How to Use This Document",
        "",
        "- **Forty numbered sections** follow the structure required by the brief. Sections 1–4 explain the game, 5–26 specify "
        "every gameplay system, 27–31 are the technical specification, 32–35 cover onboarding, expansion, roadmap and QA, "
        "36 holds the content databases, and 37–40 hold checklists, open decisions, balancing assumptions and the definition of done.",
        "- **Identifiers** are stable, unique and cross-referenced everywhere (`RCP_BRG_001`, `MUT_216`, `ABL_018`, `EMP_001`, "
        "`QST_TUT_006` …). An identifier in the first column of a table row (or leading a heading) is the entity's *definition*; "
        "every other mention is a *reference* and resolves to exactly one definition. The full prefix list is in §36.1.",
        "- **`[TUNABLE]`** marks a balancing assumption: implement it as stated (systems depend on it) but expose it in "
        "configuration so it can be tuned with telemetry. §39 consolidates them.",
        "- **Acceptance criteria** are numbered `AC-<section>-<n>` and are measurable; §40 defines how they roll up into "
        "\"done\".",
        "- **Cross-references** use `§N` (section) and `§N.M` (subsection).",
        "- **Databases:** recipes §6, ingredients §7, personalities §9, NPCs §19, quests §20; everything else in §36.",
        "- **Canon references** (`canon C4.4`, `§C4.4`, `E1`–`E14`) point to Appendix A, the Design Canon: the shared "
        "identifiers, constants, formulas and edge-case rulings every section builds on.",
        "",
        "## Completion Manifest",
        "",
        "Generated automatically by `gdd/tools/build_gdd.py` from the validator, so the counts below are counted from "
        "this document and are never typed by hand.",
        "",
        *manifest(res),
        "",
        "## Brief Coverage Map",
        "",
        "| Brief Part | Where it is answered |",
        "|---|---|",
        *[f"| {p} | {w} |" for p, w in PART_COVERAGE],
        "",
        "## Table of Contents",
        "",
    ]
    head = "\n".join(L)
    return head + "\n" + "\n".join(toc(list(sections) + [_Pseudo(canon_appendix())], head)) + "\n\n---\n"


README_START, README_END = "<!-- sections:start -->", "<!-- sections:end -->"


def update_readme(sections):
    """Refresh the per-section reading index in GDD_README.md (between marker comments)."""
    readme = g.ROOT / "GDD_README.md"
    if not readme.exists():
        return
    text = readme.read_text(encoding="utf-8")
    if README_START not in text or README_END not in text:
        return
    rows = ["| Section | Source file | Size |", "|---|---|---|"]
    for s in sections:
        first = s.lines[0].lstrip("#").strip() if s.lines else s.name
        kb = len(s.text.encode("utf-8")) / 1024
        rows.append(f"| {first} | [`{s.name}`](gdd/sections/{s.name}) | {kb:.0f} KB |")
    rows.append(f"| Appendix A. Design Canon | [`canon.md`](gdd/canon.md) | {g.CANON_PATH.stat().st_size / 1024:.0f} KB |")
    head, rest = text.split(README_START, 1)
    _, tail = rest.split(README_END, 1)
    readme.write_text(head + README_START + "\n" + "\n".join(rows) + "\n" + README_END + tail, encoding="utf-8")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--render", action="store_true", help="re-run data renderers first")
    ap.add_argument("--allow-fail", action="store_true", help="write the document even if validation fails")
    a = ap.parse_args()
    if a.render:
        run_renderers()
    sections = g.load_sections()
    res = validate_gdd.run(quiet=True)
    fm = front_matter(sections, res)
    (g.SECTIONS_DIR / g.FRONT_MATTER).write_text(fm, encoding="utf-8")
    body = "\n\n".join(s.text.rstrip() + "\n" for s in sections)
    g.OUTPUT_PATH.write_text(fm + "\n" + body + "\n" + canon_appendix(), encoding="utf-8")
    update_readme(sections)
    size = g.OUTPUT_PATH.stat().st_size
    print(f"Wrote {g.OUTPUT_PATH.name}: {size/1024:.0f} KB, {len(sections)} section files, "
          f"validation {'PASS' if res['ok'] else 'FAIL'} ({res['undefined_count']} unresolved IDs)")
    if not res["ok"] and not a.allow_fail:
        sys.exit(1)


if __name__ == "__main__":
    main()

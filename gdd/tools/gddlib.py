"""Shared helpers for building and validating the Mystery Morph Restaurant GDD.

Stdlib only. Imported by build_gdd.py and validate_gdd.py.
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GDD_DIR = ROOT / "gdd"
SECTIONS_DIR = GDD_DIR / "sections"
CANON_PATH = GDD_DIR / "canon.md"
OUTPUT_PATH = ROOT / "MYSTERY_MORPH_RESTAURANT_GDD.md"
FRONT_MATTER = "00_front_matter.md"

# Section titles required by Part 27 of the brief, in order.
REQUIRED_SECTIONS = [
    "Executive Summary", "Game Vision", "Design Pillars", "Core Gameplay Loops",
    "Cooking Mechanics", "Recipe Database", "Ingredient Database", "Customer AI",
    "Customer Personalities", "Satisfaction and Tantrum Systems", "Combat System",
    "Mutation System", "Morph Customization", "Player Progression", "Restaurant Building",
    "Employee Management", "Offline Restaurant Simulation", "Morph City", "City NPCs",
    "Quests", "Multiplayer", "Economy", "Monetization", "UI/UX", "Art Direction",
    "Animation and Audio", "Roblox Architecture", "Data Persistence",
    "Security and Anti-Exploit", "Performance Optimization", "Analytics", "Tutorial",
    "Content Expansion", "Development Roadmap", "Testing and QA",
    "Content Database Appendices", "Implementation Checklists", "Open Design Decisions",
    "Balancing Assumptions", "Definition of Done",
]

# Mermaid diagrams required by Part 27 (key -> description).
REQUIRED_DIAGRAMS = {
    "core-gameplay-loop": "Core gameplay loop",
    "customer-state-machine": "Customer state machine",
    "cooking-workflow": "Cooking workflow",
    "combat-state-machine": "Combat state machine",
    "employee-management": "Employee management",
    "offline-earnings": "Offline earnings calculation",
    "player-progression": "Player progression",
    "service-architecture": "Roblox service architecture",
    "data-persistence-flow": "Data persistence flow",
}

# Identifier families: name -> regex. Word boundaries keep e.g. RCP_MUT_001 from matching MUT_001.
ID_PATTERNS: dict[str, str] = {
    "RCP": r"RCP_(?:BRG|PIZ|TAC|SAN|SOP|PST|BRK|DES|DRK|SEA|SAL|FRI|ALN|MUT|LEG)_\d{3}",
    "ING": r"ING_[A-Z0-9]+(?:_[A-Z0-9]+)*",
    "MOD": r"MOD_\d{3}",
    "STN": r"STN_[A-Z]+(?:_[A-Z]+)*",
    "PER": r"PER_\d{3}",
    "ABL": r"ABL_\d{3}",
    "STS": r"STS_[A-Z]+",
    "MUT": r"MUT_\d{3}",
    "SYN": r"SYN_\d{3}",
    "CMB": r"CMB_\d{3}",
    "SKL": r"SKL_(?:CHEF|CMBT|RPR|SVC|MGMT)_\d{2}",
    "ACH": r"ACH_\d{3}",
    "MLS": r"MLS_\d{3}",
    "TIER": r"TIER_\d{2}",
    "FRN": r"FRN_\d{3}",
    "UPG": r"UPG_\d{3}",
    "ROLE": r"ROLE_[A-Z]+(?:_[A-Z]+)*",
    "EMP": r"EMP_\d{3}",
    "INC": r"INC_\d{3}",
    "DST": r"DST_\d{2}",
    "BLD": r"BLD_\d{2}",
    "NPC": r"NPC_\d{3}",
    "QST": r"QST_(?:TUT|STY|DLY|WKY|CHF|CBT|RPR|EXP|EMP|RST)_\d{3}",
    "EVT": r"EVT_\d{3}",
    "ANM": r"ANM_\d{3}",
    "SFX": r"SFX_\d{3}",
    "MUS": r"MUS_\d{3}",
    "CSEC": r"CSEC_\d{2}",
    "CPROP": r"CPROP_\d{2}",
    "CPIX": r"CPIX_\d{2}",
}

ANY_ID_RE = re.compile(r"(?<![A-Za-z0-9_])(?:" + "|".join(f"(?:{p})" for p in ID_PATTERNS.values()) + r")(?![A-Za-z0-9_])")
FAMILY_RES = {k: re.compile(rf"^(?:{v})$") for k, v in ID_PATTERNS.items()}


def family_of(token: str) -> str | None:
    for fam, rx in FAMILY_RES.items():
        if rx.match(token):
            return fam
    return None


@dataclass
class Section:
    path: Path
    text: str
    number: int | None = None
    title: str | None = None
    lines: list[str] = field(default_factory=list)

    @property
    def name(self) -> str:
        return self.path.name


def load_sections() -> list[Section]:
    out = []
    for p in sorted(SECTIONS_DIR.glob("*.md")):
        if p.name == FRONT_MATTER:
            continue
        text = p.read_text(encoding="utf-8")
        s = Section(path=p, text=text, lines=text.splitlines())
        m = re.match(r"^##\s+(\d+)\.\s+(.+?)\s*$", s.lines[0] if s.lines else "")
        if m:
            s.number, s.title = int(m.group(1)), m.group(2)
        out.append(s)
    return out


def section_number_for_file(name: str) -> int | None:
    m = re.match(r"^(\d{2})", name)
    return int(m.group(1)) if m else None


CELL_STRIP = re.compile(r"[`*_\[\]]|\(#[^)]*\)")


def first_cell(line: str) -> str | None:
    """Return the stripped first cell of a markdown table row, or None."""
    s = line.strip()
    if not s.startswith("|") or re.match(r"^\|\s*:?-{2,}", s):
        return None
    parts = s.split("|")
    if len(parts) < 3:
        return None
    cell = parts[1].strip()
    # Keep underscores inside IDs: strip only backticks/bold markers/links.
    cell = cell.replace("`", "").replace("**", "").strip()
    cell = re.sub(r"^\[(.+?)\]\(.*?\)$", r"\1", cell)
    return cell


HEADING_ID_RE = re.compile(r"^#{2,6}\s+`?(" + ANY_ID_RE.pattern + r")`?(?:\s|$|[—:\-–])")


def iter_code_fence_mask(lines: list[str]) -> list[bool]:
    """True for lines inside fenced code blocks."""
    mask, inside = [], False
    for ln in lines:
        if ln.strip().startswith("```"):
            mask.append(True)
            inside = not inside
            continue
        mask.append(inside)
    return mask


def collect_definitions(sections: list[Section]) -> dict[str, list[tuple[str, int, str]]]:
    """ID -> list of (file, line_no, line) where it is defined (first table cell or heading)."""
    defs: dict[str, list[tuple[str, int, str]]] = {}
    for s in sections:
        mask = iter_code_fence_mask(s.lines)
        for i, ln in enumerate(s.lines):
            if mask[i]:
                continue
            cell = first_cell(ln)
            tok = None
            if cell is not None:
                m = re.fullmatch(ANY_ID_RE.pattern, cell)
                if m:
                    tok = cell
            else:
                hm = HEADING_ID_RE.match(ln)
                if hm:
                    tok = hm.group(1)
            if tok:
                defs.setdefault(tok, []).append((s.name, i + 1, ln))
    return defs


def collect_references(sections: list[Section]) -> dict[str, list[tuple[str, int]]]:
    refs: dict[str, list[tuple[str, int]]] = {}
    for s in sections:
        for i, ln in enumerate(s.lines):
            for m in ANY_ID_RE.finditer(ln):
                refs.setdefault(m.group(0), []).append((s.name, i + 1))
    return refs


def parse_canon_table(prefix_regex: str, name_col: int = 1) -> dict[str, str]:
    """Parse canon.md tables whose first cell is an ID matching prefix_regex. Returns ID -> name cell."""
    out: dict[str, str] = {}
    if not CANON_PATH.exists():
        return out
    for ln in CANON_PATH.read_text(encoding="utf-8").splitlines():
        cell = first_cell(ln)
        if cell and re.fullmatch(prefix_regex, cell):
            parts = [p.strip() for p in ln.strip().split("|")[1:-1]]
            if len(parts) > name_col:
                out[cell] = parts[name_col].replace("`", "").strip()
    return out


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "", s.lower())


def github_slug(text: str, seen: dict[str, int]) -> str:
    t = text.strip().lower()
    t = re.sub(r"[`*~]", "", t)
    t = re.sub(r"\[(.*?)\]\(.*?\)", r"\1", t)
    t = re.sub(r"[^\w\- ]", "", t, flags=re.UNICODE)
    t = t.replace(" ", "-")
    base = t
    n = seen.get(base, 0)
    seen[base] = n + 1
    return base if n == 0 else f"{base}-{n}"

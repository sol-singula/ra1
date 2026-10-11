#!/usr/bin/env python3
"""Shared canon readers for the A11 (Employees / Offline) tools.

Python 3 stdlib only. Every constant the A11 tools need from the canon is parsed
from gdd/canon.md at run time so the tools can never drift from the canon.

Used by:
  gdd/tools/render_employees.py      -> gdd/sections/36_08_employee_archetypes.md
  gdd/tools/render_incidents.py      -> gdd/sections/36_09_offline_incidents.md
  gdd/tools/offline_sim_examples.py  -> worked examples printed for section 17
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CANON = os.path.join(ROOT, "gdd", "canon.md")
DATA = os.path.join(ROOT, "gdd", "data")
SECTIONS = os.path.join(ROOT, "gdd", "sections")


def _canon_text():
    with open(CANON, encoding="utf-8") as f:
        return f.read()


def _num(s):
    return float(s.replace(",", "").strip())


def mutations():
    """C13.6 -> {MUT_id: {name, slot, category, rarity, family, tags[], active}}"""
    rows = re.findall(
        r"^\| `(MUT_\d{3})` \| ([^|]+) \| (\w+) \| (\w+) \| (\w+) \| (\w+) \| ([^|]+) \| ([^|]+) \|$",
        _canon_text(), re.M)
    out = {}
    for r in rows:
        out[r[0]] = {
            "name": r[1].strip(), "slot": r[2], "category": r[3], "rarity": r[4],
            "family": r[5], "tags": [t.strip() for t in r[6].split(",")],
            "active": r[7].strip().strip("`"),
        }
    assert len(out) == 280, len(out)
    return out


def tiers():
    """C6 -> {n: {...}} plus C4.4 active net / hour."""
    txt = _canon_text()
    out = {}
    for m in re.finditer(
            r"^\| `TIER_(\d{2})` \| ([^|]+) \| ([\d,]+|0 \(start\)) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \| (\d+) \|$",
            txt, re.M):
        n = int(m.group(1))
        out[n] = {
            "id": "TIER_%02d" % n, "name": m.group(2).strip(),
            "cost": 0 if "start" in m.group(3) else int(_num(m.group(3))),
            "req_level": int(m.group(4)), "seats": int(m.group(5)),
            "appliance_slots": int(m.group(6)), "menu_slots": int(m.group(7)),
            "employee_cap": int(m.group(8)), "base_demand": int(m.group(9)),
        }
    for m in re.finditer(r"^\| TIER_(\d{2}) \| (\d+) \| (\d+) \| ([\d,]+) \| ([\d,—]+) \|$", txt, re.M):
        out[int(m.group(1))]["active_net"] = int(_num(m.group(4)))
    assert len(out) == 10 and all("active_net" in t for t in out.values())
    return out


def rarity_bands():
    """C4.8 -> {rarity: {hire:(lo,hi), wage:(lo,hi), stat:(lo,hi), cap, typical}}"""
    out = {}
    for m in re.finditer(
            r"^\| (Common|Uncommon|Rare|Epic|Legendary) \| ([\d,]+)–([\d,]+) \| (\d+)–([\d,]+) \| (\d+)–(\d+) \| (\d+) \| (T\d+–T\d+) \|$",
            _canon_text(), re.M):
        out[m.group(1)] = {
            "hire": (int(_num(m.group(2))), int(_num(m.group(3)))),
            "wage": (int(_num(m.group(4))), int(_num(m.group(5)))),
            "stat": (int(m.group(6)), int(m.group(7))),
            "cap": int(m.group(8)), "typical": m.group(9),
        }
    assert len(out) == 5, out
    return out


def recipes():
    """C10 -> {RCP_id: {name, level, cat}}"""
    out = {}
    for m in re.finditer(r"^\| `(RCP_([A-Z]{3})_\d{3})` \| ([^|]+) \| (\d+) \|$", _canon_text(), re.M):
        out[m.group(1)] = {"name": m.group(3).strip(), "level": int(m.group(4)), "cat": m.group(2)}
    assert len(out) == 150, len(out)
    return out


ID_PATTERN = re.compile(
    r"\b(RCP_[A-Z]{3}_\d{3}|ING_[A-Z][A-Z_]*[A-Z]|MOD_\d{3}|STN_[A-Z][A-Z_]*[A-Z]|PER_\d{3}|ABL_\d{3}|"
    r"STS_[A-Z]+|MUT_\d{3}|SYN_\d{3}|CMB_\d{3}|SKL_[A-Z]+_\d{2}|ACH_\d{3}|MLS_\d{3}|TIER_\d{2}|"
    r"FRN_\d{3}|UPG_\d{3}|ROLE_[A-Z][A-Z_]*[A-Z]|EMP_\d{3}|INC_\d{3}|DST_\d{2}|BLD_\d{2}|NPC_\d{3}|"
    r"QST_[A-Z]{3}_\d{3}|EVT_\d{3}|ANM_\d{3}|SFX_\d{3}|MUS_\d{3})\b")


def canon_ids():
    """Every ID token that appears anywhere in the canon (treated as defined)."""
    return set(ID_PATTERN.findall(_canon_text()))

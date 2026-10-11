#!/usr/bin/env python3
"""check_synergies.py - validator for Mystery Morph Restaurant §12.9 / §12.10 / §36.4 / §36.5.

Python 3 standard library only. Run from the repository root:

    python3 gdd/tools/check_synergies.py            # validate, exit 0 when clean
    python3 gdd/tools/check_synergies.py --stats    # also print coverage + Morphdex statistics
    python3 gdd/tools/check_synergies.py --verbose  # also print every combo's evaluation

Checks
  (a) every synergy requirement - and every OR-branch of it - is satisfiable by canon parts under
      the slot rules (one part per anatomy slot, two arms, two legs, FUR xor SCALES, mandatory slots);
  (b) every synergy's example parts exist, fit together legally, satisfy the requirement, and each
      example part contributes to at least one atom of the requirement;
  (c) every combo's parts exist and are slot-valid (unlisted TORSO/ARM/LEG = Plain Human defaults);
  (d) the synergies listed for every combo are exactly the ones its parts trigger, and the
      active / suppressed split matches the §12.10 resolution rules (stacking group, max 5 active);
  plus: the §12.9 naming algorithm reproduces every combo's Morphdex key and display name
  (generated vs signature), the 12.10 effect-type vocabulary covers every effect used, every ID token
  in the A8 files resolves to canon or to an A8 definition, and the minimum counts are met.
"""
from __future__ import annotations

import collections
import os
import re
import sys

# ----------------------------------------------------------------------------- paths
HERE = os.path.dirname(os.path.abspath(__file__))
GDD = os.path.dirname(HERE)
CANON = os.path.join(GDD, "canon.md")
SECTIONS = os.path.join(GDD, "sections")
F_12B = os.path.join(SECTIONS, "12b_combinations_synergies.md")
F_13 = os.path.join(SECTIONS, "13_morph_customization.md")
F_SYN = os.path.join(SECTIONS, "36_04_mutation_synergies.md")
F_CMB = os.path.join(SECTIONS, "36_05_morph_combinations.md")
A8_FILES = [F_12B, F_13, F_SYN, F_CMB]

MIN_SYNERGIES = 80
MIN_COMBOS = 110
MAX_ACTIVE = 5

# ----------------------------------------------------------------------------- slot model (canon C13.1)
SLOTS = ["HEAD", "FACE", "NOSE", "MOUTH", "EYES", "EARS", "HORNS", "NECK", "TORSO", "ARM_L", "ARM_R",
         "HANDS", "LEG_L", "LEG_R", "FEET", "TAIL", "WINGS", "BACK", "SKIN", "FUR", "SCALES", "FX"]
MANDATORY = ["HEAD", "TORSO", "ARM_L", "ARM_R", "LEG_L", "LEG_R"]
DEFAULTS = {"TORSO": "MUT_117", "ARM_L": "MUT_139", "ARM_R": "MUT_139", "LEG_L": "MUT_179", "LEG_R": "MUT_179"}
NON_FX = [s for s in SLOTS if s != "FX"]
SCOPES = {s: [s] for s in SLOTS}
SCOPES.update({
    "ANY": NON_FX,
    "ARM": ["ARM_L", "ARM_R"],
    "LEG": ["LEG_L", "LEG_R"],
    "COVER": ["SKIN", "FUR", "SCALES"],
    "G_HEAD": ["HEAD", "FACE", "NOSE", "MOUTH"],
    "G_EARS": ["EARS", "HORNS"],
    "G_EYES": ["EYES"],
    "G_ARMS": ["ARM_L", "ARM_R", "HANDS"],
    "G_LEGS": ["LEG_L", "LEG_R", "FEET"],
    "G_TAILS": ["TAIL"],
    "G_EXTRAS": ["NECK", "TORSO", "WINGS", "BACK", "SKIN", "FUR", "SCALES"],
})
RARITY_RANK = {"Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 4, "Legendary": 5, "Mythic": 6, "Secret": 5}
NEUTRAL_FAMILIES = {"human"}
CONTEXTS = {"cook", "combat", "repair", "move", "social"}
ID_PREFIXES = ("MUT", "SYN", "CMB", "ABL", "STS", "STN", "PER", "BLD", "DST", "NPC", "EVT", "RCP", "ING", "QST",
               "EMP", "FRN", "ANM", "SFX", "MUS", "TIER", "ROLE", "SKL", "ACH", "MLS", "UPG", "INC", "MOD")
ID_TOKEN = re.compile(r"\b(?:%s)_[A-Z0-9_]*[A-Z0-9]\b" % "|".join(ID_PREFIXES))


def slot_code_fits(code: str, inst: str) -> bool:
    if code == "ARM":
        return inst in ("ARM_L", "ARM_R")
    if code == "LEG":
        return inst in ("LEG_L", "LEG_R")
    return code == inst


# ----------------------------------------------------------------------------- markdown helpers
def read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def split_row(line: str) -> list[str]:
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in line.split("|")]


def clean(cell: str) -> str:
    return cell.replace("`", "").replace("*", "").strip()


def find_table(text: str, header: list[str]) -> list[list[str]]:
    """Return body rows of the first table whose header starts with `header` (case-insensitive)."""
    lines = text.splitlines()
    want = [h.lower() for h in header]
    for i, line in enumerate(lines):
        if not line.lstrip().startswith("|"):
            continue
        cells = [clean(c).lower() for c in split_row(line)]
        if cells[: len(want)] == want:
            rows = []
            for nxt in lines[i + 2:]:
                if not nxt.lstrip().startswith("|"):
                    break
                rows.append(split_row(nxt))
            return rows
    return []


def id_rows(text: str, prefix: str) -> list[list[str]]:
    rows = []
    for line in text.splitlines():
        if re.match(r"^\|\s*`?%s_\d{3}`?\s*\|" % prefix, line):
            rows.append(split_row(line))
    return rows


# ----------------------------------------------------------------------------- canon
class Part:
    __slots__ = ("id", "name", "slot", "cat", "rar", "fam", "tags", "act")

    def __init__(self, pid, name, slot, cat, rar, fam, tags, act):
        self.id, self.name, self.slot, self.cat, self.rar, self.fam = pid, name, slot, cat, rar, fam
        self.tags, self.act = tags, act

    def __repr__(self):
        return self.id


def load_canon():
    text = read(CANON)
    parts = {}
    for line in text.splitlines():
        m = re.match(r"^\|\s*`(MUT_\d{3})`\s*\|(.*)\|\s*$", line)
        if not m:
            continue
        cells = [c.strip() for c in m.group(2).split("|")]
        if len(cells) != 7:
            continue
        name, slot, cat, rar, fam, tags, act = cells
        parts[m.group(1)] = Part(m.group(1), name, slot, cat, rar, fam,
                                 frozenset(t.strip() for t in tags.split(",") if t.strip()), act.strip("`"))
    tokens = set(ID_TOKEN.findall(text))
    tokens |= {"ANM_%03d" % n for n in range(301, 371)}  # C21: ANM_301-ANM_370 mirror ABL_001-ABL_070
    return parts, tokens


# ----------------------------------------------------------------------------- requirement grammar (§12.10)
ATOM_RE = re.compile(r"^(family|tag|category|rarity|slot|pair|distinct):([A-Za-z0-9_+]+)(?:@([A-Z_]+))?(?:(>=|<=)(\d+))?$")


class Atom:
    __slots__ = ("kind", "values", "scope", "cmp", "n", "text")

    def __init__(self, text):
        m = ATOM_RE.match(text)
        if not m:
            raise ValueError("bad atom '%s'" % text)
        self.text = text
        self.kind = m.group(1)
        self.values = m.group(2).split("+")
        self.scope = m.group(3) or "ANY"
        self.cmp = m.group(4) or ">="
        self.n = int(m.group(5)) if m.group(5) else 1
        if self.scope not in SCOPES:
            raise ValueError("unknown scope '%s' in '%s'" % (self.scope, text))
        if self.kind == "slot":
            if self.values[0] not in SCOPES or m.group(3):
                raise ValueError("slot atom takes a scope as value: '%s'" % text)
            self.scope = self.values[0]
        if self.kind == "pair" and self.values[0] not in ("ARM", "LEG"):
            raise ValueError("pair atom must be pair:ARM or pair:LEG: '%s'" % text)
        if self.kind == "distinct" and self.values[0] not in ("family", "category"):
            raise ValueError("distinct atom must be distinct:family or distinct:category: '%s'" % text)
        if self.kind == "rarity" and self.values[0] not in RARITY_RANK:
            raise ValueError("unknown rarity in '%s'" % text)

    def instances(self):
        if self.kind == "pair":
            return SCOPES[self.values[0]]
        return SCOPES[self.scope]

    def neutral(self, p: Part) -> bool:
        """Plain Human defaults are neutral filler: ignored by every atom except an explicit family:human."""
        return p.fam in NEUTRAL_FAMILIES and not (self.kind == "family" and p.fam in self.values)

    def part_matches(self, p: Part) -> bool:
        """Does part p satisfy the value predicate (ignoring scope)?"""
        if self.neutral(p):
            return False
        k, v = self.kind, self.values
        if k == "family":
            return all(p.fam == x for x in v)
        if k == "tag":
            return all(x in p.tags for x in v)
        if k == "category":
            return all(p.cat == x for x in v)
        if k == "rarity":
            return RARITY_RANK[p.rar] >= RARITY_RANK[v[0]]
        return True  # slot / distinct / pair: any occupant

    def contributes(self, p: Part, inst: str) -> bool:
        return inst in self.instances() and self.part_matches(p)

    def value(self, lo: dict) -> int:
        insts = self.instances()
        if self.kind == "pair":
            a, b = lo.get(insts[0]), lo.get(insts[1])
            ok = a is not None and b is not None and a.id == b.id and not self.neutral(a)
            return 1 if ok else 0
        if self.kind == "distinct":
            vals = set()
            for i in insts:
                p = lo.get(i)
                if p is None or self.neutral(p):
                    continue
                vals.add(p.fam if self.values[0] == "family" else p.cat)
            return len(vals)
        return sum(1 for i in insts if lo.get(i) is not None and self.part_matches(lo[i]))

    def holds(self, lo: dict) -> bool:
        v = self.value(lo)
        return v >= self.n if self.cmp == ">=" else v <= self.n


def tokenize(req: str):
    return re.findall(r"\(|\)|\bAND\b|\bOR\b|[a-z]+:[^\s()]+", req)


def parse_req(req: str):
    toks = tokenize(req)
    if "".join(toks).replace(" ", "") != req.replace(" ", ""):
        raise ValueError("unparseable characters in requirement '%s'" % req)
    pos = 0

    def peek():
        return toks[pos] if pos < len(toks) else None

    def p_or():
        nonlocal pos
        node = [p_and()]
        while peek() == "OR":
            pos += 1
            node.append(p_and())
        return node[0] if len(node) == 1 else ("or", node)

    def p_and():
        nonlocal pos
        node = [p_term()]
        while peek() == "AND":
            pos += 1
            node.append(p_term())
        return node[0] if len(node) == 1 else ("and", node)

    def p_term():
        nonlocal pos
        t = peek()
        if t == "(":
            pos += 1
            node = p_or()
            if peek() != ")":
                raise ValueError("missing ')' in '%s'" % req)
            pos += 1
            return node
        if t is None or t in ("AND", "OR", ")"):
            raise ValueError("unexpected token '%s' in '%s'" % (t, req))
        pos += 1
        return ("atom", Atom(t))

    tree = p_or()
    if pos != len(toks):
        raise ValueError("trailing tokens in '%s'" % req)
    return tree


def evaluate(tree, lo) -> bool:
    if tree[0] == "atom":
        return tree[1].holds(lo)
    if tree[0] == "and":
        return all(evaluate(t, lo) for t in tree[1])
    return any(evaluate(t, lo) for t in tree[1])


def atoms_of(tree):
    if tree[0] == "atom":
        return [tree[1]]
    out = []
    for t in tree[1]:
        out += atoms_of(t)
    return out


def dnf(tree):
    if tree[0] == "atom":
        return [[tree[1]]]
    if tree[0] == "or":
        out = []
        for t in tree[1]:
            out += dnf(t)
        return out
    out = [[]]
    for t in tree[1]:
        out = [a + b for a in out for b in dnf(t)]
    return out


# ----------------------------------------------------------------------------- satisfiability solver (check a)
def solve(clause, parts, node_limit=400000):
    """Find a legal loadout satisfying every atom of `clause` (a conjunction). Returns loadout or None."""
    by_code = collections.defaultdict(list)
    for p in parts.values():
        by_code[p.slot].append(p)
    pairs = {a.values[0] for a in clause if a.kind == "pair"}
    # virtual instances: tuple of real instances filled together
    virtual = []
    for inst in SLOTS:
        if inst in ("ARM_R", "LEG_R"):
            continue
        if inst in ("FUR", "SCALES"):
            continue
        if inst == "ARM_L":
            virtual += [("ARM_L", "ARM_R")] if "ARM" in pairs else [("ARM_L",), ("ARM_R",)]
            continue
        if inst == "LEG_L":
            virtual += [("LEG_L", "LEG_R")] if "LEG" in pairs else [("LEG_L",), ("LEG_R",)]
            continue
        virtual.append((inst,))
    virtual.append(("COVER2",))  # FUR xor SCALES

    def options(v):
        insts = v
        if v == ("COVER2",):
            opts = [None] + [("FUR", p) for p in by_code["FUR"]] + [("SCALES", p) for p in by_code["SCALES"]]
        else:
            code = insts[0] if insts[0] not in ("ARM_L", "ARM_R", "LEG_L", "LEG_R") else insts[0][:3]
            opts = [(None, p) for p in by_code[code]]
            if insts[0] not in MANDATORY:
                opts = [None] + opts
        # group by signature
        groups = {}
        for o in opts:
            if o is None:
                groups.setdefault(("none",), None)
                continue
            real, p = o
            reals = (real,) if real else insts
            sig = []
            for a in clause:
                sig.append(tuple(a.contributes(p, r) for r in reals))
                if a.kind == "distinct":
                    sig.append(p.cat if a.values[0] == "category" else p.fam)
            groups.setdefault(tuple(sig), (reals, p))
        return list(groups.values())

    opt_lists = [options(v) for v in virtual]

    def contrib_score(o):
        if o is None:
            return 0
        reals, p = o
        return sum(1 for a in clause if a.cmp == ">=" for r in reals if a.contributes(p, r))

    for ol in opt_lists:
        ol.sort(key=lambda o: -contrib_score(o))
    lo = {}
    nodes = [0]
    seen = set()

    def state_key(idx):
        vals = []
        for a in clause:
            v = a.value(lo)
            vals.append(min(v, a.n + 1))
        return (idx, tuple(vals))

    def feasible(idx):
        for a in clause:
            v = a.value(lo)
            if a.cmp == "<=":
                if v > a.n:
                    return False
                continue
            remaining = 0
            for ol, v_ in zip(opt_lists[idx:], virtual[idx:]):
                best = 0
                for o in ol:
                    if o is None:
                        continue
                    reals, p = o
                    best = max(best, sum(1 for r in reals if a.contributes(p, r)))
                remaining += best
            if a.kind == "pair":
                remaining = 1 if remaining else 0
            if v + remaining < a.n:
                return False
        return True

    def dfs(idx):
        nodes[0] += 1
        if nodes[0] > node_limit:
            raise TimeoutError
        if idx == len(virtual):
            return all(a.holds(lo) for a in clause)
        key = state_key(idx)
        if key in seen:
            return False
        if not feasible(idx):
            seen.add(key)
            return False
        for o in opt_lists[idx]:
            placed = []
            if o is not None:
                reals, p = o
                for r in reals:
                    lo[r] = p
                    placed.append(r)
            if dfs(idx + 1):
                return True
            for r in placed:
                del lo[r]
        seen.add(key)
        return False

    try:
        return dict(lo) if dfs(0) else None
    except TimeoutError:
        return "TIMEOUT"


# ----------------------------------------------------------------------------- loadouts
def parse_part_list(cell: str, parts, errors, where):
    """'MUT_145 ×2, MUT_102' -> list of Part (repeats expanded)."""
    out = []
    for chunk in [c.strip() for c in cell.split(",") if c.strip()]:
        m = re.match(r"^`?(MUT_\d{3})`?(?:\s*[×x]\s*(\d))?$", chunk)
        if not m:
            errors.append("%s: cannot parse part token '%s'" % (where, chunk))
            continue
        if m.group(1) not in parts:
            errors.append("%s: unknown part %s" % (where, m.group(1)))
            continue
        out += [parts[m.group(1)]] * int(m.group(2) or 1)
    return out


def auto_assign(plist, errors, where):
    lo = {}
    for p in plist:
        if p.slot == "ARM":
            targets = ["ARM_L", "ARM_R"]
        elif p.slot == "LEG":
            targets = ["LEG_L", "LEG_R"]
        else:
            targets = [p.slot]
        free = [t for t in targets if t not in lo]
        if not free:
            errors.append("%s: no free slot for %s (%s)" % (where, p.id, p.slot))
            continue
        lo[free[0]] = p
    if "FUR" in lo and "SCALES" in lo:
        errors.append("%s: FUR and SCALES are mutually exclusive" % where)
    return lo


def with_defaults(lo, parts):
    out = dict(lo)
    for inst, pid in DEFAULTS.items():
        out.setdefault(inst, parts[pid])
    return out


def parse_combo_parts(cell, parts, errors, where):
    lo = {}
    for seg in [s.strip() for s in cell.split(";") if s.strip()]:
        m = re.match(r"^([A-Z_]+)\s*:\s*`?(MUT_\d{3})`?(?:\s*[×x]\s*(2))?$", seg)
        if not m:
            errors.append("%s: cannot parse '%s'" % (where, seg))
            continue
        slot, pid, twice = m.group(1), m.group(2), m.group(3)
        if pid not in parts:
            errors.append("%s: unknown part %s" % (where, pid))
            continue
        p = parts[pid]
        if slot in ("ARM", "LEG"):
            targets = [slot + "_L", slot + "_R"] if twice else None
            if not twice:
                errors.append("%s: '%s:' needs ×2 (use %s_L/%s_R for single sides)" % (where, slot, slot, slot))
                continue
        else:
            if twice:
                errors.append("%s: ×2 only allowed on ARM/LEG" % where)
            targets = [slot]
        for t in targets:
            if t not in SLOTS:
                errors.append("%s: unknown slot %s" % (where, t))
                continue
            if not slot_code_fits(p.slot, t):
                errors.append("%s: %s is a %s part, cannot go in %s" % (where, pid, p.slot, t))
                continue
            if t in lo:
                errors.append("%s: slot %s filled twice" % (where, t))
                continue
            lo[t] = p
    if "FUR" in lo and "SCALES" in lo:
        errors.append("%s: FUR and SCALES are mutually exclusive" % where)
    if "HEAD" not in lo:
        errors.append("%s: HEAD must be listed" % where)
    return with_defaults(lo, parts)


# ----------------------------------------------------------------------------- 12b rule tables
class Rules:
    def __init__(self, text):
        self.words, self.loud = {}, set()
        for r in find_table(text, ["Family", "Name word", "Loud prefix"]):
            fam = clean(r[0])
            self.words[fam] = clean(r[1])
            if clean(r[2]).lower().startswith("yes"):
                self.loud.add(fam)
        self.dominance = {}
        for r in find_table(text, ["Slot", "Name dominance"]):
            for code in re.split(r"[,/ ]+", clean(r[0])):
                if code:
                    self.dominance[code] = float(clean(r[1]))
        self.bonus = {clean(r[0]): float(clean(r[1])) for r in find_table(text, ["Rarity", "Name bonus"])}
        self.priority = []
        for r in find_table(text, ["Tie-break slot order"]):
            self.priority = [c.strip() for c in clean(r[0]).split(">")]
        self.signatures = []
        for r in find_table(text, ["Signature title", "Rule (grammar)"]):
            self.signatures.append((clean(r[0]), clean(r[1]), parse_req(clean(r[1]))))
        self.effect_types = {clean(r[0]) for r in find_table(text, ["Effect type", "Meaning"])}

    def word(self, fam):
        return self.words.get(fam, fam.replace("_", " ").title().replace(" ", "-"))

    def dom(self, inst):
        key = inst[:3] if inst[:4] in ("ARM_", "LEG_") else inst
        return self.dominance.get(key, 0.0)


def morph_name(lo, rules: Rules):
    """Returns (key, spoken_generated, signature_title_or_None)."""
    lead = lo["HEAD"].fam
    score = collections.defaultdict(float)
    best = collections.defaultdict(float)
    prio = {}
    order = rules.priority or NON_FX
    for inst, p in lo.items():
        if inst in ("HEAD", "FX") or p is None or p.fam == lead or p.fam in NEUTRAL_FAMILIES:
            continue
        score[p.fam] += rules.dom(inst) + rules.bonus.get(p.rar, 0.0)
        best[p.fam] = max(best[p.fam], rules.bonus.get(p.rar, 0.0))
        key = inst[:3] if inst[:4] in ("ARM_", "LEG_") else inst
        idx = order.index(key) if key in order else 99
        prio[p.fam] = min(prio.get(p.fam, 99), idx)
    lw = rules.word(lead)
    sig = None
    for title, _text, tree in rules.signatures:
        if evaluate(tree, lo):
            sig = title
            break
    cands = [f for f in score if score[f] > 0]
    if not cands:
        art = "an" if lw[:1].upper() in "AEIOU" else "a"
        return lw, "Just %s %s" % (art, lw), sig
    dom = sorted(cands, key=lambda f: (-round(score[f], 3), -best[f], prio[f], f))[0]
    dw = rules.word(dom)
    key = "%s-%s" % (lw, dw)
    spoken = "%s %s" % (dw, lw) if (dom in rules.loud and lead not in rules.loud) else "%s %s" % (lw, dw)
    return key, spoken, sig


# ----------------------------------------------------------------------------- synergies
class Synergy:
    def __init__(self, row, parts, errors):
        self.id = clean(row[0])
        self.ok = True
        if len(row) != 9:
            errors.append("%s: expected 9 columns, got %d" % (self.id, len(row)))
            self.ok = False
            return
        self.name = row[1]
        self.req_text = clean(row[2])
        self.effect = row[3]
        m = re.match(r"^\s*((?:SG_[A-Z_]+)|—)\s*\(r([123])\)\s*$", clean(row[5]))
        if not m:
            errors.append("%s: bad stacking group cell '%s'" % (self.id, row[5]))
            self.ok = False
            return
        self.group = m.group(1) if m.group(1) != "—" else self.id
        self.rank = int(m.group(2))
        self.examples_cell = clean(row[7])
        self.contexts = [c.strip() for c in clean(row[8]).split(",")]
        bad = [c for c in self.contexts if c not in CONTEXTS]
        if bad:
            errors.append("%s: unknown context(s) %s" % (self.id, bad))
        em = re.match(r"^((?:`[A-Z_]+`(?:\s*\+\s*)?)+)", self.effect.strip())
        self.effect_types = re.findall(r"`([A-Z_]+)`", em.group(1)) if em else []
        if not self.effect_types:
            errors.append("%s: Effect cell must start with backticked effect type(s)" % self.id)
        try:
            self.tree = parse_req(self.req_text)
        except ValueError as exc:
            errors.append("%s: %s" % (self.id, exc))
            self.ok = False


def resolve(triggered, syn_by_id, pins=()):
    """§12.10 resolution: highest rank per stacking group, then top MAX_ACTIVE by (pinned, rank, id)."""
    by_group = collections.defaultdict(list)
    for sid in triggered:
        by_group[syn_by_id[sid].group].append(sid)
    winners, suppressed = [], []
    for grp, ids in by_group.items():
        ids.sort(key=lambda s: (-syn_by_id[s].rank, s))
        winners.append(ids[0])
        suppressed += ids[1:]
    winners.sort(key=lambda s: (0 if s in pins else 1, -syn_by_id[s].rank, s))
    active = winners[:MAX_ACTIVE]
    suppressed += winners[MAX_ACTIVE:]
    return sorted(active), sorted(suppressed)


def triggered_by(lo, synergies):
    return sorted(s.id for s in synergies if s.ok and evaluate(s.tree, lo))


# ----------------------------------------------------------------------------- main
def main(argv):
    stats = "--stats" in argv
    verbose = "--verbose" in argv
    errors, warnings = [], []
    parts, canon_tokens = load_canon()
    if len(parts) != 280:
        errors.append("canon: expected 280 MUT rows, parsed %d" % len(parts))

    missing = [f for f in A8_FILES if not os.path.exists(f)]
    for f in missing:
        errors.append("missing file %s" % os.path.relpath(f, GDD))
    if missing:
        return report(errors, warnings)

    text12b, text13, textsyn, textcmb = (read(f) for f in A8_FILES)
    rules = Rules(text12b)
    if not rules.dominance or not rules.bonus or not rules.signatures or not rules.effect_types:
        errors.append("12b: could not parse naming/signature/effect-type tables")

    # ---------------- synergies
    synergies = [Synergy(r, parts, errors) for r in id_rows(textsyn, "SYN")]
    syn_by_id = {}
    for s in synergies:
        if s.id in syn_by_id:
            errors.append("%s: duplicate definition" % s.id)
        syn_by_id[s.id] = s
    expected = ["SYN_%03d" % i for i in range(1, len(synergies) + 1)]
    if [s.id for s in synergies] != expected:
        errors.append("SYN ids must be sequential SYN_001..SYN_%03d in table order" % len(synergies))
    if len(synergies) < MIN_SYNERGIES:
        errors.append("only %d synergies (< %d)" % (len(synergies), MIN_SYNERGIES))

    for s in synergies:
        if not s.ok:
            continue
        for t in s.effect_types:
            if t not in rules.effect_types:
                errors.append("%s: effect type %s not defined in §12.10 table" % (s.id, t))
        atoms = atoms_of(s.tree)
        # FX rule: FX-scoped atoms only in social-only synergies
        if any("FX" in a.instances() for a in atoms) and s.contexts != ["social"]:
            errors.append("%s: references the FX slot but context is not exactly 'social'" % s.id)
        # (a) satisfiability of every OR branch
        for bi, clause in enumerate(dnf(s.tree)):
            res = solve(clause, parts)
            if res is None:
                errors.append("%s: OR-branch %d (%s) is unsatisfiable with canon parts"
                              % (s.id, bi + 1, " AND ".join(a.text for a in clause)))
            elif res == "TIMEOUT":
                warnings.append("%s: solver node limit reached on branch %d (inconclusive)" % (s.id, bi + 1))
        # (b) examples
        where = "%s examples" % s.id
        plist = parse_part_list(s.examples_cell, parts, errors, where)
        lo = auto_assign(plist, errors, where)
        if not evaluate(s.tree, lo):
            errors.append("%s: example parts alone do not satisfy '%s'" % (s.id, s.req_text))
        if not evaluate(s.tree, with_defaults(lo, parts)):
            errors.append("%s: example parts + Plain Human defaults do not satisfy '%s'" % (s.id, s.req_text))
        for inst, p in lo.items():
            if not any(a.contributes(p, inst) for a in atoms):
                errors.append("%s: example %s (%s) does not contribute to any atom" % (s.id, p.id, inst))
        # warn when an example loadout is suppressed by a stronger synergy of the same group
        full = with_defaults(lo, parts)
        for o in synergies:
            if o is s or not o.ok or o.group != s.group:
                continue
            if (o.rank, ) > (s.rank, ) and evaluate(o.tree, full):
                warnings.append("%s: its example loadout also triggers stronger %s in %s" % (s.id, o.id, s.group))

    # ---------------- combos
    combos = id_rows(textcmb, "CMB")
    expected = ["CMB_%03d" % i for i in range(1, len(combos) + 1)]
    if [clean(r[0]) for r in combos] != expected:
        errors.append("CMB ids must be sequential CMB_001..CMB_%03d in table order" % len(combos))
    if len(combos) < MIN_COMBOS:
        errors.append("only %d combos (< %d)" % (len(combos), MIN_COMBOS))
    keys_seen, names_seen = set(), set()
    trig_count = collections.Counter()
    for r in combos:
        cid = clean(r[0])
        if len(r) != 7:
            errors.append("%s: expected 7 columns, got %d" % (cid, len(r)))
            continue
        disp, parts_cell, ntype, _vibe, syn_cell, _seen = r[1], r[2], r[3], r[4], r[5], r[6]
        lo = parse_combo_parts(clean(parts_cell), parts, errors, cid)
        if "HEAD" not in lo:
            continue
        key, spoken, sig = morph_name(lo, rules)
        m = re.match(r"^(generated|signature)\s*\(key\s*`([^`]+)`\)\s*$", ntype.strip())
        if not m:
            errors.append("%s: bad Name type cell '%s'" % (cid, ntype))
        else:
            if m.group(2) != key:
                errors.append("%s: key should be '%s' (cell says '%s')" % (cid, key, m.group(2)))
            if sig and (m.group(1) != "signature" or clean(disp) != sig):
                errors.append("%s: matches signature '%s' -> name type signature, display '%s'" % (cid, sig, sig))
            if not sig and (m.group(1) != "generated" or clean(disp) != spoken):
                errors.append("%s: generated name should be '%s' (cell: '%s' / %s)" % (cid, spoken, clean(disp), m.group(1)))
        keys_seen.add(key)
        names_seen.add(clean(disp))
        trig = triggered_by(lo, synergies)
        for t in trig:
            trig_count[t] += 1
        active, suppressed = resolve(trig, syn_by_id)
        listed_active = sorted(re.findall(r"(?<!\()\b(SYN_\d{3})\b(?!\))", syn_cell))
        listed_supp = sorted(re.findall(r"\((SYN_\d{3})\)", syn_cell))
        if listed_active != active or listed_supp != suppressed:
            errors.append("%s: synergies should be active %s suppressed %s (cell: active %s suppressed %s)"
                          % (cid, active, suppressed, listed_active, listed_supp))
        if verbose:
            print("%s %-28s key=%-22s active=%s supp=%s" % (cid, clean(disp), key, active, suppressed))

    # ---------------- brief / mockup coverage
    for k in ["Bear-Scorpion", "Shark-Spider", "Giraffe-Squid", "TV-Moth", "Frog-Robot", "Cat-Fish", "Axolotl-Cow",
              "Pigeon-Muscle", "Snake-Rabbit", "Deer-Plant"]:
        if k not in keys_seen:
            errors.append("mockup/brief combo key '%s' missing from §36.5" % k)
    for n in ["Scorpion Bear", "Shark Spider", "Giraffe Squid", "TV Moth", "Frog Robot", "Cat Fish", "Axolotl Cow",
              "Muscle Pigeon"]:
        if n not in names_seen:
            errors.append("brief combo name '%s' missing from §36.5" % n)
    brief_syn = [("octopus+chef", lambda t: "family:octopus" in t and "chef" in t),
                 ("bear+rhino", lambda t: "family:bear" in t and "family:rhino" in t),
                 ("spider legs+repair claws", lambda t: "family:spider@LEG" in t and "repair" in t and "claw" in t),
                 ("dragon head+fireproof skin", lambda t: "family:dragon@HEAD" in t and "family:fire@SKIN" in t)]
    for label, test in brief_syn:
        if not any(test(s.req_text) for s in synergies if s.ok):
            errors.append("brief synergy example '%s' missing from §36.4" % label)
    for ctx in CONTEXTS:
        if not any(ctx in s.contexts for s in synergies if s.ok):
            errors.append("no synergy covers context '%s'" % ctx)
    for s in synergies:
        if s.ok and trig_count[s.id] == 0:
            pass  # not every synergy needs a showcase combo

    # ---------------- ID tokens in A8 files
    defined = {s.id for s in synergies} | {clean(r[0]) for r in combos}
    for f in A8_FILES:
        txt = read(f)
        for tok in sorted(set(ID_TOKEN.findall(txt))):
            if tok not in canon_tokens and tok not in defined:
                errors.append("%s: ID token %s resolves to nothing in canon or A8 definitions"
                              % (os.path.basename(f), tok))
        for tok in sorted(set(re.findall(r"\b(?:SFX|MUS|FRN)_\d+\b", txt))):
            errors.append("%s: A8 must not reference %s (owned by other contributors)" % (os.path.basename(f), tok))

    if stats:
        print_stats(parts, rules, synergies, combos, trig_count)
    print("synergies: %d   combos: %d   distinct combo keys: %d" % (len(synergies), len(combos), len(keys_seen)))
    return report(errors, warnings)


def print_stats(parts, rules, synergies, combos, trig_count):
    ctx = collections.Counter(c for s in synergies if s.ok for c in s.contexts)
    print("contexts:", dict(sorted(ctx.items())))
    fams, tags, cats = set(), set(), set()
    for s in synergies:
        if not s.ok:
            continue
        for a in atoms_of(s.tree):
            if a.kind == "family":
                fams |= set(a.values)
            elif a.kind == "tag":
                tags |= set(a.values)
            elif a.kind == "category":
                cats |= set(a.values)
    all_fams = {p.fam for p in parts.values()}
    all_tags = set().union(*(p.tags for p in parts.values()))
    print("families referenced: %d/%d  tags referenced: %d/%d  categories referenced: %d/16"
          % (len(fams), len(all_fams), len(tags), len(all_tags), len(cats)))
    print("tags never referenced:", sorted(all_tags - tags))
    heads = sorted({p.fam for p in parts.values() if p.slot == "HEAD"})
    nameable = sorted({p.fam for p in parts.values() if p.slot not in ("HEAD", "FX")} - NEUTRAL_FAMILIES)
    keys = len(heads) + sum(len([f for f in nameable if f != h]) for h in heads)
    print("Morphdex: head families %d, nameable dominant families %d, possible keys %d"
          % (len(heads), len(nameable), keys))
    per_slot = collections.Counter(p.slot for p in parts.values())
    total = 1
    for inst in SLOTS:
        code = inst[:3] if inst[:4] in ("ARM_", "LEG_") else inst
        if inst in ("FUR", "SCALES"):
            continue
        n = per_slot[code] + (0 if inst in MANDATORY else 1)
        total *= n
    total *= (1 + per_slot["FUR"] + per_slot["SCALES"])
    print("raw legal loadouts: %.3e" % total)
    print("synergies never triggered by a §36.5 combo: %d" % sum(1 for s in synergies if trig_count[s.id] == 0))


def report(errors, warnings):
    for w in warnings:
        print("WARN  " + w)
    for e in errors:
        print("ERROR " + e)
    print("RESULT: %s (%d errors, %d warnings)" % ("CLEAN" if not errors else "FAILED", len(errors), len(warnings)))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

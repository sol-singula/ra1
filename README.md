# Mystery Morph Restaurant — Game Design Document

Design and development specification for **Mystery Morph Restaurant**, a Roblox restaurant-chaos /
creature-collection / tycoon game. Everything should be just a little bit ridiculous.

## The deliverable

**[`MYSTERY_MORPH_RESTAURANT_GDD.md`](MYSTERY_MORPH_RESTAURANT_GDD.md)** is the complete, assembled GDD:
40 numbered sections (vision → systems → technical architecture → roadmap/QA → content databases →
definition of done), a generated completion manifest, and a full table of contents.

The file is large. To read one section at a time, open the per-section sources in [`gdd/sections/`](gdd/sections).

## Repository layout

| Path | Purpose |
|---|---|
| `MYSTERY_MORPH_RESTAURANT_GDD.md` | Assembled document (generated — do not edit by hand) |
| `gdd/brief/MASTER_PROMPT.md` | The client brief the GDD answers |
| `gdd/canon.md` | Single source of truth for identifiers, master content lists, constants and core formulas that every section uses |
| `gdd/sections/*.md` | Section sources, assembled in filename order |
| `gdd/data/*.json` | Data-backed content (recipes, ingredients, mutation parts, …) — also the intended source for generated Luau data modules (§27) |
| `gdd/tools/render_*.py` | Render data-backed tables from `gdd/data/` into section files |
| `gdd/tools/validate_gdd.py` | Validates section order, identifier cross-references, content counts, canonical names and required diagrams |
| `gdd/tools/build_gdd.py` | Validates, generates the front matter (manifest + TOC) and assembles the GDD |

## Rebuilding

Python 3.10+ (standard library only):

```bash
python3 gdd/tools/validate_gdd.py          # report; exit code 1 on any failure
python3 gdd/tools/build_gdd.py --render    # re-render data tables, validate, assemble the GDD
```

Edit section sources or `gdd/data/*.json`, never the assembled file.

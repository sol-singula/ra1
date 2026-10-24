# Mutation Meadow: build spec 01, Crops (9 crops × 4 stages)

Batch 1 of 6. Owner: Game Artist. Audience: Roblox Developer, who writes the build prompts. This file is a spec only, with no prompts.
Build rule: **Parts and built-in materials only.** No meshes, no uploaded assets, no decals or textures. `SpecialMesh` is used only as a built-in shape (`MeshType.Sphere`, to get an ellipsoid).
Refs: `build-spec/refs/crop_01_carrot.png` … `crop_09_moonmelon.png`. These are look references for proportion and colour, not renders to match exactly. **The numbers in this file win over the pictures.**
Read against the repo (read-only): `client/Controllers/TileController.lua`, `PedestalController.lua`, `server/Services/FarmService.lua`, `CaptureService.lua`, `shared/Config/Seeds.lua`, `shared/Growth.lua`, `shared/Visuals.lua`, `shared/Tiles.lua`.

Later batches: `02-mutations.md` (Golden, Wet, Wet+Golden overlays and FX on the `Fruit*` parts defined here), `03-sunflower.md`, `04-reveal.md`, `05-patch.md`, `06-avatars.md` (farmer/avatar polish), and `review-checklist.md`.

---

## 0. Conventions (apply to every crop)

### 0.1 Ids and names (must match the code)
| Crop id (Seeds.lua key) | Display | Tier | growSec | harvests | Fruit hex (from `Visuals.SEED`) |
|---|---|---|---|---|---|
| `carrot` | Carrot | 1 | 30 | 1 | #F58C28 |
| `strawberry` | Strawberry | 2 | 45 | 5 | #E63246 |
| `blueberry` | Blueberry | 3 | 90 | 5 | #465AC8 |
| `tomato` | Tomato | 4 | 180 | 5 | #DC3228 |
| `corn` | Corn | 5 | 360 | 5 | #F5D23C |
| `pumpkin` | Pumpkin | 6 | 720 | 1 | #F0821E |
| `watermelon` | Watermelon | 7 | 1800 | 6 | #3CA046 |
| `dragonfruit` | Dragon Fruit | 8 | 3600 | 8 | #EB46A0 |
| `moonmelon` | Moon Melon (event) | 9 | 10800 | 10 | #BEC8FF |

The fruit hexes stay identical to `Visuals.SEED`, so the UI, pedestal and crop all agree.

### 0.2 Model structure
- **Model name:** the code's existing name, `plot.Name.."_"..tile.Name`, parented to the same `cropFolder` TileController uses today. One Model per tile replaces the single cube Part.
- **PrimaryPart:** `Root`, the soil mound (present in every stage).
- **Child naming:** `Root`, `Hole`, `Seed`, `Stake`, `Tag`, `Stem#`, `Leaf#`, `Flower#`, `Vine#`, `Bud#`, `Fruit#` (ripe fruit only), `FruitDetail#` (stripes, calyx, kernels' husk etc. that belong to a fruit).
- **Mutation hook (used by 02-mutations):**
  - Only parts whose name starts with `Fruit` (`Fruit#` and `FruitDetail#`) get the Golden/Wet treatment.
  - `Root` holds an `Attachment` named **`FxAnchor`** at the listed fruit centroid. It replaces the current `Visuals.mutationFx(cropPart)`; pass the Model or its `FxAnchor` instead.
  - Base crops have **no** ParticleEmitter, Beam, Trail or Neon. Any sparkle in the world means a mutation.
- **Model attributes:** keep the tile attributes on the tile part. Copy `Seed` and add `Stage` = `"seed"|"sprout"|"growing"|"ripe"` on the Model, for debugging, capture and QA.
- **Pedestal (PedestalController):** clone only the `Fruit*` parts of the Ripe build (plus `Stem#` for pumpkin). Pivot them to the pedestal top and `ScaleTo` so the largest extent is 1.8 studs. This replaces today's Neon cube.

### 0.3 Origin, axes and the cell
- **Origin O = the soil surface under the tile centre.** Get it by raycasting down from `tile.Position`, excluding `tile` and `cropFolder`, or use `tile.Position - (0, tile.Size.Y/2, 0)`.
  - Do **not** use the tile top. On the placeholder street the tile part is 1 stud tall and invisible, so the top sits 1 stud above the grass, and crops would float (see Conflicts C3).
- **Axes:** +X = right, +Y = up, **front = −Z** (toward the road; row 1 is nearest the road). Cell pitch is 4 studs (`TILE = 4`), and the tile part is 3.7 × 3.7. **Keep every build inside a 3.4 × 3.4 footprint**, which leaves a ≥0.15 stud gap so neighbours never touch.
- **The Extra Row bed** (`extra1..8`) uses the same 4-stud cell and the same builds. The spec's "1×8 bed cell" is this cell.
- **Height limits:** ≤ 3.25 studs above O (corn is the tallest). The plot sign is 3 studs, and an R15 avatar is about 5 studs. Crops are **true scale**; only the Block Party sunflower is giant.
- **Offsets and rotations** in the tables are relative to O, as `CFrame.new(x,y,z) * CFrame.Angles(rad(rx), rad(ry), rad(rz))`, in degrees. y is to the part **centre**. The whole model is then `PivotTo(tileCF)`, where tileCF = CFrame at O with the tile's yaw.
- **Variation:** rotate the whole model about Y by `((tonumber(tileId) or 0) * 37) % 360` degrees, so a field of carrots doesn't look stamped. Use a deterministic value, not random, so a re-render doesn't jitter. Exception: the corn and tomato stakes may face any way.

### 0.4 Shapes (how to read the "Shape" column)
| Code | Roblox | Size meaning |
|---|---|---|
| `Block` | Part, Shape=Block | X,Y,Z |
| `Ball` | Part, Shape=Ball | uniform; give one number |
| `CylV` | Part, Shape=Cylinder, **rotated rz=90** so it stands up | Size = (height, diameter, diameter). **Cylinder's axis is X.** The 90° is already included in the "CylV" code; don't add it again. |
| `Disc` | CylV with tiny height | (thickness, dia, dia) |
| `Ell` | Part, Shape=Block + `SpecialMesh` MeshType=Sphere, Scale (1,1,1) | ellipsoid that fills the Block size X,Y,Z |
| `Wedge` | WedgePart | X,Y,Z (slope faces −Z at rotation 0) |

### 0.5 Physics, welds and render flags
- Every part: `Anchored=true`, `CanCollide=false`, `CanTouch=false`, `CanQuery=false`. The tile's ClickDetector must still win the click, and crops must never block the tile.
- **Welds: none required**, because everything is anchored and placed by CFrame. If the developer wants to tween the model as one piece, add `WeldConstraint`s from each part to `Root`, un-anchor the children, and keep `Root` anchored. Either way works; pick one and use it everywhere.
- `CastShadow`: true for `Root`, `Fruit#` and any part ≥ 1 stud. False for everything smaller (perf).
- **Material:** `Enum.Material.SmoothPlastic` for everything (the flat storybook look). Exceptions are named in the tables. **No Neon on base crops.**
- **Reflectance 0 and Transparency 0 everywhere**, unless a table says otherwise. Reflectance is reserved for Wet/Golden in batch 2.
- **Lights:** only the Ripe Moon Melon has a light (one PointLight). No other base crop has lights.

### 0.6 Shared colours
| Name | Hex | Use |
|---|---|---|
| Soil (Cocoa Soil) | #7A4E2D | Root mound |
| Soil dark | #5C3A1F | Hole |
| Leaf (Meadow Green) | #5BC236 | light leaves |
| Leaf Shadow | #2E7D32 | dark leaves, alternating |
| Stem green | #4E9A2A | stems, vines |
| Wood | #A87B4F | stakes |
| Bark | #6B4A2B | blueberry trunk |
| Unripe green | #9CC74A | immature fruit |
| Flower white | #FFF8E7 (Cream) | strawberry, tomato and dragonfruit flowers |
| Flower yellow | #FFD23F (Butter Sun, matte) | pumpkin and melon flowers |

Never use #FFC300 or #FFF1A8 (Golden only), the brass #A89670 (VIP only), or rainbow.

### 0.7 Stages (the code has no discrete stages; derive them on the client)
TileController already computes `progress` (Growth / `Grown` / `GrowSec` / `Rate` / `At`) and reads `Ripe`.
| Stage | Condition | Shows |
|---|---|---|
| `seed` | progress < 0.20 | mound + hole + seed + stake with tag |
| `sprout` | 0.20 ≤ progress < 0.50 | mound + seedling + stake with tag |
| `growing` | progress ≥ 0.50 and not `Ripe` | plant with unripe fruit or flowers; tag removed |
| `ripe` | `Ripe == true` | full plant with `Fruit#` parts |

- **Only rebuild on a stage change**, not every frame. Today the cube is resized continuously; keep the per-frame cost at zero.
- **Pop on change:** build the new stage, `ScaleTo(0.8)`, then tween a NumberValue 0.8 → 1.06 over 0.15 s (Back Out), then 1.0 over 0.10 s, calling `Model:ScaleTo(v)` each step. Destroy the old model on the same frame the new one appears. Total 0.25 s. With `reducedFx` on, skip the tween.
- **Regrow (harvests > 1):** after a harvest that leaves harvests, FarmService calls `Growth.regrow`, so progress restarts at 0. The plant should go back to **`growing` minus its fruit** (a "regrow" look), not to a seed. This needs a replicated flag, because today the tile part has no harvest counter (see Conflict C4). Proposed: the server sets the tile attribute `Regrow = true` when `harvestsLeft < Seeds[seed].harvests`, and the client then maps seed/sprout → `growing`.
- **Harvest:** on harvest the ripe model is replaced on the next update, with no extra FX here. The reveal and its FX are in 04.

---

## 1. Seed stage (shared by all 9 crops): 5 parts

| # | Name | Shape | Size | Offset (x,y,z) | Rot (rx,ry,rz) | Hex | Notes |
|---|---|---|---|---|---|---|---|
| 1 | Root | CylV | (0.30, 2.8, 2.8) | (0, 0.15, 0) | — | #7A4E2D | soil mound, present in all stages |
| 2 | Hole | Disc | (0.04, 0.9, 0.9) | (0, 0.31, 0) | — | #5C3A1F | |
| 3 | Seed | Ball | per crop | (0, 0.36, 0) | — | per crop | half sunk in the hole |
| 4 | Stake | Block | (0.12, 1.0, 0.12) | (0.95, 0.80, −0.95) | — | #A87B4F | front-right corner |
| 5 | Tag | Block | (0.60, 0.45, 0.08) | (0.95, 1.20, −1.01) | (0, −20, 0) | per-crop fruit hex | blank plate, no text |

The mound top is at y = 0.30. **All later y values assume this mound.**
Per-crop seed: carrot Ball 0.22 #D9B98A · strawberry 0.18 #F2D45C · blueberry 0.20 #465AC8 · tomato 0.22 #EADBB8 · corn 0.30 #F5D23C · pumpkin 0.32 #F3E3C3 · watermelon 0.26 #2B2B2B · dragonfruit 0.20 #1E1B2E · moonmelon 0.30 #E6EBFF.
`FxAnchor` (seed stage): (0, 0.5, 0). Mutations only apply when ripe, so this is unused, but always present.

---

## 2. Sprout stage: 3 archetypes, 5–7 parts

All sprouts keep `Root`, `Stake` and `Tag` from the seed stage (3 parts), then add the seedling below. `Hole` and `Seed` are removed.

**A. Blades** (carrot, corn)
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Leaf1 | Block | carrot (0.08, 0.55, 0.18) · corn (0.10, 0.80, 0.30) | (0, 0.30+h/2, 0) | (0,0,0) | #5BC236 |
| Leaf2 | Block | same | (−0.10, same, 0) | (0, 0, 18) | #2E7D32 |
| Leaf3 (carrot only) | Block | same | (0.10, same, 0) | (0, 0, −18) | #5BC236 |
Here h = Size.Y. Corn uses Leaf1 at rot (0, 90, 12) and Leaf2 at (0, 90, −12), so the two broad blades cross.
Parts: carrot 6, corn 5.

**B. Cotyledons** (strawberry, blueberry, tomato, pumpkin, watermelon, moonmelon)
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Stem1 | Block | (0.12, 0.40, 0.12) | (0, 0.50, 0) | — | #4E9A2A (moonmelon #8FBFA8) |
| Leaf1 | Ell | (0.48, 0.08, 0.30) | (−0.24, 0.72, 0) | (0, 0, 15) | #5BC236 (moonmelon #A9DCCB) |
| Leaf2 | Ell | (0.48, 0.08, 0.30) | (0.24, 0.72, 0) | (0, 0, −15) | #5BC236 (moonmelon #A9DCCB) |
| Leaf3 (strawberry, blueberry, tomato only) | Ell | (0.26, 0.06, 0.34) | (0, 0.78, −0.12) | (−25, 0, 0) | #2E7D32 |
- Pumpkin, watermelon and moonmelon cotyledons are 1.3× bigger, with Leaf size (0.62, 0.08, 0.40) and offset x ±0.31. These are the big-seed crops.
- Parts: 6 (3 shared + 3), or 7 with Leaf3.

**C. Cactus nub** (dragonfruit)
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Stem1 | Block | (0.30, 0.50, 0.30) | (0, 0.55, 0) | (0, 45, 0) | #3E8E3E |
| Leaf1 | Wedge | (0.10, 0.18, 0.14) | (0.20, 0.70, 0) | (0, 90, 0) | #7BC043 |
| Leaf2 | Wedge | (0.10, 0.18, 0.14) | (−0.20, 0.62, 0) | (0, −90, 0) | #7BC043 |
Parts: 6.

`FxAnchor` (sprout): (0, 0.8, 0).

---

## 3. Per-crop Growing and Ripe builds

Every build includes `Root` (shared, row 1 of §1), and **the tag and stake are removed from Growing on**. "×" lists give one row per part. For mirrored parts, the second gets the sign-flipped x or rotation as shown.

### 3.1 Carrot `carrot`: 1 harvest. Ref: `refs/crop_01_carrot.png`
Look: a feathery leafy top over an orange shoulder half out of the soil.

**Growing (6 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | #7A4E2D |
| Bud1 | CylV | (0.30, 0.55, 0.55) | (0, 0.40, 0) | — | #F7A85A (pale orange) |
| Leaf1 | Block | (0.10, 0.80, 0.30) | (0, 0.95, 0) | (0,0,0) | #5BC236 |
| Leaf2 | Block | same | (−0.18, 0.90, 0) | (0, 0, 25) | #2E7D32 |
| Leaf3 | Block | same | (0.18, 0.90, 0) | (0, 0, −25) | #2E7D32 |
| Leaf4 | Block | same | (0, 0.90, 0.18) | (25, 0, 0) | #5BC236 |

**Ripe (8 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | #7A4E2D |
| Fruit1 | CylV | (0.60, 0.90, 0.90) | (0, 0.55, 0) | — | #F58C28 (the visible shoulder, spanning y 0.25–0.85) |
| FruitDetail1 | Disc | (0.08, 0.70, 0.70) | (0, 0.89, 0) | — | #E07A1E (crown ring) |
| Leaf1 | Block | (0.14, 1.10, 0.40) | (0, 1.45, 0) | (0,0,0) | #5BC236 |
| Leaf2 | Block | same | (−0.25, 1.38, 0) | (0, 0, 28) | #2E7D32 |
| Leaf3 | Block | same | (0.25, 1.38, 0) | (0, 0, −28) | #2E7D32 |
| Leaf4 | Block | same | (0, 1.38, 0.25) | (28, 0, 0) | #5BC236 |
| Leaf5 | Block | same | (0, 1.38, −0.25) | (−28, 0, 0) | #5BC236 |
FxAnchor (0, 0.6, 0). Height 2.0. Footprint = mound 2.8.

### 3.2 Strawberry `strawberry`: 5 harvests (regrow → Growing without fruit). Ref: `crop_02_strawberry.png`
Look: a low, round bush. White flowers when Growing, then red berries hanging at the front edge.

**Growing (7 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Leaf1 | Ell | (1.0, 0.50, 1.0) | (−0.45, 0.50, 0.25) | — | #2E7D32 |
| Leaf2 | Ell | (1.0, 0.50, 1.0) | (0.45, 0.50, 0.25) | — | #5BC236 |
| Leaf3 | Ell | (1.0, 0.55, 1.0) | (0, 0.55, −0.35) | — | #5BC236 |
| Flower1 | Disc | (0.06, 0.36, 0.36) | (−0.35, 0.82, −0.55) | (−30, 0, 0) applied after CylV | #FFF8E7 |
| Flower2 | Disc | same | (0.50, 0.80, −0.30) | (−20, 0, 0) | #FFF8E7 |
| Flower3 | Disc | same | (0.05, 0.85, 0.35) | (20, 0, 0) | #FFF8E7 |

**Ripe (12 parts):** the same 3 Leaf parts at 1.2× size (1.2, 0.6, 1.2), with offsets unchanged. Flowers are removed. Add:
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Fruit1 | Ell | (0.45, 0.55, 0.45) | (−0.80, 0.42, −0.75) | (0, 0, 10) | #E63246 |
| Fruit2 | Ell | same | (0.78, 0.42, −0.62) | (0, 0, −10) | #E63246 |
| Fruit3 | Ell | same | (0.15, 0.40, −1.05) | — | #E63246 |
| Fruit4 | Ell | same | (−0.20, 0.48, 0.95) | — | #E63246 |
| FruitDetail1–4 | Block | (0.36, 0.06, 0.36) | each Fruit + (0, 0.29, 0) | (0, 45, 0) | #5BC236 (calyx) |
FxAnchor (0, 0.5, −0.5). Height 0.9. Footprint about 2.9.

### 3.3 Blueberry `blueberry`: 5 harvests. Ref: `crop_03_blueberry.png`
Look: a small shrub on a short trunk, with blue berry pairs dotted on the front of the canopy.

**Growing (8 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Stem1 | CylV | (0.60, 0.18, 0.18) | (0, 0.60, 0) | — | #6B4A2B |
| Leaf1 | Ell | (1.30, 0.80, 1.30) | (0, 1.10, 0) | — | #2E7D32 |
| Leaf2 | Ell | (0.90, 0.65, 0.90) | (0.25, 1.45, −0.15) | — | #5BC236 |
| Bud1–4 | Ball | 0.20 | (−0.45,1.05,−0.55) (0.40,1.20,−0.55) (0,1.45,−0.55) (0.55,1.50,−0.25) | — | #A8D08D (unripe) |

**Ripe (10 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Stem1 | CylV | (0.80, 0.20, 0.20) | (0, 0.70, 0) | — | #6B4A2B |
| Leaf1 | Ell | (1.60, 1.00, 1.60) | (0, 1.30, 0) | — | #2E7D32 |
| Leaf2 | Ell | (1.10, 0.80, 1.10) | (0.30, 1.75, −0.20) | — | #5BC236 |
| Fruit1, Fruit2 | Ball | 0.28 | (−0.55,1.15,−0.70), (−0.33,1.10,−0.75) | — | #465AC8 |
| Fruit3, Fruit4 | Ball | 0.28 | (0.45,1.35,−0.72), (0.65,1.28,−0.62) | — | #465AC8 |
| Fruit5, Fruit6 | Ball | 0.28 | (0.10,1.72,−0.68), (0.30,1.80,−0.62) | — | #465AC8 |
FxAnchor (0, 1.4, −0.6). Height 2.3. Footprint 2.8 (the mound; the canopy is 1.6).

### 3.4 Tomato `tomato`: 5 harvests. Ref: `crop_04_tomato.png`
Look: a vine zig-zagging up a wooden stake, with leaves and 4 red tomatoes on the front.

**Growing (12 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Stake | Block | (0.15, 2.40, 0.15) | (0, 1.50, 0.30) | — | #A87B4F |
| Vine1 | Block | (0.18, 0.90, 0.18) | (−0.15, 0.75, 0.15) | (0, 0, 15) | #4E9A2A |
| Vine2 | Block | same | (0.15, 1.55, 0.15) | (0, 0, −15) | #4E9A2A |
| Vine3 | Block | same | (−0.10, 2.25, 0.15) | (0, 0, 12) | #4E9A2A |
| Leaf1–4 | Block | (0.60, 0.08, 0.40) | (−0.45,1.05,0.1) (0.45,1.45,0.1) (−0.45,1.85,0.1) (0.40,2.35,0.1) | rz +20, −20, +20, −20 | alternate #5BC236 / #2E7D32 |
| Bud1–3 | Ball | 0.40 | (−0.40,0.95,−0.15) (0.38,1.40,−0.20) (−0.30,1.90,−0.15) | — | #9CC74A |

**Ripe (13 parts):** the same as Growing minus Bud1–3, with the Stake 2.6 tall at y 1.60. Add:
| Name | Shape | Size | Offset | Hex |
|---|---|---|---|---|
| Fruit1 | Ball | 0.55 | (−0.45, 0.95, −0.20) | #DC3228 |
| Fruit2 | Ball | 0.55 | (0.40, 1.40, −0.25) | #DC3228 |
| Fruit3 | Ball | 0.50 | (−0.35, 1.90, −0.20) | #DC3228 |
| Fruit4 | Ball | 0.45 | (0.30, 2.35, −0.15) | #DC3228 |
FxAnchor (0, 1.6, −0.2). Height 2.9. Footprint 2.8.

### 3.5 Corn `corn`: 5 harvests. Ref: `crop_05_corn.png`
Look: the tallest normal crop. One stalk, 4 long drooping leaves, 2 ears with husks opened to show the kernels, and a tan tassel.
**Keep corn matte and husk-dominant** so it never reads as Golden (see C6).

**Growing (8 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Stem1 | CylV | (2.00, 0.24, 0.24) | (0, 1.30, 0) | — | #4E9A2A |
| Leaf1–4 | Block | (0.10, 1.10, 0.32) | (−0.40,1.00,0) (0.40,1.30,0) (0,1.60,−0.40) (0,1.90,0.40) | rz +40, rz −40, rx −40, rx +40 | alternate #5BC236 / #2E7D32 |
| Bud1, Bud2 | Ell | (0.34, 0.70, 0.34) | (0.25,1.30,−0.20), (−0.25,1.70,0.18) | rz −20, rz +20 | #8DC63F (closed husk) |

**Ripe (13 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Stem1 | CylV | (2.80, 0.28, 0.28) | (0, 1.70, 0) | — | #4E9A2A |
| Stem2–4 (tassel) | Block | (0.06, 0.45, 0.06) | (0,3.30,0) (−0.12,3.25,0) (0.12,3.25,0) | rz 0, +25, −25 | #B89A6A (tan; not gold) |
| Leaf1–4 | Block | (0.10, 1.40, 0.35) | (−0.45,1.30,0) (0.45,1.60,0) (0,2.10,−0.45) (0,2.40,0.45) | rz +40, rz −40, rx −40, rx +40 | alternate #5BC236 / #2E7D32 |
| FruitDetail1, FruitDetail2 (husks) | Ell | (0.42, 0.90, 0.42) | (0.30,1.50,−0.25), (−0.30,2.00,0.20) | rz −20, rz +20 | #8DC63F |
| Fruit1, Fruit2 (kernels) | Ell | (0.32, 0.70, 0.32) | each husk + 0.08 toward −Z, +0.12 y | same as husk | #F5D23C, SmoothPlastic, Reflectance 0 |
Shortened corn: height ≤3.25 (Stem1 length and part Ys as in the ripe table). FxAnchor (0, 1.45, −0.2).

### 3.6 Pumpkin `pumpkin`: 1 harvest (hero crop). Ref: `crop_06_pumpkin.png`
Look: a chunky faceted orange pumpkin made of 3 overlapping lobes, with a short stem and a curl, sitting on a vine with 2 big leaves.

**Growing (8 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Bud1 | Ell | (0.66, 0.70, 1.00) | (0, 0.62, 0) | — | #9CC74A |
| Bud2, Bud3 | Ell | (0.50, 0.66, 0.92) | (±0.30, 0.60, 0) | — | #8DBA3E |
| Vine1 | Block | (0.15, 0.12, 1.25) | (0.60, 0.36, 1.10) | (0, 30, 0) | #4E9A2A |
| Leaf1, Leaf2 | Disc | (0.08, 0.90, 0.90) | (−1.00,0.42,0.85), (1.05,0.42,−0.85) | tilt rx ±10 | #2E7D32 |
| Flower1 | Disc | (0.06, 0.40, 0.40) | (0.95, 0.50, 0.70) | — | #FFD23F (matte) |

**Ripe (9 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Fruit1 (core) | Ell | (1.20, 1.35, 1.90) | (0, 0.95, 0) | — | #F0821E |
| Fruit2 (left lobe) | Ell | (0.90, 1.25, 1.70) | (−0.55, 0.92, 0) | — | #E27318 |
| Fruit3 (right lobe) | Ell | (0.90, 1.25, 1.70) | (0.55, 0.92, 0) | — | #E27318 |
| Stem1 | CylV | (0.45, 0.22, 0.22) | (0, 1.80, 0) | (0, 0, 8) | #6B8E23 |
| Stem2 (curl) | Block | (0.12, 0.12, 0.45) | (0, 2.00, 0.18) | (30, 0, 0) | #6B8E23 |
| Vine1 | Block | (0.15, 0.12, 1.05) | (0.60, 0.36, 1.20) | (0, 30, 0) | #4E9A2A |
| Leaf1 | Disc | (0.08, 1.00, 1.00) | (−1.15,0.42,0.95) | tilt rx ±10 | #2E7D32 |
| Leaf2 | Disc | (0.08, 0.90, 0.90) | (1.20,0.42,−0.95) | tilt rx ±10 | #2E7D32 |
The lobes give the faceted read through the shade split #F0821E / #E27318. Size: 2.0 wide × 1.65 tall body. FxAnchor (0, 0.95, 0). The pedestal clones Fruit1–3 + Stem1–2.

### 3.7 Watermelon `watermelon`: 6 harvests. Ref: `crop_07_watermelon.png`
Look: a big oval striped melon plus one small melon on a vine with leaves.

**Growing (8 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Bud1 | Ell | (0.80, 0.75, 1.20) | (0, 0.66, 0) | (0, 20, 0) | #7CC46A |
| Bud2, Bud3 (stripes) | Ell | (0.14, 0.76, 1.21) | Bud1 ± 0.22 along its local X | same | #3E8E3E |
| Vine1 | Block | (0.15, 0.12, 2.00) | (0.90, 0.36, 0.40) | (0, 15, 0) | #4E9A2A |
| Leaf1, Leaf2 | Disc | (0.08, 0.80, 0.80) | (−1.05,0.42,0.80), (1.05,0.42,−0.90) | rx ±10 | #2E7D32 |
| Flower1 | Disc | (0.06, 0.36, 0.36) | (1.00, 0.48, 1.00) | — | #FFD23F |

**Ripe (11 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Fruit1 | Ell | (1.30, 1.20, 2.00) | (−0.20, 0.88, −0.10) | (0, 20, 0) | #3CA046 |
| FruitDetail1–3 | Ell | (0.18, 1.21, 2.01) | Fruit1 + local X −0.38, 0, +0.38 | same as Fruit1 | #1F6B2A (dark stripes) |
| Fruit2 | Ell | (0.70, 0.65, 1.00) | (1.05, 0.62, 0.95) | (0, −30, 0) | #3CA046 |
| FruitDetail4 | Ell | (0.12, 0.66, 1.01) | Fruit2 centre | same as Fruit2 | #1F6B2A |
| Vine1 | Block | (0.15, 0.12, 2.00) | (0.90, 0.36, 0.20) | (0, 15, 0) | #4E9A2A |
| Leaf1–3 | Disc | (0.08, 0.90, 0.90) | (−1.05,0.42,0.95) (1.10,0.42,−0.95) (−1.00,0.42,−1.00) | rx ±10 | #2E7D32, #5BC236, #2E7D32 |
The stripe Ell sit 0.01 larger than the melon, so they show as bands without Z-fighting. If you see flicker, use +0.02. FxAnchor (0, 0.9, 0). Footprint 3.0.

### 3.8 Dragon Fruit `dragonfruit`: 8 harvests. Ref: `crop_08_dragonfruit.png`
Look: a chunky segmented cactus stalk with 2 arms, each tipped with a hot-pink fruit with green-tipped scale wedges.

**Growing (7 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Stem1 | Block | (0.40, 1.00, 0.40) | (0, 0.80, 0) | (0, 45, 0) | #3E8E3E |
| Stem2 | Block | (0.36, 0.80, 0.36) | (0.38, 1.45, 0) | (0, 45, −35) | #4FA34F |
| Stem3 | Block | (0.36, 0.80, 0.36) | (−0.38, 1.65, 0) | (0, 45, 35) | #4FA34F |
| Bud1, Bud2 | Ell | (0.40, 0.60, 0.40) | tips: (0.68, 1.95, 0), (−0.68, 2.15, 0) | rz −35, +35 | #B5D96A |
| Flower1 | Disc | (0.06, 0.50, 0.50) | (0, 1.40, −0.25) | rx −60 | #FFF8E7 |

**Ripe (12 parts):** Root + Stem1–3 as Growing. Add:
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Fruit1 | Ell | (0.80, 1.00, 0.80) | (0.75, 2.05, 0) | (0, 0, −20) | #EB46A0 |
| Fruit2 | Ell | (0.80, 1.00, 0.80) | (−0.75, 2.25, 0) | (0, 0, 20) | #EB46A0 |
| FruitDetail1–3 | Wedge | (0.15, 0.35, 0.30) | on Fruit1 at local (0.40,0,0) (−0.40,0.1,0) (0,0.35,−0.40) | point outward: ry 90 / −90 / 0, rx −20 | #7BC043 |
| FruitDetail4–6 | Wedge | same | on Fruit2, mirrored | mirrored | #7BC043 |
FxAnchor (0, 2.15, 0). Height 2.75. Footprint 2.8.

### 3.9 Moon Melon `moonmelon`: 10 harvests (event only). Ref: `crop_09_moonmelon.png`
Look: a round pale silver-blue melon with soft cool banding, a pale crescent mark on the front, sage leaves, and one soft cool light. **Cool, never gold.**

**Growing (6 parts)**
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Root | §1 | | | | |
| Bud1 | Ell | (1.00, 0.90, 1.00) | (0, 0.75, 0) | — | #D7DDF7 |
| Vine1 | Block | (0.15, 0.12, 1.60) | (0.80, 0.36, 0.50) | (0, 20, 0) | #6FAF8F |
| Leaf1, Leaf2 | Disc | (0.08, 0.85, 0.85) | (−1.05,0.42,0.80), (1.05,0.42,−0.85) | rx ±10 | #6FAF8F |
| Flower1 | Disc | (0.06, 0.36, 0.36) | (0.95, 0.48, 1.05) | — | #E6EBFF |

**Ripe (9 parts + 1 PointLight)**
| Name | Shape | Size | Offset | Rot | Hex | Material |
|---|---|---|---|---|---|---|
| Root | §1 | | | | | |
| Fruit1 | Ell | (1.80, 1.50, 1.80) | (0, 1.05, 0) | — | #BEC8FF | SmoothPlastic, Reflectance 0.05 |
| FruitDetail1, FruitDetail2 (bands) | Ell | (0.20, 1.51, 1.81) | Fruit1 ± 0.45 x | — | #A9B6F5 | SmoothPlastic |
| FruitDetail3 (crescent light) | Disc | (0.04, 0.60, 0.60) | (0, 1.15, −0.88) | CylV then rx 90 so it faces −Z | #F3F5FF | SmoothPlastic |
| FruitDetail4 (crescent cut) | Disc | (0.05, 0.50, 0.50) | (0.14, 1.20, −0.89) | same | #BEC8FF | SmoothPlastic |
| Vine1 | Block | (0.15, 0.12, 1.60) | (0.90, 0.36, 0.60) | (0, 20, 0) | #6FAF8F | |
| Leaf1, Leaf2 | Disc | (0.08, 0.95, 0.95) | (−1.15,0.42,0.95), (1.15,0.42,−0.95) | rx ±10 | #6FAF8F | |
- **MoonGlow:** a `PointLight` in Fruit1 with Color #BEC8FF, Brightness 0.8, Range 6, Shadows false. No Neon and no particles.
- When a Moon Melon is Golden or Wet+Golden, **destroy MoonGlow**. The Golden light replaces it (≤1 PointLight per mutated crop). With Wet only, keep MoonGlow.
- FxAnchor (0, 1.05, 0). Height 1.8. Footprint 2.8.

---

## 4. Part budgets

| Crop | Seed | Sprout | Growing | Ripe | Sum of 4 builds |
|---|---|---|---|---|---|
| carrot | 5 | 6 | 6 | 8 | 25 |
| strawberry | 5 | 7 | 7 | 12 | 31 |
| blueberry | 5 | 7 | 8 | 10 | 30 |
| tomato | 5 | 7 | 12 | 13 | 37 |
| corn | 5 | 5 | 8 | 13 | 31 |
| pumpkin | 5 | 6 | 8 | 9 | 28 |
| watermelon | 5 | 6 | 8 | 11 | 30 |
| dragonfruit | 5 | 6 | 7 | 12 | 30 |
| moonmelon | 5 | 6 | 6 | 9 (+1 light) | 26 |
| **Total** | 45 | 56 | 70 | 97 | **268 part definitions** |

- **Cap:** ≤ 14 parts for any single crop build. Max today is 13 (tomato, corn). Average ripe is 10.8.
- **Per plot worst case:** 64 grid tiles + 8 Extra Row = 72 tiles × 13 = 936 parts. With 8 plots that's about 7.5k anchored, non-colliding, non-queryable parts. That's fine with `StreamingEnabled` (recommended), and it's the ceiling, not the norm.
- If the profiler complains: (1) set CastShadow off on every non-Fruit part; (2) beyond 120 studs from the camera, swap to the "far" build of Root + Fruit1 only (2 parts), done via `StreamingEnabled` model LOD or a simple distance check every 1 s.
- Lights: at most 1 per tile (Moon Melon only).

---

## 5. Conflicts with the code and the spec (for Roblox Developer and the parent)

| # | Where | Conflict | Proposed resolution |
|---|---|---|---|
| C1 | `TileController` (crop draw), `PedestalController` | Each crop is one cube Part sized `0.6 + 2.2*progress`, lerped LEAF→SEED colour, and **Material = Neon when ripe**. The pedestal is also a Neon cube. | Replace both with a shared crop builder module, e.g. `shared/CropModels.lua`, with `build(seedId, stage) -> Model`. Drop Neon from base crops; Neon/glints mean mutations only. |
| C2 | `Visuals.mutationFx(crop, muts)` | Takes the single cube Part. | Pass the Model. Attach FX to `Root.FxAnchor`, and tint/overlay only `Fruit*` parts (batch 2). |
| C3 | `StreetBuilder` placeholder street | The tile part is 3.7×1×3.7, centred at y 0.5 (top y 1.0), invisible, over Grass ground at top y 0. Today's code puts crops on the tile **top**, so on the placeholder street they float 1 stud above the grass. The Extra Row bed top is at y 0.5. There's no visible soil anywhere. | Origin = the ground under the tile (raycast down, or the tile bottom), and every build carries its own `Root` soil mound. If Studio's real street has soil beds, keep the mound anyway (it reads per-tile). |
| C4 | ~~HarvestsLeft / regrow attribute for art~~ | ~~Was listed as art-relevant.~~ | **STRUCK / OUTDATED.** `harvestsLeft` is server-side only (`FarmService`); not replicated to the tile part. Regrow calls `Growth.regrow` when harvests remain; art does not read a HarvestsLeft attribute. Keep `Regrow` only if CropBuilder already sets it for stage rebuild — not a QA blocker. |
| C5 | Code vs spec "stages" | The spec and art list name the stages seed / sprout / growing / ripe; the code has only continuous progress + `Ripe`. | Thresholds in §0.7 (0.2 / 0.5 / Ripe). Rebuild only on a stage change. |
| C6 | Corn #F5D23C vs Golden | Corn kernels are the yellowest base colour and can be confused with Golden (#FFC300 Foil/Metal). | Kernels stay SmoothPlastic, Reflectance 0, and mostly covered by green husk; there's no glint. Golden differs by material, Reflectance and glints (batch 2). The tassel is tan #B89A6A, not gold. |
| C7 | Moon Melon glow vs "≤1 PointLight per mutated crop" | The base Moon Melon already has a light. | The Golden light replaces MoonGlow; Wet keeps it (§3.9). |
| C8 | `CaptureService` / capture stage | Builds its own crop cubes (the same Neon style). | Call the same crop builder, so capture shots match gameplay (this matters for capture-plan-R1). |
| C9 | Art list crop budgets | Given as 150–800 **tris** (the mesh era). | Superseded for the Parts build by §4 (≤14 parts per build). |
| C10 | `MUT.golden` (255,200,40) = #FFC828 vs spec Golden #FFC300 | A tiny mismatch. | Resolved in 02-mutations: use #FFC300 / #FFF1A8. Not a crops issue; logged here so it isn't lost. |
| C11 | Corn height | The ripe tassel reaches 3.5, vs "corn ≤ sign (3 studs)" in the art list. | The §3.5 shortened variant gives 3.2. Mason or the developer picks; default = the shortened variant if the sign must read over the corn. |
| C12 | Cylinder axis | Roblox Cylinder parts run along **X**. | Every `CylV` and `Disc` in this file already includes rz=90; extra disc tilts are applied after it. Call this out in the prompts. |

---

## 6. Reference sheets (look only, not finals, never upload)
`refs/crop_01_carrot.png`, `crop_02_strawberry.png`, `crop_03_blueberry.png`, `crop_04_tomato.png`, `crop_05_corn.png`, `crop_06_pumpkin.png`, `crop_07_watermelon.png`, `crop_08_dragonfruit.png`, `crop_09_moonmelon.png`
- Each sheet shows SEED → SPROUT → GROWING → RIPE left to right on a 4-stud tile, with labels added after generation.
- They're AI-generated look refs in a chunky blocky-primitive storybook style. Where a sheet and this file disagree (counts, sizes, colours), **this file wins**.

### Known ref-sheet deviations (follow the tables, not the picture)
- **All sheets:** some show the stake and tag on Growing and Ripe. The spec removes them from Growing on. The grass tile base is just presentation.
- **Strawberry:** the sheet shows 5 berries; the spec has 4.
- **Blueberry:** the sheet shows 8 berries; the spec has 6 in pairs.
- **Tomato:** the sheet stacks the tomatoes on one side; the spec alternates left and right.
- **Corn:** the tassel is drawn as a cob-like block; the spec uses 3 tan sticks.
- **Pumpkin:** the stem and curl look right.
- **Dragon Fruit:** the sheet shows 3 fruits (one on the main stalk); the spec has 2 (the arm tips only). A third fruit, `Fruit3` at (0, 2.6, 0), is allowed and would make 16 parts. Over the cap, so not recommended.
- **Moon Melon:** the sheet adds grass tufts, a small lollipop marker and a rock on Seed. Ignore all of these. The crescent, the bands and the soft cool glow are correct.

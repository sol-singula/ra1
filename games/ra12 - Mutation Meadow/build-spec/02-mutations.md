# 02 - Mutations: Wet x2, Golden x20, Wet+Golden x40

Batch 2 of the Mutation Meadow build-spec (Game Artist → Roblox Developer). Parts, built-in materials and stock engine
features only. Plugs into RD prompt 2 (`/workspace/roblox/ra12-m-art.md`): `Visuals.applyMutation(model, key)`,
`Role=="fruit"`, the invisible `Fx` PrimaryPart, and the pooled `MutFx` / `MutDrops` emitters.
Refs (look only, **numbers in this file win**): `refs/mut_01_pumpkin_states.png`, `refs/mut_02_crop_grid.png`.

There is no Gem mutation and no rainbow. The three keys are `"wet"`, `"golden"` and `"wetgolden"`.

---

## 0. Global art calls (Mason, Oct 23 2026)

| Item | Final value | Replaces |
|---|---|---|
| **Golden hex** | **#FFC300** (255,195,0). Shade **#E0A100**, highlight **#FFF1A8** | `Visuals.MUT.golden` (255,200,40) = #FFC828. The spec's #FFC300 wins. |
| Gold look | Built-in `Enum.Material.Metal` + modest Reflectance + one painted highlight part + a rare glint. **No Foil, no Neon base, no sparkle haze, no `sparkles_main` cloud.** Handmade, toy-like. | RD draft's Foil + sparkles_main.dds at rate 8 |
| Where gold may appear | **Only** on the Golden / Wet+Golden mutation (crop, pedestal, Backpack/Index mutation chip, reveal). | `UI.COLORS.gold` (240,190,60) on Sell buttons and the Block Party meter |
| UI Sell buttons | Leaf green **#4CAF50** (pressed #3D8C40, text #FFFFFF, stroke #1E1B2E) | gold |
| Block Party meter | Flat sunflower-petal yellow **#FFE066**, no gradient, no shine, track #1E1B2E @ 0.35 transparency | gold |
| Brass (VIP only) | **#B08D57** base / **#D4BC8A** light / **#7A5F36** dark. Satin: SmoothPlastic, Reflectance 0.05, **no particles, no light** | #A89670 (`StreetBuilder.BRASS`, `Cosmetics.BRASS`) and 01-crops §0.6 |
| Wet+Golden | Gold base, darker glossy wet sheen, Wet's beads and drip. Reads as both. | mint (150,255,220) |
| Labels | Lower-case **x**: `Wet x2`, `Golden x20`, `Wet+Golden x40` | "×" |

Brass vs Golden at a glance: brass is desaturated, darker (lum 0.57 vs 0.76), SmoothPlastic and never sparkles; Golden is
saturated #FFC300 Metal with a cream highlight and a glint. They never share a screen region (brass = VIP trims only).

---

## 1. How it plugs in

### 1.1 Which parts get recoloured
- RD's role system: every part with `Role == "fruit"` is a mutation target. Map from 01-crops: `Fruit#` → role `fruit`,
  `Tone = "base"`; `FruitDetail#` → role `fruit`, `Tone = "detail"`. Set `Tone` as a part attribute in `CropBuilder`.
- Nothing else changes colour (leaves, stems, soil stay). Exception: Wet darkens the soil mound (§3.4).
- Exceptions by crop:
  - **Strawberry calyx** (`FruitDetail1–4`, #5BC236) and **Dragon Fruit scales** (`FruitDetail1–6`, #7BC043) are green
    details. Golden turns them **#E0A100** (whole fruit reads gold, the toy look). Wet just darkens them.
  - **Corn husks** (`FruitDetail1–2`) stay green under Golden (only the kernels `Fruit1–2` go gold) so the cob looks
    gilded inside a green husk. Wet darkens both.
  - **Moon Melon `FruitDetail3` crescent** #F3F5FF → Golden **#FFF1A8** (it becomes the highlight; skip the extra
    `GoldLight` part on Moon Melon). `FruitDetail4` crescent cut → #FFC300.

### 1.2 Restore
`applyMutation(model, nil)` must return the model to its template look. Simplest: CropBuilder already rebuilds by
`stage..muts` key, so clone a fresh template instead of restoring. If RD restores in place, cache `BaseColor`,
`BaseMaterial`, `BaseReflectance` attributes on first apply, and destroy everything named `Mut*` / `GoldLight`.

### 1.3 Added instances (all names start with `Mut` or `Gold` so cleanup is one loop)
| Instance | Wet | Golden | Wet+Golden | Parent |
|---|---|---|---|---|
| `GoldLight` part (painted highlight) | - | 1 | 1 | model |
| `MutBead1..n` parts | 6-10 | - | 6-10 | model |
| `MutLight` PointLight | - | 1 | 1 | `Fx` part |
| `MutFx` emitter (pooled, glint **or** drip) | drip | glint | glint | `Fx` part |
| `MutDrops` emitter (pooled) | - | - | drip | `Fx` part |

Wet uses the `MutFx` slot for its drip (same settings as `MutDrops`), so plain Wet costs 1 emitter, Golden 1,
Wet+Golden 2 (matches RD's "counts as 2").

---

## 2. Golden x20

### 2.1 Fruit parts
| Tone | Color | Material | Reflectance | Transparency |
|---|---|---|---|---|
| base (`Fruit#`) | **#FFC300** | `Enum.Material.Metal` | 0.15 | 0 |
| detail (`FruitDetail#`) | **#E0A100** | `Enum.Material.Metal` | 0.10 | 0 |

- Metal gives a brushed, slightly grainy toy-gilt read. If Metal's grain looks noisy on a phone at 30 studs, fall back
  to `SmoothPlastic`, Reflectance 0.25 (same hexes). Decide from one screenshot; do not use Foil or Neon either way.
- `CastShadow` unchanged.

### 2.2 `GoldLight`: the painted highlight (1 part)
A hand-painted "shine" decal made from a part, like a toy's painted highlight. On the **largest** `Fruit` part only.

| Prop | Value |
|---|---|
| Shape | Block + `SpecialMesh` MeshType=Sphere (Ell) |
| Size | (0.30·Fx, 0.20·Fy, 0.06), where Fx,Fy are the largest fruit part's X,Y size, clamped to min 0.14 × 0.10 |
| Placement | on the fruit surface along the unit direction **(−0.45, 0.55, −0.70)** in the fruit's local frame (upper-left-front, the key-light side); push out by 0.02 so it doesn't z-fight; rotate so its thin axis is the surface normal |
| Color / Material | **#FFF1A8**, SmoothPlastic, Reflectance 0 |
| Flags | Anchored, CanCollide/Touch/Query false, CastShadow false |

Per crop (largest fruit part): carrot Fruit1, strawberry Fruit3 (front berry), blueberry Fruit1, tomato Fruit1, corn
Fruit1, pumpkin Fruit1, watermelon Fruit1, dragonfruit Fruit1, moonmelon none (crescent becomes the highlight).

### 2.3 Glint (`MutFx`, Golden mode): restrained, one at a time
One small star now and then. Never a cloud.

| ParticleEmitter prop | Value |
|---|---|
| Texture | default (`rbxasset://textures/particles/sparkles_main.dds`, the engine default, verified on the API ref). Do **not** set any other texture. |
| Color | ColorSequence #FFF1A8 → #FFFFFF |
| LightEmission / LightInfluence | 0.4 / 0 |
| Rate | **0.35** (≈ one glint every 3 s). reducedFx: × `REDUCED_RATE` 0.25 |
| Lifetime | 0.35 - 0.45 |
| Speed / SpreadAngle | 0 / (0,0) |
| Size | NumberSequence {0: 0, 0.5: 0.55, 1: 0} (pumpkin/watermelon/moonmelon 0.7) |
| Transparency | {0: 0.1, 1: 0.1} |
| Rotation / RotSpeed | 0 - 45 / 0 |
| Squash | 0 (keep the star shape; it is the colour-blind cue vs Wet's droplets) |
| Orientation | FacingCamera |
| Shape | Box, ShapeStyle **Surface**, emitter parent `Fx` sized to the fruit bounds × 0.9 |
| ZOffset | 0.3 |
| LockedToPart | true |

Optional script variant (if RD prefers no constant emitter): `Enabled=false`, `Emit(1)` every `4 + rand()*3` s.

### 2.4 `MutLight` PointLight
| Prop | Golden | Wet+Golden |
|---|---|---|
| Color | #FFD27A (warm, not the fruit hex) | #FFD27A |
| Brightness | 0.6 | 0.5 |
| Range | 5 (pumpkin/watermelon/moonmelon 6) | same |
| Shadows | false | false |

Cap: ≤ 8 `MutLight`s on screen (nearest first, RD's rule). Moon Melon: destroy `MoonGlow` when Golden/Wet+Golden.

---

## 3. Wet x2

### 3.1 Fruit parts
Rule: HSV **V × 0.85, S × 1.15** (clamped), Material unchanged (SmoothPlastic), **Reflectance 0.30**. Precomputed:

| Crop | Part tone | Base → Wet |
|---|---|---|
| carrot | Fruit1 / crown ring | #F58C28 → **#D06A08** / #E07A1E → **#BE5B01** |
| strawberry | berries / calyx | #E63246 → **#C31427** / #5BC236 → **#40A51C** |
| blueberry | berries | #465AC8 → **#2B3EAA** |
| tomato | fruit | #DC3228 → **#BB150B** |
| corn | kernels / husks | #F5D23C → **#D0AE1B** / #8DC63F → **#71A824** |
| pumpkin | core / lobes | #F0821E → **#CC6100** / #E27318 → **#C05700** |
| watermelon | rind / stripes | #3CA046 → **#268830** / #1F6B2A → **#115B1B** |
| dragonfruit | skin / scales | #EB46A0 → **#C8267E** / #7BC043 → **#60A329** |
| moonmelon | skin / bands / crescent | #BEC8FF → **#99A3D9** / #A9B6F5 → **#8693D0** / #F3F5FF → **#CDCFD9** |

Wet corn kernels (#D0AE1B) are darker and duller than Golden (#FFC300 Metal) and carry beads, so they don't read gold.

### 3.2 Beads (`MutBead#`): the main Wet read
| Prop | Value |
|---|---|
| Shape | Ball, size **0.16 / 0.20 / 0.24** (mix, in that ratio 2:2:1) |
| Color | **#DFF4FF** |
| Material | `Enum.Material.Glass` |
| Transparency / Reflectance | 0.35 / 0.25 |
| Flags | Anchored, CanCollide/Touch/Query false, CastShadow false |
| Count | carrot 6, strawberry 6 (spread over the 4 berries), blueberry 6, tomato 8, corn 6 (on kernels + husk tips), pumpkin 10, watermelon 10, dragonfruit 8, moonmelon 10 |
| Placement | on `Fruit#` surfaces only, upper 2/3 (local y ≥ −0.2·Fy) and front-facing hemisphere preferred (z ≤ 0.3·Fz), sunk 40 % of their diameter. Deterministic: seed a `Random.new(tileId*7919 + cropIndex)` so beads don't jump on rebuild. Min spacing 0.25 studs. |

Ellipsoid surface point for a part of size (X,Y,Z) along unit direction d: `p = d * 0.5 / sqrt((dx/X)^2+(dy/Y)^2+(dz/Z)^2)`.

### 3.3 Drip (`MutFx` in Wet mode, `MutDrops` in Wet+Golden)
| ParticleEmitter prop | Value |
|---|---|
| Texture | default (sparkle) - squashed into a drop shape below |
| Color | #8FD3FF |
| LightEmission / LightInfluence | 0.1 / 1 |
| Rate | **3** (pumpkin/watermelon/moonmelon 4). reducedFx × 0.25 |
| Lifetime | 0.5 - 0.8 |
| Speed | 0 - 0.5, EmissionDirection Bottom |
| Acceleration | (0, −16, 0) |
| Drag | 0 |
| Size | {0: 0.10, 0.2: 0.14, 1: 0.12} |
| Squash | {0: 0.9, 1: 1.3} (tall drop; the colour-blind shape cue) |
| Transparency | {0: 0.15, 0.8: 0.3, 1: 1} |
| Orientation | VelocityParallel (falls as a streak, not a star) |
| Shape | Box, ShapeStyle Volume, emitter on an Attachment `MutDripAt` at the fruit's lowest front point (fruit centre + (0, −0.35·Fy, −0.25·Fz)), Box covering 0.6·Fx × 0.05 × 0.4·Fz (use the `Fx` part only if RD keeps a single emitter host; then size `Fx` to that slab) |
| ZOffset | 0 |
| LockedToPart | false (drops stay in world) |

### 3.4 Wet soil (no new part)
`Root` colour #7A4E2D → **#683D1C**, Reflectance 0.10 while Wet or Wet+Golden. Restore on clear.

### 3.5 Wet light
None. (Moon Melon keeps `MoonGlow` under Wet.)

---

## 4. Wet+Golden x40

It must read as **gold** first and **wet** second, in that order, at 30 studs and in greyscale.

| Element | Value |
|---|---|
| Fruit base (`Tone=base`) | **#D9A600** (Golden through the Wet rule: darker, glossier), `Metal`, **Reflectance 0.35** |
| Fruit detail (`Tone=detail`) | **#BE8900**, `Metal`, Reflectance 0.30 |
| `GoldLight` | as §2.2, #FFF1A8 (now reads as a wet specular highlight; keep it) |
| Beads | as §3.2 but Color **#E8F6FF**, Transparency 0.30 (clear-blue beads on gold = "wet") |
| Drip | `MutDrops` as §3.3, Color #8FD3FF |
| Glint | `MutFx` as §2.3, Rate **0.25** (rarer than Golden so the glint doesn't fight the drip) |
| `MutLight` | §2.4, Brightness 0.5 |
| Soil | wet soil §3.4 |
| Corn | kernels #D9A600, husks wet green #71A824 |
| Moon Melon | crescent #FFF1A8; destroy MoonGlow |

**Replace** `Visuals.MUT.wetgolden` mint (150,255,220). For UI chips (Backpack, Index, pedestal tag) Wet+Golden uses
a **gold fill #FFC300 with a 2 px blue UIStroke #50AAFF** (Wet's existing `MUT.wet` (80,170,255)). Golden chip = gold
fill + #1E1B2E stroke. Wet chip = #50AAFF fill + #1E1B2E stroke. Chip text: `Wet x2`, `Golden x20`, `Wet+Golden x40`,
white #FFFFFF, Fredoka One / GothamBlack as the UI already uses, stroke #1E1B2E.

Greyscale check (relative luminance): gold 0.76, wet-gold 0.65, corn 0.81 but matte with no light/glint, wet corn 0.67
with beads. The two cues that separate them for colour-blind players are **shape**: drops (squashed, falling) vs
stars (static, round), and **beads** (Wet only).

---

## 5. Budgets (per mutated crop)

| Key | Extra parts | Emitters | Lights | Notes |
|---|---|---|---|---|
| wet | 6-10 beads | 1 (drip, rate 3-4) | 0 | |
| golden | 1 (`GoldLight`) | 1 (glint, rate 0.35) | 1 | |
| wetgolden | 7-11 | 2 (drip 3-4 + glint 0.25) | 1 | counts as 2 emitting crops |

- Worst crop: Wet+Golden pumpkin/watermelon/moonmelon = ripe 7-9 parts + 11 = **≤ 20 parts** (template 13 max + 11 = 24
  theoretical cap; RD's `maxParts` 10 for ripe does not include mutation extras; add `maxMutParts = 11`).
- Plot rule (RD): ≤ 3 emitting mutated crops per plot, nearest first, Wet+Golden counts 2. Rates are all ≤ 4, far
  under RD's Rate ≤ 20 cap and lower than the draft's 8/8/14, so **Perf.spec constants must be updated** from 8/8/14
  to **3 / 0.35 / 3+0.25** (only gets cheaper; flag to RD so the spec test isn't red).
- Textures: none custom (default sparkle only), so the ≤128 px rule is satisfied trivially.
- `lodStuds` 160: beyond it, keep colours and `GoldLight`, disable emitters and lights, keep beads only if the crop is
  within 80 studs (beads are tiny; drop them first).
- ViewportFrames (Backpack/Index icons) don't render particles or PointLights: there the colour, `GoldLight` and beads
  carry the read. Pedestals in the world get the full treatment.

---

## 6. Answers to RD's placeholders (prompt 2)

| Placeholder | Value |
|---|---|
| bead colour | #DFF4FF Glass T0.35 R0.25 (Wet); #E8F6FF T0.30 on Wet+Golden |
| drip rate | 3 (large fruit 4); Lifetime 0.5-0.8; Accel (0,−16,0) |
| PointLight brightness / range | 0.6 / 5 (Golden), 0.5 / 5 (Wet+Golden); large fruit Range 6; Color #FFD27A |
| glint size / lifetime | peak 0.55 (large 0.7) / 0.35-0.45 s, Rate 0.35 (0.25 on Wet+Golden) |
| texture | engine default only; remove the explicit `sparkles_main.dds` cloud usage and Foil |
| Golden material | Metal R0.15 (fallback SmoothPlastic R0.25), never Foil/Neon |

---

## 7. Conflicts / changes RD must make

| # | Where | Now | Change to |
|---|---|---|---|
| M1 | `Visuals.MUT.golden` | (255,200,40) #FFC828 | (255,195,0) #FFC300 |
| M2 | `Visuals.MUT.wetgolden` | mint (150,255,220) | gold #FFC300 + blue stroke #50AAFF for UI; crop look §4 |
| M3 | RD draft prompt 2 | Foil + `sparkles_main.dds` emitter, rates 8/8/14 | Metal + `GoldLight` + glint 0.35; drip 3 |
| M4 | Perf.spec | expects 8/8/14 | 3 / 0.35 / 3+0.25 |
| M5 | `UI.COLORS.gold` | Sell buttons + Block Party meter | Sell #4CAF50; meter #FFE066; keep a `mutGold` #FFC300 only for mutation chips |
| M6 | `StreetBuilder.BRASS`, `Cosmetics.BRASS`, 01-crops §0.6 | #A89670 | #B08D57 / #D4BC8A / #7A5F36 satin |
| M7 | Labels | "×2/×20/×40" | "x2/x20/x40" |
| M8 | Purple-gold x40 badge (marketing capture badge in the old draft) | purple + gold | game UI uses gold + blue; purple only if a marketing asset already shipped with it |
| M9 | RD role list | `role` "fruit" has no tone | add `Tone` attribute (base/detail) for the two gold shades |

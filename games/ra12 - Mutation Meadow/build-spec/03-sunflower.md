# 03 - Block Party Sunflower

Batch 3. Procedural Parts sunflower for `Workspace.Street.Sunflower`. Plugs into RD prompt 3
(`SunflowerController` builds locally when the Street streams in; the server keeps `Stem` + Water prompt and the
attributes `Phase` / `Stage` / `Waters` / `Goal`). Replaces today's transparency swap of five MeshParts
(`Drooping`/`Perking`/`Standing`/`Bloom`/`Wilt`) with one Model tweened between four pose CFrames.
Refs: `refs/sunflower_poses.png`, `refs/sunflower_bloom.png`.

Config (BlockParty, already in code):
```
stages = { perking = 0.33, standing = 0.66, bloom = 1.0 }
wiltSec = 60
rangeStuds = 15
```
Stage keys on the model: `"drooping"` | `"perking"` | `"standing"` | `"bloom"`. Phase `"open"` | `"weather"` | `"wilt"`.

---

## 0. Look targets (RD draft + Mason)

| Element | Hex / note |
|---|---|
| Petals (Butter Sun) | **#FFD23F** SmoothPlastic R0. Bloom = full sat. Drooping desat → **#E6C96D**. Wilt → **#C8B070** |
| Disc (centre) | **#7A4E2D** SmoothPlastic. Bloom seeds (dots) #5C3A1F |
| Stem | **#5BC236**. Wilt / drooping → **#6EAF56** |
| Leaves | **#2E7D32** top, **#4E9A2A** underside. Drooping → **#3F7041** / **#5B8B44** |
| Height at bloom | **22 studs** from ground to disc centre (RD's ~22). Head diameter ~9. Petals extend ~3.5 beyond the disc. |
| Thirsty icon | BillboardGui above the head while `phase=="open"` and `waters < goal` (§5) |

Fix vs CaptureService / today's MeshPart: Bloom head was (255,205,0) / (255,200,0). Use #FFD23F petals + #7A4E2D disc.

---

## 1. Model structure

```
Sunflower (Model, PrimaryPart = Root)
├── Root            -- invisible anchor at ground under the Street sunflower pad
├── StemBase        -- fat stump that never tilts
├── Stem1..Stem4    -- stacked CylV segments (tweened)
├── LeafL1, LeafL2, LeafR1, LeafR2
├── HeadPivot       -- invisible Part at the top of Stem4; holds the head assembly
│   ├── Disc
│   ├── SeedDot1..8
│   └── Petal1..18
├── FxBloom         -- Attachment at disc centre for bloom VFX
└── Stem            -- the existing ProximityPrompt host (server-owned; keep the name)
```

- Client builds everything except `Stem` (server already owns that part + Water prompt). Parent the new parts under the
  streamed Model; do not destroy `Stem`.
- All art parts: Anchored=true (or WeldConstrainted to Root with Root anchored), CanCollide/Touch/Query=false except
  `Stem` which keeps its prompt collision rules.
- Material: SmoothPlastic everywhere. **No Foil / Neon / Metal. No gold.**
- Origin O = ground under the Street sunflower (raycast or the pad's top). Front = −Z (toward the plots / road).

---

## 2. Part list (bloom pose, rest pose; 34 parts)

Sizes in studs. Offsets relative to O. Rotations in degrees, applied as `CFrame.Angles(rx,ry,rz)`.

### 2.1 Stem
| Name | Shape | Size | Offset (bloom) | Rot | Hex |
|---|---|---|---|---|---|
| Root | Block | (0.2, 0.2, 0.2) | (0, 0.1, 0) | — | #7A4E2D, Transparency 1 |
| StemBase | CylV | (1.6, 1.4, 1.4) | (0, 0.8, 0) | — | #4E9A2A |
| Stem1 | CylV | (5.0, 1.1, 1.1) | (0, 4.1, 0) | — | #5BC236 |
| Stem2 | CylV | (5.0, 1.0, 1.0) | (0, 9.1, 0) | — | #5BC236 |
| Stem3 | CylV | (5.0, 0.9, 0.9) | (0, 14.1, 0) | — | #5BC236 |
| Stem4 | CylV | (3.5, 0.8, 0.8) | (0, 18.35, 0) | — | #5BC236 |
| HeadPivot | Block | (0.3, 0.3, 0.3) | (0, 20.3, 0) | — | Transparency 1 |

Segment lengths sum to ~19.5 of stem + base; disc centre lands at y≈21.1; petals peak at ~23.5. Close enough to "22 studs
tall at bloom" for the disc.

### 2.2 Leaves (4)
| Name | Shape | Size | Offset (bloom) | Rot | Hex |
|---|---|---|---|---|---|
| LeafL1 | Wedge | (0.25, 1.6, 3.2) | (−1.6, 6.0, 0.2) | (0, 90, −25) | #2E7D32 |
| LeafR1 | Wedge | (0.25, 1.6, 3.2) | (1.6, 7.5, −0.2) | (0, −90, 25) | #2E7D32 |
| LeafL2 | Wedge | (0.22, 1.3, 2.6) | (−1.3, 11.5, −0.4) | (0, 110, −20) | #4E9A2A |
| LeafR2 | Wedge | (0.22, 1.3, 2.6) | (1.3, 13.0, 0.3) | (0, −110, 20) | #4E9A2A |

Wedge tip points away from the stem. CastShadow true on leaves and StemBase–Stem3.

### 2.3 Head
| Name | Shape | Size | Offset from HeadPivot | Rot | Hex |
|---|---|---|---|---|---|
| Disc | CylV then rx=90 (faces −Z) | (0.70, 3.6, 3.6) | (0, 0.8, 0) | as above | #7A4E2D |
| SeedDot1..8 | Ball | 0.35 | on Disc face in a 1.1-radius ring, then a centre Dot at (0,0.8,−0.40) | — | #5C3A1F |
| Petal1..18 | Wedge | (0.18, 1.1, 3.4) | each petal's base at Disc rim, tip out | see §2.4 | #FFD23F |

Petal count **18** (within RD's 16–20). Odd number avoided so opposite petals line up.

### 2.4 Petal layout (bloom)
For i = 0..17:
```
angle = i * 20°                          -- around the disc's local Z (facing −Z)
base  = HeadPivot * CFrame.new(0, 0.8, 0)
      * CFrame.Angles(0, 0, rad(angle))
      * CFrame.new(0, 1.85 + 0.55, 0)     -- rim + half petal length along local Y of the rotated frame
petal.CFrame = base
             * CFrame.Angles(rad(-8), 0, 0)   -- slight cup toward camera (front)
```
Each petal's long axis points radially out. Slight −8° cup keeps the bloom reading open, not flat.

FxBloom Attachment at Disc centre: HeadPivot + (0, 0.8, −0.35).

---

## 3. Pose CFrame tables

Tween every movable part from its current CFrame to the pose target over **0.6 s**, `Enum.EasingStyle.Back`,
`Enum.EasingDirection.Out` (RD's ~0.6 s). Bloom pose is already the rest pose in §2. Below: deltas from bloom, applied
as relative CFrames so a rebuilt model stays consistent.

Notation: for stem segments, `tilt` is a rotation about local X (positive = tip toward +Z / away from road = droop
back). Leaves and petals also get a droop.

**Height targets are authoritative** (connected stem: tilt + HeadPivot translate cannot both be maxed). Drive disc
height from the HeadPivot translate; stem tilts are visual lean only. Measure after build and nudge tilts ±2° so
disc centres land in range — do not change the height numbers to match over-tilted stems.

Target disc-centre Y (ground = 0): bloom **21.0–21.5**, standing **20.0–20.8**, perking **18.0–19.0**, drooping
**13.5–14.5**. Bloom petal tip peak Y **~23.5** (if tips hit ~26, fix petal local offset so they stay in the disc
plane — do not lengthen the stem).

### 3.1 `standing` (stage ≥ 0.66, < 1.0)
Almost bloom height, head slightly smaller cup, petals half-closed.

| Part | Delta from bloom |
|---|---|
| Stem1..4 | tilt **+2°** each (total ~8° lean; was +4° — halved so offsets win) |
| HeadPivot | translate (0, −0.6, 0.4); tilt +10° |
| Petals | cup −35° (more closed); Color #FFD23F |
| Leaves | tip down +12° |

### 3.2 `perking` (stage ≥ 0.33, < 0.66)
| Part | Delta |
|---|---|
| Stem1..4 | tilt **+5°** each (total ~20°; was +10°) |
| HeadPivot | (0, −2.5, 1.6); tilt +28° |
| Petals | cup −55°; Color #FFD23F |
| Leaves | tip down +22° |

### 3.3 `drooping` (stage < 0.33, and the resting state between hours)
| Part | Delta |
|---|---|
| Stem1..4 | tilt **+8° / +7° / +6° / +5°** (cascade; total lean ~26°; was +16/+14/+12/+10) |
| HeadPivot | (0, −5.5, 3.2); tilt +55° (head almost faces the ground) — **keep this translate** |
| Petals | cup −70° (closed bud); Color **#E6C96D** (desat ~30%) |
| Disc / SeedDots | Color #6B4528 (slightly duller) |
| Stem* / Leaves | Stem #6EAF56, Leaves #3F7041 / #5B8B44 |
| Height of disc centre | **13.5–14.5** studs (authoritative) |

### 3.4 Wilt (phase `"wilt"`, 60 s after weather ends)
Start at bloom; over **wiltSec = 60** linearly lerp every movable part toward the drooping targets, and lerp petal /
stem / leaf colours toward the drooping desats. At the end, snap Stage to `"drooping"` (server already does). No
Back easing on wilt — use Linear so it feels like a slow sag, not a pop.

### 3.5 Guaranteed bloom (~1.5 s)
When Stage flips to `"bloom"` (waters hit goal, or the hour timer), tween **from the current pose to bloom** over
**1.5 s**, Back Out. Simultaneously fire the bloom VFX (§4). Camera shake ≤ 0.2 s, Amplitude 0.15, only within 60
studs, never when `reducedFx`.

---

## 4. Bloom VFX (≤ 3 emitters, ≤ 1 s)

Parent everything under `FxBloom`. Destroy / disable after 1.0 s.

### 4.1 Petal pop (emitter 1)
| Prop | Value |
|---|---|
| Texture | default |
| Color | #FFD23F → #FFE066 |
| Rate | 0 (use `Emit(18)` once) |
| Lifetime | 0.4 - 0.6 |
| Speed | 6 - 10, EmissionDirection Outward, Shape Ball ShapeStyle Surface |
| Size | {0: 0.4, 0.5: 0.7, 1: 0} |
| Transparency | {0: 0, 0.7: 0.2, 1: 1} |
| LightEmission | 0.3 |
| Squash | 0 |

### 4.2 Radial burst (emitter 2)
| Prop | Value |
|---|---|
| Texture | default |
| Color | weather-keyed: Rain **#3FA7F5**, Golden Hour **#FFC300** (this is the one place the golden hex may tint a
  Block Party VFX; the sunflower itself stays Butter Sun, never gilt) |
| Rate | 0; `Emit(24)` once |
| Lifetime | 0.5 - 0.8 |
| Speed | 10 - 16, SpreadAngle (180,180) |
| Acceleration | (0, −8, 0) |
| Size | {0: 0.3, 1: 0} |
| Transparency | {0: 0.1, 1: 1} |
| LightEmission | 0.5 |

### 4.3 Light-column Beam (≤ 1 s)
| Prop | Value |
|---|---|
| Attachments | `BeamBottom` at HeadPivot − (0, 8, 0); `BeamTop` at HeadPivot + (0, 14, 0) |
| Color | Rain #3FA7F5 / Golden Hour #FFC300 |
| Width0 / Width1 | 2.5 / 0.4 |
| Transparency | NumberSequence {0: 0.2, 0.7: 0.4, 1: 1}, tweened to fully transparent over 1.0 s |
| LightEmission | 0.6 |
| FaceCamera | true |
| Texture | none (solid) / or default beam texture if RD prefers; no custom asset |
| Segments | 8 |

One PointLight on HeadPivot for the bloom second only: Color matches the Beam, Brightness 1.2 → 0 over 1.0 s, Range 20.
Does not count against the crop MutLight cap (different system).

reducedFx: skip Beam + PointLight, keep `Emit` counts at half (9 / 12).

---

## 5. Thirsty BillboardGui

Shown while `phase == "open"` and `waters < goal`, hidden on bloom / wilt / weather.

| Prop | Value |
|---|---|
| Adornee | HeadPivot |
| Size | UDim2.fromOffset(64, 64) |
| StudsOffset | (0, 3.5, 0) |
| AlwaysOnTop | false |
| MaxDistance | 80 |
| Contents | a Frame 64×64, BackgroundTransparency 1; a TextLabel "💧" or, if emoji is unreliable on all
  platforms, a blue Circle ImageLabel (UICorner 1, Background #3FA7F5) with a white "!" TextLabel. Prefer the
  circle + "!" for consistency. |
| Bob | tween StudsOffset Y 3.3 ↔ 3.7 over 1.2 s, Sine InOut, looped. |

---

## 6. Budgets

| Item | Cap |
|---|---|
| Parts | 1 Root + 1 StemBase + 4 Stem + 1 HeadPivot + 4 Leaf + 1 Disc + 8 SeedDot + 18 Petal = **38** (+ server Stem) |
| Emitters during bloom | ≤ 3, live ≤ 1 s |
| Continuous emitters | 0 |
| PointLights | 1, ≤ 1 s at bloom |
| Tweens concurrent | ≤ 30 (one per movable part); use a single Spring/lerp driver if RD prefers |

LOD: beyond 160 studs, freeze at the current pose, hide SeedDots and every other petal (keep 9), kill VFX.

---

## 7. Answers to RD placeholders (prompt 3)

| Placeholder | Value |
|---|---|
| petal count | **18** |
| segment lengths | StemBase 1.6 + Stem1..3 5.0 + Stem4 3.5 (§2.1) |
| pose angles | §3 (droop cascade ~26° lean + HeadPivot +55°; standing ~8°; perking ~20°). Heights win over tilts. |
| desaturation hexes | petals #E6C96D (droop) / #C8B070 (deep wilt), stem #6EAF56, leaves #3F7041/#5B8B44 |
| thirsty icon | §5 circle + "!" |
| Bloom colour fix | petals #FFD23F, disc #7A4E2D (replace (255,200,0)/(255,205,0)) |

---

## 8. Conflicts

| # | Where | Now | Change to |
|---|---|---|---|
| S1 | CaptureService / Street MeshParts | Bloom (255,205,0), Stem (70,140,50) Grass | #FFD23F / #5BC236 SmoothPlastic |
| S2 | BlockPartyService.show | toggles Transparency of Drooping/Perking/Standing/Bloom/Wilt parts | drive pose tweens from Stage/Phase attributes; MeshParts can be deleted once the procedural model ships |
| S3 | RD draft "16–20 petals, ~22 studs" | open | locked: 18 petals, disc at ~21 studs |
| S4 | Wilt MeshPart | separate Wilt look | wilt = 60 s lerp into drooping; no fifth pose mesh |
| S5 | 505c875 connected stem | tilt + HeadPivot offset both maxed → droop disc ~17.2 | keep HeadPivot offsets + disc Y targets; halve stem tilts (§3) |

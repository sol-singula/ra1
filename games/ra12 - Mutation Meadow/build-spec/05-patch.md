# 05 - Patch (shop NPC)

Batch 5. Procedural Parts build for `Workspace.Street.Patch`. Plugs into RD prompt 4 /
`src/shared/Art/PatchBuilder.lua` and the rig contract in `PatchService` / `Patch.spec`:
required names `PumpkinHead`, `Counter`, `ShopPrompt`; attributes `Anim` and `Face`; Animations folder
with idle / wave / point / cheer / announce / lean (AnimationIds empty until authored).
Refs: `refs/patch_turnaround.png`, `refs/patch_poses.png`. Concept: `mascot/patch_character_sheet_v3.jpg`.

**No gold anywhere on Patch.** No collar, leash or rarity frame. No Wet alt skin in v1.

---

## 0. Scale and palette

| Item | Value |
|---|---|
| Height | **~0.6× R15 avatar** ≈ **3.0 studs** from floor to top of stem curl (head ~1.3× body width) |
| Origin O | floor under Patch, at the Counter's back edge centre. Front = −Z (faces the street / players) |
| Head orange | **#FF8C1A** base / **#D9661A** shade / **#FFB066** light |
| Eyes | **#1E1B2E** with 2 white highlight dots #FFF8E7 |
| Cheeks | **#FF8FB1** |
| Mouth | uncarved curved Block (happy default) #1E1B2E |
| Stem curl + leaf cowlick | stem #6B8E23, leaf #2E7D32 |
| Torso (shirt) | cream **#EADBB8** SmoothPlastic |
| Apron | green **#5BC236**, pocket #2E7D32, seed packet #FFF8E7 with a tiny #E63246 "seed" dot |
| Arms / legs | leafy green **#5BC236** / **#2E7D32** |
| Root feet | **#7A4E2D** |
| Counter | wood **#BE8C5A** WoodPlanks (code's (190,140,90)), top #A0784B |
| Material | SmoothPlastic everywhere on the character; WoodPlanks on Counter only. **No Foil / Neon / Metal / gold.** |

Code today uses `PUMPKIN = (235,120,30)` ≈ #EB781E and a Body (90,120,60). Replace both with the palette above.

---

## 1. Rig contract (do not rename)

```
Patch (Model, Anchored, PrimaryPart = Root)
├── Root                 -- invisible, at O
├── Counter              -- required name (ShopPrompt parent fallback)
│   └── ShopPrompt       -- ProximityPrompt (PatchService owns the props)
├── Body                 -- torso / apron host
├── PumpkinHead          -- required name; Face parts live under it
├── ArmL, ArmR
├── LegL, LegR
├── FootL, FootR
├── StemCurl, Cowlick
├── AnimationController → Animator
└── Animations (Folder)
    ├── idle, wave, point, cheer, announce, lean   -- Animation, AnimationId=""
```

Attributes on the Model (PatchService sets these):
- `Anim` ∈ idle | wave | point | cheer | announce | lean
- `Face` ∈ happy | wow | thinking | wink | sleepy

Until AnimationIds exist, `PatchBuilder` drives poses by tweening Motor6D.Transform (or part CFrames) to the
targets in §4 whenever `Anim` changes. Faces are **part swaps** under `PumpkinHead` (Decal-free), toggled by `Face`.

---

## 2. Part list (rest / idle pose): 28 parts + Counter

Offsets relative to O. Character stands behind the Counter (Counter is toward −Z of the body).

### 2.1 Counter
| Name | Shape | Size | Offset | Rot | Hex / Mat |
|---|---|---|---|---|---|
| Root | Block | (0.2,0.2,0.2) | (0,0.1,0) | — | T1 |
| Counter | Block | (8, 3, 3) | (0, 1.5, −3.0) | — | #BE8C5A WoodPlanks |
| CounterTop | Block | (8.2, 0.15, 3.2) | (0, 3.075, −3.0) | — | #A0784B SmoothPlastic |

`ShopPrompt` parents to Counter (PatchService already does this).

### 2.2 Body and limbs (idle)
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| Body | Block | (1.5, 1.6, 1.0) | (0, 1.5, 0) | — | #EADBB8 |
| Apron | Block | (1.55, 1.3, 0.12) | (0, 1.35, −0.56) | — | #5BC236 |
| ApronPocket | Block | (0.70, 0.55, 0.10) | (0, 1.05, −0.66) | — | #2E7D32 |
| SeedPacket | Block | (0.40, 0.50, 0.06) | (0, 1.08, −0.74) | (0,0,8) | #FFF8E7 |
| SeedDot | Ball | 0.12 | (0.05, 1.15, −0.78) | — | #E63246 |
| ArmL | Block | (0.45, 1.2, 0.45) | (−1.05, 1.55, 0) | (0,0,12) | #5BC236 |
| ArmR | Block | (0.45, 1.2, 0.45) | (1.05, 1.55, 0) | (0,0,−12) | #5BC236 |
| HandL / HandR | Ball | 0.42 | end of each arm | — | #2E7D32 (mitten) |
| LegL / LegR | Block | (0.45, 0.9, 0.45) | (±0.35, 0.55, 0) | — | #5BC236 |
| FootL / FootR | Block | (0.55, 0.25, 0.70) | (±0.35, 0.18, −0.05) | — | #7A4E2D |

### 2.3 Pumpkin head (1.3:1 vs body width: head 2.0 wide, body 1.5)
| Name | Shape | Size | Offset | Rot | Hex |
|---|---|---|---|---|---|
| PumpkinHead | Ell | (2.0, 1.7, 2.0) | (0, 2.95, 0) | — | #FF8C1A |
| HeadShadeL | Ell | (0.55, 1.55, 1.85) | (−0.75, 2.90, 0) | — | #D9661A |
| HeadLight | Ell | (0.70, 0.90, 0.50) | (0.35, 3.20, −0.85) | — | #FFB066 |
| StemCurl | CylV | (0.45, 0.28, 0.28) then a Block curl (0.12,0.12,0.40) | (0, 3.90, 0) / (0.05, 4.05, 0.15) | curl rx 35 | #6B8E23 |
| Cowlick | Wedge | (0.12, 0.35, 0.55) | (−0.55, 3.85, −0.2) | (0, 40, −25) | #2E7D32 |

### 2.4 Face parts (happy default; all under PumpkinHead, local offsets from head centre)
| Name | Shape | Size | Local offset | Hex | Notes |
|---|---|---|---|---|---|
| EyeL / EyeR | Ball | 0.28 | (±0.40, 0.15, −0.90) | #1E1B2E | |
| EyeShineL / R | Ball | 0.08 | eye + (−0.06, 0.06, −0.12) | #FFF8E7 | |
| CheekL / R | Ball | 0.18 | (±0.70, −0.15, −0.75) | #FF8FB1 | T 0.15 |
| Mouth | Block | (0.55, 0.10, 0.12) | (0, −0.35, −0.95) | #1E1B2E | slight smile: rotate z ±8 on two half-blocks, or one Block with ry 0 and a tiny Wedge corner up |

Face swap sets (toggle Transparency 0/1, never Decals):

| Face | What changes |
|---|---|
| happy | default above |
| wow | EyeL/R Size → 0.36; Mouth → open Oval Ell (0.35, 0.30, 0.12) |
| thinking | EyeL drifts +0.08 x; EyeR −0.04 y; Mouth shifts +0.08 x and shrinks to (0.35, 0.08, 0.10); optional Brow Block (0.70, 0.06, 0.08) at (0.1, 0.40, −0.92) |
| wink | EyeR → flat Block (0.30, 0.06, 0.08); EyeShineR hidden; Mouth smile wider |
| sleepy | both Eyes → flat Blocks (0.30, 0.06, 0.08); Mouth small flat; Cheeks T 0.4; head tilts +8° z in the sleepy idle |

PatchService sets Face=`sleepy` after `SLEEPY_SEC = 60` with nobody nearby.

---

## 3. Motor6D layout (for pose targets)

If RD welds instead of anchoring every part:

| Motor | Part0 | Part1 | Idle C0 (approx) |
|---|---|---|---|
| RootBody | Root | Body | (0, 1.5, 0) |
| BodyHead | Body | PumpkinHead | (0, 1.45, 0) |
| BodyArmL / R | Body | ArmL / ArmR | (±0.95, 0.55, 0) |
| ArmHandL / R | Arm* | Hand* | (0, −0.7, 0) |
| BodyLegL / R | Body | Leg* | (±0.35, −0.85, 0) |
| LegFootL / R | Leg* | Foot* | (0, −0.55, −0.05) |
| HeadStem | PumpkinHead | StemCurl | (0, 0.95, 0) |
| HeadCowlick | PumpkinHead | Cowlick | (−0.55, 0.90, −0.2) |

Apron / pocket / seed parts WeldConstraint to Body (they don't animate on their own). Counter stays anchored and
un-motor'd.

---

## 4. Pose targets (Anim attribute)

Angles in degrees, relative to idle. Tween 0.25 s Quad Out (wave/point) or 0.35 s Back Out (cheer/announce).

| Anim | Body | Head | ArmL | ArmR | Notes |
|---|---|---|---|---|---|
| idle | breath: y ±0.04 over 2 s Sine | yaw ±6° over 4 s | hang | hang | looped procedural bob until AnimationIds exist |
| wave | — | yaw toward player ~15° | — | raise to (rx −150, rz −20), hand wiggle ±25° rz @ 4 Hz for 1.2 s | Face happy |
| point | slight lean −Z 5° | look at target | — | straight out (rx −90), hand open | Face thinking or happy |
| cheer | hop y +0.3 | — | both arms raise (rx −160) | same | Face wow; land after 0.4 s |
| announce | lean −Z 8° | nod −10° | open gesture (rx −40, rz 25) | open (rx −40, rz −25) | Face wow; used with update / rare lines |
| lean (counter-lean) | translate (0, 0, −0.6), tilt rx −15° | rest on CounterTop (y drops so chin ≈ top) | fold on counter (rx −70) | same | Face happy or sleepy; ShopHello / idle-near-counter |

`LINE_LOOK` in PatchService already maps line ids → {anim, face}; keep those mappings, just fill AnimationIds later
or keep the procedural tweens forever for v1.

---

## 5. Budgets

| Item | Cap |
|---|---|
| Character parts | ≤ 30 (28 listed) |
| Counter parts | 3 |
| Concurrent tweens | ≤ 12 |
| Lights / particles on Patch | **0** |
| Gold / Foil / Neon | **0** |

LOD: beyond 120 studs, hide SeedPacket, SeedDot, EyeShine, Cheeks, Cowlick (keep silhouette).

---

## 6. Answers to RD placeholders (prompt 4)

| Placeholder | Value |
|---|---|
| head / shade / light | #FF8C1A / #D9661A / #FFB066 |
| torso | #EADBB8 |
| arms / apron | #5BC236 / #2E7D32 pocket |
| feet | #7A4E2D |
| head:body | 1.3:1 (2.0 / 1.5) |
| height | ~3.0 studs (0.6× avatar) |
| faces | Decal-free part swaps (§2.4) |
| poses | §4; AnimationIds stay "" until authored |
| gold on Patch | none |

---

## 7. Conflicts

| # | Where | Now | Change to |
|---|---|---|---|
| P1 | PatchService placeholder | PUMPKIN (235,120,30), Body (90,120,60) Fabric, Head 2.6×2.2×2.6 | palette §0, SmoothPlastic, sizes §2 |
| P2 | CaptureService.patch | Body 2×4×1 (90,120,60), Head 2.4 cube | replace with PatchBuilder output for captures |
| P3 | Animations.*.AnimationId | "" | procedural tweens in v1; ids later |

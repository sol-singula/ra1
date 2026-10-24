# 06 - Farmer avatars (Block Party crowd + capture)

Batch 6. Real Roblox R15 farmer look for the 6–8 Block Party farmers and for capture scenes
(`block_party`, `block_party_golden`). Plugs into RD's overlapping `ra12-art-prompt.txt` note that uses
`Players:CreateHumanoidModelFromDescription`, and replaces CaptureService's hand-built blocky `farmer()`.
Ref: `refs/avatars_outfits.png`.

Mason: real Roblox avatar read (R15, blocky hands, classic faces). Stock catalog ids only when verified.
**No gold on farmers** (sunhat and rainboots boots were drifting yellow/gold — fixed below).

---

## 0. Build path

Preferred (matches RD's note):
```lua
local desc = Instance.new("HumanoidDescription")
-- body colours, Face, scales below
local model = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
```
Fallback if CreateHumanoidModelFromDescriptionAsync is awkward in a capture script: build an R15-proportioned
blocky rig by hand with the part sizes in §2 (same colours / faces / outfits), Humanoid + Animator attached.
Either way the on-screen read is "classic Roblox farmer", not a custom mesh.

Farmers are NPCs (no Player). Anchor HumanoidRootPart or set Humanoid.PlatformStand / authed walk as RD prefers.
They do not need shirts/pants catalog clothing — BodyColors + a few accessory Parts are enough and avoid
unavailable clothing asset ids.

---

## 1. Proportions (R15 blocky)

| Part | Size (studs) | Notes |
|---|---|---|
| HumanoidRootPart | (2, 2, 1) | Transparency 1 |
| LowerTorso | (2, 0.4, 1) | |
| UpperTorso | (2, 1.6, 1) | |
| Head | (1.2, 1.2, 1.2) | Blocky; HeadScale 1.0 |
| UpperArm L/R | (1, 1.4, 1) | |
| LowerArm L/R | (1, 1.2, 1) | |
| Hand L/R | (1, 0.4, 1) → **mitten override** Size (1.05, 0.55, 1.05), Ball or Block with UICorner-like read | capture-plan wants mitten hands |
| UpperLeg L/R | (1, 1.5, 1) | |
| LowerLeg L/R | (1, 1.2, 1) | |
| Foot L/R | (1, 0.4, 1) | |

Scales on HumanoidDescription: HeightScale 1.0, WidthScale 1.0, DepthScale 1.0, HeadScale 1.0, BodyTypeScale 0,
ProportionScale 0 (classic blocky, not modern proportions).

Skin (Head / Arms): **#F0C8A0** = (240,200,160), matching CaptureService.

---

## 2. Faces (verified)

Use the Head's Decal named `face` / `Face`. Prefer the built-in default; catalog Face assets are optional extras
RD may enable after confirming the asset type resolves in Studio (website id ≠ texture id; HumanoidDescription.Face
wants a Face-type asset id).

| Use | Texture / id | Status |
|---|---|---|
| Default happy (recommended) | `rbxasset://textures/face.png` | **Verified** built-in engine texture |
| Smile | HumanoidDescription.Face = 144075659 | Reported across multiple face-code lists (2026); **RD must confirm in Studio** that it applies as a Face asset before shipping |
| Chill | 7074764 | same caveat |
| Check It (cheer / surprised) | 7074786 | same caveat |
| Winky | 7074864 | same caveat |

If a catalog id fails to apply, fall back to `rbxasset://textures/face.png` for every farmer. Do **not** invent
ids. Do not use FaceAccessory for the default look.

Pose → face suggestion: idle/wave Smile or default; cheer Check It; watering Chill; surprised Winky or Check It.

---

## 3. Outfits (6, cycled)

`OUTFIT_ORDER` stays: overalls, sunhat, apron, rainboots, flannel, gloves. Colours below **replace** CaptureService
where they drifted toward gold/yellow.

| Outfit | Shirt (torso) | Pants (legs) | Extra part(s) | Hex notes |
|---|---|---|---|---|
| overalls | #F0F0EB | **#3C5AA0** (denim) | — | was (60,90,160) — keep |
| sunhat | #F5C878 (warm shirt, **not gold**) | #785A3C | Hat: Cylinder disc (0.15, 2.2, 2.2) + crown Block (1.2, 0.7, 1.2), Color **#E8C56A**, Material **Fabric**, Reflectance 0. Parent to Head. | was hat (230,200,120) — pulled away from gilt; no Metal |
| apron | #C85050 | #463C32 | Apron Block (1.7, 1.4, 0.12) on UpperTorso front, #F5F0DC | keep |
| rainboots | #5AA0D2 | #3C3C46 | Boots: Foot L/R recolour **#3A7CBC** (blue rubber), **not** (240,210,40) yellow. Optional cuff Block on LowerLeg #E8E8E8 | yellow boots looked like gold — fixed to blue |
| flannel | #AA2828 | #32466E | — | keep |
| gloves | #6EAA5A | #5A503C | Gloves: Hand L/R recolour #78C878 | keep |

BodyColors mapping:
- HeadColor / LeftArmColor / RightArmColor = skin #F0C8A0
- TorsoColor = shirt hex
- LeftLegColor / RightLegColor = pants hex
- For rainboots: Legs = pants, then recolour Foot parts after build
- For gloves: recolour Hand parts after build
- For sunhat / apron: accessory Parts welded to Head / UpperTorso

**Never** use #FFC300, #FFF1A8, #B08D57, Foil, or Metal on farmers.

---

## 4. Poses

Procedural (no AnimationIds required for v1), matching CaptureService's wave/cheer arm raises and extending them:

| Pose | What moves | Duration |
|---|---|---|
| idle | slight Knee bend cycle ±4°, arm sway ±6° over 2.5 s | looped |
| wave | Right UpperArm rx −140, hand wiggle 1.5 s | 1.5 s then idle |
| cheer | both UpperArms rx −160, small hop HRP y +0.4 | 0.8 s |
| watering | Right UpperArm rx −40, rz −20; Left holds a can (optional Part 0.5×0.6×0.35 #5AA0D2 on HandL); torso tilt −Z 8° | held |
| surprised | both UpperArms rx −100, Head tilt −10°, Face Check It / Winky | 0.6 s |

Block Party crowd: **6–8 farmers** in a loose ring 8–12 studs from the sunflower, facing it (lookAt HeadPivot).
Outfit cycle by index `OUTFIT_ORDER[(i-1) % 6 + 1]`. In `block_party_golden` exactly **1** Golden crop is visible
on a nearby plot (already a CaptureService rule); farmers themselves stay un-gilt.

---

## 5. Budgets

| Item | Cap |
|---|---|
| Farmers on screen | 8 |
| Parts per farmer | R15 default (~19) + ≤ 3 accessory Parts (hat / apron / boots cuffs) |
| Catalog clothing assets | 0 required (BodyColors only) |
| Lights / particles on farmers | 0 |
| Gold / Foil / Metal | 0 |

---

## 6. Conflicts

| # | Where | Now | Change to |
|---|---|---|---|
| A1 | CaptureService.farmer | hand-built R6-ish blocks, no HumanoidDescription | R15 via CreateHumanoidModelFromDescriptionAsync (§0) or R15-proportion blocks (§1) |
| A2 | sunhat hat (230,200,120) | warm gilt | #E8C56A Fabric |
| A3 | rainboots boots (240,210,40) | yellow ≈ gold | #3A7CBC blue |
| A4 | Face ids | none | default `rbxasset://textures/face.png`; catalog ids only after Studio verify |
| A5 | mitten hands | capture-plan asks, code has block hands | Hand parts Ball / rounded block §1 |

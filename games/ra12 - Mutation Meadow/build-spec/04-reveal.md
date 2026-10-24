# 04 - Mutation Reveal (0 – 1.5 s)

Batch 4. Timed client sequence when a crop on the local player's plot (or within 60 studs) mutates.
Plugs into RD prompt 5: `RevealController` listens to the `Mutation` remote; pooled `Emit` bursts; Highlights removed
by 1.5 s; sounds from `Config.Art.revealSounds` (ids = RD picks from the Roblox built-in library; this file gives
**cue descriptions only**).
Ref: `refs/reveal_timeline.png`.

Mason: Golden is gold through materials, **no foil or sparkle haze**. Effects stay restrained.

---

## 0. When it fires

- Remote: existing Mutation signal (the one PatchService also uses for the "first mutation" line).
- Play the full sequence if: the tile is on **your** plot, OR the crop is within **60 studs** of your character.
- `reducedFx` or Settings.sfx off: skip camera punch and sounds; keep the soil puff + one Emit burst at half count;
  skip Highlight and shine sweep.
- Never stack: if a second mutation lands on the same tile before 1.5 s, cancel the first sequence's remaining tweens,
  keep the final look, and restart from t=0 for the new key.

Keys: `"wet"` | `"golden"` | `"wetgolden"`. (No Gem, no rainbow.)

---

## 1. Shared setup (t = 0)

1. Resolve the crop Model and its `Fx` / `FxAnchor`.
2. Call `Visuals.applyMutation(model, key)` **immediately** so the fruit already wears the new colours / beads /
   `GoldLight` when the burst happens (the reveal sells the change; it does not invent it).
3. Cache camera (for punch) and create a Highlight on the Model:
   | Prop | Value |
   |---|---|
   | FillColor | Wet #50AAFF / Golden #FFC300 / Wet+Golden #FFC300 |
   | OutlineColor | Wet #DFF4FF / Golden #FFF1A8 / Wet+Golden #8FD3FF |
   | FillTransparency | 0.55 |
   | OutlineTransparency | 0.15 |
   Engine cap 31 Highlights — one per reveal, destroyed by t=1.5. If the cap is hit, skip Highlight.

---

## 2. Timeline

Times in seconds from the remote. All Emit counts are for the full-FX path; halved under reducedFx.

### 2.1 t = 0.00 – Soil puff (every key)
Emitter on an Attachment at O (ground under the tile), shaped as a flat disc.

| Prop | Value |
|---|---|
| Texture | default |
| Color | #7A4E2D → #A0784B |
| Rate | 0; `Emit(14)` |
| Lifetime | 0.35 - 0.55 |
| Speed | 2 - 5, EmissionDirection Top, SpreadAngle (40, 40) |
| Acceleration | (0, −10, 0) |
| Size | {0: 0.25, 0.4: 0.45, 1: 0.1} |
| Transparency | {0: 0.2, 1: 1} |
| LightEmission | 0 |
| Squash | 0 |

### 2.2 t = 0.05 – Mutation burst

**Wet** — blue droplets (shape cue = squash + VelocityParallel):
| Prop | Value |
|---|---|
| Color | #8FD3FF → #50AAFF |
| Emit | 16 |
| Lifetime | 0.4 - 0.7 |
| Speed | 4 - 8, EmissionDirection Top, SpreadAngle (70, 70) |
| Acceleration | (0, −14, 0) |
| Size | {0: 0.12, 0.3: 0.18, 1: 0.08} |
| Squash | {0: 0.8, 1: 1.4} |
| Orientation | VelocityParallel |
| Transparency | {0: 0.1, 0.8: 0.3, 1: 1} |
| LightEmission | 0.15 |

**Golden** — gold stars (shape cue = round, no squash, FacingCamera):
| Prop | Value |
|---|---|
| Color | #FFC300 → #FFF1A8 |
| Emit | 12 |
| Lifetime | 0.4 - 0.6 |
| Speed | 3 - 6, SpreadAngle (60, 60) |
| Acceleration | (0, −4, 0) |
| Size | {0: 0.2, 0.4: 0.55, 1: 0} |
| Squash | 0 |
| Orientation | FacingCamera |
| Transparency | {0: 0.05, 0.7: 0.2, 1: 1} |
| LightEmission | 0.5 |
| RotSpeed | (−90) - 90 |

**Wet+Golden** — both bursts, Emit 10 droplets + 8 stars (total 18, still under a single "pooled burst" call if RD
fires two emitters). Same props as above.

Parent the burst emitter(s) on `Fx` / `FxAnchor`. Rate stays 0; only `Emit`. Destroy the emitter Instance after 1.0 s
(or return to the pool).

### 2.3 t = 0.10 – Wet splash ring (Wet and Wet+Golden only)
A one-shot ring at ground level.

| Approach | Spec |
|---|---|
| Preferred | a single Part, Shape Cylinder lying flat (rx=90), Size (0.06, 0.4, 0.4) at t=0.10, Color #8FD3FF,
  Material Glass, Transparency 0.3, Reflectance 0.2; tween Size → (0.06, 3.2, 3.2) and Transparency → 1 over 0.45 s,
  then Destroy. |
| Alt | ParticleEmitter Emit(20), locked to a thin torus-shaped Attachment ring, Speed 5 outward, Lifetime 0.35,
  Color #8FD3FF, Squash 0. |

No ring on plain Golden.

### 2.4 t = 0.15 – Golden shine sweep (Golden and Wet+Golden only)
Restrained. **Not** a sparkle haze.

| Approach | Spec |
|---|---|
| Preferred | a thin Block "bar" Size (fruitX × 1.1, 0.08, 0.12), Color #FFF1A8, Material SmoothPlastic,
  Transparency 0.2, parented to the largest Fruit, starting at local y = −0.55·Fy, tweened to +0.55·Fy over **0.6 s**
  (Linear), Transparency 0.2 → 1. Destroy at end. CastShadow false. |
| Do not | trail of sparkles, Foil flash, full-model Neon pulse, camera bloom. |

If the fruit already has `GoldLight` (§02), the sweep passes over it; they reinforce each other.

### 2.5 t = 0.00 – Camera punch (your plot or ≤60 studs; never reducedFx)
| Prop | Value |
|---|---|
| Duration | ≤ 0.3 s |
| FOV | current − 4, then back (Quad Out) |
| Offset | none (FOV only; no CameraOffset shake — sunflower bloom already has a tiny shake and they must not stack) |

### 2.6 t = 0.00 – Sound cue (descriptions only; RD picks library ids)
| Key | Cue |
|---|---|
| wet | short water drip / soft splash, ~0.4 s, gentle, no cartoon boing |
| golden | soft bright chime / coin-light sparkle, ~0.5 s, one hit, not a slot-machine roll |
| wetgolden | drip + chime layered, chime −3 dB under the drip, ~0.6 s |

Respect Settings.sfx. Put the chosen ids in `Config.Art.revealSounds = { wet=…, golden=…, wetgolden=… }`.
Volume ~0.6, RollOff MaxDistance 40, EmitterSound on the `Fx` part.

### 2.7 t = 0.80 – Highlight fade
Tween Highlight FillTransparency 0.55 → 1 and OutlineTransparency 0.15 → 1 over 0.5 s.

### 2.8 t = 1.50 – Cleanup
Destroy Highlight, splash ring (if still alive), shine bar, temporary Emit emitters. Idle MutFx / MutDrops from
02-mutations keep running. Sequence done.

---

## 3. Summary table

| t (s) | Wet | Golden | Wet+Golden |
|---|---|---|---|
| 0.00 | soil puff 14, Highlight blue, camera punch, drip SFX | soil puff 14, Highlight gold, camera punch, chime SFX | soil puff 14, Highlight gold/blue outline, camera punch, layered SFX |
| 0.05 | droplet Emit 16 | star Emit 12 | droplet 10 + star 8 |
| 0.10 | splash ring | — | splash ring |
| 0.15 | — | shine sweep 0.6 s | shine sweep 0.6 s |
| 0.80 | Highlight fade | Highlight fade | Highlight fade |
| 1.50 | cleanup | cleanup | cleanup |

---

## 4. Budgets

| Item | Cap |
|---|---|
| Concurrent reveal sequences on screen | ≤ 2 (nearest); queue / drop the rest |
| Emit particles per reveal | ≤ 30 (Wet+Golden worst = 14 + 10 + 8 = 32 → drop soil to 10 under pressure) |
| Temporary parts | ≤ 2 (ring + shine bar) |
| Highlights | 1, ≤ 1.5 s |
| Sounds | 1 |

---

## 5. Conflicts

| # | Where | Now | Change to |
|---|---|---|---|
| R1 | RD draft "gold stars" via sparkles_main cloud | continuous sparkle | one-shot Emit of stars, then the idle glint from 02 (Rate 0.35) |
| R2 | Sound ids | open | cue descriptions only; RD fills `Config.Art.revealSounds` from the built-in library |
| R3 | Camera | punch FOV−4 ≤0.3 s | confirmed; no CameraOffset |

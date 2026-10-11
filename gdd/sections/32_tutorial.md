## 32. Tutorial

> **Owner:** A1 Vision & Onboarding. This section scripts the first 15 minutes line by line: the twelve tutorial
> quests `QST_TUT_001`–`QST_TUT_012` (IDs and titles fixed by canon C17.1; quest rows in §20), their dialogue,
> prompts per input device, highlights, timing, animations, rewards, recovery, skip and resume rules, analytics,
> and the post-tutorial contextual tips. Widget reveal order follows §24.3 (progressive disclosure), and input
> glyphs follow §24.3.2 default bindings.

### 32.1 Purpose

Within 15 minutes, a new player must understand the twelve things in brief Part 21: (1) moving, (2) taking orders,
(3) preparing food, (4) serving, (5) satisfaction, (6) what angry customers do, (7) self-defense, (8) repairing,
(9) earning money, (10) buying mutations, (11) upgrading the restaurant, (12) how employees work. They should also
laugh at least three times. The first tantrum has to be memorable, the first mutation exciting, and the first hire
has to *show* that the restaurant earns while they're away.

**Experience goals.** Learning by doing, never by reading (≤ 2 dialogue lines between player actions). The mentor
is funny and affectionate. Mistakes recover automatically and comically. Every step ends in a reward. Players can
always skip once they've cooked their first burger.

### 32.2 Rules & Mechanics (global)

1. **Sequential, server-owned steps.** Steps 1–12 run in order. Each step has objectives validated by the server
   from domain events (§32.13). A step is persisted only when it completes, and it then grants its rewards exactly
   once (idempotency key = quest ID).
2. **Solo interior during steps 1–9.** The player's interior is tutorial-locked: visitors see an "Under Renovation"
   sign on the façade and cannot enter, and only scripted customers spawn. Steps 10–12 take place in the shared
   city and the player's interior.
3. **Mentor delivery.** Nana Gristle (`NPC_001`) speaks from a hologram menu board. One board is on the shack's
   façade, one is above the counter inside, and in step 10 she "borrows" the Mutation Mart's price board ("Every
   menu board in town is my menu board now"). Lines appear in a bottom subtitle panel plus a speech bubble on the
   board, with toaster-gibberish voice barks (§26).
   - *Blocking* lines (marked **[B]**) pause customer patience and station timers until they are dismissed or
     auto-advance.
   - *Barks* (unmarked) never pause anything.
   - Auto-advance happens after `max(2.5 s, 0.055 s × characters)`. Click, tap or the gamepad A button advances
     early.
4. **Guidance layers** (escalating; §32.3 timing):
   - L0: the objective chip in the tracker.
   - L1: a `Highlight` on the target (yellow outline, AlwaysOnTop) plus a pulsing prompt glyph.
   - L2: a footprint `Beam` trail from the player to the target and a screen-edge arrow when the target is off-screen.
   - L3: a Nana nudge line and a gentle camera nudge toward the target (not with Reduced Motion).
   - L4: an assist that makes the step easier (an extra-wide window, a ghost overlay, a free taxi). Assists never
     complete a step for the player, except the last-resort Auto-Flip in §32.3.
5. **Tutorial Assist modifiers** (§32.3) apply only to the player's restaurant while `tutorial.step < 12`. They are
   pushed onto the service modifier stacks of CookingService, CustomerAIService and CombatService, and popped on
   completion or skip.
6. **Progressive HUD.** Widgets appear exactly when needed (§24.3): ticket and order queue at step 2, XP bar at
   step 3, MB counter at step 5, combat HUD at steps 6–7, condition widget at step 8, ability bar, Morph menu and
   MS counter at step 10, Restaurant Hub and Upgrades at step 11, Employees and the offline preview at step 12.
7. **No dead ends.** Every failure has an automatic recovery, and no objective can become impossible (§32.14).
8. **Skip** is offered after `QST_TUT_003` completes (§32.10). **Resume** after a disconnect restarts the first
   incomplete step with step-specific re-setup (§32.14).

### 32.3 Variables [TUNABLE]

| Variable | Value | Notes |
|---|---|---|
| Target total duration | 15:00 (p50), ≤ 20:00 (p90) | §32.4 timeline |
| Patience multiplier, scripted customers | Grandma Golem ×3, Polite Demon ×2, walk-in (step 12) ×2 | on top of §9 values |
| Patience pause | during every **[B]** line and while the player is idle-paused | |
| Perfect window | × 1.5 during steps 3–6 (2.0 s → 3.0 s at Lv1) | canon C8 baseline |
| Burn delay | `T_burn = T_ready + 12 s` (×2); ON_FIRE suppressed until step 12 is complete | fire is taught by a contextual tip |
| Undercooked recovery | an UNDERCOOKED item may go back on the grill and continue cooking | tutorial only |
| Waste and trash cost | waived | canon C9 charges at the trash otherwise |
| Auto-Flip assist | after 3 BURNED patties in one step, the next patty auto-removes at GOOD | the only auto-complete assist |
| Assembly ghost | shown after 2 wrong-order attempts | |
| Karenosaurus anger beats | 32 → 48 → 63 → 78, 4.0 s apart after serve (or 30 s after ordering if unserved) | escalation rolls bypassed (scripted) |
| Karenosaurus combat | Huff Points 48; 4 damage per hit; wind-up 1.0 s (1.5 s after 2 missed blocks); ≥ 3.0 s between attacks; walk speed 10 | canon defaults in §11 apply after the tutorial |
| Player "Plot Armor" | HP cannot drop below 1 during step 7 | no KO in the tutorial |
| Polite Demon splash | anger set to 35 (Complaining) when hit by the scripted throw | demonstrates +25 × sensitivity |
| First repair | free | §15 prices apply afterwards |
| Pigeon Taxi assist | offered free after 40 s of walking in step 10, or if the player is > 60 studs off the trail for 10 s | canon fare 25 MB × tier otherwise |
| Idle handling | nudge at 30 s; pause (timers frozen, "Paused – press any key") at 90 s | |
| Guidance escalation | L1 at step start; L2 after 8 s without progress; L3 after 20 s; L4 per-step trigger | |
| Tutorial upgrade price | target 200 MB, band 150–250 MB | selection rule in §32.6.11 |
| Reward totals | 600 MB, 360 quest XP (+ per-serve XP), 10 MS, 1 Morph Capsule, 1 tutorial mutation, `EMP_001`, 2 titles, 1 emote | §32.5 |

### 32.4 Minute-by-Minute Timeline

"Learns #" refers to the twelve brief Part 21 items listed in §32.1. Wallet and XP are cumulative (≈ where
per-serve values apply).

| Clock | Step / quest | Beat | Learns # | Wallet MB | XP |
|---|---|---|---|---|---|
| 00:00–00:08 | 1 `QST_TUT_001` | Spawn on Restaurant Row at the player's plot; 4 s fly-by of the shack (cut with Reduced Motion); Nana's hologram flickers on | 1 | 0 | 0 |
| 00:08–00:30 | 1 | Walk to the door following the footprint trail | 1 | 0 | 0 |
| 00:30–00:40 | 1 | Interact with the sticky door; fade into the interior | 1 | 0 | 0 |
| 00:40–01:20 | 2 `QST_TUT_002` | Grandma Golem walks in, reads the menu and waves; the player takes the order; ticket and patience ring explained | 2 | 0 | 0 |
| 01:20–01:45 | 3 `QST_TUT_003` | Bun from the Pantry to the Assembly Counter | 3 | 0 | 0 |
| 01:45–02:10 | 3 | Patty from the Fridge onto the Grill | 3 | 0 | 0 |
| 02:10–02:40 | 3 | Grill timing ring; remove at PERFECT or GOOD | 3 | 0 | 0 |
| 02:40–03:20 | 3 | Assemble bun → patty → bun; **skip becomes available** | 3 | 50 | 60 |
| 03:20–04:00 | 4 `QST_TUT_004` | Plate, then serve at the Serving Window; Grandma eats | 3, 4 | 75 | ≈ 103 |
| 04:00–04:30 | 5 `QST_TUT_005` | Satisfaction reaction card; pay + tip; MB counter appears | 5, 9 | ≈ 83 | ≈ 103 |
| 04:30–06:00 | 5 | Polite Demon orders Cheeseburger + Fizzy Soda; the player cooks with fewer hints (two trips: carry 1) | 2–5 | ≈ 171 | ≈ 146 |
| 06:00–06:25 | 6 `QST_TUT_006` | Lights flicker; the Karenosaurus storms in and orders the impossible | 6 | ≈ 171 | ≈ 146 |
| 06:25–07:05 | 6 | The player serves a Cheeseburger | 6 | ≈ 171 | ≈ 160 |
| 07:05–07:30 | 6 | Escalation: complain → soggy pickle → **table flip** → she turns on the player | 6 | ≈ 196 | ≈ 180 |
| 07:30–07:55 | 7 `QST_TUT_007` | Block ×2 | 7 | ≈ 196 | ≈ 180 |
| 07:55–08:15 | 7 | Dodge Roll; the thrown soda splashes the Polite Demon (chain reaction) | 6, 7 | ≈ 196 | ≈ 180 |
| 08:15–08:40 | 7 | Swipe Combo ×2 → Dizzy → apology → Apology Payment → escorted out | 7 | ≈ 197 | ≈ 180 |
| 08:40–09:00 | 7 | Calm Down! on the Polite Demon; "dinner theater" tip; **Level 2** | 6, 7 | ≈ 275 | ≈ 230 |
| 09:00–09:50 | 8 `QST_TUT_008` | Repair the broken table; mop the pickle puddle | 8 | ≈ 325 | ≈ 270 |
| 09:50–10:20 | 9 `QST_TUT_009` | Register cha-ching; Shift Receipt; Nana's Inheritance Envelope | 9 | ≈ 475 | ≈ 290 |
| 10:20–11:05 | 10 `QST_TUT_010` | Footprint trail to the Mutation Mart (free Pigeon Taxi if slow) | 10 | ≈ 475 | ≈ 290 |
| 11:05–11:50 | 10 | Starter Pod ceremony: try on and choose `MUT_145` / `MUT_144` / `MUT_153` | 10 | ≈ 475 | ≈ 290 |
| 11:50–12:20 | 10 | Equip in the Morph menu, try the ability on the Complaint Dummy; Downtown gate opens | 10 | ≈ 525 | ≈ 330 |
| 12:20–12:40 | 11 `QST_TUT_011` | Return Door home | 11 | ≈ 525 | ≈ 330 |
| 12:40–13:20 | 11 | Restaurant Hub → Upgrades → buy the circled upgrade; Bolt installs it | 11 | ≈ 375 | ≈ 360 |
| 13:20–13:50 | 12 `QST_TUT_012` | Ollie at the door; hire (0 MB); assign as Chef to the Grill | 12 | ≈ 375 | ≈ 360 |
| 13:50–14:20 | 12 | Ollie cooks two patties at once for a walk-in (bonus pickle) | 12 | ≈ 382 | ≈ 360 |
| 14:20–14:40 | 12 | **Offline Income Preview** card (≈ 350 MB in 2 h) | 12 | ≈ 382 | ≈ 360 |
| 14:40–15:00 | graduation | Nana's speech; title, graduation capsule; next goal "Save 1,000 MB for Tiny Mutation Diner" | — | ≈ 432 | ≈ 400 |

### 32.5 Reward Ledger

Rewards follow the canon C17.4 vocabulary. MB rewards before `QST_TUT_011` total **500 MB**, plus ≈ 25 MB of
customer income, so the 150–250 MB first upgrade is always affordable. Totals across the tutorial are **600 MB**,
360 quest XP, 10 MS, 1 capsule, 1 part and `EMP_001`.

| Step | Quest | MB | XP | Other rewards |
|---|---|---|---|---|
| 1 | `QST_TUT_001` Welcome to the Shack | 0 | 0 | Title "Shack Inheritor" |
| 2 | `QST_TUT_002` Your First Order | 0 | 0 | — (order queue unlocked) |
| 3 | `QST_TUT_003` Burger 101 | 50 | 60 | first XP (Level badge appears) |
| 4 | `QST_TUT_004` Plate It, Serve It | 25 | 30 | — |
| 5 | `QST_TUT_005` Happy Customer, Happy Wallet | 75 | 30 | MB counter revealed |
| 6 | `QST_TUT_006` Uh-Oh, Karenosaurus | 25 | 20 | — |
| 7 | `QST_TUT_007` Defend the Diner | 75 | max(50, 210 − current XP) | Emote "Phew!" · guarantees Level 2 here |
| 8 | `QST_TUT_008` Fix It Up | 50 | 40 | free first repair |
| 9 | `QST_TUT_009` Cash In | 150 | 20 | "Nana's Inheritance Envelope" |
| 10 | `QST_TUT_010` Your First Mutation | 50 | 40 | 1 of `MUT_145` / `MUT_144` / `MUT_153` (free, equip-level override, canon C13.8); 10 MS |
| 11 | `QST_TUT_011` Fancy Upgrades | 50 | 30 | — (the upgrade is a purchase) |
| 12 | `QST_TUT_012` Hire Help | 50 | 40 | `EMP_001` Ollie (hire cost 0, canon C14.4); 1 Morph Capsule; Title "Restaurant Owner (Probably)" |
| | **Total** | **600** | **≈ 360–380** | |

Customer income during the tutorial *(example values; prices per §4.1.3)*:
- Grandma: Basic Burger 9 + tip 2 − ingredients 3 = +8.
- Polite Demon: 16 + 2 − 5 = +13, plus a scripted +3 "dinner theater" tip.
- Karenosaurus: Apology Payment 40 % of 10 = 4, minus 3 ingredients = +1.
- Ollie's demo walk-in: ≈ +7.
- Total ≈ **+32 MB**.

### 32.6 Step Scripts

Format for every step: **Trigger · Objective · Timing · Setup · Dialogue · Prompts · Highlights · Animations ·
Rewards · Failure & auto-recovery · Analytics**. Dialogue speakers: **N** = Nana Gristle (`NPC_001`); other speakers
are named. **[B]** marks a blocking line. Prompts show default bindings (§24.3.2), and the client renders the live
binding via `UserInputService:GetStringForKeyCode` / `GetImageForKeyCode`. Funnel analytics: on completion, step N
logs `AnalyticsService:LogOnboardingFunnelStepEvent(player, N, "mmr_tutorial_step_NN", fields)` (§32.13).

#### 32.6.1 Step 1: `QST_TUT_001` Welcome to the Shack

- **Trigger:** first spawn of a profile with `tutorial.step = 0`, after the character and the player's plot
  façade (`BLD_17`) have loaded (`Player.CharacterAdded`, plus the plot-ready signal from RestaurantService).
- **Objective:** walk to the shack door (≥ 10 studs of movement), then interact with the door to enter the interior.
- **Timing:** 0:00–0:40.
- **Setup:** spawn 25 studs from the door, facing it. Façade in TIER_01 "broken" dressing: a crooked sign, one
  flickering letter. The plot's street area is fenced by a soft velvet rope 40 studs out.
- **Dialogue:**
  - N1 [B] (hologram flickers, static crackle): "Is this thing on? HELLO? Oh. It's you. The grand-whatever."
  - N2 [B]: "I'm your great-aunt, Nana Gristle. Tortoise head, toaster body, oven-mitt hands. Long story. Involves a blender."
  - N3 [B]: "Welcome to Morph City, where everybody's a bit of everything. And welcome to the Broken Burger Shack. It's yours now. Congratulations. Sorry."
  - N4: "I'm retired. On a cruise. But somebody has to supervise you, so I live in the menu board now. Walk to the door."
  - Jump reaction (first jump): "Jumping won't fix the roof, dear."
  - At the door: "Push the door. It sticks. Like everything here."
  - Inside (on fade-in): "Ta-da. Grease, dust and potential. Mostly grease."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Move | W A S D keycaps | left-stick glyph | ghost thumbstick on the left half, animated drag |
| Look around | hold RMB + drag | right-stick glyph | "drag here" hint on the right half |
| Enter | E "Enter" | X "Enter" | big contextual button **ENTER** |

- **Highlights:** the door gets a Highlight at once; the footprint Beam appears after 8 s without movement; a
  screen-edge arrow when the door is off-screen; the ENTER prompt pulses (static with Reduced Motion).
- **Animations:** player `ANM_001` Idle, `ANM_002` Walk, `ANM_003` Run, `ANM_004` Jump, `ANM_005` Fall/land.
- **Rewards:** title "Shack Inheritor".
- **Failure & auto-recovery:**
  - Leaving the rope area → a soft barrier plus "Wrong way! The shack's the one that looks like it lost a fight."
  - Falling out of the world → respawn at the plot spawn.
  - No input for 30 s → N4 repeats with the L3 camera nudge.
- **Analytics:** step 1. Custom field 02 = input mode at completion.

#### 32.6.2 Step 2: `QST_TUT_002` Your First Order

- **Trigger:** 2 s after the interior fade-in.
- **Objective:** take Grandma Golem's (`PER_013`) order at the counter (counter service, canon C6).
- **Timing:** 0:40–1:20.
- **Setup:** TutorialDirector spawns the Grandma Golem with a fixed tutorial look (rocky body, knitted shawl) and
  patience ×3. She walks to the counter, does `ANM_041` Read menu, then `ANM_042` Order wave. Her order is fixed to
  `RCP_BRG_001` Basic Burger with no modifications.
- **Dialogue:**
  - N1 [B]: "A customer! Don't panic. Panic is for the dinner rush."
  - N2 [B]: "That's Grandma Golem. She's made of rock and she's very patient. Rocks are like that."
  - N3: "Walk up to the counter and take her order."
  - Grandma (bubble): "One Basic Burger, sweetie. Take your time. I'm basically a boulder."
  - N4 [B] (ticket appears): "See that ticket? That's the order. Tickets are sacred. Do not lose the ticket."
  - N5: "The ring around her head is her patience. Hers lasts forever. Most customers' doesn't."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Take order | E "Take Order" | X "Take Order" | **ORDER** button |
| Peek at tickets | Tab | hold LB | tap the mini-ticket |

- **Highlights:** Grandma gets a Highlight. After the order: a coach mark on the ticket card, then on the patience
  ring.
- **Animations:** customer `ANM_002`, `ANM_041`, `ANM_042`.
- **Rewards:** none (order queue revealed).
- **Failure & auto-recovery:**
  - At 20 s: Grandma "Yoo-hoo!" and N: "She's waving. Waving means 'take my order'. Also 'hello'. Mostly the order."
  - At 45 s: screen-edge arrow plus camera nudge.
  - Patience cannot run out (×3 and paused during N lines).
- **Analytics:** step 2.

#### 32.6.3 Step 3: `QST_TUT_003` Burger 101

- **Trigger:** the ticket opens.
- **Objective:** build `RCP_BRG_001` from §6's recipe data. Sub-objectives are generated from the recipe's step
  list, so the tutorial always matches §6. Baseline: (a) bun from Pantry (`STN_PANTRY`) to the Assembly Counter
  (`STN_ASSEMBLY`); (b) patty from Fridge (`STN_FRIDGE`) onto the Grill (`STN_GRILL`); (c) remove the patty at
  PERFECT or GOOD; (d) assemble in recipe order. If §6 adds components (e.g. ketchup), extra sub-objectives use the
  same prompt patterns. If it includes a CHOP component, the chop lesson and the Auto-Rhythm hint (§32.12) are
  taught here.
- **Timing:** 1:20–3:20.
- **Setup:** Perfect window ×1.5, burn delay ×2, fire suppressed, waste cost waived (§32.3). The grill timing ring
  renders at 1.5× size.
- **Dialogue:**
  - N1 [B]: "Burger 101. Lesson one: a burger is a sandwich that went to college."
  - N2: "Grab a bun from the pantry shelf. Bun goes on the assembly counter."
  - N3: "Now a patty from the fridge. Patty goes on the grill. The grill is the hot thing. Don't lick the hot thing."
  - N4 (patty placed): "Watch the ring. When it hits the green, that's PERFECT. Grab it then."
  - PERFECT: "PERFECT! I'd cry, but I'm a toaster. I'd short-circuit."
  - GOOD: "Good! Not perfect. Good. I'll allow it."
  - Early grab (UNDERCOOKED): "Still mooing. Put it back on." (it may return to the grill)
  - BURNED: *long hologram sigh* "Burned. Classic. I burned my first four hundred." A fresh patty plops onto the fridge shelf.
  - N5 (assembly): "Bun. Patty. Bun. In that order. It's a sandwich, not modern art."
  - Wrong order: "That's… a patty hat. Bottom bun first, dear."
  - Done: "Look at that. An actual burger. With your actual hands."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Grab ingredient | E "Grab" | X "Grab" | **GRAB** |
| Place on station | E "Place" | X "Place" | **PLACE** |
| Take off grill | E "Take" (in green) | X "Take" | **TAKE** (button rim shows the ring) |
| Add to stack | E "Add" | X "Add" | **ADD** |
| Drop held item | G | B | **Drop** |

- **Highlights:** pantry → assembly counter → fridge → grill, one at a time. The green zone of the ring glows and
  carries ✓ tick marks, so it doesn't rely on color. The assembly ghost overlay shows the correct stack after 2
  wrong attempts.
- **Animations:** player `ANM_006` Carry item, `ANM_011` Grill flip, `ANM_017` Assemble stack.
- **Rewards:** 50 MB, 60 XP (Level badge and XP bar revealed). The **Skip** button appears in the tracker after
  completion (§32.10).
- **Failure & auto-recovery:**
  - BURNED → fresh patty, no charge.
  - 3 burns → Auto-Flip assist.
  - Wrong station (patty into the fryer) → the station rejects it: "That's a fryer. The patty wants the grill."
  - Bun trashed → infinite basic stock (canon C9), no charge.
  - Idle while holding an item → L2/L3 guidance toward the next station.
- **Analytics:** step 3. Assists logged via `AnalyticsService:LogCustomEvent(player, "mmr_tutorial_assist", 1, fields)` with custom field 01 = `burn_recovery` | `auto_flip` | `assembly_ghost` (§32.13).

#### 32.6.4 Step 4: `QST_TUT_004` Plate It, Serve It

- **Trigger:** the dish is assembled.
- **Objective:** plate the burger (the assembly counter doubles as plating at TIER_01, canon C7), then serve it
  through the Serving Window (`STN_WINDOW`) to Grandma.
- **Timing:** 3:20–4:00.
- **Dialogue:**
  - N1 [B]: "Plate it. Customers love plates. Plates make food look expensive."
  - N2: "Fancy restaurants take points off for food without a plate. We're not fancy. Yet. Build the habit."
  - N3: "Now slide it through the serving window to Grandma."
  - Grandma: "Ooh, still warm! Like a sunny rock."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Plate | hold E "Plate" (0.4 s) | hold X | hold **PLATE** |
| Serve | E "Serve" | X "Serve" | **SERVE** |

- **Highlights:** the assembly counter's plate icon, then the window's pickup spot with the matching ticket glow.
- **Animations:** player `ANM_018` Plate & garnish, `ANM_006` Carry item, `ANM_019` Serve (hand-off). Customer
  `ANM_043` Eat (shortened to 6 s).
- **Rewards:** 25 MB, 30 XP, plus per-serve XP (§14).
- **Failure & auto-recovery:** a dropped plate stays valid ("Five-second rule. Pick it up."); carrying it away for
  > 20 s triggers L2; serving can't go to the wrong customer because only Grandma is present.
- **Analytics:** step 4.

#### 32.6.5 Step 5: `QST_TUT_005` Happy Customer, Happy Wallet

- **Trigger:** Grandma finishes eating.
- **Objective:** (a) watch the satisfaction reaction and payment; (b) serve the Polite Demon's (`PER_003`) order,
  `RCP_BRG_002` Cheeseburger + `RCP_DRK_001` Fizzy Soda, with lighter guidance.
- **Timing:** 4:00–6:00.
- **Setup:** Grandma's S is computed by the normal formula (canon C11.3) under Tutorial Assist. A typical result is
  Delighted at ≈ 92 (W 1.0, K 1.0, M 0.20). The **reaction card** shows a face icon, the number, and the top two
  factors ("Perfect patty! ▲", "Shack is a bit shabby ▼"). The MB counter is revealed and counts up from 0 to the
  accumulated quest MB plus her payment. The Demon spawns with patience ×2; his eating is slowed to 40 s so he is
  still seated for step 7.
- **Dialogue:**
  - N1 [B]: "Moment of truth. Every customer rates their meal. See the face? That's satisfaction."
  - N2 [B]: "Happy customers pay. VERY happy customers tip. Grumpy customers… we'll get to that."
  - Grandma: "Delightful! Here's a little extra for your piggy bank."
  - N3 [B] (coins fly to the counter, `ANM_045` Tip flourish): "Cha-ching! Morph Bucks. You'll spend them on everything. Mostly on yourself. You'll see."
  - N4 (Demon enters): "Another one! The Polite Demon. Very polite. VERY polite. Don't test it."
  - Demon: "Good evening! A Cheeseburger and a Fizzy Soda, if it's no trouble. Please. Thank you. Sorry."
  - N5: "Your turn. Fewer hints. I'll be over here, judging silently." (She then fails to stay silent.)
  - Drink: "Hold to pour, let go at the line. It's fizzy, not a fountain."
  - Cheese: "Cheese goes on the patty. Cheese ALWAYS goes on the patty. It's the law."
  - Carry limit: "Two hands, both busy. One thing at a time. …Unless you grow more hands. Foreshadowing!"
  - S ≥ 70: "Look at you. Running a restaurant. I'm getting misty. That's steam. Toaster."
  - S < 70: Demon "It's… fine! Totally fine!" N: "He's being polite. The card says why. Faster next time."
- **Prompts:** as in steps 3–4, plus Pour: hold E / hold X / hold **POUR**.
- **Highlights:** first use of the Drink Dispenser (`STN_DRINK`) only. Everything else is L0 (objective chip) unless
  the player stalls for 12 s.
- **Animations:** customer `ANM_043` Eat, `ANM_044` Pay, `ANM_045` Tip flourish; player `ANM_020` Pour drink plus the
  step-3 set.
- **Rewards:** 75 MB, 30 XP (+ per-serve XP).
- **Failure & auto-recovery:** the objective is *serving* the Demon. Low satisfaction never blocks progress; it gets
  the explanatory line instead. Burn and assembly assists as in step 3.
- **Analytics:** step 5. Custom field 03 = the Demon's S band (Delighted / Happy / Meh / lower).

#### 32.6.6 Step 6: `QST_TUT_006` Uh-Oh, Karenosaurus

- **Trigger:** the Demon is served and seated.
- **Objective:** serve the Karenosaurus (`PER_001`), *or* simply survive her tantrum. The step completes at the
  final escalation beat either way.
- **Timing:** 6:00–7:30.
- **Setup:**
  - The lights flicker (cartoon thunder rumble; no flashes with Reduced Motion). The door slams open, and the
    Karenosaurus ducks in.
  - Tutorial look: T-Rex head (`MUT_032`), Tiny T-Rex arms (`MUT_161`), sunglasses pushed up on her head, an
    enormous handbag.
  - She orders `RCP_BRG_002`. Escalation is scripted (§32.3 anger beats) and rolls are bypassed. Player input stays
    live (they can walk away), but there is no combat HUD yet.
- **Dialogue (the set piece):**
  - Karenosaurus (entrance): "I have been waiting for FOUR SECONDS. Why is there a line? I want to speak to the manager."
  - N1 [B] (whisper): "Oh no. A Karenosaurus. Extinct everywhere except restaurants."
  - N2: "Stay calm. Just make her a Cheeseburger."
  - Karenosaurus (ordering): "One Cheeseburger. NO cheese. But EXTRA cheese. Make it snappy. But slow. Artisanal."
  - N3: "…Just make a normal Cheeseburger, dear. Nobody wins with her. Nobody."
  - **Beat A, anger 32 Complaining** (`ANM_047` Complain): "This cheese is TOO cheesy. And ALSO not cheesy ENOUGH. I'm leaving a review. With my FEET."
  - N4: "Complaining. That's level two. She's just warming up."
  - **Beat B, anger 48 Throwing food** (`ANM_048` Throw food): she pulls a **soggy pickle** out of her handbag and lobs it at the player in a scripted arc. SPLAT: a corner-of-screen pickle splat for 1.5 s (a small HUD pickle icon with Reduced Motion). "Your PICKLES are SOGGY!"
  - N5: "Did she… bring her own pickle? To throw? She PLANNED this."
  - **Beat C, anger 63 Destroying furniture** (`ANM_049` Flip table, then `ANM_050` Tantrum stomp): her table flips end over end and lands Broken (durability 20 %). Its chairs spin like tops, and a comic "TABLE FLIPPED!" burst pops. "And this table is the wrong SHAPE!"
  - N6 [B]: "MY TABLE! That table survived the Great Blender Blunder!"
  - N7 [B]: "Relax. Most customers just grumble and leave. She's… special. And she's coming for you. Get ready!"
  - **Beat D, anger 78 Fighting the player:** a cartoon roar, a red "!" over her head, and the combat HUD slides in. This hands off to step 7.
- **Prompts:** cooking prompts as before. No combat prompts until Beat D.
- **Highlights:** her anger meter is highlighted at each beat with the level numeral (1–6) next to its icon. The
  thrown pickle shows a ground target circle 0.6 s before landing, which foreshadows dodging.
- **Animations:** customer `ANM_002`, `ANM_046` Impatient foot tap (while waiting), `ANM_047`, `ANM_048`, `ANM_049`,
  `ANM_050`.
- **Rewards:** 25 MB, 20 XP.
- **Failure & auto-recovery:** if the player doesn't serve within 30 s, Beat A starts anyway ("I've been waiting
  FOREVER"). The pickle lands on the floor if the player isn't there, leaving a spill for step 8. The step cannot
  fail.
- **Analytics:** step 6. Custom field 03 = served (yes/no).

#### 32.6.7 Step 7: `QST_TUT_007` Defend the Diner

- **Trigger:** Beat D of step 6.
- **Objective (in order):** (a) Block 2 attacks (`ABL_003`); (b) Dodge Roll 1 throw (`ABL_004`); (c) land Swipe
  Combo hits (`ABL_001`) until the Karenosaurus is Dizzy; (d) use Calm Down! (`ABL_006`) on the splashed Polite
  Demon.
- **Timing:** 7:30–9:00.
- **Setup:**
  - Combat HUD revealed: HP bar, guard meter, base combat buttons, a hostile health bar showing her Huff Points.
  - The Karenosaurus uses the §32.3 tutorial combat values. Plot Armor keeps the player at ≥ 1 HP.
  - The In-Combat flag (canon C12.1) is live, so full-screen menus are blocked ("Can't shop during a brawl!", canon E2).
- **Dialogue and beats:**
  - **(a) Block.** She winds up a "Handbag Wallop": 1.0 s wind-up, glowing handbag, "!" plus a whoosh cue.
    - N1 [B]: "Purse incoming! HOLD Block before it lands!"
    - On a block (feathers burst, "BLOCKED!"): "Ha! Like a brick wall. A brick wall with an apron."
    - On a miss: "That's called 'getting walloped'. Hold Block BEFORE the purse lands." After 2 misses the wind-up slows to 1.5 s.
  - **(b) Dodge.** She snatches the Polite Demon's Fizzy Soda ("MINE NOW!") and hurls it in a scripted arc with a
    0.6 s ground marker.
    - N2: "Incoming soda! DODGE ROLL!"
    - On a dodge: the soda sails past and **splashes the Polite Demon**. His anger is set to 35 (Complaining), and
      small cartoon steam puffs come from his ears. Demon: "Pardon me… but I appear to be WEARING my beverage."
    - N3: "Nice dodge! …Terrible aim. Hers, I mean. Now we've got TWO problems. That's how chain reactions start in this town."
    - If the player fails to dodge twice, her third throw veers into the Demon anyway. N: "She missed you and hit HIM. Happens constantly." **The chain-reaction lesson always plays.**
  - **(c) Swipe.** She is winded and bent over for 4 s windows (repeats until she's done).
    - N4: "Now! Bonk her! Gently! It's a family restaurant!"
    - Each 3-hit combo deals 8 × 3 = 24 Huff Points (canon C12.1 at STR 0). Two combos take her from 48 to 0. Hits show
      feathers, "BONK!" letters, and her sunglasses spinning.
    - On a combo: "That's a combo! Do it again!"
    - At 0 Huff: `STS_DIZZY` 3 s with `ANM_052` Dizzy stars. N5: "She's seeing stars. Good. Now she'll calm down… eventually."
    - She recovers into `ANM_053` Apologize bow: "I… may have overreacted. Here. For the table." She pays the
      **Apology Payment** of 40 % of 10 MB = 4 MB, with no tip (canon C11.4), then `ANM_055` Escorted out:
      "I'm STILL leaving a review."
  - **(d) Calm Down!**
    - N6 [B]: "Your turn for the gentle approach. Calm Down! works best BEFORE things get flippy."
    - On use: the Demon's anger drops to Happy. Demon: "My apologies for the outburst. Most unbecoming. Please accept this gratuity for the… dinner theater." (+3 MB tip)
    - N7: "THAT is how you handle a customer. Talk first, bonk second."
  - **Level-up** (guaranteed here by the XP formula in §32.5): `ANM_064` Level-up celebrate and a toast.
    - N8: "Level 2! From surviving a DINOSAUR. Put that on your résumé."
    - N9: "You got stat points. Spend them later in your Profile. I'm not your accountant." (Allocation is deferred, canon E14.)
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Block | hold F (toggle option shown) | hold LT | hold **Block** |
| Dodge Roll | C (+ WASD for direction) | RB (+ left stick) | **Dodge** (stick sets direction) |
| Swipe Combo | LMB ×3 | RT ×3 | **Attack** ×3 |
| Calm Down! | R | Y | **Calm** |

- **Highlights:** each combat button pulses only when it's needed. A threat arrow points at her during wind-ups.
  Calm Down! auto-targets the Demon (10 studs).
- **Animations:** customer `ANM_048` (soda throw), `ANM_052`, `ANM_053`, `ANM_055`. Player: the ability animations
  of `ABL_001`, `ABL_003`, `ABL_004` and `ABL_006` (§36.14 per the canon C21 mapping), plus `ANM_064`.
- **Rewards:** 75 MB, XP = max(50, 210 − current XP), emote "Phew!" (a wipes-brow emote).
- **Failure & auto-recovery:**
  - The player cannot be KO'd (Plot Armor).
  - Running away → she follows at walk speed 10, and N: "You can't outrun a dinosaur. Well, you can. But don't."
  - 20 s idle in combat → the needed prompt re-pulses with an N line.
  - Using Calm Down! on the Karenosaurus during (a)–(c): "She's past talking. That's level five. Calm Down! works on grumblers, not brawlers." No cooldown is consumed in the tutorial.
- **Analytics:** step 7. Custom field 03 = blocks missed (0, 1–2, 3+).

#### 32.6.8 Step 8: `QST_TUT_008` Fix It Up

- **Trigger:** the Karenosaurus exits the door.
- **Objective:** (a) repair the Broken table back to Pristine; (b) mop the pickle and soda puddle.
- **Timing:** 9:00–9:50.
- **Setup:** restaurant-condition widget revealed (§24). The table shows "BROKEN – seats unusable" (canon C6) with a
  cartoon crack overlay. The repair interaction uses the §15 repair minigame. In the tutorial it has 3 hammer
  points, each with a timing ring like chopping. A missed tap repairs at half speed, and it never fails. The first
  repair is free.
- **Dialogue:**
  - N1 [B]: "My poor table. Broken things seat nobody, and they scare off customers."
  - N2: "Walk up and hold Interact. Your arms know what to do."
  - N3 (during): "Tap when the nail glows. Tap. Tap. Like you mean it."
  - On completion: "Good as new! Better, honestly. Don't tell the table."
  - N4 [B]: "First repair's on me. After this, you pay. Fixing is WAY cheaper than replacing. Remember that."
  - N5: "And mop that pickle juice. It's ruining the vibe. Clean floors make happy customers."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Start repair | hold E "Repair" | hold X | hold **REPAIR** |
| Hammer point | E on glow | X on glow | tap **REPAIR** on glow |
| Mop | hold E "Mop" | hold X | hold **MOP** |

- **Highlights:** the broken table, then the puddle decal. A durability bar animates from 20 % to 100 %, and the
  state labels change Broken → Cracked → Scuffed → Pristine, each with a matching icon.
- **Animations:** player `ANM_060` Hammer repair, `ANM_022` Mop / clean.
- **Rewards:** 50 MB, 40 XP.
- **Failure & auto-recovery:** walking away mid-repair keeps the progress (the job persists, as in canon E3). Missed
  taps only slow it down. The puddle can't be missed because the mop prompt appears within 7 studs.
- **Analytics:** step 8.

#### 32.6.9 Step 9: `QST_TUT_009` Cash In

- **Trigger:** both step-8 objectives are done.
- **Objective:** (a) interact with the cash register on the counter to print the **Shift Receipt**; (b) claim
  Nana's Inheritance Envelope.
- **Timing:** 9:50–10:20.
- **Setup:** the receipt is a diegetic paper UI that unrolls from the register. It shows the day's real values
  *(example)*:
  - Customers 3 · Sales 25 MB · Tips 7 MB · Apology Payments 4 MB · Ingredients −11 MB.
  - Net kept: 25 MB.
  - Footer: "1 table flipped (repaired) · 1 soda incident".
- **Dialogue:**
  - N1: "Let's count the money. My favorite part. Walk to the register."
  - N2 [B] (receipt prints, `ANM_066` Cash register cha-ching): "Payments go straight into your wallet, up top. Ingredients come out when you serve, so this is what you actually KEPT."
  - N3 [B]: "Three customers. One apology. One soda incident. Not bad for a first day."
  - N4 [B] (an envelope pops out of the till): "And this is from me. My inheritance. It was going to be bigger, but… cruise buffet."
  - N5 [B]: "Now. Want to know what Morph Bucks are REALLY for? Not furniture. Not rent. YOU."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Use register | E "Cash Up" | X | **CASH UP** |
| Claim envelope | E / click **CLAIM** | A on **CLAIM** | tap **CLAIM** |

- **Highlights:** the register, then the MB counter (a coach-mark line from the envelope to the counter as it
  counts up).
- **Animations:** player `ANM_066` Cash register cha-ching.
- **Rewards:** 150 MB (the envelope), 20 XP.
- **Failure & auto-recovery:** if the player ignores the register for 20 s, it rings by itself (a bell bark) and
  L2 guidance starts.
- **Analytics:** step 9.

#### 32.6.10 Step 10: `QST_TUT_010` Your First Mutation

- **Trigger:** N5 of step 9 ends.
- **Objective:** (a) travel to the Mutation Mart (`BLD_01`) in Mutation Market (`DST_02`); (b) choose one starter
  part in the Starter Pod ceremony; (c) equip it from the Morph menu; (d) *(optional, 15 s)* try its ability on the
  Complaint Dummy. Leaving the Mart unlocks Downtown (`DST_03`, canon C16.1).
- **Timing:** 10:20–12:20.
- **Setup:**
  - The shack sign flips to "Back in 5 Minutes!" (no chef yet, §4.3.2), and the tutorial lock lifts.
  - A footprint Beam runs from the door along Restaurant Row (`DST_01`) to the Mart. The target walk is ≤ 45 s
    (district distances in §18). A free Pigeon Taxi is offered per §32.3.
  - At the Mart, Mutty McMutface (`NPC_004`) waits beside the **Starter Pod**: three glass tubes in the floor, and a
    "Complaint Dummy" (a punching bag shaped like a grumpy customer) next to the counter.
- **Dialogue (travel):**
  - N1: "To the Mutation Mart! Follow the footprints. I'll flip the sign."
  - Taxi offer (if slow): "Lost? Take a Pigeon Taxi. Tutorial fare: FREE. I'm paying. Grudgingly."
- **The Starter Pod ceremony.**
  1. Mutty: "WELCOME to Mutation Mart, where you're one purchase away from being someone else! Nana called ahead. You get a freebie."
  2. N2 [B] (on the Mart's price board): "Every menu board in town is my menu board now. Pick one. Choose wisely. Or funnily."
  3. The three tubes rise with a drumroll. Each holds a slowly rotating part above a card (rarity is always
     color *and* shape, canon C13.3; stats from §36.3):

| Choice | Part | Rarity | Playstyle | Active ability | Card callout |
|---|---|---|---|---|---|
| A | `MUT_145` Octopus Arm | Uncommon ▲ (green) | **Chef** | `ABL_012` Octo-Flurry | "+1 carry: hold two things at once!" (canon C3) |
| B | `MUT_144` Crab Claw Arm | Uncommon ▲ (green) | **Fighter** | `ABL_017` Claw Grab & Toss | "Grab it. Toss it. Problem solved." |
| C | `MUT_153` Wrench Claw Arm | Rare ■ (blue) | **Repair** | `ABL_062` Repair Burst | "Fix things in a burst of bolts." |

  4. **Try On:** each card has a Try On button. A `ViewportFrame` shows the player's current morph wearing that part
     and doing `ANM_065` Mutation equip flex. The player can try all three, as often as they like.
  5. **Choose →** confirm modal. N: "This one? The other two are sold right here later, so no take-backsies on the freebie." [Choose] [Look again]
  6. **Reveal:** the chosen tube pops open with confetti and a rising chord. The part flies to the player and *clicks* on at the right arm
     (canon C13.1; ARM parts can be moved to the left arm later). The player does `ANM_065`, and the camera orbits for
     3 s (static with Reduced Motion). Banner: "NEW MUTATION! OCTOPUS ARM ▲ UNCOMMON". Other players nearby see
     the confetti too.
  7. Mutty: "Ooh, it SUITS you. Everything suits everybody here. That's the beauty of Morph City."
  8. Nana, depending on the choice:
     - Octopus: "Eight arms! Well. One arm with eight bits. You can carry two things now. FINALLY."
     - Crab: "Pinchy! Good for grabbing things. And grumpy dinosaurs."
     - Wrench: "A wrench for a hand. My table would like a word. A thank-you word."
- **Equip lesson:** the ability bar, Morph menu entry and MS counter appear (§24). N3: "Open your Morph menu.
  That's where you'll spend… most of your life." The menu opens on the Arms group with the new part. Equipping is
  instant out of combat (canon E4). The part is already worn from the reveal, so this beat teaches *where* parts
  live and how to switch sides or unequip. It is complete when the menu has been opened and closed with the part
  equipped.
- **Try it:** "Press 1 and try it on the dummy. It's had worse." The ability fires on the Complaint Dummy (it wobbles
  and goes "Hmph!").
- **Downtown unlock:** when the player walks out of the Mart, the arch between Mutation Market and Downtown lifts
  with a brass fanfare: "DOWNTOWN MORPH CITY IS NOW OPEN!" A map pin is added.
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Choose card | click card / 1–3 | D-pad / left stick + A | tap card |
| Try On | click **Try On** | X | tap **Try On** |
| Open Morph menu | N | radial (Select) | **≡** → Morph |
| Ability 1 | 1 | D-pad Up | ability arc slot 1 (tap = auto-target) |

- **Animations:** player `ANM_002`, `ANM_003`, `ANM_065`; Mutty idle loop from §36.14.
- **Rewards:** the chosen part (granted at the choice, acquisition `QUEST`, equip-level requirement waived per canon
  C13.8), 50 MB, 40 XP, 10 MS (the MS counter appears).
- **Failure & auto-recovery:**
  - Closing the choice modal leaves the Pod waiting; the tracker offers "Choose your mutation" (opens the modal from
    anywhere).
  - The step cannot complete without a choice.
  - Disconnecting after choosing keeps the part (it was granted at the choice); resume starts at the equip lesson.
  - Wandering off the trail triggers L2/L3 guidance and then the taxi offer.
- **Analytics:** step 10. Custom field 03 = choice (`octopus` / `crab` / `wrench`). The choice split is a key §31
  dashboard; target: no option chosen by < 15 % of players [TUNABLE].

#### 32.6.11 Step 11: `QST_TUT_011` Fancy Upgrades

- **Trigger:** the Downtown fanfare ends.
- **Objective:** (a) use the Return Door button to go home (free, 10 s cooldown, canon C16.1); (b) open the Restaurant
  Hub → Upgrades; (c) buy a restaurant upgrade (the circled one is recommended; any upgrade counts); (d) watch it get
  installed.
- **Timing:** 12:20–13:20.
- **The tutorial upgrade (selection rule, data-driven):** the cheapest §36.12 restaurant upgrade that requires
  TIER_01 and is flagged tutorial-eligible. It must cost 150–250 MB and have an immediate visible effect,
  preferably on Atmosphere (which feeds M and DecorMult, canon C11.3–C11.4). If no upgrade qualifies, use the
  cheapest TIER_01 decor item in §36.13 with Atmosphere > 0. **Affordability guard:** the wallet here is
  ≥ 500 MB + customer income by construction (§32.5). If a balance change ever leaves the player short, the quest
  grants the shortfall as "Nana's Loan Forgiveness" (server-side, logged).
- **Dialogue:**
  - N1: "Back home. Hit the Return Door button. Works anywhere in the city. Free! Unlike me."
  - N2 [B]: "Open the Restaurant Hub. Upgrades. This is where Morph Bucks become a better restaurant."
  - N3: "I circled one for you. It's cheap, and it makes the place less… shack-y."
  - Bolt Butterworth (`NPC_006`) zips in on forklift legs: "Delivery for the shack! Installed! Signed! Gone!" He
    installs it with one comically oversized wrench (`ANM_061` Weld / bolt repair).
  - N4 [B]: "Look at that. Atmosphere went up. Customers notice. Happier customers, bigger tips."
  - N5: "Tiers, stations, decor, it all adds up. Save 1,000 Morph Bucks and we can call this place a DINER."
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Return Door | HUD 🏠 button or quick radial (Q) | radial (Select) → Return | 🏠 button |
| Restaurant Hub | H | radial → Hub | **≡** → Hub |
| Buy | click **Buy** | A on **Buy** | tap **Buy** |

- **Highlights:** the Return button, then the Hub entry, the Upgrades tab and the circled card ("Recommended" ribbon,
  never color-only). The before/after Atmosphere value is shown on the card.
- **Animations:** Bolt `ANM_002`, `ANM_061`.
- **Rewards:** 50 MB, 30 XP.
- **Failure & auto-recovery:** closing the Hub re-highlights the entry after 5 s. Buying a different upgrade
  completes the step. Return Door on cooldown shows the remaining seconds.
- **Analytics:** step 11. Custom field 03 = recommended (yes/no).

#### 32.6.12 Step 12: `QST_TUT_012` Hire Help

- **Trigger:** 2 s after the install finishes.
- **Objective:** (a) open the Employee panel; (b) hire Ollie (`EMP_001`) for 0 MB; (c) assign him as Chef to the
  Grill; (d) watch him cook one order; (e) read the Offline Income Preview card.
- **Timing:** 13:20–14:40, then graduation until 15:00.
- **Setup:**
  - Doorbell. Ollie the Octopus Intern waits at the door holding a soggy résumé.
  - Ms. Hirewell (`NPC_007`) appears split-screen on Nana's board: "Recruitment Office, Downtown. I sent you a candidate. He's… enthusiastic."
  - The Employees entry and the offline preview chip are revealed (§24).
  - A walk-in customer (patience ×2) arrives once Ollie is assigned and orders 2 × `RCP_BRG_001`.
- **Dialogue:**
  - Ollie: "Hi! I'm Ollie! I have eight arms and one brain cell! The brain cell is VERY excited!"
  - Ollie: "I cook two things at once! Sometimes I put a pickle on stuff. I don't know why. Nobody knows why."
  - N1 [B]: "An octopus intern. Wage: 12 Morph Bucks an hour. Cheaper than me, and I'm a hologram."
  - N2: "Hire him, then put him on the grill. Chefs need a station."
  - Demo (Ollie grills two patties at once; the scripted trait gag adds a pickle): walk-in "Ooh, bonus pickle!"; N: "See? Two at once. One brain cell. Zero explanations."
  - N3 [B] (preview card opens): "Here's the best part. When you log off, Ollie keeps cooking."
  - N4: "Two hours without a Manager. Hire a Manager later and he'll work longer. Come back and collect. Money while you nap!"
- **Hire card (canon C14.4):** `ROLE_CHEF` · Common ● · hire cost **0 MB** (tutorial gift) · wage 12 MB/h · Cooking 30 ·
  Service 15 · Accuracy 28 · Reliability 40 · trait **"Eight Arms, One Brain Cell"** (cooks 2 items at once; 5 %
  chance to put a pickle on everything).
- **Prompts:**

| Beat | KB/M | Controller | Touch |
|---|---|---|---|
| Employees | P | radial → Employees | **≡** → Employees |
| Hire | click **Hire (0 MB)** | A | tap **Hire** |
| Assign station | click Role ▸ Chef, Station ▸ Grill | A / D-pad | tap Role, tap Station |
| Close preview | click **Got it!** | A | tap **Got it!** |

- **Animations:** Ollie `ANM_002` Walk, `ANM_011` Grill flip, `ANM_017` Assemble stack; customer `ANM_043`, `ANM_044`.

**The Offline Income Preview card.** The card is rendered from `OfflineEarningsService:PreviewAsync(player)`, which
is the *same* pure function §17 uses for real reports, run with the live state, the cap, and incidents as an
expected range. The main view shows the big number: **"≈ 350 MB if you're away 2 h"**. It also shows a range
(≈ 290–440 MB), "Max 2 h without a Manager → hire a Manager for 4 h", and the tip "More ★ and more decor = more
customers". A **Show the math** expander shows the canon C15 computation. The reference fixture below is also
acceptance test AC-32-09.

*Fixture inputs:* TIER_01 (seats 4, BaseDemand 50/h, canon C6). Stars 2.50 and Atmosphere 20 *(live values in game)*.
Ollie with canon stats, Morale 80 % and Energy 100 % at hire *(starting morale per §16)*. Player EFFICIENCY 0. Menu =
the four L1 recipes priced 9 / 10 / 6 / 6 MB (§4.1.3) with order weights 0.357 / 0.357 / 0.143 / 0.143. Base prep
times 35 / 40 / 25 / 8 s and per-customer ingredient cost 3.80 MB are *(§6 values; fixture only)*. No Manager, so the
cap is 2 h (canon C14.3).

| # | Quantity | Computation | Value |
|---|---|---|---|
| 1 | RepMult | 0.5 + 0.25 × 2.50 | 1.125 |
| 2 | DecorMult | 0.9 + 0.003 × 20 | 0.96 |
| 3 | `Demand_off` | 50 × 1.125 × 0.96 × 0.6 | **32.4 customers/h** |
| 4 | `Cap_seat` | 4 × 3600 / 300 | 48.0 /h |
| 5 | `PrepSec_avg` | 0.357·35 + 0.357·40 + 0.143·25 + 0.143·8 | 31.5 s |
| 6 | Ollie's efficiency | (29 / 100) × (0.6 + 0.4 × 0.80) × (0.7 + 0.3 × 1.00) × (1 + 0.001 × 0); chef RoleStatAvg = mean(Cooking 30, Accuracy 28) = 29, expressed as a 0–1 fraction | 0.2668 |
| 7 | `Cap_kitchen` | (3600 / 31.5) × 0.2668 / 1.4 × 2 (trait: 2 parallel items) × (1 + 0.15 × 0) × 1 | 43.6 /h |
| 8 | `Cap_service` | tier ≤ 2 → `Cap_kitchen` | 43.6 /h |
| 9 | Q | min(32.4, 48.0, 43.6, 43.6) | **32.4 /h (demand-bound)** |
| 10 | AvgTicket · quality q | 1.4 × 8.50 = 11.90 MB · min(0.95, 0.70 + 0.25 × 0.28) = 0.77 | — |
| 11 | Revenue / h | 32.4 × 11.90 × 0.77 | 296.9 MB |
| 12 | Tips / h | 296.9 × (0.04 + 0.04 × 15 / 100) × (1 + 0); Ollie's Service stands in for waiter service at counter tiers | 13.7 MB |
| 13 | Ingredients / h · wages / h | 32.4 × 3.80 · 12 × 1 | 123.1 · 12.0 MB |
| 14 | Net, hour 1 | 296.9 + 13.7 − 123.1 − 12.0 | 175.4 MB |
| 15 | Net, hour 2 | Energy 92 % → efficiency 0.2604 → `Cap_kitchen` 42.5 /h, still above demand → same Q | 175.4 MB |
| 16 | **2 h total (before incidents)** | 65 customers · revenue 594 · tips 27 · ingredients −246 · wages −24 | **≈ 351 MB** |
| 17 | Incidents | count = floor(2 × 0.6 × 1) = 1 + seeded roll; bounded −10 % / +15 % of (revenue + tips) = −62 / +93 MB | range ≈ 290–440 MB |
| 18 | Discoveries | 8 %/h chance of 1–3 MS → expected ≈ 0.3 MS | "maybe a few Shards!" |

**Robustness note.** Hour 1 stays demand-bound for any trait multiplier ≥ 1.5. With no trait at all (×1.0) the card
would show ≈ 225 MB. §36.8 is authoritative for how the trait applies offline, and the card simply displays what
§17's function returns. For comparison, an hour of active play at TIER_01 nets ≈ 630 MB (canon C4.4). Ollie alone
earns ≈ 28 % of that per hour, which sits *below* the 35–50 % band for a well-staffed restaurant and leaves visible
room to grow ("Hire more staff and a Manager to earn more while you're away!").

- **Rewards:** 50 MB, 40 XP, `EMP_001` (hired and assigned), 1 Morph Capsule (earnable capsule, canon C4.7 odds;
  opened from the inventory any time), title "Restaurant Owner (Probably)".
- **Graduation (14:40–15:00):** N [B]: "Well. You took an order, cooked a burger, survived a dinosaur, fixed a table,
  grew a new arm and hired an octopus. I've never been prouder. Of anyone. Don't let it go to your head. Your new
  head. Whatever head you've got." Confetti. The objective chip changes to **"Save 1,000 MB for Tiny Mutation
  Diner"**, story chapter 1 begins (§20), daily quests unlock, and the full HUD is now visible.
- **Failure & auto-recovery:** "Not now" on the hire card → Ollie waits at the door indefinitely; the Employees entry
  pulses and N reminds every 60 s ("He's still there. Dripping."). The step and graduation stay pending. Assigning
  Ollie to a non-grill station is allowed if it's a cooking station. The demo order then uses that station's
  recipe, falling back to `STN_GRILL` via auto-reassign with a line.
- **Analytics:** step 12 (= tutorial complete). `LogCustomEvent "mmr_tutorial_complete"` with total duration
  (seconds) as the value.

### 32.7 UI

All tutorial UI lives in `UIController`'s overlay layer (§24.5). It is input-adaptive and respects safe areas.

| Element | Description | Behavior |
|---|---|---|
| Tutorial tracker | Top-left chip: "Step 5/12 · Happy Customer, Happy Wallet", with sub-objective checkboxes; a secondary **Skip tutorial ▸** link appears after step 3 | Collapses to a single line while In Combat; never covers the ticket card (R-READ-1) |
| Dialogue panel | Bottom subtitle bar: Nana portrait (hologram-tinted), speaker name, ≤ 2 lines, ▸ advance glyph, ↺ replay-line icon | Tap, click or A advances; blocking lines dim the world 20 % (none with Reduced Motion) |
| Board bubble | A speech bubble on the menu board Nana is speaking from | Mirrors the subtitle text so it is readable at a distance |
| Coach marks | `UIStroke` pulse (1 Hz) plus an arrow on a HUD widget; world targets use a `Highlight` | Static outline with Reduced Motion |
| Footprint trail | `Beam` between the player's attachment and the target, scrolling footprint texture | `TextureSpeed = 0` with Reduced Motion; hidden when within 6 studs of the target |
| Screen-edge arrow | Points to an off-screen target, with a distance label | Only one at a time |
| Reaction card (step 5) | Face icon, number, top 2 factors with ▲/▼ icons | Shown 3 s, then shrinks into the customer's bubble |
| Shift Receipt (step 9) | Diegetic paper receipt | Also opens as a 2D panel on phone for legibility |
| Starter Pod cards (step 10) | Three cards: rarity color + shape, role, ability, stats, Try On | Gamepad: D-pad cycles cards; touch: swipe between cards on phone |
| Offline Income Preview (step 12) | Big number, range, cap line, tip, **Show the math** expander | Expander text is selectable; numbers use thousands separators |

### 32.8 Player Interactions (multiplayer)

- **Steps 1–9 are solo.** The interior rejects visitors ("Under Renovation"). Friends can see the player's façade on
  Restaurant Row, and their join invites are queued with "Finish Nana's lessons first!" until step 12 completes or
  the tutorial is skipped.
- **Steps 10–12 are social.** The player walks through the shared city. Others see the Starter Pod confetti, and
  friends can follow them into the Mart.
- **Server moves.** If the player follows a friend to another server (TeleportService) mid-tutorial, they land at
  their plot in the new server and resume the current step (§32.14).
- **Chat** is Roblox's standard `TextChatService`. The tutorial adds no free-text input.

### 32.9 Accessibility

- **Reduced Motion** (seeded from `GuiService.ReducedMotionEnabled`, toggle in Settings) removes:
  - the step-1 fly-by and the step-10 camera orbit (both become cuts);
  - the pickle splat (it becomes a small HUD icon);
  - the light flicker (it becomes a soft dim);
  - pulsing coach marks (they become static outlines);
  - confetti (cut to 20 %).
- **No flashing faster than 3 Hz** anywhere in the tutorial (R-ACC-6).
- **Auto-Rhythm chopping** (canon C8: every tap counts as yellow, 0.8) is offered in the first-chop hint (in step 3
  if §6's recipe has a CHOP, otherwise TIP-01) and is always available in Settings → Accessibility.
- **Hold or toggle:** the step-7 Block prompt mentions the toggle option, and Sprint has the same option (§24.3.2).
- **Timing windows:** Tutorial Assist widens Perfect windows to 3.0 s, and no tutorial input requires a window
  shorter than 1.0 s. Missing a window is never a fail state.
- **Text and audio:** every line is subtitled and replayable from the Quest Journal (R-ACC-7). Nana's gibberish
  voice has its own *Voice barks* slider. Text size follows the §24 text-scale setting.
- **Color independence:** timing rings carry ✓ ticks in the good zone. Rarity is shown by shape as well as color.
  Anger shows level numerals.
- **Input parity:** the full tutorial can be completed with keyboard and mouse, controller only, or touch only
  (AC-32-11).

### 32.10 Skip Rules

1. **When:** the **Skip tutorial ▸** link appears in the tracker once `QST_TUT_003` is complete (the first burger is
   mandatory). It stays available until step 12.
2. **Confirmation modal:** "Skip Nana's lessons? You'll still get everything: the remaining Morph Bucks, XP, 10
   Mutation Shards, your free mutation (choose now!), Ollie the Octopus Intern, Downtown access and a graduation
   capsule." [Skip] [Keep learning]. Nana: "Fine. FINE. I'll be on my cruise. Call me never. (Call me.)"
3. **Server behavior:** pop all Tutorial Assist modifiers. Complete each remaining step in order, granting its
   rewards idempotently and logging its funnel step with custom field 01 = `skipped`. Then:
   - If no starter part has been chosen yet, open the **mandatory** choice modal. It has no close button, and the
     player can still Try On. "Pick one! You can buy the others later."
   - Unlock `DST_03`.
   - Hire `EMP_001` and assign him as `ROLE_CHEF` on `STN_GRILL`.
   - Show the **short Offline Income Preview card** (big number plus cap line), so skippers also see offline income.
   - Set the next objective "Save 1,000 MB for Tiny Mutation Diner".
4. **Not auto-performed:** the step-11 *purchase* (players keep the MB; the Upgrades entry gets a contextual tip
   later) and the scripted Karenosaurus fight (combat basics come from TIP-12 at the player's first anger ≥ 3
   customer).
5. **Scripted customers** present at skip time are served automatically, pay normally and leave. Held items are
   discarded at no charge.
6. Skipping is final, but every line stays replayable in the Quest Journal. Target skip rate ≤ 15 % of players
   offered the skip (§1.7).

### 32.11 Dependencies

§5 (stations, timers, the assist modifier hooks), §6 (Basic Burger, Cheeseburger and Fizzy Soda recipes and
prices), §8–§10 (scripted spawn API, satisfaction, anger levels), §11 (base kit, Huff Points, In-Combat flag), §12–§13
(starter parts, Morph menu), §14 (per-serve XP, level-up toast), §15 (repair minigame, tutorial-eligible upgrade flag,
Atmosphere), §16–§17 (hire flow, `PreviewAsync`), §18 (Mart route, Downtown arch, Pigeon Taxi), §19 (`NPC_001`,
`NPC_004`, `NPC_006`, `NPC_007`), §20 (`QST_TUT_` quest rows and rewards), §24 (progressive HUD, bindings, overlays),
§26 (Nana's voice, SFX, music stingers), §27 (remotes), §28 (tutorial state schema), §31 (funnel dashboards).

### 32.12 Progression after the Tutorial: Contextual Tips

One-time tips fire the first time a situation occurs. Each is a short Nana bark plus a coach mark, persisted per
profile as a bitmask and skippable with one tap.

| Tip | Trigger | Content |
|---|---|---|
| TIP-01 | First use of `STN_CUT` | Chop ring (green = clean cut, yellow, miss; over-chopping makes MUSHY) and an **Auto-Rhythm** toggle button right in the hint |
| TIP-02 | First ON_FIRE station | "FIRE! Extinguisher! Hold Interact!" (`ANM_030` Extinguish fire) |
| TIP-03 | First visit after reaching TIER_03 | Table service: waiters, seating, plating now matters (×0.9 if un-plated, canon C8) |
| TIP-04 | First login with a pending offline report | The Welcome Back screen: Collect, Employee Report, Restaurant Damage, Upgrade Suggestions (§17) |
| TIP-05 | First player KO | "Seeing Stars! You lose nothing. Ever. Walk it off." (canon C12.1) |
| TIP-06 | First capsule open | Disclosed odds and the 40-capsule pity counter (canon C4.7) |
| TIP-07 | First time opening Stats after a level-up | Stat allocation: Cooking, Strength, Repair, Luck "+" buttons, "More Stats" (canon C5) |
| TIP-08 | First SOLD OUT | Special ingredients are stocked; buy crates at Restaurant Supplies (canon C9) |
| TIP-09 | First city event toast | Events, map pings, rewards; Return Door to get home |
| TIP-10 | Second part owned in any slot group | Saved loadouts (Chef, Fighter, Repair) and the in-combat swap rules (canon E4) |
| TIP-11 | First order with a modification | Reading modification icons on the ticket (§6.18) |
| TIP-12 | First customer at anger ≥ 3 (skippers only) | Block / Dodge / Swipe / Calm Down! quick card |
| TIP-13 | First storm-out | Pay 0, a small reputation hit; how Calm Down! and Peace Offerings prevent it |
| TIP-14 | First Manager hired | The offline cap rises to 4 h; the Closing Checklist (§4.5.1) |
| TIP-15 | First Upgrades visit after skipping | The "Affordable now" badge and Atmosphere |

### 32.13 Roblox Implementation

**Architecture.**
- Server: `TutorialDirector` is a module owned by `QuestService`. Client: `TutorialController` is owned by
  `UIController`.
- The server decides; the client presents. Objectives subscribe to domain signals:
  - `OrderService`: ticket opened, dish served.
  - `CookingService`: item graded, dish completed.
  - `CustomerAIService`: satisfaction resolved, anger level changed.
  - `CombatService`: ability used, hit landed, Huff Points zero.
  - `RepairService`: repair completed. `MutationService`: part equipped. `BuildingService`: upgrade purchased.
  - `EmployeeService`: hired, assigned.
- Scripted customers use CustomerAIService's scripted-spawn API with fixed looks and orders. Tutorial Assist values
  are pushed as modifiers keyed by the restaurant instance.
- Remotes (`<Domain>.<Action>`, final names in §27):
  - `Tutorial.StepChanged` (server → client)
  - `Tutorial.RequestSkip` (client → server)
  - `Tutorial.ChooseMutation` (client → server; validated against the three canon choices)
  - `Tutorial.ForceChoice` (server → client)
  - `Tutorial.DialogueAck` (client → server; only releases blocking-line pauses, rate-limited)

**Persistence (in the profile; schema in §28).**

```lua
--!strict
export type TutorialState = {
	v: number,                     -- tutorial script version (migrations map old steps to new)
	step: number,                  -- last COMPLETED step, 0..12
	skipped: boolean,
	choice: string?,               -- "MUT_145" | "MUT_144" | "MUT_153" once chosen
	startedAt: number,             -- os.time() on the server
	completedAt: number?,
	tipsSeen: number,              -- bitmask for TIP-01..TIP-15
	assists: { [string]: number }, -- analytics counters (burn_recovery, auto_flip, taxi, ...)
}
```

**Step completion, rewards and funnel logging (excerpt).** API names other than Roblox's are illustrative; §27
fixes the service interfaces.

```lua
--!strict
-- ServerScriptService/Services/QuestService/TutorialDirector.lua (excerpt)
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
-- Injected by the §27 service loader during Init (loader omitted from this excerpt):
local PlayerDataService: any, QuestService: any, MutationService: any, EmployeeService: any

local LAST_STEP, SKIP_MIN_STEP = 12, 3
local STARTER_CHOICES = { MUT_145 = "octopus", MUT_144 = "crab", MUT_153 = "wrench" }
local CF = Enum.AnalyticsCustomFieldKeys

local TutorialDirector = {}

local function questId(step: number): string
	return string.format("QST_TUT_%03d", step)
end

local function logFunnel(player: Player, step: number, mode: string, extra: string?)
	AnalyticsService:LogOnboardingFunnelStepEvent(player, step, string.format("mmr_tutorial_step_%02d", step), {
		[CF.CustomField01.Name] = mode,                                  -- "played" | "skipped"
		[CF.CustomField02.Name] = player:GetAttribute("InputMode") or "unknown", -- analytics only
		[CF.CustomField03.Name] = extra or "",
	})
end

function TutorialDirector.completeStep(player: Player, step: number, mode: string, extra: string?): boolean
	local profile = PlayerDataService:GetProfile(player)
	if not profile or profile.SafeMode then
		return false -- canon E6: no progress or rewards in Safe Mode
	end
	local t = profile.Data.tutorial
	if step ~= t.step + 1 or step > LAST_STEP then
		return false -- strictly sequential; replays and duplicates are no-ops
	end
	-- Idempotent by quest ID: EconomyService:Transact uses questId(step) as the idempotency key.
	if not QuestService:GrantRewardsOnce(player, questId(step)) then
		return false -- step stays incomplete and is retried; nothing is half-granted
	end
	t.step = step
	if step == LAST_STEP then
		t.completedAt = os.time()
		TutorialDirector.popAssists(player)
	end
	logFunnel(player, step, mode, extra)
	Remotes.Tutorial.StepChanged:FireClient(player, step, mode)
	return true
end

Remotes.Tutorial.ChooseMutation.OnServerEvent:Connect(function(player: Player, partId: unknown)
	if typeof(partId) ~= "string" or STARTER_CHOICES[partId] == nil then
		return
	end
	local profile = PlayerDataService:GetProfile(player)
	if not profile then return end
	local t = profile.Data.tutorial
	if t.choice ~= nil or t.step < 9 then
		return -- exactly one free choice, only from step 10 (or during skip)
	end
	t.choice = partId
	MutationService:Grant(player, partId, { source = "QUEST", questId = questId(10), ignoreLevelReq = true })
	TutorialDirector.onChoice(player, STARTER_CHOICES[partId])
end)

function TutorialDirector.skip(player: Player)
	local profile = PlayerDataService:GetProfile(player)
	if not profile then return end
	local t = profile.Data.tutorial
	if t.step < SKIP_MIN_STEP or t.step >= LAST_STEP then return end
	t.skipped = true
	TutorialDirector.popAssists(player)
	TutorialDirector.serveAndDismissScriptedCustomers(player)
	for step = t.step + 1, LAST_STEP do
		if step == 10 and t.choice == nil then
			Remotes.Tutorial.ForceChoice:FireClient(player)
			if not TutorialDirector.waitForChoice(player, 300) then
				return -- resumes at step 10 next session; the modal reopens
			end
		end
		if step == 12 then
			EmployeeService:GrantTutorialHire(player, "EMP_001", "ROLE_CHEF", "STN_GRILL")
		end
		if not TutorialDirector.completeStep(player, step, "skipped") then
			return
		end
	end
end

return TutorialDirector
```

**Other implementation notes.**
- Highlights use `Highlight` (`DepthMode = AlwaysOnTop`, `FillTransparency = 1`, yellow outline). Roblox caps
  simultaneous Highlights, and the tutorial uses at most 2 at a time.
- Trails are `Beam`s between `Attachment`s on the HumanoidRootPart and the target.
- Glyphs come from `UserInputService:GetStringForKeyCode` / `GetImageForKeyCode`. The input mode is
  `UIController.InputMode` (§24).
- Dialogue strings live in the localization table under keys `tut.<step>.<speaker>.<n>` and are served through
  `LocalizationService`.
- Analytics: funnel steps 1–12 are logged once per player via `LogOnboardingFunnelStepEvent`. Sub-events
  (`mmr_tutorial_assist`, `mmr_tutorial_skip`, `mmr_tutorial_resume`, `mmr_tutorial_complete`) go through
  `LogCustomEvent` with custom field 01 carrying the sub-type. The schema and dashboards are in §31.
- Performance: scripted customers are SPCV proxies like any other customer (canon C3). The tutorial adds ≤ 3 active
  customers, 1 Pod model and 1 dummy, which is well within §30 budgets.

### 32.14 Edge Cases and Resume

**Resume rule.** On join, if `tutorial.step < 12`, start step `tutorial.step + 1` with that step's re-setup. Progress
inside an incomplete step is not persisted, *except* for permanent grants made mid-step (the step-10 part, the
step-12 hire), which are checked first. Every resume logs `mmr_tutorial_resume` with the step number.

| Situation | Behavior |
|---|---|
| Disconnect during steps 2–5 | Re-enter the interior; the scripted customer for that step respawns with a fresh ticket; held items are gone (no charge) |
| Disconnect during step 6 | The Karenosaurus re-enters and goes straight to ordering ("Where WERE you?") |
| Disconnect during step 7 | The Karenosaurus re-enters at anger 78: "I'M BAAACK." The table stays Broken because damage persists. The Polite Demon respawns seated for the splash beat |
| Disconnect during step 8 | The table is still Broken and the puddle is still there; repair starts from the persisted durability |
| Disconnect during step 10 after choosing | The part is already owned; resume at the equip lesson in front of the Mart (Return Door works) |
| Disconnect during step 12 after hiring | Ollie is already on the roster; resume at "assign to Grill" |
| Server shutdown (canon E13) | Same as a disconnect, in the new server |
| DataStore failure / Safe Mode (canon E6) | Tutorial paused with a friendly banner; no rewards granted; resumes next join |
| Player tries to leave the interior during steps 1–9 | The door shows a velvet rope; N: "Not yet! The city can wait. The burger cannot." |
| Visitor tries to enter during steps 1–9 | "Under Renovation" sign; entry rejected |
| Player attacks a customer before step 7 | Combat inputs are unbound until step 7 (the HUD isn't shown), so nothing happens |
| Patty put in the wrong station / bun trashed / 3 burns | Rejection line / free restock / Auto-Flip assist (§32.6.3) |
| Player idle 30 s / 90 s | Nudge line / pause with timers frozen. Roblox's own idle kick still applies; resume next join |
| Full-screen menu opened in step 7 | Blocked by In Combat (canon E2); overlays still work |
| Choice modal dismissed in step 10 | Re-openable from the tracker; the step can't complete without a choice |
| Profile already owns the chosen starter part (migrated or test profile) | Grant converts to MS per canon C4.7 duplicate rules, and the tracker suggests equipping the owned copy |
| Balance below the tutorial upgrade price | Shortfall granted as "Nana's Loan Forgiveness" (never expected; logged as an anomaly) |
| Player declines Ollie | Ollie waits at the door; step 12 stays pending; reminders every 60 s |
| Player levels up from per-serve XP before step 7 | Allowed; the step-7 formula then grants the 50 XP minimum; the level-up toast follows canon E14 |
| Tutorial script updated between sessions | `tutorial.v` migration maps old steps to new (§28); no step is replayed for rewards |
| Returning player on a new device | No tutorial (the profile flag is server-side) |

### 32.15 Acceptance Criteria

- **AC-32-01:** Median tutorial duration is 13–17 min and p90 ≤ 20 min across ≥ 30 first-time testers split across phone, PC and controller.
- **AC-32-02:** Tutorial completion (funnel step 12 ÷ step 1) is ≥ 80 % in soft launch [TUNABLE].
- **AC-32-03:** Every player who reaches step N has exactly one `LogOnboardingFunnelStepEvent` for each step 1..N with sequential step numbers and names `mmr_tutorial_step_01`…`_12`. Skipped steps carry custom field 01 = `skipped`.
- **AC-32-04:** After completion (played or skipped), the profile has received exactly 600 MB from `QST_TUT_` rewards, 10 MS, 1 Morph Capsule, exactly one of `MUT_145` / `MUT_144` / `MUT_153`, and `EMP_001` assigned as `ROLE_CHEF`. Re-firing any completion or choice event changes nothing (idempotency test).
- **AC-32-05:** In 1,000 simulated runs including the worst case (every patty burned, Karenosaurus unserved), the wallet at the start of `QST_TUT_011` is ≥ the tutorial upgrade price in 100 % of runs.
- **AC-32-06:** Fault injection that disconnects at 3 points inside each of the 12 steps always resumes at the first incomplete step with the documented re-setup, with 0 duplicate grants and 0 lost grants.
- **AC-32-07:** Level 2 is reached at the completion of `QST_TUT_007` in 100 % of runs where it had not been reached earlier.
- **AC-32-08:** The Karenosaurus set piece plays all four beats (`ANM_047`, `ANM_048`, `ANM_049` + `ANM_050`, then the fight), and the soda splash on the Polite Demon (anger 35) occurs in 100 % of runs, whether or not the player dodges.
- **AC-32-09:** With the §32.6.12 fixture inputs, `OfflineEarningsService:PreviewAsync` returns `Demand_off` 32.4 ± 0.1 /h, Q 32.4 /h, 2-hour net 351 ± 2 MB and a displayed range of 289–444 ± 2 MB.
- **AC-32-10:** The skip link is absent before `QST_TUT_003` completes. Skipping grants a reward ledger identical to playing (except the optional purchase). The skip-path choice modal cannot be dismissed without choosing.
- **AC-32-11:** The full tutorial can be completed using only keyboard and mouse, only an Xbox controller, only a PlayStation controller, or only touch. Prompts show the correct glyphs and update within 0.25 s of an input-mode change.
- **AC-32-12:** With Reduced Motion on, there is no fly-by, camera orbit, shake, full-screen splat or pulse faster than 1 Hz, and no effect anywhere in the tutorial flashes faster than 3 Hz.
- **AC-32-13:** No player can be KO'd during `QST_TUT_007`, and no scripted customer can storm out during steps 2–7.
- **AC-32-14:** During steps 1–9, 100 % of visitor entry attempts to the player's interior are rejected, and friend invites are queued.
- **AC-32-15:** The tutorial runs at ≥ 30 FPS p95 on the §30 reference low-end phone.
- **AC-32-16:** In observed playtests, ≥ 70 % of testers aged 8–11 laugh or smile during the Karenosaurus beat (observer checklist) [TUNABLE].
- **AC-32-17:** Within the first 10,000 players, each starter part is chosen by ≥ 15 % of players. If not, card copy and previews are revised [TUNABLE].

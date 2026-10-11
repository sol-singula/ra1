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
- **Analytics:** step 3. Assists logged as `LogCustomEvent(player, "mmr_tutorial_assist", 1, {CustomField01 = "burn_recovery" | "auto_flip" | "assembly_ghost"})`.

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


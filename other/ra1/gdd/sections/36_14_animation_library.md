### 36.14 Animation Library

This appendix is the **only place `ANM_` ids are defined**. Numbers 001–300 are the
general library; `ANM_301`–`ANM_370` are the ability animations, mapped 1:1 to `ABL_001`–`ABL_070` (same last two
digits, canon §C21). The 52 canon core ids keep their canon names verbatim. Playback rules (priorities, blending,
gait classes, LOD, employee cycles) are specified in §26; art rules in §25.

#### 36.14.1 Conventions

| Column | Meaning |
|---|---|
| Rig / users | **R15** = standard R15 joint set (players: Humanoid → Animator; SPCV visuals for customers, employees and NPCs: AnimationController → Animator). **Prop** = AnimationController on a prop rig. Users: **P** player · **C** customer · **E** employee · **N** named NPC · **X** client-only city crowd · **A** = P + C + E + N. |
| Loop? | **Yes** / **No** / **Seg** = looping middle section between the `LoopStart` and `LoopEnd` markers; the client wraps `TimePosition` while the state holds, then lets the exit play. |
| Duration (s) | Authored length of one cycle at speed 1.0, keyed at 30 fps. |
| Priority | `Enum.AnimationPriority` value; policy table in §26. **UB** = upper-body-only track (no keys below `UpperTorso`), so the current gait shows through. |
| Markers | Standard `KeyframeMarker` names: `Impact`, `Release`, `FootL`, `FootR`, `Sfx`, `Vfx`, `LoopStart`, `LoopEnd`. Markers drive cosmetic VFX and SFX only. They are never used for server hit validation. |

| Block | ID range | Rows |
|---|---|---|
| Core locomotion & carry | `ANM_001`–`ANM_009`, `ANM_067`–`ANM_077` | 20 |
| Cooking, service & cleaning | `ANM_010`–`ANM_035` | 26 |
| Customers & tantrums | `ANM_040`–`ANM_059`, `ANM_100`–`ANM_113` | 34 |
| Repair, KO & progression core | `ANM_060`–`ANM_066` | 7 |
| Combat, reactions & status | `ANM_140`–`ANM_161` | 22 |
| Repair, build & props | `ANM_180`–`ANM_187` | 8 |
| Celebrate, emote & system | `ANM_200`–`ANM_212` | 13 |
| Employee work cycles | `ANM_230`–`ANM_249` | 20 |
| City NPCs & crowd | `ANM_260`–`ANM_268` | 9 |
| City events | `ANM_280`–`ANM_285` | 6 |
| Ability animations | `ANM_301`–`ANM_370` | 70 |
| **Total** | | **235** |

Unlisted numbers in the 001–300 general range are reserved for future content and must not be referenced.

#### 36.14.2 Locomotion and carry

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_001` | Idle | Locomotion | R15 · A | Yes | 4.0 | Idle | Weight-shift breathing with a blink-synced head bob. Three `Vfx` markers trigger a family fidget (ear twitch, tail flick). | Animate core; all SPCV visuals |
| `ANM_002` | Walk | Locomotion | R15 · A | Yes | 1.0 | Movement | Bouncy blocky walk authored at 8 studs/s with ±35° arm swing. Speed-scaled from 0.5 to 12 studs/s. | Animate core; CustomerAIService; EmployeeService |
| `ANM_003` | Run | Locomotion | R15 · A | Yes | 0.7 | Movement | Forward-lean cartoon run authored at 16 studs/s with pumping arms. Plays above 12 studs/s up to the 21 cap. | Animate core; chase AI; `ANM_363` overlay |
| `ANM_004` | Jump | Locomotion | R15 · A | No | 0.45 | Movement | 0.08 s anticipation crouch, then a tuck with arms up. Wings and tails get a procedural flick. | Animate core |
| `ANM_005` | Fall/land | Locomotion | R15 · A | Seg | 0.6 | Movement | Freefall flail loop, then a squash-pose landing with 0.12 s recovery. Heavy morphs add a dust ring. | Animate core; `ANM_322` exit |
| `ANM_006` | Carry item (upper body) | Carry | R15 · P, E | Yes | 2.0 | Action (UB) | Item held at chest height and welded to the `MMR_HandR` grip. Legs keep the current gait. | CookingService carry; `ABL_061` |
| `ANM_007` | Carry tray | Carry | R15 · P, E | Yes | 2.0 | Action (UB) | One palm under the tray at shoulder height while the free hand steadies it. Tray wobble is procedural, driven by speed. | Serving; ROLE_WAITER; `ANM_308` |
| `ANM_008` | Wobbly gait (mismatched legs) | Locomotion | R15 · A | Yes | 1.1 | Movement | Replaces walk and run when LEG_L ≠ LEG_R: ±12° hip roll, the short leg tiptoes. No speed change. | MorphAssemblyService flag; §26 |
| `ANM_009` | Strafe / backpedal | Locomotion | R15 · P, C | Yes | 0.9 | Movement | Side-step and back-step while facing a lock target. Used while In Combat. | CombatService lock-on; THROWER spacing |
| `ANM_067` | Gait – Heavy stomp | Locomotion | R15 · A | Yes | 1.3 | Movement | Wide stance, shoulders roll, `FootL`/`FootR` thuds with a light camera nudge. Speed-scaled for walk and run. | Gait class Heavy (bear, elephant, tree); TANK |
| `ANM_068` | Gait – Hop | Locomotion | R15 · A | Yes | 0.8 | Movement | Two-footed spring hops with knees tucked. Hop height scales with LegLength. | Gait class Hop (frog, fish, kangaroo, grasshopper, pogo) |
| `ANM_069` | Gait – Skitter | Locomotion | R15 · A | Yes | 0.5 | Movement | Fast low scuttle with a torso bob. The extra leg meshes cycle procedurally. | Gait class Skitter (spider) |
| `ANM_070` | Gait – Glide | Locomotion | R15 · A | Yes | 1.2 | Movement | Smooth sway-glide with no foot plants. Tentacle and cloud legs ripple procedurally. | Gait class Glide (octopus, cloud) |
| `ANM_071` | Gait – Roll | Locomotion | R15 · A | Yes | 1.0 | Movement | Upright lean with arms out for balance. Wheels or skates spin by speed. | Gait class Roll (wheel; skate/ice FEET) |
| `ANM_072` | Gait – Strut | Locomotion | R15 · A | Yes | 0.9 | Movement | High-knee bird or hoof strut with a forward head bob. | Gait class Strut (chicken, ostrich, raptor, goat, phoenix) |
| `ANM_073` | Hover idle | Locomotion | R15 · P, C | Yes | 0.6 | Idle | Airborne idle with dangling legs. Wing, rotor or jetpack motion is procedural. | `ABL_022`, `ABL_069`; flying-tag WINGS |
| `ANM_074` | Slip on spill | Reaction | R15 · A | No | 1.2 | Action3 | Banana-peel windmill, a bump on the bottom, then a quick hop up. Purely comic. | SPILLED floors; STS_GREASY |
| `ANM_075` | Multi-carry juggle | Carry | R15 · P, E | Yes | 1.6 | Action (UB) | 2–3 items juggled in a stack with extra limbs. Plays when carry count ≥ 2 (canon max 3). | Octopus Arm, Monkey Tail, `ABL_061` |
| `ANM_076` | Carry crate (two-hand) | Carry | R15 · P, E | Yes | 1.4 | Action (UB) | Arms around a crate held at belly height, with a slight back arch. | STN_DELIVERY; ROLE_STOCKER |
| `ANM_077` | Door squeeze | Locomotion | R15 · A | No | 0.9 | Action | Big morphs turn sideways and pop through the doorway with a cork "fwump". | Restaurant door entry; RestaurantService |

#### 36.14.3 Cooking, service and cleaning

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_010` | Chop | Cooking | R15 · P, E | Yes | 0.5 | Action | One knife stroke per tap. The `Impact` marker pops the timing-ring visual. Default is 4 taps. | STN_CUT; `ANM_231` |
| `ANM_011` | Grill flip | Cooking | R15 · P, E | No | 0.6 | Action | Spatula slides under the patty, then a flip with a 360° prop spin and an elbow pop. | STN_GRILL |
| `ANM_012` | Fryer dunk | Cooking | R15 · P, E | No | 0.7 | Action | Basket lowered with a wince lean-back. `Vfx` marker spawns bubble bursts. | STN_FRYER |
| `ANM_013` | Oven load | Cooking | R15 · P, E | No | 0.9 | Action | Hip-bump the door open, slide the tray in, heel-kick it shut. Reversed playback = unload. | STN_OVEN |
| `ANM_014` | Stir pot | Cooking | R15 · P, E | Yes | 1.2 | Action | Big two-handed ladle circles with the torso following. Steam puffs on `Vfx`. | STN_SOUP_POT; STN_STOVE |
| `ANM_015` | Blend (hold lid) | Cooking | R15 · P, E | Yes | 0.4 | Action | Both hands clamp the lid and the whole body vibrates. Speed rises 1.0→1.4 with progress. | STN_BLENDER |
| `ANM_016` | Mix bowl | Cooking | R15 · P, E | Yes | 0.8 | Action | Bowl under one arm, frantic whisking. Hand-mixing at STN_PREP plays at speed 0.67. | STN_MIXER; STN_PREP |
| `ANM_017` | Assemble stack | Cooking | R15 · P, E | No | 0.5 | Action | Reach, place one layer, pat, tongue-out concentration. Repeats once per layer. | STN_ASSEMBLY |
| `ANM_018` | Plate & garnish | Cooking | R15 · P, E | No | 1.0 | Action | Food slid onto the plate, garnish pinch-sprinkled from height, admiring head tilt. | STN_PLATING; STN_ASSEMBLY (T1–T2) |
| `ANM_019` | Serve (hand-off) | Service | R15 · P, E | No | 0.8 | Action | Two-hand presentation bow. The customer mirrors with a grab on `Release`. | OrderService serve; STN_WINDOW |
| `ANM_020` | Pour drink | Cooking | R15 · P, E | Yes | 0.6 | Action | Cup under the nozzle, other hand on the lever, eyes squinting at the fill line. | STN_DRINK |
| `ANM_021` | Wash dishes | Cleaning | R15 · P, E | Yes | 1.0 | Action | Scrub-scrub-rinse at sink height. Suds on `Vfx`, and the plate-stack prop increments. | STN_DISHWASH |
| `ANM_022` | Mop / clean | Cleaning | R15 · P, E | Yes | 1.2 | Action | Figure-eight mop sweep with a hip sway. Mop prop held on `MMR_HandR`. | Spill cleanup; ROLE_CLEANER |
| `ANM_023` | Trash toss | Cleaning | R15 · P, E | No | 0.6 | Action | No-look over-the-shoulder toss. The script decides hit or miss, not the animation. | STN_TRASH |
| `ANM_024` | Sauté pan toss | Cooking | R15 · P, E | Yes | 0.7 | Action | Wrist-flick toss that sends the food prop 1 stud up. Heat shimmer only, no flames. | STN_STOVE |
| `ANM_025` | Scoop ice cream | Cooking | R15 · P, E | No | 0.8 | Action | Dig-and-curl scoop, plopped onto a cone with an effort face. | STN_ICECREAM |
| `ANM_026` | Pizza peel slide | Cooking | R15 · P, E | No | 1.0 | Action | Long peel thrust like a pool shot, then a yank back. Also used to pull the pizza out. | STN_PIZZA_OVEN |
| `ANM_027` | Steamer lid lift | Cooking | R15 · P, E | No | 0.7 | Action | Lid lifted, recoil from the steam cloud, waft it away with the free hand. | STN_STEAMER |
| `ANM_028` | Infuse (mutagen pump) | Cooking | R15 · P, E | Yes | 0.9 | Action | Bellows pump with goggles on. Glowing goo travels down the tube via texture scroll. | STN_INFUSER |
| `ANM_029` | Anti-grav toss | Cooking | R15 · P, E | Yes | 1.1 | Action | Food tossed into the hover field and tapped with chopsticks while it floats. | STN_ANTIGRAV |
| `ANM_030` | Extinguish fire | Cooking | R15 · P, E | Yes | 0.8 | Action | Panicked sweep with a cartoon extinguisher until ON_FIRE clears. | ON_FIRE stations |
| `ANM_031` | Reach & grab | Cooking | R15 · P, E | No | 0.6 | Action (UB) | Open shelf or door, rummage, then pull out the ingredient with a "found it!" lift. | STN_PANTRY; STN_FRIDGE; STN_DELIVERY |
| `ANM_032` | Freezer dunk | Cooking | R15 · P, E | No | 0.8 | Action | Item dunked into the frosty chest. The body shivers on the way out. | STN_FREEZER (FREEZE) |
| `ANM_033` | Tentacle multi-chop | Cooking | R15 · P, E | Yes | 0.5 | Action | Flavor variant of `ANM_010`: three tentacles chop in a ripple. Same tap timing. | tentacle-tag ARM; EMP_001 |
| `ANM_034` | Perfect flourish | Cooking | R15 · P, E | No | 0.9 | Action (UB) | Chef's-kiss hand bloom over the item as it leaves a station at PERFECT. | CookingService quality = PERFECT |
| `ANM_035` | Burnt soot cough | Cooking | R15 · P, E | No | 1.0 | Action (UB) | Lifts the blackened item, gets a soot puff to the face, coughs, wipes the soot off. | BURNED result; MUSHY (shortened) |

#### 36.14.4 Customers and tantrums

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_040` | Customer sit | Customer | R15 · C, P, E | Yes | 3.0 | Movement | Hop-in sit with swinging legs. The seat offset is LegLength-aware, and tails drape over the chair back. | CustomerAIService Sit; seats |
| `ANM_041` | Read menu | Customer | R15 · C | Yes | 2.5 | Action (UB) | Menu held up while the head scans left-right. 10 % chance of an upside-down menu gag. | Review menu state |
| `ANM_042` | Order wave | Customer | R15 · C | Yes | 1.0 | Action (UB) | Eager arm wave. Claw, tentacle and wing limbs wave whatever is attached. | Place order state |
| `ANM_043` | Eat | Customer | R15 · C, P | Yes | 1.2 | Action (UB) | Big chomp loop with a full-cheek face swap and crumb VFX on `Vfx`. | Eat state; MUT dish |
| `ANM_044` | Pay | Customer | R15 · C | No | 1.0 | Action (UB) | Digs in a pocket (or shell), then slaps coins on the table with a coin-burst VFX. | Pay state |
| `ANM_045` | Tip flourish | Customer | R15 · C | No | 1.2 | Action (UB) | Magician coin flick with sparkle. Satisfaction 98+ adds a blown kiss. | Tip state (S ≥ 70) |
| `ANM_046` | Impatient foot tap | Customer | R15 · C | Yes | 0.8 | Action | Arms crossed, foot taps on the beat. The seated variant drums fingers (UB keys only). | Anger 1 Annoyed; patience < 50 % |
| `ANM_047` | Complain (arms flail) | Customer | R15 · C | Yes | 1.6 | Action | Full-body rant, pointing at the plate. `Vfx` marker spawns "WRONG ORDER?!" comic text. | Anger 2 Complaining; INSTIGATOR |
| `ANM_048` | Throw food | Tantrum | R15 · C, P | No | 0.9 | Action2 | Wind-up and overhand lob. `Release` hands off to the scripted raycast arc (§11). | Anger 3; `ABL_005` |
| `ANM_049` | Flip table | Tantrum | R15 · C | No | 1.3 | Action2 | Grips the table edge and heaves with a roar. The table runs its damage state and plates fly as client debris. | Anger 4; CHARGER |
| `ANM_050` | Tantrum stomp | Tantrum | R15 · C | Yes | 1.0 | Action2 | Clenched fists, alternating stomps, head shakes, dust puffs on `FootL`/`FootR`. | Anger 4–6 |
| `ANM_051` | Victory dance | Celebrate | R15 · C, P | Yes | 2.0 | Action | Goofy shuffle with hip wiggles. A customer who KOs the player plays it, then leaves (canon §C12.1). | Player KO; arena win |
| `ANM_052` | Dizzy stars | Status | R15 · A | Yes | 1.5 | Action4 | Wobbly circle with stars orbiting the head. Loops for the STS_DIZZY duration (3 s at 0 Huff Points). | STS_DIZZY |
| `ANM_053` | Apologize bow | Customer | R15 · C | No | 1.4 | Action | Deep embarrassed bow with hands together and a blush face. Precedes the Apology Payment. | Apologizing state |
| `ANM_054` | Flee (cartoon scramble) | Customer | R15 · C | Yes | 0.5 | Movement | Legs windmill in place for 0.3 s, then a dash with arms up. Replaces run. | Fleeing state; TRICKSTER |
| `ANM_055` | Escorted out (grumble shuffle) | Customer | R15 · C | Yes | 1.2 | Movement | Slumped shuffle with a muttering head shake. Paired with `ANM_239`. | Being escorted out |
| `ANM_056` | Cry dramatically | Customer | R15 · C | Yes | 1.4 | Action | Face in hands, cartoon tear fountains (water-blue streams), occasional peek-through-fingers. | PACIFIST at anger 3–5 |
| `ANM_057` | Storm out | Customer | R15 · C | Yes | 0.9 | Movement | Nose-up stomping exit. The door slam is scripted at the threshold. | Storm-out (pays 0) |
| `ANM_058` | Calming down | Customer | R15 · C | No | 2.0 | Action | Deep breaths with shoulders rising and falling, then the steam puffs fade. | Calming down state; `ABL_006` |
| `ANM_059` | Instigator yell | Customer | R15 · C | Yes | 1.2 | Action (UB) | Cupped-hand yell toward neighbors. The anger-aura ring pulses on `Vfx`. | INSTIGATOR aura |
| `ANM_100` | Queue wait | Customer | R15 · C | Yes | 3.5 | Idle | In-line idle: weight shifts, peeks around the customer in front, checks an invisible watch. | Request seating / queue |
| `ANM_101` | Inspect food | Customer | R15 · C | No | 1.5 | Action (UB) | Leans in, sniffs, pokes the dish with a fork. The reaction branch fires on `Impact`. | Inspect food state |
| `ANM_102` | Delighted cheer | Customer | R15 · C | No | 1.6 | Action | Bounces in the seat, fists up, hearts pop. | Satisfaction ≥ 90 |
| `ANM_103` | Sulk | Customer | R15 · C | Yes | 2.5 | Action (UB) | Arms crossed, chin on the table, a tiny rain cloud overhead. | Failed escalation roll; PACIFIST |
| `ANM_104` | Dust-cloud scuffle | Tantrum | R15 · C | Yes | 1.0 | Action2 | Customer-vs-customer brawl hidden in a cartoon dust ball with limbs poking out. Client-only cloud mesh. | Customers fighting each other (anger 4–6) |
| `ANM_105` | Poof to seat | Customer | R15 · C | No | 0.6 | Action4 | Puff of smoke, "Pardon me!", then the customer reappears seated. | Stuck > 6 s (canon E10) |
| `ANM_106` | Mutation-dish "Whoa!" | Customer | R15 · C | No | 1.4 | Action | Stares at the arm as a temporary part pops on, then a wide-eyed "Whoa!". | MUT dish 60 s cosmetic part |
| `ANM_107` | Selfie pose | Customer | R15 · C | No | 2.0 | Action (UB) | Phone-free selfie: peace sign, duck face, flash sparkle. | PER_009 signature |
| `ANM_108` | Critic notes | Customer | R15 · C | Yes | 2.2 | Action (UB) | Monocle squint, tiny-notepad scribble, a single dramatic eyebrow lift. | PER_004, PER_025 |
| `ANM_109` | Doze off | Customer | R15 · C | Yes | 3.0 | Action (UB) | Head droops onto the menu, big "Z" bubbles, startles awake every 6 s. | PER_006; STS_SLEEPY (seated) |
| `ANM_110` | Invisible box mime | Customer | R15 · C | Yes | 2.4 | Action | Silent palms-on-glass box routine, then complains in mime. | PER_019 |
| `ANM_111` | Flex pose | Customer | R15 · C, P | No | 1.8 | Action | Double-bicep flex with a chest bump. Offense-taking variant points at the waiter. | PER_010, PER_030 |
| `ANM_112` | Drama faint | Customer | R15 · C | No | 2.0 | Action | Back of hand to forehead, slow swoon onto the chair, one eye peeks to see who noticed. | PER_018 |
| `ANM_113` | Party cheer | Customer | R15 · C | Yes | 1.5 | Action (UB) | Party-horn toot (no prop needed), confetti toss, group sway. | PER_016, PER_031 |

#### 36.14.5 Repair, KO and progression core

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_060` | Hammer repair | Repair | R15 · P, E | Yes | 0.6 | Action | Kneeling double-tap hammer with star sparks on `Impact`. | RepairService; ROLE_REPAIR |
| `ANM_061` | Weld / bolt repair | Repair | R15 · P, E | Yes | 0.9 | Action | Wrench ratchet plus a cartoon sparkle welder (no flame) on appliances. | Appliance repair |
| `ANM_062` | Seeing Stars (KO) | Status | R15 · P | No | 4.0 | Action4 | Spin, pratfall, then lies still with stars and tiny birds orbiting. Matches the canon 4 s KO. | CombatService KO |
| `ANM_063` | Respawn poof | System | R15 · P | No | 0.8 | Action4 | Pops out of a confetti puff at the kitchen spawn and shakes the head clear. | Respawn (60 % HP, STS_WOOZY) |
| `ANM_064` | Level-up celebrate | Celebrate | R15 · P | No | 1.8 | Action (UB) | Fist pump plus a spin. Deferred while interacting or In Combat (canon E14). | ProgressionService |
| `ANM_065` | Mutation equip flex | Celebrate | R15 · P | No | 1.6 | Action | Flexes toward the new part's slot as the part pops in with a squash tween. | MutationService equip; Morph menu |
| `ANM_066` | Cash register cha-ching | Service | R15 · P, E | No | 0.9 | Action (UB) | Slams a key, the drawer pops, a coin flips in. | Payment; ROLE_CASHIER |

#### 36.14.6 Combat, reactions and status

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_140` | Combat idle | Combat | R15 · P, C | Yes | 1.6 | Idle | Bouncing fists-up stance. Claws snap and tails lash procedurally. | In Combat flag; BRAWLER |
| `ANM_141` | Hit react – light | Reaction | R15 · A | No | 0.35 | Action3 | Head snaps back, eyes squeeze shut, star sparkle at the hit point. Direction comes from 4 mirrored variants. | Any light hit |
| `ANM_142` | Hit react – heavy | Reaction | R15 · A | No | 0.7 | Action3 | Stagger two steps with flailing arms and wobbly knees. | Heavy hits; `ABL_002` |
| `ANM_143` | Knockdown & get-up | Reaction | R15 · A | Seg | 1.8 | Action4 | Launch, cartoon tumble, flat-on-back loop, then a kip-up. | STS_KNOCKDOWN; knockback |
| `ANM_144` | Guard break wobble | Status | R15 · A | No | 1.0 | Action4 | Arms fly apart and the body wobbles like jelly for the 1.0 s stun. | Guard break; STS_STUN |
| `ANM_145` | Brawler combo | Combat | R15 · C | No | 1.2 | Action2 | NPC jab-jab-haymaker. `Impact` markers at 0.3 / 0.6 / 1.0 s. | BRAWLER style |
| `ANM_146` | Charger wind-up & rush | Combat | R15 · C | Seg | 1.6 | Action2 | Hoof scrape plus steam snort (0.6 s tell), head-down rush loop, skid stop. | CHARGER style |
| `ANM_147` | Tank ground slam | Combat | R15 · C | No | 1.5 | Action2 | Slow two-fist raise (0.8 s tell), then a slam with a dust shock ring. | TANK style |
| `ANM_148` | Trickster snatch & flee | Combat | R15 · C | No | 1.1 | Action2 | Sneaky tiptoe, plate snatch, cheeky tongue-out, scramble away. | TRICKSTER style |
| `ANM_149` | Thrower quick lob | Combat | R15 · C | No | 0.7 | Action2 | Back-step plus a sidearm toss. `Release` marker at 0.45 s. | THROWER style |
| `ANM_150` | Frozen solid | Status | R15 · A | Yes | 1.0 | Action4 | Pose freezes mid-motion inside a client ice-block mesh. Only the eyes dart. | STS_FROZEN |
| `ANM_151` | Shocked jitter | Status | R15 · A | Yes | 0.3 | Action3 | Rigid jitter with fur standing up (procedural), cartoon zig-zag outline. | STS_SHOCKED |
| `ANM_152` | Sticky struggle | Status | R15 · A | Yes | 0.9 | Action3 | Feet glued while the upper body tugs and the legs stretch-pull. | STS_STICKY |
| `ANM_153` | Sleepy sway | Status | R15 · A | Yes | 2.0 | Action3 | Slow head nods and drooping arms. Speed 0.7 for STS_SLOW, a wider sway for STS_WOOZY. | STS_SLEEPY, STS_WOOZY, STS_SLOW |
| `ANM_154` | Confused stumble | Status | R15 · A | Yes | 1.4 | Action3 | Zig-zag steps and hand-shading search. `?` icons orbit. | STS_CONFUSED, STS_BLINDED |
| `ANM_155` | Floating paddle | Status | R15 · A | Yes | 1.2 | Action4 | Airborne doggy-paddle with bicycle legs. | STS_FLOATING; `ABL_045` target |
| `ANM_156` | Shake-off | Status | R15 · A | No | 0.9 | Action3 | Wet-dog full-body shake. Ends STS_SOAKED, STS_GREASY, STS_STINKY and STS_TOASTY with that state's FX. | STS_SOAKED, STS_GREASY, STS_STINKY, STS_TOASTY |
| `ANM_157` | Charmed swoon | Status | R15 · A | Yes | 1.6 | Action3 | Heart-eyes sway toward the charmer with hands clasped. | STS_CHARMED; `ABL_029` target |
| `ANM_158` | Power-up pose | Status | R15 · P | No | 0.8 | Action (UB) | Quick fist clench with a glow ring. Plays on buff application. | STS_INSPIRED, STS_HYPED, STS_SHIELDED |
| `ANM_159` | Food splat flinch | Reaction | R15 · A | No | 0.8 | Action3 | Food hits the face: freeze, slow wipe, outraged blink (+anger handled by AI). | Thrown-food hit |
| `ANM_160` | Arena entrance | Combat | R15 · P | No | 2.5 | Action | Slide-in pose plus a crowd-point and a signature mutation flex. | BLD_08 arena intro |
| `ANM_161` | Arena taunt | Combat | R15 · P | No | 1.5 | Action | "Come at me" wave, then a chef-hat tip. Cosmetic only (no buff). | Arena; emote wheel |

#### 36.14.7 Repair, build and props

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_180` | Sweep debris | Repair | R15 · P, E | Yes | 1.0 | Action | Broom sweeps rubble into a neat pile before rebuild. A dust puff on each stroke. | Repair prelude (Broken/Destroyed) |
| `ANM_181` | Rebuild from rubble | Repair | R15 · P, E | Seg | 2.4 | Action | Arms spread in a "rewind" conductor gesture while the rubble pieces fly back together. | Rebuild job (Destroyed → Pristine) |
| `ANM_182` | Placement hold | Build | R15 · P | Yes | 1.5 | Action (UB) | Hands frame the hologram furniture like a director while the object follows the cursor. | BuildingService placement mode |
| `ANM_183` | Construction crew hammer | Build | R15 · X | Yes | 0.8 | Action | Tiny client-only crew mutants hammer, saw and wave flags on the scaffold. | Mutant Builders sequence (§15, §25.4.7) |
| `ANM_184` | Ribbon cutting | Build | R15 · P, N | No | 2.0 | Action | Giant scissors snip, the ribbon halves flop, confetti on `Vfx`. | Grand Opening (§15); optional NPC_002 at TIER_04+ |
| `ANM_185` | Prop – façade unfold | Prop | Prop | No | 1.5 | Action | As the dust clears, the new façade panels snap into place like a pop-up book. | Mutant Builders reveal at 7.0 s (§15) |
| `ANM_186` | Prop – capsule shake-open | Prop | Prop | No | 2.2 | Action | Morph Capsule wobbles 3× (each shake bigger), pops the lid, rarity beam rises. | Capsule open; `ANM_207` |
| `ANM_187` | Prop – appliance fire rattle | Prop | Prop | Yes | 0.4 | Action | Appliance hops and rattles with a cartoon flame on top (flame on the appliance only). | ON_FIRE; Broken appliance |

#### 36.14.8 Celebrate, emote and system

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_200` | Emote – Wave | Emote | R15 · P, N | No | 1.4 | Action (UB) | Big friendly wave with the nearest limb. | Emote wheel; NPC greetings |
| `ANM_201` | Emote – Chef's Kiss | Emote | R15 · P | No | 1.2 | Action (UB) | Fingers to mouth, "mwah", sparkle burst. | Emote wheel (earnable) |
| `ANM_202` | Emote – Noodle Dance | Emote | R15 · P | Yes | 2.4 | Action | Limp-limbed wiggle dance. Extra limbs flop procedurally. | Emote wheel (earnable) |
| `ANM_203` | Emote – Facepalm | Emote | R15 · P | No | 1.6 | Action (UB) | Slow facepalm with a head shake. Tentacles do a "tentaclepalm". | Emote wheel |
| `ANM_204` | Emote – Thumbs Up | Emote | R15 · P | No | 1.0 | Action (UB) | Thumbs up with a "ting" glint. Claws do a pinch-up. | Emote wheel; tutorial |
| `ANM_205` | Emote – Slow Clap | Emote | R15 · P | Yes | 1.2 | Action (UB) | Sarcastic slow clap. Speeds up into a sincere clap on repeat. | Emote wheel |
| `ANM_206` | Emote – Spatula Salute | Emote | R15 · P, E | No | 1.3 | Action (UB) | Spatula raised to the brow like a knight's salute. | Emote wheel; employee hire |
| `ANM_207` | Rare reveal gasp | Celebrate | R15 · P | No | 2.0 | Action | Jaw drops, hands on cheeks, jumps back as the rarity beam rises. Epic+ adds a spin. | Capsule and fusion reveal |
| `ANM_208` | Welcome Back wave | System | R15 · P | No | 2.0 | Action | Morph preview pops up from below the report card and waves. | Offline report screen (§17, §24) |
| `ANM_209` | Loadout swap spin | System | R15 · P | No | 3.0 | Action | Spins inside a sparkle tornado while the parts swap at 2.8 s. Interrupted by damage. | Loadout swap 3 s channel (canon E4) |
| `ANM_210` | Rest pose | System | R15 · A | Yes | 1.0 | Core | Neutral A-pose reference. Fallback when no track plays; used for part-fit QA. | MorphAssemblyService; asset QA |
| `ANM_211` | Morph preview idle | System | R15 · P | Yes | 3.0 | Idle | Turntable-friendly idle that shows off arms and tail. The slot-focus pose blends over it. | Morph customization viewport (§13) |
| `ANM_212` | Collect earnings scoop | Celebrate | R15 · P | No | 1.6 | Action (UB) | Scoops a coin avalanche into the arms, wobbles under the weight. | Collect earnings; milestones |

#### 36.14.9 Employee work cycles

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_230` | Chef "Order up!" | Employee | R15 · E | No | 1.2 | Action (UB) | Slaps the window bell and points at the plate. Ends each chef cycle. | ROLE_CHEF |
| `ANM_231` | Prep chop & pass | Employee | R15 · E | Yes | 1.5 | Action | Rapid 3-chop burst, then a slide of the board to the chef. | ROLE_PREP |
| `ANM_232` | Waiter seat guide | Employee | R15 · E | No | 1.4 | Action (UB) | "Right this way" sweep plus a chair pull-out. | ROLE_WAITER seating |
| `ANM_233` | Waiter notepad | Employee | R15 · E | Yes | 1.8 | Action (UB) | Licks the pencil, scribbles, nods. Order ticket pops on `Vfx`. | ROLE_WAITER order taking |
| `ANM_234` | Cashier scan & receipt | Employee | R15 · E | No | 1.6 | Action (UB) | Beep-scan, receipt curls out 2 studs long, tears with a flourish. | ROLE_CASHIER |
| `ANM_235` | Dishwasher stack scrub | Employee | R15 · E | Yes | 1.6 | Action | Flavor variant of `ANM_021` with a 4-plate stack and a spin-dry twirl. | ROLE_DISH |
| `ANM_236` | Cleaner spray & wipe | Employee | R15 · E | Yes | 1.4 | Action (UB) | Spray-bottle psst-psst, circular wipe, "sparkle" check. | ROLE_CLEANER |
| `ANM_237` | Repair tech toolbox | Employee | R15 · E | No | 1.2 | Action | Kneels, flips the toolbox open, picks a tool. Precedes `ANM_060`/`ANM_061`. | ROLE_REPAIR |
| `ANM_238` | Security stop-hand | Employee | R15 · E | No | 1.0 | Action2 | Steps in front with a palm out, "Whoa there, buddy". Interrupts a customer wind-up. | ROLE_SECURITY intercept |
| `ANM_239` | Security escort | Employee | R15 · E | Yes | 1.2 | Movement | Gentle shoulder-guide walk beside the customer (pairs with `ANM_055`). | ROLE_SECURITY escort |
| `ANM_240` | Manager clipboard pace | Employee | R15 · E | Yes | 3.0 | Action (UB) | Paces with a clipboard, taps a pen, points at stations. | ROLE_MANAGER |
| `ANM_241` | Manager pep talk | Employee | R15 · E | No | 2.2 | Action | Double clap and "you got this!" fist, sparkle ring on staff in range. | ROLE_MANAGER morale tick |
| `ANM_242` | Delivery bag dash | Employee | R15 · E | No | 1.0 | Action (UB) | Grabs the insulated bag, salutes, dashes out the door (delivery is off-screen). | ROLE_DELIVERY |
| `ANM_243` | Stocker shelf restock | Employee | R15 · E | Yes | 1.8 | Action | Slides crates onto the shelf and counts on their fingers. | ROLE_STOCKER |
| `ANM_244` | Asst manager whistle | Employee | R15 · E | No | 1.2 | Action (UB) | Coach whistle tweet plus a double point at the busiest station. | ROLE_ASST_MGR |
| `ANM_245` | Tired yawn | Employee | R15 · E | No | 2.0 | Action (UB) | Huge yawn, eye rub. Plays when Energy < 30 %. | EmployeeService energy |
| `ANM_246` | Unpaid break sit | Employee | R15 · E | Yes | 3.0 | Movement | Sits on an upturned crate holding a "BREAK" sign (canon E8). | Unpaid Break |
| `ANM_247` | Hero moment pose | Employee | R15 · E | No | 2.0 | Action | Heroic chest-out pose with a cape-flutter wind gust. | Offline report highlight; hero incidents |
| `ANM_248` | Low-morale slump | Employee | R15 · E | Yes | 2.5 | Action (UB) | Drooping shoulders, sigh, tiny raincloud. Plays when Morale < 30. | EmployeeService morale |
| `ANM_249` | Hired greeting bow | Employee | R15 · E | No | 1.6 | Action | Excited bow plus an apron tie-on. First appearance after hiring. | Recruitment (BLD_04); QST_TUT_012 |

#### 36.14.10 City NPCs and crowd

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_260` | Shopkeeper lean | NPC | R15 · N | Yes | 4.0 | Idle | Counter lean, drums fingers, perks up when a player is within 10 studs. | Shop NPCs (NPC_004–NPC_007, NPC_015) |
| `ANM_261` | Announcer hype | NPC | R15 · N | Yes | 2.0 | Action | Mic-hand sweeps, jumps, crowd point. | NPC_011, NPC_024, NPC_030 |
| `ANM_262` | Crowd stroll | NPC | R15 · X | Yes | 1.2 | Movement | Low-cost stroll for client-only crowds. A single track with no secondary motion. | City crowds (§18) |
| `ANM_263` | Crowd gawk | NPC | R15 · X | No | 2.0 | Action (UB) | Stops, points at a billboard or a flashy morph, whispers to nobody. | City crowds; billboards |
| `ANM_264` | Busker play | NPC | R15 · N, X | Yes | 2.0 | Action (UB) | Generic instrument strum or toot. One loop per instrument prop. | DST_07 buskers (MUT_112 puzzle) |
| `ANM_265` | Pigeon Taxi ride | NPC | R15 · P | Yes | 2.0 | Movement | Seated on the giant pigeon, hanging on, hat flapping. | Pigeon Taxi travel |
| `ANM_266` | Hologram Nana scold | NPC | R15 · N | Yes | 2.4 | Action | Finger wag plus an arms-crossed huff on the flickering menu-board hologram. | NPC_001 tutorial |
| `ANM_267` | Baron monocle scoff | NPC | R15 · N | No | 1.8 | Action (UB) | Monocle pop, sniff, tail flick of disdain. | NPC_003 story scenes |
| `ANM_268` | Critic judging | NPC | R15 · N | Yes | 2.6 | Action (UB) | Long-neck lean-in, sniff, tentacle scribble on the scorecard. | NPC_016; EVT_008 |

#### 36.14.11 City events

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_280` | Parade wave | Event | R15 · N, X, P | Yes | 2.0 | Action (UB) | Pageant wave from a float, alternating hands. | EVT_002; EVT_028 |
| `ANM_281` | Dance-off routine | Event | R15 · P, X | Yes | 4.0 | Action | 4-count goofy routine. Players match prompts. | EVT_027; BLD_22 |
| `ANM_282` | Handstand walk | Event | R15 · P, C | Yes | 1.2 | Movement | Upside-down hand-walk with legs waving. Replaces walk during the event. | EVT_011 Upside-Down Day |
| `ANM_283` | Weather shiver & fan | Event | R15 · A | Yes | 1.6 | Action (UB) | Teeth-chatter shiver (cold) or self-fanning (heat), chosen by an event flag. | EVT_020; EVT_019 |
| `ANM_284` | Rat King stomp-roar | Event | R15 · N | No | 2.2 | Action2 | Crown wobble, tail-lash stomp, squeaky roar with a shock ring. | NPC_020; EVT_007 |
| `ANM_285` | Pickle umbrella | Event | R15 · A | Yes | 1.5 | Action (UB) | Holds a hand or a menu over the head as pickles bounce off. | EVT_012 Pickle Rain |

#### 36.14.12 Ability animations (`ANM_301`–`ANM_370` ↔ `ABL_001`–`ABL_070`)

Names equal the canon ability names (§C12.2). Mutation actives list their source part (§C13.6). §11 owns timing,
damage and hitboxes in §36.6. Where these durations disagree with §36.6, §11's cast and recovery windows win, and the
track is speed-scaled to fit. Users: P = player, C = customer using the NPC-tuned version (§C11.6).

| ID | Name | Category | Rig / users | Loop? | Duration (s) | Priority | Description | Used by (systems / ability ids) |
|---|---|---|---|---|---|---|---|---|
| `ANM_301` | Swipe Combo | Ability | R15 · P | No | 1.05 | Action2 | Three limb-agnostic swipes L-R-L, `Impact` every 0.35 s. | `ABL_001` base kit |
| `ANM_302` | Wallop | Ability | R15 · P | No | 0.9 | Action2 | 0.6 s glowing wind-up, then an overhead two-limb smash. `Impact` at 0.65 s. | `ABL_002` base kit |
| `ANM_303` | Block | Ability | R15 · P | Yes | 0.5 | Action2 | Crossed-limb brace (shells and claws turn forward). Additive flinch on each hit. | `ABL_003` base kit |
| `ANM_304` | Dodge Roll | Ability | R15 · P | No | 0.4 | Action2 | Tuck-and-roll, i-frames marked 0.05–0.30 s. Wings fold and tails tuck. | `ABL_004` base kit |
| `ANM_305` | Grab & Throw | Ability | R15 · P, C | No | 1.1 | Action2 | Lifts a prop overhead, wobbles, heaves. `Release` at 0.8 s. | `ABL_005` base kit |
| `ANM_306` | Calm Down! | Ability | R15 · P | No | 1.2 | Action | Palms-down "shhh" with lavender soothe ripples. | `ABL_006` base kit |
| `ANM_307` | Pan Bonk | Ability | R15 · P | No | 0.7 | Action2 | Two-handed frying-pan golf swing, `Impact` at 0.4 s. | `ABL_007` (held pan) |
| `ANM_308` | Tray Shield | Ability | R15 · P | Yes | 0.6 | Action2 | Tray raised at face height. Deflect spark on hit. | `ABL_008` (held tray) |
| `ANM_309` | Scorpion Tail Swipe | Ability | R15 · P, C | No | 0.8 | Action2 | Torso twist drives a 180° over-shoulder tail arc. | `ABL_009` · MUT_216 |
| `ANM_310` | Bear Slam | Ability | R15 · P, C | No | 1.0 | Action2 | Overhead double-paw slam with a dust ring. | `ABL_010` · MUT_140 |
| `ANM_311` | Kangaroo Kick | Ability | R15 · P, C | No | 0.9 | Action2 | Leans back on the tail, double-leg spring kick. | `ABL_011` · MUT_184 |
| `ANM_312` | Octo-Flurry | Ability | R15 · P, C | No | 1.4 | Action2 | Rapid multi-tentacle slap flurry that fans across up to 3 targets. | `ABL_012` · MUT_145 |
| `ANM_313` | Rhino Charge | Ability | R15 · P, C | Seg | 1.5 | Action2 | Hoof-scrape wind-up (0.5 s), head-down charge loop, skid. | `ABL_013` · MUT_099 |
| `ANM_314` | Eel Zap | Ability | R15 · P, C | No | 0.8 | Action2 | Body crackles, arms thrust out a cartoon zap bolt. | `ABL_014` · MUT_253 |
| `ANM_315` | Spine Burst | Ability | R15 · P, C | No | 0.7 | Action2 | Crouch-and-puff, spines flare out in a ring, recovery shake. | `ABL_015` · MUT_243 |
| `ANM_316` | Tongue Yank | Ability | R15 · P, C | No | 0.9 | Action2 | Mouth opens, a tongue Beam lashes out and reels the target in. | `ABL_016` · MUT_061 |
| `ANM_317` | Claw Grab & Toss | Ability | R15 · P, C | No | 1.2 | Action2 | Claw snaps onto the target or prop, a spin, an overhand toss. | `ABL_017` · MUT_144 |
| `ANM_318` | Dragon Breath | Ability | R15 · P, C | Seg | 1.5 | Action2 | 0.3 s rear-back, a looping breath segment held for the whole 1.5 s channel (orange sparkles and soot cone), 0.2 s exit. Never flames on bodies. | `ABL_018` · MUT_031 |
| `ANM_319` | Shark Chomp | Ability | R15 · P, C | No | 0.6 | Action2 | Lunge with jaws wide, comic CHOMP freeze-frame (2 frames held). | `ABL_019` · MUT_062 |
| `ANM_320` | Web Shot | Ability | R15 · P, C | No | 0.6 | Action2 | Head-thrust spit of a web glob. | `ABL_020` · MUT_028 |
| `ANM_321` | Ground Pound | Ability | R15 · P, C | No | 1.1 | Action2 | Knuckle hop and a double-fist pound with a shockwave ring. | `ABL_021` · MUT_148 |
| `ANM_322` | Flap Hover | Ability | R15 · P, C | Yes | 0.5 | Action2 | Frantic tiny-wing flaps, legs dangling, slow descent. | `ABL_022` · MUT_231 |
| `ANM_323` | Bat Screech | Ability | R15 · P, C | No | 1.0 | Action2 | Ears flare, cupped-hand screech with visible sound rings. | `ABL_023` · MUT_089 |
| `ANM_324` | Skunk Cloud | Ability | R15 · P, C | No | 0.9 | Action2 | Turns around, tail up, green cartoon puff, holds nose after. | `ABL_024` · MUT_220 |
| `ANM_325` | Puff Up | Ability | R15 · P, C | Seg | 1.2 | Action2 | Inflates (swap to a pre-modeled puffed torso on `Vfx`), bounce loop, deflate raspberry. | `ABL_025` · MUT_129 |
| `ANM_326` | Mantis Chop | Ability | R15 · P, C | No | 0.7 | Action2 | Scythe arms cross-chop in an X. | `ABL_026` · MUT_151 |
| `ANM_327` | Armadillo Roll | Ability | R15 · P, C | Seg | 1.6 | Action2 | Curls into a ball (mesh swap), rolling loop, uncurl pose. | `ABL_027` · MUT_128 |
| `ANM_328` | Trunk Spray | Ability | R15 · P, C | Yes | 1.0 | Action2 | Trunk raised, water-jet sweep left to right. | `ABL_028` · MUT_053 |
| `ANM_329` | Peacock Dazzle | Ability | R15 · P, C | No | 1.2 | Action2 | Tail fan snaps open, shimmy, sparkle burst (photosafe ≤ 3 Hz). | `ABL_029` · MUT_219 |
| `ANM_330` | Owl Spin Counter | Ability | R15 · P, C | No | 0.8 | Action2 | Head spins 360° while the body ducks, then a counter-swipe. | `ABL_030` · MUT_016 |
| `ANM_331` | Rocket Punch | Ability | R15 · P, C | No | 1.0 | Action2 | Wind-up, the fist rockets off on a trail and boomerangs back. | `ABL_031` · MUT_154 |
| `ANM_332` | Laser Eyes | Ability | R15 · P, C | Yes | 1.0 | Action2 | Braced stance while the head sweeps a Beam across. | `ABL_032` · MUT_078 |
| `ANM_333` | Magnet Pull | Ability | R15 · P, C | No | 1.0 | Action2 | Magnet hand thrust and yank-back. Pulled props wobble in. | `ABL_033` · MUT_155 |
| `ANM_334` | Toast Barrage | Ability | R15 · P, C | No | 1.2 | Action2 | Head bobs as toast pops fire in a 3-shot burst. | `ABL_034` · MUT_010 |
| `ANM_335` | Vacuum Suck | Ability | R15 · P, C | Yes | 1.0 | Action2 | Leans back, mouth-vortex swirl, items stream in. | `ABL_035` · MUT_066 |
| `ANM_336` | Umbrella Parry | Ability | R15 · P, C | No | 0.6 | Action2 | Snaps the umbrella open forward, deflects, twirls. | `ABL_036` · MUT_157 |
| `ANM_337` | Jelly Bounce | Ability | R15 · P, C | No | 1.0 | Action2 | Squash-down, then a big jiggly hop that boings foes away. | `ABL_037` · MUT_134 |
| `ANM_338` | Cactus Hug | Ability | R15 · P, C | No | 1.2 | Action2 | Arms-wide hug lunge with prickle sparkles on contact. | `ABL_038` · MUT_132 |
| `ANM_339` | Flytrap Snap | Ability | R15 · P, C | No | 0.7 | Action2 | Head lunges, jaws snap shut, chew-and-spit. | `ABL_039` · MUT_035 |
| `ANM_340` | Spore Puff | Ability | R15 · P, C | No | 0.8 | Action2 | Bows forward and the mushroom cap releases a pastel spore cloud. | `ABL_040` · MUT_248 |
| `ANM_341` | Frost Blast | Ability | R15 · P, C | No | 0.9 | Action2 | Ice-arm thrust with a snowflake cone burst. | `ABL_041` · MUT_162 |
| `ANM_342` | Thunder Clap | Ability | R15 · P, C | No | 0.8 | Action2 | Overhead clap and a spark ring from the horn. | `ABL_042` · MUT_105 |
| `ANM_343` | Lava Slam | Ability | R15 · P, C | No | 1.1 | Action2 | Lava-fist raise, ground punch, cartoon magma-bubble ring. | `ABL_043` · MUT_163 |
| `ANM_344` | Gust Kick | Ability | R15 · P, C | No | 0.7 | Action2 | Cloud-leg roundhouse that blows a wind cone. | `ABL_044` · MUT_197 |
| `ANM_345` | Tractor Beam | Ability | R15 · P, C | Yes | 1.0 | Action2 | Alien arm raised while the beam lifts the target in a wobble-carry. | `ABL_045` · MUT_166 |
| `ANM_346` | Comet Blink | Ability | R15 · P, C | No | 0.5 | Action2 | Crouch, streak-teleport along a comet trail, arrival pose. | `ABL_046` · MUT_228 |
| `ANM_347` | Mind Buzz | Ability | R15 · P, C | No | 1.0 | Action2 | Fingers to temples, wobbly psychic rings. | `ABL_047` · MUT_033 |
| `ANM_348` | Slime Trail | Ability | R15 · P, C | Yes | 0.8 | Movement | Skate-slide gait that lays a slime decal trail. | `ABL_048` · MUT_256 |
| `ANM_349` | Tentacle Whip | Ability | R15 · P, C | No | 0.8 | Action2 | Crack-the-whip arc with a long tentacle. | `ABL_049` · MUT_146 |
| `ANM_350` | Beak Peck Combo | Ability | R15 · P, C | No | 1.0 | Action2 | Rapid 4-peck head-bob combo. | `ABL_050` · MUT_063 |
| `ANM_351` | Wing Buffet | Ability | R15 · P, C | No | 1.0 | Action2 | Two forward wing beats and a gust push. | `ABL_051` · MUT_238 |
| `ANM_352` | Horn Toss | Ability | R15 · P, C | No | 0.9 | Action2 | Head-down scoop and an upward horn flick. | `ABL_052` · MUT_100 |
| `ANM_353` | Tail Spin | Ability | R15 · P, C | No | 1.0 | Action2 | Full-body 720° spin with the tail sweeping. | `ABL_053` · MUT_227 |
| `ANM_354` | Hammerhead Bash | Ability | R15 · P, C | No | 0.8 | Action2 | Sideways head swing like a mallet. | `ABL_054` · MUT_025 |
| `ANM_355` | Mole Burrow | Ability | R15 · P, C | Seg | 1.4 | Action2 | Dives into a dirt mound, tunnel-bump loop, pops out. | `ABL_055` · MUT_196 |
| `ANM_356` | Stink Bomb | Ability | R15 · P, C | No | 0.9 | Action2 | Reaches back to the shell and lobs a green stink orb. | `ABL_056` · MUT_251 |
| `ANM_357` | Firefly Flash | Ability | R15 · P, C | No | 0.6 | Action2 | Eyes squint, then a single soft glow pulse (no strobe). | `ABL_057` · MUT_083 |
| `ANM_358` | Goat Headbutt | Ability | R15 · P, C | No | 0.8 | Action2 | Back-up hop and a running headbutt. | `ABL_058` · MUT_097 |
| `ANM_359` | Ghost Phase | Ability | R15 · P, C | No | 1.0 | Action2 | Sheet flutter while the body fades to Transparency 0.6 (client), floaty drift. Silly, not spooky. | `ABL_059` · MUT_252 |
| `ANM_360` | Kraken Grasp | Ability | R15 · P, C | Seg | 3.3 | Action2 | Ultimate: 0.8 s rear-up wind-up, then a 2.5 s looping wrap-and-squeeze-shake segment, then a toss exit. Small camera nudge. | `ABL_060` · MUT_165 |
| `ANM_361` | Extra Hands | Ability | R15 · P | No | 0.8 | Action | Backpack arms unfold with a mechanical flourish. | `ABL_061` · MUT_249 |
| `ANM_362` | Repair Burst | Ability | R15 · P | No | 1.0 | Action | Wrench claw spins overhead and sends out a sparkle repair ring. | `ABL_062` · MUT_153 |
| `ANM_363` | Cheetah Dash | Ability | R15 · P | Seg | 0.8 | Action2 | Low sprint lean with speed lines, overlaid on run. | `ABL_063` · MUT_186 |
| `ANM_364` | Super Sniff | Ability | R15 · P | No | 1.2 | Action (UB) | Snout twitch, a huge sniff, then reveal sparkles float up. | `ABL_064` · MUT_058 |
| `ANM_365` | Soothing Song | Ability | R15 · P | Yes | 2.0 | Action | Fairy wings flutter, sway-and-hum, music-note ripples. | `ABL_065` · MUT_241 |
| `ANM_366` | Microwave Zap-Cook | Ability | R15 · P | No | 0.9 | Action | Head door opens, the item spins inside, DING, it jumps to GOOD. | `ABL_066` · MUT_036 |
| `ANM_367` | Freeze Touch | Ability | R15 · P | No | 0.6 | Action (UB) | Frosty fingertip tap with an ice crackle. | `ABL_067` · MUT_176 |
| `ANM_368` | Web Sweep | Ability | R15 · P | No | 1.2 | Action | Spider arms sweep a web net and the trash rolls into a ball. | `ABL_068` · MUT_150 |
| `ANM_369` | Hover Serve | Ability | R15 · P | Yes | 0.8 | Action | Jetpack lift with the tray held high, legs kicking. | `ABL_069` · MUT_245 |
| `ANM_370` | Eagle Eye | Ability | R15 · P | No | 1.0 | Action (UB) | Hand-visor scan and an eye-glint zoom as the meters appear. | `ABL_070` · MUT_079 |

#### 36.14.13 Library acceptance checks

- Every id above is uploaded under the group that owns the experience. Animations owned by another account do not
  play. Each upload's asset id is stored in the `AnimationIds` module keyed by the `ANM_` id.
- The validator confirms that all 52 canon core ids (§C21) and all 70 ability ids resolve to an uploaded asset, and
  that each Priority and Loop value in this table matches the asset's KeyframeSequence settings.

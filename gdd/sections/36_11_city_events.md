### 36.11 City Events Database

> **Owner:** A12 City. All 32 canon events (§C16.5). The scheduler, cross-server sync, announcements, reward
> units and restaurant protections are specified in §18.8; this appendix holds the per-event rows.
> Acceptance criteria: `AC-18-50` … `AC-18-69`.

**Legend.**

- **Type:** **H** headline (rotation, :00 UTC slots) · **S** side (rotation, :30 slots) · **M** modifier
  (rotation, odd hours :15, rules change for one 24-min city day) · **F** fixed UTC anchor · **X** seasonal.
- **Frequency** figures are expected values from the §18.8.2 decks: H pool = 11 events, 12 cards
  (`EVT_009` weight 2) over ~18 free headline slots/day → ~1.5/day each (~3 for `EVT_009`; ~1 and ~2 during
  seasonal months); S pool = 6 event cards (`EVT_003` weight 2) + 6 Quiet cards over 24 side slots → ~2/day each
  (~4 for `EVT_003`); M pool = 8 events over 12 windows → ~1.5/day each.
- **Rewards** are listed as **P / S / T** totals (Participation / Success / Top, §18.8.4). **ERM** → MB scaled by
  restaurant tier (`round(ERM × NetMBPerHour[tier] / 60)`); **XPF** → XP = XPF × XPRate(level); MS and RT are
  flat. Daily caps, capsule cap (3/day) and the trophy rule (each of `FRN_901`–`FRN_910` once, repeats → 100 MS) apply.
  Seasonal track rewards are one-time milestones and are exempt from the daily capsule cap.
- **Scope:** *city-wide*, *district* (named), *restaurant* (owner-present restaurants per §18.8.6).
- **Participation:** solo · co-op (party/guests) · server (everyone on the server shares the objective) ·
  cross-server (a global MemoryStore goal adds the +25 % MB bonus; server-local fallback target in Notes).

#### 36.11.1 Fixed anchors (UTC)

| Anchor | When | Event |
|---|---|---|
| Rat King raids | 02:00, 06:00, 10:00, 14:00, 18:00, 22:00 daily (headline slot) | `EVT_007` |
| Midnight Sale | 00:00–00:30 daily (district scope, runs alongside the 00:00 headline) | `EVT_024` |
| Arena Brawl Bash | Fri, Sat, Sun 20:00 · Sat, Sun 08:00 (headline slot) | `EVT_025` |
| Legendary Chef Tournament finals | Sat 19:00 · Sun 03:00 (headline slot); qualifying Mon 00:00 – Sat 18:00 | `EVT_005` |
| Founders' Glow Week | Jul 1–7, every unanchored headline hour divisible by 3; mini-edition first Saturday of each month 21:00 | `EVT_028` |
| Haunted Kitchen Night | Oct 1–31, every unanchored headline hour divisible by 3; Oct 31 23:00 extended edition | `EVT_029` |
| Snowmorph Holiday | Dec 1–31, every unanchored headline hour divisible by 3; Dec 24–26 every unanchored even hour | `EVT_030` |
| Spring Sprout Bloom | Apr 1–30, every unanchored headline hour divisible by 3 | `EVT_031` |

#### 36.11.2 Event table

| ID | Name | Type | Schedule / frequency | Duration | Scope | Rules & gameplay changes | Objectives | Rewards (P / S / T) | Participation | Min level | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `EVT_001` | Giant Food Festival | H | rotation, ~1.5/day | 12 min | district: DST_03 Gravy Plaza | Giant co-op stations unfold (8-slot Giant Grill, Giant Cutting Board, Giant Oven, Assembly Crane); giant components need a 2-player "team lift"; Perfect window ×2 on giant food; 3 courses (burger, pizza, sundae). | Server: finish ≥ 2 of 3 giant courses. Personal: ≥ 6 component actions (carry, cook, assemble). | ERM 6/12/16 · MS 10/25/40 · XPF 0.06/0.12/0.18 · S +1 Capsule · T (MVP) `FRN_901` first time | server + cross-server (60 % of servers finish all 3 courses) | 3 | Host `NPC_009`. Detail §36.11.3. |
| `EVT_002` | Mutation Parade | H | rotation, ~1.5/day | 10 min | city-wide route DST_01 → DST_03 → DST_07 | Float pads build a float around each rider's morph; floats follow a 1,200-stud spline; 4-lane rhythm prompts every 4 s; spectators catch candy and vote with emoji. | Riders: ≥ 70 % rhythm accuracy. Spectators: catch 10 candies + cast 3 votes. | ERM 4/8/12 · MS 10/20/30 · XPF 0.05/0.08/0.12 · T (most votes) `FRN_907` first time + title "Parade Grand Marshal" | server | 1 | Opened by `NPC_002`; judged by `NPC_005`. Event Access covers the DST_07 leg. |
| `EVT_003` | Citywide Restaurant Rush | S | rotation (weight 2), ~4/day | 8 min | restaurant (owners inside) | `EventMult ×2.0` demand; patience ×1.15; every 4th order is a gold Rush Ticket (tip ×1.5). Staffed restaurants of absent owners get ×1.3 demand only (no rewards). | Personal: serve `6 + 2 × tierNumber` dishes at S ≥ 70. Global: city-wide dishes ≥ 30 × total participants. | ERM 0/4/8 (cooking income is the main payout) · MS 5/15/25 · XPF 0/0.06/0.10 · global goal: +1 Capsule (once per day) | solo / co-op guests + cross-server | 2 | Fallback target: 30 × server participants. |
| `EVT_004` | Angry Customer Invasion | S | rotation, ~2/day; never in the side slot after `EVT_007`/`EVT_025` | 6 min | restaurant (opt-in; owners inside) | 3 waves of `2 + floor(tierNumber / 2)` invaders starting at anger 30; escalation rolls ×1.5; `ABL_006` cooldown −50 %; a Perfect dish instantly calms an invader; damage is **Event Damage** (free repairs; auto-heals 15 min after). | Calm or serve `8 + tierNumber` invaders; keep average durability ≥ 50 %. | ERM 3/8/12 · MS 10/20/30 · XPF 0.05/0.10/0.15 | solo / co-op | 4 | "Peaceful Restaurant" setting skips it. Detail §36.11.3. |
| `EVT_005` | Legendary Chef Tournament | F | qualifying all week; finals Sat 19:00 & Sun 03:00 UTC | 20 min finals | district: DST_07 Grand Tournament Kitchen (`BLD_22`) | Qualify with Tournament Score ≥ `2,500 + 500 × tierNumber`; finals: 3 rounds (Mystery Box, Speed, Signature) judged in Forks by `NPC_016`, `NPC_009` and `NPC_029`; max 8 finalists per server (others spectate). | Finish all 3 rounds; best server score = champion. | P: ERM 8 · MS 30 · XPF 0.10 — S: ERM 16 · MS 60 · RT 3 · Capsule — T (server champion): + RT 8 · `FRN_910` first time · title "Tournament Champion"; global top 100: + RT 5 · title "Legendary Finalist" | server finals + cross-server leaderboard | 25 | One final per player per week. Story finale variant in §20. |
| `EVT_006` | Mutation Meteor Shower | H | rotation, ~1.5/day | 10 min | city-wide (unlocked surface districts) | Meteors every 4 s with a 4-s shadow telegraph; impact leaves a Meteor Chunk (carried item) and a 60-s mutagen puddle granting a random temporary cosmetic mutation; a meteor bonk = `STS_DIZZY` 1 s, no damage. | Personal: deliver 5 chunks to Collection Rockets (DST_01/02/03). Server: `40 + 10 × participants`. | ERM 5/10/14 · MS 15/30/45 · XPF 0.05/0.10/0.15 · S +1 Capsule · T `FRN_906` first time · global +10 MS | server + cross-server (global chunk count) | 3 | Science by `NPC_013`. Fallback: server target only. |
| `EVT_007` | Giant Rat King Attack | F | 6/day (every 4 h from 02:00) | 15 min | city-wide raid → `BLD_21` boss | Phase 1 rat squads steal crates on DST_01/DST_03; Phase 2 Event Chute to the Throne Room boss fight (§36.10 `BLD_21` rules); Phase 3 cheese party. | Server: defeat King Ratbeard (`NPC_020`) before 14:00. Personal: ≥ 2 crates recovered or ≥ 3 % of boss contribution. | ERM 6/12/18 · MS 20/40/60 · XPF 0.08/0.15/0.20 · RT 0/1/2 · S +1 Capsule · T `FRN_902` first time | server | 8 | Event Access to DST_09 at L8+. Detail §36.11.3. |
| `EVT_008` | Food Critic Convention | H | rotation, ~1.5/day | 12 min | district DST_07 + restaurants | 12 critics tour; 6 pop-up booths on the Neon Strip cook a Convention Menu for the panel; critic customers (`PER_004`) visit up to 2 times per owner-present restaurant; all dishes scored in Forks (`BLD_14` formula). | ≥ 9 Forks total; Top = average ≥ 4.5 Forks over ≥ 3 dishes. | ERM 4/10/14 · MS 10/25/40 · XPF 0.05/0.10/0.15 · S Gazette Feature (`EventMult ×1.10`, 60 min) · T `FRN_903` first time | server | 10 | Host `NPC_016`. |
| `EVT_009` | Blackout Night | H | rotation (weight 2), ~3/day | 12 min | city-wide | Forced night; neon and streetlamps off; free cosmetic flashlight; 4 generators to repair (DST_01/02/03/08); lost citizens to escort; restaurants turn candlelit (Atmosphere +10, `EventModifier` +5). | Server: restore all 4 generators. Personal: 1 generator stage or 3 escorts. | ERM 5/10/14 · MS 10/25/35 · XPF 0.06/0.12/0.16 · S +1 Capsule | server | 1 | **Only window for `MUT_040`** (`CSEC_01`). Detail §36.11.3. |
| `EVT_010` | Restaurant Repair Emergency | S | rotation, ~2/day | 8 min | restaurant + DST_01 street | "Burp-quake": `4 + floor(tierNumber / 2)` objects per owner-present restaurant drop to Cracked/Broken (never Destroyed); 6 soda pipes burst on Restaurant Row; event repairs cost 0 materials; neighbours get repair-only guest access. | Repair 6 objects (any restaurant) or 3 pipes. | ERM 4/8/12 · MS 10/20/30 · XPF 0.05/0.10/0.15 | server co-op | 3 | Unrepaired event damage auto-heals 15 min after. Staffed absent owners: Repair Techs handle it. |
| `EVT_011` | Upside-Down Day | M | rotation, ~1.5/day | 24 min | city-wide + restaurants | Signs and billboards render upside-down; crowds walk on their hands; `Workspace.Gravity` 196.2 → 140 (floaty jumps); "upside-down" order modifications (§6.18) ×3 and `RCP_BRG_013` demand ×3; menus stay readable (toggle "Flip my menu too" for fun). | Serve 5 upside-down orders correctly; flip 3 upside-down citizens back (interact). | ERM 3/6/9 · MS 8/15/25 · XPF 0.04/0.08/0.12 | solo | 1 | Gravity change excluded from Arena pits and boss arenas. |
| `EVT_012` | Pickle Rain | M | rotation, ~1.5/day | 24 min | city-wide + restaurants | Client pickle particles; ≤ 20 server Jumbo Pickles falling at once; pickle-related modifications ×2; `ING_PICKLE` netted cost −50 %; `RCP_BRG_006` demand ×2. | Catch 25 Jumbo Pickles (Umbrella Arm `MUT_157` catches count ×2). | ERM 2/5/8 · MS 5/12/20 · XPF 0.03/0.06/0.10 | solo | 1 | Ollie (`EMP_001`) gets an "Employee of the Day" sash. |
| `EVT_013` | Sewer Flood | H | rotation, ~1.5/day | 10 min | districts DST_04, DST_06, DST_08 (+ DST_09) | Lime-soda flood 3 studs deep in streets (slows to ×0.8 on foot, `STS_SOAKED` cosmetic); rubber-duck boats spawn on the surface; 6 giant noodle clogs block drains (pull with Grab & Throw `ABL_005` or tongue/tractor abilities); floating citizens to rescue. | Server: clear 6 drains. Personal: 1 drain + 2 rescues. | ERM 5/10/14 · MS 12/25/35 · XPF 0.06/0.12/0.16 · S +1 Capsule | server | 4 | Event Access to flooded zones of DST_04/06 at L4+; King Ratbeard cameo apologising. |
| `EVT_014` | Celebrity Chef Visit | H | rotation, ~1.5/day | 10 min | DST_01 + DST_07 + restaurants | The celebrity (`NPC_029` on even UTC days, `NPC_021` on odd) tours Restaurant Row and visits one owner-present restaurant every 2 min (weighted by ★); a visited restaurant gets a Celebrity Order (a known recipe + 3 modifications); city players queue for autographs (emote QTE). | Everyone: get an autograph. Visited owner: serve the Celebrity Order at S ≥ 90. | ERM 3/10/12 · MS 5/25/30 · RT 0/1/1 · S (visited, S ≥ 90) `EventMult ×1.25` for 30 min · T title "Celebrity Approved" | server | 5 | Baron Von Bistro sulks loudly outside the visited restaurant. |
| `EVT_015` | Tiny Day | M | rotation, ~1.5/day; never adjacent to `EVT_016` | 24 min | city-wide (interiors excluded) | All characters `Model:ScaleTo(0.5)` in city zones; interaction ranges unchanged; Giant Everyday Objects course appears in DST_08 (a sandwich mountain); 3 tiny doors hidden around the city. | Finish the sandwich course; find 3 tiny doors. | ERM 3/6/9 · MS 8/15/25 · XPF 0.04/0.08/0.12 | solo | 1 | Scale reverts inside interiors and Arena pits. |
| `EVT_016` | Giant Day | M | rotation, ~1.5/day; never adjacent to `EVT_015` | 24 min | city-wide (interiors excluded) | Characters `ScaleTo(1.6)` in city zones (doors are 12 studs); stomp camera shake (off under Reduced Motion); giant tasks: lift the stuck Snail Bus, re-hang fallen MORPH CITY letters, hand cats down from roofs. | Complete 3 giant tasks. | ERM 3/6/9 · MS 8/15/25 · XPF 0.04/0.08/0.12 | solo / server | 1 | Crowds look up in awe and take photos. |
| `EVT_017` | Polite Robot Uprising | H | rotation, ~1.5/day | 10 min | city-wide + restaurants | Robot citizens "rise up" demanding extreme politeness: compliment beams make players dance (`STS_CHARMED`, 1.5 s, cosmetic); micro-requests: walk a robot to a building, tighten a bolt (repair QTE), serve an Oil Smoothie (any drink); ROBOT-category customers ×3 in restaurants, patience ×1.5, tips ×1.2. | Personal: help 10 robots. Server: 40. | ERM 4/8/12 · MS 10/20/30 · XPF 0.05/0.10/0.14 | server | 1 | Ends in a chain of robots thanking each other. |
| `EVT_018` | Alien Tourist Season | M | rotation, ~1.5/day | 48 min (two city days) | city-wide + restaurants | Alien Tourist customers (`PER_029`) ×4; ALN dish demand ×2 for players who know them; Zorp (`NPC_027`) runs extra tour loops; tourists photograph players at photo spots (soft flash, disabled under Reduced Effects). | Pose for 5 tourist photos; serve 3 Alien Tourists. | ERM 3/6/9 · MS 8/16/24 · XPF 0.04/0.08/0.12 | solo | 5 | — |
| `EVT_019` | Hot Sauce Heatwave | M | rotation, ~1.5/day; never adjacent to `EVT_020` | 24 min | city-wide + restaurants | Orange heat shimmer; spicy-tag dishes demand ×2 and pay +15 %; 60 % of customers add a drink; heat stations `T_burn` −1 s [TUNABLE]; hydrants spray cooling mist; `EventModifier` +5 for spicy dishes served with a drink. | Serve 8 drinks or spicy dishes; cool 5 overheated citizens with a hydrant. | ERM 3/6/9 · MS 8/15/25 · XPF 0.04/0.08/0.12 | solo | 1 | Warning icon on heat stations while active. |
| `EVT_020` | Frozen Snap | M | rotation, ~1.5/day (weight ×2 in December) | 24 min | city-wide + restaurants | Snow and icy patches (Ice Skates `MUT_207` +20 % speed on ice); soups and hot drinks demand ×2, frozen desserts ×0.5; FREEZE processing −30 % time; snow-sculpting spots appear in parks. | Build 3 snowmorphs; serve 5 hot dishes. | ERM 3/6/9 · MS 8/15/25 · XPF 0.04/0.08/0.12 | solo | 1 | — |
| `EVT_021` | Morph Swap Hour | H | rotation, ~1.5/day | 10 min ("the Mayor rounded up") | city-wide (opt-in) | Every 3 min each opted-in player's *visual* morph swaps with another opted-in player's (stats and abilities stay your own; name tags stay visible); "Guess Who": find who wears your morph. | Find your morph-wearer twice; take a photo-spot pose together. | ERM 2/5/8 · MS 8/16/24 · S title "Identity Crisis" first time | server (opt-in) | 5 | < 2 opt-ins → NPC mirror clones instead. |
| `EVT_022` | Lost Pet Kraken | H | rotation, ~1.5/day | 12 min | city-wide hunt (3 districts) | Baby kraken "Squidge" is lost; ink trails, wet footprints and tentacle-shaped holes are clues; Curator Fossilbottom (`NPC_018`) reads clues; final hideout is a fountain or canal where it must be fed a seafood dish cooked at a pop-up stove. | Personal: 3 clues. Server: find and feed Squidge. | ERM 5/10/14 · MS 12/24/36 · XPF 0.05/0.10/0.15 · S `FRN_908` first time | server | 5 | Squidge squirts harmless ink (`STS_BLINDED` 1 s, cosmetic). |
| `EVT_023` | Delivery Frenzy | S | rotation, ~2/day | 8 min | city-wide + `BLD_15` | Delivery missions pay ×2 and spawn ×3; free rocket boots; absent owners with `ROLE_DELIVERY` staff get delivery revenue ×1.5. | Personal: 3 deliveries. Server: 20. | ERM 3/8/12 (+ mission pay ×2) · MS 8/18/28 | server | 8 | Host `NPC_017`. |
| `EVT_024` | Mystery Market Midnight Sale | F | daily 00:00 UTC | 30 min | district DST_09 (`BLD_13`) | Extra stock: last week's Legendary + 1 extra Epic (no price cuts on mutations); Market Chute gives L15+ Event Access; the Hagfish's Riddle Round (3 riddles). | Answer 3 riddles. | S: 15 MS + XPF 0.03 (once per day) · title "Night Owl Shopper" after 5 visits | solo | 15 | Host `NPC_015`. |
| `EVT_025` | Arena Brawl Bash | F | Fri–Sun 20:00, Sat–Sun 08:00 UTC | 15 min | district DST_10 (`BLD_08`) | Opt-in PvP king-of-the-hill with ring-outs (no persistent damage); parallel PvE "Bash the Bots" for non-PvP players; rules and balance per §21. | Win rounds or clear bot waves. | ERM 4/10/14 · MS 15/30/50 · RT 0/1/3 · T `FRN_904` first time | server (opt-in PvP or PvE) | 12 | Referee `NPC_008`; commentary `NPC_011`. |
| `EVT_026` | Health Inspector Sweep | S | rotation, ~2/day; never right after `EVT_010` | 8 min | restaurant | Inspector Grimewell (`NPC_022`) visits each owner-present restaurant once with a 60-s warning; grades A–F on cleanliness K, broken objects and fires; an F has **no** reputation penalty (only a comedic re-inspection). | Grade B or better. | ERM 2/6/10 · MS 8/16/25 · XPF 0.03/0.06/0.10 · A grade: `EventMult ×1.10` for 30 min · 10 A grades: title "Spotless" | solo / co-op | 5 | Staffed absent owners are inspected; cleaners count. |
| `EVT_027` | Downtown Dance-Off | H | rotation, ~1.5/day | 8 min | district DST_03 Gravy Plaza | DJ Morphenstein's (`NPC_024`) mobile stage; 4-lane rhythm rounds of 60 s; crowd joins; multi-leg morphs get extra visual flair (no score bonus). | ≥ 70 % accuracy; Top = highest score. | ERM 3/6/10 · MS 8/16/25 · S emote "Gravy Wiggle" first time · T title "Dance Floor Disaster (Complimentary)" | server | 1 | Inputs: keys / D-pad / 4 tap pads. |
| `EVT_028` | Neon Lights Festival | X | Jul 1–7 + monthly mini | 15 min editions | city-wide | Founders' Glow Week: fix broken neon tubes for Glow Sparks, carry lantern floats, light the MORPH CITY sign; week-long neon bunting overlay. | Edition: 10 sparks + carry a lantern to the sign. | ERM 5/10/14 · MS 12/24/36 · track: 4 stamps → 2 Capsules; 7 stamps → palette "Founders' Neon" + title "Glow Getter" | server | 1 | Detail §36.11.3. |
| `EVT_029` | Haunted Kitchen Night | X | October | 12 min editions | city-wide + restaurants | Friendly ghosts possess stations (tap "Boo-back" first); `PER_028` ×4; `RCP_SOP_006` demand ×3; Trick-or-Treat doors in DST_08; Ghost Chef cook-off. | Edition: calm 6 possessions or collect 20 candy. | ERM 5/10/14 · MS 12/24/36 · track 3/8/15 stamps → emote "Spooky Boo" / palette "Pumpkin Spice Neon" / title "Haunted Head Chef" + 2 Capsules | server / restaurant | 1 | Detail §36.11.3. |
| `EVT_030` | Snowmorph Holiday | X | December | 12 min editions | city-wide (`BLD_19` focus) | Snow overlay; build Snowmorphs from snow-part piles and vote; gift deliveries (Parcel Run ×1.5); hot dishes demand ×2. | Edition: build 1 Snowmorph + 2 gift deliveries. | ERM 5/10/14 · MS 12/24/36 · track 3/8/15 stamps → emote "Snow Angel Flail" / palette "Frosty Sprinkles" / title "Snowmorph Sculptor" + 2 Capsules | server | 1 | Detail §36.11.3. |
| `EVT_031` | Spring Sprout Bloom | X | April | 12 min editions | city-wide (`BLD_19` focus) | Plant, water and protect giant flowers; salads demand ×2; spring crates −20 % at `BLD_20`. | Edition: plant 2 seeds and keep them alive to bloom. | ERM 5/10/14 · MS 12/24/36 · track 3/8/15 stamps → emote "Petal Twirl" / palette "Spring Sprout" / title "Green Thumb(s)" + 2 Capsules | server | 1 | Detail §36.11.3. |
| `EVT_032` | Bug Swarm Brunch | M | rotation, ~1.5/day (starts with the city dawn) | 24 min | city-wide + restaurants | Swarms of candy-like friendly bugs drift through the streets; bug-tag dishes (`ING_BUG_CRUNCH`, `RCP_DES_010`) demand ×3; free bug nets (held tool); insect-category morphs get a cosmetic "swarm buddy". | Catch 20 bugs; serve 4 bug dishes. | ERM 3/6/9 · MS 8/15/25 · XPF 0.04/0.08/0.12 | solo | 1 | Host `NPC_023` buys your bug catch "for science (and brunch)". |

#### 36.11.3 Event detail blocks

Each block gives **Phases** (minute:second from T0), **Mechanics**, **Success / fail** and **Emergent fun**
(how the systems create funny moments without a script). Contribution points (CP) feed the P/S/T bands of
§18.8.4; Top = the 3 highest CP on the server unless stated.

##### EVT_001 — Giant Food Festival

- **Phases:** 0:00–0:30 *Setup* — Professor Saucington (`NPC_009`) rides an Assembly Crane into Gravy Plaza
  and giant stations unfold. 0:30–4:30 *Course 1: Giant Burger* (bun, 2 patties, cheese, lettuce).
  4:30–8:30 *Course 2: Giant Pizza* (dough, sauce, cheese, 3 toppings). 8:30–11:30 *Course 3: Giant Sundae*
  (3 scoops, syrup, cherry the size of a beach ball). 11:30–12:00 *Feast* — a 40-stud Festival Glutton eats it all.
- **Mechanics:** giant ingredients parachute from the Hot Dog Blimp into the plaza; each giant component needs
  a **team lift** (2 players within 6 studs of its handles, moving at 70 % speed — it counts as a full carry);
  cooking uses normal §5 timing with the Perfect window ×2; the crane accepts components only in recipe order.
  CP: carry 10, cook 15 (+10 for Perfect), assemble 10. Course quality = mean component grade.
- **Success / fail:** ≥ 2 courses served = team Success; personal ≥ 6 actions. MVP (highest CP) earns
  `FRN_901` the first time. < 2 courses: P only, and the Glutton eats the plates instead ("Delicious ceramics!").
- **Emergent fun:** two lifters pulling a 6-stud patty in opposite directions; a burned giant patty releases a
  plaza-sized cartoon soot puff for 3 s; players with Octopus Arms (`MUT_145`) become the most popular people in
  the city; the Glutton sneezes if the pizza has too much pepper and blows everyone's hats off (cosmetic).

##### EVT_002 — Mutation Parade

- **Phases:** 0:00–1:00 *Muster* on Restaurant Row: 8 float pads; stepping on one builds a float themed on
  the rider's dominant mutation category; Mayor Moosington (`NPC_002`) cuts a giant ribbon with his antlers.
  1:00–8:00 *March* along a 1,200-stud route (≈ 2.9 studs/s) through Downtown to the Neon Strip; Glamtrax
  (`NPC_005`) judges from a grandstand at Gravy Plaza. 8:00–10:00 *Finale* — votes tallied, confetti cannons.
- **Mechanics:** riders hit 4-lane rhythm prompts every 4 s (keys / D-pad / tap pads) to raise Crowd Cheer;
  a 10-s Pose Window at the grandstand doubles cheer for a held emote. Spectators (on foot) catch candy (cosmetic)
  thrown from floats and cast 3 emoji votes (no self-votes). CP: prompt hit 2, perfect 3, vote cast 5, candy 1.
- **Success / fail:** riders ≥ 70 % accuracy; spectators 10 candies + 3 votes. The rider with the most votes
  gets `FRN_907` (first time) and the "Parade Grand Marshal" title. The parade cannot fail; it can only be
  under-attended (P only).
- **Emergent fun:** Giraffe Neck riders bonk every bunting line; crowd citizens faint dramatically at
  Legendary parts; an NPC float driven by Baron Von Bistro (`NPC_003`) keeps trying to cut into the line and is
  honked at by the Snail Bus.

##### EVT_003 — Citywide Restaurant Rush

- **Phases:** T−1 Anchor Andy: "Scientists confirm: everyone is hungry." 0:00–8:00 *Rush*. 8:00 *Tally* —
  global counter shown on every Mega-Screen.
- **Mechanics:** participating restaurants run at `EventMult ×2.0` with patience ×1.15 so the extra volume is
  fair; every 4th order is a gold Rush Ticket (tip ×1.5). Co-op guests' serves count toward the owner's
  objective and their own CP. Servers push dish deltas every 15 s into the `evtgoal` buckets (§18.8.3).
- **Success / fail:** personal `6 + 2 × tierNumber` dishes at S ≥ 70; global goal 30 dishes per participant
  across all servers (+1 Capsule once per day, +25 % MB). Missing the personal goal leaves P (if ≥ 60 s active).
- **Emergent fun:** the volume naturally triggers more anger escalations and food-throwing chain reactions;
  Ollie (`EMP_001`) puts pickles on 5 % of everything at twice the speed; friends pile into each other's
  kitchens because guests count.

##### EVT_004 — Angry Customer Invasion

- **Phases:** 0:00–0:30 *Rumble* — Sergeant Rhonda (`NPC_026`) radios a warning, windows rattle. 0:30–5:30
  *Waves* — 3 waves 100 s apart. 5:30–6:00 *Aftermath* — surviving invaders bow in unison (`ANM_053`) and pay
  the 40 % Apology Payment (§C11.4).
- **Mechanics:** each wave spawns `2 + floor(tierNumber / 2)` invaders at anger 30 with BRAWLER, THROWER and
  CHARGER styles weighted 40/40/20; escalation rolls ×1.5; `ABL_006` Calm Down! cooldown −50 %; serving an
  invader any Perfect dish calms it instantly. All damage is Event Damage (repair materials free for 15 min;
  anything unrepaired auto-heals 15 min after the event). Security Guards work at ×1.5 effectiveness.
- **Success / fail:** calm or serve `8 + tierNumber` invaders while average durability stays ≥ 50 %. Below
  either threshold: P only. Being KO'd is Seeing Stars only (no losses, §C12.1).
- **Emergent fun:** thrown food constantly misses the player and hits other invaders, who then fight each other
  (the canon chain reaction); a Perfect sundae lands mid-brawl and a CHARGER stops dead to eat it.

##### EVT_005 — Legendary Chef Tournament

- **Qualifying (Mon 00:00 – Sat 18:00 UTC):** Tournament Score = sum of the best 50 dish scores served in your
  restaurant this week, `dishScore = Q × (1 + 0.2 × D) × 100` (D = difficulty 1–5; max 10,000). Qualify at
  `2,500 + 500 × tierNumber` [TUNABLE].
- **Finals phases (20 min, Grand Tournament Kitchen behind `BLD_22`):** 0:00–1:00 *Entrance* — Chef Supreme
  Omnivora (`NPC_029`) introduces the judges (`NPC_016`, `NPC_009`, herself). 1:00–7:00 *R1 Mystery Box* — the
  same 3 random ingredients for everyone; cook any known dish that uses ≥ 2 of them. 7:00–12:00 *R2 Speed* — as
  many copies of a given simple dish as possible at ≥ GOOD. 12:00–19:00 *R3 Signature* — your highest-difficulty
  known dish. 19:00–20:00 *Ceremony*.
- **Mechanics:** each judge scores Forks (`BLD_14` formula); R2 scores 1 Fork per 2 GOOD+ dishes (max 5 per
  judge). Total = sum over rounds and judges (max 45). Ties → R3 score, then earlier finish.
- **Success / fail:** finishing all 3 rounds = S; server champion = T (`FRN_910` first time). Global
  leaderboard (`tourney:<w>` SortedMap) closes Sun 04:00 UTC; top 100 get +5 RT and "Legendary Finalist".
  Leaving a final early = P if ≥ 60 s were played.
- **Emergent fun:** Baron Von Bistro competes as an NPC finalist on every server; when he loses he throws his hat
  into the crowd and anyone can wear it for 60 s; Omnivora's tentacle arms taste four dishes at once.

##### EVT_006 — Mutation Meteor Shower

- **Phases:** 0:00–0:30 *Purple Sky* — Dr. Splice (`NPC_013`): "Completely harmless. Mostly." 0:30–8:30
  *Shower*. 8:30–10:00 *Launch* — Collection Rockets in DST_01, DST_02 and DST_03 blast off with the haul.
- **Mechanics:** a meteor lands every 4 s per server at a random sidewalk point in unlocked surface districts,
  telegraphed by a 4-s growing shadow (radius 6 studs). Impact: one Meteor Chunk (carried item, §C3 capacity)
  and a 60-s mutagen puddle that gives whoever steps in a random temporary cosmetic mutation (client visual,
  60 s, like the MUT-dish rule of §C10). A direct hit = `STS_DIZZY` 1 s with cartoon stars, no damage.
  Magnet Pull (`ABL_033`) can yank chunks from 20 studs. CP: chunk delivered 10.
- **Success / fail:** personal 5 chunks; server `40 + 10 × participants`; global chunk goal adds +10 MS for
  everyone. Most chunks on the server → `FRN_906` first time. Missing the server goal: S still possible
  personally (team bonus Capsule lost).
- **Emergent fun:** crowds of players who all look ridiculous from overlapping puddle mutations; carry-capacity
  morphs (Octopus Arm, Monkey Tail, Extra Arm Backpack) become chunk taxis; a meteor lands in the Sauce Fountain
  and splashes everyone nearby.

##### EVT_007 — Giant Rat King Attack

- **Phases:** 0:00–6:00 *Raid* — 6 rat squads (4 rats each, server proxies) raid Restaurant Row and Downtown
  carrying stolen ingredient crates. 6:00–14:00 *Throne Room* — Event Chutes open at Gravy Plaza and Restaurant
  Row; boss fight against King Ratbeard (`NPC_020`) per §36.10 `BLD_21`. 14:00–15:00 *Cheese Party* — the
  Dizzy king apologises and returns the crates.
- **Mechanics:** any hit makes a carrier rat drop its crate; returning a crate to Bolt Butterworth's truck = 10 CP.
  Rats only shove (`STS_KNOCKDOWN` 0.5 s). Boss stages, HP formula and minion caps are in `BLD_21`; boss CP =
  damage dealt + 2 × healing/de-pinning assists. Boss join closes at < 25 % HP.
- **Success / fail:** king defeated before 14:00 = team Success; personal ≥ 2 crates or ≥ 3 % of total boss CP.
  Top 3 CP → `FRN_902` first time. Timer expires → the king escapes on a rubber duck, laughing; P only ("He'll
  be back in 4 hours!").
- **Emergent fun:** crown boomerangs knock his own minions into the soda; a Frog Tongue (`MUT_061`) yank steals
  the crown, the king chases that player (aggro switch) and the thief wears the crown for 30 s; Rex Rumbleton
  (`NPC_011`) commentates every pratfall.

##### EVT_008 — Food Critic Convention

- **Phases:** 0:00–1:00 *Arrival* — 12 critics parade out of `BLD_14`. 1:00–11:00 *Tasting* — 6 pop-up booths on
  the Neon Strip, plus critic visits to restaurants. 11:00–12:00 *Awards* — Madame Fourchette (`NPC_016`) names
  Best in Show.
- **Mechanics:** each booth is a compact station set (cutting board, grill, fryer, assembly) running the
  Convention Menu (simple dishes ≤ L20 so every qualified player can cook); one player per booth at a time,
  4-min booth limit. Critic customers (`PER_004`) visit each owner-present restaurant at most twice; their
  satisfaction S converts to Forks with the `BLD_14` table. CP: Fork 5.
- **Success / fail:** ≥ 9 Forks = S (Gazette Feature); average ≥ 4.5 Forks over ≥ 3 dishes = T (`FRN_903`
  first time). Fewer: P.
- **Emergent fun:** critics' giraffe necks crossing over the booths to steal bites; a critic dramatically
  swoons at a 5-Fork dish and has to be fanned by two junior critics.

##### EVT_009 — Blackout Night

- **Phases:** 0:00–0:30 *Flicker* — lights stutter; Anchor Andy reads the news by candlelight. 0:30–11:00
  *Dark*. 11:00–12:00 *Lights On* — fireworks if all generators run; otherwise the dawn simply arrives.
- **Mechanics:** night lighting forced; neon and streetlamp creatures switch off — except the ERROR billboard
  in Sauce Drip Alley, which flickers (`CPROP_04`; 3 interactions → `MUT_040`, `CSEC_01`). Every player gets a
  cosmetic flashlight (client `SpotLight`, range 40). 4 generators (DST_01, DST_02, DST_03, DST_08) each need
  3 repair-minigame stages (2 players = double speed). Lost citizens with glowing eyes wander; walking within
  6 studs makes one follow you to the Lantern Shelter in Gravy Plaza. Players with glow-tag parts emit a
  20-stud light aura. Restaurants: candlelit dining (Atmosphere +10, max 100; `EventModifier` +5).
  CP: generator stage 15, escort 8.
- **Success / fail:** all 4 generators = team S; personal 1 stage or 3 escorts. Otherwise P.
- **Emergent fun:** eight flashlights pointing at each other in a dark plaza; firefly-eyed morphs (`MUT_083`)
  become living lamps that everyone follows; a lost citizen follows the wrong player into a restaurant and
  orders soup.

##### EVT_010 — Restaurant Repair Emergency

- **Phases:** 0:00 *Burp-quake* — the Sewers burp; screen shake (none under Reduced Motion). 0:00–7:30
  *Repair*. 7:30–8:00 *Inspection* — Wrenchy (`NPC_010`) awards the "Golden Wrench" title tag to the top fixer for
  the rest of the city day (cosmetic).
- **Mechanics:** each owner-present restaurant gets `4 + floor(tierNumber / 2)` objects set to Cracked or
  Broken (never Destroyed) flagged as Event Damage (0 material cost). 6 soda pipes burst on Restaurant Row (each a
  repair minigame). Any participant may enter any participating restaurant on the server with repair-only
  guest access (no cooking, moving or selling; §C22 E12 Co-op Insurance applies). Bolt Butterworth (`NPC_006`)
  hands out loaner tools that repair 25 % faster during the event. CP: object 10, pipe 15.
- **Success / fail:** 6 objects or 3 pipes = S; top 3 CP = T. Unrepaired event damage auto-heals 15 min after.
- **Emergent fun:** neighbours sprinting through each other's dining rooms; a burst pipe launching someone onto
  the Ketchup Water Tower; Sous-Chef Sniffles (`NPC_028`) secretly helping fix the player's tables while the
  Baron isn't looking.

##### EVT_028 — Neon Lights Festival (Founders' Glow Week, July)

- **Season:** July 1–7 editions every unanchored headline hour divisible by 3; monthly mini-edition on the first
  Saturday at 21:00 UTC. All week the city wears neon bunting and the MORPH CITY sign cycles colors.
- **Phases (15 min):** 0:00–8:00 *Spark Hunt* — 30 broken neon tubes across unlocked surface districts; a 3-tap
  timing minigame fixes one and yields a Glow Spark (event score item). 8:00–13:00 *Lantern Parade* — carry a
  lantern float along the Neon Strip; sparks carried make it brighter. 13:00–15:00 *Light-Up* — sparks are fed
  into the MORPH CITY sign; fireworks. Day 7's last edition ends with a 3-min particle light show spelling the
  (filtered) display names of the week's top contributors.
- **Success / fail:** 10 sparks + one lantern delivered = S (1 stamp; max 2 stamps per day). Track: 4 stamps → 2
  Capsules; 7 stamps → palette "Founders' Neon" + title "Glow Getter".
- **Emergent fun:** uneven spark feeding makes each sign letter a different color, spelling the city name in a
  clashing rainbow; repaired tubes sometimes buzz into the wrong word ("MORPH PITY") until the next fix.

##### EVT_029 — Haunted Kitchen Night (October)

- **Season:** Oct 1–31; city overlay of cute pumpkins, cobwebs and friendly bedsheet ghosts; the night phase gets
  a purple tint. Oct 31's 23:00 UTC edition lasts 20 min and grants double stamps.
- **Phases (12 min):** 0:00–10:00 *Haunting* — in participating restaurants a random station is "possessed" every
  45 s for 10 s (wiggles, ghost face); interacting first needs a "Boo-back" tap that calms it. Haunted Toasters
  (`PER_028`) ×4; Pumpkin Screamer Soup (`RCP_SOP_006`) demand ×3; spooky-themed dishes get `EventModifier` +5.
  In the city: Trick-or-Treat doors in DST_08 give candy (score item); a Ghost Chef challenges players to a 2-min
  burger cook-off at Gravy Plaza. 10:00–12:00 *Midnight Bell* — ghosts dance and candy is tallied.
- **Success / fail:** calm 6 possessions or collect 20 candy = S (1 stamp). Track: 3 stamps → emote "Spooky Boo";
  8 → palette "Pumpkin Spice Neon"; 15 → title "Haunted Head Chef" + 2 Capsules.
- **Kid-safety:** no jump scares or sudden loud sounds; ghosts are smiling sheets; Reduced Motion removes wiggles.
- **Emergent fun:** possessed blenders "singing" in harmony when two are haunted at once; the Ghost Chef burns
  its own patty and blames the player.

##### EVT_030 — Snowmorph Holiday (December)

- **Season:** Dec 1–31 (Dec 24–26 every unanchored even hour); snow on roofs, string lights, the MORPH CITY sign
  wears a scarf; `EVT_020` Frozen Snap weight ×2 in the modifier deck.
- **Phases (12 min):** 0:00–6:00 *Snow Sculpt* — piles shaped like part groups (Head, Torso, Arms, Legs, Tail,
  Extras) appear in `BLD_19`; players carry snow parts to 6 plinths and assemble a Snowmorph (client-built white
  morph visual from the chosen part families); everyone votes. 6:00–11:00 *Gift Run* — gift parcels from
  `BLD_15` to Residential addresses (Parcel Run rules, ×1.5 ERM); restaurants see hot dishes and drinks
  demand ×2. 11:00–12:00 *Snow Globe* — winning Snowmorph revealed under a falling-snow globe effect.
- **Success / fail:** contribute to 1 Snowmorph + 2 gift deliveries = S (1 stamp). Track: 3 → emote "Snow Angel
  Flail"; 8 → palette "Frosty Sprinkles"; 15 → title "Snowmorph Sculptor" + 2 Capsules.
- **Emergent fun:** snowmorphs with three heads and no legs; two teams fighting (politely) over the last tail
  pile; a Snowmorph that looks suspiciously like Mayor Moosington wins every time.

##### EVT_031 — Spring Sprout Bloom (April)

- **Season:** Apr 1–30; blossoms, pastel neon and cute bees; Farmer Fungus (`NPC_023`) gives free seeds.
- **Phases (12 min):** 0:00–3:00 *Plant* — 12 planter beds in `BLD_19` plus 2 per unlocked surface district.
  3:00–9:00 *Water & Protect* — water with hydrant hoses (`CPROP_10`) or Trunk Spray (`ABL_028`, counts ×2); bonk
  away Munch Bugs (cute caterpillars) that nibble sprouts. 9:00–12:00 *Bloom* — sprouts become giant flowers whose
  size depends on care; flowers launch players upward like trampolines and burst into petals.
- **Mechanics:** a sprout needs 3 waterings and no more than 2 nibbles to bloom; restaurants see salads demand
  ×2; `BLD_20` spring crates −20 %.
- **Success / fail:** plant 2 seeds that bloom = S (1 stamp). Track: 3 → emote "Petal Twirl"; 8 → palette "Spring
  Sprout"; 15 → title "Green Thumb(s)" + 2 Capsules.
- **Emergent fun:** flower-launch chains across the park; Munch Bugs that get bonked roll into the fountain and
  float there happily; Venus Flytrap Head players (`MUT_035`) are mistaken for flowers and get watered.

#### 36.11.4 Compatibility rules

- One H/F/X, one S and one M run at most simultaneously (§18.8.1).
- Scale modifiers (`EVT_015`, `EVT_016`) and Gravity changes (`EVT_011`) never apply inside restaurant interiors,
  Arena pits (`BLD_08`) or the `BLD_21` boss arena.
- `EVT_015` ↔ `EVT_016` and `EVT_019` ↔ `EVT_020` are never in consecutive modifier windows (deck swap rule).
- `EVT_004` never follows an `EVT_007`/`EVT_025` slot in the same hour; `EVT_026` never follows `EVT_010` in the
  same hour.
- Restaurant `EventMult` values stack multiplicatively but are clamped to ×0.5…×2.5; `EventModifier` sums are
  clamped to −15…+15 (§C11.3).
- `EVT_009` forces night for its duration; a concurrent modifier keeps its rules but uses night lighting.

#### 36.11.5 Acceptance Criteria

- **AC-18-50:** All 32 events `EVT_001`–`EVT_032` are schedulable and runnable from a debug console, and each
  starts, resolves and pays rewards without errors.
- **AC-18-51:** Over a simulated 7 days, each weight-1 H-pool event appears 7–15 times (`EVT_009` 13–29 times),
  each weight-1 S-pool event 10–18 times (`EVT_003` 22–34), and no event occupies two consecutive slots of its pool.
- **AC-18-52:** Fixed anchors start within ±2 s of their UTC times on every server, including `EVT_007` six times
  per day and `EVT_024` daily at 00:00.
- **AC-18-53:** During seasonal months the seasonal event runs in every unanchored headline hour divisible by 3,
  and never outside its month (or Jul 1–7 / first-Saturday mini for `EVT_028`).
- **AC-18-54:** Every event's MB reward equals the ERM formula for the player's tier, and no reward outside the
  §C17.4 vocabulary is ever granted.
- **AC-18-55:** Each trophy `FRN_901`–`FRN_910` that an event grants is granted at most once per player; repeats
  convert to exactly 100 MS.
- **AC-18-56:** `EVT_004` never runs for a player with "Peaceful Restaurant" enabled, and Event Damage from
  `EVT_004`/`EVT_010` is fully healed 15 min after the event if unrepaired.
- **AC-18-57:** `EVT_007` boss Huff Points match the `BLD_21` formula for 1, 4 and 8 participants, and an
  under-L20 player at L8+ can reach the Throne Room only during the event.
- **AC-18-58:** The ERROR billboard accepts interactions only during `EVT_009`, and its 3-interaction counter
  resets when the instance ends.
- **AC-18-59:** `EVT_021` never changes stats, abilities or name tags, and only swaps between opted-in players.
- **AC-18-60:** Global goals (`EVT_001`, `EVT_003`, `EVT_006`) aggregate contributions from ≥ 2 test servers within
  30 s, and fall back to server-local targets when MemoryStore is disabled.
- **AC-18-61:** Kid-safety review passes for all event text and visuals (Haunted Kitchen Night has no jump scares;
  all defeats show as Dizzy/Seeing Stars).

# Build the Biggest Raft (ra8): the build plan, and what was built

The master plan is [MASTER_PLAN.md](MASTER_PLAN.md). This is how it became a game, section by section, and
where each part lives in `games/ra8 - The Endless Voyage/`.

## The shape of it

* **Six plots on a ring** round the middle of a 1600-stud ocean (`shared/World/OceanLayout`). Every player who
  joins gets a plot and their raft is built there from their save (`RaftService`). The raft never moves: the
  current carries debris through the plot, and when a voyage arrives the destination rises out of the water
  beside the plot (`IslandBuilder`, `IslandService`) and sinks back when you sail home (`VoyageService`).
  Everyone on the plot (the owner and visitors) shares the voyage.
* **The raft is a 14 x 14 grid of 6-stud tiles on two decks** (`Data/Pieces`, `RaftModels`): structure (floor
  tiles, plank decks, stairs, railings, ladders, walls, roofs), six stations, systems (storage, nets, sails, the
  engine, the navigation table, the crow's nest, the anchor, spikes, the harpoon turret, the bunk, planters,
  lamps, the aquarium, the trophy stand, the helm) and decoration. Tiers (`Formulas.raftTier`) are earned by what
  the raft can do, exactly as §5.4 lays them out, and each tier opens more pieces, more room and further waters.
* **Everything persists** in the profile (`PlayerDataService`): the raft piece by piece, the bag, the charts, the
  blueprints, research, the journal, achievements, colours, records. What you carry while away from your dock is
  this voyage's finds: go down away from home and half of it floats off as a lost bag (`PlayerService`,
  `InventoryService.LoseFinds`); sail home and it's safe.

## Section by section

| Master plan | Built | Where |
|---|---|---|
| §3 the loop: collect → build → upgrade → sail → explore → discover → return → improve | debris with the current, rods and nets, the build grid, tiers, voyages with events, islands and wrecks, the journal, home | `OceanService`, `RaftService`, `VoyageService`, `IslandService`, `ProgressService` |
| §4 the first five minutes | six pieces within reach at 0:00; reel in 5 with the rod → a tile → the workbench → craft → the crate at 2:20 with the net's blueprint and an axe → the net → the helm and the first choice → Palm Key → home; returning players skip it | `TutorialService`, `TutorialController` |
| §5 the raft | the grid, two decks, the six tiers and their needs, personal ownership (visitors can't build), colours and flags | `RaftService`, `Data/Pieces`, `Formulas` |
| §6 persistent vs expedition | the profile keeps everything; the lost bag is the risk; no permadeath, no raft loss | `PlayerDataService`, `PlayerService` |
| §7 collecting | 5 debris kinds by weight, supply crates and bottles, 5 rods with different reach, pull, double-catch and rare odds, nets that hold or empty into a storage box, fishing with a bite window, the economy's tiers from common to legendary | `OceanService`, `Data/Items`, `LootService` |
| §8 crafting & research | six stations with readable have/need costs, blueprints found in crates, islands, wrecks and research milestones, the Research Station's points, the Decorative Workshop's dyes | `CraftService`, `Data/Recipes`, `Data/Progression.RESEARCH` |
| §9 exploration | nine destinations (two wrecks, six islands, the Trench), each with a landmark and a story, gathering with the right tool, containers, two environmental puzzles, creatures with reasons, the discovery journal | `Data/Voyages`, `IslandBuilder`, `IslandService`, `CreatureService` |
| §10 navigation & travel | the helm and the map, charts found five different ways, the crow's nest, nine kinds of event under way (lanes, drops, bottles, dolphins, storms, a shadow, sharks, serpents, whirlpools), travel time by distance and speed | `VoyageService`, `WeatherService` |
| the creatures | crabs, thief gulls, lurkers, lava beetles, wolf packs, the Ruin Guardian, sharks and serpents that bite tiles (spikes punish them), the Leviathan with its surface/dive cycle and enrage | `CreatureService`, `CombatService`, `Rigs` |
| progression | XP and levels, titles, 26 achievements, 6 leaderboards (friends first), records, colours earned not bought | `ProgressService`, `LeaderboardService` |
| friends | rafts you can row over to (friends / anyone / nobody), friends' servers, private oceans | `VisitService`, `JoinService` |
| the studio's usual | analytics (the funnel, snapshots, the live dashboard row), the Discord game log, "Do you like the game?", notifications, the anti-cheat | `AnalyticsService`, `GameLogService`, `FeedbackService`, `AntiCheatService` |

## What's deliberately not in v1

* Robux products: none at launch. Dyes, flags and titles are earned.
* Raft-vs-raft anything: your raft is yours.
* A hunger meter: food heals and buffs, nothing nags.
* Rest skipping the night: the server's night is everyone's; the bunk heals you and sets your spawn.

## Numbers to watch (Constants.lua)

* `DEBRIS_EVERY` 3.2 s, `DEBRIS_MAX` 12: the first minute's pace. `GUIDE_START_DEBRIS` 6 pieces within reach at 0:00.
* `VOYAGE_SECONDS_PER_DISTANCE` 32: Palm Key is 32 s away at paddle speed, 16 with a sail, 8-14 with an engine.
* `STORM_TILE_DAMAGE` 22 every 5 s for 26 s: a storm costs a tile or two without railings, nothing much with an anchor.
* `DANGER_BY_TIER` {1, 1, 2, 3, 5, 5}: a Floating Fortress can face the Trench; the tooth it brings back makes the Legendary Vessel.
* `XP.cap` 4000 a day.

## Round 2: after the first playtest

What the first play found, and what changed:

* **Frame rate with things in the water.** The server moved every piece of debris every tick, and every part of every
  piece crossed the network ten times a second. Now the server only decides where a piece is (a start position, a
  time and a velocity on the server's clock, and who is pulling it in: attributes on the model, `OceanService`),
  and each client draws the drift itself every frame from those numbers (`DebrisController`). Nothing about the
  drift crosses the network; far pieces are placed every sixth frame.
* **Islands in a ring.** The far islands were twelve humps evenly round a ring. Now nine of them are scattered at
  random bearings and distances out to the edge of a wider ocean (2400 studs), with a peak and snow on the big ones,
  green humps with trees, and a sandy atoll with palms (`OceanLayout.HORIZON`, `OceanBuilder`), always loaded
  (persistent) and streamed to 1024 studs; and a voyage's island rises at a different spot in the plot's island zone
  each time (`OceanLayout.islandSpot`), so what you see from the raft is never a neat circle.
* **Sky and shading.** A bigger sun and moon, more glare and haze by day, soft shadows, less sky fill so shapes keep
  their shading, a touch of depth of field on the far isles (off in lite mode), livelier water.
* **The bag.** Tab (or I) opens the bag; the Roblox player list no longer steals Tab. Drag an item to another slot
  (the hotbar on screen too) or tap one slot then another; hover shows it. A details card: the item's picture, its
  rarity and kind, what it does, its numbers (reach, pull, bites, power, damage, heal, research), USE / HOLD / TO BAG /
  DROP. Every slot, hotbar cell, crafting row and build row shows the thing itself in a little 3D view
  (`UI/Icons`, a ViewportFrame of `ItemModels` / `RaftModels`), and every one of the 53 items got a real model
  (rods with a reel and a bobber, bevelled axes, a coral, a gear, a pearl on its shell, a compass with
  a needle...). 2D icon art for all of them is in `other/ra8/items/` with an upload script (`tools/icons/`): once
  uploaded, the UI uses it (`Data/IconIds`).
* **The guide's finger.** Besides the arrow and the glow in the world (which now pulse, the supply crate too), a
  pulsing ring and a hand sit on the exact button to press next for whatever is open: BUILD, the piece's PLACE, the
  hotbar slot with the rod, ACT on touch, the BAG, the crate's slot and OPEN, MAKE at the bench, SAIL, HOME
  (`UI/Glow`, `TutorialController.uiTarget`).
* **Animations.** Sustained poses everyone sees (the character's `Pose` attribute, `PlayerService:SetPose`): the rod
  held out in both hands while you wait, the tip jerking on a bite, the left hand cranking the reel; hand over hand
  cranking the reel while a piece you cast at comes in. The rod's line runs from its tip to the bobber, the bobber dips and
  ripples on a bite, the fish flies up out of the water to you when you reel, and the rope stays on the piece as it
  comes in (`AnimController`, `FxController`).
* **Aiming.** The cursor picks the nearest thing it is over, not the one nearest the ray's line behind it.

## Round 3: the second playtest

What the second play found, and what changed:

* **No hook.** Hooks are gone (items, recipes, blueprints, icons). The rod does it all: CAST at a piece of debris and
  the line flies out to it and reels it in (the reel cranks, the piece skims to you); CAST at open water and you
  fish. Five rods: the Fishing Rod you start with, the Iron Rod (workbench), the Deep Rod, the Long Rod and the
  Salvage Rod (research blueprints), each with a reach, a pull speed, a chance of a double catch and of rarer finds
  (`Data/Items`, `OceanService:Cast`, `ActionService`). The guide's crate gives the net's blueprint and an axe.
* **The baseplate at the water line.** Roblox's template leaves a Baseplate whose top is exactly at the water level,
  so jumping off the raft landed you on an invisible floor. `OceanBuilder` removes any Baseplate or SpawnLocation at
  startup; the ocean is terrain water, so you swim in it: a splash going in, ripples while you're in, and the HUD
  tells you to swim back and jump up (`FxController`, `HudController`).
* **The raft floats.** Every floor tile has two half-sunk pontoons under it with lashings, and a skirt below the deck
  so you never see the underside (`RaftModels.pontoons`). Each client bobs and rolls the whole raft on the swell
  (`RaftMotionController`: one BulkMoveTo a frame, tripled in a storm, with a lean forward while sailing), so the
  deck is never a flat plank on a flat sea.
* **The boat moves.** Sailing felt like standing still because only the water moved. Now, while sailing, the far
  islands slide past (`SailingController`), the raft leaves a foaming wake astern and spray at the bow, the
  destination rises on the horizon ahead and comes closer with the trip's progress, and the debris streams past
  three times as fast (`OceanService`).
* **Quick build.** A QUICK button (F on PC, DPad down on a gamepad, held on a phone): the piece your raft needs next
  goes where you look, one every half second while you hold it, with the same ghost and rules as the build panel.
  The server lists what to build next (`RaftService:Recommend`: the next tier's missing stations, tiles while the
  tier wants more, stairs when it wants a second deck, a few comforts, more room); the client takes the first the
  bag can pay for (`Formulas.recommended`), and looking at the water beside the raft while a station is recommended
  lays tiles instead (`BuildController.quickStart/quickPlace`). The guide's finger points at QUICK when it would
  build the step's piece.
* **Tab and the bag.** Tab (or I) opened the bag but also gave it the gamepad's selection cursor, which trapped
  Escape and the arrow keys. The cursor is only set for a gamepad now and cleared when a panel closes
  (`PanelController`).
* **The torch at spawn.** The glowing post at each plot was the plot's marker. It is a channel buoy now: a striped
  float with a bell, a ring and a numbered flag (`OceanBuilder`).
* **Docking and moving the boat.** As in Raft: without an anchor the current takes the raft home 2:30 after you land
  at an island (a warning 30 s before: get aboard); with an Anchor (tier 3, metal and rope) the raft stays docked as
  long as you like, and storms do half the damage (`VoyageService`, `Constants.ISLAND_STAY_*`). The MAP shows the
  stay clock or the anchor, and the drive ladder (paddling ×1, a Sail ×2, an Engine ×4, with what each needs); the
  HUD's clock shows the countdown.
* **The lag in the water.** The drift has been drawn client-side since round 2 (each piece from a start, a time and a
  velocity; nothing crosses the network while it drifts), so a build with round 2 in it moves the pieces smoothly;
  the server's tick only decides, it never moves a model.

## Round 4: the guide never lets go

* **The guide never ends and can't be dismissed.** SKIP is gone. After the nine steps the card says NEXT, forever
  (`TutorialService:Goal`): reel in at sea; explore, then sail home on an island; hold your rod when your hands are
  empty (a HOLD MY ROD button on the card does it, from the bag too); fix what's broken (or make a hammer first);
  build the helm; then the raft's next piece, or where its blueprint comes from, or a new place to sail.
* **Blueprint, then materials, then the build.** A build step or goal never asks for something you can't build yet:
  without the blueprint it sends you for it (the supply crate comes at once, then OPEN it, then LEARN), without the
  materials it says exactly what's missing and where it comes from and points at the debris, and the moment you can
  pay for it, it points at QUICK or BUILD. QUICK only ever offers a piece you can pay for right now.
* **The rod.** Tools always get a hotbar slot (a full hotbar moves a non-tool into the bag). Your last rod can't be
  dropped, and a player with no rod at all gets a spare one on the raft. The rod now rises from the hand at 40° with
  the bobber hanging straight down, instead of pointing at the deck.
* **BUILD panel.** A category rail on the left (STRUCTURE, STATIONS, SYSTEMS, DECORATION) lights the section you're
  scrolled to and jumps to one on a tap; the panel opens scrolled to the piece the guide wants, marked ⭐ NEXT.
* **Seeing what's coming.** Debris appears 110 studs upstream instead of 46 (the lane starts full, up to 22 pieces
  afloat), and the fair-weather haze is about half as thick, so you see pieces coming a long way off.

## Round 5: plain words, a world that moves, and two ways to play

* **Explained like you're 3.** The word "tier" is gone from everything the player reads. The raft has a name and a
  size ("Survival Raft, size 2 of 6"), and every message says exactly what to do: a full raft says "Your raft is
  full! Build a Workbench 🛠️ and a Storage Box 📦 and it grows into a Survival Raft with room for 24 floors"; a
  locked piece says "Not yet! Build ... first"; the HUD says "⬆️ To grow: ..." (`Formulas.growText`, `lockedText`,
  `fullText`). Tiles are "floors".
* **No more "sailing home".** The raft lives at its spot out at sea. Leaving an island says "⛵ LEAVING PALM KEY",
  the button is LEAVE ISLAND, and you end up "BACK OUT AT SEA". The island's terrain is now cleared out to its widest
  layer (some islands had a beach shelf left behind).
* **The world always moves.** The far islands drift past downstream all the time (slowly at your spot, fast while
  sailing), wrapping round and never passing through the raft; the destination comes in from upstream; and the
  island you leave stays where it was as a copy that slides away behind you and sinks below the horizon
  (`SailingController`).
* **The helm has a sail.** The Helm is a steering wheel with a little mast and sail behind it, so it's clear what
  moves the raft; the old Sail is the Big Sail (twice as fast).
* **Debris looks like it floats.** Every piece was rebuilt with more detail (a log with cut ends and nailed planks, a
  hooped barrel, a coil of rope on a float, a tied canvas bundle, corrugated metal, a flagged crate with a light, a
  bottle with a note, a buckled bag), sits half under the water, and has a broken ring of foam round it.
* **Start menu: MY WORLD or PUBLIC OCEAN.** A public server shows the menu over the live ocean (`MenuController`,
  `ModeService`). MY WORLD sends you to your own reserved server, the same one every time, and INVITE FRIENDS sends
  friends straight there. PUBLIC OCEAN is an ordinary server with other players nearby, each on their own raft.
  Your raft is saved to you, so it's the same raft in either. In Studio the menu just closes and you play there.
  (A shared online ship everyone builds was tried and dropped: no goal, a reset nobody wants, and griefing.)

## Round 6: visiting, no size limit, nets while you're away, pinned pieces

* **Visiting like Clash of Clans.** 👀 VISIT lists the players in this server, your friends and the biggest rafts
  on the leaderboard. Pick one and you see a copy of their raft (live if they're here, from their save if they're
  offline) on its own patch of sea, with a camera that turns round it (drag, zoom) and a BACK button. It exists
  only on your screen, so you can't take, build or break anything, and you never sail up to anyone. The owner gets
  a "👀 ... is looking at your raft!" toast, and visits count for achievements (`VisitService`, `VisitController`).
  Rowing over to other rafts and the who-may-visit setting are gone.
* **Rafts as big as you like.** The tile cap per raft size is gone (the raft still grows up by building what it
  asks for, which unlocks pieces). The grid reaches 82 × 82 floors round the plot's centre, the plots sit much
  further apart (a ring of 950 studs in a 4400-stud ocean), and islands rise clear of a big raft's edge.
* **Seeing what's coming.** Debris appears 260 studs upstream (the lane starts full, up to 30 pieces), and every
  piece far from you wears a little round badge with what it is (📦 a crate, 🍾 a bottle...), so you spot it from a
  long way off (`DebrisController`).
* **Nets work while you're away.** When you come back, each net has caught one thing per 90 seconds you were gone,
  up to what it holds (6, the salvage net 10), with a callout saying how much; with a storage box it goes straight
  into your bag (the box also empties what a net was holding). Nets keep their catch in your save.
* **Pieces in the hotbar.** Every piece you can build has a 📌 button in BUILD: it puts that piece in your hotbar.
  Hold the slot and the piece's ghost follows where you look; ACT builds it, again and again, until you pick
  another slot. Dropping the shortcut just takes it off the hotbar.

## Round 7: your world, friends, and the rod fixed for real

* **The rod in your hand.** The server put the rod in your hand once, the moment your character appeared; in a real
  game the avatar's hands often arrive a moment later, so the rod never showed. Now it goes into the hand whenever
  it isn't there (the hand arriving, an avatar swapping its hands, every couple of seconds as a safety net), and
  ACT with empty hands simply grabs your rod.
* **The menu is about your world.** No public ocean. Every time you arrive: ▶ PLAY (from a public server it takes
  you to your own world), 💌 INVITE FRIENDS TO SEE YOUR RAFT, 👀 VISIT RAFTS, and 🔄 RESET MY WORLD (it asks first;
  your raft goes back to the driftwood platform and your bag to just the rod and the hammer; level, journal, blueprints and
  achievements stay; not during a trip). ⚙️ MORE reopens it.
* **Inviting friends, everywhere.** A pulsing 💌 INVITE FRIENDS button is always on screen. Invites name your world,
  so friends sail straight into it, and when a friend arrives you both get a supply crate (once a day per friend).
  When there's something to show (the raft grows up, every 10 floors, back from a trip) a card asks "Show it to a
  friend?" (at most every 8 minutes, 4 a session), and once the raft has grown the NEXT guide suggests it for a
  minute every ten (`ModeService`, `MenuController`).

## Round 8: quick wins

* **A net in the first minute.** The guide goes cast → **Surface Net** → tile → workbench → crate → helm → island →
  home. Three catches and the next thing is a net: it needs no blueprint and no edge (it goes on any floor; things
  drift under the raft and its mesh hangs below the deck), and it catches anything within `NET_RANGE` (24 studs). There
  is no "craft something" step and no "make a hammer" goal: everyone starts with a hammer for repairs.
* **Double hauls on a starter raft.** While the raft is tier 1 every catch gives `EARLY_BOOST` (2x), with a ⭐x2 on the
  popup and a sparkle where it came out of the water.
* **The rod.** It points up out of the fist, and casting is a two-handed wind-up, whip and follow-through. The line
  hides while the bobber flies, then draws as a sagging curve. Casting goes as far as you aim (up to the rod's
  range: 45, 55, 75, 90 studs), and as it reels back it hooks **everything** within `SWEEP_RADIUS` (10 studs) of the
  line. No careful aiming.
* **The crate you can't miss.** When the guide asks for it, a supply crate drifts in right beside the raft
  (`GUIDE_CRATE_DISTANCE`, 16 studs), slowly, under a tall gold pillar of light with a red "📦 CAST HERE!" sign. If one
  gets away, another comes a few seconds later, until you have one. Inside: an axe, a spear, 10 wood and 4 rope.
* **Ready for the island.** Setting sail somewhere with animals hands you a spear if you have no weapon, and fills
  your health.
* **Graphics.** Floating pieces lose their hovering badges (only the guide's crate is marked). The guide's arrow is a
  real arrow: a round shaft and a cone head. The axe, the pickaxe, the hammer, the spears and the harpoons are
  rebuilt with their heads across the handle and proper points. Wood shows as 🟫 boards, not a tree. Dolphins are
  real dolphins that leap and splash, and the shark, the gull and the crab are rounded, with fins, stalked eyes and
  pincers.

## Round 9: the rod, for real this time

* **Why the rod pointed down.** The arm poses bent the shoulder and elbow through each Motor6D's C0, every frame.
  On the avatars Roblox spawns today that does nothing: the platform puts every Motor6D's C0 back to what its rig
  attachments say, and with the Avatar Joint Upgrade the joints aren't Motor6Ds at all but AnimationConstraints. So
  the arm hung at the side, the rod (welded to point up only when the forearm was raised) pointed at the deck, and
  the cast swing never played. The test mock had none of this, so the tests passed.
* **The fix.** AnimController now writes each joint's Transform in RunService.PreSimulation, after the Animator,
  which is how Roblox asks for procedural poses. It works on both Motor6D and AnimationConstraint joints, and never
  touches C0. Rods get their own poses with the wrist: held low with the rod angled up, an overarm cast (back over
  the shoulder, then the whip out level over the water), low over the water while fishing, up while reeling. The rod
  also leaves the fist 40° up, so even with no arm animation at all it points up and out.
* **The line.** A held rod's little line hangs straight down from its tip with the bobber, whatever the rod's
  angle, and swings a little as it moves (FxController). The bobber leaves the rod at the whip of the cast, and the
  piece starts coming in when it lands (`HOOK_FLIGHT` 0.6 s).
* **ACT can't go dead.** Picking a hotbar slot ends building. Laying floors ends by itself when the bag can't pay for
  another. An ACT that can't place says why ("Tap DONE to stop building"). A fishing state that never came back
  stops blocking ACT. Casting with a line already out recasts, and the caster always gets their own cast's effect.
* **The guide's arrow.** A flat game arrow (a shaft and a triangle head, bright yellow with a thick dark outline
  and a white shine) that turns its face to the camera and bobs over the target, instead of a glowing pillar.
* **The mock now behaves like Roblox here.** Characters are R15 rigs joined by Motor6Ds, or by AnimationConstraints
  (`Engine.avatarJoints`). Every step the Animator writes each joint's Transform and the platform resets each
  Motor6D's C0, then PreSimulation fires and the joints are solved. `tests/Rod.spec.luau` measures where the rod's
  tip really is against the hand, for both kinds of joint, and `tools/gameplay/hold_check.luau` renders it.

## Round 10: the line, the arrow, and islands you can see

* **Why the line went nowhere and the arrow missed.** The world streams in (StreamingEnabled). A floating piece is a
  model, and its parts can arrive after the model itself. Only the clients move pieces as they drift, so a part that
  arrived late showed up where the piece was made, not where it had drifted to. The piece's pivot is what the cast,
  the line and the arrow aim at, and it became the middle of whatever parts had arrived, often empty water. So the
  bobber flew off to nothing and the arrow hung beside the piece.
* **The fix.** Every floating piece now streams in whole and stays loaded (a Persistent model), with its pivot pinned to
  where it was made, so every client draws it in one piece in the right place. Tapping or clicking a piece casts at
  that piece. The guide's arrow picks the nearest piece a few times a second and follows it every frame; over the
  guide's crate it follows the crate itself.
* **A line you can see.** Every line is thicker (0.11 studs) and the bobber is bigger.
* **Islands from far away.** The far islands are rebuilt in much more detail:
  * palms with curved trunks, fronds and coconuts
  * round leafy trees on the hills, pines up the mountains
  * boulders, wet sand and surf
  * atolls with a turquoise lagoon
  * snow on the tall peaks

  The islands you sail to load their trees, rocks, wrecks, huts, chests and landmark whole and keep them loaded, so
  they show from the raft. Bushes, plants and reeds still load as you come near. The streaming radius is doubled
  (minimum 256, target 2048), so the land itself shows from further away.
* **The mock** follows Roblox's rule for a model's pivot: its PrimaryPart, else its WorldPivot, else the middle of its
  parts. New checks: a piece streams in whole with its pivot where it was made, and the arrow points right at the
  piece.

## Round 11: fixes from the live test

* **Costs say what you have.** A cost chip reads 12/4 when you have 12, not 4/4.
* **Text at every screen size.** Popup titles asked for no outline but got a thick dark one anyway (a bug in
  `Theme.title`), so on smaller screens dark letters in dark outlines ran into blobs. Now they get none, and every
  outline is about a tenth of the height its letters are really drawn at (`Theme.outline`).
* **Nothing overlaps.** The screens are laid out for a canvas at least 1240 across (`Theme.MIN_WIDTH`): on a squarer
  screen the UI is a little smaller instead of piled up. While a card asks something ("Do you like the game?"), the
  guide's NEXT card steps aside and alerts and callouts come as one row of toasts at the bottom (`UI/Layout`). Toasts
  keep to two rows and unlock cards to three, the oldest making room. A test measures every widget on a phone, a
  tablet, a small window and a big screen.
* **Research shows the way.** Tapping RESEARCH away from the Research Station closes the bag, points the guide's
  arrow at your station (it glows) and opens its panel when you get there; with no station it says how to get one
  (`CraftService:ShowStation`, the "Point" remote). Making something away from its station does the same.
* **REMOVE, for the whole cost.** X, the gamepad's d-pad left, or the ♻️ button on your raft: the piece you point at
  glows red, the bar says what you'll get back, and ACT takes it off. A tile takes what's on it and on its edges
  with it (everything refunded, a net's catch too); the raft still can't be split in two.
* **Islands come to you.** A voyage's island rises right off the raft's outer side, its beach `ISLAND_GAP` (3 studs)
  from the deck's edge whatever the raft's size (`Formulas.raftReach`, `OceanLayout.islandBeside`); the destination
  you watch on the way lands on the same spot. While an island is there, pieces drift past the raft's inner side.
* **Eight to a server.** Eight rafts on the ring (`MAX_PLAYERS`): set the place's Server Size to 8 and Server Fill to
  keep 2 slots, so matchmaking stops at 6 and friends can join.
* **The Discord log.** Every entry in the studio's shared game-logs channel starts with "ra8 · ", the chat too
  (escaped: no pings, no markdown). A server without the secret looks again every minute, and any failure (no
  secret, HTTP off, the domain, a wrong key) is said in the server's log, F9 (`GameKey`). Setup: [README](README.md).
* **Where we lose them.** Every analytics event now carries where the player was: the guide's step, what they were
  doing (casting, building, sailing...), where they stood, the voyage, the raft's tiles and tier, their level. The
  leave says the step and what they were doing last.
* **Everything in Discord.** The same events also go to the channel, one line each: the time into the session, who,
  what happened, and that context. They're sent as "ra8 · 📜 Activity" entries every 15 seconds
  (`GAME_LOG_ACTIVITY_SECONDS`), in as few messages as fit. Performance and focus events are left out.
  `GAME_LOG_ACTIVITY = false` turns the feed off if the shared channel gets too busy.
* **Nets are tiles of their own.** A net is a tile at the raft's edge, like a floor (BUILD, then tap a spot next to
  the raft). It's a frame round open water, with the net hanging below in a sagging bowl. What it catches floats in
  the bowl where you can see it (up to six pieces), and its prompt says how full it is.
  * A storage box empties a net into your bag when it's full, or 45 seconds after its first catch
    (`NET_BOX_EVERY`), so the catch always shows for a while.
  * Nothing can be built on a net or over it. Nets only go on the first deck, and they don't count as floor tiles.
  * A net in an old save sat on a floor tile. It moves to a free spot beside the raft, with its catch. With no free
    spot, its cost and catch go back to the bag.
* **Run.** Hold Shift, click the left stick (on until you stop), or tap RUN (on until you tap it again) to run 9
  studs a second faster (`SPRINT_BONUS`).
  * The camera widens a little while you run, unless screen shake is off or reduced motion is on.
  * You lean into it, with forearms raised like a sprinter, on top of Roblox's own run.
  * You kick up sand on islands.
  * Your speed changes the moment you press. The server matches it (`PlayerService:Sprint`), and the anti-cheat
    always allows a run.
* **JUMP on phones.** The big ACT button sat on top of Roblox's own jump button, so phones had no way to jump. Phones
  now get a JUMP button above ACT (hold it to keep jumping), with RUN beside it. Roblox's own jump button is hidden.
  On a phone held sideways, unlock cards keep to two rows so they stay clear of both buttons.
* **A new name and new store art.** The game is now **Build the Biggest Raft**: the menu's title and badge, the
  docs and the tools (the folder and the place file keep the working title). The achievement for 50 voyages is
  Endless Voyager. The art is in two sets with different jobs:
  * **Ads** ([`ads/`](ads/README.md)): ten dark, quiet pictures for Ads Manager, with no words at all. Each one is a
    survivor and one strange thing: an eye in the water, a shadow under the raft, a wall of storm, a ship frozen in
    the ice, Mist Hollow's empty huts, the watching totems, a fortress in the fog, a bottle in a storm, a fin in the
    fog, a raft city's lights on the horizon.
  * **The game's page** ([`thumbnails/`](thumbnails/README.md)): six bright thumbnails with the name and one line
    each: START SMALL. GO BIG!, CATCH WHAT FLOATS BY, BUILD WITH FRIENDS, SAIL TO NEW ISLANDS, FIND TREASURE, FACE
    THE LEVIATHAN. The README has a description in the same plain words.
  * **A new icon**: a grinning survivor holding up a hammer in front of a huge raft, with three alternates.

  All of them were made from fresh renders of the current game ([renders](screenshots/README.md)).
  `title_art.py` letters the name in one line or two (`--title`, `--title-size`, `--at`).

## Tests

`tools/run_tests.sh`: the data and formulas (`tests/Formulas.spec.luau`, 66 checks: tiers, speeds, loot odds,
every builder builds, every icon is an emoji Roblox draws), the server (`tests/ServerSmoke.spec.luau`, 298 checks:
the first five minutes, nets, tiers, storms, fishing, research, the wreck and the lost bag, sharks and the serpent,
the turret and the Leviathan, removing pieces, running, visiting, friends, boards, leaving and coming back, feedback,
the anti-cheat, analytics and the Discord log; also run without DataStores, 298 checks), the client
(`tests/ClientSmoke.spec.luau`, 223 checks: the real UI driving the real server on a phone-sized screen, and nothing
overlapping on four screen sizes) and the rod in the hand (`tests/Rod.spec.luau`, 10 checks, run once with Motor6D
joints and once with AnimationConstraints).

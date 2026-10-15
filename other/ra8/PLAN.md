# The Endless Voyage (ra8): the build plan, and what was built

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

## Tests

`tools/run_tests.sh`: the data and formulas (`tests/Formulas.spec.luau`, 61 checks: tiers, speeds, loot odds,
every builder builds, every icon is an emoji Roblox draws), the server (`tests/ServerSmoke.spec.luau`, 245 checks:
the first five minutes, tiers, storms, fishing, research, the wreck and the lost bag, sharks and the serpent, the
turret and the Leviathan, visiting, friends, boards, leaving and coming back, feedback, the anti-cheat, analytics;
also run without DataStores, 247 checks) and the client (`tests/ClientSmoke.spec.luau`, 136 checks: the real UI driving the
real server on a phone-sized screen).

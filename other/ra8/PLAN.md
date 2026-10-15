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
| §3 the loop: collect → build → upgrade → sail → explore → discover → return → improve | debris with the current, hooks and nets, the build grid, tiers, voyages with events, islands and wrecks, the journal, home | `OceanService`, `RaftService`, `VoyageService`, `IslandService`, `ProgressService` |
| §4 the first five minutes | six pieces within reach at 0:00; hook 5 → a tile → the workbench → craft → the crate at 2:20 with the net's blueprint and a rod → the net → the helm and the first choice → Palm Key → home; returning players skip it | `TutorialService`, `TutorialController` |
| §5 the raft | the grid, two decks, the six tiers and their needs, personal ownership (visitors can't build), colours and flags | `RaftService`, `Data/Pieces`, `Formulas` |
| §6 persistent vs expedition | the profile keeps everything; the lost bag is the risk; no permadeath, no raft loss | `PlayerDataService`, `PlayerService` |
| §7 collecting | 5 debris kinds by weight, supply crates and bottles, 4 hooks and 2 rods with different reach and odds, nets that hold or empty into a storage box, fishing with a bite window, the economy's tiers from common to legendary | `OceanService`, `Data/Items`, `LootService` |
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
  (hooks with a J, rods with a reel and a bobber, bevelled axes, a coral, a gear, a pearl on its shell, a compass with
  a needle...). 2D icon art for all of them is in `other/ra8/items/` with an upload script (`tools/icons/`): once
  uploaded, the UI uses it (`Data/IconIds`).
* **The guide's finger.** Besides the arrow and the glow in the world (which now pulse, the supply crate too), a
  pulsing ring and a hand sit on the exact button to press next for whatever is open: BUILD, the piece's PLACE, the
  hotbar slot with the hook, ACT on touch, the BAG, the crate's slot and OPEN, MAKE at the bench, SAIL, HOME
  (`UI/Glow`, `TutorialController.uiTarget`).
* **Animations.** Sustained poses everyone sees (the character's `Pose` attribute, `PlayerService:SetPose`): the rod
  held out in both hands while you wait, the tip jerking on a bite, the left hand cranking the reel; hand over hand
  on the rope while a hooked piece comes in. The rod's line runs from its tip to the bobber, the bobber dips and
  ripples on a bite, the fish flies up out of the water to you when you reel, and the rope stays on the piece as it
  comes in (`AnimController`, `FxController`).
* **Aiming.** The cursor picks the nearest thing it is over, not the one nearest the ray's line behind it.

## Tests

`tools/run_tests.sh`: the data and formulas (`tests/Formulas.spec.luau`, 59 checks: tiers, speeds, loot odds,
every builder builds, every icon is an emoji Roblox draws), the server (`tests/ServerSmoke.spec.luau`, 231 checks:
the first five minutes, tiers, storms, fishing, research, the wreck and the lost bag, sharks and the serpent, the
turret and the Leviathan, visiting, friends, boards, leaving and coming back, feedback, the anti-cheat, analytics;
also run without DataStores) and the client (`tests/ClientSmoke.spec.luau`, 115 checks: the real UI driving the
real server on a phone-sized screen).

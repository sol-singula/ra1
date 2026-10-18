# ra10 · the build plan and what was built

## Phase A (October 2026): the scaffold

`games/ra10 - Farm to Fleet/` from the studio's engine, as ra9 had it: the service loader (dependency-sorted
Init/Start, per-service error isolation; a service may set `Disabled`), the typed remotes with per-player rate
limits (`Net`, with the farm's events: Farm, Buy, Sell, Animal, Order, Guide, Daily, Drive; Plot, Guide, Animal,
Orders, Vehicles, Daily, Away), the session-locked saves (`PlayerDataService`, with the farm's profile: Cash, Gems,
XP and level, stage, owned upgrades, soil timers, storage, animals, orders, the guide's place, the 7-day calendar,
the away clock), the client boot and its Store, the UI theme, the mock engine and the Luau test runner.
`Constants` carries the palette (farm, crops, industrial) and the six plot colours.

Tests: `BootSmoke` (the server and the client boot, a player's farm profile loads, Ready, leaving releases it).

## Phase B: the street and stage 1 (the Shack)

* **The street** (`World/PlotLayout`, `World/FarmBuilder.world`): the main road along X (asphalt, yellow centre
  dashes, white edges, verges, lamps), six plots of 160 x 220 meadow, three each side, a 4-stud white fence apart,
  open to the road; trees and low hills round it. Each plot has its own frame (local -Z is the road), so one layout
  serves both sides; the land for every later stage is reserved from the start.
* **A plot** (`PlotService`): the first free one on join, the owner's name on its sign; the shack (board siding,
  trims, a pitched roof with a ridge in the plot's colour, porch, door, window with shutters, flower box, chimney),
  the farm stand with crates of produce and its SELL pad, a mailbox, a dirt track, three buy-pads. Leaving frees the
  plot; the save rebuilds it.
* **Farming** (`FarmService`, `Data/Crops`): raised soil tiles with boards and furrows; one big action button does
  everything in reach (HARVEST ripe, else PLANT empty, else WATER dry); timers run on the server clock (they keep
  going while away); four growth phases per crop, golden crops (a roll at planting, 10x value); the basket's limit;
  selling by standing on the stand's pad.
* **Upgrades** (`UpgradeService`, `Data/Upgrades`): sixteen stage-1 buys on the pads in order (soil to 12 tiles,
  the well, the wheelbarrow, the fence, sprinklers, the stand's awning, the scarecrow, the barn deed into stage 2),
  each built on the plot; a pad shows the next one locked behind a level; empty pads disappear.
* **Levels** (`Data/Levels`, `EconomyService`): XP from harvests, sales, buys and the guide; level 2 after about ten
  strawberries unlocks carrots (and the crop picker).
* **The guide** (`GuideService`, `Data/Guide`, `GuideController`): twenty scripted steps for chapter 1 with a card,
  a bobbing gold arrow over the target and a dotted path on the ground; generated goals after the chapter.
* **The HUD**: Cash, Gems, the basket, the level bar, toasts and "+N".

Tests: `FarmSmoke` (60 checks: the street, the first minute through the real button with the first harvest under
10 s and the first sale under 30 s, the guide's steps and targets, the well, levels, carrots, the picker, the whole
stage bought in order, sprinklers, the basket, leaving and coming back with crops still growing, a neighbour's
plot). Renders: `other/ra10/screenshots/` (`tools/gameplay/farm.luau`).

## Phase C: stage 2 (the Farm) and the animals

* **Stage 2** (`Data/Upgrades`, `World/FarmBuilder`): thirteen buys after the barn deed: the Big Barn (gambrel
  roof, braced doors, hayloft, cupola and weathervane; it takes the place of its staked-out site), three fields (to
  39 tiles, a rail fence round them), the tractor (every 8 s it harvests what's ripe and plants again), the conveyor
  belt (round the plot's west edge to the stand; every 12 s it sells the basket), the grain silo, the windmill (it
  turns), four pens, and the deed to the packing shed (stage 3).
* **Animals** (`AnimalService`, `Data/Animals`, `AnimalController`): chicken, pig, sheep and cow in pens behind the
  fields (coop on stilts, sty with mud, sheep shelter with hay, cow shed; fence, trough, feeder, a pad at the gate).
  They arrive hungry; the pad feeds them (5 crops from the basket) and collects their products (eggs, truffles,
  wool, milk) into the basket to sell. Boosts per level: chickens +3% growth, pigs +3% vegetable prices, sheep
  +3% machine speed, cows +3% fruit growth and a little golden luck; hungry animals give half. Levels 1-10 for Cash
  (1.8x a level): more animals in the pen, a ribbon at 5, a golden bell at 10. The pen's panel shows level, boost,
  fed/hungry, what's waiting, FEED and UPGRADE. The animals wander their pens on each client (the server only
  places them); goat and horse (orders, walking speed) are ready for later stages.
* **The guide's chapter 2**: eighteen more steps (barn, field, corn, coop, feed, eggs, sell eggs, tractor, field,
  conveyor, upgrade the chickens, pigs, silo, field, sheep, windmill, cows, the shed's deed), with "pen:" targets.

Tests: `AnimalSmoke` (61 checks: the barn replacing its site, fields to 39 tiles, the coop and the guide to it,
feeding from the basket, eggs collected and sold, every boost, levels and herd sizes, max level and its look, the
tractor and the conveyor working alone, client-side wandering inside the pen, the windmill, stage 3, animals kept
across a rejoin).

## Next: Phase D

Stage 3 (the packing shed, the box line, orders and the order board, the first delivery van, daily contracts).

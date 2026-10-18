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

## Phase D: stage 3 (the Packing Shed), orders, vans, daily contracts

* **Stage 3** (`Data/Upgrades`, `World/ShedBuilder`): ten buys after the shed's deed: The Packing Shed (sage-green
  corrugated siding, white trim, a roll-up loading door with hazard stripes and bumpers, a side door over the PACK
  ORDERS pad, the packing table under lights, pallets and crates inside; it takes the place of its site), the Paved
  Yard (asphalt, van bays, lamps, planters), the Delivery Van, the Big Order Board (3 orders; bulbs round it), the
  Box Line (a belt into the shed with boxes riding it and a box folder), the Sorting Machine (+15% on orders), the
  Loading Dock (trips 25% quicker), the Pallet Wrapper (+15% more), a Second Van, and the warehouse's deed (stage 4).
* **Orders** (`OrderService`, `Data/Orders`): the order board holds 2 orders (3 with the big board). Each customer
  asks for 1 to 3 crops the farm has (quick growers, or an animal's product, at most 24), pays 3x the stand, and has
  10 minutes. Standing on PACK ORDERS packs the basket into the open orders; the box line does it every 6 s. Once
  the shed stands, the conveyor leaves what the orders still need in the basket. A packed order leaves on the
  buyer's pickup (40 s, one at a time) or the vans (20 s; two at once with the second van; 15 s with the dock) and
  pays when the vehicle gets back. One order in six is BIG: twice the crops, 2.5x the pay, 2 Gems. An order that
  runs out, or is skipped, gives its boxes back. The board in the world shows each order: customer, one line per
  crop, the pay or what it's doing.
* **Vehicles** (`World/Trips`, `VehicleController`): the server marks a trip on the vehicle (start, length, kind);
  every client drives it along the plan for that kind: the van backs out, goes round to the loading door, backs up
  to it, loads, drives off down the road, comes back up the far lane and parks; the pickup comes up the far lane,
  noses in, loads, backs out and drives away. Neighbours see each other's trucks. A trip under way while the player
  is gone pays when they're back.
* **Daily contracts**: three a UTC day, picked by the day and the player from eight kinds (ship orders, harvest,
  sell, plant, feed, pack, eggs, a BIG order), measured from the day's start; each pays Cash and a Gem, all three
  add 3 Gems.
* **The orders panel** (`OrderController`): on the right once the shed stands: each order with who, what's packed
  of what, the time left or what it's doing, the pay (and Gems), a skip; then today's contracts and when they renew.
  The crop picker moved to a two-row strip at the bottom centre and shows only by the soil.
* **The guide's chapter 3**: sixteen steps (the shed, pack, a whole order, watch it ship, yard, van, three orders,
  the big board, a contract, box line, sorter, dock, ten orders, wrapper, second van, the warehouse's deed), with
  "pack", "board" and "door" targets.

Tests: `OrderSmoke` (89 checks: order making and pay, BIG odds, contracts by day, the van's and pickup's trips; the
shed replacing its site on the industry side, the board and the panel, the conveyor holding back, packing at the
pad, the pickup's trip on the client and the payout, running out and skipping, the van, three orders, one van at
a time then two, the box line, the pay boosts, the dock's shorter trip, a BIG order's Gems, contracts paying, all
three, a new day, every stage-3 upgrade covered by the guide, a trip paying across a rejoin, and the profile
saving). 220 checks in all (`tools/run_tests.sh`).

## Next: Phase E

Stage 4, built round the master plan's five pillars (§13): the warehouse rises bay by bay with racks that show
every pallet the farm holds, forklifts on painted lanes (client-animated, an optional ride), and the four-station
flow (Grow, Pack, Store, Ship) with the Operations board, so the slowest station glows red and the pads offer a fix
for each. Then F (docks, semis, Special Orders), G (coming back, the street board, visiting, friends), H (prestige:
Franchise and the second region), I (money, art, publish).

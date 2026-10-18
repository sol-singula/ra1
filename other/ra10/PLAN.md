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

## Phase E: stage 4 (the Warehouse), the four-station flow and bottlenecks

Built round the master plan's pillars of scale (§13.1) and bottlenecks (§13.2).

* **The warehouse** (`World/WarehouseBuilder`): a 64 x 60 steel building (ribbed walls, the farm's colour band,
  clerestory windows, a roof with skylights and units) that rises slice by slice: the front slice (packing lines,
  the staging floor, the office, a people door lined up with a new back door through the shed, a roll-up truck
  door) and the first bay come with The Warehouse; three more bays (Warehouse Bay 2-4) replace a steel skeleton on
  its slab. Out front: four station pads and a big **Operations screen**; an overhead conveyor from the shed.
  Behind: a truck lane up the plot's east edge and a lot for the box trucks. The sorter, the wrapper and the
  second van moved to keep the lane clear.
* **Everything you can count:** rack rows (8, 24 pallets each) with a real pallet on a slot for every pallet the farm
  holds, pallets on the staging floor, crates waiting at the lines, packing lines (4, then robot arms), forklifts
  (5; a charging bay with the fast ones), box trucks (4, longer with bigger trucks), pivot irrigation over the
  fields, fertilizer tanks, greenhouses. Every stage-4 buy builds something (a test checks it).
* **The flow** (`Data/Flow`, `WarehouseService`): once it stands, the conveyor brings the basket in (leaving what
  orders need) instead of selling it; the lines pack crates into pallets (packing stops while 6 wait on the floor);
  each forklift racks a pallet every 30 s (faster with fast forklifts) while there's a free slot; each truck takes up
  to 4 pallets (6 with bigger trucks) when it can fill up or after 15 s, makes its trip and pays 2x the stand a
  pallet (more with the sorter and wrapper) when it's back. Every rate is Cash a minute, so the four compare.
* **Bottlenecks:** the slowest station (or Store, when the racks are full) is red on the Operations screen, the
  HUD's Operations strip (`OpsController`) and its own station pad. The four pads sell one fix each from their
  track (grow 3, pack 3, store 11, ship 3), so buying the red one moves the jam to the next station; it counts as a
  fix and says so. A bought-out red track tells you what to do instead (plant pricier crops).
* **Vehicles and forklifts on the client** (`World/Trips` "truck", `WarehouseController`): trucks back out of the
  lot, down the lane, back up to the truck door, load, drive off and come back to their spot; forklifts loop from
  the staging floor down the cross aisle to a rack, lift the pallet to its level and come back, only while their
  warehouse is busy. The roof lifts off while the camera's inside.
* **The guide's chapter 4**: build it, the first pallet, racked, shipped, fix a bottleneck, fix three; then the guide
  always points at the bottleneck's pad ("BOTTLENECK: PACK! Buy Packing Line 3 at the PACK pad"), or the next fix,
  then the hub's deed (stage 5).
* **Operation Size** (`Flow.size`) on the HUD strip: one number for how big the operation is.

Tests: `WarehouseSmoke` (74 checks: the flow's rates and bottleneck rules, every track, every stage-4 buy building
something, the truck's trip; the warehouse replacing its site with its skeleton, open slices, roof, pads, screen,
racks, staging, forklift and truck; the conveyor's intake, packing, racking, every pallet shown, a truck's load,
trip, door and pay; the guide through chapter 4 to the red pad; forklifts working on the client; the roof lifting;
three fixes; full racks; every track bought out (8 rows, 5 forklifts, 4 long trucks); stock and a trip across a
rejoin; the hub's deed; no failed saves or ticks). 295 checks in all.

## Phase E+: the hub takes over the front, and detail everywhere

The owner's direction: "the warehouse should eventually take over the spot of the market... really massive... nice
detail all over and in it so it looks to have all the pipes/things it needs."

* **The detail layer** (`WarehouseBuilder` `detail`/`outside`): every slice of the warehouse (and the front hall, and
  the market) gets red sprinkler mains with their heads, a ventilation duct with diffusers and hangers, a yellow
  cable tray, two rows of high-bay lights, roof joists, columns with yellow guards, electrical panels with conduit,
  extinguishers; outside, downspouts, wall lights, a pipe rack (water, gas, air) down the east wall, rooftop HVAC
  units with fans and exhaust stacks.
* **Stage 5, the Distribution Hub** (`World/HubBuilder`, `Data/Upgrades`), on the stand's pads after the hub's deed:
  * *Back Dock Doors* (needs the last bay): four dock doors on the back wall (seals, levelers, bumpers, red/green
    lights, canopies, numbers), the truck court paved behind, light poles, a guard booth; the box trucks move to the
    court in line with their docks and back straight up to them (`World/Trips` "truckBack"); trips 15% quicker.
  * *The Front Hall*: the warehouse grows forward to the shed's front line. The shed, the sorter, the wrapper, the
    box line and the lit order board come down (`replaces` takes a list now); the old front wall too. The hall's
    façade keeps the van's loading door, the PACK ORDERS pad and the order board (now on the wall) where they were,
    under a "FARM TO FLEET DISTRIBUTION" band; inside, a sorting line into a big sorter, packing tables, the wrapper,
    an overhead conveyor loop, a mezzanine office with stairs, compressors and air tanks, walkways, and the
    Operations screen hanging over the station pads. Packing +25%.
  * *Control Tower*: an HQ tower on the hall's corner (glass cab, sign, antenna, red beacon, dish). Orders and pallets
    +10%.
  * *Solar Roof*: panels on every roof there is. Packing +25%.
  * *The Market Hall*: a red market hall along the road where the farm stand stood (glass storefront, striped
    awning, gable roof and cupola, "FARM TO FLEET MARKET"); the stand comes down, the sell pad becomes its checkout
    and the buy-pads move in to its upgrades desk; produce stalls, fridge cases, the barn's conveyor arriving through
    a hatch. The stand pays +50%.
* Roofs carry the box they cover, so the hall's and the market's lift off too when the camera's inside; the order
  board and PACK ORDERS pad are found wherever they stand; the guide suggests a hub expansion when it's affordable.

Tests: `HubSmoke` (45 checks: the dock gate, the flow effects, the truck's back route; the deed; the docks and the
trucks moved; a load backing up to its dock on the client; the hall swallowing the shed and its machines and the
old front wall, one pad and one board and one screen, packing from the hall's pad, everything inside the hall's
footprint; the tower; the solar panels; the market replacing the stand with the pads moved and selling at its
checkout; the size and the detail; roofs lifting in the hall and the market; all of it the same after a rejoin).
340 checks in all.

## Phase F: semis on the shared road, and Special Orders

* **Semis** (`Data/Flow`, `WarehouseService`, `World/Trips` "semi", `HubBuilder`): the SHIP station's track carries
  on into stage 5 with the First and Second Semi (they need the back docks; the pad says so). The back wall now has
  six dock positions: box trucks use 1-4, each semi its own (5, 6), built with its SEMIS sign. A semi isn't parked on
  the plot: it comes in from the shared road when there's half a load (or after 30 s), up the lane, along the court,
  backs its trailer up to its dock, takes up to 24 pallets and leaves the same way, paying when it's gone. Every
  client drives it, so the whole street sees the semis come and go.
* **Special Orders** (`Data/Specials`, `SpecialService`, `SpecialController`): once the shed stands, one breaks in
  every 20-40 minutes of play (the first after 4), and one is waiting on the first visit of each UTC day. Five kinds:
  Emergency Supermarket (big, 10 min), Golden Harvest (golden crops only), Celebrity Chef (lots of one premium crop),
  Night Express (evenings and nights only) and the Holiday Mega Delivery (weekends only: huge, lots of Gems). Each
  pays 3-12x (more with the sorter, wrapper and tower) plus Gems. Its express truck pulls up on the road in front of
  the plot; everyone on the server hears about it; a pulsing gold banner shows what's packed, the clock and the pay;
  the guide drops everything to point at PACK ORDERS. The pad (and the box line) packs it first and the conveyor
  holds back what it needs; packed, the truck drives off and it pays; too late, the boxes come back.

Tests: `FreightSmoke` (69 checks: when each special can come, golden ones, the same seed giving the same special,
specials paying far more, semis shipping more, a semi's route; no semi before the back docks, the fifth dock, a
semi's load, trip to its dock on the client and pay; a special after enough play, its truck pulling up, the banner,
the guide, the conveyor holding back, packing it, the truck driving off, Cash and Gems, one running out, golden
crops only, the day's first visit; saving). The other suites switch specials off so their packing stays exact.
409 checks in all.

## Phase G: coming back, and watching each other

* **Analytics** (`AnalyticsService`, `GameKey`): one session row per visit (new or returning, the session number,
  days since the last visit, country, device, how they joined, progress at the start and the end) and an event for
  everything that matters (the first minute's plant/harvest/sell, buys, guide steps, orders, trucks, specials,
  the calendar, the franchise, Robux taps, a snapshot every 30 s). It goes to the studio pipeline tagged "ra10" and
  sends nothing from Studio.
* **Offline earnings** (`OfflineService`): while they're away the operation keeps going at half speed, at the
  slowest station's rate (or the fields' rate before the warehouse), for up to 4 h (12 h with Long Nap, +2 h a
  franchise nap perk). The **welcome-back card** (`AwayController`) counts the Cash up and lists what's waiting:
  ripe crops, a Special Order, the day's reward.
* **The 7-day calendar** (`Data/Daily`, `DailyService`, the DAILY panel): one reward a UTC day, growing to day 7's
  Gems and golden seeds. A missed day steps back one day, not to zero. **Golden seeds** make the next plantings
  golden. The panel opens by itself after the welcome-back card while a reward is waiting.
* **The weekly Big Contract**: four parts drawn from the week's play (orders, crops, packing, specials, contracts,
  feeding, pallets), measured from Monday and scaled to the level; Cash and 50 Gems when all four are done.
* **The menu bar** (`MenuController`, `UI/Panel`): DAILY, STREET, FRIENDS, FRANCHISE and SHOP along the top right.
  One panel is open at a time; there are red dots for what's waiting, and the button pulses when the guide points
  at it.
* **The street** (`StreetService`, `World/StreetBuilder`): a **STREET gantry** over the road ranks every farm live
  by Cash/min, with deliveries/min, Size and the best shipment today, and the street's biggest shipment of the day
  along the bottom. A **billboard** over every gate shows the same numbers and likes; the most liked farm gets a
  tag. In the STREET panel, VISIT any farm's gate and come HOME, and LIKE once a day per farm.
* **Friends**: friends online in the game, with their farm's numbers from the summary they saved on another
  server; VISIT if they're here, JOIN to teleport to theirs.
* **The Hall of Fame** (`LeaderboardService`): three OrderedDataStore boards (most Cash ever, biggest shipment,
  biggest operation) on a second gantry, turning every 15 s, and in the STREET panel.

Tests: `ComebackSmoke` (56 checks) and `StreetSmoke` (40 checks).

## Phase H: Franchise

* **Franchise** (`Data/Franchise`, `FranchiseService`, the FRANCHISE panel): once the Market Hall stands, sell the
  company for Stars, sqrt(this run's Cash / 1M) of them, at least 1. The plot is rebuilt in place as a stage-1
  farm in the next region (`PlayerDataService.Rebuild` cycles the player's services without leaving the server).
  GOES: Cash, buildings, stages, the warehouse, the live orders. STAYS: Gems, the farm level, animal levels, golden
  seeds, the calendar, likes and every stat. Guide steps pay once only, across runs.
* **Regions**: Orchard Valley, Tropical Coast (x1.6), Northern Dairy (x2.4), Mega Port (x3.5). Each changes the
  meadow's colour, the trees along the back (palms, pines, cranes with containers) and the sign. Every Star ever
  earned adds +2% to everything shipped.
* **Perks** for Stars: Green Thumb (growth), Big Baskets, Head Start (the new farm's Cash), Quick Fleet (truck
  trips), Extra Order, Long Lunch (offline hours).

Tests: `FranchiseSmoke` (48 checks).

## Phase I: money, the guide to 100%, art

* **The shop** (`Data/Shop`, `ShopService`, the SHOP panel):
  * Robux: Gem packs, a once-only Starter Pack, Instant Harvest.
  * Passes: 2x Cash, VIP (+10%, +10 Gems a day, a tag), Extra Order, Long Nap.
  * Gems: Ripen Everything, Feed Everyone, Golden Seeds, Cash Rush (x2 for 15 minutes), a Special Order now.
  * The ids are in `Constants.PRODUCTS` / `Constants.PASSES`. While an id is 0 the item is free in Studio and shows
    SOON live, so creating the products and setting their ids is all that's left. Receipts are granted once and
    saved; passes bought on the website are found on join.
* **The guide to 100%**: chapters for the street (claim the calendar, visit, like), the hub (back docks, the front
  hall, a special, the tower, solar, the market, the first semi and its trip) and the franchise (sell, a perk). The
  card shows a percentage.
* **Renders**: the street board, a gate billboard, the Hall of Fame, the DAILY, STREET, SHOP and FRANCHISE panels,
  the welcome-back card, and a franchised farm in Tropical Coast.

Tests: `ShopSmoke` (37 checks). 591 checks in all, in 11 suites.

## Before going live

* Create the developer products and game passes (prices in `Data/Shop`) and put their ids in `Constants`.
* Publish (only with the owner's go-ahead).

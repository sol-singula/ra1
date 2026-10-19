# ra10 · Farm to Fleet — master plan (October 2026, after round 7)

The game as it stands and the rules every change is checked against. The old plan (orders as the heartbeat,
bottlenecks to solve, animal products, conveyor belts) is gone: the owner's direction after playing it was
**"focus on economy and progression"**, and this is the plan for that.

> *From one seed to a shipping empire.* Plant a strawberry by a shack. Pick it, sell it, buy more soil. Every
> few minutes something new stands on your farm: a barn, a tractor, chickens, a packing shed, a warehouse with
> forklifts and trucks. Six of you on a street, each watching the others grow.

## 0. What can't change (the brief)

* A tycoon: farms, fruit and vegetables, upgrading until you have a big warehouse with trucks, forklifts and
  dock doors for semis.
* Six plots a server, side by side along one road; everyone sees everyone grow from a shack to a warehouse.
* Animals outside the warehouse, upgradeable, giving boosts.
* Timers that bring players back tomorrow and over seven days.
* Guided through 100% of the game, in words a third grader reads.
* Colourful, with ra9's matte, geometric detail; the end must look like a real shipping warehouse.
* Phone first: one big button, nothing fiddly, nothing covered by the jump button.

## 1. The one loop (the Chicken Farm rule)

**Grow → barn → customers buy → upgrade the shop.** The field grows random crops as fast as it can; they pile up
in the barn; customers come to the stand at a rate and buy them a few at a time. **How fast you can sell is the
only bottleneck.** A full barn means the shop can't keep up, and the next shop upgrade (a sign, a bell, a helper, a
parking lot, adverts...) brings more customers. Nothing else ever blocks you.

* **Grow:** the field plants itself with a random crop you've unlocked (the newer ones more often, they pay more).
  Crops planted close together ripen together, so a field is one big pick. There is nothing to choose.
* **Barn:** picks go into the barn (400 crops, then 1,500; the warehouse's shelves after that). Before the barn, a
  basket you carry (20, then 60) that you sell by hand at SELL.
* **Sell:** customers walk up and buy out of the barn (4 a minute to start, one crop each). Later the vans take
  loads of 40 and pay 3x; the warehouse's trucks sell by the pallet; semis by the dozen pallets.
* **Upgrade:** every buy-pad does one thing you can see and say in a sentence ("4 more customers a minute",
  "customers buy 2 at a time", "picks 2 patches at once", "keeps 1,500 crops").

No orders, no specials, no trades, no picking what to grow: pump out food as fast as you can and sell it as fast
as you can. The animals are boosts that make the pumping faster.

Pillars: *something to do in the next 30 seconds* · *something new on the farm every few minutes* · *you do a
job by hand once, then a machine does it* · *no fail state* · *a reason to come back tomorrow* · *one next step,
always*.

| Target | Value |
|---|---:|
| First pick | < 10 s |
| First sale | < 30 s |
| First upgrade (More Soil, $10) | < 45 s |
| The barn, the first customers | ~6 min |
| Tractor (the farm runs itself) | ~8 min |
| Delivery shed (vans) | ~25 min |
| Warehouse (trucks) | session 2 |
| Hub, semis | ~7 days |

## 2. What the player does

Three buttons, one of them big:

* **The big button** (bottom right, above the jump button on phones) says what it will do for the soil you're
  standing by: **PICK** when something's ripe, **PLANT** when there's empty soil, **TEND** when it's all growing.
  TEND halves what's left to grow for **every crop on the farm** (once every 4 s): the active player waits half
  as long, the AFK player still gets there.
* At a pen the same button says **TEND**: the animals are happy for a minute and their boost doubles (once every
  2 min). Walking up to a hungry pen feeds them, free.
* **SELL**: step on the stand's pad to sell everything at once. Once the barn stands, customers buy from it by
  themselves; the HUD says how fast (🏪 SHOP 10 customers/min · buy 2 each) and turns red when the barn is full.

Tap a patch to see what's growing and how long it has. On a PC, E or a click does what the button does.

## 3. The economy: every stage sells the same crops faster, and for more

| Stage | Who buys | Multiplier |
|---|---|---:|
| 1 · The Shack | you, at SELL (Stand Roof +25%; the stand grows into a stall/shop/market, up to +35%) | 1x |
| 2 · The Farm | customers out of the barn: Big Sign +4/min, Shop Helper (2 each), Shop Bell +6/min, Parking Lot +8/min, Second Counter (3 each); pigs +4% a level on vegetables | 1x, by itself |
| 3 · The Delivery Shed | vans take 40 crops a trip and pay **3x** (Box Machine 2x the load, Sorter +15%, Wrapper +15%, Big Door quicker trips, a second van); Adverts +12 customers/min | 3x |
| 4 · The Warehouse | the barn's crops go in the door → pallets → trucks sell by the load at **2x the stand per 1,000 crops' worth**; Grow Boosts | the biggest pipe |
| 5 · The Hub | the Tower +10% on deliveries, the Market Hall +50% at the stand, Giant Trucks (24 pallets) | the same crops, three ways at once |

* **Crops** unlock on the level, one every 4-5 levels, each worth about 2.5x the last: Strawberry 8 (8 s), Carrot
  24 (15 s, Lv 4), Corn 60 (25 s, Lv 8), Tomato 88 (40 s, Lv 12), Blueberry 200 (1 min, Lv 16), Apple 560
  (1.5 min, Lv 20), Pumpkin 1,920 (2 min, Lv 25), Watermelon 4,000 (3 min, Lv 30), Orange 8,800 (4 min, Lv 35),
  Golden Pumpkin 80,000 (8 min, Lv 40). The field grows a random mix of them, the newest most. A new farmer's crops
  grow 2x as fast and pay 2.5x until level 7.
* **Golden crops** (2%, more with the Scarecrow and the cows, or a golden seed) are worth 10x.
* **Levels** come from picks, sales, buys and the guide (XP need = 10·n^1.55). The level gates crops, pads and
  the house.
* **Money:** Cash for everything on the farm (start with $15); Gems (the calendar, contracts, Robux) for skips,
  golden seeds, a customer rush.

## 4. Progression: the five stages (≈75 buys, every one visible)

| Stage | Buys, in order (level) | What it looks like |
|---|---|---|
| **1 · The Shack** $10-$900 | More Soil x9 (3 → 12 patches), Water Well (+25% grow), Wheelbarrow (carry 60), White Fence, Sprinklers (2x grow, a water tower), Stand Roof (+25%), Scarecrow (golden), **Build the Barn!** | a shack with a garden path, one field inside a fence, a stand, a well |
| **2 · The Farm** $1.5k-$15k (Lv 5-11) | The Barn (keeps 400), Big Sign (+4 customers), Bigger Field (20), Chickens, Tractor, Bigger Field (28), Shop Helper (2 each), Shop Bell (+6), Pigs, Bigger Tractor (2), Parking Lot (+8), Bigger Barn (1,500), Bigger Field (36), Sheep, Windmill, Big Tractor (3), Cows, Second Counter (3 each), Bigger Field (48), **Build the Delivery Shed!** | the red barn full of crates, shoppers walking up to the stand, pens along a path, a tractor driving the one big field |
| **3 · The Delivery Shed** $18k-$100k (Lv 11-17) | Delivery Shed, Van (40 a trip, 3x), Adverts (+12), Huge Tractor (4), Box Machine (2x the load), Sorter, Big Door, Wrapper, Mega Tractor (5), Second Van, Second Tractor, **Build the Warehouse!** | the shed and its paved yard, vans loading up and backing out of the big door |
| **4 · The Warehouse** $120k-$2.5M (Lv 17-26) | Warehouse, Packing Lines 2-4, Forklifts 2-5, Grow Boost 1-3, More Shelves x4, Bigger Warehouse x3 (it grows in place, bay by bay), Trucks 2-4, Bigger Trucks, Fast Forklifts, Robot Packer, Giant Field (64), **Build the Hub!** | the steel warehouse rising behind the shed, racks with real pallets, forklifts on painted lanes, box trucks in the lot |
| **5 · The Hub** $3M-$25M (Lv 26-32) | Back Doors (4 docks), Front Hall (over the old shed), Tower, Solar Roof, Market Hall (over the stand), Giant Truck, Giant Truck 2 | the warehouse takes the front of the plot; semis back into the docks from the shared road |

Rules for every buy: a plain name, a one-line `desc` a third grader reads, a number that's true ("+8 patches"
means 8), and something that stands on the plot when it's bought. Upgrades come in order on three pads by the
stand (the next locked one shows its level).

**The house grows by itself** with the level: Shack → Cozy Cottage (6) → Farmhouse (12) → Villa (18) → Mansion
(25) → Grand Estate (32), each with more garden: a path, hedges, flower beds, trees, a fountain and lanterns.

## 5. Automation: how the farm runs itself

* **The tractor** (Lv 6) drives round the field by itself: at each stop it picks and replants as many patches as
  its level (1 to 5; a bigger model each time), 20% quicker a level, quicker again with sheep. It goes to a crop an
  open order needs first, then the nearest ripe. A second tractor at Lv 16. Hop on (DRIVE prompt) and it follows
  you, picking and planting what you drive over, for fun.
* **The barn** keeps every pick; **the Shop Helper** (Lv 7) sells what the orders don't need every 12 s.
* **The customers** buy out of the barn every few seconds, dearest crops first; **the vans** (stage 3) take a load
  of 40 whenever there's one (or whatever's there after 30 s), drive off and pay 3x when they're back.
* **The warehouse** (stage 4) pulls the barn's extra every tick; lines pack it, forklifts rack it, trucks sell
  it. Full shelves stop the picking (the toast says so) until a truck leaves.
* **Away:** the operation earns at half speed for up to 4 h (12 h with the pass); the welcome-back card counts it
  up. Crops keep growing on the server clock.

The guide never asks the player to run any of this. It asks for the next thing to buy.

## 6. Animals: boosts only

Pens along the farm path (chickens Lv 5, pigs Lv 7, sheep Lv 9, cows Lv 10; goats and horses are data for a
later stage). No products: the crops are the money.

| Animal | Boost (per level, no top level) |
|---|---|
| Chicken | every crop grows 4% faster |
| Pig | vegetables sell for 4% more |
| Sheep | the tractor and the shop helper go 4% faster |
| Cow | fruit grows 4% faster, and a little golden luck |

* **FEED** is free, at the pen's pad (walking up to a hungry pen does it): the full boost for 4 h, half of it
  after (never none). A soft come-back timer.
* **TEND** (a pat): happy for a minute, the boost doubled; once every 2 minutes. On the big button at the pen.
* **UPGRADE** for Cash (×1.8 a level): a bigger boost, more animals in the pen (up to 8), a ribbon at 5, a golden
  bell at 10, and on without a cap.

## 7. In the background (never a step)

* **Daily contracts** (3 a UTC day: pick, sell, plant, feed, tend, serve customers, send vans) and the **weekly
  Big Contract** (4 parts, 50 Gems), both in the DAILY panel.
* **The warehouse's four stations** (Grow, Pack, Store, Ship) still have rates; the screen inside the warehouse
  shows them for anyone curious. The HUD doesn't. The pads sell their upgrades in the one plain list.
* There are no orders, no special orders and no trades any more: the owner found them too much. The one thing
  the player is ever told is "your barn is full: buy the next shop upgrade".

## 8. Coming back

* Crops on the server clock; the 8-minute Golden Pumpkin at Lv 40.
* Offline earnings (§5), the welcome-back card.
* The 7-day calendar (a reward a day, Gems and golden seeds on day 7; a missed day steps back one).
* Feeding every 4 h; a Special Order waiting on the first visit of the day; the daily contracts; the weekly
  contract.

## 9. The guide: 100%, in third-grade words

One numbered step at a time, low in the middle: a gold STEP badge, one short line, a beam and ring on the exact
tile, pad or pen, an arrow, a path on the ground, the button pulsing. A GO button when the spot is 30+ studs away.
A reward when it's done.

* **Chapter 1 · The Shack** (20): plant, pick, plant all 3, TEND, pick 6, SELL, More Soil, the well, Level 2,
  carrots at 4, soil, the wheelbarrow, the fence, 9 patches, sprinklers, the stand roof, 12 patches, the scarecrow,
  **build the barn**.
* **Chapter 2 · The Farm** (18): the barn, a bigger field, chickens, FEED, TEND the chickens, the tractor, ride
  it, a bigger field, the shop helper, upgrade the chickens, pigs, the bigger tractor, the big barn, a bigger field,
  sheep, the big tractor, the windmill, cows, **build the shed**.
* **Chapter 3 · The Shed** (15): orders fill themselves (watch the board), watch the buyer pick it up, the van,
  deliver 3, the big board, the box machine, the huge tractor, the sorter, the big door, deliver 10, the wrapper,
  the mega tractor, the second van, the second tractor, **build the warehouse**.
* **Chapter 4 · The Warehouse** (9): watch the first pallet packed, racked, shipped; pick what to grow (the picker
  opens here); DAILY, STREET, LIKE; **build the hub**.
* **Chapter 5 · The Hub** (7): back doors, the front hall, the tower, the solar roof, the market hall, the giant
  truck, its first trip.
* **Chapter 6 · Franchise** (2).
* **After the steps:** "Next: buy X ($cost). what it does", or "Pick and sell to reach Level N: Y unlocks".

A step that costs more than the player has turns into earning it ("Sell your crops at SELL: $40 more for the
Tractor"); a step by the soil while it all grows says it's nearly ripe. The card never goes empty.

## 10. The world

* **The street:** one road, six plots of 240 x 380 three a side, a fence apart, with the STREET gantry and the
  Hall of Fame over the road. Each plot has an accent colour (its sign, its trailers, its roof trim).
* **A plot, front to back:** you spawn facing the field's gate; the **BUILD stall** (the three buy-pads under
  one little roof) a few steps behind you, the stand and SELL a few steps to the left; the house and its garden on
  the left with its own drive; **one field** (8 to a row, up to 64 patches) in the middle inside its fence; a wide farm
  path up the middle with signposts (FIELD, BARN, ANIMALS); the barn with its doors to the field and two tractor
  spots; the four pens along a side path; the shed and its yard on the right (industry side), the warehouse
  behind it growing bay by bay, the truck lot and lane up the east edge, the docks and truck court at the back.
  The hub's front hall and market hall later take over the shed and the stand.
* **Landscaping grows with the level**: the house's garden, hedges, trees, the fountain. Signs on every zone
  (RECEIVING, PACKING LINES, ROW 3, DOCK 2). Every machine and vehicle is animated on each client.
* **Art:** a picture book: toon blocks (a darker foot, a lighter cap), chunky round trees, rolling hills, flower
  clumps, bunting; a warm sun with bloom and a saturated grade; ra9's matte, geometric detail underneath; the farm palette (barn red, cream, three greens, sunflower) and the
  industrial one (concrete, safety yellow, rack orange on blue, steel grey, white trailers with the plot's stripe).
* Part budget: a stage-5 plot ≤ 3,000 parts; vehicles, animals and crops are client-animated.

## 11. Social and prestige

* Name your farm (NAME on the menu; the sign by the road). Visit, LIKE, the street board and gate billboards,
  friends across servers, the Hall of Fame (most Cash, biggest shipment, biggest operation).
* * **Franchise** once the Market Hall stands: sell for Stars, start again in a richer region (Orchard Valley →
  Tropical Coast 1.6x → Northern Dairy 2.4x → Mega Port 3.5x); Gems, levels, animal levels and golden seeds stay;
  Stars buy perks (growth, baskets, a head start, quicker trucks, Regulars, longer naps).

## 12. Money

2x Cash, VIP, More Customers and Long Nap passes; Gem packs; a once-only Starter Pack; Instant Harvest; Gems for
Ripen Everything, Feed Everyone, Golden Seeds, Cash Rush, a Customer Rush. Nothing paid
is required and the guide never points at the shop.

## 13. Admin

xthirtysix sees a red ADMIN button: reset any farmer's progress by name (online: a fresh save and a rejoin;
offline: the save is deleted) and give Cash for testing.

## 14. What's next (in order)

1. **Watch the numbers.** Analytics already logs the first minute, every buy and every guide step: check where the
   first sessions stop and tune costs and crop values there first (the shed at ~25 min is the big one).
2. **Renders and store art** for the new layout (the one field, the barn, the growing house).
3. **Products and passes**: create them on Roblox and put the ids in `Constants`.
4. Goats and horses as stage-4/5 pens; seasonal pens later.
5. Experience notifications (crops ready, the day's reward) once the owner enables them.

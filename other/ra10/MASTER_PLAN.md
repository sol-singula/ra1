# ra10 · Farm to Fleet — master plan

The design brief (October 2026) and the decisions made where it stops: the reference every phase is checked
against.

> *From one seed to a shipping empire.* Plant a strawberry in a dirt patch next to a shack; days later you run a
> full distribution hub: fields, barns and pens outside, a proper shipping warehouse inside, forklifts weaving
> between pallet racks and semis backing into the dock doors. Six of you on a server, side by side, each watching
> the others grow from a shack to a warehouse.

## 0. The brief, in the owner's words (what can't change)

* **A tycoon: farms, fruits, vegetables**, upgrading until you have **a big warehouse with trucks, forklifts,
  delivery and pick-up doors for semis, forklifts driving around**.
* **6 plots a server**, as close together as possible, so everyone sees everyone go from a little shack to a huge
  warehouse. As plots grow, **the roads and the land round them adjust**.
* **Animals** (basic ones: cow, sheep, pig, chicken…), **upgradeable**, giving the farm **production boosts**
  (things grow faster etc.), kept **outside the warehouse**.
* **Timers and shipping**, and **timers that bring players back the next day and over 7 days**.
* **Guided through 100% of the game.**
* **Art: much more colourful than ra9, with ra9's texture and detail.** It must look like **a proper shipping
  warehouse** by the end.
* Monetisation, art and every recommendation from the pitch: agreed.

## 1. Art direction

* **Texture: ra9's.** Matte SmoothPlastic, no image textures, no noise. Detail comes from geometry: plinths, trims,
  moldings, panel lines, window frames, railings, bolts, stripes. Everything square and clean, readable on a phone.
* **Colour: generous, but in families.** A fixed palette (Constants.PALETTE) so six plots look like one world:
  * Farm: barn red, cream trim, field greens (three steps), soil browns *only for soil and crates*, sky blue water,
    sunflower yellow, fence white.
  * Crops: each its own strong colour (strawberry red, carrot orange, corn yellow, pumpkin orange, watermelon green
    and pink, blueberry indigo, golden crops in gold with a glow).
  * Industrial: concrete light grey floors, **safety yellow** (forklifts, bollards, lane lines, dock bumpers in
    black and yellow stripes), **rack orange beams on blue uprights**, steel grey walls with ribbed panels, green
    and red dock lights, white trailers with each plot's colour stripe, chrome-grey truck cabs.
  * Each plot has an **accent colour** (its trailers, banners, roof trim, uniforms).
* **The warehouse at the end must read as real at a glance:** a long ribbed-steel building with a parapet and
  skylights; a row of dock doors (roll-up doors, dock seals, levelers, bumpers, red/green dock lights, numbers
  over each door); a truck court with painted stalls and trailer parking; inside, polished concrete with yellow lane
  lines and walkways, rows of pallet racks four levels high stocked with crates of real produce, a picking line, a
  mezzanine office with windows, hanging lights, fire extinguishers, signage ("RECEIVING", "SHIPPING", "DOCK 3").
* **Cheap on phones:** a fully grown plot stays under a part budget (§10); vehicles, animals and crop sway are
  animated on each client, never by the server.

## 2. Vision and targets

Player fantasy: *"I started with a shack and a dirt patch. Now look at my warehouse: my forklifts are loading my
trucks with my apples, and the whole server can see it."*

Pillars: **always something to do in the next 30 seconds** · **visible growth every few minutes** · **automation
you earned** (you do each job by hand first) · **no fail state, no skill gate** · **a reason to come back tomorrow
and all week** · **guided from the first tap to the last upgrade**.

| Target | Value |
|---|---:|
| First harvest | < 10 s after spawning |
| First sale | < 30 s |
| First upgrade | < 45 s |
| First automation (sprinkler) | < 3 min |
| First animal | ~5 min |
| Packing shed | ~25 min |
| First forklift | session 2 (day 1–2) |
| First semi at a dock door | day 2–3 |
| Full distribution hub | ~7 days of normal play |
| Median session target | 12+ min (ra9's was 1:45: the first two minutes are everything) |

## 3. The core loop

**Plant → grow (timer) → harvest → carry/convey → sell or pack → fill orders → upgrade → automate → bigger orders.**

* **Selling:** the farm stand (any crop, a fair price) from minute one. **Orders** pay far more: a truck (a van at
  first, a semi later) arrives at your plot with a list ("30 strawberries, 10 carrots"), you have its timer to fill
  it, it drives off with a payout and XP. Orders are the heartbeat of the mid and late game.
* **Money:** Cash (earned) for everything on the farm; Gems (rare: daily streak, big orders, Robux) for skips,
  golden seeds, cosmetics.
* **Farm XP and levels** gate unlocks (crops, animals, buildings), so the guide always has a clear next target.

## 4. The five stages (each automates the last)

| Stage | You start by hand | Then buy | The world |
|---|---|---|---|
| **1 · The Shack** | tap to plant, tap to water, tap to pick | more plots, a well, a sprinkler, a wheelbarrow | a shack, a dirt patch, a hand-painted stand, a mailbox |
| **2 · The Farm** | carry crates to the stand | fields, a barn, a tractor (auto-harvest a row), a conveyor to the stand, **animal pens** | red barn, fenced fields, silo, pens, a gravel driveway to the road |
| **3 · The Packing Shed** | box produce at the packing table | sorting machine, box line, pallet wrapper, the first **delivery van** | a shed with belts and a loading door, a paved yard |
| **4 · The Warehouse** | drive the first forklift yourself (optional; a worker can do it) | racks, forklift drivers, receiving and shipping doors | the steel warehouse rises bay by bay; racks fill with your crates |
| **5 · The Distribution Hub** | wave the first semi into a dock | more dock doors, a truck fleet, trailer parking, an office, a fuel island | semis queue on the road, forklifts load them, trucks pull away with your colour on the trailer |

Each stage is about 8–15 buy-pads/upgrades (≈60 in all), each one **visible** (a building, a machine, a vehicle, a
field), plus level-ups on machines (speed, capacity) that change how they look (a bigger hopper, a second belt).

## 5. Crops

| Crop | Unlock | Grow | Notes |
|---|---|---|---|
| Strawberry | start | 8 s | the first harvest, instant gratification |
| Carrot | Lv 2 | 20 s | |
| Corn | Lv 4 | 45 s | tall stalks, tractor-friendly |
| Tomato | Lv 6 | 1 min | |
| Blueberry | Lv 9 | 2 min | bushes |
| Apple | Lv 12 | 5 min | orchard trees, regrow (no replant) |
| Pumpkin | Lv 16 | 15 min | big, satisfying |
| Watermelon | Lv 20 | 30 min | |
| Orange | Lv 25 | 1 h | orchard |
| **Golden Pumpkin** | Lv 30 | **8 h (overnight)** | a "plant before bed" crop; huge payout; golden glow |

Fruit trees regrow; vegetables replant (auto-replant is an upgrade). Rare **golden** versions of every crop drop
sometimes (and from golden seeds) and are worth 10×.

## 6. Animals (outside the warehouse, in pens)

Animals live in pens on the farm side of the plot (never inside the warehouse), wander their pen (client-animated)
and each gives a **product** and a **farm-wide boost**:

| Animal | Unlock | Product | Boost (per level, up to Lv 10) |
|---|---|---|---|
| Chicken | Lv 3 | eggs | **crops grow faster** (+3% speed) |
| Pig | Lv 7 | truffles | **sell price of vegetables** (+3%) |
| Sheep | Lv 10 | wool | **packing and machine speed** (+3%) |
| Cow | Lv 14 | milk | **fruit grows faster** (+3%) and golden-crop chance |
| Goat | Lv 18 | cheese | **order payouts** (+2%) |
| Horse | Lv 24 | — | **worker and vehicle speed** (+3%) |
| (later) Llama, Duck, Bee hives | events | | seasonal boosts |

* **Upgrade:** Cash + feed (grown on the farm: corn and carrots become feed at the feed mill) → bigger, shinier
  animal, a bigger pen, a stronger boost; Lv 5 and Lv 10 change the look (a ribbon, a golden bell).
* **Happiness, never punishment:** feeding every 4 h keeps the boost at 100% (and doubles product); unfed it falls
  to 50%, never to 0. Feeding is a soft come-back timer.
* More of each animal (pen slots) unlock with levels; every pen is a visible upgrade.

## 7. Orders, vehicles, the warehouse

* **Order board** on the plot: 3 live orders (refresh on a timer), each with crops, a reward and a time limit;
  **daily contracts** (3, reset at midnight UTC) and a **weekly Big Contract** (a 7-day multi-part order with a big
  Gem reward).
* **Vehicles** carry the story: a van (stage 3) → box trucks → **semis** (stage 5) arriving on the shared road,
  backing into a free **dock door**, waiting while forklifts load pallets, pulling away. Inbound semis drop seed and
  feed pallets at **receiving** doors (the "pick-up / delivery doors" of the brief: receiving on one side, shipping
  on the other).
* **Forklifts** move pallets: from the packing line to the racks (put-away), from the racks to the dock
  (picking/loading). More forklifts, faster forklifts and better routes are upgrades; the floor shows painted lanes
  they follow. The player can hop into one and drive (optional, never required; a big touch control set).
* **How it's built:** the server decides *what moves where and when* ("pallet 41: rack B3 → dock 2, 7 s"); each
  client animates the forklift or truck along the plot's lane graph (§10). Twenty-plus vehicles cost the server
  nothing.

## 8. Coming back: tomorrow and all week

* **Long timers on purpose:** pumpkins (15 min) → oranges (1 h) → **Golden Pumpkin (8 h)**: plant at night,
  harvest in the morning. Late upgrades take real time (an hour, four hours, overnight) with a skip.
* **Offline earnings:** machines and workers keep producing while away (up to 4 h; 12 h with the pass); the
  "while you were gone" card is the first thing you see.
* **7-day streak calendar:** a reward each day, bigger every day; **day 7 = a rare animal** (a golden chicken) or
  golden seeds. Miss a day: the streak steps back one day, not to zero.
* **Daily contracts** (3) and the **weekly Big Contract** (7 days).
* **Animal feeding** every 4 h (a soft timer, §6).
* **End-of-session hooks:** when they leave, the last screen shows what's ready tomorrow ("Golden Pumpkin ready in
  7:42 · Day 3 reward waiting · Contract 2/3").
* **Roblox experience notifications** (opt-in) for "your crops are ready" / "your day-3 reward is waiting", once
  the owner enables them.

## 9. The guide: 100% of the game

* **Always a next step.** A goal card at the top of the screen at all times ("Plant 3 strawberries", "Buy the
  sprinkler", "Fill your first order"), with a **3D arrow and a path line on the ground** to the exact thing to
  tap, and the button itself pulsing. It is never empty: when the scripted steps end, it switches to generated goals
  (the next upgrade, the next order, the next animal level).
* **A scripted chapter per stage** (~120 steps in all), each new system introduced once, in the moment, by doing
  it: the first sprinkler, the first animal, the first order, the first van, the first forklift ride, the first
  semi at a dock. Every step pays a little (Cash or XP), so following the guide is the fastest path.
* **No walls of text.** One line, one arrow, one pulse. A step that isn't done in 20 s gets a gentle replay (the
  camera glances at the target).
* **Returning players** pick up mid-chapter; the guide remembers.

## 10. Map, plots and roads

* **6 plots a server, as close as possible:** two rows of three either side of a **shared main road**, each plot
  backing onto open land it grows into. Neighbours are a fence apart; the road between them is where everyone's
  trucks drive.
* **Each plot grows in footprint** with its stage: the shack's yard → fenced fields → shed and yard → the warehouse
  and its truck court. The plot's land is reserved from the start (looks like meadow until built on), so plots never
  collide.
* **Roads adjust as plots grow:** a dirt track → a gravel driveway → a paved yard → a truck court with stalls and
  a two-lane entrance joining the main road; the main road itself gains turn lanes and stop markings by each plot
  that reaches stage 5.
* **Part budget:** a stage-5 plot ≤ 3,000 parts; vehicles and animals are client-side models; StreamingEnabled
  with the plots as persistent streaming regions where needed.

## 11. Money (agreed)

* **2× Cash** pass · **Auto-Collect + 12 h offline** pass · **VIP Truck** pass (a chrome semi with its own dock door
  and +10% order pay) · **Skip timers** (Gems; Gems as dev products) · **Golden seeds** packs · forklift/truck/
  trailer skins and plot themes · a **Starter Pack** offered after the first big order (cash, gems, a golden seed,
  a chicken).
* Nothing paid is required; the guide never points at the shop except as an option.

## 12. Social

* Visit and **like** neighbours' plots; a plot sign shows the owner, level and stage.
* Leaderboards: Net Worth, Shipments, Biggest Order (all time and this server); the live street board (§13.4).
* Friends join friends; a party lands on the same server.

## 13. What makes it addictive: the five pillars (owner's direction)

Not more features: a few mechanics that make the loop we have hard to put down. Everything from Phase E on is
built to serve these five, and each later phase is checked against them.

### 13.1 The operation visibly explodes in scale
* **Stock is visible.** Every pallet the farm holds is a real pallet on a real rack slot (up to the rack's size),
  and overflow piles up in the yard. A full warehouse looks full; an empty one looks hungry.
* **Every upgrade adds things you can count:** another bay of the warehouse, another rack row, another forklift on
  the lanes, another dock door with its own semi, another conveyor line. No upgrade is "+10%" with nothing to see.
* **The end state** is dozens of moving things on one plot: 6-8 forklifts, 3-4 conveyor lines, 6 dock doors,
  semis queuing on the road, a fuel island, trailer parking. It is the store thumbnail.
* **Operation Size** (one number: buildings, machines, vehicles, docks) on the plot sign and the street board, so
  "bigger" is something you can say out loud.

### 13.2 Bottlenecks the player solves
* From stage 4, the farm runs as a **flow of four stations**: **Grow** (crops a minute) → **Pack** (boxes a
  minute) → **Store** (pallet space) → **Ship** (docks x truck size / trip time). Each station has a real rate the
  server computes from what's owned.
* The **Operations board** (a HUD strip and a big screen in the warehouse office) shows the four rates as bars.
  The slowest glows red: "BOTTLENECK: SHIPPING". Pallets pile up visibly where the flow jams (packed boxes on the
  floor, full racks, trucks waiting for a free door).
* The buy-pads offer **one fix per station** instead of one straight list: another dock, a faster forklift, more
  racks, a bigger truck, another packing line, automation. Fixing one station moves the bottleneck to the next, and
  each fix opens the next expansion. The guide always points at the red station's fix, so younger players never get
  lost, and older players can choose their own order.
* Only one station is ever red, and its fix is always on a pad. The choice is real, but there's never a puzzle.

### 13.3 Rare, high-value shipments
* **Special Orders** break into normal play with a siren, a banner and a special truck on the shared road that
  everyone sees: a short deadline (5-20 minutes) and 5-20x a normal order's pay, often with Gems.
* Kinds: **Golden Harvest** (only golden crops: suddenly the scarecrow and the cows matter), **Emergency
  Supermarket** (a big mixed order, 10 minutes: drop everything), **Holiday Mega Delivery** (a weekend/holiday
  event: several semis, the whole street can chip in to a shared total), **Celebrity Chef** (one rare crop, top
  quality), **Night Express** (only between set hours: a come-back reason).
* One rolls every 20-40 minutes of play; one is waiting on the first login of each day (a reason to come back
  tomorrow), and the weekly Big Contract becomes the week's headline Special Order.

### 13.4 Reasons to watch each other
* **The street board** at the road: each plot's Operation Size, deliveries a minute, Cash a minute, and biggest
  shipment today, ranked live. A banner over the road celebrates the street's biggest shipment of the day.
* **Plot billboards** over each gate show those numbers to anyone walking past, so a neighbour's jump is noticed.
* **Visit**: a button teleports you to any plot on the street (the gate, facing in), and the street is laid out
  to see the neighbours' operations from your own. **Friends**: a panel with friends' sizes and throughput across
  servers (from their saved summary), and "Join" to land on their server. Likes and a "most liked operation" tag.
* **Shared moments**: a Special Order's truck, a rival's semi fleet and a big shipment's fireworks are visible to
  the whole street.

### 13.5 Prestige: life after the warehouse
* When the distribution hub is done, **Franchise** it: sell the company for **Franchise Stars** (from lifetime
  earnings) and start a new farm in a **new region**. Cash, buildings and stages reset; Gems, cosmetics, the guide's
  progress and animals' levels stay.
* **Stars buy permanent bonuses:** faster growth, a bigger first basket, starting with the barn, quicker trucks, an
  extra order slot, more offline time.
* **Regions** change the look and the goods: Orchard Valley (the start), Tropical Coast (mangoes, coconuts,
  pineapples), Northern Dairy (cheeses, berries), Mega Port (a container terminal finale). Each has higher-value
  products and a bigger scale cap (more docks, a rail siding, then container cranes), so every run ends larger than
  the last.
* The second run reaches the old end-game in a fraction of the time, then goes past it. A Franchise level shows on
  the plot sign and the street board.

## 14. Build phases

| Phase | What |
|---|---|
| **A** | Scaffold from ra9's engine (loader, saves, Net, client boot, mock-engine tests, analytics hooks); this plan |
| **B** | The map: six plots, the shared road, reserved land; stage 1 (shack, soil, strawberry→carrot); plant/grow/harvest/sell; the first minute and the guide's first chapter |
| **C** | Stage 2: fields, barn, tractor, conveyors, crops to corn/tomato/blueberry; animals (pens, chicken→cow, feeding, boosts, upgrades) |
| **D** | Stage 3: packing shed, box line, orders, the van, the order board; daily contracts |
| **E** | Stage 4: the warehouse rises bay by bay (racks with visible pallets, put-away), forklifts on painted lanes (client-animated, an optional ride); **the four-station flow, the Operations board and bottlenecks** (§13.2); Operation Size |
| **F** | Stage 5: dock doors, receiving/shipping, semis on the shared road, truck court, roads adjusting; **Special Orders** (§13.3) |
| **G** | Coming back: offline earnings, 7-day calendar, weekly contract, golden pumpkin, end-of-session card, the guide to 100%; **the street board, plot billboards, visiting, friends** (§13.4) |
| **H** | **Prestige: Franchise, Stars, the second region** (§13.5) |
| **I** | Money (passes, gems, skips, starter pack), leaderboards, store art and thumbnails, tests, renders, publish |

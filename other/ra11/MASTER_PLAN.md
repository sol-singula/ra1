# Farm Empire — the master plan

*Working title. Timings, prices and retention figures are starting hypotheses to validate through playtesting.*

**Core design promise: easy to play, rewarding to master.** Players always know what to do next, can see their
business growing, and are naturally shown where the next upgrade will help.

Design priorities:

* A fast first-session payoff: plant, harvest, sell, earn and expand.
* Free, universal harvest automation; better machinery makes it faster.
* Visible bottlenecks across production, retail, storage and shipping.
* Buildings physically transform as the business grows.
* Retention and monetization measured from the first prototype.

## 1. Vision and core gameplay

A 12-player Roblox farming tycoon. Every player owns a permanent, expandable territory. The game begins with a
tiny fruit stand and develops into a large farm, a busy retail store, a warehouse, and a distribution centre
with forklifts, trucks and multiple loading docks.

Four interconnected systems:

* **Production:** plant crops, grow them, harvest them, expand fields.
* **Selling:** NPC customers buy produce; the store has a finite service rate and capacity.
* **Logistics:** goods move through storage, the shop, the warehouse and the trucks.
* **Expansion:** cash funds larger fields, faster machinery, more selling capacity and new business stages.

Locked decisions: 12 players a server, each with a permanent territory · start with a simple fruit stand, not a
farming tutorial · automation is earned through normal play, and the first auto-harvester covers every planted
crop (it is slow, not restricted to a fraction of the farm) · tractors and larger machinery increase speed and
throughput · production and selling capacity are separate upgrade paths · workers come with business upgrades,
never bought one by one · camera moves introduce and celebrate major changes but stay short and skippable.

**The core loop:** plant → grow → harvest → store → sell → earn → upgrade → expand. The same loop eventually
feeds bulk dispatches and market orders.

## 2. Visible bottlenecks and recommendations

*The defining principle: the player should see their next problem before the game tells them what to do about
it. A bottleneck is a growth opportunity, not a punishment.*

| System | Tracks | Shows the player |
|---|---|---|
| Harvesting | ready crops vs. harvest rate | ripe tiles waiting, with their glow |
| Storage | inventory vs. capacity | crates stacking in the stock area; the STORAGE FULL line |
| Store | customer demand vs. service rate | a visible line at the counter, busy workers, full shelves |
| Warehouse | incoming goods vs. dispatch rate | pallets stacking up, trucks waiting at the docks |
| Land | productive space vs. remaining plots | visible unused expansion zones with their price |

When the store falls behind: customers queue instead of leaving, crates accumulate, revenue continues but the
displayed rate makes the opportunity visible, and a persistent, unobtrusive prompt previews the store expansion
and its price. The upgrade adds floor space, shelves, workers, stock capacity and service throughput together.

Recommendation priority: finish first-time onboarding → recommend the highest-value affordable upgrade →
if nothing is affordable, recommend the quickest sensible way to earn the shortfall → introduce a new mechanic
when its prerequisite is reached → detect the current bottleneck; never recommend more production when selling
capacity is the constraint. Never make players lose everything for missing a prompt: a crowded store still earns.

The game's model (BusinessService:Bottleneck): `dispatch` (a full warehouse the docks can't clear) > `storage`
(stock at 90% of capacity) > `service` (a line of four or more) > `harvest` (ripe tiles waiting, no or slow
machine) > `production` (empty shelves) > `demand` (an idle counter) > `land`. The recommendation is the
dearest affordable upgrade that fixes it, else the cheapest one to save for (UpgradeService:Recommend).

## 3. The first 60 minutes

Initial pacing targets, not hard timers.

| Target | Milestone | What happens |
|---|---|---|
| 0–1 min | First sale | Plant one crop, watch it grow, harvest it, see an NPC buy it. |
| 1–3 min | First expansion | Buy more tiles and a bigger counter. More NPCs arrive; revenue is visible. |
| 3–5 min | Working business | Unlock a second crop; the auto-seeder replants; a sign brings customers. |
| 5–10 min | First real choice | Production, store capacity or a new crop: the recommendation follows the bottleneck. |
| 10–15 min | Farm expands | The East Field opens; wheat and corn; harvesting gets repetitive. |
| 15–20 min | Automation | The Auto-Harvester works across the whole farm, slowly. A phase change. |
| 20–30 min | Business transforms | The tractor; adverts; more storage. The game shifts away from clicking. |
| 30–45 min | First store | The Fruit Shop replaces the stand: shelves, a stockroom, workers, a proper line. |
| 45–60 min | Logistics preview | The warehouse ghost, the trucks' lane and the docks appear as the next goal. |

After the first hour: 1–2 h the warehouse and the first truck (bulk sales, dispatch); 2–4 h more docks and
throughput; 4–8 h the large automated farm (combine, fleet, more crops, the distribution centre); long term new
regions (prestige), premium crops, cosmetics.

## 4. Territory layout and the world

Twelve territories, two rows of six along an avenue, round a shared town square in the middle. Each territory
(130 x 120 studs, World/Layout) is laid out for its endgame footprint from the start:

* **Front entrance:** the stand (later the shop) on the avenue, the spawn beside it, the gate sign.
* **Starter production:** the starter field (24 tiles) right behind the business.
* **Expansion fields:** East, West and North fields (30 tiles each), visible as outlined zones with their price.
* **Equipment zone:** the machine shed on the right, where the harvester, tractor and combine park.
* **Logistics zone:** the warehouse and its docks at the back right, with the trucks' lane down the right edge.
* **Scenic edges:** trees, a white fence all round.

The town: the market board, the shared boost meter, the leaderboards, a fountain, a spawn for visitors, and the
avenue running past every gate.

Performance rules: crops are lightweight states (the client draws a plant per tile from a table), NPCs, vehicles
and effects are pooled and scripted, collisions are simple, there is no script per crop, and each player's
progression is saved separately from the server's temporary state.

## 5. Harvest automation and machinery

*The first auto-harvester covers every eligible planted crop. Its limitation is speed, not coverage: with 70 of
100 tiles ready it eventually clears all 70.*

| Tier | Role | Tiles a minute |
|---|---|---|
| 1. Auto-Harvester | the earned milestone (~15–20 min) | 40 |
| 2. Farm Tractor | early expansion | 90 |
| 3. Combine Harvester | midgame | 200 |
| 4. Automated Fleet | late game: two machines on the field | 400 |

Coverage, harvest rate and storage throughput stay separate variables. A full stock area makes the machine wait,
never lose crops. Offline: crops grow on their saved timestamps; with a machine the farm also earns at half the
live rate for up to 4 hours (8 with the Night Shift pass).

## 6. Business progression: stand to distribution centre

Each stage has its own look and its own capacity problem (Data/Business).

| Stage | Look | Base demand / service / storage / dispatch | Bottleneck |
|---|---|---|---|
| A. Fruit Stand | a counter, an awning, a few crates | 12 / 10 / 30 / – | the line grows faster than the stand serves; crates fill |
| B. Fruit Shop ($2,500) | a storefront, shelves, a stockroom, two workers | 60 / 50 / 400 / – | produce beats shelf movement or service |
| C. Warehouse ($30,000) | pallets, a forklift, docks, trucks buying in bulk at 1.4x | 90 / 80 / 2,000 / 60 | goods arrive faster than the docks dispatch |
| D. Distribution Centre ($300,000) | six docks, a conveyor, a fleet, bulk contracts at 1.6x | 140 / 120 / 8,000 / 400 | docks, storage and dispatch stay distinct choices |

Workers and vehicles are scripted, lightweight animations: workers restock, customers walk, queue, buy and leave,
the forklift shuttles between the pallets and the dock, trucks pull out, drive down the lane and return.

## 7. Economy and revenue feedback

Three values at a glance: cash, income a minute, and the cost of the next useful upgrade. Profit a minute = units
sold a minute x profit a unit. Crops (Data/Crops):

| Crop | Grow | Value | $ a tile a minute | Unlock |
|---|---|---|---|---|
| Strawberry | 10 s | $3 | 18 | start |
| Tomato | 15 s | $6 | 24 | $80 |
| Wheat | 20 s | $10 | 30 | $250 |
| Corn | 30 s | $18 | 36 | $800 |
| Pumpkin | 45 s | $32 | 43 | $3,000 (shop) |
| Blueberry | 40 s | $36 | 54 | $5,000 (shop) |
| Melon | 60 s | $55 | 55 | $20,000 (warehouse) |
| Golden Apple | 120 s | $150 | 75 | $200,000 (centre) |

Cheap crops grow quickly and fill demand; premium crops take longer and earn more per tile, and fewer harvests
per dollar eases the harvest bottleneck. Production and demand are separate upgrade paths: a large farm can be
bottlenecked by selling capacity, a large store by production.

## 8. The camera

Camera moves teach, celebrate and reveal; they never take control for long (CameraController).

* **Opening (3.5 s, once ever, skippable):** an elevated view of the farm, a glide to the stand, then it settles
  behind the player with the first tile lit.
* **Reveals:** the first shop (pull back to show the building), the auto-harvester (follow it across the field),
  a new crop (close-up, then back), the warehouse and the centre (an elevated reveal of building and trucks).
* Rules: 1–3 s for most moves, 4–5 s for major reveals; never during a purchase prompt; a tap or Space skips;
  control returns with the next task visible; nothing replays on a later login.

## 9. Graphics and performance

Polished, colourful low-poly 3D: rounded shapes, strong silhouettes, soft lighting, readable detail. Rich natural
greens for fields and crops, warm wood and cream for the starter buildings, distinct crop colours and silhouettes
(wheat stalks, corn stalks, tomato vines, strawberry bushes, pumpkins and melons on the ground, the golden apple
tree), bright accents for machinery and upgrade cues (gold for the recommendation, blue for the preview ghost).
No heavy bloom or post-processing. Four readable growth stages; a ready crop is bigger, brighter and ringed.
Major upgrades change footprint, architecture and activity. Mobile first: lightweight models, pooled effects,
streaming on.

## 10. Retention

* **Day 1:** a sale in the first minute, an expansion in the first few, a meaningful upgrade, a glimpse of the
  shop (the ghost and its price), a clear next objective at session end (the task card).
* **Day 2:** the welcome-back card: time away, crops grown, cash earned with a machine, and the next upgrade.
* **Days 3–7:** new crops, machines and land zones, the shop's milestones, the market board's daily orders, the
  shared boosts, cosmetics.
* **Days 7–30:** advanced crops, the warehouse and the centre, bulk contracts, rare cosmetics, prestige (never
  mandatory, only after a substantial milestone).

Initial funnel targets (hypotheses): first crop planted 90%+, first sale 85%+, first upgrade 70%+, first
meaningful expansion 50%+, D1 15–20%, D7 4–7%, D30 1–3%. If players plant but don't sell, fix the sales loop; if
they sell but don't expand, fix the next goal.

## 11. Monetization

Complete and fun without Robux; nothing basic is paywalled. Four kinds (Data/Shop):

* **Shared boosts (10 min, the whole server):** Harvest Rush (machines 2x), Customer Rush (demand 2x), Golden
  Market (+50% on every sale). The meter in the square fills with anyone's Cash and lights the next one in turn;
  Robux lights one at once. One at a time.
* **Convenience:** Turbo Machines (+25%), Night Shift (8 hours offline).
* **Cosmetics:** Paint Shop, the Premium Bundle.
* **Cash:** crates sized by the player's own income a minute (30 minutes, 3 hours).

Test prices: small boosts 19–39, larger 49–99, cosmetics 49–149, bundles 199–399 Robux.

## 12. NPC and inventory simulation

The real economy (layer A, BusinessService) is separate from the visual simulation (layer B, the client). The
server works out demand, service, stock, sales a minute and dispatch; the client draws six to eight people on the
path for thirty sales a minute, a line whose length follows the server's queue, workers, the forklift and the
trucks. If demand exceeds service the line grows; if service exceeds demand there is spare capacity; if stock runs
out, sales stop whatever the capacity.

## 13. Saving and offline progression

Persistent: cash, lifetime earnings, the stage, upgrades and levels, the tiles and their planting times, the
stock, the guidance's place, passes, cosmetics, prestige, the away timestamp and the income rate at leaving.
Temporary: NPC positions, the active server boost, the meter. Autosave every two minutes, a session lock so two
servers never write one profile, retries on load.

## 14. Technical module plan

| Module | Responsibilities |
|---|---|
| TerritoryService | territory ownership, the world build, rebuilds on upgrades, spawning, visiting |
| CropService | tiles, planting, growth on timestamps, harvesting, the crop choice |
| AutomationService | the machine's route and rate |
| BusinessService | the stage, demand, service, storage, dispatch, the queue, the bottleneck |
| EconomyService | cash, income a minute, multipliers |
| UpgradeService | buying, prerequisites, the recommendation |
| TaskService | onboarding, the primary task, goals, the milestone |
| BoostService | the shared boosts and the meter |
| ShopService | Robux products and passes |
| OfflineService | the welcome-back settlement |
| PlayerDataService | profiles, saving, the lock |
| AnalyticsService | sessions and the funnel's events |
| Client | HUD, crops, tasks and the arrow, the upgrades panel, customers, machines, logistics, camera, effects, shop, boost, away |

The server validates every transaction; the client only asks.

## 15. The upgrade tree

Five branches (Data/Upgrades): Production (tiles, fields, crops, sprinklers), Machinery (seeder, harvester,
tractor, combine, fleet), Retail (counter, sign, adverts, billboard, checkouts, the shop), Logistics (crates,
shelves, the warehouse, docks, forklifts, racks, sorting, the centre, conveyors, silos), Prestige (a new region).
Every upgrade adds output, adds selling capacity, eases a bottleneck, unlocks something or visibly changes the
farm; nothing is a tiny stat with no transformation.

## 16. Task and guidance design

Three layers, one prominent task on screen: the primary task (nine onboarding steps, then the recommendation),
secondary goals (harvest 50, sell 200, earn $1,000 ...; each pays once, nothing is claimed by hand), and the
long-term milestone (the next building's silhouette and price, in the world and on the HUD). Guidance stops
once the loop is understood; the camera is reserved for new mechanics.

## 17. Build roadmap

| Phase | Build | Exit criteria |
|---|---|---|
| 1. Core | one territory, crops, harvesting, the stand, NPC sales, cash, the first upgrades | a new tester understands the loop and reaches the first upgrade |
| 2. Retention | tasks, the store expansion, queues, revenue feedback, the auto-harvester, machinery | players see production vs. selling bottlenecks; no artificial paywalls |
| 3. World | 12 territories, expansion zones, the town, boosts, visiting | every farm runs without performance trouble |
| 4. Content | warehouse, storage, forklifts, trucks, docks, bulk contracts | a new economic bottleneck and a post-retail goal exist |
| 5. Polish | cinematic reveals, building transformations, workers, sound, previews | major purchases feel satisfying and visibly change the farm |
| 6. Scale | retention tests, economy tuning, purchases, advanced crops, prestige | engagement and monetization improve without damaging free progression |

Phases are done when their exit criteria are met, not on dates.

## 18. Analytics

Events from day one: first_crop_planted, first_crop_harvested, first_sale_completed, first_upgrade_purchased,
store_bottleneck_reached, automation_unlocked, first_store_unlocked, warehouse_unlocked, session_ended,
purchase_completed (AnalyticsService), plus every buy, task, truck, the welcome-back and a snapshot every 30 s.
Dashboard views: new players by day and cohort, first-session completion, session length, D1/D7/D30, time
between milestones, conversion and revenue per active user.

## 19. Risks and mitigations

| Risk | Mitigation |
|---|---|
| players outgrow the game too quickly | the next transformation is shown early (the ghost) and earned through progress |
| production feels meaningless | the sales bottleneck is on screen, stores keep earning, capacity upgrades are clear |
| automation removes the fun | repetitive harvesting goes; crop choices, expansion, balancing and new facilities stay |
| world performance | lightweight crops, pooled NPCs, simple routes, streaming, a server-side economy |
| guidance becomes annoying | one primary task, short skippable camera moves, no repeated tutorials |

## 20. Final specification

Server size 12 · starting experience a fruit stand · first major automation ~15–20 min · first store
transformation ~30–45 min · first warehouse goal ~45–60 min · progression stand → shop → expanding farm →
warehouse → distribution centre → new region · systems: crops, free automation, NPC sales, visible bottlenecks,
workers, logistics, tasks, cinematics, boosts, offline progression, prestige · monetization optional · success
measures: first-session completion, D1/D7, milestones, session length, revenue per active player.

Three priorities above everything else: the first five minutes must feel satisfying at once; players should
naturally recognise when fields, stores or warehouses need expansion; players should be able to look back at a
huge farm, a busy store and a warehouse full of forklifts and trucks.

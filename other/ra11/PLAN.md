# Farm Empire — the build plan and what was built

The phases follow the master plan's roadmap (§17). Each ships with the tests green, the place built and the docs
current.

## Phase 1 · Core — built

* The Rojo project, the generic engine (service loader, typed remotes with rate limits, signals, the client store,
  the UI theme, panels, device handling), the mock engine and the screenshot tools, lint config, the test runner.
* Data: crops (eight, four growth stages), the four business stages, the upgrade tree (five branches, 36
  upgrades, levels and prerequisites), the guidance (nine onboarding tasks, eight goals, the milestone), the shop.
* World: the layout (12 territories in two rows round the town, the zones and the fields), the territory builder
  (ground, fence, trees, the gate sign, the fields with outlined expansion zones, the stand, the shop, the
  warehouse and the centre with docks, the shed and machines, the trucks and forklift, the preview ghost with a
  Build prompt), the town (avenue, square, fountain, market board, leaderboards, the boost meter).
* Server: profiles with a session lock; cash and the income a minute; territories, spawning and visiting;
  tiles, planting, growth on timestamps, harvesting, PLANT ALL and the crop choice; the business tick (demand,
  service, the line, storage, trucks in bulk) and the bottleneck; buying upgrades and the recommendation; the
  machine's route; onboarding, goals and the milestone; the shared boosts; the Robux shop; offline settlement;
  analytics; an admin panel.
* Client: the HUD (cash, income, the business line, toasts, +$); the plants per tile and their stages, tap and
  walk-over harvesting, the crop bar; the task card with BUY, the goals, the milestone and the arrow; the
  UPGRADES panel by branch with the RECOMMENDED tag; the menu rail; the customers' line, workers and crates; the
  machines driving to the tiles they clear; trucks and the forklift; the opening and the reveals; harvest bursts,
  coins and sounds; the shop; the boost chip and panel; the welcome-back card.

## Phase 2 · Retention — built with phase 1

The bottleneck model and the recommendation, the stand-to-shop transformation with workers and a longer line,
the harvester tiers, the revenue feedback.

## Phase 3 · World — built with phase 1

Twelve territories, expansion zones with prices, the town, the boost meter, TOWN/HOME teleports.

## Phase 4 · Content — built

The warehouse, the centre, docks, forklifts, trucks in bulk, and the market board's daily orders (three a day for
a shop, a bulk contract for a centre, delivered out of stock for a bonus).

## Phase 5 · Polish — partly

Reveals, transformations, workers, bursts and sounds, the previews. A sound and sky pass is next.

## Phase 6 · Scale — built, tuning open

Prestige (a new region: the farm starts over with +25% a region, a star on the gate), the town's leaderboards from
OrderedDataStores, the first hour tuned on the mock play-through (the shop at about 28 minutes, the harvester at
about 17). Open: the store art, and tuning from live telemetry once it's published.

## Round 2 · the world pass — built

From the first live test (a fall into the void, overlaps, cramped plots, a thin hub): a base plate under the whole
map with a ring of hills and an invisible edge, streaming paused outside the loaded area; territories 200 x 180
with separate zones (front yard, three field blocks and the North field, the machine shed, the warehouse on the
lane, the pond and windmill at the back) and a farmhouse that grows with the stage; the previews as footprints,
not boxes; a town square with welcome arches, a three-tier fountain, the market hall, the leaderboard wall with
its podium, the boost tower, a bandstand, benches, lamps, flower beds and planters; a detail pass on the stand,
the shop, the warehouse, the shed and the gate.

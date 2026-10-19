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

## Round 3 · facing the road, build pads, the city — built

From the second live test (farms facing away, too much walking, fences over the road, weak signs, little guidance,
a plain hub, square crops, a poor arrow and GUI, slow money):

* **Layout.** Every farm's front (the gate, the stand, the build yard) faces the avenue; the south row is turned
  half round. Each zone has its own rectangle, and `tests/LayoutSmoke` checks none overlap, all sit inside the
  fence, every front faces the road and no city part stands inside a farm. The fence rails stop at the gate, the
  frontage and the lane, so no post or rail doubles up or crosses the road.
* **Build pads.** Eight pads in the build yard beside the spawn, each showing one upgrade (gold for the guide's,
  green when affordable, dark when not) with a sign of its name and price. Step on a pad to buy it; stand on it
  to buy the next level of the same upgrade. The UPGRADES panel is still there. `tests/PadSmoke` covers it.
* **The city.** The centre is a city: streets and blocks of fake buildings (shopfronts, awnings, window strips,
  roof tanks and antennas) round a big cobbled courtyard with arches, a fountain, benches and lamps; the
  leaderboard wall with its podium, a store ("coming soon": nothing to buy yet), the market hall and the boost
  tower.
* **Graphics.** Crops are real plants, one model per crop in four stages (strawberry, tomato, wheat, corn,
  blueberry bushes, pumpkin and melon vines, golden apple trees). The harvester, the tractor and the combine, the
  trucks and the forklift were rebuilt with more detail. Signs are framed boards with a title and a line.
* **Guidance.** A bouncing gold chevron with a word under it ("TAP TO PLANT", "HARVEST", "STEP HERE", "YOUR
  STAND"), a pulsing ring and a trail of glowing dots to the target. A step card shows "STEP n OF 9", a reward
  chip, a BUY button and a progress bar; every tutorial step pays a cash reward. A goals card at the left has
  progress bars and the next building with how close you are. A welcome card follows the opening flight.
* **GUI.** The RECOMMENDED tag sits inside its row with a gold outline. Price buttons read "BUY $80" in green or
  "NEED $80" on dark. Toasts and the business line are dark pills. A "+$n" floats up at the stand on every sale,
  and a burst plays round you when you buy.
* **Economy.** Crops pay about three times more and grow faster. The stand serves more. On the mock play-through
  the Fruit Shop ($5,000) comes at about 4 minutes and the Warehouse ($120,000) at about 23. The Distribution
  Centre ($2,000,000) is still ahead at 50 minutes, and the longest wait between buys is under 150 seconds.

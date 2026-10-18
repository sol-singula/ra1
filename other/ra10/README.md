# ra10 · Farm to Fleet

A farm-to-shipping-empire tycoon: plant a strawberry next to a shack and grow, day by day, into a full distribution
hub: fields, barns and animal pens outside; a proper shipping warehouse inside, with pallet racks, forklifts
weaving between them and semis backing into the dock doors. Six plots a server, side by side along a shared road,
so everyone watches everyone grow. Colourful, with ra9's matte, detailed look.

* Game: `games/ra10 - Farm to Fleet/` (Rojo project)
* [The store description](DESCRIPTION.md) · [screenshots](screenshots/)
* [The master plan](MASTER_PLAN.md) (the brief, art direction, the five stages, crops, animals, orders and
  vehicles, the come-back timers, the 100% guide, money, phases) · [the build plan and what was built](PLAN.md)

## Running the tests

`sh tools/run_tests.sh` from the game folder (needs Rust once, to build the Luau runner).

## Before it goes live

* Create the developer products and game passes (names and prices in `src/shared/Data/Shop.lua`) and set their
  ids in `src/shared/Constants.lua` (`PRODUCTS`, `PASSES`). Until then they're free in Studio and show SOON live.
* The store icon and thumbnails are still to make.

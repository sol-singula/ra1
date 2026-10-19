# ra11 · Farm Empire

A 12-player farming tycoon: a tiny fruit stand grows into a large automated farm, a busy retail shop, a warehouse
and a distribution centre with forklifts, trucks and loading docks. Not only growing crops: a connected business,
where production feeds inventory, inventory feeds sales, sales make cash and cash funds expansion. The player
sees the next problem (ripe fields waiting, crates piling up, a line at the counter, pallets stacking at the dock)
before the game tells them what to do about it.

* Game: `games/ra11 - Farm Empire/` (Rojo project, `FarmEmpire.rbxl` built from it)
* [The master plan](MASTER_PLAN.md) (the design: the loop, the bottlenecks, the first hour, the territories, the
  machines, the business stages, the economy, the camera, the look, retention, money, the module plan) ·
  [the build plan and what was built](PLAN.md) · [the store description](DESCRIPTION.md)
* [Screenshots](screenshots/) (from the mock engine through `tools/gameplay`)

## Running the tests

`sh tools/run_tests.sh` from the game folder (needs Rust once, to build the Luau runner): the server and the
client booting together, the first hour played through on the real numbers, the machines, the business stages,
the town's boosts, the shop and coming back.

## Before it goes live

* Create the experience on Roblox and publish `FarmEmpire.rbxl` (or `rojo serve` the project).
* Create the developer products and game passes (names and prices in `src/shared/Data/Shop.lua`) and set their
  ids in `src/shared/Constants.lua` (`PRODUCTS`, `PASSES`). Until then they're free in Studio and show SOON live.
* Add the `discord_log` secret for the analytics (see `src/server/GameKey.lua`).

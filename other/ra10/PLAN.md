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

## Next: Phase B

The map (six plots either side of the shared road, reserved land), stage 1 (the shack, soil, strawberry and
carrot), plant/grow/harvest/sell, the first minute and the guide's first chapter.

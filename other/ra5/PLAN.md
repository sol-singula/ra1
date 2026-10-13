# The Last Train (ra5): build plan and status

The design is the [master plan](MASTER_PLAN.md). This page tracks what the first build covers, how each item was
done, and what comes next. How to run and play it: [README](README.md).

## MVP: every "Must build" item (master plan §20)

| # | Must build | Status | How |
|---|---|---|---|
| 1 | Enclosed station lobby | ✅ | A Victorian train shed (iron arches, glass roof, lamp posts) and a concourse with the departure boards. `World/StationBuilder` |
| 2 | Hall of Records prototype | ✅ | The top record's stage (bronze crew statues with headshots, a miniature of their train, the plaque) and four more plaques; tap a plaque to inspect it. `RecordService`, `World/HallBuilder` |
| 3 | One modular train with connected cars | ✅ | Locomotive (cab, boiler, engine room), crew car, five cabin cars, gangways, 13 sliding outside doors. `World/TrainBuilder`, `World/Layout` |
| 4 | A persistent personal cabin | ✅ | One of 20 compartments per player, drawn from their save; anyone can visit, only the owner builds. `CabinService` |
| 5 | One polished region | ✅ | The Overgrown Line: forest lighting moods, fog, fir and oak forests, telegraph lines. |
| 6 | Three stop variants (+ a fourth) | ✅ | Ranger Station, Timber Yard, Signal Tower (5 km), Overgrown Platform (15 km), each with its own landmark, light and materials. `World/StopBuilder`, `Data/Stops` |
| 7 | Four core resource types | ✅ | Wood, scrap, parts, cloth, plus crew fuel and blueprints. `Data/Resources` |
| 8 | 2–3 minute scavenging timer with clear warnings | ✅ | 2:30 (+15 s Searchlight); 60 s warning, 20 s final call, horn, flashing beacons, red edges, a line to the nearest door. |
| 9 | Controlled travel, arrival and departure | ✅ | The train never moves: the stop slides in and out, the forest streams past (BulkMoveTo chunks), camera rumble, fades over the cuts. `TravelController` |
| 10 | One cabin chain of 10–15 upgrades | ✅ | 15, from the master plan's example chain, each with a visible change and a ghost preview. `Data/CabinItems`, `World/CabinBuilder` |
| 11 | One shared chain with 2+ stages | ✅ | Engine Overhaul (3 stages) and Scout Lamp (Searchlight, Radio Mast). `TrainService`, `Data/TrainUpgrades` |
| 12 | Server-owned distance and phase | ✅ | `ExpeditionService`: lobby → departing → traveling → arriving → scavenging → warning → … → ended. Clients only display. |
| 13 | Friend join and full-server messaging | ✅ | Exact-server teleport; Train Full with Wait for a Spot (honest retries), Join Another Friend, Start a New Expedition. `JoinService` |
| 14 | Safe late join | ✅ | Spawn aboard, a summary card, a contextual guide that never sends you out as the train leaves. |
| 15 | Simple records and the Hall | ✅ | Idempotent by expedition id, never shrinks, checkpointed at stops after 5 km and on shutdown; crew eligibility shown. |
| 16 | Mobile-first UI and performance | ✅ | Phone-scaled HUD, thumb-safe layout, lite forest on phones, accessibility settings respected. Real-device testing still to do after publishing. |
| 17 | Recovery for players left behind | ✅ | The signal hut: 3 fuses, the fuse box, the lever, then a trolley (instant with the Radio Mast). Only the bag is lost. `RecoveryService` |
| 18 | Telemetry for retention and the core loop | ✅ | Funnel events, live rows for `other/live.html?game=ra5`, Discord game log, feedback card. `AnalyticsService`, `GameLogService` |

Also in: the anti-cheat (speed, teleport, flying, request spam), rejoining a train after a disconnect, the
Discord log, Experience Notifications opt-in, and a "Do you like the game?" card with the train-specific
reasons.

## Explicitly postponed (master plan §20)

Monsters and combat, more regions, rescue vehicles, trading, PvP, skill trees, free placement, many furniture
sets, a paid shop, more currencies, physical train simulation, cutscenes. There are **no Robux products yet**: the
plan says to prove the loop first (§13, §22).

## Exploit checks (master plan §17)

| Case | Covered by |
|---|---|
| Collecting without reaching a pile | the server checks the phase, the distance (14 studs) and that this player hasn't taken it |
| Arbitrary amounts, repeated pickups | amounts come from the pile; each pile once per player; fuel cans once per crew |
| Upgrading without materials | `Formulas.canBuild` on the server; only what you hold, only what a stage still needs |
| Fake distance or records | distance, crew and records are server state only; nothing comes from a client |
| Bypassing Train Full | exact-server teleports only after a capacity check; Roblox enforces Max Players |
| Spamming joins, prompts, requests | per-player rate limits on every remote; the anti-cheat counts auto-clicker rates |
| Changing the local timer | the timer is the server's (`PhaseEnds`); the client only draws it |
| Duplicating through disconnects | session-locked saves; the bag isn't saved (banked only aboard) |

## Tests

`tools/run_tests.sh`: formulas (121 checks), the client smoke test (129: every panel, button, the travel scenery,
the stop sliding in, the guide, the left-behind screen), and the server smoke test (216, and about 210 without
DataStores: whole expeditions with a crew, a late joiner, someone left behind, running out of fuel, the record,
Train Full and retries, rejoining, feedback, analytics, the game log and the anti-cheat). Lint: selene and stylua
clean.

## Next (after the first playtests)

1. Publish, then watch the funnel on the dashboard: if people leave before the first stop, fix onboarding and
   the first arrival; if they scavenge but don't return, tune the timer and stop layouts (§22 decision rules).
2. Real train sounds (whistle, horn, brakes, door chime, wheel rumble) in place of the shared effects.
3. More stops for the Overgrown Line, then the second region (§9).
4. Only then, ethical offers (cosmetic cabin sets, a supporter pass) per §13, never pay-to-skip the timer.

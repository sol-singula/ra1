# Survive the 6-7 (ra6): build plan and status

The design is the [master plan](MASTER_PLAN.md). This page tracks what the first build covers, how each part was
done, and what comes next. How to run and play it: [README](README.md).

## The roadmap (master plan §15)

| Phase | Status | How |
|---|---|---|
| 1. Prototype | ✅ | Running, sprinting with stamina, a dodge with i-frames, the camera (Invisicam: trees and walls fade instead of blocking), the Rusty Axe and Kermy's chase, in the forest round the camp. Every number in `Constants`. |
| 2. Vertical slice | ✅ | A whole run: gathering (`ResourceService`), crates and findings (`LootService`, `WorldService`), crafting at four stations (`CraftService`, `Data/Recipes`), the hotbar and the bag (`InventoryService`), the camp's four tiers (`CampService`, `World/CampModels`), day, dusk, night and dawn (`RunService`), six nights of monsters and Mega Kermy on the seventh (`MonsterService`, `BossService`, `World/Rigs`), the win, the wipe and the results. |
| 3. Multiplayer | ✅ | Six-player runs with a roster that locks at night 1 (late joiners wait for the next run), revives and getting up by the fire, ghosts until dawn, rejoining your run for 15 minutes, the lost pack, friends-first leaderboards (`LeaderboardService`), joining friends, new runs and free private runs (`JoinService`), server-side everything, saves with a fallback when DataStores are down (`PlayerDataService`). |
| 4. Polish | ✅ | The phone-first HUD, panels and buttons (`HudController`, `PanelController`, `InputController`), a guide for the first five minutes (`TutorialService`, `TutorialController`), every tell drawn on the ground, hand-made animation for survivors and monsters (`AnimController`, `Rigs`), effects for every action (`FxController`), lighting that follows the clock and the night's event (`LightingController`), music and sound (`AudioController`), lite mode on phones (`PerformanceController`). |
| 5. Closed test | 🟡 | Analytics (the first-five-minutes funnel, run completion, where runs end, downs and revives), the Discord game log, the feedback card and the dashboard tab are in. Still to do: publish, small playtests, tune from the numbers. |
| 6. Launch | ⏳ | After the closed test: public release with this biome, then new content on the plan's terms. |

## The launch scope (§17)

| Feature | Scope | Status |
|---|---|---|
| Responsive running, jumping, and combat | Required | ✅ server-checked hits with tells, a dodge with i-frames and a ping grace, knockback |
| One polished forest biome | Required | ✅ the forest, the camp's clearing, the creek and pond, outcrops, 13 kinds of findings placed at random |
| Six-player target with solo viability | Required | ✅ how many monsters come, their health and Mega Kermy's scale with the team; a solo player can get up by the fire |
| Functional hotbar and inventory | Required | ✅ 6 hotbar slots, a 12+ slot backpack, gear slots, tap to move, use / wear / drop, rarity colours |
| Gathering, crafting, and camp upgrades | Required | ✅ trees, rocks, bushes, scrap; 28 recipes at 4 stations; 4 camp tiers built together |
| Signature monster plus supporting enemies | Required | ✅ Kermy plus Snapcap, Grinwolf, Pinecone Pelter, Stumpy and the Mimic, golden elites |
| Complete run with final boss | Required | ✅ seven days, six nights, Mega Kermy, the win and the wipe |
| Permanent progression and saves | Required | ✅ levels, kits, perks, weapon mastery, the book, looks, titles, records |
| Friend leaderboards and achievements | Required | ✅ 8 boards (friends first), 31 achievements |
| Free private servers | Target | ✅ PRIVATE RUN reserves a server; Roblox private servers should be set to free when publishing |
| Multiple biomes, a big shop, trading, dozens of weapons | Later | not built |

## The first five minutes (§4)

| When | What happens | How |
|---|---|---|
| 0:00 | You spawn by the campfire, holding a Rusty Axe, friends around you | `TutorialService` step 1 with the arrow, the beam and the compass marker |
| 0:15 | Chop a tree: chips fly, "+1 🪵" pops up, the tree tips over | ACT says CHOP next to a tree; aim help turns the swing |
| 0:45 | Build the Workbench: hold its glowing blueprint's prompt, it goes up in a puff | the camp's tier-1 blueprints are placed at the start of every run |
| 1:30 | Open a crate (there are always a few by the camp), hold what you found | the hotbar slot glows; the guide moves on when you hold it |
| 2:30 | Kermy shows himself at the edge of the camp, then slips back into the trees | `MonsterService` "first sighting", his roar, a callout |
| 3:30 | Dusk: "Get back to camp!" | the horn, the sky turning, the guide's last steps |
| 3:45 | Night 1: survive, dodge his lunge | the red line on the ground, DODGE, revives |

Returning players skip the guide; SKIP ends it at any time. Steps the team already did (the Workbench) are
skipped, so it works alone or with friends.

## Combat and enemies (§5, §10)

Every enemy has a silhouette, a detection rule, one distinctive behaviour, a tell you can read and a reason to
fight it (`Data/Enemies`): Kermy's "SIX... SEVEN!" lunge (and his faceplant when he misses), the Snapcap's crouch
and leap, the Grinwolf pack's circling and red-eyed howl before a dart, the Pelter's lob and hide, Stumpy's slow
wind-up and wall-smashing, the Mimic's breathing crate. Every attack is checked on the server and hits each player
at most once; a dodge's i-frames get a grace of up to 0.15 s for the player's ping so dodges never feel random.
Weapons each have a role (§5): axes chop and fight close, clubs stagger, spears reach, bows need arrows, traps
need setting, support items heal and rescue. Rarer weapons hit harder but older ones keep their role.

## Safety and fair play (§14)

| Case | Covered by |
|---|---|
| Hits, damage, loot, crafting, upgrades | all on the server, with range, arc and cooldown checks; aim help only picks targets the server would accept |
| Speed, teleporting, flying | `AntiCheatService` (with grace after the server's own moves: dodges, knockbacks, Mega Kermy's grab) |
| Spamming requests | per-player rate limits on every remote; auto-clicker rates add strikes; enough strikes kick (admins are only logged) |
| Griefing the camp | there's no friendly fire, and nobody can take apart what the team built |
| Leaving mid-run | your run waits 15 minutes; your things wait by the fire |
| Chat and feedback | Roblox's filters; the feedback card's text goes through `TextService` before it's logged |

## Making money (§13)

There are **no Robux products yet.** The plan says the game must be fun for free first; looks are earned by
playing (levels and achievements). Paid cosmetics come only after retention is established, never power.

## Tests

`tools/run_tests.sh`: formulas (95 checks), the terrain (23), the client smoke test (254: the real server and
client together on a phone screen, played through the client's own buttons) and the server smoke test (286, and
274 without DataStores: whole runs, the win and the wipe, rejoining, friends, leaderboards). Lint: selene and
stylua clean.

## Next (after the first playtests)

1. Publish, then watch §16's numbers on the dashboard: if people leave in the first minute, fix the spawn and the
   first objective; if they leave before the first night, make day 1's exploration and rewards better; if they
   go down without knowing why, make the tells clearer.
2. Tune the night budgets, Kermy's lunge and Mega Kermy's health from real runs (all in `Constants`).
3. A real "SIX... SEVEN!" voice line and forest sounds in place of the shared effects.
4. Only then: a second biome, more monsters and weapons, paid looks per §13.

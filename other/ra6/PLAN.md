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
| 0:00 | You spawn by the campfire, holding a Rusty Axe, friends around you; five young trees stand right there | `TutorialService` step 1: "Chop any tree", the arrow and the beam to the nearest one (it lights up; whichever tree you walk to becomes the one) |
| 0:05 | Chop: chips fly, "+1 🌳" pops up, two hits and the sapling tips over, "+10 XP ✨" | `MapLayout.SAPLINGS` (two hits of the Rusty Axe, 4 wood each, back every run); every first the guide asks for pays XP (`Constants.XP.guide`) |
| 0:20 | Build the Workbench (6 wood): hold its glowing blueprint's prompt, it goes up in a puff | the camp's tier-1 blueprints are placed at the start of every run; the blueprint glows |
| 0:40 | Open the starter crate by the fire: a club or a spear, a torch and berries; hold the weapon | `LootService` places it 12-15 studs from the fire with those in it; the hotbar slot glows |
| 0:50 | Kermy shows himself at the edge of the camp, "SIX... SEVEN!", then slips back into the trees | `MonsterService` "first sighting", his roar, a callout (§4 had this at 2:30: the first playtest moved the hook into the first minute) |
| 1:00 | A Snapcap jumps out of the bushes at someone: "A Snapcap! Hit it!", it glows red; the first kill, "+25 XP" | `MonsterService` "ambush" (one, by day, harmless-ish); the guide shows LOOK OUT! whatever step you're on, then goes back to it |
| 1:20 | "Explore! Crates and stone are out in the forest": the arrow points at the nearest crate | the Stone Axe and Stone Spear need stone; crates sit clear of the trees' crowns |
| 2:50 | With 40 s of day left: "Get back to camp before dark!" | `Constants.GUIDE_DUSK_WARNING` |
| 3:30 | Dusk: the horn, the sky turning | the guide's last steps |
| 3:42 | Night 1: survive, dodge his lunge | the red line on the ground, DODGE, revives |

Returning players skip the guide; SKIP ends it at any time. Steps the team already did (the Workbench) are
skipped, so it works alone or with friends. Swinging at a giant or an Ancient Pine says it's too big to chop.

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

`tools/run_tests.sh`: formulas (96 checks), the terrain (23), the client smoke test (301: the real server and
client together on a phone screen, played through the client's own buttons, plus PC clicks, the hold pose and
which way every swing goes) and the server smoke test (301, and 288 without DataStores: whole runs, the win and the
wipe, rejoining, friends, leaderboards). The mock DataStore now refuses what Roblox's refuses (lists with gaps,
mixed keys, NaN). Lint: selene and stylua clean.

The mock engine has no real physics, rendering or Roblox rigs, so some things only show up in a real play test.
The first one found these, now fixed: every arm animation was mirrored (on a Roblox shoulder a positive pitch swings
the arm forward; chops, thrusts and the 6-7 all went backwards); held items were gripped mid-handle with the axe's
blade facing back (now a hold pose, a grip at the end of the handle and a per-item hold); on PC a click aimed at a
point on a sphere round the camera, so it often swung backwards and missed the tree (now the swing goes where you
look and turns to the tree or rock most in front of you); a rock beside or behind you took the swing meant for the
tree in front; the guide could point at a giant that can't be chopped; and the guide's arrow spun inside the
tree's trunk with its beam running into it (now beside the trunk, and the tree glows); trunks ran up inside the
crowns, so a tree the camera faded (Invisicam) showed its trunk as a line, and birches had full black rings.

The second playtest: the crafting panel's costs read "0/3 2/4" with nothing else, because Roblox draws no emoji
newer than 2019 (wood 🪵 and stone 🪨 are blank; seven of the game's icons were): every cost now names its
material, and the icons are ones Roblox has. The guide pointed at one tree (the nearest, refreshed every two
seconds) and the crate it pointed at could sit under a tree's crown: now "chop any tree", the client picks the
nearest as you move, and crates, blueprints and the Snapcap light up. And the first minute was a walk: the trees
were 78 studs away and Kermy came at 2:30 (see the table above for what it is now).

An audit for the rest turned up, also fixed: the menu's Reset Character left you a frozen body for good (the server
can't stop the client's character dying, and characters don't come back by themselves here); the campfire's Feed
and Cook prompts, and a station's Use, Repair and Reinforce, hid each other (Roblox shows one prompt per key); a
click on a panel or the HUD went through to the world (a swing, eating the held food); reading a diary page broke
every save after it (a list with gaps); downed survivors could still jump (the place used JumpPower); ghosts
watching a teammate saw nothing streamed in round them; the phone HUD was sized for the whole screen, not the
part inside Roblox's top bar; a downed survivor saw their own Revive prompt; ACT could stay held after a thumb
slid off it, and held in goo it sent Mash every frame; key hints never showed; stumps were stretched on the wrong
axis; round rocks collided as their boxes. Still open: most of the sound effects are private uploads that only
play for the account that owns them (see the README).

## Next (after the first playtests)

1. Publish, then watch §16's numbers on the dashboard: if people leave in the first minute, fix the spawn and the
   first objective; if they leave before the first night, make day 1's exploration and rewards better; if they
   go down without knowing why, make the tells clearer.
2. Tune the night budgets, Kermy's lunge and Mega Kermy's health from real runs (all in `Constants`).
3. A real "SIX... SEVEN!" voice line and forest sounds in place of the shared effects.
4. Only then: a second biome, more monsters and weapons, paid looks per §13.

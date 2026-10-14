# Hold the Castle (ra7): build plan and status

The design is the [master plan](MASTER_PLAN.md). This page tracks what the first build covers, how each part was
done, and what comes next. How to run and play it: [README](README.md).

## The build order (master plan §24)

| Phase | Status | How |
|---|---|---|
| 1. Lock the design | ✅ | The master plan, plus first numbers for every open question (§28): 24 players, about 1 in 4 turned (nobody under 4 players), build time 6-8 minutes by player count, 12-minute fight, drain 0.8%/s per extra monster up to 4%/s. All in `Constants`. |
| 2. The core loop | ✅ | `MatchService`: hangout → build → plague → fight → last stand → ended. `TeamService` puts everyone on the dwarves, the plague turns some, dead dwarves come back as monsters. `ShrineService`: three shrines that drain, fall and open the way on. |
| 3. Building | ✅ | Stone, wood and gold nodes that regrow (`ResourceService`); snap-to-grid shared blueprints that rise as they're hammered, breaking and fixing, traps and stations, upgrades, Camp → Town → Castle (`BuildService`, `Data/Pieces`, `World/PieceModels`). |
| 4. Jobs | ✅ | 5 dwarf and 5 monster jobs, each a main move, a special and a trait (`Data/Jobs`, `CombatService`); Job Boards for dwarves, a picker at the spawn for monsters; monster levels and a time bonus during the match. |
| 5. Make it pretty | ✅ | A bright cartoon valley, castle pieces and costumes from plain parts (`World/Kit`, `MapBuilder`, `Costumes`); hand-made animation for players and NPCs; effects for every move; lighting that follows the match; music by phase; phone controls; the first 5 minutes; the big moments (the scare, the plague, a shrine falling, the last stand). |
| 6. Test and launch | 🟡 | Tests, lint, the game picture and icon (3 versions each: building, attack, last stand) are done. Still to do: publish, a small test with real players, a full 24-player server, cheap phones. |
| 7. Grow | ⏳ | New maps, jobs, seasons, events, clubs: after launch. |

## The first 5 minutes (§12)

| When | What happens | How |
|---|---|---|
| 0:00 | You spawn in the camp; a glowing rock pile right by you; the big HELP BUILD THE CASTLE sign | `TutorialService` step 1, a sparkle trail and bouncing arrow (`TutorialController`) |
| 0:10 | Tap the rocks: stone, a number pops up | MAIN does the right thing next to a node |
| 0:30 | Bring it to a glowing blueprint and hammer it: "You helped build this!" | the camp's starter plan is placed as blueprints at the start |
| 1:00 | The first choice: stronger gate, a tower or a thicker wall | three big buttons; the pick becomes a blueprint (or an upgrade) |
| | Pick a job at the Job Board | the board's prompt opens the jobs panel; keeping your job counts |
| 2:00 | The sky dims, a horn, monsters on the far hill | the "scare" lighting, watchers on the hill who wake if you hit them |
| 2:50 | A scout attacks: swing at it | scouts every 70 s until 45 s before the plague |
| | When the plague comes, hold the shrines | the last guide step; players who join during the fight get one line as a monster |

## Safety and fair play (§21)

| Case | Covered by |
|---|---|
| Hits, damage and kills | all on the server, with a wind-up and range and arc checks; aim help only picks targets the server would accept |
| Building without materials, in the wrong place, too much | the server checks the zone, the cells, the shrine clearing, the bag, 6 blueprints per player and 220 pieces per match |
| Wrecking your own castle | dwarves can't damage pieces at all; only monsters' moves hit the castle |
| Speed, teleporting, flying, walking through walls | `AntiCheatService` (with grace after the server's own moves: knockbacks, the charge, respawns) |
| Spamming requests | per-player rate limits on every remote; auto-clicker rates add anti-cheat strikes, and enough strikes kick (admins are only logged) |
| Chat | Roblox's filters; the feedback card's text goes through `TextService` filtering before it's logged |
| Reporting | the MORE panel shows how to report with Roblox's menu |

Not yet: kicking players who quit matches early too often (§21), which needs real numbers first.

## Making money (§18)

There are **no Robux products yet**: looks are bought with coins earned by playing. The plan says the game must
be fun for free first; when we add paid looks (skins, effects, emotes, poses, flags, a looks-only season pass),
they go in the same shop, never in a pop-up during a match, and never make anyone stronger.

## Tests

`tools/run_tests.sh`: formulas (95 checks), the client smoke test (232: every server event, every HUD, action and
build button, the guide, the horde drawn and interpolated, every effect, the gate opening, the lighting and music
following the phase, every panel including the shop's 3D preview, the monster picker and the results), and the
server smoke test (290, and 291 without DataStores: whole matches from the hangout to the next match, both ways to
win). Lint: selene and stylua clean.

## Next (after the first playtests)

1. Publish, then watch the numbers in §26 on the dashboard: if people leave before their first wall, fix the first
   minute; if dwarves almost never win (or always win), tune the drain, the horde and the plague share first.
2. A full 24-player test and a week of cheap-phone tests (§22); lower the piece and NPC limits if needed.
3. Castle-specific sounds (hammers on stone, the horn, the shrine falling, monster roars) in place of the shared
   effects.
4. Only then: a second map, new jobs (§8, §9), seasons and paid looks per §18.

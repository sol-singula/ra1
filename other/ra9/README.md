# ra9 · Turf Wars

A fast first-person team-warfare game after Mineplex Turf Wars, in the look of SUPERHOT: a plain white geometric
world where the only colours are the teams, red and blue. Two teams build defences, then fight with bows; every
kill pushes the frontline toward the enemy's base until one team runs out of turf. Up to 40 players, no lobby, the
next map loads in the same server.

* Game: `games/ra9 - Turf Wars/` (Rojo project, `TurfWars.rbxl` built from it)
* [The master plan](MASTER_PLAN.md) (the design brief, the art direction and the decisions) ·
  [the build plan and what was built](PLAN.md)
* [Map renders](screenshots/) (from the mock engine through `tools/gameplay`)
* Store art: [thumbnails](thumbnails/README.md), [ads (no text)](ads/README.md), [icon](icon/README.md)

## The maps

| Castle Clash | Frostbite |
|---|---|
| ![](screenshots/castle_overview.png) | ![](screenshots/frost_overview.png) |
| **Jungle Rush** | **Dust Devil** |
| ![](screenshots/jungle_overview.png) | ![](screenshots/dust_overview.png) |

## Running the tests

`sh tools/run_tests.sh` from the game folder (needs Rust once, to build the Luau runner): the rules and every map
(fair, closed, open lanes), a whole match from the server's side, the same through the real client, the bots, and
what goes out to the Discord log and the analytics (LogSmoke).

## Publishing checklist (once a place exists)

1. Create the experience on Roblox, publish `TurfWars.rbxl` (or `rojo serve` the project).
2. Server Size 40. Game Settings, Security: Allow HTTP Requests on (the Discord log and analytics).
3. Creator Dashboard, the experience, Secrets: add the studio's game key as a secret named `discord_log`, allowed
   for the domain `kvedatksqkcsgivntskb.supabase.co` (the same key as the other games). Without it the game runs but
   sends nothing, and the server's log (F9, Server) says why once a minute.
4. Record the place and universe ids here.

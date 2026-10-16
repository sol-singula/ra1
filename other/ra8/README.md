# ra8 · The Endless Voyage

A raft-building ocean survival game for Roblox: start on a 2 x 2 driftwood platform, cast your rod at what drifts past,
build, craft, raise the sail, and go find what's out there. Your raft and everything you've found persist; a
voyage is where the risk is.

* Game: `games/ra8 - The Endless Voyage/` (Rojo project, `TheEndlessVoyage.rbxl` built from it)
* [The master plan](MASTER_PLAN.md) · [the build plan and what was built](PLAN.md)
* [Gameplay renders](screenshots/README.md) · [thumbnails and the icon](thumbnails/README.md) · [item icons](items/README.md)
* The dashboard (`other/live.html`) has an `ra8` entry: where each player is (raft / water / island / visiting),
  the voyage's state, raft tier and tiles, level, voyages, finds aboard, health, idle.

Place `133187155481262`, universe `10771148207`.

## Publishing checklist

1. Open `TheEndlessVoyage.rbxl` in Studio (or `rojo serve` the project) and publish to the experience.
2. Game Settings: allow HTTP requests (analytics and the game log), enable Studio API access for testing saves.
3. Secrets: `discord_log`, the studio's shared game key, for the domain `kvedatksqkcsgivntskb.supabase.co`.
4. Server Size 8 (a raft spot each), Server Fill: customize, keep 2 slots (for friends joining). Private servers free.
5. Upload the icon (`icon/`) and the six thumbnails (`thumbnails/`).
6. Run `tools/run_tests.sh` before every publish.
7. Optional: upload the 2D item icons (`items/README.md`) so the bag shows them instead of the 3D model pictures.

## The Discord log

The game posts batches every few seconds to the studio's Supabase function `roblox-game-log`, which posts them into
the studio's private game-logs channel with the same bot as the other games; every entry starts with "ra8 · ".
Nothing to set up on Discord or Supabase. On Roblox:

1. Creator Dashboard → the experience → Secrets: a secret named `discord_log`, its value the studio's shared game
   key (the one the other games use), the domain `kvedatksqkcsgivntskb.supabase.co`. The analytics use it too.
2. Studio → Game Settings → Security: Allow HTTP Requests.
3. Join a live server (Studio never sends). The server starting and your join show within seconds.

Nothing? Press F9 in the game, Server log, and look for `[GameLog]`: it says whether the secret is missing, HTTP
requests are off, the domain isn't allowed or the key is wrong. A server that started before the secret existed
picks it up within a minute (older builds: shut the servers down from the Creator Dashboard). The function's own
log is in Supabase → Edge Functions → roblox-game-log → Logs ("not allowed" = a wrong key).

What goes in: servers starting and stopping, joins and leaves (with the session's stats), tier-ups, feedback, the
anti-cheat's flags, the chat, and every player's every event as "ra8 · 📜 Activity" lines every 15 seconds. Each
line has the time into the session, who, what happened, the guide's step, the raft's size, where they were and
what they were doing. If the shared channel gets too busy, set `GAME_LOG_ACTIVITY = false` in `Constants.lua` and
publish: the rest still goes in.

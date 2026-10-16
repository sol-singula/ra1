# ra8 · Build the Biggest Raft

A raft-building ocean survival game for Roblox: start on a 2 x 2 driftwood platform, cast your rod at what drifts past,
build, craft, raise the sail, and go find what's out there. Your raft and everything you've found persist; a
voyage is where the risk is.

* Game: `games/ra8 - The Endless Voyage/` (Rojo project, `TheEndlessVoyage.rbxl` built from it; the folder and the
  place file keep the working title, The Endless Voyage)
* [The master plan](MASTER_PLAN.md) · [the build plan and what was built](PLAN.md)
* [Gameplay renders](screenshots/README.md) · [store thumbnails and the icon](thumbnails/README.md) ·
  [ad images](ads/README.md) · [item icons](items/README.md)
* The dashboard (`other/live.html`) has an `ra8` entry: where each player is (raft / water / island / visiting),
  the voyage's state, raft tier and tiles, level, voyages, finds aboard, health, idle.

Place `133187155481262`, universe `10771148207`.

## Publishing checklist

1. Open `TheEndlessVoyage.rbxl` in Studio (or `rojo serve` the project) and publish to the experience.
2. Studio, File → Experience Settings → Security: Allow HTTP Requests (analytics and the game log), and Enable
   Studio Access to API Services for testing saves.
3. The `discord_log` secret ([the Discord log](#the-discord-log) below).
4. Server Size 8 (a raft spot each), Server Fill: customize, keep 2 slots (for friends joining). Private servers free.
5. The game's page: the name **Build the Biggest Raft** and the description, the icon (`icon/icon_main.png`) and the
   six store thumbnails (`thumbnails/`, in order): Creator Dashboard → the experience → Configurations → Places →
   the start place ([how](thumbnails/README.md#upload-them)).
6. Run `tools/run_tests.sh` before every publish.
7. Optional: an Ads Manager campaign with the ten text-free pictures in `ads/` ([how](ads/README.md#run-them)).
8. Optional: upload the 2D item icons (`items/README.md`) so the bag shows them instead of the 3D model pictures.

## The Discord log

The game posts batches every few seconds to the studio's Supabase function `roblox-game-log`, which posts them into
the studio's private game-logs channel with the same bot as the other games; every entry starts with "ra8 · ".
Nothing to set up on Discord or Supabase. On Roblox:

1. Creator Dashboard (create.roblox.com/dashboard/creations) → Build the Biggest Raft → **Secrets** → **Create
   Secret**. Only the experience's owner (or the group's owner, for a group game) can add one.
   * **Name**: `discord_log`
   * **Secret**: the studio's shared game key, the same value as the other games' `discord_log` (paste it from
     wherever the studio keeps it; never put it in this repo)
   * **Domain**: `kvedatksqkcsgivntskb.supabase.co`

   The analytics use it too.
2. Studio, File → Experience Settings → Security: Allow HTTP Requests on, then publish.
3. Join a live server (Studio never sends: a playtest can't read live secrets). The server starting and your join
   show within seconds.

Nothing? Press F9 in the game, Server log, and look for `[GameLog]`: it says whether the secret is missing, HTTP
requests are off, the domain isn't allowed or the key is wrong. A server that started before the secret existed
picks it up within a minute (older builds: shut the servers down from the Creator Dashboard). The function's own
log is in Supabase → Edge Functions → roblox-game-log → Logs ("not allowed" = a wrong key).

What goes in: servers starting and stopping, joins and leaves (with the session's stats), tier-ups, feedback, the
anti-cheat's flags, the chat, and every player's every event as "ra8 · 📜 Activity" lines every 15 seconds. Each
line has the time into the session, who, what happened, the guide's step, the raft's size, where they were and
what they were doing. If the shared channel gets too busy, set `GAME_LOG_ACTIVITY = false` in `Constants.lua` and
publish: the rest still goes in.

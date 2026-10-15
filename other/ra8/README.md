# ra8 · The Endless Voyage

A raft-building ocean survival game for Roblox: start on a 2 x 2 driftwood platform, cast your rod at what drifts past,
build, craft, raise the sail, and go find what's out there. Your raft and everything you've found persist; a
voyage is where the risk is.

* Game: `games/ra8 - The Endless Voyage/` (Rojo project, `TheEndlessVoyage.rbxl` built from it)
* [The master plan](MASTER_PLAN.md) · [the build plan and what was built](PLAN.md)
* [Gameplay renders](screenshots/README.md) · [thumbnails and the icon](thumbnails/README.md) · [item icons](items/README.md)
* The dashboard (`other/live.html`) has an `ra8` entry: where each player is (raft / water / island / visiting),
  the voyage's state, raft tier and tiles, level, voyages, finds aboard, health, idle.

## Publishing checklist

1. Open `TheEndlessVoyage.rbxl` in Studio (or `rojo serve` the project) and publish to the experience.
2. Game Settings: allow HTTP requests (analytics and the game log), enable Studio API access for testing saves.
3. Secrets Store: `discord_log` (the studio's shared key for the analytics and game-log functions).
4. Max players 6 (one plot each). Private servers free.
5. Upload the icon (`icon/`) and the six thumbnails (`thumbnails/`).
6. Run `tools/run_tests.sh` before every publish.
7. Optional: upload the 2D item icons (`items/README.md`) so the bag shows them instead of the 3D model pictures.

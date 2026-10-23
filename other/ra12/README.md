# ra12 — Mutation Meadow

The code is in [`games/ra12 - Mutation Meadow/`](<../../games/ra12 - Mutation Meadow>). This is the M1 scaffold: the
project files, every tuning number in `src/shared/Config/`, the boot loaders, the shared utilities and a lune test
suite. There is no gameplay yet; each later milestone adds its services to `Loader.ORDER`.

## Tools

Install [Rokit](https://github.com/rojo-rbx/rokit) and run `rokit install` in the game folder. It installs rojo
7.4.4, selene 0.27.1, StyLua 2.0.2 and lune 0.11.1.

## Run it

- Studio: run `rojo serve` in the game folder and connect from the Rojo plugin, or build a place file with
  `rojo build -o MutationMeadow.rbxl` (place files are gitignored). The output should print `[Loader] ready`.
- Tests: `tools/run_tests.sh` runs every `tests/*.spec.luau` under lune with a fake engine
  (`tests/mock/Engine.luau`) and exits non-zero on any failure.
- Lint and format: `selene src` and `stylua --check src tests`.

## Layout

| Path | What it is |
|---|---|
| `src/shared/Config/` | One frozen `Config` table; each child file is one table of numbers |
| `src/shared/Signal.lua`, `Clock.lua`, `Types.lua` | Shared utilities |
| `src/server/Loader.lua` | `PLAN` (all 21 services in boot order) and `ORDER` (the ones that exist so far) |
| `src/server/DevConfig.lua` | Who may use dev tools: Studio, or a UserId in `Config.AdminUserIds` |
| `src/client/ControllerLoader.lua` | The client mirror of the loader |
| `tests/` | The specs, the runner and the mock engine |

## To do before launch

- `Config.AdminUserIds` is `{ 0 }`: fill in Mason's Roblox UserId.
- Every badge and Catalog id is 0: create them on Mason's account.

# Roblox games

Every game has a short ID: `ra1` means "Roblox game A1", `ra2` is the next one, and so on.

```text
games/                      the games themselves (Rojo projects you open and run)
  ra1 - Mystery Morph Restaurant/
  ra2 - Steal a Dragon/
  ra3 - Raid a Planet/
  ra4 - Snipe a Noob/
  ra5 - The Last Train/
other/                      everything else: READMEs, screenshots, design docs
  ra1/
  ra2/
  ra3/
  ra4/
  ra5/
  analytics/                the live dashboard's Supabase function (live.html reads it)
  live.html                 the live analytics dashboard for every game (switch games at the top)
```

| ID | Game | Code | Docs |
|---|---|---|---|
| ra1 | Mystery Morph Restaurant | [`games/ra1 - Mystery Morph Restaurant/`](<../games/ra1 - Mystery Morph Restaurant>) | [How to run and play](ra1/README.md) · [Screenshots](ra1/screenshots/README.md) · [Game design document](ra1/GDD_README.md) |
| ra3 | Raid a Planet | [`games/ra3 - Raid a Planet/`](<../games/ra3 - Raid a Planet>) | [How to run and play](ra3/README.md) · [Plan](ra3/PLAN.md) · [Thumbnails](ra3/thumbnails/README.md) |
| ra2 | Steal a Dragon | [`games/ra2 - Steal a Dragon/`](<../games/ra2 - Steal a Dragon>) | [How to run and play](ra2/README.md) · [Screenshots](ra2/screenshots/README.md) · [Plan](ra2/PLAN.md) · [UI guidelines](ra2/UI_GUIDELINES.md) · [Thumbnails](ra2/thumbnails/README.md) · [Publish checklist](ra2/PUBLISH.md) |
| ra4 | Snipe a Noob | [`games/ra4 - Snipe a Noob/`](<../games/ra4 - Snipe a Noob>) | [How to run and play](ra4/README.md) · [Plan](ra4/PLAN.md) · [Thumbnails](ra4/thumbnails/README.md) |
| ra5 | The Last Train | [`games/ra5 - The Last Train/`](<../games/ra5 - The Last Train>) | [How to run and play](ra5/README.md) · [Plan](ra5/PLAN.md) · [Master plan](ra5/MASTER_PLAN.md) · [Thumbnails](ra5/thumbnails/README.md) · [Screenshots](ra5/screenshots/README.md) |

To run a game, open a terminal in its folder under `games/` and run `rojo serve`, or double-click the prebuilt
`.rbxl` file there. Each game's README in `other/` has the details.

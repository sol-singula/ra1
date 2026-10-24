# Mutation Meadow: release checklist (§11.5)

Nothing here is done from the repo. Each item is a step on Mason's account or in Studio.

## Before publishing

- [x] **`Config.AdminUserIds`** (`src/shared/Config/init.lua`) holds Mason's Roblox UserId (`{ 11787294097 }`).
  Every DevCommand (capture included) is Studio only: on a live server even this id is dropped as `dev_gate`.
- [ ] **Every Catalog and badge `id` is created and filled in.** That's the 29 store items and 10 badges listed in
      `docs/ids-todo.md`, all made on Mason's own account. Then run `RELEASE=1 tools/run_tests.sh Release`: it
      fails while any id is still 0.
- [ ] **Private servers** are on, at 99 R$ a month (Creator Hub > Monetization > Private Servers).
- [ ] **Store art is uploaded:** the 1024×1024 icon and the 1920×1080 thumbnails from the M6 capture scenes.
  In Studio (capture is Studio only), set the viewport to exactly 1920×1080 (1024×1024 for the icon), then use the
  DevCommand `capture <scene>` (street, offline_before, offline_after, golden_reveal, block_party_rain,
  block_party_golden, pedestals, icon), `capture hud off`, `capture guides on` (warns when the viewport size is
  wrong) and `capture size`. In golden_reveal, `capture reveal` plays the Golden reveal and the farmer's surprise.
- [ ] **Every analytics event is verified** (M10, `docs/analytics.md`). Run a Studio playtest with the Analytics
      debug view, and do one test join with ad LaunchData `{"src":"ad","c":"test"}` to check that `ad` shows in
      CustomField01 on every event.
- [ ] **The §11 build checklist is all ticked**, as below.

## §11 build checklist

**In the repo** (`tools/run_tests.sh`, `selene src`, `stylua --check src tests`, `rojo build`):
- [x] Every screen scales with the viewport, keeps to CoreUISafeInsets, and every tap target is at least 48 px
      (`tests/UI11.spec.luau`).
- [x] The HUD has no overlaps on iPhone SE, iPhone 14 Pro Max, iPad and 1080p desktop, and Patch's toast sits at the
      top (`tests/UI11.spec.luau`). This uses a layout model of the GUIs, not the Studio device emulator itself.
- [x] Streaming is on (64 / 256). The street pieces are Persistent, plots are Atomic, your own plot is
      PersistentPerPlayer, a visit streams the plot in first, and plots streaming out don't break the client
      (`tests/Streaming.spec.luau`, `tests/UI11.spec.luau`).
- [x] Reduced effects cut particles by 75% and turn off the rain sheet. Mutation sparkles are pooled. `State`
      replication stays under 4 KB/s with 8 full plots (`tests/Perf.spec.luau`).
- [x] The Lune soak passes: 8 players over 48 virtual hours (`tests/Soak.spec.luau`).

**In Studio** (see `docs/soak.md`):
- [ ] All 4 emulated devices show every screen with no clipping.
- [ ] A walk down the street with network simulation shows no errors, and a far plot renders within 2s of a visit.
- [ ] Low-end phone, 8 players, every plot full: client frame time ≤ 33 ms and server heartbeat ≥ 55 Hz.
- [ ] The live 2-hour soak passes its thresholds.

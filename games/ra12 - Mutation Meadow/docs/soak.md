# Mutation Meadow: soak tests (§11.4)

## Lune soak (in the repo)

`tests/Soak.spec.luau` runs with the rest of the suite (about 75 s). It plays 8 players over 48 virtual hours:

- **Actions:** random valid play (planting, harvesting, selling, buying seeds, upgrades, watering, help-watering,
  daily and playtime claims).
- **Robux purchases:** boosts and cosmetics.
- **Gift products:** sent to friends who are here, and to two friends who are only online at each restart (their
  gifts go through the gift queue).
- **Free item gifts:** accepted or declined.
- **Disruptions:** rejoins, a failed DataStore write now and then, and a forced server close every 6 h. A new
  server, with a new JobId, picks up the same data.

Use `SOAK_HOURS=2 tools/run_tests.sh Soak` for a quick run.

| Invariant | How it's checked |
|---|---|
| coins ≥ 0 | every hour, for every loaded or stored profile |
| No GUID in 2 profiles | every hour, across all 8 profiles |
| Items conserved across gifts | the giver's and receiver's item counts before and after each gift |
| `receipts` ≤ 50 | after every purchase and every hour |
| No lost purchase | at every close (the stored profile) and at the end: every granted cosmetic and every gift is owned |
| Locks released | at every close, every stored lock is gone |
| DataStore budget never below 0 | the mock's budget refills per minute like Roblox's, and its lowest value is checked |
| Autosave every 90 s per player | profile writes during the last server's sessions are at most 90 s apart, plus the 6 s cooldown and a failed write's backoff |
| Block Party runs | it blooms about once an hour |
| No errors | every hour |

The last 48 h run: 17,359 actions, 1,089 purchases, 836 gift products, 1,024 item gifts, 1,216 rejoins, 8 closes,
1,085 failed writes and 48 Block Party blooms. The lowest budget was 98.

## Live soak (Studio, by hand)

1. Studio > Test > Clients and Servers: a local server with 8 players. Have them play for 2 hours, using the
   DevCommands `bp start` and `weather rain` now and then.
2. Watch the server's Developer Console (F9 > Server) for:
   - **Memory:** after the first 10 minutes of warm-up, server memory grows by less than 50 MB.
   - **Errors:** none in the server or client logs.
   - **DataStores:** no throttle warnings ("DataStore request was added to queue").
   - **Autosaves:** one about every 90 s per player. The server log shows the SaveQueue writes.
   - **Block Party:** it runs at least twice, start to bloom to wilt, with no errors.
3. Record the numbers in the release checklist (`docs/release.md`).

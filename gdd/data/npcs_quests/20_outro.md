### 20.10 Unlock & trophy map (quick reference)

| Unlock / reward | Granted by | Gate |
|---|---|---|
| Downtown district (`DST_03`) | `QST_TUT_010` (canon tutorial step 10) | tutorial |
| Arena access: Bash the Bots, Cook-Off race, opt-in PvP | `QST_CBT_001` Ring Debut | L12 (`DST_10`) |
| Mutation Lab access | `QST_EXP_002` Lab Rat (Voluntary) | L15 (`DST_06`) |
| Mystery Market access | `QST_EXP_003` Down the Drain | L20 (`DST_09`) |
| Alien Cuisine course (all ALN recipes learnable) | `QST_STY_017` Alien Cuisine 101 (Chapter 5, Zorp `NPC_027`) | L30, `TIER_05` |
| `RCP_LEG_001` … `RCP_LEG_005` | `QST_CHF_011` … `QST_CHF_015` (Legendary Recipe quests, chained) | L65 / 72 / 80 / 88 / 95 |
| City Hall Expansion Permits `TIER_04` … `TIER_10` | `QST_RST_004` … `QST_RST_010` (Mayor `NPC_002`) | the tier's canon required level (§C6) |
| `FRN_901` Golden Spatula Trophy | `QST_CHF_010` | L50 |
| `FRN_902` Rat King's Crown Display | `QST_STY_020` (Chapter 6 finale) | L40 |
| `FRN_903` Critic's Five-Star Plaque | `QST_STY_023` (Chapter 7 finale) | L50 |
| `FRN_904` Arena Champion Belt Case | `QST_CBT_009` | L40 |
| `FRN_905` Baron's Defeated Mustache Portrait | `QST_STY_028` (Chapter 9) | L70 |
| `FRN_906` Meteor Chunk Lamp | `QST_EXP_006` (`EVT_006`) | L26 |
| `FRN_907` Parade Float Mini | `QST_EXP_007` (`EVT_002`) | L12 |
| `FRN_908` Kraken Plush | `QST_EXP_008` (`EVT_022`) | L30 |
| `FRN_909` Museum Replica Fossil | `QST_EXP_009` | L16 |
| `FRN_910` Omnivora's Signed Apron | `QST_STY_032` (finale, `EVT_005`, host `NPC_029`) | L85 |
| Story mutation parts | Ch. 2 `MUT_235` · Ch. 4 `MUT_049` · Ch. 5 `MUT_103` · Ch. 6 `MUT_084` · Ch. 7 `MUT_038` + `MUT_137` · Ch. 8 `MUT_037` + `MUT_200` · Ch. 9 `MUT_178` + `MUT_108` · Ch. 10 choice of `MUT_039` or `MUT_242` | story |

Trophies are one per profile, non-tradeable and non-purchasable (§36.13). A trophy from an event quest can still be
earned in a later occurrence of that event if missed.

### 20.11 Edge Cases

| # | Situation | Ruling |
|---|---|---|
| Q1 | Player completes an objective while offline (e.g. offline report collected) | Only `CollectOffline` counts offline activity, and it counts at the moment of the server-validated claim. Offline customers never advance serve/cook objectives. |
| Q2 | Daily reset happens while the player is online mid-quest | Unclaimed completed dailies auto-claim at reset (rewards are never lost). Incomplete dailies expire, and the new draw appears with a toast. Weekly works the same way on Monday. |
| Q3 | Player upgrades tier between accepting and claiming a daily | Rewards use the tier and level snapshot taken at accept (§20.6). |
| Q4 | Event-dependent story step, but the event is weeks away | Story Replay opens after 60 min (§20.7), so the story never waits on the live calendar. |
| Q5 | Personality-based daily rolled but the personality stops spawning (e.g. event override) | Server re-validates eligibility at each daily draw. If a slot becomes impossible mid-day, a free reroll is granted for that slot. |
| Q6 | Player reaches a quest's level gate in a district they haven't unlocked | The quest stays Locked with a tooltip. District unlock levels (§C16.1) always take precedence. |
| Q7 | Required station not owned (e.g. `STN_SOUP_POT`, `STN_INFUSER`) | The quest card shows "Needs `STN_…`" with a shortcut. The quest can still be accepted, but cook objectives won't progress until the station exists. |
| Q8 | Co-op guest cooks for the host during the host's story challenge | Cook/serve actions credit whoever performed them (§20.2). The host's story objective counts dishes served in the host's restaurant regardless of who cooked them; the guest gets guest rewards (§21), not the host's story rewards. |
| Q9 | Player is KO'd during a timed challenge | The timer keeps running and the player respawns at kitchen spawn (canon C12.1). No extra penalty applies; the attempt fails only if the timer expires. |
| Q10 | Two claims race (double tap, two devices) | The session lock plus the idempotent `quest:<key>` grant means exactly one succeeds and the other returns `AlreadyClaimed` (§20.7). |
| Q11 | Story Assist enabled and then the player levels up | Assist applies only to the current attempt of that step and resets when the step completes. |
| Q12 | Player skipped the tutorial (§32) | Skipping auto-completes `QST_TUT_001`–`QST_TUT_012` with their full rewards (600 MB, 390 XP, the part choice, `EMP_001`, 1 Morph Capsule) after a 3-screen summary, so skippers are never behind. |
| Q13 | A quest grants a part the player already owns (e.g. `MUT_175`) | The duplicate follows canon dupe rules (kept for upgrades or auto-converted to MS, §C4.6–C4.7). It never fails. |
| Q14 | Player declines PvP entirely | Every arena objective accepts Bash the Bots or Cook-Off race (§21), and social weeklies reroll free. No quest requires PvP or another player. |

### 20.12 Dependencies

- **§19:** quest givers, dialogue effects and markers. **§18 / §36.10:** buildings, secrets and location triggers.
  **§36.11:** event participation awards and the Story Replay mode for `EVT_005`, `EVT_007` and `EVT_008`.
- **§5 / §6 / §C10:** cooking signals, recipe IDs and unlock levels. **§9:** personality spawn tables.
  **§12 / §36.3:** reward parts. **§15 / §36.12 / §36.13:** tiers, the Starter upgrade shelf, menu slots, trophies.
- **§16 / §17:** hiring, roles, training, morale, offline reports. **§21:** co-op attribution, Bash the Bots / Cook-Off / PvP modes.
- **§14:** skill-point budget (quests ≤ 15). **§22:** economy budget review. **§24:** journal and HUD tracker.
- **§27 / §28 / §29:** `QuestService`, the `profile.quests` schema and remote rate limits. **§31:** quest analytics.
  **§32:** tutorial script for `QST_TUT_001`–`QST_TUT_012`.

### 20.13 Acceptance Criteria

- **AC-20-01:** The database defines ≥ 125 quests: TUT 12 · STY ≥ 30 · DLY ≥ 20 · WKY ≥ 12 · CHF ≥ 10 · CBT ≥ 10 · RPR ≥ 8 · EXP ≥ 10 · EMP ≥ 8 · RST ≥ 10. Every row has all 10 columns filled.
- **AC-20-02:** `QST_TUT_001`–`QST_TUT_012` carry the canon titles. Their MB rewards sum to exactly 600 MB, and a player who never spends finishes `QST_TUT_010` with ≥ 525 MB from quests alone (enough for the ≤ 500 MB first upgrade). `QST_TUT_010` offers exactly `MUT_145` / `MUT_144` / `MUT_153`, and `QST_TUT_012` hires `EMP_001` at 0 MB.
- **AC-20-03:** Every quest's NPC and involved NPCs exist in §19, every NPC lists ≥ 1 quest, and every reward ID is a canon `MUT_`/`RCP_`/`FRN_901–910` (`render_npcs_quests.py --check` exits 0).
- **AC-20-04:** Exactly 3 dailies are drawn per UTC day and 5 weeklies per Monday-UTC week. The same `UserId` + day always yields the same draw (reconnect test), and resets fire at 00:00 UTC ± 5 s.
- **AC-20-05:** One free daily reroll per UTC day (one per week for weeklies). A second free reroll attempt is rejected server-side, and paid rerolls cost MB only.
- **AC-20-06:** Completing all 3 dailies grants exactly 1 Morph Capsule once per day, and all 5 weeklies grant 2 Morph Capsules + 1 RT once per week.
- **AC-20-07:** Spamming `Quest.Claim` 50 times (or claiming from two clients at once) grants a quest's rewards exactly once, verified via the `EconomyService` transaction log.
- **AC-20-08:** No client remote can advance objective progress. A forged `Quest.Progress` from a client is ignored and logged.
- **AC-20-09:** A failed timed quest applies no MB/MS/RT/XP/item penalty and becomes Available again after 60 s ± 1 s. After 3 fails of a STY/TUT step, Story Assist is offered.
- **AC-20-10:** Each story chapter opens only at its tier (`TIER_01`–`TIER_10`) after the previous chapter. All 10 chapters plus the epilogue are completable solo, with event steps completable via Story Replay within 60 min.
- **AC-20-11:** `QST_STY_017` sets the Alien Cuisine flag, after which every ALN recipe is learnable at `BLD_06` at its unlock level. `QST_CHF_011`–`QST_CHF_015` grant `RCP_LEG_001`–`RCP_LEG_005` respectively.
- **AC-20-12:** The tier-upgrade button for `TIER_04`–`TIER_10` stays disabled until the matching permit quest (`QST_RST_004`–`QST_RST_010`) is complete. `TIER_02`–`TIER_03` never require a permit.
- **AC-20-13:** All 10 trophies `FRN_901`–`FRN_910` are obtainable from exactly the quests listed in §20.10.
- **AC-20-14:** The sum of skill points granted by quests is ≤ 15 (currently 12), as printed by the renderer.
- **AC-20-15:** Every quest with an arena objective can be completed without entering PvP (Bash the Bots or Cook-Off race), verified by a PvP-disabled test account completing `QST_CBT_001`, `QST_CBT_008`, `QST_CBT_009`, `QST_DLY_020` and `QST_WKY_010`.
- **AC-20-16:** The HUD tracks ≤ 3 quests, and quest toasts never overlap the order queue or patience meters on a 1280×720 phone layout. Every timer has a text countdown.

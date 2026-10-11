## 38. Open Design Decisions

These are the decisions the design deliberately leaves open, each with options, a recommendation and a
deadline tied to the phase gates of §34. Until a decision is recorded, teams build to the
**recommendation**. Items OD-23…OD-27 are canon clarifications found while writing the test plan (§35):
they need a one-line ruling, not a redesign.

### 38.1 Decision Process

| Step | Rule |
|---|---|
| Open | Listed here with an owner role and a decide-by gate. |
| Proposed | Owner circulates evidence (playtest, telemetry, cost estimate) ≥ 1 sprint before the gate. |
| Decided | Producer records the outcome in the decision log (date, option, rationale); the affected section is updated; values go to LiveConfig where tunable (§39). |
| Implemented | Linked tickets closed; tests updated (§35). |
| Revisit | Any decision may be reopened by telemetry crossing a KPI floor (§34.10.3). |

Owner roles refer to the team in §34.1: Producer (PM/QA lead), Lead Engineer, Designer, Art Director
(lead artist), UI Engineer.

### 38.2 Decision Register

| ID | Question | Options | Recommendation | Owner role | Decide by | Impact |
|---|---|---|---|---|---|---|
| OD-01 | Server size: 8 or 12 players? | (a) 8, one plot each (canon §C3); (b) 12 with a redesigned Restaurant Row; (c) 6 | (a) 8 at launch; reconsider 12 only if P-03 (§35.10) shows ≥ 30 % server headroom and Restaurant Row is redesigned for 12 plots | Lead Engineer + Designer | G2 | plot layout, server load, friend-join availability, city density |
| OD-02 | Restaurant interiors: instanced in the main place, or separate places? | (a) instanced interior region (canon §C3); (b) reserved-server restaurant place via TeleportService | (a); fall back to (b) only if P-03 client memory misses target by > 20 % after optimization | Lead Engineer | G1 | architecture, streaming, co-op flow, teleport friction |
| OD-03 | Allow player trading? | (a) none; (b) gifting of earned cosmetics only; (c) full trade window for parts and furniture | (a) at launch; evaluate (b) in Live Ops; never (c) for mutation parts (economy, scams, child safety; honors paid-item trading policy) | Designer + Producer | G3 | economy integrity, moderation and support load |
| OD-04 | What may Arena PvP reward? | (a) cosmetic only; (b) cosmetics + modest MS, RT in ranked seasons; (c) exclusive power parts | (b); any part obtainable in the Arena must also have a non-PvP source | Designer | G3 | fairness for players who never opt into PvP |
| OD-05 | Second restaurant property? | (a) never; (b) post-launch, gated at `TIER_10`; (c) at launch | (b) design spike in Live Ops month 4; combined offline income still ≤ 60 % of active (§C15); requires a plot solution for 8-player servers | Designer + Lead Engineer | Live Ops month 3 | profile size, plots, offline economy |
| OD-06 | Voice chat? | (a) off; (b) city only for eligible users; (c) everywhere for eligible users | (a) at launch; revisit (b) after launch using Roblox eligibility controls | Producer | G4 | child safety, moderation |
| OD-07 | Cosmetic season pass? | (a) none; (b) free track only; (c) free + Robux cosmetic track | (c) in Live Ops month 5: cosmetics only, no MB/MS/RT, no power, no random rewards | Producer + Designer | G4 | revenue, player trust |
| OD-08 | Offline cap tuning? | (a) canon caps 2/4/8/12/24 h (+2 h assistant); (b) compressed 2/4/6/10/16 h; (c) extended beyond 24 h | (a) at launch; tune by D1/D7 and the offline/active ratio; never above 24 h; changes via LiveConfig and a SIM_VERSION bump (§39) | Designer | G5, then monthly | retention, inflation |
| OD-09 | Target maturity label: Minimal or Mild? | (a) answer for Minimal by toning down fights; (b) answer honestly, expecting Mild (repeated cartoon violence, no blood) | (b); keep the chaos pillar; re-verify Roblox's age-access rules for the label before launch | Producer | G4 | discoverability for the youngest players, brand honesty |
| OD-10 | Text chat inside co-op restaurants? | (a) default filtered chat only; (b) quick-chat wheel only; (c) both | (c): `TextChatService` filtered chat plus a preset quick-chat wheel ("Order up!", "Need cheese!", "Karenosaurus incoming!") for mobile and young players | Designer + UI Engineer | G3 | co-op usability, safety |
| OD-11 | Arena at launch: casual or ranked? | (a) casual opt-in 1v1/2v2; (b) ranked seasons; (c) none | (a); ranked seasons in Live Ops month 3 (§34.10.2); (c) only via cut list (§34.13) | Designer | G3 | scope, RT inflow |
| OD-12 | Private-server pricing? | (a) free; (b) low Robux price; (c) disabled | (a) free, so families and friends can co-op without strangers | Producer | G4 | safety, social play |
| OD-13 | Server fill and friend slots? | (a) Roblox-optimized fill; (b) reserve 1 slot for friends; (c) maximum fill | (b) reserve 1 slot so a friend can always join (a free plot exists) | Lead Engineer | G4 | social joins vs matchmaking density |
| OD-14 | Persistence implementation: build §28's locking design in-house, or adopt an open-source profile library? | (a) implement §28's design (lock in the profile, stale steal, presence-confirmed steal, teleport hand-off) in-house; (b) adopt a library and adapt it | (a); a library may be used only if it reproduces §28 exactly, including the atomic offline write of §C15 | Lead Engineer | G1 | data safety, schedule |
| OD-15 | Leaderboards? | (a) none; (b) friends-only; (c) friends + weekly global boards | (c) in Live Ops (Feb 2028); rank by reputation, dishes served, Legendary dishes — never by spending | Designer | G4 | social competition, DataStore load |
| OD-16 | Ship on console at launch? | (a) yes; (b) Live Ops month 2 | (a) if TC-UI-08 and the D5 column of §35.10 pass at G4, else (b) | Producer | G4 | reach, QA load |
| OD-17 | Cooking assists beyond Auto-Rhythm? | (a) none; (b) cue-only "Timer Assist" (audio + haptic tick at `T_ready`, no rule change); (c) wider windows capped at GOOD (0.80) | (b) at launch; (c) as a post-launch accessibility option | Designer | G3 | accessibility, fairness of rewards |
| OD-18 | Reviewed launch languages? | (a) English + automatic translation; (b) English + 5 reviewed; (c) English + 10 reviewed | (b): Spanish, Portuguese (Brazil), French, German, Indonesian reviewed; automatic translation elsewhere; add more by traffic | Producer | G3 | reach, localization cost |
| OD-19 | Daily login streak forgiveness? | (a) hard reset on a missed day; (b) 1 automatic grace day per 7-day window; (c) earnable streak shields | (b): kid-friendly and non-coercive | Designer | G3 | retention ethics |
| OD-20 | Mystery Market (`BLD_13`) rotation scope? | (a) global weekly stock (same for everyone); (b) per-player stock | (a), seeded by week number, so players talk about "this week's Market" | Designer | G3 | social buzz, exploit surface |
| OD-21 | Roblox Premium benefits? | (a) none; (b) small cosmetic perk; (c) MB bonus | (b) only; no currency bonus (avoids pay-to-earn) | Producer | G4 | policy, fairness |
| OD-22 | Analytics pipeline? | (a) `AnalyticsService` only; (b) + internal aggregates for live dashboards; (c) + external warehouse | (b); external storage only for aggregated, anonymous data | Lead Engineer | G3 | privacy, tuning speed |
| OD-23 | (Canon E1) Are tickets finished by online employees during Closing credited after PlayerRemoving? | (a) hold the session lock; Closing ≤ 30 s; final save after Closing; (b) void those tickets; (c) credit them into the next offline interval | (a); (c) as fallback under BindToClose pressure; never double-credit (TC-EDGE-02) | Lead Engineer + Designer | G2 | E1 behavior, data safety |
| OD-24 | (Canon §C14.2 vs §C15) Scale of `Eff_chef` / `Eff_waiter` in the offline formula | (a) Efficiency / 100 (0–1); (b) raw 1–100 | (a), otherwise capacities are 100× too large | Designer | G2 (before offline goldens) | offline economy |
| OD-25 | (Canon §C3 vs §C5) Max WalkSpeed 21 or 20.8? | (a) 20.8 from the MOVE formula; (b) 21 | (a); "21" is a rounded label | Designer | G1 | movement validation thresholds |
| OD-26 | (Canon §C11.4) Jackpot cap at exactly `TIER_05` | (a) `TIER_01`–`TIER_04` 500 MB, `TIER_05`+ 5,000 MB; (b) `TIER_05` still 500 MB | (a) (TC-SAT-09) | Designer | G2 | tip economy |
| OD-27 | (Canon §C4.6, §C13.4) Rounding of fractional costs and budgets (e.g. 337.5 MB, 18.92 points) | (a) costs round half-up to whole MB; budgets kept to 1 decimal internally, distributed so stats sum exactly; (b) floor everything | (a) | Designer | G2 | data validators, UI display |

### 38.3 Evidence Needed and Work Blocked

| ID | Evidence the owner must bring | Work that waits on the decision (build to the recommendation meanwhile) |
|---|---|---|
| OD-01 | P-03 server captures (§35.10); CCU distribution from closed beta | Restaurant Row plot layout beyond 8 plots |
| OD-02 | P-03 client memory on D1 after the Phase 3 performance pass | Interior streaming setup; co-op entry flow |
| OD-03 | support-ticket forecast; Roblox trading policy review; economy-sim impact | any trade UI; gifting in Live Ops |
| OD-04 | arena opt-in rate in playtests; RT inflow model (§39.3.2) | arena reward tables |
| OD-05 | profile-size estimate; plot solution sketch; offline-ratio model with two properties | second-property design spike |
| OD-06 | platform eligibility controls at the time; moderation cost estimate | voice settings in §37.4.3 |
| OD-07 | cosmetic catalogue depth (§23); art capacity in Live Ops | season-pass UI shell |
| OD-08 | D1/D7 by offline cap cohort; offline/active ratio per tier (TC-OFF-10) | Manager pricing; Welcome Back copy |
| OD-09 | completed questionnaire draft; kid-safety sign-off (§37.3.3) | store page copy; marketing creatives |
| OD-10 | co-op playtest notes on mobile typing; quick-chat phrase list | co-op HUD layout |
| OD-11 | arena engineering estimate vs Beta capacity (F4.9) | cut-list item 1 (§34.13) |
| OD-12 | private-server usage in closed beta | experience settings |
| OD-13 | friend-join failure rate in closed beta | server-fill setting |
| OD-14 | prototype of the §28 lock under failure injection (TC-EDGE-10, TC-EDGE-11); library audit if (b) is proposed | `PlayerDataService` v0 |
| OD-15 | OrderedDataStore budget estimate; social KPI targets | leaderboard UI |
| OD-16 | D5 column of §35.10; TC-UI-08 results | device list in §37.4.1 |
| OD-17 | accessibility playtest results (R6, R7 in §35.8) | settings screen |
| OD-18 | traffic forecast by locale; vendor quotes | LocalizationTable import plan |
| OD-19 | streak-break rates in Phase 3 playtests | login-streak UI |
| OD-20 | Mystery Market purchase data from Alpha | `BLD_13` stock generator |
| OD-21 | Premium-player share in closed beta | cosmetic catalogue |
| OD-22 | privacy review; dashboard latency needs | analytics pipeline (F4.10) |
| OD-23 | BindToClose timing measurements under 8 players | Closing state (`RestaurantService`), TC-EDGE-02 |
| OD-24 | offline goldens computed both ways vs §C15 ratio targets | offline goldens F-OFF-01…F-OFF-10 |
| OD-25 | none (formula check) | movement validation thresholds |
| OD-26 | none (wording check) | jackpot cap code, TC-SAT-09 |
| OD-27 | none (rounding check) | data validators, UI number display |

### 38.4 Decision Log Template

Each decided item is recorded as a row in the producer's decision log (kept with the GDD):

| Field | Content |
|---|---|
| Decision ID | OD-NN |
| Date / gate | e.g. 2027-04-20 / G2 |
| Chosen option | letter + one sentence |
| Rationale | evidence summary with links (captures, playtest notes, telemetry) |
| Sections updated | list of §N touched |
| Tests updated | TC IDs added or changed (§35) |
| LiveConfig keys | if tunable (§39) |
| Revisit trigger | KPI floor or date |

### 38.5 Acceptance Criteria

- **AC-38-01:** Every OD has an owner role and a decide-by gate; no gate closes with an OD due at that
  gate still Open.
- **AC-38-02:** Each decided OD appears in the decision log with date, chosen option and rationale, and the
  affected section and tests are updated within one sprint.
- **AC-38-03:** Until decided, implementations follow the listed recommendation (verified at gate review).


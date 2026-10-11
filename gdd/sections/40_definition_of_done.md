## 40. Definition of Done

"Done" means *shippable to players*, not "works on my machine". This section defines Done at four levels —
**feature**, **content item**, **GDD section** and **release** — with measurable criteria, links every
section's acceptance criteria (the `AC-SS-NN` convention of §C0) to the tests that verify them (§35), and
sets the performance, accessibility, localization and safety gates that every level inherits. The
launch-readiness checklist (§40.8) is the final Go/No-Go.

### 40.1 Levels at a Glance

| Level | Unit of work | Who signs | Blocking evidence |
|---|---|---|---|
| Feature | a system or sub-system (e.g. Lab fusion, Closing state) | owning engineer + designer; QA verifies | §40.2 criteria F1–F12 |
| Content item | one database row plus its assets (a recipe, part, NPC, quest…) | content owner; art director for visuals | §40.3 criteria C1–C10 |
| GDD section | one `gdd/sections/` file | section owner + integrator | §40.4 criteria D1–D12 |
| Release | a build promoted to players (gate or live patch) | producer + lead engineer | §40.5 criteria R1–R10 and §40.7 gates |

### 40.2 Feature Definition of Done

| # | Criterion | Measure | Evidence |
|---|---|---|---|
| F1 | Specified | the owning section has all template blocks (Purpose · Rules & Mechanics · Variables · UI · Progression · Player Interactions · Dependencies · Roblox Implementation · Edge Cases · Acceptance Criteria) | section link |
| F2 | Tunables externalized | every [TUNABLE] value read from LiveConfig with the §39 default and safe range | config key list |
| F3 | Server-authoritative | all state changes on the server; every new remote in the remote inventory with schema, rate limit and caller rule (§35.11) | inventory diff |
| F4 | Tested | 100 % of the area's P0 and ≥ 95 % of P1 cases pass (§35.5); formula modules ≥ 90 % line coverage; relevant §C22 rulings pass (§35.6) | CI run + test report |
| F5 | Acceptance criteria met | 100 % of the section's `AC-SS-NN` items verified, each with a linked test ID, capture or review record | AC checklist |
| F6 | Performant | meets the §30 budget on the LOW class (D1) in its scenario; no regression > 5 % FPS p50 in P-02 vs the previous build | capture files |
| F7 | Accessible | usable with touch, keyboard/mouse and gamepad; status readable without color; respects Reduced Effects and audio sliders | TC-UI-02/03/08 results |
| F8 | Localized | all player-facing strings in the LocalizationTable; pseudo-localization shows no clipping | pseudo-loc screenshots |
| F9 | Safe | kid-safety checklist (§37.3.3) passed; any user-entered text filtered | review record |
| F10 | Instrumented | §31 events emitted with ≤ 1 % schema errors in Staging | analytics validation |
| F11 | Code quality | reviewed and approved by a second engineer; lint and format clean; no TODO without a ticket | pull request |
| F12 | Clean bug state | no open S0/S1 against the feature; S2s have workarounds and tickets (§35.13) | tracker query |

### 40.3 Content-Item Definition of Done

| # | Criterion | Measure |
|---|---|---|
| C1 | Data row complete | every field required by the owning section filled (e.g. 20 brief fields per recipe in §6; all §C13.6 + A7 fields per part in §36.3) |
| C2 | Identity valid | ID follows §C2, unique, canon names unchanged; ID appears as a definition exactly once in the assembled GDD |
| C3 | References resolve | the GDD validator reports 0 unresolved references introduced by the item |
| C4 | Balance in range | values inside canon bands and §39 safe ranges (price curve, rarity bands, budgets); economy validators pass |
| C5 | Assets in budget | mesh/triangle/MeshPart budgets (§C13.7, §30); textures within memory budget; animations and sounds hooked |
| C6 | Visual sign-off | art director approval against §25 and the kid-safety checklist (§37.3.3) |
| C7 | Tested in situ | verified in its test harness (morph test scene with ≥ 5 combos; recipe cook test at PERFECT and BURNED; NPC dialogue walk-through; quest completion run) |
| C8 | Localized | display name, description and dialogue strings in the LocalizationTable |
| C9 | Accessible | rarity/status conveyed by shape or icon as well as color |
| C10 | Tracked | §37.3.1 tracker updated; content count shows in the validator's completion manifest |

### 40.4 GDD-Section Definition of Done

| # | Criterion | Measure |
|---|---|---|
| D1 | Heading | first line is the exact §C1 heading (H2), or the allocated H3 for contributing files; no H1 anywhere |
| D2 | Structure | subsections numbered `N.x`; every major system uses the §C0 template blocks in order |
| D3 | Canon fidelity | every canon value used verbatim; [TUNABLE] values labelled; no new currencies |
| D4 | IDs | only IDs from the section's own domain are defined; all others are references that resolve |
| D5 | Database tables | first column is the ID; one row per entity; required minimum row counts delivered, no truncation |
| D6 | Acceptance criteria | measurable, numbered `AC-SS-NN`, unique within the section |
| D7 | Diagrams | Mermaid blocks open with `%% diagram: <key>`; required keys present where owned (§C1.3) |
| D8 | Edge cases | consistent with §C22 rulings; section-specific edge cases listed |
| D9 | Implementability | Roblox-realistic APIs only; Luau examples typed where helpful |
| D10 | Tone | ridiculous surface, rigorous rules; kid-safe; no real brands or people |
| D11 | Cross-references | other sections cited as `§N` (fixed anchors only for §36.x subsections) |
| D12 | Validated & reviewed | GDD validator passes for the file; reviewed by the owner and the integrator |

### 40.5 Release Definition of Done

| # | Criterion | Measure |
|---|---|---|
| R1 | Gate evidence | the applicable gate of §35.12 (G1–G6) is met and recorded |
| R2 | Regression | suite per §35.9 executed on the release build; results archived with build ID |
| R3 | Performance | §40.7 performance gate met (full matrix for G4/G5; P-02 on D1 for G6) |
| R4 | Security | exploit suite passed; new remotes inventoried; no open S0/S1 exploit |
| R5 | Data safety | migrations tested on fixtures; offline goldens unchanged or SIM_VERSION bumped and re-approved |
| R6 | Config | LiveConfig diff reviewed; production defaults equal §39 (AC-39-02) |
| R7 | Compliance | §37.4 items still true (maturity answers, monetization rules, filtering) |
| R8 | Release notes | player-facing notes written and localized |
| R9 | Rollback | previous place version tagged; LiveConfig rollback owner named; ≤ 15 min rehearsal valid (AC-34-35) |
| R10 | Monitoring | 2-hour post-publish watch staffed; dashboards and alerts green |

### 40.6 Acceptance-Criteria Linkage by Section

Each section defines its own `AC-SS-NN` items. Appendix subsections in §36 may use the prefix of the system
section that owns them (e.g. §36.11 city events carry `AC-18-50`…`AC-18-69`). A feature is Done only when
every AC of its section is verified by the listed evidence.

| Section | AC prefix | Primary verification (§35) | First gate |
|---|---|---|---|
| §1–§4 Vision, pillars, loops | `AC-01-*`…`AC-04-*` | playtests R1–R10 (§35.8), loop questionnaire | G1 |
| §5 Cooking Mechanics (+ §6.18) | `AC-05-*` | TC-COOK, TC-EDGE-12, TC-EDGE-37 | G1 |
| §6 Recipe Database | `AC-06-*` | data validators (price curve, stations), TC-COOK | G2 |
| §7 Ingredient Database | `AC-07-*` | data validator, TC-EDGE-14 | G2 |
| §8 Customer AI | `AC-08-*` | TC-CUST, TC-EDGE-15, TC-EDGE-16, TC-EDGE-34 | G1 |
| §9 Customer Personalities | `AC-09-*` | TC-CUST-07…09 | G2 |
| §10 Satisfaction and Tantrum | `AC-10-*` | TC-SAT, TC-CUST-06…10 | G1 |
| §11 Combat System | `AC-11-*` | TC-CMBT, TC-EDGE-03, TC-EDGE-04, TC-EDGE-22, TC-EDGE-23 | G1 |
| §12 Mutation System (+ §12.9–§12.10) | `AC-12-*` | TC-MUT, TC-EDGE-27, TC-EDGE-28 | G2 |
| §13 Morph Customization | `AC-13-*` | TC-MORPH, TC-EDGE-07, TC-EDGE-29 | G2 |
| §14 Player Progression | `AC-14-*` | TC-QST-08, TC-ECON-14, TC-EDGE-21, TC-EDGE-32 | G2 |
| §15 Restaurant Building | `AC-15-*` | TC-BUILD, TC-DEST, TC-RPR, TC-EDGE-24 | G2 |
| §16 Employee Management | `AC-16-*` | TC-EMP, TC-EDGE-05, TC-EDGE-06, TC-EDGE-13, TC-EDGE-45 | G2 |
| §17 Offline Simulation | `AC-17-*` | TC-OFF, TC-EDGE-08, TC-EDGE-09, TC-EDGE-17, TC-EDGE-18, TC-EDGE-26 | G2 |
| §18 Morph City | `AC-18-*` | TC-PERF-04, TC-ECON-11, TC-EDGE-42, TC-EDGE-43 | G3 |
| §19 City NPCs | `AC-19-*` | data validator, dialogue walk-through | G3 |
| §20 Quests | `AC-20-*` | TC-QST | G2 |
| §21 Multiplayer | `AC-21-*` | TC-MP, TC-EDGE-19, TC-EDGE-33 | G3 |
| §22 Economy | `AC-22-*` | TC-ECON, economy simulation (§35.2) | G3 |
| §23 Monetization | `AC-23-*` | TC-MUT-13, TC-DATA-11, §37.4.4 | G4 |
| §24 UI/UX | `AC-24-*` | TC-UI | G2 |
| §25 Art Direction | `AC-25-*` | §37.3.3 sign-off, TC-CMBT-13 | G2 |
| §26 Animation and Audio | `AC-26-*` | TC-MORPH-09, §37.3.2 checklists | G3 |
| §27 Roblox Architecture | `AC-27-*` | integration suite (L4), remote inventory | G3 |
| §28 Data Persistence | `AC-28-*` | TC-DATA, TC-EDGE-10, TC-EDGE-11, TC-EDGE-20, TC-EDGE-41 | G2 |
| §29 Security and Anti-Exploit | `AC-29-*` | TC-ECON, exploit program (§35.11) | G3 |
| §30 Performance Optimization | `AC-30-*` | TC-PERF, matrix (§35.10) | G4 |
| §31 Analytics | `AC-31-*` | schema validation (AC-34-28) | G4 |
| §32 Tutorial | `AC-32-*` | TC-QST-01…05, R7 | G2 |
| §33 Content Expansion | `AC-33-*` | release DoD (§40.5) per drop | G6 |
| §34 Development Roadmap | `AC-34-*` | gate reviews | each gate |
| §35 Testing and QA | `AC-35-*` | QA audit at each gate | G2 |
| §36 Content Database Appendices | owner prefixes | GDD validator (counts, references, canon names) | G4 |
| §37–§40 | `AC-37-*`…`AC-40-*` | producer audit | G4 |

### 40.7 Cross-Cutting Gates

| Gate | Criterion | Threshold | Evidence |
|---|---|---|---|
| Performance | FPS on the LOW class (D1) in P-02 (`TIER_10` rush, chaos level 6) | p50 ≥ 30, p5 ≥ 25 (§30) | §35.10 capture |
| Performance | client memory (LOW / MID / HIGH) | ≤ 900 / 1,400 / 2,500 MB | §35.10 capture |
| Performance | server heartbeat with 8 busy restaurants | ≥ 45 Hz at p95 | TC-PERF-03 |
| Performance | network per player | ≤ 40 KB/s down avg, ≤ 6 KB/s up avg | TC-PERF-08 |
| Performance | join to first input on LOW, 4G | ≤ 20 s cold | TC-PERF-07 |
| Accessibility | tutorial completable on touch, keyboard/mouse and gamepad | 3 of 3 recorded runs | AC-34-12 |
| Accessibility | status readable without color (rarity shapes, anger/patience icons) | 100 % of indicators | TC-UI-03 |
| Accessibility | touch targets | ≥ 44×44 rendered px, ≥ 8 px spacing (§24) | TC-UI-04 |
| Accessibility | options present | Reduced Effects, separate audio sliders, Auto-Rhythm, camera-shake toggle, cue-only Timer Assist (OD-17) | TC-UI-09 |
| Accessibility | text contrast | body text ≥ 4.5:1 | TC-UI-10 |
| Localization | strings externalized | 100 % in the LocalizationTable; none baked into textures | string audit |
| Localization | reviewed languages | the OD-18 set at 100 % translated and reviewed | vendor sign-off |
| Localization | layout robustness | pseudo-localization (+40 %) clean on every screen | TC-UI-05 |
| Safety | content | no blood, gore, death or realistic weapons; no real brands or people | §37.3.3 sign-off, TC-CMBT-13 |
| Safety | user text | 100 % of user-entered text filtered before display | TC-MORPH-11, TC-MP-08 |
| Safety | monetization | cosmetics only; no paid random items; earnable capsule odds disclosed | TC-MUT-13, TC-UI-07 |
| Safety | fair failure | KO and platform failures never remove mutations, items or currency | TC-CMBT-07, TC-EDGE-22 |
| Safety | privacy | no personal data collected; erasure procedure works | TC-DATA-10 |
| Data integrity | duplication | 0 duplicates in crash-chaos runs (200 purchases + 200 collects) | §35.11 |
| Economy | pacing and offline | pacing within ±15 % of §C5.1; offline ≤ 60 % of active at every tier | economy sim, TC-OFF-10 |

### 40.8 Launch-Readiness Checklist (Go / No-Go)

- [ ] All launch-critical rows of §34.12 implemented; §37.3.1 tracker complete for launch scope.
- [ ] G4 Beta gate passed and G5 evidence recorded (§35.12).
- [ ] 0 open S0; 0 open S1 in launch-critical systems; S2 count ≤ 25 with workarounds.
- [ ] Every section passes the GDD-section DoD (§40.4); GDD validator: 0 unresolved IDs, 0 duplicate definitions, all counts met.
- [ ] Every cross-cutting gate of §40.7 met on the release candidate.
- [ ] Soft-launch metrics: crash-free ≥ 99.3 %, DataStore errors ≤ 0.5 %, D1 ≥ 30 %, median session ≥ 20 min (AC-34-32, AC-34-33).
- [ ] Launch checklist §37.4 complete and signed (experience settings, maturity questionnaire, privacy, monetization, servers, localization).
- [ ] LiveConfig production defaults equal §39; kill switches tested; rollback ≤ 15 min rehearsed.
- [ ] On-call rota for launch + 14 days; S0 response ≤ 1 h.
- [ ] Open design decisions due by G4/G5 decided and logged (§38).
- [ ] Player-facing release notes and support macros ready in all reviewed languages.
- [ ] Final Go signed by producer, lead engineer, designer and art director (kid-safety).

### 40.9 Acceptance Criteria

- **AC-40-01:** Every feature closed in the tracker links evidence for all twelve feature criteria F1–F12.
- **AC-40-02:** Every content item passes C1–C10; the assembled GDD validates with 0 unresolved references
  and 0 duplicate ID definitions.
- **AC-40-03:** Every GDD section passes D1–D12 (validator plus owner and integrator sign-off) before G4.
- **AC-40-04:** Every release records R1–R10; launch is Go only when all §40.8 boxes are checked.
- **AC-40-05:** The §40.7 gate table is measured and archived for every release candidate.


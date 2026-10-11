## 31. Analytics

> **Owner:** A18 Data & Ops. **Binding inputs:** §C20 (Roblox `AnalyticsService` + an internal event schema;
> names `mmr_<snake_case>`), §C4.4 (pacing targets), §C14.3/§C15 (offline caps and the 35–50 % rate), §C4.7
> (capsule odds and pity), §C22. KPI targets are stated in §1.7 and are **defined and measured here**; the
> `Telemetry` module is placed by §27; economy events are emitted only inside `EconomyService:TransactWith`
> (§27.12.5). We count every pickle, never the person: analytics is about the restaurant, not the player's identity.

### 31.1 Purpose

Turn play into decisions. Every brief-required moment (onboarding, tutorial completion, first order, first
successful meal, first tantrum, first combat, first mutation, first restaurant upgrade, first employee hire, first
offline collection, city exploration, quest completion, session duration, return visits) is instrumented; every
KPI from §1.7 has one formula and one source; every balancing lever in the game has a written rule that says
which signal moves it and by how much.

### 31.2 Rules & Mechanics (analytics principles)

| # | Principle |
|---|---|
| A1 | **Server-side truth.** Gameplay events are logged by the server from authoritative state; the client contributes only presentation facts (input mode, load time, device tier), marked non-authoritative. |
| A2 | **One name, one meaning.** Internal names are `mmr_<snake_case>` (§C2); every event is registered in the §31.10 catalog with its properties before code can emit it (CI check). |
| A3 | **Native first.** `AnalyticsService` (Creator Hub dashboards) is the primary sink: onboarding/recurring funnels, economy, progression and a budgeted set of custom events. The internal schema exists for consistency, Studio debugging and an optional export (§31.9). |
| A4 | **Low cardinality.** Custom fields carry enumerations and content IDs, never UserIds, timestamps, free text or raw high-cardinality numbers (numbers are bucketed). |
| A5 | **Once means once.** "First X" events are guarded by a persisted bitset (`meta.analytics.firstsBits`, §28.9.2) so reconnects and server hops cannot double-count. |
| A6 | **Economy events come only from `EconomyService`** (§27 P3) — one `LogEconomyEvent` per currency moved, inside the transaction. |
| A7 | **No PII, no chat, no free text** (§31.17). Player-written strings (morph names, loadout names) never enter analytics. |
| A8 | **Telemetry never changes gameplay for an individual.** Data informs content releases and flags; it does not secretly tune one player's odds or difficulty. |
| A9 | **Decisions are pre-registered** (§31.15): signal, threshold, minimum sample and lever are written before the data is looked at. |

### 31.3 Variables

| Variable | Value | Notes |
|---|---|---|
| `AS_CUSTOM_NAME_BUDGET` | ≤ 60 distinct `LogCustomEvent` names | headroom under Roblox's custom-event cardinality limits (verify current limits); everything else is grouped or internal-only |
| `AS_FIELD_CARDINALITY` | ≤ 1,000 distinct values per custom field per day | headroom under Roblox's per-field limits |
| `AS_EVENT_RATE` | ≤ 1 AnalyticsService call per 2 s per player (average), ≤ 10 per 10 s burst | enforced by `Telemetry`; economy events count |
| `SAMPLE_HIGH_FREQ` | 10 % | `mmr_ability_used`, `mmr_prop_thrown` (§11) |
| `PERF_SAMPLE_WINDOW_S` | 300 | `mmr_perf_sample` aggregation (§30.20) |
| `EXPORT_ENABLED` | false (flag `analyticsExport`, §27.15) | optional external warehouse; requires legal review |
| `EXPORT_BATCH` | every 30 s or 500 events | via `HttpService:PostAsync`, ≤ 2 requests/min per server |
| `EXPORT_RETENTION` | 13 months, then aggregated | erasure within 30 days of a request (§28.24) |
| `MIN_COHORT` | 2,000 players | minimum per arm / cohort before a §31.15 rule may fire |
| `KPI_REVIEW` | weekly (Mondays, after the 00:00 UTC reset) | live-ops cadence |

### 31.4 UI

Players see no analytics UI. Internal surfaces: the Creator Hub Analytics dashboards (native) and the team
dashboards of §31.14 (built from the optional export). The settings screen shows a one-line privacy note:
*"We count kitchen stats like burgers served to make the game better — never your chats or your name."*

### 31.5 Progression (lifecycle coverage)

| Lifecycle stage | Questions | Instrumentation |
|---|---|---|
| First 15 min | Where do new players stop? | onboarding funnel (tutorial steps 1–12), `mmr_first_*` moments |
| First hour | Do they reach TIER_02 and hire Ollie? | `RestaurantTier` progression, `mmr_first_employee_hire`, economy flows |
| First day | Do they come back to a Welcome Back report? | `mmr_session_start`, `mmr_offline_report_shown`, `mmr_offline_collected` |
| First week | Are mutations pulling them forward? | `mmr_mutation_acquired`, capsule funnel, collection KPIs |
| First month+ | Is the mid-game paced to §C4.4? Is offline replacing play? | tier-reach times, offline share, session length, events, arena |

### 31.6 Player Interactions

None directly; analytics is passive. Players are never asked for age, email or other personal data. Players can
reduce what the client contributes only through Roblox's own privacy settings; the server-side gameplay events
do not identify a person outside Roblox.

### 31.7 Dependencies

| Component | Role |
|---|---|
| `Telemetry` (server, §27.4.2) | the only caller of `AnalyticsService` besides `EconomyService` and `QuestService`'s tutorial funnel (§32.13); validates names against the catalog, enforces budgets, builds the envelope |
| `EconomyService` | `LogEconomyEvent` inside `TransactWith`, reason codes from §31.12 |
| `ProgressionService` | `LogProgressionEvent` for `PlayerLevel` (§14), level/tier milestones |
| `QuestService` / `TutorialDirector` | onboarding funnel steps (§32.13) |
| `PlayerDataService` | persists `meta.analytics` (install day, sessions, firsts bitset, onboarding step, §28.9.2) |
| `RemoteConfig` (§27.15) | feature flags and experiment definitions (§31.16) |
| All gameplay services | emit domain signals that `Telemetry` subscribes to (no service calls `AnalyticsService` directly) |

### 31.8 AnalyticsService Usage (canon §C20)

| Roblox call | Used for | Rules |
|---|---|---|
| `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` | **the one onboarding funnel**: §32 tutorial steps 1–12, names `mmr_tutorial_step_01` … `mmr_tutorial_step_12` | logged once per player per step, sequentially (AC-32-03); custom field 01 = `skipped` when skipped |
| `LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, customFields)` | first-session moments (`mmr_first_session`) and recurring funnels (shop, capsule, hire, offline collect, tier upgrade, §31.11) | recurring funnels use a fresh GUID per attempt; `mmr_first_session` uses the constant session id `"fs"` |
| `LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields)` | every MB/MS/RT movement | only inside `EconomyService:TransactWith`; `currencyType` ∈ `MB`, `MS`, `RT`; `transactionType` = an `Enum.AnalyticsEconomyTransactionType` name (§31.12) |
| `LogProgressionEvent(player, pathName, Enum.AnalyticsProgressionType.Complete, level, levelName, customFields)` | paths `PlayerLevel` (§14), `RestaurantTier` (1–10), `StoryChapter` (1–10) | `Start` is logged for `StoryChapter` when a chapter opens |
| `LogCustomEvent(player, eventName, value, customFields)` | the budgeted custom events flagged "custom" in §31.10 | `value` is a meaningful number (seconds, MB, count) or 1 |

**Ruling — one onboarding funnel.** Roblox supports a single onboarding funnel per experience. It is the §32
tutorial (as §1.7 and AC-32-03 define). The §36.17 milestones `MLS_001`–`MLS_013` therefore log their
events through the recurring funnel `mmr_first_session` (step = milestone order 1–13) rather than through
`LogOnboardingFunnelStepEvent`; this supersedes the onboarding wording in AC-14-20.

**Custom-field convention** (shared with §32): `CustomField01` = variant/context (e.g. `skipped`, a source code,
a district ID); `CustomField02` = input mode (`KBM`, `Gamepad`, `Touch`) or platform; `CustomField03` =
event-specific low-cardinality bucket. Numbers are bucketed (e.g. offline hours `0-2`, `2-4`, `4-8`, `8-12`,
`12-24`).

### 31.9 Internal Event Schema

Every event — whether or not it is forwarded to `AnalyticsService` — is built as one envelope by `Telemetry`.
Studio prints envelopes to the Output; production forwards them to `AnalyticsService` per the catalog and, only if
`analyticsExport` is enabled, batches them to the external collector, which replaces the UserId with a salted
pseudonymous `pid` on ingest and never stores the raw id.

| Field | Type | Meaning |
|---|---|---|
| `schema` | int | envelope version (1) |
| `event` | string | catalog name, `mmr_…` |
| `ts` | int | server `os.time()` |
| `seq` | int | per-session counter (dedupe at the collector) |
| `session` | string | per-session GUID (`HttpService:GenerateGUID(false)`) |
| `server` | object | `place` (`main` / `arena`), `build`, `cv` (ContentVersion, §27.5) |
| `player` | object | `level`, `tier`, `daysSinceInstall`, `sessionIndex`, `platform`, `deviceTier`, `inputMode`, `ab` (experiment buckets) |
| `props` | object | event-specific properties from §31.10 (numbers, enums, content IDs only) |

```json
{
  "schema": 1,
  "event": "mmr_offline_collected",
  "ts": 1791972000,
  "seq": 418,
  "session": "b7c1d2e0-5f3a-4c11-9a77-0e4b2a9c8d10",
  "server": { "place": "main", "build": "2026.10.11.3", "cv": "3f9a1c27" },
  "player": { "level": 27, "tier": "TIER_05", "daysSinceInstall": 9, "sessionIndex": 23,
              "platform": "mobile", "deviceTier": "LOW", "inputMode": "Touch",
              "ab": { "welcome_copy_v2": "B" } },
  "props": { "hours": 7.4, "capped": false, "net": 11700, "customers": 183,
             "managerCap": 8, "delaySinceShownS": 12, "firstOfDay": true }
}
```

```lua
--!strict
-- ServerScriptService/Server/Framework/Telemetry/Events.lua (the analytics half of §27's Telemetry module)
local AnalyticsService = game:GetService("AnalyticsService")

export type Props = { [string]: string | number | boolean }
type Def = {
	route: "custom" | "internal",   -- "custom" = forwarded with LogCustomEvent; "internal" = envelope only
	firstBit: number?,               -- once-only: bit index into meta.analytics.firstsBits (§28.9.2)
	sample: number?,                 -- 0..1 sampling rate
	fields: { string }?,             -- prop names mapped to CustomField01..03, in order
}
type Deps = {
	getAnalyticsState: (Player) -> any,  -- PlayerDataService: profile.data.meta.analytics
	markDirty: (Player) -> (),           -- PlayerDataService:MarkDirty(player, "meta")
	envelope: (Player, string, Props) -> { [string]: any },
	export: ({ [string]: any }) -> (),   -- no-op unless the analyticsExport flag is on
}

local CF = Enum.AnalyticsCustomFieldKeys
local FIELD_KEYS = { CF.CustomField01.Name, CF.CustomField02.Name, CF.CustomField03.Name }

local DEFS: { [string]: Def } = {      -- excerpt; the full registry is generated from §31.10
	mmr_first_order = { route = "custom", firstBit = 1, fields = { "tier" } },
	mmr_first_tantrum = { route = "custom", firstBit = 4, fields = { "personalityId" } },
	mmr_session_end = { route = "custom", fields = { "endReason", "inputMode", "lengthBand" } },
	mmr_ability_used = { route = "custom", sample = 0.10, fields = { "abilityId", "context" } },
	mmr_order_served = { route = "internal" },
}

local function testAndSetBit(words: { number }, bit: number): boolean -- true if it was already set
	local w, b = bit // 32 + 1, bit % 32
	local word = words[w] or 0
	if bit32.btest(word, bit32.lshift(1, b)) then
		return true
	end
	while #words < w do
		table.insert(words, 0)
	end
	words[w] = bit32.bor(word, bit32.lshift(1, b))
	return false
end

local Events = {}

function Events.track(d: Deps, player: Player, name: string, props: Props, value: number?)
	local def = DEFS[name]
	if def == nil then
		warn("[Telemetry] unregistered event " .. name)    -- CI rejects unregistered call sites too
		return
	end
	if def.sample ~= nil and math.random() > def.sample then
		return
	end
	if def.firstBit ~= nil then
		local state = d.getAnalyticsState(player)
		if state == nil or testAndSetBit(state.firstsBits, def.firstBit) then
			return                                          -- already logged for this account
		end
		d.markDirty(player)
	end
	local env = d.envelope(player, name, props)
	if def.route == "custom" then
		local fields: { [string]: string } = {}
		for i, key in def.fields or {} do
			local v = props[key]
			if v ~= nil and i <= 3 then
				fields[FIELD_KEYS[i]] = tostring(v)
			end
		end
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields)
	end
	d.export(env)
end

return Events
```

### 31.10 Event Catalog

Legend for the last column — **Onb N**: onboarding funnel step N; **FS N**: `mmr_first_session` funnel step N;
**Fun `<name>` N**: recurring funnel step; **Custom** (fields CF01/CF02/CF03): `LogCustomEvent` (counts toward
the 60-name budget, 53 used); **Prog `<path>`**: `LogProgressionEvent`; **Econ**: `LogEconomyEvent` by
`EconomyService`; **Internal**: envelope only. Names already used by other sections are kept verbatim.

#### 31.10.1 Onboarding, tutorial and first moments

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_tutorial_step_01` … `mmr_tutorial_step_12` | completion of `QST_TUT_001` … `QST_TUT_012` (§32) | step, durationS, skipped, inputMode, step-specific field (§32) | **Onb 1–12** (CF01 `skipped`, CF02 input mode, CF03 per §32) |
| `mmr_tutorial_assist` | a §32 tutorial assist fires | step, assist (`burn_recovery`, `auto_flip`, `assembly_ghost`, …) | Custom (CF01 assist, CF03 step) |
| `mmr_tutorial_skip` | player confirms the skip | atStep | Custom (CF03 step) |
| `mmr_tutorial_resume` | a session resumes an unfinished tutorial | atStep, hoursSinceLast | Custom (CF03 step) |
| `mmr_tutorial_complete` | `QST_TUT_012` done (also `MLS_013`) | totalDurationS, skipped, assistsUsed | Custom (value = totalDurationS) + **FS 13** |
| `mmr_onboarding_enter_restaurant` | first interior entry (`MLS_001`) | secondsSinceJoin | **FS 1** |
| `mmr_first_order` | first order taken (`MLS_002`) | tier, secondsSinceInstall | **FS 2** |
| `mmr_first_successful_meal` | first dish served with S ≥ 50 (`MLS_003`) | satisfaction band, quality grade | **FS 3** |
| `mmr_first_tip` | first tip (`MLS_004`) | tipBand | **FS 4** |
| `mmr_first_tantrum` | first customer reaches anger level 3 (`MLS_005`) | personalityId (scripted `PER_001` in tutorial) | **FS 5** |
| `mmr_first_combat` | first damage dealt to a hostile customer (`MLS_006`) | abilityId | **FS 6** |
| `mmr_first_calm_down` | first hostile customer reaches Apologizing (`MLS_007`) | method | **FS 7** |
| `mmr_first_repair` | first object repaired (`MLS_008`) | objectRef | **FS 8** |
| `mmr_first_ko` | first Seeing Stars (`MLS_009`) | killerStyle | **FS 9** |
| `mmr_first_mutation` | first part equipped (`MLS_010`) | partId (`MUT_145` / `MUT_144` / `MUT_153`) | **FS 10** (CF01 part) |
| `mmr_first_restaurant_upgrade` | first upgrade or furniture purchase (`MLS_011`) | itemRef | **FS 11** |
| `mmr_first_employee_hire` | `EMP_001` hired (`MLS_012`) | — | **FS 12** |
| `mmr_first_offline_collect` | first Welcome Back report collected (`MLS_017`) | hours, net, capped | Custom (value = net) |
| `mmr_first_city_trip` | first district other than `DST_01` (`MLS_018`) | district, travelMode | Custom (CF01 district) |
| `mmr_first` | any other once-only first (`mmr_first_level_up`, `mmr_first_stat_allocation`, `mmr_first_skill_node`, `mmr_first_capsule`, `mmr_first_lab_fusion`, `mmr_first_mutation_upgrade`, `mmr_first_synergy`, `mmr_first_perfect_dish`, `mmr_first_recipe_learned`, `mmr_first_station_upgrade`, `mmr_first_quest_complete`, `mmr_first_metro_ride`, `mmr_first_city_event`, `mmr_first_coop_visit`, `mmr_first_arena_match`) | which (the internal name), hoursSinceInstall | Custom grouped (CF01 which) — internal envelope keeps the specific name |

#### 31.10.2 Sessions and retention

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_session_start` | profile loaded (§28.14) | sessionIndex, daysSinceInstall, daysSinceLastSession, platform, deviceTier, offlineReportPending | Custom (value = daysSinceLastSession; CF01 platform, CF02 input mode) |
| `mmr_join_ready` | `UI.Ready` received (§27.11) | loadMs, deviceTier | Custom (value = loadMs; CF01 device tier) |
| `mmr_daily_return` | first session of a new UTC day for a returning player | dayIndex (days since install), streak | Custom (value = dayIndex) |
| `mmr_return_visit` | first session on a second distinct UTC day — once (`MLS_031`) | daysSinceInstall | Custom |
| `mmr_session_end` | `PlayerRemoving` / shutdown | durationS, activeS, endReason, ordersServed, perfectRate, avgSatisfaction, tantrums, brawls, kos, mbNet, partsGained | Custom (value = durationS; CF01 end reason, CF02 input mode, CF03 length band) |

#### 31.10.3 Restaurant, customers and combat

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_order_served` | ticket settled (`OrderService`) | recipeId, satisfaction, quality, waitPct, mods, tipBand | Internal (aggregated into `mmr_session_end`) |
| `mmr_customer_walkby` | party leaves because the line is full (§8) | tier, queueLength | Internal |
| `mmr_customer_poof` | E10 poof to a seat (§8) | tier, layoutHash | Custom (CF01 tier) — finds bad layouts |
| `mmr_combat_encounter_start` | first hostile of an encounter (§11) | tier, trigger, hostiles | Internal |
| `mmr_combat_encounter_end` | encounter resolved (§11) | durationS, hostiles, playerKos, calmedBy, durabilityLostPct | Custom (value = durationS; CF01 calmedBy, CF03 tier) |
| `mmr_player_ko` | Seeing Stars (§11) | tier, killerStyle, hadSecurity | Custom (CF01 killer style, CF03 tier) |
| `mmr_customer_calmed` | hostile reaches Apologizing (§11) | method, personalityId | Custom (CF01 method, CF02 personality) |
| `mmr_ability_used` | ability activation accepted (10 % sampled, §11) | abilityId, context | Custom (CF01 ability, CF02 context) |
| `mmr_prop_thrown` | prop thrown (10 % sampled, §11) | propClass, hitKind | Custom (CF01 prop class) |
| `mmr_restaurant_tier_up` | tier upgrade completed (`MLS_046`+; §22 calls it `mmr_tier_upgraded`) | tier, activeHoursSinceInstall, level | **Prog `RestaurantTier`** (level = tier number) |
| `mmr_station_upgraded` | station level purchased | stationRef, newLevel | Internal |
| `mmr_employee_hired` | hire committed (`EmployeeService`) | archetype, rarity, role, cost | Custom (CF01 rarity, CF02 role) + **Fun `mmr_hire` 3** |
| `mmr_unpaid_break` | wage tick uncovered (E8, §22) | staffCount, deficit | Custom (CF03 tier) |

#### 31.10.4 Mutations and morph

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_mutation_acquired` | part added to `mutations.owned` (new or duplicate) | partId, rarity, source (§C13.8 code), duplicate | Custom (CF01 source, CF02 rarity) |
| `mmr_capsule_opened` | capsule result committed | rarity, pityCount, pityTriggered | **Fun `mmr_capsule` 3** (CF01 rarity, CF03 pity yes/no) |
| `mmr_mutation_upgraded` | upgrade applied | partId, rarity, newLevel, usedDuplicate | Custom (CF01 rarity, CF03 level) |
| `mmr_lab_fusion` | fusion applied | resultRarity, category | Custom (CF01 result rarity) |
| `mmr_loadout_swap` | loadout swap completed (E4) | fromSlot, toSlot | Internal |
| `mmr_morphdex_spotted` | new Morphdex cell spotted (§12b) | headFamily, domFamily | Internal |
| `mmr_morphdex_worn` | new Morphdex cell worn (§12b) | headFamily, domFamily | Custom (CF01 head family) |
| `mmr_signature_unlocked` | signature combination unlocked (§12b) | signatureKey | Custom (CF01 key) |

#### 31.10.5 Offline earnings

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_offline_report_shown` | Welcome Back screen opened with a pending report | hours, capHours, capped, customers, net, incidents, segments | **Fun `mmr_offline_collect` 1** (CF01 capped, CF03 hours band) |
| `mmr_offline_collected` | Collect committed (key `offline:<reportId>`) | hours, net, delaySinceShownS, firstOfDay | Custom (value = net) + **Fun `mmr_offline_collect` 3** |
| `mmr_welcome_back_crate` | E5 crate granted (absence ≥ 7 days) | daysAway | Custom (value = daysAway) |

#### 31.10.6 Quests, progression and achievements

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_quest_completed` | quest reaches `COMPLETE` | questId, type (TUT/STY/DLY/WKY/CHF/CBT/RPR/EXP/EMP/RST), durationS | Custom (CF01 type, CF02 quest ID) |
| `mmr_quest_claimed` | quest reward claimed | questId, rewardMB, rewardMS, rewardRT | Internal (money also via Econ) |
| `mmr_daily_set_complete` | all 3 dailies claimed in one UTC day | streak | Custom |
| `mmr_story_chapter` | chapter opens / completes | chapter | **Prog `StoryChapter`** (Start / Complete) |
| `mmr_level_up` | level gained (§14) | level, hoursActive | **Prog `PlayerLevel`** (§14) |
| `mmr_level_band_reached` | milestone levels 5/10/12/15/20/25/30/40/50/60/75/90/100 (§36.17) | level | Custom (CF03 level) |
| `mmr_stat_allocated` | stat point allocated (§14) | stat, newValue | Internal |
| `mmr_skill_node_unlocked` | skill node rank committed (§14) | node, rank | Custom (CF01 node) |
| `mmr_respec` | respec (§14) | kind, paid, cost, level | Custom (CF01 kind) |
| `mmr_xp_session_summary` | session end (§14) | xpu by tag | Internal |
| `mmr_xp_anomaly` | > 180 XPU in a rolling hour (§14) | rate, tag | Custom (ops) |
| `mmr_achievement_unlocked` | achievement claimed (§36.16) | achievementId | Custom (CF01 ID) |
| `mmr_milestone_reached` | milestone claimed (§36.17) | milestoneId | Custom (CF01 ID) |
| `mmr_overtime_bar` | Overtime bar filled (`MLS_045`) | barIndex | Custom (value = barIndex) |
| `mmr_journal_opened` | quest/achievement journal opened (§36.16) | tab | Internal |

#### 31.10.7 City exploration, social and events

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_city_district_enter` | player enters a district (§18) | district, firstVisit | Custom (CF01 district) |
| `mmr_city_travel` | Metro / Pigeon Taxi / Return Door / walk arrival (§18) | mode, cost, from, to | Custom (CF01 mode) |
| `mmr_city_secret_found` | secret discovered (§18) | secretKey, district | Custom (CF01 district) |
| `mmr_city_event_join` | joins a city event (§18) | eventId | Custom (CF01 event ID) |
| `mmr_city_event_result` | event result band (§18) | eventId, band, erm | Custom (CF01 event ID, CF03 band) |
| `mmr_city_away_mode` | restaurant runs while the owner explores (§18) | staffed, minutes | Internal |
| `mmr_building_enter` | building entered (§36.10) | buildingId | Internal |
| `mmr_shop_purchase` | shop purchase committed (§36.10) | buildingId, item, currency, amount | **Fun `mmr_shop` 3** (CF01 building, CF02 currency) |
| `mmr_coop_visit_end` | co-op visit settles (§21) | durationS, role (owner/guest), ordersHelped | Custom (value = durationS; CF01 role) |
| `mmr_arena_match_end` | arena match ends (§21) | result, ratingDelta | Custom (CF01 result) |

#### 31.10.8 Economy, monetization and operations

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_currency_tx` | every committed transaction (§22) | reason, currency, delta, balance, sku | **Econ** (one `LogEconomyEvent` per currency moved) |
| `mmr_wallet_snapshot` | first save of each UTC day (§22) | MB, MS, RT balances | Internal |
| `mmr_economy_cap_hit` | grant clamped at a hard cap (§22) | currency | Custom (CF01 currency) |
| `mmr_ms_softcap_hit` | repeatable MS soft cap reached (§22) | source | Custom (CF01 source) |
| `mmr_purchase_failed_insufficient` | repeated failed purchases throttled (§22) | reason | Custom |
| `mmr_cosmetic_purchase` | Robux cosmetic granted (§28.18) | skuCategory | Custom (CF01 category) — Robux revenue itself comes from Roblox's monetization dashboards |
| `mmr_perf_sample` | every 300 s per client (§30.20) | fpsP50, fpsP5, memMb, kbpsIn, kbpsOut, qualityTier | Custom (value = fpsP50; CF01 device tier, CF02 platform, CF03 tier band) |
| `mmr_service_error` | service error (§27) | service, phase | Custom (CF01 service) |
| `mmr_security_flag` | §29.17 flag raised | code, sev | Custom (CF01 code, CF03 sev) |
| `mmr_save_failed` | a save exhausted its retries (§28.16) | reason, attempt | Custom (CF01 reason) |
| `mmr_safe_mode_entered` | Safe Mode (§28.16) | cause | Custom (CF01 cause) |
| `mmr_profile_rollback` | automatic or support rollback (§28.20.4) | kind, ageH | Custom (CF01 kind) |
| `mmr_lock_steal` | lock rule L3/L4 applied (§28.13) | rule | Internal |
| `mmr_exp_exposure` | first exposure per session to an experiment (§31.16) | experiment, variant | Custom (CF01 `<experiment>:<variant>`) |
| `mmr_anim_load_fail`, `mmr_audio_load_fail` | asset load failure (§26) | assetKind | Internal |
| `mmr_ui_menu_blocked_combat` | menu blocked by E2 (§24) | screen | Internal |

### 31.11 Funnels

**Onboarding funnel** (the only one, §31.8): step N = completion of `QST_TUT_00N`/`QST_TUT_01N`, names
`mmr_tutorial_step_01` … `_12`. Completion KPI = step 12 ÷ step 1 (§1.7 target ≥ 80 %).

| Step | Quest | Step | Quest |
|---|---|---|---|
| 1 | `QST_TUT_001` Welcome to the Shack | 7 | `QST_TUT_007` Defend the Diner |
| 2 | `QST_TUT_002` Your First Order | 8 | `QST_TUT_008` Fix It Up |
| 3 | `QST_TUT_003` Burger 101 | 9 | `QST_TUT_009` Cash In |
| 4 | `QST_TUT_004` Plate It, Serve It | 10 | `QST_TUT_010` Your First Mutation |
| 5 | `QST_TUT_005` Happy Customer, Happy Wallet | 11 | `QST_TUT_011` Fancy Upgrades |
| 6 | `QST_TUT_006` Uh-Oh, Karenosaurus | 12 | `QST_TUT_012` Hire Help |

**First-session funnel** `mmr_first_session` (`LogFunnelStepEvent`, session id `"fs"`): steps 1–13 =
`MLS_001` … `MLS_013` in ID order (table §31.10.1). Because players can reach some moments out of order (a KO
before the first calm-down), dashboards read it as "% of new players who reached step N within 60 min", not as
strict conversion.

**Recurring funnels** (`LogFunnelStepEvent`, fresh `funnelSessionId` GUID per attempt):

| Funnel | Step 1 | Step 2 | Step 3 | Key question |
|---|---|---|---|---|
| `mmr_shop` | shop opened (`BLD_01`, `BLD_03`, `BLD_12`, `BLD_13` …) | item inspected | purchase committed | which shops convert, which items stall at inspection |
| `mmr_capsule` | capsule earned | reveal started | result shown (rarity, pity) | do players open capsules promptly; are odds observed as disclosed |
| `mmr_hire` | Recruitment Office (`BLD_04`) opened | candidate inspected | hire committed | does hiring stall on price |
| `mmr_offline_collect` | Welcome Back shown | Collect pressed | credited | collect rate (§1.7 target ≥ 95 %) |
| `mmr_tier_upgrade` | upgrade panel opened with an affordable next tier | confirm pressed | upgrade committed | hesitation at expensive tiers |
| `mmr_mutation_upgrade` | upgrade panel opened | confirm pressed | upgrade applied | MS/RT bottlenecks |


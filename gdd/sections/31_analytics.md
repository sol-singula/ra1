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
| First day | Do they come back to a Welcome Back report? | `mmr_session_start`, `mmr_offline_report_viewed`, `mmr_offline_collected` |
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
| `LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` | **the one onboarding funnel**: §32 tutorial steps 1–12 (`mmr_tutorial_step_01` … `_12`) and step 13 = first offline collection (`mmr_first_offline_collect`, §17.12) | logged once per player per step, sequentially (AC-32-03); custom field 01 = `skipped` when skipped |
| `LogFunnelStepEvent(player, funnelName, funnelSessionId, step, stepName, customFields)` | first-session moments (`mmr_first_session`) and recurring funnels (shop, capsule, hire, offline collect, tier upgrade, §31.11) | recurring funnels use a fresh GUID per attempt; `mmr_first_session` uses the constant session id `"fs"` |
| `LogEconomyEvent(player, flowType, currencyType, amount, endingBalance, transactionType, itemSku, customFields)` | every MB/MS/RT movement | only inside `EconomyService:TransactWith`; `currencyType` ∈ `MB`, `MS`, `RT`; `transactionType` = an `Enum.AnalyticsEconomyTransactionType` name (§31.12) |
| `LogProgressionEvent(player, pathName, Enum.AnalyticsProgressionType.Complete, level, levelName, customFields)` | paths `PlayerLevel` (§14), `RestaurantTier` (1–10), `StoryChapter` (1–10) | `Start` is logged for `StoryChapter` when a chapter opens |
| `LogCustomEvent(player, eventName, value, customFields)` | the budgeted custom events flagged "custom" in §31.10 | `value` is a meaningful number (seconds, MB, count) or 1 |

**Ruling — one onboarding funnel.** Roblox supports a single onboarding funnel per experience. It is the §32
tutorial (steps 1–12, as §1.7 and AC-32-03 define) followed by step 13, the first Welcome Back collection that §17.12
asks for — the D1 hook that completes onboarding. The first 13 §36.17 milestones (from `MLS_001`, the first-session "firsts") therefore log their
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
the 60-name budget, 55 used); **Prog `<path>`**: `LogProgressionEvent`; **Econ**: `LogEconomyEvent` by
`EconomyService`; **Internal**: envelope only. Names already used by other sections are kept verbatim.

#### 31.10.1 Onboarding, tutorial and first moments

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_tutorial_step_01` … `mmr_tutorial_step_12` | completion of `QST_TUT_001` … `QST_TUT_012` (§32) | step, durationS, skipped, inputMode, step-specific field (§32) | **Onb 1–12** (CF01 `skipped`, CF02 input mode, CF03 per §32) |
| `mmr_tutorial_assist` | a §32 tutorial assist fires | step, assist (`burn_recovery`, `auto_flip`, `assembly_ghost`, …) | Custom (CF01 assist, CF03 step) |
| `mmr_tutorial_skip` | player confirms the skip | atStep | Custom (CF03 step) |
| `mmr_tutorial_resume` | a session resumes an unfinished tutorial | atStep, hoursSinceLast | Custom (CF03 step) |
| `mmr_tutorial_complete` | `QST_TUT_012` done (also §36.17 milestone #13) | totalDurationS, skipped, assistsUsed | Custom (value = totalDurationS) + **FS 13** |
| `mmr_onboarding_enter_restaurant` | first interior entry (`MLS_001`, §36.17 #1) | secondsSinceJoin | **FS 1** |
| `mmr_first_order` | first order taken (§36.17 #2) | tier, secondsSinceInstall | **FS 2** |
| `mmr_first_successful_meal` | first dish served with S ≥ 50 (§36.17 #3) | satisfaction band, quality grade | **FS 3** |
| `mmr_first_tip` | first tip (§36.17 #4) | tipBand | **FS 4** |
| `mmr_first_tantrum` | first customer reaches anger level 3 (§36.17 #5) | personalityId (scripted `PER_001` in tutorial) | **FS 5** |
| `mmr_first_combat` | first damage dealt to a hostile customer (§36.17 #6) | abilityId | **FS 6** |
| `mmr_first_calm_down` | first hostile customer reaches Apologizing (§36.17 #7) | method | **FS 7** |
| `mmr_first_repair` | first object repaired (§36.17 #8) | objectRef | **FS 8** |
| `mmr_first_ko` | first Seeing Stars (§36.17 #9) | killerStyle | **FS 9** |
| `mmr_first_mutation` | first part equipped (§36.17 #10) | partId (`MUT_145` / `MUT_144` / `MUT_153`) | **FS 10** (CF01 part) |
| `mmr_first_restaurant_upgrade` | first upgrade or furniture purchase (§36.17 #11) | itemRef | **FS 11** |
| `mmr_first_employee_hire` | `EMP_001` hired (§36.17 #12) | — | **FS 12** |
| `mmr_first_offline_collect` | first Welcome Back report collected (§36.17 #17) | hours, net, capped | **Onb 13** (CF01 capped, CF03 hours band) |
| `mmr_first_city_trip` | first district other than `DST_01` (§36.17 #18) | district, travelMode | Custom (CF01 district) |
| `mmr_first` | any other once-only first (`mmr_first_level_up`, `mmr_first_stat_allocation`, `mmr_first_skill_node`, `mmr_first_capsule`, `mmr_first_lab_fusion`, `mmr_first_mutation_upgrade`, `mmr_first_synergy`, `mmr_first_perfect_dish`, `mmr_first_recipe_learned`, `mmr_first_station_upgrade`, `mmr_first_quest_complete`, `mmr_first_metro_ride`, `mmr_first_city_event`, `mmr_first_coop_visit`, `mmr_first_arena_match`) | which (the internal name), hoursSinceInstall | Custom grouped (CF01 which) — internal envelope keeps the specific name |

#### 31.10.2 Sessions and retention

| Event | Trigger (server) | Properties | AnalyticsService call |
|---|---|---|---|
| `mmr_session_start` | profile loaded (§28.14) | sessionIndex, daysSinceInstall, daysSinceLastSession, platform, deviceTier, offlineReportPending | Custom (value = daysSinceLastSession; CF01 platform, CF02 input mode) |
| `mmr_join_ready` | `UI.Ready` received (§27.11) | loadMs, deviceTier | Custom (value = loadMs; CF01 device tier) |
| `mmr_daily_return` | first session of a new UTC day for a returning player | dayIndex (days since install), streak | Custom (value = dayIndex) |
| `mmr_return_visit` | first session on a second distinct UTC day — once (§36.17 "Came Back!" milestone) | daysSinceInstall | Custom |
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
| `mmr_restaurant_tier_up` | tier upgrade completed (§36.17 tier milestones) | tier, activeHoursSinceInstall, level | **Prog `RestaurantTier`** (level = tier number) |
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
| `mmr_offline_report_generated` | after the join `UpdateAsync` commits a new or merged report (§17.12) | reportId-free summary: simVersion, tier, elapsedSec, simulatedSec, effectiveHours, capped, capHours, managerRarity, customers, net, ratioToActive | Custom (value = net; CF01 capped, CF02 manager rarity, CF03 tier) |
| `mmr_offline_report_viewed` | Welcome Back screen or tab opened (§17.12) | tab, secondsOnScreen, hours band | **Fun `mmr_offline_collect` 1** (CF01 tab, CF03 hours band) |
| `mmr_offline_collected` | Collect committed (key `offline:<reportId>`) | mb, delaySec, auto (via Continue), alreadyClaimed | Custom (value = mb) + **Fun `mmr_offline_collect` 3** |
| `mmr_offline_collect_failed` | Collect retries exhausted (§17.12) | reason | Internal |
| `mmr_offline_suggestion_clicked` | upgrade suggestion tapped (§17.12) | type | Internal |
| `mmr_offline_ceiling_hit` | a report clamped by a safety ceiling (§17.12; §29.14 E-R7) | amount | Custom (ops) |
| `mmr_offline_clock_skew` / `mmr_offline_merge` | skew or merge safety paths (§17.12) | skewSec / segments | Internal |
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
| `mmr_overtime_bar` | Overtime bar filled (§36.17 Overtime milestone) | barIndex | Custom (value = barIndex) |
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

**Onboarding funnel** (the only one, §31.8): steps 1–12 = completion of `QST_TUT_001` … `QST_TUT_012`, names
`mmr_tutorial_step_01` … `_12`; step 13 = first offline collection. Tutorial completion KPI = step 12 ÷ step 1
(§1.7 target ≥ 80 %); step 13 ÷ step 12 measures the next-day hook.

| Step | Quest | Step | Quest |
|---|---|---|---|
| 1 | `QST_TUT_001` Welcome to the Shack | 7 | `QST_TUT_007` Defend the Diner |
| 2 | `QST_TUT_002` Your First Order | 8 | `QST_TUT_008` Fix It Up |
| 3 | `QST_TUT_003` Burger 101 | 9 | `QST_TUT_009` Cash In |
| 4 | `QST_TUT_004` Plate It, Serve It | 10 | `QST_TUT_010` Your First Mutation |
| 5 | `QST_TUT_005` Happy Customer, Happy Wallet | 11 | `QST_TUT_011` Fancy Upgrades |
| 6 | `QST_TUT_006` Uh-Oh, Karenosaurus | 12 | `QST_TUT_012` Hire Help |
| — | — | 13 | first Welcome Back collection (`mmr_first_offline_collect`) |

**First-session funnel** `mmr_first_session` (`LogFunnelStepEvent`, session id `"fs"`): steps 1–13 =
the first 13 §36.17 milestones (`MLS_001` onward) in ID order (table §31.10.1). Because players can reach some moments out of order (a KO
before the first calm-down), dashboards read it as "% of new players who reached step N within 60 min", not as
strict conversion.

**Recurring funnels** (`LogFunnelStepEvent`, fresh `funnelSessionId` GUID per attempt):

| Funnel | Step 1 | Step 2 | Step 3 | Key question |
|---|---|---|---|---|
| `mmr_shop` | shop opened (`BLD_01`, `BLD_03`, `BLD_12`, `BLD_13` …) | item inspected | purchase committed | which shops convert, which items stall at inspection |
| `mmr_capsule` | capsule earned | reveal started | result shown (rarity, pity) | do players open capsules promptly; are odds observed as disclosed |
| `mmr_hire` | Recruitment Office (`BLD_04`) opened | candidate inspected | hire committed | does hiring stall on price |
| `mmr_offline_collect` | Welcome Back viewed (`mmr_offline_report_viewed`) | Collect pressed | credited (`mmr_offline_collected`) | collect rate (§1.7 target ≥ 95 %) |
| `mmr_tier_upgrade` | upgrade panel opened with an affordable next tier | confirm pressed | upgrade committed | hesitation at expensive tiers |
| `mmr_mutation_upgrade` | upgrade panel opened | confirm pressed | upgrade applied | MS/RT bottlenecks |

### 31.12 Economy Telemetry (reason codes)

`EconomyService:TransactWith` logs one `LogEconomyEvent` per currency moved, with `flowType` Source/Sink,
`currencyType` = `MB`/`MS`/`RT`, `endingBalance` = the post-transaction balance, `transactionType` from the table
and `itemSku` = the content ID when one exists. These codes are the registry §22.2 rule 3 refers to; their
per-transaction ceilings are in §29.14. Zero-delta transactions log nothing.

| Reason code | Flow | Currencies | `transactionType` | `itemSku` |
|---|---|---|---|---|
| `serve_payment` | Source | MB | `Gameplay` | recipe ID (`RCP_…`) |
| `serve_tip` | Source | MB | `Gameplay` | recipe ID |
| `quest_reward` | Source | MB, MS, RT | `Onboarding` for `QST_TUT_…`, else `Gameplay` | quest ID |
| `achievement_reward` / `milestone_reward` | Source | MB, MS, RT | `Gameplay` | achievement / milestone ID |
| `event_reward` | Source | MB, MS, RT | `Gameplay` | event ID (`EVT_…`) |
| `delivery_reward` | Source | MB | `Gameplay` | `BLD_15` |
| `daily_login` | Source | MB, MS | `TimedReward` | streak day bucket |
| `offline_collect` | Source | MB, MS | `TimedReward` | `offline` |
| `welcome_back` | Source | MS | `TimedReward` | `welcome_back` |
| `coop_guest_pay` | Source | MB | `Gameplay` | `coop` |
| `arena_reward` | Source | MS, RT | `Gameplay` | `arena` |
| `showcase_reward` | Source | MS | `Gameplay` | `BLD_22` |
| `dupe_conversion` | Source | MS | `Gameplay` | part ID |
| `furniture_sellback` | Source | MB | `Shop` | furniture ID (§22) |
| `ingredient_cost` | Sink | MB | `Gameplay` | recipe ID or ingredient ID |
| `wages` | Sink | MB | `Gameplay` | `wages` |
| `repair` | Sink | MB | `Gameplay` | furniture ID |
| `tier_upgrade` | Sink | MB | `Shop` | tier ID |
| `station_purchase` / `station_upgrade` / `furniture_purchase` | Sink | MB | `Shop` | furniture or upgrade ID |
| `mutation_purchase` | Sink | MB, MS, RT | `Shop` | part ID |
| `mutation_upgrade` | Sink | MB, MS, RT | `Shop` | part ID |
| `lab_fusion` | Sink | MB, MS, RT | `Shop` | result rarity |
| `hire` | Sink | MB | `Shop` | archetype ID (`EMP_…`) |
| `recipe_learn` | Sink | MB | `Shop` | recipe ID |
| `respec` | Sink | MB | `Shop` | `stat` / `skill` |
| `pigeon_taxi` | Sink | MB | `ContextualPurchase` | destination district |
| `cosmetic_mb` | Sink | MB | `Shop` | cosmetic key |
| `robux_cosmetic` | — (zero delta) | — | not logged (Roblox monetization dashboards) | — |
| `mod_reversal` | Sink | any | not logged to `AnalyticsService` (internal only, keeps dashboards clean) | case reference |

Robux is never a currency in these events: Robux buys cosmetics only (§C4.1), and Robux revenue is read from
Roblox's native monetization analytics.

### 31.13 KPI Definitions and Targets

Targets restate §1.7 [TUNABLE]; this table owns the formulas. "Day N" uses UTC days, install day = day 0.

| KPI | Definition | Source | Target |
|---|---|---|---|
| CCU | concurrent players, sampled per minute | Creator Hub (native) | tracked; launch-month peak goal [TUNABLE] 5,000 |
| Peak CCU | max per-minute CCU in a UTC day | native | rising week-over-week during live events |
| DAU | unique players with ≥ 1 session in a UTC day | native + `mmr_session_start` | tracked |
| D1 / D7 / D30 retention | % of a day-0 cohort with a session on day 1 / 7 / 30 | native retention; cross-check `mmr_session_start.daysSinceInstall` | **≥ 35 % / ≥ 15 % / ≥ 6 %** |
| Average session length | mean `mmr_session_end.durationS` (sessions ≥ 30 s) | custom | **≥ 22 min** |
| Sessions per DAU | sessions ÷ DAU | `mmr_session_start` | **≥ 2.0** |
| Tutorial completion | onboarding step 12 ÷ step 1 | onboarding funnel | **≥ 80 %**; skip rate ≤ 15 % |
| First hire in session 1 / first mutation in session 1 | % of new players reaching FS 12 / FS 10 in their first session | `mmr_first_session` | ≥ 75 % / ≥ 85 % |
| Restaurant progression distribution | median and p25/p75 cumulative active hours to reach each tier vs §C4.4; % of players at each tier by day 1/7/30 | `RestaurantTier` progression + `mmr_session_end.activeS` | medians within ± 25 % of §C4.4; median TIER_02 ≤ 90 min |
| Mutation collection | distinct parts owned at D7 / D30; share of MB spent on mutations | `mmr_mutation_acquired`, Econ sinks | ≥ 50 % of D7 players own ≥ 15 parts; ≥ 40 % of MB spent on mutations by D30 median |
| Offline-earnings engagement | collect rate = Fun step 3 ÷ step 1; % of D1 returners whose first screen is Welcome Back; % of reports capped | `mmr_offline_collect` funnel, `mmr_session_start` | collect ≥ 95 %; Welcome-Back-first ≥ 70 % |
| Offline share of MB income | offline-collect MB ÷ all MB sources, per player, median | Econ | D7 ≤ 60 %, D30 ≤ 70 % (§1.7, §4.5) |
| Offline rate ratio | (offline net ÷ simulated hours) ÷ (active net per active hour) at the same tier | `mmr_offline_report_generated.ratioToActive`, cross-checked with Econ and `activeS` | 35–50 %, never > 60 % (§C15) |
| Chaos health | % of sessions ≥ 10 min with ≥ 1 brawl (anger level ≥ 5) | `mmr_session_end.brawls` | ≥ 70 % |
| Social reach | % of players who visit or co-op another restaurant by D7 | `mmr_coop_visit_end`, visits | ≥ 20 % |
| Revenue per active user | ARPDAU = Robux revenue ÷ DAU; payer conversion = payers ÷ MAU; ARPPU | native monetization | [TUNABLE] ARPDAU ≥ 0.5 R$, conversion ≥ 1.5 % by D30 — cosmetics only, never a gameplay lever |
| Technical quality | crash-free sessions; join → `UI.Ready` p95; FPS p5 on LOW | native + `mmr_join_ready`, `mmr_perf_sample` | ≥ 99.5 %; ≤ 20 s; ≥ 25 FPS |

### 31.14 Dashboards

| Dashboard | Audience · refresh | Panels |
|---|---|---|
| Live Ops | on-call · 1 min (native) / 5 min (export) | CCU, joins/min, `mmr_safe_mode_entered`, `mmr_save_failed`, `mmr_service_error`, server Heartbeat p95, lock steals |
| Onboarding | design · daily | step 1–12 drop-off, time per step, skips, assists, starter-part split (`MUT_145` / `MUT_144` / `MUT_153`), FS 1–13 reach within 60 min |
| Retention | leads · daily | D1/D7/D30 by cohort and platform, sessions per DAU, session-length histogram, daily returns, Welcome-Back-first share |
| Economy | economy · daily | sources and sinks per currency and tier, net MB per active hour vs §C4.4, balance percentiles, cap and soft-cap hits, failed purchases |
| Pacing | progression · weekly | tier and level reach times vs §C4.4 / §C5.1, story chapter progression, stuck-at-tier cohorts |
| Offline | economy · daily | collect rate, hours and cap distribution, offline share D7/D30, offline rate ratio by tier, manager-cap mix, incident mix |
| Morph | design · weekly | parts owned D7/D30, capsule rarity observed vs disclosed odds, pity rate, top-part usage share, fusion/upgrade funnels, Morphdex fill |
| Chaos & Combat | design · weekly | tantrums/brawls/KOs per session, encounter duration, calmed-by mix, KO-heavy first sessions vs D1, poofs by layout |
| City & Social | design · weekly | district reach, travel modes, secrets found, event participation and result bands, co-op visits, arena |
| Monetization | leads · weekly | native Robux dashboards, cosmetic categories (`mmr_cosmetic_purchase`), payer conversion, ARPDAU |
| Performance | engineering · daily | FPS p50/p5, memory and bandwidth by device tier, join time, auto-scaler tier distribution |
| Security | ops · daily | flags by code and severity, earnings holds, reversals, bans (counts only) |

### 31.15 Data-Driven Balancing (decision rules)

A rule fires only with ≥ `MIN_COHORT` players in the measured cohort for ≥ 7 days. **Release path:** canon economy
formulas, offline coefficients and `SIM_VERSION` are *never* remotely tunable (§27.15) — they change only through a
content release (with a `SIM_VERSION` bump for offline). Presentation and onboarding levers may use remote flags.

| Signal | Threshold | Tuning lever (first → last) | Owner | Release path |
|---|---|---|---|---|
| Median cumulative active hours to reach tier T vs §C4.4 | > +25 % (too slow) | raise early quest MB (within §22 budgets) → reduce `TIER_` cost for T (canon amendment) | §22, §15 | content release |
| Same | < −25 % (too fast) | trim quest/event MB shares → raise tier cost (canon amendment) | §22 | content release |
| Median time to `TIER_02` | > 90 min | tutorial MB rewards → TIER_01 income levers | §32, §22 | content release |
| Offline share of MB income | D7 median > 60 % or D30 > 70 % | `OFFLINE_DEMAND_FACTOR` 0.6 → ≈ 0.35 (§4.5.4 order) → cap semantics (§17) → manager caps (§C14.3) | §17 | content release + `SIM_VERSION` bump |
| Offline rate ratio at any tier | > 50 % (target band) or > 60 % (canon violation) | fix §17 coefficients; > 60 % is a hotfix | §17 | hotfix + `SIM_VERSION` bump |
| Reports capped | > 60 % of reports capped while D1 < 35 % | make Rare/Epic Managers easier to reach (hire price, §36.8) before touching caps | §16 | content release |
| Offline collect rate | < 95 % | Welcome Back clarity (§24) | §24 | remote flag (UI variant) |
| Tantrum vs churn | players with ≥ 3 KOs in their first 30 min show D1 ≥ 10 points below cohort | lower T1–T3 `AngerProbability` (§10) → earlier `ABL_006` coaching | §10, §32 | content release |
| Brawl rate | < 70 % of sessions ≥ 10 min have a brawl | raise escalation probabilities at T2+ (§10) | §10 | content release |
| Brawl overload | median encounter duration > 90 s or > 4 encounters per 10 min | lower escalation, shorten Huff Points (§11) | §10, §11 | content release |
| Tutorial step drop-off | any single step loses > 8 % | redesign that step (§32); temporary assist via flag | §32 | remote flag, then content |
| Mutation spend share | < 40 % of MB on mutations by D30 | Mart rotations and "Next Morph" prompts (§4, §12) | §12, §22 | content release |
| Part dominance | any part equipped in > 60 % of active loadouts at its rarity | rebalance that part (§36.3) | §12 | content release |
| Capsule pity | observed pity-trigger rate deviates > 2 points from the expected ≈ 9 % of 40-capsule windows (0.94^39, §C4.7 Epic-or-better = 6 %) | RNG audit; odds must match disclosure | §12 | hotfix |
| Session length | < 22 min average | medium-session activity menu (§4.3), event cadence (§18) | §4, §18 | content / remote schedule |
| Economy flags | `econ_rate_3x` on > 0.5 % of DAU | investigate exploit vs mis-tuned threshold (§29.14) | §29 | hotfix |
| Customer poofs | > 1 poof per 30 customers on a layout hash | fix placement validation (§15) | §15 | content release |
| Safe Mode | > 0.1 % of sessions | DataStore incident response (§28.16) | §28 | ops |

### 31.16 Experimentation and Feature Flags

- **Platform.** Flags and experiments live in §27.15's `RemoteConfig` (`mmr_remote_config` sorted map, 60 s poll,
  `mmr_config` fast path). An experiment is a key `exp.<name>` = `{ variants, weights, salt, startDay, endDay,
  eligibility = { minLevel, maxLevel, platforms }, guardrails }`, validated against defaults; the safe default
  is always variant A.
- **Assignment** is deterministic and sticky — the same player gets the same variant on every server — with no
  storage needed; exposure is logged once per session (`mmr_exp_exposure`) at the moment the variant first
  changes what the player sees.
- **Allowed:** UI layouts and copy, tutorial pacing within §32's rules, tooltip timing, shop/menu presentation,
  event schedule within approved ranges, performance tunables (`tunables.aiThinkHz`, `batchHz`, §27.15).
- **Never:** canon economy formulas, prices, rewards, offline coefficients, `SIM_VERSION` (§27.15); capsule odds
  or pity (disclosed odds must be true for everyone, §C4.7); anything that changes combat fairness or PvP;
  anything targeted by age; Robux prices.
- **Readout:** pre-registered primary metric and guardrails (D1, session length, crash-free sessions, collect
  rate); ≥ `MIN_COHORT` per arm; minimum 7 days; stop early only for guardrail breaches.

```lua
--!strict
-- ServerScriptService/Server/Framework/Experiments.lua (excerpt)
-- FNV-1a over "userId:experiment:salt", computed with exact 32-bit arithmetic.
local function hash32(key: string): number
	local h = 2166136261
	for i = 1, #key do
		h = bit32.bxor(h, string.byte(key, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296   -- h * 16777619 mod 2^32 without precision loss
	end
	return h
end

local function variantFor(userId: number, name: string, salt: string, weights: { number }): number
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = hash32(string.format("%d:%s:%s", userId, name, salt)) % total
	for i, w in weights do
		if roll < w then
			return i                                          -- 1 = control (variant A)
		end
		roll -= w
	end
	return 1
end

return { variantFor = variantFor }
```

### 31.17 Privacy and Compliance

- **No PII.** No names, display names, emails, ages, locations, device identifiers or IP addresses are collected.
  `AnalyticsService` data is processed by Roblox under its own policies; the optional export replaces the UserId
  with a salted pseudonymous id at ingest and never stores the raw id.
- **No chat logging.** Chat is never read, stored or analyzed by our code; moderation of chat is Roblox's. Player
  free text (morph names, loadout names) never enters analytics or logs.
- **Under-13 players.** The game treats every player as potentially under 13: no behavioral advertising, no
  third-party ad or analytics SDKs, no fingerprinting, no social-media links, no data sold or shared. Features
  that vary by region or policy (e.g. paid random items — which this game never sells) are gated with
  `PolicyService:GetPolicyInfoForPlayerAsync`.
- **Minimization and retention.** Only catalogued properties are recorded; the export keeps 13 months of events,
  then aggregates; DAU-level aggregates may be kept indefinitely.
- **Erasure.** Right-to-erasure requests remove export rows by pseudonymous id within the §28.24 procedure.
- **Transparency.** The settings privacy line (§31.4) states what is counted.

### 31.18 Edge Cases

| # | Situation | Behavior |
|---|---|---|
| AE-01 | Player hops servers mid-session | `firstsBits` and `onboardingStep` travel with the profile, so firsts and funnel steps never repeat; the new server starts a new analytics session |
| AE-02 | Server shuts down (E13) | `BindToClose` emits `mmr_session_end` (`endReason = shutdown`) before saves; if the budget runs out the event is dropped, never the save |
| AE-03 | Safe Mode session | only `mmr_session_start`, `mmr_safe_mode_entered` and `mmr_session_end` are logged; gameplay events are impossible, and firsts are not set (the profile is not saved) |
| AE-04 | `AnalyticsService` throttling | `Telemetry` drops lowest-priority events first (sampled → internal-only → custom), never economy or onboarding events |
| AE-05 | Custom-field value outside the registry | bucketed to `other` and counted in `mmr_service_error` (registry drift) |
| AE-06 | Experiment ends mid-session | the player keeps the variant until the session ends; no mid-session flip |
| AE-07 | Tutorial skipped | steps are still logged in order with `CustomField01 = skipped` (AC-32-03) |
| AE-08 | Offline report merged across two sessions | one `mmr_offline_report_generated` per commit and one `mmr_offline_report_viewed` per showing; `segments` records the merge; collect logged once by `reportId` key |
| AE-09 | Studio play test | `Telemetry` prints envelopes and never calls `AnalyticsService` or the export |
| AE-10 | Reversal by moderation | `mod_reversal` is excluded from economy dashboards; counted only in the security dashboard |

### 31.19 Acceptance Criteria

- **AC-31-01:** Every event emitted in code exists in the §31.10 catalog (CI scan of `Telemetry.track` call sites: 0 unregistered names), and the number of distinct `LogCustomEvent` names in production stays ≤ 60.
- **AC-31-02:** Each brief-required moment — onboarding, tutorial completion, first order, first successful meal, first tantrum, first combat, first mutation, first restaurant upgrade, first employee hire, first offline collection, city exploration, quest completion, session duration, return visits — produces its event in a scripted end-to-end playthrough (14 of 14).
- **AC-31-03:** Once-only events fire at most once per account across 50 scripted reconnects and server hops (verified on the export and against `firstsBits`).
- **AC-31-04:** The onboarding funnel contains exactly the 12 tutorial steps plus step 13 (first offline collection), each logged once per player in order; only `TutorialDirector` and the first-collect path call `LogOnboardingFunnelStepEvent` (static scan).
- **AC-31-05:** For 1,000 randomized transactions, the sum of logged `LogEconomyEvent` amounts per currency equals the net wallet change (sources − sinks), excluding zero-delta and `mod_reversal` transactions.
- **AC-31-06:** No custom field or export property contains a UserId, display name, chat text or player-written string (automated scan of a 24-hour export sample: 0 hits).
- **AC-31-07:** Every §31.13 KPI is computable from the catalogued events or Roblox native analytics, and the KPI query suite runs green on soft-launch data.
- **AC-31-08:** Experiment assignment is identical for the same UserId across 3 servers and 10 sessions (100 % stickiness), and arms split within ± 1 percentage point of their weights over 100,000 simulated UserIds.
- **AC-31-09:** Telemetry keeps `AnalyticsService` calls ≤ 1 per 2 s per player on average during a 30-minute level-6 chaos session (sampling and aggregation verified).
- **AC-31-10:** Every §31.15 rule has a dashboard panel that shows its signal with the threshold drawn, and the weekly KPI review records each fired rule with its decision.
- **AC-31-11:** No experiment definition in `RemoteConfig` references an economy formula, price, reward, capsule odds, offline coefficient or `SIM_VERSION` key (validator rejects them).
- **AC-31-12:** Observed capsule rarity frequencies over ≥ 100,000 opens fall within 99 % confidence intervals of the disclosed §C4.7 odds.

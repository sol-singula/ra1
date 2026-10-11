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


--[[
The one wrapper over AnalyticsService (§10). Nothing else calls AnalyticsService: services log to Telemetry
(Telemetry.log(player, name, data)) and this turns the log into Analytics events.

Acquisition tag (first join only, meta.source == nil): player:GetJoinData().LaunchData is untrusted. At most
LAUNCH_MAX chars, JSONDecode in a pcall; { "src": "ad", "c": "<campaign>" } with c matching ^[%w_%-]+$ and at most
CAMPAIGN_MAX chars -> meta.source = "ad", meta.campaign = c. Anything else -> "organic", no campaign. Never
overwritten.

Every event carries customFields: CustomField01 = source, CustomField02 = campaign or "none", CustomField03 = "payer"
(receipts recorded or any pass owned) or "nonpayer".

Funnel (LogOnboardingFunnelStepEvent): steps 1-10 (STEPS), once each, only while the first session is running
(firstSession not done); the steps reached are kept in meta.funnel.

Economy (LogEconomyEvent, currency "Coins", the ending balance): InventoryService.Economy for coins. Sources and
sinks are SOURCES / SINKS. Transaction types: Gameplay for earns, Shop for seed and tool buys, Onboarding for
FTUE rewards (addCoins with { onboarding = true }).

Custom events (LogCustomEvent): only the names in EVENTS. Analytics has just 3 custom fields and all three carry
the ad split, so details go elsewhere: low-cardinality ones are suffixed onto the name (weather_start:rain), one
number goes in value, the rest is printed to the server log. Engine-side extras: session_end (value = session
seconds), d1_return (once, a join on utcDay(meta.created) + 1), first_purchase, net_drop (on leave, per reason).

  TelemetryService.parseLaunch(raw) -> source, campaign
  TelemetryService.fieldsFor(player) -> customFields
  TelemetryService.funnel(player, step)
  TelemetryService.custom(player, name, data)
  TelemetryService.STEPS / EVENTS / SOURCES / SINKS
]]
local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local Purchase = require(script.Parent.Parent.Purchase)
local Telemetry = require(script.Parent.Parent.Telemetry)

local TelemetryService = {}

TelemetryService.LAUNCH_MAX = 200
TelemetryService.CAMPAIGN_MAX = 32

TelemetryService.STEPS = {
	"join",
	"plant",
	"harvest",
	"sell",
	"shop_open",
	"plot_level_2",
	"welcome_shower",
	"first_item_kept",
	"first_pedestal",
	"ten_minutes",
}

-- [source] = transaction type for earns; [sink] = for spends
TelemetryService.SOURCES = {
	sell_normal = "Gameplay",
	sell_item = "Gameplay",
	collection = "Gameplay",
	daily = "Gameplay",
	quest = "Gameplay",
	playtime = "Gameplay",
	help = "Gameplay",
	blockparty = "Gameplay",
	weekly = "Gameplay",
}
TelemetryService.SINKS = { seed = "Shop", upgrade = "Gameplay", can = "Shop", sprinkler = "Shop" }

local function onOff(word, other)
	return function(v)
		return if v then word else other
	end
end

-- suffix: data fields appended to the name, in order; value: the data field sent as value
TelemetryService.EVENTS = {
	mutation_found = { suffix = { "mut" } },
	item_kept = { suffix = { "mut" } },
	item_sold = { suffix = { "mut" }, value = "coins" },
	item_displayed = { suffix = { "mut" } },
	item_gifted = { value = "qty" },
	gift_declined = { suffix = { "reason" } },
	collection_claim = {},
	milestone_claim = { value = "n" },
	backpack_full = {},
	basket_full = {},
	blockparty_water = { value = "waters" },
	blockparty_bloom = { suffix = { "early" }, format = { early = onOff("early", "full_window") }, value = "waters" },
	blockparty_reward = { value = "coins" },
	weather_start = { suffix = { "kind" } },
	daily_claim = { value = "day" },
	quest_complete = { suffix = { "id" }, value = "coins" },
	playtime_claim = { value = "index" },
	weekly_gift_claim = {},
	shop_open = { suffix = { "via" } },
	lounge_enter = {},
	purchase = { suffix = { "key" }, value = "robux" },
	patch_line_shown = { suffix = { "id" } },
	patch_line_dismissed = { suffix = { "id", "how" } },
	session_end = { value = "sec" },
	d1_return = {},
	first_purchase = { suffix = { "key" }, value = "robux" },
	net_drop = { suffix = { "reason" }, value = "count" },
}

local FIELD = { "CustomField01", "CustomField02", "CustomField03" }

local function call(method, ...)
	local args = table.pack(...)
	local ok, err = pcall(function()
		AnalyticsService[method](AnalyticsService, table.unpack(args, 1, args.n))
	end)
	if not ok then
		warn(`[Telemetry] {method} failed: {err}`)
	end
end

---------------------------------------------------------------------------------------------------------------
-- the acquisition tag and the custom fields

function TelemetryService.parseLaunch(raw)
	if type(raw) ~= "string" or #raw == 0 or #raw > TelemetryService.LAUNCH_MAX then
		return "organic", nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(data) ~= "table" or data.src ~= "ad" then
		return "organic", nil
	end
	local c = data.c
	if type(c) ~= "string" or #c > TelemetryService.CAMPAIGN_MAX or not c:match("^[%w_%-]+$") then
		return "organic", nil
	end
	return "ad", c
end

local function tag(player, profile)
	if profile.meta.source ~= nil then
		return
	end
	local ok, join = pcall(function()
		return player:GetJoinData()
	end)
	local raw = ok and type(join) == "table" and join.LaunchData or nil
	profile.meta.source, profile.meta.campaign = TelemetryService.parseLaunch(raw)
end

local function payer(player, profile)
	if #profile.receipts > 0 then
		return true
	end
	for key in Config.Catalog.passes do
		if Purchase.owns(player, key) then
			return true
		end
	end
	return false
end

function TelemetryService.fieldsFor(player)
	local profile = player and DataService.get(player)
	local source, campaign, paid = "organic", nil, false
	if profile then
		tag(player, profile)
		source, campaign, paid = profile.meta.source, profile.meta.campaign, payer(player, profile)
	end
	return {
		[Enum.AnalyticsCustomFieldKeys[FIELD[1]].Name] = source,
		[Enum.AnalyticsCustomFieldKeys[FIELD[2]].Name] = campaign or "none",
		[Enum.AnalyticsCustomFieldKeys[FIELD[3]].Name] = if paid then "payer" else "nonpayer",
	}
end

---------------------------------------------------------------------------------------------------------------
-- funnel, economy, custom events

function TelemetryService.funnel(player, step)
	local profile = DataService.get(player)
	if not profile or profile.firstSession.done or not TelemetryService.STEPS[step] then
		return
	end
	profile.meta.funnel = profile.meta.funnel or {}
	local key = tostring(step)
	if profile.meta.funnel[key] then
		return
	end
	profile.meta.funnel[key] = true
	call("LogOnboardingFunnelStepEvent", player, step, TelemetryService.STEPS[step], TelemetryService.fieldsFor(player))
end

local function economy(player, currency, delta, reason, opts)
	if currency ~= "coins" then
		return
	end
	local profile = DataService.get(player)
	if not profile then
		return
	end
	local flow, kind
	if delta > 0 then
		flow, kind = "Source", TelemetryService.SOURCES[reason]
		if opts and opts.onboarding then
			kind = "Onboarding"
		end
	else
		flow, kind = "Sink", TelemetryService.SINKS[reason]
	end
	if not kind then
		warn(`[Telemetry] coins {delta} with an unknown reason {reason}`)
		kind = "Gameplay"
	end
	call(
		"LogEconomyEvent",
		player,
		Enum.AnalyticsEconomyFlowType[flow],
		"Coins",
		math.abs(delta),
		profile.coins,
		Enum.AnalyticsEconomyTransactionType[kind].Name,
		reason,
		TelemetryService.fieldsFor(player)
	)
	if reason == "sell_normal" or reason == "sell_item" then
		TelemetryService.funnel(player, 4)
	end
end

function TelemetryService.custom(player, name, data)
	local spec = TelemetryService.EVENTS[name]
	if not spec then
		return false
	end
	data = data or {}
	local full = name
	local used = {}
	for _, field in spec.suffix or {} do
		local v = data[field]
		local fmt = spec.format and spec.format[field]
		if fmt then
			v = fmt(v)
		end
		if v ~= nil then
			full ..= ":" .. tostring(v)
		end
		used[field] = true
	end
	local value
	if spec.value then
		value = tonumber(data[spec.value])
		used[spec.value] = true
	end
	local rest = {}
	for k, v in data do
		if not used[k] then
			rest[k] = v
		end
	end
	if next(rest) ~= nil then
		local ok, json = pcall(HttpService.JSONEncode, HttpService, rest)
		print(`[Telemetry] {player and player.UserId} {full} {if ok then json else ""}`)
	end
	call("LogCustomEvent", player, full, value or 1, TelemetryService.fieldsFor(player))
	return true
end

-- the Telemetry log: custom events, plus the funnel steps they mark
local FUNNEL_FROM = { shop_open = 5, item_kept = 8, item_displayed = 9 }

local function logged(player, name, data)
	if not player then
		return
	end
	if name == "funnel" then
		TelemetryService.funnel(player, data and data.step)
		return
	end
	if name == "purchase" then
		local profile = DataService.get(player)
		if profile and not profile.meta.firstPurchase then
			profile.meta.firstPurchase = Clock.now()
			TelemetryService.custom(player, "first_purchase", data)
		end
	end
	if not TelemetryService.custom(player, name, data) then
		print(`[Telemetry] {player.UserId} {name} (server log only)`)
	end
	if FUNNEL_FROM[name] then
		TelemetryService.funnel(player, FUNNEL_FROM[name])
	end
end

---------------------------------------------------------------------------------------------------------------

function TelemetryService:Init()
	Telemetry.Logged:Connect(logged)
	InventoryService.Economy:Connect(economy)
end

function TelemetryService:Start()
	FarmService.Planted:Connect(function(player)
		TelemetryService.funnel(player, 2)
	end)
	FarmService.Harvested:Connect(function(player)
		TelemetryService.funnel(player, 3)
	end)
	FarmService.Upgraded:Connect(function(player, kind, level)
		if kind == "plot" and level >= 2 then
			TelemetryService.funnel(player, 6)
		end
	end)
end

function TelemetryService:OnPlayerLoaded(player, profile)
	tag(player, profile)
	TelemetryService.funnel(player, 1)
	local today = Clock.utcDay(Clock.now())
	if not profile.meta.d1Logged and today == Clock.utcDay(profile.meta.created) + 1 then
		profile.meta.d1Logged = true
		TelemetryService.custom(player, "d1_return", {})
	end
end

function TelemetryService:OnPlayerLeaving(player, profile)
	local sec = math.max(0, math.floor(Clock.now() - profile.meta.sessionStart))
	TelemetryService.custom(player, "session_end", { sec = sec })
	local drops = NetService.dropStats().byPlayer[player.UserId]
	for reason, count in drops or {} do
		TelemetryService.custom(player, "net_drop", { reason = reason, count = count })
	end
end

return TelemetryService

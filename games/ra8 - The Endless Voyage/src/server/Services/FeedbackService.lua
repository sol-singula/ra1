--[[
Asking players what they think, and staying in touch (same as the studio's other games):
  * Feedback card: after FEEDBACK_AFTER seconds of play, "Do you like the game? 👍 / 👎" with an optional "What
    should we add?" box. Asked at most FEEDBACK_MAX_ASKS times, at most once every FEEDBACK_ASK_EVERY, never again
    once answered, and never in the middle of a fight (it waits for the day, or the results). 👎 shows the reason
    buttons (Constants.DISLIKE_REASONS). The answer goes to analytics ("feedback") with how long they played, how
    many runs and nights, whether they've ever won, and their device.
  * Notifications: after NOTIFY_AFTER seconds the client offers Roblox's Experience Notifications opt-in, and
    reports what happened ("Notify": shown / on / off / status) as analytics events.
Free text goes through Roblox's text filter before it's stored, and is kept short.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local FeedbackService = {
	Name = "FeedbackService",
	Dependencies = {
		"PlayerDataService",
		"WeatherService",
		"AnalyticsService",
		"CreatureService",
		"RaftService",
		"VoyageService",
	},
	Answered = Signal.new("FeedbackService.Answered"), -- (player, like, text)
}

local data, weather, analytics, creatures, voyages, rafts
local readyAt = {} -- [player] = os.clock() when they loaded in
local startStats = {} -- [player] = { voyages, tier }

local function minutesPlayed(player)
	return readyAt[player] and math.floor((os.clock() - readyAt[player]) / 6) / 10 or 0
end

local function context(player)
	local s = analytics:Session(player)
	local profile = data:Get(player)
	local st = profile and profile.stats
	local start = startStats[player] or {}
	return {
		minutes = minutesPlayed(player),
		voyages = st and (st.voyages - (start.voyages or st.voyages)) or nil,
		voyages_total = st and st.voyages or nil,
		tier = profile and profile.records.tier or nil,
		tier_start = start.tier,
		tiles = profile and profile.records.tiles or nil,
		device = s and s.device or nil,
		new = profile and profile._isNew == true or nil,
		visit = profile and profile.meta and profile.meta.sessions or nil,
	}
end

local function filter(player, text)
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	return ok and type(result) == "string" and result or nil
end

local function cleanText(text)
	if type(text) ~= "string" then
		return nil
	end
	text = string.gsub(string.sub(text, 1, Constants.FEEDBACK_MAX_CHARS), "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text ~= "" and text or nil
end

-- A calm moment: docked or ashore, no Leviathan up.
local function calm(player)
	local plot = rafts:PlotOf(player)
	if plot and creatures:Boss(plot) then
		return false
	end
	local state = plot and voyages:State(plot) or "docked"
	return state == "docked" or state == "island"
end

function FeedbackService:Ask(player)
	local profile = data:Get(player)
	local fb = profile and profile.feedback
	if not fb or fb.at or (fb.asks or 0) >= Constants.FEEDBACK_MAX_ASKS then
		return false
	end
	if fb.askedAt and os.time() - fb.askedAt < Constants.FEEDBACK_ASK_EVERY then
		return false
	end
	fb.asks = (fb.asks or 0) + 1
	fb.askedAt = os.time()
	Net.fire(player, "Ask", { kind = "feedback" })
	analytics.track(
		player,
		"feedback_asked",
		{ ask = fb.asks, minutes = minutesPlayed(player), phase = weather:Phase() }
	)
	return true
end

local function cleanReasons(reasons)
	if type(reasons) ~= "table" then
		return nil
	end
	local known, out, seen = {}, {}, {}
	for _, r in Constants.DISLIKE_REASONS do
		known[r.key] = true
	end
	for _, r in reasons do
		if type(r) == "string" and known[r] and not seen[r] then
			seen[r] = true
			table.insert(out, r)
		end
	end
	return #out > 0 and out or nil
end

function FeedbackService:Answer(player, like, text, reasons)
	local profile = data:Get(player)
	local fb = profile and profile.feedback
	if not fb or fb.at or type(like) ~= "boolean" then
		return false
	end
	text = cleanText(text)
	local filtered = text and filter(player, text)
	fb.at, fb.like = os.time(), like
	local row = context(player)
	row.like = like
	row.text = filtered
	row.reasons = not like and cleanReasons(reasons) or nil
	row.text_dropped = text ~= nil and filtered == nil or nil
	analytics.track(player, "feedback", row)
	self.Answered:Fire(player, like, filtered)
	Net.fire(player, "Ask", { kind = "thanks", like = like })
	return true
end

function FeedbackService:OfferNotify(player)
	local profile = data:Get(player)
	if not profile or profile.notify.on then
		return false
	end
	local last = profile.notify.askedAt
	if last and os.time() - last < Constants.NOTIFY_ASK_EVERY then
		return false
	end
	profile.notify.askedAt = os.time()
	Net.fire(player, "Ask", { kind = "notify" })
	return true
end

function FeedbackService:_notify(player, what, value)
	local profile = data:Get(player)
	if not profile or type(what) ~= "string" then
		return
	end
	local n = profile.notify
	if what == "shown" then
		n.shown = (n.shown or 0) + 1
		n.askedAt = os.time()
		analytics.track(player, "notify_shown", { minutes = minutesPlayed(player) })
	elseif what == "on" or what == "off" then
		n.on = what == "on"
		analytics.track(player, "notify_opt_in", { on = n.on, minutes = minutesPlayed(player) })
	elseif what == "status" and type(value) == "boolean" then
		local wasOn = n.on == true
		if wasOn and value then
			n.on = false
		end
		analytics.track(player, "notify_status", { can_ask = value, on = n.on == true, left_list = wasOn and value })
	end
end

function FeedbackService:Init(registry)
	data = registry.PlayerDataService
	weather = registry.WeatherService
	analytics = registry.AnalyticsService
	creatures = registry.CreatureService
	voyages = registry.VoyageService
	rafts = registry.RaftService
	Net.on("Feedback", function(player, like, text, reasons)
		self:Answer(player, like, text, reasons)
	end)
	Net.on("Notify", function(player, what, value)
		self:_notify(player, what, value)
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
		startStats[player] = nil
	end)
end

function FeedbackService:OnPlayerReady(player, profile)
	profile.feedback = profile.feedback or { asks = 0 }
	profile.notify = profile.notify or {}
	local t0 = os.clock()
	readyAt[player] = t0
	startStats[player] = { voyages = profile.stats.voyages, tier = profile.records.tier }
	-- after `seconds`, at the next calm moment (checked every 5 s, for up to 10 minutes)
	local function at(seconds, fn)
		task.delay(seconds, function()
			for _ = 1, 120 do
				if readyAt[player] ~= t0 or not player.Parent then
					return
				end
				if calm(player) then
					fn()
					return
				end
				task.wait(5)
			end
		end)
	end
	at(Constants.FEEDBACK_AFTER, function()
		self:Ask(player)
	end)
	at(Constants.NOTIFY_AFTER, function()
		self:OfferNotify(player)
	end)
end

function FeedbackService:OnPlayerLeaving(player)
	readyAt[player] = nil
	startStats[player] = nil
end

return FeedbackService

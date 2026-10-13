-- Asking players what they think, and staying in touch:
--   * Feedback card: after FEEDBACK_AFTER seconds of play (tutorial done), "Do you like the game? 👍 / 👎" with an
--     optional "What should we add?" box. Asked at most FEEDBACK_MAX_ASKS times, never again once answered.
--     The answer goes to analytics ("feedback") with how long they played, how often they got bonked or robbed,
--     and their device, so it ties to the session.
--   * Vote reminder: players who said 👍 (or played VOTE_NUDGE_AFTER seconds) are reminded to tap 👍 on the game
--     page. Roblox doesn't let a game open the vote itself; at most once every VOTE_NUDGE_EVERY seconds.
--   * Notifications: after NOTIFY_AFTER seconds (or right after the feedback card), the client offers Roblox's
--     Experience Notifications opt-in. The client reports what happened ("Notify": shown / on / off / status) and
--     each result is an analytics event, so the dashboard can count how many players are on the list.
-- Free text is run through Roblox's text filter before it is stored, and kept short.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local FeedbackService = {
	Name = "FeedbackService",
	Dependencies = { "PlayerDataService", "AnalyticsService" },
	Answered = Signal.new("FeedbackService.Answered"), -- (player, like, text)
}

local data, analytics
local readyAt = {} -- [player] = os.clock() when they loaded in

local function minutesPlayed(player)
	return readyAt[player] and math.floor((os.clock() - readyAt[player]) / 6) / 10 or 0
end

-- What we know about this session so far (for the feedback row).
local function context(player)
	local s = analytics:Session(player)
	local counts = s and s.counts or {}
	local profile = data:Get(player)
	return {
		minutes = minutesPlayed(player),
		bonked = counts.got_bonked or 0,
		robbed = counts.got_robbed or 0,
		device = s and s.device or nil,
		new = profile and profile._isNew == true or nil,
		visit = profile and profile.meta and profile.meta.sessions or nil,
	}
end

-- Roblox's text filter (as if it were shown to everyone). Returns nil when the filter can't run.
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

function FeedbackService:Ask(player)
	local profile = data:Get(player)
	local fb = profile and profile.feedback
	if not fb or fb.at or (fb.asks or 0) >= Constants.FEEDBACK_MAX_ASKS or not profile.tutorialDone then
		return false
	end
	fb.asks = (fb.asks or 0) + 1
	Net.fire(player, "Ask", { kind = "feedback" })
	analytics.track(player, "feedback_asked", { ask = fb.asks, minutes = minutesPlayed(player) })
	return true
end

function FeedbackService:Answer(player, like, text)
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
	row.text_dropped = text ~= nil and filtered == nil or nil
	analytics.track(player, "feedback", row)
	self.Answered:Fire(player, like, filtered)
	-- the thank-you card: 👍 gets the vote reminder; both get the notifications offer
	if like then
		profile.notify.votedNudgeAt = os.time()
	end
	Net.fire(player, "Ask", { kind = "thanks", like = like })
	return true
end

-- "Like the game? Tap 👍 on the game page!" for players who liked it or have played a long time.
function FeedbackService:NudgeVote(player)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	if profile.feedback.like == false then
		return false
	end
	local last = profile.notify.votedNudgeAt
	if last and os.time() - last < Constants.VOTE_NUDGE_EVERY then
		return false
	end
	profile.notify.votedNudgeAt = os.time()
	Net.fire(player, "Ask", { kind = "vote" })
	analytics.track(player, "vote_nudge", { minutes = minutesPlayed(player), liked = profile.feedback.like })
	return true
end

-- Offer notifications (the client checks Roblox can ask them before showing anything).
function FeedbackService:OfferNotify(player)
	local profile = data:Get(player)
	if not profile or profile.notify.on or not profile.tutorialDone then
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
		local on = what == "on"
		n.on = on
		analytics.track(player, "notify_opt_in", { on = on, minutes = minutesPlayed(player) })
	elseif what == "status" and type(value) == "boolean" then
		-- once a session: can Roblox still ask them? If they were on the list and it can ask again, they left it.
		local wasOn = n.on == true
		if wasOn and value then
			n.on = false
		end
		analytics.track(player, "notify_status", { can_ask = value, on = n.on == true, left_list = wasOn and value })
	end
end

function FeedbackService:Init(registry)
	data = registry.PlayerDataService
	analytics = registry.AnalyticsService
	Net.on("Feedback", function(player, like, text)
		self:Answer(player, like, text)
	end)
	Net.on("Notify", function(player, what, value)
		self:_notify(player, what, value)
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

function FeedbackService:OnPlayerReady(player, profile)
	profile.feedback = profile.feedback or { asks = 0 }
	profile.notify = profile.notify or {}
	local t0 = os.clock()
	readyAt[player] = t0
	local function at(seconds, fn)
		task.delay(seconds, function()
			if readyAt[player] == t0 and player.Parent then
				fn()
			end
		end)
	end
	at(Constants.FEEDBACK_AFTER, function()
		self:Ask(player)
	end)
	at(Constants.NOTIFY_AFTER, function()
		self:OfferNotify(player)
	end)
	at(Constants.VOTE_NUDGE_AFTER, function()
		self:NudgeVote(player)
	end)
end

function FeedbackService:OnPlayerLeaving(player)
	readyAt[player] = nil
end

return FeedbackService

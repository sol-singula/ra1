--[[
Asking the players (only ever right after a match, while the fireworks are going, never mid-fight; winners and
losers alike, the like card only for winners):

  * "Are you liking the game?" YES / NO: at most once a day (UTC) per player. A NO must say why: one or more of
    Constants.FEEDBACK_REASONS (the card won't send without one).
  * Said YES? Then on their NEXT win they're asked for a like: "Give the game a 👍 Like". Roblox doesn't let a game
    press the like button for you, so the card asks, and its button offers Roblox's own favourite prompt (the one
    thing a game can open). Asked for a like once; never again after that.

Answering the daily question (YES or NO: it's the answer that's thanked, not liking it) gives the Thank-You Trail
once (Data/Extras), worn straight away, with a THANK YOU card (Net "Unlock" with extra = true).

Kept in the profile (profile.feedback): the day they were last asked, their answer, whether a like ask is owed,
and how the like card went. FEEDBACK_ASK_DELAY seconds after the win, so it lands after the fireworks start and
doesn't cover the results. Never at the end of someone's first live match: that one ends in the shop
(GiftService:FirstShopDue), so the question waits for their next match.

  Net "Ask" { kind = "enjoy" | "like" }          server -> client
  Net "Feedback" ("enjoy", true) | ("enjoy", false, { reason keys }) | ("like", "ok" | "later")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local FeedbackService = {
	Name = "FeedbackService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = { "PlayerDataService", "TeamService", "MatchService", "ProgressService", "GiftService" },
	Asked = Signal.new("FeedbackService.Asked"), -- (player, kind)
	Answered = Signal.new("FeedbackService.Answered"), -- (player, kind, answer)
	Thanked = Signal.new("FeedbackService.Thanked"), -- (player, extra)
}

local data, teams, match, progress, gifts
local THANKS = "extra_thanks"
local outstanding = {} -- [player] = the card they were shown and haven't answered

local function today()
	return os.time() // 86400
end

local function feedbackOf(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	p.feedback = p.feedback or {}
	local f = p.feedback
	f.askedDay = f.askedDay or 0
	f.likeAskedDay = f.likeAskedDay or 0
	return f
end

-- What to ask this winner now, if anything: the like card when it's owed, else the daily question.
function FeedbackService:Pick(player)
	local f = feedbackOf(player)
	if not f then
		return nil
	end
	if f.pendingLike then
		return "like"
	end
	if f.askedDay ~= today() then
		return "enjoy"
	end
	return nil
end

function FeedbackService:Ask(player, kind)
	local f = feedbackOf(player)
	if not f or not kind then
		return false
	end
	if kind == "like" then
		f.pendingLike = false
		f.likeAskedDay = today()
	else
		f.askedDay = today()
	end
	outstanding[player] = kind
	Net.fire(player, "Ask", { kind = kind })
	self.Asked:Fire(player, kind)
	return true
end

-- After a match: everyone who played it, a moment later (the losers too: they're the ones who'd say why not).
-- The like card only ever goes to a winner.
function FeedbackService:AfterWin(winner)
	local list = {}
	for _, p in Players:GetPlayers() do
		-- (their first match ends in the shop instead: the question waits for the next one)
		if teams:Team(p) ~= nil and not (gifts and gifts:FirstShopDue(p)) then
			table.insert(list, p)
		end
	end
	task.delay(Constants.FEEDBACK_ASK_DELAY, function()
		for _, p in list do
			if p.Parent and match:Phase() == "victory" then
				local kind = self:Pick(p)
				if kind == "like" and teams:Team(p) ~= winner then
					kind = nil -- (a like ask after a loss would land badly: their next win)
				end
				self:Ask(p, kind)
			end
		end
	end)
end

-- The thank-you for answering: the trail, once, worn at once.
function FeedbackService:Thank(player)
	if not progress:GrantExtra(player, THANKS, { title = "THANK YOU!" }) then
		return false
	end
	self.Thanked:Fire(player, THANKS)
	return true
end

function FeedbackService:Answer(player, kind, answer, reasons)
	if outstanding[player] ~= kind then
		return false -- (only the card they were shown)
	end
	outstanding[player] = nil
	local f = feedbackOf(player)
	if not f then
		return false
	end
	if kind == "enjoy" and type(answer) == "boolean" then
		-- (a NO must say why: one or more of Constants.FEEDBACK_REASONS; without one the card stays up)
		local why
		if answer == false then
			why = {}
			local valid = {}
			for _, r in Constants.FEEDBACK_REASONS do
				valid[r.key] = true
			end
			for _, k in type(reasons) == "table" and reasons or {} do
				if type(k) == "string" and valid[k] and not table.find(why, k) then
					table.insert(why, k)
				end
			end
			if #why == 0 then
				outstanding[player] = kind
				return false
			end
			f.reasons = why
		end
		f.answer = answer
		f.yes = (f.yes or 0) + (answer and 1 or 0)
		f.no = (f.no or 0) + (answer and 0 or 1)
		-- liking it and never asked for a like: ask on the next win
		f.pendingLike = answer == true and f.likeAskedDay == 0
		self.Answered:Fire(player, kind, answer, why)
		self:Thank(player)
		return true
	elseif kind == "like" and (answer == "ok" or answer == "later") then
		f.likeAnswer = answer
	else
		return false
	end
	self.Answered:Fire(player, kind, answer)
	return true
end

function FeedbackService:Init(registry)
	data = registry.PlayerDataService
	teams = registry.TeamService
	match = registry.MatchService
	progress = registry.ProgressService
	gifts = registry.GiftService
	Net.on("Feedback", function(player, kind, answer, reasons)
		self:Answer(player, kind, answer, reasons)
	end)
	match.Ended:Connect(function(winner)
		self:AfterWin(winner)
	end)
	Players.PlayerRemoving:Connect(function(player)
		outstanding[player] = nil
	end)
end

return FeedbackService

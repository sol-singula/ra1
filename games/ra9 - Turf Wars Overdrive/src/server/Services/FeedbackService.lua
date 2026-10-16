--[[
Asking the winners (only ever right after a win, while the fireworks are going, never mid-fight):

  * "Are you liking the game?" YES / NO: at most once a day (UTC) per player.
  * Said YES? Then on their NEXT win they're asked for a like: "Give the game a 👍 Like". Roblox doesn't let a game
    press the like button for you, so the card asks, and its button offers Roblox's own favourite prompt (the one
    thing a game can open). Asked for a like once; never again after that.

Kept in the profile (profile.feedback): the day they were last asked, their answer, whether a like ask is owed,
and how the like card went. FEEDBACK_ASK_DELAY seconds after the win, so it lands after the fireworks start and
doesn't cover the results.

  Net "Ask" { kind = "enjoy" | "like" }          server -> client
  Net "Feedback" ("enjoy", yes) | ("like", "ok" | "later")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local FeedbackService = {
	Name = "FeedbackService",
	Dependencies = { "PlayerDataService", "TeamService", "MatchService" },
	Asked = Signal.new("FeedbackService.Asked"), -- (player, kind)
	Answered = Signal.new("FeedbackService.Answered"), -- (player, kind, answer)
}

local data, teams, match
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

-- After a win: each winner still here, a moment later.
function FeedbackService:AfterWin(winner)
	local list = {}
	for _, p in Players:GetPlayers() do
		if teams:Team(p) == winner then
			table.insert(list, p)
		end
	end
	task.delay(Constants.FEEDBACK_ASK_DELAY, function()
		for _, p in list do
			if p.Parent and match:Phase() == "victory" then
				self:Ask(p, self:Pick(p))
			end
		end
	end)
end

function FeedbackService:Answer(player, kind, answer)
	if outstanding[player] ~= kind then
		return false -- (only the card they were shown)
	end
	outstanding[player] = nil
	local f = feedbackOf(player)
	if not f then
		return false
	end
	if kind == "enjoy" and type(answer) == "boolean" then
		f.answer = answer
		f.yes = (f.yes or 0) + (answer and 1 or 0)
		f.no = (f.no or 0) + (answer and 0 or 1)
		-- liking it and never asked for a like: ask on the next win
		f.pendingLike = answer == true and f.likeAskedDay == 0
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
	Net.on("Feedback", function(player, kind, answer)
		self:Answer(player, kind, answer)
	end)
	match.Ended:Connect(function(winner)
		self:AfterWin(winner)
	end)
	Players.PlayerRemoving:Connect(function(player)
		outstanding[player] = nil
	end)
end

return FeedbackService

--[[
The daily favourite raft. Once a day, after VOTE_AFTER seconds of play, a card shows VOTE_CHOICES of the biggest
rafts on the leaderboard (others' rafts in this server when the board is short), LOOK opens one (VisitService),
VOTE picks it. Each voter gets the next few on the list, so every raft near the top gets looked at, not just #1.
LATER asks again after another VOTE_AFTER.

Votes add up per UTC day in an OrderedDataStore (VOTE_STORE .. day, one entry per raft owner's user id; in memory
without DataStores). Yesterday's winner is read when the server starts and every hour: everyone hears it when they
join, and the winner, the first time they join after, gets VOTE_PRIZE_XP and the "Favourite Raft" title.

  "Ask" { kind = "vote", choices = { { userId, name, value } } }    server -> client
  "Vote" userId | "later"                                          client -> server
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local VoteService = {
	Name = "VoteService",
	Dependencies = { "PlayerDataService", "LeaderboardService", "RaftService", "ProgressService" },
	Asked = Signal.new("VoteService.Asked"), -- (player, choices)
	Voted = Signal.new("VoteService.Voted"), -- (player, userId)
}

local data, rafts, leaderboard, progress
local offered = {} -- [player] = { [userId] = true } the choices on their card
local askAt = {} -- [player] = os.clock() when to ask (nil: not today)
local rotation = 0 -- where the next voter's choices start on the list
local memory = {} -- [day] = { [userId] = votes } (without DataStores)
local winner -- { day, userId, name, votes } yesterday's favourite

local function today()
	return os.time() // 86400
end

local function storeFor(day)
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Constants.VOTE_STORE .. day)
	return ok and store or nil
end

-- The rafts up for a vote, best first: the top of the biggest-raft board, then the other rafts in this server.
function VoteService:Candidates(player)
	local list, seen = {}, { [player.UserId] = true }
	local view = leaderboard:View(player, "tiles")
	for _, r in view and view.global or {} do
		if r.userId and r.userId > 0 and not seen[r.userId] then
			seen[r.userId] = true
			table.insert(list, { userId = r.userId, name = r.name, value = r.value })
		end
	end
	for _, raft in rafts:All() do
		local owner = raft.owner
		if owner and owner.Parent and not seen[owner.UserId] then
			seen[owner.UserId] = true
			table.insert(
				list,
				{ userId = owner.UserId, name = owner.DisplayName, value = raft.summary.placed or raft.summary.tiles }
			)
		end
	end
	return list
end

-- The next few from the list for this voter (the list goes round, so they all get seen).
function VoteService:Choices(player)
	local list = self:Candidates(player)
	if #list < 2 then
		return nil
	end
	local n = math.min(Constants.VOTE_CHOICES, #list)
	local out = {}
	for k = 0, n - 1 do
		table.insert(out, list[(rotation + k) % #list + 1])
	end
	rotation = (rotation + n) % #list
	return out
end

function VoteService:Ask(player)
	local profile = data:Get(player)
	if not profile or profile.voteDay == today() then
		askAt[player] = nil
		return false
	end
	local choices = self:Choices(player)
	if not choices then
		askAt[player] = os.clock() + 120 -- (nobody to vote for yet: look again soon)
		return false
	end
	askAt[player] = nil
	offered[player] = {}
	for _, c in choices do
		offered[player][c.userId] = true
	end
	Net.fire(player, "Ask", { kind = "vote", choices = choices })
	self.Asked:Fire(player, choices)
	return true
end

function VoteService:Cast(player, userId)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	if userId == "later" then
		offered[player] = nil
		askAt[player] = os.clock() + Constants.VOTE_AFTER
		return true
	end
	userId = tonumber(userId)
	if not userId or not offered[player] or not offered[player][userId] or profile.voteDay == today() then
		return false
	end
	offered[player] = nil
	profile.voteDay = today()
	local day = today()
	local store = storeFor(day)
	local ok = store and pcall(store.IncrementAsync, store, tostring(userId), 1)
	if not ok then
		memory[day] = memory[day] or {}
		memory[day][userId] = (memory[day][userId] or 0) + 1
	end
	Net.fire(player, "Toast", "⭐ Vote counted! Tomorrow you'll see which raft won.", "good")
	self.Voted:Fire(player, userId)
	return true
end

-- Yesterday's favourite: the most votes (nil when nobody voted).
function VoteService:_readWinner()
	local day = today() - 1
	local best
	local store = storeFor(day)
	if store then
		local ok, pages = pcall(store.GetSortedAsync, store, false, 1)
		local okPage, page = false, nil
		if ok and pages then
			okPage, page = pcall(pages.GetCurrentPage, pages)
		end
		if okPage and type(page) == "table" and page[1] then
			best = { userId = tonumber(page[1].key), votes = page[1].value }
		end
	end
	for userId, votes in memory[day] or {} do
		if not best or votes > best.votes then
			best = { userId = userId, votes = votes }
		end
	end
	if not best or not best.userId then
		winner = nil
		return nil
	end
	local okName, name = pcall(Players.GetNameFromUserIdAsync, Players, best.userId)
	winner = { day = day, userId = best.userId, votes = best.votes, name = okName and name or "a captain" }
	return winner
end

function VoteService:Winner()
	return winner
end

function VoteService:_greet(player)
	if not winner then
		return
	end
	local profile = data:Get(player)
	if player.UserId == winner.userId and profile and profile.favouriteDay ~= winner.day then
		profile.favouriteDay = winner.day
		profile.titles = profile.titles or { owned = {} }
		profile.titles.owned.favourite = true
		progress:AddXp(player, Constants.VOTE_PRIZE_XP, "favourite")
		Net.fire(
			player,
			"Alert",
			`⭐ YOUR RAFT WAS VOTED FAVOURITE! (+{Constants.VOTE_PRIZE_XP} XP)`,
			Color3.fromRGB(255, 220, 120),
			5
		)
	else
		Net.fire(
			player,
			"Toast",
			`⭐ Yesterday's favourite raft: {winner.name}'s ({winner.votes} vote{winner.votes == 1 and "" or "s"})`,
			"info"
		)
	end
end

function VoteService:Init(registry)
	data = registry.PlayerDataService
	rafts = registry.RaftService
	leaderboard = registry.LeaderboardService
	progress = registry.ProgressService
	Net.on("Vote", function(player, userId)
		self:Cast(player, userId)
	end)
end

function VoteService:OnPlayerReady(player, profile)
	if profile.voteDay ~= today() then
		askAt[player] = os.clock() + Constants.VOTE_AFTER
	end
	task.delay(4, function()
		if player.Parent then
			self:_greet(player)
		end
	end)
end

function VoteService:OnPlayerLeaving(player)
	offered[player] = nil
	askAt[player] = nil
end

function VoteService:Start()
	task.spawn(function()
		self:_readWinner()
	end)
	local lastRead = os.clock()
	while true do
		task.wait(5)
		if os.clock() - lastRead > 3600 then
			lastRead = os.clock()
			self:_readWinner()
		end
		for player, at in askAt do
			if player.Parent and os.clock() >= at then
				self:Ask(player)
			end
		end
	end
end

-- (tests)
function VoteService:_setAskAt(player, t)
	askAt[player] = t
end
function VoteService:_memory()
	return memory
end
function VoteService:_setWinner(w)
	winner = w
end

return VoteService

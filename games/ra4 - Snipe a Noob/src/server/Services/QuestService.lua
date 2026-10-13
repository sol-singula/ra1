-- Reasons to come back every day: three daily quests (the same for everyone, seeded by the day) that pay coins or
-- crate keys, one swap a day for coins, and the daily gift streak (day 3 and day 6 are keys, day 7 is big).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Signal = require(ReplicatedStorage.Shared.Signal)

local QuestService = {
	Name = "QuestService",
	Dependencies = { "PlayerDataService", "EconomyService", "TeamService" },
	QuestDone = Signal.new("QuestService.QuestDone"), -- (player, quest)
	GiftClaimed = Signal.new("QuestService.GiftClaimed"), -- (player, day, text)
}

local data, economy, team

-- Today's three quests, the same in every server (one of each kind at most). Returns pool indices.
function QuestService.todays(day)
	local r = Random.new(day)
	local pool = {}
	for i = 1, #Quests do
		pool[i] = i
	end
	local picked, kinds = {}, {}
	while #picked < Constants.DAILY_QUESTS and #pool > 0 do
		local i = table.remove(pool, r:NextInteger(1, #pool))
		if not kinds[Quests[i].kind] then
			kinds[Quests[i].kind] = true
			table.insert(picked, i)
		end
	end
	return picked
end

local function today(profile)
	local day = Formulas.day(os.time())
	local q = profile.quests
	if not q or q.day ~= day then
		q = {
			day = day,
			start = table.clone(profile.stats),
			list = QuestService.todays(day),
			done = {},
			swapped = false,
		}
		profile.quests = q
	end
	return q
end

function QuestService:Progress(player, quest)
	local profile = data:Get(player)
	local q = today(profile)
	return math.min(quest.target, (profile.stats[quest.kind] or 0) - (q.start[quest.kind] or 0))
end

local function rewardText(quest)
	if quest.keys then
		return `{quest.keys} 🔑`
	end
	return `{quest.coins} 💰`
end

function QuestService:View(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local q = today(profile)
	local list = {}
	for i, idx in q.list do
		local quest = Quests[idx]
		list[i] = {
			text = quest.text,
			progress = self:Progress(player, quest),
			target = quest.target,
			reward = rewardText(quest),
			done = q.done[i] == true,
		}
	end
	return { list = list, canSwap = not q.swapped, swapCoins = Constants.QUEST_REROLL_COINS }
end

function QuestService:Check(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local q = today(profile)
	local changed = false
	for i, idx in q.list do
		local quest = Quests[idx]
		if not q.done[i] and self:Progress(player, quest) >= quest.target then
			q.done[i] = true
			if quest.keys then
				economy:AddKeys(player, quest.keys)
			else
				economy:AddCoins(player, quest.coins, false)
			end
			Net.fire(
				player,
				"Alert",
				`📜 QUEST DONE: {quest.text}! +{rewardText(quest)}`,
				Color3.fromRGB(120, 220, 255)
			)
			Net.fire(player, "Sfx", "levelup")
			self.QuestDone:Fire(player, quest)
			changed = true
		end
	end
	if changed then
		self:Push(player)
	end
end

-- Swap one unfinished quest for a different one, once a day, for coins.
function QuestService:Swap(player, i)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	local q = today(profile)
	if q.swapped or not q.list[i] or q.done[i] then
		return false
	end
	if not economy:SpendCoins(player, Constants.QUEST_REROLL_COINS) then
		Net.fire(player, "Toast", `You need {Constants.QUEST_REROLL_COINS} coins.`, "bad")
		return false
	end
	local used = {}
	for _, idx in q.list do
		used[Quests[idx].kind] = true
	end
	local options = {}
	for idx, quest in Quests do
		if not used[quest.kind] then
			table.insert(options, idx)
		end
	end
	if #options == 0 then
		return false
	end
	q.list[i] = options[math.random(1, #options)]
	q.swapped = true
	-- progress counts from now for the new quest
	local kind = Quests[q.list[i]].kind
	q.start[kind] = profile.stats[kind] or 0
	self:Push(player)
	return true
end

-- Daily gift -----------------------------------------------------------------------------------------------------
local function giftText(g)
	local parts = {}
	if g.coins then
		table.insert(parts, `{g.coins} coins`)
	end
	if g.keys then
		table.insert(parts, `{g.keys} key{g.keys > 1 and "s" or ""}`)
	end
	return table.concat(parts, " + ")
end

function QuestService:DailyView(player)
	local profile = data:Get(player)
	local d = profile.daily
	local todayN = Formulas.day(os.time())
	local canClaim = d.lastDay ~= todayN
	local nextStreak = (d.lastDay == todayN - 1 or not canClaim) and d.streak + 1 or 1
	local week = {}
	local first = math.floor((nextStreak - 1) / #Constants.DAILY_GIFTS) * #Constants.DAILY_GIFTS
	for i = 1, #Constants.DAILY_GIFTS do
		week[i] = giftText(Constants.DAILY_GIFTS[(first + i - 1) % #Constants.DAILY_GIFTS + 1])
	end
	return {
		streak = d.streak,
		canClaim = canClaim,
		nextDay = nextStreak,
		gifts = week,
		secondsToNext = (todayN + 1) * 86400 - os.time(),
	}
end

function QuestService:ClaimDaily(player)
	local profile = data:Get(player)
	if not profile then
		return false
	end
	local todayN = Formulas.day(os.time())
	local d = profile.daily
	if d.lastDay == todayN then
		Net.fire(player, "Toast", "Come back tomorrow for the next gift!", "info")
		return false
	end
	local streak = (d.lastDay == todayN - 1) and d.streak + 1 or 1
	local g = Constants.DAILY_GIFTS[(streak - 1) % #Constants.DAILY_GIFTS + 1]
	d.streak = streak
	d.lastDay = todayN
	if g.coins then
		economy:AddCoins(player, g.coins, false)
	end
	if g.keys then
		economy:AddKeys(player, g.keys)
	end
	local text = giftText(g)
	Net.fire(player, "Alert", `🎁 Day {streak} gift: {text}!`, Color3.fromRGB(255, 205, 50))
	Net.fire(player, "Sfx", "gift")
	self.GiftClaimed:Fire(player, streak, text)
	self:Push(player)
	return true
end

function QuestService:Push(player)
	if data:Get(player) then
		data:Push(player, { quests = self:View(player), daily = self:DailyView(player) })
	end
end

function QuestService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	team = registry.TeamService
	Net.on("ClaimDaily", function(player)
		self:ClaimDaily(player)
	end)
	Net.on("RerollQuest", function(player, i)
		if type(i) == "number" then
			self:Swap(player, math.floor(i))
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	-- playing with a friend counts for the "Play with a friend" quest
	team.TeamChanged:Connect(function(player)
		local profile = data:Get(player)
		if profile and team:FriendsHere(player) > 0 then
			local q = today(profile)
			if (profile.stats.friendPlay or 0) - (q.start.friendPlay or 0) < 1 then
				profile.stats.friendPlay += 1
			end
		end
	end)
end

function QuestService:OnPlayerReady(_player, profile)
	today(profile)
end

function QuestService:Start()
	while true do
		task.wait(2)
		for _, player in Players:GetPlayers() do
			if data:Get(player) then
				self:Check(player)
			end
		end
	end
end

return QuestService

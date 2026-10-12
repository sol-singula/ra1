-- Reasons to come back every day: three daily quests that pay gems (the main free gem source), and the daily
-- gift streak (coins, ore, gems and blasters, day 7 is a Mega blaster). Also the gem sinks: rerolling a stat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Signal = require(ReplicatedStorage.Shared.Signal)

local QuestService = {
	Name = "QuestService",
	Dependencies = { "PlayerDataService", "EconomyService", "BlasterService", "PlanetService" },
	QuestDone = Signal.new("QuestService.QuestDone"), -- (player, quest)
	GiftClaimed = Signal.new("QuestService.GiftClaimed"), -- (player, day, text)
}

local data, economy, blasters, planetService
local rng = Random.new()

-- Today's three quests, the same in every server (seeded by the day).
function QuestService.todays(day)
	local r = Random.new(day)
	local pool = table.clone(Quests)
	local picked = {}
	-- one of each kind at most
	local kinds = {}
	while #picked < Constants.DAILY_QUESTS and #pool > 0 do
		local i = r:NextInteger(1, #pool)
		local q = table.remove(pool, i)
		if not kinds[q.kind] then
			kinds[q.kind] = true
			table.insert(picked, q)
		end
	end
	return picked
end

-- The day's record: stats at the start of the day, and which quests were paid.
local function today(profile)
	local day = Formulas.day(os.time())
	local q = profile.quests
	if not q or q.day ~= day then
		q = { day = day, start = table.clone(profile.stats), done = {} }
		profile.quests = q
	end
	return q
end

function QuestService:Progress(player, quest)
	local profile = data:Get(player)
	local q = today(profile)
	return math.min(quest.target, (profile.stats[quest.kind] or 0) - (q.start[quest.kind] or 0))
end

function QuestService:View(player)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local q = today(profile)
	local list = {}
	for i, quest in self.todays(q.day) do
		list[i] = {
			text = quest.text,
			progress = self:Progress(player, quest),
			target = quest.target,
			gems = quest.gems,
			done = q.done[i] == true,
		}
	end
	return list
end

function QuestService:Check(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local q = today(profile)
	local changed = false
	for i, quest in self.todays(q.day) do
		if not q.done[i] and self:Progress(player, quest) >= quest.target then
			q.done[i] = true
			economy:AddGems(player, quest.gems, true)
			Net.fire(
				player,
				"Alert",
				`📜 QUEST DONE: {quest.text}! +{quest.gems} 💎`,
				Color3.fromRGB(120, 220, 255)
			)
			Net.fire(player, "Sfx", "goal")
			self.QuestDone:Fire(player, quest)
			changed = true
		end
	end
	if changed then
		self:Push(player)
	end
end

-- Daily gift -----------------------------------------------------------------------------------------------------
function QuestService:GiftText(player, day)
	local g = Constants.DAILY_GIFTS[(day - 1) % #Constants.DAILY_GIFTS + 1]
	local top = Planets.list[planetService:Unlocked(player)]
	if g.kind == "coins" then
		return `{Format.num(g.bugs * top.bugCoins)} coins`
	elseif g.kind == "ore" then
		return `{g.amount} {top.ore}`
	elseif g.kind == "gems" then
		return `{g.amount} gems`
	end
	return `a {Formulas.forgeTier(g.tier).name} blaster`
end

function QuestService:DailyView(player)
	local profile = data:Get(player)
	local d = profile.daily
	local todayN = Formulas.day(os.time())
	local canClaim = d.lastDay ~= todayN
	local nextStreak = (d.lastDay == todayN - 1) and d.streak + 1 or 1
	if not canClaim then
		nextStreak = d.streak + 1
	end
	local week = {}
	local first = math.floor((nextStreak - 1) / #Constants.DAILY_GIFTS) * #Constants.DAILY_GIFTS
	for i = 1, #Constants.DAILY_GIFTS do
		week[i] = self:GiftText(player, first + i)
	end
	return {
		streak = d.streak,
		canClaim = canClaim,
		nextDay = nextStreak,
		gift = self:GiftText(player, nextStreak),
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
	local text = self:GiftText(player, streak)
	d.streak = streak
	d.lastDay = todayN
	local top = Planets.list[planetService:Unlocked(player)]
	if g.kind == "coins" then
		economy:AddCoins(player, g.bugs * top.bugCoins, false)
	elseif g.kind == "ore" then
		economy:AddOre(player, top.key, g.amount)
	elseif g.kind == "gems" then
		economy:AddGems(player, g.amount, true)
	else
		local rec = blasters:Grant(player, Formulas.rollBlaster(rng, g.tier, top.key, 1), "gift")
		text = Formulas.blasterName(rec) .. " " .. Formulas.rollStars(rec)
	end
	Net.fire(player, "Alert", `🎁 Day {streak} gift: {text}!`, Color3.fromRGB(255, 205, 50))
	Net.fire(player, "Sfx", "gift")
	self.GiftClaimed:Fire(player, streak, text)
	self:Push(player)
	return true
end

-- Gem sinks ------------------------------------------------------------------------------------------------------
function QuestService:Reroll(player, uid, stat)
	local profile = data:Get(player)
	if not profile or not table.find(Constants.ROLL_STATS, stat) then
		return false
	end
	local rec
	for _, r in profile.blasters do
		if r.uid == uid then
			rec = r
		end
	end
	if not rec then
		return false
	end
	if not economy:SpendGems(player, Constants.REROLL_GEMS) then
		Net.fire(player, "Toast", `You need {Constants.REROLL_GEMS} gems to reroll.`, "bad")
		return false
	end
	local before = rec.roll[stat]
	rec.roll[stat] = Formulas.pickOdds(Constants.ROLL_ODDS, rng:NextNumber(), 1)
	blasters:Push(player)
	blasters.Changed:Fire(player)
	Net.fire(
		player,
		"Alert",
		`🎲 {string.upper(stat)}: {string.upper(before)} → {string.upper(rec.roll[stat])}`,
		Color3.fromRGB(120, 220, 255)
	)
	Net.fire(player, "Sfx", rec.roll[stat] == "god" and "win" or "pop")
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
	blasters = registry.BlasterService
	planetService = registry.PlanetService
	Net.on("ClaimDaily", function(player)
		self:ClaimDaily(player)
	end)
	Net.on("Reroll", function(player, uid, stat)
		if type(uid) == "number" and type(stat) == "string" then
			self:Reroll(player, uid, stat)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
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

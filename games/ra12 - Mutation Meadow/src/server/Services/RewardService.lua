--[[
Badges, the daily calendar, quests and playtime gifts (§2 RewardService).

Badges: award(player, key) sets profile.badges[key] first, then BadgeService:AwardBadge in a pcall, so a badge is
never retried after it went through (a failed call clears the flag to try again later). A badge with id 0 isn't
created yet: warn and skip, leaving it to award once it has an id. Triggers: welcome (first join), first_harvest,
first_splash (first kept item), first_golden / first_wetgolden (the first such crop kept), master_gardener (CollectionLogService),
week_of_sprouts (Day 7), full_meadow (plot level 5), moonstruck (a Moon Melon harvest), sunflower_friend (Block Party).

Daily calendar (Daily:claim): once per UTC day (Clock.utcDay(now) > lastClaimDay). Grants Config.Daily.days[day]; a
missed day only pauses (the next claim is the next day). Day 7 also gives trail_petals on the first cycle and
repeatCoins after, awards week_of_sprouts, and starts the next cycle.

Quests: the 5 starter quests track from join and pay on completion (the FTUE beats); the daily ones unlock after all
5 starters, reset at 00:00 UTC and pay dailyCoinsPerLevelSq x plotLevel^2 on Quest:claim.

Playtime: playtime.sec counts in-game seconds and resets each UTC day; Playtime:claim {index} pays each gift once a
day once sec >= its atSec (coins x plotLevel^2, and/or top-tier seeds: the highest non-event seed whose shop gate
passes).

  RewardService.award(player, key) -> boolean
  RewardService.topTierSeed(profile)
  RewardService.claimDaily(player) / claimPlaytime(player, index)   (the remote handlers, for tests)
  RewardService.QuestDone(player, questId)
]]
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local BlockPartyService = require(script.Parent.BlockPartyService)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local ShopService = require(script.Parent.ShopService)
local SocialService = require(script.Parent.SocialService)

local RewardService = {
	QuestDone = Signal.new(),
}

local lastTick = setmetatable({}, { __mode = "k" }) -- [player] = time of the last playtime tick

---------------------------------------------------------------------------------------------------------------
-- badges

function RewardService.award(player, key)
	local profile = DataService.get(player)
	local badge = Config.Badges[key]
	if not profile or not badge or profile.badges[key] then
		return false
	end
	if badge.id == 0 then
		warn(`[RewardService] badge {key} has no id yet: skipped`)
		return false
	end
	profile.badges[key] = true
	local ok, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, badge.id)
	end)
	if not ok then
		profile.badges[key] = nil
		warn(`[RewardService] badge {key} failed: {err}`)
		return false
	end
	NetService.change(player, { "badges" }, profile.badges)
	return true
end

---------------------------------------------------------------------------------------------------------------
-- grants

function RewardService.topTierSeed(profile)
	local best
	for _, seed in Config.Restock.order do
		local s = Config.Seeds[seed]
		if not s.gate.eventOnly and ShopService.gateReason(profile, seed, false) == nil then
			if not best or s.tier > Config.Seeds[best].tier then
				best = seed
			end
		end
	end
	return best
end

local function grantSeeds(player, seeds, source)
	for seed, n in seeds do
		InventoryService.addSeeds(player, seed, n, source)
	end
end

local function levelSq(profile)
	return profile.plotLevel ^ 2
end

---------------------------------------------------------------------------------------------------------------
-- the daily calendar

function RewardService.claimDaily(player, _, profile)
	local d = profile.daily
	local today = Clock.utcDay(Clock.now() - Config.Daily.resetUtcHour * 3600)
	if today <= d.lastClaimDay then
		return false, "claimed_today"
	end
	local days = Config.Daily.days
	local entry = days[d.day]
	if entry.coins then
		InventoryService.addCoins(player, entry.coins, "daily")
	end
	if entry.seeds then
		grantSeeds(player, entry.seeds, "daily")
	end
	d.lastClaimDay = today
	d.streak += 1
	if d.day >= #days then
		if d.cycle == 1 and entry.firstCycle then
			profile.cosmetics.owned[entry.firstCycle] = true
			NetService.change(player, { "cosmetics" }, profile.cosmetics)
		elseif entry.repeatCoins then
			InventoryService.addCoins(player, entry.repeatCoins, "daily")
		end
		RewardService.award(player, "week_of_sprouts")
		d.day = 1
		d.cycle += 1
	else
		d.day += 1
	end
	NetService.change(player, { "daily" }, d)
	return true
end

---------------------------------------------------------------------------------------------------------------
-- quests

local STARTER = {}
for i, q in Config.Quests.starter do
	STARTER[q.key] = { index = i, quest = q }
end
local DAILY = {}
for _, q in Config.Quests.daily do
	DAILY[q.key] = q
end

local function starterDone(profile)
	for _, q in Config.Quests.starter do
		local st = profile.quests.starter[q.key]
		if not (st and st.claimed) then
			return false
		end
	end
	return true
end

local function dailyState(profile)
	local dq = profile.quests.daily
	local today = Clock.utcDay(Clock.now())
	if dq.day ~= today then
		dq.day = today
		dq.progress = {}
		dq.claimed = {}
	end
	return dq
end

local function payStarter(player, q)
	local r = q.reward
	if r.coins then
		InventoryService.addCoins(player, r.coins, "quest")
	end
	if r.seeds then
		grantSeeds(player, r.seeds, "quest")
	end
	local i = STARTER[q.key].index
	local what = if r.coins then `{r.coins} coins` else "seeds"
	NetService.toast(player, "quest", `Starter {i} done: {what}`, { quest = q.key })
	RewardService.QuestDone:Fire(player, q.key)
end

-- set (absolute = true) or add to a starter quest's progress; pays on completion
local function starterProgress(player, key, value, absolute)
	local profile = DataService.get(player)
	local entry = STARTER[key]
	if not profile or not entry then
		return
	end
	local st = profile.quests.starter[key] or { n = 0, claimed = false }
	profile.quests.starter[key] = st
	if st.claimed then
		return
	end
	st.n = if absolute then math.max(st.n, value) else st.n + value
	if st.n >= entry.quest.n then
		st.n = entry.quest.n
		st.claimed = true
		payStarter(player, entry.quest)
	end
	NetService.change(player, { "quests" }, profile.quests)
end

local function dailyProgress(player, key, add)
	local profile = DataService.get(player)
	if not profile or not starterDone(profile) then
		return
	end
	local dq = dailyState(profile)
	dq.progress[key] = math.min((dq.progress[key] or 0) + add, DAILY[key].n)
	NetService.change(player, { "quests" }, profile.quests)
end

local function claimQuest(player, payload, profile)
	local id = payload.questId
	if STARTER[id] then
		return false, "auto" -- starter quests pay themselves on completion
	end
	if not starterDone(profile) then
		return false, "locked"
	end
	local dq = dailyState(profile)
	if dq.claimed[id] then
		return false, "claimed"
	end
	if (dq.progress[id] or 0) < DAILY[id].n then
		return false, "not_done"
	end
	dq.claimed[id] = true
	NetService.change(player, { "quests" }, profile.quests)
	InventoryService.addCoins(player, Config.Quests.dailyCoinsPerLevelSq * levelSq(profile), "quest")
	RewardService.QuestDone:Fire(player, id)
	return true
end

---------------------------------------------------------------------------------------------------------------
-- playtime gifts

local function playtimeState(profile)
	local pt = profile.playtime
	local today = Clock.utcDay(Clock.now())
	if pt.day ~= today then
		pt.day = today
		pt.sec = 0
		pt.claimed = {}
	end
	return pt
end

function RewardService.claimPlaytime(player, payload, profile)
	local gift = Config.Playtime[payload.index]
	local pt = playtimeState(profile)
	local key = tostring(payload.index)
	if pt.claimed[key] then
		return false, "claimed"
	end
	if pt.sec < gift.atSec then
		return false, "not_yet"
	end
	pt.claimed[key] = true
	if gift.coinsPerLevelSq then
		InventoryService.addCoins(player, gift.coinsPerLevelSq * levelSq(profile), "playtime")
	end
	if gift.topTierSeeds then
		local seed = RewardService.topTierSeed(profile)
		if seed then
			InventoryService.addSeeds(player, seed, gift.topTierSeeds, "playtime")
		end
	end
	NetService.change(player, { "playtime" }, pt)
	return true
end

local function tickPlaytime(now)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			local dt = now - (lastTick[player] or now)
			lastTick[player] = now
			local pt = playtimeState(profile)
			local before = pt.sec
			pt.sec += dt
			for _, gift in Config.Playtime do
				if before < gift.atSec and pt.sec >= gift.atSec then
					NetService.change(player, { "playtime" }, pt) -- a gift just became ready
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------

function RewardService:Init()
	NetService.on("Daily", "claim", nil, RewardService.claimDaily)
	NetService.on("Quest", "claim", nil, claimQuest)
	NetService.on("Playtime", "claim", nil, RewardService.claimPlaytime)
end

function RewardService:Start()
	FarmService.Harvested:Connect(function(player, seed)
		RewardService.award(player, "first_harvest")
		if seed == "moonmelon" then
			RewardService.award(player, "moonstruck")
		end
		starterProgress(player, "harvest5", 1)
		dailyProgress(player, "harvest30", 1)
	end)
	FarmService.Upgraded:Connect(function(player, kind, level)
		if kind == "plot" then
			starterProgress(player, "plot2", level, true)
		end
	end)
	FarmService.BadgeEarned:Connect(RewardService.award)
	BlockPartyService.BadgeEarned:Connect(RewardService.award)
	BlockPartyService.Watered:Connect(function(player)
		dailyProgress(player, "sunflower5", 1)
	end)
	InventoryService.ItemKept:Connect(function(player, _, item)
		RewardService.award(player, "first_splash")
		-- the badge text says "Keep your first Golden crop": kept, not just mutated
		if item.muts.golden then
			RewardService.award(player, "first_golden")
		end
		if item.muts.golden and item.muts.wet then
			RewardService.award(player, "first_wetgolden")
		end
		starterProgress(player, "keepMut", 1)
	end)
	InventoryService.Displayed:Connect(function(player)
		starterProgress(player, "pedestal", 1)
	end)
	SocialService.Helped:Connect(function(helper)
		starterProgress(helper, "help1", 1)
		dailyProgress(helper, "help3", 1)
	end)
	while true do
		task.wait(1)
		tickPlaytime(Clock.now())
	end
end

function RewardService:OnPlayerLoaded(player, profile)
	lastTick[player] = Clock.now()
	RewardService.award(player, "welcome")
	if profile.plotLevel >= 2 then
		starterProgress(player, "plot2", profile.plotLevel, true)
	end
end

return RewardService

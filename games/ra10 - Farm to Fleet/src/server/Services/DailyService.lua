--[[
Coming back (master plan §8, Data/Daily): the 7-day calendar and the weekly Big Contract.

  the calendar   one claim a UTC day (Net "Daily" "claim"): Cash scaled to the level, Gems, golden seeds; day 7 is
                 the big one; a missed day steps it back one day, not to zero
  golden seeds   profile.goldenSeeds: each makes the next planting golden (FarmService:Plant spends them)
  the weekly     four parts from the week's stats (measured from the week's start); Cash and Gems when all four are
                 done; a new one every Monday (UTC)

profile.calendar = { day (the last day claimed, 1..7), streak, claimedDay (Daily.day of that claim), best }
profile.orders.weekly = { week, level, base = { [stat] = n }, done = { ["1".."4"] = true }, paid }
Net "Daily" to the owner: { today = { day, reward, ready, streak, held }, days = { rewards 1..7 }, weekly = { parts,
reward, paid, ends } }

  DailyService:Claimable(player) -> the day's reward if it's not claimed yet, else nil
  DailyService:Claim(player) -> the reward given, or nil
  DailyService:Weekly(player) -> parts (with have, done), the record
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daily = require(ReplicatedStorage.Shared.Data.Daily)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DailyService = {
	Name = "DailyService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	Changed = Signal.new("DailyService.Changed"),
	TICK = 2,
}

local data, economy, analytics

local function calendarOf(p)
	p.calendar = p.calendar or {}
	local c = p.calendar
	c.day = c.day or 0
	c.streak = c.streak or 0
	c.claimedDay = c.claimedDay or 0
	return c
end

function DailyService:Claimable(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local c = calendarOf(p)
	local today = Daily.day()
	if c.claimedDay == today then
		return nil
	end
	local d = Daily.next(c, today)
	local r = Daily.reward(d, p.level)
	r.day = d
	return r
end

function DailyService:Claim(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local c = calendarOf(p)
	local today = Daily.day()
	if c.claimedDay == today then
		return nil
	end
	local d, held = Daily.next(c, today)
	local r = Daily.reward(d, p.level)
	c.day = d
	c.claimedDay = today
	c.streak = held and c.streak + 1 or 1
	c.best = math.max(c.best or 0, c.streak)
	p.stats.calendar = (p.stats.calendar or 0) + 1
	if r.cash > 0 then
		economy:Add(player, r.cash, "calendar")
	end
	if r.gems > 0 then
		economy:AddGems(player, r.gems, "calendar")
	end
	if r.seeds > 0 then
		p.goldenSeeds = (p.goldenSeeds or 0) + r.seeds
	end
	if p.passes and p.passes.vip then
		-- (VIP: ten more Gems a day)
		r.gems += 10
		economy:AddGems(player, 10, "vip")
	end
	local parts = {}
	if r.cash > 0 then
		table.insert(parts, `{r.cash} Cash`)
	end
	if r.gems > 0 then
		table.insert(parts, `{r.gems} Gems`)
	end
	if r.seeds > 0 then
		table.insert(parts, `{r.seeds} golden seeds`)
	end
	Net.fire(player, "Toast", `DAY {d} REWARD: ` .. table.concat(parts, " + ") .. "!", "good")
	if analytics then
		pcall(analytics.event, player, "calendar", { day = d, streak = c.streak, held = held })
	end
	r.day = d
	self.Changed:Fire(player, "claim")
	self:Push(player)
	return r
end

-- The weekly Big Contract -----------------------------------------------------------------------------------------
local function weeklyOf(player, p)
	p.orders = p.orders or {}
	local week = Daily.week()
	local w = p.orders.weekly
	if type(w) ~= "table" or w.week ~= week or type(w.base) ~= "table" then
		w = { week = week, level = p.level or 1, base = {}, done = {} }
		local parts = Daily.weekly(week, player.UserId, w.level)
		for _, part in parts do
			w.base[part.stat] = p.stats[part.stat] or 0
		end
		p.orders.weekly = w
	end
	w.done = w.done or {}
	local parts, reward = Daily.weekly(week, player.UserId, w.level)
	for i, part in parts do
		part.have = math.clamp((p.stats[part.stat] or 0) - (w.base[part.stat] or 0), 0, part.n)
		part.done = w.done[tostring(i)] == true
	end
	return parts, w, reward
end

function DailyService:Weekly(player)
	local p = data:Get(player)
	if not p then
		return {}, nil
	end
	local parts, w = weeklyOf(player, p)
	return parts, w
end

function DailyService:Check(player, p)
	local parts, w, reward = weeklyOf(player, p)
	local changed = false
	for i, part in parts do
		if not part.done and part.have >= part.n then
			w.done[tostring(i)] = true
			part.done = true
			changed = true
			Net.fire(player, "Toast", `BIG CONTRACT {i}/4: {part.text}!`, "good")
		end
	end
	if changed and not w.paid then
		local all = true
		for _, part in parts do
			all = all and part.done
		end
		if all then
			w.paid = true
			economy:Add(player, reward.cash, "weekly")
			economy:AddGems(player, reward.gems, "weekly")
			p.stats.weeklies = (p.stats.weeklies or 0) + 1
			Net.fire(player, "Toast", `WEEKLY BIG CONTRACT DONE! +{reward.cash} Cash, +{reward.gems} Gems`, "good")
			if analytics then
				pcall(analytics.event, player, "weekly", { week = w.week })
			end
		end
	end
	if changed then
		self.Changed:Fire(player, "weekly")
		self:Push(player)
	end
	return changed
end

function DailyService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local c = calendarOf(p)
	local today = Daily.day()
	local ready = c.claimedDay ~= today
	local d, held = c.day, true
	if ready then
		d, held = Daily.next(c, today)
	end
	local days = {}
	for i = 1, 7 do
		days[i] = Daily.reward(i, p.level)
	end
	local parts, w, reward = weeklyOf(player, p)
	Net.fire(player, "Daily", {
		today = { day = math.max(1, d), ready = ready, streak = c.streak, held = held, reward = days[math.max(1, d)] },
		days = days,
		seeds = p.goldenSeeds or 0,
		weekly = {
			parts = parts,
			reward = reward,
			paid = w.paid == true,
			ends = (Daily.week() + 1) * 7 * 86400 - 3 * 86400 - os.time(),
		},
	})
end

function DailyService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	analytics = registry.AnalyticsService
	Net.on("Daily", function(player, what)
		if what == "claim" then
			self:Claim(player)
		elseif what == "open" then
			self:Push(player)
		end
	end)
end

function DailyService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function DailyService:_tick()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		if p then
			self:Check(player, p)
		end
	end
end

function DailyService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[DailyService] tick failed: " .. tostring(err))
		end
	end
end

return DailyService

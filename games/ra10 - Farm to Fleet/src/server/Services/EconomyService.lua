--[[
The farm's money and level (master plan §3): Cash (earned on the farm), Gems (rare), XP and the farm level
(Data/Levels). Everything that pays goes through here, so the counters on screen stay true.

  EconomyService:Cash(player) / :Gems(player)
  EconomyService:Add(player, n, why)        Cash in (Net "Earned" flies it into the counter); returns the total
  EconomyService:Spend(player, n) -> ok     Cash out, never below 0
  EconomyService:AddGems(player, n, why) / :SpendGems(player, n) -> ok
  EconomyService:AddXP(player, n, why)      XP in; a level-up fires LevelUp and says so
  EconomyService:Level(player)
  EconomyService:Push(player)               the profile view to the client (Net "Profile")
  EconomyService.Changed (player, currency, total, delta, why) · EconomyService.LevelUp (player, level)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Levels = require(ReplicatedStorage.Shared.Data.Levels)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService" },
	Changed = Signal.new("EconomyService.Changed"),
	LevelUp = Signal.new("EconomyService.LevelUp"),
}

local data

function EconomyService:Cash(player)
	local p = data:Get(player)
	return p and p.cash or 0
end

function EconomyService:Gems(player)
	local p = data:Get(player)
	return p and p.gems or 0
end

function EconomyService:Level(player)
	local p = data:Get(player)
	return p and p.level or 1
end

function EconomyService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local level, into, need = Levels.of(p.xp or 0)
	data:Push(player, {
		cash = math.floor(p.cash),
		gems = p.gems,
		xp = p.xp,
		level = level,
		into = into,
		need = need,
		stage = p.stage,
	})
end

function EconomyService:Add(player, n, why)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n <= 0 then
		return p and p.cash or 0
	end
	n = math.floor(n + 0.5)
	p.cash += n
	p.stats.earned = (p.stats.earned or 0) + n
	self.Changed:Fire(player, "cash", p.cash, n, why)
	Net.fire(player, "Earned", { amount = n, why = why, total = p.cash, currency = "cash" })
	self:Push(player)
	return p.cash
end

function EconomyService:Spend(player, n)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n < 0 or p.cash < n then
		return false
	end
	p.cash -= n
	self.Changed:Fire(player, "cash", p.cash, -n, "spend")
	self:Push(player)
	return true
end

function EconomyService:AddGems(player, n, why)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n <= 0 then
		return p and p.gems or 0
	end
	p.gems += math.floor(n)
	self.Changed:Fire(player, "gems", p.gems, n, why)
	Net.fire(player, "Earned", { amount = math.floor(n), why = why, total = p.gems, currency = "gems" })
	self:Push(player)
	return p.gems
end

function EconomyService:SpendGems(player, n)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n < 0 or p.gems < n then
		return false
	end
	p.gems -= n
	self.Changed:Fire(player, "gems", p.gems, -n, "spend")
	self:Push(player)
	return true
end

function EconomyService:AddXP(player, n, why)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n <= 0 then
		return
	end
	local before = p.level or 1
	p.xp = (p.xp or 0) + math.floor(n)
	local level = Levels.of(p.xp)
	p.level = level
	if level > before then
		for l = before + 1, level do
			self.LevelUp:Fire(player, l)
		end
		Net.fire(player, "Toast", `FARM LEVEL {level}!`, "good")
	end
	_ = why
	self:Push(player)
end

function EconomyService:Init(registry)
	data = registry.PlayerDataService
end

function EconomyService:OnPlayerReady(player, profile)
	profile.level = Levels.of(profile.xp or 0)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

return EconomyService

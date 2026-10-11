-- XP, levels and stat allocation (GDD §27.8.19, canon C5). Skill trees and respec are out of MVP scope.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)

local ProgressionService = {
	Name = "ProgressionService",
	Dependencies = { "PlayerDataService", "MutationService" },
	LevelChanged = Signal.new("ProgressionService.LevelChanged"), -- (player, level)
	StatsChanged = Signal.new("ProgressionService.StatsChanged"), -- (player)
}

local data, mutations

function ProgressionService:Init(registry)
	data = registry.PlayerDataService
	mutations = registry.MutationService

	Net.on("AllocateStat", function(player, code)
		local profile = data:Get(player)
		local stat = typeof(code) == "string" and Progression.StatByCode[code]
		if not profile or not stat or profile.statPoints <= 0 then
			return
		end
		if profile.stats[code] >= Progression.MAX_ALLOCATED_PER_STAT then
			Net.fire(player, "Toast", `{stat.name} already has the maximum 50 points.`, "bad")
			return
		end
		profile.stats[code] += 1
		profile.statPoints -= 1
		self:_changed(player)
	end)

	mutations.Equipped:Connect(function(player)
		self:_changed(player)
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
end

function ProgressionService:OnPlayerReady(player)
	self:Push(player)
end

function ProgressionService:_changed(player)
	self:Push(player)
	self.StatsChanged:Fire(player)
end

-- Effective stat: allocated points + mutation bonus, capped (C5).
function ProgressionService:Stat(player, code)
	local profile = data:Get(player)
	if not profile then
		return 0
	end
	local bonus = mutations:StatBonus(player)[code] or 0
	return Formulas.capped(profile.stats[code] + bonus, Progression.StatByCode[code].cap)
end

function ProgressionService:Level(player)
	local profile = data:Get(player)
	return profile and profile.level or 1
end

function ProgressionService:AddXp(player, amount)
	local profile = data:Get(player)
	if not profile or amount <= 0 then
		return
	end
	profile.xp += math.floor(amount)
	local leveled = false
	while profile.level < Constants.LEVEL_CAP_MVP and profile.xp >= Formulas.xpReq(profile.level) do
		profile.xp -= Formulas.xpReq(profile.level)
		profile.level += 1
		profile.statPoints += Progression.STAT_POINTS_PER_LEVEL
		leveled = true
	end
	if profile.level >= Constants.LEVEL_CAP_MVP then
		profile.xp = math.min(profile.xp, Formulas.xpReq(profile.level))
	end
	self:Push(player)
	if leveled then
		data:Push(player, { levelUp = profile.level })
		self.LevelChanged:Fire(player, profile.level)
	end
end

function ProgressionService:Push(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local effective = {}
	for _, s in Progression.Stats do
		effective[s.code] = self:Stat(player, s.code)
	end
	data:Push(player, {
		level = profile.level,
		xp = profile.xp,
		xpReq = Formulas.xpReq(profile.level),
		statPoints = profile.statPoints,
		stats = profile.stats,
		effective = effective,
	})
end

return ProgressionService

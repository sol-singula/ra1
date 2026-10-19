--[[
A new region (master plan §10, §15: prestige, never mandatory, after the centre). The "region" upgrade: the farm
starts over on a fresh territory with every sale paying 25% more a region, the stats and passes kept, the
onboarding not repeated, a trophy on the gate.

  PrestigeService:Open(player)   the reset (UpgradeService fires Applied "region")
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local PrestigeService = {
	Name = "PrestigeService",
	Dependencies = { "PlayerDataService", "UpgradeService" },
}

local data, analytics

function PrestigeService:Open(player)
	local p = data:Get(player)
	if not p then
		return false
	end
	p.prestige = p.prestige or { level = 0 }
	p.prestige.level += 1
	p.cash = 0
	p.stage = "stand"
	p.owned = {}
	p.tiles = {}
	p.stock = {}
	p.chosen = "strawberry"
	p.task.done = true
	p.market = nil
	Net.fire(
		player,
		"Toast",
		`Region {p.prestige.level + 1}: every sale pays {25 * p.prestige.level}% more. Welcome back to the stand!`,
		"good"
	)
	if analytics then
		pcall(analytics.event, player, "prestige", { level = p.prestige.level })
	end
	if data.Rebuild then
		task.defer(data.Rebuild, player)
	end
	return true
end

function PrestigeService:Init(registry)
	data = registry.PlayerDataService
	analytics = registry.AnalyticsService
	registry.UpgradeService.Applied:Connect(function(player, key)
		if key == "region" then
			self:Open(player)
		end
	end)
end

return PrestigeService

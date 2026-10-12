-- The goal card: one goal at a time (Data/Goals), each paying coins or gems. The first three are the tutorial:
-- blast 5 bugs, forge a blaster, beat the Dust King.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Format = require(ReplicatedStorage.Shared.Format)
local Goals = require(ReplicatedStorage.Shared.Data.Goals)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local GoalService = {
	Name = "GoalService",
	Dependencies = { "PlayerDataService", "EconomyService", "BlasterService" },
	Done = Signal.new("GoalService.Done"), -- (player, index)
}

local data, economy, blasters

function GoalService:ProgressOf(player, kind)
	local profile = data:Get(player)
	if not profile then
		return 0
	end
	if kind == "bosses" then
		local n = 0
		for _, times in profile.beaten do
			if times > 0 then
				n += 1
			end
		end
		return n
	elseif kind == "rarity" then
		local best = 0
		for _, rec in profile.blasters do
			best = math.max(best, Blasters.RarityRank[rec.rarity] or 0)
		end
		return best
	end
	return profile.stats[kind] or 0
end

function GoalService:View(player)
	local profile = data:Get(player)
	local g = profile and Goals[profile.goal]
	if not g then
		return false
	end
	return {
		index = profile.goal,
		total = #Goals,
		text = g.text,
		progress = math.min(g.target, self:ProgressOf(player, g.kind)),
		target = g.target,
		reward = g.reward and (Format.num(g.reward) .. " 💰") or (g.gems .. " 💎"),
	}
end

function GoalService:Push(player)
	data:Push(player, { goal = self:View(player) })
end

function GoalService:Check(player)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local g = Goals[profile.goal]
	local changed = false
	while g and self:ProgressOf(player, g.kind) >= g.target do
		if g.reward then
			economy:AddCoins(player, g.reward, false)
		else
			economy:AddGems(player, g.gems, true)
		end
		Net.fire(
			player,
			"Alert",
			`⭐ GOAL DONE! +{g.reward and (Format.num(g.reward) .. " 💰") or (g.gems .. " 💎")}`,
			Color3.fromRGB(255, 215, 60)
		)
		Net.fire(player, "Sfx", "goal")
		self.Done:Fire(player, profile.goal)
		profile.goal += 1
		g = Goals[profile.goal]
		changed = true
	end
	_ = changed
	self:Push(player)
end

function GoalService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	blasters = registry.BlasterService
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	blasters.Changed:Connect(function(player)
		self:Check(player)
	end)
end

function GoalService:Start()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			if data:Get(player) then
				self:Check(player)
			end
		end
	end
end

return GoalService

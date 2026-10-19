--[[
Harvest automation (master plan §5): the first auto-harvester covers every tile you own; its limit is speed. Each
tier clears more tiles a minute. The machine works its way along the route (field by field, row by row), clears
the ripe tiles it reaches, and skips nothing: with 70 of 100 tiles ripe it eventually clears all 70. A full stock
area makes it wait (the storage bottleneck), never lose crops.

  tier 1 auto-harvester 40 a minute · 2 tractor 90 · 3 combine 200 · 4 fleet 400
  x2 while the Harvest Rush boost is on, x1.25 with the Turbo Machines pass

  AutomationService:Rate(player)   tiles a minute (0: no machine)
  AutomationService:Push(player)   Net "Machines" { tier, rate, at = the tile it's working, next }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local AutomationService = {
	Name = "AutomationService",
	Dependencies = { "PlayerDataService", "CropService", "BusinessService" },
	TICK = 0.5,
	RATES = { 40, 90, 200, 400 },
}

local data, crops, boosts
local work = {} -- [player] = { credit, cursor (route index), at (tile id being worked) }

function AutomationService:Rate(player)
	local p = data:Get(player)
	if not p then
		return 0
	end
	local tier = Upgrades.machine(p.owned)
	if tier == 0 then
		return 0
	end
	local rate = self.RATES[tier]
	if boosts and boosts:Active("harvestRush") then
		rate *= 2
	end
	if p.passes and p.passes.fastMachines then
		rate *= 1.25
	end
	return rate
end

function AutomationService:Step(player, dt)
	local rate = self:Rate(player)
	if rate == 0 then
		return
	end
	local w = work[player]
	if not w then
		w = { credit = 0, cursor = 1, at = nil }
		work[player] = w
	end
	w.credit = math.min(w.credit + rate / 60 * dt, 5)
	if w.credit < 1 then
		return
	end
	local route = crops:Tiles(player)
	if #route == 0 then
		return
	end
	-- the next ripe tile along the route from the cursor
	local n = #route
	for _ = 1, n do
		if w.cursor > n then
			w.cursor = 1
		end
		local id = route[w.cursor]
		if crops:Ripe(player, id) then
			local got = crops:Harvest(player, id, "machine")
			if got > 0 then
				w.credit -= 1
				w.at = id
				w.cursor += 1
				if w.credit < 1 then
					return
				end
			else
				return -- (storage full: wait here)
			end
		else
			w.cursor += 1
		end
	end
end

function AutomationService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local w = work[player]
	Net.fire(player, "Machines", {
		tier = Upgrades.machine(p.owned),
		rate = self:Rate(player),
		at = w and w.at or nil,
	})
end

function AutomationService:Init(registry)
	data = registry.PlayerDataService
	crops = registry.CropService
	boosts = registry.BoostService
	registry.UpgradeService.Applied:Connect(function(player, key)
		if Upgrades[key].effect.machine then
			self:Push(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		work[player] = nil
	end)
end

function AutomationService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function AutomationService:Start()
	local last = workspace:GetServerTimeNow()
	local pushAcc = 0
	while true do
		task.wait(self.TICK)
		local t = workspace:GetServerTimeNow()
		local dt = math.clamp(t - last, 0, 5)
		last = t
		pushAcc += dt
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(self.Step, self, player, dt)
			if not ok then
				warn("[AutomationService] tick failed: " .. tostring(err))
			end
			if pushAcc >= 3 then
				pcall(self.Push, self, player)
			end
		end
		if pushAcc >= 3 then
			pushAcc = 0
		end
	end
end

return AutomationService

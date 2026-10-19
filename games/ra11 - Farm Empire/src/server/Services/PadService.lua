--[[
The build pads (tycoon style): eight pads in each farm's build yard, beside the spawn, each showing one upgrade
you can buy now or soon. Step on a pad to buy it; keep standing on it to buy the next level of the same thing.
No walking about the farm to find things to buy, no menus needed (the UPGRADES panel is there too).

What the pads show, in order (nearest the spawn first): the upgrade the guide wants (the onboarding step's, else
the recommendation: it's gold), then the rest you can buy at this stage, cheapest first.

The server watches where each player stands (no Touched events: the root part's position in the farm's frame,
five times a second), so it works the same on every device and in the tests.

  PadService:List(player)          the keys shown, in slot order
  PadService:Refresh(player)       rebuild / repaint the pads now
  PadService:Shown(player)         [slot] = key
  PadService.HOLD                  seconds standing before the next level is bought
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.World.Layout)
local PadBuilder = require(ReplicatedStorage.Shared.World.PadBuilder)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local PadService = {
	Name = "PadService",
	Dependencies = { "PlayerDataService", "EconomyService", "UpgradeService", "TerritoryService", "TaskService" },
	SLOTS = 8, -- the build yard's pads (then one at each animal pen)
	TICK = 0.2,
	HOLD = 1.2,
	REFRESH = 2,
}

local data, economy, upgrades, territory, tasks
local shown = {} -- [player] = { [slot] = key }
local dirty = {} -- [player] = true: repaint at the next tick
local lastRefresh = {}
local standing = {} -- [player] = { slot, key, at }

local function now()
	return workspace:GetServerTimeNow()
end

function PadService:Shown(player)
	return shown[player] or {}
end

function PadService:List(player)
	local p = data:Get(player)
	if not p then
		return {}, nil
	end
	local primary = tasks:Primary(player)
	local first = primary and primary.kind == "upgrade" and primary.target or nil
	local list = {}
	for _, key in Upgrades.LIST do
		local ok, why = Upgrades.can(p, key)
		if (ok or why == "cash") and key ~= first and Upgrades[key].branch ~= "animals" then
			table.insert(list, key)
		end
	end
	table.sort(list, function(a, b)
		return Upgrades.cost(a, p.owned[a] or 0) < Upgrades.cost(b, p.owned[b] or 0)
	end)
	if first and Upgrades[first] and Upgrades[first].branch ~= "animals" then
		local ok, why = Upgrades.can(p, first)
		if ok or why == "cash" then
			table.insert(list, 1, first)
		end
	end
	while #list > self.SLOTS do
		table.remove(list)
	end
	-- the pens' pads: each animal on its own pen (shown once its stage is reached, until maxed)
	for n, key in Layout.ANIMALS do
		local ok, why = Upgrades.can(p, key)
		list[self.SLOTS + n] = (ok or why == "cash") and key or nil
	end
	return list, first
end

function PadService:Refresh(player)
	local p = data:Get(player)
	local t = territory:Territory(player)
	if not p or not t or not t.model or not t.model.Parent then
		return
	end
	lastRefresh[player] = now()
	dirty[player] = nil
	local folder = t.model:FindFirstChild("Pads")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Pads"
		folder.Parent = t.model
	end
	local list, first = self:List(player)
	local prev = shown[player] or {}
	local nowShown = {}
	for k = 1, Layout.PAD_SLOTS do
		local key = list[k]
		local m = folder:FindFirstChild("Pad" .. k)
		if prev[k] ~= key or (key and not m) then
			if m then
				m:Destroy()
			end
			m = key and PadBuilder.build(folder, t.index, k, key, Upgrades[key].branch) or nil
		end
		if m and key then
			local level = p.owned[key] or 0
			local u = Upgrades[key]
			local cost = level < u.max and Upgrades.cost(key, level) or nil
			PadBuilder.paint(m, {
				name = u.name,
				cost = cost,
				level = level,
				max = u.max,
				affordable = cost ~= nil and p.cash >= cost,
				recommended = key == first,
				branch = u.branch,
			})
		end
		nowShown[k] = key
	end
	shown[player] = nowShown
end

-- Which slot a player is standing on (their own farm's pads only)
function PadService:Under(player)
	local t = territory:Territory(player)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not t or not hrp then
		return nil
	end
	local pos = hrp.Position
	if pos.Y > Layout.GROUND_Y + 8 then
		return nil
	end
	local x, z = Layout.toLocal(t.index, pos)
	local r = Layout.PAD / 2 + 0.4
	for k, key in shown[player] or {} do
		local pad = Layout.padAt(k)
		if key and pad and math.abs(x - pad.x) <= r and math.abs(z - pad.z) <= r then
			return k
		end
	end
	return nil
end

function PadService:Step(player)
	if dirty[player] or now() - (lastRefresh[player] or 0) >= self.REFRESH then
		self:Refresh(player)
	end
	local slot = self:Under(player)
	local key = slot and (shown[player] or {})[slot] or nil
	local st = standing[player]
	if not st or st.slot ~= slot then
		standing[player] = { slot = slot, key = key, at = now() }
		if key then
			upgrades:Buy(player, key) -- (it says why not, if it can't)
		end
	elseif key and key == st.key and now() - st.at >= self.HOLD then
		-- still on it: the next level of the same thing, if they can afford it (no toasts every second)
		st.at = now()
		local p = data:Get(player)
		if p and Upgrades.can(p, key) then
			upgrades:Buy(player, key)
		end
	end
end

function PadService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	upgrades = registry.UpgradeService
	territory = registry.TerritoryService
	tasks = registry.TaskService
	economy.Changed:Connect(function(player)
		dirty[player] = true
	end)
	upgrades.Applied:Connect(function(player)
		dirty[player] = true
	end)
	tasks.Completed:Connect(function(player)
		dirty[player] = true
	end)
	territory.Changed:Connect(function(player)
		dirty[player] = true
	end)
	Players.PlayerRemoving:Connect(function(player)
		shown[player], dirty[player], lastRefresh[player], standing[player] = nil, nil, nil, nil
	end)
end

function PadService:OnPlayerReady(player)
	shown[player] = nil
	dirty[player] = true
end

function PadService:OnPlayerLeaving(player)
	shown[player] = nil
	standing[player] = nil
end

function PadService:Start()
	while true do
		task.wait(self.TICK)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(self.Step, self, player)
			if not ok then
				warn("[PadService] tick failed: " .. tostring(err))
			end
		end
	end
end

return PadService

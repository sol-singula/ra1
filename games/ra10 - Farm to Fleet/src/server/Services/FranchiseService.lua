--[[
Prestige (master plan §13.5, Data/Franchise). Once the Market Hall stands, the FRANCHISE panel can sell the company:
Franchise Stars for what this run earned, a new farm in the next region (PlayerDataService.Rebuild takes the plot
down and builds it again from the reset profile, on the same plot, without leaving the server). Stars buy perks
(Net "Franchise" "perk"); every Star ever earned and the region lift what everything ships for
(EconomyService). The region shows on the plot: the meadow's colour, its trees along the back, and the sign.

  resets   cash (to the Head Start), owned, stage, soil, storage, the warehouse's flow, the live orders and the
           special; the guide starts again from chapter 1
  keeps    Gems, golden seeds, XP and the farm level, animals' levels, the calendar, the daily and weekly
           contracts, likes, receipts, passes and every stat

profile.franchise = { level, stars (to spend), total (ever earned), perks = { [key] = level }, runStart (stats.earned
when this run began) }
Net "Franchise": { open, ready, level, stars, total, earn, earned, region, nextRegion, mult, perks = { rows } }

  FranchiseService:Earn(player) -> the Stars a sale would bring now
  FranchiseService:Sell(player) -> ok
  FranchiseService:Perk(player, key) -> ok
  FranchiseService:IncomeMult(profile)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Franchise = require(ReplicatedStorage.Shared.Data.Franchise)
local Net = require(ReplicatedStorage.Shared.Net)
local Shapes = require(ReplicatedStorage.Shared.World.Shapes)
local Signal = require(ReplicatedStorage.Shared.Signal)

local FranchiseService = {
	Name = "FranchiseService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService" },
	Sold = Signal.new("FranchiseService.Sold"), -- (player, level, stars)
}

local data, economy, plots, analytics
local meadowColor = {} -- [plotIndex] = the meadow's own colour
local told = {} -- [player] = true: they've heard it's open this session

local function stateOf(p)
	p.franchise = p.franchise or {}
	local f = p.franchise
	f.level = f.level or 0
	f.stars = f.stars or 0
	f.total = f.total or 0
	f.perks = f.perks or {}
	f.runStart = f.runStart or 0
	return f
end

function FranchiseService:IncomeMult(p)
	return Franchise.incomeMult(p)
end

function FranchiseService:Earn(player)
	local p = data:Get(player)
	if not p then
		return 0
	end
	local f = stateOf(p)
	return Franchise.stars((p.stats.earned or 0) - f.runStart)
end

function FranchiseService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local f = stateOf(p)
	local rows = {}
	for _, key in Franchise.ORDER do
		local perk = Franchise.PERKS[key]
		local level = f.perks[key] or 0
		table.insert(rows, {
			key = key,
			name = perk.name,
			text = perk.text,
			level = level,
			max = perk.max,
			cost = level < perk.max and Franchise.cost(key, level) or nil,
		})
	end
	local open = Franchise.open(p)
	Net.fire(player, "Franchise", {
		open = open,
		ready = open,
		level = f.level,
		stars = f.stars,
		total = f.total,
		earn = self:Earn(player),
		earned = math.floor((p.stats.earned or 0) - f.runStart),
		region = Franchise.region(f.level).name,
		nextRegion = Franchise.region(f.level + 1).name,
		mult = Franchise.incomeMult(p),
		perks = rows,
	})
end

-- The region's look on the plot ----------------------------------------------------------------------------------
local function tree(L, kind, x, z)
	if kind == "palm" then
		L:cyl(x, 7, z, 14, 1.2, { color = Color3.fromRGB(140, 105, 70), name = "Trunk" }, "y")
		for i = 0, 4 do
			local a = math.rad(i * 72)
			L:box(
				x + math.cos(a) * 3,
				14,
				z + math.sin(a) * 3,
				6,
				0.4,
				2,
				Shapes.deco({ color = Color3.fromRGB(60, 160, 70), name = "Frond" })
			)
		end
	elseif kind == "pine" then
		L:cyl(x, 3, z, 6, 1.2, { color = Color3.fromRGB(100, 75, 50), name = "Trunk" }, "y")
		for i, w in { 9, 7, 5, 3 } do
			L:box(x, 4 + i * 3, z, w, 3, w, Shapes.deco({ color = Color3.fromRGB(40, 110, 70), name = "Needles" }))
		end
	elseif kind == "crane" then
		L:box(x, 14, z, 2, 28, 2, { color = Color3.fromRGB(230, 170, 40), name = "CraneMast" })
		L:box(x + 8, 28, z, 20, 1.6, 1.6, Shapes.deco({ color = Color3.fromRGB(230, 170, 40), name = "CraneJib" }))
		L:box(x + 15, 20, z, 0.3, 14, 0.3, Shapes.deco({ color = Color3.fromRGB(40, 40, 44), name = "CraneLine" }))
		L:box(x + 15, 12.5, z, 6, 2.6, 2.6, Shapes.deco({ color = Color3.fromRGB(40, 120, 200), name = "Container" }))
	else
		L:cyl(x, 3, z, 6, 1, { color = Color3.fromRGB(120, 85, 55), name = "Trunk" }, "y")
		L:box(x, 8, z, 7, 5, 7, Shapes.deco({ color = Color3.fromRGB(80, 160, 60), name = "Leaves" }))
		L:box(x + 1.5, 9, z - 1, 1, 1, 1, Shapes.deco({ color = Color3.fromRGB(230, 60, 50), name = "Apple" }))
	end
end

function FranchiseService:Dress(player)
	local p, plot = data:Get(player), plots:Plot(player)
	if not p or not plot then
		return
	end
	local f = stateOf(p)
	local region = Franchise.region(f.level)
	local meadow = plot.folder:FindFirstChild("Meadow")
	if meadow then
		meadowColor[plot.index] = meadowColor[plot.index] or meadow.Color
		meadow.Color = f.level > 0 and region.ground or meadowColor[plot.index]
	end
	local old = plot.items:FindFirstChild("Region")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Region"
	folder:SetAttribute("Region", region.key)
	folder.Parent = plot.items
	if f.level > 0 then
		local L = Shapes.new(folder, plot.cf)
		for x = -72, 72, 18 do
			tree(L, region.trees, x, 106)
		end
	end
	FarmBuilder.sign(
		plot.sign,
		`{string.upper(player.DisplayName)}'S FARM`,
		f.level > 0 and `{string.rep("★", math.min(f.level, 5))} {string.upper(region.name)}` or "",
		plot.color
	)
end

-- Selling and the perks -------------------------------------------------------------------------------------------
function FranchiseService:Sell(player)
	local p = data:Get(player)
	if not p or not Franchise.open(p) or not data.Rebuild then
		return false
	end
	local f = stateOf(p)
	local stars = self:Earn(player)
	f.level += 1
	f.stars += stars
	f.total += stars
	f.runStart = p.stats.earned or 0
	p.stats.franchises = (p.stats.franchises or 0) + 1
	-- the reset (Data/Franchise: what goes, what stays)
	p.cash = Constants.START_CASH + Franchise.HEAD_START[(f.perks.headStart or 0) + 1]
	p.owned = {}
	p.stage = 1
	p.soil = {}
	p.storage = {}
	p.flow = nil
	if p.orders then
		p.orders.live = {}
		p.orders.special = nil
		p.orders.specialIn = nil
	end
	local paid = p.guide and math.max(p.guide.paid or 0, (p.guide.step or 1) - 1) or 0
	p.guide = { chapter = 1, step = 1, done = false, paid = paid }
	local region = Franchise.region(f.level)
	if analytics then
		pcall(analytics.event, player, "franchise", { level = f.level, stars = stars, region = region.key })
	end
	told[player] = nil
	data.Rebuild(player)
	Net.fire(player, "Toast", `SOLD! +{stars} Franchise Stars. Welcome to {region.name}!`, "good")
	Net.fireAll("Toast", `⭐ {player.DisplayName} franchised their company and moved to {region.name}!`, "good")
	self.Sold:Fire(player, f.level, stars)
	self:Push(player)
	return true
end

function FranchiseService:Perk(player, key)
	local p = data:Get(player)
	local perk = type(key) == "string" and Franchise.PERKS[key]
	if not p or not perk then
		return false
	end
	local f = stateOf(p)
	local level = f.perks[key] or 0
	if level >= perk.max then
		return false
	end
	local cost = Franchise.cost(key, level)
	if f.stars < cost then
		Net.fire(player, "Toast", `{perk.name} needs {cost} Stars`, "bad")
		return false
	end
	f.stars -= cost
	f.perks[key] = level + 1
	p.stats.perks = (p.stats.perks or 0) + 1
	Net.fire(player, "Toast", `{perk.name} level {level + 1}!`, "good")
	if analytics then
		pcall(analytics.event, player, "perk", { key = key, level = level + 1 })
	end
	economy:Push(player)
	self:Push(player)
	return true
end

function FranchiseService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	analytics = registry.AnalyticsService
	Net.on("Franchise", function(player, what, a)
		if what == "open" then
			self:Push(player)
		elseif what == "sell" then
			self:Sell(player)
		elseif what == "perk" then
			self:Perk(player, a)
		end
	end)
	-- (a plot let go goes back to the street's own meadow)
	plots.Released:Connect(function(_, plot)
		local meadow = plot.folder:FindFirstChild("Meadow")
		if meadow and meadowColor[plot.index] then
			meadow.Color = meadowColor[plot.index]
		end
	end)
	-- (the panel's button shows up the moment the Market Hall goes up)
	economy.Changed:Connect(function(player, kind)
		if kind == "cash" then
			local p = data:Get(player)
			if p and Franchise.open(p) and not told[player] then
				told[player] = true
				self:Push(player)
			end
		end
	end)
end

function FranchiseService:OnPlayerReady(player)
	told[player] = nil
	self:Dress(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

return FranchiseService

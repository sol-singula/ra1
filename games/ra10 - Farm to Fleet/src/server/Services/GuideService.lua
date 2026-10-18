--[[
The guide (master plan §9): always one next thing to do, with a target in the world. The scripted steps
(Data/Guide) come first, in order, each checked against the profile whenever the farm, the pads or the level
change (and every CHECK seconds); a step done pays its reward and the next one shows at once. After the last
scripted step the guide keeps going with generated goals: the next upgrade on offer, or the level it needs.

Net "Guide" to the owner: { key, text, target = Vector3 (world), step, of, generated? } whenever it changes.

  GuideService:Step(player)       -> the current step (a Data/Guide entry, or a generated one)
  GuideService:Target(player, target) -> Vector3 in the world, or nil
  GuideService:Check(player)      advance past every step that's done; push
  GuideService.Advanced (player, step)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flow = require(ReplicatedStorage.Shared.Data.Flow)
local Guide = require(ReplicatedStorage.Shared.Data.Guide)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local GuideService = {
	Name = "GuideService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"PlotService",
		"FarmService",
		"UpgradeService",
		"AnimalService",
		"OrderService",
		"WarehouseService",
	},
	Advanced = Signal.new("GuideService.Advanced"),
	CHECK = 1,
}

local data, economy, plots, farm, upgrades, animals, orders, analytics
local sent = {} -- [player] = the last payload's key and target, so nothing is sent twice

local function guideOf(p)
	p.guide = p.guide or { chapter = 1, step = 1, done = false }
	return p.guide
end

local function planted(player)
	local n = 0
	for i in farm:Tiles(player) do
		if farm:Phase(player, i) ~= nil then
			n += 1
		end
	end
	return n
end

local function isDone(player, p, step)
	local d = step.done
	if d.kind == "stat" then
		return (p.stats[d.stat] or 0) >= d.n
	elseif d.kind == "owned" then
		return p.owned and p.owned[d.key] ~= nil
	elseif d.kind == "level" then
		return (p.level or 1) >= d.n
	elseif d.kind == "planted" then
		return planted(player) >= d.n
	elseif d.kind == "animal" then
		local st = p.animals and p.animals[d.key]
		return st ~= nil and (st.level or 1) >= d.n
	end
	return false
end

function GuideService:Step(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local g = guideOf(p)
	local step = Guide.STEPS[g.step]
	if step then
		return step
	end
	-- generated, in the warehouse: the bottleneck's fix (or the next fix there is)
	if p.owned and p.owned.warehouse then
		local rates = Flow.rates(p, workspace:GetServerTimeNow())
		local u = Upgrades.trackNext(p.owned, rates.bottleneck)
		local name = string.upper(rates.bottleneck)
		if u and u.level <= (p.level or 1) then
			return {
				key = "fix:" .. u.key,
				text = `BOTTLENECK: {name}! Buy {u.name} at the {name} pad ({Format.num(u.cost)})`,
				target = "station:" .. rates.bottleneck,
				generated = true,
			}
		end
		for _, track in Upgrades.TRACKS do
			local v = Upgrades.trackNext(p.owned, track)
			if v and v.level <= (p.level or 1) then
				return {
					key = "fix:" .. v.key,
					text = `Next: {v.name} at the {string.upper(track)} pad ({Format.num(v.cost)})`,
					target = "station:" .. track,
					generated = true,
				}
			end
		end
	end
	-- generated: the next upgrade on offer, or the level the next one needs
	local offer = upgrades:Offer(player)
	local first = offer[1]
	if first and not first.locked then
		local u = first.upgrade
		return {
			key = "buy:" .. u.key,
			text = `Next: buy {u.name} ({u.cost} Cash)`,
			target = "pad:" .. u.key,
			generated = true,
		}
	end
	local next = Upgrades.upcoming(p.owned or {})
	if next then
		return {
			key = "level:" .. next.level,
			text = `Harvest and sell to reach Farm Level {next.level}`,
			target = "soil",
			generated = true,
		}
	end
	return { key = "more", text = "More of the farm is coming soon: keep growing!", target = "stand", generated = true }
end

-- The world spot a target names
function GuideService:Target(player, target)
	local refs = plots:Refs(player)
	if not refs or type(target) ~= "string" then
		return nil
	end
	if target == "stand" then
		return refs.standPad and refs.standPad.Position
	elseif target == "soil1" then
		return refs.tiles[1] and refs.tiles[1].Position
	elseif target == "soil" then
		-- the tile that wants something: ripe first, then empty, then any
		local best, rank = nil, 99
		for n, tile in refs.tiles do
			local ph = farm:Phase(player, n)
			local r = ph == 3 and 1 or (ph == nil and 2 or 3)
			if r < rank or (r == rank and best and n < best[1]) then
				best, rank = { n, tile }, r
			end
		end
		return best and best[2].Position
	elseif target == "station" or string.sub(target, 1, 8) == "station:" then
		local p = data:Get(player)
		local track = string.sub(target, 9)
		if track == "" then
			track = p and Flow.rates(p, workspace:GetServerTimeNow()).bottleneck or "grow"
		end
		local pad = upgrades:Stations(player)[track]
		return pad and pad.Position
	elseif string.sub(target, 1, 5) == "flow:" then
		local plot = plots:Plot(player)
		local spot = ({
			pack = Vector3.new(30, 0, -31),
			store = PlotLayout.rackSlot(1, 1),
			ship = PlotLayout.SPOTS.truckDoor - Vector3.new(0, 0, 4),
		})[string.sub(target, 6)]
		return plot and spot and PlotLayout.toWorld(plot.index, spot.X, spot.Z, 1)
	elseif target == "pack" then
		local pad = orders and orders:PackPad(player)
		return pad and pad.Position
	elseif target == "board" or target == "door" then
		local plot = plots:Plot(player)
		local spot = target == "board" and PlotLayout.SPOTS.board or PlotLayout.SPOTS.door - Vector3.new(0, 0, 6)
		return plot and PlotLayout.toWorld(plot.index, spot.X, spot.Z, 0.5)
	elseif string.sub(target, 1, 4) == "pen:" then
		local pen = animals and animals:Pens(player)[string.sub(target, 5)]
		return pen and pen.pad.Position
	elseif string.sub(target, 1, 4) == "pad:" then
		local key = string.sub(target, 5)
		for _, pad in refs.pads do
			if pad:GetAttribute("Item") == key then
				return pad.Position
			end
		end
		return refs.pads[2] and refs.pads[2].Position
	end
	return nil
end

local function push(player, force)
	local p = data:Get(player)
	local step = GuideService:Step(player)
	if not p or not step then
		return
	end
	local target = GuideService:Target(player, step.target)
	local s = sent[player]
	if not force and s and s.key == step.key and s.target == target then
		return
	end
	sent[player] = { key = step.key, target = target }
	Net.fire(player, "Guide", {
		key = step.key,
		text = step.text,
		target = target,
		step = guideOf(p).step,
		of = #Guide.STEPS,
		generated = step.generated == true,
	})
end

function GuideService:Check(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local g = guideOf(p)
	local moved = false
	while Guide.STEPS[g.step] and isDone(player, p, Guide.STEPS[g.step]) do
		local step = Guide.STEPS[g.step]
		g.step += 1
		moved = true
		local reward = step.reward or {}
		if reward.cash then
			economy:Add(player, reward.cash, "guide")
		end
		if reward.xp then
			economy:AddXP(player, reward.xp, "guide")
		end
		if analytics then
			pcall(analytics.event, player, "guide", { step = step.key, index = step.index })
		end
		self.Advanced:Fire(player, step)
	end
	if not Guide.STEPS[g.step] then
		g.done = true
	end
	push(player, moved)
end

function GuideService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	farm = registry.FarmService
	upgrades = registry.UpgradeService
	animals = registry.AnimalService
	orders = registry.OrderService
	analytics = registry.AnalyticsService
	farm.Changed:Connect(function(player)
		self:Check(player)
	end)
	upgrades.Bought:Connect(function(player)
		self:Check(player)
	end)
	animals.Changed:Connect(function(player)
		self:Check(player)
	end)
	orders.Changed:Connect(function(player)
		self:Check(player)
	end)
	registry.WarehouseService.Changed:Connect(function(player)
		self:Check(player)
	end)
	economy.LevelUp:Connect(function(player)
		task.defer(self.Check, self, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		sent[player] = nil
	end)
end

function GuideService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		sent[player] = nil
		self:Check(player)
	end)
end

function GuideService:Start()
	while true do
		task.wait(self.CHECK)
		for _, player in Players:GetPlayers() do
			pcall(self.Check, self, player)
		end
	end
end

return GuideService

--[[
What floats past (master plan §7: collecting is the heartbeat; the rod is the first tool; nets collect while you
build). Debris drifts through every plot with the current: wood, scrap, rope, cloth, metal, now and then a supply
crate or a bottle, and the bags of things people dropped or lost. The rod does it all: cast at a piece (aim at
it, ACT) and the line lands on it and reels it in; cast at open water and a bite wants a quick REEL; nets on the
raft's edges catch what passes while you do something else.

  debris     { id, kind, pos, plot, expires, model, special?, data? }: the server decides where a piece is (a
             start position, a time and a velocity on the server's clock, and who is pulling it in: attributes on
             its model), and every client moves the model itself each frame (DebrisController), so the drift never
             crosses the network
  lanes      a voyage's debris lane or a supply drop: extra spawns for a while (VoyageService)
  nets       NET_EVERY: each working net takes a piece within NET_RANGE; with a storage box aboard the catch goes
             straight to the owner's bag, otherwise the net holds NET_HOLD pieces until its prompt is used
  fishing    cast, wait FISH_BITE seconds (faster rods bite sooner), a bite, FISH_WINDOW seconds to reel
             (Formulas.pickFish: the waters, the night and the rod decide what)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Creatures = require(ReplicatedStorage.Shared.Data.Creatures)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local OceanModels = require(ReplicatedStorage.Shared.World.OceanModels)
local Signal = require(ReplicatedStorage.Shared.Signal)

local OceanService = {
	Name = "OceanService",
	Dependencies = { "PlayerDataService", "RaftService", "InventoryService", "PlayerService" },
	Spawned = Signal.new("OceanService.Spawned"), -- (debris)
	Hooked = Signal.new("OceanService.Hooked"), -- (player, debris, items)
	Netted = Signal.new("OceanService.Netted"), -- (raft, piece, items)
	CastOut = Signal.new("OceanService.CastOut"), -- (player)
	Caught = Signal.new("OceanService.Caught"), -- (player, fish, itemKey)
	Missed = Signal.new("OceanService.Missed"), -- (player)
}

local rafts, inventory, players, registry
local plots = {} -- [plot] = { debris = { [id] = d }, nextAt, lanes = {}, netAt }
local byId = {} -- [id] = d
local nextId = 0
local fishing = {} -- [player] = { rod, pos, biteAt, bitten, windowEnds }
local rng = Random.new()
local lastHint = {} -- [player] = os.clock()

-- What drifts: the odds and what each gives (a little more with a stronger rod).
local KINDS = {
	wood = { weight = 40, gives = { wood = { 2, 3 } } },
	scrap = { weight = 22, gives = { scrap = { 2, 3 } } },
	rope = { weight = 16, gives = { rope = { 1, 2 } } },
	cloth = { weight = 14, gives = { cloth = { 1, 2 } } },
	metal = { weight = 8, gives = { metal = { 1, 2 } } },
}
local ORDER = { "wood", "scrap", "rope", "cloth", "metal" }
local TOTAL = 0
for _, k in ORDER do
	TOTAL += KINDS[k].weight
end

local function now()
	return workspace:GetServerTimeNow()
end

local function plotState(plot)
	local p = plots[plot]
	if not p then
		p = { debris = {}, nextAt = 0, lanes = {}, netAt = 0, count = 0 }
		plots[plot] = p
	end
	return p
end

local function pickKind()
	local r = rng:NextNumber() * TOTAL
	for _, k in ORDER do
		r -= KINDS[k].weight
		if r <= 0 then
			return k
		end
	end
	return "wood"
end

local function hint(player, text)
	local t = os.clock()
	if t - (lastHint[player] or 0) < 1.5 then
		return
	end
	lastHint[player] = t
	Net.fire(player, "Toast", text, "info")
end

-- Spawning ------------------------------------------------------------------------------------------------------------
-- A piece upstream of the raft (or at a position), drifting through the plot.
function OceanService:Spawn(plot, kind, opts)
	opts = opts or {}
	local layout = OceanLayout.plot(plot)
	if not layout then
		return nil
	end
	local p = plotState(plot)
	local pos = opts.pos
	if not pos then
		local back = opts.distance or Constants.DEBRIS_FROM
		local across = (opts.spread or Constants.DEBRIS_SPREAD) * rng:NextNumber(-1, 1)
		pos = layout.center - layout.current * back + layout.out * across
	end
	pos = Vector3.new(pos.X, Constants.WATER_LEVEL + 0.3, pos.Z)
	nextId += 1
	local folder = workspace:FindFirstChild("Debris") or workspace
	local model =
		OceanModels.debris(kind, CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), folder)
	model:SetAttribute("DebrisId", nextId)
	model:SetAttribute("Plot", plot)
	model:SetAttribute("Kind", kind)
	if opts.special then
		model:SetAttribute("Special", true)
	end
	local t = now()
	local d = {
		id = nextId,
		kind = kind,
		pos = pos,
		pos0 = pos,
		t0 = t,
		vel = layout.current * Constants.DEBRIS_SPEED * (opts.speed or 1),
		plot = plot,
		layout = layout,
		expires = t + (opts.lifetime or Constants.DEBRIS_LIFETIME),
		model = model,
		special = opts.special,
		data = opts.data,
		guide = opts.guide,
		bob = rng:NextNumber(0, 6),
		yaw = rng:NextNumber(0, math.pi * 2),
	}
	-- what the clients need to draw the drift themselves
	model:SetAttribute("T0", t)
	model:SetAttribute("Pos0", pos)
	model:SetAttribute("Vel", d.vel)
	model:SetAttribute("Bob", d.bob)
	model:SetAttribute("Yaw", d.yaw)
	p.debris[d.id] = d
	p.count += 1
	byId[d.id] = d
	self.Spawned:Fire(d)
	return d
end

function OceanService:Remove(d)
	local p = plots[d.plot]
	if p and p.debris[d.id] then
		p.debris[d.id] = nil
		p.count -= 1
	end
	byId[d.id] = nil
	if d.model then
		d.model:Destroy()
		d.model = nil
	end
end

-- A supply crate (the guide's, or a voyage's supply drop) drifting in from upstream.
function OceanService:Crate(plot, danger, opts)
	opts = opts or {}
	return self:Spawn(plot, "supply_crate", {
		special = "supply_crate",
		data = { danger = danger or 1, guide = opts.guide },
		guide = opts.guide,
		distance = opts.distance or Constants.DEBRIS_FROM,
		spread = opts.spread or 10,
		lifetime = opts.lifetime or 90,
	})
end

function OceanService:Bottle(plot)
	return self:Spawn(plot, "bottle", { special = "bottle", spread = 12, lifetime = 90 })
end

-- A debris lane: `n` extra pieces over `seconds` (a voyage event).
function OceanService:Burst(plot, n, seconds)
	local p = plotState(plot)
	table.insert(p.lanes, { left = n, every = seconds / n, nextAt = now() })
end

-- Pieces within reach the moment a new player arrives (§4: the first cast lands in the first ten seconds).
function OceanService:SeedNear(plot, n)
	local layout = OceanLayout.plot(plot)
	if not layout then
		return
	end
	for i = 1, n do
		local back = 10 + i * 3
		local pos = layout.center - layout.current * back + layout.out * rng:NextNumber(-9, 9)
		self:Spawn(plot, i == 1 and "rope" or pickKind(), { pos = pos, lifetime = 120 })
	end
end

function OceanService:Debris(plot)
	return plotState(plot).debris
end

function OceanService:Get(id)
	return byId[id]
end

-- Debris within a radius of a position in a plot.
function OceanService:Near(plot, pos, radius)
	local out = {}
	for _, d in plotState(plot).debris do
		if (d.pos - pos).Magnitude <= radius then
			table.insert(out, d)
		end
	end
	return out
end

-- Casting at debris --------------------------------------------------------------------------------------------------
-- What the cast lands on: the piece the client named (a debris id, or "drop:<id>"), else a piece right in front
-- (`strict`: only one you are clearly looking at, so a cast at open water fishes).
function OceanService:_target(player, targetId, aim, range, strict)
	local root = players:Root(player)
	if not root then
		return nil
	end
	local plot = players:Here(player)
	if type(targetId) == "number" then
		local d = byId[targetId]
		if d and (d.pos - root.Position).Magnitude <= range + 4 then
			return d
		end
	elseif type(targetId) == "string" then
		local id = tonumber(string.match(targetId, "^drop:(%d+)$"))
		local drop = id and inventory:DropAt(id)
		if drop and (drop.pos - root.Position).Magnitude <= range + 4 then
			return drop, true
		end
	end
	-- no target named: the piece most in front of you
	local dir = typeof(aim) == "Vector3" and aim.Magnitude > 0.01 and Vector3.new(aim.X, 0, aim.Z).Unit
		or root.CFrame.LookVector
	local best, bestScore
	local function consider(d, isDrop)
		local to = d.pos - root.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		local dist = flat.Magnitude
		if dist > range or dist < 1 then
			return
		end
		local dot = flat.Unit:Dot(dir)
		if dot < (strict and 0.8 or 0.55) then
			return
		end
		local score = dot * 2 - dist / range
		if not bestScore or score > bestScore then
			best, bestScore = { d, isDrop }, score
		end
	end
	if plot then
		for _, d in plotState(plot).debris do
			if not d.hooked then
				consider(d, false)
			end
		end
	end
	for _, drop in inventory:Drops() do
		consider(drop, true)
	end
	if best then
		return best[1], best[2]
	end
	return nil
end

local function gives(kind, bonus)
	local spec = KINDS[kind]
	local items = {}
	if spec then
		for key, range in spec.gives do
			table.insert(items, { key = key, n = rng:NextInteger(range[1], range[2]) + (bonus or 0) })
		end
	end
	return items
end

-- The piece is in: what it gives, to whom.
function OceanService:_collect(player, d, rod)
	if not byId[d.id] then
		return
	end
	local items = {}
	if d.special == "supply_crate" then
		items = { { key = "supply_crate", n = 1, data = d.data } }
	elseif d.special == "bottle" then
		items = { { key = "bottle", n = 1, data = registry.LootService:BottleData(player) } }
	else
		local bonus = 0
		if rod and (rod.pull or 1) >= 1.5 and rng:NextNumber() < 0.5 then
			bonus = 1
		end
		if players:Luck(player) > 0 and rng:NextNumber() < 0.5 then
			bonus += 1
		end
		items = gives(d.kind, bonus)
		-- the salvage rod's claw finds the good stuff
		if rod and rod.salvage and rng:NextNumber() < 0.12 * rod.salvage then
			table.insert(items, { key = rng:NextNumber() < 0.7 and "metal" or "pearl", n = 1 })
		end
	end
	local pos = d.pos
	self:Remove(d)
	local text = {}
	for _, it in items do
		inventory:Give(player, it.key, it.n, "hook", { data = it.data })
		local item = Items.get(it.key)
		table.insert(text, `+{it.n} {item and item.icon or ""}`)
	end
	Net.fire(player, "Popup", pos + Vector3.new(0, 2, 0), table.concat(text, " "), Color3.fromRGB(255, 240, 160))
	Net.fire(player, "Sfx", "pickup")
	for _, other in players:PlayersOnPlot(d.plot) do
		Net.fire(other, "Fx", "splash", { pos = pos, small = true })
	end
	self.Hooked:Fire(player, d, items)
end

-- The piece starts coming in: the clients draw it heading for the player from here, at this speed.
function OceanService:_startPull(d, player, speed)
	d.pull = { player = player, speed = speed }
	if d.model then
		d.model:SetAttribute("Pull", player.UserId)
		d.model:SetAttribute("PullFrom", d.pos)
		d.model:SetAttribute("PullT0", now())
		d.model:SetAttribute("PullSpeed", speed)
	end
	players:SetPose(player, "reel", 8)
end

-- The puller left, or the piece is gone: back to drifting from where it is.
function OceanService:_stopPull(d)
	local who = d.pull and d.pull.player
	d.pull, d.hooked, d.hook = nil, nil, nil
	d.pos0, d.t0 = d.pos, now()
	if d.model then
		d.model:SetAttribute("Pull", nil)
		d.model:SetAttribute("Pos0", d.pos0)
		d.model:SetAttribute("T0", d.t0)
	end
	if who then
		players:SetPose(who, "reel", 0)
	end
end

-- The line lands on a piece (or a floating bag) and reels it in.
function OceanService:CastAt(player, item, d, isDrop)
	local rod = item and item.tool and item.tool.rod
	local root = players:Root(player)
	if not rod or not root then
		return false
	end
	if isDrop then
		for _, other in players:PlayersOnPlot(players:Here(player) or 0) do
			Net.fire(other, "Fx", "cast", { from = root.Position, to = d.pos, by = player.UserId, drop = d.id })
		end
		Net.fire(player, "Sfx", "hook")
		players:SetPose(player, "reel", Constants.HOOK_FLIGHT + (d.pos - root.Position).Magnitude / (14 * rod.pull))
		task.delay(Constants.HOOK_FLIGHT + (d.pos - root.Position).Magnitude / (14 * rod.pull), function()
			if player.Parent then
				inventory:Pickup(player, d.id)
			end
		end)
		return true
	end
	if d.hooked then
		return false
	end
	d.hooked = player
	d.hook = rod
	for _, other in players:PlayersOnPlot(d.plot) do
		Net.fire(other, "Fx", "cast", { from = root.Position, to = d.pos, by = player.UserId, id = d.id })
	end
	Net.fire(player, "Sfx", "hook", root.Position)
	task.delay(Constants.HOOK_FLIGHT, function()
		if byId[d.id] and d.hooked == player then
			self:_startPull(d, player, 14 * (rod.pull or 1))
		end
	end)
	-- the long rod and the salvage rod sometimes bring a second piece
	if (rod.double or 0) > 0 and rng:NextNumber() < rod.double then
		for _, other in self:Near(d.plot, d.pos, 10) do
			if other ~= d and not other.hooked and not other.special then
				other.hooked = player
				other.hook = rod
				task.delay(Constants.HOOK_FLIGHT + 0.2, function()
					if byId[other.id] and other.hooked == player then
						self:_startPull(other, player, 14 * (rod.pull or 1))
					end
				end)
				break
			end
		end
	end
	return true
end

-- Nets ------------------------------------------------------------------------------------------------------------------
function OceanService:_nets(raft)
	local p = plotState(raft.plot)
	local hasBox = rafts:Has(raft, "storage", true)
	local owner = raft.owner
	for _, net in rafts:Nets(raft) do
		local piece = net.piece
		local take = piece.key == "salvage_net" and 2 or 1
		if #(piece.held or {}) >= Constants.NET_HOLD then
			continue
		end
		for _, d in self:Near(raft.plot, net.pos, Constants.NET_RANGE) do
			if take <= 0 then
				break
			end
			if not d.hooked and not d.special and not d.guide then
				take -= 1
				local items = gives(d.kind, 0)
				if piece.key == "salvage_net" and rng:NextNumber() < 0.25 then
					table.insert(items, { key = "metal", n = 1 })
				end
				local pos = d.pos
				self:Remove(d)
				if hasBox and owner and owner.Parent then
					for _, it in items do
						inventory:Give(owner, it.key, it.n, "net")
					end
				else
					piece.held = piece.held or {}
					for _, it in items do
						table.insert(piece.held, it)
					end
				end
				for _, other in players:PlayersOnPlot(raft.plot) do
					Net.fire(other, "Fx", "net", { pos = pos, net = net.pos })
				end
				self.Netted:Fire(raft, piece, items)
			end
		end
	end
	_ = p
end

-- Casting ----------------------------------------------------------------------------------------------------------------
-- ACT with a rod: at a piece (named, or clearly in front) it reels it in; at open water it fishes.
function OceanService:Cast(player, item, aim, targetId)
	local rod = item and item.tool and item.tool.rod
	if not rod or not players:IsAlive(player) then
		return false
	end
	local d, isDrop = self:_target(player, targetId, aim, rod.range, targetId == nil)
	if d then
		return self:CastAt(player, item, d, isDrop)
	end
	local where = players:Where(player)
	if where ~= "raft" and where ~= "visiting" then
		hint(player, "🎣 Cast from your raft's edge: at a floating piece to reel it in, at open water to fish.")
		return false
	end
	if fishing[player] then
		return false
	end
	local root = players:Root(player)
	local dir = typeof(aim) == "Vector3" and aim.Magnitude > 0.01 and Vector3.new(aim.X, 0, aim.Z).Unit
		or root.CFrame.LookVector
	local pos = root.Position + dir * 11
	pos = Vector3.new(pos.X, Constants.WATER_LEVEL + 0.2, pos.Z)
	local t = now()
	fishing[player] = {
		rod = rod,
		pos = pos,
		biteAt = t + rng:NextNumber(Constants.FISH_BITE[1], Constants.FISH_BITE[2]) / (rod.speed or 1),
		bitten = false,
	}
	players:SetPose(player, "fishing")
	Net.fire(player, "Fish", { state = "cast", pos = pos })
	for _, other in players:PlayersOnPlot(players:Here(player) or 0) do
		Net.fire(other, "Fx", "cast", { from = root.Position, to = pos, by = player.UserId })
	end
	Net.fire(player, "Sfx", "splash", pos)
	self.CastOut:Fire(player)
	return true
end

function OceanService:Reel(player)
	local f = fishing[player]
	if not f then
		return false
	end
	fishing[player] = nil
	if not f.bitten then
		players:SetPose(player, "fishing", 0)
		Net.fire(player, "Fish", { state = "off" })
		hint(player, "🎣 Too early! Wait for the bite.")
		return false
	end
	players:SetPose(player, "reel", 1.4)
	local plot = players:Here(player)
	local voyages, weather = registry.VoyageService, registry.WeatherService
	local waters = voyages and plot and voyages:Waters(plot) or "home"
	local night = weather and weather:IsNight() or false
	local fish = Formulas.pickFish(rng, Creatures.FISH, waters, night, (f.rod.rare or 0) + players:Luck(player) * 0.3)
	local key = fish.junk or "raw_fish"
	local n = fish.junk and 1 or (fish.food or 1)
	inventory:Give(player, key, n, "fish")
	Net.fire(
		player,
		"Fish",
		{ state = "caught", fish = fish.key, name = fish.name, icon = fish.icon, rarity = fish.rarity }
	)
	Net.fire(player, "Popup", f.pos + Vector3.new(0, 2, 0), `{fish.icon} {fish.name}`, Items.rarityColor(fish.rarity))
	Net.fire(player, "Sfx", "pickup")
	for _, other in players:PlayersOnPlot(plot or 0) do
		Net.fire(other, "Fx", "splash", { pos = f.pos })
	end
	self.Caught:Fire(player, fish, key)
	return true
end

function OceanService:Fishing(player)
	return fishing[player]
end

-- The tick ---------------------------------------------------------------------------------------------------------------
function OceanService:_tick(dt)
	local t = now()
	local voyages = registry.VoyageService
	for plot, raft in rafts:All() do
		local p = plotState(plot)
		-- new pieces
		local sailing = voyages and voyages:State(plot) == "sailing"
		if t >= p.nextAt and p.count < Constants.DEBRIS_MAX then
			p.nextAt = t + Constants.DEBRIS_EVERY * (sailing and 0.6 or 1)
			self:Spawn(plot, pickKind(), { speed = sailing and 3 or 1 })
		end
		for i = #p.lanes, 1, -1 do
			local lane = p.lanes[i]
			if t >= lane.nextAt then
				lane.nextAt = t + lane.every
				lane.left -= 1
				self:Spawn(plot, pickKind(), { spread = 12, lifetime = 45, speed = sailing and 3 or 1 })
				if lane.left <= 0 then
					table.remove(p.lanes, i)
				end
			end
		end
		-- nets
		if t >= p.netAt then
			p.netAt = t + Constants.NET_EVERY
			self:_nets(raft)
		end
		-- drift, pull, expire (the clients draw the models themselves from the same numbers)
		local layout = raft.layout
		for _, d in p.debris do
			if d.pull then
				local root = players:Root(d.pull.player)
				if not root or not d.pull.player.Parent then
					self:_stopPull(d)
				else
					local to = root.Position - d.pos
					local flat = Vector3.new(to.X, 0, to.Z)
					local dist = flat.Magnitude
					if dist <= 3.5 then
						players:SetPose(d.pull.player, "reel", 0)
						self:_collect(d.pull.player, d, d.hook)
						continue
					end
					d.pos += flat.Unit * math.min(dist, d.pull.speed * dt)
				end
			else
				d.pos = d.pos0 + d.vel * (t - d.t0)
				local along = (d.pos - layout.center):Dot(layout.current)
				if along > Constants.DEBRIS_FROM + 14 or t > d.expires then
					self:Remove(d)
					continue
				end
			end
		end
	end
	-- fishing
	for player, f in fishing do
		if not player.Parent or not players:IsAlive(player) then
			fishing[player] = nil
			continue
		end
		local where = players:Where(player)
		if where ~= "raft" and where ~= "visiting" then
			fishing[player] = nil
			players:SetPose(player, f.bitten and "bite" or "fishing", 0)
			Net.fire(player, "Fish", { state = "off" })
			continue
		end
		if not f.bitten and t >= f.biteAt then
			f.bitten = true
			f.windowEnds = t + Constants.FISH_WINDOW
			players:SetPose(player, "bite")
			Net.fire(player, "Fish", { state = "bite", window = Constants.FISH_WINDOW })
			Net.fire(player, "Sfx", "splash", f.pos)
		elseif f.bitten and t > f.windowEnds then
			fishing[player] = nil
			players:SetPose(player, "bite", 0)
			Net.fire(player, "Fish", { state = "away" })
			self.Missed:Fire(player)
		end
	end
end

-- Boot ---------------------------------------------------------------------------------------------------------------------
function OceanService:Init(reg)
	registry = reg
	rafts = reg.RaftService
	inventory = reg.InventoryService
	players = reg.PlayerService
	Net.on("Reel", function(player)
		self:Reel(player)
	end)
	rafts.Assigned:Connect(function(_, raft)
		plotState(raft.plot)
		-- the lane starts full: pieces all the way out to where they appear, so there's always something close and
		-- something coming
		for _ = 1, math.floor(Constants.DEBRIS_MAX / 2) do
			self:Spawn(raft.plot, pickKind(), { distance = rng:NextNumber(20, Constants.DEBRIS_FROM) })
		end
	end)
	rafts.Released:Connect(function(_, raft)
		local p = plots[raft.plot]
		if p then
			for _, d in p.debris do
				if d.model then
					d.model:Destroy()
				end
				byId[d.id] = nil
			end
			plots[raft.plot] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		fishing[player] = nil
		lastHint[player] = nil
		for _, d in byId do
			if d.hooked == player then
				d.pull, d.hooked, d.hook = nil, nil, nil
				d.pos0, d.t0 = d.pos, now()
				if d.model then
					d.model:SetAttribute("Pull", nil)
					d.model:SetAttribute("Pos0", d.pos0)
					d.model:SetAttribute("T0", d.t0)
				end
			end
		end
	end)
end

function OceanService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			self:_tick(acc)
			acc = 0
		end
	end)
end

-- (tests)
OceanService.KINDS = KINDS
OceanService.pickKind = pickKind
return OceanService

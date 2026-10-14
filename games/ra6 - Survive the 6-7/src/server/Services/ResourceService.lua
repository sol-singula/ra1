--[[
Gathering (master plan §3: wood, stone, scrap, food and special materials).

  trees      every tree in the forest (but the giants and the Ancient Pines) can be chopped: swing an axe at it (other
             weapons chop slowly). Each hit gives a little wood, the fall gives the rest (Lumberjack perk: +30%).
             Felled trees leave a stump and grow back for the next run.
  rocks      hit them (clubs and hammers break them fastest): stone. They come back after a while.
  scrap      old junk heaps (and the findings' wrecks): hit them for scrap.
  plants     fiber plants, berry bushes, herbs and glowing glowcaps: hold the Gather prompt.

Hits come from CombatService (it finds what a swing touches with TreesNear / NodesNear). WorldService adds the
findings' own nodes for each run (AddNode).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ResourceService = {
	Name = "ResourceService",
	Dependencies = { "PlayerDataService", "RunService", "InventoryService" },
	Gathered = Signal.new("ResourceService.Gathered"), -- (player, item, amount, sourceKind)
	Felled = Signal.new("ResourceService.Felled"), -- (player, tree)
	Broke = Signal.new("ResourceService.Broke"), -- (player, node)
}

local data, runs, inventory
local MapBuilder -- the server world builder (trees' models)
local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local trees = {} -- [id] = { tree record from MapLayout, hp, felled }
local treeGrid = {} -- [cell] = { tree, ... }
local nodes = {} -- [id] = { id, kind, x, y, z, size, hp, maxHp, model, respawnAt, dynamic }
local nodeGrid = {} -- [cell] = { node, ... } (static and dynamic)
local nextDynamic = 100000
local stumps
local CELL = 16

-- what each node kind gives and how
local NODE = {
	rock = { item = "stone", hit = true, per = 1, bonus = 3, hp = Constants.ROCK_HP, respawn = Constants.ROCK_RESPAWN },
	scrap = { item = "scrap", hit = true, per = 1, bonus = 2, hp = 24, respawn = Constants.SCRAP_RESPAWN },
	fiber = { item = "fiber", gather = 3, respawn = Constants.BUSH_RESPAWN, text = "Gather fiber" },
	berry = { item = "berries", gather = 3, respawn = Constants.BUSH_RESPAWN, text = "Pick berries" },
	herb = { item = "herb", gather = 2, respawn = Constants.BUSH_RESPAWN, text = "Pick herbs" },
	glowcap = { item = "glowcap", gather = 1, respawn = 180, text = "Pick glowcap" },
}
ResourceService.NODE = NODE

local function now()
	return workspace:GetServerTimeNow()
end

local function cellKey(x, z)
	return math.floor(x / CELL) * 100000 + math.floor(z / CELL)
end

local function addToGrid(grid, x, z, v)
	local k = cellKey(x, z)
	grid[k] = grid[k] or {}
	table.insert(grid[k], v)
end

local function near(grid, pos, radius, fn)
	local out = {}
	for cx = math.floor((pos.X - radius) / CELL), math.floor((pos.X + radius) / CELL) do
		for cz = math.floor((pos.Z - radius) / CELL), math.floor((pos.Z + radius) / CELL) do
			local list = grid[cx * 100000 + cz]
			if list then
				for _, v in list do
					if fn(v) then
						table.insert(out, v)
					end
				end
			end
		end
	end
	return out
end

-- Trees --------------------------------------------------------------------------------------------------------------
function ResourceService:Tree(id)
	return trees[id]
end

function ResourceService:IsFelled(id)
	local t = trees[id]
	return t ~= nil and t.felled
end

-- Standing trees whose trunk is within `radius` of pos (2D), nearest first.
function ResourceService:TreesNear(pos, radius)
	local list = near(treeGrid, pos, radius + 4, function(t)
		if t.felled then
			return false
		end
		local dx, dz = t.rec.x - pos.X, t.rec.z - pos.Z
		return dx * dx + dz * dz <= (radius + t.rec.trunk) ^ 2
	end)
	table.sort(list, function(a, b)
		return (a.rec.x - pos.X) ^ 2 + (a.rec.z - pos.Z) ^ 2 < (b.rec.x - pos.X) ^ 2 + (b.rec.z - pos.Z) ^ 2
	end)
	return list
end

-- The giants of the deep forest (and anything else with endless health) can't be chopped.
function ResourceService:CanChop(t)
	return t ~= nil and not t.felled and t.hp ~= math.huge
end

-- A swing at a tree too big to chop: a thunk, and (now and then) a word on why nothing happened.
local tooBigToast = setmetatable({}, { __mode = "k" }) -- [player] = when it was last said
function ResourceService:TooBig(player, t)
	local pos = V3(t.rec.x, t.rec.y + 3, t.rec.z)
	Net.fireAll("Sfx", "thud", pos)
	if (tooBigToast[player] or -100) < now() - 10 then
		tooBigToast[player] = now()
		Net.fire(player, "Toast", "🌲 This giant is too big to chop. Try a smaller tree!", "info")
	end
end

-- An axe (or anything) hits a tree. power = the item's tree power. Returns the wood given.
function ResourceService:HitTree(player, t, power)
	if not t or t.felled or t.hp == math.huge then
		return 0
	end
	local profile = data:Get(player)
	local mult = (profile and table.find(profile.perks or {}, "lumberjack")) and 1.3 or 1
	t.hp -= 10 * math.max(power, 0.1)
	local pos = V3(t.rec.x, t.rec.y + 3, t.rec.z)
	Net.fireAll("Fx", "chop", { pos = pos, tree = t.rec.id })
	local wood = math.random() < 0.6 * mult and 1 or 0
	if t.hp <= 0 then
		wood += math.floor(t.wood * mult + 0.5)
		self:_fell(player, t)
	end
	if wood > 0 then
		inventory:Give(player, "wood", wood, "tree")
		Net.fire(player, "Popup", pos, `+{wood} 🪵`, Color3.fromRGB(230, 190, 130))
		self.Gathered:Fire(player, "wood", wood, "tree")
	end
	return wood
end

function ResourceService:_fell(player, t)
	t.felled = true
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dir = hrp and (V3(t.rec.x, 0, t.rec.z) - V3(hrp.Position.X, 0, hrp.Position.Z)) or V3(1, 0, 0)
	dir = dir.Magnitude > 0.01 and dir.Unit or V3(1, 0, 0)
	Net.fireAll("Fx", "fell", { tree = t.rec.id, dir = dir, pos = V3(t.rec.x, t.rec.y, t.rec.z), h = t.rec.h })
	Net.fireAll("Sfx", "thud", V3(t.rec.x, t.rec.y, t.rec.z))
	local model = MapBuilder and MapBuilder.tree(t.rec.id)
	if MapBuilder then
		MapBuilder.forgetTree(t.rec.id)
	end
	task.delay(1.6, function()
		if model then
			model:Destroy()
		end
	end)
	if stumps then
		local s = Kit.stump(stumps, V3(t.rec.x, t.rec.y, t.rec.z), Random.new(t.rec.seed))
		-- (to the trunk's width: a stump is upright cylinders, whose length is X and whose width is Y and Z)
		for _, part in s:GetDescendants() do
			if part:IsA("BasePart") then
				part.Size = part.Size * V3(1, t.rec.trunk / 1.1, t.rec.trunk / 1.1)
			end
		end
	end
	self.Felled:Fire(player, t)
end

-- Nodes ----------------------------------------------------------------------------------------------------------------
local function nodeModel(n, parent)
	local m = Kit.model(n.kind, parent)
	local pos = V3(n.x, n.y, n.z)
	local rng = Random.new(n.seed or n.id)
	if n.kind == "rock" then
		local b =
			Kit.boulder(m, pos - V3(0, 0.4, 0), n.size, rng, C.rock:Lerp(C.rockMoss, rng:NextNumber(0, 0.35)), M.Rock)
		b.Name = "Rock"
	elseif n.kind == "scrap" then
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			Kit.box(
				m,
				"Scrap",
				CFrame.new(pos + V3(math.cos(a) * 0.9, 0.4 + (k % 2) * 0.3, math.sin(a) * 0.9))
					* CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)),
				V3(rng:NextNumber(1, 1.8), 0.3, rng:NextNumber(0.6, 1.2)),
				k % 2 == 0 and C.iron or Color3.fromRGB(150, 96, 70),
				k % 2 == 0 and M.Metal or M.CorrodedMetal,
				{ CastShadow = false }
			)
		end
		Kit.cyl(
			m,
			"Wheel",
			CFrame.new(pos + V3(0.4, 0.5, -0.6)) * CFrame.Angles(0, 0.6, 0),
			0.5,
			1.4,
			C.black,
			M.Rubber,
			{
				CastShadow = false,
			}
		)
	elseif n.kind == "fiber" then
		for k = 1, 7 do
			local a = k / 7 * math.pi * 2
			local h = rng:NextNumber(2, 3.4)
			Kit.box(
				m,
				"Blade",
				CFrame.new(pos + V3(math.cos(a) * 0.4, h / 2, math.sin(a) * 0.4))
					* CFrame.Angles(math.cos(a) * 0.25, 0, math.sin(a) * 0.25),
				V3(0.18, h, 0.35),
				C.fern:Lerp(C.leafLight, rng:NextNumber(0, 0.6)),
				M.Grass,
				{ CanCollide = false, CastShadow = false }
			)
		end
		Kit.ball(m, "Tuft", pos + V3(0, 3.2, 0), 0.6, C.cream, M.Fabric, { CanCollide = false, CastShadow = false })
	elseif n.kind == "berry" then
		Kit.ball(m, "Bush", pos + V3(0, 1.2, 0), 3.2, C.leafDark, M.Grass, { CastShadow = false })
		for _ = 1, 7 do
			local a = rng:NextNumber(0, math.pi * 2)
			local e = rng:NextNumber(0.2, 1.1)
			Kit.ball(
				m,
				"Berry",
				pos + V3(math.cos(a) * 1.45, 1.2 + e, math.sin(a) * 1.45),
				0.45,
				C.flowerBlue:Lerp(C.purple, 0.4),
				M.SmoothPlastic,
				{ CanCollide = false, CastShadow = false }
			)
		end
	elseif n.kind == "herb" then
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			Kit.ellipsoid(
				m,
				"Leaf",
				pos + V3(math.cos(a) * 0.5, 0.7, math.sin(a) * 0.5),
				V3(0.5, 0.15, 1.2),
				C.green:Lerp(C.leafLight, 0.3),
				M.Grass,
				{ CanCollide = false, CastShadow = false }
			)
		end
		Kit.ball(
			m,
			"Flower",
			pos + V3(0, 1.3, 0),
			0.5,
			C.flowerWhite,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	elseif n.kind == "glowcap" then
		Kit.mushrooms(m, pos, rng, true)
		local cap = m:FindFirstChild("Cap")
		if cap then
			Kit.light(cap, "PointLight", { Color = C.glowcap, Range = 10, Brightness = 1.2 })
		end
	end
	m:SetAttribute("NodeId", n.id)
	m:SetAttribute("Kind", n.kind)
	local spec = NODE[n.kind]
	if spec.gather then
		local anchor = m:FindFirstChildWhichIsA("BasePart")
		if anchor then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Gather"
			prompt.ActionText = spec.text
			prompt.ObjectText = ""
			prompt.HoldDuration = 0.4
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = anchor
		end
	end
	return m
end
ResourceService.nodeModel = nodeModel

function ResourceService:_buildNode(n)
	local parent = workspace:FindFirstChild("Nodes") or workspace
	n.model = nodeModel(n, parent)
	if NODE[n.kind].hit then
		-- (for the client's aim help: where it is and how big)
		n.model:SetAttribute("At", V3(n.x, n.y, n.z))
		n.model:SetAttribute("Radius", self:NodeRadius(n))
	end
	local spec = NODE[n.kind]
	n.hp = spec.hp and spec.hp * (n.kind == "rock" and math.max(0.6, n.size / 4.5) or 1) or 1
	n.maxHp = n.hp
	n.respawnAt = nil
	local prompt = n.model:FindFirstChild("Gather", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			self:Gather(player, n)
		end)
	end
end

function ResourceService:_deplete(n)
	if n.model then
		n.model:Destroy()
		n.model = nil
	end
	local spec = NODE[n.kind]
	n.respawnAt = not n.once and (now() + spec.respawn) or nil
	n.gone = true
end

-- How far a node reaches from its centre (rocks by their size).
function ResourceService:NodeRadius(n)
	return n.kind == "rock" and (n.size or 2) * 0.5 or 1.2
end

-- Hittable nodes (rocks, scrap) whose edge is within radius of pos.
function ResourceService:NodesNear(pos, radius)
	return near(nodeGrid, pos, radius + 6, function(n)
		if n.gone or not NODE[n.kind].hit then
			return false
		end
		local r = self:NodeRadius(n)
		return (n.x - pos.X) ^ 2 + (n.z - pos.Z) ^ 2 <= (radius + r) ^ 2
	end)
end

function ResourceService:HitNode(player, n, power)
	if not n or n.gone then
		return 0
	end
	local spec = NODE[n.kind]
	n.hp -= 10 * math.max(power, 0.1)
	local pos = V3(n.x, n.y + 1.5, n.z)
	Net.fireAll("Fx", n.kind == "rock" and "sparks" or "clank", { pos = pos })
	local got = math.random() < 0.7 and spec.per or 0
	if n.hp <= 0 then
		got += spec.bonus
		self:_deplete(n)
		self.Broke:Fire(player, n)
	end
	if got > 0 then
		inventory:Give(player, spec.item, got, n.kind)
		Net.fire(
			player,
			"Popup",
			pos,
			`+{got} {spec.item == "stone" and "🪨" or "⚙️"}`,
			Color3.fromRGB(220, 220, 230)
		)
		self.Gathered:Fire(player, spec.item, got, n.kind)
	end
	return got
end

function ResourceService:Gather(player, n)
	if n.gone or not runs:InRun(player) then
		return 0
	end
	local spec = NODE[n.kind]
	local amount = spec.gather
	if n.kind == "glowcap" then
		amount = math.random(1, 2)
	end
	inventory:Give(player, spec.item, amount, n.kind)
	Net.fire(player, "Popup", V3(n.x, n.y + 2, n.z), `+{amount}`, Color3.fromRGB(200, 255, 170))
	Net.fire(player, "Sfx", "pickup")
	self.Gathered:Fire(player, spec.item, amount, n.kind)
	self:_deplete(n)
	return amount
end

-- A node for this run only (a finding's scrap, glowcaps in a mushroom ring).
function ResourceService:AddNode(kind, pos, opts)
	nextDynamic += 1
	local n = {
		id = nextDynamic,
		kind = kind,
		x = pos.X,
		y = MapLayout.floorY(pos.X, pos.Z),
		z = pos.Z,
		size = opts and opts.size or 4,
		seed = nextDynamic,
		dynamic = true,
		once = opts and opts.once,
	}
	nodes[n.id] = n
	addToGrid(nodeGrid, n.x, n.z, n)
	self:_buildNode(n)
	return n
end

function ResourceService:Nodes()
	return nodes
end

-- A new run: every tree back, every node back, the findings' nodes gone.
function ResourceService:ResetWorld()
	for id, t in trees do
		if t.felled and MapBuilder then
			MapBuilder.plantTree(t.rec)
		end
		t.felled = false
		t.hp = t.maxHp
		_ = id
	end
	if stumps then
		stumps:ClearAllChildren()
	end
	for id, n in nodes do
		if n.dynamic then
			if n.model then
				n.model:Destroy()
			end
			nodes[id] = nil
		elseif n.gone or not n.model then
			n.gone = false
			self:_buildNode(n)
		end
	end
	-- the grid keeps dynamic nodes that are gone: rebuild it from what's left
	table.clear(nodeGrid)
	for _, n in nodes do
		addToGrid(nodeGrid, n.x, n.z, n)
	end
end

function ResourceService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	inventory = registry.InventoryService
	local ok, mb = pcall(function()
		return require(script.Parent.Parent.World.MapBuilder)
	end)
	MapBuilder = ok and mb or nil
	for _, rec in MapLayout.trees() do
		local spec = MapLayout.TREE_KINDS[rec.kind]
		if rec.reachable then
			local t = { rec = rec, hp = spec.hp, maxHp = spec.hp, wood = spec.wood, felled = false }
			trees[rec.id] = t
			addToGrid(treeGrid, rec.x, rec.z, t)
		end
	end
	runs.Reset:Connect(function()
		self:ResetWorld()
	end)
end

function ResourceService:Start()
	local map = workspace:FindFirstChild("Map")
	stumps = Instance.new("Folder")
	stumps.Name = "Stumps"
	stumps.Parent = map or workspace
	for _, n in MapLayout.nodes() do
		local node = table.clone(n)
		nodes[node.id] = node
		addToGrid(nodeGrid, node.x, node.z, node)
		self:_buildNode(node)
	end
	while true do
		task.wait(2)
		local t = now()
		for _, n in nodes do
			if n.gone and n.respawnAt and t >= n.respawnAt then
				n.gone = false
				self:_buildNode(n)
			end
		end
	end
end

return ResourceService

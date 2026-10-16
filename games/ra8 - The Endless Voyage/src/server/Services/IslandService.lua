--[[
The island beside the plot (master plan §9: exploration with a purpose). When a voyage arrives, IslandBuilder
raises the destination out of the water next to the raft; this runs what's on it: nodes to gather (an axe for
trees, a pickaxe for rocks, ore and crystals, a crowbar for a wreck's salvage; bushes by hand), containers to
search (hold the prompt), the landmark to look at (the journal's story, and sometimes the next chart), the
environmental puzzles (light three lanterns at Mist Hollow, turn three totems to face the sea at the Ruin: a chest
appears), lava that burns, and the creatures that live there (CreatureService). Sailing home takes it all down.
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local IslandBuilder = require(ReplicatedStorage.Shared.World.IslandBuilder)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanModels = require(ReplicatedStorage.Shared.World.OceanModels)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)

local IslandService = {
	Name = "IslandService",
	Dependencies = { "PlayerDataService", "RaftService", "InventoryService", "PlayerService", "LootService" },
	Arrived = Signal.new("IslandService.Arrived"), -- (plot, island)
	Left = Signal.new("IslandService.Left"), -- (plot, island)
	Gathered = Signal.new("IslandService.Gathered"), -- (player, node, items)
	Searched = Signal.new("IslandService.Searched"), -- (player, container, items, island)
	Looked = Signal.new("IslandService.Looked"), -- (player, island, first)
	Solved = Signal.new("IslandService.Solved"), -- (plot, island, players)
	Burned = Signal.new("IslandService.Burned"), -- (player)
}

local rafts, inventory, players, loot, registry
local islands = {} -- [plot] = island
local rng = Random.new()
local lastHint = {}

local TOOL_NAME = { axe = "an axe", pick = "a pickaxe", pry = "a crowbar" }
local TOOL_FX = { axe = "chop", pick = "sparks", pry = "clank" }

local function now()
	return workspace:GetServerTimeNow()
end

local function hint(player, text)
	local t = os.clock()
	if t - (lastHint[player] or 0) < 1.5 then
		return
	end
	lastHint[player] = t
	Net.fire(player, "Toast", text, "info")
end

local function prompt(model, kind, text, object, id, hold)
	local part = model and model:FindFirstChildWhichIsA("BasePart")
	if not part then
		return nil
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = "Prompt"
	p.ActionText = text
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Id", id)
	p.Parent = part
	return p
end

-- Reads -------------------------------------------------------------------------------------------------------------
function IslandService:Here(plot)
	return islands[plot]
end

function IslandService:Ashore(plot, pos)
	local island = islands[plot]
	if not island then
		return false
	end
	local d = Vector3.new(pos.X - island.center.X, 0, pos.Z - island.center.Z).Magnitude
	return d <= island.radius + 8 and pos.Y > Constants.WATER_LEVEL - 1.5
end

function IslandService:Ground(plot, x, z)
	local island = islands[plot]
	return island and island.built.ground(x, z) or nil
end

function IslandService:View(plot)
	local island = islands[plot]
	if not island then
		return false
	end
	local nodes, containers, opened = 0, 0, 0
	for _ in island.nodes do
		nodes += 1
	end
	for _, c in island.containers do
		containers += 1
		if c.opened then
			opened += 1
		end
	end
	local puzzle
	if island.puzzle then
		local done = 0
		for _, part in island.puzzle.parts do
			if
				(island.puzzle.kind == "lanterns" and part.lit) or (island.puzzle.kind == "totems" and part.facing == 0)
			then
				done += 1
			end
		end
		puzzle = {
			kind = island.puzzle.kind,
			done = done,
			total = #island.puzzle.parts,
			solved = island.puzzle.solved or nil,
		}
	end
	return {
		key = island.dest.key,
		name = island.dest.name,
		icon = island.dest.icon,
		kind = island.dest.kind,
		template = island.dest.template,
		danger = island.dest.danger,
		desc = island.dest.desc,
		nodes = nodes,
		containers = containers - opened,
		containersTotal = containers,
		puzzle = puzzle,
		landmark = island.landmark and island.landmark.text or nil,
		landmarkPos = island.landmark and island.landmark.pos or nil,
		center = island.center,
		radius = island.radius,
	}
end

function IslandService:Push(plot)
	local view = self:View(plot)
	for _, player in players:PlayersOnPlot(plot) do
		Net.fire(player, "Island", view)
	end
end

-- Arriving and leaving -------------------------------------------------------------------------------------------
function IslandService:Arrive(plot, dest)
	if islands[plot] then
		self:Leave(plot)
	end
	local raft = rafts:Get(plot)
	if not raft or not dest then
		return nil
	end
	local folder = workspace:FindFirstChild("Islands") or workspace
	-- right off the raft's outer side, whatever its size: you hop ashore
	local layout = OceanLayout.plot(plot)
	local t = IslandBuilder.TEMPLATES[dest.template]
	local reach = Formulas.raftReach(layout.center, raft.pieces, layout.out)
	local spot = OceanLayout.islandBeside(plot, reach, t and t.radius or Constants.ISLAND_RADIUS)
	local built = IslandBuilder.build(dest.template, spot, rng, folder)
	built.model:SetAttribute("Plot", plot)
	built.model:SetAttribute("Dest", dest.key)
	local island = {
		plot = plot,
		dest = dest,
		built = built,
		center = built.center,
		radius = built.radius,
		nodes = {},
		containers = {},
		puzzle = built.puzzle,
		landmark = built.landmark,
		looked = {}, -- [player] = true
		arrivedAt = now(),
	}
	for _, n in built.nodes do
		island.nodes[n.id] = n
		if not n.tool then
			prompt(n.model, "bush", "Pick", "Plants", n.id)
		end
	end
	for _, c in built.containers do
		island.containers[c.id] = c
		prompt(
			c.model,
			"container",
			"Search",
			c.kind == "locker" and "Locker" or c.kind == "chest" and "Chest" or "Container",
			c.id,
			Constants.CONTAINER_SEARCH
		)
	end
	if island.puzzle then
		for _, part in island.puzzle.parts do
			prompt(
				part.model,
				"puzzle",
				island.puzzle.kind == "lanterns" and "Light" or "Turn",
				island.puzzle.kind == "lanterns" and "Lantern" or "Totem",
				part.id
			)
		end
	end
	if island.landmark then
		prompt(island.landmark.model, "landmark", "Look", dest.name, 0)
	end
	islands[plot] = island
	local creatures = registry.CreatureService
	if creatures then
		for _, s in built.spawns do
			creatures:SpawnAt(s.kind, s.pos, plot, { danger = dest.danger, island = true })
		end
	end
	self:Push(plot)
	self.Arrived:Fire(plot, island)
	return island
end

function IslandService:Leave(plot)
	local island = islands[plot]
	if not island then
		return
	end
	islands[plot] = nil
	local creatures = registry.CreatureService
	if creatures then
		creatures:ClearPlot(plot, "island")
	end
	-- everyone ashore comes back aboard
	local raft = rafts:Get(plot)
	for _, player in players:PlayersOnPlot(plot) do
		local pos = players:Position(player)
		if raft and pos and self:AshoreOf(island, pos) then
			players:Teleport(player, rafts:SpawnPoint(raft))
		end
		Net.fire(player, "Island", false)
	end
	IslandBuilder.remove(island.built)
	self.Left:Fire(plot, island)
end

function IslandService:AshoreOf(island, pos)
	local d = Vector3.new(pos.X - island.center.X, 0, pos.Z - island.center.Z).Magnitude
	return d <= island.radius + 8 and pos.Y > Constants.WATER_LEVEL - 1.5
end

-- Gathering ---------------------------------------------------------------------------------------------------------
local function fxTo(plot, kind, d)
	for _, player in players:PlayersOnPlot(plot) do
		Net.fire(player, "Fx", kind, d)
	end
end

-- What the swing hits: the node the client named, else the nearest one this tool works on in front of you.
function IslandService:_node(player, island, tool, targetId, aim)
	local root = players:Root(player)
	if not root then
		return nil
	end
	if type(targetId) == "number" then
		local n = island.nodes[targetId]
		if n and (n.pos - root.Position).Magnitude <= 10 then
			return n
		end
	end
	local dir = typeof(aim) == "Vector3" and aim.Magnitude > 0.01 and Vector3.new(aim.X, 0, aim.Z).Unit
		or root.CFrame.LookVector
	local best, bestScore
	for _, n in island.nodes do
		local to = n.pos - root.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		local dist = flat.Magnitude
		if dist <= 9 and n.tool then
			local dot = dist > 0.5 and flat.Unit:Dot(dir) or 1
			local score = (n.tool == tool and 2 or 0) + dot - dist / 9
			if dot > 0.2 and (not bestScore or score > bestScore) then
				best, bestScore = n, score
			end
		end
	end
	return best
end

function IslandService:Gather(player, item, targetId, aim)
	local plot = players:Here(player)
	local island = plot and islands[plot]
	local tool = Items.toolKind(item)
	if not island then
		hint(player, "🏝️ Trees, rocks and wrecks are on the islands. Set sail from the helm.")
		return false
	end
	local n = self:_node(player, island, tool, targetId, aim)
	if not n then
		hint(
			player,
			tool == "axe" and "🌴 Walk up to a tree and swing."
				or tool == "pick" and "⛰️ Walk up to a rock and swing."
				or "🔧 Walk up to a salvage pile and pry."
		)
		return false
	end
	if n.tool ~= tool then
		hint(player, `That needs {TOOL_NAME[n.tool] or "a tool"}.`)
		return false
	end
	local power = item.tool[tool].power or 1
	n.hp -= 10 * power
	fxTo(plot, TOOL_FX[tool] or "chop", { pos = n.pos, node = n.id, kind = n.kind })
	Net.fire(player, "Sfx", tool == "axe" and "chop" or "mine", n.pos)
	if n.hp > 0 then
		return true
	end
	island.nodes[n.id] = nil
	if n.model then
		n.model:Destroy()
	end
	fxTo(plot, n.kind == "tree" and "fell" or "crumble", { pos = n.pos, kind = n.kind })
	local text = {}
	for _, g in n.gives do
		inventory:Give(player, g.key, g.n, "gather")
		local it = Items.get(g.key)
		table.insert(text, `+{g.n} {it and it.icon or ""}`)
	end
	Net.fire(player, "Popup", n.pos + Vector3.new(0, 3, 0), table.concat(text, " "), Color3.fromRGB(255, 240, 160))
	Net.fire(player, "Sfx", "pickup")
	self.Gathered:Fire(player, n, n.gives)
	self:Push(plot)
	return true
end

function IslandService:Pick(player, island, nodeId)
	local n = island.nodes[nodeId]
	if not n or n.tool then
		return false
	end
	island.nodes[n.id] = nil
	if n.model then
		n.model:Destroy()
	end
	local text = {}
	for _, g in n.gives do
		inventory:Give(player, g.key, g.n, "gather")
		local it = Items.get(g.key)
		table.insert(text, `+{g.n} {it and it.icon or ""}`)
	end
	Net.fire(player, "Popup", n.pos + Vector3.new(0, 3, 0), table.concat(text, " "), Color3.fromRGB(255, 240, 160))
	Net.fire(player, "Sfx", "pickup")
	self.Gathered:Fire(player, n, n.gives)
	self:Push(island.plot)
	return true
end

-- Containers, the landmark, the puzzles -----------------------------------------------------------------------------
function IslandService:Search(player, island, containerId)
	local c = island.containers[containerId]
	if not c or c.opened then
		return false
	end
	c.opened = true
	if c.model then
		c.model:SetAttribute("Opened", true)
		local p = c.model:FindFirstChild("Prompt", true)
		if p then
			p:Destroy()
		end
	end
	local items = loot:Container(player, island.dest.key, c.kind)
	fxTo(island.plot, "loot", { pos = c.pos })
	self.Searched:Fire(player, c, items, island)
	self:Push(island.plot)
	return true
end

function IslandService:Look(player, island)
	local first = not island.looked[player]
	island.looked[player] = true
	Net.fire(player, "Alert", `📔 {island.landmark.text}`, Color3.fromRGB(240, 220, 160), 7)
	Net.fire(player, "Sfx", "discover")
	self.Looked:Fire(player, island, first)
	return true
end

function IslandService:Puzzle(player, island, partId)
	local puzzle = island.puzzle
	if not puzzle or puzzle.solved then
		return false
	end
	local part
	for _, p in puzzle.parts do
		if p.id == partId then
			part = p
		end
	end
	if not part then
		return false
	end
	if puzzle.kind == "lanterns" then
		if part.lit then
			return false
		end
		part.lit = true
		if part.model then
			part.model:SetAttribute("Lit", true)
			local glass = part.model:FindFirstChild("Glass")
			if glass then
				glass.Color = Color3.fromRGB(255, 200, 90)
				glass.Material = Enum.Material.Neon
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 200, 90)
				light.Range = 18
				light.Brightness = 1.5
				light.Parent = glass
			end
		end
		Net.fire(player, "Sfx", "craft", part.pos)
	else
		part.facing = (part.facing + 1) % 4
		if part.model then
			part.model:PivotTo(CFrame.new(part.pos) * CFrame.Angles(0, part.facing * math.pi / 2, 0))
			part.model:SetAttribute("Facing", part.facing)
		end
		Net.fire(player, "Sfx", "mine", part.pos)
	end
	local done = 0
	for _, p in puzzle.parts do
		if (puzzle.kind == "lanterns" and p.lit) or (puzzle.kind == "totems" and p.facing == 0) then
			done += 1
		end
	end
	fxTo(island.plot, "puzzle", { pos = part.pos, done = done, total = #puzzle.parts })
	if done == #puzzle.parts then
		puzzle.solved = true
		local m = OceanModels.prop("container", puzzle.chestPos, rng, island.built.model)
		m:SetAttribute("Chest", true)
		local c = { id = 9000 + island.plot, kind = "chest", pos = puzzle.chestPos, model = m }
		m:SetAttribute("ContainerId", c.id)
		island.containers[c.id] = c
		prompt(m, "container", "Open", "Chest", c.id, Constants.CONTAINER_SEARCH)
		local here = players:PlayersOnPlot(island.plot)
		for _, p in here do
			Net.fire(
				p,
				"Callout",
				puzzle.kind == "lanterns" and "💡 The hollow gives up its secret: a chest appeared!"
					or "💡 The totems face the sea. A chest rose from the ground!",
				"good"
			)
			Net.fire(p, "Sfx", "discover")
		end
		fxTo(island.plot, "discover", { pos = puzzle.chestPos })
		self.Solved:Fire(island.plot, island, here)
	end
	self:Push(island.plot)
	return true
end

-- Prompts --------------------------------------------------------------------------------------------------------------
function IslandService:_prompt(p, player)
	local kind = p:GetAttribute("Kind")
	if kind ~= "container" and kind ~= "puzzle" and kind ~= "landmark" and kind ~= "bush" then
		return
	end
	local plot = players:Here(player)
	local island = plot and islands[plot]
	if not island or not players:IsAlive(player) then
		return
	end
	local id = p:GetAttribute("Id")
	if kind == "container" then
		self:Search(player, island, id)
	elseif kind == "puzzle" then
		self:Puzzle(player, island, id)
	elseif kind == "landmark" then
		self:Look(player, island)
	elseif kind == "bush" then
		self:Pick(player, island, id)
	end
end

function IslandService:_tick()
	for plot, island in islands do
		if #island.built.hazards == 0 then
			continue
		end
		for _, player in players:PlayersOnPlot(plot) do
			local pos = players:Position(player)
			if pos and players:IsAlive(player) then
				for _, h in island.built.hazards do
					if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(h.pos.X, 0, h.pos.Z)).Magnitude <= h.radius then
						players:Damage(player, 4, { kind = "lava" })
						self.Burned:Fire(player)
						break
					end
				end
			end
		end
	end
end

function IslandService:Init(reg)
	registry = reg
	rafts = reg.RaftService
	inventory = reg.InventoryService
	players = reg.PlayerService
	loot = reg.LootService
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(p, player)
			self:_prompt(p, player)
		end)
	end)
	players.Moved:Connect(function(player, _, plot)
		Net.fire(player, "Island", plot and self:View(plot) or false)
	end)
	rafts.Released:Connect(function(_, raft)
		self:Leave(raft.plot)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastHint[player] = nil
	end)
end

function IslandService:Start()
	while true do
		task.wait(0.5)
		self:_tick()
	end
end

-- (tests)
function IslandService:_islands()
	return islands
end
_ = Voyages
return IslandService

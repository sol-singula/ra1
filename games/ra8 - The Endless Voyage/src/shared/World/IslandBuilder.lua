--[[
The islands and wrecks (master plan §9: each one a place with a reason to go, a landmark, something to gather,
something to find, something that lives there). Built beside a plot when a voyage arrives and taken down when it
sails home: terrain for the land (stacked cylinders of sand, grass, rock, snow or basalt) and plain-part props
from OceanModels and Kit on top.

  IslandBuilder.build(template, center, rng, parent) -> built
    built.nodes        { { id, kind, tool, pos, model, hp, gives = { { key, n }, ... } }, ... } trees, rocks, ore,
                       crystals, salvage piles, old machines (and bushes: a prompt, no tool)
    built.containers   { { id, kind = "container" | "locker" | "chest", pos, model }, ... }
    built.puzzle       { kind = "lanterns" | "totems", parts = { { id, pos, model } }, chestPos } or nil
    built.landmark     { pos, model, text }
    built.spawns       { { kind, pos }, ... } creatures
    built.hazards      { { kind = "lava", pos, radius }, ... }
    built.ground(x, z) -> y   the land's height there (nil: water)
  IslandBuilder.remove(built)   the land goes back under the water
]]
local Constants = require(script.Parent.Parent.Constants)
local Kit = require(script.Parent.Kit)
local OceanModels = require(script.Parent.OceanModels)

local IslandBuilder = {}

-- Big things show from far away: the trees, rocks, wrecks, huts, chests and the landmark stream in whole and stay
-- (Roblox's Persistent models), so an island reads as an island from the raft and across the water; small plants
-- stream in as you come near.
local function keep(m)
	if m and m:IsA("Model") then
		pcall(function()
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
	end
	return m
end

local C, M = Kit.C, Kit.M
local V3 = Vector3.new
local WATER = Constants.WATER_LEVEL

-- The land: a stack of cylinders, widest at the water, each { radius share, top height, material }.
local TEMPLATES = {
	tropical = {
		radius = 46,
		layers = { { 1, 1.6, "Sand" }, { 0.78, 3.4, "Grass" }, { 0.55, 5.4, "Grass" }, { 0.3, 7.2, "Grass" } },
		trees = { n = 9, kind = "palm", gives = { { "wood", 3 }, { "palm", 2 } }, extra = { "coconut", 1, 0.6 } },
		bushes = 4,
		rocks = { n = 2, kind = "rock", gives = { { "stone", 3 } } },
		containers = { n = 2, kind = "container" },
		landmark = {
			prop = "campfire",
			text = "An old campfire, and a note under a stone: 'Took the rowboat for the wreck to the east. The Drifter. If it's still afloat, it's full of metal.'",
		},
		spawns = { { "reef_crab", 3 } },
		seats = 1,
	},
	rocky = {
		radius = 40,
		layers = { { 1, 1.4, "Sand" }, { 0.8, 3.6, "Rock" }, { 0.55, 6.5, "Rock" }, { 0.3, 10.5, "Rock" } },
		rocks = { n = 6, kind = "rock", gives = { { "stone", 3 } } },
		ore = { n = 4 },
		salvage = { n = 2, gives = { { "scrap", 3 }, { "metal", 1 } } },
		containers = { n = 2, kind = "container" },
		landmark = {
			prop = "lantern_post",
			text = "A rusted beacon. Someone kept its lamp filled for years. Scratched into the post: 'Fog to the north. Light three and the hollow lets you in.'",
		},
		spawns = { { "gull", 2 }, { "reef_crab", 2 } },
	},
	surface_wreck = {
		radius = 22,
		layers = { { 1, 1, "Sand" } },
		hull = true,
		salvage = { n = 5, gives = { { "scrap", 3 }, { "metal", 2 } } },
		containers = { n = 3, kind = "locker" },
		landmark = {
			prop = "seat_rock",
			text = "The captain's cabin, on its side. A chart case, empty. On the wall, a drawing of something with a mouth as wide as the ship.",
		},
		spawns = { { "reef_crab", 1 } },
	},
	foggy = {
		radius = 50,
		layers = { { 1, 1.2, "Mud" }, { 0.85, 2.4, "Grass" }, { 0.5, 3.6, "Grass" } },
		trees = { n = 5, kind = "dead", gives = { { "wood", 3 } } },
		reeds = 8,
		huts = 3,
		containers = { n = 3, kind = "container" },
		puzzle = "lanterns",
		landmark = {
			prop = "hut",
			text = "Huts nobody left in a hurry: the pots are still on the fires. The reeds move when nothing's there.",
		},
		spawns = { { "mire_lurker", 2 } },
	},
	volcanic = {
		radius = 44,
		layers = { { 1, 1.4, "Basalt" }, { 0.8, 4, "Basalt" }, { 0.55, 7.5, "Basalt" }, { 0.3, 11.5, "CrackedLava" } },
		rocks = { n = 3, kind = "rock", gives = { { "stone", 3 } } },
		ore = { n = 3 },
		crystals = { n = 4, item = "heat_crystal", color = Color3.fromRGB(255, 120, 50) },
		lava = 3,
		containers = { n = 2, kind = "container" },
		landmark = {
			prop = "seat_rock",
			text = "A cave that breathes warm air. The walls glow. Deeper in, something has been digging the crystals out with claws.",
		},
		spawns = { { "lava_beetle", 3 } },
	},
	frozen = {
		radius = 46,
		layers = { { 1, 1.4, "Snow" }, { 0.8, 3.4, "Snow" }, { 0.55, 5.4, "Glacier" }, { 0.3, 7.2, "Glacier" } },
		ice = { n = 6 },
		crystals = { n = 3, item = "frost_crystal", color = Color3.fromRGB(150, 220, 255) },
		ore = { n = 2 },
		containers = { n = 2, kind = "container" },
		hull = true,
		landmark = {
			prop = "seat_rock",
			text = "A ship frozen into the ice, its name worn off. In the hold, the wolves' den, and bones that aren't theirs.",
		},
		spawns = { { "frost_wolf", 3 } },
	},
	deep_wreck = {
		radius = 30,
		layers = { { 1, 1.2, "Sand" }, { 0.7, 2.6, "Sand" } },
		hull = true,
		bigHull = true,
		salvage = { n = 6, gives = { { "metal", 2 }, { "scrap", 2 } }, extra = { "gear", 1, 0.3 } },
		machines = { n = 2 },
		containers = { n = 4, kind = "locker" },
		landmark = {
			prop = "seat_rock",
			text = "A hidden room behind the galley. A logbook on the table, open at the last page: 'It followed us from the Trench. It is still following.'",
		},
		spawns = { { "mire_lurker", 2 } },
	},
	ruin = {
		radius = 48,
		layers = { { 1, 1.4, "Sand" }, { 0.85, 3.2, "Grass" }, { 0.6, 5.6, "Ground" }, { 0.35, 8.6, "Ground" } },
		trees = { n = 4, kind = "toon", gives = { { "wood", 3 } } },
		rocks = { n = 3, kind = "rock", gives = { { "stone", 3 } } },
		walls = 6,
		machines = { n = 3 },
		containers = { n = 2, kind = "chest" },
		puzzle = "totems",
		landmark = {
			prop = "ruin_wall",
			text = "Three totems that face the wrong way. Whoever built this place wanted them watching the sea. Something still does.",
		},
		spawns = { { "ruin_guardian", 1 }, { "mire_lurker", 2 } },
	},
	trench = {
		radius = 0,
		layers = {},
		pillars = 5,
		landmark = nil,
		spawns = { { "leviathan", 1 } },
	},
}
IslandBuilder.TEMPLATES = TEMPLATES

-- Props the nodes use.
local NODE_PROP = {
	rock = "rock",
	ore = "ore_rock",
	crystal = "crystal_rock",
	salvage = "salvage",
	machine = "old_machine",
	ice = "ice_block",
}

local function layered(t, center)
	-- the land's height at a point from the layers (nil: water)
	return function(x, z)
		local d = V3(x - center.X, 0, z - center.Z).Magnitude
		local y
		for _, layer in t.layers do
			if d <= layer[1] * t.radius then
				y = WATER + layer[2]
			end
		end
		return y
	end
end

-- A spot on the land: at `share` of the radius (0 = the middle, 1 = the shore), any angle, on the ground.
local function spot(t, center, ground, rng, shareMin, shareMax)
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(shareMin, shareMax) * t.radius
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local y = ground(x, z)
		if y then
			return V3(x, y, z)
		end
	end
	local y = ground(center.X, center.Z) or WATER + 1
	return V3(center.X, y, center.Z)
end

-- Spots spread round the island (so props don't pile up): n of them between the shares.
local function ring(t, center, ground, rng, n, shareMin, shareMax, offset)
	local out = {}
	for i = 1, n do
		local a = (offset or 0) + (i - 1) / n * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local r = rng:NextNumber(shareMin, shareMax) * t.radius
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local y = ground(x, z)
		if y then
			table.insert(out, V3(x, y, z))
		end
	end
	return out
end

function IslandBuilder.build(template, center, rng, parent)
	local t = TEMPLATES[template]
	assert(t, `unknown island template {template}`)
	rng = rng or Random.new()
	local model = Instance.new("Model")
	model.Name = "Island_" .. template
	model:SetAttribute("Template", template)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	local built = {
		template = template,
		center = center,
		radius = t.radius,
		model = model,
		nodes = {},
		containers = {},
		puzzle = nil,
		landmark = nil,
		spawns = {},
		hazards = {},
		top = WATER + 2,
	}
	-- the land
	for _, layer in t.layers do
		local r, top, mat = layer[1] * t.radius, WATER + layer[2], layer[3]
		built.top = math.max(built.top, top)
		built.clear = math.max(built.clear or 0, r) -- the widest layer: what leaving must wash away
		if terrain then
			local bottom = Constants.SEA_FLOOR + 4
			local h = top - bottom
			pcall(function()
				terrain:FillCylinder(CFrame.new(center.X, bottom + h / 2, center.Z), h, r, Enum.Material[mat])
			end)
		end
	end
	local ground = layered(t, center)
	built.ground = ground
	local nextId = 0
	local function id()
		nextId += 1
		return nextId
	end
	local function node(kind, tool, pos, prop, gives, extra, hp)
		local m
		if prop then
			m = OceanModels.prop(prop, pos, rng, model, extra)
		end
		local n = {
			id = id(),
			kind = kind,
			tool = tool,
			pos = pos,
			model = m,
			hp = hp or (tool == "axe" and Constants.TREE_HP or Constants.ROCK_HP),
			gives = gives,
		}
		if m then
			m:SetAttribute("NodeId", n.id)
			m:SetAttribute("Tool", tool or "")
			if kind ~= "bush" then
				keep(m)
			end
		end
		table.insert(built.nodes, n)
		return n
	end
	local function gives(list, extra)
		local out = {}
		for _, g in list or {} do
			table.insert(out, { key = g[1], n = g[2] })
		end
		if extra and rng:NextNumber() < extra[3] then
			table.insert(out, { key = extra[1], n = extra[2] })
		end
		return out
	end
	-- trees
	if t.trees then
		for _, pos in ring(t, center, ground, rng, t.trees.n, 0.35, 0.8) do
			local n =
				node("tree", "axe", pos, t.trees.kind == "palm" and "palm" or nil, gives(t.trees.gives, t.trees.extra))
			if t.trees.kind == "dead" then
				n.model = Kit.deadTree(model, pos, rng:NextNumber(8, 12), rng)
			elseif t.trees.kind == "toon" then
				n.model = Kit.toonTree(model, pos, rng:NextNumber(14, 20), rng)
			end
			if n.model then
				n.model:SetAttribute("NodeId", n.id)
				n.model:SetAttribute("Tool", "axe")
				keep(n.model)
			end
		end
	end
	if t.bushes then
		for _, pos in ring(t, center, ground, rng, t.bushes, 0.3, 0.7, 0.4) do
			local n = node("bush", nil, pos, "plant", { { key = "berries", n = 2 }, { key = "fiber", n = 2 } }, nil, 1)
			_ = n
		end
	end
	if t.reeds then
		for _, pos in ring(t, center, ground, rng, t.reeds, 0.5, 0.95, 0.2) do
			node("bush", nil, pos, "plant", { { key = "fiber", n = 2 } }, nil, 1)
		end
	end
	if t.rocks then
		for _, pos in ring(t, center, ground, rng, t.rocks.n, 0.2, 0.75, 1.1) do
			node("rock", "pick", pos, "rock", gives(t.rocks.gives))
		end
	end
	if t.ore then
		for _, pos in ring(t, center, ground, rng, t.ore.n, 0.15, 0.6, 2.2) do
			node("ore", "pick", pos, "ore_rock", { { key = "ore", n = 2 }, { key = "stone", n = 1 } })
		end
	end
	if t.crystals then
		for _, pos in ring(t, center, ground, rng, t.crystals.n, 0.1, 0.5, 0.9) do
			node("crystal", "pick", pos, "crystal_rock", { { key = t.crystals.item, n = 2 } }, t.crystals.color)
		end
	end
	if t.ice then
		for _, pos in ring(t, center, ground, rng, t.ice.n, 0.3, 0.85, 1.7) do
			node(
				"ice",
				"pick",
				pos,
				"ice_block",
				rng:NextNumber() < 0.4 and { { key = "frost_crystal", n = 1 }, { key = "stone", n = 1 } }
					or { { key = "stone", n = 2 } }
			)
		end
	end
	if t.salvage then
		for _, pos in ring(t, center, ground, rng, t.salvage.n, 0.2, 0.8, 0.6) do
			node("salvage", "pry", pos, "salvage", gives(t.salvage.gives, t.salvage.extra))
		end
	end
	if t.machines then
		for _, pos in ring(t, center, ground, rng, t.machines.n, 0.1, 0.5, 2.8) do
			node(
				"machine",
				"pry",
				pos,
				"old_machine",
				{ { key = "old_tech", n = 1 }, { key = "gear", n = 1 }, { key = "scrap", n = 2 } },
				nil,
				Constants.ROCK_HP * 1.5
			)
		end
	end
	-- the set dressing
	if t.hull then
		local pos = V3(center.X, WATER + 0.5, center.Z) + V3(0, 0, t.bigHull and 0 or 6)
		local hull = keep(OceanModels.prop("wreck_hull", pos, rng, model, t.bigHull))
		hull:SetAttribute("Hull", true)
	end
	if t.huts then
		for _, pos in ring(t, center, ground, rng, t.huts, 0.25, 0.6, 1.5) do
			keep(OceanModels.prop("hut", pos, rng, model))
		end
	end
	if t.walls then
		for _, pos in ring(t, center, ground, rng, t.walls, 0.3, 0.7, 0.3) do
			keep(OceanModels.prop("ruin_wall", pos, rng, model))
		end
	end
	if t.lava then
		for _, pos in ring(t, center, ground, rng, t.lava, 0.15, 0.55, 1.9) do
			OceanModels.prop("lava_pool", pos, rng, model)
			table.insert(built.hazards, { kind = "lava", pos = pos, radius = 4.5 })
		end
	end
	if t.seats then
		for _, pos in ring(t, center, ground, rng, t.seats, 0.8, 0.95, 2) do
			keep(OceanModels.prop("seat_rock", pos, rng, model))
		end
	end
	if t.pillars then
		for i = 1, t.pillars do
			local a = i / t.pillars * math.pi * 2
			local pos = center + V3(math.cos(a) * 34, Constants.SEA_FLOOR + 6, math.sin(a) * 34)
			Kit.box(
				model,
				"Pillar",
				CFrame.new(pos) * CFrame.Angles(0, a, 0.08),
				V3(5, 22, 5),
				C.rockDark,
				M.Slate,
				{ CanCollide = false }
			)
		end
	end
	-- containers
	if t.containers then
		for _, pos in ring(t, center, ground, rng, t.containers.n, 0.2, 0.7, 2.5) do
			local kind = t.containers.kind
			local prop = kind == "locker" and "locker" or "container"
			local m = keep(OceanModels.prop(prop, pos, rng, model))
			local c = { id = id(), kind = kind, pos = pos, model = m }
			m:SetAttribute("ContainerId", c.id)
			table.insert(built.containers, c)
		end
	end
	-- the puzzle
	if t.puzzle then
		local parts = {}
		for _, pos in ring(t, center, ground, rng, 3, 0.4, 0.6, 0.8) do
			local m = keep(OceanModels.prop(t.puzzle == "lanterns" and "lantern_post" or "totem", pos, rng, model))
			local part = { id = id(), pos = pos, model = m, lit = false, facing = rng:NextInteger(1, 3) }
			m:SetAttribute("PuzzleId", part.id)
			if t.puzzle == "totems" then
				m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, part.facing * math.pi / 2, 0))
			end
			table.insert(parts, part)
		end
		built.puzzle = { kind = t.puzzle, parts = parts, chestPos = spot(t, center, ground, rng, 0.05, 0.2) }
	end
	-- the landmark
	if t.landmark then
		local pos = spot(t, center, ground, rng, 0.05, 0.25)
		local m = keep(OceanModels.prop(t.landmark.prop, pos, rng, model))
		m:SetAttribute("Landmark", true)
		built.landmark = { pos = pos, model = m, text = t.landmark.text }
	end
	-- who lives here
	for _, s in t.spawns or {} do
		local kind, n = s[1], s[2]
		if kind == "leviathan" then
			table.insert(built.spawns, { kind = kind, pos = V3(center.X, WATER - 6, center.Z) })
		else
			for _, pos in ring(t, center, ground, rng, n, 0.5, 0.85, rng:NextNumber(0, 6)) do
				table.insert(built.spawns, { kind = kind, pos = pos + V3(0, 1, 0) })
			end
		end
	end
	model.Parent = parent or workspace
	return built
end

-- The land goes back under the sea.
function IslandBuilder.remove(built)
	if built.model then
		built.model:Destroy()
		built.model = nil
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and built.radius > 0 then
		local c = built.center
		local r = math.max(built.radius, built.clear or 0) + 10
		pcall(function()
			local depth = WATER - (Constants.SEA_FLOOR + 2)
			terrain:FillCylinder(
				CFrame.new(c.X, Constants.SEA_FLOOR + 2 + depth / 2, c.Z),
				depth,
				r,
				Enum.Material.Water
			)
			local above = built.top + 4 - WATER
			terrain:FillCylinder(CFrame.new(c.X, WATER + above / 2, c.Z), above, r, Enum.Material.Air)
		end)
	end
end

IslandBuilder.NODE_PROP = NODE_PROP
return IslandBuilder

--[[
Builds the world once at start-up (the camp's structures, the findings, the loot and the resource nodes come and
go with each run: CampService, WorldService, LootService, ResourceService):

  the land        TerrainBuilder (smooth terrain from MapLayout.floorY)
  the forest      every tree from MapLayout.trees(), in 128-stud chunks that stream in whole and show as simple
                  meshes from far away (§11: level of detail), with ferns, mushrooms, pebbles, fallen logs and
                  stumps round them
  the camp        the fire, log seats, the Camp Board, the bell, the four difficulty stones, tents; the Ancient
                  Pines round the clearing
  the rest        log bridges over the creek, lily pads and a dock on the pond, boulders on the outcrops, the
                  invisible walls at the edge

  MapBuilder.build()              everything above (once)
  MapBuilder.tree(id) -> model    a tree's model (nil once it's been felled)
  MapBuilder.camp                 { fire, board, bell, stones = { ... }, pines = { [id] = { model, rune } } }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampModels = require(ReplicatedStorage.Shared.World.CampModels)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local MapBuilder = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new
local CHUNK = 128

local trees = {} -- [treeId] = model
MapBuilder.camp = nil

function MapBuilder.tree(id)
	local m = trees[id]
	if m and m.Parent then
		return m
	end
	return nil
end

function MapBuilder.forgetTree(id)
	trees[id] = nil
end

local function folder(name, parent)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local chunks = {}
local function chunkFor(parent, x, z)
	local cx, cz = math.floor(x / CHUNK), math.floor(z / CHUNK)
	local key = cx .. "_" .. cz
	local m = chunks[key]
	if not m then
		m = Instance.new("Model")
		m.Name = "Chunk_" .. key
		pcall(function()
			m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
		end)
		m.Parent = parent
		chunks[key] = m
	end
	return m
end

-- One tree, rebuilt at the start of every run if it was felled (ResourceService).
function MapBuilder.plantTree(t)
	local map = workspace:FindFirstChild("Map")
	local forest = map and map:FindFirstChild("Forest")
	if not forest then
		return nil
	end
	local old = trees[t.id]
	if old and old.Parent then
		return old
	end
	local m = Kit.tree(chunkFor(forest, t.x, t.z), t)
	trees[t.id] = m
	return m
end

local function buildForest(map)
	local forest = folder("Forest", map)
	local ground = folder("Ground", map)
	local rng = Random.new(2024)
	for _, t in MapLayout.trees() do
		trees[t.id] = Kit.tree(chunkFor(forest, t.x, t.z), t)
		-- the forest floor round the trunks
		local roll = rng:NextNumber()
		local a = rng:NextNumber(0, math.pi * 2)
		local d = t.trunk + rng:NextNumber(2, 5)
		local x, z = t.x + math.cos(a) * d, t.z + math.sin(a) * d
		if t.reachable and MapLayout.clearOf(x, z, -2) then
			local pos = V3(x, MapLayout.floorY(x, z), z)
			local into = chunkFor(ground, x, z)
			if roll < 0.28 then
				Kit.fern(into, pos, rng)
			elseif roll < 0.36 then
				Kit.mushrooms(into, pos, rng, MapLayout.zoneAt(x, z) == "deep" and rng:NextNumber() < 0.5)
			elseif roll < 0.44 then
				Kit.pebble(into, pos, rng)
			elseif roll < 0.5 then
				Kit.bush(into, pos, rng:NextNumber(2.4, 3.6), rng, C.leafDark)
			end
		end
	end
	-- fallen logs and stumps between the trees
	local placed = 0
	local tries = 0
	while placed < 120 and tries < 3000 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(90 ^ 2, (MapLayout.WORLD_RADIUS - 15) ^ 2))
		local x, z = math.cos(a) * r, math.sin(a) * r
		if MapLayout.clearOf(x, z, 4) then
			local pos = V3(x, MapLayout.floorY(x, z), z)
			local into = chunkFor(ground, x, z)
			if placed % 2 == 0 then
				Kit.fallenLog(into, pos, rng:NextNumber(8, 14), rng)
			else
				Kit.stump(into, pos, rng)
			end
			placed += 1
		end
	end
end

local function buildCamp(map)
	local camp = Instance.new("Model")
	camp.Name = "Camp"
	pcall(function()
		camp.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	camp.Parent = map
	local P = MapLayout.CAMP_PROPS
	local y = MapLayout.CAMP.y
	local out = { stones = {}, pines = {} }
	out.fireModel = CampModels.build("fire", CFrame.new(P.fire), { parent = camp, name = "Campfire", tier = 1 })
	out.fire = out.fireModel
	for i, pos in P.logs do
		CampModels.build("seat", CFrame.lookAt(pos, V3(0, y, 0)) * CFrame.Angles(0, math.rad(90), 0), {
			parent = camp,
			name = "Seat" .. i,
		})
	end
	local boardModel = CampModels.build("board", CFrame.lookAt(P.board, V3(0, y, 0)) * CFrame.Angles(0, math.pi, 0), {
		parent = camp,
		name = "CampBoard",
	})
	out.board = boardModel
	out.bell = CampModels.build("bell", CFrame.lookAt(P.bell, V3(0, y, 0)), { parent = camp, name = "Bell" })
	local glyphs = { "🌲", "💀", "😈", "👑" }
	for i, pos in P.stones do
		local m = CampModels.build("stone", CFrame.lookAt(pos, V3(0, y, 0)) * CFrame.Angles(0, math.pi, 0), {
			parent = camp,
			name = "Stone" .. i,
			text = glyphs[i],
		})
		m:SetAttribute("Difficulty", i)
		out.stones[i] = m
	end
	local tentColors = { C.canvas, C.canvasGreen, C.canvasRed }
	for i, t in P.tents do
		CampModels.build("tent", CFrame.lookAt(t.pos, V3(0, y, 0)) * CFrame.Angles(0, math.pi, 0), {
			parent = camp,
			name = "Tent" .. i,
			color = tentColors[i],
		})
	end
	-- flowers and a few rocks in the clearing round the camp
	local rng = Random.new(99)
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(50, 74)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if MapLayout.trailDistance(x, z) > 6 then
			Kit.flowers(camp, V3(x, MapLayout.floorY(x, z), z), rng, 4)
		end
	end
	-- the Ancient Pines
	local pines = Instance.new("Model")
	pines.Name = "AncientPines"
	pines.Parent = map
	for _, p in MapLayout.ancientPines do
		local m, rune = Kit.ancientPine(pines, p.pos, p.id * 17)
		m.Name = "AncientPine" .. p.id
		m:SetAttribute("PineId", p.id)
		out.pines[p.id] = { model = m, rune = rune }
	end
	-- a fallen log across the clearing's edge by each gate: something to jump over in the first minute (§4)
	for i, a in MapLayout.GATE_ANGLES do
		local p = MapLayout.polar(a + 16, 58)
		Kit.fallenLog(camp, V3(p.X, MapLayout.floorY(p.X, p.Z), p.Z), 9, Random.new(i * 7))
	end
	return out
end

local function buildBridges(map)
	local f = folder("Bridges", map)
	for i, b in MapLayout.bridges do
		local m = Kit.model("Bridge" .. i, f)
		local center = V3(b.x, b.y, b.z)
		local cf = CFrame.lookAt(center, center + b.dir)
		local len = b.halfLen * 2
		for k = -1, 1 do
			Kit.cyl(
				m,
				"Log",
				cf * CFrame.new(k * 2.2, -0.5, 0) * CFrame.Angles(0, math.rad(90), 0),
				len,
				2.2,
				C.bark:Lerp(C.woodDark, (k + 1) * 0.15),
				M.Wood
			)
		end
		Kit.box(m, "Deck", cf * CFrame.new(0, 0.55, 0), V3(b.halfWidth * 2, 0.4, len - 1), C.plank, M.WoodPlanks)
		for _, side in { -1, 1 } do
			Kit.box(
				m,
				"Rail",
				cf * CFrame.new(side * (b.halfWidth + 0.2), 2, 0),
				V3(0.35, 0.35, len - 2),
				C.woodDark,
				M.Wood,
				{ CastShadow = false }
			)
			for z = -len / 2 + 2, len / 2 - 2, 6 do
				Kit.box(
					m,
					"Post",
					cf * CFrame.new(side * (b.halfWidth + 0.2), 1.2, z),
					V3(0.4, 2, 0.4),
					C.woodDark,
					M.Wood,
					{
						CastShadow = false,
					}
				)
			end
		end
	end
end

local function buildPond(map)
	local P = MapLayout.POND
	local m = Kit.model("Pond", map)
	local rng = Random.new(11)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(4, P.radius - 6)
		Kit.disc(
			m,
			"LilyPad",
			V3(P.x + math.cos(a) * r, P.water + 0.05, P.z + math.sin(a) * r),
			rng:NextNumber(1.6, 2.8),
			0.1,
			C.leafDark,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = P.radius + rng:NextNumber(-1, 2)
		local base = V3(P.x + math.cos(a) * r, 0, P.z + math.sin(a) * r)
		base = V3(base.X, MapLayout.floorY(base.X, base.Z), base.Z)
		for k = 1, 3 do
			Kit.box(
				m,
				"Reed",
				CFrame.new(base + V3(k * 0.4, 1.4, 0))
					* CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)),
				V3(0.15, 2.8, 0.15),
				C.fern,
				M.Grass,
				{ CanCollide = false, CastShadow = false }
			)
		end
	end
	-- a little dock on the camp side
	local dir = (V3(0, 0, 0) - V3(P.x, 0, P.z)).Unit
	local start = V3(P.x, 0, P.z) + dir * (P.radius - 9)
	local dock = CFrame.lookAt(start + V3(0, 0.7, 0), start + dir * 10 + V3(0, 0.7, 0))
	Kit.box(m, "Dock", dock * CFrame.new(0, 0, -5), V3(4, 0.5, 12), C.plank, M.WoodPlanks)
	for _, z in { -1, -6, -10 } do
		for _, x in { -1.7, 1.7 } do
			Kit.box(
				m,
				"Pile",
				dock * CFrame.new(x, -1.6, z),
				V3(0.6, 4, 0.6),
				C.woodDark,
				M.Wood,
				{ CastShadow = false }
			)
		end
	end
end

local function buildOutcrops(map)
	local f = folder("Outcrops", map)
	local rng = Random.new(31)
	for _, o in MapLayout.OUTCROPS do
		for _ = 1, 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, o.r * 0.6)
			local x, z = o.x + math.cos(a) * r, o.z + math.sin(a) * r
			Kit.boulder(f, V3(x, MapLayout.floorY(x, z) - 0.6, z), rng:NextNumber(4, 9), rng, C.rock, M.Rock)
		end
	end
end

local function buildBoundary(map)
	local f = folder("Boundary", map)
	local R = MapLayout.WALL_RADIUS
	local n = 72
	local w = 2 * math.pi * R / n + 2
	for k = 0, n - 1 do
		local a = (k + 0.5) / n * math.pi * 2
		local p = V3(math.cos(a) * R, 60, math.sin(a) * R)
		Kit.wall(f, CFrame.lookAt(p, V3(0, 60, 0)), V3(w, 220, 4))
	end
end

function MapBuilder.build()
	TerrainBuilder.build()
	local map = folder("Map", workspace)
	buildForest(map)
	MapBuilder.camp = buildCamp(map)
	buildBridges(map)
	buildPond(map)
	buildOutcrops(map)
	buildBoundary(map)
	for _, name in { "Structures", "Findings", "Nodes", "Loot", "Drops", "Traps" } do
		folder(name, workspace)
	end
	LightingPresets.apply("day")
	return map
end

return MapBuilder

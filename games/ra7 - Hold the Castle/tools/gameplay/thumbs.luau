--[[
Store thumbnails and screenshots (master plan §25: the castle, the monster army, the dwarves at the gate; three
versions: building, attack, last stand). Staged scenes made from the game's own models (the map, castle pieces,
the dwarf and monster costumes, the effects' shapes), posed by hand, with no UI. Snapshots are marked cinematic so
render.js also writes a depth pass, and thumbs_post.py adds the "shader" look and the title.

  luaurun tools/gameplay/thumbs.luau <outDir> [only]      (from the game folder)
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules>
  python3 tools/gameplay/thumbs_post.py <renderDir> <thumbDir> --font LuckiestGuy.ttf
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local rgb = Engine.globals.Color3.fromRGB
local Instance = Engine.Instance
local Random = Engine.globals.Random
local Enum = Engine.Enum
local outDir = ARGS[1] or "thumbs"
local only = ARGS[2]

local tree = Engine.mountProject(".")
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local PieceModels = Engine.require(tree.shared.World.PieceModels)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local Costumes = Engine.require(tree.shared.World.Costumes)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local Looks = Engine.require(tree.shared.Data.Looks)
local Kit = Engine.require(tree.shared.World.Kit)
local C, M = Kit.C, Kit.M
local ws = Engine.workspace

MapBuilder.build()
for _, n in MapLayout.nodes do
	local m = MapBuilder.nodeModel(n, ws.Nodes)
	m:SetAttribute("NodeId", n.id)
end
-- the shrine labels are for players, not pictures
for _, d in ws.Map:GetDescendants() do
	if d.ClassName == "BillboardGui" then
		d.Enabled = false
	end
end
-- the hangout deck sits on the ridge behind most shots: not part of the match
local hangoutDeck = ws.Map:FindFirstChild("Hangout")
if hangoutDeck then
	hangoutDeck:Destroy()
end
local npcFolder = Instance.new("Folder", ws)
npcFolder.Name = "Npcs"
local fxFolder = Instance.new("Folder", ws)
fxFolder.Name = "Fx"
local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer

local rng = Random.new(25)
local function clear()
	for _, f in { ws.Castle, npcFolder, fxFolder } do
		for _, c in f:GetChildren() do
			c:Destroy()
		end
	end
end

-- Castle pieces: built, rising out of the ground (with the blue blueprint box), or a plan only -----------------
local function place(key, i, j, rot, opts)
	opts = opts or {}
	local def = Pieces.byKey[key]
	local w, d = Pieces.cells(def, rot)
	local cx, cz = (i + w / 2) * MapLayout.CELL, (j + d / 2) * MapLayout.CELL
	local cf = PieceModels.frame(def, i, j, rot, MapLayout.groundY(cx, cz))
	local progress = opts.progress or 1
	local m = PieceModels.build(key, cf, { upgraded = opts.upgraded, flag = opts.flag, parent = ws.Castle })
	if progress < 1 then
		local h = math.max(1, def.height)
		m:PivotTo(cf * CF.new(0, -(1 - progress) * (h + 0.2), 0))
		local hh = math.max(1.2, def.height)
		Kit.box(
			ws.Castle,
			"Blueprint",
			cf * CF.new(0, hh / 2, 0),
			V3.new(w * MapLayout.CELL, hh, d * MapLayout.CELL),
			C.blueprint,
			M.SmoothPlastic,
			{
				Transparency = 0.72,
				CanCollide = false,
				CastShadow = false,
			}
		)
	end
	return m, cf
end
local function starterCastle(skip)
	for _, b in MapLayout.starter do
		if not (skip and skip[b.key .. b.j]) then
			place(b.key, b.i, b.j, b.rot, { upgraded = b.key == "tower" })
		end
	end
end

-- People and monsters ------------------------------------------------------------------------------------------------
local SHIRTS = Costumes.DWARF_SHIRTS
local function npc(kind, pos, look, pose, facing)
	local n = Costumes.npc(kind, look or {}, npcFolder)
	local f = facing or V3.new(1, 0, 0)
	local root = CF.lookAt(pos, pos + V3.new(f.X, 0, f.Z))
	Costumes.place(n, root, pose or {})
	return n
end
local function ground(x, z, extra)
	return V3.new(x, MapLayout.groundY(x, z) + (extra or 0), z)
end
local ARMORS = { "royal", "iron", "golden", "emerald", "copper", "rose", "obsidian", "crystal" }
local BEARDS = { "ginger", "brown", "snow", "black", "gray", "goldBraid", "rainbow" }
local function dwarfLook(k, job)
	return {
		armor = Looks.byKey[ARMORS[(k - 1) % #ARMORS + 1]],
		beard = Looks.byKey[BEARDS[(k - 1) % #BEARDS + 1]],
		job = job,
		shirt = SHIRTS[(k - 1) % #SHIRTS + 1],
		weapon = k % 3 == 0 and Looks.byKey.goldTool or nil,
	}
end
local SKINS = { nil, nil, "toxic", nil, "frost", nil, "lava", nil, nil, "shadow", nil, "candy" }
local function monsterLook(k)
	local s = SKINS[(k - 1) % #SKINS + 1]
	return { skin = s and Looks.byKey[s] or nil }
end

-- Effects, made of the same shapes the client's effects use ----------------------------------------------------------
local function chunk(pos, size, color, material, shape, t)
	local p = Kit.box(
		fxFolder,
		"Fx",
		CF.new(pos) * CF.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
		size,
		color,
		material or M.SmoothPlastic,
		{
			CanCollide = false,
			CastShadow = false,
			Transparency = t or 0,
		}
	)
	if shape == "ball" then
		p.Shape = Enum.PartType.Ball
	end
	return p
end
local function sparks(pos, color, n, spread)
	for _ = 1, n or 8 do
		local s = rng:NextNumber(0.25, 0.6)
		chunk(
			pos + V3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 1), rng:NextNumber(-1, 1)) * (spread or 2),
			V3.new(s, s, s),
			color or C.gold,
			M.Neon
		)
	end
end
local function dust(pos, n, size, color)
	for _ = 1, n or 6 do
		local s = rng:NextNumber(0.6, 1.2) * (size or 2.5)
		chunk(
			pos + V3.new(rng:NextNumber(-2, 2), rng:NextNumber(0, 1.5), rng:NextNumber(-2, 2)),
			V3.new(s, s, s),
			color or C.cream,
			M.SmoothPlastic,
			"ball",
			0.35
		)
	end
end
local function arrow(from, to, k)
	local pos = from:Lerp(to, k) + V3.new(0, math.sin(k * math.pi) * (to - from).Magnitude * 0.04, 0)
	local ahead = from:Lerp(to, k + 0.03) + V3.new(0, math.sin((k + 0.03) * math.pi) * (to - from).Magnitude * 0.04, 0)
	local cf = CF.lookAt(pos, ahead)
	Kit.box(
		fxFolder,
		"Arrow",
		cf,
		V3.new(0.25, 0.25, 3.2),
		C.woodDark,
		M.Wood,
		{ CanCollide = false, CastShadow = false }
	)
	Kit.box(
		fxFolder,
		"Fletch",
		cf * CF.new(0, 0, 1.4),
		V3.new(0.7, 0.1, 0.6),
		C.white,
		M.SmoothPlastic,
		{ CanCollide = false, CastShadow = false }
	)
	Kit.box(
		fxFolder,
		"Tip",
		cf * CF.new(0, 0, -1.7),
		V3.new(0.35, 0.35, 0.4),
		C.steel,
		M.Metal,
		{ CanCollide = false, CastShadow = false }
	)
end
local function orb(pos, color, size)
	local p = chunk(pos, V3.new(size, size, size), color, M.Neon, "ball")
	local light = Instance.new("PointLight", p)
	light.Color = color
	light.Range = 14
	light.Brightness = 2
	return p
end
local function boom(pos, radius)
	chunk(pos, V3.new(radius, radius, radius), C.fire, M.Neon, "ball", 0.25)
	chunk(pos, V3.new(radius * 0.6, radius * 0.6, radius * 0.6), C.gold, M.Neon, "ball", 0.1)
	for _ = 1, 14 do
		local s = rng:NextNumber(0.6, 1.6)
		local dir = V3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
		chunk(
			pos + dir * rng:NextNumber(radius * 0.4, radius * 1.1),
			V3.new(s, s, s),
			({ C.castle, C.castleDark, C.stone, C.fire })[rng:NextInteger(1, 4)],
			M.SmoothPlastic
		)
	end
	dust(pos + V3.new(0, radius * 0.4, 0), 8, radius * 0.5, C.black:Lerp(C.rock, 0.55))
	local holder = chunk(pos, V3.new(0.5, 0.5, 0.5), C.fire, M.Neon, nil, 1)
	local light = Instance.new("PointLight", holder)
	light.Color = C.fire
	light.Range = 30
	light.Brightness = 4
end
local function torch(pos)
	local p = Kit.box(fxFolder, "Brazier", CF.new(pos), V3.new(1.6, 3, 1.6), C.woodDark, M.Wood, { CanCollide = false })
	Instance.new("Fire", p)
	local light = Instance.new("PointLight", p)
	light.Color = rgb(255, 150, 70)
	light.Range = 26
	light.Brightness = 3
	return p
end

-- Lighting for pictures: the game's presets, with the haze turned down for wide shots ---------------------------------
local function light(name, tweak)
	local p = table.clone(LightingPresets.list[name])
	p.atmosphere = table.clone(p.atmosphere)
	for k, v in tweak or {} do
		if k == "atmosphere" then
			for a, b in v do
				p.atmosphere[a] = b
			end
		else
			p[k] = v
		end
	end
	LightingPresets.apply(p)
end

local shots = {}
local function shot(name, camPos, camTarget, fov, focus)
	if only and not string.find(name, only, 1, true) then
		return
	end
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov or 50,
	})
	snap.title = name
	snap.cinematic = true
	snap.hideGui = true
	snap.viewport = { w = 1920, h = 1080, dpr = 1 }
	focus = focus or camTarget
	snap.focus = { focus.X, focus.Y, focus.Z }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
	print("shot", name, #snap.parts, "parts")
end

local WALL_X = MapLayout.starter[1].i * MapLayout.CELL -- the west wall's outer face (-244)
local Y = MapLayout.HILL.height

-- 1 BUILDING: a bright afternoon, the west wall going up, dwarves hammering and hauling stone -------------------------
do
	light("build", {
		clock = 16.2,
		brightness = 2.3,
		exposure = -0.2,
		ambient = rgb(92, 90, 104),
		outdoor = rgb(128, 128, 142),
		atmosphere = { density = 0.05, haze = 0.3, color = rgb(214, 228, 246) },
	})
	-- the plan: the gate and a tower done, the walls rising, a second tower just started
	place("gate", -61, -1, 1)
	place("stoneWall", -61, 1, 1, { progress = 0.8 })
	place("stoneWall", -61, 3, 1, { progress = 0.55 })
	place("stoneWall", -61, 5, 1, { progress = 0.3 })
	place("stoneWall", -61, 7, 1, { progress = 0.1 })
	place("stoneWall", -61, -3, 1)
	place("stoneWall", -61, -5, 1)
	place("stoneWall", -61, -7, 1, { progress = 0.7 })
	place("stoneWall", -61, -9, 1, { progress = 0.4 })
	place("tower", -62, -11, 0, { flag = Looks.byKey.dragon })
	place("spikes", -64, -4, 0, { progress = 0.5 })
	place("flag", -63, -2, 0, { flag = Looks.byKey.crown })
	-- hammering at the rising walls from outside (facing east)
	local k = 0
	local function dwarf(x, z, facing, job, pose)
		k += 1
		return npc(
			"dwarf",
			ground(x, z),
			dwarfLook(k, job or "builder"),
			pose or { swing = 0.62 },
			facing or V3.new(1, 0, 0)
		)
	end
	dwarf(-247.6, 6.5, nil, "builder", { swing = 0.62 })
	sparks(V3.new(-244.4, Y + 7.6, 6.5), C.gold, 10, 1.4)
	dwarf(-247.8, 14, nil, "builder", { swing = 0.35 })
	dwarf(-247.6, 21.5, nil, "miner", { swing = 0.68 })
	sparks(V3.new(-244.4, Y + 3.2, 21.5), rgb(255, 120, 170), 9, 1.4) -- the Hearts build effect
	dust(V3.new(-245, Y + 0.4, 21), 3, 1.4)
	dwarf(-247.4, 29.5, nil, "builder", { swing = 0.55 })
	sparks(V3.new(-244.4, Y + 1.6, 29.5), C.gold, 7, 1.3)
	dwarf(-248, -30, nil, "fighter", { swing = 0.6 })
	sparks(V3.new(-244.4, Y + 4.6, -30), C.gold, 7, 1.3)
	dwarf(-249, 38, V3.new(1, 0, -0.2), "builder", { swing = 0.45 })
	-- hauling stone up the west road
	dwarf(-262, 3, V3.new(1, 0, 0.15), "miner", { carry = true, walk = 1.2, stride = 1 })
	dwarf(-270, -1.5, V3.new(1, 0, 0.2), "builder", { carry = true, walk = 3.6, stride = 1 })
	dwarf(-279, 2, V3.new(1, 0, 0.1), "archer", { carry = true, walk = 5.1, stride = 1 })
	dwarf(-254, 12, V3.new(1, 0, 0.6), "healer", { cheer = 0.4 })
	-- a miner at a rock pile by the road
	local rock = Kit.model("Rocks", ws.Castle)
	for r = 1, 4 do
		local sz = r == 1 and 5 or rng:NextNumber(2.4, 3.4)
		Kit.ellipsoid(
			rock,
			"Rock",
			ground(-262 + (r - 1) % 2 * 3, -16 - math.floor((r - 1) / 2) * 2.4, sz * 0.35),
			V3.new(sz, sz * 0.8, sz * 0.9),
			({ C.stone, C.rock, C.stoneDark })[(r - 1) % 3 + 1],
			M.SmoothPlastic
		)
	end
	dwarf(-258.5, -13, V3.new(-0.6, 0, -1), "miner", { swing = 0.6 })
	sparks(ground(-260.5, -15.5, 3), C.rock, 8, 1.4)
	shot("01_building", V3.new(-268, Y + 7, 34), V3.new(-245, Y + 4.5, 12), 50, V3.new(-248, Y + 4, 16))
	shot("02_building_wide", V3.new(-296, Y + 22, 58), V3.new(-243, Y + 3, 4), 46, V3.new(-247, Y + 4, 10))
end
clear()

-- 2 ATTACK: sunset, the monster army charging the gate, archers on the walls, a bomb going off ----------------------
do
	light("fight", { clock = 17.4, brightness = 2.6, atmosphere = { density = 0.12 } })
	starterCastle()
	place("spikes", -64, -1, 0)
	place("spikes", -64, 0, 0)
	place("spikes", -65, -3, 0)
	place("oilPot", -60, -4, 0)
	place("flag", -60, 3, 0, { flag = Looks.byKey.lion })
	-- the army, coming up the west road
	local kinds = {
		"brute",
		"grunt",
		"grunt",
		"breaker",
		"spitter",
		"grunt",
		"witch",
		"brute",
		"grunt",
		"imp",
		"imp",
		"grunt",
		"spitter",
		"breaker",
		"grunt",
		"brute",
		"grunt",
		"witch",
		"grunt",
		"imp",
		"grunt",
		"spitter",
		"grunt",
		"brute",
		"grunt",
		"grunt",
		"imp",
		"grunt",
		"witch",
		"grunt",
	}
	for k, kind in kinds do
		local row = math.floor((k - 1) / 6)
		local col = (k - 1) % 6
		local x = WALL_X - 18 - row * 9 + rng:NextNumber(-2, 2)
		local z = -24 + col * 9 + rng:NextNumber(-2, 2) + (row % 2) * 4
		local pose = { walk = rng:NextNumber(0, 6), stride = 1 }
		if row == 0 then
			pose = { swing = rng:NextNumber(0.2, 0.75) }
		end
		npc(kind, ground(x, z), monsterLook(k), pose, V3.new(1, 0, -z * 0.012))
	end
	-- a breaker ramming the gate, a brute pounding the wall
	npc("breaker", ground(WALL_X - 6, 1.5), monsterLook(3), { swing = 0.62 }, V3.new(1, 0, 0))
	npc("brute", ground(WALL_X - 8, -14), monsterLook(7), { swing = 0.6 }, V3.new(1, 0, 0))
	npc("grunt", ground(WALL_X - 5, 24), monsterLook(1), { swing = 0.5 }, V3.new(1, 0, 0))
	-- dwarves on the walls and towers
	local k = 0
	local function defender(pos, job, pose, facing)
		k += 1
		return npc("dwarf", pos, dwarfLook(k, job), pose or {}, facing or V3.new(-1, 0, 0))
	end
	local towerTop = Y + 20
	local wallTop = Y + 10
	defender(V3.new(-244, towerTop, 40), "archer", {})
	defender(V3.new(-243, towerTop, -40), "archer", {})
	defender(V3.new(-242, wallTop, -14), "archer", {})
	defender(V3.new(-242, wallTop, 12), "archer", {})
	defender(V3.new(-242, wallTop, 26), "fighter", { swing = 0.3 })
	defender(V3.new(-242, wallTop, -25), "builder", { swing = 0.6 })
	defender(V3.new(-242, wallTop, 19), "healer", { cheer = 0.3 })
	defender(V3.new(-242, wallTop + 2, -5), "fighter", { swing = 0.55 })
	-- arrows in flight, goo and hexes coming back
	for i = 1, 9 do
		local from = V3.new(-244, towerTop + 2, i <= 3 and 40 or -40)
		if i > 5 then
			from = V3.new(-242, wallTop + 2, ({ -14, 12, -14, 12 })[i - 5])
		end
		local to = ground(WALL_X - 20 - rng:NextNumber(0, 24), rng:NextNumber(-20, 24), 3)
		arrow(from, to, rng:NextNumber(0.25, 0.8))
	end
	orb(V3.new(WALL_X - 12, Y + 13, 8), C.plague, 1.6)
	orb(V3.new(WALL_X - 24, Y + 11, 16), C.plague, 1.4)
	orb(V3.new(WALL_X - 16, Y + 10, -8), C.magic, 1.3)
	-- a bomb at the wall
	boom(V3.new(WALL_X - 1, Y + 6, 13), 7)
	dust(ground(WALL_X - 10, 0, 0.5), 6, 2.4, C.dirt:Lerp(C.cream, 0.4))
	shot("03_attack", V3.new(WALL_X - 58, Y + 15, -50), V3.new(WALL_X + 2, Y + 7, 6), 46, V3.new(WALL_X - 16, Y + 4, 2))
	shot(
		"04_wall_siege",
		V3.new(WALL_X - 14, Y + 4.5, 54),
		V3.new(WALL_X - 4, Y + 7, 0),
		52,
		V3.new(WALL_X - 6, Y + 4, 20)
	)
	-- the archers from inside the courtyard, against the sky
	shot("05_archers", V3.new(-226, Y + 3, -30), V3.new(-243, Y + 15, 2), 58, V3.new(-242, Y + 12, -12))
end
clear()

-- 3 THE LAST STAND: night in the cave, the last dwarves round the shrine, the horde pouring in -------------------------
do
	light("laststand", { brightness = 1.4, atmosphere = { density = 0.18 } })
	local s3 = MapLayout.shrines[3].pos
	-- what's left of the castle: a few walls, a tower, spikes
	place("stoneWall", 89, -8, 1)
	place("stoneWall", 89, -4, 1, { upgraded = true })
	place("stoneWall", 89, 4, 1)
	place("tower", 90, 8, 0, { flag = Looks.byKey.moon })
	place("spikes", 87, -1, 0)
	place("spikes", 87, 0, 0)
	place("spikes", 86, 2, 0)
	torch(V3.new(s3.X - 14, 1.5, -13))
	torch(V3.new(s3.X - 14, 1.5, 14))
	torch(V3.new(s3.X + 12, 1.5, -16))
	torch(V3.new(s3.X + 12, 1.5, 16))
	-- the last dwarves, in a ring
	local ring = {
		{ -9, -3, "fighter", { swing = 0.6 } },
		{ -8, 5, "archer", {} },
		{ -4, -9, "healer", { cheer = 0.5 } },
		{ -3, 10, "builder", { swing = 0.4 } },
		{ -11, 1.5, "miner", { swing = 0.7 } },
	}
	for k, d in ring do
		npc("dwarf", V3.new(s3.X + d[1], 0, s3.Z + d[2]), dwarfLook(k + 2, d[3]), d[4], V3.new(-1, 0, d[2] * -0.04))
	end
	-- the horde from the main tunnel
	local kinds = {
		"brute",
		"grunt",
		"witch",
		"grunt",
		"imp",
		"breaker",
		"grunt",
		"spitter",
		"brute",
		"grunt",
		"imp",
		"grunt",
		"grunt",
		"witch",
		"grunt",
		"brute",
		"imp",
		"grunt",
		"grunt",
		"spitter",
	}
	for k, kind in kinds do
		local row = math.floor((k - 1) / 5)
		local x = s3.X - 26 - row * 8 + rng:NextNumber(-2, 2)
		local z = -16 + ((k - 1) % 5) * 8 + rng:NextNumber(-1.5, 1.5)
		local pose = row == 0 and { swing = rng:NextNumber(0.3, 0.75) } or { walk = rng:NextNumber(0, 6), stride = 1 }
		npc(kind, V3.new(x, 0, z), monsterLook(k + 4), pose, V3.new(1, 0, -z * 0.02))
	end
	orb(V3.new(s3.X - 17, 6, 3), C.magic, 1.4)
	orb(V3.new(s3.X - 22, 8, -6), C.plague, 1.5)
	arrow(V3.new(s3.X - 8, 4, 5), V3.new(s3.X - 40, 3, 2), 0.35)
	arrow(V3.new(s3.X - 8, 4, 5), V3.new(s3.X - 44, 3, -8), 0.6)
	sparks(V3.new(s3.X - 13, 3.5, -3), C.gold, 9, 1.8)
	-- low behind the dwarves, facing the horde
	shot("06_last_stand", V3.new(s3.X - 4, 5, -31), V3.new(s3.X - 14, 4.5, 3), 52, V3.new(s3.X - 9, 3, 0))
	-- from the horde's side: the last dwarves and the glowing shrine
	shot("07_last_stand_horde", V3.new(s3.X - 30, 15, -27), V3.new(s3.X - 4, 5, 2), 50, V3.new(s3.X - 8, 4, 0))
end
clear()

-- 4 THE PLAGUE: a sick purple sunset, a dwarf turning, the others backing away ------------------------------------------
do
	light("plague", { atmosphere = { density = 0.16 } })
	starterCastle()
	local c = V3.new(-212, Y, -46)
	npc("grunt", c, { skin = Looks.byKey.toxic }, { cheer = 0.6 }, V3.new(0, 0, -1))
	for _ = 1, 3 do
		dust(c + V3.new(0, 1.5, 0), 6, 3, C.plague:Lerp(C.leafDark, 0.3))
	end
	local ring = Kit.disc(fxFolder, "Ring", c + V3.new(0, 0.15, 0), 18, 0.2, C.plague, M.Neon)
	ring.Transparency = 0.45
	local k = 0
	for _, d in
		{ { -7, -6, { hit = 0.8 } }, { 7, -7, { hit = 0.6 } }, { 2, -12, { cheer = 0.2 } }, { -4, -13, { hit = 0.5 } } }
	do
		k += 1
		npc(
			"dwarf",
			c + V3.new(d[1], 0, d[2]),
			dwarfLook(k, ({ "fighter", "builder", "healer", "archer" })[k]),
			d[3],
			(c - (c + V3.new(d[1], 0, d[2]))).Unit
		)
	end
	shot("08_plague", c + V3.new(-6, 7, -30), c + V3.new(0, 3, 0), 50, c)
end
clear()

-- 5 THE VALLEY: the castle on its hill at sunset and the army crossing the creek -------------------------------------
do
	light("fight", { clock = 17.2, brightness = 2.6, atmosphere = { density = 0.08 } })
	starterCastle()
	place("tower", -50, -16, 0, { upgraded = true, flag = Looks.byKey.dragon })
	place("tower", -50, 14, 0, { upgraded = true, flag = Looks.byKey.lion })
	place("stoneWall", -52, -14, 0)
	place("stoneWall", -52, 14, 0)
	for k = 1, 46 do
		local kinds = { "grunt", "grunt", "brute", "spitter", "imp", "witch", "breaker" }
		local x = -340 - rng:NextNumber(0, 70)
		local z = rng:NextNumber(-34, 34)
		npc(
			kinds[(k - 1) % #kinds + 1],
			ground(x, z),
			monsterLook(k),
			{ walk = rng:NextNumber(0, 6), stride = 1 },
			V3.new(1, 0, -z * 0.01)
		)
	end
	for k = 1, 6 do
		npc(
			"dwarf",
			V3.new(-242, Y + 10, -30 + k * 9),
			dwarfLook(k, k % 2 == 0 and "archer" or "fighter"),
			{},
			V3.new(-1, 0, 0)
		)
	end
	shot("09_valley", V3.new(-330, 70, -150), V3.new(-262, 6, 0), 55, V3.new(-280, 6, 0))
end

clear()

-- 6 THE JOBS: five dwarves and five monsters, face to face (a character sheet for the store page) -------------------
do
	light("build", {
		clock = 16.2,
		brightness = 2.3,
		exposure = -0.2,
		ambient = rgb(92, 90, 104),
		outdoor = rgb(128, 128, 142),
		atmosphere = { density = 0.05, haze = 0.3, color = rgb(214, 228, 246) },
	})
	starterCastle()
	local base = V3.new(-214, Y, -60)
	local dwarfJobs = { "builder", "miner", "fighter", "archer", "healer" }
	local dwarfPose = { { swing = 0.3 }, { swing = 0.6 }, {}, {}, { cheer = 0.4 } }
	for k, job in dwarfJobs do
		npc(
			"dwarf",
			base + V3.new(-11 + k * 3.2, 0, -2 - math.abs(k - 3) * 0.6),
			dwarfLook(k + 1, job),
			dwarfPose[k],
			V3.new(0.35, 0, -1)
		)
	end
	local monsters = { "grunt", "brute", "spitter", "witch", "breaker" }
	for k, kind in monsters do
		npc(
			kind,
			base + V3.new(4.5 + k * 3.8, 0, -1 - math.abs(k - 3) * 0.7),
			monsterLook(k),
			k == 2 and { swing = 0.4 } or {},
			V3.new(-0.35, 0, -1)
		)
	end
	shot("10_jobs", base + V3.new(6, 6, -30), base + V3.new(6, 3.2, -1), 42, base + V3.new(6, 3, -2))
end

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print(`{#shots} shots, {#Engine.errors} script errors`)
for _, e in Engine.errors do
	print(e)
end

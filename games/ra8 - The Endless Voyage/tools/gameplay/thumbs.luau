--[[
Store thumbnails and screenshots (master plan §1-§10: the raft at the centre, collecting, building, sailing,
islands, wrecks, the creatures, the Leviathan). Staged scenes made from the game's own models (the ocean from
OceanBuilder, rafts from RaftModels at the grid's real positions, islands from IslandBuilder, debris from
OceanModels, creatures from Rigs, items from ItemModels), with survivors as plain blocky Roblox avatars posed by
hand, and no UI. Snapshots are marked cinematic so render.js also writes a depth pass; thumbs_post.py adds the
"shader" look.

  luaurun tools/gameplay/thumbs.luau <outDir> [only,...]      (from the game folder; only = parts of shot names)
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules> --textures <pbr dir>
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
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)
local OceanBuilder = Engine.require(tree.server.World.OceanBuilder)
local OceanLayout = Engine.require(tree.shared.World.OceanLayout)
local RaftModels = Engine.require(tree.shared.World.RaftModels)
local OceanModels = Engine.require(tree.shared.World.OceanModels)
local IslandBuilder = Engine.require(tree.shared.World.IslandBuilder)
local ItemModels = Engine.require(tree.shared.World.ItemModels)
local Rigs = Engine.require(tree.shared.World.Rigs)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local Items = Engine.require(tree.shared.Data.Items)
local Kit = Engine.require(tree.shared.World.Kit)
local C, M = Kit.C, Kit.M
local ws = Engine.workspace
local WATER = Constants.WATER_LEVEL

OceanBuilder.build()
local cast = Instance.new("Folder", ws)
cast.Name = "Cast"
local fxFolder = ws:FindFirstChild("Fx") or Instance.new("Folder", ws)
fxFolder.Name = "Fx"
local rafts = ws:FindFirstChild("Rafts")
local islands = ws:FindFirstChild("Islands")
local debrisFolder = ws:FindFirstChild("Debris")
local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer
local rng = Random.new(8)

local function clear()
	for _, f in { cast, fxFolder, rafts, islands, debrisFolder } do
		for _, c in f:GetChildren() do
			c:Destroy()
		end
	end
	-- (the islands' terrain: the renderer reads the ops in order, so the last fill of a spot wins)
end

-- Rafts: pieces at the grid's real positions, the way RaftService builds them -----------------------------------------
local function raft(plot, pieces, colours)
	local layout = OceanLayout.plot(plot)
	local folder = Instance.new("Model", rafts)
	folder.Name = "Raft" .. plot
	local models = {}
	for _, p in pieces do
		local pos = Formulas.tilePosition(layout.center, p[2], p[3], p[4] or 1)
		local def = Engine.require(tree.shared.Data.Pieces).get(p[1])
		local rot = p[5] or 0
		local cf = (def and def.edge) and CF.new(pos) or CF.new(pos) * CF.Angles(0, -rot * math.pi / 2, 0)
		local m =
			RaftModels.build(p[1], cf, { colours = colours or {}, edge = (def and def.edge) and rot or nil }, folder)
		if p.hp then
			RaftModels.damage(m, p.hp)
		end
		table.insert(models, m)
	end
	return layout, models
end

-- A square of floor tiles from (x0, z0), n x n.
local function square(x0, z0, n, key)
	local out = {}
	for x = 0, n - 1 do
		for z = 0, n - 1 do
			table.insert(out, { key or "floor", x0 + x, z0 + z, 1 })
		end
	end
	return out
end
local function join(...)
	local out = {}
	for _, list in { ... } do
		for _, p in list do
			table.insert(out, p)
		end
	end
	return out
end
local function tileWorld(layout, gx, gz, level)
	return Formulas.tilePosition(layout.center, gx, gz, level or 1) + V3.new(0, 0.3, 0)
end

-- Survivors: blocky Roblox avatars, posed by hand -----------------------------------------------------------------------
local SKINS = { rgb(255, 214, 176), rgb(234, 184, 146), rgb(198, 142, 100), rgb(142, 96, 64), rgb(255, 226, 196) }
local function mk(parent, name, cf, size, color, material, shape)
	local p = Kit.box(parent, name, cf, size, color, material or M.SmoothPlastic, { CanCollide = false })
	if shape then
		p.Shape = Enum.PartType[shape]
	end
	return p
end
local function resolveWelds(model)
	for _, w in model:GetDescendants() do
		if w.ClassName == "Weld" and w.Part0 and w.Part1 then
			local c1 = w.C1 or CF.new()
			w.Part1.CFrame = w.Part0.CFrame * (w.C0 or CF.new()) * c1:Inverse()
		end
	end
end
--[[ spec = { pos, face (direction), shirt, pants, skin (1-5), hair (Color3 | false), hold (item key, right hand),
  holdL (item key, left hand), pose = { armR, armL (pitch: + is forward/up), rollR, rollL (out to the side),
  legR, legL, lean (- is forward), twist, turn (the head), nod } ]]
local function survivor(spec)
	local m = Instance.new("Model")
	m.Name = spec.name or "Survivor"
	m.Parent = cast
	local pose = spec.pose or {}
	local f = spec.face or V3.new(0, 0, -1)
	local pos = spec.pos
	local base = CF.lookAt(pos, pos + V3.new(f.X, 0, f.Z))
	local skin = SKINS[spec.skin or 1]
	local shirt, pants = spec.shirt or rgb(214, 74, 60), spec.pants or rgb(44, 48, 66)
	local function limb(name, pivot, pitch, roll, size, color)
		local at = pivot * CF.Angles(pitch or 0, 0, roll or 0)
		mk(m, name, at * CF.new(0, -size.Y / 2 + 0.1, 0), size, color)
		return at
	end
	limb("LeftLeg", base * CF.new(-0.5, 2, 0), pose.legL, 0, V3.new(1, 2, 1), pants)
	limb("RightLeg", base * CF.new(0.5, 2, 0), pose.legR, 0, V3.new(1, 2, 1), pants)
	local hips = base * CF.new(0, 2, 0) * CF.Angles(pose.lean or 0, pose.twist or 0, 0)
	mk(m, "UpperTorso", hips * CF.new(0, 1, 0), V3.new(2, 2, 1), shirt)
	mk(m, "Belt", hips * CF.new(0, 0.15, 0), V3.new(2.02, 0.3, 1.02), pants:Lerp(rgb(20, 20, 26), 0.4))
	local headCF = hips * CF.new(0, 2.65, 0) * CF.Angles(pose.nod or 0, pose.turn or 0, 0)
	local head = mk(m, "Head", headCF, V3.new(1.2, 1.2, 1.2), skin)
	head.Transparency = 1
	mk(m, "HeadShape", headCF * CF.Angles(0, 0, math.rad(90)), V3.new(1.2, 1.3, 1.3), skin, M.SmoothPlastic, "Cylinder")
	for _, x in { -0.24, 0.24 } do
		mk(m, "Eye", headCF * CF.new(x, 0.12, -0.62), V3.new(0.16, 0.26, 0.08), rgb(24, 24, 32))
	end
	mk(m, "Smile", headCF * CF.new(0, -0.22, -0.63), V3.new(0.46, 0.09, 0.06), rgb(24, 24, 32))
	if spec.hair ~= false then
		local hair = spec.hair or rgb(70, 46, 30)
		mk(m, "Hair", headCF * CF.new(0, 0.62, 0.05), V3.new(1.36, 0.36, 1.36), hair, M.Fabric)
		mk(m, "HairBack", headCF * CF.new(0, 0.2, 0.6), V3.new(1.34, 0.9, 0.24), hair, M.Fabric)
	end
	if spec.hat then
		mk(m, "Hat", headCF * CF.new(0, 0.75, 0), V3.new(1.5, 0.3, 1.5), spec.hat, M.Fabric)
		mk(m, "HatTop", headCF * CF.new(0, 1.05, 0), V3.new(1.1, 0.5, 1.1), spec.hat, M.Fabric)
	end
	local function arm(name, side, pitch, roll)
		local sh = hips * CF.new(side * 1.5, 1.85, 0)
		local at = sh * CF.Angles(pitch or 0, 0, (roll or 0) * side)
		mk(m, name, at * CF.new(0, -0.85, 0), V3.new(1, 1.7, 1), shirt)
		mk(m, name .. "Hand", at * CF.new(0, -1.85, 0), V3.new(0.92, 0.4, 0.92), skin)
		return at * CF.new(0, -1.9, 0)
	end
	local handR = arm("RightArm", 1, pose.armR, pose.rollR)
	local handL = arm("LeftArm", -1, pose.armL, pose.rollL)
	local function hold(key, hand)
		local item = Items.get(key)
		if not item then
			return
		end
		local model = ItemModels.held(item, m)
		model:PivotTo(hand * ItemModels.holdCFrame(item, nil))
		Engine.resolveWelds()
	end
	if spec.hold then
		hold(spec.hold, handR)
	end
	if spec.holdL then
		hold(spec.holdL, handL)
	end
	resolveWelds(m)
	return m, handR
end

local POSES = {
	stand = {},
	throw = { armR = 2.3, armL = 0.6, rollL = -0.2, legR = 0.3, legL = -0.3, lean = -0.12, twist = 0.2 },
	reel = { armR = 1.4, armL = 1.2, rollL = -0.3, lean = -0.08 },
	chop = { armR = 2.7, armL = 2.4, rollL = -0.25, lean = 0.08 },
	hammer = { armR = 2.2, armL = 0.9, rollL = -0.3, legR = 0.2, legL = -0.2, lean = -0.2 },
	helm = { armR = 1.3, armL = 1.3, rollR = -0.3, rollL = -0.3 },
	aim = { armR = 2.5, armL = 1.5, rollL = -0.35, twist = 0.35, turn = -0.3, lean = -0.1 },
	stab = { armR = 1.55, armL = 0.5, legR = 0.35, legL = -0.3, lean = -0.2 },
	cheer = { armR = 2.9, armL = 2.9, rollR = 0.3, rollL = 0.3 },
	brace = { armR = 1.6, armL = 1.2, legR = 0.45, legL = -0.45, lean = -0.12 },
	carry = { armR = 1.1, armL = 1.1, rollR = -0.25, rollL = -0.25, lean = 0.06 },
	wave = { armR = 2.8, rollR = 0.4, armL = 0.1 },
	sit = { legR = 1.5, legL = 1.5, armR = 0.6, armL = 0.6 },
}
local OUTFITS = {
	{ shirt = rgb(214, 74, 60), pants = rgb(44, 48, 66), skin = 1, hair = rgb(70, 46, 30) },
	{ shirt = rgb(60, 130, 220), pants = rgb(54, 54, 60), skin = 3, hair = rgb(24, 22, 26) },
	{ shirt = rgb(250, 196, 50), pants = rgb(70, 60, 120), skin = 2, hair = rgb(220, 170, 90) },
	{ shirt = rgb(80, 180, 100), pants = rgb(60, 44, 34), skin = 4, hair = rgb(30, 24, 20) },
	{ shirt = rgb(170, 90, 210), pants = rgb(240, 240, 240), skin = 5, hair = rgb(200, 80, 60) },
	{ shirt = rgb(255, 140, 60), pants = rgb(40, 70, 110), skin = 2, hair = rgb(110, 70, 40) },
}
local function dress(k, spec)
	local o = OUTFITS[(k - 1) % #OUTFITS + 1]
	for key, v in o do
		if spec[key] == nil then
			spec[key] = v
		end
	end
	return survivor(spec)
end

-- Creatures ---------------------------------------------------------------------------------------------------------------
local function creature(kind, pos, facing, state, moving)
	local model, offsets = Rigs.build(kind, cast)
	local cf = CF.lookAt(pos, pos + V3.new(facing.X, 0, facing.Z))
	Rigs.place(model, offsets, cf, state or "idle", 1.3, moving)
	return model
end

-- Effects, made of the same shapes the client's effects use ---------------------------------------------------------------
local function chunk(pos, size, color, material, shape, t)
	local p = Kit.box(
		fxFolder,
		"Fx",
		CF.new(pos) * CF.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
		size,
		color,
		material or M.SmoothPlastic,
		{ CanCollide = false, CastShadow = false, Transparency = t or 0 }
	)
	if shape then
		p.Shape = Enum.PartType[shape]
	end
	return p
end
local function chips(pos, n, colors)
	for _ = 1, n or 8 do
		local s = rng:NextNumber(0.25, 0.5)
		chunk(
			pos + V3.new(rng:NextNumber(-1.4, 1.4), rng:NextNumber(-0.3, 1.6), rng:NextNumber(-1.4, 1.4)),
			V3.new(s, s * 0.6, s * 1.3),
			(colors or { C.woodLight, C.bark, C.wood })[rng:NextInteger(1, 3)]
		)
	end
end
local function sparkles(pos, color, n, spread)
	for _ = 1, n or 10 do
		local s = rng:NextNumber(0.2, 0.5)
		chunk(
			pos + V3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1.4), rng:NextNumber(-1, 1)) * (spread or 2),
			V3.new(s, s, s),
			color or C.gold,
			M.Neon,
			"Ball"
		)
	end
end
local function splash(pos, n, size)
	for _ = 1, n or 10 do
		local s = rng:NextNumber(0.3, 0.7) * (size or 1)
		chunk(
			pos + V3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 2.2), rng:NextNumber(-1.5, 1.5)),
			V3.new(s, s, s),
			rgb(200, 230, 245),
			M.SmoothPlastic,
			"Ball",
			0.2
		)
	end
	local ring = Kit.disc(
		fxFolder,
		"Ring",
		V3.new(pos.X, WATER + 0.25, pos.Z),
		(size or 1) * 5,
		0.2,
		rgb(220, 240, 250),
		M.Neon,
		{ CanCollide = false, Transparency = 0.45 }
	)
	_ = ring
end
-- the hook's rope from a hand to a point
local function rope(from, to, color)
	local d = to - from
	local len = d.Magnitude
	local p = Kit.box(
		fxFolder,
		"Rope",
		CF.lookAt(from, to) * CF.new(0, 0, -len / 2),
		V3.new(0.14, 0.14, len),
		color or C.rope,
		M.Fabric,
		{ CanCollide = false, CastShadow = false }
	)
	return p
end
local function wave(center, radius, t)
	Kit.disc(
		fxFolder,
		"Wave",
		V3.new(center.X, WATER + 0.3, center.Z),
		radius * 2,
		0.5,
		rgb(180, 215, 240),
		M.SmoothPlastic,
		{ CanCollide = false, Transparency = t or 0.5 }
	)
end
local function redRing(pos, radius)
	Kit.disc(
		fxFolder,
		"Tell",
		pos + V3.new(0, 0.15, 0),
		radius * 2,
		0.15,
		rgb(255, 52, 52),
		M.Neon,
		{ CanCollide = false, Transparency = 0.35 }
	)
end
local function glow(pos, color, range, brightness)
	local p = chunk(pos, V3.new(0.2, 0.2, 0.2), color or C.warm, M.Neon, "Ball", 1)
	Kit.light(
		p,
		"PointLight",
		{ Name = "Glow", Color = color or C.warm, Range = range or 18, Brightness = brightness or 1.5 }
	)
	return p
end
local function drift(plot, n, radius, kinds)
	local layout = OceanLayout.plot(plot)
	local out = {}
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(radius * 0.6, radius)
		local pos = layout.center + V3.new(math.cos(a) * r, WATER + 0.3, math.sin(a) * r)
		local kind = (kinds or { "wood", "scrap", "rope", "wood", "cloth", "metal" })[(i - 1) % 6 + 1]
		table.insert(out, {
			pos = pos,
			model = OceanModels.debris(kind, CF.new(pos) * CF.Angles(0, rng:NextNumber(0, 6), 0), debrisFolder),
		})
	end
	return out
end

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
local function wants(name)
	if not only then
		return true
	end
	for part in string.gmatch(only, "[^,]+") do
		if string.find(name, part, 1, true) then
			return true
		end
	end
	return false
end
local function shot(name, camPos, camTarget, fov, focus)
	if not wants(name) then
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

local WHITE = { sail = "white", banner = "white", flag = "white", deck = "natural" }

-- 01 The first cast: the driftwood platform, the rod's line flying out to a piece of wood ------------------------------------
if wants("01") then
	clear()
	light("day")
	local layout = raft(1, join(square(6, 6, 2), { { "floor", 8, 6, 1 } }), WHITE)
	local pieces = drift(1, 7, 22)
	local stand = tileWorld(layout, 8, 6)
	local target = stand + layout.current * 14 + V3.new(0, -2, 0)
	target = V3.new(target.X, WATER + 0.3, target.Z)
	OceanModels.debris("wood", CF.new(target) * CF.Angles(0, 0.8, 0), debrisFolder)
	local face = (target - stand).Unit
	local caster, hand = dress(1, { pos = stand, face = face, pose = POSES.throw, hold = "fishing_rod" })
	local bobber = caster:FindFirstChild("Bobber", true)
	rope((bobber and bobber.Position or hand.Position + V3.new(0, 0.2, 0)), target + V3.new(0, 0.6, 0), rgb(240, 232, 210))
	splash(target, 8, 0.8)
	-- a friend on the platform's other tile, waving
	dress(2, { pos = tileWorld(layout, 6, 7), face = face, pose = POSES.wave })
	local cam = stand - face * 11 + V3.new(0, 6, 0) + V3.new(-face.Z, 0, face.X) * 5
	shot("01_first_cast", cam, stand + face * 6 + V3.new(0, 1.5, 0), 52, stand + face * 4 + V3.new(0, 2, 0))
	_ = pieces
end

-- 02 Building: a survival raft growing, a tile being hammered down ------------------------------------------------------------
if wants("02") then
	clear()
	light("day", { clock = 10.5 })
	local pieces = join(square(5, 5, 4), {
		{ "workbench", 6, 7, 1, 2 },
		{ "storage", 5, 5, 1, 0 },
		{ "bed", 8, 8, 1, 1 },
		{ "lamp", 5, 8, 1 },
		{ "railing", 5, 6, 1, 2 },
		{ "railing", 5, 7, 1, 2 },
		{ "net", 8, 5, 1, 0 },
		{ "net", 8, 6, 1, 0 },
		{ "ladder", 6, 5, 1, 3 },
		{ "floor", 9, 7, 1 },
		{ "chair", 7, 5, 1, 1 },
	})
	local layout = raft(1, pieces, WHITE)
	drift(1, 8, 26)
	local newTile = tileWorld(layout, 9, 7)
	chips(newTile + V3.new(0, 0.6, 0), 10)
	sparkles(newTile + V3.new(0, 1, 0), C.gold, 8, 1.6)
	local here = tileWorld(layout, 8, 7)
	dress(1, { pos = here, face = V3.new(1, 0, 0), pose = POSES.hammer, hold = "hammer" })
	local bench = tileWorld(layout, 6, 7)
	dress(2, { pos = bench + V3.new(0, 0, 3.2), face = V3.new(0, 0, -1), pose = POSES.carry })
	dress(3, { pos = tileWorld(layout, 7, 8), face = V3.new(-1, 0, 0.3), pose = POSES.reel, hold = "fishing_rod" })
	local cam = here + V3.new(-14, 8, 12)
	shot("02_build_your_raft", cam, here + V3.new(1, 1.5, 0), 50, here + V3.new(0, 2, 0))
end

-- 03 Setting sail: a sail up, a hand at the helm, dolphins, an island ahead ---------------------------------------------------
if wants("03") then
	clear()
	light("day", { clock = 16 })
	local pieces = join(square(5, 5, 4), {
		{ "sail", 7, 7, 1, 1 },
		{ "helm", 6, 5, 1, 3 },
		{ "nav_table", 8, 5, 1, 3 },
		{ "workbench", 5, 8, 1, 2 },
		{ "storage", 5, 5, 1 },
		{ "refinery", 8, 8, 1, 1 },
		{ "railing", 5, 6, 1, 2 },
		{ "railing", 5, 7, 1, 2 },
		{ "railing", 6, 8, 1, 1 },
		{ "railing", 7, 8, 1, 1 },
		{ "flag", 8, 6, 1 },
		{ "net", 8, 7, 1, 0 },
	})
	local layout = raft(2, pieces, { sail = "blue", banner = "blue", flag = "blue", deck = "natural" })
	local dest = layout.islandCenter
	IslandBuilder.build("tropical", dest, Random.new(3), islands)
	local helm = tileWorld(layout, 6, 5)
	dress(2, { pos = helm + V3.new(0, 0, 2.2), face = V3.new(0, 0, -1), pose = POSES.helm })
	dress(1, { pos = tileWorld(layout, 7, 6), face = layout.out, pose = POSES.cheer })
	dress(4, {
		pos = tileWorld(layout, 8, 7) + V3.new(-2, 0, 0),
		face = V3.new(1, 0, 0),
		pose = POSES.reel,
		hold = "fishing_rod",
	})
	-- dolphins and the bow wave
	for i = 1, 3 do
		local a = layout.out * (18 + i * 5) + layout.current * (i * 6 - 8)
		local p = layout.center + a + V3.new(0, WATER + 1 + (i % 2) * 2, 0)
		local fin = chunk(p, V3.new(0.5, 1.8, 3), rgb(120, 140, 160))
		fin.CFrame = CF.lookAt(p, p + layout.out + V3.new(0, 0.3, 0))
		splash(V3.new(p.X, WATER, p.Z), 4, 0.6)
	end
	wave(layout.center, 24, 0.75)
	local cam = layout.center - layout.out * 26 + layout.current * 22 + V3.new(0, 11, 0)
	shot("03_set_sail", cam, layout.center + layout.out * 8 + V3.new(0, 5, 0), 55, layout.center + V3.new(0, 4, 0))
end

-- 04 Palm Key: ashore, chopping a palm, crabs on the beach ------------------------------------------------------------------------
if wants("04") then
	clear()
	light("day", { clock = 11 })
	local layout = raft(
		3,
		join(
			square(5, 6, 3),
			{ { "helm", 7, 8, 1 }, { "sail", 6, 8, 1 }, { "workbench", 5, 6, 1 }, { "railing", 5, 7, 1, 2 } }
		),
		{ sail = "red", banner = "red", flag = "red", deck = "natural" }
	)
	local built = IslandBuilder.build("tropical", layout.islandCenter, Random.new(5), islands)
	local palm
	for _, n in built.nodes do
		if n.kind == "tree" then
			palm = n
			break
		end
	end
	local fire = built.landmark.pos
	local at = palm.pos
	local toRaft = (layout.center - at)
	toRaft = V3.new(toRaft.X, 0, toRaft.Z).Unit
	local stand = at + toRaft * 3.2
	stand = V3.new(stand.X, (built.ground(stand.X, stand.Z) or WATER + 1) + 0.2, stand.Z)
	dress(1, { pos = stand, face = -toRaft, pose = POSES.chop, hold = "axe" })
	chips(at + V3.new(0, 3, 0) + toRaft * 1.5, 12)
	for i = 1, 3 do
		local a = i * 2.1
		local p = fire + V3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
		p = V3.new(p.X, (built.ground(p.X, p.Z) or WATER + 1) + 0.9, p.Z)
		creature("reef_crab", p, (stand - p), i == 1 and "tell" or "chase", true)
	end
	local firePos = V3.new(fire.X, fire.Y, fire.Z)
	dress(
		3,
		{ pos = firePos + V3.new(3.5, 0.2, 2), face = (firePos - (firePos + V3.new(3.5, 0, 2))), pose = POSES.sit }
	)
	glow(firePos + V3.new(0, 1.5, 0), C.warm, 16, 1.2)
	local cam = stand + toRaft * 13 + V3.new(0, 7, 0) + V3.new(-toRaft.Z, 0, toRaft.X) * 6
	shot("04_palm_key", cam, at + V3.new(0, 3, 0), 52, stand + V3.new(0, 2, 0))
end

-- 05 The Drifter: a wreck on its side, prying the salvage, a lurker in the reeds ---------------------------------------------
if wants("05") then
	clear()
	light("fog", { clock = 15 })
	local layout = raft(
		4,
		join(square(5, 5, 4), {
			{ "helm", 8, 5, 1 },
			{ "sail", 7, 7, 1 },
			{ "engine", 5, 8, 1 },
			{ "railing", 5, 5, 1, 2 },
			{ "railing", 5, 6, 1, 2 },
			{ "lamp", 6, 5, 1 },
		}),
		{ sail = "green", banner = "green", flag = "green", deck = "dark" }
	)
	local built = IslandBuilder.build("surface_wreck", layout.islandCenter, Random.new(7), islands)
	local pile
	for _, n in built.nodes do
		if n.kind == "salvage" then
			pile = n
			break
		end
	end
	local at = pile.pos
	local toward = (layout.center - at)
	toward = V3.new(toward.X, 0, toward.Z).Unit
	local stand = at + toward * 2.8
	stand = V3.new(stand.X, (built.ground(stand.X, stand.Z) or WATER + 1) + 0.2, stand.Z)
	dress(2, { pos = stand, face = -toward, pose = POSES.stab, hold = "crowbar" })
	chips(at + V3.new(0, 1.2, 0), 8, { C.iron, C.steel, rgb(90, 70, 60) })
	local locker = built.containers[1]
	dress(5, { pos = locker.pos + toward * 2.5 + V3.new(0, 0.2, 0), face = -toward, pose = POSES.carry })
	sparkles(locker.pos + V3.new(0, 1.5, 0), C.gold, 10, 1.4)
	local lurk = built.center - toward * 10 + V3.new(5, 0, 0)
	lurk = V3.new(lurk.X, (built.ground(lurk.X, lurk.Z) or WATER + 1) + 1.2, lurk.Z)
	creature("mire_lurker", lurk, stand - lurk, "tell", false)
	redRing(V3.new(lurk.X, lurk.Y - 1, lurk.Z), 5.5)
	local cam = stand + toward * 12 + V3.new(0, 6.5, 0) - V3.new(-toward.Z, 0, toward.X) * 7
	shot("05_the_wreck", cam, at + V3.new(0, 2.5, 0), 54, stand + V3.new(0, 2, 0))
end

-- 06 Storm: waves over the deck, a cracked tile, a shark at the edge, the hammer out -------------------------------------------
if wants("06") then
	clear()
	light("storm")
	local pieces = join(square(5, 5, 4), {
		{ "sail", 6, 7, 1, 1 },
		{ "helm", 8, 5, 1, 3 },
		{ "anchor", 5, 8, 1 },
		{ "workbench", 5, 5, 1 },
		{ "railing", 5, 6, 1, 2 },
		{ "railing", 5, 7, 1, 2 },
		{ "railing", 6, 8, 1, 1 },
		{ "railing", 7, 8, 1, 1 },
		{ "spikes", 8, 6, 1, 0 },
		{ "lamp", 7, 5, 1 },
		{ "floor", 9, 6, 1, hp = 0.2 },
		{ "floor", 9, 7, 1, hp = 0.4 },
	})
	local layout = raft(5, pieces, { sail = "white", banner = "red", flag = "red", deck = "natural" })
	wave(layout.center + V3.new(14, 0, 4), 18, 0.55)
	wave(layout.center + V3.new(-10, 0, -12), 14, 0.6)
	for i = 1, 14 do
		local a = i * 0.45
		splash(layout.center + V3.new(math.cos(a) * 15, 0, math.sin(a) * 15), 3, 1.2)
	end
	local broken = tileWorld(layout, 9, 6)
	dress(1, { pos = tileWorld(layout, 8, 7), face = V3.new(1, 0, -0.4), pose = POSES.hammer, hold = "hammer" })
	dress(3, { pos = tileWorld(layout, 6, 6), face = V3.new(1, 0, 0), pose = POSES.brace })
	local bite = broken + V3.new(4.5, -2, 0)
	local shark = creature("shark", V3.new(bite.X, WATER - 0.2, bite.Z), (broken - bite), "surface", true)
	_ = shark
	splash(V3.new(bite.X, WATER, bite.Z), 10, 1.6)
	glow(tileWorld(layout, 7, 5) + V3.new(0, 4, 0), C.warm, 20, 1.4)
	local cam = layout.center + V3.new(-18, 9, 20)
	shot("06_storm", cam, broken + V3.new(-2, 1.5, 0), 56, tileWorld(layout, 8, 7) + V3.new(0, 2, 0))
end

-- 07 The Leviathan: night at the Trench, the fortress raft, harpoons flying -----------------------------------------------------
if wants("07") then
	clear()
	light("trench", { clock = 23 })
	local pieces = join(square(4, 4, 6), {
		{ "harpoon_turret", 4, 4, 1 },
		{ "harpoon_turret", 9, 9, 1 },
		{ "lamp", 4, 9, 1 },
		{ "lamp", 9, 4, 1 },
		{ "lamp", 6, 6, 1 },
		{ "stairs", 7, 7, 1, 1 },
		{ "crow_nest", 7, 8, 2 },
		{ "engine", 4, 6, 1 },
		{ "sail", 6, 8, 1, 1 },
		{ "anchor", 5, 4, 1 },
		{ "research", 8, 5, 1 },
		{ "engineering", 8, 6, 1 },
		{ "spikes", 9, 5, 1, 0 },
		{ "spikes", 9, 6, 1, 0 },
		{ "spikes", 9, 7, 1, 0 },
		{ "railing", 4, 5, 1, 2 },
		{ "railing", 4, 7, 1, 2 },
		{ "railing", 4, 8, 1, 2 },
		{ "floor", 7, 8, 2 },
		{ "floor", 8, 8, 2 },
		{ "floor", 8, 7, 2 },
		{ "floor", 6, 7, 2 },
	})
	local layout = raft(6, pieces, { sail = "black", banner = "gold", flag = "gold", deck = "dark" })
	IslandBuilder.build("trench", layout.islandCenter, Random.new(9), islands)
	local out = layout.out
	local side = V3.new(-out.Z, 0, out.X)
	local levPos = layout.center + out * 34 + V3.new(0, WATER + 2.5, 0)
	creature("leviathan", levPos, -out, "surface", false)
	splash(V3.new(levPos.X, WATER, levPos.Z), 16, 2.5)
	for _, m in cast:GetChildren() do
		if m.Name == "leviathan" then
			local eyes = m:FindFirstChild("EyeGlow")
			if eyes then
				Kit.light(eyes, "PointLight", { Name = "Big", Color = rgb(255, 200, 60), Range = 40, Brightness = 2 })
			end
		end
	end
	local edge = tileWorld(layout, 9, 7)
	local _, hand = dress(1, { pos = edge, face = out, pose = POSES.aim, hold = "harpoon" })
	rope(hand.Position + V3.new(0, 0.5, 0), levPos + V3.new(0, 1, 0) - out * 9 + side * 2, C.steel)
	dress(2, { pos = tileWorld(layout, 9, 5), face = out, pose = POSES.aim, hold = "harpoon" })
	dress(4, { pos = tileWorld(layout, 8, 8, 2), face = out, pose = POSES.cheer })
	dress(3, { pos = tileWorld(layout, 7, 6), face = out, pose = POSES.hammer, hold = "hammer" })
	-- the turret's shot
	local tur = tileWorld(layout, 9, 9) + V3.new(0, 3, 0)
	rope(tur, levPos + V3.new(0, 2, 0) - out * 8, rgb(255, 220, 120))
	for _, g in { tileWorld(layout, 4, 9), tileWorld(layout, 9, 4), tileWorld(layout, 6, 6) } do
		glow(g + V3.new(0, 4.5, 0), C.warm, 22, 1.6)
	end
	local cam = layout.center - out * 12 + side * 30 + V3.new(0, 12, 0)
	shot("07_the_leviathan", cam, levPos - out * 8 + V3.new(0, 1, 0), 58, edge + V3.new(0, 2, 0))
end

-- 08 Legendary vessel at dusk: two decks, gold flags, the aquarium, the trophy ---------------------------------------------------
if wants("08") then
	clear()
	light("dusk")
	local pieces = join(square(3, 3, 8), {
		{ "sail", 6, 6, 1, 1 },
		{ "helm", 5, 3, 1, 3 },
		{ "nav_table", 7, 3, 1, 3 },
		{ "engine", 3, 8, 1 },
		{ "anchor", 10, 10, 1 },
		{ "workbench", 3, 4, 1, 0 },
		{ "refinery", 3, 5, 1, 0 },
		{ "engineering", 3, 6, 1, 0 },
		{ "research", 3, 7, 1, 0 },
		{ "cookpot", 10, 4, 1 },
		{ "decor_shop", 10, 5, 1, 2 },
		{ "aquarium", 8, 9, 1, 1 },
		{ "trophy_stand", 6, 9, 1, 1 },
		{ "stairs", 9, 7, 1, 1 },
		{ "crow_nest", 9, 9, 2 },
		{ "bed", 4, 9, 1, 1 },
		{ "planter", 5, 10, 1 },
		{ "planter", 6, 10, 1 },
		{ "lamp", 3, 10, 1 },
		{ "lamp", 10, 3, 1 },
		{ "flag", 7, 10, 1 },
		{ "banner", 4, 3, 1, 3 },
		{ "chair", 8, 4, 1, 2 },
		{ "table", 9, 4, 1 },
		{ "rug", 8, 5, 1 },
		{ "storage", 10, 6, 1 },
		{ "storage", 10, 7, 1 },
		{ "harpoon_turret", 10, 8, 1 },
		{ "railing", 3, 3, 1, 2 },
		{ "railing", 3, 9, 1, 2 },
		{ "net", 10, 9, 1, 0 },
		{ "salvage_net", 4, 10, 1, 1 },
		{ "coral_lamp", 7, 4, 1 },
	})
	for x = 7, 9 do
		for z = 7, 9 do
			if not (x == 9 and z == 9) then
				table.insert(pieces, { "plank_floor", x, z, 2 })
			end
		end
	end
	table.insert(pieces, { "railing", 7, 7, 2, 2 })
	table.insert(pieces, { "railing", 7, 8, 2, 2 })
	table.insert(pieces, { "roof", 8, 8, 2 })
	local layout = raft(1, pieces, { sail = "gold", banner = "gold", flag = "gold", deck = "white" })
	drift(1, 6, 30)
	dress(1, { pos = tileWorld(layout, 8, 7, 2), face = V3.new(0, 0, 1), pose = POSES.cheer })
	dress(2, { pos = tileWorld(layout, 5, 3), face = V3.new(0, 0, -1), pose = POSES.helm })
	dress(3, { pos = tileWorld(layout, 8, 5), face = V3.new(1, 0, 0), pose = POSES.sit })
	dress(5, { pos = tileWorld(layout, 6, 8), face = V3.new(0, 0, 1), pose = POSES.wave })
	for _, g in { tileWorld(layout, 3, 10), tileWorld(layout, 10, 3) } do
		glow(g + V3.new(0, 4.5, 0), C.warm, 20, 1.2)
	end
	local cam = layout.center + V3.new(-40, 20, 44)
	shot("08_legendary_vessel", cam, layout.center + V3.new(0, 5, 0), 50, tileWorld(layout, 6, 6) + V3.new(0, 4, 0))
end

-- 09 The cast: everyone that lives out there, on Gull Rock's shore -------------------------------------------------------------
if wants("09") then
	clear()
	light("day", { clock = 14 })
	local layout = OceanLayout.plot(2)
	local built = IslandBuilder.build("rocky", layout.islandCenter, Random.new(11), islands)
	local c = built.center
	local toward = -layout.out
	local side = V3.new(-toward.Z, 0, toward.X)
	local line = { "reef_crab", "gull", "mire_lurker", "lava_beetle", "frost_wolf", "ruin_guardian" }
	for i, kind in line do
		local p = c + toward * 26 + side * ((i - 3.5) * 7)
		local y = built.ground(p.X, p.Z) or WATER + 1
		creature(kind, V3.new(p.X, y + (kind == "gull" and 0 or 1), p.Z), toward, i == 3 and "tell" or "idle", false)
	end
	local sharkAt = c + toward * 46 + side * -14
	creature("shark", V3.new(sharkAt.X, WATER - 0.2, sharkAt.Z), side, "surface", true)
	local serpAt = c + toward * 50 + side * 12
	creature("sea_serpent", V3.new(serpAt.X, WATER + 0.5, serpAt.Z), -side, "surface", true)
	splash(V3.new(sharkAt.X, WATER, sharkAt.Z), 6, 1.2)
	splash(V3.new(serpAt.X, WATER, serpAt.Z), 8, 1.6)
	local cam = c + toward * 52 + V3.new(0, 9, 0)
	shot("09_the_cast", cam, c + toward * 22 + V3.new(0, 3, 0), 56, c + toward * 26 + V3.new(0, 2, 0))
end

-- 10 The ocean from above: six plots, rafts, an island or two, the horizon's isles -------------------------------------------
if wants("10") then
	clear()
	-- a thin haze: from up here the plots are 600 studs off and the usual atmosphere would wash them out
	light("day", { clock = 9, atmosphere = { density = 0.1 } })
	raft(
		1,
		join(square(5, 5, 4), { { "sail", 7, 7, 1 }, { "helm", 5, 5, 1 } }),
		{ sail = "red", banner = "red", flag = "red", deck = "natural" }
	)
	raft(2, square(6, 6, 2), WHITE)
	raft(
		3,
		join(
			square(4, 4, 6),
			{ { "sail", 7, 7, 1 }, { "crow_nest", 8, 8, 2 }, { "stairs", 8, 7, 1 }, { "floor", 8, 8, 2 } }
		),
		{ sail = "blue", banner = "blue", flag = "blue", deck = "dark" }
	)
	raft(4, join(square(5, 5, 3), { { "helm", 6, 8, 1 } }), WHITE)
	raft(
		5,
		join(square(5, 5, 4), { { "sail", 7, 7, 1 } }),
		{ sail = "gold", banner = "gold", flag = "gold", deck = "white" }
	)
	raft(6, square(6, 6, 2), WHITE)
	IslandBuilder.build("tropical", OceanLayout.plot(1).islandCenter, Random.new(3), islands)
	IslandBuilder.build("rocky", OceanLayout.plot(3).islandCenter, Random.new(4), islands)
	for p = 1, 6 do
		drift(p, 5, 28)
	end
	shot("10_the_ocean", V3.new(-200, 150, 430), V3.new(20, 0, 30), 54, V3.new(280, 2, 60))
end

-- (render.js reads the list)
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print(#shots .. " shots written to " .. outDir)

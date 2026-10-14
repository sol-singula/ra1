--[[
Store thumbnails and screenshots (master plan §2, store presentation: the monster pursuing players, the camp and the
survival objective, equipment and loot, cooperation and the final encounter). Staged scenes made from the game's own
models (the forest and the camp from MapBuilder and CampModels, the monsters from Rigs, items from ItemModels, looks
from Looks, the telegraphs' shapes), with survivors as plain blocky Roblox avatars posed by hand, and no UI.
Snapshots are marked cinematic so render.js also writes a depth pass; thumbs_post.py adds the "shader" look.

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
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local CampModels = Engine.require(tree.shared.World.CampModels)
local FindingModels = Engine.require(tree.shared.World.FindingModels)
local ItemModels = Engine.require(tree.shared.World.ItemModels)
local Looks = Engine.require(tree.shared.World.Looks)
local Rigs = Engine.require(tree.shared.World.Rigs)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local Items = Engine.require(tree.shared.Data.Items)
local Kit = Engine.require(tree.shared.World.Kit)
local C, M = Kit.C, Kit.M
local ws = Engine.workspace

MapBuilder.build()
local cast = Instance.new("Folder", ws)
cast.Name = "Cast"
local fxFolder = Instance.new("Folder", ws)
fxFolder.Name = "Fx"
local structures = ws:FindFirstChild("Structures") or Instance.new("Folder", ws)
structures.Name = "Structures"
local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer
local rng = Random.new(67)

local function ground(x, z, up)
	return V3.new(x, MapLayout.floorY(x, z) + (up or 0), z)
end
local function clear()
	for _, f in { cast, fxFolder, structures } do
		for _, c in f:GetChildren() do
			c:Destroy()
		end
	end
end
-- Trees and undergrowth out of the way of a shot (they grow back for the next one: the map is rebuilt only once,
-- so this just hides them).
local hidden = {}
local function clearTrees(center, radius)
	for _, t in MapLayout.trees() do
		if (V3.new(t.x, 0, t.z) - V3.new(center.X, 0, center.Z)).Magnitude < radius then
			local m = MapBuilder.tree(t.id)
			if m and m.Parent then
				table.insert(hidden, { m, m.Parent })
				m.Parent = nil
			end
		end
	end
	for _, d in Engine.game:GetService("CollectionService"):GetTagged("Detail") do
		if d.Parent and d:IsA("BasePart") and (d.Position - center).Magnitude < radius then
			table.insert(hidden, { d, d.Parent })
			d.Parent = nil
		end
	end
end
local function restoreTrees()
	for _, h in hidden do
		h[1].Parent = h[2]
	end
	table.clear(hidden)
end

-- Survivors: blocky Roblox avatars, posed by hand --------------------------------------------------------------------------
local SKINS = { rgb(255, 214, 176), rgb(234, 184, 146), rgb(198, 142, 100), rgb(142, 96, 64), rgb(255, 226, 196) }
local function mk(parent, name, cf, size, color, material, shape)
	local p = Kit.box(parent, name, cf, size, color, material or M.SmoothPlastic, { CanCollide = false })
	if shape then
		p.Shape = Enum.PartType[shape]
	end
	return p
end
-- Weld targets follow their Part0 (what Roblox does; the looks are welded to the head and torso).
local function resolveWelds(model)
	for _, w in model:GetDescendants() do
		if w.ClassName == "Weld" and w.Part0 and w.Part1 then
			local c1 = w.C1 or CF.new()
			w.Part1.CFrame = w.Part0.CFrame * (w.C0 or CF.new()) * c1:Inverse()
		end
	end
end
--[[ spec = { pos, face (direction), shirt, pants, skin (1-5), hair (Color3 | false), look (key) | looks ({ keys }),
  hold (item key, right hand), holdL (item key, left hand),
  pose = { armR, armL (pitch: + is forward/up), rollR, rollL (out to the side), legR, legL, lean (- is forward),
           twist, turn (the head), nod } ]]
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
	-- legs from the hips (they don't lean)
	local function limb(name, pivot, pitch, roll, size, color)
		local at = pivot * CF.Angles(pitch or 0, 0, roll or 0)
		mk(m, name, at * CF.new(0, -size.Y / 2 + 0.1, 0), size, color)
		return at
	end
	limb("LeftLeg", base * CF.new(-0.5, 2, 0), pose.legL, 0, V3.new(1, 2, 1), pants)
	limb("RightLeg", base * CF.new(0.5, 2, 0), pose.legR, 0, V3.new(1, 2, 1), pants)
	-- shoes
	local hips = base * CF.new(0, 2, 0) * CF.Angles(pose.lean or 0, pose.twist or 0, 0)
	local torso = mk(m, "UpperTorso", hips * CF.new(0, 1, 0), V3.new(2, 2, 1), shirt)
	mk(m, "Belt", hips * CF.new(0, 0.15, 0), V3.new(2.02, 0.3, 1.02), pants:Lerp(rgb(20, 20, 26), 0.4))
	-- the head: a rounded cylinder (an invisible box keeps the looks' welds square)
	local headCF = hips * CF.new(0, 2.65, 0) * CF.Angles(pose.nod or 0, pose.turn or 0, 0)
	local head = mk(m, "Head", headCF, V3.new(1.2, 1.2, 1.2), skin)
	head.Transparency = 1
	mk(m, "HeadShape", headCF * CF.Angles(0, 0, math.rad(90)), V3.new(1.2, 1.3, 1.3), skin, M.SmoothPlastic, "Cylinder")
	for _, x in { -0.24, 0.24 } do
		mk(m, "Eye", headCF * CF.new(x, 0.12, -0.62), V3.new(0.16, 0.26, 0.08), rgb(24, 24, 32))
	end
	mk(m, "Smile", headCF * CF.new(0, -0.22, -0.63), V3.new(0.46, 0.09, 0.06), rgb(24, 24, 32))
	if spec.hair ~= false and not spec.look then
		local hair = spec.hair or rgb(70, 46, 30)
		mk(m, "Hair", headCF * CF.new(0, 0.62, 0.05), V3.new(1.36, 0.36, 1.36), hair, M.Fabric)
		mk(m, "HairBack", headCF * CF.new(0, 0.2, 0.6), V3.new(1.34, 0.9, 0.24), hair, M.Fabric)
	end
	-- arms from the shoulders, a hand at the end of each
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
		model:PivotTo(hand * ItemModels.holdCFrame(item, nil)) -- (the game's own weld)
		Engine.resolveWelds()
	end
	if spec.hold then
		hold(spec.hold, handR)
	end
	if spec.holdL then
		hold(spec.holdL, handL)
	end
	for _, key in spec.looks or { spec.look } do
		Looks.wear(m, key)
	end
	resolveWelds(m)
	_ = torso
	return m
end

local POSES = {
	stand = {},
	run = { armR = 0.95, armL = -0.85, legR = -0.75, legL = 0.75, lean = -0.22 },
	runBack = { armR = -0.7, armL = 0.9, legR = 0.7, legL = -0.6, lean = -0.18, turn = 0.9 },
	chop = { armR = 2.7, armL = 2.4, rollL = -0.25, lean = 0.08 },
	strike = { armR = 1.35, armL = 0.6, legR = 0.3, legL = -0.25, lean = -0.18 },
	torchUp = { armL = 2.4, rollL = 0.15, armR = 0.3, legR = 0.15, legL = -0.15 },
	aim = { armR = 1.45, armL = 1.6, rollL = -0.35, twist = 0.35, turn = -0.3 },
	dodge = { armR = 1.2, armL = -0.5, rollR = 0.5, rollL = 0.6, legR = 0.9, legL = -0.4, lean = -0.45 },
	cheer = { armR = 2.9, armL = 2.9, rollR = 0.3, rollL = 0.3 },
	sixseven = { armR = 1.25, armL = 1.05, rollR = -0.1, rollL = -0.1 },
	carry = { armR = 1.1, armL = 1.1, rollR = -0.25, rollL = -0.25, lean = 0.06 },
	open = { armR = 1.9, armL = 1.9, rollR = -0.2, rollL = -0.2, lean = -0.3 },
	brace = { armR = 1.6, armL = 1.2, legR = 0.45, legL = -0.45, lean = -0.12 },
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

-- Monsters --------------------------------------------------------------------------------------------------------------------
local function monster(kind, pos, facing, pose, opts)
	local rig = Rigs.build(kind, opts or {}, cast)
	local root = CF.lookAt(pos, pos + V3.new(facing.X, 0, facing.Z))
	Rigs.place(rig, root, pose or {})
	return rig
end

-- Effects, made of the same shapes the client's effects use ---------------------------------------------------------------------
local RED = rgb(255, 52, 52)
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
local function chips(pos, n)
	for _ = 1, n or 8 do
		local s = rng:NextNumber(0.25, 0.5)
		chunk(
			pos + V3.new(rng:NextNumber(-1.4, 1.4), rng:NextNumber(-0.3, 1.6), rng:NextNumber(-1.4, 1.4)),
			V3.new(s, s * 0.6, s * 1.3),
			({ C.woodLight, C.bark, C.wood })[rng:NextInteger(1, 3)]
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
local function puff(pos, n, size, color)
	for _ = 1, n or 6 do
		local s = rng:NextNumber(0.6, 1.2) * (size or 2.5)
		chunk(
			pos + V3.new(rng:NextNumber(-2, 2), rng:NextNumber(0, 1.2), rng:NextNumber(-2, 2)),
			V3.new(s, s, s),
			color or C.cream,
			M.SmoothPlastic,
			"Ball",
			0.4
		)
	end
end
-- the telegraphs: a red strip that fills, a red circle that fills
local function redLine(from, dir, length, width, fill)
	local flat = V3.new(dir.X, 0, dir.Z).Unit
	local base = ground(from.X, from.Z, 0.25)
	Kit.box(
		fxFolder,
		"Tell",
		CF.lookAt(base + flat * length / 2, base + flat * length),
		V3.new(width, 0.12, length),
		RED,
		M.Neon,
		{ CanCollide = false, CastShadow = false, Transparency = 0.55 }
	)
	local fl = length * (fill or 0.7)
	Kit.box(
		fxFolder,
		"TellFill",
		CF.lookAt(base + flat * fl / 2 + V3.new(0, 0.02, 0), base + flat * length + V3.new(0, 0.02, 0)),
		V3.new(width * 0.92, 0.16, fl),
		RED,
		M.Neon,
		{ CanCollide = false, CastShadow = false, Transparency = 0.12 }
	)
end
local function redCircle(center, radius, fill, color)
	local base = ground(center.X, center.Z, 0.25)
	local o = Kit.cyl(
		fxFolder,
		"Tell",
		CF.new(base) * CF.Angles(0, 0, math.rad(90)),
		0.12,
		radius * 2,
		color or RED,
		M.Neon,
		{ CanCollide = false, CastShadow = false, Transparency = 0.7 }
	)
	local d = radius * 2 * (fill or 0.7)
	local i = Kit.cyl(
		fxFolder,
		"TellFill",
		CF.new(base + V3.new(0, 0.02, 0)) * CF.Angles(0, 0, math.rad(90)),
		0.16,
		d,
		color or RED,
		M.Neon,
		{ CanCollide = false, CastShadow = false, Transparency = 0.35 }
	)
	_ = o
	_ = i
end
local function glow(pos, color, range, brightness)
	local p = chunk(pos, V3.new(0.3, 0.3, 0.3), color, M.Neon, nil, 1)
	local l = Instance.new("PointLight", p)
	l.Color = color
	l.Range = range or 20
	l.Brightness = brightness or 2
	return p
end
local function speech(model, text, height)
	local anchor = model.PrimaryPart
	local bb = Instance.new("BillboardGui")
	bb.Size = Engine.globals.UDim2.fromOffset(340, 80)
	bb.StudsOffsetWorldSpace = V3.new(0, height or 6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = anchor
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = Engine.globals.UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = rgb(190, 255, 110)
	label.TextStrokeTransparency = 0
	label.Parent = bb
end

-- The camp at a tier (every structure of that tier built, walls of stone from the Fort on; blueprints for the next if
-- asked) ----------------------------------------------------------------------------------------------------------------------------
local CampData = Engine.require(tree.shared.Data.Camp)
local function camp(tier, opts)
	opts = opts or {}
	local fire = ws.Map.Camp:FindFirstChild("Campfire")
	if fire then
		local cf = fire:GetPivot()
		fire:Destroy()
		CampModels.build(
			"fire",
			CF.new(MapLayout.CAMP_PROPS.fire),
			{ parent = ws.Map.Camp, name = "Campfire", tier = tier }
		)
		_ = cf
	end
	for _, s in MapLayout.campSlots do
		local def = CampData.STRUCTURES[s.key]
		local t = def and def.tier or 1
		if t <= tier or (opts.blueprints and t == tier + 1) then
			if CampModels.has(s.key) then
				CampModels.build(s.key, s.cf, {
					parent = structures,
					width = s.width,
					tier = tier,
					upgraded = def and def.upgrade and tier >= def.upgrade.tier,
					ghost = t > tier,
				})
			end
		end
	end
end

-- Lighting for pictures: the game's presets, tweaked (brighter nights read better as a small picture) ------------------------------------
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
-- (only: a part of a shot's name, or several separated by commas)
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

-- A spot in the forest with trees round it: angle (deg) and distance from the fire
local function forestSpot(aDeg, r)
	local p = MapLayout.polar(aDeg, r)
	return ground(p.X, p.Z)
end

-- Moonlight for pictures: the game's night, a little bluer and darker than the playing preset, with the torches and the
-- fire doing the lighting
local NIGHT = { brightness = 1.1, ambient = rgb(56, 64, 104), outdoor = rgb(70, 82, 130), exposure = 0.1 }
local function at2(v)
	return ground(v.X, v.Z)
end

-- 1. Kermy's coming: night on a forest trail, three survivors running for camp with a torch, Kermy right behind -------
if wants("01_kermy_chase") then
	clear()
	light("night", NIGHT)
	local at = forestSpot(200, 128)
	local toCamp = (V3.new(0, at.Y, 0) - at).Unit
	local side = V3.new(-toCamp.Z, 0, toCamp.X)
	clearTrees(at + toCamp * 6, 16)
	-- the runners spread across the trail, Kermy in the gap between them
	dress(1, {
		pos = at2(at + toCamp * 7.5 + side * 3.6),
		face = toCamp + side * 0.15,
		holdL = "torch",
		hold = "rusty_axe",
		pose = POSES.runBack,
	})
	dress(
		2,
		{ pos = at2(at + toCamp * 9 - side * 3.4), face = toCamp - side * 0.1, pose = POSES.run, look = "ranger_hat" }
	)
	dress(3, {
		pos = at2(at + toCamp * 5 - side * 6.2),
		face = toCamp - side * 0.2,
		pose = POSES.run,
		looks = { "camp_pack" },
	})
	monster("kermy", at2(at - toCamp * 1), toCamp, { state = "chase", walk = 1.4, stride = 1, t = 0.3 })
	glow(at + toCamp * 7 + side * 3 + V3.new(0, 4, 0), rgb(255, 160, 80), 24, 2.4)
	glow(at - toCamp * 1 + V3.new(0, 9, 3), rgb(150, 170, 255), 18, 0.8) -- moonlight on him
	local cam = at + toCamp * 19 + side * 1.5 + V3.new(0, 2.6, 0)
	shot("01_kermy_chase", cam, at + toCamp * 2 + V3.new(0, 4.4, 0), 50, at + toCamp * 4 + V3.new(0, 3, 0))
	restoreTrees()
end

-- 2. SIX... SEVEN!: Kermy's tell, the red line on the ground, a survivor rolling out of the way -------------------------------------
if wants("02_sixseven") then
	clear()
	light("night", NIGHT)
	local at = forestSpot(300, 110)
	local dir = V3.new(1, 0, 0.3).Unit
	local side = V3.new(-dir.Z, 0, dir.X)
	clearTrees(at + dir * 6, 16)
	monster("kermy", at, dir, { state = "tell", tell = "sixseven", t = 0.45, f = 0.8 })
	redLine(at + dir * 1.5, dir, 17, 4, 0.8)
	-- the target rolls sideways out of the line; a friend with a torch shouts
	dress(1, { pos = at2(at + dir * 12 + side * 3.4), face = side, hold = "stone_spear", pose = POSES.dodge })
	dress(5, {
		pos = at2(at + dir * 17 - side * 4),
		face = -dir + side * 0.4,
		holdL = "torch",
		hold = "branch_club",
		pose = POSES.brace,
	})
	glow(at + dir * 14 + V3.new(0, 4, 0), rgb(255, 160, 80), 22, 2)
	glow(at + V3.new(0, 10, 0) - side * 4, rgb(150, 170, 255), 18, 0.9)
	local cam = at + dir * 7 - side * 11 + V3.new(0, 3, 0)
	shot("02_sixseven", cam, at + dir * 6.5 + V3.new(0, 3.4, 0), 58, at + dir * 3 + V3.new(0, 4, 0))
	restoreTrees()
end

-- 3. The camp at night: the walls, the fire roaring, survivors round it, wolves' red eyes outside -----------------------------------
if wants("03_camp_night") then
	clear()
	camp(3)
	light("night", NIGHT)
	local fire = MapLayout.CAMP_PROPS.fire
	dress(
		1,
		{ pos = ground(fire.X + 6, fire.Z + 3), face = V3.new(-0.4, 0, 1), hold = "stone_axe", pose = POSES.brace }
	)
	dress(2, {
		pos = ground(fire.X - 5, fire.Z + 4.5),
		face = V3.new(-0.5, 0, 1),
		holdL = "torch",
		pose = POSES.torchUp,
		look = "ranger_hat",
	})
	dress(3, { pos = ground(fire.X + 1, fire.Z - 6.5), face = V3.new(0, 0, 1), hold = "wood", pose = POSES.carry })
	dress(4, {
		pos = ground(fire.X - 1, fire.Z + 9),
		face = V3.new(-0.5, 0, 1),
		hold = "short_bow",
		pose = POSES.aim,
		looks = { "lantern_pack" },
	})
	-- grinwolves just outside the wall on our side, eyes red
	for k, a in { 116, 128, 104 } do
		local p = MapLayout.polar(a, 46 + k * 2)
		local wolf =
			monster("grinwolf", ground(p.X, p.Z), V3.new(-p.X, 0, -p.Z), { state = "circle", walk = k, stride = 0.4 })
		Rigs.setEyes(wolf, RED)
	end
	local cam = V3.new(-26, 30, 58)
	shot("03_camp_night", cam, V3.new(0, 2, 6), 50, V3.new(0, 3, 4))
end

-- 4. Day: building the camp up (a wall rising out of its blueprint), hauling wood, chopping at the edge ------------------------
if wants("04_build") then
	clear()
	camp(1)
	light("day", { clock = 15.5, exposure = 0.05, atmosphere = { density = 0.22, haze = 0.6 } })
	local wall = MapLayout.slotsByKey.wall[2]
	local wp = wall.pos
	local inward = (V3.new(0, 0, 0) - V3.new(wp.X, 0, wp.Z)).Unit
	local along = V3.new(-inward.Z, 0, inward.X)
	for _, i in { 1, 3, 4 } do
		local w = MapLayout.slotsByKey.wall[i]
		CampModels.build("wall", w.cf, { parent = structures, width = w.width, ghost = true })
	end
	CampModels.build("wall", wall.cf, { parent = structures, width = wall.width, ghost = true })
	-- the wall half built: the real thing rising out of the ground inside its blueprint
	local rising = CampModels.build("wall", wall.cf, { parent = structures, width = wall.width })
	rising:PivotTo(rising:GetPivot() * CF.new(0, -2.6, 0))
	dress(1, { pos = at2(wp + inward * 3 + along * 1.5), face = -inward, hold = "iron_hammer", pose = POSES.chop })
	sparkles(wp + V3.new(0, 3.2, 0) + inward * 1.4 + along * 1.5, C.gold, 12, 1.4)
	dress(6, {
		pos = at2(wp + inward * 3.5 - along * 3),
		face = -inward + along * 0.3,
		hold = "stone_axe",
		pose = POSES.strike,
	})
	chips(wp + V3.new(0, 2.8, 0) + inward * 1.6 - along * 3, 6)
	dress(2, {
		pos = at2(wp + inward * 6.5 + along * 6),
		face = -inward + along * -0.5,
		hold = "wood",
		pose = POSES.carry,
		look = "ranger_hat",
	})
	-- the workbench and someone at it
	local bench = MapLayout.slotsByKey.workbench[1]
	dress(3, {
		pos = ground(bench.pos.X - 2.5, bench.pos.Z + 2.5),
		face = V3.new(0.6, 0, -1),
		hold = "stone_axe",
		pose = POSES.stand,
	})
	local cam = wp + inward * 19 + along * 1 + V3.new(0, 7.5, 0)
	shot("04_build", cam, wp + inward * 2.5 + along * 1.5 + V3.new(0, 2.4, 0), 52, wp + inward * 3 + V3.new(0, 3, 0))
end

-- 5. Loot: a chest bursting open with a legendary bow inside, a teammate holding up a new axe -----------------------------------------
if wants("05_loot") then
	clear()
	light("day", { clock = 14.6, exposure = 0.1, atmosphere = { density = 0.2, haze = 0.5 } })
	local at = forestSpot(40, 140)
	local camDir = V3.new(0, 0, -1) -- the camera is south of the chest, looking north at it
	clearTrees(at, 12)
	-- the chest faces the camera; its lid thrown back
	local chestCF = CF.lookAt(at, at - camDir) -- its front (-Z) toward the camera, the hinge at the back
	Kit.box(cast, "Chest", chestCF * CF.new(0, 1, 0), V3.new(3.6, 2, 2.4), C.wood, M.WoodPlanks)
	Kit.box(
		cast,
		"Lid",
		chestCF * CF.new(0, 2.15, 1.2) * CF.Angles(math.rad(105), 0, 0) * CF.new(0, 0, -1.25),
		V3.new(3.8, 0.4, 2.6),
		C.woodDark,
		M.Wood
	)
	Kit.box(cast, "Gold", chestCF * CF.new(0, 2.05, 0), V3.new(3.2, 0.3, 2), C.gold, M.Neon)
	for _, x in { -1.3, 1.3 } do
		Kit.box(cast, "Band", chestCF * CF.new(x, 1.3, 0), V3.new(0.3, 2.7, 2.6), C.gold, M.Metal)
	end
	sparkles(at + V3.new(0, 2.6, 0), C.gold, 24, 1.6)
	glow(at + V3.new(0, 3, 0), rgb(255, 210, 90), 18, 3)
	ItemModels.dropped(Items.get("moonshot"), CF.new(at + V3.new(0, 5, 0.6)) * CF.Angles(0, 0, math.rad(-35)), cast)
	-- either side of the chest: one jumping for joy, one holding up a crystal axe
	dress(1, { pos = ground(at.X - 3.8, at.Z - 1.6), face = V3.new(0.35, 0, 1), pose = POSES.cheer })
	dress(3, {
		pos = ground(at.X + 3.8, at.Z - 2.2),
		face = V3.new(-0.35, 0, 1),
		hold = "crystal_axe",
		pose = POSES.chop,
		look = "leaf_crown",
	})
	-- more loot on the ground with its rarity beams
	ItemModels.dropped(Items.get("iron_plate"), CF.new(ground(at.X - 5, at.Z + 1, 0.4)), cast)
	ItemModels.dropped(Items.get("hunter_bow"), CF.new(ground(at.X + 5.5, at.Z + 2, 0.4)), cast)
	ItemModels.dropped(Items.get("medkit"), CF.new(ground(at.X - 3, at.Z + 4.5, 0.4)), cast)
	local cam = at + V3.new(0.5, 4.2, 12)
	shot("05_loot", cam, at + V3.new(0, 2.8, 0), 55, at + V3.new(0, 2.5, 0))
	restoreTrees()
end

-- 6. Mega Kermy: night 7, the team in front of an Ancient Pine, baiting his charge ----------------------------------------------------
if wants("06_mega_kermy") then
	clear()
	camp(4)
	light("boss", { brightness = 1.3, exposure = 0.15 })
	local pine = MapLayout.ancientPines[3]
	local out = V3.new(pine.pos.X, 0, pine.pos.Z).Unit
	local side = V3.new(-out.Z, 0, out.X)
	local bossAt = pine.pos + out * 30
	clearTrees(pine.pos + out * 16, 26)
	local boss = monster("mega_kermy", at2(bossAt), -out, { state = "tell", tell = "sixseven", t = 0.4 })
	Rigs.setWeak(boss, true, 0.2)
	-- the team between him and the pine (his charge will hit the tree)
	local front = pine.pos + out * 7
	for k, spec in
		{
			{ 0, "iron_spear", POSES.brace },
			{ 4, "hunter_bow", POSES.aim },
			{ -4, "boulder_maul", POSES.strike },
			{ 7.5, nil, POSES.torchUp },
		}
	do
		local p = front + side * spec[1] - out * (k % 2) * 2
		dress(k, {
			pos = at2(p),
			face = out,
			hold = spec[2],
			holdL = spec[2] == nil and "torch" or nil,
			pose = spec[3],
			look = k == 2 and "crown_67" or nil,
			looks = k == 3 and { "golden_67" } or nil,
		})
	end
	redLine(bossAt - out * 3, -out, 26, 9, 0.5)
	local cam = pine.pos + side * 25 - out * 7 + V3.new(0, 6.5, 0)
	shot("06_mega_kermy", cam, bossAt + V3.new(0, 11, 0) - out * 12, 60, front + V3.new(0, 3, 0))
	restoreTrees()
end

-- 7. The monster line-up by day ---------------------------------------------------------------------------------------------------------------
if wants("07_monsters") then
	clear()
	light("day", { clock = 12.5, exposure = 0.05, atmosphere = { density = 0.18, haze = 0.4 } })
	local cx, cz = 8, 56
	local function put(kind, x, z, pose, opts)
		return monster(kind, ground(cx + x, cz + z), V3.new(0, 0, -1), pose, opts)
	end
	put("kermy", -11, 0, { state = "tell", tell = "sixseven", t = 0.3 })
	put("snapcap", -5, -2, { state = "idle" })
	put("grinwolf", -1, -1, { state = "idle" })
	put("grinwolf", 3.5, 1, { state = "idle" }, { elite = true })
	put("pelter", 8, -2, { state = "tell" })
	put("stumpy", 13, 0, { state = "idle" })
	put("mimic", -7.5, -5, { state = "tell" })
	local y0 = MapLayout.floorY(cx, cz)
	shot("07_monsters", V3.new(cx + 1, y0 + 6, cz - 21), V3.new(cx + 1, y0 + 2.8, cz), 54)
end

-- 8. The forest from above at dusk: the camp's fire in its clearing, trees as far as you can see --------------------------------------------
if wants("08_forest") then
	clear()
	camp(2)
	light("dusk", { exposure = 0.15 })
	shot("08_forest", V3.new(-115, 95, 150), V3.new(0, 0, 0), 50, V3.new(0, 0, 0))
end

-- 9. A finding in the forest: the ice cream truck, two survivors poking round it ---------------------------------------------------------------
if wants("09_finding") then
	clear()
	light("day", { clock = 11, exposure = 0.05, atmosphere = { density = 0.22, haze = 0.5 } })
	local at = forestSpot(150, 175)
	clearTrees(at, 16)
	FindingModels.build("ice_cream_truck", CF.lookAt(at, at + V3.new(1, 0, 0)), Random.new(3), cast)
	dress(2, {
		pos = ground(at.X - 9, at.Z + 3),
		face = V3.new(1, 0, -0.3),
		holdL = "torch",
		pose = POSES.stand,
		look = "ranger_hat",
	})
	dress(
		6,
		{ pos = ground(at.X - 7.5, at.Z + 7.5), face = V3.new(0.4, 0, -1), hold = "ice_cream", pose = POSES.sixseven }
	)
	shot("09_finding", at + V3.new(-14, 7, 26), at + V3.new(-2, 3, 0), 55)
	restoreTrees()
end

-- 10. Dawn: the team does the 6-7 by the fire --------------------------------------------------------------------------------------------------------
if wants("10_dawn") then
	clear()
	camp(3)
	light("dawn", { exposure = 0.15 })
	local fire = MapLayout.CAMP_PROPS.fire
	for k = 1, 5 do
		local a = math.rad(-30 + k * 30)
		local p = V3.new(math.cos(a) * 7, 0, math.sin(a) * 7) + V3.new(fire.X, 0, fire.Z)
		dress(k, {
			pos = ground(p.X, p.Z),
			face = V3.new(0, 0, 1),
			pose = k % 2 == 0 and POSES.sixseven or POSES.cheer,
			look = k == 3 and "crown_67" or nil,
		})
	end
	shot("10_dawn", V3.new(fire.X + 2, 6, fire.Z + 24), V3.new(fire.X, 3, fire.Z + 5), 52)
end

-- 11. Kermy close up (the icon's reference): "SIX... SEVEN!" at night, lit by a torch ---------------------------------------------------
if wants("11_kermy_portrait") then
	clear()
	light("night", NIGHT)
	local at = forestSpot(240, 120)
	local face = V3.new(0, 0, 1)
	clearTrees(at + face * 4, 10)
	monster("kermy", at, face, { state = "tell", tell = "sixseven", t = 0.35, f = 0.9 })
	glow(at + face * 4 + V3.new(2.5, 6, 0), rgb(255, 170, 90), 16, 2.6)
	glow(at + face * 3 + V3.new(-3, 8, 0), rgb(150, 170, 255), 14, 1.2)
	shot("11_kermy_portrait", at + face * 9.5 + V3.new(0, 6.4, 0), at + V3.new(0, 6, 0), 42)
	restoreTrees()
end

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))

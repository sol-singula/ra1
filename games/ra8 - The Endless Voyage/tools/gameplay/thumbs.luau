--[[
Store thumbnails and screenshots (master plan §1-§10: the raft at the centre, collecting, building, sailing,
islands, wrecks, the creatures, the Leviathan; and the game's mysteries: the bottle with a chart in it, Mist
Hollow's empty huts, the ship frozen into the Frost Shelf, the Ruin's totems, the shape that passes under the raft,
the fortress in the fog). Staged scenes made from the game's own models (the ocean from OceanBuilder, rafts from
RaftModels at the grid's real positions, islands from IslandBuilder, debris from OceanModels, creatures from Rigs,
items from ItemModels), with survivors as plain blocky Roblox avatars posed by hand, and no UI. Snapshots are marked
cinematic so render.js also writes a depth pass; thumbs_post.py adds the "shader" look.

Each shot prints where its survivors and creatures land in the frame (0-1 across, 0-1 down) and flags anything cut
by the edge, so a framing can be checked before the minute-long render.

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

-- The deep water. The renderer's water is see-through, so the sea floor 34 studs down showed through it, lit, and
-- the sea round a raft looked like a sandbar. An opaque deep-blue plane just under the surface hides the floor in
-- every shot (the islands' shallows stay above it). It has its own folder, which clear() leaves alone.
local terrainInst = ws:FindFirstChildOfClass("Terrain")
local WATER_TRANSPARENCY = terrainInst.WaterTransparency
local deepFolder = Instance.new("Folder", ws)
deepFolder.Name = "DeepWater"
local DEEP_Y, DEEP_COLOR = WATER - 8, rgb(14, 62, 92)
local deep = Kit.box(
	deepFolder,
	"Deep",
	CF.new(0, DEEP_Y, 0),
	V3.new(Constants.OCEAN_SIZE, 0.5, Constants.OCEAN_SIZE),
	DEEP_COLOR,
	M.SmoothPlastic,
	{ CanCollide = false, CastShadow = false }
)
-- the ocean's own terrain (the sea floor and the water): each shot starts from just this
local baseOps = #Engine.terrain.ops

local function clear()
	for _, f in { cast, fxFolder, rafts, islands, debrisFolder } do
		for _, c in f:GetChildren() do
			c:Destroy()
		end
	end
	-- the last shot's islands go (the renderer reads every terrain fill in order, so an old island's land would
	-- still be there under the next one), and the water is the usual water again
	local ops = Engine.terrain.ops
	for i = #ops, baseOps + 1, -1 do
		ops[i] = nil
	end
	terrainInst.WaterTransparency = WATER_TRANSPARENCY
	deep.CFrame = CF.new(0, DEEP_Y, 0)
	deep.Color = DEEP_COLOR
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
local function flat(v)
	return V3.new(v.X, 0, v.Z).Unit
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
-- The far end of a held rod's tip (the held rod has a part "Tip", a cylinder along its local X): where the line
-- starts. nil if the survivor holds no rod.
local function rodTip(survivorModel)
	for _, held in survivorModel:GetChildren() do
		local tip, grip = held:FindFirstChild("Tip"), held:FindFirstChild("Grip")
		if held.ClassName == "Model" and held:FindFirstChild("Reel") and tip and grip then
			local a = tip.CFrame:PointToWorldSpace(V3.new(tip.Size.X / 2, 0, 0))
			local b = tip.CFrame:PointToWorldSpace(V3.new(-tip.Size.X / 2, 0, 0))
			return (a - grip.Position).Magnitude > (b - grip.Position).Magnitude and a or b
		end
	end
	return nil
end
-- A rod in the hand has a short line hanging straight down from its tip with the bobber on it (FxController's idle
-- line: 1.3 studs, a red ball and a white top).
local function idleLine(tip)
	local hang = 1.3
	local still = { CanCollide = false, CastShadow = false }
	Kit.box(
		fxFolder,
		"Line",
		CF.new(tip - V3.new(0, hang / 2, 0)),
		V3.new(0.08, hang, 0.08),
		C.cream,
		M.SmoothPlastic,
		still
	)
	Kit.ball(fxFolder, "Bobber", tip - V3.new(0, hang, 0), 0.34, C.red, M.SmoothPlastic, still)
	Kit.ball(fxFolder, "BobberTop", tip - V3.new(0, hang - 0.18, 0), 0.26, C.white, M.SmoothPlastic, still)
end
--[[ spec = { name, pos, face (direction), shirt, pants, skin (1-5), hair (Color3 | false), hold (item key, right
  hand), holdL (item key, left hand), line (false: no idle line on a held rod, e.g. while it's cast),
  pose = { armR, armL (pitch: + is forward/up), rollR, rollL (out to the side, - across the body), wrist, wristL
  (the hand's pitch: what it holds tilts with it), legR, legL, lean (- is forward), twist, turn (the head), nod
  (+ looks up), drop (studs the body sits lower: sitting, kneeling) } }
A held item sits at hand * CFrame.Angles(wrist, 0, 0) * ItemModels.holdCFrame: a rod leaves the fist 40° above the
hand's forward, so its elevation is 40° + the arm's pitch + lean + wrist; a lantern hangs upright when arm + lean +
wrist is 90°. ]]
local function survivor(spec)
	local m = Instance.new("Model")
	m.Name = spec.name or "Survivor"
	m.Parent = cast
	local pose = spec.pose or {}
	local f = spec.face or V3.new(0, 0, -1)
	local pos = spec.pos - V3.new(0, pose.drop or 0, 0)
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
	local function hold(key, hand, wrist)
		local item = Items.get(key)
		if not item then
			return
		end
		local model = ItemModels.held(item, m)
		model:PivotTo(hand * CF.Angles(wrist or 0, 0, 0) * ItemModels.holdCFrame(item, nil))
		Engine.resolveWelds()
		return item
	end
	local rod = false
	for _, h in { { spec.hold, handR, pose.wrist }, { spec.holdL, handL, pose.wristL } } do
		local item = h[1] and hold(h[1], h[2], h[3])
		rod = rod or (item ~= nil and Items.toolKind(item) == "rod")
	end
	resolveWelds(m)
	if rod and spec.line ~= false then
		idleLine(rodTip(m))
	end
	return m, handR, handL
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
	-- planks carried flat in front: the wrists undo the arms' pitch
	carryPlanks = { armR = 1.0, armL = 1.0, rollR = -0.3, rollL = -0.3, lean = 0.06, wrist = -1.0, wristL = -1.0 },
	wave = { armR = 2.8, rollR = 0.4, armL = 0.1 },
	sit = { drop = 1.45, legR = 1.5, legL = 1.5, armR = 0.6, armL = 0.6 },
	-- the follow-through of a cast (AnimController's whip): the arm out in front, the wrist turned down so the rod
	-- points out over the water at about 25° (40° from the grip + 66° arm - 7° lean - 74° wrist)
	cast = {
		armR = 1.15,
		armL = 0.95,
		rollR = -0.08,
		rollL = -0.35,
		legR = 0.3,
		legL = -0.25,
		lean = -0.12,
		twist = 0.12,
		wrist = -1.3,
	},
	-- kneeling at the raft's edge, leaning out, a hand down to the water
	kneelReach = {
		drop = 1.5,
		legR = -1.45,
		legL = -1.45,
		lean = -0.9,
		armR = 1.2,
		armL = 0.7,
		rollR = -0.05,
		rollL = 0.25,
		nod = 0.1,
	},
	-- at the edge, looking down into the water
	peer = { lean = -0.38, nod = -0.5, armR = 0.3, armL = 0.3, rollR = 0.15, rollL = 0.15, legR = 0.1, legL = -0.1 },
	peerPoint = { lean = -0.35, nod = -0.45, armR = 1.2, armL = 0.25, rollR = -0.05, rollL = 0.15 },
	-- a lantern held out in front in the left hand (the wrist keeps it hanging upright)
	lantern = { armL = 1.35, wristL = 0.22, armR = 0.15, rollR = 0.08, legR = 0.2, legL = -0.15 },
	-- head back, looking up at something big
	lookUp = { nod = 0.42, armR = 0.12, armL = 0.12, rollR = 0.1, rollL = 0.1, lean = 0.05 },
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
-- (pitch tilts the whole rig nose-up: Rigs.place's own "surface" lean dips the nose)
local function creature(kind, pos, facing, state, moving, pitch)
	local model, offsets = Rigs.build(kind, cast)
	local cf = CF.lookAt(pos, pos + V3.new(facing.X, 0, facing.Z)) * CF.Angles(pitch or 0, 0, 0)
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
	local r = (size or 1) * 2.2
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local rr = r * rng:NextNumber(0.8, 1.15)
		local blob = Kit.ellipsoid(
			fxFolder,
			"Foam",
			V3.new(pos.X + math.cos(a) * rr, WATER + 0.05, pos.Z + math.sin(a) * rr),
			V3.new((size or 1) * rng:NextNumber(0.7, 1.2), 0.08, (size or 1) * 0.45),
			rgb(240, 248, 252),
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false, Transparency = 0.3 }
		)
		blob.CFrame = CF.new(blob.Position) * CF.Angles(0, -a + math.pi / 2, 0)
	end
end
-- A line from one point to another (a harpoon's rope, the turret's shot, the fishing line), sagging a little like
-- FxController's tether when `sag` is given (the drop at the middle, as a share of the length), in 8 pieces.
local function rope(from, to, color, width, sag)
	local n = sag and 8 or 1
	local drop = (to - from).Magnitude * (sag or 0)
	local prev = from
	for i = 1, n do
		local k = i / n
		local p = from:Lerp(to, k) - V3.new(0, 4 * drop * k * (1 - k), 0)
		local len = (p - prev).Magnitude
		Kit.box(
			fxFolder,
			"Rope",
			CF.lookAt(prev, p) * CF.new(0, 0, -len / 2),
			V3.new(width or 0.14, width or 0.14, len + 0.04),
			color or C.rope,
			M.Fabric,
			{ CanCollide = false, CastShadow = false }
		)
		prev = p
	end
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
-- A lantern post lit the way IslandService lights it (the glass turns warm Neon and gets a light).
local function lightLantern(model)
	local glass = model:FindFirstChild("Glass")
	if glass then
		glass.Color = rgb(255, 200, 90)
		glass.Material = M.Neon
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 200, 90)
		light.Range = 18
		light.Brightness = 1.5
		light.Parent = glass
	end
end
-- Children of an island's model by name (huts, walls, trees...).
local function propsNamed(built, name)
	local out = {}
	for _, c in built.model:GetChildren() do
		if c.Name == name then
			table.insert(out, c)
		end
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
-- the renderer's sun comes from this way (its azimuth is fixed): a camera on this side of a subject lights it
-- from the front, a camera looking this way sees it against the sun
local SUN = V3.new(-0.6374, 0, 0.7705)

-- Where a point lands in the frame (0-1 across, 0-1 down; nil behind the camera), the way render.js projects it.
local function screen(camPos, target, fov, p)
	local f = (target - camPos).Unit
	local r = f:Cross(V3.new(0, 1, 0)).Unit
	local u = r:Cross(f)
	local d = p - camPos
	local z = d:Dot(f)
	if z <= 0.1 then
		return nil
	end
	local t = math.tan(math.rad(fov) / 2)
	return 0.5 + d:Dot(r) / (z * t * 16 / 9) / 2, 0.5 - d:Dot(u) / (z * t) / 2, z
end
local function report(camPos, target, fov, marks)
	local function show(label, parts, head)
		local lo, hi, n = { 9, 9 }, { -9, -9 }, 0
		for _, d in parts do
			local half = d.Size / 2
			for _, k in
				{
					{ -1, -1, -1 },
					{ -1, -1, 1 },
					{ -1, 1, -1 },
					{ -1, 1, 1 },
					{ 1, -1, -1 },
					{ 1, -1, 1 },
					{ 1, 1, -1 },
					{ 1, 1, 1 },
				}
			do
				local x, y = screen(camPos, target, fov, d.CFrame * V3.new(half.X * k[1], half.Y * k[2], half.Z * k[3]))
				if x then
					n += 1
					lo = { math.min(lo[1], x), math.min(lo[2], y) }
					hi = { math.max(hi[1], x), math.max(hi[2], y) }
				end
			end
		end
		local flag = ""
		if n == 0 then
			flag = "  << BEHIND THE CAMERA"
		elseif lo[1] < 0.01 or hi[1] > 0.99 or lo[2] < 0.01 or hi[2] > 0.99 then
			flag = "  << CUT BY THE EDGE"
		end
		local hs = ""
		if head then
			local x, y, z = screen(camPos, target, fov, head.Position)
			hs = x and string.format("  head %.2f,%.2f at %.0f studs", x, y, z) or "  head behind"
			if x and (x < 0.03 or x > 0.97 or y < 0.03 or y > 0.97) then
				flag ..= "  << HEAD AT THE EDGE"
			end
		end
		print(string.format("    %-16s x %.2f-%.2f  y %.2f-%.2f%s%s", label, lo[1], hi[1], lo[2], hi[2], hs, flag))
	end
	for _, m in cast:GetChildren() do
		local parts = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (rawget(d, "_props").Transparency or 0) < 0.99 then
				table.insert(parts, d)
			end
		end
		show(m.Name, parts, m:FindFirstChild("Head"))
	end
	for label, p in marks or {} do
		local x, y, z = screen(camPos, target, fov, p)
		print(string.format("    %-16s %s", label, x and string.format("%.2f,%.2f at %.0f studs", x, y, z) or "behind"))
	end
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
local function shot(name, camPos, camTarget, fov, focus, marks)
	if not wants(name) then
		return
	end
	fov = fov or 50
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov,
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
	report(camPos, camTarget, fov, marks)
end

local WHITE = { sail = "white", banner = "white", flag = "white", deck = "natural" }

-- 01 The first cast: the 2 x 2 driftwood platform, the line from the rod's tip out to a plank drifting in -------------------
if wants("01") then
	clear()
	light("day")
	local layout = raft(1, square(6, 6, 2), WHITE)
	drift(1, 7, 24)
	-- the caster at the platform's upstream edge, casting at a plank coming in on the current
	local castDir = V3.new(-0.15, 0, -1).Unit
	local stand = tileWorld(layout, 7, 6) + V3.new(0.6, 0, -2.2)
	local target = stand + castDir * 15
	target = V3.new(target.X, WATER + 0.3, target.Z)
	OceanModels.debris("wood", CF.new(target) * CF.Angles(0, 0.8, 0), debrisFolder)
	local caster = dress(
		1,
		{ name = "Caster", pos = stand, face = castDir, pose = POSES.cast, hold = "fishing_rod", line = false }
	)
	local tip = rodTip(caster)
	rope(tip, target + V3.new(0, 0.6, 0), C.cream, 0.13, 0.03)
	splash(target, 8, 0.8)
	local right = V3.new(-castDir.Z, 0, castDir.X)
	local cam = stand + right * 12 + castDir * 1.5 + V3.new(0, 4.5, 0)
	-- a friend on the platform's far side, waving
	local friendAt = tileWorld(layout, 6, 7) + V3.new(0.5, 0, -0.5)
	dress(2, { name = "Friend", pos = friendAt, face = flat(cam - friendAt), pose = POSES.wave })
	local look = stand + castDir * 4 - right * 3 + V3.new(0, 0.5, 0)
	shot("01_first_cast", cam, look, 56, stand + V3.new(0, 2.5, 0), { tip = tip, plank = target })
end

-- 02 Building: a survival raft growing, a tile being hammered down, planks coming aboard -------------------------------------
if wants("02") then
	clear()
	light("day", { clock = 10.5 })
	local pieces = join(square(5, 5, 4), {
		{ "workbench", 6, 7, 1, 2 },
		{ "storage", 5, 5, 1, 0 },
		{ "bed", 6, 5, 1, 1 },
		{ "lamp", 5, 8, 1 },
		{ "railing", 5, 6, 1, 2 },
		{ "railing", 5, 7, 1, 2 },
		{ "net", 9, 5, 1 }, -- (a net is a tile of its own, beside the raft)
		{ "ladder", 7, 5, 1, 3 },
		{ "floor", 9, 7, 1 },
		{ "chair", 5, 6, 1, 1 },
	})
	local layout = raft(1, pieces, WHITE)
	drift(1, 8, 28)
	local newTile = tileWorld(layout, 9, 7)
	chips(newTile + V3.new(0, 0.6, 0), 10)
	sparkles(newTile + V3.new(0, 1, 0), C.gold, 8, 1.6)
	local here = tileWorld(layout, 8, 7) + V3.new(0.6, 0, 0)
	dress(1, { name = "Builder", pos = here, face = V3.new(1, 0, 0.15), pose = POSES.hammer, hold = "hammer" })
	-- two more bringing planks over from the storage box
	local p2 = tileWorld(layout, 7, 8) + V3.new(0, 0, 1)
	dress(2, {
		name = "Carrier",
		pos = p2,
		face = flat(here - p2),
		pose = POSES.carryPlanks,
		hold = "plank",
		holdL = "plank",
	})
	local p3 = tileWorld(layout, 6, 6) + V3.new(1, 0, 0)
	dress(3, {
		name = "Carrier2",
		pos = p3,
		face = V3.new(1, 0, 0.6),
		pose = POSES.carryPlanks,
		hold = "wood",
		holdL = "plank",
	})
	local cam = here + V3.new(15, 7.5, 13)
	shot("02_build_your_raft", cam, here + V3.new(-3, 1.6, -2), 50, here + V3.new(0, 2, 0))
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
		{ "net", 9, 7, 1 },
	})
	local layout = raft(2, pieces, { sail = "blue", banner = "blue", flag = "blue", deck = "natural" })
	local dest = layout.islandCenter
	IslandBuilder.build("tropical", dest, Random.new(3), islands)
	local helm = tileWorld(layout, 6, 5)
	dress(2, { name = "Helm", pos = helm + V3.new(0, 0, 2.2), face = V3.new(0, 0, -1), pose = POSES.helm })
	dress(1, { name = "Lookout", pos = tileWorld(layout, 7, 6), face = layout.out, pose = POSES.cheer })
	dress(4, {
		name = "Fisher",
		pos = tileWorld(layout, 8, 7) + V3.new(-2, 0, 0),
		face = V3.new(1, 0, 0),
		pose = POSES.reel,
		hold = "fishing_rod",
	})
	-- dolphins and the bow wave
	for i = 1, 3 do
		local a = layout.out * (18 + i * 5) + layout.current * (i * 6 - 8)
		local p = layout.center + a + V3.new(0, WATER + 1 + (i % 2) * 2, 0)
		local dolphin = Rigs.build("dolphin", cast)
		dolphin:PivotTo(CF.lookAt(p, p + layout.out + V3.new(0, 0.5 - (i % 2), 0)))
		splash(V3.new(p.X, WATER, p.Z), 4, 0.6)
	end
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
	local across = V3.new(-toRaft.Z, 0, toRaft.X)
	local stand = at + toRaft * 3.2
	stand = V3.new(stand.X, (built.ground(stand.X, stand.Z) or WATER + 1) + 0.2, stand.Z)
	dress(1, { name = "Chopper", pos = stand, face = -toRaft, pose = POSES.chop, hold = "axe" })
	chips(at + V3.new(0, 3, 0) + toRaft * 1.5, 12)
	for i = 1, 3 do
		local a = i * 2.1
		local p = fire + V3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
		p = V3.new(p.X, (built.ground(p.X, p.Z) or WATER + 1) + 0.9, p.Z)
		creature("reef_crab", p, (stand - p), i == 1 and "tell" or "chase", true)
	end
	local firePos = V3.new(fire.X, fire.Y, fire.Z)
	local seat = firePos + V3.new(3.2, 0, 1.8)
	dress(3, { name = "Sitter", pos = seat, face = flat(firePos - seat), pose = POSES.sit })
	glow(firePos + V3.new(0, 1.5, 0), C.warm, 16, 1.2)
	-- from the side, so the swing and the face show
	local cam = stand + across * 11 + toRaft * 2.5 + V3.new(0, 4, 0)
	shot("04_palm_key", cam, (stand + at) / 2 + V3.new(0, 3, 0), 54, stand + V3.new(0, 2, 0))
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
	dress(2, { name = "Pryer", pos = stand, face = -toward, pose = POSES.stab, hold = "crowbar" })
	chips(at + V3.new(0, 1.2, 0), 8, { C.iron, C.steel, rgb(90, 70, 60) })
	local locker = built.containers[1]
	dress(
		5,
		{ name = "Looter", pos = locker.pos + toward * 2.5 + V3.new(0, 0.2, 0), face = -toward, pose = POSES.carry }
	)
	sparkles(locker.pos + V3.new(0, 1.5, 0), C.gold, 10, 1.4)
	local lurk = built.center - toward * 10 + V3.new(5, 0, 0)
	lurk = V3.new(lurk.X, (built.ground(lurk.X, lurk.Z) or WATER + 1) + 1.2, lurk.Z)
	creature("mire_lurker", lurk, stand - lurk, "tell", false)
	redRing(V3.new(lurk.X, lurk.Y - 1, lurk.Z), 5.5)
	local cam = stand + toward * 6 - V3.new(-toward.Z, 0, toward.X) * 10 + V3.new(0, 5, 0)
	shot("05_the_wreck", cam, (stand + at) / 2 + V3.new(0, 2.5, 0), 54, stand + V3.new(0, 2, 0))
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
	for i = 1, 12 do
		local a = i * 0.52
		splash(layout.center + V3.new(math.cos(a) * 15, 0, math.sin(a) * 15), 2, 0.8)
	end
	local broken = tileWorld(layout, 9, 6)
	dress(1, {
		name = "Repairer",
		pos = tileWorld(layout, 8, 7),
		face = V3.new(1, 0, -0.4),
		pose = POSES.hammer,
		hold = "hammer",
	})
	dress(3, { name = "Bracer", pos = tileWorld(layout, 6, 6), face = V3.new(1, 0, 0), pose = POSES.brace })
	local bite = broken + V3.new(4.5, -2, 0)
	creature("shark", V3.new(bite.X, WATER - 0.2, bite.Z), (broken - bite), "surface", true)
	splash(V3.new(bite.X, WATER, bite.Z), 10, 1.3)
	glow(tileWorld(layout, 7, 5) + V3.new(0, 4, 0), C.warm, 20, 1.4)
	local cam = layout.center + V3.new(-18, 9, 20)
	shot("06_storm", cam, broken + V3.new(-2, 1.5, 0), 56, tileWorld(layout, 8, 7) + V3.new(0, 2, 0))
end

-- 07 The Leviathan: night at the Trench, the fortress raft, the monster rearing up right off the bow, harpoons flying ------
if wants("07") then
	clear()
	light("trench", { clock = 23 })
	local pieces = join(square(4, 4, 6), {
		{ "harpoon_turret", 9, 9, 1, 1 },
		{ "harpoon_turret", 4, 4, 1 },
		{ "lamp", 4, 9, 1 },
		{ "lamp", 9, 4, 1 },
		{ "lamp", 6, 6, 1 },
		{ "stairs", 5, 7, 1, 1 },
		{ "crow_nest", 5, 8, 2 },
		{ "engine", 4, 6, 1 },
		{ "sail", 6, 8, 1, 1 },
		{ "anchor", 5, 4, 1 },
		{ "research", 7, 4, 1 },
		{ "engineering", 6, 4, 1 },
		{ "spikes", 9, 5, 1, 0 },
		{ "spikes", 9, 8, 1, 0 },
		{ "railing", 4, 5, 1, 2 },
		{ "railing", 4, 7, 1, 2 },
		{ "railing", 4, 8, 1, 2 },
		{ "floor", 5, 8, 2 },
		{ "floor", 4, 8, 2 },
		{ "floor", 4, 7, 2 },
		{ "floor", 5, 7, 2 },
	})
	local layout = raft(6, pieces, { sail = "black", banner = "gold", flag = "gold", deck = "dark" })
	IslandBuilder.build("trench", layout.islandCenter, Random.new(9), islands)
	-- the Leviathan rears up off the raft's +X edge, its jaws a few studs from the planks
	local out = V3.new(1, 0, 0)
	local side = V3.new(0, 0, 1)
	local levPos = layout.center + out * 39 + side * 1 + V3.new(0, WATER + 1.5, 0)
	local lev = creature("leviathan", levPos, -out, "tell", false, 0.42)
	local eyes = lev:FindFirstChild("EyeGlow")
	if eyes then
		Kit.light(eyes, "PointLight", { Name = "Big", Color = rgb(255, 200, 60), Range = 40, Brightness = 2 })
	end
	local head = lev:FindFirstChild("Head")
	splash(V3.new(levPos.X - 6, WATER, levPos.Z), 16, 2.2)
	splash(V3.new(levPos.X + 6, WATER, levPos.Z + 2), 10, 1.6)
	local edge = tileWorld(layout, 9, 7)
	local _, hand = dress(1, {
		name = "Harpooner",
		pos = edge + V3.new(-0.5, 0, 0),
		face = flat(head.Position - edge),
		pose = POSES.aim,
		hold = "harpoon",
	})
	rope(hand.Position + V3.new(0, 0.5, 0), head.Position + V3.new(0, -1.5, 2.5), C.steel)
	local e2 = tileWorld(layout, 9, 6) + V3.new(-1, 0, -1)
	dress(2, { name = "Harpooner2", pos = e2, face = flat(head.Position - e2), pose = POSES.aim, hold = "harpoon" })
	-- the turret's shot, from the end of its barrel
	local tur = tileWorld(layout, 9, 9) + V3.new(3.3, 2.1, 0)
	rope(tur, head.Position + V3.new(1, -2.5, -2), rgb(255, 220, 120), 0.14)
	for _, g in { tileWorld(layout, 4, 9), tileWorld(layout, 9, 4), tileWorld(layout, 6, 6) } do
		glow(g + V3.new(0, 4.5, 0), C.warm, 22, 1.6)
	end
	-- from just behind the harpooners, a little above their heads, looking up at it
	local cam = layout.center + out * 4 + side * -17 + V3.new(0, 7.5, 0)
	local look = head.Position + V3.new(0, -2.5, -3)
	shot("07_the_leviathan", cam, look, 54, head.Position, { head = head.Position })
end

-- 08 Legendary vessel at dusk: two decks, gold flags, the aquarium, the trophy ---------------------------------------------------
local FORTRESS = {
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
	{ "net", 11, 9, 1 },
	{ "salvage_net", 4, 11, 1 },
	{ "coral_lamp", 7, 4, 1 },
}
local function fortress(dz)
	local pieces = {}
	for _, p in join(square(3, 3, 8), FORTRESS) do
		local q = table.clone(p)
		q[3] += dz or 0
		table.insert(pieces, q)
	end
	for x = 7, 9 do
		for z = 7, 9 do
			if not (x == 9 and z == 9) then
				table.insert(pieces, { "plank_floor", x, z + (dz or 0), 2 })
			end
		end
	end
	table.insert(pieces, { "railing", 7, 7 + (dz or 0), 2, 2 })
	table.insert(pieces, { "railing", 7, 8 + (dz or 0), 2, 2 })
	table.insert(pieces, { "roof", 8, 8 + (dz or 0), 2 })
	return pieces
end
if wants("08") then
	clear()
	light("dusk")
	local layout = raft(1, fortress(), { sail = "gold", banner = "gold", flag = "gold", deck = "white" })
	drift(1, 6, 30)
	dress(1, { name = "Captain", pos = tileWorld(layout, 8, 7, 2), face = V3.new(0, 0, 1), pose = POSES.cheer })
	dress(2, { name = "Helm", pos = tileWorld(layout, 5, 3), face = V3.new(0, 0, -1), pose = POSES.helm })
	dress(3, { name = "Sitter", pos = tileWorld(layout, 8, 5), face = V3.new(1, 0, 0), pose = POSES.sit })
	dress(5, { name = "Waver", pos = tileWorld(layout, 6, 8), face = V3.new(0, 0, 1), pose = POSES.wave })
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
		local p = c + toward * 27 + side * ((i - 3.5) * 6.5)
		local y = built.ground(p.X, p.Z) or WATER + 1
		creature(kind, V3.new(p.X, y + (kind == "gull" and 0 or 1), p.Z), toward, i == 3 and "tell" or "idle", false)
	end
	-- and in the water off the beach, the shark and the sea serpent
	local sharkAt = c + toward * 41.5 + side * -15
	creature("shark", V3.new(sharkAt.X, WATER - 0.2, sharkAt.Z), side, "surface", true)
	local serpAt = c + toward * 41.5 + side * 14
	creature("sea_serpent", V3.new(serpAt.X, WATER + 0.5, serpAt.Z), -side, "surface", true)
	splash(V3.new(sharkAt.X, WATER, sharkAt.Z), 6, 1.2)
	splash(V3.new(serpAt.X, WATER, serpAt.Z), 8, 1.6)
	local cam = c + toward * 57 + V3.new(0, 8, 0)
	shot("09_the_cast", cam, c + toward * 30 + V3.new(0, 2.5, 0), 54, c + toward * 30 + V3.new(0, 2, 0))
end

-- 10 From above: a raft on its plot, its island, debris drifting in on the current, the far isles ---------------------------
if wants("10") then
	clear()
	light("day", { clock = 9.5, atmosphere = { density = 0.08 } })
	local layout = raft(
		1,
		join(
			square(5, 5, 4),
			{ { "sail", 7, 7, 1, 1 }, { "helm", 5, 5, 1, 3 }, { "storage", 8, 8, 1 }, { "net", 9, 5, 1 } }
		),
		{ sail = "red", banner = "red", flag = "red", deck = "natural" }
	)
	IslandBuilder.build("tropical", layout.islandCenter, Random.new(3), islands)
	-- the current brings the debris past in a lane
	for i = 1, 14 do
		local along = -150 + i * 19 + rng:NextNumber(-6, 6)
		local p = layout.center
			+ layout.current * along
			+ layout.out * rng:NextNumber(-26, 26)
			+ V3.new(0, WATER + 0.3, 0)
		local kinds = { "wood", "scrap", "rope", "wood", "cloth", "metal", "supply_crate", "wood" }
		OceanModels.debris(kinds[(i - 1) % #kinds + 1], CF.new(p) * CF.Angles(0, rng:NextNumber(0, 6), 0), debrisFolder)
	end
	dress(1, {
		name = "Caster",
		pos = tileWorld(layout, 8, 6),
		face = V3.new(0, 0, -1),
		pose = POSES.reel,
		hold = "fishing_rod",
	})
	dress(2, { name = "Walker", pos = tileWorld(layout, 6, 7), face = V3.new(1, 0, 0) })
	local cam = layout.center + V3.new(-70, 85, 95)
	shot("10_the_ocean", cam, layout.center + V3.new(70, 0, -40), 54, layout.center)
end

-- 11 A message in a bottle: dusk, a green bottle with a note in it bumping the raft, a survivor reaching down for it ---------
if wants("11") then
	clear()
	light("dusk", { clock = 18.2 })
	local layout = raft(
		1,
		join(
			square(6, 6, 2),
			{ { "floor", 6, 8, 1 }, { "lamp", 7, 7, 1 }, { "storage", 7, 8, 1 }, { "railing", 7, 6, 1, 3 } }
		),
		WHITE
	)
	-- kneeling at the platform's -X edge, leaning out, a hand down to the water
	local tile = tileWorld(layout, 6, 6)
	local edgeX = tile.X - 3
	local kneel = V3.new(edgeX + 0.6, tile.Y, tile.Z + 0.6)
	dress(5, { name = "Reacher", pos = kneel, face = V3.new(-1, 0, 0), pose = POSES.kneelReach })
	local bottleAt = V3.new(edgeX - 1.25, WATER + 0.3, kneel.Z - 0.5)
	OceanModels.debris("bottle", CF.new(bottleAt) * CF.Angles(0, 2.6, 0), debrisFolder)
	-- the little ripples where it knocks against the pontoon
	Kit.disc(
		fxFolder,
		"Ripple",
		V3.new(bottleAt.X, WATER + 0.22, bottleAt.Z),
		3.4,
		0.08,
		rgb(230, 244, 250),
		M.SmoothPlastic,
		{ CanCollide = false, CastShadow = false, Transparency = 0.6 }
	)
	local look = V3.new(edgeX - 0.4, 2.5, bottleAt.Z + 0.5)
	local cam = look + V3.new(-9.5, 0.4, -5.4)
	shot("11_message_in_a_bottle", cam, look, 50, bottleAt + V3.new(0, 0.8, 0), { bottle = bottleAt })
end

-- 12 Mist Hollow: evening fog, the huts nobody came back to, two of the three lanterns lit, a survivor with a lantern -------
if wants("12") then
	clear()
	light("fog", {
		clock = 19.6,
		brightness = 1.2,
		ambient = rgb(70, 78, 92),
		outdoor = rgb(96, 108, 126),
		atmosphere = { density = 2.6, color = rgb(118, 130, 146), decay = rgb(58, 68, 86) },
	})
	local layout = OceanLayout.plot(3)
	local built = IslandBuilder.build("foggy", layout.islandCenter, Random.new(53), islands)
	local c = built.center
	local parts = built.puzzle.parts
	-- two of the three lanterns lit (the third still dark), the way IslandService lights them
	lightLantern(parts[1].model)
	lightLantern(parts[3].model)
	-- coming up from the shore: from here both lit lanterns and all four huts are ahead, in the fog
	local a = math.rad(345)
	local dir = V3.new(math.cos(a), 0, math.sin(a))
	local across = V3.new(-dir.Z, 0, dir.X)
	local stand = c + dir * 46.5 + across * 1.8
	stand = V3.new(stand.X, (built.ground(stand.X, stand.Z) or WATER + 1.2) + 0.2, stand.Z)
	dress(
		2,
		{ name = "Walker", pos = stand, face = flat(-dir - across * 0.12), pose = POSES.lantern, holdL = "lantern" }
	)
	local cam = c + dir * 57.5 + across * 3 + V3.new(0, WATER + 8.5, 0)
	local look = c + dir * 12 + V3.new(0, 3, 0)
	local marks = {
		lantern1 = parts[1].pos + V3.new(0, 4.2, 0),
		lantern3 = parts[3].pos + V3.new(0, 4.2, 0),
		dark2 = parts[2].pos + V3.new(0, 4.2, 0),
	}
	for i, h in propsNamed(built, "hut") do
		marks["hut" .. i] = h:GetPivot().Position
	end
	shot("12_mist_hollow", cam, look, 52, stand + V3.new(0, 3, 0), marks)
end

-- 13 The Frost Shelf: a ship frozen into the ice, its name worn off; cold morning light, a raft coming in -------------------
if wants("13") then
	clear()
	light("dawn", {
		clock = 7.6,
		brightness = 2.4,
		ambient = rgb(112, 124, 146),
		outdoor = rgb(150, 170, 200),
		atmosphere = { density = 0.32, color = rgb(204, 220, 238), decay = rgb(104, 136, 182) },
		clouds = { cover = 0.45, density = 0.5, color = rgb(232, 238, 250) },
	})
	local home = OceanLayout.plot(4)
	local built = IslandBuilder.build("frozen", home.islandCenter, Random.new(4), islands)
	local hull
	for _, m in built.model:GetChildren() do
		if m:GetAttribute("Hull") then
			hull = m
		end
	end
	local hullAt = hull:GetPivot().Position
	-- the raft comes in toward the shore from the sun's side (staged nearer the shore than a voyage leaves it):
	-- its tiles on plot 4's grid, shifted out to there
	local toward = flat(SUN + V3.new(0.25, 0, 0.1))
	local raftAt = built.center + toward * 76
	local dx = math.floor((raftAt.X - home.center.X) / 6 + 0.5)
	local dz = math.floor((raftAt.Z - home.center.Z) / 6 + 0.5)
	local pieces = join(square(5 + dx, 5 + dz, 3), {
		{ "sail", 6 + dx, 6 + dz, 1, 1 },
		{ "lamp", 7 + dx, 7 + dz, 1 },
		{ "storage", 5 + dx, 7 + dz, 1 },
		{ "railing", 5 + dx, 5 + dz, 1, 3 },
		{ "railing", 7 + dx, 5 + dz, 1, 3 },
	})
	local layout = raft(4, pieces, { sail = "white", banner = "blue", flag = "blue", deck = "natural" })
	local bow = tileWorld(layout, 6 + dx, 5 + dz)
	local inland = flat(built.center - bow)
	local side = V3.new(-inland.Z, 0, inland.X)
	dress(1, { name = "Lookout", pos = bow + inland * 1.2 - side * 1.2, face = inland, pose = POSES.stand })
	dress(3, {
		name = "Sailor",
		pos = bow + inland * 0.6 + side * 2.4,
		face = flat(inland + side * 0.2),
		pose = POSES.peerPoint,
	})
	-- from behind and beside the raft (the sail off to the side, out of the way), past them to the ship
	local cam = bow - inland * 9 - side * 7 + V3.new(0, 7, 0)
	shot("13_frost_shelf", cam, hullAt + V3.new(0, 2, 0), 40, bow + inland * 25, { hull = hullAt + V3.new(0, 6, 0) })
end

-- 14 The totems: three of them, turned inland, staring at whoever comes up from the beach -----------------------------------
if wants("14") then
	clear()
	light("day", { clock = 16.6, atmosphere = { density = 0.22, haze = 1.4 } })
	local layout = OceanLayout.plot(5)
	local built = IslandBuilder.build("ruin", layout.islandCenter, Random.new(13), islands)
	local c = built.center
	-- the camera stands inland, looking out to sea (away from the sun, so the stone is lit); the totems stand on the
	-- same terrace between it and the sea, turned round to face inland: at the camera
	local seaward = -SUN
	local across = V3.new(-seaward.Z, 0, seaward.X)
	local camAt = c + seaward * 18.6
	for i, part in built.puzzle.parts do
		local p = c + seaward * (26.4 + (i == 2 and 0.8 or 0)) + across * ((i - 2) * 4.3)
		local y = built.ground(p.X, p.Z) or WATER + 1
		p = V3.new(p.X, y, p.Z)
		-- stood on the ground (IslandBuilder's PivotTo puts the middle of the model on the ground), eyes (its -Z face)
		-- toward the camera
		local m = part.model
		local base = m:FindFirstChild("Base")
		local face = flat(camAt - p)
		local want = CF.lookAt(p + V3.new(0, 0.5, 0), p + V3.new(0, 0.5, 0) + face)
		local delta = want * base.CFrame:Inverse()
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = delta * d.CFrame
			end
		end
		part.pos = p
	end
	-- ruin walls and jungle trees round them (the island's own, moved to frame them)
	local function moveTo(m, p)
		local y = built.ground(p.X, p.Z) or WATER + 1
		local piv = m:GetPivot()
		local bottom = math.huge
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				bottom = math.min(bottom, d.Position.Y - d.Size.Y / 2)
			end
		end
		m:PivotTo(CF.new(V3.new(p.X, piv.Position.Y + (y - bottom - 0.3), p.Z)) * piv.Rotation)
	end
	local walls, trees = propsNamed(built, "ruin_wall"), propsNamed(built, "Tree")
	if walls[1] then
		moveTo(walls[1], c + seaward * 24 + across * -13)
	end
	if walls[2] then
		moveTo(walls[2], c + seaward * 25 + across * 13.5)
	end
	if trees[1] then
		moveTo(trees[1], c + seaward * 31 + across * -19)
	end
	if trees[2] then
		moveTo(trees[2], c + seaward * 29 + across * 20)
	end
	-- someone coming up from the beach, small between them, looking up
	local standAt = c + seaward * 39 + across * 4.6
	standAt = V3.new(standAt.X, (built.ground(standAt.X, standAt.Z) or WATER + 1) + 0.2, standAt.Z)
	dress(6, { name = "Explorer", pos = standAt, face = flat(-seaward), pose = POSES.lookUp })
	local camPos = V3.new(camAt.X, (built.ground(camAt.X, camAt.Z) or WATER + 1) + 1.7, camAt.Z)
	local look = c + seaward * 26 + V3.new(0, 8.2, 0)
	local marks = {}
	for i, part in built.puzzle.parts do
		marks["totem" .. i] = part.pos + V3.new(0, 4, 0)
	end
	shot("14_the_totems", camPos, look, 50, c + seaward * 26 + V3.new(0, 4, 0), marks)
end

-- 15 The shadow: at the Trench, something enormous passes under the raft; they look down and see it go by --------------------
if wants("15") then
	clear()
	light("trench", { clock = 12.5, brightness = 3, atmosphere = { density = 0.25 } })
	-- the water as clear as it ever gets (the renderer still keeps it half opaque), and the deep plane lowered and
	-- lighter, so the dark shape just under the surface shows against it
	terrainInst.WaterTransparency = 1
	deep.CFrame = CF.new(0, WATER - 18, 0)
	deep.Color = rgb(44, 138, 160)
	local layout = raft(
		6,
		join(square(5, 5, 4), {
			{ "sail", 6, 7, 1, 1 },
			{ "helm", 7, 5, 1, 3 },
			{ "storage", 5, 5, 1 },
			{ "lamp", 8, 8, 1 },
			{ "railing", 5, 6, 1, 2 },
			{ "railing", 5, 7, 1, 2 },
			{ "railing", 6, 8, 1, 1 },
		}),
		{ sail = "white", banner = "red", flag = "red", deck = "natural" }
	)
	IslandBuilder.build("trench", layout.islandCenter, Random.new(9), islands)
	-- the Leviathan, a few studs down, sliding under the raft from one side to the other
	local dir = V3.new(1, 0, 0.55).Unit
	local levPos = layout.center + dir * 4 + V3.new(-dir.Z, 0, dir.X) * 3 + V3.new(0, WATER - 3.2, 0)
	creature("leviathan", levPos, dir, "idle", true)
	-- the survivors at the +X edge, looking down over it
	local e1 = tileWorld(layout, 8, 6) + V3.new(1.6, 0, 0)
	dress(1, { name = "Looker", pos = e1, face = V3.new(1, 0, 0.2), pose = POSES.peerPoint })
	local e2 = tileWorld(layout, 8, 7) + V3.new(1.4, 0, 0.5)
	dress(3, { name = "Looker2", pos = e2, face = V3.new(1, 0, -0.1), pose = POSES.peer })
	local e3 = tileWorld(layout, 7, 5) + V3.new(0.5, 0, -1.4)
	dress(2, { name = "Looker3", pos = e3, face = V3.new(0.3, 0, -1), pose = POSES.peer })
	local perp = V3.new(-dir.Z, 0, dir.X)
	local cam = layout.center + perp * 16 + V3.new(0, 33, 0) - dir * 2
	local look = layout.center + dir * 1 + V3.new(0, -4, 0)
	shot("15_the_shadow", cam, look, 52, layout.center, { leviathan = levPos })
end

-- 16 Who built that? In the fog, a starter raft drifts up to a fortress somebody else built, its lamps lit -----------------
if wants("16") then
	clear()
	light("fog", {
		clock = 18.4,
		brightness = 1.3,
		ambient = rgb(92, 98, 108),
		outdoor = rgb(124, 132, 144),
		atmosphere = { density = 3.2, color = rgb(150, 160, 172), decay = rgb(84, 94, 110) },
	})
	-- the fortress (08's raft, a few more lamps lit) and, out in front of it on the same grid, a 2 x 2 starter raft
	local pieces = fortress()
	local lamps = { { 3, 10, 1 }, { 10, 3, 1 }, { 8, 10, 1 }, { 9, 10, 1 }, { 7, 9, 2 } }
	for i = 3, #lamps do
		table.insert(pieces, { "lamp", lamps[i][1], lamps[i][2], lamps[i][3] })
	end
	local layout = raft(2, pieces, { sail = "gold", banner = "gold", flag = "gold", deck = "dark" })
	raft(2, square(6, 15, 2), WHITE)
	local small = Formulas.tilePosition(layout.center, 6.5, 15.5, 1) + V3.new(0, 0.3, 0)
	local big = Formulas.tilePosition(layout.center, 6.5, 6.5, 1)
	local toBig = flat(big - small)
	for _, l in lamps do
		glow(Formulas.tilePosition(layout.center, l[1], l[2], l[3]) + V3.new(1.2, 4.5, 0), C.warm, 26, 1.8)
	end
	dress(4, {
		name = "Starter",
		pos = small + toBig * 1 + V3.new(0.8, 0, 0),
		face = flat(toBig + V3.new(0.15, 0, 0)),
		pose = POSES.lookUp,
	})
	local cam = small - toBig * 8 + V3.new(-3, 3.2, 0)
	local look = big + V3.new(0, 7.5, 0)
	shot("16_who_built_that", cam, look, 50, small + toBig * 16, { fortress = big + V3.new(0, 6, 0) })
end

-- (render.js reads the list)
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print(#shots .. " shots written to " .. outDir)

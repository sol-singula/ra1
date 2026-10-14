--[[
How the camp looks (master plan §7, §11: the camp is the team's home and the visual focal point, with warm light
and recognizable structures that change as it grows). Every structure is built from plain parts by one function
here; CampService places them on their slots (World/MapLayout.campSlots), first as a glowing blueprint (ghost),
then for real. The fixed props (the fire, the Camp Board, the bell, the difficulty stones, the tents) are built by
MapBuilder with the same functions.

  CampModels.build(key, cf, opts) -> model     opts = { parent, ghost = bool, width, tier, upgraded }
]]
local Kit = require(script.Parent.Kit)

local CampModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

-- A blueprint: every part a see-through glowing blue, no collision (the real thing replaces it when it's built).
local function ghostify(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = C.blueprint
			d.Material = M.Neon
			d.Transparency = 0.72
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		elseif d:IsA("Light") or d:IsA("Fire") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
end
CampModels.ghostify = ghostify

local builders = {}

-- The campfire: a ring of stones, crossed logs, flames and a warm light. Bigger with each camp tier.
function builders.fire(m, cf, opts)
	local tier = opts.tier or 1
	local s = 1 + (tier - 1) * 0.22
	local base = cf.Position
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local p = base + V3(math.cos(a), 0, math.sin(a)) * 3.4 * s
		local stone = Kit.ellipsoid(
			m,
			"Stone",
			p + V3(0, 0.5, 0),
			V3(1.7, 1.1, 1.4) * s,
			C.stone:Lerp(C.stoneDark, (k % 3) * 0.2),
			M.Rock,
			{ CastShadow = false }
		)
		stone.CFrame = stone.CFrame * CFrame.Angles(0, a, 0)
	end
	for k = 0, tier >= 3 and 3 or 2 do
		local a = k / (tier >= 3 and 4 or 3) * math.pi * 2
		Kit.cyl(
			m,
			"Log",
			CFrame.new(base + V3(0, 0.9 * s, 0)) * CFrame.Angles(0, a, math.rad(28)),
			4.2 * s,
			0.8 * s,
			C.woodDark,
			M.Wood,
			{ CanCollide = false, CastShadow = false }
		)
	end
	Kit.disc(
		m,
		"Embers",
		base + V3(0, 0.25, 0),
		4.6 * s,
		0.4,
		C.ember,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	local flame = Kit.ellipsoid(
		m,
		"Flame",
		base + V3(0, 2.2 * s, 0),
		V3(2.4, 3.6, 2.4) * s,
		C.fire,
		M.Neon,
		{ CanCollide = false, CastShadow = false, Transparency = 0.15 }
	)
	Kit.ellipsoid(
		m,
		"FlameCore",
		base + V3(0, 1.7 * s, 0),
		V3(1.4, 2.4, 1.4) * s,
		C.yellow,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	local fire = Instance.new("Fire")
	fire.Size = 6 * s
	fire.Heat = 9
	fire.Color = C.fire
	fire.SecondaryColor = C.ember
	fire.Parent = flame
	Kit.light(
		flame,
		"PointLight",
		{ Name = "FireLight", Color = C.warm, Range = 26 + (tier - 1) * 6, Brightness = 2.4 }
	)
	if tier >= 4 then
		-- the Great Beacon: a stone pillar with a fire bowl high above the camp
		Kit.disc(m, "Beacon", base + V3(5.5, 5, 0), 1.6, 10, C.stone, M.Cobblestone)
		local bowl = Kit.disc(m, "Bowl", base + V3(5.5, 10.4, 0), 3, 0.9, C.iron, M.Metal, { CastShadow = false })
		Kit.ellipsoid(m, "BeaconFlame", bowl.Position + V3(0, 1.4, 0), V3(2, 2.8, 2), C.fire, M.Neon, {
			CanCollide = false,
			CastShadow = false,
		})
	end
	return flame
end

function builders.workbench(m, cf)
	local top = Kit.box(m, "Top", cf * CFrame.new(0, 3, 0), V3(7, 0.6, 3.4), C.plank, M.WoodPlanks)
	for _, x in { -3, 3 } do
		for _, z in { -1.3, 1.3 } do
			Kit.box(
				m,
				"Leg",
				cf * CFrame.new(x, 1.35, z),
				V3(0.6, 2.7, 0.6),
				C.woodDark,
				M.Wood,
				{ CastShadow = false }
			)
		end
	end
	Kit.box(m, "Shelf", cf * CFrame.new(0, 1, 0), V3(6.2, 0.3, 2.6), C.wood, M.WoodPlanks, { CastShadow = false })
	-- a saw, a hammer and a vise
	Kit.box(
		m,
		"Saw",
		cf * CFrame.new(-1.6, 3.45, -0.4) * CFrame.Angles(0, 0.3, 0),
		V3(2.8, 0.1, 0.8),
		C.steel,
		M.Metal,
		{
			CanCollide = false,
			CastShadow = false,
		}
	)
	Kit.box(
		m,
		"HammerHandle",
		cf * CFrame.new(1.4, 3.4, 0.5) * CFrame.Angles(0, -0.5, 0),
		V3(1.8, 0.25, 0.25),
		C.woodDark,
		M.Wood,
		{
			CanCollide = false,
			CastShadow = false,
		}
	)
	Kit.box(
		m,
		"HammerHead",
		cf * CFrame.new(2.1, 3.5, 0.15) * CFrame.Angles(0, -0.5, 0),
		V3(0.5, 0.45, 0.9),
		C.iron,
		M.Metal,
		{
			CanCollide = false,
			CastShadow = false,
		}
	)
	Kit.box(m, "Vise", cf * CFrame.new(3.1, 3.6, -1.1), V3(0.9, 0.8, 0.9), C.iron, M.Metal, { CastShadow = false })
	return top
end

function builders.storage(m, cf)
	local body = Kit.box(m, "Chest", cf * CFrame.new(0, 1.3, 0), V3(5, 2.6, 3), C.wood, M.WoodPlanks)
	local lid = Kit.box(m, "Lid", cf * CFrame.new(0, 2.9, 0), V3(5.2, 0.7, 3.2), C.woodLight, M.WoodPlanks)
	for _, x in { -1.8, 1.8 } do
		Kit.box(m, "Band", cf * CFrame.new(x, 1.6, 0), V3(0.35, 3.4, 3.3), C.iron, M.Metal, { CastShadow = false })
	end
	Kit.box(m, "Lock", cf * CFrame.new(0, 2.3, -1.6), V3(0.7, 0.8, 0.3), C.gold, M.Metal, { CastShadow = false })
	return body, lid
end

-- A palisade wall: sharpened logs side by side on a beam (stone: big blocks), as wide as its slot.
function builders.wall(m, cf, opts)
	local w = opts.width or 11
	if opts.upgraded then
		local h = 9
		Kit.box(m, "Wall", cf * CFrame.new(0, h / 2, 0), V3(w, h, 3), C.stone, M.Cobblestone)
		Kit.box(
			m,
			"Cap",
			cf * CFrame.new(0, h + 0.4, 0),
			V3(w + 0.3, 0.8, 3.4),
			C.stoneDark,
			M.Slate,
			{ CastShadow = false }
		)
		for x = -w / 2 + 1.2, w / 2 - 1.2, 2.6 do
			Kit.box(
				m,
				"Merlon",
				cf * CFrame.new(x, h + 1.4, 0),
				V3(1.4, 1.4, 3),
				C.stone,
				M.Cobblestone,
				{ CastShadow = false }
			)
		end
		return m
	end
	local n = math.max(3, math.floor(w / 1.8))
	local step = w / n
	for i = 0, n - 1 do
		local x = -w / 2 + step * (i + 0.5)
		local h = 7.6 + ((i * 7) % 3) * 0.5
		Kit.cyl(
			m,
			"Stake",
			cf * CFrame.new(x, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			h,
			step * 1.02,
			C.wood:Lerp(C.woodDark, (i % 3) * 0.2),
			M.Wood,
			{ CastShadow = i % 2 == 0 }
		)
		Kit.wedge(
			m,
			"Point",
			cf * CFrame.new(x, h + 0.6, 0),
			V3(step * 0.9, 1.2, step * 0.9),
			C.woodLight,
			M.Wood,
			{ CastShadow = false, CanCollide = false }
		)
	end
	Kit.box(m, "Beam", cf * CFrame.new(0, 4.2, -0.9), V3(w, 0.7, 0.5), C.woodDark, M.Wood, { CastShadow = false })
	return m
end

-- A gate: an archway the team walks through (monsters have to break it down).
function builders.gate(m, cf, opts)
	local w = opts.width or 10
	local stone = opts.upgraded
	local col, mat = stone and C.stone or C.woodDark, stone and M.Cobblestone or M.Wood
	for _, x in { -w / 2 - 0.6, w / 2 + 0.6 } do
		Kit.box(m, "Post", cf * CFrame.new(x, 5.5, 0), V3(1.6, 11, 1.6), col, mat)
	end
	Kit.box(m, "Lintel", cf * CFrame.new(0, 10.6, 0), V3(w + 3, 1.2, 1.8), col, mat)
	-- the doors stand open (the team walks through; the server keeps monsters out until they break it)
	for _, side in { -1, 1 } do
		Kit.box(
			m,
			"Door",
			cf
				* CFrame.new(side * (w / 2 - 0.1), 4.2, -2.2)
				* CFrame.Angles(0, side * math.rad(70), 0)
				* CFrame.new(-side * 2.3, 0, 0),
			V3(4.6, 8, 0.5),
			stone and C.iron or C.wood,
			stone and M.Metal or M.WoodPlanks,
			{ CanCollide = false, CastShadow = false }
		)
	end
	local lantern = cf * CFrame.new(0, 9.4, -1.2)
	Kit.bulb(m, "Lantern", lantern.Position, 0.8, C.warm, 18, 1.2)
	return m
end

function builders.spikes(m, cf, opts)
	if opts.upgraded then
		Kit.disc(
			m,
			"Pit",
			cf.Position + V3(0, 0.1, 0),
			7,
			0.3,
			C.ember,
			M.Neon,
			{ CanCollide = false, CastShadow = false }
		)
		Kit.disc(m, "Rim", cf.Position + V3(0, 0.25, 0), 8, 0.4, C.stoneDark, M.Rock, { CanCollide = false })
		local f = Instance.new("Fire")
		f.Size = 5
		f.Heat = 6
		f.Parent = m:FindFirstChild("Pit")
		return m
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local p = cf.Position + V3(math.cos(a), 0, math.sin(a)) * 1.6
		Kit.wedge(
			m,
			"Spike",
			CFrame.new(p + V3(0, 1.1, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-20), 0, 0),
			V3(0.6, 2.4, 0.6),
			C.woodLight,
			M.Wood,
			{ CanCollide = false, CastShadow = false }
		)
	end
	Kit.disc(
		m,
		"Base",
		cf.Position + V3(0, 0.1, 0),
		5,
		0.2,
		C.dirt,
		M.Ground,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

function builders.repair(m, cf)
	for _, x in { -2, 2 } do
		Kit.box(
			m,
			"Horse",
			cf * CFrame.new(x, 1.3, 0) * CFrame.Angles(0, 0, math.rad(8)),
			V3(0.5, 2.6, 2.4),
			C.woodDark,
			M.Wood
		)
	end
	Kit.box(m, "Plank", cf * CFrame.new(0, 2.7, 0), V3(6, 0.4, 1.4), C.plank, M.WoodPlanks)
	Kit.box(
		m,
		"Plank2",
		cf * CFrame.new(0.4, 3.05, 0.2) * CFrame.Angles(0, 0.2, 0),
		V3(5, 0.3, 1.1),
		C.woodLight,
		M.WoodPlanks,
		{
			CastShadow = false,
		}
	)
	Kit.box(
		m,
		"Hammer",
		cf * CFrame.new(-1, 3.3, -0.3),
		V3(0.5, 0.45, 1.2),
		C.iron,
		M.Metal,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

-- A watch platform: a deck on four posts, railings, and a ladder (climb it: archers hit harder up here).
function builders.platform(m, cf)
	local h = 8
	for _, x in { -3.4, 3.4 } do
		for _, z in { -3.4, 3.4 } do
			Kit.box(m, "Post", cf * CFrame.new(x, h / 2, z), V3(0.9, h, 0.9), C.woodDark, M.Wood)
		end
	end
	Kit.box(m, "Deck", cf * CFrame.new(0, h, 0), V3(8, 0.6, 8), C.plank, M.WoodPlanks)
	for _, z in { -3.9, 3.9 } do
		Kit.box(m, "Rail", cf * CFrame.new(0, h + 1.5, z), V3(8, 0.4, 0.3), C.wood, M.Wood, { CastShadow = false })
	end
	Kit.box(m, "RailSide", cf * CFrame.new(-3.9, h + 1.5, 0), V3(0.3, 0.4, 8), C.wood, M.Wood, { CastShadow = false })
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = V3(2, h, 2)
	ladder.CFrame = cf * CFrame.new(4.6, h / 2, 0)
	ladder.Color = C.woodLight
	ladder.Material = M.Wood
	ladder.Parent = m
	return m
end

function builders.anvil(m, cf)
	Kit.disc(m, "Stump", cf.Position + V3(0, 1.2, 0), 2.6, 2.4, C.bark, M.Wood)
	Kit.box(m, "Anvil", cf * CFrame.new(0, 2.9, 0), V3(2.8, 1, 1.2), C.iron, M.Metal)
	Kit.wedge(
		m,
		"Horn",
		cf * CFrame.new(2, 2.9, 0) * CFrame.Angles(0, math.rad(90), 0),
		V3(1.2, 1, 1.2),
		C.iron,
		M.Metal,
		{
			CastShadow = false,
		}
	)
	Kit.box(m, "Base", cf * CFrame.new(0, 2.2, 0), V3(1.6, 0.6, 1), C.iron, M.Metal, { CastShadow = false })
	Kit.box(
		m,
		"Tongs",
		cf * CFrame.new(-0.6, 3.5, 0.2) * CFrame.Angles(0, 0.4, 0),
		V3(2, 0.15, 0.3),
		C.black,
		M.Metal,
		{
			CanCollide = false,
			CastShadow = false,
		}
	)
	return m
end

function builders.cookpot(m, cf)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local foot = cf.Position + V3(math.cos(a), 0, math.sin(a)) * 2.4
		local top = cf.Position + V3(0, 5, 0)
		Kit.box(
			m,
			"Leg",
			CFrame.lookAt((foot + top) / 2, top),
			V3(0.3, 0.3, (top - foot).Magnitude),
			C.woodDark,
			M.Wood,
			{
				CastShadow = false,
			}
		)
	end
	Kit.ball(m, "Pot", cf.Position + V3(0, 2.2, 0), 2.6, C.black, M.Metal)
	Kit.disc(
		m,
		"Stew",
		cf.Position + V3(0, 3.1, 0),
		2,
		0.2,
		C.autumn,
		M.SmoothPlastic,
		{ CanCollide = false, CastShadow = false }
	)
	Kit.disc(
		m,
		"Coals",
		cf.Position + V3(0, 0.2, 0),
		2.4,
		0.3,
		C.ember,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	return m
end

function builders.lamppost(m, cf)
	Kit.lantern(m, cf.Position, (cf.LookVector * V3(1, 0, 1)).Unit, 9)
	return m
end

function builders.catapult(m, cf)
	Kit.box(m, "Frame", cf * CFrame.new(0, 0.6, 0), V3(3, 1, 4.4), C.woodDark, M.Wood)
	for _, x in { -1.2, 1.2 } do
		Kit.box(
			m,
			"Upright",
			cf * CFrame.new(x, 2.1, 0.4),
			V3(0.5, 2.4, 0.5),
			C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	Kit.box(
		m,
		"Arm",
		cf * CFrame.new(0, 2.6, -0.6) * CFrame.Angles(math.rad(-35), 0, 0),
		V3(0.5, 0.5, 5),
		C.wood,
		M.Wood,
		{
			CastShadow = false,
		}
	)
	Kit.box(m, "Bucket", cf * CFrame.new(0, 4.2, -2.6), V3(1.4, 0.8, 1.4), C.wood, M.WoodPlanks, { CastShadow = false })
	Kit.ball(m, "Pinecone", cf.Position + (cf.Rotation * V3(0, 4.8, -2.6)), 1, C.bark, M.Wood, {
		CanCollide = false,
		CastShadow = false,
	})
	return m
end

-- The Totem of the Seventh Night: a carved pole of stacked grinning faces, a big 67, glowing eyes.
function builders.totem(m, cf)
	local base = cf.Position
	local faces = { C.wood, C.kermy, C.woodLight, C.jersey }
	for i, col in faces do
		local y = 1.4 + (i - 1) * 2.4
		Kit.box(m, "Face", cf * CFrame.new(0, y, 0), V3(2.6, 2.3, 2.6), col, i == 2 and M.SmoothPlastic or M.Wood)
		for _, x in { -0.6, 0.6 } do
			Kit.ball(m, "Eye", (cf * CFrame.new(x, y + 0.3, -1.32)).Position, 0.55, C.glowcap, M.Neon, {
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
	for _, side in { -1, 1 } do
		Kit.wedge(
			m,
			"Wing",
			cf * CFrame.new(side * 2.6, 8.4, 0) * CFrame.Angles(0, side * math.rad(90), 0),
			V3(0.4, 2, 3),
			C.jerseyTrim,
			M.Wood,
			{ CastShadow = false }
		)
	end
	local plate = Kit.box(
		m,
		"Plate",
		cf * CFrame.new(0, 10.6, -0.2),
		V3(3, 1.6, 0.4),
		C.jerseyTrim,
		M.Metal,
		{ CastShadow = false }
	)
	Kit.text(plate, Enum.NormalId.Front, "67", { font = Enum.Font.LuckiestGuy, color = C.jersey, ppu = 40 })
	Kit.light(m:FindFirstChild("Face"), "PointLight", { Color = C.glowcap, Range = 14, Brightness = 1.2 })
	_ = base
	return m
end

-- The Camp Board: what the next camp tier needs (CampService writes its text).
function builders.board(m, cf)
	for _, x in { -2.6, 2.6 } do
		Kit.box(m, "Post", cf * CFrame.new(x, 2.5, 0), V3(0.5, 5, 0.5), C.woodDark, M.Wood)
	end
	local board = Kit.box(m, "Board", cf * CFrame.new(0, 3.6, 0), V3(5.6, 3.2, 0.35), C.woodLight, M.WoodPlanks)
	Kit.box(
		m,
		"Roof",
		cf * CFrame.new(0, 5.5, 0) * CFrame.Angles(math.rad(-12), 0, 0),
		V3(6.4, 0.3, 1.6),
		C.woodDark,
		M.Wood,
		{
			CastShadow = false,
		}
	)
	local label = Kit.text(board, Enum.NormalId.Front, "CAMP BOARD", {
		name = "Info",
		font = Enum.Font.LuckiestGuy,
		color = C.woodDark,
		ppu = 36,
	})
	label.TextScaled = true
	return board
end

function builders.bell(m, cf)
	for _, x in { -1.8, 1.8 } do
		Kit.box(m, "Post", cf * CFrame.new(x, 3, 0), V3(0.5, 6, 0.5), C.woodDark, M.Wood)
	end
	Kit.box(m, "Beam", cf * CFrame.new(0, 6, 0), V3(4.4, 0.5, 0.6), C.woodDark, M.Wood)
	local bell = Kit.ellipsoid(m, "Bell", cf.Position + V3(0, 4.6, 0), V3(1.8, 2.2, 1.8), C.gold, M.Metal)
	return bell
end

-- A standing stone for one difficulty (lit when someone in the server has unlocked it).
function builders.stone(m, cf, opts)
	local stone =
		Kit.box(m, "Stone", cf * CFrame.new(0, 2.4, 0), V3(2, 4.8, 1.2), C.stone:Lerp(C.rockMoss, 0.2), M.Rock)
	local glyph = Kit.box(m, "Glyph", cf * CFrame.new(0, 3, -0.62), V3(1.2, 1.2, 0.1), C.glowcap, M.Neon, {
		CanCollide = false,
		CastShadow = false,
		Transparency = 0.5,
	})
	Kit.text(glyph, Enum.NormalId.Front, opts.text or "?", { font = Enum.Font.LuckiestGuy, color = C.white, ppu = 30 })
	return stone, glyph
end

-- An A-frame canvas tent.
function builders.tent(m, cf, opts)
	local col = opts.color or C.canvas
	for _, side in { -1, 1 } do
		Kit.wedge(
			m,
			"Canvas",
			cf * CFrame.new(side * 1.6, 1.8, 0) * CFrame.Angles(0, side > 0 and 0 or math.pi, 0),
			V3(5, 3.6, 3.2),
			col,
			M.Fabric
		)
	end
	Kit.box(m, "Door", cf * CFrame.new(0, 1.2, -2.5), V3(1.6, 2.2, 0.1), col:Lerp(C.black, 0.45), M.Fabric, {
		CanCollide = false,
		CastShadow = false,
	})
	Kit.box(m, "Ridge", cf * CFrame.new(0, 3.65, 0), V3(0.25, 0.25, 5.4), C.woodDark, M.Wood, { CastShadow = false })
	return m
end

-- A log to sit on round the fire.
function builders.seat(m, cf)
	Kit.cyl(m, "Seat", cf * CFrame.new(0, 0.7, 0), 5, 1.5, C.bark, M.Wood)
	return m
end

function CampModels.build(key, cf, opts)
	opts = opts or {}
	local m = Kit.model(opts.name or key, nil)
	local fn = builders[key]
	assert(fn, "no camp model for " .. tostring(key))
	fn(m, cf, opts)
	if opts.ghost then
		ghostify(m)
	end
	m.Parent = opts.parent
	return m
end

CampModels.has = function(key)
	return builders[key] ~= nil
end

return CampModels

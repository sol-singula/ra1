--[[
What floats (master plan §7.1: common pickups you can tell apart from far away): the debris, the supply crate, the
bottle, a lost bag, a drifting trunk. OceanModels.debris(kind, cf, parent) -> model (anchored; the server moves it
with the current). And the island props: palms, rocks, plants, ore, containers, salvage piles, huts, totems...

  OceanModels.debris(kind, cf, parent)
  OceanModels.prop(kind, cf, rng, parent)
]]
local Kit = require(script.Parent.Kit)

local OceanModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local function p(m, name, cf, size, color, material, extra)
	local e = { CanCollide = false, CanQuery = true }
	for k, v in extra or {} do
		e[k] = v
	end
	return Kit.box(m, name, cf, size, color, material, e)
end

-- Debris -------------------------------------------------------------------------------------------------------
local debris = {}

function debris.wood(m, cf)
	p(m, "Log", cf * CFrame.Angles(0, 0.4, 0), V3(3.4, 0.8, 0.9), C.bark, M.Wood)
	p(m, "Plank", cf * CFrame.new(0.6, 0.2, 0.6) * CFrame.Angles(0, -0.3, 0), V3(2.6, 0.3, 0.7), C.plank, M.WoodPlanks)
end

function debris.scrap(m, cf)
	p(
		m,
		"Barrel",
		cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(80)),
		V3(1.8, 1.4, 1.4),
		Color3.fromRGB(60, 140, 200),
		M.Plastic
	)
	p(m, "Bits", cf * CFrame.new(1.2, 0, 0.6), V3(0.9, 0.3, 0.9), C.iron, M.CorrodedMetal)
end

function debris.rope(m, cf)
	Kit.cyl(m, "Coil", cf * CFrame.Angles(0, 0, math.rad(90)), 0.6, 2.2, C.rope, M.Fabric, { CanCollide = false })
	Kit.cyl(
		m,
		"Hole",
		cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		0.7,
		0.8,
		C.water,
		M.SmoothPlastic,
		{ CanCollide = false, CastShadow = false }
	)
end

function debris.cloth(m, cf)
	p(m, "Sail", cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0.7, 0), V3(3, 0.15, 2.2), C.canvas, M.Fabric)
	p(
		m,
		"Fold",
		cf * CFrame.new(0.4, 0.3, -0.3) * CFrame.Angles(0.2, 0.2, 0),
		V3(1.6, 0.2, 1.2),
		C.canvas:Lerp(C.cloth, 0.3),
		M.Fabric
	)
end

function debris.metal(m, cf)
	p(m, "Plate", cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0.5, 0.15), V3(2.4, 0.3, 1.6), C.steel, M.Metal)
	p(m, "Bolt", cf * CFrame.new(0.6, 0.35, 0.3), V3(0.4, 0.4, 0.4), C.iron, M.Metal)
end

function debris.supply_crate(m, cf)
	p(m, "Crate", cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0.3, 0), V3(2.4, 2.2, 2.4), C.wood, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		p(m, "Band", cf * CFrame.new(sx * 0.8, 0.6, 0) * CFrame.Angles(0, 0.3, 0), V3(0.3, 2.3, 2.5), C.iron, M.Metal)
	end
	local beacon = Kit.ball(m, "Beacon", cf.Position + V3(0, 2.2, 0), 0.6, C.canvasRed, M.Neon, { CanCollide = false })
	Kit.light(beacon, "PointLight", { Name = "Glow", Color = C.canvasRed, Range = 12, Brightness = 1 })
end

function debris.bottle(m, cf)
	Kit.cyl(
		m,
		"Glass",
		cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0.4, 0.2),
		1.6,
		0.6,
		Color3.fromRGB(120, 200, 170),
		M.Glass,
		{ CanCollide = false, Transparency = 0.35 }
	)
	p(m, "Cork", cf * CFrame.new(0.9, 0.35, 0.3), V3(0.3, 0.3, 0.3), C.woodLight, M.Wood)
	p(m, "Note", cf * CFrame.new(0, 0.2, 0), V3(0.9, 0.3, 0.3), C.cream, M.Fabric)
end

function debris.lost_bag(m, cf)
	p(m, "Bag", cf * CFrame.new(0, 0.5, 0), V3(1.8, 1.4, 1.2), C.canvasGreen, M.Fabric)
	p(m, "Strap", cf * CFrame.new(0, 1.1, 0), V3(1.9, 0.2, 0.3), C.woodDark, M.Fabric)
	local glow = Kit.ball(m, "Glow", cf.Position + V3(0, 1.6, 0), 0.5, C.warm, M.Neon, { CanCollide = false })
	Kit.light(glow, "PointLight", { Name = "Light", Color = C.warm, Range = 10, Brightness = 0.8 })
end

function OceanModels.debris(kind, cf, parent)
	local m = Instance.new("Model")
	m.Name = kind
	local fn = debris[kind] or debris.wood
	fn(m, cf)
	m:SetAttribute("Debris", kind)
	m.Parent = parent
	return m
end

-- Far islands --------------------------------------------------------------------------------------------------
-- A far island you can see but never reach (the horizon, and the place you're sailing to while you sail):
-- h = { size, kind = "peak" | "low" | "atoll", far = 0..1 }. Green humps with trees, a peak with snow on the big
-- ones, or a sandy atoll with palms; no shadows or collisions, it is scenery.
local FAR_PART = { CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false }

function OceanModels.isle(parent, name, base, h, rng)
	local m = Kit.model(name, parent)
	local s = h.size
	local sandy = h.kind == "atoll"
	Kit.ellipsoid(m, "Shore", base + V3(0, s * 0.04, 0), V3(s * 2.6, s * 0.2, s * 2), C.sand, M.Sand, FAR_PART)
	if not sandy then
		Kit.ellipsoid(
			m,
			"Isle",
			base + V3(0, s * 0.14, 0),
			V3(s * 2.1, s * 0.5, s * 1.6),
			C.grassDark,
			M.Grass,
			FAR_PART
		)
		Kit.ellipsoid(
			m,
			"Hump",
			base + V3(rng:NextNumber(-0.3, 0.3) * s, s * 0.26, rng:NextNumber(-0.2, 0.2) * s),
			V3(s * 1.1, s * 0.5, s * 0.9),
			C.grass,
			M.Grass,
			FAR_PART
		)
	end
	if h.kind == "peak" then
		local hh = s * (1.1 + (h.far or 0.5) * 0.5)
		Kit.cone(m, "Peak", base + V3(0, s * 0.2, 0), s * 0.95, hh, C.rockDark, 6, M.Rock, FAR_PART)
		if hh > 60 then
			Kit.cone(
				m,
				"Snow",
				base + V3(0, s * 0.2 + hh * 0.62, 0),
				s * 0.95 * 0.38,
				hh * 0.38,
				C.white,
				6,
				M.Snow,
				FAR_PART
			)
		end
		Kit.cone(m, "Peak2", base + V3(s * 0.45, s * 0.18, s * 0.2), s * 0.6, hh * 0.55, C.rock, 5, M.Rock, FAR_PART)
	end
	for _ = 1, sandy and 6 or 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0.25, 0.8) * s
		local at = base + V3(math.cos(a) * r, sandy and s * 0.08 or s * 0.34, math.sin(a) * r * 0.75)
		if sandy then
			local th = s * rng:NextNumber(0.25, 0.4)
			Kit.cyl(
				m,
				"Trunk",
				CFrame.new(at + V3(0, th / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				th,
				s * 0.05,
				C.bark,
				M.Wood,
				FAR_PART
			)
			Kit.ellipsoid(m, "Fronds", at + V3(0, th, 0), V3(s * 0.4, s * 0.12, s * 0.4), C.leaf, M.Grass, FAR_PART)
		else
			Kit.ellipsoid(
				m,
				"Trees",
				at,
				V3(s * rng:NextNumber(0.3, 0.5), s * rng:NextNumber(0.25, 0.4), s * rng:NextNumber(0.3, 0.5)),
				C.pineDark:Lerp(C.leaf, rng:NextNumber(0, 0.5)),
				M.Grass,
				FAR_PART
			)
		end
	end
	return m
end

-- Island props ---------------------------------------------------------------------------------------------------
local props = {}

function props.palm(m, pos, rng)
	local h = rng:NextNumber(9, 14)
	local lean = rng:NextNumber(-0.18, 0.18)
	local cf = CFrame.new(pos) * CFrame.Angles(lean, rng:NextNumber(0, math.pi * 2), 0)
	Kit.cyl(m, "Trunk", cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), h, 0.9, C.bark, M.Wood)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		p(
			m,
			"Frond",
			cf
				* CFrame.new(0, h, 0)
				* CFrame.Angles(0, a, 0)
				* CFrame.new(2.2, 0.2, 0)
				* CFrame.Angles(0, 0, math.rad(-28)),
			V3(4.6, 0.12, 1.2),
			C.leaf:Lerp(C.leafLight, rng:NextNumber(0, 0.4)),
			M.Grass,
			{ CastShadow = k < 3 }
		)
	end
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		Kit.ball(
			m,
			"Coconut",
			cf.Position + cf.UpVector * (h - 0.6) + V3(math.cos(a) * 0.6, 0, math.sin(a) * 0.6),
			0.6,
			C.bark:Lerp(C.woodDark, 0.4),
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end
end

function props.rock(m, pos, rng)
	Kit.boulder(m, pos - V3(0, 0.6, 0), rng:NextNumber(3.5, 6), rng, C.rock, M.Rock)
end

function props.ore_rock(m, pos, rng)
	Kit.boulder(m, pos - V3(0, 0.6, 0), rng:NextNumber(3.5, 5.5), rng, C.rockDark, M.Rock)
	for _ = 1, 4 do
		local a = rng:NextNumber(0, math.pi * 2)
		Kit.ball(
			m,
			"Vein",
			pos + V3(math.cos(a) * 1.6, rng:NextNumber(0.4, 1.8), math.sin(a) * 1.6),
			rng:NextNumber(0.5, 0.9),
			Color3.fromRGB(220, 140, 60),
			M.Metal,
			{ CanCollide = false }
		)
	end
end

function props.crystal_rock(m, pos, rng, color)
	Kit.boulder(m, pos - V3(0, 0.6, 0), rng:NextNumber(3, 5), rng, C.rockDark, M.Rock)
	Kit.crystals(m, pos + V3(0, 0.8, 0), rng:NextNumber(2, 3.4), color or C.glowcap, rng, 4)
end

function props.plant(m, pos, rng)
	Kit.fern(m, pos, rng, rng:NextNumber(1.6, 2.4))
	Kit.ball(m, "Berries", pos + V3(0, 1.1, 0), 1.8, C.leafDark, M.Grass, { CanCollide = false })
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		Kit.ball(
			m,
			"Berry",
			pos + V3(math.cos(a) * 0.8, 1.3, math.sin(a) * 0.8),
			0.35,
			C.flowerBlue,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
end

function props.container(m, pos, rng)
	local cf = CFrame.new(pos + V3(0, 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	p(m, "Crate", cf, V3(2.6, 2, 2.6), C.wood, M.WoodPlanks, { CanCollide = true })
	p(m, "Lid", cf * CFrame.new(0, 1.1, 0), V3(2.8, 0.25, 2.8), C.woodDark, M.Wood)
	p(m, "Lock", cf * CFrame.new(0, 0.2, -1.33), V3(0.6, 0.6, 0.1), C.gold, M.Metal)
end

function props.locker(m, pos, rng)
	local cf = CFrame.new(pos + V3(0, 1.6, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	p(m, "Locker", cf, V3(2, 3.2, 1.4), C.iron, M.CorrodedMetal, { CanCollide = true })
	p(m, "Door", cf * CFrame.new(0.3, 0, -0.75), V3(1.2, 2.8, 0.1), C.steel, M.Metal)
end

function props.salvage(m, pos, rng)
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2
		p(
			m,
			"Scrap",
			CFrame.new(pos + V3(math.cos(a) * 1.2, 0.4 + (k % 2) * 0.4, math.sin(a) * 1.2))
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.4, 0.4)),
			V3(rng:NextNumber(1.2, 2.2), 0.3, rng:NextNumber(0.6, 1.4)),
			k % 2 == 0 and C.iron or C.steel,
			k % 2 == 0 and M.CorrodedMetal or M.Metal
		)
	end
	p(
		m,
		"Hull",
		CFrame.new(pos + V3(0, 1.2, 0)) * CFrame.Angles(0.3, rng:NextNumber(0, 6), 0.2),
		V3(2.4, 2, 0.4),
		C.canvasRed:Lerp(C.iron, 0.5),
		M.CorrodedMetal
	)
end

function props.campfire(m, pos)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Kit.ball(
			m,
			"Stone",
			pos + V3(math.cos(a) * 1.4, 0.3, math.sin(a) * 1.4),
			0.8,
			C.stone,
			M.Rock,
			{ CanCollide = false }
		)
	end
	p(m, "Log", CFrame.new(pos + V3(0, 0.4, 0)) * CFrame.Angles(0, 0.5, 0), V3(2, 0.5, 0.5), C.deadWood, M.Wood)
	p(m, "Log", CFrame.new(pos + V3(0, 0.4, 0)) * CFrame.Angles(0, 2.1, 0), V3(2, 0.5, 0.5), C.deadWood, M.Wood)
	p(m, "Ash", CFrame.new(pos + V3(0, 0.15, 0)), V3(1.6, 0.1, 1.6), C.rockDark, M.Sand)
end

function props.hut(m, pos, rng)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	p(m, "Floor", cf * CFrame.new(0, 0.3, 0), V3(8, 0.6, 7), C.woodDark, M.WoodPlanks, { CanCollide = true })
	p(m, "Back", cf * CFrame.new(0, 2.5, -3.3), V3(8, 4.4, 0.4), C.wood, M.WoodPlanks, { CanCollide = true })
	p(m, "Side", cf * CFrame.new(-3.8, 2.5, 0), V3(0.4, 4.4, 7), C.wood, M.WoodPlanks, { CanCollide = true })
	p(m, "Side", cf * CFrame.new(3.8, 2.5, 1.4), V3(0.4, 4.4, 4.2), C.wood, M.WoodPlanks, { CanCollide = true })
	p(
		m,
		"Roof",
		cf * CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(8), 0, 0),
		V3(9, 0.4, 8.4),
		C.fern:Lerp(C.deadWood, 0.5),
		M.Grass
	)
	p(m, "Table", cf * CFrame.new(-1.6, 1.4, -1.6), V3(2.4, 0.3, 1.6), C.woodLight, M.Wood)
end

function props.totem(m, pos, rng)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	p(m, "Base", cf * CFrame.new(0, 0.5, 0), V3(2.4, 1, 2.4), C.rockDark, M.Rock, { CanCollide = true })
	p(
		m,
		"Body",
		cf * CFrame.new(0, 3, 0),
		V3(1.8, 4, 1.8),
		C.stone:Lerp(C.rockMoss, 0.5),
		M.Rock,
		{ CanCollide = true }
	)
	p(m, "Eye", cf * CFrame.new(-0.4, 4, -0.95), V3(0.5, 0.5, 0.2), C.ink, M.SmoothPlastic)
	p(m, "Eye", cf * CFrame.new(0.4, 4, -0.95), V3(0.5, 0.5, 0.2), C.ink, M.SmoothPlastic)
	p(m, "Mouth", cf * CFrame.new(0, 2.8, -0.95), V3(1.1, 0.3, 0.2), C.ink, M.SmoothPlastic)
	Kit.cone(m, "Hat", cf.Position + V3(0, 5, 0), 2.4, 1.6, C.rockDark, 3, M.Rock, { CanCollide = false })
end

function props.lantern_post(m, pos)
	p(m, "Post", CFrame.new(pos + V3(0, 2.2, 0)), V3(0.4, 4.4, 0.4), C.woodDark, M.Wood, { CanCollide = true })
	p(m, "Cage", CFrame.new(pos + V3(0, 4.2, 0)), V3(1, 1.2, 1), C.iron, M.Metal)
	local glass =
		p(m, "Glass", CFrame.new(pos + V3(0, 4.2, 0)), V3(0.8, 1, 0.8), C.rockDark, M.Glass, { Transparency = 0.4 })
	_ = glass
end

function props.ruin_wall(m, pos, rng)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for k = -2, 2 do
		local h = rng:NextNumber(2, 6)
		p(
			m,
			"Block",
			cf * CFrame.new(k * 2.1, h / 2, 0),
			V3(2, h, 1.6),
			C.stone:Lerp(C.rockMoss, rng:NextNumber(0, 0.6)),
			M.Rock,
			{ CanCollide = true }
		)
	end
	p(m, "Vines", cf * CFrame.new(0, 2.5, -0.9), V3(9, 3, 0.2), C.leafDark, M.Grass, { CastShadow = false })
end

function props.old_machine(m, pos, rng)
	local cf = CFrame.new(pos + V3(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	p(m, "Body", cf, V3(3.6, 3, 2.6), C.iron, M.CorrodedMetal, { CanCollide = true })
	local core = p(m, "Core", cf * CFrame.new(0, 0.3, -1.35), V3(1.2, 1.2, 0.2), C.glowcap, M.Neon)
	Kit.light(core, "PointLight", { Name = "Glow", Color = C.glowcap, Range = 10, Brightness = 0.8 })
	p(m, "Pipe", cf * CFrame.new(1.4, 2, 0), V3(0.6, 1.6, 0.6), C.steel, M.Metal)
end

function props.wreck_hull(m, pos, rng)
	-- a ship on its side: a long hull, a broken mast, a deck you can walk on
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	p(
		m,
		"Hull",
		cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(22)),
		V3(26, 6, 9),
		C.woodDark:Lerp(C.deadWood, 0.4),
		M.WoodPlanks,
		{ CanCollide = true }
	)
	p(
		m,
		"Deck",
		cf * CFrame.new(0, 4.6, -2) * CFrame.Angles(0, 0, math.rad(22)),
		V3(24, 0.6, 7),
		C.plank:Lerp(C.deadWood, 0.5),
		M.WoodPlanks,
		{ CanCollide = true }
	)
	p(
		m,
		"Cabin",
		cf * CFrame.new(-7, 7, -2) * CFrame.Angles(0, 0, math.rad(22)),
		V3(6, 4, 5),
		C.wood:Lerp(C.deadWood, 0.5),
		M.WoodPlanks,
		{ CanCollide = true }
	)
	p(
		m,
		"Mast",
		cf * CFrame.new(3, 8, -2) * CFrame.Angles(0, 0, math.rad(60)),
		V3(0.8, 12, 0.8),
		C.woodDark,
		M.Wood,
		{ CanCollide = true }
	)
	p(m, "Rail", cf * CFrame.new(0, 5.6, 1.4) * CFrame.Angles(0, 0, math.rad(22)), V3(22, 1, 0.3), C.woodDark, M.Wood)
	for k = -2, 2 do
		p(
			m,
			"Rib",
			cf * CFrame.new(k * 5, 1, 4) * CFrame.Angles(0, 0, math.rad(22)),
			V3(0.6, 4, 0.6),
			C.deadWood,
			M.Wood
		)
	end
end

function props.ice_block(m, pos, rng)
	p(
		m,
		"Ice",
		CFrame.new(pos + V3(0, 1.2, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), 0),
		V3(rng:NextNumber(2, 4), rng:NextNumber(2, 3.4), rng:NextNumber(2, 3.6)),
		Color3.fromRGB(190, 225, 240),
		M.Ice,
		{ CanCollide = true, Transparency = 0.15 }
	)
end

function props.lava_pool(m, pos)
	local lava = Kit.disc(m, "Lava", pos + V3(0, 0.1, 0), 6, 0.3, C.ember, M.Neon, { CanCollide = false })
	Kit.light(lava, "PointLight", { Name = "Glow", Color = C.ember, Range = 16, Brightness = 1.2 })
	Kit.disc(m, "Crust", pos + V3(0, 0.05, 0), 7.4, 0.2, C.rockDark, M.Basalt, { CanCollide = false })
end

function props.seat_rock(m, pos, rng)
	Kit.boulder(m, pos - V3(0, 1.4, 0), rng:NextNumber(5, 7), rng, C.rock, M.Rock)
end

function OceanModels.prop(kind, pos, rng, parent, extra)
	local m = Instance.new("Model")
	m.Name = kind
	local fn = props[kind]
	if fn then
		fn(m, pos, rng or Random.new(), extra)
	end
	m:SetAttribute("Prop", kind)
	m.Parent = parent
	return m
end

return OceanModels

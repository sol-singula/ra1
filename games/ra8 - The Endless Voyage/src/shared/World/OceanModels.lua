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
-- Each piece sits half in the water (the pivot is just above the surface) with a ring of foam round it, so you can
-- spot it from far off and it reads as floating, not resting on glass.
local debris = {}
local WATERLINE = -0.3 -- the water's surface, from the pivot

local function foam(m, cf, w, d)
	-- a loose ring of little foam blobs where the piece meets the water (not a plate)
	local r = math.max(w, d) / 2 + 0.15
	local n = 9
	local first
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2 + (k % 2) * 0.2
		local rr = r * (0.85 + (k % 3) * 0.1)
		local blob = Kit.ellipsoid(
			m,
			k == 0 and "Foam" or "FoamBit",
			cf.Position + V3(math.cos(a) * rr, WATERLINE + 0.03, math.sin(a) * rr),
			V3(0.9 + (k % 2) * 0.4, 0.07, 0.5),
			Color3.fromRGB(245, 250, 255),
			M.SmoothPlastic,
			{ CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.35 }
		)
		blob.CFrame = CFrame.new(blob.Position) * CFrame.Angles(0, -a + math.pi / 2, 0)
		first = first or blob
	end
	return first
end

-- a plank with darker grain lines and two nail heads
local function plank(m, name, cf, len, w, color)
	p(m, name, cf, V3(len, 0.32, w), color, M.WoodPlanks)
	for _, z in { -w * 0.22, w * 0.22 } do
		p(
			m,
			name .. "Grain",
			cf * CFrame.new(0, 0.17, z),
			V3(len * 0.9, 0.02, 0.06),
			color:Lerp(C.woodDark, 0.45),
			M.Wood,
			{ CanQuery = false }
		)
	end
	for _, x in { -len * 0.4, len * 0.4 } do
		p(m, name .. "Nail", cf * CFrame.new(x, 0.18, 0), V3(0.12, 0.04, 0.12), C.iron, M.Metal, { CanQuery = false })
	end
end

function debris.wood(m, cf)
	foam(m, cf, 3.6, 2.4)
	-- a short log with pale cut ends, and two loose planks across it
	Kit.cyl(
		m,
		"Log",
		cf * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0.4, 0),
		3.2,
		0.95,
		C.bark,
		M.Wood,
		{ CanCollide = false }
	)
	for _, sx in { -1, 1 } do
		Kit.cyl(
			m,
			"LogEnd",
			cf * CFrame.Angles(0, 0.4, 0) * CFrame.new(sx * 1.61, -0.15, 0),
			0.04,
			0.8,
			C.woodLight,
			M.Wood,
			{ CanCollide = false, CanQuery = false }
		)
	end
	plank(m, "Plank", cf * CFrame.new(0.3, 0.32, 0.5) * CFrame.Angles(0, -0.35, 0.06), 2.8, 0.7, C.plank)
	plank(
		m,
		"Plank2",
		cf * CFrame.new(-0.4, 0.2, -0.55) * CFrame.Angles(0, 0.9, -0.05),
		2.2,
		0.6,
		C.plank:Lerp(C.woodLight, 0.3)
	)
end

function debris.scrap(m, cf)
	foam(m, cf, 2.6, 2.2)
	-- a blue barrel on its side, with metal hoops and a cap, and a bit of scrap beside it
	local body = cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0.5, 0)
	Kit.cyl(m, "Barrel", body, 2, 1.4, Color3.fromRGB(52, 128, 196), M.SmoothPlastic, { CanCollide = false })
	for _, x in { -0.65, 0, 0.65 } do
		Kit.cyl(
			m,
			"Hoop",
			body * CFrame.new(x, 0, 0),
			0.12,
			1.48,
			Color3.fromRGB(36, 92, 150),
			M.SmoothPlastic,
			{ CanCollide = false, CanQuery = false }
		)
	end
	Kit.cyl(
		m,
		"Cap",
		body * CFrame.new(1.03, 0.3, 0),
		0.08,
		0.32,
		C.white,
		M.SmoothPlastic,
		{ CanCollide = false, CanQuery = false }
	)
	p(
		m,
		"Bits",
		cf * CFrame.new(1.3, -0.1, 0.8) * CFrame.Angles(0.2, 0.6, 0.1),
		V3(0.9, 0.25, 0.7),
		C.iron,
		M.CorrodedMetal
	)
end

function debris.rope(m, cf)
	foam(m, cf, 2.4, 2.4)
	-- a coil of rope: rings of rope round a hole, a loose end trailing, on a cork float
	Kit.cyl(
		m,
		"Float",
		cf * CFrame.new(0, -0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		0.35,
		2.4,
		C.woodLight,
		M.Wood,
		{ CanCollide = false }
	)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		p(
			m,
			"Coil",
			cf * CFrame.new(math.cos(a) * 0.75, 0.15, math.sin(a) * 0.75) * CFrame.Angles(0, -a, 0),
			V3(0.32, 0.32, 0.52),
			C.rope,
			M.Fabric
		)
	end
	for k = 0, 9 do
		local a = (k + 0.5) / 10 * math.pi * 2
		p(
			m,
			"Coil2",
			cf * CFrame.new(math.cos(a) * 0.55, 0.38, math.sin(a) * 0.55) * CFrame.Angles(0, -a, 0),
			V3(0.28, 0.28, 0.4),
			C.rope:Lerp(C.woodLight, 0.2),
			M.Fabric,
			{ CanQuery = false }
		)
	end
	p(
		m,
		"End",
		cf * CFrame.new(1.3, 0.05, 0.4) * CFrame.Angles(0, 0.4, 0),
		V3(1.2, 0.2, 0.2),
		C.rope,
		M.Fabric,
		{ CanQuery = false }
	)
end

function debris.cloth(m, cf)
	foam(m, cf, 3.2, 2.6)
	-- a bundle of canvas tied with rope, a corner of it spread on the water
	p(m, "Sail", cf * CFrame.new(0.3, -0.1, 0.2) * CFrame.Angles(0, 0.7, 0.03), V3(3, 0.1, 2.2), C.canvas, M.Fabric)
	p(
		m,
		"Bundle",
		cf * CFrame.new(-0.3, 0.25, -0.2) * CFrame.Angles(0.1, 0.3, 0),
		V3(1.8, 0.8, 1.2),
		C.canvas:Lerp(C.cloth, 0.35),
		M.Fabric
	)
	p(
		m,
		"Fold",
		cf * CFrame.new(-0.25, 0.68, -0.2) * CFrame.Angles(0.1, 0.3, 0.1),
		V3(1.5, 0.15, 1),
		C.canvas,
		M.Fabric,
		{ CanQuery = false }
	)
	for _, x in { -0.5, 0.4 } do
		p(
			m,
			"Tie",
			cf * CFrame.new(-0.3, 0.25, -0.2) * CFrame.Angles(0.1, 0.3, 0) * CFrame.new(x, 0, 0),
			V3(0.14, 0.86, 1.26),
			C.rope,
			M.Fabric,
			{ CanQuery = false }
		)
	end
end

function debris.metal(m, cf)
	foam(m, cf, 3, 2.2)
	-- a corrugated sheet on a floating crate lid, and a pipe
	local base = cf * CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0.5, 0.05)
	p(m, "Lid", base * CFrame.new(0, -0.15, 0), V3(2.6, 0.3, 1.9), C.wood, M.WoodPlanks)
	for k = -3, 3 do
		p(
			m,
			"Ridge",
			base * CFrame.new(k * 0.34, 0.08, 0),
			V3(0.18, 0.16, 1.7),
			k % 2 == 0 and C.steel or C.steel:Lerp(C.iron, 0.4),
			M.Metal
		)
	end
	Kit.cyl(
		m,
		"Pipe",
		cf * CFrame.new(0.4, 0.35, 0.9) * CFrame.Angles(0, -0.4, 0),
		1.8,
		0.35,
		C.iron,
		M.CorrodedMetal,
		{ CanCollide = false }
	)
	p(m, "Bolt", cf * CFrame.new(-0.7, 0.3, -0.5), V3(0.3, 0.3, 0.3), C.iron, M.Metal)
end

function debris.supply_crate(m, cf)
	foam(m, cf, 3, 3)
	-- a sturdy crate: planked sides, dark edges, iron corners, a red flag on a pole and a blinking light
	local box = cf * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0.3, 0)
	p(m, "Crate", box, V3(2.4, 2.1, 2.4), C.wood, M.WoodPlanks)
	for _, y in { -0.7, 0, 0.7 } do
		p(m, "Slat", box * CFrame.new(0, y, 1.22), V3(2.3, 0.08, 0.06), C.woodDark, M.Wood, { CanQuery = false })
		p(m, "SlatB", box * CFrame.new(0, y, -1.22), V3(2.3, 0.08, 0.06), C.woodDark, M.Wood, { CanQuery = false })
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			p(
				m,
				"Corner",
				box * CFrame.new(sx * 1.17, 0, sz * 1.17),
				V3(0.2, 2.2, 0.2),
				C.iron,
				M.Metal,
				{ CanQuery = false }
			)
		end
	end
	p(m, "Lid", box * CFrame.new(0, 1.1, 0), V3(2.5, 0.16, 2.5), C.woodDark, M.WoodPlanks, { CanQuery = false })
	p(m, "Pole", box * CFrame.new(0.9, 2.1, 0.9), V3(0.12, 2, 0.12), C.woodDark, M.Wood, { CanQuery = false })
	p(m, "Flag", box * CFrame.new(1.35, 2.75, 0.9), V3(0.9, 0.6, 0.05), C.canvasRed, M.Fabric, { CanQuery = false })
	local beacon =
		Kit.ball(m, "Beacon", (box * CFrame.new(0, 1.35, 0)).Position, 0.5, C.canvasRed, M.Neon, { CanCollide = false })
	Kit.light(beacon, "PointLight", { Name = "Glow", Color = C.canvasRed, Range = 14, Brightness = 1.2 })
end

function debris.bottle(m, cf)
	foam(m, cf, 1.8, 1.2)
	-- a green bottle bobbing neck-up, a cork, a rolled note inside
	local body = cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0.4, math.rad(35))
	Kit.cyl(
		m,
		"Glass",
		body,
		1.3,
		0.7,
		Color3.fromRGB(90, 180, 140),
		M.Glass,
		{ CanCollide = false, Transparency = 0.3 }
	)
	Kit.cyl(
		m,
		"Neck",
		body * CFrame.new(0.85, 0, 0),
		0.5,
		0.3,
		Color3.fromRGB(90, 180, 140),
		M.Glass,
		{ CanCollide = false, Transparency = 0.3 }
	)
	Kit.cyl(m, "Cork", body * CFrame.new(1.15, 0, 0), 0.2, 0.26, C.woodLight, M.Wood, { CanCollide = false })
	Kit.cyl(m, "Note", body, 0.9, 0.36, C.cream, M.Fabric, { CanCollide = false, CanQuery = false })
	local sparkle = Kit.ball(
		m,
		"Sparkle",
		cf.Position + V3(0, 0.9, 0),
		0.25,
		C.white,
		M.Neon,
		{ CanCollide = false, CanQuery = false }
	)
	Kit.light(sparkle, "PointLight", { Name = "Glow", Color = C.white, Range = 6, Brightness = 0.6 })
end

function debris.lost_bag(m, cf)
	foam(m, cf, 2.2, 1.6)
	p(m, "Bag", cf * CFrame.new(0, 0.4, 0), V3(1.8, 1.3, 1.2), C.canvasGreen, M.Fabric)
	p(
		m,
		"Flap",
		cf * CFrame.new(0, 1.0, 0.15),
		V3(1.85, 0.2, 0.95),
		C.canvasGreen:Lerp(C.woodDark, 0.25),
		M.Fabric,
		{ CanQuery = false }
	)
	p(m, "Buckle", cf * CFrame.new(0, 0.85, 0.62), V3(0.3, 0.3, 0.06), C.gold, M.Metal, { CanQuery = false })
	p(m, "Strap", cf * CFrame.new(0, 1.15, 0), V3(1.9, 0.18, 0.3), C.woodDark, M.Fabric, { CanQuery = false })
	local glow = Kit.ball(m, "Glow", cf.Position + V3(0, 1.8, 0), 0.5, C.warm, M.Neon, { CanCollide = false })
	Kit.light(glow, "PointLight", { Name = "Light", Color = C.warm, Range = 10, Brightness = 0.8 })
end

function OceanModels.debris(kind, cf, parent)
	local m = Instance.new("Model")
	m.Name = kind
	local fn = debris[kind] or debris.wood
	fn(m, cf)
	m:SetAttribute("Debris", kind)
	-- The clients move debris themselves (DebrisController) from the point it was made at, so: the pivot is that
	-- point (not the middle of whatever parts it has), and the whole piece always streams in at once, never part by
	-- part (parts that arrived after the piece started drifting would land where it was made and drift along away
	-- from where it really is: the guide's arrow and your line would go to empty water). Always streamed in also
	-- means you see it coming from far away.
	m.WorldPivot = cf
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	m.Parent = parent
	return m
end

-- Far islands --------------------------------------------------------------------------------------------------
-- A far island you can see but never reach (the horizon, and the place you're sailing to while you sail):
-- h = { size, kind = "peak" | "low" | "atoll", far = 0..1 }. Built to read from far away: surf round a beach of wet
-- and dry sand, green hills covered in big leafy trees, palms leaning out over the sand, boulders, a jagged rocky
-- peak with pines up its slopes (snow on the tall ones), or a ring of sand round a turquoise lagoon. The trees are
-- big on purpose, so you can pick them out from across the sea. Scenery: no shadows, no collisions, nothing to click.
local FAR_PART = { CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false }

-- a palm: a trunk curving up in four pieces, a crown of arching fronds, coconuts
local function farPalm(m, at, h, rng)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local side = V3(math.cos(yaw), 0, math.sin(yaw))
	local lean = rng:NextNumber(0.12, 0.3) * h
	local function point(t)
		return at + V3(0, h * t, 0) + side * (lean * t * t)
	end
	local prev = point(0)
	for i = 1, 4 do
		local nxt = point(i / 4)
		local mid = (prev + nxt) / 2
		Kit.cyl(
			m,
			"Trunk",
			CFrame.lookAt(mid, nxt) * CFrame.Angles(0, math.rad(90), 0),
			(nxt - prev).Magnitude + h * 0.02,
			h * (0.08 - i * 0.008),
			C.bark:Lerp(C.woodLight, i * 0.06),
			M.Wood,
			FAR_PART
		)
		prev = nxt
	end
	local top = point(1)
	local L = h * 0.46
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local col = C.leaf:Lerp(C.leafLight, rng:NextNumber(0, 0.45))
		local root = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, math.rad(14))
		-- rising a little, then drooping: two leaves end to end
		p(m, "Frond", root * CFrame.new(L * 0.25, 0, 0), V3(L * 0.5, h * 0.014, L * 0.24), col, M.Grass, FAR_PART)
		p(
			m,
			"Frond",
			root * CFrame.new(L * 0.48, 0, 0) * CFrame.Angles(0, 0, math.rad(-48)) * CFrame.new(L * 0.22, 0, 0),
			V3(L * 0.46, h * 0.014, L * 0.18),
			col:Lerp(C.leafDark, 0.2),
			M.Grass,
			FAR_PART
		)
	end
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		Kit.ball(
			m,
			"Coconut",
			top + V3(math.cos(a) * h * 0.04, -h * 0.04, math.sin(a) * h * 0.04),
			h * 0.06,
			C.bark:Lerp(C.woodDark, 0.4),
			M.SmoothPlastic,
			FAR_PART
		)
	end
end

-- a leafy tree: a trunk and a cloud of leaf balls
local function farTree(m, at, h, rng, color)
	Kit.cyl(
		m,
		"Trunk",
		CFrame.new(at + V3(0, h * 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		h * 0.5,
		h * 0.09,
		C.bark,
		M.Wood,
		FAR_PART
	)
	local col = color or C.leaf
	local clumps = {
		{ V3(0, 0.64, 0), 0.62 },
		{ V3(0.2, 0.53, 0.08), 0.46 },
		{ V3(-0.18, 0.55, -0.1), 0.46 },
		{ V3(0.03, 0.82, -0.04), 0.42 },
	}
	for i, c in clumps do
		local jitter = V3(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04)) * h
		Kit.ball(
			m,
			"Leaves",
			at + c[1] * h + jitter,
			h * c[2] * rng:NextNumber(0.9, 1.1),
			col:Lerp(C.leafLight, rng:NextNumber(0, 0.3)):Lerp(C.leafDark, i == 1 and 0.18 or 0),
			M.Grass,
			FAR_PART
		)
	end
end

-- a pine: a trunk and soft stacked tiers of needles
local function farPine(m, at, h, rng)
	Kit.cyl(
		m,
		"Trunk",
		CFrame.new(at + V3(0, h * 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		h * 0.28,
		h * 0.08,
		C.bark,
		M.Wood,
		FAR_PART
	)
	local col = rng:NextNumber() < 0.5 and C.pine or C.pineDark
	for i = 0, 3 do
		local t = i / 3
		local d = h * (0.56 - 0.38 * t)
		Kit.ellipsoid(
			m,
			"Needles",
			at + V3(0, h * (0.28 + 0.5 * t), 0),
			V3(d, h * 0.26, d),
			col:Lerp(C.leafLight, 0.12 * t),
			M.Grass,
			FAR_PART
		)
	end
end

-- Snow over the top of a Kit.roofCone: the cone's own wedges (as wide, as steep) from `from` of the way up, pushed
-- out a little, so the snow lies on the rock all the way round and no rock edge pokes through it. Each runs a little
-- past the middle too, so its back face isn't in the same plane as the rock's (they'd flicker).
local function snowCap(m, base, radius, height, sides, from)
	local margin, back = 0.6, 0.5
	local w = 2 * math.pi * radius / sides * 1.06 + margin * 2
	local depth = radius * (1 - from) + margin + back
	local tall = depth * height / radius
	for k = 0, sides - 1 do
		local a = (k + 0.5) / sides * math.pi * 2
		local dir = V3(math.cos(a), 0, math.sin(a))
		local pos = base + V3(0, height * from + tall / 2, 0) + dir * (depth / 2 - back)
		Kit.wedge(m, "Snow", CFrame.lookAt(pos, pos + dir), V3(w, tall, depth), C.white, M.Snow, FAR_PART)
	end
end

function OceanModels.isle(parent, name, base, h, rng)
	local m = Kit.model(name, parent)
	local s = h.size
	local kind = h.kind
	local sea = base.Y + 2 -- (the island's base sits 2 studs under the water)
	-- the ground: every land ellipsoid, so trees and rocks stand on it
	local lands = {}
	local function land(partName, center, size, color, material)
		Kit.ellipsoid(m, partName, center, size, color, material, FAR_PART)
		table.insert(lands, { c = center, r = size / 2 })
	end
	local function groundAt(x, z)
		local best
		for _, l in lands do
			local dx, dz = (x - l.c.X) / l.r.X, (z - l.c.Z) / l.r.Z
			local k = 1 - dx * dx - dz * dz
			if k > 0 then
				local y = l.c.Y + l.r.Y * math.sqrt(k)
				best = (not best or y > best) and y or best
			end
		end
		return best
	end
	-- a random spot on the land between two shares of the radius, and the ground there
	local function spotOn(minShare, maxShare)
		for _ = 1, 10 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(minShare, maxShare)
			local x, z = base.X + math.cos(a) * r * s * 1.2, base.Z + math.sin(a) * r * s * 0.95
			local y = groundAt(x, z)
			if y and y > sea + 0.5 then
				return V3(x, y - 0.3, z)
			end
		end
		return nil
	end
	-- surf where it meets the sea, then wet sand, then dry sand
	Kit.ellipsoid(
		m,
		"Surf",
		V3(base.X, sea, base.Z),
		V3(s * 2.95, 0.7, s * 2.35),
		C.white,
		M.SmoothPlastic,
		{ CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.35 }
	)
	if kind == "atoll" then
		-- a ring of sand round a lagoon
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			land(
				"Sand",
				base + V3(math.cos(a) * s * 0.95, s * 0.03, math.sin(a) * s * 0.75),
				V3(s * 0.9, s * 0.16, s * 0.62),
				C.sand:Lerp(C.white, rng:NextNumber(0, 0.12)),
				M.Sand
			)
		end
		Kit.cyl(
			m,
			"Lagoon",
			CFrame.new(base.X, sea + 0.15, base.Z) * CFrame.Angles(0, 0, math.rad(90)),
			0.3,
			s * 1.5,
			Color3.fromRGB(80, 214, 214),
			M.SmoothPlastic,
			{ CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.15 }
		)
		for _ = 1, 9 + math.floor(s / 12) do
			local a = rng:NextNumber(0, math.pi * 2)
			local x, z = base.X + math.cos(a) * s * 0.95, base.Z + math.sin(a) * s * 0.75
			local y = groundAt(x, z)
			if y then
				farPalm(m, V3(x, y - 0.3, z), s * rng:NextNumber(0.32, 0.45), rng)
			end
		end
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local at = base + V3(math.cos(a) * s * 1.2, 1, math.sin(a) * s * 0.95)
			Kit.boulder(m, at, s * rng:NextNumber(0.12, 0.2), rng, C.rock, M.Rock)
		end
	else
		land("WetSand", base + V3(0, s * 0.02, 0), V3(s * 2.75, s * 0.18, s * 2.15), C.sand:Lerp(C.bark, 0.18), M.Sand)
		land("Sand", base + V3(0, s * 0.04, 0), V3(s * 2.45, s * 0.22, s * 1.9), C.sand, M.Sand)
		-- green hills
		land("Isle", base + V3(0, s * 0.1, 0), V3(s * 1.95, s * 0.5, s * 1.5), C.grassDark, M.Grass)
		land(
			"Hump",
			base + V3(rng:NextNumber(-0.3, 0.3) * s, s * 0.2, rng:NextNumber(-0.2, 0.2) * s),
			V3(s * 1.15, s * 0.58, s * 0.95),
			C.grass,
			M.Grass
		)
		land(
			"Hump",
			base + V3(rng:NextNumber(-0.5, 0.5) * s, s * 0.14, rng:NextNumber(-0.35, 0.35) * s),
			V3(s * 0.8, s * 0.42, s * 0.7),
			C.grass:Lerp(C.leafLight, 0.2),
			M.Grass
		)
		if kind == "peak" then
			-- a jagged rocky mountain (two peaks), pines up its lower slopes, snow on the tall ones
			local hh = s * (1.1 + (h.far or 0.5) * 0.5)
			local top = base + V3(0, s * 0.15, 0)
			Kit.roofCone(m, "Peak", top, s * 0.78, hh, C.rockDark, M.Rock, 9, FAR_PART)
			Kit.roofCone(
				m,
				"Peak2",
				top + V3(s * 0.45, -s * 0.02, s * 0.2),
				s * 0.5,
				hh * 0.58,
				C.rock,
				M.Rock,
				7,
				FAR_PART
			)
			if hh > 50 then
				snowCap(m, top, s * 0.78, hh, 9, 0.62)
			end
			for _ = 1, 7 + math.floor(s / 14) do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(0.55, 0.88) * s * 0.78
				local y = top.Y + hh * (1 - r / (s * 0.78))
				farPine(
					m,
					V3(base.X + math.cos(a) * r, y - 0.6, base.Z + math.sin(a) * r),
					s * rng:NextNumber(0.22, 0.32),
					rng
				)
			end
		end
		-- leafy trees all over the hills, palms leaning out over the sand
		for _ = 1, (kind == "peak" and 8 or 13) + math.floor(s / 8) do
			local at = spotOn(0.05, 0.75)
			if at and at.Y > base.Y + s * 0.2 then
				farTree(m, at, s * rng:NextNumber(0.28, 0.42), rng, C.leaf:Lerp(C.pineDark, rng:NextNumber(0, 0.45)))
			end
		end
		for _ = 1, 6 + math.floor(s / 14) do
			local at = spotOn(0.78, 0.98)
			if at then
				farPalm(m, at, s * rng:NextNumber(0.3, 0.42), rng)
			end
		end
		-- boulders on the beach and up the hills
		for _ = 1, 5 do
			local at = spotOn(0.6, 1)
			if at then
				Kit.boulder(m, at, s * rng:NextNumber(0.1, 0.2), rng, C.rock, M.Rock)
			end
		end
	end
	-- scenery only: nothing casts a shadow, collides or can be clicked (and no boulder colliders)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "BoulderCollider" then
				d:Destroy()
			else
				d.CastShadow = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Anchored = true
			end
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

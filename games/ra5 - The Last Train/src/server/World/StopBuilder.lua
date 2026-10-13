-- The stops of the Overgrown Line (Data/Stops), built once as templates; ExpeditionService puts a fresh copy beside
-- the train when it arrives. Every stop has the same frame (ground, track, an old platform along the whole train
-- with ramps down, a wall of forest all round) and its own content: a landmark you can see from the train, clusters
-- of piles to collect (common ones close to the platform, rare ones farther out) and one blueprint at the landmark.
--
-- Piles are Models with attributes Node = "wood" | "scrap" | "parts" | "cloth" | "fuel" | "blueprint" and Amount;
-- ResourceService gives them their prompts. Fuel cans are spread out; ResourceService keeps as many as the crew
-- needs and removes the rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)

local StopBuilder = {}

local C, M = Kit.C, Kit.M
local box, wedge, cyl, disc = Kit.box, Kit.wedge, Kit.cyl, Kit.disc
local FLOOR = Layout.FLOOR_Y
local PZ0, PZ1 = Layout.PLATFORM_Z0, Layout.PLATFORM_Z1
local SITE_X = 280 -- the site runs from -SITE_X to +SITE_X
local SITE_Z = 236 -- and from the platform out to here

-- Piles ------------------------------------------------------------------------------------------------------------
local NODE_LOOK = {}

function NODE_LOOK.wood(m, cf)
	Kit.logs(m, cf * CFrame.new(0, 0, 0), 4.5, 2)
	disc(m, "Stump", (cf * CFrame.new(3.4, 0.6, 1.2)).Position, 1.8, 1.2, C.bark, M.Wood)
	box(
		m,
		"Axe",
		cf * CFrame.new(3.4, 1.6, 1.2) * CFrame.Angles(0, 0, math.rad(20)),
		Vector3.new(0.2, 1.6, 0.2),
		C.woodLight,
		M.Wood,
		{ CastShadow = false, CanCollide = false }
	)
	return box(
		m,
		"Root",
		cf * CFrame.new(0, 1.2, 0),
		Vector3.new(4.6, 2.4, 3.6),
		C.bark,
		M.Wood,
		{ Transparency = 1, CanCollide = false }
	)
end

function NODE_LOOK.scrap(m, cf)
	box(
		m,
		"Sheet",
		cf * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(25), math.rad(15), 0),
		Vector3.new(3.6, 0.25, 2.8),
		C.rust,
		M.CorrodedMetal
	)
	cyl(
		m,
		"Pipe",
		cf * CFrame.new(-0.6, 0.5, 1) * CFrame.Angles(0, math.rad(35), 0),
		3.4,
		0.7,
		C.steel,
		M.CorrodedMetal
	)
	cyl(
		m,
		"Wheel",
		cf * CFrame.new(1.4, 0.9, -0.6) * CFrame.Angles(0, 0, math.rad(70)),
		0.4,
		1.8,
		C.rustDark,
		M.CorrodedMetal
	)
	box(m, "Can", cf * CFrame.new(-1.3, 0.5, -0.9), Vector3.new(1, 1, 1), C.rustDark, M.CorrodedMetal)
	return box(
		m,
		"Root",
		cf * CFrame.new(0, 1, 0),
		Vector3.new(4, 2, 3.4),
		C.rust,
		M.CorrodedMetal,
		{ Transparency = 1, CanCollide = false }
	)
end

function NODE_LOOK.parts(m, cf)
	box(m, "PartsCrate", cf * CFrame.new(0, 1, 0), Vector3.new(2.8, 2, 2.2), Kit.rgb(70, 96, 120), M.Metal)
	box(
		m,
		"CrateStripe",
		cf * CFrame.new(0, 1, -1.12),
		Vector3.new(2.82, 0.4, 0.05),
		Kit.rgb(230, 190, 60),
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	cyl(m, "Gear", cf * CFrame.new(0, 2.15, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.3, 1.6, C.brass, M.Metal)
	box(m, "Toolbox", cf * CFrame.new(1.9, 0.5, 0.6), Vector3.new(1.2, 1, 0.8), C.wheel, M.Metal)
	return box(
		m,
		"Root",
		cf * CFrame.new(0, 1.2, 0),
		Vector3.new(3.6, 2.4, 2.6),
		C.steel,
		M.Metal,
		{ Transparency = 1, CanCollide = false }
	)
end

function NODE_LOOK.cloth(m, cf)
	box(
		m,
		"Sack",
		cf * CFrame.new(-0.7, 0.8, 0) * CFrame.Angles(0, 0, math.rad(8)),
		Vector3.new(1.6, 1.6, 1.4),
		Kit.rgb(206, 184, 136),
		M.Fabric
	)
	box(
		m,
		"Sack",
		cf * CFrame.new(0.9, 0.7, 0.3) * CFrame.Angles(0, math.rad(30), math.rad(-6)),
		Vector3.new(1.5, 1.4, 1.3),
		Kit.rgb(190, 164, 120),
		M.Fabric
	)
	box(m, "Tarp", cf * CFrame.new(0.1, 1.75, 0.1), Vector3.new(2.8, 0.4, 2), Kit.rgb(52, 120, 120), M.Fabric)
	return box(
		m,
		"Root",
		cf * CFrame.new(0, 1, 0),
		Vector3.new(3.4, 2, 2.4),
		C.cream,
		M.Fabric,
		{ Transparency = 1, CanCollide = false }
	)
end

function NODE_LOOK.fuel(m, cf)
	for i, dx in { -0.7, 0.7 } do
		local can = cf * CFrame.new(dx, 1.1, 0) * CFrame.Angles(0, math.rad(i * 10), 0)
		box(m, "Jerrycan", can, Vector3.new(1.1, 2.2, 1.6), C.fuel, M.SmoothPlastic)
		box(
			m,
			"CanStripe",
			can * CFrame.new(0, 0, -0.81),
			Vector3.new(1.12, 0.3, 0.05),
			C.white,
			M.SmoothPlastic,
			{ CastShadow = false }
		)
		box(
			m,
			"CanHandle",
			can * CFrame.new(0, 1.25, 0),
			Vector3.new(0.3, 0.3, 1),
			C.fuel:Lerp(C.black, 0.3),
			M.SmoothPlastic,
			{ CastShadow = false }
		)
	end
	return box(
		m,
		"Root",
		cf * CFrame.new(0, 1.2, 0),
		Vector3.new(2.6, 2.4, 1.8),
		C.fuel,
		M.SmoothPlastic,
		{ Transparency = 1, CanCollide = false }
	)
end

function NODE_LOOK.blueprint(m, cf)
	disc(m, "Pedestal", (cf * CFrame.new(0, 0.9, 0)).Position, 1.8, 1.8, C.woodDark, M.Wood)
	box(
		m,
		"Case",
		cf * CFrame.new(0, 2.3, 0),
		Vector3.new(1.6, 1, 1.6),
		C.glass,
		M.Glass,
		{ Transparency = 0.5, CastShadow = false }
	)
	cyl(m, "Scroll", cf * CFrame.new(0, 2.25, 0), 1.3, 0.5, C.blueprint, M.SmoothPlastic, { CastShadow = false })
	local glow = Kit.ball(
		m,
		"Glow",
		(cf * CFrame.new(0, 3.4, 0)).Position,
		0.5,
		Kit.rgb(140, 190, 255),
		M.Neon,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.light(glow, "PointLight", { Range = 14, Brightness = 2, Color = Kit.rgb(140, 190, 255) })
	return box(
		m,
		"Root",
		cf * CFrame.new(0, 1.6, 0),
		Vector3.new(2, 3.2, 2),
		C.blueprint,
		M.SmoothPlastic,
		{ Transparency = 1, CanCollide = false }
	)
end

local NODE_GLOW = {
	wood = Kit.rgb(255, 196, 120),
	scrap = Kit.rgb(220, 226, 240),
	parts = Kit.rgb(120, 180, 255),
	cloth = Kit.rgb(255, 230, 170),
	fuel = Kit.rgb(255, 90, 70),
}

-- A pile at `cf` on the ground (y of cf = ground height). amount = how many it gives.
local function node(parent, kind, cf, amount, far)
	local m = Kit.model("Node_" .. kind, parent)
	local root = NODE_LOOK[kind](m, cf)
	m.PrimaryPart = root
	m:SetAttribute("Node", kind)
	m:SetAttribute("Amount", amount or 1)
	m:SetAttribute("Far", far == true)
	if NODE_GLOW[kind] then
		-- a soft light so piles read at dusk without a wall of text
		Kit.light(root, "PointLight", { Range = 9, Brightness = 0.9, Color = NODE_GLOW[kind] })
	end
	return m
end
StopBuilder.node = node

-- The frame every stop shares ---------------------------------------------------------------------------------------
local function frame(model, stop, opts)
	local rng = Random.new(opts.seed or 1)
	local groundColor = opts.ground or C.grass
	box(
		model,
		"Ground",
		CFrame.new(0, -1, SITE_Z / 2 - 20),
		Vector3.new(SITE_X * 2 + 160, 2, SITE_Z + 120),
		groundColor,
		M.Grass
	)
	box(
		model,
		"FarGround",
		CFrame.new(0, -1.05, -50),
		Vector3.new(SITE_X * 2 + 160, 2, 80),
		groundColor:Lerp(C.dirt, 0.3),
		M.Ground
	)
	Kit.track(model, CFrame.new(0, 0.1, 0), SITE_X * 2 + 100)
	-- the platform: old concrete with a mossy top, an edge, name boards and ramps down to the ground
	box(
		model,
		"Platform",
		CFrame.new(0, FLOOR / 2, (PZ0 + PZ1) / 2),
		Vector3.new(Layout.LENGTH + 30, FLOOR, PZ1 - PZ0),
		C.concrete,
		M.Concrete
	)
	box(
		model,
		"PlatformEdge",
		CFrame.new(0, FLOOR - 0.15, PZ0 + 0.9),
		Vector3.new(Layout.LENGTH + 30, 0.32, 1.8),
		C.concreteDark,
		M.Concrete
	)
	box(
		model,
		"SafetyLine",
		CFrame.new(0, FLOOR + 0.02, PZ0 + 2.2),
		Vector3.new(Layout.LENGTH + 30, 0.06, 0.5),
		Kit.rgb(200, 170, 70),
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	for _ = 1, 26 do
		local x = rng:NextNumber(-Layout.LENGTH / 2, Layout.LENGTH / 2)
		box(
			model,
			"Moss",
			CFrame.new(x, FLOOR + 0.03, rng:NextNumber(PZ0 + 3, PZ1 - 1)),
			Vector3.new(rng:NextNumber(4, 12), 0.06, rng:NextNumber(2, 5)),
			C.moss,
			M.Grass,
			{ CastShadow = false }
		)
	end
	for _, x in { -200, -110, -20, 70, 160 } do
		wedge(
			model,
			"Ramp",
			CFrame.new(x, FLOOR / 2, PZ1 + 6) * CFrame.Angles(0, math.pi, 0),
			Vector3.new(10, FLOOR, 12),
			C.concrete,
			M.Concrete
		)
	end
	-- name boards on posts along the platform, facing the train
	for _, x in { -170, -60, 50, 160 } do
		local postX = x
		for _, dx in { -5, 5 } do
			box(
				model,
				"BoardPost",
				CFrame.new(postX + dx, FLOOR + 4, PZ1 - 2),
				Vector3.new(0.6, 8, 0.6),
				C.iron,
				M.Metal
			)
		end
		Kit.sign(
			model,
			CFrame.new(postX, FLOOR + 8.4, PZ1 - 2) * CFrame.Angles(0, math.pi, 0),
			13,
			2.4,
			string.upper(stop.name),
			{ ppu = 30 }
		)
	end
	-- old lamps along the platform: most still work
	for i, x in { -220, -150, -80, -10, 60, 130, 200 } do
		local _, bulb = Kit.lampPost(model, Vector3.new(x, FLOOR, PZ1 - 3.5), 11)
		if i == 3 then
			bulb.Color = C.black
			bulb.Material = M.SmoothPlastic
			for _, l in bulb:GetChildren() do
				l:Destroy()
			end
		end
	end
	-- the forest wall round the site, and behind the train
	local trees = Kit.folder("Forest", model)
	local function band(x0, x1, z0, z1, count, scale)
		for _ = 1, count do
			local pos = Vector3.new(rng:NextNumber(x0, x1), 0, rng:NextNumber(z0, z1))
			if rng:NextNumber() < (opts.pineShare or 0.8) then
				Kit.pine(trees, pos, rng:NextNumber(30, 52) * (scale or 1), rng)
			else
				Kit.oak(trees, pos, rng:NextNumber(20, 30) * (scale or 1), rng)
			end
		end
	end
	band(-SITE_X - 40, SITE_X + 40, SITE_Z, SITE_Z + 50, 46, 1.1)
	band(-SITE_X - 60, -SITE_X, 20, SITE_Z, 16)
	band(SITE_X, SITE_X + 60, 20, SITE_Z, 16)
	band(-SITE_X - 40, SITE_X + 40, -70, -30, 40)
	-- a few trees and bushes inside the site, away from the routes
	for _ = 1, opts.innerTrees or 14 do
		local x, z = rng:NextNumber(-SITE_X + 20, SITE_X - 20), rng:NextNumber(60, SITE_Z - 20)
		if not opts.clear or opts.clear(x, z) then
			Kit.pine(trees, Vector3.new(x, 0, z), rng:NextNumber(24, 40), rng)
		end
	end
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-SITE_X + 10, SITE_X - 10), rng:NextNumber(32, SITE_Z - 10)
		if not opts.clear or opts.clear(x, z) then
			if rng:NextNumber() < 0.5 then
				Kit.bush(model, Vector3.new(x, 0, z), nil, rng)
			else
				Kit.fern(model, Vector3.new(x, 0, z), rng)
			end
		end
	end
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-SITE_X + 10, SITE_X - 10), rng:NextNumber(36, SITE_Z - 10)
		if not opts.clear or opts.clear(x, z) then
			Kit.rock(model, Vector3.new(x, 0, z), rng:NextNumber(2, 5), rng)
		end
	end
	-- invisible walls: the forest edge and behind the train
	Kit.wall(model, CFrame.new(0, 30, SITE_Z + 4), Vector3.new(SITE_X * 2 + 40, 60, 2))
	Kit.wall(model, CFrame.new(-SITE_X - 4, 30, SITE_Z / 2 - 20), Vector3.new(2, 60, SITE_Z + 80))
	Kit.wall(model, CFrame.new(SITE_X + 4, 30, SITE_Z / 2 - 20), Vector3.new(2, 60, SITE_Z + 80))
	Kit.wall(model, CFrame.new(0, 30, -34), Vector3.new(SITE_X * 2 + 40, 60, 2))
	return rng
end

-- A dirt path between points (ground decal-like strips).
local function path(model, points, width)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		box(
			model,
			"Path",
			CFrame.lookAt(mid, b) + Vector3.new(0, 0.03, 0),
			Vector3.new(width or 6, 0.06, len + (width or 6)),
			C.dirt,
			M.Ground,
			{ CastShadow = false }
		)
	end
end

-- A wooden stair tower of zigzag ramps up to a deck at `topY` (landmark climbs). Returns the deck's centre.
local function stairTower(model, base, topY, w, legColor)
	local levels = math.ceil(topY / 8)
	local rise = topY / levels
	local legs = {
		Vector3.new(-w / 2, 0, -w / 2),
		Vector3.new(w / 2, 0, -w / 2),
		Vector3.new(-w / 2, 0, w / 2),
		Vector3.new(w / 2, 0, w / 2),
	}
	for _, l in legs do
		box(
			model,
			"TowerLeg",
			CFrame.new(base + l + Vector3.new(0, topY / 2, 0)),
			Vector3.new(1.2, topY, 1.2),
			legColor or C.woodDark,
			M.Wood
		)
	end
	for i = 1, levels do
		local y = i * rise
		-- landing
		box(
			model,
			"Landing",
			CFrame.new(base + Vector3.new(0, y - 0.25, (i % 2 == 0) and -w / 4 or w / 4)),
			Vector3.new(w, 0.5, w / 2),
			C.woodLight,
			M.WoodPlanks
		)
		-- ramp from the landing below
		local y0 = y - rise
		local zA = (i % 2 == 0) and w / 4 or -w / 4
		local zB = -zA
		local a = base + Vector3.new(-w / 4 * (i % 2 == 0 and -1 or 1), y0, zA)
		local b = base + Vector3.new(w / 4 * (i % 2 == 0 and -1 or 1), y, zB)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		box(
			model,
			"Stair",
			CFrame.lookAt(mid, b) * CFrame.new(0, -0.25, 0),
			Vector3.new(w / 2 - 0.6, 0.5, len + 0.8),
			C.woodLight,
			M.WoodPlanks
		)
		-- cross braces
		box(
			model,
			"Brace",
			CFrame.new(base + Vector3.new(0, y - rise / 2, -w / 2)) * CFrame.Angles(0, 0, math.atan2(rise, w)),
			Vector3.new(math.sqrt(w * w + rise * rise), 0.5, 0.5),
			legColor or C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	return base + Vector3.new(0, topY, 0)
end

-- Ranger Station ----------------------------------------------------------------------------------------------------
local function ranger(model)
	local clearZones = {
		{ -70, -10, 60, 104 }, -- the station building
		{ 70, 110, 150, 194 }, -- the lookout
		{ -170, -110, 40, 80 },
		{ 120, 180, 50, 90 },
	}
	local function clear(x, z)
		for _, r in clearZones do
			if x > r[1] - 6 and x < r[2] + 6 and z > r[3] - 6 and z < r[4] + 6 then
				return false
			end
		end
		return math.abs(x + 40) > 12 or z > 60 -- keep the main path clear
	end
	local rng = frame(model, { name = "Ranger Station" }, { seed = 11, clear = clear })
	path(
		model,
		{ Vector3.new(-40, 0, 30), Vector3.new(-40, 0, 58), Vector3.new(20, 0, 110), Vector3.new(90, 0, 150) },
		7
	)
	path(model, { Vector3.new(-40, 0, 58), Vector3.new(-140, 0, 62) }, 5)
	path(model, { Vector3.new(20, 0, 110), Vector3.new(150, 0, 70) }, 5)
	-- the ranger station: a two-storey log building with a porch and lit windows
	local hx, hz = -40, 82
	local house = Kit.model("RangerStation", model)
	box(house, "Foundation", CFrame.new(hx, 0.6, hz), Vector3.new(30, 1.2, 22), C.concreteDark, M.Cobblestone)
	-- walls with a door gap on the front (-Z)
	box(house, "WallBack", CFrame.new(hx, 9, hz + 10.5), Vector3.new(30, 16, 1), C.wood, M.Wood)
	box(house, "WallSide", CFrame.new(hx - 14.5, 9, hz), Vector3.new(1, 16, 22), C.wood, M.Wood)
	box(house, "WallSide", CFrame.new(hx + 14.5, 9, hz), Vector3.new(1, 16, 22), C.wood, M.Wood)
	box(house, "WallFront", CFrame.new(hx - 9, 9, hz - 10.5), Vector3.new(12, 16, 1), C.wood, M.Wood)
	box(house, "WallFront", CFrame.new(hx + 9, 9, hz - 10.5), Vector3.new(12, 16, 1), C.wood, M.Wood)
	box(house, "WallFront", CFrame.new(hx, 14, hz - 10.5), Vector3.new(6, 6, 1), C.wood, M.Wood)
	for i = 0, 6 do
		box(
			house,
			"Log",
			CFrame.new(hx, 1.8 + i * 2.2, hz - 11.05),
			Vector3.new(30.4, 0.5, 0.3),
			C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	box(house, "Floor", CFrame.new(hx, 1.3, hz), Vector3.new(28, 0.2, 20), C.woodLight, M.WoodPlanks)
	box(house, "UpperFloor", CFrame.new(hx, 9, hz + 4), Vector3.new(28, 0.4, 12), C.woodLight, M.WoodPlanks)
	-- roof: two big wedges
	wedge(house, "Roof", CFrame.new(hx, 20.5, hz - 5.75), Vector3.new(34, 7, 12.5), C.roof:Lerp(C.rust, 0.25), M.Slate)
	wedge(
		house,
		"Roof",
		CFrame.new(hx, 20.5, hz + 5.75) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(34, 7, 12.5),
		C.roof:Lerp(C.rust, 0.25),
		M.Slate
	)
	disc(house, "Chimney", Vector3.new(hx + 9, 22, hz + 5), 2.4, 8, C.concreteDark, M.Brick)
	-- porch
	box(house, "Porch", CFrame.new(hx, 1.1, hz - 15), Vector3.new(30, 0.4, 8), C.woodLight, M.WoodPlanks)
	box(
		house,
		"PorchRoof",
		CFrame.new(hx, 10, hz - 15) * CFrame.Angles(math.rad(-12), 0, 0),
		Vector3.new(31, 0.5, 9),
		C.roof,
		M.Slate
	)
	for _, dx in { -14, -5, 5, 14 } do
		box(house, "PorchPost", CFrame.new(hx + dx, 5.6, hz - 18.6), Vector3.new(0.8, 9, 0.8), C.woodDark, M.Wood)
	end
	-- warm windows
	for _, dx in { -9, 9 } do
		for _, y in { 6, 14 } do
			local w = box(
				house,
				"LitWindow",
				CFrame.new(hx + dx, y, hz - 11.1),
				Vector3.new(4, 3, 0.2),
				Kit.rgb(255, 196, 110),
				M.Neon,
				{ CastShadow = false }
			)
			if y == 6 then
				Kit.light(w, "PointLight", { Range = 16, Brightness = 1.4, Color = C.warm })
			end
		end
	end
	Kit.sign(
		house,
		CFrame.new(hx, 11.2, hz - 19.4) * CFrame.Angles(0, math.pi, 0),
		14,
		2,
		"RANGER STATION",
		{ ppu = 30 }
	)
	-- inside: the map room table and shelves (parts and cloth live here)
	box(house, "MapTable", CFrame.new(hx - 6, 3.4, hz + 2), Vector3.new(6, 0.4, 4), C.woodDark, M.Wood)
	box(
		house,
		"OldMap",
		CFrame.new(hx - 6, 3.65, hz + 2),
		Vector3.new(5, 0.06, 3.2),
		Kit.rgb(214, 196, 150),
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	local lamp = Kit.bulb(house, "HouseLamp", Vector3.new(hx, 8.2, hz), 0.7, C.warm, 22, 1.4)
	_ = lamp
	-- the fire lookout: a tall stair tower with a cabin on top (the blueprint)
	local lx, lz = 90, 172
	local look = Kit.model("FireLookout", model)
	local top = stairTower(look, Vector3.new(lx, 0, lz), 40, 14)
	box(look, "Deck", CFrame.new(top + Vector3.new(0, -0.2, 0)), Vector3.new(18, 0.6, 18), C.woodLight, M.WoodPlanks)
	for _, s in { { 0, 8.7, 18, 0.5 }, { 0, -8.7, 18, 0.5 } } do
		box(
			look,
			"Rail",
			CFrame.new(top + Vector3.new(s[1], 1.6, s[2])),
			Vector3.new(s[3], 0.4, s[4]),
			C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	box(look, "CabinRoof", CFrame.new(top + Vector3.new(0, 8.6, 0)), Vector3.new(16, 0.6, 16), C.roof, M.Slate)
	for _, p in { { -7.5, -7.5 }, { 7.5, -7.5 }, { -7.5, 7.5 }, { 7.5, 7.5 } } do
		box(
			look,
			"CabinPost",
			CFrame.new(top + Vector3.new(p[1], 4.3, p[2])),
			Vector3.new(0.6, 8.6, 0.6),
			C.woodDark,
			M.Wood
		)
	end
	Kit.cone(look, "LookoutRoof", top + Vector3.new(0, 8.9, 0), 18, 5, C.roof, 3, M.Slate)
	local beacon =
		Kit.ball(look, "LookoutLamp", top + Vector3.new(0, 6.5, 0), 1, C.warm, M.Neon, { CastShadow = false })
	Kit.light(beacon, "PointLight", { Range = 26, Brightness = 2, Color = C.warm })
	node(model, "blueprint", CFrame.new(top + Vector3.new(3, 0.1, 3)), 1, true)
	-- storage sheds (cloth and wood)
	for _, s in { { -140, 60, 0 }, { 150, 70, math.pi } } do
		local sx, sz, rot = s[1], s[2], s[3]
		local shed = Kit.model("Shed", model)
		local cf = CFrame.new(sx, 0, sz) * CFrame.Angles(0, rot, 0)
		box(shed, "ShedBack", cf * CFrame.new(0, 5, 7), Vector3.new(22, 10, 0.8), C.woodDark, M.WoodPlanks)
		box(shed, "ShedSide", cf * CFrame.new(-10.6, 5, 0), Vector3.new(0.8, 10, 14), C.woodDark, M.WoodPlanks)
		box(shed, "ShedSide", cf * CFrame.new(10.6, 5, 0), Vector3.new(0.8, 10, 14), C.woodDark, M.WoodPlanks)
		box(
			shed,
			"ShedRoof",
			cf * CFrame.new(0, 10.6, 0) * CFrame.Angles(math.rad(-8), 0, 0),
			Vector3.new(23, 0.6, 16),
			C.rust,
			M.CorrodedMetal
		)
		box(shed, "ShedFloor", cf * CFrame.new(0, 0.15, 0), Vector3.new(21, 0.3, 14), C.dirt, M.Ground)
		node(model, "cloth", cf * CFrame.new(-6, 0.3, 3), 2)
		node(model, "cloth", cf * CFrame.new(0, 0.3, 3.5), 1)
		node(model, "wood", cf * CFrame.new(6, 0.3, 2), 2)
	end
	-- an old truck with fuel near it
	local truck = Kit.model("Truck", model)
	local tcf = CFrame.new(-110, 0, 130) * CFrame.Angles(0, math.rad(25), 0)
	box(truck, "TruckBed", tcf * CFrame.new(-3, 3, 0), Vector3.new(10, 1, 7), C.rust, M.CorrodedMetal)
	box(truck, "TruckCab", tcf * CFrame.new(5, 4.5, 0), Vector3.new(5, 5, 6.6), Kit.rgb(70, 96, 78), M.CorrodedMetal)
	box(truck, "TruckHood", tcf * CFrame.new(9, 3.2, 0), Vector3.new(3.4, 2.6, 6), Kit.rgb(70, 96, 78), M.CorrodedMetal)
	for _, wx in { -5, 7 } do
		for _, wz in { -3.4, 3.4 } do
			cyl(
				truck,
				"Tyre",
				tcf * CFrame.new(wx, 1.4, wz) * CFrame.Angles(0, math.rad(90), 0),
				1,
				2.8,
				C.black,
				M.Rubber
			)
		end
	end
	node(model, "scrap", tcf * CFrame.new(-3, 0, -7), 2)
	-- fire pit with logs
	disc(model, "FirePit", Vector3.new(10, 0.4, 60), 6, 0.8, C.concreteDark, M.Cobblestone)
	local embers =
		Kit.ball(model, "Embers", Vector3.new(10, 0.8, 60), 2, Kit.rgb(255, 120, 40), M.Neon, { CastShadow = false })
	Kit.light(embers, "PointLight", { Range = 16, Brightness = 1.6, Color = Kit.rgb(255, 130, 60) })
	-- fences along the paths
	Kit.fence(model, Vector3.new(-70, 0, 40), Vector3.new(-70, 0, 120))
	Kit.fence(model, Vector3.new(40, 0, 130), Vector3.new(120, 0, 130))
	-- piles: common near the platform, rare farther out
	local spots = {
		{ "wood", -70, 36, 1 },
		{ "wood", 30, 40, 1 },
		{ "wood", 120, 38, 1 },
		{ "wood", -200, 48, 2 },
		{ "scrap", -10, 46, 1 },
		{ "scrap", 200, 56, 1 },
		{ "scrap", 60, 100, 2 },
		{ "cloth", -100, 40, 1 },
		{ "cloth", 80, 52, 1 },
		{ "parts", 200, 150, 2, true },
		{ "parts", -210, 180, 2, true },
	}
	node(model, "parts", CFrame.new(hx - 8, 1.4, hz + 4), 1, true) -- in the map room
	for _, s in spots do
		node(model, s[1], CFrame.new(s[2], 0, s[3]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s[4], s[5])
	end
	return {
		fuel = {
			{ -60, 32 },
			{ 0, 34 },
			{ 60, 36 },
			{ -150, 90 },
			{ 110, 110 },
			{ -110, 122 },
			{ 170, 120 },
			{ -20, 150 },
			{ 230, 90 },
		},
	}
end

-- Timber Yard ------------------------------------------------------------------------------------------------------
local function timber(model)
	local function clear(x, z)
		if z > 44 and z < 118 and math.abs(x) < 170 then
			return false -- the lumber rows
		end
		if x > -130 and x < -50 and z > 120 and z < 180 then
			return false -- the sawmill
		end
		if x > 40 and x < 160 and z > 116 and z < 206 then
			return false -- the crane
		end
		return true
	end
	local rng = frame(
		model,
		{ name = "Timber Yard" },
		{ seed = 23, clear = clear, ground = C.grass:Lerp(C.dirt, 0.45), innerTrees = 8 }
	)
	box(
		model,
		"YardDirt",
		CFrame.new(0, 0.02, 120),
		Vector3.new(360, 0.06, 170),
		C.dirt,
		M.Ground,
		{ CastShadow = false }
	)
	-- lumber rows: stacks with lanes between them
	for row = 0, 2 do
		for i = -3, 3 do
			local x, z = i * 46, 56 + row * 26
			local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0)
			local stack = Kit.model("LumberStack", model)
			for layer = 0, rng:NextInteger(2, 4) do
				box(
					stack,
					"Planks",
					cf * CFrame.new(0, 0.9 + layer * 1.7, 0),
					Vector3.new(22, 1.5, 8),
					C.woodLight:Lerp(C.wood, rng:NextNumber(0, 0.4)),
					M.WoodPlanks
				)
				box(
					stack,
					"Spacer",
					cf * CFrame.new(0, 1.7 + layer * 1.7, 0),
					Vector3.new(0.6, 0.2, 8.4),
					C.woodDark,
					M.Wood,
					{ CastShadow = false }
				)
			end
			if (i + row) % 2 == 0 then
				node(model, "wood", cf * CFrame.new(0, 0, -6.5), 2)
			end
		end
	end
	-- the sawmill: an open shed with a huge blade and a conveyor
	local mx, mz = -90, 150
	local mill = Kit.model("Sawmill", model)
	for _, dx in { -18, 18 } do
		for _, dz in { -12, 12 } do
			box(mill, "MillPost", CFrame.new(mx + dx, 8, mz + dz), Vector3.new(1.2, 16, 1.2), C.woodDark, M.Wood)
		end
	end
	box(
		mill,
		"MillRoof",
		CFrame.new(mx, 16.4, mz) * CFrame.Angles(0, 0, math.rad(6)),
		Vector3.new(40, 0.6, 28),
		C.rust,
		M.CorrodedMetal
	)
	box(mill, "MillFloor", CFrame.new(mx, 0.3, mz), Vector3.new(38, 0.6, 26), C.concreteDark, M.Concrete)
	box(mill, "SawTable", CFrame.new(mx, 3, mz), Vector3.new(22, 1, 5), C.iron, M.Metal)
	cyl(mill, "SawBlade", CFrame.new(mx, 6, mz) * CFrame.Angles(0, math.rad(90), 0), 0.3, 8, C.steel, M.Metal)
	box(mill, "Conveyor", CFrame.new(mx + 16, 2.2, mz), Vector3.new(14, 0.6, 4), C.black, M.Rubber)
	Kit.logs(mill, CFrame.new(mx + 16, 2.6, mz), 10, 1)
	node(model, "scrap", CFrame.new(mx - 12, 0.6, mz + 8), 2)
	node(model, "parts", CFrame.new(mx + 6, 0.6, mz + 9), 1, true)
	node(model, "scrap", CFrame.new(mx + 12, 0.6, mz - 9), 1)
	local millLamp = Kit.bulb(mill, "MillLamp", Vector3.new(mx, 15, mz), 0.8, C.warm, 26, 1.4)
	_ = millLamp
	-- the gantry crane (the landmark): two A-frame legs, a beam, a hanging log, a cab on top (the blueprint)
	local cx, cz = 100, 160
	local crane = Kit.model("GantryCrane", model)
	local H = 34
	for _, dx in { -40, 40 } do
		for _, dz in { -12, 12 } do
			box(
				crane,
				"CraneLeg",
				CFrame.new(cx + dx, H / 2, cz + dz),
				Vector3.new(2, H, 2),
				Kit.rgb(214, 160, 40),
				M.Metal
			)
		end
		box(
			crane,
			"CraneTie",
			CFrame.new(cx + dx, H * 0.4, cz),
			Vector3.new(1.4, 1.4, 24),
			Kit.rgb(214, 160, 40),
			M.Metal,
			{ CastShadow = false }
		)
	end
	for _, dz in { -12, 12 } do
		box(crane, "CraneBeam", CFrame.new(cx, H + 1, cz + dz), Vector3.new(84, 2.4, 2), Kit.rgb(214, 160, 40), M.Metal)
	end
	box(crane, "Trolley", CFrame.new(cx + 10, H + 2.6, cz), Vector3.new(6, 2, 26), C.iron, M.Metal)
	for _, dz in { -1.5, 1.5 } do
		box(
			crane,
			"Cable",
			CFrame.new(cx + 10, H - 7, cz + dz),
			Vector3.new(0.2, 16, 0.2),
			C.black,
			M.Metal,
			{ CastShadow = false, CanCollide = false }
		)
	end
	Kit.logs(crane, CFrame.new(cx + 10, H - 17, cz), 16, 1)
	-- a ladder up the near leg and a walkway to the cab
	local ladderX, ladderZ = cx - 40, cz - 13.4
	for i = 0, math.floor(H / 1.6) do
		box(
			crane,
			"Rung",
			CFrame.new(ladderX, 1 + i * 1.6, ladderZ),
			Vector3.new(2.6, 0.25, 0.25),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	for _, dx in { -1.3, 1.3 } do
		box(
			crane,
			"LadderRail",
			CFrame.new(ladderX + dx, H / 2, ladderZ),
			Vector3.new(0.25, H + 2, 0.25),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	local truss = Instance.new("TrussPart")
	truss.Name = "LadderTruss"
	truss.Anchored = true
	truss.Size = Vector3.new(2, H + 2, 2)
	truss.CFrame = CFrame.new(ladderX, H / 2 + 1, ladderZ - 0.8)
	truss.Transparency = 1
	truss.Parent = crane
	box(crane, "Walkway", CFrame.new(cx - 26, H + 2.6, cz - 12), Vector3.new(30, 0.4, 3), C.steel, M.DiamondPlate)
	box(crane, "CabFloor", CFrame.new(cx - 10, H + 2.6, cz - 12), Vector3.new(8, 0.4, 6), C.steel, M.DiamondPlate)
	box(crane, "Cab", CFrame.new(cx - 10, H + 5.6, cz - 9.5), Vector3.new(8, 6, 0.5), Kit.rgb(214, 160, 40), M.Metal)
	box(
		crane,
		"CabRoof",
		CFrame.new(cx - 10, H + 8.8, cz - 12),
		Vector3.new(8.6, 0.5, 6.6),
		Kit.rgb(214, 160, 40),
		M.Metal
	)
	local warn = Kit.ball(
		crane,
		"CraneLamp",
		Vector3.new(cx - 10, H + 9.4, cz - 12),
		0.8,
		C.signal,
		M.Neon,
		{ CastShadow = false }
	)
	warn:SetAttribute("Blink", true)
	node(model, "blueprint", CFrame.new(cx - 10, H + 2.8, cz - 13), 1, true)
	-- a broken forklift and scrap
	local fork = Kit.model("Forklift", model)
	box(fork, "ForkBody", CFrame.new(170, 2.5, 60), Vector3.new(6, 4, 4), Kit.rgb(210, 150, 40), M.CorrodedMetal)
	box(fork, "ForkMast", CFrame.new(167, 5, 60), Vector3.new(0.6, 8, 3.4), C.iron, M.Metal)
	node(model, "scrap", CFrame.new(176, 0, 52), 1)
	-- the rest of the piles
	local spots = {
		{ "scrap", -180, 40, 1 },
		{ "scrap", 40, 34, 1 },
		{ "scrap", -40, 130, 2 },
		{ "cloth", -150, 120, 1 },
		{ "cloth", 220, 170, 2, true },
		{ "parts", 200, 200, 2, true },
		{ "parts", -220, 200, 1, true },
		{ "wood", 230, 48, 1 },
		{ "wood", -230, 60, 1 },
	}
	for _, s in spots do
		node(model, s[1], CFrame.new(s[2], 0, s[3]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s[4], s[5])
	end
	return {
		fuel = {
			{ -120, 34 },
			{ -10, 36 },
			{ 90, 34 },
			{ 200, 40 },
			{ -200, 110 },
			{ 30, 140 },
			{ 180, 120 },
			{ -40, 190 },
			{ 240, 210 },
		},
	}
end

-- Signal Tower -----------------------------------------------------------------------------------------------------
local function signal(model)
	local function clear(x, z)
		if math.abs(x) < 24 and z > 126 and z < 176 then
			return false
		end
		if z > 60 and z < 110 and math.abs(x - 120) < 40 then
			return false
		end
		return true
	end
	local rng = frame(model, { name = "Signal Tower" }, { seed = 37, clear = clear, ground = C.grassDark })
	path(model, { Vector3.new(0, 0, 30), Vector3.new(0, 0, 130) }, 6)
	path(model, { Vector3.new(0, 0, 80), Vector3.new(-120, 0, 90), Vector3.new(-180, 0, 160) }, 5)
	path(model, { Vector3.new(0, 0, 80), Vector3.new(120, 0, 86) }, 5)
	-- the signal tower: a tall lattice tower with stairs to a platform halfway and a ladder to the top
	local tx, tz = 0, 150
	local tower = Kit.model("SignalTower", model)
	local H = 60
	local W = 14
	for _, p in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local bottom = Vector3.new(tx + p[1] * W / 2, 0, tz + p[2] * W / 2)
		local top = Vector3.new(tx + p[1] * 3, H, tz + p[2] * 3)
		local mid = (bottom + top) / 2
		box(
			tower,
			"TowerLeg",
			CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0),
			Vector3.new(1.2, (top - bottom).Magnitude, 1.2),
			C.white,
			M.Metal
		)
	end
	for i = 1, 7 do
		local y = i * (H / 8)
		local w = W - (W - 6) * (y / H)
		for _, side in { { 0, -1, 0 }, { 0, 1, 0 }, { -1, 0, 1 }, { 1, 0, 1 } } do
			local pos = Vector3.new(tx + side[1] * w / 2, y, tz + side[2] * w / 2)
			box(
				tower,
				"TowerRing",
				CFrame.new(pos) * CFrame.Angles(0, side[3] == 1 and math.pi / 2 or 0, 0),
				Vector3.new(w, 0.5, 0.5),
				i % 2 == 0 and C.red or C.white,
				M.Metal,
				{ CastShadow = false }
			)
		end
	end
	-- a stair tower beside it up to the halfway platform, then a ladder (truss) to the top
	local stair = stairTower(tower, Vector3.new(tx - 16, 0, tz), 30, 10, C.iron)
	box(tower, "HalfDeck", CFrame.new(tx - 6, 30 - 0.2, tz), Vector3.new(22, 0.6, 12), C.steel, M.DiamondPlate)
	_ = stair
	local ladder = Instance.new("TrussPart")
	ladder.Name = "TowerLadder"
	ladder.Anchored = true
	ladder.Size = Vector3.new(2, 31, 2)
	ladder.CFrame = CFrame.new(tx - 2.5, 45.5, tz - 5.6) -- beside the top deck, so you step off onto it
	ladder.Color = C.steel
	ladder.Parent = tower
	box(tower, "TopDeck", CFrame.new(tx, H - 0.2, tz), Vector3.new(10, 0.6, 10), C.steel, M.DiamondPlate)
	for _, s in { { 0, 4.8, 10, 0.3 }, { -4.8, 0, 0.3, 10 }, { 4.8, 0, 0.3, 10 } } do
		box(
			tower,
			"TopRail",
			CFrame.new(tx + s[1], H + 1.6, tz + s[2]),
			Vector3.new(s[3], 0.3, s[4]),
			C.white,
			M.Metal,
			{ CastShadow = false }
		)
	end
	local light =
		Kit.ball(tower, "SignalLight", Vector3.new(tx, H + 6, tz), 2.2, C.signal, M.Neon, { CastShadow = false })
	Kit.light(light, "PointLight", { Range = 40, Brightness = 3, Color = C.signal })
	light:SetAttribute("Blink", true)
	box(tower, "LightMast", CFrame.new(tx, H + 2.8, tz), Vector3.new(0.6, 5.4, 0.6), C.white, M.Metal)
	node(model, "blueprint", CFrame.new(tx + 2, H + 0.1, tz + 2), 1, true)
	-- relay huts (parts) humming with green lights
	for i, p in { { 110, 76 }, { 134, 98 }, { -120, 92 } } do
		local hut = Kit.model("RelayHut", model)
		local cf = CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		box(hut, "Hut", cf * CFrame.new(0, 4, 0), Vector3.new(10, 8, 8), C.concrete, M.Concrete)
		box(hut, "HutRoof", cf * CFrame.new(0, 8.3, 0), Vector3.new(11, 0.6, 9), C.concreteDark, M.Concrete)
		box(hut, "HutDoor", cf * CFrame.new(0, 3.2, -4.05), Vector3.new(3, 6.4, 0.2), C.iron, M.Metal)
		local g = box(
			hut,
			"HutLight",
			cf * CFrame.new(3, 6, -4.1),
			Vector3.new(1, 0.6, 0.2),
			Kit.rgb(120, 255, 160),
			M.Neon,
			{ CastShadow = false }
		)
		Kit.light(g, "PointLight", { Range = 12, Brightness = 1.2, Color = Kit.rgb(120, 255, 160) })
		node(model, "parts", cf * CFrame.new(0, 0, -7), i == 3 and 2 or 1, i == 3)
	end
	-- cable spools and a semaphore gantry over the track
	for i, p in { { -40, 50 }, { -60, 60 }, { 50, 46 }, { 70, 120 } } do
		local cf = CFrame.new(p[1], 3, p[2]) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		cyl(model, "Spool", cf, 3, 6, C.woodLight, M.Wood)
		cyl(model, "SpoolCore", cf, 3.2, 3.4, C.black, M.Rubber, { CastShadow = false })
		if i <= 2 then
			node(model, "scrap", CFrame.new(p[1] + 5, 0, p[2]), 1)
		end
	end
	local gantry = Kit.model("SignalGantry", model)
	for _, z in { -18, 30 } do
		box(gantry, "GantryPost", CFrame.new(-120, 13, z), Vector3.new(1.4, 26, 1.4), C.iron, M.Metal)
	end
	box(gantry, "GantryBeam", CFrame.new(-120, 25.6, 6), Vector3.new(1.6, 1.6, 50), C.iron, M.Metal)
	for _, z in { -6, 10 } do
		box(
			gantry,
			"Semaphore",
			CFrame.new(-120, 22, z) * CFrame.Angles(math.rad(30), 0, 0),
			Vector3.new(0.4, 1.4, 7),
			C.red,
			M.SmoothPlastic
		)
		local lamp = Kit.ball(
			gantry,
			"SemaphoreLamp",
			Vector3.new(-119.4, 23.6, z - 2),
			0.8,
			Kit.rgb(120, 255, 140),
			M.Neon,
			{ CastShadow = false }
		)
		_ = lamp
	end
	-- a little ravine with a footbridge to the west (a second way round)
	box(model, "Ravine", CFrame.new(-190, -2.5, 140), Vector3.new(16, 5, 120), C.dirt:Lerp(C.black, 0.3), M.Ground)
	box(model, "Footbridge", CFrame.new(-190, 0.4, 160), Vector3.new(20, 0.5, 6), C.woodLight, M.WoodPlanks)
	for _, dz in { -3, 3 } do
		box(
			model,
			"BridgeRail",
			CFrame.new(-190, 2, 160 + dz),
			Vector3.new(20, 0.3, 0.3),
			C.woodDark,
			M.Wood,
			{ CastShadow = false }
		)
	end
	local spots = {
		{ "scrap", 30, 40, 1 },
		{ "scrap", -150, 44, 1 },
		{ "scrap", 200, 60, 2 },
		{ "scrap", -230, 120, 1 },
		{ "wood", -90, 40, 1 },
		{ "wood", 160, 40, 1 },
		{ "wood", -200, 200, 2, true },
		{ "cloth", 90, 40, 1 },
		{ "cloth", -60, 110, 1 },
		{ "cloth", 200, 190, 2, true },
		{ "parts", 220, 130, 2, true },
		{ "parts", -40, 200, 2, true },
	}
	for _, s in spots do
		node(model, s[1], CFrame.new(s[2], 0, s[3]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s[4], s[5])
	end
	return {
		fuel = {
			{ -100, 30 },
			{ 0, 36 },
			{ 100, 32 },
			{ -160, 80 },
			{ 60, 80 },
			{ 170, 100 },
			{ -70, 150 },
			{ 100, 170 },
			{ -230, 60 },
		},
	}
end

-- Overgrown Platform -------------------------------------------------------------------------------------------------
local function overgrown(model)
	local function clear(x, z)
		if math.abs(x + 20) < 46 and z > 50 and z < 104 then
			return false
		end
		return true
	end
	local rng = frame(
		model,
		{ name = "Overgrown Platform" },
		{ seed = 51, clear = clear, ground = C.moss, innerTrees = 22, pineShare = 0.5 }
	)
	-- vines over the platform edge
	for _ = 1, 30 do
		local x = rng:NextNumber(-Layout.LENGTH / 2, Layout.LENGTH / 2)
		box(
			model,
			"Vine",
			CFrame.new(x, FLOOR - 1.2, PZ1 + 0.2),
			Vector3.new(rng:NextNumber(2, 6), 2.6, 0.3),
			C.moss:Lerp(C.leaf, rng:NextNumber()),
			M.Grass,
			{ CastShadow = false, CanCollide = false }
		)
	end
	-- the old waiting room: broken walls, a caved-in roof, a tree growing through it (the blueprint is inside)
	local wx, wz = -20, 76
	local room = Kit.model("WaitingRoom", model)
	box(room, "RoomFloor", CFrame.new(wx, 0.5, wz), Vector3.new(44, 1, 26), C.concrete, M.Concrete)
	box(room, "RoomWall", CFrame.new(wx, 7, wz + 12.5), Vector3.new(44, 14, 1), C.concrete:Lerp(C.moss, 0.2), M.Brick)
	box(room, "RoomWall", CFrame.new(wx - 21.5, 6, wz), Vector3.new(1, 12, 26), C.concrete:Lerp(C.moss, 0.2), M.Brick)
	box(
		room,
		"RoomWall",
		CFrame.new(wx + 21.5, 4, wz + 4),
		Vector3.new(1, 8, 18),
		C.concrete:Lerp(C.moss, 0.3),
		M.Brick
	)
	box(
		room,
		"RoomFront",
		CFrame.new(wx - 13, 7, wz - 12.5),
		Vector3.new(18, 14, 1),
		C.concrete:Lerp(C.moss, 0.2),
		M.Brick
	)
	box(
		room,
		"RoomFront",
		CFrame.new(wx + 15, 5, wz - 12.5),
		Vector3.new(14, 10, 1),
		C.concrete:Lerp(C.moss, 0.2),
		M.Brick
	)
	box(
		room,
		"RoofLeft",
		CFrame.new(wx - 10, 14.5, wz) * CFrame.Angles(0, 0, math.rad(8)),
		Vector3.new(26, 0.8, 27),
		C.roof,
		M.Slate
	)
	box(
		room,
		"RoofFallen",
		CFrame.new(wx + 13, 6, wz + 2) * CFrame.Angles(0, 0, math.rad(-38)),
		Vector3.new(18, 0.8, 22),
		C.roof,
		M.Slate
	)
	Kit.oak(room, Vector3.new(wx + 6, 1, wz + 4), 34, rng, C.leaf)
	for i = 1, 4 do
		box(
			room,
			"OldBench",
			CFrame.new(wx - 16 + i * 6, 2.2, wz + 9) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			Vector3.new(5, 0.4, 2),
			C.woodDark,
			M.WoodPlanks
		)
	end
	local clockFace = cyl(
		room,
		"Clock",
		CFrame.new(wx - 13, 12, wz - 13.2) * CFrame.Angles(0, math.rad(90), 0),
		0.4,
		4,
		C.cream:Lerp(C.moss, 0.3),
		M.SmoothPlastic
	)
	_ = clockFace
	local glow = Kit.ball(
		room,
		"RoomGlow",
		Vector3.new(wx - 6, 6, wz + 2),
		0.6,
		Kit.rgb(190, 255, 190),
		M.Neon,
		{ CastShadow = false }
	)
	Kit.light(glow, "PointLight", { Range = 24, Brightness = 1.5, Color = Kit.rgb(190, 255, 200) })
	node(model, "blueprint", CFrame.new(wx - 14, 1, wz + 6), 1, true)
	-- a second, ruined platform farther out with a rusted coach
	box(
		model,
		"RuinPlatform",
		CFrame.new(60, 2, 170),
		Vector3.new(160, 4, 12),
		C.concrete:Lerp(C.moss, 0.4),
		M.Concrete
	)
	local coach = Kit.model("RustedCoach", model)
	box(coach, "CoachBody", CFrame.new(60, 7, 158), Vector3.new(56, 10, 12), C.rust:Lerp(C.green, 0.3), M.CorrodedMetal)
	box(coach, "CoachRoof", CFrame.new(60, 12.4, 158), Vector3.new(56, 1, 10), C.rustDark, M.CorrodedMetal)
	for i = -3, 3 do
		box(
			coach,
			"CoachWindow",
			CFrame.new(60 + i * 7, 8, 151.95),
			Vector3.new(4, 3, 0.2),
			C.black,
			M.SmoothPlastic,
			{ CastShadow = false }
		)
	end
	node(model, "parts", CFrame.new(40, 4, 172), 2, true)
	node(model, "cloth", CFrame.new(90, 4, 173), 2, true)
	local spots = {
		{ "scrap", -120, 40, 1 },
		{ "scrap", 60, 44, 1 },
		{ "scrap", 180, 80, 2 },
		{ "scrap", -200, 130, 1 },
		{ "wood", -60, 36, 1 },
		{ "wood", 120, 40, 1 },
		{ "wood", -170, 70, 2 },
		{ "wood", 210, 160, 1 },
		{ "cloth", 20, 40, 1 },
		{ "cloth", -100, 120, 1 },
		{ "cloth", 150, 120, 1 },
		{ "parts", -220, 200, 2, true },
		{ "parts", 220, 210, 1, true },
		{ "parts", -40, 140, 1 },
	}
	for _, s in spots do
		node(model, s[1], CFrame.new(s[2], 0, s[3]) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), s[4], s[5])
	end
	return {
		fuel = {
			{ -150, 32 },
			{ -40, 34 },
			{ 70, 36 },
			{ 180, 34 },
			{ -90, 100 },
			{ 120, 100 },
			{ -180, 170 },
			{ 0, 180 },
			{ 230, 200 },
		},
	}
end

local CONTENT = { ranger = ranger, timber = timber, signal = signal, platform = overgrown }

-- Build one stop's template. Returns the model (fuel spots are marked as Node = "fuel" models).
function StopBuilder.build(parent, stop)
	local model = Kit.model("Stop_" .. stop.key, parent)
	model:SetAttribute("Stop", stop.key)
	local extra = CONTENT[stop.key](model)
	for i, f in extra.fuel or {} do
		local m = node(model, "fuel", CFrame.new(f[1], 0, f[2]) * CFrame.Angles(0, (i * 1.7) % (math.pi * 2), 0), 1)
		m:SetAttribute("FuelSpot", i)
	end
	return model
end

return StopBuilder

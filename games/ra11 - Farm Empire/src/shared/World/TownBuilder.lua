--[[
The shared town (master plan §4) and the land under everything. The square in the middle of the avenue: cobbles
and hedges, the welcome arches over the avenue at both ends, a three-tier fountain, the market hall (a roofed hall
of stalls with the orders board on its back wall), the boost tower (a tall glass tube on a plinth, lit by the
server's boost), the leaderboard wall with its podium, a bandstand, benches, lamps, flower beds and planters.
Round the whole map: a base plate, rolling hills along the edges and an invisible wall so nobody walks off.

  TownBuilder.build(parent)   a Model "Town"
  TownBuilder.world(parent)   a Model "World": the base and the edges
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Layout = require(script.Parent.Layout)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local rgb = Color3.fromRGB
local TownBuilder = {}

local function lamp(parent, o)
	Shapes.part(parent, Vector3.new(0.6, 10, 0.6), o * CFrame.new(0, 5, 0), P.steelDark)
	Shapes.part(parent, Vector3.new(2, 1, 2), o * CFrame.new(0, 10.4, 0), P.steelDark)
	Shapes.part(parent, Vector3.new(1.4, 1, 1.4), o * CFrame.new(0, 10.2, 0), rgb(255, 240, 180)).Material =
		Enum.Material.Neon
end

local function bench(parent, o)
	Shapes.part(parent, Vector3.new(5, 0.4, 1.4), o * CFrame.new(0, 1.4, 0), P.wood)
	Shapes.part(parent, Vector3.new(5, 1.6, 0.3), o * CFrame.new(0, 2.4, 0.6), P.wood)
	for _, x in { -2, 2 } do
		Shapes.part(parent, Vector3.new(0.4, 1.4, 1.4), o * CFrame.new(x, 0.7, 0), P.steelDark)
	end
end

local function planter(parent, o)
	Shapes.part(parent, Vector3.new(4, 1.6, 4), o * CFrame.new(0, 0.8, 0), rgb(170, 110, 80)).Material =
		Enum.Material.Brick
	Shapes.tree(parent, o * CFrame.new(0, 1.2, 0), 0.8, P.leaf)
end

local function hedge(parent, o, len)
	Shapes.part(parent, Vector3.new(len, 2.2, 1.6), o * CFrame.new(0, 1.1, 0), P.grassDark).Material =
		Enum.Material.Grass
end

function TownBuilder.world(parent)
	local m = Shapes.model(parent, "World")
	local hw, hd = Layout.MAP.halfWidth, Layout.MAP.halfDepth
	local base =
		Shapes.part(m, Vector3.new(hw * 2, 4, hd * 2), CFrame.new(0, -2.2, 0), P.grassDark, { CanCollide = true })
	base.Name = "Base"
	base.Material = Enum.Material.Grass
	-- rolling hills along every edge, in two rows
	local rng = Random.new(11)
	local function hills(x1, z1, x2, z2, n)
		for k = 0, n do
			local t = k / n
			local x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			local r = 18 + rng:NextNumber(0, 16)
			local h = Shapes.ball(
				m,
				Vector3.new(r * 2, r * 1.1, r * 2),
				CFrame.new(x + rng:NextNumber(-6, 6), -r * 0.25, z + rng:NextNumber(-6, 6)),
				rng:NextNumber() < 0.5 and P.grass or P.grassDark
			)
			h.Material = Enum.Material.Grass
			if k % 3 == 0 then
				Shapes.tree(m, CFrame.new(x, r * 0.3, z), 1.6, P.leaf)
			end
		end
	end
	hills(-hw, hd - 20, hw, hd - 20, 40)
	hills(-hw, -hd + 20, hw, -hd + 20, 40)
	hills(-hw + 20, -hd, -hw + 20, hd, 24)
	hills(hw - 20, -hd, hw - 20, hd, 24)
	-- an invisible wall round the map
	for _, side in { { 0, -hd, hw * 2, 1 }, { 0, hd, hw * 2, 1 }, { -hw, 0, 1, hd * 2 }, { hw, 0, 1, hd * 2 } } do
		local wall = Shapes.part(
			m,
			Vector3.new(side[3], 80, side[4]),
			CFrame.new(side[1], 38, side[2]),
			P.grass,
			{ CanCollide = true }
		)
		wall.Transparency = 1
		wall.Name = "Edge"
	end
	return m
end

function TownBuilder.build(parent)
	TownBuilder.world(parent)
	local m = Shapes.model(parent, "Town")
	local half = Layout.TOWN / 2
	local width = Layout.MAP.halfWidth * 2
	-- the avenue: the whole width of the map, kerbed, a dashed centre line
	local road =
		Shapes.part(m, Vector3.new(width, 1, Layout.AVENUE), CFrame.new(0, -0.5, 0), P.road, { CanCollide = true })
	road.Name = "Avenue"
	road.Material = Enum.Material.Asphalt
	for x = -width / 2 + 10, width / 2 - 10, 12 do
		if math.abs(x) > half then
			Shapes.part(m, Vector3.new(6, 0.1, 0.5), CFrame.new(x, 0.06, 0), P.roadLine)
		end
	end
	for _, z in { -Layout.AVENUE / 2 - 2.5, Layout.AVENUE / 2 + 2.5 } do
		Shapes.part(m, Vector3.new(width, 0.8, 5), CFrame.new(0, -0.3, z), P.concrete, { CanCollide = true }).Material =
			Enum.Material.Concrete
	end
	-- the square: cobbles over the avenue, a hedge all round with openings for the avenue and the paths
	local square = Shapes.part(
		m,
		Vector3.new(Layout.TOWN, 1.2, Layout.TOWN),
		CFrame.new(0, -0.35, 0),
		P.concrete,
		{ CanCollide = true }
	)
	square.Name = "Square"
	square.Material = Enum.Material.Cobblestone
	Shapes.part(
		m,
		Vector3.new(Layout.TOWN, 0.05, Layout.AVENUE),
		CFrame.new(0, 0.27, 0),
		P.concreteDark or rgb(190, 190, 184)
	).Material =
		Enum.Material.Cobblestone
	for _, side in
		{
			{ 0, -half + 1, half * 2 - 60, 0 },
			{ 0, half - 1, half * 2 - 60, 0 },
			{ -half + 1, -half / 2 - 12, 36, 1 },
			{ -half + 1, half / 2 + 12, 36, 1 },
			{ half - 1, -half / 2 - 12, 36, 1 },
			{ half - 1, half / 2 + 12, 36, 1 },
		}
	do
		local o = CFrame.new(side[1], 0.2, side[2]) * CFrame.Angles(0, side[4] == 1 and math.pi / 2 or 0, 0)
		if side[4] == 0 then
			hedge(m, CFrame.new(side[1] - half / 2 - 15, 0.2, side[2]), side[3] / 2)
			hedge(m, CFrame.new(side[1] + half / 2 + 15, 0.2, side[2]), side[3] / 2)
		else
			hedge(m, o, side[3])
		end
	end
	-- the welcome arches over the avenue at both ends of the square
	for _, x in { -half, half } do
		for _, z in { -Layout.AVENUE / 2 - 4, Layout.AVENUE / 2 + 4 } do
			local pillar = Shapes.part(m, Vector3.new(3, 14, 3), CFrame.new(x, 7, z), rgb(170, 110, 80))
			pillar.Material = Enum.Material.Brick
		end
		local beam = Shapes.part(m, Vector3.new(3, 3.5, Layout.AVENUE + 11), CFrame.new(x, 15.75, 0), P.woodDark)
		beam.Name = "Arch"
		Shapes.face(
			beam,
			"FARM EMPIRE",
			x < 0 and Enum.NormalId.Left or Enum.NormalId.Right,
			{ PixelsPerStud = 30, TextColor3 = P.safetyYellow }
		)
		Shapes.face(
			beam,
			"FARM EMPIRE",
			x < 0 and Enum.NormalId.Right or Enum.NormalId.Left,
			{ PixelsPerStud = 30, TextColor3 = P.safetyYellow }
		)
		for k = -2, 2 do
			Shapes.ball(m, Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, 17.8, k * 9), rgb(255, 240, 180)).Material =
				Enum.Material.Neon
		end
	end
	-- the fountain: three tiers, a gold star on top
	local f = Layout.TOWN_SPOTS.fountain
	for k, spec in { { 20, 1.6 }, { 12, 4.2 }, { 6, 6.6 } } do
		local r, y = spec[1], spec[2]
		Shapes.cylinder(m, Vector3.new(1.4, r, r), CFrame.new(f.x, y, f.z) * CFrame.Angles(0, 0, math.pi / 2), P.steel)
		local water = Shapes.cylinder(
			m,
			Vector3.new(0.6, r - 1.5, r - 1.5),
			CFrame.new(f.x, y + 0.6, f.z) * CFrame.Angles(0, 0, math.pi / 2),
			P.water
		)
		water.Transparency = 0.3
		if k < 3 then
			Shapes.cylinder(
				m,
				Vector3.new(2.6, 2, 2),
				CFrame.new(f.x, y + 2, f.z) * CFrame.Angles(0, 0, math.pi / 2),
				P.steel
			)
		end
	end
	Shapes.ball(m, Vector3.new(3.4, 3.4, 3.4), CFrame.new(f.x, 9.4, f.z), P.safetyYellow).Material = Enum.Material.Neon
	-- the market hall (west): a roofed hall of stalls, the orders board on its back wall
	local b = Layout.TOWN_SPOTS.board
	local hall = Shapes.model(m, "MarketHall")
	Shapes.part(hall, Vector3.new(36, 0.3, 22), CFrame.new(b.x, 0.4, b.z), P.path).Material = Enum.Material.Cobblestone
	for _, x in { -16, 0, 16 } do
		for _, z in { -10, 10 } do
			Shapes.part(hall, Vector3.new(0.8, 10, 0.8), CFrame.new(b.x + x, 5, b.z + z), P.woodDark)
		end
	end
	Shapes.wedge(hall, Vector3.new(38, 4, 12), CFrame.new(b.x, 12, b.z - 6) * CFrame.Angles(0, math.pi, 0), P.barnRed)
	Shapes.wedge(hall, Vector3.new(38, 4, 12), CFrame.new(b.x, 12, b.z + 6), P.barnRed)
	Shapes.part(hall, Vector3.new(38, 0.6, 24), CFrame.new(b.x, 10.1, b.z), P.woodDark)
	for k = 0, 2 do
		local x = b.x - 12 + k * 12
		Shapes.part(hall, Vector3.new(9, 2.6, 3), CFrame.new(x, 1.7, b.z - 7), P.wood)
		for j = 0, 3 do
			Shapes.ball(
				hall,
				Vector3.new(0.9, 0.9, 0.9),
				CFrame.new(x - 3 + j * 2, 3.4, b.z - 7),
				({ rgb(230, 50, 60), rgb(250, 212, 60), rgb(246, 140, 40), rgb(80, 90, 200) })[(j + k) % 4 + 1]
			)
		end
		for j = 0, 5 do
			Shapes.part(
				hall,
				Vector3.new(1.5, 0.3, 3.4),
				CFrame.new(x - 3.75 + j * 1.5, 5.8, b.z - 7.4) * CFrame.Angles(0.3, 0, 0),
				j % 2 == 0 and ({ P.awning, rgb(60, 150, 240), rgb(86, 192, 96) })[k + 1] or P.awningStripe
			)
		end
	end
	local board = Shapes.part(hall, Vector3.new(20, 7, 0.8), CFrame.new(b.x, 5.5, b.z + 9.5), rgb(60, 50, 44))
	board.Name = "MarketBoard"
	Shapes.face(
		board,
		"MARKET ORDERS\nthree a day · delivered from your stock",
		Enum.NormalId.Front,
		{ PixelsPerStud = 24, TextColor3 = P.cream }
	)
	Shapes.part(hall, Vector3.new(22, 1, 1.2), CFrame.new(b.x, 9.3, b.z + 9.5), P.safetyYellow)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Market"
	prompt.ActionText = "Market orders"
	prompt.ObjectText = "Town board"
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	-- the leaderboard wall (east) and the podium in front of it
	local lb = Layout.TOWN_SPOTS.boards
	local wallBase = Shapes.part(
		m,
		Vector3.new(44, 1, 6),
		CFrame.new(lb.x, 0.5, lb.z + 6),
		rgb(150, 150, 145),
		{ CanCollide = true }
	)
	wallBase.Material = Enum.Material.Slate
	Shapes.part(m, Vector3.new(44, 13, 2), CFrame.new(lb.x, 6.5, lb.z + 8), rgb(150, 150, 145), { CanCollide = true }).Material =
		Enum.Material.Slate
	Shapes.part(m, Vector3.new(46, 1.2, 3), CFrame.new(lb.x, 13.4, lb.z + 8), P.safetyYellow)
	for k = -1, 1 do
		local plate = Shapes.part(m, Vector3.new(12, 10, 0.8), CFrame.new(lb.x + k * 14, 6.5, lb.z + 6.6), P.steelDark)
		plate.Name = "Leaderboard"
		plate:SetAttribute("Board", ({ "earned", "regions", "sold" })[k + 2])
		Shapes.part(m, Vector3.new(13, 11, 0.4), CFrame.new(lb.x + k * 14, 6.5, lb.z + 6.9), P.woodDark)
	end
	for k, spec in { { -5, 1.6, rgb(200, 200, 205) }, { 0, 2.4, rgb(255, 200, 36) }, { 5, 1, rgb(190, 120, 60) } } do
		Shapes.part(
			m,
			Vector3.new(4.6, spec[2], 4.6),
			CFrame.new(lb.x + spec[1], spec[2] / 2 + 0.2, lb.z - 4),
			spec[3],
			{ CanCollide = true }
		)
		Shapes.face(
			Shapes.part(
				m,
				Vector3.new(2, 1.2, 0.2),
				CFrame.new(lb.x + spec[1], spec[2] / 2 + 0.2, lb.z - 6.4),
				P.woodDark
			),
			tostring(k == 2 and 1 or (k == 1 and 2 or 3)),
			Enum.NormalId.Front,
			{ PixelsPerStud = 40 }
		)
	end
	-- the boost tower (north): a plinth, the glass tube, rings, a star on top
	local mt = Layout.TOWN_SPOTS.meter
	local plinth =
		Shapes.part(m, Vector3.new(14, 2.4, 14), CFrame.new(mt.x, 1.2, mt.z), P.steelDark, { CanCollide = true })
	plinth.Name = "MeterPlinth"
	Shapes.part(m, Vector3.new(18, 0.6, 18), CFrame.new(mt.x, 0.3, mt.z), P.concrete, { CanCollide = true })
	local tube = Shapes.cylinder(
		m,
		Vector3.new(22, 5, 5),
		CFrame.new(mt.x, 13.4, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.glass
	)
	tube.Name = "MeterTube"
	tube.Transparency = 0.45
	local fill = Shapes.cylinder(
		m,
		Vector3.new(0.2, 4.2, 4.2),
		CFrame.new(mt.x, 2.5, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.accent
	)
	fill.Name = "MeterFill"
	fill.Material = Enum.Material.Neon
	for k = 1, 4 do
		Shapes.cylinder(
			m,
			Vector3.new(0.6, 6, 6),
			CFrame.new(mt.x, 2.4 + k * 5, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
			P.steelDark
		)
	end
	Shapes.cylinder(
		m,
		Vector3.new(1.2, 6.4, 6.4),
		CFrame.new(mt.x, 24.8, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.steelDark
	)
	Shapes.ball(m, Vector3.new(3, 3, 3), CFrame.new(mt.x, 27, mt.z), P.safetyYellow).Material = Enum.Material.Neon
	Shapes.label(
		plinth,
		"SERVER BOOST\nchip in Cash · lights a boost for everyone",
		{ Size = UDim2.fromOffset(300, 60), StudsOffset = Vector3.new(0, 28, 0), MaxDistance = 220 }
	)
	local bp = Instance.new("ProximityPrompt")
	bp.Name = "Boost"
	bp.ActionText = "Server boost"
	bp.ObjectText = "Chip in"
	bp.MaxActivationDistance = 16
	bp.RequiresLineOfSight = false
	bp.Parent = plinth
	-- the bandstand (south-west), benches, lamps, planters, flower beds
	local bs = { x = -60, z = 50 }
	Shapes.cylinder(
		m,
		Vector3.new(1, 22, 22),
		CFrame.new(bs.x, 0.6, bs.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.wood,
		{ CanCollide = true }
	)
	for k = 0, 5 do
		local a = k * math.pi / 3
		Shapes.part(
			m,
			Vector3.new(0.7, 9, 0.7),
			CFrame.new(bs.x + math.cos(a) * 9.5, 5.5, bs.z + math.sin(a) * 9.5),
			P.white
		)
	end
	Shapes.cylinder(
		m,
		Vector3.new(1, 24, 24),
		CFrame.new(bs.x, 10.4, bs.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.roofGreen
	)
	Shapes.ball(m, Vector3.new(6, 4, 6), CFrame.new(bs.x, 12.2, bs.z), P.roofGreen)
	Shapes.ball(m, Vector3.new(1.4, 1.4, 1.4), CFrame.new(bs.x, 14.6, bs.z), P.safetyYellow)
	for _, spot in { { -30, 0 }, { 30, 0 }, { 0, -30 }, { 0, 28 } } do
		local o = CFrame.new(f.x + spot[1], 0.2, f.z + spot[2])
			* CFrame.Angles(0, math.atan2(-spot[1], -spot[2]) + math.pi, 0)
		bench(m, o)
	end
	for _, c in
		{
			{ -half + 12, -half + 12 },
			{ half - 12, -half + 12 },
			{ -half + 12, half - 12 },
			{ half - 12, half - 12 },
			{ -30, 30 },
			{ 30, 30 },
			{ -30, -30 },
			{ 30, -30 },
		}
	do
		lamp(m, CFrame.new(c[1], 0.2, c[2]))
	end
	for _, c in
		{ { -40, 70 }, { 40, 70 }, { -half + 24, half - 24 }, { half - 24, half - 24 }, { half - 30, -half + 30 } }
	do
		planter(m, CFrame.new(c[1], 0.2, c[2]))
	end
	for _, c in { { -22, -22 }, { 22, -22 }, { -22, 22 }, { 22, 22 } } do
		Shapes.part(m, Vector3.new(8, 0.8, 8), CFrame.new(c[1], 0.6, c[2]), P.soilDark)
		local rng = Random.new(c[1] * 3 + c[2])
		for k = 1, 14 do
			local x, z = rng:NextNumber(-3.2, 3.2), rng:NextNumber(-3.2, 3.2)
			Shapes.part(m, Vector3.new(0.3, 0.9, 0.3), CFrame.new(c[1] + x, 1.4, c[2] + z), P.leaf)
			Shapes.ball(
				m,
				Vector3.new(0.8, 0.8, 0.8),
				CFrame.new(c[1] + x, 1.9, c[2] + z),
				({ rgb(255, 90, 90), rgb(255, 210, 60), rgb(250, 120, 200), rgb(240, 240, 255) })[k % 4 + 1]
			)
		end
	end
	-- a spawn for visitors by the south entrance
	local sp = Layout.TOWN_SPOTS.spawn
	local spawn = Shapes.part(m, Vector3.new(10, 0.3, 10), CFrame.new(sp.x, 0.4, sp.z), P.path)
	spawn.Name = "TownSpawn"
	spawn.Material = Enum.Material.Cobblestone
	return m
end

return TownBuilder

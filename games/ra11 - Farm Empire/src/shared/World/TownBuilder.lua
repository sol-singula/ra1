--[[
The city in the middle of the map (master plan §4) and the land under everything.

The city: streets and blocks of fake buildings (shops on the ground floor, windows above, awnings, signs, roof
tanks and vents, parked cars and street lamps) round a big paved courtyard where the avenue runs in through two
arches. In the courtyard: a three-tier fountain, the leaderboard wall with its podium (north), the Farm Empire
store (north-west, coming soon: nothing to buy yet), the market hall with the orders board (north-east), the
boost tower (south), flower beds, benches, lamps and trees in planters.

The land: a base plate under the whole map, the avenue past the farms with its sidewalks and lamps, tree strips
between the farms, rolling hills round the edge and an invisible wall so nobody walks off.

  TownBuilder.build(parent)   a Model "Town" (and a Model "World")
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Layout = require(script.Parent.Layout)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local rgb = Color3.fromRGB
local TownBuilder = {}

local CITY = Layout.CITY
local COURT = CITY.court

-- Bits -----------------------------------------------------------------------------------------------------------------
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

local function planter(parent, o, scale)
	Shapes.part(parent, Vector3.new(4.4, 1.6, 4.4), o * CFrame.new(0, 0.8, 0), rgb(170, 110, 80)).Material =
		Enum.Material.Brick
	Shapes.part(parent, Vector3.new(3.8, 0.2, 3.8), o * CFrame.new(0, 1.65, 0), P.soilDark)
	Shapes.tree(parent, o * CFrame.new(0, 1.6, 0), scale or 0.85, P.leaf)
end

local function flowerBed(parent, o, w, d, seed)
	Shapes.part(parent, Vector3.new(w + 0.8, 0.9, d + 0.8), o * CFrame.new(0, 0.45, 0), rgb(150, 150, 145)).Material =
		Enum.Material.Slate
	Shapes.part(parent, Vector3.new(w, 0.3, d), o * CFrame.new(0, 0.95, 0), P.soilDark)
	local rng = Random.new(seed or 1)
	local colors = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(250, 120, 200), rgb(240, 240, 255), rgb(255, 150, 60) }
	for k = 1, math.floor(w * d / 3) do
		local x, z = rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), rng:NextNumber(-d / 2 + 0.6, d / 2 - 0.6)
		Shapes.part(parent, Vector3.new(0.3, 0.9, 0.3), o * CFrame.new(x, 1.5, z), P.leaf)
		Shapes.sphere(parent, Vector3.new(0.8, 0.8, 0.8), o * CFrame.new(x, 2, z), colors[k % #colors + 1])
	end
end

local CAR_COLORS =
	{ rgb(220, 60, 50), rgb(60, 120, 220), rgb(250, 200, 50), rgb(240, 240, 240), rgb(60, 170, 90), rgb(40, 40, 46) }
local function car(parent, o, k)
	local m = Shapes.model(parent, "Car")
	local c = CAR_COLORS[k % #CAR_COLORS + 1]
	Shapes.part(m, Vector3.new(4, 1.6, 8), o * CFrame.new(0, 1.4, 0), c)
	Shapes.part(m, Vector3.new(3.6, 1.4, 4.2), o * CFrame.new(0, 2.9, 0.4), Shapes.shade(c, 0.1))
	Shapes.part(m, Vector3.new(3.7, 1.1, 4.3), o * CFrame.new(0, 2.9, 0.4), rgb(150, 206, 236)).Transparency = 0.2
	for _, x in { -1.8, 1.8 } do
		for _, z in { -2.6, 2.6 } do
			Shapes.cylinder(m, Vector3.new(0.6, 1.5, 1.5), o * CFrame.new(x, 0.75, z), rgb(30, 30, 34))
		end
	end
	for _, x in { -1.3, 1.3 } do
		Shapes.part(m, Vector3.new(0.6, 0.4, 0.1), o * CFrame.new(x, 1.6, -4.02), rgb(255, 245, 200)).Material =
			Enum.Material.Neon
	end
	return m
end

-- A fake building: front facing -z of o, standing on o
local STYLES = {
	{ body = rgb(178, 84, 64), trim = rgb(236, 224, 200) }, -- brick
	{ body = rgb(236, 224, 196), trim = rgb(120, 90, 70) }, -- cream
	{ body = rgb(80, 150, 150), trim = rgb(240, 240, 232) }, -- teal
	{ body = rgb(222, 178, 80), trim = rgb(110, 80, 60) }, -- mustard
	{ body = rgb(150, 154, 160), trim = rgb(230, 230, 230) }, -- grey
	{ body = rgb(90, 120, 170), trim = rgb(236, 236, 236) }, -- blue
	{ body = rgb(206, 176, 140), trim = rgb(110, 76, 54) }, -- sand
	{ body = rgb(214, 140, 140), trim = rgb(250, 244, 236) }, -- rose
	{ body = rgb(150, 196, 170), trim = rgb(70, 90, 80) }, -- mint
}
local AWNINGS = { rgb(220, 60, 50), rgb(60, 130, 220), rgb(60, 160, 90), rgb(250, 190, 40), rgb(160, 90, 200) }
local NAMES = {
	"BAKERY",
	"BANK",
	"CAFE",
	"HOTEL",
	"DINER",
	"BOOKS",
	"TOYS",
	"PIZZA",
	"FLOWERS",
	"GROCER",
	"POST OFFICE",
	"CINEMA",
	"GYM",
	"PHARMACY",
	"ICE CREAM",
	"HARDWARE",
	"TAILOR",
	"MUSIC",
	"BARBER",
	"SEEDS & FEED",
	"TRACTORS",
	"BURGERS",
	"DONUTS",
	"NEWS",
}
local nameIndex = 0

local function building(parent, o, w, d, h, n, opts)
	opts = opts or {}
	local st = STYLES[n % #STYLES + 1]
	local m = Shapes.model(parent, "Building")
	local body = Shapes.part(m, Vector3.new(w, h, d), o * CFrame.new(0, h / 2, 0), st.body, { CanCollide = true })
	body.Name = "Body"
	if st.body == STYLES[1].body then
		body.Material = Enum.Material.Brick
	end
	-- the ground floor
	Shapes.part(m, Vector3.new(w + 0.3, 6, d + 0.3), o * CFrame.new(0, 3, 0), Shapes.shade(st.body, -0.18))
	local front = -d / 2 - 0.2
	if opts.shop ~= false then
		Shapes.part(m, Vector3.new(w - 5, 3.4, 0.3), o * CFrame.new(-1, 2.6, front), rgb(150, 206, 236))
		Shapes.part(m, Vector3.new(w - 4.6, 0.4, 0.4), o * CFrame.new(-1, 4.5, front - 0.05), st.trim)
		Shapes.part(m, Vector3.new(2.4, 4.4, 0.3), o * CFrame.new(w / 2 - 2.2, 2.2, front), Shapes.shade(st.trim, -0.4))
		local aw = AWNINGS[n % #AWNINGS + 1]
		local stripes = math.max(3, math.floor(w / 2))
		for k = 0, stripes - 1 do
			Shapes.part(
				m,
				Vector3.new(w / stripes, 0.25, 3),
				o * CFrame.new(-w / 2 + (k + 0.5) * w / stripes, 5.6, front - 1.3) * CFrame.Angles(0.3, 0, 0),
				k % 2 == 0 and aw or rgb(250, 246, 236)
			)
		end
		nameIndex += 1
		local signBoard =
			Shapes.part(m, Vector3.new(math.min(w - 2, 16), 1.8, 0.3), o * CFrame.new(0, 7.4, front - 0.1), st.trim)
		Shapes.face(signBoard, opts.name or NAMES[nameIndex % #NAMES + 1], Enum.NormalId.Front, {
			TextColor3 = st.body:Lerp(Color3.new(0, 0, 0), 0.35),
			TextStrokeTransparency = 1,
			PixelsPerStud = 30,
		})
	else
		Shapes.part(m, Vector3.new(4, 4.6, 0.3), o * CFrame.new(0, 2.3, front), rgb(150, 206, 236))
		Shapes.part(m, Vector3.new(5, 0.5, 2), o * CFrame.new(0, 4.9, front - 0.8), st.trim)
	end
	-- the floors above: a window strip a floor, mullions between bays
	local floors = math.floor((h - 8) / 4)
	local glass = rgb(120, 170, 210)
	for f = 1, floors do
		Shapes.part(m, Vector3.new(w - 2.4, 2.2, 0.3), o * CFrame.new(0, 8 + (f - 1) * 4 + 1.1, front), glass)
		if opts.sides then
			for _, sx in { -1, 1 } do
				Shapes.part(
					m,
					Vector3.new(0.3, 2.2, d - 2.4),
					o * CFrame.new(sx * (w / 2 + 0.2), 8 + (f - 1) * 4 + 1.1, 0),
					glass
				)
			end
		end
	end
	if floors > 0 then
		local bays = math.max(2, math.floor((w - 2.4) / 4))
		for b = 1, bays - 1 do
			Shapes.part(
				m,
				Vector3.new(0.5, floors * 4, 0.45),
				o * CFrame.new(-(w - 2.4) / 2 + b * (w - 2.4) / bays, 8 + floors * 2 - 0.4, front - 0.05),
				st.trim
			)
		end
		for f = 1, floors do
			Shapes.part(
				m,
				Vector3.new(w - 2, 0.35, 0.5),
				o * CFrame.new(0, 8 + (f - 1) * 4 - 0.1, front - 0.05),
				st.trim
			)
		end
	end
	-- the top: a cornice and something on the roof
	Shapes.part(m, Vector3.new(w + 1, 1, d + 1), o * CFrame.new(0, h + 0.5, 0), st.trim)
	local rng = Random.new(n * 31 + 7)
	local r = rng:NextInteger(1, 3)
	if r == 1 and h > 24 then
		-- a water tank on legs
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Shapes.part(m, Vector3.new(0.4, 4, 0.4), o * CFrame.new(sx * 1.6 + 2, h + 3, sz * 1.6), P.woodDark)
			end
		end
		Shapes.cylinder(
			m,
			Vector3.new(4, 4.4, 4.4),
			o * CFrame.new(2, h + 6.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
			P.wood
		)
		Shapes.wedge(
			m,
			Vector3.new(4.6, 1.4, 2.3),
			o * CFrame.new(2, h + 9.5, -1.15) * CFrame.Angles(0, math.pi, 0),
			P.woodDark
		)
		Shapes.wedge(m, Vector3.new(4.6, 1.4, 2.3), o * CFrame.new(2, h + 9.5, 1.15), P.woodDark)
	elseif r == 2 then
		Shapes.part(m, Vector3.new(4, 2, 3), o * CFrame.new(-w / 4, h + 2, 0), rgb(190, 192, 196))
		Shapes.part(m, Vector3.new(3, 1.4, 3), o * CFrame.new(w / 4, h + 1.7, d / 4), rgb(170, 172, 176))
	else
		Shapes.part(m, Vector3.new(0.3, 8, 0.3), o * CFrame.new(w / 3, h + 5, 0), P.steelDark)
		Shapes.sphere(m, Vector3.new(0.7, 0.7, 0.7), o * CFrame.new(w / 3, h + 9.2, 0), rgb(255, 70, 60)).Material =
			Enum.Material.Neon
	end
	return m
end

-- A row of buildings along x from x0 to x1, fronts at z = front facing -z (dir = 1) or +z (dir = -1)
local counter = 0
local function row(parent, x0, x1, front, dir, depth, widths, heights, opts)
	local x = x0
	local k = 0
	while x < x1 - 1 do
		k += 1
		local w = math.min(widths[(k - 1) % #widths + 1], x1 - x)
		local h = heights[(k - 1) % #heights + 1]
		counter += 1
		local cz = front + dir * depth / 2
		local o = CFrame.new(x + w / 2, 0.4, cz) * CFrame.Angles(0, dir == 1 and 0 or math.pi, 0)
		building(parent, o, w - 0.6, depth, h, counter, {
			shop = opts.shop,
			sides = (k == 1 or x + w >= x1 - 1) or opts.sides,
		})
		x += w
	end
end

-- A column of buildings along z (east/west sides of the courtyard), fronts facing toward x = 0
local function column(parent, z0, z1, front, dir, depth, widths, heights)
	local z = z0
	local k = 0
	while z < z1 - 1 do
		k += 1
		local w = math.min(widths[(k - 1) % #widths + 1], z1 - z)
		counter += 1
		local cx = front + dir * depth / 2
		-- front faces -x when dir = 1 (east side), +x when dir = -1 (west side)
		local o = CFrame.new(cx, 0.4, z + w / 2) * CFrame.Angles(0, dir == 1 and math.pi / 2 or -math.pi / 2, 0)
		building(parent, o, w - 0.6, depth, heights[(k - 1) % #heights + 1], counter, { sides = true })
		z += w
	end
end

-- The land under everything --------------------------------------------------------------------------------------------
function TownBuilder.world(parent)
	local m = Shapes.model(parent, "World")
	local hw, hd = Layout.MAP.halfWidth, Layout.MAP.halfDepth
	local base =
		Shapes.part(m, Vector3.new(hw * 2, 4, hd * 2), CFrame.new(0, -2.2, 0), P.grassDark, { CanCollide = true })
	base.Name = "Base"
	base.Material = Enum.Material.Grass
	-- the avenue past the farms (east and west of the city): asphalt, sidewalks, dashes, lamps
	local half = Layout.AVENUE / 2
	local roadHalf = Layout.ROAD / 2
	for _, sx in { -1, 1 } do
		local x0, x1 = CITY.half, hw
		local cx = sx * (x0 + x1) / 2
		local road =
			Shapes.part(m, Vector3.new(x1 - x0, 1, Layout.ROAD), CFrame.new(cx, -0.5, 0), P.road, { CanCollide = true })
		road.Name = "Avenue"
		road.Material = Enum.Material.Asphalt
		for _, sz in { -1, 1 } do
			local walk = Shapes.part(
				m,
				Vector3.new(x1 - x0, 1.3, half - roadHalf),
				CFrame.new(cx, -0.35, sz * (roadHalf + half) / 2),
				P.concrete,
				{ CanCollide = true }
			)
			walk.Material = Enum.Material.Concrete
		end
		for x = x0 + 8, x1 - 8, 12 do
			Shapes.part(m, Vector3.new(6, 0.1, 0.5), CFrame.new(sx * x, 0.06, 0), P.roadLine)
		end
		for x = x0 + 30, x1 - 20, 50 do
			for _, sz in { -1, 1 } do
				lamp(m, CFrame.new(sx * x, 0.3, sz * (half - 2)))
			end
		end
	end
	-- tree strips between the farms (and beyond the last one)
	for _, sx in { -1, 1 } do
		for k = 0, 3 do
			local x = CITY.half + Layout.GAP / 2 + (Layout.WIDTH + Layout.GAP) * k
			if k == 3 then
				x = CITY.half + (Layout.WIDTH + Layout.GAP) * 3 + 6
			end
			for _, sz in { -1, 1 } do
				local strip = Shapes.part(
					m,
					Vector3.new(Layout.GAP - 2, 0.3, Layout.DEPTH - 4),
					CFrame.new(sx * x, 0.0, sz * (half + Layout.DEPTH / 2)),
					P.grass
				)
				strip.Material = Enum.Material.Grass
				for z = half + 8, half + Layout.DEPTH - 8, 16 do
					Shapes.tree(m, CFrame.new(sx * x, 0, sz * z), 1, (z // 16) % 2 == 0 and P.leaf or P.grassDark)
				end
			end
		end
	end
	-- rolling hills round the edge
	local rng = Random.new(11)
	local function hills(x1, z1, x2, z2, n)
		for k = 0, n do
			local t = k / n
			local x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
			local r = 18 + rng:NextNumber(0, 16)
			local h = Shapes.sphere(
				m,
				Vector3.new(r * 2, r * 1.1, r * 2),
				CFrame.new(x + rng:NextNumber(-6, 6), -r * 0.2, z + rng:NextNumber(-6, 6)),
				rng:NextNumber() < 0.5 and P.grass or P.grassDark
			)
			h.Material = Enum.Material.Grass
			if k % 3 == 0 then
				Shapes.tree(m, CFrame.new(x, r * 0.32, z), 1.5, P.leaf)
			end
		end
	end
	hills(-hw, hd - 22, hw, hd - 22, 48)
	hills(-hw, -hd + 22, hw, -hd + 22, 48)
	hills(-hw + 22, -hd, -hw + 22, hd, 26)
	hills(hw - 22, -hd, hw - 22, hd, 26)
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

-- The city ---------------------------------------------------------------------------------------------------------------
local function city(m)
	local H, D = CITY.half, CITY.depth
	local streets = Shapes.part(m, Vector3.new(H * 2, 1, D * 2), CFrame.new(0, -0.5, 0), P.road, { CanCollide = true })
	streets.Name = "Streets"
	streets.Material = Enum.Material.Asphalt
	local function block(x0, x1, z0, z1)
		local p = Shapes.part(
			m,
			Vector3.new(x1 - x0, 0.8, z1 - z0),
			CFrame.new((x0 + x1) / 2, 0, (z0 + z1) / 2),
			P.concrete,
			{ CanCollide = true }
		)
		p.Material = Enum.Material.Concrete
		return p
	end
	local B1 = COURT + 8 -- the first ring of blocks starts here (a street round the courtyard first)
	for _, sz in { -1, 1 } do
		local function z(v)
			return sz * v
		end
		-- the sidewalks under the rows
		local function sblock(a, b)
			local lo, hi = math.min(z(a), z(b)), math.max(z(a), z(b))
			block(-H, H, lo, hi)
		end
		sblock(B1, B1 + 26)
		sblock(B1 + 34, B1 + 84)
		sblock(B1 + 92, D)
		-- ring 1: shops facing the courtyard; ring 2: taller; ring 3: the skyline
		local dir = sz == 1 and 1 or -1
		row(m, -H, H, z(B1 + 3), dir, 22, { 24, 20, 28, 24, 28, 20, 24, 24 }, { 16, 20, 14, 22, 18, 14, 20, 16 }, {})
		row(m, -H, H, z(B1 + 37), dir, 44, { 32, 28, 36, 32, 32, 32 }, { 34, 46, 30, 52, 38, 44 }, {})
		row(m, -H, H, z(B1 + 95), dir, D - B1 - 98, { 40, 36, 40, 36, 40 }, { 60, 48, 72, 54, 64 }, { shop = false })
		-- lamps and trees on the ring-1 sidewalk; parked cars in the street in front
		for x = -H + 12, H - 12, 24 do
			lamp(m, CFrame.new(x, 0.4, z(B1 + 1.5)))
			car(m, CFrame.new(x + 8, 0, z(B1 - 2.5)) * CFrame.Angles(0, math.pi / 2, 0), x)
		end
		-- the streets between the rows: dashes
		for x = -H + 6, H - 6, 12 do
			Shapes.part(m, Vector3.new(6, 0.1, 0.5), CFrame.new(x, 0.06, z(B1 + 30)), P.roadLine)
			Shapes.part(m, Vector3.new(6, 0.1, 0.5), CFrame.new(x, 0.06, z(B1 + 88)), P.roadLine)
		end
	end
	-- the east and west sides of the courtyard, either side of the avenue
	local half = Layout.AVENUE / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local z0, z1 = half + 4, B1
			block(sx == 1 and B1 or -H, sx == 1 and H or -B1, sz == 1 and z0 or -z1, sz == 1 and z1 or -z0)
			column(
				m,
				sz == 1 and z0 or -z1,
				sz == 1 and z1 or -z0,
				sx * (B1 + 3),
				sx,
				H - B1 - 4,
				{ 23, 23 },
				{ 18, 24 }
			)
		end
		-- the avenue coming in: sidewalks and dashes
		for x = COURT + 2, H - 2, 12 do
			Shapes.part(m, Vector3.new(6, 0.1, 0.5), CFrame.new(sx * x, 0.06, 0), P.roadLine)
		end
	end
end

-- The courtyard ----------------------------------------------------------------------------------------------------------
local function courtyard(m)
	local court = Shapes.part(
		m,
		Vector3.new(COURT * 2, 1, COURT * 2),
		CFrame.new(0, -0.2, 0),
		rgb(214, 206, 190),
		{ CanCollide = true }
	)
	court.Name = "Square"
	court.Material = Enum.Material.Cobblestone
	-- a darker ring and a star pattern of paving round the fountain
	Shapes.cylinder(
		m,
		Vector3.new(0.1, 46, 46),
		CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(190, 176, 150)
	)
	Shapes.cylinder(
		m,
		Vector3.new(0.12, 40, 40),
		CFrame.new(0, 0.33, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(214, 206, 190)
	)
	-- a kerb round the courtyard
	for _, side in
		{
			{ 0, -COURT, COURT * 2, 1 },
			{ 0, COURT, COURT * 2, 1 },
			{ -COURT, 0, 1, COURT * 2 },
			{ COURT, 0, 1, COURT * 2 },
		}
	do
		Shapes.part(
			m,
			Vector3.new(side[3], 0.8, side[4]),
			CFrame.new(side[1], 0.4, side[2]),
			rgb(150, 150, 145),
			{ CanCollide = false }
		).Material =
			Enum.Material.Slate
	end
	-- the arches where the avenue comes in
	local half = Layout.AVENUE / 2
	for _, x in { -COURT, COURT } do
		for _, z in { -half + 1, half - 1 } do
			local pillar =
				Shapes.part(m, Vector3.new(3, 15, 3), CFrame.new(x, 7.5, z), rgb(170, 110, 80), { CanCollide = true })
			pillar.Material = Enum.Material.Brick
			Shapes.part(m, Vector3.new(3.6, 1, 3.6), CFrame.new(x, 15.5, z), P.concrete)
		end
		local beam = Shapes.part(m, Vector3.new(2.4, 4, Layout.AVENUE + 2), CFrame.new(x, 17.5, 0), P.woodDark)
		beam.Name = "Arch"
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			Shapes.face(beam, "FARM EMPIRE CITY", face, { PixelsPerStud = 24, TextColor3 = P.safetyYellow })
		end
	end
	-- the fountain: three tiers, a gold star on top
	for k, spec in { { 22, 1.4 }, { 12, 4 }, { 6, 6.4 } } do
		local r, y = spec[1], spec[2]
		Shapes.cylinder(
			m,
			Vector3.new(1.4, r, r),
			CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(200, 200, 205),
			{ CanCollide = k == 1 }
		)
		local water = Shapes.cylinder(
			m,
			Vector3.new(0.6, r - 1.6, r - 1.6),
			CFrame.new(0, y + 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			P.water
		)
		water.Transparency = 0.25
		if k < 3 then
			Shapes.cylinder(
				m,
				Vector3.new(2.6, 2, 2),
				CFrame.new(0, y + 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
				rgb(200, 200, 205)
			)
		end
	end
	Shapes.sphere(m, Vector3.new(3.2, 3.2, 3.2), CFrame.new(0, 9.4, 0), P.safetyYellow).Material = Enum.Material.Neon
	-- flower beds on the diagonals, benches round the fountain, lamps on a ring
	for k, c in { { -26, -26 }, { 26, -26 }, { -26, 26 }, { 26, 26 } } do
		flowerBed(m, CFrame.new(c[1], 0.3, c[2]), 9, 9, k)
	end
	for k = 0, 7 do
		local a = k * math.pi / 4 + math.pi / 8
		local p = Vector3.new(math.cos(a) * 16, 0.3, math.sin(a) * 16)
		bench(m, CFrame.lookAt(p, Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.pi, 0))
	end
	for k = 0, 11 do
		-- (offset so none stands on the paths to the boost tower or the leaderboards)
		local a = k * math.pi / 6 + math.pi / 12
		lamp(m, CFrame.new(math.cos(a) * 46, 0.3, math.sin(a) * 46))
	end
	-- planters with trees round the edge (not across the avenue or in front of the buildings)
	for v = -COURT + 6, COURT - 6, 14 do
		if math.abs(v) > 30 then
			planter(m, CFrame.new(v, 0.3, -COURT + 5))
		end
		if v > half + 6 and v < COURT - 26 then -- (the south half only: the store and the hall are north)
			planter(m, CFrame.new(-COURT + 5, 0.3, -v))
			planter(m, CFrame.new(COURT - 5, 0.3, -v))
		end
	end
end

-- The leaderboard wall (north), the store (north-west), the market hall (north-east), the boost tower (south)
local function features(m)
	-- the leaderboards: a stone wall facing the fountain, three boards on it, a podium in front
	local lb = Layout.TOWN_SPOTS.boards
	local wall = Shapes.part(
		m,
		Vector3.new(48, 15, 2),
		CFrame.new(lb.x, 7.8, lb.z + 3),
		rgb(150, 150, 145),
		{ CanCollide = true }
	)
	wall.Material = Enum.Material.Slate
	Shapes.part(m, Vector3.new(50, 1.4, 3), CFrame.new(lb.x, 15.8, lb.z + 3), P.safetyYellow)
	local _, title = Shapes.sign(m, CFrame.new(lb.x, 0, lb.z + 1.8), 22, 2.6, "TOP FARMERS", nil, {
		name = "LeaderTitle",
		posts = false,
		bottom = 16.5,
		back = false,
		board = rgb(60, 50, 44),
		accent = P.safetyYellow,
	})
	_ = title
	for k = -1, 1 do
		local plate =
			Shapes.part(m, Vector3.new(13, 11, 0.8), CFrame.new(lb.x + k * 15, 8, lb.z + 1.6), rgb(40, 44, 54))
		plate.Name = "Leaderboard"
		plate:SetAttribute("Board", ({ "earned", "regions", "sold" })[k + 2])
		Shapes.part(m, Vector3.new(14, 12, 0.4), CFrame.new(lb.x + k * 15, 8, lb.z + 2.2), P.woodDark)
	end
	for k, spec in { { -6, 1.8, rgb(200, 200, 205) }, { 0, 2.8, rgb(255, 200, 36) }, { 6, 1.1, rgb(190, 120, 60) } } do
		local step = Shapes.part(
			m,
			Vector3.new(5.6, spec[2], 5.6),
			CFrame.new(lb.x + spec[1], spec[2] / 2 + 0.3, lb.z - 8),
			spec[3],
			{ CanCollide = true }
		)
		Shapes.face(step, tostring(k == 2 and 1 or (k == 1 and 2 or 3)), Enum.NormalId.Front, { PixelsPerStud = 30 })
	end
	-- the store: a proper storefront facing east, COMING SOON in the window (nothing to buy yet)
	local st = Layout.TOWN_SPOTS.store
	local so = CFrame.new(st.x, 0.3, st.z) * CFrame.Angles(0, -math.pi / 2, 0)
	local store = building(m, so, 22, 14, 18, 99, { name = "FARM EMPIRE STORE", sides = true })
	store.Name = "Store"
	local banner = Shapes.part(m, Vector3.new(14, 2, 0.2), so * CFrame.new(0, 2.6, -7.5), rgb(255, 205, 50))
	Shapes.face(
		banner,
		"COMING SOON",
		Enum.NormalId.Front,
		{ TextColor3 = rgb(58, 38, 28), TextStrokeTransparency = 1 }
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Store"
	prompt.ActionText = "Store"
	prompt.ObjectText = "Coming soon"
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = banner
	-- the market hall facing west: a roofed hall of stalls, the orders board on its back wall
	local mk = Layout.TOWN_SPOTS.board
	local mo = CFrame.new(mk.x, 0.3, mk.z) * CFrame.Angles(0, math.pi / 2, 0)
	local hall = Shapes.model(m, "MarketHall")
	Shapes.part(hall, Vector3.new(26, 0.3, 16), mo * CFrame.new(0, 0.15, 0), P.path).Material =
		Enum.Material.Cobblestone
	for _, x in { -12, 0, 12 } do
		for _, z in { -7, 7 } do
			Shapes.part(hall, Vector3.new(0.8, 10, 0.8), mo * CFrame.new(x, 5, z), P.woodDark)
		end
	end
	Shapes.wedge(hall, Vector3.new(28, 4, 9), mo * CFrame.new(0, 12, -4.5) * CFrame.Angles(0, math.pi, 0), P.barnRed)
	Shapes.wedge(hall, Vector3.new(28, 4, 9), mo * CFrame.new(0, 12, 4.5), P.barnRed)
	Shapes.part(hall, Vector3.new(28, 0.6, 18), mo * CFrame.new(0, 10.1, 0), P.woodDark)
	for k = 0, 2 do
		local x = -8 + k * 8
		Shapes.part(hall, Vector3.new(6.5, 2.6, 2.6), mo * CFrame.new(x, 1.3, -4), P.wood)
		for j = 0, 3 do
			Shapes.sphere(
				hall,
				Vector3.new(0.9, 0.9, 0.9),
				mo * CFrame.new(x - 2.2 + j * 1.5, 3, -4),
				({ rgb(230, 50, 60), rgb(250, 212, 60), rgb(246, 140, 40), rgb(80, 90, 200) })[(j + k) % 4 + 1]
			)
		end
		for j = 0, 4 do
			Shapes.part(
				hall,
				Vector3.new(1.3, 0.25, 3),
				mo * CFrame.new(x - 2.6 + j * 1.3, 5.6, -5.2) * CFrame.Angles(0.3, 0, 0),
				j % 2 == 0 and ({ P.awning, rgb(60, 150, 240), rgb(86, 192, 96) })[k + 1] or P.awningStripe
			)
		end
	end
	local board = Shapes.part(hall, Vector3.new(16, 6.5, 0.8), mo * CFrame.new(0, 5.2, 7.2), rgb(60, 50, 44))
	board.Name = "MarketBoard"
	Shapes.face(
		board,
		"MARKET ORDERS\nthree a day, from your stock",
		Enum.NormalId.Front,
		{ PixelsPerStud = 24, TextColor3 = P.cream }
	)
	local mp = Instance.new("ProximityPrompt")
	mp.Name = "Market"
	mp.ActionText = "Market orders"
	mp.ObjectText = "Town board"
	mp.MaxActivationDistance = 18
	mp.RequiresLineOfSight = false
	mp.Parent = board
	-- the boost tower (south): a plinth, the glass tube, rings, a star on top
	local mt = Layout.TOWN_SPOTS.meter
	Shapes.part(m, Vector3.new(18, 0.6, 18), CFrame.new(mt.x, 0.6, mt.z), P.concrete, { CanCollide = true })
	local plinth =
		Shapes.part(m, Vector3.new(14, 2.4, 14), CFrame.new(mt.x, 1.5, mt.z), P.steelDark, { CanCollide = true })
	plinth.Name = "MeterPlinth"
	local tube = Shapes.cylinder(
		m,
		Vector3.new(22, 5, 5),
		CFrame.new(mt.x, 13.7, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.glass
	)
	tube.Name = "MeterTube"
	tube.Transparency = 0.45
	local fill = Shapes.cylinder(
		m,
		Vector3.new(0.2, 4.2, 4.2),
		CFrame.new(mt.x, 2.8, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.accent
	)
	fill.Name = "MeterFill"
	fill.Material = Enum.Material.Neon
	for k = 1, 4 do
		Shapes.cylinder(
			m,
			Vector3.new(0.6, 6, 6),
			CFrame.new(mt.x, 2.7 + k * 5, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
			P.steelDark
		)
	end
	Shapes.cylinder(
		m,
		Vector3.new(1.2, 6.4, 6.4),
		CFrame.new(mt.x, 25.1, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.steelDark
	)
	Shapes.sphere(m, Vector3.new(3, 3, 3), CFrame.new(mt.x, 27.3, mt.z), P.safetyYellow).Material = Enum.Material.Neon
	Shapes.sign(m, CFrame.new(mt.x, 0.3, mt.z - 9.5), 12, 3, "SERVER BOOST", "chip in Cash: a boost for everyone", {
		name = "BoostSign",
		bottom = 1,
		accent = rgb(230, 130, 20),
	})
	local bp = Instance.new("ProximityPrompt")
	bp.Name = "Boost"
	bp.ActionText = "Server boost"
	bp.ObjectText = "Chip in"
	bp.MaxActivationDistance = 16
	bp.RequiresLineOfSight = false
	bp.Parent = plinth
	-- the visitors' spawn
	local sp = Layout.TOWN_SPOTS.spawn
	local spawn = Shapes.part(m, Vector3.new(10, 0.3, 10), CFrame.new(sp.x, 0.4, sp.z), rgb(196, 176, 142))
	spawn.Name = "TownSpawn"
	spawn.Material = Enum.Material.Cobblestone
end

function TownBuilder.build(parent)
	counter, nameIndex = 0, 0
	TownBuilder.world(parent)
	local m = Shapes.model(parent, "Town")
	city(m)
	courtyard(m)
	features(m)
	return m
end

return TownBuilder

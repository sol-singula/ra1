--[[
Builds a territory (master plan §4, §6, §9) from a profile's view: the ground, paths, fence, trees, the gate and
the pond once; the fields (the tiles you own, the outlines of the land you don't), the buildings (the business at
the front, the farmhouse, the machine shed, the warehouse and its docks, the silo), and the preview of the next
building (a blue footprint with its price) whenever they change. Everything is anchored parts in the territory's
local frame (World/Layout). Nothing overlaps: every zone has its own rectangle.

  TerritoryBuilder.build(parent, i, view)      the whole territory: a Model "T<i>" under workspace.Territories
  TerritoryBuilder.fields(model, i, view)
  TerritoryBuilder.buildings(model, i, view)
  TerritoryBuilder.preview(model, i, view)
  view = { stage, owned, tiles (the ids owned), name, prestige, docks, machine (tier), paint,
           next = { key, name, cost } | nil, fieldCosts }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(script.Parent.Layout)
local Models = require(script.Parent.Models)
local PenBuilder = require(script.Parent.PenBuilder)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local rgb = Color3.fromRGB
local TerritoryBuilder = {}

local function cf(i, x, z, y, yaw)
	return Layout.cframe(i, x, z, y, yaw)
end

-- Little things ----------------------------------------------------------------------------------------------------------
local function lamp(parent, o)
	Shapes.part(parent, Vector3.new(0.5, 9, 0.5), o * CFrame.new(0, 4.5, 0), P.steelDark)
	Shapes.part(parent, Vector3.new(1.6, 1, 1.6), o * CFrame.new(0, 9.4, 0), P.steelDark)
	local bulb = Shapes.part(parent, Vector3.new(1.2, 0.8, 1.2), o * CFrame.new(0, 9.2, 0), rgb(255, 240, 180))
	bulb.Material = Enum.Material.Neon
end

local function hayBale(parent, o)
	local b = Shapes.cylinder(parent, Vector3.new(3, 3.2, 3.2), o * CFrame.new(0, 1.6, 0), rgb(226, 196, 110))
	b.Material = Enum.Material.Grass
	Shapes.part(parent, Vector3.new(3.2, 0.3, 0.4), o * CFrame.new(0, 1.6, 1.62), rgb(170, 130, 70))
end

local function bush(parent, o, scale, color)
	scale = scale or 1
	local m = Shapes.model(parent, "Bush")
	Shapes.part(
		m,
		Vector3.new(2.6 * scale, 1.8 * scale, 2.6 * scale),
		o * CFrame.new(0, 0.9 * scale, 0),
		color or P.leaf
	)
	Shapes.part(
		m,
		Vector3.new(1.8 * scale, 1.4 * scale, 1.8 * scale),
		o * CFrame.new(0.4 * scale, 1.9 * scale, -0.3 * scale),
		(color or P.leaf):Lerp(Color3.new(1, 1, 1), 0.15)
	)
	return m
end

local function flowerBed(parent, o, w, d)
	Shapes.part(parent, Vector3.new(w, 0.6, d), o * CFrame.new(0, 0.3, 0), P.soilDark)
	local rng = Random.new(math.floor(o.Position.X * 7 + o.Position.Z))
	local colors = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(250, 120, 200), rgb(255, 150, 60), rgb(240, 240, 255) }
	for _ = 1, math.floor(w * d / 3) do
		local x = rng:NextNumber(-w / 2 + 0.5, w / 2 - 0.5)
		local z = rng:NextNumber(-d / 2 + 0.5, d / 2 - 0.5)
		Shapes.part(parent, Vector3.new(0.3, 0.8, 0.3), o * CFrame.new(x, 1, z), P.leaf)
		Shapes.ball(parent, Vector3.new(0.7, 0.7, 0.7), o * CFrame.new(x, 1.5, z), colors[rng:NextInteger(1, #colors)])
	end
end

local function scarecrow(parent, o)
	Shapes.part(parent, Vector3.new(0.4, 6, 0.4), o * CFrame.new(0, 3, 0), P.woodDark)
	Shapes.part(parent, Vector3.new(4, 0.4, 0.4), o * CFrame.new(0, 4.6, 0), P.woodDark)
	Shapes.part(parent, Vector3.new(1.6, 2, 0.8), o * CFrame.new(0, 4, 0), rgb(90, 130, 200))
	Shapes.part(parent, Vector3.new(1.1, 1.1, 1.1), o * CFrame.new(0, 5.6, 0), rgb(236, 200, 110))
	Shapes.cylinder(
		parent,
		Vector3.new(0.4, 2.2, 2.2),
		o * CFrame.new(0, 6.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(200, 150, 70)
	)
end

local function windmill(parent, o)
	local m = Shapes.model(parent, "Windmill")
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		Shapes.part(
			m,
			Vector3.new(0.6, 18, 0.6),
			o * CFrame.new(math.cos(a) * 2.6, 9, math.sin(a) * 2.6) * CFrame.Angles(0, -a, 0.12),
			P.steelDark
		)
	end
	Shapes.part(m, Vector3.new(3, 1, 3), o * CFrame.new(0, 18, 0), P.steelDark)
	local hub = Shapes.part(m, Vector3.new(1, 1, 1), o * CFrame.new(0, 18.5, 1.6), P.steel)
	hub.Name = "Hub"
	for k = 0, 7 do
		local a = k * math.pi / 4
		Shapes.part(
			m,
			Vector3.new(0.4, 5, 1.4),
			o * CFrame.new(0, 18.5, 1.8) * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.8, 0),
			rgb(240, 240, 240)
		)
	end
	Shapes.part(m, Vector3.new(1.2, 0.4, 4), o * CFrame.new(0, 18.5, -2.4), P.steelDark)
	return m
end

local function pond(parent, i)
	local s = Layout.SPOTS.pond
	local o = cf(i, s.x, s.z, 0)
	local water = Shapes.cylinder(
		parent,
		Vector3.new(0.5, 22, 22),
		o * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2),
		P.water
	)
	water.Transparency = 0.25
	water.Name = "Pond"
	Shapes.cylinder(
		parent,
		Vector3.new(0.3, 26, 26),
		o * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(200, 190, 150)
	)
	for k = 0, 7 do
		local a = k * math.pi / 4
		Shapes.ball(
			parent,
			Vector3.new(1.6, 1.2, 1.6),
			o * CFrame.new(math.cos(a) * 11.5, 0.5, math.sin(a) * 11.5),
			rgb(150, 150, 145)
		)
		if k % 2 == 0 then
			Shapes.part(
				parent,
				Vector3.new(0.3, 2.2, 0.3),
				o * CFrame.new(math.cos(a) * 9.5, 1.1, math.sin(a) * 9.5),
				P.grassDark
			)
		end
	end
	-- a little jetty
	Shapes.part(parent, Vector3.new(3, 0.4, 8), o * CFrame.new(0, 0.7, -12), P.wood)
	for _, z in { -9, -15 } do
		for _, x in { -1.2, 1.2 } do
			Shapes.part(parent, Vector3.new(0.5, 1.2, 0.5), o * CFrame.new(x, 0.4, z), P.woodDark)
		end
	end
end

-- Ground, paths, the fence, the gate, the yard, trees, the back garden ---------------------------------------------
local function ground(model, i, view)
	local g = Shapes.folder(model, "Ground")
	local W, D = Layout.WIDTH, Layout.DEPTH
	local hw, hd = W / 2, D / 2
	local fw, fd = Layout.FENCE.x, Layout.FENCE.z
	local plate = Shapes.part(g, Vector3.new(W, 2, D), cf(i, 0, 0, -1), P.grass, { CanCollide = true })
	plate.Name = "Plate"
	plate.Material = Enum.Material.Grass
	-- the front lawn right of the stand (the stock yard and the pens stand on it), a lighter green
	local lawn = Shapes.part(g, Vector3.new(56, 0.1, 28), cf(i, 48, -73, 0.03), P.grassLight)
	lawn.Material = Enum.Material.Grass
	-- the trucks' lane: from the avenue to the warehouse, kerbed, with dashes
	local ln = Layout.SPOTS.lane
	local lane = Shapes.part(g, Vector3.new(14, 0.3, 170), cf(i, ln.x, ln.z, 0.1), P.road)
	lane.Name = "Lane"
	lane.Material = Enum.Material.Asphalt
	for z = ln.z - 80, ln.z + 80, 10 do
		Shapes.part(g, Vector3.new(0.4, 0.05, 4), cf(i, ln.x, z, 0.28), P.roadLine)
	end
	Shapes.part(g, Vector3.new(0.8, 0.5, 170), cf(i, ln.x - 7.4, ln.z, 0.25), P.concrete)
	-- the paths
	local function path(x, z, w, d)
		local p = Shapes.part(g, Vector3.new(w, 0.2, d), cf(i, x, z, 0.08), P.path)
		p.Material = Enum.Material.Cobblestone
		return p
	end
	path(Layout.SPOTS.gate.x, -85, 10, 7) -- the gate into the yard
	path(8, -53.5, 136, 4.5) -- the cross path in front of the fields
	path(-15, -33.5, 6, 31) -- between the East and home fields
	path(14.25, -33.5, 6, 31) -- between the home and West fields
	path(-1, -14.5, 90, 4) -- behind the fields
	path(47.5, -14, 5, 76) -- out to the warehouse
	-- the frontage: a pavement in front of the stand, open to the avenue
	local front = Shapes.part(g, Vector3.new(36, 0.2, 10), cf(i, 0, -84, 0.06), P.concrete)
	front.Material = Enum.Material.Concrete
	-- the build yard: paved, kerbed, a sign
	local y = Layout.SPOTS.yard
	local yard = Shapes.part(g, Vector3.new(40, 0.25, 21), cf(i, y.x, y.z, 0.1), rgb(196, 176, 142))
	yard.Name = "Yard"
	yard.Material = Enum.Material.Cobblestone
	for _, side in { { y.x, y.z - 10.75, 40.6, 0.5 }, { y.x, y.z + 10.75, 40.6, 0.5 }, { y.x - 20.25, y.z, 0.5, 21 } } do
		Shapes.part(g, Vector3.new(side[3], 0.5, side[4]), cf(i, side[1], side[2], 0.25), P.woodDark)
	end
	Shapes.sign(g, cf(i, y.x - 21.5, y.z, 0, -math.pi / 2), 9, 2.6, "BUILD YARD", "step on a pad to buy it", {
		name = "YardSign",
		bottom = 1.2,
		accent = rgb(60, 140, 230),
	})
	-- the spawn, between the yard and the home field
	local sp = Layout.SPOTS.spawn
	local spawn = Shapes.part(g, Vector3.new(6, 0.3, 6), cf(i, sp.x, sp.z, 0.12), rgb(196, 176, 142))
	spawn.Name = "Spawn"
	spawn.Material = Enum.Material.Cobblestone
	-- the fence: posts and two rails; open at the gate, the stand's frontage and the lane (no post twice)
	local fence = Shapes.folder(g, "Fence")
	local function rail(x1, z1, x2, z2, first, last)
		local dx, dz = x2 - x1, z2 - z1
		local len = math.sqrt(dx * dx + dz * dz)
		local n = math.max(1, math.floor(len / 8))
		for k = first and 0 or 1, last and n or n - 1 do
			local t = k / n
			Shapes.part(fence, Vector3.new(0.6, 3.2, 0.6), cf(i, x1 + dx * t, z1 + dz * t, 1.6), P.white)
		end
		local mid = cf(i, (x1 + x2) / 2, (z1 + z2) / 2, 0)
		local yaw = math.atan2(dx, dz)
		for _, h in { 1.2, 2.5 } do
			Shapes.part(
				fence,
				Vector3.new(0.3, 0.45, len),
				mid * CFrame.new(0, h, 0) * CFrame.Angles(0, yaw, 0),
				P.white
			)
		end
	end
	local gx = Layout.SPOTS.gate.x
	rail(-fw, -fd, -fw, fd, true, false) -- left
	rail(-fw, fd, fw, fd, true, false) -- back
	rail(fw, fd, fw, -fd, true, true) -- right
	rail(-fw, -fd, gx - 11.2, -fd, false, false) -- front, left of the gate
	rail(gx + 11.2, -fd, -18, -fd, false, true) -- between the gate and the frontage
	rail(18, -fd, ln.x - 7.5, -fd, true, true) -- between the frontage and the lane
	rail(ln.x + 7.5, -fd, fw, -fd, true, false) -- right of the lane
	-- the gate: two brick pillars with lamps and the farm's name over them
	local stars = string.rep("★", math.min(view.prestige or 0, 6))
	local text = string.upper(view.name or "YOUR") .. " FARM" .. (stars ~= "" and (" " .. stars) or "")
	for _, dx in { -11.2, 11.2 } do
		local pillar = Shapes.part(g, Vector3.new(2.4, 9, 2.4), cf(i, gx + dx, -fd, 4.5), rgb(170, 110, 80))
		pillar.Material = Enum.Material.Brick
		Shapes.part(g, Vector3.new(3, 0.8, 3), cf(i, gx + dx, -fd, 9.3), P.concrete)
		Shapes.sphere(g, Vector3.new(1.6, 1.6, 1.6), cf(i, gx + dx, -fd, 10.3), rgb(255, 240, 180)).Material =
			Enum.Material.Neon
	end
	local _, arch = Shapes.sign(g, cf(i, gx, -fd, 0), 20, 3, text, nil, {
		name = "GateSign",
		posts = false,
		bottom = 9,
		board = P.woodDark,
		accent = P.cream,
	})
	arch.Name = "GateBoard"
	-- lamps along the cross path and the lane
	lamp(g, cf(i, -62, -57, 0))
	lamp(g, cf(i, 30, -57, 0))
	lamp(g, cf(i, ln.x - 9.5, -40, 0))
	lamp(g, cf(i, ln.x - 9.5, 40, 0))
	-- trees round the edges (none where the orchard and the windmill stand)
	local trees = Shapes.folder(g, "Trees")
	local rng = Random.new(i * 7919)
	for x = -40, 70, 14 do
		Shapes.tree(
			trees,
			cf(i, x + rng:NextNumber(-2, 2), hd - 6),
			1.05 + rng:NextNumber(-0.15, 0.2),
			rng:NextNumber() < 0.5 and P.leaf or P.grassDark
		)
	end
	for z = -76, 30, 14 do
		Shapes.tree(trees, cf(i, -hw + 6, z + rng:NextNumber(-2, 2)), 1 + rng:NextNumber(0, 0.25), P.leaf)
	end
	-- bushes along the front fence left of the gate; flower beds by the gate and on the lawn
	for x = -92, -60, 8 do
		bush(g, cf(i, x, -85), 0.9 + rng:NextNumber(0, 0.3))
	end
	flowerBed(g, cf(i, gx - 8, -85, 0), 4, 3)
	flowerBed(g, cf(i, gx + 8, -85, 0), 4, 3)
	-- the back garden: the pond, the windmill, hay bales by the North field, a scarecrow by the East field
	pond(g, i)
	windmill(g, cf(i, Layout.SPOTS.windmill.x, Layout.SPOTS.windmill.z, 0))
	for k = 0, 2 do
		hayBale(g, cf(i, 20 + k * 4, 2, 0, k * 0.3))
	end
	scarecrow(g, cf(i, Layout.SPOTS.scarecrow.x, Layout.SPOTS.scarecrow.z, 0))
	return g
end

-- The fields: owned tiles as soil, the rest as outlines with a sign ------------------------------------------------
function TerritoryBuilder.fields(model, i, view)
	local old = model:FindFirstChild("Fields")
	if old then
		old:Destroy()
	end
	local f = Shapes.folder(model, "Fields")
	local owned = {}
	for _, id in view.tiles or {} do
		owned[id] = true
	end
	for _, key in Layout.FIELD_LIST do
		local field = Layout.FIELDS[key]
		local cx, cz, w, d = Layout.fieldRect(key)
		local any = false
		for n = 1, field.tiles do
			local id = Layout.tileId(key, n)
			local x, z = Layout.tilePos(key, n)
			if owned[id] then
				any = true
				local tile = Shapes.part(f, Vector3.new(Layout.TILE, 0.5, Layout.TILE), cf(i, x, z, 0.15), P.soil)
				tile.Name = "Tile"
				tile.Material = Enum.Material.Ground
				tile:SetAttribute("Id", id)
				tile:SetAttribute("Territory", i)
				for k = -1, 1 do
					Shapes.part(f, Vector3.new(Layout.TILE - 0.4, 0.14, 0.35), cf(i, x, z + k * 1.2, 0.45), P.soilDark).Name =
						"Furrow"
				end
				Shapes.part(f, Vector3.new(Layout.TILE + 0.5, 0.3, Layout.TILE + 0.5), cf(i, x, z, 0.05), P.soilDark).Name =
					"Edge"
			elseif key == "field1" then
				local ghost = Shapes.part(f, Vector3.new(Layout.TILE, 0.15, Layout.TILE), cf(i, x, z, 0.1), P.grassDark)
				ghost.Name = "Soon"
				ghost.Transparency = 0.55
			end
		end
		if any or key == "field1" then
			-- a low wooden border and the field's name on a little sign in front
			local border = Shapes.folder(f, "Border")
			for _, side in
				{
					{ cx, cz - d / 2 - 0.6, w + 1.6, 0.5 },
					{ cx, cz + d / 2 + 0.6, w + 1.6, 0.5 },
					{ cx - w / 2 - 0.6, cz, 0.5, d + 1.6 },
					{ cx + w / 2 + 0.6, cz, 0.5, d + 1.6 },
				}
			do
				Shapes.part(border, Vector3.new(side[3], 0.5, side[4]), cf(i, side[1], side[2], 0.25), P.woodDark)
			end
			Shapes.sign(f, cf(i, cx, cz - d / 2 - 2.1, 0), 7, 1.5, Layout.FIELD_NAMES[key], nil, {
				name = "FieldSign",
				bottom = 0.5,
				accent = P.roofGreen,
			})
		else
			-- an expansion zone: its outline, corner posts and a sign (visible unused land, master plan §2)
			local zone = Shapes.part(f, Vector3.new(w, 0.12, d), cf(i, cx, cz, 0.07), P.grassLight)
			zone.Name = "Zone"
			zone.Transparency = 0.4
			zone:SetAttribute("Field", key)
			for _, dx in { -1, 1 } do
				for _, dz in { -1, 1 } do
					Shapes.part(f, Vector3.new(0.5, 1.6, 0.5), cf(i, cx + dx * w / 2, cz + dz * d / 2, 0.8), P.white)
				end
			end
			local cost = view.fieldCosts and view.fieldCosts[key]
			local s = Shapes.sign(
				f,
				cf(i, cx, cz, 0),
				10,
				3.2,
				Layout.FIELD_NAMES[key],
				`{field.tiles} tiles · {cost and Format.cash(cost) or ""} · buy it on a pad`,
				{
					name = "ZoneSign",
					bottom = 1,
					accent = rgb(60, 140, 230),
				}
			)
			s:SetAttribute("Field", key)
		end
	end
	return f
end

-- The buildings -------------------------------------------------------------------------------------------------------
local function awning(parent, origin, width, depth)
	local n = math.max(2, math.floor(width / 1.6))
	for k = 0, n - 1 do
		local c = k % 2 == 0 and P.awning or P.awningStripe
		Shapes.part(
			parent,
			Vector3.new(width / n, 0.25, depth),
			origin * CFrame.new(-width / 2 + (k + 0.5) * width / n, 0, 0) * CFrame.Angles(0.25, 0, 0),
			c
		)
	end
end

local FRUIT =
	{ rgb(230, 50, 60), rgb(236, 72, 48), rgb(250, 212, 60), rgb(246, 140, 40), rgb(80, 90, 200), rgb(70, 170, 80) }
local function crate(parent, o, color, full)
	Shapes.part(parent, Vector3.new(2, 1.4, 2), o * CFrame.new(0, 0.7, 0), P.wood)
	Shapes.part(parent, Vector3.new(2.1, 0.2, 2.1), o * CFrame.new(0, 1.0, 0), P.woodDark)
	if full ~= false then
		for k = 0, 3 do
			Shapes.ball(
				parent,
				Vector3.new(0.7, 0.7, 0.7),
				o * CFrame.new(-0.5 + (k % 2) * 1, 1.55, -0.5 + (k // 2) * 1),
				color or FRUIT[k + 1]
			)
		end
	end
end

local function stand(b, i)
	local s = Layout.SPOTS.stand
	local o = cf(i, s.x, s.z, 0)
	local m = Shapes.model(b, "Business")
	Shapes.part(m, Vector3.new(22, 0.2, 18), o * CFrame.new(0, 0.1, 0), P.path).Material = Enum.Material.Cobblestone
	local counter = Shapes.part(m, Vector3.new(12, 3, 2.6), o * CFrame.new(0, 1.5, -3), P.wood, { CanCollide = true })
	counter.Name = "Counter"
	Shapes.part(m, Vector3.new(12.4, 0.4, 3.2), o * CFrame.new(0, 3.2, -3), P.woodDark)
	for k = 0, 4 do
		crate(m, o * CFrame.new(-4.8 + k * 2.4, 3.4, -3), FRUIT[k + 1])
	end
	for _, x in { -5.6, 5.6 } do
		Shapes.part(m, Vector3.new(0.6, 8, 0.6), o * CFrame.new(x, 4, -4.6), P.woodDark)
		Shapes.part(m, Vector3.new(0.6, 8, 0.6), o * CFrame.new(x, 4, 3), P.woodDark)
	end
	awning(m, o * CFrame.new(0, 8.2, -1), 13, 9)
	Shapes.part(m, Vector3.new(13.4, 0.4, 0.5), o * CFrame.new(0, 7.3, -5.4), P.woodDark)
	-- the stock area behind the counter: crates, some empty, a barrow
	local stock = Shapes.folder(m, "StockArea")
	for k = 0, 3 do
		crate(stock, o * CFrame.new(-4.5 + k * 3, 0.2, 3.5), FRUIT[(k + 2) % 6 + 1], k < 2)
	end
	Shapes.part(stock, Vector3.new(2.2, 1.2, 3), o * CFrame.new(7, 1.2, 4), rgb(90, 130, 200))
	Shapes.cylinder(
		stock,
		Vector3.new(0.5, 1.4, 1.4),
		o * CFrame.new(7, 0.7, 5.6) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(40, 40, 44)
	)
	local sign = Shapes.part(m, Vector3.new(10, 2, 0.4), o * CFrame.new(0, 9.6, -5.2), P.cream)
	sign.Name = "Sign"
	Shapes.face(sign, "FRUIT STAND", Enum.NormalId.Front, { TextColor3 = P.barnRed, TextStrokeTransparency = 1 })
	local board =
		Shapes.part(m, Vector3.new(2.2, 3, 0.3), o * CFrame.new(8.5, 1.6, -7) * CFrame.Angles(0, -0.5, 0), P.woodDark)
	Shapes.face(
		board,
		"FRESH\nTODAY",
		Enum.NormalId.Front,
		{ PixelsPerStud = 40, TextColor3 = P.cream, TextStrokeTransparency = 1 }
	)
	for k = 1, 4 do
		Shapes.part(m, Vector3.new(1.4, 0.08, 1.4), o * CFrame.new(1.5, 0.22, -7 - k * 2.4), P.concrete)
	end
	return m
end

local function shop(b, i)
	local s = Layout.SPOTS.stand
	local o = cf(i, s.x, s.z + 4, 0)
	local m = Shapes.model(b, "Business")
	local W, D, H = 30, 18, 9
	local frame = rgb(70, 50, 40)
	Shapes.part(m, Vector3.new(W + 6, 0.2, 12), o * CFrame.new(0, 0.1, -D / 2 - 6), P.path).Material =
		Enum.Material.Cobblestone
	Shapes.part(m, Vector3.new(W, 0.6, D), o * CFrame.new(0, 0.3, 0), P.concrete, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.6, H, D), o * CFrame.new(-W / 2, H / 2, 0), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.6, H, D), o * CFrame.new(W / 2, H / 2, 0), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(W, H, 0.6), o * CFrame.new(0, H / 2, D / 2), P.cream, { CanCollide = true })
	for _, x in { -10, 10 } do
		Shapes.part(m, Vector3.new(10, H, 0.6), o * CFrame.new(x, H / 2, -D / 2), P.cream, { CanCollide = true })
		Shapes.part(m, Vector3.new(7.6, 5.2, 0.5), o * CFrame.new(x, 4.6, -D / 2 - 0.15), frame)
		Shapes.part(m, Vector3.new(7, 4.6, 0.3), o * CFrame.new(x, 4.6, -D / 2 - 0.3), P.glass)
		Shapes.part(m, Vector3.new(0.3, 4.6, 0.35), o * CFrame.new(x, 4.6, -D / 2 - 0.32), frame)
		Shapes.part(m, Vector3.new(7, 0.3, 0.35), o * CFrame.new(x, 4.6, -D / 2 - 0.32), frame)
		Shapes.part(m, Vector3.new(8.4, 1, 1.6), o * CFrame.new(x, 1.5, -D / 2 - 0.9), P.woodDark)
		for k = -2, 2 do
			Shapes.ball(
				m,
				Vector3.new(0.9, 0.9, 0.9),
				o * CFrame.new(x + k * 1.5, 2.3, -D / 2 - 0.9),
				({ rgb(255, 90, 90), rgb(255, 210, 60), rgb(250, 120, 200) })[(k + 2) % 3 + 1]
			)
		end
	end
	Shapes.part(m, Vector3.new(10, 2.5, 0.6), o * CFrame.new(0, H - 1.25, -D / 2), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.5, 7, 0.6), o * CFrame.new(-4.75, 3.5, -D / 2), frame)
	Shapes.part(m, Vector3.new(0.5, 7, 0.6), o * CFrame.new(4.75, 3.5, -D / 2), frame)
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 4.5, W / 2 + 1),
		o * CFrame.new(-W / 4 - 0.2, H + 2.25, 0) * CFrame.Angles(0, math.pi / 2, 0),
		P.roofGreen
	)
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 4.5, W / 2 + 1),
		o * CFrame.new(W / 4 + 0.2, H + 2.25, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		P.roofGreen
	)
	Shapes.part(m, Vector3.new(W + 2, 0.6, D + 2), o * CFrame.new(0, H + 0.3, 0), P.woodDark)
	Shapes.part(m, Vector3.new(2, 4, 2), o * CFrame.new(W / 2 - 5, H + 4, 3), rgb(150, 100, 80)).Material =
		Enum.Material.Brick
	awning(m, o * CFrame.new(0, 7.2, -D / 2 - 2.2), 28, 5)
	local counter = Shapes.part(m, Vector3.new(14, 2.8, 2), o * CFrame.new(0, 1.4, -3), P.wood)
	counter.Name = "Counter"
	Shapes.part(m, Vector3.new(2, 1.2, 1.2), o * CFrame.new(5, 3.4, -3), P.steelDark)
	for k = 0, 3 do
		for _, y in { 2, 4.6 } do
			Shapes.part(m, Vector3.new(6, 0.3, 1.4), o * CFrame.new(-10.5 + k * 7, y, D / 2 - 1.2), P.woodDark)
			for j = 0, 2 do
				Shapes.part(
					m,
					Vector3.new(1.4, 1.2, 1.1),
					o * CFrame.new(-12.5 + k * 7 + j * 2, y + 0.8, D / 2 - 1.2),
					FRUIT[(k + j + (y > 3 and 1 or 0)) % 6 + 1]
				)
			end
		end
	end
	local stock = Shapes.folder(m, "StockArea")
	for k = 0, 5 do
		crate(
			stock,
			o * CFrame.new(W / 2 - 2.4, 0.3 + (k // 3) * 1.6, -6 + (k % 3) * 2.6),
			FRUIT[k % 6 + 1],
			k % 2 == 0
		)
	end
	local sign = Shapes.part(m, Vector3.new(16, 2.4, 0.5), o * CFrame.new(0, H + 1.6, -D / 2 - 0.6), P.barnRed)
	sign.Name = "Sign"
	Shapes.face(sign, "FRUIT SHOP", Enum.NormalId.Front, { TextColor3 = P.white, TextStrokeTransparency = 1 })
	for k = -3, 3 do
		Shapes.ball(m, Vector3.new(0.5, 0.5, 0.5), o * CFrame.new(k * 2.5, H + 3, -D / 2 - 0.7), rgb(255, 240, 180)).Material =
			Enum.Material.Neon
	end
	Shapes.part(m, Vector3.new(5, 0.4, 1.4), o * CFrame.new(-W / 2 + 4, 1.4, -D / 2 - 4), P.wood)
	Shapes.part(m, Vector3.new(5, 1.6, 0.3), o * CFrame.new(-W / 2 + 4, 2.4, -D / 2 - 3.4), P.wood)
	Shapes.cylinder(
		m,
		Vector3.new(2.2, 1.6, 1.6),
		o * CFrame.new(W / 2 - 3, 1.1, -D / 2 - 4) * CFrame.Angles(0, 0, math.pi / 2),
		P.steelDark
	)
	for k = 1, 5 do
		Shapes.part(m, Vector3.new(1.4, 0.08, 1.4), o * CFrame.new(0, 0.22, -D / 2 - 2 - k * 2.4), P.concrete)
	end
	return m
end

local function house(b, i, view)
	local s = Layout.SPOTS.house
	local o = cf(i, s.x, s.z, 0)
	local m = Shapes.model(b, "House")
	local stage = view.stage
	local W, D, H = 14, 11, 7
	local wall, roof = P.wood, P.barnRed
	if stage == "shop" then
		W, D, H, wall, roof = 18, 13, 8, P.cream, P.roofGreen
	elseif stage == "warehouse" then
		W, D, H, wall, roof = 20, 14, 14, P.cream, P.roofBlue
	elseif stage == "center" then
		W, D, H, wall, roof = 24, 16, 16, rgb(222, 214, 200), rgb(80, 80, 90)
	end
	Shapes.part(m, Vector3.new(W + 4, 0.3, D + 6), o * CFrame.new(0, 0.15, -1), P.path).Material =
		Enum.Material.Cobblestone
	Shapes.part(m, Vector3.new(W, H, D), o * CFrame.new(0, H / 2 + 0.3, 0), wall, { CanCollide = true })
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 4, W / 2 + 1),
		o * CFrame.new(-W / 4 - 0.2, H + 2.3, 0) * CFrame.Angles(0, math.pi / 2, 0),
		roof
	)
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 4, W / 2 + 1),
		o * CFrame.new(W / 4 + 0.2, H + 2.3, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		roof
	)
	Shapes.part(m, Vector3.new(W + 2, 0.5, D + 2), o * CFrame.new(0, H + 0.55, 0), P.woodDark)
	Shapes.part(m, Vector3.new(2.6, 4.6, 0.4), o * CFrame.new(0, 2.6, -D / 2 - 0.1), P.woodDark)
	local rows = H > 10 and 2 or 1
	for r = 0, rows - 1 do
		for _, x in { -W / 2 + 4, W / 2 - 4 } do
			Shapes.part(m, Vector3.new(3, 2.6, 0.4), o * CFrame.new(x, 3.8 + r * 6, -D / 2 - 0.1), P.glass)
			Shapes.part(m, Vector3.new(3.4, 0.3, 0.5), o * CFrame.new(x, 2.4 + r * 6, -D / 2 - 0.2), P.woodDark)
		end
	end
	Shapes.part(m, Vector3.new(W - 2, 0.4, 4), o * CFrame.new(0, 0.6, -D / 2 - 2), P.wood)
	Shapes.part(m, Vector3.new(W - 2, 0.4, 4.4), o * CFrame.new(0, 5.6, -D / 2 - 2.2), roof)
	for _, x in { -W / 2 + 2, W / 2 - 2 } do
		Shapes.part(m, Vector3.new(0.5, 5.2, 0.5), o * CFrame.new(x, 3, -D / 2 - 3.8), P.woodDark)
	end
	Shapes.part(m, Vector3.new(1.8, 3, 1.8), o * CFrame.new(W / 2 - 3, H + 3.5, 2), rgb(150, 100, 80)).Material =
		Enum.Material.Brick
	if stage == "center" then
		Shapes.part(m, Vector3.new(5, 8, 5), o * CFrame.new(-W / 2 + 3, H + 4, D / 2 - 3), wall)
		Shapes.part(m, Vector3.new(0.3, 6, 0.3), o * CFrame.new(-W / 2 + 3, H + 11, D / 2 - 3), P.steelDark)
		Shapes.part(m, Vector3.new(3, 2, 0.2), o * CFrame.new(-W / 2 + 4.6, H + 13, D / 2 - 3), P.safetyYellow)
	end
	return m
end

local function warehouse(b, i, view)
	local s = Layout.SPOTS.warehouse
	local big = view.stage == "center"
	local W, D, H = big and 68 or 50, big and 44 or 34, big and 16 or 12
	if big then
		s = Layout.SPOTS.center
	end
	local o = cf(i, s.x, s.z, 0)
	local m = Shapes.model(b, "Warehouse")
	local wall = big and P.steel or P.concrete
	local yard = Shapes.part(m, Vector3.new(W + 10, 0.2, D + 10), o * CFrame.new(2, 0.1, 0), P.concrete)
	yard.Material = Enum.Material.Concrete
	Shapes.part(m, Vector3.new(W, 0.6, D), o * CFrame.new(0, 0.3, 0), P.concrete, { CanCollide = true })
	Shapes.part(m, Vector3.new(W, H, 0.8), o * CFrame.new(0, H / 2, D / 2), wall, { CanCollide = true })
	Shapes.part(m, Vector3.new(W, H, 0.8), o * CFrame.new(0, H / 2, -D / 2), wall, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.8, H, D), o * CFrame.new(-W / 2, H / 2, 0), wall, { CanCollide = true })
	for k = 1, math.floor(W / 6) - 1 do
		Shapes.part(
			m,
			Vector3.new(0.3, H - 1, 0.3),
			o * CFrame.new(-W / 2 + k * 6, H / 2, -D / 2 - 0.5),
			wall:Lerp(Color3.new(0, 0, 0), 0.12)
		)
	end
	Shapes.part(m, Vector3.new(W, 1.4, 0.3), o * CFrame.new(0, H - 2.2, -D / 2 - 0.5), P.safetyYellow)
	local docks = math.clamp(view.docks or 1, 1, big and 5 or 3) -- (the doors drawn: the rest are round the side)
	local pitch = D / (docks + 1)
	local door = math.min(7, pitch - 1.5)
	for k = 0, docks do
		local z0 = -D / 2 + k * pitch
		Shapes.part(
			m,
			Vector3.new(0.8, H, pitch - door),
			o * CFrame.new(W / 2, H / 2, z0 + pitch / 2),
			wall,
			{ CanCollide = true }
		)
	end
	Shapes.part(m, Vector3.new(0.8, H - 7, D), o * CFrame.new(W / 2, H - (H - 7) / 2, 0), wall)
	for k = 1, docks do
		local z = -D / 2 + k * pitch
		Shapes.part(m, Vector3.new(0.5, 1.6, door + 0.4), o * CFrame.new(W / 2 + 0.2, 7.3, z), P.safetyYellow)
		Shapes.part(m, Vector3.new(0.5, 0.5, door + 0.4), o * CFrame.new(W / 2 + 0.25, 6.4, z), rgb(30, 30, 34))
	end
	Shapes.part(m, Vector3.new(W + 2, 0.8, D + 2), o * CFrame.new(0, H + 0.4, 0), P.steelDark)
	for k = 1, 3 do
		Shapes.part(m, Vector3.new(W * 0.7, 0.6, 3), o * CFrame.new(0, H + 1, -D / 2 + k * D / 4), P.glass)
	end
	local platform =
		Shapes.part(m, Vector3.new(7, 1.2, D), o * CFrame.new(W / 2 + 3.5, 0.6, 0), P.concrete, { CanCollide = true })
	platform.Name = "Platform"
	for k = 1, docks do
		local z = -D / 2 + k * pitch
		local bay = Shapes.part(m, Vector3.new(6, 0.3, 5), o * CFrame.new(W / 2 + 3.5, 1.25, z), P.safetyYellow)
		bay.Name = "Dock"
		bay:SetAttribute("Index", k)
		Shapes.part(m, Vector3.new(0.5, 2.2, 5), o * CFrame.new(W / 2 + 7, 0.7, z), P.steelDark)
		for _, dz in { -3.5, 3.5 } do
			Shapes.cylinder(
				m,
				Vector3.new(2, 0.8, 0.8),
				o * CFrame.new(W / 2 + 7.4, 1.2, z + dz) * CFrame.Angles(0, 0, math.pi / 2),
				P.safetyYellow
			)
		end
	end
	local pallets = Shapes.folder(m, "Pallets")
	for k = 0, (big and 11 or 5) do
		Models.pallet(
			pallets,
			o * CFrame.new(-W / 2 + 5 + (k % 4) * 6, 0.6, -D / 2 + 5 + (k // 4) * 6),
			({ P.wood, P.barnRed, P.roofGreen })[k % 3 + 1]
		)
	end
	for k = 0, math.floor(W / 8) - 1 do
		Shapes.part(m, Vector3.new(6, 0.3, 2), o * CFrame.new(-W / 2 + 4 + k * 8, 4, D / 2 - 2), rgb(244, 116, 32))
		Shapes.part(m, Vector3.new(6, 0.3, 2), o * CFrame.new(-W / 2 + 4 + k * 8, 7.5, D / 2 - 2), rgb(244, 116, 32))
		Shapes.part(m, Vector3.new(0.3, 9, 0.3), o * CFrame.new(-W / 2 + 1 + k * 8, 4.5, D / 2 - 2), rgb(44, 96, 190))
	end
	Shapes.part(m, Vector3.new(10, 5, 6), o * CFrame.new(-W / 2 + 6, 2.8, -D / 2 - 4), P.cream)
	Shapes.part(m, Vector3.new(8, 2, 0.3), o * CFrame.new(-W / 2 + 6, 3.2, -D / 2 - 7.1), P.glass)
	local sign = Shapes.part(m, Vector3.new(W * 0.55, 3, 0.4), o * CFrame.new(4, H - 5, -D / 2 - 0.6), P.roofBlue)
	sign.Name = "Sign"
	Shapes.face(
		sign,
		big and "DISTRIBUTION CENTRE" or "WAREHOUSE",
		Enum.NormalId.Front,
		{ TextColor3 = P.white, TextStrokeTransparency = 1 }
	)
	if big then
		Shapes.cylinder(
			m,
			Vector3.new(D, 2, 2),
			o * CFrame.new(-W / 2 + 6, H - 3, 0) * CFrame.Angles(math.pi / 2, 0, 0),
			P.steel
		)
		Shapes.part(m, Vector3.new(4, 10, 4), o * CFrame.new(W / 2 - 4, H + 5, -D / 2 + 4), P.steelDark)
		Shapes.ball(m, Vector3.new(1.2, 1.2, 1.2), o * CFrame.new(W / 2 - 4, H + 10.6, -D / 2 + 4), rgb(255, 60, 60)).Material =
			Enum.Material.Neon
	end
	local si = Layout.SPOTS.silo
	for k = 0, 1 do
		local so = cf(i, si.x + k * 7, si.z, 0)
		Shapes.cylinder(m, Vector3.new(14, 5, 5), so * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.pi / 2), P.steel)
		Shapes.ball(m, Vector3.new(5, 3, 5), so * CFrame.new(0, 14.2, 0), P.steelDark)
		Shapes.part(m, Vector3.new(0.4, 14, 0.4), so * CFrame.new(2.6, 7, 0), P.steelDark)
	end
	return m
end

local function shed(b, i, view)
	local s = Layout.SPOTS.shed
	local o = cf(i, s.x, s.z, 0)
	local m = Shapes.model(b, "Shed")
	Shapes.part(m, Vector3.new(20, 0.4, 18), o * CFrame.new(0, 0.2, 0), P.concrete).Material = Enum.Material.Concrete
	for _, x in { -9.5, 9.5 } do
		for _, z in { -8.5, 8.5 } do
			Shapes.part(m, Vector3.new(0.7, 8, 0.7), o * CFrame.new(x, 4, z), P.woodDark)
		end
	end
	Shapes.wedge(m, Vector3.new(20, 3, 10), o * CFrame.new(0, 9.5, -5) * CFrame.Angles(0, math.pi, 0), P.barnRed)
	Shapes.wedge(m, Vector3.new(20, 3, 10), o * CFrame.new(0, 9.5, 5), P.barnRed)
	Shapes.part(m, Vector3.new(21, 0.5, 19), o * CFrame.new(0, 8.1, 0), P.woodDark)
	Shapes.part(m, Vector3.new(0.5, 8, 18), o * CFrame.new(10, 4, 0), P.wood)
	Shapes.part(m, Vector3.new(20, 8, 0.5), o * CFrame.new(0, 4, 9), P.wood)
	Shapes.cylinder(
		m,
		Vector3.new(5, 2.2, 2.2),
		o * CFrame.new(-7, 2.4, 6) * CFrame.Angles(0, math.pi / 2, 0),
		P.machineRed
	)
	for _, x in { -8.2, -5.8 } do
		Shapes.part(m, Vector3.new(0.5, 1.2, 0.5), o * CFrame.new(x, 0.8, 6), P.steelDark)
	end
	for k = 0, 2 do
		Shapes.part(m, Vector3.new(0.3, 3, 0.3), o * CFrame.new(5 + k * 1.5, 4.5, 8.6), P.woodDark)
	end
	if view.machine and view.machine > 0 then
		local tier = math.min(view.machine, 3)
		local mach = Models.machine(m, tier, view.paint or P.machineRed)
		mach.Name = "Machine"
		mach:PivotTo(o * CFrame.new(0, 0, -1))
		if view.machine >= 4 then
			local second = Models.machine(m, 3, view.paint or P.machineGreen)
			second.Name = "Machine2"
			second:PivotTo(cf(i, Layout.SPOTS.machine2.x, Layout.SPOTS.machine2.z, 0))
		end
	end
	local h = Layout.SPOTS.hay
	hayBale(m, cf(i, h.x - 2, h.z, 0))
	hayBale(m, cf(i, h.x + 2, h.z, 0, 0.4))
	return m
end

local function orchard(b, i)
	local s = Layout.SPOTS.orchard
	local m = Shapes.model(b, "Orchard")
	for r = 0, 1 do
		for c = 0, 3 do
			local o = cf(i, s.x - 12 + c * 8, s.z - 6 + r * 12, 0)
			Shapes.part(m, Vector3.new(1, 5, 1), o * CFrame.new(0, 2.5, 0), P.woodDark)
			Shapes.part(m, Vector3.new(5.5, 4.5, 5.5), o * CFrame.new(0, 6.5, 0), P.leaf)
			for k = 0, 5 do
				local a = k * 1.05
				Shapes.ball(
					m,
					Vector3.new(0.9, 0.9, 0.9),
					o * CFrame.new(math.cos(a) * 2.6, 6.2 + math.sin(a * 2), math.sin(a) * 2.6),
					rgb(255, 200, 40)
				)
			end
		end
	end
	return m
end

function TerritoryBuilder.buildings(model, i, view)
	local old = model:FindFirstChild("Buildings")
	if old then
		old:Destroy()
	end
	local b = Shapes.folder(model, "Buildings")
	if view.stage == "stand" then
		stand(b, i)
	else
		shop(b, i)
	end
	house(b, i, view)
	if view.stage == "warehouse" or view.stage == "center" then
		warehouse(b, i, view)
		local trucks = Shapes.folder(b, "Trucks")
		for k = 1, math.max(1, view.docks or 1) do
			local t = Models.truck(trucks, view.paint or P.truckWhite)
			t:SetAttribute("Index", k)
			t:PivotTo(cf(i, Layout.SPOTS.lane.x, 80 - (k - 1) * 15, 0))
		end
		Models.forklift(b):PivotTo(cf(i, Layout.SPOTS.warehouse.x + 8, Layout.SPOTS.warehouse.z - 8, 0.6))
	end
	if view.machine and view.machine > 0 then
		shed(b, i, view)
	end
	if view.owned and (view.owned.orchard or 0) > 0 then
		orchard(b, i)
	end
	return b
end

-- The preview of the next building (master plan §16): a blue footprint, corner posts, its sign and a Build prompt
function TerritoryBuilder.preview(model, i, view)
	local old = model:FindFirstChild("Preview")
	if old then
		old:Destroy()
	end
	if not view.next then
		return nil
	end
	local pv = Shapes.folder(model, "Preview")
	local key = view.next.key
	local spot, w, d, sign
	if key == "shop" then
		spot, w, d = { x = Layout.SPOTS.stand.x, z = Layout.SPOTS.stand.z + 4 }, 30, 18
		sign = { x = spot.x, z = spot.z + 12 }
	elseif key == "warehouse" then
		spot, w, d = Layout.SPOTS.warehouse, 50, 34
		sign = { x = spot.x, z = spot.z - d / 2 - 4 }
	elseif key == "center" then
		spot, w, d = Layout.SPOTS.center, 68, 44
		sign = { x = spot.x, z = spot.z - d / 2 - 4 }
	else
		spot, w, d = Layout.SPOTS.region, 8, 8
		sign = { x = spot.x, z = spot.z - 6 }
	end
	local o = cf(i, spot.x, spot.z, 0)
	local ghost = Shapes.part(pv, Vector3.new(w, 0.25, d), o * CFrame.new(0, 0.3, 0), P.preview)
	ghost.Name = "Ghost"
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.ForceField
	ghost:SetAttribute("Upgrade", key)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			local post =
				Shapes.part(pv, Vector3.new(0.6, 3, 0.6), o * CFrame.new(dx * w / 2, 1.5, dz * d / 2), P.preview)
			post.Material = Enum.Material.Neon
		end
	end
	local m, board = Shapes.sign(
		pv,
		cf(i, sign.x, sign.z, 0),
		11,
		3.4,
		"NEXT: " .. string.upper(view.next.name),
		Format.cash(view.next.cost) .. " · buy it on a pad",
		{
			name = "PreviewSign",
			bottom = 1.4,
			accent = rgb(40, 110, 200),
		}
	)
	m.Name = "PreviewSign"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Build"
	prompt.ActionText = "Build " .. view.next.name
	prompt.ObjectText = Format.cash(view.next.cost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Upgrade", key)
	prompt.Parent = board
	return pv
end

function TerritoryBuilder.build(parent, i, view)
	local model = Shapes.model(parent, "T" .. i)
	model:SetAttribute("Index", i)
	ground(model, i, view)
	TerritoryBuilder.fields(model, i, view)
	TerritoryBuilder.buildings(model, i, view)
	TerritoryBuilder.preview(model, i, view)
	PenBuilder.build(model, i, view)
	return model
end

-- An empty territory (nobody's yet)
function TerritoryBuilder.empty(parent, i)
	local model = Shapes.model(parent, "T" .. i)
	model:SetAttribute("Index", i)
	ground(model, i, { name = "FREE" })
	return model
end

return TerritoryBuilder

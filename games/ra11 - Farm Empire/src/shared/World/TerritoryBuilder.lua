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

-- Ground, paths, the fence, trees, the gate, the pond ---------------------------------------------------------------
local function ground(model, i, view)
	local g = Shapes.folder(model, "Ground")
	local W, D = Layout.WIDTH, Layout.DEPTH
	local hw, hd = W / 2, D / 2
	local plate = Shapes.part(g, Vector3.new(W, 2, D), cf(i, 0, 0, -1), P.grass, { CanCollide = true })
	plate.Name = "Plate"
	plate.Material = Enum.Material.Grass
	-- a lighter lawn round the house and along the front
	local lawn = Shapes.part(g, Vector3.new(60, 0.1, 40), cf(i, -64, -66, 0.03), P.grassLight)
	lawn.Material = Enum.Material.Grass
	-- the trucks' lane down the right edge, kerbed, with dashes
	local lane = Shapes.part(g, Vector3.new(16, 0.3, D), cf(i, Layout.SPOTS.lane.x, 0, 0.1), P.road)
	lane.Name = "Lane"
	lane.Material = Enum.Material.Asphalt
	for z = -hd + 8, hd - 8, 10 do
		Shapes.part(g, Vector3.new(0.4, 0.05, 4), cf(i, Layout.SPOTS.lane.x, z, 0.28), P.roadLine)
	end
	Shapes.part(g, Vector3.new(1, 0.6, D), cf(i, Layout.SPOTS.lane.x - 8.5, 0, 0.3), P.concrete)
	-- paths: the gate to the cross path, the cross path, between the fields, out to the shed and the warehouse
	local function path(x, z, w, d)
		local p = Shapes.part(g, Vector3.new(w, 0.2, d), cf(i, x, z, 0.08), P.path)
		p.Material = Enum.Material.Cobblestone
		return p
	end
	path(-16, -70, 6, 40) -- from the gate, left of the stand, up to the cross path
	path(-10, -48, 150, 6) -- the cross path along the front of the fields
	path(-48.5, -24, 5, 42) -- between the home and East fields
	path(-11.5, -24, 5, 42) -- between the East and West fields
	path(-28, -4, 90, 5) -- behind the three fields, in front of the North field
	path(40, -10, 6, 80) -- out past the shed to the warehouse
	path(36, 24, 60, 5) -- along the front of the warehouse
	-- the fence: posts and two rails, all round but the gate and the lane
	local fence = Shapes.folder(g, "Fence")
	local function rail(x1, z1, x2, z2)
		local dx, dz = x2 - x1, z2 - z1
		local len = math.sqrt(dx * dx + dz * dz)
		local n = math.max(1, math.floor(len / 8))
		for k = 0, n do
			local t = k / n
			Shapes.part(fence, Vector3.new(0.6, 3.2, 0.6), cf(i, x1 + dx * t, z1 + dz * t, 1.6), P.white)
		end
		local mid = cf(i, (x1 + x2) / 2, (z1 + z2) / 2, 0)
		local yaw = math.atan2(dx, dz)
		for _, y in { 1.2, 2.5 } do
			Shapes.part(
				fence,
				Vector3.new(0.3, 0.45, len),
				mid * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0),
				P.white
			)
		end
	end
	local fw, fd = hw - 1.5, hd - 1.5
	rail(-fw, -fd, -fw, fd)
	rail(-fw, fd, fw, fd)
	rail(fw, -fd, fw, fd)
	rail(-fw, -fd, -9, -fd)
	rail(9, -fd, Layout.SPOTS.lane.x - 9, -fd)
	-- the gate: two brick pillars and the arch with the farm's name
	local stars = string.rep("★", math.min(view.prestige or 0, 6))
	local text = string.upper(view.name or "YOUR") .. " FARM" .. (stars ~= "" and (" " .. stars) or "")
	for _, x in { -10, 10 } do
		local pillar = Shapes.part(g, Vector3.new(2.4, 9, 2.4), cf(i, x, -fd, 4.5), rgb(170, 110, 80))
		pillar.Material = Enum.Material.Brick
		Shapes.part(g, Vector3.new(3, 0.8, 3), cf(i, x, -fd, 9.3), P.concrete)
		Shapes.ball(g, Vector3.new(1.6, 1.6, 1.6), cf(i, x, -fd, 10.3), rgb(255, 240, 180)).Material =
			Enum.Material.Neon
	end
	local arch = Shapes.part(g, Vector3.new(22, 3, 1), cf(i, 0, -fd, 11.5), P.woodDark)
	arch.Name = "GateSign"
	Shapes.face(arch, text, Enum.NormalId.Front, { PixelsPerStud = 30 })
	Shapes.face(arch, text, Enum.NormalId.Back, { PixelsPerStud = 30 })
	-- the spawn, by the path at the left of the stand
	local spawn =
		Shapes.part(g, Vector3.new(6, 0.3, 6), cf(i, Layout.SPOTS.spawn.x, Layout.SPOTS.spawn.z, 0.12), P.path)
	spawn.Name = "Spawn"
	spawn.Material = Enum.Material.Cobblestone
	-- lamps along the cross path and the lane
	lamp(g, cf(i, -20, -52, 0))
	lamp(g, cf(i, 30, -52, 0))
	lamp(g, cf(i, Layout.SPOTS.lane.x - 10, -40, 0))
	lamp(g, cf(i, Layout.SPOTS.lane.x - 10, 40, 0))
	-- trees (scenic edges): the back, the left, a few by the front corners
	local trees = Shapes.folder(g, "Trees")
	local rng = Random.new(i * 7919)
	for x = -hw + 8, hw - 24, 13 do
		if x < Layout.SPOTS.lane.x - 14 then
			Shapes.tree(
				trees,
				cf(i, x + rng:NextNumber(-2, 2), hd - 6 + rng:NextNumber(-2, 1)),
				1.1 + rng:NextNumber(-0.2, 0.3),
				rng:NextNumber() < 0.5 and P.leaf or P.grassDark
			)
		end
	end
	for z = -hd + 10, hd - 20, 14 do
		Shapes.tree(
			trees,
			cf(i, -hw + 6 + rng:NextNumber(-1, 1), z + rng:NextNumber(-2, 2)),
			1 + rng:NextNumber(0, 0.3),
			P.leaf
		)
	end
	for _, x in { -hw + 20, -hw + 34 } do
		Shapes.tree(trees, cf(i, x, -hd + 8), 0.9, P.grassDark)
	end
	-- bushes and flowers along the front fence and by the spawn
	for x = -80, -20, 12 do
		bush(g, cf(i, x, -hd + 5), 0.9 + rng:NextNumber(0, 0.3))
	end
	flowerBed(g, cf(i, -26, -80, 0), 6, 3)
	flowerBed(g, cf(i, -42, -80, 0), 6, 3)
	-- the pond and the windmill at the back left, hay bales by the North field, a scarecrow by the home field
	pond(g, i)
	windmill(g, cf(i, -46, 66, 0))
	for k = 0, 2 do
		hayBale(g, cf(i, -16 + k * 4, 16, 0, k * 0.3))
	end
	scarecrow(g, cf(i, -78, -8, 0))
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
				local tile = Shapes.part(
					f,
					Vector3.new(Layout.TILE, 0.5, Layout.TILE),
					cf(i, x, z, 0.15),
					P.soil,
					{ CanCollide = false }
				)
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
		if any then
			-- a low wooden border and a name board
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
			Shapes.part(f, Vector3.new(0.4, 2.6, 0.4), cf(i, cx - w / 2 + 1.5, cz - d / 2 - 2.2, 1.3), P.woodDark)
			local board =
				Shapes.part(f, Vector3.new(5, 1.4, 0.3), cf(i, cx - w / 2 + 1.5, cz - d / 2 - 2.2, 2.9), P.wood)
			board.Name = "FieldSign"
			Shapes.face(
				board,
				Layout.FIELD_NAMES[key],
				Enum.NormalId.Front,
				{ PixelsPerStud = 40, TextStrokeTransparency = 1, TextColor3 = P.cream }
			)
		elseif key ~= "field1" then
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
			local post = Shapes.part(f, Vector3.new(0.5, 4, 0.5), cf(i, cx, cz, 2), P.woodDark)
			post.Name = "ZoneSign"
			post:SetAttribute("Field", key)
			local cost = view.fieldCosts and view.fieldCosts[key]
			Shapes.label(
				post,
				`{Layout.FIELD_NAMES[key]}: {field.tiles} TILES` .. (cost and ("\n" .. Format.cash(cost)) or ""),
				{ Size = UDim2.fromOffset(220, 60), StudsOffset = Vector3.new(0, 3, 0), MaxDistance = 60 }
			)
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
	Shapes.part(m, Vector3.new(W + 10, 0.2, D + 14), o * CFrame.new(0, 0.1, -3), P.path).Material =
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
	local o = cf(i, s.x - (big and 9 or 0), s.z, 0)
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
	local docks = math.max(1, view.docks or 1)
	local pitch = D / (docks + 1)
	for k = 0, docks do
		local z0 = -D / 2 + k * pitch
		Shapes.part(
			m,
			Vector3.new(0.8, H, pitch - 7),
			o * CFrame.new(W / 2, H / 2, z0 + pitch / 2),
			wall,
			{ CanCollide = true }
		)
	end
	Shapes.part(m, Vector3.new(0.8, H - 7, D), o * CFrame.new(W / 2, H - (H - 7) / 2, 0), wall)
	for k = 1, docks do
		local z = -D / 2 + k * pitch
		Shapes.part(m, Vector3.new(0.5, 1.6, 7.4), o * CFrame.new(W / 2 + 0.2, 7.3, z), P.safetyYellow)
		Shapes.part(m, Vector3.new(0.5, 0.5, 7.4), o * CFrame.new(W / 2 + 0.25, 6.4, z), rgb(30, 30, 34))
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
			second:PivotTo(cf(i, s.x - 18, s.z + 2, 0))
		end
	end
	hayBale(m, cf(i, s.x - 16, s.z - 6, 0))
	hayBale(m, cf(i, s.x - 16, s.z - 2.5, 0, 0.4))
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
			t:PivotTo(cf(i, Layout.SPOTS.lane.x, Layout.SPOTS.warehouse.z - 24 + k * 16, 0, math.pi))
		end
		Models.forklift(b):PivotTo(cf(i, Layout.SPOTS.warehouse.x + 8, Layout.SPOTS.warehouse.z - 8, 0.3))
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
	local o, w, d, signZ
	if key == "shop" then
		o, w, d, signZ = cf(i, Layout.SPOTS.stand.x, Layout.SPOTS.stand.z + 4, 0), 30, 18, 14
	elseif key == "warehouse" then
		o, w, d, signZ = cf(i, Layout.SPOTS.warehouse.x, Layout.SPOTS.warehouse.z, 0), 50, 34, -22
	elseif key == "center" then
		o, w, d, signZ = cf(i, Layout.SPOTS.warehouse.x - 9, Layout.SPOTS.warehouse.z, 0), 68, 44, -27
	else
		o, w, d, signZ = cf(i, Layout.SPOTS.gate.x + 18, Layout.SPOTS.gate.z + 8, 0), 6, 6, 0
	end
	local ghost = Shapes.part(pv, Vector3.new(w, 0.25, d), o * CFrame.new(0, 0.3, 0), P.preview)
	ghost.Name = "Ghost"
	ghost.Transparency = 0.5
	ghost.Material = Enum.Material.ForceField
	ghost.CanCollide = false
	ghost:SetAttribute("Upgrade", key)
	for _, dx in { -1, 1 } do
		for _, dz in { -1, 1 } do
			local post =
				Shapes.part(pv, Vector3.new(0.6, 3, 0.6), o * CFrame.new(dx * w / 2, 1.5, dz * d / 2), P.preview)
			post.Material = Enum.Material.Neon
		end
	end
	local post = Shapes.part(pv, Vector3.new(0.6, 5, 0.6), o * CFrame.new(0, 2.5, signZ), P.woodDark)
	post.Name = "PreviewSign"
	Shapes.label(post, `NEXT: {string.upper(view.next.name)}\n{Format.cash(view.next.cost)}`, {
		Size = UDim2.fromOffset(260, 70),
		StudsOffset = Vector3.new(0, 4, 0),
		MaxDistance = 110,
		TextColor3 = P.preview,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Build"
	prompt.ActionText = "Build " .. view.next.name
	prompt.ObjectText = Format.cash(view.next.cost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Upgrade", key)
	prompt.Parent = post
	return pv
end

function TerritoryBuilder.build(parent, i, view)
	local model = Shapes.model(parent, "T" .. i)
	model:SetAttribute("Index", i)
	ground(model, i, view)
	TerritoryBuilder.fields(model, i, view)
	TerritoryBuilder.buildings(model, i, view)
	TerritoryBuilder.preview(model, i, view)
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

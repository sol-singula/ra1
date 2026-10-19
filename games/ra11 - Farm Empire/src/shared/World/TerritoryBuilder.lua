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

-- Ground, paths, the fence, the gate, the yards, trees, the back garden ------------------------------------------
local function ground(model, i, view)
	local g = Shapes.folder(model, "Ground")
	local W, D = Layout.WIDTH, Layout.DEPTH
	local hw, hd = W / 2, D / 2
	local fw, fd = Layout.FENCE.x, Layout.FENCE.z
	local Z = Layout.ZONES
	local plate = Shapes.part(g, Vector3.new(W, 2, D), cf(i, 0, 0, -1), P.grass, { CanCollide = true })
	plate.Name = "Plate"
	plate.Material = Enum.Material.Grass
	local function slab(z, color, material, y, name)
		local p = Shapes.part(g, Vector3.new(z.w, 0.2, z.d), cf(i, z.cx, z.cz, y or 0.08), color)
		p.Material = material or Enum.Material.Concrete
		p.Name = name or "Slab"
		return p
	end
	-- the front: the customers' pavement, the truck yard (asphalt, dashes, kerbs), the pallet yard (painted bays)
	slab(Z.frontage, P.concrete, Enum.Material.Concrete, 0.06, "Frontage")
	local ty = slab(Z.truckYard, P.road, Enum.Material.Asphalt, 0.1, "TruckYard")
	_ = ty
	for z = Z.truckYard.cz - Z.truckYard.d / 2 + 6, Z.truckYard.cz + Z.truckYard.d / 2 - 6, 10 do
		Shapes.part(g, Vector3.new(0.4, 0.05, 4), cf(i, Z.truckYard.cx + 6, z, 0.23), P.roadLine)
	end
	for _, dx in { -1, 1 } do
		Shapes.part(
			g,
			Vector3.new(0.8, 0.5, Z.truckYard.d),
			cf(i, Z.truckYard.cx + dx * (Z.truckYard.w / 2 + 0.4), Z.truckYard.cz, 0.25),
			P.concrete
		)
	end
	local py = slab(Z.palletYard, P.concreteDark, Enum.Material.Concrete, 0.1, "PalletYard")
	_ = py
	for row = 0, 12 do
		Shapes.part(
			g,
			Vector3.new(Z.palletYard.w - 2, 0.05, 0.25),
			cf(i, Z.palletYard.cx, Z.palletYard.cz - 35.75 + row * 5.5, 0.23),
			P.safetyYellow
		)
	end
	Shapes.sign(
		g,
		cf(i, Z.palletYard.cx, Z.palletYard.cz - Z.palletYard.d / 2 - 1.5, 0),
		10,
		2.4,
		"PALLET YARD",
		"stock spills out here",
		{
			name = "PalletSign",
			bottom = 1.2,
			accent = rgb(200, 120, 30),
		}
	)
	-- the paths
	local function path(x, z, w, d)
		local p = Shapes.part(g, Vector3.new(w, 0.2, d), cf(i, x, z, 0.08), P.path)
		p.Material = Enum.Material.Cobblestone
		return p
	end
	local gx = Layout.SPOTS.gate.x
	path(gx, -169, 12, 18) -- the gate into the build yard
	path(gx, -115, 12, 10) -- the yard to the spawn
	path(0, -66, 300, 6) -- the cross path behind the building, in front of the fields
	path(-37.5, -35, 5, 50) -- between the East and home fields
	path(37.5, -35, 5, 50) -- between the home and West fields
	path(0, -2.5, 240, 5) -- behind the fields
	path(130, -35, 20, 5) -- out to the shed
	path(-130, -88, 8, 38) -- the spawn down to the cross path
	-- the build yard: paved, kerbed, a sign
	local y = Z.yard
	local yard = Shapes.part(g, Vector3.new(y.w, 0.25, y.d), cf(i, y.cx, y.cz, 0.1), rgb(196, 176, 142))
	yard.Name = "Yard"
	yard.Material = Enum.Material.Cobblestone
	for _, side in
		{
			{ y.cx, y.cz - y.d / 2 - 0.25, y.w + 1, 0.5 },
			{ y.cx - y.w / 2 - 0.25, y.cz, 0.5, y.d },
			{ y.cx + y.w / 2 + 0.25, y.cz, 0.5, y.d },
		}
	do
		Shapes.part(g, Vector3.new(side[3], 0.5, side[4]), cf(i, side[1], side[2], 0.25), P.woodDark)
	end
	Shapes.sign(
		g,
		cf(i, y.cx - y.w / 2 - 1.5, y.cz, 0, -math.pi / 2),
		10,
		2.8,
		"BUILD YARD",
		"step on a pad to buy it",
		{
			name = "YardSign",
			bottom = 1.2,
			accent = rgb(60, 140, 230),
		}
	)
	-- the spawn, behind the yard
	local sp = Layout.SPOTS.spawn
	local spawn = Shapes.part(g, Vector3.new(8, 0.3, 8), cf(i, sp.x, sp.z, 0.12), rgb(196, 176, 142))
	spawn.Name = "Spawn"
	spawn.Material = Enum.Material.Cobblestone
	-- the fence: posts and two rails; open at the gate, the frontage and the truck yard (no post twice)
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
	local tyx0, tyx1 = Z.truckYard.cx - Z.truckYard.w / 2, Z.truckYard.cx + Z.truckYard.w / 2
	local fx0, fx1 = Z.frontage.cx - Z.frontage.w / 2, Z.frontage.cx + Z.frontage.w / 2
	rail(-fw, -fd, -fw, fd, true, false) -- left
	rail(-fw, fd, fw, fd, true, false) -- back
	rail(fw, fd, fw, -fd, true, true) -- right
	rail(-fw, -fd, gx - 11.2, -fd, false, false) -- front, left of the gate
	rail(gx + 11.2, -fd, fx0, -fd, false, true) -- between the gate and the frontage
	rail(fx1, -fd, tyx0, -fd, true, true) -- between the frontage and the truck yard
	rail(tyx1, -fd, fw, -fd, true, false) -- right of the truck yard
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
	-- lamps along the cross path
	for x = -140, 140, 40 do
		lamp(g, cf(i, x, -70, 0))
	end
	-- trees round the edges (none where the orchard and the windmill stand)
	local trees = Shapes.folder(g, "Trees")
	local rng = Random.new(i * 7919)
	for x = -60, 190, 16 do
		Shapes.tree(
			trees,
			cf(i, x + rng:NextNumber(-2, 2), hd - 7),
			1.1 + rng:NextNumber(-0.15, 0.25),
			rng:NextNumber() < 0.5 and P.leaf or P.grassDark
		)
	end
	for z = -95, 80, 16 do
		Shapes.tree(trees, cf(i, -hw + 7, z + rng:NextNumber(-2, 2)), 1.05 + rng:NextNumber(0, 0.3), P.leaf)
		Shapes.tree(trees, cf(i, hw - 7, z + 60 + rng:NextNumber(-2, 2)), 1.05 + rng:NextNumber(0, 0.3), P.grassDark)
	end
	-- bushes along the front fence left of the gate; flower beds by the gate
	for x = -190, -150, 8 do
		bush(g, cf(i, x, -174), 0.9 + rng:NextNumber(0, 0.3))
	end
	flowerBed(g, cf(i, gx - 9, -174, 0), 4, 3)
	flowerBed(g, cf(i, gx + 9, -174, 0), 4, 3)
	-- the back garden: the pond, the windmill, hay bales by the North field, a scarecrow by the East field
	pond(g, i)
	windmill(g, cf(i, Layout.SPOTS.windmill.x, Layout.SPOTS.windmill.z, 0))
	for k = 0, 2 do
		hayBale(g, cf(i, 90 + k * 4, 45, 0, k * 0.3))
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

-- The walls of the business building at a stage: a front with the storefront, the sides, the back with big doors
-- open onto the farm (doors = how many, each doorW wide), all solid where they're wall
local function shell(m, o, W, D, H, wall, doors, doorW, doorH)
	Shapes.part(m, Vector3.new(W, 0.6, D), o * CFrame.new(0, 0.3, 0), P.concrete, { CanCollide = true }).Name = "Floor"
	Shapes.part(m, Vector3.new(0.8, H, D), o * CFrame.new(-W / 2, H / 2, 0), wall, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.8, H, D), o * CFrame.new(W / 2, H / 2, 0), wall, { CanCollide = true })
	-- the back wall: piers between the open doors, a lintel over them, a striped frame round each
	local pitch = W / doors
	for k = 0, doors do
		local x0 = -W / 2 + k * pitch
		local pier = k == 0 and (pitch - doorW) / 2 or (k == doors and (pitch - doorW) / 2 or pitch - doorW)
		local cx = k == 0 and -W / 2 + pier / 2 or (k == doors and W / 2 - pier / 2 or x0)
		Shapes.part(m, Vector3.new(pier, H, 0.8), o * CFrame.new(cx, H / 2, D / 2), wall, { CanCollide = true })
	end
	Shapes.part(
		m,
		Vector3.new(W, H - doorH, 0.8),
		o * CFrame.new(0, doorH + (H - doorH) / 2, D / 2),
		wall,
		{ CanCollide = true }
	)
	for k = 1, doors do
		local x = -W / 2 + (k - 0.5) * pitch
		Shapes.part(m, Vector3.new(doorW + 1, 0.8, 1), o * CFrame.new(x, doorH + 0.4, D / 2 + 0.2), P.safetyYellow)
		for _, side in { -1, 1 } do
			Shapes.part(
				m,
				Vector3.new(0.6, doorH, 1),
				o * CFrame.new(x + side * (doorW / 2 + 0.2), doorH / 2, D / 2 + 0.2),
				P.safetyYellow
			)
		end
		-- the rolled-up door in its drum over the opening
		Shapes.cylinder(m, Vector3.new(doorW, 1.6, 1.6), o * CFrame.new(x, doorH + 1.6, D / 2 - 0.6), P.steelDark)
	end
end

-- The shop: the stand grown into a building where it stood, shelves inside, double doors at the back
local function shop(b, i)
	local x0, z0, B = Layout.building("shop")
	local o = cf(i, x0, z0, 0)
	local m = Shapes.model(b, "Business")
	local W, D, H = B.w, B.d, B.h
	local frame = rgb(70, 50, 40)
	shell(m, o, W, D, H, P.cream, 1, 12, 7.5)
	-- the front: two big windows, the entrance between them
	for _, x in { -12, 12 } do
		Shapes.part(m, Vector3.new(16, H, 0.6), o * CFrame.new(x, H / 2, -D / 2), P.cream, { CanCollide = true })
		Shapes.part(m, Vector3.new(11.6, 5.2, 0.5), o * CFrame.new(x, 4.6, -D / 2 - 0.15), frame)
		Shapes.part(m, Vector3.new(11, 4.6, 0.3), o * CFrame.new(x, 4.6, -D / 2 - 0.3), P.glass)
		Shapes.part(m, Vector3.new(0.3, 4.6, 0.35), o * CFrame.new(x, 4.6, -D / 2 - 0.32), frame)
		Shapes.part(m, Vector3.new(12.4, 1, 1.6), o * CFrame.new(x, 1.5, -D / 2 - 0.9), P.woodDark)
		for k = -3, 3 do
			Shapes.ball(
				m,
				Vector3.new(0.9, 0.9, 0.9),
				o * CFrame.new(x + k * 1.6, 2.3, -D / 2 - 0.9),
				({ rgb(255, 90, 90), rgb(255, 210, 60), rgb(250, 120, 200) })[(k + 3) % 3 + 1]
			)
		end
	end
	Shapes.part(
		m,
		Vector3.new(8, H - 7, 0.6),
		o * CFrame.new(0, 7 + (H - 7) / 2, -D / 2),
		P.cream,
		{ CanCollide = true }
	)
	for _, x in { -4, 4 } do
		Shapes.part(m, Vector3.new(0.5, 7, 0.6), o * CFrame.new(x, 3.5, -D / 2), frame)
	end
	-- the roof: a green gable over a dark band
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 5, W / 2 + 1),
		o * CFrame.new(-W / 4 - 0.2, H + 2.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
		P.roofGreen
	)
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 5, W / 2 + 1),
		o * CFrame.new(W / 4 + 0.2, H + 2.5, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		P.roofGreen
	)
	Shapes.part(m, Vector3.new(W + 2, 0.6, D + 2), o * CFrame.new(0, H + 0.3, 0), P.woodDark)
	awning(m, o * CFrame.new(0, 7.6, -D / 2 - 2.2), W - 2, 5)
	local counter = Shapes.part(m, Vector3.new(14, 2.8, 2), o * CFrame.new(0, 1.4, -D / 2 + 4), P.wood)
	counter.Name = "Counter"
	Shapes.part(m, Vector3.new(2, 1.2, 1.2), o * CFrame.new(5, 3.4, -D / 2 + 4), P.steelDark)
	-- the shelves along the back, either side of the doors (StockController fills them)
	for _, side in { -1, 1 } do
		for _, y in { 0.5, 2.7 } do
			for row = 0, 1 do
				Shapes.part(
					m,
					Vector3.new(12.4, 0.2, 2),
					o * CFrame.new(side * 12.3, y, D / 2 - 2.2 - row * 2.4),
					P.woodDark
				)
			end
		end
	end
	local sign = Shapes.part(m, Vector3.new(18, 2.4, 0.5), o * CFrame.new(0, H + 1.6, -D / 2 - 0.6), P.barnRed)
	sign.Name = "Sign"
	Shapes.face(sign, "FRUIT SHOP", Enum.NormalId.Front, { TextColor3 = P.white, TextStrokeTransparency = 1 })
	for k = -3, 3 do
		Shapes.ball(m, Vector3.new(0.5, 0.5, 0.5), o * CFrame.new(k * 2.6, H + 3, -D / 2 - 0.7), rgb(255, 240, 180)).Material =
			Enum.Material.Neon
	end
	Shapes.part(m, Vector3.new(5, 0.4, 1.4), o * CFrame.new(-W / 2 + 4, 1.4, -D / 2 - 4), P.wood)
	Shapes.part(m, Vector3.new(5, 1.6, 0.3), o * CFrame.new(-W / 2 + 4, 2.4, -D / 2 - 3.4), P.wood)
	return m
end

-- The warehouse (and the distribution centre): the shop grown into a great shed where it stood. The storefront and
-- counter at the front, racks inside (StockController fills them; the pallet yard outside takes the rest), three
-- big doors open at the back onto the farm, the loading docks on the right wall over the truck yard.
local function warehouse(b, i, view)
	local big = view.stage == "center"
	local x0, z0, B = Layout.building(view.stage)
	local W, D, H = B.w, B.d, B.h
	local o = cf(i, x0, z0, 0)
	local m = Shapes.model(b, "Business")
	m:SetAttribute("Warehouse", true)
	local wall = big and P.steel or P.concrete
	local frame = rgb(60, 64, 72)
	-- the shell: the side walls, the back with its doors; the right wall is built with the docks below
	Shapes.part(m, Vector3.new(W, 0.6, D), o * CFrame.new(0, 0.3, 0), P.concrete, { CanCollide = true }).Name = "Floor"
	Shapes.part(m, Vector3.new(0.8, H, D), o * CFrame.new(-W / 2, H / 2, 0), wall, { CanCollide = true })
	local doors, doorW, doorH = 3, big and 22 or 18, big and 15 or 13
	local pitch = W / doors
	for k = 0, doors do
		local pier = (k == 0 or k == doors) and (pitch - doorW) / 2 or pitch - doorW
		local cx = k == 0 and -W / 2 + pier / 2 or (k == doors and W / 2 - pier / 2 or -W / 2 + k * pitch)
		Shapes.part(m, Vector3.new(pier, H, 0.8), o * CFrame.new(cx, H / 2, D / 2), wall, { CanCollide = true })
	end
	Shapes.part(
		m,
		Vector3.new(W, H - doorH, 0.8),
		o * CFrame.new(0, doorH + (H - doorH) / 2, D / 2),
		wall,
		{ CanCollide = true }
	)
	for k = 1, doors do
		local x = -W / 2 + (k - 0.5) * pitch
		Shapes.part(m, Vector3.new(doorW + 1.2, 1, 1), o * CFrame.new(x, doorH + 0.5, D / 2 + 0.2), P.safetyYellow)
		for _, side in { -1, 1 } do
			Shapes.part(
				m,
				Vector3.new(0.8, doorH, 1),
				o * CFrame.new(x + side * (doorW / 2 + 0.2), doorH / 2, D / 2 + 0.2),
				P.safetyYellow
			)
		end
		Shapes.cylinder(m, Vector3.new(doorW, 2, 2), o * CFrame.new(x, doorH + 2, D / 2 - 0.8), P.steelDark)
	end
	-- the front: the storefront (glass between steel posts), the entrance, the counter inside
	for _, x in { -W / 4 - 4, W / 4 + 4 } do
		local w = W / 2 - 14
		Shapes.part(m, Vector3.new(w, 3, 0.8), o * CFrame.new(x, 1.5, -D / 2), wall, { CanCollide = true })
		local glass =
			Shapes.part(m, Vector3.new(w, 7, 0.4), o * CFrame.new(x, 6.5, -D / 2), P.glass, { CanCollide = true })
		glass.Transparency = 0.35
		for k = 0, math.floor(w / 6) do
			Shapes.part(
				m,
				Vector3.new(0.5, 7, 0.6),
				o * CFrame.new(x - w / 2 + k * w / math.floor(w / 6), 6.5, -D / 2),
				frame
			)
		end
	end
	Shapes.part(
		m,
		Vector3.new(W, H - 10, 0.8),
		o * CFrame.new(0, 10 + (H - 10) / 2, -D / 2),
		wall,
		{ CanCollide = true }
	)
	for _, x in { -6, 6 } do
		Shapes.part(m, Vector3.new(0.8, 10, 0.9), o * CFrame.new(x, 5, -D / 2), frame)
	end
	Shapes.part(m, Vector3.new(W + 0.4, 1.4, 0.3), o * CFrame.new(0, 10.8, -D / 2 - 0.5), P.safetyYellow)
	awning(m, o * CFrame.new(0, 9.4, -D / 2 - 2.4), 14, 5)
	local counter = Shapes.part(m, Vector3.new(16, 2.8, 2), o * CFrame.new(0, 1.4, -D / 2 + 5), P.wood)
	counter.Name = "Counter"
	Shapes.part(m, Vector3.new(2, 1.2, 1.2), o * CFrame.new(6, 3.4, -D / 2 + 5), P.steelDark)
	-- the right wall over the truck yard: the dock doors
	local docks = math.clamp(view.docks or 1, 1, big and 6 or 4)
	local dpitch = (D - 20) / docks
	local ddoor = math.min(9, dpitch - 2)
	local dz0 = -D / 2 + 16
	Shapes.part(m, Vector3.new(0.8, H, 16), o * CFrame.new(W / 2, H / 2, -D / 2 + 8), wall, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.8, H, 4), o * CFrame.new(W / 2, H / 2, D / 2 - 2), wall, { CanCollide = true })
	for k = 0, docks - 1 do
		local zc = dz0 + (k + 0.5) * dpitch
		for _, side in { -1, 1 } do
			local pz = zc + side * (ddoor / 2 + (dpitch - ddoor) / 4)
			Shapes.part(
				m,
				Vector3.new(0.8, H, (dpitch - ddoor) / 2),
				o * CFrame.new(W / 2, H / 2, pz),
				wall,
				{ CanCollide = true }
			)
		end
		Shapes.part(m, Vector3.new(0.8, H - 9, ddoor), o * CFrame.new(W / 2, 9 + (H - 9) / 2, zc), wall)
		Shapes.part(m, Vector3.new(0.5, 1.4, ddoor + 0.4), o * CFrame.new(W / 2 + 0.3, 9.7, zc), P.safetyYellow)
		local bay = Shapes.part(m, Vector3.new(6, 0.3, ddoor), o * CFrame.new(W / 2 + 3.4, 1.35, zc), P.safetyYellow)
		bay.Name = "Dock"
		bay:SetAttribute("Index", k + 1)
		Shapes.part(m, Vector3.new(0.5, 2.2, ddoor), o * CFrame.new(W / 2 + 6.6, 1.1, zc), P.steelDark)
	end
	local platform = Shapes.part(
		m,
		Vector3.new(6.4, 1.2, D - 18),
		o * CFrame.new(W / 2 + 3.6, 0.6, 2),
		P.concrete,
		{ CanCollide = true }
	)
	platform.Name = "Platform"
	-- the racks: uprights and beams down each row (the pallets on them are StockController's)
	for _, r in Layout.racks(view.stage) do
		local len = r.x1 - r.x0 + Layout.PALLET + 1
		local cx = (r.x0 + r.x1) / 2
		for level = 1, r.levels do
			for _, dz in { -1.9, 1.9 } do
				Shapes.part(
					m,
					Vector3.new(len, 0.3, 0.3),
					cf(i, cx, r.z + dz, 0.45 + level * 4.2 - 0.3),
					rgb(244, 116, 32)
				)
			end
		end
		for x = r.x0 - 2.2, r.x1 + 2.3, 8.8 do
			for _, dz in { -1.9, 1.9 } do
				Shapes.part(
					m,
					Vector3.new(0.35, r.levels * 4.2 + 0.6, 0.35),
					cf(i, x, r.z + dz, (r.levels * 4.2 + 0.6) / 2 + 0.6),
					rgb(44, 96, 190)
				)
			end
		end
	end
	-- the roof: a dark steel lid with skylights (light falls on the racks)
	Shapes.part(m, Vector3.new(W + 2, 0.8, D + 2), o * CFrame.new(0, H + 0.4, 0), P.steelDark)
	for k = 1, 4 do
		local sky = Shapes.part(m, Vector3.new(W * 0.8, 0.6, 3), o * CFrame.new(0, H + 1, -D / 2 + k * D / 5), P.glass)
		sky.Transparency = 0.3
	end
	local sign = Shapes.part(m, Vector3.new(W * 0.5, 4, 0.5), o * CFrame.new(0, H - 3, -D / 2 - 0.6), P.roofBlue)
	sign.Name = "Sign"
	Shapes.face(
		sign,
		big and "DISTRIBUTION CENTRE" or "WAREHOUSE",
		Enum.NormalId.Front,
		{ TextColor3 = P.white, TextStrokeTransparency = 1 }
	)
	if big then
		Shapes.part(m, Vector3.new(4, 10, 4), o * CFrame.new(W / 2 - 4, H + 5, -D / 2 + 4), P.steelDark)
		Shapes.ball(m, Vector3.new(1.2, 1.2, 1.2), o * CFrame.new(W / 2 - 4, H + 10.6, -D / 2 + 4), rgb(255, 60, 60)).Material =
			Enum.Material.Neon
	end
	return m
end

-- The silos at the back (warehouse and up)
local function silos(b, i)
	local m = Shapes.model(b, "Silos")
	local si = Layout.SPOTS.silo
	for k = 0, 1 do
		local so = cf(i, si.x + k * 7, si.z, 0)
		Shapes.cylinder(m, Vector3.new(14, 5, 5), so * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.pi / 2), P.steel)
		Shapes.ball(m, Vector3.new(5, 3, 5), so * CFrame.new(0, 14.2, 0), P.steelDark)
		Shapes.part(m, Vector3.new(0.4, 14, 0.4), so * CFrame.new(2.6, 7, 0), P.steelDark)
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
	-- the business: one building at the front that grows where it stands
	if view.stage == "stand" then
		stand(b, i)
	elseif view.stage == "shop" then
		shop(b, i)
	else
		local m = warehouse(b, i, view)
		local _, _, B = Layout.building(view.stage)
		local trucks = Shapes.folder(b, "Trucks")
		-- a truck backed up to every dock, nose to the avenue side of the yard
		for _, d in m:GetChildren() do
			if d.Name == "Dock" then
				local t = Models.truck(trucks, view.paint or P.truckWhite)
				t:SetAttribute("Index", d:GetAttribute("Index"))
				local _, lz = Layout.toLocal(i, d.Position)
				t:PivotTo(cf(i, B.w / 2 + 14, lz, 0, -math.pi / 2))
			end
		end
		local fork = Models.forklift(b)
		fork:PivotTo(cf(i, -10, Layout.FRONT_Z + 18, 0.6))
		silos(b, i)
	end
	house(b, i, view)
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
	if Layout.BUILDING[key] then
		-- the next stage of the business: its footprint where it will stand (the building grows in place)
		local x, z, B = Layout.building(key)
		spot, w, d = { x = x, z = z }, B.w, B.d
		sign = { x = -B.w / 2 - 6, z = Layout.FRONT_Z - 4 }
		if key == "shop" then
			sign = { x = -B.w / 2 - 6, z = Layout.FRONT_Z + 4 }
		end
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

--[[
Builds a territory (master plan §4, §6, §9) from a profile's view: the ground and the fence once; the fields (the
tiles you own, the outlines of the land you don't), the buildings (the business at the front, the machine shed,
the warehouse and its docks), and the preview of the next building (a blue ghost with its price) whenever they
change. Everything is anchored parts in the territory's local frame (World/Layout).

  TerritoryBuilder.build(i, view)      the whole territory: a Model "T<i>" under workspace.Territories
  TerritoryBuilder.fields(model, i, view)
  TerritoryBuilder.buildings(model, i, view)
  TerritoryBuilder.preview(model, i, view)
  view = { stage, owned, tiles (the ids owned), name, docks, machine (tier), next = { key, name, cost } | nil }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(script.Parent.Layout)
local Models = require(script.Parent.Models)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local TerritoryBuilder = {}

local function cf(i, x, z, y, yaw)
	return Layout.cframe(i, x, z, y, yaw)
end

-- Ground, paths, the fence and the trees -----------------------------------------------------------------------------
local function ground(model, i, view)
	local g = Shapes.folder(model, "Ground")
	local W, D = Layout.WIDTH, Layout.DEPTH
	local plate = Shapes.part(g, Vector3.new(W, 2, D), cf(i, 0, 0, -1), P.grass, { CanCollide = true })
	plate.Name = "Plate"
	plate.Material = Enum.Material.Grass
	-- the trucks' lane down the right side, from the avenue to the back
	Shapes.part(g, Vector3.new(12, 0.2, D - 4), cf(i, Layout.SPOTS.lane.x, 2, 0.05), P.road).Name = "Lane"
	-- a path from the gate past the stand to the fields
	Shapes.part(g, Vector3.new(6, 0.2, 34), cf(i, -12, -40, 0.06), P.path)
	Shapes.part(g, Vector3.new(60, 0.2, 5), cf(i, 0, -33, 0.06), P.path)
	-- the fence: posts and two rails, all round but the front
	local fence = Shapes.folder(g, "Fence")
	local function rail(x1, z1, x2, z2)
		local dx, dz = x2 - x1, z2 - z1
		local len = math.sqrt(dx * dx + dz * dz)
		local n = math.max(1, math.floor(len / 8))
		for k = 0, n do
			local t = k / n
			Shapes.part(fence, Vector3.new(0.6, 3, 0.6), cf(i, x1 + dx * t, z1 + dz * t, 1.5), P.white)
		end
		local mid = cf(i, (x1 + x2) / 2, (z1 + z2) / 2, 0)
		local yaw = math.atan2(dx, dz)
		for _, y in { 1.1, 2.3 } do
			Shapes.part(
				fence,
				Vector3.new(0.3, 0.4, len),
				mid * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, 0),
				P.white
			)
		end
	end
	local hw, hd = W / 2 - 1, D / 2 - 1
	rail(-hw, -hd, -hw, hd)
	rail(hw, -hd, hw, hd)
	rail(-hw, hd, hw, hd)
	rail(-hw, -hd, -hw + 20, -hd)
	rail(hw - 20, -hd, Layout.SPOTS.lane.x + 7, -hd)
	-- trees along the back and the sides (scenic edges)
	local trees = Shapes.folder(g, "Trees")
	local rng = Random.new(i * 7919)
	for k = -5, 5 do
		Shapes.tree(
			trees,
			cf(i, k * 11 + rng:NextNumber(-2, 2), hd - 4 + rng:NextNumber(-2, 1)),
			1 + rng:NextNumber(-0.15, 0.25),
			k % 2 == 0 and P.leaf or P.grassDark
		)
	end
	for k = -3, 3 do
		Shapes.tree(
			trees,
			cf(i, -hw + 4 + rng:NextNumber(-1, 1), k * 14 + rng:NextNumber(-2, 2)),
			0.9 + rng:NextNumber(0, 0.3),
			P.leaf
		)
	end
	-- the gate sign
	local post =
		Shapes.part(g, Vector3.new(0.8, 7, 0.8), cf(i, Layout.SPOTS.sign.x, Layout.SPOTS.sign.z, 3.5), P.woodDark)
	post.Name = "GatePost"
	local board = Shapes.part(g, Vector3.new(14, 3, 0.6), cf(i, Layout.SPOTS.sign.x, Layout.SPOTS.sign.z, 7.5), P.wood)
	board.Name = "GateSign"
	local stars = string.rep("★", math.min(view.prestige or 0, 6))
	local text = string.upper(view.name or "YOUR") .. " FARM" .. (stars ~= "" and (" " .. stars) or "")
	Shapes.face(board, text, Enum.NormalId.Front, { PixelsPerStud = 30 })
	Shapes.face(board, text, Enum.NormalId.Back, { PixelsPerStud = 30 })
	-- the spawn
	local spawn = Shapes.part(g, Vector3.new(6, 0.4, 6), cf(i, Layout.SPOTS.spawn.x, Layout.SPOTS.spawn.z, 0.1), P.path)
	spawn.Name = "Spawn"
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
	local SIGN = { field1 = nil, field2 = "EAST FIELD", field3 = "WEST FIELD", field4 = "NORTH FIELD" }
	for _, key in Layout.FIELD_LIST do
		local field = Layout.FIELDS[key]
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
				-- a low ridge round it
				Shapes.part(f, Vector3.new(Layout.TILE + 0.4, 0.3, Layout.TILE + 0.4), cf(i, x, z, 0.05), P.soilDark).Name =
					"Edge"
			elseif key == "field1" then
				-- a tile not yet bought in the starter field: a faint outline
				local ghost = Shapes.part(f, Vector3.new(Layout.TILE, 0.2, Layout.TILE), cf(i, x, z, 0.1), P.grassDark)
				ghost.Name = "Soon"
				ghost.Transparency = 0.5
			end
		end
		if not any and key ~= "field1" then
			-- an expansion zone: its outline and a sign (visible unused land, master plan §2)
			local cx = field.x + (field.cols - 1) * Layout.PITCH / 2
			local cz = field.z + (field.rows - 1) * Layout.PITCH / 2
			local w = field.cols * Layout.PITCH
			local d = field.rows * Layout.PITCH
			local zone = Shapes.part(f, Vector3.new(w, 0.15, d), cf(i, cx, cz, 0.08), P.grassLight)
			zone.Name = "Zone"
			zone.Transparency = 0.35
			zone:SetAttribute("Field", key)
			local post = Shapes.part(f, Vector3.new(0.5, 4, 0.5), cf(i, cx, cz, 2), P.woodDark)
			post.Name = "ZoneSign"
			post:SetAttribute("Field", key)
			local cost = view.fieldCosts and view.fieldCosts[key]
			Shapes.label(post, SIGN[key] .. (cost and ("\n" .. Format.cash(cost)) or ""), {
				Size = UDim2.fromOffset(200, 60),
				StudsOffset = Vector3.new(0, 3, 0),
				MaxDistance = 90,
			})
		end
	end
	return f
end

-- The buildings -------------------------------------------------------------------------------------------------------
local function awning(parent, origin, width, depth, y)
	-- red and cream stripes, sloping a little
	local n = math.max(2, math.floor(width / 1.6))
	for k = 0, n - 1 do
		local c = k % 2 == 0 and P.awning or P.awningStripe
		Shapes.part(
			parent,
			Vector3.new(width / n, 0.25, depth),
			origin * CFrame.new(-width / 2 + (k + 0.5) * width / n, y, 0) * CFrame.Angles(0.25, 0, 0),
			c
		)
	end
end

local function stand(b, i)
	local s = Layout.SPOTS.stand
	local o = cf(i, s.x, s.z, 0)
	local m = Shapes.model(b, "Business")
	local counter = Shapes.part(m, Vector3.new(10, 3, 2.4), o * CFrame.new(0, 1.5, -2), P.wood, { CanCollide = true })
	counter.Name = "Counter"
	Shapes.part(m, Vector3.new(10.4, 0.4, 3), o * CFrame.new(0, 3.2, -2), P.woodDark)
	for _, x in { -4.6, 4.6 } do
		Shapes.part(m, Vector3.new(0.5, 7, 0.5), o * CFrame.new(x, 3.5, -3.6), P.woodDark)
		Shapes.part(m, Vector3.new(0.5, 7, 0.5), o * CFrame.new(x, 3.5, 2), P.woodDark)
	end
	awning(m, o, 11, 7, 7.1)
	-- the stock area behind the counter: a few crates
	local stock = Shapes.folder(m, "StockArea")
	for k = 0, 2 do
		Shapes.part(stock, Vector3.new(2, 1.6, 2), o * CFrame.new(-3 + k * 3, 0.8, 2.6), P.wood)
	end
	local sign = Shapes.part(m, Vector3.new(9, 1.8, 0.4), o * CFrame.new(0, 8.3, -3.6), P.cream)
	sign.Name = "Sign"
	Shapes.face(sign, "FRUIT STAND", Enum.NormalId.Front, { TextColor3 = P.barnRed, TextStrokeTransparency = 1 })
	-- where the line forms
	for k = 1, 3 do
		Shapes.part(m, Vector3.new(1.2, 0.1, 1.2), o * CFrame.new(1.5, 0.06, -5 - k * 2.4), P.path)
	end
	return m
end

local function shop(b, i)
	local s = Layout.SPOTS.stand
	local o = cf(i, s.x, s.z + 4, 0)
	local m = Shapes.model(b, "Business")
	local W, D, H = 26, 16, 9
	-- walls (cream) with a big window and a door on the front
	Shapes.part(m, Vector3.new(W, 0.6, D), o * CFrame.new(0, 0.3, 0), P.concrete, { CanCollide = true }) -- floor
	Shapes.part(m, Vector3.new(0.6, H, D), o * CFrame.new(-W / 2, H / 2, 0), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.6, H, D), o * CFrame.new(W / 2, H / 2, 0), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(W, H, 0.6), o * CFrame.new(0, H / 2, D / 2), P.cream, { CanCollide = true }) -- back
	-- front: two window panels and the door gap
	Shapes.part(m, Vector3.new(9, H, 0.6), o * CFrame.new(-8.5, H / 2, -D / 2), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(9, H, 0.6), o * CFrame.new(8.5, H / 2, -D / 2), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(8, 2.5, 0.6), o * CFrame.new(0, H - 1.25, -D / 2), P.cream, { CanCollide = true })
	Shapes.part(m, Vector3.new(7, 4.5, 0.3), o * CFrame.new(-8.5, 4.5, -D / 2 - 0.1), P.glass)
	Shapes.part(m, Vector3.new(7, 4.5, 0.3), o * CFrame.new(8.5, 4.5, -D / 2 - 0.1), P.glass)
	-- roof: a green gable
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 4, W / 2 + 1),
		o * CFrame.new(-W / 4 - 0.2, H + 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
		P.roofGreen
	)
	Shapes.wedge(
		m,
		Vector3.new(D + 2, 4, W / 2 + 1),
		o * CFrame.new(W / 4 + 0.2, H + 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		P.roofGreen
	)
	awning(m, o, 24, 5, 0)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and (p.Color == P.awning or p.Color == P.awningStripe) then
			p.CFrame = p.CFrame * CFrame.new(0, 7.2, -D / 2 - 2.2)
		end
	end
	-- the counter inside, the shelves along the back, the stockroom at the side
	local counter = Shapes.part(m, Vector3.new(12, 2.8, 2), o * CFrame.new(0, 1.4, -2), P.wood)
	counter.Name = "Counter"
	for k = 0, 3 do
		Shapes.part(
			m,
			Vector3.new(5, 0.3, 1.4),
			o * CFrame.new(-8 + k * 5.3, 2 + (k % 2) * 1.6, D / 2 - 1.2),
			P.woodDark
		)
		Shapes.part(
			m,
			Vector3.new(5, 0.3, 1.4),
			o * CFrame.new(-8 + k * 5.3, 4.6 - (k % 2) * 1.6, D / 2 - 1.2),
			P.woodDark
		)
	end
	local stock = Shapes.folder(m, "StockArea")
	for k = 0, 5 do
		Shapes.part(
			stock,
			Vector3.new(2, 1.6, 2),
			o * CFrame.new(W / 2 - 2.2, 0.8 + (k // 3) * 1.6, -5 + (k % 3) * 2.4),
			P.wood
		)
	end
	local sign = Shapes.part(m, Vector3.new(14, 2.2, 0.4), o * CFrame.new(0, H + 1.4, -D / 2 - 0.4), P.barnRed)
	sign.Name = "Sign"
	Shapes.face(sign, "FRUIT SHOP", Enum.NormalId.Front, { TextColor3 = P.white, TextStrokeTransparency = 1 })
	for k = 1, 4 do
		Shapes.part(m, Vector3.new(1.2, 0.1, 1.2), o * CFrame.new(0, 0.66, -D / 2 - 2 - k * 2.4), P.path)
	end
	return m
end

local function warehouse(b, i, view)
	local s = Layout.SPOTS.warehouse
	local big = view.stage == "center"
	local W, D, H = big and 64 or 44, big and 40 or 30, big and 16 or 12
	local o = cf(i, s.x - (big and 8 or 0), s.z, 0)
	local m = Shapes.model(b, "Warehouse")
	local wall = big and P.steel or P.concrete
	Shapes.part(m, Vector3.new(W, 0.6, D), o * CFrame.new(0, 0.3, 0), P.concrete, { CanCollide = true })
	Shapes.part(m, Vector3.new(W, H, 0.8), o * CFrame.new(0, H / 2, D / 2), wall, { CanCollide = true })
	Shapes.part(m, Vector3.new(W, H, 0.8), o * CFrame.new(0, H / 2, -D / 2), wall, { CanCollide = true })
	Shapes.part(m, Vector3.new(0.8, H, D), o * CFrame.new(-W / 2, H / 2, 0), wall, { CanCollide = true })
	-- the dock side (+x): the wall with the dock doors open
	local docks = math.max(1, view.docks or 1)
	local pitch = D / (docks + 1)
	for k = 0, docks do
		local z0 = -D / 2 + k * pitch
		Shapes.part(
			m,
			Vector3.new(0.8, H, pitch - 6),
			o * CFrame.new(W / 2, H / 2, z0 + pitch / 2),
			wall,
			{ CanCollide = true }
		)
	end
	Shapes.part(m, Vector3.new(0.8, H - 7, D), o * CFrame.new(W / 2, H - (H - 7) / 2, 0), wall)
	-- roof and the stripe
	Shapes.part(m, Vector3.new(W + 2, 0.8, D + 2), o * CFrame.new(0, H + 0.4, 0), P.steelDark)
	Shapes.part(m, Vector3.new(W, 1.2, 0.3), o * CFrame.new(0, H - 2, -D / 2 - 0.5), P.safetyYellow)
	-- the docks: a platform along the +x side with the bays, the trucks' lane beside it
	local platform =
		Shapes.part(m, Vector3.new(6, 1.2, D), o * CFrame.new(W / 2 + 3, 0.6, 0), P.concrete, { CanCollide = true })
	platform.Name = "Platform"
	for k = 1, docks do
		local z = -D / 2 + k * pitch
		local bay = Shapes.part(m, Vector3.new(5, 0.3, 4), o * CFrame.new(W / 2 + 3, 1.25, z), P.safetyYellow)
		bay.Name = "Dock"
		bay:SetAttribute("Index", k)
		Shapes.part(m, Vector3.new(0.4, 2, 4), o * CFrame.new(W / 2 + 5.8, 0.6, z), P.steelDark) -- bumper
	end
	-- pallets inside, a forklift
	local pallets = Shapes.folder(m, "Pallets")
	for k = 0, (big and 11 or 5) do
		Models.pallet(
			pallets,
			o * CFrame.new(-W / 2 + 4 + (k % 4) * 5, 0.6, -D / 2 + 4 + (k // 4) * 5),
			({ P.wood, P.barnRed, P.roofGreen })[k % 3 + 1]
		)
	end
	local sign = Shapes.part(m, Vector3.new(W * 0.6, 2.6, 0.4), o * CFrame.new(0, H - 4, -D / 2 - 0.5), P.roofBlue)
	sign.Name = "Sign"
	Shapes.face(
		sign,
		big and "DISTRIBUTION CENTRE" or "WAREHOUSE",
		Enum.NormalId.Front,
		{ TextColor3 = P.white, TextStrokeTransparency = 1 }
	)
	if big then
		-- a conveyor tube out of the back wall and a tower
		Shapes.cylinder(
			m,
			Vector3.new(D, 2, 2),
			o * CFrame.new(-W / 2 + 6, H - 3, 0) * CFrame.Angles(math.pi / 2, 0, 0),
			P.steel
		)
		Shapes.part(m, Vector3.new(4, 10, 4), o * CFrame.new(W / 2 - 4, H + 5, -D / 2 + 4), P.steelDark)
	end
	return m
end

local function shed(b, i, view)
	local s = Layout.SPOTS.shed
	local o = cf(i, s.x, s.z, 0)
	local m = Shapes.model(b, "Shed")
	Shapes.part(m, Vector3.new(14, 0.4, 14), o * CFrame.new(0, 0.2, 0), P.concrete)
	for _, x in { -6.5, 6.5 } do
		for _, z in { -6.5, 6.5 } do
			Shapes.part(m, Vector3.new(0.6, 7, 0.6), o * CFrame.new(x, 3.5, z), P.woodDark)
		end
	end
	Shapes.part(m, Vector3.new(15, 0.6, 15), o * CFrame.new(0, 7.2, 0), P.barnRed)
	Shapes.part(m, Vector3.new(0.4, 7, 14), o * CFrame.new(7, 3.5, 0), P.wood)
	if view.machine and view.machine > 0 then
		local tier = math.min(view.machine, 3)
		local mach = Models.machine(m, tier, view.paint or P.machineRed)
		mach.Name = "Machine"
		mach:PivotTo(o * CFrame.new(0, 0, 0))
		if view.machine >= 4 then
			local second = Models.machine(m, 3, view.paint or P.machineGreen)
			second.Name = "Machine2"
			second:PivotTo(o * CFrame.new(-16, 0, 0))
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
	if view.stage == "warehouse" or view.stage == "center" then
		warehouse(b, i, view)
		-- the trucks: one a dock, parked in the lane
		local trucks = Shapes.folder(b, "Trucks")
		for k = 1, math.max(1, view.docks or 1) do
			local t = Models.truck(trucks, view.paint or P.truckWhite)
			t:SetAttribute("Index", k)
			t:PivotTo(cf(i, Layout.SPOTS.lane.x, Layout.SPOTS.warehouse.z - 20 + k * 12, 0, math.pi))
		end
		Models.forklift(b):PivotTo(cf(i, Layout.SPOTS.warehouse.x + 10, Layout.SPOTS.warehouse.z - 8, 0.3))
	end
	if view.machine and view.machine > 0 then
		shed(b, i, view)
	end
	return b
end

-- The preview of the next building (master plan §16: the long-term milestone, a silhouette in the world) ----------
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
	local o, size
	if key == "shop" then
		o, size = cf(i, Layout.SPOTS.stand.x, Layout.SPOTS.stand.z + 4, 0), Vector3.new(26, 9, 16)
	elseif key == "warehouse" then
		o, size = cf(i, Layout.SPOTS.warehouse.x, Layout.SPOTS.warehouse.z, 0), Vector3.new(44, 12, 30)
	elseif key == "center" then
		o, size = cf(i, Layout.SPOTS.warehouse.x - 8, Layout.SPOTS.warehouse.z, 0), Vector3.new(64, 16, 40)
	else
		o, size = cf(i, Layout.SPOTS.gate.x, Layout.SPOTS.gate.z + 6, 0), Vector3.new(6, 8, 6)
	end
	local ghost = Shapes.ghost(Shapes.part(pv, size, o * CFrame.new(0, size.Y / 2 + 0.5, 0), P.preview))
	ghost.Name = "Ghost"
	ghost:SetAttribute("Upgrade", key)
	if key ~= "region" then
		Shapes.ghost(
			Shapes.wedge(
				pv,
				Vector3.new(size.Z, 3, size.X / 2),
				o * CFrame.new(-size.X / 4, size.Y + 2, 0) * CFrame.Angles(0, math.pi / 2, 0),
				P.preview
			)
		)
		Shapes.ghost(
			Shapes.wedge(
				pv,
				Vector3.new(size.Z, 3, size.X / 2),
				o * CFrame.new(size.X / 4, size.Y + 2, 0) * CFrame.Angles(0, -math.pi / 2, 0),
				P.preview
			)
		)
	end
	local post = Shapes.part(pv, Vector3.new(0.6, 5, 0.6), o * CFrame.new(0, 2.5, -size.Z / 2 - 4), P.woodDark)
	post.Name = "PreviewSign"
	Shapes.label(post, `NEXT: {string.upper(view.next.name)}\n{Format.cash(view.next.cost)}`, {
		Size = UDim2.fromOffset(260, 70),
		StudsOffset = Vector3.new(0, 4, 0),
		MaxDistance = 140,
		TextColor3 = P.preview,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Build"
	prompt.ActionText = "Build " .. view.next.name
	prompt.ObjectText = Format.cash(view.next.cost)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 14
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

-- An empty territory (nobody's yet): the ground and a FOR SALE board
function TerritoryBuilder.empty(parent, i)
	local model = Shapes.model(parent, "T" .. i)
	model:SetAttribute("Index", i)
	ground(model, i, { name = "FREE" })
	return model
end

return TerritoryBuilder

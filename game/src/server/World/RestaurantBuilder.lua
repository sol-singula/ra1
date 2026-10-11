-- Builds one restaurant on a plot (TIER_01 Broken Burger Shack / TIER_02 Tiny Mutation Diner) out of primitive
-- parts: no uploaded assets needed. Local layout (studs, plot centre = origin, front faces -Z toward the street):
--   kitchen  z = +6 … +24   stations on the back wall, assembly island in the middle
--   counter  z = +5          order spot in front of it; a gap at x = +10 … +16 lets the cook walk through
--   aisle    z = -2          customers walk along it; queue spots east of the order spot
--   dining   z = -12 row     round tables with a stool either side
--   door     x = +22, z = -24; customers spawn on the sidewalk at z = -34
-- Station models keep a "Base" (prompts) and a "Top" (items); everything else is decoration.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent.WorldBuilder)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)

local RestaurantBuilder = {}

local block = WorldBuilder.block
local rgb = Color3.fromRGB
local WOOD = rgb(176, 122, 74)
local WOOD_LIGHT = rgb(214, 168, 112)
local DARK = rgb(52, 54, 66)
local STEEL = rgb(196, 202, 212)
local CHROME = rgb(225, 228, 235)
local PAPER = rgb(255, 246, 224)
local INK = rgb(27, 29, 43)
local WALL = rgb(255, 222, 160)
local WAINSCOT = rgb(46, 150, 140)
local KETCHUP = rgb(232, 70, 60)

local TABLE_XS = { -18, -4, 10 } -- table 3 only exists from TIER_02

local function round(parent, name, height, diameter, cf, color, material)
	local p = block(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, d, cf, color, material)
	local p = block(parent, name, Vector3.new(d, d, d), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function label(parent, title, subtitle, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(190, subtitle and 48 or 30)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 45
	gui.AlwaysOnTop = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = PAPER
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = subtitle and UDim2.new(1, -8, 0, 26) or UDim2.new(1, -8, 1, 0)
	t.Position = UDim2.fromOffset(4, subtitle and 2 or 0)
	t.TextColor3 = INK
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = title
	t.Parent = frame
	if subtitle then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Size = UDim2.new(1, -8, 0, 16)
		s.Position = UDim2.fromOffset(4, 28)
		s.TextColor3 = rgb(110, 106, 124)
		s.Font = Enum.Font.FredokaOne
		s.TextScaled = true
		s.Text = subtitle
		s.Parent = frame
	end
	frame.Parent = gui
	gui.Parent = parent
	return gui
end

local function station(parent, root, id, name, subtitle, pos, size, topColor)
	local m = Instance.new("Model")
	m.Name = id
	local base = block(m, "Base", size, root * CFrame.new(pos), STEEL, Enum.Material.Metal)
	local top = block(
		m,
		"Top",
		Vector3.new(size.X - 0.4, 0.3, size.Z - 0.4),
		base.CFrame * CFrame.new(0, size.Y / 2 + 0.15, 0),
		topColor
	)
	m.PrimaryPart = base
	m:SetAttribute("StationId", id)
	label(base, name, subtitle, Vector3.new(0, size.Y / 2 + 3.4, 0))
	m.Parent = parent
	return m, base, top
end

local function slot(top, name, offset)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = offset + Vector3.new(0, top.Size.Y / 2, 0)
	a.Parent = top
	return a
end

local function lamp(parent, cf)
	block(parent, "LampCord", Vector3.new(0.12, 3, 0.12), cf * CFrame.new(0, 1.5, 0), INK)
	local shade = round(parent, "LampShade", 0.9, 2.4, cf, KETCHUP)
	shade.Material = Enum.Material.SmoothPlastic
	local bulb = ball(parent, "Bulb", 0.8, cf * CFrame.new(0, -0.55, 0), rgb(255, 240, 200), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 214, 160)
	light.Range = 18
	light.Brightness = 1.4
	light.Shadows = true
	light.Parent = bulb
end

local function plant(parent, cf)
	round(parent, "Pot", 1.6, 2, cf * CFrame.new(0, 0.8, 0), rgb(196, 98, 60))
	ball(parent, "Leaves", 2.6, cf * CFrame.new(0, 2.6, 0), rgb(76, 168, 82), Enum.Material.Grass)
	ball(parent, "Leaves", 1.8, cf * CFrame.new(0.7, 3.5, 0.3), rgb(92, 186, 96), Enum.Material.Grass)
end

local function surfaceText(part, face, canvas)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = canvas
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = INK
	t.Parent = sg
	sg.Parent = part
	return t
end

function RestaurantBuilder.build(owner, plotIndex, tierIndex)
	local tier = Progression.Tiers[tierIndex]
	local root = WorldBuilder.plotCFrame(plotIndex)
	local model = Instance.new("Model")
	model.Name = "Restaurant_" .. owner.Name
	model:SetAttribute("OwnerUserId", owner.UserId)
	model:SetAttribute("PlotIndex", plotIndex)

	local function at(x, y, z)
		return root * CFrame.new(x, y, z)
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model

	-- floors: checkered diner tiles in the dining room, grey tiles in the kitchen
	block(model, "Floor", Vector3.new(62, 0.4, 50), at(0, 0.5, 0), rgb(236, 224, 200), Enum.Material.WoodPlanks)
	for ix = 0, 14 do
		for iz = 0, 6 do
			local even = (ix + iz) % 2 == 0
			block(
				decor,
				"Tile",
				Vector3.new(4, 0.1, 4),
				at(-28 + ix * 4, 0.74, -22 + iz * 4),
				even and PAPER or rgb(255, 126, 110)
			)
		end
	end
	for ix = 0, 14 do
		for iz = 0, 3 do
			local even = (ix + iz) % 2 == 0
			block(
				decor,
				"KitchenTile",
				Vector3.new(4, 0.1, 4.5),
				at(-28 + ix * 4, 0.74, 8.25 + iz * 4.5),
				even and rgb(232, 236, 242) or rgb(200, 206, 216),
				Enum.Material.Marble
			)
		end
	end

	-- walls: painted with a teal wainscot band; the front wall has windows and a door frame
	local function wall(name, size, cf)
		block(model, name, size, cf, WALL)
		block(
			decor,
			name .. "Band",
			Vector3.new(size.X + 0.1, 3, size.Z + 0.1),
			cf * CFrame.new(0, -size.Y / 2 + 1.5, 0),
			WAINSCOT
		)
		block(
			decor,
			name .. "Trim",
			Vector3.new(size.X + 0.2, 0.4, size.Z + 0.2),
			cf * CFrame.new(0, size.Y / 2, 0),
			WOOD
		)
	end
	wall("WallBack", Vector3.new(62, 10, 1), at(0, 5.5, 24.5))
	wall("WallLeft", Vector3.new(1, 10, 50), at(-30.5, 5.5, 0))
	wall("WallRight", Vector3.new(1, 10, 50), at(30.5, 5.5, 0))
	wall("WallFrontL", Vector3.new(48, 3, 1), at(-6, 2, -24.5))
	wall("WallFrontR", Vector3.new(4, 3, 1), at(28.5, 2, -24.5))
	for i = 0, 4 do
		local x = -28 + i * 8 + 4
		local glass =
			block(decor, "Window", Vector3.new(7.6, 5, 0.3), at(x, 6, -24.5), rgb(170, 220, 240), Enum.Material.Glass)
		glass.Transparency = 0.55
		block(decor, "WindowFrame", Vector3.new(0.5, 5.6, 0.8), at(x - 4, 6, -24.5), WOOD)
	end
	block(decor, "WindowFrame", Vector3.new(0.5, 5.6, 0.8), at(12, 6, -24.5), WOOD)
	block(model, "WallFrontPanel", Vector3.new(6, 5.6, 1), at(15.2, 6, -24.5), WALL)
	block(decor, "WindowSill", Vector3.new(40.4, 0.5, 1.4), at(-8, 3.6, -24.6), WOOD)
	block(decor, "WindowHead", Vector3.new(40.4, 0.6, 1), at(-8, 8.7, -24.5), WOOD)
	block(decor, "DoorFrameL", Vector3.new(0.8, 9, 1.2), at(18.4, 5, -24.5), WOOD)
	block(decor, "DoorFrameR", Vector3.new(0.8, 9, 1.2), at(26.1, 5, -24.5), WOOD)
	block(decor, "DoorHead", Vector3.new(8.5, 1, 1.2), at(22.25, 9, -24.5), WOOD)
	local open =
		block(decor, "OpenSign", Vector3.new(4, 1.2, 0.2), at(22.25, 7.8, -25.2), rgb(255, 90, 80), Enum.Material.Neon)
	surfaceText(open, Enum.NormalId.Front, Vector2.new(200, 60)).Text = "OPEN"
	-- striped awning over the windows
	for i = 0, 11 do
		local stripe = block(
			decor,
			"Awning",
			Vector3.new(4, 0.3, 4.4),
			at(-28 + i * 4 + 2, 10.4, -26.4) * CFrame.Angles(math.rad(-28), 0, 0),
			i % 2 == 0 and KETCHUP or PAPER
		)
		stripe.Name = "Awning"
	end

	-- counter with a cash register at the order spot
	block(model, "Counter", Vector3.new(38, 3.6, 2), at(-9, 2.5, 5), WOOD, Enum.Material.Wood)
	block(model, "CounterEnd", Vector3.new(14, 3.6, 2), at(23, 2.5, 5), WOOD, Enum.Material.Wood)
	block(decor, "CounterTop", Vector3.new(38.4, 0.3, 2.6), at(-9, 4.45, 5), WOOD_LIGHT, Enum.Material.Wood)
	block(decor, "CounterTopEnd", Vector3.new(14.4, 0.3, 2.6), at(23, 4.45, 5), WOOD_LIGHT, Enum.Material.Wood)
	block(decor, "Register", Vector3.new(2, 1.2, 1.6), at(-2, 5.2, 5.2), DARK)
	block(
		decor,
		"RegisterScreen",
		Vector3.new(1.6, 0.9, 0.2),
		at(-2, 6.2, 5.6) * CFrame.Angles(math.rad(-20), 0, 0),
		rgb(80, 220, 200),
		Enum.Material.Neon
	)
	block(decor, "Bell", Vector3.new(0.8, 0.5, 0.8), at(1, 4.85, 4.8), rgb(255, 210, 80), Enum.Material.Metal)

	-- the sign over the windows
	local signPart = block(model, "Sign", Vector3.new(30, 4, 0.6), at(-6, 12.6, -24.8), rgb(255, 197, 49))
	block(decor, "SignFrame", Vector3.new(31, 4.8, 0.4), at(-6, 12.6, -24.4), INK)
	local st = surfaceText(signPart, Enum.NormalId.Front, Vector2.new(600, 80))
	st.Text = `{tier.name} · {owner.DisplayName}`

	-- live menu board on the dining room wall
	local board = block(decor, "MenuBoard", Vector3.new(0.4, 6, 9), at(-30, 6.5, -10), INK)
	block(decor, "MenuBoardFrame", Vector3.new(0.3, 6.6, 9.6), at(-30.15, 6.5, -10), WOOD)
	local menuText = surfaceText(board, Enum.NormalId.Right, Vector2.new(300, 200))
	menuText.TextColor3 = PAPER
	menuText.Font = Enum.Font.FredokaOne
	menuText.TextXAlignment = Enum.TextXAlignment.Left

	-- stations (the TIER_01 starter kit, §C7.1)
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = model
	local s = {}
	local m, base, top

	m, base = station(
		stations,
		root,
		"STN_PANTRY",
		"Pantry",
		"take ingredients",
		Vector3.new(-24, 3.5, 21.5),
		Vector3.new(7, 6, 3),
		WOOD
	)
	base.Color = WOOD
	base.Material = Enum.Material.Wood
	local boxColors = {
		rgb(255, 197, 49),
		rgb(232, 70, 60),
		rgb(108, 196, 84),
		rgb(255, 255, 255),
		rgb(240, 150, 60),
		rgb(160, 110, 70),
	}
	for shelf = 0, 2 do
		block(
			m,
			"Shelf",
			Vector3.new(6.8, 0.25, 2.2),
			base.CFrame * CFrame.new(0, -2 + shelf * 2, -1.2),
			WOOD_LIGHT,
			Enum.Material.Wood
		)
		for i = 0, 3 do
			local c = boxColors[(shelf * 4 + i) % #boxColors + 1]
			block(
				m,
				"Box",
				Vector3.new(1.2, 1.2, 1.2),
				base.CFrame * CFrame.new(-2.4 + i * 1.6, -1.25 + shelf * 2, -1.4),
				c
			)
		end
	end
	s.STN_PANTRY = m

	m, base, top = station(
		stations,
		root,
		"STN_CUT",
		"Cutting Board",
		"chop vegetables",
		Vector3.new(-15, 2.2, 21.5),
		Vector3.new(6, 3.4, 4),
		rgb(236, 200, 150)
	)
	slot(top, "Slot1", Vector3.zero)
	block(m, "Knife", Vector3.new(0.2, 0.08, 1.8), top.CFrame * CFrame.new(2.2, 0.2, 0.2), CHROME, Enum.Material.Metal)
	block(m, "KnifeHandle", Vector3.new(0.3, 0.2, 0.9), top.CFrame * CFrame.new(2.2, 0.22, 1.5), INK)
	s.STN_CUT = m

	m, base, top = station(
		stations,
		root,
		"STN_GRILL",
		"Grill",
		"patties · hot dogs · bread",
		Vector3.new(-6, 2.2, 21.5),
		Vector3.new(7, 3.4, 4),
		DARK
	)
	base.Color = rgb(70, 72, 84)
	slot(top, "Slot1", Vector3.new(-1.6, 0, 0))
	slot(top, "Slot2", Vector3.new(1.6, 0, 0))
	for i = -3, 3 do
		block(
			m,
			"Grate",
			Vector3.new(0.15, 0.12, 3.4),
			top.CFrame * CFrame.new(i * 0.9, 0.2, 0),
			rgb(30, 30, 34),
			Enum.Material.Metal
		)
	end
	for i = -1, 1 do
		round(
			m,
			"Knob",
			0.3,
			0.5,
			base.CFrame * CFrame.new(i * 1.6, 0.8, -2.05) * CFrame.Angles(0, math.rad(90), 0),
			KETCHUP
		)
	end
	s.STN_GRILL = m

	m, base, top = station(
		stations,
		root,
		"STN_FRYER",
		"Fryer",
		"potatoes · onions",
		Vector3.new(3, 2.2, 21.5),
		Vector3.new(5, 3.4, 4),
		rgb(240, 196, 60)
	)
	top.Transparency = 0.15
	slot(top, "Slot1", Vector3.zero)
	block(m, "BasketHandle", Vector3.new(0.3, 0.3, 2.2), top.CFrame * CFrame.new(0, 0.5, -1.5), INK)
	block(
		m,
		"Basket",
		Vector3.new(3, 0.6, 2.2),
		top.CFrame * CFrame.new(0, 0.1, 0.2),
		rgb(150, 156, 166),
		Enum.Material.DiamondPlate
	)
	s.STN_FRYER = m

	-- range hood over the grill and fryer
	block(decor, "Hood", Vector3.new(14, 2, 4), at(-1.5, 9, 21.5), STEEL, Enum.Material.Metal)
	block(decor, "Backsplash", Vector3.new(44, 3, 0.3), at(-8, 5.3, 23.85), rgb(250, 250, 250))

	m, base = station(
		stations,
		root,
		"STN_DRINK",
		"Drink Dispenser",
		"pour drinks",
		Vector3.new(12, 3.5, 21.5),
		Vector3.new(5, 6, 3),
		rgb(46, 196, 182)
	)
	base.Color = rgb(46, 196, 182)
	base.Material = Enum.Material.SmoothPlastic
	for i, c in { rgb(150, 70, 40), rgb(250, 230, 110), rgb(255, 120, 170) } do
		block(
			m,
			"Flavor",
			Vector3.new(1.2, 1.6, 0.2),
			base.CFrame * CFrame.new(-1.6 + (i - 1) * 1.6, 1.6, -1.6),
			c,
			Enum.Material.Neon
		)
		block(
			m,
			"Nozzle",
			Vector3.new(0.4, 0.8, 0.4),
			base.CFrame * CFrame.new(-1.6 + (i - 1) * 1.6, -0.2, -1.7),
			CHROME,
			Enum.Material.Metal
		)
	end
	block(m, "DripTray", Vector3.new(4.6, 0.3, 1.4), base.CFrame * CFrame.new(0, -1.4, -2), DARK)
	s.STN_DRINK = m

	m, base, top = station(
		stations,
		root,
		"STN_ASSEMBLY",
		"Assembly Counter",
		"stack · plate",
		Vector3.new(-8, 2.2, 12),
		Vector3.new(14, 3.4, 4),
		rgb(245, 240, 230)
	)
	for i, x in { -3.5, 3.5 } do
		local b = block(
			m,
			"Board" .. i,
			Vector3.new(4.5, 0.2, 3),
			top.CFrame * CFrame.new(x, 0.25, 0),
			rgb(210, 170, 120),
			Enum.Material.Wood
		)
		b:SetAttribute("Board", i)
		slot(b, "Stack", Vector3.zero)
	end
	for i = 0, 3 do
		round(m, "Plate", 0.15, 1.6, top.CFrame * CFrame.new(-6.3, 0.25 + i * 0.16, 0), rgb(250, 250, 250))
	end
	s.STN_ASSEMBLY = m

	m, base, top = station(
		stations,
		root,
		"STN_TRASH",
		"Trash",
		"throw things away",
		Vector3.new(26, 2, 14),
		Vector3.new(3, 3, 3),
		rgb(70, 150, 90)
	)
	base.Color = rgb(70, 150, 90)
	base.Material = Enum.Material.SmoothPlastic
	s.STN_TRASH = m

	-- dining room: round tables with a stool either side and a lamp above
	local dining = Instance.new("Folder")
	dining.Name = "Dining"
	dining.Parent = model
	local seats = {}
	for t = 1, math.ceil(tier.seats / 2) do
		local x = TABLE_XS[t]
		local tbl = round(dining, "Table" .. t, 0.6, 4.6, at(x, 3.6, -12), WOOD_LIGHT, Enum.Material.Wood)
		tbl:SetAttribute("Durability", 100)
		tbl:SetAttribute("FurnitureName", "Diner Table")
		block(decor, "TableLeg", Vector3.new(0.5, 2.6, 0.5), at(x, 2, -12), CHROME, Enum.Material.Metal)
		round(decor, "TableFoot", 0.3, 2.2, at(x, 0.9, -12), CHROME, Enum.Material.Metal)
		round(decor, "Napkins", 0.6, 0.7, at(x + 0.9, 4.2, -12.6), PAPER)
		lamp(decor, at(x, 11.5, -12))
		for side = -1, 1, 2 do
			local idx = #seats + 1
			local stool = round(dining, "Seat" .. idx, 0.6, 2.4, at(x + side * 3.4, 2.6, -12), KETCHUP)
			stool:SetAttribute("Durability", 100)
			stool:SetAttribute("FurnitureName", "Stool")
			block(
				decor,
				"StoolLeg",
				Vector3.new(0.4, 1.8, 0.4),
				at(x + side * 3.4, 1.6, -12),
				CHROME,
				Enum.Material.Metal
			)
			table.insert(seats, {
				index = idx,
				part = stool,
				tablePart = tbl,
				cf = CFrame.lookAt(at(x + side * 3.4, 2.5, -12).Position, at(x, 2.5, -12).Position),
				approach = at(x + side * 3.4, 2.5, -2),
			})
		end
	end
	plant(decor, at(-28, 0.75, -22))
	plant(decor, at(16, 0.75, -22))
	plant(decor, at(28, 0.75, 2))

	model.Parent = workspace.Restaurants

	local function p(x, z)
		return at(x, 2.5, z).Position
	end
	return {
		model = model,
		root = root,
		stations = s,
		seats = seats,
		sign = st,
		-- keep the wall menu in sync with the player's menu
		setMenu = function(recipes)
			local lines = { "MENU" }
			for _, r in recipes do
				table.insert(lines, `{r.name}  ·  {r.price} MB`)
			end
			menuText.Text = table.concat(lines, "\n")
		end,
		way = {
			spawn = p(22, -34),
			door = p(22, -24),
			aisle = p(22, -2),
			order = p(-2, 2),
			queue = { p(3, 2), p(8, 2), p(13, 2) },
		},
		kitchenSpawn = at(-2, 3.5, 16),
		center = at(0, 3, 0).Position,
	}
end

return RestaurantBuilder

-- Builds one greybox restaurant on a plot (TIER_01 Broken Burger Shack / TIER_02 Tiny Mutation Diner).
-- Local layout (studs, plot centre = origin, front faces -Z toward the street):
--   kitchen  z = +6 … +24   stations on the back wall, assembly island in the middle
--   counter  z = +5          order spot in front of it; a gap at x = +10 … +16 lets the cook walk through
--   aisle    z = -2          customers walk along it; queue spots east of the order spot
--   dining   z = -12 row     tables with a stool on each side
--   door     x = +22, z = -24; customers spawn on the sidewalk at z = -34
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBuilder = require(script.Parent.WorldBuilder)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)

local RestaurantBuilder = {}

local block = WorldBuilder.block
local WOOD = Color3.fromRGB(176, 122, 74)
local DARK = Color3.fromRGB(58, 60, 72)
local STEEL = Color3.fromRGB(190, 196, 206)
local PAPER = Color3.fromRGB(255, 246, 224)
local INK = Color3.fromRGB(27, 29, 43)

local TABLE_XS = { -18, -4, 10 } -- table 3 only exists from TIER_02

local function label(parent, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.MaxDistance = 45
	gui.AlwaysOnTop = false
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = PAPER
	t.TextColor3 = INK
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = t
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = INK
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = t
	t.Parent = gui
	gui.Parent = parent
	return gui
end

-- A station is a Model with a "Base" (prompts live here) and a "Top" (items sit here).
local function station(parent, root, id, name, pos, size, topColor)
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
	label(base, name, Vector3.new(0, size.Y / 2 + 3, 0))
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

	-- shell
	block(
		model,
		"Floor",
		Vector3.new(62, 0.4, 50),
		at(0, 0.5, 0),
		Color3.fromRGB(236, 224, 200),
		Enum.Material.WoodPlanks
	)
	block(
		model,
		"KitchenFloor",
		Vector3.new(60, 0.42, 18),
		at(0, 0.52, 15),
		Color3.fromRGB(220, 222, 230),
		Enum.Material.Marble
	)
	block(model, "WallBack", Vector3.new(62, 10, 1), at(0, 5.5, 24.5), Color3.fromRGB(255, 214, 140))
	block(model, "WallLeft", Vector3.new(1, 10, 50), at(-30.5, 5.5, 0), Color3.fromRGB(255, 214, 140))
	block(model, "WallRight", Vector3.new(1, 10, 50), at(30.5, 5.5, 0), Color3.fromRGB(255, 214, 140))
	block(model, "WallFrontL", Vector3.new(48, 4, 1), at(-6, 2.5, -24.5), Color3.fromRGB(255, 214, 140))
	block(model, "WallFrontR", Vector3.new(4, 4, 1), at(28.5, 2.5, -24.5), Color3.fromRGB(255, 214, 140))
	block(model, "Counter", Vector3.new(38, 3.6, 2), at(-9, 2.5, 5), WOOD, Enum.Material.Wood)
	block(model, "CounterEnd", Vector3.new(14, 3.6, 2), at(23, 2.5, 5), WOOD, Enum.Material.Wood)

	local signPart = block(model, "Sign", Vector3.new(30, 4, 0.6), at(-6, 9, -24.8), Color3.fromRGB(255, 197, 49))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 80)
	local st = Instance.new("TextLabel")
	st.Name = "Text"
	st.Size = UDim2.fromScale(1, 1)
	st.BackgroundTransparency = 1
	st.Font = Enum.Font.LuckiestGuy
	st.TextScaled = true
	st.TextColor3 = INK
	st.Text = `{tier.name} · {owner.DisplayName}`
	st.Parent = sg
	sg.Parent = signPart
	block(model, "SignPost", Vector3.new(1, 6, 0.6), at(-20, 4, -24.8), DARK)
	block(model, "SignPost", Vector3.new(1, 6, 0.6), at(8, 4, -24.8), DARK)

	-- stations (the TIER_01 starter kit, §C7.1)
	local stations = Instance.new("Folder")
	stations.Name = "Stations"
	stations.Parent = model
	local s = {}
	local m, _, top
	m = station(stations, root, "STN_PANTRY", "Pantry", Vector3.new(-24, 3.5, 21.5), Vector3.new(7, 6, 3), WOOD)
	s.STN_PANTRY = m
	m, _, top = station(
		stations,
		root,
		"STN_CUT",
		"Cutting Board",
		Vector3.new(-15, 2.2, 21.5),
		Vector3.new(6, 3.4, 4),
		Color3.fromRGB(236, 200, 150)
	)
	slot(top, "Slot1", Vector3.zero)
	s.STN_CUT = m
	m, _, top = station(stations, root, "STN_GRILL", "Grill", Vector3.new(-6, 2.2, 21.5), Vector3.new(7, 3.4, 4), DARK)
	slot(top, "Slot1", Vector3.new(-1.6, 0, 0))
	slot(top, "Slot2", Vector3.new(1.6, 0, 0))
	s.STN_GRILL = m
	m, _, top = station(
		stations,
		root,
		"STN_FRYER",
		"Fryer",
		Vector3.new(3, 2.2, 21.5),
		Vector3.new(5, 3.4, 4),
		Color3.fromRGB(240, 196, 60)
	)
	slot(top, "Slot1", Vector3.zero)
	s.STN_FRYER = m
	m = station(
		stations,
		root,
		"STN_DRINK",
		"Drink Dispenser",
		Vector3.new(12, 3.5, 21.5),
		Vector3.new(5, 6, 3),
		Color3.fromRGB(46, 196, 182)
	)
	s.STN_DRINK = m
	m, _, top = station(
		stations,
		root,
		"STN_ASSEMBLY",
		"Assembly Counter",
		Vector3.new(-8, 2.2, 12),
		Vector3.new(14, 3.4, 4),
		Color3.fromRGB(245, 240, 230)
	)
	for i, x in { -3.5, 3.5 } do
		local board = block(
			m,
			"Board" .. i,
			Vector3.new(4.5, 0.2, 3),
			top.CFrame * CFrame.new(x, 0.25, 0),
			Color3.fromRGB(210, 170, 120),
			Enum.Material.Wood
		)
		board:SetAttribute("Board", i)
		slot(board, "Stack", Vector3.zero)
	end
	s.STN_ASSEMBLY = m
	m = station(
		stations,
		root,
		"STN_TRASH",
		"Trash",
		Vector3.new(26, 2, 14),
		Vector3.new(3, 3, 3),
		Color3.fromRGB(70, 150, 90)
	)
	s.STN_TRASH = m

	-- dining room: tables with a stool either side
	local dining = Instance.new("Folder")
	dining.Name = "Dining"
	dining.Parent = model
	local seats = {}
	for t = 1, math.ceil(tier.seats / 2) do
		local x = TABLE_XS[t]
		local tbl = block(dining, "Table" .. t, Vector3.new(4, 3, 4), at(x, 2.2, -12), WOOD, Enum.Material.Wood)
		tbl:SetAttribute("Durability", 100)
		tbl:SetAttribute("FurnitureName", "Diner Table")
		for side = -1, 1, 2 do
			local idx = #seats + 1
			local stool = Instance.new("Part")
			stool.Name = "Seat" .. idx
			stool.Shape = Enum.PartType.Cylinder
			stool.Anchored = true
			stool.Size = Vector3.new(2, 2.4, 2.4)
			stool.CFrame = at(x + side * 3.4, 1.7, -12) * CFrame.Angles(0, 0, math.rad(90))
			stool.Color = Color3.fromRGB(255, 75, 62)
			stool.Material = Enum.Material.SmoothPlastic
			stool:SetAttribute("Durability", 100)
			stool:SetAttribute("FurnitureName", "Stool")
			stool.Parent = dining
			table.insert(seats, {
				index = idx,
				part = stool,
				tablePart = tbl,
				cf = CFrame.lookAt(at(x + side * 3.4, 2.5, -12).Position, at(x, 2.5, -12).Position),
				approach = at(x + side * 3.4, 2.5, -2),
			})
		end
	end

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

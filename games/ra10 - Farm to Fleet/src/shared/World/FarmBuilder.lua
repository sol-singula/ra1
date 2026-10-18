--[[
The world Farm to Fleet is built from (the server builds it; World/Shapes parts, ra9's matte detail in the farm's
colours, master plan §1). The street: the main road along X with its lines, lamps and verges, six plots of
meadow either side a white fence apart, trees and low hills round it. A plot (World/PlotLayout's frame) gets, once
someone owns it: the shack with its porch, the soil tiles it has, the farm stand at the road, the mailbox, a dirt
track to the road and the buy-pads; then every upgrade it buys (FarmBuilder.upgrade) and the crops growing on its
tiles (FarmBuilder.crop).

  FarmBuilder.world(parent) -> { folder, plots = { [i] = plot }, count }
     plot = { index, cf, color, folder, items (the owner's: cleared when they leave), sign }
  FarmBuilder.base(plot) -> { standPad, pads = { Part x3 }, rims = { Part x3 }, tiles = {} }
  FarmBuilder.tile(plot, refs, n) -> Part     soil tile n
  FarmBuilder.crop(plot, tile, cropKey, phase, golden?)   the crop on a tile (phase 0 seed .. 3 ripe; nil clears)
  FarmBuilder.water(tile, wet)                darker soil while watered
  FarmBuilder.upgrade(plot, key)              the upgrade's piece on the plot (a pen's has its PenPad)
  FarmBuilder.animal(parent, key, at, level, facing?) -> Model   a blocky animal (bigger with its level)
  FarmBuilder.clear(plot)
  FarmBuilder.label(part, title, line?, color?)   words over a pad or a sign (a billboard sized in studs)
  FarmBuilder.sign(part, title, line?, color?, face?)   words on a part's face
  FarmBuilder.board(part, title, lines, status?, color?)   an order board's face: a title, three lines, a status
  FarmBuilder.light()
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Home = require(ReplicatedStorage.Shared.Data.Home)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local PlotLayout = require(script.Parent.PlotLayout)
local Shapes = require(script.Parent.Shapes)

local FarmBuilder = {}

local P = Constants.PALETTE
local deco = Shapes.deco
local INK = Color3.fromRGB(30, 30, 34)
local WHITE = Color3.fromRGB(250, 250, 248)
local SPOTS = PlotLayout.SPOTS
local SOIL_DARK = Color3.fromRGB(100, 68, 46)
local FLOWERS = {
	Color3.fromRGB(240, 90, 140),
	Color3.fromRGB(255, 205, 40),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(150, 110, 230),
}

-- Words -----------------------------------------------------------------------------------------------------------
function FarmBuilder.sign(part, title, line, color, face)
	local gui = part:FindFirstChild("Words") or Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local function label(name, text, y, h)
		local l = gui:FindFirstChild(name) or Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.04, y)
		l.Size = UDim2.fromScale(0.92, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = color or INK
		l.Text = text
		l.Parent = gui
	end
	if line and line ~= "" then
		label("Title", title, 0.06, 0.5)
		label("Line", line, 0.6, 0.34)
	else
		label("Title", title, 0.1, 0.8)
		local old = gui:FindFirstChild("Line")
		if old then
			old:Destroy()
		end
	end
	gui.Parent = part
	return gui
end

-- A hanging zone sign (the warehouse's RECEIVING, ROW 3...): a board readable from both sides on two chains; turn
-- = true runs it along Z instead of X
function FarmBuilder.hang(L, x, y, z, title, color, turn, width)
	local w = width or 10
	for side = 0, 1 do
		local b = L:box(x, y, z, w, 1.8, 0.2, deco({ color = color or P.safetyYellow, name = "ZoneSign" }))
		local yaw = (turn and math.pi / 2 or 0) + side * math.pi
		b.CFrame = L.cf * CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -0.06)
		FarmBuilder.sign(b, title, "", INK)
	end
	for _, d in { -w * 0.4, w * 0.4 } do
		L:box(
			x + (turn and 0 or d),
			y + 2.4,
			z + (turn and d or 0),
			0.12,
			3,
			0.12,
			deco({ color = P.steel, name = "SignChain" })
		)
	end
end

-- A board's face (an order on the order board): a title, up to three lines and a status line along the bottom
function FarmBuilder.board(part, title, lines, status, color)
	local gui = part:FindFirstChild("Board") or Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(math.floor(part.Size.X * 100), math.floor(part.Size.Y * 100))
	local function label(name, text, y, h, c, cap)
		local l = gui:FindFirstChild(name) or Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.06, y)
		l.Size = UDim2.fromScale(0.88, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextWrapped = true
		l.TextColor3 = c
		l.Text = text
		l.Parent = gui
		local k = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		k.MaxTextSize = cap
		k.Parent = l
	end
	label("Title", title, 0.04, 0.2, color or WHITE, 64)
	for i = 1, 3 do
		label("Line" .. i, lines[i] or "", 0.28 + (i - 1) * 0.15, 0.13, Color3.fromRGB(235, 240, 230), 48)
	end
	label("Status", status or "", 0.8, 0.14, color or WHITE, 44)
	gui.Parent = part
	return gui
end

function FarmBuilder.label(part, title, line, color)
	local bb = part:FindFirstChild("Over") or Instance.new("BillboardGui")
	bb.Name = "Over"
	bb.Size = UDim2.new(8, 0, 2.6, 0) -- (in studs: it shrinks with distance)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	local function label(name, text, y, h, c, cap)
		local l = bb:FindFirstChild(name) or Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = c
		l.TextStrokeTransparency = 0.15
		l.TextStrokeColor3 = INK
		l.Text = text
		l.Parent = bb
		local k = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		k.MaxTextSize = cap
		k.Parent = l
	end
	label("Title", title, 0, 0.55, WHITE, 28)
	label("Line", line or "", 0.55, 0.45, color or P.sunflower, 24)
	bb.Parent = part
	return bb
end

function FarmBuilder.light()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(120, 124, 132)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 156, 166)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.05
	Lighting.FogColor = Color3.fromRGB(196, 222, 246)
	Lighting.FogEnd = 1400
	pcall(function()
		Lighting.ShadowSoftness = 0.35
	end)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.25
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(205, 228, 250)
	atmo.Decay = Color3.fromRGB(150, 190, 235)
	atmo.Glare = 0
	atmo.Haze = 0.8
	atmo.Parent = Lighting
	local cc = Lighting:FindFirstChild("Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.18
	cc.Contrast = 0.08
	cc.Parent = Lighting
end

-- The street ------------------------------------------------------------------------------------------------------
local function tree(s, x, z, k)
	k = k or 1
	s:block(x, z, 1.4 * k, 1.4 * k, 6 * k, { color = P.wood, name = "Trunk" })
	s:block(x, z, 7 * k, 7 * k, 5 * k, { color = P.grassDark, name = "Leaves" }, 5 * k)
	s:block(x, z, 5 * k, 5 * k, 3 * k, deco({ color = P.grass, name = "Leaves" }), 9.6 * k)
end

local function lamp(s, x, z)
	s:block(x, z, 1.2, 1.2, 0.5, { color = P.concreteDark, name = "LampBase" })
	s:block(x, z, 0.5, 0.5, 11, { color = P.steel, name = "LampPost" }, 0.5)
	s:block(x, z, 1.4, 1.4, 0.6, deco({ color = P.steel }), 11.5)
	s:block(
		x,
		z,
		1,
		1,
		0.4,
		deco({ color = Color3.fromRGB(255, 244, 200), material = Enum.Material.Neon, name = "Lamp" }),
		11.1
	)
end

function FarmBuilder.world(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Farms"
	local s = Shapes.new(folder)
	local world = { folder = folder, plots = {} }
	local length = 3 * PlotLayout.WIDTH + 2 * PlotLayout.GAP + 200
	local road = PlotLayout.ROAD

	-- the ground, the road and its lines, the verges
	s:block(0, 0, 2400, 2400, 2, { color = P.grassDark, name = "Ground" }, -2)
	s:block(0, 0, length + 1200, 26, 0.3, { color = P.asphalt, name = "Road" }, 0)
	for _, side in { -1, 1 } do
		s:block(0, side * 12.4, length + 1200, 0.5, 0.34, deco({ color = WHITE, name = "EdgeLine" }), 0)
		s:block(0, side * 16.5, length + 1200, 7, 0.2, { color = P.grassLight, name = "Verge" }, 0)
	end
	for x = -length / 2 - 600, length / 2 + 600, 14 do
		s:block(x, 0, 7, 0.5, 0.34, deco({ color = P.safetyYellow, name = "CentreLine" }), 0)
	end
	for x = -length / 2 + 20, length / 2 - 20, 48 do
		for _, side in { -1, 1 } do
			lamp(s, x, side * 17.5)
		end
	end
	-- round it: trees and low hills past the plots
	local r = Random.new(10)
	for i = 1, 60 do
		local x = r:NextNumber(-length / 2 - 300, length / 2 + 300)
		local zEdge = road / 2 + PlotLayout.DEPTH + 20
		local z = (i % 2 == 0 and 1 or -1) * r:NextNumber(zEdge, zEdge + 220)
		tree(s, x, z, r:NextNumber(0.9, 1.6))
	end
	for i = 1, 14 do
		local x = -1000 + i * 140 + r:NextNumber(-30, 30)
		for _, side in { -1, 1 } do
			local h = r:NextNumber(18, 50)
			s:block(
				x,
				side * r:NextNumber(560, 720),
				r:NextNumber(120, 220),
				r:NextNumber(80, 160),
				h,
				deco({ color = i % 2 == 0 and P.grass or P.grassDark, shadow = false, name = "Hill" }),
				-2
			)
		end
	end
	for _, side in { -1, 1 } do
		tree(s, side * (length / 2 - 40), side * 40, 1.4)
	end

	-- the plots: meadow, a fence round each, the owner's sign
	for i = 1, Constants.PLOTS do
		local plotFolder = Instance.new("Folder")
		plotFolder.Name = "Plot" .. i
		plotFolder:SetAttribute("Plot", i)
		plotFolder.Parent = folder
		local items = Instance.new("Folder")
		items.Name = "Items"
		items.Parent = plotFolder
		local plot = {
			index = i,
			cf = PlotLayout.frame(i),
			color = Constants.PLOT_COLORS[i],
			folder = plotFolder,
			items = items,
		}
		local L = Shapes.new(plotFolder, plot.cf)
		local W, D, F = PlotLayout.WIDTH, PlotLayout.DEPTH, PlotLayout.EDGE
		L:block(0, D / 2 - F, W, D, 0.25, deco({ color = i % 2 == 0 and P.grass or P.grassLight, name = "Meadow" }), 0)
		-- the fence: posts and two rails on the three land sides, open to the road
		local function rail(x0, z0, x1, z1)
			local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
			local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
			local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
			for _, y in { 1.4, 2.6 } do
				L:box(
					cx,
					y,
					cz,
					alongX and len or 0.3,
					0.3,
					alongX and 0.3 or len,
					{ color = P.fenceWhite, name = "Fence" }
				)
			end
			for k = 0, math.floor(len / 8) do
				local t = k * 8 / len
				L:block(
					x0 + (x1 - x0) * t,
					z0 + (z1 - z0) * t,
					0.5,
					0.5,
					3.2,
					deco({ color = P.fenceWhite, name = "FencePost" }),
					0
				)
			end
		end
		rail(-W / 2, -F, -W / 2, D - F)
		rail(W / 2, -F, W / 2, D - F)
		rail(-W / 2, D - F, W / 2, D - F)
		-- the owner's sign by the road
		local spot = SPOTS.sign
		L:block(spot.X - 3.5, spot.Z, 0.6, 0.6, 6, { color = P.wood, name = "SignPost" }, 0)
		L:block(spot.X + 3.5, spot.Z, 0.6, 0.6, 6, { color = P.wood, name = "SignPost" }, 0)
		local board = L:box(spot.X, 5.6, spot.Z - 0.1, 9, 3, 0.4, deco({ color = P.cream, name = "OwnerSign" }))
		L:box(spot.X, 7.25, spot.Z - 0.1, 9.4, 0.3, 0.5, deco({ color = plot.color, name = "SignTrim" }))
		L:box(spot.X, 3.95, spot.Z - 0.1, 9.4, 0.3, 0.5, deco({ color = plot.color, name = "SignTrim" }))
		FarmBuilder.sign(board, "FOR SALE", "", INK)
		plot.sign = board
		world.plots[i] = plot
	end
	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	world.count = n
	folder.Parent = parent
	return world
end

-- A plot's own pieces ---------------------------------------------------------------------------------------------
-- The house: the shack a new farmer gets, and the bigger homes it grows into with the farm level (Data/Home), all
-- from one plan: walls, siding, a roof in the plot's colour, a door, windows with shutters and flower boxes, a
-- porch, a chimney; bigger tiers get a second floor of windows, a garden, hedges, trees, a fountain
local function house(L, plot, tier)
	local color = plot.color
	local T = Home.TIERS[tier] or Home.TIERS[1]
	local x, z = SPOTS.shack.X, SPOTS.shack.Z
	local w, d, h = T.w, T.d, T.h
	local wall, trim, roof = T.wall, T.trim, T.roof
	L:block(x, z, w + 1, d + 1, 0.8, { color = P.concreteDark, name = "HouseFloor" }, 0)
	L:block(x, z, w, d, h, { color = wall, name = "House" }, 0.8)
	for y = 2, h, 1.2 do
		for _, sz in { -1, 1 } do
			L:block(
				x,
				z + sz * (d / 2 + 0.05),
				w + 0.1,
				0.12,
				0.12,
				deco({ color = T.siding or wall, name = "Siding" }),
				y
			)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			L:block(x + sx * w / 2, z + sz * d / 2, 0.6, 0.6, h, deco({ color = trim, name = "Trim" }), 0.8)
		end
	end
	-- the roof: two slopes, a ridge, eaves in the plot's colour; a tall house gets a taller roof
	local rh = tier >= 4 and 6 or 4
	L:wedge(x, 0.8 + h + rh / 2, z - d / 4 - 0.3, w + 1.6, rh, d / 2 + 0.8, { color = roof, name = "Roof" }, 180)
	L:wedge(x, 0.8 + h + rh / 2, z + d / 4 + 0.3, w + 1.6, rh, d / 2 + 0.8, { color = roof, name = "Roof" }, 0)
	L:box(x, 0.8 + h + rh + 0.1, z, w + 1.8, 0.4, 0.6, deco({ color = color, name = "Ridge" }))
	-- the door and its frame, windows with shutters and flower boxes along the front
	local fz = z - d / 2
	local doorX = x - (tier >= 3 and 0 or 2.5)
	L:box(doorX, 0.8 + 3, fz - 0.1, 3, 6, 0.2, deco({ color = Color3.fromRGB(120, 72, 44), name = "Door" }))
	L:box(doorX, 0.8 + 6.2, fz - 0.15, 3.6, 0.4, 0.3, deco({ color = trim, name = "Trim" }))
	L:box(doorX + 1.3, 0.8 + 3, fz - 0.2, 0.3, 0.3, 0.2, deco({ color = P.sunflower, name = "Knob" }))
	local windows = {}
	if tier <= 2 then
		windows = { x + 3 }
	else
		for k = -math.floor(w / 10), math.floor(w / 10) do
			if math.abs(x + k * 5 - doorX) > 3.2 then
				table.insert(windows, x + k * 5)
			end
		end
	end
	local floors = tier >= 3 and 2 or 1
	for floor = 1, floors do
		local wy = 0.8 + 4.5 + (floor - 1) * (h / 2)
		for _, wx in windows do
			L:box(wx, wy, fz - 0.1, 3.4, 2.6, 0.2, deco({ color = P.glass, name = "Window" }))
			L:box(wx, wy, fz - 0.15, 3.8, 0.3, 0.3, deco({ color = trim, name = "Trim" }))
			for _, sx in { -1, 1 } do
				L:box(wx + sx * 2.3, wy, fz - 0.12, 1, 2.8, 0.2, deco({ color = color, name = "Shutter" }))
			end
			if floor == 1 then
				L:box(
					wx,
					wy - 1.6,
					fz - 0.5,
					3.6,
					0.6,
					0.8,
					deco({ color = Color3.fromRGB(120, 72, 44), name = "FlowerBox" })
				)
				for k = -1, 1 do
					L:box(
						wx + k * 1.1,
						wy - 1.1,
						fz - 0.5,
						0.6,
						0.6,
						0.6,
						deco({ color = k == 0 and P.sunflower or Color3.fromRGB(240, 90, 140), name = "Flower" })
					)
				end
			end
		end
	end
	-- the porch: a deck, posts, a little roof (a wide porch on the big homes)
	local pw = tier >= 3 and w * 0.7 or 7
	L:block(doorX, fz - 2, pw, 4, 0.8, { color = P.wood, name = "Porch" }, 0)
	for _, sx in { -1, 1 } do
		L:block(doorX + sx * (pw / 2 - 0.4), fz - 3.7, 0.5, 0.5, 6, { color = trim, name = "PorchPost" }, 0.8)
	end
	L:box(doorX, 0.8 + 6.4, fz - 2, pw + 0.6, 0.4, 4.4, { color = color, name = "PorchRoof" })
	L:block(x + w / 2 - 2.5, z + 1.5, 1.6, 1.6, 4.5, { color = P.concreteDark, name = "Chimney" }, 0.8 + h + 0.8)
	-- the garden grows with the home: a lawn path, hedges, flower beds, trees, a fountain, lanterns
	local gz = fz - 6
	L:block(
		doorX,
		(gz + SPOTS.mailbox.Z) / 2,
		4,
		gz - SPOTS.mailbox.Z + 2,
		0.12,
		deco({ color = P.concrete, name = "GardenPath" }),
		0.26
	)
	if tier >= 2 then
		for _, sx in { -1, 1 } do
			L:block(
				x + sx * (w / 2 + 2),
				fz - 4,
				1.6,
				6,
				1.6,
				deco({ color = Color3.fromRGB(60, 140, 60), name = "Hedge" }),
				0
			)
		end
	end
	if tier >= 3 then
		for k = 0, 4 do
			for _, sx in { -1, 1 } do
				local bx = doorX + sx * (4 + k * 1.1)
				L:block(bx, gz, 1, 1, 0.35, deco({ color = SOIL_DARK, name = "Bed" }), 0)
				L:box(bx, 0.75, gz, 0.35, 0.6, 0.35, deco({ color = Color3.fromRGB(70, 150, 60), name = "Stem" }))
				L:box(bx, 1.15, gz, 0.6, 0.35, 0.6, deco({ color = FLOWERS[k % #FLOWERS + 1], name = "Flower" }))
			end
		end
	end
	if tier >= 4 then
		for _, sx in { -1, 1 } do
			local tx, tz = x + sx * (w / 2 + 6), z - 2
			L:block(tx, tz, 1.2, 1.2, 5, { color = P.wood, name = "Trunk" }, 0)
			L:box(tx, 7.5, tz, 6, 5, 6, deco({ color = Color3.fromRGB(70, 150, 70), name = "Leaves" }))
		end
	end
	if tier >= 5 then
		local fx, fzz = doorX, gz - 5
		L:cyl(fx, 0.6, fzz, 1.2, 7, { color = P.concrete, name = "Fountain" }, "y")
		L:cyl(fx, 1.3, fzz, 0.3, 6, deco({ color = P.water, name = "FountainWater" }), "y")
		L:cyl(fx, 2.2, fzz, 2, 1.2, deco({ color = P.concrete, name = "FountainStem" }), "y")
		L:cyl(fx, 3.3, fzz, 0.4, 3, deco({ color = P.water, name = "FountainWater" }), "y")
		for _, sx in { -1, 1 } do
			L:block(fx + sx * 5, fzz, 0.4, 0.4, 5, { color = INK, name = "LanternPost" }, 0)
			L:box(
				fx + sx * 5,
				5.4,
				fzz,
				1,
				1,
				1,
				deco({ color = P.sunflower, material = Enum.Material.Neon, name = "Lantern" })
			)
		end
	end
	local sign =
		L:box(doorX, 0.8 + h - 0.6, fz - 0.2, math.min(w - 2, 12), 1.6, 0.2, deco({ color = trim, name = "HouseSign" }))
	FarmBuilder.sign(sign, string.upper(T.name), "", color)
end

-- The field's rail fence, round every patch it has now (rebuilt as it grows), open at the front and the path side
function FarmBuilder.fieldFence(plot, n)
	local folder = plot.items:FindFirstChild("FieldFence")
	if folder and folder:GetAttribute("Patches") == n then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "FieldFence"
	folder:SetAttribute("Patches", n)
	folder.Parent = plot.items
	local L = Shapes.new(folder, plot.cf)
	local x0, x1, z0, z1 = PlotLayout.fieldBox(n)
	local function rail(ax, az, bx, bz)
		local len = math.max(math.abs(bx - ax), math.abs(bz - az))
		local alongX = math.abs(bx - ax) > 0
		for _, y in { 1, 2 } do
			L:box(
				(ax + bx) / 2,
				y,
				(az + bz) / 2,
				alongX and len or 0.3,
				0.3,
				alongX and 0.3 or len,
				deco({ color = P.wood, name = "FieldRail" })
			)
		end
		for k = 0, math.floor(len / 6) do
			local t = k * 6 / len
			L:block(
				ax + (bx - ax) * t,
				az + (bz - az) * t,
				0.5,
				0.5,
				2.4,
				deco({ color = P.wood, name = "FieldPost" }),
				0
			)
		end
	end
	rail(x0, z0, x0, z1)
	rail(x0, z1, x1, z1)
	rail(x1, z0, x1, z1)
	rail(x0, z0, x0 + 12, z0)
	rail(x0 + 24, z0, x1, z0)
	return folder
end

-- Build (or rebuild) the home at a tier
function FarmBuilder.homeTier(plot, tier)
	local folder = plot.items:FindFirstChild("Home")
	if folder and folder:GetAttribute("Tier") == tier then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Home"
	folder:SetAttribute("Tier", tier)
	folder.Parent = plot.items
	house(Shapes.new(folder, plot.cf), plot, tier)
	return folder
end

-- The stand's building, by tier (Data/Stand): it grows with the farm level, in the same spot, the sell pad in front
local STAND = {}

local function produceCrates(L, x, z, y, n)
	for k = 0, n - 1 do
		local cx = x + (k - (n - 1) / 2) * 3
		L:block(cx, z, 2.4, 1.8, 0.9, deco({ color = Color3.fromRGB(150, 104, 64), name = "Crate" }), y)
		local key = Crops.LIST[k % 5 + 1]
		for j = -1, 1 do
			L:block(cx + j * 0.65, z, 0.55, 0.55, 0.5, deco({ color = Crops[key].color, name = "Produce" }), y + 0.9)
		end
	end
end

STAND[1] = function(L, color)
	local x, z = SPOTS.stand.X, SPOTS.stand.Z
	L:block(x, z, 10, 4, 3, { color = P.wood, name = "Stand" }, 0)
	L:block(x, z, 10.6, 4.6, 0.4, deco({ color = P.cream, name = "Counter" }), 3)
	for _, sx in { -1, 1 } do
		L:block(x + sx * 4.8, z + 1.8, 0.5, 0.5, 4.5, { color = P.cream, name = "StandPost" }, 3.4)
	end
	L:box(x, 3.4 + 4.7, z + 1, 11, 0.4, 3.2, { color = color, name = "StandRoof" })
	produceCrates(L, x, z - 0.6, 3.4, 3)
	local board = L:box(x, 1.6, z - 2.1, 7, 1.6, 0.2, deco({ color = P.cream, name = "StandSign" }))
	FarmBuilder.sign(board, "FARM STAND", "", P.barnRed)
end

-- a striped awning across the front, on posts
local function awning(L, x, z, w, y, color)
	local n = math.floor(w / 1.5)
	for k = 0, n - 1 do
		L:wedge(
			x - w / 2 + 0.75 + k * 1.5,
			y,
			z,
			1.5,
			1.4,
			3,
			deco({ color = k % 2 == 0 and color or WHITE, name = "Awning" }),
			180
		)
	end
end

STAND[2] = function(L, color)
	-- the produce stall: a long counter under a striped awning, barrels and baskets out front
	local x, z = SPOTS.stand.X, SPOTS.stand.Z
	L:block(x, z + 0.5, 14, 5, 3, { color = P.wood, name = "Stand" }, 0)
	L:block(x, z + 0.5, 14.6, 5.6, 0.4, deco({ color = P.cream, name = "Counter" }), 3)
	for _, sx in { -1, 1 } do
		L:block(x + sx * 6.9, z - 1.8, 0.5, 0.5, 4.6, { color = P.cream, name = "StandPost" }, 3.4)
		L:block(x + sx * 6.9, z + 2.8, 0.5, 0.5, 5.6, { color = P.cream, name = "StandPost" }, 3.4)
	end
	L:box(x, 9.2, z + 1.4, 15, 0.4, 3.4, { color = color, name = "StandRoof" })
	awning(L, x, z - 2.2, 15, 8.4, color)
	produceCrates(L, x, z - 0.4, 3.4, 4)
	for _, sx in { -1, 1 } do
		L:cyl(x + sx * 9, 1.1, z - 1, 2.2, 1.8, { color = Color3.fromRGB(140, 90, 50), name = "Barrel" }, "y")
		L:box(x + sx * 9, 2.4, z - 1, 1.5, 0.5, 1.5, deco({ color = Crops.tomato.color, name = "Produce" }))
	end
	local board = L:box(x, 1.6, z - 2.1, 9, 1.8, 0.2, deco({ color = P.cream, name = "StandSign" }))
	FarmBuilder.sign(board, "PRODUCE STALL", "", P.barnRed)
end

STAND[3] = function(L, color)
	-- the farm shop: a little shop with a gable roof, a wide open counter window, window boxes, a hanging sign
	local x, z = SPOTS.stand.X, SPOTS.stand.Z + 1
	local w, d, h = 16, 8, 8
	L:block(x, z, w + 1, d + 1, 0.6, { color = P.concreteDark, name = "StandFloor" }, 0)
	L:block(x, z + d / 2 - 0.3, w, 0.6, h, { color = P.cream, name = "Stand" }, 0.6) -- back wall
	for _, sx in { -1, 1 } do
		L:block(x + sx * (w / 2 - 0.3), z, 0.6, d, h, { color = P.cream, name = "Stand" }, 0.6)
		-- the front wall either side of the window
		L:block(x + sx * (w / 2 - 1.5), z - d / 2 + 0.3, 3, 0.6, h, { color = P.cream, name = "Stand" }, 0.6)
	end
	L:block(x, z - d / 2 + 0.3, w - 6, 0.6, 3, { color = P.wood, name = "Counter" }, 0.6)
	L:block(x, z - d / 2 + 0.3, w, 0.6, 1.6, { color = P.cream, name = "Stand" }, h - 1)
	L:wedge(x, h + 0.6 + 1.6, z - d / 4, w + 1, 3.2, d / 2 + 0.6, { color = color, name = "StandRoof" }, 180)
	L:wedge(x, h + 0.6 + 1.6, z + d / 4, w + 1, 3.2, d / 2 + 0.6, { color = color, name = "StandRoof" }, 0)
	produceCrates(L, x, z - d / 2 + 0.3, 3.6, 3)
	for _, sx in { -1, 1 } do
		L:block(x + sx * (w / 2 - 1.5), z - d / 2 - 0.4, 2.6, 0.8, 0.6, deco({ color = P.wood, name = "WindowBox" }), 3)
		for k = -1, 1 do
			L:box(
				x + sx * (w / 2 - 1.5) + k * 0.8,
				3.9,
				z - d / 2 - 0.4,
				0.6,
				0.5,
				0.6,
				deco({ color = FLOWERS[(k + 2) % #FLOWERS + 1], name = "Flower" })
			)
		end
	end
	local board = L:box(x, h + 0.6 + 0.2, z - d / 2 - 0.1, 10, 1.6, 0.25, deco({ color = color, name = "StandSign" }))
	FarmBuilder.sign(board, "FARM SHOP", "", WHITE)
end

STAND[4] = function(L, color)
	-- the country market: a bigger two-tone hall, an awning the whole width, crates outside, a big sign on the roof
	local x, z = SPOTS.stand.X, SPOTS.stand.Z + 1.5
	local w, d, h = 20, 9, 10
	L:block(x, z, w + 1, d + 1, 0.6, { color = P.concreteDark, name = "StandFloor" }, 0)
	L:block(x, z + d / 2 - 0.3, w, 0.6, h, { color = P.barnRed, name = "Stand" }, 0.6)
	for _, sx in { -1, 1 } do
		L:block(x + sx * (w / 2 - 0.3), z, 0.6, d, h, { color = P.barnRed, name = "Stand" }, 0.6)
		L:block(x + sx * (w / 2 - 1.5), z - d / 2 + 0.3, 3, 0.6, h, { color = P.barnRed, name = "Stand" }, 0.6)
	end
	L:block(x, z - d / 2 + 0.3, w - 6, 0.6, 3, { color = P.wood, name = "Counter" }, 0.6)
	L:block(x, z - d / 2 + 0.3, w, 0.6, 2, { color = WHITE, name = "Stand" }, h - 1.4)
	L:box(x, h + 0.9, z, w + 1.2, 0.6, d + 1.2, { color = Color3.fromRGB(70, 74, 82), name = "StandRoof" })
	awning(L, x, z - d / 2 - 1.6, w, 6.6, color)
	produceCrates(L, x, z - d / 2 + 0.3, 3.6, 4)
	produceCrates(L, x, z - d / 2 - 3.8, 0, 2)
	local board = L:box(x, h + 2.8, z - d / 2 + 0.6, 14, 3, 0.4, deco({ color = WHITE, name = "StandSign" }))
	FarmBuilder.sign(board, "COUNTRY MARKET", "", P.barnRed)
end

-- Build (or rebuild) the stand at a tier; the awning upgrade's own awning only shows on the cart stand
function FarmBuilder.standTier(plot, tier)
	local folder = plot.items:FindFirstChild("StandBuilding")
	if folder and folder:GetAttribute("Tier") == tier then
		return folder
	end
	if folder then
		folder:Destroy()
	end
	if plot.items:FindFirstChild("marketHall") then
		return nil
	end
	folder = Instance.new("Folder")
	folder.Name = "StandBuilding"
	folder:SetAttribute("Tier", tier)
	folder.Parent = plot.items
	STAND[tier](Shapes.new(folder, plot.cf), plot.color)
	local cart = plot.items:FindFirstChild("awning")
	if tier > 1 and cart then
		cart:ClearAllChildren()
	end
	return folder
end

local function stand(L)
	-- the pad in front: stand on it to sell
	local x, z = SPOTS.stand.X, SPOTS.stand.Z
	L:block(x, z - 7.5, 7, 4, 0.3, deco({ color = P.sunflower, name = "SellRim" }), 0.25)
	local pad = L:block(x, z - 7.5, 6.2, 3.2, 0.4, { color = WHITE, name = "SellPad" }, 0.25)
	return pad
end

-- The little things that make it a farm: flower beds by the shack, a stepping-stone path from the spawn to the soil,
-- hay bales, barrels and crates by the stand, bushes along the fence, a bench, a water trough, a lantern post
local function bush(L, x, z, r)
	local leaf = deco({ color = Color3.fromRGB(70, 150, 70), name = "Bush" })
	local b = L:box(x, r * 0.55, z, r * 1.4, r * 1.1, r * 1.4, leaf)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = b
	local b2 = L:box(
		x + r * 0.5,
		r * 0.45,
		z - r * 0.3,
		r,
		r * 0.9,
		r,
		deco({ color = Color3.fromRGB(95, 175, 85), name = "Bush" })
	)
	mesh:Clone().Parent = b2
end

function FarmBuilder.decor(L, plot)
	local S = SPOTS
	-- flower beds along the shack's front
	local sx, sz = S.shack.X, S.shack.Z - 5 - 0.6
	for i = 0, 5 do
		local x = sx + 2 + i * 1.1
		L:block(x, sz - 1.2, 1, 1, 0.35, deco({ color = SOIL_DARK, name = "Bed" }), 0)
		L:box(x, 0.75, sz - 1.2, 0.35, 0.6, 0.35, deco({ color = Color3.fromRGB(70, 150, 60), name = "Stem" }))
		L:box(x, 1.15, sz - 1.2, 0.6, 0.35, 0.6, deco({ color = FLOWERS[i % #FLOWERS + 1], name = "Flower" }))
	end
	-- stepping stones from the spawn to the soil
	local a = Vector3.new(S.spawn.X, 0, S.spawn.Z + 2)
	local b = Vector3.new(S.soil.X + 6, 0, S.soil.Z - 5)
	for i = 0, 6 do
		local p = a:Lerp(b, i / 6)
		L:block(
			p.X + (i % 2 == 0 and 0.4 or -0.4),
			p.Z,
			1.8,
			1.4,
			0.18,
			deco({ color = i % 2 == 0 and P.concrete or P.concreteDark, name = "Stone" }),
			0.22
		)
	end
	-- by the stand: hay bales, barrels, a stack of crates
	local st = S.stand
	for i = 0, 1 do
		L:block(
			st.X - 8,
			st.Z + 1 - i * 2.6,
			3,
			2.2,
			1.8,
			{ color = Color3.fromRGB(225, 190, 90), name = "HayBale" },
			0
		)
		L:block(
			st.X - 8,
			st.Z + 1 - i * 2.6,
			3.05,
			0.2,
			1.85,
			deco({ color = Color3.fromRGB(170, 130, 60), name = "Twine" }),
			0
		)
	end
	L:block(st.X - 8, st.Z - 0.3, 2.8, 2, 1.6, { color = Color3.fromRGB(225, 190, 90), name = "HayBale" }, 1.8)
	for i = 0, 1 do
		local x, z = st.X + 1.5 + i * 2.3, st.Z + 4.2
		L:cyl(x, 1.1, z, 2.2, 1.8, { color = Color3.fromRGB(140, 90, 50), name = "Barrel" }, "y")
		for _, y in { 0.4, 1.8 } do
			L:cyl(x, y, z, 0.18, 1.86, deco({ color = P.steel, name = "Hoop" }), "y")
		end
	end
	for i = 0, 2 do
		L:block(
			st.X - 9 + (i % 2) * 1.6,
			st.Z + 4,
			1.5,
			1.5,
			1.3,
			deco({ color = Color3.fromRGB(170, 120, 70), name = "Crate" }),
			i == 2 and 1.3 or 0
		)
	end
	-- a bench and a lantern post on the drive, a water trough by the well
	local bx, bz = S.mailbox.X - 5, S.mailbox.Z + 4
	L:block(bx, bz, 4, 1.2, 0.25, { color = P.wood, name = "Bench" }, 1.2)
	L:box(bx, 2.1, bz + 0.55, 4, 1, 0.2, deco({ color = P.wood, name = "BenchBack" }))
	for _, dx in { -1.7, 1.7 } do
		L:block(bx + dx, bz, 0.3, 1, 1.2, deco({ color = INK, name = "BenchLeg" }), 0)
	end
	local lx, lz = S.mailbox.X + 3, S.mailbox.Z
	L:block(lx, lz, 0.4, 0.4, 6, { color = INK, name = "LanternPost" }, 0)
	L:box(lx, 6.4, lz, 1, 1.1, 1, deco({ color = P.sunflower, material = Enum.Material.Neon, name = "Lantern" }))
	L:box(lx, 7.1, lz, 1.3, 0.3, 1.3, deco({ color = INK, name = "LanternCap" }))
	local w = S.well
	L:block(w.X + 6, w.Z + 1, 4, 1.6, 1.2, { color = P.wood, name = "Trough" }, 0)
	L:block(w.X + 6, w.Z + 1, 3.5, 1.1, 0.2, deco({ color = P.water, name = "TroughWater" }), 1.05)
	-- bushes along the back of the shack's yard and by the drive
	for _, b2 in { { -66, -62 }, { -48, -60 }, { 8, -100 }, { -44, -110 } } do
		bush(L, b2[1], b2[2], 1.6)
	end
	_ = plot
end

function FarmBuilder.base(plot)
	local L = Shapes.new(plot.items, plot.cf)
	FarmBuilder.homeTier(plot, 1)
	local refs = { tiles = {} }
	refs.standPad = stand(L)
	FarmBuilder.standTier(plot, 1)
	FarmBuilder.label(refs.standPad, "SELL", "stand here", P.sunflower)
	-- the mailbox, the dirt track from the road to the shack
	local m = SPOTS.mailbox
	L:block(m.X, m.Z, 0.4, 0.4, 3.4, { color = P.wood, name = "MailPost" }, 0)
	L:box(m.X, 3.9, m.Z, 1.2, 1, 1.8, deco({ color = plot.color, name = "Mailbox" }))
	L:block(-50, -95, 9, 30, 0.12, deco({ color = Color3.fromRGB(160, 120, 84), name = "Track" }), 0.24)
	-- the farm path: from the stand past the soil, the fields and the barn to the pens, so it's all one walk
	local fp = SPOTS.farmPath
	local dirt = deco({ color = Color3.fromRGB(176, 136, 96), name = "FarmPath" })
	L:block(fp.x, (fp.z0 + fp.z1) / 2, fp.w, fp.z1 - fp.z0, 0.12, dirt, 0.24)
	L:block(fp.x - 9, fp.z0, 18, fp.w, 0.12, dirt, 0.24)
	L:block((fp.x - 80) / 2, fp.pens, fp.x + 80, fp.w, 0.12, dirt, 0.24)
	L:block(-42, -20, fp.w, 10, 0.12, dirt, 0.24) -- (the field to the barn's doors)
	-- the pens' own path, down the middle
	L:block(SPOTS.path.X, SPOTS.path.Z, fp.w, 86, 0.12, dirt, 0.24)
	-- signposts where the paths meet
	for _, sp in { { fp.x - 5.5, -44, "FIELD" }, { fp.x - 5.5, -2, "BARN" }, { fp.x - 5.5, fp.pens + 5, "ANIMALS" } } do
		L:block(sp[1], sp[2], 0.4, 0.4, 4, { color = P.wood, name = "SignPost" }, 0)
		local board = L:box(sp[1], 4.2, sp[2], 0.3, 1.4, 4.4, deco({ color = P.cream, name = "PathSign" }))
		FarmBuilder.sign(board, sp[3], "", plot.color, Enum.NormalId.Left)
	end
	FarmBuilder.decor(L, plot)
	-- the buy-pads
	refs.pads, refs.rims = {}, {}
	for slot, at in SPOTS.pads do
		refs.rims[slot] = L:block(at.X, at.Z, 6, 6, 0.3, deco({ color = plot.color, name = "PadRim" }), 0.25)
		local pad = L:block(at.X, at.Z, 5.2, 5.2, 0.4, { color = WHITE, name = "BuyPad" }, 0.25)
		pad:SetAttribute("Slot", slot)
		pad:SetAttribute("Plot", plot.index)
		refs.pads[slot] = pad
	end
	return refs
end

function FarmBuilder.tile(plot, refs, n)
	if refs.tiles[n] then
		return refs.tiles[n]
	end
	local L = Shapes.new(plot.items, plot.cf)
	local at = PlotLayout.soilTile(n)
	local T = PlotLayout.TILE
	-- wooden edge boards, the soil, three furrows
	for _, sx in { -1, 1 } do
		L:block(at.X + sx * (T / 2 + 0.2), at.Z, 0.4, T + 0.8, 0.9, deco({ color = P.wood, name = "Board" }), 0.2)
		L:block(at.X, at.Z + sx * (T / 2 + 0.2), T + 0.8, 0.4, 0.9, deco({ color = P.wood, name = "Board" }), 0.2)
	end
	local tile = L:block(at.X, at.Z, T, T, 0.7, { color = P.soil, name = "Soil", query = true }, 0.2)
	tile:SetAttribute("Tile", n)
	tile:SetAttribute("Plot", plot.index)
	for k = -1, 1 do
		L:block(
			at.X + k * 1.8,
			at.Z,
			0.7,
			T - 0.6,
			0.18,
			deco({ color = Color3.fromRGB(100, 68, 46), name = "Furrow" }),
			0.9
		)
	end
	refs.tiles[n] = tile
	return tile
end

function FarmBuilder.water(tile, wet)
	tile.Color = wet and P.soilWet or P.soil
end

-- A crop on a tile: phase 0 (a seed mound with a sprout) to 3 (ripe); golden ones glow. Each crop has its own plant,
-- built from turned leaves, round fruit (sphere meshes) and stems, so a field reads at a glance: strawberry
-- rosettes with white flowers then red berries, feathery carrot tops over orange shoulders, tall corn with arching
-- leaves, tassels and cobs, staked tomato vines, round blueberry bushes, a fruit tree a tile (apples, oranges),
-- sprawling vines with big leaves under pumpkins and melons.
local function cropPart(model, cf, size, color, name, shape, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Name = name
	if shape == "ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape == "cyl" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = model
	return p
end

local CROPS = {}

-- (a leaf: a thin slab leaning out from the stem at `tilt` degrees, turned `yaw` round it)
local function leafCF(base, yaw, tilt, len, y)
	return base
		* CFrame.Angles(0, math.rad(yaw), 0)
		* CFrame.new(0, y or 0, -len * 0.45)
		* CFrame.Angles(math.rad(-tilt), 0, 0)
end

CROPS.strawberry = function(m, base, k, phase, fruit, fm, leaf, light)
	for i = 0, 4 do
		local cf = leafCF(base, i * 72, 28, 1.1 * k, 0.25 * k)
		cropPart(m, cf, Vector3.new(0.75 * k, 0.1, 1.1 * k), i % 2 == 0 and leaf or light, "Leaf")
	end
	if phase == 2 then
		for i = 0, 1 do
			local cf = base * CFrame.Angles(0, math.rad(40 + i * 180), 0) * CFrame.new(0.45, 0.55, 0)
			cropPart(m, cf, Vector3.new(0.35, 0.1, 0.35), WHITE, "Flower")
		end
	elseif phase == 3 then
		for i = 0, 2 do
			local cf = base * CFrame.Angles(0, math.rad(20 + i * 120), 0) * CFrame.new(0.75, 0.3, 0)
			cropPart(m, cf, Vector3.new(0.42, 0.55, 0.42), fruit, "Fruit", "ball", fm)
		end
	end
end

CROPS.carrot = function(m, base, k, phase, fruit, fm, leaf, light)
	for i = 0, 4 do
		local cf = base
			* CFrame.Angles(0, math.rad(i * 72), 0)
			* CFrame.Angles(math.rad(18), 0, 0)
			* CFrame.new(0, 0.9 * k + 0.2, 0)
		cropPart(m, cf, Vector3.new(0.12, 1.8 * k, 0.12), i % 2 == 0 and leaf or light, "Leaf")
		cropPart(m, cf * CFrame.new(0, 0.7 * k, -0.18), Vector3.new(0.35 * k, 0.06, 0.45 * k), light, "Leaf")
	end
	if phase >= 2 then
		local big = phase == 3 and 0.75 or 0.45
		cropPart(m, base * CFrame.new(0, 0.12, 0), Vector3.new(big, big * 0.7, big), fruit, "Fruit", "ball", fm)
	end
end

CROPS.corn = function(m, base, k, phase, fruit, fm, leaf, light)
	local h = 6 * k
	cropPart(
		m,
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(h, 0.35, 0.35),
		leaf,
		"Stalk",
		"cyl"
	)
	for i = 0, 3 do
		local cf = leafCF(base, i * 90 + 30, 35, 2.2 * k, h * (0.3 + 0.17 * i))
		cropPart(m, cf, Vector3.new(0.3, 0.06, 2.2 * k), i % 2 == 0 and leaf or light, "Leaf")
	end
	if phase >= 2 then
		for i = 0, 2 do
			local cf = base * CFrame.new(0, h + 0.3, 0) * CFrame.Angles(0, math.rad(i * 60), math.rad(25))
			cropPart(m, cf, Vector3.new(0.08, 0.8, 0.08), Color3.fromRGB(200, 170, 90), "Tassel")
		end
	end
	if phase == 3 then
		for i = 0, 1 do
			local cf = base
				* CFrame.Angles(0, math.rad(i * 180 + 45), 0)
				* CFrame.new(0.3, h * 0.55, 0)
				* CFrame.Angles(0, 0, math.rad(-20))
			cropPart(m, cf, Vector3.new(0.5, 1.4, 0.5), fruit, "Fruit", "ball", fm)
			cropPart(m, cf * CFrame.new(0.12, -0.2, 0), Vector3.new(0.3, 1.2, 0.55), light, "Husk", "ball")
		end
	end
end

CROPS.tomato = function(m, base, k, phase, fruit, fm, leaf, light)
	local h = 3.6 * k
	cropPart(m, base * CFrame.new(0.15, 2, 0.15), Vector3.new(0.14, 4, 0.14), P.wood, "Stake")
	cropPart(m, base * CFrame.new(0, h / 2, 0), Vector3.new(0.14, h, 0.14), leaf, "Vine")
	for i = 0, 3 do
		for j = 0, 1 do
			local cf = leafCF(base, i * 95 + j * 180, 30, 0.9 * k, h * (0.25 + 0.22 * i))
			cropPart(m, cf, Vector3.new(0.7 * k, 0.08, 0.9 * k), (i + j) % 2 == 0 and leaf or light, "Leaf")
		end
	end
	if phase >= 2 then
		local ripe = phase == 3
		for i = 0, ripe and 3 or 1 do
			local cf = base * CFrame.Angles(0, math.rad(60 + i * 95), 0) * CFrame.new(0.6, h * (0.3 + 0.18 * i), 0)
			cropPart(
				m,
				cf,
				Vector3.new(0.45, 0.4, 0.45),
				ripe and fruit or light,
				ripe and "Fruit" or "Green",
				"ball",
				ripe and fm or nil
			)
		end
	end
end

CROPS.blueberry = function(m, base, k, phase, fruit, fm, leaf, light)
	for i = 0, 2 do
		local cf = base * CFrame.Angles(0, math.rad(i * 120), 0) * CFrame.new(0.35 * k, 0.75 * k, 0)
		cropPart(m, cf, Vector3.new(1.3 * k, 1.2 * k, 1.3 * k), i == 1 and light or leaf, "Leaf", "ball")
	end
	if phase == 3 then
		for i = 0, 6 do
			local a = math.rad(i * 51)
			local cf = base * CFrame.new(math.cos(a) * 0.8, 0.55 + (i % 3) * 0.35, math.sin(a) * 0.8)
			cropPart(m, cf, Vector3.new(0.26, 0.26, 0.26), fruit, "Fruit", "ball", fm)
		end
	end
end

-- a fruit tree: one a tile, in its middle
CROPS.tree = function(m, base, k, phase, fruit, fm, leaf, light)
	local h = 3.2 * k
	cropPart(
		m,
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(h, 0.55, 0.55),
		P.wood,
		"Trunk",
		"cyl"
	)
	local crowns = { { 0, 0, 0, 3 }, { 0.9, -0.3, 0.5, 2.2 }, { -0.8, -0.4, -0.6, 2.3 }, { 0.2, 0.7, -0.2, 2 } }
	for i, c in crowns do
		cropPart(
			m,
			base * CFrame.new(c[1] * k, h + 0.8 * k + c[2] * k, c[3] * k),
			Vector3.new(c[4] * k, c[4] * 0.85 * k, c[4] * k),
			i % 2 == 0 and light or leaf,
			"Leaf",
			"ball"
		)
	end
	if phase >= 2 then
		local n = phase == 3 and 7 or 0
		for i = 1, n do
			local a = math.rad(i * 51)
			local cf = base * CFrame.new(math.cos(a) * 1.35 * k, h + 0.5 * k + (i % 3) * 0.45, math.sin(a) * 1.35 * k)
			cropPart(m, cf, Vector3.new(0.48, 0.48, 0.48), fruit, "Fruit", "ball", fm)
		end
		if phase == 2 then
			for i = 1, 4 do
				local a = math.rad(i * 90 + 20)
				cropPart(
					m,
					base * CFrame.new(math.cos(a) * 1.3, h + 0.9, math.sin(a) * 1.3),
					Vector3.new(0.3, 0.3, 0.3),
					Color3.fromRGB(255, 225, 235),
					"Blossom",
					"ball"
				)
			end
		end
	end
end

-- a vine sprawling over the tile under one big fruit (pumpkins, melons)
CROPS.vine = function(m, base, k, phase, fruit, fm, leaf, light, key)
	for i = 0, 3 do
		local a = i * 90 + 20
		local cf = base
			* CFrame.Angles(0, math.rad(a), 0)
			* CFrame.new(0, 0.35 * k, -1.5 * k)
			* CFrame.Angles(math.rad(-12), 0, 0)
		cropPart(m, cf, Vector3.new(1.5 * k, 0.1, 1.5 * k), i % 2 == 0 and leaf or light, "Leaf")
		cropPart(
			m,
			base * CFrame.Angles(0, math.rad(a + 40), 0) * CFrame.new(0, 0.15, -0.9 * k),
			Vector3.new(0.12, 0.12, 1.8 * k),
			leaf,
			"Vine"
		)
	end
	if phase >= 2 then
		local ripe = phase == 3
		local s = ripe and 1 or 0.55
		if key == "watermelon" then
			cropPart(
				m,
				base * CFrame.new(0, 0.65 * s, 0),
				Vector3.new(2.3 * s, 1.3 * s, 1.5 * s),
				fruit,
				"Fruit",
				"ball",
				fm
			)
			for i = -1, 1 do
				cropPart(
					m,
					base * CFrame.new(i * 0.55 * s, 1.27 * s, 0),
					Vector3.new(0.14, 0.06, 1.1 * s),
					Color3.fromRGB(30, 100, 40),
					"Stripe"
				)
			end
		else
			local color = ripe and fruit or Color3.fromRGB(150, 180, 70)
			cropPart(
				m,
				base * CFrame.new(0, 0.7 * s, 0),
				Vector3.new(1.6 * s, 1.3 * s, 1.9 * s),
				color,
				"Fruit",
				"ball",
				ripe and fm or nil
			)
			for _, sx in { -1, 1 } do
				cropPart(
					m,
					base * CFrame.new(sx * 0.5 * s, 0.68 * s, 0),
					Vector3.new(1.1 * s, 1.2 * s, 1.75 * s),
					color,
					"Fruit",
					"ball",
					ripe and fm or nil
				)
			end
			cropPart(
				m,
				base * CFrame.new(0, 1.45 * s, 0) * CFrame.Angles(0, 0, math.rad(12)),
				Vector3.new(0.2, 0.45, 0.2),
				Color3.fromRGB(110, 80, 40),
				"Stem"
			)
		end
	end
end

function FarmBuilder.crop(_plot, tile, key, phase, golden)
	local old = tile:FindFirstChild("Crop")
	if old then
		old:Destroy()
	end
	if not key then
		return nil
	end
	local c = Crops[key]
	local model = Instance.new("Model")
	model.Name = "Crop"
	model:SetAttribute("Crop", key)
	model:SetAttribute("Phase", phase)
	model.Parent = tile
	local top = tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0)
	local fruit = golden and P.sunflower or c.color
	local fm = golden and Enum.Material.Neon or nil
	local leaf = c.leaf
	local light = c.leaf:Lerp(Color3.new(1, 1, 0.8), 0.25)
	local spots = { { -1.6, -1.5 }, { 1.6, -1.5 }, { -1.6, 1.5 }, { 1.6, 1.5 } }
	if phase == 0 then
		-- seed mounds, each with a tiny sprout
		for i, p in spots do
			local at = top * CFrame.new(p[1], 0, p[2])
			cropPart(model, at * CFrame.new(0, 0.12, 0), Vector3.new(1, 0.3, 1), SOIL_DARK, "Mound", "ball")
			cropPart(
				model,
				at * CFrame.Angles(0, math.rad(i * 50), math.rad(30)) * CFrame.new(0, 0.35, 0),
				Vector3.new(0.08, 0.35, 0.22),
				light,
				"Sprout"
			)
		end
		return model
	end
	local k = 0.45 + 0.55 * phase / 3
	local build = CROPS[key]
	if c.regrow then
		CROPS.tree(model, top, k, phase, fruit, fm, leaf, light)
	elseif key == "pumpkin" or key == "watermelon" or key == "goldpumpkin" then
		CROPS.vine(model, top, k, phase, fruit, fm, leaf, light, key)
	else
		build = build or CROPS.strawberry
		for i, p in spots do
			build(
				model,
				top * CFrame.new(p[1], 0, p[2]) * CFrame.Angles(0, math.rad(i * 37), 0),
				k,
				phase,
				fruit,
				fm,
				leaf,
				light
			)
		end
	end
	if phase == 3 then
		-- a soft sparkle over a ripe tile, so it reads "ready" from across the field
		local p = cropPart(
			model,
			top * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)),
			Vector3.new(0.6, 0.6, 0.6),
			golden and P.sunflower or WHITE,
			"Ripe",
			nil,
			Enum.Material.Neon
		)
		p.Transparency = 0.2
	end
	return model
end

-- The upgrades' pieces --------------------------------------------------------------------------------------------
local BUILD = {}

BUILD.well = function(L, plot)
	local w = SPOTS.well
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		L:block(
			w.X + math.cos(a) * 2.2,
			w.Z + math.sin(a) * 2.2,
			1.6,
			1.6,
			2.4,
			{ color = k % 2 == 0 and P.concreteDark or P.concrete, name = "WellStone" },
			0
		)
	end
	L:block(w.X, w.Z, 3, 3, 1.6, deco({ color = P.water, name = "WellWater" }), 0.4)
	for _, sx in { -1, 1 } do
		L:block(w.X + sx * 2.4, w.Z, 0.5, 0.5, 5, { color = P.wood, name = "WellPost" }, 2.4)
	end
	L:box(w.X, 7.6, w.Z, 0.3, 0.3, 5, deco({ color = P.wood, name = "WellBar" }))
	L:wedge(w.X, 8.6, w.Z - 1.2, 6.4, 1.8, 2.6, { color = plot.color, name = "WellRoof" }, 180)
	L:wedge(w.X, 8.6, w.Z + 1.2, 6.4, 1.8, 2.6, { color = plot.color, name = "WellRoof" }, 0)
	L:box(w.X, 5.6, w.Z, 0.9, 1, 0.9, deco({ color = P.steel, name = "Bucket" }))
end

BUILD.wheelbarrow = function(L)
	local w = SPOTS.wheelbarrow
	L:box(w.X, 1.6, w.Z, 2.6, 1.2, 1.8, { color = Color3.fromRGB(40, 140, 80), name = "Barrow" })
	L:box(w.X, 2.3, w.Z, 2.2, 0.4, 1.4, deco({ color = Crops.strawberry.color, name = "Produce" }))
	L:cyl(w.X + 1.6, 0.6, w.Z, 0.4, 1.2, deco({ color = INK, name = "Wheel" }), "z")
	for _, sz in { -0.6, 0.6 } do
		L:box(w.X - 2.1, 1.4, w.Z + sz, 2, 0.25, 0.25, deco({ color = P.wood, name = "Handle" }))
	end
end

BUILD.fence = function(L)
	-- a white picket fence round the house's garden, open at the track (the field has its own rails)
	local x0, x1, z0, z1 = -76, -50, -88, -52
	local function run(ax, az, bx, bz)
		local len = math.max(math.abs(bx - ax), math.abs(bz - az))
		local alongX = math.abs(bx - ax) > 0
		for k = 0, math.floor(len / 1.5) do
			local t = k * 1.5 / len
			L:block(
				ax + (bx - ax) * t,
				az + (bz - az) * t,
				0.5,
				0.5,
				2.6,
				deco({ color = P.fenceWhite, name = "Picket" }),
				0
			)
		end
		local cx, cz = (ax + bx) / 2, (az + bz) / 2
		L:box(
			cx,
			1.8,
			cz,
			alongX and len or 0.25,
			0.3,
			alongX and 0.25 or len,
			deco({ color = P.fenceWhite, name = "PicketRail" })
		)
	end
	run(x0, z1, x1, z1)
	run(x0, z0, x0, z1)
	run(x1, z0, x1, z1)
	run(x0, z0, -66, z0)
	run(-58, z0, x1, z0)
end

BUILD.sprinkler = function(L, plot)
	-- a sprinkler by every patch the field can ever have (all of them grow faster)
	for n = 1, PlotLayout.MAX_SOIL do
		local at = PlotLayout.soilTile(n)
		local x, z = at.X + PlotLayout.TILE / 2 + 0.8, at.Z + PlotLayout.TILE / 2 + 0.8
		L:block(x, z, 0.3, 0.3, 2, deco({ color = P.steel, name = "SprinklerPipe" }), 0)
		L:box(x, 2.15, z, 0.7, 0.3, 0.7, deco({ color = P.water, name = "SprinklerHead" }))
	end
	-- the water tower that feeds them, by the shack: four legs, cross braces, a round tank, a ladder, the farm's colour
	local w = SPOTS.waterTower
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			L:block(w.X + sx * 3, w.Z + sz * 3, 0.6, 0.6, 14, { color = P.steel, name = "TowerLeg" }, 0)
		end
		L:box(w.X + sx * 3, 7, w.Z, 0.3, 0.3, 6.2, deco({ color = P.steel, name = "TowerBrace" }))
		L:box(w.X, 7, w.Z + sx * 3, 6.2, 0.3, 0.3, deco({ color = P.steel, name = "TowerBrace" }))
	end
	L:cyl(w.X, 17, w.Z, 6, 8.5, { color = P.steelLight, name = "WaterTank" }, "y")
	L:cyl(w.X, 18.2, w.Z, 1.4, 8.6, deco({ color = plot.color, name = "TankStripe" }), "y")
	L:cyl(w.X, 20.4, w.Z, 0.8, 7, deco({ color = P.steel, name = "TankRoof" }), "y")
	L:cyl(w.X, 21.1, w.Z, 0.6, 4, deco({ color = P.steel, name = "TankRoof" }), "y")
	L:box(w.X + 4.4, 9, w.Z, 0.2, 18, 1, deco({ color = P.steel, name = "Ladder" }))
	L:block(w.X, w.Z, 0.8, 0.8, 14, deco({ color = P.water, name = "TowerPipe" }), 0)
	local board = L:box(w.X, 17, w.Z - 4.3, 6, 2, 0.2, deco({ color = WHITE, name = "TankSign" }))
	FarmBuilder.sign(board, "WATER", "", plot.color)
end

BUILD.awning = function(L, plot)
	local building = plot.items:FindFirstChild("StandBuilding")
	if building and (building:GetAttribute("Tier") or 1) > 1 then
		return -- (the bigger stands have their own awnings)
	end
	local x, z = SPOTS.stand.X, SPOTS.stand.Z
	for k = 0, 6 do
		L:wedge(
			x - 4.5 + k * 1.5,
			7.2,
			z - 2.2,
			1.5,
			1.4,
			3,
			deco({ color = k % 2 == 0 and P.barnRed or WHITE, name = "Awning" }),
			180
		)
	end
end

BUILD.scarecrow = function(L, plot)
	local w = SPOTS.scarecrow
	L:block(w.X, w.Z, 0.4, 0.4, 6, { color = P.wood, name = "ScarecrowPole" }, 0)
	L:box(w.X, 4.4, w.Z, 4, 0.35, 0.35, deco({ color = P.wood, name = "ScarecrowArms" }))
	L:box(w.X, 4, w.Z, 1.8, 2.2, 1, deco({ color = plot.color, name = "ScarecrowShirt" }))
	L:box(w.X, 5.7, w.Z, 1.2, 1.2, 1.2, deco({ color = Color3.fromRGB(230, 200, 140), name = "ScarecrowHead" }))
	L:box(w.X, 6.4, w.Z, 2.4, 0.2, 2.4, deco({ color = P.sunflower, name = "HatBrim" }))
	L:box(w.X, 6.9, w.Z, 1.2, 0.8, 1.2, deco({ color = P.sunflower, name = "Hat" }))
end

BUILD.barnDeed = function(L, plot)
	-- the barn's site: stakes and string, a sign (stage 2 builds the barn here)
	local b = SPOTS.barnSite
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			L:block(b.X + sx * 14, b.Z + sz * 10, 0.4, 0.4, 2, deco({ color = P.wood, name = "Stake" }), 0)
		end
	end
	L:block(b.X, b.Z, 28, 20, 0.15, deco({ color = Color3.fromRGB(160, 120, 84), name = "BarnSite" }), 0.24)
	local board = L:box(b.X, 3, b.Z - 11, 8, 2.4, 0.3, deco({ color = P.cream, name = "SiteSign" }))
	FarmBuilder.sign(board, "BARN", "coming soon", plot.color)
end

-- Stage 2: the farm ------------------------------------------------------------------------------------------------
local BARN_RED = Color3.fromRGB(176, 44, 38)
local ROOF = Color3.fromRGB(70, 74, 82)

BUILD.barn = function(L, plot)
	local b = SPOTS.barnSite
	local x, z, w, d, h = b.X, b.Z, 28, 20, 12
	L:block(x, z, w + 1.4, d + 1.4, 0.8, { color = P.concreteDark, name = "BarnFloor" }, 0)
	L:block(x, z, w, d, h, { color = BARN_RED, name = "Barn" }, 0.8)
	-- white trim at the corners and along the eaves
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			L:block(x + sx * w / 2, z + sz * d / 2, 0.8, 0.8, h, deco({ color = WHITE, name = "Trim" }), 0.8)
		end
		L:box(x, h + 0.8, z + sx * (d / 2 + 0.05), w + 0.8, 0.6, 0.5, deco({ color = WHITE, name = "Trim" }))
	end
	-- the gambrel roof: a steep lower pair of slopes, a shallow upper pair, a white ridge
	L:wedge(x, h + 0.8 + 2.5, z - d / 2 + 2.6, w + 1.2, 5, 5.6, { color = ROOF, name = "Roof" }, 180)
	L:wedge(x, h + 0.8 + 2.5, z + d / 2 - 2.6, w + 1.2, 5, 5.6, { color = ROOF, name = "Roof" }, 0)
	L:box(x, h + 0.8 + 2.5, z, w + 1.2, 5, d - 10.4, { color = ROOF, name = "Roof" })
	L:wedge(x, h + 0.8 + 6.5, z - (d - 10.4) / 4, w + 1.2, 3, (d - 10.4) / 2, { color = ROOF, name = "Roof" }, 180)
	L:wedge(x, h + 0.8 + 6.5, z + (d - 10.4) / 4, w + 1.2, 3, (d - 10.4) / 2, { color = ROOF, name = "Roof" }, 0)
	L:box(x, h + 0.8 + 8.1, z, w + 1.4, 0.4, 0.6, deco({ color = WHITE, name = "Ridge" }))
	-- the big doors on the front: two leaves with white frames and X braces
	local fz = z - d / 2 - 0.12
	for _, sx in { -1, 1 } do
		local dx = x + sx * 2.6
		L:box(dx, 0.8 + 4.5, fz, 5, 9, 0.25, deco({ color = BARN_RED, name = "BarnDoor" }))
		L:box(dx, 0.8 + 4.5, fz - 0.1, 5.2, 0.4, 0.2, deco({ color = WHITE, name = "Brace" }))
		L:box(dx, 0.8 + 9, fz - 0.1, 5.2, 0.4, 0.2, deco({ color = WHITE, name = "Brace" }))
		L:box(dx, 0.8, fz - 0.1, 5.2, 0.4, 0.2, deco({ color = WHITE, name = "Brace" }))
		for _, sign in { -1, 1 } do
			local brace = L:box(dx, 0.8 + 4.5, fz - 0.12, 0.4, 10, 0.2, deco({ color = WHITE, name = "Brace" }))
			brace.CFrame = brace.CFrame * CFrame.Angles(0, 0, math.rad(27 * sign))
		end
	end
	-- the hayloft door and a cupola with a weathervane
	L:box(x, h - 1.6, fz, 4, 3.2, 0.25, deco({ color = WHITE, name = "Hayloft" }))
	L:box(x, h - 1.6, fz - 0.1, 3.2, 2.4, 0.2, deco({ color = Color3.fromRGB(120, 72, 44), name = "Hay" }))
	L:block(x, z, 3.2, 3.2, 3, { color = WHITE, name = "Cupola" }, h + 9)
	L:block(x, z, 3.8, 3.8, 0.4, deco({ color = ROOF, name = "CupolaRoof" }), h + 12)
	L:block(x, z, 0.2, 0.2, 2.6, deco({ color = INK, name = "Vane" }), h + 12.4)
	L:box(x, h + 14.4, z, 2.2, 0.2, 0.2, deco({ color = INK, name = "Vane" }))
	-- inside: crates of crops that fill up as the barn does (FarmService shows them: BarnCrate, Slot) and a sign
	for i = 1, 12 do
		local cx = x - 10 + ((i - 1) % 6) * 4
		local cz = z - 4 + ((i - 1) // 6) * 5
		local crate = L:block(cx, cz, 3, 3, 2.6, { color = P.wood, name = "BarnCrate", transparency = 1 }, 0.8)
		crate:SetAttribute("Slot", i)
		local top = L:block(
			cx,
			cz,
			2.6,
			2.6,
			0.5,
			deco({ color = Crops[Crops.LIST[(i - 1) % 5 + 1]].color, name = "BarnCrateTop", transparency = 1 }),
			3.4
		)
		top:SetAttribute("Slot", i)
	end
	local board = L:box(x, h - 3.6, fz - 0.2, 10, 2, 0.2, deco({ color = WHITE, name = "BarnSign" }))
	FarmBuilder.sign(board, "BARN", "your crops", BARN_RED)
	-- hay bales by the door
	for k = 0, 2 do
		L:block(
			x + 9 + (k % 2) * 2.6,
			z - d / 2 - 2.5,
			2.4,
			1.6,
			1.6,
			{ color = P.sunflower, name = "HayBale" },
			0 + (k == 2 and 1.6 or 0)
		)
	end
	_ = plot
end

-- A tractor at a level (bigger each level, a wider header in front) at a spot; the model the services drive
local function tractorModel(L, plot, level, at, name)
	local k = 1 + 0.18 * (level - 1)
	local model = Instance.new("Model")
	model.Name = name or "Tractor"
	model:SetAttribute("Level", level)
	model.Parent = L.folder
	local s = L:sub(model, CFrame.new(at.X, 0, at.Z))
	local green = Color3.fromRGB(40, 150, 70)
	s:box(0, 2.6 * k, 0.6 * k, 3 * k, 1.8 * k, 5 * k, { color = green, name = "TractorBody" })
	s:box(0, 3.2 * k, -2 * k, 2.6 * k, 1.4 * k, 1.6 * k, { color = green, name = "Hood" })
	s:box(0, 3.95 * k, -2 * k, 2.7 * k, 0.15, 1.7 * k, deco({ color = P.sunflower, name = "Stripe" }))
	s:box(0, 4.4 * k, 1.6 * k, 2.6 * k, 0.2, 2.4 * k, deco({ color = INK, name = "Seat" }))
	s:box(0, 5 * k, 1.2 * k, 0.2, 1.2 * k, 0.2, deco({ color = INK, name = "Column" }))
	s:cyl(0, 5.6 * k, 1 * k, 0.2, 1.2 * k, deco({ color = INK, name = "Wheel" }), "y")
	s:box(0.9 * k, 5 * k, -2.5 * k, 0.35, 2.6 * k, 0.35, deco({ color = P.steel, name = "Exhaust" }))
	for _, sx in { -1, 1 } do
		s:cyl(sx * 1.9 * k, 1.8 * k, 1.4 * k, 1 * k, 3.6 * k, { color = INK, name = "BigWheel" }, "x")
		s:cyl(sx * 2.42 * k, 1.8 * k, 1.4 * k, 0.1, 1.8 * k, deco({ color = P.sunflower, name = "Rim" }), "x")
		s:cyl(sx * 1.6 * k, 1 * k, -2.6 * k, 0.7 * k, 2 * k, { color = INK, name = "SmallWheel" }, "x")
		s:cyl(sx * 1.97 * k, 1 * k, -2.6 * k, 0.1, 1 * k, deco({ color = P.sunflower, name = "Rim" }), "x")
	end
	-- a header in front: wider with the level (it picks that many patches at once)
	if level >= 2 then
		local hw = 3 + level * 1.6
		s:box(0, 1.2, -4 * k, hw, 1, 1.4, deco({ color = P.barnRed, name = "Header" }))
		for i = 0, math.floor(hw / 1.2) do
			s:box(-hw / 2 + 0.6 + i * 1.2, 0.7, -4.4 * k, 0.5, 0.5, 0.8, deco({ color = P.sunflower, name = "Tooth" }))
		end
	end
	if level >= 4 then
		s:box(0, 5.4 * k, 0.9 * k, 2.8 * k, 2 * k, 2.6 * k, deco({ color = P.glass, name = "Cab" }))
	end
	model:SetAttribute("Plot", plot.index)
	-- (it drives about: its pivot on the ground under it, nothing to bump into; TractorService)
	model.WorldPivot = plot.cf * CFrame.new(at.X, 0, at.Z)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return model
end

-- The tractor's level: the highest "autoharvest" owned (the upgrades' folders on the plot say)
local function tractorLevel(plot)
	local best = 1
	for _, d in plot.items:GetChildren() do
		local key = d:GetAttribute("Upgrade")
		local u = key and Upgrades[key]
		if u and u.kind == "autoharvest" then
			best = math.max(best, u.value)
		end
	end
	return best
end

-- Build (or rebuild) the tractors at the plot's level: the first in the "tractor" folder, the second in its own
function FarmBuilder.tractors(plot)
	local level = tractorLevel(plot)
	for _, spec in { { "tractor", SPOTS.tractor, "Tractor" }, { "secondTractor", SPOTS.tractor2, "Tractor2" } } do
		local folder = plot.items:FindFirstChild(spec[1])
		if folder then
			local old = folder:FindFirstChild(spec[3])
			if not old or old:GetAttribute("Level") ~= level then
				local pivot = old and old:GetPivot()
				if old then
					old:Destroy()
				end
				local m = tractorModel(Shapes.new(folder, plot.cf), plot, level, spec[2], spec[3])
				if pivot then
					m:PivotTo(pivot)
				end
			end
		end
	end
end

BUILD.tractor = function(L, plot)
	tractorModel(L, plot, 1, SPOTS.tractor, "Tractor")
	task.defer(FarmBuilder.tractors, plot)
end
for level = 2, 5 do
	BUILD["tractor" .. level] = function(_, plot)
		task.defer(FarmBuilder.tractors, plot)
	end
end
BUILD.secondTractor = function(L, plot)
	tractorModel(L, plot, tractorLevel(plot), SPOTS.tractor2, "Tractor2")
	task.defer(FarmBuilder.tractors, plot)
end

BUILD.bigBarn = function(L, plot)
	-- (a silo by the barn: the bigger barn keeps more)
	local s = SPOTS.silo
	L:cyl(s.X, 11, s.Z, 22, 8, { color = P.steelLight, name = "Silo" }, "y")
	for y = 3, 21, 4.5 do
		L:cyl(s.X, y, s.Z, 0.4, 8.3, deco({ color = P.steel, name = "SiloRing" }), "y")
	end
	L:cyl(s.X, 18, s.Z, 1.2, 8.35, deco({ color = plot.color, name = "SiloStripe" }), "y")
	L:cyl(s.X, 22.4, s.Z, 1, 7, deco({ color = P.steel, name = "SiloDome" }), "y")
	L:cyl(s.X, 23.2, s.Z, 0.8, 4.5, deco({ color = P.steel, name = "SiloDome" }), "y")
	L:cyl(s.X, 23.8, s.Z, 0.6, 1.8, deco({ color = P.steelLight, name = "SiloCap" }), "y")
	L:box(s.X + 4.15, 11, s.Z, 0.3, 22, 1.2, deco({ color = P.steel, name = "Ladder" }))
end

BUILD.windmill = function(L)
	local w = SPOTS.windmill
	for k = 0, 4 do
		local size = 6 - k * 0.8
		L:block(w.X, w.Z, size, size, 3.2, { color = k % 2 == 0 and P.cream or WHITE, name = "WindmillTower" }, k * 3.2)
	end
	L:block(w.X, w.Z, 3.6, 3.6, 2, { color = P.barnRed, name = "WindmillCap" }, 16)
	local hub = L:box(w.X, 17, w.Z - 2.2, 1.2, 1.2, 1.2, deco({ color = INK, name = "WindmillHub" }))
	hub:SetAttribute("Spin", 1.2)
	for k = 0, 3 do
		local blade = Instance.new("Part")
		blade.Name = "WindmillBlade"
		blade.Anchored = true
		blade.CanCollide = false
		blade.CanQuery = false
		blade.Material = Enum.Material.SmoothPlastic
		blade.Color = WHITE
		blade.Size = Vector3.new(1.4, 7, 0.2)
		blade.CFrame = hub.CFrame * CFrame.Angles(0, 0, math.rad(90 * k)) * CFrame.new(0, 4, -0.3)
		blade.Parent = hub
	end
	L:box(w.X, 1.4, w.Z - 3.05, 1.4, 2.6, 0.2, deco({ color = Color3.fromRGB(120, 72, 44), name = "WindmillDoor" }))
end

-- A pen: a white rail fence, a shelter that fits the animal, a trough and a feeder, the pad at its gate
local function pen(L, plot, key)
	local c = SPOTS.pens[key]
	local W, D = PlotLayout.PEN.X, PlotLayout.PEN.Z
	local x0, x1, z0, z1 = c.X - W / 2, c.X + W / 2, c.Z - D / 2, c.Z + D / 2
	L:block(
		c.X,
		c.Z,
		W,
		D,
		0.12,
		deco({ color = key == "pig" and Color3.fromRGB(150, 110, 80) or P.grass, name = "PenGround" }),
		0.24
	)
	local function rail(ax, az, bx, bz)
		local len = math.max(math.abs(bx - ax), math.abs(bz - az))
		local alongX = math.abs(bx - ax) > 0
		for _, y in { 1.1, 2.3 } do
			L:box(
				(ax + bx) / 2,
				y,
				(az + bz) / 2,
				alongX and len or 0.3,
				0.3,
				alongX and 0.3 or len,
				{ color = P.fenceWhite, name = "PenFence" }
			)
		end
		for k = 0, math.floor(len / 5) do
			local t = k * 5 / len
			L:block(
				ax + (bx - ax) * t,
				az + (bz - az) * t,
				0.5,
				0.5,
				2.8,
				deco({ color = P.fenceWhite, name = "PenPost" }),
				0
			)
		end
	end
	rail(x0, z1, x1, z1)
	rail(x0, z0, x0, z1)
	rail(x1, z0, x1, z1)
	rail(x0, z0, c.X - 3, z0)
	rail(c.X + 3, z0, x1, z0)
	-- the shelter at the back
	local sx, sz = c.X, z1 - 7
	if key == "chicken" then
		L:block(sx, sz, 10, 7, 1.6, deco({ color = P.wood, name = "CoopStilts" }), 0)
		L:block(sx, sz, 10, 7, 6, { color = P.cream, name = "Coop" }, 1.6)
		L:wedge(sx, 9.6, sz - 1.9, 11, 2, 3.8, { color = plot.color, name = "CoopRoof" }, 180)
		L:wedge(sx, 9.6, sz + 1.9, 11, 2, 3.8, { color = plot.color, name = "CoopRoof" }, 0)
		L:box(sx, 3.6, sz - 3.6, 2.2, 2.6, 0.2, deco({ color = INK, name = "CoopDoor" }))
		L:box(sx, 1, sz - 5.3, 1.8, 0.2, 3.6, deco({ color = P.wood, name = "Ramp" }))
	elseif key == "pig" then
		L:block(sx, sz, 12, 7, 5, { color = P.barnRed, name = "Sty" }, 0)
		L:box(sx, 5.6, sz, 13, 1.2, 8, { color = ROOF, name = "StyRoof" })
		L:box(sx, 2, sz - 3.6, 3.4, 3.6, 0.2, deco({ color = INK, name = "StyDoor" }))
		L:block(c.X - 8, c.Z - 4, 8, 6, 0.1, deco({ color = Color3.fromRGB(110, 80, 60), name = "Mud" }), 0.36)
	elseif key == "sheep" then
		for _, px in { -5.5, 5.5 } do
			for _, pz in { -3, 3 } do
				L:block(sx + px, sz + pz, 0.6, 0.6, 6, { color = P.wood, name = "ShelterPost" }, 0)
			end
		end
		L:box(sx, 6.4, sz, 13, 0.8, 8, { color = plot.color, name = "ShelterRoof" })
		for k = 0, 2 do
			L:block(sx - 3 + k * 3, sz + 1, 2.4, 1.6, 1.6, { color = P.sunflower, name = "HayBale" }, 0)
		end
	else
		L:block(sx, sz, 14, 8, 8, { color = BARN_RED, name = "CowShed" }, 0)
		L:wedge(sx, 9.5, sz - 2, 15, 3, 4.4, { color = ROOF, name = "ShedRoof" }, 180)
		L:wedge(sx, 9.5, sz + 2, 15, 3, 4.4, { color = ROOF, name = "ShedRoof" }, 0)
		L:box(sx, 3.4, sz - 4.1, 5, 6.8, 0.2, deco({ color = WHITE, name = "ShedDoor" }))
	end
	-- a water trough and a feeder
	L:block(c.X + W / 2 - 4, c.Z - 4, 2, 6, 1.4, { color = P.steel, name = "Trough" }, 0)
	L:block(c.X + W / 2 - 4, c.Z - 4, 1.6, 5.6, 0.2, deco({ color = P.water, name = "TroughWater" }), 1.3)
	L:block(c.X - W / 2 + 4, c.Z - 6, 2.4, 2.4, 2, { color = P.wood, name = "Feeder" }, 0)
	-- the pad at the gate, and its sign
	L:block(c.X, z0 - 3.5, 6, 4.6, 0.3, deco({ color = P.sunflower, name = "PenRim" }), 0.25)
	local pad = L:block(c.X, z0 - 3.5, 5.2, 3.8, 0.4, { color = WHITE, name = "PenPad" }, 0.25)
	pad:SetAttribute("Animal", key)
	return pad
end

BUILD.chickenCoop = function(L, plot)
	pen(L, plot, "chicken")
end
BUILD.pigPen = function(L, plot)
	pen(L, plot, "pig")
end
BUILD.sheepPen = function(L, plot)
	pen(L, plot, "sheep")
end
BUILD.cowBarn = function(L, plot)
	pen(L, plot, "cow")
end

BUILD.shedDeed = function(L, plot)
	local x, z = 34, -60
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			L:block(x + sx * 18, z + sz * 14, 0.4, 0.4, 2, deco({ color = P.wood, name = "Stake" }), 0)
		end
	end
	L:block(x, z, 36, 28, 0.15, deco({ color = P.concrete, name = "ShedSite" }), 0.24)
	local board = L:box(x, 3, z - 15, 10, 2.6, 0.3, deco({ color = P.cream, name = "SiteSign" }))
	FarmBuilder.sign(board, "PACKING SHED", "coming soon", plot.color)
end

-- An animal, blocky, in the pen: bigger as it levels; a ribbon from level 5, a golden bell at 10
function FarmBuilder.animal(parent, key, at, level, facing)
	local model = Instance.new("Model")
	model.Name = "Animal"
	model:SetAttribute("Animal", key)
	model.Parent = parent
	local k = 1 + 0.04 * ((level or 1) - 1)
	local cf = CFrame.new(at) * CFrame.Angles(0, facing or 0, 0)
	local s = Shapes.new(model, cf)
	local function box(x, y, z, w, h, d, color, name)
		return s:box(x * k, y * k, z * k, w * k, h * k, d * k, deco({ color = color, name = name or "Body" }))
	end
	local body
	if key == "chicken" then
		body = box(0, 1.2, 0, 1.2, 1.1, 1.6, WHITE, "Body")
		box(0, 2, -0.8, 0.8, 0.8, 0.8, WHITE, "Head")
		box(0, 2.5, -0.8, 0.25, 0.35, 0.6, P.dockRed, "Comb")
		box(0, 1.95, -1.3, 0.3, 0.25, 0.3, P.sunflower, "Beak")
		box(0, 1.3, 0.85, 0.9, 0.7, 0.3, Color3.fromRGB(230, 230, 225), "Tail")
		for _, sx in { -0.3, 0.3 } do
			box(sx, 0.35, 0, 0.15, 0.7, 0.15, P.sunflower, "Leg")
		end
	elseif key == "pig" then
		body = box(0, 1.5, 0, 2, 1.6, 3, Color3.fromRGB(250, 170, 180), "Body")
		box(0, 1.7, -1.9, 1.5, 1.3, 1, Color3.fromRGB(250, 170, 180), "Head")
		box(0, 1.5, -2.5, 0.8, 0.6, 0.3, Color3.fromRGB(230, 130, 150), "Snout")
		for _, sx in { -0.5, 0.5 } do
			box(sx, 2.45, -1.9, 0.4, 0.3, 0.3, Color3.fromRGB(230, 130, 150), "Ear")
			for _, sz in { -1, 1 } do
				box(sx, 0.35, sz, 0.45, 0.7, 0.45, Color3.fromRGB(240, 150, 165), "Leg")
			end
		end
		box(0, 2, 1.6, 0.2, 0.4, 0.2, Color3.fromRGB(230, 130, 150), "Tail")
	elseif key == "sheep" then
		body = box(0, 1.7, 0, 2.2, 1.7, 3, WHITE, "Body")
		box(0, 2.3, 0.4, 1.8, 0.8, 2.2, Color3.fromRGB(240, 240, 236), "Wool")
		box(0, 1.9, -1.8, 1, 1, 1, INK, "Head")
		for _, sx in { -0.6, 0.6 } do
			for _, sz in { -1, 1 } do
				box(sx, 0.45, sz, 0.35, 0.9, 0.35, INK, "Leg")
			end
		end
	elseif key == "cow" then
		body = box(0, 2.2, 0, 2.4, 2, 4, WHITE, "Body")
		box(0.6, 2.6, 0.6, 1.3, 1.2, 1.6, INK, "Patch")
		box(-0.7, 2.1, -0.9, 1.1, 1, 1.2, INK, "Patch")
		box(0, 2.6, -2.5, 1.5, 1.5, 1.2, WHITE, "Head")
		box(0, 2.2, -3.15, 1.2, 0.7, 0.2, Color3.fromRGB(240, 170, 170), "Muzzle")
		for _, sx in { -0.65, 0.65 } do
			box(sx, 3.5, -2.5, 0.25, 0.5, 0.25, P.cream, "Horn")
			for _, sz in { -1.3, 1.3 } do
				box(sx, 0.6, sz, 0.5, 1.2, 0.5, WHITE, "Leg")
			end
		end
		box(0, 1, 0.6, 0.9, 0.4, 0.9, Color3.fromRGB(240, 170, 170), "Udder")
	elseif key == "goat" then
		body = box(0, 1.6, 0, 1.8, 1.5, 2.6, Color3.fromRGB(225, 215, 200), "Body")
		box(0, 2.3, -1.6, 1, 1, 1, Color3.fromRGB(225, 215, 200), "Head")
		box(0, 1.7, -1.9, 0.3, 0.6, 0.3, Color3.fromRGB(200, 190, 175), "Beard")
		for _, sx in { -0.5, 0.5 } do
			box(sx, 0.4, -0.9, 0.3, 0.8, 0.3, Color3.fromRGB(200, 190, 175), "Leg")
			box(sx, 0.4, 0.9, 0.3, 0.8, 0.3, Color3.fromRGB(200, 190, 175), "Leg")
		end
	else -- horse
		body = box(0, 2.8, 0, 2, 2, 4.4, Color3.fromRGB(150, 100, 60), "Body")
		box(0, 4.2, -2.4, 1, 2.2, 1.2, Color3.fromRGB(150, 100, 60), "Neck")
		box(0, 4.8, -3.2, 0.9, 0.9, 1.8, Color3.fromRGB(150, 100, 60), "Head")
		box(0, 4.6, -1.9, 0.3, 2, 1, INK, "Mane")
		for _, sx in { -0.6, 0.6 } do
			for _, sz in { -1.5, 1.5 } do
				box(sx, 0.9, sz, 0.45, 1.8, 0.45, Color3.fromRGB(130, 85, 50), "Leg")
			end
		end
	end
	if (level or 1) >= 5 then
		box(0, body.Size.Y / k + 0.6, -0.4, body.Size.X / k + 0.1, 0.3, 0.4, P.dockRed, "Ribbon")
	end
	if (level or 1) >= 10 then
		local bell = box(0, body.Size.Y / k, -1.2, 0.5, 0.5, 0.5, P.sunflower, "Bell")
		bell.Material = Enum.Material.Neon
	end
	model.PrimaryPart = body
	return model
end

function FarmBuilder.upgrade(plot, key)
	local build = BUILD[key]
	if not build then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = key
	folder:SetAttribute("Upgrade", key)
	folder.Parent = plot.items
	build(Shapes.new(folder, plot.cf), plot)
	return folder
end

function FarmBuilder.clear(plot)
	for _, d in plot.items:GetChildren() do
		d:Destroy()
	end
end

-- (stage 3's pieces, and the vehicles)
require(script.Parent.ShedBuilder)(FarmBuilder, BUILD)
-- (stage 4's)
require(script.Parent.WarehouseBuilder)(FarmBuilder, BUILD)

FarmBuilder.BUILD = BUILD

return FarmBuilder

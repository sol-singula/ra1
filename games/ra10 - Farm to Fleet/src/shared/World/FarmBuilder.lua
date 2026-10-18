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
local PlotLayout = require(script.Parent.PlotLayout)
local Shapes = require(script.Parent.Shapes)

local FarmBuilder = {}

local P = Constants.PALETTE
local deco = Shapes.deco
local INK = Color3.fromRGB(30, 30, 34)
local WHITE = Color3.fromRGB(250, 250, 248)
local SPOTS = PlotLayout.SPOTS

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
		local W, D = PlotLayout.WIDTH, PlotLayout.DEPTH
		L:block(0, 0, W, D, 0.25, deco({ color = i % 2 == 0 and P.grass or P.grassLight, name = "Meadow" }), 0)
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
		rail(-W / 2, -D / 2, -W / 2, D / 2)
		rail(W / 2, -D / 2, W / 2, D / 2)
		rail(-W / 2, D / 2, W / 2, D / 2)
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
local function shack(L, color)
	local x, z = SPOTS.shack.X, SPOTS.shack.Z
	local w, d, h = 14, 10, 8
	L:block(x, z, w + 1, d + 1, 0.8, { color = P.concreteDark, name = "ShackFloor" }, 0)
	L:block(x, z, w, d, h, { color = P.barnRed, name = "Shack" }, 0.8)
	-- the siding: board lines round it
	for y = 2, h, 1.2 do
		L:block(
			x,
			z - d / 2 - 0.05,
			w + 0.1,
			0.12,
			0.12,
			deco({ color = Color3.fromRGB(150, 40, 34), name = "Siding" }),
			y
		)
		L:block(
			x,
			z + d / 2 + 0.05,
			w + 0.1,
			0.12,
			0.12,
			deco({ color = Color3.fromRGB(150, 40, 34), name = "Siding" }),
			y
		)
	end
	-- corner trims
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			L:block(x + sx * w / 2, z + sz * d / 2, 0.6, 0.6, h, deco({ color = P.cream, name = "Trim" }), 0.8)
		end
	end
	-- the roof: two slopes, a ridge, eaves in the plot's colour
	L:wedge(x, 0.8 + h + 2, z - d / 4 - 0.3, w + 1.6, 4, d / 2 + 0.8, { color = INK, name = "Roof" }, 180)
	L:wedge(x, 0.8 + h + 2, z + d / 4 + 0.3, w + 1.6, 4, d / 2 + 0.8, { color = INK, name = "Roof" }, 0)
	L:box(x, 0.8 + h + 4.1, z, w + 1.8, 0.4, 0.6, deco({ color = color, name = "Ridge" }))
	-- the door and its frame, a window with shutters, a flower box
	L:box(x - 2.5, 0.8 + 3, z - d / 2 - 0.1, 3, 6, 0.2, deco({ color = Color3.fromRGB(120, 72, 44), name = "Door" }))
	L:box(x - 2.5, 0.8 + 6.2, z - d / 2 - 0.15, 3.6, 0.4, 0.3, deco({ color = P.cream, name = "Trim" }))
	L:box(x - 1.2, 0.8 + 3, z - d / 2 - 0.2, 0.3, 0.3, 0.2, deco({ color = P.sunflower, name = "Knob" }))
	L:box(x + 3, 0.8 + 4.5, z - d / 2 - 0.1, 3.4, 2.6, 0.2, deco({ color = P.glass, name = "Window" }))
	L:box(x + 3, 0.8 + 4.5, z - d / 2 - 0.15, 3.8, 0.3, 0.3, deco({ color = P.cream, name = "Trim" }))
	for _, sx in { -1, 1 } do
		L:box(x + 3 + sx * 2.3, 0.8 + 4.5, z - d / 2 - 0.12, 1, 2.8, 0.2, deco({ color = color, name = "Shutter" }))
	end
	L:box(
		x + 3,
		0.8 + 2.9,
		z - d / 2 - 0.5,
		3.6,
		0.6,
		0.8,
		deco({ color = Color3.fromRGB(120, 72, 44), name = "FlowerBox" })
	)
	for k = -1, 1 do
		L:box(
			x + 3 + k * 1.1,
			0.8 + 3.4,
			z - d / 2 - 0.5,
			0.6,
			0.6,
			0.6,
			deco({ color = k == 0 and P.sunflower or Color3.fromRGB(240, 90, 140), name = "Flower" })
		)
	end
	-- the porch: a deck, two posts, a little roof
	L:block(x - 2.5, z - d / 2 - 2, 7, 4, 0.8, { color = P.wood, name = "Porch" }, 0)
	for _, sx in { -1, 1 } do
		L:block(x - 2.5 + sx * 3.2, z - d / 2 - 3.7, 0.5, 0.5, 6, { color = P.cream, name = "PorchPost" }, 0.8)
	end
	L:box(x - 2.5, 0.8 + 6.4, z - d / 2 - 2, 7.6, 0.4, 4.4, { color = color, name = "PorchRoof" })
	-- a chimney
	L:block(x + 4.5, z + 1.5, 1.6, 1.6, 4.5, { color = P.concreteDark, name = "Chimney" }, 0.8 + h + 0.8)
end

local function stand(L, color)
	local x, z = SPOTS.stand.X, SPOTS.stand.Z
	L:block(x, z, 10, 4, 3, { color = P.wood, name = "Stand" }, 0)
	L:block(x, z, 10.6, 4.6, 0.4, deco({ color = P.cream, name = "Counter" }), 3)
	for _, sx in { -1, 1 } do
		L:block(x + sx * 4.8, z + 1.8, 0.5, 0.5, 4.5, { color = P.cream, name = "StandPost" }, 3.4)
	end
	L:box(x, 3.4 + 4.7, z + 1, 11, 0.4, 3.2, { color = color, name = "StandRoof" })
	-- crates of produce on the counter
	for k = -1, 1 do
		local cx = x + k * 3
		L:block(cx, z - 0.6, 2.4, 1.8, 0.9, deco({ color = Color3.fromRGB(150, 104, 64), name = "Crate" }), 3.4)
		local c = k == -1 and Crops.strawberry.color or (k == 0 and Crops.carrot.color or Crops.corn.color)
		for j = -1, 1 do
			L:block(cx + j * 0.65, z - 0.6, 0.55, 0.55, 0.5, deco({ color = c, name = "Produce" }), 4.3)
		end
	end
	local board = L:box(x, 1.6, z - 2.1, 7, 1.6, 0.2, deco({ color = P.cream, name = "StandSign" }))
	FarmBuilder.sign(board, "FARM STAND", "", P.barnRed)
	-- the pad in front: stand on it to sell
	L:block(x, z - 7.5, 7, 4, 0.3, deco({ color = P.sunflower, name = "SellRim" }), 0.25)
	local pad = L:block(x, z - 7.5, 6.2, 3.2, 0.4, { color = WHITE, name = "SellPad" }, 0.25)
	return pad
end

function FarmBuilder.base(plot)
	local L = Shapes.new(plot.items, plot.cf)
	shack(L, plot.color)
	local refs = { tiles = {} }
	refs.standPad = stand(L, plot.color)
	FarmBuilder.label(refs.standPad, "SELL", "stand here", P.sunflower)
	-- the mailbox, the dirt track from the road to the shack
	local m = SPOTS.mailbox
	L:block(m.X, m.Z, 0.4, 0.4, 3.4, { color = P.wood, name = "MailPost" }, 0)
	L:box(m.X, 3.9, m.Z, 1.2, 1, 1.8, deco({ color = plot.color, name = "Mailbox" }))
	L:block(-46, -95, 5, 30, 0.12, deco({ color = Color3.fromRGB(160, 120, 84), name = "Track" }), 0.24)
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

-- A crop on a tile: phase 0 (a seed mound) to 3 (ripe); golden ones glow
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
	local s = Shapes.new(model, tile.CFrame * CFrame.new(0, tile.Size.Y / 2, 0))
	local fruit = golden and P.sunflower or c.color
	local fopts = deco({ color = fruit, name = "Fruit", material = golden and Enum.Material.Neon or nil })
	local leaf = deco({ color = c.leaf, name = "Leaf" })
	local spots = { { -1.8, -1.6 }, { 1.8, -1.6 }, { -1.8, 1.6 }, { 1.8, 1.6 } }
	if phase == 0 then
		for _, p in spots do
			s:box(p[1], 0.15, p[2], 1, 0.3, 1, deco({ color = Color3.fromRGB(100, 68, 46), name = "Mound" }))
		end
		return model
	end
	local k = phase / 3
	for _, p in spots do
		local px, pz = p[1], p[2]
		if key == "corn" then
			s:box(px, 3 * k, pz, 0.35, 6 * k, 0.35, leaf)
			s:box(px + 0.4, 3.4 * k, pz, 0.9 * k, 0.2, 1.4 * k, leaf)
			if phase == 3 then
				s:box(px + 0.3, 3.2, pz + 0.3, 0.55, 1.5, 0.55, fopts)
			end
		elseif key == "carrot" then
			s:box(px, 0.9 * k + 0.2, pz, 0.25, 1.8 * k, 0.25, leaf)
			s:box(px + 0.3, 0.7 * k + 0.2, pz, 0.2, 1.4 * k, 0.2, leaf)
			if phase == 3 then
				s:box(px, 0.15, pz, 0.7, 0.35, 0.7, fopts)
			end
		elseif c.regrow then
			-- a small tree
			s:box(px, 1 * k, pz, 0.4, 2 * k, 0.4, deco({ color = P.wood, name = "Trunk" }))
			s:box(px, 2.4 * k, pz, 1.8 * k, 1.4 * k, 1.8 * k, leaf)
			if phase == 3 then
				s:box(px + 0.7, 2.2, pz - 0.7, 0.5, 0.5, 0.5, fopts)
				s:box(px - 0.6, 2.6, pz + 0.6, 0.5, 0.5, 0.5, fopts)
			end
		else
			-- a leafy clump (strawberries, tomatoes, berries, melons, pumpkins)
			s:box(px, 0.45 * k + 0.1, pz, 1.5 * k, 0.9 * k, 1.5 * k, leaf)
			s:box(
				px,
				0.95 * k + 0.1,
				pz,
				0.9 * k,
				0.4 * k,
				0.9 * k,
				deco({ color = Color3.fromRGB(90, 190, 80), name = "Leaf" })
			)
			if phase == 3 then
				local big = (key == "pumpkin" or key == "watermelon" or key == "goldpumpkin") and 1.2 or 0.45
				s:box(px + 0.6, big / 2 + 0.1, pz - 0.6, big, big * 0.85, big, fopts)
				if big < 1 then
					s:box(px - 0.5, 0.3, pz + 0.6, 0.45, 0.4, 0.45, fopts)
				end
			end
		end
	end
	if phase == 3 then
		-- a soft sparkle over a ripe tile, so it reads "ready" from across the field
		local p = s:box(
			0,
			4.2,
			0,
			0.6,
			0.6,
			0.6,
			deco({
				color = golden and P.sunflower or WHITE,
				material = Enum.Material.Neon,
				name = "Ripe",
				transparency = 0.2,
			})
		)
		p.CFrame = p.CFrame * CFrame.Angles(0, math.rad(45), math.rad(45))
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
	-- a white picket fence round the shack and the field, open at the track
	local x0, x1, z0, z1 = -68, -2, -88, -50
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
	run(x0, z0, -50, z0)
	run(-42, z0, x1, z0)
end

BUILD.sprinkler = function(L)
	for n = 1, 12 do
		local at = PlotLayout.soilTile(n)
		local x, z = at.X + PlotLayout.TILE / 2 + 0.8, at.Z + PlotLayout.TILE / 2 + 0.8
		L:block(x, z, 0.3, 0.3, 2, deco({ color = P.steel, name = "SprinklerPipe" }), 0)
		L:box(x, 2.15, z, 0.7, 0.3, 0.7, deco({ color = P.water, name = "SprinklerHead" }))
	end
end

BUILD.awning = function(L)
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

BUILD.field1 = function(L)
	-- a rail fence round the stage-2 fields, open toward the barn
	local x0, x1, z0, z1 = -79, -8, -7, 20
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
	rail(x0, z1, x1, z1)
	rail(x0, z0, x0, z1)
	rail(x1, z0, x1, z1)
	rail(x0, z0, -50, z0)
	rail(-32, z0, x1, z0)
end

BUILD.tractor = function(L, plot)
	local t = SPOTS.tractor
	local model = Instance.new("Model")
	model.Name = "Tractor"
	model.Parent = L.folder
	local s = L:sub(model, CFrame.new(t.X, 0, t.Z))
	local green = Color3.fromRGB(40, 150, 70)
	s:box(0, 2.6, 0.6, 3, 1.8, 5, { color = green, name = "TractorBody" })
	s:box(0, 3.2, -2, 2.6, 1.4, 1.6, { color = green, name = "Hood" })
	s:box(0, 3.95, -2, 2.7, 0.15, 1.7, deco({ color = P.sunflower, name = "Stripe" }))
	s:box(0, 4.4, 1.6, 2.6, 0.2, 2.4, deco({ color = INK, name = "Seat" }))
	s:box(0, 5, 1.2, 0.2, 1.2, 0.2, deco({ color = INK, name = "Column" }))
	s:cyl(0, 5.6, 1, 0.2, 1.2, deco({ color = INK, name = "Wheel" }), "y")
	s:box(0.9, 5, -2.5, 0.35, 2.6, 0.35, deco({ color = P.steel, name = "Exhaust" }))
	for _, sx in { -1, 1 } do
		s:cyl(sx * 1.9, 1.8, 1.4, 1, 3.6, { color = INK, name = "BigWheel" }, "x")
		s:cyl(sx * 2.42, 1.8, 1.4, 0.1, 1.8, deco({ color = P.sunflower, name = "Rim" }), "x")
		s:cyl(sx * 1.6, 1, -2.6, 0.7, 2, { color = INK, name = "SmallWheel" }, "x")
		s:cyl(sx * 1.97, 1, -2.6, 0.1, 1, deco({ color = P.sunflower, name = "Rim" }), "x")
	end
	model:SetAttribute("Plot", plot.index)
end

BUILD.conveyor = function(L)
	local route = PlotLayout.CONVEYOR
	for i = 1, #route - 1 do
		local a, b = route[i], route[i + 1]
		local len = (b - a).Magnitude
		local alongX = math.abs(b.X - a.X) > 0.1
		local cx, cz = (a.X + b.X) / 2, (a.Z + b.Z) / 2
		local w, d = alongX and len + 2 or 2, alongX and 2 or len + 2
		L:box(cx, 1.6, cz, w, 0.25, d, deco({ color = Color3.fromRGB(46, 48, 54), name = "Belt" }))
		L:box(
			cx,
			1.35,
			cz,
			alongX and len + 2.2 or 2.4,
			0.3,
			alongX and 2.4 or len + 2.2,
			deco({ color = P.steelLight, name = "BeltFrame" })
		)
		for _, side in { -1, 1 } do
			L:box(
				cx + (alongX and 0 or side * 1.15),
				1.95,
				cz + (alongX and side * 1.15 or 0),
				alongX and len + 2 or 0.2,
				0.5,
				alongX and 0.2 or len + 2,
				deco({ color = P.safetyYellow, name = "BeltRail" })
			)
		end
		for k = 0, math.floor(len / 6) do
			local t = k * 6 / len
			L:block(
				a.X + (b.X - a.X) * t,
				a.Z + (b.Z - a.Z) * t,
				0.4,
				0.4,
				1.2,
				deco({ color = P.steel, name = "BeltLeg" }),
				0
			)
		end
	end
	-- a hopper at the barn, a chute down to the stand
	local first, last = route[1], route[#route]
	L:block(first.X, first.Z, 3, 3, 1.6, deco({ color = P.steel, name = "Hopper" }), 1.8)
	L:block(last.X + 1.5, last.Z, 3, 2.4, 0.6, deco({ color = P.steel, name = "Chute" }), 1.8)
end

BUILD.silo = function(L, plot)
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

FarmBuilder.BUILD = BUILD

return FarmBuilder

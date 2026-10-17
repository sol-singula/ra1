--[[
The tycoon place's world (TycoonService builds it on the server): a street along Z with three plots each side, in
the maps' look (World/ArenaBuilder's shapes: white and greys, plain, square, no browns), each plot with its own
accent colour (Data/Tycoon.COLORS) for its trims, banners and the mines' caps. The LOBBY portal stands at the north
end of the street, the CASTLE TYCOON sign at the south.

A plot is built in its own frame (TycoonBuilder.frame(i)): local -Z is its front, toward the street, the gate in the
middle of it; the plot is Tycoon.PLOT_SIZE a side round the frame's origin. Everything on a plot is placed in those
local coordinates, so the same castle stands on both sides of the street:

  spawn      (0, 3, -38) facing in      the street in front of the gate
  collector  (0, -24)                   the COLLECT pad just inside the gate
  pads       (-12 | 0 | 12, -14)        the three buy-pads
  mines      (+-22, -6 | 4 | 14 | 24)   along the side walls
  towers     (+-29, +-29)               the corners
  keep       (0, 16)                    at the back, the hall and the spire on it

  TycoonBuilder.build(parent) -> world { folder, plots = { [i] = plot }, portal, sign, count }
     plot = { index, cf, color, folder (the base), items (a Folder: what the owner has built and the pads), sign }
  TycoonBuilder.frame(i)               plot i's CFrame
  TycoonBuilder.toWorld(i, x, z, y?)   a plot-local spot in the world
  TycoonBuilder.pads(plot) -> { collector, pads = { Part x3 } }   the COLLECT pad and the buy-pads (owner's)
  TycoonBuilder.item(plot, key) -> { folder, spout?, top? }       build one piece (spout: a mine's; top: a tower's)
  TycoonBuilder.clear(plot)            take down everything the owner built (and the pads)
  TycoonBuilder.label(part, title, line?, color?)   the words on a pad's top and over it
  TycoonBuilder.light()                the maps' lighting
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Tycoon = require(ReplicatedStorage.Shared.Data.Tycoon)
local ArenaBuilder = require(script.Parent.ArenaBuilder)
local LobbyBuilder = require(script.Parent.LobbyBuilder)

local TycoonBuilder = {}

local V3 = Vector3.new
local GOLD = Constants.GOLD
local INK = Color3.fromRGB(30, 30, 34)
local deco = ArenaBuilder.deco
local HALF = Tycoon.PLOT_SIZE / 2

TycoonBuilder.STREET = 20 -- the street's width (between the plots' fronts)
TycoonBuilder.ROWS = { -72, 0, 72 } -- the plots' Z, each side
TycoonBuilder.SPOTS = {
	spawn = V3(0, 3, -38),
	collector = V3(0, 0, -24),
	pads = { V3(-12, 0, -14), V3(0, 0, -14), V3(12, 0, -14) },
	portal = V3(0, 0, -122), -- (world: the street's north end)
	sign = V3(0, 0, 122),
}
TycoonBuilder.MINES = {
	mine1 = V3(-22, 0, -6),
	mine2 = V3(22, 0, -6),
	mine3 = V3(-22, 0, 4),
	mine4 = V3(22, 0, 4),
	mine5 = V3(-22, 0, 14),
	mine6 = V3(22, 0, 14),
	mine7 = V3(-22, 0, 24),
	mine8 = V3(22, 0, 24),
}
TycoonBuilder.TOWERS = {
	towerFL = V3(-29, 0, -29),
	towerFR = V3(29, 0, -29),
	towerBL = V3(-29, 0, 29),
	towerBR = V3(29, 0, 29),
}

-- Plot i: 1-3 on the west side (front toward +X), 4-6 on the east (front toward -X)
function TycoonBuilder.frame(i)
	local west = i <= 3
	local z = TycoonBuilder.ROWS[(i - 1) % 3 + 1]
	local x = (TycoonBuilder.STREET / 2 + HALF) * (west and -1 or 1)
	local centre = V3(x, 0, z)
	return CFrame.lookAt(centre, centre + V3(west and 1 or -1, 0, 0))
end

function TycoonBuilder.toWorld(i, x, z, y)
	return TycoonBuilder.frame(i) * V3(x, y or 0, z)
end

local function newShapes(folder)
	return setmetatable({
		folder = folder,
		solids = {},
		collide = {},
		white = Constants.WHITE,
		light = Constants.LIGHT,
		grey = Constants.GREY,
		dark = Constants.DARK,
	}, ArenaBuilder.Shapes)
end

-- Shapes in a plot's frame: block(x, z, w, d, h, opts, y0) as Shapes:block, x/z/w/d all local
local Local = {}
Local.__index = Local

local function localShapes(plot, folder)
	return setmetatable({ cf = plot.cf, s = newShapes(folder), color = plot.color, index = plot.index }, Local)
end

function Local:box(x, y, z, w, h, d, opts)
	return self.s:box(self.cf * CFrame.new(x, y, z), V3(w, h, d), opts)
end

function Local:block(x, z, w, d, h, opts, y0)
	return self:box(x, (y0 or 0) + h / 2, z, w, h, d, opts)
end

-- A world spot from a local one
function Local:at(x, z, y)
	return self.cf * V3(x, y or 0, z)
end

-- Merlons along a line (local), on top of a wall at height y
function Local:merlons(x0, z0, x1, z1, y, opts)
	local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
	local n = math.max(2, math.floor(len / 2.6))
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
		self:block(x, z, 1.3, 1.3, 1.6, opts or { color = Constants.WHITE }, y)
	end
end

-- A wall (local, axis-aligned): a plinth, the wall, a coping, the merlons, a band in the plot's colour
function Local:wall(x0, z0, x1, z1, h, t)
	t = t or 2
	local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local len = alongX and math.abs(x1 - x0) or math.abs(z1 - z0)
	local w, d = alongX and len or t, alongX and t or len
	self:block(cx, cz, w + (alongX and 0 or 0.8), d + (alongX and 0.8 or 0), 0.8, { color = Constants.LIGHT }, 0)
	self:block(cx, cz, w, d, h, { color = Constants.WHITE, name = "Wall" }, 0)
	self:block(cx, cz, w + (alongX and 0 or 0.6), d + (alongX and 0.6 or 0), 0.5, deco({ color = Constants.LIGHT }), h)
	self:block(
		cx,
		cz,
		w + (alongX and 0 or 0.25),
		d + (alongX and 0.25 or 0),
		0.4,
		deco({ color = self.color, name = "Band" }),
		h - 2.2
	)
	self:merlons(x0, z0, x1, z1, h + 0.5)
end

-- A square tower (Shapes:tower, at the world spot of a local one)
function Local:tower(x, z, w, h, opts)
	local p = self:at(x, z)
	return self.s:tower(p.X, p.Z, w, w, h, opts)
end

-- A banner in the plot's colour hanging on a face: (x, z) local, `out` the local direction it faces
function Local:banner(x, z, out, y, h)
	local p = self:at(x + out.X * 0.35, z + out.Z * 0.35, y + h / 2)
	local look = self.cf:VectorToWorldSpace(out)
	local cf = CFrame.lookAt(p, p + look)
	self.s:box(cf, V3(3.2, h, 0.2), deco({ color = self.color, name = "Banner" }))
	self.s:box(cf * CFrame.new(0, 0, -0.06), V3(0.6, h - 0.8, 0.2), deco({ color = Constants.WHITE }))
	self.s:box(cf * CFrame.new(0, h / 2 + 0.2, 0), V3(4, 0.4, 0.4), deco({ color = Constants.LIGHT }))
end

-- Words on a pad: on its top face and on a billboard over it (readable from a phone's third-person camera)
function TycoonBuilder.label(part, title, line, color)
	LobbyBuilder.sign(part, title, line, color or INK, Enum.NormalId.Top)
	local bb = part:FindFirstChild("Over") or Instance.new("BillboardGui")
	bb.Name = "Over"
	bb.Size = UDim2.new(7, 0, 2.3, 0) -- (in studs: it shrinks with distance, so far pads never pile up)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.MaxDistance = 60
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	local function label(name, text, y, h, c, size)
		local l = bb:FindFirstChild(name) or Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = c
		l.TextStrokeTransparency = 0.2
		l.TextStrokeColor3 = INK
		l.Text = text
		l.Parent = bb
		local cap = l:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = size
		cap.Parent = l
		return l
	end
	label("Title", title, 0, 0.55, Color3.new(1, 1, 1), 26)
	label("Line", line or "", 0.55, 0.45, color or GOLD, 22)
	bb.Parent = part
	return bb
end

function TycoonBuilder.light()
	LobbyBuilder.light()
end

-- The world --------------------------------------------------------------------------------------------------------
function TycoonBuilder.build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Tycoon"
	local shapes = newShapes(folder)
	local world = { folder = folder, plots = {} }
	local street = TycoonBuilder.STREET
	local long = 3 * Tycoon.PLOT_SIZE + 2 * 8 + 40

	-- the ground: one slab under it all, a pale ground out past it, the street down the middle, a skyline in the haze
	local wide = street + 4 * HALF + 24
	shapes:block(0, 0, wide, long, 2, { color = shapes.white, name = "Floor" }, -2)
	shapes:block(0, 0, 1200, 1200, 1, deco({ color = shapes.light, shadow = false, name = "Ground" }), -4)
	shapes:block(0, 0, street, long, 0.08, deco({ color = shapes.light, shadow = false, name = "Street" }), 0)
	for _, s in { -1, 1 } do
		shapes:block(s * (street / 2 - 0.4), 0, 0.5, long, 0.12, deco({ color = GOLD, name = "Kerb" }), 0.02)
	end
	local r = Random.new(77)
	for i = 1, 22 do
		local a = (i / 22) * math.pi * 2
		local d = 190 + r:NextNumber(20, 120)
		local w, dd, h = r:NextNumber(16, 36), r:NextNumber(16, 36), r:NextNumber(30, 90)
		local c = (i % 3 == 0) and shapes.light or ((i % 3 == 1) and shapes.white or shapes.grey)
		shapes:block(
			math.cos(a) * d,
			math.sin(a) * d,
			w,
			dd,
			h,
			deco({ color = c, shadow = false, name = "Skyline" }),
			-3
		)
	end
	-- lamps down both kerbs
	for z = -100, 100, 25 do
		for _, s in { -1, 1 } do
			shapes:lamp(s * (street / 2 - 1.6), z, 7, GOLD)
		end
	end

	-- the LOBBY portal at the north end: an arch, its opening glowing gold, a sign over it
	local p = TycoonBuilder.SPOTS.portal
	shapes:arch(p.X, p.Z, 10, 12, 2.5, "z", { pier = 2.5 })
	local glow = shapes:box(
		CFrame.lookAt(V3(p.X, 6, p.Z), V3(p.X, 6, p.Z + 1)),
		V3(9.6, 11.6, 0.3),
		deco({ color = GOLD, material = Enum.Material.Neon, transparency = 0.45, name = "LobbyPortal" })
	)
	local sign = shapes:box(
		CFrame.lookAt(V3(p.X, 17.5, p.Z), V3(p.X, 17.5, p.Z + 1)),
		V3(13, 3, 0.5),
		deco({ color = shapes.white, name = "PortalSign" })
	)
	LobbyBuilder.sign(sign, "◀ LOBBY", "", GOLD)
	world.portal = glow

	-- the CASTLE TYCOON sign at the south end
	local s = TycoonBuilder.SPOTS.sign
	shapes:block(s.X, s.Z, 30, 2, 1, { color = shapes.light }, 0)
	shapes:block(s.X - 13, s.Z, 1.4, 1.4, 12, { color = shapes.white }, 1)
	shapes:block(s.X + 13, s.Z, 1.4, 1.4, 12, { color = shapes.white }, 1)
	local board = shapes:box(
		CFrame.lookAt(V3(s.X, 10, s.Z), V3(s.X, 10, s.Z - 1)),
		V3(26, 6, 0.6),
		deco({ color = shapes.white, name = "TitleSign" })
	)
	LobbyBuilder.sign(board, "CASTLE TYCOON", "build it · grow it · rebirth", GOLD)
	world.sign = board

	-- the plots: a base with a trim in its colour, the owner's sign by the gate
	for i = 1, Tycoon.PLOTS do
		local plotFolder = Instance.new("Folder")
		plotFolder.Name = "Plot" .. i
		plotFolder:SetAttribute("Plot", i)
		plotFolder.Parent = folder
		local items = Instance.new("Folder")
		items.Name = "Items"
		items.Parent = plotFolder
		local plot =
			{ index = i, cf = TycoonBuilder.frame(i), color = Tycoon.COLORS[i], folder = plotFolder, items = items }
		local L = localShapes(plot, plotFolder)
		L:block(0, 0, Tycoon.PLOT_SIZE, Tycoon.PLOT_SIZE, 0.3, deco({ color = shapes.light, name = "PlotBase" }), 0)
		for _, sx in { -1, 1 } do
			L:block(
				sx * (HALF - 0.3),
				0,
				0.6,
				Tycoon.PLOT_SIZE,
				0.36,
				deco({ color = plot.color, name = "PlotTrim" }),
				0
			)
			L:block(
				0,
				sx * (HALF - 0.3),
				Tycoon.PLOT_SIZE,
				0.6,
				0.36,
				deco({ color = plot.color, name = "PlotTrim" }),
				0
			)
		end
		-- the owner's sign on a post by the gate
		L:block(-10, -34, 0.6, 0.6, 7, { color = shapes.grey, name = "SignPost" }, 0)
		local post = L:box(-10, 8.6, -34, 9, 3.2, 0.4, deco({ color = shapes.white, name = "OwnerSign" }))
		post.CFrame = CFrame.lookAt(post.Position, post.Position + plot.cf:VectorToWorldSpace(V3(0, 0, -1)))
		L:box(-10, 10.35, -34, 9.3, 0.3, 0.5, deco({ color = plot.color, name = "SignTrim" }))
		L:box(-10, 6.85, -34, 9.3, 0.3, 0.5, deco({ color = plot.color, name = "SignTrim" }))
		LobbyBuilder.sign(post, "FREE PLOT", "", INK)
		plot.sign = post
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

-- The owner's pads -------------------------------------------------------------------------------------------------
function TycoonBuilder.pads(plot)
	local L = localShapes(plot, plot.items)
	local c = TycoonBuilder.SPOTS.collector
	L:block(c.X, c.Z, 7, 7, 0.3, deco({ color = GOLD, name = "CollectorRim" }), 0.3)
	local collector = L:block(c.X, c.Z, 6, 6, 0.5, { color = Constants.WHITE, name = "Collector" }, 0.3)
	collector:SetAttribute("Plot", plot.index)
	TycoonBuilder.label(collector, "COLLECT", "0", GOLD)
	local pads = {}
	for slot, at in TycoonBuilder.SPOTS.pads do
		L:block(at.X, at.Z, 5.8, 5.8, 0.3, deco({ color = plot.color, name = "PadRim" }), 0.3)
		local pad = L:block(at.X, at.Z, 5, 5, 0.5, { color = Constants.WHITE, name = "BuyPad" }, 0.3)
		pad:SetAttribute("Plot", plot.index)
		pad:SetAttribute("Slot", slot)
		pads[slot] = pad
	end
	return { collector = collector, pads = pads }
end

function TycoonBuilder.clear(plot)
	for _, d in plot.items:GetChildren() do
		d:Destroy()
	end
end

-- The pieces -------------------------------------------------------------------------------------------------------
local GEM = {
	mine1 = GOLD,
	mine2 = GOLD,
	mine3 = GOLD,
	mine4 = GOLD,
	mine5 = Color3.fromRGB(140, 120, 255),
	mine6 = Color3.fromRGB(140, 120, 255),
	mine7 = Color3.fromRGB(200, 245, 255),
	mine8 = Color3.fromRGB(200, 245, 255),
}

local BUILD = {}

local function mine(L, key)
	local at = TycoonBuilder.MINES[key]
	local inward = at.X < 0 and 1 or -1
	local big = (key == "mine4" or key == "mine6" or key == "mine8") and 1.2 or 1
	L:block(at.X, at.Z, 6, 6, 0.6, { color = Constants.LIGHT }, 0)
	L:block(at.X, at.Z, 4 * big, 4 * big, 6 * big, { color = Constants.WHITE, name = "Mine" }, 0.6)
	L:block(at.X, at.Z, 4.3 * big, 4.3 * big, 0.5, deco({ color = L.color, name = "Band" }), 4 * big)
	L:block(at.X, at.Z, 5 * big, 5 * big, 0.8, { color = L.color, name = "MineCap" }, 0.6 + 6 * big)
	L:block(at.X, at.Z, 2.4, 2.4, 1.6, deco({ color = Constants.GREY }), 1.4 + 6 * big)
	L:block(
		at.X,
		at.Z,
		1.2,
		1.2,
		1.2,
		deco({ color = GEM[key], material = Enum.Material.Neon, name = "Gem" }),
		3 + 6 * big
	)
	-- the spout on the inner face, where the cubes come out
	local spout = L:box(
		at.X + inward * (2 * big + 0.15),
		2.8,
		at.Z,
		0.3,
		1.8,
		1.8,
		deco({ color = Constants.DARK, name = "Spout" })
	)
	spout:SetAttribute("Plot", L.index)
	spout:SetAttribute("Gem", GEM[key])
	return { spout = spout }
end
for key in TycoonBuilder.MINES do
	BUILD[key] = mine
end

BUILD.wallFL = function(L)
	L:wall(-32, -31, -8, -31, 8)
end
BUILD.wallFR = function(L)
	L:wall(8, -31, 32, -31, 8)
end
BUILD.wallL = function(L)
	L:wall(-31, -26, -31, 26, 8)
end
BUILD.wallR = function(L)
	L:wall(31, -26, 31, 26, 8)
end
BUILD.wallB = function(L)
	L:wall(-26, 31, 26, 31, 8)
end

BUILD.gate = function(L)
	for _, sx in { -1, 1 } do
		L:block(sx * 6.5, -31, 3.4, 3.4, 12, { color = Constants.WHITE, name = "GatePier" }, 0)
		L:block(sx * 6.5, -31, 4, 4, 0.5, deco({ color = Constants.LIGHT }), 12)
	end
	L:block(0, -31, 16, 3, 3, { color = Constants.WHITE, name = "Lintel" }, 9)
	L:block(0, -31, 16.5, 3.4, 0.5, deco({ color = Constants.LIGHT }), 12)
	L:block(0, -31, 16.6, 3.2, 0.4, deco({ color = L.color, name = "Band" }), 10.2)
	L:merlons(-8, -31, 8, -31, 12.5)
	L:banner(0, -32.5, V3(0, 0, -1), 9.2, 2.6) -- (on the lintel, over the way in)
end

local function tower(L, key, h, crown)
	local at = TycoonBuilder.TOWERS[key]
	local top = L:tower(at.X, at.Z, 7, h, { crown = crown, floor = 7 })
	L:block(at.X, at.Z, 7.4, 7.4, 0.4, deco({ color = L.color, name = "Band" }), h - 3)
	local orb = L:block(
		at.X,
		at.Z,
		1.4,
		1.4,
		1.4,
		deco({
			color = crown == "spire" and Color3.fromRGB(140, 120, 255) or L.color,
			material = Enum.Material.Neon,
			name = "TowerTop",
		}),
		top + (crown == "spire" and 15.4 or 3.2)
	)
	return { top = orb.Position }
end
BUILD.towerFL = function(L)
	return tower(L, "towerFL", 16, "battlements")
end
BUILD.towerFR = function(L)
	return tower(L, "towerFR", 16, "battlements")
end
BUILD.towerBL = function(L)
	return tower(L, "towerBL", 20, "spire")
end
BUILD.towerBR = function(L)
	return tower(L, "towerBR", 20, "spire")
end

BUILD.forge = function(L)
	L:block(-11, -2, 6, 5, 4, { color = Constants.GREY, name = "Forge" }, 0)
	L:block(-11, -2, 6.4, 5.4, 0.5, deco({ color = Constants.LIGHT }), 4)
	L:block(-12.5, -1, 1.6, 1.6, 4, { color = Constants.LIGHT, name = "Chimney" }, 4.5)
	L:block(
		-11,
		-4.55,
		3,
		0.2,
		2,
		deco({ color = Color3.fromRGB(255, 140, 30), material = Enum.Material.Neon, name = "Fire" }),
		0.6
	)
end

BUILD.vault = function(L)
	L:block(11, -2, 6, 5, 4, { color = Constants.WHITE, name = "Vault" }, 0)
	L:block(11, -2, 6.4, 5.4, 0.5, deco({ color = L.color, name = "Band" }), 4)
	L:block(11, -4.55, 2.6, 0.2, 3, deco({ color = GOLD, material = Enum.Material.Neon, name = "VaultDoor" }), 0.4)
	for k = 0, 2 do
		L:block(13.6, -4.6 + k * 0.1, 1, 1, 0.4, deco({ color = GOLD, name = "Coins" }), 0.4 + k * 0.4)
	end
end

BUILD.keep1 = function(L)
	L:block(0, 16, 15, 13, 0.8, { color = Constants.LIGHT }, 0)
	L:block(0, 16, 14, 12, 12, { color = Constants.WHITE, name = "Keep" }, 0)
	L:block(0, 16, 14.5, 12.5, 0.5, deco({ color = Constants.LIGHT }), 12)
	L:block(0, 16, 14.3, 12.3, 0.4, deco({ color = L.color, name = "Band" }), 9.6)
	L:block(0, 9.9, 4, 0.2, 6, deco({ color = Constants.DARK, name = "KeepDoor" }), 0)
	for _, sx in { -1, 1 } do
		L:block(sx * 4.5, 9.9, 1.6, 0.2, 2.6, deco({ color = Constants.DARK, name = "Window" }), 6.4)
	end
	L:merlons(-7, 10, 7, 10, 12.5)
	L:merlons(-7, 22, 7, 22, 12.5)
	L:merlons(-7, 10, -7, 22, 12.5)
	L:merlons(7, 10, 7, 22, 12.5)
end

BUILD.hall = function(L)
	L:block(0, 17, 10, 8, 7, { color = Constants.WHITE, name = "Hall" }, 12.5)
	L:block(0, 17, 10.5, 8.5, 0.5, deco({ color = Constants.LIGHT }), 19.5)
	L:block(0, 17, 10.3, 8.3, 0.4, deco({ color = L.color, name = "Band" }), 17.6)
	for _, sx in { -1, 0, 1 } do
		L:block(sx * 3, 12.9, 1.4, 0.2, 2.6, deco({ color = Constants.DARK, name = "Window" }), 14.5)
	end
	L:merlons(-5, 13, 5, 13, 20)
	L:merlons(-5, 21, 5, 21, 20)
end

BUILD.spire = function(L)
	local top = L:tower(0, 17, 5, 8, { crown = "spire", y0 = 20, floor = 4, noWindows = true })
	L:block(0, 17, 5.4, 5.4, 0.4, deco({ color = L.color, name = "Band" }), top - 2)
end

BUILD.walks = function(L)
	-- flags along the tops of the walls, a light walk on each
	local runs = {
		{ -32, -31, -8, -31 },
		{ 8, -31, 32, -31 },
		{ -31, -26, -31, 26 },
		{ 31, -26, 31, 26 },
		{ -26, 31, 26, 31 },
	}
	for _, run in runs do
		local x0, z0, x1, z1 = run[1], run[2], run[3], run[4]
		for t = 0.25, 0.76, 0.5 do
			local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
			L:block(x, z, 0.3, 0.3, 4.5, deco({ color = Constants.LIGHT, name = "FlagPole" }), 8.5)
			L:block(x + 0.9, z, 1.6, 0.15, 1.1, deco({ color = L.color, name = "Flag" }), 11.6)
		end
	end
end

BUILD.statue = function(L)
	local p = L:at(-13, 13)
	local face = L.cf.LookVector.X > 0 and 1 or -1
	L.s:statue(p.X, p.Z, face, 0.8, nil, 0)
end

BUILD.banners = function(L)
	for _, sx in { -1, 1 } do
		L:banner(sx * 4.6, 9.8, V3(0, 0, -1), 2.2, 6)
	end
	for _, key in { "towerFL", "towerFR" } do
		local at = TycoonBuilder.TOWERS[key]
		L:banner(at.X, at.Z - 3.6, V3(0, 0, -1), 6, 5)
	end
end

BUILD.crown = function(L)
	local y = 40
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		L:block(
			math.cos(a) * 3,
			17 + math.sin(a) * 3,
			1.4,
			1.4,
			k % 2 == 0 and 2.6 or 1.6,
			deco({ color = GOLD, material = Enum.Material.Neon, name = "Crown" }),
			y
		)
	end
	L:block(0, 17, 6.6, 6.6, 0.6, deco({ color = GOLD, name = "Crown" }), y - 0.6)
end

BUILD.throne = function(L)
	L:block(0, 6.5, 9, 5, 0.8, { color = Constants.WHITE, name = "Dais" }, 0)
	L:block(0, 6.5, 9.4, 5.4, 0.3, deco({ color = GOLD, name = "DaisTrim" }), 0.8)
	L:block(0, 8, 2.6, 2, 4.6, { color = GOLD, name = "Throne" }, 0.8)
	L:block(0, 7, 2.6, 1.6, 1.2, { color = GOLD, name = "Throne" }, 0.8)
	for _, sx in { -1, 1 } do
		L:block(
			sx * 7.05,
			10.05,
			0.3,
			0.3,
			12,
			deco({ color = GOLD, material = Enum.Material.Neon, name = "GoldTrim" }),
			0
		)
	end
end

function TycoonBuilder.item(plot, key)
	local build = BUILD[key]
	if not build then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = key
	folder:SetAttribute("Item", key)
	folder.Parent = plot.items
	local L = localShapes(plot, folder)
	local out = build(L, key) or {}
	out.folder = folder
	return out
end

TycoonBuilder.BUILD = BUILD

return TycoonBuilder

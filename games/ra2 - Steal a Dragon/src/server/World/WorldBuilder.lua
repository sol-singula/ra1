-- Builds the whole map from primitive parts: the lobby with the leaderboards, the Dragon Road, 8 player
-- bases and the Practice Base. Returns a layout table the services use.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldBuilder = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(27, 29, 43)
local WHITE = rgb(255, 255, 255)

local BASE_COLORS = {
	rgb(255, 85, 85),
	rgb(70, 150, 255),
	rgb(80, 210, 110),
	rgb(255, 200, 50),
	rgb(170, 100, 255),
	rgb(255, 145, 50),
	rgb(255, 120, 200),
	rgb(40, 200, 190),
}
WorldBuilder.BASE_COLORS = BASE_COLORS

local BASE_W, BASE_D = 40, 44 -- width (x) and depth (z)
WorldBuilder.BASE_HALF = Vector3.new(BASE_W / 2, 30, BASE_D / 2)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function label(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = WHITE
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = INK
	for k, v in props do
		t[k] = v
	end
	t.Parent = parent
	return t
end

-- A floating sign (studs-sized, so it stays readable from far away on a phone).
local function billboard(adornee, w, h, offset, lines, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.new(w, 0, h, 0)
	gui.StudsOffset = offset
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 200
	gui.Parent = adornee
	local out = {}
	for i, l in lines do
		out[i] = label(gui, {
			Name = "Line" .. i,
			Size = UDim2.new(1, 0, l.h, 0),
			Position = UDim2.new(0, 0, l.y, 0),
			Text = l.text,
			TextColor3 = l.color or WHITE,
			Font = l.font or Enum.Font.FredokaOne,
		})
	end
	return gui, out
end

local function tree(parent, pos, scale)
	scale = scale or 1
	part({
		Name = "Trunk",
		Size = Vector3.new(1.4, 6, 1.4) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 3 * scale, 0)),
		Color = rgb(120, 80, 50),
		Parent = parent,
	})
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(7, 7, 7) * scale,
		CFrame = CFrame.new(pos + Vector3.new(0, 8 * scale, 0)),
		Color = rgb(70, 175, 80),
		Parent = parent,
	})
end

-- A leaderboard: a big board with a title and 10 rows. Returns { rows = { {rank, name, value} }, sub }.
local function leaderboard(parent, cf, title, color)
	local board = part({
		Name = "Leaderboard",
		Size = Vector3.new(16, 20, 1),
		CFrame = cf * CFrame.new(0, 12, 0),
		Color = rgb(35, 38, 58),
		Parent = parent,
	})
	part({
		Name = "Frame",
		Size = Vector3.new(17, 21, 0.8),
		CFrame = board.CFrame * CFrame.new(0, 0, 0.3),
		Color = color,
		Parent = parent,
	})
	for _, x in { -6, 6 } do
		part({
			Name = "Post",
			Size = Vector3.new(1, 2, 1),
			CFrame = cf * CFrame.new(x, 1, 0),
			Color = INK,
			Parent = parent,
		})
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(480, 600)
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, {
		Name = "Title",
		Size = UDim2.new(1, -20, 0, 70),
		Position = UDim2.new(0, 10, 0, 8),
		Text = title,
		TextColor3 = color,
		Font = Enum.Font.LuckiestGuy,
	})
	local sub = label(gui, {
		Name = "Sub",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.new(0, 10, 0, 76),
		Text = "Loading...",
		TextColor3 = rgb(200, 200, 215),
	})
	local rows = {}
	for i = 1, Constants.LEADERBOARD_SIZE do
		local y = 108 + (i - 1) * 48
		local bg = Instance.new("Frame")
		bg.Name = "Row" .. i
		bg.Size = UDim2.new(1, -24, 0, 42)
		bg.Position = UDim2.new(0, 12, 0, y)
		bg.BackgroundColor3 = i % 2 == 0 and rgb(48, 52, 78) or rgb(58, 62, 92)
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local medal = ({ rgb(255, 205, 60), rgb(210, 215, 230), rgb(225, 150, 90) })[i] or WHITE
		rows[i] = {
			rank = label(bg, {
				Name = "Rank",
				Size = UDim2.new(0, 56, 1, -6),
				Position = UDim2.new(0, 4, 0, 3),
				Text = "#" .. i,
				TextColor3 = medal,
			}),
			name = label(bg, {
				Name = "Name",
				Size = UDim2.new(0.58, -60, 1, -8),
				Position = UDim2.new(0, 64, 0, 4),
				Text = "",
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			value = label(bg, {
				Name = "Value",
				Size = UDim2.new(0.42, -12, 1, -8),
				Position = UDim2.new(0.58, 0, 0, 4),
				Text = "",
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}
	end
	return { rows = rows, sub = sub, part = board }
end

-- One player base. cf: centre of the floor; its -Z (look vector) points at the road.
local function buildBase(parent, index, cf)
	local color = BASE_COLORS[index]
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = parent
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	part({
		Name = "Floor",
		Size = Vector3.new(BASE_W, 0.4, BASE_D),
		CFrame = at(0, 0.2, 0),
		Color = rgb(235, 230, 220),
		Parent = model,
	})
	part({
		Name = "Rim",
		Size = Vector3.new(BASE_W + 2, 0.3, BASE_D + 2),
		CFrame = at(0, 0.15, 0),
		Color = color,
		Parent = model,
	})
	-- walls: back, sides, and the front with a 16-stud gate
	local wallColor = color:Lerp(WHITE, 0.35)
	part({
		Name = "WallBack",
		Size = Vector3.new(BASE_W, 9, 1),
		CFrame = at(0, 4.9, BASE_D / 2),
		Color = wallColor,
		Parent = model,
	})
	part({
		Name = "WallL",
		Size = Vector3.new(1, 9, BASE_D),
		CFrame = at(-BASE_W / 2, 4.9, 0),
		Color = wallColor,
		Parent = model,
	})
	part({
		Name = "WallR",
		Size = Vector3.new(1, 9, BASE_D),
		CFrame = at(BASE_W / 2, 4.9, 0),
		Color = wallColor,
		Parent = model,
	})
	part({
		Name = "WallFL",
		Size = Vector3.new(12, 9, 1),
		CFrame = at(-14, 4.9, -BASE_D / 2),
		Color = wallColor,
		Parent = model,
	})
	part({
		Name = "WallFR",
		Size = Vector3.new(12, 9, 1),
		CFrame = at(14, 4.9, -BASE_D / 2),
		Color = wallColor,
		Parent = model,
	})
	for _, x in { -8.5, 8.5 } do
		part({
			Name = "GatePost",
			Size = Vector3.new(1.6, 11, 1.6),
			CFrame = at(x, 5.9, -BASE_D / 2),
			Color = color,
			Parent = model,
		})
	end
	local gateTop = part({
		Name = "GateTop",
		Size = Vector3.new(18.6, 1.4, 1.6),
		CFrame = at(0, 11.6, -BASE_D / 2),
		Color = color,
		Parent = model,
	})
	local laser = part({
		Name = "Laser",
		Size = Vector3.new(16, 10.5, 0.4),
		CFrame = at(0, 5.6, -BASE_D / 2),
		Color = rgb(255, 50, 60),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	-- sign over the gate: owner name and lock state
	local _, lines = billboard(gateTop, 18, 5, Vector3.new(0, 3.5, 0), {
		{ text = "EMPTY BASE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "", h = 0.4, y = 0.6, color = rgb(255, 230, 120) },
	})
	-- beacon so you can find your base
	local beacon = part({
		Name = "Beacon",
		Size = Vector3.new(1.2, 40, 1.2),
		CFrame = at(-BASE_W / 2 + 1, 20, BASE_D / 2 - 1),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	-- nests: 4 x 4, front row first
	local nests = {}
	local xs, zs = { -13.5, -4.5, 4.5, 13.5 }, { -8, -1, 6, 13 }
	for row = 1, 4 do
		for col = 1, 4 do
			local i = (row - 1) * 4 + col
			local pad = part({
				Name = "Nest" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 6.4, 6.4),
				CFrame = at(xs[col], 0.8, zs[row]) * CFrame.Angles(0, 0, math.rad(90)),
				Color = rgb(190, 150, 95),
				Material = Enum.Material.WoodPlanks,
				Parent = model,
			})
			part({
				Name = "Straw",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 5, 5),
				CFrame = at(xs[col], 1.3, zs[row]) * CFrame.Angles(0, 0, math.rad(90)),
				Color = rgb(240, 210, 120),
				Material = Enum.Material.Fabric,
				Parent = pad,
			})
			nests[i] = { pad = pad, feet = at(xs[col], 1.45, zs[row]) }
		end
	end
	-- lock pad at the back, collect pad front-left, egg stand front-right
	local lockPad = part({
		Name = "LockPad",
		Size = Vector3.new(7, 0.5, 5),
		CFrame = at(0, 0.55, 19),
		Color = rgb(255, 70, 70),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	billboard(
		lockPad,
		8,
		2.5,
		Vector3.new(0, 3, 0),
		{ { text = "🔒 LOCK", h = 1, y = 0, font = Enum.Font.LuckiestGuy } },
		60
	)
	local collectPad = part({
		Name = "CollectPad",
		Size = Vector3.new(7, 0.5, 6),
		CFrame = at(-13, 0.55, -17),
		Color = rgb(255, 205, 50),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local _, collectLines = billboard(collectPad, 9, 3.5, Vector3.new(0, 3.5, 0), {
		{ text = "💰 COINS", h = 0.5, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "0", h = 0.5, y = 0.5, color = rgb(255, 230, 120) },
	}, 60)
	local eggStand = part({
		Name = "EggStand",
		Size = Vector3.new(4, 1.6, 4),
		CFrame = at(13, 0.8, -17),
		Color = rgb(250, 245, 235),
		Parent = model,
	})
	return {
		index = index,
		cf = cf,
		color = color,
		model = model,
		laser = laser,
		signLines = lines,
		beacon = beacon,
		nests = nests,
		lockPad = lockPad,
		collectPad = collectPad,
		collectLines = collectLines,
		eggStand = eggStand,
		gateCf = at(0, 0.5, -BASE_D / 2 - 4),
	}
end

local function lighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = rgb(110, 110, 125)
	Lighting.OutdoorAmbient = rgb(150, 150, 165)
	Lighting.GlobalShadows = true
	local function effect(className, values)
		if Lighting:FindFirstChildOfClass(className) then
			return
		end
		local e = Instance.new(className)
		for k, v in values do
			e[k] = v
		end
		e.Parent = Lighting
	end
	effect("Atmosphere", { Density = 0.25, Haze = 1, Color = rgb(200, 220, 255), Decay = rgb(120, 140, 190) })
	effect("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.08, Brightness = 0.02 })
	effect("BloomEffect", { Intensity = 0.5, Size = 24, Threshold = 1.6 })
	effect("SunRaysEffect", { Intensity = 0.04, Spread = 0.8 })
end

function WorldBuilder.build()
	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	lighting()
	local map = folder("Map", workspace)
	part({
		Name = "Ground",
		Size = Vector3.new(700, 2, 700),
		CFrame = CFrame.new(0, -1, 0),
		Color = rgb(110, 195, 95),
		Material = Enum.Material.Grass,
		Parent = map,
	})

	-- Dragon Road
	local road = Instance.new("Model")
	road.Name = "DragonRoad"
	road.Parent = map
	local roadLen = Constants.ROAD_END_X - Constants.ROAD_START_X + 6
	part({
		Name = "Road",
		Size = Vector3.new(roadLen, 0.5, 14),
		CFrame = CFrame.new(0, 0.25, 0),
		Color = rgb(125, 85, 205),
		Parent = road,
	})
	for _, z in { -7.4, 7.4 } do
		part({
			Name = "Edge",
			Size = Vector3.new(roadLen, 0.7, 0.8),
			CFrame = CFrame.new(0, 0.35, z),
			Color = rgb(255, 210, 60),
			Material = Enum.Material.Neon,
			Parent = road,
		})
	end
	for x = Constants.ROAD_START_X + 8, Constants.ROAD_END_X - 8, 16 do
		part({
			Name = "Arrow",
			Size = Vector3.new(1.2, 0.1, 5),
			CFrame = CFrame.new(x, 0.55, 0) * CFrame.Angles(0, math.rad(-35), 0) * CFrame.new(0, 0, -1.6),
			Color = WHITE,
			Transparency = 0.3,
			Parent = road,
		})
		part({
			Name = "Arrow",
			Size = Vector3.new(1.2, 0.1, 5),
			CFrame = CFrame.new(x, 0.55, 0) * CFrame.Angles(0, math.rad(35), 0) * CFrame.new(0, 0, 1.6),
			Color = WHITE,
			Transparency = 0.3,
			Parent = road,
		})
	end
	-- the cave the dragons walk out of, and the one they leave through
	for _, x in { Constants.ROAD_START_X - 4, Constants.ROAD_END_X + 4 } do
		part({
			Name = "CaveL",
			Size = Vector3.new(6, 12, 3),
			CFrame = CFrame.new(x, 6, -9),
			Color = rgb(90, 85, 100),
			Material = Enum.Material.Slate,
			Parent = road,
		})
		part({
			Name = "CaveR",
			Size = Vector3.new(6, 12, 3),
			CFrame = CFrame.new(x, 6, 9),
			Color = rgb(90, 85, 100),
			Material = Enum.Material.Slate,
			Parent = road,
		})
		part({
			Name = "CaveTop",
			Size = Vector3.new(6, 3, 21),
			CFrame = CFrame.new(x, 13.5, 0),
			Color = rgb(90, 85, 100),
			Material = Enum.Material.Slate,
			Parent = road,
		})
		part({
			Name = "CaveDark",
			Size = Vector3.new(1, 12, 15),
			CFrame = CFrame.new(x + (x < 0 and -2.5 or 2.5), 6, 0),
			Color = rgb(20, 18, 30),
			Parent = road,
		})
	end
	local startCave = road:FindFirstChild("CaveTop")
	billboard(startCave, 26, 4.5, Vector3.new(0, 4, 0), {
		{ text = "🐉 DRAGON ROAD", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 70) },
		{ text = "Grab a dragon! Run home!", h = 0.4, y = 0.6 },
	})

	-- Lobby
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = map
	part({
		Name = "Plaza",
		Size = Vector3.new(60, 0.6, 70),
		CFrame = CFrame.new(-145, 0.3, 0),
		Color = rgb(245, 235, 215),
		Material = Enum.Material.Pavement,
		Parent = lobby,
	})
	for i = -2, 2 do
		part({
			Name = "Stripe",
			Size = Vector3.new(60, 0.62, 3),
			CFrame = CFrame.new(-145, 0.31, i * 13),
			Color = rgb(255, 215, 120),
			Parent = lobby,
		})
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(-162, 0.6, 0) * CFrame.Angles(0, math.rad(-90), 0)
	spawn.Color = rgb(255, 205, 50)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Parent = lobby
	-- three leaderboards in a row on the right of the spawn, each turned to face it
	local facing = Vector3.new(-162, 0.6, 0)
	local boards = {
		coins = leaderboard(lobby, CFrame.lookAt(Vector3.new(-150, 0.6, 27), facing), "TOP COINS", rgb(255, 205, 50)),
		steals = leaderboard(lobby, CFrame.lookAt(Vector3.new(-132, 0.6, 30), facing), "TOP THIEVES", rgb(255, 90, 90)),
		income = leaderboard(
			lobby,
			CFrame.lookAt(Vector3.new(-114, 0.6, 30), facing),
			"BEST DRAGONS",
			rgb(110, 200, 255)
		),
	}
	-- the FREE dragon stand for new players
	local freePad = part({
		Name = "FreePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 8, 8),
		CFrame = CFrame.new(-140, 1.2, 8) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(255, 205, 50),
		Material = Enum.Material.Neon,
		Parent = lobby,
	})
	billboard(freePad, 14, 3, Vector3.new(0, 8.5, 0), {
		{ text = "FREE DRAGON!", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 70) },
		{ text = "for new players", h = 0.4, y = 0.6 },
	})
	-- welcome sign
	local welcome = part({
		Name = "Welcome",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(-113, 28, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = lobby,
	})
	billboard(welcome, 40, 9, Vector3.zero, {
		{ text = "STEAL A DRAGON", h = 0.62, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 120, 60) },
		{ text = "Grab. Run home. Lock. Steal!", h = 0.38, y = 0.62 },
	})

	-- Bases: 4 north of the road facing south, 4 south facing north
	local basesFolder = folder("Bases", workspace)
	local bases = {}
	local xs = { -75, -25, 25, 75 }
	for i = 1, Constants.MAX_BASES do
		local north = i <= 4
		local x = xs[(i - 1) % 4 + 1]
		local z = north and 40 or -40
		local cf = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0))
		bases[i] = buildBase(basesFolder, i, cf)
	end

	-- Practice Base: always open, for the tutorial steal
	local pcf = CFrame.lookAt(Vector3.new(-145, 0, -62), Vector3.new(-145, 0, 0))
	local practice = Instance.new("Model")
	practice.Name = "PracticeBase"
	practice.Parent = map
	part({
		Name = "Floor",
		Size = Vector3.new(24, 0.4, 20),
		CFrame = pcf * CFrame.new(0, 0.2, 0),
		Color = rgb(210, 230, 255),
		Parent = practice,
	})
	part({
		Name = "WallBack",
		Size = Vector3.new(24, 6, 1),
		CFrame = pcf * CFrame.new(0, 3.4, 10),
		Color = rgb(120, 170, 255),
		Parent = practice,
	})
	local practiceNest = part({
		Name = "Nest",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 6.4, 6.4),
		CFrame = pcf * CFrame.new(0, 0.8, 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(190, 150, 95),
		Material = Enum.Material.WoodPlanks,
		Parent = practice,
	})
	billboard(practiceNest, 16, 3.4, Vector3.new(0, 10, 0), {
		{ text = "PRACTICE BASE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(120, 190, 255) },
		{ text = "Steal from Sneaky Sam!", h = 0.4, y = 0.6 },
	})

	-- trees around the edge
	local deco = folder("Decor", map)
	for x = -180, 140, 32 do
		tree(deco, Vector3.new(x, 0, 92))
		tree(deco, Vector3.new(x + 16, 0, -92))
	end
	for z = -60, 60, 30 do
		tree(deco, Vector3.new(130, 0, z), 1.2)
	end

	WorldBuilder.layout = {
		bases = bases,
		boards = boards,
		freePad = freePad,
		freeFeet = CFrame.new(-140, 1.8, 8) * CFrame.Angles(0, math.rad(-90), 0),
		practiceFeet = pcf * CFrame.new(0, 1.2, 2),
		practiceNest = practiceNest,
		practiceCenter = pcf.Position,
		spawn = spawn,
		roadZ = 0,
		roadY = 0.5,
	}
	return WorldBuilder.layout
end

return WorldBuilder

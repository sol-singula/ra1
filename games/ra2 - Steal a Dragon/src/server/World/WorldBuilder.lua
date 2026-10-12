-- Builds the whole map from primitive parts: the lobby with the leaderboards, the Dragon Road, 8 player
-- bases and the Practice Base. Returns a layout table the services use.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local DragonBuilder = require(script.Parent.DragonBuilder)
local Scenery = require(script.Parent.Scenery)

local WorldBuilder = {}

local rgb = Scenery.rgb

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

local part = Scenery.part

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

-- One player base: a little castle. cf: centre of the floor; its -Z (look vector) points at the road.
local STONE = rgb(188, 180, 168)
local STONE_DARK = rgb(140, 132, 124)

local function buildBase(parent, index, cf)
	local color = BASE_COLORS[index]
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = parent
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local function pos(x, y, z)
		return (cf * CFrame.new(x, y, z)).Position
	end
	part({
		Name = "Floor",
		Size = Vector3.new(BASE_W, 0.4, BASE_D),
		CFrame = at(0, 0.2, 0),
		Color = color:Lerp(rgb(150, 142, 134), 0.68),
		Parent = model,
	})
	part({
		Name = "Rim",
		Size = Vector3.new(BASE_W + 3, 0.3, BASE_D + 3),
		CFrame = at(0, 0.15, 0),
		Color = STONE_DARK,
		Material = Enum.Material.Cobblestone,
		Parent = model,
	})
	-- checker tiles in two soft shades of the base colour
	local soft = color:Lerp(rgb(175, 166, 156), 0.55)
	for ix = 0, 4 do
		for iz = 0, 5 do
			if (ix + iz) % 2 == 0 then
				part({
					Name = "Tile",
					Size = Vector3.new(8, 0.05, 7.33),
					CFrame = at(-16 + ix * 8, 0.42, -18.33 + iz * 7.33),
					Color = soft,
					CastShadow = false,
					CanCollide = false,
					Parent = model,
				})
			end
		end
	end
	-- stone walls with a coloured band and battlements; the front has a 16-stud gate
	local function wall(name, size, cframe)
		local w = part({
			Name = name,
			Size = size,
			CFrame = cframe,
			Color = STONE,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
		part({
			Name = "Band",
			Size = Vector3.new(size.X + 0.1, 1.2, size.Z + 0.1),
			CFrame = cframe * CFrame.new(0, size.Y / 2 - 1.6, 0),
			Color = color,
			CastShadow = false,
			Parent = model,
		})
		-- battlements along the top
		local long = size.X > size.Z and "X" or "Z"
		local len = long == "X" and size.X or size.Z
		local count = math.floor(len / 4)
		for i = 0, count - 1 do
			local offset = -len / 2 + 2 + i * 4
			if i % 2 == 0 then
				part({
					Name = "Merlon",
					Size = long == "X" and Vector3.new(2, 1.6, size.Z + 0.3) or Vector3.new(size.X + 0.3, 1.6, 2),
					CFrame = cframe
						* CFrame.new(long == "X" and offset or 0, size.Y / 2 + 0.8, long == "Z" and offset or 0),
					Color = STONE,
					Material = Enum.Material.Cobblestone,
					CastShadow = false,
					Parent = model,
				})
			end
		end
		return w
	end
	wall("WallBack", Vector3.new(BASE_W, 9, 1.4), at(0, 4.9, BASE_D / 2))
	wall("WallL", Vector3.new(1.4, 9, BASE_D), at(-BASE_W / 2, 4.9, 0))
	wall("WallR", Vector3.new(1.4, 9, BASE_D), at(BASE_W / 2, 4.9, 0))
	wall("WallFL", Vector3.new(12, 9, 1.4), at(-14, 4.9, -BASE_D / 2))
	wall("WallFR", Vector3.new(12, 9, 1.4), at(14, 4.9, -BASE_D / 2))
	-- towers: two at the back corners, two guarding the gate
	Scenery.tower(model, pos(-BASE_W / 2, 0, BASE_D / 2), 6, 13, STONE, color, color)
	Scenery.tower(model, pos(BASE_W / 2, 0, BASE_D / 2), 6, 13, STONE, color, color)
	Scenery.tower(model, pos(-9.5, 0, -BASE_D / 2), 4.4, 12, STONE, color, color)
	Scenery.tower(model, pos(9.5, 0, -BASE_D / 2), 4.4, 12, STONE, color, color)
	local gateTop = part({
		Name = "GateTop",
		Size = Vector3.new(16, 2, 2),
		CFrame = at(0, 11.4, -BASE_D / 2),
		Color = STONE_DARK,
		Material = Enum.Material.Cobblestone,
		Parent = model,
	})
	part({
		Name = "GateBanner",
		Size = Vector3.new(12, 1.4, 0.3),
		CFrame = at(0, 11.4, -BASE_D / 2 - 1.1),
		Color = color,
		CastShadow = false,
		Parent = model,
	})
	local laser = part({
		Name = "Laser",
		Size = Vector3.new(15, 10.4, 0.4),
		CFrame = at(0, 5.6, -BASE_D / 2),
		Color = rgb(255, 50, 60),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	-- welcome mat outside the gate and a lantern on each side
	part({
		Name = "Mat",
		Size = Vector3.new(12, 0.1, 6),
		CFrame = at(0, 0.05, -BASE_D / 2 - 4),
		Color = color:Lerp(rgb(160, 150, 140), 0.35),
		CastShadow = false,
		CanCollide = false,
		Parent = model,
	})
	Scenery.lantern(model, pos(-13.5, 0, -BASE_D / 2 - 3), 6)
	Scenery.lantern(model, pos(13.5, 0, -BASE_D / 2 - 3), 6)
	-- sign over the gate: owner name and lock state
	local _, lines = billboard(gateTop, 18, 5, Vector3.new(0, 4, 0), {
		{ text = "EMPTY BASE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "", h = 0.4, y = 0.6, color = rgb(255, 230, 120) },
	}, 110)
	-- beacon so you can find your base: a glowing crystal over the back-left tower
	local beacon = part({
		Name = "Beacon",
		Size = Vector3.new(2.2, 3.6, 2.2),
		CFrame = at(-BASE_W / 2, 26, BASE_D / 2) * CFrame.Angles(0, math.rad(45), 0),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})
	-- nests: 4 x 4 on a raised wooden dais, front row first
	part({
		Name = "Dais",
		Size = Vector3.new(36, 0.4, 28),
		CFrame = at(0, 0.6, 2.5),
		Color = rgb(196, 160, 112),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	local nests = {}
	local xs, zs = { -13.5, -4.5, 4.5, 13.5 }, { -8, -1, 6, 13 }
	for row = 1, 4 do
		for col = 1, 4 do
			local i = (row - 1) * 4 + col
			local pad = part({
				Name = "Nest" .. i,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 6.2, 6.2),
				CFrame = at(xs[col], 1.1, zs[row]) * CFrame.Angles(0, 0, math.rad(90)),
				Color = rgb(150, 105, 65),
				Material = Enum.Material.WoodPlanks,
				Parent = model,
			})
			part({
				Name = "Straw",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 5, 5),
				CFrame = at(xs[col], 1.55, zs[row]) * CFrame.Angles(0, 0, math.rad(90)),
				Color = rgb(245, 215, 125),
				Material = Enum.Material.Fabric,
				CastShadow = false,
				Parent = pad,
			})
			nests[i] = { pad = pad, feet = at(xs[col], 1.7, zs[row]) }
		end
	end
	-- lock pad at the back, collect pad front-left with a treasure chest, egg stand front-right
	local lockPad = part({
		Name = "LockPad",
		Size = Vector3.new(7, 0.5, 4),
		CFrame = at(0, 0.6, 19.5),
		Color = rgb(230, 60, 60),
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
		CFrame = at(-13, 0.6, -17),
		Color = rgb(245, 190, 40),
		Parent = model,
	})
	local _, collectLines = billboard(collectPad, 9, 3.5, Vector3.new(0, 3.5, 0), {
		{ text = "💰 COINS", h = 0.5, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "0", h = 0.5, y = 0.5, color = rgb(255, 230, 120) },
	}, 60)
	part({
		Name = "Chest",
		Size = Vector3.new(3.4, 2, 2.2),
		CFrame = at(-18, 1.4, -17),
		Color = rgb(140, 90, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Name = "ChestLid",
		Size = Vector3.new(3.6, 0.8, 2.4),
		CFrame = at(-18, 2.7, -17),
		Color = rgb(255, 200, 60),
		Material = Enum.Material.Foil,
		Parent = model,
	})
	for _, c in { { -16.5, 0.7, -15.4 }, { -17.2, 0.7, -18.8 }, { -16.2, 1.2, -18.2 } } do
		Scenery.ball(
			model,
			"Coin",
			pos(c[1], c[2], c[3]),
			0.9,
			rgb(255, 205, 50),
			Enum.Material.Foil,
			{ CastShadow = false, CanCollide = false }
		)
	end
	local eggStand = part({
		Name = "EggStand",
		Size = Vector3.new(4, 1.6, 4),
		CFrame = at(13, 0.8, -17),
		Color = rgb(250, 245, 235),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	part({
		Name = "EggTrim",
		Size = Vector3.new(4.4, 0.4, 4.4),
		CFrame = at(13, 1.5, -17),
		Color = rgb(255, 200, 60),
		Material = Enum.Material.Foil,
		CastShadow = false,
		Parent = model,
	})
	-- wall lanterns inside
	for _, x in { -19, 19 } do
		part({
			Name = "WallLamp",
			Size = Vector3.new(0.8, 1.2, 0.8),
			CFrame = at(x * 0.95, 6.5, 0),
			Color = rgb(255, 200, 90),
			Material = Enum.Material.Neon,
			CastShadow = false,
			Parent = model,
		})
	end
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
		-- where the owner spawns: just inside the gate, facing the road
		homeCf = at(0, 3, -BASE_D / 2 + 6),
	}
end

local function lighting()
	-- Late-afternoon sun, toned down: plastic bricks look washed out under strong light, so brightness, ambient
	-- and exposure stay low, and colour comes from saturation instead.
	Lighting.ClockTime = 15.2
	Lighting.Brightness = 1.8
	Lighting.ExposureCompensation = -0.25
	Lighting.Ambient = rgb(80, 78, 92)
	Lighting.OutdoorAmbient = rgb(118, 116, 132)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.3
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
	effect(
		"Atmosphere",
		{ Density = 0.28, Haze = 0.5, Glare = 0, Color = rgb(190, 205, 235), Decay = rgb(120, 130, 175) }
	)
	effect(
		"ColorCorrectionEffect",
		{ Saturation = 0.15, Contrast = 0.18, Brightness = -0.04, TintColor = rgb(255, 246, 236) }
	)
	effect("BloomEffect", { Intensity = 0.25, Size = 20, Threshold = 2.2 })
	effect("SunRaysEffect", { Intensity = 0.02, Spread = 0.6 })
end

-- Places where scenery must not go: the lobby, the road and its sidewalks, the bases, the Practice Base.
local function clear(x, z)
	if x > -182 and x < -108 and math.abs(z) < 44 then
		return false
	end
	if math.abs(z) < 20 and x > -130 and x < 128 then
		return false
	end
	for _, bx in { -75, -25, 25, 75 } do
		if math.abs(x - bx) < 28 and math.abs(z) > 12 and math.abs(z) < 70 then
			return false
		end
	end
	if x > -165 and x < -125 and z > -80 and z < -44 then
		return false
	end
	return true
end
WorldBuilder.isClear = clear

-- A rocky cave mouth facing along the road, at the far (east) end where dragons leave: dir = +1, with a whole
-- mountain behind it when mountain is true.
local function caveMountain(parent, x, dir, glow, mountain)
	local rock = rgb(120, 112, 128)
	local mouth = x + dir * 2
	for _, z in { -10.5, 10.5 } do
		part({
			Name = "CavePillar",
			Size = Vector3.new(8, 16, 6),
			CFrame = CFrame.new(mouth, 8, z) * CFrame.Angles(0, 0, math.rad(dir * 4)),
			Color = rock,
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	part({
		Name = "CaveTop",
		Size = Vector3.new(8, 5, 27),
		CFrame = CFrame.new(mouth, 17, 0),
		Color = rock,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	part({
		Name = "CaveDark",
		Size = Vector3.new(1, 15, 15),
		CFrame = CFrame.new(mouth + dir * 3.5, 7.5, 0),
		Color = rgb(18, 15, 28),
		Parent = parent,
	})
	local glowPart = part({
		Name = "CaveGlow",
		Size = Vector3.new(6, 0.2, 13),
		CFrame = CFrame.new(mouth + dir * 1, 0.6, 0),
		Color = glow,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = parent,
	})
	-- rocks piled on top of and behind the arch, so the lobby side looks like a rocky hill too
	local rng = Random.new(x > 0 and 11 or 7)
	for _, m in { { -9, 13 }, { 0, 15.5 }, { 9, 13 } } do
		Scenery.ball(
			parent,
			"CaveRock",
			Vector3.new(mouth + dir * 7.5, m[2] * 0.36, m[1]),
			m[2],
			rock:Lerp(rgb(150, 140, 155), rng:NextNumber() * 0.5),
			Enum.Material.Slate
		)
	end
	for _, m in { { 0, 21, -8, 9 }, { 1, 22.5, 3, 11 }, { -1, 20.5, 10, 8 } } do
		Scenery.ball(
			parent,
			"CaveRock",
			Vector3.new(mouth + m[1], m[2], m[3]),
			m[4],
			rock:Lerp(rgb(90, 85, 100), rng:NextNumber()),
			Enum.Material.Slate
		)
	end
	for _, m in
		(mountain and {
			{ 14, 18, 0, 44 },
			{ 10, 8, -22, 30 },
			{ 10, 8, 22, 30 },
			{ 26, 22, 12, 40 },
			{ 24, 20, -14, 38 },
		} or {})
	do
		Scenery.ball(
			parent,
			"CaveRock",
			Vector3.new(x + dir * m[1], m[2] - 6, m[3]),
			m[4],
			rock:Lerp(rgb(90, 85, 100), rng:NextNumber()),
			Enum.Material.Slate
		)
	end
	if mountain then
		Scenery.ball(parent, "Snow", Vector3.new(x + dir * 18, 30, 4), 18, rgb(245, 248, 255), Enum.Material.Snow)
	end
	-- glowing crystals by the mouth
	for i, c in { { -14, 3, 30 }, { -16, 2.2, -25 }, { 14, 2.6, 20 }, { 15, 3.4, -30 } } do
		part({
			Name = "Crystal",
			Size = Vector3.new(1.6, c[2] * 2, 1.6),
			CFrame = CFrame.new(mouth - dir * 1, c[2], c[1]) * CFrame.Angles(math.rad(c[3]), 0, math.rad(i * 9)),
			Color = glow,
			Material = Enum.Material.Neon,
			CastShadow = false,
			CanCollide = false,
			Parent = parent,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 22
	light.Brightness = 2
	light.Parent = glowPart
end

-- The Dragon Gate at the start of the road: an open stone arch with a glowing lava pool where new dragons
-- appear, and the road's name on top. Open, so the lobby can see straight down the road through it.
local function dragonGate(parent, x)
	local rock = rgb(112, 104, 120)
	for _, z in { -9.5, 9.5 } do
		part({
			Name = "GatePillar",
			Size = Vector3.new(4, 16, 4),
			CFrame = CFrame.new(x, 8, z),
			Color = rock,
			Material = Enum.Material.Slate,
			Parent = parent,
		})
		part({
			Name = "GatePillarCap",
			Size = Vector3.new(5, 1.2, 5),
			CFrame = CFrame.new(x, 16.6, z),
			Color = rgb(240, 185, 55),
			Parent = parent,
		})
	end
	local top = part({
		Name = "GateTop",
		Size = Vector3.new(4, 3, 24),
		CFrame = CFrame.new(x, 18.7, 0),
		Color = rock,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	local pool = part({
		Name = "GateGlow",
		Size = Vector3.new(6, 0.2, 12),
		CFrame = CFrame.new(x + 1, 0.62, 0),
		Color = rgb(255, 120, 40),
		Material = Enum.Material.Neon,
		CastShadow = false,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 130, 50)
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = pool
	billboard(top, 26, 4.5, Vector3.new(0, 4.5, 0), {
		{ text = "🐉 DRAGON ROAD", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 70) },
		{ text = "Grab a dragon! Run home!", h = 0.4, y = 0.6 },
	})
	return top
end

function WorldBuilder.build()
	local old = workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	lighting()
	local rng = Random.new(42)
	local map = folder("Map", workspace)
	part({
		Name = "Ground",
		Size = Vector3.new(800, 2, 800),
		CFrame = CFrame.new(0, -1, 0),
		Color = rgb(88, 162, 76),
		Material = Enum.Material.Grass,
		Parent = map,
	})
	-- lighter meadow patches so the grass isn't one flat colour
	local deco = folder("Decor", map)
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-260, 220), rng:NextNumber(-150, 150)
		if clear(x, z) then
			Scenery.disc(
				deco,
				"Meadow",
				Vector3.new(x, 0.02, z),
				rng:NextNumber(18, 40),
				0.04,
				rgb(104, 178, 86):Lerp(rgb(80, 150, 72), rng:NextNumber()),
				Enum.Material.Grass,
				{ CastShadow = false, CanCollide = false }
			)
		end
	end

	-- Dragon Road: a royal carpet on a stone causeway, with sidewalks, lanterns and banners
	local road = Instance.new("Model")
	road.Name = "DragonRoad"
	road.Parent = map
	local roadLen = Constants.ROAD_END_X - Constants.ROAD_START_X + 6
	part({
		Name = "Causeway",
		Size = Vector3.new(roadLen, 0.4, 18),
		CFrame = CFrame.new(0, 0.2, 0),
		Color = rgb(150, 140, 160),
		Material = Enum.Material.Slate,
		Parent = road,
	})
	part({
		Name = "Road",
		Size = Vector3.new(roadLen, 0.5, 13),
		CFrame = CFrame.new(0, 0.25, 0),
		Color = rgb(130, 80, 200),
		Material = Enum.Material.Fabric,
		Parent = road,
	})
	for _, z in { -6.9, 6.9 } do
		part({
			Name = "Edge",
			Size = Vector3.new(roadLen, 0.62, 0.7),
			CFrame = CFrame.new(0, 0.31, z),
			Color = rgb(240, 190, 50),
			CastShadow = false,
			Parent = road,
		})
	end
	for _, z in { -14, 14 } do
		part({
			Name = "Sidewalk",
			Size = Vector3.new(roadLen + 20, 0.3, 10),
			CFrame = CFrame.new(-4, 0.15, z),
			Color = rgb(172, 165, 155),
			Material = Enum.Material.Cobblestone,
			Parent = road,
		})
	end
	for x = Constants.ROAD_START_X + 8, Constants.ROAD_END_X - 8, 16 do
		for _, a in { -35, 35 } do
			part({
				Name = "Arrow",
				Size = Vector3.new(1.2, 0.1, 5),
				CFrame = CFrame.new(x, 0.55, 0)
					* CFrame.Angles(0, math.rad(a), 0)
					* CFrame.new(0, 0, a < 0 and -1.6 or 1.6),
				Color = rgb(255, 225, 120),
				Transparency = 0.25,
				CastShadow = false,
				Parent = road,
			})
		end
	end
	local banner = 0
	for x = Constants.ROAD_START_X + 14, Constants.ROAD_END_X - 6, 24 do
		for _, z in { -9.6, 9.6 } do
			Scenery.lantern(road, Vector3.new(x, 0.3, z), 8)
			banner += 1
			part({
				Name = "Banner",
				Size = Vector3.new(0.2, 4, 2.2),
				CFrame = CFrame.new(x, 6, z + (z > 0 and 0.6 or -0.6)) * CFrame.Angles(0, math.rad(90), 0),
				Color = BASE_COLORS[(banner - 1) % #BASE_COLORS + 1],
				CastShadow = false,
				Parent = road,
			})
		end
	end
	-- paths from the sidewalk to each base gate
	for _, bx in { -75, -25, 25, 75 } do
		for _, z in { -20, 20 } do
			part({
				Name = "Path",
				Size = Vector3.new(12, 0.3, 4),
				CFrame = CFrame.new(bx, 0.15, z),
				Color = rgb(172, 165, 155),
				Material = Enum.Material.Cobblestone,
				Parent = road,
			})
		end
	end
	-- New dragons appear at the Dragon Gate next to the lobby (an open arch, so the spawn looks straight down the
	-- road) and leave through the crystal cave at the far end.
	dragonGate(road, Constants.ROAD_START_X - 3)
	caveMountain(road, Constants.ROAD_END_X + 4, 1, rgb(110, 220, 255), true)

	-- Lobby: a plaza at the start of the road. New players spawn on its east side looking down the road, with the
	-- free dragon right in front of them. The three leaderboards stand side by side along the north edge, facing
	-- in; the golden statue stands on the south side.
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = map
	part({
		Name = "Plaza",
		Size = Vector3.new(62, 0.6, 76),
		CFrame = CFrame.new(-145, 0.3, 0),
		Color = rgb(196, 186, 170),
		Material = Enum.Material.Cobblestone,
		Parent = lobby,
	})
	Scenery.disc(
		lobby,
		"PlazaRing",
		Vector3.new(-145, 0.62, 0),
		40,
		0.06,
		rgb(232, 180, 70),
		nil,
		{ CastShadow = false, CanCollide = false }
	)
	Scenery.disc(
		lobby,
		"PlazaInner",
		Vector3.new(-145, 0.66, 0),
		37,
		0.06,
		rgb(210, 202, 188),
		Enum.Material.Marble,
		{ CastShadow = false, CanCollide = false }
	)
	-- hedges around the plaza with openings toward the road and the Practice Base
	for _, h in { { -145, 38.5, 62, 2 }, { -176.5, 0, 2, 76 }, { -125, -38.5, 22, 2 }, { -165, -38.5, 22, 2 } } do
		part({
			Name = "Hedge",
			Size = Vector3.new(h[3], 2.6, h[4]),
			CFrame = CFrame.new(h[1], 1.3, h[2]),
			Color = rgb(55, 128, 62),
			Material = Enum.Material.Grass,
			Parent = lobby,
		})
	end
	for _, c in { { -174, 36 }, { -174, -36 }, { -116, 36 }, { -116, -36 } } do
		Scenery.lantern(lobby, Vector3.new(c[1], 0.6, c[2]), 9)
	end
	for _, f in { { -170, -30 }, { -132, -32 }, { -170, 12 }, { -170, -12 } } do
		Scenery.flowers(lobby, Vector3.new(f[1], 0.6, f[2]), 7, rng)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	-- faces +X: straight down the Dragon Road
	spawn.CFrame = CFrame.new(-130, 0.6, 0) * CFrame.Angles(0, math.rad(-90), 0)
	spawn.Color = rgb(240, 190, 50)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	Scenery.brick(spawn)
	spawn.Parent = lobby
	-- the golden dragon statue
	local statueBase = Vector3.new(-150, 0.6, -20)
	Scenery.disc(
		lobby,
		"Pedestal",
		statueBase + Vector3.new(0, 1.5, 0),
		11,
		3,
		rgb(215, 208, 195),
		Enum.Material.Marble
	)
	Scenery.disc(
		lobby,
		"PedestalTrim",
		statueBase + Vector3.new(0, 3.1, 0),
		11.6,
		0.4,
		rgb(255, 200, 60),
		Enum.Material.Foil
	)
	local statue = DragonBuilder.build("GOLDIE", "GOLD", 4, 1.2)
	for _, d in statue:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Sparkles") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	statue.Name = "DragonStatue"
	DragonBuilder.place(statue, CFrame.new(statueBase + Vector3.new(0, 3.3, 0)) * CFrame.Angles(0, math.rad(30), 0))
	statue.Parent = lobby
	-- the three leaderboards in one straight row along the north edge, all facing south into the plaza
	local function boardAt(x)
		local p = Vector3.new(x, 0.6, 29)
		return CFrame.lookAt(p, p - Vector3.zAxis)
	end
	local boards = {
		coins = leaderboard(lobby, boardAt(-164), "TOP COINS", rgb(255, 205, 50)),
		steals = leaderboard(lobby, boardAt(-145), "TOP THIEVES", rgb(255, 90, 90)),
		income = leaderboard(lobby, boardAt(-126), "BEST DRAGONS", rgb(110, 200, 255)),
	}
	-- the FREE dragon stand for new players, just ahead of the spawn
	local freePos = Vector3.new(-121, 1.2, -6)
	local freePad = part({
		Name = "FreePad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 8, 8),
		CFrame = CFrame.new(freePos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(245, 190, 40),
		Parent = lobby,
	})
	billboard(freePad, 14, 3, Vector3.new(0, 8.5, 0), {
		{ text = "FREE DRAGON!", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 70) },
		{ text = "for new players", h = 0.4, y = 0.6 },
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

	-- Practice Base: a small open camp, always unlocked, for the tutorial steal
	local pcf = CFrame.lookAt(Vector3.new(-145, 0, -62), Vector3.new(-145, 0, 0))
	local practice = Instance.new("Model")
	practice.Name = "PracticeBase"
	practice.Parent = map
	part({
		Name = "Floor",
		Size = Vector3.new(24, 0.4, 20),
		CFrame = pcf * CFrame.new(0, 0.2, 0),
		Color = rgb(196, 160, 112),
		Material = Enum.Material.WoodPlanks,
		Parent = practice,
	})
	part({
		Name = "Path",
		Size = Vector3.new(6, 0.3, 10),
		CFrame = CFrame.new(-145, 0.15, -45),
		Color = rgb(205, 198, 185),
		Material = Enum.Material.Cobblestone,
		Parent = practice,
	})
	for _, x in { -12, -4, 4, 12 } do
		part({
			Name = "Fence",
			Size = Vector3.new(0.6, 3, 0.6),
			CFrame = pcf * CFrame.new(x, 1.5, 10),
			Color = rgb(120, 85, 55),
			Material = Enum.Material.Wood,
			Parent = practice,
		})
	end
	part({
		Name = "FenceRail",
		Size = Vector3.new(24, 0.5, 0.4),
		CFrame = pcf * CFrame.new(0, 2.4, 10),
		Color = rgb(140, 100, 65),
		Material = Enum.Material.Wood,
		Parent = practice,
	})
	part({
		Name = "Tent",
		Size = Vector3.new(8, 6, 8),
		CFrame = pcf * CFrame.new(8, 3, 6) * CFrame.Angles(0, math.rad(45), 0),
		Color = rgb(110, 170, 255),
		Material = Enum.Material.Fabric,
		Parent = practice,
	})
	Scenery.cone(
		practice,
		"TentTop",
		(pcf * CFrame.new(8, 6, 6)).Position,
		11,
		4,
		rgb(80, 130, 230),
		3,
		Enum.Material.Fabric
	)
	local practiceNest = part({
		Name = "Nest",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 6.4, 6.4),
		CFrame = pcf * CFrame.new(0, 0.8, 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rgb(150, 105, 65),
		Material = Enum.Material.WoodPlanks,
		Parent = practice,
	})
	billboard(practiceNest, 16, 3.4, Vector3.new(0, 10, 0), {
		{ text = "PRACTICE BASE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(120, 190, 255) },
		{ text = "Steal from Sneaky Sam!", h = 0.4, y = 0.6 },
	})

	-- Scenery: trees, rocks and flowers where there's room, mountains around the edge, clouds above
	for _ = 1, 140 do
		local x, z = rng:NextNumber(-250, 200), rng:NextNumber(-140, 140)
		if clear(x, z) then
			local r = rng:NextNumber()
			if r < 0.45 then
				Scenery.roundTree(deco, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.4), rng)
			elseif r < 0.75 then
				Scenery.pineTree(deco, Vector3.new(x, 0, z), rng:NextNumber(0.9, 1.5))
			elseif r < 0.9 then
				Scenery.rock(deco, Vector3.new(x, 0, z), rng:NextNumber(2, 5), rng)
			else
				Scenery.flowers(deco, Vector3.new(x, 0, z), 6, rng)
			end
		end
	end
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		Scenery.mountain(
			deco,
			Vector3.new(-25 + math.cos(a) * 300, -12, math.sin(a) * 210),
			rng:NextNumber(90, 140),
			rng
		)
	end
	for _ = 1, 9 do
		Scenery.cloud(
			deco,
			Vector3.new(rng:NextNumber(-220, 180), rng:NextNumber(85, 120), rng:NextNumber(-160, 160)),
			rng:NextNumber(0.8, 1.5)
		)
	end
	-- dragons circling in the sky (the client flies them around; see FxController)
	local sky = folder("SkyDragons", workspace)
	for i, spec in { { "BLAZE", 70, 60, 0.05 }, { "CRYSTAL", 110, 75, -0.035 }, { "STORM", 150, 55, 0.03 } } do
		local d = DragonBuilder.build(spec[1], nil, 4, 1.3)
		for _, p in d:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
			end
		end
		d:SetAttribute("Radius", spec[2])
		d:SetAttribute("Height", spec[3])
		d:SetAttribute("Speed", spec[4])
		d:SetAttribute("Phase", i * 2.1)
		DragonBuilder.place(
			d,
			CFrame.new(-20 + math.cos(i * 2.1) * spec[2], spec[3], math.sin(i * 2.1) * spec[2] * 0.7)
		)
		CollectionService:AddTag(d, "SkyDragon")
		d.Parent = sky
	end

	WorldBuilder.layout = {
		bases = bases,
		boards = boards,
		freePad = freePad,
		freeFeet = CFrame.new(-121, 1.8, -6) * CFrame.Angles(0, math.rad(90), 0),
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

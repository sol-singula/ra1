-- Builds the lobby (the arenas are built per round by MapBuilder):
--   the PLAY pad in the middle, the podium to the north, the leaderboards on the west side, the Shop, Crates and
--   Rifles counters on the east, the shooting range in the south-west, the Duel pad in the south-east, the map
--   the Trade Plaza stalls along the south.
-- Also the pop box (where popped players wait out of sight) and the duel arena.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Scenery = require(script.Parent.Scenery)

local part, disc, ball, rgb = Scenery.part, Scenery.disc, Scenery.ball, Scenery.rgb

local WorldBuilder = {}

WorldBuilder.LOBBY_HALF = 80
WorldBuilder.PAD_RADIUS = 5
WorldBuilder.STALLS = 8
WorldBuilder.POP_BOX = Vector3.new(0, 600, -1600)
WorldBuilder.DUEL_CENTER = Vector3.new(1400, 0, 0)
WorldBuilder.DUEL_HALF = 34
WorldBuilder.RANGE = { min = Vector3.new(-78, 0, 18), max = Vector3.new(-30, 0, 78) }

local INK = rgb(30, 30, 44)
local GRASS = rgb(110, 190, 90)
local PATH = rgb(235, 225, 200)
local TRIM = rgb(255, 200, 40)

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function lighting()
	Lighting.ClockTime = 13.5 -- bright midday
	Lighting.Brightness = 3
	Lighting.Ambient = rgb(165, 165, 175)
	Lighting.OutdoorAmbient = rgb(185, 185, 195)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.FogEnd = 3000
	Lighting.FogColor = rgb(205, 230, 255)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("ColorCorrectionEffect") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.18
	atmosphere.Haze = 0.3
	atmosphere.Color = rgb(215, 235, 255)
	atmosphere.Parent = Lighting
	-- a little brighter and more colourful everywhere
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.04
	cc.Contrast = 0.05
	cc.Saturation = 0.18
	cc.Parent = Lighting
end

-- A glowing pad on the floor with a sign (services watch who stands on it).
local function pad(parent, name, center, color, lines, radius)
	radius = radius or WorldBuilder.PAD_RADIUS
	local p = Scenery.ring(parent, name, center + Vector3.new(0, 0.25, 0), radius * 2, color)
	disc(parent, name .. "Base", center + Vector3.new(0, 0.1, 0), radius * 2 + 1.5, 0.2, INK)
	local gui, labels = Scenery.sign(p, 12, 4, Vector3.new(0, 5, 0), lines, 120)
	gui.Size = UDim2.fromOffset(190, 62)
	return p, labels
end

local function prompt(parent, name, action, object, distance)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local WHITE = rgb(255, 255, 255)
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

-- A leaderboard: a big board with a title, a line under it and 10 rows (LeaderboardService fills them).
-- cf is the middle of its base on the floor; the board faces cf's look direction.
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
	gui.CanvasSize = Vector2.new(480, 640)
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
		local y = 108 + (i - 1) * 46
		local bg = Instance.new("Frame")
		bg.Name = "Row" .. i
		bg.Size = UDim2.new(1, -24, 0, 40)
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
	local timer = label(gui, {
		Name = "Timer",
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 572),
		Text = "",
		TextColor3 = rgb(200, 200, 215),
	})
	-- a little stage on top, where the board's #1 dances
	part({
		Name = "Stage",
		Size = Vector3.new(8, 0.8, 5),
		CFrame = cf * CFrame.new(0, 22.9, 0),
		Color = color,
		Parent = parent,
	})
	return { rows = rows, sub = sub, timer = timer, part = board, top = cf * CFrame.new(0, 23.3, 0) }
end

-- A kiosk: a counter with an awning, a big sign, and a prompt. Faces `facing`.
local function kiosk(parent, name, at, facing, color, title, sub, promptName, action)
	local cf = CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z))
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(10, 3, 3),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = color,
		Material = Enum.Material.Plastic,
		Parent = m,
	})
	part({
		Name = "Top",
		Size = Vector3.new(10.4, 0.4, 3.4),
		CFrame = cf * CFrame.new(0, 3.2, 0),
		Color = TRIM,
		Parent = m,
	})
	part({
		Name = "Back",
		Size = Vector3.new(10, 9, 1),
		CFrame = cf * CFrame.new(0, 4.5, 3),
		Color = color:Lerp(INK, 0.25),
		Material = Enum.Material.Plastic,
		Parent = m,
	})
	for _, px in { -4.8, 4.8 } do
		part({
			Name = "Pole",
			Size = Vector3.new(0.5, 8, 0.5),
			CFrame = cf * CFrame.new(px, 4, -1.2),
			Color = INK,
			Parent = m,
		})
	end
	part({
		Name = "Awning",
		Size = Vector3.new(11, 0.5, 4.5),
		CFrame = cf * CFrame.new(0, 8.2, 0.5) * CFrame.Angles(math.rad(-10), 0, 0),
		Color = color:Lerp(rgb(255, 255, 255), 0.3),
		Parent = m,
	})
	local _, lines = Scenery.sign(counter, 14, 4.5, Vector3.new(0, 9.5, 0), {
		{ text = title, h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = color:Lerp(rgb(255, 255, 255), 0.35) },
		{ text = sub, h = 0.4, y = 0.6 },
	}, 140)
	local p = prompt(counter, promptName, action, title, 12)
	return { model = m, counter = counter, lines = lines, prompt = p, cf = cf }
end

-- The lobby is a closed courtyard: tall brick walls with a walkway trim, battlements, lit pillars, banners,
-- a big corner tower at each corner and trees peeking over from outside. Nobody can leave it.
local WALL = rgb(205, 120, 90)
local STONE = rgb(225, 220, 210)
local BANNERS = { rgb(255, 80, 80), rgb(40, 160, 230), rgb(255, 200, 40), rgb(90, 200, 110) }
local WALL_H = 30

local function walls(model, H)
	local R = H + 4 -- wall middle
	local len = R * 2
	for _, s in { -1, 1 } do
		for _, axis in { "x", "z" } do
			local function at(along, y, out)
				out = out or 0
				if axis == "x" then
					return Vector3.new(along, y, s * (R + out))
				end
				return Vector3.new(s * (R + out), y, along)
			end
			local function size(alongLen, h, thick)
				if axis == "x" then
					return Vector3.new(alongLen, h, thick)
				end
				return Vector3.new(thick, h, alongLen)
			end
			part({
				Name = "Wall",
				Size = size(len + 4, WALL_H, 4),
				CFrame = CFrame.new(at(0, WALL_H / 2)),
				Color = WALL,
				Material = Enum.Material.Brick,
				Parent = model,
			})
			-- stone base and top trim on the inside
			part({
				Name = "WallBase",
				Size = size(len, 3, 1.2),
				CFrame = CFrame.new(at(0, 1.5, -2.4)),
				Color = STONE,
				Material = Enum.Material.Slate,
				Parent = model,
			})
			part({
				Name = "WallTrim",
				Size = size(len + 6, 1.5, 6),
				CFrame = CFrame.new(at(0, WALL_H + 0.75)),
				Color = STONE,
				Material = Enum.Material.Slate,
				Parent = model,
			})
			-- battlements
			for i = -R + 3, R - 3, 6 do
				part({
					Name = "Battlement",
					Size = size(3, 3, 5),
					CFrame = CFrame.new(at(i, WALL_H + 3)),
					Color = STONE,
					Material = Enum.Material.Slate,
					Parent = model,
				})
			end
			-- pillars with lamps, and banners between them
			for i = -R + 20, R - 20, 24 do
				part({
					Name = "Pillar",
					Size = size(4, WALL_H + 2, 2.5),
					CFrame = CFrame.new(at(i, (WALL_H + 2) / 2, -3)),
					Color = STONE,
					Material = Enum.Material.Slate,
					Parent = model,
				})
				local lamp = part({
					Name = "Lamp",
					Size = size(2.2, 2.2, 1.6),
					CFrame = CFrame.new(at(i, 18, -4.6)),
					Color = rgb(255, 230, 160),
					Material = Enum.Material.Neon,
					CanCollide = false,
					Parent = model,
				})
				local light = Instance.new("PointLight")
				light.Range = 18
				light.Brightness = 1.2
				light.Color = rgb(255, 220, 150)
				light.Parent = lamp
				local mid = i + 12
				if mid < R - 12 then
					local color = BANNERS[(math.floor((mid + R) / 24) % #BANNERS) + 1]
					part({
						Name = "Banner",
						Size = size(6, 14, 0.3),
						CFrame = CFrame.new(at(mid, WALL_H - 9, -2.2)),
						Color = color,
						CanCollide = false,
						Parent = model,
					})
					part({
						Name = "BannerStripe",
						Size = size(6.2, 1.2, 0.4),
						CFrame = CFrame.new(at(mid, WALL_H - 13, -2.25)),
						Color = TRIM,
						CanCollide = false,
						Parent = model,
					})
					part({
						Name = "BannerRod",
						Size = size(7.5, 0.6, 0.6),
						CFrame = CFrame.new(at(mid, WALL_H - 1.8, -2.4)),
						Color = INK,
						Material = Enum.Material.Metal,
						CanCollide = false,
						Parent = model,
					})
				end
			end
		end
	end
	-- corner towers with pointed roofs and flags
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local c = Vector3.new(sx * R, 0, sz * R)
			disc(model, "Tower", c + Vector3.new(0, (WALL_H + 10) / 2, 0), 16, WALL_H + 10, WALL, Enum.Material.Brick)
			disc(model, "TowerTop", c + Vector3.new(0, WALL_H + 10.75, 0), 18, 1.5, STONE, Enum.Material.Slate)
			for k = 1, 8 do
				local a = k / 8 * math.pi * 2
				part({
					Name = "Battlement",
					Size = Vector3.new(3, 3, 3),
					CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 7.8, WALL_H + 13, math.sin(a) * 7.8)),
					Color = STONE,
					Material = Enum.Material.Slate,
					Parent = model,
				})
			end
			for k = 0, 5 do -- a stepped roof
				disc(
					model,
					"Roof",
					c + Vector3.new(0, WALL_H + 13 + k * 2.2, 0),
					14 - k * 2.3,
					2.2,
					rgb(70, 90, 170),
					Enum.Material.Plastic
				)
			end
			part({
				Name = "FlagPole",
				Size = Vector3.new(0.5, 8, 0.5),
				CFrame = CFrame.new(c + Vector3.new(0, WALL_H + 30, 0)),
				Color = INK,
				Material = Enum.Material.Metal,
				Parent = model,
			})
			part({
				Name = "Flag",
				Size = Vector3.new(4.5, 2.8, 0.2),
				CFrame = CFrame.new(c + Vector3.new(2.4, WALL_H + 32.5, 0)),
				Color = BANNERS[(sx + 1) + (sz + 1) / 2 + 1],
				CanCollide = false,
				Parent = model,
			})
			local lamp = part({
				Name = "Lamp",
				Size = Vector3.new(2, 2, 2),
				CFrame = CFrame.new(c + Vector3.new(-sx * 6.5, 18, -sz * 6.5)),
				Color = rgb(255, 230, 160),
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = model,
			})
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 1.2
			light.Color = rgb(255, 220, 150)
			light.Parent = lamp
		end
	end
	-- an invisible lid so nobody can jump the walls
	part({
		Name = "Lid",
		Size = Vector3.new(len + 8, 1, len + 8),
		CFrame = CFrame.new(0, 80, 0),
		Transparency = 1,
		CanQuery = false,
		Parent = model,
	})
	-- tall trees outside, peeking over the walls
	local rng = Random.new(4)
	for i = 1, 32 do
		local a = i / 32 * math.pi * 2
		local r = R + 14 + rng:NextNumber(0, 14)
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local h = rng:NextInteger(24, 34)
		part({
			Name = "Trunk",
			Size = Vector3.new(2.4, h, 2.4),
			CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)),
			Color = rgb(120, 80, 50),
			Material = Enum.Material.Wood,
			Parent = model,
		})
		ball(
			model,
			"Leaves",
			p + Vector3.new(0, h + 4, 0),
			rng:NextInteger(14, 19),
			rgb(70, 170, 70),
			Enum.Material.Plastic
		)
	end
end

local function lobby(map)
	local model = Instance.new("Model")
	model.Name = "Lobby"
	model.Parent = map
	local H = WorldBuilder.LOBBY_HALF
	part({
		Name = "Floor",
		Size = Vector3.new(H * 2 + 8, 2, H * 2 + 8),
		CFrame = CFrame.new(0, -1, 0),
		Color = GRASS,
		Material = Enum.Material.Plastic,
		Parent = model,
	})
	part({
		Name = "Ground",
		Size = Vector3.new(H * 2 + 200, 1, H * 2 + 200),
		CFrame = CFrame.new(0, -2.5, 0),
		Color = GRASS:Lerp(INK, 0.12),
		Material = Enum.Material.Plastic,
		Parent = model,
	})
	-- paths: a cross and a ring around the PLAY pad
	for _, s in { Vector3.new(H * 2, 0.2, 12), Vector3.new(12, 0.2, H * 2) } do
		part({
			Name = "Path",
			Size = s,
			CFrame = CFrame.new(0, 0.1, 0),
			Color = PATH,
			CanCollide = false,
			Parent = model,
		})
	end
	disc(model, "Plaza", Vector3.new(0, 0.15, 0), 40, 0.3, PATH, Enum.Material.Plastic, { CanCollide = false })
	walls(model, H)
	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, 0.2, 34)
	spawn.Color = PATH:Lerp(TRIM, 0.4)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	-- the PLAY pad and the status sign over it
	local playPad, playLabels = pad(model, "PlayPad", Vector3.new(0, 0, 4), rgb(255, 140, 30), {
		{ text = "▶ PLAY", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 170, 60) },
		{ text = "Jump into the round", h = 0.4, y = 0.6 },
	}, 7)
	local statusPost = part({
		Name = "StatusPost",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 30, 4),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local statusGui, statusLines = Scenery.sign(statusPost, 30, 6, Vector3.new(0, 0, 0), {
		{ text = "WAITING FOR PLAYERS", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = TRIM },
		{ text = "A round starts with 2 players", h = 0.4, y = 0.6 },
	}, 220)
	statusGui.Name = "Status"

	-- the podium (north), with the title over it
	local podium = Instance.new("Model")
	podium.Name = "Podium"
	podium.Parent = model
	local spots = {}
	local podiumSpec =
		{ { 0, 6, rgb(255, 205, 60), "1" }, { -8, 4, rgb(210, 215, 230), "2" }, { 8, 2.5, rgb(225, 150, 90), "3" } }
	for i, spec in podiumSpec do
		local p = part({
			Name = "Step" .. i,
			Size = Vector3.new(7, spec[2], 7),
			CFrame = CFrame.new(spec[1], spec[2] / 2, -52),
			Color = spec[3],
			Material = Enum.Material.Plastic,
			Parent = podium,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.CanvasSize = Vector2.new(200, 200)
		gui.LightInfluence = 0
		gui.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = spec[4]
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextColor3 = rgb(255, 255, 255)
		t.TextStrokeTransparency = 0
		t.Parent = gui
		spots[i] = Vector3.new(spec[1], spec[2], -52)
	end
	local podiumNames = {}
	for i, spot in spots do
		local post = part({
			Name = "NamePost" .. i,
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(spot + Vector3.new(0, 7.5, 0)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = podium,
		})
		local _, l = Scenery.sign(post, 10, 3, Vector3.new(0, 0, 0), {
			{ text = "", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = podiumSpec[i][3] },
			{ text = "", h = 0.4, y = 0.6 },
		}, 160)
		podiumNames[i] = l
	end
	part({
		Name = "Backdrop",
		Size = Vector3.new(44, 18, 2),
		CFrame = CFrame.new(0, 9, -60),
		Color = rgb(60, 70, 120),
		Material = Enum.Material.Plastic,
		Parent = podium,
	})
	part({
		Name = "BackdropTrim",
		Size = Vector3.new(46, 1.4, 2.4),
		CFrame = CFrame.new(0, 18.5, -60),
		Color = TRIM,
		Parent = podium,
	})
	local titlePost = part({
		Name = "TitlePost",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 26, -60),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = podium,
	})
	Scenery.sign(titlePost, 44, 9, Vector3.new(0, 0, 0), {
		{ text = "🎯 SNIPE A NOOB", h = 0.65, y = 0, font = Enum.Font.LuckiestGuy, color = TRIM },
		{ text = "One shot. One pop. Most pops in 5 minutes wins!", h = 0.35, y = 0.65 },
	}, 300)

	-- leaderboards down the west side, facing the plaza
	local boards = {}
	local boardSpec = {
		{ "daily", "TODAY'S TOP SNIPERS", rgb(255, 120, 200), -62 },
		{ "pops", "MOST POPS", rgb(255, 205, 60), -40 },
		{ "streak", "BEST STREAK", rgb(255, 140, 30), -18 },
		{ "level", "HIGHEST LEVEL", rgb(120, 200, 255), 4 },
	}
	for _, spec in boardSpec do
		local at = Vector3.new(-72, 0.6, spec[4])
		boards[spec[1]] = leaderboard(model, CFrame.lookAt(at, at + Vector3.xAxis), spec[2], spec[3])
	end

	-- the counters on the east side, facing the plaza
	local kiosks = {
		shop = kiosk(
			model,
			"ShopKiosk",
			Vector3.new(68, 0, -44),
			Vector3.new(0, 0, -44),
			rgb(255, 95, 170),
			"🛒 DAILY SHOP",
			"New every day at 7pm ET",
			"Prompt_shop",
			"Open the Shop"
		),
		crates = kiosk(
			model,
			"CrateKiosk",
			Vector3.new(68, 0, -22),
			Vector3.new(0, 0, -22),
			rgb(150, 90, 240),
			"🎁 CRATES",
			"Skins inside! Odds shown",
			"Prompt_crates",
			"Open Crates"
		),
		rifles = kiosk(
			model,
			"RifleKiosk",
			Vector3.new(68, 0, 0),
			Vector3.new(0, 0, 0),
			rgb(60, 160, 255),
			"🔫 RIFLES",
			"New ways to play",
			"Prompt_rifles",
			"Open Rifles"
		),
		style = kiosk(
			model,
			"StyleKiosk",
			Vector3.new(68, 0, 22),
			Vector3.new(0, 0, 22),
			rgb(30, 200, 185),
			"✨ STYLE",
			"Crosshairs, colours, pops",
			"Prompt_style",
			"Open Style"
		),
		season = kiosk(
			model,
			"SeasonKiosk",
			Vector3.new(68, 0, 44),
			Vector3.new(0, 0, 44),
			rgb(255, 170, 40),
			"🏅 SEASON",
			"Earn tiers, get skins",
			"Prompt_season",
			"Open the Season"
		),
	}
	-- a crate on the crate counter, a rifle on the rifle counter
	local crateShow = part({
		Name = "CrateShow",
		Size = Vector3.new(2.6, 2.6, 2.6),
		CFrame = kiosks.crates.cf * CFrame.new(0, 4.8, 0),
		Color = rgb(150, 90, 240),
		Material = Enum.Material.Plastic,
		CanCollide = false,
		Parent = kiosks.crates.model,
	})
	crateShow:SetAttribute("TurnSpeed", 0.8)
	CollectionService:AddTag(crateShow, "Turn")

	-- the shooting range (south-west): a firing line and a field with targets
	local R = WorldBuilder.RANGE
	local rc = (R.min + R.max) / 2
	local rs = R.max - R.min
	part({
		Name = "RangeFloor",
		Size = Vector3.new(rs.X, 0.3, rs.Z),
		CFrame = CFrame.new(rc.X, 0.15, rc.Z),
		Color = rgb(200, 180, 140),
		Material = Enum.Material.Plastic,
		CanCollide = false,
		Parent = model,
	})
	for _, x in { R.min.X, R.max.X } do
		part({
			Name = "RangeWall",
			Size = Vector3.new(1.5, 6, rs.Z),
			CFrame = CFrame.new(x, 3, rc.Z),
			Color = rgb(150, 110, 70),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	part({
		Name = "RangeBack",
		Size = Vector3.new(rs.X, 14, 1.5),
		CFrame = CFrame.new(rc.X, 7, R.max.Z),
		Color = rgb(150, 110, 70),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Name = "FiringLine",
		Size = Vector3.new(rs.X, 1.2, 1),
		CFrame = CFrame.new(rc.X, 0.6, R.min.Z + 12),
		Color = TRIM,
		Parent = model,
	})
	local rangePost = part({
		Name = "RangeSign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(rc.X, 10, R.min.Z + 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	Scenery.sign(rangePost, 16, 4.5, Vector3.new(0, 0, 0), {
		{ text = "🎯 RANGE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 120, 80) },
		{ text = "Practice here any time", h = 0.4, y = 0.6 },
	}, 140)
	local rangeTargets = {}
	for i = 1, 6 do
		local x = R.min.X + 6 + (i - 1) * ((rs.X - 12) / 5)
		local z = R.min.Z + 30 + (i % 3) * 13
		rangeTargets[i] = Vector3.new(x, 0, z)
	end

	-- the Duel pad (south-east)
	local duelPad, duelLabels = pad(model, "DuelPad", Vector3.new(62, 0, 64), rgb(255, 65, 75), {
		{ text = "⚔️ DUEL", h = 0.55, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 120, 120) },
		{ text = "2 players: first to 5", h = 0.45, y = 0.55 },
	}, 6)

	-- the Trade Plaza: stalls along the south
	local stalls = {}
	local tradePost = part({
		Name = "TradeSign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(10, 12, 70),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	Scenery.sign(tradePost, 20, 4.5, Vector3.new(0, 0, 0), {
		{ text = "🏪 TRADE PLAZA", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(120, 220, 255) },
		{ text = "Sell skins for coins", h = 0.4, y = 0.6 },
	}, 160)
	for i = 1, WorldBuilder.STALLS do
		local center = Vector3.new(-24 + (i - 1) * 9.5, 0, 74)
		local cf = CFrame.lookAt(center, center - Vector3.zAxis)
		local stand = Instance.new("Model")
		stand.Name = "Stall" .. i
		stand.Parent = model
		local counter = part({
			Name = "Counter",
			Size = Vector3.new(7, 2.6, 2.5),
			CFrame = cf * CFrame.new(0, 1.3, 0),
			Color = rgb(90, 140, 200),
			Parent = stand,
		})
		part({
			Name = "Top",
			Size = Vector3.new(7.4, 0.4, 2.9),
			CFrame = cf * CFrame.new(0, 2.8, 0),
			Color = TRIM,
			Parent = stand,
		})
		for _, px in { -3.2, 3.2 } do
			part({
				Name = "Pole",
				Size = Vector3.new(0.4, 6, 0.4),
				CFrame = cf * CFrame.new(px, 3, 1),
				Color = INK,
				Parent = stand,
			})
		end
		part({
			Name = "Awning",
			Size = Vector3.new(7.6, 0.4, 3.4),
			CFrame = cf * CFrame.new(0, 6.2, 0.6) * CFrame.Angles(math.rad(12), 0, 0),
			Color = rgb(120, 200, 255),
			Parent = stand,
		})
		local show = part({
			Name = "Show",
			Size = Vector3.new(1, 1, 1),
			CFrame = cf * CFrame.new(0, 3.8, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = stand,
		})
		local _, lines = Scenery.sign(show, 9, 4, Vector3.new(0, 2.6, 0), {
			{ text = "EMPTY STALL", h = 0.4, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(220, 220, 230) },
			{ text = "Put a skin here", h = 0.3, y = 0.4 },
			{ text = "", h = 0.3, y = 0.7, color = rgb(150, 230, 255) },
		}, 70)
		local p = prompt(counter, "Prompt_stall", "Use stall", stand.Name, 9)
		stalls[i] = { index = i, model = stand, cf = cf, show = show, lines = lines, prompt = p }
	end

	return {
		model = model,
		spawn = spawn,
		playPad = { part = playPad, labels = playLabels, center = Vector3.new(0, 0, 4), radius = 7 },
		status = statusLines,
		podium = { spots = spots, names = podiumNames, camera = Vector3.new(0, 11, -26), look = Vector3.new(0, 6, -52) },
		boards = boards,
		kiosks = kiosks,
		range = { min = R.min, max = R.max, targets = rangeTargets, spawn = Vector3.new(rc.X, 0, R.min.Z + 6) },
		duelPad = { part = duelPad, labels = duelLabels, center = Vector3.new(62, 0, 64), radius = 6 },
		stalls = stalls,
	}
end

-- The pop box: a closed room far away where popped players wait (anchored) until they respawn.
local function popBox(map)
	local m = Instance.new("Model")
	m.Name = "PopBox"
	m.Parent = map
	local c = WorldBuilder.POP_BOX
	part({
		Name = "Floor",
		Size = Vector3.new(40, 2, 40),
		CFrame = CFrame.new(c + Vector3.new(0, -6, 0)),
		Color = INK,
		Parent = m,
	})
	return m
end

function WorldBuilder.build()
	lighting()
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or (child:IsA("SpawnLocation") and child.Name == "SpawnLocation") then
			child:Destroy()
		end
	end
	local map = folder("Map", workspace)
	local l = lobby(map)
	popBox(map)
	folder("Arena", workspace)
	folder("Robots", workspace)
	folder("Fx", workspace)
	l.maps = Maps.list
	WorldBuilder.layout = l
	return l
end

function WorldBuilder.inLobby(pos)
	local H = WorldBuilder.LOBBY_HALF + 4
	return math.abs(pos.X) <= H and math.abs(pos.Z) <= H and pos.Y > -20 and pos.Y < 80
end

function WorldBuilder.inRange(pos)
	local R = WorldBuilder.RANGE
	return pos.X >= R.min.X and pos.X <= R.max.X and pos.Z >= R.min.Z and pos.Z <= R.max.Z and pos.Y < 40
end

-- Is a position on a pad (flat distance)?
function WorldBuilder.onPad(padInfo, pos)
	local d = Vector3.new(pos.X - padInfo.center.X, 0, pos.Z - padInfo.center.Z).Magnitude
	return d <= padInfo.radius and math.abs(pos.Y - padInfo.center.Y) < 8
end

return WorldBuilder

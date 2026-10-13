-- Builds the whole map from primitive parts: the lobby with the leaderboards, the Dragon Road, 8 player
-- bases and the Practice Base. Returns a layout table the services use.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local DragonBuilder = require(script.Parent.DragonBuilder)
local Disco = require(script.Parent.Disco)
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

local BASE_W, BASE_D = 46, 60 -- width (x) and depth (z)
-- The lobby courtyard's floor (its walls stand just outside) and the FREE dragon stand inside it.
WorldBuilder.LOBBY = { x0 = -204, x1 = -114.5, z0 = -46, z1 = 46 }
WorldBuilder.FREE_PAD = Vector3.new(-120, 1.2, -9) -- right in front of the spawn, beside the path
local BASE_XS = { -87, -29, 29, 87 } -- base centres along the road; 4 on each side, with room between them
local BASE_Z = 62 -- distance of each base centre from the road (leaves room for a front lawn)
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
	-- The castle grows with its owner's dragon power (BaseService picks the level, WorldBuilder.setCastleLevel
	-- shows it): level 1 is a plain low wall; each higher level's pieces live in their own model.
	local levels = {}
	for level = 2, #Constants.CASTLE_LEVEL_POWER do
		local m = Instance.new("Model")
		m.Name = "CastleLevel" .. level
		m.Parent = model
		levels[level] = m
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
	local tw, td = BASE_W / 5, BASE_D / 6
	for ix = 0, 4 do
		for iz = 0, 5 do
			if (ix + iz) % 2 == 0 then
				part({
					Name = "Tile",
					Size = Vector3.new(tw, 0.05, td),
					CFrame = at(-BASE_W / 2 + tw * (ix + 0.5), 0.42, -BASE_D / 2 + td * (iz + 0.5)),
					Color = soft,
					CastShadow = false,
					CanCollide = false,
					Parent = model,
				})
			end
		end
	end
	-- Stone walls: a low wall at level 1; from level 2 they rise to full height with a coloured band and
	-- battlements. The front has a 16-stud gate. Every wall has a dark plinth, a capping course and a scatter
	-- of lighter and darker stones on its outer face; from level 3 the long walls get buttresses and ivy.
	local detailRng = Random.new(index * 13)
	local IVY = rgb(70, 140, 70)
	local function wall(name, size, cframe, out)
		local low = part({
			Name = name,
			Size = Vector3.new(size.X, 5, size.Z),
			CFrame = cframe * CFrame.new(0, -2, 0),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
		part({
			Name = name .. "Upper",
			Size = Vector3.new(size.X, size.Y - 5, size.Z),
			CFrame = cframe * CFrame.new(0, 2.5, 0),
			Color = STONE,
			Material = Enum.Material.Cobblestone,
			Parent = levels[2],
		})
		part({
			Name = "Band",
			Size = Vector3.new(size.X + 0.1, 1.2, size.Z + 0.1),
			CFrame = cframe * CFrame.new(0, size.Y / 2 - 1.6, 0),
			Color = color,
			CastShadow = false,
			Parent = levels[2],
		})
		part({
			Name = "GoldTrim",
			Size = Vector3.new(size.X + 0.25, 0.5, size.Z + 0.25),
			CFrame = cframe * CFrame.new(0, size.Y / 2 - 0.7, 0),
			Color = rgb(255, 200, 60),
			Material = Enum.Material.Foil,
			CastShadow = false,
			Parent = levels[5],
		})
		local long = size.X > size.Z and "X" or "Z"
		local len = long == "X" and size.X or size.Z
		local thick = long == "X" and size.Z or size.X
		-- a piece on the outer face: `along` the wall, at height y (from the wall's centre), `depth` out from it
		local function onFace(pieceName, along, y, w, h, depth, pieceColor, parentModel, extra)
			local props = {
				Name = pieceName,
				Size = long == "X" and Vector3.new(w, h, depth) or Vector3.new(depth, h, w),
				CFrame = cframe * CFrame.new(
					(long == "X" and Vector3.new(along, y, 0) or Vector3.new(0, y, along))
						+ out * (thick / 2 + depth / 2 - 0.02)
				),
				Color = pieceColor,
				Material = Enum.Material.Cobblestone,
				CastShadow = false,
				Parent = parentModel,
			}
			for k, v in extra or {} do
				props[k] = v
			end
			return part(props)
		end
		local bottom = -size.Y / 2
		onFace("Plinth", 0, bottom + 0.6, len, 1.2, 0.35, STONE_DARK, model)
		part({
			Name = "Coping",
			Size = long == "X" and Vector3.new(len, 0.5, thick + 0.5) or Vector3.new(thick + 0.5, 0.5, len),
			CFrame = cframe * CFrame.new(0, 0.6, 0),
			Color = rgb(206, 198, 186),
			Material = Enum.Material.Cobblestone,
			CastShadow = false,
			Parent = model,
		})
		for i = 1, math.floor(len / 5) do
			local shade = STONE:Lerp(detailRng:NextNumber() < 0.5 and STONE_DARK or rgb(225, 218, 206), 0.6)
			local along = detailRng:NextNumber(-len / 2 + 1.5, len / 2 - 1.5)
			onFace("Stone", along, detailRng:NextNumber(bottom + 1.8, -0.2), 2.2, 1, 0.12, shade, model)
			if i % 2 == 0 then
				local upper = detailRng:NextNumber(-len / 2 + 1.5, len / 2 - 1.5)
				onFace("Stone", upper, detailRng:NextNumber(1.4, size.Y / 2 - 2.6), 2.2, 1, 0.12, shade, levels[2])
			end
		end
		if len >= 20 then
			for along = -len / 2 + 6, len / 2 - 5, 12 do
				onFace("Buttress", along, bottom + 3.5, 1.8, 7, 1.4, STONE_DARK, levels[3], { CastShadow = true })
				onFace("Buttress", along, bottom + 7.8, 1.8, 1.6, 0.8, STONE_DARK, levels[3])
			end
			for _ = 1, 2 do
				local along = detailRng:NextNumber(-len / 2 + 3, len / 2 - 3)
				local h = detailRng:NextNumber(3, 6)
				onFace("Ivy", along, bottom + h / 2 + 0.4, detailRng:NextNumber(2.4, 4), h, 0.15, IVY, levels[3], {
					Material = Enum.Material.Grass,
				})
				onFace(
					"Ivy",
					along + 0.8,
					bottom + h + 0.6,
					1.4,
					1.2,
					0.2,
					IVY:Lerp(rgb(120, 190, 90), 0.4),
					levels[3],
					{
						Material = Enum.Material.Grass,
					}
				)
			end
		end
		-- battlements along the top
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
					Parent = levels[2],
				})
			end
		end
		return low
	end
	wall("WallBack", Vector3.new(BASE_W, 9, 1.4), at(0, 4.9, BASE_D / 2), Vector3.zAxis)
	wall("WallL", Vector3.new(1.4, 9, BASE_D), at(-BASE_W / 2, 4.9, 0), -Vector3.xAxis)
	wall("WallR", Vector3.new(1.4, 9, BASE_D), at(BASE_W / 2, 4.9, 0), Vector3.xAxis)
	local sideW = BASE_W / 2 - 8 -- the gate is 16 wide
	wall("WallFL", Vector3.new(sideW, 9, 1.4), at(-8 - sideW / 2, 4.9, -BASE_D / 2), -Vector3.zAxis)
	wall("WallFR", Vector3.new(sideW, 9, 1.4), at(8 + sideW / 2, 4.9, -BASE_D / 2), -Vector3.zAxis)
	-- square corner posts (the back ones end up inside the level 2 towers; the front ones get turrets at level 4)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		part({
			Name = "CornerPost",
			Size = Vector3.new(2.4, 6.6, 2.4),
			CFrame = at(c[1] * BASE_W / 2, 3.3, c[2] * BASE_D / 2),
			Color = STONE_DARK,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
		part({
			Name = "CornerCap",
			Size = Vector3.new(3, 0.6, 3),
			CFrame = at(c[1] * BASE_W / 2, 6.9, c[2] * BASE_D / 2),
			Color = rgb(206, 198, 186),
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
	end
	for _, side in { -1, 1 } do
		Scenery.tower(levels[4], pos(side * BASE_W / 2, 0, -BASE_D / 2), 4, 12, STONE, color, color)
	end
	-- gate posts hold up the gate arch (and its name sign) at every level
	for _, side in { -1, 1 } do
		part({
			Name = "GatePost",
			Size = Vector3.new(1.6, 10.4, 1.6),
			CFrame = at(side * 8.6, 5.6, -BASE_D / 2),
			Color = STONE_DARK,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
	end
	-- towers: two at the back corners (level 2), two guarding the gate (level 3)
	Scenery.tower(levels[2], pos(-BASE_W / 2, 0, BASE_D / 2), 6, 13, STONE, color, color)
	Scenery.tower(levels[2], pos(BASE_W / 2, 0, BASE_D / 2), 6, 13, STONE, color, color)
	Scenery.tower(levels[3], pos(-9.5, 0, -BASE_D / 2), 4.4, 12, STONE, color, color)
	Scenery.tower(levels[3], pos(9.5, 0, -BASE_D / 2), 4.4, 12, STONE, color, color)
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
	-- Front lawn between the sidewalk and the gate: green studs, a stone path to the gate, flower beds and two
	-- round bushes (no lamps: the road has enough)
	local rng = Random.new(index * 7)
	local lawnD = BASE_Z - BASE_D / 2 - 1.5 - 19 -- from the sidewalk's edge to the castle's rim
	local lawnZ = -BASE_D / 2 - 1.5 - lawnD / 2
	part({
		Name = "Lawn",
		Size = Vector3.new(BASE_W + 6, 0.2, lawnD),
		CFrame = at(0, 0.1, lawnZ),
		Color = rgb(96, 176, 82),
		Parent = model,
	})
	part({
		Name = "Path",
		Size = Vector3.new(10, 0.3, lawnD + 1),
		CFrame = at(0, 0.15, lawnZ),
		Color = rgb(172, 165, 155),
		Material = Enum.Material.Cobblestone,
		Parent = model,
	})
	part({
		Name = "Mat",
		Size = Vector3.new(12, 0.1, 4),
		CFrame = at(0, 0.32, -BASE_D / 2 - 3),
		Color = color:Lerp(rgb(160, 150, 140), 0.35),
		CastShadow = false,
		CanCollide = false,
		Parent = model,
	})
	for _, side in { -1, 1 } do
		-- a flower bed edged in the base colour, and a round bush at the outer corner
		part({
			Name = "FlowerBed",
			Size = Vector3.new(10, 0.5, 5),
			CFrame = at(side * 12, 0.25, lawnZ),
			Color = rgb(110, 80, 55),
			Parent = model,
		})
		part({
			Name = "BedTrim",
			Size = Vector3.new(10.6, 0.3, 5.6),
			CFrame = at(side * 12, 0.15, lawnZ),
			Color = color,
			Parent = model,
		})
		Scenery.flowers(model, pos(side * 12, 0.3, lawnZ), 8, rng)
		Scenery.bush(model, pos(side * (BASE_W / 2 + 0.5), 0.1, lawnZ), 1.25, rng, color)
		Scenery.bush(model, pos(side * (BASE_W / 2 - 2.6), 0.1, lawnZ + 2.4), 0.8, rng)
	end
	-- Castle details by level: arrow slits, front-wall banners and a portcullis (3), a tall keep behind the back
	-- wall (4), and a golden dragon over the gate (5)
	local slit = rgb(45, 40, 50)
	for z = -BASE_D / 2 + 6, BASE_D / 2 - 6, 8 do
		for _, side in { -1, 1 } do
			part({
				Name = "ArrowSlit",
				Size = Vector3.new(0.2, 2.2, 0.6),
				CFrame = at(side * (BASE_W / 2 + 0.72), 6.6, z),
				Color = slit,
				CastShadow = false,
				CanCollide = false,
				Parent = levels[3],
			})
		end
	end
	for x = -BASE_W / 2 + 7, BASE_W / 2 - 7, 8 do
		part({
			Name = "ArrowSlit",
			Size = Vector3.new(0.6, 2.2, 0.2),
			CFrame = at(x, 6.6, BASE_D / 2 + 0.72),
			Color = slit,
			CastShadow = false,
			CanCollide = false,
			Parent = levels[3],
		})
	end
	for _, side in { -1, 1 } do
		local bx = side * (8 + sideW / 2)
		part({
			Name = "WallBanner",
			Size = Vector3.new(3.4, 5, 0.2),
			CFrame = at(bx, 5.2, -BASE_D / 2 - 0.82),
			Color = color,
			CastShadow = false,
			CanCollide = false,
			Parent = levels[3],
		})
		part({
			Name = "WallBannerTrim",
			Size = Vector3.new(3.8, 0.5, 0.25),
			CFrame = at(bx, 7.8, -BASE_D / 2 - 0.85),
			Color = rgb(240, 185, 55),
			CastShadow = false,
			CanCollide = false,
			Parent = levels[3],
		})
	end
	for x = -6, 6, 2 do
		part({
			Name = "Portcullis",
			Size = Vector3.new(0.3, 1.6, 0.3),
			CFrame = at(x, 9.6, -BASE_D / 2),
			Color = rgb(60, 55, 65),
			CanCollide = false,
			Parent = levels[3],
		})
	end
	Scenery.tower(levels[4], pos(0, 0, BASE_D / 2 + 7), 10, 20, STONE, color, color)
	local golden = DragonBuilder.build("GOLDIE", "GOLD", 3, 0.9)
	for _, d in golden:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	golden.Name = "GoldenDragon"
	DragonBuilder.place(golden, at(0, 12.4, -BASE_D / 2) * CFrame.Angles(0, math.pi, 0))
	golden.Parent = levels[5]
	-- Level 6: the back towers rise into tall spires, and a great arch with banners stands over the gate
	for _, side in { -1, 1 } do
		Scenery.tower(levels[6], pos(side * BASE_W / 2, 0, BASE_D / 2), 5, 22, STONE, color, rgb(255, 205, 60))
	end
	part({
		Name = "GreatArch",
		Size = Vector3.new(26, 3, 3),
		CFrame = at(0, 15.5, -BASE_D / 2),
		Color = STONE_DARK,
		Material = Enum.Material.Cobblestone,
		Parent = levels[6],
	})
	for _, side in { -1, 1 } do
		part({
			Name = "ArchPillar",
			Size = Vector3.new(3, 15, 3),
			CFrame = at(side * 13, 7.5, -BASE_D / 2 - 0.5),
			Color = STONE_DARK,
			Material = Enum.Material.Cobblestone,
			Parent = levels[6],
		})
		part({
			Name = "GateBannerTall",
			Size = Vector3.new(3.4, 8, 0.2),
			CFrame = at(side * 13, 9, -BASE_D / 2 - 2.1),
			Color = color,
			Material = Enum.Material.Fabric,
			CastShadow = false,
			CanCollide = false,
			Parent = levels[6],
		})
	end
	-- Level 7: a grand hall behind the castle with twin spires and a glowing crystal crown
	part({
		Name = "GrandHall",
		Size = Vector3.new(30, 18, 10),
		CFrame = at(0, 9, BASE_D / 2 + 6),
		Color = STONE,
		Material = Enum.Material.Cobblestone,
		Parent = levels[7],
	})
	part({
		Name = "GrandHallRoof",
		Size = Vector3.new(32, 1.6, 12),
		CFrame = at(0, 18.8, BASE_D / 2 + 6),
		Color = color,
		Parent = levels[7],
	})
	for _, side in { -1, 1 } do
		Scenery.tower(levels[7], pos(side * 12, 0, BASE_D / 2 + 9), 6, 30, STONE, color, rgb(255, 205, 60))
	end
	for i = -3, 3 do
		part({
			Name = "HallWindow",
			Size = Vector3.new(1.6, 4, 0.2),
			CFrame = at(i * 4, 10, BASE_D / 2 + 0.95),
			Color = rgb(255, 200, 110),
			Material = Enum.Material.Neon,
			CastShadow = false,
			Parent = levels[7],
		})
	end
	part({
		Name = "CrystalCrown",
		Size = Vector3.new(3, 6, 3),
		CFrame = at(0, 26, BASE_D / 2 + 6) * CFrame.Angles(0, math.rad(45), 0),
		Color = color:Lerp(rgb(255, 255, 255), 0.3),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CastShadow = false,
		CanCollide = false,
		Parent = levels[7],
	})
	-- Level 8: everything turns to legend: golden spires on the gate, a golden dome on the hall and floating
	-- crystals in a ring above the castle
	part({
		Name = "GoldenDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		CFrame = at(0, 19, BASE_D / 2 + 6),
		Color = rgb(255, 200, 60),
		Material = Enum.Material.Foil,
		Parent = levels[8],
	})
	for _, side in { -1, 1 } do
		part({
			Name = "GoldSpire",
			Size = Vector3.new(1.4, 9, 1.4),
			CFrame = at(side * 13, 21.5, -BASE_D / 2 - 0.5),
			Color = rgb(255, 200, 60),
			Material = Enum.Material.Foil,
			Parent = levels[8],
		})
	end
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part({
			Name = "FloatingCrystal",
			Size = Vector3.new(1.6, 3.4, 1.6),
			CFrame = at(math.cos(a) * 18, 30 + (i % 2) * 2, math.sin(a) * 22) * CFrame.Angles(0, a, math.rad(15)),
			Color = BASE_COLORS[(index + i - 2) % #BASE_COLORS + 1],
			Material = Enum.Material.Neon,
			CastShadow = false,
			CanCollide = false,
			Parent = levels[8],
		})
	end
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
	-- Nests: a dragon gallery, not a grid. Stepped stands along both side walls (a low front row and a raised back
	-- row, staggered so every dragon can be seen, all facing the middle) and a two-step trophy stand across the back
	-- facing the gate. The middle stays open to walk around in, with the egg on its pedestal in the centre.
	local STAND = rgb(214, 204, 188)
	local trim = color:Lerp(rgb(255, 255, 255), 0.15)
	local function stand(name, x0, z0, x1, z1, top)
		part({
			Name = name,
			Size = Vector3.new(x1 - x0, top - 0.4, z1 - z0),
			CFrame = at((x0 + x1) / 2, 0.4 + (top - 0.4) / 2, (z0 + z1) / 2),
			Color = STAND,
			Material = Enum.Material.Marble,
			Parent = model,
		})
		-- a coloured edge along the front lip
		part({
			Name = name .. "Trim",
			Size = Vector3.new(x1 - x0 + 0.1, 0.3, z1 - z0 + 0.1),
			CFrame = at((x0 + x1) / 2, top - 0.15, (z0 + z1) / 2),
			Color = trim,
			CastShadow = false,
			Parent = model,
		})
	end
	local LOW, HIGH = 1.4, 3.6 -- stand tops
	for _, side in { -1, 1 } do
		local function xs(a, b)
			return math.min(side * a, side * b), math.max(side * a, side * b)
		end
		local a0, a1 = xs(11, 17)
		stand("StandLow", a0, -15.5, a1, 18, LOW)
		local b0, b1 = xs(17, BASE_W / 2 - 0.7)
		stand("StandHigh", b0, -11, b1, 23.2, HIGH)
	end
	stand("TrophyLow", -13.8, 18, 13.8, 23.8, LOW)
	stand("TrophyHigh", -13.8, 23.8, 13.8, BASE_D / 2 - 0.7, HIGH)
	-- the 24 spots, in the order nests open: the low side rows first, then the trophy stand, then the high rows
	local spots = {}
	for _, z in { -12, -3, 6, 15 } do
		for _, side in { -1, 1 } do
			table.insert(spots, { side * 14, LOW, z, side })
		end
	end
	for _, x in { -10.5, -3.5, 3.5, 10.5 } do
		table.insert(spots, { x, LOW, 20.9, 0 })
	end
	for _, z in { -7.5, 1.5, 10.5, 19.5 } do
		for _, side in { -1, 1 } do
			table.insert(spots, { side * 19.6, HIGH, z, side })
		end
	end
	for _, x in { -10.5, -3.5, 3.5, 10.5 } do
		table.insert(spots, { x, HIGH, 26.6, 0 })
	end
	local nests = {}
	for i, spot in ipairs(spots) do
		local x, top, z, side = spot[1], spot[2], spot[3], spot[4]
		-- side rows face the middle aisle; the trophy stand faces the gate
		local facing = side == 0 and CFrame.new() or CFrame.Angles(0, side < 0 and -math.pi / 2 or math.pi / 2, 0)
		local pad = part({
			Name = "Nest" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 5.4, 5.4),
			CFrame = at(x, top + 0.4, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(150, 105, 65),
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
		part({
			Name = "Straw",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 4.4, 4.4),
			CFrame = at(x, top + 0.85, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(245, 215, 125),
			Material = Enum.Material.Fabric,
			CastShadow = false,
			Parent = pad,
		})
		nests[i] = { pad = pad, feet = at(x, top + 1, z) * facing }
	end
	-- a rug down the middle aisle
	part({
		Name = "Rug",
		Size = Vector3.new(8, 0.06, 30),
		CFrame = at(0, 0.43, 1),
		Color = color:Lerp(rgb(60, 30, 30), 0.35),
		Material = Enum.Material.Fabric,
		CastShadow = false,
		Parent = model,
	})
	part({
		Name = "RugTrim",
		Size = Vector3.new(9, 0.04, 31),
		CFrame = at(0, 0.42, 1),
		Color = rgb(255, 200, 60),
		CastShadow = false,
		Parent = model,
	})
	-- Front row, just inside the gate: the coin pad (with the treasure chest) and the Auto Collect plate on the
	-- left, the lock pad and the 30-Minute Lock plate on the right. The egg stand is at the back.
	local padZ = -BASE_D / 2 + 6
	local function pad(name, x, size, padColor, signLines, signW)
		local p = part({
			Name = name,
			Size = size,
			CFrame = at(x, 0.6, padZ),
			Color = padColor,
			Parent = model,
		})
		-- a small label in screen pixels, so it never fills the view when you stand next to it
		local gui, padLines = billboard(p, signW, #signLines * 1.6 + 0.4, Vector3.new(0, 2.4, 0), signLines, 28)
		gui.Size = UDim2.fromOffset(signW * 10, #signLines * 17 + 4)
		return p, padLines
	end
	local collectPad, collectLines = pad("CollectPad", -14, Vector3.new(7, 0.5, 6), rgb(245, 190, 40), {
		{ text = "💰 COINS", h = 0.5, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "0", h = 0.5, y = 0.5, color = rgb(255, 230, 120) },
	}, 9)
	local autoPlate = pad("AutoPlate", -6.5, Vector3.new(5, 0.5, 5), rgb(90, 200, 255), {
		{ text = "🧲 AUTO", h = 0.55, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "collect coins", h = 0.45, y = 0.55, color = rgb(200, 240, 255) },
	}, 8)
	local lockPad = pad("LockPad", 10, Vector3.new(7, 0.5, 5), rgb(230, 60, 60), {
		{ text = "🔒 LOCK", h = 1, y = 0, font = Enum.Font.LuckiestGuy },
	}, 8)
	local lockPlate = pad("LockPlate", 17.5, Vector3.new(5, 0.5, 5), rgb(255, 150, 60), {
		{ text = "🔒 30 MIN", h = 0.55, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "lock time", h = 0.45, y = 0.55, color = rgb(255, 225, 190) },
	}, 8)
	part({
		Name = "Chest",
		Size = Vector3.new(3.4, 2, 2.2),
		CFrame = at(-20.2, 1.4, padZ + 1),
		Color = rgb(140, 90, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	part({
		Name = "ChestLid",
		Size = Vector3.new(3.6, 0.8, 2.4),
		CFrame = at(-20.2, 2.7, padZ + 1),
		Color = rgb(255, 200, 60),
		Material = Enum.Material.Foil,
		Parent = model,
	})
	for _, c in { { -19, 0.7, padZ - 1.2 }, { -21, 0.7, padZ - 1.6 }, { -20.2, 1.2, padZ - 0.8 } } do
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
	-- the egg on a pedestal in the middle of the gallery, and the LEVEL ALL plate in front of it
	local eggZ = 6
	local eggStand = part({
		Name = "EggStand",
		Size = Vector3.new(4, 1.6, 4),
		CFrame = at(0, 0.8, eggZ),
		Color = rgb(250, 245, 235),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	-- LEVEL ALL: a podium beside the egg with a hold-to-use prompt (ShopService), so it's never set off by just
	-- walking past
	local podium = part({
		Name = "LevelPodium",
		Size = Vector3.new(2.4, 2.6, 2.4),
		CFrame = at(5.5, 1.7, eggZ),
		Color = rgb(250, 245, 235),
		Material = Enum.Material.Marble,
		Parent = model,
	})
	local levelPlate = part({
		Name = "LevelPlate",
		Size = Vector3.new(2.8, 0.4, 2.8),
		CFrame = at(5.5, 3.2, eggZ),
		Color = rgb(120, 220, 110),
		Material = Enum.Material.Neon,
		Parent = model,
	})
	podium.Parent = model
	local levelSign = billboard(levelPlate, 9, 3.6, Vector3.new(0, 2.6, 0), {
		{ text = "⬆️ LEVEL ALL", h = 0.55, y = 0, font = Enum.Font.LuckiestGuy },
		{ text = "every dragon, with coins", h = 0.45, y = 0.55, color = rgb(210, 255, 200) },
	}, 28)
	levelSign.Size = UDim2.fromOffset(104, 38)
	part({
		Name = "EggTrim",
		Size = Vector3.new(4.4, 0.4, 4.4),
		CFrame = at(0, 1.5, eggZ),
		Color = rgb(255, 200, 60),
		Material = Enum.Material.Foil,
		CastShadow = false,
		Parent = model,
	})
	-- wall lanterns inside
	for _, x in { -1, 1 } do
		part({
			Name = "WallLamp",
			Size = Vector3.new(0.8, 1.2, 0.8),
			CFrame = at(x * (BASE_W / 2 - 1.2), 6.5, 0),
			Color = rgb(255, 200, 90),
			Material = Enum.Material.Neon,
			CastShadow = false,
			Parent = levels[4],
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
		lockPlate = lockPlate,
		autoPlate = autoPlate,
		levelPlate = levelPlate,
		levels = levels,
		collectPad = collectPad,
		collectLines = collectLines,
		eggStand = eggStand,
		gateCf = at(0, 0.5, -BASE_D / 2 - 4),
		-- where the owner spawns: just inside the gate, facing the road
		homeCf = at(0, 3, -BASE_D / 2 + 5),
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

-- The cliff wall around the map: an ellipse (centre x, radii) at the cliffs' foot.
local CLIFF_CX, CLIFF_RX, CLIFF_RZ = -25, 300, 212

-- Places where scenery must not go: the lobby, the road and its sidewalks, the bases, the Practice Base, the cliffs.
local function clear(x, z)
	if ((x - CLIFF_CX) / (CLIFF_RX - 14)) ^ 2 + (z / (CLIFF_RZ - 14)) ^ 2 > 1 then
		return false -- at the foot of the cliffs
	end
	if x > -238 and x < -108 and math.abs(z) < 58 then
		return false -- the castle courtyard and its keep
	end
	if math.abs(z) < 20 and x > -130 and x < 128 then
		return false
	end
	if x > 105 and x < 200 and math.abs(z) < 45 then
		return false -- the exit tunnel and its hill
	end
	for _, bx in BASE_XS do
		if math.abs(x - bx) < BASE_W / 2 + 6 and math.abs(z) > 12 and math.abs(z) < BASE_Z + BASE_D / 2 + 16 then
			return false
		end
	end
	if x > -165 and x < -125 and z > -80 and z < -44 then
		return false
	end
	return true
end
WorldBuilder.isClear = clear

-- The exit tunnel at the far end of the road: a rock hill with a dark tunnel straight through its middle. Road
-- dragons walk in and disappear in the dark (RoadService removes them at ROAD_EXIT_X), so they never walk into
-- rock. x = the tunnel mouth; the tunnel runs east (+X).
local function exitTunnel(parent, x)
	local rock = rgb(112, 104, 120)
	local dark = rgb(10, 9, 16)
	local len = Constants.ROAD_EXIT_X + 10 - x
	local mid = x + len / 2
	local inner, height = 14, 12
	-- black inside: floor, walls, ceiling and the far end
	part({
		Name = "TunnelFloor",
		Size = Vector3.new(len, 0.6, inner),
		CFrame = CFrame.new(mid, 0.3, 0),
		Color = dark,
		Parent = parent,
	})
	-- the north wall stops at the secret disco's door near the far end (see Disco.lua)
	local door = Disco.DOOR
	for _, z in { -1, 1 } do
		local x1 = z > 0 and door.x0 or x + len
		local x1rock = z > 0 and door.x0 - 0.8 or x + len
		part({
			Name = "TunnelWall",
			Size = Vector3.new(x1 - x, height, 0.4),
			CFrame = CFrame.new((x + x1) / 2, height / 2, z * (inner / 2 + 0.2)),
			Color = dark,
			Parent = parent,
		})
		-- the rock hill around it
		part({
			Name = "TunnelRock",
			Size = Vector3.new(x1rock - x, height + 6, 14),
			CFrame = CFrame.new((x + x1rock) / 2, (height + 6) / 2, z * (inner / 2 + 7.4)),
			Color = rock,
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	part({
		Name = "TunnelWall", -- over the door
		Size = Vector3.new(x + len - door.x0, height - 9.6, 0.4),
		CFrame = CFrame.new((door.x0 + x + len) / 2, 9.6 + (height - 9.6) / 2, inner / 2 + 0.2),
		Color = dark,
		Parent = parent,
	})
	part({
		Name = "TunnelCeiling",
		Size = Vector3.new(len, 0.4, inner + 0.8),
		CFrame = CFrame.new(mid, height + 0.2, 0),
		Color = dark,
		Parent = parent,
	})
	part({
		Name = "TunnelRoof",
		Size = Vector3.new(len, 5.6, inner + 0.8),
		CFrame = CFrame.new(mid, height + 3.2, 0),
		Color = rock,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	part({
		Name = "TunnelEnd",
		Size = Vector3.new(0.4, height, inner),
		CFrame = CFrame.new(x + len, height / 2, 0),
		Color = dark,
		Parent = parent,
	})
	-- stone arch around the mouth, with the road's glow strip running in
	part({
		Name = "TunnelArch",
		Size = Vector3.new(3, 3, inner + 8),
		CFrame = CFrame.new(x - 1, height + 1.5, 0),
		Color = rgb(150, 142, 158),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
	for _, z in { -1, 1 } do
		part({
			Name = "TunnelPillar",
			Size = Vector3.new(3, height, 3),
			CFrame = CFrame.new(x - 1, height / 2, z * (inner / 2 + 1.5)),
			Color = rgb(150, 142, 158),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	part({
		Name = "TunnelGlow",
		Size = Vector3.new(8, 0.2, 0.5),
		CFrame = CFrame.new(x + 2, 0.66, 0),
		Color = rgb(110, 220, 255),
		Material = Enum.Material.Neon,
		CastShadow = false,
		CanCollide = false,
		Parent = parent,
	})
	-- a snowy mountain behind and around the tunnel (kept clear of the mouth)
	local rng = Random.new(11)
	-- (kept clear of the secret disco's room too, north-east of the tunnel's end)
	for _, m in { { 60, 14, 0, 46 }, { 14, 8, -30, 34 }, { 50, 8, 52, 30 }, { 40, 20, -18, 40 }, { 62, 20, 22, 40 } } do
		Scenery.ball(
			parent,
			"MountainRock",
			Vector3.new(x + len + m[1] + 2, m[2] - 6, m[3]),
			m[4],
			rock:Lerp(rgb(90, 85, 100), rng:NextNumber()),
			Enum.Material.Slate
		)
	end
	Scenery.ball(parent, "Snow", Vector3.new(x + len + 62, 34, 0), 20, rgb(245, 248, 255), Enum.Material.Snow)
	WorldBuilder.discoModel = Disco.build(parent)
	billboard(parent:FindFirstChild("TunnelArch"), 18, 3, Vector3.new(0, 3.5, 0), {
		{ text = "EXIT", h = 1, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(150, 230, 255) },
	}, 160)
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

-- Show a base's castle at a level (1 .. #CASTLE_LEVEL_POWER): the pieces of every level up to it appear, the
-- rest hide. Each part remembers how it looked when built.
function WorldBuilder.setCastleLevel(world, level)
	for l, m in world.levels do
		local show = l <= level
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				if p:GetAttribute("ShownTransparency") == nil then
					p:SetAttribute("ShownTransparency", p.Transparency)
					p:SetAttribute("ShownCollide", p.CanCollide)
				end
				p.Transparency = show and p:GetAttribute("ShownTransparency") or 1
				p.CanCollide = show and p:GetAttribute("ShownCollide") or false
			end
		end
	end
	world.castleLevel = level
end

function WorldBuilder.build()
	-- remove what Studio's Baseplate template puts in a new place (the grey baseplate and its spawn pad)
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or (child:IsA("SpawnLocation") and child.Name == "SpawnLocation") then
			child:Destroy()
		end
	end
	lighting()
	local rng = Random.new(42)
	local map = folder("Map", workspace)
	-- green studded plastic, like a LEGO baseplate (Scenery.brick turns grass into studded plastic)
	part({
		Name = "Ground",
		Size = Vector3.new(1600, 2, 1600),
		CFrame = CFrame.new(0, -1, 0),
		Color = rgb(88, 162, 76),
		Parent = map,
	})
	-- lighter green plates laid on top here and there, so the ground isn't one flat colour
	local deco = folder("Decor", map)
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-260, 220), rng:NextNumber(-150, 150)
		if clear(x, z) then
			-- (whole studs, so the plate's studs line up with the ground's)
			part({
				Name = "Meadow",
				Size = Vector3.new(rng:NextInteger(8, 20) * 2, 0.4, rng:NextInteger(8, 20) * 2),
				CFrame = CFrame.new(math.floor(x), 0.2, math.floor(z)),
				Color = rgb(104, 178, 86):Lerp(rgb(80, 150, 72), rng:NextNumber()),
				Material = Enum.Material.Grass,
				CastShadow = false,
				Parent = deco,
			})
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
					* CFrame.Angles(0, math.pi, 0) -- flip: the chevron's tip points +X, the way dragons walk
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
	for x = Constants.ROAD_START_X + 14, Constants.ROAD_END_X - 6, 48 do
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
	-- New dragons appear at the Dragon Gate next to the lobby (an open arch, so the spawn looks straight down the
	-- road) and leave through the dark exit tunnel at the far end.
	dragonGate(road, Constants.ROAD_START_X - 3)
	exitTunnel(road, Constants.ROAD_END_X + 3)

	-- Lobby: the courtyard of a castle at the start of the road. Stone walls with towers close it in and a great
	-- keep looks over it from the west; on the east side the Dragon Gate is the courtyard's gate onto the road.
	-- New players spawn on the east side looking down the road. A fountain with the golden dragon statue stands
	-- in the middle, the three leaderboards stand against the north wall, the FREE dragon waits off to the south
	-- right in front of the spawn, and a gap in the south wall leads to the Practice Base.
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = map
	local L = WorldBuilder.LOBBY
	local cx = (L.x0 + L.x1) / 2
	part({
		Name = "Plaza",
		Size = Vector3.new(L.x1 - L.x0, 0.6, L.z1 - L.z0),
		CFrame = CFrame.new(cx, 0.3, 0),
		Color = rgb(196, 186, 170),
		Material = Enum.Material.Cobblestone,
		Parent = lobby,
	})
	-- paving pattern: a gold ring around the fountain and a marble cross of paths
	-- (each layer sits a clear step above the one below, so they never flicker)
	Scenery.disc(lobby, "PlazaRing", Vector3.new(cx, 0.67, 0), 40, 0.06, rgb(232, 180, 70), nil, {
		CastShadow = false,
		CanCollide = false,
	})
	Scenery.disc(lobby, "PlazaInner", Vector3.new(cx, 0.73, 0), 37, 0.06, rgb(210, 202, 188), Enum.Material.Marble, {
		CastShadow = false,
		CanCollide = false,
	})
	for _, p in { { cx, 0, L.x1 - L.x0, 7 }, { cx, 0, 7, L.z1 - L.z0 } } do
		part({
			Name = "PlazaPath",
			Size = Vector3.new(p[3], 0.04, p[4]),
			CFrame = CFrame.new(p[1], 0.62, p[2]),
			Color = rgb(214, 206, 192),
			Material = Enum.Material.Marble,
			CastShadow = false,
			CanCollide = false,
			Parent = lobby,
		})
	end

	-- Castle walls: a walkway on top with battlements on the outer edge and banners on the inner face
	local WALL_H, WALL_T = 11, 3 -- the east walls by the gate; the sides and back stand taller
	local TALL_H = 16
	local wallStone = rgb(176, 168, 158)
	local function castleWall(x0, z0, x1, z1, inward, height)
		local wallH = height or WALL_H
		local along = x1 ~= x0 and Vector3.xAxis or Vector3.zAxis
		local len = (x1 - x0) + (z1 - z0)
		local mid = Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
		local size = along == Vector3.xAxis and Vector3.new(len, wallH, WALL_T) or Vector3.new(WALL_T, wallH, len)
		part({
			Name = "CastleWall",
			Size = size,
			CFrame = CFrame.new(mid + Vector3.new(0, wallH / 2, 0)),
			Color = wallStone,
			Material = Enum.Material.Cobblestone,
			Parent = lobby,
		})
		-- a darker plinth along the bottom and a capping band along the top
		for _, band in { { 1.2, 0.6, STONE_DARK }, { 0.8, wallH - 0.4, rgb(196, 188, 178) } } do
			local grow = along == Vector3.xAxis and Vector3.new(0, 0, 0.6) or Vector3.new(0.6, 0, 0)
			part({
				Name = "WallBand",
				Size = Vector3.new(size.X, band[1], size.Z) + grow,
				CFrame = CFrame.new(mid + Vector3.new(0, band[2], 0)),
				Color = band[3],
				Material = Enum.Material.Cobblestone,
				Parent = lobby,
			})
		end
		local outward = -inward
		local n = math.floor(len / 4)
		for i = 0, n - 1 do
			local t = (i + 0.5) / n - 0.5
			part({
				Name = "Merlon",
				Size = along == Vector3.xAxis and Vector3.new(2, 2, 0.9) or Vector3.new(0.9, 2, 2),
				CFrame = CFrame.new(
					mid + along * (t * len) + outward * (WALL_T / 2 - 0.45) + Vector3.new(0, wallH + 1, 0)
				),
				Color = wallStone,
				Material = Enum.Material.Cobblestone,
				Parent = lobby,
			})
		end
		-- banners hanging on the courtyard side, in the eight base colours
		local count = math.max(1, math.floor(len / 16))
		for i = 1, count do
			local t = i / (count + 1) - 0.5
			local pos = mid + along * (t * len) + inward * (WALL_T / 2 + 0.12)
			local color = BASE_COLORS[(math.floor(pos.X + pos.Z) % #BASE_COLORS) + 1]
			local face = CFrame.lookAt(pos, pos + inward)
			part({
				Name = "WallBanner",
				Size = Vector3.new(3, 5.5, 0.15),
				CFrame = face * CFrame.new(0, 6.6, 0),
				Color = color,
				Material = Enum.Material.Fabric,
				CastShadow = false,
				CanCollide = false,
				Parent = lobby,
			})
			part({
				Name = "BannerRod",
				Size = Vector3.new(3.8, 0.25, 0.25),
				CFrame = face * CFrame.new(0, 9.45, 0),
				Color = rgb(255, 205, 60),
				Material = Enum.Material.Metal,
				CanCollide = false,
				Parent = lobby,
			})
			part({
				Name = "BannerTrim",
				Size = Vector3.new(3, 0.5, 0.18),
				CFrame = face * CFrame.new(0, 4.1, 0),
				Color = rgb(255, 205, 60),
				CastShadow = false,
				CanCollide = false,
				Parent = lobby,
			})
		end
	end
	local wx0, wx1, wz = L.x0 - WALL_T / 2, L.x1 + WALL_T / 2 - 0.5, L.z1 + WALL_T / 2
	castleWall(wx0, wz, wx1, wz, -Vector3.zAxis, TALL_H) -- north
	castleWall(wx0, -wz, -153, -wz, Vector3.zAxis, TALL_H) -- south, west of the Practice Base gap
	castleWall(-137, -wz, wx1, -wz, Vector3.zAxis, TALL_H) -- south, east of the gap
	castleWall(wx0, -wz, wx0, wz, Vector3.xAxis, TALL_H) -- west
	-- the east walls run up to the Dragon Gate's pillars (z = +-11.5)
	castleWall(wx1, 11.5, wx1, wz, -Vector3.xAxis) -- east, north of the road
	castleWall(wx1, -wz, wx1, -11.5, -Vector3.xAxis) -- east, south of the road
	-- towers at the corners (the east ones slim, next to the first bases) and in the middle of the west wall
	for _, t in
		{
			{ wx0, wz, 10, 25 },
			{ wx0, -wz, 10, 25 },
			{ wx1, wz, 6, 20 },
			{ wx1, -wz, 6, 20 },
			{ wx0, -30, 8, 22 }, -- (not in the middle of the west wall: that would hide the keep's name)
			{ wx0, 30, 8, 22 },
			{ -125, -wz - 0.5, 7, 21 }, -- halfway along the south walls, either side of the Practice Base gap
			{ -179, -wz - 0.5, 7, 21 },
		}
	do
		Scenery.tower(lobby, Vector3.new(t[1], 0, t[2]), t[3], t[4], wallStone, rgb(70, 95, 190), rgb(255, 205, 60))
	end
	-- a small arch over the gap to the Practice Base
	part({
		Name = "PracticeArch",
		Size = Vector3.new(16 + 2, 2.4, WALL_T + 0.6),
		CFrame = CFrame.new(-145, TALL_H - 1.2, -wz),
		Color = wallStone,
		Material = Enum.Material.Cobblestone,
		Parent = lobby,
	})

	-- The keep: a great hall behind the west wall with towers, tall windows and a huge door
	local keepX = wx0 - 15
	local keepStone = rgb(186, 178, 168)
	part({
		Name = "Keep",
		Size = Vector3.new(24, 30, 40),
		CFrame = CFrame.new(keepX, 15, 0),
		Color = keepStone,
		Material = Enum.Material.Cobblestone,
		Parent = lobby,
	})
	part({
		Name = "KeepTop",
		Size = Vector3.new(26, 1.4, 42),
		CFrame = CFrame.new(keepX, 30.7, 0),
		Color = rgb(150, 142, 134),
		Material = Enum.Material.Cobblestone,
		Parent = lobby,
	})
	for i = -4, 4 do
		part({
			Name = "Merlon",
			Size = Vector3.new(1.2, 2.2, 2.4),
			CFrame = CFrame.new(keepX + 12.4, 32.5, i * 4.6),
			Color = keepStone,
			Material = Enum.Material.Cobblestone,
			Parent = lobby,
		})
	end
	Scenery.cone(lobby, "KeepRoof", Vector3.new(keepX, 31.4, 0), 18, 16, rgb(70, 95, 190), 4)
	Scenery.flag(lobby, Vector3.new(keepX, 47, 0), 7, rgb(200, 50, 50))
	for _, z in { -20, 20 } do
		Scenery.tower(lobby, Vector3.new(keepX + 4, 0, z), 11, 36, keepStone, rgb(70, 95, 190), rgb(200, 50, 50))
	end
	-- tall windows glowing warm, and the great door
	for _, z in { -12, -6, 6, 12 } do
		for _, y in { 14, 23 } do
			part({
				Name = "KeepWindow",
				Size = Vector3.new(0.3, 4.4, 2),
				CFrame = CFrame.new(keepX + 12.05, y, z),
				Color = rgb(255, 200, 110),
				Material = Enum.Material.Neon,
				CastShadow = false,
				Parent = lobby,
			})
			part({
				Name = "WindowArch",
				Size = Vector3.new(0.4, 0.6, 2.8),
				CFrame = CFrame.new(keepX + 12.1, y + 2.5, z),
				Color = rgb(140, 132, 124),
				Parent = lobby,
			})
		end
	end
	part({
		Name = "KeepDoor",
		Size = Vector3.new(0.4, 9, 7),
		CFrame = CFrame.new(keepX + 12.1, 4.5 + WALL_H - 9, 0),
		Color = rgb(120, 80, 45),
		Material = Enum.Material.WoodPlanks,
		Parent = lobby,
	})
	-- the name on a board fixed flat to the keep's front (a floating sign would sink into the towers)
	part({
		Name = "KeepSignFrame",
		Size = Vector3.new(0.3, 4.6, 27),
		CFrame = CFrame.new(keepX + 12.15, 27.9, 0),
		Color = rgb(255, 200, 60),
		Material = Enum.Material.Foil,
		Parent = lobby,
	})
	local keepSign = part({
		Name = "KeepSign",
		Size = Vector3.new(0.3, 3.8, 26),
		CFrame = CFrame.new(keepX + 12.35, 27.9, 0),
		Color = rgb(40, 46, 110),
		Parent = lobby,
	})
	local keepGui = Instance.new("SurfaceGui")
	keepGui.Name = "Sign"
	keepGui.Face = Enum.NormalId.Right
	keepGui.CanvasSize = Vector2.new(780, 114)
	keepGui.LightInfluence = 0
	keepGui.Parent = keepSign
	label(keepGui, {
		Name = "Title",
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.new(0, 10, 0, 6),
		Text = "STEAL A DRAGON",
		TextColor3 = rgb(255, 215, 70),
		Font = Enum.Font.LuckiestGuy,
	})

	-- Inside the courtyard: planters with trees in the south corners (the north wall is for the leaderboards) and
	-- flowers along the walls
	-- (the south-east corner is the TOP SPENDERS board and the Mystery Box)
	for _, c in { { L.x0 + 6, L.z0 + 6 } } do
		Scenery.disc(lobby, "Planter", Vector3.new(c[1], 1.2, c[2]), 7, 1.8, STONE_DARK, Enum.Material.Cobblestone)
		Scenery.roundTree(lobby, Vector3.new(c[1], 2.1, c[2]), 0.9, rng)
	end
	for _, f in { { -190, 20 }, { -190, -20 }, { -168, -40 } } do
		Scenery.flowers(lobby, Vector3.new(f[1], 0.6, f[2]), 6, rng)
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
	-- the fountain in the middle with the golden dragon statue on its pedestal
	local statueBase = Vector3.new(cx, 0.6, 0)
	-- the basin, then the water a little lower than the gold rim stones that ring it (nothing shares a surface)
	Scenery.disc(
		lobby,
		"Fountain",
		statueBase + Vector3.new(0, 0.6, 0),
		22,
		1.2,
		rgb(200, 192, 180),
		Enum.Material.Marble
	)
	Scenery.disc(
		lobby,
		"FountainWater",
		statueBase + Vector3.new(0, 1.35, 0),
		20,
		0.3,
		rgb(90, 180, 255),
		Enum.Material.Glass,
		{ Transparency = 0.2, CanCollide = false, CastShadow = false }
	)
	for i = 1, 20 do
		local a = (i - 0.5) / 20 * math.pi * 2
		part({
			Name = "FountainRim",
			Size = Vector3.new(3.5, 0.9, 1.2),
			CFrame = CFrame.new(statueBase + Vector3.new(math.cos(a) * 10.6, 1.65, math.sin(a) * 10.6))
				* CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = rgb(255, 200, 60),
			Material = Enum.Material.Foil,
			Parent = lobby,
		})
	end
	Scenery.disc(lobby, "Pedestal", statueBase + Vector3.new(0, 2.5, 0), 9, 5, rgb(215, 208, 195), Enum.Material.Marble)
	Scenery.disc(
		lobby,
		"PedestalTrim",
		statueBase + Vector3.new(0, 5.1, 0),
		9.6,
		0.4,
		rgb(255, 200, 60),
		Enum.Material.Foil
	)
	local statue = DragonBuilder.build("GOLDIE", "GOLD", 4, 1.2)
	for _, d in statue:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	statue.Name = "DragonStatue"
	statue:SetAttribute("TurnSpeed", 0.12) -- FxController turns it slowly
	statue:SetAttribute("Flap", true) -- and slowly flaps its wings
	DragonBuilder.place(statue, CFrame.new(statueBase + Vector3.new(0, 5.3, 0)) * CFrame.Angles(0, math.rad(-90), 0))
	statue.Parent = lobby
	-- the four leaderboards side by side against the north wall, facing south into the courtyard. The daily
	-- TOP EARNERS board has the prize on show in front of it: the Ultra dragon on a pedestal, slowly turning.
	local function boardAt(x)
		local p = Vector3.new(x, 0.6, L.z1 - 3)
		return CFrame.lookAt(p, p - Vector3.zAxis)
	end
	-- (seen from the courtyard, facing north, +X is on the left: so they read COINS, TODAY, BEST, THIEVES)
	local DAILY_X = cx + 11
	local boards = {
		coins = leaderboard(lobby, boardAt(cx + 33), "TOP COINS", rgb(255, 205, 50)),
		daily = leaderboard(lobby, boardAt(DAILY_X), "TODAY'S TOP EARNERS", rgb(120, 255, 240)),
		income = leaderboard(lobby, boardAt(cx - 11), "BEST DRAGONS", rgb(110, 200, 255)),
		steals = leaderboard(lobby, boardAt(cx - 33), "TOP THIEVES", rgb(255, 90, 90)),
	}
	local prizeSign = part({
		Name = "PrizeSign",
		Size = Vector3.new(17, 4.6, 0.8),
		CFrame = boardAt(DAILY_X) * CFrame.new(0, 25, 0),
		Color = rgb(30, 34, 60),
		Parent = lobby,
	})
	part({
		Name = "PrizeSignFrame",
		Size = Vector3.new(17.8, 5.4, 0.6),
		CFrame = prizeSign.CFrame * CFrame.new(0, 0, 0.3),
		Color = rgb(120, 255, 240),
		Material = Enum.Material.Neon,
		Parent = lobby,
	})
	local prizeGui = Instance.new("SurfaceGui")
	prizeGui.Name = "Prize"
	prizeGui.Face = Enum.NormalId.Front
	prizeGui.CanvasSize = Vector2.new(520, 140)
	prizeGui.LightInfluence = 0
	prizeGui.Parent = prizeSign
	label(prizeGui, {
		Name = "Prize",
		Size = UDim2.new(1, -16, 0.56, 0),
		Position = UDim2.new(0, 8, 0, 4),
		Text = "👑 #1 WINS OMNI PRISM · ULTRA RARE",
		TextColor3 = rgb(255, 230, 120),
		Font = Enum.Font.LuckiestGuy,
	})
	boards.daily.timer = label(prizeGui, {
		Name = "Timer",
		Size = UDim2.new(1, -16, 0.38, 0),
		Position = UDim2.new(0, 8, 0.58, 0),
		Text = "⏰ Ends in --",
		TextColor3 = rgb(120, 255, 240),
	})
	local prizePos = (boardAt(DAILY_X) * CFrame.new(0, 0, -8)).Position -- in front of the board (it faces -Z)
	Scenery.disc(
		lobby,
		"PrizePedestal",
		prizePos + Vector3.new(0, 1.2, 0),
		6,
		2.4,
		rgb(40, 44, 70),
		Enum.Material.Marble
	)
	Scenery.disc(
		lobby,
		"PrizeRing",
		prizePos + Vector3.new(0, 2.45, 0),
		6.6,
		0.25,
		rgb(120, 255, 240),
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	local prize = DragonBuilder.build(Dragons.PRIZE, nil, 3)
	for _, d in prize:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	prize.Name = "PrizeDragon"
	DragonBuilder.place(prize, CFrame.new(prizePos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(180), 0))
	DragonBuilder.label(prize, "👑 Omni Prism", Dragons.RarityColor.Ultra, "ULTRA · daily #1 prize")
	prize:SetAttribute("TurnSpeed", 0.35)
	prize.Parent = lobby
	-- The south-east corner, near the spawn: the TOP SPENDERS board (angled toward the courtyard) and the
	-- Mystery Box beside it, on a round gold-and-purple platform of their own
	local PURPLE = rgb(150, 90, 240)
	local cornerCenter = Vector3.new(-127, 0.6, -30)
	Scenery.disc(
		lobby,
		"SpenderPlatform",
		cornerCenter + Vector3.new(0, 0.25, 0),
		30,
		0.5,
		rgb(232, 180, 70),
		Enum.Material.Marble
	)
	Scenery.disc(
		lobby,
		"SpenderCarpet",
		cornerCenter + Vector3.new(0, 0.55, 0),
		27,
		0.1,
		PURPLE,
		Enum.Material.Fabric,
		{
			CastShadow = false,
			CanCollide = false,
		}
	)
	local spenderAt = Vector3.new(-120.5, 1.1, -31)
	boards.spent =
		leaderboard(lobby, CFrame.lookAt(spenderAt, spenderAt + Vector3.new(-1, 0, 1)), "💎 TOP SPENDERS", PURPLE)
	local box = Instance.new("Model")
	box.Name = "MysteryBox"
	local boxAt = Vector3.new(-135.5, 1.1, -28)
	Scenery.disc(
		lobby,
		"MysteryPedestal",
		boxAt + Vector3.new(0, 0.6, 0),
		4.2,
		1.2,
		rgb(40, 44, 70),
		Enum.Material.Marble
	)
	Scenery.disc(lobby, "MysteryRing", boxAt + Vector3.new(0, 1.25, 0), 4.6, 0.15, PURPLE, Enum.Material.Neon, {
		CanCollide = false,
	})
	local core = part({
		Name = "Core",
		Size = Vector3.new(4, 3.6, 4),
		CFrame = CFrame.new(boxAt + Vector3.new(0, 3.1, 0)),
		Color = PURPLE,
		Material = Enum.Material.SmoothPlastic,
		Parent = box,
	})
	part({
		Name = "Lid",
		Size = Vector3.new(4.4, 0.9, 4.4),
		CFrame = core.CFrame * CFrame.new(0, 2.2, 0),
		Color = rgb(120, 70, 210),
		Material = Enum.Material.SmoothPlastic,
		Parent = box,
	})
	-- gold ribbon both ways, and a bow on top
	for _, r in { Vector3.new(4.5, 4.6, 0.7), Vector3.new(0.7, 4.6, 4.5) } do
		part({
			Name = "Ribbon",
			Size = r,
			CFrame = core.CFrame * CFrame.new(0, 0.45, 0),
			Color = rgb(255, 205, 60),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = box,
		})
	end
	for _, side in { -1, 1 } do
		part({
			Name = "Bow",
			Size = Vector3.new(1.4, 1, 0.5),
			CFrame = core.CFrame * CFrame.new(side * 0.75, 3.1, 0) * CFrame.Angles(0, 0, math.rad(side * -25)),
			Color = rgb(255, 205, 60),
			CanCollide = false,
			Parent = box,
		})
	end
	-- a big "?" on all four sides
	for i = 0, 3 do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Mark" .. i
		gui.Face = ({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right })[i + 1]
		gui.CanvasSize = Vector2.new(200, 180)
		gui.LightInfluence = 0
		gui.Parent = core
		label(gui, {
			Name = "Q",
			Size = UDim2.fromScale(1, 1),
			Text = "?",
			Font = Enum.Font.LuckiestGuy,
			TextColor3 = rgb(255, 230, 120),
		})
	end
	local glow = Instance.new("PointLight")
	glow.Color = PURPLE
	glow.Range = 12
	glow.Brightness = 1.5
	glow.Parent = core
	box.PrimaryPart = core
	box:SetAttribute("TurnSpeed", 0.6) -- FxController turns it slowly
	box.Parent = lobby
	billboard(core, 15, 4.6, Vector3.new(0, 6.2, 0), {
		{ text = "🎁 MYSTERY BOX", h = 0.4, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 70) },
		{ text = "Always a Legend or better!", h = 0.22, y = 0.4 },
		{ text = "Legend 85% · Secret 14% · Ultra 1%", h = 0.2, y = 0.62, color = rgb(210, 180, 255) },
		{ text = "R$ 99", h = 0.18, y = 0.82, color = rgb(120, 255, 160) },
	}, 80)

	-- the FREE dragon stand for new players: right in front of where they spawn, beside the path to the road
	local freePos = WorldBuilder.FREE_PAD
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
	for i = 1, Constants.MAX_BASES do
		local north = i <= 4
		local x = BASE_XS[(i - 1) % 4 + 1]
		local z = north and BASE_Z or -BASE_Z
		local cf = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0))
		bases[i] = buildBase(basesFolder, i, cf)
		WorldBuilder.setCastleLevel(bases[i], 1)
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
	-- a hazy ring of far mountains on the horizon, for depth
	for i = 0, 13 do
		local a = (i + 0.5) / 14 * math.pi * 2
		Scenery.farMountain(
			deco,
			Vector3.new(-25 + math.cos(a) * 470, -30, math.sin(a) * 360),
			rng:NextNumber(150, 220)
		)
	end
	-- a tall cliff wall all the way around, with trees along its top and a couple of waterfalls
	local cliffs = folder("Cliffs", deco)
	local CLIFF_SEGMENTS = 44
	for i = 0, CLIFF_SEGMENTS - 1 do
		local a = i / CLIFF_SEGMENTS * math.pi * 2
		local p = Vector3.new(CLIFF_CX + math.cos(a) * CLIFF_RX, 0, math.sin(a) * CLIFF_RZ)
		local inward = -Vector3.new(math.cos(a) / CLIFF_RX, 0, math.sin(a) / CLIFF_RZ).Unit
		local height = 64 + 16 * math.sin(a * 3 + 1) + rng:NextNumber(0, 10)
		-- wide enough to overlap the next stretch everywhere around the ellipse (no gaps)
		local arc = math.sqrt((CLIFF_RX * math.sin(a)) ^ 2 + (CLIFF_RZ * math.cos(a)) ^ 2)
			* math.pi
			* 2
			/ CLIFF_SEGMENTS
		Scenery.cliff(cliffs, CFrame.lookAt(p, p + inward), arc * 1.35 + 4, height, rng, i == 9 or i == 31)
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

	-- Phones: small parts cast no shadow (no visible difference, a lot less GPU work), and pure decoration is
	-- tagged "Detail" so PerformanceController can leave it out on phones and low graphics settings.
	local DETAIL = { Stone = true, Berry = true, Flower = true, Tile = true, Pebble = true, Petal = true, Leaf = true }
	for _, root in { map, basesFolder } do
		for _, p in root:GetDescendants() do
			if p:IsA("BasePart") then
				local size = p.Size
				local big, thin = math.max(size.X, size.Y, size.Z), math.min(size.X, size.Y, size.Z)
				if big < 3 or thin < 0.3 then
					p.CastShadow = false
				end
				if DETAIL[p.Name] or (big < 1.6 and p:IsDescendantOf(deco)) then
					CollectionService:AddTag(p, "Detail")
				end
			end
		end
	end

	WorldBuilder.layout = {
		bases = bases,
		boards = boards,
		mysteryBox = core,
		freePad = freePad,
		-- (facing the spawn)
		freeFeet = CFrame.lookAt(WorldBuilder.FREE_PAD + Vector3.new(0, 0.6, 0), Vector3.new(-130, 1.8, 0)),
		practiceFeet = pcf * CFrame.new(0, 1.2, 2),
		practiceNest = practiceNest,
		practiceCenter = pcf.Position,
		feverButton = WorldBuilder.discoModel and WorldBuilder.discoModel:FindFirstChild("FeverButton"),
		spawn = spawn,
		roadZ = 0,
		roadY = 0.5,
	}
	return WorldBuilder.layout
end

return WorldBuilder

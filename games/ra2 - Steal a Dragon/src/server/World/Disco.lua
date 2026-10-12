-- The secret disco at the end of the exit tunnel. A door near the tunnel's dark far end opens into a corridor that
-- turns twice, so nothing of the party shows from the tunnel mouth or from outside: the room is closed in by
-- rock on every side and on top. Inside: a light-up dance floor, a mirror ball, sweeping lasers, a DJ booth and
-- three dragons dancing. The animation runs on each client (DiscoController), only near the room.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local DragonBuilder = require(script.Parent.DragonBuilder)
local Scenery = require(script.Parent.Scenery)

local Disco = {}

local part = Scenery.part
local rgb = Scenery.rgb

local DARK = rgb(14, 12, 24)
local ROCK = rgb(112, 104, 120)

Disco.COLORS = {
	rgb(255, 60, 140),
	rgb(80, 220, 255),
	rgb(255, 220, 60),
	rgb(140, 90, 255),
	rgb(80, 255, 140),
	rgb(255, 120, 40),
}

-- Room layout, in world studs. The tunnel runs along +X with its floor top at y 0.6 and its north wall at z 7.
Disco.DOOR = { x0 = 136.5, x1 = 141.6 } -- the door in the tunnel's north wall
Disco.ROOM = { x0 = 150, x1 = 180, z0 = 5, z1 = 35, h = 16 }
local FLOOR_Y = 0.6
local CORRIDOR_H = 10

-- A wall piece from (x0, z0) to (x1, z1), axis-aligned, dark inside, with rock around it.
local function wall(parent, name, x0, z0, x1, z1, height, thick)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local sx, sz = math.max(math.abs(x1 - x0), thick), math.max(math.abs(z1 - z0), thick)
	part({
		Name = name,
		Size = Vector3.new(sx, height, sz),
		CFrame = CFrame.new(cx, FLOOR_Y + height / 2, cz),
		Color = DARK,
		Parent = parent,
	})
end

local function floor(parent, name, x0, z0, x1, z1)
	part({
		Name = name,
		Size = Vector3.new(x1 - x0, 0.6, z1 - z0),
		CFrame = CFrame.new((x0 + x1) / 2, 0.3, (z0 + z1) / 2),
		Color = DARK,
		Parent = parent,
	})
end

local function roof(parent, name, x0, z0, x1, z1, y)
	part({
		Name = name,
		Size = Vector3.new(x1 - x0, 6, z1 - z0),
		CFrame = CFrame.new((x0 + x1) / 2, y + 3, (z0 + z1) / 2),
		Color = ROCK,
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

function Disco.build(parent)
	local model = Instance.new("Model")
	model.Name = "Disco"
	model.Parent = parent
	local D, R = Disco.DOOR, Disco.ROOM

	-- Corridor 1 runs north from the tunnel door; its east wall blocks every view from the tunnel mouth.
	local c1z1 = 22
	floor(model, "CorridorFloor", D.x0, 7, D.x1, c1z1)
	wall(model, "CorridorWall", D.x0 - 0.4, 7.4, D.x0 - 0.4, c1z1 + 0.4, CORRIDOR_H, 0.8)
	wall(model, "CorridorWall", D.x1 + 0.4, 7.4, D.x1 + 0.4, 17, CORRIDOR_H, 0.8)
	-- Corridor 2 turns east into the room.
	floor(model, "CorridorFloor", D.x1, 17, R.x0, c1z1)
	wall(model, "CorridorWall", D.x0 - 0.8, c1z1 + 0.4, R.x0, c1z1 + 0.4, CORRIDOR_H, 0.8)
	wall(model, "CorridorWall", D.x1 + 0.8, 16.6, R.x0, 16.6, CORRIDOR_H, 0.8)
	roof(model, "CorridorRoof", D.x0 - 1, 7.4, R.x0, c1z1 + 1, FLOOR_Y + CORRIDOR_H)
	-- little floor lights leading the way
	for i = 0, 6 do
		local z = 9 + i * 2
		local x = i < 5 and (D.x0 + D.x1) / 2 or D.x1 + (i - 4) * 3
		z = i < 5 and z or 19.5
		local dot = part({
			Name = "GuideLight",
			Size = Vector3.new(0.8, 0.12, 0.8),
			CFrame = CFrame.new(x, FLOOR_Y + 0.06, z),
			Color = Disco.COLORS[i % #Disco.COLORS + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
			Parent = model,
		})
		dot:SetAttribute("DiscoTile", i)
	end

	-- The room: walls (the west one has the doorway), a rock roof and a rock hill around it all.
	wall(model, "RoomWall", R.x0, R.z0, R.x1, R.z0, R.h, 1) -- south
	wall(model, "RoomWall", R.x0, R.z1, R.x1, R.z1, R.h, 1) -- north
	wall(model, "RoomWall", R.x1, R.z0, R.x1, R.z1, R.h, 1) -- east
	wall(model, "RoomWall", R.x0, R.z0, R.x0, 16.6, R.h, 1) -- west, south of the doorway
	wall(model, "RoomWall", R.x0, c1z1 + 0.4, R.x0, R.z1, R.h, 1) -- west, north of the doorway
	part({
		Name = "RoomWall",
		Size = Vector3.new(1, R.h - CORRIDOR_H, c1z1 + 0.4 - 16.6),
		CFrame = CFrame.new(R.x0, FLOOR_Y + CORRIDOR_H + (R.h - CORRIDOR_H) / 2, (16.6 + c1z1 + 0.4) / 2),
		Color = DARK,
		Parent = model,
	})
	roof(model, "RoomRoof", R.x0 - 0.5, R.z0 - 0.5, R.x1 + 0.5, R.z1 + 0.5, FLOOR_Y + R.h)
	for _, s in
		{
			{ R.x0 - 4, (R.z0 + R.z1) / 2, 8, R.h + 4, R.z1 - R.z0 + 8 },
			{ R.x1 + 4, (R.z0 + R.z1) / 2, 8, R.h + 4, R.z1 - R.z0 + 8 },
			{ (R.x0 + R.x1) / 2, R.z1 + 4, R.x1 - R.x0 + 16, R.h + 4, 8 },
			{ (R.x0 + R.x1) / 2, R.z0 - 4, R.x1 - R.x0 + 16, R.h + 4, 8 },
		}
	do
		-- thick rock shell outside the walls (kept clear of the corridor)
		local x, z, sx, sy, sz = s[1], s[2], s[3], s[4], s[5]
		if x < R.x0 then
			-- west shell: split around the corridor
			part({
				Name = "DiscoRock",
				Size = Vector3.new(sx, sy, 16.6 - 0.5 - (R.z0 - 8)),
				CFrame = CFrame.new(x, sy / 2, ((R.z0 - 8) + 16.1) / 2),
				Color = ROCK,
				Material = Enum.Material.Slate,
				Parent = model,
			})
			part({
				Name = "DiscoRock",
				Size = Vector3.new(sx, sy, (R.z1 + 8) - (c1z1 + 1)),
				CFrame = CFrame.new(x, sy / 2, ((c1z1 + 1) + (R.z1 + 8)) / 2),
				Color = ROCK,
				Material = Enum.Material.Slate,
				Parent = model,
			})
			part({
				Name = "DiscoRock",
				Size = Vector3.new(sx, sy - CORRIDOR_H - 1, c1z1 + 1 - 16.1),
				CFrame = CFrame.new(x, CORRIDOR_H + 1 + (sy - CORRIDOR_H - 1) / 2, (16.1 + c1z1 + 1) / 2),
				Color = ROCK,
				Material = Enum.Material.Slate,
				Parent = model,
			})
		else
			part({
				Name = "DiscoRock",
				Size = Vector3.new(sx, sy, sz),
				CFrame = CFrame.new(x, sy / 2, z),
				Color = ROCK,
				Material = Enum.Material.Slate,
				Parent = model,
			})
		end
	end
	-- rock around corridor 1 (east side) and on top of the corridor
	part({
		Name = "DiscoRock",
		Size = Vector3.new(R.x0 - 4 - (D.x1 + 0.8), CORRIDOR_H + 6, 16.2 - 7.4),
		CFrame = CFrame.new((D.x1 + 0.8 + R.x0 - 4) / 2, (CORRIDOR_H + 6) / 2, (7.4 + 16.2) / 2),
		Color = ROCK,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	part({
		Name = "DiscoRock",
		Size = Vector3.new(6, CORRIDOR_H + 6, c1z1 + 1 - 7.4),
		CFrame = CFrame.new(D.x0 - 3.8, (CORRIDOR_H + 6) / 2, (7.4 + c1z1 + 1) / 2),
		Color = ROCK,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	part({
		Name = "DiscoRock",
		Size = Vector3.new(R.x0 - (D.x0 - 6.8), CORRIDOR_H + 6, 8),
		CFrame = CFrame.new((D.x0 - 6.8 + R.x0) / 2, (CORRIDOR_H + 6) / 2, c1z1 + 5),
		Color = ROCK,
		Material = Enum.Material.Slate,
		Parent = model,
	})
	for _, b in { { 165, 32, 20, 30 }, { 140, 12, 34, 18 }, { 192, 10, 8, 18 }, { 143, 19, 11, 12 } } do
		-- rounded rock on top and around (all outside the room and corridors; the walls and roof do the blocking)
		Scenery.ball(model, "DiscoHill", Vector3.new(b[1], b[2], b[3]), b[4], ROCK, Enum.Material.Slate, {
			CanCollide = false,
			CanQuery = false,
		})
	end

	-- Dance floor: 6 x 6 light-up tiles
	local tiles = 6
	local size = (R.x1 - R.x0 - 6) / tiles
	local fx0, fz0 = R.x0 + 3, R.z0 + 5
	for i = 0, tiles - 1 do
		for j = 0, tiles - 1 do
			local tile = part({
				Name = "DanceTile",
				Size = Vector3.new(size - 0.2, 0.3, size - 0.2),
				CFrame = CFrame.new(fx0 + (i + 0.5) * size, FLOOR_Y + 0.15, fz0 + (j + 0.5) * size),
				Color = Disco.COLORS[(i + j) % #Disco.COLORS + 1],
				Material = Enum.Material.Neon,
				CastShadow = false,
				Parent = model,
			})
			tile:SetAttribute("DiscoTile", i * tiles + j)
		end
	end
	floor(model, "RoomFloor", R.x0, R.z0, R.x1, R.z1)

	-- Mirror ball with coloured spotlights (they turn with it)
	local center = Vector3.new((R.x0 + R.x1) / 2, FLOOR_Y + R.h - 4, (R.z0 + R.z1) / 2)
	part({
		Name = "BallChain",
		Size = Vector3.new(0.2, 3, 0.2),
		CFrame = CFrame.new(center + Vector3.new(0, 2.6, 0)),
		Color = rgb(180, 180, 190),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local ball = Scenery.ball(model, "DiscoBall", center, 3.4, rgb(220, 225, 235), Enum.Material.Foil, {
		Reflectance = 0.5,
		CanCollide = false,
	})
	ball:SetAttribute("DiscoBall", true)
	for k, angle in { 0, 90, 180, 270 } do
		local a = Instance.new("Attachment")
		a.Name = "Beam" .. k
		a.CFrame = CFrame.Angles(0, math.rad(angle), 0) * CFrame.Angles(math.rad(-50), 0, 0)
		a.Parent = ball
		local light = Instance.new("SpotLight")
		light.Color = Disco.COLORS[k]
		light.Brightness = 6
		light.Range = 40
		light.Angle = 35
		light.Face = Enum.NormalId.Front
		light.Parent = ball
	end
	local glow = Instance.new("PointLight")
	glow.Color = rgb(200, 120, 255)
	glow.Brightness = 1.5
	glow.Range = 30
	glow.Parent = ball

	-- Lasers from the four top corners, sweeping across the room
	for k, corner in
		{
			Vector3.new(R.x0 + 1, FLOOR_Y + R.h - 1, R.z0 + 1),
			Vector3.new(R.x1 - 1, FLOOR_Y + R.h - 1, R.z0 + 1),
			Vector3.new(R.x0 + 1, FLOOR_Y + R.h - 1, R.z1 - 1),
			Vector3.new(R.x1 - 1, FLOOR_Y + R.h - 1, R.z1 - 1),
		}
	do
		for n = 1, 2 do
			local laser = part({
				Name = "Laser",
				Size = Vector3.new(0.15, 0.15, 34),
				CFrame = CFrame.lookAt(corner, center - Vector3.new(0, R.h - 5, 0)) * CFrame.new(0, 0, -17),
				Color = Disco.COLORS[(k + n) % #Disco.COLORS + 1],
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Parent = model,
			})
			laser:SetAttribute("DiscoLaser", k * 2 + n)
			laser:SetAttribute("Origin", corner)
		end
		part({
			Name = "LaserBox",
			Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = CFrame.new(corner),
			Color = rgb(30, 30, 40),
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end

	-- DJ booth against the east wall, with speakers and a dragon DJ
	local booth = part({
		Name = "DJBooth",
		Size = Vector3.new(3, 3.5, 9),
		CFrame = CFrame.new(R.x1 - 3, FLOOR_Y + 1.75, (R.z0 + R.z1) / 2),
		Color = rgb(30, 28, 44),
		Parent = model,
	})
	part({
		Name = "DJLights",
		Size = Vector3.new(0.2, 0.6, 8.6),
		CFrame = booth.CFrame * CFrame.new(-1.6, 0.8, 0),
		Color = Disco.COLORS[1],
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = model,
	}):SetAttribute("DiscoTile", 99)
	for _, dz in { -7.5, 7.5 } do
		local speaker = part({
			Name = "Speaker",
			Size = Vector3.new(2.6, 6, 3),
			CFrame = CFrame.new(R.x1 - 2.5, FLOOR_Y + 3, (R.z0 + R.z1) / 2 + dz),
			Color = rgb(22, 22, 30),
			Parent = model,
		})
		for _, dy in { -1.4, 1.4 } do
			local cone = Scenery.disc(
				model,
				"SpeakerCone",
				(speaker.CFrame * CFrame.new(-1.35, dy, 0)).Position,
				1.8,
				0.2,
				rgb(70, 70, 85),
				Enum.Material.Metal
			)
			cone.CFrame = CFrame.new(cone.Position) * CFrame.Angles(0, 0, 0)
		end
	end
	local sign = part({
		Name = "DiscoSign",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = CFrame.new(R.x1 - 1, FLOOR_Y + 11, (R.z0 + R.z1) / 2),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.new(22, 0, 5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	gui.Parent = sign
	for i, line in
		{
			{ "🪩 SECRET DISCO 🪩", 0.62, rgb(255, 120, 220) },
			{ "Type /e dance and show your moves!", 0.38, rgb(150, 230, 255) },
		}
	do
		local t = Instance.new("TextLabel")
		t.Name = "Line" .. i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, line[2], 0)
		t.Position = UDim2.new(0, 0, i == 1 and 0 or 0.62, 0)
		t.Text = line[1]
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextColor3 = line[3]
		t.TextStrokeTransparency = 0
		t.Parent = gui
	end

	-- Dancing dragons (a DJ behind the booth and two on the floor)
	for k, spot in
		{
			{ "BLAZE", Vector3.new(R.x1 - 5.5, FLOOR_Y, (R.z0 + R.z1) / 2) },
			{ "FROSTY", Vector3.new(R.x0 + 9, FLOOR_Y, R.z0 + 10) },
			{ "PUFF", Vector3.new(R.x0 + 9, FLOOR_Y, R.z1 - 10) },
		}
	do
		if Dragons.byId[spot[1]] then
			local dragon = DragonBuilder.build(spot[1], nil, 2)
			dragon.Name = "DiscoDragon"
			for _, d in dragon:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			local look = k == 1 and spot[2] - Vector3.new(1, 0, 0) or Vector3.new(center.X, spot[2].Y, center.Z)
			DragonBuilder.place(dragon, CFrame.lookAt(spot[2], look))
			dragon:SetAttribute("DiscoDancer", k)
			dragon:SetAttribute("Home", dragon:GetPivot())
			dragon.Parent = model
		end
	end
	return model
end

return Disco

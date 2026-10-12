-- Builds the whole map from plain parts, in the brick style:
--   The Hub: a round platform floating in space, with the Forge in the middle, 8 glowing GO pads around the edge
--     (one per planet) and the raid portal ring over the top.
--   The 8 planets: floating islands in a ring around the Hub, each in its own colour, with rocks, crystals, a
--     HOME pad back to the Hub, and a Boss Gate at the far end leading to the boss yard.
-- Space: a dark sky with stars and far planets; players can't fall off (invisible walls).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Scenery = require(script.Parent.Scenery)
local Themes = require(script.Parent.Themes)

local part, disc, ball, rgb = Scenery.part, Scenery.disc, Scenery.ball, Scenery.rgb

local WorldBuilder = {}

WorldBuilder.HUB_RADIUS = 46
WorldBuilder.PLANET_RING = 300 -- distance from the hub to each planet's centre
WorldBuilder.PLANET_RADIUS = 58
WorldBuilder.BOSS_YARD = 40 -- the boss yard disc, past the boss gate
WorldBuilder.PAD_RADIUS = 5
WorldBuilder.WING_Z = 118 -- the Trade Plaza (north) and Booth Street (south) wings
WorldBuilder.WING_RADIUS = 40
WorldBuilder.ARENA_Y = 140 -- the raid arena floats high over the hub
WorldBuilder.ARENA_RADIUS = 64
WorldBuilder.STALLS = 12
WorldBuilder.BOOTHS = 16

local INK = rgb(30, 30, 44)
local HUB_COLOR = rgb(70, 75, 110)
local HUB_TRIM = rgb(255, 205, 60)

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Where planet i sits (a ring around the hub, starting east and going round)
function WorldBuilder.planetCenter(i)
	local a = (i - 1) / #Planets.list * math.pi * 2
	return Vector3.new(math.cos(a) * WorldBuilder.PLANET_RING, 0, math.sin(a) * WorldBuilder.PLANET_RING)
end

-- A glowing pad on the floor with a sign: stepping on it does something (PlanetService watches positions).
local function pad(parent, name, center, color, lines, extra)
	local p = Scenery.ring(parent, name, center + Vector3.new(0, 0.25, 0), WorldBuilder.PAD_RADIUS * 2, color, extra)
	disc(parent, name .. "Base", center + Vector3.new(0, 0.1, 0), WorldBuilder.PAD_RADIUS * 2 + 1.5, 0.2, INK)
	-- a pixel-sized label, so it never fills the screen when you stand on the pad
	local gui, labels = Scenery.sign(p, 10, 3.5, Vector3.new(0, 4.5, 0), lines, 90)
	gui.Size = UDim2.fromOffset(150, 52)
	return p, labels
end

local function lighting()
	Lighting.ClockTime = 0 -- night: space
	Lighting.Brightness = 2
	Lighting.Ambient = rgb(70, 70, 95)
	Lighting.OutdoorAmbient = rgb(90, 90, 120)
	Lighting.FogEnd = 1200
	Lighting.FogColor = rgb(12, 10, 30)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 4000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
end

local function hub(map, rng)
	local model = Instance.new("Model")
	model.Name = "Hub"
	model.Parent = map
	local R = WorldBuilder.HUB_RADIUS
	disc(model, "Floor", Vector3.new(0, -1, 0), R * 2, 2, HUB_COLOR, Enum.Material.Plastic)
	disc(model, "Under", Vector3.new(0, -4, 0), R * 1.7, 4, HUB_COLOR:Lerp(INK, 0.4))
	disc(model, "Under2", Vector3.new(0, -9, 0), R * 1.1, 6, HUB_COLOR:Lerp(INK, 0.6))
	-- gold edge ring and lamp posts
	Scenery.ring(model, "Edge", Vector3.new(0, 0.05, 0), R * 2 - 1, HUB_TRIM, { Transparency = 0.2 })
	disc(model, "EdgeHole", Vector3.new(0, 0.06, 0), R * 2 - 4, 0.32, HUB_COLOR, Enum.Material.Plastic)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local p = Vector3.new(math.cos(a) * (R - 3), 0, math.sin(a) * (R - 3))
		part({
			Name = "Post",
			Size = Vector3.new(0.7, 7, 0.7),
			CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)),
			Color = INK,
			Parent = model,
		})
		ball(
			model,
			"Lamp",
			p + Vector3.new(0, 7.6, 0),
			1.6,
			rgb(255, 240, 180),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	end
	-- the Forge in the middle: a stone anvil block, a chimney, a fire bowl and a big sign
	local forge = Instance.new("Model")
	forge.Name = "Forge"
	forge.Parent = model
	part({
		Name = "Base",
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = rgb(90, 90, 110),
		Parent = forge,
	})
	part({
		Name = "Anvil",
		Size = Vector3.new(6, 3, 4),
		CFrame = CFrame.new(0, 2.5, 0),
		Color = rgb(60, 62, 80),
		Material = Enum.Material.Metal,
		Parent = forge,
	})
	part({
		Name = "Chimney",
		Size = Vector3.new(3, 10, 3),
		CFrame = CFrame.new(0, 6, 4.5),
		Color = rgb(110, 70, 60),
		Parent = forge,
	})
	local fire = part({
		Name = "FireBowl",
		Size = Vector3.new(4, 1.2, 4),
		CFrame = CFrame.new(0, 4.6, 0),
		Color = rgb(255, 120, 30),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = forge,
	})
	local f = Instance.new("Fire")
	f.Size = 6
	f.Heat = 8
	f.Parent = fire
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 150, 60)
	light.Range = 30
	light.Brightness = 2
	light.Parent = fire
	Scenery.sign(fire, 18, 4, Vector3.new(0, 8, 0), {
		{ text = "⚒️ FORGE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 200, 60) },
		{ text = "Put ore in. Get a blaster!", h = 0.4, y = 0.6 },
	}, 120)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt_forge"
	prompt.ActionText = "Open the Forge"
	prompt.ObjectText = "FORGE"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = fire
	-- GO pads around the edge, one per planet, facing their planet
	local goPads = {}
	for i, planet in Planets.list do
		local dir = WorldBuilder.planetCenter(i).Unit
		local center = dir * (R - 12)
		local p, labels = pad(model, "GoPad" .. i, center, planet.color, {
			{
				text = `{planet.emoji} GO: {planet.name}`,
				h = 0.55,
				y = 0,
				font = Enum.Font.LuckiestGuy,
				color = planet.color,
			},
			{ text = "🔒 Beat the boss before", h = 0.45, y = 0.55, color = rgb(230, 230, 240) },
		})
		p:SetAttribute("Planet", planet.key)
		goPads[i] = { part = p, labels = labels, center = center, planet = planet }
	end
	-- the raid portal: a ring over the hub that turns slowly; when the raid opens it glows and a beam comes down
	-- to the RAID pad (RaidService). Jumping into the pad takes you to the arena.
	local ring = disc(model, "PortalRing", Vector3.new(0, 30, 0), 22, 1.5, rgb(140, 90, 255), Enum.Material.Neon, {
		CanCollide = false,
		Transparency = 0.45,
	})
	ring:SetAttribute("TurnSpeed", 0.4)
	CollectionService:AddTag(ring, "Turn")
	local beam = part({
		Name = "PortalBeam",
		Size = Vector3.new(6, 30, 6),
		CFrame = CFrame.new(0, 15, 0),
		Color = rgb(170, 120, 255),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local raidPad = Scenery.ring(model, "RaidPad", Vector3.new(0, 7.2, 0), 10, rgb(170, 120, 255), { Transparency = 1 })
	Scenery.sign(raidPad, 12, 3.5, Vector3.new(0, 5, 0), {
		{ text = "☄️ RAID", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(200, 160, 255) },
		{ text = "Jump in!", h = 0.4, y = 0.6 },
	}, 80).Enabled =
		false
	-- the big title over the forge and a gallery of planet orbs on pedestals around it
	local titlePost = part({
		Name = "TitlePost",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 22, -8),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	Scenery.sign(titlePost, 40, 8, Vector3.new(0, 0, 0), {
		{ text = "☄️ RAID A PLANET", h = 0.62, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 60) },
		{ text = "Blast bugs. Forge blasters. Beat the boss.", h = 0.38, y = 0.62 },
	}, 220)
	for i, planet in Planets.list do
		local a = (i - 0.5) / #Planets.list * math.pi * 2
		local p = Vector3.new(math.cos(a) * 22, 0, math.sin(a) * 22)
		_ = planet.key
		part({
			Name = "Pedestal",
			Size = Vector3.new(2.5, 3, 2.5),
			CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0)),
			Color = HUB_COLOR:Lerp(INK, 0.3),
			Parent = model,
		})
		local orb =
			ball(model, "Orb", p + Vector3.new(0, 5, 0), 3, planet.color, Enum.Material.Neon, { CanCollide = false })
		orb:SetAttribute("TurnSpeed", 0.8)
		orb:SetAttribute("Bob", 0.4)
		CollectionService:AddTag(orb, "Turn")
		local orbLight = Instance.new("PointLight")
		orbLight.Color = planet.color
		orbLight.Range = 9
		orbLight.Parent = orb
	end
	-- the two wings: Trade Plaza (north) and Booth Street (south), each on its own disc with a bridge
	local stalls, booths = {}, {}
	for _, side in { -1, 1 } do
		local wz = side * WorldBuilder.WING_Z
		local wr = WorldBuilder.WING_RADIUS
		local wing = Instance.new("Model")
		wing.Name = side < 0 and "TradePlaza" or "BoothStreet"
		wing.Parent = model
		local wcolor = side < 0 and rgb(60, 90, 120) or rgb(110, 70, 110)
		disc(wing, "Floor", Vector3.new(0, -1, wz), wr * 2, 2, wcolor, Enum.Material.Plastic)
		disc(wing, "Under", Vector3.new(0, -5, wz), wr * 1.6, 6, wcolor:Lerp(INK, 0.5))
		part({
			Name = "Bridge",
			Size = Vector3.new(10, 1, WorldBuilder.WING_Z - wr - R + 4),
			CFrame = CFrame.new(0, -0.5, side * (R + (WorldBuilder.WING_Z - wr - R) / 2)),
			Color = HUB_COLOR,
			Parent = wing,
		})
		for _, bx in { -5.5, 5.5 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.5, 2, WorldBuilder.WING_Z - wr - R + 4),
				CFrame = CFrame.new(bx, 0.8, side * (R + (WorldBuilder.WING_Z - wr - R) / 2)),
				Color = HUB_TRIM,
				Parent = wing,
			})
		end
		local post = part({
			Name = "WingSignPost",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(0, 16, wz),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Parent = wing,
		})
		Scenery.sign(post, 30, 6, Vector3.new(0, 0, 0), side < 0 and {
			{ text = "🏪 TRADE PLAZA", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(120, 220, 255) },
			{ text = "Sell blasters for gems. Buy with gems.", h = 0.4, y = 0.6 },
		} or {
			{ text = "🛍️ BOOTH STREET", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 150, 220) },
			{ text = "Show your own clothes. Others can buy them!", h = 0.4, y = 0.6 },
		}, 200)
		local count = side < 0 and WorldBuilder.STALLS or WorldBuilder.BOOTHS
		for i = 1, count do
			local a = (i - 0.5) / count * math.pi * 2
			local center = Vector3.new(math.cos(a) * (wr - 9), 0, wz + math.sin(a) * (wr - 9))
			local cf = CFrame.lookAt(center, Vector3.new(0, 0, wz))
			local stand = Instance.new("Model")
			stand.Name = (side < 0 and "Stall" or "Booth") .. i
			stand.Parent = wing
			part({
				Name = "Counter",
				Size = Vector3.new(7, 2.6, 2.5),
				CFrame = cf * CFrame.new(0, 1.3, 0),
				Color = side < 0 and rgb(90, 140, 200) or rgb(200, 110, 170),
				Parent = stand,
			})
			part({
				Name = "Top",
				Size = Vector3.new(7.4, 0.4, 2.9),
				CFrame = cf * CFrame.new(0, 2.8, 0),
				Color = HUB_TRIM,
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
				Color = side < 0 and rgb(120, 200, 255) or rgb(255, 170, 220),
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
				{
					text = side < 0 and "EMPTY STALL" or "EMPTY BOOTH",
					h = 0.4,
					y = 0,
					font = Enum.Font.LuckiestGuy,
					color = rgb(220, 220, 230),
				},
				{ text = side < 0 and "Put a blaster here" or "Claim it: show your clothes", h = 0.3, y = 0.4 },
				{ text = "", h = 0.3, y = 0.7, color = rgb(150, 230, 255) },
			}, 70)
			local standPrompt = Instance.new("ProximityPrompt")
			standPrompt.Name = side < 0 and "Prompt_stall" or "Prompt_booth"
			standPrompt.ActionText = side < 0 and "Use stall" or "Use booth"
			standPrompt.ObjectText = stand.Name
			standPrompt.HoldDuration = 0
			standPrompt.MaxActivationDistance = 9
			standPrompt.RequiresLineOfSight = false
			standPrompt.Parent = stand.Counter
			local entry = { index = i, model = stand, cf = cf, show = show, lines = lines, prompt = standPrompt }
			if side < 0 then
				stalls[i] = entry
			else
				booths[i] = entry
			end
		end
	end
	-- the raid arena: a big disc high over the hub with four shield plates and an invisible wall
	local arena = Instance.new("Model")
	arena.Name = "Arena"
	arena.Parent = model
	local ay, ar = WorldBuilder.ARENA_Y, WorldBuilder.ARENA_RADIUS
	disc(arena, "Floor", Vector3.new(0, ay - 1, 0), ar * 2, 2, rgb(50, 40, 80), Enum.Material.Plastic)
	disc(arena, "Under", Vector3.new(0, ay - 5, 0), ar * 1.6, 6, rgb(35, 28, 60))
	Scenery.ring(arena, "Edge", Vector3.new(0, ay + 0.05, 0), ar * 2 - 2, rgb(170, 120, 255), { Transparency = 0.3 })
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local p = Vector3.new(math.cos(a) * (ar + 1), ay + 10, math.sin(a) * (ar + 1))
		part({
			Name = "Wall",
			Size = Vector3.new(ar * 2 * math.pi / 24 + 1, 22, 1),
			CFrame = CFrame.lookAt(p, Vector3.new(0, ay + 10, 0)),
			Transparency = 1,
			CanQuery = false,
			Parent = arena,
		})
	end
	local plates = {}
	for k = 1, 4 do
		local a = (k - 0.5) / 4 * math.pi * 2
		local p = Vector3.new(math.cos(a) * (ar - 14), ay, math.sin(a) * (ar - 14))
		local plate = Scenery.ring(
			arena,
			"Plate" .. k,
			p + Vector3.new(0, 0.25, 0),
			11,
			rgb(120, 120, 140),
			{ Transparency = 0.6 }
		)
		disc(arena, "PlateBase", p + Vector3.new(0, 0.1, 0), 12.5, 0.2, INK)
		local _, plateLines = Scenery.sign(plate, 10, 3, Vector3.new(0, 4, 0), {
			{ text = `PLATE {k}`, h = 0.55, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(220, 220, 240) },
			{ text = "", h = 0.45, y = 0.55 },
		}, 100)
		plates[k] = { part = plate, center = p, lines = plateLines }
	end
	local arenaSpawn = Vector3.new(0, ay, ar - 12)
	local exitPad = pad(arena, "ExitPad", Vector3.new(0, ay, ar - 6), HUB_TRIM, {
		{ text = "🏠 LEAVE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = HUB_TRIM },
		{ text = "back to the Hub", h = 0.4, y = 0.6 },
	})
	local boardPost = part({
		Name = "SkyBoardPost",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 48, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	-- spawn: on the east side, facing the forge
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.CFrame = CFrame.new(0, 0.2, 22)
	spawn.Color = HUB_COLOR:Lerp(HUB_TRIM, 0.3)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model
	-- stars and far planets all around
	local sky = folder("Sky", map)
	for _ = 1, 160 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude > 0.1 then
			Scenery.star(sky, dir.Unit * rng:NextNumber(700, 1000), rng:NextNumber(2, 6))
		end
	end
	Scenery.farPlanet(sky, Vector3.new(-600, 220, -500), 140, rgb(255, 150, 90), true)
	Scenery.farPlanet(sky, Vector3.new(650, 140, 400), 90, rgb(120, 180, 255), false)
	Scenery.farPlanet(sky, Vector3.new(100, 320, 800), 60, rgb(200, 120, 255), true)
	return {
		model = model,
		goPads = goPads,
		forge = fire,
		spawn = spawn,
		ring = ring,
		beam = beam,
		raidPad = raidPad,
		stalls = stalls,
		booths = booths,
		arena = {
			model = arena,
			center = Vector3.new(0, ay, 0),
			radius = ar,
			plates = plates,
			spawn = arenaSpawn,
			exitPad = exitPad,
			exitCenter = Vector3.new(0, ay, ar - 6),
		},
		skyBoardPost = boardPost,
	}
end

-- One planet island. Returns its layout: centre, the spawn point (near the HOME pad), the boss gate and yard.
local function planetIsland(map, i, planet, rng)
	local center = WorldBuilder.planetCenter(i)
	local R = WorldBuilder.PLANET_RADIUS
	local model = Instance.new("Model")
	model.Name = "Planet_" .. planet.key
	model.Parent = map
	-- the island: a coloured disc with darker rock underneath
	disc(
		model,
		"Floor",
		center + Vector3.new(0, -1, 0),
		R * 2,
		2,
		planet.color:Lerp(rgb(255, 255, 255), 0.1),
		Enum.Material.Plastic
	)
	disc(model, "Under", center + Vector3.new(0, -5, 0), R * 1.8, 6, planet.dark)
	disc(model, "Under2", center + Vector3.new(0, -12, 0), R * 1.2, 8, planet.dark:Lerp(INK, 0.5))
	-- an invisible wall so nobody falls into space
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * (R + 1), 8, math.sin(a) * (R + 1))
		part({
			Name = "Wall",
			Size = Vector3.new(R * 2 * math.pi / 24 + 1, 18, 1),
			CFrame = CFrame.lookAt(p, center + Vector3.new(0, 8, 0)),
			Transparency = 1,
			CanQuery = false,
			Parent = model,
		})
	end
	-- the direction back toward the hub: the HOME pad and the arrival spot are on that side
	local toHub = (Vector3.zero - center).Unit
	local homeCenter = center + toHub * (R - 10)
	local homePad = pad(model, "HomePad", homeCenter, HUB_TRIM, {
		{ text = "🏠 HOME", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = HUB_TRIM },
		{ text = "back to the Hub", h = 0.4, y = 0.6 },
	})
	local arrive = homeCenter - toHub * 12
	-- the Boss Gate on the far side: two pillars and a glowing bar; the yard is a smaller disc beyond
	local gateCenter = center - toHub * (R - 6)
	local gateCf = CFrame.lookAt(gateCenter, center)
	for _, side in { -1, 1 } do
		part({
			Name = "GatePillar",
			Size = Vector3.new(2.5, 12, 2.5),
			CFrame = gateCf * CFrame.new(side * 6, 6, 0),
			Color = planet.dark,
			Parent = model,
		})
	end
	local gateBar = part({
		Name = "GateBar",
		Size = Vector3.new(14.5, 2, 2),
		CFrame = gateCf * CFrame.new(0, 12.5, 0),
		Color = planet.color,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	Scenery.sign(gateBar, 16, 4, Vector3.new(0, 3.5, 0), {
		{ text = "👑 BOSS GATE", h = 0.6, y = 0, font = Enum.Font.LuckiestGuy, color = rgb(255, 215, 60) },
		{ text = `Walk in to fight the {planet.boss}`, h = 0.4, y = 0.6 },
	}, 110)
	local yardCenter = gateCenter - toHub * (WorldBuilder.BOSS_YARD + 2)
	disc(
		model,
		"Yard",
		yardCenter + Vector3.new(0, -1, 0),
		WorldBuilder.BOSS_YARD * 2,
		2,
		planet.dark:Lerp(rgb(255, 255, 255), 0.15),
		Enum.Material.Plastic
	)
	disc(model, "YardUnder", yardCenter + Vector3.new(0, -5, 0), WorldBuilder.BOSS_YARD * 1.7, 6, planet.dark)
	Scenery.ring(
		model,
		"YardRing",
		yardCenter + Vector3.new(0, 0.05, 0),
		WorldBuilder.BOSS_YARD * 2 - 2,
		planet.color,
		{ Transparency = 0.3 }
	)
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2
		local p = yardCenter
			+ Vector3.new(math.cos(a) * (WorldBuilder.BOSS_YARD + 1), 8, math.sin(a) * (WorldBuilder.BOSS_YARD + 1))
		part({
			Name = "Wall",
			Size = Vector3.new(WorldBuilder.BOSS_YARD * 2 * math.pi / 18 + 1, 18, 1),
			CFrame = CFrame.lookAt(p, yardCenter + Vector3.new(0, 8, 0)),
			Transparency = 1,
			CanQuery = false,
			Parent = model,
		})
	end
	-- a bridge from the island to the yard, under the gate
	part({
		Name = "Bridge",
		Size = Vector3.new(12, 1, 16),
		CFrame = CFrame.lookAt(gateCenter - toHub * 4, yardCenter) * CFrame.new(0, -0.5, 0),
		Color = planet.dark,
		Parent = model,
	})
	-- scenery: rocks and crystals, away from the pads, the gate and the middle
	local deco = folder("Decor", model)
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(18, R - 8)
		local p = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		if (p - homeCenter).Magnitude > 14 and (p - gateCenter).Magnitude > 14 then
			local theme = Themes.scenery[planet.key]
			if theme then
				theme(deco, p, planet, rng)
			else
				Scenery.rock(deco, p, rng:NextNumber(3, 6), planet.dark, rng)
			end
		end
	end
	-- the planet's name over the middle
	local namePost = part({
		Name = "NamePost",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 16, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	Scenery.sign(namePost, 24, 5, Vector3.new(0, 0, 0), {
		{
			text = `{planet.emoji} {string.upper(planet.name)}`,
			h = 0.6,
			y = 0,
			font = Enum.Font.LuckiestGuy,
			color = planet.color,
		},
		{ text = `Blast {planet.bug}s for {planet.ore}`, h = 0.4, y = 0.6 },
	}, 130)
	return {
		planet = planet,
		model = model,
		center = center,
		radius = R,
		arrive = arrive,
		homePad = homePad,
		homeCenter = homeCenter,
		gateCf = gateCf,
		gateCenter = gateCenter,
		yardCenter = yardCenter,
		bossHome = yardCenter - toHub * (WorldBuilder.BOSS_YARD - 12),
		toHub = toHub,
	}
end

function WorldBuilder.build()
	lighting()
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or (child:IsA("SpawnLocation") and child.Name == "SpawnLocation") then
			child:Destroy()
		end
	end
	local rng = Random.new(7)
	local map = folder("Map", workspace)
	-- a big dark floor far below, so a fall never lasts for ever (a player who falls is sent home anyway)
	part({
		Name = "Void",
		Size = Vector3.new(2000, 2, 2000),
		CFrame = CFrame.new(0, -120, 0),
		Color = rgb(10, 8, 24),
		Transparency = 0.4,
		Parent = map,
	})
	local h = hub(map, rng)
	local planets = {}
	for i, planet in Planets.list do
		planets[i] = planetIsland(map, i, planet, rng)
	end
	folder("Mobs", workspace)
	folder("Fx", workspace)
	WorldBuilder.layout = {
		hub = h,
		planets = planets,
		spawn = h.spawn,
		arena = h.arena,
		stalls = h.stalls,
		booths = h.booths,
	}
	return WorldBuilder.layout
end

-- Which planet a position is on (nil in the hub or in space).
function WorldBuilder.planetAt(pos)
	for _, pl in WorldBuilder.layout.planets do
		local d = Vector3.new(pos.X - pl.center.X, 0, pos.Z - pl.center.Z).Magnitude
		if d <= pl.radius + 2 then
			return pl, false
		end
		local dy = Vector3.new(pos.X - pl.yardCenter.X, 0, pos.Z - pl.yardCenter.Z).Magnitude
		if dy <= WorldBuilder.BOSS_YARD + 2 then
			return pl, true
		end
		-- the bridge between them
		local mid = (pl.gateCenter + pl.yardCenter) / 2
		if Vector3.new(pos.X - mid.X, 0, pos.Z - mid.Z).Magnitude <= 12 then
			return pl, true
		end
	end
	return nil, false
end

function WorldBuilder.inHub(pos)
	return Vector3.new(pos.X, 0, pos.Z).Magnitude <= WorldBuilder.HUB_RADIUS + 2 and pos.Y < 40
end

function WorldBuilder.inArena(pos)
	return pos.Y > WorldBuilder.ARENA_Y - 10 and Vector3.new(pos.X, 0, pos.Z).Magnitude <= WorldBuilder.ARENA_RADIUS + 2
end

return WorldBuilder

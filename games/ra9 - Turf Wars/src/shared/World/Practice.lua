--[[
The private practice arena: where a brand-new player's tutorial plays (TutorialService decides and keeps the score,
TutorialController draws it and runs the show). A small field of its own, far out past the match's world (each
player in one at the same time gets their own slot along Z), with the same rules as the real arena: red at -X,
blue at +X, turf strips coloured by the frontline, a spawn deck at each end.

The look is the real maps' (World/ArenaBuilder's shapes, SUPERHOT: white and greys, the teams' colours, no browns):
walls with a plinth, a string course and a crown molding under the coping, columns in bays, recessed panels, tall
windows, banners, lamps, the gate framed by piers under a crested lintel, statues on the decks, towers at the corners
and a skyline beyond; a few hundred parts (it's drawn on every phone that plays it), all of it looks only, out of the
field's lanes and the steps' lines of fire.

Private by construction: the server only puts down an invisible floor and walls there (Practice.collider: a body
stands on something even before its client has drawn the place); everything you see (the turf, the walls, the
line, the bots, the walls you build) is made on that player's own client (Practice.build), so nobody else is sent
a single part of it, and nobody in the match can see or reach it.

Sized for the show: seven knockouts (Practice.KILLS), each moving the line Practice.PUSH studs, take the line from
the middle to the enemy's lose line (Practice.EDGE).

  Practice.origin(slot)              the middle of a slot's field, on the floor (y = 0, like every arena)
  Practice.spawn(origin, team)       where you stand at the start: just behind the line, facing it
  Practice.inside(origin, pos)       inside its walls
  Practice.collider(origin, parent)  the server's invisible floor and walls -> Folder
  Practice.build(origin, team, parent)  the look (a client's own) -> world { folder, strips, marker, glow, origin }
  Practice.paint(world, frontline, team)  recolour the turf for the line, move the glowing line onto it
]]
local Constants = require(script.Parent.Parent.Constants)
local Formulas = require(script.Parent.Parent.Formulas)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

local Practice = {}

local CELL = Constants.CELL
Practice.KILLS = 7 -- knockouts in the whole show: the last one wins it
Practice.PUSH = 2 * CELL -- studs each knockout moves the line
Practice.EDGE = Practice.KILLS * Practice.PUSH -- the lose lines at -EDGE and +EDGE
Practice.DEPTH = 12 -- each spawn deck
Practice.HALF = Practice.EDGE + Practice.DEPTH
Practice.WIDTH = 48
Practice.WALL = 14 -- the walls' height (an invisible shell above, to CEILING)
Practice.CEILING = 44
Practice.Z0 = 3200 -- the first slot's middle along Z (the match's world ends well inside 600)
Practice.GAP = 400 -- between slots
Practice.START = 4 -- studs behind the line where you stand at the start

function Practice.origin(slot)
	return Vector3.new(0, 0, Practice.Z0 + (math.max(1, slot) - 1) * Practice.GAP)
end

function Practice.spawn(origin, team)
	local f = Formulas.forward(team)
	local p = Vector3.new(-f * Practice.START, 3, origin.Z)
	return CFrame.lookAt(p, p + Vector3.new(f, 0, 0))
end

function Practice.inside(origin, pos, margin)
	margin = margin or 0
	return math.abs(pos.X) <= Practice.HALF + margin
		and math.abs(pos.Z - origin.Z) <= Practice.WIDTH / 2 + margin
		and pos.Y > -8
end

-- (one invisible, solid box)
local function solid(name, cf, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CastShadow = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

function Practice.collider(origin, parent)
	local folder = Instance.new("Folder")
	folder.Name = "PracticeFloor"
	local L, W, H = Practice.HALF * 2, Practice.WIDTH, Practice.CEILING
	solid("Floor", CFrame.new(origin + Vector3.new(0, -1, 0)), Vector3.new(L + 8, 2, W + 8), folder)
	for _, s in { -1, 1 } do
		solid("Side", CFrame.new(origin + Vector3.new(0, H / 2, s * (W / 2 + 2))), Vector3.new(L + 8, H, 4), folder)
		solid("End", CFrame.new(origin + Vector3.new(s * (L / 2 + 2), H / 2, 0)), Vector3.new(4, H, W + 8), folder)
	end
	folder.Parent = parent
	return folder
end

function Practice.build(origin, team, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Practice"
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = folder
	local Z, W, half = origin.Z, Practice.WIDTH, Practice.HALF
	local shapes = setmetatable({
		folder = map,
		solids = {},
		collide = {},
		white = Constants.WHITE,
		light = Constants.LIGHT,
		grey = Constants.GREY,
		dark = Constants.DARK,
	}, ArenaBuilder.Shapes)
	local deco = ArenaBuilder.deco
	local H = Practice.WALL
	local function trim(color, name)
		return deco({ color = color, name = name or "Trim" })
	end
	local function neon(color, name)
		return deco({ color = color, material = Enum.Material.Neon, name = name })
	end

	-- the turf: a strip per cell along X
	local turf = Instance.new("Folder")
	turf.Name = "Turf"
	turf.Parent = folder
	local strips = {}
	for i = 1, math.floor(half * 2 / CELL) do
		local p = Instance.new("Part")
		p.Name = "Strip" .. i
		p.Anchored = true
		p.Size = Vector3.new(CELL, 2, W)
		p.CFrame = CFrame.new(-half + (i - 0.5) * CELL, -1, Z)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Color = Constants.WHITE
		p.Parent = turf
		strips[i] = p
	end
	-- the pale ground out past the walls, so the world never ends at them, and a skyline of plain blocks in the haze
	shapes:block(0, Z, half * 2 + 500, W + 500, 1, deco({ color = shapes.light, shadow = false }), -3)
	local r = Random.new(97)
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2 + r:NextNumber(-0.08, 0.08)
		local x, z = math.cos(a) * (half + r:NextNumber(50, 110)), Z + math.sin(a) * (W / 2 + r:NextNumber(50, 110))
		local w, d, h = r:NextNumber(12, 28), r:NextNumber(12, 28), r:NextNumber(24, 64)
		local c = (i % 3 == 0) and shapes.light or ((i % 3 == 1) and shapes.white or shapes.grey)
		shapes:block(x, z, w, d, h, deco({ color = c, shadow = false, name = "Skyline" }), -2)
		if i % 2 == 0 then
			shapes:block(x, z, w * 0.6, d * 0.6, h * 0.2, deco({ color = shapes.white, shadow = false }), h - 2)
		end
	end

	-- the long walls (z = Z +- W/2 on their inner face): a plinth with a base molding, a string course, a crown molding
	-- of two steps under the coping; free-standing columns in bays, a recessed panel low in each bay and a tall window
	-- over the string course (a banner in each half's colour in the two middle bays), a lamp each side of the line.
	-- All of it looks only (nothing stops an arrow or a builder), and none of it stands in the field's lanes.
	for _, s in { -1, 1 } do
		local face = Z + s * W / 2
		shapes:block(0, Z + s * (W / 2 + 1), half * 2 + 4, 2, H, { color = shapes.light, name = "Wall" })
		shapes:block(0, face - s * 0.4, half * 2, 0.8, 1, trim(shapes.grey, "Plinth"))
		shapes:block(0, face - s * 0.3, half * 2, 0.6, 0.35, trim(shapes.white, "Molding"), 1)
		shapes:block(0, face - s * 0.3, half * 2, 0.6, 0.5, trim(shapes.white, "Molding"), 6)
		shapes:block(0, face - s * 0.3, half * 2, 0.6, 0.5, trim(shapes.light, "Molding"), H - 2)
		shapes:block(0, face - s * 0.55, half * 2, 1.1, 0.7, trim(shapes.white, "Molding"), H - 1.5)
		shapes:block(0, Z + s * (W / 2 + 1), half * 2 + 6, 2.6, 0.8, trim(shapes.white, "Molding"), H)
		shapes:block(0, Z + s * (W / 2 + 1), half * 2 + 4, 2, Practice.CEILING - H, {
			transparency = 1,
			shadow = false,
			name = "Shell",
		}, H)
		for _, x in { -40, -16, 16, 40 } do
			shapes:column(x, face - s * 2.2, H - 2, 1)
		end
		for _, x in { -52, -28, 0, 28, 52 } do
			local pw = math.abs(x) == 52 and 12 or 14
			-- the panel: a white frame, a grey inset, a light field
			shapes:block(x, face - s * 0.15, pw, 0.3, 3.8, trim(shapes.white, "Panel"), 1.6)
			shapes:block(x, face - s * 0.3, pw - 1.6, 0.3, 2.8, trim(shapes.grey), 2.1)
			shapes:block(x, face - s * 0.45, pw - 2.6, 0.3, 2, trim(shapes.light), 2.5)
			if math.abs(x) == 28 then
				shapes:banner(x, face, x < 0 and -1 or 1, -s, 6.7, 5)
			else
				-- the window: a white frame, the dark glass, a mullion
				shapes:block(x, face - s * 0.2, 6, 0.4, 5, trim(shapes.white, "Window"), 7)
				shapes:block(x, face - s * 0.35, 4.6, 0.4, 4.2, trim(shapes.dark), 7.4)
				shapes:block(x, face - s * 0.45, 0.4, 0.4, 4.2, trim(shapes.white), 7.4)
			end
		end
		for _, x in { -9.5, 9.5 } do
			local lz = face - s * 1.6
			shapes:block(x, lz, 1.4, 1.4, 0.6, deco({ color = shapes.light, collide = true }))
			shapes:block(x, lz, 0.5, 0.5, 7, deco({ color = shapes.white, collide = true }), 0.6)
			shapes:block(x, lz, 1.2, 1.2, 0.3, trim(shapes.light), 7.6)
			shapes:block(x, lz, 0.9, 0.9, 0.9, neon(Color3.new(1, 1, 1), "Lamp"), 7.9)
			shapes:block(x, lz, 1.3, 1.3, 0.25, trim(shapes.light), 8.8)
		end
	end

	-- each base: a deck, its spawn line, pads with a white ring, and the end wall: a plinth and a crown molding, a pier
	-- each side, and the gate (piers on plinths with capitals, a lintel under a cornice and the team's crest, its colour
	-- glowing in the opening); an archer's statue in each corner of the deck, looking out; a tower outside each corner
	for _, t in Constants.TEAMS do
		local s = t == "red" and -1 or 1
		local color = Constants.TEAM_COLOR[t]
		local zoneX = s * (half - Practice.DEPTH / 2)
		local function X(d)
			return s * (half - d)
		end
		shapes:block(s * (half + 1), Z, 2, W + 4, H, { color = shapes.light, name = "Wall" })
		shapes:block(s * (half + 1), Z, 2.6, W + 6, 0.8, trim(shapes.white, "Molding"), H)
		shapes:block(X(0.4), Z, 0.8, W, 1, trim(shapes.grey, "Plinth"))
		shapes:block(X(0.3), Z, 0.6, W, 0.5, trim(shapes.white, "Molding"), 6)
		shapes:block(X(0.55), Z, 1.1, W, 0.7, trim(shapes.white, "Molding"), H - 1.5)
		shapes:block(X(0.1), Z, 0.2, W, 0.5, neon(color), H - 3.2)
		shapes:block(zoneX, Z, Practice.DEPTH, W - 2, 0.2, deco({ color = shapes.light }), 0)
		shapes:block(s * Practice.EDGE, Z, 0.6, W, 0.25, neon(color))
		for _, dz in { -12, 0, 12 } do
			shapes:block(X(5), Z + dz, 4.5, 4.5, 0.3, neon(color))
			shapes:block(X(5), Z + dz, 5.6, 5.6, 0.15, trim(shapes.white, "PadRing"))
		end
		for _, dz in { -1, 1 } do
			-- a pier on the end wall, and the gate's piers
			shapes:block(X(0.75), Z + dz * 17, 1.5, 2.4, H, { color = shapes.white })
			shapes:block(X(0.9), Z + dz * 17, 1.8, 3, 0.8, trim(shapes.light, "Capital"), H - 2.6)
			shapes:block(X(0.5), Z + dz * 6, 4, 4, 1, trim(shapes.light, "Plinth"))
			shapes:block(X(0.5), Z + dz * 6, 3, 3, H + 3, { color = shapes.white })
			shapes:block(X(0.5), Z + dz * 6, 3.8, 3.8, 0.8, trim(shapes.light, "Capital"), H - 1.5)
		end
		shapes:block(X(0.5), Z, 3, 12, 3, { color = shapes.white }, H)
		shapes:block(X(0.5), Z, 3.6, 13, 0.6, trim(shapes.light, "Molding"), H + 3)
		shapes:box(
			CFrame.new(X(1.9), H + 1.5, Z) * CFrame.Angles(math.rad(45), 0, 0),
			Vector3.new(0.6, 1.8, 1.8),
			deco({ color = color, name = "Crest" })
		)
		shapes:block(X(0.1), Z, 0.2, 9.4, H - 0.3, trim(shapes.light, "GateFrame"))
		shapes:block(X(0.35), Z, 0.3, 8, H - 1, neon(color, "Gate"))
		for _, dz in { -1, 1 } do
			shapes:statue(X(4), Z + dz * 19, -s, 0.62, s)
			local tz = Z + dz * (W / 2 + 3)
			shapes:tower(s * (half + 3), tz, 6, 6, 20, { floor = 7 })
		end
	end
	-- a little cover on each side (crates), mirrored, out of the lanes the bots walk
	shapes:crates(-30, Z + 16, 3, 10)
	shapes:crates(30, Z - 16, 3, 190)

	-- the frontline: a bright line on the floor and its soft glow
	local function line(name, w, h, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.new(1, 1, 1)
		p.Transparency = transparency
		p.Size = Vector3.new(w, h, W)
		p.CFrame = CFrame.new(0, h / 2 + 0.02, Z)
		p.Parent = folder
		return p
	end
	local world = {
		folder = folder,
		strips = strips,
		marker = line("Frontline", 1.2, 0.32, 0),
		glow = line("FrontlineGlow", 2.2, 0.06, 0.65),
		origin = origin,
		team = team,
	}
	folder.Parent = parent
	Practice.paint(world, 0)
	return world
end

function Practice.paint(world, frontline, team)
	for i, strip in world.strips do
		local x = -Practice.HALF + (i - 0.5) * CELL
		local base = Constants.TURF_COLOR[Formulas.sideOf(x, frontline)]
		strip.Color = (i % 2 == 0) and base:Lerp(Color3.new(1, 1, 1), 0.12) or base
	end
	local color = Constants.TEAM_COLOR[team or ""] or Color3.new(1, 1, 1)
	for _, p in { world.marker, world.glow } do
		p.CFrame = CFrame.new(frontline, p.Size.Y / 2 + 0.02, world.origin.Z)
		p.Color = color
	end
end

return Practice

--[[
The private practice arena: where a brand-new player's tutorial plays (TutorialService decides and keeps the score,
TutorialController draws it and runs the show). A small field of its own, far out past the match's world (each
player in one at the same time gets their own slot along Z), with the same rules as the real arena: red at -X,
blue at +X, turf strips coloured by the frontline, a spawn deck at each end.

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
	-- the pale ground out past the walls, so the world never ends at them
	shapes:block(0, Z, half * 2 + 500, W + 500, 1, deco({ color = shapes.light, shadow = false }), -3)

	-- the walls round it (a plinth and a coping), an invisible shell above
	local H = Practice.WALL
	for _, s in { -1, 1 } do
		shapes:block(0, Z + s * (W / 2 + 1), half * 2 + 4, 2, H, { color = shapes.light, name = "Wall" })
		shapes:block(s * (half + 1), Z, 2, W + 4, H, { color = shapes.light, name = "Wall" })
		shapes:block(0, Z + s * (W / 2 - 0.4), half * 2, 0.8, 1, deco({ color = shapes.grey }))
		shapes:block(0, Z + s * (W / 2 + 1), half * 2 + 6, 2.6, 0.8, deco({ color = shapes.white }), H)
		shapes:block(s * (half + 1), Z, 2.6, W + 6, 0.8, deco({ color = shapes.white }), H)
		shapes:block(0, Z + s * (W / 2 + 1), half * 2 + 4, 2, Practice.CEILING - H, {
			transparency = 1,
			shadow = false,
			name = "Shell",
		}, H)
		-- columns along the long walls, mirrored
		for _, x in { -40, -16, 16, 40 } do
			shapes:column(x, Z + s * (W / 2 - 2.2), H - 1, 1)
		end
	end

	-- each base: a deck, its spawn line, pads, and a gate in the back wall glowing in the team's colour
	for _, t in Constants.TEAMS do
		local s = t == "red" and -1 or 1
		local color = Constants.TEAM_COLOR[t]
		local zoneX = s * (half - Practice.DEPTH / 2)
		shapes:block(zoneX, Z, Practice.DEPTH, W - 2, 0.2, deco({ color = shapes.light }), 0)
		shapes:block(s * Practice.EDGE, Z, 0.6, W, 0.25, deco({ color = color, material = Enum.Material.Neon }))
		for _, dz in { -12, 0, 12 } do
			shapes:block(s * (half - 5), Z + dz, 4.5, 4.5, 0.3, deco({ color = color, material = Enum.Material.Neon }))
		end
		for _, dz in { -1, 1 } do
			shapes:block(s * (half - 0.5), Z + dz * 6, 3, 3, H + 3, { color = shapes.white })
		end
		shapes:block(s * (half - 0.5), Z, 3, 12, 3, { color = shapes.white }, H)
		shapes:block(s * (half - 0.2), Z, 0.6, 9, H - 1, deco({ color = color, material = Enum.Material.Neon }))
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

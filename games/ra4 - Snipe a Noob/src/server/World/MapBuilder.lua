-- Builds the arena for a round. Each map is laid out like a real shooter map, mirrored around the middle so both
-- halves are fair:
--   * three lanes run from the north spawns to the south spawns; the middle lane passes the centrepiece
--   * walk-in two-storey buildings sit on the side lanes: doors at both ends (the lane runs through), windows on
--     the sides to shoot out of, and stairs up to a roof deck with a low wall
--   * sniper nests in the corners: a tower with a railing (with gaps to shoot through) and a roof
--   * cover along every lane: sandbags, crate stacks, barrels, cars or carts, fences and planters
--   * walls with pillars, lamps and banners, and a skyline outside so the arena sits in a real place
-- Every piece is dressed in the map's theme (Block Town, Candy Canyon, Space Dock, Castle Court).
-- Three sizes (half widths from Constants.MAP_SIZES). The same map and size always comes out the same.
-- Returns { model, spawns = { Vector3 }, center, half, floorY, key, name, size }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Scenery = require(script.Parent.Scenery)

local MapBuilder = {}

MapBuilder.ARENA_CENTER = Vector3.new(0, 0, 1400)
MapBuilder.WALL_HEIGHT = 30
MapBuilder.STOREY = 9

local rgb = Scenery.rgb
local INK = rgb(30, 30, 44)
local WHITE = rgb(255, 255, 255)

local function sizeOf(sizeKey)
	for _, s in Constants.MAP_SIZES do
		if s.key == sizeKey then
			return s
		end
	end
	return Constants.MAP_SIZES[1]
end

-- Which size fits this many players.
function MapBuilder.sizeFor(players)
	for _, s in Constants.MAP_SIZES do
		if players <= s.maxPlayers then
			return s.key
		end
	end
	return Constants.MAP_SIZES[#Constants.MAP_SIZES].key
end

-- Primitives (every one takes a CFrame) ----------------------------------------------------------------------------
local function block(parent, name, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in extra or {} do
		p[k] = v
	end
	Scenery.brick(p)
	p.Parent = parent
	return p
end

local function deco(parent, name, size, cf, color, material, extra)
	local props = { CanCollide = false, CanQuery = false, CastShadow = false }
	for k, v in extra or {} do
		props[k] = v
	end
	return block(parent, name, size, cf, color, material, props)
end

local function cyl(parent, name, d, h, cf, color, material, extra)
	-- an upright cylinder (Roblox cylinders run along X)
	local p = block(
		parent,
		name,
		Vector3.new(h, d, d),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material or Enum.Material.SmoothPlastic,
		extra
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent, name, d, cf, color, material, extra)
	local p = block(parent, name, Vector3.new(d, d, d), cf, color, material or Enum.Material.SmoothPlastic, extra)
	p.Shape = Enum.PartType.Ball
	return p
end

local function wedge(parent, size, cf, color)
	local w = Instance.new("WedgePart")
	w.Name = "Ramp"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.Plastic
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- A ramp that climbs `h` studs going toward the base's -Z, starting at `foot` (the bottom middle).
local function ramp(parent, base, foot, h, width, color)
	local len = h * 1.6
	return wedge(
		parent,
		Vector3.new(width, h, len),
		base * CFrame.new(foot.X, h / 2, foot.Z - len / 2) * CFrame.Angles(0, math.rad(180), 0),
		color
	)
end

-- A wall along the base's X axis with openings { { x, w, y0, y1 } } (doors and windows are real gaps).
local function wallWithHoles(parent, base, length, height, thick, openings, color, material)
	table.sort(openings, function(a, b)
		return a.x < b.x
	end)
	local x = -length / 2
	local function solid(x0, x1, y0, y1)
		if x1 - x0 > 0.05 and y1 - y0 > 0.05 then
			block(
				parent,
				"Wall",
				Vector3.new(x1 - x0, y1 - y0, thick),
				base * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0),
				color,
				material
			)
		end
	end
	for _, o in openings do
		local ox0, ox1 = o.x - o.w / 2, o.x + o.w / 2
		solid(x, ox0, 0, height)
		solid(ox0, ox1, 0, o.y0)
		solid(ox0, ox1, o.y1, height)
		x = ox1
	end
	solid(x, length / 2, 0, height)
end

-- Theme looks ----------------------------------------------------------------------------------------------------
local LOOK = {
	town = {
		wall = { rgb(255, 240, 205), rgb(190, 225, 250), rgb(255, 215, 175), rgb(220, 245, 210) },
		wallMat = Enum.Material.Plastic,
		trim = WHITE,
		roof = rgb(240, 110, 95),
		floor = rgb(225, 195, 155),
		cover = rgb(205, 190, 140), -- sandbags
		fence = WHITE,
		metal = rgb(70, 75, 90),
		light = rgb(255, 240, 180),
	},
	candy = {
		wall = { rgb(215, 160, 105), rgb(200, 145, 95) }, -- gingerbread
		wallMat = Enum.Material.Plastic,
		trim = WHITE, -- icing
		roof = rgb(255, 130, 190),
		floor = rgb(255, 230, 240),
		cover = rgb(255, 250, 245), -- marshmallows
		fence = rgb(230, 30, 50), -- candy canes
		metal = rgb(255, 255, 255),
		light = rgb(255, 120, 200),
	},
	dock = {
		wall = { rgb(205, 215, 235), rgb(180, 195, 225) },
		wallMat = Enum.Material.DiamondPlate,
		trim = rgb(120, 220, 255),
		roof = rgb(120, 200, 245),
		floor = rgb(170, 185, 215),
		cover = rgb(255, 200, 40), -- barriers
		fence = rgb(255, 200, 40),
		metal = rgb(200, 210, 230),
		light = rgb(120, 220, 255),
	},
	castle = {
		wall = { rgb(232, 226, 214), rgb(215, 208, 196) },
		wallMat = Enum.Material.Slate,
		trim = rgb(200, 192, 182),
		roof = rgb(100, 140, 230),
		floor = rgb(200, 160, 120),
		cover = rgb(220, 190, 90), -- hay
		fence = rgb(140, 95, 55), -- palisade
		metal = rgb(90, 80, 70),
		light = rgb(255, 160, 60), -- torches
	},
}

-- Pieces ----------------------------------------------------------------------------------------------------------
-- Each piece builds at `base` (a CFrame on the floor) and returns its footprint half sizes (x, z).

-- A walk-in building: doors at the front and back (local ±Z), windows on the sides, stairs up the +X side to a
-- roof deck with a low wall. w along X, d along Z.
local function building(m, theme, look, base, w, d, rng)
	local H = MapBuilder.STOREY
	local color = look.wall[rng:NextInteger(1, #look.wall)]
	local t = 1
	local door = { x = 0, w = 5, y0 = 0, y1 = 7 }
	for _, s in { -1, 1 } do
		-- front/back with the door (the lane runs through)
		wallWithHoles(
			m,
			base * CFrame.new(0, 0, s * (d / 2 - t / 2)),
			w,
			H,
			t,
			{ table.clone(door) },
			color,
			look.wallMat
		)
		-- sides with two windows each
		local side = base * CFrame.new(s * (w / 2 - t / 2), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		wallWithHoles(m, side, d - 2 * t, H, t, {
			{ x = -d / 4, w = 3.2, y0 = 3.6, y1 = 6.4 },
			{ x = d / 4, w = 3.2, y0 = 3.6, y1 = 6.4 },
		}, color, look.wallMat)
	end
	-- floor inside, roof deck, and the low wall around the deck (gaps on the stairs side)
	deco(m, "InnerFloor", Vector3.new(w - 2 * t, 0.2, d - 2 * t), base * CFrame.new(0, 0.1, 0), look.floor)
	block(m, "Roof", Vector3.new(w + 0.6, 1, d + 0.6), base * CFrame.new(0, H + 0.5, 0), look.roof)
	for _, s in { -1, 1 } do
		block(m, "Parapet", Vector3.new(w + 0.6, 2.4, 0.8), base * CFrame.new(0, H + 2.2, s * (d / 2)), look.trim)
	end
	block(m, "Parapet", Vector3.new(0.8, 2.4, d + 0.6), base * CFrame.new(-w / 2, H + 2.2, 0), look.trim)
	-- the +X side has a gap for the stairs at the back half
	block(m, "Parapet", Vector3.new(0.8, 2.4, d / 2), base * CFrame.new(w / 2, H + 2.2, d / 4), look.trim)
	-- stairs up the +X side, from the front to the back
	ramp(m, base, Vector3.new(w / 2 + 2.2, 0, d / 2 + 1), H + 1, 4, look.floor)
	-- trim lines and the theme's touches
	deco(m, "Trim", Vector3.new(w + 0.3, 0.5, d + 0.3), base * CFrame.new(0, H - 0.25, 0), look.trim)
	if theme.props == "town" then
		-- awnings over the doors and flower boxes under the windows
		for _, s in { -1, 1 } do
			deco(
				m,
				"Awning",
				Vector3.new(6, 0.4, 2),
				base * CFrame.new(0, 7.6, s * (d / 2 + 0.9)) * CFrame.Angles(s * math.rad(-12), 0, 0),
				theme.cover[rng:NextInteger(1, #theme.cover)]
			)
			for _, z in { -d / 4, d / 4 } do
				deco(
					m,
					"Flowers",
					Vector3.new(0.8, 0.6, 3.4),
					base * CFrame.new(s * (w / 2 + 0.4), 3.3, z),
					rgb(255, 120, 160)
				)
			end
		end
	elseif theme.props == "candy" then
		for _, s in { -1, 1 } do
			for i = -2, 2 do
				ball(
					m,
					"Gumdrop",
					1,
					base * CFrame.new(i * (w / 5), H + 0.1, s * (d / 2 + 0.3)),
					theme.cover[(i + 3) % #theme.cover + 1],
					nil,
					{ CanCollide = false, CanQuery = false }
				)
			end
		end
	elseif theme.props == "dock" then
		for _, s in { -1, 1 } do
			deco(
				m,
				"Neon",
				Vector3.new(w + 0.2, 0.3, 0.2),
				base * CFrame.new(0, 1, s * (d / 2 + 0.05)),
				look.trim,
				Enum.Material.Neon
			)
		end
	else
		for i = 0, math.floor(w / 3) do
			if i % 2 == 0 then
				for _, s in { -1, 1 } do
					block(
						m,
						"Merlon",
						Vector3.new(1.4, 1.2, 0.8),
						base * CFrame.new(-w / 2 + 0.7 + i * 3, H + 4, s * (d / 2)),
						look.trim
					)
				end
			end
		end
	end
	return w / 2 + 4.5, d / 2 + 2
end

-- A sniper nest: a tower with a railing (gaps to shoot through), a roof on posts and a ramp. Returns the deck top.
local function nest(m, theme, look, base, rng)
	local h = 13
	local s = 11
	if theme.props == "castle" then
		-- a solid stone tower
		block(m, "Tower", Vector3.new(s, h, s), base * CFrame.new(0, h / 2, 0), look.wall[1], look.wallMat)
	else
		for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			local post = base * CFrame.new(c[1] * (s / 2 - 0.7), 0, c[2] * (s / 2 - 0.7))
			if theme.props == "candy" then
				cyl(
					m,
					"Post",
					1.4,
					h,
					post * CFrame.new(0, h / 2, 0),
					(c[1] + c[2]) % 4 == 0 and rgb(230, 30, 50) or WHITE
				)
			else
				block(
					m,
					"Post",
					Vector3.new(1.4, h, 1.4),
					post * CFrame.new(0, h / 2, 0),
					look.metal,
					theme.props == "dock" and Enum.Material.Metal or Enum.Material.Wood
				)
			end
		end
		-- cross braces
		for _, sd in { -1, 1 } do
			deco(
				m,
				"Brace",
				Vector3.new(s - 1.4, 0.5, 0.5),
				base * CFrame.new(0, h * 0.45, sd * (s / 2 - 0.7)) * CFrame.Angles(0, 0, math.rad(35)),
				look.metal
			)
		end
	end
	block(m, "Deck", Vector3.new(s + 1, 1, s + 1), base * CFrame.new(0, h - 0.5, 0), look.floor)
	-- railing: three sides, each with a shooting gap in the middle
	for _, side in { { 0, -1 }, { 0, 1 }, { 1, 0 } } do
		local rot = side[1] ~= 0 and math.rad(90) or 0
		local rb = base * CFrame.new(side[1] * (s / 2), h, side[2] * (s / 2)) * CFrame.Angles(0, rot, 0)
		wallWithHoles(m, rb, s + 1, 2.6, 0.6, { { x = 0, w = 2.4, y0 = 1.1, y1 = 2.6 } }, look.trim)
	end
	-- a roof on four tall posts (cover from above, open to shoot from)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		deco(
			m,
			"RoofPost",
			Vector3.new(0.5, 6, 0.5),
			base * CFrame.new(c[1] * (s / 2), h + 3, c[2] * (s / 2)),
			look.metal,
			nil,
			{ CanCollide = true }
		)
	end
	block(m, "NestRoof", Vector3.new(s + 2, 0.6, s + 2), base * CFrame.new(0, h + 6.3, 0), look.roof)
	if theme.props == "town" or theme.props == "castle" then
		wedge(m, Vector3.new(s + 2, 2.5, (s + 2) / 2), base * CFrame.new(0, h + 7.85, (s + 2) / 4), look.roof)
		wedge(
			m,
			Vector3.new(s + 2, 2.5, (s + 2) / 2),
			base * CFrame.new(0, h + 7.85, -(s + 2) / 4) * CFrame.Angles(0, math.rad(180), 0),
			look.roof
		)
	end
	-- the ramp up the open (-X) side
	local len = h * 1.6
	wedge(
		m,
		Vector3.new(4, h, len),
		base * CFrame.new(-s / 2 - len / 2, h / 2, 0) * CFrame.Angles(0, math.rad(90), 0),
		look.floor
	)
	_ = rng
	return (base * CFrame.new(0, h, 0)).Position, s / 2 + len, s / 2 + 1
end

local function sandbags(m, theme, look, base, rng)
	local n = rng:NextInteger(5, 7)
	for i = 1, n do
		local a = math.rad((i - (n + 1) / 2) * 14)
		local cf = base * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -6)
		for row = 0, 1 do
			if theme.props == "candy" then
				cyl(
					m,
					"Marshmallow",
					1.6,
					1.4,
					cf * CFrame.new(0, 0.7 + row * 1.4, 0),
					row == 1 and rgb(255, 200, 220) or look.cover
				)
			elseif theme.props == "castle" then
				cyl(
					m,
					"Hay",
					1.7,
					1.5,
					cf * CFrame.new(0, 0.75 + row * 1.5, 0) * CFrame.Angles(math.rad(90), 0, 0),
					look.cover,
					Enum.Material.Grass
				)
			elseif theme.props == "dock" then
				block(
					m,
					"Barrier",
					Vector3.new(2.2, 1.6, 1),
					cf * CFrame.new(0, 0.8 + row * 1.6, 0),
					row == 0 and look.cover or INK
				)
			else
				block(
					m,
					"Sandbag",
					Vector3.new(2.2, 1.3, 1.2),
					cf * CFrame.new(0, 0.65 + row * 1.3, 0),
					look.cover,
					Enum.Material.Fabric
				)
			end
		end
	end
	return 7, 4
end

local function crates(m, theme, look, base, rng)
	local spots = { { 0, 0, 4 }, { 4.2, 0, 3.4 }, { 1.8, 4, 3.4 } }
	for i, sp in spots do
		if i < 3 or rng:NextNumber() < 0.7 then
			local s = sp[3]
			local color = theme.cover[rng:NextInteger(1, #theme.cover)]
			local cf = base
				* CFrame.new(sp[1] - 2, sp[2] + s / 2, rng:NextNumber(-0.6, 0.6))
				* CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
			block(
				m,
				"Crate",
				Vector3.new(s, s, s),
				cf,
				theme.props == "town" and rgb(170, 120, 70) or color,
				theme.props == "town" and Enum.Material.Wood or nil
			)
			deco(
				m,
				"CrateBand",
				Vector3.new(s + 0.1, 0.35, s + 0.1),
				cf * CFrame.new(0, s * 0.3, 0),
				theme.props == "dock" and look.trim or INK,
				theme.props == "dock" and Enum.Material.Neon or nil
			)
		end
	end
	cyl(
		m,
		"Barrel",
		2.2,
		3,
		base * CFrame.new(-4.6, 1.5, 1.5),
		theme.props == "candy" and rgb(255, 170, 60) or rgb(60, 120, 200),
		Enum.Material.Metal
	)
	return 6, 3.5
end

local function barrels(m, theme, look, base, rng)
	for i = 1, 4 do
		local a = i * 1.7
		local p = base * CFrame.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8)
		if theme.props == "candy" then
			cyl(m, "Cupcake", 2.4, 2.6, p * CFrame.new(0, 1.3, 0), rgb(200, 140, 90))
			ball(m, "Frosting", 2.6, p * CFrame.new(0, 2.8, 0), theme.cover[i % #theme.cover + 1])
		elseif theme.props == "dock" then
			cyl(
				m,
				"FuelTank",
				2.4,
				3.6,
				p * CFrame.new(0, 1.8, 0),
				i % 2 == 0 and rgb(220, 70, 60) or look.metal,
				Enum.Material.Metal
			)
		else
			cyl(
				m,
				"Barrel",
				2.2,
				3,
				p * CFrame.new(0, 1.5, 0),
				i % 2 == 0 and rgb(150, 100, 60) or rgb(60, 110, 70),
				theme.props == "castle" and Enum.Material.Wood or Enum.Material.Metal
			)
		end
	end
	_ = rng
	return 3.5, 3.5
end

-- A car (town), donut (candy), cargo cart (dock) or hay cart (castle): good waist-high cover.
local function vehicle(m, theme, look, base, rng)
	if theme.props == "candy" then
		cyl(m, "Donut", 8, 2.6, base * CFrame.new(0, 1.3, 0), rgb(220, 170, 110))
		cyl(m, "Icing", 7.4, 0.5, base * CFrame.new(0, 2.8, 0), rgb(255, 120, 190), nil, { CanCollide = false })
		cyl(m, "Hole", 2.6, 0.6, base * CFrame.new(0, 2.9, 0), look.floor, nil, { CanCollide = false })
		return 4.5, 4.5
	end
	local color = theme.props == "town" and theme.cover[rng:NextInteger(1, #theme.cover)]
		or (theme.props == "dock" and rgb(255, 170, 40) or rgb(140, 95, 55))
	block(
		m,
		"Body",
		Vector3.new(4.4, 2.2, 8.5),
		base * CFrame.new(0, 1.7, 0),
		color,
		theme.props == "castle" and Enum.Material.Wood or nil
	)
	if theme.props == "town" then
		block(m, "Cabin", Vector3.new(4, 1.8, 4.2), base * CFrame.new(0, 3.7, -0.4), color)
		for _, z in { -2.3, 1.6 } do
			deco(
				m,
				"Window",
				Vector3.new(4.05, 1.2, 0.2),
				base * CFrame.new(0, 3.8, z),
				rgb(120, 180, 230),
				Enum.Material.Glass
			)
		end
	elseif theme.props == "dock" then
		block(m, "Load", Vector3.new(4, 2.4, 4), base * CFrame.new(0, 4, 1.6), look.metal, Enum.Material.Metal)
		deco(m, "Stripe", Vector3.new(4.5, 0.4, 8.6), base * CFrame.new(0, 2.5, 0), INK)
	else
		block(m, "Hay", Vector3.new(3.6, 1.6, 6), base * CFrame.new(0, 3.6, 0), rgb(220, 190, 90), Enum.Material.Grass)
	end
	for _, x in { -2.3, 2.3 } do
		for _, z in { -2.8, 2.8 } do
			local wheel = block(
				m,
				"Wheel",
				Vector3.new(0.8, 1.6, 1.6),
				base * CFrame.new(x, 0.8, z),
				INK,
				nil,
				{ CanCollide = false }
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	return 3, 5
end

local function fence(m, theme, look, base, rng)
	local len = 12
	for i = 0, 6 do
		local x = -len / 2 + i * (len / 6)
		if theme.props == "candy" then
			cyl(m, "Cane", 0.7, 3.6, base * CFrame.new(x, 1.8, 0), i % 2 == 0 and look.fence or WHITE)
		else
			block(
				m,
				"FencePost",
				Vector3.new(0.6, 3.6, 0.6),
				base * CFrame.new(x, 1.8, 0),
				look.fence,
				theme.props == "castle" and Enum.Material.Wood or nil
			)
		end
	end
	for _, y in { 1.2, 2.6 } do
		block(
			m,
			"Rail",
			Vector3.new(len, 0.4, 0.3),
			base * CFrame.new(0, y, 0),
			look.fence,
			theme.props == "castle" and Enum.Material.Wood or nil
		)
	end
	_ = rng
	return len / 2 + 1, 1.5
end

local function planter(m, theme, look, base, rng)
	if theme.props == "dock" then
		cyl(m, "Tank", 5, 6, base * CFrame.new(0, 3, 0), look.metal, Enum.Material.Metal)
		cyl(m, "TankTop", 5.2, 0.4, base * CFrame.new(0, 6.2, 0), look.trim, Enum.Material.Neon, { CanCollide = false })
		return 3.5, 3.5
	elseif theme.props == "candy" then
		local h = rng:NextInteger(8, 12)
		cyl(m, "Stick", 1, h, base * CFrame.new(0, h / 2, 0), WHITE)
		local candy = block(
			m,
			"Lolly",
			Vector3.new(1.4, 6, 6),
			base * CFrame.new(0, h + 2.5, 0),
			theme.cover[rng:NextInteger(1, #theme.cover)]
		)
		candy.Shape = Enum.PartType.Cylinder
		ball(m, "Swirl", 2.4, base * CFrame.new(0.5, h + 2.5, 0), WHITE, nil, { CanCollide = false })
		return 3.5, 3.5
	end
	block(
		m,
		"Planter",
		Vector3.new(5, 2.2, 5),
		base * CFrame.new(0, 1.1, 0),
		theme.props == "castle" and look.wall[2] or look.wall[1],
		look.wallMat
	)
	deco(m, "Soil", Vector3.new(4.4, 0.2, 4.4), base * CFrame.new(0, 2.3, 0), rgb(110, 80, 50))
	block(m, "Trunk", Vector3.new(1, 4, 1), base * CFrame.new(0, 4.2, 0), rgb(120, 80, 50), Enum.Material.Wood)
	ball(m, "Leaves", 5.5, base * CFrame.new(0, 7.2, 0), rgb(70, 170, 70), Enum.Material.Plastic)
	ball(m, "Leaves2", 3.6, base * CFrame.new(1.2, 8.6, 0.6), rgb(90, 190, 80), Enum.Material.Plastic)
	return 3, 3
end

local function lowWall(m, theme, look, base, rng)
	block(m, "LowWall", Vector3.new(9, 4, 1.4), base * CFrame.new(0, 2, 0), look.wall[1], look.wallMat)
	deco(m, "Cap", Vector3.new(9.4, 0.5, 1.8), base * CFrame.new(0, 4.25, 0), look.trim)
	_ = theme
	_ = rng
	return 5, 1.5
end

local function lamp(m, theme, look, base)
	if theme.props == "castle" then
		block(
			m,
			"Torch",
			Vector3.new(0.5, 4.5, 0.5),
			base * CFrame.new(0, 2.25, 0),
			rgb(110, 75, 45),
			Enum.Material.Wood,
			{ CanCollide = false }
		)
		ball(
			m,
			"Flame",
			1,
			base * CFrame.new(0, 4.8, 0),
			look.light,
			Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false }
		)
		return
	end
	block(m, "LampPost", Vector3.new(0.4, 7, 0.4), base * CFrame.new(0, 3.5, 0), INK, nil, { CanCollide = false })
	ball(
		m,
		"Light",
		1.3,
		base * CFrame.new(0, 7.3, 0),
		look.light,
		Enum.Material.Neon,
		{ CanCollide = false, CanQuery = false }
	)
end

-- The centrepiece ----------------------------------------------------------------------------------------------------
local function centerpiece(m, theme, look, c)
	local base = CFrame.new(c)
	if theme.props == "town" then
		cyl(m, "FountainRim", 15, 2.2, base * CFrame.new(0, 1.1, 0), rgb(205, 205, 215), Enum.Material.Slate)
		cyl(
			m,
			"Water",
			13,
			0.3,
			base * CFrame.new(0, 2.1, 0),
			rgb(80, 170, 255),
			Enum.Material.Glass,
			{ CanCollide = false }
		)
		cyl(m, "Column", 2, 6, base * CFrame.new(0, 3, 0), rgb(205, 205, 215), Enum.Material.Slate)
		cyl(m, "Bowl", 5, 0.8, base * CFrame.new(0, 6.2, 0), rgb(205, 205, 215), Enum.Material.Slate)
		ball(
			m,
			"Splash",
			2.4,
			base * CFrame.new(0, 7.4, 0),
			rgb(120, 200, 255),
			Enum.Material.Glass,
			{ CanCollide = false }
		)
	elseif theme.props == "candy" then
		cyl(m, "Cake", 12, 5, base * CFrame.new(0, 2.5, 0), rgb(255, 200, 220))
		cyl(m, "Cake2", 8, 4, base * CFrame.new(0, 7, 0), rgb(255, 150, 200))
		cyl(m, "Icing", 12.4, 0.6, base * CFrame.new(0, 5.2, 0), WHITE, nil, { CanCollide = false })
		ball(m, "Cherry", 3, base * CFrame.new(0, 10.4, 0), rgb(230, 30, 50))
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			cyl(
				m,
				"Candle",
				0.5,
				2,
				base * CFrame.new(math.cos(a) * 3, 10, math.sin(a) * 3),
				i % 2 == 0 and rgb(120, 220, 255) or rgb(255, 230, 80),
				nil,
				{ CanCollide = false }
			)
		end
	elseif theme.props == "dock" then
		cyl(m, "Pad", 16, 1, base * CFrame.new(0, 0.5, 0), rgb(110, 115, 150), Enum.Material.DiamondPlate)
		cyl(
			m,
			"PadRing",
			16.4,
			0.2,
			base * CFrame.new(0, 1.05, 0),
			look.trim,
			Enum.Material.Neon,
			{ CanCollide = false }
		)
		cyl(m, "Rocket", 5, 16, base * CFrame.new(0, 9, 0), rgb(235, 235, 245))
		local nose = wedge(m, Vector3.new(4.6, 4, 2.3), base * CFrame.new(0, 19, 1.15), rgb(220, 60, 60))
		_ = nose
		wedge(
			m,
			Vector3.new(4.6, 4, 2.3),
			base * CFrame.new(0, 19, -1.15) * CFrame.Angles(0, math.rad(180), 0),
			rgb(220, 60, 60)
		)
		for _, a in { 0, 90, 180, 270 } do
			block(
				m,
				"Fin",
				Vector3.new(0.6, 5, 3),
				base * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 3.5, 3.2),
				rgb(220, 60, 60)
			)
		end
		deco(m, "Porthole", Vector3.new(5.1, 1.6, 1.6), base * CFrame.new(0, 13, 0), look.trim, Enum.Material.Neon)
		-- the gantry tower next to it
		block(m, "Gantry", Vector3.new(2, 20, 2), base * CFrame.new(6, 10, 0), look.metal, Enum.Material.Metal)
		block(m, "Arm", Vector3.new(4, 0.8, 1), base * CFrame.new(4, 15, 0), look.metal, Enum.Material.Metal)
	else
		block(m, "Keep", Vector3.new(12, 14, 12), base * CFrame.new(0, 7, 0), look.wall[1], look.wallMat)
		for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			cyl(m, "Turret", 4, 18, base * CFrame.new(corner[1] * 6, 9, corner[2] * 6), look.wall[2], look.wallMat)
			local cone = wedge(
				m,
				Vector3.new(4.4, 3, 2.2),
				base * CFrame.new(corner[1] * 6, 19.5, corner[2] * 6 + 1.1),
				look.roof
			)
			_ = cone
			wedge(
				m,
				Vector3.new(4.4, 3, 2.2),
				base * CFrame.new(corner[1] * 6, 19.5, corner[2] * 6 - 1.1) * CFrame.Angles(0, math.rad(180), 0),
				look.roof
			)
		end
		for _, s in { -1, 1 } do
			deco(
				m,
				"Banner",
				Vector3.new(0.3, 6, 3),
				base * CFrame.new(s * 6.2, 9, 0),
				theme.accent,
				Enum.Material.Fabric
			)
		end
		deco(m, "Gate", Vector3.new(4, 6, 0.3), base * CFrame.new(0, 3, 6.1), rgb(90, 60, 40), Enum.Material.Wood)
	end
end

-- Outside the walls: a skyline so the arena sits somewhere real (can't be reached).
local function skyline(m, theme, look, c, H, rng)
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		local cx, sz = math.cos(a), math.sin(a)
		local k = (H + 16 + rng:NextNumber(0, 18)) / math.max(math.abs(cx), math.abs(sz))
		local p = c + Vector3.new(cx * k, 0, sz * k)
		local base = CFrame.lookAt(p, Vector3.new(c.X, 0, c.Z))
		if theme.props == "town" then
			if i % 3 == 0 then
				local h = rng:NextInteger(14, 26)
				block(
					m,
					"FarHouse",
					Vector3.new(12, h, 10),
					base * CFrame.new(0, h / 2, 0),
					look.wall[rng:NextInteger(1, #look.wall)],
					nil,
					{ CanQuery = false }
				)
				wedge(m, Vector3.new(12, 5, 5), base * CFrame.new(0, h + 2.5, 2.5), look.roof).CanQuery = false
				wedge(
					m,
					Vector3.new(12, 5, 5),
					base * CFrame.new(0, h + 2.5, -2.5) * CFrame.Angles(0, math.rad(180), 0),
					look.roof
				).CanQuery =
					false
			else
				block(
					m,
					"FarTrunk",
					Vector3.new(2, 10, 2),
					base * CFrame.new(0, 5, 0),
					rgb(120, 80, 50),
					Enum.Material.Wood,
					{ CanQuery = false }
				)
				ball(
					m,
					"FarLeaves",
					rng:NextInteger(10, 14),
					base * CFrame.new(0, 13, 0),
					rgb(70, 160, 70),
					nil,
					{ CanQuery = false }
				)
			end
		elseif theme.props == "candy" then
			if i % 2 == 0 then
				local h = rng:NextInteger(18, 30)
				cyl(m, "FarStick", 1.6, h, base * CFrame.new(0, h / 2, 0), WHITE, nil, { CanQuery = false })
				local l = block(
					m,
					"FarLolly",
					Vector3.new(2, 12, 12),
					base * CFrame.new(0, h + 5, 0),
					theme.cover[rng:NextInteger(1, #theme.cover)],
					nil,
					{ CanQuery = false }
				)
				l.Shape = Enum.PartType.Cylinder
			else
				ball(
					m,
					"FarGumdrop",
					rng:NextInteger(14, 22),
					base * CFrame.new(0, 3, 0),
					theme.cover[rng:NextInteger(1, #theme.cover)],
					nil,
					{ CanQuery = false }
				)
			end
		elseif theme.props == "dock" then
			if i % 4 == 0 then
				block(
					m,
					"CraneTower",
					Vector3.new(3, 40, 3),
					base * CFrame.new(0, 20, 0),
					rgb(255, 170, 40),
					Enum.Material.Metal,
					{ CanQuery = false }
				)
				block(
					m,
					"CraneArm",
					Vector3.new(3, 2.5, 28),
					base * CFrame.new(0, 39, 8),
					rgb(255, 170, 40),
					Enum.Material.Metal,
					{ CanQuery = false }
				)
			else
				local stack = rng:NextInteger(1, 3)
				for s = 0, stack - 1 do
					block(
						m,
						"FarContainer",
						Vector3.new(8, 7, 16),
						base * CFrame.new(0, 3.5 + s * 7, 0),
						theme.cover[rng:NextInteger(1, #theme.cover)],
						nil,
						{ CanQuery = false }
					)
				end
			end
		else
			if i % 3 == 0 then
				cyl(
					m,
					"FarTower",
					10,
					34,
					base * CFrame.new(0, 17, 0),
					look.wall[2],
					look.wallMat,
					{ CanQuery = false }
				)
				wedge(m, Vector3.new(11, 8, 5.5), base * CFrame.new(0, 38, 2.75), look.roof).CanQuery = false
				wedge(
					m,
					Vector3.new(11, 8, 5.5),
					base * CFrame.new(0, 38, -2.75) * CFrame.Angles(0, math.rad(180), 0),
					look.roof
				).CanQuery =
					false
			else
				block(
					m,
					"FarTrunk",
					Vector3.new(2, 9, 2),
					base * CFrame.new(0, 4.5, 0),
					rgb(110, 75, 45),
					Enum.Material.Wood,
					{ CanQuery = false }
				)
				ball(
					m,
					"FarLeaves",
					rng:NextInteger(9, 13),
					base * CFrame.new(0, 12, 0),
					rgb(60, 140, 60),
					nil,
					{ CanQuery = false }
				)
			end
		end
	end
end

-- Footprints ------------------------------------------------------------------------------------------------------
local function overlaps(taken, x, z, hx, hz, pad)
	for _, r in taken do
		if math.abs(x - r[1]) < hx + r[3] + pad and math.abs(z - r[2]) < hz + r[4] + pad then
			return true
		end
	end
	return false
end

-- Dressing ----------------------------------------------------------------------------------------------------------
-- Everything that makes a map feel like a place: paving, curbs and ground patches, building details (frames,
-- shutters, awnings, signs, chimneys, flower boxes), street props in the theme, ivy and posters on the walls,
-- hills and mountains outside, and clouds. Props that stand on the ground are real cover; the rest is decoration
-- (shots and players pass through it).
local SIGNS = {
	town = { "CAFE", "SHOP", "BAKERY", "TOYS", "BOOKS", "PIZZA" },
	candy = { "SWEETS", "FUDGE", "TAFFY", "GUMMY", "COCOA", "TREATS" },
	dock = { "HANGAR 1", "FUEL", "CARGO", "LAB", "DOCK 7", "COMMS" },
	castle = { "INN", "SMITH", "TAVERN", "STABLE", "GUARD", "MARKET" },
}

local function sign(m, cf, w, h, text, bg, fg)
	local p = deco(m, "Sign", Vector3.new(w, h, 0.3), cf, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(w * 40, h * 40)
	gui.LightInfluence = 0.3
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = fg
	t.Parent = gui
	return p
end

local function dressHouse(m, theme, look, h, rng, i)
	local base, w, d = h.base, h.w, h.d
	local H = MapBuilder.STOREY
	local trim = look.trim
	local accent = theme.cover[(i % #theme.cover) + 1]
	-- corner posts and a band between the floors
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			deco(m, "CornerTrim", Vector3.new(0.9, H, 0.9), base * CFrame.new(sx * (w / 2), H / 2, sz * (d / 2)), trim)
		end
	end
	for _, sz in { -1, 1 } do
		deco(m, "Band", Vector3.new(w + 0.4, 0.5, 0.4), base * CFrame.new(0, 2.8, sz * (d / 2 + 0.1)), trim)
		-- an awning over each door, striped
		for k = -2, 2 do
			deco(
				m,
				"Awning",
				Vector3.new(1.2, 0.25, 2.2),
				base * CFrame.new(k * 1.2, 7.6, sz * (d / 2 + 1)) * CFrame.Angles(sz * math.rad(-14), 0, 0),
				k % 2 == 0 and accent or WHITE,
				Enum.Material.Fabric
			)
		end
		-- door frame
		deco(m, "DoorFrame", Vector3.new(6, 0.5, 0.5), base * CFrame.new(0, 7.2, sz * (d / 2 + 0.15)), trim)
		for _, dx in { -2.75, 2.75 } do
			deco(m, "DoorFrame", Vector3.new(0.5, 7, 0.5), base * CFrame.new(dx, 3.5, sz * (d / 2 + 0.15)), trim)
		end
	end
	-- the shop sign over the front door
	local names = SIGNS[theme.props] or SIGNS.town
	local s = sign(
		m,
		base * CFrame.new(0, 8.6, -(d / 2 + 0.35)) * CFrame.Angles(0, math.rad(180), 0),
		6,
		1.4,
		names[(i % #names) + 1],
		trim,
		accent:Lerp(INK, 0.35)
	)
	s.Name = "ShopSign"
	-- window frames, shutters and flower boxes on the sides
	for _, sx in { -1, 1 } do
		for _, wz in { -d / 4, d / 4 } do
			local wcf = base * CFrame.new(sx * (w / 2 + 0.15), 5, wz) * CFrame.Angles(0, math.rad(90 * sx), 0)
			deco(m, "WindowFrame", Vector3.new(4, 0.4, 0.4), wcf * CFrame.new(0, 1.6, 0), trim)
			deco(m, "WindowFrame", Vector3.new(4, 0.4, 0.4), wcf * CFrame.new(0, -1.6, 0), trim)
			for _, dx in { -2.6, 2.6 } do
				deco(m, "Shutter", Vector3.new(1.2, 3, 0.2), wcf * CFrame.new(dx, 0, 0.1), accent, Enum.Material.Wood)
			end
			deco(m, "FlowerBox", Vector3.new(3.4, 0.6, 0.8), wcf * CFrame.new(0, -2.1, -0.4), look.floor:Lerp(INK, 0.3))
			for f = -1, 1 do
				ball(
					m,
					"Flower",
					0.6,
					wcf * CFrame.new(f * 1.1, -1.6, -0.4),
					theme.cover[rng:NextInteger(1, #theme.cover)],
					nil,
					{ CanCollide = false, CanQuery = false, CastShadow = false }
				)
			end
		end
	end
	-- something on the roof: a chimney (town, castle), a cherry (candy) or an antenna (dock)
	local roofTop = base * CFrame.new(w / 2 - 1.6, H + 1, d / 2 - 1.6)
	if theme.props == "dock" then
		deco(m, "Antenna", Vector3.new(0.3, 7, 0.3), roofTop * CFrame.new(0, 4.5, 0), look.metal)
		ball(
			m,
			"AntennaLight",
			0.8,
			roofTop * CFrame.new(0, 8.2, 0),
			rgb(255, 60, 60),
			Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false }
		)
		cyl(
			m,
			"Dish",
			2.6,
			0.3,
			roofTop * CFrame.new(-2.5, 2.2, 0) * CFrame.Angles(math.rad(35), 0, 0),
			WHITE,
			nil,
			{ CanCollide = false, CanQuery = false }
		)
	elseif theme.props == "candy" then
		ball(
			m,
			"Cherry",
			1.8,
			roofTop * CFrame.new(0, 2.2, 0),
			rgb(230, 30, 50),
			nil,
			{ CanCollide = false, CanQuery = false }
		)
		deco(
			m,
			"Stem",
			Vector3.new(0.2, 1.6, 0.2),
			roofTop * CFrame.new(0.2, 3.6, 0) * CFrame.Angles(0, 0, math.rad(20)),
			rgb(80, 150, 60)
		)
	else
		deco(
			m,
			"Chimney",
			Vector3.new(1.6, 4, 1.6),
			roofTop * CFrame.new(0, 2.5, 0),
			look.wall[#look.wall]:Lerp(INK, 0.25),
			look.wallMat
		)
		deco(m, "ChimneyCap", Vector3.new(2, 0.4, 2), roofTop * CFrame.new(0, 4.7, 0), trim)
	end
end

-- Props along the lanes, by theme. Each returns its footprint half size (they're real cover).
local PROPS = {}
function PROPS.town(m, look, p, rng, theme)
	local k = rng:NextInteger(1, 4)
	if k == 1 then -- a bench
		block(m, "Bench", Vector3.new(4, 0.4, 1.4), p * CFrame.new(0, 1.4, 0), rgb(170, 110, 60), Enum.Material.Wood)
		block(
			m,
			"BenchBack",
			Vector3.new(4, 1.2, 0.3),
			p * CFrame.new(0, 2.2, 0.6),
			rgb(170, 110, 60),
			Enum.Material.Wood
		)
		for _, x in { -1.6, 1.6 } do
			block(m, "BenchLeg", Vector3.new(0.3, 1.2, 1.2), p * CFrame.new(x, 0.6, 0), look.metal)
		end
		return 2, 0.8
	elseif k == 2 then -- a postbox
		block(m, "Postbox", Vector3.new(1.4, 2.6, 1.4), p * CFrame.new(0, 1.3, 0), rgb(220, 50, 50))
		cyl(m, "PostboxTop", 1.4, 0.4, p * CFrame.new(0, 2.8, 0), rgb(220, 50, 50))
		return 0.8, 0.8
	elseif k == 3 then -- a hydrant
		cyl(m, "Hydrant", 1, 1.8, p * CFrame.new(0, 0.9, 0), rgb(240, 60, 50))
		ball(m, "HydrantTop", 1, p * CFrame.new(0, 1.9, 0), rgb(240, 60, 50))
		return 0.6, 0.6
	end
	-- a market stall
	block(m, "Stall", Vector3.new(4, 2.4, 2), p * CFrame.new(0, 1.2, 0), rgb(170, 110, 60), Enum.Material.Wood)
	for k2 = -1, 1 do
		deco(
			m,
			"StallRoof",
			Vector3.new(1.4, 0.2, 2.6),
			p * CFrame.new(k2 * 1.35, 4.2, 0),
			k2 == 0 and WHITE or theme.cover[1],
			Enum.Material.Fabric
		)
	end
	for _, x in { -1.8, 1.8 } do
		deco(m, "StallPole", Vector3.new(0.2, 1.8, 0.2), p * CFrame.new(x, 3.3, 0.9), look.metal)
	end
	for f = -1, 1 do
		ball(
			m,
			"Fruit",
			0.6,
			p * CFrame.new(f * 1.1, 2.7, 0),
			theme.cover[rng:NextInteger(1, #theme.cover)],
			nil,
			{ CanCollide = false }
		)
	end
	return 2.1, 1.1
end
function PROPS.candy(m, _look, p, rng, theme)
	local k = rng:NextInteger(1, 3)
	if k == 1 then -- a giant lollipop
		deco(m, "Stick", Vector3.new(0.5, 6, 0.5), p * CFrame.new(0, 3, 0), WHITE, nil, { CanCollide = true })
		cyl(
			m,
			"Lolly",
			4,
			0.8,
			p * CFrame.new(0, 7.5, 0) * CFrame.Angles(math.rad(90), 0, 0),
			theme.cover[rng:NextInteger(1, #theme.cover)]
		)
		cyl(
			m,
			"LollySwirl",
			2.6,
			0.9,
			p * CFrame.new(0, 7.5, 0) * CFrame.Angles(math.rad(90), 0, 0),
			WHITE,
			nil,
			{ CanCollide = false, CanQuery = false }
		)
		return 0.5, 0.5
	elseif k == 2 then -- a candy cane
		for i = 0, 5 do
			block(
				m,
				"Cane",
				Vector3.new(0.9, 1, 0.9),
				p * CFrame.new(0, 0.5 + i, 0),
				i % 2 == 0 and rgb(230, 30, 50) or WHITE
			)
		end
		block(m, "CaneHook", Vector3.new(0.9, 0.9, 2), p * CFrame.new(0, 6.3, 0.6), rgb(230, 30, 50))
		return 0.6, 0.6
	end
	-- a stack of gumdrops
	for i = 1, 3 do
		ball(
			m,
			"Gumdrop",
			3 - i * 0.5,
			p * CFrame.new(0, i * 1.6 - 0.4, 0),
			theme.cover[rng:NextInteger(1, #theme.cover)]
		)
	end
	return 1.3, 1.3
end
function PROPS.dock(m, look, p, rng, theme)
	local k = rng:NextInteger(1, 3)
	if k == 1 then -- a cargo container
		local col = theme.cover[rng:NextInteger(1, #theme.cover)]
		block(m, "Container", Vector3.new(4, 4, 8), p * CFrame.new(0, 2, 0), col, Enum.Material.CorrodedMetal)
		for z = -3, 3, 1.5 do
			deco(m, "Rib", Vector3.new(4.2, 3.6, 0.2), p * CFrame.new(0, 2, z), col:Lerp(INK, 0.2))
		end
		return 2.1, 4.1
	elseif k == 2 then -- a fuel tank
		cyl(m, "Tank", 3, 4, p * CFrame.new(0, 2, 0), WHITE, Enum.Material.Metal)
		deco(m, "TankBand", Vector3.new(3.2, 0.4, 3.2), p * CFrame.new(0, 2.6, 0), rgb(255, 200, 40))
		return 1.6, 1.6
	end
	-- a crate of glowing cells
	block(m, "CellCrate", Vector3.new(3, 2, 3), p * CFrame.new(0, 1, 0), look.metal, Enum.Material.DiamondPlate)
	for _, q in { { -0.7, -0.7 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 } } do
		cyl(
			m,
			"Cell",
			0.8,
			1.2,
			p * CFrame.new(q[1], 2.5, q[2]),
			rgb(120, 230, 255),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	end
	return 1.6, 1.6
end
function PROPS.castle(m, look, p, rng, _theme)
	local k = rng:NextInteger(1, 3)
	if k == 1 then -- a well
		cyl(m, "Well", 4, 2.4, p * CFrame.new(0, 1.2, 0), look.wall[1], Enum.Material.Cobblestone)
		cyl(m, "Water", 3.2, 0.2, p * CFrame.new(0, 2.2, 0), rgb(80, 160, 230), nil, { CanCollide = false })
		for _, x in { -1.8, 1.8 } do
			deco(
				m,
				"WellPost",
				Vector3.new(0.4, 3, 0.4),
				p * CFrame.new(x, 3.6, 0),
				rgb(120, 80, 50),
				Enum.Material.Wood
			)
		end
		wedge(m, Vector3.new(4.4, 1.2, 1.4), p * CFrame.new(0, 5.6, 0.7), look.roof).CanQuery = false
		wedge(
			m,
			Vector3.new(4.4, 1.2, 1.4),
			p * CFrame.new(0, 5.6, -0.7) * CFrame.Angles(0, math.rad(180), 0),
			look.roof
		).CanQuery =
			false
		return 2.1, 2.1
	elseif k == 2 then -- a torch post
		deco(
			m,
			"TorchPost",
			Vector3.new(0.6, 5, 0.6),
			p * CFrame.new(0, 2.5, 0),
			rgb(110, 75, 45),
			Enum.Material.Wood,
			{ CanCollide = true }
		)
		local flame = ball(
			m,
			"Flame",
			1,
			p * CFrame.new(0, 5.4, 0),
			rgb(255, 160, 50),
			Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false }
		)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 170, 80)
		light.Range = 14
		light.Parent = flame
		return 0.4, 0.4
	end
	-- a weapon rack / barrels of apples
	block(m, "AppleBarrel", Vector3.new(2, 2, 2), p * CFrame.new(0, 1, 0), rgb(140, 95, 55), Enum.Material.Wood)
	for _ = 1, 5 do
		ball(
			m,
			"Apple",
			0.55,
			p * CFrame.new(rng:NextNumber(-0.6, 0.6), 2.2, rng:NextNumber(-0.6, 0.6)),
			rgb(210, 40, 40),
			nil,
			{ CanCollide = false }
		)
	end
	return 1.1, 1.1
end

local function dress(m, theme, look, c, H, rank, rng, taken, houses)
	local props = theme.props
	-- paving: tiles down the lanes in two shades, and curbs along them
	for _, u in { -0.55, 0, 0.55 } do
		local n = math.floor(H * 2 / 4)
		for i = 0, n - 1 do
			local z = -H + 2 + i * 4
			if i % 2 == 0 then
				deco(
					m,
					"Tile",
					Vector3.new(7.4, 0.06, 3.6),
					CFrame.new(c + Vector3.new(u * H, 0.23, z)),
					theme.path:Lerp(INK, 0.06)
				)
			end
		end
		for _, sx in { -1, 1 } do
			deco(
				m,
				"Curb",
				Vector3.new(0.6, 0.35, H * 2),
				CFrame.new(c + Vector3.new(u * H + sx * 4.2, 0.18, 0)),
				look.trim:Lerp(theme.path, 0.4)
			)
		end
	end
	-- ground patches: grass tufts, dirt, sprinkles, glowing strips or cobbles
	for i = 1, 24 + rank * 10 do
		local x, z = rng:NextNumber(-H + 4, H - 4), rng:NextNumber(-H + 4, H - 4)
		local p = CFrame.new(c + Vector3.new(x, 0.21, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		if props == "town" or props == "castle" then
			local col = theme.floor:Lerp(i % 3 == 0 and rgb(140, 110, 70) or rgb(60, 140, 60), 0.35)
			cyl(
				m,
				"Patch",
				rng:NextNumber(3, 7),
				0.05,
				p,
				col,
				nil,
				{ CanCollide = false, CanQuery = false, CastShadow = false }
			)
			if i % 2 == 0 then
				for t = 1, 3 do
					deco(
						m,
						"Tuft",
						Vector3.new(0.2, 0.9, 0.2),
						p * CFrame.new(t * 0.4 - 0.8, 0.45, 0) * CFrame.Angles(0, 0, math.rad(t * 15 - 30)),
						rgb(70, 160, 60)
					)
				end
			end
		elseif props == "candy" then
			for t = 1, 4 do
				deco(
					m,
					"Sprinkle",
					Vector3.new(0.9, 0.2, 0.25),
					p * CFrame.new(t - 2.5, 0, (t % 2) * 0.8) * CFrame.Angles(0, t, 0),
					theme.cover[(t % #theme.cover) + 1],
					Enum.Material.Neon
				)
			end
		else
			deco(m, "FloorPanel", Vector3.new(6, 0.05, 6), p, theme.floor:Lerp(WHITE, 0.25), Enum.Material.DiamondPlate)
			if i % 3 == 0 then
				deco(
					m,
					"GlowStrip",
					Vector3.new(6, 0.08, 0.4),
					p * CFrame.new(0, 0.05, 0),
					rgb(120, 220, 255),
					Enum.Material.Neon
				)
			end
		end
	end
	-- crosswalk stripes where the lanes meet the cross path
	if props == "town" then
		for _, u in { -0.55, 0.55 } do
			for k = -3, 3 do
				deco(
					m,
					"Crosswalk",
					Vector3.new(0.8, 0.07, 6),
					CFrame.new(c + Vector3.new(u * H + k * 1.1, 0.25, 0)),
					WHITE
				)
			end
		end
	end
	-- building details
	for i, h in houses do
		dressHouse(m, theme, look, h, rng, i)
	end
	-- props along the lanes (real cover), mirrored so it stays fair
	local maker = PROPS[props] or PROPS.town
	local tries = 10 + rank * 6
	for _ = 1, tries do
		local u = ({ -0.55, 0, 0.55 })[rng:NextInteger(1, 3)]
		local x = u * H + (rng:NextInteger(0, 1) == 0 and -6.5 or 6.5)
		local z = rng:NextNumber(-H + 10, -6)
		local yaw = rng:NextInteger(0, 3) * 90
		local fits = not overlaps(taken, x, z, 2.5, 4.5, 1) and not overlaps(taken, -x, -z, 2.5, 4.5, 1)
		if fits then
			local seed = rng:NextInteger(1, 1e6)
			for _, mirror in { 1, -1 } do
				local p = CFrame.new(c + Vector3.new(x * mirror, 0, z * mirror))
					* CFrame.Angles(0, math.rad(yaw + (mirror == -1 and 180 or 0)), 0)
				local hx, hz = maker(m, look, p, Random.new(seed), theme)
				table.insert(taken, { x * mirror, z * mirror, math.max(hx, hz), math.max(hx, hz) })
			end
		end
	end
	-- the walls inside: ivy (town, castle), pipes (dock), icing drips (candy), and posters
	local WH = MapBuilder.WALL_HEIGHT
	for _, s in { -1, 1 } do
		for k = 1, 6 + rank * 2 do
			local t = rng:NextNumber(-H + 6, H - 6)
			local alongX = k % 2 == 0
			local pos = alongX and Vector3.new(t, 0, s * (H - 0.05)) or Vector3.new(s * (H - 0.05), 0, t)
			local cf = CFrame.new(c + pos)
				* (
					alongX and CFrame.Angles(0, s > 0 and 0 or math.pi, 0)
					or CFrame.Angles(0, s > 0 and math.pi / 2 or -math.pi / 2, 0)
				)
			if props == "town" or props == "castle" then
				local hgt = rng:NextNumber(8, WH - 4)
				deco(
					m,
					"Ivy",
					Vector3.new(rng:NextNumber(2, 4), hgt, 0.25),
					cf * CFrame.new(0, hgt / 2, 0),
					rgb(70, 150, 60),
					Enum.Material.Grass
				)
				for _ = 1, 3 do
					ball(
						m,
						"IvyLeaf",
						rng:NextNumber(1.2, 2),
						cf * CFrame.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(1, hgt), 0),
						rgb(80, 165, 70),
						Enum.Material.Grass,
						{ CanCollide = false, CanQuery = false, CastShadow = false }
					)
				end
			elseif props == "dock" then
				deco(
					m,
					"Pipe",
					Vector3.new(0.8, WH - 2, 0.8),
					cf * CFrame.new(0, (WH - 2) / 2, 0.3),
					look.metal,
					Enum.Material.Metal
				)
				deco(
					m,
					"PipeLight",
					Vector3.new(1, 0.4, 1),
					cf * CFrame.new(0, WH / 2, 0.3),
					rgb(120, 220, 255),
					Enum.Material.Neon
				)
			else
				for dd = 1, 3 do
					deco(
						m,
						"Drip",
						Vector3.new(1, rng:NextNumber(2, 5), 0.3),
						cf * CFrame.new(dd * 1.3 - 2.6, WH - 3, 0),
						WHITE
					)
				end
			end
			if k % 3 == 0 then
				local poster = sign(
					m,
					cf * CFrame.new(0, 6, -0.1) * CFrame.Angles(0, math.pi, 0),
					4,
					5,
					({ "🎯", "💥", "🏆", "⭐" })[rng:NextInteger(1, 4)],
					theme.cover[rng:NextInteger(1, #theme.cover)],
					WHITE
				)
				poster.Name = "Poster"
			end
		end
	end
	-- outside: rolling hills with trees (town, castle, candy), or moons and floating rocks (dock), and clouds
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local dist = H + 80 + rng:NextNumber(0, 60)
		local p = c + Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
		if props == "dock" and i % 4 == 0 then
			-- a few big moons far off and high up
			ball(
				m,
				"Moon",
				rng:NextNumber(60, 110),
				CFrame.new(p * 3 - c * 2 + Vector3.new(0, rng:NextNumber(160, 260), 0)),
				i % 2 == 0 and rgb(220, 225, 240) or rgb(255, 210, 160),
				nil,
				{ CanCollide = false, CanQuery = false }
			)
		elseif props ~= "dock" then
			local size = rng:NextNumber(40, 80)
			ball(
				m,
				"Hill",
				size,
				CFrame.new(p + Vector3.new(0, -size * 0.25, 0)),
				theme.floor:Lerp(props == "candy" and WHITE or rgb(60, 130, 60), 0.3),
				Enum.Material.Grass,
				{ CanCollide = false, CanQuery = false }
			)
			for _ = 1, 2 do
				local tp = p + Vector3.new(rng:NextNumber(-8, 8), size * 0.2, rng:NextNumber(-8, 8))
				deco(
					m,
					"HillTrunk",
					Vector3.new(1.4, 6, 1.4),
					CFrame.new(tp + Vector3.new(0, 3, 0)),
					rgb(120, 80, 50),
					Enum.Material.Wood
				)
				ball(
					m,
					"HillTree",
					rng:NextNumber(6, 9),
					CFrame.new(tp + Vector3.new(0, 8, 0)),
					props == "candy" and theme.cover[rng:NextInteger(1, #theme.cover)] or rgb(70, 160, 70),
					nil,
					{ CanCollide = false, CanQuery = false }
				)
			end
		end
	end
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(H + 40, H + 220)
		local p = c + Vector3.new(math.cos(a) * dist, rng:NextNumber(110, 170), math.sin(a) * dist)
		for b = 1, 4 do
			ball(
				m,
				"Cloud",
				rng:NextNumber(14, 24),
				CFrame.new(p + Vector3.new(b * 9 - 22, rng:NextNumber(-3, 3), rng:NextNumber(-5, 5))),
				WHITE,
				nil,
				{ CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.1 }
			)
		end
	end
end

-- Build ------------------------------------------------------------------------------------------------------------
local PIECES = {
	sandbags = sandbags,
	crates = crates,
	barrels = barrels,
	vehicle = vehicle,
	fence = fence,
	planter = planter,
	lowWall = lowWall,
}
-- One half of the layout in units of the half width (u across, v toward the north spawns); the other half is the
-- same turned 180 degrees. rot is the piece's turn in degrees. min: smallest map size the piece appears on.
local LAYOUT = {
	{ "building", 0.52, 0.12, 0, "small" },
	{ "sandbags", 0, 0.42, 0, "small" },
	{ "crates", -0.42, 0.5, 90, "small" },
	{ "vehicle", 0.24, 0.62, 20, "small" },
	{ "planter", -0.2, 0.22, 0, "small" },
	{ "barrels", 0.82, 0.5, 0, "small" },
	{ "fence", -0.72, 0.18, 90, "small" },
	{ "lowWall", 0.26, 0.3, 90, "medium" },
	{ "crates", 0.1, 0.78, 0, "medium" },
	{ "planter", 0.8, 0.82, 0, "medium" },
	{ "sandbags", -0.55, 0.8, 180, "medium" },
	{ "vehicle", -0.85, 0.42, 0, "large" },
	{ "barrels", 0.6, 0.38, 0, "large" },
	{ "lowWall", -0.25, 0.6, 0, "large" },
}
local SIZE_RANK = { small = 1, medium = 2, large = 3 }

function MapBuilder.build(mapKey, sizeKey, parent, center)
	local theme = Maps.byKey[mapKey] or Maps.list[1]
	local look = LOOK[theme.props]
	local size = sizeOf(sizeKey)
	local H = size.half
	local rank = SIZE_RANK[size.key] or 1
	local c = center or MapBuilder.ARENA_CENTER
	local seed = H
	for i = 1, #mapKey do
		seed += string.byte(mapKey, i) * i * 31
	end
	local rng = Random.new(seed)
	local m = Instance.new("Model")
	m.Name = "Arena_" .. theme.key

	-- floor: the base, the lanes, a plaza round the middle, and ground beyond the walls
	block(m, "Floor", Vector3.new(H * 2 + 8, 2, H * 2 + 8), CFrame.new(c + Vector3.new(0, -1, 0)), theme.floor)
	for _, u in { -0.55, 0, 0.55 } do
		deco(m, "Lane", Vector3.new(8, 0.2, H * 2), CFrame.new(c + Vector3.new(u * H, 0.1, 0)), theme.path)
	end
	deco(m, "CrossPath", Vector3.new(H * 2, 0.2, 7), CFrame.new(c + Vector3.new(0, 0.1, 0)), theme.path)
	cyl(
		m,
		"Plaza",
		30,
		0.25,
		CFrame.new(c + Vector3.new(0, 0.13, 0)),
		theme.path:Lerp(WHITE, 0.15),
		nil,
		{ CanCollide = false, CanQuery = false }
	)
	block(
		m,
		"Ground",
		Vector3.new(H * 2 + 160, 1, H * 2 + 160),
		CFrame.new(c + Vector3.new(0, -2.6, 0)),
		theme.floor:Lerp(INK, 0.15),
		nil,
		{ CanQuery = false }
	)

	-- walls with pillars, lamps and banners
	local WH = MapBuilder.WALL_HEIGHT
	for _, s in { -1, 1 } do
		block(
			m,
			"Wall",
			Vector3.new(H * 2 + 8, WH, 4),
			CFrame.new(c + Vector3.new(0, WH / 2, s * (H + 2))),
			look.wall[1],
			look.wallMat
		)
		block(
			m,
			"Wall",
			Vector3.new(4, WH, H * 2 + 8),
			CFrame.new(c + Vector3.new(s * (H + 2), WH / 2, 0)),
			look.wall[1],
			look.wallMat
		)
		deco(
			m,
			"WallTrim",
			Vector3.new(H * 2 + 8, 1.2, 4.6),
			CFrame.new(c + Vector3.new(0, WH, s * (H + 2))),
			theme.accent
		)
		deco(
			m,
			"WallTrim",
			Vector3.new(4.6, 1.2, H * 2 + 8),
			CFrame.new(c + Vector3.new(s * (H + 2), WH, 0)),
			theme.accent
		)
		deco(
			m,
			"Skirting",
			Vector3.new(H * 2 + 8, 1.6, 4.4),
			CFrame.new(c + Vector3.new(0, 0.8, s * (H + 2))),
			look.trim
		)
		deco(
			m,
			"Skirting",
			Vector3.new(4.4, 1.6, H * 2 + 8),
			CFrame.new(c + Vector3.new(s * (H + 2), 0.8, 0)),
			look.trim
		)
		local n = math.floor(H * 2 / 16)
		for i = 0, n do
			local t = -H + i * (H * 2 / n)
			for _, side in { { t, s * (H - 0.2), 0 }, { s * (H - 0.2), t, 90 } } do
				local base = CFrame.new(c + Vector3.new(side[1], 0, side[2])) * CFrame.Angles(0, math.rad(side[3]), 0)
				block(
					m,
					"Pillar",
					Vector3.new(2.6, WH - 2, 1.2),
					base * CFrame.new(0, (WH - 2) / 2, 0),
					look.wall[#look.wall],
					look.wallMat
				)
				ball(
					m,
					"WallLight",
					1.4,
					base * CFrame.new(0, WH - 4, -s * 0.9),
					look.light,
					Enum.Material.Neon,
					{ CanCollide = false, CanQuery = false }
				)
				if i % 2 == 1 then
					deco(
						m,
						"Banner",
						Vector3.new(3.4, 9, 0.2),
						base * CFrame.new(5.5, WH - 9, -s * 0.8),
						i % 4 == 1 and theme.accent or theme.cover[1],
						Enum.Material.Fabric
					)
				end
			end
		end
	end
	block(
		m,
		"Lid",
		Vector3.new(H * 2 + 8, 1, H * 2 + 8),
		CFrame.new(c + Vector3.new(0, WH + 40, 0)),
		INK,
		nil,
		{ Transparency = 1, CanQuery = false }
	)

	-- spawns: along the north and south ends, the corners and the side edges
	local spawns, taken, houses = {}, {}, {}
	local function addSpawn(x, z)
		for _, q in spawns do
			if (q - (c + Vector3.new(x, 0, z))).Magnitude < 7 then
				return
			end
		end
		table.insert(spawns, c + Vector3.new(x, 0, z))
		table.insert(taken, { x, z, 2.5, 2.5 })
	end
	for _, s in { -1, 1 } do
		for _, u in { -0.85, -0.55, -0.25, 0, 0.25, 0.55, 0.85 } do
			addSpawn(u * H, s * (H - 5))
		end
		for _, v in { -0.5, 0, 0.5 } do
			addSpawn(s * (H - 5), v * H)
		end
	end

	-- the middle
	table.insert(taken, { 0, 0, 10, 10 })
	centerpiece(m, theme, look, c)

	-- sniper nests in the corners (two on small maps, four on bigger ones), bridges between them on large maps
	local nestSpots = { { 0.66, 0.66, 180 }, { -0.66, -0.66, 0 } }
	if rank >= 2 then
		table.insert(nestSpots, { -0.66, 0.66, 180 })
		table.insert(nestSpots, { 0.66, -0.66, 0 })
	end
	local tops = {}
	for _, ns in nestSpots do
		local x, z = ns[1] * H, ns[2] * H
		local base = CFrame.new(c + Vector3.new(x, 0, z)) * CFrame.Angles(0, math.rad(ns[3]), 0)
		local top, hx, hz = nest(m, theme, look, base, rng)
		table.insert(tops, top)
		-- the ramp sticks out along the nest's -X: reserve the whole footprint
		table.insert(taken, { x, z, hx, hz + 2 })
		table.insert(spawns, top + Vector3.new(0, 0.5, 0) - Vector3.new(0, 0, 0))
	end
	if rank >= 3 then
		for _, pair in { { 1, 3 }, { 2, 4 } } do
			local a, b = tops[pair[1]], tops[pair[2]]
			if a and b then
				local mid = (a + b) / 2
				local len = (a - b).Magnitude - 12
				block(
					m,
					"Bridge",
					Vector3.new(len, 0.8, 4),
					CFrame.lookAt(mid + Vector3.new(0, -0.4, 0), b + Vector3.new(0, -0.4, 0))
						* CFrame.Angles(0, math.rad(90), 0),
					look.floor
				)
				for _, side in { -1, 1 } do
					deco(
						m,
						"BridgeRail",
						Vector3.new(len, 1.2, 0.3),
						CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0.6, side * 2),
						look.trim,
						nil,
						{ CanCollide = true }
					)
				end
			end
		end
	end

	-- the mirrored layout
	for _, item in LAYOUT do
		local kind, u, v, rot, minSize = item[1], item[2], item[3], item[4], item[5]
		if rank >= SIZE_RANK[minSize] then
			for _, mirror in { 1, -1 } do
				local x, z = u * H * mirror, v * H * mirror
				local base = CFrame.new(c + Vector3.new(x, 0, z))
					* CFrame.Angles(0, math.rad(rot + (mirror == -1 and 180 or 0)), 0)
				if kind == "building" then
					local w, d = 13, rank >= 2 and 18 or 15
					if not overlaps(taken, x, z, w / 2 + 4, d / 2 + 2, 1) then
						local hx, hz = building(m, theme, look, base, w, d, rng)
						table.insert(taken, { x, z, hx, hz })
						table.insert(houses, { base = base, w = w, d = d })
						-- a spawn on the roof deck
						table.insert(spawns, (base * CFrame.new(-w / 4, MapBuilder.STOREY + 1, 0)).Position)
					end
				else
					local builder = PIECES[kind]
					-- try the spot as designed; skip it if something's already there
					local probe = Instance.new("Model")
					local hx, hz = builder(probe, theme, look, base, rng)
					local turned = (rot % 180) ~= 0
					if turned then
						hx, hz = hz, hx
					end
					if overlaps(taken, x, z, hx, hz, 1) then
						probe:Destroy()
					else
						for _, child in probe:GetChildren() do
							child.Parent = m
						end
						probe:Destroy()
						table.insert(taken, { x, z, hx, hz })
					end
				end
			end
		end
	end

	-- lamps along the lanes, and bushes or flowers by the walls
	for _, u in { -0.55, 0.55 } do
		for _, v in { -0.85, -0.3, 0.3, 0.85 } do
			local x, z = u * H + 5, v * H
			if not overlaps(taken, x, z, 0.5, 0.5, 1) then
				lamp(m, theme, look, CFrame.new(c + Vector3.new(x, 0, z)))
			end
		end
	end
	for i = 1, 10 + rank * 4 do
		local side = i % 4
		local t = rng:NextNumber(-H + 6, H - 6)
		local x = side == 0 and (H - 1.5) or (side == 1 and -(H - 1.5) or t)
		local z = side == 2 and (H - 1.5) or (side == 3 and -(H - 1.5) or t)
		if not overlaps(taken, x, z, 1.5, 1.5, 0.5) then
			local p = CFrame.new(c + Vector3.new(x, 0, z))
			if theme.props == "dock" then
				deco(m, "Hazard", Vector3.new(3, 0.25, 3), p * CFrame.new(0, 0.13, 0), rgb(255, 200, 40))
			elseif theme.props == "candy" then
				ball(
					m,
					"Gumdrop",
					2.4,
					p * CFrame.new(0, 1, 0),
					theme.cover[rng:NextInteger(1, #theme.cover)],
					nil,
					{ CanCollide = false }
				)
			else
				ball(m, "Bush", 3, p * CFrame.new(0, 1.2, 0), rgb(80, 160, 70), nil, { CanCollide = false })
				ball(
					m,
					"Flower",
					0.7,
					p * CFrame.new(0.6, 2.6, 0.4),
					theme.cover[rng:NextInteger(1, #theme.cover)],
					Enum.Material.Neon,
					{ CanCollide = false, CanQuery = false }
				)
			end
		end
	end

	skyline(m, theme, look, c, H, rng)
	dress(m, theme, look, c, H, rank, rng, taken, houses)
	m.Parent = parent
	return {
		model = m,
		spawns = spawns,
		center = c,
		half = H,
		floorY = c.Y,
		key = theme.key,
		name = theme.name,
		size = size.key,
	}
end

return MapBuilder

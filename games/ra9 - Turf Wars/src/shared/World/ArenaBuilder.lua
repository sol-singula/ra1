--[[
The reusable arena (master plan §4): what every map shares, plus the shapes a map is made of.

Every map is a battlefield along X (red base at -X, blue at +X) on a floor of turf strips, one per 4-stud cell,
coloured by the frontline. Round it: solid walls, an invisible shell up to a ceiling, and a kill plane below. At
each end, a spawn zone with pads and its team's colour. In between, the map's own architecture, built by its file
in World/Maps with the shapes below, mirrored so both sides play the same.

The look (§0): SUPERHOT. White and light grey, smooth matte plastic, no textures; detail comes from shapes (bases
and capitals on columns, steps, ledges, railings, window frames).

  local arena = ArenaBuilder.build(mapDef, parent)
  arena = {
    folder, def, length, width, half, spawnDepth,
    solids = { { min, max, part } },     every solid box (projectiles and building use these)
    spawns = { red = { CFrame }, blue = { CFrame } },
    strips = { [i] = Part },             the turf, west to east; strip i covers x in [x0 + (i-1)*CELL, x0 + i*CELL)
    blocked = { [cx] = { [cz] = true } } cells a tall map shape stands in (the lane rule)
    marker, glow                          the frontline: a glowing line on the floor (and its soft glow), coloured by the last push
  }
  ArenaBuilder.paint(arena, frontline, team?)   recolour the turf and move the glowing line; team: who pushed it
                                                last (its colour), nil = white (a new match)
  ArenaBuilder.bounds(arena)              the playable box (min, max)
]]
local Constants = require(script.Parent.Parent.Constants)
local Formulas = require(script.Parent.Parent.Formulas)

local ArenaBuilder = {}

local CELL = Constants.CELL

-- The shapes a map is made of --------------------------------------------------------------------------------------
local Shapes = {}
Shapes.__index = Shapes

local function aabbOf(cf, size)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = cf * Vector3.new(hx * sx, hy * sy, hz * sz)
				mn = Vector3.new(math.min(mn.X, p.X), math.min(mn.Y, p.Y), math.min(mn.Z, p.Z))
				mx = Vector3.new(math.max(mx.X, p.X), math.max(mx.Y, p.Y), math.max(mx.Z, p.Z))
			end
		end
	end
	return mn, mx
end
ArenaBuilder.aabbOf = aabbOf

function Shapes:part(className, cf, size, opts)
	opts = opts or {}
	local p = Instance.new(className)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.Color = opts.color or self.white
	p.Transparency = opts.transparency or 0
	p.CanCollide = opts.collide ~= false
	p.CastShadow = opts.shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = opts.name or "Shape"
	if opts.reflect then
		p.Reflectance = opts.reflect
	end
	p.Parent = opts.parent or self.folder
	if p.CanCollide and opts.solid ~= false then
		local mn, mx = aabbOf(cf, size)
		table.insert(self.solids, { min = mn, max = mx, part = p })
	end
	return p
end

-- A box. pos: its centre (Vector3) or a CFrame.
function Shapes:box(pos, size, opts)
	local cf = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	return self:part("Part", cf, size, opts)
end

-- A box standing on the floor: (x, z) its centre, w along X, d along Z, h tall, from y0 (default the floor).
function Shapes:block(x, z, w, d, h, opts, y0)
	return self:box(Vector3.new(x, (y0 or 0) + h / 2, z), Vector3.new(w, h, d), opts)
end

function Shapes:wedge(cf, size, opts)
	return self:part("WedgePart", cf, size, opts)
end

-- A round column with a square base and capital (the detail that makes a plain world read as architecture).
function Shapes:column(x, z, h, r, opts)
	opts = opts or {}
	local base = r * 2 + 1.2
	self:block(x, z, base, base, 1, { color = self.light })
	self:block(x, z, base - 0.6, base - 0.6, 0.5, { color = self.white }, 1)
	local shaft = Instance.new("Part")
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Anchored = true
	shaft.Size = Vector3.new(h - 3, r * 2, r * 2)
	shaft.CFrame = CFrame.new(x, 1.5 + (h - 3) / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Color = opts.color or self.white
	shaft.TopSurface = Enum.SurfaceType.Smooth
	shaft.BottomSurface = Enum.SurfaceType.Smooth
	shaft.Name = "Column"
	shaft.Parent = self.folder
	-- (the shaft collides as its square: close enough, and never lets an arrow through a gap that isn't there)
	table.insert(
		self.solids,
		{ min = Vector3.new(x - r, 1.5, z - r), max = Vector3.new(x + r, h - 1.5, z + r), part = shaft }
	)
	self:block(x, z, base - 0.6, base - 0.6, 0.5, { color = self.white }, h - 1.5)
	self:block(x, z, base, base, 1, { color = self.light }, h - 1)
end

-- A square pillar with plinth and cap.
function Shapes:pillar(x, z, h, s, opts)
	opts = opts or {}
	self:block(x, z, s + 1, s + 1, 1, { color = self.light })
	self:block(x, z, s, s, h - 2, { color = opts.color or self.white }, 1)
	self:block(x, z, s + 1, s + 1, 1, { color = self.light }, h - 1)
end

-- An arch across an opening: two piers and a lintel with a stepped soffit. along: "x" or "z" (the way you walk through).
function Shapes:arch(x, z, span, h, depth, along, opts)
	opts = opts or {}
	local pier = opts.pier or 3
	local alongX = along == "x"
	local function at(off, w, hh, y0, color)
		if alongX then
			self:block(x, z + off, depth, w, hh, { color = color or self.white }, y0)
		else
			self:block(x + off, z, w, depth, hh, { color = color or self.white }, y0)
		end
	end
	local half = span / 2 + pier / 2
	at(-half, pier, h, 0)
	at(half, pier, h, 0)
	at(0, span + pier * 2, 3, h, self.white) -- the lintel
	at(0, span + pier * 2 + 1, 0.8, h + 3, self.light) -- the cornice
	-- the stepped soffit: two blocks that round the opening's top corners
	at(-span / 2 + 0.75, 1.5, 1.5, h - 1.5, self.light)
	at(span / 2 - 0.75, 1.5, 1.5, h - 1.5, self.light)
end

-- Steps up to a height: from (x, z), climbing toward dir ("+x" | "-x" | "+z" | "-z"), width w.
function Shapes:stairs(x, z, dir, steps, rise, run, w, opts)
	opts = opts or {}
	for i = 1, steps do
		local h = rise * i
		local off = run * (i - 0.5)
		local cx, cz = x, z
		local sx, sz = run, w
		if dir == "+x" then
			cx = x + off
		elseif dir == "-x" then
			cx = x - off
		elseif dir == "+z" then
			cz, sx, sz = z + off, w, run
		else
			cz, sx, sz = z - off, w, run
		end
		self:block(cx, cz, sx, sz, h, { color = (i % 2 == 0) and self.white or self.light })
	end
end

-- A railing along a line at height y: posts and a top rail (low enough to shoot over, high enough to read).
function Shapes:railing(a, b, y, opts)
	opts = opts or {}
	local d = b - a
	local len = d.Magnitude
	local n = math.max(2, math.floor(len / 4) + 1)
	for i = 0, n - 1 do
		local p = a + d * (i / (n - 1))
		self:block(p.X, p.Z, 0.5, 0.5, 2.6, { color = self.grey, solid = false }, y)
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, y + 2.8, mid.Z), Vector3.new(b.X, y + 2.8, b.Z))
	self:box(cf, Vector3.new(0.5, 0.4, len), { color = self.white, solid = false })
end

-- A wall with window openings: along X from x0 to x1 at z (or along Z), h tall, t thick, windows: count.
function Shapes:windowWall(x0, x1, z, h, t, windows, alongZ)
	local len = math.abs(x1 - x0)
	local mid = (x0 + x1) / 2
	local function seg(c, l, hh, y0, color)
		if alongZ then
			self:block(z, c, t, l, hh, { color = color or self.white }, y0)
		else
			self:block(c, z, l, t, hh, { color = color or self.white }, y0)
		end
	end
	if windows <= 0 then
		seg(mid, len, h, 0)
		return
	end
	local sill, top = 3, h - 3
	seg(mid, len, sill, 0) -- below the windows
	seg(mid, len, h - top, top) -- above
	local pane = len / (windows * 2 + 1)
	local start = math.min(x0, x1)
	for i = 0, windows do
		local c = start + pane * (i * 2 + 0.5)
		seg(c, pane, top - sill, sill, self.light) -- the mullions between openings
	end
	-- the sill ledge: a thin line that catches the light
	if alongZ then
		self:block(z, mid, t + 0.6, len, 0.4, { color = self.white, solid = false }, sill)
	else
		self:block(mid, z, len, t + 0.6, 0.4, { color = self.white, solid = false }, sill)
	end
end

-- A faceted shard (ice, crystal): a block tilted on two axes, with a smaller one leaning on it.
function Shapes:shard(x, z, w, h, tiltX, tiltZ, opts)
	opts = opts or {}
	local cf = CFrame.new(x, h / 2 - 1, z)
		* CFrame.Angles(math.rad(tiltX or 0), math.rad(opts.yaw or 0), math.rad(tiltZ or 0))
	self:box(cf, Vector3.new(w, h, w * 0.8), { color = opts.color or self.white })
	local cf2 = CFrame.new(x + w * 0.45, h * 0.3, z - w * 0.3)
		* CFrame.Angles(math.rad(-(tiltX or 0) * 1.3), math.rad(30), math.rad(-(tiltZ or 0)))
	self:box(cf2, Vector3.new(w * 0.55, h * 0.55, w * 0.45), { color = opts.color2 or self.light })
end

-- Detail pieces (looks only: nothing here stops an arrow or a builder) ---------------------------------------------
local function deco(opts)
	opts = opts or {}
	opts.solid = false
	if opts.collide == nil then
		opts.collide = false
	end
	return opts
end
ArenaBuilder.deco = deco

-- The team colour for a half: s = -1 red, 1 blue
function Shapes:teamColor(s)
	return Constants.TEAM_COLOR[s < 0 and "red" or "blue"]
end

-- A lamp post: a slim post on a plinth, an arm and a glowing cube (colour: the light's, default white)
function Shapes:lamp(x, z, h, color)
	self:block(x, z, 1.4, 1.4, 0.6, deco({ color = self.light, collide = true }))
	self:block(x, z, 0.5, 0.5, h, deco({ color = self.white, collide = true }), 0.6)
	self:block(x, z, 1.2, 1.2, 0.3, deco({ color = self.light }), h + 0.6)
	self:block(
		x,
		z,
		0.9,
		0.9,
		0.9,
		deco({ color = color or Color3.fromRGB(255, 255, 255), material = Enum.Material.Neon }),
		h + 0.9
	)
	self:block(x, z, 1.3, 1.3, 0.25, deco({ color = self.light }), h + 1.8)
end

-- A team banner hanging on a wall: a rod, the cloth in the team's colour with a white stripe, a pointed foot.
-- (x, z) the wall face, facing: +1 / -1 the way the banner faces along Z (it hangs on a long wall)
function Shapes:banner(x, z, s, facing, y, h)
	local c = self:teamColor(s)
	y = y or 10
	h = h or 9
	local zf = z + facing * 0.35
	self:block(x, zf, 4.2, 0.4, 0.4, deco({ color = self.white }), y + h)
	self:block(x, zf, 3.2, 0.2, h - 1.2, deco({ color = c }), y + 1.2)
	self:block(x, zf + facing * 0.05, 0.6, 0.2, h - 1.6, deco({ color = Constants.WHITE }), y + 1.4)
	self:wedge(
		CFrame.new(x - 0.8, y + 0.6, zf) * CFrame.Angles(0, math.rad(90), math.rad(180)),
		Vector3.new(0.2, 1.2, 1.6),
		deco({ color = c })
	)
	self:wedge(
		CFrame.new(x + 0.8, y + 0.6, zf) * CFrame.Angles(0, math.rad(-90), math.rad(180)),
		Vector3.new(0.2, 1.2, 1.6),
		deco({ color = c })
	)
end

-- A flag on a pole (on a tower top, a gate): the pole, a ball, the flag in the team's colour
function Shapes:flag(x, z, y, s)
	self:block(x, z, 0.35, 0.35, 8, deco({ color = self.white }), y)
	self:block(x, z, 0.7, 0.7, 0.7, deco({ color = self.light }), y + 8)
	self:block(x - s * 1.8, z, 3.4, 0.15, 2.2, deco({ color = self:teamColor(s) }), y + 5.4)
end

-- A stack of crates: low cover where it stands (the bottom ones are solid), lids and bands for detail
function Shapes:crates(x, z, n, yaw)
	local cf0 = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
	local spots = { { 0, 0, 0 }, { 2.6, 0, 0.3 }, { 1.2, 2.4, 0.1 }, { -0.2, 0, 2.5 } }
	for i = 1, math.min(n or 3, #spots) do
		local sp = spots[i]
		local cf = cf0 * CFrame.new(sp[1], 1.2 + sp[2], sp[3]) * CFrame.Angles(0, math.rad(i * 9), 0)
		self:box(cf, Vector3.new(2.4, 2.4, 2.4), { color = (i % 2 == 0) and self.light or self.white })
		self:box(cf * CFrame.new(0, 0, 0), Vector3.new(2.5, 0.3, 2.5), deco({ color = self.grey }))
		self:box(cf * CFrame.new(0, 1.15, 0), Vector3.new(2.0, 0.15, 2.0), deco({ color = self.light }))
	end
end

-- Steps of rubble: a few small tilted blocks scattered round a point (looks only)
function Shapes:rubble(x, z, n, seed)
	local r = Random.new(seed or 1)
	for i = 1, n or 5 do
		local a = r:NextNumber(0, math.pi * 2)
		local d = r:NextNumber(0.5, 3)
		local sz = r:NextNumber(0.5, 1.4)
		self:box(
			CFrame.new(x + math.cos(a) * d, sz / 2 - 0.1, z + math.sin(a) * d)
				* CFrame.Angles(r:NextNumber(-0.4, 0.4), r:NextNumber(0, 3), r:NextNumber(-0.4, 0.4)),
			Vector3.new(sz, sz * 0.7, sz * 1.1),
			deco({ color = (i % 2 == 0) and self.light or self.grey })
		)
	end
end

-- Both halves at once: fn(s) runs for s = -1 (red's half, -X) and s = 1 (blue's, +X), so maps stay fair.
function Shapes:mirror(fn)
	fn(-1)
	fn(1)
end

-- The arena ---------------------------------------------------------------------------------------------------
function ArenaBuilder.build(def, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	local length, width = def.length or 200, def.width or 96
	local half = length / 2
	local spawnDepth = def.spawnDepth or 20
	local palette = def.palette or {}
	local shapes = setmetatable({
		folder = Instance.new("Folder"),
		solids = {},
		white = palette.white or Constants.WHITE,
		light = palette.light or Constants.LIGHT,
		grey = palette.grey or Constants.GREY,
		dark = palette.dark or Constants.DARK,
		length = length,
		width = width,
		half = half,
		spawnDepth = spawnDepth,
	}, Shapes)
	shapes.folder.Name = "Map"
	shapes.folder.Parent = folder

	-- the turf: one strip per cell along X, the full width
	local turf = Instance.new("Folder")
	turf.Name = "Turf"
	turf.Parent = folder
	local strips = {}
	local n = math.floor(length / CELL)
	for i = 1, n do
		local x = -half + (i - 0.5) * CELL
		local p = Instance.new("Part")
		p.Name = "Strip" .. i
		p.Anchored = true
		p.Size = Vector3.new(CELL, 2, width)
		p.CFrame = CFrame.new(x, -1, 0)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Color = Constants.WHITE
		p.Parent = turf
		strips[i] = p
	end
	-- (the floor is one solid box for projectiles; the strips are only its colour)
	table.insert(
		shapes.solids,
		{ min = Vector3.new(-half, -2, -width / 2), max = Vector3.new(half, 0, width / 2), part = strips[1] }
	)

	-- the walls round it: visible to 26 studs, then an invisible shell up to the ceiling (nobody leaves)
	local wallH, ceiling, t = def.wallHeight or 26, def.ceiling or 70, 4
	local function shell(cx, cz, sx, sz)
		shapes:box(Vector3.new(cx, wallH / 2, cz), Vector3.new(sx, wallH, sz), { color = shapes.light, name = "Wall" })
		shapes:box(
			Vector3.new(cx, wallH + (ceiling - wallH) / 2, cz),
			Vector3.new(sx, ceiling - wallH, sz),
			{ transparency = 1, shadow = false, name = "Shell", solid = true }
		)
	end
	shell(0, -width / 2 - t / 2, length + t * 2, t)
	shell(0, width / 2 + t / 2, length + t * 2, t)
	shell(-half - t / 2, 0, t, width)
	shell(half + t / 2, 0, t, width)
	shapes:box(
		Vector3.new(0, ceiling + 1, 0),
		Vector3.new(length + 8, 2, width + 8),
		{ transparency = 1, shadow = false, name = "Ceiling" }
	)
	-- the walls' detail: a plinth and a coping line all round
	for _, zz in { -1, 1 } do
		shapes:block(0, zz * (width / 2 - 0.5), length, 1, 1.2, { color = shapes.grey, solid = false })
		shapes:block(0, zz * (width / 2 + 0.5), length + 8, 1.6, 1, { color = shapes.white, solid = false }, wallH)
	end

	-- the long walls' detail: pilasters every 20 studs with a lamp, recessed panels between, a banner in each
	-- half's colour, a cornice at the top
	for _, zz in { -1, 1 } do
		local face = zz * (width / 2)
		for x = -half + 30, half - 30, 20 do
			shapes:block(x, face - zz * 0.6, 2.4, 1.2, wallH, { color = shapes.white, solid = false })
			shapes:block(x, face - zz * 1.0, 3, 1.4, 1.2, deco({ color = shapes.light }))
			shapes:block(
				x,
				face - zz * 1.4,
				0.8,
				0.8,
				0.8,
				deco({ color = Color3.new(1, 1, 1), material = Enum.Material.Neon }),
				wallH - 4
			)
		end
		for x = -half + 40, half - 40, 20 do
			shapes:block(x, face - zz * 0.15, 14, 0.3, 14, deco({ color = shapes.white }), 5)
			shapes:block(x, face - zz * 0.3, 12, 0.3, 12, deco({ color = shapes.grey }), 6)
			shapes:block(x, face - zz * 0.45, 11, 0.3, 11, deco({ color = shapes.light }), 6.5)
		end
		for _, sx in { -1, 1 } do
			for _, k in { 30, 50 } do
				shapes:banner(sx * (half - k), face, sx, -zz, 9, 10)
			end
		end
		shapes:block(0, face - zz * 0.8, length, 1.6, 0.8, deco({ color = shapes.white }), wallH - 1.5)
	end

	-- beyond the walls: a skyline of white monoliths fading into the haze, so the world never ends at a wall
	local r = Random.new(def.seed or #def.key * 97)
	for i = 1, 70 do
		local a = (i / 70) * math.pi * 2 + r:NextNumber(-0.04, 0.04)
		local rx, rz = (half + 90) + r:NextNumber(0, 160), (width / 2 + 90) + r:NextNumber(0, 160)
		local x, z = math.cos(a) * rx, math.sin(a) * rz
		local w, d, h = r:NextNumber(12, 36), r:NextNumber(12, 36), r:NextNumber(24, 80)
		local c = (i % 3 == 0) and shapes.light or ((i % 3 == 1) and shapes.white or shapes.grey)
		local p = shapes:box(Vector3.new(x, h / 2 - 2, z), Vector3.new(w, h, d), deco({ color = c, shadow = false }))
		p.Name = "Skyline"
		if i % 4 == 0 then
			shapes:box(
				Vector3.new(x, h - 2 + 1.5, z),
				Vector3.new(w * 0.6, 3, d * 0.6),
				deco({ color = shapes.white, shadow = false })
			)
		end
	end
	-- the ground out there: one wide pale floor, below the arena's, so nothing below the walls is ever empty
	local ground = shapes:box(
		Vector3.new(0, -2.5, 0),
		Vector3.new(length + 600, 1, width + 600),
		deco({ color = shapes.light, shadow = false })
	)
	ground.Name = "Ground"

	-- the spawn rooms (no spawn killing): pads in the team's colour inside a walled, roofed room. Its front wall has
	-- two doors; just inside, a long baffle wall stands between the doors and the pads, so nobody outside can see or
	-- shoot a pad: you leave round the baffle's ends, along the corridor behind the front wall, and out of a door.
	-- The roof (frames and glass) stops arrows lobbed over. Distances are from the team's own end wall (d).
	local spawns = { red = {}, blue = {} }
	local room = ArenaBuilder.room(width, spawnDepth)
	for _, team in Constants.TEAMS do
		local s = team == "red" and -1 or 1
		local color = Constants.TEAM_COLOR[team]
		local function X(d)
			return s * (half - d)
		end
		local zoneX = X(spawnDepth / 2)
		shapes:block(zoneX, 0, spawnDepth, width - 2, 0.2, { color = shapes.light, collide = false, solid = false }, 0)
		for row = -2, 2 do
			for _, d in room.pads do
				local px, pz = X(d), row * 14
				local pad =
					shapes:block(px, pz, 4.5, 4.5, 0.3, { color = color, material = Enum.Material.Neon, solid = false })
				pad.Name = team .. "Pad"
				-- a ring round the pad: a step you read from across the room
				shapes:block(px, pz, 5.6, 5.6, 0.15, { color = shapes.white, collide = false, solid = false })
				table.insert(spawns[team], CFrame.lookAt(Vector3.new(px, 3.5, pz), Vector3.new(0, 3.5, pz)))
			end
		end
		-- the spawn line: a thin bar in the team's colour across the floor, where the base ends
		shapes:block(
			X(spawnDepth),
			0,
			0.6,
			width,
			0.25,
			{ color = color, material = Enum.Material.Neon, solid = false }
		)
		-- the front wall, with its two doors (and lintels over them)
		local fd = (room.front0 + room.front1) / 2
		local ft = room.front1 - room.front0
		local edges = { -width / 2 }
		for _, side in { -1, 1 } do
			for _, e in { room.gapMid - room.gapHalf, room.gapMid + room.gapHalf } do
				table.insert(edges, side * e)
			end
		end
		table.insert(edges, width / 2)
		table.sort(edges)
		for i = 1, #edges, 2 do
			local z0, z1 = edges[i], edges[i + 1]
			shapes:block(X(fd), (z0 + z1) / 2, ft, z1 - z0, room.height, { color = shapes.white, name = "SpawnWall" })
			-- pilasters on its face toward the field, and a plinth
			for z = z0 + 3, z1 - 3, 8 do
				shapes:block(X(room.front1 + 0.4), z, 0.8, 1.6, room.height, { color = shapes.light, solid = false })
			end
			shapes:block(X(room.front1 + 0.3), (z0 + z1) / 2, 0.6, z1 - z0, 1, { color = shapes.grey, solid = false })
		end
		for _, side in { -1, 1 } do
			local gz = side * room.gapMid
			shapes:block(X(fd), gz, ft, room.gapHalf * 2, room.height - room.door, { color = shapes.white }, room.door)
			-- the door frame: a team-coloured line round it
			shapes:block(X(room.front1 + 0.1), gz, 0.3, room.gapHalf * 2 + 0.6, 0.4, {
				color = color,
				material = Enum.Material.Neon,
				solid = false,
			}, room.door)
			for _, e in { -1, 1 } do
				shapes:block(X(room.front1 + 0.1), gz + e * (room.gapHalf + 0.15), 0.3, 0.3, room.door, {
					color = color,
					material = Enum.Material.Neon,
					solid = false,
				})
			end
		end
		-- a coping and a team band along the wall's top
		shapes:block(X(fd), 0, ft + 0.8, width, 0.6, { color = shapes.light, solid = false }, room.height)
		shapes:block(X(room.front1 + 0.05), 0, 0.2, width, 0.5, {
			color = color,
			material = Enum.Material.Neon,
			solid = false,
		}, room.height - 1.6)
		-- the baffle inside, with a bench along its back (the pads' side)
		local bd = (room.baffle0 + room.baffle1) / 2
		shapes:block(X(bd), 0, room.baffle1 - room.baffle0, room.baffleHalf * 2, room.baffleH, {
			color = shapes.light,
			name = "Baffle",
		})
		shapes:block(X(bd), 0, room.baffle1 - room.baffle0 + 0.6, room.baffleHalf * 2 + 0.6, 0.4, {
			color = shapes.white,
			solid = false,
		}, room.baffleH)
		shapes:block(
			X(room.baffle0 - 0.6),
			0,
			1.2,
			room.baffleHalf * 2 - 4,
			1.4,
			{ color = shapes.white, solid = false }
		)
		-- the roof: frames (beams across the room) with glass between, so the light still comes in
		local rd = room.front1 / 2
		shapes:box(Vector3.new(X(rd), room.height + 0.5, 0), Vector3.new(room.front1, 1, width), {
			color = color:Lerp(Color3.new(1, 1, 1), 0.75),
			material = Enum.Material.Glass,
			transparency = 0.55,
			shadow = false,
			name = "SpawnRoof",
		})
		for z = -width / 2 + 6, width / 2 - 6, 12 do
			shapes:block(X(rd), z, room.front1, 1, 1.2, { color = shapes.white, solid = false }, room.height + 0.9)
		end
		shapes:block(X(room.front1 - 0.5), 0, 1, width, 1.2, { color = shapes.white, solid = false }, room.height + 0.9)
		-- the back wall's arches (detail on the base end)
		for k = -2, 2 do
			shapes:block(X(1.5), k * 17, 3, 3, wallH, { color = shapes.white })
		end
		shapes:block(X(1), 0, 2, width, 2, { color = color, material = Enum.Material.Neon, solid = false }, wallH - 4)
	end

	-- the map's own architecture
	if def.build then
		def.build(shapes)
	end

	-- the frontline: a big glowing line ON the floor across the field (nothing standing up, so both teams always see
	-- each other over it), in the colour of the team that pushed it last, with a wide soft glow round it
	local function glowPart(name, w, h, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 255, 255)
		p.Transparency = transparency
		p.Size = Vector3.new(w, h, width)
		p.CFrame = CFrame.new(0, h / 2 + 0.02, 0)
		p.Parent = folder
		return p
	end
	local marker = glowPart("Frontline", 1.6, 0.3, 0)
	local glow = glowPart("FrontlineGlow", 7, 0.08, 0.55)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Top
	light.Angle = 120
	light.Range = 14
	light.Brightness = 3
	light.Color = marker.Color
	light.Parent = marker

	-- cells a tall map shape stands in (for the lane rule): any solid between 0.5 and 5 studs up in that cell
	local blocked = {}
	for _, s in shapes.solids do
		if s.max.Y > 0.6 and s.min.Y < 5 and s.part ~= strips[1] and s.max.Y - math.max(s.min.Y, 0) >= 3 then
			local c0x, c0z = Formulas.cellOf(s.min.X + 0.01, s.min.Z + 0.01)
			local c1x, c1z = Formulas.cellOf(s.max.X - 0.01, s.max.Z - 0.01)
			for cx = c0x, c1x do
				blocked[cx] = blocked[cx] or {}
				for cz = c0z, c1z do
					blocked[cx][cz] = true
				end
			end
		end
	end

	folder:SetAttribute("Map", def.key)
	folder.Parent = parent
	local arena = {
		folder = folder,
		def = def,
		length = length,
		width = width,
		half = half,
		spawnDepth = spawnDepth,
		solids = shapes.solids,
		spawns = spawns,
		strips = strips,
		blocked = blocked,
		marker = marker,
		glow = glow,
		ceiling = ceiling,
	}
	arena.room = room
	return arena
end

-- The spawn room's measures, in studs from the team's own end wall (d) and across the field (z):
--   pads (d of the two pad columns), baffle0/baffle1 (the baffle's faces), baffleHalf (it spans |z| <= this),
--   front0/front1 (the front wall's faces), gapMid/gapHalf (the doors: |z| within gapMid +- gapHalf),
--   height (walls and roof), door (a door's height), baffleH
function ArenaBuilder.room(width, spawnDepth)
	return {
		pads = { 4, 8.5 },
		baffle0 = 11.5,
		baffle1 = 13,
		baffleHalf = math.min(26, width / 2 - 12),
		front0 = spawnDepth - 3,
		front1 = spawnDepth - 1,
		gapMid = 14,
		gapHalf = 4,
		height = 12,
		door = 9,
		baffleH = 10,
	}
end

-- Inside a team's spawn room? (behind its front wall)
function ArenaBuilder.inRoom(arena, team, pos)
	local s = team == "red" and -1 or 1
	return arena.half - s * pos.X < arena.room.front1 + 0.5
end

-- The way out of the spawn room: where to walk next from pos to reach goal (goal itself when there's nothing in
-- the way). Round the baffle's end on your side, along the corridor, out of the door.
function ArenaBuilder.route(arena, team, pos, goal)
	local r = arena.room
	if not r then
		return goal
	end
	local s = team == "red" and -1 or 1
	local function d(p)
		return arena.half - s * p.X
	end
	local function at(dd, z)
		return Vector3.new(s * (arena.half - dd), pos.Y, z)
	end
	local dp, dg = d(pos), d(goal)
	if dp >= r.front1 + 0.5 or dg < r.front0 then
		return goal -- (already out, or staying in)
	end
	local side = math.abs(pos.Z) > 1 and math.sign(pos.Z) or (goal.Z >= 0 and 1 or -1)
	local corridor = (r.baffle1 + r.front0) / 2
	if dp < r.baffle1 + 0.8 and (dp < r.baffle0 or math.abs(pos.Z) >= r.baffleHalf) then
		if math.abs(pos.Z) < r.baffleHalf + 2 then
			return at(r.baffle0 - 2, side * (r.baffleHalf + 4)) -- (along the baffle's back to its end)
		end
		return at(corridor, side * (r.baffleHalf + 4)) -- (round the end)
	end
	local gz = side * r.gapMid
	if dp < r.front0 and math.abs(pos.Z - gz) > r.gapHalf - 1.2 then
		return at(corridor, gz) -- (along the corridor to the door)
	end
	return at(r.front1 + 4, gz) -- (out of the door)
end

-- Recolour the turf for this frontline, and move the glowing line onto it in the colour of the team that pushed it
-- last (white when nobody has yet).
function ArenaBuilder.paint(arena, frontline, team)
	for i, strip in arena.strips do
		local x = -arena.half + (i - 0.5) * CELL
		local side = Formulas.sideOf(x, frontline)
		local base = Constants.TURF_COLOR[side]
		-- every other strip a shade lighter: the grid reads without a texture
		strip.Color = (i % 2 == 0) and base:Lerp(Color3.new(1, 1, 1), 0.12) or base
	end
	local color = Constants.TEAM_COLOR[team or ""] or Color3.fromRGB(255, 255, 255)
	local m = arena.marker
	m.CFrame = CFrame.new(frontline, m.Size.Y / 2 + 0.02, 0)
	m.Color = color
	local light = m:FindFirstChildOfClass("SurfaceLight")
	if light then
		light.Color = color
	end
	if arena.glow then
		arena.glow.CFrame = CFrame.new(frontline, arena.glow.Size.Y / 2 + 0.02, 0)
		arena.glow.Color = color
	end
	arena.lastTeam = team
end

-- Where a team loses: the frontline reaching its spawn zone's edge.
function ArenaBuilder.loseLine(arena, team)
	local edge = arena.half - arena.spawnDepth
	return team == "red" and -edge or edge
end

function ArenaBuilder.bounds(arena)
	return Vector3.new(-arena.half, -30, -arena.width / 2), Vector3.new(arena.half, arena.ceiling, arena.width / 2)
end

ArenaBuilder.Shapes = Shapes

return ArenaBuilder

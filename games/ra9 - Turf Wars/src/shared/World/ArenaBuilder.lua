--[[
The reusable arena (master plan §4): what every map shares, plus the shapes a map is made of.

Every map is a battlefield along X (red base at -X, blue at +X) on a floor of turf strips, one per 4-stud cell,
coloured by the frontline. Round it: solid walls, an invisible shell up to a ceiling, and a kill plane below. At
each end, a spawn zone with pads and its team's colour. In between, the map's own architecture, built by its file
in World/Maps with the shapes below, mirrored so both sides play the same.

The look (§0): SUPERHOT. White and light grey, smooth matte plastic, no textures; detail comes from shapes (bases
and capitals on columns, steps, ledges, railings, window frames).

  local arena = ArenaBuilder.build(mapDef, parent, scale)   scale: how many people are in the match (or a tier's
                                                             name); it picks the size (ArenaBuilder.SIZES)
  arena = {
    folder, def, length, width, half, spawnDepth, tier,
    solids = { { min, max, part } },     every solid box (projectiles and building use these)
    collide = { { min, max } },          every box a body bumps into, solid or not (the bots' walking grid)
    spawns = { red = { CFrame }, blue = { CFrame } },
    shopSigns = { red = Part, blue = Part }   the shop sign's board on each deck (looks only; ShopSignController)
    strips = { [i] = Part },             the turf, west to east; strip i covers x in [x0 + (i-1)*CELL, x0 + i*CELL)
    blocked = { [cx] = { [cz] = true } } cells a tall map shape stands in (the lane rule)
    marker, glow                          the frontline: a glowing line on the floor (and its soft glow), coloured by the last push
  }
  ArenaBuilder.paint(arena, frontline, team?)   recolour the turf and move the glowing line; team: who pushed it
                                                last (its colour), nil = white (a new match)
  ArenaBuilder.bounds(arena)              the playable box (min, max)
  ArenaBuilder.tier(scale)                "small" (up to 9 people) | "medium" (10 to 19) | "large" (20 to 29) | "huge" (30 and up)

Sizes: a map is drawn for the small arena (200 x 96); a bigger tier adds whole cells to the length (so the turf
takes longer to push) and to the width, with the spawn decks as deep as ever. Maps place their shapes through
A:fx / A:fz (distances stretched to this arena) and A.W / A.edge / A.tier, so every size is the same map, mirrored.
Height: the walls stand wallHeight tall with bays of pilasters, windows and balconies, and the shapes below
(towers, colonnades under entablatures, statues, platforms with stairs, trees) give a map its skyline.
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
	if not p.CanCollide then
		-- (pure looks: nothing asks about it, nothing touches it, and the small bits cast no shadow)
		p.CanQuery = false
		p.CanTouch = false
		if opts.shadow == nil and math.max(size.X, size.Y, size.Z) < 4 then
			p.CastShadow = false
		end
	end
	p.Parent = opts.parent or self.folder
	if p.CanCollide then
		local mn, mx = aabbOf(cf, size)
		-- (everything a body bumps into, solid to arrows or not: the bots' walking grid reads this)
		table.insert(self.collide, { min = mn, max = mx })
		if opts.solid ~= false then
			table.insert(self.solids, { min = mn, max = mx, part = p })
		end
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

-- A round column with a square base and capital (the detail that makes a plain world read as architecture), standing
-- on opts.y0 (default the floor).
function Shapes:column(x, z, h, r, opts)
	opts = opts or {}
	local y0 = opts.y0 or 0
	local base = r * 2 + 1.2
	self:block(x, z, base, base, 1, { color = self.light }, y0)
	self:block(x, z, base - 0.6, base - 0.6, 0.5, { color = self.white }, y0 + 1)
	local shaft = Instance.new("Part")
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Anchored = true
	shaft.Size = Vector3.new(h - 3, r * 2, r * 2)
	shaft.CFrame = CFrame.new(x, y0 + 1.5 + (h - 3) / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Color = opts.color or self.white
	shaft.TopSurface = Enum.SurfaceType.Smooth
	shaft.BottomSurface = Enum.SurfaceType.Smooth
	shaft.Name = "Column"
	shaft.Parent = self.folder
	-- (the shaft collides as its square: close enough, and never lets an arrow through a gap that isn't there)
	local mn, mx = Vector3.new(x - r, y0 + 1.5, z - r), Vector3.new(x + r, y0 + h - 1.5, z + r)
	table.insert(self.solids, { min = mn, max = mx, part = shaft })
	table.insert(self.collide, { min = mn, max = mx })
	self:block(x, z, base - 0.6, base - 0.6, 0.5, { color = self.white }, y0 + h - 1.5)
	self:block(x, z, base, base, 1, { color = self.light }, y0 + h - 1)
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

-- Steps up to a height: from (x, z), climbing toward dir ("+x" | "-x" | "+z" | "-z"), width w, from opts.y0 (default
-- the floor).
function Shapes:stairs(x, z, dir, steps, rise, run, w, opts)
	opts = opts or {}
	local y0 = opts.y0 or 0
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
		self:block(cx, cz, sx, sz, h, { color = (i % 2 == 0) and self.white or self.light }, y0)
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

-- Bigger pieces: the height and the skyline of a map --------------------------------------------------------------

-- A box along "x" or "z": (x, z) its middle, len along that way, depth across, h tall from y0
function Shapes:run(x, z, len, along, depth, h, opts, y0)
	if along == "x" then
		return self:block(x, z, len, depth, h, opts, y0)
	end
	return self:block(x, z, depth, len, h, opts, y0)
end

-- The beam over a colonnade: an architrave, a frieze set back from it, and a crown molding of two steps out.
-- (x, z) its middle, len along `along`, depth across, sitting on y.
function Shapes:entablature(x, z, len, along, y, depth)
	self:run(x, z, len, along, depth, 1.6, { color = self.white }, y)
	self:run(x, z, len - 0.4, along, depth - 0.5, 1.4, { color = self.light }, y + 1.6)
	self:run(x, z, len + 0.8, along, depth + 0.8, 0.5, deco({ color = self.white }), y + 3)
	self:run(x, z, len + 1.4, along, depth + 1.4, 0.4, deco({ color = self.light }), y + 3.5)
end

-- A row of n columns from a to b (distances along `along`, at `at` across) under one entablature
function Shapes:colonnade(a, b, at, along, n, h, r, opts)
	opts = opts or {}
	for i = 0, n - 1 do
		local c = a + (b - a) * (n > 1 and i / (n - 1) or 0.5)
		if along == "x" then
			self:column(c, at, h, r, opts)
		else
			self:column(at, c, h, r, opts)
		end
	end
	local mid = (a + b) / 2
	local len = math.abs(b - a) + r * 2 + 2
	if along == "x" then
		self:entablature(mid, at, len, "x", (opts.y0 or 0) + h, r * 2 + 1.4)
	else
		self:entablature(at, mid, len, "z", (opts.y0 or 0) + h, r * 2 + 1.4)
	end
end

-- A tall tower: a plinth, the shaft, a thin string course every `floor` studs with a dark window slit on each face
-- between them, a corbelled crown, and on top battlements (opts.crown = "battlements", the default), a stepped roof
-- ("roof") or a needle spire ("spire"). Returns the height of its top.
function Shapes:tower(x, z, w, d, h, opts)
	opts = opts or {}
	local y0 = opts.y0 or 0
	self:block(x, z, w + 1.2, d + 1.2, 1.2, { color = self.light }, y0)
	self:block(x, z, w, d, h, { color = opts.color or self.white }, y0)
	local floor = opts.floor or 9
	local dark = opts.windowColor or self.dark
	for y = y0 + floor, y0 + h - 5, floor do
		self:block(x, z, w + 0.5, d + 0.5, 0.4, deco({ color = self.light }), y)
		if not opts.noWindows then
			for _, f in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local wx, wz = x + f[1] * (w / 2 + 0.05), z + f[2] * (d / 2 + 0.05)
				local sx, sz = f[1] ~= 0 and 0.2 or 1, f[2] ~= 0 and 0.2 or 1
				self:block(wx, wz, sx, sz, 3.2, deco({ color = dark }), y - floor / 2 - 1.6)
			end
		end
	end
	local top = y0 + h
	self:block(x, z, w + 1.6, d + 1.6, 1.2, { color = self.light }, top)
	local crown = opts.crown or "battlements"
	if crown == "battlements" then
		for _, side in { -1, 1 } do
			local n = math.max(2, math.floor((w + 1.6) / 2.6))
			for i = 0, n - 1 do
				local cx = x - (w + 1.6) / 2 + 0.7 + i * ((w + 1.6 - 1.4) / (n - 1))
				self:block(cx, z + side * (d / 2 + 0.25), 1.3, 1.1, 1.8, { color = self.white }, top + 1.2)
			end
			local m = math.max(2, math.floor((d + 1.6) / 2.6))
			for i = 1, m - 2 do
				local cz = z - (d + 1.6) / 2 + 0.7 + i * ((d + 1.6 - 1.4) / (m - 1))
				self:block(x + side * (w / 2 + 0.25), cz, 1.1, 1.3, 1.8, { color = self.white }, top + 1.2)
			end
		end
	elseif crown == "roof" then
		for i = 1, 4 do
			local k = 1 - i * 0.22
			self:block(
				x,
				z,
				(w + 1) * k,
				(d + 1) * k,
				1.4,
				{ color = (i % 2 == 0) and self.light or self.white },
				top + 1.2 + (i - 1) * 1.4
			)
		end
	elseif crown == "spire" then
		self:block(x, z, w * 0.6, d * 0.6, 3, { color = self.white }, top + 1.2)
		self:block(x, z, w * 0.36, d * 0.36, 5, { color = self.light }, top + 4.2)
		self:block(x, z, 0.6, 0.6, 6, deco({ color = self.white }), top + 9.2)
	end
	return top
end

-- A statue on a pedestal: a faceted archer (legs, a long coat, the chest, the head, one arm up, a bow held low)
-- facing along X (face = 1: toward +X); s (optional) adds a sash in that half's colour. k scales it (1: about 12
-- studs with the pedestal).
function Shapes:statue(x, z, face, k, s, y0)
	k = k or 1
	y0 = y0 or 0
	self:block(x, z, 4.6 * k, 4.6 * k, 1 * k, { color = self.light }, y0)
	self:block(x, z, 3.6 * k, 3.6 * k, 3.2 * k, { color = self.white }, y0 + 1 * k)
	self:block(x, z, 4.2 * k, 4.2 * k, 0.5 * k, deco({ color = self.light }), y0 + 4.2 * k)
	local base = CFrame.new(x, y0 + 4.7 * k, z) * CFrame.Angles(0, face > 0 and -math.pi / 2 or math.pi / 2, 0)
	local stone = deco({ color = self.white, shadow = true })
	local function piece(off, size, rot, opts)
		self:box(base * CFrame.new(off * k) * (rot or CFrame.new()), size * k, opts or stone)
	end
	piece(Vector3.new(-0.55, 1.5, 0), Vector3.new(0.9, 3, 1))
	piece(Vector3.new(0.55, 1.5, 0.3), Vector3.new(0.9, 3, 1), CFrame.Angles(math.rad(-8), 0, 0))
	piece(Vector3.new(0, 3.3, 0), Vector3.new(2.3, 1.8, 1.4), nil, deco({ color = self.light, shadow = true }))
	piece(Vector3.new(0, 4.9, 0), Vector3.new(2.2, 1.8, 1.1))
	piece(Vector3.new(0, 6.4, 0), Vector3.new(1.1, 1.1, 1.1), CFrame.Angles(0, math.rad(20), 0))
	piece(Vector3.new(1.45, 6.2, -0.2), Vector3.new(0.65, 2.6, 0.65), CFrame.Angles(math.rad(-25), 0, math.rad(-15)))
	piece(Vector3.new(-1.35, 5.3, -0.8), Vector3.new(0.65, 0.65, 2.2))
	-- the bow: three thin bars in an arc ahead of the lowered arm
	for i = -1, 1 do
		piece(
			Vector3.new(-1.35, 5.3 + i * 1.3, -2 + math.abs(i) * 0.45),
			Vector3.new(0.25, 1.5, 0.25),
			CFrame.Angles(math.rad(-i * 28), 0, 0),
			deco({ color = self.light })
		)
	end
	if s then
		piece(
			Vector3.new(0, 4.9, -0.58),
			Vector3.new(0.5, 2.5, 0.12),
			CFrame.Angles(0, 0, math.rad(35)),
			deco({ color = self:teamColor(s) })
		)
	end
	return y0 + 4.7 * k
end

-- A raised deck players climb from their own side: a block h tall with a lip round its top, and steps of about a
-- stud each up the side `stairs` faces ("+x" | "-x" | "+z" | "-z"), w2 wide.
function Shapes:platform(x, z, w, d, h, stairs, w2, opts)
	opts = opts or {}
	self:block(x, z, w, d, h, { color = opts.color or self.light })
	self:block(x, z, w + 0.6, d + 0.6, 0.4, deco({ color = self.white }), h - 0.2)
	if stairs then
		local steps = math.ceil(h)
		local rise, run = h / steps, 1.3
		local sx, sz, dir = x, z, nil
		if stairs == "+x" then
			sx, dir = x + w / 2 + steps * run, "-x"
		elseif stairs == "-x" then
			sx, dir = x - w / 2 - steps * run, "+x"
		elseif stairs == "+z" then
			sz, dir = z + d / 2 + steps * run, "-z"
		else
			sz, dir = z - d / 2 - steps * run, "+z"
		end
		self:stairs(sx, sz, dir, steps, rise, run, w2 or 6)
	end
end

-- A balcony on a long wall, high over the field (looks only, out of reach): a slab on two brackets with a
-- balustrade. x its middle, face the wall's inner face (z), zz which wall (+1 / -1), y its floor.
function Shapes:balcony(x, face, zz, y, len)
	local z = face - zz * 1.3
	self:block(x, z, len, 2.6, 0.6, { color = self.white }, y)
	for _, sx in { -1, 1 } do
		self:wedge(
			CFrame.new(x + sx * (len / 2 - 0.8), y - 0.8, face - zz * 0.7)
				* CFrame.Angles(0, zz > 0 and 0 or math.pi, math.pi),
			Vector3.new(0.8, 1.6, 1.4),
			deco({ color = self.light })
		)
	end
	self:block(x, face - zz * 2.45, len, 0.3, 1.8, deco({ color = self.light }), y + 0.6)
	self:block(x, face - zz * 2.45, len + 0.3, 0.5, 0.3, deco({ color = self.white }), y + 2.4)
	for i = 0, 2 do
		self:block(
			x + (i - 1) * (len / 2 - 0.4),
			face - zz * 2.45,
			0.5,
			0.55,
			1.8,
			deco({ color = self.white }),
			y + 0.6
		)
	end
end

-- A geometric tree: a trunk and three canopy blocks turned against each other (the canopy is looks only)
function Shapes:tree(x, z, h, leaf, leaf2, k)
	k = k or 1
	self:block(x, z, 1.2 * k, 1.2 * k, h, { color = self.grey })
	for i = 0, 2 do
		local size = (6 - i * 1.6) * k
		self:box(
			CFrame.new(x, h + i * 2 * k, z) * CFrame.Angles(math.rad(8 - i * 6), math.rad(i * 35), math.rad(-6 + i * 5)),
			Vector3.new(size, 2.2 * k, size),
			deco({ color = (i % 2 == 0) and leaf or leaf2, shadow = true })
		)
	end
end

-- A distance along the field (from the middle) or across it (from the centre line), drawn for the small arena,
-- stretched to this one
function Shapes:fx(v)
	return v * self.sx
end
function Shapes:fz(v)
	return v * self.sz
end

-- Both halves at once: fn(s) runs for s = -1 (red's half, -X) and s = 1 (blue's, +X), so maps stay fair.
function Shapes:mirror(fn)
	fn(-1)
	fn(1)
end

-- Sizes: a match that starts with a lot of people gets a bigger arena (MatchService:NewMatch counts everyone). Each
-- tier adds whole cells to the field (`grow` studs of length, half to each side, so the turf takes longer to push)
-- and to its width; the spawn decks stay as deep, so the lose lines are always spawnDepth from the end walls.
-- A step every 10 people, each a big one: 10 in the match is half as long again and half as wide again, 20 nearly
-- twice the small field, 30 and up about two and a half times as long and wide.
ArenaBuilder.TIERS = { "small", "medium", "large", "huge" }
ArenaBuilder.SIZES = {
	small = { upTo = 9, grow = 0, widen = 0 },
	medium = { upTo = 19, grow = 96, widen = 48 },
	large = { upTo = 29, grow = 192, widen = 96 },
	huge = { upTo = math.huge, grow = 288, widen = 144 },
}

-- The tier for a scale: a tier's name, or a number of people (nil: small)
function ArenaBuilder.tier(scale)
	if type(scale) == "string" and ArenaBuilder.SIZES[scale] then
		return scale
	end
	local n = tonumber(scale) or 0
	for _, t in ArenaBuilder.TIERS do
		if n <= ArenaBuilder.SIZES[t].upTo then
			return t
		end
	end
	return ArenaBuilder.TIERS[#ArenaBuilder.TIERS]
end

-- The arena ---------------------------------------------------------------------------------------------------
function ArenaBuilder.build(def, parent, scale)
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	local tier = ArenaBuilder.tier(scale)
	local size = ArenaBuilder.SIZES[tier]
	local baseLength, baseWidth = def.length or 200, def.width or 96
	local length, width = baseLength + size.grow, baseWidth + size.widen
	local half = length / 2
	local spawnDepth = def.spawnDepth or 20
	local palette = def.palette or {}
	local shapes = setmetatable({
		folder = Instance.new("Folder"),
		solids = {},
		collide = {},
		white = palette.white or Constants.WHITE,
		light = palette.light or Constants.LIGHT,
		grey = palette.grey or Constants.GREY,
		dark = palette.dark or Constants.DARK,
		length = length,
		width = width,
		half = half,
		W = width / 2,
		spawnDepth = spawnDepth,
		edge = half - spawnDepth,
		tier = tier,
		wallH = def.wallHeight or 26,
		-- (a map is drawn for the small field; fx / fz stretch its distances to this one's)
		sx = (half - spawnDepth) / (baseLength / 2 - spawnDepth),
		sz = width / baseWidth,
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
		p.Color = Constants.MAP_GROUND.turf or Constants.WHITE -- (the mode's ground, when it has one: grass in Bot Brawl)
		p.Parent = turf
		strips[i] = p
	end
	-- (the floor is one solid box for projectiles; the strips are only its colour)
	table.insert(
		shapes.solids,
		{ min = Vector3.new(-half, -2, -width / 2), max = Vector3.new(half, 0, width / 2), part = strips[1] }
	)

	-- the walls round it: visible to wallH, then an invisible shell up to the ceiling (nobody leaves)
	local wallH, t = shapes.wallH, 4
	local ceiling = def.ceiling or math.max(70, wallH + 26)
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

	-- the long walls, in bays of 20 studs: a pilaster the full height with its base, capital and a lamp, a recessed
	-- panel low down, a tall window high up over a string course, a balcony on every other bay; a banner in each
	-- half's colour; a crown molding along the top (and battlements, for a map that asks)
	local course = math.floor(wallH * 0.42)
	for _, zz in { -1, 1 } do
		local face = zz * (width / 2)
		for x = -half + 30, half - 30, 20 do
			shapes:block(x, face - zz * 0.6, 2.4, 1.2, wallH, { color = shapes.white, solid = false })
			shapes:block(x, face - zz * 1.0, 3, 1.4, 1.2, deco({ color = shapes.light }))
			shapes:block(x, face - zz * 0.9, 3.2, 1.8, 1, deco({ color = shapes.light }), wallH - 3)
			shapes:block(
				x,
				face - zz * 1.4,
				0.8,
				0.8,
				0.8,
				deco({ color = Color3.new(1, 1, 1), material = Enum.Material.Neon }),
				course - 3
			)
		end
		for x = -half + 40, half - 40, 20 do
			shapes:block(x, face - zz * 0.15, 14, 0.3, 11, deco({ color = shapes.white }), 2.5)
			shapes:block(x, face - zz * 0.3, 12, 0.3, 9, deco({ color = shapes.grey }), 3.5)
			shapes:block(x, face - zz * 0.45, 11, 0.3, 8, deco({ color = shapes.light }), 4)
			local winH = wallH - course - 8
			if winH > 4 then
				shapes:block(x, face - zz * 0.2, 8, 0.4, winH + 1.2, deco({ color = shapes.white }), course + 3.4)
				shapes:block(x, face - zz * 0.35, 6, 0.4, winH, deco({ color = shapes.dark }), course + 4)
				shapes:block(x, face - zz * 0.45, 0.6, 0.4, winH, deco({ color = shapes.white }), course + 4)
			end
			if math.floor((math.abs(x) + 10) / 20) % 2 == 1 then -- (every other bay, the same both halves)
				shapes:balcony(x, face, zz, course + 1, 10)
			end
		end
		shapes:block(0, face - zz * 0.4, length, 0.8, 0.6, deco({ color = shapes.white }), course)
		for _, sx in { -1, 1 } do
			for _, k in { 30, 50 } do
				shapes:banner(sx * (half - k), face, sx, -zz, 9, 10)
			end
		end
		shapes:block(0, face - zz * 0.8, length, 1.6, 0.8, deco({ color = shapes.white }), wallH - 1.5)
		shapes:block(0, face - zz * 1.2, length, 1.2, 0.5, deco({ color = shapes.light }), wallH - 2.2)
		if def.crown == "battlements" then
			for x = -half + 2, half - 2, 6 do
				shapes:block(x, zz * (width / 2 + 1), 2.6, 2, 2.2, deco({ color = shapes.white }), wallH + 1)
			end
		end
	end

	-- beyond the walls: a skyline fading into the haze, so the world never ends at a wall. Towers with set-backs,
	-- crowns and a few needles by default; a map can draw its own (def.skyline(shapes, x, z, w, d, h, rng, i)).
	local r = Random.new(def.seed or #def.key * 97)
	for i = 1, 64 do
		local a = (i / 64) * math.pi * 2 + r:NextNumber(-0.04, 0.04)
		local rx, rz = (half + 80) + r:NextNumber(0, 150), (width / 2 + 80) + r:NextNumber(0, 150)
		local x, z = math.cos(a) * rx, math.sin(a) * rz
		local w, d, h = r:NextNumber(14, 36), r:NextNumber(14, 36), r:NextNumber(34, 100)
		if not (def.skyline and def.skyline(shapes, x, z, w, d, h, r, i)) then
			local c = (i % 3 == 0) and shapes.light or ((i % 3 == 1) and shapes.white or shapes.grey)
			local p =
				shapes:box(Vector3.new(x, h / 2 - 2, z), Vector3.new(w, h, d), deco({ color = c, shadow = false }))
			p.Name = "Skyline"
			if i % 2 == 0 then
				shapes:box(
					Vector3.new(x, h - 2 + h * 0.12, z),
					Vector3.new(w * 0.62, h * 0.24, d * 0.62),
					deco({ color = shapes.white, shadow = false })
				)
			elseif i % 3 == 0 then
				shapes:box(
					Vector3.new(x, h - 1.5, z),
					Vector3.new(w + 2, 1, d + 2),
					deco({ color = shapes.light, shadow = false })
				)
			end
			if i % 5 == 0 then
				shapes:box(Vector3.new(x, h * 1.24 + 6, z), Vector3.new(1, 18, 1), deco({ color = shapes.white }))
			end
		end
	end
	-- the ground out there: one wide pale floor, below the arena's, so nothing below the walls is ever empty
	local ground = shapes:box(
		Vector3.new(0, -2.5, 0),
		Vector3.new(length + 600, 1, width + 600),
		deco({ color = Constants.MAP_GROUND.ground or shapes.light, shadow = false })
	)
	ground.Name = "Ground"

	-- the spawns: an open deck at the back of the base, pads in the team's colour facing the field, so you come in
	-- seeing where you are and where the fight is (no walls, no hall). It's safe by rule, not by walls: nobody can
	-- hurt you on your own deck until you shoot or swing (CombatService). Distances are from the team's own end wall.
	local spawns = { red = {}, blue = {} }
	local shopSigns = {}
	local room = ArenaBuilder.room(width, spawnDepth)
	for _, team in Constants.TEAMS do
		local s = team == "red" and -1 or 1
		local color = Constants.TEAM_COLOR[team]
		local function X(d)
			return s * (half - d)
		end
		local zoneX = X(spawnDepth / 2)
		shapes:block(
			zoneX,
			0,
			spawnDepth,
			width - 2,
			0.2,
			{ color = Constants.MAP_GROUND.deck or shapes.light, collide = false, solid = false },
			0
		)
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
		-- cover on the deck (solid: arrows and TNT stop on it), between the pads' lanes so every pad still looks and
		-- walks straight out: a chest-high parapet along the deck's front edge in segments (a gap in front of each pad
		-- row), and a tall pier behind each segment to duck behind, each with a band of the team's colour. Only round
		-- the pads (nobody spawns further out), and few pieces each: the big arenas stay within a phone's budget.
		local cover = room.cover
		local zMax = math.min(width / 2 - cover.margin, cover.reach)
		for k = -6, 5 do
			local z = (k + 0.5) * cover.pitch
			if math.abs(z) + cover.segment / 2 <= zMax then
				-- the parapet, and a neon band along its field face
				local px = X(cover.parapet)
				shapes:block(
					px,
					z,
					cover.thick,
					cover.segment,
					cover.parapetH,
					{ color = shapes.white, name = "Cover" }
				)
				shapes:block(
					px - s * (cover.thick / 2 + 0.05),
					z,
					0.1,
					cover.segment - 1,
					0.35,
					deco({ color = color, material = Enum.Material.Neon }),
					cover.parapetH - 1.1
				)
				-- the pier, under a light capital
				local qx = X(cover.pier)
				shapes:block(qx, z, cover.pierW, cover.pierW, cover.pierH, { color = shapes.white, name = "Cover" })
				shapes:block(
					qx,
					z,
					cover.pierW + 0.6,
					cover.pierW + 0.6,
					0.6,
					deco({ color = shapes.light }),
					cover.pierH
				)
			end
		end
		-- the shop sign: a plain board on a post by the deck's side wall, on the team's right as they face the field,
		-- turned to the pads. Clear of the pads, the cover and the back wall's piers, and pure looks (no collision, no
		-- queries): it never stops a body, an arrow or a piece. Each client puts its words and its prompt on it
		-- (ShopSignController: "🛒 SHOP" and today's deal; the prompt opens the shop).
		local sg = room.sign
		local sx, sz = X(sg.d), -s * (width / 2 - sg.inset)
		shapes:block(sx, sz, 0.6, 0.6, sg.y, deco({ color = Constants.GREY, name = "ShopSignPost" }))
		shapes:block(sx, sz, 1.6, 1.6, 0.3, deco({ color = Constants.LIGHT, name = "ShopSignPost" }))
		local face = CFrame.lookAt(Vector3.new(sx, sg.y + sg.h / 2, sz), Vector3.new(X(sg.d + 6), sg.y + sg.h / 2, 0))
		local board =
			shapes:box(face, Vector3.new(sg.w, sg.h, 0.3), deco({ color = Constants.WHITE, name = "ShopSign" }))
		board:SetAttribute("Team", team)
		for _, dy in { -1, 1 } do
			shapes:box(
				face * CFrame.new(0, dy * (sg.h / 2 + 0.15), 0),
				Vector3.new(sg.w + 0.3, 0.3, 0.4),
				deco({ color = color, name = "ShopSignTrim" })
			)
		end
		shopSigns[team] = board
		-- the back wall: piers with capitals, a gate in the middle (two tall piers under a lintel, the team's colour
		-- glowing in it), a string course and a crest high up
		local piers = math.floor((width / 2 - 8) / 17)
		for k = -piers, piers do
			if k ~= 0 then
				shapes:block(X(1.5), k * 17, 3, 3, wallH, { color = shapes.white })
				shapes:block(X(1.8), k * 17, 3.6, 3.6, 1.2, deco({ color = shapes.light }), wallH - 3)
			end
		end
		for _, zs in { -1, 1 } do
			shapes:block(X(2), zs * 7, 4, 4, wallH + 4, { color = shapes.white })
			shapes:block(X(2.2), zs * 7, 4.8, 4.8, 1.4, deco({ color = shapes.light }), wallH - 6)
		end
		shapes:block(X(2), 0, 4, 18, 4, { color = shapes.white }, wallH - 10)
		shapes:block(X(0.4), 0, 0.8, 10, wallH - 12, deco({ color = color, material = Enum.Material.Neon }), 0.5)
		shapes:block(X(0.6), 0, 1.2, 12, wallH - 11, deco({ color = shapes.light }), 0)
		shapes:box(
			CFrame.new(X(1.2), wallH - 2, 0) * CFrame.Angles(math.rad(45), 0, 0),
			Vector3.new(1, 5, 5),
			deco({ color = color })
		)
		shapes:block(X(0.6), 0, 1.2, width, 0.8, deco({ color = shapes.white }), course)
		shapes:block(X(1), 0, 2, width, 2, { color = color, material = Enum.Material.Neon, solid = false }, wallH - 4)
	end

	-- the map's own architecture
	if def.build then
		def.build(shapes)
	end

	-- the frontline: one crisp, bright line ON the floor across the field (nothing standing up, so both teams always
	-- see each other over it), in the colour of the team that pushed it last. Dark edges on both sides keep it sharp
	-- against the red and the blue turf; the glow is a thin band right on it, so it never bleeds across both sides.
	local function linePart(name, w, h, transparency, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material or Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 255, 255)
		p.Transparency = transparency
		p.Size = Vector3.new(w, h, width)
		p.CFrame = CFrame.new(0, h / 2 + 0.02, 0)
		p.Parent = folder
		return p
	end
	local marker = linePart("Frontline", 1.2, 0.32, 0)
	local glow = linePart("FrontlineGlow", 2.2, 0.06, 0.65)
	local edge = linePart("FrontlineEdge", 2.0, 0.28, 0, Enum.Material.SmoothPlastic)
	edge.Color = Constants.WHITE -- (white edges either side of the glowing line, like the rest of the world)
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Top
	light.Angle = 60
	light.Range = 5
	light.Brightness = 1.5
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
	folder:SetAttribute("Size", tier)
	folder.Parent = parent
	local arena = {
		folder = folder,
		def = def,
		length = length,
		width = width,
		half = half,
		spawnDepth = spawnDepth,
		tier = tier,
		solids = shapes.solids,
		collide = shapes.collide,
		spawns = spawns,
		shopSigns = shopSigns,
		strips = strips,
		blocked = blocked,
		marker = marker,
		glow = glow,
		edge = edge,
		ceiling = ceiling,
	}
	arena.room = room
	return arena
end

-- The spawn room's measures, in studs from the team's own end wall (d) and across the field (z):
--   pads (d of the two pad columns), baffle0/baffle1 (the baffle's faces), baffleHalf (it spans |z| <= this),
--   front0/front1 (the front wall's faces), gapMid/gapHalf (the doors: |z| within gapMid +- gapHalf),
--   height (walls and roof), door (a door's height), baffleH, cover (the deck's parapets and piers)
function ArenaBuilder.room(width, spawnDepth)
	return {
		open = true, -- (no walls: safe by rule, see CombatService)
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
		-- the deck's cover (studs from the end wall; segments centred between the pad rows, pitch apart)
		cover = {
			pitch = 14, -- (the pad rows' spacing: a segment sits halfway between two rows)
			segment = 7, -- a parapet's length across the field (a 7-stud gap in front of each row)
			margin = 3, -- kept clear of the side walls
			reach = 38.5, -- and no further out than this (the outer pad rows are at 28)
			parapet = 17.5, -- its middle, just inside the spawn line
			thick = 1.4,
			parapetH = 4.2, -- chest high: crouch behind it, stand to shoot over
			pier = 13, -- a tall pier behind each segment
			pierW = 2.8,
			pierH = 7.5,
		},
		-- the shop sign (studs from the end wall, in from the side wall; its board's size, and its bottom edge's
		-- height: over a body's head, so nothing ever walks into its edge)
		sign = { d = 7, inset = 5, w = 5, h = 2.6, y = 5.6 },
	}
end

-- On a team's spawn deck? (behind its spawn line)
function ArenaBuilder.inRoom(arena, team, pos)
	local s = team == "red" and -1 or 1
	return arena.half - s * pos.X < arena.room.front1 + 0.5
end

-- The way out of the spawn deck: straight on (it's open). (Kept for the bots; a room with walls would route here.)
function ArenaBuilder.route(arena, team, pos, goal)
	local r = arena.room
	if not r or r.open then
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
	if arena.edge then
		arena.edge.CFrame = CFrame.new(frontline, arena.edge.Size.Y / 2 + 0.02, 0)
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

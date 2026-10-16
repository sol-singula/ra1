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
    marker,                               the frontline's light sheet
  }
  ArenaBuilder.paint(arena, frontline)    recolour the turf (and move the marker) for this frontline
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

	-- the spawn zones: pads in the team's colour, a back wall with arches, a frame you leave through
	local spawns = { red = {}, blue = {} }
	for _, team in Constants.TEAMS do
		local s = team == "red" and -1 or 1
		local color = Constants.TEAM_COLOR[team]
		local zoneX = s * (half - spawnDepth / 2)
		shapes:block(zoneX, 0, spawnDepth, width - 2, 0.2, { color = shapes.light, collide = false, solid = false }, 0)
		for row = -2, 2 do
			for col = 0, 1 do
				local px = s * (half - 5 - col * 7)
				local pz = row * 14
				local pad =
					shapes:block(px, pz, 4.5, 4.5, 0.3, { color = color, material = Enum.Material.Neon, solid = false })
				pad.Name = team .. "Pad"
				table.insert(spawns[team], CFrame.lookAt(Vector3.new(px, 3.5, pz), Vector3.new(0, 3.5, pz)))
			end
		end
		-- the spawn line: a thin bar in the team's colour across the floor, where the base ends
		shapes:block(
			s * (half - spawnDepth),
			0,
			0.6,
			width,
			0.25,
			{ color = color, material = Enum.Material.Neon, solid = false }
		)
		-- the back wall's arches (detail on the base end)
		for k = -2, 2 do
			shapes:block(s * (half - 1.5), k * 17, 3, 3, wallH, { color = shapes.white })
		end
		shapes:block(
			s * (half - 1),
			0,
			2,
			width,
			2,
			{ color = color, material = Enum.Material.Neon, solid = false },
			wallH - 4
		)
	end

	-- the map's own architecture
	if def.build then
		def.build(shapes)
	end

	-- the frontline's marker: a thin sheet of light across the field
	local marker = Instance.new("Part")
	marker.Name = "Frontline"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 255, 255)
	marker.Transparency = 0.55
	marker.Size = Vector3.new(0.4, 6, width)
	marker.CFrame = CFrame.new(0, 3, 0)
	marker.Parent = folder

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
		ceiling = ceiling,
	}
	return arena
end

-- Recolour the turf for this frontline (and move the marker onto it).
function ArenaBuilder.paint(arena, frontline)
	for i, strip in arena.strips do
		local x = -arena.half + (i - 0.5) * CELL
		local team = Formulas.sideOf(x, frontline)
		local base = Constants.TURF_COLOR[team]
		-- every other strip a shade lighter: the grid reads without a texture
		strip.Color = (i % 2 == 0) and base:Lerp(Color3.new(1, 1, 1), 0.12) or base
	end
	arena.marker.CFrame = CFrame.new(frontline, 3, 0)
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

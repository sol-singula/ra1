--[[
The lobby place (LobbyService builds it on the server; everyone lands here first): a 240 x 240 plaza round the
origin, the floor at y = 0, in the maps' look (World/ArenaBuilder's shapes, SUPERHOT: white and greys, no browns)
with gold and both teams' colours as the accents, dressed richer than an arena (plinths, string courses, crown
moldings, columns, panels, windows, banners, lamps, statues, trees, corner towers and a skyline) but phone-cheap:
under a thousand parts, every bit of trim looks only.

The fixed spots everything stands on (LobbyBuilder.SPOTS: the numbers every other piece of the lobby builds to):
  spawn     CFrame at (0, 3, 40) facing -Z: where everyone lands, looking down the walkway at PLAY
  play      (0, 0, -20): the gold PLAY beacon: a dais under a gate with "PLAY" in 3D letters on it and a column of
            light; walking onto the dais joins the fullest game (LobbyController sends Net "Play")
  portals   ctf (-40, 0, -30), brawl (40, 0, -30): a smaller arch each in its mode's colour, a sign for its name and
            live count; walking in plays that mode
  parkour   start (-90, 0, 60), up the west wall to top (-90, 40, -60): gold and white blocks, a "PARKOUR ▲" sign,
            checkpoints on the way (LobbyBuilder.PARKOUR: the platforms, the checkpoints, the top)
  boards    (100, 0, 0): the leaderboards' stand on the east side, four boards facing the plaza (LobbyController
            fills them from Net "Leaderboards")
  duelPads  (-60 | -20 | 20 | 60, 0, -90): four marked pads (1v1, 2v2, 3v3, 4v4) with signs (the duel service wires them)
  crate     (60, 0, 60): a raised stand with steps and a "CRATE" sign (the crate and the weapon rack go on it)
  shops     (18, 0, 10) and (-18, 0, 10) flanking the walkway, (-95, 0, 0) and (40, 0, -95) by the walls: shop
            kiosks, each hinting at a tab (EFFECTS, WEAPON SKINS, SHARDS, DEALS); walking up opens the shop
  verify    (30, 0, 45): the VERIFY stand by the spawn (LobbyService's thank-you)

Nothing a body bumps into stands on the walkway from the spawn to the PLAY dais (LobbyBuilder.WALKWAY: the box
the tests check).

  LobbyBuilder.build(parent) -> world {
    folder, solids, collide,                  (as ArenaBuilder's: every solid box, every box a body bumps into)
    spots = SPOTS,
    beacon, portals = { [mode] = { part, sign } }, kiosks = { { part, sign, hint, tab } }, verify = { part, sign },
    boards = { [boardKey] = Part }, pads = { Part }, crate = Part, parkour = { start, checkpoints = { Part }, top },
    count = how many parts }
  LobbyBuilder.light()                       the lobby's lighting (the maps' white haze)
  LobbyBuilder.near(pos, spot, radius, dy?)  pos within radius of a spot on the ground (and within dy of its height)
  LobbyBuilder.sign(part, title, line?, color?)   words on a part's front face (a SurfaceGui)
]]
local Lighting = game:GetService("Lighting")

local Constants = require(script.Parent.Parent.Constants)
local Modes = require(script.Parent.Parent.Data.Modes)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

local LobbyBuilder = {}

local V3 = Vector3.new
local GOLD = Constants.GOLD
local INK = Color3.fromRGB(30, 30, 34)
local deco = ArenaBuilder.deco

LobbyBuilder.SIZE = 240
LobbyBuilder.HALF = 120
LobbyBuilder.WALL = 18 -- the walls' height (an invisible shell above, to CEILING)
LobbyBuilder.CEILING = 90
LobbyBuilder.GOLD = GOLD

LobbyBuilder.SPOTS = {
	spawn = CFrame.new(0, 3, 40), -- (facing -Z)
	play = V3(0, 0, -20),
	parkour = { start = V3(-90, 0, 60), top = V3(-90, 40, -60) },
	boards = V3(100, 0, 0),
	duelPads = { V3(-60, 0, -90), V3(-20, 0, -90), V3(20, 0, -90), V3(60, 0, -90) },
	crate = V3(60, 0, 60),
	shops = { V3(18, 0, 10), V3(-18, 0, 10), V3(-95, 0, 0), V3(40, 0, -95) },
	verify = V3(30, 0, 45),
	portals = { ctf = V3(-40, 0, -30), brawl = V3(40, 0, -30) },
}
local SPOTS = LobbyBuilder.SPOTS

-- The walkway from the spawn to the PLAY dais: nothing collidable stands in it (the floor is below it)
LobbyBuilder.WALKWAY = { min = V3(-6, 0.3, -8), max = V3(6, 8, 38) }

-- The shop kiosks: where, which way they face, the tab they hint at (all open the shop; DEALS at today's deal)
LobbyBuilder.KIOSKS = {
	{ at = SPOTS.shops[1], face = V3(-1, 0, 0), hint = "EFFECTS", tab = "shop" },
	{ at = SPOTS.shops[2], face = V3(1, 0, 0), hint = "WEAPON SKINS", tab = "shop" },
	{ at = SPOTS.shops[3], face = V3(1, 0, 0), hint = "SHARDS", tab = "shop" },
	{ at = SPOTS.shops[4], face = V3(0, 0, 1), hint = "DEALS", tab = "deal" },
}

-- The parkour: thirteen platforms climbing the west wall from the start to the tower, every fourth a checkpoint
-- (a bigger block with a ring and a gold post), the tower's top the finish. Each entry is the top of a block.
LobbyBuilder.PARKOUR = { platforms = {}, checkpoints = {}, steps = 13, every = 4 }
do
	local P = LobbyBuilder.PARKOUR
	local s, t = SPOTS.parkour.start, SPOTS.parkour.top
	table.insert(P.checkpoints, s)
	for i = 1, P.steps do
		local k = i / (P.steps + 1)
		local top = V3(s.X + 7 * math.sin(i * 1.1), i * 3, s.Z + (t.Z - s.Z) * k)
		P.platforms[i] = top
		if i % P.every == 0 then
			table.insert(P.checkpoints, top)
		end
	end
	table.insert(P.checkpoints, t)
end

function LobbyBuilder.near(pos, spot, radius, dy)
	local p = typeof(spot) == "CFrame" and spot.Position or spot
	local dx, dz = pos.X - p.X, pos.Z - p.Z
	if dx * dx + dz * dz > radius * radius then
		return false
	end
	return dy == nil or math.abs(pos.Y - p.Y) <= dy
end

-- Words on a part's front face: a title and (optionally) a line under it, on a SurfaceGui the part carries
function LobbyBuilder.sign(part, title, line, color, face)
	local gui = part:FindFirstChild("Words") or Instance.new("SurfaceGui")
	gui.Name = "Words"
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local function label(name, text, y, h, c)
		local l = gui:FindFirstChild(name) or Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.04, y)
		l.Size = UDim2.fromScale(0.92, h)
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextWrapped = true
		l.TextColor3 = c
		l.Text = text
		l.Parent = gui
		return l
	end
	if line and line ~= "" then
		label("Title", title, 0.06, 0.5, color or INK)
		label("Line", line, 0.58, 0.36, color or INK)
	else
		label("Title", title, 0.08, 0.84, color or INK)
		local old = gui:FindFirstChild("Line")
		if old then
			old:Destroy()
		end
	end
	gui.Parent = part
	return gui
end

-- The lighting: the maps' (ArenaService): a white haze, soft grey shadows, matte surfaces
function LobbyBuilder.light()
	Lighting.Ambient = Color3.fromRGB(170, 170, 172):Lerp(Color3.new(0, 0, 0), 0.32)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 138, 142)
	Lighting.Brightness = 2.6 * 0.62
	Lighting.ClockTime = 14
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.04
	Lighting.ExposureCompensation = -0.25
	Lighting.FogColor = Color3.fromRGB(232, 232, 236)
	Lighting.FogEnd = 1200
	pcall(function()
		Lighting.ShadowSoftness = 0.3
	end)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Offset = 0.1
	atmo.Color = Color3.fromRGB(236, 236, 240)
	atmo.Decay = Color3.fromRGB(214, 216, 222)
	atmo.Glare = 0
	atmo.Haze = 1.2
	atmo.Parent = Lighting
	local cc = Lighting:FindFirstChild("Grade") or Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Saturation = 0.15
	cc.Contrast = 0.12
	cc.Brightness = -0.03
	cc.Parent = Lighting
end

-- 3D letters: a 5 x 7 dot font, each column's runs of dots merged into one block (a letter is 3 to 6 parts)
local FONT = {
	P = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
	L = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
	A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
	Y = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" },
	T = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
	U = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
	R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
	F = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
	W = { "10001", "10001", "10001", "10101", "10101", "10101", "01010" },
	S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
}

-- Words standing up along X, centred on cx, their feet at y0, at depth z: cell studs a dot, `thick` deep
local function letters(shapes, text, cx, y0, z, cell, opts, thick)
	local gap = cell * 1.2
	local width = #text * 5 * cell + (#text - 1) * gap
	local x = cx - width / 2
	for i = 1, #text do
		local glyph = FONT[string.sub(text, i, i)]
		if glyph then
			for col = 1, 5 do
				local run = 0
				for row = 1, 8 do
					local on = row <= 7 and string.sub(glyph[row], col, col) == "1"
					if on then
						run += 1
					elseif run > 0 then
						-- (rows count from the top: the run ended at row - 1)
						local top = y0 + (7 - (row - 1 - run)) * cell
						shapes:block(
							x + (col - 0.5) * cell,
							z,
							cell,
							thick or cell * 0.8,
							run * cell,
							opts,
							top - run * cell
						)
						run = 0
					end
				end
			end
		end
		x += 5 * cell + gap
	end
end

function LobbyBuilder.build(parent)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local shapes = setmetatable({
		folder = folder,
		solids = {},
		collide = {},
		white = Constants.WHITE,
		light = Constants.LIGHT,
		grey = Constants.GREY,
		dark = Constants.DARK,
	}, ArenaBuilder.Shapes)
	local H, HALF = LobbyBuilder.WALL, LobbyBuilder.HALF
	local world = { folder = folder, solids = shapes.solids, collide = shapes.collide, spots = SPOTS }
	local function trim(color, name)
		return deco({ color = color, name = name or "Trim" })
	end
	local function neon(color, name, transparency)
		return deco({ color = color, material = Enum.Material.Neon, name = name, transparency = transparency })
	end
	-- a box turned to face `dir` (its front toward it), its centre at pos
	local function facing(pos, dir, size, opts)
		return shapes:box(CFrame.lookAt(pos, pos + dir), size, opts)
	end
	-- a lamp post: a slim post on a plinth, a glowing cube (the "Lamp") under a cap
	local function lamp(x, z, h, color)
		shapes:block(x, z, 1.4, 1.4, 0.6, deco({ color = shapes.light, collide = true }))
		shapes:block(x, z, 0.5, 0.5, h, deco({ color = shapes.white, collide = true }), 0.6)
		shapes:block(x, z, 1.2, 1.2, 0.3, trim(shapes.light), h + 0.6)
		shapes:block(x, z, 0.9, 0.9, 0.9, neon(color or Color3.new(1, 1, 1), "Lamp"), h + 0.9)
		shapes:block(x, z, 1.3, 1.3, 0.25, trim(shapes.light), h + 1.8)
	end
	-- a square ring on the floor (four thin bars), looks only
	local function ring(x, z, w, color, y, bar)
		bar = bar or 0.4
		for _, s in { -1, 1 } do
			shapes:block(x + s * (w / 2), z, bar, w, 0.12, neon(color, "Ring"), y)
			shapes:block(x, z + s * (w / 2), w - bar * 2, bar, 0.12, neon(color, "Ring"), y)
		end
	end
	-- a sign on a post: the board faces `dir`, the words on it. opts: { board, trim, text } colours, h (the post), w
	local function post(x, z, dir, title, line, opts)
		opts = opts or {}
		local h, w = opts.h or 8, opts.w or 7
		shapes:block(x, z, 0.6, 0.6, h, deco({ color = shapes.grey, collide = true, name = "SignPost" }))
		shapes:block(x, z, 1.6, 1.6, 0.3, trim(shapes.light))
		local board =
			facing(V3(x, h + 1.6, z), dir, V3(w, 3.2, 0.4), deco({ color = opts.board or shapes.white, name = "Sign" }))
		for _, dy in { -1, 1 } do
			shapes:box(
				board.CFrame * CFrame.new(0, dy * 1.75, 0),
				V3(w + 0.3, 0.3, 0.5),
				deco({ color = opts.trim or GOLD, name = "SignTrim" })
			)
		end
		LobbyBuilder.sign(board, title, line, opts.text or INK)
		return board
	end

	-- The ground: the plaza's floor (one solid slab), a pale ground out past the walls so the world never ends at
	-- them, a skyline of plain blocks in the haze, and a tower at each corner outside the walls
	shapes:block(0, 0, HALF * 2 + 8, HALF * 2 + 8, 2, { color = shapes.white, name = "Floor" }, -2)
	shapes:block(0, 0, 1200, 1200, 1, deco({ color = shapes.light, shadow = false, name = "Ground" }), -4)
	local r = Random.new(2024)
	for i = 1, 26 do
		local a = (i / 26) * math.pi * 2 + r:NextNumber(-0.06, 0.06)
		local d = HALF + r:NextNumber(55, 140)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local w, dd, h = r:NextNumber(14, 34), r:NextNumber(14, 34), r:NextNumber(28, 96)
		local c = (i % 3 == 0) and shapes.light or ((i % 3 == 1) and shapes.white or shapes.grey)
		shapes:block(x, z, w, dd, h, deco({ color = c, shadow = false, name = "Skyline" }), -3)
		if i % 2 == 0 then
			shapes:block(
				x,
				z,
				w * 0.6,
				dd * 0.6,
				h * 0.18,
				deco({ color = shapes.white, shadow = false, name = "Skyline" }),
				h - 3
			)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			shapes:tower(sx * (HALF + 9), sz * (HALF + 9), 12, 12, 36, { crown = "spire", floor = 9 })
		end
	end
	-- the walkway from the spawn to PLAY (a lighter strip with gold edges), an avenue across the plaza, the spawn's
	-- ring and the big ring round the beacon (all looks only, flat on the floor)
	shapes:block(0, 0, 200, 10, 0.08, deco({ color = shapes.light, shadow = false, name = "Avenue" }), 0)
	shapes:block(0, 14, 12, 64, 0.1, deco({ color = shapes.light, shadow = false, name = "Walkway" }), 0.02)
	for _, s in { -1, 1 } do
		shapes:block(s * 6.2, 14, 0.4, 64, 0.14, neon(GOLD, "WalkwayEdge"), 0.02)
	end
	ring(0, 40, 12, GOLD, 0.05)
	shapes:block(0, 40, 9, 9, 0.12, deco({ color = shapes.white, shadow = false, name = "SpawnPad" }), 0.03)
	ring(0, -20, 44, GOLD, 0.05, 0.6)

	-- The walls: a plinth with a base molding, a string course, a crown molding of two steps under the coping, and an
	-- invisible shell above. Columns in bays along each wall; in each bay a recessed panel low down and a tall window
	-- over the string course, with a banner (red and blue in turn) on every other bay, and a lamp at the foot of every
	-- second column. Built in the wall's own frame: `along` runs along it, `across` is the way into the plaza.
	local function wall(axis, s)
		local face = s * HALF
		local function at(along, across, len, depth, h, opts, y0)
			if axis == "z" then
				return shapes:block(along, face - s * across, len, depth, h, opts, y0)
			end
			return shapes:block(face - s * across, along, depth, len, h, opts, y0)
		end
		local function pt(along, across)
			if axis == "z" then
				return along, face - s * across
			end
			return face - s * across, along
		end
		at(0, -1, HALF * 2 + 4, 2, H, { color = shapes.light, name = "Wall" })
		at(0, -1, HALF * 2 + 4, 2, LobbyBuilder.CEILING - H, { transparency = 1, shadow = false, name = "Shell" }, H)
		at(0, 0.4, HALF * 2, 0.8, 1, trim(shapes.grey, "Plinth"))
		at(0, 0.3, HALF * 2, 0.6, 0.35, trim(shapes.white, "Molding"), 1)
		at(0, 0.3, HALF * 2, 0.6, 0.5, trim(GOLD, "Molding"), 7)
		at(0, 0.3, HALF * 2, 0.6, 0.5, trim(shapes.light, "Molding"), H - 2)
		at(0, 0.55, HALF * 2, 1.1, 0.7, trim(shapes.white, "Molding"), H - 1.5)
		at(0, -1, HALF * 2 + 6, 2.6, 0.8, trim(shapes.white, "Molding"), H)
		for i = -2, 2 do
			local x, z = pt(i * 40, 2.2)
			shapes:column(x, z, H - 2, 1)
			if i % 2 == 0 then
				local lx, lz = pt(i * 40 + 6, 3)
				lamp(lx, lz, 7)
			end
		end
		for i = -2, 2 do
			local c = i * 40 + 20
			at(c, 0.15, 14, 0.3, 3.8, trim(shapes.white, "Panel"), 1.6)
			at(c, 0.3, 12.4, 0.3, 2.8, trim(shapes.grey), 2.1)
			at(c, 0.45, 11.4, 0.3, 2, trim(shapes.light), 2.5)
			if i % 2 == 0 then
				-- the banner: a rod, the cloth in a team's colour with a white stripe, a gold tassel (red and blue in turn)
				local team = (i / 2 + (axis == "x" and 1 or 0) + (s > 0 and 1 or 0)) % 2 == 0 and "red" or "blue"
				local color = Constants.TEAM_COLOR[team]
				at(c, 0.35, 4.2, 0.4, 0.4, trim(shapes.white, "BannerRod"), 16)
				at(c, 0.3, 3.2, 0.2, 7.2, deco({ color = color, name = "Banner" }), 8.6)
				at(c, 0.25, 0.6, 0.2, 6.8, trim(shapes.white, "Banner"), 8.8)
				at(c, 0.3, 1.2, 0.2, 0.8, trim(GOLD, "Banner"), 7.8)
			else
				-- the window: a white frame, the dark glass, a mullion
				at(c, 0.2, 6, 0.4, 6, trim(shapes.white, "Window"), 9)
				at(c, 0.35, 4.6, 0.4, 5.2, trim(shapes.dark, "Window"), 9.4)
				at(c, 0.45, 0.4, 0.4, 5.2, trim(shapes.white, "Window"), 9.4)
			end
		end
	end
	wall("z", -1)
	wall("z", 1)
	wall("x", -1)
	wall("x", 1)
	-- the game's name along the top of the north wall, in gold, seen from the spawn
	letters(shapes, "TURF WARS", 0, H + 0.8, -HALF - 1, 2, neon(GOLD, "Name"), 1.6)

	-- The spawn: a statue each side looking in, lamps down the walkway, trees at the plaza's corners
	shapes:statue(-16, 52, 1, 0.7, -1)
	shapes:statue(16, 52, -1, 0.7, 1)
	for _, z in { 28, -2 } do
		for _, x in { -9, 9 } do
			lamp(x, z, 7, GOLD)
		end
	end
	for _, p in { { -72, 32 }, { 72, 32 }, { -72, -62 }, { 72, -62 }, { -30, 80 }, { 30, 80 } } do
		shapes:tree(p[1], p[2], 7, shapes.light, shapes.white, 1.3)
	end

	-- The PLAY beacon: a dais of three steps under a gate (piers on plinths under capitals, a lintel on brackets, a
	-- cornice) with PLAY standing on it in gold, a column of gold light rising from the middle, a team flag on each
	-- pier. Walking onto the dais plays (the top step is the zone: "PlayBeacon").
	local px, pz = SPOTS.play.X, SPOTS.play.Z
	shapes:block(px, pz, 22, 22, 0.5, { color = shapes.light, name = "Dais" })
	shapes:block(px, pz, 18, 18, 0.5, { color = shapes.white, name = "Dais" }, 0.5)
	world.beacon = shapes:block(px, pz, 14, 14, 0.5, { color = shapes.light, name = "PlayBeacon" }, 1)
	ring(px, pz, 13, GOLD, 1.5)
	shapes:block(px, pz, 2.2, 2.2, 13, neon(GOLD, "Beam", 0.35), 1.5)
	shapes:block(px, pz, 3.2, 3.2, 0.4, neon(GOLD, "Beam"), 1.5)
	for _, sx in { -1, 1 } do
		local x = px + sx * 8
		shapes:block(x, pz, 4.2, 4.2, 1, { color = shapes.light, name = "Pier" }, 0.5)
		shapes:block(x, pz, 3, 3, 13.5, { color = shapes.white, name = "Pier" }, 1.5)
		shapes:block(x, pz, 3.8, 3.8, 0.8, trim(shapes.light, "Capital"), 14.2)
		shapes:block(x - sx * 1.6, pz, 0.3, 2, 10, trim(GOLD, "Inlay"), 3) -- (a gold inlay on the walkway's side)
		shapes:block(x + sx * 3.5, pz, 3, 2.6, 1.2, trim(shapes.light, "Bracket"), 13.8)
		shapes:flag(px + sx * 13.2, pz, 18.1, sx)
	end
	shapes:block(px, pz, 28, 3.4, 2.5, { color = shapes.white, name = "Lintel" }, 15)
	shapes:block(px, pz, 29.5, 4, 0.6, trim(shapes.light, "Cornice"), 17.5)
	shapes:block(px, pz, 24, 2.4, 0.3, trim(GOLD), 17.5)
	letters(shapes, "PLAY", px, 18.1, pz, 1, neon(GOLD, "PlayLetters"), 1.4)

	-- The mode portals beside it: an arch each, its opening glowing in the mode's colour, a pad in front, a sign
	-- above for its name and live count (LobbyController fills it)
	world.portals = {}
	for key, at in SPOTS.portals do
		local m = Modes[key] or {}
		local color = m.color or GOLD
		shapes:arch(at.X, at.Z, 8, 10, 2.5, "z", { pier = 2.5 })
		local glow = facing(V3(at.X, 5, at.Z), V3(0, 0, 1), V3(7.6, 9.6, 0.3), neon(color, "Portal", 0.45))
		glow:SetAttribute("Mode", key)
		shapes:block(at.X, at.Z + 5, 10, 5, 0.3, deco({ color = shapes.light, collide = true, name = "PortalPad" }))
		ring(at.X, at.Z + 5, 9, color, 0.3)
		local sign = facing(
			V3(at.X, 15.6, at.Z),
			V3(0, 0, 1),
			V3(11, 2.8, 0.5),
			deco({ color = shapes.white, name = "PortalSign" })
		)
		sign:SetAttribute("Mode", key)
		for _, dy in { -1, 1 } do
			shapes:box(
				sign.CFrame * CFrame.new(0, dy * 1.55, 0),
				V3(11.3, 0.3, 0.6),
				deco({ color = color, name = "SignTrim" })
			)
		end
		LobbyBuilder.sign(sign, string.upper(m.name or key), "", color)
		world.portals[key] = { part = glow, sign = sign }
	end

	-- The parkour: the start block with its sign, the platforms climbing the west wall (gold and white in turn), the
	-- checkpoints (a ring and a gold post), and the tower at the top: a shaft with string courses and slits, a top
	-- slab with a parapet on three sides (open where you arrive), a gold ring and a gold flag
	local P = LobbyBuilder.PARKOUR
	local start = SPOTS.parkour.start
	world.parkour = { checkpoints = {} }
	world.parkour.start = shapes:block(start.X, start.Z, 10, 10, 0.6, { color = GOLD, name = "ParkourStart" })
	ring(start.X, start.Z, 9, shapes.white, 0.6)
	post(
		start.X + 8,
		start.Z + 6,
		V3(1, 0, -0.3),
		"PARKOUR ▲",
		"CLIMB TO THE TOP",
		{ board = GOLD, trim = shapes.white, h = 9, w = 8 }
	)
	for i, top in P.platforms do
		local cp = i % P.every == 0
		local w = cp and 8 or 6
		local white = i % 2 == 0
		shapes:block(top.X, top.Z, w, w, 1, { color = white and shapes.white or GOLD, name = "Parkour" }, top.Y - 1)
		if white then
			-- (a gold band round a white block, so it reads against the white wall from the spawn)
			shapes:block(top.X, top.Z, w + 0.2, w + 0.2, 0.3, trim(GOLD, "ParkourBand"), top.Y - 0.8)
		end
		if cp then
			ring(top.X, top.Z, w - 1, shapes.white, top.Y)
			local p = shapes:block(top.X + 3, top.Z, 0.6, 0.6, 3, neon(GOLD, "ParkourCheckpoint"), top.Y)
			p:SetAttribute("Step", i)
			table.insert(world.parkour.checkpoints, p)
		end
	end
	local t = SPOTS.parkour.top
	shapes:block(t.X, t.Z, 11.2, 11.2, 1.2, { color = shapes.light, name = "Tower" })
	shapes:block(t.X, t.Z, 10, 10, t.Y, { color = shapes.white, name = "Tower" })
	for y = 8, t.Y - 6, 8 do
		shapes:block(t.X, t.Z, 10.5, 10.5, 0.4, trim(shapes.light, "Molding"), y)
		shapes:block(t.X + 5.05, t.Z, 0.2, 1, 3.2, trim(shapes.dark, "Window"), y - 5.6)
		shapes:block(t.X, t.Z + 5.05, 1, 0.2, 3.2, trim(shapes.dark, "Window"), y - 5.6)
	end
	shapes:block(t.X, t.Z, 12, 12, 1.2, { color = shapes.light, name = "Tower" }, t.Y)
	world.parkour.top = shapes:block(t.X, t.Z, 6, 6, 0.2, neon(GOLD, "ParkourTop"), t.Y + 1.2)
	shapes:block(
		t.X,
		t.Z - 5.7,
		12,
		0.6,
		1.4,
		deco({ color = shapes.white, collide = true, name = "Parapet" }),
		t.Y + 1.2
	)
	for _, sx in { -1, 1 } do
		shapes:block(
			t.X + sx * 5.7,
			t.Z - 0.3,
			0.6,
			11.4,
			1.4,
			deco({ color = shapes.white, collide = true, name = "Parapet" }),
			t.Y + 1.2
		)
	end
	shapes:block(t.X - 4.5, t.Z - 4.5, 0.4, 0.4, 9, trim(shapes.white, "FlagPole"), t.Y + 1.2)
	shapes:block(t.X - 2.8, t.Z - 4.5, 3.4, 0.15, 2.2, trim(GOLD, "Flag"), t.Y + 7.4)

	-- The leaderboards' stand on the east side: a plinth and a back wall under a crown molding, four boards facing the
	-- plaza with gold trims (LobbyController puts the names and numbers on them), the title over them, a column and a
	-- lamp each side
	local b = SPOTS.boards
	world.boards = {}
	shapes:block(b.X + 1, b.Z, 5, 34, 1, { color = shapes.light, name = "BoardsPlinth" })
	shapes:block(b.X + 2.5, b.Z, 1, 34, 13, { color = shapes.white, name = "BoardsWall" }, 1)
	shapes:block(b.X + 2.5, b.Z, 1.8, 35, 0.6, trim(shapes.light, "Molding"), 14)
	shapes:block(b.X + 2.5, b.Z, 2.4, 36, 0.5, trim(shapes.white, "Molding"), 14.6)
	local BOARDS = { "wins", "kills", "mvps", "streak" }
	for i, key in BOARDS do
		local z = b.Z + (i - 2.5) * 8
		local board = facing(
			V3(b.X + 1.7, 7, z),
			V3(-1, 0, 0),
			V3(7, 9.4, 0.5),
			deco({ color = shapes.white, name = "LobbyBoard" })
		)
		board:SetAttribute("Board", key)
		for _, dy in { -1, 1 } do
			shapes:box(
				board.CFrame * CFrame.new(0, dy * 4.85, 0),
				V3(7.3, 0.3, 0.6),
				deco({ color = GOLD, name = "BoardTrim" })
			)
		end
		world.boards[key] = board
	end
	local title = facing(
		V3(b.X + 1.7, 16.4, b.Z),
		V3(-1, 0, 0),
		V3(22, 3, 0.5),
		deco({ color = shapes.white, name = "BoardsSign" })
	)
	LobbyBuilder.sign(title, "🏆 LEADERBOARDS", nil, INK)
	for _, sz in { -1, 1 } do
		shapes:column(b.X - 1, b.Z + sz * 19.5, 16, 1)
		lamp(b.X - 6, b.Z + sz * 23, 7, GOLD)
	end

	-- The duel pads along the north side: a pad with a white ring and the two teams' halves, a sign saying its size
	world.pads = {}
	for i, at in SPOTS.duelPads do
		local pad =
			shapes:block(at.X, at.Z, 12, 12, 0.4, deco({ color = shapes.light, collide = true, name = "DuelPad" }))
		pad:SetAttribute("Size", i)
		ring(at.X, at.Z, 11, shapes.white, 0.4)
		shapes:block(
			at.X - 2.6,
			at.Z,
			4,
			4,
			0.1,
			deco({ color = Constants.TURF_COLOR.red, shadow = false, name = "PadHalf" }),
			0.4
		)
		shapes:block(
			at.X + 2.6,
			at.Z,
			4,
			4,
			0.1,
			deco({ color = Constants.TURF_COLOR.blue, shadow = false, name = "PadHalf" }),
			0.4
		)
		post(at.X, at.Z - 8, V3(0, 0, 1), `{i}v{i}`, "DUEL", { h = 7, w = 6 })
		table.insert(world.pads, pad)
	end

	-- The crate's stand: a raised platform with steps up from the walkway's side, a lip, a sign
	local c = SPOTS.crate
	shapes:platform(c.X, c.Z, 14, 14, 3, "-x", 6)
	world.crate = shapes:block(c.X, c.Z, 12, 12, 0.1, deco({ color = shapes.white, name = "CrateStand" }), 3.2)
	post(c.X + 6, c.Z + 8.8, V3(-1, 0, -0.3), "CRATE", "OPEN IT HERE", { board = GOLD, trim = shapes.white, h = 9 })

	-- The shop kiosks: a counter with a gold band, a back wall, posts under a canopy with a gold awning, and a sign
	-- hinting at a tab; the counter is the zone (walking up to it opens the shop: "ShopKiosk")
	world.kiosks = {}
	for _, k in LobbyBuilder.KIOSKS do
		local base = CFrame.lookAt(V3(k.at.X, 0, k.at.Z), V3(k.at.X, 0, k.at.Z) + k.face)
		local function piece(dx, y, dz, size, opts)
			return shapes:box(base * CFrame.new(dx, y, dz), size, opts)
		end
		local counter = piece(0, 1.5, -1, V3(6, 3, 2), { color = shapes.white, name = "ShopKiosk" })
		counter:SetAttribute("Hint", k.hint)
		counter:SetAttribute("Tab", k.tab)
		piece(0, 3.15, -1, V3(6.4, 0.3, 2.4), trim(shapes.light, "Counter"))
		piece(0, 2.4, -2.05, V3(6, 0.6, 0.1), trim(GOLD, "Counter"))
		piece(0, 4, 1.6, V3(6.4, 8, 0.6), { color = shapes.white, name = "KioskWall" })
		piece(0, 4.5, 1.25, V3(5, 2.6, 0.1), trim(shapes.grey, "Panel"))
		for _, sx in { -1, 1 } do
			piece(sx * 3, 4, -2.3, V3(0.5, 8, 0.5), deco({ color = shapes.white, collide = true, name = "KioskPost" }))
		end
		piece(0, 8.25, -0.4, V3(7.2, 0.5, 5), trim(shapes.light, "Canopy"))
		piece(0, 8.75, -0.4, V3(7.4, 0.5, 5.2), trim(GOLD, "Awning"))
		piece(0, 8.75, -3.05, V3(7.4, 0.5, 0.2), trim(shapes.white, "Awning"))
		local sign = piece(0, 10.6, -0.4, V3(7, 2.8, 0.4), deco({ color = shapes.white, name = "ShopKioskSign" }))
		sign:SetAttribute("Hint", k.hint)
		for _, dy in { -1, 1 } do
			piece(0, 10.6 + dy * 1.55, -0.4, V3(7.3, 0.3, 0.5), trim(GOLD, "SignTrim"))
		end
		LobbyBuilder.sign(sign, "🛒 SHOP", k.hint, INK)
		table.insert(world.kiosks, { part = counter, sign = sign, hint = k.hint, tab = k.tab })
	end

	-- The VERIFY stand by the spawn: a plinth, a pedestal under a cap, the 👍 board on top (the client's words change
	-- to thanks once you've tapped it)
	local v = SPOTS.verify
	local plinth = shapes:block(v.X, v.Z, 4, 4, 1, { color = shapes.light, name = "VerifyStand" })
	shapes:block(v.X, v.Z, 2.4, 2.4, 3, { color = shapes.white, name = "VerifyStand" }, 1)
	shapes:block(v.X, v.Z, 3, 3, 0.5, trim(shapes.light, "Capital"), 4)
	local vsign =
		facing(V3(v.X, 6.6, v.Z), V3(-1, 0, 0), V3(5, 4, 0.5), deco({ color = shapes.white, name = "VerifySign" }))
	for _, dy in { -1, 1 } do
		shapes:box(
			vsign.CFrame * CFrame.new(0, dy * 2.15, 0),
			V3(5.3, 0.3, 0.6),
			deco({ color = GOLD, name = "SignTrim" })
		)
	end
	LobbyBuilder.sign(vsign, "VERIFY 👍", "LIKE TURF WARS?", INK)
	world.verify = { part = plinth, sign = vsign }

	local n = 0
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	world.count = n
	folder.Parent = parent
	return world
end

return LobbyBuilder

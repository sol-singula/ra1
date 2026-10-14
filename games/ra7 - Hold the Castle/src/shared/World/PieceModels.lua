--[[
What every castle piece looks like (master plan §7, §14): a few reused chunky parts per piece, bright cartoon
stone and wood. The server builds a piece's model once and raises it out of the ground as it's built; the client
uses the same builder for the placement ghost; the render tools for the screenshots.

PieceModels.build(key, cf, opts) -> Model
  cf    the footprint's centre on the ground, turned the way the piece faces (its own X is its width)
  opts  { upgraded = bool, ghost = Color3 (a see-through preview in that colour), flag = look item (banners),
          parent = Instance }
Each model has a PrimaryPart ("Root", invisible, at cf) and, for gates, "DoorL"/"DoorR" (visual only) and an
invisible "Blocker" that monsters bump into.
]]
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Parent.Data.Pieces)

local PieceModels = {}

local C, M = Kit.C, Kit.M
local CELL = 4

local function v(x, y, z)
	return Vector3.new(x, y, z)
end

-- A small box with no collision or shadow (trim and details).
local function trim(m, name, cf, size, color, material)
	return Kit.box(m, name, cf, size, color, material or M.SmoothPlastic, { CanCollide = false, CastShadow = false })
end

local builders = {}

-- Stone wall: a light stone body on a darker plinth, a walkway ledge and merlons on both sides.
function builders.stoneWall(m, cf, w, _d, h, opts)
	local depth = opts.upgraded and 4.2 or 3.4
	Kit.box(m, "Plinth", cf * CFrame.new(0, 0.7, 0), v(w, 1.4, depth + 0.5), C.castleDark, M.Cobblestone)
	Kit.box(m, "Body", cf * CFrame.new(0, h * 0.46, 0), v(w, h * 0.92 - 1.4, depth), C.castle, M.Brick)
	Kit.box(m, "Ledge", cf * CFrame.new(0, h - 1.15, 0), v(w, 0.5, depth + 0.4), C.castleDark, M.Slate)
	for _, side in { -1, 1 } do
		for _, x in { -w / 4, w / 4 } do
			Kit.box(
				m,
				"Merlon",
				cf * CFrame.new(x, h - 0.1, side * (depth / 2 - 0.4)),
				v(w * 0.24, 1.6, 0.8),
				C.castle,
				M.Brick,
				{ CastShadow = false }
			)
		end
		-- a few stone blocks standing out of the face
		for k, p in { { -w * 0.28, h * 0.32 }, { w * 0.18, h * 0.55 }, { -w * 0.05, h * 0.18 } } do
			trim(
				m,
				"Block",
				cf * CFrame.new(p[1], p[2], side * (depth / 2 + 0.06)),
				v(w * (0.2 + k * 0.03), 1.1, 0.14),
				k == 2 and C.stone or C.castleDark
			)
		end
		if opts.upgraded then
			for _, x in { -w / 2 + 0.9, w / 2 - 0.9 } do
				Kit.wedge(
					m,
					"Buttress",
					cf
						* CFrame.new(x, h * 0.32, side * (depth / 2 + 0.7))
						* CFrame.Angles(0, side > 0 and 0 or math.pi, 0),
					v(1.2, h * 0.64, 1.4),
					C.castleDark,
					M.Cobblestone,
					{ CastShadow = false }
				)
			end
		end
	end
end

-- Wood wall: a palisade of pointed logs held by two braces (a stone base once upgraded).
function builders.woodWall(m, cf, w, d, h, opts)
	local logs = 5
	local base = 0
	if opts.upgraded then
		base = 3.4
		Kit.box(m, "StoneBase", cf * CFrame.new(0, base / 2, 0), v(w, base, d * 0.9), C.castle, M.Cobblestone)
		trim(m, "Cap", cf * CFrame.new(0, base, 0), v(w + 0.2, 0.4, d * 0.95), C.castleDark, M.Slate)
	end
	for i = 1, logs do
		local x = -w / 2 + (i - 0.5) * w / logs
		local lh = h - base - (i % 2) * 0.5
		Kit.disc(
			m,
			"Log",
			(cf * CFrame.new(x, base + lh / 2, 0)).Position,
			w / logs + 0.1,
			lh,
			i % 2 == 0 and C.woodLight or C.wood,
			M.Wood
		)
		trim(
			m,
			"Point",
			cf
				* CFrame.new(x, base + lh + 0.2, 0)
				* CFrame.Angles(0, math.rad(45), 0)
				* CFrame.Angles(math.rad(45), 0, 0),
			v(1, 1, 1),
			C.woodLight,
			M.Wood
		)
	end
	for _, y in { 0.3, 0.72 } do
		for _, side in { -1, 1 } do
			trim(m, "Brace", cf * CFrame.new(0, base + (h - base) * y, side * 0.95), v(w, 0.7, 0.3), C.woodDark, M.Wood)
		end
	end
end

-- Gate: two stone pillars and an arch with a pair of wooden doors (visual only: the invisible Blocker is what
-- stops monsters, so a door swinging open on a monster's screen never lets it through).
function builders.gate(m, cf, w, d, h, opts)
	local pillar = 1.7
	for _, s in { -1, 1 } do
		Kit.box(
			m,
			"Pillar",
			cf * CFrame.new(s * (w / 2 - pillar / 2), h / 2, 0),
			v(pillar, h, d * 1.05),
			C.castle,
			M.Brick
		)
		trim(
			m,
			"PillarCap",
			cf * CFrame.new(s * (w / 2 - pillar / 2), h + 0.35, 0),
			v(pillar + 0.5, 0.7, d * 1.15),
			opts.upgraded and C.iron or C.castleDark,
			opts.upgraded and M.Metal or M.Slate
		)
	end
	Kit.box(m, "Arch", cf * CFrame.new(0, h - 1.2, 0), v(w, 2.4, d * 1.05), C.castleDark, M.Cobblestone)
	trim(m, "Keystone", cf * CFrame.new(0, h - 1.2, -d * 0.53), v(1.4, 1.8, 0.2), C.gold, M.Metal)
	local doorW = (w - pillar * 2) / 2
	local doorH = h - 2.4
	local doorColor = opts.upgraded and C.iron or C.wood
	for _, s in { -1, 1 } do
		local door = Kit.box(
			m,
			s < 0 and "DoorL" or "DoorR",
			cf * CFrame.new(s * doorW / 2, doorH / 2, 0),
			v(doorW, doorH, 0.7),
			doorColor,
			opts.upgraded and M.Metal or M.WoodPlanks,
			{ CanCollide = false }
		)
		-- where the door swings from (the client animates it open for dwarves)
		door:SetAttribute("Hinge", (cf * CFrame.new(s * doorW, 0, 0)).Position)
		door:SetAttribute("Side", s)
		for _, y in { doorH * 0.25, doorH * 0.72 } do
			trim(
				m,
				"Band",
				cf * CFrame.new(s * doorW / 2, y, -0.4),
				v(doorW, 0.45, 0.12),
				opts.upgraded and C.gold or C.iron,
				M.Metal
			)
		end
	end
	local blocker = Kit.box(
		m,
		"Blocker",
		cf * CFrame.new(0, doorH / 2, 0),
		v(w - pillar * 2, doorH, 1.2),
		C.black,
		M.SmoothPlastic,
		{ Transparency = 1, CastShadow = false }
	)
	blocker:SetAttribute("Gate", true)
end

-- Archer tower: a round stone tower with a platform, merlons, a red cone roof on four posts and a ladder.
function builders.tower(m, cf, w, _d, h, opts)
	local body = opts.upgraded and 8.4 or 7.6
	local top = h - 6
	Kit.disc(m, "Base", (cf * CFrame.new(0, 1.2, 0)).Position, body + 1, 2.4, C.castleDark, M.Cobblestone)
	Kit.disc(m, "Body", (cf * CFrame.new(0, top / 2, 0)).Position, body, top, C.castle, M.Brick)
	for _, y in { top * 0.4, top * 0.75 } do
		trim(m, "Window", cf * CFrame.new(0, y, -body / 2 + 0.05), v(0.9, 1.8, 0.2), C.black)
	end
	Kit.disc(m, "Platform", (cf * CFrame.new(0, top + 0.5, 0)).Position, w + 2, 1, C.castleDark, M.Slate)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		if k % 2 == 0 then
			Kit.box(
				m,
				"Merlon",
				cf
					* CFrame.new(math.cos(a) * (w / 2 + 0.5), top + 1.8, math.sin(a) * (w / 2 + 0.5))
					* CFrame.Angles(0, -a, 0),
				v(0.8, 1.6, 1.8),
				C.castle,
				M.Brick,
				{ CastShadow = false }
			)
		end
	end
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		trim(
			m,
			"Post",
			cf * CFrame.new(c[1] * w * 0.38, top + 3.2, c[2] * w * 0.38),
			v(0.6, 4.4, 0.6),
			C.woodDark,
			M.Wood
		)
	end
	local roofColor = opts.flag and opts.flag.main or C.roofRed
	Kit.cone(
		m,
		"Roof",
		(cf * CFrame.new(0, top + 5.2, 0)).Position,
		w + (opts.upgraded and 3.4 or 2.4),
		opts.upgraded and 9 or 7,
		roofColor,
		7,
		M.ClayRoofTiles,
		{ CanCollide = false }
	)
	Kit.banner(
		m,
		cf * CFrame.new(0, top + (opts.upgraded and 13.6 or 11.6), 0),
		4,
		opts.flag and opts.flag.main or C.cloth,
		opts.flag and opts.flag.trim or C.gold,
		"TopFlag"
	)
	if opts.upgraded then
		trim(
			m,
			"GoldRing",
			cf * CFrame.new(0, top - 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			v(0.6, body + 0.3, body + 0.3),
			C.gold,
			M.Metal
		)
		for _, s in { -1, 1 } do
			Kit.box(
				m,
				"Hanging",
				cf * CFrame.new(s * body * 0.36, top - 3.4, -body / 2 - 0.1),
				v(1.6, 5, 0.2),
				opts.flag and opts.flag.main or C.cloth,
				M.Fabric,
				{ CanCollide = false, CastShadow = false }
			)
		end
	end
	-- the ladder up the back (a truss you can climb)
	local ladder = Kit.part({
		ClassName = "TrussPart",
		Name = "Ladder",
		Size = v(2, top, 2),
		CFrame = cf * CFrame.new(0, top / 2, body / 2 + 1),
		Color = C.woodDark,
		Material = M.Wood,
		Parent = m,
	})
	ladder.CastShadow = false
end

-- Quick wall: a fast barricade of planks.
function builders.quickWall(m, cf, w, _d, h, _opts)
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		Kit.box(m, "Post", cf * CFrame.new(x, h / 2, 0), v(0.8, h, 0.8), C.woodDark, M.Wood)
	end
	for k, y in { 1.1, 2.9, 4.7 } do
		Kit.box(
			m,
			"Plank",
			cf * CFrame.new(0, y, k % 2 == 0 and -0.3 or 0.3) * CFrame.Angles(0, 0, math.rad(k == 2 and 3 or -2)),
			v(w, 1.3, 0.5),
			k % 2 == 0 and C.wood or C.woodLight,
			M.WoodPlanks
		)
	end
	trim(
		m,
		"Brace",
		cf * CFrame.new(0, h / 2, -0.6) * CFrame.Angles(0, 0, math.atan2(h, w)),
		v(math.sqrt(w * w + h * h) - 1, 0.5, 0.25),
		C.woodDark,
		M.Wood
	)
end

-- Stairs: a wooden ramp up to the top of a wall (rises toward the piece's +Z).
function builders.stairs(m, cf, w, d, h, _opts)
	Kit.wedge(m, "Ramp", cf * CFrame.new(0, h / 2, 0), v(w - 0.4, h, d), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		trim(
			m,
			"Rail",
			cf * CFrame.new(s * (w / 2 - 0.2), h / 2 + 1, 0) * CFrame.Angles(-math.atan2(h, d), 0, 0),
			v(0.3, 0.4, math.sqrt(h * h + d * d)),
			C.woodDark,
			M.Wood
		)
	end
	for k = 1, 4 do
		local t = k / 5
		trim(m, "Step", cf * CFrame.new(0, h * t + 0.05, -d / 2 + d * t), v(w - 0.5, 0.2, 0.4), C.wood, M.Wood)
	end
end

-- Spike trap: a low wooden base bristling with steel spikes.
function builders.spikes(m, cf, w, _d, _h, _opts)
	Kit.box(m, "Base", cf * CFrame.new(0, 0.2, 0), v(w - 0.3, 0.4, w - 0.3), C.woodDark, M.WoodPlanks)
	for a = -1, 1 do
		for b = -1, 1 do
			trim(
				m,
				"Spike",
				cf
					* CFrame.new(a * 1.15, 0.9, b * 1.15)
					* CFrame.Angles(0, math.rad(45), 0)
					* CFrame.Angles(math.rad(8 * a), 0, math.rad(8 * b)),
				v(0.45, 1.3, 0.45),
				C.steel,
				M.Metal
			)
		end
	end
end

-- Pit trap: a dark hole in a wooden frame with stakes at the bottom.
function builders.pit(m, cf, w, _d, _h, _opts)
	trim(m, "Hole", cf * CFrame.new(0, 0.06, 0), v(w - 0.8, 0.12, w - 0.8), C.black)
	for k = 0, 3 do
		local a = k * math.pi / 2
		Kit.box(
			m,
			"Frame",
			cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.25, w / 2 - 0.35),
			v(w, 0.5, 0.7),
			C.wood,
			M.Wood,
			{ CastShadow = false }
		)
	end
	for _, p in { { -0.6, -0.5 }, { 0.7, 0.4 }, { 0, 0.9 }, { -0.4, 0.6 } } do
		trim(m, "Stake", cf * CFrame.new(p[1], 0.35, p[2]), v(0.25, 0.5, 0.25), C.woodLight, M.Wood)
	end
end

-- Oil pot: a black cauldron on a stand, full of glowing oil.
function builders.oilPot(m, cf, _w, _d, h, _opts)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Kit.box(m, "Leg", cf * CFrame.new(c[1] * 1.2, h * 0.3, c[2] * 1.2), v(0.45, h * 0.6, 0.45), C.woodDark, M.Wood)
	end
	Kit.box(m, "Shelf", cf * CFrame.new(0, h * 0.58, 0), v(3.4, 0.4, 3.4), C.wood, M.WoodPlanks)
	local pot = Kit.ball(m, "Pot", (cf * CFrame.new(0, h * 0.58 + 1.3, 0)).Position, 3, C.black, M.Metal)
	pot:SetAttribute("Oil", true)
	local oil = Kit.disc(
		m,
		"Oil",
		(cf * CFrame.new(0, h * 0.58 + 2.4, 0)).Position,
		2.3,
		0.2,
		C.fire,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	Kit.light(oil, "PointLight", { Color = C.warm, Range = 10, Brightness = 1 })
	trim(
		m,
		"Spout",
		cf * CFrame.new(0, h * 0.58 + 2.2, -1.6) * CFrame.Angles(math.rad(35), 0, 0),
		v(0.6, 0.6, 1.4),
		C.iron,
		M.Metal
	)
end

-- Fix-it station: a workbench with a big wrench and a blue gear.
function builders.fixStation(m, cf, w, _d, _h, _opts)
	Kit.box(m, "Top", cf * CFrame.new(0, 3, 0), v(w - 0.4, 0.5, w - 1), C.woodLight, M.WoodPlanks)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		trim(m, "Leg", cf * CFrame.new(c[1] * 1.5, 1.4, c[2] * 1.1), v(0.4, 2.8, 0.4), C.woodDark, M.Wood)
	end
	Kit.disc(m, "Gear", (cf * CFrame.new(-0.6, 3.9, 0.2)).Position, 2.2, 0.5, C.blue, M.Metal, { CanCollide = false })
	trim(
		m,
		"Wrench",
		cf * CFrame.new(0.9, 3.5, -0.2) * CFrame.Angles(0, math.rad(30), 0),
		v(0.4, 0.3, 2.6),
		C.steel,
		M.Metal
	)
	Kit.box(m, "Board", cf * CFrame.new(0, 4.6, 1.4), v(w - 0.8, 3, 0.3), C.wood, M.WoodPlanks, { CanCollide = false })
	for k = -1, 1 do
		trim(m, "Tool", cf * CFrame.new(k * 1, 4.8, 1.2), v(0.25, 1.8, 0.2), C.steel, M.Metal)
	end
end

-- Healing station: a stone basin with a glowing green crystal.
function builders.healStation(m, cf, w, _d, _h, _opts)
	Kit.disc(m, "Basin", (cf * CFrame.new(0, 0.9, 0)).Position, w - 0.6, 1.8, C.castle, M.Marble)
	Kit.disc(
		m,
		"Water",
		(cf * CFrame.new(0, 1.85, 0)).Position,
		w - 1.4,
		0.15,
		C.green:Lerp(C.white, 0.3),
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	local orb = Kit.crystals(m, (cf * CFrame.new(0, 1.8, 0)).Position, 3.4, C.green, Random.new(7), 3)
	local core = orb:FindFirstChildWhichIsA("BasePart")
	if core then
		Kit.light(core, "PointLight", { Color = C.green, Range = 14, Brightness = 1.2 })
	end
end

-- Forge: a stone furnace glowing orange, a chimney and an anvil.
function builders.forge(m, cf, w, d, h, _opts)
	Kit.box(
		m,
		"Furnace",
		cf * CFrame.new(-w * 0.18, h * 0.32, 0),
		v(w * 0.6, h * 0.64, d * 0.85),
		C.stoneDark,
		M.Cobblestone
	)
	local glow = trim(m, "Glow", cf * CFrame.new(-w * 0.18, h * 0.22, -d * 0.43), v(2.2, 1.8, 0.2), C.fire, M.Neon)
	Kit.light(glow, "PointLight", { Color = C.warm, Range = 14, Brightness = 1.6 })
	Kit.box(m, "Chimney", cf * CFrame.new(-w * 0.28, h * 0.8, 0.4), v(1.6, h * 0.5, 1.6), C.castleDark, M.Brick)
	Kit.box(m, "AnvilBase", cf * CFrame.new(w * 0.3, 0.9, 0), v(1, 1.8, 1), C.woodDark, M.Wood)
	Kit.box(m, "Anvil", cf * CFrame.new(w * 0.3, 2.2, 0), v(2.4, 0.8, 1.1), C.iron, M.Metal)
	trim(
		m,
		"Horn",
		cf * CFrame.new(w * 0.3 - 1.5, 2.25, 0) * CFrame.Angles(0, 0, math.rad(-15)),
		v(1, 0.4, 0.5),
		C.iron,
		M.Metal
	)
end

-- Kitchen: a counter, a big pot of stew on the fire and a striped awning.
function builders.kitchen(m, cf, w, d, h, _opts)
	Kit.box(m, "Counter", cf * CFrame.new(w * 0.15, 1.5, 0.4), v(w * 0.6, 3, d * 0.55), C.woodLight, M.WoodPlanks)
	Kit.box(m, "Hearth", cf * CFrame.new(-w * 0.28, 0.8, 0), v(2.8, 1.6, 2.8), C.stoneDark, M.Cobblestone)
	local stew = Kit.ball(m, "Pot", (cf * CFrame.new(-w * 0.28, 2.6, 0)).Position, 2.6, C.black, M.Metal)
	_ = stew
	Kit.disc(
		m,
		"Stew",
		(cf * CFrame.new(-w * 0.28, 3.55, 0)).Position,
		2,
		0.2,
		C.autumn,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	for _, s in { -1, 1 } do
		trim(m, "Pole", cf * CFrame.new(s * (w / 2 - 0.3), h * 0.5, 1.5), v(0.4, h, 0.4), C.woodDark, M.Wood)
	end
	for k = 0, 3 do
		Kit.wedge(
			m,
			"Awning",
			cf * CFrame.new(-w / 2 + (k + 0.5) * w / 4, h - 0.6, 0.2) * CFrame.Angles(0, math.pi, 0),
			v(w / 4, 1.2, d * 0.8),
			k % 2 == 0 and C.red or C.white,
			M.Fabric,
			{ CanCollide = false, CastShadow = k == 0 }
		)
	end
	for k = 0, 2 do
		trim(
			m,
			"Sausage",
			cf * CFrame.new(w * 0.05 + k * 0.9, h - 1.8, 1.4),
			v(0.5, 1, 0.5),
			C.mushroom:Lerp(C.dirt, 0.4)
		)
	end
end

-- Potion table: three bright bottles and a little bubbling pot.
function builders.potionTable(m, cf, w, _d, _h, _opts)
	Kit.box(m, "Top", cf * CFrame.new(0, 2.6, 0), v(w - 0.4, 0.4, w - 1), C.woodDark, M.WoodPlanks)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		trim(m, "Leg", cf * CFrame.new(c[1] * 1.5, 1.2, c[2] * 1.1), v(0.4, 2.4, 0.4), C.woodDark, M.Wood)
	end
	local colors = { C.crystalPink, C.crystal, C.plague }
	for k, col in colors do
		local x = -1.3 + (k - 1) * 1.3
		Kit.ball(
			m,
			"Bottle",
			(cf * CFrame.new(x, 3.4, -0.3)).Position,
			1.1,
			col,
			M.Neon,
			{ CanCollide = false, CastShadow = false }
		)
		trim(m, "Neck", cf * CFrame.new(x, 4.1, -0.3), v(0.35, 0.6, 0.35), C.white, M.Glass)
	end
	Kit.ball(m, "Cauldron", (cf * CFrame.new(0.4, 3.3, 0.9)).Position, 1.2, C.black, M.Metal, { CanCollide = false })
end

-- Banner: a tall flag in the builder's colours.
function builders.flag(m, cf, _w, _d, h, opts)
	Kit.disc(m, "Foot", (cf * CFrame.new(0, 0.3, 0)).Position, 2, 0.6, C.castleDark, M.Cobblestone)
	local look = opts.flag
	Kit.banner(m, cf, h, look and look.main or C.cloth, look and look.trim or C.gold, "Flag")
end

-- Shrine ward: a stone obelisk with a glowing crystal on top.
function builders.shrineWard(m, cf, _w, _d, h, _opts)
	Kit.box(m, "Foot", cf * CFrame.new(0, 0.5, 0), v(3.4, 1, 3.4), C.castleDark, M.Cobblestone)
	Kit.box(m, "Pillar", cf * CFrame.new(0, h * 0.42, 0), v(2.2, h * 0.75, 2.2), C.castle, M.Marble)
	for _, y in { h * 0.3, h * 0.55 } do
		trim(m, "Rune", cf * CFrame.new(0, y, -1.12), v(1, 0.5, 0.1), C.shrine, M.Neon)
	end
	local gem = Kit.box(
		m,
		"Gem",
		cf * CFrame.new(0, h * 0.86, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0),
		v(1.6, 1.6, 1.6),
		C.shrine,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	Kit.light(gem, "PointLight", { Color = C.shrine, Range = 12, Brightness = 1.2 })
end

-- The world CFrame of a footprint: cell (i, j), the piece's size in cells, its turn, the ground height.
function PieceModels.frame(piece, i, j, rot, groundY)
	local w, d = Pieces.cells(piece, rot)
	local cx, cz = (i + w / 2) * CELL, (j + d / 2) * CELL
	return CFrame.new(cx, groundY, cz) * CFrame.Angles(0, rot == 1 and math.rad(90) or 0, 0)
end

function PieceModels.build(key, cf, opts)
	opts = opts or {}
	local piece = Pieces.byKey[key]
	assert(piece, `unknown piece {key}`)
	local m = Instance.new("Model")
	m.Name = piece.name
	local root = Kit.box(m, "Root", cf, v(1, 1, 1), C.black, M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	m.PrimaryPart = root
	local w, d = piece.size[1] * CELL, piece.size[2] * CELL
	builders[key](m, cf, w, d, piece.height, opts)
	if opts.ghost then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p ~= root then
				p.Color = opts.ghost
				p.Material = M.SmoothPlastic
				p.Transparency = p.Name == "Blocker" and 1 or 0.55
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
			elseif p:IsA("Light") then
				p.Enabled = false
			end
		end
	end
	m.Parent = opts.parent
	return m
end

-- Cracks on a damaged piece (level 1: a few, level 2: many), on both faces. Returns the parts made.
function PieceModels.cracks(m, cf, piece, level)
	local made = {}
	local w, d = piece.size[1] * CELL, piece.size[2] * CELL
	local h = math.max(1, piece.height)
	local rng = Random.new(level * 31 + w)
	for _ = 1, level * 3 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		local x = rng:NextNumber(-w * 0.4, w * 0.4)
		local y = rng:NextNumber(h * 0.15, h * 0.85)
		table.insert(
			made,
			trim(
				m,
				"Crack",
				cf * CFrame.new(x, y, side * (d / 2 + 0.08)) * CFrame.Angles(0, 0, rng:NextNumber(-0.9, 0.9)),
				v(rng:NextNumber(1, 2.6), 0.22, 0.1),
				C.black:Lerp(C.castleDark, 0.3)
			)
		)
	end
	return made
end

return PieceModels

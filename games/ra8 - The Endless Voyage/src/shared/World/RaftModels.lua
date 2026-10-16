--[[
What the raft's pieces look like (master plan §5: the raft must change visibly). Every builder makes a Model of
plain anchored parts at a tile's place: build(key, cf, opts) with opts { colours = { sail, banner, deck }, edge = the
side a railing or net faces (0-3), level, hp share (damage shows as cracks) }. Pieces are 6 x 6 studs (Constants.TILE).

  RaftModels.build(key, cf, opts) -> model
  RaftModels.damage(model, share)   darken and crack a piece as its health goes
]]
local Constants = require(script.Parent.Parent.Constants)
local Kit = require(script.Parent.Kit)
local Progression = require(script.Parent.Parent.Data.Progression)

local RaftModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new
local T = Constants.TILE

local DECK_COLOR = {
	natural = C.plank,
	dark = C.woodDark,
	white = Color3.fromRGB(226, 220, 206),
}

local function colour(opts, kind)
	local key = opts and opts.colours and opts.colours[kind]
	local c = key and Progression.COLORS[key]
	return c and c.color or Progression.COLORS.white.color
end

local function deckColor(opts)
	local key = opts and opts.colours and opts.colours.deck
	return DECK_COLOR[key] or DECK_COLOR.natural
end

local function part(m, name, cf, size, color, material, extra)
	return Kit.box(m, name, cf, size, color, material, extra)
end

-- A tile's edge: 0 = +X, 1 = +Z, 2 = -X, 3 = -Z. The CFrame on that edge, facing out.
local function edgeCF(cf, edge)
	local a = math.rad((edge or 0) * 90)
	return cf * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -T / 2)
end
RaftModels.edgeCF = edgeCF

local build = {}

-- Structure ----------------------------------------------------------------------------------------------------
-- What keeps a tile up, and what makes it look like it floats: two pontoons running under it, half in the water
-- (the water is at cf.Y - DECK_Y), lashed on with rope, and a dark hull skirt under the planks so no light shows
-- through from below.
local function pontoons(m, cf, color, material)
	local still = { CanCollide = false, CastShadow = false }
	part(m, "Skirt", cf * CFrame.new(0, -0.62, 0), V3(T, 0.6, T), C.barkDark, M.Wood, { CanCollide = false })
	for _, sz in { -1, 1 } do
		Kit.cyl(m, "Pontoon", cf * CFrame.new(0, -Constants.DECK_Y, sz * 2), T - 0.2, 2.2, color, material, still)
		for _, sx in { -1.9, 1.9 } do
			Kit.cyl(m, "Lashing", cf * CFrame.new(sx, -Constants.DECK_Y, sz * 2), 0.25, 2.4, C.rope, M.Fabric, still)
		end
	end
end

function build.floor(m, cf, opts)
	local col = deckColor(opts)
	-- three planks across, a little gap between them, sat on two beams
	for k = -1, 1 do
		part(
			m,
			"Plank",
			cf * CFrame.new(k * 2, 0, 0),
			V3(1.85, 0.6, T - 0.1),
			col:Lerp(C.woodDark, (k + 1) * 0.06),
			M.WoodPlanks
		)
	end
	for k = -1, 1, 2 do
		part(m, "Beam", cf * CFrame.new(0, -0.6, k * 2.2), V3(T, 0.6, 0.6), C.woodDark, M.Wood, { CanCollide = false })
	end
	pontoons(m, cf, C.barkDark:Lerp(C.woodDark, 0.4), M.Wood)
end

function build.plank_floor(m, cf, opts)
	local col = deckColor(opts):Lerp(C.woodLight, 0.2)
	part(m, "Deck", cf, V3(T, 0.7, T), col, M.WoodPlanks)
	part(m, "Trim", cf * CFrame.new(0, 0.05, 0), V3(T + 0.1, 0.5, T + 0.1), col:Lerp(C.woodDark, 0.35), M.Wood, {
		CanCollide = false,
	})
	pontoons(m, cf, C.iron, M.Metal)
end

function build.stairs(m, cf, opts)
	-- a floor tile with a flight of steps up to the deck above, rising along +Z
	build.floor(m, cf, opts)
	local steps = 6
	local rise = Constants.DECK_HEIGHT / steps
	for i = 1, steps do
		part(
			m,
			"Step",
			cf * CFrame.new(0, 0.3 + i * rise - rise / 2, -T / 2 + i * (T / steps) - T / steps / 2),
			V3(T - 1, rise, T / steps + 0.1),
			C.wood,
			M.WoodPlanks
		)
	end
	for _, sx in { -1, 1 } do
		part(
			m,
			"Rail",
			cf * CFrame.new(sx * (T / 2 - 0.3), Constants.DECK_HEIGHT / 2 + 0.8, 0) * CFrame.Angles(math.rad(-50), 0, 0),
			V3(0.3, 0.3, 9.2),
			C.woodDark,
			M.Wood,
			{ CanCollide = false }
		)
	end
end

function build.railing(m, cf, opts)
	local e = edgeCF(cf, opts and opts.edge)
	for k = -1, 1 do
		part(m, "Post", e * CFrame.new(k * 2.6, 1.2, 0.2), V3(0.4, 2.4, 0.4), C.woodDark, M.Wood)
	end
	part(m, "Rail", e * CFrame.new(0, 2.2, 0.2), V3(T, 0.35, 0.4), C.wood, M.Wood)
	part(m, "Rail", e * CFrame.new(0, 1.1, 0.2), V3(T, 0.25, 0.3), C.wood, M.Wood, { CanCollide = false })
end

function build.ladder(m, cf, opts)
	local e = edgeCF(cf, opts and opts.edge)
	for _, sx in { -1, 1 } do
		part(
			m,
			"Side",
			e * CFrame.new(sx * 0.8, -1.2, -0.4),
			V3(0.3, 5, 0.3),
			C.woodDark,
			M.Wood,
			{ CanCollide = false }
		)
	end
	for i = 0, 4 do
		part(
			m,
			"Rung",
			e * CFrame.new(0, -3.4 + i * 1.1, -0.4),
			V3(1.9, 0.25, 0.3),
			C.wood,
			M.Wood,
			{ CanCollide = false }
		)
	end
	-- (a TrussPart does the climbing)
	local truss = Instance.new("TrussPart")
	truss.Name = "Climb"
	truss.Size = V3(2, 6, 2)
	truss.CFrame = e * CFrame.new(0, -1.5, -0.9)
	truss.Anchored = true
	truss.Transparency = 1
	truss.Parent = m
end

function build.wall(m, cf, opts)
	local e = edgeCF(cf, opts and opts.edge)
	part(m, "Wall", e * CFrame.new(0, 2.7, 0.2), V3(T, 5.4, 0.5), deckColor(opts):Lerp(C.woodLight, 0.1), M.WoodPlanks)
	part(m, "Window", e * CFrame.new(1.4, 3.2, 0.2), V3(1.6, 1.4, 0.6), C.glowcap:Lerp(C.white, 0.5), M.Glass, {
		Transparency = 0.5,
		CanCollide = false,
	})
end

function build.roof(m, cf, opts)
	part(m, "Roof", cf * CFrame.new(0, 5.9, 0), V3(T + 0.6, 0.5, T + 0.6), C.canvas, M.Fabric, { CanCollide = false })
	part(m, "Thatch", cf * CFrame.new(0, 6.25, 0), V3(T + 0.2, 0.3, T + 0.2), C.fern:Lerp(C.canvas, 0.4), M.Grass, {
		CanCollide = false,
		CastShadow = false,
	})
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				m,
				"Post",
				cf * CFrame.new(sx * 2.6, 3, sz * 2.6),
				V3(0.35, 5.6, 0.35),
				C.woodDark,
				M.Wood,
				{ CanCollide = false }
			)
		end
	end
	_ = opts
end

-- Stations -----------------------------------------------------------------------------------------------------
local function bench(m, cf, top, legs)
	part(m, "Top", cf * CFrame.new(0, 1.7, 0), V3(4.4, 0.3, 2.2), top, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(
				m,
				"Leg",
				cf * CFrame.new(sx * 1.9, 0.9, sz * 0.8),
				V3(0.3, 1.5, 0.3),
				legs,
				M.Wood,
				{ CanCollide = false }
			)
		end
	end
end

function build.workbench(m, cf)
	bench(m, cf, C.wood, C.woodDark)
	part(m, "Vice", cf * CFrame.new(1.4, 2.1, 0), V3(0.8, 0.6, 0.8), C.iron, M.Metal, { CanCollide = false })
	part(
		m,
		"Saw",
		cf * CFrame.new(-1, 1.95, 0.3) * CFrame.Angles(0, 0.4, 0),
		V3(1.8, 0.1, 0.5),
		C.steel,
		M.Metal,
		{ CanCollide = false }
	)
end

function build.refinery(m, cf)
	part(m, "Drum", cf * CFrame.new(-1.2, 1.5, 0), V3(2.2, 3, 2.2), C.iron, M.CorrodedMetal)
	Kit.disc(
		m,
		"Lid",
		cf.Position + cf.RightVector * -1.2 + V3(0, 3.1, 0),
		2.3,
		0.3,
		C.steel,
		M.Metal,
		{ CanCollide = false }
	)
	part(m, "Chimney", cf * CFrame.new(-1.2, 4.2, 0), V3(0.6, 2, 0.6), C.rockDark, M.Metal, { CanCollide = false })
	bench(m, cf * CFrame.new(1.4, 0, 0), C.woodDark, C.woodDark)
	local glow =
		part(m, "Glow", cf * CFrame.new(-1.2, 1, 1.15), V3(1, 0.8, 0.1), C.fire, M.Neon, { CanCollide = false })
	Kit.light(glow, "PointLight", { Name = "Fire", Color = C.fire, Range = 8, Brightness = 0.8 })
end

function build.engineering(m, cf)
	bench(m, cf, C.steel, C.iron)
	part(m, "Panel", cf * CFrame.new(0, 3, -0.9), V3(3.6, 1.6, 0.3), C.iron, M.Metal, { CanCollide = false })
	for k = -1, 1 do
		part(
			m,
			"Dial",
			cf * CFrame.new(k * 1.1, 3, -1.08),
			V3(0.5, 0.5, 0.1),
			k == 0 and C.good or C.warm,
			M.Neon,
			{ CanCollide = false }
		)
	end
	part(
		m,
		"Gear",
		cf * CFrame.new(1.4, 2.2, 0.4),
		V3(0.9, 0.9, 0.3),
		C.gold:Lerp(C.iron, 0.5),
		M.Metal,
		{ CanCollide = false }
	)
end

function build.research(m, cf)
	bench(m, cf, C.woodDark, C.woodDark)
	part(
		m,
		"Book",
		cf * CFrame.new(-0.8, 1.95, 0),
		V3(1.2, 0.2, 1.5),
		C.blue:Lerp(C.ink, 0.3),
		M.Fabric,
		{ CanCollide = false }
	)
	part(
		m,
		"Lens",
		cf * CFrame.new(1.2, 2.6, 0) * CFrame.Angles(0, 0, math.rad(60)),
		V3(0.3, 2, 0.3),
		C.iron,
		M.Metal,
		{ CanCollide = false }
	)
	local globe = Kit.ball(
		m,
		"Globe",
		cf.Position + V3(0, 3.6, 0) + cf.RightVector * 1.2,
		1.1,
		C.glowcap,
		M.Neon,
		{ CanCollide = false }
	)
	Kit.light(globe, "PointLight", { Name = "Glow", Color = C.glowcap, Range = 9, Brightness = 0.6 })
end

function build.cookpot(m, cf)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		part(
			m,
			"Leg",
			cf * CFrame.new(math.cos(a) * 1.2, 1, math.sin(a) * 1.2) * CFrame.Angles(0, -a, math.rad(12)),
			V3(0.3, 2.4, 0.3),
			C.iron,
			M.Metal,
			{ CanCollide = false }
		)
	end
	Kit.ball(m, "Pot", cf.Position + V3(0, 2.2, 0), 2.4, C.iron, M.Metal)
	Kit.disc(m, "Stew", cf.Position + V3(0, 3.3, 0), 1.8, 0.2, C.autumn, M.SmoothPlastic, { CanCollide = false })
	local fire = part(m, "Fire", cf * CFrame.new(0, 0.6, 0), V3(1.2, 0.8, 1.2), C.fire, M.Neon, { CanCollide = false })
	local f = Instance.new("Fire")
	f.Size = 3
	f.Heat = 6
	f.Parent = fire
	Kit.light(fire, "PointLight", { Name = "Glow", Color = C.fire, Range = 10, Brightness = 1 })
end

function build.decor_shop(m, cf)
	bench(m, cf, C.woodLight, C.woodDark)
	local cols = { C.canvasRed, C.blue, C.leafLight, C.gold }
	for k, col in cols do
		part(
			m,
			"Pot",
			cf * CFrame.new(-1.6 + (k - 1) * 1.05, 2.1, 0.4),
			V3(0.7, 0.8, 0.7),
			col,
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	part(
		m,
		"Easel",
		cf * CFrame.new(0, 3.2, -0.9) * CFrame.Angles(math.rad(-10), 0, 0),
		V3(2.6, 2, 0.2),
		C.cream,
		M.Fabric,
		{ CanCollide = false }
	)
end

-- Systems ------------------------------------------------------------------------------------------------------
function build.storage(m, cf)
	part(m, "Box", cf * CFrame.new(0, 1.3, 0), V3(3.6, 2.6, 2.6), C.wood, M.WoodPlanks)
	part(m, "Lid", cf * CFrame.new(0, 2.75, 0), V3(3.8, 0.3, 2.8), C.woodDark, M.Wood, { CanCollide = false })
	for _, sx in { -1, 1 } do
		part(m, "Band", cf * CFrame.new(sx * 1.2, 1.3, 0), V3(0.3, 2.7, 2.7), C.iron, M.Metal, { CanCollide = false })
	end
end

-- A net: a tile of its own. A frame round open water (walk on the frame, see down into the sea), a float under
-- each side, and the net hanging from the frame's inside in a deep sagging bowl below the water; what it has
-- caught floats in the bowl (RaftModels.showCatch: the server calls it as the catch changes).
local NET_HOLE = 3.9 -- the open middle, across
local function netTile(m, cf, frameColor, frameMaterial, cordColor)
	local still = { CanCollide = false, CastShadow = false }
	local side = (T - NET_HOLE) / 2
	for i = 0, 3 do
		local a = math.rad(i * 90)
		local edge = cf * CFrame.Angles(0, a, 0)
		part(m, "Frame", edge * CFrame.new(0, 0, (T - side) / 2), V3(T, 0.6, side), frameColor, frameMaterial)
		part(
			m,
			"Rim",
			edge * CFrame.new(0, -0.42, NET_HOLE / 2 + 0.05),
			V3(NET_HOLE + 0.2, 0.16, 0.16),
			C.rope,
			M.Fabric,
			still
		)
		Kit.cyl(
			m,
			"Float",
			edge * CFrame.new(0, -Constants.DECK_Y + 0.25, T / 2 - side / 2),
			T - 0.6,
			1.5,
			C.barkDark,
			M.Wood,
			still
		)
	end
	-- the bowl: cords across both ways, each sagging deepest in the middle, into the water and below
	local h = NET_HOLE / 2
	local function sag(u, v)
		-- (u, v from -1 to 1 across the hole: 0 at the rim, deepest at the middle)
		local depth = (1 - u * u) * (1 - 0.55 * v * v)
		return -0.45 - depth * 3.1
	end
	for _, axis in { "x", "z" } do
		for k = -2, 2 do
			local v = k / 2.2
			local prev
			for j = 0, 6 do
				local u = -1 + j / 3
				local pos = axis == "x" and V3(u * h, sag(u, v), v * h) or V3(v * h, sag(u, v), u * h)
				local world = cf:PointToWorldSpace(pos)
				if prev then
					local len = (world - prev).Magnitude
					part(
						m,
						"Cord",
						CFrame.lookAt(prev, world) * CFrame.new(0, 0, -len / 2),
						V3(0.07, 0.07, len + 0.05),
						cordColor,
						M.Fabric,
						still
					)
				end
				prev = world
			end
		end
	end
	local catch = Instance.new("Folder")
	catch.Name = "Catch"
	catch.Parent = m
end

function build.net(m, cf, opts)
	netTile(m, cf, deckColor(opts):Lerp(C.woodDark, 0.25), M.WoodPlanks, C.rope)
end

function build.salvage_net(m, cf, opts)
	netTile(m, cf, C.iron:Lerp(C.steel, 0.4), M.Metal, C.rope:Lerp(C.white, 0.35))
	local lamp = part(m, "Lamp", cf * CFrame.new(T / 2 - 0.4, 1.2, T / 2 - 0.4), V3(0.5, 0.5, 0.5), C.glowcap, M.Neon, {
		CanCollide = false,
	})
	part(m, "LampPost", cf * CFrame.new(T / 2 - 0.4, 0.6, T / 2 - 0.4), V3(0.2, 1.2, 0.2), C.iron, M.Metal, {
		CanCollide = false,
	})
	Kit.light(lamp, "PointLight", { Name = "Glow", Color = C.glowcap, Range = 8, Brightness = 0.5 })
	_ = opts
end

-- What a net holds, floating in its bowl: a little piece of each (up to six), the newest on top.
local CATCH_SPOTS = { { -0.8, -0.7 }, { 0.8, 0.6 }, { 0.7, -0.8 }, { -0.7, 0.8 }, { 0, 0 }, { 0, -1.1 } }
local function catchPiece(folder, key, cf)
	local still = { CanCollide = false, CanQuery = false, CastShadow = false }
	if key == "wood" or key == "plank" then
		part(folder, "Caught", cf * CFrame.Angles(0, 0.4, 0), V3(1.5, 0.22, 0.38), C.woodLight, M.Wood, still)
		part(
			folder,
			"Caught",
			cf * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, -0.6, 0),
			V3(1.3, 0.2, 0.34),
			C.wood,
			M.Wood,
			still
		)
	elseif key == "rope" then
		Kit.cyl(folder, "Caught", cf * CFrame.Angles(0, 0, math.rad(90)), 0.3, 0.95, C.rope, M.Fabric, still)
	elseif key == "cloth" then
		part(folder, "Caught", cf * CFrame.Angles(0, 0.7, 0.15), V3(1, 0.2, 0.8), C.canvas, M.Fabric, still)
	elseif key == "scrap" or key == "metal" then
		part(folder, "Caught", cf * CFrame.Angles(0.3, 0.5, 0), V3(0.8, 0.45, 0.6), C.steel, M.Metal, still)
		part(
			folder,
			"Caught",
			cf * CFrame.new(0.3, 0.2, 0) * CFrame.Angles(0, 1.1, 0.4),
			V3(0.9, 0.12, 0.2),
			C.iron,
			M.Metal,
			still
		)
	elseif key == "bottle" then
		Kit.cyl(folder, "Caught", cf * CFrame.Angles(0, 0.4, math.rad(60)), 0.8, 0.45, C.leafLight, M.Glass, still)
	else
		part(folder, "Caught", cf * CFrame.Angles(0, 0.5, 0), V3(0.8, 0.8, 0.8), C.woodLight, M.WoodPlanks, still)
	end
end

function RaftModels.showCatch(model, held)
	local folder = model and model:FindFirstChild("Catch")
	if not folder then
		return
	end
	folder:ClearAllChildren()
	local origin = model:GetAttribute("Origin") or model:GetPivot()
	local list = held or {}
	local n = math.min(#list, #CATCH_SPOTS)
	for i = 1, n do
		local it = list[#list - n + i]
		local spot = CATCH_SPOTS[i]
		-- floating at the water, in the bowl
		local cf = origin * CFrame.new(spot[1], -Constants.DECK_Y + 0.15, spot[2])
		catchPiece(folder, it.key, cf)
	end
	model:SetAttribute("Caught", #list)
end

function build.sail(m, cf, opts)
	part(m, "Mast", cf * CFrame.new(0, 7, 0), V3(0.6, 14, 0.6), C.woodDark, M.Wood)
	part(m, "Boom", cf * CFrame.new(0, 3.2, 1.6), V3(0.4, 0.4, 5.4), C.woodDark, M.Wood, { CanCollide = false })
	part(m, "Yard", cf * CFrame.new(0, 12.6, 1.4), V3(0.35, 0.35, 5), C.woodDark, M.Wood, { CanCollide = false })
	part(
		m,
		"Canvas",
		cf * CFrame.new(0.2, 7.9, 1.6) * CFrame.Angles(0, 0, math.rad(-6)),
		V3(0.2, 9, 4.8),
		colour(opts, "sail"),
		M.Fabric,
		{
			CanCollide = false,
		}
	)
	part(m, "Base", cf * CFrame.new(0, 0.6, 0), V3(1.6, 1.2, 1.6), C.wood, M.Wood)
end

function build.engine(m, cf)
	part(m, "Block", cf * CFrame.new(0, 1.4, 0), V3(3.4, 2.8, 2.6), C.iron, M.Metal)
	part(m, "Stack", cf * CFrame.new(-0.8, 3.6, 0), V3(0.8, 2, 0.8), C.rockDark, M.Metal, { CanCollide = false })
	part(m, "Pipe", cf * CFrame.new(1.2, 1.2, 1.7), V3(0.5, 0.5, 1.6), C.steel, M.Metal, { CanCollide = false })
	local wheel = Kit.cyl(
		m,
		"Flywheel",
		cf * CFrame.new(1.9, 1.6, 0) * CFrame.Angles(0, 0, 0),
		0.4,
		2,
		C.gold:Lerp(C.iron, 0.6),
		M.Metal,
		{ CanCollide = false }
	)
	_ = wheel
	local glow =
		part(m, "Glow", cf * CFrame.new(0, 1.4, -1.35), V3(1.4, 0.6, 0.1), C.warm, M.Neon, { CanCollide = false })
	Kit.light(glow, "PointLight", { Name = "Glow", Color = C.warm, Range = 6, Brightness = 0.5 })
end

function build.nav_table(m, cf)
	bench(m, cf, C.woodDark, C.woodDark)
	part(m, "Map", cf * CFrame.new(0, 1.9, 0), V3(3.6, 0.1, 1.8), C.cream, M.Fabric, { CanCollide = false })
	part(
		m,
		"Route",
		cf * CFrame.new(0.4, 1.96, 0.2) * CFrame.Angles(0, 0.5, 0),
		V3(2.2, 0.05, 0.1),
		C.canvasRed,
		M.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	Kit.disc(
		m,
		"Compass",
		cf.Position + V3(0, 2.05, 0) + cf.RightVector * -1.4,
		0.9,
		0.2,
		C.gold,
		M.Metal,
		{ CanCollide = false }
	)
end

function build.crow_nest(m, cf)
	part(m, "Mast", cf * CFrame.new(0, 5, 0), V3(0.6, 10, 0.6), C.woodDark, M.Wood)
	Kit.disc(m, "Floor", cf.Position + V3(0, 9.8, 0), 3.6, 0.4, C.wood, M.WoodPlanks)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		part(
			m,
			"Post",
			cf * CFrame.new(math.cos(a) * 1.6, 10.9, math.sin(a) * 1.6),
			V3(0.25, 1.8, 0.25),
			C.woodDark,
			M.Wood,
			{ CanCollide = false }
		)
	end
	Kit.disc(m, "Rim", cf.Position + V3(0, 11.8, 0), 3.7, 0.25, C.woodDark, M.Wood, { CanCollide = false })
	part(
		m,
		"Telescope",
		cf * CFrame.new(0.8, 11.6, -0.8) * CFrame.Angles(math.rad(20), math.rad(-35), 0),
		V3(0.3, 0.3, 1.8),
		C.gold,
		M.Metal,
		{ CanCollide = false }
	)
end

function build.anchor(m, cf)
	part(m, "Winch", cf * CFrame.new(0, 1, 0), V3(2.6, 2, 2), C.woodDark, M.Wood)
	Kit.cyl(m, "Drum", cf * CFrame.new(0, 1.3, 0), 2.8, 1.4, C.wood, M.Wood, { CanCollide = false })
	part(
		m,
		"Shank",
		cf * CFrame.new(1.8, 1.6, 0) * CFrame.Angles(0, 0, math.rad(20)),
		V3(0.4, 3.2, 0.4),
		C.iron,
		M.Metal,
		{ CanCollide = false }
	)
	part(m, "Arms", cf * CFrame.new(2.2, 0.4, 0), V3(0.4, 0.4, 2.8), C.iron, M.Metal, { CanCollide = false })
	part(m, "Ring", cf * CFrame.new(1.2, 3.2, 0), V3(0.9, 0.9, 0.3), C.iron, M.Metal, { CanCollide = false })
end

function build.spikes(m, cf, opts)
	local e = edgeCF(cf, opts and opts.edge)
	part(m, "Bar", e * CFrame.new(0, -0.2, -0.3), V3(T, 0.4, 0.4), C.iron, M.CorrodedMetal, { CanCollide = false })
	for k = -2, 2 do
		part(
			m,
			"Spike",
			e * CFrame.new(k * 1.15, -0.3, -1.1) * CFrame.Angles(math.rad(-30), 0, 0),
			V3(0.25, 0.25, 1.8),
			C.steel,
			M.Metal,
			{ CanCollide = false }
		)
	end
end

function build.harpoon_turret(m, cf)
	Kit.disc(m, "Base", cf.Position + V3(0, 0.5, 0), 3.4, 1, C.iron, M.Metal)
	part(m, "Pivot", cf * CFrame.new(0, 1.6, 0), V3(1.2, 1.4, 1.2), C.rockDark, M.Metal, { CanCollide = false })
	part(
		m,
		"Barrel",
		cf * CFrame.new(0, 2.4, -1.2) * CFrame.Angles(math.rad(-12), 0, 0),
		V3(0.6, 0.6, 4),
		C.steel,
		M.Metal,
		{ CanCollide = false }
	)
	part(
		m,
		"Harpoon",
		cf * CFrame.new(0, 2.4, -3.3) * CFrame.Angles(math.rad(-12), 0, 0),
		V3(0.2, 0.2, 2),
		C.steel,
		M.Metal,
		{ CanCollide = false }
	)
	part(m, "Seat", cf * CFrame.new(0, 1.9, 1.6), V3(1.4, 0.3, 1.2), C.wood, M.Wood, { CanCollide = false })
end

function build.bed(m, cf, opts)
	part(m, "Frame", cf * CFrame.new(0, 0.6, 0), V3(5, 0.6, 3), C.woodDark, M.Wood)
	part(m, "Mattress", cf * CFrame.new(0, 1.15, 0), V3(4.8, 0.5, 2.8), C.cream, M.Fabric, { CanCollide = false })
	part(
		m,
		"Blanket",
		cf * CFrame.new(0.8, 1.45, 0),
		V3(3, 0.2, 2.9),
		colour(opts, "banner"),
		M.Fabric,
		{ CanCollide = false }
	)
	part(m, "Pillow", cf * CFrame.new(-1.8, 1.5, 0), V3(1, 0.4, 2), C.white, M.Fabric, { CanCollide = false })
end

function build.planter(m, cf)
	part(m, "Box", cf * CFrame.new(0, 0.6, 0), V3(5, 1.2, 3), C.woodDark, M.Wood)
	part(m, "Soil", cf * CFrame.new(0, 1.15, 0), V3(4.8, 0.2, 2.8), C.dirt, M.Ground, { CanCollide = false })
	for k = -1, 1 do
		Kit.ball(
			m,
			"Bush",
			cf.Position + V3(0, 1.8, 0) + cf.RightVector * (k * 1.5),
			1.3,
			C.leaf,
			M.Grass,
			{ CanCollide = false }
		)
		Kit.ball(
			m,
			"Berry",
			cf.Position + V3(0.3, 2.1, 0.4) + cf.RightVector * (k * 1.5),
			0.35,
			C.flowerBlue,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
end

function build.lamp(m, cf)
	part(m, "Post", cf * CFrame.new(0, 2.6, 0), V3(0.35, 5.2, 0.35), C.iron, M.Metal)
	part(m, "Arm", cf * CFrame.new(0.6, 5, 0), V3(1.4, 0.25, 0.25), C.iron, M.Metal, { CanCollide = false })
	local lamp = part(m, "Lamp", cf * CFrame.new(1.2, 4.5, 0), V3(0.8, 1, 0.8), C.warm, M.Neon, { CanCollide = false })
	Kit.light(lamp, "PointLight", { Name = "Glow", Color = C.warm, Range = 18, Brightness = 1.4 })
end

function build.aquarium(m, cf)
	part(m, "Stand", cf * CFrame.new(0, 0.6, 0), V3(5, 1.2, 3), C.woodDark, M.Wood)
	part(m, "Tank", cf * CFrame.new(0, 2.4, 0), V3(4.8, 2.4, 2.8), Color3.fromRGB(120, 200, 230), M.Glass, {
		Transparency = 0.55,
		CanCollide = false,
	})
	part(
		m,
		"Water",
		cf * CFrame.new(0, 2.2, 0),
		V3(4.6, 1.9, 2.6),
		C.water,
		M.Glass,
		{ Transparency = 0.7, CanCollide = false }
	)
	local glow =
		part(m, "Light", cf * CFrame.new(0, 3.7, 0), V3(4.8, 0.2, 2.8), C.glowcap, M.Neon, { CanCollide = false })
	Kit.light(glow, "PointLight", { Name = "Glow", Color = C.glowcap, Range = 10, Brightness = 0.7 })
end

function build.trophy_stand(m, cf)
	part(m, "Plinth", cf * CFrame.new(0, 0.8, 0), V3(3, 1.6, 3), C.stone, M.Rock)
	part(m, "Top", cf * CFrame.new(0, 1.7, 0), V3(3.3, 0.3, 3.3), C.gold, M.Metal, { CanCollide = false })
	part(m, "Cloth", cf * CFrame.new(0, 1.9, 0), V3(2.4, 0.1, 2.4), C.canvasRed, M.Fabric, { CanCollide = false })
end

function build.helm(m, cf, opts)
	-- the wheel steers, and a little sail on a short mast behind it catches the wind: that's what moves the raft
	part(m, "Mast", cf * CFrame.new(0, 4.6, 1.7), V3(0.45, 9.2, 0.45), C.woodDark, M.Wood, { CanCollide = false })
	part(m, "Yard", cf * CFrame.new(0, 8.4, 1.9), V3(4.6, 0.28, 0.28), C.woodDark, M.Wood, { CanCollide = false })
	part(m, "Boom", cf * CFrame.new(0, 3.6, 1.9), V3(4.2, 0.28, 0.28), C.woodDark, M.Wood, { CanCollide = false })
	-- the canvas, bellied out with the wind (two panels at a slight angle)
	for i, side in { -1, 1 } do
		part(
			m,
			"Canvas" .. i,
			cf * CFrame.new(side * 1.05, 6, 2.15) * CFrame.Angles(0, side * math.rad(-12), 0),
			V3(2.2, 4.6, 0.12),
			colour(opts, "sail"),
			M.Fabric,
			{ CanCollide = false }
		)
	end
	part(
		m,
		"Pennant",
		cf * CFrame.new(0.5, 9.4, 1.7),
		V3(1, 0.4, 0.06),
		colour(opts, "flag"),
		M.Fabric,
		{ CanCollide = false }
	)
	part(m, "Post", cf * CFrame.new(0, 1.4, 0), V3(0.6, 2.8, 0.6), C.woodDark, M.Wood)
	Kit.cyl(m, "Wheel", cf * CFrame.new(0, 3.2, 0.2), 0.3, 3, C.wood, M.Wood, { CanCollide = false })
	for k = 0, 3 do
		part(
			m,
			"Spoke",
			cf * CFrame.new(0, 3.2, 0.2) * CFrame.Angles(0, 0, k * math.pi / 4),
			V3(3.6, 0.25, 0.25),
			C.woodDark,
			M.Wood,
			{ CanCollide = false }
		)
	end
	Kit.disc(
		m,
		"Hub",
		cf.Position + V3(0, 3.2, 0) + cf.LookVector * -0.2,
		0.8,
		0.5,
		C.gold,
		M.Metal,
		{ CanCollide = false }
	)
end

-- Decoration ---------------------------------------------------------------------------------------------------
function build.chair(m, cf, opts)
	part(
		m,
		"Seat",
		cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(math.rad(-12), 0, 0),
		V3(2, 0.25, 2.2),
		colour(opts, "banner"),
		M.Fabric,
		{ CanCollide = false }
	)
	part(
		m,
		"Back",
		cf * CFrame.new(0, 2.2, 0.9) * CFrame.Angles(math.rad(20), 0, 0),
		V3(2, 2.2, 0.25),
		colour(opts, "banner"),
		M.Fabric,
		{ CanCollide = false }
	)
	for _, sx in { -1, 1 } do
		part(
			m,
			"Leg",
			cf * CFrame.new(sx * 0.9, 0.6, 0) * CFrame.Angles(math.rad(25), 0, 0),
			V3(0.2, 1.4, 0.2),
			C.woodDark,
			M.Wood,
			{ CanCollide = false }
		)
		part(
			m,
			"Leg",
			cf * CFrame.new(sx * 0.9, 0.6, 0) * CFrame.Angles(math.rad(-25), 0, 0),
			V3(0.2, 1.4, 0.2),
			C.woodDark,
			M.Wood,
			{ CanCollide = false }
		)
	end
end

function build.table(m, cf)
	bench(m, cf, C.woodLight, C.woodDark)
	part(m, "Mug", cf * CFrame.new(1, 2.1, 0.4), V3(0.5, 0.6, 0.5), C.cream, M.SmoothPlastic, { CanCollide = false })
end

function build.rug(m, cf, opts)
	part(
		m,
		"Rug",
		cf * CFrame.new(0, 0.36, 0),
		V3(T - 1, 0.12, T - 1.6),
		colour(opts, "banner"),
		M.Fabric,
		{ CanCollide = false }
	)
	part(
		m,
		"Border",
		cf * CFrame.new(0, 0.4, 0),
		V3(T - 1.8, 0.1, T - 2.4),
		C.cream,
		M.Fabric,
		{ CanCollide = false, CastShadow = false }
	)
end

function build.plant(m, cf)
	part(m, "Pot", cf * CFrame.new(0, 0.8, 0), V3(1.4, 1.6, 1.4), C.stone, M.Rock)
	part(m, "Trunk", cf * CFrame.new(0, 2.4, 0), V3(0.3, 2, 0.3), C.bark, M.Wood, { CanCollide = false })
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		part(
			m,
			"Frond",
			cf * CFrame.new(math.cos(a) * 0.9, 3.5, math.sin(a) * 0.9) * CFrame.Angles(0, -a, math.rad(-35)),
			V3(2, 0.1, 0.6),
			C.leaf,
			M.Grass,
			{ CanCollide = false, CastShadow = false }
		)
	end
end

function build.banner(m, cf, opts)
	part(m, "Pole", cf * CFrame.new(0, 3, 0), V3(0.3, 6, 0.3), C.woodDark, M.Wood)
	part(m, "Bar", cf * CFrame.new(0, 5.8, 0.9), V3(0.25, 0.25, 2), C.woodDark, M.Wood, { CanCollide = false })
	part(
		m,
		"Cloth",
		cf * CFrame.new(0, 4.2, 0.9),
		V3(0.1, 3, 1.8),
		colour(opts, "banner"),
		M.Fabric,
		{ CanCollide = false }
	)
end

function build.flag(m, cf, opts)
	part(m, "Pole", cf * CFrame.new(0, 4, 0), V3(0.3, 8, 0.3), C.woodDark, M.Wood)
	part(
		m,
		"Flag",
		cf * CFrame.new(1.4, 7.2, 0),
		V3(2.6, 1.6, 0.1),
		colour(opts, "flag"),
		M.Fabric,
		{ CanCollide = false }
	)
	local pattern = opts and opts.colours and opts.colours.pattern
	if pattern and pattern ~= "plain" then
		part(
			m,
			"Mark",
			cf * CFrame.new(1.4, 7.2, -0.07),
			V3(0.9, 0.9, 0.05),
			C.white,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
	Kit.ball(m, "Top", cf.Position + V3(0, 8.2, 0), 0.5, C.gold, M.Metal, { CanCollide = false })
end

function build.coral_lamp(m, cf)
	part(m, "Base", cf * CFrame.new(0, 0.5, 0), V3(1.2, 1, 1.2), C.stone, M.Rock)
	local lamp = Kit.ball(m, "Coral", cf.Position + V3(0, 1.6, 0), 1.4, C.glowcap, M.Neon, { CanCollide = false })
	Kit.light(lamp, "PointLight", { Name = "Glow", Color = C.glowcap, Range = 14, Brightness = 1 })
end

-- One piece: a Model of anchored parts, named after the piece, with attributes the client reads.
function RaftModels.build(key, cf, opts, parent)
	local m = Instance.new("Model")
	m.Name = key
	local fn = build[key]
	if fn then
		fn(m, cf, opts or {})
	else
		part(m, "Crate", cf * CFrame.new(0, 1, 0), V3(2, 2, 2), C.wood, M.WoodPlanks)
	end
	m:SetAttribute("Piece", key)
	-- (where it was built, for what's drawn on it later: a net's catch)
	m:SetAttribute("Origin", cf)
	m.Parent = parent
	return m
end

-- Damage shows: parts darken and a crack appears past half health.
function RaftModels.damage(model, share)
	local crack = model:FindFirstChild("Crack")
	if share < 0.5 then
		if not crack then
			local p = model:FindFirstChildWhichIsA("BasePart")
			if p then
				crack = part(
					model,
					"Crack",
					p.CFrame * CFrame.new(0.6, p.Size.Y / 2 + 0.02, -0.4) * CFrame.Angles(0, 0.6, 0),
					V3(3.5, 0.05, 0.25),
					C.ink,
					M.SmoothPlastic,
					{ CanCollide = false, CastShadow = false }
				)
			end
		end
	elseif crack then
		crack:Destroy()
	end
	model:SetAttribute("Health", share)
end

return RaftModels

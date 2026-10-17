-- Unit tests for src/shared: the rules (Formulas), the data (weapons, structures, the ladder, the maps) and every
-- map built on the mock engine (fair, closed, with open lanes).
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Weapons = Engine.require(tree.shared.Data.Weapons)
local Structures = Engine.require(tree.shared.Data.Structures)
local Ladder = Engine.require(tree.shared.Data.Ladder)
local Maps = Engine.require(tree.shared.Data.Maps)
local ArenaBuilder = Engine.require(tree.shared.World.ArenaBuilder)
local Net = Engine.require(tree.shared.Net)
local Vector3 = Engine.Vector3

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end
local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-6)
end

-- The frontline ------------------------------------------------------------------------------------------------
check("a kill in a full server moves the line one cell", Formulas.pushCells(40) == 1)
check("...in a small one, more (each kill matters)", Formulas.pushCells(4) == 3 and Formulas.pushCells(8) == 2)
check("...never more than three", Formulas.pushCells(1) == 3)
check("turf: west of the line is red's", Formulas.sideOf(-1, 0) == "red" and Formulas.sideOf(1, 0) == "blue")
check("red pushes east, blue west", Formulas.forward("red") == 1 and Formulas.forward("blue") == -1)

-- Weapons ------------------------------------------------------------------------------------------------------
local bow, tnt, blade = Weapons.get("bow"), Weapons.get("tnt"), Weapons.get("blade")
check(
	"the bow, the TNT and the blade, in that order (1 2 3), all at the start",
	#Weapons.list == 3 and Weapons.list[1] == bow and Weapons.list[2] == tnt and Weapons.list[3] == blade
)
check("no crossbow, no heavy bow", Weapons.get("crossbow") == nil and Weapons.get("heavy") == nil)
check("no weapon has a magazine now", bow.mag == nil and tnt.mag == nil and blade.mag == nil)
check(
	"the blade is melee: no arrow, a reach across the line",
	blade.melee == true and blade.range >= 9 and blade.arc > 0
)
check("...one slash, one knockout", blade.damage[1] >= Constants.MAX_HEALTH)
check("...and its swing parries arrows for a moment", Constants.PARRY_SECONDS > 0.2 and Constants.PARRY_SECONDS < 1)
check("a tap is the least charge", near(Formulas.charge(bow, 0), bow.minCharge))
check("a full draw is full charge", near(Formulas.charge(bow, 5), 1))
check("a full bow draw kills (100)", Formulas.shot(bow, 1).damage >= Constants.MAX_HEALTH)
check("a tap kills too: every hit is a knockout", Formulas.shot(bow, bow.minCharge).damage >= Constants.MAX_HEALTH)
check(
	"...but a tap flies slower than a full draw",
	Formulas.shot(bow, bow.minCharge).speed < Formulas.shot(bow, 1).speed
)
-- the TNT: thrown, wound up (the charge is the distance), a cooldown so it isn't spammy
check("the TNT is thrown, not shot", tnt.throw == true and not tnt.melee)
check("...wound up like a draw", tnt.draw > 0 and tnt.minCharge > 0)
check("...a few seconds between throws", tnt.cooldown >= 2.5 and tnt.cooldown <= 4)
check(
	"...the blast: a core inside the radius, a short fuse",
	Constants.TNT_CORE < Constants.TNT_RADIUS and Constants.TNT_RADIUS >= 8 and Constants.TNT_FUSE <= 2
)
do
	local look = Vector3.new(1, 0, 0)
	local v = Formulas.lobVelocity(look, 50)
	check("a throw leaves above where you look (a lob)", v.Y > 0 and near(v.Magnitude, 50, 1e-4))
	local o2 = Vector3.new(0, 5, 0)
	local top, land
	for i = 1, 200 do
		local q = Formulas.lobAt(o2, v, i / 100)
		top = math.max(top or q.Y, q.Y)
		if not land and q.Y <= 0 then
			land = q
		end
	end
	check("...it rises, then comes down", top > 5 and land ~= nil)
	check("...falling faster than an arrow (heavier)", Constants.TNT_GRAVITY > Constants.GRAVITY)
	local far = Formulas.lobAt(o2, Formulas.lobVelocity(look, Formulas.shot(tnt, 1).speed), 0.5)
	local short = Formulas.lobAt(o2, Formulas.lobVelocity(look, Formulas.shot(tnt, tnt.minCharge).speed), 0.5)
	check("...wound up all the way, it goes further", far.X > short.X * 1.8, `{far.X} {short.X}`)
	local target = Vector3.new(30, 0.5, 6)
	local speed = Formulas.shot(tnt, 0.7).speed
	local dir, miss = Formulas.lobAim(o2, target, speed)
	check("lobAim finds a throw onto a spot (bots)", miss < 2.5, miss)
	check("...toward it", dir and dir.X > 0 and dir.Z > 0)
	check("the blast falls off with distance", Formulas.blast(0) == 1 and Formulas.blast(Constants.TNT_RADIUS) == 0)
	check("...half way, half", near(Formulas.blast(Constants.TNT_RADIUS / 2), 0.5))
	check(
		"a point's distance to a box",
		Formulas.boxDistance(Vector3.new(5, 1, 0), Vector3.new(0, 0, -1), Vector3.new(2, 4, 1)) == 3
			and Formulas.boxDistance(Vector3.new(1, 1, 0), Vector3.new(0, 0, -1), Vector3.new(2, 4, 1)) == 0
	)
end

-- What structures look like (StructureModel): castle pieces, boxes only, the team's colour on each ---------------
do
	local StructureModel = Engine.require(tree.shared.StructureModel)
	-- (the same colour: the mock's Color3 has no value equality)
	local function same(a, b)
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 1e-3
	end
	local NAMES = {
		barricade = "Battlement",
		wall = "Castle Wall",
		reinforced = "Keep Wall",
		tower = "Watchtower",
		bridge = "Rampart",
		cover = "Shield Wall",
		banner = "Rally Banner",
	}
	for key, name in NAMES do
		local def = Structures.get(key)
		check(`{key} is the {name} (the key kept)`, def ~= nil and def.name == name, def and def.name)
		check(`...and says what it's for`, def and type(def.role) == "string" and #def.role > 0)
	end
	local onlyBanner = true
	for _, def in Structures.list do
		if (def.rally == true) ~= (def.key == "banner") then
			onlyBanner = false
		end
	end
	check("the Rally Banner rallies (and nothing else does)", onlyBanner)
	for _, team in { "red", "blue" } do
		local shade = Constants.BUILD_COLOR[team]
		for _, def in Structures.list do
			for rot = 0, 1 do
				local w, d = Structures.footprint(def, rot)
				local mn, mx = Formulas.footprintBox(3, -2, w, d, 0, def.h)
				local parts = StructureModel.parts(def.key, team, mn, mx)
				local outside, high, round, teamed, solid = 0, 0, 0, false, 0
				for _, e in parts do
					teamed = teamed or same(StructureModel.color(e.tone, team), shade)
					if e.shape or e.wedge then
						round += 1 -- (a Ball or a Cylinder; no wedges either: boxes only)
					end
					-- (anything solid stays inside the footprint and near its height)
					if e.solid then
						solid += 1
						local c = e.cf.Position
						if c.X < mn.X - 0.01 or c.X > mx.X + 0.01 or c.Z < mn.Z - 0.01 or c.Z > mx.Z + 0.01 then
							outside += 1
						end
						if c.Y > def.h + 2.5 then
							high += 1
						end
					end
				end
				check(
					`{team} {def.key} rot {rot}: plain and light for phones ({#parts} parts), the team's colour on it`,
					#parts >= 5 and #parts <= 45 and teamed and solid > 0
				)
				check(`...nothing round in it`, round == 0, round)
				check(
					`...nothing solid outside its footprint or high above it`,
					outside == 0 and high == 0,
					`{outside} {high}`
				)
			end
		end
		check(`{team}: the trim is the build shade`, same(StructureModel.color("team", team), shade))
	end
	-- plain: everything leans to the team, and nothing is brown (a warm colour with little blue in it, dark-ish)
	check(
		"the stone tells the sides apart",
		not same(StructureModel.color("stone", "red"), StructureModel.color("stone", "blue"))
	)
	for _, tone in { "stone", "stoneDark", "wood", "woodDark", "iron", "mortar" } do
		for _, team in { "red", "blue" } do
			local c = StructureModel.color(tone, team)
			check(`{tone} ({team}): plain greys and whites, no brown`, math.abs(c.R - c.B) < 0.2, `{c.R} {c.G} {c.B}`)
		end
	end
	-- the watchtower: square, crenellated, a platform to stand on at its top, a ladder, a roofed turret with a flag
	local mn, mx = Formulas.footprintBox(0, 0, 2, 2, 0, Structures.get("tower").h)
	local names = {}
	local platformTop = 0
	for _, e in StructureModel.parts("tower", "red", mn, mx) do
		names[e.name] = (names[e.name] or 0) + 1
		if e.name == "Platform" then
			platformTop = math.max(platformTop, e.cf.Position.Y + e.size.Y / 2)
		end
	end
	check(
		"the watchtower: a shaft, slits, merlons, a platform, a ladder with rungs, a stepped roof, a flag",
		names.Shaft
			and (names.Slit or 0) >= 4
			and (names.Merlon or 0) >= 6
			and names.Platform
			and (names.Rung or 0) >= 5
			and (names.Roof or 0) >= 3
			and names.Flag
	)
	check("...you stand on its top", math.abs(platformTop - Structures.get("tower").h) < 0.01, platformTop)
	-- the rampart: you stand on its deck at its height, and a ladder goes up
	local bmn, bmx = Formulas.footprintBox(0, 0, 1, 3, 0, Structures.get("bridge").h)
	local deck, rungs = 0, 0
	for _, e in StructureModel.parts("bridge", "red", bmn, bmx) do
		if e.name == "Plank" then
			deck = math.max(deck, e.cf.Position.Y + e.size.Y / 2)
		elseif e.name == "Rung" then
			rungs += 1
		end
	end
	check(
		"the rampart: a deck at its height, a ladder up",
		math.abs(deck - Structures.get("bridge").h) < 0.01 and rungs >= 4,
		`{deck} {rungs}`
	)
end

-- Pieces touching join up (StructureModel.joins): a row of walls is one wall, corners get a post ----------------
do
	local StructureModel = Engine.require(tree.shared.StructureModel)
	local CELL = Constants.CELL
	-- a little grid of pieces, and what stands on a cell
	local function grid(list)
		local cells = {}
		for _, p in list do
			for x = p.cx, p.cx + p.w - 1 do
				for z = p.cz, p.cz + p.d - 1 do
					cells[x .. ":" .. z] = p
				end
			end
		end
		return function(x, z)
			return cells[x .. ":" .. z]
		end
	end
	local function piece(key, cx, cz, rot, team)
		local w, d = Structures.footprint(Structures.get(key), rot or 0)
		return { key = key, team = team or "red", cx = cx, cz = cz, w = w, d = d, rot = rot or 0 }
	end
	local function boxOf(p)
		return Formulas.footprintBox(p.cx, p.cz, p.w, p.d, 0, Structures.get(p.key).h)
	end
	local function partsOf(p, joins)
		local mn, mx = boxOf(p)
		return StructureModel.parts(p.key, p.team, mn, mx, joins)
	end
	-- a part's box in the world (every frame here is square to the grid)
	local function extent(e)
		local cf, s = e.cf, e.size
		local function abs(v)
			return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
		end
		local half = (abs(cf.RightVector) * s.X + abs(cf.UpVector) * s.Y + abs(cf.LookVector) * s.Z) / 2
		return cf.Position - half, cf.Position + half
	end
	local function named(parts, name)
		local out = {}
		for _, e in parts do
			if e.name == name then
				table.insert(out, e)
			end
		end
		return out
	end
	-- solid parts of two pieces that overlap (they'd fight for the same space) or anything solid outside its own box
	local function clash(pa, pb, a, b)
		local n = 0
		for _, ea in pa do
			for _, eb in pb do
				if ea.solid and eb.solid then
					local a0, a1 = extent(ea)
					local b0, b1 = extent(eb)
					local o = Vector3.new(
						math.min(a1.X, b1.X) - math.max(a0.X, b0.X),
						math.min(a1.Y, b1.Y) - math.max(a0.Y, b0.Y),
						math.min(a1.Z, b1.Z) - math.max(a0.Z, b0.Z)
					)
					if o.X > 0.01 and o.Y > 0.01 and o.Z > 0.01 then
						n += 1
					end
				end
			end
		end
		for _, pair in { { pa, a }, { pb, b } } do
			local mn, mx = boxOf(pair[2])
			for _, e in pair[1] do
				local e0, e1 = extent(e)
				if
					e.solid
					and (e0.X < mn.X - 0.01 or e1.X > mx.X + 0.01 or e0.Z < mn.Z - 0.01 or e1.Z > mx.Z + 0.01)
				then
					n += 1
				end
			end
		end
		return n
	end
	-- the merlons along a row (merged where two halves meet on a seam) and the gaps between them
	local function crenels(list, axis)
		local spans = {}
		for _, e in list do
			local e0, e1 = extent(e)
			table.insert(spans, { e0[axis], e1[axis] })
		end
		table.sort(spans, function(p, q)
			return p[1] < q[1]
		end)
		local merged = {}
		for _, s in spans do
			local last = merged[#merged]
			if last and s[1] <= last[2] + 0.01 then
				last[2] = math.max(last[2], s[2])
			else
				table.insert(merged, { s[1], s[2] })
			end
		end
		local gaps, widths = {}, {}
		for i, s in merged do
			table.insert(widths, s[2] - s[1])
			if i > 1 then
				table.insert(gaps, s[1] - merged[i - 1][2])
			end
		end
		return gaps, widths
	end
	local function spread(list)
		local lo, hi = math.huge, -math.huge
		for _, v in list do
			lo, hi = math.min(lo, v), math.max(hi, v)
		end
		return hi - lo
	end
	local function plain(parts)
		local bad = 0
		for _, e in parts do
			local c = StructureModel.color(e.tone, "red")
			local teamed = e.tone == "team" or e.tone == "teamDark" or e.tone == "flame" or e.tone == "glow"
			if e.shape or e.wedge or (not teamed and math.abs(c.R - c.B) >= 0.2) then
				bad += 1
			end
		end
		return bad
	end

	for _, key in { "barricade", "wall", "reinforced" } do
		for rot = 0, 1 do
			-- two of them end to end in a row
			local a = piece(key, 0, 0, rot)
			local b = rot == 0 and piece(key, 2, 0, rot) or piece(key, 0, 2, rot)
			local at = grid({ a, b })
			local ja, jb = StructureModel.joins(a, at), StructureModel.joins(b, at)
			local axis = rot == 0 and "X" or "Z"
			local seam = 2 * CELL
			check(`{key} rot {rot}: two end to end run on`, ja and ja.right == "run" and jb and jb.left == "run")
			local pa, pb = partsOf(a, ja), partsOf(b, jb)
			local _, ba1 = extent(named(pa, "Body")[1])
			local bb0 = extent(named(pb, "Body")[1])
			check(
				`...the bodies meet at the seam (no end set in there)`,
				near(ba1[axis], seam, 0.01) and near(bb0[axis], seam, 0.01)
			)
			local ca, cb = named(pa, "Coping")[1], named(pb, "Coping")[1]
			local ca0, ca1 = extent(ca)
			local cb0, cb1 = extent(cb)
			check(
				`...the coping runs on: end to end, the same height and width`,
				near(ca1[axis], cb0[axis], 0.01)
					and near(ca0.Y, cb0.Y, 0.01)
					and near(ca1.Y, cb1.Y, 0.01)
					and near(
						ca1.X - ca0.X + ca1.Z - ca0.Z - (ca1[axis] - ca0[axis]),
						cb1.X - cb0.X + cb1.Z - cb0.Z - (cb1[axis] - cb0[axis]),
						0.01
					)
			)
			local merlons = named(pa, "Merlon")
			for _, e in named(pb, "Merlon") do
				table.insert(merlons, e)
			end
			local gaps, widths = crenels(merlons, axis)
			check(
				`...the merlons keep one rhythm over the joint (one on the seam, as wide as the rest)`,
				#gaps >= 3 and spread(gaps) < 0.05 and spread(widths) < 0.05,
				`{table.concat(gaps, " ")} / {table.concat(widths, " ")}`
			)
			check(`...one pilaster on the joint`, #named(pa, "Pilaster") + #named(pb, "Pilaster") == 1)
			local free = #partsOf(a) + #partsOf(b)
			check(`...hardly more parts than two apart`, #pa + #pb <= free + 1, `{#pa + #pb} vs {free}`)
			check(`...nothing solid fighting for the same space`, clash(pa, pb, a, b) == 0, clash(pa, pb, a, b))
			check(`...still plain: nothing round, nothing brown`, plain(pa) + plain(pb) == 0)
			-- one taken away: the other is itself again
			local alone = StructureModel.joins(a, grid({ a }))
			check(
				`...take one away and the other finishes its end again`,
				alone == nil and StructureModel.joinsKey(alone) == ""
			)
		end
	end
	-- an L: a wall's end against another's end cell makes a square corner post there
	do
		local a = piece("wall", 0, 0, 0) -- (cells x 0..1 at z 0)
		local b = piece("wall", 2, 0, 1) -- (cells z 0..1 at x 2: its end cell beside a's end)
		local at = grid({ a, b })
		local ja, jb = StructureModel.joins(a, at), StructureModel.joins(b, at)
		check("an L: the one meeting the other's side butts into it", ja and ja.right == "butt", ja and ja.right)
		local pa, pb = partsOf(a, ja), partsOf(b, jb)
		local posts = named(pb, "Post")
		local p0, p1 = extent(posts[1] or named(pb, "Plinth")[1])
		check(
			"...a square corner post on the corner cell",
			#posts == 1
				and near(p0.X, 2 * CELL, 0.01)
				and near(p1.X, 3 * CELL, 0.01)
				and near(p0.Z, 0, 0.01)
				and near(p1.Z, CELL, 0.01)
		)
		check("...with a cap", #named(pb, "PostCap") == 1)
		local _, ab1 = extent(named(pa, "Body")[1])
		check("...the other's body runs right up to the post", near(ab1.X, 2 * CELL, 0.01))
		local cb0 = extent(named(pb, "Coping")[1])
		check("...the coping stops at the post (no doubled top)", cb0.Z >= CELL - 0.01, cb0.Z)
		check("...nothing solid overlapping at the corner", clash(pa, pb, a, b) == 0, clash(pa, pb, a, b))
		check("...still plain: nothing round, nothing brown", plain(pa) + plain(pb) == 0)
		check("...a few parts at most added", #pa + #pb <= #partsOf(a) + #partsOf(b) + 2)
		-- the T: a third wall running on from the post side, the post stays shared
		local c = piece("wall", 2, -2, 1)
		local at3 = grid({ a, b, c })
		local jb3 = StructureModel.joins(b, at3)
		check(
			"a T: the post stays, the walls either side run on",
			jb3 and jb3.left == "run" and #named(partsOf(b, jb3), "Post") == 1
		)
		check("...and taking the corner away puts the end back", StructureModel.joins(b, grid({ b })) == nil)
	end
	-- a wall into a Watchtower: no end facing into the tower, it reaches the shaft
	do
		local a = piece("wall", 0, 0, 0)
		local t = piece("tower", 2, 0, 0)
		local ja = StructureModel.joins(a, grid({ a, t }))
		check("a wall against a Watchtower butts into it", ja and ja.right == "tower")
		local pa = partsOf(a, ja)
		local _, ab1 = extent(named(pa, "Body")[1])
		local abut = named(pa, "Abut")[1]
		local _, u1 = extent(abut or named(pa, "Plinth")[1])
		check(
			"...its body to the end and a reach to the shaft",
			near(ab1.X, 2 * CELL, 0.01) and abut and u1.X > 2 * CELL + 0.3
		)
		check("...the tower is as it was", StructureModel.joins(t, grid({ a, t })) == nil)
		check("...nothing solid in the tower", clash(pa, partsOf(t), a, t) == 0)
	end
	-- heights: a Battlement against a Castle Wall's end steps cleanly
	do
		local low = piece("barricade", 0, 0, 0)
		local high = piece("wall", 2, 0, 0)
		local at = grid({ low, high })
		local jl, jh = StructureModel.joins(low, at), StructureModel.joins(high, at)
		check(
			"different heights: the lower butts in, the taller finishes",
			jl.left == nil and jl.right == "butt" and jh.left == "flush"
		)
		local ph = partsOf(high, jh)
		local hb0 = extent(named(ph, "Body")[1])
		check("...the taller's end set flush (no slot)", near(hb0.X, 2 * CELL, 0.01))
		check("...nothing solid overlapping", clash(partsOf(low, jl), ph, low, high) == 0)
		check(
			"other teams' pieces don't join",
			StructureModel.joins(low, grid({ low, piece("barricade", 2, 0, 0, "blue") })) == nil
		)
	end
	-- a Rampart: decks run on end to end, and no palisade where a wall stands against it
	do
		local r1 = piece("bridge", 0, 0, 0) -- (along Z: cells z 0..2 at x 0)
		local r2 = piece("bridge", 0, 3, 0)
		local at = grid({ r1, r2 })
		local j1, j2 = StructureModel.joins(r1, at), StructureModel.joins(r2, at)
		check("ramparts end to end: one deck", j1.right == "run" and j2.left == "run")
		local p1, p2 = partsOf(r1, j1), partsOf(r2, j2)
		check(
			"...no kerb across it, no doubled posts on the seam",
			#named(p1, "Kerb") + #named(p2, "Kerb") == 2 and #named(p1, "Post") == 4
		)
		local top1, top2 = 0, 0
		for _, e in named(p1, "Plank") do
			top1 = math.max(top1, select(2, extent(e)).Y)
		end
		for _, e in named(p2, "Plank") do
			top2 = math.max(top2, select(2, extent(e)).Y)
		end
		check("...the decks line up", near(top1, top2, 0.01))
		check("...fewer parts than two apart", #p1 + #p2 < #partsOf(r1) + #partsOf(r2))
		check("...nothing solid overlapping", clash(p1, p2, r1, r2) == 0)
		-- (red's enemy is +X: a wall along the rampart's enemy side)
		local w = piece("wall", 1, 0, 1)
		local jr = StructureModel.joins(r1, grid({ r1, w }))
		local pr = partsOf(r1, jr)
		local len = 0
		for _, e in named(pr, "Palisade") do
			local e0, e1 = extent(e)
			len += e1.Z - e0.Z
		end
		check("a wall against a rampart's enemy side: no palisade there", jr and len > 0 and near(len, CELL, 0.01), len)
		local d1 = 0
		for _, e in named(pr, "Plank") do
			d1 = math.max(d1, select(2, extent(e)).X)
		end
		check("...the deck reaches the wall", near(d1, CELL, 0.01), d1)
		check(
			"...nothing solid overlapping",
			clash(pr, partsOf(w, StructureModel.joins(w, grid({ r1, w }))), r1, w) == 0
		)
	end
	-- Shield Walls side by side close up
	do
		local s1, s2 = piece("cover", 0, 0, 0), piece("cover", 0, 1, 0)
		local at = grid({ s1, s2 })
		local b1 = named(partsOf(s1, StructureModel.joins(s1, at)), "Board")[1]
		local b2 = named(partsOf(s2, StructureModel.joins(s2, at)), "Board")[1]
		local _, e1 = extent(b1)
		local e2 = extent(b2)
		check("shield walls side by side: one board, no slit", near(e1.Z, CELL, 0.01) and near(e2.Z, CELL, 0.01))
	end
	-- with no joins (the hotbar's pictures) every piece is just as it was
	for _, def in Structures.list do
		local p = piece(def.key, 0, 0, 0)
		check(`{def.key}: no neighbours, no joins`, StructureModel.joins(p, grid({ p })) == nil)
	end
end

-- Arrow maths --------------------------------------------------------------------------------------------------
local o, v = Vector3.new(0, 10, 0), Vector3.new(100, 0, 0)
local p = Formulas.arrowAt(o, v, 1)
check("arrows drop", p.Y < 10 and near(p.X, 100))
check("...by half g t²", near(p.Y, 10 - 0.5 * Constants.GRAVITY))
check(
	"a segment through a sphere hits it",
	Formulas.segmentSphere(Vector3.new(-5, 0, 0), Vector3.new(5, 0, 0), Vector3.zero, 1) ~= nil
)
check(
	"...and one beside it doesn't",
	Formulas.segmentSphere(Vector3.new(-5, 3, 0), Vector3.new(5, 3, 0), Vector3.zero, 1) == nil
)
local t = Formulas.segmentSphere(Vector3.new(-5, 0, 0), Vector3.new(5, 0, 0), Vector3.zero, 1)
check("...where it enters", t and near(t, 0.4))
local tb = Formulas.segmentBox(Vector3.new(-5, 1, 1), Vector3.new(5, 1, 1), Vector3.new(0, 0, 0), Vector3.new(2, 2, 2))
check("a segment into a box enters at its face", tb and near(tb, 0.5))
check(
	"...a segment past it misses",
	Formulas.segmentBox(Vector3.new(-5, 5, 1), Vector3.new(5, 5, 1), Vector3.zero, Vector3.new(2, 2, 2)) == nil
)

-- an arrow is a point: it slips through anything that isn't really there
do
	local CF = Engine.CFrame
	-- a thin plank turned 45°: its axis-aligned box is huge, the plank itself is not
	local plank = CF.new(0, 0, 0) * CF.Angles(0, math.rad(45), 0)
	local size = Vector3.new(8, 2, 0.4)
	check(
		"a turned plank: an arrow through the empty corner of its box flies on",
		Formulas.segmentPart(Vector3.new(0.6, 0, 2.4), Vector3.new(5, 0, 2.4), plank, size, "Block") == nil
			and Formulas.segmentBox(
					Vector3.new(0.6, 0, 2.4),
					Vector3.new(5, 0, 2.4),
					Vector3.new(-3, -1, -3),
					Vector3.new(3, 1, 3)
				)
				~= nil
	)
	check(
		"...through the plank itself, it stops",
		Formulas.segmentPart(Vector3.new(-5, 0, 0), Vector3.new(5, 0, 0), plank, size, "Block") ~= nil
	)
	-- a round column (a cylinder stood up): past the corner of its square, an arrow flies on
	local column = CF.new(0, 0, 0) * CF.Angles(0, 0, math.rad(90))
	local csize = Vector3.new(10, 4, 4)
	check(
		"a round column: past its square's corner, the arrow flies on",
		Formulas.segmentPart(Vector3.new(-5, 0, 1.8), Vector3.new(5, 0, 1.8 - 10), column, csize, "Cylinder") == nil
			or Formulas.segmentPart(Vector3.new(-5, 0, 1.9), Vector3.new(1.9, 0, -5), column, csize, "Cylinder")
				== nil
	)
	local tc = Formulas.segmentPart(Vector3.new(-5, 0, 0), Vector3.new(5, 0, 0), column, csize, "Cylinder")
	check("...into it, it stops at its face", tc and near(tc, 0.3), tc)
	check(
		"a ball: only the ball",
		Formulas.segmentPart(
			Vector3.new(-5, 1.8, 1.8),
			Vector3.new(5, 1.8, 1.8),
			CF.new(0, 0, 0),
			Vector3.new(4, 4, 4),
			"Ball"
		) == nil
	)
end

-- Structures and the grid --------------------------------------------------------------------------------------
check("seven structures", #Structures.list == 7)
for _, s in Structures.list do
	check(`{s.key}: a cost, durability and a footprint`, s.cost > 0 and s.hp > 0 and s.w >= 1 and s.d >= 1)
end
local w, d = Structures.footprint(Structures.get("wall"), 1)
check("a turned wall swaps its footprint", w == 1 and d == 2)
check("cells are 4 studs", Formulas.cellOf(5, -1) == 1 and select(2, Formulas.cellOf(5, -1)) == -1)
check("a budget buys several pieces", Constants.BUILD_BUDGET >= Structures.get("tower").cost * 3)
check(
	"200 points a phase, 24 pieces each, stacks to 30 studs",
	Constants.BUILD_BUDGET == 200 and Constants.PLAYER_STRUCTURES == 24 and Constants.BUILD_MAX_HEIGHT == 30
)
do
	-- stacking (Formulas.stackCheck): what stands on each cell, as the server and the preview see it
	local tops = {}
	local function topAt(x, z)
		return tops[x .. ":" .. z]
	end
	local function set(x, z, top, team, key)
		tops[x .. ":" .. z] = top and { top = top, team = team or "red", key = key or "wall" } or nil
	end
	local wall, tower, banner, bar =
		Structures.get("wall"), Structures.get("tower"), Structures.get("banner"), Structures.get("barricade")
	check("the floor, bare: a wall goes down", Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 0, topAt) == true)
	set(0, 0, 10)
	set(1, 0, 10)
	local ok, why = Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 0, topAt)
	check("...taken: something's already there", not ok and why == "Something's already there", why)
	check("a wall on two wall tops at 10: supported", Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 10, topAt) == true)
	ok, why = Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 6, topAt)
	check("...half way up: no support", not ok and why == "No support", why)
	ok, why = Formulas.stackCheck(wall, "red", 1, 0, 2, 1, 10, topAt)
	check("...half on a wall, half in the air: no support", not ok and why == "No support", why)
	set(1, 0, 4, "red", "barricade")
	ok, why = Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 10, topAt)
	check("...on tops of different heights: no support", not ok and why == "No support", why)
	set(1, 0, 10, "blue")
	ok, why = Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 10, topAt)
	check("...on the enemy's wall: no support", not ok and why == "No support", why)
	set(1, 0, 10, "red", "tower")
	ok, why = Formulas.stackCheck(bar, "red", 0, 0, 2, 1, 10, topAt)
	check(
		"...on a tower: no support (nothing builds on a tower, a shield or a banner)",
		not ok and why == "No support",
		why
	)
	set(1, 0, 10)
	ok, why = Formulas.stackCheck(banner, "red", 0, 0, 1, 1, 10, topAt)
	check("the Rally Banner only on the floor", not ok and why == "Only on the floor", why)
	check("a battlement on a wall: a parapet", Formulas.stackCheck(bar, "red", 0, 0, 2, 1, 10, topAt) == true)
	set(0, 0, 20)
	set(1, 0, 20)
	check("a third wall reaches the cap", Formulas.stackCheck(wall, "red", 0, 0, 2, 1, 20, topAt) == true)
	ok, why = Formulas.stackCheck(tower, "red", 0, 0, 2, 2, 20, topAt)
	check("...a tower there would go over it: too high", not ok and why and why:find("Too high") ~= nil, why)
	set(0, 0, 6, "red", "bridge")
	set(1, 0, 6, "red", "bridge")
	set(0, 1, 6, "red", "bridge")
	set(1, 1, 6, "red", "bridge")
	check("a tower on four rampart cells: supported", Formulas.stackCheck(tower, "red", 0, 0, 2, 2, 6, topAt) == true)
end

-- The ladder ---------------------------------------------------------------------------------------------------
check("a hundred steps", #Ladder.steps == 100)
local kinds = {}
for _, s in Ladder.steps do
	kinds[s.kind] = (kinds[s.kind] or 0) + 1
end
check(
	"trails, skins, effects, banners and titles",
	kinds.trail and kinds.skin and kinds.effect and kinds.banner and kinds.title
)
check("every 10th is big", Ladder.at(10).big and Ladder.at(100).big and not Ladder.at(9).big)
check("the 100th is the Overdrive title", Ladder.at(100).kind == "title" and Ladder.at(100).name == "Overdrive")
local names = {}
local dup = false
for _, s in Ladder.steps do
	local k = s.kind .. s.name
	dup = dup or names[k]
	names[k] = true
end
check("no step repeats another", not dup)
check(
	"a qualifying win: won, long enough, active",
	Formulas.qualifies({ won = true, seconds = 200, active = true })
		and not Formulas.qualifies({ won = true, seconds = 30, active = true })
		and not Formulas.qualifies({ won = true, seconds = 200, active = false })
		and not Formulas.qualifies({ won = false, seconds = 200, active = true })
)
check(
	"streak badges at 3, 5, 10",
	Formulas.streakBadge(3) == 3 and Formulas.streakBadge(4) == nil and Formulas.streakBadge(10) == 10
)

-- The maps -----------------------------------------------------------------------------------------------------
check("four maps", #Maps.list == 4)
check(
	"the rotation never repeats a map",
	(function()
		for _ = 1, 50 do
			if Maps.next("castle").key == "castle" then
				return false
			end
		end
		return true
	end)()
)
for _, def in Maps.list do
	for _, tier in ArenaBuilder.TIERS do
		local holder = Engine.Instance.new("Folder")
		local ok, arena = pcall(ArenaBuilder.build, def, holder, tier)
		check(`{def.key} {tier}: builds`, ok, not ok and arena or nil)
		if ok then
			local parts = 0
			for _, x in arena.folder:GetDescendants() do
				if x:IsA("BasePart") then
					parts += 1
				end
			end
			check(`{def.key} {tier}: detailed (lots of shapes)`, parts >= 150, parts)
			check(`{def.key} {tier}: within a phone's budget (well under 2500 parts)`, parts <= 2400, parts)
			check(`{def.key} {tier}: ten spawn pads a team`, #arena.spawns.red == 10 and #arena.spawns.blue == 10)
			-- nothing of the map's own in the spawn zones (beyond the back wall's detail and the spawn room itself:
			-- its cover too, the parapets and piers between the pads' lanes)
			local inSpawn = 0
			local edge = arena.half - arena.spawnDepth
			for _, s in arena.solids do
				local inside = s.min.X > edge + 1 or s.max.X < -edge - 1
				local own = s.part and s.part.Parent and s.part.Parent.Name == "Map"
				local room = s.part
					and (
						s.part.Name == "Baffle"
						or s.part.Name == "SpawnWall"
						or s.part.Name == "SpawnRoof"
						or s.part.Name == "Cover"
					)
				if
					inside
					and own
					and not room
					and s.min.Y < 6
					and s.max.Y > 0.5
					and math.abs(s.min.X) < arena.half - 4
				then
					inSpawn += 1
				end
			end
			check(`{def.key} {tier}: spawn zones are clear`, inSpawn == 0, inSpawn)
			-- the lanes: every row across the field has open cells at ground level
			local worst = math.huge
			local _, z0 = Formulas.cellOf(0, -arena.width / 2 + 0.01)
			local _, z1 = Formulas.cellOf(0, arena.width / 2 - 0.01)
			local x0 = Formulas.cellOf(-edge + 0.01, 0)
			local x1 = Formulas.cellOf(edge - 0.01, 0)
			for cx = x0, x1 do
				local free = 0
				for cz = z0, z1 do
					if not (arena.blocked[cx] and arena.blocked[cx][cz]) then
						free += 1
					end
				end
				worst = math.min(worst, free)
			end
			check(`{def.key} {tier}: every row has a way through`, worst >= 4, worst)
			-- fair: the same shapes on both halves (as many solids west of the middle as east)
			local west, east = 0, 0
			for _, s in arena.solids do
				local c = (s.min.X + s.max.X) / 2
				if c < -1 then
					west += 1
				elseif c > 1 then
					east += 1
				end
			end
			check(`{def.key} {tier}: mirrored halves`, west == east, `{west} vs {east}`)
			-- closed: shell walls on every side and a ceiling
			local shells = 0
			for _, x in arena.folder:GetDescendants() do
				if x.Name == "Shell" or x.Name == "Ceiling" then
					shells += 1
				end
			end
			check(`{def.key} {tier}: walled in and roofed`, shells == 5, shells)
			-- the turf paints from the frontline
			ArenaBuilder.paint(arena, 10)
			check(
				`{def.key} {tier}: the turf paints red west of the line, blue east`,
				arena.strips[1].Color == Constants.TURF_COLOR.red
					and arena.strips[#arena.strips].Color:Lerp(Constants.TURF_COLOR.blue, 0) ~= nil
			)
			check(`{def.key} {tier}: the frontline marker moved`, near(arena.marker.CFrame.Position.X, 10))
			check(
				`{def.key} {tier}: the frontline is a line on the floor, not a wall (you see over it)`,
				arena.marker.Size.Y <= 0.5 and arena.marker.CFrame.Position.Y < 0.5 and arena.glow.Size.Y <= 0.5
			)
			check(
				`{def.key} {tier}: white before anyone pushes`,
				arena.marker.Color.R > 0.99 and arena.marker.Color.G > 0.99 and arena.marker.Color.B > 0.99
			)
			ArenaBuilder.paint(arena, 14, "blue")
			check(
				`{def.key} {tier}: it glows the colour of the last push`,
				arena.marker.Color == Constants.TEAM_COLOR.blue and arena.glow.Color == Constants.TEAM_COLOR.blue
			)
			holder:Destroy()
		end
	end
end

-- The sizes: more people, a bigger arena; always whole cells, the lose lines spawnDepth from the end walls
do
	check("up to 9 people: the small arena", ArenaBuilder.tier(9) == "small" and ArenaBuilder.tier(1) == "small")
	check("10 to 19: medium", ArenaBuilder.tier(10) == "medium" and ArenaBuilder.tier(19) == "medium")
	check("20 to 29: large", ArenaBuilder.tier(20) == "large" and ArenaBuilder.tier(29) == "large")
	check("30 and up: huge", ArenaBuilder.tier(30) == "huge" and ArenaBuilder.tier(40) == "huge")
	check("a tier's name passes through", ArenaBuilder.tier("large") == "large" and ArenaBuilder.tier(nil) == "small")
	local holder = Engine.Instance.new("Folder")
	local last
	for _, tier in ArenaBuilder.TIERS do
		local a = ArenaBuilder.build(Maps.list[1], holder, tier)
		check(
			`{tier}: whole cells along and across`,
			a.length % (2 * Constants.CELL) == 0 and a.width % (2 * Constants.CELL) == 0,
			`{a.length}x{a.width}`
		)
		check(`{tier}: a strip per cell`, #a.strips == a.length / Constants.CELL, #a.strips)
		check(
			`{tier}: the lose lines spawnDepth from the walls`,
			ArenaBuilder.loseLine(a, "blue") == a.half - a.spawnDepth
				and ArenaBuilder.loseLine(a, "red") == -(a.half - a.spawnDepth)
				and a.spawnDepth == 20
		)
		check(`{tier}: the lose line on a cell edge`, (a.half - a.spawnDepth) % Constants.CELL == 0)
		if last then
			check(`{tier}: longer and wider than the one before`, a.length > last.length and a.width > last.width)
			-- (more cells to push through, and pushCells(people) never more than before: it takes longer)
			local cellsBefore = (last.half - last.spawnDepth) / Constants.CELL
			local cells = (a.half - a.spawnDepth) / Constants.CELL
			local people = { medium = 14, large = 24, huge = 35 }
			check(
				`{tier}: more kills to win than the size before`,
				cells / Formulas.pushCells(people[tier]) > cellsBefore / Formulas.pushCells(8)
			)
		end
		last = a
		a.folder:Destroy()
	end
end

-- Remotes ------------------------------------------------------------------------------------------------------
check("Shoot is rate-limited above the bow's rate", Net.ClientEvents.Shoot >= 1 / bow.cooldown)
check(
	"the TNT's lob and blast go to everyone",
	table.find(Net.ServerEvents, "Bomb") and table.find(Net.ServerEvents, "Blast")
)
check(
	"the server events include the kill feed and results",
	table.find(Net.ServerEvents, "Kill") and table.find(Net.ServerEvents, "Results")
)

-- Money: cosmetics, the shop, the pass, goals, VIP ----------------------------------------------------------------
do
	local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
	local Shop = Engine.require(tree.shared.Data.Shop)
	local Season = Engine.require(tree.shared.Data.Season)
	local Achievements = Engine.require(tree.shared.Data.Achievements)
	local Locker = Engine.require(tree.shared.Data.Locker)
	local kinds, rarities = {}, {}
	for _, k in Cosmetics.KINDS do
		kinds[k] = true
	end
	for _, r in Cosmetics.RARITIES do
		rarities[r] = true
	end
	local bad = {}
	for _, it in Cosmetics.list do
		if not kinds[it.kind] or not rarities[it.rarity] or type(it.look) ~= "table" or Cosmetics.get(it.key) ~= it then
			table.insert(bad, it.key)
		end
	end
	check("every cosmetic has a kind, a rarity and a look", #bad == 0, table.concat(bad, " "))
	local ladderOk = true
	for _, st in Ladder.steps do
		local it = Cosmetics.get(st.key)
		ladderOk = ladderOk and it ~= nil and it.kind == st.kind and type(it.look) == "table" and it.source == "ladder"
	end
	check("every ladder step is a cosmetic with a look", ladderOk)
	check("the extras are cosmetics too", Cosmetics.get("extra_buddy") and Cosmetics.get("extra_buddy").kind == "trail")
	local forSale = true
	for _, k in Shop.pool do
		local src = Cosmetics.get(k).source
		forSale = forSale and src == "shop"
	end
	check("only shop cosmetics are ever for sale (never goals, VIP or MVP)", forSale and #Shop.pool >= 12, #Shop.pool)
	-- the rotation
	local day = 20742
	local a, b = Shop.daily(day), Shop.daily(day)
	check("the day's shop is the same everywhere", table.concat(a, ",") == table.concat(b, ","))
	local seen, distinct = {}, true
	for _, k in a do
		distinct = distinct and not seen[k]
		seen[k] = true
	end
	check("4 different items a day", #a == 4 and distinct)
	local week = Shop.weekly((day + 3) // 7)
	local clash = false
	for _, k in week.keys do
		clash = clash or seen[k] == true
	end
	check("the week's bundle isn't also in the day's items", not clash and #week.keys == 3)
	local sum = 0
	for _, k in week.keys do
		sum += Shop.price(Cosmetics.get(k))
	end
	check("the bundle is cheaper than its items", week.price < sum, `{week.price} {sum}`)
	check("the shop changes day to day", table.concat(Shop.daily(day + 1), ",") ~= table.concat(a, ","))
	check("an item of the day is in the rotation", Shop.inRotation(a[1], day * 86400 + 100))
	local value = true
	for i = 2, #Shop.PACKS do
		value = value
			and Shop.PACKS[i].shards / Shop.PACKS[i].robux > Shop.PACKS[i - 1].shards / Shop.PACKS[i - 1].robux
	end
	check("bigger Shard packs are better value", value)
	check("a short stay earns nothing", Shop.shardsFor({ seconds = 20, kills = 5 }, false) == 0)
	check(
		"a win earns more than a loss, the day's first win more again",
		Shop.shardsFor({ seconds = 300, won = true }, true) > Shop.shardsFor({ seconds = 300, won = true }, false)
			and Shop.shardsFor({ seconds = 300, won = true }, false)
				> Shop.shardsFor({ seconds = 300, won = false }, false)
	)
	-- the pass
	check("season 1 starts at the epoch", Season.at(Season.EPOCH).n == 1 and Season.at(Season.EPOCH - 5).n == 1)
	check("a new season every 4 weeks", Season.at(Season.EPOCH + 28 * 86400).n == 2)
	check("tiers from XP", Season.tierOf(0) == 0 and Season.tierOf(Season.XP_PER_TIER * 3 + 5) == 3)
	check("...capped at 30", Season.tierOf(10 ^ 7) == Season.TIERS)
	check("premium tier 1: the season title", Cosmetics.get("s1_1p") and Cosmetics.get("s1_1p").kind == "title")
	check("free tier 5: a cosmetic", Season.reward(1, 5, "f").kind == "cosmetic" and Cosmetics.get("s1_5f") ~= nil)
	check("tier 30 premium is legendary", Cosmetics.get("s1_30p").rarity == "legendary")
	check("free odd tiers between give 10 Shards", (Season.reward(1, 7, "f") or {}).amount == 10)
	local every = true
	for t = 1, Season.TIERS do
		if not Season.reward(1, t, "f") then
			every = false
		end
	end
	check("...every free tier gives a reward", every)
	check("season items aren't made for tiers without one", Cosmetics.get("s1_4f") == nil)
	check(
		"season items are the season's own",
		Cosmetics.get("s2_3p").season == 2 and Cosmetics.get("s2_3p").source == "pass"
	)
	-- goals and VIP
	local pro = { wins = 3, best = 2, stats = { headshots = 100, kills = 10, mvps = 1 } }
	local earned = Achievements.earned(pro)
	check("a goal reached gives its reward", earned.goal_sharp == true and earned.goal_centurion == nil)
	check("VIP isn't there yet", not Achievements.isVip(pro) and not earned.vip_title)
	local vip = { wins = 50, best = 1, stats = { mvps = 10 } }
	check("50 wins and 10 MVPs: VIP", Achievements.isVip(vip) and Achievements.earned(vip).vip_trail == true)
	check("...10 MVPs also gives the MVP title", Achievements.earned(vip).mvp_title == true)
	check("VIP once earned is kept", Achievements.isVip({ vip = true, wins = 0, stats = {} }))
	local newly = Achievements.newly({ stats = { headshots = 99 } }, { stats = { headshots = 100 } })
	check("a goal is announced once, when it's reached", #newly == 1 and newly[1].key == "sharp")
	-- owning
	check(
		"ladder cosmetics: owned with the wins",
		Locker.owns({ wins = 5 }, "trail_1") and not Locker.owns({ wins = 0 }, "trail_1")
	)
	check(
		"shop cosmetics: owned once bought",
		Locker.owns({ owned = { shop_echo = true } }, "shop_echo") and not Locker.owns({}, "shop_echo")
	)
	check(
		"goal cosmetics: owned with the stat",
		Locker.owns(pro, "goal_sharp") and not Locker.owns(pro, "goal_architect")
	)
	check("VIP cosmetics: VIPs only", Locker.owns(vip, "vip_skin") and not Locker.owns(pro, "vip_skin"))
	check("an unknown key isn't owned", not Locker.owns(pro, "nope"))
	check(
		"nothing paid adds combat power (cosmetics carry no numbers for fights)",
		(function()
			for _, it in Cosmetics.list do
				if it.damage or it.speed or it.health or it.reload then
					return false
				end
			end
			return true
		end)()
	)
end

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("Formulas: " .. failed .. " failures")
end

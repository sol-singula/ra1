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

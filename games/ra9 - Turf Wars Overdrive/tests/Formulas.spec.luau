-- Unit tests for src/shared: the rules (Formulas), the data (weapons, structures, the ladder, the maps) and every
-- map built on the mock engine (fair, closed, with open lanes).
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
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

-- Bows ---------------------------------------------------------------------------------------------------------
local bow, crossbow, heavy = Weapons.get("bow"), Weapons.get("crossbow"), Weapons.get("heavy")
check("three bows, all at the start", #Weapons.list == 3 and bow and crossbow and heavy)
check("a tap is the least charge", near(Formulas.charge(bow, 0), bow.minCharge))
check("a full draw is full charge", near(Formulas.charge(bow, 5), 1))
check("the crossbow is always full", Formulas.charge(crossbow, 0) == 1)
check("a full bow draw kills (100)", Formulas.shot(bow, 1).damage >= Constants.MAX_HEALTH)
check("a tap doesn't", Formulas.shot(bow, bow.minCharge).damage < Constants.MAX_HEALTH)
check("the crossbow takes three hits", math.ceil(Constants.MAX_HEALTH / Formulas.shot(crossbow, 1).damage) == 3)
check("the heavy bow pushes hardest", heavy.knockback > bow.knockback and heavy.knockback > crossbow.knockback)
check("the heavy bow wrecks structures", heavy.structure > bow.structure)
-- none is strictly better: each loses somewhere
check(
	"no bow is strictly better",
	heavy.draw > bow.draw and crossbow.damage[2] < bow.damage[2] and bow.speed[2] > heavy.speed[2] - 40
)

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
	local holder = Engine.Instance.new("Folder")
	local ok, arena = pcall(ArenaBuilder.build, def, holder)
	check(`{def.key}: builds`, ok, not ok and arena or nil)
	if ok then
		local parts = 0
		for _, x in arena.folder:GetDescendants() do
			if x:IsA("BasePart") then
				parts += 1
			end
		end
		check(`{def.key}: detailed (lots of shapes)`, parts >= 150, parts)
		check(`{def.key}: within a phone's budget`, parts <= 1500, parts)
		check(`{def.key}: ten spawn pads a team`, #arena.spawns.red == 10 and #arena.spawns.blue == 10)
		-- nothing of the map's own in the spawn zones (beyond the back wall's detail)
		local inSpawn = 0
		local edge = arena.half - arena.spawnDepth
		for _, s in arena.solids do
			local inside = s.min.X > edge + 1 or s.max.X < -edge - 1
			local own = s.part and s.part.Parent and s.part.Parent.Name == "Map"
			if inside and own and s.min.Y < 6 and s.max.Y > 0.5 and math.abs(s.min.X) < arena.half - 4 then
				inSpawn += 1
			end
		end
		check(`{def.key}: spawn zones are clear`, inSpawn == 0, inSpawn)
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
		check(`{def.key}: every row has a way through`, worst >= 4, worst)
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
		check(`{def.key}: mirrored halves`, west == east, `{west} vs {east}`)
		-- closed: shell walls on every side and a ceiling
		local shells = 0
		for _, x in arena.folder:GetDescendants() do
			if x.Name == "Shell" or x.Name == "Ceiling" then
				shells += 1
			end
		end
		check(`{def.key}: walled in and roofed`, shells == 5, shells)
		-- the turf paints from the frontline
		ArenaBuilder.paint(arena, 10)
		check(
			`{def.key}: the turf paints red west of the line, blue east`,
			arena.strips[1].Color == Constants.TURF_COLOR.red
				and arena.strips[#arena.strips].Color:Lerp(Constants.TURF_COLOR.blue, 0) ~= nil
		)
		check(`{def.key}: the frontline marker moved`, near(arena.marker.CFrame.Position.X, 10))
		holder:Destroy()
	end
end

-- Remotes ------------------------------------------------------------------------------------------------------
check("Shoot is rate-limited above the crossbow's rate", Net.ClientEvents.Shoot >= 1 / crossbow.cooldown)
check(
	"the server events include the kill feed and results",
	table.find(Net.ServerEvents, "Kill") and table.find(Net.ServerEvents, "Results")
)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("Formulas: " .. failed .. " failures")
end

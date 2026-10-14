-- Unit tests for src/shared/Formulas.lua and the data tables (the pure game math), plus the map's helpers.
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Jobs = Engine.require(tree.shared.Data.Jobs)
local Looks = Engine.require(tree.shared.Data.Looks)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local Tasks = Engine.require(tree.shared.Data.Tasks)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local Net = Engine.require(tree.shared.Net)

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end
local function near(a, b)
	return math.abs(a - b) < 1e-6
end

-- The match ----------------------------------------------------------------------------------------------------
check("build time: 6 minutes for a few players", Formulas.buildSeconds(1) == 360 and Formulas.buildSeconds(4) == 360)
check("7 minutes from 5 players", Formulas.buildSeconds(5) == 420 and Formulas.buildSeconds(8) == 420)
check("8 minutes for a full server", Formulas.buildSeconds(9) == 480 and Formulas.buildSeconds(24) == 480)
check("the plague turns nobody in a tiny server", Formulas.plagueCount(1) == 0 and Formulas.plagueCount(3) == 0)
check(
	"about 1 in 4 otherwise",
	Formulas.plagueCount(4) == 1
		and Formulas.plagueCount(8) == 2
		and Formulas.plagueCount(12) == 3
		and Formulas.plagueCount(24) == 6
)

-- Shrines ------------------------------------------------------------------------------------------------------
check("no monsters near: it heals", Formulas.shrineRate(3, 0) == Constants.SHRINE_REGEN)
check("as many dwarves as monsters: it holds", Formulas.shrineRate(3, 3) == 0 and Formulas.shrineRate(5, 3) == 0)
check("three extra monsters drain 2.4% a second", near(Formulas.shrineRate(2, 5), -2.4))
check("drain is capped", near(Formulas.shrineRate(0, 20), -Constants.SHRINE_DRAIN_MAX))
check("two wards and a castle slow it down", near(Formulas.shrineRate(0, 20, 2, "castle"), -4 * 0.4))
check("only two wards count", near(Formulas.shrineRate(0, 20, 5, "castle"), Formulas.shrineRate(0, 20, 2, "castle")))
check("a town drains slower than a camp", Formulas.shrineRate(0, 5, 0, "town") > Formulas.shrineRate(0, 5, 0, "camp"))
check(
	"castle stages",
	Formulas.castleStage(0) == "camp"
		and Formulas.castleStage(35) == "camp"
		and Formulas.castleStage(36) == "town"
		and Formulas.castleStage(99) == "town"
		and Formulas.castleStage(100) == "castle"
)

-- The horde ----------------------------------------------------------------------------------------------------
check("a few monsters even with no dwarves", Formulas.hordeTarget(0, 0, 0) == Constants.HORDE_MIN)
check("more dwarves, more monsters", Formulas.hordeTarget(0, 6, 0) == 9)
check("more time, more monsters", Formulas.hordeTarget(10, 6, 0) == 17)
check("monster players take NPC places", Formulas.hordeTarget(10, 6, 5) == 11)
check("never more than NPC_MAX", Formulas.hordeTarget(60, 24, 0) == Constants.NPC_MAX)
check("never fewer than HORDE_MIN", Formulas.hordeTarget(0, 1, 12) == Constants.HORDE_MIN)
check(
	"monster levels",
	Formulas.monsterLevel(0) == 1
		and Formulas.monsterLevel(39) == 1
		and Formulas.monsterLevel(40) == 2
		and Formulas.monsterLevel(100) == 3
		and Formulas.monsterLevel(299) == 4
		and Formulas.monsterLevel(300) == 5
		and Formulas.monsterLevel(99999) == 5
)
check("next level XP", Formulas.monsterNextXp(1) == 40 and Formulas.monsterNextXp(5) == nil)
check("level 1 at the start: no bonus", Formulas.monsterMult(1, 0) == 1)
check("each level adds 8%", near(Formulas.monsterMult(3, 0), 1.16))
check("each fight minute adds 4%", near(Formulas.monsterMult(1, 5), 1.2))
check(
	"the time bonus stops at 50%",
	near(Formulas.monsterMult(1, 100), 1.5) and near(Formulas.monsterMult(5, 100), 1.82)
)
local grunt, brute, builder = Jobs.byKey.grunt, Jobs.byKey.brute, Jobs.byKey.builder
check("grunts are open to everyone", Formulas.jobUnlocked(grunt, 1, 0))
check("brutes need monster level 2", not Formulas.jobUnlocked(brute, 1, 0) and Formulas.jobUnlocked(brute, 2, 0))
check("everything opens after 4 minutes of fighting", Formulas.jobUnlocked(brute, 1, Constants.MONSTER_UNLOCK_AFTER))
check(
	"dwarf jobs aren't monster jobs",
	not Formulas.jobUnlocked(builder, 5, 9999) and not Formulas.jobUnlocked(nil, 5, 0)
)

-- Building -----------------------------------------------------------------------------------------------------
check("builders hit twice as hard", Formulas.hammerPower("builder") == 2 and Formulas.hammerPower("miner") == 1)
check(
	"a healer's aura adds a quarter",
	near(Formulas.hammerPower("miner", true), 1.25) and near(Formulas.hammerPower("builder", true), 2.5)
)
check("deposits per hit", Formulas.depositPerHit("builder") == 3 and Formulas.depositPerHit("fighter") == 2)
check("work waits for materials", Formulas.workCap({ stone = 4 }, { stone = 2 }, 10) == 5)
check(
	"work cap: all brought",
	Formulas.workCap({ stone = 4 }, { stone = 4 }, 10) == 10 and Formulas.workCap({}, {}, 7) == 7
)
local miss = Formulas.missing({ stone = 4, wood = 2 }, { stone = 4, wood = 1 })
check("what's missing", miss.wood == 1 and miss.stone == nil)
check(
	"can afford",
	Formulas.canAfford({ stone = 5 }, { stone = 4 })
		and not Formulas.canAfford({ stone = 3 }, { stone = 4 })
		and not Formulas.canAfford({}, { gold = 1 })
)
check("progress: the slower of materials and hammering", Formulas.progress({ stone = 4 }, { stone = 4 }, 10, 5) == 0.5)
check("progress: materials hold it back", Formulas.progress({ stone = 4 }, { stone = 2 }, 10, 10) == 0.5)
check("progress: a free piece with no work is done", Formulas.progress({}, {}, 0, 0) == 1)
check("total", Formulas.total({ stone = 2, wood = 3 }) == 5)

-- Fighting -----------------------------------------------------------------------------------------------------
check(
	"armor: 12% less damage per tier",
	near(Formulas.armorMult(0), 1) and near(Formulas.armorMult(3), 0.64) and near(Formulas.armorMult(9), 0.64)
)
check("weapons: 12% more per tier", near(Formulas.weaponMult(2), 1.24) and near(Formulas.weaponMult(-1), 1))
check("the pack: 5% per grunt nearby", near(Formulas.packMult(grunt, 2), 1.1))
check("the pack is capped", near(Formulas.packMult(grunt, 50), 1 + grunt.packMax))
check("only grunts have a pack", Formulas.packMult(brute, 10) == 1)
local fwd = Vector3.new(0, 0, -1)
check("in front: in the arc", Formulas.inArc(fwd, Vector3.new(0.2, 0, -1), 90))
check("to the side: not in a 90° arc", not Formulas.inArc(fwd, Vector3.new(1, 0, 0), 90))
check("behind: not in the arc", not Formulas.inArc(fwd, Vector3.new(0, 0, 1), 120))
check("a wide arc reaches the side", Formulas.inArc(fwd, Vector3.new(1, 0, -0.1), 200))
check("standing on it counts", Formulas.inArc(fwd, Vector3.new(0, 0, 0), 30))

-- Progress -----------------------------------------------------------------------------------------------------
local l, into, need = Formulas.levelFromXp(0, 120, 40)
check("level 1 at 0 XP", l == 1 and into == 0 and need == 120)
l, into, need = Formulas.levelFromXp(279, 120, 40)
check("level 2 needs 120, level 3 160 more", l == 2 and into == 159 and need == 160)
check("level 3 at 280", (Formulas.levelFromXp(280, 120, 40)) == 3)
check("account levels use the constants", (Formulas.accountLevel(Constants.LEVEL_XP)) == 2)
check(
	"job levels",
	(Formulas.jobLevel(Constants.JOB_LEVEL_XP - 1)) == 1 and (Formulas.jobLevel(Constants.JOB_LEVEL_XP)) == 2
)
local coins, xp =
	Formulas.rewards({ team = "dwarf", won = true, heldSeconds = 600, beaten = 10, built = 12, lastDwarf = true })
check("a dwarf's win", coins == 162 and xp == 243, `{coins} / {xp}`)
coins, xp = Formulas.rewards({ team = "monster", won = true, dwarvesBeaten = 3, broken = 7, shrines = 2 })
check("a monster's win", coins == 100 and xp == 150, `{coins} / {xp}`)
coins = Formulas.rewards({ team = "dwarf" })
check("everyone gets something", coins == Constants.REWARDS.base)
coins, xp = Formulas.rewards({ team = "dwarf", beaten = 1000 })
check(
	"one match pays at most the cap",
	coins == Constants.REWARDS.cap and xp == math.floor(Constants.REWARDS.cap * 1.5)
)
check(
	"daily gifts: a 7-day streak, then it repeats",
	Formulas.dailyGift(1) == 30
		and Formulas.dailyGift(7) == 150
		and Formulas.dailyGift(8) == 30
		and Formulas.dailyGift(0) == 30
)
check(
	"clock",
	Formulas.clock(245) == "4:05"
		and Formulas.clock(0) == "0:00"
		and Formulas.clock(59.6) == "1:00"
		and Formulas.clock(-5) == "0:00"
)
check("long clock", Formulas.clock(720) == "12:00")

-- Daily tasks --------------------------------------------------------------------------------------------------
local a, b = Tasks.pickDaily(12345, 20000), Tasks.pickDaily(12345, 20000)
check("same player, same day: same tasks", a[1] == b[1] and a[2] == b[2] and a[3] == b[3])
check("three different tasks", #a == 3 and a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3])
local changed = false
for d = 20001, 20010 do
	local c = Tasks.pickDaily(12345, d)
	if c[1] ~= a[1] or c[2] ~= a[2] or c[3] ~= a[3] then
		changed = true
	end
end
check("new tasks on other days", changed)
check("every task is known", Tasks.byKey[a[1]] and Tasks.byKey[a[2]] and Tasks.byKey[a[3]])
local w = Tasks.pickWeekly(12345, 2800)
check("a weekly task", Tasks.byKey[w] and Tasks.byKey[w].weekly == true)
check(
	"weeks start on Monday",
	Tasks.week(4 * 86400) == Tasks.week(10 * 86400) and Tasks.week(11 * 86400) == Tasks.week(4 * 86400) + 1
)
local statOk = true
for _, t in Tasks.daily do
	if not t.stat or not t.goal or t.goal <= 0 or not t.coins then
		statOk = false
	end
end
check("every daily has a stat, a goal and coins", statOk)

-- Data tables --------------------------------------------------------------------------------------------------
check("five jobs a side", #Jobs.dwarf == 5 and #Jobs.monster == 5)
local jobsOk = true
for _, j in Jobs.dwarf do
	if j.team ~= "dwarf" or not j.main or not j.special or not j.trait or not j.special.cooldown or not j.icon then
		jobsOk = false
	end
end
for _, j in Jobs.monster do
	if j.team ~= "monster" or not j.main or not j.special or not j.trait or not j.special.cooldown or not j.icon then
		jobsOk = false
	end
end
check("every job has a main move, a special and a trait", jobsOk)
check(
	"default jobs",
	Jobs.byKey[Jobs.DEFAULT_DWARF].team == "dwarf" and Jobs.byKey[Jobs.DEFAULT_MONSTER].team == "monster"
)
local piecesOk = true
for _, p in Pieces.list do
	if not p.need or not p.work or not p.hp or not p.size or not p.icon or not p.name then
		piecesOk = false
	end
end
check("every piece has a cost, work, health, size and icon", piecesOk and #Pieces.list >= 16)
local gw, gd = Pieces.cells(Pieces.byKey.gate, 0)
local rw, rd = Pieces.cells(Pieces.byKey.gate, 1)
check("cells turn", gw == 2 and gd == 1 and rw == 1 and rd == 2)
check("cost text", Pieces.costText({ stone = 6, wood = 2 }) == "6 🪨 · 2 🪵")
check("upgrades cost something", Pieces.byKey.stoneWall.upgrade and next(Pieces.byKey.stoneWall.upgrade.need) ~= nil)
local looksOk = true
for _, s in Looks.slots do
	local d = Looks.default[s.key]
	if not d or Looks.byKey[d].price ~= 0 or #(Looks.bySlot[s.key] or {}) < 3 then
		looksOk = false
	end
end
check("every look slot has a free default and choices", looksOk)
local pricesOk = true
for _, item in Looks.items do
	if type(item.price) ~= "number" or item.price < 0 or not Looks.slots[1] then
		pricesOk = false
	end
end
check("prices are coins", pricesOk)
local titleOk = true
for _, t in Looks.titles do
	if t.key ~= "rookie" and (not t.stat or not t.goal) then
		titleOk = false
	end
end
check("titles are earned from stats", titleOk)

-- The map ------------------------------------------------------------------------------------------------------
local s1 = MapLayout.shrines[1].pos
check("shrine 1 sits on the hill", MapLayout.groundY(s1.X, s1.Z) == MapLayout.HILL.height)
check("the canyon floor is flat", MapLayout.groundY(MapLayout.shrines[2].pos.X, 0) == 0)
check(
	"build zones",
	MapLayout.buildZoneAt(s1.X + 30, s1.Z) == 1 and MapLayout.buildZoneAt(MapLayout.shrines[2].pos.X + 10, 0) == 2
)
check("no building in the forest", MapLayout.buildZoneAt(MapLayout.FOREST_SPAWN.X, 0) == nil)
local ci, cj = MapLayout.cellOf(-242, 1)
local cx, cz = MapLayout.cellCenter(ci, cj)
check("cells", ci == -61 and cj == 0 and cx == -242 and cz == 2)
check("zones by x", MapLayout.zoneOf(-200) == 1 and MapLayout.zoneOf(100) == 2 and MapLayout.zoneOf(400) == 3)
check("the valley is walkable", MapLayout.walkable(-300, 0))
check("the canyon walls aren't", not MapLayout.walkable(100, MapLayout.CANYON.halfWidth + 5))
check("the rock spine isn't", not MapLayout.walkable(40, 0))
check("the cave is", MapLayout.walkable(MapLayout.shrines[3].pos.X, 0))
local spawn = MapLayout.dwarfSpawn(1, 3)
check("dwarves spawn by their shrine", (Vector3.new(spawn.X, 0, spawn.Z) - Vector3.new(s1.X, 0, s1.Z)).Magnitude < 40)
check(
	"monsters spawn in the forest, then at the fallen shrine",
	(MapLayout.monsterSpawnCenter(0) - MapLayout.FOREST_SPAWN).Magnitude < 1
		and (MapLayout.monsterSpawnCenter(1) - s1).Magnitude < 40
)
local startOk = true
for _, b in MapLayout.starter do
	local def = Pieces.byKey[b.key]
	local w2, d2 = Pieces.cells(def, b.rot)
	local x, z = (b.i + w2 / 2) * MapLayout.CELL, (b.j + d2 / 2) * MapLayout.CELL
	if MapLayout.buildZoneAt(x, z) ~= 1 then
		startOk = false
	end
end
check("the starter castle is in shrine 1's zone", startOk)
local nodesOk = true
for _, n in MapLayout.nodes do
	if not MapLayout.NODE_AMOUNT[n.kind] or not n.id then
		nodesOk = false
	end
end
check("every rock, tree and vein has an id and an amount", nodesOk and #MapLayout.nodes > 20)

-- The network --------------------------------------------------------------------------------------------------
local ratesOk = true
for name, rate in Net.ClientEvents do
	if type(rate) ~= "number" or rate <= 0 then
		ratesOk = false
		print("bad rate", name)
	end
end
check("every client event has a rate limit", ratesOk)
Net.init()
local folder = Engine.game:GetService("ReplicatedStorage"):FindFirstChild("Net")
check(
	"the horde goes over an unreliable event",
	folder and folder.Horde.ClassName == "UnreliableRemoteEvent" and folder.Match.ClassName == "RemoteEvent"
)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("formula tests failed")
end

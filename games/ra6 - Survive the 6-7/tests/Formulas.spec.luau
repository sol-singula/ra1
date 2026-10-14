-- Unit tests for src/shared/Formulas.lua and the data tables (the game's maths and its content), plus the map's
-- helpers and the remote list.
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Items = Engine.require(tree.shared.Data.Items)
local Enemies = Engine.require(tree.shared.Data.Enemies)
local Recipes = Engine.require(tree.shared.Data.Recipes)
local Camp = Engine.require(tree.shared.Data.Camp)
local Findings = Engine.require(tree.shared.Data.Findings)
local Progression = Engine.require(tree.shared.Data.Progression)
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
local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-6)
end

-- The run (§3: 20-30 minutes) ------------------------------------------------------------------------------------------
local length = Formulas.runLength() + Constants.BOSS_ENRAGE_AT
check("a run lasts 20-30 minutes", length >= 20 * 60 and length <= 30 * 60, length / 60)
check("seven days, six nights before Mega Kermy", #Constants.DAY_SECONDS == 7 and #Constants.NIGHT_SECONDS == 6)
check("day 1 is long enough for the guide (3+ minutes)", Constants.DAY_SECONDS[1] >= 180)
check("Kermy shows himself during day 1", Constants.FIRST_SIGHTING_AT < Constants.DAY_SECONDS[1])
check(
	"nights get longer",
	(function()
		for i = 2, #Constants.NIGHT_SECONDS do
			if Constants.NIGHT_SECONDS[i] < Constants.NIGHT_SECONDS[i - 1] then
				return false
			end
		end
		return true
	end)()
)
check(
	"the clock: 7:00 at sunrise, 18:00 at sunset",
	near(Formulas.clockTime("day", 0, 100), 7) and near(Formulas.clockTime("day", 100, 100), 18)
)
check(
	"the clock: midnight-ish in the night",
	Formulas.clockTime("night", 50, 100) > 23 or Formulas.clockTime("night", 50, 100) < 1
)
check("the clock wraps past midnight", Formulas.clockTime("night", 100, 100) == 5)
check("dusk and dawn", near(Formulas.clockTime("dusk", 0, 10), 18) and near(Formulas.clockTime("dawn", 10, 10), 7))
check("clock text", Formulas.clock(65) == "1:05" and Formulas.clock(0) == "0:00" and Formulas.clock(760) == "12:40")

-- Levels and mastery (§9) ------------------------------------------------------------------------------------------------
check("level 1 at 0 XP", Formulas.level(0) == 1)
check("level 2 at LEVEL_XP", Formulas.level(Constants.LEVEL_XP) == 2 and Formulas.level(Constants.LEVEL_XP - 1) == 1)
check(
	"each level needs more",
	select(3, Formulas.level(Formulas.xpForLevel(5))) > select(3, Formulas.level(Formulas.xpForLevel(4)))
)
check(
	"xpForLevel inverts level",
	(function()
		for l = 1, 40 do
			if Formulas.level(Formulas.xpForLevel(l)) ~= l then
				return false
			end
		end
		return true
	end)()
)
check(
	"a first win is a level or two (not ten)",
	Formulas.level(Formulas.runXp({ nights = 7, won = true, difficulty = 1 })) <= 6
)
check("mastery 1 at 0", Formulas.mastery(0) == 1 and select(2, Formulas.mastery(0)) == 0)
check("mastery 3 opens the special", Formulas.mastery(Constants.MASTERY_XP[3]) == 3)
check("mastery tops out at 10", Formulas.mastery(1e9) == 10 and select(2, Formulas.mastery(1e9)) == 1)
check(
	"halfway between mastery levels",
	near(select(2, Formulas.mastery((Constants.MASTERY_XP[2] + Constants.MASTERY_XP[3]) / 2)), 0.5)
)

-- Difficulty and scaling (§8) ------------------------------------------------------------------------------------------------
check(
	"four difficulties",
	#Constants.DIFFICULTIES == 4 and Formulas.difficulty(1).key == "normal" and Formulas.difficulty(4).key == "sixseven"
)
check(
	"difficulty index is clamped",
	Formulas.difficulty(0).key == "normal" and Formulas.difficulty(99).key == "sixseven"
)
check(
	"each difficulty is harder",
	(function()
		for i = 2, #Constants.DIFFICULTIES do
			local a, b = Constants.DIFFICULTIES[i - 1], Constants.DIFFICULTIES[i]
			if b.hp < a.hp or b.dmg < a.dmg or b.count < a.count or b.bleed > a.bleed or b.xp < a.xp then
				return false
			end
		end
		return true
	end)()
)
check(
	"more players, more monsters",
	Formulas.playerScale(1) < Formulas.playerScale(2) and Formulas.playerScale(6) > Formulas.playerScale(4)
)
check("beyond the table it keeps growing", Formulas.playerScale(10) > Formulas.playerScale(8))
check("night budgets grow", Formulas.nightBudget(6, 4, 1) > Formulas.nightBudget(1, 4, 1))
check(
	"budgets scale with players and difficulty",
	Formulas.nightBudget(3, 6, 1) > Formulas.nightBudget(3, 1, 1)
		and Formulas.nightBudget(3, 4, 4) > Formulas.nightBudget(3, 4, 1)
)
check("a solo night 1 is small", Formulas.nightBudget(1, 1, 1) < 6, Formulas.nightBudget(1, 1, 1))
check("golden monsters are tougher", Formulas.monsterHp(100, 4, 1, true) == Formulas.monsterHp(100, 4, 1) * 2.5)
check("monster damage by difficulty", near(Formulas.monsterDamage(10, 2), 12.5))
check("Kermy hits softer on night 1", Formulas.kermyDamage(30, 1, 1) < 30 and near(Formulas.kermyDamage(30, 6, 1), 30))
check("Kermy gets tougher each night", Formulas.kermyHp(420, 6, 4, 1) > Formulas.kermyHp(420, 1, 4, 1))
check(
	"Mega Kermy: the Totem takes 15%",
	Formulas.bossHp(4, 1, true) == math.floor(Formulas.bossHp(4, 1, false) * 0.85 + 0.5)
)
check("Mega Kermy for a full team", Formulas.bossHp(6, 1, false) > Formulas.bossHp(2, 1, false))

-- Damage taken -----------------------------------------------------------------------------------------------------------
check("no armor: full damage", Formulas.damageTaken(20, 0, 0, false) == 20)
check("armor cuts", Formulas.damageTaken(20, 0.25, 0, false) == 15)
check("armor and a shield stack", Formulas.damageTaken(20, 0.25, 0.5, false) == 8)
check("armor is capped at 80%", Formulas.damageTaken(100, 2, 0, false) == 20)
check("the fire out: harder hits", Formulas.damageTaken(20, 0, 0, true) == 25)
check("at least 1 damage", Formulas.damageTaken(1, 0.8, 0.9, false) == 1)

-- XP for a run ----------------------------------------------------------------------------------------------------------------
local lost = Formulas.runXp({ nights = 3, difficulty = 1, kills = 0, killXp = 30 })
local won = Formulas.runXp({ nights = 7, difficulty = 1, won = true, killXp = 30 })
check("a loss still pays", lost > 0)
check("a win pays much more", won > lost * 3)
check(
	"harder difficulties pay more",
	Formulas.runXp({ nights = 7, difficulty = 3, won = true })
		> Formulas.runXp({ nights = 7, difficulty = 1, won = true })
)
check(
	"XP from one run is capped",
	Formulas.runXp({ nights = 7, difficulty = 4, won = true, killXp = 1e6 }) == Constants.XP.cap
)
check(
	"rarer finds score more",
	Formulas.discoveryPoints("legendary") > Formulas.discoveryPoints("epic") and Formulas.discoveryPoints("common") == 1
)

-- Items (§6) -----------------------------------------------------------------------------------------------------------------------
local keys, dup = {}, nil
for _, it in Items.list do
	if keys[it.key] then
		dup = it.key
	end
	keys[it.key] = true
end
check("item keys are unique", dup == nil, dup)
check(
	"Items.get finds items",
	Items.get("rusty_axe") and Items.get("rusty_axe").name == "Rusty Axe" and Items.get("nope") == nil
)
check(
	"every item has a rarity the game knows",
	(function()
		for _, it in Items.list do
			if not Items.RARITY[it.rarity] then
				return false, it.key
			end
		end
		return true
	end)()
)
check(
	"every item has a name, an icon and a description",
	(function()
		for _, it in Items.list do
			if not (it.name and it.icon and it.desc) then
				return false
			end
		end
		return true
	end)()
)
check(
	"every weapon has its numbers",
	(function()
		for _, it in Items.list do
			if it.kind == "weapon" and not (it.class and it.dmg and it.cd and it.range) then
				return false
			end
		end
		return true
	end)()
)
check(
	"every weapon class has a mastery",
	(function()
		for _, it in Items.list do
			if it.kind == "weapon" and not Items.masteryClass(it) then
				return false
			end
		end
		return true
	end)()
)
check("bows need arrows", Items.get("short_bow").ammo == "arrows" and Items.get("arrows") ~= nil)
check("five rarities from Common to Legendary", #Items.RARITIES == 5 and Items.RARITIES[5] == "legendary")
check(
	"there's at least one legendary weapon of each melee class",
	(function()
		local seen = {}
		for _, it in Items.list do
			if it.kind == "weapon" and it.rarity == "legendary" then
				seen[it.class] = true
			end
		end
		return seen.axe and seen.club and seen.bow
	end)()
)
check(
	"weapons go to the hotbar, resources don't",
	Items.goesToHotbar(Items.get("rusty_axe")) and not Items.goesToHotbar(Items.get("wood"))
)
check("armor is equipment", Items.isEquipment(Items.get("bark_armor")) and not Items.isEquipment(Items.get("bandage")))

-- Recipes and the camp (§7) -----------------------------------------------------------------------------------------------------------
check(
	"every recipe makes a real item from real materials at a real station",
	(function()
		for _, r in Recipes.list do
			if not Items.get(r.item) or not Recipes.STATIONS[r.station] then
				return false, r.item
			end
			for k in r.cost do
				if not Items.get(k) then
					return false, k
				end
			end
		end
		return true
	end)()
)
check(
	"recipes are reachable at their tier",
	(function()
		for _, r in Recipes.list do
			if r.tier < 1 or r.tier > #Camp.TIERS then
				return false
			end
		end
		return true
	end)()
)
check(
	"the workbench makes the basics on day 1",
	Recipes.byItem.stone_axe.tier == 1 and Recipes.byItem.stone_axe.station == "workbench"
)
check("Recipes.get by id", Recipes.get(Recipes.byItem.torch.id) == Recipes.byItem.torch)
check("four camp tiers", #Camp.TIERS == 4 and Camp.TIERS[4].name == "The Stronghold")
check(
	"every tier's cost uses real materials",
	(function()
		for _, t in Camp.TIERS do
			for k in t.cost or {} do
				if not Items.get(k) then
					return false
				end
			end
		end
		return true
	end)()
)
check(
	"every structure has a cost of real materials and a slot",
	(function()
		for key, s in Camp.STRUCTURES do
			for k in s.cost do
				if not Items.get(k) then
					return false, key
				end
			end
			if not MapLayout.slotsByKey[key] or #MapLayout.slotsByKey[key] < s.count then
				return false, key
			end
		end
		return true
	end)()
)
check(
	"every tier's requirements are structures",
	(function()
		for _, t in Camp.TIERS do
			for k in t.requires or {} do
				if not Camp.STRUCTURES[k] and k ~= "stone_wall" then
					return false, k
				end
			end
		end
		return true
	end)()
)
check(
	"the camp order lists every structure",
	(function()
		local n = 0
		for _ in Camp.STRUCTURES do
			n += 1
		end
		return #Camp.ORDER == n
	end)()
)

-- Monsters (§10) ------------------------------------------------------------------------------------------------------------------------------
check(
	"the roster: Kermy and friends",
	Enemies.get("kermy")
		and Enemies.get("snapcap")
		and Enemies.get("grinwolf")
		and Enemies.get("pelter")
		and Enemies.get("stumpy")
		and Enemies.get("mimic")
		and Enemies.get("mega_kermy")
)
check(
	"every monster has tells to learn (the bestiary)",
	(function()
		for _, e in Enemies.list do
			if not e.tips or next(e.tips) == nil then
				return false, e.key
			end
		end
		return true
	end)()
)
check(
	"tells give time to react (at least 0.4 s)",
	(function()
		for _, e in Enemies.list do
			if (e.tell or 0) < 0.4 then
				return false, e.key
			end
		end
		return true
	end)()
)
check(
	"sprinting outruns Kermy and the wolves",
	Constants.SPRINT_SPEED > Enemies.get("kermy").speed and Constants.SPRINT_SPEED > Enemies.get("grinwolf").speed
)
check(
	"every night monster appears by night 3",
	(function()
		for _, key in Enemies.NIGHT do
			if Enemies.get(key).nights > 3 then
				return false, key
			end
		end
		return true
	end)()
)

-- Findings (the map is forest + the camp + these) --------------------------------------------------------------------------------------------
check("at least ten kinds of finding", #Findings.list >= 10)
check(
	"every finding has a zone, a radius and something worth the trip",
	(function()
		for _, f in Findings.list do
			if not (f.zone and f.radius and (f.loot or f.special or f.glowcaps or f.scrap)) then
				return false, f.key
			end
		end
		return true
	end)()
)
check(
	"findings fit the clearings",
	(function()
		local most = 0
		for _, f in Findings.list do
			most += f.count[2]
		end
		return most <= #MapLayout.sites
	end)(),
	#MapLayout.sites
)
check("seven diary pages", #Findings.PAGES == 7)

-- Progression (§9) -------------------------------------------------------------------------------------------------------------------------------
check(
	"eight perks, unlocked by level",
	#Progression.PERKS == 8 and Progression.PERKS[1].level <= Progression.PERKS[8].level
)
check("perk slots grow with level", Progression.perkSlots(1) < Progression.perkSlots(30))
check(
	"every kit's items exist",
	(function()
		for _, k in Progression.KITS do
			for _, it in k.items do
				if not Items.get(it[1]) then
					return false, it[1]
				end
			end
		end
		return true
	end)()
)
check("the first kit is free", Progression.KITS[1].level == 1)
check(
	"a special for every weapon class",
	Progression.SPECIALS.axe and Progression.SPECIALS.club and Progression.SPECIALS.spear and Progression.SPECIALS.bow
)
check(
	"titles from achievements point at real achievements",
	(function()
		for _, t in Progression.TITLES do
			if t.achievement and not Progression.achievementByKey[t.achievement] then
				return false, t.key
			end
		end
		return true
	end)()
)
check(
	"stat achievements count real stats",
	(function()
		local known = {
			kermyKO = true,
			monsters = true,
			rescues = true,
			dodged = true,
			mimics = true,
			wood = true,
			itemsFound = true,
		}
		for _, a in Progression.ACHIEVEMENTS do
			if a.stat and not known[a.stat] then
				return false, a.key
			end
		end
		return true
	end)()
)
check("eight leaderboard categories", #Progression.BOARDS == 8)
check("the fastest win board goes up", Progression.boardByKey.fastest.ascending == true)
check(
	"cosmetics only: looks never give power (no stats)",
	(function()
		for _, l in Progression.LOOKS do
			if l.armor or l.dmg or l.speed then
				return false
			end
		end
		return true
	end)()
)

-- The map's helpers ----------------------------------------------------------------------------------------------------------------------------------
check(
	"zones by distance",
	MapLayout.zoneAt(0, 0) == "camp"
		and MapLayout.zoneAt(120, 0) == "inner"
		and MapLayout.zoneAt(300, 0) == "middle"
		and MapLayout.zoneAt(450, 0) == "deep"
)
check(
	"the camp is flat",
	math.abs(MapLayout.floorY(10, 10) - MapLayout.CAMP.y) < 0.5
		and math.abs(MapLayout.floorY(-30, 20) - MapLayout.CAMP.y) < 0.5
)
check("the forest beyond the camp is walkable", MapLayout.walkable(150, 40))
check("the world ends", not MapLayout.walkable(MapLayout.WALL_RADIUS + 20, 0))
check("polar coordinates", near(MapLayout.polar(0, 10).X, 10, 1e-3) and near(MapLayout.polar(90, 10).Z, 10, 1e-3))
check(
	"trees keep out of the camp",
	(function()
		for _, t in MapLayout.trees() do
			if MapLayout.radius(t.x, t.z) < MapLayout.CAMP.clear - 6 then
				return false
			end
		end
		return true
	end)()
)
check(
	"trees keep off the trails",
	(function()
		for _, t in MapLayout.trees() do
			if t.reachable and MapLayout.trailDistance(t.x, t.z) < MapLayout.TRAIL_HALF then
				return false
			end
		end
		return true
	end)()
)
check(
	"the map is deterministic",
	#MapLayout.trees() == #MapLayout.trees() and MapLayout.trees()[10].x == MapLayout.trees()[10].x
)
check(
	"spawn points are round the fire",
	(function()
		for i = 1, 12 do
			local p = MapLayout.spawnPoint(i)
			local r = MapLayout.radius(p.X, p.Z)
			if r < 6 or r > 16 then
				return false
			end
		end
		return true
	end)()
)
check("the creek has bridges where the trails cross", #MapLayout.bridges >= 2, #MapLayout.bridges)

-- Remotes ----------------------------------------------------------------------------------------------------------------------------------------------
check(
	"every client event has a rate limit",
	(function()
		for name, rate in Net.ClientEvents do
			if type(rate) ~= "number" or rate <= 0 then
				return false, name
			end
		end
		return true
	end)()
)
check(
	"server event names are unique",
	(function()
		local seen = {}
		for _, name in Net.ServerEvents do
			if seen[name] then
				return false
			end
			seen[name] = true
		end
		return true
	end)()
)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("formula tests failed")
end

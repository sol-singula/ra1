-- Unit tests for the game math (no engine needed beyond the mock's globals).
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Planets = Engine.require(tree.shared.Data.Planets)
local Blasters = Engine.require(tree.shared.Data.Blasters)

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

-- planets get harder, in order
for i = 2, #Planets.list do
	check(`planet {i} is harder than {i - 1}`, Planets.list[i].bugHealth > Planets.list[i - 1].bugHealth * 5)
	check(`planet {i} pays more`, Planets.list[i].bugCoins > Planets.list[i - 1].bugCoins)
end
-- a planet's Common takes about 6 shots per bug, on every planet
for _, p in Planets.list do
	local rec = {
		rarity = "Common",
		planet = p.key,
		roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
		lv = 0,
	}
	local shots = Formulas.bugHealth(p, 1) / Formulas.blasterDamage(rec)
	check(`{p.name} Common: about 6 shots per bug`, shots >= 5.5 and shots <= 6.5, shots)
end
-- health scales with the crowd
check("1 player = base health", Formulas.bugHealth(Planets.list[1], 1) == 30)
check("2 players = +60%", Formulas.bugHealth(Planets.list[1], 2) == 48)
check("boss = 45 bugs", Formulas.bossHealth(Planets.list[1], 1) == 30 * 45)
-- rarity multiplies damage; rolls multiply damage; power ups add 4% each
local plain = {
	rarity = "Common",
	planet = "DUST",
	roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
	lv = 0,
}
local god =
	{ rarity = "Common", planet = "DUST", roll = { dmg = "god", spd = "plain", luck = "plain", gem = "plain" }, lv = 0 }
local legend = {
	rarity = "Legend",
	planet = "DUST",
	roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
	lv = 0,
}
check("GOD damage roll = 3x", Formulas.blasterDamage(god) == Formulas.blasterDamage(plain) * 3)
check("Legend = 9x Common", Formulas.blasterDamage(legend) == Formulas.blasterDamage(plain) * 9)
check(
	"Power Up 25 = 2x",
	math.abs(
		Formulas.blasterDamage({ rarity = "Common", planet = "DUST", roll = plain.roll, lv = 25 })
			- Formulas.blasterDamage(plain) * 2
	) < 0.2
)
check(
	"shiny speed shoots faster",
	Formulas.blasterCooldown({ rarity = "Common", planet = "DUST", roll = { spd = "shiny" } })
		< Constants.BLAST_COOLDOWN
)
check(
	"names",
	Formulas.blasterName(legend) == "Dust Nova Cannon"
		and Formulas.blasterName({ rarity = "Epic", planet = "ICE" }) == "Frost Cannon"
)
check(
	"stars",
	Formulas.rollStars({ roll = { dmg = "god", spd = "shiny", luck = "plain", gem = "shiny" } }) == "🌟✨✨"
)
check(
	"power up cost grows",
	Formulas.powerUpCost({ rarity = "Common", planet = "DUST", lv = 10 })
		> Formulas.powerUpCost({ rarity = "Common", planet = "DUST", lv = 0 })
)
check(
	"power up stops at the top",
	Formulas.powerUpCost({ rarity = "Common", planet = "DUST", lv = Constants.POWER_UP_LEVELS }) == nil
)
check(
	"sell value scales by planet",
	Formulas.sellValue({ rarity = "Rare", planet = "ICE" }) > Formulas.sellValue({ rarity = "Rare", planet = "DUST" })
)

-- odds tables add to 100 and pickOdds follows them
for _, tier in Constants.FORGE_TIERS do
	local sum = 0
	for _, row in Constants.FORGE_ODDS[tier.key] do
		sum += row[2]
	end
	check(`{tier.name} odds add to 100`, math.abs(sum - 100) < 1e-6, sum)
end
local sum = 0
for _, row in Constants.ROLL_ODDS do
	sum += row[2]
end
check("roll odds add to 100", math.abs(sum - 100) < 1e-6)
check("pickOdds: 0 is the first row", Formulas.pickOdds(Constants.FORGE_ODDS.small, 0) == "Common")
check("pickOdds: 0.999 is the last row", Formulas.pickOdds(Constants.FORGE_ODDS.small, 0.999) == "Legend")
check("pickOdds: 0.8 is Rare in a small forge", Formulas.pickOdds(Constants.FORGE_ODDS.small, 0.8) == "Rare")
-- a big sample lands near the odds
local rng = Engine.globals.Random.new(1)
local counts = {}
local N = 20000
for _ = 1, N do
	local r = Formulas.rollBlaster(rng, "small", "DUST", 1)
	counts[r.rarity] = (counts[r.rarity] or 0) + 1
end
check("sample: ~70% Common", math.abs(counts.Common / N - 0.70) < 0.02, counts.Common / N)
check("sample: ~25% Rare", math.abs(counts.Rare / N - 0.25) < 0.02, counts.Rare / N)
check("sample: Legend is rare", (counts.Legend or 0) / N < 0.015)
-- luck shifts toward the rare end
local lucky, plainN = 0, 0
for _ = 1, N do
	if Formulas.rollBlaster(rng, "small", "DUST", 1.6).rarity ~= "Common" then
		lucky += 1
	end
	if Formulas.rollBlaster(rng, "small", "DUST", 1).rarity ~= "Common" then
		plainN += 1
	end
end
check("luck gives more non-Commons", lucky > plainN * 1.15, lucky / plainN)
check(
	"mega forge never rolls Common",
	(function()
		for _ = 1, 2000 do
			if Formulas.rollBlaster(rng, "mega", "DUST", 1).rarity == "Common" then
				return false
			end
		end
		return true
	end)()
)
check(
	"rolled blasters have all four stats",
	(function()
		local r = Formulas.rollBlaster(rng, "small", "DUST", 1)
		for _, stat in Constants.ROLL_STATS do
			if not Constants.ROLL_MULT[r.roll[stat]] then
				return false
			end
		end
		return true
	end)()
)
check("odds lines", Formulas.oddsLines("small")[4] == "Legend: 0.5%")

-- Finish Now price falls as the timer runs down
local steps = { 9, 19, 29, 49, 79, 99, 149 }
check("full timer = top price", Formulas.finishNowPrice(100, 100, steps) == 149)
check("half timer = middle price", Formulas.finishNowPrice(50, 100, steps) == 79)
check("almost done = cheapest", Formulas.finishNowPrice(1, 100, steps) == 9)

-- loot
local ore, coins = Formulas.bugLoot(Planets.list[1], plain)
check("bug loot", ore == 1 and coins == 5)
local oreL = Formulas.bugLoot(Planets.list[1], { roll = { luck = "god" } })
check("GOD luck = 3x ore", oreL == 3)
check("every rarity has a colour and a noun", #Blasters.Rarities == 6 and Blasters.byRarity.Ultra.noun == "Omni Ray")

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("formula tests failed")
end

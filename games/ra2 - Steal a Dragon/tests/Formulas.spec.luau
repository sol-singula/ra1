-- Unit tests for src/shared/Formulas.lua and Format.lua (the pure game math).
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Format = Engine.require(tree.shared.Format)
local Constants = Engine.require(tree.shared.Constants)
local Dragons = Engine.require(tree.shared.Data.Dragons)
local Goals = Engine.require(tree.shared.Data.Goals)
local Shop = Engine.require(tree.shared.Data.Shop)

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

-- Levels and size
local function rec(t)
	t.id = t.id or "PUFF"
	t.born = t.born or 0
	return t
end
check("level 1 at birth", Formulas.level(rec({ born = 1000 }), 1000) == 1)
check("baby at birth", Formulas.stage(rec({ born = 1000 }), 1000) == 1)
check("kid at 10 min", Formulas.level(rec({}), 600) == 8 and Formulas.stage(rec({}), 600) == 2)
check("big at 1 h", Formulas.level(rec({}), 3600) == 18 and Formulas.stage(rec({}), 3600) == 3)
check("giant at 8 h", Formulas.level(rec({}), 8 * 3600) == 50 and Formulas.stage(rec({}), 8 * 3600) == 4)
check("levels slow down", Formulas.level(rec({}), 24 * 3600) - Formulas.level(rec({}), 23 * 3600) <= 2)
check("bought levels add up", Formulas.level(rec({ lv = 5 }), 0) == 6)
check("level cap", Formulas.level(rec({ lv = 500 }), 0) == Constants.MAX_LEVEL)
check("size stays Giant past level 49", Formulas.stage(rec({ lv = 90 }), 0) == 4)
check("level multiplier", Formulas.levelMult(1) == 1 and math.abs(Formulas.levelMult(49) - 8.2) < 1e-9)
check("level up costs a minute of income", Formulas.levelUpCost(rec({}), 0) == 60)
check("level up gets pricier", Formulas.levelUpCost(rec({ lv = 1 }), 0) == 67)
check("special makes levels pricier", Formulas.levelUpCost(rec({ id = "BLAZE", sp = "GOLD" }), 0) == 7200)
check("no level up at max", Formulas.levelUpCost(rec({ lv = 500 }), 0) == nil)

-- Income and prices
check("puff baby = 1/s", Formulas.dragonIncome({ id = "PUFF", born = 0 }, 0) == 1)
check("level 50 x8.35", math.abs(Formulas.dragonIncome({ id = "PUFF", born = 0 }, 8 * 3600) - 8.35) < 1e-9)
check("gold special x3", Formulas.dragonIncome({ id = "BLAZE", sp = "GOLD", born = 0 }, 0) == 120)
check("road price with special", Formulas.roadPrice("FROSTY", "FIRE") == 700)
check(
	"sell value is half, grows with level",
	Formulas.sellValue({ id = "PUFF", born = 0 }, 0) == 12 and Formulas.sellValue({ id = "PUFF", born = 0 }, 3600) == 44
)

-- Player multiplier
check("no passes", Formulas.playerMult({}, 0) == 1)
check("2x and VIP stack to 3x", Formulas.playerMult({ DOUBLE = true, VIP = true }, 0) == 3)
check("friends +10% each, max 3", math.abs(Formulas.playerMult({}, 5) - 1.3) < 1e-9)

-- Speed
check("base speed", Formulas.walkSpeed(1, nil, 0, {}) == 18)
check("speed level 3", Formulas.walkSpeed(3, nil, 0, {}) == 21)
local slow = Formulas.walkSpeed(1, { id = "GOLDIE", born = 0 }, 0, {})
check("legend carry slows to 70%", math.abs(slow - 12.6) < 1e-9, slow)
check("fast feet helps", Formulas.walkSpeed(1, { id = "GOLDIE", born = 0 }, 0, { FAST = true }) > slow)
check("speed price grows", Formulas.speedPrice(1) == 150 and Formulas.speedPrice(2) == 360)
check("no price at max", Formulas.speedPrice(Constants.MAX_SPEED_LEVEL) == nil)

-- Lock, nests, offline
check("lock 60 s", Formulas.lockSeconds({}) == 60)
check("long lock + VIP", Formulas.lockSeconds({ LONGLOCK = true, VIP = true }) == 135)
check("extra nests pass", Formulas.maxNests(4, { NESTS = true }) == 8)
check("no offline coins for short breaks", Formulas.offlineCoins(10, 60) == 0)
check("offline = quarter speed", Formulas.offlineCoins(10, 3600) == 9000)
check("offline capped at 8 h", Formulas.offlineCoins(10, 48 * 3600) == 72000)

-- Rolls
local function seq(values)
	local i = 0
	return function()
		i += 1
		return values[i] or 0.99
	end
end
local id, sp = Formulas.rollDragon(seq({ 0.0, 0.0, 0.99, 0.99, 0.99, 0.99 }), false)
check("low roll = first common, no special", id == "PUFF" and sp == nil, id)
id = Formulas.rollDragon(seq({ 0.999, 0.0 }), false)
check("top roll = secret", Dragons.byId[id].rarity == "Secret", id)
id = Formulas.rollDragon(seq({ 0.0, 0.0 }), false, "Legend")
check("minimum rarity respected", Dragons.RarityRank[Dragons.byId[id].rarity] >= 4, id)
id, sp = Formulas.rollDragon(seq({ 0.0, 0.0, 0.001 }), false)
check("rainbow special on a tiny roll", sp == "RAINBOW", sp)
-- luck makes rare+ more likely: count over a fixed stream
local rng = Engine.globals.Random.new(5)
local function r()
	return rng:NextNumber()
end
local normal, lucky = 0, 0
for _ = 1, 4000 do
	if Dragons.byId[(Formulas.rollDragon(r, false))].rarity ~= "Common" then
		normal += 1
	end
	if Dragons.byId[(Formulas.rollDragon(r, true))].rarity ~= "Common" then
		lucky += 1
	end
end
check("server luck gives more rare dragons", lucky > normal * 1.2, `{normal} vs {lucky}`)

-- Daily, deal, egg
check(
	"day 2 gift is a Rare dragon",
	Formulas.dailyGift(2).kind == "dragon" and Dragons.byId[Formulas.dailyGift(2).id].rarity == "Rare"
)
check("day 7 gift is a Legend", Dragons.byId[Formulas.dailyGift(7).id].rarity == "Legend")
check("gifts repeat after a week", Formulas.dailyGift(8).text == Formulas.dailyGift(1).text)
check("daily deal is Rare or Epic", Dragons.RarityRank[Dragons.byId[Formulas.dailyDeal(20000)].rarity] >= 2)
check("egg dragons exist", Dragons.byId[Formulas.eggDragon(1)] ~= nil and Dragons.byId[Formulas.eggDragon(99)] ~= nil)

-- Format
check("format small", Format.num(999) == "999")
check("format K", Format.num(1234) == "1.2K", Format.num(1234))
check("format M", Format.num(3400000) == "3.4M", Format.num(3400000))
check("format whole", Format.num(25000) == "25K", Format.num(25000))
check("format 100+", Format.num(250000) == "250K", Format.num(250000))
check("commas", Format.commas(1234567) == "1,234,567")
check("time m:ss", Format.time(65) == "1:05")
check("time hours", Format.time(3 * 3600 + 300) == "3h 5m")

-- Data sanity
for _, d in Dragons.list do
	check("price > 0 " .. d.id, d.price > 0 and d.cps > 0 and Dragons.RarityColor[d.rarity] ~= nil)
end
for i, g in Goals do
	check("goal " .. i .. " has a known kind", ({
		coins = 1,
		bought = 1,
		steals = 1,
		nests = 1,
		rarity = 1,
		speed = 1,
		locks = 1,
		bonks = 1,
		earned = 1,
		friendPlay = 1,
		stage = 1,
	})[g.kind] ~= nil)
end
for _, p in Shop.Products do
	check("product price " .. p.key, p.price > 0)
end
for _, p in Shop.Passes do
	check("pass price " .. p.key, p.price > 0)
end
for n = 5, Constants.BUYABLE_NESTS do
	check("nest price " .. n, Constants.NEST_PRICES[n] ~= nil)
end

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("formula tests failed")
end

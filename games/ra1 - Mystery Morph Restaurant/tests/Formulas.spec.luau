-- Unit tests for Shared/Formulas against the GDD canon reference values.
-- Runs outside Roblox with any Luau runtime that exposes `loadModule(path)` (see other/ra1/README.md):
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Formulas = loadModule("src/shared/Formulas.lua")

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail and (": " .. detail) or ""))
	end
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end

-- C5.1 XP curve reference values
check("xpReq(1) = 210", Formulas.xpReq(1) == 210, tostring(Formulas.xpReq(1)))
check("xpReq(10) = 713", Formulas.xpReq(10) == 713, tostring(Formulas.xpReq(10)))
check("xpReq(26) = 2885", Formulas.xpReq(26) == 2885, tostring(Formulas.xpReq(26)))
check("xpReq(80) = 83523", Formulas.xpReq(80) == 83523, tostring(Formulas.xpReq(80)))
local cum = 0
for l = 1, 9 do
	cum += Formulas.xpReq(l)
end
check("cumulative XP to L10 = 3661", cum == 3661, tostring(cum))

-- C5 stats
check("maxHp(1) = 100", Formulas.maxHp(1) == 100)
check("maxHp(10) = 118", Formulas.maxHp(10) == 118)
check("cook time at cap", near(Formulas.cookTimeMult(150), 0.526, 0.001))
check("walk speed at cap", near(Formulas.walkSpeed(100), 20.8, 1e-9))
check("damage taken at DEF 200", near(Formulas.damageTakenMult(200), 1 / 3, 1e-9))

-- C8 heat timing (T_ready 8, window 2, burn after 6, fire after 4)
local function grade(t)
	return (Formulas.heatGrade(t, 8, 2, 6, 4))
end
check("undercooked", grade(5) == "UNDERCOOKED")
check("perfect", grade(9) == "PERFECT")
check("good", grade(12) == "GOOD")
check("burned", grade(16) == "BURNED")
local g, s, fire = Formulas.heatGrade(19, 8, 2, 6, 4)
check("on fire after burn + 4", g == "RUINED" and s == 0 and fire == true)

-- C8 chopping ring
check("chop green", Formulas.chopTapScore(0.5) == 1.0)
check("chop yellow", Formulas.chopTapScore(0.3) == 0.8)
check("chop miss", Formulas.chopTapScore(0.05) == 0.6)

-- C11.2 patience
check("patience 1 item D1", near(Formulas.patience(1, 1, 1, 0), 75))
check("patience goblin 2 items", near(Formulas.patience(2, 2, 0.55, 0), (70 + 20 + 10) * 0.55))

-- C11.3 wait factor and satisfaction
check("wait within half", Formulas.waitFactor(30, 75) == 1)
check("wait at 75 %", near(Formulas.waitFactor(56.25, 75), 0.5))
check("wait over", Formulas.waitFactor(100, 75) == 0)
local perfect = { A = 1, Q = 1, C = 1, W = 1, K = 1, M = 1 }
check("perfect neutral = 100", near(Formulas.satisfaction(perfect, { pMult = 1, pOffset = 0 }), 100))
check("karen caps lower", near(Formulas.satisfaction(perfect, { pMult = 0.85, pOffset = -5 }), 80))
check("clamped at 100", Formulas.satisfaction(perfect, { pMult = 1.05, pOffset = 5 }) == 100)
check(
	"mood thresholds",
	Formulas.mood(92, { 90, 70, 50, 30 }) == "Delighted" and Formulas.mood(29, { 90, 70, 50, 30 }) == "Furious"
)

-- C11.4 payment
local pay, tip, jackpot = Formulas.payment(20, 85, 1, 0, 0.99, 1)
check("pay full at S 85", pay == 20)
check("tip 10 % at S 85", tip == 2)
check("no jackpot", jackpot == false)
pay, tip = Formulas.payment(20, 40, 1, 0, 0.99, 1)
check("pay 80 % at S 40, no tip", pay == 16 and tip == 0)
pay, tip, jackpot = Formulas.payment(20, 99, 1, 0, 0.0, 1)
check("jackpot ×5 on a lucky roll", jackpot and tip == 25, tostring(tip))
check("stars move toward S/20", near(Formulas.updateStars(2.5, 100), 2.55))
check("rep mult at 2.5 stars", near(Formulas.repMult(2.5), 1.125))
check("demand at T1, 2.5 stars, atmosphere 30", near(Formulas.demandPerHour(50, 2.5, 30), 50 * 1.125 * 0.99))

-- C11.5 anger
local floors = { 0, 15, 30, 45, 60, 75, 90 }
check("anger level 0", Formulas.angerLevel(10, floors) == 0)
check("anger level 3", Formulas.angerLevel(45, floors) == 3)
check("anger level 6", Formulas.angerLevel(95, floors) == 6)
check("calm amount capped", Formulas.calmAmount(500) == 35)

-- C6 damage states
local states = {
	{ name = "Pristine", min = 76 },
	{ name = "Scuffed", min = 51 },
	{ name = "Cracked", min = 26 },
	{ name = "Broken", min = 1 },
	{ name = "Destroyed", min = 0 },
}
check("pristine", Formulas.damageState(100, states) == "Pristine")
check("broken", Formulas.damageState(10, states) == "Broken")
check("destroyed", Formulas.damageState(0, states) == "Destroyed")

-- Recipe matching
local basic = {
	parts = {
		{ "ING_BUN", 1, "RAW" },
		{ "ING_BEEF_PATTY", 1, "GRILLED" },
		{ "ING_PICKLE", 1, "CHOPPED" },
		{ "ING_LETTUCE", 1, "CHOPPED" },
		{ "ING_KETCHUP", 1, "RAW" },
	},
	core = { "ING_BUN", "ING_BEEF_PATTY" },
}
local cheese = {
	parts = {
		{ "ING_BUN", 1, "RAW" },
		{ "ING_BEEF_PATTY", 1, "GRILLED" },
		{ "ING_CHEESE", 1, "RAW" },
		{ "ING_TOMATO", 1, "CHOPPED" },
		{ "ING_LETTUCE", 1, "CHOPPED" },
		{ "ING_KETCHUP", 1, "RAW" },
	},
	core = { "ING_BUN", "ING_BEEF_PATTY" },
}
local double = {
	parts = {
		{ "ING_BUN", 1, "RAW" },
		{ "ING_BEEF_PATTY", 2, "GRILLED" },
		{ "ING_CHEESE", 2, "RAW" },
		{ "ING_LETTUCE", 1, "CHOPPED" },
		{ "ING_KETCHUP", 1, "RAW" },
	},
	core = { "ING_BUN", "ING_BEEF_PATTY" },
}
local full = {
	["ING_BUN|RAW"] = 1,
	["ING_BEEF_PATTY|GRILLED"] = 1,
	["ING_PICKLE|CHOPPED"] = 1,
	["ING_LETTUCE|CHOPPED"] = 1,
	["ING_KETCHUP|RAW"] = 1,
}
local ok, omitted = Formulas.matchRecipe(basic, full)
check("basic burger exact", ok and #omitted == 0)
local noPickle =
	{ ["ING_BUN|RAW"] = 1, ["ING_BEEF_PATTY|GRILLED"] = 1, ["ING_LETTUCE|CHOPPED"] = 1, ["ING_KETCHUP|RAW"] = 1 }
ok, omitted = Formulas.matchRecipe(basic, noPickle)
check("basic burger without pickle", ok and omitted[1] == "ING_PICKLE")
check("no bun is not a burger", not Formulas.matchRecipe(basic, { ["ING_BEEF_PATTY|GRILLED"] = 1 }))
check("raw patty does not match", not Formulas.matchRecipe(basic, { ["ING_BUN|RAW"] = 1, ["ING_BEEF_PATTY|RAW"] = 1 }))
local best = Formulas.bestMatch({ basic, cheese, double }, noPickle)
check("best match prefers fewest omissions", best == basic)
local twoPatties = {
	["ING_BUN|RAW"] = 1,
	["ING_BEEF_PATTY|GRILLED"] = 2,
	["ING_CHEESE|RAW"] = 2,
	["ING_LETTUCE|CHOPPED"] = 1,
	["ING_KETCHUP|RAW"] = 1,
}
check("counts pick the double", Formulas.bestMatch({ basic, cheese, double }, twoPatties) == double)
check("accuracy exact", Formulas.accuracy({ "ING_PICKLE" }, { "ING_PICKLE" }) == 1)
check("accuracy forgot mod", Formulas.accuracy({}, { "ING_PICKLE" }) == 0.75)
check("accuracy left out extra", Formulas.accuracy({ "ING_PICKLE", "ING_LETTUCE" }, {}) == 0.5)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end

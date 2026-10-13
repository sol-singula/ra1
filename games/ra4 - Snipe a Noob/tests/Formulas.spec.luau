-- Unit tests for the game math (no engine needed beyond the mock's globals).
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local Rifles = Engine.require(tree.shared.Data.Rifles)
local Maps = Engine.require(tree.shared.Data.Maps)
local Vector3 = Engine.Vector3
local Random = Engine.globals.Random

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

-- Levels -------------------------------------------------------------------------------------------------------
check("level 1 at 0 xp", Formulas.levelFromXp(0) == 1)
local need1 = Formulas.xpForLevel(1)
check("level 2 at the first threshold", Formulas.levelFromXp(need1) == 2)
check("just under stays level 1", Formulas.levelFromXp(need1 - 1) == 1)
check("each level needs more", Formulas.xpForLevel(10) > Formulas.xpForLevel(9))
local lv, into, need = Formulas.levelFromXp(need1 + 50)
check("progress into a level", lv == 2 and into == 50 and need == Formulas.xpForLevel(2))
check("level cap", Formulas.levelFromXp(10 ^ 9) == Constants.MAX_LEVEL)
check("level coins at least 100", Formulas.levelCoins(2) == 100 and Formulas.levelCoins(50) == 500)
-- how long levels take: a pop is 25 xp, a round about 60 + 10 pops
local roundXp = Constants.XP.round + 10 * Constants.XP.pop
local xpTo20 = 0
for l = 1, 19 do
	xpTo20 += Formulas.xpForLevel(l)
end
check("level 20 takes about 20 to 60 rounds", xpTo20 / roundXp >= 20 and xpTo20 / roundXp <= 60, xpTo20 / roundXp)

-- Coins ------------------------------------------------------------------------------------------------------
check("a pop = 10", Formulas.popCoins({}) == 10)
check("a headshot = 20", Formulas.popCoins({ headshot = true }) == 20)
check("streak bonus from 3", Formulas.popCoins({ streak = 3 }) == 15 and Formulas.popCoins({ streak = 2 }) == 10)
check("revenge bonus", Formulas.popCoins({ revenge = true }) == 25)
check("crown bonus", Formulas.popCoins({ crown = true }) == 60)
check("last minute doubles", Formulas.popCoins({ headshot = true, lastMinute = true }) == 40)
check("robots pay a little", Formulas.popCoins({ robot = true, headshot = true }) == Constants.COINS.robot)

-- Hit shapes -----------------------------------------------------------------------------------------------------
local root = Vector3.new(0, 3, 0)
local fromFar = Vector3.new(0, 3, 50)
local d, head = Formulas.hitTarget(Vector3.new(0, 4.6, 50), Vector3.new(0, 0, -1), root, 100)
check("a shot at the head is a headshot", d ~= nil and head == true, d)
d, head = Formulas.hitTarget(fromFar, Vector3.new(0, 0, -1), root, 100)
check(
	"a shot at the chest hits the body",
	d ~= nil and head == false and math.abs(d - (50 - Constants.BODY_RADIUS)) < 0.1,
	d
)
d = Formulas.hitTarget(Vector3.new(0, 1, 50), Vector3.new(0, 0, -1), root, 100)
check("a shot at the legs hits", d ~= nil)
d = Formulas.hitTarget(Vector3.new(3, 3, 50), Vector3.new(0, 0, -1), root, 100)
check("a shot to the side misses", d == nil)
d = Formulas.hitTarget(Vector3.new(0, 7, 50), Vector3.new(0, 0, -1), root, 100)
check("over the head misses", d == nil)
d = Formulas.hitTarget(fromFar, Vector3.new(0, 0, -1), root, 30)
check("past max distance misses (a wall in front)", d == nil)
d = Formulas.hitTarget(fromFar, Vector3.new(0, 0, 1), root, 100)
check("shooting away misses", d == nil)
d = Formulas.hitTarget(Vector3.new(0, 3, 0.5), Vector3.new(0, 0, -1), root, 100)
check("point blank inside the body hits", d ~= nil and d < 0.6, d)
-- spread
local dir = Vector3.new(0, 0, -1)
check("no spread = same direction", Formulas.spread(dir, 0, 0.3, 0.6) == dir)
local wide = Formulas.spread(dir, 3.5, 1, 0.25)
check(
	"spread stays within its cone",
	Formulas.angle(dir, wide) <= 3.51 and Formulas.angle(dir, wide) > 3.4,
	Formulas.angle(dir, wide)
)

-- Odds -----------------------------------------------------------------------------------------------------------
for _, crate in Cosmetics.Crates do
	local total = 0
	for _, row in crate.odds do
		total += row[2]
		check(`{crate.name}: {row[1]} has skins`, #Cosmetics.crateSkins(row[1]) > 0)
	end
	check(`{crate.name} odds add to 100`, math.abs(total - 100) < 1e-9, total)
	check(`{crate.name} shows its odds`, #Formulas.oddsLines(crate.key) == #crate.odds)
end
local rng = Random.new(5)
local counts = {}
for _ = 1, 4000 do
	local id = Formulas.rollCrate(rng, "COIN")
	local r = Cosmetics.skinById[id].rarity
	counts[r] = (counts[r] or 0) + 1
end
check(
	"coin crate is mostly Common",
	(counts.Common or 0) / 4000 > 0.64 and (counts.Common or 0) / 4000 < 0.76,
	counts.Common
)
check("coin crate never gives Secret", counts.Secret == nil)
check(
	"season skins never come from crates",
	(function()
		for _ = 1, 500 do
			local s = Cosmetics.skinById[Formulas.rollCrate(rng, "KEY")]
			if s.source ~= "crate" then
				return false
			end
		end
		return true
	end)()
)

-- The Daily Shop ---------------------------------------------------------------------------------------------------
local shopA = Formulas.dailyShop(20000)
local shopB = Formulas.dailyShop(20000)
local shopC = Formulas.dailyShop(20001)
check("daily shop has 10 items", #shopA == Constants.DAILY_SHOP_SIZE, #shopA)
check("the same day gives the same shop", shopA[1].id == shopB[1].id and shopA[7].id == shopB[7].id)
local same = 0
for i = 1, 6 do
	if shopA[i].id == shopC[i].id then
		same += 1
	end
end
check("the next day changes", same < 6)
local kinds = { skin = 0, effect = 0, emote = 0 }
local ids = {}
for _, item in shopA do
	kinds[item.kind] += 1
	check("shop item has a price", item.price > 0)
	check("no repeats in a shop", not ids[item.kind .. item.id])
	ids[item.kind .. item.id] = true
end
check("6 skins, 2 effects, 2 emotes", kinds.skin == 6 and kinds.effect == 2 and kinds.emote == 2)

-- Seasons ------------------------------------------------------------------------------------------------------
local n1, ends1 = Formulas.season(Constants.SEASON_START + 10)
check("season 1 at the start", n1 == 1 and ends1 == Constants.SEASON_START + Constants.SEASON_DAYS * 86400)
check("season 2 after 14 days", Formulas.season(Constants.SEASON_START + 15 * 86400) == 2)
check("tier from xp", Formulas.seasonTier(Constants.SEASON_TIER_XP * 3 + 5) == 3)
check("tier cap", Formulas.seasonTier(10 ^ 9) == Constants.SEASON_TIERS)
for tier = 1, Constants.SEASON_TIERS do
	local free, pass = Formulas.seasonReward(tier)
	check(`tier {tier} has rewards`, free ~= nil and pass ~= nil and next(pass) ~= nil)
	if pass.skin then
		check(
			`tier {tier} skin is a season skin`,
			Cosmetics.skinById[pass.skin] and Cosmetics.skinById[pass.skin].source == "season"
		)
	end
	if pass.effect then
		check(`tier {tier} effect exists`, Cosmetics.effectById[pass.effect] ~= nil)
	end
	if pass.emote then
		check(`tier {tier} emote exists`, Cosmetics.emoteById[pass.emote] ~= nil)
	end
end

-- Data ------------------------------------------------------------------------------------------------------------
check("5 rifles", #Rifles.list == 5)
for i, r in Rifles.list do
	check(`{r.name} has a scope zoom`, r.fov > 5 and r.fov < Constants.HIP_FOV)
	if i > 1 then
		check(
			`{r.name} unlocks later and costs more`,
			r.level > Rifles.list[i - 1].level and r.price > Rifles.list[i - 1].price
		)
	end
end
check(
	"Twin fires two quick shots",
	Rifles.cooldown(Rifles.byKey.TWIN, 1) == Rifles.byKey.TWIN.gap
		and Rifles.cooldown(Rifles.byKey.TWIN, 2) == Rifles.byKey.TWIN.bolt
)
check("4 maps", #Maps.list == 4)
local _, endsAt = Formulas.dailyPeriod(1700000000)
check("daily period ends in the future", endsAt > 1700000000 and endsAt - 1700000000 <= 86400)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error("formula tests failed")
end

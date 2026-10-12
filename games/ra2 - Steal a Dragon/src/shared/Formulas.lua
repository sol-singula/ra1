-- Pure game math, shared by server and client (and unit-tested in tests/Formulas.spec.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)

local Formulas = {}

-- A dragon's level: it levels up by itself over time (fast at first, then slower), plus the levels its owner
-- bought (rec.lv). Capped at MAX_LEVEL.
function Formulas.level(rec, now)
	local minutes = math.max(0, now - rec.born) / 60
	local natural = 1 + math.floor(Constants.LEVEL_RATE * math.sqrt(minutes))
	return math.min(Constants.MAX_LEVEL, natural + (rec.lv or 0))
end

-- Size step 1..4 (Baby, Kid, Big, Giant) for a level. Giant is the last size; levels keep going.
function Formulas.stageForLevel(level)
	local stage = 1
	for i, need in Constants.STAGE_LEVELS do
		if level >= need then
			stage = i
		end
	end
	return stage
end

function Formulas.stage(rec, now)
	return Formulas.stageForLevel(Formulas.level(rec, now))
end

-- Coin multiplier for a level: +LEVEL_STEP per level.
function Formulas.levelMult(level)
	return 1 + Constants.LEVEL_STEP * (level - 1)
end

-- Coins to buy one more level (nil at MAX_LEVEL). Grows by LEVEL_COST_GROWTH per level, so early levels are a
-- few minutes of income and high levels take a long time to pay back.
function Formulas.levelUpCost(rec, now)
	local level = Formulas.level(rec, now)
	if level >= Constants.MAX_LEVEL then
		return nil
	end
	local base = Dragons.byId[rec.id].cps * Formulas.specialMult(rec.sp) * (rec.mx or 1)
	return math.floor(base * Constants.LEVEL_COST_SECONDS * Constants.LEVEL_COST_GROWTH ^ (level - 1))
end

function Formulas.specialMult(special)
	return special and Dragons.Specials[special] and Dragons.Specials[special].mult or 1
end

-- Coins per second of one dragon record { id, sp, born, lv } before player bonuses.
-- rec.mx: the boost from dragons combined into this one (DragonService:Combine), so combining keeps the income.
function Formulas.dragonIncome(rec, now)
	local d = Dragons.byId[rec.id]
	return d.cps * Formulas.levelMult(Formulas.level(rec, now)) * Formulas.specialMult(rec.sp) * (rec.mx or 1)
end

-- The boost to give `into` so it earns what it and `from` earned together.
function Formulas.combinedBoost(into, from, now)
	local a, b = Formulas.dragonIncome(into, now), Formulas.dragonIncome(from, now)
	return (into.mx or 1) * (a + b) / math.max(a, 1e-9)
end

function Formulas.roadPrice(id, special)
	return math.floor(Dragons.byId[id].price * Formulas.specialMult(special))
end

function Formulas.sellValue(rec, now)
	local mult = Formulas.levelMult(Formulas.level(rec, now)) * (rec.mx or 1)
	return math.floor(Formulas.roadPrice(rec.id, rec.sp) * Constants.SELL_FRACTION * mult)
end

-- Player-wide coin multiplier.
function Formulas.playerMult(passes, friendsHere)
	local m = 1
	if passes.DOUBLE then
		m *= Constants.DOUBLE_COINS_MULT
	end
	if passes.VIP then
		m *= Constants.VIP_MULT
	end
	local friends = math.min(friendsHere or 0, Constants.MAX_FRIEND_BONUS_FRIENDS)
	return m * (1 + Constants.FRIEND_BONUS * friends)
end

function Formulas.walkSpeed(speedLevel, carryingRec, now, passes)
	local speed = Constants.BASE_WALK_SPEED + Constants.SPEED_PER_LEVEL * (speedLevel - 1)
	if carryingRec then
		local d = Dragons.byId[carryingRec.id]
		local stage = Formulas.stage(carryingRec, now)
		speed *= Dragons.CarrySpeed[d.rarity] * (1 - 0.04 * (stage - 1))
		if passes and passes.FAST then
			speed *= Constants.FAST_FEET_MULT
		end
	end
	return speed
end

-- Price of the next speed level (nil at max).
function Formulas.speedPrice(level)
	if level >= Constants.MAX_SPEED_LEVEL then
		return nil
	end
	return math.floor(Constants.SPEED_PRICE_BASE * Constants.SPEED_PRICE_GROWTH ^ (level - 1))
end

function Formulas.lockSeconds(passes)
	local s = passes.LONGLOCK and Constants.LOCK_SECONDS_LONG or Constants.LOCK_SECONDS
	if passes.VIP then
		s += Constants.LOCK_VIP_BONUS
	end
	return s
end

function Formulas.maxNests(boughtNests, passes)
	return boughtNests + (passes.NESTS and 4 or 0)
end

-- Coins earned while away (a quarter speed, at most 8 hours).
function Formulas.offlineCoins(incomePerSecond, secondsAway)
	if secondsAway < Constants.OFFLINE_MIN_SECONDS then
		return 0
	end
	return math.floor(incomePerSecond * math.min(secondsAway, Constants.OFFLINE_CAP_SECONDS) * Constants.OFFLINE_RATE)
end

-- Day number (UTC) used by the daily gift and the daily deal.
function Formulas.day(now)
	return math.floor(now / 86400)
end

-- Days since 1970-01-01 for a calendar date, and back (proleptic Gregorian; pure maths, no time zone).
local function daysFromCivil(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end
local function yearOf(days)
	local z = days + 719468
	local era = math.floor(z / 146097)
	local doe = z - era * 146097
	local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
	local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
	local mp = math.floor((5 * doy + 2) / 153)
	local m = mp < 10 and mp + 3 or mp - 9
	return era * 400 + yoe + (m <= 2 and 1 or 0)
end
-- The day (since 1970) of the n-th Sunday of a month.
local function nthSunday(y, m, n)
	local first = daysFromCivil(y, m, 1)
	local weekday = (first + 4) % 7 -- 0 = Sunday (1970-01-01 was a Thursday)
	return first + (7 - weekday) % 7 + (n - 1) * 7
end

-- US Eastern time's offset from UTC in hours at a UTC time: -4 during daylight saving time (2am on the second
-- Sunday of March to 2am on the first Sunday of November), -5 otherwise.
function Formulas.easternOffset(utc)
	local y = yearOf(math.floor(utc / 86400))
	local dstStart = nthSunday(y, 3, 2) * 86400 + 7 * 3600 -- 2am EST
	local dstEnd = nthSunday(y, 11, 1) * 86400 + 6 * 3600 -- 2am EDT
	return (utc >= dstStart and utc < dstEnd) and -4 or -5
end

-- The daily leaderboard runs from 7pm Eastern to 7pm Eastern. Returns the period number and when it ends (UTC).
function Formulas.dailyPeriod(utc)
	local shift = (Formulas.easternOffset(utc) - Constants.DAILY_RESET_HOUR_ET) * 3600
	local period = math.floor((utc + shift) / 86400)
	return period, (period + 1) * 86400 - shift
end

-- Weighted pick helper: list of { item, weight }, r in [0, 1).
function Formulas.pick(entries, r)
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	local x = r * total
	for _, e in entries do
		x -= e[2]
		if x < 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

-- Roll a road dragon. rng returns numbers in [0, 1). lucky = Server Luck active. minRarity forces Legend+ etc.
-- fancy = true rolls one of the custom dragons instead (their own rarity weights; no Commons).
function Formulas.rollDragon(rng, lucky, minRarity, fancy)
	local entries = {}
	local weights = fancy and Constants.FANCY_RARITY_WEIGHTS or Constants.RARITY_WEIGHTS
	for _, rarity in Dragons.Rarities do
		if weights[rarity] and (not minRarity or Dragons.RarityRank[rarity] >= Dragons.RarityRank[minRarity]) then
			local w = weights[rarity]
			if lucky then
				w *= Constants.LUCK_RARITY_MULT[rarity]
			end
			table.insert(entries, { rarity, w })
		end
	end
	local rarity = Formulas.pick(entries, rng())
	local species = {}
	for _, d in (fancy and Dragons.fancyByRarity or Dragons.byRarity)[rarity] do
		table.insert(species, { d.id, d.weight })
	end
	local id = Formulas.pick(species, rng())
	local special
	for _, key in Dragons.SpecialOrder do
		local chance = Dragons.Specials[key].chance * (lucky and Constants.LUCK_SPECIAL_MULT or 1)
		if rng() < chance then
			special = key
			break
		end
	end
	return id, special
end

-- Today's Daily Deal dragon: a Rare or Epic picked from the day number, the same for everyone.
function Formulas.dailyDeal(day)
	local pool = {}
	for _, d in Dragons.byRarity.Rare do
		table.insert(pool, d.id)
	end
	for _, d in Dragons.byRarity.Epic do
		table.insert(pool, d.id)
	end
	return pool[(day * 7 + 3) % #pool + 1]
end

-- How good a player's dragons are: the coins per second of their best species (with its special, before
-- levels). Daily gifts and eggs are sized from this, so they stay worth having at every stage of the game.
function Formulas.bestSpecies(records)
	local best = 0
	for _, rec in records do
		local d = Dragons.byId[rec.id]
		if d then
			best = math.max(best, d.cps * Formulas.specialMult(rec.sp))
		end
	end
	return best
end

-- A dragon about this good: one of the road-able dragons (not the Ultra prize) earning between `target` and 1.6x
-- that, picked by `seed`; if none earns that much, one of the five best. Custom dragons come first when there's a
-- choice of both.
function Formulas.dragonForPower(target, seed)
	local fancy, regular, all = {}, {}, {}
	for _, d in Dragons.list do
		if not d.ultra then
			table.insert(all, d)
			if d.cps >= target and d.cps <= target * 1.6 then
				table.insert(d.fancy and fancy or regular, d.id)
			end
		end
	end
	local pool = #fancy > 0 and fancy or regular
	if #pool == 0 then
		table.sort(all, function(a, b)
			return a.cps > b.cps
		end)
		local above = {}
		for _, d in all do
			if d.cps >= target then
				table.insert(above, d)
			end
		end
		if #above > 0 then
			return above[#above].id -- the cheapest dragon that's still good enough
		end
		for i = 1, math.min(5, #all) do
			table.insert(pool, all[i].id)
		end
	end
	table.sort(pool)
	return pool[(math.floor(seed) * 7 + 3) % #pool + 1]
end

-- Daily gift for streak day n (1..7, then repeats). Coins are minutes of the player's own income (at least
-- `amount`); dragons are a multiple of their best dragon (at least as good as `min`).
Formulas.DAILY_GIFTS = {
	{ kind = "coins", seconds = 600, amount = 500 },
	{ kind = "dragon", mult = 0.7, min = "FROSTY" },
	{ kind = "coins", seconds = 1800, amount = 2500 },
	{ kind = "dragon", mult = 1.2, min = "BLAZE" },
	{ kind = "coins", seconds = 3600, amount = 15000 },
	{ kind = "luck" },
	{ kind = "dragon", mult = 2.5, min = "GOLDIE" },
}

-- The gift for streak day n, sized for a player with this income (coins per second) and best dragon
-- (Formulas.bestSpecies). seed varies which dragon; gift: another gift spec to size instead (playtime gifts).
-- Returns { kind, amount | id, text }.
function Formulas.dailyGift(streakDay, income, best, seed, gift)
	local g = gift or Formulas.DAILY_GIFTS[(streakDay - 1) % #Formulas.DAILY_GIFTS + 1]
	if g.kind == "coins" then
		local amount = math.max(g.amount, math.floor((income or 0) * g.seconds))
		return { kind = "coins", amount = amount, text = Format.num(amount) .. " coins" }
	elseif g.kind == "dragon" then
		local target = math.max(Dragons.byId[g.min].cps, (best or 0) * g.mult)
		local id = Formulas.dragonForPower(target, seed or streakDay)
		local d = Dragons.byId[id]
		return { kind = "dragon", id = id, text = `{d.name} ({d.rarity})` }
	end
	return { kind = "luck", text = "Server Luck (15 min)" }
end

-- Playtime gifts: each day, the longer you play the better they get (PlaytimeService). at = seconds played today.
Formulas.PLAYTIME_GIFTS = {
	{ at = 60, kind = "coins", seconds = 60, amount = 150 },
	{ at = 180, kind = "potion", count = 2 },
	{ at = 300, kind = "dragon", mult = 0.6, min = "FROSTY" },
	{ at = 600, kind = "coins", seconds = 240, amount = 1000 },
	{ at = 900, kind = "luck" },
	{ at = 1200, kind = "coins", seconds = 480, amount = 4000 },
	{ at = 1800, kind = "dragon", mult = 1.3, min = "BLAZE" },
	{ at = 2700, kind = "coins", seconds = 900, amount = 15000 },
	{ at = 3600, kind = "dragon", mult = 2, min = "GOLDIE" },
}

-- Playtime gift n, sized for this player's income and best dragon. Returns { kind, amount | id | count, text }.
function Formulas.playtimeGift(n, income, best, seed)
	local g = Formulas.PLAYTIME_GIFTS[n]
	if g.kind == "potion" then
		return { kind = "potion", count = g.count, text = `{g.count} Speed Potions` }
	end
	return Formulas.dailyGift(1, income, best, seed, g)
end

-- The egg hatches a dragon better than the player's best (eggNumber varies which), with a special.
function Formulas.eggDragon(best, eggNumber)
	return Formulas.dragonForPower(math.max(4, (best or 0) * 1.5), eggNumber)
end
Formulas.EGG_SPECIALS = { { "FIRE", 50 }, { "ICE", 30 }, { "GOLD", 15 }, { "RAINBOW", 5 } }

return Formulas

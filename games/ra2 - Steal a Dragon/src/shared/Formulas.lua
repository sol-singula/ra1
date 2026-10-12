-- Pure game math, shared by server and client (and unit-tested in tests/Formulas.spec.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)

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
	local base = Dragons.byId[rec.id].cps * Formulas.specialMult(rec.sp)
	return math.floor(base * Constants.LEVEL_COST_SECONDS * Constants.LEVEL_COST_GROWTH ^ (level - 1))
end

function Formulas.specialMult(special)
	return special and Dragons.Specials[special] and Dragons.Specials[special].mult or 1
end

-- Coins per second of one dragon record { id, sp, born, lv } before player bonuses.
function Formulas.dragonIncome(rec, now)
	local d = Dragons.byId[rec.id]
	return d.cps * Formulas.levelMult(Formulas.level(rec, now)) * Formulas.specialMult(rec.sp)
end

function Formulas.roadPrice(id, special)
	return math.floor(Dragons.byId[id].price * Formulas.specialMult(special))
end

function Formulas.sellValue(rec, now)
	local mult = Formulas.levelMult(Formulas.level(rec, now))
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

-- Daily gift for streak day n (1..7, then repeats).
Formulas.DAILY_GIFTS = {
	{ kind = "coins", amount = 500, text = "500 coins" },
	{ kind = "dragon", id = "FROSTY", text = "Frosty (Rare)" },
	{ kind = "coins", amount = 2500, text = "2,500 coins" },
	{ kind = "dragon", id = "BLAZE", text = "Blaze (Epic)" },
	{ kind = "coins", amount = 15000, text = "15,000 coins" },
	{ kind = "luck", text = "Server Luck (15 min)" },
	{ kind = "dragon", id = "GOLDIE", text = "King Goldie (Legend)" },
}
function Formulas.dailyGift(streakDay)
	return Formulas.DAILY_GIFTS[(streakDay - 1) % #Formulas.DAILY_GIFTS + 1]
end

-- The overnight egg always hatches into this list's entry for the player's egg count (shown up front, no gamble).
Formulas.EGG_DRAGONS = { "CORAL", "STORM", "LEAFY", "JELLY", "SPARKY", "BLAZE" }
function Formulas.eggDragon(eggNumber)
	return Formulas.EGG_DRAGONS[(eggNumber - 1) % #Formulas.EGG_DRAGONS + 1]
end

return Formulas

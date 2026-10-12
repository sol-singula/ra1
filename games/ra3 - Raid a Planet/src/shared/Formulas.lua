-- The game's math: damage, health, rolls, odds, prices. Pure functions, unit-tested in tests/Formulas.spec.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)

local Formulas = {}

-- Health ---------------------------------------------------------------------------------------------------
-- A bug's health on a planet with this many players near it.
function Formulas.bugHealth(planet, nearPlayers)
	return math.floor(planet.bugHealth * (1 + Constants.SCALE_PER_PLAYER * math.max(0, (nearPlayers or 1) - 1)))
end

function Formulas.bossHealth(planet, nearPlayers)
	return Formulas.bugHealth(planet, nearPlayers) * Constants.BOSS_HEALTH_MULT
end

-- Blasters -------------------------------------------------------------------------------------------------
-- Base damage of a planet's blasters: a Common from the planet takes about 6 shots per bug.
function Formulas.baseDamage(planet)
	return planet.bugHealth / 6
end

-- Damage per shot of a blaster record { rarity, planet, roll = { dmg, spd, luck, gem }, lv }.
function Formulas.blasterDamage(rec, extraMult)
	local planet = Planets.byKey[rec.planet]
	local rarity = Blasters.byRarity[rec.rarity]
	if not planet or not rarity then
		return 0
	end
	local dmg = Formulas.baseDamage(planet) * rarity.mult * Constants.ROLL_MULT[rec.roll and rec.roll.dmg or "plain"]
	dmg *= 1 + Constants.POWER_UP_PERCENT * (rec.lv or 0)
	return math.floor(dmg * (extraMult or 1) * 10 + 0.5) / 10 -- (one decimal: small blasters grow by tenths)
end

-- Seconds between shots with this blaster.
function Formulas.blasterCooldown(rec)
	local grade = rec.roll and rec.roll.spd or "plain"
	return Constants.BLAST_COOLDOWN / math.sqrt(Constants.ROLL_MULT[grade])
end

-- A number for "how good is this blaster" (sorting, the raid board, the best-blaster leaderboard).
function Formulas.blasterPower(rec)
	return Formulas.blasterDamage(rec) / Formulas.blasterCooldown(rec)
end

function Formulas.blasterName(rec)
	local planet = Planets.byKey[rec.planet]
	local rarity = Blasters.byRarity[rec.rarity]
	return (planet and planet.adjective or "?") .. " " .. (rarity and rarity.noun or "?")
end

-- How many rolls are GOD / shiny: the "✨✨" shown next to a name.
function Formulas.rollStars(rec)
	local out = ""
	for _, stat in Constants.ROLL_STATS do
		local g = rec.roll and rec.roll[stat]
		if g == "god" then
			out ..= "🌟"
		elseif g == "shiny" then
			out ..= "✨"
		end
	end
	return out
end

-- Coins to Power Up a blaster from its current level (nil at the top).
function Formulas.powerUpCost(rec)
	local lv = rec.lv or 0
	if lv >= Constants.POWER_UP_LEVELS then
		return nil
	end
	local planet = Planets.byKey[rec.planet]
	local rarity = Blasters.byRarity[rec.rarity]
	return math.floor(planet.bugCoins * 4 * rarity.mult * (1.15 ^ lv))
end

function Formulas.sellValue(rec)
	local planet = Planets.byKey[rec.planet]
	local rarity = Blasters.byRarity[rec.rarity]
	return math.floor(rarity.sell * planet.bugCoins / 5)
end

-- Rolling --------------------------------------------------------------------------------------------------
-- Pick from an odds table { { key, percent }, ... } with a 0..1 number; luck > 1 shifts toward the rare end.
function Formulas.pickOdds(table_, r, luck)
	luck = luck or 1
	local total = 0
	local weights = {}
	for i, row in table_ do
		-- rarer rows (later in the table) get boosted by luck
		local w = row[2] * (luck ^ (i - 1))
		weights[i] = w
		total += w
	end
	local x = r * total
	for i, row in table_ do
		x -= weights[i]
		if x <= 0 then
			return row[1]
		end
	end
	return table_[#table_][1]
end

-- Roll a new blaster from a forge tier on a planet. rng has NextNumber(). luck boosts rarity and grades.
function Formulas.rollBlaster(rng, tierKey, planetKey, luck)
	local rarity = Formulas.pickOdds(Constants.FORGE_ODDS[tierKey], rng:NextNumber(), luck)
	local roll = {}
	for _, stat in Constants.ROLL_STATS do
		roll[stat] = Formulas.pickOdds(Constants.ROLL_ODDS, rng:NextNumber(), luck)
	end
	return { rarity = rarity, planet = planetKey, roll = roll, lv = 0 }
end

-- The exact odds of a forge tier as text lines (the Odds page), adding to 100.
function Formulas.oddsLines(tierKey)
	local lines = {}
	for _, row in Constants.FORGE_ODDS[tierKey] do
		table.insert(lines, `{row[1]}: {row[2]}%`)
	end
	return lines
end

function Formulas.forgeTier(key)
	for _, t in Constants.FORGE_TIERS do
		if t.key == key then
			return t
		end
	end
	return nil
end

-- Finish Forge Now price for the seconds left out of the whole time (falls as the timer runs down), snapped
-- to one of the product prices.
function Formulas.finishNowPrice(secondsLeft, totalSeconds, steps)
	local frac = math.clamp(secondsLeft / math.max(1, totalSeconds), 0, 1)
	local want = Constants.FINISH_NOW_MIN + (Constants.FINISH_NOW_MAX - Constants.FINISH_NOW_MIN) * frac
	local best = steps[1]
	for _, price in steps do
		if price <= want then
			best = price
		end
	end
	return best
end

-- Loot -----------------------------------------------------------------------------------------------------
-- Ore and coins a bug drops for a blaster with this Luck roll.
function Formulas.bugLoot(planet, rec)
	local luck = Constants.ROLL_MULT[rec and rec.roll and rec.roll.luck or "plain"]
	return math.floor(planet.bugOre * luck + 0.5), math.floor(planet.bugCoins * luck)
end

-- Days and daily things (UTC days, like ra2's gifts)
function Formulas.day(t)
	return math.floor(t / 86400)
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

-- Text for a count of ore
function Formulas.oreText(planet, n)
	return `{Format.num(n)} {planet.ore}`
end

return Formulas

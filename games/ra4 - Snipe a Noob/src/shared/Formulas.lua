-- The game's math: levels, coins, hit shapes, odds, the daily shop and seasons. Pure functions, unit-tested in
-- tests/Formulas.spec.luau. Shared by the server (which decides every pop) and the client (aim help, previews).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)

local Formulas = {}

-- Levels ----------------------------------------------------------------------------------------------------
-- XP needed to go from `level` to the next one.
function Formulas.xpForLevel(level)
	return Constants.LEVEL_BASE_XP + (level - 1) * Constants.LEVEL_STEP_XP
end

-- Level and progress from total XP: level, xp into this level, xp needed for the next.
function Formulas.levelFromXp(xp)
	local level = 1
	local need = Formulas.xpForLevel(1)
	while xp >= need and level < Constants.MAX_LEVEL do
		xp -= need
		level += 1
		need = Formulas.xpForLevel(level)
	end
	return level, xp, need
end

-- Coins for reaching a level.
function Formulas.levelCoins(level)
	return math.max(Constants.LEVEL_COINS, math.floor(Constants.LEVEL_COINS * level / 100) * 10)
end

-- Coins -----------------------------------------------------------------------------------------------------
-- Coins for one pop. info: { headshot, streak (after this pop), revenge, crown, robot, lastMinute }
function Formulas.popCoins(info)
	local c = Constants.COINS
	if info.robot then
		return c.robot
	end
	local coins = info.headshot and c.headshot or c.pop
	if (info.streak or 0) >= 3 then
		coins += c.streak
	end
	if info.revenge then
		coins += c.revenge
	end
	if info.crown then
		coins += c.crown
	end
	if info.lastMinute then
		coins *= Constants.LAST_MINUTE_MULT
	end
	return coins
end

-- Hit shapes --------------------------------------------------------------------------------------------------
-- Where a ray first hits a ball (center, radius): the distance along the unit direction, or nil.
function Formulas.rayBall(origin, dir, center, radius, maxDist)
	local m = origin - center
	local b = m:Dot(dir)
	local c = m:Dot(m) - radius * radius
	if c > 0 and b > 0 then
		return nil
	end
	local disc = b * b - c
	if disc < 0 then
		return nil
	end
	local t = math.max(0, -b - math.sqrt(disc))
	if t > maxDist then
		return nil
	end
	return t
end

-- Where a ray first hits an upright capsule (from bottom point a to top point b, radius r), or nil.
function Formulas.rayCapsule(origin, dir, a, b, r, maxDist)
	-- the cylinder part: work in the horizontal plane (the capsule is upright)
	local best
	local ox, oz = origin.X - a.X, origin.Z - a.Z
	local dx, dz = dir.X, dir.Z
	local qa = dx * dx + dz * dz
	if qa > 1e-9 then
		local qb = ox * dx + oz * dz
		local qc = ox * ox + oz * oz - r * r
		local disc = qb * qb - qa * qc
		if disc >= 0 then
			local t = (-qb - math.sqrt(disc)) / qa
			if t < 0 and qc <= 0 then
				t = 0
			end
			if t >= 0 then
				local y = origin.Y + dir.Y * t
				if y >= a.Y and y <= b.Y then
					best = t
				end
			end
		end
	elseif ox * ox + oz * oz <= r * r then
		-- straight up or down inside the cylinder
		local y = origin.Y
		if y >= a.Y and y <= b.Y then
			best = 0
		end
	end
	for _, cap in { a, b } do
		local t = Formulas.rayBall(origin, dir, cap, r, maxDist)
		if t and (not best or t < best) then
			best = t
		end
	end
	if best and best <= maxDist then
		return best
	end
	return nil
end

-- Test a shot against a target standing with its root at `root`. Returns distance, headshot (or nil).
function Formulas.hitTarget(origin, dir, root, maxDist)
	local head = root + Vector3.new(0, Constants.HEAD_OFFSET, 0)
	local th = Formulas.rayBall(origin, dir, head, Constants.HEAD_RADIUS, maxDist)
	local tb = Formulas.rayCapsule(
		origin,
		dir,
		root + Vector3.new(0, Constants.BODY_BOTTOM + Constants.BODY_RADIUS, 0),
		root + Vector3.new(0, Constants.BODY_TOP - Constants.BODY_RADIUS, 0),
		Constants.BODY_RADIUS,
		maxDist
	)
	if th and (not tb or th <= tb + 0.6) then
		return th, true
	end
	if tb then
		return tb, false
	end
	return nil
end

-- Spread: turn a unit direction by up to `degrees` at random (rng gives 0..1 numbers).
function Formulas.spread(dir, degrees, r1, r2)
	if degrees <= 0 then
		return dir
	end
	local up = math.abs(dir.Y) < 0.99 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
	local right = dir:Cross(up).Unit
	local up2 = right:Cross(dir).Unit
	local angle = math.rad(degrees) * math.sqrt(r1)
	local spin = r2 * math.pi * 2
	return (dir * math.cos(angle) + (right * math.cos(spin) + up2 * math.sin(spin)) * math.sin(angle)).Unit
end

-- Angle in degrees between two unit vectors.
function Formulas.angle(a, b)
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

-- Rolling --------------------------------------------------------------------------------------------------
-- Pick from an odds table { { key, percent }, ... } with a 0..1 number.
function Formulas.pickOdds(table_, r)
	local total = 0
	for _, row in table_ do
		total += row[2]
	end
	local x = r * total
	for _, row in table_ do
		x -= row[2]
		if x <= 0 then
			return row[1]
		end
	end
	return table_[#table_][1]
end

-- Open a crate: the skin id. rng has NextNumber() and NextInteger().
function Formulas.rollCrate(rng, crateKey)
	local crate = Cosmetics.crateByKey[crateKey]
	local rarity = Formulas.pickOdds(crate.odds, rng:NextNumber())
	local pool = Cosmetics.crateSkins(rarity)
	return pool[rng:NextInteger(1, #pool)].id
end

-- The odds lines a crate shows: { "Common: 70%", ... } plus the skins in each rarity.
function Formulas.oddsLines(crateKey)
	local out = {}
	for _, row in Cosmetics.crateByKey[crateKey].odds do
		local names = {}
		for _, s in Cosmetics.crateSkins(row[1]) do
			table.insert(names, s.name)
		end
		table.insert(out, `{row[1]}: {row[2]}% ({table.concat(names, ", ")})`)
	end
	return out
end

-- The Daily Shop ----------------------------------------------------------------------------------------------
-- The items for a daily period (7pm ET to 7pm ET): 6 crate skins, 2 pop effects, 2 emotes, the same on every
-- server. Returns { { kind, id, price } }.
function Formulas.dailyShop(period)
	local rng = Random.new(period * 7919 + 17)
	local out = {}
	local function pickFrom(list, n, kind, priceOf)
		local pool = table.clone(list)
		for _ = 1, n do
			if #pool == 0 then
				break
			end
			local item = table.remove(pool, rng:NextInteger(1, #pool))
			table.insert(out, { kind = kind, id = item.id, price = priceOf(item) })
		end
	end
	local skins = {}
	for _, s in Cosmetics.Skins do
		if s.source == "crate" then
			table.insert(skins, s)
		end
	end
	pickFrom(skins, 6, "skin", function(s)
		return Cosmetics.ShopPrice[s.rarity]
	end)
	local effects = {}
	for _, e in Cosmetics.PopEffects do
		if e.id ~= "BRICKS" then
			table.insert(effects, e)
		end
	end
	pickFrom(effects, 2, "effect", function(e)
		return math.floor(Cosmetics.ShopPrice[e.rarity] * 1.5)
	end)
	local emotes = {}
	for _, e in Cosmetics.Emotes do
		if e.id ~= "WAVE" then
			table.insert(emotes, e)
		end
	end
	pickFrom(emotes, 2, "emote", function(e)
		return math.floor(Cosmetics.ShopPrice[e.rarity] * 1.25)
	end)
	return out
end

-- Seasons -----------------------------------------------------------------------------------------------------
-- The season number at a UTC time, and when it ends.
function Formulas.season(utc)
	local len = Constants.SEASON_DAYS * 86400
	local n = math.floor((utc - Constants.SEASON_START) / len) + 1
	return n, Constants.SEASON_START + n * len
end

-- The tier for an amount of season XP (0 to SEASON_TIERS).
function Formulas.seasonTier(xp)
	return math.min(Constants.SEASON_TIERS, math.floor(xp / Constants.SEASON_TIER_XP))
end

-- A season tier's rewards: free = { coins | keys }, pass = { coins | keys | skin | effect | emote }.
local SEASON_SKINS = { "S_ARCTIC", "S_JUNGLE", "S_COMET", "S_STORM", "S_ROYAL" }
local SEASON_EXTRAS = {
	{ effect = "CONFETTI" },
	{ emote = "CHEER" },
	{ effect = "STARS" },
	{ emote = "DANCE" },
	{ effect = "FIRE" },
}
function Formulas.seasonReward(tier)
	local free = tier % 5 == 0 and { keys = 1 } or { coins = 100 + tier * 10 }
	local pass
	if tier % 10 == 0 then
		pass = { skin = SEASON_SKINS[tier // 10] }
	elseif tier % 10 == 5 then
		pass = SEASON_EXTRAS[(tier + 5) // 10]
	elseif tier % 3 == 0 then
		pass = { keys = 1 }
	else
		pass = { coins = 250 + tier * 20 }
	end
	return free, pass
end

-- Days and the daily period -----------------------------------------------------------------------------------
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

return Formulas

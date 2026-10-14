-- The game's maths in one place, shared by the server, the client and the tests: levels, mastery, how hard a night
-- is for how many players at which difficulty, damage after armor, and the time of day for the lighting.
local Constants = require(script.Parent.Constants)

local Formulas = {}

-- Player level from total XP: level, XP into this level, XP this level needs.
function Formulas.level(xp)
	xp = math.max(0, xp or 0)
	local level, need = 1, Constants.LEVEL_XP
	while xp >= need and level < 200 do
		xp -= need
		level += 1
		need = Constants.LEVEL_XP + Constants.LEVEL_XP_GROWTH * (level - 1)
	end
	return level, xp, need
end

-- Total XP needed to reach a level (tests, the UI's bars).
function Formulas.xpForLevel(level)
	local total = 0
	for l = 1, level - 1 do
		total += Constants.LEVEL_XP + Constants.LEVEL_XP_GROWTH * (l - 1)
	end
	return total
end

-- Mastery level (1-10) from mastery XP, and the share of the way to the next level.
function Formulas.mastery(xp)
	xp = xp or 0
	local steps = Constants.MASTERY_XP
	local level = 1
	for i = #steps, 1, -1 do
		if xp >= steps[i] then
			level = i
			break
		end
	end
	if level >= #steps then
		return level, 1
	end
	local a, b = steps[level], steps[level + 1]
	return level, (xp - a) / (b - a)
end

function Formulas.difficulty(index)
	return Constants.DIFFICULTIES[math.clamp(index or 1, 1, #Constants.DIFFICULTIES)]
end

-- How much harder a night gets for this many survivors (§8: adjusts to the active players, within tested limits).
function Formulas.playerScale(players)
	local s = Constants.PLAYER_SCALE
	players = math.max(1, players or 1)
	if players <= #s then
		return s[players]
	end
	return s[#s] + (players - #s) * 0.12
end

-- Threat points a night spends on monsters.
function Formulas.nightBudget(night, players, difficultyIndex)
	local base = Constants.NIGHT_BUDGET[math.clamp(night, 1, #Constants.NIGHT_BUDGET)]
	local d = Formulas.difficulty(difficultyIndex)
	return base * Formulas.playerScale(players) * d.count
end

-- A monster's health and damage for this run (players at the last stage boundary, difficulty, golden or not).
function Formulas.monsterHp(base, players, difficultyIndex, elite)
	local d = Formulas.difficulty(difficultyIndex)
	local scale = 0.7 + 0.3 * Formulas.playerScale(players)
	return math.floor(base * d.hp * scale * (elite and 2.5 or 1) + 0.5)
end

function Formulas.monsterDamage(base, difficultyIndex, elite)
	local d = Formulas.difficulty(difficultyIndex)
	return base * d.dmg * (elite and 1.25 or 1)
end

-- Kermy gets tougher as the nights go on.
-- Kermy hits softer on the first nights (players are still learning his tell) and full strength from night 6.
function Formulas.kermyDamage(base, night, difficultyIndex)
	return Formulas.monsterDamage(base, difficultyIndex, false) * math.min(1, 0.65 + 0.07 * (math.max(1, night) - 1))
end

function Formulas.kermyHp(base, night, players, difficultyIndex)
	return math.floor(Formulas.monsterHp(base, players, difficultyIndex) * (0.6 + 0.12 * night) + 0.5)
end

function Formulas.bossHp(players, difficultyIndex, totem)
	local d = Formulas.difficulty(difficultyIndex)
	local hp = Constants.BOSS_HP * Formulas.playerScale(players) * d.hp
	if totem then
		hp *= 1 - 0.15
	end
	return math.floor(hp + 0.5)
end

-- Damage a survivor takes: armor, a shield brew, the fire being out.
function Formulas.damageTaken(raw, armor, shield, dark)
	local dmg = raw * (1 - math.clamp(armor or 0, 0, 0.8)) * (1 - math.clamp(shield or 0, 0, 0.9))
	if dark then
		dmg *= Constants.DARK_DAMAGE
	end
	return math.max(1, math.floor(dmg + 0.5))
end

-- Seconds into a stage -> the time of day (Lighting.ClockTime) for the sky.
--   day: 7:00 -> 18:00, dusk: 18:00 -> 20:00, night: 20:00 -> 05:00, dawn: 05:00 -> 07:00
function Formulas.clockTime(phase, t, length)
	local f = length and length > 0 and math.clamp(t / length, 0, 1) or 0
	if phase == "day" then
		return 7 + 11 * f
	elseif phase == "dusk" then
		return 18 + 2 * f
	elseif phase == "night" or phase == "boss" then
		return (20 + 9 * f) % 24
	elseif phase == "dawn" then
		return 5 + 2 * f
	end
	return 13
end

-- "1:05", "12:40"
function Formulas.clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- The length of the whole run if every day runs out (for the HUD and the docs).
function Formulas.runLength()
	local total = 0
	for _, s in Constants.DAY_SECONDS do
		total += s + Constants.DUSK_SECONDS
	end
	for _, s in Constants.NIGHT_SECONDS do
		total += s + Constants.DAWN_SECONDS
	end
	return total
end

-- Discovery score points for something found the first time (the "rarest discoveries" board).
local RARITY_POINTS = { common = 1, uncommon = 3, rare = 7, epic = 14, legendary = 25 }
function Formulas.discoveryPoints(rarity)
	return RARITY_POINTS[rarity] or 1
end

-- XP for a finished run (before the cap): what each part is worth.
function Formulas.runXp(r)
	local x = Constants.XP
	local d = Formulas.difficulty(r.difficulty)
	local total = 0
	for n = 1, r.nights or 0 do
		total += x.night * n
	end
	total += (r.objectives or 0) * x.objective
	total += (r.firsts or 0) * x.discovery + (r.repeats or 0) * x.repeatFind
	total += (r.revives or 0) * x.revive
	total += r.killXp or 0
	total += math.floor((r.contributed or 0) * x.contribution)
	if r.won then
		total += x.win * d.xp
	end
	return math.min(x.cap, math.floor(total * (r.won and 1 or 0.85) + 0.5))
end

return Formulas

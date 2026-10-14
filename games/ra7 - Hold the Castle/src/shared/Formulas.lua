-- All the game's math in one place, so the server, the client and the tests agree (and so tuning is one file).
local Constants = require(script.Parent.Constants)
local Jobs = require(script.Parent.Data.Jobs)

local Formulas = {}

-- The match ---------------------------------------------------------------------------------------------------
-- Build time for this many players (fewer players, shorter build).
function Formulas.buildSeconds(players)
	local seconds = Constants.BUILD_SECONDS[1].seconds
	for _, row in Constants.BUILD_SECONDS do
		if players >= row.players then
			seconds = row.seconds
		end
	end
	return seconds
end

-- How many dwarves the plague turns: about 1 in 4 (§5), nobody in a small server (the horde attacks instead).
function Formulas.plagueCount(players)
	if players < Constants.PLAGUE_MIN_PLAYERS then
		return 0
	end
	return math.max(1, math.floor(players * Constants.PLAGUE_SHARE))
end

-- Shrines ----------------------------------------------------------------------------------------------------
-- How a shrine's health changes each second (negative = draining). It drains only while monsters near it
-- outnumber the dwarves near it; it heals slowly while no monster is near.
function Formulas.shrineRate(dwarves, monsters, wards, stage)
	if monsters <= 0 then
		return Constants.SHRINE_REGEN
	end
	local extra = monsters - dwarves
	if extra <= 0 then
		return 0
	end
	local rate = math.min(Constants.SHRINE_DRAIN_MAX, extra * Constants.SHRINE_DRAIN_PER_EXTRA)
	local cut = math.min(wards or 0, Constants.SHRINE_WARDS_MAX) * Constants.SHRINE_WARD_CUT
		+ (Constants.STAGE_DRAIN_CUT[stage or "camp"] or 0)
	return -rate * math.max(0.3, 1 - cut)
end

-- Camp, Town or Castle from the castle points around a shrine.
function Formulas.castleStage(points)
	if points >= Constants.STAGE_POINTS.castle then
		return "castle"
	elseif points >= Constants.STAGE_POINTS.town then
		return "town"
	end
	return "camp"
end

-- The horde -------------------------------------------------------------------------------------------------
-- NPC monsters the horde wants on the field: more dwarves and more time = more monsters; monster players count
-- instead of NPCs.
function Formulas.hordeTarget(minutes, dwarves, monsterPlayers)
	local want = Constants.HORDE_BASE
		+ Constants.HORDE_PER_DWARF * dwarves * (1 + Constants.HORDE_GROWTH * minutes)
		- Constants.HORDE_PER_MONSTER_PLAYER * monsterPlayers
	return math.clamp(math.floor(want + 0.5), Constants.HORDE_MIN, Constants.NPC_MAX)
end

-- Monsters grow stronger: by their own level this match, and by how long the fight has gone on (§9).
function Formulas.monsterLevel(xp)
	local level = 1
	for i, need in Constants.MONSTER_LEVELS do
		if xp >= need then
			level = i
		end
	end
	return level
end

function Formulas.monsterNextXp(level)
	return Constants.MONSTER_LEVELS[level + 1]
end

function Formulas.monsterMult(level, fightMinutes)
	return 1
		+ (level - 1) * Constants.MONSTER_LEVEL_BONUS
		+ math.min(Constants.MONSTER_TIME_BONUS_MAX, math.max(0, fightMinutes) * Constants.MONSTER_TIME_BONUS)
end

-- Can a monster pick this job? Brutes and Witches need monster level 2, or a long enough fight.
function Formulas.jobUnlocked(job, level, fightSeconds)
	if not job or job.team ~= "monster" then
		return false
	end
	return (job.unlock or 1) <= level or fightSeconds >= Constants.MONSTER_UNLOCK_AFTER
end

-- Building ----------------------------------------------------------------------------------------------------
-- Hammer work per hit (a Builder hits twice as hard; a Healer close by adds a quarter).
function Formulas.hammerPower(jobKey, aura)
	local job = Jobs.byKey[jobKey]
	local p = job and job.buildPower or 1
	if aura then
		p *= 1 + Constants.HEALER_AURA
	end
	return p
end

-- Materials one hit puts into a blueprint (Builders carry it in faster too).
function Formulas.depositPerHit(jobKey)
	return jobKey == "builder" and Constants.DEPOSIT_BUILDER or Constants.DEPOSIT_PER_HIT
end

local function total(t)
	local n = 0
	for _, v in t do
		n += v
	end
	return n
end
Formulas.total = total

-- How far the hammering can go with what's been brought so far (work can't run ahead of the materials).
function Formulas.workCap(need, have, work)
	local needed = total(need)
	if needed <= 0 then
		return work
	end
	return work * math.clamp(total(have) / needed, 0, 1)
end

-- What a blueprint still needs: { stone = 2, ... } (only the missing ones).
function Formulas.missing(need, have)
	local out = {}
	for k, n in need do
		local m = n - (have[k] or 0)
		if m > 0 then
			out[k] = m
		end
	end
	return out
end

function Formulas.canAfford(bag, need)
	for k, n in need do
		if (bag[k] or 0) < n then
			return false
		end
	end
	return true
end

-- A blueprint's progress 0..1 (materials and hammering both count).
function Formulas.progress(need, have, work, done)
	local needed = total(need)
	local mat = needed > 0 and math.clamp(total(have) / needed, 0, 1) or 1
	local w = work > 0 and math.clamp(done / work, 0, 1) or 1
	return math.min(mat, w)
end

-- Fighting --------------------------------------------------------------------------------------------------
-- A dwarf's gear this match: damage taken and dealt.
function Formulas.armorMult(tier)
	return 1 - math.clamp(tier or 0, 0, Constants.GEAR_TIERS) * Constants.ARMOR_CUT
end

function Formulas.weaponMult(tier)
	return 1 + math.clamp(tier or 0, 0, Constants.GEAR_TIERS) * Constants.WEAPON_BONUS
end

-- The Grunt's trait: hits harder with other monsters around.
function Formulas.packMult(job, nearby)
	if not job or not job.pack then
		return 1
	end
	return 1 + math.min(job.packMax, job.pack * math.max(0, nearby))
end

-- Is `dir` within a cone of `arc` degrees around `facing`? (both flat Vector3s)
function Formulas.inArc(facing, dir, arc)
	if dir.Magnitude < 1e-3 then
		return true
	end
	local f = Vector3.new(facing.X, 0, facing.Z)
	local d = Vector3.new(dir.X, 0, dir.Z)
	if f.Magnitude < 1e-3 or d.Magnitude < 1e-3 then
		return true
	end
	return f.Unit:Dot(d.Unit) >= math.cos(math.rad(arc / 2))
end

-- Progress between matches -------------------------------------------------------------------------------
-- Level from total XP where level 2 needs `base` and each level after needs `growth` more.
-- Returns level, XP into this level, XP this level needs.
function Formulas.levelFromXp(xp, base, growth)
	local level, need = 1, base
	xp = math.max(0, math.floor(xp or 0))
	while xp >= need and level < 999 do
		xp -= need
		level += 1
		need = base + growth * (level - 1)
	end
	return level, xp, need
end

function Formulas.accountLevel(xp)
	return Formulas.levelFromXp(xp, Constants.LEVEL_XP, Constants.LEVEL_XP_GROWTH)
end

function Formulas.jobLevel(xp)
	return Formulas.levelFromXp(xp, Constants.JOB_LEVEL_XP, Constants.JOB_LEVEL_XP_GROWTH)
end

-- Coins and XP for one player's match. `m`: { team, won, heldSeconds, beaten, dwarvesBeaten, built, broken,
-- shrines, lastDwarf }.
function Formulas.rewards(m)
	local R = Constants.REWARDS
	local coins = R.base
	coins += math.floor((m.heldSeconds or 0) / 60) * R.perMinuteHeld
	coins += (m.beaten or 0) * R.perBeaten + (m.dwarvesBeaten or 0) * R.perBeaten * 3
	coins += (m.built or 0) * R.perBuilt + (m.broken or 0) * R.perBroken
	coins += (m.shrines or 0) * R.shrine
	if m.won then
		coins += m.team == "dwarf" and R.dwarfWin or R.monsterWin
	end
	if m.lastDwarf then
		coins += R.lastDwarf
	end
	coins = math.min(coins, R.cap)
	return coins, math.floor(coins * R.xpPerCoin)
end

-- The daily gift for a login streak (1 = the first day).
function Formulas.dailyGift(streak)
	local list = Constants.DAILY_GIFTS
	return list[((math.max(1, streak) - 1) % #list) + 1]
end

-- "4:05"
function Formulas.clock(seconds)
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Formulas

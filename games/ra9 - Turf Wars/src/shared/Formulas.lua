--[[
The rules as pure functions (no Instances), shared by the server, the client and the tests.

  Formulas.pushCells(players)                 how many cells a kill moves the frontline
  Formulas.sideOf(x, frontline)               "red" | "blue": whose turf this X is
  Formulas.charge(weapon, heldSeconds)        0..1 (the bow's draw)
  Formulas.shot(weapon, charge)               speed, damage, knockback at that charge
  Formulas.arrowAt(origin, velocity, t)       where an arrow is t seconds after it left
  Formulas.lobVelocity(dir, speed)           the TNT's throw: where you look, lifted into a lob
  Formulas.lobAt(origin, velocity, t)         where a thrown TNT is t seconds after it left (heavier than an arrow)
  Formulas.lobAim(origin, target, speed)      the look direction that lobs it onto target at that speed (bots)
  Formulas.blast(distance)                    0..1: how much of the TNT's structure damage reaches that far
  Formulas.boxDistance(p, min, max)           from a point to the nearest point of a box (0 inside)
  Formulas.segmentSphere(a, b, c, r)          the fraction along a→b where it first touches the sphere, or nil
  Formulas.segmentBox(a, b, min, max)         ...the axis-aligned box, or nil
  Formulas.cellOf(x, z) / cellCenter(cx, cz)  the 4-stud building grid
]]
local Constants = require(script.Parent.Constants)

local Formulas = {}

function Formulas.pushCells(players)
	local n = math.max(1, players or 1)
	local cells = math.floor(Constants.PUSH_PLAYERS / n + 0.5)
	return math.clamp(cells, Constants.PUSH_CELLS_MIN, Constants.PUSH_CELLS_MAX)
end

function Formulas.sideOf(x, frontline)
	return x < frontline and "red" or "blue"
end

function Formulas.enemyOf(team)
	return team == "red" and "blue" or "red"
end

-- Which way is "forward" for a team along X (red pushes toward +X, blue toward -X).
function Formulas.forward(team)
	return team == "red" and 1 or -1
end

function Formulas.charge(weapon, held)
	if not weapon then
		return 0
	end
	if weapon.draw <= 0 then
		return 1
	end
	return math.clamp((held or 0) / weapon.draw, weapon.minCharge or 0, 1)
end

local function lerp(range, t)
	return range[1] + (range[2] - range[1]) * t
end

function Formulas.shot(weapon, charge)
	charge = math.clamp(charge or 0, 0, 1)
	return {
		speed = lerp(weapon.speed, charge),
		damage = math.floor(lerp(weapon.damage, charge) + 0.5),
		knockback = weapon.knockback * (0.35 + 0.65 * charge),
	}
end

function Formulas.arrowAt(origin, velocity, t)
	return origin + velocity * t + Vector3.new(0, -0.5 * Constants.GRAVITY * t * t, 0)
end

function Formulas.arrowVelocity(velocity, t)
	return velocity + Vector3.new(0, -Constants.GRAVITY * t, 0)
end

function Formulas.lobVelocity(dir, speed)
	local d = dir + Vector3.new(0, Constants.TNT_LIFT, 0)
	return (d.Magnitude > 1e-6 and d.Unit or Vector3.new(0, 1, 0)) * speed
end

function Formulas.lobAt(origin, velocity, t)
	return origin + velocity * t + Vector3.new(0, -0.5 * Constants.TNT_GRAVITY * t * t, 0)
end

-- The look direction (toward target, pitched) whose lob comes closest to target at this throw speed, by trying
-- pitches from straight ahead to steep: a bot's throw. Returns the direction and how close it lands.
function Formulas.lobAim(origin, target, speed)
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	local yaw = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
	local best, bestMiss
	for deg = -40, 60, 4 do
		local a = math.rad(deg)
		local dir = yaw * math.cos(a) + Vector3.new(0, math.sin(a), 0)
		local v = Formulas.lobVelocity(dir, speed)
		local miss = math.huge
		for i = 1, 40 do
			local p = Formulas.lobAt(origin, v, i * Constants.TNT_FUSE / 40)
			miss = math.min(miss, (p - target).Magnitude)
		end
		if not bestMiss or miss < bestMiss then
			best, bestMiss = dir, miss
		end
	end
	return best, bestMiss
end

function Formulas.blast(d)
	return math.clamp(1 - d / Constants.TNT_RADIUS, 0, 1)
end

function Formulas.boxDistance(p, mn, mx)
	local q = Vector3.new(math.clamp(p.X, mn.X, mx.X), math.clamp(p.Y, mn.Y, mx.Y), math.clamp(p.Z, mn.Z, mx.Z))
	return (p - q).Magnitude
end

-- Segment a→b against a sphere at c, radius r: the first fraction in [0, 1] where it touches, or nil.
function Formulas.segmentSphere(a, b, c, r)
	local d = b - a
	local f = a - c
	local A = d:Dot(d)
	if A < 1e-9 then
		return (f.Magnitude <= r) and 0 or nil
	end
	local B = 2 * f:Dot(d)
	local C = f:Dot(f) - r * r
	if C <= 0 then
		return 0 -- (starts inside)
	end
	local disc = B * B - 4 * A * C
	if disc < 0 then
		return nil
	end
	local s = math.sqrt(disc)
	local t1 = (-B - s) / (2 * A)
	if t1 >= 0 and t1 <= 1 then
		return t1
	end
	return nil
end

-- Segment a→b against an axis-aligned box (slab method): the entry fraction in [0, 1], or nil.
function Formulas.segmentBox(a, b, mn, mx)
	local d = b - a
	local tmin, tmax = 0, 1
	for _, axis in { "X", "Y", "Z" } do
		local o, v, lo, hi = a[axis], d[axis], mn[axis], mx[axis]
		if math.abs(v) < 1e-9 then
			if o < lo or o > hi then
				return nil
			end
		else
			local t1 = (lo - o) / v
			local t2 = (hi - o) / v
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tmin = math.max(tmin, t1)
			tmax = math.min(tmax, t2)
			if tmin > tmax then
				return nil
			end
		end
	end
	return tmin
end

function Formulas.boxesOverlap(aMin, aMax, bMin, bMax)
	return aMin.X < bMax.X
		and aMax.X > bMin.X
		and aMin.Y < bMax.Y
		and aMax.Y > bMin.Y
		and aMin.Z < bMax.Z
		and aMax.Z > bMin.Z
end

function Formulas.cellOf(x, z)
	return math.floor(x / Constants.CELL), math.floor(z / Constants.CELL)
end

function Formulas.cellCenter(cx, cz)
	return (cx + 0.5) * Constants.CELL, (cz + 0.5) * Constants.CELL
end

-- A structure's box on the ground: the min and max corners for cell (cx, cz) with footprint w x d cells at height y.
function Formulas.footprintBox(cx, cz, w, d, y, h)
	local c = Constants.CELL
	return Vector3.new(cx * c, y, cz * c), Vector3.new((cx + w) * c, y + h, (cz + d) * c)
end

-- A win counts toward the ladder when you were on the winning team, in the match long enough, and not idle.
function Formulas.qualifies(info)
	return info ~= nil and info.won == true and (info.seconds or 0) >= Constants.QUALIFY_SECONDS and info.active == true
end

-- The streak badge earned by reaching this streak (3, 5, 10), or nil.
function Formulas.streakBadge(streak)
	for i = #Constants.STREAKS, 1, -1 do
		if streak == Constants.STREAKS[i] then
			return streak
		end
	end
	return nil
end

-- MVP score: the frontline you moved (kills), a share for assists, a little for building.
function Formulas.mvpScore(s)
	return (s.kills or 0) * 10 + (s.assists or 0) * 4 + (s.built or 0) * 1
end

return Formulas

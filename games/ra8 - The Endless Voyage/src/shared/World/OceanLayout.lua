--[[
Where everything is (master plan §5, §9): the ocean, the six plots on a ring round its centre, each with a raft in
the middle and an island zone out from it, and the current that carries debris through.

  OceanLayout.plots            { { index, center, islandCenter, angle, current (unit, across the plot) }, ... }
  OceanLayout.plot(index)
  OceanLayout.plotAt(pos)      the plot a position is in, or nil
  OceanLayout.islandBeside(i, reach, radius)  where a voyage's island rises: right off the raft's outer side
  OceanLayout.HORIZON          the far islands you can see but never reach
  OceanLayout.SPAWN            where a player with no plot yet stands (never happens: a plot for every player)
]]
local Constants = require(script.Parent.Parent.Constants)

local OceanLayout = {}

local V3 = Vector3.new

OceanLayout.plots = {}
for i = 1, Constants.MAX_PLAYERS do
	local a = math.rad((i - 1) * 360 / Constants.MAX_PLAYERS)
	local out = V3(math.cos(a), 0, math.sin(a))
	local center = out * Constants.PLOT_RING
	-- the island comes to the outer side of the plot, so the rafts never look at each other's islands
	local islandCenter = center + out * Constants.ISLAND_OFFSET
	-- debris drifts across the plot, along the ring's tangent
	local current = V3(-out.Z, 0, out.X)
	table.insert(OceanLayout.plots, {
		index = i,
		center = center,
		islandCenter = islandCenter,
		angle = math.deg(a),
		out = out,
		current = current,
	})
end

function OceanLayout.plot(index)
	return OceanLayout.plots[index]
end

function OceanLayout.plotAt(pos)
	local best, bestD
	for _, p in OceanLayout.plots do
		local d = (V3(pos.X, 0, pos.Z) - p.center).Magnitude
		if
			d <= Constants.PLOT_RADIUS + Constants.ISLAND_OFFSET + Constants.ISLAND_RADIUS and (not bestD or d < bestD)
		then
			best, bestD = p, d
		end
	end
	return best
end

-- Where a voyage's island rises beside a plot: somewhere in the plot's island zone, a different spot each time
-- (so the islands you see from your raft are never a neat ring). Always inside plotAt's reach.
-- `clear`: how far out the island must sit to miss a big raft (its edge plus the island's size).
-- Where a voyage's island rises: straight off the raft's outer side, its beach Constants.ISLAND_GAP studs from the
-- edge of the raft (reach: how far the raft goes that way, Formulas.raftReach), so you hop ashore instead of swimming.
-- Open water (an island of radius 0: the Trench) stays further out, where the Leviathan has room.
function OceanLayout.islandBeside(index, reach, radius)
	local p = OceanLayout.plots[index]
	if not p then
		return nil
	end
	local r = radius > 0 and (reach + Constants.ISLAND_GAP + radius) or (reach + 70)
	return V3(p.center.X + p.out.X * r, 0, p.center.Z + p.out.Z * r)
end

-- Far, unreachable islands on the horizon: scattered at random bearings and distances, from the edge of what you
-- can reach to the edge of the water (the ocean has an edge you can't see): { x, z, size, kind, far }
--   kind: "peak" (a mountain, snow on the big ones), "low" (green humps with trees), "atoll" (sand and palms)
--   far: 0 (nearest) .. 1 (the farthest, drawn bigger so it still shows)
OceanLayout.HORIZON = {}
do
	local rng = Random.new(8)
	local inner = Constants.PLOT_RING + Constants.ISLAND_OFFSET + Constants.ISLAND_RADIUS + 140
	local outer = Constants.OCEAN_SIZE / 2 - 70
	local kinds = { "peak", "low", "atoll", "low", "peak", "atoll", "low", "low", "peak" }
	local angles = {}
	local tries = 0
	while #OceanLayout.HORIZON < #kinds and tries < 400 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local clear = true
		for _, b in angles do
			local diff = math.abs((a - b + math.pi) % (math.pi * 2) - math.pi)
			if diff < math.rad(24) then
				clear = false
				break
			end
		end
		if clear then
			table.insert(angles, a)
			local far = rng:NextNumber() ^ 0.7
			local r = inner + (outer - inner) * far
			local k = #OceanLayout.HORIZON + 1
			table.insert(OceanLayout.HORIZON, {
				x = math.cos(a) * r,
				z = math.sin(a) * r,
				size = rng:NextNumber(34, 64) * (0.8 + far * 0.8),
				kind = kinds[k],
				far = far,
			})
		end
	end
end

OceanLayout.SPAWN = V3(0, Constants.DECK_Y + 3, 0)

return OceanLayout

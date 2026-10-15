--[[
Where everything is (master plan §5, §9): the ocean, the six plots on a ring round its centre, each with a raft in
the middle and an island zone out from it, and the current that carries debris through.

  OceanLayout.plots            { { index, center, islandCenter, angle, current (unit, across the plot) }, ... }
  OceanLayout.plot(index)
  OceanLayout.plotAt(pos)      the plot a position is in, or nil
  OceanLayout.SPAWN            where a player with no plot yet stands (never happens: six plots, six players)
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

-- Far, unreachable islands on the horizon (the ocean has an edge you can't see): { x, z, size, kind }
OceanLayout.HORIZON = {}
do
	local rng = Random.new(8)
	for k = 0, 11 do
		local a = math.rad(k * 30 + rng:NextNumber(-8, 8))
		local r = Constants.OCEAN_SIZE / 2 - rng:NextNumber(40, 110)
		table.insert(OceanLayout.HORIZON, {
			x = math.cos(a) * r,
			z = math.sin(a) * r,
			size = rng:NextNumber(40, 90),
			kind = k % 3 == 0 and "peak" or "low",
		})
	end
end

OceanLayout.SPAWN = V3(0, Constants.DECK_Y + 3, 0)

return OceanLayout

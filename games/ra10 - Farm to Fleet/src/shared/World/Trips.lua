--[[
Where a vehicle is during a trip (master plan §7: the server says what goes where and when, every client moves it).
A trip is a list of keyframes in a plot's own frame: { f (0..1 of the trip), x, z, rev? (backing up: it faces the
other way), hide? (off the map: under the ground till the next keyframe) }. Between keyframes a vehicle drives in
a straight line, facing where it's going (or away, backing up); standing still it keeps its last heading.

  van     from its parking spot (nose to the shed): backs out, round to the loading door, backs up to it, loads,
          drives off down the road, comes back up the far lane and parks again (the order pays when it's home)
  truck   a box truck: from its spot in the lot behind the warehouse, down the truck lane, backs up to the
          warehouse's truck door, loads, off down the road, back the same way and backs into its spot
  pickup  the buyer's: comes up the far lane, noses in to the door, loads, backs out and drives away

  Trips.at(plotIndex, kind, f, park?) -> CFrame (world, on the ground), visible
  Trips.PLAN[kind]                    the keyframes (the van's first and last are its parking spot: `park`)
]]
local PlotLayout = require(script.Parent.PlotLayout)

local Trips = {}

local NEAR, FAR = PlotLayout.LANES[1], PlotLayout.LANES[2]
local DOOR = PlotLayout.SPOTS.door
local AWAY = 330 -- how far down the road a vehicle drives before it's gone
local AT_DOOR = DOOR.Z - 7.5 -- a van's middle when its back is at the door
local NOSE_IN = DOOR.Z - 6
local TD = PlotLayout.SPOTS.truckDoor
local LANE = PlotLayout.SPOTS.lane
local AT_TRUCK_DOOR = TD.Z - 7 -- a truck's middle with its back at the warehouse door

-- stylua: ignore start
Trips.PLAN = {
	van = {
		{ f = 0,    park = true },
		{ f = 0.06, x = DOOR.X + 10, z = DOOR.Z - 20, rev = true },
		{ f = 0.11, x = DOOR.X,      z = DOOR.Z - 24 },
		{ f = 0.17, x = DOOR.X,      z = AT_DOOR, rev = true },
		{ f = 0.36, x = DOOR.X,      z = AT_DOOR },
		{ f = 0.43, x = DOOR.X,      z = -112 },
		{ f = 0.47, x = DOOR.X + 12, z = NEAR },
		{ f = 0.58, x = DOOR.X + AWAY, z = NEAR, hide = true },
		{ f = 0.72, x = DOOR.X + AWAY, z = FAR },
		{ f = 0.86, x = DOOR.X + 30, z = FAR },
		{ f = 0.91, x = DOOR.X + 22, z = -112 },
		{ f = 0.97, park = true },
		{ f = 1,    park = true },
	},
	-- a box truck (stage 4): from its spot in the lot (nose to the road), down the lane, backs up to the warehouse's
	-- truck door, loads, out to the road and away; back up the far lane and the truck lane, and backs into its spot
	truck = {
		{ f = 0,    park = true },
		{ f = 0.05, parkX = true,  z = 30 },
		{ f = 0.09, x = LANE,      z = 26 },
		{ f = 0.21, x = LANE,      z = -48 },
		{ f = 0.24, x = TD.X,      z = -50 },
		{ f = 0.28, x = TD.X,      z = AT_TRUCK_DOOR, rev = true },
		{ f = 0.42, x = TD.X,      z = AT_TRUCK_DOOR },
		{ f = 0.45, x = TD.X,      z = -50 },
		{ f = 0.48, x = LANE,      z = -54 },
		{ f = 0.56, x = LANE,      z = -112 },
		{ f = 0.60, x = LANE + 12, z = NEAR },
		{ f = 0.68, x = LANE + AWAY, z = NEAR, hide = true },
		{ f = 0.78, x = LANE + AWAY, z = FAR },
		{ f = 0.86, x = LANE + 8,  z = FAR },
		{ f = 0.89, x = LANE,      z = -112 },
		{ f = 0.95, x = LANE,      z = 28 },
		{ f = 0.97, parkX = true,  z = 28 },
		{ f = 1,    park = true, rev = true },
	},
	pickup = {
		{ f = 0,    x = DOOR.X + AWAY, z = FAR },
		{ f = 0.30, x = DOOR.X + 4,  z = FAR },
		{ f = 0.36, x = DOOR.X,      z = -112 },
		{ f = 0.45, x = DOOR.X,      z = NOSE_IN },
		{ f = 0.65, x = DOOR.X,      z = NOSE_IN },
		{ f = 0.73, x = DOOR.X,      z = -104, rev = true },
		{ f = 0.80, x = DOOR.X + 10, z = NEAR },
		{ f = 1,    x = DOOR.X + AWAY, z = NEAR },
	},
}
-- stylua: ignore end

local function spot(k, park)
	if k.park then
		return park or PlotLayout.SPOTS.parks[1]
	elseif k.parkX then
		return Vector3.new((park or PlotLayout.SPOTS.parks[1]).X, 0, k.z)
	end
	return Vector3.new(k.x, 0, k.z)
end

-- The heading at keyframe i: the way it drives on the leg into i (or out of it, at the first)
local function heading(plan, i, park)
	local here = spot(plan[i], park)
	for j = i - 1, 1, -1 do
		local d = here - spot(plan[j], park)
		if d.Magnitude > 0.1 then
			return plan[i].rev and -d.Unit or d.Unit
		end
	end
	for j = i + 1, #plan do
		local d = spot(plan[j], park) - here
		if d.Magnitude > 0.1 then
			return plan[j].rev and -d.Unit or d.Unit
		end
	end
	return Vector3.new(0, 0, 1)
end

function Trips.local_(kind, f, park)
	local plan = Trips.PLAN[kind] or Trips.PLAN.pickup
	f = math.clamp(f, 0, 1)
	for i = 2, #plan do
		local a, b = plan[i - 1], plan[i]
		if f <= b.f then
			local pa, pb = spot(a, park), spot(b, park)
			local k = b.f > a.f and (f - a.f) / (b.f - a.f) or 1
			local pos = pa:Lerp(pb, k)
			local d = pb - pa
			local look
			if d.Magnitude > 0.1 then
				look = b.rev and -d.Unit or d.Unit
			else
				look = heading(plan, i - 1, park)
			end
			if a.park and b.park then
				look = Vector3.new(0, 0, 1) -- (parked: nose to the shed)
			end
			return pos, look, not a.hide
		end
	end
	local last = plan[#plan]
	return spot(last, park), heading(plan, #plan, park), true
end

function Trips.at(plotIndex, kind, f, park)
	local pos, look, visible = Trips.local_(kind, f, park)
	local frame = PlotLayout.frame(plotIndex)
	local wpos = frame * pos
	local wlook = frame:VectorToWorldSpace(look)
	if not visible then
		wpos -= Vector3.new(0, 60, 0)
	end
	return CFrame.lookAt(wpos, wpos + wlook), visible
end

return Trips

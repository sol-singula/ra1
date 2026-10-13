-- Where everything on the train is, shared by the server (builders, services) and the client (travel scenery,
-- tutorial arrows). The train never moves: it stands on the track along the X axis with its front at +X, and the
-- world around it changes (the station, the stops, the travel scenery). Doors and platforms are on the +Z side.
--
-- Cars, front to back: the locomotive (engine room and cab), the crew car (crew board, workshop, entry seats), then
-- five cabin cars with four cabins each. Every car has a vestibule at each end with an outside door; cabins open
-- onto a corridor along the -Z side.
local Layout = {}

Layout.FLOOR_Y = 4 -- top of every car floor, and of every platform
Layout.CAR_W = 26 -- outside width
Layout.HALF_IN = 12 -- inside: z from -12 to +12
Layout.CEIL_Y = 17 -- inside ceiling
Layout.ROOF_Y = 19.6 -- top of the roof
Layout.GAP = 3 -- gangway between cars
Layout.DOOR_W = 5
Layout.DOOR_H = 9
Layout.VESTIBULE = 6
Layout.CORRIDOR_Z = -6 -- cabins are from z = -6 to +12; the corridor from -12 to -6
Layout.CABIN_LEN = 14
Layout.PLATFORM_Z0 = 13.5 -- platform edge (just off the car side)
Layout.PLATFORM_Z1 = 24

Layout.CARS = {
	{ key = "engine", kind = "loco", length = 60, name = "Engine" },
	{ key = "crew", kind = "crew", length = 64, name = "Crew Car" },
	{ key = "A", kind = "cabin", length = 68, name = "Car A" },
	{ key = "B", kind = "cabin", length = 68, name = "Car B" },
	{ key = "C", kind = "cabin", length = 68, name = "Car C" },
	{ key = "D", kind = "cabin", length = 68, name = "Car D" },
	{ key = "E", kind = "cabin", length = 68, name = "Car E" },
}

local total = 0
for i, car in Layout.CARS do
	total += car.length
	if i > 1 then
		total += Layout.GAP
	end
end
Layout.LENGTH = total
Layout.FRONT_X = total / 2
Layout.BACK_X = -total / 2

Layout.byKey = {}
Layout.cabins = {} -- [1..20] = { index, car, cf, doorCf, plateCf, center }
Layout.doors = {} -- { car, cf (the door opening's centre, facing +Z), x }

local x = Layout.FRONT_X
local cabinIndex = 0
for _, car in Layout.CARS do
	car.x1 = x -- front end
	car.x0 = x - car.length -- rear end
	car.cx = (car.x0 + car.x1) / 2
	car.cf = CFrame.new(car.cx, Layout.FLOOR_Y, 0)
	Layout.byKey[car.key] = car
	x = car.x0 - Layout.GAP

	-- outside doors (in the vestibules; the locomotive has one at its rear)
	local doorXs = car.kind == "loco" and { car.x0 + 4 } or { car.x1 - Layout.VESTIBULE / 2, car.x0 + Layout.VESTIBULE / 2 }
	for _, dx in doorXs do
		table.insert(Layout.doors, {
			car = car.key,
			x = dx,
			cf = CFrame.new(dx, Layout.FLOOR_Y + Layout.DOOR_H / 2, Layout.CAR_W / 2),
		})
	end

	-- cabins: four per cabin car, numbered from the front of the train
	if car.kind == "cabin" then
		car.cabins = {}
		for j = 0, 3 do
			cabinIndex += 1
			local cx = car.x1 - Layout.VESTIBULE - Layout.CABIN_LEN / 2 - j * Layout.CABIN_LEN
			local center = Vector3.new(cx, Layout.FLOOR_Y, (Layout.CORRIDOR_Z + Layout.HALF_IN) / 2)
			local cabin = {
				index = cabinIndex,
				car = car.key,
				number = cabinIndex,
				cf = CFrame.new(center), -- local +Z toward the window, -Z toward the corridor door
				center = center,
				-- standing just inside the door, facing the window
				insideCf = CFrame.new(center + Vector3.new(0, 3, -6)) * CFrame.Angles(0, math.pi, 0),
				-- the door sign on the corridor side
				plateCf = CFrame.new(cx + 3.6, Layout.FLOOR_Y + 6.2, Layout.CORRIDOR_Z - 0.55),
			}
			Layout.cabins[cabinIndex] = cabin
			table.insert(car.cabins, cabin)
		end
	end
end

-- Notable spots
local crew = Layout.byKey.crew
local engine = Layout.byKey.engine
-- late joiners and respawns without a bunk arrive on the entry seats in the crew car
Layout.ENTRY_CF = CFrame.new(crew.x0 + 16, Layout.FLOOR_Y + 3, -4) * CFrame.Angles(0, -math.pi / 2, 0)
-- the train upgrades board in the engine room (faces -X, toward the crew car)
Layout.UPGRADE_BOARD_CF = CFrame.new(engine.x0 + 22, Layout.FLOOR_Y + 6.5, -11.4)
Layout.ENGINE_ROOM_CF = CFrame.new(engine.x0 + 10, Layout.FLOOR_Y + 3, 0) * CFrame.Angles(0, -math.pi / 2, 0)
Layout.CREW_BOARD_CF = CFrame.new(crew.cx, Layout.FLOOR_Y + 6.5, -11.4)

-- the station (StationBuilder) and where people arrive in it
Layout.STATION_SPAWN = CFrame.new(0, Layout.FLOOR_Y + 3, 70)
-- the recovery shelter, far from everything (RecoveryBuilder)
Layout.RECOVERY_ORIGIN = CFrame.new(0, 0, -1600)

-- Is a world position inside the train (any car or gangway)?
function Layout.inTrain(pos)
	return pos.X >= Layout.BACK_X - 0.5
		and pos.X <= Layout.FRONT_X + 0.5
		and math.abs(pos.Z) <= Layout.HALF_IN + 0.8
		and pos.Y >= Layout.FLOOR_Y - 2
		and pos.Y <= Layout.CEIL_Y + 2
end

-- The car a position is in (or nil).
function Layout.carAt(pos)
	if not Layout.inTrain(pos) then
		return nil
	end
	for _, car in Layout.CARS do
		if pos.X >= car.x0 - Layout.GAP / 2 and pos.X <= car.x1 + Layout.GAP / 2 then
			return car
		end
	end
	return nil
end

-- The cabin a position is in (or nil).
function Layout.cabinAt(pos)
	for _, cabin in Layout.cabins do
		local p = cabin.center
		if math.abs(pos.X - p.X) <= Layout.CABIN_LEN / 2 and pos.Z >= Layout.CORRIDOR_Z and pos.Z <= Layout.HALF_IN + 0.5 and math.abs(pos.Y - (Layout.FLOOR_Y + 3)) < 6 then
			return cabin
		end
	end
	return nil
end

-- The nearest outside door to a position.
function Layout.nearestDoor(pos)
	local best, bestD
	for _, d in Layout.doors do
		local dist = (d.cf.Position - pos).Magnitude
		if not best or dist < bestD then
			best, bestD = d, dist
		end
	end
	return best, bestD
end

return Layout

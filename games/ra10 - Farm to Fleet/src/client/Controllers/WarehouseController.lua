--[[
The warehouse on screen (master plan §7, §13.1): every forklift on the street works its loop while its warehouse is
busy (the server only says Busy, Speed and how many rack rows there are): from its spot to the staging floor, picks
up a pallet, down the cross aisle and along a rack row's aisle, turns to the rack, lifts the pallet to its level,
lowers the forks and comes back; idle, it waits in its spot. A warehouse's roof (parts marked Roof, with their Plot)
disappears while
the camera is inside it, so you see the racks and forklifts from above.

  WarehouseController.working()   how many forklifts are on their loop
  WarehouseController.roofHidden() how many roof parts are hidden now
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)

local WarehouseController = { Name = "WarehouseController", Order = 43, SCAN = 2, SPEED = 9, LIFT = 1.2 }

local forklifts, roofs, lastScan = {}, {}, -math.huge
local loops = {} -- [model] = the loop it's on
local carriage = {} -- [model] = { { part, offset } }: the carriage and load parts, relative to the pivot
local hidden = {} -- [part] = true while hidden
local working = 0

function WarehouseController.working()
	return working
end

function WarehouseController.roofHidden()
	local n = 0
	for _ in hidden do
		n += 1
	end
	return n
end

local function scan()
	table.clear(forklifts)
	table.clear(roofs)
	local folder = workspace:FindFirstChild("Farms")
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d.Name == "Forklift" and d:IsA("Model") then
			table.insert(forklifts, d)
		elseif d:IsA("BasePart") and d:GetAttribute("Roof") then
			table.insert(roofs, d)
		end
	end
end

-- A loop for a forklift: waypoints (local to its plot) with what happens at each
local function newLoop(m)
	local rows = math.max(1, m:GetAttribute("Rows") or 1)
	local row = math.random(1, rows)
	local per = math.floor((PlotLayout.RACK_X[2] - PlotLayout.RACK_X[1]) / PlotLayout.SLOT)
	local slot = PlotLayout.rackSlot(row, math.random(1, per * PlotLayout.LEVELS))
	local az = PlotLayout.aisle(row)
	local home = m:GetAttribute("Home") or Vector3.new(64, 0.5, -28)
	local face = slot.Z > az and 1 or -1
	return {
		i = 1,
		t = 0,
		points = {
			{ pos = Vector3.new(57, 0.5, -24.5), face = Vector3.new(0, 0, -1), pick = true },
			{ pos = Vector3.new(64, 0.5, -20) },
			{ pos = Vector3.new(64, 0.5, az) },
			{ pos = Vector3.new(slot.X, 0.5, az) },
			{ pos = Vector3.new(slot.X, 0.5, az), face = Vector3.new(0, 0, face), lift = slot.Y - 0.5 },
			{ pos = Vector3.new(64, 0.5, az), drop = true },
			{ pos = Vector3.new(home.X, 0.5, home.Z) },
		},
		at = Vector3.new(home.X, 0.5, home.Z),
		look = Vector3.new(1, 0, 0),
		height = 0,
		carrying = false,
	}
end

local function rememberCarriage(m)
	local list = {}
	local pivot = m:GetPivot()
	for _, part in m:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "Carriage" or part.Name == "Load") then
			table.insert(list, { part = part, offset = pivot:ToObjectSpace(part.CFrame) })
		end
	end
	carriage[m] = list
	return list
end

local function place(m, plotIndex, loop)
	local frame = PlotLayout.frame(plotIndex)
	local wpos = frame * loop.at
	local wlook = frame:VectorToWorldSpace(loop.look)
	local cf = CFrame.lookAt(wpos - Vector3.new(0, 0.5, 0), wpos - Vector3.new(0, 0.5, 0) + wlook)
	m:PivotTo(cf)
	for _, c in carriage[m] or rememberCarriage(m) do
		c.part.CFrame = cf * CFrame.new(0, loop.height, 0) * c.offset
		if c.part.Name == "Load" then
			c.part.Transparency = loop.carrying and 0 or 1
		end
	end
end

local function step(m, dt)
	local plotIndex = m:GetAttribute("Plot")
	if type(plotIndex) ~= "number" then
		return
	end
	if not carriage[m] then
		rememberCarriage(m)
	end
	local busy = m:GetAttribute("Busy") == true
	local loop = loops[m]
	if not loop then
		if not busy then
			return
		end
		loop = newLoop(m)
		loops[m] = loop
	end
	working += 1
	local speed = WarehouseController.SPEED * (m:GetAttribute("Speed") or 1)
	local target = loop.points[loop.i]
	if target.lift then
		-- up to the slot, then down again
		loop.t += dt * (m:GetAttribute("Speed") or 1)
		local k = loop.t / WarehouseController.LIFT
		loop.look = target.face
		loop.height = k < 1 and target.lift * k or target.lift * math.max(0, 2 - k)
		if k >= 1 then
			loop.carrying = false
		end
		if k >= 2 then
			loop.t, loop.height = 0, 0
			loop.i += 1
		end
	else
		local to = target.pos - loop.at
		local d = Vector3.new(to.X, 0, to.Z)
		local move = speed * dt
		if d.Magnitude <= move then
			loop.at = target.pos
			if target.face then
				loop.look = target.face
			end
			if target.pick then
				loop.carrying = true
			end
			loop.i += 1
		else
			loop.look = d.Unit
			loop.at += d.Unit * move
		end
	end
	if loop.i > #loop.points then
		loops[m] = nil
		if busy then
			loops[m] = newLoop(m)
			loops[m].at = loop.at
		end
	end
	place(m, plotIndex, loops[m] or loop)
end

local function roofsFor(cam)
	local camPos = cam.CFrame.Position
	local seen = {}
	for _, part in roofs do
		if part.Parent then
			-- (inside the warehouse this roof covers: within its walls, under its roof)
			local plotIndex = part:GetAttribute("Plot")
			local inside = false
			local frame = plotIndex and PlotLayout.frame(plotIndex)
			if frame then
				local l = frame:PointToObjectSpace(camPos)
				local s = PlotLayout.SLICES
				inside = l.X > 6 and l.X < 70 and l.Z > s[1] and l.Z < s[#s] and l.Y < PlotLayout.WAREHOUSE.Y + 1
			end
			if inside then
				seen[part] = true
				if not hidden[part] then
					hidden[part] = part.Transparency
					part.Transparency = 1
				end
			end
		end
	end
	for part, was in hidden do
		if not seen[part] then
			part.Transparency = was
			hidden[part] = nil
		end
	end
end

function WarehouseController:init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		local step_dt = acc
		acc = 0
		if os.clock() - lastScan >= WarehouseController.SCAN then
			lastScan = os.clock()
			scan()
		end
		working = 0
		for _, m in forklifts do
			if m.Parent then
				step(m, step_dt)
			end
		end
		local cam = workspace.CurrentCamera
		if cam then
			roofsFor(cam)
		end
	end)
end

return WarehouseController

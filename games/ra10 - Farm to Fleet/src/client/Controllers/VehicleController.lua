--[[
The vehicles on the street (master plan §7): the server marks a trip on a vehicle (TripStart, TripLength, Trip:
its kind) and every client drives it along World/Trips' plan for that kind (or its Plan), smoothly, at 30 fps; a van or a box
truck with no trip waits in its spot (ParkAt, or the van's Park). Any plot's vehicles, so neighbours watch each
other's trucks come and go.

  VehicleController.moving()  how many vehicles are on a trip right now
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Trips = require(ReplicatedStorage.Shared.World.Trips)

local VehicleController = { Name = "VehicleController", Order = 42, SCAN = 2 }

local vehicles, lastScan = {}, -math.huge
local moving = 0

local function scan()
	table.clear(vehicles)
	local folder = workspace:FindFirstChild("Farms")
	if not folder then
		return
	end
	for _, d in folder:GetDescendants() do
		if d.Name == "Vehicle" and d:IsA("Model") then
			table.insert(vehicles, d)
		end
	end
end

function VehicleController.moving()
	return moving
end

local function drive()
	local now = workspace:GetServerTimeNow()
	moving = 0
	for _, m in vehicles do
		local plot = m:GetAttribute("Plot")
		if not m.Parent or type(plot) ~= "number" then
			continue
		end
		local kind = m:GetAttribute("Kind") or "pickup"
		local plan = m:GetAttribute("Plan") or kind -- (a truck's route changes when the hub's back docks open)
		local park = m:GetAttribute("Park")
		local spot = m:GetAttribute("ParkAt") or (park and PlotLayout.SPOTS.parks[park]) or nil
		local start, length = m:GetAttribute("TripStart"), m:GetAttribute("TripLength")
		if type(start) == "number" and type(length) == "number" and length > 0 then
			local f = (now - start) / length
			m:PivotTo((Trips.at(plot, plan, f, spot)))
			moving += 1
		elseif spot and kind ~= "pickup" and not m:GetAttribute("Parked") then
			m:PivotTo((Trips.at(plot, plan, 1, spot)))
			m:SetAttribute("Parked", true)
		end
		if type(start) == "number" then
			m:SetAttribute("Parked", nil)
		end
	end
end

function VehicleController:init()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / 30 then
			return
		end
		acc = 0
		if os.clock() - lastScan >= VehicleController.SCAN then
			lastScan = os.clock()
			scan()
		end
		drive()
	end)
end

return VehicleController

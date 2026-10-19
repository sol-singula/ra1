--[[
Trucks and the forklift (master plan §6, §12): scripted, lightweight. On Net "Truck" the next parked truck backs
off its dock, drives down the lane to the avenue, and comes back twenty seconds later. The forklift shuttles
between the pallets and the dock all day. Nothing here is simulated on the server.

  LogisticsController.trips()   trucks on the road right now (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)

local LogisticsController = { Name = "LogisticsController", Order = 46, TRIP = 20 }

local trips = {} -- [model] = { t0, home = CFrame }

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

local function buildings()
	local i = territoryIndex()
	local m = i and workspace:FindFirstChild("Territories") and workspace.Territories:FindFirstChild("T" .. i)
	return m and m:FindFirstChild("Buildings") or nil, i
end

function LogisticsController.trips()
	local n = 0
	for _ in trips do
		n += 1
	end
	return n
end

function LogisticsController:init()
	Net.listen("Truck", function(m)
		local b, i = buildings()
		local trucks = b and b:FindFirstChild("Trucks")
		if not trucks then
			return
		end
		local idle
		for _, t in trucks:GetChildren() do
			if not trips[t] then
				idle = t
				break
			end
		end
		if idle and idle.PrimaryPart then
			trips[idle] = { t0 = os.clock(), home = idle.PrimaryPart.CFrame, i = i }
		end
		_ = m
	end)
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for model, trip in trips do
			if not model.Parent then
				trips[model] = nil
			else
				local k = (t - trip.t0) / LogisticsController.TRIP
				if k >= 1 then
					model:PivotTo(trip.home)
					trips[model] = nil
				else
					-- down the lane to the avenue (the first half), and back (the second)
					local lane = Layout.SPOTS.lane
					local far = Layout.toWorld(trip.i, lane.x, -Layout.DEPTH / 2 - 10, 0)
					local home = trip.home.Position
					local pos
					if k < 0.5 then
						pos = home:Lerp(far, k * 2)
						model:PivotTo(CFrame.lookAt(pos, far) * CFrame.new(0, 0, 0))
					else
						pos = far:Lerp(home, (k - 0.5) * 2)
						model:PivotTo(CFrame.lookAt(pos, home))
					end
				end
			end
		end
		-- the forklift
		local b, i = buildings()
		local fork = b and b:FindFirstChild("Forklift")
		if fork and fork.PrimaryPart and i then
			local w = Layout.SPOTS.warehouse
			local a = Layout.toWorld(i, w.x - 14, w.z - 8, 0.3)
			local c = Layout.toWorld(i, w.x + 18, w.z + 4, 0.3)
			local phase = (t * 0.25) % 2
			local pos = phase < 1 and a:Lerp(c, phase) or c:Lerp(a, phase - 1)
			local look = phase < 1 and c or a
			fork:PivotTo(CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z)))
		end
	end)
end

return LogisticsController

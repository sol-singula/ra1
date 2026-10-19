--[[
The machines at work (master plan §5): the server's harvester is a number (tiles a minute); on the client the
machine in the shed drives to every tile the server says it cleared (Net "Harvested" by "machine"), so the player
watches it work across the whole farm. The fleet's second machine takes every other tile. The trucks: on
Net "Truck" one drives from its dock down the lane to the avenue and back (LogisticsController).

  MachineController.at()   where the machine is heading (a tile id), or nil
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)

local MachineController = { Name = "MachineController", Order = 45, SPEED = 14 }

local targets = { nil, nil } -- [1 | 2] = { pos, id }
local positions = {} -- [1 | 2] = Vector3 where the model is
local which = 1

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

local function models()
	local i = territoryIndex()
	local m = i and workspace:FindFirstChild("Territories") and workspace.Territories:FindFirstChild("T" .. i)
	local shed = m and m:FindFirstChild("Buildings") and m.Buildings:FindFirstChild("Shed")
	if not shed then
		return nil, nil
	end
	return shed:FindFirstChild("Machine"), shed:FindFirstChild("Machine2")
end

function MachineController.at()
	return targets[1] and targets[1].id or nil
end

function MachineController:init()
	Net.listen("Harvested", function(h)
		if type(h) ~= "table" or h.by ~= "machine" then
			return
		end
		local i = territoryIndex()
		if not i then
			return
		end
		local _, second = models()
		local n = second and which or 1
		which = which == 1 and 2 or 1
		targets[n] = { pos = Layout.toWorld(i, h.x, h.z, 0), id = h.tile }
	end)
	RunService.Heartbeat:Connect(function(dt)
		local first, second = models()
		for n, model in { first, second } do
			if model and model.PrimaryPart then
				local t = targets[n]
				local pos = positions[n] or model.PrimaryPart.Position * Vector3.new(1, 0, 1)
				if t then
					local to = t.pos
					local d = to - pos
					local flat = Vector3.new(d.X, 0, d.Z)
					if flat.Magnitude > 0.5 then
						local stepLen = math.min(flat.Magnitude, MachineController.SPEED * dt)
						pos = pos + flat.Unit * stepLen
						model:PivotTo(CFrame.lookAt(pos, pos + flat.Unit))
					end
				end
				positions[n] = pos
			end
		end
	end)
end

return MachineController

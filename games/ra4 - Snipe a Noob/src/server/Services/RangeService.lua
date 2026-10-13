-- The shooting range in the lobby: walk past the firing line and you're in first person with your rifle; six
-- targets stand in the field. Pop one and it pops back up 2 seconds later. Players on the range can't pop each
-- other. Practice only: no coins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local RobotBuilder = require(script.Parent.Parent.World.RobotBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RangeService = {
	Name = "RangeService",
	Dependencies = { "CombatService" },
	targets = {},
	TargetPopped = Signal.new("RangeService.TargetPopped"), -- (player, headshot)
}

local combat

function RangeService:Init(registry)
	combat = registry.CombatService
	local layout = WorldBuilder.layout
	combat.zones.range = {
		targetsOnly = true,
		respawnSeconds = 2,
		geometry = function()
			return { layout.model }
		end,
		spawn = function(f)
			if f.robot then
				return CFrame.lookAt(f.home, f.home - Vector3.zAxis)
			end
			return CFrame.new(layout.range.spawn + Vector3.new(0, 3, 0))
		end,
		onPop = function(killer, victim, info)
			if killer and not killer.robot and victim.robot then
				Net.fire(killer, "Toast", info.headshot and "🎯 Bullseye!" or "Nice shot!", "good")
				self.TargetPopped:Fire(killer, info.headshot)
			end
		end,
	}
	local folder = workspace:FindFirstChild("Robots") or workspace
	for i, pos in layout.range.targets do
		local home = pos + Vector3.new(0, 3, 0)
		local model = RobotBuilder.build(tostring(i), "dummy", CFrame.lookAt(home, home - Vector3.zAxis))
		model:SetAttribute("Zone", "range")
		model.Parent = folder
		local t = {
			robot = true,
			dummy = true,
			id = -i,
			name = "Target",
			model = model,
			root = model.PrimaryPart,
			zone = "range",
			home = home,
		}
		self.targets[i] = t
		combat:AddRobot(t)
	end
end

function RangeService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		for _, p in Players:GetPlayers() do
			local r = combat.root(p)
			local z = combat.zone(p)
			if r and not combat.isPopped(p) then
				local inRange = WorldBuilder.inRange(r.Position)
				if z == "lobby" and inRange then
					combat.setZone(p, "range")
				elseif z == "range" and not inRange then
					combat.setZone(p, "lobby")
				end
			end
		end
	end)
end

return RangeService

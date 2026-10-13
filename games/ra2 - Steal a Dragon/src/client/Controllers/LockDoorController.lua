-- Locked bases: the server makes each locked gate's red laser solid for everyone. The owner and their friends are
-- listed in the laser's AllowedUsers attribute (",id,id,"), so on their own screen the laser stays walk-through and
-- they can get in and out of their own locked base.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local LockDoorController = { Name = "LockDoorController", Order = 62 }

local function allowed(laser)
	local list = laser:GetAttribute("AllowedUsers")
	return type(list) == "string" and string.find(list, "," .. player.UserId .. ",", 1, true) ~= nil
end

local function fix(laser)
	if laser.CanCollide and allowed(laser) then
		laser.CanCollide = false
	end
end

function LockDoorController.watch(laser)
	if laser:GetAttribute("DoorWatched") then
		return
	end
	laser:SetAttribute("DoorWatched", true)
	fix(laser)
	laser:GetPropertyChangedSignal("CanCollide"):Connect(function()
		fix(laser)
	end)
	laser:GetAttributeChangedSignal("AllowedUsers"):Connect(function()
		-- no longer allowed (you left the team): the server's value comes back with the next lock change
		fix(laser)
	end)
end

function LockDoorController:init()
	task.spawn(function()
		local folder = workspace:WaitForChild("Bases", 30)
		if not folder then
			return
		end
		local function scan(base)
			local laser = base:WaitForChild("Laser", 10)
			if laser and laser:IsA("BasePart") then
				LockDoorController.watch(laser)
			end
		end
		for _, base in folder:GetChildren() do
			task.spawn(scan, base)
		end
		folder.ChildAdded:Connect(scan)
	end)
end

return LockDoorController

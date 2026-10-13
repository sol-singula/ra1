-- A player's real avatar, dancing: on top of a leaderboard (that board's #1) and on the podium (the last round's
-- top 3). Built from their user id, so it works when they're not in the server. Loading the avatar can take a
-- moment, so it happens in the background; a newer request for the same spot wins.
local Players = game:GetService("Players")

local AvatarStatue = {}

-- Roblox's own /e dance animations (R15)
AvatarStatue.DANCES = { "rbxassetid://507771019", "rbxassetid://507776043", "rbxassetid://507777268" }

local tokens = {} -- [spot name] = latest request

local function dance(model, animId)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play()
end

-- Put `userId`'s avatar at `cf` (feet on the spot, facing its look) inside `folder`, named `spot`. nil clears it.
function AvatarStatue.place(folder, spot, userId, cf, animId)
	local old = folder:FindFirstChild(spot)
	if old then
		old:Destroy()
	end
	local token = {}
	tokens[spot] = token
	if not userId or userId <= 0 then
		return
	end
	task.spawn(function()
		local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
		if not ok or not model or tokens[spot] ~= token then
			if ok and model then
				model:Destroy()
			end
			return
		end
		model.Name = spot
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
			end
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		if root then
			root.Anchored = true
		end
		local hip = (hum and hum.HipHeight or 2) + (root and root.Size.Y / 2 or 1)
		model:PivotTo(cf * CFrame.new(0, hip, 0))
		model.Parent = folder
		pcall(dance, model, animId or AvatarStatue.DANCES[1])
	end)
end

return AvatarStatue

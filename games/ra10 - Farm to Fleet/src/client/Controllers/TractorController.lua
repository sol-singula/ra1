--[[
The tractors on screen (TractorService): each one driving itself goes From → To between Depart and Arrive (model
attributes), turned the way it's going, a little bounce on the way; the one you're riding sits under you every frame,
and jumping gets you off (Net "Tractor" "off").

  TractorController.driving()   true while you ride yours
  TractorController.step()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local TractorController = { Name = "TractorController", Order = 45, SCAN = 2, SIT = "rbxassetid://2506281703" }

local player = Players.LocalPlayer
local tractors = {}
local lastScan = -math.huge
local seated = nil -- { track, animate } while you ride: the sit pose, and the walk animations switched off

-- Riding: sit, don't walk (the character's Animate script is paused and a sit pose plays)
local function sit(on)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if on and not seated and hum then
		seated = {}
		local animate = c:FindFirstChild("Animate")
		if animate then
			animate.Disabled = true
			seated.animate = animate
		end
		pcall(function()
			local animator = hum:FindFirstChildOfClass("Animator") or hum
			for _, t in animator:GetPlayingAnimationTracks() do
				t:Stop(0.1)
			end
			local anim = Instance.new("Animation")
			anim.AnimationId = TractorController.SIT
			seated.track = animator:LoadAnimation(anim)
			seated.track.Looped = true
			seated.track.Priority = Enum.AnimationPriority.Action
			seated.track:Play(0.15)
		end)
	elseif not on and seated then
		pcall(function()
			if seated.track then
				seated.track:Stop(0.15)
			end
		end)
		if seated.animate then
			seated.animate.Disabled = false
		end
		seated = nil
	end
end

function TractorController.seated()
	return seated ~= nil
end

function TractorController.driving()
	for _, m in tractors do
		if m.Parent and m:GetAttribute("Driver") == player.UserId then
			return true
		end
	end
	return false
end

local function scan()
	table.clear(tractors)
	local farms = workspace:FindFirstChild("Farms")
	for _, plot in farms and farms:GetChildren() or {} do
		local items = plot:FindFirstChild("Items")
		local folder = items and items:FindFirstChild("tractor")
		local m = folder and folder:FindFirstChild("Tractor")
		if m then
			table.insert(tractors, m)
		end
	end
end

function TractorController.step()
	local t = workspace:GetServerTimeNow()
	sit(TractorController.driving())
	for _, m in tractors do
		if not m.Parent then
			continue
		end
		local driver = m:GetAttribute("Driver")
		if driver == player.UserId then
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if root then
				local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
				local ground = Vector3.new(root.Position.X, m:GetPivot().Position.Y, root.Position.Z)
				m:PivotTo(look.Magnitude > 0.01 and CFrame.lookAt(ground, ground + look.Unit) or CFrame.new(ground))
			end
		elseif (driver or 0) == 0 then
			local from, to = m:GetAttribute("From"), m:GetAttribute("To")
			local depart, arrive = m:GetAttribute("Depart"), m:GetAttribute("Arrive")
			if typeof(from) == "Vector3" and typeof(to) == "Vector3" and depart and arrive then
				local k = arrive > depart and math.clamp((t - depart) / (arrive - depart), 0, 1) or 1
				local at = from:Lerp(to, k)
				local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
				local bounce = k < 1 and math.abs(math.sin(t * 9)) * 0.08 or 0
				local pos = Vector3.new(at.X, from.Y + bounce, at.Z)
				m:PivotTo(dir.Magnitude > 0.01 and CFrame.lookAt(pos, pos + dir.Unit) or CFrame.new(pos))
			end
		end
	end
end

function TractorController:init()
	RunService.RenderStepped:Connect(function()
		if os.clock() - lastScan >= TractorController.SCAN then
			lastScan = os.clock()
			scan()
		end
		TractorController.step()
	end)
	local jump = UserInputService.JumpRequest
	if jump then
		jump:Connect(function()
			if TractorController.driving() then
				Net.send("Tractor", "off")
			end
		end)
	end
end

return TractorController

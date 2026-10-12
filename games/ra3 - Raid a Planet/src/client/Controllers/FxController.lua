-- Look and feel on the client: bugs flap their wings, the portal ring and the planet orbs in the Hub turn,
-- far planets drift, the blaster's tip pulses, and the camera shakes a little when you're knocked down.
-- Only things within range of the camera are animated, so 30-player servers stay smooth.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local FxController = { Name = "FxController", Order = 50 }

local RANGE = 120
local wingBase = setmetatable({}, { __mode = "k" }) -- [wing] = its CFrame relative to the root at rest
local shakeUntil = 0

local function cameraPos()
	local cam = workspace.CurrentCamera
	local cf = cam and cam.CFrame
	return cf and cf.Position or Vector3.zero
end

-- Wings: swing around the body on a sine, fast for bugs (they hover)
local function flapWings(t)
	local cam = cameraPos()
	for _, wing in CollectionService:GetTagged("MobWing") do
		local model = wing.Parent
		local root = model and model.PrimaryPart
		if root and (root.Position - cam).Magnitude < RANGE then
			local rel = wingBase[wing]
			if not rel then
				rel = root.CFrame:ToObjectSpace(wing.CFrame)
				wingBase[wing] = rel
			end
			local side = wing:GetAttribute("Side") or 1
			local flap = math.sin(t * 14 + root.Position.X) * 0.5
			wing.CFrame = root.CFrame * rel * CFrame.Angles(0, 0, side * flap)
		end
	end
end

local function turn(t)
	for _, inst in CollectionService:GetTagged("Turn") do
		if inst:IsA("BasePart") then
			local speed = inst:GetAttribute("TurnSpeed") or 0.5
			local home = inst:GetAttribute("Home")
			if not home then
				home = inst.CFrame
				inst:SetAttribute("Home", home)
			end
			local bob = inst:GetAttribute("Bob") or 0
			inst.CFrame = home * CFrame.new(0, math.sin(t * 1.5) * bob, 0) * CFrame.Angles(0, t * speed, 0)
		end
	end
end

-- Pets float beside their owner: slot 1 at the left shoulder, slot 2 at the right, bobbing, facing forward.
local function pets(t)
	local folder = workspace:FindFirstChild("Pets")
	if not folder then
		return
	end
	local cam = cameraPos()
	for _, model in folder:GetChildren() do
		local owner = Players:GetPlayerByUserId(model:GetAttribute("OwnerUserId") or 0)
		local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		local root = model.PrimaryPart
		if hrp and root and (hrp.Position - cam).Magnitude < RANGE then
			local slot = model:GetAttribute("Slot") or 1
			local side = slot == 1 and -1 or 1
			local target = hrp.CFrame * CFrame.new(side * 2.6, 1.2 + math.sin(t * 2.5 + slot) * 0.3, 1.2)
			root.CFrame = root.CFrame:Lerp(target, 0.15)
		end
	end
end

function FxController:init()
	Net.listen("Down", function()
		shakeUntil = os.clock() + 0.5
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		if Theme.reducedMotion() then
			return
		end
		flapWings(t)
		turn(t)
		pets(t)
		if t < shakeUntil then
			local cam = workspace.CurrentCamera
			if cam and cam.CFrame then
				local k = (shakeUntil - t) * 0.6
				cam.CFrame = cam.CFrame * CFrame.new(math.sin(t * 60) * k, math.cos(t * 50) * k, 0)
			end
		end
	end)
	_ = player
end

return FxController

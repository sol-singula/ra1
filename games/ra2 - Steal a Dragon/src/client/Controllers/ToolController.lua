-- Dragon Wings: with the wings in your hand, a click (or tap) on the ground launches you up, and while you're
-- in the air you glide: a slow fall and a fast forward drift in the direction you steer. Your character's physics
-- run on your device, so this lives on the client. Wings can't lift a carried dragon.
-- Also flaps every character's wings (ToolService puts them on the back).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Hud = require(script.Parent.HudController)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local ToolController = { Name = "ToolController", Order = 40 }

local hooked = setmetatable({}, { __mode = "k" })

local function carrying()
	local c = Store.state.carrying
	return c ~= nil and c ~= false
end

local function parts()
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return character, hum, hrp
end

-- The wings tool in your hand, if any.
local function wingsInHand()
	local character = player.Character
	if not character then
		return nil
	end
	for _, t in character:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Kind") == "wings" then
			return t
		end
	end
	return nil
end

local function airborne(hum)
	return hum.FloorMaterial == Enum.Material.Air
end

function ToolController.launch()
	local _, hum, hrp = parts()
	if not hum or not hrp then
		return
	end
	if carrying() then
		Hud.toast("Too heavy to fly with a dragon! Run! 🏃", "bad")
		return
	end
	if airborne(hum) then
		return -- already flying: you glide by just holding the wings
	end
	local v = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(v.X, Constants.WINGS_LAUNCH, v.Z)
end

-- One physics step of gliding (only with the wings in hand, in the air, and not carrying).
function ToolController.glide()
	local _, hum, hrp = parts()
	if not hum or not hrp or not wingsInHand() or carrying() or not airborne(hum) then
		return false
	end
	local v = hrp.AssemblyLinearVelocity
	local dir = hum.MoveDirection
	local flat
	if dir.Magnitude > 0.1 then
		flat = Vector3.new(dir.X, 0, dir.Z).Unit * Constants.GLIDE_SPEED
	else
		flat = Vector3.new(v.X, 0, v.Z) * 0.98
	end
	hrp.AssemblyLinearVelocity = Vector3.new(flat.X, math.max(v.Y, -Constants.GLIDE_FALL), flat.Z)
	return true
end

local function hook(tool)
	if hooked[tool] or not tool:IsA("Tool") or tool:GetAttribute("Kind") ~= "wings" then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(ToolController.launch)
end

local function watch(character)
	for _, t in character:GetChildren() do
		hook(t)
	end
	character.ChildAdded:Connect(hook)
end

-- Same shape as ToolService.wingC0 (the server builds the wings; this only swings them).
local function wingC0(side, flap)
	return CFrame.new(side * 0.3, 0.5, 0.65) * CFrame.Angles(0, side * (math.rad(-18) + flap), side * math.rad(12))
end

function ToolController:init()
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	RunService.Heartbeat:Connect(function()
		ToolController.glide()
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local still = Theme.reducedMotion()
		for _, p in Players:GetPlayers() do
			local model = p.Character and p.Character:FindFirstChild("WingsModel")
			if model then
				local hum = p.Character:FindFirstChildOfClass("Humanoid")
				local flying = hum and airborne(hum)
				local flap = still and 0 or math.sin(t * (flying and 9 or 2.5)) * (flying and 0.45 or 0.12)
				for _, root in model:GetChildren() do
					local joint = root:FindFirstChild("Joint")
					if joint then
						joint.C0 = wingC0(root:GetAttribute("Side") or 1, flap)
					end
				end
			end
		end
	end)
end

return ToolController

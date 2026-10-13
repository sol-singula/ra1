-- The bonk swing you can see. Your own swing plays the instant you click, tap or press Q (no waiting for the
-- server); everyone else's plays when the server says they swung ("Swing"). The arm lifts the weapon back over
-- the shoulder and slams it down, the weapon tips forward with it, and a white swoosh trails the head.
-- The hit itself (who gets stunned) is still decided by the server (CombatService.Bonk).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Audio = require(script.Parent.AudioController)

local player = Players.LocalPlayer

local BonkController = { Name = "BonkController", Order = 41 }

local lastLocal = -99
local swinging = setmetatable({}, { __mode = "k" }) -- [character] = true while a swing plays

local function shoulder(character)
	local arm = character:FindFirstChild("RightUpperArm")
	local m = arm and arm:FindFirstChild("RightShoulder")
	if not m then
		local torso = character:FindFirstChild("Torso")
		m = torso and torso:FindFirstChild("Right Shoulder")
	end
	return m and m:IsA("Motor6D") and m or nil
end

local function weaponIn(character)
	for _, t in character:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Kind") == "bonk" then
			return t
		end
	end
	return nil
end

local function tween(inst, seconds, goal, style)
	local ok, tw = pcall(function()
		return TweenService:Create(
			inst,
			TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
	end)
	if ok and tw then
		tw:Play()
	end
end

-- Play one swing on a character (any player's).
function BonkController.swing(character)
	if not character or swinging[character] then
		return false
	end
	swinging[character] = true
	local motor = shoulder(character)
	local tool = weaponIn(character)
	local c0 = motor and motor.C0
	local grip = tool and tool.Grip
	-- wind up (0.07 s), slam (0.1 s), back to rest (0.16 s)
	if motor then
		tween(motor, 0.07, { C0 = c0 * CFrame.Angles(math.rad(150), 0, math.rad(-10)) })
	end
	if tool then
		tween(tool, 0.07, { Grip = grip * CFrame.Angles(math.rad(-35), 0, 0) })
		local head = tool:FindFirstChild("Handle")
		if head and not head:FindFirstChild("Swoosh") then
			local a0 = Instance.new("Attachment")
			a0.Name = "SwooshA"
			a0.Position = Vector3.new(0, head.Size.Y / 2, 0)
			a0.Parent = head
			local a1 = Instance.new("Attachment")
			a1.Name = "SwooshB"
			a1.Position = Vector3.new(0, -head.Size.Y / 4, 0)
			a1.Parent = head
			local trail = Instance.new("Trail")
			trail.Name = "Swoosh"
			trail.Attachment0, trail.Attachment1 = a0, a1
			trail.Lifetime = 0.18
			trail.LightEmission = 0.6
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = head
			task.delay(0.45, function()
				trail:Destroy()
				a0:Destroy()
				a1:Destroy()
			end)
		end
	end
	task.delay(0.07, function()
		if motor then
			tween(motor, 0.1, { C0 = c0 * CFrame.Angles(math.rad(-25), 0, math.rad(5)) }, Enum.EasingStyle.Back)
		end
		if tool then
			tween(tool, 0.1, { Grip = grip * CFrame.Angles(math.rad(70), 0, 0) }, Enum.EasingStyle.Back)
		end
		task.delay(0.12, function()
			if motor then
				tween(motor, 0.16, { C0 = c0 })
			end
			if tool then
				tween(tool, 0.16, { Grip = grip })
			end
			task.delay(0.17, function()
				swinging[character] = nil
			end)
		end)
	end)
	return true
end

-- Your own swing: right away, with the swing sound, and the same cooldown as the server.
function BonkController.localSwing()
	if os.clock() - lastLocal < Constants.BONK_COOLDOWN then
		return false
	end
	lastLocal = os.clock()
	BonkController.swing(player.Character)
	Audio.play("swing")
	return true
end

function BonkController:init()
	-- the weapon in your hand: clicking it swings here at once (the server does the hit from the same click)
	local function hook(t)
		if t:IsA("Tool") and t:GetAttribute("Kind") == "bonk" and not t:GetAttribute("SwingHooked") then
			t:SetAttribute("SwingHooked", true)
			t.Activated:Connect(BonkController.localSwing)
		end
	end
	local function watch(character)
		for _, t in character:GetChildren() do
			hook(t)
		end
		character.ChildAdded:Connect(hook)
	end
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	-- other players' swings
	Net.listen("Swing", function(attacker)
		if typeof(attacker) == "Instance" and attacker ~= player and attacker.Character then
			BonkController.swing(attacker.Character)
		end
	end)
end

return BonkController

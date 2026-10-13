-- Dragon Wings (VIP): with the wings in your hand you really fly. Hold jump (space, or the jump button) to rise,
-- let go to hover in place, hold Shift (or C / Ctrl; L2 on a controller; the ⬇ button on a phone or
-- tablet) to fly down, and steer with the normal
-- controls. You can't fly higher than Constants.FLY_MAX_HEIGHT above the ground level of the map, and you can't
-- fly with a dragon (too heavy). Put the wings away and you glide down gently. Your character's physics run on
-- your device, so this lives on the client.
-- Also flaps every character's wings (ToolService puts them on the back): fast while flying, slow on the ground.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Audio = require(script.Parent.AudioController)
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

local function UserInputServiceTouch()
	local UIS = game:GetService("UserInputService")
	return UIS.TouchEnabled == true
end

local function airborne(hum)
	return hum.FloorMaterial == Enum.Material.Air
end

local downButton
local toldControls = false

local function sinking()
	local UIS = game:GetService("UserInputService")
	local ok, held = pcall(function()
		return UIS:IsKeyDown(Enum.KeyCode.LeftShift)
			or UIS:IsKeyDown(Enum.KeyCode.RightShift)
			or UIS:IsKeyDown(Enum.KeyCode.C)
			or UIS:IsKeyDown(Enum.KeyCode.LeftControl)
			or UIS:IsKeyDown(Enum.KeyCode.ButtonL2)
			or UIS:IsKeyDown(Enum.KeyCode.ButtonB)
	end)
	return (ok and held) or (downButton ~= nil and downButton:GetAttribute("Held") == true)
end

-- Clicking with the wings in hand gives a hop into the air (then hold jump to keep rising).
function ToolController.launch()
	local _, hum, hrp = parts()
	if not hum or not hrp then
		return
	end
	if carrying() then
		Hud.toast("Too heavy to fly with a dragon! Run! 🏃", "bad")
		return
	end
	local v = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(v.X, Constants.FLY_UP_SPEED, v.Z)
	Audio.play("wings")
end

-- One physics step of flying. Returns "fly" while flying, "glide" when gliding down without wings in hand.
function ToolController.glide()
	local _, hum, hrp = parts()
	if not hum or not hrp or carrying() then
		return false
	end
	local inHand = wingsInHand()
	if not inHand and not hrp:GetAttribute("WasFlying") then
		return false
	end
	local v = hrp.AssemblyLinearVelocity
	local dir = hum.MoveDirection or Vector3.zero
	local flat = dir.Magnitude > 0.1 and Vector3.new(dir.X, 0, dir.Z).Unit * Constants.FLY_SPEED or Vector3.zero
	if inHand then
		local up = 0
		if hum.Jump then
			up = Constants.FLY_UP_SPEED
		elseif sinking() then
			up = -Constants.FLY_UP_SPEED
		end
		local y = hrp.Position.Y
		if not airborne(hum) and up <= 0 then
			return false -- standing on the ground: walk normally
		end
		if y >= Constants.FLY_MAX_HEIGHT and up > 0 then
			up = 0 -- the sky has a ceiling
		elseif y > Constants.FLY_MAX_HEIGHT + 1 then
			up = -Constants.FLY_UP_SPEED * 0.5
		end
		hrp.AssemblyLinearVelocity = Vector3.new(flat.X, up, flat.Z)
		return "fly"
	elseif airborne(hum) and hrp:GetAttribute("WasFlying") then
		-- wings put away in the air: glide down instead of dropping like a rock
		local f = dir.Magnitude > 0.1 and flat * (Constants.GLIDE_SPEED / Constants.FLY_SPEED)
			or Vector3.new(v.X, 0, v.Z) * 0.98
		hrp.AssemblyLinearVelocity = Vector3.new(f.X, math.max(v.Y, -Constants.GLIDE_FALL), f.Z)
		return "glide"
	end
	return false
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
		local mode = ToolController.glide()
		local _, _, hrp = parts()
		if hrp then
			hrp:SetAttribute("WasFlying", mode == "fly" or (mode == "glide" and true) or nil)
		end
		-- the ⬇ button for phones while flying
		if downButton then
			downButton.Visible = mode == "fly"
		end
		if mode == "fly" and not toldControls then
			toldControls = true
			local kind = Theme.inputKind()
			Hud.toast(
				kind == "touch" and "🪽 Flying! Jump = up · ⬇ = down"
					or kind == "gamepad" and "🪽 Flying! A = up · L2 = down"
					or "🪽 Flying! Space = up · Shift = down",
				"good"
			)
		end
	end)
	if UserInputServiceTouch() then
		local gui = Instance.new("ScreenGui")
		gui.Name = "FlyControls"
		gui.ResetOnSpawn = false
		gui.Parent = player:WaitForChild("PlayerGui")
		downButton = Theme.button({
			Name = "FlyDown",
			Text = "⬇",
			BackgroundColor3 = Theme.Color.sky,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(64, 64),
			Position = UDim2.new(1, -150, 1, -40),
			Visible = false,
			round = true,
			Parent = gui,
		})
		pcall(function()
			downButton.InputBegan:Connect(function()
				downButton:SetAttribute("Held", true)
			end)
			downButton.InputEnded:Connect(function()
				downButton:SetAttribute("Held", false)
			end)
		end)
	end
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

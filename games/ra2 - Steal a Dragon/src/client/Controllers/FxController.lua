-- Look and feel: a bonk bat in every character's hand (swings when its owner bonks), rainbow dragons,
-- dragons circling in the sky, the "YOUR BASE" marker that is always visible, camera shake when you get
-- bonked, and the bonk keys.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local FxController = { Name = "FxController", Order = 50 }

local bats = {} -- [character] = { weld, swingUntil }
local homeMarker

-- Bats ---------------------------------------------------------------------------------------------------------
local function addBat(character)
	local hand = character:WaitForChild("RightHand", 5) or character:FindFirstChild("Right Arm")
	if not hand or character:FindFirstChild("Bat") then
		return
	end
	local bat = new("Model", { Name = "Bat" })
	local handle = new("Part", {
		Name = "Handle",
		Size = Vector3.new(0.35, 2.2, 0.35),
		Color = Color3.fromRGB(150, 100, 60),
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanQuery = false,
		Massless = true,
		Parent = bat,
	})
	local head = new("Part", {
		Name = "Head",
		Size = Vector3.new(0.75, 1.3, 0.75),
		Color = Color3.fromRGB(255, 205, 50),
		CanCollide = false,
		CanQuery = false,
		Massless = true,
		CFrame = handle.CFrame * CFrame.new(0, 1.6, 0),
		Parent = bat,
	})
	new("WeldConstraint", { Part0 = handle, Part1 = head, Parent = head })
	local weld = new("Weld", {
		Part0 = hand,
		Part1 = handle,
		C0 = CFrame.new(0, -0.4, -0.3) * CFrame.Angles(math.rad(-80), 0, 0),
		Parent = handle,
	})
	bat.Parent = character
	bats[character] = { weld = weld, swingUntil = 0 }
end

local function watchCharacter(p)
	if p.Character then
		task.spawn(addBat, p.Character)
	end
	p.CharacterAdded:Connect(function(character)
		task.spawn(addBat, character)
	end)
end

local function swing(p)
	local b = p and p.Character and bats[p.Character]
	if b then
		b.swingUntil = os.clock() + 0.3
	end
end

-- Home marker ----------------------------------------------------------------------------------------------
local function updateHome()
	local index = Store.state.baseIndex
	local bases = workspace:FindFirstChild("Bases")
	local base = index and bases and bases:FindFirstChild("Base" .. index)
	local laser = base and base:FindFirstChild("Laser")
	if not laser then
		return
	end
	if not homeMarker then
		homeMarker = new("BillboardGui", {
			Name = "HomeMarker",
			AlwaysOnTop = true,
			MaxDistance = 2000,
			StudsOffset = Vector3.new(0, 14, 0),
			Parent = player:WaitForChild("PlayerGui"),
		})
		Theme.text({
			Name = "Text",
			Text = "🏠 YOUR BASE",
			Font = Theme.Display,
			TextColor3 = C.mustard,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = C.ink,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = homeMarker,
		})
	end
	homeMarker.Adornee = laser
	local carrying = Store.state.carrying
	homeMarker.Size = (carrying and carrying ~= false) and UDim2.fromOffset(260, 60) or UDim2.fromOffset(170, 36)
end

-- Camera shake ---------------------------------------------------------------------------------------------
local shakeUntil = 0

function FxController:init()
	for _, p in Players:GetPlayers() do
		watchCharacter(p)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	Net.listen("Swing", swing)
	Net.listen("Bonked", function(seconds)
		if not Theme.reducedMotion() then -- no camera shake for players who asked for reduced motion
			shakeUntil = os.clock() + math.min(seconds, 0.5)
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.baseIndex ~= nil or partial.carrying ~= nil then
			updateHome()
		end
	end)

	-- bonk: Q / R2 on computers and consoles, a click on empty screen with a mouse, the big button on phones
	-- (gamepad X is left alone: Roblox uses it for proximity prompts)
	ContextActionService:BindAction("Bonk", function(_, state)
		if state == Enum.UserInputState.Begin then
			Net.send("Bonk")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonR2)
	-- lock: L / gamepad Y (the on-screen LOCK button shows these keys)
	ContextActionService:BindAction("Lock", function(_, state)
		if state == Enum.UserInputState.Begin then
			Net.send("Lock")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.L, Enum.KeyCode.ButtonY)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
			Net.send("Bonk")
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		-- bat swings
		for character, b in bats do
			if not character.Parent then
				bats[character] = nil
			else
				local swingT = math.clamp((b.swingUntil - t) / 0.3, 0, 1)
				local angle = -80 + math.sin(swingT * math.pi) * 140
				b.weld.C0 = CFrame.new(0, -0.4, -0.3) * CFrame.Angles(math.rad(angle), 0, 0)
			end
		end
		-- camera shake
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			if t < shakeUntil then
				-- a short shake that dies away instead of staying the same strength
				local strength = (shakeUntil - t) / 0.5
				hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * strength
			elseif hum.CameraOffset ~= Vector3.zero then
				hum.CameraOffset = Vector3.zero
			end
		end
		-- dragons circling in the sky
		for _, d in CollectionService:GetTagged("SkyDragon") do
			local r, h = d:GetAttribute("Radius") or 80, d:GetAttribute("Height") or 60
			local a = (d:GetAttribute("Phase") or 0) + t * (d:GetAttribute("Speed") or 0.04)
			local p = Vector3.new(-20 + math.cos(a) * r, h + math.sin(t * 0.8 + a) * 3, math.sin(a) * r * 0.7)
			local ahead = Vector3.new(-20 + math.cos(a + 0.05) * r, h, math.sin(a + 0.05) * r * 0.7)
			if (d:GetAttribute("Speed") or 0) < 0 then
				ahead = p + (p - ahead)
			end
			d:PivotTo(
				CFrame.lookAt(p, Vector3.new(ahead.X, p.Y, ahead.Z)) * CFrame.Angles(0, 0, math.sin(t + a) * 0.15)
			)
		end
		-- rainbow dragons, 10 times a second
		acc += dt
		if acc >= 0.1 then
			acc = 0
			local hue = (t * 0.25) % 1
			for _, model in CollectionService:GetTagged("RainbowDragon") do
				for _, name in { "Body", "Head", "Snout", "Tail", "Tail2" } do
					local part = model:FindFirstChild(name)
					if part then
						part.Color = Color3.fromHSV(hue, 0.65, 1)
					end
				end
			end
		end
	end)
end

return FxController

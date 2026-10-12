-- Look and feel: rainbow dragons, the custom dragons' spinning halos, orbs and rings and their pulsing glow, dragons circling in the sky, the "YOUR BASE" marker that is always visible,
-- camera shake when you get bonked, and the bonk and lock keys. (The bat itself is a hotbar tool: ToolService.)
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local FxController = { Name = "FxController", Order = 50 }

local homeMarker
local SPIN_RANGE = 140 -- studs from the camera

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

	-- bonk: a click or tap with the bat in your hand (it's a hotbar tool), or Q / R2 whatever you hold
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

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
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
		-- custom dragons: spinning pieces (same maths as DragonBuilder.spinC0) and pulsing glow, near the camera only
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame and cam.CFrame.Position
		if camPos and not Theme.reducedMotion() then
			for _, w in CollectionService:GetTagged("DragonSpin") do
				local p0 = w.Part0
				if p0 and (p0.Position - camPos).Magnitude < SPIN_RANGE then
					local a = (w:GetAttribute("A") or 0) + t * (w:GetAttribute("Speed") or 1)
					w.C0 = CFrame.new(0, w:GetAttribute("Y") or 0, w:GetAttribute("Z") or 0)
						* CFrame.Angles(w:GetAttribute("Tilt") or 0, 0, 0)
						* CFrame.Angles(0, a, 0)
						* CFrame.new(w:GetAttribute("R") or 0, 0, 0)
				end
			end
			local glow = 0.35 + 0.35 * math.sin(t * 4)
			for _, p in CollectionService:GetTagged("DragonPulse") do
				if (p.Position - camPos).Magnitude < SPIN_RANGE then
					p.Transparency = glow
				end
			end
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

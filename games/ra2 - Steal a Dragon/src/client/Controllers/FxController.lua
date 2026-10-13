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
local PerformanceController = require(script.Parent.PerformanceController)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local FxController = { Name = "FxController", Order = 50 }

local homeMarker
local SPIN_RANGE = 140 -- studs from the camera

-- Lobby showpieces that turn slowly (TurnSpeed attribute): the golden statue (which also flaps, Flap attribute)
-- and the daily prize dragon.
local turners = {} -- [model] = { home, speed, flap, scale, parts = { { part, rel, side } } }
local nextTurnerScan = 0

local function scanTurners()
	local map = workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	for _, m in lobby:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("TurnSpeed") and not turners[m] then
			local home = m:GetPivot()
			local entry = {
				home = home,
				speed = m:GetAttribute("TurnSpeed"),
				flap = m:GetAttribute("Flap") == true,
				scale = m:GetAttribute("Scale") or 1,
				parts = {},
			}
			if entry.flap then
				for _, p in m:GetDescendants() do
					if p:IsA("BasePart") then
						local rel = home:ToObjectSpace(p.CFrame)
						local isWing = p.Name:sub(1, 4) == "Wing" or p.Name:sub(1, 7) == "Feather"
						local side = isWing and (rel.Position.X < 0 and -1 or 1) or 0
						table.insert(entry.parts, { p, rel, side })
					end
				end
			end
			turners[m] = entry
		end
	end
end

-- One frame of the showpieces at time t (exposed for tests).
function FxController.turn(t)
	for m, e in turners do
		if not m.Parent then
			turners[m] = nil
		else
			local pivot = e.home * CFrame.Angles(0, t * e.speed, 0)
			if e.flap then
				-- anchored statue: place every part, swinging the wings about the shoulders
				local flap = math.sin(t * 1.3) * 0.3
				for _, entry in e.parts do
					local p, rel, side = entry[1], entry[2], entry[3]
					if side ~= 0 then
						local hinge = Vector3.new(side * 1.1 * e.scale, 1 * e.scale, 0)
						rel = CFrame.new(hinge) * CFrame.Angles(0, 0, side * flap) * CFrame.new(-hinge) * rel
					end
					p.CFrame = pivot * rel
				end
			else
				m:PivotTo(pivot)
			end
		end
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

	local acc, spinAcc = 0, 0
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
		-- lobby showpieces
		if t >= nextTurnerScan then
			nextTurnerScan = t + 3
			scanTurners()
		end
		local cam0 = workspace.CurrentCamera
		local camPos0 = cam0 and cam0.CFrame and cam0.CFrame.Position
		if not Theme.reducedMotion() and (not camPos0 or (camPos0 - Vector3.new(-160, 10, 0)).Magnitude < 260) then
			FxController.turn(t)
		end
		-- custom dragons: spinning pieces (same maths as DragonBuilder.spinC0) and pulsing glow, near the camera only
		-- (20 times a second in lite mode instead of every frame)
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame and cam.CFrame.Position
		spinAcc += dt
		local spinNow = not PerformanceController.lite or spinAcc >= 0.05
		if spinNow then
			spinAcc = 0
		end
		if spinNow and camPos and not Theme.reducedMotion() then
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

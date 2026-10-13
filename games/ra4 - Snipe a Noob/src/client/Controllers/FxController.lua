-- What you see happen: shot tracers, players popping into bits (in the shooter's pop effect), the crown over the
-- round leader (seen through walls for 2 s every 15 s), rainbow rifles, spinning lobby things, and the cameras:
-- the pop cam (5 s on the player who popped you) and the podium cam after a round.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local FxController = { Name = "FxController", Order = 50 }

local fxFolder
local camMode = nil -- nil | { kind = "pop", target, untilT } | { kind = "podium", untilT }
local crowns = {} -- [character or robot model] = billboard

local function fx()
	if not fxFolder or not fxFolder.Parent then
		fxFolder = workspace:FindFirstChild("Fx")
		if not fxFolder then
			fxFolder = Instance.new("Folder")
			fxFolder.Name = "Fx"
			fxFolder.Parent = workspace
		end
	end
	return fxFolder
end

-- A tracer: a thin glowing beam from the muzzle to where the shot ended, fading fast.
function FxController.tracer(from, to, color)
	local dist = (to - from).Magnitude
	if dist < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Name = "Tracer"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 230, 120)
	p.Size = Vector3.new(0.12, 0.12, dist)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = fx()
	Theme.tween(p, 0.25, { Transparency = 1, Size = Vector3.new(0.03, 0.03, dist) })
	task.delay(0.3, function()
		p:Destroy()
	end)
	-- a little flash where it hit
	local flash = Instance.new("Part")
	flash.Name = "Spark"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = p.Color
	flash.Size = Vector3.new(0.8, 0.8, 0.8)
	flash.CFrame = CFrame.new(to)
	flash.Parent = fx()
	Theme.tween(flash, 0.2, { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) })
	task.delay(0.25, function()
		flash:Destroy()
	end)
end

-- A pop: bits fly out in the pop effect's colours and shapes, then fade.
function FxController.pop(pos, effectId)
	local e = Cosmetics.effectById[effectId] or Cosmetics.PopEffects[1]
	local n = e.small and 22 or 14
	for i = 1, n do
		local b = Instance.new("Part")
		b.Name = "Bit"
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CastShadow = false
		local s = e.small and 0.4 or 0.9
		if e.ball then
			b.Shape = Enum.PartType.Ball
		end
		b.Size = Vector3.new(s, s, s)
		b.Color = e.colors[(i - 1) % #e.colors + 1]
		b.Material = e.neon and Enum.Material.Neon or (e.glass and Enum.Material.Glass or Enum.Material.Plastic)
		if e.glass then
			b.Transparency = 0.3
		end
		local dir = Vector3.new(math.random() - 0.5, e.rise and 1 or math.random() * 0.9, math.random() - 0.5).Unit
		b.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
		b.Parent = fx()
		local target = pos + Vector3.new(0, 1, 0) + dir * (e.rise and 6 or math.random(3, 6))
		Theme.tween(
			b,
			0.7,
			{ CFrame = CFrame.new(target) * CFrame.Angles(math.random(), math.random(), 0), Transparency = 1 }
		)
		task.delay(0.75, function()
			b:Destroy()
		end)
	end
end

-- Crowns ----------------------------------------------------------------------------------------------------------
local function crownFor(model, show)
	local existing = crowns[model]
	if show and not existing then
		local head = model:FindFirstChild("Head") or model:FindFirstChild("Root") or model.PrimaryPart
		if not head then
			return
		end
		local bb = Instance.new("BillboardGui")
		bb.Name = "CrownTag"
		bb.Size = UDim2.fromOffset(60, 50)
		bb.StudsOffset = Vector3.new(0, model:FindFirstChild("Head") and 2.6 or 7, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 400
		bb.LightInfluence = 0
		bb.Adornee = head
		bb.Parent = head
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = "👑"
		t.TextScaled = true
		t.Parent = bb
		crowns[model] = bb
	elseif not show and existing then
		existing:Destroy()
		crowns[model] = nil
	end
end

local function updateCrowns()
	local reveal = (workspace:GetServerTimeNow() % Constants.CROWN_REVEAL_EVERY) < Constants.CROWN_REVEAL_SECONDS
	local seen = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		if c then
			local on = p:GetAttribute("Crown") == true and not p:GetAttribute("Popped")
			crownFor(c, on)
			if on then
				seen[c] = true
			end
		end
	end
	local robots = workspace:FindFirstChild("Robots")
	for _, m in robots and robots:GetChildren() or {} do
		local on = m:GetAttribute("Crown") == true
		crownFor(m, on)
		if on then
			seen[m] = true
		end
	end
	for model, bb in crowns do
		if not seen[model] or not model.Parent then
			bb:Destroy()
			crowns[model] = nil
		else
			-- through walls during the reveal (not for yourself)
			bb.AlwaysOnTop = reveal and model ~= player.Character
		end
	end
end

-- Cameras -----------------------------------------------------------------------------------------------------------
local function popTargetModel(info)
	if info.userId and info.userId ~= 0 then
		local p = Players:GetPlayerByUserId(info.userId)
		return p and p.Character
	elseif info.robot then
		local robots = workspace:FindFirstChild("Robots")
		return robots and robots:FindFirstChild(info.robot)
	end
	return nil
end

local function updateCamera()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if camMode and os.clock() > camMode.untilT then
		camMode = nil
		cam.CameraType = Enum.CameraType.Custom
	end
	if not camMode then
		return
	end
	if camMode.kind == "pop" then
		local m = camMode.target
		local root = m and m.Parent and (m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Root"))
		if root then
			cam.CameraType = Enum.CameraType.Scriptable
			local look = root.CFrame.LookVector
			local eye = root.Position - look * 10 + Vector3.new(0, 4, 0) + root.CFrame.RightVector * 3
			cam.CFrame = CFrame.lookAt(eye, root.Position + Vector3.new(0, 1.5, 0))
		end
	elseif camMode.kind == "podium" then
		cam.CameraType = Enum.CameraType.Scriptable
		local t = os.clock() - camMode.start
		local sway = math.sin(t * 0.6) * 3
		cam.CFrame = CFrame.lookAt(camMode.eye + Vector3.new(sway, 0, 0), camMode.look)
	end
end

function FxController.camMode()
	return camMode and camMode.kind or nil
end

function FxController:init()
	local rifleModule = script.Parent:FindFirstChild("RifleController")
	if rifleModule then
		require(rifleModule).onLocalShot = function(from, to, tracer)
			if tracer ~= false then
				FxController.tracer(from, to, Color3.fromRGB(255, 230, 120))
			end
		end
	end
	Net.listen("Shot", function(from, to, color, shooterId, tracer)
		if shooterId == player.UserId then
			return -- my own tracer already showed
		end
		if tracer ~= false then
			FxController.tracer(from, to, color)
		end
		if FxController.playSound then
			FxController.playSound("shot", from)
		end
	end)
	Net.listen("Pop", function(pos, effectId)
		FxController.pop(pos, effectId)
	end)
	Net.listen("Popped", function(info)
		camMode = {
			kind = "pop",
			target = popTargetModel(info),
			untilT = os.clock() + Constants.RESPAWN_SECONDS - 0.1,
		}
	end)
	Net.listen("Podium", function()
		local layout = workspace:FindFirstChild("Map")
		_ = layout
		camMode = {
			kind = "podium",
			eye = Vector3.new(0, 11, -26),
			look = Vector3.new(0, 6, -52),
			start = os.clock(),
			untilT = os.clock() + Constants.PODIUM_SECONDS,
		}
	end)
	player:GetAttributeChangedSignal("Popped"):Connect(function()
		if not player:GetAttribute("Popped") and camMode and camMode.kind == "pop" then
			camMode = nil
			local cam = workspace.CurrentCamera
			if cam then
				cam.CameraType = Enum.CameraType.Custom
			end
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		updateCamera()
		acc += dt
		if acc >= 0.2 then
			acc = 0
			updateCrowns()
		end
		local t = os.clock()
		for _, part in CollectionService:GetTagged("Turn") do
			if part.Parent then
				part.CFrame = CFrame.new(part.Position) * CFrame.Angles(0, t * (part:GetAttribute("TurnSpeed") or 1), 0)
			end
		end
		-- rainbow rifles cycle their colours
		local hue = (t * 0.25) % 1
		for _, p in Players:GetPlayers() do
			local tool = p.Character and p.Character:FindFirstChild("Rifle")
			if tool and tool:GetAttribute("Rainbow") then
				for _, part in tool:GetChildren() do
					if part:IsA("BasePart") and part.Name ~= "Lens" then
						part.Color = Color3.fromHSV((hue + (part.Name == "Barrel" and 0.3 or 0)) % 1, 0.8, 1)
					end
				end
			end
		end
		local cam = workspace.CurrentCamera
		local vm = cam and cam:FindFirstChild("ViewModel")
		if vm and vm:GetAttribute("Rainbow") then
			for _, part in vm:GetChildren() do
				if part:IsA("BasePart") and part.Name ~= "Lens" then
					part.Color = Color3.fromHSV((hue + (part.Name == "Barrel" and 0.3 or 0)) % 1, 0.8, 1)
				end
			end
		end
	end)
end

return FxController

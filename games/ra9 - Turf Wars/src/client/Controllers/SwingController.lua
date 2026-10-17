--[[
How a blade slash looks and feels (the server decides the hit; this is only the show):

  * Everyone else's slash (Net "Swing"): their right arm sweeps across in a fast arc (the R15 RightShoulder joint,
    set after the animations each frame), and a white streak in their team's colour cuts the air in front of them.
  * Your own slash (Bus.Fired with the blade): a streak across your view, in front of the blade.
  * A hit with the blade (Net "Hit" with melee): a burst of sparks where it landed, a sharp camera jolt and a short
    zoom punch, so you feel it connect; harder on a hit from behind and on a knockout.

  SwingController.slashOf(character, dir)   play another player's slash (tests call it)
  SwingController.streaks()                 how many streak pieces are on screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)
local CameraController = require(script.Parent.CameraController)

local SwingController = { Name = "SwingController", Order = 47 }

local SWING_SECONDS = 0.32
local player = Players.LocalPlayer
local folder
local pieces = {} -- { part, born, life, size }
local arms = {} -- [motor] = { start, base }

local function bodyOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return p.Character
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, m in bots and bots:GetChildren() or {} do
		if m:GetAttribute("BotId") == userId then
			return m
		end
	end
	return nil
end

local function piece(cf, size, color, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = 0.15
	p.Parent = folder
	table.insert(pieces, { part = p, born = os.clock(), life = life or 0.22, size = size })
	return p
end

-- A curved streak: thin glowing segments along an arc, from up right to down left, centred at `at`, facing `dir`
local function streak(at, dir, color, radius)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(at, at + flat)
	local n = 7
	for i = 0, n - 1 do
		local a = math.rad(-60 + 120 * (i / (n - 1)))
		local local0 = Vector3.new(math.cos(a) * radius, math.sin(a) * radius * 0.55, 0)
		local a2 = math.rad(-60 + 120 * ((i + 1) / (n - 1)))
		local local1 = Vector3.new(math.cos(a2) * radius, math.sin(a2) * radius * 0.55, 0)
		local p0, p1 = frame * local0, frame * local1
		local len = math.max(0.1, (p1 - p0).Magnitude)
		local w = 0.08 + 0.12 * math.sin(math.pi * i / (n - 1)) -- (thick in the middle, thin at the ends)
		piece(CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(w, w, len), color, 0.16 + i * 0.012)
	end
end

function SwingController.streaks()
	return #pieces
end

function SwingController.slashOf(character, dir)
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local team = character:GetAttribute("Team")
	local color = (Constants.TEAM_COLOR[team or ""] or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.45)
	local look = typeof(dir) == "Vector3" and dir or root.CFrame.LookVector
	streak(root.Position + Vector3.new(0, 1.2, 0) + look * 2.4, look, color, 2.2)
	local arm = character:FindFirstChild("RightUpperArm")
	local motor = arm and arm:FindFirstChild("RightShoulder")
	if motor and motor:IsA("Motor6D") then
		arms[motor] = { start = os.clock() }
	end
	return true
end

local function sparks(pos, strong)
	local n = strong and 14 or 8
	for _ = 1, n do
		local d = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		d = d.Magnitude > 0.01 and d.Unit or Vector3.yAxis
		local len = 0.6 + math.random() * 0.9
		local at = pos + Vector3.new(0, 1, 0) + d * (0.4 + math.random() * 0.8)
		piece(CFrame.lookAt(at, at + d), Vector3.new(0.08, 0.08, len), Color3.fromRGB(255, 255, 255), 0.18)
	end
end

local function step()
	local t = os.clock()
	for i = #pieces, 1, -1 do
		local s = pieces[i]
		local k = (t - s.born) / s.life
		if k >= 1 then
			s.part:Destroy()
			table.remove(pieces, i)
		else
			s.part.Transparency = 0.15 + 0.85 * k * k
			s.part.Size = Vector3.new(s.size.X * (1 - k * 0.6), s.size.Y * (1 - k * 0.6), s.size.Z)
		end
	end
	-- arms mid-slash: wind up, a fast sweep across, and back (set after the animations, so it wins this frame)
	for motor, a in arms do
		local f = (t - a.start) / SWING_SECONDS
		if f >= 1 or not motor.Parent then
			arms[motor] = nil
			pcall(function()
				motor.Transform = CFrame.new()
			end)
		else
			local sweep = f < 0.25 and -(f / 0.25)
				or (f < 0.6 and -1 + 2.4 * ((f - 0.25) / 0.35) or 1.4 * (1 - (f - 0.6) / 0.4))
			pcall(function()
				motor.Transform = CFrame.Angles(math.rad(70 + 30 * sweep), math.rad(-40 * sweep), math.rad(25 * sweep))
			end)
		end
	end
end

function SwingController:init()
	folder = Instance.new("Folder")
	folder.Name = "Slashes"
	folder.Parent = workspace
	Net.listen("Swing", function(s)
		if type(s) ~= "table" or s.by == player.UserId then
			return
		end
		SwingController.slashOf(bodyOf(s.by), s.dir)
	end)
	Bus.Fired:Connect(function(key)
		if key ~= "blade" then
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			local look = cam.CFrame.LookVector
			streak(cam.CFrame.Position + look * 2.6 - Vector3.new(0, 0.35, 0), look, Color3.fromRGB(255, 255, 255), 1.5)
		end
	end)
	Net.listen("Hit", function(h)
		if type(h) ~= "table" or not h.melee then
			return
		end
		if typeof(h.pos) == "Vector3" then
			sparks(h.pos, h.kill or h.head)
		end
		local strong = h.kill or h.head
		CameraController.shake(Theme.reducedMotion() and 0.05 or (strong and 0.32 or 0.2), 0.14)
		CameraController.setFov("slash", strong and -9 or -6)
		task.delay(0.09, function()
			CameraController.setFov("slash", nil)
		end)
	end)
	RunService.RenderStepped:Connect(step)
end

return SwingController

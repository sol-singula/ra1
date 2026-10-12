-- The glowing path: a trail of gold chevrons on the ground from you to where you need to go. It shows the way to
-- each tutorial step's target and, whenever you carry a dragon, the way home. To a target inside a base it goes
-- through that base's gate, not through the walls. Only you see it (the parts are made on your client).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local GuideController = { Name = "GuideController", Order = 35 }

local SPACING = 3.2 -- studs between chevrons
local MAX_CHEVRONS = 70
local GROUND_Y = 0.95 -- just above floors, the road, the plaza and the nest dais
local COLOR = Color3.fromRGB(255, 215, 70)
local ARM = 1.5 -- length of each arm of a chevron

local folder
local pool = {} -- { { a = Part, b = Part, dist = number } }
local tutorialTarget

local function arm(name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = COLOR
	p.Size = Vector3.new(0.35, 0.12, ARM)
	p.Parent = folder
	return p
end

local function chevron(i)
	if not pool[i] then
		pool[i] = { a = arm("ChevronL"), b = arm("ChevronR"), dist = 0 }
	end
	return pool[i]
end

local function hide(from)
	for i = from, #pool do
		pool[i].a.Transparency = 1
		pool[i].b.Transparency = 1
		pool[i].hidden = true
	end
end

local function partOf(target)
	if typeof(target) ~= "Instance" or not target.Parent then
		return nil
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	end
	return target:IsA("BasePart") and target or nil
end

-- The base model a part belongs to (workspace.Bases.BaseN), if any.
local function baseOf(part)
	local bases = workspace:FindFirstChild("Bases")
	local node = part
	while node and node.Parent do
		if node.Parent == bases then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function inside(base, pos)
	local floor = base:FindFirstChild("Floor")
	if not floor then
		return false
	end
	local p = floor.CFrame:PointToObjectSpace(pos)
	return math.abs(p.X) <= floor.Size.X / 2 and math.abs(p.Z) <= floor.Size.Z / 2
end

local function myBaseGate()
	local index = Store.state.baseIndex
	local bases = workspace:FindFirstChild("Bases")
	local base = index and bases and bases:FindFirstChild("Base" .. index)
	return base and base:FindFirstChild("Laser")
end

-- Where to lead the player now: the tutorial target, or their own gate while carrying a dragon.
local function goal()
	local part = partOf(tutorialTarget)
	if part then
		return part
	end
	local carrying = Store.state.carrying
	if carrying ~= nil and carrying ~= false then
		return myBaseGate()
	end
	return nil
end

-- The route: from the player, through the gate of the target's base (when the player is outside it), to the target.
local function route(from, part)
	local points = { Vector3.new(from.X, GROUND_Y, from.Z) }
	local base = baseOf(part)
	local laser = base and base:FindFirstChild("Laser")
	local target = Vector3.new(part.Position.X, GROUND_Y, part.Position.Z)
	if laser then
		local out = laser.CFrame.LookVector -- the gate faces the road
		local gate = Vector3.new(laser.Position.X, GROUND_Y, laser.Position.Z)
		if not inside(base, from) then
			table.insert(points, gate + out * 7)
		end
		if part == laser then
			target = gate - out * 5 -- lead a little way in, so you end up inside
		else
			table.insert(points, gate - out * 3)
		end
	end
	table.insert(points, target)
	return points
end

local function layout(points)
	local n, travelled = 0, 0
	local nextAt = 2.5
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local seg = (b - a).Magnitude
		if seg > 0.01 then
			local dir = (b - a).Unit
			while nextAt <= travelled + seg - 1 and n < MAX_CHEVRONS do
				n += 1
				local tip = a + dir * (nextAt - travelled)
				local c = chevron(n)
				local base = CFrame.lookAt(tip, tip + dir)
				c.a.CFrame = base * CFrame.Angles(0, math.rad(40), 0) * CFrame.new(0, 0, ARM / 2)
				c.b.CFrame = base * CFrame.Angles(0, math.rad(-40), 0) * CFrame.new(0, 0, ARM / 2)
				c.dist = nextAt
				c.hidden = false
				nextAt += SPACING
			end
		end
		travelled += seg
	end
	hide(n + 1)
end

function GuideController:init()
	folder = Instance.new("Folder")
	folder.Name = "GuidePath"
	folder.Parent = workspace
	Net.listen("Tutorial", function(info)
		tutorialTarget = info and info.target or nil
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local part = goal()
		if not hrp or not part or (hrp.Position - part.Position).Magnitude < 10 then
			hide(1)
			return
		end
		if acc >= 0.15 then
			acc = 0
			layout(route(hrp.Position, part))
		end
		-- a glow that runs along the path toward the goal (steady with Reduced Motion on)
		local t = Theme.reducedMotion() and 0 or os.clock() * 7
		for _, c in pool do
			if not c.hidden then
				local wave = 0.5 + 0.5 * math.sin(c.dist * 0.55 - t)
				local alpha = 0.1 + 0.5 * (1 - wave)
				c.a.Transparency = alpha
				c.b.Transparency = alpha
			end
		end
	end)
end

return GuideController

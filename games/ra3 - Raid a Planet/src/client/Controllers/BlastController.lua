-- Blasting on the client: picks the nearest bug or boss you're facing and asks the server to shoot it, as fast
-- as your blaster allows, while the BLAST button is held, the blaster tool is clicked or tapped, or F / Space
-- is held. Draws the beams everyone's shots make.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Hud = require(script.Parent.HudController)

local player = Players.LocalPlayer

local BlastController = { Name = "BlastController", Order = 30 }

local keyHeld = false
local lastShot = 0
local hooked = setmetatable({}, { __mode = "k" })

local function parts()
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return c, hrp
end

local function blasterInHand()
	local c = player.Character
	if not c then
		return nil
	end
	for _, t in c:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Kind") == "blaster" then
			return t
		end
	end
	return nil
end

-- The target to shoot: the nearest mob in front of you within range; if none is in front, the nearest at all.
function BlastController.pickTarget()
	local _, hrp = parts()
	local mobs = workspace:FindFirstChild("Mobs")
	if not hrp or not mobs then
		return nil
	end
	local look = hrp.CFrame.LookVector
	local bestFront, bestFrontD, bestAny, bestAnyD
	for _, m in mobs:GetChildren() do
		local id = m:GetAttribute("MobId")
		local root = m.PrimaryPart
		if id and root then
			local delta = root.Position - hrp.Position
			local d = delta.Magnitude
			if d <= Constants.BLAST_RANGE then
				local flat = Vector3.new(delta.X, 0, delta.Z)
				local dot = flat.Magnitude > 0.1 and look:Dot(flat.Unit) or 1
				if dot >= Constants.BLAST_CONE and (not bestFrontD or d < bestFrontD) then
					bestFront, bestFrontD = id, d
				end
				if not bestAnyD or d < bestAnyD then
					bestAny, bestAnyD = id, d
				end
			end
		end
	end
	return bestFront or bestAny
end

function BlastController.fire()
	local tool = blasterInHand()
	if not tool then
		return false
	end
	local cd = tool:GetAttribute("Cooldown") or Constants.BLAST_COOLDOWN
	if os.clock() - lastShot < cd then
		return false
	end
	local id = BlastController.pickTarget()
	if not id then
		return false
	end
	lastShot = os.clock()
	Net.send("Blast", id)
	return true
end

-- Beams: a thin neon part from the shooter to the target for a blink.
local function beam(from, to, color)
	local fx = workspace:FindFirstChild("Fx") or workspace
	local delta = to - from
	local len = delta.Magnitude
	if len < 0.5 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "Beam"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color or Color3.fromRGB(255, 240, 120)
	part.Size = Vector3.new(0.35, 0.35, len)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
	part.Parent = fx
	local flash = Instance.new("Part")
	flash.Name = "Hit"
	flash.Shape = Enum.PartType.Ball
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Material = Enum.Material.Neon
	flash.Color = part.Color
	flash.Size = Vector3.new(1.6, 1.6, 1.6)
	flash.CFrame = CFrame.new(to)
	flash.Parent = fx
	task.delay(0.08, function()
		part:Destroy()
	end)
	task.delay(0.15, function()
		flash:Destroy()
	end)
end

local function hook(tool)
	if hooked[tool] or not tool:IsA("Tool") or tool:GetAttribute("Kind") ~= "blaster" then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		BlastController.fire()
	end)
end

local function watch(character)
	for _, t in character:GetChildren() do
		hook(t)
	end
	character.ChildAdded:Connect(hook)
end

function BlastController:init()
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	Net.listen("Beam", beam)
	ContextActionService:BindAction("Blast", function(_, state)
		keyHeld = state == Enum.UserInputState.Begin
		if keyHeld then
			BlastController.fire()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	RunService.RenderStepped:Connect(function()
		if Hud.blastTapped then
			Hud.blastTapped = false
			BlastController.fire()
		elseif keyHeld or Hud.blastHeld then
			BlastController.fire()
		end
	end)
end

return BlastController

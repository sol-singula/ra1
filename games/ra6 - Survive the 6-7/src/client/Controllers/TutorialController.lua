--[[
The guide's side on screen (master plan §4: the first five minutes, one clear thing at a time, never a text wall).
The server sends the step ("Tutorial": { step, total, key, text, target } or false); here it becomes:
  * a card under the compass: STEP 2 of 6, what to do, and a SKIP button
  * a bouncing arrow over the target (the nearest tree, the workbench's blueprint, a crate, the campfire)
  * a soft light beam from you to it, so you never have to guess where to go
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TutorialController = { Name = "TutorialController", Order = 25 }

local player = Players.LocalPlayer
local C = Theme.Color
local gui, card, label, stepLabel
local arrow, beam, targetAttach, fromAttach, targetPart
local current -- the step on screen

local function ensureWorld()
	if arrow and arrow.Parent then
		return
	end
	local folder = workspace:FindFirstChild("Guide") or Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = workspace
	arrow = Instance.new("Model")
	arrow.Name = "GuideArrow"
	arrow.Parent = folder
	local shaft = Kit.box(
		arrow,
		"Shaft",
		CFrame.new(),
		Vector3.new(0.9, 2.2, 0.9),
		C.mustard,
		Kit.M.Neon,
		{ CanCollide = false, CanQuery = false, CastShadow = false }
	)
	local head = Kit.wedge(
		arrow,
		"Head",
		CFrame.new(),
		Vector3.new(0.4, 1.6, 2.2),
		C.mustard,
		Kit.M.Neon,
		{ CanCollide = false, CanQuery = false, CastShadow = false }
	)
	arrow.PrimaryPart = shaft
	arrow:SetAttribute("Head", true)
	targetPart = Kit.box(
		folder,
		"GuideTarget",
		CFrame.new(),
		Vector3.new(0.2, 0.2, 0.2),
		C.mustard,
		Kit.M.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false }
	)
	targetAttach = Instance.new("Attachment")
	targetAttach.Parent = targetPart
	beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Attachment1 = targetAttach
	beam.Color = ColorSequence.new(C.mustard)
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 12
	beam.Parent = targetPart
	_ = head
end

local function clearWorld()
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	if targetPart then
		targetPart:Destroy()
		targetPart = nil
	end
	beam, targetAttach, fromAttach = nil, nil, nil
end

local function show(view)
	current = type(view) == "table" and view or nil
	if not current then
		card.Visible = false
		clearWorld()
		return
	end
	card.Visible = true
	stepLabel.Text = `STEP {current.step} OF {current.total}`
	label.Text = current.text or ""
	Theme.pop(card)
	if typeof(current.target) == "Vector3" then
		ensureWorld()
	else
		clearWorld()
	end
end

local function step()
	if not current or typeof(current.target) ~= "Vector3" or not arrow then
		return
	end
	local t = os.clock()
	local top = current.target + Vector3.new(0, 4 + math.sin(t * 4) * 0.6, 0)
	local spin = CFrame.Angles(0, t * 2, 0)
	local shaft = arrow:FindFirstChild("Shaft")
	local head = arrow:FindFirstChild("Head")
	if shaft and head then
		shaft.CFrame = CFrame.new(top + Vector3.new(0, 1.6, 0)) * spin
		head.CFrame = CFrame.new(top) * spin * CFrame.Angles(math.rad(180), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	end
	targetPart.CFrame = CFrame.new(current.target)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and beam then
		if not fromAttach or fromAttach.Parent ~= root then
			fromAttach = Instance.new("Attachment")
			fromAttach.Name = "GuideFrom"
			fromAttach.Position = Vector3.new(0, -2.4, 0)
			fromAttach.Parent = root
			beam.Attachment0 = fromAttach
		end
		-- the beam fades once you're there
		beam.Enabled = (root.Position - current.target).Magnitude > 10
	end
end

function TutorialController:init()
	gui = Theme.screen("Guide", 4, player:WaitForChild("PlayerGui"))
	card = Theme.slab({
		Name = "GuideCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 228),
		Size = UDim2.fromOffset(470, 70),
		BackgroundColor3 = Color3.fromRGB(40, 70, 130),
		Visible = false,
		Parent = gui,
	})
	stepLabel = Theme.title({
		Name = "Step",
		Text = "",
		Size = UDim2.new(1, -120, 0, 20),
		Position = UDim2.fromOffset(12, 4),
		TextColor3 = C.mustard,
		outline = 2,
		Parent = card,
	})
	label = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -120, 0, 38),
		Position = UDim2.fromOffset(12, 26),
		outline = 2.5,
		Parent = card,
	})
	local skip = Theme.button({
		Name = "Skip",
		Text = "SKIP",
		BackgroundColor3 = C.slate,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(92, 40),
		Parent = card,
	})
	skip.Activated:Connect(function()
		Net.send("SkipTutorial")
		Bus.Tap:Fire("skip_guide")
		show(false)
	end)
	Net.listen("Tutorial", show)
	Store.Changed:Connect(function(partial)
		if partial.tutorial ~= nil and partial.tutorial == false then
			show(false)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
function TutorialController.current()
	return current
end

return TutorialController

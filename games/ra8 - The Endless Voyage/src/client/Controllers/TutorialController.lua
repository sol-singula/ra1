--[[
The guide's side on screen (master plan §4: one clear thing at a time, never a text wall). The server sends the
step ("Tutorial": { step, total, key, text, target, debris | spot | edge | piece | container | landmark } or
false); here it becomes:
  * a card under the callouts: STEP 2 OF 9, what to do, and a SKIP button
  * a bouncing arrow over the target (the nearest piece of debris, a free spot beside the raft, the workbench, the
    crate, a free edge, the helm, the island's campfire), and the thing itself lit up; for "hook the driftwood"
    this client picks the nearest piece as you move, so whichever one you aim at is the one
  * a soft light beam from you to it
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TutorialController = { Name = "TutorialController", Order = 25 }

local player = Players.LocalPlayer
local C = Theme.Color
local gui, card, label, stepLabel
local arrow, beam, targetAttach, fromAttach, targetPart, spotPad
local current
local glow, glowKey, glowCheckAt = nil, nil, 0
local target, targetGlow
local pickAt = 0

local function modelWith(folderName, attribute, value, deep)
	local folder = workspace:FindFirstChild(folderName)
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute(attribute) == value then
			return m
		end
		if deep then
			for _, d in m:GetChildren() do
				if d:GetAttribute(attribute) == value then
					return d
				end
			end
		end
	end
	return nil
end

local function glowModel(g)
	if g.kind == "debris" then
		return modelWith("Debris", "DebrisId", g.id)
	elseif g.kind == "piece" then
		return modelWith("Rafts", "PieceId", g.id, true)
	elseif g.kind == "container" then
		return modelWith("Islands", "ContainerId", g.id, true)
	elseif g.kind == "landmark" then
		return modelWith("Islands", "Landmark", true, true)
	end
	return nil
end

local function clearGlow()
	if glow then
		glow:Destroy()
	end
	glow, glowKey = nil, nil
	if spotPad then
		spotPad:Destroy()
		spotPad = nil
	end
end

-- Light up the thing to go to (retried now and then: it may not have streamed in yet). A spot on the grid gets
-- a glowing pad instead.
local function updateGlow()
	local g = targetGlow
	if not g then
		clearGlow()
		return
	end
	local key = g.kind .. tostring(g.id)
	if
		glowKey == key
		and ((glow and glow.Parent and glow.Adornee and glow.Adornee.Parent) or (spotPad and spotPad.Parent))
	then
		return
	end
	local t = os.clock()
	if t < glowCheckAt then
		return
	end
	glowCheckAt = t + 0.4
	clearGlow()
	if g.kind == "spot" then
		spotPad = Kit.box(
			workspace:FindFirstChild("Guide") or workspace,
			"GuidePad",
			CFrame.new(g.pos),
			Vector3.new(Constants.TILE - 0.4, 0.2, Constants.TILE - 0.4),
			C.mustard,
			Kit.M.Neon,
			{
				CanCollide = false,
				CanQuery = false,
				Transparency = 0.45,
			}
		)
		glowKey = key
		return
	end
	local m = glowModel(g)
	if not m then
		return
	end
	glow = Instance.new("Highlight")
	glow.Name = "GuideGlow"
	glow.Adornee = m
	glow.FillColor = C.mustard
	glow.FillTransparency = 0.8
	glow.OutlineColor = C.mustard
	glow.OutlineTransparency = 0.1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = workspace:FindFirstChild("Guide") or m
	glowKey = key
end

-- Where the arrow goes this frame. "Hook the driftwood": the nearest piece from here; everything else: what the
-- server said.
local function pickTarget()
	if not current then
		target, targetGlow = nil, nil
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if current.key == "hook" and root then
		local t = os.clock()
		if t >= pickAt or not target then
			pickAt = t + 0.2
			local best, bestD, bestId
			local debris = workspace:FindFirstChild("Debris")
			for _, m in debris and debris:GetChildren() or {} do
				local id = m:GetAttribute("DebrisId")
				if id and not m:GetAttribute("Special") then
					local pos = m:GetPivot().Position
					local d = (pos - root.Position).Magnitude
					if not bestD or d < bestD then
						best, bestD, bestId = pos, d, id
					end
				end
			end
			if best then
				target = best + Vector3.new(0, 1, 0)
				targetGlow = { kind = "debris", id = bestId }
			elseif typeof(current.target) == "Vector3" then
				target = current.target
				targetGlow = current.debris and { kind = "debris", id = current.debris } or nil
			end
		end
		return
	end
	target = typeof(current.target) == "Vector3" and current.target or nil
	if current.debris then
		targetGlow = { kind = "debris", id = current.debris }
	elseif current.piece then
		targetGlow = { kind = "piece", id = current.piece }
	elseif current.container then
		targetGlow = { kind = "container", id = current.container }
	elseif current.landmark then
		targetGlow = { kind = "landmark", id = 1 }
	elseif current.spot and Store.get("raft") then
		local raft = Store.get("raft")
		local layout = OceanLayout.plot(raft.plot or 1)
		local pos = Formulas.tilePosition(layout.center, current.spot.gx, current.spot.gz, 1)
		targetGlow = { kind = "spot", id = current.spot.gx * 100 + current.spot.gz, pos = pos + Vector3.new(0, 0.4, 0) }
	elseif current.edge then
		targetGlow = { kind = "piece", id = current.edge.piece }
	else
		targetGlow = nil
	end
end

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
	Kit.wedge(
		arrow,
		"Head",
		CFrame.new(),
		Vector3.new(0.4, 1.6, 2.2),
		C.mustard,
		Kit.M.Neon,
		{ CanCollide = false, CanQuery = false, CastShadow = false }
	)
	arrow.PrimaryPart = shaft
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
end

local function clearWorld()
	clearGlow()
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
	local was = current
	current = type(view) == "table" and view or nil
	if not current then
		card.Visible = false
		clearWorld()
		return
	end
	card.Visible = true
	stepLabel.Text = current.title or `STEP {current.step} OF {current.total}`
	label.Text = current.text or ""
	if not was or was.key ~= current.key then
		Theme.pop(card)
	end
	pickAt = 0
	pickTarget()
	if target then
		ensureWorld()
	else
		clearWorld()
	end
end

local function step()
	if not current then
		return
	end
	pickTarget()
	if not target then
		clearWorld()
		return
	end
	ensureWorld()
	if not arrow then
		return
	end
	local t = os.clock()
	updateGlow()
	local top = target + Vector3.new(0, (targetGlow and 2.4 or 4) + math.sin(t * 4) * 0.6, 0)
	local spin = CFrame.Angles(0, t * 2, 0)
	local shaft = arrow:FindFirstChild("Shaft")
	local head = arrow:FindFirstChild("Head")
	if shaft and head then
		shaft.CFrame = CFrame.new(top + Vector3.new(0, 1.6, 0)) * spin
		head.CFrame = CFrame.new(top) * spin * CFrame.Angles(math.rad(180), 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	end
	targetPart.CFrame = CFrame.new(target)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and beam then
		if not fromAttach or fromAttach.Parent ~= root then
			fromAttach = Instance.new("Attachment")
			fromAttach.Name = "GuideFrom"
			fromAttach.Position = Vector3.new(0, -2.4, 0)
			fromAttach.Parent = root
			beam.Attachment0 = fromAttach
		end
		beam.Enabled = (root.Position - target).Magnitude > 10
	end
end

function TutorialController:init()
	gui = Theme.screen("Guide", 4, player:WaitForChild("PlayerGui"))
	card = Theme.slab({
		Name = "GuideCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(520, 70),
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

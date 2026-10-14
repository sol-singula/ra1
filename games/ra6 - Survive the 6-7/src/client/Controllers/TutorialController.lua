--[[
The guide's side on screen (master plan §4: the first five minutes, one clear thing at a time, never a text wall).
The server sends the step ("Tutorial": { step, total, key, text, target } or false); here it becomes:
  * a card under the compass: STEP 2 of 7 (or LOOK OUT!), what to do, and a SKIP button
  * a bouncing arrow over the target (beside the nearest tree's trunk, the workbench's blueprint, the crate, the
    Snapcap, the campfire), and the thing itself lit up: for "chop any tree" this client picks the nearest tree an
    axe can chop as you move, so whichever tree you walk to is the one
  * a soft light beam from you to it, so you never have to guess where to go
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local InputController = require(script.Parent.InputController)
local MonsterController = require(script.Parent.MonsterController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TutorialController = { Name = "TutorialController", Order = 25 }

local player = Players.LocalPlayer
local C = Theme.Color
local gui, card, label, stepLabel
local arrow, beam, targetAttach, fromAttach, targetPart
local current -- the step on screen
local glow, glowKey, glowCheckAt = nil, nil, 0 -- the Highlight on the thing to go to
local treeById
local target, targetGlow -- where the arrow is now, and what glows: { kind, id } (per frame, from the step)
local pickAt = 0

-- The model of a tree (by its id), if it has streamed in: trees live in 128-stud chunks under Map.Forest.
local function treeModel(id)
	if not treeById then
		treeById = {}
		for _, t in MapLayout.trees() do
			treeById[t.id] = t
		end
	end
	local t = treeById[id]
	local map = workspace:FindFirstChild("Map")
	local forest = map and map:FindFirstChild("Forest")
	if not t or not forest then
		return nil
	end
	local chunk = forest:FindFirstChild(`Chunk_{math.floor(t.x / 128)}_{math.floor(t.z / 128)}`)
	for _, m in chunk and chunk:GetChildren() or {} do
		if m:GetAttribute("TreeId") == id then
			return m
		end
	end
	return nil
end

-- The model with an attribute, among a folder's children (crates by ContainerId, blueprints by Structure).
local function modelWith(folderName, attribute, value)
	local folder = workspace:FindFirstChild(folderName)
	for _, m in folder and folder:GetChildren() or {} do
		if m:GetAttribute(attribute) == value then
			return m
		end
	end
	return nil
end

local function glowModel(g)
	if g.kind == "tree" then
		return treeModel(g.id)
	elseif g.kind == "container" then
		return modelWith("Loot", "ContainerId", g.id)
	elseif g.kind == "structure" then
		return modelWith("Structures", "Structure", g.id)
	elseif g.kind == "mob" then
		local m = MonsterController.mobs[g.id]
		local folder = workspace:FindFirstChild("Monsters")
		return m and folder and folder:FindFirstChild(m.kind .. g.id) or nil
	end
	return nil
end

local function clearGlow()
	if glow then
		glow:Destroy()
	end
	glow, glowKey = nil, nil
end

-- Light up the thing to go to (retried now and then: it may not have streamed in yet).
local function updateGlow()
	local g = targetGlow
	if not g then
		clearGlow()
		return
	end
	local key = g.kind .. tostring(g.id)
	if glowKey == key and glow and glow.Parent and glow.Adornee and glow.Adornee.Parent then
		return
	end
	local t = os.clock()
	if t < glowCheckAt then
		return
	end
	glowCheckAt = t + 0.4
	local m = glowModel(g)
	if not m then
		clearGlow()
		return
	end
	clearGlow()
	local color = g.kind == "mob" and C.red or C.mustard
	glow = Instance.new("Highlight")
	glow.Name = "GuideGlow"
	glow.Adornee = m
	glow.FillColor = color
	glow.FillTransparency = g.kind == "mob" and 0.7 or 0.8
	glow.OutlineColor = color
	glow.OutlineTransparency = 0.1
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = workspace:FindFirstChild("Guide") or m
	glowKey = key
end

-- Where the arrow goes this frame. "Chop any tree": the nearest tree an axe can chop, from here, so whichever
-- tree you walk to is the one; the Snapcap: where it's drawn; everything else: what the server said.
local function pickTarget()
	if not current then
		target, targetGlow = nil, nil
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if current.key == "chop" and root then
		local t = os.clock()
		if t >= pickAt or not target then
			pickAt = t + 0.2
			local best, bestD
			for _, tree in InputController.treesNear(root.Position, 150) do
				local d = Vector3.new(tree.x - root.Position.X, 0, tree.z - root.Position.Z).Magnitude - tree.trunk
				if not bestD or d < bestD then
					best, bestD = tree, d
				end
			end
			if best then
				local c = Vector3.new(best.x, best.y, best.z)
				local side = Vector3.new(root.Position.X - c.X, 0, root.Position.Z - c.Z)
				side = side.Magnitude > 0.1 and side.Unit or Vector3.new(1, 0, 0)
				target = c + side * (best.trunk + 1.8) + Vector3.new(0, 1.2, 0)
				targetGlow = { kind = "tree", id = best.id }
			elseif typeof(current.target) == "Vector3" then
				target = current.target
				targetGlow = current.tree and { kind = "tree", id = current.tree } or nil
			end
		end
		return
	end
	if current.key == "fight" and current.mob then
		local p = MonsterController.position(current.mob)
		if p then
			target = p + Vector3.new(0, 1, 0)
			targetGlow = { kind = "mob", id = current.mob }
			return
		end
	end
	target = typeof(current.target) == "Vector3" and current.target or nil
	if current.container then
		targetGlow = { kind = "container", id = current.container }
	elseif current.structure then
		targetGlow = { kind = "structure", id = current.structure }
	elseif current.tree then
		targetGlow = { kind = "tree", id = current.tree }
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
	stepLabel.TextColor3 = current.title and C.red or C.mustard
	label.Text = current.text or ""
	if not was or was.key ~= current.key then
		Theme.pop(card) -- (only for a new step: the server refreshes the target every few seconds)
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
	-- (the arrow floats low over what glows, under a tree's branches)
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
		-- the beam fades once you're there
		beam.Enabled = (root.Position - target).Magnitude > 10
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

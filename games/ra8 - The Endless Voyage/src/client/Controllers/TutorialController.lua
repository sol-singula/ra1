--[[
The guide's side on screen (master plan §4: one clear thing at a time, never a text wall). The server sends the
step ("Tutorial": { step, total, key, text, target, debris | spot | edge | piece | container | landmark } or
false); here it becomes:
  * a card under the callouts: STEP 2 OF 9 (then NEXT, forever: it can't be dismissed), what to do, and a
    button when the card can do it for you (HOLD MY ROD)
  * a bouncing arrow over the target (the nearest piece of debris, a free spot beside the raft, the workbench, the
    crate, a free edge, the helm, the island's campfire), and the thing itself lit up and pulsing; for "cast at the
    driftwood" this client picks the nearest piece as you move, so whichever one you aim at is the one
  * a soft light beam from you to it
  * the guide's finger on the screen (UI/Glow): a pulsing ring and a hand on the exact button to press next, for
    whatever is open (BUILD, the piece's PLACE, ACT, the hotbar slot with the rod, the BAG, the crate's slot and
    OPEN, MAKE, SAIL, HOME)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local InputController = require(script.Parent.InputController)
local PanelController = require(script.Parent.PanelController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Glow = require(script.Parent.Parent.UI.Glow)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local TutorialController = { Name = "TutorialController", Order = 25 }

local player = Players.LocalPlayer
local C = Theme.Color
local gui, card, label, stepLabel, actionButton
local arrow, beam, targetAttach, fromAttach, targetPart, spotPad
local current
local glow, glowKey, glowCheckAt = nil, nil, 0
local target, targetGlow
local pickedModel -- the piece the arrow follows ("hook the driftwood")
local pickAt = 0
local uiAt = 0

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
	if (current.key == "cast" or current.gather) and root then
		local t = os.clock()
		-- the nearest piece, chosen a few times a second, followed every frame as it drifts
		if t >= pickAt or not (pickedModel and pickedModel.Parent) then
			pickAt = t + 0.2
			pickedModel = nil
			local bestD
			local debris = workspace:FindFirstChild("Debris")
			for _, m in debris and debris:GetChildren() or {} do
				if m:GetAttribute("DebrisId") and not m:GetAttribute("Special") and not m:GetAttribute("Pull") then
					local d = (m:GetPivot().Position - root.Position).Magnitude
					if not bestD or d < bestD then
						pickedModel, bestD = m, d
					end
				end
			end
		end
		if pickedModel then
			target = pickedModel:GetPivot().Position + Vector3.new(0, 1, 0)
			targetGlow = { kind = "debris", id = pickedModel:GetAttribute("DebrisId") }
		elseif typeof(current.target) == "Vector3" then
			target = current.target
			targetGlow = current.debris and { kind = "debris", id = current.debris } or nil
		else
			target = nil
		end
		return
	end
	target = typeof(current.target) == "Vector3" and current.target or nil
	if current.debris then
		-- a piece the server named (the guide's crate): where it's drawn now, not where it was a moment ago
		local debris = workspace:FindFirstChild("Debris")
		for _, m in debris and debris:GetChildren() or {} do
			if m:GetAttribute("DebrisId") == current.debris then
				target = m:GetPivot().Position + Vector3.new(0, 1.5, 0)
				break
			end
		end
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

-- The on-screen button to press next, for the step and whatever is open ----------------------------------------------
local function screen(name)
	local pg = player:FindFirstChild("PlayerGui")
	return pg and pg:FindFirstChild(name)
end

local function inGui(name, child)
	local g = screen(name)
	return g and g:FindFirstChild(child, true) or nil
end

local function hotbarSlotWith(test)
	local inv = Store.get("inv") or { slots = {} }
	for i = 1, Constants.HOTBAR do
		local slot = inv.slots["h" .. i]
		if slot and test(slot) then
			return i, slot
		end
	end
	return nil
end

local function bagHas(key)
	for id, slot in (Store.get("inv") or { slots = {} }).slots do
		if slot.key == key then
			return id
		end
	end
	return nil
end

local function raftHas(key)
	for _, p in (Store.get("raft") or { pieces = {} }).pieces or {} do
		if p.key == key then
			return true
		end
	end
	return false
end

-- ACT on touch (keyboard players click: the world glow is enough), after the right tool is in hand.
local function actOrTool(toolTest)
	local _, held = Store.held()
	if not (held and toolTest(held)) then
		local i = hotbarSlotWith(toolTest)
		if i then
			return inGui("Hud", "Slot" .. i)
		end
		return nil
	end
	if Theme.inputKind() == "touch" then
		return inGui("Actions", "Act")
	end
	return nil
end

local function isRod(slot)
	local item = Items.get(slot.key)
	return item and item.tool and item.tool.rod ~= nil
end

-- BUILD, then the piece's PLACE in the panel; nothing while the ghost is out (the pad on the raft glows).
local function buildStep(pieceKey)
	if InputController.isBuilding() then
		return nil
	end
	if PanelController.current() == "build" then
		local row = inGui("Panels", "Piece_" .. pieceKey)
		return row and row:FindFirstChild("Place") or row
	end
	if PanelController.current() then
		return nil
	end
	-- QUICK when it would build this very piece, else BUILD
	local quick = inGui("Actions", "Quick")
	if quick and quick.Visible and quick:GetAttribute("Piece") == pieceKey then
		return quick
	end
	return inGui("Actions", "Build")
end

local function uiTarget()
	if not current then
		return nil
	end
	local key = current.key
	local panel = PanelController.current()
	if current.action and actionButton and actionButton.Visible then
		return actionButton
	end
	if current.gather then
		return actOrTool(isRod) -- can't pay for it yet: cast at the debris
	end
	if current.learn then
		-- a blueprint in the bag: BAG, its slot, LEARN
		local slotId
		for id, slot in (Store.get("inv") or { slots = {} }).slots do
			if slot.key == "blueprint" then
				slotId = id
			end
		end
		if panel == "inventory" and slotId then
			if PanelController.picked() == slotId then
				return inGui("Panels", "Use")
			end
			return inGui("Panels", "Slot_" .. slotId)
		elseif not panel then
			return inGui("Hud", "Bag")
		end
		return nil
	end
	if key == "quick" then
		return buildStep(current.quick)
	elseif key == "repair" then
		return actOrTool(function(slot)
			local item = Items.get(slot.key)
			return item and item.tool and item.tool.hammer ~= nil
		end)
	elseif key == "make" then
		if panel == "craft" then
			return inGui("Panels", "Make_" .. (current.item or "hammer"))
		end
		return nil
	elseif key == "sail" then
		if panel == "map" then
			return inGui("Panels", "Sail_" .. (current.dest or ""))
		elseif not panel then
			return inGui("Hud", "Menu_map")
		end
		return nil
	end
	if key == "cast" then
		return actOrTool(isRod)
	elseif key == "tile" then
		return buildStep("floor")
	elseif key == "bench" then
		return buildStep("workbench")
	elseif key == "crate" then
		local slotId = bagHas("supply_crate")
		if not slotId then
			return actOrTool(isRod)
		end
		if panel == "inventory" then
			if PanelController.picked() == slotId then
				return inGui("Panels", "Use")
			end
			return inGui("Panels", "Slot_" .. slotId)
		elseif not panel then
			return inGui("Hud", "Bag")
		end
		return nil
	elseif key == "net" then
		return buildStep("net")
	elseif key == "helm" then
		if not raftHas("helm") then
			return buildStep("helm")
		end
		if panel == "map" then
			return inGui("Panels", "Sail_palm_key")
		end
		return nil
	elseif key == "home" then
		if panel == "map" then
			return inGui("Panels", "Home")
		end
		return nil
	end
	return nil
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
	-- a proper game arrow: flat like a sign (a shaft and a triangle head), bright yellow with a thick dark outline and a
	-- white shine, its tip at the pivot pointing down; every frame it turns its face to the camera and bobs, so from
	-- anywhere it reads as an arrow pointing at the thing to do
	local pivot = Kit.box(arrow, "Pivot", CFrame.new(), Vector3.new(0.2, 0.2, 0.2), C.mustard, Kit.M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local function shape(name, x, apex, headW, headH, shaftW, shaftH, color, thick)
		local extra = { CanCollide = false, CanQuery = false, CastShadow = false }
		-- the head: two wedges back to back, a triangle with its point at y = apex
		for _, side in { 1, -1 } do
			Kit.wedge(
				arrow,
				name .. "Head",
				CFrame.new(x, apex + headH / 2, side * headW / 4)
					* (side < 0 and CFrame.Angles(0, math.pi, 0) or CFrame.new())
					* CFrame.Angles(math.pi, 0, 0),
				Vector3.new(thick, headH, headW / 2),
				color,
				Kit.M.SmoothPlastic,
				extra
			)
		end
		-- the shaft, overlapping the head a little
		Kit.box(
			arrow,
			name .. "Shaft",
			CFrame.new(x, apex + headH + shaftH / 2 - 0.05, 0),
			Vector3.new(thick, shaftH + 0.1, shaftW),
			color,
			Kit.M.SmoothPlastic,
			extra
		)
	end
	-- the fill (in front, facing +X) and the outline (behind it, bigger by T all round)
	local W, H, SW, SH, T = 3.0, 1.7, 1.15, 2.0, 0.24
	local slope = (W / 2) / H -- the head's half-width per stud of height
	local down = T * math.sqrt(1 + slope * slope) / slope -- how far the outline's point sits below the fill's
	shape("Fill", 0.12, 0, W, H, SW, SH, C.mustard, 0.5)
	shape("Outline", -0.06, -down, 2 * (H + T + down) * slope, H + T + down, SW + 2 * T, SH, C.ink, 0.5)
	Kit.box(
		arrow,
		"Shine",
		CFrame.new(0.39, H + SH * 0.55, -SW / 2 + 0.22),
		Vector3.new(0.06, SH * 0.7, 0.18),
		C.white,
		Kit.M.SmoothPlastic,
		{ CanCollide = false, CanQuery = false, CastShadow = false }
	)
	arrow.PrimaryPart = pivot
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
		Glow.show(nil)
		return
	end
	uiAt = 0
	card.Visible = true
	stepLabel.Text = current.title or `STEP {current.step} OF {current.total}`
	label.Text = current.text or ""
	actionButton.Visible = current.action ~= nil
	actionButton.Text = current.action == "invite" and "💌 INVITE" or "🎣 HOLD MY ROD"
	actionButton.BackgroundColor3 = current.action == "invite" and C.mustard or C.good
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

local function screenStep()
	local t = os.clock()
	if t >= uiAt then
		uiAt = t + 0.1
		local ok, want = pcall(uiTarget)
		Glow.show(ok and want or nil)
	end
	Glow.step(t)
end

local function step()
	if not current then
		return
	end
	screenStep()
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
	if glow and glow.Parent then
		-- the whole thing pulses: bright, then brighter
		local pulse = 0.5 + 0.5 * math.sin(t * 5)
		glow.FillTransparency = 0.75 - pulse * 0.45
		glow.OutlineTransparency = 0
		glow.FillColor = C.mustard:Lerp(C.white, pulse * 0.5)
	end
	if spotPad and spotPad.Parent then
		spotPad.Transparency = 0.6 - (0.5 + 0.5 * math.sin(t * 5)) * 0.4
	end
	-- bob above the target, the face turned to the camera (local +X toward it)
	local top = target + Vector3.new(0, (targetGlow and 1.6 or 2.4) + math.abs(math.sin(t * 3.2)) * 0.9, 0)
	local cam = workspace.CurrentCamera
	local to = cam and cam.CFrame and (cam.CFrame.Position - top) or Vector3.new(1, 0, 0)
	local flat = Vector3.new(to.X, 0, to.Z)
	local yaw = flat.Magnitude > 0.01 and math.atan2(-flat.Z, flat.X) or 0
	arrow:PivotTo(CFrame.new(top) * CFrame.Angles(0, yaw, 0))
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
	-- no SKIP: the card always says what to do next. When it can do it for you, a button does.
	actionButton = Theme.button({
		Name = "Action",
		Text = "🎣 HOLD MY ROD",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(110, 46),
		TextSize = 13,
		Visible = false,
		Parent = card,
	})
	actionButton.Activated:Connect(function()
		local action = current and current.action
		if action == "invite" then
			Bus.Menu:Fire("invite") -- (the invite prompt is the client's)
		elseif action then
			Bus.Tap:Fire("guide_" .. action)
			Net.send("GuideAction", action)
		end
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
TutorialController.uiTarget = uiTarget

return TutorialController

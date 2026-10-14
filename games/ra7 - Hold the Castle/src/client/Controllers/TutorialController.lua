--[[
The first five minutes, from your side (master plan §12; TutorialService decides the steps): one short line in a
card at the top left ("2 of 7 · Bring it to a glowing blueprint and hammer it!") with SKIP, a sparkle trail on
the ground from you to where to go, and a bouncing arrow over the spot that says how far it is. The thing to
touch (the rock pile, the blueprint) also gets a soft glow. A scout moves, so the "swing at it" step follows the
nearest scout.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local TutorialController = { Name = "TutorialController", Order = 50 }

local gui, cardFrame, stepLabel, textLabel
local anchor, beam, arrow, arrowText, highlight, sparkles
local current -- the last step message
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- The model at (or very near) a target position: a rock pile or a castle piece, to make it glow.
local function modelAt(pos)
	local best, bestD = nil, 6
	for _, name in { "Nodes", "Castle" } do
		local f = workspace:FindFirstChild(name)
		if f then
			for _, m in f:GetChildren() do
				if m:IsA("Model") then
					local ok, pivot = pcall(m.GetPivot, m)
					if ok then
						local p = pivot.Position
						local d = Vector2.new(p.X - pos.X, p.Z - pos.Z).Magnitude
						if d < bestD then
							best, bestD = m, d
						end
					end
				end
			end
		end
	end
	return best
end

local function setHighlight(model)
	if highlight and highlight.Adornee == model then
		return
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if model then
		highlight = new("Highlight", {
			Name = "GuideGlow",
			Adornee = model,
			FillColor = C.mustard,
			FillTransparency = 0.7,
			OutlineColor = C.mustard,
			OutlineTransparency = 0,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Parent = gui,
		})
	end
end

local function hideMarker()
	if anchor then
		anchor.Parent = nil
	end
	setHighlight(nil)
end

local function buildMarker()
	anchor = Kit.box(nil, "GuideTarget", CFrame.new(), Vector3.new(0.4, 0.4, 0.4), C.mustard, Enum.Material.Neon, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	local a1 = new("Attachment", { Name = "To", Position = Vector3.new(0, 0.6, 0), Parent = anchor })
	beam = new("Beam", {
		Name = "Trail",
		Attachment1 = a1,
		Texture = SPARKLE,
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 3,
		TextureSpeed = 1.6,
		Color = ColorSequence.new(C.mustard, C.white),
		LightEmission = 1,
		LightInfluence = 0,
		Width0 = 1.6,
		Width1 = 1.6,
		FaceCamera = true,
		Segments = 20,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(0.2, 0.1),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		Parent = anchor,
	})
	sparkles = new("ParticleEmitter", {
		Name = "Sparkles",
		Texture = SPARKLE,
		Color = ColorSequence.new(C.mustard),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 14,
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(180, 180),
		Parent = a1,
	})
	arrow = new("BillboardGui", {
		Name = "Arrow",
		Size = UDim2.fromOffset(120, 110),
		StudsOffset = Vector3.new(0, 9, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		Parent = anchor,
	})
	Theme.text({
		Name = "Icon",
		Text = "⬇️",
		Size = UDim2.new(1, 0, 0, 72),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = arrow,
	})
	arrowText = Theme.title({
		Name = "Far",
		Text = "",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 76),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.mustard,
		Parent = arrow,
	})
end

-- Where the current step points right now (a scout moves; everything else stays put).
function TutorialController.targetPos()
	local msg = current
	if not msg or typeof(msg.target) ~= "Vector3" then
		return nil
	end
	if msg.key == "fight" then
		local ok, horde = pcall(require, script.Parent.HordeController)
		if ok and horde.near then
			local r = root()
			local from = r and r.Position or msg.target
			local best, bestD
			for _, n in
				horde.near(from, 220, function(k)
					return k == "scout"
				end)
			do
				local d = (n.pos - from).Magnitude
				if not bestD or d < bestD then
					best, bestD = n, d
				end
			end
			if best then
				return best.pos
			end
		end
	end
	return msg.target
end

local bob = 0
local glowAt = 0
local function updateMarker(dt)
	local target = TutorialController.targetPos()
	local r = root()
	if not target or not r then
		hideMarker()
		return
	end
	if not anchor then
		buildMarker()
	end
	anchor.Parent = workspace
	anchor.CFrame = CFrame.new(target)
	local from = r:FindFirstChild("GuideFrom")
		or new("Attachment", { Name = "GuideFrom", Position = Vector3.new(0, -2.4, 0), Parent = r })
	beam.Attachment0 = from
	local far = (target - r.Position).Magnitude
	-- close enough: the trail goes, the arrow stays
	beam.Enabled = far > 9
	sparkles.Enabled = true
	arrowText.Text = far > 9 and `{math.floor(far)}m` or ""
	if not Theme.reducedMotion() then
		bob += dt
		arrow.StudsOffset = Vector3.new(0, 9 + math.abs(math.sin(bob * 3.2)) * 2.2, 0)
	end
	-- (looking for the model to glow walks the castle: a few times a second is plenty)
	glowAt -= dt
	if glowAt <= 0 then
		glowAt = 0.4
		if current and (current.key == "mine" or current.key == "build") then
			setHighlight(modelAt(target))
		else
			setHighlight(nil)
		end
	end
end

function TutorialController.show(msg)
	current = msg or nil
	if not msg then
		cardFrame.Visible = false
		hideMarker()
		return
	end
	glowAt = 0 -- a new step: find its thing to glow right away
	stepLabel.Text = msg.total and msg.total > 1 and `GUIDE · {msg.step} OF {msg.total}` or "GUIDE"
	textLabel.Text = msg.text or ""
	if not cardFrame.Visible then
		cardFrame.Visible = true
	end
	Theme.pop(cardFrame)
end

function TutorialController.current()
	return current
end

function TutorialController:init()
	gui = Theme.screen("Guide", 11, player:WaitForChild("PlayerGui"))
	cardFrame = Theme.slab({
		Name = "Card",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.fromOffset(300, 106),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	cardFrame.UIStroke.Color = C.mustard
	stepLabel = Theme.title({
		Name = "Step",
		Text = "GUIDE",
		Size = UDim2.new(1, -96, 0, 22),
		Position = UDim2.fromOffset(12, 6),
		TextColor3 = C.mustard,
		outline = 2,
		Parent = cardFrame,
	})
	textLabel = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -24, 0, 66),
		Position = UDim2.fromOffset(12, 32),
		TextYAlignment = Enum.TextYAlignment.Top,
		outline = 2,
		Parent = cardFrame,
	})
	local skip = Theme.button({
		Name = "Skip",
		Text = "SKIP",
		BackgroundColor3 = C.muted,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(72, 26),
		Parent = cardFrame,
	})
	skip.Activated:Connect(function()
		Bus.Tap:Fire("skip_guide")
		Net.send("SkipTutorial")
		TutorialController.show(nil)
	end)
	Net.listen("Tutorial", function(msg)
		TutorialController.show(type(msg) == "table" and msg or nil)
	end)
	RunService.Heartbeat:Connect(updateMarker)
end

return TutorialController

-- The first-time guide, from your side (TutorialService decides the steps): a small numbered card on the left
-- ("2 of 7 · Pick a colour on your door sign 🎨") with SKIP, and a glowing line from you to the thing to touch, which
-- also gets a soft outline. The card never covers the departure timer or the thumbs' corners.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local TutorialController = { Name = "TutorialController", Order = 50 }

local gui, cardFrame, stepLabel, textLabel
local beam, highlight
local current -- the last step message

local function setTarget(target)
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if beam then
		beam.Enabled = false
	end
	if typeof(target) ~= "Instance" or not target.Parent then
		return
	end
	local adornee = target:IsA("BasePart") and target or nil
	if adornee then
		highlight = new("Highlight", {
			Name = "GuideHighlight",
			Adornee = adornee.Parent and adornee.Parent:IsA("Model") and adornee.Parent or adornee,
			FillColor = C.amber,
			FillTransparency = 0.75,
			OutlineColor = C.amber,
			OutlineTransparency = 0.1,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			Parent = gui,
		})
	end
end

local function updateBeam()
	local target = current and current.target
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if typeof(target) ~= "Instance" or not target.Parent or not target:IsA("BasePart") or not hrp then
		if beam then
			beam.Enabled = false
		end
		return
	end
	if not beam then
		beam = new("Beam", {
			Name = "GuideBeam",
			Color = ColorSequence.new(C.amber),
			Width0 = 0.4,
			Width1 = 0.4,
			FaceCamera = true,
			LightEmission = 1,
			Transparency = NumberSequence.new(0.25),
			TextureSpeed = 1.5,
			Parent = workspace,
		})
	end
	local a0 = hrp:FindFirstChild("GuideFrom")
		or new("Attachment", { Name = "GuideFrom", Position = Vector3.new(0, -1.5, 0), Parent = hrp })
	local a1 = target:FindFirstChild("GuideTo") or new("Attachment", { Name = "GuideTo", Parent = target })
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Enabled = true
end

function TutorialController.show(msg)
	current = msg or nil
	if not msg then
		cardFrame.Visible = false
		setTarget(nil)
		return
	end
	stepLabel.Text = string.upper(`Guide · {msg.step} of {msg.total}`)
	textLabel.Text = msg.text or ""
	if not cardFrame.Visible then
		cardFrame.Visible = true
		Theme.pop(cardFrame)
	end
	setTarget(msg.target)
end

function TutorialController.current()
	return current
end

function TutorialController:init()
	gui = Theme.screen("Guide", 11, player:WaitForChild("PlayerGui"))
	cardFrame = Theme.slab({
		Name = "Card",
		Position = UDim2.new(0, 8, 0, 200),
		Size = UDim2.fromOffset(236, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	cardFrame.UIStroke.Color = C.amber
	Theme.padding(10, 8).Parent = cardFrame
	Theme.list("y", 6).Parent = cardFrame
	stepLabel = Theme.title({
		Name = "Step",
		Text = "Guide",
		Size = UDim2.new(1, 0, 0, 15),
		TextColor3 = C.amber,
		LayoutOrder = 1,
		Parent = cardFrame,
	})
	textLabel = Theme.text({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 15,
		LayoutOrder = 2,
		Parent = cardFrame,
	})
	local skip = Theme.button({
		Name = "Skip",
		Text = "Skip guide",
		secondary = true,
		Size = UDim2.fromOffset(110, 28),
		LayoutOrder = 3,
		Parent = cardFrame,
	})
	skip.Activated:Connect(function()
		Net.send("SkipTutorial")
		TutorialController.show(nil)
	end)
	Net.listen("Tutorial", function(msg)
		TutorialController.show(msg ~= false and msg or nil)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			updateBeam()
		end
	end)
end

return TutorialController

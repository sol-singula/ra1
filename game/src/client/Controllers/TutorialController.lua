-- Tutorial UI: the step card on the left, a bouncing arrow over the thing to use next, and a glow on it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local TutorialController = { Name = "TutorialController", Order = 60 }

local gui, card, stepLabel, textLabel
local arrow, highlight

local function clearMarker()
	if arrow then
		arrow:Destroy()
		arrow = nil
	end
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
end

local function mark(target)
	clearMarker()
	if not target then
		return
	end
	local adornee = target:IsA("Model") and (target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")) or target
	highlight = new("Highlight", {
		Adornee = target,
		FillColor = C.mustard,
		FillTransparency = 0.65,
		OutlineColor = C.mustard,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Parent = gui,
	})
	arrow = new("BillboardGui", {
		Name = "TutorialArrow",
		Adornee = adornee,
		Size = UDim2.fromOffset(90, 110),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		MaxDistance = 400,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local holder =
		new("Frame", { Name = "Holder", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = arrow })
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Text = "HERE",
		Font = Theme.Display,
		TextScaled = true,
		TextColor3 = C.mustard,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		Parent = holder,
	})
	new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 80),
		Text = "▼",
		Font = Theme.Display,
		TextScaled = true,
		TextColor3 = C.mustard,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = C.ink,
		Parent = holder,
	})
end

local function show(info)
	if not info then
		card.Visible = false
		clearMarker()
		return
	end
	card.Visible = true
	stepLabel.Text = `TUTORIAL · STEP {info.step} OF {info.total}`
	textLabel.Text = info.text
	mark(info.target)
end

function TutorialController:init()
	gui = new(
		"ScreenGui",
		{ Name = "Tutorial", ResetOnSpawn = false, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") }
	)
	card = Theme.card({
		Name = "Card",
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(16, 282),
		BackgroundColor3 = C.paper,
		Visible = false,
		Parent = gui,
	})
	Theme.padding(14).Parent = card
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	stepLabel = Theme.text({
		Text = "",
		Font = Theme.Display,
		TextColor3 = C.ketchup,
		TextSize = 20,
		TextScaled = false,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = 1,
		Parent = card,
	})
	textLabel = Theme.text({
		Text = "",
		TextSize = 20,
		TextScaled = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = 2,
		Parent = card,
	})
	local skip = Theme.button({
		Text = "Skip tutorial",
		BackgroundColor3 = C.white,
		TextSize = 16,
		TextScaled = false,
		Size = UDim2.fromOffset(130, 32),
		LayoutOrder = 3,
		Parent = card,
	})
	skip.Activated:Connect(function()
		Net.send("SkipTutorial")
	end)
	Net.listen("Tutorial", show)

	-- bob the arrow up and down
	RunService.RenderStepped:Connect(function()
		if arrow then
			arrow.StudsOffset = Vector3.new(0, 6 + math.abs(math.sin(os.clock() * 4)) * 1.2, 0)
		end
	end)
end

return TutorialController

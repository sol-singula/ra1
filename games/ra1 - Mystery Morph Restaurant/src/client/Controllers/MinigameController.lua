-- Cooking feedback: the chopping timing ring, the drink pour meter, and progress bars over food on the
-- grill and fryer. Timing uses the server clock (GetServerTimeNow) so what the player sees matches what the
-- server judges.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new

local MinigameController = { Name = "MinigameController", Order = 30 }

local gui
local chop, pour -- active sessions
local ACTION = "MMR_Minigame"

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function bindKeys(onPress)
	ContextActionService:BindActionAtPriority(ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			onPress()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

local function unbindKeys()
	ContextActionService:UnbindAction(ACTION)
end

-- Chopping ------------------------------------------------------------------------------------------------
local function endChop()
	if chop then
		chop.frame:Destroy()
		chop.conn:Disconnect()
		chop = nil
		unbindKeys()
	end
end

local function startChop(info)
	endChop()
	local frame = Theme.card({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(460, 190),
		Parent = gui,
	})
	Theme.text({
		Text = `Chop: {info.ingredient}`,
		Font = Theme.Display,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 10),
		Parent = frame,
	})
	local track = new("Frame", {
		Size = UDim2.new(1, -40, 0, 26),
		Position = UDim2.fromOffset(20, 56),
		BackgroundColor3 = Color3.fromRGB(58, 61, 85),
		BorderSizePixel = 0,
		Parent = frame,
	}, { Theme.corner(10) })
	new("Frame", {
		Size = UDim2.fromScale(0.5, 1),
		Position = UDim2.fromScale(0.25, 0),
		BackgroundColor3 = C.mustard,
		BorderSizePixel = 0,
		Parent = track,
	}, { Theme.corner(8) })
	new("Frame", {
		Size = UDim2.fromScale(0.2, 1),
		Position = UDim2.fromScale(0.4, 0),
		BackgroundColor3 = C.good,
		BorderSizePixel = 0,
		Parent = track,
	}, { Theme.corner(8) })
	local marker = new("Frame", {
		Size = UDim2.new(0, 8, 1, 10),
		Position = UDim2.new(0, 0, 0, -5),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Parent = track,
	}, { Theme.corner(4) })
	local pips = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 22),
		Position = UDim2.fromOffset(20, 92),
		Parent = frame,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	for i = 1, info.taps do
		new("Frame", {
			Name = "Pip" .. i,
			Size = UDim2.fromOffset(40, 18),
			BackgroundColor3 = i <= info.done and C.teal or C.white,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = pips,
		}, { Theme.corner(6), Theme.stroke(2) })
	end
	local button = Theme.button({
		Text = "CHOP!  (Space / tap)",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.new(0, 20, 1, -56),
		Parent = frame,
	})
	local function tap()
		Net.send("ChopTap")
	end
	button.Activated:Connect(tap)
	bindKeys(tap)
	-- the marker sweeps 0 → 1 each period; the green zone is the middle (Formulas.chopTapScore)
	local conn = RunService.RenderStepped:Connect(function()
		local phase = ((serverNow() - info.startAt) % info.period) / info.period
		marker.Position = UDim2.new(phase, 0, 0, -5)
	end)
	chop = { frame = frame, conn = conn, pips = pips }
	-- walking away cancels
	task.spawn(function()
		local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		local origin = hrp and hrp.Position
		while chop and chop.frame == frame and hrp and origin do
			if (hrp.Position - origin).Magnitude > 8 then
				Net.send("ChopCancel")
				break
			end
			task.wait(0.2)
		end
	end)
end

local function chopProgress(done, score)
	if not chop then
		return
	end
	local pip = chop.pips:FindFirstChild("Pip" .. done)
	if pip then
		pip.BackgroundColor3 = score >= 1 and C.good or (score >= 0.8 and C.mustard or C.ketchup)
	end
end

-- Pouring -------------------------------------------------------------------------------------------------
local function endPour()
	if pour then
		pour.frame:Destroy()
		pour.conn:Disconnect()
		pour = nil
		unbindKeys()
	end
end

local function startPour(info)
	endPour()
	local frame = Theme.card({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(300, 300),
		Parent = gui,
	})
	Theme.text({
		Text = `Pour: {info.recipe}`,
		Font = Theme.Display,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.fromOffset(12, 10),
		Parent = frame,
	})
	local cup = new("Frame", {
		Size = UDim2.fromOffset(110, 170),
		Position = UDim2.new(0.5, -55, 0, 50),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	}, { Theme.corner(10), Theme.stroke(3) })
	local fill = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = C.teal,
		BorderSizePixel = 0,
		Parent = cup,
	})
	-- the Perfect band: 85 %-100 % of the cup
	new("Frame", {
		Size = UDim2.new(1, 0, 0.15, 0),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = C.good,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = cup,
	})
	local button = Theme.button({
		Text = "STOP!  (Space / tap)",
		Size = UDim2.new(1, -40, 0, 44),
		Position = UDim2.new(0, 20, 1, -56),
		Parent = frame,
	})
	local function stop()
		Net.send("PourStop")
	end
	button.Activated:Connect(stop)
	bindKeys(stop)
	local conn = RunService.RenderStepped:Connect(function()
		local f = math.min((serverNow() - info.startAt) / info.seconds, info.maxFill)
		fill.Size = UDim2.fromScale(1, math.min(f, 1))
		fill.BackgroundColor3 = f > 1 and C.ketchup or C.teal
	end)
	pour = { frame = frame, conn = conn }
end

-- Heat progress bars over grill / fryer items --------------------------------------------------------------
local bars = {} -- [part] = billboard

local function attachBar(part)
	local bb = new("BillboardGui", {
		Size = UDim2.fromOffset(90, 26),
		StudsOffset = Vector3.new(0, 1.6, 0),
		AlwaysOnTop = true,
		MaxDistance = 40,
		Adornee = part,
		Parent = Players.LocalPlayer.PlayerGui,
	})
	local _, fillBar = Theme.bar({ Size = UDim2.new(1, 0, 0, 10), Parent = bb }, C.mustard)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 11),
		Font = Theme.Body,
		TextScaled = true,
		TextColor3 = C.white,
		TextStrokeTransparency = 0,
		Text = "",
		Parent = bb,
	})
	bars[part] = { bb = bb, fill = fillBar, label = label }
end

local function updateBars()
	for part, b in bars do
		if not part.Parent then
			b.bb:Destroy()
			bars[part] = nil
		else
			local elapsed = serverNow() - (part:GetAttribute("StartAt") or serverNow())
			local tReady = part:GetAttribute("TReady") or 1
			local window = part:GetAttribute("Window") or 2
			local burnAfter = part:GetAttribute("BurnAfter") or 6
			local fireAfter = part:GetAttribute("FireAfter") or 4
			local grade = Formulas.heatGrade(elapsed, tReady, window, burnAfter, fireAfter)
			local total = tReady + burnAfter + fireAfter
			b.fill.Size = UDim2.fromScale(math.clamp(elapsed / total, 0, 1), 1)
			b.fill.BackgroundColor3 = ({
				UNDERCOOKED = C.mustard,
				PERFECT = C.good,
				GOOD = C.teal,
				BURNED = C.ketchup,
				RUINED = C.ink,
			})[grade]
			b.label.Text = grade
		end
	end
end

function MinigameController:init()
	gui = new("ScreenGui", {
		Name = "Minigames",
		ResetOnSpawn = false,
		DisplayOrder = 4,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	Net.listen("ChopStart", startChop)
	Net.listen("ChopProgress", chopProgress)
	Net.listen("ChopEnd", endChop)
	Net.listen("PourStart", startPour)
	Net.listen("PourEnd", endPour)
	CollectionService:GetInstanceAddedSignal("MMR_Cooking"):Connect(attachBar)
	for _, part in CollectionService:GetTagged("MMR_Cooking") do
		attachBar(part)
	end
	RunService.Heartbeat:Connect(updateBars)
end

return MinigameController

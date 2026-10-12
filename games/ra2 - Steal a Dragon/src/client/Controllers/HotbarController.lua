-- The hotbar: our own, in place of Roblox's (which shows only a tool's name or picture). One chunky slot per tool
-- (ToolService gives them, in the order of their "Slot" attribute) with the tool's picture, its key number and a
-- count badge (the Speed Potions left). Tap or click a slot, or press 1-3, to hold that tool; again to put it
-- away. LB / RB step through the tools on a gamepad.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local HotbarController = { Name = "HotbarController", Order = 12 }

local SLOT = 74 -- slot size on the 1000 x 560 canvas
local GAP = 10
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }

local gui, bar
local slots = {} -- [i] = { button, image, count, label, key }

-- The player's tools in slot order (from the Backpack and the one in hand).
function HotbarController.tools()
	local list = {}
	for _, holder in { player:FindFirstChild("Backpack"), player.Character } do
		if holder then
			for _, t in holder:GetChildren() do
				if t:IsA("Tool") then
					table.insert(list, t)
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Slot") or 99) < (b:GetAttribute("Slot") or 99)
	end)
	return list
end

-- Hold the tool in slot i, or put it away if it's already in hand.
function HotbarController.use(i)
	local tool = HotbarController.tools()[i]
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not hum then
		return
	end
	if tool.Parent == character then
		hum:UnequipTools()
	else
		hum:EquipTool(tool)
	end
	HotbarController.refresh()
end

local function slot(i)
	if slots[i] then
		return slots[i]
	end
	local button = Theme.button({
		Name = "Slot" .. i,
		Text = "",
		BackgroundColor3 = C.slate,
		Size = UDim2.fromOffset(SLOT, SLOT),
		LayoutOrder = i,
		Parent = bar,
	})
	local image = new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.86, 0.86),
		Position = UDim2.fromScale(0.07, 0.07),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
		Parent = button,
	})
	local label = Theme.text({
		Name = "Label",
		Text = "",
		Size = UDim2.fromScale(1, 0.32),
		Position = UDim2.fromScale(0, 0.68),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = button,
	})
	local key = Theme.text({
		Name = "Key",
		Text = tostring(i),
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(-4, -6),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = button,
	})
	local count = new("TextLabel", {
		Name = "Count",
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(30, 24),
		Position = UDim2.new(1, 10, 1, 8),
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.white,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { Theme.corner("round"), Theme.stroke(2) })
	button.Activated:Connect(function()
		HotbarController.use(i)
	end)
	slots[i] = { button = button, image = image, count = count, label = label, key = key }
	return slots[i]
end

function HotbarController.refresh()
	if not bar then
		return
	end
	local tools = HotbarController.tools()
	local character = player.Character
	for i = 1, math.max(#tools, #slots) do
		local tool = tools[i]
		if tool then
			local s = slot(i)
			s.button.Visible = true
			local texture = tool.TextureId
			s.image.Image = texture or ""
			s.image.Visible = texture ~= nil and texture ~= ""
			s.label.Text = s.image.Visible and "" or tool.Name -- no picture: show the name instead
			local n = tool:GetAttribute("Count")
			s.count.Visible = n ~= nil
			s.count.Text = n and ("x" .. n) or ""
			s.count.BackgroundColor3 = (n == 0) and Color3.fromRGB(120, 120, 130) or C.red
			local held = tool.Parent == character
			s.button.BackgroundColor3 = held and C.mustard or C.slate
			s.button.UIStroke.Color = held and C.white or C.ink
			s.button.UIStroke.Thickness = held and 4 or 3
		elseif slots[i] then
			slots[i].button.Visible = false
		end
	end
	bar.Size = UDim2.fromOffset(#tools * SLOT + math.max(0, #tools - 1) * GAP, SLOT)
end

function HotbarController:init()
	-- Roblox's own hotbar off (retry: StarterGui may not accept it in the first frames)
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				break
			end
			task.wait(0.5)
		end
	end)
	gui = Theme.screen("Hotbar", 2, player:WaitForChild("PlayerGui"))
	bar = new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(0, SLOT),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	ContextActionService:BindAction("HotbarKeys", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			local i = table.find(KEYS, input.KeyCode)
			if i then
				HotbarController.use(i)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(KEYS))
	ContextActionService:BindAction("HotbarCycle", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			local tools = HotbarController.tools()
			local current = 0
			for i, t in tools do
				if t.Parent == player.Character then
					current = i
				end
			end
			local step = input.KeyCode == Enum.KeyCode.ButtonL1 and -1 or 1
			local nextI = (current - 1 + step) % math.max(#tools, 1) + 1
			HotbarController.use(nextI)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			HotbarController.refresh()
		end
	end)
end

return HotbarController

--[[
A tiny UI kit: mobile-first panels that scale with the screen (one UIScale per ScreenGui, designed at 1280 x 720).

  UI.screen(name)                     a ScreenGui in PlayerGui (ResetOnSpawn off, CoreUISafeInsets), scaled to the
                                      viewport
  UI.MIN_TAP                          48: the smallest tap target, in px at 1x
  UI.frame(parent, props)             a rounded panel
  UI.label(parent, text, props)
  UI.button(parent, text, onClick, props)   a big tap target (TextButton.Activated)
  UI.sellButton(parent, text, onClick, props)   a Sell button: leaf green, darker while pressed, white text, dark
                                      outline (GA-02: gold is for mutations only)
  UI.mutChip(parent, key, props)      the mutation chip: "Wet x2" / "Golden x20" / "Wet+Golden x40" in the
                                      Config.MutationVisuals.chips colours
  UI.list(parent, padding?)           vertical layout for the children
  UI.modal(name, title)               a centred card with a title and a close button -> { gui, card, body, close }
  UI.scaleFor(viewport)               the UIScale for a viewport size
  UI.money(n) / UI.duration(sec)      "12,345" / "2h 15m", "4m 05s", "12s"
  UI.COLORS
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local UI = {}

UI.MIN_TAP = 48

UI.COLORS = {
	card = Color3.fromRGB(255, 248, 230),
	ink = Color3.fromRGB(60, 44, 30),
	green = Color3.fromRGB(86, 170, 76),
	red = Color3.fromRGB(210, 80, 70),
	-- GA-02 section 0: gold appears only on mutation chips; Sell is leaf green; the Block Party meter is
	-- sunflower-petal yellow on a dark track
	mutGold = Color3.fromHex("#FFC300"),
	sell = Color3.fromHex("#4CAF50"),
	sellPressed = Color3.fromHex("#3D8C40"),
	outline = Color3.fromHex("#1E1B2E"),
	meter = Color3.fromHex("#FFE066"),
	meterTrack = Color3.fromHex("#1E1B2E"),
	-- a highlight that isn't gold (today's calendar day)
	highlight = Color3.fromHex("#FFE066"),
	grey = Color3.fromRGB(170, 160, 150),
	shade = Color3.fromRGB(0, 0, 0),
}

local DESIGN = Vector2.new(1280, 720)

function UI.scaleFor(viewport)
	local s = math.min(viewport.X / DESIGN.X, viewport.Y / DESIGN.Y)
	return math.clamp(s, 0.55, 1.6)
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 14)
	c.Parent = parent
end

local function apply(inst, props)
	for k, v in props or {} do
		inst[k] = v
	end
	return inst
end

function UI.screen(name)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- clear of the notch, the Roblox top bar and home bar
	local scale = Instance.new("UIScale")
	local camera = workspace.CurrentCamera
	local function rescale()
		scale.Scale = UI.scaleFor(camera.ViewportSize)
	end
	rescale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	scale.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	return gui
end

function UI.frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UI.COLORS.card
	f.BorderSizePixel = 0
	corner(f)
	apply(f, props)
	f.Parent = parent
	return f
end

function UI.label(parent, text, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = UI.COLORS.ink
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Size = UDim2.new(1, 0, 0, 32)
	apply(l, props)
	l.Parent = parent
	return l
end

function UI.button(parent, text, onClick, props)
	local b = Instance.new("TextButton")
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = UI.COLORS.green
	b.Font = Enum.Font.GothamBlack
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Size = UDim2.new(1, 0, 0, 52) -- at least 44 pt on phones
	corner(b, 12)
	apply(b, props)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

function UI.sellButton(parent, text, onClick, props)
	local b = UI.button(parent, text, onClick, { BackgroundColor3 = UI.COLORS.sell, AutoButtonColor = false })
	b.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = UI.COLORS.outline
	stroke.Thickness = 2
	stroke.Parent = b
	b:SetAttribute("PressedColor", UI.COLORS.sellPressed)
	pcall(function()
		b.MouseButton1Down:Connect(function()
			b.BackgroundColor3 = UI.COLORS.sellPressed
		end)
		b.MouseButton1Up:Connect(function()
			b.BackgroundColor3 = UI.COLORS.sell
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = UI.COLORS.sell
		end)
	end)
	apply(b, props)
	return b
end

function UI.mutChip(parent, key, props)
	local chips = Config.MutationVisuals.chips
	local style = chips[key]
	if not style then
		return nil
	end
	local chip = Instance.new("TextLabel")
	chip.Name = "MutChip"
	chip.Text = Config.MutationVisuals.labels[key]
	chip.BackgroundColor3 = Color3.fromHex(style.fill)
	chip.BorderSizePixel = 0
	chip.TextColor3 = Color3.fromHex(chips.text)
	chip.TextStrokeColor3 = Color3.fromHex(chips.textStroke)
	chip.TextStrokeTransparency = 0
	chip.Font = Enum.Font.GothamBlack
	chip.TextScaled = true
	chip.Size = UDim2.fromOffset(110, 22)
	corner(chip, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromHex(style.stroke)
	stroke.Thickness = chips.strokeThickness
	stroke.Parent = chip
	chip:SetAttribute("Mut", key)
	apply(chip, props)
	chip.Parent = parent
	return chip
end

function UI.list(parent, padding)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, padding or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.Parent = parent
	return l
end

function UI.modal(name, title)
	local gui = UI.screen(name)
	gui.Enabled = false
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = UI.COLORS.shade
	shade.BackgroundTransparency = 0.5
	shade.Parent = gui
	local card = UI.frame(gui, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 520),
	})
	UI.label(card, title, {
		Name = "Title",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -80, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(16, 64)
	body.Size = UDim2.new(1, -32, 1, -80)
	body.Parent = card
	UI.list(body)
	local m = { gui = gui, card = card, body = body }
	function m.close()
		gui.Enabled = false
	end
	function m.open()
		gui.Enabled = true
	end
	function m.isOpen()
		return gui.Enabled
	end
	function m.clear()
		for _, child in body:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end
	UI.button(card, "X", m.close, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = UI.COLORS.red,
	})
	return m
end

function UI.money(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function UI.duration(sec)
	sec = math.max(0, math.floor(sec))
	local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

return UI

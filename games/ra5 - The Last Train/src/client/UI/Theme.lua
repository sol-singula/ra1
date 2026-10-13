-- The look of every screen: cinematic and calm. Dark, see-through panels with a thin brass edge, warm amber for
-- what you can act on, cream text, and Oswald capitals for headings (the same lettering as the train's signs).
-- Plus the phone scaling: every ScreenGui is laid out for a 1000 x 560 landscape canvas and scaled to the real
-- screen with a UIScale.
--
-- Following Roblox's accessibility and adaptive-design guidance, it also:
--   * respects Reduced Motion (GuiService.ReducedMotionEnabled): tweens snap, nothing pulses
--   * respects Background Transparency (GuiService.PreferredTransparency) on see-through panels
--   * respects Text Size (GuiService.PreferredTextSize) on fixed-size text
--   * knows the player's current input (touch, keyboard/mouse or gamepad) so screens can show the right hints
--   * never says something with colour alone: every state also has a word or an icon
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Theme.Color = {
	ink = rgb(12, 16, 14), -- the darkest: panel backgrounds
	panel = rgb(20, 27, 24),
	panel2 = rgb(32, 41, 37), -- rows and wells inside a panel
	edge = rgb(150, 118, 64), -- the thin brass edge
	amber = rgb(255, 184, 76), -- act on this
	amberDark = rgb(196, 124, 38),
	cream = rgb(242, 232, 208), -- text
	muted = rgb(160, 160, 146),
	good = rgb(118, 214, 128),
	bad = rgb(242, 96, 76),
	warn = rgb(255, 150, 60),
	blue = rgb(120, 172, 255), -- blueprints
	fuel = rgb(240, 112, 72),
	white = rgb(255, 255, 255),
	black = rgb(0, 0, 0),
}
Theme.Display = Enum.Font.Oswald
Theme.Body = Enum.Font.GothamMedium
Theme.Bold = Enum.Font.GothamBold

local C = Theme.Color

-- Accessibility --------------------------------------------------------------------------------------------
function Theme.reducedMotion()
	return GuiService.ReducedMotionEnabled == true
end

function Theme.motion(seconds)
	return Theme.reducedMotion() and 0 or seconds
end

function Theme.tween(inst, seconds, props, style, direction)
	local info =
		TweenInfo.new(Theme.motion(seconds), style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local TEXT_SIZE_FACTOR = { Medium = 1, Large = 1.15, Larger = 1.3, Largest = 1.5 }
function Theme.textFactor()
	local pref = GuiService.PreferredTextSize
	return pref and TEXT_SIZE_FACTOR[pref.Name] or 1
end

local translucent = {} -- [guiObject] = default transparency
function Theme.translucent(inst, default)
	translucent[inst] = default
	inst.BackgroundTransparency = default * (GuiService.PreferredTransparency or 1)
	return inst
end
pcall(function()
	GuiService:GetPropertyChangedSignal("PreferredTransparency"):Connect(function()
		for inst, default in translucent do
			if inst.Parent then
				inst.BackgroundTransparency = default * GuiService.PreferredTransparency
			else
				translucent[inst] = nil
			end
		end
	end)
end)

-- Input ----------------------------------------------------------------------------------------------------
function Theme.inputKind()
	local last = UserInputService:GetLastInputType()
	local name = last and last.Name or ""
	if name:sub(1, 7) == "Gamepad" then
		return "gamepad"
	elseif name == "Touch" then
		return "touch"
	elseif name:sub(1, 8) == "Keyboard" or name:sub(1, 5) == "Mouse" then
		return "keyboard"
	end
	return UserInputService.TouchEnabled and "touch" or "keyboard"
end

function Theme.isTouch()
	return UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
end

-- Building blocks ------------------------------------------------------------------------------------------
-- new("Frame", { Size = …, Parent = … }, { children })
function Theme.new(className, props, children)
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = Theme.new

function Theme.lighten(c, amount)
	return c:Lerp(C.white, amount)
end

function Theme.darken(c, amount)
	return c:Lerp(C.black, amount)
end

function Theme.corner(radius)
	return new("UICorner", { CornerRadius = radius == "round" and UDim.new(1, 0) or UDim.new(0, radius or 10) })
end

function Theme.stroke(thickness, color, transparency)
	return new("UIStroke", {
		Thickness = thickness or 1.5,
		Color = color or C.edge,
		Transparency = transparency or 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- A soft dark outline around text, for text over the world.
function Theme.textStroke(thickness, transparency)
	return new("UIStroke", {
		Name = "TextStroke",
		Thickness = thickness or 1.5,
		Color = C.black,
		Transparency = transparency or 0.45,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Theme.gradient(top, bottom, rotation)
	return new("UIGradient", { Name = "Shade", Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) })
end

function Theme.padding(px, py)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, py or px),
		PaddingBottom = UDim.new(0, py or px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

function Theme.list(direction, gap, align)
	return new("UIListLayout", {
		FillDirection = direction == "x" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = direction == "x" and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
	})
end

-- A dark see-through panel with a brass edge (the standard panel and HUD slab).
function Theme.slab(props)
	local round = props.round
	props.round = nil
	local transparency = props.BackgroundTransparency or 0.18
	props.BackgroundTransparency = nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.panel
	props.BorderSizePixel = 0
	local slab = new("Frame", props, {
		Theme.corner(round and "round" or 12),
		Theme.stroke(1.5),
		Theme.gradient(Theme.lighten(C.white, 0), rgb(205, 205, 205)),
	})
	return Theme.translucent(slab, transparency)
end
Theme.card = Theme.slab

-- Plain text (cream body text by default). outline = true adds the soft dark edge for text over the world.
function Theme.text(props)
	local outline = props.outline
	props.outline = nil
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Body
	props.TextColor3 = props.TextColor3 or C.cream
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = true
	if not props.TextSize then
		props.TextScaled = true
	else
		props.TextSize = math.floor(props.TextSize * Theme.textFactor() + 0.5)
	end
	local label = new("TextLabel", props)
	if outline then
		Theme.textStroke(type(outline) == "number" and outline or 1.5).Parent = label
	end
	return label
end

-- A heading in Oswald capitals.
function Theme.title(props)
	props.Font = props.Font or Theme.Display
	props.TextColor3 = props.TextColor3 or C.cream
	if props.Text then
		props.Text = string.upper(props.Text)
	end
	return Theme.text(props)
end

local function pressable(button)
	local scale = new("UIScale", { Name = "Press", Scale = 1, Parent = button })
	local hovering = false
	button.MouseEnter:Connect(function()
		if Theme.inputKind() == "keyboard" then
			hovering = true
			Theme.tween(scale, 0.1, { Scale = 1.04 })
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.08, { Scale = 0.94 })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.16, { Scale = hovering and 1.04 or 1 }, Enum.EasingStyle.Back)
	end)
end

-- A button. Primary (default): amber with dark lettering. secondary = true: dark with an amber edge.
-- danger = true: red. Disabled-looking buttons still say why in their text.
function Theme.button(props)
	local secondary, danger, round = props.secondary, props.danger, props.round
	props.secondary, props.danger, props.round = nil, nil, nil
	local fill = props.BackgroundColor3 or (danger and C.bad or secondary and C.panel2 or C.amber)
	props.BackgroundColor3 = fill
	props.Font = props.Font or Theme.Display
	props.TextColor3 = props.TextColor3 or ((secondary or danger) and C.cream or C.ink)
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	if props.Text then
		props.Text = string.upper(props.Text)
	end
	if not props.TextSize then
		props.TextScaled = true
	end
	local button = new("TextButton", props, {
		Theme.corner(round and "round" or 9),
		Theme.stroke(
			secondary and 1.5 or 1,
			secondary and C.amber or Theme.darken(fill, 0.35),
			secondary and 0.2 or 0.1
		),
		Theme.gradient(C.white, rgb(214, 214, 214)),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
	button.Selectable = true
	pressable(button)
	return button
end

function Theme.busy(button, seconds)
	if button:GetAttribute("Busy") then
		return false
	end
	local text = button.Text
	button:SetAttribute("Busy", true)
	button.Text = "..."
	button.Active = false
	task.delay(seconds or 1.2, function()
		if button.Parent then
			button.Text = text
			button.Active = true
			button:SetAttribute("Busy", nil)
		end
	end)
	return true
end

-- A small key hint (like "B") in the corner of a button, shown only to keyboard or gamepad players.
function Theme.keyHint(button, keyboardText, gamepadText)
	local badge = new("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(24, 20),
		Position = UDim2.new(1, 4, 0, -6),
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Font = Theme.Display,
		TextSize = 14,
		TextColor3 = C.amber,
		Text = keyboardText,
		ZIndex = 5,
		Visible = false,
		Parent = button,
	}, { Theme.corner(5), Theme.stroke(1, C.amber, 0.3) })
	badge:SetAttribute("Keyboard", keyboardText)
	badge:SetAttribute("Gamepad", gamepadText)
	return badge
end

-- Horizontal bar: returns the frame and its fill.
function Theme.bar(props, fillColor)
	props.BackgroundColor3 = props.BackgroundColor3 or C.ink
	props.BorderSizePixel = 0
	local frame = new("Frame", props, { Theme.corner("round"), Theme.stroke(1, C.edge, 0.4) })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor or C.amber,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Theme.corner("round"), Theme.gradient(C.white, rgb(200, 200, 200)) })
	return frame, fill
end

-- Ease a panel in: it rises a few pixels and grows from 94% (0.2 s), or just appears with Reduced Motion on.
function Theme.pop(guiObject)
	local scale = guiObject:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = guiObject })
	scale.Scale = Theme.reducedMotion() and 1 or 0.94
	Theme.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Quint)
end

-- Phone scaling -------------------------------------------------------------------------------------------
Theme.DESIGN = Vector2.new(1000, 560)

function Theme.scaleFactor()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if not size or size.X < 10 then
		return 1
	end
	return math.clamp(math.min(size.X / Theme.DESIGN.X, size.Y / Theme.DESIGN.Y), 0.55, 1.25)
end

local scaled = {}
function Theme.screen(name, displayOrder, parent)
	local gui = new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = parent,
	})
	local scale = new("UIScale", { Name = "Scale", Scale = Theme.scaleFactor(), Parent = gui })
	table.insert(scaled, scale)
	return gui
end

function Theme.watchScale()
	task.spawn(function()
		local last
		while true do
			local f = Theme.scaleFactor()
			if f ~= last then
				last = f
				for _, s in scaled do
					s.Scale = f
				end
			end
			task.wait(1)
		end
	end)
end

function Theme.canvas()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if not size or size.X < 10 then
		return Theme.DESIGN
	end
	local f = Theme.scaleFactor()
	return Vector2.new(size.X / f, size.Y / f)
end

-- A menu button: a dark rounded square with a big icon and its name underneath, and a dot for "something new".
function Theme.iconButton(props)
	local button = Theme.button({
		Name = props.Name,
		Text = "",
		secondary = true,
		Size = props.Size or UDim2.fromOffset(64, 64),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	})
	button.UICorner.CornerRadius = UDim.new(0, 14)
	Theme.text({
		Name = "Icon",
		Text = props.icon,
		Size = UDim2.new(1, 0, 0.62, 0),
		Position = UDim2.new(0, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	Theme.title({
		Name = "Label",
		Text = props.label,
		Size = UDim2.new(1, 4, 0.3, 0),
		Position = UDim2.new(0, -2, 0.66, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.amber,
		Parent = button,
	})
	local dot = new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, -10, 0, -4),
		BackgroundColor3 = C.amber,
		Visible = false,
		Parent = button,
	}, { Theme.corner("round"), Theme.stroke(1.5, C.ink, 0) })
	return button, dot
end

return Theme

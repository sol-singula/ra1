-- The look of every screen: chunky shapes with thick dark outlines, glossy top-to-bottom gradients, white text
-- with a black outline, buttons that squish when pressed and panels that pop in. Plus the phone scaling: every
-- ScreenGui is laid out for a 1000 x 560 landscape canvas and scaled to the real screen with a UIScale.
--
-- Following Roblox's accessibility and adaptive-design guidance, it also:
--   * respects the player's Reduced Motion setting (GuiService.ReducedMotionEnabled): tweens snap, nothing pulses
--   * respects the Background Transparency setting (GuiService.PreferredTransparency) on see-through panels
--   * respects the Text Size setting (GuiService.PreferredTextSize) on fixed-size text
--   * knows the player's current input (touch, keyboard/mouse or gamepad) so screens can show the right hints
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Theme.Color = {
	paper = rgb(255, 248, 232),
	ink = rgb(22, 22, 34),
	slate = rgb(34, 36, 56),
	mustard = rgb(255, 200, 40),
	ketchup = rgb(255, 75, 62),
	teal = rgb(30, 200, 185),
	good = rgb(60, 205, 90),
	muted = rgb(110, 106, 124),
	white = rgb(255, 255, 255),
	purple = rgb(150, 90, 240),
	sky = rgb(60, 160, 255),
	red = rgb(255, 65, 75),
	orange = rgb(255, 140, 30),
	pink = rgb(255, 95, 170),
}
Theme.Display = Enum.Font.LuckiestGuy
Theme.Body = Enum.Font.FredokaOne

local C = Theme.Color

-- Accessibility --------------------------------------------------------------------------------------------
function Theme.reducedMotion()
	return GuiService.ReducedMotionEnabled == true
end

-- Tween length, or 0 (snap) when the player asked for reduced motion.
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

-- See-through backgrounds get more solid when the player turns down transparency in their settings.
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
-- "touch", "keyboard" or "gamepad", from the last input the player used.
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
	return c:Lerp(rgb(0, 0, 0), amount)
end

function Theme.corner(radius)
	return new("UICorner", { CornerRadius = radius == "round" and UDim.new(1, 0) or UDim.new(0, radius or 14) })
end

-- A thick dark outline around a frame or button.
function Theme.stroke(thickness, color)
	return new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or C.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- A black outline around text (what makes white text readable over the world).
function Theme.textStroke(thickness, color)
	return new("UIStroke", {
		Name = "TextStroke",
		Thickness = thickness or 2,
		Color = color or C.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

-- A glossy vertical gradient: lighter at the top, darker at the bottom. Works on top of BackgroundColor3.
function Theme.gloss(top, bottom)
	return new("UIGradient", {
		Name = "Gloss",
		Rotation = 90,
		Color = ColorSequence.new(top or rgb(255, 255, 255), bottom or rgb(190, 190, 190)),
	})
end

function Theme.padding(px)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

-- A cream card with a thick outline (the standard panel).
function Theme.card(props)
	props.BackgroundColor3 = props.BackgroundColor3 or C.paper
	props.BorderSizePixel = 0
	return new("Frame", props, { Theme.corner(18), Theme.stroke(4) })
end

-- A dark translucent HUD slab.
function Theme.slab(props)
	local round = props.round
	props.round = nil
	local transparency = props.BackgroundTransparency or 0.15
	props.BackgroundTransparency = nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.slate
	props.BorderSizePixel = 0
	local slab = new("Frame", props, { Theme.corner(round and "round" or 16), Theme.stroke(3, C.ink) })
	return Theme.translucent(slab, transparency)
end

-- Plain text. Pass outline = true (or a thickness) for white-on-black outlined text.
function Theme.text(props)
	local outline = props.outline
	props.outline = nil
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Body
	props.TextColor3 = props.TextColor3 or C.ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = true
	if not props.TextSize then
		props.TextScaled = true
	else
		props.TextSize = math.floor(props.TextSize * Theme.textFactor() + 0.5)
	end
	local label = new("TextLabel", props)
	if outline then
		Theme.textStroke(type(outline) == "number" and outline or 2).Parent = label
	end
	return label
end

-- A big outlined headline in the display font.
function Theme.title(props)
	props.Font = props.Font or Theme.Display
	props.TextColor3 = props.TextColor3 or C.white
	props.outline = props.outline or 3
	return Theme.text(props)
end

-- Buttons react: grow a little under the mouse, squish while held, bounce back on release (about 0.1 s).
local function pressable(button)
	local scale = new("UIScale", { Name = "Press", Scale = 1, Parent = button })
	local hovering = false
	button.MouseEnter:Connect(function()
		if Theme.inputKind() == "keyboard" then
			hovering = true
			Theme.tween(scale, 0.1, { Scale = 1.05 })
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		Theme.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		Theme.tween(scale, 0.08, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		Theme.tween(scale, 0.18, { Scale = hovering and 1.05 or 1 }, Enum.EasingStyle.Back)
	end)
end

-- A chunky glossy button with white outlined text. dark = true keeps ink text (for white buttons).
function Theme.button(props)
	local dark, round = props.dark, props.round
	props.dark, props.round = nil, nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.mustard
	props.Font = props.Font or Theme.Display
	props.TextColor3 = props.TextColor3 or (dark and C.ink or C.white)
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	if not props.TextSize then
		props.TextScaled = true
	end
	local button = new("TextButton", props, {
		Theme.corner(round and "round" or 14),
		Theme.stroke(3),
		Theme.gloss(rgb(255, 255, 255), rgb(200, 200, 200)),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		}),
	})
	if not dark then
		Theme.textStroke(2).Parent = button
	end
	button.Selectable = true -- reachable with a gamepad
	pressable(button)
	return button
end

-- Show a button is working after a tap (e.g. while Roblox's purchase prompt opens), and block double taps.
function Theme.busy(button, seconds)
	if button:GetAttribute("Busy") then
		return false
	end
	local text = button.Text
	button:SetAttribute("Busy", true)
	button.Text = "..."
	button.Active = false
	task.delay(seconds or 1.5, function()
		if button.Parent then
			button.Text = text
			button.Active = true
			button:SetAttribute("Busy", nil)
		end
	end)
	return true
end

-- A small key hint (like "Q" or "R2") in the corner of a button, shown only for keyboard or gamepad players.
function Theme.keyHint(button, keyboardText, gamepadText)
	local badge = new("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(30, 26),
		Position = UDim2.new(1, 6, 0, -8),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Font = Theme.Display,
		TextSize = 16,
		TextColor3 = C.ink,
		Text = keyboardText,
		ZIndex = 5,
		Visible = false,
		Parent = button,
	}, { Theme.corner(7), Theme.stroke(2.5) })
	badge:SetAttribute("Keyboard", keyboardText)
	badge:SetAttribute("Gamepad", gamepadText)
	table.insert(Theme._keyHints, badge)
	Theme.refreshKeyHints()
	return badge
end

-- Key badges show on computers (the key) and gamepads (the button), never on phones.
Theme._keyHints = {}
function Theme.refreshKeyHints()
	local kind = Theme.inputKind()
	for i = #Theme._keyHints, 1, -1 do
		local badge = Theme._keyHints[i]
		if not badge.Parent then
			table.remove(Theme._keyHints, i)
		else
			local text = kind == "gamepad" and badge:GetAttribute("Gamepad") or badge:GetAttribute("Keyboard")
			badge.Visible = kind ~= "touch" and text ~= nil
			badge.Text = text or ""
		end
	end
end

-- Horizontal bar: returns the frame and its fill.
function Theme.bar(props, fillColor)
	props.BackgroundColor3 = props.BackgroundColor3 or rgb(40, 42, 62)
	props.BorderSizePixel = 0
	local frame = new("Frame", props, { Theme.corner("round"), Theme.stroke(2) })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Theme.corner("round"), Theme.gloss(rgb(255, 255, 255), rgb(185, 185, 185)) })
	return frame, fill
end

-- Pop a panel in: it grows from 80% with a little overshoot (0.25 s), or just appears with Reduced Motion on.
function Theme.pop(guiObject)
	local scale = guiObject:FindFirstChild("Pop") or new("UIScale", { Name = "Pop", Parent = guiObject })
	scale.Scale = Theme.reducedMotion() and 1 or 0.8
	Theme.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
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

-- True on phones and tablets (no keyboard, touch screen).
function Theme.isTouch()
	return UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
end

local scaled = {}
-- A ScreenGui that keeps its UIScale in step with the screen size.
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

-- Call once from the client bootstrap: rescales every Theme.screen when the window or phone rotates.
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

-- Size of the scaled canvas in design pixels (useful to keep things on screen).
function Theme.canvas()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize
	if not size or size.X < 10 then
		return Theme.DESIGN
	end
	local f = Theme.scaleFactor()
	return Vector2.new(size.X / f, size.Y / f)
end

-- A glossy rounded-square menu button with a big emoji, and its name in outlined letters across the bottom
-- edge (the style most top Roblox games use). Returns the button and its red notification dot.
function Theme.iconButton(props)
	local button = Theme.button({
		Name = props.Name,
		Text = "",
		BackgroundColor3 = props.color or C.mustard,
		Size = props.Size or UDim2.fromOffset(70, 70),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
	})
	button.UICorner.CornerRadius = UDim.new(0, 18)
	Theme.text({
		Name = "Icon",
		Text = props.icon,
		Size = UDim2.new(1, 0, 0.78, 0),
		Position = UDim2.new(0, 0, 0, -2),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	Theme.title({
		Name = "Label",
		Text = props.label,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1.25, 0, 0, 22),
		Position = UDim2.new(0.5, 0, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2.5,
		Parent = button,
	})
	local dot = new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -16, 0, -10),
		BackgroundColor3 = C.red,
		Visible = false,
		Parent = button,
	}, { Theme.corner("round"), Theme.stroke(2.5) })
	Theme.title({
		Text = "!",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = dot,
	})
	return button, dot
end

return Theme

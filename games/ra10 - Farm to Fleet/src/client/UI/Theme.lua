-- The look of every screen (master plan §0): SUPERHOT. White cards with thin black edges, black type in a heavy
-- geometric font, dark glassy slabs for the HUD over the white world, and the only colours red and blue. Plus the
-- phone scaling: every ScreenGui is laid out for a landscape canvas at least 1240 x 560 and scaled with a UIScale.
--
-- Following Roblox's accessibility and adaptive-design guidance, it also:
--   * respects the player's Reduced Motion setting (GuiService.ReducedMotionEnabled): tweens snap, nothing pulses
--   * respects the Background Transparency setting (GuiService.PreferredTransparency) on see-through panels
--   * respects the Text Size setting (GuiService.PreferredTextSize) on fixed-size text
--   * knows the player's current input (touch, keyboard/mouse or gamepad) so screens can show the right hints
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Theme.Color = {
	paper = rgb(250, 250, 250),
	ink = rgb(18, 18, 22),
	slate = rgb(22, 22, 28),
	mustard = rgb(255, 200, 40),
	ketchup = rgb(235, 40, 45),
	teal = rgb(30, 200, 185),
	good = rgb(70, 200, 110),
	muted = rgb(120, 120, 128),
	white = rgb(255, 255, 255),
	purple = rgb(150, 90, 240),
	sky = rgb(35, 110, 245),
	red = rgb(235, 40, 45),
	blue = rgb(35, 110, 245),
	orange = rgb(255, 140, 30),
	pink = rgb(255, 95, 170),
	grey = rgb(196, 197, 200),
}
Theme.Display = Enum.Font.GothamBlack
Theme.Body = Enum.Font.GothamBold

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

-- Outlines that fit their letters. An outline a fixed number of pixels thick swamps small text: a long title that
-- TextScaled squeezes onto a small phone turns into blobs. So an outline is about a tenth of the height the letters
-- are really drawn at, never thicker than asked for and never under a pixel, and it follows the text as it changes.
local asked = setmetatable({}, { __mode = "k" }) -- [stroke] = the thickness asked for

-- How tall a label's letters are drawn, in pixels: its TextSize on the scaled canvas, or for TextScaled text the
-- biggest size that fits the box (what Roblox picks).
local function drawnSize(label)
	local abs = label.AbsoluteSize
	if typeof(abs) ~= "Vector2" or abs.X < 2 or abs.Y < 2 then
		return nil
	end
	if not label.TextScaled then
		return label.TextSize * Theme.scaleFactor()
	end
	local ok, size = pcall(function()
		local lo, hi = 1, math.clamp(math.floor(abs.Y), 1, 100)
		local width = label.TextWrapped and abs.X or 100000
		while lo < hi do
			local mid = math.ceil((lo + hi) / 2)
			local b = TextService:GetTextSize(label.Text, mid, label.Font, Vector2.new(width, 100000))
			if b.X <= abs.X + 0.5 and b.Y <= abs.Y + 0.5 then
				lo = mid
			else
				hi = mid - 1
			end
		end
		return lo
	end)
	if ok and type(size) == "number" then
		return size
	end
	local bounds = label.TextBounds
	return typeof(bounds) == "Vector2" and bounds.Y > 0 and bounds.Y or nil
end

local function fitOutline(label, stroke)
	local want = asked[stroke]
	if not want or stroke.Parent ~= label then
		return
	end
	local size = drawnSize(label)
	if size then
		stroke.Thickness = math.clamp(size * 0.1, 1, want)
	end
end
Theme.fitOutline = fitOutline

-- Put a fitted outline on a TextLabel or TextButton.
function Theme.outline(label, thickness, color)
	local stroke = Theme.textStroke(thickness, color)
	asked[stroke] = stroke.Thickness
	stroke.Parent = label
	fitOutline(label, stroke)
	pcall(function()
		for _, prop in { "AbsoluteSize", "Text", "TextSize" } do
			label:GetPropertyChangedSignal(prop):Connect(function()
				fitOutline(label, stroke)
			end)
		end
	end)
	return stroke
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

-- A cream card with a thick outline (the standard panel). Active: a click on it is for the card, not the world
-- behind it (a plain Frame lets clicks through as if nothing was there: a swing, or the camera turning).
function Theme.card(props)
	props.BackgroundColor3 = props.BackgroundColor3 or C.paper
	props.BorderSizePixel = 0
	if props.Active == nil then
		props.Active = true
	end
	return new("Frame", props, { Theme.corner(6), Theme.stroke(2) })
end

-- A dark translucent HUD slab.
function Theme.slab(props)
	local round = props.round
	props.round = nil
	local transparency = props.BackgroundTransparency or 0.15
	props.BackgroundTransparency = nil
	props.BackgroundColor3 = props.BackgroundColor3 or C.slate
	props.BorderSizePixel = 0
	if props.Active == nil then
		props.Active = true -- (as for cards)
	end
	local slab = new("Frame", props, { Theme.corner(round and "round" or 6), Theme.stroke(1, C.ink) })
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
	-- fit = n: the words shrink to fit their box (never past it, whatever the text size setting) up to size n
	local fit = props.fit
	props.fit = nil
	if fit then
		props.TextSize = nil
		props.TextScaled = true
	end
	if not props.TextSize then
		props.TextScaled = true
	else
		props.TextSize = math.floor(props.TextSize * Theme.textFactor() + 0.5)
	end
	local label = new("TextLabel", props)
	if fit then
		new("UITextSizeConstraint", {
			MaxTextSize = math.floor(fit * Theme.textFactor() + 0.5),
			MinTextSize = 8,
			Parent = label,
		})
	end
	if outline then
		Theme.outline(label, type(outline) == "number" and outline or 2)
	end
	return label
end

-- A big outlined headline in the display font (outline = false for dark letters on a light card: a dark outline
-- around dark letters runs them together).
function Theme.title(props)
	props.Font = props.Font or Theme.Display
	props.TextColor3 = props.TextColor3 or C.white
	if props.outline == nil then
		props.outline = 3
	end
	return Theme.text(props)
end

-- A popup's header: a dark band across the top of a card with the words in white display letters and a dark
-- outline, like a panel's title bar. (Dark letters on the cream card read as black blobs on a phone.) Without a
-- textSize the words shrink to fit the band, wrapping onto a second line if they must.
function Theme.cardHeader(card, text, height, color, textSize)
	local band = color or C.slate
	local head = new("Frame", {
		Name = "Head",
		BackgroundColor3 = band,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height or 48),
		Parent = card,
	}, { Theme.corner(18) })
	-- (square bottom corners: the band meets the card's body in a straight line)
	new("Frame", {
		Name = "Square",
		BackgroundColor3 = band,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = head,
	})
	local title = Theme.title({
		Name = "Title",
		Text = text or "",
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(14, 5),
		Size = UDim2.new(1, -28, 1, -10),
		TextSize = textSize,
		Parent = head,
	})
	return head, title
end

-- Fade outlined text in or out: the letters and their outline together (an outline left behind keeps the words
-- on screen as a ghost after the letters have gone).
function Theme.fadeText(label, seconds, transparency)
	Theme.tween(label, seconds, { TextTransparency = transparency })
	for _, d in label:GetChildren() do
		if d:IsA("UIStroke") then
			Theme.tween(d, seconds, { Transparency = transparency })
		end
	end
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

Theme.pressable = pressable

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
		Theme.outline(button, 2)
	end
	button.Selectable = true -- reachable with a gamepad
	pressable(button)
	return button
end

-- Every panel's close button: a round dark button with an X drawn as two crossed white bars (a "✕" glyph doesn't
-- draw in every font), red under the mouse. It's "Close", marked CloseButton; the caller makes it Modal.
--   Theme.closeButton(parent, onClick, { Position = …, Size = … })
function Theme.closeButton(parent, onClick, props)
	props = props or {}
	local b = new("TextButton", {
		Name = "Close",
		Position = props.Position or UDim2.fromOffset(0, 0),
		Size = props.Size or UDim2.fromOffset(36, 36),
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = C.ink,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Selectable = true,
		Parent = parent,
	}, { Theme.corner("round"), Theme.stroke(2, C.ink) })
	b:SetAttribute("CloseButton", true)
	-- the X (its two bars cross on purpose: a picture, not a layout)
	local glyph = new("Frame", {
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		Parent = b,
	})
	glyph:SetAttribute("Art", true)
	for i, rot in { 45, -45 } do
		new("Frame", {
			Name = "Bar" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0, 4),
			Rotation = rot,
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			Parent = glyph,
		}, { Theme.corner("round") })
	end
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = C.red
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = C.ink
	end)
	pressable(b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- The Shard: a small cut gem drawn from frames (a diamond in two shades of aqua, a white glint, a dark edge), so
-- every Shard amount reads the same at any size. A square box; `size` in pixels.
Theme.SHARD = rgb(40, 190, 230)
function Theme.gem(parent, size, props)
	props = props or {}
	local box = new("Frame", {
		Name = props.Name or "Shard",
		Position = props.Position or UDim2.fromOffset(0, 0),
		AnchorPoint = props.AnchorPoint,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,
		Parent = parent,
	})
	box:SetAttribute("Art", true) -- (its facets sit on each other on purpose)
	local stone = new("Frame", {
		Name = "Stone",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		Rotation = 45,
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		Parent = box,
	}, {
		Theme.corner(math.max(1, math.floor(size / 10))),
		Theme.stroke(math.max(1, size / 14), rgb(14, 60, 90)),
		-- the left facets lit, the right in shade (a hard split down the middle, corner to corner)
		new("UIGradient", {
			Rotation = 45,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(170, 245, 255)),
				ColorSequenceKeypoint.new(0.499, rgb(80, 215, 245)),
				ColorSequenceKeypoint.new(0.5, rgb(25, 150, 215)),
				ColorSequenceKeypoint.new(1, rgb(15, 105, 175)),
			}),
		}),
	})
	-- the table (the flat top) and a glint
	new("Frame", {
		Name = "Table",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.42),
		Size = UDim2.fromScale(0.34, 0.34),
		BackgroundColor3 = rgb(215, 250, 255),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		Parent = stone,
	}, { Theme.corner(math.max(1, math.floor(size / 16))) })
	new("Frame", {
		Name = "Glint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.36, 0.28),
		Size = UDim2.fromOffset(math.max(2, size * 0.12), math.max(2, size * 0.12)),
		Rotation = 45,
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex,
		Parent = box,
	})
	return box
end

-- An amount of Shards: the gem, then the number, centred in a w x h box (or left with align = "left").
-- Returns the box; its number is box.Amount.
function Theme.shards(parent, amount, props)
	local w, h = props.w, props.h
	local box = new("Frame", {
		Name = props.Name or "Price",
		Position = props.Position or UDim2.fromOffset(0, 0),
		AnchorPoint = props.AnchorPoint,
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,
		Parent = parent,
	})
	local s = type(amount) == "number" and Theme.commas(amount) or tostring(amount)
	local gs = math.floor(h * (props.gem or 0.95))
	-- (the number's width, roughly: the display font's figures run about 0.62 of their height)
	local tw = math.min(w - gs - 4, #s * h * 0.62)
	local x = props.align == "left" and 0 or math.floor((w - gs - 4 - tw) / 2)
	Theme.gem(box, gs, {
		Position = UDim2.fromOffset(x, math.floor((h - gs) / 2)),
		ZIndex = props.ZIndex,
	})
	Theme.text({
		Name = "Amount",
		Text = s,
		Position = UDim2.fromOffset(x + gs + 4, 0),
		Size = UDim2.fromOffset(w - x - gs - 4, h),
		Font = Theme.Display,
		TextColor3 = props.color or C.ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		fit = props.fit or h,
		ZIndex = props.ZIndex,
		Parent = box,
	})
	return box
end

function Theme.commas(n)
	local s = tostring(math.floor(n or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
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

-- A small key hint (like "Q" or "R2") in the corner of a button, shown only for keyboard or gamepad players (and
-- switching as they switch).
local hints = setmetatable({}, { __mode = "k" })
local function showHint(badge)
	local kind = Theme.inputKind()
	local text = badge:GetAttribute(kind == "gamepad" and "Gamepad" or "Keyboard")
	badge.Visible = kind ~= "touch" and type(text) == "string" and text ~= ""
	if type(text) == "string" then
		badge.Text = text
	end
end
function Theme.keyHint(button, keyboardText, gamepadText)
	local badge = new("TextLabel", {
		Name = "KeyHint",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(30, 26),
		AutomaticSize = Enum.AutomaticSize.X,
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
	}, {
		Theme.corner(7),
		Theme.stroke(2.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }),
	})
	badge:SetAttribute("Keyboard", keyboardText)
	badge:SetAttribute("Gamepad", gamepadText)
	hints[badge] = true
	showHint(badge)
	return badge
end
pcall(function()
	UserInputService.LastInputTypeChanged:Connect(function()
		for badge in hints do
			if badge.Parent then
				showHint(badge)
			else
				hints[badge] = nil
			end
		end
	end)
end)

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
-- The narrowest canvas the screens get: the HUD's corners, the centre column and the action buttons only fit side
-- by side from 1240 across, so a squarer screen (a tablet, a small window) gets the whole UI a little smaller
-- rather than things on top of each other.
Theme.MIN_WIDTH = 1240

local scaled = {}
local scaledGuis = {}

-- The space the screens really get: inside Roblox's top bar and the phone's notch and home bar (CoreUISafeInsets),
-- which on a phone in landscape is quite a bit less than the whole screen.
local function safeSize()
	for _, gui in scaledGuis do
		local ok, size = pcall(function()
			return gui.AbsoluteSize
		end)
		if ok and typeof(size) == "Vector2" and size.X > 10 and size.Y > 10 then
			return size
		end
	end
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize
end

function Theme.scaleFactor()
	local size = safeSize()
	if not size or size.X < 10 then
		return 1
	end
	return math.clamp(math.min(size.X / Theme.MIN_WIDTH, size.Y / Theme.DESIGN.Y), 0.55, 1.25)
end

-- True on phones and tablets (no keyboard, touch screen).
function Theme.isTouch()
	return require(script.Parent.Device).isTouch()
end

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
	table.insert(scaledGuis, gui)
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
	local size = safeSize()
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

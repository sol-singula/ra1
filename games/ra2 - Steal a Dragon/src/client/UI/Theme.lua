-- UI colours and fonts (chunky ink borders, bright fills) plus a tiny element factory, and the phone scaling:
-- every ScreenGui is laid out for a 1000 x 560 landscape canvas and scaled to the real screen with a UIScale.
local Theme = {}

Theme.Color = {
	paper = Color3.fromRGB(255, 246, 224),
	ink = Color3.fromRGB(27, 29, 43),
	slate = Color3.fromRGB(35, 38, 58),
	mustard = Color3.fromRGB(255, 197, 49),
	ketchup = Color3.fromRGB(255, 75, 62),
	teal = Color3.fromRGB(46, 196, 182),
	good = Color3.fromRGB(72, 209, 107),
	muted = Color3.fromRGB(110, 106, 124),
	white = Color3.fromRGB(255, 255, 255),
	purple = Color3.fromRGB(125, 85, 205),
	sky = Color3.fromRGB(80, 170, 255),
	red = Color3.fromRGB(255, 70, 70),
}
Theme.Display = Enum.Font.LuckiestGuy
Theme.Body = Enum.Font.FredokaOne

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

function Theme.corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 14) })
end

function Theme.stroke(thickness, color)
	return new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Theme.Color.ink,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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

-- A paper card with an ink border (the game's standard panel).
function Theme.card(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.paper
	props.BorderSizePixel = 0
	return new("Frame", props, { Theme.corner(16), Theme.stroke(3) })
end

-- A dark translucent HUD slab.
function Theme.slab(props)
	props.BackgroundColor3 = Theme.Color.slate
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	props.BorderSizePixel = 0
	return new("Frame", props, { Theme.corner(14), Theme.stroke(3, Color3.fromRGB(13, 15, 24)) })
end

function Theme.text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Theme.Body
	props.TextColor3 = props.TextColor3 or Theme.Color.ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = true
	if not props.TextSize then
		props.TextScaled = true
	end
	return new("TextLabel", props)
end

-- Chunky mustard button with an ink outline.
function Theme.button(props)
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.mustard
	props.Font = props.Font or Theme.Body
	props.TextColor3 = props.TextColor3 or Theme.Color.ink
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	if not props.TextSize then
		props.TextScaled = true
	end
	return new("TextButton", props, {
		Theme.corner(12),
		Theme.stroke(3),
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
	})
end

-- Horizontal bar: returns the frame and its fill.
function Theme.bar(props, fillColor)
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(58, 61, 85)
	props.BorderSizePixel = 0
	local frame = new("Frame", props, { Theme.corner(8) })
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Theme.corner(8) })
	return frame, fill
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
	local UserInputService = game:GetService("UserInputService")
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

-- A round-cornered square button with a big emoji and a short label under it.
function Theme.iconButton(props)
	local button = Theme.button({
		Name = props.Name,
		Text = "",
		BackgroundColor3 = props.color or Theme.Color.mustard,
		Size = props.Size or UDim2.fromOffset(68, 68),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Parent = props.Parent,
	})
	Theme.text({
		Name = "Icon",
		Text = props.icon,
		Size = UDim2.new(1, 0, 0.62, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	Theme.text({
		Name = "Label",
		Text = props.label,
		Font = Theme.Display,
		Size = UDim2.new(1, 0, 0.36, 0),
		Position = UDim2.new(0, 0, 0.64, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = button,
	})
	local dot = new("Frame", {
		Name = "Dot",
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, -12, 0, -8),
		BackgroundColor3 = Theme.Color.red,
		Visible = false,
		Parent = button,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), Theme.stroke(2) })
	return button, dot
end

return Theme

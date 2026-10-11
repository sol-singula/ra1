-- UI tokens from GDD §24 (paper, ink, mustard, ketchup, teal; chunky ink borders and hard drop shadows)
-- plus a tiny element factory so screens can be built in code without a UI framework.
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

return Theme

--[[
The guide's finger on the screen (master plan §4: one clear thing at a time, never a text wall): a pulsing ring
round the exact button to press next and a bouncing hand beside it, drawn over everything, so it can sit on a HUD
button, a hotbar slot or a row inside a panel (TutorialController decides which).

  Glow.show(target)   the ring and the hand follow this GuiObject (nil hides them)
  Glow.step(clock)    every frame
  Glow.target()
]]
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local Glow = {}

local C = Theme.Color
local gui, ring, stroke, hand, target

local function ensure()
	if gui and gui.Parent then
		return
	end
	gui = Theme.new("ScreenGui", {
		Name = "GuideGlow",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	ring = Theme.new("Frame", {
		Name = "Ring",
		BackgroundColor3 = C.mustard,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = gui,
	}, { Theme.corner(16) })
	stroke = Theme.stroke(5, C.white)
	stroke.Parent = ring
	hand = Theme.title({
		Name = "Hand",
		Text = "👇",
		Size = UDim2.fromOffset(56, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 3,
		outline = 2,
		Parent = gui,
	})
	hand.TextScaled = true
end

function Glow.show(t)
	target = t
	if t then
		ensure()
	end
	if ring then
		ring.Visible = t ~= nil
		hand.Visible = t ~= nil
	end
end

function Glow.target()
	return target
end

local function showing(t)
	if not t or not t.Parent or t.Visible == false then
		return false
	end
	local pos, size = t.AbsolutePosition, t.AbsoluteSize
	if typeof(pos) ~= "Vector2" or typeof(size) ~= "Vector2" then
		return false -- (the mock: nothing to measure)
	end
	-- an ancestor hidden, or a row scrolled out of its list, hides it too
	local a = t.Parent
	while a and not a:IsA("LayerCollector") do
		if a:IsA("GuiObject") and a.Visible == false then
			return false
		end
		if a:IsA("ScrollingFrame") then
			local ap, asz = a.AbsolutePosition, a.AbsoluteSize
			if pos.Y + size.Y < ap.Y or pos.Y > ap.Y + asz.Y then
				return false
			end
		end
		a = a.Parent
	end
	return a ~= nil and (a.Enabled ~= false)
end

function Glow.step(clock)
	if not ring then
		return
	end
	if not showing(target) then
		ring.Visible = false
		hand.Visible = false
		return
	end
	local pos, size = target.AbsolutePosition, target.AbsoluteSize
	local pulse = 0.5 + 0.5 * math.sin(clock * 6)
	local pad = 5 + pulse * 7
	ring.Visible = true
	hand.Visible = true
	ring.Position = UDim2.fromOffset(pos.X - pad, pos.Y - pad)
	ring.Size = UDim2.fromOffset(size.X + pad * 2, size.Y + pad * 2)
	ring.BackgroundTransparency = 0.92 - pulse * 0.3
	stroke.Color = C.mustard:Lerp(C.white, pulse)
	stroke.Thickness = 3 + pulse * 4
	local above = pos.Y > 90
	hand.Text = above and "👇" or "👆"
	local bob = pulse * 10
	hand.Position =
		UDim2.fromOffset(pos.X + size.X / 2 - 28, above and (pos.Y - 60 - bob) or (pos.Y + size.Y + 6 + bob))
end

return Glow

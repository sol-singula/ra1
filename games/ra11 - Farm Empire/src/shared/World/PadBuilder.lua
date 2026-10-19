--[[
The upgrade pads in the build yard (PadService fills them): step on one to buy what it shows. A pad is a raised
plinth in its branch's colour with a glowing top: green when you can afford it, gold when it's the recommended one
(the guide's arrow points at it), dark when you can't yet. Over it a sign in studs (it shrinks with distance): the
upgrade's name and its price; a small icon on the top.

  PadBuilder.build(folder, i, k, key)   the pad in slot k of territory i, showing upgrade key
  PadBuilder.paint(model, state)        state = { name, cost, level, max, affordable, recommended, branch }
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(script.Parent.Layout)
local Shapes = require(script.Parent.Shapes)

local PadBuilder = {}

local rgb = Color3.fromRGB
PadBuilder.BRANCH = {
	production = { color = rgb(86, 180, 80), icon = "🌱" },
	machinery = { color = rgb(222, 70, 56), icon = "🚜" },
	retail = { color = rgb(60, 140, 230), icon = "🏪" },
	logistics = { color = rgb(244, 140, 40), icon = "📦" },
	prestige = { color = rgb(160, 100, 235), icon = "⭐" },
	animals = { color = rgb(214, 150, 90), icon = "🐾" },
}
local GREEN = rgb(80, 230, 110)
local GOLD = rgb(255, 205, 50)
local DARK = rgb(70, 64, 60)

function PadBuilder.build(folder, i, k, key, branch)
	local spot = Layout.padAt(k)
	local o = Layout.cframe(i, spot.x, spot.z, 0)
	local b = PadBuilder.BRANCH[branch] or PadBuilder.BRANCH.production
	local m = Shapes.model(folder, "Pad" .. k)
	m:SetAttribute("Slot", k)
	m:SetAttribute("Upgrade", key)
	local base = Shapes.part(m, Vector3.new(7.4, 0.6, 7.4), o * CFrame.new(0, 0.3, 0), b.color)
	base.Name = "Base"
	Shapes.part(m, Vector3.new(7.8, 0.25, 7.8), o * CFrame.new(0, 0.12, 0), Shapes.shade(b.color, -0.35)).Name = "Foot"
	local top = Shapes.part(m, Vector3.new(Layout.PAD, 0.2, Layout.PAD), o * CFrame.new(0, 0.7, 0), DARK)
	top.Name = "Pad"
	top.Material = Enum.Material.Neon
	top:SetAttribute("Upgrade", key)
	-- the icon on the top
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Icon"
	sg.Face = Enum.NormalId.Top
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.6, 0.6)
	icon.TextScaled = true
	icon.Text = b.icon
	icon.Parent = sg
	sg.Parent = top
	-- the sign over it: the name, the price
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag"
	bb.Size = UDim2.new(6.6, 0, 2.8, 0)
	bb.StudsOffset = Vector3.new(0, 3.4, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = rgb(40, 30, 24)
	card.BackgroundTransparency = 0.1
	card.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 3
	stroke.Color = b.color
	stroke.Parent = card
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.06)
	title.Size = UDim2.fromScale(0.9, 0.48)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = rgb(255, 255, 255)
	title.Text = ""
	title.Parent = card
	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromScale(0.05, 0.54)
	price.Size = UDim2.fromScale(0.9, 0.4)
	price.Font = Enum.Font.GothamBlack
	price.TextScaled = true
	price.TextColor3 = GREEN
	price.Text = ""
	price.Parent = card
	bb.Parent = top
	return m
end

function PadBuilder.paint(m, s)
	local top = m:FindFirstChild("Pad")
	if not top then
		return
	end
	local color = s.recommended and GOLD or (s.affordable and GREEN or DARK)
	if top.Color ~= color then
		top.Color = color
	end
	local card = top.Tag.Card
	local name = s.name .. ((s.max or 1) > 1 and ` {(s.level or 0) + 1}/{s.max}` or "")
	if card.Title.Text ~= name then
		card.Title.Text = name
	end
	local price = s.cost and Format.cash(s.cost) or "MAXED"
	if card.Price.Text ~= price then
		card.Price.Text = price
	end
	card.Price.TextColor3 = s.affordable and GREEN or rgb(255, 120, 100)
	card.Stroke.Color = s.recommended and GOLD or (PadBuilder.BRANCH[s.branch] or PadBuilder.BRANCH.production).color
	m:SetAttribute("Affordable", s.affordable == true)
	m:SetAttribute("Recommended", s.recommended == true)
	m:SetAttribute("Cost", s.cost or 0)
end

return PadBuilder

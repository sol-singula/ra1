-- Builds a blocky dragon Model from primitive parts. The invisible "Root" part is the PrimaryPart: it sits
-- around the body, carries the prompts and the name tag, and every other part is welded to it, so moving the
-- Root moves the whole dragon. The dragon faces -Z (Roblox's forward).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)

local DragonBuilder = {}

local ROOT_HALF = 1.75 -- the Root is 3.5 tall; its centre is this far above the feet

-- name, size, offset from the feet centre, colour key, extra rotation (degrees x, y, z)
local PARTS = {
	{ "Body", Vector3.new(2.2, 1.8, 3), Vector3.new(0, 1.6, 0), "body" },
	{ "Belly", Vector3.new(1.7, 1.3, 0.3), Vector3.new(0, 1.45, -1.5), "belly" },
	{ "Head", Vector3.new(1.7, 1.5, 1.6), Vector3.new(0, 2.9, -1.7), "body" },
	{ "Snout", Vector3.new(1.2, 0.8, 0.9), Vector3.new(0, 2.6, -2.85), "body" },
	{ "EyeL", Vector3.new(0.45, 0.5, 0.1), Vector3.new(-0.45, 3.15, -2.53), "white" },
	{ "EyeR", Vector3.new(0.45, 0.5, 0.1), Vector3.new(0.45, 3.15, -2.53), "white" },
	{ "PupilL", Vector3.new(0.22, 0.3, 0.06), Vector3.new(-0.42, 3.1, -2.6), "ink" },
	{ "PupilR", Vector3.new(0.22, 0.3, 0.06), Vector3.new(0.42, 3.1, -2.6), "ink" },
	{ "HornL", Vector3.new(0.3, 0.8, 0.3), Vector3.new(-0.5, 3.95, -1.5), "belly", { -20, 0, 10 } },
	{ "HornR", Vector3.new(0.3, 0.8, 0.3), Vector3.new(0.5, 3.95, -1.5), "belly", { -20, 0, -10 } },
	{ "WingL", Vector3.new(2.4, 0.15, 1.7), Vector3.new(-1.9, 2.75, 0), "wing", { 0, 0, -25 } },
	{ "WingR", Vector3.new(2.4, 0.15, 1.7), Vector3.new(1.9, 2.75, 0), "wing", { 0, 0, 25 } },
	{ "WingTipL", Vector3.new(1.4, 0.15, 1.3), Vector3.new(-3.3, 3.55, 0.2), "wing", { 0, 0, -40 } },
	{ "WingTipR", Vector3.new(1.4, 0.15, 1.3), Vector3.new(3.3, 3.55, 0.2), "wing", { 0, 0, 40 } },
	{ "Tail", Vector3.new(0.9, 0.9, 1.6), Vector3.new(0, 1.3, 2.1), "body" },
	{ "Tail2", Vector3.new(0.6, 0.6, 1.4), Vector3.new(0, 1.65, 3.3), "body", { 20, 0, 0 } },
	{ "TailTip", Vector3.new(0.9, 0.2, 0.9), Vector3.new(0, 1.95, 4.05), "wing", { 0, 45, 0 } },
	{ "Spike1", Vector3.new(0.3, 0.5, 0.5), Vector3.new(0, 2.7, -0.8), "wing" },
	{ "Spike2", Vector3.new(0.3, 0.5, 0.5), Vector3.new(0, 2.7, 0.2), "wing" },
	{ "Spike3", Vector3.new(0.3, 0.5, 0.5), Vector3.new(0, 2.6, 1.2), "wing" },
	{ "LegFL", Vector3.new(0.7, 0.9, 0.7), Vector3.new(-0.75, 0.45, -0.9), "body" },
	{ "LegFR", Vector3.new(0.7, 0.9, 0.7), Vector3.new(0.75, 0.45, -0.9), "body" },
	{ "LegBL", Vector3.new(0.7, 0.9, 0.7), Vector3.new(-0.75, 0.45, 0.9), "body" },
	{ "LegBR", Vector3.new(0.7, 0.9, 0.7), Vector3.new(0.75, 0.45, 0.9), "body" },
}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(27, 29, 43)

function DragonBuilder.scaleFor(stage)
	return Constants.STAGE_SCALE[stage] or 1
end

-- Height of the Root centre above the feet for a given scale.
function DragonBuilder.rootHeight(scale)
	return ROOT_HALF * scale
end

-- build(id, special, stage, sizeMult) -> Model. Position it with DragonBuilder.place(model, feetCFrame).
-- sizeMult shrinks a dragon you carry so it doesn't block your view.
function DragonBuilder.build(id, special, stage, sizeMult)
	local d = Dragons.byId[id]
	local s = DragonBuilder.scaleFor(stage or 1) * (sizeMult or 1)
	local model = Instance.new("Model")
	model.Name = "Dragon_" .. id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 3.5, 5) * s
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = true
	root.CFrame = CFrame.new(0, ROOT_HALF * s, 0)
	root.Parent = model
	model.PrimaryPart = root
	local colors = { body = d.body, belly = d.belly, wing = d.wing, white = WHITE, ink = INK }
	if special == "GOLD" then
		colors.body, colors.wing = Color3.fromRGB(255, 205, 60), Color3.fromRGB(235, 160, 30)
	elseif special == "ICE" then
		colors.body, colors.wing = Color3.fromRGB(185, 235, 255), Color3.fromRGB(120, 200, 255)
	end
	for _, spec in PARTS do
		local p = Instance.new("Part")
		p.Name = spec[1]
		p.Size = spec[2] * s
		local rot = spec[5] or { 0, 0, 0 }
		p.CFrame = root.CFrame
			* CFrame.new((spec[3] - Vector3.new(0, ROOT_HALF, 0)) * s)
			* CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		p.Color = colors[spec[4]]
		p.Material = special == "ICE" and spec[4] ~= "ink" and Enum.Material.Glass or Enum.Material.SmoothPlastic
		if special == "GOLD" and (spec[4] == "body" or spec[4] == "wing") then
			p.Material = Enum.Material.Foil
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	-- Specials and rare glow
	local body = model:FindFirstChild("Body")
	if special == "FIRE" then
		local fire = Instance.new("Fire")
		fire.Size = 4 * s
		fire.Heat = 3
		fire.Parent = body
	elseif special == "ICE" or special == "GOLD" or special == "RAINBOW" then
		local sp = Instance.new("Sparkles")
		sp.SparkleColor = Dragons.Specials[special].color
		sp.Parent = body
	end
	if special == "RAINBOW" or id == "REX" then
		CollectionService:AddTag(model, "RainbowDragon")
	end
	local rank = Dragons.RarityRank[d.rarity]
	if rank >= 4 or special then
		local light = Instance.new("PointLight")
		light.Color = special and Dragons.Specials[special].color or Dragons.RarityColor[d.rarity]
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = body
	end
	model:SetAttribute("DragonId", id)
	model:SetAttribute("Special", special)
	model:SetAttribute("Stage", stage or 1)
	model:SetAttribute("Scale", s)
	return model
end

-- Put the dragon's feet at feetCFrame (its facing comes from feetCFrame's rotation).
function DragonBuilder.place(model, feetCFrame)
	local s = model:GetAttribute("Scale") or 1
	model:PivotTo(feetCFrame * CFrame.new(0, ROOT_HALF * s, 0))
end

-- A floating name tag: line 1 in the rarity colour, line 2 underneath.
function DragonBuilder.label(model, line1, color, line2)
	local root = model.PrimaryPart
	local s = model:GetAttribute("Scale") or 1
	local gui = root:FindFirstChild("Tag")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.new(8, 0, 2.6, 0)
		gui.StudsOffset = Vector3.new(0, 2.4 * s + 1.2, 0)
		gui.MaxDistance = 50
		gui.LightInfluence = 0
		gui.Parent = root
		for i, name in { "Line1", "Line2" } do
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, 0, 0.5, 0)
			t.Position = UDim2.new(0, 0, (i - 1) * 0.5, 0)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextStrokeTransparency = 0
			t.TextStrokeColor3 = INK
			t.TextColor3 = WHITE
			t.Parent = gui
		end
	end
	gui.Line1.Text = line1
	gui.Line1.TextColor3 = color or WHITE
	gui.Line2.Text = line2 or ""
	return gui
end

return DragonBuilder

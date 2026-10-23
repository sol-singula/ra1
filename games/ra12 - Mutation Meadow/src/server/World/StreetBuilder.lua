--[[
A placeholder street, built when the place has none (Studio normally places Workspace.Street). Same layout the
services expect:

  Workspace.Street.Plots.Plot1..Plot8, each with
    Tiles/<id>        "1".."64" (row-major 8 x 8; row 1 is nearest the road)
    ExtraRow          the Extra Plot Row bed: Bed + extra1..extra8 (hidden until owned)
    Sign              ProximityPrompt "Expand" (opens Upgrades)
    SellStand         ProximityPrompt "Sell"
    Pedestals/P1..P7
    Mailbox           attribute GardenName
  Workspace.Street.Sunflower: Stem (ProximityPrompt "Water") and the looks Drooping, Perking, Standing, Bloom, Wilt
  Every tile and pedestal has a ClickDetector "Click".

  StreetBuilder.build(parent) -> the Street model
]]
local Tiles = require(game:GetService("ReplicatedStorage").Shared.Tiles)

local StreetBuilder = {}

local PLOTS = 8
local TILE = 4 -- studs per tile
local SPACING = 52 -- between plot centres along the road
local ROAD_Z = -10
local SOIL = Color3.fromRGB(120, 84, 52)
local GRASS = Color3.fromRGB(96, 168, 72)
local CLICK_DISTANCE = 32

local function part(parent, name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function prompt(parent, name, action, object)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function tile(parent, id, pos)
	local t = part(parent, id, Vector3.new(TILE - 0.3, 1, TILE - 0.3), pos, SOIL, Enum.Material.Ground)
	t.Transparency = 1
	t.CanCollide = false
	local click = Instance.new("ClickDetector")
	click.Name = "Click"
	click.MaxActivationDistance = CLICK_DISTANCE
	click.Parent = t
	return t
end

local function plot(street, index)
	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	local ox = (index - (PLOTS + 1) / 2) * SPACING
	local width = Tiles.GRID * TILE
	local oz = 4 -- the plot starts this far back from the road edge
	part(
		model,
		"Ground",
		Vector3.new(width + 12, 1, width + TILE + 16),
		Vector3.new(ox, -0.5, oz + (width + TILE) / 2),
		GRASS,
		Enum.Material.Grass
	)

	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = model
	for r = 1, Tiles.GRID do
		for c = 1, Tiles.GRID do
			tile(tiles, Tiles.id(r, c), Vector3.new(ox + (c - (Tiles.GRID + 1) / 2) * TILE, 0.5, oz + (r - 0.5) * TILE))
		end
	end

	local extra = Instance.new("Model")
	extra.Name = "ExtraRow"
	extra.Parent = model
	local rowZ = oz + (Tiles.GRID + 0.5) * TILE + 1
	local bed = part(
		extra,
		"Bed",
		Vector3.new(width + 1, 0.6, TILE + 1),
		Vector3.new(ox, 0.2, rowZ),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Wood
	)
	bed.Transparency = 1
	bed.CanCollide = false
	for c = 1, Tiles.GRID do
		tile(extra, "extra" .. c, Vector3.new(ox + (c - (Tiles.GRID + 1) / 2) * TILE, 0.5, rowZ))
	end

	local front = oz - 2.5
	local sign = part(
		model,
		"Sign",
		Vector3.new(4, 3, 0.5),
		Vector3.new(ox - width / 2 + 2, 1.5, front),
		Color3.fromRGB(200, 160, 100),
		Enum.Material.Wood
	)
	prompt(sign, "Expand", "Expand", "Plot Upgrades")
	local stand = part(
		model,
		"SellStand",
		Vector3.new(5, 3, 3),
		Vector3.new(ox + width / 2 - 3, 1.5, front),
		Color3.fromRGB(230, 200, 120),
		Enum.Material.Wood
	)
	prompt(stand, "Sell", "Sell", "Sell Stand")
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = model
	for i = 1, 7 do
		part(
			pedestals,
			"P" .. i,
			Vector3.new(2, 2, 2),
			Vector3.new(ox - 9 + (i - 1) * 3, 1, front - 1),
			Color3.fromRGB(220, 220, 225),
			Enum.Material.Marble
		)
	end
	local mailbox = part(
		model,
		"Mailbox",
		Vector3.new(1, 3, 1),
		Vector3.new(ox - width / 2 - 1, 1.5, front - 2),
		Color3.fromRGB(60, 90, 180)
	)
	mailbox:SetAttribute("GardenName", "")
	model.Parent = street
	return model
end

-- the Block Party sunflower: a Stem (the prompt and the range centre) and one part per look; one shows at a time
local function sunflower(street)
	local model = Instance.new("Model")
	model.Name = "Sunflower"
	local stem = part(
		model,
		"Stem",
		Vector3.new(2, 14, 2),
		Vector3.new(0, 7, ROAD_Z - 16),
		Color3.fromRGB(70, 140, 50),
		Enum.Material.Grass
	)
	prompt(stem, "Water", "Water", "Sunflower")
	local looks = {
		{ "Drooping", Color3.fromRGB(170, 150, 60), 11 },
		{ "Perking", Color3.fromRGB(220, 190, 50), 14 },
		{ "Standing", Color3.fromRGB(250, 210, 40), 16 },
		{ "Bloom", Color3.fromRGB(255, 200, 0), 18 },
		{ "Wilt", Color3.fromRGB(130, 110, 70), 10 },
	}
	for _, look in looks do
		local head = part(
			model,
			look[1],
			Vector3.new(8, 8, 1.5),
			Vector3.new(0, look[3], ROAD_Z - 16),
			look[2],
			Enum.Material.SmoothPlastic
		)
		head.CanCollide = false
		head.Transparency = if look[1] == "Drooping" then 0 else 1
	end
	model.Parent = street
	return model
end

function StreetBuilder.build(parent)
	local street = Instance.new("Model")
	street.Name = "Street"
	part(
		street,
		"Road",
		Vector3.new(PLOTS * SPACING + 40, 1, 14),
		Vector3.new(0, -0.5, ROAD_Z),
		Color3.fromRGB(70, 70, 75),
		Enum.Material.Asphalt
	)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = street
	for i = 1, PLOTS do
		plot(plots, i)
	end
	sunflower(street)
	street.Parent = parent
	return street
end

return StreetBuilder

-- Greybox Restaurant Row (DST_01, BLD_17): ground, road, sidewalks and 8 empty plots facing the street.
-- RestaurantService builds a restaurant on a plot when a player claims it.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local WorldBuilder = {}

WorldBuilder.PLOT_SPACING = 80
WorldBuilder.PLOT_Z = 40 -- plot centres sit behind the sidewalk; their fronts face -Z (the street)

local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
WorldBuilder.block = block

function WorldBuilder.plotCFrame(index)
	local x = (index - (Constants.MAX_PLAYERS + 1) / 2) * WorldBuilder.PLOT_SPACING
	return CFrame.new(x, 0, WorldBuilder.PLOT_Z)
end

function WorldBuilder.build()
	local city = Instance.new("Folder")
	city.Name = "City"
	city.Parent = workspace

	if not workspace:FindFirstChild("Baseplate") then
		block(
			city,
			"Ground",
			Vector3.new(1024, 2, 1024),
			CFrame.new(0, -1, 0),
			Color3.fromRGB(106, 176, 76),
			Enum.Material.Grass
		)
	end
	local length = Constants.MAX_PLAYERS * WorldBuilder.PLOT_SPACING + 80
	block(
		city,
		"Road",
		Vector3.new(length, 0.2, 22),
		CFrame.new(0, 0.1, -10),
		Color3.fromRGB(58, 60, 72),
		Enum.Material.Asphalt
	)
	block(
		city,
		"Sidewalk",
		Vector3.new(length, 0.4, 12),
		CFrame.new(0, 0.2, 6),
		Color3.fromRGB(200, 196, 186),
		Enum.Material.Concrete
	)
	block(
		city,
		"SidewalkFar",
		Vector3.new(length, 0.4, 10),
		CFrame.new(0, 0.2, -26),
		Color3.fromRGB(200, 196, 186),
		Enum.Material.Concrete
	)
	for i = 1, math.floor(length / 24) do
		local x = -length / 2 + i * 24
		block(city, "LaneMark", Vector3.new(8, 0.25, 0.6), CFrame.new(x, 0.15, -10), Color3.fromRGB(255, 220, 90))
	end

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = city
	for i = 1, Constants.MAX_PLAYERS do
		local pad = block(
			plots,
			"Plot" .. i,
			Vector3.new(66, 0.3, 54),
			WorldBuilder.plotCFrame(i) * CFrame.new(0, 0.15, 0),
			Color3.fromRGB(150, 140, 120),
			Enum.Material.Concrete
		)
		pad:SetAttribute("PlotIndex", i)
	end

	local restaurants = Instance.new("Folder")
	restaurants.Name = "Restaurants"
	restaurants.Parent = workspace

	Lighting.ClockTime = 15
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 130)
end

return WorldBuilder

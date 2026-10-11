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

	-- street dressing between the plots: trees, lamp posts, flower beds and crosswalks
	local props = Instance.new("Folder")
	props.Name = "StreetProps"
	props.Parent = city
	local function prop(name, size, cf, color, material, shape)
		local p = block(props, name, size, cf, color, material)
		if shape then
			p.Shape = shape
		end
		return p
	end
	for i = 0, Constants.MAX_PLAYERS do
		local x = (i - Constants.MAX_PLAYERS / 2) * WorldBuilder.PLOT_SPACING
		-- tree on the far sidewalk
		prop(
			"Trunk",
			Vector3.new(1.2, 7, 1.2),
			CFrame.new(x, 3.5, -27),
			Color3.fromRGB(120, 82, 52),
			Enum.Material.Wood
		)
		prop(
			"Canopy",
			Vector3.new(7, 7, 7),
			CFrame.new(x, 9, -27),
			Color3.fromRGB(80, 170, 80),
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		prop(
			"Canopy",
			Vector3.new(5, 5, 5),
			CFrame.new(x + 2, 11, -26),
			Color3.fromRGB(96, 186, 92),
			Enum.Material.Grass,
			Enum.PartType.Ball
		)
		-- lamp post on the near sidewalk, between restaurants
		prop(
			"LampPost",
			Vector3.new(0.6, 12, 0.6),
			CFrame.new(x, 6, 2),
			Color3.fromRGB(40, 44, 56),
			Enum.Material.Metal
		)
		prop(
			"LampArm",
			Vector3.new(0.4, 0.4, 3),
			CFrame.new(x, 12, 0.8),
			Color3.fromRGB(40, 44, 56),
			Enum.Material.Metal
		)
		local bulb = prop(
			"LampBulb",
			Vector3.new(1.4, 0.8, 1.4),
			CFrame.new(x, 11.6, -0.4),
			Color3.fromRGB(255, 236, 190),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 1
		light.Color = Color3.fromRGB(255, 220, 170)
		light.Parent = bulb
		-- flower bed between plots
		prop("Planter", Vector3.new(8, 1, 3), CFrame.new(x, 0.9, 10), Color3.fromRGB(150, 100, 70), Enum.Material.Wood)
		for f = -1, 1 do
			local colors =
				{ Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 210, 80), Color3.fromRGB(170, 120, 255) }
			prop(
				"Flowers",
				Vector3.new(2, 2, 2),
				CFrame.new(x + f * 2.5, 2, 10),
				colors[f + 2],
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
		-- crosswalk
		for z = 0, 4 do
			prop("Crosswalk", Vector3.new(8, 0.22, 2), CFrame.new(x, 0.13, -18 + z * 4), Color3.fromRGB(245, 245, 245))
		end
	end

	-- lighting: warm afternoon with a little haze, bloom and sun rays.
	-- For the best look also set Lighting.Technology to Future in Studio (it can't be set from a script).
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 140)
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local function effect(className, values)
		local e = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
		for k, v in values do
			e[k] = v
		end
		e.Parent = Lighting
	end
	effect("Atmosphere", {
		Density = 0.28,
		Offset = 0.2,
		Color = Color3.fromRGB(199, 220, 240),
		Decay = Color3.fromRGB(110, 120, 140),
		Glare = 0.2,
		Haze = 1.2,
	})
	effect(
		"ColorCorrectionEffect",
		{ Saturation = 0.18, Contrast = 0.06, Brightness = 0.02, TintColor = Color3.fromRGB(255, 248, 238) }
	)
	effect("BloomEffect", { Intensity = 0.6, Size = 24, Threshold = 1.6 })
	effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.6 })
end

return WorldBuilder

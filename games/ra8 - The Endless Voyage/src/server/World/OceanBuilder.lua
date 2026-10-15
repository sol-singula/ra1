--[[
The world that's always there (master plan §1: a beautiful, open ocean): the water, the sea floor, the far islands
scattered on the horizon, a buoy at every plot and the sky. Rafts (RaftService), debris (OceanService), islands
(IslandBuilder) and creatures come and go on top of it.

  OceanBuilder.build()     once, at start-up
  OceanBuilder.folder(name)   workspace folders the services put things in
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Kit = require(ReplicatedStorage.Shared.World.Kit)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)

local OceanBuilder = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local function folder(name, parent)
	local f = (parent or workspace):FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent or workspace
	return f
end
OceanBuilder.folder = folder

local function water()
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if not terrain then
		return
	end
	pcall(function()
		terrain.WaterColor = Color3.fromRGB(22, 116, 156)
		terrain.WaterTransparency = 0.42
		terrain.WaterReflectance = 0.7
		terrain.WaterWaveSize = 0.24
		terrain.WaterWaveSpeed = 10
	end)
	local size = Constants.OCEAN_SIZE
	local depth = Constants.WATER_LEVEL - Constants.SEA_FLOOR
	-- the sea floor, then the water on it (a little deeper in the middle of each plot's island zone: the Trench)
	terrain:FillBlock(CFrame.new(0, Constants.SEA_FLOOR - 8, 0), V3(size, 16, size), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, Constants.SEA_FLOOR + depth / 2, 0), V3(size, depth, size), Enum.Material.Water)
end

local FAR_PART = { CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false }

-- Far islands you can see but never reach, scattered at random distances (OceanLayout.HORIZON): green humps with
-- trees, a peak with snow on it, a sandy atoll with palms. Persistent, so they are on the horizon from the first
-- frame whatever streams in later.
local function horizon(map)
	local f = folder("Horizon", map)
	local rng = Random.new(88)
	for i, h in OceanLayout.HORIZON do
		local m = Kit.model("Isle" .. i, f)
		pcall(function()
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		local base = V3(h.x, Constants.WATER_LEVEL - 2, h.z)
		local s = h.size
		local sandy = h.kind == "atoll"
		-- the shore: a wide low ellipse of sand, then the land on it
		Kit.ellipsoid(m, "Shore", base + V3(0, s * 0.04, 0), V3(s * 2.6, s * 0.2, s * 2), C.sand, M.Sand, FAR_PART)
		if not sandy then
			Kit.ellipsoid(
				m,
				"Isle",
				base + V3(0, s * 0.14, 0),
				V3(s * 2.1, s * 0.5, s * 1.6),
				C.grassDark,
				M.Grass,
				FAR_PART
			)
			Kit.ellipsoid(
				m,
				"Hump",
				base + V3(rng:NextNumber(-0.3, 0.3) * s, s * 0.26, rng:NextNumber(-0.2, 0.2) * s),
				V3(s * 1.1, s * 0.5, s * 0.9),
				C.grass,
				M.Grass,
				FAR_PART
			)
		end
		if h.kind == "peak" then
			local hh = s * (1.1 + h.far * 0.5)
			Kit.cone(m, "Peak", base + V3(0, s * 0.2, 0), s * 0.95, hh, C.rockDark, 6, M.Rock, FAR_PART)
			if hh > 60 then
				Kit.cone(
					m,
					"Snow",
					base + V3(0, s * 0.2 + hh * 0.62, 0),
					s * 0.95 * 0.38,
					hh * 0.38,
					C.white,
					6,
					M.Snow,
					FAR_PART
				)
			end
			Kit.cone(
				m,
				"Peak2",
				base + V3(s * 0.45, s * 0.18, s * 0.2),
				s * 0.6,
				hh * 0.55,
				C.rock,
				5,
				M.Rock,
				FAR_PART
			)
		end
		-- trees: a few round crowns on the humps, palms on the atoll
		local n = sandy and 6 or 5
		for _ = 1, n do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0.25, 0.8) * s
			local at = base + V3(math.cos(a) * r, sandy and s * 0.08 or s * 0.34, math.sin(a) * r * 0.75)
			if sandy then
				local th = s * rng:NextNumber(0.25, 0.4)
				Kit.cyl(
					m,
					"Trunk",
					CFrame.new(at + V3(0, th / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
					th,
					s * 0.05,
					C.bark,
					M.Wood,
					FAR_PART
				)
				Kit.ellipsoid(m, "Fronds", at + V3(0, th, 0), V3(s * 0.4, s * 0.12, s * 0.4), C.leaf, M.Grass, FAR_PART)
			else
				Kit.ellipsoid(
					m,
					"Trees",
					at,
					V3(s * rng:NextNumber(0.3, 0.5), s * rng:NextNumber(0.25, 0.4), s * rng:NextNumber(0.3, 0.5)),
					C.pineDark:Lerp(C.leaf, rng:NextNumber(0, 0.5)),
					M.Grass,
					FAR_PART
				)
			end
		end
	end
end

-- A buoy at each plot's upstream edge (where the debris comes from), with the plot's number.
local function buoys(map)
	local f = folder("Buoys", map)
	for _, plot in OceanLayout.plots do
		local pos = plot.center - plot.current * (Constants.DEBRIS_FROM + 10) + V3(0, Constants.WATER_LEVEL, 0)
		local m = Kit.model("Buoy" .. plot.index, f)
		Kit.disc(m, "Float", pos + V3(0, 0.6, 0), 3, 1.2, C.canvasRed, M.SmoothPlastic, { CanCollide = false })
		Kit.box(m, "Post", CFrame.new(pos + V3(0, 2.6, 0)), V3(0.4, 3.2, 0.4), C.iron, M.Metal, { CanCollide = false })
		local light = Kit.ball(m, "Light", pos + V3(0, 4.4, 0), 0.9, C.warm, M.Neon, { CanCollide = false })
		Kit.light(light, "PointLight", { Name = "Glow", Color = C.warm, Range = 14, Brightness = 1.2 })
		m:SetAttribute("Plot", plot.index)
	end
end

function OceanBuilder.build()
	local map = folder("Map")
	water()
	horizon(map)
	buoys(map)
	for _, name in { "Rafts", "Debris", "Islands", "Creatures", "Drops", "Fx" } do
		folder(name)
	end
	-- the sky and the first light (the client follows the clock from here): a big sun and moon, stars at night,
	-- real clouds over the water
	pcall(function()
		local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
		sky.StarCount = 3000
		sky.SunAngularSize = 16
		sky.MoonAngularSize = 13
		sky.CelestialBodiesShown = true
		sky.Parent = Lighting
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain and not terrain:FindFirstChildOfClass("Clouds") then
			local clouds = Instance.new("Clouds")
			clouds.Cover = 0.38
			clouds.Density = 0.5
			clouds.Parent = terrain
		end
	end)
	LightingPresets.apply("day")
	workspace:SetAttribute("Phase", "day")
end

return OceanBuilder

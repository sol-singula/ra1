--[[
The world that's always there (master plan §1: a beautiful, open ocean): the water, the sea floor, the far islands
on the horizon, a buoy at every plot and the sky. Rafts (RaftService), debris (OceanService), islands
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
		terrain.WaterColor = Color3.fromRGB(28, 118, 150)
		terrain.WaterTransparency = 0.5
		terrain.WaterReflectance = 0.5
		terrain.WaterWaveSize = 0.18
		terrain.WaterWaveSpeed = 12
	end)
	local size = Constants.OCEAN_SIZE
	local depth = Constants.WATER_LEVEL - Constants.SEA_FLOOR
	-- the sea floor, then the water on it (a little deeper in the middle of each plot's island zone: the Trench)
	terrain:FillBlock(CFrame.new(0, Constants.SEA_FLOOR - 8, 0), V3(size, 16, size), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, Constants.SEA_FLOOR + depth / 2, 0), V3(size, depth, size), Enum.Material.Water)
end

-- Far islands you can see but never reach: low green humps and a peak or two.
local function horizon(map)
	local f = folder("Horizon", map)
	local rng = Random.new(88)
	for _, h in OceanLayout.HORIZON do
		local base = V3(h.x, Constants.WATER_LEVEL - 2, h.z)
		local s = h.size
		Kit.ellipsoid(f, "Isle", base + V3(0, s * 0.12, 0), V3(s * 2.2, s * 0.5, s * 1.6), C.grassDark, M.Grass, {
			CastShadow = false,
			CanCollide = false,
		})
		if h.kind == "peak" then
			Kit.cone(f, "Peak", base + V3(0, s * 0.2, 0), s * 0.9, s * 1.1, C.rockDark, 5, M.Rock, {
				CastShadow = false,
				CanCollide = false,
			})
		end
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0.2, 0.7) * s
			Kit.ellipsoid(
				f,
				"Trees",
				base + V3(math.cos(a) * r, s * 0.3, math.sin(a) * r * 0.7),
				V3(s * 0.4, s * 0.3, s * 0.4),
				C.pineDark,
				M.Grass,
				{ CastShadow = false, CanCollide = false }
			)
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
	-- the sky and the first light (the client follows the clock from here)
	pcall(function()
		local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
		sky.StarCount = 3000
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

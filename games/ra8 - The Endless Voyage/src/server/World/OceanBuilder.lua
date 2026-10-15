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
local OceanModels = require(ReplicatedStorage.Shared.World.OceanModels)

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

-- Far islands you can see but never reach, scattered at random distances (OceanLayout.HORIZON, OceanModels.isle).
-- Persistent, so they are on the horizon from the first frame whatever streams in later.
local function horizon(map)
	local f = folder("Horizon", map)
	local rng = Random.new(88)
	for i, h in OceanLayout.HORIZON do
		local m = OceanModels.isle(f, "Isle" .. i, V3(h.x, Constants.WATER_LEVEL - 2, h.z), h, rng)
		pcall(function()
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
	end
end

-- A buoy at each plot's upstream edge (where the debris comes from), with the plot's number.
-- A channel buoy at each plot's upstream edge (where the debris comes from): a striped float, a bell on a short
-- tower, and a flag with the plot's number.
local function buoys(map)
	local f = folder("Buoys", map)
	local brass = C.gold:Lerp(C.goldDark, 0.5)
	for _, plot in OceanLayout.plots do
		local pos = plot.center - plot.current * (Constants.DEBRIS_FROM + 10) + V3(0, Constants.WATER_LEVEL, 0)
		local m = Kit.model("Buoy" .. plot.index, f)
		local still = { CanCollide = false, CastShadow = false }
		Kit.disc(m, "Float", pos + V3(0, 0.3, 0), 3.6, 1.6, C.canvasRed, M.SmoothPlastic, still)
		Kit.disc(m, "Stripe", pos + V3(0, 1.3, 0), 3.2, 0.5, C.white, M.SmoothPlastic, still)
		Kit.disc(m, "Top", pos + V3(0, 1.75, 0), 2.4, 0.4, C.canvasRed, M.SmoothPlastic, still)
		for _, a in { 0, 120, 240 } do
			local r = math.rad(a)
			Kit.box(
				m,
				"Leg",
				CFrame.new(pos + V3(math.cos(r) * 0.7, 3.2, math.sin(r) * 0.7)) * CFrame.Angles(0, -r, math.rad(8)),
				V3(0.18, 2.8, 0.18),
				C.iron,
				M.Metal,
				still
			)
		end
		Kit.disc(m, "Ring", pos + V3(0, 4.6, 0), 1.6, 0.16, C.iron, M.Metal, still)
		Kit.cone(m, "Bell", pos + V3(0, 3.5, 0), 1, 0.9, brass, 3, M.Metal, still)
		Kit.ball(m, "Clapper", pos + V3(0, 3.45, 0), 0.26, C.iron, M.Metal, still)
		Kit.box(m, "Mast", CFrame.new(pos + V3(0, 5.4, 0)), V3(0.12, 1.6, 0.12), C.iron, M.Metal, still)
		local flag =
			Kit.box(m, "Flag", CFrame.new(pos + V3(0.66, 5.8, 0)), V3(1.2, 0.8, 0.06), C.white, M.Fabric, still)
		Kit.text(flag, Enum.NormalId.Front, tostring(plot.index), { size = 32, color = C.canvasRed })
		Kit.text(flag, Enum.NormalId.Back, tostring(plot.index), { size = 32, color = C.canvasRed })
		m:SetAttribute("Plot", plot.index)
	end
end

function OceanBuilder.build()
	-- a place file's Baseplate sits exactly at the water level (its top at y = 0): nothing may lie on the water
	for _, c in workspace:GetChildren() do
		if c:IsA("BasePart") and (c.Name == "Baseplate" or c:IsA("SpawnLocation")) then
			c:Destroy()
		end
	end
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

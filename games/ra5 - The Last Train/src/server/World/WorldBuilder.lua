-- Builds the world once at server start:
--   the train (always in the workspace; it never moves)
--   the station and every stop as templates in ServerStorage (ExpeditionService puts one beside the train)
--   the emergency signal hut far away (RecoveryService)
-- and keeps handles to all of it in WorldBuilder.layout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local Stops = require(ReplicatedStorage.Shared.Data.Stops)
local RecoveryBuilder = require(script.Parent.RecoveryBuilder)
local StationBuilder = require(script.Parent.StationBuilder)
local StopBuilder = require(script.Parent.StopBuilder)
local TrainBuilder = require(script.Parent.TrainBuilder)

local WorldBuilder = {}

WorldBuilder.layout = nil

function WorldBuilder.build()
	if WorldBuilder.layout then
		return WorldBuilder.layout
	end
	-- remove what Studio's Baseplate template puts in a new place
	for _, child in workspace:GetChildren() do
		if child.Name == "Baseplate" or (child:IsA("SpawnLocation") and child.Name == "SpawnLocation") then
			child:Destroy()
		end
	end
	LightingPresets.apply("station")
	workspace:SetAttribute("LightPreset", "station")

	local train = TrainBuilder.build(workspace)
	-- a fallback spawn on the entry seats (ExpeditionService moves everyone to the right place on arrival)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "EntrySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(4, 0.4, 4)
	spawn.CFrame = CFrame.new(Layout.ENTRY_CF.Position.X, Layout.FLOOR_Y + 0.1, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CastShadow = false
	spawn.Duration = 0
	spawn.Parent = workspace

	local templates = Kit.folder("Templates", ServerStorage)
	local station = StationBuilder.build(templates)
	local stops = {}
	for _, stop in Stops.list do
		stops[stop.key] = StopBuilder.build(templates, stop)
	end
	local recovery = RecoveryBuilder.build(workspace)
	-- the place things are swapped into
	local scenery = Kit.folder("Scenery", workspace)

	WorldBuilder.layout = {
		train = train,
		station = station,
		stops = stops,
		recovery = recovery,
		scenery = scenery,
		templates = templates,
	}
	return WorldBuilder.layout
end

return WorldBuilder

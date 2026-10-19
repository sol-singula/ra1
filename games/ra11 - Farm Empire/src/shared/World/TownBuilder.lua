--[[
The shared town (master plan §4): a square in the middle of the avenue with the market board, the boost meter,
the leaderboards, a fountain, and the avenue itself running east-west past every farm's gate. Built once by
TerritoryService at start.

  TownBuilder.build(parent)   a Model "Town"
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Layout = require(script.Parent.Layout)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local TownBuilder = {}

function TownBuilder.build(parent)
	local m = Shapes.model(parent, "Town")
	local half = Layout.TOWN / 2
	-- the avenue: the whole width of the map, with a dashed centre line
	local width = 1000
	local road =
		Shapes.part(m, Vector3.new(width, 1, Layout.AVENUE), CFrame.new(0, -0.5, 0), P.road, { CanCollide = true })
	road.Name = "Avenue"
	road.Material = Enum.Material.Asphalt
	for x = -width / 2 + 10, width / 2 - 10, 12 do
		if math.abs(x) > half then
			Shapes.part(m, Vector3.new(6, 0.1, 0.5), CFrame.new(x, 0.06, 0), P.roadLine)
		end
	end
	-- pavements either side of the avenue
	for _, z in { -Layout.AVENUE / 2 - 2, Layout.AVENUE / 2 + 2 } do
		Shapes.part(m, Vector3.new(width, 0.6, 4), CFrame.new(0, -0.3, z), P.concrete, { CanCollide = true })
	end
	-- the square: paving over the avenue, a fountain in the middle
	local square = Shapes.part(
		m,
		Vector3.new(Layout.TOWN, 1.2, Layout.TOWN),
		CFrame.new(0, -0.4, 0),
		P.concrete,
		{ CanCollide = true }
	)
	square.Name = "Square"
	square.Material = Enum.Material.Cobblestone
	local f = Layout.TOWN_SPOTS.fountain
	Shapes.cylinder(m, Vector3.new(1.5, 16, 16), CFrame.new(f.x, 0.9, f.z) * CFrame.Angles(0, 0, math.pi / 2), P.steel)
	local water = Shapes.cylinder(
		m,
		Vector3.new(0.6, 14, 14),
		CFrame.new(f.x, 1.5, f.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.water
	)
	water.Transparency = 0.3
	Shapes.cylinder(m, Vector3.new(6, 2, 2), CFrame.new(f.x, 3.5, f.z) * CFrame.Angles(0, 0, math.pi / 2), P.steel)
	Shapes.ball(m, Vector3.new(3, 3, 3), CFrame.new(f.x, 7, f.z), P.safetyYellow)
	-- the market board (west)
	local b = Layout.TOWN_SPOTS.board
	local board =
		Shapes.part(m, Vector3.new(16, 9, 1), CFrame.new(b.x, 6, b.z) * CFrame.Angles(0, math.pi / 2, 0), P.woodDark)
	board.Name = "MarketBoard"
	Shapes.part(m, Vector3.new(17, 1, 2), CFrame.new(b.x, 11, b.z) * CFrame.Angles(0, math.pi / 2, 0), P.barnRed)
	for _, z in { -7, 7 } do
		Shapes.part(m, Vector3.new(0.8, 12, 0.8), CFrame.new(b.x, 6, b.z + z), P.woodDark)
	end
	Shapes.face(board, "MARKET ORDERS", Enum.NormalId.Front, { PixelsPerStud = 20 })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Market"
	prompt.ActionText = "Market orders"
	prompt.ObjectText = "Town board"
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	-- the leaderboards (east): three boards side by side
	local lb = Layout.TOWN_SPOTS.boards
	for k = -1, 1 do
		local plate = Shapes.part(m, Vector3.new(0.8, 10, 12), CFrame.new(lb.x, 6.5, lb.z + k * 13), P.steelDark)
		plate.Name = "Leaderboard"
		plate:SetAttribute("Board", ({ "earned", "stage", "sold" })[k + 2])
		Shapes.part(m, Vector3.new(1, 0.8, 13), CFrame.new(lb.x, 11.9, lb.z + k * 13), P.safetyYellow)
	end
	-- the boost meter (north): a tall glass tube on a plinth with the three boosts' colours
	local mt = Layout.TOWN_SPOTS.meter
	local plinth = Shapes.part(m, Vector3.new(10, 2, 10), CFrame.new(mt.x, 1, mt.z), P.steelDark, { CanCollide = true })
	plinth.Name = "MeterPlinth"
	local tube =
		Shapes.cylinder(m, Vector3.new(12, 4, 4), CFrame.new(mt.x, 8, mt.z) * CFrame.Angles(0, 0, math.pi / 2), P.glass)
	tube.Name = "MeterTube"
	tube.Transparency = 0.5
	local fill = Shapes.cylinder(
		m,
		Vector3.new(0.2, 3.2, 3.2),
		CFrame.new(mt.x, 2.1, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.accent
	)
	fill.Name = "MeterFill"
	Shapes.cylinder(
		m,
		Vector3.new(1, 5, 5),
		CFrame.new(mt.x, 14.5, mt.z) * CFrame.Angles(0, 0, math.pi / 2),
		P.steelDark
	)
	Shapes.label(
		plinth,
		"SERVER BOOST",
		{ Size = UDim2.fromOffset(220, 50), StudsOffset = Vector3.new(0, 16, 0), MaxDistance = 160 }
	)
	local bp = Instance.new("ProximityPrompt")
	bp.Name = "Boost"
	bp.ActionText = "Server boost"
	bp.ObjectText = "Chip in"
	bp.MaxActivationDistance = 14
	bp.RequiresLineOfSight = false
	bp.Parent = plinth
	-- a spawn for visitors and a few trees
	local spawn = Shapes.part(m, Vector3.new(8, 0.3, 8), CFrame.new(0, 0.25, -half + 12), P.path)
	spawn.Name = "TownSpawn"
	for k = -2, 2 do
		Shapes.tree(m, CFrame.new(k * 28, 0, half - 8), 1.2, P.leaf)
		Shapes.tree(m, CFrame.new(k * 28, 0, -half + 8), 1.2, P.grassDark)
	end
	return m
end

return TownBuilder

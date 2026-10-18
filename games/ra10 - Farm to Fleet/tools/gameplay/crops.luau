--[[
Every crop at every stage, close up: a farm with all its fields, each crop on a row of tiles from seed to ripe (and
a golden one), for checking how the plants look.

  luaurun tools/gameplay/crops.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local CF = Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Farm = service("FarmService")
local Upg = service("UpgradeService")
local Economy = service("EconomyService")
local Data = service("PlayerDataService")
local Plots = service("PlotService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Crops = Engine.require(tree.shared.Data.Crops)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
local FarmBuilder = Engine.require(tree.shared.World.FarmBuilder)

local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1)
local p = Data:Get(player)
p.cash = 1e9
for _, key in Upgrades.LIST do
	Economy:AddXP(player, 4000, "render")
	if Upgrades[key].stage <= 2 then
		Upg:Buy(player, key)
	end
end
Engine.advance(1)
local plot = Plots:Plot(player)
local tiles = Farm:Tiles(player)
-- (the stage-2 fields: 9 to a row; each crop on a row, seed → ripe, the last golden)
local rows = {
	{ "strawberry", "carrot", "corn" },
	{ "tomato", "blueberry", "apple" },
	{ "pumpkin", "watermelon", "orange" },
}
local n = 13
for _, row in rows do
	for _, key in row do
		for phase = 0, 3 do
			local t = tiles[n]
			if t then
				FarmBuilder.crop(plot, t, key, phase, false)
			end
			n += 1
		end
		n -= 1
		-- (overwrite the last as golden on the shack's field)
	end
end
-- the shack's field: every crop ripe, two golden
local keys = {
	"strawberry",
	"carrot",
	"corn",
	"tomato",
	"blueberry",
	"apple",
	"pumpkin",
	"watermelon",
	"orange",
	"goldpumpkin",
	"strawberry",
	"corn",
}
for i, key in keys do
	if tiles[i] then
		FarmBuilder.crop(plot, tiles[i], key, 3, i >= 11)
	end
end
_ = Crops
Engine.advance(0.2)

local cam = ws.CurrentCamera
local shots = {}
local function at(x, z, y)
	return PlotLayout.toWorld(plot.index, x, z, y)
end
local function shot(name, eye, look)
	cam.CFrame = CF.lookAt(eye, look)
	Engine.advance(0.016)
	for _, d in player.Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	local snap = Capture.snapshot(
		Engine,
		{ pos = { eye.X, eye.Y, eye.Z }, target = { look.X, look.Y, look.Z }, fov = cam.FieldOfView or 70 }
	)
	snap.title = name
	snap.cinematic = true
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end
local s = PlotLayout.SPOTS
shot("crops_ripe", at(s.soil.X + 11, s.soil.Z - 14, 10), at(s.soil.X + 11, s.soil.Z + 7, 0))
local f = s.field
shot("crops_rows", at(f.X + 30, f.Z - 18, 16), at(f.X + 30, f.Z + 10, 0))
shot("crops_close", at(f.X + 6, f.Z - 7, 5), at(f.X + 10, f.Z + 2, 1))
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)

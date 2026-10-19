--[[
Close-ups for checking the art: every vehicle on a plate of its own (from the front and from the side), and the
buildings of a full farm (the stand, the shop, the warehouse and the centre, the shed, the farmhouse, the gate,
the pads, the stock yard).

  luaurun tools/gameplay/models.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Models = Engine.require(tree.shared.World.Models)
local Shapes = Engine.require(tree.shared.World.Shapes)
local Layout = Engine.require(tree.shared.World.Layout)
local Upgrades = Engine.require(tree.shared.Data.Upgrades)

-- a gallery of vehicles on a plate out past the map
local G = V3.new(0, 0, 700)
local gallery = Shapes.folder(ws, "Gallery")
Shapes.part(gallery, V3.new(160, 1, 60), CF.new(G.X, -0.5, G.Z), Engine.globals.Color3.fromRGB(110, 170, 90))
local function put(model, x)
	model:PivotTo(CF.new(G.X + x, 0, G.Z))
	return model
end
put(Models.machine(gallery, 1), -60)
put(Models.machine(gallery, 2), -36)
put(Models.machine(gallery, 3), -8)
put(Models.truck(gallery), 22)
put(Models.forklift(gallery), 44)

local Data = service("PlayerDataService")
local Upg = service("UpgradeService")
local ben = Engine.addPlayer("Ben", 902)
Engine.Players.LocalPlayer = ben
Engine.localPlayer = ben
Engine.advance(1)
if not ben:FindFirstChild("PlayerGui") then
	local g = Instance.new("PlayerGui")
	g.Parent = ben
end

local shots = {}
local function shot(name, eye, look)
	local snap =
		Capture.snapshot(Engine, { pos = { eye.X, eye.Y, eye.Z }, target = { look.X, look.Y, look.Z }, fov = 50 })
	snap.title = name
	snap.cinematic = false
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end
for _, spec in
	{
		{ "harvester", -60, 9 },
		{ "tractor", -36, 12 },
		{ "combine", -8, 18 },
		{ "truck", 22, 18 },
		{ "forklift", 44, 9 },
	}
do
	local x, d = G.X + spec[2], spec[3]
	shot(spec[1] .. "_front", V3.new(x + d * 0.7, d * 0.55, G.Z - d), V3.new(x, 2, G.Z))
	shot(spec[1] .. "_side", V3.new(x - d * 1.1, d * 0.35, G.Z + d * 0.4), V3.new(x, 2, G.Z))
end

-- a full farm
local pb = Data:Get(ben)
for _, key in Upgrades.LIST do
	if key ~= "region" and key ~= "center" then
		pb.cash = 10 ^ 12
		Upg:Buy(ben, key)
	end
end
Engine.advance(3)
local i = service("TerritoryService"):Territory(ben).index
local function at(x, z, y)
	return Layout.toWorld(i, x, z, y)
end
shot("farm_front", at(0, -112, 16), at(0, -70, 3))
shot("farm_yard", at(-40, -100, 12), at(-38, -70, 1))
shot("farm_stock", at(14, -94, 12), at(25, -68, 2))
shot("farm_pens", at(50, -102, 16), at(52, -66, 2))
shot("farm_shed", at(80, -50, 14), at(62, -30, 3))
shot("farm_warehouse", at(80, 10, 22), at(36, 50, 5))
shot("farm_house", at(-50, 20, 14), at(-72, 44, 4))
shot("farm_back", at(-10, 30, 18), at(-40, 70, 2))
writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print("shots", #shots)

--[[
Castle Tycoon, the way a player sees it: the real server and client boot on the mock engine in tycoon mode, two
players on the street (one castle just started, one finished), and the street from above, a finished castle, a
new plot with its pads, the screen in play and a raid at the gate are caught.

  luaurun tools/gameplay/tycoon.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
local Constants = Engine.require(tree.shared.Constants)
Constants.TUTORIAL = false
Constants.applyMode("tycoon")
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled, UIS.KeyboardEnabled = true, false
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Ty = service("TycoonService")
local Tycoon = Engine.require(tree.shared.Data.Tycoon)
local TB = Engine.require(tree.shared.World.TycoonBuilder)

local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local foe = Engine.addPlayer("Ben", 902)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
Engine.advance(0.5)

-- Ava's castle: everything; Ben's: the first few pieces
local s = Ty:State(player)
s.cash = 10 ^ 9
for _, it in Tycoon.ITEMS do
	Ty:Buy(player, it.key)
end
s.cash = 1840
local b = Ty:State(foe)
b.cash = 10 ^ 6
for _, key in { "mine1", "mine2", "wallFL", "wallFR", "mine3" } do
	Ty:Buy(foe, key)
end
b.cash = 60
Engine.advance(6)
local mine = Ty:Plot(player).index
local theirs = Ty:Plot(foe).index

local cam = ws.CurrentCamera
local shots = {}
local function shot(name, eye, look, hideMe)
	cam.CFrame = CF.lookAt(eye, look)
	Engine.advance(0.016)
	if hideMe then
		for _, d in player.Character:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			end
		end
	end
	local snap = Capture.snapshot(
		Engine,
		{ pos = { eye.X, eye.Y, eye.Z }, target = { look.X, look.Y, look.Z }, fov = cam.FieldOfView or 70 }
	)
	snap.title = name
	snap.cinematic = false
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end
local function at(i, x, z, y)
	return TB.toWorld(i, x, z, y)
end

-- the street from above, the LOBBY portal at the far end
shot("tycoon_street", V3.new(0, 95, 150), V3.new(0, 0, -20), true)
-- the finished castle from the street
shot("tycoon_castle", at(mine, -26, -70, 34), at(mine, 0, 6, 8), true)
-- a castle just started: the pads and the COLLECT pad, from behind the gate
shot("tycoon_new_plot", at(theirs, 8, -50, 16), at(theirs, 0, -10, 0), true)
-- in play: standing at their gate, the third-person view with the screen
Engine.moveTo(player, at(mine, 0, -30, 3), at(mine, 0, 0, 3))
Engine.advance(1)
shot("tycoon_play", at(mine, 4, -44, 10), at(mine, 0, -14, 2), false)
-- a raid at the gate, the towers shooting
Ty:StartRaid(player)
Engine.advance(5.2)
shot("tycoon_raid", at(mine, 14, -52, 14), at(mine, 0, -32, 2), false)
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)

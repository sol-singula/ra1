--[[
The TNT and the structures, seen from outside (for the docs): the real server and client boot on the mock engine on
Dust Devil's open floor, every piece is built for both teams (all one team shade, the Reinforced Wall darker), the
tower close up, then a blue TNT goes off against a red wall and tower and the frames catch the explosion and the
debris flying (what ExplosionController and DebrisController draw on every client).

  luaurun tools/gameplay/tnt.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false
Engine.require(tree.shared.Constants).BUILD_SECONDS = 600 -- (time to stage it all)
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled, UIS.KeyboardEnabled = false, true
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Match = service("MatchService")
local Teams = service("TeamService")
local Build = service("BuildService")
local Combat = service("CombatService")
local Formulas = Engine.require(tree.shared.Formulas)
local foe = Engine.addPlayer("Foe", 901)
Engine.advance(0.3)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
Match:NewMatch("dust")
Engine.advance(1)
local red = Teams:Team(player) == "red" and player or foe
local blue = red == player and foe or player
-- (out of the way of every frame)
Engine.moveTo(player, V3.new(Teams:Team(player) == "red" and -70 or 70, 3, -40))
Engine.moveTo(foe, V3.new(Teams:Team(foe) == "red" and -70 or 70, 3, -40))

local shots = {}
local function shot(name, pos, target, fov)
	-- (the world only: no HUD in these)
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") then
			g.Enabled = false
		end
	end
	local snap = Capture.snapshot(
		Engine,
		{ pos = { pos.X, pos.Y, pos.Z }, target = { target.X, target.Y, target.Z }, fov = fov or 60 }
	)
	snap.title = name
	snap.cinematic = false
	snap.hideGui = true
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	snap.focus = { target.X, target.Y, target.Z }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end

-- build with the server's own rules (standing by each spot, refilled)
local function place(who, key, x, z, rot)
	local cx, cz = Formulas.cellOf(x, z)
	Engine.moveTo(who, V3.new(x - (Teams:Team(who) == "red" and 8 or -8), 3, z))
	Build:Refill()
	local ok, s = Build:Place(who, key, cx, cz, rot or 0)
	if not ok then
		print("not built", key, x, z, s)
	end
	return ok and s or nil
end

-- every piece, both teams, facing each other across the line
local keys = { "barricade", "wall", "reinforced", "tower", "bridge", "cover", "banner" }
for i, key in keys do
	local z = -24 + (i - 1) * 9
	place(red, key, -14, z, 1)
	place(blue, key, 10, z, 1)
end
Engine.moveTo(player, V3.new(Teams:Team(player) == "red" and -70 or 70, 3, -40))
Engine.moveTo(foe, V3.new(Teams:Team(foe) == "red" and -70 or 70, 3, -40))
Engine.advance(0.2)
shot("structures_line", V3.new(-2, 34, -52), V3.new(-4, 2, 4), 55)
-- a gallery: every piece in a row for each team, built from the same StructureModel the server uses, on the bare
-- turf (the map's own shapes hidden for this frame)
do
	local StructureModel = Engine.require(tree.shared.StructureModel)
	local Structures = Engine.require(tree.shared.Data.Structures)
	local CELL = Engine.require(tree.shared.Constants).CELL
	local hidden = {}
	for _, d in ws:FindFirstChild("Arena"):GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Position.Y > 0.6 then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	for _, d in ws.Structures:GetDescendants() do
		if d:IsA("BasePart") then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	local gallery = Engine.Instance.new("Folder")
	gallery.Name = "Gallery"
	gallery.Parent = ws
	for row, team in { "red", "blue" } do
		local x = 30
		for _, def in Structures.list do
			local w, d = def.w * CELL, def.d * CELL
			local z = row == 1 and -8 or 10
			local mn, mx = V3.new(x - w, 0, z - d / 2), V3.new(x, def.h, z + d / 2)
			for _, spec in StructureModel.parts(def.key, team, mn, mx) do
				StructureModel.make(spec, team).Parent = gallery
			end
			x -= w + 4
		end
	end
	Engine.advance(0.05)
	shot("structures", V3.new(-4, 20, -46), V3.new(-4, 3, 2), 62)
	shot("tower", V3.new(8, 10, -28), V3.new(-10, 8, -8), 50)
	shot("tower_back", V3.new(-30, 9, -26), V3.new(-10, 7, -8), 50)
	gallery:Destroy()
	for d, t in hidden do
		d.Transparency = t
	end
end

-- the blast: fight on, a blue TNT against red's wall and tower
Match:SkipTo("fight")
Engine.advance(0.5)
Engine.moveTo(player, V3.new(Teams:Team(player) == "red" and -70 or 70, 3, -40))
Engine.moveTo(foe, V3.new(Teams:Team(foe) == "red" and -70 or 70, 3, -40))
local at = V3.new(-7.4, 3, 1)
Combat:_explode({ id = 990, by = blue, team = "blue" }, at)
for _, t in { 0.06, 0.12, 0.24, 0.45, 0.9 } do
	Engine.advance(t - (shots.last or 0))
	shots.last = t
	shot(("tnt_blast_%03d"):format(math.floor(t * 1000)), V3.new(16, 22, 30), V3.new(-9, 5, 0), 60)
end
shots.last = nil

local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)

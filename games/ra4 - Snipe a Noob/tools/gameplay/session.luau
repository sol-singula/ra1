--[[
Plays a session of Snipe a Noob on the mock engine, server and client code together, on a phone-sized screen
(844 x 390), and writes a snapshot of what the player sees at each interesting moment: the lobby, the round in
first person (hip and scoped), the kill feed, being popped, the podium, and every map from above.

  luaurun tools/gameplay/session.luau <outDir>        (from the game folder)

Then render the snapshots with tools/gameplay/render.js.
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3 = Engine.Vector3
local CF = Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "screens"

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
local cam = Engine.workspace.CurrentCamera
cam.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Combat = service("CombatService")
local Round = service("RoundService")
local Constants = Engine.require(tree.shared.Constants)
local Maps = Engine.require(tree.shared.Data.Maps)
local World = Engine.require(tree.server.World.WorldBuilder)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local layout = World.layout

local player = Engine.addPlayer("Ava", 4242)
player.DisplayName = "SnipeKid"
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
Engine.advance(0.2)
Engine.runScript(tree.client.Main)
Engine.advance(0.5)
local pd = Data:Get(player)
pd.coins = 2450
pd.keys = 2
pd.xp = 2600
Economy:PushAll(player)
local hrp = player.Character.HumanoidRootPart

local shots = {}
local function shot(name, camPos, camTarget, fov)
	cam.CFrame = CF.lookAt(camPos, camTarget)
	cam.FieldOfView = fov or 70
	Engine.advance(0.05)
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov or 70,
	})
	snap.title = name
	writeFile(outDir .. "/" .. name .. ".json", Engine.game:GetService("HttpService"):JSONEncode(snap))
	table.insert(shots, name)
	print("shot", name)
end
local function walk(p, pos, lookAt)
	Engine.moveTo(p, pos + V3.new(0, 3, 0), lookAt and (lookAt + V3.new(0, 3, 0)) or nil)
	Engine.advance(0.1)
end
local function follow(name, back, up, ahead)
	local cf = hrp.CFrame
	local look = cf.LookVector
	local pos = hrp.Position - look * (back or 15) + V3.new(0, up or 7, 0)
	shot(name, pos, hrp.Position + look * (ahead or 6) + V3.new(0, 1, 0))
end
-- first person: the camera at the head, looking at a point (Roblox hides your own body in first person)
local function eyes(name, target, fov)
	local head = hrp.Position + V3.new(0, 1.5, 0)
	local hidden = {}
	for _, d in player.Character:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	shot(name, head, target, fov)
	for d, t in hidden do
		d.Transparency = t
	end
end

-- 1. the lobby, waiting for a second player
walk(player, layout.spawn.Position, V3.new(0, 0, 0))
follow("lobby_arrive", 20, 9, 14)
shot("lobby_wide", V3.new(60, 55, 95), V3.new(0, 0, -5), 65)
shot("lobby_boards", V3.new(-30, 14, -20), V3.new(-72, 10, -30), 70)
shot("lobby_kiosks", V3.new(30, 12, -10), V3.new(68, 6, 0), 70)

-- 1b. the range: robots targets
walk(player, layout.range.spawn, layout.range.targets[3])
Engine.advance(0.5)
eyes("range", layout.range.targets[3] + V3.new(0, 3, 0))
-- 1c. the Daily Shop and the crates
walk(player, layout.spawn.Position, V3.new(0, 0, 0))
local Panel = Engine.require(tree.client.Controllers.PanelController)
Panel.open("Shop")
follow("panel_shop", 20, 9, 14)
Panel.open("Crates")
follow("panel_crates", 20, 9, 14)
Panel.open("Rifles")
follow("panel_rifles", 20, 9, 14)
Panel.close()

-- 2. friends join: Ben, Cat and Dan (robots of the test: real server-side players)
local others = {}
for i, name in { "Ben", "Cat", "Dan" } do
	local p = Engine.addPlayer(name, 5000 + i)
	Engine.makeCharacter(p)
	Engine.advance(0.1)
	Engine.fireServer(p, "Ready")
	others[i] = p
end
Engine.advance(1)
follow("lobby_countdown", 20, 9, 14)
shot("lobby_vote", V3.new(0, 22, 30), V3.new(0, 0, -20), 70)
Engine.advance(Constants.LOBBY_SECONDS + 0.5)

-- 3. the round: first person
local c = Round.map.center
Engine.advance(Constants.SHIELD_SECONDS + 0.2)
local ben = others[1]
local spot = Round.map.spawns[1]
walk(player, spot, c)
walk(ben, c + (spot - c) * -0.35, spot)
Engine.advance(0.3)
eyes("round_hip", ben.Character.HumanoidRootPart.Position + V3.new(0, 0.5, 0))
-- scoped in
local Rifle = Engine.require(tree.client.Controllers.RifleController)
Rifle.setScope(true)
Engine.advance(0.4)
eyes("round_scoped", ben.Character.HumanoidRootPart.Position + V3.new(0, 1.2, 0), 28)
-- pop Ben (server decides): the feed, the toast and the hit marker show
local head = hrp.Position + V3.new(0, Constants.HEAD_OFFSET, 0)
Combat:Fire(player, head, (ben.Character.HumanoidRootPart.Position + V3.new(0, 1.6, 0) - head).Unit)
Engine.advance(0.08)
eyes("round_pop", ben.Character.HumanoidRootPart.Position + V3.new(0, 1, 0), 28)
Rifle.setScope(false)
-- a few more pops between the others for the feed and scoreboard
Engine.advance(Constants.RESPAWN_SECONDS + Constants.SHIELD_SECONDS + 0.2)
for i = 2, 3 do
	local shooter, victimP = others[i], others[i % 3 + 1]
	local vpos = victimP.Character.HumanoidRootPart.Position
	walk(shooter, vpos + V3.new(0, 0, 25), vpos)
	local h = shooter.Character.HumanoidRootPart.Position + V3.new(0, Constants.HEAD_OFFSET, 0)
	Combat:Fire(shooter, h, (victimP.Character.HumanoidRootPart.Position - h).Unit)
	Engine.advance(0.1)
end
walk(player, spot, c)
eyes("round_feed", c + V3.new(0, 4, 0))
-- 4. popped: the pop cam
Engine.advance(Constants.SHIELD_SECONDS + 1.5)
local dan = others[3]
local mypos = hrp.Position
walk(dan, mypos + (c - mypos).Unit * 30, mypos)
Engine.advance(0.1)
local dh = dan.Character.HumanoidRootPart.Position + V3.new(0, Constants.HEAD_OFFSET, 0)
Combat:Fire(dan, dh, (hrp.Position + V3.new(0, 1.6, 0) - dh).Unit)
Engine.advance(0.2)
local dr = dan.Character.HumanoidRootPart
shot(
	"popped",
	dr.Position - dr.CFrame.LookVector * 10 + V3.new(0, 4, 0) + dr.CFrame.RightVector * 3,
	dr.Position + V3.new(0, 1.5, 0)
)
Engine.advance(Constants.RESPAWN_SECONDS)
-- 5. a wide look at the arena
shot("arena_wide", c + V3.new(Round.map.half * 1.2, 70, Round.map.half * 1.4), c, 60)
-- 6. the end of the round: the podium
pd.coins += 0
Round.endsAt = Engine.workspace:GetServerTimeNow() + 0.1
Engine.advance(0.6)
shot("podium", V3.new(0, 11, -28), V3.new(0, 6, -52), 70)
Engine.advance(Constants.PODIUM_SECONDS)

-- 6b. robots fill a quiet round: everyone but Ben leaves
for i = 2, 3 do
	Engine.removePlayer(others[i])
end
Engine.advance(Constants.LOBBY_SECONDS + 1)
local Robots = service("RobotService")
Engine.advance(Constants.SHIELD_SECONDS + 2)
local bot = Robots.robots[1]
if bot then
	local bp = bot.root.Position
	walk(player, bp + bot.root.CFrame.LookVector * 22, bp)
	Robots.paused = true
	Engine.advance(0.1)
	eyes("robots", bot.root.Position + V3.new(0, 0.5, 0))
	Robots.paused = false
end

-- no HUD and no held rifle in the map and gallery shots
for _, sg in player.PlayerGui:GetChildren() do
	sg.Enabled = false
end
local function clearCam()
	for _, child in cam:GetChildren() do
		child:Destroy()
	end
end

-- 7. every map from above (medium size)
for _, m in Maps.list do
	local built = MapBuilder.build(m.key, "medium", Engine.workspace, V3.new(0, 0, 3000))
	clearCam()
	shot("map_" .. string.lower(m.key), V3.new(70, 95, 3000 + 110), V3.new(0, 0, 3000), 60)
	shot("map_" .. string.lower(m.key) .. "_ground", V3.new(14, 7, 3000 + 54), V3.new(0, 6, 3000), 70)
	built.model:Destroy()
end

-- 8. the rifles and the skins, on a gallery wall
local RifleModel = Engine.require(tree.shared.RifleModel)
local Rifles = Engine.require(tree.shared.Data.Rifles)
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local G = V3.new(0, 400, 6000)
local gallery = Engine.Instance.new("Model")
gallery.Parent = Engine.workspace
local back = Engine.Instance.new("Part")
back.Size = V3.new(140, 80, 1)
back.CFrame = CF.new(G + V3.new(0, 0, -3))
back.Color = Engine.globals.Color3.fromRGB(235, 238, 245)
back.Anchored = true
back.Parent = gallery
local function hang(rifleKey, skinId, tier, pos)
	local m = RifleModel.build(rifleKey, skinId, tier, CF.new(pos) * CF.Angles(0, -math.pi / 2, 0))
	m.Parent = gallery
end
for i, r in Rifles.list do
	hang(r.key, nil, nil, G + V3.new(-3, 13 - i * 3.6, 0))
end
clearCam()
shot("rifles", G + V3.new(1, 2.2, 16), G + V3.new(1, 2.2, 0), 55)
local skins = {}
for _, sk in Cosmetics.Skins do
	table.insert(skins, sk.id)
end
for _, m in gallery:GetChildren() do
	if m:IsA("Model") then
		m:Destroy()
	end
end
local cols = 4
for i, id in skins do
	local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
	hang("BOLT", id, nil, G + V3.new(-27 + col * 15, 17 - row * 4.2, 0))
end
clearCam()
shot("skins", G + V3.new(0, 4.5, 33), G + V3.new(0, 4.5, 0), 60)
gallery:Destroy()

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print(`{#shots} shots, {#Engine.errors} script errors`)
for _, e in Engine.errors do
	print(e)
end

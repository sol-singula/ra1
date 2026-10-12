--[[
Plays a session of Raid a Planet on the mock engine, server and client code together, on a phone-sized screen
(844 x 390), and writes a snapshot of what the player sees at each interesting moment: the Hub, the Forge panel,
Dust planet with bugs, blasting, the Boss Gate, the boss fight, the Bag.

  luaurun tools/gameplay/session.luau <outDir>        (from the game folder)

Then render the snapshots with tools/gameplay/render.js.
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "screens"

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Planet = service("PlanetService")
local Blaster = service("BlasterService")
local Mob = service("MobService")
local Boss = service("BossService")
local Economy = service("EconomyService")
local World = Engine.require(tree.server.World.WorldBuilder)
local layout = World.layout

local player = Engine.addPlayer("Ava", 4242)
player.DisplayName = "StarKid"
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
Engine.advance(0.2)
Engine.runScript(tree.client.Main)
Engine.advance(0.5)
local pd = Data:Get(player)
local hrp = player.Character.HumanoidRootPart

local shots = {}
local function shot(name, camPos, camTarget, fov)
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
local function follow(name, back, up, ahead)
	local cf = hrp.CFrame
	local look = cf.LookVector
	local pos = hrp.Position - look * (back or 15) + V3.new(0, up or 7, 0)
	shot(name, pos, hrp.Position + look * (ahead or 6) + V3.new(0, 1, 0))
end
local function walk(pos, lookAt)
	Engine.moveTo(player, pos + V3.new(0, 3, 0), lookAt and (lookAt + V3.new(0, 3, 0)) or nil)
	Engine.advance(0.3)
end

-- 1. the Hub on arrival
walk(layout.spawn.Position, V3.new(0, 0, 0))
follow("hub_arrive", 18, 9, 10)
shot("hub_wide", V3.new(70, 40, 70), V3.new(0, 4, 0), 65)
-- 2. the Forge panel
Engine.remote("Profile") -- (the client already listens)
local Net = Engine.require(tree.shared.Net)
_ = Net
local panels = player.PlayerGui:FindFirstChild("Panels")
local hud = player.PlayerGui:FindFirstChild("Hud")
pd.ore.DUST = 37
Economy:PushAll(player)
Engine.advance(0.1)
for _, d in hud:GetDescendants() do
	if d.ClassName == "TextButton" and d.Name == "ForgeButton" then
		d.Activated:Fire()
	end
end
Engine.advance(0.2)
follow("forge_panel", 18, 9, 10)
panels.Dim.Card.Close.Activated:Fire()
Engine.advance(0.1)
-- 3. Dust: bugs come at you
Planet:Travel(player, "DUST")
Engine.advance(2.5)
local dust = layout.planets[1]
walk(dust.center + V3.new(-10, 0, 8), dust.center + V3.new(20, 0, 0))
Engine.advance(1.5)
follow("dust_bugs", 16, 8, 12)
-- 4. blasting a bug
local best, bestD
for _, e in Mob.targets do
	if not e.boss and e.model.Parent then
		local d = (e.pos - hrp.Position).Magnitude
		if not bestD or d < bestD then
			best, bestD = e, d
		end
	end
end
if best then
	walk(best.pos + V3.new(7, 0, 0), best.pos)
	Engine.fireServer(player, "Blast", best.id)
	Engine.advance(0.03)
	follow("dust_blast", 14, 7, 10)
end
-- 5. the boss gate
walk(dust.gateCenter + dust.toHub * 18, dust.gateCenter)
follow("boss_gate", 16, 8, 14)
-- 6. the boss fight (a big blaster so the bar moves)
pd.blasters[1].rarity = "Legend"
pd.blasters[1].lv = 30
Blaster:Push(player)
local boss = Boss.bosses[1]
walk(dust.yardCenter, boss.pos)
Engine.advance(0.6)
walk(boss.pos + V3.new(14, 0, 2), boss.pos)
for _ = 1, 6 do
	Engine.fireServer(player, "Blast", boss.id)
	Engine.advance(0.35)
end
boss.hp = math.floor(boss.maxHp * 0.42)
boss.lastBall = 0
Engine.advance(0.4)
Engine.fireServer(player, "Blast", boss.id)
Engine.advance(0.03)
follow("boss_fight", 18, 9, 16)
-- 7. the Bag
for _, d in hud:GetDescendants() do
	if d.ClassName == "TextButton" and d.Name == "BagButton" then
		d.Activated:Fire()
	end
end
Engine.advance(0.2)
follow("bag_panel", 18, 9, 16)
panels.Dim.Card.Close.Activated:Fire()
-- 8. the raid: the portal opens, we jump in, shields, the sky board
local Raid = service("RaidService")
Planet:Travel(player, "HUB")
walk(V3.new(0, 0.5, 14), V3.new(0, 0, 0))
Raid.Start_(Raid)
Engine.advance(0.3)
follow("raid_portal", 20, 10, 14)
Engine.fireServer(player, "Travel", "RAID")
Engine.advance(0.4)
local star
for _, e in Mob.targets do
	if e.raid then
		star = e
	end
end
walk(star.pos + V3.new(18, 0, 6), star.pos)
Engine.advance(0.3)
Engine.fireServer(player, "Blast", star.id)
Engine.advance(0.05)
follow("raid_fight", 22, 11, 18)
star.hp = math.floor(star.maxHp * 0.6)
Engine.advance(3)
shot("raid_shields", layout.arena.center + V3.new(0, 40, 70), layout.arena.center + V3.new(0, 4, -10), 70)
star.hp = 1
Engine.fireServer(player, "Blast", star.id)
Engine.advance(0.5)
Planet:Travel(player, "HUB")
walk(V3.new(0, 0.5, 30), V3.new(0, 48, 0))
shot("raid_board", V3.new(0, 20, 60), V3.new(0, 46, 0), 70)
-- 8b. the Board Deck, the Egg Machine and SQUAD RAID pad, the Trade Plaza and Booth Street
walk(V3.new(-56, 0.5, 0), V3.new(-70, 0, 0))
shot("board_deck", V3.new(-30, 14, 34), V3.new(-74, 9, 0), 62)
walk(V3.new(0, 0.5, -4), V3.new(0, 0, -16))
shot("hub_pads", V3.new(0, 12, 14), V3.new(0, 3, -16), 60)
walk(V3.new(0, 0.5, 90), V3.new(0, 0, 118))
shot("trade_plaza", V3.new(0, 22, 62), V3.new(0, 4, 118), 65)
walk(V3.new(0, 0.5, -90), V3.new(0, 0, -118))
shot("booth_street", V3.new(0, 22, -62), V3.new(0, 4, -118), 65)
-- 9. the whole ring from above
shot("world", V3.new(0, 420, 520), V3.new(0, 0, 0), 60)

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print(`{#shots} shots, {#Engine.errors} script errors`)
for _, e in Engine.errors do
	print(e)
end

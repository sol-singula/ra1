--[[
Plays a real session of Steal a Dragon on the mock engine, server and client code together, on a phone-sized
screen (844 x 390, landscape), and writes a snapshot of what the player sees at each interesting moment.
A small bot plays the tutorial, buys, steals, gets bonked, opens the shop and so on.

  luaurun tools/gameplay/session.luau <outDir>        (from the game folder)

Then render the snapshots with tools/gameplay/render.js.
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "screens"

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.1)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Base = service("BaseService")
local Dragon = service("DragonService")
local Road = service("RoadService")
local Combat = service("CombatService")
local Reward = service("RewardService")
local Leaderboard = service("LeaderboardService")
local Economy = service("EconomyService")
local Net = Engine.require(tree.shared.Net)
local World = Engine.require(tree.server.World.WorldBuilder).layout

-- Other players (server only): they own bases full of dragons
local bots = {}
for i, spec in { { "BoltNugget", 901 }, { "PixelPaws", 902 }, { "ZoomZoom", 903 } } do
	local p = Engine.addPlayer(spec[1], spec[2])
	Engine.makeCharacter(p)
	Engine.advance(0.1)
	Engine.fireServer(p, "Ready")
	Engine.fireServer(p, "SkipTutorial")
	bots[i] = p
end
Engine.advance(0.5)
local ben, cat, zed = bots[1], bots[2], bots[3]
local function give(p, list)
	for _, item in list do
		local rec = Dragon:Grant(p, item[1], item[2])
		rec.born -= item[3] or 0
	end
end
local pb, pc, pz = Data:Get(ben), Data:Get(cat), Data:Get(zed)
pb.nestsBought, pc.nestsBought, pz.nestsBought = 8, 6, 5
give(ben, {
	{ "BLAZE", nil, 4000 },
	{ "SPARKY" },
	{ "FROSTY", "FIRE" },
	{ "EMBER" },
	{ "CORAL", nil, 700 },
	{ "STORM" },
	{ "PEBBLE" },
})
give(cat, { { "PUFF" }, { "BUBBLES", nil, 700 }, { "LEAFY" }, { "GOLDIE", "GOLD" }, { "EMBER" } })
give(zed, { { "JELLY" }, { "PUFF", nil, 30000 }, { "SHADOW" } })
pb.steals, pc.steals, pz.steals = 23, 9, 41
pb.earned, pc.earned, pz.earned = 184000, 52000, 990000
pb.bestIncome, pc.bestIncome, pz.bestIncome = 410, 120, 1350
for _, p in bots do
	Dragon:_drawLockedNests(p)
end

-- The local player, with the real client scripts
local player = Engine.addPlayer("Ava", 4242)
player.DisplayName = "SkyDragon"
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
Engine.runScript(tree.client.Main)
Engine.advance(0.6)
local profile = Data:Get(player)
local gui = player.PlayerGui
local base = Base:Get(player)
local hrp = player.Character.HumanoidRootPart

-- bots stand in or near their bases
local function at(b, x, y, z)
	return (b.world.cf * CF.new(x, y, z)).Position
end
Engine.moveTo(ben, at(Base:Get(ben), 6, 3, -10), at(Base:Get(ben), 6, 3, -30))
Engine.moveTo(cat, at(Base:Get(cat), -4, 3, 4), at(Base:Get(cat), 0, 3, -30))
Engine.moveTo(zed, V3.new(-60, 3, 12), V3.new(0, 3, 12))

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
-- Roblox's default camera: behind and above the character
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
local function trigger(model, kind)
	local root = model.PrimaryPart or model
	root:FindFirstChild("Prompt_" .. kind).Triggered:Fire(player)
	Engine.advance(0.2)
end
local function anyNest(owner)
	for _, m in Engine.workspace.Dragons:GetChildren() do
		if m:GetAttribute("OwnerUserId") == owner.UserId and m:GetAttribute("Slot") then
			return m
		end
	end
end
local function nestOf(owner, id)
	for _, m in Engine.workspace.Dragons:GetChildren() do
		if
			m:GetAttribute("OwnerUserId") == owner.UserId
			and m:GetAttribute("Slot")
			and m:GetAttribute("DragonId") == id
		then
			return m
		end
	end
end
local gate = base.world.gateCf.Position

-- 01 Spawn in the lobby: leaderboards, the free dragon, tutorial step 1
Engine.advance(6) -- road fills up
Leaderboard:Refresh()
walk(V3.new(-158, 0.6, 2), V3.new(-120, 0.6, 2))
Engine.advance(0.6)
follow("01_lobby_spawn", 16, 8, 10)

-- 02 Grab the free dragon
walk(World.freeFeet.Position + V3.new(-5, -1.2, 0), World.freeFeet.Position)
Engine.advance(0.3)
follow("02_free_dragon_prompt", 12, 6, 4)
trigger(Road.freeModel, "free")
Engine.advance(0.6)
walk(V3.new(-100, 0.5, 16), gate)
follow("03_carry_home_arrow", 14, 7, 8)

-- 04 Placed in a nest
walk(at(base, 0, 0.5, -6), at(base, 0, 0.5, 20))
Engine.advance(4)
walk(at(base, -6, 0.5, -17), at(base, 6, 0.5, 6))
Engine.advance(0.5)
follow("04_first_nest_collect", 14, 9, 8)
walk(base.world.collectPad.Position, at(base, 0, 0.5, 10))
Engine.advance(0.3)
walk(at(base, 0, 0.5, 12), at(base, 0, 0.5, 30))
Engine.advance(0.4)
follow("05_lock_pad", 13, 7, 6)
walk(base.world.lockPad.Position, at(base, 0, 0.5, -30))
Engine.advance(0.5)
shot("06_locked_base", at(base, 0, 14, -48), at(base, 0, 2, 0), 60)

-- Practice steal
local practice = Road.practiceModel
walk(practice.PrimaryPart.Position + V3.new(0, -1.75, 6), practice.PrimaryPart.Position)
Engine.advance(0.4)
follow("07_practice_steal", 12, 6, 3)
trigger(practice, "practice")
walk(at(base, 0, 0.5, 0))
Engine.advance(0.6)

-- Buy on the road
profile.coins += 400
Economy:PushCoins(player)
Engine.advance(4)
local pick
for _, m in Engine.workspace.Dragons.Road:GetChildren() do
	local e = m:GetAttribute("RoadId") and Road:Entry(m:GetAttribute("RoadId"))
	if e and e.x > -80 and e.x < -20 and e.price <= profile.coins and (not pick or e.price > pick.price) then
		pick = e
	end
end
pick = pick or Road:Spawn()
local rp = pick.model.PrimaryPart.Position
walk(V3.new(rp.X + 2, 0.5, rp.Z + 9), V3.new(rp.X, 0.5, rp.Z))
Engine.advance(0.05)
follow("08_dragon_road_buy", 13, 7, 6)
pick = Road:Entry(pick.roadId) or pick
walk(pick.model.PrimaryPart.Position + V3.new(0, -1.75, 5), pick.model.PrimaryPart.Position)
trigger(pick.model, "buy")
walk(at(base, 0, 0.5, 2))
Engine.advance(1.5)
walk(at(base, 8, 0.5, -14), base.world.eggStand.Position)
Engine.advance(0.3)
shot("09_tutorial_done_egg", at(base, -2, 13, -4), base.world.eggStand.Position + V3.new(0, 2, 0), 65)

-- Fill up the base over a "few days" so later shots look lived-in
profile.nestsBought = 8
Dragon:_drawLockedNests(player)
give(player, { { "BLAZE", nil, 3800 }, { "CORAL" }, { "SPARKY", "ICE" }, { "STORM", nil, 900 } })
profile.coins = 2350
profile.steals = 12
profile.earned = 64000
profile.bestIncome = 300
Economy:PushCoins(player)
Engine.advance(2)
shot("10_my_base_aerial", at(base, 0, 34, -38), at(base, 0, 0, 2), 60)

-- Steal from BoltNugget
Engine.advance(1)
local victim = nestOf(ben, "BLAZE") or anyNest(ben)
local vp = victim.PrimaryPart.Position
walk(V3.new(vp.X - 2, 0.5, vp.Z - 7 * (Base:Get(ben).world.cf.LookVector.Z > 0 and 1 or -1)), vp)
Engine.moveTo(player, at(Base:Get(ben), -11, 3, -14), vp)
Engine.advance(0.3)
follow("11_steal_prompt", 11, 6, 3)
trigger(victim, "steal")
Engine.advance(0.3)
walk(at(Base:Get(ben), 0, 0.5, -34), V3.new(at(base, 0, 0, 0).X, 0.5, 0))
Engine.advance(0.2)
follow("12_run_with_stolen", 14, 7, 6)

-- BoltNugget bonks us
Engine.moveTo(ben, hrp.Position + V3.new(2, 0, 2))
Engine.advance(0.1)
Combat:Bonk(ben)
Engine.advance(0.3)
follow("13_bonked_dropped", 13, 8, 2)
Engine.advance(2)

-- Shop and panels (standing by the road)
local hud = gui.Hud
walk(V3.new(-20, 0.5, 14), V3.new(-20, 0.5, -10))
hud.ShopButton.Activated:Fire()
Engine.advance(0.2)
follow("14_shop_boosts")
local tabs = gui.Panels.Dim.Card.Tabs
tabs.passes.Activated:Fire()
Engine.advance(0.2)
follow("15_shop_passes")
gui.Panels.Dim.Card.Close.Activated:Fire()
hud.GiftButton.Activated:Fire()
Engine.advance(0.2)
follow("16_daily_gift")
gui.Panels.Dim.Card.Close.Activated:Fire()
hud.SpeedButton.Activated:Fire()
Engine.advance(0.2)
follow("17_speed_upgrade")
gui.Panels.Dim.Card.Close.Activated:Fire()
Net.fire(player, "Offline", { coins = 18400, seconds = 6 * 3600 + 1200 })
Engine.advance(0.3)
follow("18_welcome_back")
gui.Panels.Dim.Card.Close.Activated:Fire()

-- Legend event and Server Luck on the road
Road:AddLuck(15 * 60, "PixelPaws")
local legend = Road:Spawn("Legend")
legend.x = -40
Net.fireAll("Event", { kind = "legend", at = Engine.workspace:GetServerTimeNow() + 18 })
Engine.advance(0.5)
local lp = legend.model.PrimaryPart.Position
walk(V3.new(lp.X + 6, 0.5, lp.Z + 10), lp)
Engine.advance(0.05)
follow("19_legend_and_luck", 14, 7, 4)

-- Leaderboards close up and the whole map
Leaderboard:Refresh()
walk(V3.new(-146, 0.6, 8), V3.new(-132, 0.6, 30))
Engine.advance(0.3)
shot("20_lobby_leaderboards", V3.new(-158, 9, 0), V3.new(-134, 11, 26), 70)
shot("21_map_overview", V3.new(-150, 120, -150), V3.new(0, 0, 0), 55)

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print(`{#shots} shots, {#Engine.errors} script errors`)
for _, e in Engine.errors do
	print(e)
end

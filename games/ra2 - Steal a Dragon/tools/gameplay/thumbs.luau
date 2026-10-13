--[[
Store-page thumbnails: the real game world (server + client code on the mock engine) staged into a few
cinematic scenes, with no UI. Snapshots are marked cinematic so render.js also writes a depth pass, and
tools/gameplay/thumbs_post.py adds the "shader" look (bloom, colour grade, depth blur, sun glow) and the title.

  luaurun tools/gameplay/thumbs.luau <outDir>        (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "screens"

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
local UIS = Engine.game:GetService("UserInputService")
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


-- give each player their own avatar colours (shirt, pants, skin) so a crowd doesn't look cloned
local function paint(p, shirt, pants, skin)
	for _, part in p.Character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local n = part.Name
			if n == "Torso" or n == "UpperTorso" or n == "LowerTorso" then
				part.Color = shirt
			elseif string.find(n, "Leg") then
				part.Color = pants
			elseif string.find(n, "Arm") or n == "Head" then
				part.Color = skin
			end
		end
	end
end
local rgb = Engine.globals.Color3.fromRGB
paint(player, rgb(235, 70, 60), rgb(40, 50, 80), rgb(255, 205, 150))
paint(ben, rgb(60, 140, 255), rgb(30, 30, 40), rgb(240, 190, 140))
paint(cat, rgb(170, 90, 240), rgb(255, 255, 255), rgb(140, 95, 60))
paint(zed, rgb(60, 205, 90), rgb(60, 45, 30), rgb(255, 220, 180))

-- fill the local player's base too
profile.nestsBought = 8
Dragon:_drawLockedNests(player)
give(player, {
	{ "BLAZE", nil, 3800 },
	{ "CORAL" },
	{ "SPARKY", "ICE" },
	{ "STORM", nil, 900 },
	{ "GOLDIE", "GOLD" },
	{ "SHADOW" },
})
Engine.advance(6) -- the road fills with dragons
local legend = Road:Spawn("Legend")
legend.x = -30
local secret = Road:Spawn("Secret")
secret.x = -55
Engine.advance(0.3)

local shots = {}
local function shot(name, camPos, camTarget, fov, focus)
	Engine.advance(0.05)
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov or 50,
	})
	snap.title = name
	snap.cinematic = true
	snap.viewport = { w = 1920, h = 1080, dpr = 2 }
	focus = focus or camTarget
	snap.focus = { focus.X, focus.Y, focus.Z }
	writeFile(outDir .. "/" .. name .. ".json", Engine.game:GetService("HttpService"):JSONEncode(snap))
	table.insert(shots, name)
	print("shot", name)
end
local function nestOf(owner, id)
	for _, m in Engine.workspace.Dragons:GetChildren() do
		if m:GetAttribute("OwnerUserId") == owner.UserId and m:GetAttribute("Slot") and m:GetAttribute("DragonId") == id then
			return m
		end
	end
end

-- 1 HERO: we sneak out of BoltNugget's castle with his best dragon on our head, he chases us with the bonk bat
local bb = Base:Get(ben)
local victim = nestOf(ben, "BLAZE")
Engine.moveTo(player, victim.PrimaryPart.Position + V3.new(0, 1, 0), victim.PrimaryPart.Position)
victim.PrimaryPart:FindFirstChild("Prompt_steal").Triggered:Fire(player)
Engine.advance(0.3)
local run = at(bb, -1, 3, -31)
Engine.moveTo(player, run, at(bb, -8, 3, -48))
Engine.moveTo(ben, at(bb, 5, 3, -24), run)
Engine.advance(0.3)
shot("01_hero_steal", at(bb, -12, 3.6, -45), at(bb, 1, 4.2, -28), 40, run)

-- 2 the dragon road: a Legend walks by, players run over to buy it (they face the camera)
local lp = legend.model.PrimaryPart.Position
Engine.moveTo(cat, V3.new(lp.X - 3, 3, lp.Z - 7), lp)
Engine.moveTo(zed, V3.new(lp.X + 6, 3, lp.Z - 8), lp)
Engine.moveTo(player, V3.new(lp.X + 10, 3, lp.Z - 5), lp)
Engine.advance(0.2)
shot("02_dragon_road", V3.new(lp.X + 1, 4.2, lp.Z + 13), V3.new(lp.X + 3, 3.4, lp.Z - 3), 50, lp)

-- 3 a full base, three-quarter view
local base = Base:Get(player)
Engine.moveTo(player, at(base, 3, 3, -8), at(base, 0, 3, 10))
Engine.advance(0.2)
shot("03_full_base", at(base, -26, 22, -34), at(base, 0, 2, 2), 45)

-- 5 the whole map from the sky
shot("04_map", V3.new(-170, 95, -120), V3.new(-10, 0, 10), 50)

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print(`{#shots} shots, {#Engine.errors} script errors`)
for _, e in Engine.errors do
	print(e)
end

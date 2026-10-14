--[[
Client smoke test: builds the real map, boots the real client scripts on the mock engine as a phone-sized screen,
and feeds them every server → client event: the profile, the match phases, you, your bag, the shrines, the guide
and the first choice, the horde, moves, effects, pings, the monster picker, the results, friends and the small
cards. It presses the HUD, action and build buttons, opens every panel (shop with its 3D preview, tasks, friends,
more, the Job Board), and checks the gate swinging open, the lighting following the phase, the music, lite mode
on phones and the analytics batches. Fails on any script error or warning.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local Color3 = Engine.globals.Color3
local Instance = Engine.Instance

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
local Net = Engine.require(tree.shared.Net)
local Constants = Engine.require(tree.shared.Constants)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local PieceModels = Engine.require(tree.shared.World.PieceModels)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
Net.init() -- the server normally creates the remotes
-- the map, built the way the server builds it
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
MapBuilder.build()
local Horde = Engine.require(tree.server.Services.HordeService) -- (only its snapshot packer)
local ws = Engine.workspace
local CollectionService = Engine.game:GetService("CollectionService")
local flowers = CollectionService:GetTagged("Detail")
check("flowers are tagged as detail", #flowers > 20, #flowers)

-- a rock pile and a built gate at Shrine 1, like ResourceService and BuildService make them
local starter
for _, n in MapLayout.nodes do
	if n.starter then
		starter = n
		break
	end
end
local node = MapBuilder.nodeModel(starter, ws.Nodes)
node:SetAttribute("NodeId", starter.id)
node:SetAttribute("Amount", 20)
node:SetAttribute("Max", 20)
local gateSpec = MapLayout.starter[1]
local gateDef = Pieces.byKey.gate
local gw, gd = Pieces.cells(gateDef, gateSpec.rot)
local gcx, gcz = (gateSpec.i + gw / 2) * MapLayout.CELL, (gateSpec.j + gd / 2) * MapLayout.CELL
local gate = PieceModels.build(
	"gate",
	PieceModels.frame(gateDef, gateSpec.i, gateSpec.j, gateSpec.rot, MapLayout.groundY(gcx, gcz)),
	{ parent = ws.Castle }
)
for k, v in
	{
		PieceId = 1,
		Key = "gate",
		I = gateSpec.i,
		J = gateSpec.j,
		Rot = gateSpec.rot,
		Shrine = 1,
		Built = true,
		Hp = 300,
		MaxHp = 300,
	}
do
	gate:SetAttribute(k, v)
end
-- a blueprint next to it (MAIN says BUILD there)
local wallSpec = MapLayout.starter[2]
local wallDef = Pieces.byKey.stoneWall
local ww, wd = Pieces.cells(wallDef, wallSpec.rot)
local wcx, wcz = (wallSpec.i + ww / 2) * MapLayout.CELL, (wallSpec.j + wd / 2) * MapLayout.CELL
local wall = PieceModels.build(
	"stoneWall",
	PieceModels.frame(wallDef, wallSpec.i, wallSpec.j, wallSpec.rot, MapLayout.groundY(wcx, wcz)),
	{ parent = ws.Castle, ghost = Color3.fromRGB(120, 200, 255) }
)
for k, v in
	{
		PieceId = 2,
		Key = "stoneWall",
		I = wallSpec.i,
		J = wallSpec.j,
		Rot = wallSpec.rot,
		Shrine = 1,
		Hp = 0,
		MaxHp = wallDef.hp,
	}
do
	wall:SetAttribute(k, v)
end

ws:SetAttribute("Phase", "intermission")
ws:SetAttribute("PhaseEnds", 0)
ws:SetAttribute("FightEnds", 0)
ws:SetAttribute("Fallen", 0)

Engine.side = "client"
-- a phone in landscape: 844 x 390
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false

local player = Engine.addPlayer("Ava", 7)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
local character = Engine.makeCharacter(player)
-- the joints AnimController bends (Roblox's R15 rig has them)
local shoulder = Instance.new("Motor6D")
shoulder.Name = "RightShoulder"
shoulder.C0 = CFrame.new(1, 0.5, 0)
shoulder.Parent = character.RightUpperArm
local waist = Instance.new("Motor6D")
waist.Name = "Waist"
waist.C0 = CFrame.new(0, 0.2, 0)
waist.Parent = character.UpperTorso
character.Humanoid.MaxHealth = 100
character.Humanoid.Health = 100
local spawnPos = MapLayout.dwarfSpawn(1, 1)
Engine.moveTo(player, spawnPos)
local function camAt(pos)
	ws.CurrentCamera.CFrame = CFrame.lookAt(pos + Vector3.new(0, 14, 26), pos)
end
camAt(spawnPos)
Engine.runScript(tree.client.Main)
Engine.advance(0.3)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)

local gui = player.PlayerGui
local function serverSends(name, ...)
	Engine.remote(name):FireClient(player, ...)
	Engine.advance(0.05)
end
local function findButton(root, text)
	for _, d in root:GetDescendants() do
		if
			d.ClassName == "TextButton"
			and d.Text
			and string.find(string.upper(d.Text), string.upper(text), 1, true)
		then
			return d
		end
	end
	return nil
end
local function click(root, text)
	local b = findButton(root, text)
	check("button '" .. text .. "' exists", b ~= nil)
	if b then
		b.Activated:Fire()
		Engine.advance(0.05)
	end
	return b
end
local function press(b)
	b.Activated:Fire()
	Engine.advance(0.05)
end
local function sent(name)
	local e = Engine.lastClientEvent(name)
	return e and e.player == "server" and e or nil
end
local function textIn(root, needle)
	for _, d in root:GetDescendants() do
		if
			(d.ClassName == "TextLabel" or d.ClassName == "TextButton")
			and d.Text
			and string.find(string.upper(d.Text), string.upper(needle), 1, true)
		then
			return d
		end
	end
	return nil
end
local function count(name)
	return Engine.countClientEvents(name)
end
local function sameColor(a, b)
	return a and b and math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

local hud = gui:FindFirstChild("Hud")
check("HUD built", hud ~= nil)
check("phone scale applied", math.abs(hud.Scale.Scale - 390 / 560) < 0.01, hud.Scale.Scale)
check("landscape on phones", gui.ScreenOrientation ~= nil)
check(
	"menu buttons",
	hud:FindFirstChild("shop")
		and hud:FindFirstChild("tasks")
		and hud:FindFirstChild("friends")
		and hud:FindFirstChild("settings")
)
local actions = gui:FindFirstChild("Actions")
check(
	"action buttons",
	actions and actions:FindFirstChild("Main") and actions:FindFirstChild("Special") and actions:FindFirstChild("Mode")
)
local Perf = Engine.require(tree.client.Controllers.PerformanceController)
check("lite mode on a phone", Perf.lite == true)
local dropped = 0
for _, f in flowers do
	if f.Parent == nil then
		dropped += 1
	end
end
check("lite mode leaves the flowers out", dropped == #flowers, `{dropped}/{#flowers}`)
check("hangout: no match buttons", actions.Main.Visible == false and actions.Mode.Visible == false)
check("hangout card", string.find(hud.Me.Who.Text, "hangout", 1, true) ~= nil, hud.Me.Who.Text)

-- The profile ----------------------------------------------------------------------------------------------------
local profile = {
	coins = 260,
	xp = 300,
	level = 3,
	levelInto = 60,
	levelNeed = 140,
	jobLevels = { builder = 2, miner = 1, grunt = 3 },
	dwarfJob = "builder",
	looks = {
		owned = {
			iron = true,
			brown = true,
			classic = true,
			steel = true,
			dust = true,
			wave = true,
			hammerUp = true,
			dragon = true,
			cheer = true,
		},
		equipped = {
			armor = "iron",
			beard = "brown",
			skin = "classic",
			weapon = "steel",
			buildFx = "dust",
			emote = "wave",
			pose = "hammerUp",
			flag = "dragon",
		},
	},
	titles = { owned = { rookie = true, wallMaster = true }, equipped = "rookie" },
	stats = {
		matches = 3,
		dwarfWins = 1,
		built = 12,
		walls = 100,
		beaten = 9,
		mined = 300,
		healed = 40,
		bestHold = 245,
		traps = 7,
	},
	tasks = {
		{ key = "build5", line = "Help build 5 pieces", goal = 5, progress = 2, done = false, coins = 40 },
		{ key = "mine50", line = "Mine 50 materials", goal = 50, progress = 50, done = true, coins = 30 },
	},
	weekly = { key = "win3", line = "Hold the castle 3 times", goal = 3, progress = 1, done = false, coins = 200 },
	gift = { ready = true, streak = 2, next = 60 },
	settings = { fx = true, shake = true, music = true },
	tutorial = { done = false, step = 1 },
}
serverSends("Profile", profile)
check("coins", hud.Coins.Value.Text == "🪙 260", hud.Coins.Value.Text)
check("level", hud.Coins.Level.Text == "Lv 3")
check("TASKS dot: gift ready", hud.tasks.Dot.Visible == true)
local giftCard = hud:FindFirstChild("Gift")
check("daily gift card", giftCard ~= nil and textIn(giftCard, "60 coins") ~= nil)
click(giftCard, "CLAIM")
check("gift claimed", sent("ClaimGift") ~= nil and hud:FindFirstChild("Gift") == nil)

-- Build time ---------------------------------------------------------------------------------------------------------
ws:SetAttribute("Phase", "build")
ws:SetAttribute("PhaseEnds", Engine.now() + 300)
serverSends("Match", { phase = "build", ends = Engine.now() + 300, number = 1, active = 1, fallen = 0, scared = false })
serverSends("Me", {
	team = "dwarf",
	job = "builder",
	alive = true,
	level = 1,
	gear = { armor = 1, weapon = 0 },
	food = 2,
	potions = 0,
	stats = { built = 3 },
})
-- (TeamService marks the character and the player too)
character:SetAttribute("Team", "dwarf")
player:SetAttribute("Team", "dwarf")
serverSends("Bag", { stone = 5, wood = 2, gold = 0, cap = 24 })
serverSends("Shrines", {
	{ health = 100, state = "active", dwarves = 3, monsters = 0, rate = 0, wards = 0, stage = "camp" },
	{ health = 100, state = "safe", dwarves = 0, monsters = 0, rate = 0, wards = 0 },
	{ health = 100, state = "safe", dwarves = 0, monsters = 0, rate = 0, wards = 0 },
})
Engine.advance(0.3)
check("alert: help build", hud:FindFirstChild("Alert") and string.find(hud.Alert.Text, "HELP BUILD", 1, true) ~= nil)
check(
	"clock shows build time",
	string.find(hud.Clock.Phase.Text, "5:00", 1, true) ~= nil
		or string.find(hud.Clock.Phase.Text, "4:5", 1, true) ~= nil,
	hud.Clock.Phase.Text
)
check("card: builder", string.find(hud.Me.Who.Text, "BUILDER", 1, true) ~= nil, hud.Me.Who.Text)
check("card: gear", string.find(hud.Me.Line.Text, "1/3", 1, true) ~= nil, hud.Me.Line.Text)
check("bag shows stone", hud.Bag.Visible and hud.Bag.stone.Text == "🪨 5", hud.Bag.stone.Text)
check("food button", hud.Food.Visible and hud.Food.Text == "🍲 2")
check("potion hidden with none", hud.Potion.Visible == false)
check("shrine 1 active", sameColor(hud.Clock.Shrine1.Label.TextColor3, Color3.fromRGB(255, 200, 40)))
check("match buttons now", actions.Main.Visible and actions.Mode.Visible and actions.Special.Visible)
Engine.advance(3)
check("alert gone", hud:FindFirstChild("Alert") == nil)
serverSends("Match", { phase = "build", ends = Engine.now() + 290, number = 1, active = 1, fallen = 0, scared = true })
Engine.advance(0.1)
check("same phase: no second banner", hud:FindFirstChild("Alert") == nil)
press(hud.Food)
check("eat sent", sent("Use") and sent("Use").args[1] == "food")

-- The guide ------------------------------------------------------------------------------------------------------------
local guide = gui:FindFirstChild("Guide")
serverSends(
	"Tutorial",
	{ step = 1, total = 7, key = "mine", text = "Tap the glowing rocks to dig stone!", target = starter.pos }
)
Engine.advance(0.2)
check(
	"guide card",
	guide.Card.Visible and string.find(guide.Card.Step.Text, "1 OF 7", 1, true) ~= nil,
	guide.Card.Step.Text
)
check("guide text", string.find(guide.Card.Text.Text, "glowing rocks", 1, true) ~= nil)
local target = ws:FindFirstChild("GuideTarget")
check("a sparkle trail to the rocks", target and target.Trail.Enabled == true and target.Trail.Attachment0 ~= nil)
check(
	"distance on the arrow",
	target and string.find(target.Arrow.Far.Text, "m", 1, true) ~= nil,
	target and target.Arrow.Far.Text
)
check("the rocks glow", guide:FindFirstChild("GuideGlow") and guide.GuideGlow.Adornee == node)
-- walk to the rocks: MAIN says MINE
Engine.moveTo(player, starter.pos + Vector3.new(0, 3, 4.5))
camAt(starter.pos)
Engine.advance(0.3)
check("close: the trail goes", target.Trail.Enabled == false)
check("MAIN: mine", string.find(actions.Main.Label.Text, "MINE", 1, true) ~= nil, actions.Main.Label.Text)
local Input = Engine.require(tree.client.Controllers.InputController)
check("context: the node", Input.context() and Input.context().kind == "node" and Input.context().id == starter.id)
check("target outlined", actions:FindFirstChild("Target") and actions.Target.Adornee == node)
actions.Main.MouseButton1Down:Fire()
Engine.advance(0.05)
actions.Main.MouseButton1Up:Fire()
local act = sent("Act")
check(
	"MAIN sends a mine",
	act and act.args[1] == "main" and type(act.args[3]) == "table" and act.args[3].node == starter.id
)
serverSends("Tutorial", {
	step = 2,
	total = 7,
	key = "build",
	text = "Bring it to a glowing blueprint and hammer it!",
	target = Vector3.new(wcx, 10, wcz),
})
check("step 2", string.find(guide.Card.Step.Text, "2 OF 7", 1, true) ~= nil)
-- next to the blueprint: MAIN says BUILD
Engine.moveTo(player, Vector3.new(wcx + 4, 13, wcz))
camAt(Vector3.new(wcx, 10, wcz))
Engine.advance(0.3)
check("MAIN: build", string.find(actions.Main.Label.Text, "BUILD", 1, true) ~= nil, actions.Main.Label.Text)
check("blueprint glows", guide:FindFirstChild("GuideGlow") and guide.GuideGlow.Adornee == wall)
Engine.advance(0.6)
actions.Main.MouseButton1Down:Fire()
Engine.advance(0.05)
actions.Main.MouseButton1Up:Fire()
act = sent("Act")
check("MAIN sends a build", act and act.args[3] and act.args[3].piece == 2)
-- the first choice
serverSends("Choice", {
	options = {
		{ key = "gate", icon = "🚪", title = "Stronger gate", line = "Iron bands on the gate." },
		{ key = "tower", icon = "🗼", title = "Build a tower", line = "Archers shoot from the top." },
		{ key = "wall", icon = "🧱", title = "Thicker wall", line = "A wall that takes more hits." },
	},
})
check("choice card", hud:FindFirstChild("Choice") ~= nil)
press(hud.Choice.Card.tower)
check("choice sent", sent("Choice") and sent("Choice").args[1] == 2 and hud:FindFirstChild("Choice") == nil)
click(guide.Card, "SKIP")
check("skip sent, guide gone", sent("SkipTutorial") ~= nil and guide.Card.Visible == false)
check("trail gone", ws:FindFirstChild("GuideTarget") == nil)

-- Build mode -------------------------------------------------------------------------------------------------------
local Build = Engine.require(tree.client.Controllers.BuildController)
local buildGui = gui.Build
press(actions.Mode)
Engine.advance(0.1)
check("build mode on", Build.state().active and buildGui.PieceBar.Visible and buildGui.BuildControls.Visible)
check("stone wall picked", Build.state().selected == "stoneWall")
check("a ghost", ws:FindFirstChild("PlacementGhost") ~= nil)
check("viewed: build", sent("Viewed") and sent("Viewed").args[1] == "build")
-- face open ground inside the hill, away from everything
Engine.moveTo(player, Vector3.new(-200, 13, 60), Vector3.new(-200, 13, 90))
Engine.advance(0.2)
local st = Build.state()
check("a good spot", st.spot and st.spot.ok == true, st.spot and st.spot.reason)
press(buildGui.BuildControls.Place)
local place = sent("Place")
check(
	"place sent",
	place and place.args[1] == "stoneWall" and place.args[2] == st.spot.i and place.args[3] == st.spot.j
)
press(buildGui.BuildControls.Rotate)
check("rotated", Build.state().rot == 1)
press(buildGui.PieceBar.tower)
check("tower picked", Build.state().selected == "tower")
-- on top of the gate: red, and no place
Engine.moveTo(player, Vector3.new(gcx + 12, 13, gcz), Vector3.new(gcx, 13, gcz))
Engine.advance(0.2)
st = Build.state()
check(
	"blocked spot is red",
	st.spot and st.spot.ok == false and string.find(buildGui.BuildControls.Place.Text, "❌", 1, true) ~= nil,
	buildGui.BuildControls.Place.Text
)
local placesBefore = count("Place")
press(buildGui.BuildControls.Place)
check("no place on a blocked spot", count("Place") == placesBefore)
-- the client's check matches the server's rules
check("check: off the build zone", Build.check("stoneWall", 0, 0, 0) == false)
check("check: the shrine kept clear", Build.check("stoneWall", -51, -1, 0) == false)
press(buildGui.BuildControls.Close)
check("build mode off", Build.state().active == false and ws:FindFirstChild("PlacementGhost") == nil)

-- Gates swing open for dwarves ----------------------------------------------------------------------------------------
local doorL = gate:FindFirstChild("DoorL")
local closedLook = doorL.CFrame.LookVector
Engine.moveTo(player, Vector3.new(gcx + 6, 13, gcz))
camAt(Vector3.new(gcx, 10, gcz))
Engine.advance(0.8)
check(
	"gate opens for a dwarf",
	(doorL.CFrame.LookVector - closedLook).Magnitude > 0.5,
	(doorL.CFrame.LookVector - closedLook).Magnitude
)
Engine.moveTo(player, Vector3.new(gcx + 60, 13, gcz))
Engine.advance(1.5)
check(
	"and closes behind",
	(doorL.CFrame.LookVector - closedLook).Magnitude < 0.1,
	(doorL.CFrame.LookVector - closedLook).Magnitude
)

-- Moves look like moves ----------------------------------------------------------------------------------------------
Engine.moveTo(player, spawnPos)
camAt(spawnPos)
Engine.advance(0.1)
local baseLook = shoulder.C0.LookVector
serverSends("Act", { by = 7, move = "hammer", windup = 0.15 })
Engine.advance(0.1)
check(
	"hammer wind-up lifts the arm",
	(shoulder.C0.LookVector - baseLook).Magnitude > 0.3,
	(shoulder.C0.LookVector - baseLook).Magnitude
)
Engine.advance(1)
check("and comes back", (shoulder.C0.LookVector - baseLook).Magnitude < 0.05)
character:SetAttribute("Heavy", true)
Engine.advance(0.1)
check("a full bag leans you over", (waist.C0.LookVector - Vector3.new(0, 0, -1)).Magnitude > 0.1)
character:SetAttribute("Heavy", nil)
serverSends("Fx", "emote", { by = 7, key = "wave" })
Engine.advance(0.5)
check("emote: wave", (shoulder.C0.LookVector - baseLook).Magnitude > 0.5)
Engine.advance(3)

-- Effects ------------------------------------------------------------------------------------------------------------
local Fx = Engine.require(tree.client.Controllers.FxController)
local at = spawnPos + Vector3.new(0, 2, -6)
local fxData = {
	mine = { position = at, kind = "stone", node = 1 },
	deplete = { position = at, kind = "wood", node = 1 },
	regrow = { position = at, kind = "wood", node = 1 },
	placed = { position = at, id = 3, key = "stoneWall" },
	hammer = { position = at, id = 3, progress = 0.5, style = "confetti" },
	built = { position = at, id = 3, key = "stoneWall", size = Vector3.new(8, 10, 4) },
	fix = { position = at, id = 3 },
	pieceHit = { position = at, id = 3, amount = 12 },
	crumble = { position = at, id = 3, size = Vector3.new(8, 10, 4) },
	projectile = { from = at, to = at + Vector3.new(40, 0, 0), style = "arrow", speed = 120 },
	goo = { position = at, radius = 6, seconds = 1 },
	bombPlant = { position = at, fuse = 0.5 },
	explode = { position = at, radius = 10 },
	heal = { position = at, radius = 3 },
	ward = { position = at, radius = 18 },
	shield = { position = at, by = 7, seconds = 1, radius = 12 },
	roar = { position = at, by = 7, radius = 20 },
	charge = { by = 7, dir = Vector3.new(1, 0, 0), seconds = 0.4 },
	dark = { position = at, by = 7, radius = 20 },
	curse = { position = at, id = 3, seconds = 1 },
	oil = { position = at, radius = 10 },
	trap = { position = at, kind = "pit" },
	shielded = { position = at, id = 3 },
	upgradeStart = { position = at, id = 3, name = "Grand Tower" },
	craft = { position = at, item = "armor" },
	eat = { position = at, item = "food" },
	turn = { position = at, userId = 9 },
	plague = { position = at, userId = 7 },
	shrineFall = { position = at, index = 1 },
}
local kinds = 0
for kind in Fx.handlers do
	kinds += 1
	check("fx data for " .. kind, fxData[kind] ~= nil)
	if fxData[kind] then
		serverSends("Fx", kind, fxData[kind])
	end
end
check("every effect kind tried", kinds >= 28, kinds)
local nParticles = Fx.counts()
check("particles flying", nParticles > 10, nParticles)
check("lite mode: half the particles at most", nParticles <= 130, nParticles)
check("the plague flashes your screen", hud.Flash.Visible == true)
Engine.advance(3)
check("particles cleaned up", Fx.counts() < nParticles)

-- The horde -----------------------------------------------------------------------------------------------------------
local HordeC = Engine.require(tree.client.Controllers.HordeController)
local function npc(id, kind, pos, extra)
	local n = {
		id = id,
		kind = kind,
		pos = pos,
		yaw = 0,
		hp = 50,
		maxHp = 50,
		moving = true,
		actCount = 0,
		hitAt = -10,
		carry = false,
		stunUntil = 0,
		elite = false,
		state = "march",
	}
	for k, v in extra or {} do
		n[k] = v
	end
	return n
end
local base = spawnPos + Vector3.new(-30, 0, 0)
local t0 = Engine.now()
serverSends(
	"Horde",
	Horde.pack({
		npc(1, "grunt", base),
		npc(2, "brute", base + Vector3.new(0, 0, 8)),
		npc(3, "dwarf", base + Vector3.new(6, 0, 0), { carry = true }),
	}, t0)
)
Engine.advance(0.075)
serverSends(
	"Horde",
	Horde.pack({
		npc(1, "grunt", base + Vector3.new(2, 0, 0), { actCount = 1 }),
		npc(2, "brute", base + Vector3.new(2, 0, 8), { hp = 25 }),
		npc(3, "dwarf", base + Vector3.new(8, 0, 0), { carry = true }),
	}, t0 + 0.125)
)
Engine.advance(0.25)
check("three NPCs drawn", HordeC.count() == 3 and #ws.Npcs:GetChildren() == 3, HordeC.count())
local grunt = HordeC.npcs[1]
local gx = grunt and grunt.rig.bones.LowerTorso.Position.X
check("glides between snapshots", gx and gx > base.X + 0.3 and gx < base.X + 2.1, gx and gx - base.X)
check("the brute's health bar shows", HordeC.npcs[2].bar.Enabled == true)
check("the dwarf carries a rock", HordeC.npcs[3].rock and HordeC.npcs[3].rock.Transparency == 0)
check("an attack swings", os.clock and grunt.swingAt > 0)
local near = HordeC.near(base, 5, function(k)
	return k ~= "dwarf"
end)
check("near(): the grunt", #near == 1 and near[1].id == 1, #near)
serverSends("Npc", { kind = "die", id = 1 })
Engine.advance(1.6)
check("a beaten monster tumbles and goes", HordeC.npcs[1] == nil and HordeC.count() == 2)
-- far away NPCs aren't drawn (lite mode: 200 studs)
serverSends(
	"Horde",
	Horde.pack({ npc(2, "brute", base + Vector3.new(400, 0, 0)), npc(3, "dwarf", base) }, Engine.now())
)
Engine.advance(0.5)
check("far ones hidden", HordeC.npcs[2] and HordeC.npcs[2].model.Parent == nil)
serverSends("Npc", { kind = "clear" })
check("cleared", HordeC.count() == 0)

-- Pings, popups, sounds ------------------------------------------------------------------------------------------------
serverSends("Ping", { key = "help", text = "Help here!", icon = "🆘", position = spawnPos, from = "Ben" })
check("ping beacon", textIn(ws.Fx, "Help here!") ~= nil and textIn(ws.Fx, "Ben") ~= nil)
serverSends("Popup", spawnPos + Vector3.new(0, 4, 0), "+2 🪨", "stone")
check("popup in the world", ws:FindFirstChild("Popup") ~= nil)
serverSends("Sfx", "hammer", spawnPos)
check("3D sound", ws:FindFirstChild("Sfx_hammer") ~= nil)
serverSends("Sfx", "coin")
check("2D sound", Engine.game:GetService("SoundService"):FindFirstChild("Sfx_coin") ~= nil)
Engine.advance(1)
local Audio = Engine.require(tree.client.Controllers.AudioController)
check("music: build tracks", Audio.music.key == "build" and Audio.music.sound and Audio.music.sound.IsPlaying)
serverSends("Callout", "Shrine 1 is at 50%!", "falling")
check("callout", hud:FindFirstChild("Callout") and textIn(hud.Callout, "50%") ~= nil)
serverSends("Toast", "Not enough stone", "bad")
check("toast", textIn(hud, "Not enough stone") ~= nil)
serverSends("Hurt", { amount = 20, kind = "claw" })
check("hurt vignette", hud.Hurt.Visible == true)

-- Panels --------------------------------------------------------------------------------------------------------------
local panels = gui:FindFirstChild("Panels")
check("panels screen", panels ~= nil)
local panel = panels.Panel
local Panels = Engine.require(tree.client.Controllers.PanelController)
press(hud.shop)
Engine.advance(0.1)
check("SHOP opens", panel.Visible and string.find(panel.Title.Text, "LOOKS SHOP", 1, true) ~= nil)
check("viewed: shop", sent("Viewed") and sent("Viewed").args[1] == "shop")
check("nine tabs", #panel.Tabs:GetChildren() >= 9)
check("armor items", panel.Body:FindFirstChild("Item_copper", true) ~= nil)
local copper = panel.Body:FindFirstChild("Item_copper", true)
check("price on copper", copper and copper.Action.Text == "🪙 150")
local iron = panel.Body:FindFirstChild("Item_iron", true)
check("iron worn", iron and iron.Action.Text == "WORN ✔")
check("a 3D preview", Panels.previewNpc() ~= nil and panel.Side.Visible)
press(copper.Action)
check("buy sent", sent("Buy") and sent("Buy").args[1] == "copper")
-- the server says it's bought and worn
local p2 = table.clone(profile)
p2.coins = 110
p2.looks = { owned = table.clone(profile.looks.owned), equipped = table.clone(profile.looks.equipped) }
p2.looks.owned.copper = true
p2.looks.equipped.armor = "copper"
p2.gift = { ready = false, streak = 3, next = 70 }
serverSends("Profile", p2)
copper = panel.Body:FindFirstChild("Item_copper", true)
check("copper worn now", copper and copper.Action.Text == "WORN ✔")
check("coins went down", textIn(panel.Body, "110 coins") ~= nil)
press(panel.Body:FindFirstChild("Item_iron", true).Action)
check("wear iron again", sent("Equip") and sent("Equip").args[1] == "armor" and sent("Equip").args[2] == "iron")
press(panel.Tabs.Tab_skin)
check("skins tab", panel.Body:FindFirstChild("Item_frost", true) ~= nil)
press(panel.Body:FindFirstChild("Item_lava", true))
check("preview: a monster in lava", Panels.previewNpc() and Panels.previewNpc().kind == "grunt")
press(panel.Tabs.Tab_flag)
check("flag preview", Panels.previewNpc() ~= nil)
press(panel.Tabs.Tab_title)
check("titles tab: no preview", panel.Side.Visible == false)
check(
	"earned title can be worn",
	panel.Body:FindFirstChild("Title_wallMaster") and textIn(panel.Body.Title_wallMaster, "WEAR") ~= nil
)
check(
	"unearned title shows progress",
	panel.Body:FindFirstChild("Title_trapper") and textIn(panel.Body.Title_trapper, "7 / 50") ~= nil
)
click(panel.Body.Title_wallMaster, "WEAR")
check("title worn", sent("Equip") and sent("Equip").args[1] == "title" and sent("Equip").args[2] == "wallMaster")
-- tasks
press(hud.tasks)
Engine.advance(0.1)
check("TASKS opens", string.find(panel.Title.Text, "TASKS", 1, true) ~= nil)
check("gift claimed already", textIn(panel.Body.Gift, "CLAIMED") ~= nil)
check("task rows", panel.Body:FindFirstChild("Task_build5") and textIn(panel.Body.Task_build5, "2 / 5") ~= nil)
check("a done task is ticked", textIn(panel.Body.Task_mine50, "✔") ~= nil)
check("weekly", panel.Body:FindFirstChild("Weekly_win3") ~= nil)
check("longest hold", textIn(panel.Body, "4:05") ~= nil)
check(
	"job levels",
	textIn(panel.Body.JobLevels, "Builder  Lv 2") ~= nil and textIn(panel.Body.JobLevels, "Grunt  Lv 3") ~= nil
)
-- friends
Engine.friendsOnline = {
	{ VisitorId = 55, UserName = "ben", DisplayName = "Ben", PlaceId = Engine.game.PlaceId, GameId = "job-55" },
	{ VisitorId = 66, UserName = "cal", DisplayName = "Cal", PlaceId = Engine.game.PlaceId, GameId = "job-66" },
}
press(hud.friends)
Engine.advance(0.2)
check("FRIENDS opens", string.find(panel.Title.Text, "FRIENDS", 1, true) ~= nil)
check("asked the server about them", sent("Friends") and #sent("Friends").args[1] == 2)
serverSends("Friends", {
	{ userId = 55, phase = "fight", shrine = 2, held = 125, crew = 10, max = 24 },
	{ userId = 66, phase = "build", crew = 24, max = 24, full = true },
})
check("friend status", textIn(panel.Body.Friend_55, "Fighting at shrine 2 · held 2:05 · 10/24 players") ~= nil)
check("full server", textIn(panel.Body.Friend_66, "FULL") ~= nil)
click(panel.Body.Friend_55, "JOIN")
check("join sent", sent("JoinFriend") and sent("JoinFriend").args[1] == 55)
click(panel.Body, "INVITE")
check("invite prompt", Engine.invites == 1)
serverSends("FriendResult", { kind = "full", name = "Cal" })
local full = panels:FindFirstChild("ServerFull")
check("server full card", full and textIn(full, "no free spots") ~= nil)
click(full, "Wait for a spot")
check("retry sent", sent("FriendAction") and sent("FriendAction").args[1] == "retry")
serverSends("FriendResult", { kind = "waiting", name = "Cal", tries = 1, max = 8, wait = 15 })
check("waiting card", panels:FindFirstChild("Waiting") and textIn(panels.Waiting, "try 2 of 8") ~= nil)
click(panels.Waiting, "Stop waiting")
check("cancel sent", sent("FriendAction").args[1] == "cancel")
serverSends("FriendResult", { kind = "failed", stillFull = true, text = "Cal's server is still full." })
click(panels.StillFull, "private match")
check("private match sent", sent("FriendAction").args[1] == "new")
serverSends("FriendResult", { kind = "rejoin", phase = "fight", shrine = 2, crew = 12, max = 24 })
check("rejoin card", panels:FindFirstChild("Rejoin") and textIn(panels.Rejoin, "shrine 2") ~= nil)
click(panels.Rejoin, "Rejoin my match")
check("rejoin sent", sent("FriendAction").args[1] == "rejoin")
serverSends("FriendResult", { kind = "here", name = "Ben", team = "monster" })
check("friend here: toast", textIn(hud, "Ben is in this server (a monster)") ~= nil)
-- more: settings, emotes
press(hud.settings)
Engine.advance(0.1)
check("MORE opens", string.find(panel.Title.Text, "MORE", 1, true) ~= nil)
check("how to play", textIn(panel.Body, "1 in 4") ~= nil)
check("how to report", textIn(panel.Body, "Report") ~= nil)
click(panel.Body.Setting_music, "ON")
check("music off sent", sent("Settings") and sent("Settings").args[1] == "music" and sent("Settings").args[2] == false)
check("toggle shows OFF", textIn(panel.Body.Setting_music, "OFF") ~= nil)
local _, vol = Audio.wanted()
check("music volume 0", vol == 0)
click(panel.Body.Emotes, "Cheer")
check("emote sent", sent("Emote") and sent("Emote").args[1] == "cheer" and panel.Visible == false)
press(hud.settings)
click(panel.Body.Emotes, "Dance")
check(
	"an emote you don't own opens the shop",
	string.find(panel.Title.Text, "LOOKS SHOP", 1, true) ~= nil and panel.Body:FindFirstChild("Item_dance", true) ~= nil
)
press(panel.Close)
check("panel closes", panel.Visible == false)
-- the Job Board's prompt
local jobPrompt
for _, d in ws.Map:GetDescendants() do
	if d.ClassName == "ProximityPrompt" and d.Name == "JobPrompt" then
		jobPrompt = d
		break
	end
end
local PPS = Engine.game:GetService("ProximityPromptService")
check("job prompts on for dwarves", jobPrompt and jobPrompt.Enabled == true)
PPS.PromptTriggered:Fire(jobPrompt, player)
Engine.advance(0.1)
check("JOB BOARD opens", panel.Visible and string.find(panel.Title.Text, "JOB BOARD", 1, true) ~= nil)
check(
	"five dwarf jobs",
	panel.Body:FindFirstChild("Job_archer", true) ~= nil and panel.Body:FindFirstChild("Job_healer", true) ~= nil
)
check("your job: keep", textIn(panel.Body:FindFirstChild("Job_builder", true), "KEEP") ~= nil)
click(panel.Body:FindFirstChild("Job_miner", true), "PICK")
check("job sent", sent("Job") and sent("Job").args[1] == "miner" and panel.Visible == false)
-- the shop sign in the hangout
local shopPrompt = MapBuilder.hangout.shop:FindFirstChild("ShopPrompt")
PPS.PromptTriggered:Fire(shopPrompt, player)
Engine.advance(0.1)
check("shop sign opens the shop", panel.Visible and string.find(panel.Title.Text, "LOOKS SHOP", 1, true) ~= nil)
-- build mode closes panels
press(actions.Mode)
check("build mode closes the panel", panel.Visible == false)
press(gui.Build.BuildControls.Close)

-- The plague and the fight ---------------------------------------------------------------------------------------------
ws:SetAttribute("Phase", "plague")
ws:SetAttribute("PhaseEnds", Engine.now() + 5)
serverSends("Match", { phase = "plague", ends = Engine.now() + 5, number = 1, active = 1, fallen = 0, scared = true })
check("plague alert", hud:FindFirstChild("Alert") and string.find(hud.Alert.Text, "PLAGUE", 1, true) ~= nil)
check("job boards close in the plague", jobPrompt.Enabled == false)
serverSends("Me", {
	team = "monster",
	job = "grunt",
	alive = false,
	level = 1,
	xp = 0,
	nextXp = 60,
	respawnAt = Engine.now() + 4,
	stats = {},
})
character:SetAttribute("Team", "monster")
player:SetAttribute("Team", "monster")
serverSends("Picker", {
	jobs = {
		{ key = "grunt", unlocked = true },
		{ key = "brute", unlocked = false },
		{ key = "spitter", unlocked = true },
		{ key = "witch", unlocked = false },
		{ key = "breaker", unlocked = true },
	},
	current = "grunt",
	respawnAt = Engine.now() + 4,
	why = "plague",
})
local picker = hud:FindFirstChild("Picker")
check("monster picker", picker and textIn(picker, "THE PLAGUE GOT YOU") ~= nil)
check("locked jobs say how", textIn(picker, "Monster level 2") ~= nil)
local jobsBefore = count("Job")
press(picker.Card.brute)
check("a locked job does nothing", count("Job") == jobsBefore)
press(picker.Card.spitter)
check("picked the spitter", sent("Job") and sent("Job").args[1] == "spitter" and hud:FindFirstChild("Picker") == nil)
Engine.advance(0.3)
check(
	"respawn countdown",
	hud.Respawn.Visible and string.find(hud.Respawn.Text, "Back in", 1, true) ~= nil,
	hud.Respawn.Text
)
check("monster card", string.find(hud.Me.Line.Text, "Monster level 1", 1, true) ~= nil)
check("no bag for monsters", hud.Bag.Visible == false)
ws:SetAttribute("Phase", "fight")
ws:SetAttribute("FightEnds", Engine.now() + 600)
serverSends(
	"Match",
	{ phase = "fight", ends = Engine.now() + 600, fightEnds = Engine.now() + 600, number = 1, active = 1, fallen = 0 }
)
serverSends("Me", { team = "monster", job = "spitter", alive = true, level = 2, xp = 10, nextXp = 90, stats = {} })
serverSends("Shrines", {
	{ health = 70, state = "active", dwarves = 2, monsters = 5, rate = -1.5, wards = 0 },
	{ health = 100, state = "safe", dwarves = 0, monsters = 0, rate = 0, wards = 0 },
	{ health = 100, state = "safe", dwarves = 0, monsters = 0, rate = 0, wards = 0 },
})
Engine.advance(0.3)
check("monster alert", hud:FindFirstChild("Alert") and string.find(hud.Alert.Text, "ATTACK", 1, true) ~= nil)
check(
	"shrine count: monsters vs dwarves",
	string.find(hud.Clock.Shrine1.Count.Text, "5", 1, true) ~= nil
		and string.find(hud.Clock.Shrine1.Count.Text, "2", 1, true) ~= nil,
	hud.Clock.Shrine1.Count.Text
)
check("draining shrine is red", sameColor(hud.Clock.Shrine1.Frame.Fill.BackgroundColor3, Color3.fromRGB(255, 65, 75)))
check(
	"fight clock",
	string.find(hud.Clock.Phase.Text, "10:00", 1, true) ~= nil
		or string.find(hud.Clock.Phase.Text, "9:5", 1, true) ~= nil,
	hud.Clock.Phase.Text
)
check("no build button for monsters", actions.Mode.Visible == false)
check("MAIN: spit", string.find(actions.Main.Label.Text, "SPIT", 1, true) ~= nil, actions.Main.Label.Text)
-- at the monster spawn the JOB button shows
Engine.moveTo(player, MapLayout.monsterSpawnCenter(0) + Vector3.new(0, 3, 0))
camAt(MapLayout.monsterSpawnCenter(0))
Engine.advance(0.3)
check("JOB button at the spawn", actions.Jobs.Visible == true)
press(actions.Jobs)
check("it opens the picker", hud:FindFirstChild("Picker") ~= nil)
press(hud.Picker.Card.grunt)
press(actions.Special)
local sp = sent("Act")
check("special sent", sp and sp.args[1] == "special")
press(actions.Ping)
local pings = actions:FindFirstChild("Pings")
check("ping wheel", pings ~= nil)
click(pings, "Monsters coming")
check("ping sent", sent("Ping") and sent("Ping").args[1] == "coming")
Engine.advance(3.5)
local fight = LightingPresets.list.fight
check(
	"fight lighting",
	math.abs(Engine.game:GetService("Lighting").ClockTime - fight.clock) < 0.01,
	Engine.game:GetService("Lighting").ClockTime
)
check("music: fight", Audio.music.key == "fight")
ws:SetAttribute("Phase", "laststand")
serverSends("Match", {
	phase = "laststand",
	ends = Engine.now() + 120,
	fightEnds = Engine.now() + 120,
	number = 1,
	active = 3,
	fallen = 2,
})
Engine.advance(1)
check("last stand alert", textIn(hud, "LAST STAND") ~= nil)
check(
	"music: the last stand, faster",
	Audio.music.key == "laststand"
		and math.abs(Audio.music.sound.PlaybackSpeed - Constants.LASTSTAND_MUSIC_SPEED) < 1e-6
)
serverSends("Knock", Vector3.new(1, 0, 0), 30)
check("knocked back", player.Character.HumanoidRootPart.AssemblyLinearVelocity.X > 10)
serverSends("Dash", Vector3.new(0, 0, 1), 20, 0.5)
Engine.advance(0.1)
check("the charge moves you", player.Character.HumanoidRootPart.AssemblyLinearVelocity.Z > 10)

-- The end ------------------------------------------------------------------------------------------------------------
ws:SetAttribute("Phase", "ended")
serverSends("Match", { phase = "ended", number = 1, active = 3, fallen = 2, result = { winner = "dwarf" } })
serverSends("Results", {
	winner = "dwarf",
	reason = "clock",
	held = 600,
	fallen = 2,
	number = 1,
	mvps = { builder = { name = "Ava", n = 14 }, defender = { name = "Ben", n = 30 }, lastDwarf = { name = "Cal" } },
	you = {
		won = false,
		coins = 85,
		xp = 60,
		level = 4,
		leveledUp = true,
		stats = { built = 14, beaten = 2, dwarvesBeaten = 3, broken = 5, heldSeconds = 200 },
	},
})
local results = hud:FindFirstChild("Results")
check("results screen", results and textIn(results, "THE DWARVES HELD") ~= nil)
check("held for 10:00", textIn(results, "Held for 10:00") ~= nil)
check("your rewards", textIn(results, "+85 coins") ~= nil and textIn(results, "Level 4") ~= nil)
check("MVPs", textIn(results, "Best builder: Ava (14)") ~= nil and textIn(results, "Last dwarf standing: Cal") ~= nil)
click(results, "OK")
check("results closed", hud:FindFirstChild("Results") == nil)

-- Feedback and update alerts ------------------------------------------------------------------------------------------
serverSends("Ask", { kind = "feedback" })
local fb = panels:FindFirstChild("Feedback")
check("feedback card", fb ~= nil)
click(fb, "Not really")
check("dislike reasons", textIn(fb, "Dwarves always lose") ~= nil)
click(fb, "Dwarves always lose")
click(fb, "SEND")
local f = sent("Feedback")
check("feedback sent with reason", f and f.args[1] == false and f.args[3][1] == "doomed")
serverSends("Ask", { kind = "thanks", like = false })
check("thanks card", panels:FindFirstChild("Thanks") ~= nil)
click(panels.Thanks, "OK")

-- Analytics ----------------------------------------------------------------------------------------------------------
Engine.advance(41)
local a = sent("Analytics")
check("analytics batches", a ~= nil)
local seen = {}
for _, e in Engine.clientLog do
	if e.name == "Analytics" and e.player == "server" then
		seen[e.args[1]] = e.args[2]
	end
end
check(
	"analytics: device info",
	seen.client_info and seen.client_info.device == "touch" and seen.client_info.lite == true
)
check("analytics: taps by button and by action", seen.ui and seen.ui.taps and seen.ui.taps["@ping_coming"] ~= nil)
check("analytics: frame rate", seen.perf and seen.perf.fps ~= nil and seen.perf.lite == true)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
check("no warnings", #Engine.warnings == 0, Engine.warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("client smoke test failed")
end

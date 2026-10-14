--[[
Client smoke test: the real server AND the real client scripts together on the mock engine, as a phone-sized touch
screen, so everything the client draws comes from what the server really sends. It plays the first five minutes
through the client's own buttons (the guide's card and arrow, chopping with ACT, the tree falling, building the
workbench, a crate, the hotbar, the BAG, crafting at the station, the camp chest and the Camp Board), then the
night (monsters drawn from the snapshots, gliding, their health bars, Kermy's tell drawn on the ground, DODGE, a
hit, going down, the DOWN card, a ghost watching a teammate), Mega Kermy's bar, the results, every menu panel (ME,
BOOK, TOP, FRIENDS, MORE), the friend and rejoin cards, "Do you like the game?", the lighting and the music
following the run, lite mode on phones, and the analytics batches. Fails on any script error or warning.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local Instance = Engine.Instance
local Enum = Engine.Enum
local typeof = Engine.globals.typeof

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
Engine.clientEnabled = true -- the server runs, and the local player's client gets what it sends
local ws = Engine.workspace
-- a phone in landscape: 844 x 390
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.1)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Run = service("RunService")
local Survivors = service("SurvivorService")
local Inventory = service("InventoryService")
local Resources = service("ResourceService")
local Camp = service("CampService")
local Loot = service("LootService")
local Monsters = service("MonsterService")
local Boss = service("BossService")
local Tutorial = service("TutorialService")
local Data = service("PlayerDataService")
-- (the game log and analytics batches stay here instead of going out)
local GameLog = service("GameLogService")
GameLog.send = function()
	return true
end
local Analytics = service("AnalyticsService")
local serverEvents = {}
Analytics.send = function(payload)
	for _, e in payload.events do
		table.insert(serverEvents, e)
	end
	return true
end
local Constants = Engine.require(tree.shared.Constants)
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local Items = Engine.require(tree.shared.Data.Items)
local ItemModels = Engine.require(tree.shared.World.ItemModels)
local Recipes = Engine.require(tree.shared.Data.Recipes)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local PPS = Engine.game:GetService("ProximityPromptService")
local CollectionService = Engine.game:GetService("CollectionService")
local details = CollectionService:GetTagged("Detail")
check("decoration is tagged as detail", #details > 20, #details)

-- The local player, with the real client ---------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)
check("a run started", Run:Phase() == "day" and Run:InRun(player))
check("ava has a character", player.Character ~= nil)

local gui = player.PlayerGui
local hud = gui:FindFirstChild("Hud")
local actions = gui:FindFirstChild("Actions")
local panels = gui:FindFirstChild("Panels")
local guide = gui:FindFirstChild("Guide")
local Hud = Engine.require(tree.client.Controllers.HudController)
local Input = Engine.require(tree.client.Controllers.InputController)
local Panels = Engine.require(tree.client.Controllers.PanelController)
local Mobs = Engine.require(tree.client.Controllers.MonsterController)
local Fx = Engine.require(tree.client.Controllers.FxController)
local Anim = Engine.require(tree.client.Controllers.AnimController)
local Audio = Engine.require(tree.client.Controllers.AudioController)
local Perf = Engine.require(tree.client.Controllers.PerformanceController)
local Guide = Engine.require(tree.client.Controllers.TutorialController)
local Store = Engine.require(tree.client.Store)
local Bus = Engine.require(tree.client.UI.Bus)
local refs = Hud.refs

-- the last event this client sent the server (the server's own events of the same name don't count)
local function sent(name)
	for i = #Engine.clientLog, 1, -1 do
		local e = Engine.clientLog[i]
		if e.name == name and e.player == "server" then
			return e
		end
	end
	return nil
end
local function countSent(name)
	local n = 0
	for _, e in Engine.clientLog do
		if e.name == name and e.player == "server" then
			n += 1
		end
	end
	return n
end
local function serverSends(name, ...)
	Engine.remote(name):FireClient(player, ...)
	Engine.advance(0.05)
end
local function textIn(root, needle)
	for _, d in root:GetDescendants() do
		if
			(d.ClassName == "TextLabel" or d.ClassName == "TextButton")
			and type(d.Text) == "string"
			and string.find(string.upper(d.Text), string.upper(needle), 1, true)
		then
			return d
		end
	end
	return nil
end
local function findButton(root, text)
	for _, d in root:GetDescendants() do
		if
			d.ClassName == "TextButton"
			and type(d.Text) == "string"
			and string.find(string.upper(d.Text), string.upper(text), 1, true)
		then
			return d
		end
	end
	return nil
end
local function press(b)
	b.Activated:Fire()
	Engine.advance(0.05)
end
local function click(root, text)
	local b = findButton(root, text)
	check("button '" .. text .. "' exists", b ~= nil)
	if b then
		press(b)
	end
	return b
end
local function ground(x, z)
	return MapLayout.groundY(x, z)
end
local function camLook(from, at)
	ws.CurrentCamera.CFrame = CFrame.lookAt(from + Vector3.new(0, 7, 0) - (at - from).Unit * 12, at)
end
-- stand on the ground at (x, z) facing a point; the camera behind you
local function standAt(x, z, lookAt)
	local at = Vector3.new(x, ground(x, z) + 3, z)
	Engine.moveTo(player, at, lookAt and Vector3.new(lookAt.X, at.Y, lookAt.Z) or nil)
	if lookAt then
		camLook(at, Vector3.new(lookAt.X, at.Y, lookAt.Z))
	else
		ws.CurrentCamera.CFrame = CFrame.lookAt(at + Vector3.new(0, 8, 14), at)
	end
end
local function pos()
	return Survivors:Position(player)
end
local function count(key)
	return Inventory:Count(player, key)
end
local function holdPhase(seconds)
	Run:Get().phaseEnds = Engine.now() + seconds
	Run:Broadcast()
end
local function skipTo(phase)
	for _ = 1, 30 do
		if Run:Phase() == phase then
			return true
		end
		Run:_skip()
		Engine.advance(0.6)
	end
	return Run:Phase() == phase
end
local function pressAct()
	actions.Act.MouseButton1Down:Fire()
	Engine.advance(0.05)
	actions.Act.MouseButton1Up:Fire()
end

-- 1. Boot: the screens, lite mode on a phone -------------------------------------------------------------------------------------------------
check("HUD built", hud ~= nil)
check(
	"action buttons",
	actions
		and actions:FindFirstChild("Act")
		and actions:FindFirstChild("Dodge")
		and actions:FindFirstChild("Special")
		and actions:FindFirstChild("Ping")
)
check("panels screen", panels ~= nil)
check("guide screen", guide ~= nil and guide:FindFirstChild("GuideCard") ~= nil)
check("phone scale applied", hud.Scale.Scale < 1 and hud.Scale.Scale >= 0.55, hud.Scale.Scale)
check("landscape on phones", gui.ScreenOrientation ~= nil)
check("lite mode on a phone", Perf.lite == true)
local dropped = 0
for _, d in details do
	if d.Parent == nil then
		dropped += 1
	end
end
check("lite mode leaves the decoration out", dropped == #details, `{dropped}/{#details}`)
check(
	"six menu buttons",
	hud.Menu:FindFirstChild("Menu_inventory")
		and hud.Menu:FindFirstChild("Menu_progress")
		and hud.Menu:FindFirstChild("Menu_bestiary")
		and hud.Menu:FindFirstChild("Menu_boards")
		and hud.Menu:FindFirstChild("Menu_friends")
		and hud.Menu:FindFirstChild("Menu_settings")
)
check("the store has the run", Store.get("run") and Store.get("run").phase == "day")
check("the store has the profile", Store.get("profile") ~= nil)
check("you're in the run", Store.inRun())

-- 2. Day 1 on the HUD -------------------------------------------------------------------------------------------------------------------------
local spawn = pos()
standAt(spawn.X, spawn.Z)
Engine.advance(0.6)
check(
	"clock: DAY 1 and the time",
	string.find(refs.phase.Text, "DAY 1", 1, true) ~= nil and string.find(refs.phase.Text, ":", 1, true) ~= nil,
	refs.phase.Text
)
check("the night that's coming", string.find(refs.sub.Text, "Night 1 of 6", 1, true) ~= nil, refs.sub.Text)
check("the run's first pip lit", refs.pips[1].BackgroundTransparency == 0, refs.pips[1].BackgroundTransparency)
check("health shows 100", refs.hpText.Text == "100", refs.hpText.Text)
check("level 1", refs.level.Text == "LV 1", refs.level.Text)
check("stamina full", refs.stFill.Size.X.Scale > 0.99, refs.stFill.Size.X.Scale)
check("the hotbar shows", refs.hotbar.Visible == true)
check("slot 1: the Rusty Axe", refs.slots[1].icon.Text == Items.get("rusty_axe").icon, refs.slots[1].icon.Text)
check("slot 1 is selected", refs.slots[1].stroke.Thickness == 5)
check(
	"the torch is in the hotbar",
	(function()
		for i = 1, Constants.HOTBAR do
			if refs.slots[i].icon.Text == Items.get("torch").icon then
				return true
			end
		end
		return false
	end)()
)
check("keyboard numbers hidden on a phone", refs.slots[1].key.Visible == false)
check("the objective is the guide's", string.sub(refs.primary.Text, 1, #"👉 ") == "👉 ", refs.primary.Text)
check("the camp line", string.find(refs.campLine.Text, "The Campsite", 1, true) ~= nil, refs.campLine.Text)
check("the fire's fuel", string.find(refs.fuelText.Text, "%", 1, true) ~= nil, refs.fuelText.Text)
check("the compass: N E S W", refs.compassMarks.dir1 ~= nil and refs.compassMarks.dir1.Text == "N")
check("ACT shows by day", actions.Act.Visible == true)
check("DODGE shows", actions.Dodge.Visible == true)
check("SPRINT on phones", actions.Sprint.Visible == true)
check("no special yet (mastery 3)", actions.Special.Visible == false)
check("no DOWN card", refs.down.Visible == false)
check("no waiting card", refs.out.Visible == false)

-- 3. The guide: chop a tree --------------------------------------------------------------------------------------------------------------------
local card = guide.GuideCard
check(
	"the guide's card",
	card.Visible == true and string.find(card.Step.Text, "STEP 1 OF", 1, true) ~= nil,
	card.Step.Text
)
check("the guide says chop", string.find(card.Text.Text, "Chop", 1, true) ~= nil, card.Text.Text)
check("an arrow over the tree", ws:FindFirstChild("Guide") and ws.Guide:FindFirstChild("GuideArrow") ~= nil)
check(
	"a beam to it",
	ws.Guide:FindFirstChild("GuideTarget") and ws.Guide.GuideTarget:FindFirstChild("GuideBeam") ~= nil
)
check("the beam starts at you", ws.Guide.GuideTarget.GuideBeam.Attachment0 ~= nil)
do
	-- the arrow and the beam end beside the trunk (not inside the tree), and that tree glows
	local view = Guide.current()
	local rec = view and view.tree and Resources:Tree(view.tree)
	check("the guide names the tree to chop", rec ~= nil, view and view.tree)
	if rec then
		local off = Vector3.new(view.target.X - rec.rec.x, 0, view.target.Z - rec.rec.z).Magnitude
		check("the arrow floats beside the trunk", off > rec.rec.trunk + 1, off - rec.rec.trunk)
		check("a tree an axe can chop", Resources:CanChop(rec))
		Engine.advance(0.6)
		local glow = ws.Guide:FindFirstChild("GuideGlow")
		check(
			"the tree to chop glows",
			glow ~= nil and glow.Adornee ~= nil and glow.Adornee:GetAttribute("TreeId") == view.tree,
			glow and glow.Adornee
		)
	end
end
-- walk to the nearest tree outside the camp and face it
local trees = Resources:TreesNear(spawn, 160)
local target
for _, t in trees do
	if MapLayout.radius(t.rec.x, t.rec.z) > MapLayout.CAMP.clear + 4 then
		target = t
		break
	end
end
check("a tree to chop", target ~= nil)
local tp = Vector3.new(target.rec.x, 0, target.rec.z)
local dir = Vector3.new(spawn.X, 0, spawn.Z) - tp
dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
local spot = tp + dir * (target.rec.trunk + 3)
standAt(spot.X, spot.Z, tp)
Engine.advance(0.4)
check("ACT says CHOP by a tree", actions.Act.Label.Text == "CHOP", actions.Act.Label.Text)
check("the axe on ACT", actions.Act.Icon.Text == Items.get("rusty_axe").icon)
local wood0 = count("wood")
local chops = 0
local popups = 0
for _ = 1, 40 do
	pressAct()
	chops += 1
	Engine.advance(0.65)
	if ws.Fx:FindFirstChild("Popup") or #Fx.movers > 0 then
		popups += 1
	end
	if target.felled then
		break
	end
end
local act = sent("Act")
check(
	"ACT sends the hotbar slot, the aim and main",
	act and act.args[1] == 1 and typeof(act.args[2]) == "Vector3" and act.args[3] == "main",
	act and `{tostring(act.args[1])} {typeof(act.args[2])} {tostring(act.args[3])}`
)
check(
	"the aim points at the tree",
	act and act.args[2]:Dot((tp - Vector3.new(spot.X, 0, spot.Z)).Unit) > 0.8,
	act and act.args[2]
)
check("chopping gave wood", count("wood") > wood0, count("wood") - wood0)
check("the tree fell", target.felled == true, chops)
check("chips and popups flew", popups > 0)
check("your swing animates at once", Anim.recs[player.Character] ~= nil)
do
	-- which way things move (R15: a positive pitch at the shoulder or elbow swings forward and up)
	local rec = Anim.recs[player.Character]
	-- (the stand-in avatar is welded together: give the pose an R15 rig's joints to aim)
	for _, name in { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist", "Neck", "Root" } do
		rec.motors[name] = rec.motors[name] or { motor = Instance.new("Motor6D"), base = CFrame.new() }
	end
	local axe = Items.get("rusty_axe")
	check("you hold the axe", Anim.heldItem(player.Character) == axe, player.Character:GetAttribute("Held"))
	rec.item, rec.mode, rec.swingAt, rec.emote = nil, nil, -100, nil
	local pose = Anim.pose(rec, player.Character, 0)
	local arm = pose.RightShoulder and pose.RightShoulder.Rotation * Vector3.new(0, -1, 0)
	check("the arm holding it reaches forward", arm and arm.Z < -0.5, arm)
	local hand = (pose.RightShoulder or CFrame.new()) * (pose.RightElbow or CFrame.new())
	local grip = hand.Rotation * ItemModels.holdCFrame(axe, nil).Rotation
	local handle = grip * Vector3.new(0, 0, -1) -- toward the axe's head
	local edge = grip * Vector3.new(0, 1, 0) -- the blade
	check("the axe stands up out of the fist", handle.Y > 0.9, handle)
	check("its blade faces forward", edge.Z < -0.9, edge)
	local spear = ItemModels.holdCFrame(Items.get("sharp_stick"), nil).Rotation
	local tip = (hand.Rotation * spear) * Vector3.new(0, 0, -1)
	check("a spear points ahead", tip.Z < -0.9, tip)
	local torch = ItemModels.holdCFrame(Items.get("torch"), nil).Rotation
	local flame = (hand.Rotation * torch) * Vector3.new(0, 1, 0)
	check("a torch is held upright", flame.Y > 0.9, flame)
	-- the chop: up over the head, then down in front of you
	rec.item, rec.mode, rec.swingAt = "rusty_axe", "main", 100
	local up = Anim.pose(rec, player.Character, 100.12).RightShoulder.Rotation * Vector3.new(0, -1, 0)
	check("the chop winds up over your head", up.Y > 0.6, up)
	local down = Anim.pose(rec, player.Character, 100.24).RightShoulder.Rotation * Vector3.new(0, -1, 0)
	check("and comes down in front of you", down.Z < 0 and down.Y < -0.8, down)
	local waist = Anim.pose(rec, player.Character, 100.2).Waist
	check("leaning into it", waist and (waist.Rotation * Vector3.new(0, 1, 0)).Z < 0, waist)
	-- the 6-7: forearms out in front
	rec.item, rec.mode, rec.emote, rec.emoteAt = "emote", "67", "67", 100
	local fore = Anim.pose(rec, player.Character, 101)
	local left = (fore.LeftShoulder * fore.LeftElbow).Rotation * Vector3.new(0, -1, 0)
	check("the 6-7's forearms reach out in front", left.Z < -0.5, left)
	rec.emote = nil
	-- an R6 rig has no elbows: the bend goes to the shoulder
	rec.motors.RightElbow, rec.motors.LeftElbow = nil, nil
	rec.item, rec.mode, rec.swingAt = nil, nil, -100
	local r6 = Anim.pose(rec, player.Character, 0)
	local r6arm = r6.RightShoulder.Rotation * Vector3.new(0, -1, 0)
	check("R6: the arm holding it reaches forward", r6.RightElbow == nil and r6arm.Z < -0.9, r6arm)
	for _, name in { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist", "Neck", "Root" } do
		rec.motors[name] = nil
	end
end
-- PC: a click swings where the camera looks and turns to the tree in front of you, even with your character
-- facing away from it
do
	UIS.MouseEnabled, UIS.KeyboardEnabled = true, true
	Engine.setInput(Enum.UserInputType.MouseMovement)
	local pick
	for _, t in Resources:TreesNear(pos(), 200) do
		if Resources:CanChop(t) and MapLayout.radius(t.rec.x, t.rec.z) > MapLayout.CAMP.clear + 4 then
			pick = t
			break
		end
	end
	check("PC: another tree to chop", pick ~= nil)
	if pick then
		local tp2 = Vector3.new(pick.rec.x, 0, pick.rec.z)
		local away = Vector3.new(spawn.X, 0, spawn.Z) - tp2
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		local at = tp2 + away * (pick.rec.trunk + 3)
		standAt(at.X, at.Z, at + away * 10)
		local toTree = (tp2 - Vector3.new(at.X, 0, at.Z)).Unit
		local a = math.rad(40)
		local off = Vector3.new(
			toTree.X * math.cos(a) - toTree.Z * math.sin(a),
			0,
			toTree.X * math.sin(a) + toTree.Z * math.cos(a)
		)
		local here = pos()
		ws.CurrentCamera.CFrame = CFrame.lookAt(here + Vector3.new(0, 7, 0) - off * 12, here + off * 10)
		Engine.advance(0.7)
		local hp0 = pick.hp
		UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
		Engine.advance(0.05)
		UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
		Engine.advance(0.2)
		local click = sent("Act")
		check("PC: a click swings at the tree", click and click.args[2]:Dot(toTree) > 0.9, click and click.args[2])
		check("PC: and chops it", pick.hp < hp0, pick.hp)
		check("PC: you turn to face it", player.Character.HumanoidRootPart.CFrame.LookVector:Dot(toTree) > 0.9)
	end
	-- the key hints show on PC (and hide again on a phone)
	local hint = actions.Dodge:FindFirstChild("KeyHint")
	check("PC: key hints show", hint ~= nil and hint.Visible == true and hint.Text == "Q", hint and hint.Text)
	-- a click on an open panel is for the panel, not a swing
	Bus.Open:Fire("inventory")
	Engine.advance(0.7)
	local acts = countSent("Act")
	UIS.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1 }, false)
	Engine.advance(0.05)
	UIS.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
	check("PC: clicking a panel doesn't swing", countSent("Act") == acts, countSent("Act") - acts)
	Panels.close()
	UIS.MouseEnabled, UIS.KeyboardEnabled = false, false
	Engine.setInput(Enum.UserInputType.Touch)
	check("phone: no key hints", hint and hint.Visible == false)
end
-- phone: holding ACT keeps swinging, and stops when that finger lifts, even off the button
do
	Engine.advance(0.7)
	local touch = { UserInputType = Enum.UserInputType.Touch }
	actions.Act.InputBegan:Fire(touch)
	actions.Act.MouseButton1Down:Fire()
	Engine.advance(1.3)
	local held = countSent("Act")
	UIS.InputEnded:Fire(touch)
	Engine.advance(1.3)
	check("phone: holding ACT keeps swinging", held >= 2, held)
	check("phone: lifting the finger anywhere stops it", countSent("Act") == held, countSent("Act") - held)
end
-- the camp's prompts that share a spot each have their own key (Roblox shows one prompt per key)
do
	local fire = ws.Map.Camp:FindFirstChild("Campfire", true)
	local cook = fire and fire:FindFirstChild("Cook", true)
	local fuel = fire and fire:FindFirstChild("Fuel", true)
	check(
		"campfire: Feed and Cook on different keys",
		cook and fuel and cook.KeyboardKeyCode ~= fuel.KeyboardKeyCode,
		cook and tostring(cook.KeyboardKeyCode)
	)
	check(
		"structures: Repair and Reinforce have their own keys",
		Camp.PROMPT_KEYS.Repair[1] ~= Camp.PROMPT_KEYS.Reinforce[1]
	)
end
-- felled trees leave round stumps; rocks collide as a box inside them, not their whole box
do
	local stumps = ws.Map:FindFirstChild("Stumps")
	local stump = stumps and stumps:FindFirstChildWhichIsA("Model")
	local trunk = stump and stump:FindFirstChild("Stump")
	check("a round stump", trunk ~= nil and math.abs(trunk.Size.Y - trunk.Size.Z) < 1e-3, trunk and trunk.Size)
	local rock = ws.Nodes:FindFirstChild("rock")
	local look, collider = rock and rock:FindFirstChild("Rock"), rock and rock:FindFirstChild("BoulderCollider")
	check(
		"rocks: the round rock doesn't collide, a box inside it does",
		look and collider and look.CanCollide == false and collider.CanCollide ~= false and collider.Transparency == 1
	)
end
-- a giant of the deep forest is too big to chop: the swing says so instead of doing nothing
do
	local giant, at
	for _, t in MapLayout.trees() do
		local g = t.kind == "giant" and t.reachable and Resources:Tree(t.id)
		if g then
			for k = 0, 3 do
				local a = k * math.pi / 2
				local p = Vector3.new(t.x, 0, t.z) + Vector3.new(math.cos(a), 0, math.sin(a)) * (t.trunk + 2.5)
				local around = Resources:TreesNear(p, Constants.GATHER_RANGE + 3)
				if #around == 1 and around[1] == g and MapLayout.clearOf(p.X, p.Z, 0) ~= false then
					giant, at = g, p
					break
				end
			end
		end
		if giant then
			break
		end
	end
	check("a giant in the forest", giant ~= nil)
	if giant then
		standAt(at.X, at.Z, Vector3.new(giant.rec.x, 0, giant.rec.z))
		Engine.advance(0.7)
		check("no CHOP by a giant", actions.Act.Label.Text ~= "CHOP", actions.Act.Label.Text)
		local wood0 = count("wood")
		pressAct()
		Engine.advance(0.3)
		local toast = Engine.lastClientEvent("Toast", player)
		check(
			"a giant is too big to chop",
			toast and string.find(tostring(toast.args[1]), "too big", 1, true) ~= nil,
			toast and toast.args[1]
		)
		check("no wood from a giant", count("wood") == wood0)
	end
end
-- turn round: the camp on the compass, with how far it is
camLook(pos(), Vector3.new(MapLayout.CAMP_PROPS.fire.X, pos().Y, MapLayout.CAMP_PROPS.fire.Z))
Engine.advance(0.1)
local campMark = refs.compassMarks.camp
check("the compass shows the camp", campMark ~= nil and campMark.Visible == true, campMark and campMark.Text)
check("and how far", campMark and string.find(campMark.Text, "m", 1, true) ~= nil, campMark and campMark.Text)
Engine.advance(2)
check(
	"the guide moved on: build the workbench",
	string.find(card.Text.Text, "Workbench", 1, true) ~= nil,
	card.Text.Text
)
check("step 2", string.find(card.Step.Text, "STEP 2", 1, true) ~= nil, card.Step.Text)
check("the hotbar or backpack has the wood", count("wood") >= 1)

-- 4. Build the workbench (hold its blueprint's prompt) ------------------------------------------------------------------------------------------
local bench = Camp:Structure("workbench_1")
Inventory:Give(player, "wood", 20, "test")
standAt(bench.slot.pos.X + 4, bench.slot.pos.Z, bench.slot.pos)
Engine.advance(0.3)
local buildPrompt
for _, pr in Engine.prompts(ws) do
	if pr:GetAttribute("Structure") == "workbench_1" then
		buildPrompt = pr
	end
end
check("the blueprint's Build prompt", buildPrompt ~= nil)
PPS.PromptButtonHoldBegan:Fire(buildPrompt, player)
local puffed = false
for _ = 1, 25 do
	Engine.advance(0.1)
	if bench.state == "built" then
		puffed = puffed or #Fx.particles > 0
	end
end
PPS.PromptButtonHoldEnded:Fire(buildPrompt, player)
Engine.advance(0.5)
check("the workbench is built", bench.state == "built", bench.state)
check("the camp's pieces go up in a puff", puffed)
Engine.advance(1)
check("the guide: open a crate", string.find(card.Text.Text, "crate", 1, true) ~= nil, card.Text.Text)

-- 5. A crate ------------------------------------------------------------------------------------------------------------------------------------
local crate, crateD
for _, c in Loot:All() do
	if not c.opened and not c.mimic and c.kind == "crate" then
		local d = (c.pos - pos()).Magnitude
		if not crateD or d < crateD then
			crate, crateD = c, d
		end
	end
end
check("a crate nearby", crate ~= nil)
standAt(crate.pos.X + 3, crate.pos.Z, crate.pos)
Engine.advance(0.2)
crate.prompt.Triggered:Fire(player)
Engine.advance(0.6)
check("the crate opened", crate.opened == true)
check("sparkles burst out", #Fx.particles > 0)
local found
for id, s in Inventory:Contents(player) do
	if string.sub(id, 1, 1) == "h" and id ~= "h1" and Items.goesToHotbar(Items.get(s.key)) then
		found = tonumber(string.sub(id, 2))
	end
end
if not found then
	Inventory:Give(player, "branch_club", 1, "test")
	Engine.advance(0.2)
	for id, s in Inventory:Contents(player) do
		if s.key == "branch_club" and string.sub(id, 1, 1) == "h" then
			found = tonumber(string.sub(id, 2))
		end
	end
end
-- tap it in the hotbar
press(refs.slots[found].button)
Engine.advance(0.3)
check("tapping a slot sends Select", sent("Select") and sent("Select").args[1] == found)
check("the slot is selected on screen", refs.slots[found].stroke.Thickness == 5 and refs.slots[1].stroke.Thickness == 3)
check("the server agrees", select(1, Inventory:Selected(player)) == "h" .. found)
Engine.advance(1)
check(
	"the guide's next step",
	Guide.current() == nil or Guide.current().step >= 5,
	Guide.current() and Guide.current().key
)
press(refs.slots[1].button)
Engine.advance(0.3)

-- 6. The BAG -----------------------------------------------------------------------------------------------------------------------------------
press(hud.Menu.Menu_inventory)
Engine.advance(0.1)
local bag = panels:FindFirstChild("Panel_inventory")
check("BAG opens", bag ~= nil and Panels.current() == "inventory")
check("viewed: inventory", sent("Viewed") and sent("Viewed").args[1] == "inventory")
check("the hotbar slots", bag and bag.Body.Slots.Hotbar:FindFirstChild("Slot_h1") ~= nil)
check("the backpack slots", bag and #bag.Body.Slots.Backpack:GetChildren() >= Inventory:Capacity(player))
check("the rules, in short", textIn(bag, "pack drops where you fell") ~= nil)
press(bag.Body.Slots.Hotbar.Slot_h1)
bag = panels:FindFirstChild("Panel_inventory")
check("tapping an item shows it", textIn(bag.Body.Detail, Items.get("rusty_axe").name) ~= nil)
check("its damage", textIn(bag.Body.Detail, "damage") ~= nil)
check("DROP", bag.Body.Detail:FindFirstChild("Drop") ~= nil)
press(bag.Body.Slots.Backpack.Slot_b5)
local mv = sent("Move")
check("tap another slot: move", mv and mv.args[1] == "h1" and mv.args[2] == "b5")
Engine.advance(0.3)
check("the axe moved", Inventory:Slot(player, "b5") and Inventory:Slot(player, "b5").key == "rusty_axe")
bag = panels:FindFirstChild("Panel_inventory")
press(bag.Body.Slots.Backpack.Slot_b5)
bag = panels:FindFirstChild("Panel_inventory")
press(bag.Body.Slots.Hotbar.Slot_h1)
Engine.advance(0.3)
check("and back", Inventory:Slot(player, "h1") and Inventory:Slot(player, "h1").key == "rusty_axe")
check("the hotbar redrew", refs.slots[1].icon.Text == Items.get("rusty_axe").icon)
-- wear a pack from the BAG
Inventory:Give(player, "small_pack", 1, "test")
Engine.advance(0.2)
local packSlot
for id, s in Inventory:Contents(player) do
	if s.key == "small_pack" then
		packSlot = id
	end
end
bag = panels:FindFirstChild("Panel_inventory")
local packCell = bag:FindFirstChild("Slot_" .. packSlot, true)
check("the pack shows up", packCell ~= nil)
if packCell then
	press(packCell)
	bag = panels:FindFirstChild("Panel_inventory")
	check("WEAR", bag.Body.Detail:FindFirstChild("Equip") ~= nil)
	press(bag.Body.Detail.Equip)
	Engine.advance(0.3)
	check("wearing the pack", Inventory:Slot(player, "pack") and Inventory:Slot(player, "pack").key == "small_pack")
	bag = panels:FindFirstChild("Panel_inventory")
	check(
		"more backpack slots on screen",
		#bag.Body.Slots.Backpack:GetChildren() >= Inventory:Capacity(player),
		Inventory:Capacity(player)
	)
end
press(bag.Head.Close)
check("BAG closes", panels:FindFirstChild("Panel_inventory") == nil and Panels.current() == nil)

-- 7. Crafting at the workbench -------------------------------------------------------------------------------------------------------------------
Inventory:Give(player, "stone", 6, "test")
standAt(bench.slot.pos.X + 4, bench.slot.pos.Z, bench.slot.pos)
Engine.advance(0.2)
local usePrompt
for _, pr in Engine.prompts(ws) do
	if pr:GetAttribute("Structure") == "workbench_1" then
		usePrompt = pr
	end
end
check(
	"the built bench has a Use prompt",
	usePrompt and usePrompt:GetAttribute("Action") == "Use",
	usePrompt and usePrompt:GetAttribute("Action")
)
PPS.PromptTriggered:Fire(usePrompt, player)
Engine.advance(0.2)
local craft = panels:FindFirstChild("Panel_craft")
check("using the bench opens CRAFT", craft ~= nil)
local axeRow = craft and craft:FindFirstChild("Craft_stone_axe", true)
check("the Stone Axe recipe", axeRow ~= nil)
check("its cost, counted", craft and craft:FindFirstChild("Cost_wood", true) ~= nil)
local bowRow = craft and craft:FindFirstChild("Craft_short_bow", true)
check("tier-2 recipes say what they need", bowRow == nil or textIn(craft, "Needs") ~= nil)
press(axeRow)
Engine.advance(0.3)
check("MAKE sends the recipe", sent("Craft") and sent("Craft").args[1] == Recipes.byItem.stone_axe.id)
check("the Stone Axe was made", count("stone_axe") == 1)
check("a toast says so", textIn(hud, "Stone Axe") ~= nil)

-- 8. The camp chest and the Camp Board -----------------------------------------------------------------------------------------------------------
local chest = Camp:Structure("storage_1")
Inventory:Give(player, "wood", 30, "test")
standAt(chest.slot.pos.X + 3, chest.slot.pos.Z, chest.slot.pos)
for _ = 1, 12 do
	Camp:Deposit(player, chest, false)
end
check("the chest is built", chest.state == "built")
Engine.advance(0.3)
local chestPrompt
for _, pr in Engine.prompts(ws) do
	if pr:GetAttribute("Structure") == "storage_1" and pr:GetAttribute("Action") == "Use" then
		chestPrompt = pr
	end
end
check("the chest has a Use prompt", chestPrompt ~= nil)
PPS.PromptTriggered:Fire(chestPrompt, player)
Engine.advance(0.2)
local chestPanel = panels:FindFirstChild("Panel_storage")
check("the chest's panel opens", chestPanel ~= nil)
local woodSlot
for id, s in Inventory:Contents(player) do
	if s.key == "wood" then
		woodSlot = id
	end
end
local put = chestPanel and chestPanel:FindFirstChild("Put_" .. woodSlot, true)
check("PUT on your wood", put ~= nil)
if put then
	press(put)
	Engine.advance(0.3)
end
check("wood went in the chest", Camp:StorageCount("wood") > 0, Camp:StorageCount("wood"))
chestPanel = panels:FindFirstChild("Panel_storage")
check("the chest's side shows it", chestPanel and chestPanel:FindFirstChild("Take_wood", true) ~= nil)
press(chestPanel:FindFirstChild("Take_wood", true))
Engine.advance(0.3)
check("TAKE takes it back", Camp:StorageCount("wood") == 0, Camp:StorageCount("wood"))
press(panels:FindFirstChild("Panel_storage"):FindFirstChild("PutAll", true))
Engine.advance(0.3)
check("PUT ALL puts the resources in", Camp:StorageCount("wood") > 0 and count("wood") == 0)
-- the Camp Board: what the Outpost needs, then UPGRADE
local board = ws.Map.Camp.CampBoard.Board
local boardPrompt = board:FindFirstChild("Upgrade")
standAt(board.Position.X + 3, board.Position.Z, board.Position)
PPS.PromptTriggered:Fire(boardPrompt, player)
boardPrompt.Triggered:Fire(player)
Engine.advance(0.2)
local campPanel = panels:FindFirstChild("Panel_camp")
check("the Camp Board opens the camp's panel", campPanel ~= nil)
check(
	"what the next tier needs",
	campPanel and textIn(campPanel, "NEXT:") ~= nil and textIn(campPanel, "Then pay") ~= nil
)
Inventory:Give(player, "stone", 15, "test")
Engine.advance(0.2)
campPanel = panels:FindFirstChild("Panel_camp")
press(campPanel:FindFirstChild("Upgrade", true))
Engine.advance(0.4)
check("UPGRADE makes the Outpost", Camp:Tier() == 2, Camp:Tier())
check("the big alert", hud:FindFirstChild("Alert") and string.find(hud.Alert.Text, "OUTPOST", 1, true) ~= nil)
Engine.advance(0.5)
check("the HUD says The Outpost", string.find(refs.campLine.Text, "Outpost", 1, true) ~= nil, refs.campLine.Text)
Panels.close()

-- 9. A teammate (a bot on the server), the team rows ----------------------------------------------------------------------------------------------
local ben = Engine.addPlayer("Ben", 502)
Engine.advance(0.3)
Engine.fireServer(ben, "Ready")
Engine.fireServer(ben, "SkipTutorial")
Engine.advance(1.2)
check("ben is in the run", Run:InRun(ben))
check("ben's row under you", refs.team:FindFirstChild("Mate502") ~= nil)
check("his name", refs.team:FindFirstChild("Mate502") and refs.team.Mate502.Who.Text == "Ben")
check("you're not in your own team list", refs.team:FindFirstChild("Mate501") == nil)

-- 10. Dusk, then the night ---------------------------------------------------------------------------------------------------------------------
local Lighting = Engine.game:GetService("Lighting")
local LightC = Engine.require(tree.client.Controllers.LightingController)
check("the day's sky", LightC.target() == LightingPresets.forPhase("day"), LightC.target())
check("music: day", Audio.music.key == "day" and Audio.music.sound and Audio.music.sound.IsPlaying)
local fire = MapLayout.CAMP_PROPS.fire
standAt(fire.X + 10, fire.Z + 4, fire)
local benSpawn = MapLayout.spawnPoint(3)
Engine.moveTo(ben, Vector3.new(benSpawn.X, ground(benSpawn.X, benSpawn.Z) + 3, benSpawn.Z))
check("to dusk", skipTo("dusk"))
Engine.advance(0.4)
check("dusk on the clock", string.find(refs.phase.Text, "DUSK", 1, true) ~= nil, refs.phase.Text)
check("back to camp!", refs.sub.Text == "Get back to camp!", refs.sub.Text)
check("a callout", hud:FindFirstChild("Callout") ~= nil)
check("to night 1", skipTo("night"))
holdPhase(500)
Engine.advance(0.6)
-- (the test sets up its own fights)
Monsters:Clear()
Monsters:_night().nextWave = math.huge
Monsters:_kermyState().nightSpawned = true
Monsters:_kermyState().koUntil = math.huge
Engine.advance(0.3)
check("NIGHT 1 on the clock", string.find(refs.phase.Text, "NIGHT 1", 1, true) ~= nil, refs.phase.Text)
check(
	"survive until dawn",
	refs.sub.Text == "Survive until dawn" or Constants.EVENTS[ws:GetAttribute("Event")] ~= nil,
	refs.sub.Text
)
Engine.advance(5.5)
check(
	"the night's sky",
	LightC.target()
		== LightingPresets.forPhase("night", ws:GetAttribute("Event") ~= "" and ws:GetAttribute("Event") or nil),
	LightC.target()
)
check("it's darker", Lighting.ClockTime > 18 or Lighting.ClockTime < 6, Lighting.ClockTime)
check("music: night", Audio.music.key == "night")

-- 11. A Snapcap, drawn from the snapshots ----------------------------------------------------------------------------------------------------------
local function openSpot()
	for a = 0, 350, 10 do
		for r = 50, 120, 10 do
			local p = MapLayout.polar(a, r)
			local clear = true
			for _ in Resources:TreesNear(p, 26) do
				clear = false
				break
			end
			if clear and MapLayout.walkable(p.X, p.Z) and MapLayout.walkable(p.X + 20, p.Z) then
				return p
			end
		end
	end
	return MapLayout.polar(0, 60)
end
local open = openSpot()
standAt(open.X, open.Z, Vector3.new(open.X + 6, 0, open.Z))
Survivors:State(player).protectUntil = math.huge
local snap = Monsters:Spawn("snapcap", Vector3.new(open.X + 6, 0, open.Z), { state = "chase" })
Engine.advance(0.8)
local drawn = Mobs.mobs[snap.id]
check("the Snapcap is drawn", drawn ~= nil and ws.Monsters:FindFirstChild("snapcap" .. snap.id) ~= nil)
check("one monster", Mobs.count() == 1, Mobs.count())
local p1 = Mobs.position(snap.id)
check("drawn where it is", p1 and (p1 - snap.pos).Magnitude < 6, p1 and (p1 - snap.pos).Magnitude)
check("near() finds it", #Mobs.near(pos(), 20) == 1)
check("ACT on a monster", actions.Act.Label.Text == "CHOP" or actions.Act.Label.Text == "SWING", actions.Act.Label.Text)
-- look 50 degrees off: the aim help on phones still turns the swing to it
-- (the Snapcap held still for this, 5 studs away: it would leap right onto you)
snap.state, snap.stateUntil, snap.stunUntil = "stagger", math.huge, math.huge
standAt(snap.pos.X - 5, snap.pos.Z, Vector3.new(snap.pos.X - 10, 0, snap.pos.Z))
do
	local d = Vector3.new(snap.pos.X - pos().X, 0, snap.pos.Z - pos().Z).Unit
	local a = math.rad(50)
	local off = Vector3.new(d.X * math.cos(a) - d.Z * math.sin(a), 0, d.X * math.sin(a) + d.Z * math.cos(a))
	ws.CurrentCamera.CFrame = CFrame.lookAt(pos() + Vector3.new(0, 6, 0), pos() + Vector3.new(0, 6, 0) + off * 20)
end
Engine.advance(0.7)
pressAct()
Engine.advance(0.1)
local swing = sent("Act")
local toSnap = Vector3.new(snap.pos.X - pos().X, 0, snap.pos.Z - pos().Z).Unit
check("aim help turns the swing to the monster", swing and swing.args[2]:Dot(toSnap) > 0.7, swing and swing.args[2])
snap.stateUntil, snap.stunUntil = 0, 0
Engine.advance(0.5)
check("a hit shows its health bar", drawn.barBack and drawn.barBack.Visible == true, snap.hp)
check("a damage number pops", ws.Fx:FindFirstChild("Part") ~= nil or #Fx.movers > 0)
for _ = 1, 25 do
	if snap.hp <= 0 then
		break
	end
	standAt(snap.pos.X - 4, snap.pos.Z, snap.pos)
	Engine.advance(0.1)
	pressAct()
	Engine.advance(0.6)
end
check("the Snapcap went down", snap.hp <= 0, snap.hp)
Engine.advance(1.6)
check("it tumbles and goes", Mobs.mobs[snap.id] == nil and Mobs.count() == 0, Mobs.count())

-- 12. Kermy's lunge: the tell on the ground, his words, DODGE ---------------------------------------------------------------------------------------
for _, mob in Monsters:All() do
	Monsters._mobs[mob.id] = nil
end
standAt(open.X, open.Z, Vector3.new(open.X + 10, 0, open.Z))
Survivors:State(player).protectUntil = 0
local kermy = Monsters:Spawn("kermy", Vector3.new(open.X + 10, 0, open.Z), { state = "chase" })
kermy.nextAttack = 0
local tellSeen, redLine
for _ = 1, 80 do
	Engine.advance(0.05)
	standAt(open.X, open.Z, kermy.pos)
	if Mobs.mobs[kermy.id] and Mobs.mobs[kermy.id].tell == "sixseven" then
		tellSeen = true
		for _, d in ws.Fx:GetChildren() do
			if d.ClassName == "Part" and d.Material == Enum.Material.Neon and d.Color.R > 0.9 and d.Color.G < 0.3 then
				redLine = d
			end
		end
		break
	end
end
check("Kermy's tell reaches the client", tellSeen == true)
check("his lunge is a red line on the ground", redLine ~= nil)
local km = Mobs.mobs[kermy.id]
check("Kermy has his name tag", km and km.nameTag and km.nameTag.Visible == true)
check("SIX... SEVEN!", km and km.rig.model:FindFirstChild("Speech") ~= nil)
local dodges0 = countSent("Dodge")
press(actions.Dodge)
Engine.advance(0.05)
check("DODGE sends a dodge", countSent("Dodge") == dodges0 + 1)
local dash = player.Character.HumanoidRootPart.AssemblyLinearVelocity
check("the dodge moves you", dash and Vector3.new(dash.X, 0, dash.Z).Magnitude > 10, dash)
check("the roll animates", Anim.recs[player.Character] and Anim.recs[player.Character].item == "dodge")
Engine.advance(1.5)
Monsters._mobs[kermy.id] = nil
Engine.advance(1.5)

-- 13. Hit, down, the DOWN card ----------------------------------------------------------------------------------------------------------------------
local char = player.Character
for _, spec in
	{
		{ "RightShoulder", "RightUpperArm" },
		{ "LeftShoulder", "LeftUpperArm" },
		{ "Waist", "UpperTorso" },
		{ "Root", "UpperTorso" },
		{ "Neck", "Head" },
	}
do
	local m = Instance.new("Motor6D")
	m.Name = spec[1]
	m.C0 = CFrame.new(0, 0.5, 0)
	m.Parent = char[spec[2]]
end
Anim.recs[char] = nil
Survivors:State(player).protectUntil = 0
Survivors:Damage(player, 20, { kind = "test", dir = Vector3.new(1, 0, 0), knock = 20 })
Engine.advance(0.1)
check("hurt: the red edges", refs.vignette.BackgroundTransparency < 0.9, refs.vignette.BackgroundTransparency)
check("hurt: the screen shakes", char.Humanoid.CameraOffset ~= nil and char.Humanoid.CameraOffset.Magnitude > 0)
check("knocked back", char.HumanoidRootPart.AssemblyLinearVelocity.X > 10)
Engine.advance(0.4)
check("health went down on the HUD", tonumber(refs.hpText.Text) and tonumber(refs.hpText.Text) < 100, refs.hpText.Text)
local far = MapLayout.polar(200, 150)
standAt(far.X, far.Z)
Survivors:State(player).protectUntil = 0
Survivors:Damage(player, 500, { kind = "test" })
Engine.advance(0.4)
check("you're down", Survivors:Status(player) == "downed")
check("the DOWN card", refs.down.Visible == true)
check("it says what to do", string.find(refs.downHint.Text, "teammate", 1, true) ~= nil, refs.downHint.Text)
check("the bleed-out bar", refs.bleedFill.Size.X.Scale > 0.5, refs.bleedFill.Size.X.Scale)
check("HP says DOWN", refs.hpText.Text == "DOWN")
check("no ACT while down", actions.Act.Visible == false)
check("you can still ping", actions.Ping.Visible == true)
check("you crawl", char.Humanoid.WalkSpeed == Constants.CRAWL_SPEED, char.Humanoid.WalkSpeed)
check("and can't jump", char.Humanoid.UseJumpPower == false and char.Humanoid.JumpHeight == 0)
do
	local own = char.HumanoidRootPart:FindFirstChild("Revive")
	check("your own Revive prompt is for your teammates", own ~= nil and own.Enabled == false, own and own.Enabled)
end
local rootMotor = char.UpperTorso:FindFirstChild("Root")
check("flat on the ground", rootMotor and (rootMotor.C0.Position - Vector3.new(0, 0.5, 0)).Magnitude > 0.5)
check("ben sees you down", Engine.lastClientEvent("Team") ~= nil)

-- 14. A ghost until dawn, watching a teammate ---------------------------------------------------------------------------------------------------------
Engine.advance(40)
check("nobody came: a ghost", Survivors:Status(player) == "ghost", Survivors:Status(player))
Engine.advance(0.5)
check(
	"the ghost card",
	refs.out.Visible == true and string.find(refs.outTitle.Text, "OUT UNTIL DAWN", 1, true) ~= nil,
	refs.outTitle.Text
)
check(
	"watching ben",
	ws.CurrentCamera.CameraSubject == (ben.Character and ben.Character:FindFirstChildOfClass("Humanoid"))
)
check("no hotbar for ghosts", refs.hotbar.Visible == false)
check(
	"the world streams in round the teammate you watch",
	ben.Character and player.ReplicationFocus == ben.Character:FindFirstChild("HumanoidRootPart"),
	player.ReplicationFocus
)
check("no NEW RUN button for a ghost", refs.newRun.Visible == false)
check("the run goes on", Run:Phase() == "night")
check("to dawn", skipTo("dawn"))
Engine.advance(0.5)
check("dawn on the clock", string.find(refs.phase.Text, "DAWN", 1, true) ~= nil, refs.phase.Text)
check("to day 2", skipTo("day"))
Engine.advance(2)
check("back on your feet", Survivors:Status(player) == "alive" and player.Character ~= nil)
check("the ghost card goes", refs.out.Visible == false)
check("the camera is yours again", ws.CurrentCamera.CameraSubject == player.Character:FindFirstChildOfClass("Humanoid"))
check("streaming follows you again", player.ReplicationFocus == nil, player.ReplicationFocus)
-- the client owns its character, so it can still die there (the menu's Reset, falling out of the world)
do
	local old = player.Character
	local hp0 = Survivors:State(player).hp
	old.Humanoid.Died:Fire()
	Engine.advance(1.5)
	check(
		"died anyway: back at the camp",
		player.Character ~= nil and player.Character ~= old and Survivors:Status(player) == "alive",
		Survivors:Status(player)
	)
	check("with the health you had", math.abs(Survivors:State(player).hp - hp0) < 1, Survivors:State(player).hp)
end
check("day 2 on the clock", string.find(refs.phase.Text, "DAY 2", 1, true) ~= nil, refs.phase.Text)
check("pips: night 1 done", refs.pips[2].BackgroundTransparency < 0.5 and refs.pips[3].BackgroundTransparency == 0)

-- 15. On to the 7th night: Mega Kermy -------------------------------------------------------------------------------------------------------------------
Survivors:State(player).protectUntil = math.huge
Survivors:State(ben).protectUntil = math.huge
check("on to night 7", skipTo("boss"), Run:Phase())
holdPhase(900)
Engine.advance(3.5)
local b = Boss:Get()
check("Mega Kermy rises", b ~= nil)
Engine.advance(0.5)
check("his bar", refs.boss.Visible == true and string.find(refs.bossName.Text, "MEGA KERMY", 1, true) ~= nil)
check("his bar is full", refs.bossFill.Size.X.Scale > 0.99)
check("NIGHT 7 on the clock", string.find(refs.phase.Text, "NIGHT 7", 1, true) ~= nil, refs.phase.Text)
check("music: the boss", Audio.music.key == "boss")
local bossDrawn = Mobs.mobs[65500]
check("he's drawn", bossDrawn ~= nil and bossDrawn.kind == "mega_kermy")
check("no small bar over him (the HUD has it)", bossDrawn and bossDrawn.bar == nil)
Engine.advance(4.5)
-- his charge: a red line from him to where it ends
local pine = MapLayout.ancientPines[1]
local outDir = Vector3.new(pine.pos.X, 0, pine.pos.Z).Unit
local bossAt = pine.pos + outDir * 22
b.pos = Vector3.new(bossAt.X, ground(bossAt.X, bossAt.Z), bossAt.Z)
local baitAt = pine.pos - outDir * 8
standAt(baitAt.X, baitAt.Z, b.pos)
local fxBefore = #ws.Fx:GetChildren()
Boss:_startCharge({ player = player, pos = pos() })
Engine.advance(0.1)
check("the charge's line is drawn", #ws.Fx:GetChildren() > fxBefore)
for _ = 1, 60 do
	Engine.advance(0.1)
	if b.state == "faceplant" then
		break
	end
end
check("he's stuck in the pine", b.state == "faceplant", b.state)
for _ = 1, 15 do
	Engine.advance(0.1)
	if string.find(refs.bossTag.Text, "WEAK", 1, true) then
		break
	end
end
check("WEAK! on his bar", string.find(refs.bossTag.Text, "WEAK", 1, true) ~= nil, refs.bossTag.Text)
-- the goo: MASH
b.state = "tired"
b.stateUntil = math.huge
Boss:_cocoon(player)
Engine.advance(0.3)
check("cocooned: ACT says MASH!", actions.Act.Label.Text == "MASH!", actions.Act.Label.Text)
local mash0 = countSent("Mash")
for _ = 1, 14 do
	pressAct()
	Engine.advance(0.1)
end
check("mashing sends Mash", countSent("Mash") > mash0)
check("out of the goo", player:GetAttribute("Cocooned") == nil)
-- the last hit
b.hp = 25
Boss:Damage(100, player, {})
Engine.advance(3.5)

-- 16. The results ------------------------------------------------------------------------------------------------------------------------------------------
check("the run is won", Run:Phase() == "results")
local results = panels:FindFirstChild("Panel_results")
check("the results panel", results ~= nil)
check("you survived the 6-7", results and textIn(results, "SURVIVED THE 6-7") ~= nil)
check("7/7 nights", results and textIn(results, "7/7 nights") ~= nil)
check("the team", results and textIn(results, "Ben") ~= nil)
check("your XP", results and textIn(results, "XP") ~= nil)
check("winners do the 6-7", Anim.recs[player.Character] and Anim.recs[player.Character].emote == "67")
check(
	"music: the results",
	(function()
		Engine.advance(1)
		return Audio.music.key == "results"
	end)()
)
check("the clock says the next run", string.find(refs.phase.Text, "RUN OVER", 1, true) ~= nil, refs.phase.Text)
click(results, "OKAY")
check("OKAY closes it", panels:FindFirstChild("Panel_results") == nil)

-- 17. ME: level, kit, perks, mastery, looks -----------------------------------------------------------------------------------------------------------
press(hud.Menu.Menu_progress)
Engine.advance(0.1)
local me = panels:FindFirstChild("Panel_progress")
check("ME opens", me ~= nil)
check("your level", me and textIn(me, "LEVEL") ~= nil)
check(
	"your records",
	me and textIn(me, "Runs won: 1 of 1") ~= nil,
	me and textIn(me, "Runs won") and textIn(me, "Runs won").Text
)
press(me.Body.Tabs.Tab_kit)
me = panels:FindFirstChild("Panel_progress")
check("the kits", me and textIn(me, "What you start each run with") ~= nil)
press(me.Body.Tabs.Tab_perks)
me = panels:FindFirstChild("Panel_progress")
check("the perks", me and textIn(me, "Perk slots") ~= nil)
local equip = me and findButton(me, "EQUIP")
if equip then
	press(equip)
	check("EQUIP sends a perk", sent("Perk") ~= nil)
end
press(me.Body.Tabs.Tab_mastery)
me = panels:FindFirstChild("Panel_progress")
check("mastery", me and textIn(me, "AXE") ~= nil)
press(me.Body.Tabs.Tab_looks)
me = panels:FindFirstChild("Panel_progress")
check(
	"looks and titles",
	me and (findButton(me, "SHOW") ~= nil or findButton(me, "WEAR") ~= nil or textIn(me, "🔒") ~= nil)
)
local show = me and findButton(me, "SHOW")
if show then
	press(show)
	check("SHOW wears a title", sent("Wear") and sent("Wear").args[1] == "title")
end
press(me.Head.Close)

-- 18. BOOK: monsters, items, places, diary, awards --------------------------------------------------------------------------------------------------------
press(hud.Menu.Menu_bestiary)
Engine.advance(0.1)
local book = panels:FindFirstChild("Panel_bestiary")
check("BOOK opens", book ~= nil)
check("monsters you've met", book and textIn(book, "Snapcap") ~= nil)
check("ones you haven't", book and textIn(book, "???") ~= nil)
for _, tab in { "items", "findings", "diary", "achievements" } do
	press(book.Body.Tabs["Tab_" .. tab])
	book = panels:FindFirstChild("Panel_bestiary")
	check("BOOK tab: " .. tab, book ~= nil and book.Body:FindFirstChild("Area") ~= nil)
end
check("items found", book and (function()
	press(book.Body.Tabs.Tab_items)
	book = panels:FindFirstChild("Panel_bestiary")
	return textIn(book, "items found") ~= nil
end)())
press(book.Head.Close)

-- 19. TOP: the leaderboards ----------------------------------------------------------------------------------------------------------------------------------
press(hud.Menu.Menu_boards)
Engine.advance(0.5)
local top = panels:FindFirstChild("Panel_boards")
check("TOP opens", top ~= nil)
check("asked for a board", sent("Board") ~= nil)
check("friends and everyone", top and textIn(top, "FRIENDS") ~= nil and textIn(top, "EVERYONE") ~= nil)
check("you're on it", top and textIn(top, "Ava") ~= nil)
local cat = top and top:FindFirstChild("Board_monsters", true)
if cat then
	press(cat)
	Engine.advance(0.5)
	check("another category", sent("Board").args[1] == "monsters")
end
press(panels.Panel_boards.Head.Close)

-- 20. FRIENDS: join, full servers, rejoin ---------------------------------------------------------------------------------------------------------------------
Engine.friendsOnline = {
	{ VisitorId = 55, UserName = "cal", DisplayName = "Cal", PlaceId = Engine.game.PlaceId, GameId = "job-55" },
}
press(hud.Menu.Menu_friends)
Engine.advance(0.3)
local fr = panels:FindFirstChild("Panel_friends")
check("FRIENDS opens", fr ~= nil)
check("asked the server about them", sent("Friends") and #sent("Friends").args[1] == 1)
serverSends("Friends", { { userId = 55, phase = "night", night = 3, crew = 4, max = 6 } })
fr = panels:FindFirstChild("Panel_friends")
check("how their run is going", fr and textIn(fr, "night 3 · 4/6") ~= nil)
press(fr:FindFirstChild("Join_55", true))
check("JOIN sent", sent("JoinFriend") and sent("JoinFriend").args[1] == 55)
serverSends("FriendResult", { kind = "full", name = "Cal", every = 15 })
local fullCard = panels:FindFirstChild("Card_full")
check("a full server: the card", fullCard ~= nil and textIn(fullCard, "full") ~= nil)
click(fullCard, "WAIT FOR A SPOT")
check("retry sent", sent("FriendAction") and sent("FriendAction").args[1] == "retry")
serverSends("FriendResult", { kind = "waiting", name = "Cal", tries = 2, max = 8 })
check("waiting shows in the panel", textIn(panels.Panel_friends, "try 2/8") ~= nil)
click(panels.Panel_friends, "PRIVATE RUN")
check("private run sent", sent("FriendAction").args[1] == "private")
click(panels.Panel_friends, "INVITE")
check("the invite prompt", Engine.invites >= 1)
serverSends("FriendResult", { kind = "rejoin", night = 4, crew = 5, max = 6 })
local rejoin = panels:FindFirstChild("Card_rejoin")
check("the rejoin card", rejoin ~= nil and textIn(rejoin, "night 4") ~= nil)
click(rejoin, "REJOIN")
check("rejoin sent", sent("FriendAction").args[1] == "rejoin")
press(panels.Panel_friends.Head.Close)

-- 21. MORE: settings ------------------------------------------------------------------------------------------------------------------------------------------
press(hud.Menu.Menu_settings)
Engine.advance(0.1)
local more = panels:FindFirstChild("Panel_settings")
check("MORE opens", more ~= nil)
check("how to play", more and textIn(more, "SIX... SEVEN!") ~= nil)
press(more:FindFirstChild("Toggle_music", true))
check("music off sent", sent("Settings") and sent("Settings").args[1] == "music" and sent("Settings").args[2] == false)
Engine.advance(0.6)
local _, vol = Audio.wanted()
check("music volume 0", vol == 0)
more = panels:FindFirstChild("Panel_settings")
check("the toggle shows OFF", more and more:FindFirstChild("Toggle_music", true).Text == "OFF")
press(more:FindFirstChild("Emote_67", true))
check(
	"the 6-7 from MORE",
	sent("Emote") and sent("Emote").args[1] == "67" and panels:FindFirstChild("Panel_settings") == nil
)
Engine.advance(0.1)
check("everyone sees it", Anim.recs[player.Character] and Anim.recs[player.Character].emote == "67")

-- 22. The ping wheel ---------------------------------------------------------------------------------------------------------------------------------------------
check("to the next run's day", skipTo("day"))
Engine.advance(2)
press(actions.Ping)
local wheel = actions:FindFirstChild("Pings")
check("the ping wheel", wheel ~= nil)
click(wheel, "KERMY!")
check("ping sent", sent("Ping") and sent("Ping").args[1] == "kermy")
Engine.advance(0.3)
check("a beacon in the world", textIn(ws.Fx, "KERMY!") ~= nil)
Engine.fireServer(ben, "Ping", "help", pos() + Vector3.new(20, 0, 0))
Engine.advance(0.3)
check("ben's ping: a toast", textIn(hud, "Ben: Help me!") ~= nil)

-- 23. Feedback -------------------------------------------------------------------------------------------------------------------------------------------------
serverSends("Ask", { kind = "feedback" })
local fb = panels:FindFirstChild("Card_feedback")
check("the feedback card", fb ~= nil)
click(fb, "NOT REALLY")
check("the reasons", fb and fb:FindFirstChild("Reason_" .. Constants.DISLIKE_REASONS[1][1]) ~= nil)
press(fb["Reason_" .. Constants.DISLIKE_REASONS[1][1]])
press(fb.Send)
local f = sent("Feedback")
check(
	"feedback sent with the reason",
	f and f.args[1] == false and f.args[3] and f.args[3][1] == Constants.DISLIKE_REASONS[1][1]
)
serverSends("Ask", { kind = "thanks", like = false })
check("the thanks card", panels:FindFirstChild("Card_thanks") ~= nil)
click(panels.Card_thanks, "OK")

-- 24. Waiting for the next run (the roster is locked) -----------------------------------------------------------------------------------------------------------
serverSends(
	"Run",
	{ phase = "night", day = 3, night = 3, roster = {}, votes = { difficulty = {}, bell = 0, need = 0 } }
)
serverSends("Me", { status = "waiting", hp = 100, maxHp = 100, stamina = 100, staminaMax = 100, buffs = {} })
ws:SetAttribute("Phase", "night")
ws:SetAttribute("Night", 3)
Engine.advance(0.3)
check(
	"the waiting card",
	refs.out.Visible == true and string.find(refs.outTitle.Text, "RUN IS UNDERWAY", 1, true) ~= nil,
	refs.outTitle.Text
)
check("next run soon", string.find(refs.phase.Text, "NEXT RUN", 1, true) ~= nil, refs.phase.Text)
press(refs.newRun)
check("FIND A NEW RUN", sent("FriendAction").args[1] == "newrun")
Run:Broadcast()
Survivors:Push(player)
Engine.advance(0.5)

-- 25. Analytics ------------------------------------------------------------------------------------------------------------------------------------------------
Engine.advance(61)
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
check("analytics: taps", seen.ui and seen.ui.taps and next(seen.ui.taps) ~= nil)
check("analytics: named actions", seen.ui and (function()
	for k in seen.ui.taps do
		if string.sub(k, 1, 1) == "@" then
			return true
		end
	end
	return false
end)())
check("analytics: frame rate", seen.perf and seen.perf.fps ~= nil and seen.perf.lite == true)

print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
for i = 1, math.min(5, #Engine.errors) do
	print("ERROR " .. tostring(Engine.errors[i]))
end
for i = 1, math.min(5, #Engine.warnings) do
	print("WARN " .. tostring(Engine.warnings[i]))
end
if failed > 0 or #Engine.errors > 0 or #Engine.warnings > 0 then
	error("client smoke test failed")
end

--[[
Client smoke test: builds the real world, boots the real client scripts on the mock engine as a phone-sized
screen, feeds them every server → client event (profile, expedition phases, bag, guide, hall, friends, recovery,
cards), presses every HUD button, opens every panel, gives, builds, and checks the prompts, the travel scenery,
the stop sliding in, the door guide and the left-behind screen.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
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
local Layout = Engine.require(tree.shared.World.Layout)
Net.init() -- the server normally creates the remotes
-- the world, built the way the server builds it (the train, the recovery hut, the station beside the train)
local World = Engine.require(tree.server.World.WorldBuilder)
World.build()
local layout = World.layout
layout.station.model.Parent = layout.scenery
local ws = Engine.workspace
ws:SetAttribute("Phase", "lobby")
ws:SetAttribute("PhaseEnds", 0)
ws:SetAttribute("Doors", "open")
-- the server's prompts (CabinService / TrainService / ResourceService make these)
local function addPrompt(parent, name, attrs)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end
local buildSpot = Instance.new("Part", layout.train.cabins[1].model)
buildSpot.Name = "BuildSpot"
buildSpot.CFrame = Layout.cabins[1].cf * CFrame.new(0, 3.5, 0)
local myBuild = addPrompt(buildSpot, "Prompt_build", { OwnerUserId = 7 })
local otherSpot = Instance.new("Part", layout.train.cabins[2].model)
otherSpot.Name = "BuildSpot"
local theirBuild = addPrompt(otherSpot, "Prompt_build", { OwnerUserId = 99 })
local trainPrompt = addPrompt(layout.train.upgradeBoardPart, "Prompt_train")
-- the fuses in the grass round the signal hut (RecoveryService makes them)
for i, cf in layout.recovery.fuseSpots do
	local fuse = Instance.new("Part", layout.recovery.model)
	fuse.Name = "Fuse"
	fuse.CFrame = cf
	fuse:SetAttribute("Fuse", i)
	addPrompt(fuse, "Prompt_fuse")
end

Engine.side = "client"
-- a phone in landscape: 844 x 390
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false

local player = Engine.addPlayer("Ava", 7)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
player:SetAttribute("Cabin", 1)
Engine.moveTo(player, Layout.STATION_SPAWN.Position)
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

local hud = gui:FindFirstChild("Hud")
check("HUD built", hud ~= nil)
check("phone scale applied", math.abs(hud.Scale.Scale - 390 / 560) < 0.01, hud.Scale.Scale)
check("landscape on phones", gui.ScreenOrientation ~= nil)
check(
	"five buttons",
	hud.Buttons.cabin and hud.Buttons.build and hud.Buttons.train and hud.Buttons.friends and hud.Buttons.hall
)

-- The profile and the expedition ---------------------------------------------------------------------------------
serverSends("Profile", {
	storage = { wood = 3, scrap = 7, parts = 2, cloth = 1 },
	blueprints = { map = 1 },
	cabin = { built = {}, variants = {}, color = nil },
	cabinIndex = 1,
	souvenirs = {},
	visited = {},
	best = 0,
	records = {},
	train = {
		upgrades = {
			{ key = "engine", stage = 0, total = 3, given = { scrap = 2 }, missing = { scrap = 8, parts = 4 } },
			{ key = "lamp", stage = 0, total = 2, given = {}, missing = { scrap = 8, parts = 3, cloth = 3 } },
		},
		fuel = 4,
		cost = 2,
	},
})
serverSends("Bag", { items = {}, plans = {}, count = 0, cap = 12 })
serverSends("Expedition", {
	phase = "lobby",
	code = "AB12",
	fuel = 4,
	cost = 2,
	distance = 0,
	rate = 0,
	region = "Overgrown Line",
	upgrades = {},
})
Engine.advance(0.3)
check("board: boarding", string.find(hud.Board.Timer.Text, "BOARDING", 1, true) ~= nil, hud.Board.Timer.Text)
check(
	"board: fuel and distance",
	string.find(hud.Board.Info.Text, "⛽ 4 / trip 2", 1, true) ~= nil,
	hud.Board.Info.Text
)
check("bag: empty", string.find(hud.Bag.Title.Text, "0/12", 1, true) ~= nil and hud.Bag.Items.Text == "empty")
check(
	"storage line",
	string.find(hud.Bag.Storage.Text, "🔩7", 1, true) ~= nil
		and string.find(hud.Bag.Storage.Text, "📜1", 1, true) ~= nil,
	hud.Bag.Storage.Text
)
check("BUILD dot: the bunk isn't affordable yet (cloth 1/2)", hud.Buttons.build.Dot.Visible == false)
check("TRAIN dot: you have scrap the engine needs", hud.Buttons.train.Dot.Visible == true)
-- the countdown
ws:SetAttribute("PhaseStarted", Engine.now())
ws:SetAttribute("PhaseEnds", Engine.now() + 40)
Engine.advance(0.3)
check(
	"board: departs in 0:39",
	string.find(hud.Board.Headline.Text, "DEPARTS IN", 1, true) ~= nil
		and string.find(hud.Board.Timer.Text, "0:3", 1, true) ~= nil,
	hud.Board.Timer.Text
)

-- Prompts: only your own cabin's ---------------------------------------------------------------------------------
Engine.advance(2.2)
check("my cabin's BUILD prompt shows", myBuild.Enabled == true)
check("someone else's is hidden", theirBuild.Enabled == false)
Engine.setProperty(theirBuild, "Enabled", true) -- the server turned it on when they moved in
Engine.advance(0.05)
check("...and stays hidden", theirBuild.Enabled == false)

-- Panels ------------------------------------------------------------------------------------------------------------
local panels = gui:FindFirstChild("Panels")
check("panels screen", panels ~= nil)
hud.Buttons.build.Activated:Fire()
Engine.advance(0.1)
local panel = panels.Panel
check(
	"BUILD panel opens",
	panel.Visible and string.find(panel.Title.Text, "MY CABIN", 1, true) ~= nil,
	panel.Title.Text
)
check("viewed: build", sent("Viewed") and sent("Viewed").args[1] == "build")
check("next upgrade first: the bunk", panel.Body:FindFirstChild("Item_bunk") ~= nil)
check("bunk: not enough materials (says what's missing)", textIn(panel.Body.Item_bunk, "Not enough materials") ~= nil)
check("costs show have/need", textIn(panel.Body.Item_bunk, "4/4") ~= nil and textIn(panel.Body.Item_bunk, "1/2") ~= nil)
check("where to find cloth", textIn(panel.Body.Item_bunk, "Ranger Station") ~= nil)
check("a preview of the next upgrade in my cabin", ws:FindFirstChild("CabinGhost") and #ws.CabinGhost:GetChildren() > 0)
check("locked items say why", textIn(panel.Body.Item_lamp, "Build Bunk first") ~= nil)
check("map board needs plans: she has them", textIn(panel.Body.Item_mapboard, "Map Board plans ✔") ~= nil)
click(panel.Body.Colors, "Teal")
check("colour sent", sent("SetColor") and sent("SetColor").args[1] == "teal")
serverSends("Profile", { cabin = { built = {}, variants = {}, color = "teal" } })
Engine.advance(0.1)
check("colour ticked", textIn(panel.Body.Colors, "TEAL ✔") ~= nil)
-- enough for the bunk now
serverSends("Profile", { storage = { wood = 3, scrap = 7, parts = 2, cloth = 2 } })
Engine.advance(0.1)
check("BUILD dot lights up", hud.Buttons.build.Dot.Visible == true)
click(panel.Body.Item_bunk, "Build")
check("build sent", sent("Build") and sent("Build").args[1] == "bunk")
serverSends("Profile", {
	cabin = { built = { bunk = true }, variants = {}, color = "teal" },
	storage = { wood = 3, scrap = 3, parts = 2, cloth = 0 },
})
Engine.advance(0.1)
check("bunk shows built", textIn(panel.Body, "BUILT ✔") ~= nil)
check(
	"the next upgrade is the lamp",
	panel.Body:FindFirstChild("Item_lamp") and textIn(panel.Body, "Next upgrade") ~= nil
)
-- a built finish changes look for free
serverSends("Profile", {
	cabin = {
		built = {
			bunk = true,
			lamp = true,
			crate = true,
			bench = true,
			worksurface = true,
			workbench = true,
			finish = true,
		},
		variants = { finish = "oak" },
		color = "teal",
	},
})
Engine.advance(0.1)
click(panel.Body.Item_finish, "Forest Green")
check("restyle sent", sent("Build") and sent("Build").args[1] == "finish" and sent("Build").args[2] == "forest")
check("salvage at the workbench", panel.Body:FindFirstChild("Salvage") ~= nil)
click(panel.Body.Salvage, "Salvage")
check("salvage sent", sent("Salvage") ~= nil)

-- TRAIN
hud.Buttons.train.Activated:Fire()
Engine.advance(0.1)
check("TRAIN panel", string.find(panel.Title.Text, "THE TRAIN", 1, true) ~= nil)
check("fuel line", textIn(panel.Body, "next trip needs 2") ~= nil)
check("the choice is explained", textIn(panel.Body, "Your materials are yours") ~= nil)
local engineRow = panel.Body:FindFirstChild("Upgrade_engine")
check("engine upgrade row", engineRow ~= nil and textIn(engineRow, "Overhaul I") ~= nil)
check("scrap 2/10 given", textIn(engineRow, "2/10") ~= nil)
engineRow.Res_scrap.Buttons:FindFirstChild("Give_scrap_1").Activated:Fire()
Engine.advance(0.05)
local dep = sent("Deposit")
check("give +1 scrap", dep and dep.args[1] == "engine" and dep.args[2] == "scrap" and dep.args[3] == 1)
check("give parts disabled with none", engineRow.Res_parts.Buttons:FindFirstChild("Give_parts_1").Active == true) -- she has 2 parts

-- FRIENDS
Engine.friendsOnline = {
	{
		VisitorId = 55,
		UserName = "zed",
		DisplayName = "Zed",
		PlaceId = Engine.game.PlaceId,
		GameId = "job-1",
		LocationType = 4,
	},
	{ VisitorId = 56, UserName = "yan", DisplayName = "Yan", PlaceId = 12345, GameId = "job-x", LocationType = 4 },
}
hud.Buttons.friends.Activated:Fire()
Engine.advance(0.2)
check("FRIENDS panel", string.find(panel.Title.Text, "FRIENDS", 1, true) ~= nil)
check(
	"asked the server about friends' trains (this game only)",
	sent("Friends") and #sent("Friends").args[1] == 1 and sent("Friends").args[1][1].jobId == "job-1"
)
check(
	"Zed listed, not Yan",
	panel.Body:FindFirstChild("Friend_55") ~= nil and panel.Body:FindFirstChild("Friend_56") == nil
)
serverSends("Friends", { { userId = 55, phase = "traveling", km = 12.5, crew = 5, max = 20, code = "ZZ" } })
Engine.advance(0.1)
check(
	"friend's train status",
	textIn(panel.Body.Friend_55, "12.5 km") ~= nil and textIn(panel.Body.Friend_55, "5/20") ~= nil
)
click(panel.Body.Friend_55, "Join")
check("join sent", sent("JoinFriend") and sent("JoinFriend").args[1] == 55)
click(panel.Body, "Invite friends")
check("invite prompt", Engine.invites == 1)
-- Train Full
serverSends("FriendResult", { kind = "full", name = "Zed", userId = 55, max = 8, every = 15 })
local full = panels:FindFirstChild("TrainFull")
check("Train Full card", full ~= nil and textIn(full, "no free seats") ~= nil)
check(
	"three choices",
	findButton(full, "Wait for a spot")
		and findButton(full, "Join another friend")
		and findButton(full, "Start a new expedition")
)
click(full, "Wait for a spot")
check("retry sent", sent("FriendAction") and sent("FriendAction").args[1] == "retry")
serverSends("FriendResult", { kind = "waiting", name = "Zed", tries = 1, max = 8, wait = 15 })
local waiting = panels:FindFirstChild("Waiting")
check(
	"waiting card: honest, no queue position",
	waiting and textIn(waiting, "try 2 of 8") and textIn(waiting, "isn't a queue")
)
click(waiting, "Stop waiting")
check("cancel sent", sent("FriendAction").args[1] == "cancel")
serverSends("FriendResult", { kind = "failed", stillFull = true, name = "Zed", text = "Zed's train is still full." })
check("still full: other options", panels:FindFirstChild("StillFull") ~= nil)
click(panels.StillFull, "Start a new expedition")
check("new expedition sent", sent("FriendAction").args[1] == "new")
serverSends("FriendResult", { kind = "rejoin", code = "QQ", km = 7.5, crew = 4, max = 20 })
check("rejoin card", panels:FindFirstChild("Rejoin") and textIn(panels.Rejoin, "#QQ"))
click(panels.Rejoin, "Rejoin my train")
check("rejoin sent", sent("FriendAction").args[1] == "rejoin")
serverSends("FriendResult", { kind = "here", name = "Ben", cabin = 2 })
check("friend here: toast", textIn(hud.Toasts, "Ben is on this train") ~= nil)

-- HALL
serverSends("Hall", {
	rule = "Full crew: aboard for 2 stops or 5 minutes.",
	records = {
		{
			rank = 1,
			code = "AB12",
			km = 22.5,
			stops = 9,
			seconds = 2100,
			at = 1700000000,
			crew = { { userId = 7, name = "Ava" }, { userId = 8, name = "Ben" } },
			crewCount = 2,
			helpers = 1,
			recognition = { fuel = { name = "Ava", amount = 4 } },
			train = { engine = 2, lamp = 1 },
			live = false,
			route = { "ranger", "timber" },
		},
		{
			rank = 2,
			code = "CD34",
			km = 10,
			stops = 4,
			seconds = 900,
			at = 1700000000,
			crew = { { userId = 9, name = "Cy" } },
			crewCount = 1,
			train = {},
			live = true,
		},
	},
})
serverSends(
	"Profile",
	{ best = 22.5, records = { { id = "x", code = "AB12", km = 22.5, stops = 9, at = 1700000000 } } }
)
hud.Buttons.hall.Activated:Fire()
Engine.advance(0.1)
check("HALL panel", string.find(panel.Title.Text, "HALL OF RECORDS", 1, true) ~= nil)
check(
	"top record",
	textIn(panel.Body.Record_1, "22.5 km")
		and textIn(panel.Body.Record_1, "Ava, Ben")
		and textIn(panel.Body.Record_1, "most fuel")
)
check("train config", textIn(panel.Body.Record_1, "Overhaul II") ~= nil)
check("still on the line", textIn(panel.Body.Record_2, "still on the line") ~= nil)
check("the rule is shown", textIn(panel.Body, "aboard for 2 stops") ~= nil)
check("your journeys", textIn(panel.Body, "Best distance: 22.5") ~= nil)
-- inspecting a plaque opens the hall at that record
local plaquePrompt = addPrompt(layout.station.hall.plaques[1].Parent.Parent, "Prompt_record", { Rank = 2 })
Engine.game:GetService("ProximityPromptService").PromptTriggered:Fire(plaquePrompt, player)
Engine.advance(0.1)
check("plaque prompt: hall focused on #2", string.find(panel.Title.Text, "HALL", 1, true) ~= nil)
-- the engine board opens TRAIN
Engine.game:GetService("ProximityPromptService").PromptTriggered:Fire(trainPrompt, player)
Engine.advance(0.1)
check("board prompt opens TRAIN", string.find(panel.Title.Text, "THE TRAIN", 1, true) ~= nil)
click(panel, "✕")
check("panel closes", panel.Visible == false)

-- Late join summary ----------------------------------------------------------------------------------------------
serverSends("Summary", {
	code = "AB12",
	phase = "scavenging",
	stop = "Timber Yard",
	distance = 5,
	nextMilestone = 10,
	fuel = 2.4,
	cost = 1.6,
	goal = "Overhaul I",
	timeLeft = 95,
	crew = 6,
})
local summary = hud:FindFirstChild("Summary")
check(
	"late join card",
	summary
		and textIn(summary, "At Timber Yard")
		and textIn(summary, "next milestone 10 km")
		and textIn(summary, "1:35")
)
click(summary, "Got it")
check("card dismissed", hud:FindFirstChild("Summary") == nil)

-- A stop ------------------------------------------------------------------------------------------------------------
local Travel = Engine.require(tree.client.Controllers.TravelController)
ws:SetAttribute("Phase", "departing")
ws:SetAttribute("PhaseStarted", Engine.now())
ws:SetAttribute("PhaseEnds", Engine.now() + 2)
serverSends(
	"Expedition",
	{ phase = "departing", code = "AB12", fuel = 4, cost = 2, distance = 0, rate = 0, upgrades = {} }
)
Engine.advance(0.3)
check("board: all aboard (red)", string.find(hud.Board.Headline.Text, "ALL ABOARD", 1, true) ~= nil)
-- traveling: the forest goes past
layout.station.model.Parent = layout.templates
ws:SetAttribute("Phase", "traveling")
ws:SetAttribute("PhaseStarted", Engine.now())
ws:SetAttribute("PhaseEnds", Engine.now() + Constants.TRAVEL_SECONDS)
serverSends("Expedition", {
	phase = "traveling",
	phaseStarted = Engine.now(),
	fuel = 2,
	cost = 2,
	distance = 0,
	rate = Constants.SEGMENT_KM / Constants.TRAVEL_SECONDS,
	nextStop = { key = "timber", name = "Timber Yard" },
	upgrades = {},
})
Engine.advance(3)
local st = Travel.state()
check("travel scenery built and moving", st.shown and st.chunks > 0 and st.speed > 10, `{st.speed}`)
check("board: next stop", string.find(hud.Board.Timer.Text, "TIMBER YARD", 1, true) ~= nil, hud.Board.Timer.Text)
check("distance grows", string.find(hud.Board.Info.Text, "🚂 0.2", 1, true) ~= nil, hud.Board.Info.Text)
local chunk = ws.TravelScenery:FindFirstChild("Chunk1017")
local sleeper = chunk and chunk:FindFirstChild("Sleeper")
local x0 = sleeper and sleeper.Position.X
Engine.advance(0.5)
check("scenery streams backwards", sleeper and sleeper.Position.X < x0, sleeper and sleeper.Position.X)
-- announcements and the milestone
serverSends("Announce", "Next stop: Timber Yard.", "chime")
check(
	"announcement subtitle",
	hud.Announce.Visible and string.find(hud.Announce.Text.Text, "Timber Yard", 1, true) ~= nil
)
serverSends("Milestone", { km = 10 })
check("milestone banner", hud.Milestone.Visible and hud.Milestone.Big.Text == "10 KM")
-- arriving: the stop appears and slides in
ws:SetAttribute("Phase", "arriving")
ws:SetAttribute("PhaseStarted", Engine.now())
ws:SetAttribute("PhaseEnds", Engine.now() + Constants.ARRIVE_SECONDS)
Engine.advance(2)
check("braking", Travel.state().speed < 70)
local stop = layout.stops.timber:Clone()
stop.Parent = layout.scenery
Engine.advance(0.4)
check("the stop slides in", Travel.state().slide == true)
check("fade masks the cut", gui.Fade.Black.Visible == true)
Engine.advance(3)
check("the stop comes to rest", Travel.state().slide == false)
-- scavenging: piles you took disappear, the bag fills
local nodeModel
for _, m in stop:GetDescendants() do
	if m.ClassName == "Model" and m:GetAttribute("Node") == "scrap" then
		nodeModel = m
		break
	end
end
nodeModel:SetAttribute("NodeId", "n1")
local np = addPrompt(nodeModel.PrimaryPart, "Prompt_node", { NodeId = "n1" })
np.ObjectText = "Scrap"
ws:SetAttribute("Phase", "scavenging")
ws:SetAttribute("PhaseStarted", Engine.now())
ws:SetAttribute("PhaseEnds", Engine.now() + 150)
serverSends("Expedition", {
	phase = "scavenging",
	fuel = 1,
	cost = 2,
	distance = 2.5,
	rate = 0,
	stop = { key = "timber", name = "Timber Yard" },
	goal = { key = "fuel", text = "Find fuel cans! Fuel 1 · next trip needs 2", progress = 0.5 },
	upgrades = {},
})
Engine.advance(2.5)
check(
	"board: doors close in 2:2x",
	string.find(hud.Board.Headline.Text, "DOORS CLOSE IN", 1, true) ~= nil
		and string.find(hud.Board.Timer.Text, "2:2", 1, true) ~= nil,
	hud.Board.Timer.Text
)
check("crew goal: fuel", hud.Goal.Visible and string.find(hud.Goal.Title.Text, "FUEL", 1, true) ~= nil)
check("scenery hidden at the stop", Travel.state().shown == false)
Engine.moveTo(player, nodeModel.PrimaryPart.Position + Vector3.new(0, 3, 4))
serverSends("Popup", nodeModel.PrimaryPart.Position, "+2 🔩", nil)
check("popup in the world", ws:FindFirstChild("PopupAnchor") ~= nil)
serverSends("Bag", { items = { scrap = 2 }, plans = {}, count = 2, cap = 12 })
serverSends("Nodes", { taken = { "n1" } })
Engine.advance(0.3)
check("bag shows it", string.find(hud.Bag.Items.Text, "🔩 2", 1, true) ~= nil)
check("bag: not saved until aboard (outside)", hud.Bag.Hint.Visible == true)
check("taken pile hidden for me", nodeModel.PrimaryPart.Transparency == 1 and np.Enabled == false)
-- the tool rack makes collecting faster
serverSends("Profile", { cabin = { built = { bunk = true, toolrack = true }, variants = {}, color = "teal" } })
Engine.advance(0.1)
local np2 = addPrompt(nodeModel.PrimaryPart, "Prompt_node", { NodeId = "n2" })
np2.ObjectText = "Scrap"
Engine.advance(2.2)
check("tool rack: shorter hold", math.abs(np2.HoldDuration - Constants.TOOLRACK_HOLD) < 1e-6, np2.HoldDuration)
-- the guide
local target = layout.train.upgradeBoardPart
serverSends(
	"Tutorial",
	{ step = 6, total = 7, key = "train", text = "Give some materials at the TRAIN board.", target = target }
)
local guide = gui.Guide
check(
	"guide card",
	guide.Card.Visible
		and string.find(guide.Card.Text.Text, "TRAIN board", 1, true) ~= nil
		and string.find(guide.Card.Step.Text, "6 OF 7", 1, true) ~= nil
)
Engine.advance(0.3)
check("guide line to the target", ws:FindFirstChild("GuideBeam") and ws.GuideBeam.Enabled == true)
click(guide, "Skip guide")
check("skip sent", sent("SkipTutorial") ~= nil and guide.Card.Visible == false)
-- the final call: red edges and a line to the nearest door
ws:SetAttribute("Phase", "warning")
ws:SetAttribute("Final", true)
ws:SetAttribute("PhaseEnds", Engine.now() + 15)
Engine.advance(0.5)
check("board: final call", string.find(hud.Board.Headline.Text, "FINAL CALL", 1, true) ~= nil)
check("red edges while outside", hud.Edges.Visible == true)
check("a line to the nearest door", ws:FindFirstChild("DoorGuide") and ws.DoorGuide.DoorBeam.Enabled == true)
Engine.moveTo(player, Layout.ENTRY_CF.Position)
Engine.advance(0.5)
check("aboard: no edges, no line", hud.Edges.Visible == false and ws.DoorGuide.DoorBeam.Enabled == false)
-- the beacons blink while the doors close
ws:SetAttribute("Doors", "closing")
local beacon
for _, d in layout.train.model:GetDescendants() do
	if d:GetAttribute("Beacon") then
		beacon = d
		break
	end
end
local seen = {}
for _ = 1, 8 do
	Engine.advance(0.12)
	seen[beacon.Transparency] = true
end
check("door beacons blink", seen[0] and seen[0.8])
ws:SetAttribute("Doors", "open")

-- Left behind ------------------------------------------------------------------------------------------------------
serverSends("Recovery", {
	step = "fuses",
	found = 1,
	need = 3,
	taken = { 1 },
	text = "The train left without you! Find 3 fuses in the grass around the hut. (1/3)",
})
Engine.moveTo(player, layout.recovery.spawn.Position)
Engine.advance(0.4)
local rec = gui.Recovery.Card
check("left-behind card", rec.Visible and string.find(rec.Count.Text, "1/3", 1, true) ~= nil)
check("the board makes way", hud.Board.Visible == false)
check("night lighting here", Engine.game:GetService("Lighting").ClockTime ~= nil)
local fuse1
for _, d in layout.recovery.model:GetDescendants() do
	if d:GetAttribute("Fuse") == 1 then
		fuse1 = d
	end
end
check("a taken fuse disappears", fuse1 and fuse1.Transparency == 1)
check("a line to the next fuse", ws:FindFirstChild("RecoveryTarget") and ws.RecoveryTarget.RecoveryBeam.Enabled == true)
serverSends(
	"Recovery",
	{ step = "waiting", found = 3, need = 3, taken = { 1, 2, 3 }, text = "Signal sent!", pickupAt = Engine.now() + 40 }
)
Engine.advance(0.4)
check("pickup countdown", string.find(rec.Count.Text, "Pickup in 0:3", 1, true) ~= nil, rec.Count.Text)
serverSends("Recovery", false)
Engine.advance(0.4)
check("back: card gone, board back", rec.Visible == false and hud.Board.Visible == true)

-- Toasts, alerts, fade, feedback ----------------------------------------------------------------------------------
serverSends("Toast", "Banked: +2 🔩", "good")
check("toast", textIn(hud.Toasts, "Banked") ~= nil)
for i = 1, 5 do
	serverSends("Toast", "toast " .. i, "info")
end
local n = 0
for _, c in hud.Toasts:GetChildren() do
	if c.Name == "Toast" then
		n += 1
	end
end
check("at most 3 toasts", n <= 3, n)
serverSends("Alert", "You're part of the crew!", nil)
check("alert", hud.Alert.Visible and string.find(hud.Alert.Text.Text, "crew", 1, true) ~= nil)
serverSends("Fade", 1, "Back on the train!")
check("fade with text", gui.Fade.Black.Visible and gui.Fade.Black.Text.Text == "Back on the train!")
serverSends("Ask", { kind = "feedback" })
local fb = panels:FindFirstChild("Feedback")
check("feedback card", fb ~= nil)
click(fb, "Not really")
check("dislike reasons", textIn(fb, "The train leaves too fast") ~= nil)
click(fb, "The train leaves too fast")
click(fb, "Send")
local f = sent("Feedback")
check("feedback sent with reason", f and f.args[1] == false and f.args[3][1] == "timer")
serverSends("Sfx", "pickup", Vector3.new(0, 5, 0))
check("3D sound", ws:FindFirstChild("Sfx_pickup") ~= nil)

-- Every button press is counted for analytics -----------------------------------------------------------------
Engine.advance(21)
local a = sent("Analytics")
check("analytics: taps batched", a ~= nil)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
check("no warnings", #Engine.warnings == 0, Engine.warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("client smoke test failed")
end

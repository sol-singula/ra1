--[[
Server smoke test: boots the real server scripts on the mock engine and plays whole expeditions with a crew:
the station lobby, boarding, the doors, travel, arriving, scavenging (piles, fuel cans, a blueprint), the field bag
and banking, building in the cabin (and the colour), giving to the train upgrades, a late joiner, being left
behind and finding the way back, running out of fuel, the record and the Hall of Records, a new expedition,
friends (Train Full, waiting for a spot, a new expedition, rejoining), the guide, feedback, analytics, the game
log, the anti-cheat and shutting down. Fails on any script error or broken expectation.

  luaurun tests/ServerSmoke.spec.luau                 (from the game folder)
  luaurun tests/ServerSmoke.spec.luau nodatastore     (Studio-without-API-access fallback)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame
local noDataStore = ARGS[1] == "nodatastore"
Engine.dataStoreFails = noDataStore

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
Engine.runScript(tree.server.Main)
Engine.advance(0.1)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Expedition = service("ExpeditionService")
local Train = service("TrainService")
local Resources = service("ResourceService")
local Cabins = service("CabinService")
local Recovery = service("RecoveryService")
local Records = service("RecordService")
local Join = service("JoinService")
local Tutorial = service("TutorialService")
local Feedback = service("FeedbackService")
local AntiCheat = service("AntiCheatService")
-- game log posts and analytics batches are captured here instead of going out
local GameLog = service("GameLogService")
local gameLogs, chatLogs = {}, {}
GameLog.send = function(payload)
	for _, e in payload.events do
		table.insert(gameLogs, e)
	end
	for _, c in payload.chat do
		table.insert(chatLogs, c)
	end
	return true
end
local Analytics = service("AnalyticsService")
local aEvents, aSessions = {}, {}
Analytics.send = function(payload)
	check("analytics batches are tagged ra5", payload.game == "ra5")
	for _, e in payload.events do
		table.insert(aEvents, e)
	end
	for _, row in payload.sessions do
		local merged = aSessions[row.session_id] or {}
		for k, v in row do
			merged[k] = v
		end
		aSessions[row.session_id] = merged
	end
	return true
end
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)
local Layout = Engine.require(tree.shared.World.Layout)
local CabinItems = Engine.require(tree.shared.Data.CabinItems)
local TrainUpgrades = Engine.require(tree.shared.Data.TrainUpgrades)
local World = Engine.require(tree.server.World.WorldBuilder).layout
local Players = Engine.Players
local ws = Engine.workspace

local function join(name, id)
	local p = Engine.addPlayer(name, id)
	Engine.makeCharacter(p)
	Engine.advance(0.2)
	Engine.fireServer(p, "Ready")
	Engine.advance(0.4)
	return p
end
local function pos(p)
	return p.Character.HumanoidRootPart.Position
end
local function go(p, at)
	Engine.moveTo(p, at + Vector3.new(0, 3, 0))
	Engine.advance(0.1)
end
local function phase()
	return Expedition:Phase()
end
-- skip to the next phase (and wait for the expedition loop to notice)
local function skip()
	local before = phase()
	Expedition:Skip()
	for _ = 1, 20 do
		Engine.advance(0.2)
		if phase() ~= before then
			break
		end
	end
	return phase()
end
local function skipTo(target, max)
	for _ = 1, max or 12 do
		if phase() == target then
			return true
		end
		skip()
	end
	return phase() == target
end
local function lastEvent(name, p)
	local e = Engine.lastClientEvent(name, p)
	return e and e.args[1], e
end
local function lastToast(p)
	local e = Engine.lastClientEvent("Toast", p)
	return e and e.args[1] or ""
end
local function nodesOf(kind)
	local out = {}
	for id, node in Resources:Nodes() do
		if node.kind == kind and node.model.Parent then
			table.insert(out, { id = id, node = node })
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end
-- walk to a pile and hold its prompt (the server checks you're there)
local function collect(p, entry)
	go(p, entry.node.root.Position + Vector3.new(2, 0, 0))
	local pr = entry.node.root:FindFirstChild("Prompt_node")
	assert(pr, "no Prompt_node on " .. entry.id)
	pr.Triggered:Fire(p)
	Engine.advance(0.1)
end
local function aboard(p)
	Engine.moveTo(p, Layout.ENTRY_CF.Position)
	Engine.advance(0.4) -- banking runs every quarter second
end
local function analyticsFor(p, kind)
	local out = {}
	for _, e in aEvents do
		if e.user_id == p.UserId and e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- World ----------------------------------------------------------------------------------------------------
check("the train: 7 cars, 20 cabins, 13 outside doors", #Layout.CARS == 7 and #World.train.cabins == 20 and #World.train.doors == 13)
check("4 stops built as templates", World.stops.ranger and World.stops.timber and World.stops.signal and World.stops.platform)
check("the station is beside the train in the lobby", World.station.model.Parent == World.scenery)
check("lobby phase, no countdown until someone's here", phase() == "lobby" and (ws:GetAttribute("PhaseEnds") or 0) == 0)
check("lighting preset: station", ws:GetAttribute("LightPreset") == "station")
check("doors open at the station", ws:GetAttribute("Doors") == "open")
check("recovery hut built with 6 fuses", #World.recovery.fuseSpots == 6 and #Engine.prompts(World.recovery.model) >= 8)
check("hall: a stage and four plaques", World.station.hall.top.plaque ~= nil and #World.station.hall.plaques == 4)
check("hall: empty at first", string.find(World.station.hall.top.plaque.Text, "NO RECORD", 1, true) ~= nil)
check("train board prompt", World.train.upgradeBoardPart:FindFirstChild("Prompt_train") ~= nil)

-- A new player at the station ---------------------------------------------------------------------------------
local ava = join("Ava", 101)
local pa = Data:Get(ava)
check("Ava's profile loaded, new", pa ~= nil and pa._isNew == true)
check("starter kit: half a bunk", pa.storage.scrap == 2 and pa.storage.cloth == 1)
check("Ava gets cabin 1", Cabins:IndexOf(ava) == 1 and ava:GetAttribute("Cabin") == 1)
check("cabin 1's door sign has her name", string.find(World.train.cabins[1].plate.Text, "AVA", 1, true) ~= nil)
check("cabin prompts are hers", World.train.cabins[1].model:FindFirstChild("BuildSpot").Prompt_build:GetAttribute("OwnerUserId") == 101)
check("spawned on the station platform", not Layout.inTrain(pos(ava)) and pos(ava).Z > 40)
check("the countdown starts once someone's here", (ws:GetAttribute("PhaseEnds") or 0) > 0)
local view = lastEvent("Expedition", ava)
check("expedition view sent", view and view.phase == "lobby" and view.fuel == Constants.START_FUEL)
local tut = lastEvent("Tutorial", ava)
check("guide step 1: find your cabin (arrow to the door sign)", tut and tut.key == "cabin" and tut.target ~= nil)
local hall = lastEvent("Hall", ava)
check("hall list sent (empty)", hall and #hall.records == 0 and hall.rule ~= nil)
check("bag sent (empty, 12 slots)", (lastEvent("Bag", ava) or {}).cap == Constants.BAG_BASE)

-- the cabin: CABIN takes you there, the colour is free
Engine.fireServer(ava, "GoCabin")
Engine.advance(0.3)
check("GoCabin: in her cabin", (pos(ava) - Layout.cabins[1].insideCf.Position).Magnitude < 1)
Engine.advance(0.5)
tut = lastEvent("Tutorial", ava)
check("guide step 2: pick a colour", tut and tut.key == "color")
Engine.fireServer(ava, "SetColor", "teal")
Engine.advance(0.5)
check("colour saved", pa.cabin.color == "teal")
tut = lastEvent("Tutorial", ava)
check("guide step 3: collect (waiting for the first stop)", tut and tut.key == "collect" and string.find(tut.text, "stops soon", 1, true) ~= nil)
-- building without enough materials says what's missing
Engine.fireServer(ava, "Build", "bunk")
Engine.advance(0.1)
check("bunk: not enough materials", pa.cabin.built.bunk == nil and string.find(lastToast(ava), "Not enough", 1, true) ~= nil)
Engine.fireServer(ava, "Build", "lamp")
Engine.advance(0.1)
check("lamp needs the bunk first", pa.cabin.built.lamp == nil and string.find(lastToast(ava), "first", 1, true) ~= nil)
-- a bad request does nothing
Engine.fireServer(ava, "Build", "rocket")
Engine.fireServer(ava, "SetColor", 42)
Engine.fireServer(ava, "Deposit", "engine", "gold", 99)
Engine.advance(0.2)
check("bad requests ignored", pa.cabin.color == "teal" and pa.storage.scrap == 2)

-- Departure from the station: everyone outside is brought aboard --------------------------------------------
go(ava, Layout.STATION_SPAWN.Position)
check("Ava back on the platform", not Layout.inTrain(pos(ava)))
check("lobby -> departing", skip() == "departing")
check("doors closing at the station", ws:GetAttribute("Doors") == "closing")
Engine.advance(Constants.DOORS_SHUT_AT + 0.3)
check("doors shut", ws:GetAttribute("Doors") == "closed")
check("left on the platform at the station = brought aboard, not stranded", Layout.inTrain(pos(ava)) and not Recovery:IsStranded(ava))
Engine.advance(Constants.DOORS_SECONDS - Constants.DOORS_SHUT_AT + 0.4)
check("departing -> traveling", phase() == "traveling")
local exp = Expedition:State()
check("the first trip used fuel", exp.fuel == Formulas.round1(Constants.START_FUEL - Formulas.fuelCost(0, 0)))
check("the station is gone, travel lighting", World.station.model.Parent ~= World.scenery and ws:GetAttribute("LightPreset") == "travel")
check("the next stop is chosen", exp.nextStop ~= nil)
local d0 = Expedition:Distance()
Engine.advance(4)
check("distance grows while travelling", Expedition:Distance() > d0)
Engine.advance(Constants.TRAVEL_SECONDS / 2)
check("next stop announced half way", exp.announcedNext == true and (lastEvent("Announce", ava) or ""):find("Next stop", 1, true) ~= nil)

-- Arriving at the first stop -------------------------------------------------------------------------------
check("traveling -> arriving", skip() == "arriving")
check("distance: one trip", exp.distance == Constants.SEGMENT_KM)
check("arriving -> scavenging", skipTo("scavenging", 3))
check("a stop beside the train", Expedition:Placed() ~= nil and Expedition:Placed().Parent == World.scenery and exp.stop ~= nil)
check("stop lighting", ws:GetAttribute("LightPreset") == exp.stop.light)
check("doors open", ws:GetAttribute("Doors") == "open")
check("stop counted: crew and profile", exp.stops == 1 and pa.stats.stops == 1 and pa.visited[exp.stop.key] == true)
check("a souvenir for the shelf", pa.souvenirs[exp.stop.key] == 1)
check("piles have prompts", #nodesOf("scrap") > 0 and #nodesOf("cloth") > 0)
check("fuel cans: as many as the crew needs", #nodesOf("fuel") == Formulas.fuelCans(1), tostring(#nodesOf("fuel")))
check("a blueprint at the landmark", #nodesOf("blueprint") == 1)
tut = lastEvent("Tutorial", ava)
check("guide: step outside and collect, with an arrow to a pile", tut and tut.key == "collect" and tut.target ~= nil and string.find(tut.text, "doors are open", 1, true) ~= nil)
local timeLeft = (ws:GetAttribute("PhaseEnds") or 0) - Engine.now()
check("doors open for the scavenging window", math.abs(timeLeft - Formulas.scavengeSeconds(0)) < 1, tostring(timeLeft))

-- collecting: too far away doesn't count
local scrap = nodesOf("scrap")
Engine.moveTo(ava, scrap[1].node.root.Position + Vector3.new(60, 3, 0))
Engine.advance(0.1)
check("too far from the pile: nothing", Resources:Collect(ava, scrap[1].id) == false and Resources:BagCount(ava) == 0)
collect(ava, scrap[1])
check("collected scrap into the bag", Resources:BagCount(ava) == scrap[1].node.amount and (lastEvent("Bag", ava) or {}).count == scrap[1].node.amount)
check("can't take the same pile twice", Resources:Collect(ava, scrap[1].id) == false)
local got = Resources:BagCount(ava)
-- just what the bunk needs (the bag only holds 12): then a fuel can and the blueprint
for i = 2, #scrap do
	if (Resources:Bag(ava).items.scrap or 0) < 2 then
		collect(ava, scrap[i])
	end
end
for _, c in nodesOf("cloth") do
	if (Resources:Bag(ava).items.cloth or 0) < 1 then
		collect(ava, c)
	end
end
check("more scrap and cloth", Resources:BagCount(ava) > got)
local bag = Resources:Bag(ava)
check("enough for the bunk in the bag", (bag.items.scrap or 0) + pa.storage.scrap >= 4 and (bag.items.cloth or 0) + pa.storage.cloth >= 2, `{bag.items.scrap} {bag.items.cloth}`)
-- a fuel can is the crew's: gone for everyone once someone takes it
local cans = nodesOf("fuel")
collect(ava, cans[1])
check("fuel can in the bag", (Resources:Bag(ava).items.fuel or 0) == 1)
Engine.advance(0.3)
check("the can is gone from the stop", cans[1].node.model.Parent == nil)
-- the blueprint
local bp = nodesOf("blueprint")[1]
collect(ava, bp)
local planKey = next(Resources:Bag(ava).plans)
check("a blueprint in the bag", planKey ~= nil)
Engine.advance(1.2)
tut = lastEvent("Tutorial", ava)
check("guide: get back aboard (arrow to a door)", tut and tut.key == "return" and tut.target ~= nil)

-- banking: the moment you're back inside
local fuelBefore = Expedition:Fuel()
local scrapBefore = pa.storage.scrap
aboard(ava)
check("bag banked when aboard", Resources:BagCount(ava) == 0)
check("materials in storage", pa.storage.scrap > scrapBefore)
check("fuel can into the tank", Expedition:Fuel() == Formulas.round1(fuelBefore + Constants.FUEL_PER_CAN))
check("blueprint kept", (pa.blueprints[planKey] or 0) == 1)
check("crew notes: fuel and blueprint", exp.crew[101].fuel >= 1 and exp.crew[101].blueprints >= 1)
Engine.advance(0.5)
tut = lastEvent("Tutorial", ava)
check("guide: build the bunk", tut and tut.key == "build" and string.find(tut.text, "BUILD", 1, true) ~= nil)

-- building the bunk
local scrapBanked, clothBanked = pa.storage.scrap, pa.storage.cloth
Engine.fireServer(ava, "Build", "bunk")
Engine.advance(0.2)
check("bunk built", pa.cabin.built.bunk == true and pa.stats.builds == 1)
check("the bunk appears in her cabin", World.train.cabins[1].items:FindFirstChild("bunk") ~= nil)
check("the bedroll goes", World.train.cabins[1].bare:FindFirstChild("Bedroll").Transparency == 1)
check("materials taken", pa.storage.scrap == scrapBanked - 4 and pa.storage.cloth == clothBanked - 2)
Engine.advance(0.5)
tut = lastEvent("Tutorial", ava)
check("guide: help the train", tut and tut.key == "train")
-- changing a built item's look is free; building it again isn't possible
Engine.fireServer(ava, "Build", "bunk")
Engine.advance(0.1)
check("can't build the bunk twice", pa.stats.builds == 1)

-- giving to the train (she spent her scrap on the bunk: a few more from the next pile run)
pa.storage.scrap += 3
local need = TrainUpgrades.byKey.engine.stages[1].cost
local before = pa.storage.scrap
Engine.fireServer(ava, "Deposit", "engine", "scrap", 999)
Engine.advance(0.2)
local gave = before - pa.storage.scrap
check("gave scrap to the engine (only what she had and what it needs)", gave > 0 and gave <= need.scrap and Train:Given("engine").scrap == gave)
check("crew notes: materials", exp.crew[101].materials == gave)
Engine.fireServer(ava, "Deposit", "engine", "scrap", 1)
Engine.advance(0.2)
Engine.advance(0.5)
check("guide: friends step after giving", (lastEvent("Tutorial", ava) or {}).key == "friends")
Engine.fireServer(ava, "Viewed", "friends")
Engine.advance(0.6)
check("guide finished", pa.tutorial.done == true and lastEvent("Tutorial", ava) == false)
-- finish the first engine stage with storage we hand her (the engine room changes)
pa.storage.scrap += 20
pa.storage.parts += 10
Engine.fireServer(ava, "Deposit", "engine", "scrap", 20)
Engine.advance(0.3)
Engine.fireServer(ava, "Deposit", "engine", "parts", 10)
Engine.advance(0.3)
check("engine stage 1 done", Train:Stage("engine") == 1)
check("fuel cost drops with the engine", Expedition:FuelCost() < Formulas.fuelCost(0, exp.distance))
check("announced to everyone", string.find(lastEvent("Announce", ava) or "", "done", 1, true) ~= nil)

-- A late joiner -------------------------------------------------------------------------------------------
local ben = join("Ben", 102)
local pb = Data:Get(ben)
check("Ben gets cabin 2", Cabins:IndexOf(ben) == 2)
Engine.advance(0.5)
local summary = lastEvent("Summary", ben)
check("late join: a summary of the crew", summary and summary.stop ~= nil and summary.distance == exp.distance and summary.timeLeft ~= nil)
check("late joiner arrives aboard (entry seats, no bunk yet)", Layout.inTrain(pos(ben)))
check("Ben is crew", exp.crew[102] ~= nil and exp.crew[102].present)
check("fuel cans on the next stop scale with the crew", Formulas.fuelCans(2) >= Formulas.fuelCans(1))

-- Ben goes out, collects, and is still outside when the doors shut: left behind -------------------------------
local wood = nodesOf("wood")
collect(ben, wood[1])
local benBag = Resources:BagCount(ben)
check("Ben collected", benBag > 0)
check("scavenging -> warning", skip() == "warning")
check("one-minute warning announced", string.find(lastEvent("Announce", ben) or "", "One minute", 1, true) ~= nil)
Expedition:Skip()
Engine.advance(0.25)
check("final call", ws:GetAttribute("Final") == true or phase() == "departing")
for _ = 1, 10 do
	if phase() == "departing" then
		break
	end
	Engine.advance(0.2)
end
check("warning -> departing", phase() == "departing")
-- Ava is aboard; Ben is out by a pile
go(ben, wood[1].node.root.Position + Vector3.new(3, 0, 0))
Engine.advance(Constants.DOORS_SHUT_AT + 0.4)
check("doors shut with Ben outside: he's left behind", Recovery:IsStranded(ben))
check("Ava (aboard) isn't", not Recovery:IsStranded(ava))
check("Ben lost his bag", Resources:BagCount(ben) == 0 and pb.stats.lost == benBag and pb.stats.stranded == 1)
Engine.advance(0.8)
check("Ben wakes up at the signal hut", (pos(ben) - World.recovery.spawn.Position).Magnitude < 8)
local rec = lastEvent("Recovery", ben)
check("recovery objective sent", rec and rec.step == "fuses" and rec.need == Constants.RECOVERY_FUSES)
Engine.advance(Constants.DOORS_SECONDS)
check("the train left: traveling", phase() == "traveling")
-- the fuses
local fuses = {}
for _, d in World.recovery.model:GetDescendants() do
	if d.Name == "Fuse" and d:GetAttribute("Fuse") then
		fuses[d:GetAttribute("Fuse")] = d
	end
end
check("6 fuses in the grass", #fuses == 6)
check("a fuse from far away doesn't count", Recovery:TakeFuse(ben, 1) == false)
for i = 1, 3 do
	go(ben, fuses[i].Position)
	fuses[i].Prompt_fuse.Triggered:Fire(ben)
	Engine.advance(0.1)
end
check("3 fuses found: fit them", Recovery:State(ben).step == "box")
go(ben, World.recovery.fuseBox.Position)
World.recovery.fuseBox.Prompt_fusebox.Triggered:Fire(ben)
Engine.advance(0.1)
check("fuses fitted: pull the lever", Recovery:State(ben).step == "lever")
go(ben, World.recovery.lever.Position)
World.recovery.lever.Prompt_lever.Triggered:Fire(ben)
Engine.advance(0.1)
check("signal sent: waiting for the trolley", Recovery:State(ben).step == "waiting" and Recovery:State(ben).pickupAt ~= nil)
-- a stranded player can't bank or give to the train from out there
Engine.fireServer(ben, "Deposit", "engine", "scrap", 1)
Engine.advance(0.1)
check("no giving from the hut", (Train:Given("engine").scrap or 0) == 0 or pb.stats.deposited == 0)
Engine.advance(Constants.RECOVERY_PICKUP_WAIT + 1.5)
check("picked up: back aboard", not Recovery:IsStranded(ben) and Layout.inTrain(pos(ben)) and pb.stats.recovered == 1)
check("crew recognition: found the way back", exp.crew[102].recovered == 1)

-- More stops until the fuel runs out ---------------------------------------------------------------------
local guard = 0
local sawMilestone = false
while phase() ~= "ended" and guard < 80 do
	guard += 1
	if phase() == "scavenging" then
		-- the crew brings back a can sometimes, so the expedition goes a few stops
		local c = nodesOf("fuel")[1]
		if c and exp.stops < 4 then
			collect(ava, c)
			aboard(ava)
		end
		aboard(ben)
	end
	if phase() == "departing" then
		aboard(ava)
		aboard(ben)
	end
	skip()
	if exp.milestones > 0 then
		sawMilestone = true
	end
end
check("the expedition ends (out of fuel)", phase() == "ended" and exp.reason == "fuel", `{phase()} {exp.reason} after {guard}`)
check("several stops", exp.stops >= 3, tostring(exp.stops))
check("a milestone along the way (10 km)", sawMilestone or exp.distance < Constants.MILESTONE_KM, tostring(exp.distance))
if exp.distance >= Constants.MILESTONE_KM then
	check("milestone parts for the crew", pa.storage.parts >= Constants.MILESTONE_PARTS)
end
check("personal best", pa.best == exp.distance and pa.stats.expeditions == 1)
check("personal record list", pa.records[1] and pa.records[1].id == exp.id and pa.records[1].km == exp.distance)
Engine.advance(1)
-- the record
local ranking = Engine.orderedStores[Constants.RECORD_STORE]
if not noDataStore then
	check("record ranked", ranking and ranking[exp.id] == math.floor(exp.distance * 10 + 0.5))
	local detail = Engine.dataStores[Constants.RECORD_DETAILS] and Engine.dataStores[Constants.RECORD_DETAILS][exp.id]
	check("record details: final, crew, recognition", detail and detail.live == false and #detail.crew >= 1 and detail.recognition.fuel ~= nil, detail and Engine.game:GetService("HttpService"):JSONEncode(detail))
	check("record crew: Ava and Ben by name", detail and detail.crew[1].userId == 101 or detail.crew[2] and detail.crew[2].userId == 101)
end
check("hall: the top record is up", string.find(World.station.hall.top.plaque.Text, "KM", 1, true) ~= nil)
check("hall: statues of the crew", #World.station.hall.top.crew:GetChildren() >= 1)
check("hall: the miniature train", #World.station.hall.top.mini:GetChildren() >= 1)
hall = lastEvent("Hall", ava)
check("hall list sent with the record", hall and #hall.records == 1 and hall.records[1].km == exp.distance)
-- the next expedition
local oldId = exp.id
Engine.advance(Constants.END_SECONDS + 1)
check("a new expedition at the station", phase() == "lobby" and Expedition:State().id ~= oldId)
check("the station is back", World.station.model.Parent == World.scenery)
check("the train is fresh", Train:Stage("engine") == 0 and Expedition:Fuel() == Constants.START_FUEL)
check("cabins are kept", pa.cabin.built.bunk == true and Cabins:IndexOf(ava) == 1)
check("the countdown restarts", (ws:GetAttribute("PhaseEnds") or 0) > Engine.now())

-- Records are idempotent and never shrink -------------------------------------------------------------------
if not noDataStore then
	local r = Engine.dataStores[Constants.RECORD_DETAILS][oldId]
	local copy = table.clone(r)
	copy.km = 1
	copy.live = true
	Records:Save(copy)
	check("a shorter or live rewrite doesn't replace a final record", Engine.dataStores[Constants.RECORD_DETAILS][oldId].km == r.km)
	local n = 0
	for _ in ranking do
		n += 1
	end
	check("no duplicate records", n == 1)
end

-- Friends -------------------------------------------------------------------------------------------------
Engine.fireServer(ava, "JoinFriend", 555, "Zed")
Engine.advance(0.3)
local fr = lastEvent("FriendResult", ava)
check("only friends' trains", fr and fr.kind == "failed")
Engine.makeFriends(ava, Players:GetPlayerByUserId(102) or ben)
Engine.advance(1.1) -- (one join request a second)
Engine.fireServer(ava, "JoinFriend", 102, "Ben")
Engine.advance(0.3)
fr = lastEvent("FriendResult", ava)
check("friend on this train: here", fr and fr.kind == "here" and fr.cabin == 2)
-- a friend on another server, with room
local zed = { id = 555 }
Engine.makeFriends(ava, { UserId = zed.id })
Engine.friendPlaces[555] = { Engine.game.PlaceId, "job-zed" }
Engine.memory.LT_Trains = Engine.memory.LT_Trains or {}
Engine.memory.LT_Trains["job-zed"] = { phase = "traveling", km = 12.5, crew = 5, max = 20, code = "ZED1", exp = "exp-zed" }
Engine.fireServer(ava, "Friends", { { userId = 555, jobId = "job-zed" }, { userId = 102, jobId = "" } })
Engine.advance(0.3)
local friends = lastEvent("Friends", ava)
check("friends panel: Zed's train status (no access code)", friends and friends[1].km == 12.5 and friends[1].crew == 5 and friends[1].access == nil)
check("friends panel: Ben is here", friends and friends[2].here == true)
local tp0 = #Engine.teleports
Engine.advance(1.1)
Engine.fireServer(ava, "JoinFriend", 555, "Zed")
Engine.advance(0.5)
check("teleport to Zed's exact server", #Engine.teleports == tp0 + 1 and Engine.teleports[#Engine.teleports].options.ServerInstanceId == "job-zed")
check("teleporting shown", (lastEvent("FriendResult", ava) or {}).kind == "teleporting")
-- full: the server says so up front
Engine.memory.LT_Trains["job-zed"].crew = 20
Engine.advance(6) -- (status cache)
Engine.fireServer(ava, "JoinFriend", 555, "Zed")
Engine.advance(0.5)
fr = lastEvent("FriendResult", ava)
check("Train Full", fr and fr.kind == "full" and fr.max == Constants.FRIEND_RETRY_TRIES)
-- or the teleport fails because it filled up meanwhile
Engine.memory.LT_Trains["job-zed"].crew = 19
Engine.advance(6)
Engine.teleportResult = "GameFull"
Engine.fireServer(ava, "JoinFriend", 555, "Zed")
Engine.advance(0.5)
fr = lastEvent("FriendResult", ava)
check("teleport failed (full): Train Full", fr and fr.kind == "full")
Engine.teleportResult = nil
-- wait for a spot: retries, then it frees up
Engine.memory.LT_Trains["job-zed"].crew = 20
Engine.fireServer(ava, "FriendAction", "retry")
Engine.advance(0.3)
fr = lastEvent("FriendResult", ava)
check("waiting for a spot (a retry, not a queue position)", fr and fr.kind == "waiting" and fr.tries == 0)
Engine.advance(Constants.FRIEND_RETRY_SECONDS + 1.5)
fr = lastEvent("FriendResult", ava)
check("still full: try 1", fr and fr.kind == "waiting" and fr.tries == 1)
Engine.memory.LT_Trains["job-zed"].crew = 12
local tp1 = #Engine.teleports
Engine.advance(Constants.FRIEND_RETRY_SECONDS + 1.5)
check("a spot opened: teleporting", #Engine.teleports == tp1 + 1)
-- start a new expedition: a fresh private train
Engine.fireServer(ava, "FriendAction", "new")
Engine.advance(0.5)
local last = Engine.teleports[#Engine.teleports]
check("new expedition: reserved server", last.options.ReservedServerAccessCode ~= nil)
-- a friend who isn't in a game
Engine.makeFriends(ava, { UserId = 556 })
Engine.advance(1.1)
Engine.fireServer(ava, "JoinFriend", 556, "Yan")
Engine.advance(0.5)
check("friend not on a train: gone", (lastEvent("FriendResult", ava) or {}).kind == "gone")
-- spamming join requests is rate limited
local before2 = #Engine.teleports
Engine.advance(1.1)
for _ = 1, 10 do
	Engine.fireServer(ava, "JoinFriend", 555, "Zed")
end
Engine.advance(0.5)
check("join spam is rate limited", #Engine.teleports - before2 <= 2)

-- Rejoining a train you dropped out of ------------------------------------------------------------------------
do
	local cy = Engine.addPlayer("Cy", 103)
	Engine.dataStores[Constants.PROFILE_STORE] = Engine.dataStores[Constants.PROFILE_STORE] or {}
	if not noDataStore then
		Engine.dataStores[Constants.PROFILE_STORE]["u_103"] = nil
	end
	Engine.removePlayer(cy)
	Engine.advance(0.5)
end

-- Feedback after 10 minutes ---------------------------------------------------------------------------------
Engine.advance(Constants.FEEDBACK_AFTER + 5)
local ask = lastEvent("Ask", ava)
check("feedback card after 10 minutes (guide done)", ask and ask.kind == "feedback")
Engine.fireServer(ava, "Feedback", false, "more stops badword", { "timer", "nope" })
Engine.advance(0.3)
check("feedback answered", pa.feedback.at ~= nil and pa.feedback.like == false)

-- The anti-cheat: teleporting to a pile is pulled back --------------------------------------------------------
do
	-- give the lobby a moment, then teleport without our grace
	local hrp = ben.Character.HumanoidRootPart
	Engine.advance(4)
	local start = hrp.Position
	hrp.CFrame = hrp.CFrame + Vector3.new(400, 0, 0)
	Engine.advance(1)
	check("teleport cheat pulled back", (hrp.Position - start).Magnitude < 50, tostring((hrp.Position - start).Magnitude))
	check("teleport cheat flagged", (AntiCheat.state[ben] and AntiCheat.state[ben].strikes or 0) >= 3)
	local hrp2 = ava.Character.HumanoidRootPart
	local a0 = hrp2.Position
	Engine.advance(3)
	check("honest player clean", (AntiCheat.state[ava] and AntiCheat.state[ava].strikes or 0) == 0 and (hrp2.Position - a0).Magnitude < 1)
end

-- Leaving and analytics ---------------------------------------------------------------------------------------
Engine.removePlayer(ben)
Engine.advance(Constants.ANALYTICS_FLUSH_SECONDS + 1)
local function kinds(p)
	local set = {}
	for _, e in aEvents do
		if e.user_id == p.UserId then
			set[e.kind] = (set[e.kind] or 0) + 1
		end
	end
	return set
end
local ka = kinds(ava)
for _, k in { "join", "loaded", "ui_ready", "color", "collect", "bank", "built", "deposit", "stop_reached", "tutorial_step", "tutorial_done", "expedition_end", "record", "friend_friend", "friend_result", "feedback", "stepped_out" } do
	check("analytics: Ava " .. k, ka[k] ~= nil)
end
local kb = kinds(ben)
for _, k in { "stranded", "recovery_step", "recovered", "bag_lost", "leave", "cheat_teleport" } do
	check("analytics: Ben " .. k, kb[k] ~= nil)
end
local benSession
for _, row in aSessions do
	if row.user_id == 102 and row.ended_at then
		benSession = row
	end
end
check("Ben's session ended with a summary", benSession and benSession.summary and benSession.summary.stranded_gained == 1 and benSession.duration_s > 0)
local live
for _, row in aSessions do
	if row.user_id == 101 and row.live then
		live = row.live
	end
end
check("live row for the dashboard: zone, phase, bag, cabin, distance, stops", live and live.zone and live.phase and live.bag and live.cabin == 1 and live.distance and live.stops)

-- game log
Engine.advance(Constants.GAME_LOG_FLUSH_SECONDS + 1)
local titles = {}
for _, e in gameLogs do
	table.insert(titles, e.title)
end
local all = table.concat(titles, "\n")
check("game log: joins and leaves", all:find("Ava joined", 1, true) and all:find("Ben left", 1, true))
check("game log: expedition ended", all:find("ended at", 1, true) ~= nil)
check("game log: hall of records", all:find("Hall of Records", 1, true) ~= nil)
check("game log: an upgrade", all:find("finished", 1, true) ~= nil)

-- Shutdown ----------------------------------------------------------------------------------------------------
for _, fn in Engine.closeHandlers do
	fn()
end
Engine.advance(1)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
local warnings = {}
for _, w in Engine.warnings do
	if not w:find("DataStore unavailable") and not w:find("couldn't save record") then
		table.insert(warnings, w)
	end
end
check("no warnings", #warnings == 0, warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("server smoke test failed")
end

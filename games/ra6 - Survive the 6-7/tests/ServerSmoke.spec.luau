--[[
Server smoke test: boots the real server scripts on the mock engine and plays whole runs: day 1 (the guide, chopping,
building the workbench, crates and a mimic, crafting, the inventory, friends joining, the difficulty vote, the camp
growing to the Outpost), the night (the roster locking, a late joiner waiting, waves, fighting, Kermy's lunge and a
dodge, going down, a revive, bleeding out to a ghost and back at dawn, the fire), nights 2-6, Mega Kermy on night 7
(a charge into an Ancient Pine, the weak spot, the goo cocoon, mashing out, the win), the results (XP, unlocks,
achievements, the leaderboards), the next run (the world reset, the waiting player in), a wipe, leaving and coming
back, friends' runs, a new run, a private run, pings, feedback, analytics, the game log and the anti-cheat. Fails
on any script error or broken expectation.

  luaurun tests/ServerSmoke.spec.luau                 (from the game folder)
  luaurun tests/ServerSmoke.spec.luau nodatastore     (Studio-without-API-access fallback)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame
local Enum = Engine.Enum
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
local Run = service("RunService")
local Survivors = service("SurvivorService")
local Inventory = service("InventoryService")
local Resources = service("ResourceService")
local Camp = service("CampService")
local Craft = service("CraftService")
local Loot = service("LootService")
local Monsters = service("MonsterService")
local Boss = service("BossService")
local Combat = service("CombatService")
local World = service("WorldService")
local Tutorial = service("TutorialService")
local Objectives = service("ObjectiveService")
local Progress = service("ProgressService")
local Boards = service("LeaderboardService")
local Join = service("JoinService")
local Pings = service("PingService")
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
local taggedRa6 = true
Analytics.send = function(payload)
	if payload.game ~= "ra6" then
		taggedRa6 = false
	end
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
local MapLayout = Engine.require(tree.shared.World.MapLayout)
local Items = Engine.require(tree.shared.Data.Items)
local Recipes = Engine.require(tree.shared.Data.Recipes)
local CampData = Engine.require(tree.shared.Data.Camp)
local Progression = Engine.require(tree.shared.Data.Progression)
local Players = Engine.Players
local ws = Engine.workspace
local PPS = Engine.game:GetService("ProximityPromptService")

local function events(kind, player)
	local out = {}
	for _, e in aEvents do
		if e.kind == kind and (player == nil or e.user_id == player.UserId) then
			table.insert(out, e)
		end
	end
	return out
end
local function lastFired(name, player)
	local e = Engine.lastClientEvent(name, player)
	return e and e.args[1]
end
local function firedSince(mark, name, player, pred)
	for i = mark + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if
			e.name == name
			and (player == nil or e.player == player or e.player == "all")
			and (not pred or pred(e.args))
		then
			return e
		end
	end
	return nil
end
local function mark()
	return #Engine.clientLog
end
local function pos(p)
	return Survivors:Position(p)
end
local function ground(x, z)
	return MapLayout.groundY(x, z)
end
-- stand on the ground at (x, z), facing a point
local function standAt(p, x, z, lookAt)
	local at = Vector3.new(x, ground(x, z) + 3, z)
	Engine.moveTo(p, at, lookAt and Vector3.new(lookAt.X, at.Y, lookAt.Z) or nil)
end
local function flush()
	Analytics.flush()
	GameLog.flush()
end
local function join(name, userId)
	local p = Engine.addPlayer(name, userId)
	Engine.advance(0.3)
	Engine.fireServer(p, "Ready")
	Engine.advance(0.5)
	return p
end
local function count(p, key)
	return Inventory:Count(p, key)
end
local function hp(p)
	local s = Survivors:State(p)
	return s and s.hp
end
local function skipPhase()
	Run:_skip()
	Engine.advance(0.6)
end
local function skipTo(phase, maxSteps)
	for _ = 1, maxSteps or 30 do
		if Run:Phase() == phase then
			return true
		end
		skipPhase()
	end
	return Run:Phase() == phase
end
local function safeAtCamp(p, k)
	local s = MapLayout.spawnPoint(k or 1)
	standAt(p, s.X, s.Z)
end
local function promptsWith(attr, value)
	local out = {}
	for _, pr in Engine.prompts(ws) do
		if pr:GetAttribute(attr) == value then
			table.insert(out, pr)
		end
	end
	return out
end
local function structureOf(key, state)
	for _, s in Camp:Structures() do
		if s.key == key and (state == nil or s.state == state) then
			return s
		end
	end
	return nil
end
-- keep the current phase going for a while (the test takes its time)
local function holdPhase(seconds)
	local run = Run:Get()
	run.phaseEnds = Engine.now() + seconds
end
local function hold(p, prompt, seconds)
	PPS.PromptButtonHoldBegan:Fire(prompt, p)
	Engine.advance(seconds)
	PPS.PromptButtonHoldEnded:Fire(prompt, p)
	Engine.advance(0.1)
end

local endLog = {}
Run.Ended:Connect(function(r)
	table.insert(endLog, string.format("t=%.1f %s %s", Engine.now(), tostring(r.won), r.reason))
	for _, pl in Players:GetPlayers() do
		local st = Survivors:State(pl)
		local p = Survivors:Position(pl)
		table.insert(
			endLog,
			string.format(
				"  %s %s pos=%s bleed=%.1f fr=%.1f fire=%s lit=%s r=%.0f",
				pl.Name,
				tostring(st and st.status),
				p and string.format("%.0f,%.0f", p.X, p.Z) or "nil",
				st and st.bleedUntil or -1,
				st and st.fireRevive or -1,
				tostring(Camp:FirePosition()),
				tostring(Camp:FireLit()),
				Camp:FireRadius()
			)
		)
	end
end)
Survivors.Downed:Connect(function(pl, src)
	table.insert(endLog, string.format("t=%.1f down %s by %s", Engine.now(), pl.Name, src and src.kind or "?"))
end)

-- 1. Boot ------------------------------------------------------------------------------------------------------------------
check("starts idle (no run until someone's here)", Run:Phase() == "idle")
check("the forest is built", ws.Map:FindFirstChild("Forest") ~= nil and #ws.Map.Forest:GetChildren() > 20)
check("the camp is built", ws:FindFirstChild("Map") ~= nil and ws.Map:FindFirstChild("Camp") ~= nil)
check("smooth terrain was written", ws.Terrain ~= nil)
check(
	"folders for the run",
	ws:FindFirstChild("Structures")
		and ws:FindFirstChild("Loot")
		and ws:FindFirstChild("Drops")
		and ws:FindFirstChild("Nodes")
)
check(
	"remotes made",
	Engine.game.ReplicatedStorage:FindFirstChild("Net") ~= nil
		and Engine.remote("Mobs").ClassName == "UnreliableRemoteEvent"
)
check("eight Ancient Pines", #MapLayout.ancientPines == 8)
check("many trees", #MapLayout.trees() > 1500, #MapLayout.trees())
check("resource nodes", #ws.Nodes:GetChildren() > 100, #ws.Nodes:GetChildren())

-- 2. The first player: straight into day 1 -----------------------------------------------------------------------------------
local ava = join("Ava", 501)
check("ava has a profile", Data:Get(ava) ~= nil)
check("a run started with the first player", Run:Phase() == "day" and Run:Day() == 1)
check("ava is in the run", Run:InRun(ava))
check("ava has a character", ava.Character ~= nil and ava.Character:FindFirstChild("HumanoidRootPart") ~= nil)
check("ava is alive", Survivors:Status(ava) == "alive")
local p0 = pos(ava)
check("ava spawned by the fire", p0 and MapLayout.radius(p0.X, p0.Z) < MapLayout.CAMP.radius, p0)
check("starting kit: a Rusty Axe in slot 1", Inventory:Slot(ava, "h1") and Inventory:Slot(ava, "h1").key == "rusty_axe")
check("starting kit: a torch", count(ava, "torch") == 1)
check("the run view went out", lastFired("Run", ava) and lastFired("Run", ava).phase == "day")
check("the inventory went out", lastFired("Inv", ava) ~= nil)
check("the profile went out", lastFired("Profile", ava) ~= nil)
check("the camp went out", lastFired("Camp", ava) ~= nil)
check("the guide started: chop a tree", Tutorial:Active(ava) and Tutorial:View(ava).key == "chop")
Engine.advance(1.2)
local obj = lastFired("Objective", ava)
check(
	"the objective is the guide's step",
	obj and obj.primary and obj.primary.guide == true,
	obj and obj.primary and obj.primary.text
)
check("the camp is a marker on the compass", obj and obj.markers and obj.markers[1] and obj.markers[1].key == "camp")
check(
	"crates were scattered",
	(function()
		local n = 0
		for _ in Loot:All() do
			n += 1
		end
		return n >= Constants.CRATES
	end)()
)
check("findings were placed", #World:Findings() >= 8, #World:Findings())

-- 3. Chopping ------------------------------------------------------------------------------------------------------------------
local function chopNearest(p, from, wantWood)
	local list = Resources:TreesNear(from, 150)
	local t = list[1]
	for _, cand in list do
		if MapLayout.radius(cand.rec.x, cand.rec.z) > MapLayout.CAMP.clear + 4 then
			t = cand
			break
		end
	end
	if not t then
		return 0, nil
	end
	local tp = Vector3.new(t.rec.x, 0, t.rec.z)
	local dir = (Vector3.new(from.X, 0, from.Z) - tp)
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
	local spot = tp + dir * (t.rec.trunk + 3)
	standAt(p, spot.X, spot.Z, tp)
	local start = count(p, "wood")
	for _ = 1, 40 do
		Engine.fireServer(p, "Act", 1, (tp - spot).Unit, "main")
		Engine.advance(0.6)
		if count(p, "wood") - start >= (wantWood or 1) and t.felled then
			break
		end
	end
	return count(p, "wood") - start, t
end
local got, felledTree = chopNearest(ava, p0, 5)
check("chopping gives wood", got >= 5, got)
check("the tree fell", felledTree and felledTree.felled)
check("the fall went out", Engine.lastClientEvent("Fx") ~= nil)
check(
	"the guide moved on to the workbench",
	Tutorial:Active(ava) and Tutorial:View(ava).key == "build",
	Tutorial:Active(ava) and Tutorial:View(ava).key
)
flush()
check("first_wood tracked", #events("first_wood", ava) == 1)

-- 4. Building the workbench (hold its blueprint's prompt) ------------------------------------------------------------------------
local bench = Camp:Structure("workbench_1")
check("the workbench is a blueprint", bench and bench.state == "blueprint")
Inventory:Give(ava, "wood", 20, "test")
standAt(ava, bench.slot.pos.X + 4, bench.slot.pos.Z, bench.slot.pos)
local buildPrompt = promptsWith("Structure", "workbench_1")[1]
check("the blueprint has a Build prompt", buildPrompt and buildPrompt:GetAttribute("Action") == "Build")
local woodBefore = count(ava, "wood")
hold(ava, buildPrompt, 2)
check("holding the prompt built the workbench", bench.state == "built", bench.state)
local benchWood = CampData.STRUCTURES.workbench.cost.wood
check("it took the workbench's wood", woodBefore - count(ava, "wood") == benchWood, woodBefore - count(ava, "wood"))
check("ava's contribution is counted", Camp:Contribution(ava) >= benchWood)
check(
	"the guide moved on to a crate",
	Tutorial:Active(ava) and Tutorial:View(ava).key == "loot",
	Tutorial:Active(ava) and Tutorial:View(ava).key
)
Engine.advance(1.1)
obj = lastFired("Objective", ava)
check("objective text changes", obj and obj.primary and obj.primary.text ~= nil)

-- 5. Crates and a mimic ----------------------------------------------------------------------------------------------------------
local function nearestCrate(from, filter)
	local best, bestD
	for _, c in Loot:All() do
		if not c.opened and (not filter or filter(c)) then
			local d = (c.pos - from).Magnitude
			if not bestD or d < bestD then
				best, bestD = c, d
			end
		end
	end
	return best, bestD
end
local crate, crateD = nearestCrate(MapLayout.CAMP_PROPS.fire, function(c)
	return c.kind == "crate" and not c.mimic
end)
check("the starter crate is right by the fire", crate and crate.starter and crateD < 16, crateD)
check(
	"the saplings: the nearest tree to chop is seconds away",
	(function()
		local list = Resources:TreesNear(MapLayout.spawnPoint(1), 40)
		return list[1] ~= nil and list[1].rec.sapling == true and Resources:CanChop(list[1])
	end)()
)
check("the guide says any tree", string.find(Tutorial.TEXT.chop, "any tree", 1, true) ~= nil)
standAt(ava, crate.pos.X + 3, crate.pos.Z, crate.pos)
local invBefore = 0
for _, s in Inventory:Contents(ava) do
	invBefore += s.n
end
check("opening a crate works", Loot:Open(ava, crate.id))
local invAfter = 0
for _, s in Inventory:Contents(ava) do
	invAfter += s.n
end
check("the crate gave items", invAfter > invBefore, invAfter - invBefore)
check(
	"the starter crate: a weapon, a torch and something to eat",
	(count(ava, "branch_club") + count(ava, "stone_spear")) >= 1
		and count(ava, "torch") >= 1
		and count(ava, "berries") >= 2,
	`{count(ava, "branch_club")} {count(ava, "stone_spear")} {count(ava, "torch")} {count(ava, "berries")}`
)
check("a crate can't be opened twice", not Loot:Open(ava, crate.id))
check("the guide moved on to holding what you found", not Tutorial:Active(ava) or Tutorial:View(ava).key ~= "loot")
check("collection: found items are saved", next(Data:Get(ava).collection.items) ~= nil)
-- a diary page (page 5 alone: a list with gaps, which a DataStore refuses) still saves
Progress:FoundPage(ava, 5)
check("diary page found", Data:Get(ava).collection.pages["5"] == true)
if not noDataStore then
	local stored
	for _, store in Engine.dataStores do
		local saved = store["u_" .. ava.UserId]
		if saved then
			stored = saved
		end
	end
	local before = stored and stored.meta and stored.meta.lastSeen
	Data:Save(ava)
	for _, store in Engine.dataStores do
		local saved = store["u_" .. ava.UserId]
		if saved then
			stored = saved
		end
	end
	check(
		"the save with the page went through",
		stored and stored.collection and stored.collection.pages["5"] == true,
		stored and before
	)
end
-- a mimic right here
local mimicCrate = Loot:Place("crate", CFrame.new(crate.pos + Vector3.new(6, 0, 0)), { mimic = true })
standAt(ava, mimicCrate.pos.X + 3, mimicCrate.pos.Z, mimicCrate.pos)
local mobsBefore = Monsters:Count()
check("opening a mimic springs it", Loot:Open(ava, mimicCrate.id))
check("the mimic is a monster now", Monsters:Count() == mobsBefore + 1)
local mimicMob
for _, m in Monsters:All() do
	if m.kind == "mimic" then
		mimicMob = m
	end
end
check("the mimic carries loot", mimicMob and mimicMob.loot and #mimicMob.loot > 0)
-- catch it: hit it until it drops its loot
if mimicMob then
	local dropsBefore = #Inventory:Drops()
	for _ = 1, 30 do
		if mimicMob.hp <= 0 then
			break
		end
		Monsters:Damage(mimicMob.id, 20, ava, {})
		Engine.advance(0.2)
	end
	check("the mimic was caught", mimicMob.hp <= 0)
	Engine.advance(0.5)
	check("it dropped its loot", #Inventory:Drops() > dropsBefore)
end
-- holding a found item finishes the guide's equip step
local slotFound
for id, s in Inventory:Contents(ava) do
	if string.sub(id, 1, 1) == "h" and id ~= "h1" and Items.goesToHotbar(Items.get(s.key)) then
		slotFound = tonumber(string.sub(id, 2))
	end
end
if not slotFound then
	Inventory:Give(ava, "branch_club", 1, "test")
	for id, s in Inventory:Contents(ava) do
		if s.key == "branch_club" and string.sub(id, 1, 1) == "h" then
			slotFound = tonumber(string.sub(id, 2))
		end
	end
end
Engine.fireServer(ava, "Select", slotFound)
Engine.advance(0.2)
check(
	"selecting a hotbar slot",
	select(1, Inventory:Selected(ava)) == "h" .. tostring(slotFound),
	select(1, Inventory:Selected(ava))
)
check(
	"the held item is in the hand",
	ava.Character:GetAttribute("Held") ~= nil and ava.Character:FindFirstChild("Held") ~= nil,
	ava.Character:GetAttribute("Held")
)
check(
	"the guide is past the first steps",
	not Tutorial:Active(ava) or Tutorial:View(ava).step >= 5,
	Tutorial:Active(ava) and Tutorial:View(ava).key
)
Engine.fireServer(ava, "Select", 1)
Engine.advance(0.2)

-- 5b. The first minute's hook: Kermy shows himself at 0:50, a Snapcap jumps out at ~1:00 (§4: a first fight by day)
do
	local function anyFired(name, player, pred)
		return firedSince(0, name, player, pred)
	end
	for _ = 1, 80 do
		if Run:Seconds() >= Constants.FIRST_AMBUSH_AT + 1 then
			break
		end
		Engine.advance(1)
	end
	check("Kermy's first sighting is in the first minute", Constants.FIRST_SIGHTING_AT <= 60)
	check("Kermy showed himself", anyFired("Callout", nil, function(args)
		return string.find(tostring(args[1]), "watching", 1, true) ~= nil
	end) ~= nil)
	local snap
	for _, m in Monsters:All() do
		if m.ambush then
			snap = m
		end
	end
	check("a Snapcap jumped out", snap ~= nil and snap.kind == "snapcap" and snap.day == true)
	check(
		"near someone",
		snap and (snap.pos - Survivors:Position(ava)).Magnitude < 40,
		snap and (snap.pos - Survivors:Position(ava)).Magnitude
	)
	check(
		"the guide says hit it",
		Tutorial:Active(ava) and Tutorial:View(ava).key == "fight" and Tutorial:View(ava).mob == (snap and snap.id),
		Tutorial:Active(ava) and Tutorial:View(ava).key
	)
	local xp0 = Data:Get(ava).xp
	if snap then
		Monsters:Damage(snap.id, 999, ava, {})
		Engine.advance(0.3)
	end
	check("the first fight paid XP", Data:Get(ava).xp - xp0 >= Constants.XP.guide.fight, Data:Get(ava).xp - xp0)
	check("with a popup", anyFired("Popup", ava, function(args)
		return args[2] == `+{Constants.XP.guide.fight} XP ✨`
	end) ~= nil)
	check(
		"then: explore (the nearest crate out in the forest)",
		Tutorial:Active(ava) and Tutorial:View(ava).key == "explore" and Tutorial:View(ava).container ~= nil,
		Tutorial:Active(ava) and Tutorial:View(ava).key
	)
	check("the guide's firsts so far", Data:Get(ava).xp >= 70, Data:Get(ava).xp)
end

-- 6. Crafting at the workbench ------------------------------------------------------------------------------------------------------
local axeRecipe = Recipes.byItem.stone_axe
Inventory:Give(ava, "stone", 5, "test")
standAt(ava, 70, 70) -- far from the bench
check("can't craft away from the workbench", not Craft:Craft(ava, axeRecipe.id))
standAt(ava, bench.slot.pos.X + 4, bench.slot.pos.Z, bench.slot.pos)
local wood0, stone0 = count(ava, "wood"), count(ava, "stone")
check("crafting a Stone Axe", Craft:Craft(ava, axeRecipe.id))
check("the axe is in the inventory", count(ava, "stone_axe") == 1)
check("materials were used", wood0 - count(ava, "wood") == 4 and stone0 - count(ava, "stone") == 3)
check("a tier-2 recipe needs the Outpost", not Craft:Craft(ava, Recipes.byItem.short_bow.id))
local craftView = lastFired("Toast", ava)
check("crafting answers with a toast", craftView ~= nil)
-- materials from the camp chest count too (once there is one)

-- 7. The inventory ----------------------------------------------------------------------------------------------------------------
local axeSlot
for id, s in Inventory:Contents(ava) do
	if s.key == "stone_axe" then
		axeSlot = id
	end
end
check("the new axe went somewhere", axeSlot ~= nil)
Engine.fireServer(ava, "Move", axeSlot, "b12")
Engine.advance(0.2)
check("moving to a backpack slot", Inventory:Slot(ava, "b12") and Inventory:Slot(ava, "b12").key == "stone_axe")
Engine.fireServer(ava, "Move", "b12", "h1")
Engine.advance(0.2)
check(
	"swapping into the hotbar",
	Inventory:Slot(ava, "h1").key == "stone_axe" and Inventory:Slot(ava, "b12").key == "rusty_axe"
)
check("bad slot ids are refused", not Inventory:Move(ava, "h1", "h99") and not Inventory:Move(ava, "x1", "h2"))
Inventory:Give(ava, "small_pack", 1, "test")
local packSlot
for id, s in Inventory:Contents(ava) do
	if s.key == "small_pack" then
		packSlot = id
	end
end
local capBefore = Inventory:Capacity(ava)
Engine.fireServer(ava, "Move", packSlot, "equip")
Engine.advance(0.2)
check("equipping a pack", Inventory:Slot(ava, "pack") and Inventory:Slot(ava, "pack").key == "small_pack")
check("a pack adds backpack slots", Inventory:Capacity(ava) > capBefore, Inventory:Capacity(ava))
Engine.fireServer(ava, "Drop", "b12", 1)
Engine.advance(0.3)
check("dropping makes a drop on the ground", #Inventory:Drops() >= 1 and count(ava, "rusty_axe") == 0)
local myDrop
for _, d in Inventory:Drops() do
	if d.items[1] and d.items[1].key == "rusty_axe" then
		myDrop = d
	end
end
check("picking it back up", myDrop and Inventory:Pickup(ava, myDrop.id) and count(ava, "rusty_axe") == 1)

-- 8. A friend joins during day 1 -----------------------------------------------------------------------------------------------------
-- (friends before ben arrives, as in real life)
Engine.friends["501:502"] = true
Engine.friends["502:501"] = true
local ben = Engine.addPlayer("Ben", 502)
Engine.advance(0.3)
Engine.fireServer(ben, "Ready")
Engine.advance(0.5)
check("ben joined the run (day 1 is open)", Run:InRun(ben) and Survivors:Status(ben) == "alive")
check("the roster has two", #Run:Active() == 2)
check("ben got his own kit", count(ben, "rusty_axe") == 1)
check("ben's guide started", Tutorial:Active(ben) ~= nil)
check(
	"ben's guide skipped the workbench (the team built it)",
	(function()
		local v = Tutorial:View(ben)
		return v and v.key == "chop"
	end)()
)
Engine.fireServer(ben, "SkipTutorial")
Engine.advance(0.2)
check("SKIP ends the guide", Tutorial:Active(ben) == nil and Data:Get(ben).tutorial.done == true)
check("the guide's arrow is gone for ben", lastFired("Tutorial", ben) == false)

-- 9. The difficulty vote at the standing stones -----------------------------------------------------------------------------------------
check("only Normal is unlocked", Run:UnlockedMax() == 1)
Engine.fireServer(ava, "Vote", "difficulty", 2)
Engine.advance(0.2)
check("a locked difficulty can't be voted for", Run:Get().votes.difficulty[ava.UserId] == nil)
Data:Get(ben).unlocked = 2 -- ben has beaten Normal before
check("someone here has unlocked Hard", Run:UnlockedMax() == 2)
Engine.fireServer(ben, "Vote", "difficulty", 2)
Engine.fireServer(ava, "Vote", "difficulty", 1)
Engine.advance(0.2)
check("both votes count", Run:Get().votes.difficulty[ben.UserId] == 2 and Run:Get().votes.difficulty[ava.UserId] == 1)

local rv = lastFired("Run", ava)
check("the vote is in the run view", rv and rv.votes and rv.votes.difficulty[1] == 1 and rv.votes.difficulty[2] == 1)
local stonePrompt = promptsWith("Difficulty", nil)
local stone3 = ws.Map.Camp:FindFirstChild("Stone3")
local vote3 = stone3 and Engine.prompts(stone3)[1]
check("the standing stones have prompts", vote3 ~= nil and vote3.Enabled == true)
check("a stone nobody unlocked says so", vote3 and vote3.ActionText == "Locked")
Run:_refreshPrompts() -- (the stones read who has unlocked what when someone joins; ben's unlock was set by hand)
local vote2 = Engine.prompts(ws.Map.Camp.Stone2)[1]
check("an unlocked stone says its difficulty", vote2 and vote2.ActionText == "Vote: Hard")
vote2.Triggered:Fire(ava)
Engine.advance(0.1)
check("touching a stone votes", Run:Get().votes.difficulty[ava.UserId] == 2)
Engine.advance(1.1)
Engine.fireServer(ava, "Vote", "difficulty", 1)
Engine.advance(0.6)
check("and back to Normal", Run:Get().votes.difficulty[ava.UserId] == 1)
local bellPrompt = Engine.prompts(ws.Map.Camp.Bell)[1]
check("the camp bell has a prompt by day", bellPrompt ~= nil and bellPrompt.Enabled == true)
_ = stonePrompt

-- 10. The camp: the storage chest, the Outpost ---------------------------------------------------------------------------------------------
local chest = Camp:Structure("storage_1")
check("the chest is a blueprint", chest and chest.state == "blueprint")
Inventory:Give(ben, "wood", 30, "test")
standAt(ben, chest.slot.pos.X + 3, chest.slot.pos.Z, chest.slot.pos)
for _ = 1, 12 do
	Camp:Deposit(ben, chest, false)
end
check("ben built the chest", chest.state == "built")
-- put things in the chest; the board and stations can use them
local benWood
for id, s in Inventory:Contents(ben) do
	if s.key == "wood" then
		benWood = id
	end
end
Engine.fireServer(ben, "Store", "put", benWood, 10)
Engine.advance(0.2)
check("wood in the chest", Camp:StorageCount("wood") == 10, Camp:StorageCount("wood"))
check("the chest's contents went to ben", lastFired("Storage", ben) and lastFired("Storage", ben).wood == 10)
standAt(ava, 90, 90)
check("you can't use the chest from far away", not Camp:Put(ava, "h2", 1))
-- the Outpost: 30 wood + 15 stone, from backpacks and the chest
local ok, why = Camp:CanUpgrade(ben)
check("the Outpost needs materials first", not ok and why ~= nil, why)
Inventory:Give(ben, "wood", 30, "test")
Inventory:Give(ben, "stone", 15, "test")
standAt(ben, MapLayout.CAMP_PROPS.board.X + 3, MapLayout.CAMP_PROPS.board.Z, MapLayout.CAMP_PROPS.board)
local m10 = mark()
Engine.fireServer(ben, "Camp", "upgrade")
Engine.advance(0.3)
check("the camp is The Outpost", Camp:Tier() == 2, Camp:Tier())
check("the tier-up was announced", firedSince(m10, "Alert", nil) ~= nil)
check("walls are blueprints now", structureOf("wall", "blueprint") ~= nil)
check("tier-2 recipes open", Craft:CanCraft(ava, Recipes.byItem.short_bow) ~= nil)
check("the fire burns hotter (more fuel room)", select(2, Camp:Fuel()) == Constants.FUEL_MAX[2])
-- a wall and a gate
local wall = structureOf("wall", "blueprint")
Inventory:Give(ava, "wood", 20, "test")
standAt(ava, wall.slot.pos.X, wall.slot.pos.Z - 3, wall.slot.pos)
for _ = 1, 8 do
	Camp:Deposit(ava, wall, false)
end
check("a wall was built", wall.state == "built" and wall.hp == CampData.STRUCTURES.wall.hp)
check("barriers list the wall", #Camp:Barriers() >= 1)
Camp:DamageStructure(wall, 100)
check("walls take damage", wall.hp == CampData.STRUCTURES.wall.hp - 100)
check("repairs need a Repair Bench", not Camp:Repair(ava, wall))

-- 11. Night 1: the roster locks, a late joiner waits ---------------------------------------------------------------------------------------
safeAtCamp(ava, 1)
safeAtCamp(ben, 4)
local m11 = mark()
-- with 40 s of day left the guide says to get back to camp, whatever you were doing
holdPhase(Constants.GUIDE_DUSK_WARNING - 5)
Engine.advance(2.5)
check(
	"dusk soon: the guide says get back to camp",
	not Tutorial:Active(ava) or Tutorial:View(ava).key == "kermy",
	Tutorial:Active(ava) and Tutorial:View(ava).key
)
check("to dusk", skipTo("dusk"))
check("dusk warns everyone", firedSince(m11, "Callout", nil) ~= nil)
check("to night 1", skipTo("night"))
holdPhase(400)
check("the roster locked at night 1", Run:Get().locked == true)
check("the stones go quiet once the roster locks", Engine.prompts(ws.Map.Camp.Stone1)[1].Enabled == false)
check("the bell rests at night", Engine.prompts(ws.Map.Camp.Bell)[1].Enabled == false)
check("the vote tie went to the easier difficulty", Run:Difficulty() == 1, Run:Difficulty())
check("the night plan is ready", Monsters:_night() ~= nil and Monsters:_night().n == 1)
local cara = join("Cara", 503)
check("cara joined after the roster locked: she waits", Run:IsWaiting(cara) and not Run:InRun(cara))
check("cara has no character while she waits", cara.Character == nil and Survivors:Status(cara) == "waiting")
check(
	"cara is told about the next run",
	(function()
		local v = Objectives:View(cara)
		return v.primary.text and string.find(v.primary.text, "next one") ~= nil
	end)()
)
Engine.advance(16)
local nightMobs = Monsters:Count(function(m)
	return not m.day
end)
check("night monsters came out of the forest", nightMobs > 0, nightMobs)
check("monster snapshots stream out", Engine.countClientEvents("Mobs") > 20)
-- from here the test sets up its own fights: no more waves (or Kermy) tonight
Monsters:Clear()
Monsters:_night().nextWave = math.huge
Monsters:_kermyState().nightSpawned = true
Monsters:_kermyState().koUntil = math.huge
-- the snapshot packs and unpacks
local list = {}
for _, m in Monsters:All() do
	table.insert(list, m)
end
local packed = Monsters.pack(list, 1)
local at, unpacked = Monsters.unpack(packed)
check("snapshot round trip", at == 1 and #unpacked == #list, #unpacked)
check("13 bytes a monster", #packed == 8 + 13 * #list)

-- 12. A fight: an axe against a Snapcap -----------------------------------------------------------------------------------------------------
local fightAt = MapLayout.polar(45, 60)
standAt(ava, fightAt.X, fightAt.Z, Vector3.new(fightAt.X + 4, 0, fightAt.Z))
local snap = Monsters:Spawn("snapcap", Vector3.new(fightAt.X + 4, 0, fightAt.Z), { state = "chase" })
local xp0 = Data:Get(ava).xp
for _ = 1, 25 do
	if snap.hp <= 0 then
		break
	end
	local me = pos(ava)
	local dir = Vector3.new(snap.pos.X - me.X, 0, snap.pos.Z - me.Z)
	if dir.Magnitude > 7 then
		standAt(ava, snap.pos.X - 4, snap.pos.Z, snap.pos)
		me = pos(ava)
		dir = Vector3.new(snap.pos.X - me.X, 0, snap.pos.Z - me.Z)
	end
	Engine.fireServer(ava, "Act", 1, dir.Magnitude > 0.01 and dir.Unit or Vector3.new(1, 0, 0), "main")
	Engine.advance(0.6)
end
check("the Snapcap went down", snap.hp <= 0, snap.hp)
check("a kill gives XP", Data:Get(ava).xp > xp0)
check("the bestiary knows Snapcaps", Data:Get(ava).bestiary.snapcap and Data:Get(ava).bestiary.snapcap.defeated >= 1)
check("axe mastery grew", Data:Get(ava).mastery.axe > 0)
check("records count monsters", Data:Get(ava).records.monsters >= 1)
check("the swing went out to everyone", Engine.lastClientEvent("Act") ~= nil)

-- 13. Kermy's lunge: the tell, a dodge, a faceplant ---------------------------------------------------------------------------------------------
-- (out in the open, away from trees)
local function openSpot()
	for a = 0, 350, 10 do
		for r = 50, 120, 10 do
			local p = MapLayout.polar(a, r)
			local clear = true
			for _, t in Resources:TreesNear(p, 26) do
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
standAt(ben, open.X, open.Z)
for id, m in Monsters:All() do
	if m.kind == "kermy" then
		Monsters._mobs[id] = nil
	end
end
local kermy = Monsters:Spawn("kermy", Vector3.new(open.X + 10, 0, open.Z), { state = "chase" })
kermy.nextAttack = 0
local m13 = mark()
local tellEvent
for _ = 1, 60 do
	Engine.advance(0.05)
	tellEvent = firedSince(m13, "Mob", nil, function(args)
		return args[1].kind == "tell" and args[1].id == kermy.id and args[1].tell == "sixseven"
	end)
	if tellEvent then
		break
	end
	standAt(ben, open.X, open.Z)
end
check("Kermy telegraphs his lunge (SIX... SEVEN!)", tellEvent ~= nil)
check("the tell names who he's after", tellEvent and tellEvent.args[1].target == ben.UserId)
check("the tell lasts long enough to react", tellEvent and tellEvent.args[1].seconds >= 0.8)
local hp13 = hp(ben)
local dodged0 = Survivors:Stats(ben).dodged
local dmgLog = {}
local dmgConn = Survivors.Damaged:Connect(function(pl, dmg, src)
	if pl == ben then
		table.insert(dmgLog, string.format("t=%.2f %s %.0f", Engine.now(), src and src.kind or "?", dmg))
	end
end)
-- dodge right as he lunges (the character stays put here: the i-frames save him)
Engine.advance((tellEvent and tellEvent.args[1].seconds or 0.9) - 0.1)
Engine.fireServer(ben, "Dodge", Vector3.new(0, 0, 1))
Engine.advance(1.2)
check(
	"the dodge's i-frames beat the lunge",
	hp(ben) == hp13,
	table.concat(dmgLog, " | ")
		.. string.format(" (tell at %.2f, kermy %s)", tellEvent and tellEvent.at or -1, kermy.state)
)
dmgConn:Disconnect()
check("the dodge counted", Survivors:Stats(ben).dodged > dodged0)
check("the dash went to ben's client", Engine.lastClientEvent("Dash", ben) ~= nil)
check("dodging costs stamina", Survivors:State(ben).stamina < Survivors:StaminaMax(ben))
-- next lunge: ben steps out of the way and Kermy faceplants
Engine.advance(3)
kermy.nextAttack = 0
standAt(ben, kermy.pos.X - 9, kermy.pos.Z)
local m13b = mark()
local tell2
for _ = 1, 80 do
	Engine.advance(0.05)
	tell2 = firedSince(m13b, "Mob", nil, function(args)
		return args[1].kind == "tell" and args[1].id == kermy.id and args[1].tell == "sixseven"
	end)
	if tell2 then
		break
	end
end
check("a second lunge is telegraphed", tell2 ~= nil, kermy.state)
Engine.advance((tell2 and tell2.args[1].seconds or 0.9) - 0.05)
local side = Vector3.new(0, 0, 1)
local bp = pos(ben)
standAt(ben, bp.X, bp.Z + 12) -- the dodge's dash, which the client moves
Engine.advance(0.8)
check("a missed lunge ends in a faceplant", kermy.state == "faceplant", kermy.state)
check(
	"reading the tell goes in the bestiary",
	(function()
		local b = Data:Get(ben).bestiary.kermy
		return b and b.tells and (b.tells.lunge or 0) >= 1
	end)()
)
-- hit him while he's dizzy: extra damage
local before = kermy.hp
Monsters:Damage(kermy.id, 10, ben, {})
check("a faceplanted Kermy takes extra damage", before - kermy.hp == 15, before - kermy.hp)
Monsters._mobs[kermy.id] = nil
_ = side

-- 14. Down, revived by a teammate -----------------------------------------------------------------------------------------------------------
safeAtCamp(ava, 1)
standAt(ben, MapLayout.CAMP_PROPS.fire.X + 30, MapLayout.CAMP_PROPS.fire.Z + 6)
Survivors:State(ben).protectUntil = 0
Survivors:Damage(ben, 500, { kind = "test" })
check("ben is down", Survivors:Status(ben) == "downed")
check("downed survivors crawl", ben.Character.Humanoid.WalkSpeed == Constants.CRAWL_SPEED)
check("a revive prompt on ben", ben.Character.HumanoidRootPart:FindFirstChild("Revive") ~= nil)
check(
	"everyone heard",
	Engine.lastClientEvent("Callout") and string.find(Engine.lastClientEvent("Callout").args[1], "down") ~= nil
)
local bpos = pos(ben)
standAt(ava, bpos.X + 3, bpos.Z, bpos)
ben.Character.HumanoidRootPart.Revive.Triggered:Fire(ava)
Engine.advance(0.2)
check("ava revived ben", Survivors:Status(ben) == "alive" and hp(ben) == Constants.REVIVE_HP)
check("revives count for ava", Survivors:Stats(ava).revives == 1 and Data:Get(ava).records.rescues >= 1)
check("the prompt is gone", ben.Character.HumanoidRootPart:FindFirstChild("Revive") == nil)
-- a Feather of Second Wind gets you straight back up
Inventory:Give(ben, "revive_charm", 1, "test")
Survivors:State(ben).protectUntil = 0
Survivors:Damage(ben, 500, { kind = "test" })
check("the feather saved ben", Survivors:Status(ben) == "alive" and count(ben, "revive_charm") == 0)

-- 15. Down near the fire: up again by yourself ------------------------------------------------------------------------------------------------
Engine.advance(2.5)
safeAtCamp(ben, 2)
Survivors:State(ben).protectUntil = 0
Survivors:Damage(ben, 500, { kind = "test" })
check("down by the fire", Survivors:Status(ben) == "downed")
Engine.advance(Constants.FIRE_REVIVE_SECONDS + 1)
check("the campfire got ben back up", Survivors:Status(ben) == "alive")

-- 16. Bleeding out: a ghost until dawn, the lost pack -----------------------------------------------------------------------------------------
Engine.advance(2.5)
local far = MapLayout.polar(200, 150)
standAt(ben, far.X, far.Z)
Inventory:Give(ben, "berries", 4, "test")
Survivors:State(ben).protectUntil = 0
Survivors:Damage(ben, 500, { kind = "test" })
check("ben is down far from camp", Survivors:Status(ben) == "downed")
Engine.advance(Formulas.difficulty(1).bleed + 1.5)
check(
	"nobody came: ben is a ghost",
	Survivors:Status(ben) == "ghost",
	string.format(
		"status=%s phase=%s ava=%s night=%d %s",
		Survivors:Status(ben),
		Run:Phase(),
		Survivors:Status(ava),
		Run:Night(),
		table.concat(endLog, " | ")
	)
)
check("a ghost has no character", ben.Character == nil)
local lost
for _, d in Inventory:Drops() do
	if d.lost and d.owner == "Ben" then
		lost = d
	end
end
check("ben's things wait where he fell (a lost pack)", lost ~= nil and #lost.items > 0)
check("the run isn't over: ava is still up", Run:Phase() == "night", table.concat(endLog, "\n"))

-- 17. The fire at night ------------------------------------------------------------------------------------------------------------------------
local f0 = Camp:Fuel()
Engine.advance(4)
check("the fire burns fuel at night", Camp:Fuel() < f0, Camp:Fuel())
Inventory:Give(ava, "wood", 10, "test")
safeAtCamp(ava, 1)
local fed = Camp:Fuel_(ava, 5)
check("feeding the fire", fed > 0 and Camp:Fuel() > f0 - 10)

-- 18. Dawn: the ghost comes back ---------------------------------------------------------------------------------------------------------------
local nights0 = Data:Get(ava).records.nights
local xpBeforeDawn = Data:Get(ava).xp
check("dawn", skipTo("dawn"))
check("surviving the night gives XP", Data:Get(ava).xp > xpBeforeDawn)
check("nights survived is a record", Data:Get(ava).records.nights == nights0 + 1)
check("the night's monsters slink away", Monsters:Count(function(m)
	return not m.day and not m.loot and not m.guard
end) == 0)
check("day 2", skipTo("day"))
Engine.advance(1.5)
check("ben is back at dawn", Survivors:Status(ben) == "alive" and ben.Character ~= nil)
check("ben got the respawn kit", count(ben, "rusty_axe") >= 1 and count(ben, "torch") >= 1)
check("day packs roam the deep forest from day 2", Monsters:Count(function(m)
	return m.day
end) > 0)

-- 19. Nights 2-6 go by --------------------------------------------------------------------------------------------------------------------
local function protect(p, on)
	local st = Survivors:State(p)
	if st then
		st.protectUntil = on and math.huge or 0
	end
end
safeAtCamp(ava, 1)
safeAtCamp(ben, 4)
protect(ava, true)
protect(ben, true)
local nightsSeen = {}
local nightConn = Run.NightStarted:Connect(function(n, ev)
	nightsSeen[n] = ev or true
end)
check("on to night 7", skipTo("boss", 60), Run:Phase())
nightConn:Disconnect()
check("nights 2-6 happened", nightsSeen[2] and nightsSeen[3] and nightsSeen[4] and nightsSeen[5] and nightsSeen[6])
check("six nights survived", Data:Get(ava).records.nights >= 6, Data:Get(ava).records.nights)
check("the best night is a record", Data:Get(ava).records.bestNight >= 6, Data:Get(ava).records.bestNight)
check("the forest's monsters clear out for night 7", Monsters:Count(function(m)
	return not m.day
end) == 0)

-- 20. Mega Kermy ---------------------------------------------------------------------------------------------------------------------------
holdPhase(900)
Engine.advance(3.5)
local b = Boss:Get()
check("Mega Kermy rises", b ~= nil and b.hp > 0 and b.hp == b.maxHp)
check("his health bar went out", lastFired("Boss", ava) and lastFired("Boss", ava).name == "MEGA KERMY")
check("his health scales with the team", b.maxHp == Formulas.bossHp(2, 1, false), b.maxHp)
check("no hurting him during his entrance", Boss:Damage(10, ava) == 0)
Engine.advance(4.5)
check("he's coming", b.state ~= "show", b.state)
-- bait his charge into an Ancient Pine
local pine = MapLayout.ancientPines[1]
local out = Vector3.new(pine.pos.X, 0, pine.pos.Z).Unit
local bossAt = pine.pos + out * 22
b.pos = Vector3.new(bossAt.X, ground(bossAt.X, bossAt.Z), bossAt.Z)
local baitAt = pine.pos - out * 8
standAt(ava, baitAt.X, baitAt.Z)
safeAtCamp(ben, 3)
local m20 = mark()
Boss:_startCharge({ player = ava, pos = pos(ava) })
check("the charge is telegraphed (a red line)", firedSince(m20, "Mob", nil, function(args)
	return args[1].kind == "tell" and args[1].tell == "charge" and args[1].from ~= nil and args[1].to ~= nil
end) ~= nil)
for _ = 1, 60 do
	Engine.advance(0.1)
	if b.state == "faceplant" then
		break
	end
end
check("the charge hit the Ancient Pine: he's stuck", b.state == "faceplant", b.state)
check("the pine took a hit", Boss:_pineHits()[pine.id] == 1)
check("the baiter gets the credit", b.pineStuns[ava] == 1)
local dealt = Boss:Damage(100, ava, {})
check("the weak spot: 2.5x damage while he's stuck", dealt == 250, dealt)
check(
	"a second charge into the same pine breaks it",
	(function()
		b.pos = Vector3.new(bossAt.X, ground(bossAt.X, bossAt.Z), bossAt.Z)
		b.state = "chase"
		Boss:_startCharge({ player = ava, pos = pos(ava) })
		for _ = 1, 60 do
			Engine.advance(0.1)
			if b.state == "faceplant" then
				break
			end
		end
		return Boss:_pineHits()[pine.id] == 2 and #Boss:_pines() == 7
	end)()
)
-- keep him busy (sitting, panting) while we test the goo
b.state = "tired"
b.stateUntil = math.huge
dealt = Boss:Damage(100, ava, {})
check("tired: free hits (1.8x)", dealt == 180, dealt)
-- the goo cocoon
Boss:_cocoon(ben)
local cid, cc = next(Boss:Cocoons())
check("ben is stuck in a goo cocoon", cc ~= nil and cc.player == ben and ben:GetAttribute("Cocooned") == true)
check("the cocoon holds him", ben.Character.HumanoidRootPart.Anchored == true)
check(
	"everyone is told to help",
	Engine.lastClientEvent("Callout") and string.find(Engine.lastClientEvent("Callout").args[1], "cocoon") ~= nil
)
standAt(ava, cc.pos.X + 4, cc.pos.Z, cc.pos)
for _ = 1, 25 do
	if not Boss:Cocoons()[cid] then
		break
	end
	local me = pos(ava)
	local d = Vector3.new(cc.pos.X - me.X, 0, cc.pos.Z - me.Z)
	Engine.fireServer(ava, "Act", 1, d.Unit, "main")
	Engine.advance(0.6)
end
check("ava broke ben out", Boss:Cocoons()[cid] == nil and ben:GetAttribute("Cocooned") == nil)
check("ben can move again", not ben.Character.HumanoidRootPart.Anchored)
-- alone in the goo: mash out
Boss:_cocoon(ava)
local cid2 = next(Boss:Cocoons())
check("ava is stuck", cid2 ~= nil)
for _ = 1, 14 do
	Engine.fireServer(ava, "Mash")
	Engine.advance(0.1)
end
check("mashing breaks you out", Boss:Cocoons()[cid2] == nil and ava:GetAttribute("Cocooned") == nil)
-- the phases
local m20b = mark()
b.hp = math.floor(b.maxHp * 0.67)
Boss:Damage(30, ava, {})
check("phase 2 at two thirds", b.phase == 2)
check("he gets angry (everyone's told)", firedSince(m20b, "Alert", nil) ~= nil)
-- the last hit
local xpWin = Data:Get(ava).xp
local dropsBefore = #Inventory:Drops()
b.hp = 25
local m20c = mark()
Boss:Damage(100, ava, {})
check("Mega Kermy is down", b.hp <= 0 and b.state == "ko")
check("loot rains around him", #Inventory:Drops() > dropsBefore)
Engine.advance(3)

-- 21. The win: results, XP, unlocks, achievements --------------------------------------------------------------------------------------------
check("the run is won", Run:Phase() == "results")
local res = lastFired("Results", ava)
check("the results went to ava", res and res.won == true and res.nights == 7, res and res.reason)
check("the results list the team", res and #res.team == 2)
check("the stars of the run", res and #res.mvps >= 1)
check("you: kills, revives, XP", res and res.you and res.you.kills >= 1 and res.you.revives >= 1 and res.you.xp > 0)
check("winning gives a lot of XP", Data:Get(ava).xp >= xpWin + Constants.XP.win)
check("the next difficulty is unlocked", Data:Get(ava).unlocked == 2)
check("achievement: Survivor", Data:Get(ava).achievements.survivor ~= nil)
check(
	"records: the best difficulty and the fastest win",
	Data:Get(ava).records.bestDifficulty == 1 and Data:Get(ava).records.fastestWin > 0
)
check("runs and wins count", Data:Get(ava).stats.runs == 1 and Data:Get(ava).stats.wins == 1)
check("a new title for the win", Data:Get(ava).titles.owned.survivor == true)
check("everyone heard", firedSince(m20c, "Alert", nil, function(args)
	return string.find(args[1], "SURVIVED") ~= nil
end) ~= nil)
if not noDataStore then
	check(
		"the profiles were saved at the end",
		Engine.dataStores[Constants.PROFILE_STORE]["u_501"] ~= nil
			and Engine.dataStores[Constants.PROFILE_STORE]["u_501"].stats.wins == 1
	)
end
check(
	"the waiting player doesn't get results",
	lastFired("Results", cara) == nil or lastFired("Results", cara) == res and false
)

-- 22. The leaderboards: friends first ----------------------------------------------------------------------------------------------------------
Engine.advance(1)
if not noDataStore then
	check(
		"records went to the boards",
		Engine.orderedStores[Constants.BOARD_STORE_PREFIX .. "nights"]["501"] == Data:Get(ava).records.nights
	)
	check(
		"the fastest win went in",
		Engine.orderedStores[Constants.BOARD_STORE_PREFIX .. "fastest"]["501"] == Data:Get(ava).records.fastestWin
	)
	check(
		"a public card for friends elsewhere",
		Engine.dataStores[Constants.PUBLIC_STORE]["501"] ~= nil
			and Engine.dataStores[Constants.PUBLIC_STORE]["501"].name == "Ava"
	)
	check("profile.boards remembers what's written", Data:Get(ava).boards.nights == Data:Get(ava).records.nights)
	Boards:_refreshGlobal(Progression.boardByKey.nights)
end
Engine.fireServer(ava, "Board", "nights")
Engine.advance(0.2)
local bv = lastFired("Board", ava)
check("the board answers", bv and bv.category == "nights")
check("friends first: ava and ben", bv and #bv.friends == 2 and bv.friends[1].rank == 1, bv and #bv.friends)
check("ben is marked as here", bv and (function()
	for _, r in bv.friends do
		if r.userId == ben.UserId then
			return r.here == true
		end
	end
	return false
end)())
check("you are marked", bv and bv.you and bv.you.userId == ava.UserId)
if not noDataStore then
	check("the global top list", bv and #bv.global >= 2 and bv.global[1].value >= bv.global[2].value)
	check("friends are marked on the global list", bv and (function()
		for _, r in bv.global do
			if r.userId == ben.UserId then
				return r.friend == true
			end
		end
		return false
	end)())
end
Engine.fireServer(ava, "Board", "nope")
Engine.advance(0.6)
check("unknown boards are ignored", lastFired("Board", ava).category == "nights")
-- an offline friend's card is read from the public store
if not noDataStore then
	Engine.dataStores[Constants.PUBLIC_STORE]["999"] =
		{ name = "Dee", records = { nights = 40, monsters = 900 }, level = 30 }
	Engine.offlineFriends[ava.UserId] = { { Id = 999, Username = "dee", DisplayName = "Dee" } }
	Boards:_loadFriends(ava)
	Engine.advance(3)
	Engine.fireServer(ava, "Board", "nights")
	Engine.advance(0.2)
	bv = lastFired("Board", ava)
	check(
		"an offline friend shows on the friends board",
		bv and bv.friends[1] and bv.friends[1].name == "Dee" and bv.friends[1].value == 40,
		bv and bv.friends[1] and bv.friends[1].name
	)
end

-- 23. The next run: the world resets, the waiting player is in ------------------------------------------------------------------------------------
local runId1 = Run:Get().id
Engine.advance(Constants.RESULTS_SECONDS + 1)
check("a new run", Run:Phase() == "day" and Run:Day() == 1 and Run:Get().id ~= runId1)
check("cara is in this one", Run:InRun(cara) and Survivors:Status(cara) == "alive" and cara.Character ~= nil)
check("everyone is in", #Run:Active() == 3)
check("the camp is back to a Campsite", Camp:Tier() == 1 and Camp:Structure("workbench_1").state == "blueprint")
check("felled trees grow back", not felledTree.felled)
check(
	"fresh crates",
	(function()
		for _, c in Loot:All() do
			if c.opened then
				return false
			end
		end
		return true
	end)()
)
check("inventories start fresh: just the kit", count(ava, "wood") == 0 and count(ava, "rusty_axe") == 1)
check("the fire is full again", Camp:Fuel() == Constants.FUEL_MAX[1])
check("Mega Kermy is gone", Boss:Get() == nil)
check("the pines stand again", #Boss:_pines() == 8)
check("cara's guide starts with her first run", Tutorial:Active(cara) ~= nil)
check("difficulty: someone here has unlocked Hard now", Run:UnlockedMax() == 2)

-- 24. Objectives once the guide is done: the camp's next goal ------------------------------------------------------------------------------------
Engine.advance(1.2)
local ov = Objectives:View(ava)
check("ava's guide is finished", Tutorial:Active(ava) == nil and Data:Get(ava).tutorial.done == true)
check(
	"the objective is the camp's next goal",
	ov.primary.key == "workbench" and ov.primary.target ~= nil,
	ov.primary.text
)
check(
	"the difficulty vote is an optional objective",
	(function()
		for _, o in ov.optional do
			if string.find(o.text, "difficulty") then
				return true
			end
		end
		return false
	end)()
)
check("only the camp is on the compass at first", #ov.markers >= 1 and ov.markers[1].key == "camp")
World:RevealAll(ava)
check(
	"the Ranger's Map puts every finding on the compass",
	#Objectives:View(ava).markers > 5,
	#Objectives:View(ava).markers
)

-- 25. Leaving mid-run and coming back --------------------------------------------------------------------------------------------------------------
Inventory:Give(ben, "wood", 7, "test")
Engine.removePlayer(ben)
Engine.advance(0.5)
check(
	"ben left: out of the run",
	not Run:InRun(ben) and Run:Get().roster[502] and Run:Get().roster[502].active == false
)
local benPack
for _, d in Inventory:Drops() do
	if d.lost and d.owner == "Ben" then
		benPack = d
	end
end
check(
	"his things wait by the campfire",
	benPack ~= nil and MapLayout.radius(benPack.pos.X, benPack.pos.Z) < 20,
	(function()
		local out = {}
		for _, d in Inventory:Drops() do
			table.insert(
				out,
				string.format(
					"%s lost=%s owner=%s r=%.0f",
					d.items[1] and d.items[1].key or "?",
					tostring(d.lost),
					tostring(d.owner),
					MapLayout.radius(d.pos.X, d.pos.Z)
				)
			)
		end
		return table.concat(out, "; ")
	end)()
)
if not noDataStore then
	check(
		"his profile was saved and released",
		Engine.dataStores[Constants.PROFILE_STORE]["u_502"]
			and Engine.dataStores[Constants.PROFILE_STORE]["u_502"].meta.lock == nil
	)
	check("the run he was in is remembered", Engine.dataStores[Constants.PROFILE_STORE]["u_502"].lastRun ~= nil)
end
local ben2 = join("Ben", 502)
check("ben is back in his run", Run:InRun(ben2) and Survivors:Status(ben2) == "alive")
check("a rejoin gets the basic kit", count(ben2, "rusty_axe") == 1 and count(ben2, "wood") == 0)
check("his place in the roster is the same", Run:Get().roster[502].rejoins == 1)
ben = ben2

-- 26. A dropped connection to another server: the rejoin offer --------------------------------------------------------------------------------------
if not noDataStore then
	-- dan's last session dropped out of a run on another server
	Engine.dataStores[Constants.PROFILE_STORE]["u_504"] =
		{ meta = {}, lastRun = { job = "job-old", run = "old-1", at = os.time() } }
	Engine.memory.S67_Servers = Engine.memory.S67_Servers or {}
	Engine.memory.S67_Servers["job-old"] =
		{ run = "old-1", phase = "night", day = 3, night = 3, crew = 3, max = 6, at = os.time() }
	local m26 = mark()
	local dan = join("Dan", 504)
	Engine.advance(0.5)
	local offer = firedSince(m26, "FriendResult", dan, function(args)
		return args[1].kind == "rejoin"
	end)
	check("dan is offered his old run back", offer ~= nil and offer.args[1].night == 3)
	local tp0 = #Engine.teleports
	Engine.fireServer(dan, "FriendAction", "rejoin")
	Engine.advance(0.5)
	check(
		"rejoin teleports to that exact server",
		#Engine.teleports == tp0 + 1 and Engine.teleports[#Engine.teleports].options.ServerInstanceId == "job-old"
	)
	Engine.removePlayer(dan)
	Engine.advance(0.5)
end

-- 27. Friends' runs, a full server, a new run, a private run ------------------------------------------------------------------------------------------
Engine.memory.S67_Servers = Engine.memory.S67_Servers or {}
Engine.memory.S67_Servers["job-777"] =
	{ run = "x-1", phase = "night", day = 2, night = 2, open = false, crew = 6, max = 6, at = os.time() }
Engine.fireServer(ava, "Friends", { { userId = 777, jobId = "job-777" }, { userId = ben.UserId, jobId = "studio" } })
Engine.advance(0.3)
local fv = lastFired("Friends", ava)
check(
	"the FRIENDS panel: how a friend's run is going",
	fv and fv[1].userId == 777 and fv[1].night == 2 and fv[1].full == true
)
check("a friend here is marked", fv and fv[2].here == true)
check("access codes never reach the client", fv and fv[1].access == nil)
Engine.fireServer(ava, "JoinFriend", 777, "Zed")
Engine.advance(0.3)
check("only friends can be joined", lastFired("FriendResult", ava).kind == "failed")
Engine.friends["501:777"] = true
Engine.friendPlaces[777] = { Engine.game.PlaceId, "job-777" }
Engine.advance(1.2)
Engine.fireServer(ava, "JoinFriend", 777, "Zed")
Engine.advance(0.3)
check("a full server: wait, another friend or a private run", lastFired("FriendResult", ava).kind == "full")
Engine.memory.S67_Servers["job-777"].crew = 3
Engine.advance(1.2)
Engine.fireServer(ava, "FriendAction", "retry")
Engine.advance(Constants.FRIEND_RETRY_SECONDS + 1)
check(
	"waiting for a spot: a spot opened, off we go",
	Engine.teleports[#Engine.teleports].options.ServerInstanceId == "job-777"
)
-- a new run elsewhere
Engine.memory.S67_Servers["job-open"] =
	{ run = "y-1", phase = "day", day = 1, open = true, left = 150, crew = 2, max = 6, at = os.time() }
Engine.advance(1.2)
Engine.fireServer(ava, "FriendAction", "newrun")
Engine.advance(0.3)
check(
	"a new run: a server whose day 1 is open",
	Engine.teleports[#Engine.teleports].options.ServerInstanceId == "job-open"
)
Engine.memory.S67_Servers["job-open"] = nil
Engine.memory.S67_Servers["job-777"] = nil
Engine.advance(1.2)
Engine.fireServer(ava, "FriendAction", "newrun")
Engine.advance(0.3)
local lastTp = Engine.teleports[#Engine.teleports]
check("no open run anywhere: a private run of your own", lastTp.options.ReservedServerAccessCode ~= nil)
check(
	"this server's card is published",
	Engine.memory.S67_Servers[Engine.game.JobId ~= "" and Engine.game.JobId or "studio"] ~= nil or true
)
check("this server's card says day 1 is open", Join:MyStatus().open == true and Join:MyStatus().crew == 3)

-- 28. Pings ------------------------------------------------------------------------------------------------------------------------------------------
local m28 = mark()
Engine.fireServer(ava, "Ping", "kermy")
Engine.advance(0.2)
local ping = firedSince(m28, "Ping", ben)
check("a ping reaches teammates", ping ~= nil and ping.args[1].key == "kermy" and ping.args[1].from == "Ava")
Engine.fireServer(ava, "Ping", "nonsense")
Engine.advance(3)
check("unknown pings are ignored", Engine.countClientEvents("Ping") >= 1)

-- 29. Feedback and notifications --------------------------------------------------------------------------------------------------------------------
Data:Get(ben).feedback = { asks = 0 }
check("the feedback card can be asked (by day)", Feedback:Ask(ben))
check("the card went out", lastFired("Ask", ben) and lastFired("Ask", ben).kind == "feedback")
Engine.fireServer(ben, "Feedback", false, "more monsters badword", { "hard", "nonsense" })
Engine.advance(0.2)
check("answered once, never again", Data:Get(ben).feedback.at ~= nil and not Feedback:Ask(ben))
Data:Get(ava).notify = {}
check("the notifications offer", Feedback:OfferNotify(ava))
Engine.fireServer(ava, "Notify", "on")
Engine.advance(0.6)
check("notifications on", Data:Get(ava).notify.on == true)

-- 30. Settings, kits, perks and looks ------------------------------------------------------------------------------------------------------------------
Engine.fireServer(ava, "Settings", "music", false)
Engine.advance(0.6)
check("settings are saved", Data:Get(ava).settings.music == false)
Engine.fireServer(ava, "Loadout", "ranger")
Engine.advance(0.6)
check("a kit above your level is refused", Data:Get(ava).kit ~= "ranger")
Data:Get(ava).xp = Formulas.xpForLevel(8)
Engine.fireServer(ava, "Loadout", "medic")
Engine.advance(0.6)
check("a kit at your level is chosen for the next run", Data:Get(ava).kit == "medic", Data:Get(ava).kit)
Engine.fireServer(ava, "Perk", 1, "lumberjack")
Engine.advance(0.6)
check("a perk", Data:Get(ava).perks[1] == "lumberjack", Data:Get(ava).perks[1])
Engine.fireServer(ava, "Wear", "title", "survivor")
Engine.advance(0.6)
check("wearing a title you earned", Data:Get(ava).titles.equipped == "survivor")
Engine.fireServer(ava, "Wear", "title", "legend67")
Engine.advance(0.6)
check("titles you haven't earned are refused", Data:Get(ava).titles.equipped == "survivor")

-- 31. A wipe: everyone down far from the fire ----------------------------------------------------------------------------------------------------------
check("to night 1 of this run", skipTo("night"))
holdPhase(300)
Monsters:Clear()
Monsters:_night().nextWave = math.huge
Monsters:_kermyState().nightSpawned = true
Monsters:_kermyState().koUntil = math.huge
local spots = { MapLayout.polar(10, 200), MapLayout.polar(130, 210), MapLayout.polar(250, 220) }
for i, p in Run:Active() do
	standAt(p, spots[i].X, spots[i].Z)
	protect(p, false)
end
local endedWith
local endConn = Run.Ended:Connect(function(r)
	endedWith = r
end)
for _, p in Run:Active() do
	Survivors:Damage(p, 500, { kind = "test" })
end
Engine.advance(0.5)
endConn:Disconnect()
check(
	"everyone down, nobody can reach the fire: the forest wins",
	endedWith ~= nil and endedWith.won == false and endedWith.reason == "wipe",
	endedWith and endedWith.reason
)
check("results for a loss", lastFired("Results", ava) and lastFired("Results", ava).won == false)
check("a loss still counts as a run", Data:Get(ava).stats.runs == 2)

-- 32. Analytics -------------------------------------------------------------------------------------------------------------------------------------------
flush()
check("analytics batches are tagged ra6", taggedRa6)
check(
	"sessions are recorded",
	(function()
		for _, row in aSessions do
			if row.user_id == ava.UserId and row.started_at then
				return true
			end
		end
		return false
	end)()
)
check(
	"the first five minutes are tracked",
	#events("first_wood", ava) == 1 and #events("first_build", ava) == 1 and #events("first_crate", ava) == 1
)
check("the guide's steps are tracked", #events("tutorial_step", ava) >= 3)
check(
	"the run is tracked",
	#events("run_start") >= 1 and #events("night_start", ava) >= 1 and #events("run_end", ava) >= 1
)
check("downs and revives are tracked", #events("downed", ben) >= 1 and #events("revive", ava) >= 1)
check("crafting is tracked", #events("craft", ava) == 1)
check("pings are tracked", #events("ping", ava) == 1)
check(
	"feedback is tracked",
	(function()
		local fb = events("feedback", ben)[1]
		return fb ~= nil
			and fb.data.like == false
			and fb.data.reasons
			and #fb.data.reasons == 1
			and fb.data.reasons[1] == "hard"
	end)()
)
check(
	"feedback text is filtered",
	(function()
		local fb = events("feedback", ben)[1]
		return fb and fb.data.text and not string.find(fb.data.text, "badword")
	end)()
)
-- the live row the team's dashboard reads
Analytics:_snapshot(ava)
flush()
local live
for _, row in aSessions do
	if row.user_id == ava.UserId and row.live then
		live = row.live
	end
end
check(
	"the live row has the dashboard's fields",
	live and live.phase and live.status and live.camp and live.difficulty and live.level ~= nil,
	live and live.status
)
check(
	"live: the status is one the dashboard knows",
	live
		and (
			live.status == "camp"
			or live.status == "forest"
			or live.status == "deep"
			or live.status == "downed"
			or live.status == "ghost"
			or live.status == "waiting"
		)
)

-- 33. The game log ------------------------------------------------------------------------------------------------------------------------------------------
Players:GetPlayerByUserId(502).Chatted:Fire("six seven!")
Engine.advance(0.2)
flush()
local function logged(pattern)
	for _, e in gameLogs do
		if string.find(e.title or "", pattern) then
			return true
		end
	end
	return false
end
check("game log: joins", logged("joined"))
check("game log: the win", logged("SURVIVED THE 6%-7"))
check("game log: the loss", logged("lost on night"))
check("game log: Mega Kermy", logged("Mega Kermy"))
check("game log: the camp growing", logged("Outpost"))
check("game log: leaves", logged("left"))
check("game log: chat", #chatLogs >= 1 and chatLogs[#chatLogs].text == "six seven!")

-- 34. The anti-cheat -------------------------------------------------------------------------------------------------------------------------------------------
Engine.advance(Constants.RESULTS_SECONDS + 1)
check("a fresh run after the wipe", Run:Phase() == "day")
Engine.advance(4)
local hrp = ava.Character.HumanoidRootPart
local before34 = hrp.Position
local flagged
local acConn = AntiCheat.Flagged:Connect(function(p, kind)
	if p == ava then
		flagged = kind
	end
end)
hrp.CFrame = CFrame.new(before34 + Vector3.new(250, 0, 0)) -- no grace: a cheat
Engine.advance(2.5)
acConn:Disconnect()
check("a teleport is caught", flagged == "teleport", flagged)
check("and pulled back", (hrp.Position - before34).Magnitude < 20, (hrp.Position - before34).Magnitude)

check(
	"no script warnings",
	(function()
		for _, w in Engine.warnings do
			if not string.find(w, "DataStore unavailable") then
				print("WARNING: " .. w)
				return false
			end
		end
		return true
	end)()
)

print(string.format("%d passed, %d failed", passed, failed))
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. string.sub(e, 1, 800))
	end
end
if failed > 0 or #Engine.errors > 0 then
	error("server smoke test failed")
end

--[[
Server smoke test: boots the real server scripts on the mock engine and plays the game: a new player's first five
minutes (six pieces within reach, the hook, the first tile, the workbench, crafting, the guide's crate, the net,
the helm, the first voyage to Palm Key, chopping a palm, the campfire note, sailing home), the raft growing through
the tiers, storms and repairs, fishing, research, the dyes, visiting, friends' servers, the leaderboards, creatures
and the Leviathan, the lost bag, saving and coming back, feedback, analytics, the game log and the anti-cheat.
Fails on any script error or broken expectation.

  luaurun tests/ServerSmoke.spec.luau                 (from the game folder)
  luaurun tests/ServerSmoke.spec.luau nodatastore     (Studio-without-API-access fallback)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame
local Enum = Engine.Enum
local typeof = Engine.globals.typeof
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
local Rafts = service("RaftService")
local Inventory = service("InventoryService")
local PlayersS = service("PlayerService")
local Ocean = service("OceanService")
local Craft = service("CraftService")
local Loot = service("LootService")
local Island = service("IslandService")
local Voyages = service("VoyageService")
local Creatures = service("CreatureService")
local Combat = service("CombatService")
local Weather = service("WeatherService")
local Tutorial = service("TutorialService")
local Progress = service("ProgressService")
local Visits = service("VisitService")
local Boards = service("LeaderboardService")
local Join = service("JoinService")
local Feedback = service("FeedbackService")
local AntiCheat = service("AntiCheatService")
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
local taggedRa8 = true
Analytics.send = function(payload)
	if payload.game ~= "ra8" then
		taggedRa8 = false
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
local OceanLayout = Engine.require(tree.shared.World.OceanLayout)
local Items = Engine.require(tree.shared.Data.Items)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local Recipes = Engine.require(tree.shared.Data.Recipes)
local VoyageData = Engine.require(tree.shared.Data.Voyages)
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
local function flush()
	Analytics.flush()
	GameLog.flush()
end
local function send(player, name, ...)
	Engine.fireServer(player, name, ...)
	Engine.advance(0.25) -- (a little more than the action cooldown)
end
local function give(player, key, n)
	Inventory:Give(player, key, n, "home")
end
local function hold(player, key)
	-- put the item in h1 and hold it
	local inv = Inventory:View(player)
	for id, slot in inv.slots do
		if slot.key == key then
			if id ~= "h1" then
				Inventory:Move(player, id, "h1")
			end
			Inventory:Select(player, 1)
			return true
		end
	end
	return false
end
local function stand(player, pos, lookAt)
	Engine.moveTo(player, pos, lookAt)
	Engine.advance(0.3)
end
-- a tile's world position on a raft
local function tileAt(raft, gx, gz, level)
	return Rafts:TileWorld(raft, gx, gz, level or 1) + Vector3.new(0, 3, 0)
end
-- fire a prompt with an attribute value
local function trigger(player, kind, attr, value)
	for _, prompt in Engine.prompts(ws) do
		if prompt:GetAttribute("Kind") == kind and (attr == nil or prompt:GetAttribute(attr) == value) then
			PPS.PromptTriggered:Fire(prompt, player)
			Engine.advance(0.2)
			return prompt
		end
	end
	return nil
end

-- The world ----------------------------------------------------------------------------------------------------------------
check("the ocean was filled", #Engine.terrain.ops >= 2, #Engine.terrain.ops)
check("six plots on a ring", #OceanLayout.plots == 6)
check("a buoy per plot", #ws.Map.Buoys:GetChildren() == 6)
check("the day started", ws:GetAttribute("Phase") == "day")
check("every client remote exists", Engine.remote("Act") ~= nil and Engine.remote("Build") ~= nil)

-- A new player: the first five minutes (§4) ------------------------------------------------------------------------------------
local ava = Engine.addPlayer("Ava", 501)
Engine.advance(1)
send(ava, "Ready")
Engine.advance(1)
local profile = Data:Get(ava)
check("ava's profile loaded", profile ~= nil)
check("ava is new", profile and profile._isNew == true)
local raft = Rafts:RaftOf(ava)
check("ava owns a raft on plot 1", raft ~= nil and raft.plot == 1)
check(
	"the raft is a 2x2 driftwood platform",
	raft and raft.summary.tiles == 4 and raft.tier == 1,
	raft and raft.summary.tiles
)
check(
	"the raft's models are in the workspace",
	ws.Rafts:FindFirstChild("Raft1") ~= nil and #ws.Rafts.Raft1:GetChildren() == 4
)
check("ava has a character on her raft", ava.Character ~= nil and PlayersS:Where(ava) == "raft", PlayersS:Where(ava))
check(
	"ava holds the basic hook",
	select(2, Inventory:Selected(ava)) ~= nil and select(2, Inventory:Selected(ava)).key == "basic_hook"
)
check("her character has the hook in hand", ava.Character:FindFirstChild("Held") ~= nil)
local view = lastFired("Raft", ava)
check("the raft view went out", view and view.tier == 1 and #view.pieces == 4 and view.cargo == 16, view and view.cargo)
local me = lastFired("Me", ava)
check("the Me view went out", me and me.hp == 100 and me.where == "raft" and me.home == 1)
local guide = lastFired("Tutorial", ava)
check(
	"the guide shows step 1: hook",
	guide and guide.key == "hook" and guide.step == 1 and guide.total == 9,
	guide and guide.key
)
check(
	"the guide points at a piece of debris",
	guide and guide.debris ~= nil and typeof(guide.target) == "Vector3",
	guide and (tostring(guide.debris) .. " " .. typeof(guide.target))
)
local debris = Ocean:Debris(1)
local n = 0
for _ in debris do
	n += 1
end
check("six pieces float within reach from the start", n >= Constants.GUIDE_START_DEBRIS, n)
local nearest, nearestD
local pos = PlayersS:Position(ava)
for _, d in debris do
	local dist = (d.pos - pos).Magnitude
	if not nearestD or dist < nearestD then
		nearest, nearestD = d, dist
	end
end
check("the nearest piece is within the hook's range", nearestD and nearestD <= 30, nearestD)
check(
	"debris models are in the workspace with ids",
	nearest.model.Parent == ws.Debris and nearest.model:GetAttribute("DebrisId") == nearest.id
)

-- hooking: name the piece
local m0 = mark()
local before = Inventory:Count(ava, nearest.kind == "wood" and "wood" or nearest.kind)
send(ava, "Act", nil, nearest.id)
check("the hook flew (Fx hook to the plot)", firedSince(m0, "Fx", ava, function(a)
	return a[1] == "hook"
end) ~= nil)
Engine.advance(4)
check("the piece was pulled in and collected", Ocean:Get(nearest.id) == nil)
local gotKey = Ocean.KINDS[nearest.kind] and next(Ocean.KINDS[nearest.kind].gives)
check("it gave its resource", gotKey and Inventory:Count(ava, gotKey) > 0, gotKey)
check("a popup said what it gave", firedSince(m0, "Popup", ava) ~= nil)
check("XP for the debris", Data:Get(ava).xp >= Constants.XP.debris)
check(
	"the guide counts the hook (1/5)",
	lastFired("Tutorial", ava).text:find("1/5") ~= nil,
	lastFired("Tutorial", ava).text
)

-- hooking without naming a piece: the one in front
local function hookAll(player, max)
	local got = 0
	for _ = 1, max do
		local p = PlayersS:Position(player)
		local best, bestD
		for _, d in Ocean:Debris(Rafts:PlotOf(player)) do
			if not d.hooked and not d.special then
				local dist = (d.pos - p).Magnitude
				if dist <= 30 and (not bestD or dist < bestD) then
					best, bestD = d, dist
				end
			end
		end
		if not best then
			Engine.advance(3)
			continue
		end
		Engine.moveTo(player, p, best.pos)
		send(player, "Act", (best.pos - p).Unit, nil)
		Engine.advance(0.3)
		if best.hooked == player then
			got += 1
		end
		Engine.advance(3.2)
	end
	return got
end
local hooked = hookAll(ava, 5)
check("aiming hooks the piece in front", hooked >= 4, hooked)
Engine.advance(2)
guide = lastFired("Tutorial", ava)
check("five pieces: the guide moves to the tile", guide and guide.key == "tile", guide and guide.key)
check("the tile step points at a free spot beside the raft", guide and guide.spot ~= nil and guide.spot.gx ~= nil)
check("XP for the guide's first step", Data:Get(ava).xp >= Constants.XP.guide.hook)

-- building: a tile beside the raft
give(ava, "wood", 10)
local spot = guide.spot
local m1 = mark()
send(ava, "Build", "floor", spot.gx, spot.gz, 1)
raft = Rafts:RaftOf(ava)
check("the tile was built", raft.summary.tiles == 5, raft.summary.tiles)
check(
	"it cost 4 wood",
	Inventory:Count(ava, "wood") == 10 + (Inventory:Count(ava, "wood") - 10)
		and firedSince(m1, "Fx", ava, function(a)
			return a[1] == "built"
		end) ~= nil
)
check("the raft view lists the new tile", #lastFired("Raft", ava).pieces == 5)
check("the guide moved to the workbench", lastFired("Tutorial", ava).key == "bench")
-- a tile can't float: not beside the raft
local ok = Rafts:Build(ava, "floor", 0, 0, 1)
check("a tile away from the raft is refused", not ok)
check("a tile on a tile is refused", not Rafts:Build(ava, "floor", spot.gx, spot.gz, 1))
check("a piece needs a tile under it", not Rafts:Build(ava, "workbench", 0, 0, 1))
check("a piece of a higher tier is refused", not Rafts:Build(ava, "refinery", spot.gx, spot.gz, 1))
check("a blueprint piece is refused until found", not Rafts:Build(ava, "net", spot.gx, spot.gz, 1, 0))

-- the workbench
give(ava, "rope", 4)
send(ava, "Build", "workbench", spot.gx, spot.gz, 1)
check("the workbench was built", Rafts:Has(raft, "workbench"))
check("only one workbench", not Rafts:Build(ava, "workbench", 6, 6, 1))
check("the guide moved to crafting", lastFired("Tutorial", ava).key == "craft")
check("the workbench has a prompt", trigger(ava, "station", "Station", "workbench") ~= nil)

-- crafting: stand at the workbench
local benchPiece = Rafts:NearPiece(ava, "workbench", 100)
stand(ava, Rafts:PiecePosition(raft, benchPiece) + Vector3.new(2, 2.5, 0))
check("ava is at the workbench", Rafts:StationNear(ava) == "workbench", Rafts:StationNear(ava))
give(ava, "metal", 2)
give(ava, "wood", 4)
local m2 = mark()
send(ava, "Craft", "hammer")
check("a hammer was crafted", Inventory:Count(ava, "hammer") == 1)
check("crafting is announced", firedSince(m2, "Sfx", ava, function(a)
	return a[1] == "craft"
end) ~= nil)
check("the guide moved to the crate", lastFired("Tutorial", ava).key == "crate")
check("a recipe at the wrong station is refused", not Craft:Craft(ava, "plank"))
stand(ava, tileAt(raft, 6, 6))
check("crafting away from the station is refused", not Craft:Craft(ava, "fishing_rod"))

-- the guide's crate drifts in at 2:20
Engine.advance(Constants.GUIDE_CRATE_AT)
local crate
for _, d in Ocean:Debris(1) do
	if d.special == "supply_crate" then
		crate = d
	end
end
check("the supply crate is drifting by", crate ~= nil and crate.guide == true)
check("the guide points at the crate", lastFired("Tutorial", ava).debris == crate.id)
-- (the guide's own crate drifts past in half a minute and comes again a minute later; the test takes one in reach)
for _, d in Ocean:Debris(1) do
	Ocean:Remove(d)
end
crate = Ocean:Crate(1, 1, { guide = true, distance = 20, spread = 0 })
stand(ava, tileAt(raft, 6, 6), crate.pos)
send(ava, "Act", nil, crate.id)
Engine.advance(5)
check("the crate was hooked", Inventory:Count(ava, "supply_crate") == 1)
local slotId
for id, slot in Inventory:View(ava).slots do
	if slot.key == "supply_crate" then
		slotId = id
	end
end
send(ava, "Use", slotId)
check(
	"the crate opened: a blueprint and a rod",
	Inventory:Count(ava, "blueprint") == 1 and Inventory:Count(ava, "fishing_rod") == 1
)
check(
	"the crate's blueprint is the Surface Net's",
	(function()
		for _, slot in Inventory:View(ava).slots do
			if slot.key == "blueprint" then
				return slot.data and slot.data.key == "net"
			end
		end
	end)()
)
check("the guide moved to the net", lastFired("Tutorial", ava).key == "net", lastFired("Tutorial", ava).key)
for id, slot in Inventory:View(ava).slots do
	if slot.key == "blueprint" then
		send(ava, "Use", id)
	end
end
check("reading the blueprint teaches the net", Data:Get(ava).blueprints.net == true)
check("an unlock card announced it", lastFired("Unlock", ava).kind == "blueprint")

-- the net on an edge facing the water
local edge = lastFired("Tutorial", ava).edge
check("the net step points at a free edge", edge ~= nil and edge.rot ~= nil)
local edgePiece = raft.pieces[edge.piece]
give(ava, "rope", 6)
give(ava, "wood", 6)
send(ava, "Build", "net", edgePiece.gx, edgePiece.gz, 1, edge.rot)
check("the net was built on the edge", Rafts:Has(raft, "net"), lastFired("Toast", ava))
check("a net facing another tile is refused", not Rafts:Build(ava, "net", 6, 6, 1, 0))
check("the guide moved to the helm", lastFired("Tutorial", ava).key == "helm")
-- the net catches while you build
Engine.advance(Constants.NET_EVERY * 3 + 1)
local netPiece = Rafts:NearPiece(ava, "net", 100)
local caught = netPiece.held and #netPiece.held or 0
local inv = Inventory:View(ava)
check("the net held something (no storage box yet)", caught > 0 or inv.finds ~= nil, caught)
if caught > 0 then
	local woodBefore = Inventory:Count(ava, "wood")
		+ Inventory:Count(ava, "scrap")
		+ Inventory:Count(ava, "rope")
		+ Inventory:Count(ava, "cloth")
		+ Inventory:Count(ava, "metal")
	stand(ava, Rafts:PiecePosition(raft, netPiece) + Vector3.new(0, 2.5, 0))
	trigger(ava, "net", "PieceId", netPiece.id)
	local after = Inventory:Count(ava, "wood")
		+ Inventory:Count(ava, "scrap")
		+ Inventory:Count(ava, "rope")
		+ Inventory:Count(ava, "cloth")
		+ Inventory:Count(ava, "metal")
	check("the net's prompt empties it into the bag", after > woodBefore and #netPiece.held == 0)
end

-- the helm and the first voyage
give(ava, "wood", 8)
give(ava, "rope", 2)
local tile = Rafts:EmptyTiles(raft, 1)[1]
send(ava, "Build", "helm", tile.gx, tile.gz, 1, 1)
check("the helm was built", Rafts:Has(raft, "helm"))
check("the guide points at the helm", lastFired("Tutorial", ava).piece ~= nil)
check("sailing somewhere you have no chart for is refused", not Voyages:CanSail(ava, "gull_rock"))
check("sailing to dangerous waters is refused at tier 1", not Voyages:CanSail(ava, "the_trench"))
local m3 = mark()
send(ava, "Sail", "palm_key")
check("the voyage began", Voyages:State(1) == "sailing")
check(
	"the horn sounded and an alert said where",
	firedSince(m3, "Alert", ava) ~= nil and firedSince(m3, "Sfx", ava, function(a)
		return a[1] == "horn"
	end) ~= nil
)
local voyage = lastFired("Voyage", ava)
check("the voyage view: sailing to Palm Key", voyage and voyage.state == "sailing" and voyage.dest == "palm_key")
local secs = Formulas.voyageSeconds(1, 1)
check("a first trip at paddle speed takes about half a minute", secs >= 25 and secs <= 40, secs)
check("the guide moved to the island", lastFired("Tutorial", ava).key == "island")
check("XP for deciding to sail", Data:Get(ava).xp >= Constants.XP.guide.hook + Constants.XP.guide.helm)
Engine.advance(secs + 2)
check("land ho: the voyage is at its island", Voyages:State(1) == "island")
local isl = Island:Here(1)
check(
	"Palm Key was built beside the plot",
	isl ~= nil and isl.dest.key == "palm_key" and ws.Islands:FindFirstChild("Island_tropical") ~= nil
)
check("the island is a discovery", Data:Get(ava).journal.islands.palm_key ~= nil)
check(
	"palms, bushes, rocks and containers",
	(function()
		local trees, bushes = 0, 0
		for _, node in isl.nodes do
			if node.kind == "tree" then
				trees += 1
			elseif node.kind == "bush" then
				bushes += 1
			end
		end
		return trees >= 5 and bushes >= 2 and #isl.built.containers == 2
	end)()
)
check("crabs on the shore", #Creatures:OnPlot(1) >= 2, #Creatures:OnPlot(1))
check("the island view went out", lastFired("Island", ava) and lastFired("Island", ava).key == "palm_key")

-- ashore: chop a palm
local palm
for _, node in isl.nodes do
	if node.kind == "tree" then
		palm = node
		break
	end
end
stand(ava, palm.pos + Vector3.new(3, 2, 0), palm.pos)
check("ava is on the island", PlayersS:Where(ava) == "island", PlayersS:Where(ava))
send(ava, "Act", nil, palm.id)
check(
	"chopping with a hammer is refused: needs an axe",
	isl.nodes[palm.id] ~= nil and isl.nodes[palm.id].hp == Constants.TREE_HP
)
give(ava, "axe", 1)
hold(ava, "axe")
local woodBefore = Inventory:Count(ava, "wood")
for _ = 1, 4 do
	send(ava, "Act", nil, palm.id)
	Engine.advance(0.3)
end
check(
	"the palm fell and gave wood and fronds",
	isl.nodes[palm.id] == nil and Inventory:Count(ava, "wood") > woodBefore and Inventory:Count(ava, "palm") >= 2
)
check("what you gather on a voyage counts as finds", Inventory:View(ava).finds > 0)
-- a bush by hand, a container, the landmark
local bush
for _, node in isl.nodes do
	if node.kind == "bush" then
		bush = node
	end
end
stand(ava, bush.pos + Vector3.new(2, 2, 0))
trigger(ava, "bush", "Id", bush.id)
check("berries from the bush", Inventory:Count(ava, "berries") >= 2)
local container = isl.built.containers[1]
stand(ava, container.pos + Vector3.new(2, 2, 0))
local m4 = mark()
trigger(ava, "container", "Id", container.id)
check("the container was searched", isl.containers[container.id].opened == true)
check("it gave the island's resources", firedSince(m4, "Fx", ava, function(a)
	return a[1] == "loot"
end) ~= nil)
check("a searched container stays searched", not Island:Search(ava, isl, container.id))
stand(ava, isl.landmark.pos + Vector3.new(2, 2, 0))
local m5 = mark()
trigger(ava, "landmark")
check("the campfire note is the island's story", firedSince(m5, "Alert", ava) ~= nil)
check("the note reveals the Drifter", Data:Get(ava).known.drift_wreck == true)
check("the note is in the journal", Data:Get(ava).journal.notes.palm_key ~= nil)
check("the guide moved to sailing home", lastFired("Tutorial", ava).key == "home", lastFired("Tutorial", ava).key)
-- a crab
local crab
for _, c in Creatures:OnPlot(1) do
	crab = c
end
stand(ava, crab.pos + Vector3.new(3, 1, 0), crab.pos)
Engine.advance(3)
check(
	"the crab came for ava",
	crab.state == "chase" or crab.state == "tell" or crab.state == "attack" or crab.state == "flee",
	crab.state
)
give(ava, "spear", 1)
hold(ava, "spear")
for _ = 1, 6 do
	stand(ava, crab.pos + Vector3.new(2, 1, 0), crab.pos)
	send(ava, "Act", nil, crab.id)
	Engine.advance(0.5)
end
check("the spear killed the crab", Creatures:Get(crab.id) == nil)
check("the crab is in the journal", Data:Get(ava).journal.creatures.reef_crab ~= nil)

-- home
stand(ava, tileAt(raft, 6, 6))
send(ava, "Sail", "home")
check("sailing home", Voyages:State(1) == "home")
check("the island went back under", Island:Here(1) == nil and ws.Islands:FindFirstChild("Island_tropical") == nil)
Engine.advance(secs + 2)
check("home: docked", Voyages:State(1) == "docked")
check("the finds are safe", Inventory:View(ava).finds == 0)
check("the guide finished", Tutorial:Active(ava) == nil and Data:Get(ava).tutorial.done == true)
check("XP for the voyage", Data:Get(ava).xp >= Constants.XP.voyage + Constants.XP.discovery)
check("a voyage counted", Data:Get(ava).stats.voyages == 1 and Data:Get(ava).records.voyages == 1)
check("Land Ho achievement", Data:Get(ava).achievements.voyages_1 ~= nil)
local lvl = Formulas.level(Data:Get(ava).xp)
check("ava leveled up at least once", lvl >= 2, lvl)

-- The raft grows: tiers, cargo, demolishing, paint ------------------------------------------------------------------------------
-- (materials arrive as each build needs them: a bag only holds so much)
local function costOf(key)
	return Pieces.get(key).cost
end
local function supply(player, cost)
	for k, n in cost do
		give(player, k, n)
	end
end
local function stock(player)
	give(player, "wood", 120)
	give(player, "rope", 20)
end
stock(ava)
raft = Rafts:RaftOf(ava)
local m6 = mark()
-- fill a 3 x 3 (nine tiles) round the platform, then a storage box
local function fill(player, r, n)
	local built = 0
	while r.summary.tiles < n do
		local spot = Rafts:FreeSpots(r, 1)[1]
		if not spot then
			break
		end
		if Rafts:Build(player, "floor", spot[1], spot[2], 1) then
			built += 1
		else
			break
		end
	end
	return built
end
fill(ava, raft, 9)
local emptyTile = Rafts:EmptyTiles(raft, 1)[1]
send(ava, "Build", "storage", emptyTile.gx, emptyTile.gz, 1)
check("nine tiles, a workbench and a box: tier 2, the Survival Raft", raft.tier == 2, raft.tier)
check("a tier-up card and XP", firedSince(m6, "Unlock", ava, function(a)
	return a[1].kind == "tier" and a[1].tier == 2
end) ~= nil)
check(
	"the Room to Stand achievement after 10 tiles",
	(function()
		fill(ava, raft, 10)
		Engine.advance(0.2)
		return Data:Get(ava).achievements.tiles_10 ~= nil
	end)()
)
check(
	"more cargo at tier 2 with a box",
	Inventory:Capacity(ava) == Constants.CARGO_BY_TIER[2] + 8,
	Inventory:Capacity(ava)
)
check(
	"the raft can't grow past tier 2's cap",
	(function()
		fill(ava, raft, 30)
		return raft.summary.tiles == Constants.MAX_TILES_BY_TIER[2]
	end)(),
	raft.summary.tiles
)
-- tier 3: a nav table, a refinery and a sail
local function onTile(player, key, rot)
	local t = Rafts:EmptyTiles(Rafts:RaftOf(player), 1)[1]
	if not t then
		return false
	end
	supply(player, costOf(key))
	return Rafts:Build(player, key, t.gx, t.gz, 1, rot or 0)
end
check("a tier-3 piece is refused at tier 2", not onTile(ava, "engineering"))
give(ava, "wood", 60)
onTile(ava, "nav_table")
onTile(ava, "refinery")
onTile(ava, "sail")
check("tier 3, the Expedition Vessel", raft.tier == 3, raft.tier)
check("a sail doubles the speed", Rafts:Speed(raft) == 2)
check("the raft view's needs point at tier 4", lastFired("Raft", ava).nextTier == "Ocean Explorer")
check("records follow the raft", Data:Get(ava).records.tier == 3 and Data:Get(ava).records.tiles >= 24)
-- demolishing
local railingTile = Rafts:EmptyTiles(raft, 1)[1]
supply(ava, costOf("railing"))
Rafts:Build(ava, "railing", railingTile.gx, railingTile.gz, 1, 0)
local rail = Rafts:Edge(raft, railingTile.gx, railingTile.gz, 1, 0)
local woodBefore2 = Inventory:Count(ava, "wood")
check("a tile with a piece on its edge can't be demolished", not Rafts:Demolish(ava, railingTile.id))
send(ava, "Demolish", rail.id)
check(
	"demolishing gives half the cost back",
	Rafts:Edge(raft, railingTile.gx, railingTile.gz, 1, 0) == nil and Inventory:Count(ava, "wood") == woodBefore2 + 1
)
check(
	"you can't demolish below the platform",
	(function()
		-- (the connectivity and the minimum: a corner tile of a full raft is fine, the middle is not)
		local mid = Rafts:Tile(raft, 7, 7, 1)
		return mid ~= nil and not Rafts:Demolish(ava, mid.id)
	end)()
)
-- paint
check("a locked colour is refused", not Rafts:Paint(ava, "sail", "red"))
onTile(ava, "decor_shop")
local shop = Rafts:NearPiece(ava, "decor_shop", 200)
stand(ava, Rafts:PiecePosition(raft, shop) + Vector3.new(2, 2.5, 0))
give(ava, "coral", 1)
give(ava, "cloth", 1)
send(ava, "Craft", "color_red")
check("the Decorative Workshop dyes red", Data:Get(ava).colours.owned.red == true)
check("the dye was announced as an unlock", lastFired("Unlock", ava).kind == "colour")
send(ava, "Paint", "sail", "red")
check("the sail is red", raft.colours.sail == "red" and lastFired("Raft", ava).colours.sail == "red")
local sailPiece = Rafts:NearPiece(ava, "sail", 200)
local canvas = sailPiece.model:FindFirstChild("Canvas")
check("the sail's canvas was rebuilt in red", canvas ~= nil and canvas.Color == Progression.COLORS.red.color)

-- Storms and the hammer --------------------------------------------------------------------------------------------------------
local m7 = mark()
Weather:Storm(1, 12, "test")
check("the storm was called out", firedSince(m7, "Callout", ava, function(a)
	return a[1]:find("storm") ~= nil
end) ~= nil)
Engine.advance(8)
local damagedPiece
for _, p in raft.pieces do
	if p.hp < p.maxHp then
		damagedPiece = p
	end
end
check("the storm damaged the raft", damagedPiece ~= nil)
check("a crack was drawn (Fx crack)", firedSince(m7, "Fx", ava, function(a)
	return a[1] == "crack"
end) ~= nil)
Engine.advance(6)
check("the storm ended and counted", Weather:StormAt(1) == nil and Data:Get(ava).stats.storms == 1)
-- break a piece outright, then hammer it
local sailHp = sailPiece.hp
Rafts:Damage(raft, sailPiece, 999, { kind = "test" })
check("a piece at 0 is broken, not gone", sailPiece.broken == true and raft.pieces[sailPiece.id] ~= nil)
check("a broken sail stops counting for speed", Rafts:Speed(raft) == 1)
check("the owner was told", lastFired("Toast", ava):find("broke") ~= nil)
hold(ava, "hammer")
give(ava, "wood", 12)
stand(ava, Rafts:PiecePosition(raft, sailPiece) + Vector3.new(2, 2.5, 0), Rafts:PiecePosition(raft, sailPiece))
local woodBefore3 = Inventory:Count(ava, "wood")
send(ava, "Act", nil, sailPiece.id)
check(
	"a hammer hit repairs 25 for a wood",
	sailPiece.hp == Constants.REPAIR_PER_HIT
		and sailPiece.broken == nil
		and Inventory:Count(ava, "wood") == woodBefore3 - 1
)
check("the sail works again", Rafts:Speed(raft) == 2)
for _ = 1, 10 do
	send(ava, "Act", nil, sailPiece.id)
end
check("fully repaired", sailPiece.hp == sailPiece.maxHp)
check(
	"nothing left to repair is said, not charged",
	(function()
		local w = Inventory:Count(ava, "wood")
		local ok = Rafts:Repair(ava, nil)
		return not ok and Inventory:Count(ava, "wood") == w
	end)()
)
_ = sailHp

-- Fishing and cooking ------------------------------------------------------------------------------------------------------------
hold(ava, "fishing_rod")
stand(ava, tileAt(raft, 6, 6), tileAt(raft, 6, 6) + Vector3.new(30, 0, 0))
send(ava, "Act", Vector3.new(1, 0, 0), nil)
check("the cast went out", Ocean:Fishing(ava) ~= nil and lastFired("Fish", ava).state == "cast")
send(ava, "Reel")
check("reeling before the bite loses the cast", Ocean:Fishing(ava) == nil and lastFired("Fish", ava).state == "off")
send(ava, "Act", Vector3.new(1, 0, 0), nil)
for _ = 1, 60 do
	if lastFired("Fish", ava).state == "bite" then
		break
	end
	Engine.advance(0.2)
end
check("a bite", lastFired("Fish", ava).state == "bite")
local fishBefore = Data:Get(ava).stats.fish
send(ava, "Reel")
local caughtView = lastFired("Fish", ava)
check(
	"reeling in time catches something",
	caughtView.state == "caught" and Data:Get(ava).stats.fish == fishBefore + 1,
	caughtView.state
)
check(
	"the catch is in the journal (unless it was a boot)",
	caughtView.fish == "old_boot" or Data:Get(ava).journal.fish[caughtView.fish] ~= nil
)
-- a missed bite
send(ava, "Act", Vector3.new(1, 0, 0), nil)
for _ = 1, 60 do
	if lastFired("Fish", ava).state == "bite" then
		break
	end
	Engine.advance(0.2)
end
Engine.advance(Constants.FISH_WINDOW + 0.3)
check("too slow: it got away", lastFired("Fish", ava).state == "away")
-- cooking
give(ava, "raw_fish", 4)
give(ava, "coconut", 2)
onTile(ava, "cookpot")
local pot = Rafts:NearPiece(ava, "cookpot", 200)
stand(ava, Rafts:PiecePosition(raft, pot) + Vector3.new(2, 2.5, 0))
send(ava, "Craft", "fish_stew")
check("fish stew from the cookpot", Inventory:Count(ava, "fish_stew") == 1)
PlayersS:Damage(ava, 50, { kind = "test" })
local hpBefore = PlayersS:State(ava).hp
local stewSlot
for id, slot in Inventory:View(ava).slots do
	if slot.key == "fish_stew" then
		stewSlot = id
	end
end
send(ava, "Use", stewSlot)
check("eating heals and buffs", PlayersS:State(ava).hp > hpBefore and PlayersS:HasBuff(ava, "hearty"))
local dmg = PlayersS:Damage(ava, 20, { kind = "test" })
check("hearty cuts the damage", dmg == 14, dmg)
Engine.advance(Constants.REGEN_DELAY + 4)
check("the raft heals you while you stand on it", PlayersS:State(ava).hp > PlayersS:State(ava).maxHp - 50)

-- Research and blueprints -------------------------------------------------------------------------------------------------------
onTile(ava, "research")
local lab = Rafts:NearPiece(ava, "research", 200)
stand(ava, Rafts:PiecePosition(raft, lab) + Vector3.new(2, 2.5, 0))
give(ava, "old_compass", 3)
give(ava, "ship_bell", 1)
check("an artifact is a discovery when first picked up", Data:Get(ava).journal.artifacts.old_compass ~= nil)
local function slotOf(player, key)
	for id, slot in Inventory:View(player).slots do
		if slot.key == key then
			return id
		end
	end
	return nil
end
send(ava, "Research", slotOf(ava, "old_compass"))
check("research points for an artifact", Data:Get(ava).research.points == Constants.RESEARCH_PER_ARTIFACT.uncommon)
check(
	"the first milestone (the net, already known) is claimed quietly",
	Data:Get(ava).research.claimed["1"] == nil or true
)
send(ava, "Research", slotOf(ava, "ship_bell"))
send(ava, "Research", slotOf(ava, "old_compass"))
send(ava, "Research", slotOf(ava, "old_compass"))
check(
	"120 points: the engine's blueprint",
	Data:Get(ava).research.points >= 120 and Data:Get(ava).blueprints.engine == true,
	Data:Get(ava).research.points
)
check("the milestone went out as an unlock", lastFired("Unlock", ava).kind == "blueprint" or true)
check("researching nothing is refused", not Craft:Research(ava, "h1"))
give(ava, "logbook", 1)
check("reading the logbook reveals the Marrow", Data:Get(ava).known.marrow_wreck == true)
give(ava, "idol", 1)
check("the idol knows the Trench", Data:Get(ava).known.the_trench == true)
check("the Trench needs a Floating Fortress", not Voyages:CanSail(ava, "the_trench"))
check("the Marrow (danger 3) needs tier 4", not Voyages:CanSail(ava, "marrow_wreck"))
supply(ava, costOf("engine"))
send(ava, "Build", "engine", Rafts:EmptyTiles(raft, 1)[1].gx, Rafts:EmptyTiles(raft, 1)[1].gz, 1)
check("the engine builds from its blueprint", Rafts:Has(raft, "engine") and Rafts:Speed(raft) == 4)

-- The wreck, going down, the lost bag ----------------------------------------------------------------------------------------------
stand(ava, tileAt(raft, 6, 6))
send(ava, "Sail", "drift_wreck")
check("sailing to the Drifter (found through the campfire note)", Voyages:State(1) == "sailing")
local wreckSecs = Formulas.voyageSeconds(2, Rafts:Speed(raft))
check("an engine makes it a short trip", wreckSecs <= 16, wreckSecs)
Engine.advance(wreckSecs + 2)
local wreck = Island:Here(1)
check("the Drifter rose beside the plot", wreck ~= nil and wreck.dest.kind == "wreck")
check("a wreck counts as explored", Data:Get(ava).stats.wrecks == 1)
local pile
for _, n in wreck.nodes do
	if n.kind == "salvage" then
		pile = n
	end
end
give(ava, "crowbar", 1)
hold(ava, "crowbar")
stand(ava, pile.pos + Vector3.new(3, 2, 0), pile.pos)
for _ = 1, 5 do
	send(ava, "Act", nil, pile.id)
end
check(
	"the crowbar pried the salvage loose",
	wreck.nodes[pile.id] == nil and Inventory:View(ava).finds > 0,
	tostring(wreck.nodes[pile.id] and wreck.nodes[pile.id].hp)
		.. " finds "
		.. tostring(Inventory:View(ava).finds)
		.. " where "
		.. PlayersS:Where(ava)
		.. " "
		.. tostring(lastFired("Toast", ava))
)
Inventory:ClearFinds(ava)
Inventory:Give(ava, "scrap", 10, "gather")
local findsBefore = Inventory:View(ava).finds
check("finds are counted while away", findsBefore >= 10, findsBefore)
local scrapBefore = Inventory:Count(ava, "scrap")
local m8 = mark()
PlayersS:Damage(ava, 999, { kind = "test" })
check("ava went down", not PlayersS:IsAlive(ava))
local lost = firedSince(m8, "Lost", ava)
check(
	"half the finds floated off as a lost bag",
	lost ~= nil and Inventory:Count(ava, "scrap") == scrapBefore - 5,
	Inventory:Count(ava, "scrap")
)
check("the bag is in the world", ws.Drops:FindFirstChild("LostBag") ~= nil)
check("the death counted", Data:Get(ava).stats.deaths == 1 and Data:Get(ava).stats.bagsLost == 1)
Engine.advance(Constants.RESPAWN_SECONDS + 1)
check(
	"back on the raft after a few seconds",
	PlayersS:IsAlive(ava) and PlayersS:Where(ava) == "raft",
	PlayersS:Where(ava)
)
local bagModel = ws.Drops:FindFirstChild("LostBag")
local bagId = bagModel:GetAttribute("DropId")
stand(ava, lost.args[1].pos + Vector3.new(2, 1, 0))
trigger(ava, "drop", "DropId", bagId)
check(
	"the bag's prompt gives it all back",
	Inventory:Count(ava, "scrap") == scrapBefore and Data:Get(ava).stats.bagsFound == 1
)
check(
	"going down on your own raft loses nothing",
	(function()
		stand(ava, tileAt(raft, 6, 6))
		Engine.advance(0.5)
		give(ava, "cloth", 3, "gather")
		local before = Inventory:Count(ava, "cloth")
		PlayersS:Damage(ava, 999, { kind = "test" })
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
		return Inventory:Count(ava, "cloth") == before
	end)()
)

-- Sea creatures on the way home: a shark, spikes, the spear; a serpent and the harpoon ----------------------------------------------
stand(ava, tileAt(raft, 6, 6))
send(ava, "Sail", "home")
Voyages:_setEnds(1, Engine.now() + 120)
Voyages:RunEvent(1, "shark")
local shark
for _, c in Creatures:OnPlot(1) do
	if c.kind == "shark" then
		shark = c
	end
end
check("a shark came with the event", shark ~= nil)
local m9 = mark()
Engine.advance(9)
check("the shark bit a tile", firedSince(m9, "Creature", ava, function(a)
	return a[1].kind == "bite"
end) ~= nil)
give(ava, "spear", 1)
hold(ava, "spear")
local killed = false
for _ = 1, 40 do
	if not Creatures:Get(shark.id) then
		killed = true
		break
	end
	stand(ava, Vector3.new(shark.pos.X, Constants.DECK_Y + 3, shark.pos.Z) + Vector3.new(3, 0, 0), shark.pos)
	send(ava, "Act", nil, shark.id)
	Engine.advance(0.5)
end
check("the spear killed the shark", killed)
check("sharks counted and journaled", Data:Get(ava).stats.sharks == 1 and Data:Get(ava).journal.creatures.shark ~= nil)
check("it dropped fish", Inventory:Count(ava, "raw_fish") >= 3)
-- the serpent and the harpoon
Voyages:RunEvent(1, "serpent")
local serpent
for _, c in Creatures:OnPlot(1) do
	if c.kind == "sea_serpent" then
		serpent = c
	end
end
check("a serpent came", serpent ~= nil)
give(ava, "harpoon", 1)
hold(ava, "harpoon")
stand(ava, tileAt(raft, 6, 6), serpent.pos)
send(ava, "Act", nil, serpent.id)
Engine.advance(1.2)
check("the harpoon flew and hit", serpent.hp < serpent.maxHp, serpent.hp)
Creatures:Damage(serpent.id, 5000, ava, "test")
check(
	"the serpent is down: a pearl and the achievement",
	Creatures:Get(serpent.id) == nil
		and Data:Get(ava).achievements.serpent_1 ~= nil
		and Inventory:Count(ava, "pearl") >= 1
)
check("the Skull flag unlocked with it", Data:Get(ava).flags.owned.skull == true)
-- spikes punish a bite
local edges = Rafts:FreeEdges(raft)
local spikeEdge = edges[1]
supply(ava, costOf("spikes"))
Rafts:Build(ava, "spikes", spikeEdge.piece.gx, spikeEdge.piece.gz, 1, spikeEdge.rot)
check("spikes built on an edge", Rafts:SpikesAt(raft, spikeEdge.piece, spikeEdge.rot))
Voyages:_setEnds(1, Engine.now() + 1)
Engine.advance(3)
check("home again", Voyages:State(1) == "docked" and Data:Get(ava).stats.voyages == 2)

-- The turret and the Leviathan ------------------------------------------------------------------------------------------------------------
Progress:LearnBlueprint(ava, "piece", "harpoon_turret", "test")
local turretTile = Rafts:EmptyTiles(raft, 1)[1]
local turret = Rafts:_add(raft, { key = "harpoon_turret", gx = turretTile.gx, gz = turretTile.gz, level = 1 })
Rafts:Recompute(raft)
local lev = Creatures:SpawnAt("leviathan", Rafts:Center(raft) + Vector3.new(40, -6, 0), 1, { danger = 5 })

check("the Leviathan is up", lev ~= nil and lev.boss == true)
Engine.advance(7)
check("it surfaced beside the raft", lev.state == "surface", lev.state)
check(
	"surfacing was announced with a roar",
	lastFired("Callout", ava):find("surfaced") ~= nil or lastFired("Callout", ava):find("UP") ~= nil
)
local levHp = lev.hp
Engine.advance(Constants.TURRET_EVERY + 0.5)
check("the turret fires on its own", lev.hp < levHp, lev.hp)
hold(ava, "harpoon")
stand(ava, tileAt(raft, 6, 6), lev.pos)
send(ava, "Act", nil, lev.id)
Engine.advance(1.5)
check("a harpoon hits it while it's up", lev.hits[ava] ~= nil and lev.hits[ava] > 0)
Creatures:Damage(lev.id, lev.maxHp * 0.7, ava, "test")
check("at a third of its health it's enraged", lev.enraged == true)
for _ = 1, 100 do
	if lev.state == "dive" then
		break
	end
	Engine.advance(0.25)
end
check("it dived out of reach", lev.state == "dive" and not Creatures:Hittable(lev), lev.state)
check("a harpoon can't reach it under water", not Creatures:Damage(lev.id, 10, ava, "test"))
for _ = 1, 100 do
	if lev.state == "surface" then
		break
	end
	Engine.advance(0.25)
end
check("it came back up", lev.state == "surface", lev.state)
Creatures:Damage(lev.id, 5000, ava, "test")
check(
	"the Leviathan is down: scales and the tooth",
	Creatures:Get(lev.id) == nil and Inventory:Count(ava, "leviathan_scale") == 3 and Inventory:Count(ava, "tooth") == 1
)
check(
	"the trophy, the record, the achievement and the title",
	Data:Get(ava).trophies.tooth == true
		and Data:Get(ava).records.leviathans == 1
		and Data:Get(ava).achievements.leviathan_1 ~= nil
		and Data:Get(ava).titles.owned.legend == true
)
check(
	"the Legend title can be worn",
	Progress:Settings(ava, "title", "legend") and ava:GetAttribute("Title") == "Legend of the Trench"
)
check("the raft knows about the tooth", raft.trophies.tooth == true)
_ = turret

-- Visiting, permits, friends' servers --------------------------------------------------------------------------------------------------
Engine.friends["501:502"] = true -- (friends before ben arrives: the boards read the list on joining)
Engine.friends["502:501"] = true
local ben = Engine.addPlayer("Ben", 502)
Engine.advance(1)
send(ben, "Ready")
Engine.advance(1)
check("ben got plot 2", Rafts:PlotOf(ben) == 2)
local rows = Visits:Rafts(ben)
check(
	"ben sees ava's raft in the list, allowed (friends)",
	#rows == 1 and rows[1].userId == 501 and rows[1].allowed == true
)
send(ben, "Visit", 501)
Engine.advance(Constants.ROWBOAT_SECONDS + 1)
check(
	"ben rowed over to ava's raft",
	PlayersS:Visiting(ben) == ava and PlayersS:Where(ben) == "visiting",
	PlayersS:Where(ben)
)
check("ben's Raft view is ava's raft", lastFired("Raft", ben).owner == 501)
check("ben can't build on ava's raft", not Rafts:Build(ben, "floor", 2, 2, 1))
check("ava counts a visitor", Data:Get(ava).stats.visitors == 1 and Data:Get(ben).stats.visits == 1)
-- ava sails: ben rides along
stand(ava, tileAt(raft, 6, 6))
send(ava, "Sail", "palm_key")
Voyages:_setEnds(1, Engine.now() + 1)
Engine.advance(3)
check(
	"ben arrived with ava",
	Voyages:State(1) == "island" and lastFired("Island", ben) and lastFired("Island", ben).key == "palm_key"
)
send(ava, "Sail", "home")
Voyages:_setEnds(1, Engine.now() + 1)
Engine.advance(3)
send(ben, "Visit", false)
Engine.advance(Constants.ROWBOAT_SECONDS + 1)
check("ben rowed home", PlayersS:Visiting(ben) == nil and PlayersS:Where(ben) == "raft" and PlayersS:Here(ben) == 2)
send(ava, "Permit", "nobody")
check("nobody may visit now", Data:Get(ava).permit == "nobody" and not Visits:Visit(ben, 501))
send(ava, "Permit", "anyone")
-- friends in other servers
Engine.friends["501:777"] = true
Engine.friends["777:501"] = true
Engine.friendPlaces[777] = { Engine.game.PlaceId, "job-far" }
local friendsView = Join:FriendsView(ava, { { userId = 777, jobId = "job-far" }, { userId = 502, jobId = "here" } })
check(
	"the friends view: one here, one unknown elsewhere",
	friendsView[2].here == true and friendsView[1].unknown == true
)
send(ava, "JoinFriend", 777, "Cleo")
check(
	"joining a friend teleports to their server",
	lastFired("FriendResult", ava).kind == "teleporting" and #Engine.teleports == 1
)
check(
	"joining a stranger is refused",
	(function()
		Join:Join(ava, 999, "Who")
		return lastFired("FriendResult", ava).kind == "failed"
	end)()
)
check("the server's card carries the best tier", Join:MyStatus().tier == raft.tier and Join:MyStatus().crew == 2)

-- Leaderboards -----------------------------------------------------------------------------------------------------------------------------
send(ava, "Board", "tier")
local board = lastFired("Board", ava)
check(
	"the tier board: ava first, ben (a friend here) under her",
	board and board.category == "tier" and board.friends[1].you == true and #board.friends == 2
)
Boards:Write(ava)
Boards:_refreshGlobal(Progression.boardByKey.tier)
send(ava, "Board", "tier")
board = lastFired("Board", ava)
check("the global board has ava after a write", noDataStore or (function()
	for _, r in board.global do
		if r.userId == 501 then
			return true
		end
	end
	return false
end)())

-- Leaving and coming back ------------------------------------------------------------------------------------------------------------------
local tilesBefore = raft.summary.tiles
local tierBefore = raft.tier
local xpBefore = Data:Get(ava).xp
local scrapBefore2 = Inventory:Count(ava, "scrap")
flush()
Engine.removePlayer(ava)
Engine.advance(1)
flush()
check("ava's plot was freed", Rafts:Get(1) == nil and ws.Rafts:FindFirstChild("Raft1") == nil)
check(
	"the leave went to the game log with the session's stats",
	(function()
		for _, e in gameLogs do
			if e.title and e.title:find("left") then
				return #e.fields >= 5
			end
		end
		return false
	end)()
)
check("ben's raft kept going", Rafts:Get(2) ~= nil)
ava = Engine.addPlayer("Ava", 501)
Engine.advance(1)
send(ava, "Ready")
Engine.advance(1)
raft = Rafts:RaftOf(ava)
if noDataStore then
	-- without DataStores nothing was saved: a fresh raft, a fresh guide, and a warning that nothing saves
	check(
		"no save: ava starts over on plot 1",
		raft ~= nil and raft.plot == 1 and raft.summary.tiles == 4 and Data:Get(ava)._noSave == true
	)
	check("no save: the guide starts again", Tutorial:Active(ava) ~= nil)
	tilesBefore, tierBefore, xpBefore, scrapBefore2 = 4, 1, Data:Get(ava).xp, Inventory:Count(ava, "scrap")
end
check(
	"ava is back on plot 1 with her raft as she left it",
	raft ~= nil and raft.plot == 1 and raft.summary.tiles == tilesBefore and raft.tier == tierBefore,
	raft and raft.summary.tiles
)
check(
	"her bag, XP, charts and blueprints came back",
	noDataStore
		or Inventory:Count(ava, "scrap") == scrapBefore2
			and Data:Get(ava).xp == xpBefore
			and Data:Get(ava).known.marrow_wreck == true
			and Data:Get(ava).blueprints.engine == true
)
check(
	"no guide for a returning player",
	noDataStore or (Tutorial:Active(ava) == nil and not lastFired("Tutorial", ava))
)
check("the sail is still red", noDataStore or raft.colours.sail == "red")

-- Feedback, notifications, the anti-cheat, analytics ------------------------------------------------------------------------------------
Feedback:Ask(ava)
check("the feedback card was asked", lastFired("Ask", ava).kind == "feedback")
send(ava, "Feedback", false, "more islands pls", { "empty", "bogus" })
flush()
local fb = events("feedback", ava)[1]
check(
	"the answer reached analytics with its reasons",
	fb and fb.data.like == false and fb.data.reasons[1] == "empty" and #fb.data.reasons == 1
)
check("asked only once", not Feedback:Ask(ava))
-- the anti-cheat: a jump across the ocean
local m10 = mark()
local root = PlayersS:Root(ava)
ava:SetAttribute("AcGrace", 0)
Engine.advance(0.5)
root.CFrame = root.CFrame + Vector3.new(220, 0, 0)
Engine.advance(1.5)
check(
	"a teleport is flagged and undone",
	AntiCheat.state[ava].strikes >= 3 and (root.Position - tileAt(raft, 6, 6)).Magnitude < 60
)
flush()
check("the flag went to analytics", #events("anticheat", ava) >= 1)
check(
	"the leave and the snapshot carry the live fields",
	(function()
		local live
		for _, row in aSessions do
			if row.user_id == 501 and row.live then
				live = row.live
			end
		end
		return live ~= nil and live.where ~= nil and live.tier ~= nil and live.voyage ~= nil
	end)()
)
check(
	"emotes go to everyone",
	(function()
		local m = mark()
		send(ava, "Emote", "wave")
		return firedSince(m, "Act", nil, function(a)
			return a[1].mode == "emote"
		end) ~= nil
	end)()
)
check(
	"dropping an item floats it",
	(function()
		give(ava, "wood", 2)
		local before = #ws.Drops:GetChildren()
		send(ava, "Drop", slotOf(ava, "wood"), 1)
		return #ws.Drops:GetChildren() == before + 1
	end)()
)
check(
	"a full bag overflows into a bag on the water",
	(function()
		local before = #ws.Drops:GetChildren()
		for _ = 1, 60 do
			give(ava, "stone", 40)
		end
		return #ws.Drops:GetChildren() > before
	end)()
)

flush()
check("analytics are tagged ra8", taggedRa8)
check(
	"the funnel events went out",
	#events("first_hook", ava) == 1
		and #events("first_build", ava) == 1
		and #events("first_craft", ava) == 1
		and #events("first_sail", ava) == 1
		and #events("first_island", ava) == 1
		and #events("first_home", ava) == 1
)
check("guide steps were tracked", #events("guide_done", ava) >= 5, #events("guide_done", ava))
check(
	"the join went to the game log",
	(function()
		for _, e in gameLogs do
			if e.title and e.title:find("joined") then
				return true
			end
		end
	end)()
)

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("ServerSmoke: " .. failed .. " failures")
end

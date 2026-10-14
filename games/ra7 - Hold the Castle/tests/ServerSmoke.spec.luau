--[[
Server smoke test: boots the real server scripts on the mock engine and plays whole matches: the hangout, build
time (mining, placing and hammering blueprints, the camp's plan, the job board, the forge and kitchen, NPC dwarves
building), the first scare and a scout, the plague, the fight (moves for every job, the horde marching and
sieging, monsters breaking walls, shrines draining and falling, the walls of magic opening, dying and coming back
as a monster), the last stand, the end of the match (rewards, titles, tasks, the podium), the next match, late
joiners, friends, the guide and the first choice, the looks shop, feedback, analytics, the game log and the
anti-cheat. Fails on any script error or broken expectation.

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
local Match = service("MatchService")
local Teams = service("TeamService")
local Resources = service("ResourceService")
local Build = service("BuildService")
local Horde = service("HordeService")
local Shrines = service("ShrineService")
local Combat = service("CombatService")
local Craft = service("CraftService")
local Progress = service("ProgressService")
local Pings = service("PingService")
local Tutorial = service("TutorialService")
local Join = service("JoinService")
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
	check("analytics batches are tagged ra7", payload.game == "ra7")
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
local Pieces = Engine.require(tree.shared.Data.Pieces)
local Jobs = Engine.require(tree.shared.Data.Jobs)
local Looks = Engine.require(tree.shared.Data.Looks)
local HordeMod = Horde
local Players = Engine.Players
local ws = Engine.workspace

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
local function pos(p)
	return Teams:Position(p)
end
local function stand(p, at, lookAt)
	Engine.moveTo(p, at + Vector3.new(0, 3, 0), lookAt and (lookAt + Vector3.new(0, 3, 0)) or nil)
end
local function flush()
	Analytics.flush()
	GameLog.flush()
end
local function skipTo(phase)
	for _ = 1, 8 do
		if Match:Phase() == phase then
			return
		end
		Match:Skip()
		Engine.advance(0.6)
	end
end
local function join(name, userId)
	local p = Engine.addPlayer(name, userId)
	Engine.advance(0.3)
	Engine.fireServer(p, "Ready")
	Engine.advance(0.3)
	return p
end

-- 1. Boot ------------------------------------------------------------------------------------------------------
check("map built", ws:GetAttribute("MapBuilt") == true)
check("starts in the hangout phase", Match:Phase() == "intermission")
check("three shrines", #MapLayout.shrines == 3 and ws.Map:FindFirstChild("Shrine3") ~= nil)
check("resource nodes built", #ws.Nodes:GetChildren() >= #MapLayout.nodes)
check("two walls of magic", ws.Map:FindFirstChild("Barrier1") and ws.Map:FindFirstChild("Barrier2"))
check("teams made", Engine.game:GetService("Teams"):FindFirstChild("Dwarves") ~= nil)

-- 2. The first player: no waiting around, straight into build time --------------------------------------------
local ava = join("Ava", 501)
check("ava has a profile", Data:Get(ava) ~= nil)
check("ava starts in the hangout", Teams:Team(ava) == nil and ava.Character ~= nil)
Engine.advance(Constants.FIRST_MATCH_DELAY + 1)
check("build time began quickly", Match:Phase() == "build", Match:Phase())
check("ava is a dwarf", Teams:Team(ava) == "dwarf")
check("ava has the default job", Teams:Job(ava) == "builder")
check("ava spawned at the castle", pos(ava) and (pos(ava) - MapLayout.shrines[1].pos).Magnitude < 40, pos(ava))
check("build time is short for one player", Match:State().buildSeconds == 360)
local hum = ava.Character:FindFirstChildOfClass("Humanoid")
check("dwarf health from the job", hum.MaxHealth == Jobs.byKey.builder.hp)
check(
	"ava wears a costume",
	ava.Character:FindFirstChild("Beard") ~= nil and ava.Character:FindFirstChild("HammerHead") ~= nil
)
check("ava has a starting bag", Resources:Bag(ava).stone == Constants.START_BAG.stone)
check(
	"the camp's plan is laid out",
	(function()
		local n = 0
		for _, p in Build:All() do
			if p.state == "blueprint" then
				n += 1
			end
		end
		return n == #MapLayout.starter
	end)()
)
check("NPC dwarves help a small crew", Horde:DwarfCount() == Constants.NPC_DWARF_FILL - 1, Horde:DwarfCount())
Engine.advance(2.5)
check("the guide starts with the rocks", lastFired("Tutorial", ava) and lastFired("Tutorial", ava).key == "mine")
local guide = lastFired("Tutorial", ava)
check(
	"the guide points at the glowing pile",
	guide and guide.target and (guide.target - MapLayout.nodes[1].pos).Magnitude < 1
)

-- 3. The first job: tap the glowing rocks ----------------------------------------------------------------------
local starter = MapLayout.nodes[1]
stand(ava, starter.pos + Vector3.new(5, 0, 0), starter.pos)
local stoneBefore = Resources:Bag(ava).stone
check("mining the starter pile works", Combat:Act(ava, "main", Vector3.new(-1, 0, 0), { node = starter.id }))
check("stone went into the bag", Resources:Bag(ava).stone == stoneBefore + 1, Resources:Bag(ava).stone)
check("a number popped up", lastFired("Popup", ava) ~= nil)
check("mining is on a cooldown", not Combat:Act(ava, "main", Vector3.new(-1, 0, 0), { node = starter.id }))
for _ = 1, 10 do
	Engine.advance(0.55)
	Combat:Act(ava, "main", Vector3.new(-1, 0, 0), { node = starter.id })
end
check("the guide moved on to building", lastFired("Tutorial", ava) and lastFired("Tutorial", ava).key == "build")
check("the starter pile runs out", Resources:Node(starter.id).amount < MapLayout.NODE_AMOUNT.stone)
local far = MapLayout.nodes[13]
check(
	"can't mine from far away",
	not Combat:Act(ava, "main", nil, { node = far.id })
		or Resources:Node(far.id).amount == MapLayout.NODE_AMOUNT[far.kind]
)

-- 4. The first win: hammer a blueprint ----------------------------------------------------------------------------
local wall
for _, p in Build:All() do
	if p.key == "stoneWall" and p.state == "blueprint" and (not wall or p.j > wall.j) then
		wall = p
	end
end
check("a wall blueprint from the camp's plan", wall ~= nil)
Resources:Bag(ava).stone = 12
Resources:PushBag(ava)
stand(ava, wall.center - Vector3.new(-6, wall.size.Y / 2, 0), wall.center)
Engine.advance(0.6)
local r = Build:Hammer(ava, wall.id)
check("first hammer hit puts stone in", r == "deposit" or r == "work", r)
check("the blueprint has stone in it", wall.have.stone > 0, wall.have.stone)
check("the wall rises", wall.progress and wall.progress > 0, wall.progress)
for _ = 1, 12 do
	Engine.advance(0.55)
	if wall.state ~= "built" then
		Combat:Act(ava, "main", Vector3.new(-1, 0, 0), { piece = wall.id })
	end
end
check("the wall is built", wall.state == "built", wall.state .. " " .. tostring(wall.done))
check("built wall has full health", wall.hp == wall.maxHp)
check("ava gets credit", Teams:State(ava).stats.built >= 1)
check(
	"'You helped build this!'",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Popup" and e.player == ava and e.args[2] == "You helped build this!" then
				return true
			end
		end
		return false
	end)()
)
check(
	"the guide moved on to the first choice",
	lastFired("Tutorial", ava) and lastFired("Tutorial", ava).key == "choice"
)
check("the choice card is shown", lastFired("Choice", ava) and #lastFired("Choice", ava).options == 3)

-- 5. The first choice: a tower ------------------------------------------------------------------------------------
local before = 0
for _ in Build:All() do
	before += 1
end
Engine.fireServer(ava, "Choice", 2)
Engine.advance(0.3)
local after = 0
local tower
for _, p in Build:All() do
	after += 1
	if p.key == "tower" and p.i == MapLayout.towerSpots[1].i then
		tower = p
	end
end
check("choosing a tower puts one in the plan", after == before + 1 and tower ~= nil, after - before)
check("the guide moved on to the job", lastFired("Tutorial", ava) and lastFired("Tutorial", ava).key == "job")

-- 6. Jobs: only at a job board, and only before the plague -------------------------------------------------------
Engine.fireServer(ava, "Job", "fighter")
Engine.advance(0.3)
check("can't change job away from a board", Teams:Job(ava) == "builder")
stand(ava, MapLayout.jobBoards[1].pos + Vector3.new(0, 0, 4))
Engine.advance(0.6)
Engine.fireServer(ava, "Job", "fighter")
Engine.advance(0.3)
check("job board changes the job", Teams:Job(ava) == "fighter")
check("the fighter gets more health", ava.Character.Humanoid.MaxHealth == Jobs.byKey.fighter.hp)
check("the fighter carries a shield", ava.Character:FindFirstChild("Shield") ~= nil)
check("the job is remembered for next time", Data:Get(ava).dwarfJob == "fighter")
check("can't pick a monster job as a dwarf", not Teams:SetJob(ava, "brute"))
check(
	"the guide moves on after the job",
	lastFired("Tutorial", ava) == false or lastFired("Tutorial", ava).key ~= "job"
)

-- 7. Placing pieces: inside a build zone, on free cells, not too close to the shrine -----------------------------
local s1 = MapLayout.shrines[1].pos
stand(ava, s1 + Vector3.new(30, 0, 30))
Engine.advance(0.6)
local i0, j0 = MapLayout.cellOf(s1.X + 34, s1.Z + 34)
local piece, why = Build:Place(ava, "spikes", i0, j0, 0)
check("place a spike trap", piece ~= nil, why)
check("can't place on top of it", Build:Place(ava, "stoneWall", i0, j0, 0) == nil)
local ci, cj = MapLayout.cellOf(s1.X + 2, s1.Z + 2)
check("can't block the shrine", Build:Place(ava, "stoneWall", ci, cj, 0) == nil)
local oi, oj = MapLayout.cellOf(-400, 0)
check("can't build outside a build zone", select(2, Build:Place(ava, "stoneWall", oi, oj, 0)) ~= nil)
local wi, wj = MapLayout.cellOf(s1.X + 9, s1.Z)
check("a shrine ward goes right by the shrine", Build:Place(ava, "shrineWard", wi, wj, 0) ~= nil)
check("a second ward", Build:Place(ava, "shrineWard", wi - 4, wj + 1, 0) ~= nil)
check("not a third ward", Build:Place(ava, "shrineWard", wi - 1, wj - 4, 0) == nil)
Engine.fireServer(ava, "Place", "kitchen", i0 + 2, j0, 0)
Engine.advance(0.3)
local kitchen
for _, p in Build:All() do
	if p.key == "kitchen" then
		kitchen = p
	end
end
check("placing through the remote works", kitchen ~= nil)
check(
	"blueprint limit per player",
	(function()
		local made = 0
		for k = 1, 10 do
			if Build:Place(ava, "quickWall", i0 - 6 + k * 0, j0 - 6 - k * 2, 0) then
				made += 1
			end
		end
		return made < 10
	end)()
)
-- the cancel: take back a blueprint, materials come back
Resources:Bag(ava).wood, Resources:Bag(ava).stone = 6, 0
Resources:PushBag(ava)
stand(ava, kitchen.center + Vector3.new(0, -kitchen.size.Y / 2, 6))
Engine.advance(0.6)
Build:Hammer(ava, kitchen.id)
local woodIn = kitchen.have.wood
check("the kitchen took wood", woodIn > 0, woodIn)
Engine.fireServer(ava, "Cancel", kitchen.id)
Engine.advance(0.3)
check("cancel removes your blueprint", Build:Get(kitchen.id) == nil)
check("cancel gives the materials back", Resources:Bag(ava).wood == 6, Resources:Bag(ava).wood)

-- 8. Crafting: a forge, armor, food ----------------------------------------------------------------------------------
local fi, fj = MapLayout.cellOf(s1.X + 20, s1.Z - 30)
stand(ava, s1 + Vector3.new(24, 0, -22))
Engine.advance(0.4)
local forge, forgeWhy = Build:Place(ava, "forge", fi, fj, 0, { built = true })
check("a finished forge", forge and forge.state == "built", forgeWhy)
stand(ava, forge.center + Vector3.new(0, -forge.size.Y / 2, 6))
Engine.advance(0.6)
Resources:Bag(ava).gold, Resources:Bag(ava).stone = 4, 6
local ok = Craft:Craft(ava, "armor")
check("forge makes armor", ok and Teams:State(ava).gear.armor == 1)
check("armor costs gold and stone", Resources:Bag(ava).gold == 2 and Resources:Bag(ava).stone == 4)
check("no food without a kitchen", not Craft:Craft(ava, "food"))
local ki, kj = MapLayout.cellOf(s1.X + 30, s1.Z - 30)
local kitchen2 = Build:Place(ava, "kitchen", ki, kj, 0, { built = true })
stand(ava, kitchen2.center + Vector3.new(0, -kitchen2.size.Y / 2, 6))
Engine.advance(0.6)
Resources:Bag(ava).wood = 4
check("the kitchen cooks stew", Craft:Craft(ava, "food") and Teams:State(ava).food == 1)
ava.Character.Humanoid.Health = 60
Engine.fireServer(ava, "Use", "food")
Engine.advance(5.2)
check("eating heals over time", ava.Character.Humanoid.Health > 90, ava.Character.Humanoid.Health)
check("the stew is gone", Teams:State(ava).food == 0)

-- 9. NPC dwarves build too ------------------------------------------------------------------------------------------
local progressBefore = 0
for _, p in Build:All() do
	if p.state == "blueprint" then
		progressBefore += Formulas.total(p.have) + p.done
	end
end
Engine.advance(30)
local progressAfter = 0
for _, p in Build:All() do
	if p.state == "blueprint" then
		progressAfter += Formulas.total(p.have) + p.done
	end
end
local builtCount = 0
for _, p in Build:All() do
	if p.state == "built" then
		builtCount += 1
	end
end
check(
	"NPC dwarves carry rocks and hammer",
	progressAfter > progressBefore or builtCount > 4,
	progressAfter - progressBefore
)
local carrying = false
for _, n in Horde:All() do
	if n.side == "dwarf" and n.job then
		carrying = true
	end
end
check("NPC dwarves have work", carrying)

-- 10. The horde snapshot packs and unpacks ---------------------------------------------------------------------------
local list = {}
for _, n in Horde:All() do
	table.insert(list, n)
end
local packed = HordeMod.pack(list, 123.5)
local t, back = HordeMod.unpack(packed)
check("snapshot time survives", t == 123.5)
check("snapshot has every NPC", #back == #list, #back)
check("snapshot is small", #packed <= 8 + 12 * #list, #packed)
check("snapshot positions survive", math.abs(back[1].x - list[1].pos.X) < 0.11 or math.abs(back[1].x - (function()
	for _, n in list do
		if n.id == back[1].id then
			return n.pos.X
		end
	end
	return 0
end)()) < 0.11)
check("horde snapshots go out", Engine.countClientEvents("Horde") > 10)

-- 11. The first scare and a scout ------------------------------------------------------------------------------------
local elapsed = Match:BuildElapsed()
Engine.advance(Constants.FIRST_SCARE_AT - elapsed + 1)
check("the first scare", Match:State().scared == true and ws:GetAttribute("Scared") == true)
local watchers = 0
for _, n in Horde:All() do
	if n.state == "watch" then
		watchers += 1
	end
end
check("monsters watch from the hill", watchers >= 5, watchers)
check("watchers don't count as attackers", Horde:MonsterCount() == 0)
Engine.advance(Constants.SCOUT_FIRST_AT - Constants.FIRST_SCARE_AT + 1)
local scout
for _, n in Horde:All() do
	if n.st.scout then
		scout = n
	end
end
check("a scout comes over the hill", scout ~= nil)
-- the scout walks toward the castle
local scoutStart = scout and scout.pos
Engine.advance(4)
check(
	"the scout walks the lane",
	scout and (scout.pos - scoutStart).Magnitude > 20,
	scout and (scout.pos - scoutStart).Magnitude
)
-- fight it: put ava next to it and swing
if scout then
	stand(ava, scout.pos + Vector3.new(4, 0, 0), scout.pos)
	Engine.advance(0.1)
	local hpBefore = scout.hp
	ava.Character.HumanoidRootPart.CFrame =
		CFrame.lookAt(ava.Character.HumanoidRootPart.Position, scout.pos + Vector3.new(0, 3, 0))
	Combat:Act(ava, "main", (scout.pos - ava.Character.HumanoidRootPart.Position).Unit)
	Engine.advance(0.5)
	check("ava's swing hits the scout", scout.hp < hpBefore or not Horde:Get(scout.id), scout.hp)
	for _ = 1, 6 do
		if Horde:Get(scout.id) then
			stand(ava, scout.pos + Vector3.new(4, 0, 0), scout.pos)
			Combat:Act(ava, "main", (scout.pos - ava.Character.HumanoidRootPart.Position).Unit)
		end
		Engine.advance(0.9)
	end
	check("the scout is beaten", Horde:Get(scout.id) == nil)
	check("beating it counts", Teams:State(ava).stats.beaten >= 1)
end
stand(ava, MapLayout.shrines[1].pos + Vector3.new(12, 0, 6))

-- 12. More players join during build time: straight in as dwarves ------------------------------------------------
local ben = join("Ben", 502)
local cal = join("Cal", 503)
local dee = join("Dee", 504)
Engine.makeFriends(ava, ben)
Engine.advance(1)
check(
	"late joiners in build are dwarves",
	Teams:Team(ben) == "dwarf" and Teams:Team(cal) == "dwarf" and Teams:Team(dee) == "dwarf"
)
check("they spawn at the castle", pos(dee) and (pos(dee) - MapLayout.shrines[1].pos).Magnitude < 40)
Engine.fireServer(cal, "Volunteer", true)
Engine.advance(0.3)
check("cal volunteers for the plague", Teams:State(cal).volunteer == true)
-- cal becomes an archer, dee a healer, ben a miner (at the board)
for _, pair in { { cal, "archer" }, { dee, "healer" }, { ben, "miner" } } do
	stand(pair[1], MapLayout.jobBoards[1].pos + Vector3.new(2, 0, 4))
	Engine.advance(0.3)
	Teams:SetJob(pair[1], pair[2])
end
check("jobs picked", Teams:Job(cal) == "archer" and Teams:Job(dee) == "healer" and Teams:Job(ben) == "miner")
check("the miner carries more", Resources:Capacity(ben) == Jobs.byKey.miner.bag)

-- the miner's Big Dig and a gem chance
local rock = MapLayout.nodes[2]
stand(ben, rock.pos + Vector3.new(5, 0, 0), rock.pos)
Engine.advance(0.3)
local stoneB = Resources:Bag(ben).stone
check("Big Dig rips out a big chunk", Combat:Act(ben, "special", Vector3.new(-1, 0, 0), { node = rock.id }))
check("Big Dig gave a lot", Resources:Bag(ben).stone - stoneB >= 6, Resources:Bag(ben).stone - stoneB)
Engine.advance(0.5)
local before2 = Resources:Bag(ben).stone
Combat:Act(ben, "main", Vector3.new(-1, 0, 0), { node = rock.id })
check("miners dig twice as much", Resources:Bag(ben).stone - before2 == 2, Resources:Bag(ben).stone - before2)

-- 13. The plague -------------------------------------------------------------------------------------------------------
local monstersBefore = Teams:MonsterPlayerCount()
Match:Skip() -- build -> plague
Engine.advance(0.5)
check("the plague phase", Match:Phase() == "plague")
check("one of four turns", Teams:MonsterPlayerCount() == monstersBefore + 1, Teams:MonsterPlayerCount())
check("the volunteer is picked first", Teams:Team(cal) == "monster")
check("the friends stay dwarves", Teams:Team(ava) == "dwarf" and Teams:Team(ben) == "dwarf")
check("the turned one gets a job picker", lastFired("Picker", cal) and #lastFired("Picker", cal).jobs == 5)
check(
	"watchers march at the plague",
	(function()
		for _, n in Horde:All() do
			if n.state == "watch" then
				return false
			end
		end
		return true
	end)()
)
Engine.fireServer(cal, "Job", "brute")
Engine.advance(0.3)
check("brutes are locked at level 1", Teams:Job(cal) ~= "brute")
Engine.fireServer(cal, "Job", "spitter")
Engine.advance(0.3)
check("spitter is open", Teams:Job(cal) == "spitter")
Engine.advance(Constants.PLAGUE_SECONDS)
check("the fight began", Match:Phase() == "fight")
check("cal came back as a monster", Teams:IsAlive(cal) and cal.Character:FindFirstChild("Sac") ~= nil)
check("monsters spawn in the forest", pos(cal) and (pos(cal) - MapLayout.FOREST_SPAWN).Magnitude < 30, pos(cal))
check("monsters can't jump walls", cal.Character.Humanoid.JumpHeight == Constants.MONSTER_JUMP)
check("the shrine is active", Shrines:State(1).state == "active")

-- 14. The horde comes ----------------------------------------------------------------------------------------------
Engine.advance(3)
check("a wave spawned", Horde:MonsterCount() > 0, Horde:MonsterCount())
local marcher
for _, n in Horde:All() do
	if n.side == "monster" and n.state == "march" then
		marcher = n
		break
	end
end
check("monsters march the lanes", marcher ~= nil)
local mStart = marcher and marcher.pos
Engine.advance(5)
check("they move toward the castle", marcher and (marcher.pos - mStart).Magnitude > 20)

-- 15. Moves: a monster player smashes a wall; the dwarves fight back ------------------------------------------------------
local target
for _, p in Build:All() do
	if p.state == "built" and p.key == "stoneWall" then
		target = p
		break
	end
end
check("there is a built wall to smash", target ~= nil)
if target then
	-- cal (spitter) spits at the wall from outside
	stand(cal, target.center + Vector3.new(-14, -target.size.Y / 2, 0), target.center)
	Engine.advance(0.2)
	local hp0 = target.hp
	Combat:Act(cal, "main", (target.center - pos(cal)).Unit)
	Engine.advance(1.2)
	check("a spit hits the wall", target.hp < hp0, target.hp .. " vs " .. hp0)
	check("monsters level up from damage", Teams:State(cal).monsterXp > 0)
	-- the dwarves can't hurt their own wall
	stand(ava, target.center + Vector3.new(4, -target.size.Y / 2, 0), target.center)
	Engine.advance(0.2)
	check(
		"dwarves never hurt their own castle",
		not Build:Damage(target.id, 50, ava, "melee") and target.hp < target.maxHp
	)
	-- a builder can fix it
	local hpFix = target.hp
	Teams:State(ava).job = "builder"
	local res = Build:Hammer(ava, target.id)
	check("hammering a hurt wall fixes it", res == "fix" and target.hp > hpFix, res)
	Teams:State(ava).job = "fighter"
end
-- ava (fighter) swings at cal
stand(ava, pos(cal) + Vector3.new(4, 0, 0), pos(cal))
Engine.advance(0.2)
local calHp = cal.Character.Humanoid.Health
cal.Character:SetAttribute("ProtectedUntil", 0)
Combat:Act(ava, "main", (pos(cal) - pos(ava)).Unit)
Engine.advance(0.5)
check("the fighter's big swing hurts monsters", cal.Character.Humanoid.Health < calHp, cal.Character.Humanoid.Health)
check("hits knock back", lastFired("Knock", cal) ~= nil)
-- shield wall
check("shield wall", Combat:Act(ava, "special", Vector3.new(-1, 0, 0)))
local avaHp = ava.Character.Humanoid.Health
ava.Character:SetAttribute("ProtectedUntil", 0)
Combat:HurtPlayer(ava, 50, cal, "spit")
check(
	"shield wall blocks most damage",
	avaHp - ava.Character.Humanoid.Health < 20,
	avaHp - ava.Character.Humanoid.Health
)
-- healer heals ava
stand(dee, pos(ava) + Vector3.new(6, 0, 0), pos(ava))
Engine.advance(0.3)
local h0 = ava.Character.Humanoid.Health
Combat:Act(dee, "special", Vector3.new(-1, 0, 0))
check("the healer's ward heals", ava.Character.Humanoid.Health > h0)
check("healing counts", Teams:State(dee).stats.healed > 0)
-- the archer: ben switches? no: fire an arrow from ava's teammate dee is a healer; test volley with a spare archer later
-- the builder's quick wall
Teams:State(ben).job = "builder"
stand(ben, MapLayout.shrines[1].pos + Vector3.new(30, 0, -12), MapLayout.shrines[1].pos + Vector3.new(30, 0, -40))
Engine.advance(0.3)
check("quick wall drops a finished wall", Combat:Act(ben, "special", Vector3.new(0, 0, -1)))
local qw
for _, p in Build:All() do
	if p.key == "quickWall" and p.state == "built" then
		qw = p
	end
end
check("the quick wall is standing", qw ~= nil)
Teams:State(ben).job = "miner"

-- 16. The archer: arrows and a volley ------------------------------------------------------------------------------------
-- (from here the horde is held back so the test players stay where the test puts them)
Horde:Clear()
Horde:Pause(600)
local function shield(on)
	for _, p in { ava, ben, cal, dee } do
		if p.Character then
			p.Character:SetAttribute("ProtectedUntil", on and Engine.now() + 9999 or 0)
		end
	end
end
shield(true)
-- (jobs switched by the test keep the last job's cooldowns: clear them like a respawn would)
local function fresh(p)
	local cd = Combat:Cooldowns(p)
	if cd then
		cd.main, cd.special = 0, 0
	end
end
check(
	"everyone is still in it",
	Teams:IsAlive(ava) and Teams:IsAlive(ben) and Teams:IsAlive(dee) and Teams:IsAlive(cal)
)
local victim = Horde:Spawn("grunt", MapLayout.shrines[1].pos + Vector3.new(-60, 0, 0))
victim.state = "watch" -- stands still for the test
Teams:State(dee).job = "archer"
stand(dee, victim.pos + Vector3.new(30, 0, 0), victim.pos)
Engine.advance(0.2)
local vhp = victim.hp
Combat:Act(dee, "main", (victim.pos + Vector3.new(0, 2.6, 0) - (pos(dee) + Vector3.new(0, 1.5, 0))).Unit)
Engine.advance(0.8)
check("an arrow hits a monster", victim.hp < vhp or not Horde:Get(victim.id), victim.hp)
check(
	"arrows fly (the projectile effect)",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Fx" and e.args[1] == "projectile" and e.args[2].style == "arrow" then
				return true
			end
		end
		return false
	end)()
)
victim.state = "watch"
fresh(dee)
check("volley fires five arrows", Combat:Act(dee, "special", (victim.pos - pos(dee)).Unit))
Engine.advance(1)
Horde:Damage(victim.id, 9999, nil, "test")
Engine.advance(Jobs.byKey.archer.main.cooldown)
check(
	"aim help finds a target that's a little off",
	(function()
		local v2 = Horde:Spawn("grunt", pos(dee) + Vector3.new(-40, -3, 6))
		v2.state = "watch"
		Engine.advance(1)
		local h = v2.hp
		Combat:Act(dee, "main", Vector3.new(-1, 0, 0))
		Engine.advance(1)
		return v2.hp < h or not Horde:Get(v2.id)
	end)()
)
Teams:State(dee).job = "healer"

-- 17. Monster moves ------------------------------------------------------------------------------------------------
Teams:AddMonsterXp(cal, 60)
check("monster level 2", Teams:State(cal).monsterLevel == 2)
check("brutes unlock at level 2", Formulas.jobUnlocked(Jobs.byKey.brute, 2, 0))
-- the Brute's charge (as a brute, without respawning)
Teams:State(cal).job = "brute"
fresh(cal)
local charge = Combat:Act(cal, "special", Vector3.new(1, 0, 0))
check("the brute charges", charge and lastFired("Dash", cal) ~= nil)
Engine.advance(1)
-- the Breaker's bomb blows up walls
Teams:State(cal).job = "breaker"
local wall2
for _, p in Build:All() do
	if p.state == "built" and p.key == "stoneWall" then
		wall2 = p
	end
end
stand(cal, wall2.center + Vector3.new(-4, -wall2.size.Y / 2, 0), wall2.center)
Engine.advance(0.2)
fresh(cal)
local w2hp = wall2.hp
check("plant a bomb", Combat:Act(cal, "special", Vector3.new(1, 0, 0)))
Engine.advance(2.5)
check("the bomb blows up the wall", (not Build:Get(wall2.id)) or wall2.hp < w2hp - 200, wall2.hp)
check(
	"an explosion",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Fx" and e.args[1] == "explode" then
				return true
			end
		end
		return false
	end)()
)
-- the Witch calls imps and heals
Teams:State(cal).job = "witch"
fresh(cal)
local impsBefore = 0
for _, n in Horde:All() do
	if n.kind == "imp" then
		impsBefore += 1
	end
end
check("dark circle", Combat:Act(cal, "special", Vector3.new(1, 0, 0)))
local impsAfter = 0
for _, n in Horde:All() do
	if n.kind == "imp" then
		impsAfter += 1
	end
end
check("the witch calls two imps", impsAfter == impsBefore + 2)
-- the Spitter's goo puddle slows dwarves
Teams:State(cal).job = "spitter"
stand(ava, pos(cal) + Vector3.new(20, 0, 0))
Engine.advance(0.2)
fresh(cal)
check("goo puddle", Combat:Act(cal, "special", Vector3.new(1, 0, 0)))
Engine.advance(0.6)
check(
	"goo slows dwarves",
	ava.Character.Humanoid.WalkSpeed < Jobs.byKey.fighter.speed,
	ava.Character.Humanoid.WalkSpeed
)
-- the Grunt's roar
Teams:State(cal).job = "grunt"
fresh(cal)
check("roar", Combat:Act(cal, "special", Vector3.new(1, 0, 0)))
Engine.advance(0.4)
check(
	"roar makes monsters fast",
	cal.Character.Humanoid.WalkSpeed > Jobs.byKey.grunt.speed,
	cal.Character.Humanoid.WalkSpeed
)
stand(ava, MapLayout.shrines[1].pos + Vector3.new(12, 0, 6))
Engine.advance(7)
check(
	"the goo wears off",
	ava.Character.Humanoid.WalkSpeed >= Jobs.byKey.fighter.speed - 0.01,
	ava.Character.Humanoid.WalkSpeed
)
Teams:State(cal).job = "spitter"

-- 18. A dwarf falls and rises as a monster ---------------------------------------------------------------------------
shield(true)
dee.Character:SetAttribute("ProtectedUntil", 0)
local calKills = Teams:State(cal).stats.dwarvesBeaten
Combat:HurtPlayer(dee, 999, cal, "claw")
Engine.advance(0.3)
check("dee fell", not Teams:IsAlive(dee) or Teams:Team(dee) == "monster")
check("dee is a monster now", Teams:Team(dee) == "monster")
check("cal gets the kill", Teams:State(cal).stats.dwarvesBeaten == calKills + 1)
check("dee picks a monster job while waiting", lastFired("Picker", dee) ~= nil)
check("dee's time as a dwarf counts", Teams:State(dee).stats.heldSeconds > 0, Teams:State(dee).stats.heldSeconds)
Engine.fireServer(dee, "Job", "breaker")
Engine.advance(Constants.TURN_RESPAWN + 0.5)
check(
	"dee comes back as a breaker",
	Teams:IsAlive(dee) and Teams:Job(dee) == "breaker" and dee.Character:FindFirstChild("Log") ~= nil
)
check("monster health grows with the fight", dee.Character.Humanoid.MaxHealth >= Jobs.byKey.breaker.hp)
check("dwarves left: ava and ben (+ NPCs)", Teams:DwarfCount() == 2, Teams:DwarfCount())

-- 19. Shrine 1 falls --------------------------------------------------------------------------------------------------
local s1pos = MapLayout.shrines[1].pos
stand(ava, s1pos + Vector3.new(60, 0, 40))
stand(ben, s1pos + Vector3.new(60, 0, 46))
for _, n in Horde:All() do
	if n.side == "dwarf" then
		n.pos = s1pos + Vector3.new(70, 0, -50)
		n.stunUntil = Engine.now() + 30
	end
end
for k = 1, 5 do
	local g = Horde:Spawn("grunt", s1pos + Vector3.new(math.cos(k) * 6, 0, math.sin(k) * 6))
	g.state = "hold"
	g.holdPos = g.pos
end
Shrines:State(1).health = 2
Engine.advance(2)
check("shrine 1 has fallen", Match:Fallen() == 1, Match:Fallen() .. " " .. Shrines:State(1).health)
check(
	"the wall of magic opens",
	ws.Map.Barrier1.Veil.CanCollide == false and ws.Map.Barrier1:GetAttribute("Open") == true
)
check("the next shrine is active", Shrines:State(2).state == "active")
check(
	"a shrine-lost callout",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Callout" and string.find(e.args[1], "has fallen") then
				return true
			end
		end
		return false
	end)()
)
check(
	"dwarves run back faster",
	ava.Character.Humanoid.WalkSpeed > Jobs.byKey.fighter.speed,
	ava.Character.Humanoid.WalkSpeed
)
check(
	"the horde heads for shrine 2",
	(function()
		for _, n in Horde:All() do
			if n.side == "monster" and n.zone ~= 2 then
				return false
			end
		end
		return true
	end)()
)
check(
	"NPC dwarves fall back",
	(function()
		for _, n in Horde:All() do
			if n.side == "dwarf" and n.state ~= "retreat" and n.state ~= "defend" then
				return false
			end
		end
		return true
	end)()
)
check("still the fight (not the last stand)", Match:Phase() == "fight")
-- monsters now come back at shrine 1
shield(true)
cal.Character:SetAttribute("ProtectedUntil", 0)
Combat:HurtPlayer(cal, 999, ava, "smash")
Engine.advance(Constants.MONSTER_RESPAWN + 0.6)
check("monsters spawn at the fallen shrine", pos(cal) and (pos(cal) - s1pos).Magnitude < 30, pos(cal))
check("ava beat cal", Teams:State(ava).stats.beaten >= 2)

-- 20. A player joins during the fight: a monster, with a hint --------------------------------------------------------
local eve = join("Eve", 505)
Engine.advance(2.5)
check("fight joiners are monsters", Teams:Team(eve) == "monster")
check("eve spawned at the monster spawn", Teams:IsAlive(eve) and pos(eve) and (pos(eve) - s1pos).Magnitude < 30)
check("eve's hint", lastFired("Tutorial", eve) and lastFired("Tutorial", eve).key == "monster")

-- 21. Shrine 2 falls: the last stand ------------------------------------------------------------------------------------
Shrines:State(2).health = 1
local s2pos = MapLayout.shrines[2].pos
for k = 1, 4 do
	local g = Horde:Spawn("grunt", s2pos + Vector3.new(math.cos(k) * 5, 0, math.sin(k) * 5), { zone = 2 })
	g.state = "hold"
	g.holdPos = g.pos
end
for _, n in Horde:All() do
	if n.side == "dwarf" then
		n.pos = s2pos + Vector3.new(70, 0, 0)
		n.state = "guard"
		n.stunUntil = Engine.now() + 30
	end
end
stand(ava, s2pos + Vector3.new(60, 0, 20))
stand(ben, s2pos + Vector3.new(60, 0, -20))
Engine.advance(2)
check("shrine 2 has fallen", Match:Fallen() == 2)
check("the last stand", Match:Phase() == "laststand" and ws:GetAttribute("Phase") == "laststand")
check("barrier 2 opens", ws.Map.Barrier2:GetAttribute("Open") == true)

-- 22. The dwarves hold until the clock runs out ------------------------------------------------------------------------
local coins0 = Data:Get(ava).coins
local matches0 = Data:Get(ava).stats.matches
Match:Skip()
Engine.advance(0.5)
check("the match ended", Match:Phase() == "ended")
check("the dwarves won", Match:State().result.winner == "dwarf")
local res = lastFired("Results", ava)
check("ava sees the results", res ~= nil and res.winner == "dwarf")
check("ava won", res and res.you.won == true and res.you.team == "dwarf")
check("ava got coins", Data:Get(ava).coins > coins0, Data:Get(ava).coins - coins0)
check("the match counts", Data:Get(ava).stats.matches == matches0 + 1)
check("cal (a monster) lost", lastFired("Results", cal) and lastFired("Results", cal).you.won == false)
check("cal still gets coins", lastFired("Results", cal) and lastFired("Results", cal).you.coins > 0)
check("MVPs listed", res and res.mvps and res.mvps.builder ~= nil)
check("the podium shows the best", ws.Map.Hangout.Podium1:FindFirstChild("Who") ~= nil)
check("XP and levels", Data:Get(ava).xp > 0)
check("job XP", (Data:Get(ava).jobXp.fighter or 0) > 0)
check(
	"the 'matches' task counted",
	(function()
		local d = Data:Get(ava).daily
		for _, key in d.tasks do
			if key == "matches2" then
				return (d.progress[key] or 0) >= 1
			end
		end
		return true
	end)()
)
check("the best hold is saved", Data:Get(ava).stats.bestHold > 0)

-- 23. The hangout, then the next match -----------------------------------------------------------------------------------
Engine.advance(Constants.ENDED_SECONDS + 0.5)
check("back to the hangout", Match:Phase() == "intermission")
check("everyone is in the hangout", Teams:Team(ava) == nil and Teams:Team(cal) == nil)
check("ava stands on the hangout deck", pos(ava) and pos(ava).Y > 45, pos(ava))
check("the castle is cleared", next(Build:All()) == nil)
check("the horde is gone", next(Horde:All()) == nil)
check("the shrines are whole again", Shrines:State(1).health == 100 and Shrines:State(1).state == "safe")
check("the walls of magic close", ws.Map.Barrier1.Veil.CanCollide == true)
Engine.advance(Constants.INTERMISSION_SECONDS + 0.5)
check("the next match starts", Match:Phase() == "build" and Match:State().number == 2)
check("five players: a longer build", Match:State().buildSeconds == 420, Match:State().buildSeconds)
check("everyone is a dwarf again", Teams:Team(cal) == "dwarf" and Teams:Team(eve) == "dwarf")
check("ava keeps her job", Teams:Job(ava) == "fighter")
check("fewer NPC helpers with more players", Horde:DwarfCount() == Constants.NPC_DWARF_FILL - 5)
check("bags start fresh", Resources:Bag(ava).stone == Constants.START_BAG.stone)

-- 24. The monsters win: every dwarf falls ---------------------------------------------------------------------------------
Match:Skip() -- plague
Engine.advance(0.5)
check("5 players: one turns", Teams:MonsterPlayerCount() == 1)
Engine.advance(Constants.PLAGUE_SECONDS + 0.5)
for _, n in Horde:All() do
	if n.side == "dwarf" then
		Horde:Damage(n.id, 9999, nil, "test")
	end
end
Engine.advance(4)
for _, p in Teams:Players("dwarf") do
	p.Character:SetAttribute("ProtectedUntil", 0)
	Combat:HurtPlayer(p, 9999, nil, "test")
	Engine.advance(0.2)
end
Engine.advance(1)
check(
	"every dwarf fell: the monsters win",
	Match:Phase() == "ended" and Match:State().result.winner == "monster",
	Match:Phase()
)
check("the reason is 'wiped'", Match:State().result.reason == "wiped")
check(
	"a last dwarf callout",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Callout" and string.find(e.args[1], "LAST DWARF") then
				return true
			end
		end
		return false
	end)()
)

-- 25. A third match: traps, stations, upgrades, castle stages -----------------------------------------------------------
Engine.advance(Constants.ENDED_SECONDS + Constants.INTERMISSION_SECONDS + 1)
check("the third match", Match:Phase() == "build" and Match:State().number == 3)
Horde:Pause(600)
for _, n in Horde:All() do
	if n.side == "monster" then
		Horde:Damage(n.id, 9999, nil, "test")
	end
end
local S1 = MapLayout.shrines[1].pos
stand(ava, S1 + Vector3.new(20, 0, 30))
Engine.advance(0.3)
local function cellAt(dx, dz)
	return MapLayout.cellOf(S1.X + dx, S1.Z + dz)
end
local ti, tj = cellAt(30, 34)
local spikes = Build:Place(ava, "spikes", ti, tj, 0, { built = true })
check("instant spike trap", spikes and spikes.state == "built")
local g = Horde:Spawn("grunt", spikes.center)
g.state = "watch"
local ghp = g.hp
Engine.advance(1.2)
check("spikes hurt monsters standing on them", g.hp < ghp, g.hp)
local pi2, pj2 = cellAt(38, 34)
local pit = Build:Place(ava, "pit", pi2, pj2, 0, { built = true })
local g2 = Horde:Spawn("grunt", pit.center)
Engine.advance(0.6)
check("a pit traps a monster", g2.stunUntil > Engine.now() or not Horde:Get(g2.id))
local oi2, oj2 = cellAt(46, 34)
local oil = Build:Place(ava, "oilPot", oi2, oj2, 0, { built = true })
local g3 = Horde:Spawn("grunt", oil.center + Vector3.new(5, 0, 0))
g3.state = "watch"
local g3hp = g3.hp
Engine.advance(0.6)
check("the oil pot pours fire on monsters near it", g3.hp < g3hp or not Horde:Get(g3.id))
-- healing station heals dwarves near it
local hi, hj = cellAt(20, 40)
local heal = Build:Place(ava, "healStation", hi, hj, 0, { built = true })
stand(ava, heal.center + Vector3.new(4, -heal.size.Y / 2, 0))
ava.Character.Humanoid.Health = 50
Engine.advance(2.2)
check("the healing station heals", ava.Character.Humanoid.Health > 50, ava.Character.Humanoid.Health)
-- fix-it station mends pieces near it
local fi2, fj2 = cellAt(24, 46)
local fix = Build:Place(ava, "fixStation", fi2, fj2, 0, { built = true })
local wi2, wj2 = cellAt(30, 46)
local wallF = Build:Place(ava, "stoneWall", wi2, wj2, 0, { built = true })
wallF.hp = wallF.maxHp / 2
wallF.lastHitAt = 0
Engine.advance(3.2)
check("the fix-it station mends walls", wallF.hp > wallF.maxHp / 2, wallF.hp)
check("fix station stands", fix.state == "built")
-- upgrades: start one, hammer it in, it gets tougher
Resources:Bag(ava).stone = 12
stand(ava, wallF.center + Vector3.new(0, -wallF.size.Y / 2, 5))
Engine.advance(0.3)
wallF.hp = wallF.maxHp
local maxBefore = wallF.maxHp
Engine.fireServer(ava, "Upgrade", wallF.id)
Engine.advance(0.3)
check("an upgrade starts", wallF.upgrade ~= nil)
for _ = 1, 8 do
	Build:Hammer(ava, wallF.id)
end
check("the thicker wall is done", wallF.upgraded == true and wallF.maxHp > maxBefore, wallF.maxHp)
-- castle stages: lots of points around shrine 1
local stageBefore = Build:Stage(1)
for k = 0, 9 do
	local ci2, cj2 = cellAt(-40 + k * 8, -60)
	Build:Place(ava, "stoneWall", ci2, cj2, 0, { built = true, system = true })
end
local tw = { cellAt(50, -50) }
Build:Place(nil, "tower", tw[1], tw[2], 0, { built = true, system = true })
check("the castle grows into a town", Build:Stage(1) ~= "camp" and stageBefore == "camp", Build:Stage(1))
check("a grander castle drains slower", Formulas.shrineRate(0, 3, 0, "town") > Formulas.shrineRate(0, 3, 0, "camp"))
check("town banners at the shrine", #(ws.Castle:GetChildren()) > 0)

-- 26. The looks shop, titles, the daily gift -----------------------------------------------------------------------------
local profile = Data:Get(ava)
profile.coins = 1000
Engine.fireServer(ava, "Buy", "royal")
Engine.advance(0.2)
check("buy a look with coins", profile.looks.owned.royal == true and profile.coins == 1000 - Looks.byKey.royal.price)
check("a new look is worn right away", profile.looks.equipped.armor == "royal")
check(
	"the costume changes at once",
	ava.Character:FindFirstChild("Helmet") and ava.Character.Helmet.Color == Looks.byKey.royal.main
)
Engine.fireServer(ava, "Buy", "royal")
Engine.advance(0.2)
check("can't buy it twice", profile.coins == 1000 - Looks.byKey.royal.price)
profile.coins = 5
Engine.fireServer(ava, "Buy", "crystal")
Engine.advance(0.2)
check("can't buy without the coins", not profile.looks.owned.crystal)
Engine.fireServer(ava, "Equip", "armor", "iron")
Engine.advance(0.2)
check("equip an owned look", profile.looks.equipped.armor == "iron")
Engine.fireServer(ava, "Equip", "armor", "crystal")
Engine.advance(0.2)
check("can't equip what you don't own", profile.looks.equipped.armor == "iron")
profile.stats.walls = 120
Progress:_checkTitles(ava)
check("titles are earned", profile.titles.owned.wallMaster == true)
Engine.fireServer(ava, "Equip", "title", "wallMaster")
Engine.advance(0.2)
check("wear a title", profile.titles.equipped == "wallMaster")
check("the title shows over your head", ava.Character.Head.Nameplate.Title.Text == "Wall Master")
local coinsG = profile.coins
Engine.fireServer(ava, "ClaimGift")
Engine.advance(0.2)
check("the daily gift", profile.coins == coinsG + Constants.DAILY_GIFTS[1] and profile.daily.streak == 1)
Engine.fireServer(ava, "ClaimGift")
Engine.advance(0.2)
check("one gift a day", profile.coins == coinsG + Constants.DAILY_GIFTS[1])
check("three daily tasks", #profile.daily.tasks == 3)
check("a weekly challenge", profile.daily.weekly ~= nil)
local view = Progress:View(ava)
check("the profile view has tasks and gift", view and #view.tasks == 3 and view.gift.ready == false)
Engine.fireServer(ava, "Emote", "wave")
Engine.advance(0.1)
check(
	"emotes play for everyone",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Fx" and e.args[1] == "emote" then
				return true
			end
		end
		return false
	end)()
)
Engine.fireServer(ava, "Emote", "dance")
Engine.advance(0.1)
Engine.fireServer(ava, "Settings", "shake", false)
Engine.advance(0.1)
check("settings save", profile.settings.shake == false)

-- 27. Pings go to your team only -----------------------------------------------------------------------------------------
Match:Skip() -- plague
Engine.advance(0.6)
local monster
for _, p in { ava, ben, cal, dee, eve } do
	if Teams:Team(p) == "monster" then
		monster = p
	end
end
check("someone turned", monster ~= nil)
local pinger, dwarfMate
for _, p in { ava, ben, cal, dee, eve } do
	if Teams:Team(p) == "dwarf" then
		if not pinger then
			pinger = p
		elseif not dwarfMate then
			dwarfMate = p
		end
	end
end
local beforePing = Engine.countClientEvents("Ping")
Engine.advance(3)
Engine.fireServer(pinger, "Ping", "gate", pos(pinger))
Engine.advance(0.2)
check("a ping reaches teammates", lastFired("Ping", dwarfMate) and lastFired("Ping", dwarfMate).key == "gate")
check(
	"a ping doesn't reach monsters",
	(function()
		for i = #Engine.clientLog, 1, -1 do
			local e = Engine.clientLog[i]
			if e.name == "Ping" and e.player == monster and e.at >= Engine.now() - 1 then
				return false
			end
		end
		return true
	end)()
)
check("pings are on a cooldown", not Pings:Ping(pinger, "help"))
check("ping events sent", Engine.countClientEvents("Ping") > beforePing)

-- 28. The anti-cheat ------------------------------------------------------------------------------------------------------
Engine.advance(Constants.PLAGUE_SECONDS + 1)
local cheater = monster
local strikes0 = AntiCheat.state[cheater] and AntiCheat.state[cheater].strikes or 0
Engine.advance(3)
cheater:SetAttribute("AcGrace", 0)
local hrp = cheater.Character.HumanoidRootPart
local base = hrp.Position
for k = 1, 10 do
	hrp.CFrame = CFrame.new(base + Vector3.new(k * 30, 0, 0))
	Engine.advance(0.25)
end
check("speed cheats are caught", AntiCheat.state[cheater].strikes > strikes0, AntiCheat.state[cheater].strikes)
-- walking through the wall of magic (shrine 1 still stands)
Engine.advance(3)
cheater:SetAttribute("AcGrace", 0)
local strikes1 = AntiCheat.state[cheater].strikes
hrp.CFrame = CFrame.new(Vector3.new(-10, 3, 0))
Engine.advance(0.6)
check(
	"walking past a wall of magic is caught",
	AntiCheat.state[cheater].strikes > strikes1,
	AntiCheat.state[cheater].strikes
)
check("and put back", hrp.Position.X < -20, hrp.Position)

-- 29. Friends: join a friend's server, server full, private match ---------------------------------------------------------
Engine.friendPlaces[777] = { Engine.game.PlaceId, "other-job" }
Engine.makeFriends(ava, { UserId = 777 })
Join:Join(ava, 777, "Pal")
check("join a friend teleports to their server", #Engine.teleports >= 1)
Engine.fireServer(ava, "FriendAction", "private")
Engine.advance(0.2)
check("start a private match", #Engine.teleports >= 2)
check("can't join a stranger", not Join:Join(ava, 888, "Stranger"))

-- 30. Analytics and the game log ------------------------------------------------------------------------------------------
flush()
check("joins tracked", #events("join") >= 5)
check("first rock tracked", #events("first_rock", ava) == 1)
check("first build tracked", #events("first_build", ava) == 1)
check("first wall tracked", #events("first_wall", ava) == 1)
check("first fight tracked", #events("first_fight", ava) == 1)
check(
	"the first choice tracked",
	#events("first_choice", ava) == 1 and events("first_choice", ava)[1].data.choice == "tower"
)
check("match starts tracked", #events("match_start") >= 3)
check("plague tracked", #events("plague") >= 2)
check("turned tracked", #events("turned") >= 2)
check("deaths tracked", #events("died") >= 2)
check("shrine falls tracked", #events("shrine_fell") >= 2)
check("match ends tracked", #events("match_end") >= 2)
check("finished a match tracked once", #events("finished_match", ava) == 1)
check("crafting tracked", #events("craft", ava) >= 2)
check("buying tracked", #events("bought", ava) == 1)
check("pings tracked", #events("ping") >= 1)
Engine.fireServer(ava, "Act", "main", Vector3.new(1, 0, 0))
Engine.advance(0.1)
flush()
check("moves are counted, not logged", #events("req_act") == 0 and (Analytics:Session(ava).acts or 0) > 0)
check("job picks tracked", #events("job") >= 3)
check("tutorial steps tracked", #events("tutorial_step", ava) >= 3)
local sid = Analytics:Session(ava).id
Analytics:_snapshot(ava)
flush()
local live = aSessions[sid] and aSessions[sid].live
check(
	"the live row for the dashboard",
	live and live.phase ~= nil and live.shrine ~= nil and live.built ~= nil and live.beaten ~= nil
)
check("the live row has team and job", live and (live.team == "dwarf" or live.team == "monster") and live.job ~= nil)
check(
	"game log: matches",
	(function()
		for _, e in gameLogs do
			if string.find(e.title or "", "Match #") then
				return true
			end
		end
		return false
	end)()
)
check(
	"game log: shrines falling",
	(function()
		for _, e in gameLogs do
			if string.find(e.title or "", "Shrine 1 fell") then
				return true
			end
		end
		return false
	end)()
)
check(
	"game log: joins",
	(function()
		for _, e in gameLogs do
			if string.find(e.title or "", "joined") then
				return true
			end
		end
		return false
	end)()
)

-- 31. Feedback ---------------------------------------------------------------------------------------------------------
Data:Get(ben).feedback = { asks = 0 }
check("the feedback card can be asked", Feedback:Ask(ben))
Engine.fireServer(ben, "Feedback", false, "more monsters badword", { "doomed", "nonsense" })
Engine.advance(0.2)
flush()
local fbe = events("feedback", ben)[1]
check("feedback is tracked", fbe ~= nil and fbe.data.like == false)
check("feedback reasons are checked", fbe and #fbe.data.reasons == 1 and fbe.data.reasons[1] == "doomed")
check("feedback text is filtered", fbe and fbe.data.text and not string.find(fbe.data.text, "badword"))

-- 32. Leaving mid-match ---------------------------------------------------------------------------------------------------
Engine.removePlayer(eve)
Engine.advance(1)
check("leaving cleans up", Teams:State(eve) == nil)
flush()
check(
	"the leave is tracked",
	(function()
		for _, e in aEvents do
			if e.kind == "leave" and e.user_id == eve.UserId then
				return true
			end
		end
		return false
	end)()
)
check("no script errors", #Engine.warnings == 0 or (function()
	for _, w in Engine.warnings do
		if
			(string.find(w, "failed") or string.find(w, "Service%]")) and not string.find(w, "DataStore unavailable")
		then
			print("WARNING: " .. w)
			return false
		end
	end
	return true
end)())

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("server smoke test failed")
end

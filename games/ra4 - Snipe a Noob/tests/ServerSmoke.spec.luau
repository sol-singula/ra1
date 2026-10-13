--[[
Server smoke test: boots the real server scripts on the mock engine and plays rounds of Snipe a Noob:
join, wait for a second player, the lobby countdown, the round (spawns, shots, pops, shields, walls, lag
compensation, headshots, streaks, revenge, the crown, double tap, falling, leaving and rejoining, the last minute),
the podium, the next round, Revive Now, and leaving. Fails on any script error or broken expectation.

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
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Combat = service("CombatService")
local Round = service("RoundService")
local Loadout = service("LoadoutService")
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)
local World = Engine.require(tree.server.World.WorldBuilder)
local MapBuilder = Engine.require(tree.server.World.MapBuilder)
local layout = World.layout

local function join(name, id)
	local p = Engine.addPlayer(name, id)
	Engine.makeCharacter(p)
	Engine.advance(0.2)
	Engine.fireServer(p, "Ready")
	Engine.advance(0.3)
	return p
end
local function root(p)
	return p.Character.HumanoidRootPart
end
local function place(p, pos, look)
	Engine.moveTo(p, pos, look)
	Engine.advance(0.05)
end
local function headOf(p)
	return root(p).Position + Vector3.new(0, Constants.HEAD_OFFSET, 0)
end
-- shoot from p's head at a point
local function shoot(p, target, firedAt)
	local from = headOf(p)
	return Combat:Fire(p, from, (target - from).Unit, firedAt or Engine.workspace:GetServerTimeNow())
end
local function waitBolt(p)
	Engine.advance(Loadout:Rifle(p).bolt + 0.05)
end

-- Join ------------------------------------------------------------------------------------------------------
local a = join("Ava", 1001)
local pa = Data:Get(a)
check("profile loaded", pa ~= nil)
check("leaderstats", a:FindFirstChild("leaderstats") ~= nil and a.leaderstats:FindFirstChild("Pops") ~= nil)
check("starts in the lobby", a:GetAttribute("Zone") == "lobby")
check("holds a rifle", a.Character:FindFirstChild("Rifle") ~= nil)
check("the rifle has a muzzle", a.Character.Rifle.Handle:FindFirstChild("Muzzle") ~= nil)
check("starts with the Bolt", pa.rifles.BOLT == true and pa.rifle == "BOLT")
check("alone: waiting", Round.state == "waiting")
check("the lobby sign says waiting", layout.status[1].Text:find("WAITING", 1, true) ~= nil, layout.status[1].Text)
check("the client hears the round state", Engine.lastClientEvent("Round", a) ~= nil)
check("no shooting in the lobby", select(2, shoot(a, Vector3.new(0, 3, -20))) == "zone")

-- A second player: the countdown -------------------------------------------------------------------------------
local b = join("Ben", 1002)
local pb = Data:Get(b)
Engine.advance(0.5)
check("2 players: the lobby countdown starts", Round.state == "lobby")
check("the sign counts down", layout.status[1].Text:find("NEXT ROUND", 1, true) ~= nil, layout.status[1].Text)
Engine.advance(Constants.LOBBY_SECONDS + 0.5)
check("the round starts", Round.state == "round" and Round.map ~= nil)
check("the arena is built", Engine.workspace.Arena:FindFirstChildOfClass("Model") ~= nil)
check("2 players get the small map", Round.map.size == "small")
check("both go in", a:GetAttribute("Zone") == "arena" and b:GetAttribute("Zone") == "arena")
local c = Round.map.center
local function inMap(p)
	local pos = root(p).Position
	return math.abs(pos.X - c.X) <= Round.map.half and math.abs(pos.Z - c.Z) <= Round.map.half
end
check("they spawn inside the arena", inMap(a) and inMap(b))
check(
	"spawned apart",
	(root(a).Position - root(b).Position).Magnitude > 30,
	(root(a).Position - root(b).Position).Magnitude
)
check("spawn shield", Combat.shielded(a) and a.Character:FindFirstChild("SpawnShield") ~= nil)
check("round alert", Engine.lastClientEvent("Alert", a) ~= nil)

-- Shooting ---------------------------------------------------------------------------------------------------------
-- up in the open air over the arena, facing each other
local A_POS, B_POS = c + Vector3.new(0, 40, 30), c + Vector3.new(0, 40, -30)
place(a, A_POS, B_POS)
place(b, B_POS, A_POS)
local victim, why = shoot(a, root(b).Position)
check("a shielded player can't be popped", victim == nil and why == "shield", why)
check("firing breaks your own shield", not Combat.shielded(a))
Engine.advance(Constants.SHIELD_SECONDS + 0.2)
local coins0 = pa.coins
victim, why = shoot(a, root(b).Position)
check("one hit pops", victim == b, why)
check("the popped player waits in the pop box", b:GetAttribute("Popped") == true and root(b).Anchored == true)
check("the pop box is out of sight", (root(b).Position - World.POP_BOX).Magnitude < 1)
check("the shooter gets coins", pa.coins == coins0 + Constants.COINS.pop * Economy:CoinMult(a), pa.coins - coins0)
check("the shooter gets a hit marker", Engine.lastClientEvent("Hit", a) ~= nil)
check("everyone sees the tracer", Engine.lastClientEvent("Shot") ~= nil)
check("everyone sees the pop", Engine.lastClientEvent("Pop") ~= nil)
local popped = Engine.lastClientEvent("Popped", b)
check("the victim learns who popped them", popped and popped.args[1].by == "Ava" and popped.args[1].userId == 1001)
local feed = Engine.lastClientEvent("Feed")
check("kill feed", feed and feed.args[1].killer == "Ava" and feed.args[1].victim == "Ben")
check("round score", Round.scores[a].pops == 1 and Round.scores[b].deaths == 1)
check("leaderstats pops", a.leaderstats.Pops.Value == 1)
check("lifetime stats", pa.stats.pops == 1 and pb.stats.deaths == 1)
check("daily pops for the board", pa.dailyPops.pops == 1)
check("mastery counts", pa.mastery.BOLT == 1)
check("xp", pa.xp > 0)
check("the leader wears the crown", a:GetAttribute("Crown") == true)
check("can't shoot a popped player", select(2, shoot(a, root(b).Position)) ~= nil)
-- fire rate and cheating
place(a, A_POS, B_POS)
check("the bolt: no second shot right away", select(2, shoot(a, B_POS)) == "cooldown")
waitBolt(a)
check(
	"a shot must start at your head",
	select(2, Combat:Fire(a, A_POS + Vector3.new(0, 30, 0), Vector3.new(0, 0, -1))) == "origin"
)
check("bad arguments are ignored", select(2, Combat:Fire(a, "x", Vector3.new(0, 0, -1))) == "args")
-- respawn
Engine.advance(Constants.RESPAWN_SECONDS)
check("back after 5 seconds", b:GetAttribute("Popped") == nil and not root(b).Anchored)
check("respawned in the arena", b:GetAttribute("Zone") == "arena" and inMap(b))
check("with a spawn shield", Combat.shielded(b))
Engine.advance(Constants.SHIELD_SECONDS + 0.1)

-- walls block shots
place(a, A_POS, B_POS)
place(b, B_POS, A_POS)
local wall = Engine.Instance.new("Part")
wall.Anchored = true
wall.Size = Vector3.new(20, 20, 2)
wall.CFrame = CFrame.new(c + Vector3.new(0, 40, 0))
wall.Parent = Round.map.model
waitBolt(a)
victim, why = shoot(a, root(b).Position)
check("a wall blocks the shot", victim == nil and why == "miss", why)
local shotEv = Engine.lastClientEvent("Shot")
check(
	"the tracer stops at the wall",
	shotEv and math.abs(shotEv.args[2].Z - (c.Z + 1)) < 0.6,
	shotEv and shotEv.args[2]
)
wall:Destroy()

-- lag compensation: Ben moved, but Ava shot at where she saw him a moment ago
place(b, B_POS, A_POS)
Engine.advance(0.2)
local seenAt = Engine.workspace:GetServerTimeNow()
place(b, B_POS + Vector3.new(8, 0, 0), A_POS)
Engine.advance(0.1)
waitBolt(a)
Engine.advance(0.0)
local now = Engine.workspace:GetServerTimeNow()
-- a shot fired 0.25 s ago (within the rewind limit) at Ben's old spot hits
seenAt = now - 0.25
place(b, B_POS, A_POS)
Engine.advance(0.1)
place(b, B_POS + Vector3.new(8, 0, 0), A_POS)
Engine.advance(0.15)
victim = shoot(a, B_POS, Engine.workspace:GetServerTimeNow() - 0.2)
check("lag compensation: a shot at where Ben was 0.2 s ago hits", victim == b)
Engine.advance(Constants.RESPAWN_SECONDS + Constants.SHIELD_SECONDS + 0.2)
place(b, B_POS, A_POS)
Engine.advance(0.3)
place(b, B_POS + Vector3.new(8, 0, 0), A_POS)
Engine.advance(0.6)
victim = shoot(a, B_POS, Engine.workspace:GetServerTimeNow() - 1.0)
check("but never more than 0.3 s back", victim == nil)
_ = seenAt

-- headshots
waitBolt(a)
place(b, B_POS, A_POS)
Engine.advance(0.4)
local coinsH = pa.coins
victim = shoot(a, headOf(b))
check("a headshot pops", victim == b)
check(
	"headshots pay double",
	pa.coins - coinsH >= math.floor(Constants.COINS.headshot * Economy:CoinMult(a)),
	pa.coins - coinsH
)
check("headshot stat", pa.stats.headshots == 1)
check("the victim hears it was a headshot", Engine.lastClientEvent("Popped", b).args[1].headshot == true)
Engine.advance(Constants.RESPAWN_SECONDS + Constants.SHIELD_SECONDS + 0.1)
check(
	"3 pops in a row: ON FIRE",
	Engine.lastClientEvent("Streak") and Engine.lastClientEvent("Streak").args[1] == "Ava"
)
check("best streak", Round.scores[a].best >= 3)

-- revenge: Ben pops Ava, who popped him last
place(a, A_POS, B_POS)
place(b, B_POS, A_POS)
Engine.advance(0.1)
local coinsR = pb.coins
victim = shoot(b, root(a).Position)
check("Ben gets his revenge", victim == a)
check(
	"revenge pays a bonus",
	pb.coins - coinsR >= math.floor((Constants.COINS.pop + Constants.COINS.revenge) * Economy:CoinMult(b)),
	pb.coins - coinsR
)
check("the feed says REVENGE", Engine.lastClientEvent("Feed").args[1].tag == "😤 REVENGE")
check("popping the crown", Engine.lastClientEvent("Feed") ~= nil and pb.stats.crowns == 1)
check("Ava's streak is over", Round.scores[a].streak == 0)
Engine.advance(Constants.RESPAWN_SECONDS + Constants.SHIELD_SECONDS + 0.1)

-- falling out: back to a spawn, nobody scores
local deathsBefore = Round.scores[b].deaths
place(b, c + Vector3.new(0, -60, 0))
Engine.advance(0.1)
check("falling out puts you back in", inMap(b) and root(b).Position.Y > c.Y - 5)
check("a fall isn't a pop", Round.scores[b].deaths == deathsBefore and b:GetAttribute("Popped") == nil)

-- double tap: Cat (Ava's friend) and Ava both pop someone within 3 seconds
Engine.makeFriends(a, { UserId = 1003 })
local cat = join("Cat", 1003)
local dan = join("Dan", 1004)
local pc = Data:Get(cat)
Engine.fireServer(cat, "Play")
Engine.fireServer(dan, "Play")
Engine.advance(0.2)
check("PLAY jumps you into the round", cat:GetAttribute("Zone") == "arena" and dan:GetAttribute("Zone") == "arena")
check("latecomers get a score line", Round.scores[cat] ~= nil)
Engine.advance(Constants.SHIELD_SECONDS + 0.1)
place(cat, c + Vector3.new(30, 40, 0), c + Vector3.new(-30, 40, 0))
place(dan, c + Vector3.new(-30, 40, 0), c + Vector3.new(30, 40, 0))
place(a, A_POS, B_POS)
place(b, B_POS, A_POS)
waitBolt(a)
local catCoins = pc.coins
shoot(cat, root(dan).Position)
victim = shoot(a, root(b).Position)
check(
	"double tap",
	victim == b
		and pc.coins - catCoins
			>= math.floor((Constants.COINS.pop + Constants.COINS.doubleTap) * Economy:CoinMult(cat)),
	pc.coins - catCoins
)
check("friends earn more coins", Economy:CoinMult(cat) > 1)
Engine.advance(Constants.RESPAWN_SECONDS + Constants.SHIELD_SECONDS + 0.1)

-- leaving and rejoining
Engine.fireServer(dan, "Leave")
Engine.advance(0.1)
check("LOBBY takes you out of the round", dan:GetAttribute("Zone") == "lobby" and World.inLobby(root(dan).Position))
place(dan, layout.playPad.center + Vector3.new(0, 3, 0))
Engine.advance(0.5)
check("the PLAY pad puts you back in", dan:GetAttribute("Zone") == "arena")
-- a fresh character (reset) goes back into the round
Engine.makeCharacter(cat)
Engine.advance(0.3)
check("a reset puts you back in the round", cat:GetAttribute("Zone") == "arena" and inMap(cat))

-- Revive Now
Engine.advance(Constants.SHIELD_SECONDS + 0.1)
place(a, A_POS, B_POS)
place(b, B_POS, A_POS)
waitBolt(a)
shoot(a, root(b).Position)
check("Ben is popped", b:GetAttribute("Popped") == true)
Engine.fireServer(b, "Purchase", "product", "REVIVE")
Engine.advance(0.1)
check("Revive Now brings you straight back", b:GetAttribute("Popped") == nil and inMap(b))

-- the last minute: 2x coins
Round.endsAt = Engine.workspace:GetServerTimeNow() + 50
Engine.advance(0.5)
check(
	"last minute banner",
	Engine.lastClientEvent("Announce")
		and tostring(Engine.lastClientEvent("Announce").args[1]):find("LAST MINUTE", 1, true) ~= nil
)
check("the round info says last minute", Round:Info().lastMinute == true)
Engine.advance(Constants.SHIELD_SECONDS + 0.1)
place(a, A_POS, B_POS)
place(b, B_POS, A_POS)
waitBolt(a)
local coinsL = pa.coins
shoot(a, root(b).Position)
check(
	"2x coins in the last minute",
	pa.coins - coinsL >= math.floor(Constants.COINS.pop * 2 * Economy:CoinMult(a)),
	pa.coins - coinsL
)

-- The end: podium ------------------------------------------------------------------------------------------------
local roundsBefore, winsBefore = pa.stats.rounds, pa.stats.wins
Round.endsAt = Engine.workspace:GetServerTimeNow() + 0.1
Engine.advance(0.5)
check("the round ends: podium", Round.state == "podium")
check(
	"everyone is back in the lobby",
	a:GetAttribute("Zone") == "lobby" and b:GetAttribute("Zone") == "lobby" and World.inLobby(root(a).Position)
)
check("nobody stays popped", b:GetAttribute("Popped") == nil and not root(b).Anchored)
local pod = Engine.lastClientEvent("Podium")
check(
	"the podium event names the top 3",
	pod and #pod.args[1] >= 2 and pod.args[1][1].name == "Ava",
	pod and pod.args[1][1] and pod.args[1][1].name
)
check(
	"the winner stands on the top step",
	(root(a).Position - (layout.podium.spots[1] + Vector3.new(0, 3, 0))).Magnitude < 1
)
check("the podium sign shows the names", layout.podium.names[1][1].Text == "Ava")
check("a round and a win counted", pa.stats.rounds == roundsBefore + 1 and pa.stats.wins == winsBefore + 1)
check("podium counted", pa.stats.podiums == 1)
check("the arena is cleared", Engine.workspace.Arena:FindFirstChildOfClass("Model") == nil and Round.map == nil)
check("the crown comes off", a:GetAttribute("Crown") == nil)
check("the lobby sign shows the winner", layout.status[2].Text:find("Ava", 1, true) ~= nil, layout.status[2].Text)
Engine.advance(Constants.PODIUM_SECONDS + 0.5)
check("then the next countdown", Round.state == "lobby")
check("map size grows with the crowd", MapBuilder.sizeFor(12) == "medium" and MapBuilder.sizeFor(20) == "large")

-- The next round, and the round ending when players leave
Engine.advance(Constants.LOBBY_SECONDS + 0.5)
check("next round", Round.state == "round" and a:GetAttribute("Zone") == "arena")
check("pops reset for the new round", a.leaderstats.Pops.Value == 0)
Engine.removePlayer(cat)
Engine.removePlayer(dan)
Engine.removePlayer(b)
Engine.advance(0.5)
check("1 player left: the round ends", Round.state ~= "round")
Engine.advance(Constants.PODIUM_SECONDS + 0.5)
check("and it waits again", Round.state == "waiting")

-- Every map and size builds -------------------------------------------------------------------------------------
for _, m in Engine.require(tree.shared.Data.Maps).list do
	for _, s in Constants.MAP_SIZES do
		local built = MapBuilder.build(m.key, s.key, Engine.workspace, Vector3.new(3000, 0, 3000))
		check(`{m.name} {s.key} builds with spawns`, built.model ~= nil and #built.spawns >= 8, #built.spawns)
		-- no spawn is inside a solid part
		local inside = 0
		for _, sp in built.spawns do
			for _, d in built.model:GetDescendants() do
				if
					d:IsA("BasePart")
					and d.CanCollide
					and d.Name ~= "Floor"
					and d.Name ~= "Ground"
					and d.Name ~= "Deck"
				then
					local lp = d.CFrame:PointToObjectSpace(sp + Vector3.new(0, 2, 0))
					if
						math.abs(lp.X) < d.Size.X / 2
						and math.abs(lp.Y) < d.Size.Y / 2
						and math.abs(lp.Z) < d.Size.Z / 2
					then
						inside += 1
					end
				end
			end
		end
		check(`{m.name} {s.key}: spawns are clear`, inside == 0, inside)
		built.model:Destroy()
	end
end

-- Leaving --------------------------------------------------------------------------------------------------------
Engine.removePlayer(a)
Engine.advance(0.5)
check("formula sanity", Formulas.popCoins({}) == Constants.COINS.pop)

-- Shutdown --------------------------------------------------------------------------------------------------------
for _, fn in Engine.closeHandlers do
	fn()
end
Engine.advance(1)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
local warnings = {}
for _, w in Engine.warnings do
	if not w:find("DataStore unavailable") then
		table.insert(warnings, w)
	end
end
check("no warnings", #warnings == 0, warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("server smoke test failed")
end

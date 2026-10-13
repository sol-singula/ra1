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
local os = Engine.globals.os -- the game's clock
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
-- robots are tested on their own near the end; keep them out of the scripted fights
local Robots = service("RobotService")
local robotWanted = Robots.Wanted
Robots.Wanted = function()
	return 0
end

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

-- (alone the server waits SOLO_WAIT seconds, then plays with robots: off until the solo test near the end)
local SOLO_WAIT = Constants.SOLO_WAIT
Constants.SOLO_WAIT = 1e9

-- Join ------------------------------------------------------------------------------------------------------
local a = join("Ava", 1001)
local pa = Data:Get(a)
check("profile loaded", pa ~= nil)
check("leaderstats", a:FindFirstChild("leaderstats") ~= nil and a.leaderstats:FindFirstChild("Pops") ~= nil)
check("starts in the lobby", a:GetAttribute("Zone") == "lobby")
check("hands free in the lobby", a.Character:FindFirstChild("Rifle") == nil)
check("starts with the Bolt", pa.rifles.BOLT == true and pa.rifle == "BOLT")
check("alone: waiting", Round.state == "waiting")
check("the lobby sign says waiting", layout.status[1].Text:find("STARTING", 1, true) ~= nil, layout.status[1].Text)
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
check("holds a rifle in the round", a.Character:FindFirstChild("Rifle") ~= nil)
check("the rifle has a muzzle", a.Character.Rifle.Handle:FindFirstChild("Muzzle") ~= nil)
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
check("1 player left: the round keeps going", Round.state == "round")
Round.endsAt = Engine.workspace:GetServerTimeNow()
Engine.advance(0.5)
Engine.advance(Constants.PODIUM_SECONDS + 0.5)
check("and it waits again", Round.state == "waiting")

-- Progression and the lobby ---------------------------------------------------------------------------------------
local Quest = service("QuestService")
local Playtime = service("PlaytimeService")
local Crate = service("CrateService")
local Season = service("SeasonService")
local Trade = service("TradeService")
local Leaderboard = service("LeaderboardService")
local Vote = service("VoteService")
local Duel = service("DuelService")
local Range = service("RangeService")
local GameLog = service("GameLogService")
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local Rifles = Engine.require(tree.shared.Data.Rifles)
local gameLogs = {}
GameLog.send = function(payload)
	for _, e in payload.events do
		table.insert(gameLogs, e)
	end
	return true
end
local function logged(text)
	for _, e in gameLogs do
		if tostring(e.title):find(text, 1, true) then
			return e
		end
	end
	return nil
end
do
	-- levels
	local xp0 = Formulas.levelFromXp(pa.xp)
	Economy:AddXp(a, Formulas.xpForLevel(xp0) * 3)
	check("XP levels you up", Formulas.levelFromXp(pa.xp) > xp0)
	check(
		"level up banner",
		Engine.lastClientEvent("Alert", a)
			and tostring(Engine.lastClientEvent("Alert", a).args[1]):find("LEVEL", 1, true) ~= nil
	)
	check("level shows in the player list", a.leaderstats.Level.Value == Formulas.levelFromXp(pa.xp))
	-- rifles: locked by level, then bought with coins
	pa.xp = 0
	Economy:PushAll(a)
	pa.coins = 100000
	check("a rifle above your level is locked", not Loadout:BuyRifle(a, "SWIFT") and not pa.rifles.SWIFT)
	local xpTo5 = 0
	for l = 1, 4 do
		xpTo5 += Formulas.xpForLevel(l)
	end
	pa.xp = xpTo5
	Economy:PushAll(a)
	check("level 5", Economy:Level(a) == 5)
	check("buy the Swift at level 5", Loadout:BuyRifle(a, "SWIFT") and pa.rifles.SWIFT and pa.rifle == "SWIFT")
	check("it costs coins", pa.coins == 100000 - Rifles.byKey.SWIFT.price)
	Combat.setZone(a, "range") -- (no time passes: the range would send a back to the lobby)
	check("the Swift is in your hands on the range", a.Character.Rifle:GetAttribute("Rifle") == "SWIFT")
	Combat.setZone(a, "lobby")
	check("and put away in the lobby", a.Character:FindFirstChild("Rifle") == nil)
	check("the Swift fires faster", Loadout:Rifle(a).bolt < Rifles.byKey.BOLT.bolt)
	check("hold the Bolt again", Loadout:EquipRifle(a, "BOLT") and pa.rifle == "BOLT")
	check("swapping needs the Extra Loadout pass", not Loadout:SwapRifle(a))
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "pass", "LOADOUT")
	Engine.advance(0.1)
	Loadout:EquipRifle(a, "SWIFT")
	check("with the pass: swap mid-round", Loadout:SwapRifle(a) and pa.rifle == "BOLT" and pa.rifle2 == "SWIFT")
	-- Style counter: crosshairs and name colours
	check("buy a crosshair", Loadout:BuyStyle(a, "crosshair", "RING") and pa.crosshair == "RING")
	check("buy a name colour", Loadout:BuyStyle(a, "nameColor", "PINK") and pa.nameColor == "PINK")
	check("the feed uses your colour", Loadout:NameColor(a) == Cosmetics.nameColorById.PINK.color)
	check("can't buy a pop effect on the Style counter", not Loadout:BuyStyle(a, "effect", "FIRE"))
	check("can't equip what you don't own", not Loadout:EquipStyle(a, "effect", "FIRE"))
	-- the Daily Shop
	local shop = Formulas.dailyShop(Formulas.dailyPeriod(os.time()))
	local coinsS = pa.coins
	local okBuy = Loadout:BuyShop(a, 1)
	check("buy from the Daily Shop", okBuy and pa.coins == coinsS - shop[1].price)
	check("only once a day", not Loadout:BuyShop(a, 1))
	check("the skin is in your bag", #pa.skins >= 1 and pa.skins[#pa.skins].id == shop[1].id)
	local effectIndex
	for i, item in shop do
		if item.kind == "effect" then
			effectIndex = i
		end
	end
	check("buy a pop effect from the shop", Loadout:BuyShop(a, effectIndex) and pa.effect == shop[effectIndex].id)
	-- skins on rifles
	local uid = pa.skins[1].uid
	check("put a skin on the Bolt", Loadout:EquipSkin(a, "BOLT", uid) and Loadout:SkinId(a, "BOLT") == pa.skins[1].id)
	Combat.setZone(a, "range")
	check("the Tool shows the skin", a.Character.Rifle:GetAttribute("Skin") == pa.skins[1].id)
	Combat.setZone(a, "lobby")
	check("a skin is on one rifle at a time", Loadout:EquipSkin(a, "SWIFT", uid) and Loadout:SkinId(a, "BOLT") == nil)
	check("take it off", Loadout:EquipSkin(a, "SWIFT", nil) and Loadout:SkinId(a, "SWIFT") == nil)
	-- mastery
	pa.mastery.BOLT = Constants.MASTERY[1] - 1
	Loadout:AddMasteryPop(a)
	check("100 pops: Gold Bolt", Loadout:MasteryTier(a, "BOLT") == 1)
	check("mastery banner", tostring(Engine.lastClientEvent("Alert", a).args[1]):find("Gold", 1, true) ~= nil)
	-- the loadout view the client gets
	local view = Loadout:View(a)
	check(
		"loadout view",
		#view.rifles == #Rifles.list and #view.shop == Constants.DAILY_SHOP_SIZE and view.shop[1].bought == true
	)
end

-- Quests, gifts, boost
do
	pa.quests = nil -- a fresh day of quests (the rounds above already finished today's)
	local qv = Quest:View(a)
	check("3 daily quests", #qv.list == 3)
	local q = pa.quests
	local qi = 1
	for i = 1, 3 do
		if not q.done[i] then
			qi = i
			break
		end
	end
	local first = Engine.require(tree.shared.Data.Quests)[q.list[qi]]
	pa.stats[first.kind] = (q.start[first.kind] or 0) + first.target
	local before = first.keys and pa.keys or pa.coins
	Quest:Check(a)
	check("a finished quest pays", (first.keys and pa.keys or pa.coins) > before and pa.quests.done[qi] == true)
	check("quest alert", tostring(Engine.lastClientEvent("Alert", a).args[1]):find("QUEST DONE", 1, true) ~= nil)
	local coinsQ = pa.coins
	local open
	for i = 1, 3 do
		if not pa.quests.done[i] then
			open = i
		end
	end
	check(
		"swap a quest for coins",
		open ~= nil and Quest:Swap(a, open) and pa.coins == coinsQ - Constants.QUEST_REROLL_COINS
	)
	check("only one swap a day", not Quest:Swap(a, open or 1))
	check("can't swap a finished quest", not Quest:Swap(a, qi))
	local coinsD = pa.coins
	check("claim the daily gift", Quest:ClaimDaily(a) and pa.coins > coinsD and pa.daily.streak >= 1)
	check("once a day", not Quest:ClaimDaily(a))
	-- playtime gifts: the first at 1 minute
	pa.playtime = { day = Formulas.day(os.time()), seconds = 55, given = 0 }
	local coinsP = pa.coins
	Engine.advance(6)
	check("a playtime gift at 1 minute", pa.playtime.given == 1 and pa.coins > coinsP)
	check("the next gift is shown", Playtime:View(a).nextText ~= nil)
	-- the new-player boost doubles coins
	pa.newBoostLeft = 30
	local m2 = Economy:CoinMult(a)
	pa.newBoostLeft = 0
	check("new-player boost doubles coins", math.abs(m2 / Economy:CoinMult(a) - Constants.NEW_PLAYER_BOOST_MULT) < 1e-6)
end

-- Purchases
do
	local keys0 = pa.keys
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "product", "KEYS_5")
	Engine.advance(0.1)
	check("5 crate keys", pa.keys == keys0 + 5)
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "product", "CALLOUT")
	Engine.advance(0.1)
	check("round callout ready", pa.callout == true)
	local m0 = Economy:CoinMult(a)
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "pass", "VIP")
	Engine.advance(0.1)
	check("VIP: +20% coins", math.abs(Economy:CoinMult(a) / m0 - Constants.VIP_COIN_MULT) < 1e-6)
	check("VIP: gold name", Loadout:NameColor(a) == Cosmetics.nameColorById.PINK.color)
	Loadout:EquipStyle(a, "nameColor", "WHITE")
	check("VIP gold when you wear white", Loadout:NameColor(a) == Cosmetics.nameColorById.GOLD.color)
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "pass", "COINS2")
	Engine.advance(0.1)
	check("2x Coins", math.abs(Economy:CoinMult(a) / m0 - Constants.VIP_COIN_MULT * 2) < 1e-6)
end

-- Crates
do
	pa.coins = 50000
	local n = #pa.skins
	local id = Crate:Open(a, "COIN")
	check("open a Coin Crate", id ~= nil and #pa.skins == n + 1 and pa.coins == 50000 - Constants.COIN_CRATE_PRICE)
	check("the reveal", Engine.lastClientEvent("Crate", a) and Engine.lastClientEvent("Crate", a).args[1].skin == id)
	local keys = pa.keys
	id = Crate:Open(a, "KEY")
	check("open a Key Crate with a key", id ~= nil and pa.keys == keys - 1)
	check("Key Crates give Rare or better", Cosmetics.RarityRank[Cosmetics.skinById[id].rarity] >= 2)
	pa.keys = 0
	check("no key, no crate", Crate:Open(a, "KEY") == nil)
	pa.coins = 10
	check("no coins, no crate", Crate:Open(a, "COIN") == nil)
	Engine.policy = { IsPaidItemTradingAllowed = false, ArePaidRandomItemsRestricted = true }
	local kid = join("Kid", 1010)
	Engine.advance(0.3)
	Data:Get(kid).keys = 3
	check("restricted accounts can't open Key Crates", Crate:Open(kid, "KEY") == nil and not Crate:CanPaid(kid))
	check("restricted accounts can't trade", not Trade:CanTrade(kid))
	Engine.policy = { IsPaidItemTradingAllowed = true, ArePaidRandomItemsRestricted = false }
	Engine.removePlayer(kid)
	Engine.advance(0.2)
end

-- Season
do
	local sv = Season:View(a)
	check("season view", sv.n ~= nil and sv.tier >= 0 and sv.endsAt > os.time())
	local need = Constants.SEASON_TIER_XP * 5 - pa.season.xp
	Economy:AddXp(a, need + 1)
	check("XP fills the season", Season:View(a).tier >= 5)
	local coinsT = pa.coins
	check("claim a free tier", Season:Claim(a, 1, "free") and pa.coins > coinsT)
	check("once", not Season:Claim(a, 1, "free"))
	check("pass rewards need the pass", not Season:Claim(a, 1, "pass"))
	check("can't claim a tier you haven't reached", not Season:Claim(a, 40, "free"))
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "product", "SEASON")
	Engine.advance(0.1)
	check("the Season Pass", pa.season.pass == true)
	check("claim a pass tier", Season:Claim(a, 5, "pass") and next(pa.effects) ~= nil)
	-- tier 10 gives a season skin
	Economy:AddXp(a, Constants.SEASON_TIER_XP * 6)
	local skins = #pa.skins
	check(
		"tier 10: a season-only skin",
		Season:Claim(a, 10, "pass")
			and #pa.skins == skins + 1
			and Cosmetics.skinById[pa.skins[#pa.skins].id].source == "season"
	)
end

-- The Trade Plaza
do
	local b2 = join("Ben", 1002)
	local pb2 = Data:Get(b2)
	Engine.advance(0.3)
	local rec = Loadout:GrantSkin(a, "GOLD", "test")
	check("list a skin on a stall", Trade:List(a, 1, rec.uid, 10000))
	check(
		"the skin leaves your bag",
		(function()
			for _, s in pa.skins do
				if s.uid == rec.uid then
					return false
				end
			end
			return true
		end)()
	)
	check("the stall sign shows it", layout.stalls[1].lines[1].Text:find("Gold", 1, true) ~= nil)
	check("one stall per player", not Trade:List(a, 2, pa.skins[1].uid, 500))
	check("a taken stall", not Trade:List(b2, 1, 0, 500))
	pb2.coins = 20000
	local sellerCoins = pa.coins
	check("buy it", Trade:Buy(b2, 1))
	check("the buyer pays", pb2.coins == 10000)
	check("the seller gets it minus 10%", pa.coins == sellerCoins + 9000, pa.coins - sellerCoins)
	check("the buyer has the skin", pb2.skins[#pb2.skins].id == "GOLD")
	check("the stall is empty again", Trade.stalls[1] == nil and layout.stalls[1].lines[1].Text == "EMPTY STALL")
	local prize = Loadout:GrantSkin(a, "P_CROWN", "test")
	check("prize skins can't be sold", not Trade:List(a, 2, prize.uid, 500))
	local rec2 = Loadout:GrantSkin(a, "MINT", "test")
	Trade:List(a, 3, rec2.uid, 500)
	check("take it back", Trade:Unlist(a, 3) and pa.skins[#pa.skins].id == "MINT")
	Engine.removePlayer(b2)
	Engine.advance(0.2)
end

-- Leaderboards and the daily prize
do
	local b3 = join("Ben", 1002)
	Engine.advance(0.3)
	pa.stats.pops = 77
	pa.stats.bestStreak = 9
	Leaderboard:Write(a)
	Leaderboard:Refresh()
	local boards = layout.boards
	check(
		"MOST POPS board",
		boards.pops.rows[1].name.Text ~= "" and boards.pops.rows[1].value.Text ~= "",
		boards.pops.rows[1].name.Text
	)
	check(
		"BEST STREAK board",
		boards.streak.rows[1].name.Text == "SnipeKid" or boards.streak.rows[1].name.Text == "Ava"
	)
	check("HIGHEST LEVEL board", boards.level.rows[1].value.Text:find("LV", 1, true) ~= nil)
	check("the prize timer", boards.daily.timer.Text:find("Champion", 1, true) ~= nil)
	local period = Formulas.dailyPeriod(os.time())
	pa.dailyPops = { period = period, pops = 500 }
	Leaderboard:Redraw()
	local n = #pa.skins
	Leaderboard:_rollover(period)
	check("the daily TOP SNIPER gets the Champion skin", #pa.skins == n + 1 and pa.skins[#pa.skins].id == "P_CROWN")
	check("only once a day", not Leaderboard:GivePrize(a, period))
	Engine.removePlayer(b3)
	Engine.advance(0.2)
end

-- Robots: they fill a quiet round, fight, and leave when it ends
do
	Robots.Wanted = robotWanted
	local b4 = join("Ben", 1002)
	Engine.advance(0.5)
	Engine.advance(Constants.LOBBY_SECONDS + 1)
	check("a round with 2 players", Round.state == "round")
	check("robots fill up to 4 fighters", #Robots.robots == 2, #Robots.robots)
	local bot = Robots.robots[1]
	check(
		"robots are in the arena",
		bot.zone == "arena" and Engine.workspace.Robots:FindFirstChild(bot.model.Name) ~= nil
	)
	check("robots are on the scoreboard", Round.scores[bot] ~= nil)
	-- a player pops a robot
	Robots.paused = true
	Engine.advance(Constants.SHIELD_SECONDS + 0.2)
	if a:GetAttribute("Popped") then
		Combat:Respawn(a, true)
	end
	for _, other in Robots.robots do
		other.model:PivotTo(CFrame.new(Round.map.center + Vector3.new(60, 150, 60)))
	end
	local c2 = Round.map.center
	if bot.popped then
		Combat:Respawn(bot, true)
	end
	bot.shieldUntil = nil
	place(a, c2 + Vector3.new(0, 150, 30), c2 + Vector3.new(0, 150, -30))
	bot.model:PivotTo(CFrame.new(c2 + Vector3.new(0, 150, -30)))
	Engine.advance(0.05)
	local coinsR = pa.coins
	local robotsBefore = pa.stats.robots
	local v = shoot(a, bot.root.Position)
	check("pop a robot", v == bot and bot.popped == true)
	check(
		"robots pay a few coins",
		pa.coins > coinsR and pa.coins - coinsR <= math.ceil(Constants.COINS.robot * Economy:CoinMult(a) * 2)
	)
	check("robot pops don't count as pops", pa.stats.robots == robotsBefore + 1)
	Engine.advance(Constants.RESPAWN_SECONDS + 0.2)
	check("robots respawn", bot.popped == false)
	-- robots walk and shoot by themselves
	Robots.paused = false
	local start = bot.root.Position
	Engine.advance(3)
	check("robots move or fight", (bot.root.Position - start).Magnitude > 0.5 or Engine.lastClientEvent("Shot") ~= nil)
	-- a robot pops a player
	Engine.advance(2)
	Robots.paused = true
	if a:GetAttribute("Popped") then
		Engine.advance(Constants.RESPAWN_SECONDS + Constants.SHIELD_SECONDS + 0.5)
	end
	place(a, c2 + Vector3.new(0, 150, 30), c2 + Vector3.new(0, 150, -30))
	a:SetAttribute("ShieldUntil", nil)
	if bot.popped then
		Combat:Respawn(bot, true)
	end
	bot.model:PivotTo(CFrame.new(c2 + Vector3.new(0, 150, -30)))
	Combat:RobotFire(bot, a, true)
	check("a robot can pop you", a:GetAttribute("Popped") == true)
	local popped = Engine.lastClientEvent("Popped", a)
	check("the pop screen names the robot", popped and popped.args[1].robot ~= nil)
	Robots.paused = false
	-- the round ends: robots go, never on the podium
	Round.endsAt = Engine.workspace:GetServerTimeNow()
	Engine.advance(0.5)
	check(
		"robots leave after the round",
		#Robots.robots == 0 and #Engine.workspace.Robots:GetChildren() == #Range.targets
	)
	local pod = Engine.lastClientEvent("Podium").args[1]
	local robotOnPodium = false
	for _, r in pod do
		robotOnPodium = robotOnPodium or r.name:find("BOT", 1, true) ~= nil or r.name == "BEEP"
	end
	check("robots never stand on the podium", not robotOnPodium)
	Robots.Wanted = function()
		return 0
	end
	Engine.advance(Constants.PODIUM_SECONDS + 0.5)
	-- the map vote
	check("the vote opens in the lobby", Round.state == "lobby" and Vote.open and #Vote.options == 3)
	local view = Engine.lastClientEvent("Profile", a)
	check("the vote card gets the maps", view and view.args[1].vote and #view.args[1].vote.options == 3)
	local pick = Vote.options[2]
	Engine.fireServer(a, "Vote", pick)
	Engine.fireServer(b4, "Vote", pick)
	Engine.advance(0.5)
	check("tapping a map votes", Vote.votes[a] == pick)
	check("votes counted", Vote:Counts()[pick] == 2)
	Engine.advance(Constants.LOBBY_SECONDS + 1)
	check("the most votes wins", Round.map and Round.map.key == pick, Round.map and Round.map.key)
	check("the vote closes", not Vote.open)
	Round.endsAt = Engine.workspace:GetServerTimeNow()
	Engine.advance(0.5)
	Engine.removePlayer(b4)
	Engine.advance(Constants.PODIUM_SECONDS + 0.5)
end

-- The range
do
	place(a, layout.range.spawn + Vector3.new(0, 3, 0))
	Engine.advance(0.5)
	check("walking onto the range: first person zone", a:GetAttribute("Zone") == "range")
	local t = Range.targets[1]
	local from = headOf(a)
	local v = Combat:Fire(a, from, (t.root.Position - from).Unit)
	check("pop a range target", v == t and t.popped)
	Engine.advance(2.3)
	check("targets pop back up fast", not t.popped)
	local friend = join("Fin", 1020)
	place(friend, layout.range.spawn + Vector3.new(4, 3, 10))
	Engine.advance(0.5)
	Engine.advance(1.3)
	from = headOf(a)
	v = Combat:Fire(a, from, (root(friend).Position - from).Unit)
	check("players on the range can't pop each other", v ~= friend and friend:GetAttribute("Popped") == nil)
	place(a, layout.spawn.Position + Vector3.new(0, 3, 0))
	place(friend, layout.spawn.Position + Vector3.new(3, 3, 0))
	Engine.advance(0.5)
	check("leaving the range: lobby", a:GetAttribute("Zone") == "lobby")
	-- a duel: both stand on the pad
	local pad = layout.duelPad.center
	local wins = pa.stats.duelWins
	place(a, pad + Vector3.new(1, 3, 0))
	place(friend, pad + Vector3.new(-1, 3, 0))
	Engine.advance(2)
	check(
		"two on the DUEL pad: a duel",
		Duel.duel ~= nil and a:GetAttribute("Zone") == "duel" and friend:GetAttribute("Zone") == "duel"
	)
	check("in the duel arena", (root(a).Position - World.DUEL_CENTER).Magnitude < 60)
	Engine.advance(Constants.SHIELD_SECONDS + 0.2)
	local dc = World.DUEL_CENTER
	for i = 1, Constants.DUEL_TO do
		place(a, dc + Vector3.new(0, 40, 20), dc + Vector3.new(0, 40, -20))
		place(friend, dc + Vector3.new(0, 40, -20), dc + Vector3.new(0, 40, 20))
		friend:SetAttribute("ShieldUntil", nil)
		Engine.advance(Loadout:Rifle(a).bolt + 0.05)
		shoot(a, root(friend).Position)
		if i < Constants.DUEL_TO then
			Engine.advance(Constants.RESPAWN_SECONDS + 0.1)
		end
	end
	Engine.advance(0.2)
	check("first to 5 wins the duel", Duel.duel == nil and pa.stats.duelWins == wins + 1)
	check("both back in the lobby", a:GetAttribute("Zone") == "lobby" and friend:GetAttribute("Zone") == "lobby")
	-- the game log
	GameLog.flush()
	check("the log saw joins", logged("joined") ~= nil)
	check("the log saw the round", logged("Round over") ~= nil)
	check("the log saw a trade", logged("skin for 10000 coins") ~= nil)
	check("the log saw the prize", logged("TOP SNIPER prize") ~= nil)
	local stats = GameLog:SessionStats(a, pa)
	check("session stats", stats and stats[1].name == "Time played" and #stats >= 10)
	Engine.removePlayer(friend)
	Engine.advance(0.3)
	GameLog.flush()
	check("the log saw a leave with stats", logged("@Fin left") ~= nil and #logged("@Fin left").fields >= 10)
end

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

-- Alone: after the solo wait the countdown starts anyway and robots fill the round
do
	Constants.SOLO_WAIT = SOLO_WAIT
	Robots.Wanted = robotWanted
	Round:_wait()
	Engine.advance(1)
	check("alone: waiting for friends", Round.state == "waiting")
	Engine.advance(SOLO_WAIT + 0.5)
	check("alone: the countdown starts anyway", Round.state == "lobby")
	Engine.advance(Constants.LOBBY_SECONDS + 1)
	check("a solo round", Round.state == "round" and a:GetAttribute("Zone") == "arena")
	check("robots join a solo round", #Robots.robots == 3, #Robots.robots)
	Round.endsAt = Engine.workspace:GetServerTimeNow()
	Engine.advance(0.5)
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

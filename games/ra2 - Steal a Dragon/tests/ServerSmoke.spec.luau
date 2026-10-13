--[[
Server smoke test: boots the real server scripts on the mock engine and plays the whole game with three
players: the tutorial, buying, stealing, bonking, grabbing, locking, selling, nests, speed, passes and
products, the daily gift, the egg, goals, friends and invites, leaderboards, offline coins and leaving
mid-steal. Fails on any script error or broken expectation.

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
local Base = service("BaseService")
local Dragon = service("DragonService")
local Road = service("RoadService")
local Combat = service("CombatService")
local Reward = service("RewardService")
local Shop = service("ShopService")
local Team = service("TeamService")
local Tutorial = service("TutorialService")
local Leaderboard = service("LeaderboardService")
local Tools = service("ToolService")
local Npc = service("NpcService")
Npc.active = false -- raiders are tested on their own near the end
-- game log posts are captured here instead of going to Discord
local GameLog = service("GameLogService")
local gameLogs = {} -- every event sent, flattened
local chatLogs = {}
GameLog.send = function(payload)
	for _, e in payload.events do
		table.insert(gameLogs, e)
	end
	for _, c in payload.chat do
		table.insert(chatLogs, c)
	end
	return true
end
-- analytics batches are captured here instead of going to Supabase
local Analytics = service("AnalyticsService")
local aEvents, aSessions = {}, {} -- every event; session rows merged by id
Analytics.send = function(payload)
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
local ShopData = Engine.require(tree.shared.Data.Shop)
-- every real item has its own Roblox ID (set by tools/setup_shop.py)
do
	local ids, ok, count = {}, true, 0
	for _, list in { ShopData.Passes, ShopData.Products } do
		for _, item in list do
			if item.id == 0 or ids[item.id] then
				ok = false
			end
			ids[item.id] = true
			count += 1
		end
	end
	check("every shop item (" .. count .. ") has a unique Roblox ID", ok and count >= 21)
end
-- the rest of this test plays as Studio does with unset IDs: purchases are granted for free
for _, list in { ShopData.Passes, ShopData.Products } do
	for _, item in list do
		item.id = 0
	end
end
table.clear(ShopData.passById)
table.clear(ShopData.productById)
local Formulas = Engine.require(tree.shared.Formulas)
local Format = Engine.require(tree.shared.Format)
local Constants = Engine.require(tree.shared.Constants)
local World = Engine.require(tree.server.World.WorldBuilder).layout
local Players = Engine.Players
local MarketplaceService = Engine.game:GetService("MarketplaceService")

local function join(name, id, launch)
	local p = Engine.addPlayer(name, id, launch)
	Engine.makeCharacter(p)
	Engine.advance(0.2)
	Engine.fireServer(p, "Ready")
	Engine.advance(0.3)
	return p
end
local function go(p, pos)
	Engine.moveTo(p, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.25)
end
local function prompt(model, kind)
	local root = model.PrimaryPart or model
	return root:FindFirstChild("Prompt_" .. kind)
end
local function trigger(p, model, kind)
	local pr = prompt(model, kind)
	assert(pr, "no prompt " .. kind .. " on " .. model.Name)
	pr.Triggered:Fire(p)
	Engine.advance(0.1)
end
local function goHome(p)
	local base = Base:Get(p)
	go(p, base.world.cf.Position + Vector3.new(0, 0.5, 0))
	Engine.advance(0.3)
end
local function nestModel(owner, slot)
	for _, m in Engine.workspace.Dragons:GetChildren() do
		if m:GetAttribute("OwnerUserId") == owner.UserId and m:GetAttribute("Slot") == slot then
			return m
		end
	end
	return nil
end
local function anyNestModel(owner)
	for _, m in Engine.workspace.Dragons:GetChildren() do
		if m:GetAttribute("OwnerUserId") == owner.UserId and m:GetAttribute("Slot") then
			return m
		end
	end
	return nil
end
local function lastTutorial(p)
	local e = Engine.lastClientEvent("Tutorial", p)
	return e and e.args[1]
end
local function countRec(profile, id)
	local n = 0
	for _, r in profile.dragons do
		if r.id == id then
			n += 1
		end
	end
	return n
end

-- World ----------------------------------------------------------------------------------------------------
check("8 bases built", #World.bases == 8)
check("3 lobby leaderboards", World.boards.coins and World.boards.steals and World.boards.income)
check("spawn in the lobby", World.spawn.Position.X < -120)
check("no Baseplate template left", Engine.workspace:FindFirstChild("Baseplate") == nil)
check("base plates: auto collect and lock time", World.bases[1].autoPlate ~= nil and World.bases[1].lockPlate ~= nil)
check("24 nests per base", #World.bases[1].nests == Constants.MAX_NESTS)

-- The secret disco at the end of the tunnel: there, and hidden from outside
local disco = Engine.workspace.Map:FindFirstChild("Disco", true)
check("secret disco built", disco ~= nil)
local discoTiles, discoBall, discoLasers, discoDancers = 0, nil, 0, 0
for _, d in disco:GetDescendants() do
	if d.Name == "DanceTile" then
		discoTiles += 1
	elseif d.Name == "DiscoBall" then
		discoBall = d
	elseif d.Name == "Laser" then
		discoLasers += 1
	elseif d:GetAttribute("DiscoDancer") then
		discoDancers += 1
	end
end
check(
	"disco: dance floor, mirror ball, lasers, dancers",
	discoTiles == 36 and discoBall and discoLasers == 8 and discoDancers == 3
)
-- does any solid, visible part block the straight line from a to b?
local solids = {}
for _, p in Engine.workspace.Map:GetDescendants() do
	-- (the mirror ball is a target below, so it can't block itself; round rocks are left out, since a box would
	-- block more than they do)
	if
		p:IsA("BasePart")
		and p ~= discoBall
		and p.Shape ~= Engine.Enum.PartType.Ball
		and p.Transparency < 0.5
		and p.Size.X > 0.5
		and p.Size.Y > 0.5
		and p.Size.Z > 0.5
	then
		table.insert(solids, p)
	end
end
local function blocked(a, b)
	for _, p in solids do
		local la, lb = p.CFrame:PointToObjectSpace(a), p.CFrame:PointToObjectSpace(b)
		local half = p.Size / 2
		local t0, t1 = 0, 1
		local hit = true
		for _, axis in { "X", "Y", "Z" } do
			local d = lb[axis] - la[axis]
			if math.abs(d) < 1e-9 then
				if math.abs(la[axis]) > half[axis] then
					hit = false
					break
				end
			else
				local u, v = (-half[axis] - la[axis]) / d, (half[axis] - la[axis]) / d
				t0, t1 = math.max(t0, math.min(u, v)), math.min(t1, math.max(u, v))
				if t0 > t1 then
					hit = false
					break
				end
			end
		end
		if hit and t1 > 0.001 and t0 < 0.999 then
			return p
		end
	end
	return nil
end
local seen
local targets = { discoBall.Position }
for _, d in disco:GetDescendants() do
	if d.Name == "DanceTile" then
		table.insert(targets, d.Position + Vector3.new(0, 0.3, 0))
	end
end
for _, ex in { 95, 105, 113, 120 } do
	for _, ez in { -6, 0, 6 } do
		for _, ey in { 2, 5, 9 } do
			for _, target in targets do
				if not seen and not blocked(Vector3.new(ex, ey, ez), target) then
					seen = Vector3.new(ex, ey, ez)
				end
			end
		end
	end
end
for _, eye in { Vector3.new(165, 80, 20), Vector3.new(120, 40, 60), Vector3.new(220, 30, 20) } do
	if not seen and not blocked(eye, discoBall.Position) then
		seen = eye
	end
end
check("the disco can't be seen from the tunnel mouth or outside", seen == nil, seen)
check("door from the tunnel into the disco corridor", blocked(Vector3.new(139, 3, 0), Vector3.new(139, 3, 15)) == nil)
local ctl = blocked(Vector3.new(158, 4, 12), discoBall.Position)
check("(control) the ball is visible from the dance floor", ctl == nil, ctl and ctl:GetFullName())
check("corridor leads into the room", blocked(Vector3.new(139, 3, 19.5), Vector3.new(158, 3, 19.5)) == nil)

-- Join and tutorial ----------------------------------------------------------------------------------------
local a = join("Ava", 1001)
local pa = Data:Get(a)
check("profile loaded", pa ~= nil)
check("unsaved only without DataStore", (pa._noSave == true) == noDataStore)
check("base assigned", Base:Get(a) ~= nil and Base:Get(a).owner == a)
check(
	"LEVEL ALL prompt belongs to the owner (others never see it over Steal)",
	Base:Get(a).world.levelPlate.Prompt_levelall:GetAttribute("OwnerUserId") == a.UserId
)
-- first minutes: new players earn double, and the HUD knows the next playtime gift
check("new players get the 2x boost", pa.newBoostLeft == Constants.NEW_PLAYER_BOOST_SECONDS)
check("the boost doubles income", select(2, Base:Income(a)) == Constants.NEW_PLAYER_BOOST_MULT)
local Playtime = service("PlaytimeService")
check("the HUD shows the next playtime gift", Playtime:View(a).nextIn ~= nil and Playtime:View(a).nextText ~= nil)
-- (both off for the rest of the test, so they don't change its numbers; playtime gifts are tested later)
pa.newBoostLeft = 0
pa.playtime.given = #Formulas.PLAYTIME_GIFTS
-- road dragons walk into the exit tunnel: unbuyable once inside, removed deep in the dark
local leaving = Road:Spawn()
leaving.x = Constants.ROAD_END_X + 1
Engine.advance(0.1)
check("dragon in the tunnel can't be bought", leaving.model.PrimaryPart:FindFirstChild("Prompt_buy") == nil)
check("dragon keeps walking into the tunnel", Road:Entry(leaving.roadId) ~= nil)
leaving.x = Constants.ROAD_EXIT_X + 1
Engine.advance(0.1)
check("dragon gone deep in the tunnel", Road:Entry(leaving.roadId) == nil)
check("leaderstats", a:FindFirstChild("leaderstats") and a.leaderstats:FindFirstChild("Coins") ~= nil)
check("base sign shows owner", Base:Get(a).world.signLines[1].Text:find("AVA", 1, true) == 1)
Leaderboard:Refresh()
check(
	"boards show players even in a brand-new game",
	World.boards.coins.rows[1].name.Text == "Ava",
	World.boards.coins.rows[1].name.Text
)
Engine.advance(0.5)
local t = lastTutorial(a)
check(
	"tutorial goal 1: the free dragon",
	t and t.step == 1 and t.target == Road.freeModel and t.total == 4,
	t and t.step
)
check("new players start with 100 coins", pa.coins == Constants.START_COINS)

trigger(a, Road.freeModel, "free")
check("carrying the free Puff", Dragon:Carrying(a) and Dragon:Carrying(a).rec.id == "PUFF")
check("carry slows you down", a.Character.Humanoid.WalkSpeed < 18)
check("carried model on the character", a.Character:FindFirstChild("CarriedDragon") ~= nil)
trigger(a, Road.freeModel, "free") -- second grab refused
check("free dragon only once", #pa.dragons == 1)
Engine.advance(0.5)
check("tutorial goal 2: your base", lastTutorial(a).step == 2)
goHome(a)
check("placed in nest 1", pa.dragons[1].slot == 1 and Dragon:Carrying(a) == nil)
check("nest model built", nestModel(a, 1) ~= nil)
check("walk speed back to normal", a.Character.Humanoid.WalkSpeed == 18)
Engine.advance(0.5)
check("tutorial goal 3: collect", lastTutorial(a).step == 3)
check("the coin pad glows for goal 3", Base:Get(a).world.collectPad:FindFirstChild("TutorialGlow") ~= nil)
Engine.advance(5)
check("bank fills", Base:Get(a).bank >= 4, Base:Get(a).bank)
go(a, Base:Get(a).world.collectPad.Position)
check("coins collected", pa.coins >= Constants.START_COINS + 4 and Base:Get(a).bank < 1, pa.coins)
local coinSound = Engine.lastClientEvent("Sfx", a)
check("collecting plays the coin sound", coinSound and coinSound.args[1] == "coin")
Engine.advance(0.5)
check("tutorial goal 4: buy a dragon", lastTutorial(a).step == 4)
check("the glow moves on", Base:Get(a).world.collectPad:FindFirstChild("TutorialGlow") == nil)
go(a, Base:Get(a).world.lockPad.Position)
check("base locked", Base:IsLocked(Base:Get(a)))
check("laser visible", Base:Get(a).world.laser.Transparency < 1)
Engine.advance(10)
local lockLeft = Base:Get(a).lockUntil
go(a, Base:Get(a).world.collectPad.Position)
go(a, Base:Get(a).world.lockPad.Position)
check(
	"stepping on the lock pad again resets the timer",
	Base:Get(a).lockUntil >= lockLeft + 9,
	Base:Get(a).lockUntil - lockLeft
)
go(a, Road.practiceModel.PrimaryPart.Position)
trigger(a, Road.practiceModel, "practice")
check("carrying practice Frosty", Dragon:Carrying(a) and Dragon:Carrying(a).rec.id == "FROSTY")
goHome(a)
check("Frosty in a nest", countRec(pa, "FROSTY") == 1 and Dragon:Carrying(a) == nil)
check("practice steal is not a real steal", pa.steals == 0)

-- Buy from the road
Engine.advance(8) -- earn enough and let dragons walk out
go(a, Base:Get(a).world.collectPad.Position)
local cheapest
for _, m in Engine.workspace.Dragons.Road:GetChildren() do
	local e = m:GetAttribute("RoadId") and Road:Entry(m:GetAttribute("RoadId"))
	if e and e.price <= pa.coins and (not cheapest or e.price < cheapest.price) then
		cheapest = e
	end
end
if not cheapest then -- make sure there is something affordable
	pa.coins += 100
	cheapest = Road:Spawn()
	pa.coins = math.max(pa.coins, cheapest.price)
end
local coinsBefore = pa.coins
go(a, cheapest.model.PrimaryPart.Position)
trigger(a, cheapest.model, "buy")
check("bought a road dragon", Dragon:Carrying(a) ~= nil and Dragon:Carrying(a).kind == "bought")
check("coins spent", pa.coins == coinsBefore - cheapest.price)
check("road dragon removed", Road:Entry(cheapest.roadId) == nil)
check("bought counter", pa.stats.bought == 1)
goHome(a)
check("three dragons in nests", #pa.dragons == 3)
Engine.advance(1)
check("tutorial finished", pa.tutorialDone == true and lastTutorial(a) == false)
check("overnight egg given", pa.egg ~= nil and pa.egg.readyAt > Engine.globals.os.time() + 3600)
check("egg model on the stand", Base:Get(a).world.model:FindFirstChild("Egg") ~= nil)

-- Goals ----------------------------------------------------------------------------------------------------
pa.coins = math.max(pa.coins, 120)
Engine.advance(1.2)
check("goal 1 done (lock your door)", pa.goal >= 2, pa.goal)

-- Second player, locks and stealing ------------------------------------------------------------------------
local b = join("Ben", 1002)
check("bases go zigzag: left, then right", Base:Get(a).index == 1 and Base:Get(b).index == 5, Base:Get(b).index)
local heardJoin = false
for _, e in Engine.clientLog do
	if e.name == "Announce" and e.player == a and tostring(e.args[1]):find("Ben joined", 1, true) then
		heardJoin = true
	end
end
check("everyone hears when someone joins", heardJoin)
do -- players still doing the tutorial can't be bonked
	local pb = Data:Get(b)
	local saved = pb.tutorialDone
	pb.tutorialDone = false
	local bp = Base:Position(b)
	check("no bonking players in the tutorial", bp == nil or Combat:_target(a, bp, 6) ~= b)
	pb.tutorialDone = true
	check("bonkable once the tutorial is done", bp == nil or Combat:_target(a, bp, 6) == b)
	pb.tutorialDone = saved
end
do -- no stunlock: a bonked player can't be hit again while stunned, nor for a few seconds after
	local pa0, pb0 = Data:Get(a).tutorialDone, Data:Get(b).tutorialDone
	Data:Get(a).tutorialDone, Data:Get(b).tutorialDone = true, true
	local spot = Vector3.new(-150, 3, 30)
	go(a, spot)
	go(b, spot + Vector3.new(3, 0, 0))
	Engine.advance(Constants.BONK_COOLDOWN + 0.1)
	Combat:Bonk(a)
	Engine.advance(0.05)
	check("a bonk stuns", Combat:IsStunned(b))
	check(
		"can't swing again right away",
		(function()
			local before = Combat:IsSafe(b)
			return before and Combat:_target(a, Base:Position(b), 9) ~= b
		end)()
	)
	local stun = Combat:Weapon(a).stun
	Engine.advance(stun + 0.3)
	check("safe for a few seconds after the stun", not Combat:IsStunned(b) and Combat:IsSafe(b))
	check("a bubble shows they're safe", b.Character:FindFirstChild("BonkSafe") ~= nil)
	Engine.advance(Constants.BONK_IMMUNE_SECONDS + 0.2)
	check("bonkable again after the safe time", not Combat:IsSafe(b) and Combat:_target(a, Base:Position(b), 9) == b)
	Data:Get(a).tutorialDone, Data:Get(b).tutorialDone = pa0, pb0
end
local pb = Data:Get(b)
Engine.fireServer(b, "SkipTutorial")
Engine.advance(0.5)
check("skip tutorial", pb.tutorialDone and pb.egg ~= nil)
check("Ben has another base", Base:Get(b) ~= nil and Base:Get(b) ~= Base:Get(a))
Base:Lock(a)
go(b, Base:Get(a).world.cf.Position)
Engine.advance(0.3)
check("locked base bounces thieves", not Base:IsInside(Base:Get(a), b.Character.HumanoidRootPart.Position))
local m1 = nestModel(a, 1)
go(b, Base:Get(a).world.gateCf.Position)
trigger(b, m1, "steal")
check("cannot steal from a locked base", Dragon:Carrying(b) == nil)
Engine.advance(130) -- the lock runs out
check("lock expired", not Base:IsLocked(Base:Get(a)))
go(b, m1.PrimaryPart.Position)
trigger(b, m1, "steal")
check("Ben is stealing", Dragon:Carrying(b) and Dragon:Carrying(b).kind == "stolen")
check("victim alerted", Engine.lastClientEvent("Alert", a) ~= nil)
check("nest emptied", nestModel(a, 1) == nil)
local outside = (Base:Get(a).world.cf * CFrame.new(0, 0, -36)).Position
go(b, outside)
check("thief outside the base still carrying", Dragon:Carrying(b) ~= nil)

check("thieves wear a THIEF tag", b.Character.Head:FindFirstChild("ThiefTag") ~= nil)
check("thieves glow red", b.Character:FindFirstChild("ThiefGlow") ~= nil)
local bounty = Combat:Bounty(b)
check("thieves carry a bounty", bounty >= Constants.BOUNTY_MIN, bounty)

-- Ava bonks Ben, grabs her dragon back
go(a, b.Character.HumanoidRootPart.Position + Vector3.new(3, 0, 0))
local coinsBeforeBonk = pa.coins
Engine.fireServer(a, "Bonk")
Engine.advance(0.1)
check("bonking a thief pays the bounty", pa.coins >= coinsBeforeBonk + bounty, pa.coins - coinsBeforeBonk)
check("everyone hears about the bounty", Engine.lastClientEvent("Announce", b) ~= nil)
check("the THIEF tag comes off", b.Character.Head:FindFirstChild("ThiefTag") == nil)
check("bonked players flash", b.Character:FindFirstChild("HitFlash") ~= nil)
check("bonked players see stars", b.Character.Head:FindFirstChild("Dizzy") ~= nil)
check("Ben stunned", b.Character.Humanoid.WalkSpeed == 0)
check("Ben dropped it", Dragon:Carrying(b) == nil)
check("bonk counted", pa.stats.bonks == 1)
local dropped = Engine.workspace.Dragons:FindFirstChild("DroppedDragon")
check("dragon on the ground", dropped ~= nil)
trigger(a, dropped, "grab")
check("Ava grabbed it back", Dragon:Carrying(a) and Dragon:Carrying(a).kind == "own")
Engine.advance(2)
check("stun wears off", b.Character.Humanoid.WalkSpeed > 0)
goHome(a)
check("back in Ava's nest", #pa.dragons == 3 and Dragon:Carrying(a) == nil and pa.steals == 0)

-- Ben steals for real
local target = anyNestModel(a)
local stolenId = target:GetAttribute("DragonId")
go(b, target.PrimaryPart.Position)
trigger(b, target, "steal")
goHome(b)
check(
	"steal complete",
	pb.steals == 1 and #pa.dragons == 2 and #pb.dragons == 1,
	`{pb.steals} {#pa.dragons} {#pb.dragons}`
)
check("stolen dragon now Ben's", pb.dragons[1].id == stolenId and pb.dragons[1].slot ~= nil)
check("leaderstats steals", b.leaderstats.Steals.Value == 1)

-- A dropped dragon nobody grabs flies home
local t2 = anyNestModel(a)
go(b, t2.PrimaryPart.Position)
trigger(b, t2, "steal")
go(b, outside)
go(a, b.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
Engine.advance(1.1)
Engine.fireServer(a, "Bonk")
Engine.advance(9)
check(
	"unclaimed drop returns to its owner",
	#pa.dragons == 2 and Engine.workspace.Dragons:FindFirstChild("DroppedDragon") == nil
)
check(
	"returned into a nest",
	(function()
		for _, r in pa.dragons do
			if not r.slot then
				return false
			end
		end
		return true
	end)()
)

-- Selling, nests, speed --------------------------------------------------------------------------------------
local coins0 = pb.coins
local bm = anyNestModel(b)
go(b, bm.PrimaryPart.Position)
trigger(b, bm, "sell")
check("sold for coins", pb.coins > coins0 and #pb.dragons == 0)
pa.coins += 1000
local nest5 = Base:Get(a).world.nests[5].pad
check("next nest has a buy prompt", nest5:FindFirstChild("Prompt_nest") ~= nil)
local nest9 = Base:Get(a).world.nests[9].pad
check("any locked nest has a buy prompt", nest9:FindFirstChild("Prompt_nest") ~= nil)
nest9.Prompt_nest.Triggered:Fire(a)
Engine.advance(0.1)
check("buying from a far nest opens the next one", pa.nestsBought == 5 and Dragon:MaxNests(a) == 5)
Engine.fireServer(a, "BuySpeed")
Engine.advance(0.1)
check("speed level 2", pa.speedLevel == 2 and a.Character.Humanoid.WalkSpeed == 19.5, a.Character.Humanoid.WalkSpeed)

-- Shop -----------------------------------------------------------------------------------------------------
local income1 = Base:Income(a)
Engine.fireServer(a, "Purchase", "pass", "DOUBLE")
Engine.advance(0.1)
check("Studio grants 2x Coins", pa.passes.DOUBLE == true)
check("2x income", math.abs(Base:Income(a) - income1 * 2) < 1e-6)
Engine.fireServer(a, "Purchase", "product", "LUCK")
Engine.advance(0.1)
check("Server Luck on", Road:IsLucky())
-- a real product id goes through ProcessReceipt, once per purchase id
local bag = ShopData.productByKey.COINS_S
bag.id = 777
ShopData.productById[777] = bag
Engine.advance(1) -- Purchase is rate-limited to 2 per second
Engine.fireServer(a, "Purchase", "product", "COINS_S")
Engine.advance(0.1)
check("real id opens Roblox's prompt", Engine.prompted[#Engine.prompted].id == 777)
local before = pa.coins
local decision = MarketplaceService.ProcessReceipt({ PlayerId = a.UserId, ProductId = 777, PurchaseId = "R1" })
check("receipt granted", decision.Name == "PurchaseGranted" and pa.coins >= before + 1000)
local after = pa.coins
MarketplaceService.ProcessReceipt({ PlayerId = a.UserId, ProductId = 777, PurchaseId = "R1" })
check("same receipt never pays twice", pa.coins == after)
check(
	"unknown player waits",
	MarketplaceService.ProcessReceipt({ PlayerId = 5, ProductId = 777, PurchaseId = "R2" }).Name == "NotProcessedYet"
)
-- Robux offers from the world (not the Shop): never during the tutorial or a new player's first minutes, and the
-- same offer at most once a minute
local savedNew, savedTut = pa._isNew, pa.tutorialDone
pa._isNew, pa.tutorialDone = true, false
Shop:ResetOffers(a)
check("no world offers during the tutorial", not Shop:Offer(a, "product", "HATCH"))
pa.tutorialDone = true
check("no world offers in a new player's first minutes", not Shop:Offer(a, "product", "HATCH"))
pa._isNew = false
check("world offers once they've settled in", Shop:OffersAllowed(a))
Shop:ResetOffers(a)
Shop.Offer(Shop, a, "product", "LOCKNOW")
check("the same offer at most once a minute", not Shop:Offer(a, "product", "LOCKNOW"))
Shop:ResetOffers(a)
pa._isNew, pa.tutorialDone = false, true -- (the rest of these tests buy from the world)
-- Levels: +10 Levels (Robux) and Level Up (coins) on a nest dragon
local gm = anyNestModel(a)
local guid = gm:GetAttribute("Uid")
local grown
for _, r in pa.dragons do
	if r.uid == guid then
		grown = r
	end
end
local lv0 = Formulas.level(grown, Engine.globals.os.time())
Dragon.GrowRequested:Fire(a, guid) -- (offered when Level Up costs more than you have)
Engine.advance(0.1)
check("+10 Levels adds 10 levels", Formulas.level(grown, Engine.globals.os.time()) == lv0 + 10)
local function modelOf(uid)
	for _, m in Engine.workspace.Dragons:GetChildren() do
		if m:GetAttribute("Uid") == uid then
			return m
		end
	end
end
gm = modelOf(guid) -- reaching Kid size rebuilds the model
check(
	"tag shows the level big on top",
	gm.PrimaryPart.Tag.Line1.Text == "LV " .. (lv0 + 10),
	gm.PrimaryPart.Tag.Line1.Text
)
check(
	"owners get just Level Up and Sell",
	gm.PrimaryPart:FindFirstChild("Prompt_combine") == nil and gm.PrimaryPart:FindFirstChild("Prompt_grow") == nil
)
local cost = Formulas.levelUpCost(grown, Engine.globals.os.time())
pa.coins += cost
local coinsBefore = pa.coins
go(a, gm.PrimaryPart.Position)
trigger(a, gm, "levelup")
check("Level Up costs coins", pa.coins == coinsBefore - cost, pa.coins - coinsBefore)
check("Level Up adds a level", Formulas.level(grown, Engine.globals.os.time()) == lv0 + 11)
check(
	"Level Up prompt shows the next price",
	gm.PrimaryPart.Prompt_levelup.ActionText:find(
		Format.num(Formulas.levelUpCost(grown, Engine.globals.os.time())),
		1,
		true
	) ~= nil
)
local poor = pa.coins
pa.coins = 0
Shop:ResetOffers(a)
trigger(a, gm, "levelup")
Engine.advance(0.1)
check(
	"no coins: Level Up offers +10 Levels (Robux; free in Studio)",
	pa.coins == 0 and Formulas.level(grown, Engine.globals.os.time()) == lv0 + 21,
	Formulas.level(grown, Engine.globals.os.time()) - lv0
)
pa.coins = poor

-- Buy plates in the base
local world = Base:Get(a).world
check("plates built", world.autoPlate ~= nil and world.lockPlate ~= nil)
Shop:RefreshPlates(a)
go(a, world.autoPlate.Position)
check("stepping on a plate never opens a purchase", pa.passes.AUTO ~= true)
check("plate buttons show once the tutorial is done", world.autoPlate.Prompt_auto.Enabled == true)
world.autoPlate.Prompt_auto.Triggered:Fire(a)
Engine.advance(0.1)
check("holding the Auto Collect button sells the pass", pa.passes.AUTO == true)
local lockBefore = Base:Get(a).lockUntil
world.lockPlate.Prompt_lock5.Triggered:Fire(a)
Engine.advance(0.1)
check(
	"lock plate adds 5 minutes",
	Base:Get(a).lockUntil
		>= math.max(lockBefore, Engine.workspace:GetServerTimeNow()) + Constants.LOCK_BOOST_SECONDS - 1
)
local lockAfter = Base:Get(a).lockUntil
Engine.advance(0.5)
check("standing on the plate doesn't buy again", Base:Get(a).lockUntil == lockAfter)
Base:Get(a).lockUntil = 0 -- open again for the stealing tests below
goHome(a)

-- LEVEL ALL plate: spends coins on the cheapest level-ups across every nest
local function totalLevels()
	local sum, now = 0, Engine.globals.os.time()
	for _, r in pa.dragons do
		if r.slot then
			sum += Formulas.level(r, now)
		end
	end
	return sum
end
check("LEVEL ALL podium built", world.levelPlate ~= nil and world.levelPlate:FindFirstChild("Prompt_levelall") ~= nil)
local levelsBefore = totalLevels()
pa.coins += 1e7
local coinsBeforeAll = pa.coins
go(a, world.levelPlate.Position)
-- (dragons also level up with time, so this checks coins: walking onto it spends nothing)
check("LEVEL ALL isn't set off by walking onto it", pa.coins >= coinsBeforeAll)
levelsBefore = totalLevels()
world.levelPlate.Prompt_levelall.Triggered:Fire(a)
check("LEVEL ALL buys levels", totalLevels() > levelsBefore + 1, totalLevels() - levelsBefore)
check("LEVEL ALL spends coins", pa.coins < coinsBeforeAll)
goHome(a)
pa.coins = 0
levelsBefore = totalLevels()
world.levelPlate.Prompt_levelall.Triggered:Fire(a) -- no coins: just says so, never asks for Robux
local noCoinsNote = Engine.lastClientEvent("Toast", a)
check(
	"LEVEL ALL with no coins doesn't charge Robux",
	totalLevels() == levelsBefore
		and noCoinsNote
		and tostring(noCoinsNote.args[1]):find("Not enough coins", 1, true) ~= nil
)
goHome(a)
pa.coins = coinsBeforeAll

-- Castle levels grow with dragon power
local myBase = Base:Get(a)
check(
	"castle level thresholds",
	Base.castleLevelFor(0) == 1 and Base.castleLevelFor(30) == 2 and Base.castleLevelFor(1e9) == 8
)
local trim = world.levels[5]:FindFirstChild("GoldTrim", true)
local realPower = Base.DragonPower
Base.DragonPower = function()
	return 1e9
end
Base:UpdateCastle(myBase)
check("castle grows to the top level", world.castleLevel == 8 and trim ~= nil and trim.Transparency < 1)
check("sign shows the castle level", world.signLines[1].Text:find("🏰8", 1, true) ~= nil)
Base.DragonPower = function()
	return 0
end
Base:UpdateCastle(myBase)
check("castle shrinks back", world.castleLevel == 1 and trim.Transparency == 1 and trim.CanCollide == false)
Base.DragonPower = realPower
Base:UpdateCastle(myBase)

-- Hotbar tools ------------------------------------------------------------------------------------------------
local function toolOf(p, kind)
	return Tools:Find(p, kind)
end
local hand = a.Character:FindFirstChildOfClass("Tool")
check("the bat is in your hand", hand ~= nil and hand:GetAttribute("Kind") == "bonk")
check("hotbar has a Speed Potion", toolOf(a, "potion") ~= nil and toolOf(a, "potion").Parent == a.Backpack)
check("starts with free potions", pa.potions == Constants.FREE_POTIONS)
check("potion count on the tool", toolOf(a, "potion").Name == "Speed Potion x" .. Constants.FREE_POTIONS)
check("camera zoom is capped", a.CameraMaxZoomDistance == Constants.CAMERA_MAX_ZOOM)
Engine.advance(Constants.BONK_COOLDOWN + 0.1)
hand.Activated:Fire()
Engine.advance(0.05)
check("clicking with the bat swings it", hand:FindFirstChild("toolanim") ~= nil)
Engine.advance(Constants.BONK_COOLDOWN + 0.1)
-- Q bonks too, and puts the bat back in your hand
local hum = a.Character.Humanoid
hum:EquipTool(toolOf(a, "potion"))
Engine.fireServer(a, "Bonk")
Engine.advance(0.05)
check("Q switches back to the bat", toolOf(a, "bonk").Parent == a.Character)
-- Speed Potion
local walk = hum.WalkSpeed
toolOf(a, "potion").Activated:Fire()
Engine.advance(0.05)
check("potion makes you faster", math.abs(hum.WalkSpeed - walk * Constants.POTION_SPEED_MULT) < 0.01, hum.WalkSpeed)
check(
	"potion used up",
	pa.potions == Constants.FREE_POTIONS - 1 and toolOf(a, "potion").Name:find("x" .. pa.potions, 1, true) ~= nil
)
check("speed sparkles", a.Character.HumanoidRootPart:FindFirstChild("SpeedFx") ~= nil)
Engine.advance(Constants.POTION_SECONDS + 0.5)
check("potion wears off", math.abs(hum.WalkSpeed - walk) < 0.01, hum.WalkSpeed)
pa.potions = 0
Shop:ResetOffers(a)
toolOf(a, "potion").Activated:Fire() -- out of potions: offers the pack (free in Studio)
Engine.advance(0.1)
check("out of potions offers 5 more", pa.potions == Constants.POTION_PACK, pa.potions)
-- passes change the hotbar
check("no wings without the pass", toolOf(a, "wings") == nil)
Engine.fireServer(a, "Purchase", "pass", "MEGABONK")
Engine.advance(0.1)
do
	local bonkTool = toolOf(a, "bonk")
	local handle = bonkTool and bonkTool:FindFirstChild("Handle")
	check("Mega Bonk gilds the weapon", handle ~= nil and handle:FindFirstChild("Twinkle") ~= nil)
	check("the weapon keeps its tier name", bonkTool.Name == Constants.WEAPONS[pa.weaponLevel or 1].name)
end
-- weapon upgrades: coins buy the next tier, and the hotbar gets the new weapon
do
	local nextW = Constants.WEAPONS[2]
	pa.coins = 0
	Engine.fireServer(a, "BuyWeapon")
	Engine.advance(0.1)
	check("no weapon without the coins", pa.weaponLevel == 1)
	pa.coins = nextW.price
	Engine.advance(1)
	Engine.fireServer(a, "BuyWeapon")
	Engine.advance(0.1)
	check("buying the next weapon", pa.weaponLevel == 2 and pa.coins < nextW.price, pa.weaponLevel)
	check("new weapon in the hotbar", toolOf(a, "bonk").Name == nextW.name)
	check("bigger weapon, longer reach", Combat:Weapon(a).range > Constants.WEAPONS[1].range)
end
Engine.fireServer(a, "Purchase", "pass", "WINGS")
Engine.advance(0.1)
local wingsTool = toolOf(a, "wings")
check("Dragon Wings in the hotbar", wingsTool ~= nil)
hum:EquipTool(wingsTool)
check("wings on your back", a.Character:FindFirstChild("WingsModel") ~= nil)
hum:EquipTool(toolOf(a, "bonk"))
check("wings come off when put away", a.Character:FindFirstChild("WingsModel") == nil)
check("potions kept when the hotbar is rebuilt", pa.potions == Constants.POTION_PACK)

-- Combining: fold a dragon into your best one, income kept; full nests combine by themselves, so you can always
-- steal or buy
do
	local FormulasC = Engine.require(tree.shared.Formulas)
	local function income(pp)
		local sum, now = 0, Engine.globals.os.time()
		for _, r in pp.dragons do
			if r.slot then
				sum += FormulasC.dragonIncome(r, now)
			end
		end
		return sum
	end
	local before, count = income(pa), #pa.dragons
	local weakest
	for _, r in pa.dragons do
		if
			r.slot
			and (
				not weakest
				or FormulasC.dragonIncome(r, Engine.globals.os.time())
					< FormulasC.dragonIncome(weakest, Engine.globals.os.time())
			)
		then
			weakest = r
		end
	end
	Dragon:CombineIntoBest(a, weakest.uid)
	check("combining keeps the income", math.abs(income(pa) - before) < before * 0.001, income(pa) - before)
	check("combining frees a nest", #pa.dragons == count - 1)
	local boosted = false
	for _, r in pa.dragons do
		boosted = boosted or (r.mx or 1) > 1
	end
	check("the best dragon carries the boost", boosted)
	-- fill every nest, then a new dragon still fits (the weakest combine)
	local maxN = Dragon:MaxNests(a)
	while true do
		local slots = 0
		for _, r in pa.dragons do
			if r.slot then
				slots += 1
			end
		end
		if slots >= maxN then
			break
		end
		Dragon:Grant(a, "PUFF")
	end
	check("full nests still have room (by combining)", Dragon:HasRoom(a))
	local fullIncome = income(pa)
	Dragon:Grant(a, "EMBER")
	check(
		"a new dragon into full nests combines the weakest, income kept",
		income(pa) > fullIncome and Dragon:WaitingCount(a) == 0
	)
end
-- the lock can be reset by stepping on the pad, but only so far; then it opens and recharges
do
	local myBase = Base:Get(a)
	myBase.lockUntil = 0
	Base:Lock(a)
	local first = myBase.lockUntil
	check("lock pad locks", Base:IsLocked(myBase))
	myBase.lockChainStart -= Constants.LOCK_SECONDS * Constants.LOCK_CHAIN_MAX
	Base:Lock(a)
	check("a lock can't be reset forever", myBase.lockUntil == first)
	myBase.lockUntil = Engine.workspace:GetServerTimeNow() - 1 -- it just ran out
	Base:Lock(a)
	check("then it recharges before it can lock again", not Base:IsLocked(myBase))
	myBase.lockUntil = 0
end

-- Skins
check("starts with Classic", pa.skins.CLASSIC and pa.skin == "CLASSIC")
pa.coins += 5000
local beforeSkin = pa.coins
Engine.fireServer(a, "BuySkin", "MIDNIGHT")
Engine.advance(0.1)
check(
	"coin skin bought and worn",
	pa.skins.MIDNIGHT and pa.skin == "MIDNIGHT" and pa.coins <= beforeSkin - 5000 + Base:Income(a),
	`{tostring(pa.skins.MIDNIGHT)} {pa.skin} {pa.coins - beforeSkin}`
)
check("nest dragons repainted", anyNestModel(a):GetAttribute("Skin") == "MIDNIGHT")
Engine.advance(0.6)
Engine.fireServer(a, "BuySkin", "LAVA")
Engine.advance(0.1)
check("Robux skin (Studio test) bought and worn", pa.skins.LAVA and pa.skin == "LAVA")
Engine.advance(0.6)
Engine.fireServer(a, "EquipSkin", "CLASSIC")
Engine.advance(0.1)
check("equip an owned skin", pa.skin == "CLASSIC" and anyNestModel(a):GetAttribute("Skin") == nil)
Engine.advance(0.6)
Engine.fireServer(a, "EquipSkin", "NEON")
Engine.advance(0.1)
check("can't wear a skin you don't own", pa.skin == "CLASSIC")

-- Daily gift and egg ---------------------------------------------------------------------------------------
local c0 = pa.coins
local FormulasG = Engine.require(tree.shared.Formulas)
local expectGift = math.max(500, math.floor(Base:Income(a) * 600))
check(
	"day 1 gift is sized to the player's income",
	Reward:DailyView(a).gifts[1].amount == expectGift,
	Reward:DailyView(a).gifts[1].amount
)
Engine.fireServer(a, "ClaimDaily")
Engine.advance(0.1)
local gained = pa.coins - c0
-- (auto-collect may add a second or two of income on top)
check(
	"daily day 1 pays it",
	pa.daily.streak == 1 and gained >= expectGift and gained < expectGift + Base:Income(a) * 3,
	gained
)
local c1 = pa.coins
Engine.fireServer(a, "ClaimDaily")
Engine.advance(0.1)
check("daily only once a day", pa.daily.streak == 1 and pa.coins - c1 < expectGift, pa.coins - c1)
-- the egg: better than your best dragon, with a special, and a hatch is an event for the whole server
local DragonsE = Engine.require(tree.shared.Data.Dragons)
local bestNow = FormulasG.bestSpecies(pa.dragons)
check("egg beats the best dragon", DragonsE.byId[pa.egg.id].cps * FormulasG.specialMult(pa.egg.sp) > bestNow, pa.egg.id)
check("egg has a special", pa.egg.sp ~= nil)
check("egg hatches in 2 hours", pa.egg.readyAt - Engine.globals.os.time() <= 2 * 3600)
-- getting a much better dragon upgrades the waiting egg
Dragon:Grant(a, "REX")
Engine.advance(1.1)
check("egg upgrades past a new best dragon", DragonsE.byId[pa.egg.id].cps > DragonsE.byId.REX.cps, pa.egg.id)
local eggId = pa.egg.id
local count0 = countRec(pa, eggId)
local egg = Base:Get(a).world.model:FindFirstChild("Egg")
local alertsB = 0
local remote = Engine.game:GetService("ReplicatedStorage").Net.Alert
local conn = remote.OnClientEvent:Connect(function()
	alertsB += 1
end)
Shop:ResetOffers(a)
trigger(a, egg, "hatch") -- not ready: opens Hatch Now (free in Studio)
check("egg hatched into the shown dragon", countRec(pa, eggId) == count0 + 1)
check("hatch fireworks over the stand", Base:Get(a).world.model:FindFirstChild("HatchFireworks", true) ~= nil)
check("next egg started", pa.egg ~= nil and pa.eggsGiven == 2)
conn:Disconnect()

-- Friends and invites ----------------------------------------------------------------------------------------
local friendLaunch = "invite:" .. a.UserId
Engine.friends["1001:1003"] = true
Engine.friends["1003:1001"] = true
local cPlayer = Engine.addPlayer("Cat", 1003, friendLaunch)
Engine.makeCharacter(cPlayer)
Engine.advance(0.2)
Engine.fireServer(cPlayer, "Ready")
Engine.advance(0.5)
local pc = Data:Get(cPlayer)
check("friends are a team", Team:AreTeam(a, cPlayer) and Team:FriendsHere(a) == 1)
check("friend bonus in income", Base:Income(a) > 0 and select(2, Base:Income(a)) == 2 * 1.1)
check("inviter got a Coral", countRec(pa, "CORAL") >= 1)
check("new friend got 200 coins", pc.coins >= 200)
check("play with a friend counted", pa.stats.friendPlay == 1)
local fm = anyNestModel(a)
go(cPlayer, fm.PrimaryPart.Position)
trigger(cPlayer, fm, "steal")
check("friends can't steal from each other", Dragon:Carrying(cPlayer) == nil)
Base:Lock(a)
go(cPlayer, Base:Get(a).world.cf.Position)
check("friends can enter a locked base", Base:IsInside(Base:Get(a), cPlayer.Character.HumanoidRootPart.Position))

-- Growth ------------------------------------------------------------------------------------------------------
local rec = pa.dragons[1]
rec.lv = 0 -- age alone decides the stage here
rec.born -= 4000
Engine.advance(1.2)
local model = nestModel(a, rec.slot)
check(
	"grown dragon gets a bigger model",
	model and model:GetAttribute("Stage") == 3,
	model and model:GetAttribute("Stage")
)

-- Leaderboards -------------------------------------------------------------------------------------------------
Leaderboard:Write(a)
Leaderboard:Write(b)
Leaderboard:Refresh()
local rows = World.boards.steals.rows
check("leaderboard filled", rows[1].name.Text ~= "", rows[1].name.Text)
check("top thief is Ben", rows[1].name.Text == "Ben", rows[1].name.Text)
check("coins board has values", World.boards.coins.rows[1].value.Text ~= "")
-- TOP COINS is the coins right now
pa.coins, pb.coins = 9e6, 5e6
Leaderboard:Redraw()
check("top coins is whoever has the most right now", World.boards.coins.rows[1].name.Text == "Ava")
pb.coins = 2e7
Leaderboard:Redraw()
check("top coins changes live", World.boards.coins.rows[1].name.Text == "Ben")
local topNote = Engine.lastClientEvent("Announce", a)
check(
	"a banner when someone takes #1",
	topNote and topNote.args[1]:find("Ben is now #1 on TOP COINS", 1, true) ~= nil,
	topNote and topNote.args[1]
)
-- making a board at all (not top 3) gets a banner too
local fakeRows = {}
for i = 1, 4 do
	table.insert(fakeRows, { id = 900000 + i, name = "Far Away " .. i, value = 1e12 - i })
end
Leaderboard:_announceTop({ key = "steals" }, fakeRows)
table.insert(fakeRows, { id = b.UserId, name = "Ben", value = 1 })
Leaderboard:_announceTop({ key = "steals" }, fakeRows)
local madeNote = Engine.lastClientEvent("Announce", a)
check(
	"a banner when someone makes a board at all",
	madeNote and tostring(madeNote.args[1]):find("Ben made the TOP THIEVES board", 1, true) ~= nil,
	madeNote and madeNote.args[1]
)
Leaderboard:Redraw()
-- BEST DRAGONS is each player's best dragon right now: lose it and lose the spot
local galaxy = Dragon:Grant(b, "OMNI") -- the best dragon there is
Leaderboard:Redraw()
local bestRow = World.boards.income.rows[1].name.Text
check(
	"best dragons shows the owner and the dragon",
	bestRow:find("Ben", 1, true) == 1 and bestRow:find("Omni", 1, true) ~= nil,
	bestRow
)
for i, r in pb.dragons do
	if r == galaxy then
		table.remove(pb.dragons, i) -- as if it was stolen
	end
end
Leaderboard:Redraw()
check("losing the best dragon loses the spot", World.boards.income.rows[1].name.Text:find("Ben", 1, true) == nil)
-- TODAY'S TOP EARNERS, the countdown and the Ultra prize
local Economy = service("EconomyService")
Economy:Add(a, 123456)
Leaderboard:Redraw()
check(
	"daily board shows today's earners",
	World.boards.daily.rows[1].name.Text == "Ava",
	World.boards.daily.rows[1].name.Text
)
check("daily board has a countdown", World.boards.daily.timer.Text:find("Ends in", 1, true) ~= nil)
local DragonsD = Engine.require(tree.shared.Data.Dragons)
local function countOmni(pp)
	local n = 0
	for _, r in pp.dragons do
		if r.id == DragonsD.PRIZE then
			n += 1
		end
	end
	for _, r in pp.waiting or {} do
		if r.id == DragonsD.PRIZE then
			n += 1
		end
	end
	return n
end
local Formulas2 = Engine.require(tree.shared.Formulas)
local today = Formulas2.dailyPeriod(Engine.globals.os.time())
Leaderboard:_rollover(today)
check("the daily #1 wins the Ultra dragon when the day ends", countOmni(pa) == 1 and pa.prizes[tostring(today)] == true)
check("only once per day", Leaderboard:GivePrize(a, today) == false and countOmni(pa) == 1)
check("the prize is on show in the lobby", Engine.workspace.Map.Lobby:FindFirstChild("PrizeDragon") ~= nil)

-- Leaving mid-steal: the thief keeps it ---------------------------------------------------------------------
Engine.advance(130)
local bait = anyNestModel(a)
local baitId = bait:GetAttribute("DragonId")
go(b, bait.PrimaryPart.Position)
trigger(b, bait, "steal")
check("Ben carrying Ava's dragon", Dragon:Carrying(b) ~= nil)
local avaCount = #pa.dragons
Engine.removePlayer(a)
Engine.advance(0.5)
check("Ava's base freed", Base:Get(a) == nil and World.bases[1].signLines[1].Text == "EMPTY BASE")
check("thief keeps a dragon when the owner leaves", countRec(pb, baitId) >= 1 and Dragon:Carrying(b).owner == b)
goHome(b)
check("placed in Ben's nest", Dragon:Carrying(b) == nil)
if not noDataStore then
	local saved = Engine.dataStores.SAD_Profiles_v1["u_1001"]
	check("Ava saved without the stolen dragon", saved and #saved.dragons == avaCount - 1, saved and #saved.dragons)
end

-- Offline coins on rejoin ------------------------------------------------------------------------------------
if not noDataStore then
	Engine.advance(600)
	local a2 = join("Ava", 1001)
	local pa2 = Data:Get(a2)
	local off = Engine.lastClientEvent("Offline", a2)
	check("away coins offered", off and off.args[1].coins > 0)
	local before2 = pa2.coins
	Engine.fireServer(a2, "ClaimOffline")
	Engine.advance(0.1)
	check("away coins claimed", pa2.coins > before2)
	check("dragons back in nests", #pa2.dragons == avaCount - 1 and anyNestModel(a2) ~= nil)
	check("no tutorial for returning players", pa2.tutorialDone and Engine.lastClientEvent("Tutorial", a2) == nil)
	check("returning player spawns in their base", Base:InOwnBase(a2))
	Engine.makeCharacter(a2)
	Engine.advance(0.2)
	check("respawns in their base", Base:InOwnBase(a2))
end

-- Custom dragons ----------------------------------------------------------------------------------------------
local DragonBuilder = Engine.require(tree.server.World.DragonBuilder)
local DragonsData = Engine.require(tree.shared.Data.Dragons)
local built, plain, spinners = 0, nil, 0
for _, d in DragonsData.list do
	if d.fancy and not d.ultra then
		local m = DragonBuilder.build(d.id, nil, 3)
		built += 1
		-- more parts than a regular dragon (extras), or effects on the body
		local parts, effects = 0, 0
		for _, x in m:GetDescendants() do
			if x:IsA("BasePart") then
				parts += 1
			elseif x.ClassName == "ParticleEmitter" or x.ClassName == "Fire" or x.ClassName == "Sparkles" then
				effects += 1
			elseif x.Name == "Spin" then
				spinners += 1
			end
		end
		if parts <= 25 or effects == 0 then
			plain = d.id
		end
		m:Destroy()
	end
end
check("all 200 custom dragons build, each with extras and effects", built == 200 and plain == nil, plain)
check("some custom dragons have spinning halos, orbs or rings", spinners > 50, spinners)
-- the road nearly always has one walking
local withFancy, samples = 0, 0
for _ = 1, 90 do
	Engine.advance(1)
	samples += 1
	if Road:FancyOnRoad() then
		withFancy += 1
	end
end
check("a custom dragon is on the road almost all the time", withFancy / samples >= 0.9, withFancy .. "/" .. samples)

-- DISCO FEVER: the button in the disco gives everyone 1.25x coins for 15 minutes, again 30 minutes after a press
local feverButton = World.feverButton
check("disco has the fever button", feverButton ~= nil and feverButton:FindFirstChild("Prompt_fever") ~= nil)
local here = Engine.Players:GetPlayers()[1]
local _, multBefore = Base:Income(here)
feverButton.Prompt_fever.Triggered:Fire(here)
Engine.advance(1.1)
local _, multAfter = Base:Income(here)
check(
	"fever gives everyone 1.25x",
	math.abs(multAfter - multBefore * Constants.FEVER_MULT) < 0.001,
	multAfter / multBefore
)
check("fever prompt shows it's on", feverButton.Prompt_fever.ActionText:find("FEVER ON", 1, true) ~= nil)
check("can't press again right away", Base:StartFever(here) == false)
local guideDots, nearRoad = 0, false
for _, d in Engine.workspace.Map:FindFirstChild("Disco", true):GetChildren() do
	if d.Name == "GuideLine" then
		guideDots += 1
		nearRoad = nearRoad or d.Position.X < 106
	end
end
check("a line of lights leads from the road to the disco", guideDots > 10 and nearRoad)

-- Playtime gifts: they arrive by themselves as minutes played today add up
do
	local who = Engine.Players:GetPlayers()[1]
	local pw = Data:Get(who)
	pw.playtime = { day = Formulas.day(Engine.globals.os.time()), seconds = 55, given = 0 }
	local coins = pw.coins
	Engine.advance(6)
	check("1 minute playtime gift: coins", pw.playtime.given == 1 and pw.coins >= coins + 150, pw.playtime.given)
	check("the gift is announced", Engine.lastClientEvent("Alert", who) ~= nil)
	local potions = pw.potions
	pw.playtime.seconds = 178
	Engine.advance(3)
	check("3 minute playtime gift: potions", pw.playtime.given == 2 and pw.potions == potions + 2, pw.potions - potions)
	pw.playtime.seconds = 298
	local count = #pw.dragons
	Engine.advance(3)
	check("5 minute playtime gift: a dragon", pw.playtime.given == 3 and #pw.dragons == count + 1)
	pw.playtime.day -= 1
	Engine.advance(1.1)
	check("playtime gifts start over each day", pw.playtime.given == 0 and pw.playtime.seconds <= 2)
	pw.playtime.given = #Formulas.PLAYTIME_GIFTS
	-- the boost runs out
	pw.newBoostLeft = 2
	Engine.advance(3)
	check("the new-player boost runs out", pw.newBoostLeft == 0 and select(2, Base:Income(who)) < 2)
end

-- Raiders: goblin NPCs fill quiet servers, raid open bases, drop the dragon when bonked, or get away
do
	local raidEvery = Constants.NPC_RAID_EVERY
	Constants.NPC_RAID_EVERY = { 9999, 9999 } -- no raids of their own during the test: it sends them
	Npc.active = true
	for _ = 1, 4 do
		Engine.advance(4.1)
	end
	local players = Engine.Players:GetPlayers()
	check("raiders fill a quiet server", #Npc.npcs == Npc:Wanted() and #Npc.npcs > 0, #Npc.npcs)
	check("raiders aren't players", #Engine.Players:GetPlayers() == #players)
	check("raiders in the world", Engine.workspace.Raiders:FindFirstChildOfClass("Model") ~= nil)
	local victim = players[1]
	local vp = Data:Get(victim)
	vp.tutorialDone = true
	Base:Get(victim).lockUntil = 0
	local DragonsData = Engine.require(tree.shared.Data.Dragons)
	while #vp.dragons < 3 do
		Dragon:Grant(victim, DragonsData.list[1].id)
	end
	Engine.advance(0.2)
	local function slotted()
		local n = 0
		for _, r in vp.dragons do
			n += r.slot and 1 or 0
		end
		return n
	end
	local function raidUntilCarrying(npc)
		check("a raider heads for a base", Npc:Raid(npc, victim))
		for _ = 1, 400 do
			Engine.advance(0.25)
			if npc.carrying then
				break
			end
		end
		return npc.carrying ~= nil
	end
	local npc = Npc.npcs[1]
	local before = slotted()
	check("a raider steals a dragon", raidUntilCarrying(npc))
	check("the nest empties", slotted() == before - 1)
	check("the owner is alerted", Engine.lastClientEvent("Alert", victim) ~= nil)
	check("raiders carrying a dragon are thieves", npc.model:FindFirstChild("ThiefGlow") ~= nil)
	-- bonk it
	local hunter = players[#players]
	local hp = Data:Get(hunter)
	Engine.advance(Constants.BONK_COOLDOWN + 0.1)
	go(hunter, npc.pos)
	local coins = hp.coins
	local bounty = Npc:Bounty(npc)
	Engine.fireServer(hunter, "Bonk")
	Engine.advance(0.1)
	check("bonked raider drops the dragon", npc.carrying == nil and npc.state == "stunned")
	check("bonking a raider pays the bounty", hp.coins >= coins + bounty, hp.coins - coins)
	check("the raider's dragon is on the ground", Engine.workspace.Dragons:FindFirstChild("DroppedDragon") ~= nil)
	Engine.advance(Constants.DROP_GRAB_SECONDS + 1.5)
	check("unclaimed, it flies home", slotted() == before)
	-- one that gets away: the dragon still comes home
	local npc2 = Npc.npcs[2] or Npc:Spawn()
	vp.tutorialDone = true
	check("a second raid", raidUntilCarrying(npc2))
	npc2.pos = Vector3.new(Constants.ROAD_END_X + 10, 0.5, 0)
	npc2.path = { Vector3.new(Constants.ROAD_END_X + 14, 0.5, 0) }
	Engine.advance(1.5)
	check("a raider that gets away vanishes", table.find(Npc.npcs, npc2) == nil)
	check("its dragon flies home", slotted() == before)
	-- a raider inside a base that locks is thrown out at the gate
	do
		local npc3 = Npc:Spawn()
		local vb = Base:Get(victim)
		npc3.pos = (vb.world.cf * CFrame.new(0, 0.5, 5)).Position
		npc3.path = {}
		Base:Lock(victim)
		Engine.advance(0.2)
		check("a locked base throws raiders out", Base:BaseAt(npc3.pos) == nil)
		vb.lockUntil = 0
	end
	-- busy servers send them home
	Npc.active = false
	for _ = 1, 120 do
		Engine.advance(0.5)
		if #Npc.npcs == 0 then
			break
		end
	end
	check("raiders leave when not wanted", #Npc.npcs == 0, #Npc.npcs)
	Constants.NPC_RAID_EVERY = raidEvery
end

-- Discord game log: joins, leaves with session stats, chat, steals, purchases... batched every few seconds
Engine.advance(Constants.GAME_LOG_FLUSH_SECONDS + 0.5)
local function logWith(text)
	for _, e in gameLogs do
		if e.title:find(text, 1, true) then
			return e
		end
	end
end
check("game log: server started", logWith("Server started") ~= nil)
check("game log: join", logWith("@Ava joined") ~= nil)
check("game log: a completed steal", logWith(" stole ") ~= nil)
check("game log: an egg hatch", logWith("egg hatched") ~= nil)
check("game log: a daily prize win", logWith("TOP EARNER") ~= nil)
local leaver = Engine.Players:GetPlayers()[1]
leaver.Chatted:Fire("hello dragons")
Engine.advance(Constants.GAME_LOG_FLUSH_SECONDS + 0.5)
local heardChat = false
for _, c in chatLogs do
	heardChat = heardChat or (c.text == "hello dragons" and c.name == leaver.DisplayName)
end
check("game log: chat", heardChat)
local leaverProfile = Data:Get(leaver)
leaverProfile.stats.bought += 2
local stats = GameLog:SessionStats(leaver, leaverProfile)
local function stat(name)
	for _, st in stats do
		if st.name == name then
			return st.value
		end
	end
end
check(
	"leave stats: time, coins, dragons",
	stat("Time played") ~= nil and stat("Coins earned") ~= nil and (stat("Dragons bought") or 0) >= 2
)
check("leave stats: best dragon and robux", stat("Best dragon") ~= nil and stat("Robux spent") ~= nil)
Engine.removePlayer(leaver)
Engine.advance(Constants.GAME_LOG_FLUSH_SECONDS + 0.5)
local leaveLog = logWith(" left")
check("game log: leave with stats", leaveLog ~= nil and #leaveLog.fields >= 10, leaveLog and #leaveLog.fields)

-- Analytics: sessions and everything players did ---------------------------------------------------------------
Engine.advance(Constants.ANALYTICS_FLUSH_SECONDS + 1)
local function eventsOf(kind)
	local out = {}
	for _, e in aEvents do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end
check("analytics: joins", #eventsOf("join") >= 3)
check("analytics: save loaded, with load time", #eventsOf("loaded") >= 3 and eventsOf("loaded")[1].data.seconds ~= nil)
check("analytics: tutorial goals", #eventsOf("tutorial_step") >= 2 and eventsOf("tutorial_step")[1].data.step == 1)
check(
	"analytics: dragons bought, with rarity and price",
	#eventsOf("buy_dragon") >= 1 and eventsOf("buy_dragon")[1].data.price ~= nil
)
check("analytics: steals and the robbed side", #eventsOf("placed_stolen") >= 1 and #eventsOf("got_robbed") >= 1)
check("analytics: client requests", #eventsOf("req_lock") + #eventsOf("req_bonk") + #eventsOf("req_purchase") >= 1)
check("analytics: minute snapshots", #eventsOf("snapshot") >= 1 and eventsOf("snapshot")[1].data.coins ~= nil)
local leaveRow
for _, row in aSessions do
	if row.end_reason == "left" then
		leaveRow = row
	end
end
check(
	"analytics: a session row ends with a summary",
	leaveRow ~= nil and leaveRow.duration_s ~= nil and leaveRow.summary ~= nil
)
check(
	"analytics: the summary has the last actions and counts",
	leaveRow and #leaveRow.summary.last_actions >= 1 and leaveRow.summary.counts ~= nil
)
local firstRow
for _, row in aSessions do
	if row.session_no == 1 then
		firstRow = row
	end
end
check(
	"analytics: session number and start progress",
	firstRow ~= nil and firstRow.start ~= nil and firstRow.is_new ~= nil
)
-- the client's device info and button taps arrive through the Analytics remote
local someone = Engine.Players:GetPlayers()[1]
Engine.fireServer(someone, "Analytics", "client_info", { device = "touch", screen = "844x390" })
Engine.fireServer(someone, "Analytics", "ui", { taps = { ShopButton = 3 } })
Engine.advance(Constants.ANALYTICS_FLUSH_SECONDS + 1)
check(
	"analytics: device on the session row",
	(function()
		for _, row in aSessions do
			if row.device == "touch" and row.screen == "844x390" then
				return true
			end
		end
		return false
	end)()
)
check("analytics: button taps", #eventsOf("ui") >= 1 and eventsOf("ui")[1].data.taps.ShopButton == 3)

-- Fill the first servers first --------------------------------------------------------------------------------
do
	local Fill = service("ServerFillService")
	Fill.testMode = true
	Fill.number = 3
	local version = Engine.game.PlaceVersion
	Fill.servers = {
		{ jobId = "one", n = 1, players = 7, max = 8, version = version }, -- full (one slot kept free)
		{ jobId = "two", n = 2, players = 3, max = 8, version = version },
		{ jobId = "old", n = 0, players = 1, max = 8, version = -1 }, -- an older version of the game
	}
	local newcomer = Engine.addPlayer("Zed", 9001)
	local target = Fill:TargetFor(newcomer)
	check(
		"fill: the lowest-numbered server with room",
		target ~= nil and target.jobId == "two",
		target and target.jobId
	)
	Fill.servers[2].players = 7
	check("fill: no room anywhere lower: stay", Fill:TargetFor(newcomer) == nil)
	Fill.servers[2].players = 3
	Fill.number = 1
	check("fill: server 1 never sends anyone away", Fill:TargetFor(newcomer) == nil)
	Fill.testMode = false
	Engine.removePlayer(newcomer)
	Engine.advance(0.5)
end

-- Shutdown ----------------------------------------------------------------------------------------------------
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

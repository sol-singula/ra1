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

-- Ava bonks Ben, grabs her dragon back
go(a, b.Character.HumanoidRootPart.Position + Vector3.new(3, 0, 0))
Engine.fireServer(a, "Bonk")
Engine.advance(0.1)
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
trigger(a, gm, "grow")
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
	"tag shows the level",
	gm.PrimaryPart.Tag.Line2.Text:find("Lv " .. (lv0 + 10)) ~= nil,
	gm.PrimaryPart.Tag.Line2.Text
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
trigger(a, gm, "levelup")
check("no Level Up without coins", Formulas.level(grown, Engine.globals.os.time()) == lv0 + 11)
pa.coins = poor

-- Buy plates in the base
local world = Base:Get(a).world
check("plates built", world.autoPlate ~= nil and world.lockPlate ~= nil)
go(a, world.autoPlate.Position)
check("Auto Collect plate sells the pass", pa.passes.AUTO == true)
local lockBefore = Base:Get(a).lockUntil
go(a, world.lockPlate.Position)
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
check("LEVEL ALL plate built", world.levelPlate ~= nil)
local levelsBefore = totalLevels()
pa.coins += 1e7
local coinsBeforeAll = pa.coins
go(a, world.levelPlate.Position)
check("LEVEL ALL buys levels", totalLevels() > levelsBefore + 1, totalLevels() - levelsBefore)
check("LEVEL ALL spends coins", pa.coins < coinsBeforeAll)
goHome(a)
pa.coins = 0
levelsBefore = totalLevels()
go(a, world.levelPlate.Position) -- no coins: offers +5 Levels for ALL (free in Studio)
local nestCount = 0
for _, r in pa.dragons do
	if r.slot and Formulas.level(r, Engine.globals.os.time()) < Constants.MAX_LEVEL then
		nestCount += 1
	end
end
check("+5 Levels for ALL levels every dragon", totalLevels() >= levelsBefore + 5 * math.max(1, nestCount - 1))
goHome(a)
pa.coins = coinsBeforeAll

-- Castle levels grow with dragon power
local myBase = Base:Get(a)
check(
	"castle level thresholds",
	Base.castleLevelFor(0) == 1 and Base.castleLevelFor(30) == 2 and Base.castleLevelFor(1e9) == 5
)
local trim = world.levels[5]:FindFirstChild("GoldTrim", true)
local realPower = Base.DragonPower
Base.DragonPower = function()
	return 1e9
end
Base:UpdateCastle(myBase)
check("castle grows to level 5", world.castleLevel == 5 and trim ~= nil and trim.Transparency < 1)
check("sign shows the castle level", world.signLines[1].Text:find("🏰5", 1, true) ~= nil)
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
Engine.advance(1.2)
hand.Activated:Fire()
Engine.advance(0.05)
check("clicking with the bat swings it", hand:FindFirstChild("toolanim") ~= nil)
Engine.advance(1.2)
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
toolOf(a, "potion").Activated:Fire() -- out of potions: offers the pack (free in Studio)
Engine.advance(0.1)
check("out of potions offers 5 more", pa.potions == Constants.POTION_PACK, pa.potions)
-- passes change the hotbar
check("no wings without the pass", toolOf(a, "wings") == nil)
Engine.fireServer(a, "Purchase", "pass", "MEGABONK")
Engine.advance(0.1)
check("Mega Bonk swaps the bat for a hammer", toolOf(a, "bonk").Name == "Mega Hammer")
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

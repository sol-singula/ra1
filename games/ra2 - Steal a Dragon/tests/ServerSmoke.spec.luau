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
local ShopData = Engine.require(tree.shared.Data.Shop)
local Formulas = Engine.require(tree.shared.Formulas)
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

-- Join and tutorial ----------------------------------------------------------------------------------------
local a = join("Ava", 1001)
local pa = Data:Get(a)
check("profile loaded", pa ~= nil)
check("unsaved only without DataStore", (pa._noSave == true) == noDataStore)
check("base assigned", Base:Get(a) ~= nil and Base:Get(a).owner == a)
check("leaderstats", a:FindFirstChild("leaderstats") and a.leaderstats:FindFirstChild("Coins") ~= nil)
check("base sign shows owner", Base:Get(a).world.signLines[1].Text == "AVA")
Leaderboard:Refresh()
check(
	"boards show players even in a brand-new game",
	World.boards.coins.rows[1].name.Text == "Ava",
	World.boards.coins.rows[1].name.Text
)
Engine.advance(0.5)
local t = lastTutorial(a)
check("tutorial step 1", t and t.step == 1 and t.target == Road.freeModel, t and t.step)

trigger(a, Road.freeModel, "free")
check("carrying the free Puff", Dragon:Carrying(a) and Dragon:Carrying(a).rec.id == "PUFF")
check("carry slows you down", a.Character.Humanoid.WalkSpeed < 18)
check("carried model on the character", a.Character:FindFirstChild("CarriedDragon") ~= nil)
trigger(a, Road.freeModel, "free") -- second grab refused
check("free dragon only once", #pa.dragons == 1)
Engine.advance(0.5)
check("tutorial step 2: run home", lastTutorial(a).step == 2)
goHome(a)
check("placed in nest 1", pa.dragons[1].slot == 1 and Dragon:Carrying(a) == nil)
check("nest model built", nestModel(a, 1) ~= nil)
check("walk speed back to normal", a.Character.Humanoid.WalkSpeed == 18)
Engine.advance(0.5)
check("tutorial step 3: collect", lastTutorial(a).step == 3)
Engine.advance(5)
check("bank fills", Base:Get(a).bank >= 4, Base:Get(a).bank)
go(a, Base:Get(a).world.collectPad.Position)
check("coins collected", pa.coins >= 4 and Base:Get(a).bank < 1, pa.coins)
Engine.advance(0.5)
check("tutorial step 4: lock", lastTutorial(a).step == 4)
go(a, Base:Get(a).world.lockPad.Position)
check("base locked", Base:IsLocked(Base:Get(a)))
check("laser visible", Base:Get(a).world.laser.Transparency < 1)
Engine.advance(0.5)
check("tutorial step 5: practice steal", lastTutorial(a).step == 5)
go(a, Road.practiceModel.PrimaryPart.Position)
trigger(a, Road.practiceModel, "practice")
check("carrying practice Frosty", Dragon:Carrying(a) and Dragon:Carrying(a).rec.id == "FROSTY")
Engine.advance(0.5)
check("tutorial step 6: run home", lastTutorial(a).step == 6)
goHome(a)
check("Frosty in a nest", countRec(pa, "FROSTY") == 1 and Dragon:Carrying(a) == nil)
check("practice steal is not a real steal", pa.steals == 0)
Engine.advance(0.5)
check("tutorial step 7: buy", lastTutorial(a).step == 7)

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
check("goal 1 done (100 coins)", pa.goal >= 2, pa.goal)

-- Second player, locks and stealing ------------------------------------------------------------------------
local b = join("Ben", 1002)
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
nest5.Prompt_nest.Triggered:Fire(a)
Engine.advance(0.1)
check("bought nest 5", pa.nestsBought == 5)
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
-- Grow Now on a nest dragon
local gm = anyNestModel(a)
local guid = gm:GetAttribute("Uid")
trigger(a, gm, "grow")
local grown
for _, r in pa.dragons do
	if r.uid == guid then
		grown = r
	end
end
check("Grow Now grows one stage", grown and Formulas.stage(grown.born, Engine.globals.os.time()) == 2)

-- Daily gift and egg ---------------------------------------------------------------------------------------
local c0 = pa.coins
Engine.fireServer(a, "ClaimDaily")
Engine.advance(0.1)
check("daily day 1 = 500 coins", pa.daily.streak == 1 and pa.coins == c0 + 500)
Engine.fireServer(a, "ClaimDaily")
Engine.advance(0.1)
check("daily only once a day", pa.coins == c0 + 500)
local eggId = pa.egg.id
local count0 = countRec(pa, eggId)
local egg = Base:Get(a).world.model:FindFirstChild("Egg")
trigger(a, egg, "hatch") -- not ready: opens Hatch Now (free in Studio)
check("egg hatched into the shown dragon", countRec(pa, eggId) == count0 + 1)
check("next egg started", pa.egg ~= nil and pa.eggsGiven == 2)

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

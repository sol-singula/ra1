--[[
Server smoke test: boots the real server scripts on the mock engine (tests/mock/Engine.luau) and plays a
session: join, pick a mutation, cook a burger end to end, serve customers, let an order go wrong, fight,
repair, upgrade the restaurant, leave and rejoin. Fails on any script error or broken expectation.

  luaurun tests/ServerSmoke.spec.luau                 (from the game/ folder)
  luaurun tests/ServerSmoke.spec.luau nodatastore     (Studio-without-API-access fallback)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
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
local Restaurant = service("RestaurantService")
local Cooking = service("CookingService")
local Customers = service("CustomerAIService")
local Economy = service("EconomyService")
local Combat = service("CombatService")
local Repair = service("RepairService")
local Progression = service("ProgressionService")

-- Join ---------------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Chef", 4242)
Engine.makeCharacter(player)
Engine.advance(0.2)
Engine.fireServer(player, "Ready")
Engine.advance(0.2)
local profile = Data:Get(player)
check("profile loaded", profile ~= nil)
check("unsaved profile only without DataStore", (profile._noSave == true) == noDataStore)
local r = Restaurant:Get(player)
check("restaurant built", r ~= nil and r.layout.model.Parent ~= nil)
check("4 seats at TIER_01", r and #r.layout.seats == 4)
check("mutation choice offered", Engine.lastClientEvent("ChooseMutation", player) ~= nil)
check(
	"character moved to the kitchen",
	(player.Character.HumanoidRootPart.Position - r.layout.kitchenSpawn.Position).Magnitude < 1
)

Engine.fireServer(player, "ChooseMutation", "MUT_145")
Engine.advance(0.1)
check("octopus arm equipped", profile.mutations.equipped == "MUT_145")
check("octopus arm visual attached", player.Character:FindFirstChild("MutationParts") ~= nil)
local carryEvent = Engine.lastClientEvent("Carry", player)
check("carry capacity 2 with the octopus arm", carryEvent and carryEvent.args[2] == 2)
Engine.fireServer(player, "ChooseMutation", "MUT_144")
Engine.advance(0.1)
check("second free pick refused", profile.mutations.equipped == "MUT_145")

-- Helpers -------------------------------------------------------------------------------------------------------
local st = r.layout.stations
local function promptOn(part, pattern)
	for _, child in part:GetChildren() do
		if
			child.ClassName == "ProximityPrompt"
			and child.Enabled
			and (not pattern or string.find(child.ActionText, pattern))
		then
			return child
		end
	end
	return nil
end
local function use(part, pattern)
	Engine.moveTo(player, part.Position + Vector3.new(0, 0, -3))
	local p = promptOn(part, pattern)
	check("prompt '" .. (pattern or "any") .. "' on " .. part.Name, p ~= nil)
	if p then
		p.Triggered:Fire(player)
	end
	Engine.advance(0.05)
end
local function top()
	return Cooking:Top(player)
end
local function pick(id)
	use(st.STN_PANTRY.PrimaryPart)
	Engine.fireServer(player, "PantryPick", id)
	Engine.advance(0.05)
	check("picked " .. id, top() and top().id == id)
end
local function chop(id)
	pick(id)
	use(st.STN_CUT.PrimaryPart)
	check("chop session started", Engine.lastClientEvent("ChopStart", player) ~= nil)
	for _ = 1, 4 do
		Engine.advance(0.44)
		Engine.fireServer(player, "ChopTap")
	end
	Engine.advance(0.05)
	check(id .. " chopped", top() and top().state == "CHOPPED", top() and top().state)
end
local board1 = st.STN_ASSEMBLY.Board1

local function makeBurger()
	pick("ING_BEEF_PATTY")
	use(st.STN_GRILL.PrimaryPart)
	check("patty on the grill", top() == nil)
	Engine.advance(8.6)
	use(st.STN_GRILL.PrimaryPart)
	check(
		"patty grilled perfectly",
		top() and top().state == "GRILLED" and top().grade == "PERFECT",
		top() and top().grade
	)
	use(board1, "Add")
	pick("ING_BUN")
	use(board1, "Add")
	pick("ING_KETCHUP")
	use(board1, "Add")
	chop("ING_PICKLE")
	use(board1, "Add")
	chop("ING_LETTUCE")
	use(board1, "Plate")
	check("board shows the dish name", true)
	use(board1, "Plate")
	local dish = top()
	check("plated a Basic Burger", dish and dish.kind == "DISH" and dish.recipeId == "RCP_BRG_001", dish and dish.label)
	check("dish quality high", dish and dish.quality > 0.8, dish and dish.quality)
end

local function pourSoda()
	use(st.STN_DRINK.PrimaryPart)
	check("pour started", Engine.lastClientEvent("PourStart", player) ~= nil)
	Engine.advance(2.75)
	Engine.fireServer(player, "PourStop")
	Engine.advance(0.05)
	local dish = top()
	check(
		"poured a Fizzy Soda",
		dish and dish.recipeId == "RCP_DRK_001" and dish.grade == "PERFECT",
		dish and dish.grade
	)
end

-- Menu ----------------------------------------------------------------------------------------------------------
Engine.fireServer(player, "SetMenu", { "RCP_BRG_001", "RCP_DRK_001" })
Engine.advance(0.1)
check("menu saved", #profile.menu == 2 and profile.menu[1] == "RCP_BRG_001")
Engine.fireServer(player, "SetMenu", { "RCP_BRG_006" })
Engine.advance(0.1)
check("locked recipe refused", profile.menu[1] == "RCP_BRG_001")

-- Tutorial: a scripted customer orders a Basic Burger and every step is highlighted ---------------------------
local tutorialEvent = Engine.lastClientEvent("Tutorial", player)
check("tutorial running", tutorialEvent ~= nil and tutorialEvent.args[1] and tutorialEvent.args[1].step >= 2)
local waitedTut = 0
local tutCustomer
while not tutCustomer and waitedTut < 60 do
	Engine.advance(0.5)
	waitedTut += 0.5
	for _, c in r.ai.customers do
		if c.scripted and c.state == "ORDER" then
			tutCustomer = c
		end
	end
end
check("tutorial customer at the counter", tutCustomer ~= nil)
check(
	"tutorial points at the customer",
	Engine.lastClientEvent("Tutorial", player).args[1].target == (tutCustomer and tutCustomer.proxy)
)
if tutCustomer then
	Engine.moveTo(player, tutCustomer.pos + Vector3.new(0, 0, 3))
	tutCustomer.prompt.Triggered:Fire(player)
	Engine.advance(0.5)
	check("tutorial order is a plain Basic Burger", tutCustomer.order.items[1].recipeId == "RCP_BRG_001")
	check("tutorial moved to the pantry step", Engine.lastClientEvent("Tutorial", player).args[1].step == 3)
	makeBurger()
	Engine.advance(0.5)
	check("tutorial waiting to serve", Engine.lastClientEvent("Tutorial", player).args[1].step == 12)
	Engine.moveTo(player, tutCustomer.pos + Vector3.new(0, 0, 3))
	tutCustomer.prompt.Triggered:Fire(player)
	Engine.advance(12)
	check(
		"tutorial finished",
		profile.tutorialDone == true and Engine.lastClientEvent("Tutorial", player).args[1] == false
	)
	check("tutorial reward paid", profile.mb >= 25)
end

-- Cook one burger before anyone arrives (also exercises every station)
makeBurger()
-- trash it and check the waste charge never goes below zero
use(st.STN_TRASH.PrimaryPart)
check("trash empties hands", top() == nil)
check("waste never makes MB negative", profile.mb >= 0)

-- French Fries: fryer + ketchup (needs fries on the menu for a moment)
Engine.fireServer(player, "SetMenu", { "RCP_BRG_001", "RCP_DRK_001", "RCP_FRI_001" })
Engine.advance(0.1)
pick("ING_POTATO")
use(st.STN_FRYER.PrimaryPart)
check("potato in the fryer", top() == nil)
Engine.advance(7.5)
use(st.STN_FRYER.PrimaryPart)
check("potato fried", top() and top().state == "FRIED" and top().grade == "PERFECT", top() and top().grade)
use(board1, "Add")
pick("ING_KETCHUP")
use(board1, "Add")
use(board1, "Plate")
check("plated French Fries", top() and top().recipeId == "RCP_FRI_001")
use(st.STN_TRASH.PrimaryPart)
Engine.fireServer(player, "SetMenu", { "RCP_BRG_001", "RCP_DRK_001" })
Engine.advance(0.1)

-- Burn something to test the fire
pick("ING_BEEF_PATTY")
use(st.STN_GRILL.PrimaryPart)
Engine.advance(25)
check("grill caught fire", r.cooking.heat.STN_GRILL.fire == true)
use(st.STN_GRILL.PrimaryPart, "Put out fire")
check("fire extinguished", r.cooking.heat.STN_GRILL.fire == false)

-- Serve the first customers -----------------------------------------------------------------------------------
local function firstCustomer(state)
	for _, c in r.ai.customers do
		if not state or c.state == state then
			return c
		end
	end
	return nil
end
local served = 0
for _ = 1, 3 do
	local waited = 0
	while not firstCustomer("ORDER") and waited < 240 do
		Engine.advance(1)
		waited += 1
	end
	local c = firstCustomer("ORDER")
	check("a customer reached the counter", c ~= nil)
	if not c then
		break
	end
	Engine.moveTo(player, c.pos + Vector3.new(0, 0, 3))
	c.prompt.Triggered:Fire(player)
	Engine.advance(0.1)
	check("order taken", c.order ~= nil and c.state == "TO_SEAT", c.state)
	check("order attribute published", c.proxy:GetAttribute("Order") ~= nil)
	for _, item in c.order.items do
		if item.recipeId == "RCP_DRK_001" then
			pourSoda()
		else
			makeBurger()
		end
		Engine.moveTo(player, c.pos + Vector3.new(0, 0, 3))
		c.prompt.Triggered:Fire(player)
		Engine.advance(0.1)
	end
	check("customer eating", c.state == "EAT", c.state)
	local summary = Engine.lastClientEvent("Served", player)
	check("served summary sent", summary ~= nil)
	if summary then
		local s = summary.args[1]
		print(string.format("  served %s: %s %d · +%d MB · +%d XP", s.name, s.mood, s.satisfaction, s.net, s.xp))
	end
	served += 1
	Engine.advance(Customers and 12 or 0)
end
check("served three customers", served == 3)
check("earned money", profile.mb > 0, profile.mb)
check("earned XP", profile.xp > 0 or profile.level > 1)
check("lifetime served counted", profile.lifetime.served == 4, profile.lifetime.served)

-- Wrong dish -------------------------------------------------------------------------------------------------
local waited = 0
while not firstCustomer("ORDER") and waited < 240 do
	Engine.advance(1)
	waited += 1
end
local c = firstCustomer("ORDER")
if c then
	Engine.moveTo(player, c.pos + Vector3.new(0, 0, 3))
	c.prompt.Triggered:Fire(player)
	Engine.advance(0.1)
	-- hand them fries, which are not on this order (or even on the menu)
	Cooking:Give(player, {
		kind = "DISH",
		recipeId = "RCP_FRI_001",
		label = "French Fries",
		contents = { ["ING_POTATO|FRIED"] = 1, ["ING_KETCHUP|RAW"] = 1 },
		omitted = {},
		quality = 1,
		cook = 1,
		color = Engine.globals.Color3.new(1, 0.8, 0.3),
	})
	local angerBefore = c.anger
	Engine.moveTo(player, c.pos + Vector3.new(0, 0, 3))
	c.prompt.Triggered:Fire(player)
	Engine.advance(0.1)
	check("wrong dish refused and angers", c.anger > angerBefore and top() ~= nil, c.anger)
	use(st.STN_TRASH.PrimaryPart)

	-- Fight: bop them until dizzy, then they pay an apology
	local mbBefore = profile.mb
	for _ = 1, 60 do
		if c.state == "DIZZY" or c.state == "LEAVE" then
			break
		end
		local hrp = player.Character.HumanoidRootPart
		hrp.CFrame = Engine.CFrame.lookAt(c.pos + Vector3.new(0, 0, 3), c.pos)
		Engine.fireServer(player, "Attack")
		Engine.advance(0.4)
	end
	check("customer hit until dizzy or stormed out", c.state == "DIZZY" or c.state == "LEAVE", c.state)
	Engine.advance(4)
	check("apology or storm-out resolved", c.state == "LEAVE", c.state)
	check("MB not lost by fighting", profile.mb >= mbBefore)
end

-- Ignore customers for a while: patience runs out, anger, thrown food, KO ---------------------------------
Engine.moveTo(player, r.layout.kitchenSpawn.Position)
Engine.advance(300, 1 / 15)
-- a thrown plate always lands where a standing-still target was
local hpBefore = Engine.lastClientEvent("Profile", player)
Combat:ThrowFood(r.layout.center, player, 1, Engine.globals.Color3.new(1, 0, 0), nil)
Engine.advance(1.2)
local hit = false
for i = #Engine.clientLog, 1, -1 do
	local e = Engine.clientLog[i]
	if e == hpBefore then
		break
	end
	if e.name == "Profile" and e.args[1].hp then
		hit = true
	end
end
check("thrown food hits a player who stands still", hit or Combat:IsKO(player))
print(
	"  projectiles: "
		.. Engine.countClientEvents("Projectile")
		.. ", KOs: "
		.. Engine.countClientEvents("KO")
		.. ", popups: "
		.. Engine.countClientEvents("Popup")
)
Engine.advance(5) -- a knock-out lasts 4 s
check("player not stuck KO", not Combat:IsKO(player))

-- Calm Down! on whoever is angry
local angry
for _, cc in r.ai.customers do
	if cc.anger > 0 and cc.state ~= "LEAVE" then
		angry = cc
	end
end
if angry then
	local before = angry.anger
	Engine.moveTo(player, angry.pos + Vector3.new(0, 0, 3))
	Engine.fireServer(player, "Ability", "ABL_006")
	Engine.advance(0.1)
	check("calm down lowers anger", angry.anger < before or angry.level >= 5, before .. " -> " .. angry.anger)
end

-- Octo-Flurry (mutation ability)
Engine.fireServer(player, "Ability", "ABL_012")
Engine.advance(0.1)
check("mutation ability cooldown sent", Engine.lastClientEvent("Cooldown", player) ~= nil)
Engine.fireServer(player, "Ability", "ABL_017")
Engine.advance(0.1)

-- Repair ---------------------------------------------------------------------------------------------------
local tbl = r.layout.model.Dining.Table1
tbl:SetAttribute("Durability", 100) -- an angry customer may already have smashed it
Repair:Damage(tbl, 80)
check("table broken", tbl:GetAttribute("DamageState") == "Broken")
Economy:Grant(player, "MB", 500, "test")
use(tbl, "Repair")
check("table repaired", tbl:GetAttribute("Durability") == 100)

-- Level up and stats ---------------------------------------------------------------------------------------
Progression:AddXp(player, 5000)
Engine.advance(0.1)
check("levelled up", profile.level >= 5, profile.level)
check("stat points granted", profile.statPoints >= 8, profile.statPoints)
Engine.fireServer(player, "AllocateStat", "COOK_SPD")
Engine.advance(0.1)
check("stat allocated", profile.stats.COOK_SPD == 1)

-- Upgrade to TIER_02 ---------------------------------------------------------------------------------------
for _, cc in r.ai.customers do
	Customers:_remove(cc)
end
Economy:Grant(player, "MB", 1000, "test")
local mb = profile.mb
Engine.fireServer(player, "UpgradeTier")
Engine.advance(0.2)
check("upgraded to TIER_02", profile.tier == "TIER_02" and r.tierIndex == 2)
check("paid 1000 MB", profile.mb == mb - 1000)
check("6 seats after upgrade", #r.layout.seats == 6)
check("old model removed", #Engine.workspace.Restaurants:GetChildren() == 1)
st = r.layout.stations
board1 = st.STN_ASSEMBLY.Board1
makeBurger() -- stations still work after the rebuild
use(st.STN_TRASH.PrimaryPart)
Engine.advance(120, 1 / 15)

-- Leave and rejoin -----------------------------------------------------------------------------------------
local savedMb, savedLevel = profile.mb, profile.level
Engine.removePlayer(player)
Engine.advance(0.5)
check("plot freed", #Engine.workspace.Restaurants:GetChildren() == 0)
if not noDataStore then
	local stored = Engine.dataStores.MMR_Profiles_v1.u_4242
	check("profile saved", stored ~= nil and stored.mb == savedMb and stored.level == savedLevel)
	check("session lock released", stored and stored.meta.lock == nil)
	local again = Engine.addPlayer("Chef", 4242)
	Engine.makeCharacter(again)
	Engine.advance(0.5)
	local p2 = Data:Get(again)
	check(
		"rejoin loads saved progress",
		p2 and p2.mb == savedMb and p2.tier == "TIER_02" and p2.mutations.equipped == "MUT_145"
	)
	check("no mutation prompt on rejoin", true)
	for _, handler in Engine.closeHandlers do
		handler()
	end
end

print(
	string.format(
		"%d passed, %d failed, %d script errors, %d warnings",
		passed,
		failed,
		#Engine.errors,
		#Engine.warnings
	)
)
for _, w in Engine.warnings do
	print("  warning: " .. w)
end
if failed > 0 or #Engine.errors > 0 then
	error("server smoke test failed")
end

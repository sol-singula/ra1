--[[
Plays a real session of the game on the mock engine, server and client code together, and writes a snapshot of
what the player sees at each interesting moment. A small bot plays: it takes orders, cooks every recipe step at
the real stations, serves, levels up, upgrades the restaurant and gets into trouble with angry customers.

  luaurun tools/gameplay/session.luau <outDir>        (from the game folder)

Then render the snapshots with tools/gameplay/render.js.
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local outDir = ARGS[1] or "screens"
math.randomseed(tonumber(ARGS[2]) or 7)

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.runScript(tree.server.Main)
Engine.advance(0.1)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Restaurant = service("RestaurantService")
local Cooking = service("CookingService")
local Data = service("PlayerDataService")
local Combat = service("CombatService")
local Recipes = Engine.require(tree.shared.Data.Recipes)
local Ingredients = Engine.require(tree.shared.Data.Ingredients)
local HttpService = Engine.game:GetService("HttpService")

-- Neighbours on the street (server-only players, standing in their kitchens)
for i, name in { "PixelPaws", "BoltNugget" } do
	local p = Engine.addPlayer(name, 900 + i)
	Engine.makeCharacter(p)
	Engine.advance(0.1)
	Engine.fireServer(p, "ChooseMutation", ({ "MUT_144", "MUT_153" })[i])
end

-- The local player, with the real client scripts
local player = Engine.addPlayer("Chef", 4242)
player.DisplayName = "ChefGrizzle"
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
Engine.runScript(tree.client.Main)
Engine.advance(0.5)
local r = Restaurant:Get(player)
local profile = Data:Get(player)
local gui = player.PlayerGui

local shots = {}
local function at(x, y, z)
	return (r.layout.root * CF.new(x, y, z)).Position
end
local function shot(name, camPos, camTarget, fov)
	local snap = Capture.snapshot(
		Engine,
		{ pos = { camPos.X, camPos.Y, camPos.Z }, target = { camTarget.X, camTarget.Y, camTarget.Z }, fov = fov or 70 }
	)
	snap.title = name
	writeFile(outDir .. "/" .. name .. ".json", HttpService:JSONEncode(snap))
	table.insert(shots, name)
	print("shot " .. name .. string.format("  (t=%.0fs, MB %d, level %d)", Engine.now(), profile.mb, profile.level))
end
local function hrp()
	return player.Character.HumanoidRootPart
end
-- third-person camera behind the player
local function behind(dist, height, side)
	local cf = hrp().CFrame
	dist, height = dist * 1.25 + 2, height * 1.3 + 1.5
	local pos = cf.Position - cf.LookVector * dist + V3.new(0, height, 0) + cf.RightVector * (side or 0) * 1.6
	return pos, cf.Position + cf.LookVector * 9 - V3.new(0, 1.5, 0)
end
-- side-on camera that frames the player and a customer together
local function twoShot(c, dist, height, flip)
	local a, b = hrp().Position, c.pos
	local mid = (a + b) / 2
	local line = (b - a) * V3.new(1, 0, 1)
	local side = V3.new(-line.Z, 0, line.X).Unit * (flip and -1 or 1)
	-- pick the side that looks from the kitchen toward the street (the open side of the room)
	local toStreet = -r.layout.root.LookVector
	if side:Dot(toStreet) > 0 then
		side = -side
	end
	return mid + side * (dist or 13) + V3.new(0, height or 7, 0), mid + V3.new(0, 1, 0)
end
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
local function standAt(part, dist)
	local p = part.Position
	local root = r.layout.root
	-- stations sit against the back wall: stand on the kitchen side facing them (+Z)
	local localP = root:PointToObjectSpace(p)
	local standLocal = localP.Z > 8 and V3.new(localP.X, 3.5, localP.Z - (dist or 4))
		or V3.new(localP.X, 3.5, localP.Z + (dist or 4))
	local stand = (root * CF.new(standLocal)).Position
	Engine.moveTo(player, stand, p)
end
local multitask = false
local takeWaitingOrders -- defined below
local function use(part, pattern)
	if multitask and takeWaitingOrders then
		takeWaitingOrders()
	end
	standAt(part)
	local p = promptOn(part, pattern)
	if p then
		p.Triggered:Fire(player)
	end
	Engine.advance(0.05)
	return p
end
local function top()
	return Cooking:Top(player)
end
local function clickText(text)
	for _, d in gui:GetDescendants() do
		if
			(d.ClassName == "TextButton" and d.Text and string.find(d.Text, text, 1, true))
			or (
				d.ClassName == "TextLabel"
				and d.Text
				and string.find(d.Text, text, 1, true)
				and d.Parent.ClassName == "TextButton"
			)
		then
			local b = d.ClassName == "TextButton" and d or d.Parent
			b.Activated:Fire()
			Engine.advance(0.05)
			return true
		end
	end
	return false
end

local st = function()
	return r.layout.stations
end

-- Cooking bot ------------------------------------------------------------------------------------------------
local function pick(id)
	use(st().STN_PANTRY.PrimaryPart)
	clickText(Ingredients[id].name) -- the real pantry panel
end
local function chop()
	use(st().STN_CUT.PrimaryPart)
	for _ = 1, 4 do
		Engine.advance(0.44)
		Engine.fireServer(player, "ChopTap")
	end
	Engine.advance(0.05)
end
local function heat(stationId)
	use(st()[stationId].PrimaryPart)
	local slot
	for _, s in r.cooking.heat[stationId].slots do
		if s.item and (not slot or s.startAt > slot.startAt) then
			slot = s
		end
	end
	Engine.advance(slot and (slot.tReady + 0.6) or 8)
	use(st()[stationId].PrimaryPart)
end
local function cook(recipeId, omit, board)
	local recipe = Recipes.byId[recipeId]
	if recipe.drink then
		use(st().STN_DRINK.PrimaryPart)
		Engine.advance(0.92 * 3 / (1 + 0.006 * 3))
		Engine.fireServer(player, "PourStop")
		Engine.advance(0.05)
		return
	end
	board = board or st().STN_ASSEMBLY.Board1
	for _, part in recipe.parts do
		local id, count, state = part[1], part[2], part[3]
		if not table.find(omit or {}, id) then
			for _ = 1, count do
				pick(id)
				if state == "CHOPPED" then
					chop()
				elseif state == "GRILLED" then
					heat("STN_GRILL")
				elseif state == "FRIED" then
					heat("STN_FRYER")
				end
				use(board, "Add")
			end
		end
	end
	use(board, "Plate")
end

local function customers(state)
	local list = {}
	for _, c in r.ai.customers do
		if not state or c.state == state then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end
local function waitFor(fn, maxSeconds)
	local t = 0
	while not fn() and t < maxSeconds do
		Engine.advance(0.5, 1 / 15)
		t += 0.5
	end
	return fn()
end
local function faceCustomer(c, dist)
	local p = c.pos
	local dir = (r.layout.kitchenSpawn.Position - p) * V3.new(1, 0, 1)
	local stand = p + dir.Unit * (dist or 4)
	Engine.moveTo(player, V3.new(stand.X, 3.5, stand.Z), p)
end
local function takeOrder(c)
	faceCustomer(c, 5)
	c.prompt.Triggered:Fire(player)
	Engine.advance(0.1)
end
local function serve(c)
	faceCustomer(c, 4)
	c.prompt.Triggered:Fire(player)
	Engine.advance(0.1)
end
function takeWaitingOrders()
	for _, c in customers("ORDER") do
		multitask = false -- no recursion while taking the order
		takeOrder(c)
		multitask = true
	end
end
-- the oldest seated customer who still needs food
local function nextHungry()
	local best
	for _, c in customers() do
		if (c.state == "WAIT_FOOD" or c.state == "TO_SEAT") and c.order then
			for _, item in c.order.items do
				if not item.served and (not best or c.orderTakenAt < best.orderTakenAt) then
					best = c
				end
			end
		end
	end
	return best
end
local function serveNextItem(c)
	for _, item in c.order.items do
		if not item.served then
			cook(item.recipeId, item.omit)
			if c.state == "WAIT_FOOD" or c.state == "TO_SEAT" or c.state == "CHASE" then
				serve(c)
			elseif top() then
				use(st().STN_TRASH.PrimaryPart)
			end
			return
		end
	end
end
local function orderOmit(item)
	return item.omit
end
local function serveCustomer(c)
	takeOrder(c)
	for _, item in c.order.items do
		cook(item.recipeId, orderOmit(item))
		if c.state == "LEAVE" then
			break
		end
		serve(c)
	end
end

-- Scenes ----------------------------------------------------------------------------------------------------
local function tutorialCustomer()
	for _, c in r.ai.customers do
		if c.scripted then
			return c
		end
	end
	return nil
end

-- 1. First join: the tutorial asks for a free mutation
Engine.moveTo(player, r.layout.kitchenSpawn.Position, at(-2, 3.5, 30))
shot("01_first_join_mutation_pick", behind(11, 5))
clickText("Pick") -- first card: Octopus Arm
Engine.advance(0.5)

-- 2. The tutorial customer arrives; the arrow points at them
waitFor(function()
	local c = tutorialCustomer()
	return c and c.state == "ORDER"
end, 60)
local c1 = tutorialCustomer()
faceCustomer(c1, 6)
Engine.advance(0.3)
shot("02_tutorial_take_order", twoShot(c1, 13, 7))
takeOrder(c1)
Engine.advance(0.5)

-- 3. Pantry (tutorial step: grab a patty), recipe card on the right
use(st().STN_PANTRY.PrimaryPart)
shot("03_pantry", behind(9, 4, 2))
clickText(Ingredients.ING_BEEF_PATTY.name)
Engine.advance(0.3)

-- 4. Patty on the grill, the arrow says take it off when green
use(st().STN_GRILL.PrimaryPart)
Engine.advance(8.3)
standAt(st().STN_GRILL.PrimaryPart, 5)
shot("04_grill", behind(8, 5, 1.5))
use(st().STN_GRILL.PrimaryPart)
use(st().STN_ASSEMBLY.Board1, "Add")
pick("ING_BUN")
use(st().STN_ASSEMBLY.Board1, "Add")

-- 5. Chopping a pickle (tutorial step), recipe card ticking off the burger
pick("ING_PICKLE")
use(st().STN_CUT.PrimaryPart)
Engine.advance(0.44)
Engine.fireServer(player, "ChopTap")
Engine.advance(0.44)
Engine.fireServer(player, "ChopTap")
Engine.advance(0.2)
shot("05_chopping", behind(8, 4.5, 2))
Engine.advance(0.24)
Engine.fireServer(player, "ChopTap")
Engine.advance(0.44)
Engine.fireServer(player, "ChopTap")
Engine.advance(0.1)
use(st().STN_ASSEMBLY.Board1, "Add")
pick("ING_LETTUCE")
chop()
use(st().STN_ASSEMBLY.Board1, "Add")
pick("ING_KETCHUP")
use(st().STN_ASSEMBLY.Board1, "Add")
Engine.advance(0.5)

-- 6. The finished stack: "Plate Basic Burger"
standAt(st().STN_ASSEMBLY.Board1, 4)
shot("06_assembly", behind(8, 6, -2))
use(st().STN_ASSEMBLY.Board1, "Plate")
Engine.advance(0.5)

-- 7. Serving the tutorial customer
faceCustomer(c1, 4)
Engine.advance(0.3)
shot("07_serving", twoShot(c1, 11, 6))
serve(c1)
Engine.advance(0.5)
shot("08_served", twoShot(c1, 12, 7))
Engine.advance(11) -- tutorial wraps up

-- Play for a while: serve everyone, capture the drink station on the way
local tookPour = false
local served = 1
while Engine.now() < 900 and served < 10 do
	local waiting = customers("ORDER")
	if #waiting > 0 then
		local c = waiting[1]
		takeOrder(c)
		for _, item in c.order.items do
			local recipe = Recipes.byId[item.recipeId]
			if recipe.drink and not tookPour then
				use(st().STN_DRINK.PrimaryPart)
				Engine.advance(1.9)
				shot("09_pouring_a_drink", behind(8, 4.5, 2))
				Engine.advance(0.75)
				Engine.fireServer(player, "PourStop")
				Engine.advance(0.05)
				tookPour = true
			else
				cook(item.recipeId, item.omit)
			end
			if c.state == "LEAVE" then
				break
			end
			serve(c)
		end
		served += 1
	else
		Engine.advance(1, 1 / 15)
	end
end

local function seated()
	return #customers("WAIT_FOOD") + #customers("TO_SEAT")
end
-- take orders as guests arrive, without cooking yet
local function seatGuests(n, maxSeconds)
	local t0 = Engine.now()
	while seated() < n and Engine.now() - t0 < maxSeconds do
		local waiting = customers("ORDER")
		if #waiting > 0 then
			takeOrder(waiting[1])
		end
		Engine.advance(0.5, 1 / 15)
	end
end

multitask = true
while profile.level < 2 and Engine.now() < 4000 do
	takeWaitingOrders()
	local c = nextHungry()
	if c then
		serveNextItem(c)
	else
		Engine.advance(1, 1 / 15)
	end
end
multitask = false

-- 10. A lunch rush: several orders taken, the dining room fills up
seatGuests(3, 400)
Engine.advance(3)
Engine.moveTo(player, at(2, 3.5, -4), at(-8, 3.5, -12))
shot("10_dining_room", at(26, 20, -16), at(-8, 1, -10), 60)

-- 11. A forgotten patty catches fire while the rush waits
pick("ING_BEEF_PATTY")
use(st().STN_GRILL.PrimaryPart)
Engine.advance(25)
standAt(st().STN_GRILL.PrimaryPart, 6)
shot("11_grill_fire", behind(8, 5, 2))
use(st().STN_GRILL.PrimaryPart, "Put out fire")

-- 12-17. Nobody gets fed: anger, thrown food, smashed tables, a fight
local tookFood, tookFight, tookDizzy, tookKO, brokenPart = false, false, false, false, nil
local t0 = Engine.now()
Engine.moveTo(player, at(8, 3.5, 0), at(-6, 3.5, -12))
while Engine.now() - t0 < 9000 and not (tookFood and tookFight and brokenPart) do
	local waiting = customers("ORDER")
	if #waiting > 0 then
		takeOrder(waiting[1])
		Engine.moveTo(player, at(8, 3.5, 0), at(-6, 3.5, -12))
	end
	Engine.advance(0.25, 1 / 15)
	if not tookFood then
		-- wait for one of our own customers to throw (neighbours' customers throw too)
		local e = Engine.lastClientEvent("Projectile")
		if e and e.at > Engine.now() - 0.3 then
			for _, c in customers() do
				if (c.pos + V3.new(0, 2, 0) - e.args[1]).Magnitude < 1 then
					Engine.advance(0.45)
					shot("12_food_fight", twoShot(c, 14, 8))
					tookFood = true
					break
				end
			end
		end
	end
	for _, part in r.layout.model.Dining:GetChildren() do
		if not brokenPart and (part:GetAttribute("Durability") or 100) <= 50 then
			brokenPart = part
		end
	end
	if not tookKO and Combat:IsKO(player) then
		Engine.advance(0.5)
		shot("21_knocked_out", behind(10, 6))
		tookKO = true
	end
	local chaser = customers("CHASE")[1]
	if chaser and not tookFight then
		-- fight back with the real client input (click), facing the attacker
		for i = 1, 60 do
			if chaser.state ~= "CHASE" then
				break
			end
			faceCustomer(chaser, 3)
			Engine.game
				:GetService("UserInputService").InputBegan
				:Fire({ UserInputType = Engine.Enum.UserInputType.MouseButton1 }, false)
			Engine.advance(0.36)
			if i == 5 then
				shot("13_fight", twoShot(chaser, 11, 6))
				tookFight = true
			end
		end
		if chaser.state == "DIZZY" and not tookDizzy then
			Engine.advance(0.3)
			shot("14_dizzy", twoShot(chaser, 11, 6))
			tookDizzy = true
		end
	end
end
if brokenPart then
	Engine.moveTo(player, brokenPart.Position + V3.new(0, 1, 5), brokenPart.Position)
	shot("16_broken_table_repair", behind(9, 5, 2))
	local p = promptOn(brokenPart, "Repair")
	if p then
		p.Triggered:Fire(player)
	end
end
-- feed whoever is still around
for _, c in customers() do
	if c.state == "WAIT_FOOD" and c.order then
		for _, item in c.order.items do
			if not item.served and c.state == "WAIT_FOOD" then
				cook(item.recipeId, item.omit)
				serve(c)
			end
		end
	end
end
Engine.advance(5)

-- Keep playing until level 5 and 1,000 MB, then upgrade
local tookStats = false
multitask = true
while (profile.level < 5 or profile.mb < 1100) and Engine.now() < 20000 do
	takeWaitingOrders()
	local c = nextHungry()
	if c then
		serveNextItem(c)
	else
		Engine.advance(1, 1 / 15)
	end
	if not tookStats and profile.statPoints >= 4 then
		Engine.moveTo(player, r.layout.kitchenSpawn.Position, at(-2, 3.5, 30))
		clickText("Stats")
		shot("15_stats_panel", behind(11, 5))
		clickText("+")
		clickText("✕")
		tookStats = true
	end
end
multitask = false
for _, c in customers() do
	if c.state ~= "LEAVE" then
		service("CustomerAIService"):_leave(c) -- closing time: let the room empty before the upgrade
	end
end
waitFor(function()
	return #customers() == 0
end, 120)
for _, c in customers() do
	service("CustomerAIService"):_remove(c)
end
Engine.moveTo(player, r.layout.kitchenSpawn.Position, at(-2, 3.5, 30))
clickText("Menu")
shot("17_menu", behind(11, 5))
clickText("✕")
clickText("Upgrade")
shot("18_upgrade_panel", behind(11, 5))
clickText("UPGRADE!")
Engine.advance(0.5)
r = Restaurant:Get(player)

-- 20. The Tiny Mutation Diner with its first customers
seatGuests(4, 600)
Engine.advance(3)
Engine.moveTo(player, at(4, 3.5, -3), at(-6, 3.5, -12))
shot("19_tiny_mutation_diner", at(24, 30, -42), at(-2, 0, -2), 55)

-- 21. Street view at the end
shot("20_restaurant_row", at(-60, 60, -130), at(-80, 0, 5), 50)

do
	local tally = {}
	for _, e in Engine.clientLog do
		if e.name == "Popup" and type(e.args[2]) == "string" and not e.args[2]:match("^[%-%+%d]") then
			tally[e.args[2]] = (tally[e.args[2]] or 0) + 1
		end
	end
	for k, v in tally do
		print("  popup", k, v)
	end
end
print(
	string.format(
		"%d shots · %d script errors · served %d · level %d · %d MB",
		#shots,
		#Engine.errors,
		profile.lifetime.served,
		profile.level,
		profile.mb
	)
)
writeFile(outDir .. "/index.json", HttpService:JSONEncode(shots))

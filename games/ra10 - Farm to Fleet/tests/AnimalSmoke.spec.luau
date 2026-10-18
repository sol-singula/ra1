--[[
Phase C on the mock engine, server and client together: stage 2 (the Farm) and the animals. The barn takes the
place of its site; the fields add tiles up to 39; the chicken coop arrives with hungry chickens, the guide leads to
feeding them at the pad (crops from the basket), they lay eggs that collect into the basket and sell at the stand;
chickens make crops grow faster, pigs make vegetables pay more, sheep speed the machines, cows the fruit; levels cost
Cash, grow the boost, the herd and the look; the tractor harvests and replants on its own, the conveyor sells on its
own; the windmill turns and the animals wander (on the client); the packing shed's deed opens stage 3; leaving and
coming back keeps every animal.

  luaurun tests/AnimalSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local typeof = Engine.globals.typeof

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
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.5)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Plots = service("PlotService")
local Farm = service("FarmService")
local Upg = service("UpgradeService")
local Animal = service("AnimalService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Animals = Engine.require(tree.shared.Data.Animals)
local Crops = Engine.require(tree.shared.Data.Crops)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)

local function stand(p, pos)
	Engine.moveTo(p, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.6)
end
local function away(p)
	local plot = Plots:Plot(p)
	stand(p, PlotLayout.toWorld(plot.index, 40, -100))
end

local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
local AnimalC = Engine.require(tree.client.Controllers.AnimalController)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades[key].cost + 10)
	while (p.level or 1) < Upgrades[key].level do
		Economy:AddXP(player, 200, "test")
	end
	return Upg:Buy(player, key)
end
away(player)
for _, key in Upgrades.LIST do
	if Upgrades[key].stage == 1 then
		buy(key)
	end
end
check("stage 1 done: stage 2 opens", p.stage == 2)
-- (chapter 1 of the guide is done, as it is for anyone who got here by playing)
local GuideData = Engine.require(tree.shared.Data.Guide)
p.guide.step = GuideData.byKey.bigBarn.index

-- The barn and the fields ---------------------------------------------------------------------------------------------
check("the barn site's sign stands", plot.items:FindFirstChild("barnDeed") ~= nil)
check("buy The Big Barn", buy("barn"))
check(
	"...it stands where the site was",
	plot.items:FindFirstChild("barn") ~= nil and plot.items:FindFirstChild("barnDeed") == nil
)
check("...a bigger basket", Farm:Carry(player) == 150, Farm:Carry(player))
check("buy the Corn Field", buy("field1"))
check("...nine more tiles", Farm:Tiles(player)[21] ~= nil and not Farm:Tiles(player)[22])
do
	local out = {}
	for n = 13, 21 do
		local t = PlotLayout.soilTile(n)
		if t.X < -78 or t.X > -8 or t.Z < -51 or t.Z > -26 then
			table.insert(out, n)
		end
	end
	check("...in the field, inside its fence", #out == 0, table.concat(out, ","))
end
-- plant corn (level 4 by now) so the guide moves on
stand(player, Farm:Tiles(player)[13].Position + Vector3.new(0, 0, -4))
Farm:Plant(player, 14, "corn")
Engine.advance(1.2)

-- The chicken coop: hungry chickens, feeding, eggs -------------------------------------------------------------------
away(player)
check("buy the Chicken Coop", buy("chickenCoop"))
local pens = Animal:Pens(player)
check("...the pen and its pad", pens.chicken ~= nil and pens.chicken.pad ~= nil)
check("...a chicken in it", pens.chicken and #pens.chicken.herd:GetChildren() == 1)
check(
	"...it arrives hungry",
	p.animals.chicken and not Animals.fed(p.animals.chicken, Engine.workspace:GetServerTimeNow())
)
Engine.advance(1.2)
check("the guide: feed them at the coop's pad", GuideC.state().key == "feed", GuideC.state().key)
check(
	"...pointing at the pad",
	typeof(GuideC.state().target) == "Vector3" and (GuideC.state().target - pens.chicken.pad.Position).Magnitude < 0.1
)
table.clear(p.storage)
stand(player, pens.chicken.pad.Position)
check("an empty basket can't feed them", not Animals.fed(p.animals.chicken, Engine.workspace:GetServerTimeNow()))
check("...the pen's panel opens", AnimalC.state().at == "chicken" and AnimalC.refs.panel.Visible)
check("...it says they're hungry", AnimalC.refs.fed.Text:find("Hungry") ~= nil, AnimalC.refs.fed.Text)
away(player)
p.storage.strawberry = 8
stand(player, pens.chicken.pad.Position)
check(
	"with crops in the basket the pad feeds them",
	Animals.fed(p.animals.chicken, Engine.workspace:GetServerTimeNow())
)
check("...five crops eaten", p.storage.strawberry == 3, p.storage.strawberry)
check("...the panel says fed", AnimalC.refs.fed.Text:find("Fed") ~= nil, AnimalC.refs.fed.Text)
check("the guide: collect eggs", GuideC.state().key == "eggs", GuideC.state().key)
away(player)
Engine.advance(Animals.chicken.every + 1)
check("they lay eggs", (p.animals.chicken.ready or 0) >= 1, p.animals.chicken.ready)
stand(player, pens.chicken.pad.Position)
check("the pad collects them into the basket", (p.storage.egg or 0) >= 1 and p.animals.chicken.ready == 0)
local refs = Plots:Refs(player)
local before = p.cash
local worth = Farm:Worth(player)
stand(player, refs.standPad.Position)
check(
	"eggs sell at the stand (plus the guide's reward for it)",
	p.cash - before >= worth and (p.stats.soldProducts or 0) >= 1,
	p.cash - before
)
away(player)

-- Boosts ------------------------------------------------------------------------------------------------------------
local now = Engine.workspace:GetServerTimeNow()
check("chickens: crops grow faster", Animals.boost(p, "grow", now) > 0)
p.soil["2"] = nil
Farm:Plant(player, 2, "strawberry")
local need = p.soil["2"].need
check("...a planted crop needs less time", need < Crops.strawberry.grow * Crops.WATER_CUT, need)
p.cash = 10 ^ 6
stand(player, pens.chicken.pad.Position)
local fedLevel = p.animals.chicken.level
AnimalC.refs.upgrade.Activated:Fire()
Engine.advance(0.5)
check("UPGRADE on the panel levels them up", p.animals.chicken.level == fedLevel + 1)
check(
	"...a bigger boost",
	Animals.boost(p, "grow", Engine.workspace:GetServerTimeNow()) > Animals.boost(p, "grow", now) - 0.0001
		and p.animals.chicken.level == 2
)
Animal:Upgrade(player, "chicken")
check("level 3: a second chicken", #pens.chicken.herd:GetChildren() == Animals.count(3) and Animals.count(3) == 2)
for _ = 1, 10 do
	Animal:Upgrade(player, "chicken")
end
check("they stop at level 10", p.animals.chicken.level == Animals.MAX_LEVEL)
check(
	"...with a ribbon and a golden bell",
	(function()
		for _, m in pens.chicken.herd:GetChildren() do
			if m:FindFirstChild("Bell") and m:FindFirstChild("Ribbon") then
				return true
			end
		end
		return false
	end)()
)
away(player)

-- The machines --------------------------------------------------------------------------------------------------------
check("buy the Tractor", buy("tractor"))
check("...it's parked on the farm", plot.items.tractor:FindFirstChild("Tractor") ~= nil)
for n = 1, 21 do
	p.soil[tostring(n)] = nil
end
table.clear(p.storage)
for n = 1, 4 do
	Farm:Plant(player, n, "strawberry")
end
Engine.advance(Crops.strawberry.grow + Upgrades.tractor.value + 1)
check("the tractor harvests what's ripe", Farm:Carried(player) >= 4, Farm:Carried(player))
check("...and plants again", p.soil["1"] ~= nil and p.soil["13"] ~= nil)
check("buy the Big Field", buy("field2"))
check("buy the Conveyor Belt", buy("conveyor"))
local cashBefore = p.cash
p.storage.carrot = 10
Engine.advance(Upgrades.conveyor.value + 1)
check("the conveyor sells the basket", p.cash > cashBefore and Farm:Carried(player) < 10, p.cash - cashBefore)
do
	-- (on its way it calls at the coop: the eggs collected and sold, the hungry chickens fed)
	local st = p.animals.chicken
	st.ready, st.fedAt = 4, 0
	local eggs = p.stats.eggs or 0
	p.storage.carrot = 10
	Engine.advance(Upgrades.conveyor.value + 1)
	check("the conveyor collects the eggs", (p.stats.eggs or 0) >= eggs + 4 and st.ready <= 1, `{p.stats.eggs} {eggs} {st.ready}`)
	check("...feeds the chickens from the basket", st.fedAt > 0)
	check("...and sells it all", Farm:Carried(player) == 0, Farm:Carried(player))
end

-- Pigs, sheep, cows ---------------------------------------------------------------------------------------------------
table.clear(p.storage)
p.storage.carrot = 10
local plain = Farm:Worth(player)
check("buy the Pig Pen", buy("pigPen"))
p.animals.pig.fedAt = Engine.workspace:GetServerTimeNow()
check("pigs: vegetables pay more", Farm:Worth(player) > plain, `{Farm:Worth(player)} vs {plain}`)
table.clear(p.storage)
p.storage.strawberry = 10
local fruit = Farm:Worth(player)
p.animals.pig.level = 10
check("...but not fruit", Farm:Worth(player) == fruit)
table.clear(p.storage)
for _, key in { "silo", "field3", "sheepPen", "windmill", "cowBarn" } do
	check(`buy {key}`, buy(key))
end
check("39 tiles", Farm:Tiles(player)[39] ~= nil)
check("a basket of 300", Farm:Carry(player) == 300)
check(
	"four pens, four herds",
	Animal:Pens(player).pig
		and Animal:Pens(player).sheep
		and Animal:Pens(player).cow
		and #Animal:Pens(player).cow.herd:GetChildren() == 1
)
now = Engine.workspace:GetServerTimeNow()
p.animals.sheep.fedAt, p.animals.cow.fedAt = now, now
check("sheep: machines faster", Animals.boost(p, "machine", now) > 0)
p.soil["30"], p.soil["31"] = nil, nil
Farm:Plant(player, 30, "strawberry")
Farm:Plant(player, 31, "carrot")
local fruitNeed = p.soil["30"].need / Crops.strawberry.grow
local vegNeed = p.soil["31"].need / Crops.carrot.grow
check("cows: fruit grows faster than vegetables", fruitNeed < vegNeed, `{fruitNeed} vs {vegNeed}`)
check("...and a little golden luck", Farm.goldenChance(p) > Crops.GOLDEN_CHANCE + 0.03)

-- The world on the client: wandering animals, the windmill ---------------------------------------------------------------
Engine.advance(3)
check("the animals wander (on the client)", AnimalC.walkers() >= 4, AnimalC.walkers())
local cow = Animal:Pens(player).cow.herd:GetChildren()[1]
local from = cow:GetPivot().Position
Engine.advance(6)
check("...they move", (cow:GetPivot().Position - from).Magnitude > 0.5)
local mn, mx = cow:GetAttribute("PenMin"), cow:GetAttribute("PenMax")
local at = cow:GetPivot().Position
check("...inside their pen", at.X >= mn.X - 0.5 and at.X <= mx.X + 0.5 and at.Z >= mn.Z - 0.5 and at.Z <= mx.Z + 0.5)
local hub = plot.items.windmill:FindFirstChild("WindmillHub")
local turned = hub.CFrame
Engine.advance(1)
check("the windmill turns", (hub.CFrame.UpVector - turned.UpVector).Magnitude > 0.01)

-- On to stage 3 ---------------------------------------------------------------------------------------------------------
check("the packing shed's deed", buy("shedDeed"))
check("...stage 3", p.stage == 3)
check("...its site staked out", plot.items:FindFirstChild("shedDeed") ~= nil)

-- Leaving and coming back keeps the animals ---------------------------------------------------------------------------
Engine.removePlayer(player)
Engine.advance(0.5)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(1.5)
local p2 = Data:Get(again)
check("coming back: the animals' levels", p2.animals.chicken.level == 10 and p2.animals.pig.level == 10)
check(
	"...the pens and herds rebuilt",
	Animal:Pens(again).cow ~= nil and #Animal:Pens(again).chicken.herd:GetChildren() == Animals.count(10)
)

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`AnimalSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end

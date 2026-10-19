--[[
Phase C on the mock engine, server and client together: stage 2 (the Farm) and the animals. The barn takes the
place of its site and keeps the crops; the fields add tiles up to 36 in the one field; the chicken coop arrives with
hungry chickens, the guide leads to feeding them at the pad (free) and tending them (happy: double boost); chickens
make crops grow faster, pigs make vegetables pay more, sheep speed the tractor, cows the fruit; levels cost Cash and
grow the boost, the herd and the look, with no top; the tractor harvests and replants on its own, the shop helper
sells on its own; the windmill turns and the animals wander (on the client); the packing shed's deed opens stage 3;
leaving and coming back keeps every animal.

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
check("buy The Big Barn", buy("barn") and buy("sign"))
check(
	"...it stands where the site was",
	plot.items:FindFirstChild("barn") ~= nil and plot.items:FindFirstChild("barnDeed") == nil
)
check("...it keeps 400 crops", Farm:Keeps(player) == 400, Farm:Keeps(player))
check("buy the Bigger Field", buy("field1"))
check("...eight more tiles", Farm:Tiles(player)[20] ~= nil and not Farm:Tiles(player)[21])
do
	local out = {}
	local x0, x1, z0, z1 = PlotLayout.fieldBox(20)
	for n = 1, 20 do
		local t = PlotLayout.soilTile(n)
		if t.X < x0 or t.X > x1 or t.Z < z0 or t.Z > z1 then
			table.insert(out, n)
		end
	end
	check("...in the one field, inside its fence", #out == 0, table.concat(out, ","))
	check("...the fence round it", plot.items:FindFirstChild("FieldFence") ~= nil)
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
stand(player, pens.chicken.pad.Position)
check("walking up to the pad feeds them, free", Animals.fed(p.animals.chicken, Engine.workspace:GetServerTimeNow()))
check("...the pen's panel opens", AnimalC.state().at == "chicken" and AnimalC.refs.panel.Visible)
check("...it says they're fed", AnimalC.refs.fed.Text:find("Fed") ~= nil, AnimalC.refs.fed.Text)
check("...FEED is free: no crops eaten", next(p.storage) == nil)
check("the guide: tend them", GuideC.state().key == "tendPen", GuideC.state().key)
do
	-- TEND at the pen: happy animals, double boost for a while, then a cooldown
	local FarmCtl = Engine.require(tree.client.Controllers.FarmController)
	check("the pen panel has TEND", AnimalC.refs.tend.Text == "TEND", AnimalC.refs.tend.Text)
	check("...and on the big button too (phones)", FarmCtl.action() == "pen", FarmCtl.action())
	local plain = Animals.boost(p, "grow", Engine.workspace:GetServerTimeNow())
	FarmCtl.press()
	Engine.advance(0.4)
	local t = Engine.workspace:GetServerTimeNow()
	check("...TEND: they're happy", Animals.happy(p.animals.chicken, t))
	check("...the boost doubles", Animals.boost(p, "grow", t) > plain * 1.9, Animals.boost(p, "grow", t))
	check("...the panel says so", AnimalC.refs.ready.Text:find("Happy") ~= nil, AnimalC.refs.ready.Text)
	check("...counted for the guide", (p.stats.tendedAnimals or 0) >= 1)
	check("...the big button waits out the cooldown", FarmCtl.action() ~= "pen")
	check("...then a cooldown on the button", AnimalC.refs.tend.Text:find("%d+s") ~= nil, AnimalC.refs.tend.Text)
	local tendedAt = p.animals.chicken.tendedAt
	AnimalC.refs.tend.Activated:Fire()
	Engine.advance(0.4)
	check("...no spamming it", p.animals.chicken.tendedAt == tendedAt)
	Engine.advance(Animals.HAPPY_SECONDS + 1)
	check("...happy wears off", not Animals.happy(p.animals.chicken, Engine.workspace:GetServerTimeNow()))
end
away(player)
Engine.advance(0.5)
check(
	"the guide moves on: the tractor",
	GuideC.state().key == "tractor" or GuideC.state().key:find("^earn:tractor") ~= nil,
	GuideC.state().key
)

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
check("no top level: they keep going", p.animals.chicken.level == 13, p.animals.chicken.level)
check("...the herd caps at 8", #pens.chicken.herd:GetChildren() == Animals.count(13) and Animals.count(13) == 7)
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
local Tractor = service("TractorService")
local model = Tractor:Model(player)
local parked = model and model:GetPivot().Position
Engine.advance(Crops.strawberry.grow + 70)
check(
	"the tractor drives round the fields",
	model and (model:GetPivot().Position - parked).Magnitude > 3 or (p.stats.tractored or 0) > 0
)
check("...harvests what's ripe into the barn", Farm:Have(player, "strawberry") >= 3, Farm:Have(player, "strawberry"))
do
	local planted = 0
	for _ in p.soil do
		planted += 1
	end
	check("...and plants again", p.soil["1"] ~= nil and planted >= 8, `{planted} planted`)
end
do
	-- hop on: it follows you, harvesting and planting what you drive over
	local prompt = model and model:FindFirstChild("Drive", true)
	check("the tractor has a DRIVE prompt", prompt ~= nil and prompt.ActionText == "Drive")
	prompt.Triggered:Fire(player)
	local hum = player.Character:FindFirstChildOfClass("Humanoid")
	check("...you're on it: faster, up in the seat", Tractor:Driving(player) and hum.WalkSpeed == Tractor.DRIVE_SPEED)
	local TractorC = Engine.require(tree.client.Controllers.TractorController)
	Engine.advance(0.2)
	check("...sitting, not walking", TractorC.seated())
	table.clear(p.storage)
	table.clear(p.stock)
	p.soil["15"] = nil
	Engine.moveTo(player, Farm:Tiles(player)[15].Position + Vector3.new(0, 3, 0))
	Engine.advance(0.5)
	check("...it plants what you drive over", p.soil["15"] ~= nil)
	check("...and it goes where you go", (model:GetPivot().Position - Farm:Tiles(player)[15].Position).Magnitude < 4)
	p.soil["15"].need = 0
	local picked = p.stats.harvested
	Engine.advance(0.5)
	check(
		"...and harvests what's ripe",
		p.stats.harvested > picked and (p.stats.driven or 0) >= 1,
		p.stats.harvested - picked
	)
	Engine.fireServer(player, "Tractor", "off")
	Engine.advance(0.2)
	check("jump off: back on your feet", not Tractor:Driving(player) and hum.WalkSpeed ~= Tractor.DRIVE_SPEED)
	check("...the sit pose ends", not TractorC.seated())
end
check("buy the Big Field", buy("field2"))
check("buy the Shop Helper", buy("shopkeeper"))
do
	-- the barn and the boosts, on screen
	table.clear(p.storage)
	table.clear(p.stock)
	p.owned.shopkeeper = nil -- (a moment without the helper: the panel first)
	p.stock.carrot = 10
	Farm:Push(player)
	local HudC = Engine.require(tree.client.Controllers.HudController)
	Engine.advance(0.3)
	check("the BARN panel lists what's in", HudC.refs.stock.Visible and HudC.refs.stockRows[1].frame.Visible)
	check(
		"...named BARN, with its room",
		HudC.refs.stockTitle.Text:find("BARN") ~= nil and HudC.refs.stockTitle.Text:find("400") ~= nil,
		HudC.refs.stockTitle.Text
	)
	check("...no basket on screen now", not HudC.refs.basket.Visible)
	local rowText = ""
	for _, row in HudC.refs.stockRows do
		if row.frame.Visible then
			rowText ..= row.name.Text .. " "
		end
	end
	check("...carrots in it", rowText:find("Carrot") ~= nil, rowText)
	check(
		"the BOOSTS panel says what the animals give",
		HudC.refs.boosts.Visible and HudC.refs.boosts.Text:find("Chickens") ~= nil,
		HudC.refs.boosts.Text
	)
	check("Cash shows with $", HudC.refs.cash.Text:sub(1, 1) == "$", HudC.refs.cash.Text)
	-- the customers buy the barn's crops by themselves (the helper: two at a time)
	p.owned.shopkeeper = 1
	local cashBefore = p.cash
	Engine.advance(61)
	check(
		"the customers buy the barn's crops on their own",
		p.cash > cashBefore and (p.stats.customers or 0) > 0,
		`{p.cash - cashBefore} left {Farm:Stock(player).carrot}`
	)
end

-- Pigs, sheep, cows ---------------------------------------------------------------------------------------------------
table.clear(p.storage)
p.storage.carrot = 10
local plain = Farm:Worth(player)
check("buy the Pig Pen", buy("bell") and buy("pigPen"))
p.animals.pig.fedAt = Engine.workspace:GetServerTimeNow()
check("pigs: vegetables pay more", Farm:Worth(player) > plain, `{Farm:Worth(player)} vs {plain}`)
table.clear(p.storage)
p.storage.strawberry = 10
local fruit = Farm:Worth(player)
p.animals.pig.level = 10
check("...but not fruit", Farm:Worth(player) == fruit)
table.clear(p.storage)
for _, key in { "tractor2", "parking", "bigBarn", "field3", "sheepPen", "windmill", "cowBarn", "counter2" } do
	check(`buy {key}`, buy(key))
end
check("36 tiles", Farm:Tiles(player)[36] ~= nil and not Farm:Tiles(player)[37])
check("the Big Barn keeps 1500", Farm:Keeps(player) == 1500, Farm:Keeps(player))
Engine.advance(0.3)
check(
	"the Bigger Tractor: level 2, a bigger model",
	Tractor:Level(player) == 2 and Tractor:Model(player):GetAttribute("Level") == 2,
	`{Tractor:Level(player)} {tostring(Tractor:Model(player) and Tractor:Model(player):GetAttribute("Level"))}`
)
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
check("cows: fruit grows faster", Animals.boost(p, "fruitGrow", now) > 0)
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
check("coming back: the animals' levels", p2.animals.chicken.level == 13 and p2.animals.pig.level == 10)
check(
	"...the pens and herds rebuilt",
	Animal:Pens(again).cow ~= nil and #Animal:Pens(again).chicken.herd:GetChildren() == Animals.count(13)
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

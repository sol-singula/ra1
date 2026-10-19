--[[
The things to do while the money comes in, and the stock you can see: animals bought on their pen's pad (the pen
is built, they arrive fed and boost the farm), hunger halving the boost, the feed plate feeding and then petting
(happy: the boost doubled), the golden crop paying many times a sale (and the machines leaving it alone), and a
full stock area stopping the harvesters.

  luaurun tests/AnimalSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")

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
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Upg = service("UpgradeService")
local Crops = service("CropService")
local Business = service("BusinessService")
local AnimalS = service("AnimalService")
local Auto = service("AutomationService")
local Pads = service("PadService")
local Territory = service("TerritoryService")
local Animals = Engine.require(tree.shared.Data.Animals)
local Layout = Engine.require(tree.shared.World.Layout)
local now = Engine.globals.os.time

local player = Engine.addPlayer("Ivy", 5501)
Engine.advance(3)
local p = Data:Get(player)
local t = Territory:Territory(player)
p.task.done = true

-- The chickens' pad is at their pen
Engine.advance(2.5)
local slot
for k, key in Pads:Shown(player) do
	if key == "chicken" then
		slot = k
	end
end
check("the chickens' pad is at their pen", slot == 8 + 1, slot)
local grow0 = Crops:GrowthMult(player)
p.cash = 1000
local pad = Layout.PENS.chicken.pad
Engine.moveTo(player, Layout.toWorld(t.index, pad.x, pad.z, 3))
Engine.advance(0.6)
check("stepping on it buys the chickens", (p.owned.chicken or 0) == 1, p.owned.chicken)
local pen = t.model.Pens:FindFirstChild("Pen1")
check(
	"...the pen is built with its herd and feed plate",
	pen and pen:FindFirstChild("Herd") and pen:FindFirstChild("FeedPlate") ~= nil
)
check("...they arrive fed: the boost is on", Crops:GrowthMult(player) > grow0 + 0.04, Crops:GrowthMult(player))
local st = AnimalS:State(player).chicken
check("...the state says fed", st and st.fed and st.level == 1)

-- Hunger
p.animals.chicken.fedAt = now() - Animals.FED_SECONDS - 1
check("hungry chickens give less", Animals.boost(p, "grow", now()) < 0.05 * 0.5, Animals.boost(p, "grow", now()))
check(
	"...and the guide says feed them",
	(function()
		Engine.advance(1.2)
		local pr = service("TaskService"):Primary(player)
		return pr.kind == "feed" or pr.kind == "golden" or pr.kind == "upgrade"
	end)()
)
-- The feed plate: feed, then step off and on: pet
local fp = Layout.PENS.chicken.feed
Engine.moveTo(player, Layout.toWorld(t.index, fp.x, fp.z, 3))
Engine.advance(0.6)
check("the feed plate feeds them", AnimalS:State(player).chicken.fed and (p.stats.fed or 0) >= 1)
Engine.moveTo(player, Layout.toWorld(t.index, 0, -60, 3))
Engine.advance(0.6)
p.animals.chicken.pettedAt = 0
Engine.moveTo(player, Layout.toWorld(t.index, fp.x, fp.z, 3))
Engine.advance(0.6)
check("...stepping on again pets them: happy", AnimalS:State(player).chicken.happy, (p.stats.petted or 0))
check(
	"...happy doubles the boost",
	math.abs(Animals.boost(p, "grow", now()) - 0.05 * p.owned.chicken * Animals.HAPPY_MULT) < 0.001,
	`{Animals.boost(p, "grow", now())} lv {p.owned.chicken} share {Animals.share(p.animals.chicken, now())}`
)

-- The golden crop
Crops:PlantAll(player)
p.stats.harvested = 5
local g
for _ = 1, 400 do
	Engine.advance(0.5)
	g = Crops:Golden(player)
	if g then
		break
	end
end
check("a golden crop appears", g ~= nil)
local cash0 = p.cash
local paid = g and Crops:TapGolden(player, g) or 0
check("...a tap pays many times a sale", paid >= 10 * 20 and p.cash - cash0 == paid, paid)
check("...and it's gone", Crops:Golden(player) == nil)

-- A full stock area stops the machines
p.owned.harvester = 1
p.owned.seeder = 1
local cap = Business:Capacity(player)
p.stock.strawberry = cap
for _, id in Crops:Tiles(player) do
	p.tiles[id] = { crop = "strawberry", at = now() - 100 }
end
local h0 = p.stats.harvested
-- (a few machine ticks, kept full: a customer may take a basket meanwhile)
for _ = 1, 6 do
	p.stock.strawberry = cap
	Engine.advance(0.5)
end
check(
	"a full stock area: the machine waits",
	p.stats.harvested == h0 and Business:Full(player),
	`{p.stats.harvested - h0} {Business:Stock(player)}/{Business:Capacity(player)}`
)
check("...the bottleneck is selling", Business:Bottleneck(player) == "service", Business:Bottleneck(player))
p.stock.strawberry = 0
Engine.advance(2)
check("...room again: it works", p.stats.harvested > h0, p.stats.harvested - h0)

-- No adverts: customers come as fast as the counter serves
local n = Business:Numbers(player)
check("customers come as fast as the counter serves", n.demand == n.service, `{n.demand} {n.service}`)

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

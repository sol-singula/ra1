--[[
The guided first minutes on the mock engine (ra9's way): the short tour of the farm for a brand-new farmer
(letterbox, 1 PLANT / 2 SELL / 3 BUY, SKIP), the numbered step card (STEP 1, CHAPTER 1 · THE SHACK, 1/20), the
beam and ring on the spot, the PLANT button pulsing when the step needs it, STEP 1 DONE! when it's done, the stage-1
loop all within a few steps (soil, SELL, the pads), GO for a far step putting you right there, and the menu staying
clear until the guide reaches it.

  luaurun tests/GuideSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2

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
Engine.runScript(tree.server.Main)
Engine.advance(0.5)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Plots = service("PlotService")
local Farm = service("FarmService")
local Guide = service("GuideService")
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)
local GuideData = Engine.require(tree.shared.Data.Guide)
local SPOTS = PlotLayout.SPOTS

-- On their own ----------------------------------------------------------------------------------------------------------
do
	local s1 = GuideData.byKey.plant1
	check("steps know their chapter and number", s1.chapter == 1 and s1.n == 1 and GuideData.byKey.harvest1.n == 2)
	check("...chapter 2 starts again at 1", GuideData.byKey.bigBarn.chapter == 2 and GuideData.byKey.bigBarn.n == 1)
	check("...a soil step pulses the PLANT button", s1.button == "act" and GuideData.byKey.sell1.button == nil)
	local function d(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end
	local sell = SPOTS.stand + Vector3.new(0, 0, -7.5)
	check("the stage-1 loop is close: spawn to soil", d(SPOTS.spawn, SPOTS.soil) < 36, d(SPOTS.spawn, SPOTS.soil))
	check("...soil to SELL", d(SPOTS.soil, sell) < 30, d(SPOTS.soil, sell))
	check("...SELL to every buy-pad", d(sell, SPOTS.pads[3]) < 34, d(sell, SPOTS.pads[3]))
	check(
		"...the spawn a few steps from SELL and the first pad",
		d(SPOTS.spawn, sell) < 24 and d(SPOTS.spawn, SPOTS.pads[1]) < 14
	)
end

-- A brand-new farmer ------------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 811)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(0.8)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
local FarmC = Engine.require(tree.client.Controllers.FarmController)
local MenuC = Engine.require(tree.client.Controllers.MenuController)
local refs = GuideC.refs
check("a new farmer gets the tour", GuideC.touring() and refs.tour.Visible)
check(
	"...letterboxed, the camera taken",
	Engine.workspace.CurrentCamera.CameraType == Engine.Enum.CameraType.Scriptable
)
Engine.advance(2.5)
check("...1 PLANT CROPS HERE", refs.tourTitle.Text:find("PLANT") ~= nil, refs.tourTitle.Text)
Engine.advance(2.2)
check("...2 SELL THEM HERE", refs.tourTitle.Text:find("SELL") ~= nil, refs.tourTitle.Text)
Engine.advance(2.2)
check("...3 BUY UPGRADES HERE", refs.tourTitle.Text:find("BUY") ~= nil, refs.tourTitle.Text)
Engine.advance(2.5)
check("...and back to the farmer", not GuideC.touring() and not refs.tour.Visible)
check("...the camera given back", Engine.workspace.CurrentCamera.CameraType == Engine.Enum.CameraType.Custom)

check("the step card: STEP 1", refs.card.Visible and refs.badgeTop.Text == "STEP" and refs.badgeNum.Text == "1")
check("...one short instruction", refs.text.Text:find("PLANT") ~= nil, refs.text.Text)
check(
	"...CHAPTER 1 · THE SHACK · 1/n",
	refs.chapter.Text:find("CHAPTER 1") and refs.chapter.Text:find("SHACK") and refs.chapter.Text:find("1/"),
	refs.chapter.Text
)
check("the spot lit: a beam and a ring", refs.beam.Transparency < 1 and refs.ring.Transparency < 1)
local tiles = Farm:Tiles(player)
check(
	"...on the first tile",
	(Vector3.new(refs.ring.Position.X, 0, refs.ring.Position.Z) - Vector3.new(
		tiles[1].Position.X,
		0,
		tiles[1].Position.Z
	)).Magnitude < 0.5
)
check("no GO when it's close", not refs.go.Visible)
check(
	"the menu stays clear for now",
	not MenuC.refs.buttons.calendar.Visible
		and not MenuC.refs.buttons.street.Visible
		and not MenuC.refs.buttons.shop.Visible
)

Engine.moveTo(player, tiles[1].Position + Vector3.new(0, 3, -4))
Engine.advance(0.6)
check("by the soil the PLANT button pulses", FarmC.refs.act.Visible and FarmC.refs.ring.Visible)
FarmC.press()
Engine.advance(0.6)
check("done: STEP 1 DONE!", refs.pay.Visible and refs.payTitle.Text:find("STEP 1 DONE") ~= nil, refs.payTitle.Text)
check("...and STEP 2 pops in", refs.badgeNum.Text == "2")
Engine.advance(2)
check("...the payoff goes", not refs.pay.Visible)

-- A far step: GO ---------------------------------------------------------------------------------------------------------
local p = Data:Get(player)
p.guide.step = GuideData.byKey.sell1.index
Guide:Check(player)
local plot = Plots:Plot(player)
Engine.moveTo(player, PlotLayout.toWorld(plot.index, 60, 80, 3))
Engine.advance(0.6)
check("far from the step's spot: GO", refs.go.Visible)
refs.go.Activated:Fire()
Engine.advance(0.6)
local r = player.Character.HumanoidRootPart
local sell = Plots:Refs(player).standPad.Position
check(
	"GO: right by it",
	(Vector3.new(r.Position.X - sell.X, 0, r.Position.Z - sell.Z)).Magnitude < 8,
	(r.Position - sell).Magnitude
)
check("...no GO now", not refs.go.Visible)
check("...and no GO for a step that's close already", not Guide:Go(player))

-- While it grows: TEND it once (Cash now, faster); a new farmer's crops grow fast and pay well -------------------------
do
	local Crops = Engine.require(tree.shared.Data.Crops)
	local g1, v1 = Crops.starter(1)
	local g7, v7 = Crops.starter(7)
	check("level 1: crops grow 2x and pay 2.5x", g1 == 2 and v1 == 2.5, `{g1} {v1}`)
	check("...fading out by level 7", g7 == 1 and v7 == 1)
	p.soil = {}
	p.stats.harvested = 0
	p.guide.step = GuideData.byKey.harvest1.index
	Farm:Plant(player, 1, "strawberry")
	Farm:Push(player)
	Guide:Check(player)
	Engine.advance(0.3)
	check(
		"tile 1 growing, empty soil next to it: PLANT that meanwhile",
		GuideC.state().text:find("PLANT") ~= nil,
		GuideC.state().text
	)
	Farm:Plant(player, 2, "strawberry")
	Farm:Plant(player, 3, "strawberry")
	Farm:Push(player)
	Guide:Check(player)
	Engine.moveTo(player, tiles[1].Position + Vector3.new(0, 3, -4))
	Engine.advance(0.3)
	check(
		"growing, not ripe: the guide doesn't say HARVEST",
		GuideC.state().text:find("HARVEST") == nil and GuideC.state().text:find("ripe") ~= nil,
		GuideC.state().text
	)
	check("...the button says TEND while it grows", FarmC.action() == "tend" and FarmC.refs.act.Visible, FarmC.action())
	FarmC.paintTimers()
	local timer = FarmC.refs.timers[1]
	check(
		"walk up: a timer over the crop",
		timer and timer.gui.Enabled and timer.label.Text:match("0:0%d$") ~= nil,
		timer and timer.label.Text
	)
	local said = FarmC.inspect(1)
	check(
		"tap a patch: what's growing and how long",
		said and said:find("Strawberry") and said:find("ready in") and FarmC.refs.inspect.Visible,
		said
	)
	check("...an empty one says so", (FarmC.inspect(12) or ""):find("Empty") ~= nil or Farm:Tiles(player)[12] == nil)
	local r1 = p.soil["1"].at + p.soil["1"].need
	local r3 = p.soil["3"].at + p.soil["3"].need
	check("...the field ripens together", math.abs(r1 - r3) < 0.01, r3 - r1)
	Engine.advance(r1 - Engine.workspace:GetServerTimeNow() + 0.5)
	check("...and soon it's ripe: HARVEST", Farm:Ripe(player, 1) and FarmC.action() == "harvest")
	FarmC.paintTimers()
	check("...READY! over it", FarmC.refs.timers[1].label.Text:find("READY!") ~= nil, FarmC.refs.timers[1].label.Text)
	check("...and the guide says so", GuideC.state().text:find("TEND") == nil, GuideC.state().text)
	check("a sale pays the starter price", Farm:Worth(player, { strawberry = 1 }) == Crops.strawberry.value * 2.5)
end

-- Can't afford the step's buy: earn it (sell, or grow) --------------------------------------------------------------------
do
	local Upg = service("UpgradeService")
	local Upgrades = Engine.require(tree.shared.Data.Upgrades)
	p.guide.step = GuideData.byKey.well.index
	p.owned.soil4, p.owned.soil5 = 1, 1
	p.cash = 5
	p.storage = { strawberry = 6 }
	Guide:Check(player)
	Engine.advance(2) -- (the jump here paid off the old step: let that go)
	check(
		"too poor for the well, crops in the basket: SELL",
		GuideC.state().text:find("Sell") ~= nil and refs.badgeNum.Text == tostring(GuideData.byKey.well.n),
		GuideC.state().text
	)
	check("...pointing at the stand", (GuideC.state().target - Plots:Refs(player).standPad.Position).Magnitude < 0.1)
	check("...the bar counts the Cash to the price", refs.chapter.Text:find("%$5 / %$30") ~= nil, refs.chapter.Text)
	p.storage = {}
	Guide:Check(player)
	Engine.advance(0.5)
	check(
		"...an empty basket: harvest more",
		GuideC.state().text:find("Harvest") ~= nil and GuideC.state().button == "act",
		GuideC.state().text
	)
	check("...no STEP DONE for that", not refs.pay.Visible)
	p.cash = 100
	Guide:Check(player)
	Engine.advance(0.5)
	check("enough Cash: back to buying it", GuideC.state().key == "well", GuideC.state().key)
	-- the pads: one of a kind, and each keeps its own
	p.owned = {}
	p.level = 5
	local offer = Upg:Offer(player)
	local names = {}
	local twice = false
	for _, o in offer do
		twice = twice or names[o.upgrade.name] == true
		names[o.upgrade.name] = true
	end
	check("never two of the same on the pads", not twice)
	check("...soil comes in order, cheapest first", offer[1].upgrade.key == "soil4")
	local second = offer[2].upgrade.key
	p.cash = 1000
	Upg:Buy(player, offer[1].upgrade.key)
	local after = Upg:Offer(player)
	check("buying one: the others stay on their pads", after[2].upgrade.key == second, after[2].upgrade.key)
	check("...the next soil takes the bought one's pad", after[1].upgrade.key == "soil5", after[1].upgrade.key)
	check("the pad says what it gives and costs in $", Upgrades.blurb(Upgrades.soil5) == "+1 patch")
	check(
		"...exactly what it adds: the Big Field +9, not +30",
		Upgrades.blurb(Upgrades.field2) == "+8 patches",
		Upgrades.blurb(Upgrades.field2)
	)
end

-- The menu opens up with the guide --------------------------------------------------------------------------------------
p.guide.step = MenuC.UNLOCK.calendar
Guide:Check(player)
Engine.advance(0.5)
check("past the first sale: DAILY and SHOP", MenuC.refs.buttons.calendar.Visible and MenuC.refs.buttons.shop.Visible)
check("...STREET still waits", not MenuC.refs.buttons.street.Visible)
p.guide.step = MenuC.UNLOCK.street
Guide:Check(player)
Engine.advance(0.5)
check("the barn: STREET and FRIENDS too", MenuC.refs.buttons.street.Visible and MenuC.refs.buttons.friends.Visible)

-- A returning farmer: no tour --------------------------------------------------------------------------------------------
Engine.removePlayer(player)
Engine.advance(1)
local again = Engine.addPlayer("Ava", 811)
Engine.advance(1)
Engine.fireServer(again, "Ready")
Engine.advance(1)
check("back again: no tour", not GuideC.touring())

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`GuideSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end

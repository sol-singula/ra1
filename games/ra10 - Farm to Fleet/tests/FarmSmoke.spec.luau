--[[
Phase B on the mock engine, server and client together: the street of six plots; a player gets a plot with their
name, the shack, the stand, three soil tiles and the pads, and lands in front of it; the guide's first steps (plant,
harvest, plant all three, harvest six, sell, buy soil) happen through the real action button; the first harvest
comes within ten seconds and the first sale within thirty; the well waters, the level unlocks carrots, the
sprinkler starts crops watered, the basket fills up; the whole first chapter can be bought through to the barn and
the guide keeps going after it; leaving frees the plot and coming back rebuilds it, crops still growing.

  luaurun tests/FarmSmoke.spec.luau
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
local Constants = Engine.require(tree.shared.Constants)
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
local Guide = service("GuideService")
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local GuideData = Engine.require(tree.shared.Data.Guide)
local PlotLayout = Engine.require(tree.shared.World.PlotLayout)

local function lastFired(name, player)
	local e = Engine.lastClientEvent(name, player)
	return e and e.args[1]
end
local function stand(p, pos)
	Engine.moveTo(p, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.3)
end

-- The street ------------------------------------------------------------------------------------------------------
local world = Plots:World()
check("the street was built", world and Engine.workspace:FindFirstChild("Farms") == world.folder)
check("six plots", #world.plots == 6)
do
	local a, b = PlotLayout.frame(1), PlotLayout.frame(2)
	local gap = (b.Position - a.Position).Magnitude - PlotLayout.WIDTH
	check("neighbours a fence apart", math.abs(gap - PlotLayout.GAP) < 0.01, gap)
	local n, s = PlotLayout.frame(1), PlotLayout.frame(4)
	check("the rows face the road", n.LookVector.Z > 0.99 and s.LookVector.Z < -0.99)
	check("...across it", math.abs(math.abs(n.Position.Z - s.Position.Z) - (PlotLayout.ROAD + PlotLayout.DEPTH)) < 0.01)
end
check("cheap street", world.count < 2500, world.count)

-- A player lands --------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 801)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local plot = Plots:Plot(player)
local refs = Plots:Refs(player)
check("they get a plot", plot ~= nil and player:GetAttribute("Plot") == plot.index)
check("...their name on the sign", plot and plot.sign.Words.Title.Text:find("AVA") ~= nil)
check(
	"...the shack, the stand, the pads",
	plot.items:FindFirstChild("Shack") ~= nil and refs.standPad ~= nil and #refs.pads == 3
)
local tiles = Farm:Tiles(player)
check("...three soil tiles", tiles[1] and tiles[2] and tiles[3] and not tiles[4])
local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local spawnAt =
	PlotLayout.toWorld(plot.index, PlotLayout.SPOTS.spawn.X, PlotLayout.SPOTS.spawn.Z, PlotLayout.SPOTS.spawn.Y)
check("they stand in front of their farm", r and (r.Position - spawnAt).Magnitude < 1)
local gui = player.PlayerGui
check(
	"the HUD, the farm button, the guide",
	gui:FindFirstChild("Hud") and gui:FindFirstChild("Farm") and gui:FindFirstChild("Guide")
)
local Hud = Engine.require(tree.client.Controllers.HudController)
local FarmC = Engine.require(tree.client.Controllers.FarmController)
local GuideC = Engine.require(tree.client.Controllers.GuideController)
check("the guide's first step: plant", GuideC.state().key == "plant1" and GuideC.refs.card.Visible, GuideC.state().key)
check(
	"...pointing at the first tile",
	typeof(GuideC.state().target) == "Vector3" and (GuideC.state().target - tiles[1].Position).Magnitude < 0.1,
	tostring(GuideC.state().target) .. " vs " .. tostring(tiles[1].Position)
)
check("...the arrow shows", GuideC.refs.arrow.Transparency < 1)
check(
	"...and the path along the ground",
	(function()
		for _, d in GuideC.refs.dots do
			if d.Transparency < 1 then
				return true
			end
		end
		return false
	end)()
)
check("the button is hidden away from the soil", FarmC.action() == nil and not FarmC.refs.act.Visible)

-- The first minute ------------------------------------------------------------------------------------------------
local t0 = os.clock()
local p = Data:Get(player)
-- stand by the first tile only (the other two are within reach too: PLANT does every empty one in reach)
stand(player, tiles[1].Position + Vector3.new(0, 0, -4))
check(
	"by the soil: PLANT",
	FarmC.action() == "plant" and FarmC.refs.act.Visible and FarmC.refs.act.Text == "PLANT",
	FarmC.action()
)
FarmC.press()
Engine.advance(0.3)
check("PLANT plants (strawberries)", Farm:Phase(player, 1) ~= nil and p.soil["1"].crop == "strawberry")
check("...the seed mound shows", tiles[1]:FindFirstChild("Crop") and tiles[1].Crop:GetAttribute("Phase") == 0)
check(
	"the guide moves on: harvest",
	GuideC.state().key == "harvest1" or GuideC.state().key == "plant3",
	GuideC.state().key
)
Engine.advance(8.5)
check("ripe in 8 seconds", Farm:Ripe(player, 1) and tiles[1].Crop:GetAttribute("Phase") == 3)
check("...the button says HARVEST", FarmC.action() == "harvest")
FarmC.press()
Engine.advance(0.3)
check("HARVEST fills the basket", Farm:Carried(player) >= 1 and p.stats.harvested >= 1)
check("the first harvest inside ten seconds", os.clock() - t0 < 10.5, os.clock() - t0)
check("XP for it", (p.xp or 0) > 0)
check(
	"the HUD's basket counts it",
	Hud.refs.basket.Text:find(tostring(Farm:Carried(player))) ~= nil,
	Hud.refs.basket.Text
)
-- plant all three (from the middle tile: all three in reach), harvest six
stand(player, tiles[2].Position + Vector3.new(0, 0, -4))
for _ = 1, 6 do
	FarmC.press()
	Engine.advance(0.3)
	if Farm:Carried(player) >= 6 then
		break
	end
	Engine.advance(8.4)
	FarmC.press()
	Engine.advance(0.3)
end
check("six harvested", p.stats.harvested >= 6, p.stats.harvested)
check("the guide asks to sell", GuideC.state().key == "sell1", GuideC.state().key)
check("...pointing at the stand", (GuideC.state().target - refs.standPad.Position).Magnitude < 0.1)
local cashBefore = p.cash
stand(player, refs.standPad.Position)
check("standing on the stand's pad sells", p.cash > cashBefore and Farm:Carried(player) == 0, p.cash)
check("the first sale inside thirty seconds", os.clock() - t0 < 30, os.clock() - t0)
check(
	"...the HUD shows the Cash",
	(Hud.refs.cash.Text:gsub(",", "")) == tostring(math.floor(p.cash)),
	Hud.refs.cash.Text
)
Engine.advance(0.5)
check("the guide: buy More Soil", GuideC.state().key == "soil4", GuideC.state().key)
local pad1 = refs.pads[1]
check("the first pad offers it, green", pad1:GetAttribute("Item") == "soil4" and pad1.Over.Line.Text:find("10") ~= nil)
check("...the guide points at that pad", (GuideC.state().target - pad1.Position).Magnitude < 0.1)
stand(player, pad1.Position)
check("standing on the pad buys it", p.owned.soil4 ~= nil and Farm:Tiles(player)[4] ~= nil)
check("...and doesn't buy the next by standing on", not p.owned.soil5)

-- The well, levels, carrots, the sprinkler, the basket ---------------------------------------------------------------
p.cash = 10000
Economy:Push(player)
Engine.advance(0.3)
stand(player, refs.pads[1].Position + Vector3.new(0, 0, 8))
for _ = 1, 3 do
	for _, pad in refs.pads do
		if pad:GetAttribute("Item") == "soil5" or pad:GetAttribute("Item") == "well" then
			stand(player, pad.Position)
			stand(player, pad.Position + Vector3.new(0, 0, 8))
		end
	end
end
check("the well is bought", p.owned.well ~= nil, p.owned.well)
stand(player, tiles[1].Position + Vector3.new(0, 0, -4))
-- (harvest anything ripe first, then plant, then water)
for _ = 1, 3 do
	local a = FarmC.action()
	if a == "water" then
		break
	end
	FarmC.press()
	Engine.advance(0.3)
end
check("growing and dry: WATER", FarmC.action() == "water", FarmC.action())
local t = p.soil["1"]
local before = t and t.need
FarmC.press()
Engine.advance(0.3)
check("watering cuts the wait", t and t.watered and t.need < before, t and t.need)
check("...and darkens the soil", tiles[1].Color ~= Constants.PALETTE.soil)
Economy:AddXP(player, 200, "test")
Engine.advance(0.5)
check("a level unlocks carrots", (p.level or 1) >= 2 and table.find(lastFired("Farm", player).crops, "carrot") ~= nil)
check("...the crop picker has it", FarmC.refs.chips.carrot ~= nil)
check("...shown with the button (by the soil)", FarmC.refs.picker.Visible == FarmC.refs.act.Visible)
FarmC.refs.chips.strawberry.Activated:Fire()
Engine.advance(0.3)
check("the picker picks", p.settings.crop == "strawberry")
-- everything in the chapter can be bought, in order
local bought = 0
for _, key in Upgrades.LIST do
	if not p.owned[key] and Upgrades[key].stage == 1 then
		Economy:AddXP(player, 500, "test")
		if Upg:Buy(player, key) then
			bought += 1
		end
	end
end
check("the whole first stage buys, in order", Upgrades.upcoming(p.owned).stage == 2, bought)
check("...the barn deed opens stage 2", p.stage == 2)
check("...12 soil tiles", Farm:Tiles(player)[12] ~= nil)
check(
	"...every upgrade stands on the plot",
	(function()
		for _, key in { "well", "wheelbarrow", "fence", "sprinkler", "awning", "scarecrow", "barnDeed" } do
			if not plot.items:FindFirstChild(key) then
				return false
			end
		end
		return true
	end)()
)
check("the basket holds more with the wheelbarrow", Farm:Carry(player) == 60)
-- sprinklers: crops start watered
for n = 1, 12 do
	p.soil[tostring(n)] = nil
end
Farm:Plant(player, 5, "strawberry")
check("sprinklers: planted crops start watered", p.soil["5"].watered == true)
Engine.advance(1.5)
check("after chapter 1 the guide goes on into chapter 2", GuideC.state().key == "bigBarn", GuideC.state().key)
check("...chapter 1's steps all passed", p.guide.step > GuideData.byKey.barn.index, p.guide.step)

-- Leaving and coming back -------------------------------------------------------------------------------------------
Farm:Plant(player, 6, "carrot")
local idx = plot.index
local saved = Data:Get(player)
Engine.removePlayer(player)
Engine.advance(0.5)
check("leaving frees the plot", Plots:Owner(idx) == nil and #world.plots[idx].items:GetChildren() == 0)
check("...the sign says FOR SALE", world.plots[idx].sign.Words.Title.Text == "FOR SALE")
-- (the mock keeps the saved profile in its DataStore: a rejoin loads it)
local again = Engine.addPlayer("Ava", 801)
Engine.advance(1.5)
local p2 = Data:Get(again)
check("coming back: the save", p2 ~= nil and p2.stage == 2 and p2.owned.barnDeed ~= nil, p2 and p2.stage)
check(
	"...the farm rebuilt",
	Farm:Tiles(again)[12] ~= nil and Plots:Plot(again).items:FindFirstChild("scarecrow") ~= nil
)
check("...the crops still growing", p2 and p2.soil["6"] and p2.soil["6"].crop == "carrot")
_ = saved

-- A neighbour's farm shows on the street
local ben = Engine.addPlayer("Ben", 802)
Engine.advance(1.5)
check("a neighbour gets the next plot", Plots:Plot(ben) and Plots:Plot(ben).index ~= Plots:Plot(again).index)
check("...with a farm of their own", Farm:Tiles(ben)[1] ~= nil and not Farm:Tiles(ben)[4])

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`FarmSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end

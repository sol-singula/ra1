--[[
The server and the client boot together on the mock engine; a player joins, gets a territory, the first minute
plays (plant, grow, harvest, a customer buys), and nothing errors.

  luaurun tests/BootSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
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
local Crops = service("CropService")
local Territory = service("TerritoryService")
local Business = service("BusinessService")

check("the town is built", Engine.workspace:FindFirstChild("Town") ~= nil)
check("twelve empty territories", #Engine.workspace.Territories:GetChildren() == 12)

local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
check("a profile", p ~= nil and p.stage == "stand")
local t = Territory:Territory(player)
check(
	"a territory, built",
	t ~= nil and t.model:FindFirstChild("Fields") ~= nil and t.model.Buildings:FindFirstChild("Business") ~= nil
)
check("four starter tiles", #Crops:Tiles(player) == 4)
check("a character at the gate", player.Character ~= nil)

-- the first minute
local id = Crops:Tiles(player)[1]
check("plant", Crops:Plant(player, id))
check("...not ripe yet", not Crops:Ripe(player, id))
Engine.advance(11)
check("...ripe after its grow time", Crops:Ripe(player, id), p.tiles[id])
check("harvest", Crops:Harvest(player, id, "hand") == 1)
check("...in stock", Business:Stock(player) == 1)
Engine.advance(8)
check("a customer bought it", (p.stats.sold or 0) >= 1 and p.cash > 0, p.cash)
check("the guidance moved past the sale", p.task.step >= 4, p.task.step)

-- the client got its state
local Store = Engine.require(tree.client.Store)
Engine.advance(1)
check("the client knows the territory", Store.get("territory") and Store.get("territory").index == t.index)
check("...and the tiles", Store.get("crops") and Store.get("crops").tiles ~= nil)
check("...and the business", Store.get("business") and Store.get("business").stage == "stand")
check("...and the task", Store.get("task") and Store.get("task").primary ~= nil)

Engine.removePlayer(player)
Engine.advance(1)
check("the territory is free again", Territory:OwnerOf(t.index) == nil)

do
	local bad = {}
	for _, w in Engine.warnings do
		if tostring(w):find("failed") then
			table.insert(bad, tostring(w))
		end
	end
	check("no failed saves, ticks or boots", #bad == 0, bad[1])
end
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`BootSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end

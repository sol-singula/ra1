--[[
The online ocean and the start menu's server side: in a server whose Mode is "online", everyone is put on ONE ship
(plot 1), anyone aboard can build on it, it outlives whoever leaves (the captain's hat passes on), it's saved for
everybody (not into anyone's own raft), and a piece built on another server shows up here. In a hub server the
menu's choices fall back to playing right here in Studio, and a friend's invite names a world.

  luaurun tests/Online.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3

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
local ws = Engine.workspace
-- a reserved online server: the first arrival's teleport data says so (the mock's join data carries no teleport
-- data, so the mode is set the way ModeService would)
ws:SetAttribute("Mode", "online")
Engine.runScript(tree.server.Main)
Engine.advance(0.1)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Rafts = service("RaftService")
local Inventory = service("InventoryService")
local Players = service("PlayerService")
local Data = service("PlayerDataService")
local Mode = service("ModeService")

local ava = Engine.addPlayer("Ava", 601)
local ben = Engine.addPlayer("Ben", 602)
Engine.advance(3)
local ship = Rafts:RaftOf(ava)
check("online: everyone's on the one ship", ship ~= nil and Rafts:RaftOf(ben) == ship and ship.shared == true)
check("it sits on plot 1", ship and ship.plot == 1)
check("only one raft in the world", #ws.Rafts:GetChildren() == 1)
check(
	"the raft view says it's shared, with the crew count",
	Rafts:View(ship).shared == true and Rafts:View(ship).crew == 2
)

-- both can build on it
local function buildFloor(player)
	Inventory:Give(player, "wood", 8, "home")
	local spot = Rafts:FreeSpots(ship, 1)[1]
	return Rafts:Build(player, "floor", spot[1], spot[2], 1)
end
local before = ship.summary.tiles
check("Ava builds a floor on the shared ship", buildFloor(ava) ~= false)
check("Ben builds one too", buildFloor(ben) ~= false)
check("the ship grew by both", ship.summary.tiles == before + 2, ship.summary.tiles)
check("each build told the other servers", #Engine.messages >= 2 and Engine.messages[1].topic == "EV_Ship")

-- a piece built on another server shows up here
local spot = Rafts:FreeSpots(ship, 1)[1]
Rafts:_onShipMessage({ server = "elsewhere", op = "add", s = { key = "floor", gx = spot[1], gz = spot[2], level = 1 } })
check("a floor built on another server appears on this one", ship.summary.tiles == before + 3, ship.summary.tiles)
Rafts:_onShipMessage({ server = "elsewhere", op = "add", s = { key = "floor", gx = spot[1], gz = spot[2], level = 1 } })
check("the same spot twice doesn't stack", ship.summary.tiles == before + 3)

-- Ava leaves: the ship stays, Ben's the captain, and Ava's own raft in her save isn't touched
local avaProfile = Data:Get(ava)
Engine.removePlayer(ava)
Engine.advance(1)
check("the ship stays while anyone's aboard", Rafts:RaftOf(ben) == ship and ws.Rafts:FindFirstChild("Raft1") ~= nil)
check("the captain's hat passed to Ben", ship.owner == ben)
check(
	"Ava's own raft (her world) wasn't overwritten by the shared ship",
	#(avaProfile.raft.pieces or {}) < ship.summary.tiles,
	#(avaProfile.raft.pieces or {})
)
check("but her records count the big ship", avaProfile.records.tiles >= before + 3)

-- saved for everybody
check("the ship saves for everyone", Rafts:SaveShared() == true)
local saved = Engine.dataStores.EV_Ship_v1 and Engine.dataStores.EV_Ship_v1.ship
check("the saved ship has every floor", saved ~= nil and #saved.pieces >= before + 3, saved and #saved.pieces)

-- the last one leaves: saved and gone; the next arrival gets it back
Engine.removePlayer(ben)
Engine.advance(1)
check("with nobody aboard the ship is put away", Rafts:Shared() == nil and ws.Rafts:FindFirstChild("Raft1") == nil)
local cal = Engine.addPlayer("Cal", 603)
Engine.advance(3)
local back = Rafts:RaftOf(cal)
check(
	"the next sailor gets the same ship back",
	back ~= nil and back.shared and back.summary.tiles == before + 3,
	back and back.summary.tiles
)
check("Cal stands on it", Players:Where(cal) == "raft" or Players:Where(cal) ~= nil)

-- the menu's choices in Studio play right here
Mode:Choose(cal, "world")
local menu = Engine.lastClientEvent("Menu", cal)
check("in Studio, MY WORLD says you play right here", menu ~= nil and menu.args[1].close == true)

print(`\n{passed} passed, {failed} failed`)
if failed > 0 or #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	error(`Online: {failed} failures`)
end

--[[
The scaffold boots: the server's services and the client's controllers start on the mock engine, a player joins,
their profile loads with the farm's shape (Cash, Gems, the stage, the guide, the calendar), the client says Ready,
and leaving saves without an error.

  luaurun tests/BootSmoke.spec.luau
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
local Constants = Engine.require(tree.shared.Constants)
Engine.clientEnabled = true
Engine.runScript(tree.server.Main)
Engine.advance(0.5)

check("the game's name", Constants.GAME_NAME == "Farm to Fleet")
check("six plots a server", Constants.PLOTS == 6 and Constants.MAX_PLAYERS == 6)
check("a colour for every plot", #Constants.PLOT_COLORS == Constants.PLOTS)

local player = Engine.addPlayer("Ava", 701)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1)

local Data = Engine.require(tree.server.Services.PlayerDataService)
local p = Data:Get(player)
check("the profile loaded", p ~= nil)
check("...a farm's profile", p and p.cash == Constants.START_CASH and p.gems == Constants.START_GEMS and p.stage == 1)
check("...the guide starts at the first step", p and p.guide.chapter == 1 and p.guide.step == 1)
check("...the calendar and the away clock", p and p.calendar.streak == 0 and p.away ~= nil)
check("...new", p and p._isNew == true)
check("the client said Ready", Engine.lastClientEvent("Ready") ~= nil)

Engine.removePlayer(player)
Engine.advance(0.5)
check("leaving lets go of the profile", Data:Get(player) == nil)

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

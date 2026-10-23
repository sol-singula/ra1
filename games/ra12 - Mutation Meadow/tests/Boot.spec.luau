local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local function dummies(log, failInit)
	local modules = {}
	for _, name in { "A", "B", "C" } do
		modules[name] = {
			Init = function(_, services)
				table.insert(log, "init " .. name)
				Assert.truthy(services.A and services.B and services.C, "Init sees every service")
				if failInit == name then
					error("boom")
				end
			end,
			Start = function()
				table.insert(log, "start " .. name)
			end,
		}
	end
	return modules
end

test("every Init runs, in order, before any Start", function()
	local engine = Engine.new()
	local Loader = engine:require(engine:module("Server/Loader"))
	local log = {}
	local ok, err = engine:run(Loader.start, dummies(log), { "A", "B", "C" })
	Assert.truthy(ok, err)
	eq(log, { "init A", "init B", "init C", "start A", "start B", "start C" })
	eq(engine.output[#engine.output], "[Loader] ready")
end)

test("a throwing Init fails the boot", function()
	local engine = Engine.new()
	local Loader = engine:require(engine:module("Server/Loader"))
	local log = {}
	local ok, err = engine:run(Loader.start, dummies(log, "B"), { "A", "B", "C" })
	Assert.truthy(not ok, "boot should fail")
	Assert.truthy(tostring(err):find("^%[Loader%] B: "), tostring(err))
	eq(log, { "init A", "init B" })
	Assert.truthy(table.find(engine.output, "[Loader] ready") == nil, "no ready after a failed boot")
end)

test("a missing service module is an error", function()
	local engine = Engine.new()
	local Loader = engine:require(engine:module("Server/Loader"))
	local ok, err = engine:run(Loader.boot, engine:module("Server/Services"), { "PolicyGate" })
	Assert.truthy(not ok)
	Assert.truthy(tostring(err):find("%[Loader%] PolicyGate: missing module"), tostring(err))
end)

test("DataService.Loaded and .Leaving reach the player hooks", function()
	local engine = Engine.new()
	local Loader = engine:require(engine:module("Server/Loader"))
	local Signal = engine:require(engine:module("Shared/Signal"))
	local seen = {}
	local modules = {
		DataService = { Loaded = Signal.new(), Leaving = Signal.new() },
		X = {
			OnPlayerLoaded = function(_, player, profile)
				table.insert(seen, { "loaded", player, profile })
			end,
			OnPlayerLeaving = function(_, player, profile)
				table.insert(seen, { "leaving", player, profile })
			end,
		},
	}
	local ok, err = engine:run(Loader.start, modules, { "DataService", "X" })
	Assert.truthy(ok, err)
	modules.DataService.Loaded:Fire("p", "prof")
	modules.DataService.Leaving:Fire("p", "prof")
	eq(seen, { { "loaded", "p", "prof" }, { "leaving", "p", "prof" } })
end)

test("ORDER is PLAN's order and every ORDER module exists", function()
	local engine = Engine.new()
	local Loader = engine:require(engine:module("Server/Loader"))
	eq(#Loader.PLAN, 21)
	local last = 0
	for _, name in Loader.ORDER do
		local i = table.find(Loader.PLAN, name)
		Assert.truthy(i and i > last, name .. " out of PLAN order")
		last = i
		Assert.truthy(engine:module("Server/Services"):FindFirstChild(name), name .. " has no module")
	end
end)

test("Main.server boots and prints ready; the client boots too", function()
	local engine = Engine.new()
	local ok, err = engine:runScript(engine:module("Server/Main"))
	Assert.truthy(ok, err)
	Assert.truthy(table.find(engine.output, "[Loader] ready"), "server ready")
	local client = Engine.new({ client = true })
	ok, err = client:runScript(client:module("Client/Main"))
	Assert.truthy(ok, err)
	Assert.truthy(table.find(client.output, "[ControllerLoader] ready"), "client ready")
	eq(engine.game.Workspace.StreamingEnabled, false)
	eq(engine.game.Players.MaxPlayers, 8)
end)

test("ControllerLoader runs Init before Start and fails on a throwing Init", function()
	local engine = Engine.new({ client = true })
	local CL = engine:require(engine:module("Client/ControllerLoader"))
	local log = {}
	local ok = engine:run(CL.start, dummies(log), { "A", "B", "C" })
	Assert.truthy(ok)
	eq(log, { "init A", "init B", "init C", "start A", "start B", "start C" })
	local ok2, err = engine:run(CL.start, dummies({}, "A"), { "A", "B", "C" })
	Assert.truthy(not ok2 and tostring(err):find("^%[ControllerLoader%] A: "), tostring(err))
end)

--[[
The universe (Data/Modes): Constants.applyMode switches the sides' names and colours (and the ground) for all
four modes and back, in place; Modes.multiPlace is false while the place ids are zero; the three place project
files parse and point at the same src tree with their Mode value; a turf server counts its real people only
(the bots never); the lobby boots with the match's services skipped (nothing crashes: the registry has no
MatchService, a player joins with no team), publishes its population, reads the other servers' lines back and
picks the best mode, and refuses PLAY and LOBBY gracefully while the places aren't made; with ids set, PLAY
teleports (a party together, by its leader, with the mode they came from in the teleport data) and a failed
teleport says so.

  luaurun tests/ModeSmoke.spec.luau
]]
local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local function near(a, b)
	return math.abs(a.R - b.R) < 0.002 and math.abs(a.G - b.G) < 0.002 and math.abs(a.B - b.B) < 0.002
end

-- 1. The modes' looks, pure ---------------------------------------------------------------------------------------
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Constants = Engine.require(tree.shared.Constants)
local Modes = Engine.require(tree.shared.Data.Modes)
local typeof = Engine.globals.typeof

check("the one place is turf", Constants.MODE == "turf" and Modes.current() == "turf")
check("turf's names", Constants.TEAM_NAME.red == "RED" and Constants.TEAM_NAME.blue == "BLUE")
local turfRed, turfBlue = Constants.TEAM_COLOR.red, Constants.TEAM_COLOR.blue
local turfTurf, turfBuild, turfArmor = Constants.TURF_COLOR.red, Constants.BUILD_COLOR.blue, Constants.ARMOR_COLOR.red
local teamTable, turfTable = Constants.TEAM_COLOR, Constants.TURF_COLOR
local WANT = {
	lobby = { "RED", "BLUE" },
	turf = { "RED", "BLUE" },
	ctf = { "PURPLE", "ORANGE" },
	brawl = { "GREEN", "SHADOW" },
}
for _, key in Constants.MODES do
	check(`applyMode({key}) returns it`, Constants.applyMode(key) == key and Constants.MODE == key)
	check(`{key}: names`, Constants.TEAM_NAME.red == WANT[key][1] and Constants.TEAM_NAME.blue == WANT[key][2])
	check(`{key}: Modes.current`, Modes.current() == key)
	check(
		`{key}: the tables keep their identity`,
		Constants.TEAM_COLOR == teamTable and Constants.TURF_COLOR == turfTable
	)
	for _, name in { "TEAM_COLOR", "TURF_COLOR", "BUILD_COLOR", "ARMOR_COLOR" } do
		local t = Constants[name]
		check(`{key}: {name} has both sides`, typeof(t.red) == "Color3" and typeof(t.blue) == "Color3")
		check(`{key}: {name} sides differ`, not near(t.red, t.blue))
	end
	if key == "brawl" then
		check(
			"brawl: green ground",
			typeof(Constants.MAP_GROUND.turf) == "Color3" and Constants.MAP_GROUND.turf.G > Constants.MAP_GROUND.turf.R
		)
		check(
			"brawl: the humans are green",
			Constants.TEAM_COLOR.red.G > Constants.TEAM_COLOR.red.R
				and Constants.TEAM_COLOR.red.G > Constants.TEAM_COLOR.red.B
		)
		check("brawl: the bots are dark", Constants.TEAM_COLOR.blue.R < 0.4 and Constants.TEAM_COLOR.blue.G < 0.4)
	else
		check(`{key}: the map's own ground`, next(Constants.MAP_GROUND) == nil)
	end
	if key == "ctf" then
		check(
			"ctf: purple",
			Constants.TEAM_COLOR.red.B > Constants.TEAM_COLOR.red.G and Constants.TEAM_COLOR.red.R > 0.4
		)
		check("ctf: orange", Constants.TEAM_COLOR.blue.R > 0.9 and Constants.TEAM_COLOR.blue.B < 0.3)
		check(
			"ctf: not turf's colours",
			not near(Constants.TEAM_COLOR.red, turfRed) and not near(Constants.TEAM_COLOR.blue, turfBlue)
		)
	end
end
Constants.applyMode("turf")
check("back to turf: names", Constants.TEAM_NAME.red == "RED" and Constants.TEAM_NAME.blue == "BLUE")
check(
	"back to turf: every colour as it was",
	near(Constants.TEAM_COLOR.red, turfRed)
		and near(Constants.TEAM_COLOR.blue, turfBlue)
		and near(Constants.TURF_COLOR.red, turfTurf)
		and near(Constants.BUILD_COLOR.blue, turfBuild)
		and near(Constants.ARMOR_COLOR.red, turfArmor)
		and next(Constants.MAP_GROUND) == nil
)
Constants.applyMode("turf")
check("applyMode twice is the same", Constants.MODE == "turf" and near(Constants.TEAM_COLOR.red, turfRed))
check("an unknown key means turf", Constants.applyMode("nope") == "turf" and Constants.MODE == "turf")

-- the StringValue under ReplicatedStorage names a place's mode
local rs = Engine.game:GetService("ReplicatedStorage")
check("no Mode value: turf", Constants.placeMode() == "turf")
local modeValue = Engine.Instance.new("StringValue", rs)
modeValue.Name = "Mode"
modeValue.Value = "brawl"
check("a Mode value names the place", Constants.placeMode() == "brawl")
modeValue.Value = "bogus"
check("a bad Mode value means turf", Constants.placeMode() == "turf")
modeValue:Destroy()

-- 2. Data/Modes --------------------------------------------------------------------------------------------------
check(
	"three modes to play",
	#Modes.LIST == 3 and Modes.LIST[1] == "turf" and Modes.LIST[2] == "ctf" and Modes.LIST[3] == "brawl"
)
for _, key in Modes.LIST do
	local m = Modes[key]
	check(`{key}: its entry`, m and m.key == key and type(m.name) == "string" and type(m.blurb) == "string")
	check(`{key}: placeId 0 until made`, m.placeId == 0)
	check(`{key}: Modes.get`, Modes.get(key) == m)
end
check("the lobby isn't played", Modes.get("lobby") == nil and Modes.LOBBY_PLACE == 0)
check("minPlayers", Modes.turf.minPlayers == 1 and Modes.ctf.minPlayers == 4 and Modes.brawl.minPlayers == 1)
check("bots", Modes.turf.bots == true and Modes.ctf.bots == false and Modes.brawl.bots == true)
check("multiPlace false with zero ids", Modes.multiPlace() == false)
Modes.LOBBY_PLACE, Modes.turf.placeId, Modes.ctf.placeId = 1, 2, 3
check("multiPlace needs every id", Modes.multiPlace() == false)
Modes.brawl.placeId = 4
check("multiPlace with every id", Modes.multiPlace() == true)
Modes.LOBBY_PLACE, Modes.turf.placeId, Modes.ctf.placeId, Modes.brawl.placeId = 0, 0, 0, 0
check("runsIn: no Modes means everywhere", Modes.runsIn({}, "lobby") and Modes.runsIn({ Name = "X" }, "ctf"))
check(
	"runsIn: Modes listed",
	Modes.runsIn({ Modes = { "turf", "ctf" } }, "ctf") and not Modes.runsIn({ Modes = { "turf", "ctf" } }, "lobby")
)
check("runsIn: the current mode by default", Modes.runsIn({ Modes = { "turf" } }) == true)

-- 3. The place project files ----------------------------------------------------------------------------------
local HttpService = Engine.game:GetService("HttpService")
local default = HttpService:JSONDecode(readFile("default.project.json"))
check("default.project.json is turf (no Mode value)", default.tree.ReplicatedStorage.Mode == nil)
for _, key in { "lobby", "ctf", "brawl" } do
	local ok, proj = pcall(function()
		return HttpService:JSONDecode(readFile(`places/{key}.project.json`))
	end)
	check(`places/{key}.project.json parses`, ok and type(proj) == "table" and type(proj.tree) == "table", proj)
	if ok then
		local t = proj.tree
		local mode = t.ReplicatedStorage and t.ReplicatedStorage.Mode
		check(
			`{key}: a Mode StringValue`,
			mode and mode["$className"] == "StringValue" and mode["$properties"].Value == key
		)
		check(`{key}: the same shared tree`, t.ReplicatedStorage.Shared["$path"] == "../src/shared")
		check(`{key}: the same server tree`, t.ServerScriptService.Server["$path"] == "../src/server")
		check(`{key}: the same client tree`, t.StarterPlayer.StarterPlayerScripts.Client["$path"] == "../src/client")
		check(
			`{key}: the same character script`,
			t.StarterPlayer.StarterCharacterScripts.Health["$path"] == "../src/character/Health.server.lua"
		)
		check(
			`{key}: the same settings`,
			t.Players["$properties"].MaxPlayers == default.tree.Players["$properties"].MaxPlayers
		)
	end
end

-- 4. A turf server: the loader runs everything, the population counts people and never bots -----------------
Constants.AFK_SECONDS = 0
Constants.TUTORIAL = false
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
check("turf boot: no script errors", #Engine.errors == 0, Engine.errors[1])
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Population = service("PopulationService")
local Bots = service("BotService")
local solo = Engine.addPlayer("Solo", 7001)
Engine.advance(0.5)
Engine.fireServer(solo, "Ready")
Engine.advance(2)
check("turf: a bot came to fight the lone player", #Bots:List() >= 1, #Bots:List())
check("turf: the bot never counts", Population:Here() == 1, Population:Here())
check("turf: this server's own count is live", Population:Counts().turf == 1, Population:Counts().turf)
check("turf: Best is turf", Population:Best() == "turf")
local line = Engine.memory[Population.MAP] and Engine.memory[Population.MAP].studio
check("turf: this server's line in the sorted map", line and line.mode == "turf" and line.n == 1, line and line.n)
local pop = Engine.lastClientEvent("Population", solo)
check(
	"turf: the player got the population",
	pop and pop.args[1].counts.turf == 1 and pop.args[1].best == "turf" and pop.args[1].open == false
)
local Place = service("PlaceService")
local trips = #Engine.teleports
local ok, why = Place:ToLobby(solo)
Engine.advance(0.1)
local toast = Engine.lastClientEvent("Toast", solo)
check(
	"turf: LOBBY refused while the places aren't made",
	ok == false and why == "closed" and #Engine.teleports == trips
)
check("turf: ...and it says so", toast and string.find(toast.args[1], "isn't open yet") ~= nil, toast and toast.args[1])
Engine.fireServer(solo, "Play", "ctf")
Engine.advance(0.1)
toast = Engine.lastClientEvent("Toast", solo)
check(
	"turf: PLAY refused too",
	#Engine.teleports == trips and toast and string.find(toast.args[1], "Capture the Flag isn't open yet") ~= nil,
	toast and toast.args[1]
)
Engine.fireServer(solo, "Play", 42)
Engine.advance(0.1)
check("turf: a bad PLAY is ignored", #Engine.teleports == trips and #Engine.errors == 0)

-- 5. The lobby: a fresh engine, the match's services skipped ----------------------------------------------------
local L = loadModule("tests/mock/Engine.luau")
local ltree = L.mountProject(".")
local LConstants = L.require(ltree.shared.Constants)
LConstants.applyMode("lobby")
local Loader = L.require(ltree.server.Loader)
local all = {}
for _, child in ltree.server.Services:GetChildren() do
	local svc = L.require(child)
	all[svc.Name] = svc
end
local run, skipped = Loader.select(all, "lobby")
check("lobby: MatchService skipped", skipped.MatchService and run.MatchService == nil)
for _, name in
	{
		"TeamService",
		"BuildService",
		"BotService",
		"ArenaService",
		"AfkService",
		"HookService",
		"GiftService",
		"FeedbackService",
		"InviteService",
		"TutorialService",
		"MissionControlService",
	}
do
	check(`lobby: {name} skipped`, skipped[name] == true and run[name] == nil)
end
for _, name in
	{
		"PlayerDataService",
		"EconomyService",
		"ShopService",
		"ProgressService",
		"SeasonService",
		"LeaderboardService",
		"AnalyticsService",
		"AdminService",
		"GameLogService",
		"MemeArtService",
		"AntiCheatService",
		"CombatService",
		"PartyService",
		"PlaceService",
		"PopulationService",
	}
do
	check(`lobby: {name} runs`, run[name] ~= nil and not skipped[name])
end
-- a service that depends only on skipped ones goes too
local fake = { Name = "OnlyMatch", Dependencies = { "MatchService", "TeamService" } }
all.OnlyMatch = fake
local run2, skipped2 = Loader.select(all, "lobby")
check(
	"lobby: a service that needs only skipped services is skipped",
	skipped2.OnlyMatch == true and run2.OnlyMatch == nil
)
all.OnlyMatch = nil
local run3, skipped3 = Loader.select(all, "turf")
local onlyOthers = true
for name in skipped3 do
	onlyOthers = onlyOthers and (all[name].Modes ~= nil and not table.find(all[name].Modes, "turf"))
end
check(
	"turf: everything runs (but another mode's own, like BrawlService)",
	onlyOthers and run3.MatchService ~= nil and run3.PlaceService ~= nil
)

L.runScript(ltree.server.Main)
L.advance(0.5)
check("lobby boot: no script errors", #L.errors == 0, L.errors[1])
check("lobby: no arena built", L.workspace:FindFirstChild("Arena") == nil)
local function lservice(name)
	return L.require(ltree.server.Services[name])
end
local LPop = lservice("PopulationService")
local LPlace = lservice("PlaceService")
local LParty = lservice("PartyService")
local LData = lservice("PlayerDataService")
local a = L.addPlayer("Ann", 7101)
L.advance(0.5)
L.fireServer(a, "Ready")
L.advance(0.5)
check("lobby: the player's save loaded", LData:Get(a) ~= nil)
check(
	"lobby: no team (TeamService isn't running)",
	a:GetAttribute("Team") == nil and (a.Character == nil or a.Character:GetAttribute("Team") == nil)
)
check("lobby: still no errors", #L.errors == 0, L.errors[1])
local b = L.addPlayer("Ben", 7102)
L.advance(0.5)
L.fireServer(b, "Ready")
L.advance(0.5)
check("lobby: two people", LPop:Here() == 2 and LPop:Counts().lobby == 2, LPop:Counts().lobby)
local lline = L.memory[LPop.MAP] and L.memory[LPop.MAP].studio
check("lobby: this server's line says lobby, 2", lline and lline.mode == "lobby" and lline.n == 2)
-- other servers' lines: summed by mode, stale ones dropped, this server's own never doubled
local map = L.memory[LPop.MAP]
local now = L.globals.os.time -- (the engine's clock, which the service reads)
map["job-a"] = { mode = "ctf", n = 5, at = now() }
map["job-b"] = { mode = "ctf", n = 2, at = now() }
map["job-c"] = { mode = "turf", n = 6, at = now() }
map["job-old"] = { mode = "brawl", n = 50, at = now() - 600 }
map["job-bad"] = { mode = "nope", n = 9, at = now() }
local changed = LPop:Refresh()
local c = LPop:Counts()
check(
	"lobby: the sums",
	c.ctf == 7 and c.turf == 6 and c.brawl == 0 and c.lobby == 2,
	`{c.turf}/{c.ctf}/{c.brawl}/{c.lobby}`
)
check("lobby: Changed and pushed", changed == true)
check("lobby: Best is the fullest", LPop:Best() == "ctf")
local pushed = L.lastClientEvent("Population", "all") or L.lastClientEvent("Population")
check(
	"lobby: the clients got the new counts",
	pushed and pushed.args[1].counts.ctf == 7 and pushed.args[1].best == "ctf"
)
map["job-c"].n = 7
LPop:Refresh()
check("lobby: a tie goes to turf", LPop:Best() == "turf")
map["job-c"].n = 1
map["job-a"].n = 1
map["job-b"] = nil
map["job-d"] = { mode = "brawl", n = 1, at = now() }
LPop:Refresh()
check("lobby: a three-way tie goes to turf", LPop:Best() == "turf")
map["job-c"] = nil
LPop:Refresh()
check("lobby: ctf before brawl on a tie", LPop:Best() == "ctf")
check("bestOf is pure", LPop.bestOf({ brawl = 3, turf = 1, ctf = 0 }) == "brawl" and LPop.bestOf({}) == "turf")

-- PLAY and LOBBY while the places aren't made: refused, with a word
local LModes = L.require(ltree.shared.Data.Modes)
L.fireServer(a, "Play")
L.advance(0.1)
local ltoast = L.lastClientEvent("Toast", a)
check(
	"lobby: PLAY (the best mode) refused while closed",
	#L.teleports == 0 and ltoast and string.find(ltoast.args[1], "isn't open yet") ~= nil,
	ltoast and ltoast.args[1]
)
check("lobby: LOBBY from the lobby is 'here'", select(2, LPlace:ToLobby(a)) == "closed")
-- the places made: PLAY teleports, with where they came from
LModes.LOBBY_PLACE, LModes.turf.placeId, LModes.ctf.placeId, LModes.brawl.placeId = 1001, 1002, 1003, 1004
check("lobby: LOBBY from the lobby is 'here' once open", select(2, LPlace:ToLobby(a)) == "here")
L.advance(2.5) -- (PLAY is one every 2 s)
L.fireServer(a, "Play")
L.advance(0.1)
check(
	"lobby: PLAY went to the best mode",
	#L.teleports == 1 and L.teleports[1].placeId == 1003,
	L.teleports[1] and L.teleports[1].placeId
)
local data = L.teleports[1] and L.teleports[1].options:GetTeleportData()
check(
	"lobby: the teleport data says where from",
	data and data.from == "lobby" and data.to == "ctf" and data.party == nil
)
check("lobby: just them", L.teleports[1] and #L.teleports[1].players == 1 and L.teleports[1].players[1] == a)
check("lobby: a second PLAY right away waits (the cooldown)", select(2, LPlace:ToMode(a, "turf")) == "busy")
check("lobby: an unknown mode", select(2, LPlace:ToMode(b, "lobby")) == "unknown")
-- a party goes together, by its leader
LParty:Invite(a, b)
L.advance(0.2)
LParty:Answer(b, true)
L.advance(0.2)
check(
	"lobby: a party formed with no teams to settle",
	LParty:Of(a) ~= nil and LParty:Of(b) == LParty:Of(a) and #L.errors == 0,
	L.errors[1]
)
check("lobby: a member can't move the party", select(2, LPlace:ToMode(b, "brawl")) == "party")
check("lobby: ...and is told", string.find(L.lastClientEvent("Toast", b).args[1], "party leader") ~= nil)
L.advance(LPlace.COOLDOWN + 0.1)
local okp = LPlace:ToMode(a, "brawl")
L.advance(0.1)
local trip = L.teleports[#L.teleports]
check(
	"lobby: the leader takes the party",
	okp == true and #L.teleports == 2 and trip.placeId == 1004 and #trip.players == 2
)
local tdata = trip.options:GetTeleportData()
check(
	"lobby: the party rides in the teleport data",
	tdata.party and tdata.party.leader == a.UserId and #tdata.party.members == 2 and tdata.from == "lobby"
)
check("lobby: PlaceService:Trips keeps them", #LPlace:Trips() == 2)
-- a teleport that fails: a toast, and they may try again
local c2 = L.addPlayer("Cat", 7103)
L.advance(0.5)
L.fireServer(c2, "Ready")
L.advance(0.3)
L.teleportResult = "Failure"
LPlace:ToMode(c2, "turf")
L.advance(0.5)
L.teleportResult = nil
local ftoast = L.lastClientEvent("Toast", c2)
check(
	"lobby: a failed teleport says so",
	ftoast and string.find(ftoast.args[1], "Could not go there") ~= nil,
	ftoast and ftoast.args[1]
)
check("lobby: ...and lifts the cooldown", select(2, LPlace:ToMode(c2, "turf")) == nil)
-- where someone came from, on arrival
local d = L.addPlayer("Dan", 7104, nil, { from = "turf" })
check("arrivedFrom reads the teleport data", LPlace.arrivedFrom(d) == "turf" and LPlace.arrivedFrom(a) == nil)
LModes.LOBBY_PLACE, LModes.turf.placeId, LModes.ctf.placeId, LModes.brawl.placeId = 0, 0, 0, 0
L.removePlayer(b)
L.advance(0.5)
check("lobby: leaving is counted", LPop:Here() == 3 and LPop:Counts().lobby == 3, LPop:Counts().lobby)
check("lobby: no errors at the end", #L.errors == 0, L.errors[1])
check("lobby: no Init failures", not string.find(table.concat(L.warnings, "\n"), "Init failed"))

print(`ModeSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("ModeSmoke failed")
end

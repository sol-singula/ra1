--[[
Bot Brawl (BrawlService, BrawlController) on the mock engine, the place in "brawl" mode: everyone who joins is on
the human side (GREEN) and no bot ever is, the grass; the build phase, then the waves of bots from the far deck that
hunt across the field; a wave cleared pays, says so, sets off the fireworks (the real client) and is remembered
(the save, the "brawl" board); a bot down never comes back; the boss takes three hits; the director eases when the
humans are losing and presses when they cruise; nobody wipes (the bots freeze); a late joiner drops straight in;
respawns; the set's build phase; the run's victory after the last wave and the fresh run on a new map.

  luaurun tests/BrawlSmoke.spec.luau
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
local Constants = Engine.require(tree.shared.Constants)
Constants.applyMode("brawl")
Constants.AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
local B = Constants.BRAWL
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
-- (the first-knockout help, the comeback shield and the new-player help are tests/FeelSmoke's)
Engine.require(tree.server.Services.CombatService).firstKillHelp = false
Engine.require(tree.server.Services.CombatService).comebackShield = false
Engine.require(tree.server.Services.CombatService).newPlayerHelp = false
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Brawl = service("BrawlService")
local Bots = service("BotService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Match = service("MatchService")
local Build = service("BuildService")
local Arena = service("ArenaService")
local Data = service("PlayerDataService")
local Leaderboard = service("LeaderboardService")
local Formulas = Engine.require(tree.shared.Formulas)

local function mark()
	return #Engine.clientLog
end
local function firedSince(m, name, player, pred)
	for i = m + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if
			e.name == name
			and (player == nil or e.player == player or e.player == "all")
			and (not pred or pred(e.args))
		then
			return e
		end
	end
	return nil
end
local function root(who)
	return who.Character and who.Character:FindFirstChild("HumanoidRootPart")
end
local function aliveBots()
	local out = {}
	for _, b in Bots:List() do
		if b.Parent and Combat:Alive(b) then
			table.insert(out, b)
		end
	end
	return out
end
-- Knock every bot of the wave out (by Ava) until the wave is over, as they come off the deck
local function clearWaveBy(killer, limit)
	for _ = 1, limit or 200 do
		if Brawl:State() ~= "wave" then
			return true
		end
		for _, b in aliveBots() do
			Combat:Kill(b, killer, { weapon = "bow" })
		end
		Engine.advance(0.3)
	end
	return Brawl:State() ~= "wave"
end

-- The mode -------------------------------------------------------------------------------------------------------
check("the place is in brawl mode", Constants.MODE == "brawl")
check("the teams are GREEN and SHADOW", Constants.TEAM_NAME.red == "GREEN" and Constants.TEAM_NAME.blue == "SHADOW")
check("...as Roblox teams", Engine.game:GetService("Teams"):FindFirstChild("GREEN") ~= nil)
check("BrawlService is up (Modes brawl)", Brawl ~= nil and Brawl.Name == "BrawlService")
check("...and nobody on: it waits", Brawl:State() == "idle", Brawl:State())
check("the match's rules: no push, no turf rule", Match.rules.push == false and Match.rules.turf == false)

-- Two people join: both on the human side --------------------------------------------------------------------------
local ava = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = ava
Engine.localPlayer = ava
Engine.runScript(tree.client.Main)
local ben = Engine.addPlayer("Ben", 502)
Engine.advance(1)
Engine.fireServer(ben, "Ready")
Engine.advance(1)
check("everyone is on the human side", Teams:Team(ava) == "red" and Teams:Team(ben) == "red", Teams:Team(ben))
check("someone's on: a fresh run, the build phase first", Match:Phase() == "build" and Brawl:State() == "build")
check("...at wave 0", Brawl:Wave() == 0)
check("no bots in the build phase", #Bots:List() == 0)
check("the budget is the brawl's", Build:Budget(ava) == B.BUILD_BUDGET, Build:Budget(ava))
check("the turf is grass: green on the human half", Arena:Current().strips[1].Color == Constants.TURF_COLOR.red)
check("the frontline sits in the middle", Match:Frontline() == 0)
check("rebalancing never moves anyone", #Teams:Rebalance() == 0 and #Teams:SpreadDevices() == 0)
do
	-- building anywhere on the human half
	-- (a free cell: the maps have shapes about)
	local a = Arena:Current()
	local ok, why
	for x = -a.half / 2 - 16, -a.half / 2 + 16, 4 do
		for z = -24, 24, 4 do
			local cx, cz = Formulas.cellOf(x, z)
			Engine.moveTo(ava, Vector3.new(x + 6, 3, z))
			ok, why = Build:Place(ava, "wall", cx, cz, 0)
			if ok then
				break
			end
		end
		if ok then
			break
		end
	end
	check("a person builds on the human half", ok == true, why)
	local bx, bz = Formulas.cellOf(a.half / 2, 0)
	Engine.moveTo(ava, Vector3.new(a.half / 2 - 6, 3, 0))
	ok, why = Build:Place(ava, "wall", bx, bz, 0)
	check("...not on the bots'", ok == false and why == "Only on your own turf", why)
	Engine.moveTo(ava, Vector3.new(-a.half / 2, 3, 0))
end
-- the client: the wave pill in the HUD's slot, the HUD's own phase pill and bar hidden
local BrawlC = Engine.require(tree.client.Controllers.BrawlController)
local Hud = Engine.require(tree.client.Controllers.HudController)
local Fireworks = Engine.require(tree.client.Controllers.FireworksController)
Engine.advance(0.5)
check(
	"the client shows the brawl's top",
	BrawlC.refs.wave ~= nil and BrawlC.refs.wave.Text:find("BUILD") ~= nil,
	BrawlC.refs.wave and BrawlC.refs.wave.Text
)
check("...the frontline bar put away", Hud.refs.bar.Visible == false and Hud.refs.phasePill.Visible == false)
check("...a name over a teammate's head", ben.Character and ben.Character:FindFirstChild("MateTag") ~= nil)
check("...a Brawl state reached the client", Engine.lastClientEvent("Brawl") ~= nil)

-- Wave 1 --------------------------------------------------------------------------------------------------------
local m0 = mark()
Engine.advance(B.BUILD_SECONDS + 0.5)
check(
	"the build phase ends: the fight, and wave 1",
	Match:Phase() == "fight" and Brawl:State() == "wave" and Brawl:Wave() == 1,
	`{Match:Phase()} {Brawl:State()} {Brawl:Wave()}`
)
check("...called out", firedSince(m0, "Alert", nil, function(a)
	return a[1] == "WAVE 1"
end) ~= nil)
Engine.advance(B.SPAWN_GAP * 5)
local list = Bots:List()
check("wave 1: 3 + 1 bots", #list == B.BOTS_BASE + 1, #list)
local allBlue, onFarDeck = true, true
for _, b in list do
	if Teams:Team(b) ~= "blue" then
		allBlue = false
	end
	local r = root(b)
	if not r or r.Position.X < 0 then
		onFarDeck = false
	end
end
check("...all on the bots' side", allBlue)
check("...from the far deck", onFarDeck)
check("...counted in the match", #Match:Everyone() == 2 + #list)
check("...bots' tags say so", list[1].Character:FindFirstChild("BotTag") ~= nil)
check(
	"the client: WAVE 1 and how many are left",
	BrawlC.refs.wave.Text:find("WAVE 1") ~= nil and BrawlC.refs.wave.Text:find("LEFT") ~= nil,
	BrawlC.refs.wave.Text
)
-- they hunt across the field (no line holds them)
do
	local a = Arena:Current()
	Engine.moveTo(ava, Vector3.new(-a.half / 2, 3, 0))
	Engine.moveTo(ben, Vector3.new(-a.half / 2, 3, 10))
	local x0 = {}
	for _, b in list do
		x0[b] = root(b).Position.X
	end
	Engine.advance(6)
	local came = 0
	for _, b in list do
		local r = root(b)
		if r and r.Position.X < x0[b] - 4 then
			came += 1
		end
	end
	check("the bots come across the field toward the humans", came >= 2, came)
	-- a person may cross the line too (no turf rule)
	Engine.moveTo(ava, Vector3.new(20, 3, 0))
	Engine.advance(0.5)
	check(
		"a person may stand on the bots' half",
		root(ava) and root(ava).Position.X > 10,
		root(ava) and root(ava).Position.X
	)
	Engine.moveTo(ava, Vector3.new(-a.half / 2, 3, 0))
end
-- the director at rest
do
	local speed, sharp, spawn, mood = Brawl:Director()
	check(
		"the director at wave 1: plain bots",
		speed == 1 and sharp == 1 and spawn == 1 and mood == "normal",
		`{speed} {sharp} {spawn} {mood}`
	)
end
-- the last one, the clear
local m1 = mark()
local alive = aliveBots()
for i = 1, #alive - 1 do
	Combat:Kill(alive[i], ava, { weapon = "bow" })
end
Engine.advance(0.3)
check("one bot left: LAST ONE!", firedSince(m1, "Alert", nil, function(a)
	return a[1] == "LAST ONE!"
end) ~= nil and firedSince(m1, "Brawl", nil, function(a)
	return a[1].kind == "last"
end) ~= nil)
check("...the kill feed saw them go", firedSince(m1, "Kill", nil, function(a)
	return a[1].killer == ava.UserId and a[1].push == 0
end) ~= nil)
check("...and the line never moved", Match:Frontline() == 0)
Engine.advance(B.RESPAWN + 1)
check("a bot down stays down", #aliveBots() == 1, #aliveBots())
local m2 = mark()
Combat:Kill(aliveBots()[1], ben, { weapon = "bow" })
Engine.advance(0.3)
check("the wave's down: WAVE 1 CLEAR!", firedSince(m2, "Alert", nil, function(a)
	return a[1] == "WAVE 1 CLEAR!"
end) ~= nil)
check("...a breather follows", Brawl:State() == "breather", Brawl:State())
local clearEvent = firedSince(m2, "Brawl", nil, function(a)
	return a[1].kind == "clear"
end)
check(
	"...the clear goes to every client",
	clearEvent ~= nil
		and clearEvent.args[1].wave == 1
		and clearEvent.args[1].shards == B.SHARDS_WAVE + B.SHARDS_PER_WAVE
)
check("...Shards for everyone, WAVE CLEAR", firedSince(m2, "Earned", ava, function(a)
	return a[1].why == "wave" and a[1].amount == B.SHARDS_WAVE + B.SHARDS_PER_WAVE
end) ~= nil and firedSince(m2, "Earned", ben, function(a)
	return a[1].why == "wave"
end) ~= nil)
check(
	"...the best wave saved",
	Data:Get(ava).stats.brawlBest == 1 and Data:Get(ben).stats.brawlBest == 1 and ws:GetAttribute("BrawlBest") == 1
)
check(
	"...the fireworks on the client",
	BrawlC.shows() == 1 and Fireworks.active(),
	`{BrawlC.shows()} {tostring(Fireworks.active())}`
)
Engine.advance(1.2)
check("...the bots gone", #Bots:List() == 0 and #ws.Bots:GetChildren() == 0, #Bots:List())
-- the "brawl" board
do
	local board
	for _, b in Leaderboard.BOARDS do
		if b.key == "brawl" then
			board = b
		end
	end
	check('a "brawl" leaderboard: the best wave', board ~= nil and board.read(Data:Get(ava)) == 1)
end

-- Wave 2: the director, respawns, no wipe, a late joiner ---------------------------------------------------------
Engine.advance(B.BREATHER_SECONDS + 0.5)
check("after the breather, wave 2", Brawl:State() == "wave" and Brawl:Wave() == 2, `{Brawl:State()} {Brawl:Wave()}`)
Engine.advance(B.SPAWN_GAP * 6)
check("...with one bot more", #Bots:List() == B.BOTS_BASE + 2, #Bots:List())
do
	-- cruising: knockouts and no deaths press; losing (downs in a row) eases, and the bots feel it
	for _ = 1, B.KILLS_CRUISE do
		Brawl:Note("kill")
	end
	local speed, sharp, _, mood = Brawl:Director()
	check("cruising: the bots press", mood == "press" and sharp < 1 and speed > 1, `{speed} {sharp} {mood}`)
	for _ = 1, B.DOWN_STREAK do
		Brawl:Note("death")
	end
	local s2, sh2, sp2, mood2 = Brawl:Director()
	check(
		"losing: the bots get sloppy, slow, and come slower",
		mood2 == "easy" and sh2 > 1.4 and s2 < 1 and sp2 > 1,
		`{s2} {sh2} {sp2} {mood2}`
	)
	Engine.advance(0.3)
	local hs, hsp, hr = Bots.handicap(Bots:List()[1])
	check("...and every bot wears it", hs < 1 and hsp > 1.4 and hr > 1.4, `{hs} {hsp} {hr}`)
	Brawl:Note("kill") -- (the streak ends; the window still says losing)
	-- the ramp: a later wave is a touch faster and sharper on its own
	local w = Brawl:Wave()
	Brawl:_jumpTo(11)
	local s3, sh3 = Brawl:Director()
	Brawl:_jumpTo(w + 1)
	check("later waves: faster and sharper bots", s3 > s2 and sh3 < sh2, `{s3} {sh3}`)
end
-- a person down: back in RESPAWN seconds, at home
do
	local bot = aliveBots()[1]
	Combat:Kill(ava, bot, { weapon = "bow" })
	check("a person down", not Combat:Alive(ava))
	Engine.advance(B.RESPAWN + 0.5)
	check("...is back in 3 s", Combat:Alive(ava))
	check("...on the human deck", root(ava) and root(ava).Position.X < 0)
end
-- the whole side down: the bots freeze
do
	Engine.advance(Constants.SPAWN_PROTECT + 0.5)
	local bot = aliveBots()[1]
	local m3 = mark()
	Combat:Kill(ava, bot, { weapon = "bow" })
	Combat:Kill(ben, bot, { weapon = "bow" })
	Engine.advance(0.3)
	local stunned = 0
	for _, b in aliveBots() do
		if (b.stunUntil or 0) > Engine.now() then
			stunned += 1
		end
	end
	check("everyone down: the bots freeze", stunned == #aliveBots() and stunned > 0, stunned)
	check("...HOLD ON!", firedSince(m3, "Alert", nil, function(a)
		return a[1] == "HOLD ON!"
	end) ~= nil and firedSince(m3, "Brawl", nil, function(a)
		return a[1].kind == "stun"
	end) ~= nil)
	local p0 = root(bot).Position
	Engine.advance(1)
	check("...and stand still", (root(bot).Position - p0).Magnitude < 0.5, (root(bot).Position - p0).Magnitude)
	Engine.advance(B.RESPAWN)
	check("...while the people get back up", Combat:Alive(ava) and Combat:Alive(ben))
end
-- a late joiner drops straight in, on the human side
do
	local m4 = mark()
	local cy = Engine.addPlayer("Cy", 503)
	Engine.advance(0.5)
	Engine.fireServer(cy, "Ready")
	Engine.advance(1)
	check("a late joiner is on the human side", Teams:Team(cy) == "red", Teams:Team(cy))
	check("...with a body, mid-wave", root(cy) ~= nil and Combat:Alive(cy))
	check("...told the wave", firedSince(m4, "Brawl", cy, function(a)
		return a[1].kind == "state" and a[1].wave == 2
	end) ~= nil)
	check("...and nobody is ever on the bots' side", Teams:Count("red") == 3 and Teams:People("blue") == 0)
	Engine.removePlayer(cy)
	Engine.advance(0.5)
end

-- The set: wave 3 cleared brings a build phase; a boss on wave 5 ---------------------------------------------------
check("wave 2 cleared", clearWaveBy(ava) and Brawl:State() == "breather", Brawl:State())
Engine.advance(B.BREATHER_SECONDS + 0.5)
check("wave 3", Brawl:Wave() == 3 and Brawl:State() == "wave")
local m5 = mark()
check("...cleared: the set's over", clearWaveBy(ava))
Engine.advance(0.5)
check(
	"a build phase before the next set",
	Match:Phase() == "build" and Brawl:State() == "build",
	`{Match:Phase()} {Brawl:State()}`
)
check("...refilled", Build:Budget(ava) == B.BUILD_BUDGET)
check("...no bots about", #Bots:List() == 0)
check("...the best wave is 3", Brawl:Best() == 3 and Data:Get(ava).stats.brawlBest == 3)
check("...three clears, three shows", BrawlC.shows() == 3, BrawlC.shows())
Brawl:_jumpTo(B.BOSS_EVERY)
Engine.advance(B.BUILD_SECONDS + 0.5)
check(
	"the next set: a BOSS wave",
	Brawl:State() == "wave" and Brawl:Wave() == B.BOSS_EVERY,
	`{Brawl:State()} {Brawl:Wave()}`
)
check("...called out", firedSince(m5, "Alert", nil, function(a)
	return a[1] == `BOSS WAVE {B.BOSS_EVERY}`
end) ~= nil)
Engine.advance(B.SPAWN_GAP * 2)
local boss
for _, b in Bots:List() do
	if b:GetAttribute("Hits") == B.BOSS_HITS then
		boss = b
	end
end
check(
	"the first bot out is the boss, with 3 hits in it",
	boss ~= nil and boss.DisplayName == "Boss (bot)",
	boss and boss.DisplayName
)
check("...crowned, with a bar", boss and boss.Character:FindFirstChild("BotTag"):FindFirstChild("Bar") ~= nil)
check(
	"...the client shows the boss bar",
	BrawlC.refs.boss.Visible == true and BrawlC.refs.bossText.Text:find("3/3") ~= nil,
	BrawlC.refs.bossText.Text
)
do
	-- off its deck and out of its spawn shield, then three hits
	Engine.advance(Constants.SPAWN_PROTECT + 0.5)
	Engine.moveTo(boss, Vector3.new(10, 3, 0))
	local hit, killed = Combat:Damage(boss, 100, ava, { weapon = "bow", kind = "arrow" })
	check("one hit: the boss stands", Combat:Alive(boss) and boss:GetAttribute("Hits") == 2, boss:GetAttribute("Hits"))
	check("...a hit, not a knockout", hit == true and killed == false)
	Engine.advance(0.3)
	check("...the client's bar follows", BrawlC.refs.bossText.Text:find("2/3") ~= nil, BrawlC.refs.bossText.Text)
	Combat:Damage(boss, 100, ava, { weapon = "bow", kind = "arrow" })
	check("two hits: still up", Combat:Alive(boss) and boss:GetAttribute("Hits") == 1)
	local m7 = mark()
	Combat:Damage(boss, 100, ben, { weapon = "bow", kind = "arrow" })
	check("three hits: BOSS DOWN", not Combat:Alive(boss) and firedSince(m7, "Alert", nil, function(a)
		return a[1] == "BOSS DOWN!"
	end) ~= nil)
	check("...pays everyone", firedSince(m7, "Earned", ava, function(a)
		return a[1].why == "boss" and a[1].amount == B.SHARDS_BOSS
	end) ~= nil and firedSince(m7, "Earned", ben, function(a)
		return a[1].why == "boss"
	end) ~= nil)
end
-- a TNT bot in the wave (every TNT_EVERYth from TNT_FROM_WAVE on)
do
	clearWaveBy(ava)
	local hadTnt = false
	-- (the wave's bots are gone now: the next wave's are looked at as they come)
	Engine.advance(B.BREATHER_SECONDS + 0.5)
	Engine.advance(B.SPAWN_GAP * (B.BOTS_BASE + 7))
	for _, b in Bots:List() do
		if (b.tntChance or 0) > 0 then
			hadTnt = true
		end
	end
	check("some bots lob TNT from wave 3 on, the rest never", hadTnt)
	local never = true
	for _, b in Bots:List() do
		if b.tntChance == nil then
			never = false
		end
	end
	check("...each bot told its chance", never)
end

-- The run's end: wave 20 cleared is a victory, then a fresh run on a new map ----------------------------------------
clearWaveBy(ava)
check("waves 6 cleared", Brawl:State() == "breather" or Brawl:State() == "build", Brawl:State())
if Brawl:State() == "build" then
	Brawl:_jumpTo(B.LAST_WAVE)
	Engine.advance(B.BUILD_SECONDS + 0.5)
else
	Brawl:_jumpTo(B.LAST_WAVE)
	Engine.advance(B.BREATHER_SECONDS + 0.5)
end
check("the last wave", Brawl:Wave() == B.LAST_WAVE and Brawl:State() == "wave", `{Brawl:Wave()} {Brawl:State()}`)
local mapBefore = Match:MapKey()
local m8 = mark()
check("...cleared", clearWaveBy(ava, 400))
Engine.advance(0.5)
check(
	"the run is a victory for the humans",
	Match:Phase() == "victory" and ws:GetAttribute("Winner") == "red",
	Match:Phase()
)
check("...results for everyone, GREEN wins", firedSince(m8, "Results", ava, function(a)
	return a[1].winner == "red" and a[1].you.won == true
end) ~= nil and firedSince(m8, "Announce", nil, function(a)
	return a[1].text == "Green team wins!"
end) ~= nil)
check("...the best wave is 20", Brawl:Best() == B.LAST_WAVE and Data:Get(ava).stats.brawlBest == B.LAST_WAVE)
check("...no bots", #Bots:List() == 0)
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
check(
	"then a fresh run on a new map",
	Match:Phase() == "build" and Match:MapKey() ~= mapBefore and Brawl:Wave() == 0 and Brawl:State() == "build",
	`{Match:Phase()} {Match:MapKey()} {Brawl:Wave()}`
)
check("...everyone still on the human side", Teams:Team(ava) == "red" and Teams:Team(ben) == "red")
Engine.advance(B.BUILD_SECONDS + 1)
check("...wave 1 again", Brawl:Wave() == 1 and Brawl:State() == "wave")

-- Everyone leaves: the bots go, and the next person starts a run of their own ---------------------------------------
Engine.removePlayer(ava)
Engine.removePlayer(ben)
Engine.advance(1)
check(
	"nobody on: the run stops, the bots go",
	Brawl:State() == "idle" and #Bots:List() == 0,
	`{Brawl:State()} {#Bots:List()}`
)
local dee = Engine.addPlayer("Dee", 504)
Engine.advance(1)
Engine.fireServer(dee, "Ready")
Engine.advance(1)
check(
	"someone new: a run from the top",
	Brawl:State() == "build" and Match:Phase() == "build" and Teams:Team(dee) == "red",
	`{Brawl:State()} {Match:Phase()}`
)

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	failed += #Engine.errors
end
if failed > 0 then
	error("BrawlSmoke: " .. failed .. " failures")
end

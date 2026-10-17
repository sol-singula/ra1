--[[
Logs and analytics smoke test: boots the real server on the mock engine with the "discord_log" secret set and
sending on in Studio, plays a short match with two players (a shot, a build, a kill, a win, a Robux purchase, the
winners' card, an anti-cheat flag, an admin action, a tutorial step, a leave), then reads what actually went out
over HttpService (the mock keeps every request): the Discord game log (roblox-game-log) and the analytics
(roblox-analytics, in ra8's format, tagged ra9, with the live row the team's dashboard reads).

  luaurun tests/LogSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Instance = Engine.Instance

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

Engine.secrets.discord_log = "test-game-key"
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
-- the admin tools: the real AdminService if it's there, else a stand-in with just its Used signal
if not tree.server.Services:FindFirstChild("AdminService") then
	local stub = Instance.new("ModuleScript", tree.server.Services)
	stub.Name = "AdminService"
	rawset(stub, "_source", "tests/mock/AdminServiceStub.luau")
end
local Constants = Engine.require(tree.shared.Constants)
Constants.GAME_LOG_IN_STUDIO = true -- (the mock is Studio: send anyway, so the requests can be read)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Analytics = service("AnalyticsService")
local GameLog = service("GameLogService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Build = service("BuildService")
local Match = service("MatchService")
local Shop = service("ShopService")
local Feedback = service("FeedbackService")
local AC = service("AntiCheatService")
local Admin = service("AdminService")
local ShopData = Engine.require(tree.shared.Data.Shop)
local Formulas = Engine.require(tree.shared.Formulas)
local HttpService = Engine.game:GetService("HttpService")

local function send(player, name, ...)
	Engine.fireServer(player, name, ...)
	Engine.advance(0.05)
end

-- What went out: every request, decoded, by function
local function requests(url)
	local out = {}
	for _, r in Engine.httpRequests do
		if r.Url == url then
			table.insert(out, { req = r, body = HttpService:JSONDecode(r.Body) })
		end
	end
	return out
end
local function logTitles()
	local out = {}
	for _, r in requests(Constants.GAME_LOG_URL) do
		for _, e in r.body.events or {} do
			table.insert(out, e.title or "")
		end
	end
	return out
end
local function logged(fragment)
	for _, t in logTitles() do
		if string.find(t, fragment, 1, true) then
			return t
		end
	end
	return nil
end
local function allEvents()
	local out = {}
	for _, r in requests(Constants.ANALYTICS_URL) do
		for _, e in r.body.events or {} do
			table.insert(out, e)
		end
	end
	return out
end
local function events(kind, player)
	local out = {}
	for _, e in allEvents() do
		if e.kind == kind and (player == nil or e.user_id == player.UserId) then
			table.insert(out, e)
		end
	end
	return out
end
local function sessionRows(player)
	local merged = {}
	for _, r in requests(Constants.ANALYTICS_URL) do
		for _, row in r.body.sessions or {} do
			if row.user_id == player.UserId then
				merged[row.session_id] = merged[row.session_id] or {}
				for k, v in row do
					merged[row.session_id][k] = v
				end
			end
		end
	end
	local _, row = next(merged)
	return row or {}
end
local function flush()
	Analytics.flush()
	GameLog.flush()
end

-- Two players join -----------------------------------------------------------------------------------------------
local ava = Engine.addPlayer("Ava", 901)
local cy = Engine.addPlayer("Cy", 902)
Engine.advance(1)
send(ava, "Ready")
send(cy, "Ready")
send(ava, "Settings", "device", "touch")
Engine.advance(4) -- (the first snapshot comes 3 s after loading)
local red = Teams:Team(ava) == "red" and ava or cy
local blue = red == ava and cy or ava
check("two teams", Teams:Team(red) == "red" and Teams:Team(blue) == "blue")

-- The chat, a build, a shot, a kill, a win -----------------------------------------------------------------------
ava.Chatted:Fire("hi @everyone **look**")
Engine.moveTo(red, Vector3.new(-40, 3, -12))
Engine.advance(0.05)
local cx, cz = Formulas.cellOf(-44, -28)
local built = Build:Place(red, "wall", cx, cz, 0)
check("the red player built a wall", built == true)
Match:_setPhase("fight", 120)
Engine.advance(0.3)
send(red, "Draw", true)
Engine.advance(1)
local r = red.Character:FindFirstChild("HumanoidRootPart")
local origin = r.Position + Vector3.new(0, 1.5, 0)
send(red, "Shoot", origin, Vector3.new(1, 0.05, 0).Unit, 1)
Engine.advance(0.5)
Combat:Kill(blue, red, { weapon = "bow", head = true })
Engine.advance(0.3)
Shop:Grant(ava, ShopData.products.shards_s)
AC:Flag(cy, "speed", "a test flag", 3)
Admin.Used:Fire(ava, "end_match", "red")
Analytics.event(ava, "tutorial_step", { step = 2, key = "build" })
Analytics.event({ UserId = -1, Name = "Bot" }, "tutorial_step", { step = 1 }) -- (a bot: ignored)
-- the shop opened from the deck's sign (and the other ways in: "first_match", "results_strip")
send(ava, "Analytics", "shop", { tab = "shop", opening = true, from = "deck_sign" })
-- (their first match's shop already seen: the cards after this win are the ones checked here)
for _, p in { ava, cy } do
	service("PlayerDataService"):Get(p).gifts.firstShop = true
end
Engine.advance(0.2)
Match:Victory("red")
Engine.advance(Constants.FEEDBACK_ASK_DELAY + 1)
send(red, "Feedback", "enjoy", true)
Engine.advance(30) -- (the next match starts; a snapshot every 30 s)
flush()

-- Analytics --------------------------------------------------------------------------------------------------------
local aReqs = requests(Constants.ANALYTICS_URL)
check("analytics went out", #aReqs > 0)
check(
	"...with the game key, as JSON",
	#aReqs > 0
		and aReqs[1].req.Method == "POST"
		and aReqs[1].req.Headers["X-Game-Key"] == "test-game-key"
		and aReqs[1].req.Headers["Content-Type"] == "application/json"
)
do
	local ok = #aReqs > 0
	for _, a in aReqs do
		local b = a.body
		if
			b.game ~= "ra9"
			or type(b.server) ~= "table"
			or b.server.players == nil
			or type(b.sessions) ~= "table"
			or type(b.events) ~= "table"
		then
			ok = false
		end
	end
	check("every batch is { game = ra9, server, sessions, events } like ra8's", ok)
end
do
	local ok, n = true, 0
	for _, e in allEvents() do
		n += 1
		if
			type(e.session_id) ~= "string"
			or type(e.user_id) ~= "number"
			or type(e.t) ~= "number"
			or type(e.kind) ~= "string"
		then
			ok = false
		end
		if e.user_id < 0 then
			ok = false -- (a bot)
		end
	end
	check("every event has session_id, user_id, t, kind (and no bots)", ok and n > 0, n)
end
for _, kind in { "join", "loaded", "match_end", "snapshot" } do
	check(`both players: {kind}`, #events(kind, ava) >= 1 and #events(kind, cy) >= 1, kind)
end
check("the build: build and first_build", #events("build", red) == 1 and #events("first_build", red) == 1)
check("the shot: first_shot", #events("first_shot", red) == 1)
check("the kill: kill and first_kill", #events("kill", red) == 1 and #events("first_kill", red) == 1)
check(
	"...and the victim went down, by a player",
	#events("down", blue) == 1 and events("down", blue)[1].data.by == "player"
)
do
	local w = events("match_end", red)[1]
	local l = events("match_end", blue)[1]
	check(
		"match_end: won with the kills, lost with the deaths",
		w and w.data.won == true and w.data.kills == 1 and l and l.data.won == false and l.data.deaths == 1
	)
	check("first_win for the winner only", #events("first_win", red) == 1 and #events("first_win", blue) == 0)
	check(
		"events carry ctx (team, phase, map)",
		w and w.data.ctx and w.data.ctx.team == "red" and w.data.ctx.map ~= nil
	)
end
check(
	"the next match: match_start with its map",
	#events("match_start", ava) >= 1 and events("match_start", ava)[1].data.map ~= nil
)
check(
	"the Robux purchase: purchase with its Robux",
	#events("purchase", ava) == 1 and events("purchase", ava)[1].data.robux == 49
)
check(
	"the card after the match: winners and losers asked, then feedback, liked",
	#events("feedback_asked", red) == 1
		and #events("feedback_asked", blue) == 1
		and #events("feedback", red) == 1
		and events("feedback", red)[1].data.like == true
)
check(
	"the shop opened, and from where (shop_open's from)",
	#events("shop_open", ava) >= 1 and events("shop_open", ava)[#events("shop_open", ava)].data.from == "deck_sign"
)
check("the anti-cheat flag", #events("anticheat", cy) == 1)
check("the admin action", #events("admin", ava) == 1 and events("admin", ava)[1].data.action == "end_match")
check("AnalyticsService.event for other services", #events("tutorial_step", ava) == 1)
do
	local row = sessionRows(ava)
	check(
		"the session row: who, when, new, device",
		row.username == "Ava"
			and row.started_at ~= nil
			and row.is_new == true
			and row.session_no == 1
			and row.device == "touch",
		row.device
	)
	local l = row.live
	local want = {
		"team",
		"phase",
		"map",
		"kills",
		"deaths",
		"weapon",
		"alive",
		"wins",
		"ladder",
		"tier",
		"shards",
		"device",
		"idle",
	}
	local missing = {}
	for _, k in want do
		if not l or l[k] == nil then
			table.insert(missing, k)
		end
	end
	check("the live row has what the dashboard shows", #missing == 0, table.concat(missing, ","))
	check("...the live device and the shards", l and l.device == "touch" and l.shards >= 300)
end

-- Leaving --------------------------------------------------------------------------------------------------------
Engine.removePlayer(cy)
Engine.advance(0.5)
flush()
do
	local row = sessionRows(cy)
	check(
		"the session ends: ended_at, duration, reason, summary",
		row.ended_at ~= nil
			and type(row.duration_s) == "number"
			and row.end_reason == "left"
			and type(row.summary) == "table"
			and type(row.summary.counts) == "table"
			and row.summary.matches_session == 1,
		row.end_reason
	)
	check("the leave event", #events("leave", cy) == 1)
end

-- The Discord game log -----------------------------------------------------------------------------------------------
local gReqs = requests(Constants.GAME_LOG_URL)
check("the game log went out, with the key", #gReqs > 0 and gReqs[1].req.Headers["X-Game-Key"] == "test-game-key")
check("...with the server (game ra9)", #gReqs > 0 and gReqs[1].body.server.game == "ra9")
do
	local ok = #logTitles() > 0
	for _, t in logTitles() do
		if string.sub(t, 1, #"ra9 · ") ~= "ra9 · " then
			ok = false
		end
	end
	check("every entry starts with ra9", ok)
end
check("server started", logged("🟦 Server started") ~= nil)
check("joins: new", logged("🟢 @Ava joined · new") ~= nil, logged("joined"))
check(
	"the chat, as plain text",
	(function()
		for _, rq in gReqs do
			for _, e in rq.body.events do
				if e.title == "ra9 · 💬 Chat" then
					return e.description:find("@\u{200B}everyone", 1, true) ~= nil
						and e.description:find("\\*\\*look", 1, true) ~= nil
				end
			end
		end
		return false
	end)()
)
check(
	"the match won, with the score and the MVP",
	logged("🏆 RED won") ~= nil and logged("kills 1–0") ~= nil and logged("MVP") ~= nil,
	logged("won")
)
check("the next match on its map", logged("🗺️ Match 2 on ") ~= nil, logged("Match"))
check("the Robux purchase", logged("💸 @Ava bought Pocket of Shards · R$ 49") ~= nil, logged("bought"))
check("the anti-cheat flag", logged("🚩 Anti-cheat: @Cy (speed)") ~= nil)
check("the admin action", logged("🛡️ Ava used end match (red)") ~= nil, logged("used"))
check(
	"the leave, with how long and the matches",
	logged("🔴 @Cy left after") ~= nil and logged("1 match, ") ~= nil,
	logged("left")
)
check("Shards buys and the activity aren't posted", logged("shard") == nil)

-- The key: sent with it; a wrong one is turned away ----------------------------------------------------------------
do
	local GameKey = Engine.require(tree.server.GameKey)
	check("GameKey.post sends with the key", GameKey.post(Constants.GAME_LOG_URL, { events = {} }, "test") == true)
	Engine.httpStatus = 401
	check(
		"...and says no when the key is wrong",
		GameKey.post(Constants.GAME_LOG_URL, { events = {} }, "test") == false
	)
	Engine.httpStatus = 200
end

for _, e in Engine.errors do
	print("ERROR " .. tostring(e))
end
failed += #Engine.errors
print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("LogSmoke failed")
end

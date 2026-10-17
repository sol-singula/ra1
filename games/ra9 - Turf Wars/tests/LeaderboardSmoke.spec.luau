--[[
The leaderboards, server and client together on the mock engine: a player's numbers go to the all-time boards
(OrderedDataStores) when they join, after a match and when they leave, at most once a minute, only what changed,
never for a bot or a spectating admin, never past the DataStore budget, and a failed write is tried again; the top
50 of every board is read again on a timer (a failed read keeps the last good copy) and sent to whoever asked;
"this server" is worked out live. On screen: the 🏆 TOP button clear of the HUD at desktop and touch layouts, L (and
the pad's D-pad up) opening the panel with the mouse free, the tabs, ALL TIME / THIS SERVER, the medal tints, your
row, Esc / ✕ / B closing it with the mouse captured again.

  luaurun tests/LeaderboardSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector2 = Engine.globals.Vector2
local Enum = Engine.Enum

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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
local Constants = Engine.require(tree.shared.Constants)
Constants.TUTORIAL = false -- (the tutorial has its own test)
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
local UIS = Engine.game:GetService("UserInputService")
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Top = service("LeaderboardService")
local Data = service("PlayerDataService")
local Bots = service("BotService")
local Match = service("MatchService")

local function store(board)
	return Engine.orderedStores[string.format(Constants.LEADERBOARD_STORE, board)] or {}
end
local function sets(from)
	local n = 0
	for i = from + 1, #Engine.orderedCalls do
		if Engine.orderedCalls[i].op == "SetAsync" then
			n += 1
		end
	end
	return n
end
local function key(input)
	UIS.InputBegan:Fire({ KeyCode = input, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.3)
end

-- Alone with a bot: the player is written, the bot never ----------------------------------------------------------
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(3)
local bots = Bots:List()
check("alone: there's a bot", #bots >= 1, #bots)
check("a bot isn't written", Top:Write(bots[1]) == false)
check("nothing written for a new player with nothing yet", sets(0) == 0, sets(0))

local p = Data:Get(player)
p.wins, p.best, p.stats.kills, p.stats.mvps = 5, 3, 40, 2
local mark = #Engine.orderedCalls
check("a player is written", Top:Write(player) == true)
Engine.advance(0.1)
check(
	"...every board that has a number",
	store("wins")["501"] == 5
		and store("streak")["501"] == 3
		and store("kills")["501"] == 40
		and store("mvps")["501"] == 2,
	`{store("wins")["501"]} {store("streak")["501"]} {store("kills")["501"]} {store("mvps")["501"]}`
)
check("...four writes", sets(mark) == 4, sets(mark))
local botKeys = 0
for _, b in { "wins", "kills", "mvps", "streak" } do
	for k in store(b) do
		if (tonumber(k) or 0) <= 0 then
			botKeys += 1
		end
	end
end
check("...no bot on any board", botKeys == 0)

-- The throttle: once a minute, only what changed
p.wins = 6
mark = #Engine.orderedCalls
Top:Write(player)
Engine.advance(10)
check("a second write within the minute waits", store("wins")["501"] == 5 and sets(mark) == 0, sets(mark))
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS)
check("...and goes after it", store("wins")["501"] == 6, store("wins")["501"])
check("...only the board that changed", sets(mark) == 1, sets(mark))
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS + 1)
mark = #Engine.orderedCalls
Top:Write(player)
Engine.advance(Top.FLUSH_SECONDS + 0.5)
check("nothing changed: nothing written", sets(mark) == 0, sets(mark))

-- The budget, and a failed write tried again
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS + 1)
Engine.dataStoreBudget.SetIncrementSortedAsync = 0
p.wins = 7
mark = #Engine.orderedCalls
Top:Write(player)
Engine.advance(Top.FLUSH_SECONDS + 0.5)
check("no budget: nothing is sent", sets(mark) == 0 and store("wins")["501"] == 6, sets(mark))
Engine.dataStoreBudget.SetIncrementSortedAsync = nil
Engine.advance(Top.FLUSH_SECONDS + 0.5)
check("...budget back: written", store("wins")["501"] == 7, store("wins")["501"])
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS + 1)
Engine.orderedFails = true
p.wins = 8
Top:Write(player)
Engine.advance(Top.FLUSH_SECONDS + 0.5)
check("a write that fails: not lost", store("wins")["501"] == 7)
Engine.orderedFails = false
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS + Top.FLUSH_SECONDS + 1)
check("...tried again later", store("wins")["501"] == 8, store("wins")["501"])

-- The refresh: the top 50, names, the last good copy ----------------------------------------------------------------
for i = 1, 60 do
	store("wins")[tostring(1000 + i)] = i
end
store("kills")["1060"] = 999
check("a refresh reads every board", Top:Refresh() == true)
local pay = Top:Payload(player)
local wins = pay.boards.wins
check("...the top 50, no more", #wins == 50, #wins)
check(
	"...best first",
	wins[1].value == 60 and wins[1].userId == 1060 and wins[2].value == 59,
	wins[1] and wins[1].value
)
check("...ranks 1, 2, 3...", wins[1].rank == 1 and wins[50].rank == 50)
check("...with names from Roblox", wins[1].name == "Name1060", wins[1].name)
check("...the people here by their own names", pay.boards.kills[2].name == "Ava", pay.boards.kills[2].name)
check("...you: your rank and number", pay.you.kills.rank == 2 and pay.you.kills.value == 40, pay.you.kills.rank)
check("...outside the top 50: no rank, still your number", pay.you.wins.rank == nil and pay.you.wins.value == 8)
check("...ok, and when", pay.ok == true and pay.at > 0)
Engine.orderedFails = true
check("a refresh that fails...", Top:Refresh() == false)
check("...keeps the last good copy", #Top:Payload(player).boards.wins == 50)
Engine.orderedFails = false

-- Others here: the server view, a spectating admin -------------------------------------------------------------
local foe = Engine.addPlayer("Foe", 900)
Engine.advance(1)
Engine.fireServer(foe, "Ready")
Engine.advance(1)
Data:Get(foe).stats.kills = 55
local owner = Engine.addPlayer("Owner", 11787294097, nil, { adminSpectate = true })
Engine.advance(1)
Engine.fireServer(owner, "Ready")
Engine.advance(1)
check("the bots go when a second person comes", #Bots:List() == 0, #Bots:List())
check("a spectating admin isn't written", Top:Write(owner) == false and store("wins")["11787294097"] == nil)
pay = Top:Payload(player)
local here = pay.server.kills
check("this server: everyone here, best first", #here == 2 and here[1].name == "Foe" and here[2].name == "Ava", #here)
check("...not the spectating admin", here[1].userId ~= 11787294097 and here[2].userId ~= 11787294097)
check("...your place here", pay.you.kills.serverRank == 2, pay.you.kills.serverRank)

-- On screen: the button, the panel -----------------------------------------------------------------------------
local TopC = Engine.require(tree.client.Controllers.LeaderboardController)
local Camera = Engine.require(tree.client.Controllers.CameraController)
local Hud = Engine.require(tree.client.Controllers.HudController)
local Layout = Engine.require(tree.client.UI.Layout)
local Device = Engine.require(tree.client.UI.Device)
local Theme = Engine.require(tree.client.UI.Theme)
local refs = TopC.refs
check("the TOP button is there", refs.button ~= nil and refs.button.Visible ~= false)
check("...it says L on a keyboard", refs.buttonHead.Text:find("[L]", 1, true) ~= nil, refs.buttonHead.Text)

-- the button against everything at the top right, on a keyboard and on a phone
local W, H = Theme.MIN_WIDTH, Theme.DESIGN.Y
local function rect(o)
	local par = o.Parent
	local px, py, pw, ph = 0, 0, W, H
	if par and not par:IsA("ScreenGui") then
		px, py, pw, ph = table.unpack(rect(par))
	end
	local ap = o.AnchorPoint or Vector2.new(0, 0)
	local w = o.Size.X.Scale * pw + o.Size.X.Offset
	local h = o.Size.Y.Scale * ph + o.Size.Y.Offset
	return {
		px + o.Position.X.Scale * pw + o.Position.X.Offset - ap.X * w,
		py + o.Position.Y.Scale * ph + o.Position.Y.Offset - ap.Y * h,
		w,
		h,
	}
end
local function hits(a, b)
	local ra, rb = rect(a), rect(b)
	return ra[1] < rb[1] + rb[3] and rb[1] < ra[1] + ra[3] and ra[2] < rb[2] + rb[4] and rb[2] < ra[2] + ra[4]
end
for _, kind in { "keyboard", "touch" } do
	Device.set(kind)
	Engine.advance(0.1)
	for i = 1, 2 do
		Hud.showUnlock({ step = { kind = "trail", key = "trail_" .. i, name = "Long Streak" }, wins = i })
	end
	Engine.advance(0.1)
	local hr = Hud.refs
	local others = { Feed = hr.feed, Top = hr.gui.Top, Invite = hr.invite, Popup = Hud.popups()[1] }
	for name, t in hr.touch or {} do
		if t.Visible then
			others["touch " .. name] = t
		end
	end
	local bad = {}
	for name, o in others do
		if o and hits(refs.button, o) then
			table.insert(bad, name)
		end
	end
	local r = rect(refs.button)
	check(`{kind}: the TOP button overlaps nothing`, #bad == 0, table.concat(bad, ", "))
	check(`{kind}: ...in the top right corner, on screen`, r[1] > W / 2 and r[2] < 40 and r[1] + r[3] <= W, r[1])
end
check("on a phone the button doesn't say L", refs.buttonHead.Text:find("[L]", 1, true) == nil)
Device.set("keyboard")
Engine.advance(0.1)

-- L opens it: the mouse is free; the client asked and the server answered
local asked = Engine.countClientEvents("Top")
check("closed at first, the mouse with the camera", not TopC.isOpen() and not Camera.mouseFree())
key(Enum.KeyCode.L)
check("L opens the panel", TopC.isOpen() and refs.panel.Visible == true)
check("...the mouse is free", Layout.panel() and Layout.modalOpen() and Camera.mouseFree() and refs.close.Modal == true)
check("...it asked the server", Engine.countClientEvents("Top") == asked + 1)
local sent = Engine.lastClientEvent("Leaderboards", player)
check("...the server answered", sent ~= nil and sent.args[1].boards.wins ~= nil and sent.args[1].server.wins ~= nil)
check("...and the panel has its data", TopC.state() ~= nil and #TopC.state().boards.wins == 50)
local function rows()
	local out = {}
	for _, c in refs.list:GetChildren() do
		if c.Name:sub(1, 3) == "Row" then
			out[tonumber(c.Name:sub(4))] = c
		end
	end
	return out
end
check("ALL TIME, WINS first: 50 rows", #rows() == 50 and TopC.tab() == "wins" and TopC.scope() == "all", #rows())
local r = rows()
check("...rank, name, number", r[1].Rank.Num.Text == "1" and r[1].Who.Text == "Name1060" and r[1].Value.Text == "60")
check(
	"...the top three gold, silver, bronze",
	r[1].Rank.BackgroundColor3 == TopC.MEDAL[1][1]
		and r[2].Rank.BackgroundColor3 == TopC.MEDAL[2][1]
		and r[3].Rank.BackgroundColor3 == TopC.MEDAL[3][1]
		and r[1].BackgroundColor3 == TopC.MEDAL[1][2]
		and r[4].BackgroundColor3 ~= TopC.MEDAL[3][2]
)
check("...you're not in it: your line says so", refs.you.Text:find("not in the top 50") ~= nil, refs.you.Text)

-- the tabs
refs.tabs.kills.Activated:Fire()
Engine.advance(0.1)
r = rows()
check("KILLS: its board", TopC.tab() == "kills" and r[1].Value.Text == "999" and refs.valueHead.Text == "KILLS")
check(
	"...your row is black, with (you)",
	r[2].BackgroundColor3 == Theme.Color.ink and r[2].Who.Text:find("(you)", 1, true) ~= nil
)
check(
	"...the tab is picked",
	refs.tabs.kills.BackgroundColor3 == Theme.Color.ink and refs.tabs.wins.BackgroundColor3 == Theme.Color.white
)
check("...your line: #2", refs.you.Text:find("#2", 1, true) ~= nil, refs.you.Text)
refs.tabs.mvps.Activated:Fire()
Engine.advance(0.1)
check("MVP: its board", TopC.tab() == "mvps" and rows()[1].Value.Text == "2" and refs.valueHead.Text == "MVPS")
refs.tabs.streak.Activated:Fire()
Engine.advance(0.1)
check(
	"STREAK: its board",
	TopC.tab() == "streak" and rows()[1].Value.Text == "3" and refs.valueHead.Text == "BEST STREAK"
)

-- THIS SERVER
refs.tabs.kills.Activated:Fire()
refs.server.Activated:Fire()
Engine.advance(0.1)
r = rows()
check(
	"THIS SERVER: the people here",
	TopC.scope() == "server" and #rows() == 2 and r[1].Who.Text == "Foe" and r[1].Value.Text == "55",
	#rows()
)
check("...your line: your place here", refs.you.Text:find("#2 here", 1, true) ~= nil, refs.you.Text)
refs.all.Activated:Fire()
Engine.advance(0.1)
check("...and back to ALL TIME", TopC.scope() == "all" and #rows() == 2, #rows())

-- the pieces inside the panel apart and inside it
local function inside(container)
	local bad = {}
	local cr = rect(container)
	local kids = {}
	for _, k in container:GetChildren() do
		if k:IsA("GuiObject") and k.Visible ~= false then
			table.insert(kids, k)
		end
	end
	for i, a in kids do
		local ar = rect(a)
		if ar[1] < cr[1] - 0.5 or ar[1] + ar[3] > cr[1] + cr[3] + 0.5 then
			table.insert(bad, a.Name .. " sticks out")
		end
		for j = i + 1, #kids do
			if hits(a, kids[j]) then
				table.insert(bad, a.Name .. " x " .. kids[j].Name)
			end
		end
	end
	return bad
end
local bad = inside(refs.panel)
for _, b in inside(rows()[1]) do
	table.insert(bad, b)
end
check("the panel: nothing overlaps, nothing sticks out", #bad == 0, table.concat(bad, ", "))
local pr = rect(refs.panel)
check(
	"...the panel is on screen, under the top bar",
	pr[1] >= 0 and pr[1] + pr[3] <= W and pr[2] >= 84 and pr[2] + pr[4] <= H
)

-- a refresh reaches the open panel; so does a match's end
refs.tabs.wins.Activated:Fire()
store("wins")["1061"] = 500
local before = Engine.countClientEvents("Leaderboards")
Engine.advance(Constants.LEADERBOARD_REFRESH_SECONDS + Top.FLUSH_SECONDS)
check("the refresh is sent to who asked", Engine.countClientEvents("Leaderboards") > before)
check("...and shows in the open panel", rows()[1].Value.Text == "500" and rows()[1].Who.Text == "Name1061")

-- Esc closes it, the mouse goes back to the camera
key(Enum.KeyCode.Escape)
check("Esc closes it", not TopC.isOpen() and not Layout.panel() and not Camera.mouseFree())
TopC.open()
refs.close.Activated:Fire()
Engine.advance(0.1)
check("✕ closes it", not TopC.isOpen() and not Camera.mouseFree())
-- a pad: D-pad up, the shoulders change tabs, Y flips the scope, B closes
key(Enum.KeyCode.DPadUp)
check("D-pad up opens it", TopC.isOpen())
key(Enum.KeyCode.ButtonR1)
check("RB: the next tab", TopC.tab() == "kills", TopC.tab())
key(Enum.KeyCode.ButtonL1)
key(Enum.KeyCode.ButtonL1)
check("LB: back two, round the end (the tycoon board is last)", TopC.tab() == "tycoon", TopC.tab())
key(Enum.KeyCode.ButtonY)
check("Y: THIS SERVER", TopC.scope() == "server")
key(Enum.KeyCode.ButtonB)
check("B closes it", not TopC.isOpen() and not Layout.panel())
key(Enum.KeyCode.L)
key(Enum.KeyCode.L)
check("L again closes it", not TopC.isOpen())
-- on a phone: a tap on the button
Device.set("touch")
refs.button.Activated:Fire()
Engine.advance(0.1)
check("a tap opens it on a phone", TopC.isOpen() and Layout.panel())
refs.button.Activated:Fire()
Engine.advance(0.1)
check("...and closes it", not TopC.isOpen() and not Layout.panel())
Device.set("keyboard")

-- The match's end and leaving: written -------------------------------------------------------------------------
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS + 1)
local mark2 = #Engine.orderedCalls
Match:Victory("red")
Engine.advance(1)
local winsAfter = Data:Get(player).wins
check("a match's end writes everyone's numbers", sets(mark2) >= 1, sets(mark2))
check("...the foe's kills are on the board", store("kills")["900"] == 55, store("kills")["900"])
check("...yours too", store("wins")["501"] == winsAfter, `{store("wins")["501"]} {winsAfter}`)
local events = Engine.countClientEvents("Leaderboards")
check("...and who asked gets the new numbers", events >= before + 2, events)
Data:Get(foe).stats.kills = 60
Engine.removePlayer(foe)
Engine.advance(1)
check("leaving within the minute: waits...", store("kills")["900"] == 55)
Engine.advance(Constants.LEADERBOARD_WRITE_SECONDS + Top.FLUSH_SECONDS)
check("...then written, after they've gone", store("kills")["900"] == 60, store("kills")["900"])

-- shutting down: what's waiting goes at once
Data:Get(player).stats.kills = 41
Top:Write(player)
Engine.advance(0.1)
Data:Get(player).stats.kills = 42
Top:Write(player)
Engine.advance(0.1)
check("waiting before shutdown", store("kills")["501"] == 41, store("kills")["501"])
for _, fn in Engine.closeHandlers do
	Engine.task.spawn(fn)
end
Engine.advance(1)
check("...written at shutdown", store("kills")["501"] == 42, store("kills")["501"])

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("LeaderboardSmoke: " .. failed .. " failures")
end

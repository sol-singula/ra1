--[[
Admins: the owner (Constants.ADMINS) gets the admin panel; everyone else is refused every action. An admin can
watch any server unseen (the server list in the MemoryStore, a teleport with { adminSpectate = true }): a
spectating admin has no body, no team, isn't counted (a lone player with one still gets bots), can't be hit, and
isn't in the results. The match controls (end with a winner or a draw, skip, stop the clock, restart, map, bots,
announce) and the player controls (team, knock out, heal, MVP, VIP, Shards, tiers, cosmetics, reset shop, go to,
bring, kick) all work and are logged (AdminService.Used). Then the real client: the ADMIN button, the panel's tabs
laid out without overlaps, a button press reaching the server, and the spectator camera.

  luaurun tests/AdminSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local Enum = Engine.Enum
local mockTime = Engine.globals.os.time

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
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Admin = service("AdminService")
local Bots = service("BotService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Match = service("MatchService")
local Data = service("PlayerDataService")
local Status = service("StatusService")
local Season = service("SeasonService")
local AntiCheat = service("AntiCheatService")
local Constants = Engine.require(tree.shared.Constants)
local Locker = Engine.require(tree.shared.Data.Locker)
local Shop = Engine.require(tree.shared.Data.Shop)
local SeasonData = Engine.require(tree.shared.Data.Season)
local Admins = Engine.require(tree.server.Admins)

local OWNER = 11787294097
local used = {}
Admin.Used:Connect(function(admin, action, detail)
	table.insert(used, { admin = admin, action = action, detail = detail })
end)

local function root(who)
	return who.Character and who.Character:FindFirstChild("HumanoidRootPart")
end
local function since(n, name, player)
	local out = {}
	for i = n + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == name and (player == nil or e.player == player or e.player == "all") then
			table.insert(out, e)
		end
	end
	return out
end
local function announced(n, text)
	for _, e in since(n, "Announce") do
		if e.args[1].text == text then
			return e.args[1]
		end
	end
	return nil
end
local function act(player, action, target, value)
	Engine.fireServer(player, "Admin", action, target, value)
	Engine.advance(0.3)
end

-- one real player: bots
local solo = Engine.addPlayer("Solo", 801)
Engine.advance(1)
Engine.fireServer(solo, "Ready")
Engine.advance(2)
check("one player: a bot joins", #Bots:List() == 1, #Bots:List())
local soloTeam = Teams:Team(solo)

-- the owner arrives from the server list: spectating
local owner = Engine.addPlayer("Owner", OWNER, nil, { adminSpectate = true })
Engine.advance(1)
Engine.fireServer(owner, "Ready")
Engine.advance(2)
check("the owner is an admin", Admins.isAdmin(owner) and owner:GetAttribute("Admin") == true)
check("...a player isn't", not Admins.isAdmin(solo) and solo:GetAttribute("Admin") == nil)
check("arriving with adminSpectate: spectating", Admins.spectating(owner))
check("...no body", owner.Character == nil)
check("...no team", Teams:Team(owner) == nil, Teams:Team(owner))
check("...not counted in the match", table.find(Match:Everyone(), owner) == nil and #Match:People() == 1)
check("...the team counts leave them out", Teams:Count("red") + Teams:Count("blue") == 2) -- (solo and the bot)
check("...the lone player keeps their bot", #Bots:List() == 1, #Bots:List())
check("...and keeps their team (no takeover)", Teams:Team(solo) == soloTeam)
check("...can't be hit", not Combat:Alive(owner) and Combat:Damage(owner, 50, Bots:List()[1]) == false)
check("...the panel's data arrives", Engine.lastClientEvent("AdminState", owner) ~= nil)
local rows = Match:Results("red").rows
local inRows = false
for _, r in rows do
	if r.userId == OWNER then
		inRows = true
	end
end
check("...not in the results", not inRows and #rows == 1, #rows)

-- everyone else is refused, every action
do
	local p = Data:Get(solo)
	local shards0, phase0, team0 = p.shards, Match:Phase(), Teams:Team(solo)
	local n0 = #Engine.clientLog
	local actions = {
		{ "state" },
		{ "servers" },
		{ "join", nil, "other-job" },
		{ "spectate", nil, true },
		{ "invisible", nil, true },
		{ "unlockall" },
		{ "tutorial" },
		{ "end", nil, "red" },
		{ "skip", nil, "fight" },
		{ "restart" },
		{ "map", nil, "frost" },
		{ "bots", nil, false },
		{ "freeze", nil, true },
		{ "announce", nil, "hi" },
		{ "team", solo.UserId, team0 == "red" and "blue" or "red" },
		{ "kill", solo.UserId },
		{ "heal", solo.UserId },
		{ "kick", owner.UserId, "x" },
		{ "mvp", solo.UserId },
		{ "vip", solo.UserId, "forever" },
		{ "shards", solo.UserId, 10000 },
		{ "tiers", solo.UserId, 30 },
		{ "cosmetic", solo.UserId, "shop_echo" },
		{ "resetshop", solo.UserId },
		{ "goto", owner.UserId },
		{ "bring", owner.UserId },
	}
	local allRefused = true
	for _, a in actions do
		local ok = Admin:Do(solo, a[1], a[2], a[3])
		if ok then
			allRefused = false
			print("  not refused: " .. a[1])
		end
		Engine.fireServer(solo, "Admin", a[1], a[2], a[3])
	end
	Engine.advance(1)
	check("a player: every action refused", allRefused)
	check("...nothing changed", p.shards == shards0 and Match:Phase() == phase0 and Teams:Team(solo) == team0)
	check("...still in the match, not spectating", Combat:Alive(solo) and not Admins.spectating(solo))
	check("...no VIP, no MVP", solo:GetAttribute("VIP") ~= true and Status:Mvp() ~= solo)
	check("...no admin data sent to them", #since(n0, "AdminState", solo) == 0)
	check("...no banner", #since(n0, "Announce") == 0)
	check("...nothing logged", #used == 0, #used)
	check("...nobody kicked", owner._kicked == nil and solo._kicked == nil)
	check("...no teleport", #Engine.teleports == 0)
end

-- the server list: this server's line, another's, a stale one
do
	local ok = Admin:Heartbeat()
	local map = Engine.memory[Constants.ADMIN_SERVER_MAP] or {}
	local mine = map.studio
	check("the heartbeat writes this server's line", ok and mine ~= nil)
	check(
		"...its players (not the spectating admin)",
		mine and mine.players == 1 and #mine.names == 1 and mine.names[1] == "Solo",
		mine and mine.players
	)
	check("...its map and phase", mine and type(mine.map) == "string" and mine.phase == Match:Phase())
	map["other-job"] = {
		jobId = "other-job",
		players = 7,
		names = { "A", "B" },
		map = "Frostbite",
		phase = "fight",
		red = 4,
		blue = 3,
		frontline = 12,
		at = mockTime(),
	}
	map["dead-job"] = { jobId = "dead-job", players = 3, names = {}, at = mockTime() - 1000 }
	local n0 = #Engine.clientLog
	act(owner, "servers")
	local e = since(n0, "AdminState", owner)
	local list = e[#e] and e[#e].args[1].servers or {}
	local ids = {}
	for _, s in list do
		ids[s.jobId] = s
	end
	check("the list: every live server", ids["other-job"] ~= nil and ids.studio ~= nil, #list)
	check("...not one that stopped talking", ids["dead-job"] == nil)
	check("...this one marked", ids.studio and ids.studio.here == true and not ids["other-job"].here)
	check("...the busiest first", list[1] and list[1].jobId == "other-job")
	act(owner, "join", nil, "other-job")
	local t = Engine.teleports[#Engine.teleports]
	local opts = t and t.options
	check("JOIN teleports the admin", t ~= nil and t.players[1] == owner)
	check("...to that server", opts and opts.ServerInstanceId == "other-job")
	check("...to spectate there", opts and opts:GetTeleportData() and opts:GetTeleportData().adminSpectate == true)
	check("...logged", used[#used] and used[#used].action == "join" and used[#used].detail == "other-job")
end

-- the anti-cheat leaves admins alone
AntiCheat:Flag(owner, "speed", "test", 10)
check("the anti-cheat never flags an admin", AntiCheat:Strikes(owner) == 0 and owner._kicked == nil)

-- back to playing: a bot's place, and the bots go
act(owner, "spectate", nil, false)
Engine.advance(1)
check("leaving spectate: a team", Teams:Team(owner) ~= nil and not Admins.spectating(owner))
check("...against the lone player (the bot's place)", Teams:Team(owner) ~= Teams:Team(solo))
check("...a body", root(owner) ~= nil and Combat:Alive(owner))
check("...the bots go (two people)", #Bots:List() == 0, #Bots:List())
check("...counted", #Match:People() == 2)
Engine.advance(0.5)
local tag = owner.Character and owner.Character:FindFirstChild("StatusTag")
local tagText = ""
for _, l in tag and tag:GetChildren() or {} do
	tagText ..= (l.Text or "") .. "|"
end
check("a red ADMIN tag over the admin", string.find(tagText, "ADMIN") ~= nil, tagText)

-- invisible
act(owner, "invisible", nil, true)
Engine.advance(0.2)
local seen = 0
for _, d in owner.Character:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		seen += 1
	end
end
check("invisible: every part hidden", seen == 0, seen)
check("...no name tag", owner.Character:FindFirstChild("StatusTag") == nil)
act(owner, "invisible", nil, false)
Engine.advance(0.3)
check("...and seen again", owner.Character:FindFirstChild("StatusTag") ~= nil)

-- player controls
do
	local other = Teams:Team(solo) == "red" and "blue" or "red"
	act(owner, "team", solo.UserId, other)
	check("switch team", Teams:Team(solo) == other, Teams:Team(solo))
	check("...a fresh body on that side", Combat:Alive(solo) and solo.Character:GetAttribute("Team") == other)

	local p = Data:Get(solo)
	local s0 = p.shards
	act(owner, "shards", solo.UserId, 1000)
	check("give Shards", p.shards == s0 + 1000, p.shards)
	act(owner, "shards", solo.UserId, -50)
	check("...never a strange amount", p.shards == s0 + 1000)

	local n0 = #Engine.clientLog
	local mvps = p.stats.mvps
	act(owner, "mvp", solo.UserId)
	check("give MVP: the crown", Status:Mvp() == solo)
	check("...counted like a real one", p.stats.mvps == mvps + 1)
	local b = announced(n0, "Solo is MVP!")
	check("...announced to everyone", b ~= nil and b.icon == "👑" and b.kind == "status")
	check("...the crown on their head", solo.Character:FindFirstChild("MvpCrown") ~= nil)

	n0 = #Engine.clientLog
	act(owner, "vip", solo.UserId, "1d")
	check("give VIP for a day", solo:GetAttribute("VIP") == true)
	check("...until tomorrow", (p.vipUntil or 0) > mockTime() + 86000 and not p.vip, p.vipUntil)
	b = announced(n0, "Solo got VIP!")
	check("...announced to everyone", b ~= nil and b.icon == "⭐")
	check("...the VIP cosmetics with it", Locker.owns(p, "vip_trail"))
	act(owner, "vip", solo.UserId, "remove")
	check("remove VIP", solo:GetAttribute("VIP") == false and not Locker.owns(p, "vip_trail"))
	act(owner, "vip", solo.UserId, "forever")
	check("VIP for good", p.vip == true and solo:GetAttribute("VIP") == true)
	act(owner, "vip", solo.UserId, "9y")
	check("...a length that isn't on the list: refused", used[#used].detail ~= "9y")

	act(owner, "cosmetic", solo.UserId, "shop_echo")
	check("give a cosmetic: owned", Locker.owns(p, "shop_echo"))
	check("...and worn", p.equipped.trail == "shop_echo" and solo:GetAttribute("LookTrail") == "shop_echo")
	local ladderKey = Engine.require(tree.shared.Data.Ladder).steps[40].key
	act(owner, "cosmetic", solo.UserId, ladderKey)
	check("...even one from the ladder", Locker.owns(p, ladderKey))
	act(owner, "cosmetic", solo.UserId, "not_a_thing")
	check("...not something that doesn't exist", p.owned.not_a_thing == nil)

	local tier0 = SeasonData.tierOf(Season:State(solo).xp)
	act(owner, "tiers", solo.UserId, 5)
	check("give pass tiers", SeasonData.tierOf(Season:State(solo).xp) == tier0 + 5)

	local day = Shop.dayOf(math.floor(ws:GetServerTimeNow()))
	local before = table.concat(Shop.daily(day), ",")
	act(owner, "resetshop", solo.UserId)
	check("reset shop: a new roll for them", solo:GetAttribute("ShopRoll") == 1)
	check("...4 other items today", table.concat(Shop.daily(day, 1), ",") ~= before)

	if Match:Phase() == "build" then
		act(owner, "skip", nil, "fight")
	end
	act(owner, "kill", solo.UserId)
	check("knock out", not Combat:Alive(solo))
	local k = Engine.lastClientEvent("Kill")
	check("...in the feed as an admin's", k and k.args[1].kind == "admin" and k.args[1].killer == nil)
	act(owner, "heal", solo.UserId)
	check("heal a player who's down: back now", Combat:Alive(solo))

	act(owner, "goto", solo.UserId)
	check("go to them", (root(owner).Position - root(solo).Position).Magnitude < 8)
	Engine.moveTo(owner, Vector3.new(30, 3, 30))
	act(owner, "bring", solo.UserId)
	check("bring them", (root(owner).Position - root(solo).Position).Magnitude < 8)
end

-- play the tutorial yourself
do
	local n0 = #Engine.clientLog
	act(owner, "tutorial")
	local started = false
	for i = n0 + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Tutorial" and e.player == owner and e.args[1].kind == "start" and e.args[1].replay then
			started = true
		end
	end
	check("PLAY TUTORIAL: it starts for you, from the top", started)
end

-- match controls
do
	local n0 = #Engine.clientLog
	act(owner, "announce", nil, "  Hello badword  ")
	local b = announced(n0, "Hello #######")
	check("announce: a banner for everyone, filtered", b ~= nil and b.kind == "admin")
	act(owner, "announce", nil, "   ")
	check("...not an empty one", #since(n0, "Announce") == 1)

	if Match:Phase() ~= "build" then
		act(owner, "skip", nil, "build")
	end
	check("skip to build", Match:Phase() == "build")
	act(owner, "skip", nil, "fight")
	check("skip to fight", Match:Phase() == "fight")

	act(owner, "freeze", nil, true)
	local left = ws:GetAttribute("PhaseEnds") - ws:GetServerTimeNow()
	Engine.advance(5)
	local after = ws:GetAttribute("PhaseEnds") - ws:GetServerTimeNow()
	check("stop the clock", Match:Frozen() and math.abs(after - left) < 1.5, `{left} -> {after}`)
	act(owner, "freeze", nil, false)
	Engine.advance(2)
	check("...start it again", not Match:Frozen() and ws:GetAttribute("PhaseEnds") - ws:GetServerTimeNow() < left - 1)

	act(owner, "map", nil, "frost")
	check("change the map: a new match there", Match:MapKey() == "frost" and Match:Phase() == "build", Match:MapKey())
	act(owner, "restart")
	check("restart", Match:MapKey() == "frost" and Match:Phase() == "build")

	if Teams:Team(solo) == Teams:Team(owner) then
		act(owner, "team", solo.UserId, Teams:Team(owner) == "red" and "blue" or "red")
	end
	n0 = #Engine.clientLog
	local red = Teams:Team(owner) == "red" and owner or solo
	local blue = red == owner and solo or owner
	local redWins = Data:Get(red).wins
	act(owner, "end", nil, "blue")
	check("end the match: BLUE wins", Match:Phase() == "victory" and ws:GetAttribute("Winner") == "blue")
	local res = since(n0, "Results", blue)
	check("...the normal results", #res > 0 and res[#res].args[1].winner == "blue")
	check(
		"...blue won, red lost",
		res[#res].args[1].you.won == true and Data:Get(red).wins == redWins,
		`{Teams:Team(owner)} {Teams:Team(solo)} {res[#res].args[1].you.won} {Data:Get(red).wins} {redWins}`
	)
	check("...logged", used[#used].action == "end" and used[#used].detail == "blue")
	-- an admin's new match during the results: the old countdown doesn't start another one
	act(owner, "restart")
	local id = Match:Snapshot().matchId
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 2)
	check("a restart during the results isn't undone", Match:Snapshot().matchId == id and Match:Phase() ~= "victory")

	local losses = Data:Get(solo).stats.losses
	local streak = Data:Get(solo).streak
	n0 = #Engine.clientLog
	act(owner, "end", nil, "draw")
	check("a draw", Match:Phase() == "victory" and ws:GetAttribute("Winner") == "draw")
	res = since(n0, "Results", solo)
	check("...nobody won", #res > 0 and res[#res].args[1].you.won == nil)
	check("...nobody lost", Data:Get(solo).stats.losses == losses and Data:Get(solo).streak == streak)
	act(owner, "restart")

	-- bots off and on: with the admin spectating, the lone player gets their bot back
	act(owner, "spectate", nil, true)
	Engine.advance(1.5)
	check("spectating again: the lone player gets a bot", #Bots:List() == 1, #Bots:List())
	check("...the admin's body is gone", owner.Character == nil and not Combat:Alive(owner))
	act(owner, "bots", nil, false)
	Engine.advance(1.5)
	check("bots off", #Bots:List() == 0)
	act(owner, "bots", nil, true)
	Engine.advance(1.5)
	check("bots on", #Bots:List() == 1)
	act(owner, "goto", solo.UserId)
	local st = Engine.lastClientEvent("AdminState", owner)
	check("GO TO while spectating: the camera follows them", st and st.args[1].follow == solo.UserId)
end

-- kick (last: the player goes)
do
	act(owner, "kick", owner.UserId, "me")
	check("an admin can't be kicked", owner._kicked == nil)
	act(owner, "kick", solo.UserId, "too much spam")
	check("kick, with the reason", type(solo._kicked) == "string" and string.find(solo._kicked, "too much spam") ~= nil)
	check("...logged", used[#used].action == "kick" and string.find(used[#used].detail, "Solo") ~= nil)
end

-- The client --------------------------------------------------------------------------------------------------
-- (in Studio the owner's username works too: a second admin, with the real client)
local me = Engine.addPlayer("xthirtysix", 4242)
Engine.Players.LocalPlayer = me
Engine.localPlayer = me
Engine.runScript(tree.client.Main)
Engine.advance(2)
local AdminC = Engine.require(tree.client.Controllers.AdminController)
local Spectate = Engine.require(tree.client.Controllers.SpectateController)
local Hud = Engine.require(tree.client.Controllers.HudController)
local Layout = Engine.require(tree.client.UI.Layout)
local Theme = Engine.require(tree.client.UI.Theme)
local r = AdminC.refs
check("client: the ADMIN button shows for an admin", r.button and r.button.Visible == true)
me:SetAttribute("Admin", nil)
AdminC.update()
check("...and not for anyone else", r.button.Visible == false)
me:SetAttribute("Admin", true)
AdminC.update()

do
	local W, H = Theme.MIN_WIDTH, Theme.DESIGN.Y
	local function rect(o)
		local p = o.Parent
		local px, py, pw, ph = 0, 0, W, H
		if p and not p:IsA("ScreenGui") then
			px, py, pw, ph = table.unpack(rect(p))
		end
		local ap = o.AnchorPoint or Vector2.new(0, 0)
		local w = o.Size.X.Scale * pw + o.Size.X.Offset
		local h = o.Size.Y.Scale * ph + o.Size.Y.Offset
		local x = px + o.Position.X.Scale * pw + o.Position.X.Offset - ap.X * w
		local y = py + o.Position.Y.Scale * ph + o.Position.Y.Offset - ap.Y * h
		return { x, y, w, h }
	end
	local function hits(a, b)
		local ra, rb = rect(a), rect(b)
		return ra[1] < rb[1] + rb[3] and rb[1] < ra[1] + ra[3] and ra[2] < rb[2] + rb[4] and rb[2] < ra[2] + ra[4]
	end
	local hud = Hud.refs
	local bad = {}
	for _, kindOf in { "keyboard", "touch" } do
		Hud.layoutFor(kindOf)
		for name, o in { Invite = hud.invite, Shop = hud.shop, Health = hud.health, Team = hud.team } do
			-- (on a phone the tag isn't shown: the button's own second line says SPECTATING there)
			local mineList = kindOf == "touch" and { AdminButton = r.button }
				or { AdminButton = r.button, SpectateTag = r.tag }
			for mine, a in mineList do
				if hits(a, o) then
					table.insert(bad, `{kindOf}: {mine} x {name}`)
				end
			end
		end
		local top = me.PlayerGui.Hud.Top
		if hits(r.button, top) or hits(r.tag, top) then
			table.insert(bad, kindOf .. ": the top bar")
		end
	end
	check("the button and tag clear the HUD (desktop and phone)", #bad == 0, table.concat(bad, ", "))

	-- the panel: each tab laid out with nothing on anything
	local function walk(container, depth)
		local kids = {}
		for _, k in container:GetChildren() do
			if k:IsA("GuiObject") and k.Visible ~= false then
				table.insert(kids, k)
			end
		end
		local out = {}
		local cr = rect(container)
		local scroll = container:IsA("ScrollingFrame")
		for i, a in kids do
			local ra = rect(a)
			local inside = ra[1] >= cr[1] - 0.5 and ra[1] + ra[3] <= cr[1] + cr[3] + 0.5
			if not scroll then
				inside = inside and ra[2] >= cr[2] - 0.5 and ra[2] + ra[4] <= cr[2] + cr[4] + 0.5
			end
			if not inside then
				table.insert(out, a.Name .. " sticks out of " .. container.Name)
			end
			for j = i + 1, #kids do
				if hits(a, kids[j]) then
					table.insert(out, a.Name .. " x " .. kids[j].Name)
				end
			end
			if depth < 6 then
				for _, x in walk(a, depth + 1) do
					table.insert(out, x)
				end
			end
		end
		return out
	end
	r.button.Activated:Fire()
	Engine.advance(0.5)
	check("the button opens the panel", AdminC.isOpen() and Layout.panel())
	check("...the mouse free", r.close.Modal == true)
	check("...the server sent its data", #(AdminC.state().players or {}) >= 2, #(AdminC.state().players or {}))
	AdminC.select(owner.UserId)
	for _, tab in { "servers", "match", "players", "me" } do
		AdminC.open(tab)
		Engine.advance(0.5)
		local out = walk(r.panel, 0)
		check(`the {tab} tab: nothing overlaps, nothing sticks out`, #out == 0, table.concat(out, ", "))
		local unfit = {}
		for _, d in r.panel:GetDescendants() do
			if d:IsA("TextLabel") and d.TextScaled ~= true then
				table.insert(unfit, d.Text)
			end
		end
		check(`the {tab} tab: its words shrink to fit`, #unfit == 0, table.concat(unfit, " | "))
	end
	AdminC.open("servers")
	Engine.advance(0.5)
	check("the servers tab lists the servers", r.body:FindFirstChild("Server1") ~= nil)
	-- the shop panel and the admin panel: one at a time
	local Panel = Engine.require(tree.client.Controllers.PanelController)
	Panel.open("shop")
	check("opening the shop closes the admin panel", Panel.isOpen() and not AdminC.isOpen() and Layout.panel())
	AdminC.open("match")
	check("...and the other way round", AdminC.isOpen() and not Panel.isOpen() and Layout.panel())

	-- a press reaches the server
	AdminC.open("match")
	r.body.Bots.Activated:Fire()
	Engine.advance(0.5)
	check("a button press reaches the server", Bots:Enabled() == false)
	r.body.Bots.Activated:Fire()
	Engine.advance(0.5)
	check("...and back", Bots:Enabled() == true)

	-- spectate from the ME tab: the free camera
	AdminC.open("me")
	r.body.Spectate.Activated:Fire()
	Engine.advance(0.5)
	check("SPECTATE from the panel", Admins.spectating(me) and me.Character == nil)
	check("...the tag says so", r.tag.Visible and r.tagText.Text == "SPECTATING (invisible)")
	check("...no health bar", Hud.refs.health.Visible == false)
	AdminC.close()
	check("closing frees the panel", not Layout.panel())
	Engine.advance(0.1)
	check("...the spectator camera", Spectate.active() and ws.CurrentCamera.CameraType == Enum.CameraType.Scriptable)
	local p0 = ws.CurrentCamera.CFrame.Position
	Engine.keysDown[Enum.KeyCode.W] = true
	Spectate.step(0.5)
	Engine.keysDown[Enum.KeyCode.W] = nil
	check("...W flies it", (ws.CurrentCamera.CFrame.Position - p0).Magnitude > 5)
	local y0 = ws.CurrentCamera.CFrame.Position.Y
	Engine.keysDown[Enum.KeyCode.Space] = true
	Spectate.step(0.5)
	Engine.keysDown[Enum.KeyCode.Space] = nil
	local y1 = ws.CurrentCamera.CFrame.Position.Y
	check("...Space goes up", y1 > y0 + 5, `{y0} -> {y1}`)
	Engine.keysDown[Enum.KeyCode.LeftShift] = true
	Spectate.step(0.5)
	Engine.keysDown[Enum.KeyCode.LeftShift] = nil
	check("...Shift goes down", ws.CurrentCamera.CFrame.Position.Y < y1 - 5)
	local t = Spectate.follow(nil)
	Spectate.step(0.1)
	check("FOLLOW: behind a player", t ~= nil and Spectate.mode() == "follow" and t ~= me)
	if t and root(t) then
		check("...near them", (ws.CurrentCamera.CFrame.Position - root(t).Position).Magnitude < 20)
	end
	check("...the bar says who", Spectate.refs.bar.Visible and string.find(Spectate.refs.name.Text, "WATCHING") ~= nil)
	Spectate.free()
	check("...back to the free camera", Spectate.mode() == "free")
	AdminC.open("me")
	r.body.Spectate.Activated:Fire()
	Engine.advance(1)
	check("leave spectate from the panel: playing again", not Admins.spectating(me) and Teams:Team(me) ~= nil)
	Spectate.step(0.1)
	check("...the normal camera", ws.CurrentCamera.CameraType == Enum.CameraType.Custom)
	AdminC.close()
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	failed += #Engine.errors
end
if failed > 0 then
	error("AdminSmoke: " .. failed .. " failures")
end

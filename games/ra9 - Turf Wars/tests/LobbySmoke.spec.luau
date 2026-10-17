--[[
The lobby place, server and client together on the mock engine (Constants.applyMode("lobby")): the plaza builds
with something on every spot (LobbyBuilder.SPOTS), nothing a body bumps into on the walkway from the spawn to
PLAY, plain white and greys with gold and the teams' colours (no browns), cheap enough for a phone; the match's
services stay out (no arena, no teams, no match) and a player lands on the spawn spot with a third-person camera
and the lobby's screen, not the match's HUD. PLAY sends "Play", a mode card sends it with its key, the counts
follow "Population", walking onto the beacon and into a portal play too. The parkour's checkpoints and its finish
pay once a day (and the Parkour title once); VERIFY pays once and never twice; walking up to a shop kiosk opens the
shop. Nothing on the screen overlaps, and the card's words and buttons stay inside it.

  luaurun tests/LobbySmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
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
local Constants = Engine.require(tree.shared.Constants)
Constants.applyMode("lobby")
Constants.AFK_SECONDS = 0
Constants.TUTORIAL = false
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Lobby = service("LobbyService")
local Data = service("PlayerDataService")
local LobbyBuilder = Engine.require(tree.shared.World.LobbyBuilder)
local ArenaBuilder = Engine.require(tree.shared.World.ArenaBuilder)
local Modes = Engine.require(tree.shared.Data.Modes)
local SPOTS = LobbyBuilder.SPOTS

local function lastFired(name, player)
	local e = Engine.lastClientEvent(name, player)
	return e and e.args[1]
end
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
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function stand(p, pos, look)
	Engine.moveTo(p, pos, look)
	Engine.advance(0.45)
end

-- The world --------------------------------------------------------------------------------------------------------
local world = Lobby:World()
local folder = ws:FindFirstChild("Lobby")
check("the lobby was built", folder ~= nil and world ~= nil and world.folder == folder)
check("no arena, no match, no teams: the match's services stay out", ws:FindFirstChild("Arena") == nil)
do
	local boot = Engine.require(tree.server.Loader)
	_ = boot
	local ok = pcall(function()
		return Engine.require(tree.server.Services.MatchService)
	end)
	check("...MatchService isn't in the registry's boot", ws:GetAttribute("Phase") == nil and ok)
	check("...workspace says it's the lobby", ws:GetAttribute("Lobby") == true)
end
-- something stands on every spot
local parts = {}
for _, d in folder:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end
local function occupied(spot, radius, dy)
	for _, d in parts do
		if d.Name ~= "Floor" and d.Name ~= "Ground" and LobbyBuilder.near(d.Position, spot, radius or 8, dy or 12) then
			return true
		end
	end
	return false
end
local spotList = {
	{ "spawn", SPOTS.spawn },
	{ "play", SPOTS.play },
	{ "parkour start", SPOTS.parkour.start },
	{ "parkour top", SPOTS.parkour.top },
	{ "boards", SPOTS.boards },
	{ "crate", SPOTS.crate },
	{ "verify", SPOTS.verify },
	{ "portal ctf", SPOTS.portals.ctf },
	{ "portal brawl", SPOTS.portals.brawl },
	{ "portal tycoon", SPOTS.portals.tycoon },
}
for i, p in SPOTS.duelPads do
	table.insert(spotList, { "duel pad " .. i, p })
end
for i, p in SPOTS.shops do
	table.insert(spotList, { "shop " .. i, p })
end
for _, s in spotList do
	check(`something stands on the {s[1]} spot`, occupied(s[2]))
end
check(
	"the exported numbers are the asked ones",
	SPOTS.spawn.Position == Vector3.new(0, 3, 40)
		and SPOTS.play == Vector3.new(0, 0, -20)
		and SPOTS.boards == Vector3.new(100, 0, 0)
		and SPOTS.parkour.top == Vector3.new(-90, 40, -60)
)
check("the spawn faces -Z (PLAY)", SPOTS.spawn.LookVector.Z < -0.99)
-- nothing a body bumps into on the walkway from the spawn to PLAY
do
	local W = LobbyBuilder.WALKWAY
	local bad = {}
	for _, box in world.collide do
		if
			box.min.X < W.max.X
			and W.min.X < box.max.X
			and box.min.Y < W.max.Y
			and W.min.Y < box.max.Y
			and box.min.Z < W.max.Z
			and W.min.Z < box.max.Z
		then
			table.insert(bad, `{(box.min + box.max) / 2}`)
		end
	end
	check("nothing collidable on the walkway from the spawn to PLAY", #bad == 0, table.concat(bad, "; "))
	-- (and the checks read the parts themselves, not only the builder's boxes)
	local hits = 0
	for _, d in parts do
		if d.CanCollide and d.Name ~= "Floor" then
			local mn, mx = ArenaBuilder.aabbOf(d.CFrame, d.Size)
			if
				mn.X < W.max.X
				and W.min.X < mx.X
				and mn.Y < W.max.Y
				and W.min.Y < mx.Y
				and mn.Z < W.max.Z
				and W.min.Z < mx.Z
			then
				hits += 1
			end
		end
	end
	check("...and no collidable part either", hits == 0, hits)
end
-- the look: the maps' detail, plain, no browns, cheap
do
	local molding, columns, lamps, banners, brown, gold = 0, 0, 0, 0, {}, 0
	for _, d in parts do
		if d.Name == "Molding" then
			molding += 1
		elseif d.Name == "Column" then
			columns += 1
		elseif d.Name == "Lamp" then
			lamps += 1
		elseif d.Name == "Banner" then
			banners += 1
		end
		if d.Color == Constants.GOLD then
			gold += 1
		end
		local c = d.Color
		local r, g, b = c.R, c.G, c.B
		local mx, mn = math.max(r, g, b), math.min(r, g, b)
		local sat = mx > 0 and (mx - mn) / mx or 0
		local hue = mx == mn and 0 or (mx == r and 60 * (((g - b) / (mx - mn)) % 6) or -1)
		if d.Transparency < 1 and mx == r and hue >= 12 and hue <= 50 and sat > 0.2 and mx < 0.85 then
			table.insert(brown, d.Name)
		end
	end
	check(
		"dressed like the maps: moldings, columns, lamps, banners",
		molding >= 20 and columns >= 16 and lamps >= 10 and banners >= 8,
		`{molding} {molding} {columns} {lamps} {banners}`
	)
	check("gold where it counts", gold >= 30, gold)
	check("nothing brown", #brown == 0, table.concat(brown, ","))
	check("cheap enough for a phone", world.count < 1000, world.count)
	local play, parkourSign = 0, false
	for _, d in parts do
		if d.Name == "PlayLetters" then
			play += 1
		end
		local words = d:FindFirstChild("Words")
		local title = words and words:FindFirstChild("Title")
		if title and string.find(title.Text, "PARKOUR") then
			parkourSign = true
		end
	end
	check("PLAY stands in 3D letters over the beacon", play >= 12 and play <= 40, play)
	check("a PARKOUR ▲ sign", parkourSign)
	check(
		"the parkour has checkpoints on the way up",
		#world.parkour.checkpoints == 3 and #LobbyBuilder.PARKOUR.checkpoints == 5
	)
	check(
		"the four boards face the plaza",
		world.boards.wins and world.boards.streak and world.boards.wins.CFrame.LookVector.X < -0.99
	)
	check("four duel pads, four kiosks", #world.pads == 4 and #world.kiosks == 4)
end

-- A player lands ---------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)
local r = rootOf(player)
check("they stand on the spawn spot", r and (r.Position - SPOTS.spawn.Position).Magnitude < 1, r and r.Position)
check("...facing PLAY", r and r.CFrame.LookVector.Z < -0.99)
check("...with no team", player.Team == nil and player:GetAttribute("Team") == nil)
check("third person: the camera isn't locked", player.CameraMode ~= Enum.CameraMode.LockFirstPerson)
local gui = player.PlayerGui
check(
	"the lobby's screen is up, the match's HUD isn't",
	gui:FindFirstChild("Lobby") ~= nil and gui:FindFirstChild("Hud") == nil
)
local LobbyC = Engine.require(tree.client.Controllers.LobbyController)
local PanelC = Engine.require(tree.client.Controllers.PanelController)
local TopC = Engine.require(tree.client.Controllers.LeaderboardController)
local refs = LobbyC.refs
check("a big PLAY button", refs.play and refs.play.Visible ~= false and refs.play.Head.Text:find("PLAY") ~= nil)
check("...saying what it does", refs.playLine.Text:find("fullest") ~= nil)
check("four mode cards", refs.cards.turf and refs.cards.ctf and refs.cards.brawl and refs.cards.tycoon)
check("a SHOP button and your Shards", refs.shop and refs.shards)
check("the state came: not verified yet", LobbyC.state().verified == false)

-- PLAY and the cards
local played = {}
Lobby.Played:Connect(function(p, key)
	table.insert(played, { p, key })
end)
refs.play.Activated:Fire()
Engine.advance(0.2)
check("PLAY sends Play", #played == 1 and played[1][1] == player and played[1][2] == nil, #played)
check(
	"...the places aren't made yet: PlaceService says the mode isn't open",
	(lastFired("Toast", player) or ""):find("isn't open yet") ~= nil,
	lastFired("Toast", player)
)
Engine.advance(LobbyC.PLAY_COOLDOWN + 0.1)
refs.cards.ctf.Activated:Fire()
Engine.advance(0.2)
check("a mode card sends Play with its key", #played == 2 and played[2][2] == "ctf", played[2] and played[2][2])
Engine.advance(LobbyC.PLAY_COOLDOWN + 0.1)
refs.cards.brawl.Activated:Fire()
Engine.advance(0.2)
check("...each its own", #played == 3 and played[3][2] == "brawl")
-- the counts
Lobby:SetPopulation({ turf = 12, ctf = 3, brawl = 5 })
Engine.advance(0.2)
check(
	"the counts follow Population",
	LobbyC.counts().turf == 12 and refs.cards.turf.Count.Text:find("12") ~= nil,
	refs.cards.turf.Count.Text
)
check("...and PLAY says how many play", refs.playLine.Text:find("20") ~= nil, refs.playLine.Text)
check("...the portals' signs too", refs.portalSigns.ctf and refs.portalSigns.ctf.Words.Line.Text:find("3") ~= nil)
check(
	"a bad key is refused",
	(function()
		Engine.advance(LobbyC.PLAY_COOLDOWN + 0.1) -- (past Net's Play rate: one in 2 s)
		Engine.fireServer(player, "Play", "nope")
		Engine.advance(0.1)
		return played[#played][2] == nil
	end)(),
	played[#played] and played[#played][2]
)
-- walking onto the beacon and into a portal
Engine.advance(LobbyC.PLAY_COOLDOWN + 0.1)
local before = #played
stand(player, SPOTS.play + Vector3.new(0, 4.5, 0))
check("walking onto the PLAY beacon plays", #played == before + 1 and played[#played][2] == nil, #played - before)
stand(player, SPOTS.spawn.Position)
Engine.advance(LobbyC.PLAY_COOLDOWN + 0.1)
before = #played
stand(player, SPOTS.portals.brawl + Vector3.new(0, 3, 3))
check(
	"walking into a portal plays its mode",
	#played == before + 1 and played[#played][2] == "brawl",
	played[#played] and played[#played][2]
)
stand(player, SPOTS.spawn.Position)

-- The shop kiosks --------------------------------------------------------------------------------------------------
check("the shop's shut", not PanelC.isOpen())
stand(player, SPOTS.shops[1] + Vector3.new(-3, 3, 0))
check("walking up to a kiosk opens the shop", PanelC.isOpen() and PanelC.tab() == "shop", PanelC.tab())
PanelC.close()
stand(player, SPOTS.spawn.Position)
check("...shut again, away from it", not PanelC.isOpen())
stand(player, SPOTS.shops[4] + Vector3.new(0, 3, -3))
check("the DEALS kiosk opens it too", PanelC.isOpen() and PanelC.tab() == "shop")
PanelC.close()
stand(player, SPOTS.spawn.Position)
check(
	"each kiosk has a prompt and a hint",
	#Engine.prompts(world.kiosks[1].part) == 1 and world.kiosks[2].sign.Words.Line.Text == "WEAPON SKINS"
)

-- VERIFY ------------------------------------------------------------------------------------------------------------
local logged = {}
Lobby.Logged:Connect(function(p, name, d)
	table.insert(logged, { p, name, d })
end)
local shards0 = Data:Get(player).shards
stand(player, SPOTS.verify + Vector3.new(-4, 3, 0))
check("walking up to the stand opens the card", LobbyC.verifyOpen())
check(
	"...worded as an honour-system thank-you",
	refs.verifyLine.Text:find("If you like") ~= nil and refs.verifyHead.Text:find("LIKE") ~= nil
)
refs.verifyGo.Activated:Fire()
Engine.advance(0.3)
local p = Data:Get(player)
check("VERIFY pays once: the Shards", p.shards == shards0 + Constants.VERIFY_SHARDS, p.shards)
check("...and the Supporter banner, worn", p.extras.supporter == true and p.equipped.banner == "extra_supporter")
check("...logged as verify", logged[#logged] and logged[#logged][2] == "verify")
check("...the card says thanks", LobbyC.state().verified and refs.verifyHead.Text:find("THANKS") ~= nil)
check("...and the stand", refs.verifySign.Words.Title.Text:find("VERIFIED") ~= nil)
local logs = #logged
Engine.fireServer(player, "Verify")
Engine.advance(0.3)
check("...never twice", Data:Get(player).shards == shards0 + Constants.VERIFY_SHARDS and #logged == logs)
refs.verifyLater.Activated:Fire()
check("LATER / CLOSE shuts it", not LobbyC.verifyOpen())
stand(player, SPOTS.spawn.Position)

-- The parkour ---------------------------------------------------------------------------------------------------------
local cps = LobbyBuilder.PARKOUR.checkpoints
local shards1 = Data:Get(player).shards
local m0 = mark()
stand(player, cps[1] + Vector3.new(0, 3.6, 0))
check(
	"standing on the start starts the clock",
	Lobby:Run(player).step == 1
		and firedSince(m0, "Lobby", player, function(a)
				return a[1].kind == "parkour" and a[1].go == true
			end)
			~= nil
)
check("...the clock's on screen", refs.clock.Visible == true and refs.clockText.Text:find("PARKOUR") ~= nil)
-- a fall to the floor: back to the start
stand(player, Vector3.new(-70, 3, 30))
check("a fall puts you back to the start", Lobby:Run(player).step == 0 and refs.clock.Visible == false)
stand(player, cps[1] + Vector3.new(0, 3.6, 0))
for i = 2, #cps - 1 do
	stand(player, cps[i] + Vector3.new(0, 3, 0))
	check(
		`checkpoint {i - 1} counts`,
		Lobby:Run(player).step == i and refs.toast.Text:find(`CHECKPOINT {i - 1}`) ~= nil,
		refs.toast.Text
	)
end
check(
	"...skipping ahead doesn't (the top needs every checkpoint)",
	(function()
		-- (already at the last checkpoint: fine; the check is that the run is still mid-way)
		return Lobby:Run(player).step == #cps - 1
	end)()
)
m0 = mark()
stand(player, cps[#cps] + Vector3.new(0, 3, 0))
p = Data:Get(player)
check("the top pays the day's Shards", p.shards == shards1 + Constants.PARKOUR_SHARDS, p.shards - shards1)
check("...and the Parkour title, worn", p.extras.parkour == true and p.equipped.title == "extra_parkour")
check("...the best time kept", p.lobby.parkourBest > 0)
local done = firedSince(m0, "Lobby", player, function(a)
	return a[1].kind == "parkour" and a[1].done == true
end)
check("...the client hears it's done, and paid", done and done.args[1].paid == true and done.args[1].first == true)
check("...logged", logged[#logged][2] == "parkour" and logged[#logged][3].paid == true)
check("...the clock stops", LobbyC.state().running == false)
-- again the same day: no Shards, no second title
stand(player, cps[1] + Vector3.new(0, 3.6, 0))
for i = 2, #cps do
	stand(player, cps[i] + Vector3.new(0, 3, 0))
end
p = Data:Get(player)
check("a second run today pays nothing more", p.shards == shards1 + Constants.PARKOUR_SHARDS, p.shards - shards1)
check(
	"...but still counts as done",
	Lobby:Run(player).step == 0 and (lastFired("Toast", player) or ""):find("PARKOUR DONE") ~= nil
)
-- tomorrow it pays again
p.lobby.parkourDay -= 1
stand(player, cps[1] + Vector3.new(0, 3.6, 0))
for i = 2, #cps do
	stand(player, cps[i] + Vector3.new(0, 3, 0))
end
check("...tomorrow it pays again", Data:Get(player).shards == shards1 + 2 * Constants.PARKOUR_SHARDS)
stand(player, SPOTS.spawn.Position)

-- Falling off the world, a knockout: back on the spawn
stand(player, Vector3.new(0, -40, 0))
Engine.advance(0.5)
r = rootOf(player)
check("off the edge: back on the spawn", r and (r.Position - SPOTS.spawn.Position).Magnitude < 1, r and r.Position)

-- The leaderboards' boards ----------------------------------------------------------------------------------------
Engine.advance(1.5)
check("the boards asked for the top", Engine.lastClientEvent("Leaderboards", player) ~= nil)
check(
	"...and show it in the world",
	refs.boards.wins and refs.boards.wins:FindFirstChild("Rows") ~= nil and refs.boards.wins.Rows.Title.Text == "WINS"
)
check("...the TOP button's still there too", TopC.refs.button ~= nil)

-- Nothing on the screen overlaps -------------------------------------------------------------------------------------
do
	local Theme = Engine.require(tree.client.UI.Theme)
	local W, H = Theme.MIN_WIDTH, Theme.DESIGN.Y
	local function rect(o)
		local pr = o.Parent
		local px, py, pw, ph, ps = 0, 0, W, H, 1
		if pr and not pr:IsA("ScreenGui") then
			px, py, pw, ph, ps = table.unpack(rect(pr))
		end
		local ap = o.AnchorPoint or Vector2.new(0, 0)
		local w = o.Size.X.Scale * pw + o.Size.X.Offset * ps
		local h = o.Size.Y.Scale * ph + o.Size.Y.Offset * ps
		local x = px + o.Position.X.Scale * pw + o.Position.X.Offset * ps - ap.X * w
		local y = py + o.Position.Y.Scale * ph + o.Position.Y.Offset * ps - ap.Y * h
		return { x, y, w, h, ps }
	end
	local function shown(o)
		local x = o
		while x and not x:IsA("ScreenGui") do
			if x.Visible == false then
				return false
			end
			x = x.Parent
		end
		return o.Parent ~= nil
	end
	local function hits(a, b)
		local ra, rb = rect(a), rect(b)
		return ra[1] < rb[1] + rb[3] and rb[1] < ra[1] + ra[3] and ra[2] < rb[2] + rb[4] and rb[2] < ra[2] + ra[4]
	end
	local function onScreen(o)
		local q = rect(o)
		return q[1] >= 0 and q[2] >= 0 and q[1] + q[3] <= W and q[2] + q[4] <= H
	end
	local function apart(what, list)
		local bad, live = {}, {}
		for name, o in list do
			if o and shown(o) then
				table.insert(live, { name, o })
				if not onScreen(o) then
					table.insert(bad, name .. " off screen")
				end
			end
		end
		for i = 1, #live do
			for j = i + 1, #live do
				if hits(live[i][2], live[j][2]) then
					table.insert(bad, live[i][1] .. " x " .. live[j][1])
				end
			end
		end
		check(what .. ": nothing overlaps", #bad == 0, table.concat(bad, ", "))
		return #live
	end
	local function tidy(what, card)
		local bad, kids = {}, {}
		local cr = rect(card)
		for _, k in card:GetChildren() do
			if k:IsA("TextLabel") or k:IsA("TextButton") then
				table.insert(kids, k)
				local q = rect(k)
				if q[1] < cr[1] or q[2] < cr[2] or q[1] + q[3] > cr[1] + cr[3] or q[2] + q[4] > cr[2] + cr[4] then
					table.insert(bad, (k.Text or k.Name) .. " sticks out")
				end
			end
		end
		for i = 1, #kids do
			for j = i + 1, #kids do
				if hits(kids[i], kids[j]) then
					table.insert(bad, `{kids[i].Text or kids[i].Name} x {kids[j].Text or kids[j].Name}`)
				end
			end
		end
		check(what .. ": its words and buttons don't overlap", #bad == 0, table.concat(bad, ", "))
	end
	LobbyC.toast("A toast on the lobby's line", "info")
	LobbyC.state().running = true
	LobbyC.state().startedAt = Engine.now()
	refs.clock.Visible = true
	local pieces = {
		play = refs.play,
		turf = refs.cards.turf,
		ctf = refs.cards.ctf,
		brawl = refs.cards.brawl,
		toast = refs.toast,
		shop = refs.shop,
		shards = refs.shardsSlab,
		clock = refs.clock,
		top = TopC.refs.button,
	}
	local n = apart("the lobby's screen", pieces)
	check("...all of it showing", n == 9, n)
	tidy("the PLAY button", refs.play)
	tidy("a mode card", refs.cards.ctf)
	LobbyC.openVerify()
	tidy("the verify card", refs.verify)
	pieces.verify = refs.verify
	pieces.toast = nil
	apart("the lobby's screen with the card up", pieces)
	LobbyC.closeVerify()
	LobbyC.state().running = false
	refs.clock.Visible = false
	-- every label shrinks to fit
	local unfit = {}
	for _, d in refs.gui:GetDescendants() do
		if d:IsA("TextLabel") and d.TextScaled ~= true then
			table.insert(unfit, d.Text)
		end
	end
	check("every label fits its box", #unfit == 0, table.concat(unfit, ", "))
end

-- A second player: the server's leaderboard rows read everyone here (no match to ask)
do
	local ben = Engine.addPlayer("Ben", 502)
	Engine.advance(0.5)
	Engine.fireServer(ben, "Ready")
	Engine.advance(0.5)
	local Top = service("LeaderboardService")
	local payload = Top:Payload(player)
	check("'this server' is everyone in the lobby", #payload.server.wins == 2, #payload.server.wins)
	Engine.removePlayer(ben)
	Engine.advance(0.5)
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("LobbySmoke: " .. failed .. " failures")
end

--[[
Capture the Flag smoke test: the real server (and, for the HUD, the real client) on the mock engine with
Constants.applyMode("ctf"): the match waits for four READY players (a party readies together), starts with no bots,
late joiners go to the side behind (even teams) or the smaller side (odd), the bigger build budget on your own
half, the blade from the fight's first second and the line open to everyone, the flags (the stands at the back of
each base, picking up, carrying slower with the bow down, dropping on a knockout, a teammate's return, the return on
its own, a capture with your own flag home only), first to three captures, the clock and sudden death, the HUD
(both scores, the flag icons, the markers, the RUN HOME banner), the Shards paid, and the results.

  luaurun tests/CtfSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local CFrame = Engine.CFrame
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
Constants.applyMode("ctf")
Constants.AFK_SECONDS = 0 -- (test players stand still)
Constants.TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
Engine.runScript(tree.server.Main)
Engine.require(tree.server.Services.CombatService).firstKillHelp = false
Engine.require(tree.server.Services.CombatService).comebackShield = false
Engine.require(tree.server.Services.CombatService).newPlayerHelp = false
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Teams = service("TeamService")
local Arena = service("ArenaService")
local Combat = service("CombatService")
local Build = service("BuildService")
local Match = service("MatchService")
local Ctf = service("CtfService")
local Bots = service("BotService")
local Party = service("PartyService")
local Data = service("PlayerDataService")
local Formulas = Engine.require(tree.shared.Formulas)
local Shop = Engine.require(tree.shared.Data.Shop)

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
local function send(player, name, ...)
	Engine.fireServer(player, name, ...)
	Engine.advance(0.05)
end
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function stand(p, pos, look)
	Engine.moveTo(p, pos, look)
	Engine.advance(0.05)
end
-- the side of the field a team's base is on (-1: red at -X)
local function sideOf(team)
	return team == "red" and -1 or 1
end

-- The queue: nothing starts without four READY players ---------------------------------------------------------
check("the mode is ctf", ws:GetAttribute("Mode") == "ctf")
check("the arena is up to wait in", ws:FindFirstChild("Arena") ~= nil)
check("the match waits for players", ws:GetAttribute("Phase") == "waiting", ws:GetAttribute("Phase"))
check(
	"the flag stands are up with the arena",
	ws:FindFirstChild("Flags") and ws.Flags:FindFirstChild("Stand_red") ~= nil
)
-- Ava plays with the real client (the HUD); the rest are server-side players
local ava = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = ava
Engine.localPlayer = ava
Engine.runScript(tree.client.Main)
local ben = Engine.addPlayer("Ben", 502)
Engine.advance(0.5)
send(ben, "Ready")
Engine.advance(1.5)
check(
	"two players: on teams, spawned, still waiting",
	Teams:Team(ava) and Teams:Team(ben) and Combat:Alive(ava) and ws:GetAttribute("Phase") == "waiting"
)
check("no bots, ever", #Bots:List() == 0)
local st = lastFired("Ctf", ava)
check(
	"the clients hear the queue: 0 of 4 ready",
	st and st.waiting == true and st.ready == 0 and st.need == 4,
	st and st.ready
)
-- the HUD while waiting
local Hud = Engine.require(tree.client.Controllers.HudController)
local Weapon = Engine.require(tree.client.Controllers.WeaponController)
local refs = Hud.refs
check(
	"HUD: WAITING FOR PLAYERS 0/4",
	refs.phase and refs.phase.Text:find("WAITING FOR PLAYERS 0/4") ~= nil,
	refs.phase and refs.phase.Text
)
check("HUD: the READY button is up", refs.ready ~= nil and refs.ready.Visible == true)
check("HUD: the scores board, not the line's bar", refs.ctf and refs.ctf.Visible == true and refs.bar.Visible == false)
check(
	"HUD: the objective says the mode's",
	refs.objective and refs.objective.Text:find("flag") ~= nil,
	refs.objective and refs.objective.Text
)
check(
	"HUD: the sides wear the mode's names and colours",
	refs.ctfSides.red.name.Text == Constants.TEAM_NAME.red
		and refs.ctfSides.blue.name.Text == Constants.TEAM_NAME.blue
		and refs.ctfSides.red.score.TextColor3 == Constants.TEAM_COLOR.red
)
check(
	"HUD: both flags home",
	refs.ctfSides.red.flag.Text:find("HOME") ~= nil and refs.ctfSides.blue.flag.Text:find("HOME") ~= nil
)
refs.ready.Activated:Fire()
Engine.advance(0.3)
check("tap READY: you're in the queue", Ctf:ReadyCount() == 1 and Ctf:IsReady(ava) and not Ctf:IsReady(ben))
check("HUD: ...the button says so", refs.ready.Text:find("1/4") ~= nil, refs.ready.Text)
check("HUD: ...and the pill", refs.phase.Text:find("1/4") ~= nil, refs.phase.Text)
refs.ready.Activated:Fire()
Engine.advance(0.3)
check("tap again: out of the queue", not Ctf:IsReady(ava) and refs.ready.Text == "READY")
send(ava, "Ctf", "ready", true)
Engine.advance(0.3)
check("READY counts", Ctf:ReadyCount() == 1 and Ctf:IsReady(ava) and not Ctf:IsReady(ben))
st = lastFired("Ctf", ben)
check("...and everyone hears 1/4", st and st.ready == 1, st and st.ready)
send(ava, "Ctf", "ready", false)
Engine.advance(0.3)
check("...and can un-READY", Ctf:ReadyCount() == 0)
send(ava, "Ctf", "ready", true)
Engine.advance(0.3)
-- Cy and Dee party up: Cy's READY readies them both
local cy = Engine.addPlayer("Cy", 503)
local dee = Engine.addPlayer("Dee", 504)
Engine.advance(0.5)
send(cy, "Ready")
send(dee, "Ready")
Engine.advance(0.5)
send(cy, "Party", "invite", 504)
Engine.advance(0.2)
send(dee, "Party", "accept")
Engine.advance(0.5)
check("a party formed", Party:Of(cy) ~= nil and Party:Of(dee) == Party:Of(cy))
check("still waiting at 1/4 with four on", ws:GetAttribute("Phase") == "waiting" and Ctf:ReadyCount() == 1)
send(cy, "Ctf", "ready", true)
Engine.advance(0.3)
check("a party readies together: 3/4", Ctf:ReadyCount() == 3 and Ctf:IsReady(dee), Ctf:ReadyCount())
check("...still not a match", ws:GetAttribute("Phase") == "waiting")
local mStart = mark()
send(ben, "Ctf", "ready", true)
Engine.advance(1)
check("four READY: the match starts in the build phase", ws:GetAttribute("Phase") == "build", ws:GetAttribute("Phase"))
check("...everyone hears the new game", firedSince(mStart, "Announce", nil, function(a)
	return a[1].kind == "start" and string.find(a[1].text, "New game") ~= nil
end) ~= nil)
check(
	"...and the match (mode ctf, no sudden death)",
	lastFired("Match", ava).mode == "ctf" and lastFired("Match", ava).sudden == nil
)
check(
	"HUD: the READY button is gone, the pill says BUILD",
	refs.ready.Visible == false and refs.phase.Text:find("BUILD") ~= nil,
	refs.phase.Text
)
check("teams are two and two", Teams:Count("red") == 2 and Teams:Count("blue") == 2)
check("the party is together", Teams:Team(cy) == Teams:Team(dee))
check("no bots after the start either", #Bots:List() == 0 and #Match:Everyone() == 4)
check("the line is the middle and stays there", ws:GetAttribute("Frontline") == 0)
local red = Teams:Team(ava) == "red" and ava or (Teams:Team(ben) == "red" and ben or cy)
local blue = Teams:Team(ava) == "blue" and ava or (Teams:Team(ben) == "blue" and ben or cy)
local red2, blue2
for _, p in { ava, ben, cy, dee } do
	if p ~= red and Teams:Team(p) == "red" then
		red2 = p
	elseif p ~= blue and Teams:Team(p) == "blue" then
		blue2 = p
	end
end
check("everyone spawned alive", Combat:Alive(red) and Combat:Alive(blue) and Combat:Alive(red2) and Combat:Alive(blue2))

-- The stands: at the back of each base, clear of the deck's cover, nowhere anyone can build ----------------------
do
	local a = Arena:Current()
	for _, team in Constants.TEAMS do
		local f = Ctf:Flag(team)
		local s = sideOf(team)
		check(
			`the {team} stand is at the back of its base`,
			f and f.pos and f.pos.X * s > a.half - a.spawnDepth,
			f and f.pos
		)
		local free = true
		if f then
			local mn, mx = f.pos - Vector3.new(1.5, 0.8, 1.5), f.pos + Vector3.new(1.5, 5, 1.5)
			for _, sol in a.solids do
				if sol.part ~= a.strips[1] and Formulas.boxesOverlap(mn, mx, sol.min, sol.max) then
					free = false
				end
			end
		end
		check(`...clear of the deck's cover and the map`, free)
		check(`...the flag is home on it`, f and f.state == "home")
		local model = ws.Flags:FindFirstChild("Stand_" .. team)
		check(
			`...a banner in the team's colour`,
			model and model:FindFirstChild("Flag") and model.Flag.Color == Constants.BUILD_COLOR[team]
		)
	end
end

-- The build phase: twice the points, your own half only ---------------------------------------------------------
check(
	"the build budget is the CTF one",
	Build:Budget(red) == Constants.CTF_BUILD_BUDGET and Constants.CTF_BUILD_BUDGET > Constants.TURF_BUILD_BUDGET
)
check(
	"...and the client is told the bigger max",
	lastFired("Me", red) and lastFired("Me", red).budgetMax == Constants.CTF_BUILD_BUDGET
)
do
	local s = sideOf(Teams:Team(red))
	stand(red, Vector3.new(s * 40, 3, -12))
	local cx, cz = Formulas.cellOf(s * 44, -28)
	local ok, why = Build:Place(red, "wall", cx, cz, 0)
	check("a wall on your own half is built", ok == true, why)
	check("...and it cost its points", Build:Budget(red) == Constants.CTF_BUILD_BUDGET - 10, Build:Budget(red))
	stand(red, Vector3.new(s * 6, 3, 0))
	local ex, ez = Formulas.cellOf(-s * 8, 0)
	local ok2, why2 = Build:Place(red, "cover", ex, ez, 0)
	check("not over the middle", not ok2 and why2 and why2:find("turf") ~= nil, why2)
	-- the line holds in the build phase: over the middle you're put back
	stand(red, Vector3.new(-s * 10, 3, 0))
	Engine.advance(0.5)
	check("in the build phase you can't cross the middle", rootOf(red).Position.X * s > 0, rootOf(red).Position.X)
	check(
		"...and you're told why",
		lastFired("Toast", red) and lastFired("Toast", red):find("Not yet") ~= nil,
		lastFired("Toast", red)
	)
	check("the blade stays away in the build phase", not Combat.allowed("blade", red))
end

-- The fight: blades out at once, the line open to everyone ------------------------------------------------------
local mFight = mark()
Match:SkipTo("fight")
Engine.advance(0.3)
check("the fight is on", ws:GetAttribute("Phase") == "fight")
check("...for four minutes", math.abs((ws:GetAttribute("PhaseEnds") - Engine.now()) - Constants.CTF.FIGHT_SECONDS) < 1)
check("the blade is out from the first second", Combat.allowed("blade", red) and ws:GetAttribute("Charge") == true)
check("...and no CHARGE call", firedSince(mFight, "Alert", nil, function(a)
	return a[1] == "CHARGE!"
end) == nil)
check("the fight's own call", firedSince(mFight, "Alert", nil, function(a)
	return a[1] == "FIGHT!"
end) ~= nil)
check("you can pick the blade", Combat:Equip(red, "blade") and Combat:Weapon(red) == "blade")
Combat:Equip(red, "bow")
do
	local s = sideOf(Teams:Team(red))
	stand(red, Vector3.new(-s * 30, 3, 0))
	Engine.advance(0.5)
	check("anyone may cross the middle in the fight", rootOf(red).Position.X * s < 0, rootOf(red).Position.X)
end

-- Picking up, carrying, dropping, returning, capturing -----------------------------------------------------------
local function flagHome(team)
	return Ctf:Flag(team).pos
end
local redTeam, blueTeam = Teams:Team(red), Teams:Team(blue)
do
	local m0 = mark()
	stand(red, flagHome(blueTeam) + Vector3.new(1, 2, 0))
	Engine.advance(0.3)
	check(
		"walk onto the enemy flag: you carry it",
		Ctf:Carrying(red) == blueTeam and Ctf:Flag(blueTeam).state == "carried"
	)
	check(
		"...it rides on your back",
		red.Character:FindFirstChild("CarriedFlag") ~= nil
			and red.Character.CarriedFlag:GetAttribute("Team") == blueTeam
	)
	check("...the stand's cloth went with it", ws.Flags["Stand_" .. blueTeam].Flag.Transparency == 1)
	check("...you're marked a carrier (the client slows you)", red:GetAttribute("Flag") == blueTeam)
	check("...the blade is in your hand", Combat:Weapon(red) == "blade")
	check("...and you're told to run home", firedSince(m0, "Toast", red, function(a)
		return string.find(a[1], "run home") ~= nil
	end) ~= nil)
	local st2 = lastFired("Ctf", blue)
	check(
		"...everyone hears who has it",
		st2 and st2.flags[blueTeam].state == "carried" and st2.flags[blueTeam].carrier == red.UserId
	)
	-- the bow stays down while carrying
	Combat:Equip(red, "bow")
	local shots = #Combat:Arrows()
	send(red, "Draw", true)
	Engine.advance(1)
	send(red, "Shoot", rootOf(red).Position + Vector3.new(0, 1.5, 0), Vector3.new(0, 0, 1), 1)
	Engine.advance(0.2)
	check("a carrier can't shoot", #Combat:Arrows() == shots)
	-- but can swing
	Combat:Equip(red, "blade")
	local mSwing = mark()
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("...but can swing the blade", firedSince(mSwing, "Swing", nil) ~= nil)
	-- a second enemy can't take a carried flag; your own flag away doesn't stop the carry
	check("the flag state stays carried for a second enemy", Ctf:PickUp(red2, blueTeam) == false)
	-- knocked out: the flag drops where you fell
	local m1 = mark()
	stand(red, Vector3.new(0, 3, 20))
	Combat:Kill(red, blue, { weapon = "bow" })
	Engine.advance(0.2)
	local f = Ctf:Flag(blueTeam)
	check(
		"knocked out: the flag drops where you fell",
		f.state == "dropped" and (f.pos - Vector3.new(0, 0, 20)).Magnitude < 3,
		f.pos
	)
	check("...it lies there for everyone to see", ws.Flags:FindFirstChild("Dropped_" .. blueTeam) ~= nil)
	check("...no longer on your back", red:GetAttribute("Flag") == nil)
	check("...everyone is told", firedSince(m1, "Ctf", nil, function(a)
		return a[1].flags[blueTeam].state == "dropped"
	end) ~= nil)
	-- the enemy touches it: home at once, paid
	local shards0 = Data:Get(blue2).shards or 0
	stand(blue2, Vector3.new(1, 3, 20))
	Engine.advance(0.3)
	check("a teammate of the flag touches it: home at once", Ctf:Flag(blueTeam).state == "home")
	check("...the stand's cloth is back", ws.Flags["Stand_" .. blueTeam].Flag.Transparency == 0)
	check(
		"...and they're paid the return",
		(Data:Get(blue2).shards or 0) == shards0 + Shop.EARN.flagReturn,
		Data:Get(blue2).shards
	)
	check(
		"...the +N flew to their counter",
		lastFired("Earned", blue2) and lastFired("Earned", blue2).why == "flagReturn"
	)
	check("...counted as a return", Match:Stats(blue2).returns == 1)
end
-- the return on its own
Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
check("the carrier is back up", Combat:Alive(red))
do
	stand(red, flagHome(blueTeam) + Vector3.new(1, 2, 0))
	Engine.advance(0.3)
	check("taken again", Ctf:Carrying(red) == blueTeam)
	stand(red, Vector3.new(10, 3, -20))
	Combat:Kill(red, blue, { weapon = "bow" })
	Engine.advance(0.2)
	check("dropped again", Ctf:Flag(blueTeam).state == "dropped")
	Engine.advance(Constants.CTF.FLAG_RETURN_SECONDS - 1)
	check("...still there a moment before the time", Ctf:Flag(blueTeam).state == "dropped")
	Engine.advance(1.5)
	check("...home on its own after FLAG_RETURN_SECONDS", Ctf:Flag(blueTeam).state == "home")
	check("...nobody paid for it", Match:Stats(blue2).returns == 1)
end
-- an enemy picks a dropped flag back up
Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
do
	stand(red, flagHome(blueTeam) + Vector3.new(1, 2, 0))
	Engine.advance(0.3)
	stand(red, Vector3.new(-5, 3, -30))
	Combat:Kill(red, blue, { weapon = "bow" })
	Engine.advance(0.2)
	local at = Ctf:Flag(blueTeam).pos
	stand(red2, at + Vector3.new(0, 2, 1))
	Engine.advance(0.3)
	check(
		"an enemy picks the dropped flag back up",
		Ctf:Carrying(red2) == blueTeam and Ctf:Flag(blueTeam).state == "carried"
	)
	check("...the dropped one is gone from the floor", ws.Flags:FindFirstChild("Dropped_" .. blueTeam) == nil)
	-- the classic rule: no capture while your own flag is away
	stand(blue, flagHome(redTeam) + Vector3.new(-1, 2, 0))
	Engine.advance(0.3)
	check("the other side takes yours meanwhile", Ctf:Carrying(blue) == redTeam)
	stand(red2, flagHome(redTeam) + Vector3.new(1, 2, 1))
	Engine.advance(0.3)
	check("no capture while your own flag is away", Ctf:Carrying(red2) == blueTeam and Ctf:Scores()[redTeam] == 0)
	-- blue's carrier goes down on red's half; red2 (carrying) returns red's flag by touching it, then captures
	local m2 = mark()
	local shards0 = Data:Get(red2).shards or 0
	stand(blue, Vector3.new(sideOf(redTeam) * 30, 3, 10))
	Combat:Kill(blue, red2, { weapon = "blade" })
	Engine.advance(0.2)
	local dropped = Ctf:Flag(redTeam).pos
	stand(red2, dropped + Vector3.new(0, 2, 0))
	Engine.advance(0.3)
	check(
		"a carrier can still return their own dropped flag",
		Ctf:Flag(redTeam).state == "home" and Ctf:Carrying(red2) == blueTeam
	)
	stand(red2, flagHome(redTeam) + Vector3.new(1, 2, 1))
	Engine.advance(0.3)
	check("home with it and yours home: a CAPTURE", Ctf:Scores()[redTeam] == 1, Ctf:Scores()[redTeam])
	check("...the flag is back on the enemy stand", Ctf:Flag(blueTeam).state == "home" and Ctf:Carrying(red2) == nil)
	check(
		"...paid the capture (and the return, and the knockout)",
		(Data:Get(red2).shards or 0) == shards0 + Shop.EARN.perKill + Shop.EARN.flagReturn + Shop.EARN.capture,
		Data:Get(red2).shards
	)
	check("...the capture alert for everyone", firedSince(m2, "Alert", nil, function(a)
		return string.find(a[1], "CAPTURES") ~= nil
	end) ~= nil)
	check("...the scores went out", lastFired("Ctf", blue).scores[redTeam] == 1)
	check("...counted on the player", Match:Stats(red2).captures == 1)
end
Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
check(
	"HUD: the score on the board",
	refs.ctfSides[redTeam].score.Text == "1" and refs.ctfSides[blueTeam].score.Text == "0"
)

-- The HUD in the fight: the markers, the carry banner, the bow down ----------------------------------------------
do
	local mine = Teams:Team(ava)
	local enemy = Formulas.enemyOf(mine)
	local foe = mine == redTeam and blue or red -- (someone on the other side)
	local at = flagHome(enemy)
	local cam = ws.CurrentCamera
	cam.CFrame = CFrame.lookAt(at + Vector3.new(-sideOf(enemy) * 30, 8, 0), at)
	Engine.advance(0.1)
	local mk = refs.flagMarkers[enemy]
	check(
		"HUD: a marker on the enemy flag, in view",
		mk.frame.Visible and mk.caption.Text == "ENEMY FLAG" and mk.frame:GetAttribute("InView") == true,
		mk.caption.Text
	)
	check("HUD: ...none on your own flag at home", refs.flagMarkers[mine].frame.Visible == false)
	cam.CFrame = CFrame.lookAt(at + Vector3.new(-sideOf(enemy) * 30, 8, 0), at + Vector3.new(-sideOf(enemy) * 60, 8, 0))
	Engine.advance(0.1)
	check(
		"HUD: ...behind you: at the screen's edge, pointing",
		mk.frame.Visible and mk.frame:GetAttribute("InView") == false and mk.arrow.Visible == true
	)
	stand(ava, at + Vector3.new(1, 2, 0))
	Engine.advance(0.3)
	check("carrying", Ctf:Carrying(ava) == enemy)
	check(
		"HUD: YOU HAVE THE FLAG: RUN HOME!",
		refs.carry.Visible == true and refs.carry.Text:find("RUN HOME") ~= nil,
		refs.carry.Text
	)
	check(
		"HUD: ...the enemy's flag reads TAKEN",
		refs.ctfSides[enemy].flag.Text:find("TAKEN") ~= nil,
		refs.ctfSides[enemy].flag.Text
	)
	check("HUD: ...no marker on the flag on your back", mk.frame.Visible == false)
	Combat:Equip(ava, "bow")
	Engine.advance(0.2)
	check("the client won't draw the bow while carrying", Weapon.startDraw() == false and Weapon.drawing() == false)
	stand(ava, Vector3.new(0, 3, -20))
	Combat:Kill(ava, foe, { weapon = "bow" })
	Engine.advance(0.2)
	check(
		"HUD: dropped: the marker is back, saying so",
		mk.frame.Visible and mk.caption.Text:find("DROPPED") ~= nil,
		mk.caption.Text
	)
	check("HUD: ...the board too", refs.ctfSides[enemy].flag.Text:find("DROPPED") ~= nil)
	check("HUD: ...no banner", refs.carry.Visible == false)
	Engine.advance(Constants.CTF.FLAG_RETURN_SECONDS + 0.5)
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	-- the other side takes yours
	stand(foe, flagHome(mine) + Vector3.new(1, 2, 0))
	Engine.advance(0.3)
	check("they took yours", Ctf:Carrying(foe) == mine)
	check(
		"HUD: THEY HAVE YOUR FLAG!",
		refs.carry.Visible == true and refs.carry.Text:find("YOUR FLAG") ~= nil,
		refs.carry.Text
	)
	local own = refs.flagMarkers[mine]
	check(
		"HUD: ...a marker on its carrier",
		own.frame.Visible == true and own.caption.Text:find("YOUR FLAG") ~= nil,
		own.caption.Text
	)
	stand(foe, Vector3.new(0, 3, 24))
	Combat:Kill(foe, ava, { weapon = "bow" })
	Engine.advance(0.2)
	check(
		"HUD: ...dropped: RETURN IT!",
		own.frame.Visible == true and own.caption.Text:find("RETURN IT") ~= nil,
		own.caption.Text
	)
	stand(ava, Ctf:Flag(mine).pos + Vector3.new(0, 2, 0))
	Engine.advance(0.3)
	check("...returned", Ctf:Flag(mine).state == "home" and own.frame.Visible == false)
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
end

-- Late joiners: the side behind on even teams, the smaller side on odd -----------------------------------------
do
	local eve = Engine.addPlayer("Eve", 505)
	Engine.advance(0.3)
	send(eve, "Ready")
	Engine.advance(0.5)
	check("a late joiner is in the match at once", Teams:Team(eve) ~= nil and Combat:Alive(eve))
	check("...on the side behind (even teams: the lower score)", Teams:Team(eve) == blueTeam, Teams:Team(eve))
	local fay = Engine.addPlayer("Fay", 506)
	Engine.advance(0.3)
	send(fay, "Ready")
	Engine.advance(0.5)
	check("odd teams: the smaller side", Teams:Team(fay) == redTeam, Teams:Team(fay))
	check("still no bots", #Bots:List() == 0)
	Engine.removePlayer(eve)
	Engine.removePlayer(fay)
	Engine.advance(0.5)
end

-- First to three ------------------------------------------------------------------------------------------------
local function captureBy(p)
	local mine, enemy = Teams:Team(p), Formulas.enemyOf(Teams:Team(p))
	stand(p, flagHome(enemy) + Vector3.new(1, 2, 0))
	Engine.advance(0.3)
	stand(p, flagHome(mine) + Vector3.new(1, 2, 1))
	Engine.advance(0.3)
end
local mWin = mark()
captureBy(red)
check("two", Ctf:Scores()[redTeam] == 2, Ctf:Scores()[redTeam])
check("...still fighting", ws:GetAttribute("Phase") == "fight")
captureBy(red2)
Engine.advance(0.3)
check(
	"three captures: the win",
	ws:GetAttribute("Phase") == "victory" and ws:GetAttribute("Winner") == redTeam,
	ws:GetAttribute("Winner")
)
local results = lastFired("Results", red)
do
	Engine.advance(0.2)
	local caps = false
	for _, d in (refs.results and refs.results:GetDescendants() or {}) do
		if d:IsA("TextLabel") and d.Text:find("CAPS") then
			caps = true
		end
	end
	check("HUD: the results card has a CAPS column", refs.results ~= nil and caps)
end
check("the results went out", results and results.winner == redTeam)
check("...with the captures on each row", results and results.rows[1].captures ~= nil)
check("...the top row is a capturer", results and results.rows[1].captures >= 1, results and results.rows[1].captures)
check("...the winners hear it in the mode's team name", firedSince(mWin, "Announce", nil, function(a)
	return a[1].kind == "win" and string.find(a[1].text, "team wins") ~= nil
end) ~= nil)
check("the blades go away with the fight", ws:GetAttribute("Charge") == nil)
check("the flags are home for the wait", Ctf:Flag(redTeam).state == "home" and Ctf:Flag(blueTeam).state == "home")
do
	local p = Data:Get(red2)
	check("the match paid: Shards and a win", (p.shards or 0) >= Shop.EARN.match and p.wins >= 0)
	check("a capture counts as being active", results.you and results.you.won == true)
end

-- The next match: whoever played stays READY, so it starts at once; the clock and sudden death ------------------
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1.5)
check(
	"the next match starts straight away (four still READY)",
	ws:GetAttribute("Phase") == "build",
	ws:GetAttribute("Phase")
)
check("the scores are back to nothing", Ctf:Scores().red == 0 and Ctf:Scores().blue == 0)
Match:SkipTo("fight")
Engine.advance(0.3)
do
	-- one each, then the clock runs out: sudden death
	captureBy(red)
	captureBy(blue)
	check("one each", Ctf:Scores().red == 1 and Ctf:Scores().blue == 1)
	local mSd = mark()
	Match:_setPhase("fight", 0.2)
	Engine.advance(0.6)
	check(
		"a tie at the clock: sudden death",
		ws:GetAttribute("Phase") == "fight" and Match:SuddenDeath() == true,
		ws:GetAttribute("Phase")
	)
	check(
		"...for one minute",
		math.abs((ws:GetAttribute("PhaseEnds") - Engine.now()) - Constants.CTF.SUDDEN_DEATH_SECONDS) < 1
	)
	check("...with the alert", firedSince(mSd, "Alert", nil, function(a)
		return a[1] == "SUDDEN DEATH"
	end) ~= nil)
	check("...the clients hear it", lastFired("Match", red).sudden == true and lastFired("Ctf", red).sudden == true)
	check("HUD: the pill says SUDDEN DEATH", refs.phase.Text:find("SUDDEN DEATH") ~= nil, refs.phase.Text)
	captureBy(blue)
	Engine.advance(0.3)
	check(
		"the first capture of sudden death wins",
		ws:GetAttribute("Phase") == "victory" and ws:GetAttribute("Winner") == blueTeam,
		ws:GetAttribute("Winner")
	)
end
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1.5)
Match:SkipTo("fight")
Engine.advance(0.3)
do
	-- ahead at the clock: the most captures wins; a tie through sudden death is a draw
	captureBy(blue)
	Match:_setPhase("fight", 0.2)
	Engine.advance(0.6)
	check(
		"ahead when the clock ends: the win",
		ws:GetAttribute("Phase") == "victory" and ws:GetAttribute("Winner") == blueTeam,
		ws:GetAttribute("Winner")
	)
end
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1.5)
Match:SkipTo("fight")
Engine.advance(0.3)
do
	Match:_setPhase("fight", 0.2)
	Engine.advance(0.6)
	check("level at the clock: sudden death", Match:SuddenDeath() == true)
	Match:_setPhase("fight", 0.2)
	Engine.advance(0.6)
	check(
		"still level: a draw",
		ws:GetAttribute("Phase") == "victory" and ws:GetAttribute("Winner") == "draw",
		ws:GetAttribute("Winner")
	)
end

-- A kill in the fight pushes nothing, and pays as today -----------------------------------------------------------
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1.5)
Match:SkipTo("fight")
Engine.advance(0.3)
do
	local shards0 = Data:Get(blue).shards or 0
	local m3 = mark()
	Combat:Kill(red, blue, { weapon = "bow" })
	Engine.advance(0.2)
	local k = firedSince(m3, "Kill", nil)
	check("a kill goes to the feed with no push", k and k.args[1].push == 0 and ws:GetAttribute("Frontline") == 0)
	check("...and pays as today", (Data:Get(blue).shards or 0) == shards0 + Shop.EARN.perKill)
end

-- Leaving with the flag drops it; the queue after a leaver ----------------------------------------------------------
Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
do
	stand(blue, flagHome(redTeam) + Vector3.new(-1, 2, 0))
	Engine.advance(0.3)
	check("carrying", Ctf:Carrying(blue) == redTeam)
	Engine.removePlayer(blue)
	Engine.advance(0.3)
	check("leaving with the flag drops it", Ctf:Flag(redTeam).state == "dropped")
	check("...and the leaver is out of the queue", Ctf:ReadyCount() == 3)
	Engine.advance(Constants.CTF.FLAG_RETURN_SECONDS + 0.5)
	check("...it goes home", Ctf:Flag(redTeam).state == "home")
	Match:Victory("draw")
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1.5)
	check("three READY: waiting again", ws:GetAttribute("Phase") == "waiting", ws:GetAttribute("Phase"))
	check("...the clients hear 3/4", lastFired("Ctf", red).waiting == true and lastFired("Ctf", red).ready == 3)
end

print(`CtfSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} checks failed`)
end

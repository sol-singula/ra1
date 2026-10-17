--[[
How the fight feels: aim help on a touch screen (and a little on a stick; none for a mouse veteran), the first
knockout made sure of (CombatService:Novice: help onto an enemy, a softer bot, faster respawns, a longer shield),
short dead time, and forgiving hits for a laggy shooter (the target where they saw it, their ping ago, and a touch
wider). A thumb's arrows meet 30% bigger spheres (capped, whatever is reported), near misses tell their target where
they came from (rate-limited), new players' first three matches get more aim help and softer bots (fading), the
comeback shield after three knockouts in a row, and bots that go easy on thumbs and pick a mouse first.

  luaurun tests/FeelSmoke.spec.luau
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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0
Engine.require(tree.shared.Constants).TUTORIAL = false
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Match = service("MatchService")
local Bots = service("BotService")
local Constants = Engine.require(tree.shared.Constants)
local Weapons = Engine.require(tree.shared.Data.Weapons)
local Formulas = Engine.require(tree.shared.Formulas)
local Analytics = service("AnalyticsService")
Combat.comebackShield = false -- (on for its own checks below: the losing streaks of the checks before it aren't real)

local function send(player, name, ...)
	Engine.fireServer(player, name, ...)
	Engine.advance(0.05)
end
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function eye(p)
	return rootOf(p).Position + Vector3.new(0, 1.5, 0)
end
local function angle(a, b)
	return math.deg(math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end
-- a direction turned `deg` degrees sideways (round Y) from d
local function turned(d, deg)
	local r = math.rad(deg)
	return Vector3.new(d.X * math.cos(r) - d.Z * math.sin(r), d.Y, d.X * math.sin(r) + d.Z * math.cos(r)).Unit
end
local function veteran(p)
	local st = Data:Get(p).stats
	st.kills, st.matches = 50, 50
end

local a = Engine.addPlayer("Shooter", 7101)
local b = Engine.addPlayer("Target", 7102)
Engine.advance(1)
Engine.fireServer(a, "Ready")
Engine.fireServer(b, "Ready")
Engine.advance(1)
veteran(a)
veteran(b)
if Teams:Team(a) == Teams:Team(b) then
	Teams:Set(b, Teams:Team(a) == "red" and "blue" or "red")
end
Match:SkipTo("fight")
Engine.advance(4) -- (past the spawn shield)
local fa = Teams:Team(a) == "red" and -1 or 1 -- (a's side of the line)
local function placeLane(z)
	Engine.moveTo(a, Vector3.new(fa * 18, 3, z), Vector3.new(-fa * 18, 3, z))
	Engine.moveTo(b, Vector3.new(-fa * 18, 3, z), Vector3.new(fa * 18, 3, z))
	Engine.advance(0.1)
end

-- 1. aim help by device --------------------------------------------------------------------------------------------
do
	placeLane(0)
	local origin = eye(a)
	local ideal = (rootOf(b).Position + Vector3.new(0, 0.6, 0) - origin).Unit
	local off = turned(ideal, 5)
	local speed = 200
	a:SetAttribute("Device", "keyboard")
	local kb = Combat:Assist(a, origin, off, speed)
	check("a mouse veteran: no aim help", angle(kb, off) < 0.01, angle(kb, off))
	a:SetAttribute("Device", "touch")
	local tc = Combat:Assist(a, origin, off, speed)
	check(
		"on a touch screen: a shot 5° off turns well onto them",
		angle(tc, ideal) < angle(off, ideal) - 2,
		`{angle(off, ideal)} -> {angle(tc, ideal)}`
	)
	a:SetAttribute("Device", "gamepad")
	local gp = Combat:Assist(a, origin, off, speed)
	check(
		"on a gamepad: a little help, less than touch",
		angle(gp, ideal) < angle(off, ideal) - 0.5 and angle(gp, ideal) > angle(tc, ideal),
		`{angle(gp, ideal)}`
	)
	a:SetAttribute("Device", "touch")
	local far = turned(ideal, 20)
	check("...but a shot 20° off stays a miss (veteran)", angle(Combat:Assist(a, origin, far, speed), far) < 0.01)
	check("50 knockouts: no novice", not Combat:Novice(a))
	a:SetAttribute("Device", "keyboard")
end

-- 2. lag: a laggy shooter hits where they saw the target ----------------------------------------------------------
local lane
do
	-- a clear lane: the plain shot straight at them lands
	for _, z in { 0, 8, -8, 16, -16, 24, -24 } do
		placeLane(z)
		Engine.advance(3) -- (a fresh life's shield and the deck's safety are long gone)
		Engine.advance(Weapons.get("bow").cooldown)
		send(a, "Draw", true)
		Engine.advance(Weapons.get("bow").draw + 0.05)
		local o = eye(a)
		local d = (rootOf(b).Position + Vector3.new(0, 0.2, 0) - o).Unit
		send(a, "Shoot", o, d, 200 + z)
		Engine.advance(1)
		if not Combat:Alive(b) then
			lane = z
			break
		end
	end
	check("(a clear lane between them)", lane ~= nil)
	Engine.advance(Constants.RESPAWN_SECONDS + 1)
	local pings = {}
	local realPing = Combat.pingOf
	Combat.pingOf = function(p)
		return pings[p] or 0
	end
	local function trial(ping)
		pings[a] = ping
		placeLane(lane)
		Engine.advance(4.5)
		local seen = rootOf(b).Position -- where the shooter "saw" them
		Engine.advance(0.6) -- (the history keeps it)
		send(a, "Draw", true)
		Engine.advance(Weapons.get("bow").draw + 0.05)
		-- they step 5 studs aside just before the shot comes in
		Engine.moveTo(b, seen + Vector3.new(0, 0, 5), seen + Vector3.new(fa * 30, 0, 5))
		Engine.advance(0.05)
		local o = eye(a)
		send(a, "Shoot", o, (seen + Vector3.new(0, 0.2, 0) - o).Unit, 300 + ping * 1000)
		Engine.advance(1)
		local hit = not Combat:Alive(b)
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
		return hit
	end
	check("no lag: a shot where they were (they moved) misses", not trial(0))
	check("250 ms ping: it hits where they saw them (rewound)", trial(0.25))
	pings[a] = 0.6
	check("...the rewind is capped (600 ms ping looks back at most 300 ms)", Constants.LAG_REWIND_MAX <= 0.3)
	Combat.pingOf = realPing
end

-- 3. dead time ----------------------------------------------------------------------------------------------------
do
	check("respawn: 2 s (was 3)", Constants.RESPAWN_SECONDS <= 2)
	Engine.advance(3)
	Combat:Kill(b, a, { weapon = "bow" })
	Engine.advance(Constants.RESPAWN_SECONDS - 0.4)
	check("...not before", not Combat:Alive(b))
	Engine.advance(0.9)
	check("...back after", Combat:Alive(b))
	Data:Get(b).stats.kills = 0 -- (a novice)
	Engine.advance(3)
	Combat:Kill(b, a, { weapon = "bow" })
	Engine.advance(Constants.RESPAWN_SECONDS_NEW + 0.4)
	check("a novice is back in 1.5 s", Combat:Alive(b))
	-- the first knockout's help: a novice's shot 20° off (in the clear lane) is aimed onto them
	placeLane(lane)
	Engine.advance(0.2)
	local origin = eye(b)
	local ideal = (rootOf(a).Position + Vector3.new(0, 0.6, 0) - origin).Unit
	check("no knockout ever yet: a novice", Combat:Novice(b))
	local nv = Combat:Assist(b, origin, turned(ideal, 20), 200)
	check(
		"a novice's shot 20° off is aimed onto them (bar the lift for the drop)",
		angle(nv, ideal) < 5,
		angle(nv, ideal)
	)
	veteran(b)
end

-- (a fresh fight for each of the checks below: the clock full, the line back in the middle)
local function freshFight()
	Match:_setPhase("fight", Constants.FIGHT_SECONDS)
	Match:_setFrontline(0)
	for _, p in { a, b } do
		if not Combat:Alive(p) then
			Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
		end
	end
	Match:_setFrontline(0)
end
local function count(name, to, from)
	local n = 0
	for i = from + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == name and (to == nil or e.player == to or e.player == "all") then
			n += 1
		end
	end
	return n
end
local function events(p, kind)
	local s = Analytics:Session(p)
	return s and s.counts[kind] or 0
end

-- 5. a thumb's arrows: the server's target spheres are 30% bigger (head and body), capped whatever is reported; a
-- mouse's and a pad's as they were. An arrow passing close tells its target where it came from. ------------------
do
	freshFight()
	local realAssist = Combat.AssistFor
	Combat.AssistFor = function()
		return nil -- (the spheres alone: no aim help turning the shot onto them)
	end
	local bow = Weapons.get("bow")
	local speed = Formulas.shot(bow, 1).speed
	local shotN = 0
	-- a full draw aimed `off` studs to the side of b's body, the drop allowed for; hit?, near misses b was told of
	local function sideShot(device, off)
		a:SetAttribute("Device", device)
		placeLane(lane)
		Engine.advance(3) -- (the spawn shield and the deck's safety long gone)
		send(a, "Draw", true)
		Engine.advance(bow.draw + 0.05)
		local o = eye(a)
		local body = rootOf(b).Position + Vector3.new(0, 0.2, 0)
		local flat = Vector3.new(body.X - o.X, 0, body.Z - o.Z).Unit
		local at = body + Vector3.new(-flat.Z, 0, flat.X) * off
		local tt = (at - o).Magnitude / speed
		local d = (at + Vector3.new(0, 0.5 * Constants.GRAVITY * tt * tt, 0) - o).Unit
		local m = #Engine.clientLog
		shotN += 1
		send(a, "Shoot", o, d, 5000 + shotN)
		Engine.advance(1)
		local hit = not Combat:Alive(b)
		local threat = Engine.lastClientEvent("Threat", b)
		local told = count("Threat", b, m)
		if hit then
			Engine.advance(Constants.RESPAWN_SECONDS + 1)
			Match:_setFrontline(0)
		end
		return hit, told, threat and threat.args[1]
	end
	a:SetAttribute("Device", "keyboard")
	check("a mouse's arrows: plain spheres", Combat:HitScale(a) == 1)
	local hit, told, threat = sideShot("keyboard", 2.65)
	check("a mouse's arrow 2.65 studs to the side of the body: a miss", not hit)
	check("...and the target is told of the near miss", told == 1, told)
	check("...where it was shot from", threat and (threat.from - eye(a)).Magnitude < 3 and threat.by == a.UserId)
	check("a pad's arrow there: a miss too", not sideShot("gamepad", 2.65))
	check("a thumb's arrow there: a hit (spheres 30% bigger)", sideShot("touch", 2.65))
	check("...head and body", Constants.TOUCH_HIT_SCALE.touch == 1.3 and Combat:HitScale(a) == 1.3)
	check("...a thumb's arrow 3.4 studs off still misses", not sideShot("touch", 3.4))
	-- a client can only report "touch", "gamepad" or "keyboard", and however big the table's number, never past the cap
	Constants.TOUCH_HIT_SCALE.touch = 3
	check("a spoofed bigger bonus is capped", Combat:HitScale(a) == Constants.TOUCH_HIT_MAX)
	check("...the arrow 3.4 studs off still misses", not sideShot("touch", 3.4))
	Constants.TOUCH_HIT_SCALE.touch = 1.3
	a:SetAttribute("Device", "cheat")
	check("...an unknown device: plain", Combat:HitScale(a) == 1)
	a:SetAttribute("Device", "keyboard")
	Combat.AssistFor = realAssist
	-- near misses: at most one every NEAR_MISS_GAP for anyone, never for the shooter's own side
	placeLane(lane)
	local br = rootOf(b).Position
	local p1, p2 = br + Vector3.new(0, 1, -10), br + Vector3.new(0, 1, 10)
	local function fake(team)
		return { by = a, team = team or Teams:Team(a), origin = eye(a) }
	end
	Engine.advance(Constants.NEAR_MISS_GAP + 0.05)
	local m = #Engine.clientLog
	Combat:_nearMiss(fake(), p1, p2)
	Combat:_nearMiss(fake(), p1, p2)
	check("two near misses at once: told once (rate-limited)", count("Threat", b, m) == 1, count("Threat", b, m))
	Engine.advance(Constants.NEAR_MISS_GAP + 0.05)
	Combat:_nearMiss(fake(), p1, p2)
	check("...and again a moment later", count("Threat", b, m) == 2)
	Engine.advance(Constants.NEAR_MISS_GAP + 0.05)
	Combat:_nearMiss(fake(Teams:Team(b)), p1, p2)
	check("...never their own side's arrows", count("Threat", b, m) == 2)
	Combat:_nearMiss(fake(), br + Vector3.new(30, 1, -10), br + Vector3.new(30, 1, 10))
	check("...nor one 30 studs off", count("Threat", b, m) == 2)
	-- a hit says where it came from too (Hurt carries the shooter)
	Engine.advance(3)
	send(a, "Draw", true)
	Engine.advance(bow.draw + 0.05)
	local o = eye(a)
	send(a, "Shoot", o, (rootOf(b).Position + Vector3.new(0, 0.2, 0) - o).Unit, 5900)
	Engine.advance(1)
	local hurt = Engine.lastClientEvent("Hurt", b)
	check(
		"a hit (the knockout) tells the victim the shooter: Hurt.from, Hurt.by",
		not Combat:Alive(b) and hurt and (hurt.args[1].from - o).Magnitude < 0.1 and hurt.args[1].by == a.UserId
	)
end

-- 6. new players' first three matches after the tutorial: more aim help (on top of the device's, capped), the
-- bots softer, both fading match by match; logged once a match ------------------------------------------------
do
	freshFight()
	placeLane(lane)
	Engine.advance(0.2)
	local st = Data:Get(a).stats
	local origin = eye(a)
	local ideal = (rootOf(b).Position + Vector3.new(0, 0.6, 0) - origin).Unit
	local off = turned(ideal, 4.5)
	a:SetAttribute("Device", "keyboard")
	local turns = {}
	for m = 0, 3 do
		st.matches = m
		turns[m] = angle(Combat:Assist(a, origin, off, 200), off)
	end
	check(
		"a mouse, 4.5° off: helped in the first match, less in the 2nd, less again in the 3rd",
		turns[0] > turns[1] and turns[1] > turns[2] and turns[2] > 0.5,
		`{turns[0]} {turns[1]} {turns[2]}`
	)
	check("...and from the 4th on, only the whisper (which doesn't reach 4.5°)", turns[3] < 0.01, turns[3])
	st.matches = 0
	local kb = Combat:AssistFor(a)
	check(
		"...a mouse's first match: between the whisper and a thumb's",
		kb.cone > Constants.AIM_ASSIST_CONE
			and kb.cone < Constants.AIM_ASSIST_DEVICE.touch.cone
			and kb.max > Constants.AIM_ASSIST_MAX
			and kb.max < Constants.AIM_ASSIST_DEVICE.touch.max,
		`{kb.cone} {kb.pull} {kb.max}`
	)
	a:SetAttribute("Device", "touch")
	local tc = Combat:AssistFor(a)
	local cap = Constants.NEW_PLAYER_AIM_CAP
	check(
		"a thumb's first match: on top of the touch help, capped",
		tc.cone > Constants.AIM_ASSIST_DEVICE.touch.cone
			and tc.cone <= cap.cone
			and tc.pull <= cap.pull
			and tc.max <= cap.max,
		`{tc.cone} {tc.pull} {tc.max}`
	)
	st.matches = 3
	local t3 = Combat:AssistFor(a)
	check("...from the 4th match: the touch help alone", t3.cone == Constants.AIM_ASSIST_DEVICE.touch.cone)
	-- the bots: softer, fading
	a:SetAttribute("Device", "keyboard")
	local spreads = {}
	for m = 0, 3 do
		st.matches = m
		spreads[m] = { Bots.softness(a) }
	end
	check(
		"bots against a new player: shakier and slower in the first match, less each match, plain from the 4th",
		spreads[0][1] > spreads[1][1]
			and spreads[1][1] > spreads[2][1]
			and spreads[2][1] > 1
			and spreads[0][2] > spreads[2][2]
			and spreads[3][1] == 1
			and spreads[3][2] == 1,
		`{spreads[0][1]} {spreads[1][1]} {spreads[2][1]} {spreads[3][1]}`
	)
	-- logged: once a match while it's on
	st.matches = 1
	local n0 = events(a, "new_help")
	Engine.workspace:SetAttribute("MatchId", 9001) -- (as if a new match: it was logged in this one when they joined)
	Combat:Spawned(a)
	Combat:Spawned(a)
	check(
		"the help is logged once a match (analytics new_help)",
		events(a, "new_help") == n0 + 1,
		events(a, "new_help")
	)
	veteran(a)
	Combat:Spawned(a)
	check("...never for a veteran", events(a, "new_help") == n0 + 1)
	check("veterans: no help, plain bots", Combat:NewHelp(a) == 0 and Bots.softness(a) == 1)
end

-- 7. the comeback shield: three knockouts in a row without one of your own, the next life blocks one hit ----------
do
	Combat.comebackShield = true
	freshFight()
	a:SetAttribute("Device", "keyboard")
	-- (b scores first: no streak to start from)
	Combat:Kill(a, b, { weapon = "bow" })
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	Match:_setFrontline(0)
	local function down(p)
		Combat:Kill(p, a, { weapon = "bow" })
		Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
		Match:_setFrontline(0)
	end
	local granted0 = events(b, "shield_granted")
	down(b)
	down(b)
	check("two knockouts in a row: no shield yet", Combat:Alive(b) and not Combat:Shielded(b))
	local m = #Engine.clientLog
	down(b)
	check("the third: the next life has a comeback shield", Combat:Alive(b) and Combat:Shielded(b))
	local bubble = b.Character and b.Character:FindFirstChild("ComebackShield")
	check(
		"...a bubble round them that everyone sees (on the server's body), out of every query",
		bubble ~= nil and bubble.CanQuery == false and bubble.CanCollide == false and b:GetAttribute("Shield") == true
	)
	check("...they're told", count("Shield", b, m) >= 1 and Engine.lastClientEvent("Shield", b).args[1].kind == "on")
	check("...logged (shield_granted)", events(b, "shield_granted") == granted0 + 1)
	check("...one at a time", Combat:GiveShield(b) == false)
	-- an arrow straight at them: the shield takes it and pops; they're still up
	placeLane(lane)
	Engine.advance(3)
	local bow = Weapons.get("bow")
	local function shoot(id)
		send(a, "Draw", true)
		Engine.advance(bow.draw + 0.05)
		local o = eye(a)
		send(a, "Shoot", o, (rootOf(b).Position + Vector3.new(0, 0.2, 0) - o).Unit, id)
		Engine.advance(1)
	end
	m = #Engine.clientLog
	shoot(6001)
	local pop = Engine.lastClientEvent("Shield", b)
	check("a hit on the shield: they're still up", Combat:Alive(b))
	check("...the shield is gone", not Combat:Shielded(b) and b.Character:FindFirstChild("ComebackShield") == nil)
	check(
		"...a SHIELD! pop for everyone, where they stand",
		pop
			and pop.player == "all"
			and pop.args[1].kind == "break"
			and (pop.args[1].pos - rootOf(b).Position).Magnitude < 3
	)
	check("...logged (shield_broken)", events(b, "shield_broken") == 1)
	Engine.advance(bow.cooldown)
	shoot(6002)
	check("the next hit knocks them out (one hit still kills)", not Combat:Alive(b))
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	Match:_setFrontline(0)
	check("...and the streak starts again: no shield", not Combat:Shielded(b))
	-- it goes when they score, or after a minute
	Combat:GiveShield(b)
	Combat:Kill(a, b, { weapon = "bow" })
	check("a knockout of their own: the shield goes", not Combat:Shielded(b))
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	Match:_setFrontline(0)
	Combat:GiveShield(b)
	Engine.advance(Constants.COMEBACK_SECONDS - 1)
	check("...it lasts a minute", Combat:Shielded(b))
	Engine.advance(1.5)
	check("...and then goes", not Combat:Shielded(b) and b:GetAttribute("Shield") == nil)
	check("...logged (shield_expired)", events(b, "shield_expired") >= 2)
	-- not for a menu Reset
	for _ = 1, 3 do
		Combat:Kill(b, nil, { kind = "reset" })
		Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	end
	check("resets don't earn a shield", Combat:Alive(b) and not Combat:Shielded(b))
	Combat.comebackShield = false
end

-- 8. bots go easy on thumbs: shakier and slower at a touch player, and a mouse in view is picked first ----------
do
	freshFight()
	Bots:SetEnabled(false) -- (three people would get a bot: this only asks who a bot would pick)
	local c = Engine.addPlayer("Thumb", 7104)
	Engine.advance(1)
	Engine.fireServer(c, "Ready")
	Engine.advance(1)
	veteran(c)
	Teams:Set(c, Teams:Team(b))
	Combat:Spawned(c)
	a:SetAttribute("Device", "keyboard")
	b:SetAttribute("Device", "keyboard")
	c:SetAttribute("Device", "touch")
	local ts, tr = Bots.softness(c)
	local ks, kr = Bots.softness(b)
	check("against a thumb: more aim error", ts > ks and ts == Constants.BOT_TOUCH_SPREAD, `{ts} {ks}`)
	check("...and a slower draw", tr > kr and tr == Constants.BOT_TOUCH_REACT, `{tr} {kr}`)
	Data:Get(c).stats.matches, Data:Get(c).stats.kills = 0, 0 -- (a brand-new thumb, still waiting for a knockout)
	local ns, nr = Bots.softness(c)
	check(
		"...never past the caps",
		ns <= Constants.BOT_EASY_SPREAD_MAX and nr <= Constants.BOT_EASY_REACT_MAX,
		`{ns} {nr}`
	)
	veteran(c)
	-- the bot's eyes: a just on its side of the line in the lane; b (a mouse) 20 studs off, c (a thumb) 9, both on
	-- their own side
	placeLane(lane)
	Engine.moveTo(a, Vector3.new(fa * 2, 3, rootOf(a).Position.Z), Vector3.new(-fa * 18, 3, rootOf(a).Position.Z))
	local ar = rootOf(a).Position
	local function at(p, dx)
		Engine.moveTo(p, Vector3.new(ar.X - fa * dx, 3, ar.Z), ar)
	end
	at(b, 20)
	at(c, 9)
	Engine.advance(0.1)
	check("a mouse 20 studs off and a thumb 9: the bot picks the mouse", Bots:Target(a, rootOf(a)) == b)
	at(c, 4)
	Engine.advance(0.1)
	check("...a thumb right up close (4): the thumb", Bots:Target(a, rootOf(a)) == c)
	c:SetAttribute("Device", "keyboard")
	at(c, 9)
	Engine.advance(0.1)
	check("...two mice: the nearer", Bots:Target(a, rootOf(a)) == c)
	c:Destroy()
	Engine.advance(1)
	Bots:SetEnabled(true)
end

-- 4. the first knockout: a fresh player alone against a bot lands one quickly ----------------------------------
do
	b:Destroy()
	a:Destroy()
	Engine.advance(2)
	a = Engine.addPlayer("Fresh", 7103) -- (a brand-new player: no knockout ever)
	Engine.advance(1)
	Engine.fireServer(a, "Ready")
	Engine.advance(1)
	Match:NewMatch()
	for _ = 1, 40 do
		Engine.advance(1)
		if Match:Phase() == "build" then
			break
		end
	end
	Match:SkipTo("fight")
	Engine.advance(0.5)
	check("alone: a bot to fight", #Bots:List() >= 1, #Bots:List())
	check("a fresh player is a novice", Combat:Novice(a) and a:GetAttribute("Novice") == true)
	local start = Engine.now()
	local got, shots = false, 0
	local wobble = { -12, 9, -4, 14, -15, 6, 0, -9, 11, -2 }
	while Engine.now() - start < 45 do
		local bot = Bots:List()[1]
		local br = bot and rootOf(bot)
		if Combat:Alive(a) and br then
			send(a, "Draw", true)
			Engine.advance(Weapons.get("bow").draw + 0.05)
			if not Combat:Alive(a) then
				continue
			end
			-- aimed roughly at the bot (within 15°, a new player's wobble)
			local o = eye(a)
			shots += 1
			local d = turned((br.Position - o).Unit, wobble[(shots - 1) % #wobble + 1])
			send(a, "Shoot", o, d, 900 + shots)
			Engine.advance(0.9)
		else
			Engine.advance(0.5)
		end
		if Match:Stats(a) and (Match:Stats(a).kills or 0) > 0 then
			got = true
			break
		end
	end
	check(
		"a fresh player aiming roughly at the bot knocks it out within 45 s",
		got,
		`{shots} shots, {math.floor(Engine.now() - start)} s`
	)
	check("...and the help ends with it", not Combat:Novice(a) and a:GetAttribute("Novice") == nil)
end

print(`FeelSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("FeelSmoke failed")
end

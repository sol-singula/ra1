--[[
How the fight feels: aim help on a touch screen (and a little on a stick; none for a mouse veteran), the first
knockout made sure of (CombatService:Novice: help onto an enemy, a softer bot, faster respawns, a longer shield),
short dead time, and forgiving hits for a laggy shooter (the target where they saw it, their ping ago, and a touch
wider).

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

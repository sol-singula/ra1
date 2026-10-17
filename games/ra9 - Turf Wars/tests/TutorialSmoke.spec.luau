--[[
The new-player tutorial, end to end: the real server and the real client on the mock engine. A veteran is playing
the live match when a brand-new player joins: the newcomer is taken to a private practice arena of their own, far
from the match (out of the match, the bots, the balancing, the watchdog, the AFK room and the anti-cheat; nothing
from the match reaches them), and plays the whole show the way a new player would: the intro, the first kill
(within seconds of having control), DOUBLE KILL! TRIPLE KILL! (paid in Shards), the near-miss (the camera's at
once, their shots held), the build (the tray up within a moment of BUILD TIME, one wall, the clock waiting, three
arrows into the wall), the TNT, the push, the win (fireworks, VICTORY!, a free trail), the gate, and into the live
match with a team, nothing of the practice's show left on screen. Never knocked out, under 3:00, every step timed.
Then: a replay skipped with K (straight into the match), a replay where they touch nothing (every step does its part
for them, one wall, still a win, still under 3:00), finishing while the live match is between games (they wait in
the practice for its next game, at most TUTORIAL_JOIN_WAIT), a player whose client never answers (the server's time
limit), the phone's and the pad's words, the practice arena's detail, and the returning-player rules.

  luaurun tests/TutorialSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
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
Constants.AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Constants.MIN_SIDE = 1
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = false
UIS.KeyboardEnabled = true
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Tutorial = service("TutorialService")
local Match = service("MatchService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Bots = service("BotService")
local Data = service("PlayerDataService")
local Build = service("BuildService")
local Afk = service("AfkService")
local AntiCheat = service("AntiCheatService")
local Formulas = Engine.require(tree.shared.Formulas)
local Practice = Engine.require(tree.shared.World.Practice)
local Net = Engine.require(tree.shared.Net)
local Shop = Engine.require(tree.shared.Data.Shop)

-- a veteran in the live match (they know the game: no tutorial for them)
Constants.TUTORIAL = false
local vet = Engine.addPlayer("Veteran", 700)
Engine.advance(0.5)
Engine.fireServer(vet, "Ready")
Engine.advance(1)
Constants.TUTORIAL = true
check("the veteran is in the match", Teams:Team(vet) ~= nil and Combat:Alive(vet))
local botsBefore = #Bots:List()

-- a brand-new player joins
local player = Engine.addPlayer("Newbie", 601)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
local logFrom = #Engine.clientLog
Engine.runScript(tree.client.Main)
Engine.advance(0.3)

local Tut = Engine.require(tree.client.Controllers.TutorialController)
local CamC = Engine.require(tree.client.Controllers.CameraController)
local Hud = Engine.require(tree.client.Controllers.HudController)
local BuildC = Engine.require(tree.client.Controllers.BuildController)
local WeaponC = Engine.require(tree.client.Controllers.WeaponController)
local Fireworks = Engine.require(tree.client.Controllers.FireworksController)
local Layout = Engine.require(tree.client.UI.Layout)
local Bus = Engine.require(tree.client.UI.Bus)
local Device = Engine.require(tree.client.UI.Device)
local Store = Engine.require(tree.client.Store)
local cam = ws.CurrentCamera
local refs = Tut.refs
local hud = Hud.refs
local fx = ws:FindFirstChild("TutorialFx")

local function root(who)
	return who.Character and who.Character:FindFirstChild("HumanoidRootPart")
end
local function headPos()
	return player.Character.Head.Position
end
local function state()
	return Tut.state()
end
local function names(list)
	local out = {}
	for _, e in list do
		table.insert(out, type(e) == "table" and e.name or e)
	end
	return table.concat(out, ",")
end
local function key(code)
	UIS.InputBegan:Fire({ KeyCode = code, UserInputType = Enum.UserInputType.Keyboard }, false)
end
local function untilTrue(seconds, fn)
	local t = 0
	while t < seconds do
		if fn() then
			return true
		end
		Engine.advance(0.1)
		t += 0.1
	end
	return fn()
end
local function count(name)
	local n = 0
	for _, d in fx:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end
-- every title slammed in and every instruction shown, as they come (polled each step of the clock)
local seen = {}
local function watchWords()
	if refs.title.Visible then
		seen[refs.title.Text] = seen[refs.title.Text] or Engine.now()
	end
	if refs.say.Visible then
		seen[refs.say.Text] = seen[refs.say.Text] or Engine.now()
	end
end
local function run(seconds)
	local t = 0
	while t < seconds do
		Engine.advance(0.05)
		watchWords()
		t += 0.05
	end
end
local function waitFor(seconds, fn)
	local t = 0
	while t < seconds do
		if fn() then
			return true
		end
		run(0.1)
		t += 0.1
	end
	return fn()
end
local function stepIs(name)
	return function()
		return state().step == name
	end
end
-- shoot like a new player: hold for a moment, let go (any release finds a bot: the aim help)
local function shoot(hold)
	Bus.Fire:Fire(true)
	run(hold or 1.1)
	Bus.Fire:Fire(false)
end
local hurt, downs = 0, 0
local function audit()
	for i = logFrom + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.player == player or e.player == "all" then
			if e.name == "Hurt" then
				hurt += 1
			elseif e.name == "Kill" and type(e.args[1]) == "table" and e.args[1].victim == player.UserId then
				downs += 1
			end
		end
	end
end

-- Taken to the private practice --------------------------------------------------------------------------------------
local start = Engine.lastClientEvent("Tutorial", player)
check("a new player is told to start", start and start.args[1].kind == "start", start and start.args[1].kind)
local info = start and start.args[1].practice or {}
check("...in a practice arena of their own", info.origin ~= nil and info.slot ~= nil)
local origin = info.origin or Vector3.new(0, 0, 0)
check("...far from the match (2000+ studs)", origin.Magnitude >= 2000, origin)
check("the server has it running", Tutorial:Active(player) and Tutorial:InPractice(player))
check("...out of the match: no team", Teams:Team(player) == nil)
check("...not counted in the match", table.find(Match:Everyone(), player) == nil)
check("...hushed: nothing from the match reaches them", Net.hushed(player))
check("the match's bots don't change for them", #Bots:List() == botsBefore, #Bots:List())
check(
	"the server drew nothing there anyone could see (an invisible floor and walls only)",
	(function()
		local floor = ws:FindFirstChild("PracticeFloor" .. info.slot)
		if not floor then
			return false
		end
		for _, p in floor:GetChildren() do
			if p.Transparency < 1 then
				return false
			end
		end
		return #floor:GetChildren() >= 5
	end)()
)
check(
	"a body in the practice, just behind the line",
	untilTrue(2, function()
		local r = root(player)
		return r ~= nil and Practice.inside(origin, r.Position)
	end)
)
check("the practice world is drawn on their client", Tut.practice() and Tut.practice().world.folder.Parent == ws)
check("...the HUD reads the practice", Store.get("match").practice == true and Store.get("match").phase == "fight")
do
	-- dressed like the real maps (crown molding, columns, panels, lamps, a gate frame), plain white and greys with the
	-- teams' colours (no browns), cheap enough for a phone; the floor and walls where the server's collider has them
	local folder = Tut.practice().world.folder
	local n, molding, columns, lamps, brown = 0, 0, 0, 0, {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			if d.Name == "Molding" then
				molding += 1
			elseif d.Name == "Column" then
				columns += 1
			elseif d.Name == "Lamp" then
				lamps += 1
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
	end
	check(
		"the practice arena has the maps' detail: crown molding, columns, lamps",
		molding >= 8 and columns >= 8 and lamps >= 4,
		`{molding} {columns} {lamps}`
	)
	check("...no browns", #brown == 0, table.concat(brown, ","))
	check("...cheap enough for a phone", n < 1100, n)
	local floor = ws:FindFirstChild("PracticeFloor" .. info.slot)
	local side = floor and floor:FindFirstChild("Side")
	check(
		"...its field inside the server's walls",
		side and math.abs(math.abs(side.Position.Z - origin.Z) - side.Size.Z / 2 - Practice.WIDTH / 2) < 0.01
	)
end
check("...their side and their body", Store.get("me").team == info.team and Store.get("me").alive == true)
local team = info.team
local fwd = Formulas.forward(team)
local t0 = Engine.now()

-- The intro ----------------------------------------------------------------------------------------------------------
check(
	"the intro starts",
	waitFor(2, function()
		return state().intro
	end)
)
run(0.6)
check("the camera is taken over", CamC.takenOver() and cam.CameraType == Enum.CameraType.Scriptable)
check("...letterbox bars", refs.barTop.Size.Y.Scale > 0.05)
check("...the HUD steps away for it", Layout.inCinema() and hud.gui.Enabled == false)
check("THIS IS YOUR TURF", refs.title.Text == "THIS IS YOUR TURF", refs.title.Text)
check("...high over the small arena", cam.CFrame.Position.Y > 25, cam.CFrame.Position.Y)
check("...over the practice, not the match", math.abs(cam.CFrame.Position.Z - origin.Z) < 120, cam.CFrame.Position.Z)
key(Enum.KeyCode.K)
Engine.advance(0.05)
check("K in the intro's first second skips nothing", state().intro and state().running)
local controlAt
check(
	"the intro ends",
	waitFor(9, function()
		return not state().intro and state().history[1] ~= nil
	end)
)
controlAt = Engine.now()
check("...THE LINE and TAKE THEIRS were in it", seen["THE LINE"] ~= nil and seen["TAKE THEIRS"] ~= nil)
check("...about 8 seconds", controlAt - t0 <= 9.5, controlAt - t0)
check("the camera is handed back", not CamC.takenOver() and cam.CameraType == Enum.CameraType.Custom)
check("...locked first person", player.CameraMode == Enum.CameraMode.LockFirstPerson)
check("...the HUD back, kept to the essentials", hud.gui.Enabled and Layout.focused() and hud.invite.Visible == false)
check(
	"...the Shards counter stays up",
	untilTrue(0.5, function()
		return hud.shop.Visible
	end)
)
check(
	"a SKIP button now",
	untilTrue(1, function()
		return refs.skip.Visible
	end)
)

-- The first kill --------------------------------------------------------------------------------------------------------
check("FIRST KILL: a bot walks at you", waitFor(2, stepIs("first_kill")))
run(0.3)
local bot = Tut.practice().bots[1]
check("...one bot", bot ~= nil and #Tut.practice().bots == 1)
check("...the camera turns you to it", CamC.takenOver())
check(
	"HOLD…",
	waitFor(2, function()
		return state().text == "HOLD…"
	end),
	state().text
)
check("...a marker over it", player.PlayerGui:FindFirstChild("TutorialMark") and player.PlayerGui.TutorialMark.Enabled)
run(3) -- (a new player takes it in)
local dist = (bot.torso.Position - root(player).Position).Magnitude
check("...about 15 studs off", dist > 11 and dist < 26, dist)
Bus.Fire:Fire(true)
check(
	"...pulling: LET GO!",
	waitFor(1.5, function()
		return state().text == "LET GO!"
	end),
	state().text
)
local f0 = Tut.practice().front
Bus.Fire:Fire(false)
Engine.advance(0.3)
check("the arrow in slow motion: the camera rides with it", CamC.takenOver() and state().cinema)
check("...nothing went to the match's server (the practice's own arrow)", #Combat:Arrows() == 0)
check(
	"KNOCKOUT!",
	waitFor(3, function()
		return seen["KNOCKOUT!"] ~= nil
	end)
)
check("...the bot's down", not bot.alive and Tut.practice().kills == 1)
local firstKillAt = Engine.now()
check("...within 15 s of having control", firstKillAt - controlAt <= 15, firstKillAt - controlAt)
check("...the line moved toward them", (Tut.practice().front - f0) * fwd == Practice.PUSH, Tut.practice().front)
check("...Shards for it (the server's)", Tutorial:Run(player).kills == 1)

-- DOUBLE KILL! TRIPLE KILL! ---------------------------------------------------------------------------------------------
local shards0 = Data:Get(player).shards
check("two more side by side", waitFor(4, stepIs("multi_kill")))
run(0.4)
check("...two bots", #(function()
	local n = {}
	for _, b in Tut.practice().bots do
		if b.alive then
			table.insert(n, b)
		end
	end
	return n
end)() == 2)
run(4.5)
shoot(1)
check(
	"DOUBLE KILL!",
	waitFor(2, function()
		return seen["DOUBLE KILL!"] ~= nil
	end)
)
run(4)
shoot(0.9)
check(
	"TRIPLE KILL!",
	waitFor(2, function()
		return seen["TRIPLE KILL!"] ~= nil
	end)
)
check(
	"THE LINE MOVED! (the camera follows it)",
	waitFor(4, function()
		return seen["THE LINE MOVED!"] ~= nil
	end)
)
check("...each one paid in Shards", Data:Get(player).shards == shards0 + 2 * Shop.EARN.perKill, Data:Get(player).shards)
local earned = 0
for i = logFrom + 1, #Engine.clientLog do
	local e = Engine.clientLog[i]
	if e.name == "Earned" and e.player == player then
		earned += 1
	end
end
check("...that fly into the counter (Earned)", earned == 3, earned)

-- The near miss ---------------------------------------------------------------------------------------------------------
check("a bot shoots back", waitFor(6, stepIs("near_miss")))
check(
	"...the camera's at once (letterbox), not yours to shoot it with",
	untilTrue(0.4, function()
		return CamC.takenOver() and state().cinema
	end)
)
local nearAt = Engine.now()
local archer = Tut.practice().bots[#Tut.practice().bots]
local kills0 = state().kills
local arrows = ws:FindFirstChild("Arrows")
local function arrowsNow()
	local n = 0
	for _, d in arrows and arrows:GetDescendants() or {} do
		if d:IsA("BasePart") and d.Transparency < 1 then
			n += 1
		end
	end
	return n
end
local before = arrowsNow()
Bus.Fire:Fire(true)
run(0.5)
Bus.Fire:Fire(false)
Engine.advance(0.05)
check(
	"...their shots held: no arrow, the archer stands",
	archer.alive and state().kills == kills0 and arrowsNow() == before,
	arrowsNow()
)
local look = cam.CFrame.LookVector
local toArcher = (archer.head.Position - cam.CFrame.Position).Unit
check("...turned to the archer", look.X * toArcher.X + look.Y * toArcher.Y + look.Z * toArcher.Z > 0.9)
check("...letterbox bars", refs.barTop.Size.Y.Scale > 0.05)
local closest = math.huge
check(
	"THEY SHOOT BACK.",
	waitFor(5, function()
		for _, d in arrows and arrows:GetDescendants() or {} do
			if d:IsA("BasePart") and d.Transparency < 1 then
				closest = math.min(closest, (d.Position - headPos()).Magnitude)
			end
		end
		return seen["THEY SHOOT BACK."] ~= nil
	end)
)
check("...it came close", closest < 6, closest)
check("...and missed (never a hit)", hurt == 0 and downs == 0 and (audit() or true) and hurt == 0 and downs == 0)
check("...BUILD COVER!", seen["BUILD COVER!"] ~= nil)

-- The build ----------------------------------------------------------------------------------------------------------------
check(
	"BUILD TIME: NO SHOOTING",
	waitFor(4, function()
		return seen["BUILD TIME: NO SHOOTING"] ~= nil
	end)
)
check(
	"...the near miss took about 5 s",
	seen["BUILD TIME: NO SHOOTING"] - nearAt <= 5.6,
	seen["BUILD TIME: NO SHOOTING"] - nearAt
)
check("...the build phase on the HUD", Store.phase() == "build")
local buildAt = seen["BUILD TIME: NO SHOOTING"]
check(
	"...the build tray up at once, the wall pulsing in it",
	waitFor(1.5, function()
		return hud.gui.Enabled and hud.tray.Visible and hud.trayButtons.wall:FindFirstChild("TutorialGlow") ~= nil
	end)
)
check("...within 1.5 s of BUILD TIME", Engine.now() - buildAt <= 1.5, Engine.now() - buildAt)
Bus.Fire:Fire(true)
Engine.advance(0.1)
check("...no drawing the bow", not WeaponC.drawing())
Bus.Fire:Fire(false)
check(
	"...a quick look up over the line",
	waitFor(1, function()
		return CamC.takenOver() and cam.CFrame.Position.Y > 12
	end),
	cam.CFrame.Position.Y
)
check("...and back, short", waitFor(3, function()
	return not CamC.takenOver()
end) and Engine.now() - buildAt <= 3.4, Engine.now() - buildAt)
local left0 = Store.get("match").ends - ws:GetServerTimeNow()
check(
	"PICK A WALL",
	waitFor(1, function()
		return state().text == "PICK A WALL"
	end),
	state().text
)
check("...its key", refs.hint.Visible and refs.hint.Text == "press 2", refs.hint.Text)
run(2)
local left1 = Store.get("match").ends - ws:GetServerTimeNow()
check("...the clock waits", math.abs(left1 - left0) < 1, `{left0} {left1}`)
check(
	"...still on PICK A WALL (no blink, nothing repeating)",
	state().step == "pick_wall" and state().text == "PICK A WALL"
)
hud.trayButtons.wall.Activated:Fire()
check(
	"PLACE IT",
	waitFor(2, function()
		return state().text == "PLACE IT"
	end),
	state().text
)
run(0.3)
check("...a glowing spot on the floor, a beam, an arrow to it", count("SpotBeam") == 1 and count("Chevron") > 2)
local slab0 = fx:FindFirstChild("SpotSlab")
local spot0 = slab0 and slab0.Position
local function placeOnSpot()
	local slab = fx:FindFirstChild("SpotSlab")
	local center = slab.Position
	local stand = Vector3.new(center.X - fwd * 12, 3, center.Z)
	Engine.moveTo(player, stand, center)
	run(4) -- (walking there)
	cam.CFrame = CFrame.lookAt(stand + Vector3.new(0, 1.6, 0), center)
	Engine.advance(0.1)
	cam.CFrame = CFrame.lookAt(stand + Vector3.new(0, 1.6, 0), center)
	local ok = BuildC.spot() and BuildC.spot().ok
	Bus.Place:Fire()
	return ok, center
end
local okSpot, wallSpot = placeOnSpot()
check("...the glow stayed put while they walked to it", spot0 and (wallSpot - spot0).Magnitude < 0.01)
check("...the preview sits on it, a valid spot", okSpot, BuildC.spot() and BuildC.spot().why)
check(
	"NICE WALL!",
	waitFor(2, function()
		return seen["NICE WALL!"] ~= nil
	end)
)
local wall
for _, s in Tut.practice().built do
	if s.key == "wall" then
		wall = s
	end
end
check("...a wall in their practice", wall ~= nil and wall.model.Parent ~= nil)
check(
	"...where the preview showed it",
	wall
		and math.abs((wall.min.X + wall.max.X) / 2 - wallSpot.X) < 0.01
		and math.abs((wall.min.Z + wall.max.Z) / 2 - wallSpot.Z) < 0.01
)
check("...facing the line (across the field)", wall and (wall.max.Z - wall.min.Z) > (wall.max.X - wall.min.X))
check(
	"...on their side of it",
	wall and (fwd > 0 and wall.max.X <= Tut.practice().front or wall.min.X >= Tut.practice().front)
)
check(
	"...never in the match's structures",
	(function()
		for _, s in Build:All() do
			if s.owner == player then
				return false
			end
		end
		return true
	end)()
)
check("...the points spent", Store.get("me").budget == Constants.BUILD_BUDGET - 10, Store.get("me").budget)
check(
	"...the lesson, short: PIECES COST POINTS",
	waitFor(2, function()
		return seen["PIECES COST POINTS"] ~= nil
	end)
)
check(
	"one wall is all it asks: then ADD ANOTHER IF YOU LIKE, as the clock runs",
	waitFor(4, function()
		return state().step == "fight_again" and state().text == "ADD ANOTHER IF YOU LIKE"
	end),
	state().text
)
check("...no tower asked for", seen["NOW A TOWER"] == nil and seen["TOWER UP!"] == nil)
check(
	"then the clock runs again",
	waitFor(2, function()
		return Store.get("match").ends - ws:GetServerTimeNow() < 6
	end)
)
check(
	"FIGHT!",
	waitFor(7, function()
		return seen["FIGHT!"] ~= nil and Store.phase() == "fight"
	end)
)
check(
	"...three arrows thud into the wall: WALLS STOP ARROWS!",
	waitFor(5, function()
		return seen["WALLS STOP ARROWS!"] ~= nil
	end)
)

-- The TNT --------------------------------------------------------------------------------------------------------------
check(
	"the TNT: followed in slow motion",
	waitFor(12, function()
		return state().step == "tnt" and fx:FindFirstChild("PracticeTnt") ~= nil and CamC.takenOver()
	end)
)
check(
	"THAT'S TNT.",
	waitFor(6, function()
		return seen["THAT'S TNT."] ~= nil
	end)
)
check("...the wall's gone", wall and wall.model.Parent == nil and Tut.practice().built[wall.id] == nil)
check(
	"YOURS FOREVER IN THE SHOP.",
	waitFor(4, function()
		return seen["YOURS FOREVER IN THE SHOP."] ~= nil
	end)
)
check("...the TNT's slot glows (no popup)", hud.bows.tnt.button:FindFirstChild("TutorialGlow") ~= nil)

-- The push --------------------------------------------------------------------------------------------------------------
check(
	"PUSH THE LINE!",
	waitFor(14, function()
		return state().step == "push" and seen["PUSH THE LINE!"] ~= nil
	end)
)
for i = 1, 3 do
	run(4.5)
	shoot(0.9)
	run(0.5)
	waitFor(3, function()
		return not state().cinema
	end)
	check(`...push knockout {i}`, state().kills == 3 + i, state().kills)
end
check("2 MORE TO WIN!", seen["2 MORE TO WIN!"] ~= nil)
check("...a short kill cam each", state().kills == 6, state().kills)

-- The win ----------------------------------------------------------------------------------------------------------------
check(
	"LAST ONE!",
	waitFor(4, function()
		return state().step == "final_kill"
	end)
)
run(4)
shoot(1)
check(
	"...in slow motion",
	untilTrue(0.5, function()
		return CamC.takenOver()
	end)
)
check(
	"VICTORY!",
	waitFor(14, function()
		return seen["VICTORY!"] ~= nil
	end)
)
check("...the line all the way to their base", state().front == fwd * Practice.EDGE, state().front)
check("...the camera circles them", CamC.takenOver())
check("...fireworks", Fireworks.active())
local reward
check(
	"...a free trail",
	waitFor(9, function()
		local e = Engine.lastClientEvent("Tutorial", player)
		if e and e.args[1].kind == "reward" then
			reward = e.args[1]
		end
		return reward ~= nil and refs.reward.Visible
	end)
)
local p = Data:Get(player)
check("...theirs, and worn", reward and reward.key and p.owned[reward.key] and p.equipped.trail == reward.key)
check(
	"...the Shards counting up (7 knockouts and the win)",
	p.shards == shards0 - Shop.EARN.perKill + 7 * Shop.EARN.perKill + Shop.EARN.win,
	p.shards
)
check(
	"THE REAL GAME STARTS NOW",
	waitFor(20, function()
		return seen["THE REAL GAME STARTS NOW"] ~= nil
	end)
)
local gate = fx:FindFirstChild("PracticeGate")
check("...a gate to walk through", gate ~= nil)
run(3.5)
local veil = gate and gate:FindFirstChild("Veil")
if veil then
	Engine.moveTo(player, Vector3.new(veil.Position.X, 3, veil.Position.Z))
end
check(
	"into the live match",
	waitFor(4, function()
		return not state().running and Teams:Team(player) ~= nil
	end)
)
local total = Engine.now() - t0
local timings = Tutorial:Run(player).timings
check(
	"every step, in order",
	names(state().history)
		== "intro,first_kill,multi_kill,near_miss,build_view,pick_wall,place_wall,fight_again,tnt,push,final_kill,victory,gate",
	names(state().history)
)
check("about 2:30 (and under 3:00)", total >= 120 and total < 180, total)
audit()
check("never knocked out, never hurt", hurt == 0 and downs == 0, `{hurt} {downs}`)
check("never knocked out (the server's count)", (Match:Stats(player).deaths or 0) == 0)

-- After: in the live match --------------------------------------------------------------------------------------------
Engine.advance(1)
check("on a team", Teams:Team(player) ~= nil)
check(
	"...alive, with a body in the arena",
	Combat:Alive(player) and root(player) and math.abs(root(player).Position.Z) < 300
)
check("...counted in the match", table.find(Match:Everyone(), player) ~= nil)
check("...not hushed, not in practice", not Net.hushed(player) and player:GetAttribute("Practice") == nil)
check(
	"...the HUD reads the match again",
	Store.get("match").practice ~= true and Store.get("match").matchId == Match:Snapshot().matchId
)
check("...and their team", Store.get("me").team == Teams:Team(player) and Store.get("me").alive == true)
check("...the practice gone", Tut.practice() == nil and ws:FindFirstChild("PracticeFloor" .. info.slot) == nil)
check("...the HUD whole again", not Layout.focused() and not Layout.inPractice() and not Layout.inCinema())
check(
	"...nothing of the practice's victory left: no fireworks, title, card, letterbox, white",
	untilTrue(1.5, function()
		return not Fireworks.active()
			and not refs.title.Visible
			and not refs.reward.Visible
			and not refs.waitCard.Visible
			and refs.barTop.Size.Y.Scale == 0
			and not refs.fade.Visible
	end)
)
check(
	"...the win's Shards read VICTORY (why = win)",
	(function()
		for i = logFrom + 1, #Engine.clientLog do
			local e = Engine.clientLog[i]
			if e.name == "Earned" and e.player == player and type(e.args[1]) == "table" and e.args[1].why == "win" then
				return true
			end
		end
		return false
	end)()
)
check("...the anti-cheat never struck them", AntiCheat:Strikes(player) == 0)
check("done, saved", p.tutorial.done == true and p.tutorial.skipped == false)
check("...not running on the server", not Tutorial:Active(player))

-- What it measured (the report) -----------------------------------------------------------------------------------------
local line = {}
for _, e in state().history do
	table.insert(line, `{e.name}={e.t}`)
end
print(
	"step timings (client, s from the start): " .. table.concat(line, " ") .. ` | total {math.floor(total * 10) / 10}`
)
local sline = {}
for _, n in
	{
		"intro",
		"first_kill",
		"multi_kill",
		"near_miss",
		"build_view",
		"place_wall",
		"fight_again",
		"tnt",
		"push",
		"final_kill",
		"victory",
		"gate",
	}
do
	table.insert(sline, `{n}={timings[n]}`)
end
print("step timings (server): " .. table.concat(sline, " "))
check("the server timed every step", timings.gate ~= nil and timings.intro ~= nil)

-- Nothing from the match reached them while they were away --------------------------------------------------------------
do
	-- (during the run: kills, banners, toasts, joins happened in the match; check the log between start and leave)
	local leaveAt
	for i = #Engine.clientLog, logFrom + 1, -1 do
		local e = Engine.clientLog[i]
		if e.name == "Tutorial" and e.player == player and e.args[1].kind == "leave" then
			leaveAt = i
			break
		end
	end
	local outside = {}
	local blocked = {
		Kill = true,
		Announce = true,
		Toast = true,
		Alert = true,
		Match = true,
		Me = true,
		InvitePromo = true,
		Gift = true,
		Hook = true,
		Ask = true,
		Results = true,
		Sfx = true,
		Arrow = true,
		Structure = true,
		PartyInvite = true,
	}
	local startAt
	for i = logFrom + 1, leaveAt or #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Tutorial" and e.player == player and e.args[1].kind == "start" then
			startAt = i
		end
		if startAt and i > startAt and (e.player == player or e.player == "all") and blocked[e.name] then
			outside[e.name] = (outside[e.name] or 0) + 1
		end
	end
	local list = {}
	for k, v in outside do
		table.insert(list, `{k}x{v}`)
	end
	check(
		"no outside notifications in the practice (feed, joins, banners, toasts, cards, the match's state)",
		#list == 0,
		table.concat(list, " ")
	)
end

-- A replay, skipped: straight into the live match ------------------------------------------------------------------------
do
	Tut.replay()
	Engine.advance(0.3)
	check("REPLAY: the practice again", state().running and Tutorial:InPractice(player) and Teams:Team(player) == nil)
	check("...no rewards this time", Tutorial:Run(player).pay == false)
	check(
		"...sent from the match: never RESPAWNING in the practice (alive there)",
		not hud.respawn.Visible and Engine.require(tree.client.Store).get("me").alive == true
	)
	key(Enum.KeyCode.Return)
	waitFor(2, function()
		return state().intro
	end)
	run(1.2)
	key(Enum.KeyCode.Return)
	Engine.advance(0.1)
	check("Enter skips the intro (after its first second)", not state().intro and not CamC.takenOver())
	check("...the steps carry on", waitFor(2, stepIs("first_kill")))
	check("...SKIP shows", refs.skip.Visible)
	-- a phone's words, a pad's words
	Device.set("touch")
	run(1.3)
	check("on a phone: HOLD FIRE…", state().text == "HOLD FIRE…", state().text)
	Device.set("gamepad")
	Engine.advance(0.1)
	check("on a pad: HOLD R2…", state().text == "HOLD R2…", state().text)
	Device.set("keyboard")
	Engine.advance(0.1)
	key(Enum.KeyCode.K)
	Engine.advance(0.3)
	check("K skips it: into the live match", not state().running and Teams:Team(player) ~= nil and Combat:Alive(player))
	check("...the practice gone", Tut.practice() == nil and not Net.hushed(player))
	check("...saved as skipped", Data:Get(player).tutorial.skipped == true)
end

-- A replay where they touch nothing: every step does its part, still a win, still under 3:00 ------------------------------
do
	Tut.replay()
	Engine.advance(0.2)
	local i0 = Engine.now()
	check("REPLAY again", state().running)
	local ended = waitFor(185, function()
		return not state().running
	end)
	local idle = Engine.now() - i0
	check("idle: it ends on its own", ended)
	check("...under 3:00", idle < 180, idle)
	check(
		"...with the win (all seven knockouts done for them)",
		names(state().history):find("victory") ~= nil and Tutorial:Run(player).kills == 7
	)
	check("...a wall built for them (then the TNT took it)", seen["NICE WALL!"] ~= nil)
	check("...just the one", #Tutorial:Run(player).built == 1, #Tutorial:Run(player).built)
	check(
		"...and into the match with a team",
		waitFor(2, function()
			return Teams:Team(player) ~= nil and Combat:Alive(player)
		end)
	)
	print(`idle run: {math.floor(idle * 10) / 10} s`)
end

-- Done while the live match is between games: they wait in the practice for its next game ----------------------------------
do
	Tut.replay()
	Engine.advance(0.3)
	check("REPLAY once more", state().running and Tutorial:InPractice(player))
	waitFor(12, stepIs("first_kill"))
	Match:Victory("red")
	Engine.advance(0.1)
	check("(the live match is in its victory)", Match:Phase() == "victory")
	local mark0 = #Engine.clientLog
	Engine.fireServer(player, "Tutorial", "done") -- (their screen's done with it)
	run(0.6)
	check(
		"done during the live victory: still in the practice",
		Tutorial:InPractice(player) and Teams:Team(player) == nil
	)
	check("...still hushed", Net.hushed(player))
	check(
		"...behind the white, NEXT MATCH STARTING…",
		refs.fade.Visible and refs.fade.BackgroundTransparency < 0.05 and refs.waitCard.Visible
	)
	check("...the HUD away, no show going", not hud.gui.Enabled and not state().running and not state().cinema)
	local joined = waitFor(Constants.TUTORIAL_JOIN_WAIT + 1, function()
		return Teams:Team(player) ~= nil
	end)
	check("...into the live match once its next game starts", joined and Match:Phase() == "build", Match:Phase())
	check("...not hushed now", not Net.hushed(player) and not Tutorial:InPractice(player))
	local results = 0
	for i = mark0 + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.player == player and e.name == "Results" then
			results += 1
		end
	end
	check("...none of the live match's victory reached them", results == 0 and not Fireworks.active(), results)
	check(
		"...the white lifts, the card goes, the HUD's back",
		untilTrue(1.5, function()
			return not refs.fade.Visible and not refs.waitCard.Visible and hud.gui.Enabled
		end)
	)
	check("...the match's build phase on the HUD", Store.phase() == "build" and Store.get("match").practice ~= true)
	-- and if the next game never comes, not for long: TUTORIAL_JOIN_WAIT at most
	local wait0 = Constants.TUTORIAL_JOIN_WAIT
	Constants.TUTORIAL_JOIN_WAIT = 2
	Tut.replay()
	Engine.advance(0.3)
	waitFor(12, stepIs("first_kill"))
	Match:_setPhase("loading", 99)
	Engine.fireServer(player, "Tutorial", "done")
	Engine.advance(1)
	check("between games for good: waiting", Tutorial:InPractice(player) and refs.waitCard.Visible)
	Engine.advance(1.5)
	check(
		"...at most TUTORIAL_JOIN_WAIT, then into the match",
		not Tutorial:InPractice(player) and Teams:Team(player) ~= nil
	)
	Constants.TUTORIAL_JOIN_WAIT = wait0
	Match:NewMatch(Match:MapKey())
	Engine.advance(1)
	check("...a body once the match starts", Combat:Alive(player))
end

-- A client that never answers: the server ends it at its time limit ---------------------------------------------------------
do
	Constants.TUTORIAL_MAX_SECONDS = 20
	local mute = Engine.addPlayer("Silent", 602)
	Engine.advance(0.5)
	check("another new player: in a practice of their own", Tutorial:InPractice(mute) and Tutorial:Run(mute) ~= nil)
	-- (and while they're in it, someone else's practice is somewhere else)
	Tut.replay()
	Engine.advance(0.3)
	check("...two at once: two slots", Tutorial:Run(player).slot ~= Tutorial:Run(mute).slot)
	check("...far apart", (Tutorial:Run(player).origin - Tutorial:Run(mute).origin).Magnitude >= 300)
	Tut.skip()
	Engine.advance(0.3)
	-- the watchdog, the AFK room and the bots leave them be
	Constants.AFK_SECONDS = 1
	Afk:_check()
	Constants.AFK_SECONDS = 0
	check("...not sent to the AFK room", not Afk:Away(mute))
	Engine.advance(Constants.STUCK_RESPAWN_SECONDS + 1)
	check("...the watchdog doesn't pull them into the match", Teams:Team(mute) == nil and Tutorial:InPractice(mute))
	Engine.advance(17)
	check("at the limit: into the live match", not Tutorial:InPractice(mute) and Teams:Team(mute) ~= nil)
	check("...alive", Combat:Alive(mute))
	Constants.TUTORIAL_MAX_SECONDS = 180
	-- a screen that never gets going (not a step reported): back to the match well before the limit
	Engine.removePlayer(mute)
	local stuck = Engine.addPlayer("Stuck", 603)
	Engine.advance(0.5)
	check("a practice whose screen never starts it", Tutorial:InPractice(stuck))
	Engine.advance(Constants.TUTORIAL_STALL_SECONDS + 2)
	check(
		"...back in the live match after TUTORIAL_STALL_SECONDS",
		not Tutorial:InPractice(stuck) and Teams:Team(stuck) ~= nil
	)
	Engine.removePlayer(stuck)
	Engine.advance(0.5)
end

-- The step timers: no step can trap you -----------------------------------------------------------------------------------
local worst = 8
for _, st in Tut.STEPS do
	check(`step {st.name} times out`, type(st.timeout) == "number" and st.timeout <= 25, st.timeout)
	worst += st.timeout + (st.grace or 4) + 0.6
end
check("even every step at its very longest stays near the limit (the server ends it at 3:00)", worst < 260, worst)

-- A returning player ------------------------------------------------------------------------------------------------------
local old = Engine.addPlayer("Oldie", 777)
Engine.advance(0.5)
Engine.fireServer(old, "Ready")
Engine.advance(0.5)
local e = Engine.lastClientEvent("Tutorial", old)
check("another new player gets it", e and e.player == old and e.args[1].kind == "start")
Engine.fireServer(old, "Tutorial", "step", "intro")
Engine.fireServer(old, "Tutorial", "done")
Engine.advance(0.2)
check("...done: joined to the match", Teams:Team(old) ~= nil)
Engine.removePlayer(old)
Engine.advance(1)
local mark = #Engine.clientLog
local back = Engine.addPlayer("Oldie", 777)
Engine.advance(0.5)
Engine.fireServer(back, "Ready")
Engine.advance(1)
local again = false
for i = mark + 1, #Engine.clientLog do
	local ev = Engine.clientLog[i]
	if ev.name == "Tutorial" and ev.player == back then
		again = true
	end
end
check("coming back after finishing it: no tutorial", not again and not Tutorial:Active(back))
check("...straight into the match", Teams:Team(back) ~= nil and not Tutorial:InPractice(back))
check("...their save says done", Data:Get(back) and Data:Get(back).tutorial.done == true)
check(
	"the rule: back within 2 minutes, no intro",
	not Tutorial.joinIntro({ meta = { lastSeen = 1000 } }, 1000 + Constants.JOIN_INTRO_REJOIN_SECONDS - 5)
)
check(
	"...2 minutes or more, the intro",
	Tutorial.joinIntro({ meta = { lastSeen = 1000 } }, 1000 + Constants.JOIN_INTRO_REJOIN_SECONDS)
)
check(
	"someone who played before the tutorial existed counts as done",
	not Tutorial.shouldShow({ stats = { matches = 3 }, tutorial = { done = false } })
)
check("...a replay asked for shows it", Tutorial.shouldShow({ stats = { matches = 3 }, tutorial = { replay = true } }))
check(
	"a brand-new player isn't returning",
	not Tutorial.returning({ meta = { sessions = 1 }, stats = {}, tutorial = {} })
)
check(
	"left part-way through the tutorial: returning (no replay of it)",
	Tutorial.returning({ meta = { sessions = 1 }, stats = {}, tutorial = { step = "first_kill" } })
)
check("a second visit: returning", Tutorial.returning({ meta = { sessions = 2 }, stats = {}, tutorial = {} }))
check("a kill or a match: returning", Tutorial.returning({ stats = { kills = 1 }, tutorial = {} }))
Constants.TUTORIAL = false
check("...and the switch turns it off", not Tutorial.shouldShow({ stats = { matches = 0 }, tutorial = {} }))
Constants.TUTORIAL = true

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("TutorialSmoke: " .. failed .. " failures")
end

--[[
The first-minute tutorial: the real server and the real client on the mock engine, one brand-new player alone with
the bot. The intro cinematic plays (the camera taken over, the titles in order, the turf rippling) and hands the
camera back to first person; each guided step shows its words and guide and ends on the real thing (a piece picked
from the tray, a wall built on the server, the fight's camera nudge, aiming, pulling, letting go, a hit, a
knockout that moves the line, the arrow to their base); the tips come once; the first win gets its show; the
server saved it all, in order. The first-match boost (a weaker bot, a longer push) is on for that match only. Then:
a replay from the menu, skipping the intro with a key (not in its first second), waiting while you're down, the
phone's words, skipping the tutorial (saved), and a returning player who doesn't get it again.

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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
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
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)

-- a brand-new player, alone (the bot comes in)
local player = Engine.addPlayer("Newbie", 601)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(0.2)

local Tut = Engine.require(tree.client.Controllers.TutorialController)
local CamC = Engine.require(tree.client.Controllers.CameraController)
local Hud = Engine.require(tree.client.Controllers.HudController)
local BuildC = Engine.require(tree.client.Controllers.BuildController)
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
	for _, d in fx:GetChildren() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end

-- The start ------------------------------------------------------------------------------------------------------
local start = Engine.lastClientEvent("Tutorial", player)
check(
	"a new player is told to start the tutorial",
	start and start.args[1].kind == "start",
	start and start.args[1].kind
)
check("...with the first-match boost", start and start.args[1].boost == true)
check(
	"...the first build phase waits for them (the intro, then their first wall)",
	ws:GetAttribute("Phase") ~= "build"
		or ws:GetAttribute("PhaseEnds") - ws:GetServerTimeNow() >= Constants.TUTORIAL_BUILD_SECONDS - 3,
	ws:GetAttribute("PhaseEnds") - ws:GetServerTimeNow()
)
check("the server has it running", Tutorial:Active(player))
check("a fresh profile has a tutorial field", Data:Get(player).tutorial and Data:Get(player).tutorial.done == false)
local team = Teams:Team(player)
local s = team == "red" and -1 or 1
local fwd = Formulas.forward(team)

-- The intro --------------------------------------------------------------------------------------------------------
check(
	"the intro starts on the first spawn",
	untilTrue(2, function()
		return state().intro
	end)
)
local t0 = Engine.now()
local function at(t)
	Engine.advance(math.max(0, t0 + t - Engine.now()))
end
at(0.5)
check("the camera is taken over (scriptable)", CamC.takenOver() and cam.CameraType == Enum.CameraType.Scriptable)
check("...the HUD steps away for it", Layout.inCinema() and hud.gui.Enabled == false)
check("...letterbox bars come in", refs.barTop.Size.Y.Scale > 0.05, refs.barTop.Size.Y.Scale)
check("RED slams in first", refs.title.Visible and refs.title.Text == "RED", refs.title.Text)
local lit = 0
for _, d in fx:GetChildren() do
	if d.Name == "TurfGlow" and d.Transparency < 0.9 then
		lit += 1
	end
end
check("...and the turf ripples", lit > 0, lit)
check("high over the arena", cam.CFrame.Position.Y > 40, cam.CFrame.Position.Y)
local x1 = cam.CFrame.Position.X
at(0.7)
key(Enum.KeyCode.W)
Engine.advance(0.05)
check("a key in the first second doesn't skip it", state().intro and CamC.takenOver())
at(1.7)
check("then BLUE", refs.title.Text == "BLUE", refs.title.Text)
check("...the camera sweeping across", cam.CFrame.Position.X ~= x1)
at(3.2)
check("then THE LINE", refs.title.Text == "THE LINE", refs.title.Text)
check("...down low over it", cam.CFrame.Position.Y < 30, cam.CFrame.Position.Y)
at(4.4)
check("then THIS IS YOUR TURF", refs.title.Text == "THIS IS YOUR TURF", refs.title.Text)
check("...a skip hint shows", refs.skipHint.Visible and string.find(refs.skipHint.Text, "ENTER") ~= nil)
-- moving, jumping and clicking (what a new player does at once) never skip it
key(Enum.KeyCode.W)
key(Enum.KeyCode.Space)
Engine.game:GetService("UserInputService").InputBegan:Fire({
	KeyCode = Enum.KeyCode.Unknown,
	UserInputType = Enum.UserInputType.MouseButton1,
}, false)
Engine.advance(0.05)
check("...walking, jumping or clicking don't skip it", state().intro and CamC.takenOver())
at(7.0)
check("then TAKE THEIRS", refs.title.Text == "TAKE THEIRS", refs.title.Text)
check(
	"...dropping into your eyes",
	(cam.CFrame.Position - headPos()).Magnitude < 1.5,
	(cam.CFrame.Position - headPos()).Magnitude
)
at(8.0)
check("the intro ends", not state().intro and state().history[1] and state().history[1].name == "intro")
check("the camera is handed back", not CamC.takenOver() and cam.CameraType == Enum.CameraType.Custom)
check("...locked first person again", player.CameraMode == Enum.CameraMode.LockFirstPerson)
check("...on your character", cam.CameraSubject == player.Character:FindFirstChildOfClass("Humanoid"))
check(
	"...from your eyes",
	(cam.CFrame.Position - headPos()).Magnitude < 0.6,
	(cam.CFrame.Position - headPos()).Magnitude
)
check("...looking at the enemy side", cam.CFrame.LookVector.X * fwd > 0.8, cam.CFrame.LookVector.X)
check("...the HUD back, kept to the essentials", hud.gui.Enabled and Layout.focused() and hud.invite.Visible == false)
check("...the bars gone", refs.barTop.Size.Y.Scale < 0.01)
check("...a SKIP button where the invite was", refs.skip.Visible)

-- Build: PICK A WALL → PLACE IT --------------------------------------------------------------------------------------
check(
	"PICK A WALL",
	untilTrue(2, function()
		return state().step == "pick" and state().text == "PICK A WALL"
	end),
	state().text
)
check("...the wall in the tray pulses", hud.trayButtons.wall:FindFirstChild("TutorialGlow") ~= nil)
check("...with its key", refs.hint.Visible and refs.hint.Text == "press 2", refs.hint.Text)
check("...the tray stays, the rest goes", hud.tray.Visible and not hud.feed.Visible and not hud.objective.Visible)
hud.trayButtons.wall.Activated:Fire()
Engine.advance(0.1)
check("picking it ends the step", names(state().history) == "intro,pick", names(state().history))
check(
	"PLACE IT",
	untilTrue(2, function()
		return state().text == "PLACE IT"
	end),
	state().text
)
Engine.advance(0.1)
check("...a glowing spot on the floor, with a beam", count("SpotBeam") == 1 and count("SpotEdge") == 4)
check("...an arrow along the floor to it", count("Chevron") > 4, count("Chevron"))
local slab = fx:FindFirstChild("SpotSlab")
local center = slab.Position
check("...on your side of the line", (center.X - Match:Frontline()) * fwd < 0, center.X)
check("...near the line", math.abs(center.X - Match:Frontline()) < 40, center.X)
-- walk up to it and aim at the glow
local stand = Vector3.new(center.X - fwd * 14, 3, center.Z)
Engine.moveTo(player, stand, center)
cam.CFrame = CFrame.lookAt(stand + Vector3.new(0, 1.6, 0), center)
Engine.advance(0.2)
check(
	"...the preview sits on it, a valid spot",
	BuildC.spot() and BuildC.spot().ok,
	BuildC.spot() and BuildC.spot().why
)
Bus.Place:Fire()
Engine.advance(0.3)
check("building it (on the server) ends the step", names(state().history) == "intro,pick,place", names(state().history))
check("...NICE! slams in", refs.title.Visible and refs.title.Text == "NICE!", refs.title.Text)
check("...with a burst", count("Burst") > 0)
Engine.advance(1.5)
check("...the spot and the arrow go", count("SpotBeam") == 0 and count("Chevron") == 0)
check("then nothing on screen until the fight", state().text == nil)

-- The boost --------------------------------------------------------------------------------------------------------
check("the first-match boost is on", Tutorial:Boosted(player))
check("...the bot goes easy on you", Bots.easyFor(player) == true)
check("...your knockouts push further", Match.bonusCells(player) == Constants.TUTORIAL_PUSH_BONUS)
local bot = Bots:List()[1]
check("...the bot is the only other one", bot ~= nil and #Match:Everyone() == 2)

-- The fight: FIGHT! → AIM HERE → HOLD TO PULL → LET GO! → HIT THEM → KNOCK THEM OUT → PUSH IT ------------------------
Bots.Think = function() end -- (the bot stands still where we put it)
check(
	"the fight comes",
	untilTrue(math.max(Constants.BUILD_SECONDS, Constants.TUTORIAL_BUILD_SECONDS) + 2, function()
		return Match:Phase() == "fight"
	end)
)
Engine.moveTo(player, Vector3.new(Match:Frontline() - fwd * 6, 3, 10), Vector3.new(Match:Frontline() + fwd * 10, 3, 10))
Engine.moveTo(bot, Vector3.new(Match:Frontline() + fwd * 10, 3, 10), Vector3.new(Match:Frontline() - fwd * 6, 3, 10))
cam.CFrame = CFrame.lookAt(headPos(), headPos() + Vector3.new(0, 0, 1)) -- (looking the wrong way)
check(
	"FIGHT! slams in",
	untilTrue(1, function()
		return refs.title.Visible and refs.title.Text == "FIGHT!"
	end),
	refs.title.Text
)
check(
	"...the camera turns you to the enemy",
	untilTrue(1, function()
		return CamC.takenOver()
	end)
)
check(
	"...and lets go",
	untilTrue(2, function()
		return not CamC.takenOver()
	end)
)
local toBot = (root(bot).Position + Vector3.new(0, 1, 0) - cam.CFrame.Position).Unit
check("...now looking right at them", cam.CFrame.LookVector:Dot(toBot) > 0.98, cam.CFrame.LookVector:Dot(toBot))
check(
	"looking at them: AIM HERE is done",
	untilTrue(2, function()
		return names(state().history):find("aim") ~= nil
	end),
	names(state().history)
)
check(
	"HOLD TO PULL",
	untilTrue(2, function()
		return state().text == "HOLD TO PULL"
	end),
	state().text
)
check("...the charge ring shows", refs.ring.Visible)
check(
	"...a marker over the enemy",
	player.PlayerGui:FindFirstChild("TutorialMark") and player.PlayerGui.TutorialMark.Enabled
)
Engine.advance(Constants.SPAWN_PROTECT)
local aim = root(bot).Position + Vector3.new(0, 0.6, 0)
cam.CFrame = CFrame.lookAt(headPos(), aim)
Bus.Fire:Fire(true)
Engine.advance(1.0)
check("pulling far enough ends it", names(state().history):find("draw") ~= nil, names(state().history))
check(
	"LET GO!",
	untilTrue(1.5, function()
		return state().text == "LET GO!"
	end),
	state().text
)
local f0 = Match:Frontline()
cam.CFrame = CFrame.lookAt(headPos(), aim)
Bus.Fire:Fire(false)
Engine.advance(0.1)
check("letting go ends it", names(state().history):find("release") ~= nil, names(state().history))
Engine.advance(0.8)
check("the arrow knocks the bot out", not Combat:Alive(bot), Combat:Health(bot))
local pushed = math.abs(Match:Frontline() - f0)
check(
	"...and the boost pushes the line further",
	pushed == (Formulas.pushCells(2) + Constants.TUTORIAL_PUSH_BONUS) * Constants.CELL,
	pushed
)
check(
	"HIT!",
	untilTrue(2, function()
		return names(state().history):find("hit") ~= nil and refs.title.Text == "HIT!"
	end),
	names(state().history) .. " " .. refs.title.Text
)
check(
	"the knockout: the camera follows the line",
	untilTrue(2, function()
		return names(state().history):find("knockout") ~= nil and CamC.takenOver()
	end),
	names(state().history)
)
check(
	"THE LINE MOVED!",
	untilTrue(1.5, function()
		return refs.title.Text == "THE LINE MOVED!"
	end),
	refs.title.Text
)
check("...the camera out above the field", cam.CFrame.Position.Y > 8, cam.CFrame.Position.Y)
check(
	"...back to first person after",
	untilTrue(3, function()
		return not CamC.takenOver() and cam.CameraType == Enum.CameraType.Custom
	end)
)
check(
	"PUSH IT TO THEIR BASE",
	untilTrue(2, function()
		return state().text == "PUSH IT TO THEIR BASE"
	end),
	state().text
)
check("...an arrow along the turf to their base", count("Chevron") > 4)
check(
	"then the tutorial is done",
	untilTrue(8, function()
		return not state().running
	end)
)
check(
	"every step in order",
	names(state().history) == "intro,pick,place,fight,aim,draw,release,hit,knockout,push",
	names(state().history)
)
check(
	"...and the server heard them in order",
	names(Tutorial:Steps(player)) == "intro,pick,place,fight,aim,draw,release,hit,knockout,push",
	names(Tutorial:Steps(player))
)
check("the HUD comes back", not Layout.focused() and hud.invite.Visible and hud.feed.Visible)
check("...the SKIP button goes", not refs.skip.Visible)
local p = Data:Get(player)
check("done, saved on the profile", p.tutorial.done == true and p.tutorial.skipped == false)
Engine.advance(0.5)
local saved = Engine.dataStores[Constants.PROFILE_STORE]["u_601"]
check("...and in the save", saved and saved.tutorial and saved.tutorial.done == true)
check("...not running on the server any more", not Tutorial:Active(player))

-- The tips, once each -------------------------------------------------------------------------------------------------
check(
	"the bot comes back",
	untilTrue(Constants.RESPAWN_SECONDS + 1, function()
		return Combat:Alive(bot)
	end)
)
Constants.CHARGE_SECONDS = 1e6 -- (the blade tip is only for the CHARGE: the whole fight is it here)
Engine.advance(0.3)
Engine.moveTo(bot, root(player).Position + Vector3.new(fwd * 6, 0, 0), root(player).Position)
Engine.advance(0.2)
check("an enemy close in the CHARGE: 3 = BLADE", refs.tip.Visible and refs.tip.Text == "3 = BLADE", refs.tip.Text)
check("...the blade's slot pulses", hud.bows.blade.button:FindFirstChild("TutorialGlow") ~= nil)
Engine.moveTo(bot, root(player).Position + Vector3.new(fwd * 30, 0, 0), root(player).Position)
Engine.advance(3.5)
Constants.CHARGE_SECONDS = 20
local hum = player.Character:FindFirstChildOfClass("Humanoid")
hum.MoveDirection = Vector3.new(1, 0, 0)
Engine.advance(8.5)
check("walking a while: SHIFT = RUN", refs.tip.Text == "SHIFT = RUN", refs.tip.Text)
hum.MoveDirection = Vector3.new(0, 0, 0)
Engine.moveTo(bot, root(player).Position + Vector3.new(fwd * 6, 0, 0), root(player).Position)
Engine.advance(4)
local tips = 0
for _, e in state().history do
	if e.name:sub(1, 4) == "tip_" then
		tips += 1
	end
end
check("...each tip only once", tips == 2, tips)

-- The first win ------------------------------------------------------------------------------------------------------
Match:Victory(team)
Engine.advance(0.3)
check("the first win: the camera circles you", CamC.takenOver())
check("...YOU WIN!", refs.title.Text == "YOU WIN!", refs.title.Text)
check(
	"...confetti",
	untilTrue(1.5, function()
		return count("Burst") > 0
	end)
)
check(
	"...and back",
	untilTrue(6, function()
		return not CamC.takenOver() and cam.CameraType == Enum.CameraType.Custom
	end)
)
check("the win is told to the server", names(Tutorial:Steps(player)):find("win") ~= nil, names(Tutorial:Steps(player)))
check("only the first match had the boost", not Tutorial:Boosted(player))
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
check("the next match", Match:Phase() == "build", Match:Phase())
check(
	"...no boost: a normal bot, a normal push",
	not Tutorial:Boosted(player) and Bots.easyFor(player) == false and Match.bonusCells(player) == 0
)
local starts = 0
for _, ev in Engine.clientLog do
	if ev.name == "Tutorial" and ev.player == player and ev.args[1].kind == "start" then
		starts += 1
	end
end
check("...and no tutorial", not state().running and starts == 1, starts)

-- Replay, skips, waiting while down, the phone's words ---------------------------------------------------------------
Tut.replay()
Engine.advance(0.2)
check("REPLAY starts it again", state().running and Tutorial:Active(player))
check(
	"...without a boost",
	not Tutorial:Boosted(player) and Engine.lastClientEvent("Tutorial", player).args[1].boost == false
)
check(
	"...the intro again",
	untilTrue(2, function()
		return state().intro
	end)
)
Engine.advance(1.2)
key(Enum.KeyCode.Space)
Engine.advance(0.1)
check("Space doesn't skip it", state().intro)
key(Enum.KeyCode.Return)
Engine.advance(0.1)
check("Enter skips the intro after a second", not state().intro and not CamC.takenOver())
check(
	"...the camera back in first person",
	cam.CameraType == Enum.CameraType.Custom and (cam.CFrame.Position - headPos()).Magnitude < 0.6
)
local last = state().history[#state().history]
check("...told as skipped", last.name == "intro" and last.how == "skip", last.how)
check(
	"the steps carry on",
	untilTrue(2, function()
		return state().step == "pick" and state().text == "PICK A WALL"
	end),
	state().step
)
Device.set("touch")
Engine.advance(0.1)
check("on a phone: TAP A WALL", state().text == "TAP A WALL", state().text)
Device.set("keyboard")
Engine.advance(0.1)
Combat:Kill(player, nil, { kind = "reset" })
Engine.advance(0.5)
check("down: the step waits, nothing on screen", state().step == "pick" and state().text == nil, state().text)
Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
check("back up: it carries on", state().step == "pick" and state().text == "PICK A WALL", state().text)
key(Enum.KeyCode.K)
Engine.advance(0.2)
check("K skips the tutorial", not state().running and not Layout.focused())
check("...the server saves it as skipped", p.tutorial.done == true and p.tutorial.skipped == true)
-- on a phone: dragging never skips the intro; its SKIP button does
Device.set("touch")
Tut.replay()
Engine.advance(0.2)
check(
	"a phone: the intro again",
	untilTrue(3, function()
		return state().intro
	end)
)
UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.Touch }, false)
Engine.advance(1.3)
check("...a drag doesn't skip it", state().intro)
check("...the SKIP button shows", refs.skipCine.Visible)
refs.skipCine.Activated:Fire()
Engine.advance(0.1)
check("...tapping SKIP skips it", not state().intro and not CamC.takenOver())
Tut.skip()
Engine.advance(0.2)
Device.set("keyboard")
check("...the guides go", count("SpotBeam") == 0 and not refs.say.Visible)

-- The join intro (a returning player): the opening alone plays, then the camera is yours again ---------------------------
do
	local NetS = Engine.require(tree.shared.Net)
	NetS.fire(player, "Tutorial", { kind = "intro" })
	local played = untilTrue(3, function()
		return Tut.state().cinema
	end)
	check("the join intro plays the opening cinematic", played)
	check("...not the guided steps", not Tut.state().running)
	local over = untilTrue(12, function()
		return not Tut.state().cinema
	end)
	check("...and ends, the camera back to you", over and ws.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable)
end

-- The step timers: a step can't trap you (it times out, the match never waits) -----------------------------------------
for _, st in Tut.STEPS do
	check(`step {st.name} times out`, type(st.timeout) == "number" and st.timeout <= 60, st.timeout)
end

-- A returning player -----------------------------------------------------------------------------------------------------
local old = Engine.addPlayer("Oldie", 777)
Engine.advance(0.5)
Engine.fireServer(old, "Ready")
Engine.advance(0.5)
local e = Engine.lastClientEvent("Tutorial", old)
check("another new player gets it too", e and e.player == old and e.args[1].kind == "start")
check("...no boost with two people on", not Tutorial:Boosted(old))
Engine.fireServer(old, "Tutorial", "step", "intro")
Engine.fireServer(old, "Tutorial", "done")
Engine.advance(0.2)
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
check("coming back right away after finishing it: no tutorial, no intro", not again and not Tutorial:Active(back))
check("...their save says done", Data:Get(back) and Data:Get(back).tutorial.done == true)
-- back after a while: the opening alone (RED, BLUE, THE LINE, YOUR TURF, into your eyes), not the whole tutorial
Engine.removePlayer(back)
Engine.advance(1)
local savedOld = Engine.dataStores[Constants.PROFILE_STORE]["u_777"]
savedOld.meta.lastSeen -= 600 -- (the mock clock: ten minutes before they left)
mark = #Engine.clientLog
local later = Engine.addPlayer("Oldie", 777)
Engine.advance(0.5)
Engine.fireServer(later, "Ready")
Engine.advance(1)
local kinds, welcome = {}, nil
for i = mark + 1, #Engine.clientLog do
	local ev = Engine.clientLog[i]
	if ev.name == "Tutorial" and ev.player == later then
		table.insert(kinds, ev.args[1].kind)
	elseif ev.name == "Hook" and ev.player == later and ev.args[1].kind == "welcome" then
		welcome = ev.args[1]
	end
end
check(
	"back after 10 minutes: no intro (straight into the fight)",
	table.find(kinds, "intro") == nil,
	table.concat(kinds, ",")
)
check("...not the tutorial", table.find(kinds, "start") == nil and not Tutorial:Active(later))
check("...a WELCOME BACK with their wins and streak", welcome ~= nil and welcome.wins ~= nil and welcome.streak ~= nil)
check("...and a body at once", later.Character ~= nil and later.Character:FindFirstChild("HumanoidRootPart") ~= nil)
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
-- back again: never the tutorial or the intro (they go straight into the fight)
check(
	"a brand-new player isn't returning",
	not Tutorial.returning({ meta = { sessions = 1 }, stats = {}, tutorial = {} })
)
check(
	"left part-way through the tutorial: returning (no replay of it)",
	Tutorial.returning({ meta = { sessions = 1 }, stats = {}, tutorial = { step = "aim" } })
)
check("a second visit: returning", Tutorial.returning({ meta = { sessions = 2 }, stats = {}, tutorial = {} }))
check("a kill or a match: returning", Tutorial.returning({ stats = { kills = 1 }, tutorial = {} }))
do
	-- a replay asked for last time and never finished doesn't carry over to the next visit
	Engine.removePlayer(later)
	Engine.advance(1)
	local saved = Engine.dataStores[Constants.PROFILE_STORE]["u_777"]
	saved.tutorial.replay = true
	saved.meta.lastSeen -= 600
	local mk = #Engine.clientLog
	local rep = Engine.addPlayer("Oldie", 777)
	Engine.advance(0.5)
	Engine.fireServer(rep, "Ready")
	Engine.advance(1)
	local started = false
	for i = mk + 1, #Engine.clientLog do
		local ev = Engine.clientLog[i]
		if ev.name == "Tutorial" and ev.player == rep then
			started = true
		end
	end
	check("a replay left over from last visit doesn't replay it", not started and not Tutorial:Active(rep))
end
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

--[[
Client smoke test: the real server AND the real client together on the mock engine, as a phone-sized touch
screen, so everything the client shows comes from what the server sends. A player joins: the HUD (phase, clock,
the frontline bar, the objective), the build tray and a structure placed through the client's own preview and
PLACE button, the bows (switching, the crossbow's bolts), the fight with the FIRE button (a predicted arrow, a hit
marker, the kill feed, the line moving on the bar), the camera and movement (the slide, the flip on the 4th jump),
and the results screen. Fails on any script error.

  luaurun tests/ClientSmoke.spec.luau
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
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Teams = service("TeamService")
local Combat = service("CombatService")
local Build = service("BuildService")
local Match = service("MatchService")
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)

-- an opponent first (a server-side player), then the local player with the real client
local foe = Engine.addPlayer("Foe", 900)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)
check("teams split one each", Teams:Team(player) ~= nil and Teams:Team(player) ~= Teams:Team(foe))

local gui = player.PlayerGui
local hud = gui:FindFirstChild("Hud")
local Hud = Engine.require(tree.client.Controllers.HudController)
local Weapon = Engine.require(tree.client.Controllers.WeaponController)
local BuildC = Engine.require(tree.client.Controllers.BuildController)
local Move = Engine.require(tree.client.Controllers.MoveController)
local Arrows = Engine.require(tree.client.Controllers.ArrowController)
local Store = Engine.require(tree.client.Store)
local refs = Hud.refs
local team = Teams:Team(player)
local s = team == "red" and -1 or 1

-- The HUD ------------------------------------------------------------------------------------------------------
check("a HUD exists", hud ~= nil)
check(
	"the phase and clock show BUILD",
	refs.phase and refs.phase.Text:find("BUILD") ~= nil,
	refs.phase and refs.phase.Text
)
check("the frontline bar starts half and half", refs.redFill and math.abs(refs.redFill.Size.X.Scale - 0.5) < 0.01)
check(
	"the objective is on screen at once",
	refs.objective and refs.objective.Visible ~= false and refs.objective.Text:find("pushes the line") ~= nil
)
check(
	"you know your team",
	refs.team and refs.team.Text:find(Constants.TEAM_NAME[team]) ~= nil,
	refs.team and refs.team.Text
)
check("first person: the camera is locked", player.CameraMode == Engine.Enum.CameraMode.LockFirstPerson)
check("the build tray is up in the build phase", refs.tray and refs.tray.Visible)
check("...with all seven pieces", refs.trayButtons and refs.trayButtons.tower ~= nil and refs.trayButtons.banner ~= nil)
check("touch: PLACE hides until a piece is picked", refs.touch and not refs.touch.place.Visible)

-- Building through the client's own preview ----------------------------------------------------------------------
Engine.moveTo(player, Vector3.new(s * 40, 3, -28), Vector3.new(s * 50, 3, -28))
local cam = ws.CurrentCamera
cam.CFrame = CFrame.lookAt(Vector3.new(s * 40, 5, -28), Vector3.new(s * 48, 0, -28))
Engine.advance(0.2)
refs.trayButtons.wall.Activated:Fire()
Engine.advance(0.1)
check("tapping a piece picks it", BuildC.picked() == "wall")
check("touch: PLACE and TURN appear", refs.touch.place.Visible and refs.touch.rotate.Visible)
local spot = BuildC.spot()
check("a preview snaps to a cell where you look", spot ~= nil and spot.cx ~= nil, spot and spot.why)
check("...and it's a valid spot", spot and spot.ok, spot and spot.why)
refs.touch.place.Activated:Fire()
Engine.advance(0.3)
local built = 0
for _, st in Build:All() do
	if st.team == team then
		built += 1
	end
end
check("PLACE builds it (on the server)", built == 1, built)
check(
	"the points went down on the HUD",
	refs.budget.Text:find(tostring(Constants.BUILD_BUDGET - 10)) ~= nil,
	refs.budget.Text
)
cam.CFrame = CFrame.lookAt(Vector3.new(s * 40, 5, -28), Vector3.new(-s * 20, 0, -28))
Engine.advance(0.1)
check("aiming across the line turns the preview red", BuildC.spot() and not BuildC.spot().ok)
check("...and says why", refs.buildHint.Text:find("turf") ~= nil, refs.buildHint.Text)

-- The fight -----------------------------------------------------------------------------------------------------
Engine.advance(Constants.BUILD_SECONDS + 0.5)
check("FIGHT on the clock", refs.phase.Text:find("FIGHT") ~= nil, refs.phase.Text)
check("the tray goes away", not refs.tray.Visible)
check("touch: FIRE is up", refs.touch.fire.Visible)
Weapon.equip("crossbow")
Engine.advance(0.2)
check("switching to the crossbow", Store.get("me").weapon == "crossbow" and Combat:Weapon(player) == "crossbow")
check("its bolts show", refs.bows.crossbow.ammo.Text:find("/6") ~= nil, refs.bows.crossbow.ammo.Text)
Weapon.equip("bow")
Engine.advance(0.2)
-- stand facing the foe across the line and shoot with the FIRE button
Engine.advance(Constants.SPAWN_PROTECT)
Engine.moveTo(player, Vector3.new(s * 8, 3, -27), Vector3.new(-s * 8, 3, -27))
Engine.moveTo(foe, Vector3.new(-s * 8, 3, -27), Vector3.new(s * 8, 3, -27))
cam.CFrame = CFrame.lookAt(Vector3.new(s * 8, 4.6, -27), Vector3.new(-s * 8, 3.3, -27))
Engine.advance(0.2)
local Bus = Engine.require(tree.client.UI.Bus)
Bus.Fire:Fire(true)
Engine.advance(1.0)
check("drawing shows the charge", refs.charge.Visible)
Bus.Fire:Fire(false)
check("letting go draws your arrow at once (predicted)", Arrows.count() >= 1)
Engine.advance(0.6)
check("the shot went to the server", Engine.lastClientEvent("Shoot") ~= nil)
check("a full draw kills the foe", not Combat:Alive(foe), Combat:Health(foe))
check("a hit marker (red: a kill)", refs.hit and refs.hitLines[1].BackgroundColor3 == Constants.TEAM_COLOR.red)
check("the kill feed shows it", #refs.feed:GetChildren() >= 2)
check(
	"the bar moved toward them",
	(team == "red" and refs.redFill.Size.X.Scale > 0.5) or (team == "blue" and refs.redFill.Size.X.Scale < 0.5),
	refs.redFill.Size.X.Scale
)

-- Movement -------------------------------------------------------------------------------------------------------
check("slide: a burst forward", Move.slide() and Move.sliding())
check("...on a cooldown", not Move.slide())
local flips = 0
for _ = 1, Constants.FLIP_EVERY do
	if Move.jumped() then
		flips += 1
	end
end
check("the 4th jump flips", flips == 1 and Move.flipping())

-- The results ----------------------------------------------------------------------------------------------------
Match:Victory(team)
Engine.advance(0.5)
check("the results card shows", refs.results ~= nil and refs.results.Parent ~= nil)
check(
	"...naming the winner",
	refs.results and refs.results:FindFirstChildWhichIsA("TextLabel").Text:find("WINS") ~= nil
)
local Fireworks = Engine.require(tree.client.Controllers.FireworksController)
Engine.advance(1)
check("fireworks go off in the winners' colour", Fireworks.active() and Fireworks.count() > 0, Fireworks.count())
check("the top shows the countdown", refs.phase.Text:find("NEXT GAME") ~= nil, refs.phase.Text)
Engine.advance(Constants.FEEDBACK_ASK_DELAY)
local Feedback = Engine.require(tree.client.Controllers.FeedbackController)
local kind, card = Feedback.current()
check("the winner is asked if they like the game", kind == "enjoy" and card ~= nil)
check(
	"...with buttons the mouse can reach in first person",
	card and card:FindFirstChild("Yes") and card.Yes.Modal == true
)
card.Yes.Activated:Fire()
Engine.advance(0.2)
check("YES goes to the server", Engine.lastClientEvent("Feedback") ~= nil and Feedback.current() == nil)
local popups = Hud.popups()
local thanksCard = popups[#popups]
check(
	"...and a THANK YOU card comes up in the popup stack",
	thanksCard and thanksCard.Name == "Thanks" and thanksCard.Head.Text == "THANK YOU!",
	thanksCard and thanksCard.Name
)
check("...showing the trail", thanksCard and thanksCard:FindFirstChild("Preview") ~= nil)
check(
	"...worn straight away (the profile says so)",
	((Store.get("profile") or {}).equipped or {}).trail == "extra_thanks"
)
local twins0 = Arrows.twins()
Arrows.predict(Vector3.new(0, 5, 0), Vector3.new(80, 0, 0), team, 4242)
check("your arrows draw the Thank-You Trail", Arrows.twins() == twins0 + 1)
Engine.advance(Constants.RESULTS_CARD_SECONDS)
check(
	"after the results, a big countdown",
	refs.countdown.Visible and refs.countdown.Text:find("NEXT GAME IN") ~= nil,
	refs.countdown.Text
)
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
check("the next match: BUILD again", refs.phase.Text:find("BUILD") ~= nil, refs.phase.Text)
check("...the results close", refs.results == nil)

-- Invite a friend -------------------------------------------------------------------------------------------------
do
	local before = Engine.invites
	refs.invite.Activated:Fire()
	check("INVITE opens Roblox's invite prompt", Engine.invites == before + 1)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.I, UserInputType = Enum.UserInputType.Keyboard }, false)
	check("...and so does I", Engine.invites == before + 2)
	check("...saying what you both get", refs.invite.Line.Text:find("Buddy Trail") ~= nil)
	local twins0 = Arrows.twins()
	Store.set("profile", { equipped = { trail = "extra_buddy" } })
	Arrows.predict(Vector3.new(0, 5, 0), Vector3.new(80, 0, 0), team, 4343)
	check("the Buddy Trail draws a line each side of the tracer", Arrows.twins() == twins0 + 2)
end

-- Nothing on screen overlaps ------------------------------------------------------------------------------------
-- (the mock draws nothing, so each piece's rectangle is worked out from its Position, Size and AnchorPoint on the
-- smallest canvas the screens get, 1240 x 560, the way Roblox lays them out)
do
	local Theme = Engine.require(tree.client.UI.Theme)
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
		local r = rect(o)
		return r[1] >= 0 and r[2] >= 0 and r[1] + r[3] <= W and r[2] + r[4] <= H
	end
	-- every pair of the pieces showing is apart, and each is on the screen
	local function apart(what, list)
		local bad = {}
		local live = {}
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
	-- inside a card: every text and button within its card, none on another
	local function tidy(what, card)
		local bad = {}
		local kids = {}
		local cr = rect(card)
		for _, k in card:GetChildren() do
			if k:IsA("TextLabel") or k:IsA("TextButton") or (k:IsA("Frame") and k.Name == "Preview") then
				table.insert(kids, k)
				local r = rect(k)
				if r[1] < cr[1] or r[2] < cr[2] or r[1] + r[3] > cr[1] + cr[3] or r[2] + r[4] > cr[2] + cr[4] then
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
	local function fit(what, card)
		local bad = {}
		for _, k in card:GetDescendants() do
			if k:IsA("TextLabel") and k.TextScaled ~= true then
				table.insert(bad, k.Text)
			end
		end
		check(what .. ": its words shrink to fit", #bad == 0, table.concat(bad, " | "))
	end

	-- the touch buttons too (built here on the desktop run, the way a phone gets them)
	UIS.TouchEnabled, UIS.KeyboardEnabled = true, false
	Hud._buildTouch(refs.gui)
	UIS.TouchEnabled, UIS.KeyboardEnabled = false, true
	local t = refs.touch
	local function corners()
		return {
			Top = hud.Top,
			Invite = refs.invite,
			Feed = refs.feed,
			Health = hud.Health,
			Team = refs.team,
			Bows = hud.Bows,
			Fire = t.fire,
			Sprint = t.sprint,
			Slide = hud:FindFirstChild("Slide"),
			Toast = refs.toast,
		}
	end
	for i = 1, 5 do
		Hud.addFeed({ killerName = "SomeoneWithALongName" .. i, victimName = "AnotherLongName", weapon = "bow" })
	end
	Hud.toast("A toast that says something")

	-- the build phase: the tray, its hint, the alert, the objective
	Engine.advance(0.1)
	local L = corners()
	L.Tray = refs.tray
	L.Hint = refs.buildHint
	L.Alert = refs.alert
	L.Objective = refs.objective
	L.Fire, L.Sprint = nil, nil -- (PLACE and TURN take their places, and only once a piece is picked)
	refs.alert.Visible, refs.objective.Visible = true, true
	apart("the build phase", L)

	-- the fight: the bows, the touch buttons, the alert, respawning
	Engine.advance(Constants.BUILD_SECONDS + 0.5)
	Hud.toast("Another toast")
	Engine.advance(0.1)
	L = corners()
	L.Alert = refs.alert
	L.Objective = refs.objective
	L.Respawn = refs.respawn
	refs.alert.Visible, refs.objective.Visible, refs.respawn.Visible = true, true, true
	apart("the fight", L)
	refs.alert.Visible, refs.respawn.Visible = false, false

	-- a win, with everything at once: a full results table, the question, three unlocks (two show, one waits), a
	-- toast
	local rows = {}
	for i = 1, 12 do
		table.insert(rows, {
			userId = i,
			name = "PlayerNumber" .. i,
			team = i % 2 == 0 and "red" or "blue",
			kills = 10,
			deaths = 3,
			assists = 2,
			built = 120,
		})
	end
	rows[11].userId = player.UserId
	Hud.showResults({
		winner = "red",
		rows = rows,
		mvp = 1,
		you = { won = true, qualified = true, step = { win = 12, name = "Long Streak II" } },
		next = { name = "Castle Clash", tagline = "Arches, columns and gate towers; balanced lanes" },
	})
	local ask = Feedback.show("like")
	for i = 1, 3 do
		Hud.showUnlock({
			step = { kind = "trail", key = "trail_" .. i, name = "Long Streak III" },
			wins = 90 + i,
			badge = 10,
		})
	end
	Hud.toast("A toast during the results")
	Engine.advance(0.1)
	local stack, waiting = Hud.popups()
	check("the popups stack, two at a time, the rest waiting", #stack == 2 and #waiting >= 1, `{#stack} {#waiting}`)
	check("the toast steps up out of the question card's way", refs.toast.Position.Y.Offset == -Hud.toastSlot())
	L = corners()
	L.Results = refs.results
	L.Ask = ask
	L.Popup1 = stack[1]
	L.Popup2 = stack[2]
	L.Countdown = refs.countdown
	check(
		"...the results show your row",
		(function()
			for _, k in refs.results:GetChildren() do
				if k:IsA("TextLabel") and k.Text:find("PlayerNumber11") then
					return true
				end
			end
			return false
		end)()
	)
	apart("a win, everything at once", L)
	tidy("the results", refs.results)
	tidy("the like card", ask)
	fit("the like card", ask)
	tidy("an unlock card", stack[1])
	tidy("the invite button", refs.invite)
	fit("the invite button", refs.invite)
	fit("an unlock card", stack[1])
	local enjoy = Feedback.show("enjoy")
	tidy("the question card", enjoy)
	fit("the question card", enjoy)
	Feedback.answer(true) -- (closes it)
	Engine.advance(Constants.RESULTS_CARD_SECONDS + 7)
	refs.countdown.Visible = true
	L = corners()
	L.Countdown = refs.countdown
	L.Popups = Hud.popups()[1]
	apart("the countdown", L)
	check("the waiting popups come up as the first ones go", #Hud.popups() >= 1 or #select(2, Hud.popups()) == 0)
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
	error("ClientSmoke: " .. failed .. " failures")
end

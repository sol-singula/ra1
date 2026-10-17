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
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
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
local Shop = Engine.require(tree.shared.Data.Shop)
local Data = service("PlayerDataService")
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
-- the hotbar: numbered pieces, and the mouse wheel steps through them
local function wheel(z)
	UIS.InputChanged:Fire({ UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, z) }, false)
	Engine.advance(0.2)
end
check(
	"the tray's pieces are numbered 1-7",
	refs.trayButtons.barricade.Key.Num.Text == "1" and refs.trayButtons.banner.Key.Num.Text == "7"
)
check("...the name says just the name", refs.trayButtons.wall.Label.Text == "WALL", refs.trayButtons.wall.Label.Text)
wheel(-1)
check("wheel down: the next piece", BuildC.picked() == "reinforced", BuildC.picked())
wheel(1)
wheel(1)
check("wheel up: the one before", BuildC.picked() == "barricade", BuildC.picked())
wheel(1)
check("...round the end", BuildC.picked() == "banner", BuildC.picked())
BuildC.pick(nil)
wheel(-1)
check("...from nothing, the first", BuildC.picked() == "barricade", BuildC.picked())
do
	-- turning a piece: a right click (the wheel picks pieces) or R
	local r0 = BuildC.rotation()
	Engine.actions.TW_Rotate(
		"TW_Rotate",
		Enum.UserInputState.Begin,
		{ UserInputType = Enum.UserInputType.MouseButton2 }
	)
	check("a right click turns the piece", BuildC.rotation() ~= r0, BuildC.rotation())
	Engine.actions.TW_Rotate("TW_Rotate", Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.R })
	check("...and R turns it back", BuildC.rotation() == r0)
end
BuildC.pick("wall")
Engine.advance(0.1)
check(
	"the picked piece's badge turns white",
	refs.trayButtons.wall.Key.BackgroundColor3 ~= refs.trayButtons.cover.Key.BackgroundColor3
)
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
check(
	"the bows are numbered 1, 2, 3",
	refs.bows.bow.key.Num.Text == "1" and refs.bows.crossbow.key.Num.Text == "2" and refs.bows.heavy.key.Num.Text == "3"
)
check("...the names say just the name", refs.bows.heavy.button.Label.Text == "HEAVY", refs.bows.heavy.button.Label.Text)
check(
	"...the one in hand: its badge white",
	refs.bows.crossbow.key.BackgroundColor3 ~= refs.bows.bow.key.BackgroundColor3
)
wheel(-1)
check("wheel down: the next bow", Store.get("me").weapon == "heavy", Store.get("me").weapon)
wheel(-1)
check("...then the blade", Store.get("me").weapon == "blade", Store.get("me").weapon)
wheel(-1)
check("...round the end", Store.get("me").weapon == "bow", Store.get("me").weapon)
wheel(1)
wheel(1)
check("wheel up: the one before", Store.get("me").weapon == "heavy", Store.get("me").weapon)
-- a menu in the fight: the mouse shows and comes free, the bow doesn't fire
do
	local Layout = Engine.require(tree.client.UI.Layout)
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local BusM = Engine.require(tree.client.UI.Bus)
	check("in play the mouse is hidden", UIS.MouseIconEnabled == false)
	Layout.setPanel(true)
	Engine.advance(0.1)
	check("a menu open: the mouse shows", UIS.MouseIconEnabled == true and CamC.mouseFree())
	check("...and is free to move", UIS.MouseBehavior == Enum.MouseBehavior.Default)
	BusM.Fire:Fire(true)
	Engine.advance(0.3)
	check("...a click doesn't draw the bow", not Weapon.drawing())
	BusM.Fire:Fire(false)
	wheel(-1)
	check("...the wheel doesn't switch bows (it scrolls the menu)", Store.get("me").weapon == "heavy")
	Layout.setPanel(false)
	Engine.advance(0.1)
	check("menu closed: the mouse hides again", UIS.MouseIconEnabled == false and not CamC.mouseFree())
	-- the shop panel for real: once closed its Modal ✕ lets go, and the cursor stays hidden even if Roblox shows it
	local PanelC = Engine.require(tree.client.Controllers.PanelController)
	PanelC.open()
	Engine.advance(0.5)
	local x = PanelC.refs and PanelC.refs.close
	check("the shop open: the mouse shows", UIS.MouseIconEnabled == true and (x == nil or x.Modal == true))
	PanelC.close()
	Engine.advance(0.5)
	check(
		"...closed: its Modal button lets go",
		x == nil or (x.Modal == false and CamC.parked()[x] == true),
		x and `{x.Modal} {CamC.parked()[x]} {x.Visible} {x.Parent and x.Parent.Name} {x:IsA("GuiButton")}`
	)
	UIS.MouseIconEnabled = true
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	Engine.advance(0.1)
	check(
		"...and the cursor is put away again",
		UIS.MouseIconEnabled == false and UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
	)
	PanelC.open()
	Engine.advance(0.5)
	check("...open again: Modal again", x == nil or x.Modal == true)
	PanelC.close()
	Engine.advance(0.5)
end
-- graphics: more on a PC that can take it, nothing added on a phone
do
	local Gfx = Engine.require(tree.client.Controllers.GraphicsController)
	local Dev = Engine.require(tree.client.UI.Device)
	local L = Engine.game:GetService("Lighting")
	local was = Dev.kind()
	Dev.set("touch")
	check("a phone: nothing added", Gfx.tier() == "low" and not L:FindFirstChild("TW_Bloom"), Gfx.tier())
	Dev.set("keyboard")
	check("a PC: the high tier", Gfx.tier() == "high", Gfx.tier())
	check(
		"...bloom, sun rays, far haze",
		L:FindFirstChild("TW_Bloom") and L:FindFirstChild("TW_Rays") and L:FindFirstChild("TW_Depth")
	)
	check("...the bloom only catches the neon", L.TW_Bloom.Threshold >= 1.8)
	Gfx.apply("mid")
	check(
		"mid: a lighter bloom, no rays",
		L:FindFirstChild("TW_Bloom") and not L:FindFirstChild("TW_Rays") and not L:FindFirstChild("TW_Depth")
	)
	Gfx.apply("low")
	check("low: nothing added", not L:FindFirstChild("TW_Bloom") and not L:FindFirstChild("TW_Rays"))
	Gfx.apply(nil)
	check("...back to the device's own", Gfx.tier() == "high")
	Dev.set(was)
end
-- banners: a server message slides in under the top bar, one at a time
do
	local NotifyC = Engine.require(tree.client.Controllers.NotifyController)
	NotifyC.show({ text = "Red team wins!", kind = "win" })
	NotifyC.show({ text = "Ava is MVP!", kind = "status" })
	Engine.advance(0.1)
	local cur = NotifyC.current()
	check("a banner shows", cur and cur.text == "Red team wins!" and NotifyC.refs.strip.Visible == true)
	check("...the next waits its turn", NotifyC.queued() == 1)
	Engine.advance(4)
	check("...then the next one", NotifyC.current() and NotifyC.current().text == "Ava is MVP!")
	Engine.advance(4)
end
-- the blade: 4 picks it, a click slashes
do
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Four, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.3)
	check("4 picks the blade", Store.get("me").weapon == "blade" and Combat:Weapon(player) == "blade")
	check("...numbered 4 on the hotbar", refs.bows.blade and refs.bows.blade.key.Num.Text == "4")
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check("...a blade in your hand", vm and vm:FindFirstChild("Edge") ~= nil and vm:FindFirstChild("String") == nil)
	Engine.advance(0.5)
	local edge = vm and vm:FindFirstChild("Edge")
	local rest = edge and edge.Position
	local BusB = Engine.require(tree.client.UI.Bus)
	local before = Engine.lastClientEvent("Swing")
	BusB.Fire:Fire(true)
	Engine.advance(0.1)
	BusB.Fire:Fire(false)
	check("a click slashes (the server is asked)", Engine.lastClientEvent("Swing") ~= before)
	check("...and the blade sweeps across", edge and (edge.Position - rest).Magnitude > 0.1)
	local SwingC = Engine.require(tree.client.Controllers.SwingController)
	check("...with a streak through the air", SwingC.streaks() > 0)
	check("someone else's slash shows on their body", SwingC.slashOf(foe.Character, Vector3.new(1, 0, 0)))
	check("...no charge ring for a blade", not refs.charge.Visible)
	Engine.advance(0.6)
end
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
do
	local cam = Engine.game:GetService("Workspace").CurrentCamera
	local CamC = Engine.require(tree.client.Controllers.CameraController)
	local fov0 = CamC.targetFov()
	local still = true
	for _ = 1, 8 do
		local before = cam.CFrame.LookVector
		Engine.advance(0.05)
		if (cam.CFrame.LookVector - before).Magnitude > 0.001 or CamC.targetFov() ~= fov0 then
			still = false
		end
	end
	check("...and the camera stays exactly as it is (no spin, dip or zoom)", still)
end

-- Crouch ---------------------------------------------------------------------------------------------------------
Engine.advance(2)
local hum0 = player.Character:FindFirstChildOfClass("Humanoid")
local hip0 = hum0.HipHeight
Move.setSprint(false)
Engine.advance(0.7)
Move.setCrouch(true)
Engine.advance(0.7)
check("crouch: lower", hum0.HipHeight < hip0 - 0.5, `{hum0.HipHeight} vs {hip0}`)
check("...and slower", hum0.WalkSpeed == Constants.CROUCH_SPEED, hum0.WalkSpeed)
check("...and the server knows (it lowers you for everyone)", service("MoveService"):State(player).crouch == true)
Move.setCrouch(false)
Engine.advance(0.7)
check("standing back up", math.abs(hum0.HipHeight - hip0) < 0.01 and hum0.WalkSpeed == Constants.WALK_SPEED)

-- The bow in your hands -------------------------------------------------------------------------------------------
do
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	check(
		"the viewmodel has arms and hands",
		vm and vm:FindFirstChild("ArmL") and vm:FindFirstChild("ArmR") and vm:FindFirstChild("HandR") ~= nil
	)
	check("...and a string in two halves", vm and vm:FindFirstChild("String") and vm:FindFirstChild("StringL") ~= nil)
	local function rel(name)
		local p = ws.CurrentCamera:FindFirstChild("Viewmodel"):FindFirstChild(name)
		return ws.CurrentCamera.CFrame:PointToObjectSpace(p.Position)
	end
	Engine.advance(1)
	Weapon.equip("heavy")
	Engine.advance(0.03)
	local early = rel("Grip")
	Engine.advance(0.8)
	local late = rel("Grip")
	check("equipping: the bow comes up from below", early.Y < late.Y - 0.2, `{early.Y} -> {late.Y}`)
	local restHand = rel("HandR")
	local restGrip = rel("Grip")
	Bus.Fire:Fire(true)
	Engine.advance(1.6)
	local drawnHand = rel("HandR")
	local drawnGrip = rel("Grip")
	check(
		"drawing: your hand pulls the string back",
		(drawnHand - drawnGrip).Magnitude > (restHand - restGrip).Magnitude + 0.6,
		`{(restHand - restGrip).Magnitude} -> {(drawnHand - drawnGrip).Magnitude}`
	)
	check("...and the bow comes toward the middle", math.abs(drawnGrip.X) < math.abs(restGrip.X) - 0.2)
	Bus.Fire:Fire(false)
	Engine.advance(0.02)
	check("release: the bow kicks", Weapon.anim().kick.v ~= 0 or Weapon.anim().kick.p ~= 0)
	Engine.advance(1)
	Weapon.equip("crossbow")
	Engine.advance(0.5)
	Weapon.reload()
	check("the crossbow tips down to reload", Weapon.anim().reloadAt ~= nil)
	Engine.advance(2.5)
	check("...and comes back up", Weapon.anim().reloadAt == nil)
	Weapon.equip("bow")
	Engine.advance(0.3)
	local held = foe.Character and foe.Character:FindFirstChild("HeldBow")
	local mine = player.Character:FindFirstChild("HeldBow")
	check("everyone holds a bow others can see", held ~= nil or mine ~= nil)
	local hidden = mine and mine:FindFirstChildWhichIsA("BasePart").LocalTransparencyModifier == 1
	check("...yours hidden from you (you see your arms)", hidden == true)
end

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

-- Parties ------------------------------------------------------------------------------------------------------
local PartyC = Engine.require(tree.client.Controllers.PartyController)
local pref = PartyC.refs
do
	local PartySvc = service("PartyService")
	local Layout = Engine.require(tree.client.UI.Layout)
	check("a PARTY button beside INVITE", pref.button ~= nil and pref.button.Parent ~= nil)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.P, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("P opens the party panel", PartyC.isOpen() and Layout.panel())
	check("...with the mouse free (a Modal button)", pref.close.Modal == true)
	local inv = pref.players:FindFirstChild("Invite_" .. foe.UserId)
	check("...listing the players here with INVITE", inv ~= nil)
	if inv then
		inv.Activated:Fire()
	end
	Engine.advance(0.3)
	PartySvc:Answer(foe, true)
	Engine.advance(0.3)
	check("INVITE, and a YES: a party, you lead", PartySvc:Of(player) ~= nil and PartySvc:Of(player).leader == player)
	check("...both on your team", Teams:Team(foe) == Teams:Team(player))
	check(
		"...the panel shows KICK and the server buttons",
		pref.members:FindFirstChild("Kick2") ~= nil and pref.newServer.Visible
	)
	check("...the corner list shows you both", pref.list.Visible and pref.list:FindFirstChild("Member2") ~= nil)
	check("...the PARTY button says so", pref.buttonLine.Text:find("2/4") ~= nil, pref.buttonLine.Text)
	local mark = PartyC.marks()[foe.UserId]
	check(
		"...a 👥 over Foe, drawn only on your screen",
		mark and mark.Parent == player.PlayerGui and mark.Adornee ~= nil
	)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.P, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("P closes it", not PartyC.isOpen() and not Layout.panel())
	-- an invite card: N says no, and it goes
	Engine.remote("PartyInvite").OnClientEvent:Fire({ from = 900, name = "Foe", kind = "friend", seconds = 20 })
	local card = PartyC.card()
	check("an invite card", card ~= nil and card.Title.Text:find("PARTY UP WITH FOE") ~= nil)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.N, UserInputType = Enum.UserInputType.Keyboard }, false)
	check("...N answers it", PartyC.card() == nil)
	Engine.remote("PartyInvite").OnClientEvent:Fire({ from = 900, name = "Foe", kind = "invite", seconds = 20 })
	Engine.advance(21)
	check("...it goes by itself after 20 s", PartyC.card() == nil)
	PartySvc:Leave(foe)
	Engine.advance(0.3)
	check("the party ends: the list and the marker go", not pref.list.Visible and next(PartyC.marks()) == nil)
	-- (a full party of four in the corner list, for the layout checks below)
	Engine.remote("PartyState").OnClientEvent:Fire({
		id = "x",
		leader = player.UserId,
		max = 4,
		members = {
			{ userId = player.UserId, name = "Ava" },
			{ userId = 7, name = "SomeoneWithALongName" },
			{ userId = 8, name = "Ben" },
			{ userId = 9, name = "Cy" },
		},
	})
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

	-- first the desktop layout (the touch buttons are hidden); the touch layout is checked after
	local Device = Engine.require(tree.client.UI.Device)
	Device.set("keyboard")
	Engine.advance(0.05)
	local t = refs.touch
	local function corners()
		return {
			Top = hud.Top,
			Invite = refs.invite,
			ShopButton = refs.shop,
			PartyButton = pref.button,
			PartyList = pref.list,
			Feed = refs.feed,
			Health = hud.Health,
			Team = refs.team,
			Bows = hud.Bows,
			Fire = t.fire,
			Jump = t.jump,
			Crouch = t.crouch,
			Sprint = t.sprint,
			Slide = t.slide,
			Reload = t.reload,
			Place = t.place,
			Rotate = t.rotate,
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
	L.PartyAsk = PartyC.showInvite({ from = 900, name = "SomeoneWithALongName", kind = "invite", seconds = 20 })
	refs.alert.Visible, refs.objective.Visible, refs.respawn.Visible = true, true, true
	apart("the fight", L)
	tidy("the party card", L.PartyAsk)
	fit("the party card", L.PartyAsk)
	PartyC.answer(false)
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

	-- The touch layout: a phone, every button showing, in each phase ------------------------------------------------
	Device.set("touch")
	local realMatch = Store.get("match")
	local realMe = Store.get("me")
	local function phaseAs(ph)
		Store.merge("match", { phase = ph })
		Engine.advance(0.05)
	end
	Store.merge("me", { weapon = "crossbow", alive = false })
	phaseAs("fight")
	check(
		"on a phone: FIRE, JUMP, CROUCH, RUN, SLIDE and RELOAD show",
		t.fire.Visible
			and t.jump.Visible
			and t.crouch.Visible
			and t.sprint.Visible
			and t.slide.Visible
			and t.reload.Visible
	)
	check(
		"...the bows move to the bottom middle, health to the top left",
		refs.bowsFrame.AnchorPoint.X == 0.5 and refs.health.Position.Y.Scale == 0
	)
	check("...and one popup at a time", select(1, Hud.popups()) and true)
	refs.alert.Visible, refs.objective.Visible, refs.respawn.Visible = true, true, true
	Hud.toast("A toast on a phone")
	for i = 1, 3 do
		Hud.showUnlock({ step = { kind = "trail", key = "trail_" .. i, name = "Long Streak" }, wins = i })
	end
	Engine.advance(0.05)
	L = corners()
	L.Alert, L.Objective, L.Respawn, L.Popups = refs.alert, refs.objective, refs.respawn, Hud.popups()[1]
	L.PartyAsk = PartyC.showInvite({ from = 900, name = "Foe", kind = "friend", seconds = 20 })
	apart("a phone in the fight", L)
	PartyC.answer(false)
	check("...one popup showing, the rest waiting", #Hud.popups() == 1, #Hud.popups())
	refs.alert.Visible, refs.respawn.Visible = false, false
	phaseAs("build")
	BuildC.pick("wall")
	Engine.advance(0.05)
	check("on a phone building: PLACE and TURN", t.place.Visible and t.rotate.Visible and not t.fire.Visible)
	L = corners()
	L.Tray, L.Hint, L.Popups = refs.tray, refs.buildHint, Hud.popups()[1]
	apart("a phone building", L)
	BuildC.pick(nil)
	phaseAs("victory")
	Hud.showResults({ winner = "red", rows = rows, mvp = 1, you = { won = true } })
	local askT = Feedback.show("enjoy")
	Engine.advance(0.05)
	L = corners()
	L.Results, L.Ask, L.Popups = refs.results, askT, Hud.popups()[1]
	apart("a phone at the win", L)
	Feedback.answer(true)
	-- a jump on the phone's own button
	local jumped = false
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Jump = false
		phaseAs("fight")
		t.jump.Activated:Fire()
		jumped = hum.Jump == true
	end
	check("JUMP jumps", jumped)
	Store.set("match", realMatch)
	Store.set("me", realMe)
	Device.set("keyboard")
	Engine.advance(0.05)
	check("back on a keyboard: the touch buttons go", not t.fire.Visible and not t.jump.Visible)

	-- The panel: the shop, the pass, the locker, the goals --------------------------------------------------------
	local Panel = Engine.require(tree.client.Controllers.PanelController)
	local Layout = Engine.require(tree.client.UI.Layout)
	local Economy = service("EconomyService")
	local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
	local pr = Panel.refs
	tidy("the shop button", refs.shop)
	fit("the shop button", refs.shop)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.B, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("B opens the panel", Panel.isOpen() and pr.panel.Visible == true and Layout.panel())
	check("...with the mouse free (a Modal button)", pr.close.Modal == true)
	-- inside a container: its pieces apart and inside it (a scrolling body: inside across, any height)
	local function walk(what, container, depth)
		local kids = {}
		for _, k in container:GetChildren() do
			if (k:IsA("GuiObject")) and k.Visible ~= false then
				table.insert(kids, k)
			end
		end
		local bad = {}
		local cr = rect(container)
		local scroll = container:IsA("ScrollingFrame")
		for i, a in kids do
			local r = rect(a)
			local inside = r[1] >= cr[1] - 0.5 and r[1] + r[3] <= cr[1] + cr[3] + 0.5
			if not scroll then
				inside = inside and r[2] >= cr[2] - 0.5 and r[2] + r[4] <= cr[2] + cr[4] + 0.5
			else
				inside = inside and r[2] >= cr[2] - 0.5
			end
			if not inside then
				table.insert(bad, (a.Name or "?") .. " sticks out of " .. container.Name)
			end
			for j = i + 1, #kids do
				if hits(a, kids[j]) then
					table.insert(bad, a.Name .. " x " .. kids[j].Name)
				end
			end
		end
		for _, k in kids do
			-- (a preview's bars and a progress bar's fill sit on each other on purpose)
			if
				k.Name ~= "Preview"
				and k.Name ~= "Progress"
				and k.Name ~= "VipBar"
				and k.Name ~= "Bar"
				and depth < 6
			then
				for _, b in walk(what, k, depth + 1) do
					table.insert(bad, b)
				end
			end
		end
		return bad
	end
	local function panelTidy(tab)
		local bad = walk(tab, pr.panel, 0)
		check(`the panel's {tab} tab: nothing overlaps, nothing sticks out`, #bad == 0, table.concat(bad, ", "))
		local unfit = {}
		for _, d in pr.panel:GetDescendants() do
			if d:IsA("TextLabel") and d.TextScaled ~= true then
				table.insert(unfit, d.Text)
			end
		end
		check(`the panel's {tab} tab: its words shrink to fit`, #unfit == 0, table.concat(unfit, " | "))
	end
	Economy:Add(player, 5000)
	Engine.advance(0.7)
	for _, tab in { "shop", "pass", "locker", "goals" } do
		Panel.open(tab)
		Engine.advance(0.1)
		check(`the {tab} tab builds`, #pr.body:GetChildren() > 3, #pr.body:GetChildren())
		panelTidy(tab)
	end
	-- the panel among the HUD's pieces: the corners stay clear of it, the middle steps aside
	Panel.open("shop")
	Hud.showResults({ winner = "red", rows = rows, mvp = 1, you = { won = true } })
	Hud.toast("A toast while the panel is up")
	Engine.advance(0.1)
	L = corners()
	L.Panel = pr.panel
	L.Popups = Hud.popups()[1]
	apart("the panel open", L)
	check("...the results card steps aside", refs.results == nil or refs.results.Visible == false)
	check("...toasts go to the panel's own line", pr.status.Text:find("A toast while") ~= nil, pr.status.Text)
	-- the party panel: one panel at a time, its pieces apart, among the HUD's
	PartyC.open()
	Engine.advance(0.1)
	check("the party panel closes the shop panel", PartyC.isOpen() and not Panel.isOpen() and Layout.panel())
	L = corners()
	L.PartyPanel = pref.panel
	apart("the party panel open", L)
	local pbad = walk("party", pref.panel, 0)
	check("the party panel: nothing overlaps, nothing sticks out", #pbad == 0, table.concat(pbad, ", "))
	for _, box in { pref.members, pref.players } do
		pbad = walk("party", box, 0)
		check(`the party panel's {box.Name}: nothing overlaps`, #pbad == 0, table.concat(pbad, ", "))
	end
	PartyC.close()
	check("...closed, the mouse goes back", not Layout.panel())
	Panel.open("shop")
	-- buying from the shop tab
	local p = Data:Get(player)
	local item1 = pr.body:FindFirstChild("Item1")
	local key1 = Shop.daily(Shop.dayOf(service("ShopService").now()))[1]
	local shardsBefore = p.shards
	item1.Buy.Activated:Fire()
	Engine.advance(0.6)
	check("BUY in the shop: bought and worn", p.owned[key1] == true and p.shards < shardsBefore)
	check("...the card says so", pr.body.Item1.Buy.Label.Text == "WORN", pr.body.Item1.Buy.Label.Text)
	-- the locker: wear something else
	Panel.open("locker")
	Engine.advance(0.1)
	pr.body.Item1.Activated:Fire() -- (NONE: wear no trail)
	Engine.advance(0.6)
	check("the locker: wear nothing", p.equipped.trail == nil, p.equipped.trail)
	local lockedShown = false
	for _, c in pr.body:GetChildren() do
		if c:FindFirstChild("Line") and c.Line.Text:find("🔒") then
			lockedShown = true
		end
	end
	check("...what you don't have says how to get it", lockedShown)
	UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.B, UserInputType = Enum.UserInputType.Keyboard }, false)
	Engine.advance(0.1)
	check("B closes it", not Panel.isOpen() and not Layout.panel())
	check("...and the results come back", refs.results == nil or refs.results.Visible == true)
	-- looks in play
	local Looks = Engine.require(tree.client.Controllers.LooksController)
	check(
		"a kill effect plays where someone fell",
		Looks.play("shop_ink", Vector3.new(0, 3, 0), "red") and Looks.count() > 0
	)
	p.owned.shop_hologram = true
	Engine.advance(0.6)
	Engine.fireServer(player, "Settings", "equip", { kind = "skin", key = "vip_skin" })
	Engine.advance(0.6)
	check("a skin you haven't earned isn't worn", p.equipped.skin ~= "vip_skin")
	Engine.fireServer(player, "Settings", "equip", { kind = "skin", key = "shop_hologram" })
	Engine.advance(0.6)
	local vm = ws.CurrentCamera:FindFirstChild("Viewmodel")
	local grip = vm and vm:FindFirstChild("Grip")
	check(
		"your bow wears its finish",
		grip and grip.Material == Enum.Material.ForceField,
		grip and tostring(grip.Material)
	)
	_ = Cosmetics
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

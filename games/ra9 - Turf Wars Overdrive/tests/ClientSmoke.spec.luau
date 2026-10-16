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
Engine.advance(Constants.RESULTS_CARD_SECONDS)
check(
	"after the results, a big countdown",
	refs.countdown.Visible and refs.countdown.Text:find("NEXT GAME IN") ~= nil,
	refs.countdown.Text
)
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
check("the next match: BUILD again", refs.phase.Text:find("BUILD") ~= nil, refs.phase.Text)
check("...the results close", refs.results == nil)

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

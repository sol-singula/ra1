--[[
The missions after the tutorial (HookService, HookController) and the gamepad controls (GamepadController), with the
real server and the real client on the mock engine: a brand-new player gets mission 1 at once, each mission is
counted from the real event and pays at once, the chain ends with HOOK COMPLETE and a cosmetic worn; who's eligible;
and on a gamepad: shoulders switch the weapon (the piece in the build phase), R2 draws and shoots, Select opens the
shop with its first button picked, B closes it.

  luaurun tests/HookSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
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
Constants.AFK_SECONDS = 0
Constants.MIN_SIDE = 1
Constants.TUTORIAL = false -- (straight to the missions: TutorialSmoke has the tutorial, and its hand-over)
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local HookS = service("HookService")
local Combat = service("CombatService")
local Build = service("BuildService")
local Match = service("MatchService")
local Data = service("PlayerDataService")
local Teams = service("TeamService")
local Hook = Engine.require(tree.shared.Data.Hook)

local foe = Engine.addPlayer("Foe", 910)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Newbie", 511)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)

local HookC = Engine.require(tree.client.Controllers.HookController)
local Pad = Engine.require(tree.client.Controllers.GamepadController)
local Weapon = Engine.require(tree.client.Controllers.WeaponController)
local BuildC = Engine.require(tree.client.Controllers.BuildController)
local Panel = Engine.require(tree.client.Controllers.PanelController)
local Store = Engine.require(tree.client.Store)

-- The missions ----------------------------------------------------------------------------------------------------
check("a brand-new player is eligible", HookS:Eligible(Data:Get(player)))
check("...the missions run for them", HookS:Running(player))
local st = HookC.state()
check(
	"mission 1 is on screen: GET 2 KNOCKOUTS",
	st.mission and st.mission.key == "ko" and st.card ~= nil,
	st.mission and st.mission.key
)
check("...with the enemy arrow as its guide", st.marker == "enemy")
check("...and its reward", st.card and st.card:FindFirstChild("Reward") and st.card.Reward.Text:find("25") ~= nil)

local shards0 = Data:Get(player).shards or 0
Combat.Killed:Fire(foe, player, { kind = "test" })
Engine.advance(0.3)
check(
	"a knockout counts: 1/2",
	HookS:State(player).have == 1 and HookC.state().mission.have == 1,
	HookS:State(player).have
)
check("...the card shows it", HookC.state().card and HookC.state().card.Count.Text == "1/2")
Combat.Killed:Fire(foe, player, { kind = "test" })
Engine.advance(0.3)
check("2 knockouts: done, and paid at once", (Data:Get(player).shards or 0) >= shards0 + 25, Data:Get(player).shards)
check("...the next one: BUILD A WALL", HookS:State(player).i == 2)
Engine.advance(1.5)
check("...and its card comes up", HookC.state().mission.key == "build" and HookC.state().card ~= nil)
-- someone else's wall doesn't count
Build.Built:Fire(foe, {})
check("someone else's wall doesn't count", HookS:State(player).i == 2 and HookS:State(player).have == 0)
Build.Built:Fire(player, {})
Engine.advance(0.3)
check("a wall of theirs: next, PUSH THE LINE", HookS:State(player).i == 3)
for _ = 1, 3 do
	Match.Pushed:Fire(0, Teams:Team(player), player, foe)
end
Engine.advance(0.3)
-- the TNT mission: their free try is there (a new player), so it waits for a throw
check("3 pushes: next, THROW THE TNT", HookS:State(player).i == 4, HookS:State(player).i)
Combat.Shot:Fire(player, "bow")
check("a bow shot isn't a TNT throw", HookS:State(player).i == 4)
Combat.Shot:Fire(player, "tnt")
Engine.advance(0.3)
check("a TNT throw: next, WIN A MATCH", HookS:State(player).i == 5)
HookS:Count(player, "win")
Engine.advance(0.5)
local p = Data:Get(player)
check("the last one: the hook is done (saved)", p.hook.done == true and not HookS:Running(player))
check(
	"...the reward cosmetic is theirs and worn",
	p.owned and p.owned[Hook.FINAL.cosmetic] == true and p.equipped.trail == Hook.FINAL.cosmetic,
	p.equipped.trail
)
check("...all the Shards paid", (p.shards or 0) >= shards0 + 25 + 25 + 40 + 40 + 75 + Hook.FINAL.shards, p.shards)
check(
	"...HOOK COMPLETE on screen with SEE THE SHOP",
	HookC.refs.complete ~= nil and HookC.refs.complete:FindFirstChild("Shop") ~= nil
)
check("...no mission card left", HookC.state().card == nil and HookC.state().marker == nil)
check("done once: never again", not HookS:Eligible(p))

-- who gets it
check("a 5th session: no missions", not HookS:Eligible({ meta = { sessions = 5 }, stats = { matches = 2 } }))
check("lots of matches: no missions", not HookS:Eligible({ meta = { sessions = 1 }, stats = { matches = 40 } }))
check("a 2nd session, few matches: yes", HookS:Eligible({ meta = { sessions = 2 }, stats = { matches = 3 } }))
-- a TNT mission with no TNT to throw is passed by
do
	local q = Engine.addPlayer("NoTnt", 512)
	Engine.advance(0.5)
	Engine.fireServer(q, "Ready")
	Engine.advance(0.5)
	local qh = HookS:State(q)
	check("another new player starts at mission 1", qh and qh.i == 1)
	qh.i, qh.have = 3, 2
	q:SetAttribute("TntTry", false)
	q:SetAttribute("OwnsTNT", nil)
	HookS:Count(q, "push")
	check("...the TNT mission with no TNT to throw is passed by", HookS:State(q).i == 5, HookS:State(q).i)
	Engine.removePlayer(q)
end

-- The welcome back -------------------------------------------------------------------------------------------------
HookC.handle({ kind = "welcome", wins = 12, streak = 3, kills = 80 })
Engine.advance(0.2)
check(
	"WELCOME BACK shows their wins and streak",
	HookC.refs.welcome ~= nil and HookC.refs.welcome.Line.Text:find("12") ~= nil
)
Engine.advance(5)
check("...and goes by itself", HookC.refs.welcome == nil)

-- The gamepad ----------------------------------------------------------------------------------------------------
Engine.advance(12.5) -- (the HOOK COMPLETE card closes itself: while it's up the mouse is free and shots wait)
Engine.setInput(Enum.UserInputType.Gamepad1)
local K = Enum.KeyCode
if Store.phase() ~= "build" then
	Match:SkipTo("build")
	Engine.advance(0.5)
end
check("(the build phase)", Store.phase() == "build", Store.phase())
Pad.press(K.ButtonR1)
check("build phase: R1 picks a piece", BuildC.picked() ~= nil)
local first = BuildC.picked()
Pad.press(K.ButtonR1)
check("...R1 again: the next one", BuildC.picked() ~= nil and BuildC.picked() ~= first)
Pad.press(K.DPadDown)
check("...D-pad down puts it away", BuildC.picked() == nil)
Engine.advance(0.5)
check("the gamepad hint shows over the hotbar", Pad.hint().Visible == true)
Match:SkipTo("fight")
Engine.advance(1)
check("(the fight)", Store.phase() == "fight", Store.phase())
-- (the TNT theirs, so R1 has somewhere to go: their free try went on the TNT mission)
player:SetAttribute("OwnsTNT", true)
Engine.advance(0.1)
local before = (Store.get("me") or {}).weapon
Pad.press(K.ButtonR1)
Engine.advance(0.2)
local after = (Store.get("me") or {}).weapon
check("fight: R1 switches the weapon", after ~= nil and after ~= before, `{before} -> {after}`)
Pad.press(K.ButtonL1)
Engine.advance(0.2)
check("...L1 back", (Store.get("me") or {}).weapon == before, (Store.get("me") or {}).weapon)
-- R2 draws and lets go (the same action as the mouse)
local mark = #Engine.clientLog
Engine.actions.TW_Fire("TW_Fire", Enum.UserInputState.Begin)
Engine.advance(0.8)
Engine.actions.TW_Fire("TW_Fire", Enum.UserInputState.End)
Engine.advance(0.2)
local shot = false
for i = mark + 1, #Engine.clientLog do
	if Engine.clientLog[i].name == "Shoot" then
		shot = true
	end
end
check("R2 held and let go: a shot", shot)
-- Select opens the shop, its first button picked; B closes it
Pad.press(K.ButtonSelect)
check("Select opens the shop", Panel.isOpen() and Panel.tab() == "shop")
local sel = Engine.game:GetService("GuiService").SelectedObject
check("...with a button picked for the D-pad", sel ~= nil and sel:IsA("GuiButton"), sel and sel.Name)
Pad.press(K.ButtonB)
check("B closes it", not Panel.isOpen() and Engine.game:GetService("GuiService").SelectedObject == nil)
Weapon.cycle(0)

print(`\nHookSmoke: {passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("HookSmoke: " .. failed .. " failures")
end

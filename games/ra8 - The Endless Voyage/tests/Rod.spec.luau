--[[
The rod in your hand, on an R15 avatar the way Roblox really spawns one (tests/mock/Engine.luau): every step the
Animator writes each joint's Transform, the platform puts every Motor6D's C0 back to its rig attachments' value,
then PreSimulation, then the joints move. Run once with Motor6D joints and once with the AnimationConstraints of
Roblox's Avatar Joint Upgrade:

  luaurun tests/Rod.spec.luau motor6d
  luaurun tests/Rod.spec.luau constraint

It measures where the rod's tip really is against the hand: up and out in front when you hold it, back over your
shoulder at the top of the cast, out level over the water at the release, low over the water while you fish, up
while you reel; a line hanging from the tip; and still up and out with no arm animation at all.
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2

local kind = ARGS[1] or "motor6d"
Engine.avatarJoints = kind

local passed, failed = 0, 0
local function check(name, cond, detail)
	name = `[{kind}] {name}`
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
Engine.advance(0.1)
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2.5)
local Menu = Engine.require(tree.client.Controllers.MenuController)
Menu.close()
local Bus = Engine.require(tree.client.UI.Bus)
local Fx = Engine.require(tree.client.Controllers.FxController)
local Inventory = Engine.require(tree.server.Services.InventoryService)

local c = player.Character
local jointClass = kind == "constraint" and "AnimationConstraint" or "Motor6D"
local found = 0
for _, d in c:GetDescendants() do
	if d:IsA(jointClass) then
		found += 1
	end
end
check(`the avatar is joined with {jointClass}s`, found >= 15, found)
check("the rod is in hand", Inventory:Selected(player) ~= nil and c:FindFirstChild("Held") ~= nil)

-- the camera behind her, as Roblox's follows
local function camera()
	local r = c.HumanoidRootPart
	ws.CurrentCamera.CFrame = CFrame.lookAt(r.Position - r.CFrame.LookVector * 12 + Vector3.new(0, 5, 0), r.Position)
end

-- Where the rod's tip is against the hand: { up, ahead (along where she faces), elevation in degrees }.
local function rod()
	local held = c:FindFirstChild("Held")
	local hand = c:FindFirstChild("RightHand")
	local tip = held and held:FindFirstChild("Tip")
	if not (hand and tip) then
		return nil
	end
	local a = tip.CFrame:PointToWorldSpace(Vector3.new(tip.Size.X / 2, 0, 0))
	local b = tip.CFrame:PointToWorldSpace(Vector3.new(-tip.Size.X / 2, 0, 0))
	local far = (a - hand.Position).Magnitude > (b - hand.Position).Magnitude and a or b
	local d = far - hand.Position
	local look = c.HumanoidRootPart.CFrame.LookVector
	local flat = Vector3.new(d.X, 0, d.Z)
	return {
		up = d.Y,
		ahead = flat:Dot(Vector3.new(look.X, 0, look.Z).Unit),
		elevation = math.deg(math.atan2(d.Y, flat.Magnitude)),
		tip = far,
	}
end
local function describe(r)
	return r and string.format("elevation %.0f°, %.1f ahead, %.1f up", r.elevation, r.ahead, r.up) or "no rod"
end

camera()
Engine.advance(0.5)
camera()
local r = rod()
check(
	"holding it: the rod points up and out in front",
	r and r.elevation > 45 and r.elevation < 82 and r.ahead > 1,
	describe(r)
)

-- a line hangs from the tip with the bobber on it
local idle = Fx.idleLines[c]
check(
	"a line hangs straight down from the rod's tip, the bobber on it",
	idle ~= nil
		and r ~= nil
		and idle.bob.Position.Y < r.tip.Y - 1
		and (Vector3.new(idle.bob.Position.X, 0, idle.bob.Position.Z) - Vector3.new(r.tip.X, 0, r.tip.Z)).Magnitude
			< 0.5,
	idle and r and (idle.bob.Position - r.tip)
)

-- the cast
Bus.Swing:Fire("fishing_rod", "cast")
Engine.advance(0.2)
r = rod()
check("the cast winds up: the rod goes back over the shoulder", r and r.ahead < -2 and r.up > 1, describe(r))
Engine.advance(0.2)
r = rod()
check("then whips out level over the water", r and r.ahead > 3 and r.elevation < 25 and r.elevation > -20, describe(r))
Engine.advance(0.4)
r = rod()
check("and comes back up to the hold", r and r.elevation > 45 and r.ahead > 1, describe(r))

-- fishing, then reeling (the server's Pose attribute)
c:SetAttribute("Pose", "fishing")
Engine.advance(0.6)
r = rod()
check(
	"fishing: the rod held out low over the water",
	r and r.elevation > 10 and r.elevation < 42 and r.ahead > 3,
	describe(r)
)
c:SetAttribute("Pose", "reel")
Engine.advance(0.6)
r = rod()
check("reeling: the rod pulled up", r and r.elevation > 60, describe(r))
c:SetAttribute("Pose", nil)
Engine.advance(0.6)

-- no arm animation at all (joints it can't find): the grip alone still points the rod up and out
for _, d in c:GetDescendants() do
	if d:IsA(jointClass) then
		d.Name = "Hidden" .. d.Name
	end
end
Engine.advance(2.5)
camera()
Engine.advance(0.3)
r = rod()
check(
	"with no arm animation at all, the rod still points up and out",
	r and r.elevation > 25 and r.ahead > 1,
	describe(r)
)

print(`{passed} passed, {failed} failed`)
if failed > 0 then
	error(`Rod ({kind}): {failed} failures`)
end

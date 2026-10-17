--[[
The kill cam and the kill effects (for checking the look against the store art): the real server and client boot on
the mock engine on Dust Devil, a foe's arrow knocks you out, and the frames catch the kill cam (the cut to the
killer, the arrow's flight, the freeze on impact, the card), an arrow's tracer in flight, and a body shattering.

  luaurun tools/gameplay/killcam.luau <outDir>
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false
Engine.require(tree.shared.Constants).BUILD_SECONDS = 600 -- (time to stage it all)
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled, UIS.KeyboardEnabled = false, true
Engine.runScript(tree.server.Main)
Engine.advance(0.3)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Match = service("MatchService")
local Teams = service("TeamService")
local Formulas = Engine.require(tree.shared.Formulas)
local foe = Engine.addPlayer("Rook", 901)
Engine.advance(0.3)
Engine.fireServer(foe, "Ready")
local player = Engine.addPlayer("Ava", 501)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
Match:NewMatch("dust")
Engine.advance(1)
Engine.require(tree.client.Controllers.GraphicsController).apply("high")
local KillCam = Engine.require(tree.client.Controllers.KillCamController)
local KillFx = Engine.require(tree.client.Controllers.KillFxController)
local team = Teams:Team(player)
local s = team == "red" and -1 or 1
-- somewhere open: the two of them in plain sight of each other, and of where the kill cam's camera goes
local Combat = service("CombatService")
local UPV = V3.new(0, 1, 0)
-- (every visible part of the map, not only the solid boxes the server knows: the pillars and the props block a
-- camera too)
local props = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and (d.Transparency or 0) < 0.9 then
		local c = d.Parent
		while c and c ~= ws and not c:FindFirstChildOfClass("Humanoid") do
			c = c.Parent
		end
		if c == ws then
			local half = d.Size * 0.5
			table.insert(props, { cf = d.CFrame, half = half, r = half.Magnitude })
		end
	end
end
local function free(a, b)
	if Combat:Blocked(a, b) then
		return false
	end
	local seg = b - a
	local len2 = seg:Dot(seg)
	for _, p in props do
		local at = p.cf.Position
		local k = len2 > 0 and math.clamp((at - a):Dot(seg) / len2, 0, 1) or 0
		if (a + seg * k - at).Magnitude <= p.r then
			local la, lb = p.cf:PointToObjectSpace(a), p.cf:PointToObjectSpace(b)
			if Formulas.segmentBox(la, lb, -p.half, p.half) then
				return false
			end
		end
	end
	return true
end
local function standable(p)
	return free(p + V3.new(0, 0.2, 0), p + V3.new(0, 4, 0))
end
-- a camera at eye sees what's round target: the middle and a few points about it
local function view(target, eye)
	local right = (target - eye):Cross(UPV)
	right = right.Magnitude > 0.01 and right.Unit or V3.new(1, 0, 0)
	for _, off in { V3.new(0, 0, 0), right * 2.5, right * -2.5, UPV * 2, UPV * -1.2 } do
		if not free(eye, target + off) then
			return false
		end
	end
	return true
end
local me, them
local zs = { 0 }
for k = 4, 36, 4 do
	table.insert(zs, k)
	table.insert(zs, -k)
end
for _, mz in zs do
	for _, mx in { 10, 14, 18, 6, 22, 26 } do
		for _, gap in { 32, 38, 28 } do
			for _, dz in { 0, 4, -4, 8, -8 } do
				if not me then
					local a = V3.new(s * mx, 3, mz)
					local b = V3.new(s * (mx - gap), 3, mz + dz)
					local dir = V3.new(a.X - b.X, 0, a.Z - b.Z).Unit
					local side = dir:Cross(UPV).Unit
					local headA, headB = a + V3.new(0, 1.5, 0), b + V3.new(0, 1.5, 0)
					local orbit = CF.fromAxisAngle(UPV, math.rad(35)) * (side * 9.5 - dir * 3.5).Unit * 11
					local ok = standable(a)
						and standable(b)
						and free(headB, headA)
						and view(headB, headB + dir * 8.5 + side * 3.6 + UPV * 1.2) -- (the cut to the killer)
						and view(a, a + side * 8.5 - dir * 7 + UPV * 2.2) -- (the flight's last stretch)
						and view(a, a + side * 9.5 - dir * 3.5 + UPV * 2) -- (the freeze)
						and view(a, a + orbit + UPV * 3.5) -- (the card's drift)
						and view(b + UPV, b + UPV + (a - b).Unit * 14 + UPV) -- (the shatter's frame)
						and view(b + (a - b) * 0.62 + UPV * 1.5, b + (a - b) * 0.62 + side * 7.5 + UPV * 3 - dir * 4) -- (the tracer's)
					if ok then
						me, them = a, b
					end
				end
			end
		end
	end
end
assert(me, "nowhere open enough on this map")
print("staged", me, them, #props)
Engine.moveTo(player, me, them)
Engine.moveTo(foe, them, me)
Engine.advance(0.3)

local cam = ws.CurrentCamera
local shots = {}
local function shot(name, camera)
	-- (the world-only frames: no HUD)
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and camera ~= nil then
			g.Enabled = false
		end
	end
	local cf = cam.CFrame
	camera = camera
		or {
			pos = { cf.Position.X, cf.Position.Y, cf.Position.Z },
			target = {
				cf.Position.X + cf.LookVector.X * 10,
				cf.Position.Y + cf.LookVector.Y * 10,
				cf.Position.Z + cf.LookVector.Z * 10,
			},
			up = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z },
			fov = cam.FieldOfView or 70,
		}
	local snap = Capture.snapshot(Engine, camera)
	snap.title = name
	snap.cinematic = false
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end
local function hideOwn(on)
	for _, d in player.Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = on and 1 or 0
		end
	end
end
local function step(seconds)
	Engine.advance(seconds, 1 / 60)
end

-- An arrow's tracer in flight, from the side
hideOwn(true)
local from = them + V3.new(0, 1.5, 0)
-- (a near miss: it flies on past you)
local target = me + V3.new(0, 1, 0) + V3.new(me.X - them.X, 0, me.Z - them.Z).Unit:Cross(V3.new(0, 1, 0)) * 4
local speed = 230
local aim = (target - from).Unit
Engine.remote("Arrow"):FireAllClients({
	id = 5001,
	by = foe.UserId,
	team = Teams:Team(foe),
	weapon = "bow",
	origin = from,
	velocity = aim * speed,
	at = ws:GetServerTimeNow(),
})
local half = (target - from).Magnitude * 0.62 / speed
step(half)
local mid = Formulas.arrowAt(from, aim * speed, half)
local flat = V3.new(me.X - them.X, 0, me.Z - them.Z).Unit
local side = flat:Cross(V3.new(0, 1, 0)).Unit
local eye = mid + side * 7.5 + V3.new(0, 1.5, 0) - flat * 4
local aimAt = mid + flat * 1.5
shot("trail", { pos = { eye.X, eye.Y, eye.Z }, target = { aimAt.X, aimAt.Y, aimAt.Z }, fov = 50 })
step(1)

-- A body shattering: the foe goes down where you can see it
local froot = foe.Character.HumanoidRootPart.Position
local look = froot + V3.new(0, 1, 0)
local seat = me + V3.new(0, 1.6, 0)
KillFx.shatter({
	victim = foe.UserId,
	victimTeam = Teams:Team(foe),
	kind = "arrow",
	pos = froot,
	cam = { velocity = (froot - seat).Unit * 200 },
})
step(0.14)
local near = look + (seat - look).Unit * 14 + V3.new(0, 1, 0)
shot("shatter", { pos = { near.X, near.Y, near.Z }, target = { look.X, look.Y + 0.5, look.Z }, fov = 55 })
step(2.5)
for _, d in foe.Character:GetDescendants() do
	if d:IsA("BasePart") then
		d.LocalTransparencyModifier = 0
	end
end
hideOwn(false)

-- The kill cam: the foe's arrow knocks you out
local origin = from
local hit = me + V3.new(0, 0.6, 0)
local dist = (hit - origin).Magnitude
local vel = (hit - origin).Unit * speed
	+ V3.new(0, Engine.require(tree.shared.Constants).GRAVITY * (dist / speed) / 2, 0)
local t = dist / speed
local k = {
	killer = foe.UserId,
	killerName = foe.DisplayName or foe.Name,
	killerTeam = Teams:Team(foe),
	victim = player.UserId,
	victimName = player.Name,
	victimTeam = team,
	weapon = "bow",
	head = false,
	kind = "arrow",
	pos = me,
	killerPos = them,
	dist = math.floor(dist + 0.5),
	cam = { origin = origin, velocity = vel, t = t, impact = Formulas.arrowAt(origin, vel, t) },
}
Engine.remote("Kill"):FireAllClients(k)
step(0.32)
shot("killcam_1_killer")
local dur = math.clamp(t * 3.5, 0.8, 1.15)
step(0.13 + dur * 0.45)
shot("killcam_2_flight")
step(dur * 0.42)
shot("killcam_3_closing")
step(dur * 0.13 + 0.06)
shot("killcam_4_impact")
step(0.5)
shot("killcam_5_card")
step(0.3)
shot("killcam_6_card")
print("stage", KillCam.stage())

local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)

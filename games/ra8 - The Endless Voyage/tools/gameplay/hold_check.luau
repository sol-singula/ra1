--[[
What the rod really looks like in a survivor's hand: the real server and the real client on the mock engine, with
an R15 avatar joined the way Roblox spawns one (tests/mock/Engine.luau: the Animator's Transforms, the platform's C0
resets), the real AnimController posing it and the real FxController hanging the line, captured at a few moments
(holding it, the top of the cast, the release, fishing, reeling) and drawn with three.js. Also the guide's arrow.

  tools/luaurun/target/release/luaurun tools/gameplay/hold_check.luau <outDir> [motor6d|constraint]
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules> --textures <pbr dir>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local outDir = ARGS[1] or "hold"
Engine.avatarJoints = ARGS[2] or "motor6d"

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1280, 720)
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
Engine.require(tree.client.Controllers.MenuController).close()
local Bus = Engine.require(tree.client.UI.Bus)
local c = player.Character

-- from the side and a little in front, a few studs away
local function view()
	local r = c.HumanoidRootPart
	local look = r.CFrame.LookVector
	local right = r.CFrame.RightVector
	local at = r.Position + Vector3.new(0, 1.5, 0) + look * 1.5
	return at + right * 9 + look * 3 + Vector3.new(0, 2.5, 0), at
end

local shots = {}
local function shot(name)
	local camPos, target = view()
	ws.CurrentCamera.CFrame = CFrame.lookAt(camPos, target)
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { target.X, target.Y, target.Z },
		fov = 50,
	})
	snap.title = name
	snap.cinematic = false
	snap.hideGui = true
	snap.viewport = { w = 1280, h = 720, dpr = 1 }
	snap.focus = { target.X, target.Y, target.Z }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
	print("shot", name)
end

local function settle(seconds)
	local camPos, target = view()
	ws.CurrentCamera.CFrame = CFrame.lookAt(camPos, target)
	Engine.advance(seconds)
end

settle(0.6)
shot("hold_1_holding")
-- the guide's arrow over the piece it wants, from behind the player (the usual camera) and from the side
do
	local arrow = ws:FindFirstChild("Guide") and ws.Guide:FindFirstChild("GuideArrow")
	if arrow then
		local tip = arrow:GetPivot().Position
		local r = c.HumanoidRootPart
		local from = r.Position
			- (Vector3.new(tip.X, r.Position.Y, tip.Z) - r.Position).Unit * 10
			+ Vector3.new(0, 6, 0)
		for i, camPos in { from, tip + Vector3.new(14, 4, 6) } do
			ws.CurrentCamera.CFrame = CFrame.lookAt(camPos, tip)
			Engine.advance(0.05)
			tip = arrow:GetPivot().Position
			local snap = Capture.snapshot(Engine, {
				pos = { camPos.X, camPos.Y, camPos.Z },
				target = { tip.X, tip.Y + 1.5, tip.Z },
				fov = 50,
			})
			local name = "arrow_" .. i
			snap.title = name
			snap.cinematic = false
			snap.hideGui = true
			snap.viewport = { w = 1280, h = 720, dpr = 1 }
			snap.focus = { tip.X, tip.Y, tip.Z }
			Capture.save(Engine, snap, outDir, name)
			table.insert(shots, name)
			print("shot", name)
		end
	end
end
Bus.Swing:Fire("fishing_rod", "cast")
settle(0.22)
shot("hold_2_windup")
settle(0.18)
shot("hold_3_release")
settle(0.5)
c:SetAttribute("Pose", "fishing")
settle(0.6)
shot("hold_4_fishing")
c:SetAttribute("Pose", "reel")
settle(0.6)
shot("hold_5_reel")
c:SetAttribute("Pose", nil)
settle(0.6)

local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))

--[[
Moving (master plan §4): running, and a jump button on phones.

  run    hold Shift (PC), click the left stick (a gamepad: running until you stop), or tap RUN (any screen: on until
         you tap it again). Faster feet (Constants.SPRINT_BONUS), the camera widening a touch while you're moving
         (Constants.SPRINT_FOV; not with screen shake off or reduced motion), sand kicked up on an island, and
         AnimController leaning you into it. Your own speed changes the moment you press; the server is told
         (PlayerService:Sprint) and sets the same speed, and the character's "Sprint" attribute says what the server
         has, so a message the rate limit dropped is sent again.
  jump   phones: a JUMP button above ACT, held to keep jumping like Roblox's own (which sits under ACT, so it's
         hidden)
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local FxController = require(script.Parent.FxController)
local InputController = require(script.Parent.InputController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local MoveController = { Name = "MoveController", Order = 21 }

local player = Players.LocalPlayer
local C = Theme.Color
local BASE_FOV = 70 -- (Roblox's camera)
local SAND = { Color3.fromRGB(226, 205, 160), Color3.fromRGB(240, 224, 186) }
local refs = {}
local shift = false -- Shift is down
local toggled = false -- RUN tapped on, or the left stick clicked
local byStick = false -- (the stick's run ends when you stop)
local stillFor = 0
local sent, sentAt = false, -10 -- (what the server was last told)
local jumpInput -- the touch holding JUMP
local puffAt = 0

local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid"), c
end

-- Running: asked for (Shift, the stick, RUN) and alive.
function MoveController.running()
	return (shift or toggled) and Store.alive()
end

local function moving(hum)
	local dir = hum and hum.MoveDirection
	return dir ~= nil and dir.Magnitude > 0.1
end

-- The speed the server will set too (PlayerService:MaxSpeed).
local function speedFor(running)
	local me = Store.get("me")
	local swift = me and me.buffs and me.buffs.swift ~= nil
	return Constants.WALK_SPEED + (swift and 4 or 0) + (running and Constants.SPRINT_BONUS or 0)
end

-- Tell the server, and again while what it has (the "Sprint" attribute) isn't what we want.
local function sync()
	local want = MoveController.running() == true
	local _, c = humanoid()
	local has = c ~= nil and c:GetAttribute("Sprint") == true
	if want == has and want == sent then
		return
	end
	if want ~= sent or os.clock() - sentAt > 0.6 then
		sent, sentAt = want, os.clock()
		pcall(Net.send, "Sprint", want)
	end
end

local function apply()
	local hum = humanoid()
	if hum and Store.alive() then
		hum.WalkSpeed = speedFor(MoveController.running())
	end
	sync()
end

-- RUN on or off (the button, the stick).
function MoveController.setRun(on, stick)
	toggled = on == true
	byStick = toggled and stick == true
	stillFor = 0
	apply()
end

function MoveController.jump()
	local hum = humanoid()
	if hum and hum.Health > 0 and Store.alive() then
		hum.Jump = true
	end
end

local function button(name, icon, color, size)
	local b, _, label = InputController.roundButton(name, icon, color, size, UDim2.new(1, -72, 1, -180), nil, nil)
	b.Visible = false
	return b, label
end

local function buildButtons()
	local run, runLabel = button("Run", "🏃", C.slate, 64)
	runLabel.Text = "RUN"
	refs.run, refs.runLabel = run, runLabel
	Theme.keyHint(run, "Shift", "L3")
	run.Activated:Connect(function()
		MoveController.setRun(not toggled)
		Bus.Tap:Fire(toggled and "run_on" or "run_off")
	end)
	local jump, jumpLabel = button("Jump", "⬆️", C.sky, 84)
	jumpLabel.Text = "JUMP"
	refs.jump = jump
	jump.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			jumpInput = input
			MoveController.jump()
		end
	end)
end

-- Phones: JUMP right above ACT, RUN beside it over REMOVE; elsewhere RUN above ACT (HudController keeps its unlock
-- cards above them). Roblox's own jump button (under ACT) hidden.
local function layout()
	local alive = Store.alive()
	local touch = UserInputService.TouchEnabled == true and UserInputService.KeyboardEnabled ~= true
	refs.jump.Visible = alive and touch
	refs.run.Visible = alive
	refs.run.Position = touch and UDim2.new(1, -160, 1, -184) or UDim2.new(1, -72, 1, -172)
	refs.jump.Position = UDim2.new(1, -62, 1, -168)
	local on = MoveController.running()
	refs.run.BackgroundColor3 = on and C.good or C.slate
	refs.runLabel.Text = on and "RUNNING" or "RUN"
	if touch then
		local playerGui = player:FindFirstChild("PlayerGui")
		local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
		local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
		local theirs = frame and frame:FindFirstChild("JumpButton")
		if theirs and theirs.Visible then
			theirs.Visible = false
		end
	end
end

local function step(dt)
	local hum, c = humanoid()
	-- the stick's run ends once you stop
	if byStick and toggled then
		stillFor = moving(hum) and 0 or stillFor + dt
		if stillFor > 0.4 then
			MoveController.setRun(false)
		end
	end
	if jumpInput then
		MoveController.jump()
	end
	local running = MoveController.running() and moving(hum)
	-- the camera widens a touch while you run
	local cam = workspace.CurrentCamera
	local fov = cam and cam.FieldOfView
	if type(fov) == "number" then
		local calm = (Store.get("settings") or {}).shake == false or Theme.reducedMotion()
		local target = BASE_FOV + ((running and not calm) and Constants.SPRINT_FOV or 0)
		if math.abs(target - fov) > 0.05 then
			cam.FieldOfView = fov + (target - fov) * math.min(1, dt * 6)
		end
	end
	-- sand kicked up on an island
	local me = Store.get("me")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if running and r and me and me.where == "island" and os.clock() > puffAt then
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics then
			puffAt = os.clock() + 0.18
			FxController.burst(r.Position - Vector3.new(0, 2.6, 0), SAND, 3, 0.35, 5, 0.45, { up = 0.5, gravity = 25 })
		end
	end
end

function MoveController:init()
	buildButtons()
	ContextActionService:BindAction("EV_Run", function(_, state, input)
		local key = input and input.KeyCode
		if key == Enum.KeyCode.ButtonL3 then
			if state == Enum.UserInputState.Begin then
				MoveController.setRun(not toggled, true)
			end
			return Enum.ContextActionResult.Sink
		end
		if state == Enum.UserInputState.Begin then
			shift = true
			apply()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			shift = false
			apply()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	UserInputService.InputEnded:Connect(function(input)
		if jumpInput and input == jumpInput then
			jumpInput = nil
		end
	end)
	-- a new body (respawned) walks until asked again; the server's speed for it comes from PlayerService:Spawn
	player.CharacterAdded:Connect(function()
		shift, toggled, byStick, sent = false, false, false, false
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		step(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			layout()
			sync()
		end
	end)
	layout()
end

-- (tests)
MoveController.refs = refs

return MoveController

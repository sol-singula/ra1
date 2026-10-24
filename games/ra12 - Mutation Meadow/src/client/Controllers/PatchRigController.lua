--[[
Patch's poses on the client (Game Artist build-spec/05-patch.md section 4). The server owns the rig at
Workspace.Street.Patch and sets its Anim / Face attributes (PatchService.LINE_LOOK); while the AnimationIds are ""
this drives him procedurally, one lerp on Heartbeat (the parts move only here, locally):

  Anim change     tween to the pose: 0.25 s Quad Out (wave, point, idle, lean) or 0.35 s Back Out (cheer, announce)
  idle            breathing (y +-0.04 over 2 s) and a head yaw (+-6 deg over 4 s), looped
  wave            the hand wiggles (+-25 deg at 4 Hz) for the first 1.2 s
  cheer           the hop lands after 0.4 s
  Face change     the face's part swap (Models/Patch.setFace)
  beyond 120 studs  SeedPacket, SeedDot, the eye shines, cheeks and Cowlick hide; the pose stops updating

  PatchRigController.rig() / params()   (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PatchModel = require(ReplicatedStorage.Shared.Models.Patch)

local PatchRigController = {}

local PV = Config.PatchVisuals

local rig
local current, tween
local anim, face, animT, clock = nil, nil, 0, 0
local far = false

function PatchRigController.rig()
	return rig
end

function PatchRigController.params()
	return current
end

local function quadOut(x)
	return 1 - (1 - x) * (1 - x)
end

local function backOut(x)
	local s = 1.70158
	return 1 + (s + 1) * (x - 1) ^ 3 + s * (x - 1) ^ 2
end

local function find()
	local street = workspace:FindFirstChild("Street")
	local m = street and street:FindFirstChild("Patch")
	return if m and m:GetAttribute("Origin") and m:FindFirstChild("PumpkinHead") then m else nil
end

local function cameraPosition()
	local ok, cf = pcall(function()
		return workspace.CurrentCamera.CFrame
	end)
	return ok and cf and cf.Position or nil
end

local function startTween(to, spec)
	tween = { from = current, to = to, t = 0, sec = spec.sec, ease = if spec.style == "back" then backOut else quadOut }
end

function PatchRigController.step(dt)
	if not rig or not rig.Parent then
		rig = find()
		if not rig then
			return
		end
		anim, face = rig:GetAttribute("Anim") or "idle", rig:GetAttribute("Face") or "happy"
		current, tween, animT, far = PatchModel.pose(anim), nil, 0, false
		PatchModel.setFace(rig, face)
	end
	clock += dt
	animT += dt
	local nowAnim, nowFace = rig:GetAttribute("Anim") or "idle", rig:GetAttribute("Face") or "happy"
	if nowFace ~= face then
		face = nowFace
		PatchModel.setFace(rig, face)
	end
	if nowAnim ~= anim then
		anim, animT = nowAnim, 0
		startTween(PatchModel.pose(anim), PV.tween[anim] or PV.tween.idle)
	end
	-- the cheer's hop lands
	if anim == "cheer" and animT >= PV.cheer.landSec and animT - dt < PV.cheer.landSec then
		local landed = PatchModel.pose("cheer")
		landed.lift = Vector3.zero
		startTween(landed, PV.tween.idle)
	end
	local eye = cameraPosition()
	local head = rig:FindFirstChild("PumpkinHead")
	local isFar = eye ~= nil and head ~= nil and (head.Position - eye).Magnitude > PV.lod.studs
	if isFar ~= far then
		far = isFar
		PatchModel.setFar(rig, far)
	end
	if tween then
		tween.t += dt
		local x = math.clamp(tween.t / tween.sec, 0, 1)
		current = PatchModel.mix(tween.from, tween.to, tween.ease(x))
		if x >= 1 then
			current, tween = tween.to, nil
		end
	end
	if far then
		return
	end
	local shown = table.clone(current)
	shown.armR = table.clone(current.armR)
	if anim == "idle" then
		local i = PV.idle
		shown.breath = i.breath * math.sin(2 * math.pi * clock / i.breathSec)
		shown.yaw = current.yaw + i.yaw * math.sin(2 * math.pi * clock / i.yawSec)
	elseif anim == "wave" and animT < PV.wave.sec then
		shown.armR[2] += PV.wave.wiggle * math.sin(2 * math.pi * PV.wave.hz * animT)
	end
	PatchModel.apply(rig, shown)
end

function PatchRigController:Start()
	RunService.Heartbeat:Connect(function(dt)
		PatchRigController.step(dt)
	end)
end

return PatchRigController

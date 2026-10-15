--[[
Animation for the survivors' characters (master plan §4: readable actions). Roblox's own walk, run, jump and swim
keep playing; on top of them this bends the joints by hand (each Motor6D's C0, on this client only), easing every
offset in and out:

  holding     anything in your hand: the forearm level in front of you, like any Roblox tool
  the rod     an overarm cast; then the rod held out in both hands, the line in the water ("fishing"); the tip
              jerking on a bite ("bite"); the left hand cranking the reel while a piece or a fish comes in ("reel")
  axes, picks, crowbars, the hammer   a wind-up over the head and a hard swing down in front
  spears      a level thrust; harpoons: an overarm throw
  eating, reading   hand to the face
  emotes      a wave, a cheer, a dance
The one-shots come from "Act"; the sustained poses are the character's "Pose" attribute, set by the server
(PlayerService:SetPose), so everyone sees them.
Your own actions play the instant you press (InputController fires Bus.Swing); the server's echo for you is skipped.
Directions: a positive pitch swings an arm or a forearm forward and up; a negative pitch leans the waist forward.
R15 rigs get every joint; R6 rigs get the shoulders, the neck and the root.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)

local AnimController = { Name = "AnimController", Order = 40 }

local player = Players.LocalPlayer
local recs = {} -- [character] = { motors, swingAt, item, mode, emote, emoteAt, flinchAt, lastHealth, locked }
local RANGE = 150
local MOTORS = { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist", "Neck", "Root" }
local R6_NAMES = { ["Right Shoulder"] = "RightShoulder", ["Left Shoulder"] = "LeftShoulder", RootJoint = "Root" }
local localSwingAt, localSwingMode = -10, nil

local HOLD_SHOULDER, HOLD_ELBOW = 0.95, 0.55
AnimController.HOLD_SHOULDER, AnimController.HOLD_ELBOW = HOLD_SHOULDER, HOLD_ELBOW

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function scan(rec, character)
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") then
			local name = table.find(MOTORS, d.Name) and d.Name or R6_NAMES[d.Name]
			local m = name and rec.motors[name]
			if name and (not m or m.motor ~= d) then
				rec.motors[name] = { motor = d, base = d.C0 }
			end
		end
	end
	rec.scanAt = os.clock() + 1
end

local function getRec(character)
	local rec = recs[character]
	if rec then
		if os.clock() > rec.scanAt and not (rec.motors.RightShoulder and rec.motors.Neck) then
			scan(rec, character)
		end
		return rec
	end
	rec = { motors = {}, swingAt = -10, emoteAt = -10, flinchAt = -10, scanAt = 0, locked = {} }
	scan(rec, character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		rec.lastHealth = hum.Health
		hum.HealthChanged:Connect(function(h)
			if rec.lastHealth and h < rec.lastHealth - 0.5 then
				rec.flinchAt = os.clock()
			end
			rec.lastHealth = h
		end)
	end
	character.Destroying:Connect(function()
		recs[character] = nil
	end)
	recs[character] = rec
	return rec
end

local function characterOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

local function start(character, item, mode)
	local rec = getRec(character)
	rec.swingAt = os.clock()
	rec.item = item
	rec.mode = mode
	if mode == "emote" then
		rec.emote = item
		rec.emoteAt = os.clock()
	end
end

local function heldItem(character)
	if not character:FindFirstChild("Held") then
		return nil
	end
	local key = character:GetAttribute("Held")
	return type(key) == "string" and Items.get(key) or nil
end
AnimController.heldItem = heldItem

local OVERHEAD = { chop = true, mine = true, pry = true, repair = true }
local OVERARM = { cast = true, throw = true }

-- The sustained poses (the character's "Pose" attribute). Each returns S, E, LS, LE, waist, neck.
local SUSTAINED = {}
function SUSTAINED.fishing(clock)
	-- the rod held out and a little down, both hands on it, swaying with the waiting
	local sway = math.sin(clock * 1.4) * 0.04
	return 0.75 + sway, 0.3, 0.55 + sway, 1.25, -0.06, 0.12
end
function SUSTAINED.bite(clock)
	-- the tip jerks: the whole arm tugs down and back up, fast
	local jerk = math.max(0, math.sin(clock * 9)) * 0.3
	return 0.75 - jerk, 0.3 + jerk * 0.5, 0.55 - jerk * 0.5, 1.25, -0.12 - jerk * 0.2, 0.18
end
function SUSTAINED.reel(clock)
	-- the rod pulled up and back, the left hand cranking in circles
	local c = clock * 14
	return 1.45, 0.5, 0.95 + math.sin(c) * 0.25, 1.1 + math.cos(c) * 0.35, 0.12, -0.05
end

function AnimController.pose(rec, character, clock)
	local out = {}
	local locked = {}
	local function add(joint, cf)
		out[joint] = (out[joint] or CFrame.new()) * cf
	end
	local t = clock - rec.swingAt
	local mode = rec.mode
	local held = heldItem(character)
	local S, E = 0, 0
	local LS, LE = 0, 0
	local rollR, rollL = 0, 0
	local waist, neck = 0, 0
	if held then
		S, E = HOLD_SHOULDER, HOLD_ELBOW
		locked.RightShoulder, locked.RightElbow = true, true
	end
	local S0, E0 = S, E
	local function lockBoth()
		locked.RightShoulder, locked.RightElbow, locked.LeftShoulder, locked.LeftElbow = true, true, true, true
	end
	if OVERHEAD[mode] and t < 0.6 then
		local windup, strike, back = mode == "repair" and 0.1 or 0.14, 0.12, 0.25
		local upS, upE, downS, downE = 2.75, 0.9, 0.3, 0.1
		if t < windup then
			local k = ease(t / windup)
			S, E = lerp(S0, upS, k), lerp(E0, upE, k)
			waist += 0.12 * k
		elseif t < windup + strike then
			local k = ease((t - windup) / strike)
			S, E = lerp(upS, downS, k), lerp(upE, downE, k)
			waist += lerp(0.12, -0.25, k)
		elseif t < windup + strike + back then
			local k = ease((t - windup - strike) / back)
			S, E = lerp(downS, S0, k), lerp(downE, E0, k)
			waist += -0.25 * (1 - k)
		end
		locked.RightShoulder, locked.RightElbow = true, true
	elseif OVERARM[mode] and t < 0.5 then
		-- overarm: cocked behind the head, whipped forward, then back to the hold (the "pulling" and "fishing"
		-- poses take over from there)
		if t < 0.2 then
			local k = ease(t / 0.2)
			S, E = lerp(S0, 2.8, k), lerp(E0, 1.2, k)
		elseif t < 0.35 then
			local k = ease((t - 0.2) / 0.15)
			S, E = lerp(2.8, 1.3, k), lerp(1.2, 0.05, k)
		else
			local k = ease((t - 0.35) / 0.15)
			S, E = lerp(1.3, S0, k), lerp(0.05, E0, k)
		end
		locked.RightShoulder, locked.RightElbow = true, true
	elseif SUSTAINED[character:GetAttribute("Pose")] then
		local pS, pE, pLS, pLE, pWaist, pNeck = SUSTAINED[character:GetAttribute("Pose")](clock)
		-- ease in over the first moments
		local since = clock - (rec.poseAt or 0)
		local k = ease(since / 0.25)
		S, E = lerp(S0, pS, k), lerp(E0, pE, k)
		LS, LE = pLS * k, pLE * k
		waist += pWaist * k
		neck += pNeck * k
		lockBoth()
	elseif mode == "swing" and t < 0.45 then
		-- a level thrust
		if t < 0.1 then
			local k = ease(t / 0.1)
			S, E = lerp(S0, 0.45, k), lerp(E0, 1.1, k)
		elseif t < 0.2 then
			local k = ease((t - 0.1) / 0.1)
			S, E = lerp(0.45, 1.55, k), lerp(1.1, 0, k)
			waist -= 0.2 * k
		else
			local k = ease((t - 0.2) / 0.25)
			S, E = lerp(1.55, S0, k), lerp(0, E0, k)
			waist -= 0.2 * (1 - k)
		end
		locked.RightShoulder, locked.RightElbow = true, true
	elseif (mode == "eat" or mode == "use") and t < 1 then
		local k = t < 0.2 and ease(t / 0.2) or t > 0.7 and 1 - ease((t - 0.7) / 0.3) or 1
		S, E = lerp(S0, 1.0, k), lerp(E0, 2.1, k)
		rollR = -0.3 * k
		neck -= 0.1 * k
		locked.RightShoulder, locked.RightElbow = true, true
	end
	-- moving fast: lean in; low on health: the chest heaves
	local hum = character:FindFirstChildOfClass("Humanoid")
	local r = character:FindFirstChild("HumanoidRootPart")
	if hum and r then
		local speed = (r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if speed > 18 then
			waist -= 0.12
		end
		if hum.Health > 0 and hum.Health < hum.MaxHealth * 0.3 then
			waist += -0.1 + math.sin(clock * 6) * 0.05
			neck -= 0.2
		end
	end
	local f = clock - rec.flinchAt
	if f < 0.3 then
		waist += 0.35 * (1 - f / 0.3)
	end
	-- emotes
	local e = clock - rec.emoteAt
	if rec.emote and e < 3 then
		local k = e < 0.2 and ease(e / 0.2) or e > 2.6 and 1 - ease((e - 2.6) / 0.4) or 1
		local key = rec.emote
		if key == "wave" then
			S, E = lerp(S, 2.8, k), lerp(E, 0.3, k)
			rollR = math.sin(clock * 10) * 0.4 * k
			locked.RightShoulder, locked.RightElbow = true, true
		elseif key == "cheer" then
			local w = math.abs(math.sin(clock * 8))
			S, E = lerp(S, 2.9, k), lerp(E, 0.2 + w * 0.3, k)
			LS, LE = 2.9 * k, (0.2 + w * 0.3) * k
			lockBoth()
		elseif key == "dance" then
			add("Waist", CFrame.Angles(0, math.sin(clock * 6) * 0.35 * k, math.sin(clock * 12) * 0.12 * k))
			S = lerp(S, math.sin(clock * 6) * 1.6, k)
			LS = -math.sin(clock * 6) * 1.6 * k
			lockBoth()
		end
	end
	if not rec.motors.RightElbow then
		S, E = S + E, 0
	end
	if not rec.motors.LeftElbow then
		LS, LE = LS + LE, 0
	end
	if S ~= 0 or rollR ~= 0 then
		add("RightShoulder", CFrame.Angles(S, 0, rollR))
	end
	if E ~= 0 then
		add("RightElbow", CFrame.Angles(E, 0, 0))
	end
	if LS ~= 0 or rollL ~= 0 then
		add("LeftShoulder", CFrame.Angles(LS, 0, rollL))
	end
	if LE ~= 0 then
		add("LeftElbow", CFrame.Angles(LE, 0, 0))
	end
	if waist ~= 0 then
		add("Waist", CFrame.Angles(waist, 0, 0))
	end
	if neck ~= 0 then
		add("Neck", CFrame.Angles(neck, 0, 0))
	end
	return out, locked
end

local function near(a, b)
	return (a.Position - b.Position).Magnitude < 1e-3
		and a.LookVector:Dot(b.LookVector) > 0.9999
		and a.UpVector:Dot(b.UpVector) > 0.9999
end

local function apply(character, rec, clock)
	local now = character:GetAttribute("Pose")
	if now ~= rec.poseKey then
		rec.poseKey = now
		rec.poseAt = clock
	end
	local pose, locked = AnimController.pose(rec, character, clock)
	rec.locked = locked
	for name, m in rec.motors do
		local motor = m.motor
		if motor.Parent then
			if m.set and not near(motor.C0, m.set) then
				m.base = motor.C0
			end
			local off = pose[name]
			local c0 = off and CFrame.new(m.base.Position) * off * m.base.Rotation or m.base
			m.set = c0
			motor.C0 = c0
		end
	end
end

local function rest(rec)
	for _, m in rec.motors do
		if m.set and m.motor.Parent then
			m.motor.C0 = m.base
		end
		m.set = nil
	end
	rec.locked = {}
end

local function holdLocked()
	for _, rec in recs do
		for name in rec.locked or {} do
			local m = rec.motors[name]
			if m and m.motor.Parent then
				m.motor.Transform = CFrame.new()
			end
		end
	end
end

function AnimController:init()
	Net.listen("Act", function(a)
		if type(a) ~= "table" or not a.by then
			return
		end
		if a.by == player.UserId and a.mode == localSwingMode and os.clock() - localSwingAt < 0.35 then
			return
		end
		local c = characterOf(a.by)
		if c then
			if a.mode == "emote" then
				start(c, a.key, "emote")
			else
				start(c, a.item, a.mode)
			end
		end
	end)
	Bus.Swing:Connect(function(item, mode)
		local c = player.Character
		if c then
			localSwingAt, localSwingMode = os.clock(), mode
			start(c, item, mode)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local clock = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
		for _, p in Players:GetPlayers() do
			local c = p.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - camPos).Magnitude < RANGE then
				apply(c, getRec(c), clock)
			elseif c and recs[c] then
				rest(recs[c])
			end
		end
	end)
	local ok, preSimulation = pcall(function()
		return RunService.PreSimulation
	end)
	local signal = ok and preSimulation or RunService.Stepped
	signal:Connect(holdLocked)
end

-- (tests)
AnimController.recs = recs

return AnimController

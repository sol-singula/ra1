--[[
Animation for the survivors' characters (master plan §4: readable actions). Roblox's own walk, run, jump and swim
keep playing; on top of them this bends the joints by hand, on this client only, easing every offset in and out:

  holding     anything in your hand: the forearm level in front of you, like any Roblox tool
  the rod     held low in front with the rod angled up; an overarm cast (up and back over the shoulder, then the
              whip out over the water); then the rod held out low in both hands, the line in the water
              ("fishing"); the tip jerking on a bite ("bite"); the rod pulled up while the left hand cranks the reel
              as a piece or a fish comes in ("reel")
  axes, picks, crowbars, the hammer   a wind-up over the head and a hard swing down in front
  spears      a level thrust; harpoons: an overarm throw
  eating, reading   hand to the face
  emotes      a wave, a cheer, a dance
  running     faster than a walk on your feet (MoveController's run): a lean into it, the head up, and the free
              arms bent like a sprinter's, on top of Roblox's own run so they still swing with the legs
The one-shots come from "Act"; the sustained poses are the character's "Pose" attribute, set by the server
(PlayerService:SetPose), so everyone sees them.
Your own actions play the instant you press (InputController fires Bus.Swing); the server's echo for you is skipped.

How it moves the joints (the way Roblox asks for it): each joint's Transform, written in RunService.PreSimulation,
after the Animator has written its own for the frame and before the joints move. A joint the pose owns ("locked":
the arm holding a tool) gets the pose alone; the others (the waist, the neck) get the pose layered on top of what
the Animator wrote. That works on both kinds of avatar joint: Motor6Ds, and the AnimationConstraints Roblox's Avatar
Joint Upgrade spawns instead. (C0 is never touched: on avatars the platform spawns, Roblox puts every Motor6D's C0
back to what its rig attachments say, so posing through C0 does nothing.)
Directions: a positive pitch swings an arm, a forearm or a hand forward and up; a negative pitch leans the waist
forward. R15 rigs get every joint; R6 rigs get the shoulders, the neck and the root (the elbow and wrist bends folded
into the shoulder).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)

local AnimController = { Name = "AnimController", Order = 40 }

local player = Players.LocalPlayer
local recs = {} -- [character] = { joints, swingAt, item, mode, emote, emoteAt, flinchAt, lastHealth, locked, scanAt }
local RANGE = 150
local JOINTS =
	{ "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck", "Root" }
local R6_NAMES = { ["Right Shoulder"] = "RightShoulder", ["Left Shoulder"] = "LeftShoulder", RootJoint = "Root" }
local localSwingAt, localSwingMode = -10, nil

-- the forearm level in front of you (any tool)
local HOLD_SHOULDER, HOLD_ELBOW = 0.95, 0.55
-- the rod: the hand low in front, the rod angled up (the rod leaves the fist 40° above the hand's forward: see
-- ItemModels.holdCFrame), so with the arm just hanging it still points up and out
local ROD_HOLD = { 0.25, 0.35, -0.2 } -- shoulder, elbow, wrist
-- running: the forearms raised this far (on top of the run's own swing)
local RUN_ELBOW = 1.15
AnimController.HOLD_SHOULDER, AnimController.HOLD_ELBOW = HOLD_SHOULDER, HOLD_ELBOW
AnimController.ROD_HOLD = ROD_HOLD
AnimController.RUN_ELBOW = RUN_ELBOW

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function isJoint(d)
	return d:IsA("Motor6D") or d:IsA("AnimationConstraint")
end

local function scan(rec, character)
	local joints = {}
	for _, d in character:GetDescendants() do
		if isJoint(d) then
			local name = table.find(JOINTS, d.Name) and d.Name or R6_NAMES[d.Name]
			if name and not joints[name] then
				local old = rec.joints[name]
				joints[name] = (old and old.joint == d) and old or { joint = d }
			end
		end
	end
	rec.joints = joints
	rec.scanAt = os.clock() + 2
end

local function getRec(character)
	local rec = recs[character]
	if rec then
		-- a body that changed (an avatar's parts arriving or being swapped): find the joints again
		local stale = os.clock() > rec.scanAt or not rec.joints.RightShoulder
		if not stale then
			for _, j in rec.joints do
				if not j.joint.Parent then
					stale = true
					break
				end
			end
		end
		if stale then
			scan(rec, character)
		end
		return rec
	end
	rec = { joints = {}, swingAt = -10, emoteAt = -10, flinchAt = -10, scanAt = 0, locked = {} }
	scan(rec, character)
	character.DescendantAdded:Connect(function(d)
		if isJoint(d) then
			rec.scanAt = 0
		end
	end)
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

-- The sustained poses (the character's "Pose" attribute). Each returns S, E, LS, LE, waist, neck, W (the wrist).
local SUSTAINED = {}
function SUSTAINED.fishing(clock)
	-- the rod held out low over the water in both hands, swaying with the waiting
	local sway = math.sin(clock * 1.4) * 0.04
	return 0.55 + sway, 0.25, 0.5 + sway, 1.2, -0.06, 0.12, -0.95
end
function SUSTAINED.bite(clock)
	-- the tip jerks: the whole arm tugs down and back up, fast
	local jerk = math.max(0, math.sin(clock * 9)) * 0.3
	return 0.55 - jerk, 0.25 + jerk * 0.5, 0.5 - jerk * 0.5, 1.2, -0.12 - jerk * 0.2, 0.18, -0.95 - jerk * 0.5
end
function SUSTAINED.reel(clock)
	-- the rod pulled up, the left hand cranking in circles
	local c = clock * 14
	return 0.85, 0.55, 0.95 + math.sin(c) * 0.25, 1.1 + math.cos(c) * 0.35, 0.12, -0.05, -0.9
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
	local rod = held ~= nil and Items.toolKind(held) == "rod"
	local S, E, W = 0, 0, 0
	local LS, LE = 0, 0
	local rollR, rollL = 0, 0
	local waist, neck = 0, 0
	if rod then
		S, E, W = ROD_HOLD[1], ROD_HOLD[2], ROD_HOLD[3]
		locked.RightShoulder, locked.RightElbow, locked.RightWrist = true, true, true
	elseif held then
		S, E = HOLD_SHOULDER, HOLD_ELBOW
		locked.RightShoulder, locked.RightElbow, locked.RightWrist = true, true, true
	end
	local S0, E0, W0 = S, E, W
	local function lockBoth()
		locked.RightShoulder, locked.RightElbow, locked.LeftShoulder, locked.LeftElbow = true, true, true, true
		locked.RightWrist = true
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
		locked.RightShoulder, locked.RightElbow, locked.RightWrist = true, true, true
	elseif mode == "cast" and t < 0.7 then
		-- a proper cast: both hands up and back over the shoulder (the rod pointing back behind you), a lean back,
		-- then the whip forward with the body behind it (the rod out level over the water), and back to the hold
		if t < 0.25 then
			local k = ease(t / 0.25)
			S, E, W = lerp(S0, 2.5, k), lerp(E0, 0.6, k), lerp(W0, -1.2, k)
			LS, LE = 2.2 * k, 1.1 * k
			waist += 0.18 * k
			add("Waist", CFrame.Angles(0, -0.35 * k, 0))
		elseif t < 0.4 then
			local k = ease((t - 0.25) / 0.15)
			S, E, W = lerp(2.5, 0.7, k), lerp(0.6, 0.05, k), lerp(-1.2, -1.25, k)
			LS, LE = lerp(2.2, 0.9, k), lerp(1.1, 0.3, k)
			waist += lerp(0.18, -0.22, k)
			add("Waist", CFrame.Angles(0, lerp(-0.35, 0.2, k), 0))
		else
			local k = ease((t - 0.4) / 0.3)
			S, E, W = lerp(0.7, S0, k), lerp(0.05, E0, k), lerp(-1.25, W0, k)
			LS, LE = lerp(0.9, 0, k), lerp(0.3, 0, k)
			waist += -0.22 * (1 - k)
			add("Waist", CFrame.Angles(0, 0.2 * (1 - k), 0))
		end
		lockBoth()
	elseif OVERARM[mode] and t < 0.5 then
		-- overarm: cocked behind the head, whipped forward, then back to the hold (the "reel" and "fishing" poses
		-- take over from there)
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
		locked.RightShoulder, locked.RightElbow, locked.RightWrist = true, true, true
	elseif SUSTAINED[character:GetAttribute("Pose")] then
		local pS, pE, pLS, pLE, pWaist, pNeck, pW = SUSTAINED[character:GetAttribute("Pose")](clock)
		-- ease in over the first moments
		local since = clock - (rec.poseAt or 0)
		local k = ease(since / 0.25)
		S, E, W = lerp(S0, pS, k), lerp(E0, pE, k), lerp(W0, rod and pW or 0, k)
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
		locked.RightShoulder, locked.RightElbow, locked.RightWrist = true, true, true
	elseif (mode == "eat" or mode == "use") and t < 1 then
		local k = t < 0.2 and ease(t / 0.2) or t > 0.7 and 1 - ease((t - 0.7) / 0.3) or 1
		S, E = lerp(S0, 1.0, k), lerp(E0, 2.1, k)
		rollR = -0.3 * k
		neck -= 0.1 * k
		locked.RightShoulder, locked.RightElbow, locked.RightWrist = true, true, true
	end
	-- running (faster than a walk, not swimming): lean in, head up, the free arms bent; low on health: the chest heaves
	local hum = character:FindFirstChildOfClass("Humanoid")
	local r = character:FindFirstChild("HumanoidRootPart")
	if hum and r then
		local speed = (r.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local swimming = hum:GetState() == Enum.HumanoidStateType.Swimming
		local want = swimming and 0 or math.clamp((speed - Constants.WALK_SPEED - 1) / 6, 0, 1)
		local dt = math.clamp(clock - (rec.runClock or clock), 0, 0.1)
		rec.runClock = clock
		rec.run = (rec.run or 0) + (want - (rec.run or 0)) * math.min(1, dt * 8)
		local k = rec.run
		if k > 0.01 then
			waist -= 0.26 * k
			neck += 0.14 * k
			if rec.joints.RightElbow and not locked.RightElbow then
				E += RUN_ELBOW * k
			end
			if rec.joints.LeftElbow and not locked.LeftElbow then
				LE += RUN_ELBOW * k
			end
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
	-- R6 (no elbows, no wrists): the bends go into the shoulder
	if not rec.joints.RightWrist then
		E, W = E + W, 0
	end
	if not rec.joints.RightElbow then
		S, E = S + E, 0
	end
	if not rec.joints.LeftElbow then
		LS, LE = LS + LE, 0
	end
	if S ~= 0 or rollR ~= 0 or locked.RightShoulder then
		add("RightShoulder", CFrame.Angles(S, 0, rollR))
	end
	if E ~= 0 or locked.RightElbow then
		add("RightElbow", CFrame.Angles(E, 0, 0))
	end
	if W ~= 0 or locked.RightWrist then
		add("RightWrist", CFrame.Angles(W, 0, 0))
	end
	if LS ~= 0 or rollL ~= 0 or locked.LeftShoulder then
		add("LeftShoulder", CFrame.Angles(LS, 0, rollL))
	end
	if LE ~= 0 or locked.LeftElbow then
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

local function same(a, b)
	return (a.Position - b.Position).Magnitude < 1e-4
		and a.LookVector:Dot(b.LookVector) > 0.99999
		and a.UpVector:Dot(b.UpVector) > 0.99999
end

-- The joint's own frame (C0's rotation, or Attachment0's): a pose is a turn about the parent part's axes, the
-- Transform turns about the joint's.
local function frameRotation(joint)
	local ok, r = pcall(function()
		if joint:IsA("Motor6D") then
			return joint.C0.Rotation
		end
		local a0 = joint.Attachment0
		return a0 and a0.CFrame.Rotation or CFrame.new()
	end)
	return ok and r or CFrame.new()
end

-- Write the pose into the joints' Transforms (PreSimulation: after the Animator, before the joints move).
local function write(rec, pose, locked)
	for name, j in rec.joints do
		local joint = j.joint
		if joint.Parent then
			local current = joint.Transform
			-- what the Animator wrote this frame (it may skip frames: then what it wrote last)
			if not j.written or not same(current, j.written) then
				j.anim = current
			end
			local off = pose[name]
			if off then
				local r0 = frameRotation(joint)
				local turn = r0:Inverse() * off * r0
				local value = locked[name] and turn or turn * (j.anim or CFrame.new())
				joint.Transform = value
				j.written = value
			elseif j.written then
				-- the pose let go of this joint: back to the animation
				joint.Transform = j.anim or CFrame.new()
				j.written = nil
			end
		end
	end
end

local function rest(rec)
	for _, j in rec.joints do
		if j.written and j.joint.Parent then
			j.joint.Transform = j.anim or CFrame.new()
		end
		j.written = nil
	end
	rec.locked = {}
end

local function apply(character, rec, clock)
	local now = character:GetAttribute("Pose")
	if now ~= rec.poseKey then
		rec.poseKey = now
		rec.poseAt = clock
	end
	local pose, locked = AnimController.pose(rec, character, clock)
	rec.locked = locked
	write(rec, pose, locked)
end

local function frame()
	local clock = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and (p == player or (r.Position - camPos).Magnitude < RANGE) then
			apply(c, getRec(c), clock)
		elseif c and recs[c] then
			rest(recs[c])
		end
	end
end
AnimController.frame = frame

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
	local ok, preSimulation = pcall(function()
		return RunService.PreSimulation
	end)
	local signal = ok and preSimulation or RunService.Stepped
	signal:Connect(frame)
end

-- (tests)
AnimController.recs = recs

return AnimController

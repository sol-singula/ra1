--[[
Animation for survivors' characters (master plan §5: fast, readable actions; §13: animation sells the game). Roblox's
own walk, run and jump keep playing; on top of them this bends the joints by hand (each Motor6D's C0, on this
client only), easing every offset in and out:

  holding     anything in your hand: the forearm level in front of you, like any Roblox tool (the arm holding it
              stops swinging as you walk)
  swings      axes and clubs: a wind-up over the head and a hard chop down in front; spears: a level thrust; bows:
              draw and loose; fists: a jab
  specials    Whirl Chop (a spin), Ground Pound (both arms down), Lunge Thrust, Triple Shot
  items       eating and drinking (hand to mouth), throwing overarm
  the dodge   a quick tuck
  downed      flat on the ground, crawling (the Root joint tilts the whole body)
  goo         stuck in a cocoon: arms pinned, wriggling
  sprinting   leaning into it; low health: the chest heaves
  emotes      the 6-7 (forearms out, palms up, going up and down), a wave, a dance
Your own swings play the instant you press (InputController fires Bus.Swing); the server's echo for you is skipped.

Directions (every offset turns about the parent part's own axes, at the joint): a positive pitch swings an arm or
a forearm forward and up; a negative pitch leans the waist forward and tips the head down. R15 rigs get every joint;
R6 rigs get the shoulders, the neck and the root (their arms have no elbow, so the elbow's bend goes to the shoulder).
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

-- The hold pose: the upper arm a little forward, the forearm level in front of you.
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
		-- (a character still loading, or a rig rebuilt: look for its joints again now and then)
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
	if item == "emote" then
		rec.emote = mode
		rec.emoteAt = os.clock()
	end
end

-- What a character holds (its "Held" model, welded to the right hand by the server), or nil.
local function heldItem(character)
	if not character:FindFirstChild("Held") then
		return nil
	end
	local key = character:GetAttribute("Held")
	return type(key) == "string" and Items.get(key) or nil
end
AnimController.heldItem = heldItem

--[[ The pose for one character right now: { joint = CFrame offset }, and the joints whose own animation is held
still (Roblox's walk swings the arms; an arm holding something, or in the middle of a move, stays where it's put). ]]
function AnimController.pose(rec, character, clock)
	local out = {}
	local locked = {}
	local function add(joint, cf)
		out[joint] = (out[joint] or CFrame.new()) * cf
	end
	local status = character:GetAttribute("Status")
	local t = clock - rec.swingAt
	local item = rec.item and Items.get(rec.item)
	local class = item and item.class or (rec.item == "hands" and "fist" or nil)
	local mode = rec.mode
	if status == "downed" then
		-- flat on the ground, crawling: arms reaching ahead in turn
		add("Root", CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(-82), 0, 0))
		local crawl = math.sin(clock * 5)
		add("RightShoulder", CFrame.Angles(math.rad(-150) + crawl * 0.4, 0, 0))
		add("LeftShoulder", CFrame.Angles(math.rad(-150) - crawl * 0.4, 0, 0))
		add("Neck", CFrame.Angles(math.rad(50), 0, 0))
		locked.RightShoulder, locked.LeftShoulder, locked.RightElbow, locked.LeftElbow = true, true, true, true
		return out, locked
	end
	local owner = Players:GetPlayerFromCharacter(character)
	if character:GetAttribute("Cocooned") or (owner and owner:GetAttribute("Cocooned")) then
		local w = math.sin(clock * 14) * 0.15
		add("RightShoulder", CFrame.Angles(0, 0, -0.08 + w))
		add("LeftShoulder", CFrame.Angles(0, 0, 0.08 - w))
		add("Waist", CFrame.Angles(0, w, 0))
		locked.RightShoulder, locked.LeftShoulder, locked.RightElbow, locked.LeftElbow = true, true, true, true
		return out, locked
	end

	-- the arms, as pitches (positive: forward and up) and rolls (positive: out to the side)
	local held = heldItem(character)
	local S, E = 0, 0 -- right shoulder, right elbow
	local LS, LE = 0, 0 -- left shoulder, left elbow
	local rollR, rollL = 0, 0
	local waist, neck = 0, 0 -- pitches (negative: lean forward, look down)
	if held then
		S, E = HOLD_SHOULDER, HOLD_ELBOW
		locked.RightShoulder, locked.RightElbow = true, true
	end
	local S0, E0 = S, E
	local function lockBoth()
		locked.RightShoulder, locked.RightElbow, locked.LeftShoulder, locked.LeftElbow = true, true, true, true
	end

	if rec.item == "dodge" and t < 0.35 then
		-- a quick tuck
		local k = math.sin(t / 0.35 * math.pi)
		waist -= 0.7 * k
		neck -= 0.4 * k
		S, E = lerp(S, 0.9, k), lerp(E, 1.1, k)
		LS, LE = 0.9 * k, 1.1 * k
		lockBoth()
	elseif mode == "special" and t < 0.9 then
		local k = t < 0.15 and ease(t / 0.15) or t > 0.6 and 1 - ease((t - 0.6) / 0.3) or 1
		if class == "axe" then
			-- Whirl Chop: the whole body spins once, the axe held out to the side
			add("Root", CFrame.Angles(0, t < 0.6 and t / 0.6 * math.pi * 2 or 0, 0))
			S, E = lerp(S, 1.2, k), lerp(E, 0.1, k)
			rollR = 1.1 * k
		elseif class == "club" then
			-- Ground Pound: both arms up over the head, then down hard
			local a = t < 0.3 and lerp(S0, 2.9, ease(t / 0.3)) or lerp(2.9, 0.35, ease((t - 0.3) / 0.15))
			S, E = lerp(S0, a, k), lerp(E0, 0.2, k)
			LS, LE = lerp(0, a, k), 0.2 * k
			waist += (t > 0.3 and -0.4 or 0.15) * k
			lockBoth()
		elseif class == "spear" then
			-- Lunge Thrust: arm straight out, leaning in
			S, E = lerp(S, 1.55, k), lerp(E, 0, k)
			waist -= 0.35 * k
		elseif class == "bow" then
			-- Triple Shot: the bow arm out, the other hand drawing to the chest
			S, E = lerp(S, 1.5, k), lerp(E, 0, k)
			LS, LE, rollL = 1.35 * k, 1.6 * k, 0.25 * k
			lockBoth()
		end
	elseif mode == "main" and t < 0.7 then
		if class == "axe" or class == "club" or class == "fist" then
			local club, fist = class == "club", class == "fist"
			local windup, strike, back = club and 0.22 or 0.12, club and 0.16 or 0.12, 0.25
			-- an overhead chop: raised over the head (the head of the axe behind you), then down in front of you;
			-- a fist pulls back to the chest and jabs straight out
			local upS, upE = 2.75, 0.9
			local downS, downE = 0.3, 0.1
			if fist then
				upS, upE, downS, downE = 0.2, 1.9, 1.5, 0.05
			end
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
			if club then
				-- two hands on the handle
				LS, LE, rollL = S * 0.85, E, 0.3
				lockBoth()
			end
		elseif class == "spear" then
			-- a level thrust: pull back to the chest, then the arm straight out (the spear stays level)
			if t < 0.1 then
				local k = ease(t / 0.1)
				S, E = lerp(S0, 0.45, k), lerp(E0, 1.1, k)
			elseif t < 0.2 then
				local k = ease((t - 0.1) / 0.1)
				S, E = lerp(0.45, 1.55, k), lerp(1.1, 0, k)
				waist -= 0.2 * k
			elseif t < 0.45 then
				local k = ease((t - 0.2) / 0.25)
				S, E = lerp(1.55, S0, k), lerp(0, E0, k)
				waist -= 0.2 * (1 - k)
			end
			locked.RightShoulder, locked.RightElbow = true, true
		elseif class == "bow" then
			-- draw and loose: the bow arm out, the other hand pulls the string to the chest
			local k = t < 0.15 and ease(t / 0.15) or t > 0.45 and 1 - ease((t - 0.45) / 0.25) or 1
			S, E = lerp(S0, 1.5, k), lerp(E0, 0, k)
			LS, LE, rollL = 1.35 * k, 1.6 * k, 0.25 * k
			lockBoth()
		end
	elseif mode == "use" and t < 1 then
		-- hand to mouth
		local k = t < 0.2 and ease(t / 0.2) or t > 0.7 and 1 - ease((t - 0.7) / 0.3) or 1
		S, E = lerp(S0, 1.0, k), lerp(E0, 2.1, k)
		rollR = -0.3 * k
		neck -= 0.1 * k
		locked.RightShoulder, locked.RightElbow = true, true
	elseif mode == "throw" and t < 0.7 then
		-- overarm: cocked behind the head, whipped forward, then back
		if t < 0.25 then
			local k = ease(t / 0.25)
			S, E = lerp(S0, 2.8, k), lerp(E0, 1.2, k)
		elseif t < 0.4 then
			local k = ease((t - 0.25) / 0.15)
			S, E = lerp(2.8, 0.9, k), lerp(1.2, 0.05, k)
		else
			local k = ease((t - 0.4) / 0.3)
			S, E = lerp(0.9, S0, k), lerp(0.05, E0, k)
		end
		locked.RightShoulder, locked.RightElbow = true, true
	end

	-- sprinting: lean in
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if hum and root then
		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if speed > 20 then
			waist -= 0.18
		end
		-- low on health: the chest heaves
		if hum.Health > 0 and hum.Health < hum.MaxHealth * 0.3 then
			waist += -0.1 + math.sin(clock * 6) * 0.05
			neck -= 0.2
		end
	end
	-- a flinch: knocked back a little
	local f = clock - rec.flinchAt
	if f < 0.3 then
		waist += 0.35 * (1 - f / 0.3)
	end
	-- emotes
	local e = clock - rec.emoteAt
	if rec.emote and e < 3 then
		local k = e < 0.2 and ease(e / 0.2) or e > 2.6 and 1 - ease((e - 2.6) / 0.4) or 1
		local key = rec.emote
		if key == "67" then
			-- the 6-7: forearms out in front, palms up, going up and down in turn
			local w = math.sin(clock * 15)
			S, E = lerp(S, 0.35, k), lerp(E, 1.3 + w * 0.5, k)
			LS, LE = 0.35 * k, (1.3 - w * 0.5) * k
			add("Waist", CFrame.Angles(0, 0, math.sin(clock * 7.5) * 0.05 * k))
			lockBoth()
		elseif key == "wave" then
			S, E = lerp(S, 2.8, k), lerp(E, 0.3, k)
			rollR = math.sin(clock * 10) * 0.4 * k
			locked.RightShoulder, locked.RightElbow = true, true
		elseif key == "dance" then
			add("Waist", CFrame.Angles(0, math.sin(clock * 6) * 0.35 * k, math.sin(clock * 12) * 0.12 * k))
			S = lerp(S, math.sin(clock * 6) * 1.6, k)
			LS = -math.sin(clock * 6) * 1.6 * k
			lockBoth()
		end
	end

	-- R6 arms have no elbow: the bend goes to the shoulder
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

-- Each offset turns about the parent part's axes at the joint: C0 = (the joint's place) * offset * (its rotation).
local function apply(character, rec, clock)
	local pose, locked = AnimController.pose(rec, character, clock)
	rec.locked = locked
	for name, m in rec.motors do
		local motor = m.motor
		if motor.Parent then
			-- (someone else rebuilt the joint: that's the new rest pose)
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

-- Back to the rest pose (out of range).
local function rest(rec)
	for _, m in rec.motors do
		if m.set and m.motor.Parent then
			m.motor.C0 = m.base
		end
		m.set = nil
	end
	rec.locked = {}
end

-- Roblox's animations have just moved the joints (each frame, before physics): hold the locked ones still.
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
		-- your own swing already played when you pressed
		if a.by == player.UserId and a.mode == localSwingMode and os.clock() - localSwingAt < 0.35 then
			return
		end
		local c = characterOf(a.by)
		if c then
			start(c, a.item, a.mode)
		end
	end)
	Bus.Swing:Connect(function(item, mode)
		local c = player.Character
		if c then
			localSwingAt, localSwingMode = os.clock(), mode or "main"
			start(c, item, mode or "main")
		end
	end)
	-- winners do the 6-7
	Net.listen("Results", function(r)
		if type(r) == "table" and r.won then
			for _, p in Players:GetPlayers() do
				if p.Character then
					start(p.Character, "emote", "67")
				end
			end
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
	-- (after Roblox's animations move the joints, before the frame is drawn)
	local ok, preSimulation = pcall(function()
		return RunService.PreSimulation
	end)
	local signal = ok and preSimulation or RunService.Stepped
	signal:Connect(holdLocked)
end

-- (tests)
AnimController.recs = recs

return AnimController

--[[
Animation for survivors' characters (master plan §5: fast, readable actions; §13: animation sells the game). Roblox's
own walk, run and jump keep playing; on top of them this bends the joints by hand (each Motor6D's C0, on this
client only), easing every offset in and out:

  swings      axes and clubs: a wind-up and a hard chop; spears: a thrust; bows: draw and loose; fists: a jab
  specials    Whirl Chop (a spin), Ground Pound (both arms down), Lunge Thrust, Triple Shot
  items       eating and drinking (hand to mouth), throwing overarm
  the dodge   a quick tuck and roll forward
  downed      flat on the ground, crawling (the Root joint tilts the whole body)
  goo         stuck in a cocoon: arms pinned, wriggling
  sprinting   leaning into it; low health: the chest heaves
  emotes      the 6-7 (forearms out, palms up, going up and down), a wave, a dance
Your own swings play the instant you press (InputController fires Bus.Swing); the server's echo for you is skipped.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)

local AnimController = { Name = "AnimController", Order = 40 }

local player = Players.LocalPlayer
local recs = {} -- [character] = { motors, swingAt, item, mode, emote, emoteAt, flinchAt, lastHealth }
local RANGE = 150
local MOTORS = { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "Waist", "Neck", "Root" }
local localSwingAt = -10

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function getRec(character)
	local rec = recs[character]
	if rec then
		return rec
	end
	rec = { motors = {}, swingAt = -10, emoteAt = -10, flinchAt = -10 }
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") and table.find(MOTORS, d.Name) then
			rec.motors[d.Name] = { motor = d, base = d.C0 }
		end
	end
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

-- The pose for one character right now: { joint = CFrame offset }.
function AnimController.pose(rec, character, clock)
	local out = {}
	local function add(joint, cf)
		out[joint] = (out[joint] or CFrame.new()) * cf
	end
	local status = character:GetAttribute("Status")
	local t = clock - rec.swingAt
	local item = rec.item and Items.get(rec.item)
	local class = item and item.class or (rec.item == "hands" and "fist" or nil)
	local mode = rec.mode
	if status == "downed" then
		-- flat on the ground, crawling
		add("Root", CFrame.new(0, -1.6, 0) * CFrame.Angles(math.rad(-82), 0, 0))
		local crawl = math.sin(clock * 5)
		add("RightShoulder", CFrame.Angles(math.rad(-150) + crawl * 0.4, 0, 0))
		add("LeftShoulder", CFrame.Angles(math.rad(-150) - crawl * 0.4, 0, 0))
		add("Neck", CFrame.Angles(math.rad(50), 0, 0))
		return out
	end
	if
		character:GetAttribute("Cocooned")
		or (
			Players:GetPlayerFromCharacter(character)
			and Players:GetPlayerFromCharacter(character):GetAttribute("Cocooned")
		)
	then
		local w = math.sin(clock * 14) * 0.15
		add("RightShoulder", CFrame.Angles(0, 0, 0.1 + w))
		add("LeftShoulder", CFrame.Angles(0, 0, -0.1 - w))
		add("Waist", CFrame.Angles(0, w, 0))
		return out
	end
	if rec.item == "dodge" and t < 0.35 then
		local k = math.sin(t / 0.35 * math.pi)
		add("Waist", CFrame.Angles(0.9 * k, 0, 0))
		add("Neck", CFrame.Angles(0.5 * k, 0, 0))
		add("RightShoulder", CFrame.Angles(-0.8 * k, 0, 0))
		add("LeftShoulder", CFrame.Angles(-0.8 * k, 0, 0))
	elseif mode == "special" and t < 0.9 then
		local k = t < 0.15 and ease(t / 0.15) or t > 0.6 and 1 - ease((t - 0.6) / 0.3) or 1
		if class == "axe" then
			add("Waist", CFrame.Angles(0, t / 0.6 * math.pi * 2 * (t < 0.6 and 1 or 0), 0))
			add("RightShoulder", CFrame.Angles(0, 0, 1.4 * k))
		elseif class == "club" then
			local a = t < 0.3 and -2.9 * ease(t / 0.3) or -2.9 + 2.6 * ease((t - 0.3) / 0.15)
			add("RightShoulder", CFrame.Angles(a * k, 0, 0))
			add("LeftShoulder", CFrame.Angles(a * k, 0, 0))
			add("Waist", CFrame.Angles(t > 0.3 and -0.4 * k or 0.15 * k, 0, 0))
		elseif class == "spear" then
			add("RightShoulder", CFrame.Angles(-1.6 * k, 0, 0))
			add("Waist", CFrame.Angles(-0.35 * k, 0, 0))
		elseif class == "bow" then
			add("LeftShoulder", CFrame.Angles(-1.5 * k, 0, 0))
			add("RightShoulder", CFrame.Angles(-1.4 * k, 0, -0.6 * k))
		end
	elseif mode == "main" and t < 0.7 then
		if class == "axe" or class == "club" or class == "fist" then
			local windup, strike = class == "club" and 0.22 or 0.12, class == "club" and 0.16 or 0.12
			local back = 0.25
			local a
			if t < windup then
				a = -2.6 * ease(t / windup)
			elseif t < windup + strike then
				a = -2.6 + 2.3 * ease((t - windup) / strike)
			elseif t < windup + strike + back then
				a = -0.3 * (1 - ease((t - windup - strike) / back))
			end
			if class == "fist" and a then
				a = a * 0.6
			end
			if a then
				add("RightShoulder", CFrame.Angles(a, 0, 0))
				add("Waist", CFrame.Angles(t < windup and -0.1 or 0.2, 0, 0))
				if class == "club" then
					add("LeftShoulder", CFrame.Angles(a * 0.8, 0, 0))
				end
			end
		elseif class == "spear" then
			local k = t < 0.1 and ease(t / 0.1) or 1 - ease((t - 0.1) / 0.3)
			add("RightShoulder", CFrame.Angles(-1.55 * k, 0, 0))
			add("RightElbow", CFrame.Angles(0.2 * (1 - k), 0, 0))
			add("Waist", CFrame.Angles(-0.2 * k, 0, 0))
		elseif class == "bow" then
			local k = t < 0.15 and ease(t / 0.15) or t > 0.45 and 1 - ease((t - 0.45) / 0.25) or 1
			add("LeftShoulder", CFrame.Angles(-1.55 * k, 0, 0))
			add("RightShoulder", CFrame.Angles(-1.35 * k, 0, -0.55 * k))
		end
	elseif (mode == "use") and t < 1 then
		local k = t < 0.2 and ease(t / 0.2) or t > 0.7 and 1 - ease((t - 0.7) / 0.3) or 1
		add("RightShoulder", CFrame.Angles(-1.2 * k, 0, 0.35 * k))
		add("RightElbow", CFrame.Angles(-1.2 * k, 0, 0))
		add("Neck", CFrame.Angles(-0.15 * k, 0, 0))
	elseif mode == "throw" and t < 0.7 then
		local a = t < 0.25 and 0.8 * ease(t / 0.25) or 0.8 - 3.2 * ease((t - 0.25) / 0.15)
		if t > 0.4 then
			a = -2.4 * (1 - ease((t - 0.4) / 0.3))
		end
		add("RightShoulder", CFrame.Angles(a, 0, 0))
	end
	-- sprinting: lean in
	local hum = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if hum and root then
		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if speed > 20 then
			add("Waist", CFrame.Angles(-0.18, 0, 0))
		end
		-- low on health: the chest heaves
		if hum.Health > 0 and hum.Health < hum.MaxHealth * 0.3 then
			add("Waist", CFrame.Angles(-0.1 + math.sin(clock * 6) * 0.05, 0, 0))
			add("Neck", CFrame.Angles(-0.2, 0, 0))
		end
	end
	-- a flinch
	local f = clock - rec.flinchAt
	if f < 0.3 then
		add("Waist", CFrame.Angles(0.35 * (1 - f / 0.3), 0, 0))
	end
	-- emotes
	local e = clock - rec.emoteAt
	if rec.emote and e < 3 then
		local k = e < 0.2 and ease(e / 0.2) or e > 2.6 and 1 - ease((e - 2.6) / 0.4) or 1
		local key = rec.emote
		if key == "67" then
			-- the 6-7: forearms out in front, palms up, going up and down
			local w = math.sin(clock * 15)
			add("RightShoulder", CFrame.Angles(-0.35 * k, 0, 0))
			add("LeftShoulder", CFrame.Angles(-0.35 * k, 0, 0))
			add("RightElbow", CFrame.Angles((-1.3 - w * 0.5) * k, 0, 0))
			add("LeftElbow", CFrame.Angles((-1.3 + w * 0.5) * k, 0, 0))
			add("Waist", CFrame.Angles(0, 0, math.sin(clock * 7.5) * 0.05 * k))
		elseif key == "wave" then
			add("RightShoulder", CFrame.Angles(-2.8 * k, 0, math.sin(clock * 10) * 0.4 * k))
		elseif key == "dance" then
			add("Waist", CFrame.Angles(0, math.sin(clock * 6) * 0.35 * k, math.sin(clock * 12) * 0.12 * k))
			add("RightShoulder", CFrame.Angles(math.sin(clock * 6) * 1.6 * k, 0, 0))
			add("LeftShoulder", CFrame.Angles(-math.sin(clock * 6) * 1.6 * k, 0, 0))
		end
	end
	return out
end

local function apply(character, rec, clock)
	local pose = AnimController.pose(rec, character, clock)
	for name, m in rec.motors do
		local off = pose[name]
		if m.motor.Parent then
			m.motor.C0 = off and m.base * off or m.base
		end
	end
end

function AnimController:init()
	Net.listen("Act", function(a)
		if type(a) ~= "table" or not a.by then
			return
		end
		-- your own swing already played when you pressed
		if a.by == player.UserId and a.mode == "main" and os.clock() - localSwingAt < 0.35 then
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
			localSwingAt = os.clock()
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
			end
		end
	end)
end

-- (tests)
AnimController.recs = recs

return AnimController

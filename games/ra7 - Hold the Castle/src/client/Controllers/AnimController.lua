--[[
Animation for players' characters (master plan §13: animations are a core part of the game). Roblox's own walk,
run and jump keep playing; on top of them this bends the joints by hand (each Motor6D's C0, on this client only):

  every move   a wind-up, then a clear strike (swings, pounds, rams), arms forward for shots and spells,
               a hammer rhythm for building and mining
  specials     the shield raised, a roar with arms up, the charge leaning in, spells overhead
  carrying     a full bag: arms forward, leaning under the weight
  tired        low on health: the chest heaves, the head drops
  hit          a flinch backwards
  emotes       wave, cheer, laugh, flex, dance; winners cheer at the end of a match
Nothing snaps: every offset eases in and out.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local AnimController = { Name = "AnimController", Order = 40 }

local recs = {} -- [character] = { motors = { name = { motor, base } }, swingAt, move, windup, emote, emoteAt, flinchAt, lastHealth }
local RANGE = 140

local MOTORS = { "RightShoulder", "LeftShoulder", "Waist", "Neck", "Root" }

-- How each move bends the body: a function of time since it started → offsets per joint (Angles x, y, z).
local SWING_MOVES = {
	hammer = 0.45,
	pick = 0.45,
	smash = 0.7,
	claw = 0.45,
	pound = 0.9,
	ram = 0.8,
	mine = 0.4,
	quickWall = 0.5,
	bigDig = 0.7,
}
local CAST_MOVES = {
	shoot = "bow",
	mend = "cast",
	spit = "spit",
	hex = "cast",
	volley = "bow",
	goo = "spit",
	ward = "overhead",
	dark = "overhead",
	roar = "roar",
	shieldWall = "shield",
	charge = "charge",
	bomb = "throw",
}

local function ease(t)
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

-- The pose for one character right now: { joint = CFrame offset }.
function AnimController.pose(rec, character, clock)
	local out = {}
	local function add(joint, cf)
		out[joint] = (out[joint] or CFrame.new()) * cf
	end
	local t = clock - rec.swingAt
	local move = rec.move
	if move and SWING_MOVES[move] then
		local windup = math.max(0.08, rec.windup or 0.15)
		local strike = 0.18
		local back = SWING_MOVES[move] - windup - strike
		local a
		if t < windup then
			a = -2.6 * ease(t / windup) -- lift high
		elseif t < windup + strike then
			a = -2.6 + 2.2 * ease((t - windup) / strike) -- bring it down hard
		elseif t < windup + strike + math.max(0.1, back) then
			a = -0.4 * (1 - ease((t - windup - strike) / math.max(0.1, back)))
		end
		if a then
			add("RightShoulder", CFrame.Angles(a, 0, 0))
			if move == "pound" or move == "ram" or move == "smash" then
				add("LeftShoulder", CFrame.Angles(a * 0.8, 0, 0))
				add("Waist", CFrame.Angles(t < windup and 0.15 or -0.25, 0, 0))
			end
		end
	elseif move and CAST_MOVES[move] and t < 0.9 then
		local style = CAST_MOVES[move]
		local k = t < 0.15 and ease(t / 0.15) or t > 0.6 and 1 - ease((t - 0.6) / 0.3) or 1
		if style == "bow" then
			add("LeftShoulder", CFrame.Angles(-1.5 * k, 0, 0))
			add("RightShoulder", CFrame.Angles(-1.3 * k, 0, -0.5 * k))
		elseif style == "spit" then
			add("Waist", CFrame.Angles(0.35 * k, 0, 0))
			add("Neck", CFrame.Angles(-0.4 * k, 0, 0))
		elseif style == "cast" or style == "throw" then
			add("RightShoulder", CFrame.Angles(-1.6 * k, 0, 0))
		elseif style == "overhead" or style == "roar" then
			add("RightShoulder", CFrame.Angles(-2.8 * k, 0, 0))
			add("LeftShoulder", CFrame.Angles(-2.8 * k, 0, 0))
			if style == "roar" then
				add("Neck", CFrame.Angles(0.4 * k, 0, 0))
				add("Waist", CFrame.Angles(-0.2 * k, 0, 0))
			end
		elseif style == "shield" then
			add("LeftShoulder", CFrame.Angles(-1.5 * k, 0.4 * k, 0))
		elseif style == "charge" then
			add("Waist", CFrame.Angles(0.45 * k, 0, 0))
			add("RightShoulder", CFrame.Angles(-0.6 * k, 0, 0))
			add("LeftShoulder", CFrame.Angles(-0.6 * k, 0, 0))
		end
	end
	-- carrying a full bag
	if character:GetAttribute("Heavy") then
		add("RightShoulder", CFrame.Angles(-0.5, 0, 0))
		add("LeftShoulder", CFrame.Angles(-0.5, 0, 0))
		add("Waist", CFrame.Angles(0.18, 0, 0))
	end
	-- tired: low on health
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * Constants.TIRED_AT then
		add("Waist", CFrame.Angles(0.12 + math.sin(clock * 6) * 0.06, 0, 0))
		add("Neck", CFrame.Angles(0.25, 0, 0))
	end
	-- a flinch
	local f = clock - rec.flinchAt
	if f < 0.3 then
		add("Waist", CFrame.Angles(-0.35 * (1 - f / 0.3), 0, 0))
	end
	-- emotes
	local e = clock - rec.emoteAt
	if rec.emote and e < 3 then
		local k = e < 0.2 and ease(e / 0.2) or e > 2.6 and 1 - ease((e - 2.6) / 0.4) or 1
		local key = rec.emote
		if key == "wave" then
			add("RightShoulder", CFrame.Angles(-2.8 * k, 0, math.sin(clock * 10) * 0.4 * k))
		elseif key == "cheer" or key == "win" then
			local bounce = math.sin(clock * 9) * 0.25
			add("RightShoulder", CFrame.Angles((-2.9 + bounce) * k, 0, 0))
			add("LeftShoulder", CFrame.Angles((-2.9 - bounce) * k, 0, 0))
		elseif key == "laugh" then
			add("Waist", CFrame.Angles(math.sin(clock * 18) * 0.12 * k - 0.15 * k, 0, 0))
			add("Neck", CFrame.Angles(-0.3 * k, 0, 0))
		elseif key == "flex" then
			add("RightShoulder", CFrame.Angles(0, 0, 1.4 * k) * CFrame.Angles(-0.4 * k, 0, 0))
			add("LeftShoulder", CFrame.Angles(0, 0, -1.4 * k) * CFrame.Angles(-0.4 * k, 0, 0))
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
		local c = characterOf(a.by)
		if c then
			local rec = getRec(c)
			rec.swingAt = os.clock()
			rec.move = a.move
			rec.windup = a.windup
		end
	end)
	Net.listen("Fx", function(kind, data)
		if kind == "emote" and type(data) == "table" and data.by then
			local c = characterOf(data.by)
			if c then
				local rec = getRec(c)
				rec.emote = data.key
				rec.emoteAt = os.clock()
			end
		end
	end)
	-- the winners cheer
	Net.listen("Results", function(r)
		for _, p in Players:GetPlayers() do
			local c = p.Character
			if c and c:GetAttribute("Team") == r.winner then
				local rec = getRec(c)
				rec.emote = "win"
				rec.emoteAt = os.clock()
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		if Theme.reducedMotion() then
			return
		end
		local clock = os.clock()
		local cam = workspace.CurrentCamera
		local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.new()
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

--[[
Bots, only while exactly one person is on: alone in a server you still get a real fight (BOT_ALLIES on your side,
BOT_ENEMIES against you). The moment a second person joins they take over a bot on the other side: its team, and
in a build or fight phase the very spot it stood on; every bot then leaves. If it drops back to one person, the bots
come back. With nobody on, none.

A bot is a stand-in that looks enough like a player to the rest of the server (a character, a team, attributes, a
UserId below zero), so it fights through the same code: CombatService draws and flies its arrows and checks its
hits, MatchService counts its kills, pushes the line and respawns it, the turf rule holds it. Net messages to a bot
are dropped (Net.fire), the anti-cheat ignores it, and only real players get rewards or rows in the results.

What a bot does (every TICK): in the build phase it walks to a spot on its own side; in the fight it picks the
nearest enemy it can see within BOT_RANGE, faces them, draws (after BOT_REACT for someone new), and lets go with a
lead on their movement, the drop allowed for, and BOT_SPREAD degrees of error; between shots it strafes along its
side of the line.

  BotService:List()          the bots in the server
  BotService:Ensure()        bots in or out for the number of people on (runs on its own every second)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local ArenaBuilder = require(ReplicatedStorage.Shared.World.ArenaBuilder)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local BotService = {
	Name = "BotService",
	Dependencies = { "TeamService", "CombatService", "MatchService", "ArenaService" },
}

local teams, combat, match, arenaService
local bots = {} -- the bots in the server
local nextId = 0
local folder
BotService.TICK = 0.1

-- The stand-in ------------------------------------------------------------------------------------------------
local Bot = {}
Bot.__index = Bot

local function newBot(name)
	nextId += 1
	return setmetatable({
		UserId = -nextId,
		Name = "Bot" .. name,
		DisplayName = name .. " (bot)",
		IsBot = true,
		Parent = workspace,
		Character = nil,
		_attrs = {},
		-- the brain
		target = nil,
		seenAt = 0,
		drawUntil = nil,
		goal = nil,
		goalAt = 0,
		shotId = 0,
		weapon = "bow",
	}, Bot)
end

function Bot:GetAttribute(k)
	return self._attrs[k]
end

function Bot:SetAttribute(k, v)
	self._attrs[k] = v
end

function Bot:IsFriendsWith()
	return false
end

function Bot:Kick() end

-- A plain blocky body (R15 part names, so the team dressing and the held bow find their places)
local PARTS = {
	{ "UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.5, 0) },
	{ "LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.5, 0) },
	{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.9, 0) },
	{ "LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 0.7, 0) },
	{ "LeftHand", Vector3.new(1, 0.6, 1), Vector3.new(-1.5, -0.3, 0) },
	{ "RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 0.7, 0) },
	{ "RightHand", Vector3.new(1, 0.6, 1), Vector3.new(1.5, -0.3, 0) },
	{ "LeftUpperLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -1.7, 0) },
	{ "RightUpperLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -1.7, 0) },
}

function Bot:LoadCharacter()
	if self.Character then
		self.Character:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = self.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = model
	for _, spec in PARTS do
		local p = Instance.new("Part")
		p.Name = spec[1]
		p.Size = spec[2]
		p.CFrame = root.CFrame * CFrame.new(spec[3])
		p.CanCollide = spec[1] == "UpperTorso" or spec[1] == "Head"
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
	end
	local hum = Instance.new("Humanoid")
	hum.HipHeight = 2.7
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = model
	model.PrimaryPart = root
	-- a name over its head, so nobody takes it for a person
	local tag = Instance.new("BillboardGui")
	tag.Name = "BotTag"
	tag.Size = UDim2.fromOffset(160, 22)
	tag.StudsOffset = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 90
	tag.Adornee = root
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = "🤖 " .. self.DisplayName
	l.TextScaled = true
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = Color3.fromRGB(30, 30, 34)
	l.Parent = tag
	tag.Parent = model
	model.Parent = folder
	self.Character = model
	self.target, self.drawUntil, self.goal = nil, nil, nil
	return model
end

function Bot:Remove()
	self.Parent = nil
	if self.Character then
		self.Character:Destroy()
		self.Character = nil
	end
end

-- In and out ------------------------------------------------------------------------------------------------
function BotService:List()
	return bots
end

local function humans()
	return Players:GetPlayers()
end

function BotService:RemoveAll()
	for _, b in bots do
		b:Remove()
	end
	bots = {}
end

function BotService:Add(team)
	local used = {}
	for _, b in bots do
		used[b.DisplayName] = true
	end
	local name = "Bot"
	for _, n in Constants.BOT_NAMES do
		if not used[n .. " (bot)"] then
			name = n
			break
		end
	end
	local b = newBot(name)
	teams:Set(b, team)
	table.insert(bots, b)
	local phase = match:Phase()
	if phase == "build" or phase == "fight" then
		match:Spawn(b)
	end
	return b
end

function BotService:Ensure()
	local people = humans()
	if #people == 1 then
		if #bots == 0 then
			local mine = teams:Team(people[1])
			if not mine then
				return
			end
			local other = mine == "red" and "blue" or "red"
			for _ = 1, Constants.BOT_ALLIES do
				self:Add(mine)
			end
			for _ = 1, Constants.BOT_ENEMIES do
				self:Add(other)
			end
		end
	elseif #bots > 0 then
		self:RemoveAll()
	end
end

-- The second person in: they take a bot's place (on the side against the first person), and the bots go.
function BotService:Takeover(player)
	local people = humans()
	if #people ~= 2 or #bots == 0 then
		return nil
	end
	local first = people[1] == player and people[2] or people[1]
	local firstTeam = teams:Team(first)
	local pick
	for _, b in bots do
		if b.Parent and teams:Team(b) ~= firstTeam and (not pick or (combat:Alive(b) and not combat:Alive(pick))) then
			pick = b
		end
	end
	pick = pick or bots[1]
	local team = teams:Team(pick)
	local root = pick.Character and pick.Character:FindFirstChild("HumanoidRootPart")
	local phase = match:Phase()
	teams:Set(player, team)
	if root and combat:Alive(pick) and (phase == "build" or phase == "fight") then
		match.SpawnAt[player] = root.CFrame -- (they appear where the bot stood)
	end
	self:RemoveAll()
	return team
end

-- The brain ---------------------------------------------------------------------------------------------------
local function rootOf(who)
	local c = who.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function moveTo(b, root, goal)
	local hum = b.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Constants.BOT_SPEED
	end
	local ok = hum and pcall(function()
		hum:MoveTo(goal)
	end)
	if not ok then
		-- (no physics here: step it along by hand)
		local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		local step = math.min(flat.Magnitude, Constants.BOT_SPEED * BotService.TICK)
		if step > 0.05 then
			root.CFrame = root.CFrame + flat.Unit * step
		end
	end
end

local function face(root, at)
	local look = Vector3.new(at.X, root.Position.Y, at.Z)
	if (look - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

-- The nearest enemy it can see
function BotService:Target(b, root)
	local mine = teams:Team(b)
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local best, bestD
	for _, who in match:Everyone() do
		local r = rootOf(who)
		local t = teams:Team(who)
		if who ~= b and r and t and t ~= mine and combat:Alive(who) then
			local d = (r.Position - root.Position).Magnitude
			if d <= Constants.BOT_RANGE and (not bestD or d < bestD) then
				if not combat:Blocked(eye, r.Position + Vector3.new(0, 1.2, 0)) then
					best, bestD = who, d
				end
			end
		end
	end
	return best
end

-- Where to aim: their chest, led by their movement over the flight time, raised for the drop, with some error
function BotService.aim(eye, target, velocity, speed, rng)
	local d = (target - eye).Magnitude
	local t = d / speed
	local at = target + velocity * t
	at += Vector3.new(0, 0.5 * Constants.GRAVITY * t * t, 0)
	local dir = (at - eye).Unit
	local spread = math.rad(Constants.BOT_SPREAD * (1 + d / 120))
	local r = rng or Random.new()
	local cf = CFrame.lookAt(Vector3.zero, dir)
		* CFrame.Angles((r:NextNumber() - 0.5) * 2 * spread, (r:NextNumber() - 0.5) * 2 * spread, 0)
	return cf.LookVector
end

local rng = Random.new()

function BotService:Think(b)
	local root = rootOf(b)
	if not b.Parent or not root or not combat:Alive(b) then
		return
	end
	local team = teams:Team(b)
	local phase = match:Phase()
	local line = match:Frontline()
	local fwd = Formulas.forward(team) -- (+1: toward the enemy)
	local t = os.clock()
	-- a spot on its own side, a little back from the line, somewhere along it; a new one now and then
	if not b.goal or t > b.goalAt then
		local back = phase == "fight" and rng:NextNumber(8, 20) or rng:NextNumber(14, 30)
		local gx = line - fwd * back
		local a = arenaService:Current()
		if a then
			-- (never back inside its spawn room: out in the field, in front of the room's wall)
			local outX = -fwd * (a.half - a.room.front1 - 6)
			gx = fwd > 0 and math.max(gx, outX) or math.min(gx, outX)
		end
		b.goal = Vector3.new(gx, root.Position.Y, rng:NextNumber(-34, 34))
		b.goalAt = t + rng:NextNumber(2.5, 5)
	end
	-- the next step toward it: out of the spawn room by its doors first
	local a = arenaService:Current()
	local dest = a and ArenaBuilder.route(a, team, root.Position, b.goal) or b.goal
	if phase ~= "fight" then
		combat:Draw(b, false)
		b.drawUntil = nil
		moveTo(b, root, dest)
		return
	end
	local target = self:Target(b, root)
	if target ~= b.target then
		b.target, b.seenAt = target, t
		if b.drawUntil then
			combat:Draw(b, false)
			b.drawUntil = nil
		end
	end
	if not target then
		moveTo(b, root, dest)
		return
	end
	local tr = rootOf(target)
	-- up close: the blade (run in and slash); otherwise the bow
	local blade = Weapons.get("blade")
	local close = (tr.Position - root.Position).Magnitude <= blade.range - 1
	local want = close and "blade" or "bow"
	if combat:Weapon(b) ~= want then
		combat:Equip(b, want)
		combat:Draw(b, false)
		b.drawUntil = nil
	end
	if close then
		face(root, tr.Position)
		moveTo(b, root, tr.Position)
		face(root, tr.Position)
		if t >= (b.swingAt or 0) then
			b.swingAt = t + blade.cooldown + rng:NextNumber(0.15, 0.45)
			local look = tr.Position - root.Position
			combat:Swing(b, look.Magnitude > 0.01 and look.Unit or root.CFrame.LookVector)
		end
		return
	end
	face(root, tr.Position)
	-- strafe a little while it draws
	moveTo(b, root, dest)
	face(root, tr.Position)
	local w = Weapons.get(combat:Weapon(b))
	if not b.drawUntil then
		if t - b.seenAt >= Constants.BOT_REACT then
			combat:Draw(b, true)
			b.drawUntil = t + w.draw * rng:NextNumber(0.75, 1.1)
		end
	elseif t >= b.drawUntil then
		local eye = root.Position + Vector3.new(0, 1.5, 0)
		local charge = 1
		local speed = Formulas.shot(w, charge).speed
		local dir = self.aim(eye, tr.Position + Vector3.new(0, 0.4, 0), tr.AssemblyLinearVelocity, speed, rng)
		b.shotId += 1
		combat:Shoot(b, eye, dir, b.shotId)
		b.drawUntil = nil
		b.seenAt = t - Constants.BOT_REACT + w.cooldown + rng:NextNumber(0.2, 0.7) -- (a breath before the next)
	end
end

function BotService:Init(registry)
	teams = registry.TeamService
	combat = registry.CombatService
	match = registry.MatchService
	arenaService = registry.ArenaService
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
	match.extras = function()
		local out = {}
		for _, b in bots do
			if b.Parent then
				table.insert(out, b)
			end
		end
		return out
	end
	Players.PlayerAdded:Connect(function(player)
		self:Takeover(player)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:Ensure()
		end)
	end)
end

function BotService:Start()
	local last = 0
	while true do
		task.wait(self.TICK)
		local t = os.clock()
		if t - last >= 1 then
			last = t
			self:Ensure()
		end
		for _, b in bots do
			local ok, err = pcall(self.Think, self, b)
			if not ok then
				warn("[BotService] " .. tostring(err))
			end
		end
	end
end

return BotService

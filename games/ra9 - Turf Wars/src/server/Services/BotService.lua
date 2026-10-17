--[[
Bots, only while every real person is on one side: alone in a server (or a party alone) you still get a real fight,
one bot against each of you (at least BOT_ENEMIES; BOT_ALLIES on your side). The moment someone joins on their own,
they take the bots' side, every bot leaves, and the game starts over (a fresh match, build phase first) so both sides
start even. Someone who joins with the party (or follows a friend in) goes to that side and gets one more bot to
fight. If everyone ends up on one side again, the bots come back. With nobody on, none.

A bot is a stand-in that looks enough like a player to the rest of the server (a character, a team, attributes, a
UserId below zero), so it fights through the same code: CombatService draws and flies its arrows and checks its
hits, MatchService counts its kills, pushes the line and respawns it, the turf rule holds it. Net messages to a bot
are dropped (Net.fire), the anti-cheat ignores it, and only real players get rewards or rows in the results.

What a bot does (every TICK):
  * build phase: walks to a spot on its own side near the line and builds like a person would (BuildService, the
    same rules and budget): walls and barricades facing the line first, then cover and a tower behind them.
  * fight: picks the nearest enemy it can see within BOT_RANGE and the right weapon for the distance (the blade up
    close, the crossbow at mid range, the bow far away), faces them, draws (after BOT_REACT for someone new) and
    lets go with a lead on their movement, the drop allowed for, and BOT_SPREAD degrees of error. It strafes side to
    side while it draws so it's not a still target, falls back behind cover when it's hurt (under BOT_RETREAT_HP),
    and pushes up when nobody is in sight.

  BotService:List()          the bots in the server
  BotService:Ensure()        bots in or out for the number of people on (runs on its own every second)
  BotService:SetEnabled(on)  an admin's switch for this server (a spectating admin never counts as a person)
  BotService.easyFor(who)    a hook: true and a bot aiming at them is slower and shakier (TutorialService sets it)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local ArenaBuilder = require(ReplicatedStorage.Shared.World.ArenaBuilder)
local Notify = require(script.Parent.Parent.Notify)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Admins = require(script.Parent.Parent.Admins)

local BotService = {
	Name = "BotService",
	Dependencies = { "TeamService", "CombatService", "MatchService", "ArenaService", "BuildService" },
}

local teams, combat, match, arenaService, buildService
local bots = {} -- the bots in the server
local enabled = true -- (an admin can switch them off for this server)
local nextId = 0
local folder
BotService.TICK = 0.1
BotService.RESET_ON_TAKEOVER = true -- (a real opponent joining starts the game over)

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

-- A real R15 body built from the same description every player wears (MatchService.sameBody), so a bot is exactly
-- the shape and size of a person; the hand-made block body below is only a fallback (Studio without the API, tests).
local function realRig(name)
	local desc = match and match.sameBody and match.sameBody()
	if not desc then
		return nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(model) ~= "Instance" or not model:FindFirstChild("HumanoidRootPart") then
		return nil
	end
	model.Name = name
	return model
end

function Bot:LoadCharacter()
	if self.Character then
		self.Character:Destroy()
	end
	local model = realRig(self.Name)
	if model then
		local root = model:FindFirstChild("HumanoidRootPart")
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		model.PrimaryPart = root
		self:_tag(model, root)
		model.Parent = folder
		self.Character = model
		self.target, self.drawUntil, self.goal = nil, nil, nil
		self.buildAt, self.built = nil, nil
		return model
	end
	model = Instance.new("Model")
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
	self:_tag(model, root)
	model.Parent = folder
	self.Character = model
	self.target, self.drawUntil, self.goal = nil, nil, nil
	self.buildAt, self.built = nil, nil
	return model
end

-- a name over its head, so nobody takes it for a person (and its id, so clients can find its body for a slash)
function Bot:_tag(model, root)
	model:SetAttribute("BotId", self.UserId)
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

-- The people on (a spectating admin isn't one: alone with one, you still get bots)
local function humans()
	local out = {}
	for _, p in Players:GetPlayers() do
		if not Admins.spectating(p) then
			table.insert(out, p)
		end
	end
	return out
end

-- Bots on or off for this server (an admin's switch). Off: every bot leaves and none come back.
function BotService:SetEnabled(on)
	enabled = on == true
	self:Ensure()
end

function BotService:Enabled()
	return enabled
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
	if not enabled or #people == 0 then
		if #bots > 0 then
			self:RemoveAll()
		end
		return
	end
	-- which sides real people are on: bots only while everyone is on one side (one player alone, or a party alone)
	local sides = {}
	for _, p in people do
		local t = teams:Team(p)
		if not t then
			return -- (someone still getting a team: decide next time)
		end
		sides[t] = (sides[t] or 0) + 1
	end
	local only = (sides.red and not sides.blue) and "red" or ((sides.blue and not sides.red) and "blue" or nil)
	if not only then
		if #bots > 0 then
			self:RemoveAll()
		end
		return
	end
	-- one bot against each real person on that side (at least BOT_ENEMIES), and BOT_ALLIES with them
	local other = only == "red" and "blue" or "red"
	local wantEnemies = math.max(Constants.BOT_ENEMIES, #people)
	local have = { [only] = {}, [other] = {} }
	for _, b in bots do
		local t = teams:Team(b)
		if have[t] then
			table.insert(have[t], b)
		end
	end
	for side, want in { [other] = wantEnemies, [only] = Constants.BOT_ALLIES } do
		for _ = #have[side] + 1, want do
			self:Add(side)
		end
		for i = #have[side], want + 1, -1 do
			local b = have[side][i]
			b:Remove()
			local at = table.find(bots, b)
			if at then
				table.remove(bots, at)
			end
		end
	end
end

-- Someone new against a side that only had bots to fight: they take a bot's place, and the bots go.
function BotService:Takeover(player)
	local people = humans()
	if #people < 2 or #bots == 0 or Admins.spectating(player) then
		return nil
	end
	-- (someone arriving with their party, or following a friend in, joins that friend's side: PartyService puts
	-- them there and the bots stay, one more against them)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local td = ok and type(joinData) == "table" and joinData.TeleportData or nil
	if (type(td) == "table" and td.party) or (teams.PartyTeam and teams:PartyTeam(player)) then
		return nil
	end
	-- (everyone else on one side, so far: a party, or one person)
	local firstTeam
	for _, p in people do
		if p ~= player then
			local t = teams:Team(p)
			if firstTeam and t ~= firstTeam then
				return nil
			end
			firstTeam = t
		end
	end
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
		match.SpawnAt[player] = root.CFrame -- (if no reset happens, they appear where the bot stood)
	end
	self:RemoveAll()
	-- a real opponent now: start the game over so both sides start even
	if self.RESET_ON_TAKEOVER and phase ~= "loading" then
		task.defer(function()
			match:NewMatch()
			Notify.all(`{player.DisplayName} joined! New game!`, "start", { icon = "⚔️" })
		end)
	end
	return team
end

-- The brain ---------------------------------------------------------------------------------------------------
-- Go easy on this player? (TutorialService: a new player's first match, alone with the bot)
BotService.easyFor = function(_target)
	return false
end

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

-- The nearest enemy body, seen or not (where to go looking)
function BotService:Nearest(b, root)
	local mine = teams:Team(b)
	local best, bestD
	for _, who in match:Everyone() do
		local r = rootOf(who)
		local t = teams:Team(who)
		if who ~= b and r and t and t ~= mine and combat:Alive(who) then
			local d = (r.Position - root.Position).Magnitude
			if d <= Constants.BOT_RANGE * 1.5 and (not bestD or d < bestD) then
				best, bestD = r, d
			end
		end
	end
	return best
end

-- Where to aim: their chest, led by their movement over the flight time, raised for the drop, with some error
function BotService.aim(eye, target, velocity, speed, rng, spreadTimes)
	local d = (target - eye).Magnitude
	local t = d / speed
	local at = target + velocity * t
	at += Vector3.new(0, 0.5 * Constants.GRAVITY * t * t, 0)
	local dir = (at - eye).Unit
	local spread = math.rad(Constants.BOT_SPREAD * (spreadTimes or 1) * (1 + d / 120))
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
		if phase == "build" then
			self:BuildSome(b, root, team, line, fwd, t)
		end
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
		-- nobody in sight (its own walls, or theirs, in the way): come out from cover toward the nearest enemy, along
		-- the line, to get a shot
		local near = self:Nearest(b, root)
		if near and (not b.peekAt or t > b.peekAt) then
			b.peekAt = t + rng:NextNumber(1.2, 2.2)
			b.goal =
				Vector3.new(line - fwd * rng:NextNumber(3, 7), root.Position.Y, near.Position.Z + rng:NextNumber(-6, 6))
			b.goalAt = b.peekAt
			dest = a and ArenaBuilder.route(a, team, root.Position, b.goal) or b.goal
		end
		moveTo(b, root, dest)
		return
	end
	local tr = rootOf(target)
	-- the right weapon for the distance: the blade up close, the crossbow at mid range, the bow far away
	local blade = Weapons.get("blade")
	local dist = (tr.Position - root.Position).Magnitude
	local close = dist <= blade.range - 1
	local want = close and "blade" or (dist < Constants.BOT_MID_RANGE and "crossbow" or "bow")
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
	-- hurt: fall back toward its own side, behind the nearest thing it can hide behind
	if combat:Health(b) < Constants.BOT_RETREAT_HP then
		local cover = self:Cover(root, tr, fwd)
		moveTo(b, root, a and ArenaBuilder.route(a, team, root.Position, cover) or cover)
	else
		-- strafe side to side while it draws, so it isn't a still target
		if not b.strafeAt or t > b.strafeAt then
			b.strafeDir = (b.strafeDir or 1) * -1
			b.strafeAt = t + rng:NextNumber(0.6, 1.4)
		end
		local toT = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
		local side = toT.Magnitude > 0.01 and Vector3.new(-toT.Unit.Z, 0, toT.Unit.X) or Vector3.new(0, 0, 1)
		local strafe = root.Position + side * b.strafeDir * 6
		moveTo(b, root, a and ArenaBuilder.route(a, team, root.Position, strafe) or strafe)
	end
	face(root, tr.Position)
	local w = Weapons.get(combat:Weapon(b))
	-- (a new player's first match: a slower, shakier bot, so the first win comes fast)
	local easy = self.easyFor(target) == true
	local react = Constants.BOT_REACT * (easy and Constants.TUTORIAL_BOT_REACT or 1)
	if not b.drawUntil then
		if t - b.seenAt >= react then
			combat:Draw(b, true)
			b.drawUntil = t + w.draw * rng:NextNumber(0.75, 1.1)
		end
	elseif t >= b.drawUntil then
		local eye = root.Position + Vector3.new(0, 1.5, 0)
		local charge = 1
		local speed = Formulas.shot(w, charge).speed
		local spreadTimes = easy and Constants.TUTORIAL_BOT_SPREAD or 1
		local dir =
			self.aim(eye, tr.Position + Vector3.new(0, 0.4, 0), tr.AssemblyLinearVelocity, speed, rng, spreadTimes)
		b.shotId += 1
		combat:Shoot(b, eye, dir, b.shotId)
		b.drawUntil = nil
		b.seenAt = t - Constants.BOT_REACT + w.cooldown + rng:NextNumber(0.2, 0.7) -- (a breath before the next)
	end
end

-- Somewhere to hide: the nearest standing structure (or map shape) between it and the target, on its own side,
-- stood behind; with none, just back from the line.
function BotService:Cover(root, tr, fwd)
	local best, bestD
	for _, box in arenaService:Solids() do
		local c = (box.min + box.max) / 2
		local tall = box.max.Y - math.max(box.min.Y, 0) >= 3 and box.min.Y < 3
		local mine = (c.X - match:Frontline()) * fwd < -2
		if tall and mine then
			local d = (Vector3.new(c.X, root.Position.Y, c.Z) - root.Position).Magnitude
			if d < 40 and (not bestD or d < bestD) then
				best, bestD = c, d
			end
		end
	end
	if not best then
		return root.Position - Vector3.new(fwd * 12, 0, 0)
	end
	local away = Vector3.new(best.X - tr.Position.X, 0, best.Z - tr.Position.Z)
	away = away.Magnitude > 0.01 and away.Unit or Vector3.new(-fwd, 0, 0)
	return Vector3.new(best.X, root.Position.Y, best.Z) + away * 3.5
end

-- The build phase: build like a person, through the same rules and budget. Walls and barricades facing the line
-- first, then cover and a tower behind them; a try every second or so, near where it stands.
local BUILD_PLAN = { "wall", "barricade", "wall", "cover", "tower", "cover", "barricade" }
function BotService:BuildSome(b, root, _team, line, fwd, t)
	if not buildService or (b.buildAt and t < b.buildAt) then
		return
	end
	b.buildAt = t + rng:NextNumber(0.8, 1.6)
	b.built = b.built or 0
	local key = BUILD_PLAN[(b.built % #BUILD_PLAN) + 1]
	local back = (key == "tower" or key == "cover") and rng:NextNumber(14, 22) or rng:NextNumber(5, 10)
	for _ = 1, 6 do
		local x = line - fwd * back + rng:NextNumber(-2, 2)
		local z = root.Position.Z + rng:NextNumber(-14, 14)
		local cx, cz = Formulas.cellOf(x, z)
		local ok = buildService:Place(b, key, cx, cz, 0)
		if ok then
			b.built += 1
			return true
		end
	end
	if buildService:Budget(b) < 5 then
		b.buildAt = t + 999 -- (spent: done for this phase)
	end
	return false
end

function BotService:Init(registry)
	teams = registry.TeamService
	combat = registry.CombatService
	match = registry.MatchService
	arenaService = registry.ArenaService
	buildService = registry.BuildService
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

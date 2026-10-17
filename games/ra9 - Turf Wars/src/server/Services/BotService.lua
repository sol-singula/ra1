--[[
Bots, only while every real person is on one side: alone in a server (or a party alone) you still get a real fight,
bots to fight (MIN_SIDE a side, below). The moment someone joins on their own,
they take the bots' side, every bot leaves, and the game starts over (a fresh match, build phase first) so both sides
start even. Someone who joins with the party (or follows a friend in) goes to that side and gets one more bot to
fight. If everyone ends up on one side again, the bots come back. With nobody on, none.

With BOTS_OFF_AT (4) real people or more there are no bots at all: the teams are evened among the people (within
one). Below that, bots only make up the odd person out: 3 against 2 gets one bot for the 2; even sides have none (they leave the moment
it's even again). One person alone gets one bot to fight (MIN_SIDE 1).
A newcomer goes to the smaller side and takes a bot's place.

A bot is a stand-in that looks enough like a player to the rest of the server (a character, a team, attributes, a
UserId below zero), so it fights through the same code: CombatService draws and flies its arrows and checks its
hits, MatchService counts its kills, pushes the line and respawns it, the turf rule holds it. Net messages to a bot
are dropped (Net.fire), the anti-cheat ignores it, and only real players get rewards or rows in the results.

What a bot does (every TICK):
  * build phase: walks to a spot on its own side near the line and builds like a person would (BuildService, the
    same rules and budget): walls and barricades facing the line first, then cover and a tower behind them.
  * fight: picks the nearest enemy it can see within BOT_RANGE and the right weapon for the distance (the blade up
    close, the bow further out; now and then, in BOT_TNT_RANGE, a TNT lobbed at them, or at an enemy wall in the
    way when nobody is in sight), faces them, draws (after BOT_REACT for someone new) and
    lets go with a lead on their movement, the drop allowed for, and BOT_SPREAD degrees of error. It strafes side to
    side while it draws so it's not a still target, falls back behind cover when it's hurt (under BOT_RETREAT_HP),
    and pushes up when nobody is in sight.
  * getting about (BotService:Go): every move goes through a path on the walking grid (server/BotNav: the map's
    shapes and the structures, kept on its own side of the line), straight to the farthest point of it in clear
    view, with a jump over anything low just ahead. Goals inside a solid move to the nearest free spot. A bot that
    makes no headway for STUCK_SECONDS jumps and marks what it walked into, then backs off round a detour, then
    gives up on that goal, and if it's still wedged it's put on the nearest free square.

  BotService:List()          the bots in the server
  BotService:Ensure()        bots in or out for the number of people on (runs on its own every second)
  BotService:SetEnabled(on)  an admin's switch for this server (a spectating admin never counts as a person)
  BotService.easyFor(who)    a hook: true and a bot aiming at them is slower and shakier (TutorialService sets it)
  BotService.softness(who)   -> spread, react: how much shakier and slower a bot is against them (1, 1: not at all)

Another mode's bots (Bot Brawl, BrawlService): with BotService.auto off, Ensure and the takeover do nothing and
that service adds and removes them itself: BotService:Add(team, name?) and BotService:Remove(bot). Its hooks:
BotService.unbound(bot) (true: the bot ignores the line and hunts anywhere, as in the CHARGE), BotService.handicap(bot)
-> speed, spread, react (multipliers on its walk, its aim error and its wait: the waves and the director), a bot's
own stunUntil (os.clock: it stands still till then) and tntChance (instead of BOT_TNT_CHANCE; 0: never).

Going easy: against a touch player a bot aims worse and waits longer (BOT_TOUCH_*), and with a mouse or pad player
in view too it goes for them first (a phone player counts BOT_TOUCH_TARGET times further off); against a player in
their first matches (CombatService:NewHelp) it's slower and shakier too, less each match; the tutorial's and the
first knockout's boost as before. However they stack, never past BOT_EASY_*_MAX.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local ArenaBuilder = require(ReplicatedStorage.Shared.World.ArenaBuilder)
local Notify = require(script.Parent.Parent.Notify)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)
local Admins = require(script.Parent.Parent.Admins)
local BotNav = require(script.Parent.Parent.BotNav)

local BotService = {
	Name = "BotService",
	Dependencies = { "TeamService", "CombatService", "MatchService", "ArenaService", "BuildService" },
}

local teams, combat, match, arenaService, buildService
local bots = {} -- the bots in the server
local enabled = true -- (an admin can switch them off for this server)
BotService.auto = true -- (bots come and go on their own for who's on; off: another service runs them, see the header)
local nextId = 0
local folder
BotService.TICK = 0.1
BotService.STUCK_SECONDS = 1.25 -- no headway for this long (wanting to go somewhere): stuck
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
		self.path, self.detour, self.prog, self.stuckN = nil, nil, nil, 0
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
	self.path, self.detour, self.prog, self.stuckN = nil, nil, nil, 0
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
		combat:Forget(b)
	end
	bots = {}
end

function BotService:Add(team, name)
	local used = {}
	for _, b in bots do
		used[b.DisplayName] = true
	end
	name = name or "Bot"
	for _, n in Constants.BOT_NAMES do
		if not used[n .. " (bot)"] then
			name = name == "Bot" and n or name
			break
		end
	end
	local b = newBot(name)
	teams:Set(b, team)
	table.insert(bots, b)
	local phase = match:Phase()
	if phase == "build" or phase == "fight" then
		-- (in its own thread, and a failed body never takes the bot loop down: the match's watchdog retries)
		task.spawn(function()
			local ok, err = pcall(match.Spawn, match, b)
			if not ok then
				warn("[BotService] spawn failed: " .. tostring(err))
			end
		end)
	end
	return b
end

-- One bot out (another mode's: BrawlService); it leaves the list and the arena.
function BotService:Remove(b)
	local at = table.find(bots, b)
	if at then
		table.remove(bots, at)
	end
	b:Remove()
	combat:Forget(b)
end

function BotService:Ensure()
	if not self.auto then
		return -- (another service runs the bots)
	end
	local people = humans()
	if not enabled or #people == 0 then
		if #bots > 0 then
			self:RemoveAll()
		end
		return
	end
	-- which sides real people are on: everyone on one side (one player alone, or a party alone), or uneven sides
	local sides = {}
	for _, p in people do
		local t = teams:Team(p)
		if not t then
			return -- (someone still getting a team: decide next time)
		end
		sides[t] = (sides[t] or 0) + 1
	end
	-- BOTS_OFF_AT real people or more: no bots, the people evened out instead (within one: 3 v 2 stays 3 v 2)
	if #people >= Constants.BOTS_OFF_AT then
		if #bots > 0 then
			self:RemoveAll()
		end
		local reds, blues = sides.red or 0, sides.blue or 0
		if math.abs(reds - blues) > 1 then
			self:Even()
		end
		return
	end
	-- every side at least MIN_SIDE strong and both sides even: bots make up whatever real people don't (one person
	-- alone gets a bot beside them and two against them; 3 against 2 gets one bot for the 2)
	local reds, blues = sides.red or 0, sides.blue or 0
	local target = math.max(Constants.MIN_SIDE, reds, blues)
	local want = { red = target - reds, blue = target - blues }
	if want.red == 0 and want.blue == 0 then
		if #bots > 0 then
			self:RemoveAll()
		end
		return
	end
	local have = { red = {}, blue = {} }
	local keep = {}
	for _, b in bots do
		local t = teams:Team(b)
		if b.Parent and have[t] then
			table.insert(have[t], b)
			table.insert(keep, b)
		else
			b:Remove() -- (a bot off both teams, or gone: never left standing about, never counted)
		end
	end
	bots = keep
	for side, n in want do
		for _ = #have[side] + 1, n do
			self:Add(side)
		end
		for i = #have[side], n + 1, -1 do
			local b = have[side][i]
			b:Remove()
			local at = table.find(bots, b)
			if at then
				table.remove(bots, at)
			end
		end
	end
end

-- The people evened out (no bots): solo players moved to the smaller side (TeamService:Rebalance, parties kept
-- together), each put on their new side's deck and told.
function BotService:Even()
	local moved = teams:Rebalance()
	local phase = match:Phase()
	for _, p in moved do
		if (phase == "build" or phase == "fight") and p.Parent and p.Character then
			task.spawn(function()
				pcall(match.Spawn, match, p)
			end)
		end
		Notify.to(
			p,
			`Teams evened: you're on {string.upper(teams:Team(p) or "")} now.`,
			"info",
			{ icon = "⚖️", seconds = 4 }
		)
	end
	if #moved > 0 then
		match:Broadcast()
	end
	return moved
end

-- Someone new against a side that only had bots to fight: they take a bot's place, and the bots go.
function BotService:Takeover(player)
	if not self.auto then
		return nil
	end
	if teams.Returning and teams:Returning(player) then
		return nil -- (back in the same match: their old side, no restart; Ensure evens the bots)
	end
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
-- (hooks, see the header: a bot free of the line; its speed, aim error and wait multipliers)
BotService.unbound = function(_bot)
	return false
end
BotService.handicap = function(_bot)
	return 1, 1, 1
end

local function rootOf(who)
	local c = who.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function moveTo(b, root, goal)
	b.moveGoal = goal
	local hum = b.Character:FindFirstChildOfClass("Humanoid")
	local speed = Constants.BOT_SPEED * (BotService.handicap(b) or 1)
	if hum then
		hum.WalkSpeed = speed
	end
	local ok = hum and pcall(function()
		hum:MoveTo(goal)
	end)
	if not ok then
		-- (no physics here: step it along by hand)
		local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		local step = math.min(flat.Magnitude, speed * BotService.TICK)
		if step > 0.05 then
			root.CFrame = root.CFrame + flat.Unit * step
		end
	end
end

local wander = Random.new() -- (detours)

local function flat(v)
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- The walking grid for the arena as it stands now (made again when the map or a structure changes)
local nav, navVersion
local function navNow()
	local a = arenaService:Current()
	if not a then
		return nil
	end
	if not nav or navVersion ~= arenaService.version then
		nav = BotNav.new(a, arenaService:Collide())
		navVersion = arenaService.version
	end
	return nav
end
BotService.nav = navNow

-- Go toward dest by the walking grid: kept in the field and on its own side, around whatever is in the way, with a
-- jump over low things and the stuck handling below.
function BotService:Go(b, root, dest)
	local a = arenaService:Current()
	local grid = navNow()
	if not a or not grid then
		return moveTo(b, root, dest)
	end
	local t = os.clock()
	local team = teams:Team(b)
	local fwd = Formulas.forward(team)
	local line = match:Frontline()
	local pos = root.Position
	-- (in the field, never over the line: the turf rule would only put it back; in the CHARGE the line is open, and
	-- an unbound bot is always free of it)
	local charging = match:Charging() or self.unbound(b)
	local x = dest.X
	if not charging and (x - line) * fwd > -2 then
		x = line - fwd * 2
	end
	x = math.clamp(x, -a.half + 3, a.half - 3)
	dest = Vector3.new(x, pos.Y, math.clamp(dest.Z, -a.width / 2 + 3, a.width / 2 - 3))
	dest = ArenaBuilder.route(a, team, pos, dest)
	if b.detour then
		if t < b.detourUntil and flat(b.detour - pos) > 1.5 then
			dest = b.detour
		else
			b.detour = nil
			b.path = nil
		end
	end
	local side = not charging and { line = line, fwd = fwd } or nil
	if charging then
		line = math.huge -- (the path's key: a CHARGE path isn't kept once the line closes again)
	end
	if
		not b.path
		or flat(dest - b.pathGoal) > 3
		or t > b.pathAt + 2
		or b.pathVersion ~= navVersion
		or b.pathLine ~= line
	then
		b.path = grid:Path(pos, dest, side) or false
		b.pathI, b.pathGoal, b.pathAt, b.pathVersion, b.pathLine = 1, dest, t, navVersion, line
	end
	local aim = dest
	local path = b.path
	if path then
		while b.pathI < #path and flat(path[b.pathI] - pos) < 1.5 do
			b.pathI += 1
		end
		aim = path[b.pathI]
		-- (the farthest point ahead it can walk straight to)
		for j = math.min(#path, b.pathI + 8), b.pathI + 1, -1 do
			if grid:Clear(pos, path[j]) then
				aim = path[j]
				break
			end
		end
	end
	local hum = b.Character:FindFirstChildOfClass("Humanoid")
	local toAim = Vector3.new(aim.X - pos.X, 0, aim.Z - pos.Z)
	if hum and toAim.Magnitude > 0.5 then
		local dir = toAim.Unit
		if grid:Low(pos + dir * 1.6) or grid:Low(pos + dir * 3) then
			hum.Jump = true -- (a crate, a bench, a low wall: over it)
		end
	end
	b.wantAt = dest -- (where it's really going: the tests read it)
	self:_unstick(b, root, hum, dest, aim, grid, t)
	moveTo(b, root, Vector3.new(aim.X, pos.Y, aim.Z))
end

-- No headway for STUCK_SECONDS while wanting to go somewhere: a jump each time, and step by step something more:
-- the square it walked into is marked for a few seconds and it plans again; then it backs off round a detour; then
-- it drops that goal; and if it is still wedged (inside something), it's put on the nearest free square.
function BotService:_unstick(b, root, hum, dest, aim, grid, t)
	local pos = root.Position
	local p0 = b.prog
	if not p0 or flat(pos - p0.pos) > 1.5 or flat(dest - pos) < 2.5 then
		if p0 and flat(pos - p0.pos) > 1.5 then
			b.stuckN = 0
		end
		b.prog = { pos = pos, t = t }
		return
	end
	if t - p0.t < self.STUCK_SECONDS then
		return
	end
	b.prog = { pos = pos, t = t }
	b.stuckN = (b.stuckN or 0) + 1
	b.stuckTimes = (b.stuckTimes or 0) + 1
	if hum then
		hum.Jump = true
	end
	-- (its own side of the line, except in the CHARGE, or unbound: then it may be over the line and anywhere is fair)
	local side = not (match:Charging() or self.unbound(b))
			and { line = match:Frontline(), fwd = Formulas.forward(teams:Team(b)) }
		or nil
	-- shut in (no way from here to there at all: structures went up round it), or inside something: straight to the
	-- nearest spot it can get there from
	local inside = false
	local feet = pos.Y - (hum and hum.HipHeight or 2) - root.Size.Y / 2
	for _, box in arenaService:Collide() do
		local mn, mx = box.min, box.max
		if
			pos.X > mn.X
			and pos.X < mx.X
			and pos.Z > mn.Z
			and pos.Z < mx.Z
			and mn.Y < feet + 2
			and mx.Y > feet + 0.3
		then
			inside = true
			break
		end
	end
	if inside or b.path == false then
		local spot = grid:Reach(pos, dest, side, 20)
		if spot and spot ~= pos then
			root.CFrame = CFrame.new(spot.X, 3.5, spot.Z) * root.CFrame.Rotation
			b.stuckN, b.path, b.detour = 0, nil, nil
			return
		end
	end
	local toAim = Vector3.new(aim.X - pos.X, 0, aim.Z - pos.Z)
	local dir = toAim.Magnitude > 0.1 and toAim.Unit or root.CFrame.LookVector
	if b.stuckN == 1 then
		grid:Block(pos + dir * 2, t + 5)
		b.path = nil
	elseif b.stuckN == 2 then
		-- back off, to one side: a free spot a few studs away that isn't the way it was going
		for _ = 1, 16 do
			local a = wander:NextNumber(0, math.pi * 2)
			local off = Vector3.new(math.cos(a), 0, math.sin(a))
			if off:Dot(dir) < 0.2 then
				local spot = grid:Free(pos + off * wander:NextNumber(4, 9), side)
				if spot and flat(spot - pos) > 2 and grid:Path(pos, spot, side) then
					b.detour, b.detourUntil = spot, t + 1.8
					break
				end
			end
		end
		b.path = nil
	elseif b.stuckN == 3 then
		b.goal, b.path, b.detour = nil, nil, nil
	else
		local spot = grid:Free(pos, side) or grid:Free(pos)
		if spot then
			root.CFrame = CFrame.new(spot.X, 3.5, spot.Z) * root.CFrame.Rotation
		end
		b.stuckN, b.path, b.detour = 0, nil, nil
	end
end

local function face(root, at)
	local look = Vector3.new(at.X, root.Position.Y, at.Z)
	if (look - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

-- The nearest enemy it can see (a touch player counts as further off: with a mouse or pad player in view too, the
-- bot picks them unless the phone player is a lot closer)
function BotService:Target(b, root)
	local mine = teams:Team(b)
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local best, bestD
	for _, who in match:Everyone() do
		local r = rootOf(who)
		local t = teams:Team(who)
		if who ~= b and r and t and t ~= mine and combat:Alive(who) then
			local d = (r.Position - root.Position).Magnitude
			local weighed = d * (combat:Device(who) == "touch" and Constants.BOT_TOUCH_TARGET or 1)
			if d <= Constants.BOT_RANGE and (not bestD or weighed < bestD) then
				if not combat:Blocked(eye, r.Position + Vector3.new(0, 1.2, 0)) then
					best, bestD = who, weighed
				end
			end
		end
	end
	return best
end

-- How easy to go on who: (spread, react) multipliers for its aim error and its wait before drawing. A new player's
-- first match alone with the bot (easyFor) or their wait for a first knockout: the tutorial's boost; a thumb:
-- BOT_TOUCH_*; their first matches: BOT_NEW_* by CombatService:NewHelp. They stack, up to BOT_EASY_*_MAX.
function BotService.softness(who)
	local spread, react = 1, 1
	if who == nil then
		return spread, react
	end
	if BotService.easyFor(who) == true or combat:Novice(who) then
		spread, react = Constants.TUTORIAL_BOT_SPREAD, Constants.TUTORIAL_BOT_REACT
	end
	if combat:Device(who) == "touch" then
		spread *= Constants.BOT_TOUCH_SPREAD
		react *= Constants.BOT_TOUCH_REACT
	end
	local help = combat:NewHelp(who)
	if help > 0 then
		spread *= 1 + (Constants.BOT_NEW_SPREAD - 1) * help
		react *= 1 + (Constants.BOT_NEW_REACT - 1) * help
	end
	return math.min(spread, Constants.BOT_EASY_SPREAD_MAX), math.min(react, Constants.BOT_EASY_REACT_MAX)
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
	-- stunned (Bot Brawl's no-wipe freeze): it stands where it is, the bow down
	if (b.stunUntil or 0) > t then
		combat:Draw(b, false)
		b.drawUntil, b.lob = nil, nil
		moveTo(b, root, root.Position)
		return
	end
	local free = self.unbound(b)
	-- a spot on its own side, a little back from the line, somewhere along it; a new one now and then (an unbound
	-- bot: somewhere round the nearest enemy, wherever they are)
	if not b.goal or t > b.goalAt then
		local back = phase == "fight" and rng:NextNumber(8, 20) or rng:NextNumber(14, 30)
		local gx = line - fwd * back
		local a = arenaService:Current()
		if a then
			-- (never back inside its spawn room: out in the field, in front of the room's wall)
			local outX = -fwd * (a.half - a.room.front1 - 6)
			gx = fwd > 0 and math.max(gx, outX) or math.min(gx, outX)
		end
		local wz = a and a.width / 2 - 14 or 34
		b.goal = Vector3.new(gx, root.Position.Y, rng:NextNumber(-wz, wz))
		b.goalAt = t + rng:NextNumber(2.5, 5)
		local near = free and self:Nearest(b, root)
		if near then
			b.goal = near.Position + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
			b.goalAt = t + rng:NextNumber(1.5, 3)
		end
	end
	if phase ~= "fight" then
		combat:Draw(b, false)
		b.drawUntil, b.lob = nil, nil
		self:Go(b, root, b.goal)
		if phase == "build" then
			self:BuildSome(b, root, team, line, fwd, t)
		end
		return
	end
	-- a TNT on its way up: wind it up, then lob it at the spot (Lob)
	if b.lob and self:Lob(b, root, t) then
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
		-- (an enemy wall in the way: blow it up)
		local wall = near and self:WallInWay(b, root, team)
		if wall and self:StartLob(b, root, wall, t) then
			return
		end
		if near and (not b.peekAt or t > b.peekAt) then
			b.peekAt = t + rng:NextNumber(1.2, 2.2)
			b.goal =
				Vector3.new(line - fwd * rng:NextNumber(3, 7), root.Position.Y, near.Position.Z + rng:NextNumber(-6, 6))
			if free then
				b.goal = near.Position + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)) -- (straight at them)
			end
			b.goalAt = b.peekAt
		end
		self:Go(b, root, b.goal)
		return
	end
	local tr = rootOf(target)
	-- the right weapon for the distance: the blade up close (only in the CHARGE), the bow further out, and now and
	-- then the TNT
	local blade = Weapons.get("blade")
	local dist = (tr.Position - root.Position).Magnitude
	-- (the blade only in the CHARGE, the fight's last seconds: then the bots run across the line at you)
	local charging = match:Charging()
	local close = charging and dist <= blade.range - 1
	local range = Constants.BOT_TNT_RANGE
	if
		not close
		and dist >= range[1]
		and dist <= range[2]
		and not self.easyFor(target)
		and not combat:Novice(target)
		and t >= (b.tntAt or 0)
	then
		b.tntAt = t + rng:NextNumber(2, 4) -- (whether it throws or not, it thinks again in a while)
		if rng:NextNumber() < (b.tntChance or Constants.BOT_TNT_CHANCE) and self:StartLob(b, root, tr.Position, t) then
			return
		end
	end
	local want = close and "blade" or "bow"
	if combat:Weapon(b) ~= want then
		combat:Equip(b, want)
		combat:Draw(b, false)
		b.drawUntil = nil
	end
	if close then
		face(root, tr.Position)
		self:Go(b, root, tr.Position)
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
		self:Go(b, root, cover)
	else
		-- strafe side to side while it draws, so it isn't a still target
		if not b.strafeAt or t > b.strafeAt then
			b.strafeDir = (b.strafeDir or 1) * -1
			b.strafeAt = t + rng:NextNumber(0.6, 1.4)
		end
		local toT = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z)
		local side = toT.Magnitude > 0.01 and Vector3.new(-toT.Unit.Z, 0, toT.Unit.X) or Vector3.new(0, 0, 1)
		local strafe = root.Position + side * b.strafeDir * 6
		if charging and dist < 45 then
			strafe = tr.Position + side * b.strafeDir * 3 -- (the CHARGE: in, weaving, to get the blade on them)
		end
		self:Go(b, root, strafe)
	end
	face(root, tr.Position)
	local w = Weapons.get(combat:Weapon(b))
	-- (a new player's first matches, a thumb: a slower, shakier bot; BotService.softness; and the bot's own handicap)
	local spreadTimes, reactTimes = self.softness(target)
	local _, hSpread, hReact = self.handicap(b)
	spreadTimes, reactTimes = spreadTimes * (hSpread or 1), reactTimes * (hReact or 1)
	local react = Constants.BOT_REACT * reactTimes
	if not b.drawUntil then
		if t - b.seenAt >= react then
			combat:Draw(b, true)
			b.drawUntil = t + w.draw * rng:NextNumber(0.75, 1.1)
		end
	elseif t >= b.drawUntil then
		local eye = root.Position + Vector3.new(0, 1.5, 0)
		local charge = 1
		local speed = Formulas.shot(w, charge).speed
		local dir =
			self.aim(eye, tr.Position + Vector3.new(0, 0.4, 0), tr.AssemblyLinearVelocity, speed, rng, spreadTimes)
		b.shotId += 1
		combat:Shoot(b, eye, dir, b.shotId)
		b.drawUntil = nil
		b.seenAt = t - Constants.BOT_REACT + w.cooldown + rng:NextNumber(0.2, 0.7) -- (a breath before the next)
	end
end

-- The TNT: pick it up and start winding up, for a throw at `point` (a spot on the ground or a wall). The charge is
-- picked for the distance; Lob lets go once it's wound up that far.
function BotService:StartLob(b, root, point, t)
	local w = Weapons.get("tnt")
	if not w or t < (b.tntReadyAt or 0) then
		return false
	end
	local dist = (Vector3.new(point.X, root.Position.Y, point.Z) - root.Position).Magnitude
	local want = math.sqrt(dist * Constants.TNT_GRAVITY / 0.9)
	local charge = math.clamp((want - w.speed[1]) / (w.speed[2] - w.speed[1]), w.minCharge, 1)
	combat:Equip(b, "tnt")
	combat:Draw(b, true)
	b.drawUntil = nil
	b.lob = { point = point, start = t, release = t + charge * w.draw }
	return true
end

-- A lob being wound up: face the spot, and at the charge it wanted, aim the arc onto it and let go. false when it's
-- over (the next tick goes back to the bow).
function BotService:Lob(b, root, t)
	local lob = b.lob
	local w = Weapons.get("tnt")
	if combat:Weapon(b) ~= "tnt" then
		b.lob = nil
		return false
	end
	face(root, lob.point)
	if t < lob.release then
		return true
	end
	local eye = root.Position + Vector3.new(0, 1.5, 0)
	local speed = Formulas.shot(w, Formulas.charge(w, t - lob.start)).speed
	local dir = Formulas.lobAim(eye, lob.point, speed)
	-- (a little spread, like its arrows)
	local spread = math.rad(Constants.BOT_SPREAD)
	dir = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), rng:NextNumber(-spread, spread)) * dir).Unit
	b.shotId += 1
	combat:Shoot(b, eye, dir, b.shotId)
	b.lob = nil
	b.tntReadyAt = t + w.cooldown + rng:NextNumber(2, 5)
	combat:Equip(b, "bow")
	return true
end

-- The nearest enemy structure within TNT reach, ahead of it (toward the enemy): somewhere to throw a TNT when
-- nobody is in sight
function BotService:WallInWay(b, root, team)
	if not buildService or os.clock() < (b.tntReadyAt or 0) then
		return nil
	end
	local range = Constants.BOT_TNT_RANGE
	local best, bestD
	for _, st in buildService:All() do
		if st.team ~= team and st.boxMin then
			local c = (st.boxMin + st.boxMax) / 2
			local d = (Vector3.new(c.X, root.Position.Y, c.Z) - root.Position).Magnitude
			if d >= range[1] and d <= range[2] and (not bestD or d < bestD) then
				best, bestD = Vector3.new(c.X, st.boxMin.Y + 1, c.Z), d
			end
		end
	end
	return best
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
		local ok = not self:_onBody(cx, cz, key) and buildService:Place(b, key, cx, cz, 0)
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

-- Would that piece go up on top of someone (itself, a team-mate)? A bot never builds round a body: it would be shut
-- in, or inside it.
function BotService:_onBody(cx, cz, key)
	local def = Structures.get(key)
	if not def then
		return false
	end
	local w, d = Structures.footprint(def, 0)
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
	for _, who in match:Everyone() do
		local r = rootOf(who)
		if r then
			local p = r.Position
			if p.X > mn.X - 2.5 and p.X < mx.X + 2.5 and p.Z > mn.Z - 2.5 and p.Z < mx.Z + 2.5 then
				return true
			end
		end
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
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			pcall(self.Ensure, self)
		end)
	end)
end

-- Someone's save has loaded, before they join the match: the takeover (a brand-new player off to their private
-- practice first takes nothing: BotService.away, TutorialService sets it)
BotService.away = function(_player, _profile)
	return false
end
function BotService:OnPlayerLoaded(player, profile)
	if not self.away(player, profile) then
		self:Takeover(player)
	end
end

function BotService:Start()
	local last = 0
	while true do
		task.wait(self.TICK)
		local t = os.clock()
		if t - last >= 1 then
			last = t
			-- (every second: the right bots for who's on; one error never stops it for good)
			local ok, err = pcall(self.Ensure, self)
			if not ok then
				warn("[BotService] ensure failed: " .. tostring(err))
			end
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

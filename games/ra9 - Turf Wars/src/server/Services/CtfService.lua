--[[
Capture the Flag (Constants.MODE "ctf"; MatchService's Rules.ctf runs the match round this). Each base has a FLAG:
a war banner in the team's colour on a stand (the Rally Banner's look, StructureModel "banner") at the back of the
spawn deck, between the deck's two middle piers (CTF.STAND_BACK from the end wall, so it's never in the cover, and
inside the spawn zone, where nobody can build). The rules, all the server's (positions are read every TICK, nothing
is trusted from a client):

  * Walk up to the enemy flag (PICKUP_RADIUS, on its stand or where it lies) and you carry it: it rides on your
    back for everyone to see, you're a little slower (CARRY_SPEED: the client reads the "Flag" attribute) and your
    bow stays down (CombatService.mayShoot: the blade is put in your hand; you can still swing it).
  * Bring it to your own stand while your own flag is home: a CAPTURE (the classic rule). The first side to
    CAPTURES_TO_WIN wins; the most when the fight's clock ends; a tie goes to sudden death, where the first capture
    wins (MatchService ends the match either way).
  * Knocked out (or gone) with it: it drops where you fell (on the floor, inside the field) and goes home on its own
    after FLAG_RETURN_SECONDS, unless a teammate of the flag touches it (home at once, and paid) or an enemy picks
    it up again.
  * Shards as they happen, like kills: a capture pays Shop.EARN.capture, a return Shop.EARN.flagReturn.
  * The queue: the match starts only when READY_PLAYERS players are READY (Net "Ctf" ("ready", on): the HUD's
    button; a party readies together). Until then MatchService keeps the match "waiting", everyone on their decks.
    Whoever played the last match stays ready for the next; someone new presses READY. Never a bot (BotService).

  CtfService:Flag(team)                { state = "home" | "carried" | "dropped", carrier, pos }
  CtfService:FlagPos(team)             where it is now
  CtfService:Carrying(player)          the team whose flag they carry, or nil
  CtfService:Scores()                  { red, blue }
  CtfService:Leader(capturesOnly?)     the side ahead on captures (then on knockouts), or nil
  CtfService:Ready(player, on) / :IsReady(player) / :ReadyCount()
  CtfService:PickUp(player, team) / :Drop(player) / :Return(team, by?) / :Capture(player)
  CtfService:State()                   what the clients get (Net "Ctf"; readyIds: who is READY, for the button)
  CtfService.Changed(state)            CtfService.Captured(player, team, scores)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Signal = require(ReplicatedStorage.Shared.Signal)
local StructureModel = require(ReplicatedStorage.Shared.StructureModel)
local Notify = require(script.Parent.Parent.Notify)
local Admins = require(script.Parent.Parent.Admins)

local CtfService = {
	Name = "CtfService",
	Modes = { "ctf" },
	Dependencies = {
		"PlayerDataService",
		"TeamService",
		"ArenaService",
		"CombatService",
		"BuildService",
		"EconomyService",
		"MatchService",
	},
	Changed = Signal.new("CtfService.Changed"), -- (state) a flag, a score or the queue changed
	Captured = Signal.new("CtfService.Captured"), -- (player, team, scores)
	TICK = 0.1,
}

local data, teams, arena, combat, economy, match, party
local folder -- workspace.Flags: the stands and any dropped flag
local flags = {} -- [team] = { state, carrier, since, pos, home, stand, cloth = { parts }, dropped }
local scores = { red = 0, blue = 0 }
local ready = {} -- [player] = true
local carrying = {} -- [player] = the team whose flag is on their back

local function now()
	return workspace:GetServerTimeNow()
end

local function nameOf(team)
	return Constants.TEAM_NAME[team] or string.upper(tostring(team))
end

-- Reading --------------------------------------------------------------------------------------------------------
function CtfService:Flag(team)
	local f = flags[team]
	return f and { state = f.state, carrier = f.carrier, pos = self:FlagPos(team) } or nil
end

function CtfService:FlagPos(team)
	local f = flags[team]
	if not f then
		return nil
	end
	if f.state == "carried" then
		local c = f.carrier and f.carrier.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		return r and r.Position or f.home
	elseif f.state == "dropped" then
		return f.pos
	end
	return f.home
end

function CtfService:Carrying(player)
	return carrying[player]
end

function CtfService:Scores()
	return { red = scores.red, blue = scores.blue }
end

-- The side ahead: on captures; then (unless capturesOnly) on knockouts; nil when level
function CtfService:Leader(capturesOnly)
	if scores.red ~= scores.blue then
		return scores.red > scores.blue and "red" or "blue"
	end
	if capturesOnly then
		return nil
	end
	local kills = { red = 0, blue = 0 }
	for _, p in match:Everyone() do
		local t = teams:Team(p)
		if kills[t] then
			kills[t] += match:Stats(p).kills or 0
		end
	end
	if kills.red ~= kills.blue then
		return kills.red > kills.blue and "red" or "blue"
	end
	return nil
end

function CtfService:State()
	local out = {
		ready = self:ReadyCount(),
		need = Constants.CTF.READY_PLAYERS,
		waiting = match:Phase() == "waiting",
		scores = self:Scores(),
		toWin = Constants.CTF.CAPTURES_TO_WIN,
		sudden = match:SuddenDeath() or nil,
		flags = {},
		readyIds = {},
	}
	for p in ready do
		if p.Parent then
			table.insert(out.readyIds, p.UserId)
		end
	end
	for _, team in Constants.TEAMS do
		local f = flags[team]
		out.flags[team] = {
			state = f and f.state or "home",
			carrier = f and f.carrier and f.carrier.UserId or nil,
			name = f and f.carrier and f.carrier.DisplayName or nil,
		}
	end
	return out
end

-- The state to one player (joining) or to everyone
function CtfService:Push(player)
	local state = self:State()
	if player then
		Net.fire(player, "Ctf", state)
	else
		Net.fireAll("Ctf", state)
		self.Changed:Fire(state)
	end
end

-- The queue ------------------------------------------------------------------------------------------------------
function CtfService:IsReady(player)
	return ready[player] == true
end

function CtfService:ReadyCount()
	local n = 0
	for p in ready do
		if p.Parent and not Admins.spectating(p) then
			n += 1
		end
	end
	return n
end

-- READY (or not). A party readies together: everyone in it, with whoever pressed it.
function CtfService:Ready(player, on)
	on = on ~= false
	local list = { player }
	local pt = party and party:Of(player)
	if pt then
		list = pt.members
	end
	local changed = false
	for _, m in list do
		if m.Parent and not Admins.spectating(m) and (ready[m] == true) ~= on then
			ready[m] = on or nil
			changed = true
		end
	end
	if changed then
		if match:Phase() == "waiting" then
			local n, need = self:ReadyCount(), Constants.CTF.READY_PLAYERS
			Notify.all(
				on and `{player.DisplayName} is ready ({n}/{need})` or `{player.DisplayName} is not ready ({n}/{need})`,
				"status",
				{ icon = "⚑", seconds = 2.5 }
			)
		end
		self:Push()
	end
	return ready[player] == true
end

-- The stands -----------------------------------------------------------------------------------------------------
-- Where a team's stand goes: STAND_BACK from its end wall in the middle of the deck (between the two middle piers,
-- behind the parapets' middle gap, clear of the pads); if a map's own shapes sit there, the next spot along
local function standSpot(a, team)
	local s = team == "red" and -1 or 1
	local back = Constants.CTF.STAND_BACK
	local pitch = a.room and a.room.cover and a.room.cover.pitch or 14
	local tries = { { back, 0 }, { back, pitch }, { back, -pitch }, { a.spawnDepth - 1, 0 } }
	local first
	for _, dz in tries do
		local x, z = s * (a.half - dz[1]), dz[2]
		local mn, mx = Vector3.new(x - 1.7, 0.2, z - 1.7), Vector3.new(x + 1.7, 6, z + 1.7)
		local free = true
		for _, sol in a.solids do
			if sol.part ~= a.strips[1] and Formulas.boxesOverlap(mn, mx, sol.min, sol.max) then
				free = false
				break
			end
		end
		first = first or Vector3.new(x, 0, z)
		if free then
			return Vector3.new(x, 0, z)
		end
	end
	return first
end

-- A "⚑ FLAG" tag over a part, in the team's colour (seen from across the field)
local function tag(part, team, text)
	local bb = Instance.new("BillboardGui")
	bb.Name = "FlagTag"
	bb.Size = UDim2.fromOffset(96, 24)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.MaxDistance = 400
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Constants.TEAM_COLOR[team] or Constants.WHITE
	l.TextStrokeColor3 = Constants.WHITE
	l.TextStrokeTransparency = 0.2
	l.Parent = bb
	bb.Parent = part
	return bb
end

-- The stand: the Rally Banner's parts (StructureModel "banner") on a 4-stud square, none of it solid (nothing to
-- get stuck on or shoot at), the cloth kept apart so it can go with the carrier
local function buildStand(team, spot)
	local model = Instance.new("Model")
	model.Name = "Stand_" .. team
	model:SetAttribute("Team", team)
	local mn, mx = spot - Vector3.new(2, 0, 2), spot + Vector3.new(2, 12, 2)
	local cloth = {}
	local top
	for _, spec in StructureModel.parts("banner", team, mn, mx) do
		local p = StructureModel.make(spec, team)
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		if spec.flag or spec.name == "FlagTop" or spec.name == "FlagTail" then
			table.insert(cloth, p)
		end
		if spec.name == "Finial" then
			top = p
		end
		p.Parent = model
	end
	if top then
		tag(top, team, `⚑ {nameOf(team)} FLAG`)
	end
	model.Parent = folder
	return model, cloth
end

local function showCloth(team, on)
	local f = flags[team]
	for _, p in f and f.cloth or {} do
		p.Transparency = on and 0 or 1
	end
end

-- The arena is up (a new match, or the first): the stands, both flags home
local function placeStands(a)
	folder:ClearAllChildren()
	for _, team in Constants.TEAMS do
		local spot = standSpot(a, team)
		local stand, cloth = buildStand(team, spot)
		flags[team] = {
			state = "home",
			carrier = nil,
			since = now(),
			pos = nil,
			home = spot + Vector3.new(0, 1, 0),
			stand = stand,
			cloth = cloth,
		}
	end
	carrying = {}
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Flag", nil)
	end
end

-- Carrying -------------------------------------------------------------------------------------------------------
-- The flag on a carrier's back: a pole leaning back off the torso, the cloth up it, in the flag's team colour
local function backFlag(player, team)
	local c = player.Character
	local torso = c and (c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"))
	if not torso then
		return nil
	end
	local old = c:FindFirstChild("CarriedFlag")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "CarriedFlag"
	model:SetAttribute("Team", team)
	local function part(name, size, color, offset, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = torso.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = torso, p
		weld.Parent = p
		p.Parent = model
		return p
	end
	local lean = CFrame.new(0, 0.4, 0.7) * CFrame.Angles(math.rad(-18), 0, 0)
	part("Pole", Vector3.new(0.25, 4.6, 0.25), StructureModel.color("woodDark", team), lean * CFrame.new(0, 1.6, 0))
	part("Flag", Vector3.new(2.2, 2.6, 0.12), StructureModel.color("team", team), lean * CFrame.new(0, 2.6, 0.2))
	part(
		"FlagTop",
		Vector3.new(2.3, 0.4, 0.16),
		StructureModel.color("teamDark", team),
		lean * CFrame.new(0, 3.95, 0.2)
	)
	part("Finial", Vector3.new(0.5, 0.5, 0.5), StructureModel.color("iron", team), lean * CFrame.new(0, 4.1, 0))
	model.Parent = c
	return model
end

-- A dropped flag where it lies: the pole stood up, the cloth, a glowing square in the team's colour round it
local function dropModel(team, pos)
	local model = Instance.new("Model")
	model.Name = "Dropped_" .. team
	model:SetAttribute("Team", team)
	local function part(name, size, color, cf, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = cf
		p.Parent = model
		return p
	end
	local glow = part(
		"Glow",
		Vector3.new(3.4, 0.12, 3.4),
		StructureModel.color("glow", team),
		CFrame.new(pos + Vector3.new(0, 0.06, 0)),
		Enum.Material.Neon
	)
	glow.Transparency = 0.35
	part(
		"Pole",
		Vector3.new(0.3, 5, 0.3),
		StructureModel.color("woodDark", team),
		CFrame.new(pos + Vector3.new(0, 2.5, 0))
	)
	part(
		"Flag",
		Vector3.new(2.2, 2.6, 0.12),
		StructureModel.color("team", team),
		CFrame.new(pos + Vector3.new(0, 3.4, 0.2))
	)
	local top = part(
		"Finial",
		Vector3.new(0.5, 0.5, 0.5),
		StructureModel.color("iron", team),
		CFrame.new(pos + Vector3.new(0, 5.2, 0))
	)
	tag(top, team, `⚑ {nameOf(team)} FLAG`)
	model.Parent = folder
	return model
end

-- Off a carrier's back (no drop model here: Drop and Return decide where the flag goes)
local function unload(player)
	local team = carrying[player]
	if not team then
		return nil
	end
	carrying[player] = nil
	local c = player.Character
	local back = c and c:FindFirstChild("CarriedFlag")
	if back then
		back:Destroy()
	end
	player:SetAttribute("Flag", nil)
	if c then
		c:SetAttribute("Flag", nil)
	end
	local f = flags[team]
	if f and f.carrier == player then
		f.carrier = nil
	end
	return team
end

-- Where a dropped flag lands: where they fell, kept inside the field and put on the floor (or whatever is under
-- that spot, where the engine has rays; the floor is at 0)
local function landing(pos)
	local a = arena:Current()
	local x, z = pos.X, pos.Z
	if a then
		x = math.clamp(x, -(a.half - 3), a.half - 3)
		z = math.clamp(z, -(a.width / 2 - 3), a.width / 2 - 3)
	end
	local y = 0
	pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local keep = { folder }
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(keep, p.Character)
			end
		end
		params.FilterDescendantsInstances = keep
		local hit = workspace:Raycast(Vector3.new(x, math.max(pos.Y, 0) + 2, z), Vector3.new(0, -80, 0), params)
		if hit and hit.Position.Y > 0 then
			y = hit.Position.Y
		end
	end)
	return Vector3.new(x, y, z)
end

function CtfService:PickUp(player, team)
	local f = flags[team]
	if not f or f.state == "carried" or carrying[player] or not combat:Alive(player) then
		return false
	end
	if f.dropped then
		f.dropped:Destroy()
		f.dropped = nil
	end
	f.state, f.carrier, f.since, f.pos = "carried", player, now(), nil
	showCloth(team, false)
	carrying[player] = team
	backFlag(player, team)
	player:SetAttribute("Flag", team)
	if player.Character then
		player.Character:SetAttribute("Flag", team)
	end
	-- (the bow stays down while carrying: the blade in hand instead)
	pcall(combat.Equip, combat, player, "blade")
	Net.fire(player, "Toast", "You have the flag: run home!", "good")
	Net.fireAll("Sfx", "pop")
	Notify.all(
		`{player.DisplayName} took the {nameOf(team)} flag!`,
		"status",
		{ color = Constants.TEAM_COLOR[teams:Team(player)], icon = "⚑", seconds = 3 }
	)
	self:Push()
	return true
end

-- Dropped where they are (knocked out, or gone): it lies there for FLAG_RETURN_SECONDS
function CtfService:Drop(player)
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local at = r and r.Position
	local team = unload(player)
	if not team then
		return false
	end
	local f = flags[team]
	f.state, f.since = "dropped", now()
	f.pos = landing(at or f.home)
	f.dropped = dropModel(team, f.pos)
	Notify.all(`{player.DisplayName} dropped the {nameOf(team)} flag!`, "status", { icon = "⚑", seconds = 3 })
	self:Push()
	return true
end

-- Home: on its own (the time ran out, a new match), or by a teammate's touch (paid)
function CtfService:Return(team, by)
	local f = flags[team]
	if not f or f.state == "home" then
		return false
	end
	if f.carrier then
		unload(f.carrier)
	end
	if f.dropped then
		f.dropped:Destroy()
		f.dropped = nil
	end
	f.state, f.carrier, f.since, f.pos = "home", nil, now(), nil
	showCloth(team, true)
	if by then
		local s = match:Stats(by)
		s.returns = (s.returns or 0) + 1
		pcall(economy.Add, economy, by, Shop.EARN.flagReturn, "flagReturn")
		Net.fire(by, "Toast", "Flag returned!", "good")
		Notify.all(
			`{by.DisplayName} returned the {nameOf(team)} flag!`,
			"status",
			{ color = Constants.TEAM_COLOR[team], icon = "⚑", seconds = 3 }
		)
	else
		Notify.all(`The {nameOf(team)} flag is back home`, "info", { icon = "⚑", seconds = 2.5 })
	end
	self:Push()
	return true
end

-- The carrier reached their own stand with their own flag home: a point, and the win when it's the last one
function CtfService:Capture(player)
	local mine = teams:Team(player)
	local team = carrying[player]
	if not team or not mine or team == mine or not flags[mine] or flags[mine].state ~= "home" then
		return false
	end
	unload(player)
	local f = flags[team]
	f.state, f.carrier, f.since, f.pos = "home", nil, now(), nil
	showCloth(team, true)
	scores[mine] += 1
	local s = match:Stats(player)
	s.captures = (s.captures or 0) + 1
	pcall(economy.Add, economy, player, Shop.EARN.capture, "capture")
	Net.fireAll("Alert", `{nameOf(mine)} CAPTURES!`, Constants.TEAM_COLOR[mine], 1.6)
	Net.fireAll("Sfx", "horn")
	Notify.all(
		`{player.DisplayName} captured the flag! {nameOf("red")} {scores.red} – {scores.blue} {nameOf("blue")}`,
		"status",
		{ color = Constants.TEAM_COLOR[mine], icon = "🏁", seconds = 4 }
	)
	self.Captured:Fire(player, mine, self:Scores())
	self:Push()
	-- the win: the last capture needed, or the first of sudden death
	if scores[mine] >= Constants.CTF.CAPTURES_TO_WIN or match:SuddenDeath() then
		match:Victory(mine)
	end
	return true
end

-- Every TICK in the fight: who stands on what
function CtfService:_tick()
	if match:Phase() ~= "fight" or not flags.red or not flags.blue then
		return
	end
	local t = now()
	local R = Constants.CTF.PICKUP_RADIUS
	for _, team in Constants.TEAMS do
		local f = flags[team]
		if f.state == "dropped" and t - f.since >= Constants.CTF.FLAG_RETURN_SECONDS then
			self:Return(team)
		end
	end
	for _, p in match:Everyone() do
		local mine = teams:Team(p)
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if mine and flags[mine] and r and combat:Alive(p) then
			local pos = r.Position
			local function near(at)
				return at ~= nil
					and Vector3.new(at.X - pos.X, 0, at.Z - pos.Z).Magnitude <= R
					and math.abs(at.Y - pos.Y) < 8
			end
			local enemy = Formulas.enemyOf(mine)
			if carrying[p] then
				if flags[mine].state == "home" and near(flags[mine].home) then
					self:Capture(p)
				end
			elseif flags[enemy].state ~= "carried" and near(self:FlagPos(enemy)) then
				self:PickUp(p, enemy)
			end
			if flags[mine].state == "dropped" and near(flags[mine].pos) then
				self:Return(mine, p)
			end
		end
	end
end

function CtfService:Init(registry)
	if Constants.MODE ~= "ctf" then
		return -- (another mode: nothing here runs)
	end
	data = registry.PlayerDataService
	teams = registry.TeamService
	arena = registry.ArenaService
	combat = registry.CombatService
	economy = registry.EconomyService
	match = registry.MatchService
	party = registry.PartyService -- (a party readies together; a build without parties: each for themselves)
	folder = Instance.new("Folder")
	folder.Name = "Flags"
	folder.Parent = workspace
	combat.mayShoot = function(player)
		return carrying[player] == nil
	end
	Net.on("Ctf", function(player, action, arg)
		if action == "ready" then
			self:Ready(player, arg ~= false)
		end
	end)
	arena.Loaded:Connect(function(a)
		placeStands(a)
	end)
	combat.Killed:Connect(function(victim)
		if carrying[victim] then
			self:Drop(victim)
		end
	end)
	match.PhaseChanged:Connect(function(new)
		if new == "loading" then
			-- a new match: the scores back to nothing (the flags come with the arena)
			scores = { red = 0, blue = 0 }
		end
		if new ~= "fight" then
			-- (the fight is over, or hasn't begun: both flags home, quietly)
			for _, team in Constants.TEAMS do
				local f = flags[team]
				if f and f.state ~= "home" then
					if f.carrier then
						unload(f.carrier)
					end
					if f.dropped then
						f.dropped:Destroy()
						f.dropped = nil
					end
					f.state, f.carrier, f.pos = "home", nil, nil
					showCloth(team, true)
				end
			end
		end
		self:Push()
	end)
	Players.PlayerRemoving:Connect(function(player)
		if carrying[player] then
			self:Drop(player)
		end
		ready[player] = nil
		task.defer(function()
			pcall(self.Push, self)
		end)
	end)
end

function CtfService:OnPlayerReady(player)
	if Constants.MODE ~= "ctf" then
		return
	end
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
	self:Push()
end

function CtfService:Start()
	if Constants.MODE ~= "ctf" then
		return
	end
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[CtfService] tick failed: " .. tostring(err))
		end
	end
end

return CtfService

-- The round loop:
--   waiting  fewer than 2 players: the lobby sign says so (the Range and the Duel pad still work)
--   lobby    15 s countdown in the lobby, map vote
--   round    5 minutes in the arena: everyone in the lobby goes in, latecomers jump in with PLAY
--   podium   8 s: back in the lobby, the top 3 stand on the podium
-- Scoring in a round: pops, streaks (3 / 5 / 10), revenge, the crown on the leader (pop them for a bonus), DOUBLE
-- TAP with a friend, 2x coins in the last minute. Coins and XP for every pop, the round, a win and the podium.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RoundService = {
	Name = "RoundService",
	Dependencies = { "PlayerDataService", "EconomyService", "CombatService", "LoadoutService", "TeamService" },
	state = "waiting",
	map = nil,
	endsAt = 0,
	scores = {}, -- [fighter] = { pops, deaths, streak, best, headshots }
	RoundStarted = Signal.new("RoundService.RoundStarted"), -- (map)
	RoundEnded = Signal.new("RoundService.RoundEnded"), -- (ranking, { name, key, size })
	Scored = Signal.new("RoundService.Scored"), -- (player, info) a player popped someone in a round
	Joined = Signal.new("RoundService.Joined"), -- (player)
}

local data, economy, combat, loadout, team
local registryRef
local stateEndsAt = 0
local lastKiller = {} -- [victim] = killer (for revenge)
local lastPopAt = {} -- [player] = os.clock() of their last pop (for DOUBLE TAP)
local crownHolder
local joined = {} -- [player] = true: played in this round
local scoreDirty = false
local lastMinuteSaid = false
local lastRanking = {}

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function realPlayers()
	local n = 0
	for _, p in Players:GetPlayers() do
		if data:Get(p) then
			n += 1
		end
	end
	return n
end

local function color3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Round info everyone sees ---------------------------------------------------------------------------------
function RoundService:Info()
	return {
		state = self.state,
		endsAt = self.state == "round" and self.endsAt or stateEndsAt,
		map = self.map and self.map.name or nil,
		mapKey = self.map and self.map.key or nil,
		size = self.map and self.map.size or nil,
		lastMinute = self.state == "round" and self.endsAt - serverNow() <= Constants.LAST_MINUTE,
		minPlayers = Constants.MIN_PLAYERS,
		players = realPlayers(),
	}
end

function RoundService:Broadcast()
	Net.fireAll("Round", self:Info())
	self:_drawStatus()
end

function RoundService:_drawStatus()
	local lines = WorldBuilder.layout.status
	local left = math.max(0, (self.state == "round" and self.endsAt or stateEndsAt) - serverNow())
	if self.state == "waiting" then
		local need = Constants.MIN_PLAYERS - realPlayers()
		lines[1].Text = need <= 1 and "WAITING FOR 1 MORE PLAYER" or `WAITING FOR {math.max(1, need)} PLAYERS`
		lines[2].Text = "A round starts with 2 players. Try the Range!"
	elseif self.state == "lobby" then
		lines[1].Text = "NEXT ROUND IN " .. Format.time(left)
		lines[2].Text = "Vote for the next map!"
	elseif self.state == "round" then
		lines[1].Text = `ROUND ON: {self.map and self.map.name or ""}`
		lines[2].Text = `Step on PLAY to jump in · {Format.time(left)} left`
	else
		local top = lastRanking[1]
		lines[1].Text = "ROUND OVER!"
		lines[2].Text = top and `Winner: {top.name} ({top.pops} pops)` or "Next round soon"
	end
end

-- The scoreboard of the current round, sorted.
function RoundService:Ranking()
	local list = {}
	for f, s in self.scores do
		local alive = f.robot and combat.robots[f] or (not f.robot and f.Parent ~= nil)
		if alive then
			table.insert(list, {
				fighter = f,
				name = combat.name(f),
				userId = f.robot and 0 or f.UserId,
				robot = f.robot == true,
				pops = s.pops,
				deaths = s.deaths,
				best = s.best,
				order = s.order,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.pops ~= b.pops then
			return a.pops > b.pops
		end
		if a.deaths ~= b.deaths then
			return a.deaths < b.deaths
		end
		return a.order < b.order
	end)
	return list
end

local scoreOrder = 0
function RoundService:Score(f)
	local s = self.scores[f]
	if not s then
		scoreOrder += 1
		s = { pops = 0, deaths = 0, streak = 0, best = 0, headshots = 0, order = scoreOrder }
		self.scores[f] = s
		scoreDirty = true
	end
	return s
end

local function sendScores()
	local out = {}
	for _, r in RoundService:Ranking() do
		table.insert(out, { userId = r.userId, name = r.name, pops = r.pops, deaths = r.deaths, robot = r.robot })
	end
	Net.fireAll("Score", out)
end

-- The crown goes to whoever leads the round (with at least one pop).
local function updateCrown()
	local top = RoundService:Ranking()[1]
	local holder = top and top.pops > 0 and top.fighter or nil
	if holder == crownHolder then
		return
	end
	if crownHolder and not crownHolder.robot and crownHolder.Parent then
		crownHolder:SetAttribute("Crown", nil)
	elseif crownHolder and crownHolder.robot and crownHolder.model then
		crownHolder.model:SetAttribute("Crown", nil)
	end
	crownHolder = holder
	if holder then
		if holder.robot then
			holder.model:SetAttribute("Crown", true)
		else
			holder:SetAttribute("Crown", true)
		end
	end
end

function RoundService:CrownHolder()
	return crownHolder
end

-- Spawning --------------------------------------------------------------------------------------------------
-- The spawn point farthest from every enemy that isn't popped (one of the best three, at random).
function RoundService:PickSpawn(f)
	local map = self.map
	if not map then
		return CFrame.new(WorldBuilder.layout.spawn.Position + Vector3.new(0, 3, 0))
	end
	local enemies = {}
	for _, other in combat:Fighters("arena") do
		if other ~= f and not combat.isPopped(other) then
			local r = combat.root(other)
			if r then
				table.insert(
					enemies,
					{ pos = r.Position, friend = not f.robot and not other.robot and team:AreTeam(f, other) }
				)
			end
		end
	end
	local scored = {}
	for _, sp in map.spawns do
		local nearest = math.huge
		local friendNear = false
		for _, e in enemies do
			local d = (e.pos - sp).Magnitude
			if e.friend then
				friendNear = friendNear or d < 45
			else
				nearest = math.min(nearest, d)
			end
		end
		local score = math.min(nearest, 200) + (friendNear and 12 or 0) + math.random() * 4
		table.insert(scored, { sp = sp, score = score })
	end
	table.sort(scored, function(a, b)
		return a.score > b.score
	end)
	local pick = scored[math.random(1, math.min(3, #scored))].sp
	return CFrame.lookAt(pick + Vector3.new(0, 3, 0), Vector3.new(map.center.X, pick.Y + 3, map.center.Z))
end

-- Joining and leaving ----------------------------------------------------------------------------------------
function RoundService:Join(player)
	if self.state ~= "round" or not self.map then
		Net.fire(player, "Toast", "No round on yet. It starts soon!", "info")
		return false
	end
	if combat.zone(player) == "arena" or not combat.root(player) then
		return false
	end
	combat:Release(player)
	combat.setZone(player, "arena")
	self:Score(player)
	if not joined[player] then
		joined[player] = true
		self.Joined:Fire(player)
	end
	combat:Respawn(player)
	Net.fire(player, "Round", self:Info())
	Net.fire(player, "Sfx", "start")
	if registryRef.RobotService then
		registryRef.RobotService:Balance()
	end
	return true
end

local function toLobby(player, at)
	combat:Release(player)
	combat.setZone(player, "lobby")
	local r = combat.root(player)
	if r then
		r.CFrame = at
			or CFrame.new(WorldBuilder.layout.spawn.Position + Vector3.new(math.random(-4, 4), 3, math.random(-4, 4)))
		r.AssemblyLinearVelocity = Vector3.zero
	end
end

function RoundService:Leave(player)
	if combat.zone(player) ~= "arena" then
		return false
	end
	toLobby(player)
	Net.fire(player, "Round", self:Info())
	if registryRef.RobotService then
		registryRef.RobotService:Balance()
	end
	return true
end

-- Popping in a round ----------------------------------------------------------------------------------------
function RoundService:_onPop(killer, victim, info)
	if self.state ~= "round" then
		return
	end
	local vs = self:Score(victim)
	vs.deaths += 1
	vs.streak = 0
	local victimWasCrown = victim == crownHolder and vs.pops > 0
	if not victim.robot then
		local vp = data:Get(victim)
		if vp then
			vp.stats.deaths += 1
		end
	end
	if killer and killer ~= victim then
		local ks = self:Score(killer)
		ks.pops += 1
		ks.streak += 1
		ks.best = math.max(ks.best, ks.streak)
		if info.headshot then
			ks.headshots += 1
		end
		local revenge = lastKiller[killer] == victim
		lastKiller[killer] = nil
		local popInfo = {
			headshot = info.headshot,
			streak = ks.streak,
			revenge = revenge,
			crown = victimWasCrown,
			robot = victim.robot == true,
			lastMinute = self.endsAt - serverNow() <= Constants.LAST_MINUTE,
		}
		if not killer.robot then
			self:_reward(killer, victim, popInfo)
		end
		-- streak banners
		for _, st in Constants.STREAKS do
			if ks.streak == st.at then
				Net.fireAll("Streak", combat.name(killer), st.text, color3(st.color))
				Net.fireAll("Sfx", "streak")
				if not killer.robot and st.at == 5 then
					local kp = data:Get(killer)
					if kp then
						kp.stats.streak5 += 1
					end
				end
			end
		end
		Net.fireAll("Feed", {
			killer = combat.name(killer),
			victim = combat.name(victim),
			headshot = info.headshot,
			killerColor = killer.robot and Color3.fromRGB(255, 120, 120) or loadout:NameColor(killer),
			victimColor = victim.robot and Color3.fromRGB(255, 120, 120) or loadout:NameColor(victim),
			skin = not killer.robot and loadout:SkinName(killer) or nil,
			rifle = not killer.robot and loadout:Rifle(killer).name or "Robot",
			tag = revenge and "😤 REVENGE" or (victimWasCrown and "👑 CROWN") or nil,
		})
		if not killer.robot then
			local stats = killer:FindFirstChild("leaderstats")
			if stats then
				stats.Pops.Value = ks.pops
			end
		end
	end
	lastKiller[victim] = killer
	updateCrown()
	scoreDirty = true
end

function RoundService:_reward(player, _victim, info)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local coins = Formulas.popCoins(info)
	local lines = {}
	if info.robot then
		profile.stats.robots += 1
		economy:AddXp(player, Constants.XP.robot)
	else
		profile.stats.pops += 1
		if info.headshot then
			profile.stats.headshots += 1
		end
		if info.crown then
			profile.stats.crowns += 1
			table.insert(lines, "👑 CROWN")
		end
		if info.revenge then
			table.insert(lines, "😤 REVENGE")
		end
		economy:AddXp(player, info.headshot and Constants.XP.headshot or Constants.XP.pop)
		-- TODAY'S TOP SNIPERS counts real pops
		local period = Formulas.dailyPeriod(os.time())
		if profile.dailyPops.period ~= period then
			profile.dailyPops = { period = period, pops = 0 }
		end
		profile.dailyPops.pops += 1
		-- DOUBLE TAP: a friend popped someone in the last 3 seconds
		local t = os.clock()
		for _, friend in team:Teammates(player) do
			if lastPopAt[friend] and t - lastPopAt[friend] <= Constants.DOUBLE_TAP_WINDOW then
				lastPopAt[friend] = nil
				economy:AddCoins(friend, Constants.COINS.doubleTap)
				coins += Constants.COINS.doubleTap
				table.insert(lines, "🤝 DOUBLE TAP")
				Net.fire(friend, "Alert", `🤝 DOUBLE TAP with {player.DisplayName}!`, Color3.fromRGB(120, 255, 140))
				break
			end
		end
		lastPopAt[player] = t
	end
	local s = self.scores[player]
	profile.stats.bestStreak = math.max(profile.stats.bestStreak, s and s.best or 0)
	loadout:AddMasteryPop(player)
	local got = economy:AddCoins(player, coins)
	if info.headshot then
		table.insert(lines, 1, "🎯 HEADSHOT")
	end
	if info.lastMinute then
		table.insert(lines, "⏰ 2X")
	end
	Net.fire(player, "Toast", `+{got} 💰 {table.concat(lines, " ")}`, "good")
	self.Scored:Fire(player, info)
end

-- The loop ------------------------------------------------------------------------------------------------------
function RoundService:StartLobby()
	self.state = "lobby"
	stateEndsAt = serverNow() + Constants.LOBBY_SECONDS
	if registryRef.VoteService then
		registryRef.VoteService:Open()
	end
	self:Broadcast()
end

function RoundService:StartRound(mapKey)
	if self.map then
		self.map.model:Destroy()
		self.map = nil
	end
	local vote = registryRef.VoteService and registryRef.VoteService:Winner()
	mapKey = mapKey or vote or Maps.list[math.random(1, #Maps.list)].key
	local size = MapBuilder.sizeFor(realPlayers())
	self.map = MapBuilder.build(mapKey, size, workspace:FindFirstChild("Arena") or workspace)
	self.state = "round"
	self.endsAt = serverNow() + Constants.ROUND_SECONDS
	self.scores = {}
	scoreOrder = 0
	table.clear(lastKiller)
	table.clear(joined)
	crownHolder = nil
	lastMinuteSaid = false
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Crown", nil)
		local stats = p:FindFirstChild("leaderstats")
		if stats then
			stats.Pops.Value = 0
		end
	end
	-- everyone in the lobby or on the range goes in (not duellers)
	local callouts = {}
	for _, p in Players:GetPlayers() do
		local z = combat.zone(p)
		if (z == "lobby" or z == "range") and data:Get(p) and combat.root(p) then
			combat:Release(p)
			combat.setZone(p, "arena")
			self:Score(p)
			joined[p] = true
			combat:Respawn(p)
			self.Joined:Fire(p)
			local profile = data:Get(p)
			if profile.callout then
				profile.callout = nil
				table.insert(callouts, p.DisplayName)
			end
		end
	end
	if registryRef.RobotService then
		registryRef.RobotService:Balance()
	end
	self:Broadcast()
	Net.fireAll("Sfx", "start")
	Net.fireAll("Alert", `🎯 {self.map.name}! Most pops in 5 minutes wins!`, Color3.fromRGB(255, 200, 40))
	for _, name in callouts do
		Net.fireAll("Announce", `🔥 {name} IS HERE TO WIN!`, Color3.fromRGB(255, 215, 60))
	end
	sendScores()
	self.RoundStarted:Fire(self.map)
end

function RoundService:EndRound()
	if self.state ~= "round" then
		return
	end
	local ranking = self:Ranking()
	lastRanking = ranking
	local mapInfo = self.map and { name = self.map.name, key = self.map.key, size = self.map.size }
	-- rewards: a round for everyone who played, the win and the podium for the top real players
	local podium = {}
	for _, r in ranking do
		if not r.robot and #podium < 3 and r.pops > 0 then
			table.insert(podium, r)
		end
	end
	for p in joined do
		local profile = p.Parent and data:Get(p)
		if profile then
			profile.stats.rounds += 1
			profile.firstRoundDone = true
			economy:AddCoins(p, Constants.COINS.round)
			economy:AddXp(p, Constants.XP.round)
		end
	end
	for i, r in podium do
		local p = r.fighter
		local profile = data:Get(p)
		if profile then
			profile.stats.podiums += 1
			local coins = economy:AddCoins(p, Constants.COINS.podium[i])
			economy:AddXp(p, Constants.XP.podium)
			if i == 1 then
				profile.stats.wins += 1
				economy:AddXp(p, Constants.XP.win)
				Net.fire(p, "Alert", `🏆 YOU WON! +{coins} coins`, Color3.fromRGB(255, 215, 60))
				Net.fire(p, "Sfx", "win")
			else
				Net.fire(p, "Alert", `🏅 #{i}! +{coins} coins`, Color3.fromRGB(210, 215, 230))
			end
		end
	end
	if registryRef.RobotService then
		registryRef.RobotService:Clear()
	end
	-- everyone back to the lobby; the podium players on their steps
	local spots = WorldBuilder.layout.podium.spots
	local onPodium = {}
	for i, r in podium do
		onPodium[r.fighter] = i
	end
	for _, p in Players:GetPlayers() do
		if combat.zone(p) == "arena" then
			local i = onPodium[p]
			if i then
				local s = spots[i]
				toLobby(p, CFrame.lookAt(s + Vector3.new(0, 3, 0), s + Vector3.new(0, 3, 10)))
			else
				toLobby(p, CFrame.new(math.random(-12, 12), 3, -28 + math.random(-4, 4)))
			end
		end
		p:SetAttribute("Crown", nil)
	end
	for i, l in WorldBuilder.layout.podium.names do
		local r = podium[i]
		l[1].Text = r and r.name or ""
		l[2].Text = r and `{r.pops} pops` or ""
	end
	local list = {}
	for i, r in podium do
		table.insert(list, { name = r.name, userId = r.userId, pops = r.pops, rank = i })
		if not r.robot then
			self:_playEmote(r.fighter)
		end
	end
	crownHolder = nil
	self.state = "podium"
	stateEndsAt = serverNow() + Constants.PODIUM_SECONDS
	Net.fireAll("Podium", list)
	self:Broadcast()
	if self.map then
		self.map.model:Destroy()
		self.map = nil
	end
	self.RoundEnded:Fire(ranking, mapInfo)
end

function RoundService:LastRanking()
	return lastRanking
end

-- The podium emote (Roblox's own emote animations; the animation replicates from the server).
function RoundService:_playEmote(player)
	local emote = loadout:Emote(player)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator or not emote then
		return
	end
	pcall(function()
		local anim = Instance.new("Animation")
		anim.AnimationId = emote.anim
		local track = animator:LoadAnimation(anim)
		track:Play()
		task.delay(Constants.PODIUM_SECONDS, function()
			track:Stop()
		end)
	end)
end

function RoundService:_step()
	local now = serverNow()
	local n = realPlayers()
	if self.state == "waiting" then
		if n >= Constants.MIN_PLAYERS then
			self:StartLobby()
		end
	elseif self.state == "lobby" then
		if n < Constants.MIN_PLAYERS then
			self.state = "waiting"
			self:Broadcast()
		elseif now >= stateEndsAt then
			self:StartRound()
		end
	elseif self.state == "round" then
		if now >= self.endsAt or n < Constants.MIN_PLAYERS then
			self:EndRound()
			return
		end
		if not lastMinuteSaid and self.endsAt - now <= Constants.LAST_MINUTE then
			lastMinuteSaid = true
			Net.fireAll("Announce", "⏰ LAST MINUTE! 2X COINS!", Color3.fromRGB(255, 140, 30))
			self:Broadcast()
		end
		-- PLAY pad
		local playPad = WorldBuilder.layout.playPad
		for _, p in Players:GetPlayers() do
			local r = combat.root(p)
			if r and combat.zone(p) == "lobby" and WorldBuilder.onPad(playPad, r.Position) then
				self:Join(p)
			end
		end
	elseif self.state == "podium" then
		if now >= stateEndsAt then
			if n >= Constants.MIN_PLAYERS then
				self:StartLobby()
			else
				self.state = "waiting"
				self:Broadcast()
			end
		end
	end
	if scoreDirty then
		scoreDirty = false
		sendScores()
	end
end

function RoundService:Init(registry)
	registryRef = registry
	data = registry.PlayerDataService
	economy = registry.EconomyService
	combat = registry.CombatService
	loadout = registry.LoadoutService
	team = registry.TeamService
	combat.zones.arena = {
		geometry = function()
			return self.map and { self.map.model } or {}
		end,
		spawn = function(f)
			return self:PickSpawn(f)
		end,
		onPop = function(killer, victim, info)
			self:_onPop(killer, victim, info)
		end,
		fallY = function()
			return (self.map and self.map.floorY or 0) + Constants.FALL_Y
		end,
	}
	Net.on("Play", function(player)
		self:Join(player)
	end)
	Net.on("Leave", function(player)
		self:Leave(player)
	end)
	data.ClientReady:Connect(function(player)
		Net.fire(player, "Round", self:Info())
		sendScores()
	end)
end

function RoundService:Start()
	local acc, statusAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		statusAcc += dt
		if acc >= 0.2 then
			acc = 0
			self:_step()
		end
		if statusAcc >= 1 then
			statusAcc = 0
			self:_drawStatus()
		end
	end)
	self:_drawStatus()
end

function RoundService:OnPlayerReady(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			-- a fresh character (reset or died some other way) starts in the lobby, or back in the round
			if not player.Parent then
				return
			end
			local z = combat.zone(player)
			local duel = registryRef.DuelService and registryRef.DuelService.duel
			combat:Release(player)
			local backIn = (z == "arena" and self.state == "round") or (z == "duel" and duel and duel.score[player])
			if backIn then
				combat:Respawn(player)
			else
				combat.setZone(player, "lobby")
			end
		end)
	end)
	self:Broadcast()
end

function RoundService:OnPlayerLeaving(player)
	joined[player] = nil
	lastKiller[player] = nil
	lastPopAt[player] = nil
	if crownHolder == player then
		crownHolder = nil
	end
	task.defer(function()
		self:Broadcast()
	end)
end

return RoundService

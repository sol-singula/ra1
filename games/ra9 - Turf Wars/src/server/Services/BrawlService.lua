--[[
Bot Brawl (Constants.BRAWL; this place runs with Constants.MODE "brawl"): co-op. Everyone who joins the server is on
the human side ("red", shown as GREEN; TeamService.fixedSide), never on the bots' ("blue", SHADOW), and a late
joiner drops straight in. Waves of bots come from the far deck and hunt across the field (BotService.unbound: no
line for them); the humans build anywhere on their own half (the frontline stays at 0, BuildService's rule as it is)
and roam wherever (MatchService.rules.turf off). Kills never move the line (rules.push off); a person down is back in
RESPAWN seconds at their deck or their Rally Banner; a bot down is gone (rules.respawn: false for a bot). The run
only ends when the server empties, or as a victory after LAST_WAVE: MatchService:Victory("red") pays the match and
loads the next map, and the run starts again at wave 1 (so does an empty server's, when someone comes).

The match's phases carry the sets: "build" (BUILD_SECONDS, from MatchService.rules.phaseSeconds) before each set of
SET_WAVES waves, then one long "fight" that BrawlService ends itself (MatchService:SkipTo("build")) when the set is
cleared. Inside the fight: a wave (WAVE_SECONDS, BOTS_BASE + N bots stepping off the deck one every SPAWN_GAP, never
more than the alive cap at once), a breather (BREATHER_SECONDS) once the whole wave is down, the next wave. A wave
still up WAVE_GRACE after its clock falls back and counts as cleared: the humans always get there. Every BOSS_EVERY
waves the first bot out is a BOSS: bigger, a crown and a bar over its head, BOSS_HITS hits to knock out (CombatService
reads its "Hits" attribute); from TNT_FROM_WAVE on, every TNT_EVERYth bot lobs TNT. Each wave cleared is a win moment:
"WAVE N CLEAR!", a short burst of the grand fireworks on every client (Net "Brawl" clear: BrawlController), Shards
to everyone (SHARDS_WAVE + SHARDS_PER_WAVE x N, "wave"; a boss down pays SHARDS_BOSS more, "boss"), the best wave kept
for the server (workspace "BrawlBest") and in each player's save (stats.brawlBest: the "brawl" leaderboard).

The director (Director) keeps it winnable, a fight all the same: bots get a little faster and sharper each wave
(RAMP_*, to the caps), but over the last DIRECTOR_WINDOW seconds, people going down more than bots (or DOWN_STREAK
downs in a row) makes the bots EASY_SLOPPY sloppy and EASY_SPAWN slow to come, and people cruising (KILLS_CRUISE
knockouts, none taken) makes them PRESS_* sharper; a wave past its clock goes sloppier still. The last bot standing is
called ("LAST ONE!"), and with the whole human side down at once the bots freeze for STUN_SECONDS (a bot's stunUntil)
so nobody wipes.

  BrawlService:Wave() / :State()        the wave on now; "idle" | "build" | "wave" | "breather" | "over"
  BrawlService:Snapshot()               what the clients get (Net "Brawl" state)
  BrawlService:Director() -> speed, sharp, spawn, mood   the multipliers on the bots now (sharp: on the aim error and
                                        the wait; spawn: on the gap); mood "easy" | "normal" | "press"
  BrawlService:Note(kind)               the director's log: "kill" (a bot down by a person) | "death" (a person down)
  BrawlService:Bots()                   { [bot] = { wave, boss, tnt } } the bots of this wave
  BrawlService:Best()                   the best wave cleared in this server
  BrawlService:_jumpTo(wave)            (tests) the next wave to come is this one
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.Notify)
local Signal = require(ReplicatedStorage.Shared.Signal)

local BrawlService = {
	Name = "BrawlService",
	Modes = { "brawl" },
	Dependencies = {
		"PlayerDataService",
		"TeamService",
		"MatchService",
		"BotService",
		"CombatService",
		"BuildService",
		"ArenaService",
		"EconomyService",
	},
	WaveStarted = Signal.new("BrawlService.WaveStarted"), -- (wave, total, boss)
	WaveCleared = Signal.new("BrawlService.WaveCleared"), -- (wave, retreated)
}

local B = Constants.BRAWL
local data, teams, match, botService, combat, arena, economy
local wave = 0 -- the wave on now (0: none yet this run)
local state = "idle"
local ends = 0 -- when the wave's clock, or the breather, runs out
local total, toSpawn = 0, 0 -- this wave's size, and how many are still to step off the deck
local nextSpawnAt = 0
local waveBots = {} -- [bot] = { wave, boss, tnt }
local boss -- the wave's boss bot while it stands
local events = {} -- { t, kind } the director's window
local downStreak = 0 -- people down in a row without a bot down
local stunnedAt = -math.huge
local lastOneSaid = false
local best = 0
local tuning = { 1, 1, 1 } -- speed, spread, react for every bot right now (Director, each tick)
local fightReady = false -- a fresh fight phase began: the set may start
local setStartAt = 0 -- (or, failing that, the wave starts at this time anyway)
local sentKey -- (the last state the clients got, so it only goes when something changed)
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

function BrawlService:Wave()
	return wave
end

function BrawlService:State()
	return state
end

function BrawlService:Bots()
	return waveBots
end

function BrawlService:Best()
	return best
end

-- The people in the match (no spectating admin, nobody in the AFK room)
local function people()
	return match:People()
end

-- How many bots may stand at once: fewer with few people on
local function aliveCap()
	return math.min(B.ALIVE_CAP, B.ALIVE_MIN + B.ALIVE_PER_PLAYER * #people())
end

local function waveSize(n)
	return B.BOTS_BASE + n
end

local function isBossWave(n)
	return n % B.BOSS_EVERY == 0
end

local function aliveBots()
	local n = 0
	for b in waveBots do
		if b.Parent and combat:Alive(b) then
			n += 1
		end
	end
	return n
end

local function anyoneUp()
	for _, p in people() do
		if combat:Alive(p) then
			return true
		end
	end
	return false
end

function BrawlService:Snapshot()
	return {
		kind = "state",
		wave = wave,
		state = state,
		ends = ends,
		alive = aliveBots(),
		left = aliveBots() + toSpawn,
		total = total,
		boss = boss and boss.Parent and combat:Alive(boss) and {
			hits = boss:GetAttribute("Hits") or 0,
			max = B.BOSS_HITS,
		} or nil,
		best = best,
		last = B.LAST_WAVE,
		set = B.SET_WAVES,
	}
end

local function send(player)
	local snap = BrawlService:Snapshot()
	if player then
		Net.fire(player, "Brawl", snap)
		return
	end
	local key = `{snap.wave}:{snap.state}:{snap.ends}:{snap.alive}:{snap.left}:{snap.boss and snap.boss.hits or "-"}`
	if key ~= sentKey then
		sentKey = key
		Net.fireAll("Brawl", snap)
	end
end

-- The director ----------------------------------------------------------------------------------------------------
function BrawlService:Note(kind)
	table.insert(events, { t = now(), kind = kind })
	if kind == "kill" then
		downStreak = 0
	elseif kind == "death" then
		downStreak += 1
	end
end

function BrawlService:Director()
	local t = now()
	while #events > 0 and t - events[1].t > B.DIRECTOR_WINDOW do
		table.remove(events, 1)
	end
	local kills, deaths = 0, 0
	for _, e in events do
		if e.kind == "kill" then
			kills += 1
		else
			deaths += 1
		end
	end
	local ramp = math.max(0, wave - 1)
	local speed = math.min(1 + B.RAMP_SPEED * ramp, B.RAMP_SPEED_MAX)
	local sharp = math.max(1 - B.RAMP_SHARP * ramp, B.RAMP_SHARP_MIN)
	local spawn, mood = 1, "normal"
	if (deaths > kills and deaths >= 2) or downStreak >= B.DOWN_STREAK then
		speed *= B.EASY_SPEED
		sharp *= B.EASY_SLOPPY
		spawn *= B.EASY_SPAWN
		mood = "easy"
	elseif kills >= B.KILLS_CRUISE and deaths == 0 then
		speed *= B.PRESS_SPEED
		sharp *= B.PRESS_SHARP
		mood = "press"
	end
	if state == "wave" and t > ends then
		sharp *= 1.3 -- (past the wave's clock: the clutch, the bots fumble a little more)
	end
	return speed, sharp, spawn, mood
end

-- The waves ------------------------------------------------------------------------------------------------------
-- A crown and a bar over the boss, and a bigger body (where the engine scales one)
local function dressBoss(b)
	local c = b.Character
	if not c then
		return
	end
	pcall(function()
		c:ScaleTo(B.BOSS_SCALE)
	end)
	local tag = c:FindFirstChild("BotTag")
	local l = tag and tag:FindFirstChildOfClass("TextLabel")
	if l then
		l.Text = "👑 BOSS"
		l.TextColor3 = Color3.fromRGB(240, 160, 20)
	end
	if tag then
		tag.Size = UDim2.fromOffset(160, 36)
		tag.StudsOffset = Vector3.new(0, 4.6, 0)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, 0)
		bar.Size = UDim2.new(0.8, 0, 0, 8)
		bar.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
		bar.BorderSizePixel = 0
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(1, 1)
		fill.BackgroundColor3 = Color3.fromRGB(240, 160, 20)
		fill.BorderSizePixel = 0
		fill.Parent = bar
		bar.Parent = tag
	end
end

local function paintBoss(b)
	local c = b.Character
	local tag = c and c:FindFirstChild("BotTag")
	local bar = tag and tag:FindFirstChild("Bar")
	local fill = bar and bar:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.fromScale(math.clamp((b:GetAttribute("Hits") or 0) / B.BOSS_HITS, 0, 1), 1)
	end
end

local function spawnOne()
	local index = total - toSpawn + 1
	local isBoss = isBossWave(wave) and index == 1
	local isTnt = not isBoss and wave >= B.TNT_FROM_WAVE and index % B.TNT_EVERY == 0
	local b = botService:Add("blue", isBoss and "Boss" or (isTnt and "Boomer" or nil))
	b.tntChance = isTnt and B.TNT_CHANCE or 0
	b.stunUntil = nil
	if isBoss then
		b:SetAttribute("Hits", B.BOSS_HITS)
		b:SetAttribute("HitsMax", B.BOSS_HITS)
		boss = b
		dressBoss(b)
	end
	waveBots[b] = { wave = wave, boss = isBoss, tnt = isTnt }
	toSpawn -= 1
	return b
end

local function removeBot(b)
	waveBots[b] = nil
	if boss == b then
		boss = nil
	end
	botService:Remove(b)
	match:Leave(b)
end

local function removeAll()
	for b in waveBots do
		removeBot(b)
	end
	waveBots, boss = {}, nil
	botService:RemoveAll()
end

local function startWave(n)
	wave = n
	total = waveSize(n)
	toSpawn = total
	boss = nil
	lastOneSaid = false
	ends = now() + B.WAVE_SECONDS
	nextSpawnAt = 0
	state = "wave"
	local bossWave = isBossWave(n)
	Net.fireAll("Alert", bossWave and `BOSS WAVE {n}` or `WAVE {n}`, Color3.fromRGB(30, 30, 34), 1.8)
	Net.fireAll("Sfx", "horn")
	if bossWave then
		Notify.all(`Wave {n}: a BOSS is coming. It takes {B.BOSS_HITS} hits!`, "start", { icon = "👑", seconds = 4 })
	end
	send()
	BrawlService.WaveStarted:Fire(n, total, bossWave)
end

-- The wave is down (or fell back): the win moment, the Shards, the best wave, and what comes next
local function clearWave(retreated)
	local cleared = wave
	local hadBoss = isBossWave(cleared)
	removeAll()
	best = math.max(best, cleared)
	workspace:SetAttribute("BrawlBest", best)
	local shards = B.SHARDS_WAVE + B.SHARDS_PER_WAVE * cleared
	for _, p in people() do
		local profile = data:Get(p)
		if profile and profile.stats then
			profile.stats.brawlBest = math.max(profile.stats.brawlBest or 0, cleared)
			profile.stats.brawlWaves = (profile.stats.brawlWaves or 0) + 1
		end
		pcall(economy.Add, economy, p, shards, "wave")
	end
	local a = arena:Current()
	Net.fireAll("Brawl", {
		kind = "clear",
		wave = cleared,
		shards = shards,
		best = best,
		boss = hadBoss or nil,
		retreated = retreated or nil,
		center = Vector3.new(a and -a.half / 2 or -50, 0, 0),
		seconds = B.FIREWORKS_SECONDS,
	})
	Net.fireAll("Alert", `WAVE {cleared} CLEAR!`, Constants.TEAM_COLOR.red, 2.2)
	Net.fireAll("Sfx", "win")
	BrawlService.WaveCleared:Fire(cleared, retreated == true)
	if cleared >= B.LAST_WAVE then
		-- the run's victory: the results, the fireworks, the next map (MatchService), then wave 1 again
		state = "over"
		Notify.all(`All {B.LAST_WAVE} waves held! GREEN wins the run!`, "win", { color = Constants.TEAM_COLOR.red })
		task.defer(function()
			match:Victory("red")
		end)
	elseif cleared % B.SET_WAVES == 0 then
		-- the set's over: a build phase before the next (MatchService ends the fight)
		state = "build"
		setStartAt = now() + 3
		Notify.all(`Set cleared! Build up before wave {cleared + 1}.`, "status", { icon = "🧱", seconds = 4 })
		task.defer(function()
			match:SkipTo("build")
		end)
	else
		state = "breather"
		ends = now() + B.BREATHER_SECONDS
		Notify.all(`Wave {cleared} clear! Next one in {B.BREATHER_SECONDS} s.`, "status", { icon = "✅", seconds = 3 })
	end
	send()
end

-- Everyone on the human side is down at once: the bots freeze, so the side gets back up
local function stun()
	stunnedAt = now()
	local untilT = os.clock() + B.STUN_SECONDS
	for b in waveBots do
		b.stunUntil = untilT
	end
	Net.fireAll("Brawl", { kind = "stun", seconds = B.STUN_SECONDS })
	Net.fireAll("Alert", "HOLD ON!", Constants.TEAM_COLOR.red, 1.5)
	Notify.all(`Everyone's down! The bots freeze for {B.STUN_SECONDS} s: get back up!`, "status", { icon = "🛡️" })
end

local function onKilled(victim, killer)
	if waveBots[victim] then
		local entry = waveBots[victim]
		if typeof(killer) == "Instance" then
			BrawlService:Note("kill")
		end
		if entry.boss then
			local pay = B.SHARDS_BOSS
			for _, p in people() do
				pcall(economy.Add, economy, p, pay, "boss")
			end
			Net.fireAll("Alert", "BOSS DOWN!", Color3.fromRGB(240, 160, 20), 1.8)
			boss = nil
		end
		-- (the body stays a moment for the kill effect, then goes; the match never respawns a bot: rules.respawn)
		task.delay(0.8, function()
			if waveBots[victim] then
				removeBot(victim)
				send()
			end
		end)
		local left = aliveBots() + toSpawn
		if left == 1 and not lastOneSaid then
			lastOneSaid = true
			Net.fireAll("Brawl", { kind = "last" })
			Net.fireAll("Alert", "LAST ONE!", Constants.TEAM_COLOR.red, 1.4)
		elseif left <= 0 and state == "wave" then
			clearWave(false)
		end
		send()
	elseif teams:Team(victim) == "red" then
		BrawlService:Note("death")
		if state == "wave" and aliveBots() > 0 and not anyoneUp() and now() - stunnedAt > B.STUN_GAP then
			stun()
		end
	end
end

-- A run from the top: wave 1 after the build phase (a new match started: the first, after the victory, an admin's)
local function onStarted()
	removeAll()
	wave, total, toSpawn = 0, 0, 0
	events, downStreak = {}, 0
	lastOneSaid = false
	state = #people() > 0 and "build" or "idle"
	fightReady, setStartAt = false, math.huge
	sentKey = nil
	send()
end

function BrawlService:_jumpTo(n)
	wave = math.max(0, n - 1)
end

function BrawlService:_tick()
	local t = now()
	local ppl = people()
	if #ppl == 0 then
		-- nobody on: the bots go, and the run starts over when someone comes
		if state ~= "idle" then
			removeAll()
			state = "idle"
			send()
		end
		return
	end
	if state == "idle" then
		-- someone's here: a fresh run on a new map (the build phase first)
		state = "build"
		match:NewMatch(Maps.next(match:MapKey(), function(a, b)
			return random:NextInteger(a, b)
		end).key)
		return
	end
	local phase = match:Phase()
	if state == "over" then
		return -- (the victory's wait: MatchService brings the next match, and Started resets us)
	end
	if phase ~= "fight" then
		-- (the build phase, or the fight ended under us: an admin's skip, the clock) no bots about
		if state ~= "build" then
			removeAll()
			state = "build"
			send()
		end
		return
	end
	tuning = { self:Director() }
	if state == "build" then
		-- the fight's on: the set starts (on a fresh fight phase, or a little after the set was cleared when the
		-- match couldn't be sent back to a build phase: an admin holding the clock)
		if fightReady or t >= setStartAt then
			fightReady = false
			startWave(wave + 1)
		end
		return
	end
	if state == "breather" then
		if t >= ends then
			startWave(wave + 1)
		end
		send()
		return
	end
	-- a wave: bots step off the deck one by one, up to the cap; past its clock and the grace, it falls back
	if toSpawn > 0 and aliveBots() < aliveCap() and t >= nextSpawnAt then
		local ok, err = pcall(spawnOne)
		if not ok then
			warn("[BrawlService] spawn failed: " .. tostring(err))
			toSpawn -= 1
		end
		nextSpawnAt = t + B.SPAWN_GAP * (tuning[3] or 1)
	end
	if toSpawn <= 0 and aliveBots() == 0 then
		clearWave(false)
	elseif t >= ends + B.WAVE_GRACE then
		Notify.all("The rest of the wave falls back!", "status", { icon = "🏃", seconds = 3 })
		clearWave(true)
	elseif aliveBots() > 0 and not anyoneUp() and t - stunnedAt > B.STUN_GAP then
		stun()
	end
	send()
end

function BrawlService:Init(registry)
	data = registry.PlayerDataService
	teams = registry.TeamService
	match = registry.MatchService
	botService = registry.BotService
	combat = registry.CombatService
	arena = registry.ArenaService
	economy = registry.EconomyService
	-- the rules: no line to push or to keep off, our own words, our phases, bots down for good
	match.rules.push = false
	match.rules.turf = false
	match.rules.tips = false
	match.rules.phaseSeconds = function(phase)
		if phase == "build" then
			return B.BUILD_SECONDS
		end
		return B.SET_WAVES * (B.WAVE_SECONDS + B.WAVE_GRACE + B.BREATHER_SECONDS) + 10
	end
	match.rules.respawn = function(victim, _wait)
		if victim.IsBot then
			return false
		end
		return B.RESPAWN
	end
	-- every person on the human side, every bot on the other
	teams.fixedSide = function(who)
		return (who and who.IsBot) and "blue" or "red"
	end
	-- the bots are ours: they hunt across the field, with the director's handicap
	botService.auto = false
	botService.unbound = function(_bot)
		return true
	end
	botService.handicap = function(_bot)
		return tuning[1], tuning[2], tuning[2]
	end
	-- the "brawl" board: the best wave (LeaderboardService's boards, when it's here)
	local leaderboard = registry.LeaderboardService
	if leaderboard and leaderboard.BOARDS then
		table.insert(leaderboard.BOARDS, {
			key = "brawl",
			name = "BEST WAVE",
			read = function(p)
				return math.max(0, math.floor(tonumber(p.stats and p.stats.brawlBest) or 0))
			end,
		})
	end
	match.Started:Connect(onStarted)
	match.PhaseChanged:Connect(function(phase)
		if phase == "fight" then
			fightReady = true
		end
	end)
	match.Ended:Connect(function()
		state = "over"
		removeAll()
	end)
	combat.Killed:Connect(function(victim, killer, info)
		local ok, err = pcall(onKilled, victim, killer, info)
		if not ok then
			warn("[BrawlService] kill failed: " .. tostring(err))
		end
	end)
	combat.Damaged:Connect(function(victim)
		if victim == boss then
			paintBoss(victim)
			send()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			pcall(self._tick, self)
		end)
	end)
end

function BrawlService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		send(player)
		Net.fire(
			player,
			"Toast",
			`Bot Brawl: everyone's on {Constants.TEAM_NAME.red}. Build, then hold off the {Constants.TEAM_NAME.blue} waves!`,
			"info"
		)
	end)
end

function BrawlService:Start()
	while true do
		task.wait(0.25)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[BrawlService] tick failed: " .. tostring(err))
		end
	end
end

return BrawlService

-- The raid. Every 15 minutes the portal over the Hub opens: a beam comes down to the RAID pad, and anyone who
-- jumps in lands in the arena high above, where the STAR EATER waits. Its health is sized to everyone in the
-- arena (about 75 seconds of all blasting). Three phases:
--   1. BLAST: shoot it.
--   2. SHIELDS (below 66%): it can't be hurt until someone stands on each of the 4 plates at the same time.
--   3. RAGE (below 33%): it fires slow glowing balls; get hit and you're DOWN for a few seconds.
-- Everyone who hit it gets ore, coins and gems; the top 5 by damage get an extra Mega roll (#1 has a 2% Ultra
-- chance) and go on the sky board over the Hub for a minute. If the clock runs out the boss flies away and
-- everyone gets half loot. With fewer than 10 real players, robot knights fill the plates and help a little.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MobBuilder = require(script.Parent.Parent.World.MobBuilder)
local RobotBuilder = require(script.Parent.Parent.World.RobotBuilder)
local Scenery = require(script.Parent.Parent.World.Scenery)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local RaidService = {
	Name = "RaidService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"PlanetService",
		"MobService",
		"BlasterService",
		"CombatService",
		"BossService",
		"TeamService",
	},
	Started = Signal.new("RaidService.Started"), -- ()
	Ended = Signal.new("RaidService.Ended"), -- (won, ranking)
	Joined = Signal.new("RaidService.Joined"), -- (player)
	state = "waiting", -- "waiting" | "fighting" | "done"
}

local data, economy, planetService, mobs, blasters, combat, bossService, team
local layout, arena
local nextAt -- server time the next raid opens
local endsAt
local boss -- the MobService entry
local balls = {}
local robots = {} -- { model, parts, pos, target, plate }
local rng = Random.new()
local plateHeld = {}
local shieldTimer = 0
local joined = {} -- [player] = true this raid
local lastRanking = {}
local sinceRobotShot = 0
local squad -- the players of a private squad raid, or nil for the public one
local lastSquadRaid = {} -- [player] = os.time()

local STAR_EATER = {
	key = "RAID",
	name = "Star Eater",
	adjective = "Star",
	color = Color3.fromRGB(170, 110, 255),
	dark = Color3.fromRGB(60, 30, 110),
	bug = "Star Eater",
	boss = "Star Eater",
	ore = "Star Ore",
	bugHealth = 1,
	bugCoins = 1,
	bugOre = 1,
}

local function position(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

function RaidService:PlayersInArena()
	local list = {}
	for _, p in Players:GetPlayers() do
		local pos = position(p)
		if pos and WorldBuilder.inArena(pos) then
			table.insert(list, p)
		end
	end
	return list
end

function RaidService:NextAt()
	return nextAt
end

function RaidService:IsOpen()
	return self.state == "fighting" and boss ~= nil and boss.hp > boss.maxHp * Constants.RAID_JOIN_UNTIL
end

-- Everyone in the arena's damage per second, to size the boss.
local function dpsOf(players)
	local dps = 0
	for _, p in players do
		local rec = blasters:Equipped(p)
		if rec then
			dps += combat:Damage(p, rec) / Formulas.blasterCooldown(rec)
		end
	end
	return dps
end

local function broadcastEvent(kind, extra)
	local e = { kind = kind, at = nextAt, endsAt = endsAt }
	for k, v in extra or {} do
		e[k] = v
	end
	Net.fireAll("Event", e)
end

-- Phases -------------------------------------------------------------------------------------------------------
local function phaseOf(entry)
	local frac = entry.hp / entry.maxHp
	if frac <= Constants.RAID_RAGE_AT then
		return 3
	elseif frac <= Constants.RAID_SHIELD_AT then
		return 2
	end
	return 1
end

function RaidService:_setPlates(on)
	for k, plate in arena.plates do
		plate.part.Transparency = on and 0.15 or 0.6
		plate.part.Color = on and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(120, 120, 140)
		plate.lines[2].Text = on and "STAND HERE!" or ""
		plateHeld[k] = false
	end
end

-- Join and leave -------------------------------------------------------------------------------------------------
function RaidService:Join(player)
	if squad and not table.find(squad, player) then
		Net.fire(player, "Toast", "That's a private squad raid. Yours opens soon!", "info")
		return false
	end
	if self.state ~= "fighting" or not boss then
		Net.fire(
			player,
			"Toast",
			`☄️ The raid opens in {Format.time(math.max(0, nextAt - workspace:GetServerTimeNow()))}`,
			"info"
		)
		return false
	end
	if not self:IsOpen() then
		Net.fire(player, "Toast", "Too late for this raid! Next one soon.", "bad")
		return false
	end
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local wasIn = #self:PlayersInArena()
	local spawn = arena.spawn + Vector3.new(rng:NextNumber(-6, 6), 3, rng:NextNumber(-3, 3))
	hrp.CFrame = CFrame.new(spawn, Vector3.new(0, spawn.Y, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	planetService:SetWhere(player, "RAID")
	if not joined[player] then
		joined[player] = true
		local profile = data:Get(player)
		if profile then
			profile.stats.raids += 1
		end
		self.Joined:Fire(player)
	end
	-- the boss grows with the crowd (keeps its health fraction)
	local people = self:PlayersInArena()
	if #people > wasIn then
		local newMax = math.max(Constants.RAID_MIN_HEALTH, math.floor(dpsOf(people) * Constants.RAID_HEALTH_SECONDS))
		if newMax > boss.maxHp then
			boss.hp = math.floor(boss.hp / boss.maxHp * newMax)
			boss.maxHp = newMax
			mobs.setBar(boss)
		end
	end
	Net.fire(player, "Alert", "☄️ BLAST THE STAR EATER!", STAR_EATER.color)
	Net.fire(player, "Sfx", "portal")
	Net.fire(player, "Event", { kind = "raidStart", at = nextAt, endsAt = endsAt })
	return true
end

function RaidService:Leave(player)
	planetService:Travel(player, "HUB")
	Net.fire(player, "Event", { kind = "raidEnd" })
end

-- Robots ---------------------------------------------------------------------------------------------------------
function RaidService:_spawnRobots(count)
	for i = 1, count do
		local model, parts = RobotBuilder.build(tostring(i))
		local pos = arena.spawn + Vector3.new((i - 2.5) * 5, 0, -8)
		local robot = { model = model, parts = parts, pos = pos, plate = i, phase = rng:NextNumber(0, 6) }
		RobotBuilder.pose(robot, CFrame.new(pos + Vector3.new(0, 0.5, 0)))
		model.Parent = arena.model
		table.insert(robots, robot)
	end
end

function RaidService:_clearRobots()
	for _, r in robots do
		r.model:Destroy()
	end
	robots = {}
end

-- Start and end --------------------------------------------------------------------------------------------------
function RaidService:Start_(squadList)
	if self.state == "fighting" then
		return
	end
	self.state = "fighting"
	squad = squadList
	joined = {}
	endsAt = workspace:GetServerTimeNow() + Constants.RAID_SECONDS
	-- the boss
	local model = MobBuilder.build(STAR_EATER, 7, true)
	boss = mobs:Register({
		model = model,
		pos = Vector3.new(0, arena.center.Y, -arena.radius + 22),
		facing = Vector3.new(0, 0, 1),
		planet = STAR_EATER,
		island = nil,
		boss = true,
		raid = true,
		hp = Constants.RAID_MIN_HEALTH,
		maxHp = Constants.RAID_MIN_HEALTH,
		phase = 0,
		lastBall = 0,
		shielded = false,
		damage = {},
	})
	boss.fill, boss.text, boss.label = MobBuilder.healthBar(model, 40, "☄️ STAR EATER")
	mobs.setBar(boss)
	boss.onHit = function(player, damage)
		if boss.shielded then
			Net.fire(
				player,
				"Popup",
				boss.pos + Vector3.new(0, 10, 0),
				"🛡️ SHIELD! Stand on the plates!",
				Color3.fromRGB(255, 215, 60)
			)
			return false
		end
		boss.damage[player] = (boss.damage[player] or 0) + damage
		return true
	end
	boss.onDeath = function()
		self:_finish(true)
	end
	model:PivotTo(CFrame.lookAt(boss.pos + Vector3.new(0, 9.1, 0), boss.pos + Vector3.new(0, 9.1, 0) + boss.facing))
	model.Parent = workspace.Mobs
	self:_setPlates(false)
	-- the portal
	layout.hub.beam.Transparency = 0.3
	layout.hub.raidPad.Transparency = 0.2
	layout.hub.raidPad.Sign.Enabled = true
	layout.hub.ring.Transparency = 0.1
	-- robots when it's quiet (a squad raid gets them too if the squad is small)
	if (squad and #squad or #Players:GetPlayers()) < Constants.RAID_ROBOTS_BELOW then
		self:_spawnRobots(4)
	end
	-- callouts: players who bought one get their name in gold across every screen
	local callers = {}
	for _, p in Players:GetPlayers() do
		local profile = data:Get(p)
		if profile and profile.callout then
			profile.callout = nil
			table.insert(callers, p.DisplayName)
		end
	end
	if squad then
		for _, p in squad do
			Net.fire(p, "Alert", "🤝 SQUAD RAID! Jump in at the Hub!", STAR_EATER.color)
			Net.fire(p, "Sfx", "portal")
		end
	else
		Net.fireAll("Alert", "☄️ THE RAID IS OPEN! Jump in at the Hub!", STAR_EATER.color)
		Net.fireAll("Sfx", "portal")
	end
	if #callers > 0 and not squad then
		Net.fireAll(
			"Announce",
			`✨ {table.concat(callers, ", ")} {#callers > 1 and "are" or "is"} raiding! Join them!`,
			Color3.fromRGB(255, 215, 60)
		)
	end
	broadcastEvent("raidOpen")
	self.Started:Fire()
end

-- The ranking: players by damage, top first.
function RaidService:Ranking()
	local list = {}
	for player, dmg in boss and boss.damage or {} do
		if player.Parent and dmg > 0 then
			table.insert(list, { player = player, damage = dmg })
		end
	end
	table.sort(list, function(a, b)
		return a.damage > b.damage
	end)
	return list
end

function RaidService:_skyBoard(ranking, won)
	local post = layout.hub.skyBoardPost
	local old = post:FindFirstChild("SkyBoard")
	if old then
		old:Destroy()
	end
	local lines = {
		{
			text = won and (squad and "🤝 SQUAD RAID WON!" or "☄️ STAR EATER BEATEN! TOP 5")
				or "☄️ THE STAR EATER GOT AWAY",
			h = 0.2,
			y = 0,
			font = Enum.Font.LuckiestGuy,
			color = Color3.fromRGB(255, 215, 60),
		},
	}
	for i = 1, Constants.RAID_TOP do
		local r = ranking[i]
		local rec = r and blasters:Equipped(r.player)
		local profile = r and data:Get(r.player)
		local stars = profile
				and profile.rebirths
				and profile.rebirths > 0
				and string.rep("⭐", math.min(5, profile.rebirths)) .. " "
			or ""
		table.insert(lines, {
			text = r
					and `#{i} {stars}{r.player.DisplayName} · {rec and Formulas.blasterName(rec) or "?"} · {Format.num(
						r.damage
					)}`
				or "",
			h = 0.16,
			y = 0.2 + (i - 1) * 0.16,
			color = ({ Color3.fromRGB(255, 215, 60), Color3.fromRGB(220, 220, 235), Color3.fromRGB(225, 150, 90) })[i]
				or Color3.fromRGB(255, 255, 255),
		})
	end
	local gui = Scenery.sign(post, 60, 30, Vector3.new(0, 0, 0), lines, 400)
	gui.Name = "SkyBoard"
	task.delay(Constants.SKY_BOARD_SECONDS, function()
		gui:Destroy()
	end)
end

function RaidService:_finish(won)
	if self.state ~= "fighting" then
		return
	end
	self.state = "done"
	local ranking = self:Ranking()
	lastRanking = ranking
	-- loot for everyone who hit it (half if it got away)
	local share = won and 1 or 0.5
	for i, r in ranking do
		local p = r.player
		local profile = data:Get(p)
		if profile then
			local top = Planets.list[planetService:Unlocked(p)]
			local rec = blasters:Equipped(p)
			local luck = Constants.ROLL_MULT[rec and rec.roll and rec.roll.luck or "plain"]
			local ore = math.floor(top.bugOre * Constants.RAID_LOOT_ORE_BUGS * luck * share)
			local coins = math.floor(top.bugCoins * Constants.RAID_LOOT_COINS_BUGS * share)
			local gems = i <= Constants.RAID_TOP and Constants.RAID_GEMS[2]
				or rng:NextInteger(Constants.RAID_GEMS[1], Constants.RAID_GEMS[2])
			economy:AddOre(p, top.key, ore)
			economy:AddCoins(p, coins)
			local gotGems = math.max(1, math.floor(gems * share))
			economy:AddGems(p, gotGems, true)
			-- the friend who lent this player a blaster gets a share of the gems
			local lentRec
			for _, rec2 in profile.blasters do
				lentRec = lentRec or (rec2.lentBy and rec2)
			end
			if lentRec then
				local lender = Players:GetPlayerByUserId(lentRec.lentBy)
				local cut = math.floor(gotGems * Constants.LEND_SHARE)
				if lender and cut > 0 then
					economy:AddGems(lender, cut, false)
					Net.fire(
						lender,
						"Alert",
						`🤝 {p.DisplayName} raided with your blaster: +{cut} 💎`,
						Color3.fromRGB(120, 220, 255)
					)
				end
			end
			local extra = ""
			if won and i <= Constants.RAID_TOP then
				local rolled
				if i == 1 and rng:NextNumber() < Constants.RAID_ULTRA_CHANCE then
					rolled = {
						rarity = "Ultra",
						planet = top.key,
						roll = { dmg = "god", spd = "shiny", luck = "shiny", gem = "shiny" },
						lv = 0,
					}
				else
					rolled = Formulas.rollBlaster(rng, "mega", top.key, 2)
				end
				local got = blasters:Grant(p, rolled, "raid")
				extra = ` + {Formulas.blasterName(got)} {Formulas.rollStars(got)}`
				if rolled.rarity == "Ultra" then
					Net.fireAll(
						"Announce",
						`🌟 {p.DisplayName} got an ULTRA {Formulas.blasterName(got)} from the raid!`,
						Blasters.byRarity.Ultra.color
					)
				end
			end
			Net.fire(
				p,
				"Alert",
				`{won and "🏆" or "💨"} RAID #{i}: +{ore} ore +{Format.num(coins)} 💰 +{gems} 💎{extra}`,
				Color3.fromRGB(255, 215, 60)
			)
			Net.fire(p, "Sfx", won and "win" or "notify")
		end
	end
	if won then
		local names = {}
		for i = 1, math.min(3, #ranking) do
			table.insert(names, ranking[i].player.DisplayName)
		end
		Net.fireAll("Announce", `☄️ The STAR EATER is down! MVP: {table.concat(names, ", ")}`, STAR_EATER.color)
	else
		Net.fireAll("Alert", "💨 The Star Eater got away! Next time, blast harder!", Color3.fromRGB(200, 200, 220))
	end
	self:_skyBoard(ranking, won)
	-- clear the arena
	if boss then
		mobs:Unregister(boss)
		if boss.model.Parent then
			MobBuilder.burst(boss.pos + Vector3.new(0, 8, 0), STAR_EATER.color, 40)
			boss.model:Destroy()
		end
	end
	boss = nil
	for _, b in balls do
		b.part:Destroy()
	end
	balls = {}
	self:_clearRobots()
	self:_setPlates(false)
	layout.hub.beam.Transparency = 1
	layout.hub.raidPad.Transparency = 1
	layout.hub.raidPad.Sign.Enabled = false
	layout.hub.ring.Transparency = 0.45
	for _, p in self:PlayersInArena() do
		task.delay(4, function()
			if p.Parent and WorldBuilder.inArena(position(p) or Vector3.zero) then
				self:Leave(p)
			end
		end)
	end
	for _, p in Players:GetPlayers() do
		blasters:ClearLent(p)
	end
	if not squad then
		nextAt = workspace:GetServerTimeNow() + Constants.RAID_EVERY
	end
	local wasSquad = squad
	squad = nil
	self.state = "waiting"
	broadcastEvent("raid")
	Net.fireAll("Event", { kind = "raidEnd" })
	self.Ended:Fire(won, ranking, wasSquad)
end

function RaidService:IsSquad()
	return squad ~= nil
end

-- A private squad raid: you and your friends in the hub, right now. Once an hour per player, and only while
-- the public raid is waiting. Everyone in the squad is pulled into the arena.
function RaidService:SquadRaid(player)
	if self.state ~= "waiting" then
		Net.fire(player, "Toast", "A raid is already on! Jump in.", "info")
		return false
	end
	local last = lastSquadRaid[player] or 0
	local left = Constants.SQUAD_RAID_EVERY - (os.time() - last)
	if left > 0 then
		Net.fire(player, "Toast", `Your next squad raid is in {Format.time(left)}.`, "info")
		return false
	end
	local list = { player }
	for _, friend in team:Teammates(player) do
		if WorldBuilder.inHub(position(friend) or Vector3.zero) then
			table.insert(list, friend)
		end
	end
	if #list < Constants.SQUAD_RAID_MIN then
		Net.fire(player, "Toast", "Bring a friend to the Hub to start a squad raid!", "info")
		return false
	end
	lastSquadRaid[player] = os.time()
	self:Start_(list)
	for _, p in list do
		self:Join(p)
	end
	local names = {}
	for _, p in list do
		table.insert(names, p.DisplayName)
	end
	Net.fireAll("Announce", `🤝 SQUAD RAID: {table.concat(names, ", ")} vs the Star Eater!`, STAR_EATER.color)
	return true
end

function RaidService:LastRanking()
	return lastRanking
end

-- Fight loop -------------------------------------------------------------------------------------------------------
function RaidService:_fireBall(target)
	local from = boss.pos + Vector3.new(0, 8, 0)
	local dir = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if dir.Magnitude < 0.1 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "RaidBall"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(5, 5, 5)
	part.Color = STAR_EATER.color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CFrame = CFrame.new(from)
	part.Parent = workspace.Fx
	table.insert(balls, { part = part, pos = from, dir = dir.Unit, bornAt = os.clock() })
	Net.fireAll("Sfx", "boss", from)
end

function RaidService:_step(dt)
	local now = workspace:GetServerTimeNow()
	if self.state == "waiting" then
		if now >= nextAt then
			self:Start_()
		end
		return
	end
	if self.state ~= "fighting" or not boss then
		return
	end
	if now >= endsAt then
		self:_finish(false)
		return
	end
	local people = self:PlayersInArena()
	local phase = phaseOf(boss)
	-- shields: all four plates held at once for a second breaks them
	if phase == 2 and not boss.shieldDone then
		if not boss.shielded then
			boss.shielded = true
			self:_setPlates(true)
			for _, p in people do
				Net.fire(p, "Alert", "🛡️ SHIELDS UP! STAND ON ALL 4 PLATES!", Color3.fromRGB(255, 215, 60))
			end
			Net.fireAll("Sfx", "boss", boss.pos)
		end
		local held = 0
		for k, plate in arena.plates do
			local on = false
			for _, p in people do
				local pos = position(p)
				if pos and Vector3.new(pos.X - plate.center.X, 0, pos.Z - plate.center.Z).Magnitude < 5.5 then
					on = true
				end
			end
			for _, r in robots do
				if r.onPlate == k then
					on = true
				end
			end
			if on ~= plateHeld[k] then
				plateHeld[k] = on
				plate.part.Color = on and Color3.fromRGB(120, 255, 140) or Color3.fromRGB(255, 215, 60)
				plate.lines[2].Text = on and "✅ HELD" or "STAND HERE!"
			end
			if on then
				held += 1
			end
		end
		if held == 4 then
			shieldTimer += dt
			if shieldTimer >= 1 then
				boss.shielded = false
				boss.shieldDone = true
				self:_setPlates(false)
				-- a squad break: four friends did it alone
				local friendsOnly = #people >= 4 and team:AllTeam(people)
				Net.fireAll(
					"Alert",
					friendsOnly and "💥 SQUAD BREAK! Shields down!" or "💥 SHIELDS DOWN! BLAST IT!",
					Color3.fromRGB(120, 255, 140)
				)
				Net.fireAll("Sfx", "win", boss.pos)
				if friendsOnly then
					boss.squadBreak = true
				end
			end
		else
			shieldTimer = 0
		end
	end
	-- the boss turns to face the nearest player and creeps forward
	local nearest, best
	for _, p in people do
		local pp = position(p)
		local d = (pp - boss.pos).Magnitude
		if not best or d < best then
			nearest, best = pp, d
		end
	end
	boss.phase += dt * 2
	if nearest and best > 20 then
		local dir = Vector3.new(nearest.X - boss.pos.X, 0, nearest.Z - boss.pos.Z).Unit
		boss.facing = dir
		boss.pos += dir * 2 * dt
	end
	local bob = math.sin(boss.phase) * 0.8
	boss.model:PivotTo(
		CFrame.lookAt(boss.pos + Vector3.new(0, 9.1 + bob, 0), boss.pos + Vector3.new(0, 9.1 + bob, 0) + boss.facing)
	)
	-- rage
	if phase == 3 and #people > 0 and os.clock() - boss.lastBall > Constants.RAID_BALL_EVERY then
		boss.lastBall = os.clock()
		local victim = people[rng:NextInteger(1, #people)]
		local vp = position(victim)
		if vp then
			self:_fireBall(vp)
		end
	end
	for k = #balls, 1, -1 do
		local b = balls[k]
		b.pos += b.dir * Constants.BOSS_BALL_SPEED * dt
		b.part.CFrame = CFrame.new(b.pos)
		local gone = os.clock() - b.bornAt > 6
		for _, p in people do
			local pp = position(p)
			if pp and (pp - b.pos).Magnitude < 4.5 and not bossService:IsDown(p) then
				bossService:Down(p)
				gone = true
			end
		end
		if gone then
			b.part:Destroy()
			table.remove(balls, k)
		end
	end
	-- robots: stand on plates during shields, otherwise hang back and take potshots
	sinceRobotShot += dt
	for i, r in robots do
		local want
		if boss.shielded then
			want = arena.plates[r.plate].center
		else
			want = arena.spawn + Vector3.new((i - 2.5) * 5, 0, -8)
		end
		local delta = Vector3.new(want.X - r.pos.X, 0, want.Z - r.pos.Z)
		if delta.Magnitude > 0.5 then
			r.pos += delta.Unit * math.min(delta.Magnitude, 12 * dt)
			r.onPlate = nil
		elseif boss.shielded then
			r.onPlate = r.plate
		end
		r.phase += dt * 4
		local face = Vector3.new(boss.pos.X - r.pos.X, 0, boss.pos.Z - r.pos.Z)
		RobotBuilder.pose(
			r,
			CFrame.lookAt(
				r.pos + Vector3.new(0, 0.5 + math.abs(math.sin(r.phase)) * 0.1, 0),
				r.pos + Vector3.new(0, 0.5, 0) + (face.Magnitude > 0.1 and face.Unit or Vector3.zAxis)
			)
		)
	end
	if #robots > 0 and not boss.shielded and sinceRobotShot >= 2 then
		sinceRobotShot = 0
		local dmg = math.floor(boss.maxHp * Constants.RAID_ROBOT_DAMAGE / 5)
		for _, r in robots do
			Net.fireAll(
				"Beam",
				r.pos + Vector3.new(0, 2.5, 0),
				boss.pos + Vector3.new(0, 8, 0),
				Color3.fromRGB(120, 220, 255)
			)
		end
		boss.hp -= dmg * #robots
		mobs.setBar(boss)
		if boss.hp <= 0 then
			self:_finish(true)
		end
	end
end

function RaidService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	planetService = registry.PlanetService
	mobs = registry.MobService
	blasters = registry.BlasterService
	combat = registry.CombatService
	bossService = registry.BossService
	team = registry.TeamService
	layout = WorldBuilder.layout
	arena = layout.arena
	nextAt = workspace:GetServerTimeNow() + Constants.RAID_EVERY
	Net.on("SquadRaid", function(player)
		self:SquadRaid(player)
	end)
	-- the SQUAD RAID pad in the Hub: a teal ring with a prompt
	local hub = layout.hub.model
	local pos = Vector3.new(-16, 0, -16)
	local ring = Scenery.ring(hub, "SquadPad", pos + Vector3.new(0, 0.2, 0), 9, Color3.fromRGB(80, 230, 200))
	ring:SetAttribute("TurnSpeed", 0.4)
	game:GetService("CollectionService"):AddTag(ring, "Turn")
	local sign = Scenery.sign(ring, 12, 4, Vector3.new(0, 4.5, 0), {
		{
			text = "🤝 SQUAD RAID",
			h = 0.55,
			y = 0,
			font = Enum.Font.LuckiestGuy,
			color = Color3.fromRGB(80, 230, 200),
		},
		{ text = "You + friends vs the Star Eater", h = 0.45, y = 0.55 },
	}, 90)
	sign.Size = UDim2.fromOffset(190, 52)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt_squad"
	prompt.ActionText = "Start a squad raid"
	prompt.ObjectText = "SQUAD RAID"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = ring
	prompt.Triggered:Connect(function(player)
		self:SquadRaid(player)
	end)
	planetService.PadStepped:Connect(function(player, pad)
		if pad == "RAID" then
			self:Join(player)
		elseif pad == "EXIT" then
			self:Leave(player)
		end
	end)
	data.ClientReady:Connect(function(player)
		if data:Get(player) then
			Net.fire(
				player,
				"Event",
				{ kind = self.state == "fighting" and "raidOpen" or "raid", at = nextAt, endsAt = endsAt }
			)
		end
	end)
end

function RaidService:OnPlayerLeaving(player)
	joined[player] = nil
	lastSquadRaid[player] = nil
	if boss then
		boss.damage[player] = nil
	end
end

function RaidService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			local step = math.min(acc, 0.3)
			acc = 0
			self:_step(step)
		end
	end)
end

return RaidService

-- Planet bosses. Each planet's boss waits in its yard past the Boss Gate. Walk in and it wakes up and comes at
-- you (slowly). Below half health it fires slow glowing balls: get hit and you're down for a few seconds (no
-- death). Beat it and everyone who hit it gets big loot, a gem, and the next planet opens. It comes back a
-- little later for the next player. Leave the yard for a while and it heals up and waits again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MobBuilder = require(script.Parent.Parent.World.MobBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local BossService = {
	Name = "BossService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlanetService", "MobService", "BlasterService" },
	Beaten = Signal.new("BossService.Beaten"), -- (planetKey, hitters)
	bosses = {}, -- [planetIndex] = entry
}

local data, economy, planetService, mobs
local layout
local balls = {} -- { part, pos, dir, planetIndex, bornAt }
local downUntil = {} -- [player] = os.clock()
local rng = Random.new()

local function position(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function playersInYard(pl)
	local list = {}
	for _, p in Players:GetPlayers() do
		local pos = position(p)
		if pos then
			local there, inYard = WorldBuilder.planetAt(pos)
			if there == pl and inYard then
				table.insert(list, p)
			end
		end
	end
	return list
end

function BossService:_spawn(i)
	local pl = layout.planets[i]
	local planet = pl.planet
	local model = MobBuilder.build(planet, 4, true)
	local entry = mobs:Register({
		model = model,
		pos = pl.bossHome,
		facing = pl.toHub,
		planet = planet,
		island = nil,
		boss = true,
		state = "waiting",
		hp = Formulas.bossHealth(planet, 1),
		maxHp = Formulas.bossHealth(planet, 1),
		phase = 0,
		lastBall = 0,
		idleSince = os.clock(),
		planetIndex = i,
	})
	entry.fill, entry.text, entry.label = MobBuilder.healthBar(model, 26, `👑 {planet.boss}`)
	mobs.setBar(entry)
	entry.lastHitter, entry.lastHitAt, entry.tagOpenUntil = nil, 0, 0
	entry.onHit = function(player)
		if entry.state == "waiting" then
			entry.state = "fighting"
		end
		if planet.key ~= "SHADOW" then
			return nil
		end
		-- the Void Eye: ghostly (half damage) unless two players hit it within a moment: TAG TEAM opens it up
		local t = os.clock()
		if t < entry.tagOpenUntil then
			return 1
		end
		if entry.lastHitter and entry.lastHitter ~= player and t - entry.lastHitAt <= Constants.TAG_TEAM_WINDOW then
			entry.tagOpenUntil = t + Constants.TAG_TEAM_OPEN
			Net.fireAll(
				"Popup",
				entry.pos + Vector3.new(0, 9, 0),
				"👊 TAG TEAM! FULL DAMAGE!",
				Color3.fromRGB(255, 215, 60)
			)
			Net.fireAll("Sfx", "win", entry.pos)
			return 1
		end
		entry.lastHitter, entry.lastHitAt = player, t
		return Constants.TAG_TEAM_WEAK
	end
	entry.onDeath = function(killer)
		self:_beaten(entry, killer)
	end
	model:PivotTo(CFrame.lookAt(entry.pos + Vector3.new(0, 5.2, 0), entry.pos + Vector3.new(0, 5.2, 0) + pl.toHub))
	model.Parent = workspace.Mobs
	self.bosses[i] = entry
	return entry
end

function BossService:_beaten(entry, _killer)
	local planet = entry.planet
	local names = {}
	for hitter in entry.hitters do
		if hitter.Parent then
			local profile = data:Get(hitter)
			if profile then
				profile.stats.bosses += 1
			end
			economy:AddGems(hitter, Constants.BOSS_GEMS, true)
			planetService:BossBeaten(hitter, planet.key)
			table.insert(names, hitter.DisplayName)
			Net.fire(
				hitter,
				"Alert",
				`👑 {string.upper(planet.boss)} BEATEN! +{Constants.BOSS_GEMS} 💎`,
				Color3.fromRGB(255, 215, 60)
			)
			Net.fire(hitter, "Sfx", "win")
		end
	end
	Net.fireAll("Announce", `👑 {table.concat(names, ", ")} beat the {planet.boss}!`, planet.color)
	self.Beaten:Fire(planet.key, entry.hitters)
	self.bosses[entry.planetIndex] = nil
	-- back in a little while
	task.delay(12, function()
		if not self.bosses[entry.planetIndex] then
			self:_spawn(entry.planetIndex)
		end
	end)
end

function BossService:IsDown(player)
	return (downUntil[player] or 0) > os.clock()
end

function BossService:Down(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	downUntil[player] = os.clock() + Constants.BOSS_DOWN_SECONDS
	hum.WalkSpeed = 0
	Net.fire(player, "Down", Constants.BOSS_DOWN_SECONDS)
	Net.fire(player, "Sfx", "hit")
	task.delay(Constants.BOSS_DOWN_SECONDS, function()
		if player.Parent and player.Character then
			local h = player.Character:FindFirstChildOfClass("Humanoid")
			if h then
				h.WalkSpeed = WorldBuilder.WALK_SPEED or Constants.WALK_SPEED
			end
		end
	end)
end

function BossService:_fireBall(entry, target)
	local pl = layout.planets[entry.planetIndex]
	local from = entry.pos + Vector3.new(0, 5, 0)
	local dir = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	if dir.Magnitude < 0.1 then
		return
	end
	local part = Instance.new("Part")
	part.Name = "BossBall"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(4, 4, 4)
	part.Color = entry.planet.color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CFrame = CFrame.new(from)
	part.Parent = workspace.Fx
	table.insert(
		balls,
		{ part = part, pos = from, dir = dir.Unit, planetIndex = entry.planetIndex, bornAt = os.clock(), pl = pl }
	)
	Net.fireAll("Sfx", "boss", from)
end

function BossService:_step(dt)
	local t = os.clock()
	for i, pl in layout.planets do
		local entry = self.bosses[i]
		if entry and entry.model.Parent then
			local people = playersInYard(pl)
			local near = #people
			-- health follows the crowd
			local newMax = Formulas.bossHealth(entry.planet, math.max(1, near))
			if newMax ~= entry.maxHp then
				entry.hp = math.floor(entry.hp / entry.maxHp * newMax)
				entry.maxHp = newMax
				mobs.setBar(entry)
			end
			if near > 0 then
				entry.idleSince = t
				if entry.state == "waiting" then
					entry.state = "fighting"
					for _, p in people do
						Net.fire(p, "Alert", `👑 {string.upper(entry.planet.boss)}! BLAST IT!`, entry.planet.color)
					end
				end
			end
			if entry.state == "fighting" then
				if near == 0 and t - entry.idleSince > Constants.BOSS_RESET_SECONDS then
					entry.state = "waiting"
					entry.hp = entry.maxHp
					entry.hitters = {}
					entry.pos = pl.bossHome
					mobs.setBar(entry)
				else
					-- walk slowly at the nearest player in the yard
					local nearest, best
					for _, p in people do
						local pp = position(p)
						local d = (pp - entry.pos).Magnitude
						if not best or d < best then
							nearest, best = pp, d
						end
					end
					entry.phase += dt * 3
					if nearest and best > 12 then
						local dir = Vector3.new(nearest.X - entry.pos.X, 0, nearest.Z - entry.pos.Z).Unit
						entry.facing = dir
						entry.pos += dir * Constants.BOSS_SPEED * dt
					end
					-- rage: slow glowing balls below half health
					if
						entry.hp <= entry.maxHp * Constants.BOSS_RAGE_AT
						and near > 0
						and t - entry.lastBall > Constants.BOSS_BALL_EVERY
					then
						entry.lastBall = t
						local victim = people[rng:NextInteger(1, #people)]
						local vp = position(victim)
						if vp then
							self:_fireBall(entry, vp)
						end
					end
				end
			end
			local bob = math.sin(entry.phase) * 0.6
			entry.model:PivotTo(
				CFrame.lookAt(
					entry.pos + Vector3.new(0, 5.2 + bob, 0),
					entry.pos + Vector3.new(0, 5.2 + bob, 0) + entry.facing
				)
			)
		elseif not entry then
			-- (bosses spawn lazily: when the planet is unlocked for anyone, or at start for all; cheap enough for 8)
			self:_spawn(i)
		end
	end
	-- the balls fly straight and slow; a hit knocks a player down
	for k = #balls, 1, -1 do
		local b = balls[k]
		b.pos += b.dir * Constants.BOSS_BALL_SPEED * dt
		b.part.CFrame = CFrame.new(b.pos)
		local gone = t - b.bornAt > 5
		for _, p in playersInYard(b.pl) do
			local pp = position(p)
			if pp and (pp - b.pos).Magnitude < 4 and not self:IsDown(p) then
				self:Down(p)
				gone = true
			end
		end
		if gone then
			b.part:Destroy()
			table.remove(balls, k)
		end
	end
end

function BossService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	planetService = registry.PlanetService
	mobs = registry.MobService
	layout = WorldBuilder.layout
end

function BossService:OnPlayerLeaving(player)
	downUntil[player] = nil
end

function BossService:Start()
	for i in layout.planets do
		self:_spawn(i)
	end
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

function BossService:HealthText(i)
	local e = self.bosses[i]
	return e and Format.num(e.hp) or "-"
end

return BossService

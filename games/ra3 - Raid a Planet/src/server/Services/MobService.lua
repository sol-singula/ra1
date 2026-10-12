-- Bugs: while someone is on a planet, a few bugs walk around it and come at the nearest player (they never hurt
-- you; they just buzz). Their health scales with the players near them. Blast one and everyone who hit it gets
-- ore and coins. Bosses (BossService) register here too, so a blast hits either the same way.
-- Bugs are anchored models moved by the server 10 times a second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MobBuilder = require(script.Parent.Parent.World.MobBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local MobService = {
	Name = "MobService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"PlanetService",
		"BlasterService",
		"TeamService",
		"RebirthService",
	},
	Died = Signal.new("MobService.Died"), -- (killer, planetKey, mob)
	targets = {}, -- [id] = { id, model, pos, hp, maxHp, planet (data), boss?, hit = fn, ... }
}

local data, economy, blasters, team, rebirth
local folder
local nextId = 1
local rng = Random.new()
local respawnAt = {} -- [planetIndex] = { times }
local layout

local function position(player)
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

-- Players standing on this planet's island (not the boss yard).
local function playersOn(pl)
	local list = {}
	for _, p in Players:GetPlayers() do
		local pos = position(p)
		if pos then
			local there, inYard = WorldBuilder.planetAt(pos)
			if there == pl and not inYard then
				table.insert(list, p)
			end
		end
	end
	return list
end

function MobService:NearCount(pos)
	local n = 0
	for _, p in Players:GetPlayers() do
		local pp = position(p)
		if pp and (pp - pos).Magnitude <= Constants.NEAR_RADIUS then
			n += 1
		end
	end
	return math.max(1, n)
end

function MobService:Register(entry)
	entry.id = nextId
	nextId += 1
	entry.model:SetAttribute("MobId", entry.id)
	entry.hitters = {}
	self.targets[entry.id] = entry
	return entry
end

function MobService:Unregister(entry)
	self.targets[entry.id] = nil
end

local function setBar(entry)
	if entry.fill then
		entry.fill.Size = UDim2.new(math.clamp(entry.hp / entry.maxHp, 0, 1), 0, 1, 0)
		entry.text.Text = Format.num(math.max(0, entry.hp))
	end
end
MobService.setBar = setBar

function MobService:SpawnBug(pl)
	local planet = pl.planet
	local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(14, pl.radius - 10)
	local pos = pl.center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	if (pos - pl.homeCenter).Magnitude < 16 then
		pos = pl.center
	end
	local model = MobBuilder.build(planet, 1, false)
	local entry = self:Register({
		model = model,
		pos = pos,
		facing = Vector3.new(0, 0, -1),
		planet = planet,
		island = pl,
		hp = Formulas.bugHealth(planet, 1),
		maxHp = Formulas.bugHealth(planet, 1),
		phase = rng:NextNumber(0, 6),
		boss = false,
	})
	entry.fill, entry.text = MobBuilder.healthBar(model, 6, planet.bug)
	setBar(entry)
	model:PivotTo(CFrame.new(pos))
	model.Parent = folder
	return entry
end

-- Loot for everyone who hit the mob: ore and coins; the killer gets the kill.
function MobService:_die(entry, killer)
	self:Unregister(entry)
	local planet = entry.planet
	for hitter in entry.hitters do
		if hitter.Parent then
			local rec = blasters:Equipped(hitter)
			local ore, coins = Formulas.bugLoot(planet, rec)
			local mult = (entry.boss and Constants.BOSS_LOOT_ORE_MULT or 1) * rebirth:NightmareMult(hitter)
			-- squad ore: a friend who hit it too doubles a boss's ore for you
			if entry.boss and team then
				for other in entry.hitters do
					if other ~= hitter and team:AreTeam(hitter, other) then
						mult *= Constants.SQUAD_ORE_MULT
						break
					end
				end
			end
			economy:AddOre(hitter, planet.key, ore * mult)
			local got = economy:AddCoins(hitter, coins * mult)
			Net.fire(
				hitter,
				"Popup",
				entry.pos + Vector3.new(0, 4, 0),
				`+{ore * mult} ore  +{Format.num(got)} 💰`,
				planet.color
			)
			if not entry.boss then
				local profile = data:Get(hitter)
				if profile then
					profile.stats.bugs += 1
				end
			end
		end
	end
	Net.fireAll("Sfx", "pop", entry.pos)
	MobBuilder.burst(entry.pos + Vector3.new(0, 1.5, 0), planet.color, entry.boss and 24 or 8)
	entry.model:Destroy()
	self.Died:Fire(killer, planet.key, entry)
	if entry.onDeath then
		entry.onDeath(killer)
	elseif entry.island then
		local list = respawnAt[entry.island.planet.index] or {}
		respawnAt[entry.island.planet.index] = list
		table.insert(list, os.clock() + Constants.BUG_RESPAWN_SECONDS)
	end
end

-- A blast hit a target. Returns the damage dealt (0 if the target is gone).
function MobService:Hit(player, id, damage)
	local entry = self.targets[id]
	if not entry or entry.hp <= 0 then
		return 0
	end
	if entry.onHit and entry.onHit(player, damage) == false then
		return 0 -- (shielded)
	end
	entry.hp -= damage
	entry.hitters[player] = true
	setBar(entry)
	Net.fire(
		player,
		"Popup",
		entry.pos + Vector3.new(0, 2.5 + rng:NextNumber(0, 1.5), 0),
		Format.num(damage),
		Color3.fromRGB(255, 240, 120)
	)
	if entry.hp <= 0 then
		self:_die(entry, player)
	end
	return damage
end

function MobService:_step(dt)
	local t = os.clock()
	-- keep every visited planet stocked
	for i, pl in layout.planets do
		local people = playersOn(pl)
		local alive = 0
		for _, e in self.targets do
			if e.island == pl and not e.boss then
				alive += 1
			end
		end
		if #people > 0 then
			local list = respawnAt[i] or {}
			local want = Constants.BUGS_PER_PLANET
			while alive + #list < want do
				table.insert(list, t + rng:NextNumber(0, 1))
			end
			for k = #list, 1, -1 do
				if t >= list[k] and alive < want then
					table.remove(list, k)
					self:SpawnBug(pl)
					alive += 1
				end
			end
			respawnAt[i] = list
		elseif alive > 0 then
			-- nobody here: the bugs go away (they come back when someone lands)
			for _, e in table.clone(self.targets) do
				if e.island == pl and not e.boss then
					self:Unregister(e)
					e.model:Destroy()
				end
			end
			respawnAt[i] = {}
		end
	end
	-- bugs walk at the nearest player on their island
	for _, e in self.targets do
		if not e.boss and e.model.Parent then
			-- health follows the crowd (the max grows; current hp keeps its fraction)
			local near = self:NearCount(e.pos)
			local newMax = Formulas.bugHealth(e.planet, near)
			if newMax ~= e.maxHp then
				e.hp = math.floor(e.hp / e.maxHp * newMax)
				e.maxHp = newMax
				setBar(e)
			end
			local nearest, best
			for _, p in playersOn(e.island) do
				local pp = position(p)
				local d = (pp - e.pos).Magnitude
				if not best or d < best then
					nearest, best = pp, d
				end
			end
			e.phase += dt * 6
			if nearest and best > Constants.BUG_STOP_DISTANCE then
				local dir = Vector3.new(nearest.X - e.pos.X, 0, nearest.Z - e.pos.Z)
				if dir.Magnitude > 0.1 then
					dir = dir.Unit
					e.facing = dir
					e.pos += dir * Constants.BUG_SPEED * dt
				end
			end
			local bob = math.sin(e.phase) * 0.25
			e.model:PivotTo(
				CFrame.lookAt(e.pos + Vector3.new(0, 1.3 + bob, 0), e.pos + Vector3.new(0, 1.3 + bob, 0) + e.facing)
			)
		end
	end
end

function MobService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	blasters = registry.BlasterService
	team = registry.TeamService
	rebirth = registry.RebirthService
	layout = WorldBuilder.layout
	folder = workspace:FindFirstChild("Mobs") or Instance.new("Folder", workspace)
	folder.Name = "Mobs"
end

function MobService:Start()
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

function MobService:PlanetOf(entry)
	return Planets.byKey[entry.planet.key]
end

return MobService

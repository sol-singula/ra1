-- The shot, the pop and the respawn. The server decides every pop:
--   * a client sends "Fire" (origin, direction, the server time it fired at)
--   * the server checks the fire rate, that the shot starts at the shooter's head, and the zone
--   * it rewinds every target to where it was when the shooter fired (lag compensation, at most 0.3 s), then
--     tests the ray against each target's head ball and body capsule and against the map's walls
--   * the nearest target in front of any wall pops: one hit, one pop
-- A popped fighter waits in the pop box (out of sight, anchored) for 5 seconds, then respawns with a 2-second
-- shield that breaks when they fire.
--
-- Zones ("arena", "duel", "range") register a handler: { geometry() -> {Instance}, spawn(f) -> CFrame,
-- onPop(killer, victim, info), fallY }. Fighters are players or robot tables
-- { robot = true, id, name, model, root, zone }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "LoadoutService" },
	zones = {}, -- [zoneName] = handler
	robots = {}, -- [robot] = true
	Fired = Signal.new("CombatService.Fired"), -- (player)
	Popped = Signal.new("CombatService.Popped"), -- (killer, victim, info)
	Respawned = Signal.new("CombatService.Respawned"), -- (fighter)
}

local data, loadout
local history = {} -- [fighter] = { { t, p } ... } newest last
local lastShot = {} -- [player] = { at = os.clock(), n = shots in this clip }
local popToken = {} -- [fighter] = number, so an old respawn timer never fires after a new pop

local function serverNow()
	return workspace:GetServerTimeNow()
end

-- Fighter helpers ------------------------------------------------------------------------------------------
function CombatService.root(f)
	if f.robot then
		return f.root
	end
	local c = f.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end
local root = CombatService.root

function CombatService.zone(f)
	if f.robot then
		return f.zone
	end
	return f:GetAttribute("Zone")
end

function CombatService.isPopped(f)
	if f.robot then
		return f.popped == true
	end
	return f:GetAttribute("Popped") == true
end

function CombatService.shielded(f)
	local untilT
	if f.robot then
		untilT = f.shieldUntil
	else
		untilT = f:GetAttribute("ShieldUntil")
	end
	return untilT ~= nil and serverNow() < untilT
end

function CombatService.name(f)
	return f.robot and f.name or f.DisplayName
end

function CombatService.setZone(player, zone)
	player:SetAttribute("Zone", zone)
end

-- Every fighter (players with characters, and robots) currently in a zone.
function CombatService:Fighters(zone)
	local out = {}
	for _, p in Players:GetPlayers() do
		if root(p) and (zone == nil or p:GetAttribute("Zone") == zone) then
			table.insert(out, p)
		end
	end
	for r in self.robots do
		if r.root and (zone == nil or r.zone == zone) then
			table.insert(out, r)
		end
	end
	return out
end

function CombatService:AddRobot(robot)
	self.robots[robot] = true
end

function CombatService:RemoveRobot(robot)
	self.robots[robot] = nil
	history[robot] = nil
	popToken[robot] = nil
end

-- Position history (for lag compensation) ------------------------------------------------------------------
local function record()
	local t = serverNow()
	for _, f in CombatService:Fighters(nil) do
		local r = root(f)
		local z = CombatService.zone(f)
		if r and CombatService.zones[z] then
			local h = history[f]
			if not h then
				h = {}
				history[f] = h
			end
			table.insert(h, { t = t, p = r.Position })
			while #h > 2 and h[1].t < t - Constants.HISTORY_SECONDS do
				table.remove(h, 1)
			end
		end
	end
end

-- Where a fighter's root was at server time `at` (between recorded samples; the live position if newer).
function CombatService:PositionAt(f, at)
	local r = root(f)
	local h = history[f]
	if not h or #h == 0 then
		return r and r.Position
	end
	if at >= h[#h].t then
		return r and r.Position or h[#h].p
	end
	for i = #h - 1, 1, -1 do
		local a, b = h[i], h[i + 1]
		if at >= a.t then
			local span = b.t - a.t
			local k = span > 0 and (at - a.t) / span or 1
			return a.p:Lerp(b.p, k)
		end
	end
	return h[1].p
end

function CombatService:ClearHistory(f)
	history[f] = nil
end

-- Shooting -----------------------------------------------------------------------------------------------------
local function wallHit(zoneName, origin, dir, range)
	local zone = CombatService.zones[zoneName]
	local geo = zone and zone.geometry and zone.geometry() or {}
	if #geo == 0 then
		return range, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = geo
	local hit = workspace:Raycast(origin, dir * range, params)
	if hit then
		return hit.Distance, hit.Position
	end
	return range, nil
end

-- The first fighter a ray hits in a zone (rewound to `at`), and whether it was a headshot. Walls block.
function CombatService:Trace(shooter, zoneName, origin, dir, at)
	local wallDist, wallPos = wallHit(zoneName, origin, dir, Constants.MAX_RANGE)
	local zone = self.zones[zoneName]
	local targetsOnly = zone and zone.targetsOnly
	local best, bestDist, bestHead
	for _, f in self:Fighters(zoneName) do
		if f ~= shooter and not self.isPopped(f) and (not targetsOnly or f.robot) then
			local pos = self:PositionAt(f, at)
			if pos then
				local d, head = Formulas.hitTarget(origin, dir, pos, wallDist)
				if d and (not bestDist or d < bestDist) then
					best, bestDist, bestHead = f, d, head
				end
			end
		end
	end
	if best then
		return best, bestHead, origin + dir * bestDist
	end
	return nil, false, wallPos or (origin + dir * Constants.MAX_RANGE)
end

local function breakShield(f)
	if f.robot then
		f.shieldUntil = nil
		return
	end
	f:SetAttribute("ShieldUntil", nil)
	local c = f.Character
	local ff = c and c:FindFirstChild("SpawnShield")
	if ff then
		ff:Destroy()
	end
end

local function muzzleOf(f, fallback)
	local c = f.robot and f.model or f.Character
	local tool = c and c:FindFirstChild("Rifle")
	local handle = tool and tool:FindFirstChild("Handle")
	local m = handle and handle:FindFirstChild("Muzzle")
	if m then
		return handle.CFrame * m.Position
	end
	return fallback
end

-- A player's shot. Returns the fighter popped (or nil) and why a shot was refused (for tests).
function CombatService:Fire(player, origin, dir, firedAt)
	local zoneName = self.zone(player)
	if not self.zones[zoneName] or self.isPopped(player) then
		return nil, "zone"
	end
	local r = root(player)
	if not r then
		return nil, "nobody"
	end
	if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" or dir.Magnitude < 0.5 then
		return nil, "args"
	end
	dir = dir.Unit
	local head = r.Position + Vector3.new(0, Constants.HEAD_OFFSET, 0)
	if (origin - head).Magnitude > Constants.ORIGIN_TOLERANCE then
		return nil, "origin"
	end
	-- fire rate
	local rifle = loadout:Rifle(player)
	local now = os.clock()
	local ls = lastShot[player]
	if ls then
		local cd = Rifles.cooldown(rifle, ls.n)
		if now - ls.at < cd - Constants.FIRE_RATE_SLACK then
			return nil, "cooldown"
		end
	end
	local n = (ls and ls.n < rifle.shots and now - ls.at < rifle.bolt) and ls.n + 1 or 1
	lastShot[player] = { at = now, n = n }
	breakShield(player)
	self.Fired:Fire(player)
	-- lag compensation
	local t = serverNow()
	local at = t
	if type(firedAt) == "number" then
		at = math.clamp(firedAt, t - Constants.LAG_COMP_MAX, t)
	end
	local victim, headshot, hitPos = self:Trace(player, zoneName, origin, dir, at)
	Net.fireAll("Shot", muzzleOf(player, origin), hitPos, loadout:TracerColor(player), player.UserId, rifle.tracer)
	if victim then
		if self.shielded(victim) then
			Net.fire(player, "Toast", "Shielded! They just spawned.", "info")
			return nil, "shield"
		end
		self:Pop(player, victim, headshot)
		return victim, nil
	end
	return nil, "miss"
end

-- A robot's shot at a target (RobotService picks the target and whether it hits).
function CombatService:RobotFire(robot, target, hits)
	if robot.popped or not robot.root then
		return
	end
	local from = robot.root.Position + Vector3.new(0, Constants.HEAD_OFFSET, 0)
	local tr = root(target)
	if not tr then
		return
	end
	local aim = tr.Position + Vector3.new(0, hits and 0.3 or 3.5, 0)
	local dir = (aim - from).Unit
	local wallDist = wallHit(robot.zone, from, dir, (aim - from).Magnitude + 2)
	local blocked = wallDist < (aim - from).Magnitude - 1
	robot.shieldUntil = nil
	Net.fireAll(
		"Shot",
		muzzleOf(robot, from),
		blocked and (from + dir * wallDist) or aim,
		Color3.fromRGB(255, 90, 90),
		0,
		true
	)
	if hits and not blocked and not self.isPopped(target) and not self.shielded(target) then
		self:Pop(robot, target, false)
	end
end

-- Popping and respawning ------------------------------------------------------------------------------------
function CombatService:Pop(killer, victim, headshot, how)
	if self.isPopped(victim) then
		return
	end
	local zoneName = self.zone(victim)
	local zone = self.zones[zoneName]
	local r = root(victim)
	local pos = r and r.Position or Vector3.zero
	popToken[victim] = (popToken[victim] or 0) + 1
	local token = popToken[victim]
	-- the burst everyone sees, in the killer's pop effect
	local effect = (killer and not killer.robot) and loadout:Effect(killer) or "BRICKS"
	Net.fireAll("Pop", pos, effect)
	Net.fireAll("Sfx", "pop", pos)
	-- out of sight until the respawn
	if victim.robot then
		victim.popped = true
		victim.model:PivotTo(CFrame.new(WorldBuilder.POP_BOX + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))))
	else
		victim:SetAttribute("Popped", true)
		breakShield(victim)
		if r then
			r.Anchored = true
			r.CFrame = CFrame.new(WorldBuilder.POP_BOX)
		end
	end
	history[victim] = nil
	local info = { headshot = headshot == true, how = how or "shot", at = pos, zone = zoneName }
	if killer and not killer.robot then
		Net.fire(killer, "Hit", headshot == true)
		Net.fire(killer, "Sfx", headshot and "headshot" or "hit")
	end
	if zone and zone.onPop then
		zone.onPop(killer, victim, info)
	end
	self.Popped:Fire(killer, victim, info)
	if not victim.robot then
		local backAt = serverNow() + Constants.RESPAWN_SECONDS
		Net.fire(victim, "Popped", {
			by = killer and self.name(killer) or "",
			userId = (killer and not killer.robot) and killer.UserId or 0,
			robot = (killer and killer.robot) and killer.model.Name or nil,
			level = killer and (killer.robot and 1 or (killer:GetAttribute("Level") or 1)) or 1,
			rifle = killer and not killer.robot and loadout:Rifle(killer).name or "Bolt",
			skin = killer and not killer.robot and loadout:SkinName(killer) or nil,
			effect = effect,
			headshot = headshot == true,
			back = backAt,
			how = info.how,
		})
		Net.fire(victim, "Sfx", "popped")
	end
	task.delay(zone and zone.respawnSeconds or Constants.RESPAWN_SECONDS, function()
		if popToken[victim] == token and self.isPopped(victim) and self.zone(victim) == zoneName then
			self:Respawn(victim)
		end
	end)
end

-- Bring a fighter back into its zone at a spawn the zone picks, with a spawn shield.
function CombatService:Respawn(f, noShield)
	local zone = self.zones[self.zone(f)]
	local r = root(f)
	if not r then
		return
	end
	local cf = zone and zone.spawn and zone.spawn(f)
	popToken[f] = (popToken[f] or 0) + 1
	history[f] = nil
	if f.robot then
		f.popped = false
		if cf then
			f.model:PivotTo(cf)
		end
		if not noShield then
			f.shieldUntil = serverNow() + Constants.SHIELD_SECONDS
		end
	else
		f:SetAttribute("Popped", nil)
		r.Anchored = false
		if cf then
			r.CFrame = cf
			r.AssemblyLinearVelocity = Vector3.zero
		end
		if not noShield then
			f:SetAttribute("ShieldUntil", serverNow() + Constants.SHIELD_SECONDS)
			local c = f.Character
			if c and not c:FindFirstChild("SpawnShield") then
				local ff = Instance.new("ForceField")
				ff.Name = "SpawnShield"
				ff.Visible = true
				ff.Parent = c
				task.delay(Constants.SHIELD_SECONDS, function()
					if ff.Parent then
						ff:Destroy()
					end
				end)
			end
		end
	end
	self.Respawned:Fire(f)
end

-- Take a fighter out of combat right now (round over, left the round): no longer popped, not anchored.
function CombatService:Release(f)
	popToken[f] = (popToken[f] or 0) + 1
	history[f] = nil
	lastShot[f] = nil
	if f.robot then
		f.popped = false
		return
	end
	f:SetAttribute("Popped", nil)
	breakShield(f)
	local r = root(f)
	if r then
		r.Anchored = false
	end
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	loadout = registry.LoadoutService
	Net.on("Fire", function(player, origin, dir, firedAt)
		self:Fire(player, origin, dir, firedAt)
	end)
end

function CombatService:Start()
	RunService.Heartbeat:Connect(function()
		record()
		-- falling out of a zone: back to a spawn, no pop given
		for _, f in self:Fighters(nil) do
			local zone = self.zones[self.zone(f)]
			local r = root(f)
			if zone and r and zone.fallY and not self.isPopped(f) and r.Position.Y < zone.fallY() then
				self:Respawn(f, true)
			end
		end
	end)
end

function CombatService:OnPlayerReady(player)
	player:SetAttribute("Zone", "lobby")
end

function CombatService:OnPlayerLeaving(player)
	history[player] = nil
	lastShot[player] = nil
	popToken[player] = nil
	_ = data
end

return CombatService

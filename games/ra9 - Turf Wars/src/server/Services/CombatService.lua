--[[
Combat (master plan §5): health, the bow, the TNT and the blade, server arrows, thrown TNT, slashes, hits,
knockback, kills and credit.

The blade: the client sends Swing(direction) as you click (turned onto the nearest enemy in front, and lunging you at
them: SwingController); the server checks the cadence and finds the nearest enemy in reach (Weapons blade.range plus
Constants.BLADE_LUNGE from where the slash began, inside blade.arc degrees of where you swung, nothing solid between;
like an arrow, also where a laggy swinger saw them), and knocks it out (one slash, one knockout). A slash that reaches
no one keeps cutting for BLADE_WINDOW (someone stepping in is still caught), then is a whiff (the swinger is told,
Swing { whiff }). Two blades swung at each other within BLADE_CLASH clash: no knockout, both thrown apart. Bots'
lunges are moved here (a player's own client moves them). Everyone is told (Swing) so they see the slash.

The client only asks: Draw(true) when you start drawing, Shoot(origin, direction, shotId) when you let go. The
server times the draw itself (the charge is how long it has really been drawing, capped by the bow), checks you're
alive, it's the fight, the bow is ready (its cooldown; a magazine if a weapon had one), and that the arrow starts
near your head. Then it flies the arrow itself in ARROW_STEP steps (Formulas.arrowAt: the same curve the clients draw) against
every opponent's head and body spheres and every solid box (the map's, the structures'), and decides the hit, the
damage (by charge; heads x HEADSHOT), the knockback, and the kill. Everyone is told about the arrow (Arrow) so they
draw it, and where it stopped (ArrowEnd).

The TNT goes through Shoot too (the same checks: alive, the fight, its cooldown, near your head, never from the far
side of a wall): the charge is how hard it's thrown, and it flies as a lob (Formulas.lobVelocity, lobAt: heavier
than an arrow) in the same steps, against the same spheres and boxes. It goes off on the first thing it touches or
when its fuse runs out (TNT_FUSE): every enemy structure within TNT_RADIUS takes TNT_STRUCTURE damage (less further
out), every enemy within TNT_CORE with nothing solid between them and the blast is knocked out (through Damage, so
spawn protection, the spawn deck's safety and no friendly fire all hold), and the rest in the open within the radius
are thrown back. Your own team's structures and players are never touched. Everyone is told (Bomb when it's thrown,
Blast when it goes off) so they draw the lob and the explosion.

Health is the server's own (state.hp), mirrored onto the Humanoid for the health bar. Spawn protection, no friendly
fire, no damage outside the fight. Kills credit the last opponent to hit you; others who hit you in the last
ASSIST_WINDOW seconds get assists.

Kinder to thumbs and newcomers (one hit still knocks out): an arrow shot by touch (the shooter's "Device", capped at
TOUCH_HIT_MAX whatever is reported) is tested against bigger spheres (TOUCH_HIT_SCALE); a player in their first
NEW_PLAYER_MATCHES gets extra aim help on top of their device's (NewHelp: fading match by match); knocked out
COMEBACK_DOWNS times in a row without a knockout, your next life wears a comeback shield that blocks one hit (a
bubble everyone sees; Net "Shield"); and an enemy arrow passing close tells you where it came from (Net "Threat",
at most every NEAR_MISS_GAP; a hit says so through Hurt.from).

  CombatService:Spawned(player)            fresh health, protection, the bow you picked
  CombatService:Alive(player)
  CombatService:SetEnabled(on)             the fight phase
  CombatService:Damage(victim, amount, attacker, info)
  CombatService:Kill(victim, attacker, info)
  CombatService:Remove(player)             out of the fight, no kill (a spectating admin)
  CombatService:Heal(player)               full health
  CombatService:NewHelp(player) -> 0..1    the new-player help's strength (1 in the first match, 0 from the 3rd on)
  CombatService:Shielded(player) -> bool   wearing a comeback shield now
  CombatService:GiveShield(player) / :DropShield(player, why)
  CombatService:Device(player)             "touch" | "gamepad" | "keyboard" | nil (as their client reported it)
  CombatService:HitScale(player)           how much bigger the spheres are for their arrows (1 .. TOUCH_HIT_MAX)
  CombatService.Killed(victim, killer, info)   info: { weapon, head, assists = { players }, kind }
  CombatService.StructureHit(id, damage, attacker)
  CombatService.Shield(player, what, detail)   "granted" | "broken" | "expired" (the analytics)
  CombatService.Helped(player, detail)     the new-player help is on for them this match (once a match)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local SwordSkins = require(ReplicatedStorage.Shared.SwordSkins)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local CombatService = {
	Name = "CombatService",
	Dependencies = { "PlayerDataService", "TeamService", "ArenaService" },
	Killed = Signal.new("CombatService.Killed"), -- (victim, killer?, info)
	Damaged = Signal.new("CombatService.Damaged"), -- (victim, amount, attacker?, info)
	Shot = Signal.new("CombatService.Shot"), -- (player, weapon)
	StructureHit = Signal.new("CombatService.StructureHit"), -- (id, damage, attacker)
	Rejected = Signal.new("CombatService.Rejected"), -- (player, reason) a shot the server refused (the anti-cheat counts)
	Locked = Signal.new("CombatService.Locked"), -- (player, key) tried a weapon they haven't bought (ShopService offers it)
	Parried = Signal.new("CombatService.Parried"), -- (swinger, shooter) a blade knocked an arrow back
	Shield = Signal.new("CombatService.Shield"), -- (player, "granted" | "broken" | "expired", detail)
	Helped = Signal.new("CombatService.Helped"), -- (player, { matches, level }) the new-player help, once a match
}

local data, teams, arena
local states = {} -- [player] = { hp, alive, weapon, drawAt, ammo, reloadAt, readyAt, protectUntil, hits = { [attacker] = t },
-- downs (knocked out in a row without a knockout), shieldUntil (the comeback shield) }
local arrows = {} -- { id, by, team, weapon, origin, velocity, t, damage, knockback, head }
local nextArrow = 0
local bombs = {} -- { id, by, team, origin, velocity, t } thrown TNT in the air
local nextBomb = 0
local enabled = false
local history = {} -- [player] = { { t, pos } ... } the last second of each body's root, ~20 a second (lag)
local scored = {} -- [player] = true once they've knocked someone out this visit (the first-kill help ends)
local warnedAt = {} -- [player] = when they were last told about a near miss
local helpedIn = {} -- [player] = the match their new-player help was last logged in
local HISTORY_STEP, HISTORY_KEEP = 0.05, 1.1

local function now()
	return workspace:GetServerTimeNow()
end

-- The trail the shooter wears (drawn by every client; cosmetic only).
local function trailOf(player)
	local profile = data and data:Get(player)
	return profile and profile.equipped and profile.equipped.trail or nil
end

local function state(player)
	local s = states[player]
	if not s then
		s = { hp = Constants.MAX_HEALTH, alive = false, weapon = Weapons.DEFAULT, ammo = nil, readyAt = 0, hits = {} }
		states[player] = s
	end
	return s
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- A real player's ping in seconds (tests replace it); bots: 0
CombatService.pingOf = function(player)
	if typeof(player) ~= "Instance" then
		return 0
	end
	local ok, p = pcall(function()
		return player:GetNetworkPing()
	end)
	return ok and type(p) == "number" and p or 0
end

-- Where a body's root was at time t (from the history; nil if it wasn't kept)
local function rootAt(player, t)
	local h = history[player]
	if not h or #h == 0 then
		return nil
	end
	for i = #h, 1, -1 do
		local e = h[i]
		if e.t <= t then
			local n = h[i + 1]
			if n and n.t > e.t then
				return e.pos:Lerp(n.pos, math.clamp((t - e.t) / (n.t - e.t), 0, 1))
			end
			return e.pos
		end
	end
	return h[1].pos
end

local function record(t)
	for player, s in states do
		local r = s.alive and root(player)
		if r then
			local h = history[player]
			if not h then
				h = {}
				history[player] = h
			end
			table.insert(h, { t = t, pos = r.Position })
			while #h > 0 and t - h[1].t > HISTORY_KEEP do
				table.remove(h, 1)
			end
		else
			history[player] = nil
		end
	end
end

local function mirror(player, s)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = Constants.MAX_HEALTH
		hum.Health = math.max(s.alive and 1 or 0, s.hp)
	end
end

function CombatService:Push(player)
	local s = state(player)
	local w = Weapons.get(s.weapon)
	Net.fire(player, "Me", {
		team = teams:Team(player),
		alive = s.alive,
		hp = s.hp,
		weapon = s.weapon,
		ammo = s.ammo,
		mag = w and w.mag,
		protected = (s.protectUntil or 0) > now(),
	})
end

-- The bow in your hand that everyone else sees (your own client hides it: you see the viewmodel). Welded to the
-- left hand, massless, out of every query (the hit spheres are the server's, not these parts).
function CombatService:HoldBow(player, key)
	local c = player.Character
	local hand = c and (c:FindFirstChild("LeftHand") or c:FindFirstChild("Left Arm"))
	if not hand then
		return nil
	end
	local old = c:FindFirstChild("HeldBow")
	if old then
		old:Destroy()
	end
	local team = teams:Team(player)
	local color = Constants.TEAM_COLOR[team or ""] or Constants.WHITE
	local model = Instance.new("Model")
	model.Name = "HeldBow"
	model:SetAttribute("Weapon", key)
	local function part(name, size, c3, offset)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = c3
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	if key == "tnt" then
		-- a bundle of red sticks in the right hand, a band round them, a fuse
		local right = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		if right then
			hand = right
		end
		for i, off in { -0.17, 0, 0.17 } do
			local at = CFrame.new(off, -0.5, i == 2 and -0.12 or 0) * CFrame.Angles(0, 0, math.rad(90))
			part("Stick", Vector3.new(0.9, 0.3, 0.3), Constants.TNT_RED, at).Shape = Enum.PartType.Cylinder
		end
		part("Band", Vector3.new(0.6, 0.14, 0.36), Color3.fromRGB(30, 30, 34), CFrame.new(0, -0.5, -0.04))
		part("Fuse", Vector3.new(0.05, 0.4, 0.05), Color3.fromRGB(30, 30, 34), CFrame.new(0, -0.05, -0.04))
	elseif key == "blade" then
		-- held in the right hand for everyone else: a grip, a guard, the blade
		local right = c:FindFirstChild("RightHand") or c:FindFirstChild("Right Arm")
		if right then
			hand = right
		end
		-- (in the sword skin they wear: Shared/SwordSkins lays it out; the client brings it alive, FlairController)
		for _, s in SwordSkins.specs(SwordSkins.lookOf(player:GetAttribute("LookSword")), team) do
			local p = part(s.name, s.size, s.color, CFrame.new(0, -0.3, 0) * s.offset)
			p.Material, p.Transparency = Enum.Material[s.material] or p.Material, s.transparency or 0
		end
	else
		local len = 1.6
		part("Grip", Vector3.new(0.25, 0.6, 0.25), color, CFrame.new(0, -0.3, 0))
		part(
			"Upper",
			Vector3.new(0.15, len, 0.15),
			Constants.WHITE,
			CFrame.new(0, -0.3 + len / 2 + 0.25, -0.2) * CFrame.Angles(math.rad(-15), 0, 0)
		)
		part(
			"Lower",
			Vector3.new(0.15, len, 0.15),
			Constants.WHITE,
			CFrame.new(0, -0.3 - len / 2 - 0.25, -0.2) * CFrame.Angles(math.rad(15), 0, 0)
		)
		part("String", Vector3.new(0.04, len * 2 + 0.4, 0.04), Color3.fromRGB(30, 30, 34), CFrame.new(0, -0.3, 0.25))
	end
	model.Parent = c
	return model
end

-- Still waiting for their first ever knockout (a real player whose saved kills are 0 and who hasn't scored yet this
-- visit): their shots are helped onto an enemy, they respawn faster and are shielded longer (Constants.FIRST_KILL_*).
CombatService.firstKillHelp = true -- (tests that aren't about it turn it off: tests/FeelSmoke checks it)
function CombatService:Novice(player)
	if not CombatService.firstKillHelp then
		return false
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or scored[player] then
		return false
	end
	local profile = data and data:Get(player)
	local st = profile and profile.stats
	return st ~= nil and (st.kills or 0) == 0
end

-- How they play, as their client last reported it (ProgressService only takes "touch", "gamepad" or "keyboard"),
-- or nil. Bots: nil.
function CombatService:Device(player)
	if typeof(player) ~= "Instance" then
		return nil
	end
	local d = player:GetAttribute("Device")
	return (d == "touch" or d == "gamepad" or d == "keyboard") and d or nil
end

-- How much bigger the target spheres are for this player's arrows: a thumb's are TOUCH_HIT_SCALE, a mouse's and a
-- pad's plain. Never past TOUCH_HIT_MAX, whatever the client says.
function CombatService:HitScale(player)
	local scale = Constants.TOUCH_HIT_SCALE[self:Device(player) or ""] or 1
	return math.clamp(scale, 1, Constants.TOUCH_HIT_MAX)
end

-- The new-player help (their first NEW_PLAYER_MATCHES finished matches after the tutorial): 1 in the first, fading
-- by a step each match (2/3, 1/3), 0 after. Bots and players without a save: 0.
CombatService.newPlayerHelp = true -- (tests that aren't about it turn it off: tests/FeelSmoke checks it)
function CombatService:NewHelp(player)
	if not CombatService.newPlayerHelp or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return 0
	end
	local profile = data and data:Get(player)
	local played = profile and profile.stats and profile.stats.matches
	if type(played) ~= "number" then
		return 0
	end
	local n = Constants.NEW_PLAYER_MATCHES
	return math.clamp((n - played) / n, 0, 1)
end

-- The comeback shield ----------------------------------------------------------------------------------------------
-- A see-through bubble round the body (made here, so everyone sees it): massless, out of every query and collision
-- (the hit spheres are the server's, not this part).
local function bubble(player, on)
	local c = player.Character
	local old = c and c:FindFirstChild("ComebackShield")
	if old then
		old:Destroy()
	end
	if c then
		c:SetAttribute("Shield", on or nil)
	end
	local r = on and c and c:FindFirstChild("HumanoidRootPart")
	if not r then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = "ComebackShield"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * Constants.COMEBACK_BUBBLE
	p.Color = Color3.fromRGB(120, 220, 255)
	p.Material = Enum.Material.ForceField
	p.Transparency = 0.2
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.CFrame = r.CFrame * CFrame.new(0, 0.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = r, p
	weld.Parent = p
	p.Parent = c
	return p
end

CombatService.comebackShield = true -- (tests that aren't about it turn it off: tests/FeelSmoke checks it)

function CombatService:Shielded(player)
	local s = states[player]
	return s ~= nil and (s.shieldUntil or 0) > now()
end

-- Put a shield on them for this life (only when they have none: it never stacks)
function CombatService:GiveShield(player, why)
	local s = state(player)
	if self:Shielded(player) then
		return false
	end
	s.shieldUntil = now() + Constants.COMEBACK_SECONDS
	player:SetAttribute("Shield", true)
	bubble(player, true)
	Net.fire(player, "Shield", { kind = "on", by = player.UserId, seconds = Constants.COMEBACK_SECONDS })
	self.Shield:Fire(player, "granted", { downs = s.downs or 0, why = why })
	return true
end

-- The shield goes: "broken" (it blocked a hit: a pop everyone sees and hears), "kill" (they scored), "time", "down"
function CombatService:DropShield(player, why, by)
	local s = states[player]
	if not s or not s.shieldUntil then
		return false
	end
	s.shieldUntil = nil
	if typeof(player) == "Instance" then
		player:SetAttribute("Shield", nil)
	end
	local r = root(player)
	bubble(player, false)
	if why == "broken" then
		Net.fireAll("Shield", {
			kind = "break",
			by = player.UserId,
			pos = r and r.Position + Vector3.new(0, 1, 0) or nil,
			attacker = by and by.UserId or nil,
		})
		self.Shield:Fire(player, "broken", { by = by and (by.IsBot and "bot" or "player") or nil })
	else
		Net.fire(player, "Shield", { kind = "off", by = player.UserId, why = why })
		self.Shield:Fire(player, "expired", { why = why })
	end
	return true
end

function CombatService:Spawned(player)
	local s = state(player)
	s.hp = Constants.MAX_HEALTH
	s.alive = true
	s.drawAt = nil
	s.hits = {}
	local novice = self:Novice(player)
	s.protectUntil = now() + (novice and Constants.SPAWN_PROTECT_NEW or Constants.SPAWN_PROTECT)
	if typeof(player) == "Instance" then
		player:SetAttribute("Novice", novice or nil) -- (the client marks their first target)
	end
	s.attacked = false
	local profile = data:Get(player)
	local pick = profile and profile.settings.weapon
	s.weapon = Weapons.get(pick) and pick or s.weapon or Weapons.DEFAULT
	if not CombatService.allowed(s.weapon, player) then
		s.weapon = Weapons.DEFAULT -- (the blade only comes out in the CHARGE; the TNT once it's bought)
	end
	local w = Weapons.get(s.weapon)
	s.ammo = w.mag
	s.reloadAt = nil
	s.readyAt = 0
	-- (alive is set above whatever happens here: a bow that fails to show must never leave them RESPAWNING)
	local ok, err = pcall(mirror, player, s)
	if not ok then
		warn("[CombatService] mirror failed: " .. tostring(err))
	end
	ok, err = pcall(self.HoldBow, self, player, s.weapon)
	if not ok then
		warn("[CombatService] hold bow failed: " .. tostring(err))
	end
	-- a losing streak (COMEBACK_DOWNS knockouts in a row without one of theirs): this life has a comeback shield
	local streak = (s.downs or 0) >= Constants.COMEBACK_DOWNS
	if CombatService.comebackShield and streak and typeof(player) == "Instance" and player:IsA("Player") then
		ok, err = pcall(self.GiveShield, self, player, "streak")
		if ok then
			s.downs = 0
		else
			warn("[CombatService] shield failed: " .. tostring(err))
		end
	end
	-- (the new-player help, logged once a match for the analytics)
	local help = self:NewHelp(player)
	local matchId = workspace:GetAttribute("MatchId")
	if help > 0 and helpedIn[player] ~= matchId then
		helpedIn[player] = matchId
		self.Helped:Fire(player, {
			matches = profile and profile.stats and profile.stats.matches or 0,
			level = math.floor(help * 100 + 0.5) / 100,
			device = self:Device(player),
		})
	end
	self:Push(player)
end

function CombatService:Alive(player)
	local s = states[player]
	return s ~= nil and s.alive
end

function CombatService:Health(player)
	return state(player).hp
end

function CombatService:Weapon(player)
	return state(player).weapon
end

function CombatService:SetEnabled(on)
	enabled = on
	if not on then
		for _, s in states do
			s.drawAt = nil
		end
	end
end

function CombatService:Enabled()
	return enabled
end

function CombatService:Kill(victim, attacker, info)
	local s = state(victim)
	if not s.alive then
		return false
	end
	s.alive = false
	s.hp = 0
	s.drawAt = nil
	info = info or {}
	-- assists: other opponents who hit you within the window
	local assists = {}
	local t = now()
	for p, at in s.hits do
		if p ~= attacker and p.Parent and t - at <= Constants.ASSIST_WINDOW then
			table.insert(assists, p)
		end
	end
	info.assists = assists
	mirror(victim, s)
	self:Push(victim)
	if attacker and attacker ~= victim and not scored[attacker] and typeof(attacker) == "Instance" then
		scored[attacker] = true -- (their first knockout this visit: the help ends)
		attacker:SetAttribute("Novice", nil)
	end
	-- the losing streak (a menu Reset doesn't count); a knockout of your own ends it, and any shield you wear
	if s.shieldUntil then
		self:DropShield(victim, "down")
	end
	if info.kind ~= "reset" then
		s.downs = (s.downs or 0) + 1
	end
	local as = attacker and attacker ~= victim and states[attacker]
	if as then
		as.downs = 0
		if as.shieldUntil then
			self:DropShield(attacker, "kill")
		end
	end
	self.Killed:Fire(victim, attacker, info)
	return true
end

-- Out of the fight without going down (no kill, no feed): a spectating admin. Nothing can hit them.
function CombatService:Remove(player)
	local s = state(player)
	s.alive = false
	s.hp = 0
	s.drawAt = nil
	s.hits = {}
	for _, o in states do
		o.hits[player] = nil
	end
	self:Push(player)
end

-- Back to full health (an admin's heal).
function CombatService:Heal(player)
	local s = state(player)
	if not s.alive then
		return false
	end
	s.hp = Constants.MAX_HEALTH
	mirror(player, s)
	self:Push(player)
	return true
end

function CombatService:Damage(victim, amount, attacker, info)
	local s = state(victim)
	if not s.alive or amount <= 0 then
		return false
	end
	if (s.protectUntil or 0) > now() then
		return false
	end
	-- safe on your own spawn deck until you shoot or swing (it's open, so walls don't do it)
	if attacker and not s.attacked and arena and arena:OnDeck(victim, teams:Team(victim)) then
		return false
	end
	if attacker then
		if teams:Team(attacker) == teams:Team(victim) then
			return false -- (no friendly fire)
		end
	end
	-- the comeback shield takes the whole hit, and pops
	if self:Shielded(victim) then
		self:DropShield(victim, "broken", attacker)
		return false
	end
	if attacker then
		s.hits[attacker] = now()
	end
	s.hp = math.max(0, s.hp - amount)
	mirror(victim, s)
	self.Damaged:Fire(victim, amount, attacker, info or {})
	if s.hp <= 0 then
		self:Kill(victim, attacker, info)
		return true, true
	end
	return true, false
end

-- Arrows --------------------------------------------------------------------------------------------------------
-- (lag and the first knockout: how far back to also look for each target, and how much wider the spheres are)
local function forgiveness(arrow)
	local rewind, extra = 0, 0
	local by = arrow.by
	if typeof(by) == "Instance" then
		local ping = math.max(0, CombatService.pingOf(by) or 0)
		rewind = math.min(ping, Constants.LAG_REWIND_MAX)
		extra = math.clamp((ping - Constants.LAG_FREE) / 0.1 * Constants.LAG_RADIUS, 0, Constants.LAG_RADIUS_MAX)
	end
	if arrow.novice then
		extra += Constants.FIRST_KILL_RADIUS
	end
	return rewind, extra
end

local function hitPlayers(arrow, a, b)
	local best, bestT, bestHead
	local rewind, extra = forgiveness(arrow)
	local scale = math.clamp(arrow.scale or 1, 1, Constants.TOUCH_HIT_MAX) -- (a thumb's arrow: bigger spheres)
	local past = rewind > 0.01 and now() - rewind or nil
	for player, s in states do
		if s.alive and player ~= arrow.by and player.Parent and teams:Team(player) ~= arrow.team then
			local r = root(player)
			if r then
				-- where they are now, and where the shooter saw them (their ping ago)
				local spots = { r.Position }
				local was = past and rootAt(player, past)
				if was and (was - r.Position).Magnitude > 0.05 then
					table.insert(spots, was)
				end
				for _, p in spots do
					local head = Formulas.segmentSphere(
						a,
						b,
						p + Vector3.new(0, 2.6, 0),
						Constants.HIT_RADIUS_HEAD * scale + extra * 0.5
					)
					local body = Formulas.segmentSphere(
						a,
						b,
						p + Vector3.new(0, 0.2, 0),
						Constants.HIT_RADIUS_BODY * scale + extra
					)
					local t, isHead = nil, false
					if head and (not body or head <= body + 0.02) then
						t, isHead = head, true
					elseif body then
						t = body
					end
					if t and (not bestT or t < bestT) then
						best, bestT, bestHead = player, t, isHead
					end
				end
			end
		end
	end
	return best, bestT, bestHead
end

local function partShape(p)
	local ok, shape = pcall(function()
		return p:IsA("Part") and p.Shape.Name or "Block"
	end)
	return ok and shape or "Block"
end

-- Does the part still fill the box it was entered with? (the floor's strips are one solid box made of many
-- moving parts: those stay a plain box)
local function sameBox(p, s)
	local ok, same = pcall(function()
		local cf, half = p.CFrame, p.Size / 2
		local ext = Vector3.new(
			math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z,
			math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z,
			math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
		)
		return ((cf.Position - ext) - s.min).Magnitude < 0.2 and ((cf.Position + ext) - s.max).Magnitude < 0.2
	end)
	return ok and same
end

local function hitSolids(a, b)
	local bestT, bestId
	local mn = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local mx = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	for _, s in arena:Solids() do
		-- (a cheap reject: the step's own box)
		if
			s.max.X >= mn.X
			and s.min.X <= mx.X
			and s.max.Y >= mn.Y
			and s.min.Y <= mx.Y
			and s.max.Z >= mn.Z
			and s.min.Z <= mx.Z
		then
			local t = Formulas.segmentBox(a, b, s.min, s.max)
			if t and (s.parts or (s.part and sameBox(s.part, s))) then
				-- (the box round it only says "maybe": the real shapes inside decide, so gaps let arrows through)
				t = nil
				for _, p in s.parts or { s.part } do
					local pt = Formulas.segmentPart(a, b, p.CFrame, p.Size, partShape(p))
					if pt and (not t or pt < t) then
						t = pt
					end
				end
			end
			if t and (not bestT or t < bestT) then
				bestT, bestId = t, s.id
			end
		end
	end
	return bestT, bestId
end

-- An enemy arrow passing close: each player it comes within NEAR_MISS_RADIUS of (once an arrow, and at most every
-- NEAR_MISS_GAP for anyone) is told where it came from, for the marker toward the shooter (HitDirectionController)
function CombatService:_nearMiss(arrow, a, b, victim)
	local t
	for player, s in states do
		if
			s.alive
			and player ~= victim
			and player ~= arrow.by
			and typeof(player) == "Instance"
			and player.Parent
			and teams:Team(player) ~= arrow.team
			and not (arrow.near and arrow.near[player])
		then
			local r = root(player)
			if r and Formulas.segmentSphere(a, b, r.Position + Vector3.new(0, 1, 0), Constants.NEAR_MISS_RADIUS) then
				arrow.near = arrow.near or {}
				arrow.near[player] = true
				t = t or now()
				if t - (warnedAt[player] or -math.huge) >= Constants.NEAR_MISS_GAP then
					warnedAt[player] = t
					Net.fire(player, "Threat", { from = arrow.origin, by = arrow.by and arrow.by.UserId })
				end
			end
		end
	end
end

function CombatService:_finish(arrow, pos, kind)
	arrow.done = true
	Net.fireAll("ArrowEnd", { id = arrow.id, pos = pos, kind = kind })
end

function CombatService:_step(dt)
	for i = #arrows, 1, -1 do
		local arrow = arrows[i]
		local t0 = arrow.t
		local t1 = t0 + dt
		local a = Formulas.arrowAt(arrow.origin, arrow.velocity, t0)
		local b = Formulas.arrowAt(arrow.origin, arrow.velocity, t1)
		arrow.t = t1
		local victim, vt, head = hitPlayers(arrow, a, b)
		local st, sid = hitSolids(a, b)
		local hits = victim and (not st or vt <= st)
		-- (the near misses: as far as it really flew this step, up to what it struck)
		local upTo = (hits and vt) or st
		self:_nearMiss(arrow, a, upTo and a:Lerp(b, upTo) or b, hits and victim or nil)
		if hits then
			local at = a:Lerp(b, vt)
			arrow.hitT = t0 + dt * vt -- (when in its flight it struck: the kill cam replays up to here)
			table.remove(arrows, i)
			if not self:_parry(arrow, victim, at, (b - a).Unit) then
				self:_hitPlayer(arrow, victim, head, at, (b - a).Unit)
			end
		elseif st then
			local at = a:Lerp(b, st)
			if sid then
				local w = Weapons.get(arrow.weapon)
				local blast = { pos = at, power = 0.35, dir = (b - a).Unit, team = arrow.team }
				self.StructureHit:Fire(sid, arrow.damage * (w and w.structure or 1), arrow.by, blast)
			end
			self:_finish(arrow, at, sid and "structure" or "world")
			table.remove(arrows, i)
		elseif t1 >= Constants.ARROW_LIFETIME or not arena:Inside(b) then
			self:_finish(arrow, b, "world")
			table.remove(arrows, i)
		end
	end
	for i = #bombs, 1, -1 do
		local bomb = bombs[i]
		local t0 = bomb.t
		local t1 = math.min(t0 + dt, Constants.TNT_FUSE)
		local a = Formulas.lobAt(bomb.origin, bomb.velocity, t0)
		local b = Formulas.lobAt(bomb.origin, bomb.velocity, t1)
		bomb.t = t1
		local victim, vt = hitPlayers(bomb, a, b)
		local st = hitSolids(a, b)
		local hit = (victim and (not st or vt <= st)) and vt or st
		if hit then
			-- (it goes off just short of what it touched, so the blast's line of sight starts in the open)
			local at = a:Lerp(b, hit)
			local back = (b - a).Magnitude > 0.01 and (b - a).Unit * 0.4 or Vector3.zero
			table.remove(bombs, i)
			self:_explode(bomb, at - back)
		elseif t1 >= Constants.TNT_FUSE or not arena:Inside(b) then
			table.remove(bombs, i)
			self:_explode(bomb, b)
		end
	end
end

-- The TNT goes off at pos: enemy structures in the radius take the blast, enemies in the core with a clear line to it
-- are knocked out, the rest of them in the open within the radius are thrown back. Never your own team.
function CombatService:_explode(bomb, pos)
	local by = bomb.by
	local attacker = by and by.Parent and by or nil
	-- the floor under it (where the shockwave runs)
	local down = 14
	local gt = hitSolids(pos + Vector3.new(0, 0.1, 0), pos - Vector3.new(0, down, 0))
	local ground = gt and (pos.Y + 0.1 - gt * (down + 0.1)) or pos.Y
	Net.fireAll("Blast", {
		id = bomb.id,
		pos = pos,
		team = bomb.team,
		by = by and by.UserId,
		ground = ground,
		radius = Constants.TNT_RADIUS,
		core = Constants.TNT_CORE,
	})
	local lo, hi = Constants.TNT_STRUCTURE[2], Constants.TNT_STRUCTURE[1]
	for _, sol in arena:Solids() do
		if sol.id then
			local d = Formulas.boxDistance(pos, sol.min, sol.max)
			if d <= Constants.TNT_RADIUS then
				local k = Formulas.blast(d)
				-- (BuildService leaves the thrower's own team's pieces alone: blast.team)
				local blast = { pos = pos, power = 0.75 + 0.25 * k, team = bomb.team, tnt = true }
				self.StructureHit:Fire(sol.id, lo + (hi - lo) * k, attacker, blast)
			end
		end
	end
	-- (the structures it broke are gone now, so what was behind them is in the open)
	local t = now()
	local hits, kills = 0, 0
	for player, st in states do
		local team = teams:Team(player)
		local r = st.alive and player.Parent and team ~= bomb.team and root(player)
		if r then
			local body = r.Position + Vector3.new(0, 0.2, 0)
			local d = (body - pos).Magnitude
			if d <= Constants.TNT_RADIUS and not hitSolids(pos, body) then
				local away = body - pos
				away = Vector3.new(away.X, 0, away.Z)
				away = away.Magnitude > 0.01 and away.Unit or Vector3.new(1, 0, 0)
				if d <= Constants.TNT_CORE then
					local info = { weapon = "tnt", head = false, kind = "blast", cam = { impact = pos } }
					local ok, killed = self:Damage(player, Constants.MAX_HEALTH, attacker, info)
					if ok then
						hits += 1
						kills += killed and 1 or 0
						Net.fire(
							player,
							"Hurt",
							{ amount = Constants.MAX_HEALTH, from = pos, knock = Vector3.zero, blast = true }
						)
					end
				else
					-- thrown back (unless spawn protection or the deck keeps them safe)
					local safe = (st.protectUntil or 0) > t or (not st.attacked and arena:OnDeck(player, team))
					if not safe then
						local push = Constants.TNT_PUSH * math.max(0.3, Formulas.blast(d))
						local kb = away * math.min(push, Constants.KNOCKBACK_CAP) + Vector3.new(0, push * 0.45, 0)
						pcall(function()
							r.AssemblyLinearVelocity += kb
						end)
						player:SetAttribute("AcGrace", os.clock() + 1.5) -- (the push is ours: the anti-cheat lets it go)
						Net.fire(player, "Hurt", { amount = 0, from = pos, knock = kb, blast = true })
					end
				end
			end
		end
	end
	if attacker and hits > 0 then
		Net.fire(attacker, "Hit", { damage = Constants.MAX_HEALTH, head = false, kill = kills > 0, pos = pos })
	end
	return hits, kills
end

-- A TNT thrown (from Shoot, already checked): it leaves near your head in a lob, the charge how hard
function CombatService:_throw(player, w, origin, direction, charge, shotId)
	local shot = Formulas.shot(w, charge)
	nextBomb += 1
	local bomb = {
		id = nextBomb,
		by = player,
		team = teams:Team(player),
		origin = origin,
		velocity = Formulas.lobVelocity(direction, shot.speed),
		t = 0,
		charge = charge,
		shotId = shotId,
	}
	table.insert(bombs, bomb)
	Net.fireAll("Bomb", {
		id = bomb.id,
		by = player.UserId,
		team = bomb.team,
		origin = origin,
		velocity = bomb.velocity,
		at = now(),
		shotId = shotId,
	})
	self.Shot:Fire(player, w.key)
	self:Push(player)
	return bomb
end

-- A blade swing in the last PARRY_SECONDS, facing the arrow: it's knocked away and flies back at whoever shot it
-- (now the swinger's arrow). true when parried.
function CombatService:_parry(arrow, victim, at, dir)
	local s = states[victim]
	if not s or (s.parryUntil or 0) < now() or not s.parryDir then
		return false
	end
	if s.parryDir:Dot(-Vector3.new(dir.X, 0, dir.Z).Unit) < Constants.PARRY_DOT then
		return false -- (from the side or behind: the blade wasn't in the way)
	end
	self:_finish(arrow, at, "parry")
	local speed = arrow.velocity.Magnitude
	local back = -dir
	local shooter = arrow.by
	local sr = shooter and shooter.Parent and root(shooter)
	if sr then
		local to = (sr.Position + Vector3.new(0, 1.5, 0)) - at
		if to.Magnitude > 1 then
			back = to.Unit
		end
	end
	local origin = at + back * 1.5
	nextArrow += 1
	local again = {
		id = nextArrow,
		by = victim,
		team = teams:Team(victim),
		weapon = arrow.weapon,
		origin = origin,
		velocity = back * speed,
		t = 0,
		damage = arrow.damage,
		knockback = arrow.knockback,
		charge = arrow.charge,
	}
	table.insert(arrows, again)
	Net.fireAll("Arrow", {
		id = again.id,
		by = victim.UserId,
		team = again.team,
		weapon = again.weapon,
		origin = origin,
		velocity = again.velocity,
		at = now(),
		trail = trailOf(victim),
		parried = true,
	})
	Net.fire(victim, "Hit", { damage = 0, parry = true, pos = at })
	self.Parried:Fire(victim, shooter)
	return true
end

function CombatService:_hitPlayer(arrow, victim, head, at, dir)
	local amount = math.floor(arrow.damage * (head and Constants.HEADSHOT or 1) + 0.5)
	local shooter = arrow.by
	local info = { weapon = arrow.weapon, head = head, kind = "arrow" }
	-- (what the victim's kill cam replays: the arrow from the bow to where it struck)
	info.cam = { origin = arrow.origin, velocity = arrow.velocity, t = arrow.hitT or arrow.t, impact = at }
	local ok, killed = self:Damage(victim, amount, shooter.Parent and shooter or nil, info)
	self:_finish(arrow, at, "player")
	if not ok then
		return
	end
	-- knockback: along the arrow, flattened, a little up; capped. The victim's client applies it (it owns its body)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
	local kb = flat * math.min(arrow.knockback, Constants.KNOCKBACK_CAP) + Vector3.new(0, arrow.knockback * 0.25, 0)
	local r = root(victim)
	if r and not killed then
		pcall(function()
			r.AssemblyLinearVelocity += kb
		end)
	end
	victim:SetAttribute("AcGrace", os.clock() + 1.5) -- (the knockback is ours: the anti-cheat lets it go)
	Net.fire(victim, "Hurt", { amount = amount, from = arrow.origin, knock = kb, head = head, by = shooter.UserId })
	if shooter.Parent then
		Net.fire(shooter, "Hit", { damage = amount, head = head, kill = killed, victim = victim.UserId })
	end
end

-- Start or stop drawing (Net "Draw"; bots call it directly). The charge is timed from here.
function CombatService:Draw(player, on)
	local s = state(player)
	if on == true and s.alive and enabled then
		s.drawAt = now()
	elseif on == false then
		s.drawAt = nil
	end
end

-- Is the straight line from a to b blocked by the map or a structure? (bots check their line of fire with it)
function CombatService:Blocked(a, b)
	return (hitSolids(a, b)) ~= nil
end

-- A new player's whisper of aim help: a shot that's already nearly on an enemy (inside AIM_ASSIST_CONE degrees of
-- where the arrow would have to go, drop included) turns a little onto them (AIM_ASSIST_PULL of the gap, at most
-- AIM_ASSIST_MAX degrees). Their first matches feel natural; a real miss still misses. Everyone sees the same arrow.
-- How much help this player's shots get: { cone, pull, max, lead?, range?, clear? }, or nil. The first knockout
-- (Novice): a shot anywhere near an enemy in the open goes onto them, leading them. Else by device (a thumb, a
-- stick), or the whisper for anyone in their first few matches; whichever helps most.
function CombatService:AssistFor(player, plain)
	if typeof(player) ~= "Instance" then
		return nil -- (bots aim on their own)
	end
	if plain ~= true and self:Novice(player) then
		return {
			cone = Constants.FIRST_KILL_CONE,
			pull = 1,
			max = Constants.FIRST_KILL_CONE,
			lead = true,
			range = Constants.FIRST_KILL_RANGE,
			clear = true,
		}
	end
	local best
	local dev = Constants.AIM_ASSIST_DEVICE[player:GetAttribute("Device") or ""]
	if dev then
		best = { cone = dev.cone, pull = dev.pull, max = dev.max }
	end
	local profile = data:Get(player)
	if profile and ((profile.stats and profile.stats.matches) or 0) < Constants.AIM_ASSIST_MATCHES then
		if not best or best.max < Constants.AIM_ASSIST_MAX then
			best =
				{ cone = Constants.AIM_ASSIST_CONE, pull = Constants.AIM_ASSIST_PULL, max = Constants.AIM_ASSIST_MAX }
		end
	end
	-- their first matches after the tutorial: more on top, fading match by match, never past NEW_PLAYER_AIM_CAP
	-- (and never less than the device gives anyway)
	local help = self:NewHelp(player)
	if help > 0 then
		local base = best or { cone = 0, pull = 0, max = 0 }
		local add, cap = Constants.NEW_PLAYER_AIM, Constants.NEW_PLAYER_AIM_CAP
		best = {}
		for _, k in { "cone", "pull", "max" } do
			best[k] = math.max(base[k], math.min(base[k] + add[k] * help, cap[k]))
		end
	end
	return best
end

-- direction turned by the help (AssistFor), and whether it was. (The first knockout's help only counts enemies in
-- the clear; with none, the ordinary help still applies.)
function CombatService:Assist(player, origin, direction, speed, plain)
	local how = self:AssistFor(player, plain)
	if not how then
		return direction, false
	end
	if how.clear and plain == nil then
		local d, helped = self:Assist(player, origin, direction, speed, "first")
		if helped then
			return d, true
		end
		return self:Assist(player, origin, direction, speed, true)
	end
	local mine = teams:Team(player)
	local best, bestAngle
	for other, os_ in states do
		local r = os_.alive and other ~= player and teams:Team(other) ~= mine and root(other)
		if r then
			local target = r.Position + Vector3.new(0, 0.6, 0)
			local dist = (target - origin).Magnitude
			if not how.range or dist <= how.range then
				local tt = dist / math.max(speed, 1)
				if how.lead then
					-- (where they'll be when it gets there)
					local v = Vector3.zero
					pcall(function()
						v = r.AssemblyLinearVelocity
					end)
					target += Vector3.new(v.X, 0, v.Z) * tt
					tt = (target - origin).Magnitude / math.max(speed, 1)
				end
				local aim = target + Vector3.new(0, 0.5 * Constants.GRAVITY * tt * tt, 0) - origin
				if aim.Magnitude > 1 and not (how.clear and hitSolids(origin, target)) then
					local ideal = aim.Unit
					local angle = math.deg(math.acos(math.clamp(direction:Dot(ideal), -1, 1)))
					if angle <= how.cone and (not bestAngle or angle < bestAngle) then
						best, bestAngle = ideal, angle
					end
				end
			end
		end
	end
	if not best or bestAngle < 0.01 then
		return direction, false
	end
	local turn = math.min(bestAngle * how.pull, how.max)
	return direction:Lerp(best, turn / bestAngle).Unit, turn > 0.5
end

-- The shot itself (Net "Shoot"): validated, then an arrow.
function CombatService:Shoot(player, origin, direction, shotId)
	if not enabled or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return nil
	end
	local s = state(player)
	if not s.alive then
		self.Rejected:Fire(player, "dead")
		return nil
	end
	local w = Weapons.get(s.weapon)
	if w.melee then
		return nil -- (the blade swings through Swing, never shoots)
	end
	if direction ~= direction or origin ~= origin then
		return nil -- (NaN)
	end
	if shotId ~= nil and (type(shotId) ~= "number" or shotId ~= shotId or math.abs(shotId) > 2 ^ 31) then
		shotId = nil -- (only a plain number goes back out to everyone)
	end
	local t = now()
	local ready = w.throw and (s.throwAt or 0) or (s.readyAt or 0)
	if t < ready - 0.08 then
		self.Rejected:Fire(player, "rate") -- (faster than the bow can shoot, beyond a little lag)
		return nil
	elseif t < ready then
		return nil
	end
	if w.mag then
		if s.reloadAt and t < s.reloadAt then
			self.Rejected:Fire(player, "reload")
			return nil
		end
		if s.reloadAt and t >= s.reloadAt then
			s.reloadAt, s.ammo = nil, w.mag
		end
		if (s.ammo or 0) <= 0 then
			return nil
		end
	end
	local r = root(player)
	if not r then
		return nil
	end
	local head = r.Position + Vector3.new(0, 1.5, 0)
	if (origin - head).Magnitude > Constants.ORIGIN_SLACK then
		origin = head -- (too far from you: it starts from your head instead)
		self.Rejected:Fire(player, "origin")
	elseif (origin - head).Magnitude > 0.5 and hitSolids(head, origin) then
		origin = head -- (never from the far side of a wall)
	end
	if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return nil
	end
	direction = direction.Unit
	s.attacked = true -- (shooting gives up the spawn deck's safety)
	local charge = w.draw > 0 and Formulas.charge(w, s.drawAt and (t - s.drawAt) or 0) or 1
	s.drawAt = nil
	if w.throw then
		s.throwAt = t + w.cooldown -- (the TNT has its own cooldown: the bow is ready again at once)
	else
		s.readyAt = t + w.cooldown
	end
	if w.throw then
		return self:_throw(player, w, origin, direction, charge, shotId)
	end
	local shot = Formulas.shot(w, charge)
	local sent = direction
	local helped
	direction, helped = self:Assist(player, origin, direction, shot.speed)
	if w.mag then
		s.ammo -= 1
		if s.ammo <= 0 then
			s.reloadAt = t + w.reload
		end
	end
	nextArrow += 1
	local arrow = {
		id = nextArrow,
		by = player,
		team = teams:Team(player),
		weapon = w.key,
		origin = origin,
		velocity = direction * shot.speed,
		t = 0,
		damage = shot.damage,
		knockback = shot.knockback,
		charge = charge,
		shotId = shotId,
		novice = self:Novice(player) or nil,
		scale = self:HitScale(player), -- (shot by touch: bigger spheres)
	}
	table.insert(arrows, arrow)
	Net.fireAll("Arrow", {
		id = arrow.id,
		by = player.UserId,
		team = arrow.team,
		weapon = w.key,
		origin = origin,
		velocity = arrow.velocity,
		at = t,
		shotId = shotId,
		trail = trailOf(player),
		-- (the shooter's own client drew it where they aimed: when the help turned it noticeably, it redraws it here)
		assisted = (helped and (direction - sent).Magnitude > 0.02) or nil,
	})
	self.Shot:Fire(player, w.key)
	if w.mag then
		self:Push(player)
	end
	return arrow
end

-- The blade is only out in the CHARGE (the fight's last seconds, MatchService sets workspace "Charge"): bows only
-- the rest of the time
function CombatService.allowed(key, player)
	local w = Weapons.get(key)
	return w ~= nil and (not w.melee or workspace:GetAttribute("Charge") == true) and not Weapons.locked(key, player)
end

-- The blade ----------------------------------------------------------------------------------------------------
-- A slash (Net "Swing"; bots call it too) lunges the swinger in and keeps cutting for BLADE_WINDOW: it hits the
-- nearest enemy in front within reach (the blade's range, plus the lunge from where the slash began), nothing solid
-- between. Like an arrow, a laggy swinger's slash is also tested against where they saw each target (their ping
-- ago) and reaches a touch further. Two blades swung at each other at nearly the same moment clash instead.
local slashes = {} -- { by, w, t, untilT, from, look, rewind, extra } slashes still cutting
local lunges = {} -- [bot] = { dir, left, speed } a bot's lunge, moved here (a player's own client moves them)

local function flatUnit(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or fallback
end

-- The enemy a slash reaches now (nearest first), or nil
function CombatService:_slashTarget(sl)
	local r = root(sl.by)
	if not r then
		return nil
	end
	local mine = teams:Team(sl.by)
	local past = sl.rewind > 0.01 and now() - sl.rewind or nil
	-- (from where the slash began, the lunge still to come; and from where the swinger is now, the lunge made)
	local froms = { { sl.from, sl.w.range + Constants.BLADE_LUNGE + sl.extra } }
	if (r.Position - sl.from).Magnitude > 0.2 then
		table.insert(froms, { r.Position, sl.w.range + sl.extra })
	end
	local best, bestD
	for other, os_ in states do
		local orr = os_.alive and other ~= sl.by and other.Parent and teams:Team(other) ~= mine and root(other)
		if orr then
			local spots = { orr.Position }
			local was = past and rootAt(other, past)
			if was and (was - orr.Position).Magnitude > 0.05 then
				table.insert(spots, was)
			end
			for _, f in froms do
				for _, p in spots do
					local to = p - f[1]
					local flat = Vector3.new(to.X, 0, to.Z)
					local d = flat.Magnitude
					local inArc = d < 1.5 or math.deg(math.acos(math.clamp(flat.Unit:Dot(sl.look), -1, 1))) <= sl.w.arc
					if d <= f[2] and math.abs(to.Y) < 5 and inArc and (not bestD or d < bestD) then
						if not self:Blocked(f[1] + Vector3.new(0, 1.5, 0), p + Vector3.new(0, 1, 0)) then
							best, bestD = other, d
						end
					end
				end
			end
		end
	end
	return best
end

-- A bot's lunge (a player's own client lunges them: it owns their body): toward who it's slashing, stopping short
local function lungeBot(bot, r, look, target)
	local dist = Constants.BLADE_STEP
	local tr = target and root(target)
	if tr then
		local gap = Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z).Magnitude
		dist = math.clamp(gap - 3, 0, Constants.BLADE_LUNGE)
	end
	if dist > 0.1 then
		lunges[bot] = { dir = look, left = dist, speed = dist / Constants.BLADE_LUNGE_TIME }
	end
end

function CombatService:_lungeStep(dt)
	for bot, l in lunges do
		local r = root(bot)
		local s = states[bot]
		if not r or not s or not s.alive or l.left <= 0 then
			lunges[bot] = nil
		else
			local d = math.min(l.left, l.speed * dt)
			local at = r.Position + Vector3.new(0, 1, 0)
			if self:Blocked(at, at + l.dir * (d + 1.5)) then
				lunges[bot] = nil -- (a wall in the way: it stops)
			else
				r.CFrame += l.dir * d
				l.left -= d
			end
		end
	end
end

-- Did the victim's own blade meet this slash (they swung at the swinger a moment ago)?
local function clashes(sl, victim)
	local vs = states[victim]
	local vw = vs and Weapons.get(vs.weapon)
	if not vw or not vw.melee or not vs.swingAt or sl.t - vs.swingAt > Constants.BLADE_CLASH then
		return false
	end
	local vr, r = root(victim), root(sl.by)
	if not vr or not r then
		return false
	end
	return vs.swingLook:Dot(flatUnit(r.Position - vr.Position, vs.swingLook)) >= Constants.PARRY_DOT
end

local function stopSlashes(who)
	for i = #slashes, 1, -1 do
		if slashes[i].by == who then
			table.remove(slashes, i)
		end
	end
	lunges[who] = nil
end

-- Steel on steel: no knockout; both are thrown apart and hear the clang
function CombatService:_clash(a, b)
	local ar, br = root(a), root(b)
	local mid = (ar.Position + br.Position) / 2 + Vector3.new(0, 1.5, 0)
	for _, pair in { { a, ar, br }, { b, br, ar } } do
		local who, mine, theirs = pair[1], pair[2], pair[3]
		stopSlashes(who)
		local knock = flatUnit(mine.Position - theirs.Position, -mine.CFrame.LookVector) * Constants.BLADE_CLASH_PUSH
			+ Vector3.new(0, 8, 0)
		pcall(function()
			mine.AssemblyLinearVelocity += knock
		end)
		if typeof(who) == "Instance" then
			who:SetAttribute("AcGrace", os.clock() + 1)
			Net.fire(who, "Hit", { damage = 0, parry = true, clash = true, melee = true, pos = mid, knock = knock })
		end
	end
	Net.fireAll("Sfx", "parry", mid)
end

-- The slash lands on best: a knockout (more from behind), or a clash
function CombatService:_slash(sl, best)
	stopSlashes(sl.by)
	local player, w = sl.by, sl.w
	if clashes(sl, best) then
		self:_clash(player, best)
		return best, false
	end
	local r, vr = root(player), root(best)
	-- from behind: the victim faces away from you
	local away = (vr.Position - r.Position)
	away = Vector3.new(away.X, 0, away.Z)
	local back = away.Magnitude > 0.01 and vr.CFrame.LookVector:Dot(away.Unit) > 0.5
	local amount = math.floor(w.damage[1] * (back and w.backstab or 1) + 0.5)
	local info = { weapon = w.key, head = false, kind = "melee", back = back }
	local ok, killed = self:Damage(best, amount, player, info)
	if not ok then
		return best, false
	end
	local look = flatUnit(away, sl.look)
	local kb = look * math.min(w.knockback, Constants.KNOCKBACK_CAP) + Vector3.new(0, w.knockback * 0.3, 0)
	if not killed then
		pcall(function()
			vr.AssemblyLinearVelocity += kb
		end)
	end
	if typeof(best) == "Instance" then
		best:SetAttribute("AcGrace", os.clock() + 1.5)
	end
	Net.fire(best, "Hurt", { amount = amount, from = r.Position, knock = kb, head = false, by = player.UserId })
	Net.fire(
		player,
		"Hit",
		{ damage = amount, head = back, kill = killed, victim = best.UserId, melee = true, pos = vr.Position }
	)
	return best, killed
end

-- (each step: the slashes still cutting look again; one that ran out is a whiff, and the swinger hears it)
function CombatService:_slashStep()
	local t = now()
	for i = #slashes, 1, -1 do
		local sl = slashes[i]
		local s = states[sl.by]
		if not s or not s.alive or not sl.by.Parent or not enabled then
			table.remove(slashes, i)
		else
			local best = self:_slashTarget(sl)
			if best then
				self:_slash(sl, best)
			elseif t >= sl.untilT then
				table.remove(slashes, i)
				Net.fire(sl.by, "Swing", { by = sl.by.UserId, whiff = true })
			end
		end
	end
end

function CombatService:Swing(player, direction)
	if not enabled or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return nil
	end
	local s = state(player)
	local w = Weapons.get(s.weapon)
	if not s.alive or not w or not w.melee or not CombatService.allowed(s.weapon) then
		return nil
	end
	local t = now()
	if t < (s.readyAt or 0) - 0.08 then
		self.Rejected:Fire(player, "rate")
		return nil
	elseif t < (s.readyAt or 0) then
		return nil
	end
	s.readyAt = t + w.cooldown
	s.attacked = true
	local r = root(player)
	if not r then
		return nil
	end
	local look = flatUnit(direction, r.CFrame.LookVector)
	-- the swing knocks back arrows from the front for a moment (see _parry), and meets another blade (clashes)
	s.parryUntil, s.parryDir = t + Constants.PARRY_SECONDS, look
	s.swingAt, s.swingLook = t, look
	stopSlashes(player)
	local rewind, extra = forgiveness({ by = player })
	local sl = {
		by = player,
		w = w,
		t = t,
		untilT = t + Constants.BLADE_WINDOW,
		from = r.Position,
		look = look,
		rewind = rewind,
		extra = extra,
	}
	local best = self:_slashTarget(sl)
	if typeof(player) ~= "Instance" then
		lungeBot(player, r, look, best)
	end
	Net.fireAll("Swing", { by = player.UserId, hit = best ~= nil, pos = r.Position, dir = look })
	self.Shot:Fire(player, w.key)
	if not best then
		table.insert(slashes, sl) -- (still cutting: see _slashStep)
		return nil
	end
	return self:_slash(sl, best)
end

function CombatService:Equip(player, key)
	local w = Weapons.get(key)
	if w and Weapons.locked(key, player) then
		self.Locked:Fire(player, key)
		return false
	end
	if not w or not CombatService.allowed(key, player) then
		return false
	end
	local s = state(player)
	s.weapon = key
	s.ammo = w.mag
	s.reloadAt = nil
	s.drawAt = nil
	local profile = data:Get(player)
	if profile then
		profile.settings.weapon = key
	end
	self:HoldBow(player, key)
	self:Push(player)
	return true
end

function CombatService:Arrows()
	return arrows
end

function CombatService:Bombs()
	return bombs
end

function CombatService:Init(registry)
	data = registry.PlayerDataService
	teams = registry.TeamService
	arena = registry.ArenaService
	Net.on("Equip", function(player, key)
		if type(key) == "string" then
			self:Equip(player, key)
		end
	end)
	Net.on("Draw", function(player, on)
		self:Draw(player, on)
	end)
	Net.on("Shoot", function(player, origin, direction, shotId)
		self:Shoot(player, origin, direction, shotId)
	end)
	Net.on("Swing", function(player, direction)
		self:Swing(player, direction)
	end)
	Net.on("Reload", function(player)
		local s = state(player)
		local w = Weapons.get(s.weapon)
		if w.mag and (s.ammo or 0) < w.mag and not s.reloadAt then
			s.reloadAt = now() + w.reload
			s.ammo = 0
			self:Push(player)
		end
	end)
	-- the CHARGE is over: blades away, bows back out
	workspace:GetAttributeChangedSignal("Charge"):Connect(function()
		if workspace:GetAttribute("Charge") == true then
			return
		end
		for who, st in states do
			local sw = Weapons.get(st.weapon)
			if sw and sw.melee and who.Parent then
				self:Equip(who, Weapons.DEFAULT)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		history[player] = nil
		scored[player] = nil
		warnedAt[player] = nil
		helpedIn[player] = nil
		stopSlashes(player)
		for _, s in states do
			s.hits[player] = nil
		end
	end)
end

function CombatService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		local tNow = now()
		if tNow - (self._recordedAt or 0) >= HISTORY_STEP then
			self._recordedAt = tNow
			record(tNow)
		end
		while acc >= Constants.ARROW_STEP do
			acc -= Constants.ARROW_STEP
			self:_step(Constants.ARROW_STEP)
		end
		-- (slashes still cutting, bots mid-lunge)
		self:_slashStep()
		self:_lungeStep(dt)
		-- (finished reloads refill the magazine; a comeback shield that ran out goes)
		local t = now()
		for player, s in states do
			if s.shieldUntil and t >= s.shieldUntil then
				self:DropShield(player, "time")
			end
			if s.reloadAt and t >= s.reloadAt then
				local w = Weapons.get(s.weapon)
				s.reloadAt, s.ammo = nil, w.mag
				if player.Parent then
					self:Push(player)
				end
			end
		end
	end)
end

return CombatService

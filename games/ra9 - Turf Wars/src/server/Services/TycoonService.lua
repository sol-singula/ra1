--[[
Castle Tycoon (the "tycoon" place: Modes = { "tycoon" }; Data/Tycoon has the items and the numbers, World/
TycoonBuilder the world). No teams and no match: everyone who joins gets the first free plot, their castle rebuilt
from their save (profile.tycoon), and lands in the street in front of their gate.

  income     every built piece adds Gold a second (Tycoon.income: the mines most, the upgrades multiply); it fills
             the plot's vault (the COLLECT pad shows how much), never the wallet, while they're here
  COLLECT    standing on the pad moves the vault into their Gold (and stats.tycoonEarned: the GOLD EARNED board)
  buy-pads   the next Tycoon.PADS pieces, each with its name and price; standing on one with the Gold builds it
             (only the owner's: on someone else's plot nothing happens). Not enough: a toast says how much more
  tiers      the last piece of a tier pays its Shards (Tycoon.TIERS, EconomyService "tycoon"), once per run
  REBIRTH    with everything built the middle pad turns into REBIRTH: standing on it asks (Net "Tycoon"
             rebirthAsk; the client's card); ("rebirth") from the client does it: the castle comes down, Gold to 0,
             rebirths + 1 (more income and higher prices from now on), Tycoon.rebirthShards Shards
  raids      from the first tower on: RAID_FIRST seconds after it, then every RAID_EVERY, RAID_BASE + tier raiders
             come out of the street for the vault. Every tower shoots the nearest in range every TOWER_EVERY;
             Net "Tycoon" ("hit") from anyone within HIT_RANGE of one hits the nearest (one hit every HIT_EVERY).
             A raider down pays the plot's owner RAIDER_GOLD seconds of income; one that reaches the COLLECT pad
             takes RAID_STEAL of the vault and is gone. A raid beaten with nothing taken pays RAID_BONUS more.
  the LOBBY  walking into the portal at the street's north end goes back (PlaceService:ToLobby)

Net "Tycoon" to the owner: { kind = "state", plot, cash, bank, income, rebirths, tier, tierName, done, of, next =
{ { key, name, cost } }, complete, raid } whenever it changes (at most every PUSH_EVERY for the numbers);
{ kind = "bought", key, name } | { kind = "tier", tier, name, shards } | { kind = "collect", amount } |
{ kind = "rebirthAsk", shards } | { kind = "rebirth", rebirths, shards } | { kind = "raid", n } |
{ kind = "raidOver", stolen, bonus } | { kind = "stolen", amount }. To everyone: { kind = "zap", from, to, hit? }
(a tower's shot or a hit: a beam on every client).

  TycoonService:Plot(player)          the plot table (World/TycoonBuilder) they own, or nil
  TycoonService:State(player)         profile.tycoon (cash, bought, rebirths, earned, tiers)
  TycoonService:Bank(player)          Gold waiting in their vault
  TycoonService:Buy(player, key)      -> ok, why ("owned" | "order" | "cash")
  TycoonService:Collect(player)       -> the amount
  TycoonService:Rebirth(player)       -> ok
  TycoonService:StartRaid(player)     a raid on their plot now (tests, admins)
  TycoonService:Raiders(player?)      { [id] = raider } (on their plot)
  TycoonService:Hit(player)           -> the raider hit, or nil
  TycoonService:World()
  TycoonService:Spawn(player)
  TycoonService.Bought / .Collected / .Reborn / .RaidStarted / .RaidOver   (signals; tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tycoon = require(ReplicatedStorage.Shared.Data.Tycoon)
local TycoonBuilder = require(ReplicatedStorage.Shared.World.TycoonBuilder)
local LobbyBuilder = require(ReplicatedStorage.Shared.World.LobbyBuilder)

local TycoonService = {
	Name = "TycoonService",
	Modes = { "tycoon" },
	Dependencies = { "PlayerDataService", "EconomyService" },
	Bought = Signal.new("TycoonService.Bought"), -- (player, item)
	Collected = Signal.new("TycoonService.Collected"), -- (player, amount)
	Reborn = Signal.new("TycoonService.Reborn"), -- (player, rebirths)
	RaidStarted = Signal.new("TycoonService.RaidStarted"), -- (player, n)
	RaidOver = Signal.new("TycoonService.RaidOver"), -- (player, stolen)
}

TycoonService.TICK = 0.1
TycoonService.PUSH_EVERY = 0.5
TycoonService.REACH = 3.2 -- studs from a pad's middle that count as standing on it
TycoonService.RESPAWN = 2

local data, economy, place, analytics
local world
local owners = {} -- [plotIndex] = player
local plots = {} -- [player] = { plot, pads, bank, built = { [key] = out }, onPad, lastPush, raidAt, raid, ... }
local raiders = {} -- [id] = { id, model, plot (index), owner, hp, path, leg, pos }
local nextId = 0
local spawning = {}
local hitAt = {} -- [player] = os.clock() of their last hit
local portalAt = {} -- [player] = os.clock() they last walked into the portal

local function log(player, name, payload)
	if analytics then
		pcall(analytics.event, player, "tycoon_" .. name, payload)
	end
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function stateOf(profile)
	profile.tycoon = profile.tycoon or {}
	local t = profile.tycoon
	t.cash = tonumber(t.cash) or Tycoon.START_CASH
	t.bought = type(t.bought) == "table" and t.bought or {}
	t.rebirths = tonumber(t.rebirths) or 0
	t.earned = tonumber(t.earned) or 0
	t.tiers = type(t.tiers) == "table" and t.tiers or {}
	return t
end

function TycoonService:State(player)
	local p = data:Get(player)
	return p and stateOf(p)
end

function TycoonService:Plot(player)
	local s = plots[player]
	return s and s.plot
end

function TycoonService:Bank(player)
	local s = plots[player]
	return s and math.floor(s.bank) or 0
end

function TycoonService:World()
	return world
end

function TycoonService:Raiders(player)
	if not player then
		return raiders
	end
	local out = {}
	for id, r in raiders do
		if r.owner == player then
			out[id] = r
		end
	end
	return out
end

local function income(t)
	return Tycoon.income(t.bought, t.rebirths)
end

-- What the owner's screen shows
local function snapshot(player)
	local s, t = plots[player], TycoonService:State(player)
	if not s or not t then
		return nil
	end
	local tier, done, of = Tycoon.tier(t.bought)
	local nxt = {}
	for _, it in Tycoon.next(t.bought) do
		table.insert(nxt, { key = it.key, name = it.name, cost = Tycoon.cost(it, t.rebirths) })
	end
	local raid = 0
	for _, r in raiders do
		if r.owner == player then
			raid += 1
		end
	end
	return {
		kind = "state",
		plot = s.plot.index,
		cash = math.floor(t.cash),
		bank = math.floor(s.bank),
		income = math.floor(income(t) * 10) / 10,
		rebirths = t.rebirths,
		tier = tier,
		tierName = Tycoon.TIERS[tier] and Tycoon.TIERS[tier].name or "COMPLETE",
		done = done,
		of = of,
		next = nxt,
		complete = Tycoon.complete(t.bought),
		raid = raid,
	}
end

local function push(player)
	local s = plots[player]
	local snap = snapshot(player)
	if s and snap then
		s.lastPush = os.clock()
		s.pushed = { cash = snap.cash, bank = snap.bank }
		Net.fire(player, "Tycoon", snap)
	end
end

-- The pads' words: each buy-pad its piece and price (green when they can pay), the COLLECT pad its vault
local GREEN = Color3.fromRGB(70, 200, 110)
local RED = Color3.fromRGB(235, 70, 70)
local function paintPads(player)
	local s, t = plots[player], TycoonService:State(player)
	if not s or not t then
		return
	end
	local nxt = Tycoon.next(t.bought)
	local complete = Tycoon.complete(t.bought)
	for slot, pad in s.pads.pads do
		local it = nxt[slot]
		if complete and slot == 2 then
			pad:SetAttribute("Item", "rebirth")
			pad.Transparency = 0
			TycoonBuilder.label(
				pad,
				"REBIRTH ★",
				`+{math.floor(Tycoon.REBIRTH_INCOME * 100)}% income forever`,
				LobbyBuilder.GOLD
			)
		elseif it then
			local cost = Tycoon.cost(it, t.rebirths)
			pad:SetAttribute("Item", it.key)
			pad.Transparency = 0
			TycoonBuilder.label(pad, it.name, cost == 0 and "FREE" or `{cost} Gold`, t.cash >= cost and GREEN or RED)
		else
			pad:SetAttribute("Item", nil)
			pad.Transparency = 0.6
			TycoonBuilder.label(pad, "", "", RED)
		end
	end
	local words = TycoonBuilder.label(s.pads.collector, "COLLECT", tostring(math.floor(s.bank)) .. " Gold")
	_ = words
end

local function paintSign(plot, player)
	LobbyBuilder.sign(
		plot.sign,
		player and string.upper(player.DisplayName) .. "'S CASTLE" or "FREE PLOT",
		"",
		plot.color
	)
end

-- Building ---------------------------------------------------------------------------------------------------------
local function build(player, key)
	local s = plots[player]
	if not s or s.built[key] then
		return
	end
	local out = TycoonBuilder.item(s.plot, key)
	s.built[key] = out or { folder = nil }
end

local function rebuild(player)
	local s, t = plots[player], TycoonService:State(player)
	TycoonBuilder.clear(s.plot)
	s.built = {}
	s.pads = TycoonBuilder.pads(s.plot)
	for _, it in Tycoon.ITEMS do
		if t.bought[it.key] then
			build(player, it.key)
		end
	end
	paintPads(player)
end

local function hasTower(t)
	for key in TycoonBuilder.TOWERS do
		if t.bought[key] then
			return true
		end
	end
	return false
end

function TycoonService:Buy(player, key)
	local s, t = plots[player], self:State(player)
	local it = Tycoon.byKey[key]
	if not s or not t or not it then
		return false, "order"
	end
	if t.bought[key] then
		return false, "owned"
	end
	local offered = false
	for _, n in Tycoon.next(t.bought) do
		if n.key == key then
			offered = true
		end
	end
	if not offered then
		return false, "order"
	end
	local cost = Tycoon.cost(it, t.rebirths)
	if t.cash < cost then
		return false, "cash"
	end
	local hadTower = hasTower(t)
	t.cash -= cost
	t.bought[key] = true
	build(player, key)
	if not hadTower and hasTower(t) and not s.raidAt then
		s.raidAt = os.clock() + Tycoon.RAID_FIRST
	end
	Net.fire(player, "Tycoon", { kind = "bought", key = key, name = it.name })
	log(player, "buy", { key = key, tier = it.tier, cost = cost, rebirths = t.rebirths })
	self.Bought:Fire(player, it)
	-- the tier's last piece: its Shards (once a run)
	local tierKey = tostring(it.tier)
	if Tycoon.tierDone(t.bought, it.tier) and not t.tiers[tierKey] then
		t.tiers[tierKey] = true
		local tier = Tycoon.TIERS[it.tier]
		economy:Add(player, tier.shards, "tycoon")
		Net.fire(player, "Tycoon", { kind = "tier", tier = it.tier, name = tier.name, shards = tier.shards })
		Net.fire(player, "Toast", `{tier.name} COMPLETE! +{tier.shards} Shards`, "good")
		log(player, "tier", { tier = it.tier, rebirths = t.rebirths })
	end
	if Tycoon.complete(t.bought) then
		Net.fire(player, "Toast", "Your castle is complete! Stand on REBIRTH to start again, stronger", "good")
	end
	paintPads(player)
	push(player)
	return true
end

function TycoonService:Collect(player)
	local s, t = plots[player], self:State(player)
	if not s or not t then
		return 0
	end
	local amount = math.floor(s.bank)
	if amount <= 0 then
		return 0
	end
	s.bank -= amount
	t.cash += amount
	t.earned += amount
	local p = data:Get(player)
	if p and p.stats then
		p.stats.tycoonEarned = (p.stats.tycoonEarned or 0) + amount
	end
	Net.fire(player, "Tycoon", { kind = "collect", amount = amount })
	self.Collected:Fire(player, amount)
	paintPads(player)
	push(player)
	return amount
end

local function clearRaid(player)
	for id, r in raiders do
		if r.owner == player then
			if r.model then
				r.model:Destroy()
			end
			raiders[id] = nil
		end
	end
	local s = plots[player]
	if s then
		s.raid = nil
	end
end

function TycoonService:Rebirth(player)
	local s, t = plots[player], self:State(player)
	if not s or not t or not Tycoon.complete(t.bought) then
		return false
	end
	local shards = Tycoon.rebirthShards(t.rebirths)
	t.rebirths += 1
	t.cash = Tycoon.START_CASH
	t.bought = {}
	t.tiers = {}
	s.bank = 0
	s.raidAt = nil
	clearRaid(player)
	rebuild(player)
	economy:Add(player, shards, "tycoon")
	Net.fire(player, "Tycoon", { kind = "rebirth", rebirths = t.rebirths, shards = shards })
	Net.fire(
		player,
		"Toast",
		`REBIRTH {t.rebirths}! +{shards} Shards · +{math.floor(Tycoon.REBIRTH_INCOME * 100 * t.rebirths)}% income`,
		"good"
	)
	log(player, "rebirth", { rebirths = t.rebirths, shards = shards })
	self.Reborn:Fire(player, t.rebirths)
	push(player)
	return true
end

-- Raids ------------------------------------------------------------------------------------------------------------
local RAIDER_DARK = Color3.fromRGB(46, 46, 54)
local function raiderModel(id, at)
	local m = Instance.new("Model")
	m.Name = "Raider"
	m:SetAttribute("Raider", id)
	local function part(name, size, offset, color, neon)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.Size = size
		p.Color = color or RAIDER_DARK
		p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(at + offset)
		p.Parent = m
		return p
	end
	local body = part("Body", Vector3.new(2, 2.2, 1.2), Vector3.new(0, 3.1, 0))
	part("LegL", Vector3.new(0.8, 2, 0.9), Vector3.new(-0.5, 1, 0))
	part("LegR", Vector3.new(0.8, 2, 0.9), Vector3.new(0.5, 1, 0))
	part("Head", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 4.9, 0))
	part("Eyes", Vector3.new(1, 0.25, 0.1), Vector3.new(0, 5, -0.72), Color3.fromRGB(235, 40, 45), true)
	part("Club", Vector3.new(0.5, 2.6, 0.5), Vector3.new(1.4, 3.2, -0.4), Color3.fromRGB(110, 112, 120))
	m.PrimaryPart = body
	m.Parent = world.folder
	return m
end

local function face(r)
	local goal = r.path[r.leg] or r.pos
	local flat = Vector3.new(goal.X, r.pos.Y, goal.Z)
	if (flat - r.pos).Magnitude > 0.05 then
		r.model:PivotTo(CFrame.lookAt(r.pos + Vector3.new(0, 3.1, 0), flat + Vector3.new(0, 3.1, 0)))
	else
		r.model:PivotTo(CFrame.new(r.pos + Vector3.new(0, 3.1, 0)))
	end
end

function TycoonService:StartRaid(player)
	local s, t = plots[player], self:State(player)
	if not s or not t then
		return 0
	end
	clearRaid(player)
	if s.raidAt then
		s.raidAt = os.clock() + Tycoon.RAID_EVERY -- (the next one counts from this one)
	end
	local tier = math.min(#Tycoon.TIERS, (Tycoon.tier(t.bought)))
	local n = Tycoon.RAID_BASE + tier
	local i = s.plot.index
	local gate = TycoonBuilder.toWorld(i, 0, -36)
	local inside = TycoonBuilder.toWorld(i, 0, -28)
	local vault = TycoonBuilder.toWorld(i, TycoonBuilder.SPOTS.collector.X, TycoonBuilder.SPOTS.collector.Z)
	s.raid = { n = n, stolen = 0, left = n, startedAt = os.clock() }
	for k = 1, n do
		nextId += 1
		local id = nextId
		local start = TycoonBuilder.toWorld(i, (k - (n + 1) / 2) * 3.2, -44 - (k % 2) * 3)
		local r = {
			id = id,
			owner = player,
			plot = i,
			hp = Tycoon.RAIDER_HITS + tier,
			pos = start,
			path = { gate, inside, vault },
			leg = 1,
			delay = (k - 1) * Tycoon.RAIDER_GAP, -- (they come out one after another)
		}
		r.model = raiderModel(id, start)
		r.maxHp = r.hp
		raiders[id] = r
		face(r)
	end
	Net.fire(player, "Tycoon", { kind = "raid", n = n })
	Net.fire(player, "Toast", "RAID! Raiders are coming for your vault: HIT them!", "bad")
	log(player, "raid", { n = n, tier = tier })
	self.RaidStarted:Fire(player, n)
	push(player)
	return n
end

local function raidDone(player)
	local s = plots[player]
	local raid = s and s.raid
	if not raid then
		return
	end
	s.raid = nil
	local t = TycoonService:State(player)
	local bonus = 0
	if raid.stolen == 0 and t then
		bonus = math.floor(math.max(Tycoon.RAIDER_GOLD_MIN, income(t) * Tycoon.RAID_BONUS))
		s.bank += bonus
	end
	Net.fire(player, "Tycoon", { kind = "raidOver", stolen = math.floor(raid.stolen), bonus = bonus })
	Net.fire(
		player,
		"Toast",
		bonus > 0 and `RAID BEATEN! +{bonus} Gold in your vault`
			or `Raid over: they took {math.floor(raid.stolen)} Gold`,
		bonus > 0 and "good" or "info"
	)
	TycoonService.RaidOver:Fire(player, raid.stolen)
	push(player)
end

local function down(r, by)
	raiders[r.id] = nil
	local at = r.pos
	if r.model then
		r.model:Destroy()
	end
	local owner = r.owner
	local t = TycoonService:State(owner)
	local s = plots[owner]
	if t and s then
		local gold = math.floor(math.max(Tycoon.RAIDER_GOLD_MIN, income(t) * Tycoon.RAIDER_GOLD))
		s.bank += gold
		_ = by
		if s.raid then
			s.raid.left -= 1
		end
	end
	Net.fireAll("Tycoon", { kind = "zap", to = at + Vector3.new(0, 3, 0), down = true })
	if s and s.raid and s.raid.left <= 0 then
		raidDone(owner)
	end
end

local function damage(r, n, from, by)
	r.hp -= n
	Net.fireAll("Tycoon", { kind = "zap", from = from, to = r.pos + Vector3.new(0, 3, 0), hit = by ~= nil })
	if r.hp <= 0 then
		down(r, by)
	end
end

function TycoonService:Hit(player)
	local rt = root(player)
	if not rt then
		return nil
	end
	local now = os.clock()
	if hitAt[player] and now - hitAt[player] < Tycoon.HIT_EVERY then
		return nil
	end
	local best, bestD
	for _, r in raiders do
		local d = (r.pos - rt.Position).Magnitude
		if d <= Tycoon.HIT_RANGE and (not bestD or d < bestD) then
			best, bestD = r, d
		end
	end
	if not best then
		return nil
	end
	hitAt[player] = now
	damage(best, 1, rt.Position, player)
	return best
end

function TycoonService:_raids(dt)
	local now = os.clock()
	-- each raider walks its path; at the vault it takes its share and is gone
	for id, r in raiders do
		if r.delay > 0 then
			r.delay -= dt
			continue
		end
		local goal = r.path[r.leg]
		local step = Tycoon.RAIDER_SPEED * dt
		local to = goal - r.pos
		if to.Magnitude <= step then
			r.pos = goal
			r.leg += 1
			if r.leg > #r.path then
				local s = plots[r.owner]
				if s then
					local take = math.floor(s.bank * Tycoon.RAID_STEAL)
					s.bank -= take
					if s.raid then
						s.raid.stolen += take
						s.raid.left -= 1
					end
					Net.fire(r.owner, "Tycoon", { kind = "stolen", amount = take })
				end
				raiders[id] = nil
				if r.model then
					r.model:Destroy()
				end
				if s and s.raid and s.raid.left <= 0 then
					raidDone(r.owner)
				end
				continue
			end
		else
			r.pos += to.Unit * step
		end
		face(r)
	end
	-- the towers shoot
	for player, s in plots do
		local t = self:State(player)
		if not t then
			continue
		end
		for key in TycoonBuilder.TOWERS do
			local out = s.built[key]
			if out and out.top then
				out.nextShot = out.nextShot or now
				if now >= out.nextShot then
					local best, bestD
					for _, r in raiders do
						local d = (r.pos - out.top).Magnitude
						if
							r.delay <= 0
							and r.plot == s.plot.index
							and d <= Tycoon.TOWER_RANGE
							and (not bestD or d < bestD)
						then
							best, bestD = r, d
						end
					end
					if best then
						out.nextShot = now + Tycoon.TOWER_EVERY
						damage(best, Tycoon.TOWER_DAMAGE[key] or 1, out.top, nil)
					end
				end
			end
		end
		-- the next raid
		if s.raidAt and now >= s.raidAt and not s.raid then
			s.raidAt = now + Tycoon.RAID_EVERY
			self:StartRaid(player)
		end
	end
end

-- Plots and bodies -------------------------------------------------------------------------------------------------
local function claim(player)
	for i = 1, Tycoon.PLOTS do
		if not owners[i] then
			owners[i] = player
			local plot = world.plots[i]
			plots[player] = { plot = plot, bank = 0, built = {}, lastPush = 0 }
			player:SetAttribute("Plot", i)
			paintSign(plot, player)
			return plot
		end
	end
	return nil
end

local function release(player)
	local s = plots[player]
	if not s then
		return
	end
	clearRaid(player)
	-- (the vault goes into their Gold as they go: nothing waiting is ever lost)
	local t = TycoonService:State(player)
	if t and s.bank >= 1 then
		t.cash += math.floor(s.bank)
		t.earned += math.floor(s.bank)
	end
	TycoonBuilder.clear(s.plot)
	paintSign(s.plot, nil)
	owners[s.plot.index] = nil
	plots[player] = nil
end

function TycoonService:Spawn(player)
	if not player.Parent or spawning[player] then
		return
	end
	spawning[player] = true
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	spawning[player] = nil
	if not ok or not player.Parent then
		return
	end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local s = plots[player]
	if r then
		local i = s and s.plot.index or 1
		local at = TycoonBuilder.toWorld(i, 0, TycoonBuilder.SPOTS.spawn.Z, TycoonBuilder.SPOTS.spawn.Y)
		r.CFrame = CFrame.lookAt(at, TycoonBuilder.toWorld(i, 0, 0, TycoonBuilder.SPOTS.spawn.Y))
	end
	player:SetAttribute("AcGrace", os.clock() + 2)
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.delay(self.RESPAWN, function()
				if player.Parent and player.Character == c then
					self:Spawn(player)
				end
			end)
		end)
	end
end

local function near(pos, part, radius)
	local p = part.Position
	local dx, dz = pos.X - p.X, pos.Z - p.Z
	return dx * dx + dz * dz <= radius * radius and math.abs(pos.Y - p.Y) <= 6
end

function TycoonService:_tick(dt)
	for player, s in plots do
		local t = self:State(player)
		if not t then
			continue
		end
		s.bank += income(t) * dt
		local r = root(player)
		if r then
			local pos = r.Position
			if pos.Y < -20 then
				self:Spawn(player)
				continue
			end
			-- the pads: only the owner's own do anything
			local on = nil
			if near(pos, s.pads.collector, self.REACH) then
				on = "collect"
				self:Collect(player)
			else
				for _, pad in s.pads.pads do
					local key = pad:GetAttribute("Item")
					if key and near(pos, pad, self.REACH) then
						on = key
						if s.onPad ~= key then
							if key == "rebirth" then
								Net.fire(
									player,
									"Tycoon",
									{ kind = "rebirthAsk", shards = Tycoon.rebirthShards(t.rebirths) }
								)
							else
								local ok, why = self:Buy(player, key)
								if not ok and why == "cash" then
									local it = Tycoon.byKey[key]
									local short = Tycoon.cost(it, t.rebirths) - math.floor(t.cash)
									Net.fire(
										player,
										"Toast",
										`Need {short} more Gold for {it.name}: COLLECT your vault!`,
										"info"
									)
								end
								if ok then
									on = pad:GetAttribute("Item") -- (the pad shows the next piece now: step off and on to buy it)
								end
							end
						end
						break
					end
				end
			end
			s.onPad = on
			-- the LOBBY portal
			if world.portal and near(pos, world.portal, 6) then
				local now = os.clock()
				if place and (not portalAt[player] or now - portalAt[player] > 6) then
					portalAt[player] = now
					Net.fire(player, "Toast", "Back to the lobby...", "info")
					place:ToLobby(player)
				end
			end
		end
		-- the numbers on screen and on the pads, when they've changed (at most every PUSH_EVERY)
		local snapBank, snapCash = math.floor(s.bank), math.floor(t.cash)
		if
			os.clock() - (s.lastPush or 0) >= self.PUSH_EVERY
			and (not s.pushed or s.pushed.bank ~= snapBank or s.pushed.cash ~= snapCash)
		then
			paintPads(player)
			push(player)
		end
	end
	self:_raids(dt)
end

-- Hooks ------------------------------------------------------------------------------------------------------------
function TycoonService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	place = registry.PlaceService
	analytics = registry.AnalyticsService
	for _, d in workspace:GetChildren() do
		if (d:IsA("BasePart") and (d.Name == "Baseplate" or d:IsA("SpawnLocation"))) or d.Name == "Baseplate" then
			d:Destroy()
		end
	end
	TycoonBuilder.light()
	world = TycoonBuilder.build(workspace)
	workspace:SetAttribute("Tycoon", true)

	Net.on("Tycoon", function(player, what)
		if what == "hit" then
			self:Hit(player)
		elseif what == "rebirth" then
			self:Rebirth(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		release(player)
		spawning[player] = nil
		hitAt[player] = nil
		portalAt[player] = nil
	end)
end

function TycoonService:OnPlayerReady(player, profile)
	stateOf(profile)
	local plot = claim(player)
	if not plot then
		Net.fire(player, "Toast", "This server's plots are all taken: back to the lobby", "bad")
		if place then
			place:ToLobby(player)
		end
		return
	end
	rebuild(player)
	self:Spawn(player)
	local t = stateOf(profile)
	if hasTower(t) then
		plots[player].raidAt = os.clock() + Tycoon.RAID_EVERY
	end
	data:WhenClientReady(player, function()
		push(player)
		if next(t.bought) == nil and t.rebirths == 0 then
			Net.fire(player, "Toast", "Welcome to your plot! Stand on the FREE Gold Mine pad", "good")
		end
	end)
	log(player, "join", { rebirths = t.rebirths, built = #Tycoon.ITEMS - #Tycoon.next(t.bought, #Tycoon.ITEMS) })
end

function TycoonService:OnPlayerLeaving(player)
	release(player)
end

function TycoonService:Start()
	local last = os.clock()
	while true do
		task.wait(self.TICK)
		local now = os.clock()
		local dt = math.min(1, now - last)
		last = now
		local ok, err = pcall(self._tick, self, dt)
		if not ok then
			warn("[TycoonService] tick failed: " .. tostring(err))
		end
	end
end

return TycoonService

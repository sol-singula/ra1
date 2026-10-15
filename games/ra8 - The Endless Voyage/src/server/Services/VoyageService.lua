--[[
Voyages (master plan §10: travel is an activity, not a loading screen; §9: where the ocean goes). The raft never
leaves its plot: from the helm you pick a destination you have the chart for (and the tier for), the trip takes
distance x VOYAGE_SECONDS_PER_DISTANCE / the raft's speed, things happen on the way (Data/Voyages.EVENTS: debris
lanes, supply drops, bottles, dolphins, storms, sharks, serpents, whirlpools, a shadow), and when you arrive the
destination rises out of the water beside the plot (IslandService). Sail home and it sinks back; home, the voyage's
finds are safe.

  state     docked | sailing | island | home   (per plot; everyone on the plot shares it)
  charts    profile.known: Palm Key from the start; the rest from crates, bottles, the crow's nest, the islands'
            landmarks and the artifacts you read (Data/Voyages: found)
  tiers     DANGER_BY_TIER: how dangerous the waters a raft may sail to; a Navigation Table for the far ones
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)

local VoyageService = {
	Name = "VoyageService",
	Dependencies = {
		"PlayerDataService",
		"RaftService",
		"InventoryService",
		"PlayerService",
		"OceanService",
		"IslandService",
		"WeatherService",
	},
	Departed = Signal.new("VoyageService.Departed"), -- (plot, dest, players, home)
	Event = Signal.new("VoyageService.Event"), -- (plot, event, players)
	Arrived = Signal.new("VoyageService.Arrived"), -- (plot, dest, players)
	Ended = Signal.new("VoyageService.Ended"), -- (plot, dest, players, danger)
	Revealed = Signal.new("VoyageService.Revealed"), -- (player, destKey, how)
}

local data, rafts, inventory, players, ocean, island, weather, registry
local voyages = {} -- [plot] = v
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function state(plot)
	local v = voyages[plot]
	if not v then
		v = { state = "docked", dest = nil, danger = 1, log = {} }
		voyages[plot] = v
	end
	return v
end

-- Reads ----------------------------------------------------------------------------------------------------------------
function VoyageService:Get(plot)
	return state(plot)
end

function VoyageService:State(plot)
	return state(plot).state
end

function VoyageService:Danger(plot)
	local v = state(plot)
	return v.state == "docked" and 1 or v.danger
end

-- The waters round the plot: the destination's template at its island, "sea" under way, "home" at the dock.
function VoyageService:Waters(plot)
	local v = state(plot)
	if v.state == "island" and v.dest then
		return v.dest.template
	elseif v.state == "docked" then
		return "home"
	end
	return "sea"
end

function VoyageService:Known(player, destKey)
	local d = Voyages.get(destKey)
	local profile = data:Get(player)
	return d ~= nil and (d.known == true or (profile ~= nil and profile.known[destKey] == true))
end

-- A destination the player doesn't know yet that turns up this way ("crate" | "bottle" | "nest"), or nil.
function VoyageService:UnknownDestination(player, how, maxDanger)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local pool, fallback = {}, {}
	for _, d in Voyages.list do
		if not d.known and not profile.known[d.key] and (not maxDanger or d.danger <= maxDanger) then
			if d.found == how then
				table.insert(pool, d.key)
			elseif d.found == "crate" or d.found == "bottle" or d.found == "nest" then
				table.insert(fallback, d.key)
			end
		end
	end
	if #pool == 0 then
		pool = fallback
	end
	if #pool == 0 then
		return nil
	end
	table.sort(pool, function(a, b)
		return Voyages.get(a).distance < Voyages.get(b).distance
	end)
	return pool[1]
end

function VoyageService:View(plot)
	local v = state(plot)
	local raft = rafts:Get(plot)
	return {
		state = v.state,
		dest = v.dest and v.dest.key or nil,
		name = v.dest and v.dest.name or nil,
		icon = v.dest and v.dest.icon or nil,
		danger = v.dest and v.dest.danger or 1,
		started = v.startedAt,
		ends = v.ends,
		event = v.event and { key = v.event.key, name = v.event.name, icon = v.event.icon, ends = v.event.ends } or nil,
		speed = raft and rafts:Speed(raft) or 1,
		log = v.log,
	}
end

function VoyageService:Push(plot)
	local view = self:View(plot)
	for _, player in players:PlayersOnPlot(plot) do
		Net.fire(player, "Voyage", view)
	end
	local raft = rafts:Get(plot)
	if raft and raft.owner and raft.owner.Parent and players:Here(raft.owner) ~= plot then
		Net.fire(raft.owner, "Voyage", view)
	end
end

local function log(v, text)
	table.insert(v.log, text)
	if #v.log > 5 then
		table.remove(v.log, 1)
	end
end

local function say(plot, text, kind)
	for _, player in players:PlayersOnPlot(plot) do
		Net.fire(player, "Callout", text, kind or "info")
	end
end

-- Charts ---------------------------------------------------------------------------------------------------------------
function VoyageService:Reveal(player, destKey, how)
	local d = Voyages.get(destKey)
	local profile = data:Get(player)
	if not d or not profile then
		return false
	end
	if d.known or profile.known[destKey] then
		return false
	end
	profile.known[destKey] = true
	Net.fire(
		player,
		"Unlock",
		{ kind = "chart", key = destKey, name = d.name, icon = d.icon, how = how, text = d.desc }
	)
	Net.fire(player, "Sfx", "discover")
	registry.ProgressService:Push(player)
	self.Revealed:Fire(player, destKey, how)
	return true
end

-- Sailing ---------------------------------------------------------------------------------------------------------------
-- Can this player set sail there now? ok, reason.
function VoyageService:CanSail(player, destKey)
	local raft = rafts:RaftOf(player)
	if not raft then
		return false, "No raft."
	end
	local v = state(raft.plot)
	if destKey == "home" then
		if v.state ~= "island" then
			return false, v.state == "docked" and "You're home already." or "You're on your way."
		end
		return true
	end
	if v.state ~= "docked" then
		return false, v.state == "island" and "Sail home first." or "You're already at sea."
	end
	local d = Voyages.get(destKey)
	if not d then
		return false, "Unknown destination."
	end
	if not rafts:Has(raft, "helm", true) then
		return false, "Build a Helm first (a broken one won't steer)."
	end
	if not self:Known(player, destKey) then
		return false, "You don't have the chart for that place."
	end
	local allowed = Constants.DANGER_BY_TIER[raft.tier] or 1
	if d.danger > allowed then
		return false,
			`Those waters need raft tier {table.find(Constants.DANGER_BY_TIER, d.danger) or 6}. Yours is {raft.tier}.`
	end
	if d.distance > 2 and not rafts:Has(raft, "nav_table", true) then
		return false, "That far needs a Navigation Table."
	end
	return true
end

function VoyageService:Sail(player, destKey)
	local ok, reason = self:CanSail(player, destKey)
	if not ok then
		Net.fire(player, "Toast", reason, "bad")
		return false, reason
	end
	local raft = rafts:RaftOf(player)
	local plot = raft.plot
	local v = state(plot)
	local t = now()
	local home = destKey == "home"
	local d = home and v.dest or Voyages.get(destKey)
	if home then
		island:Leave(plot)
	end
	local seconds = Formulas.voyageSeconds(d.distance, rafts:Speed(raft))
	v.state = home and "home" or "sailing"
	v.dest = d
	v.danger = d.danger
	v.startedAt = t
	v.ends = t + seconds
	v.event = nil
	v.nextEventAt = t
		+ rng:NextNumber(Constants.VOYAGE_EVENT_EVERY[1], Constants.VOYAGE_EVENT_EVERY[2])
			* (home and 1 / Constants.HOME_EVENT_SHARE or 0.6)
	v.log = {}
	log(v, home and `Sailing home from {d.name}.` or `Set sail for {d.name}: {seconds}s.`)
	-- everyone in the water comes aboard
	local aboard = players:PlayersOnPlot(plot)
	for _, p in aboard do
		if players:Where(p) == "water" then
			players:Teleport(p, rafts:SpawnPoint(raft))
		end
		Net.fire(
			p,
			"Alert",
			home and "⛵ SAILING HOME" or `⛵ SETTING SAIL FOR {string.upper(d.name)}`,
			Color3.fromRGB(255, 230, 120),
			3
		)
		Net.fire(p, "Sfx", "horn")
		Net.fire(p, "Fx", "sail", { center = rafts:Center(raft), seconds = seconds, home = home })
	end
	self:Push(plot)
	self.Departed:Fire(plot, d, aboard, home)
	return true
end

-- Events ------------------------------------------------------------------------------------------------------------------
local EVENT = {}

function EVENT.debris_lane(_, plot)
	ocean:Burst(plot, Constants.DEBRIS_LANE_PIECES, 20)
end

function EVENT.supply_drop(_, plot, v)
	ocean:Crate(plot, v.danger, { distance = 30, spread = 8, lifetime = 60 })
end

function EVENT.bottle(_, plot)
	ocean:Bottle(plot)
end

function EVENT.calm(_, plot)
	local raft = rafts:Get(plot)
	for _, p in players:PlayersOnPlot(plot) do
		Net.fire(p, "Fx", "dolphins", { center = rafts:Center(raft) })
	end
end

function EVENT.storm(_, plot)
	weather:Storm(plot, Constants.STORM_SECONDS, "voyage")
end

function EVENT.shadow(_, plot)
	local raft = rafts:Get(plot)
	for _, p in players:PlayersOnPlot(plot) do
		Net.fire(p, "Fx", "shadow", { center = rafts:Center(raft) })
		Net.fire(p, "Sfx", "roar")
	end
end

function EVENT.shark(_, plot, v)
	local creatures = registry.CreatureService
	local raft = rafts:Get(plot)
	local n = v.danger >= 4 and 2 or 1
	for i = 1, n do
		local a = rng:NextNumber(0, math.pi * 2) + i
		local pos = rafts:Center(raft) + Vector3.new(math.cos(a) * 30, Constants.WATER_LEVEL - 3, math.sin(a) * 30)
		creatures:SpawnAt("shark", pos, plot, { danger = v.danger, event = true, leaveAt = now() + 40 })
	end
end

function EVENT.serpent(_, plot, v)
	local creatures = registry.CreatureService
	local raft = rafts:Get(plot)
	local a = rng:NextNumber(0, math.pi * 2)
	local pos = rafts:Center(raft) + Vector3.new(math.cos(a) * 34, Constants.WATER_LEVEL - 4, math.sin(a) * 34)
	creatures:SpawnAt("sea_serpent", pos, plot, { danger = v.danger, event = true, leaveAt = now() + 45 })
end

function EVENT.whirlpool(_, plot)
	local raft = rafts:Get(plot)
	for _, p in players:PlayersOnPlot(plot) do
		Net.fire(p, "Fx", "whirlpool", { center = rafts:Center(raft), seconds = 16 })
	end
	if rafts:Anchors(raft) == 0 then
		task.delay(3, function()
			if rafts:Get(plot) == raft then
				rafts:DamageRandom(raft, 3, Constants.STORM_TILE_DAMAGE * 0.8, { kind = "whirlpool" })
			end
		end)
		task.delay(10, function()
			if rafts:Get(plot) == raft then
				rafts:DamageRandom(raft, 3, Constants.STORM_TILE_DAMAGE * 0.8, { kind = "whirlpool" })
			end
		end)
	else
		say(plot, "⚓ The anchor holds in the whirlpool.", "good")
	end
end

function VoyageService:_pickEvent(v)
	local pool, total = {}, 0
	for _, e in Voyages.EVENTS do
		if v.danger >= e.minDanger and e.key ~= v.lastEvent then
			local w = e.weight + (e.dangerWeight or 0) * (v.danger - 1)
			table.insert(pool, { e, w })
			total += w
		end
	end
	local r = rng:NextNumber() * total
	for _, p in pool do
		r -= p[2]
		if r <= 0 then
			return p[1]
		end
	end
	return pool[#pool] and pool[#pool][1]
end

function VoyageService:RunEvent(plot, key)
	local v = state(plot)
	local e
	for _, ev in Voyages.EVENTS do
		if ev.key == key then
			e = ev
		end
	end
	if not e then
		return false
	end
	v.event = { key = e.key, name = e.name, icon = e.icon, ends = now() + e.seconds }
	v.lastEvent = e.key
	log(v, `{e.icon} {e.name}`)
	local here = players:PlayersOnPlot(plot)
	for _, p in here do
		Net.fire(
			p,
			"Callout",
			`{e.icon} {e.name}: {e.desc}`,
			(e.key == "storm" or e.key == "shark" or e.key == "serpent" or e.key == "whirlpool") and "bad" or "info"
		)
	end
	local fn = EVENT[e.key]
	if fn then
		fn(self, plot, v)
	end
	self:Push(plot)
	self.Event:Fire(plot, e, here)
	return true
end

-- Arrival --------------------------------------------------------------------------------------------------------------
function VoyageService:_arrive(plot)
	local v = state(plot)
	local raft = rafts:Get(plot)
	local d = v.dest
	v.state = "island"
	v.event = nil
	v.ends = nil
	island:Arrive(plot, d)
	log(v, `Land ho: {d.name}.`)
	local here = players:PlayersOnPlot(plot)
	for _, p in here do
		Net.fire(p, "Alert", `{d.icon} LAND HO! {string.upper(d.name)}`, Color3.fromRGB(255, 230, 120), 4)
		Net.fire(
			p,
			"Callout",
			d.kind == "deep" and "🌊 The water goes black. Harpoons ready."
				or `🏝️ {d.desc} Sail home from the helm when you're done.`,
			"good"
		)
		Net.fire(p, "Sfx", "discover")
		local profile = data:Get(p)
		if profile then
			profile.visited[d.key] = (profile.visited[d.key] or 0) + 1
		end
	end
	-- the crow's nest spots somewhere new
	if raft and rafts:Has(raft, "crow_nest", true) and raft.owner and raft.owner.Parent then
		local key = self:UnknownDestination(raft.owner, "nest", d.danger + 1)
		if key then
			Net.fire(raft.owner, "Callout", "🔭 From the crow's nest: land on the horizon!", "good")
			self:Reveal(raft.owner, key, "nest")
		end
	end
	self:Push(plot)
	self.Arrived:Fire(plot, d, here)
end

function VoyageService:_home(plot)
	local v = state(plot)
	local d = v.dest
	local danger = v.danger
	v.state = "docked"
	v.dest = nil
	v.event = nil
	v.ends = nil
	v.danger = 1
	log(v, "Home.")
	local here = players:PlayersOnPlot(plot)
	for _, p in here do
		inventory:ClearFinds(p)
		Net.fire(p, "Alert", "🏠 HOME · everything you found is safe", Color3.fromRGB(140, 230, 140), 3)
		Net.fire(p, "Sfx", "win")
	end
	self:Push(plot)
	self.Ended:Fire(plot, d, here, danger)
end

function VoyageService:_tick()
	local t = now()
	for plot, v in voyages do
		if not rafts:Get(plot) then
			voyages[plot] = nil
			continue
		end
		if v.state == "sailing" or v.state == "home" then
			if v.event and t >= v.event.ends then
				v.event = nil
				self:Push(plot)
			end
			if t >= v.ends then
				if v.state == "sailing" then
					self:_arrive(plot)
				else
					self:_home(plot)
				end
			elseif t >= (v.nextEventAt or math.huge) and v.ends - t > 10 and not v.event then
				local e = self:_pickEvent(v)
				if e then
					self:RunEvent(plot, e.key)
				end
				v.nextEventAt = t
					+ rng:NextNumber(Constants.VOYAGE_EVENT_EVERY[1], Constants.VOYAGE_EVENT_EVERY[2])
						* (v.state == "home" and 1 / Constants.HOME_EVENT_SHARE or 1)
			end
		end
	end
end

-- Boot ------------------------------------------------------------------------------------------------------------------
function VoyageService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	rafts = reg.RaftService
	inventory = reg.InventoryService
	players = reg.PlayerService
	ocean = reg.OceanService
	island = reg.IslandService
	weather = reg.WeatherService
	Net.on("Sail", function(player, destKey)
		if type(destKey) == "string" then
			self:Sail(player, destKey)
		end
	end)
	-- reading an artifact tells you where it came from
	inventory.Gained:Connect(function(player, key)
		if key == "logbook" then
			self:Reveal(player, "marrow_wreck", "logbook")
		elseif key == "idol" then
			self:Reveal(player, "the_trench", "idol")
		end
	end)
	-- Palm Key's note points at the wreck (§4: the first voyage leads to the next)
	island.Looked:Connect(function(player, isl, first)
		if first and isl.dest.key == "palm_key" then
			self:Reveal(player, "drift_wreck", "guide")
		end
	end)
	players.Moved:Connect(function(player, _, plot)
		if plot then
			Net.fire(player, "Voyage", self:View(plot))
		end
	end)
	rafts.Released:Connect(function(_, raft)
		local v = voyages[raft.plot]
		if v and v.state == "island" then
			island:Leave(raft.plot)
		end
		voyages[raft.plot] = nil
	end)
	rafts.Assigned:Connect(function(_, raft)
		state(raft.plot)
	end)
end

function VoyageService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		local plot = rafts:PlotOf(player)
		if plot then
			Net.fire(player, "Voyage", self:View(plot))
		end
	end)
end

function VoyageService:Start()
	while true do
		task.wait(0.5)
		self:_tick()
	end
end

-- (tests)
function VoyageService:_setEnds(plot, t)
	local v = state(plot)
	v.ends = t
end
VoyageService.EVENT = EVENT
_ = Players
return VoyageService

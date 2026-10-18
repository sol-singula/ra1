--[[
The soil and what grows in it (master plan §3, §5). A plot has Upgrades.stat(owned, "soil", START_SOIL) tiles; each
tile is empty or growing one crop (profile.soil[n] = { crop, at, need, watered, golden }): `at` is when it was
planted (the server clock, so timers run while the player is away), `need` the seconds it takes (watering cuts what's
left by Crops.WATER_CUT). Ripe when the time's up; the model on the tile shows four phases.

  ACT   Net "Farm" ("act") from the big action button: everything within REACH of them that can be done, best first:
        harvest every ripe tile, else plant every empty one (their chosen crop, or the best they have), else water
        every growing one not watered yet (once they own the well)
  tile  Net "Farm" ("plant" | "harvest" | "water", n) for one tile within TAP_REACH
  crop  Net "Farm" ("crop", key) picks what PLANT plants (unlocked crops only)
  sell  standing on the stand's pad sells everything carried (Upgrades.stat "price" on top)

Carrying: up to Upgrades.stat(owned, "carry", START_CARRY) crops (profile.storage); a full basket says so.
Net "Farm" to the owner: { tiles = { [n] = { crop, at, need, watered, golden } }, now, soil, carried, carry, crop,
crops, golden } whenever it changes.

  FarmService:Tiles(player)                -> the live tile parts (n -> Part)
  FarmService:Plant(player, n, key?) -> ok, why
  FarmService:Harvest(player, n) -> ok, why
  FarmService:Water(player, n) -> ok, why
  FarmService:Act(player) -> what ("harvest" | "plant" | "water" | nil), how many
  FarmService:Sell(player) -> Cash paid
  FarmService:Carried(player) / :Carry(player)
  FarmService:Ripe(player, n) / :Phase(player, n)
  FarmService:BuildTiles(player)           (after soil is bought) the tiles the plot has now
  FarmService:Push(player)
  FarmService.Changed (player, what)       "plant" | "harvest" | "water" | "sell"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local FarmService = {
	Name = "FarmService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService" },
	Changed = Signal.new("FarmService.Changed"),
	REACH = 11, -- studs from a tile's middle that ACT reaches
	TAP_REACH = 16,
	TICK = 0.25,
	SELL_REACH = 4.5,
}

local data, economy, plots, analytics
local phases = {} -- [player] = { [n] = the phase the model shows }
local selling = {} -- [player] = true while they stand on the pad (one sale per visit)

local function now()
	return workspace:GetServerTimeNow()
end

local function profileOf(player)
	local p = data:Get(player)
	if p then
		p.soil = p.soil or {}
		p.storage = p.storage or {}
		p.settings = p.settings or {}
	end
	return p
end

local function soilCount(p)
	return Upgrades.stat(p.owned or {}, "soil", Upgrades.START_SOIL)
end

function FarmService:Carry(player)
	local p = profileOf(player)
	return p and Upgrades.stat(p.owned or {}, "carry", Upgrades.START_CARRY) or 0
end

function FarmService:Carried(player)
	local p = profileOf(player)
	local n = 0
	for _, v in p and p.storage or {} do
		n += v
	end
	return n
end

function FarmService:Tiles(player)
	local refs = plots:Refs(player)
	return refs and refs.tiles or {}
end

local function tileState(p, n)
	local t = p.soil[tostring(n)]
	return t
end

local function progress(t)
	if not t then
		return 0
	end
	return math.clamp((now() - t.at) / math.max(0.01, t.need), 0, 1)
end

local function phaseOf(t)
	local k = progress(t)
	if k >= 1 then
		return 3
	elseif k >= 0.5 then
		return 2
	elseif k >= 0.15 then
		return 1
	end
	return 0
end

function FarmService:Phase(player, n)
	local p = profileOf(player)
	local t = p and tileState(p, n)
	return t and phaseOf(t) or nil
end

function FarmService:Ripe(player, n)
	return self:Phase(player, n) == 3
end

function FarmService:Push(player)
	local p = profileOf(player)
	if not p then
		return
	end
	local tiles = {}
	for n = 1, soilCount(p) do
		local t = tileState(p, n)
		tiles[n] = t
				and { crop = t.crop, at = t.at, need = t.need, watered = t.watered == true, golden = t.golden == true }
			or false
	end
	local golden = 0
	for key, v in p.storage do
		if string.sub(key, 1, 1) == "*" then
			golden += v
		end
	end
	Net.fire(player, "Farm", {
		tiles = tiles,
		now = now(),
		soil = soilCount(p),
		carried = self:Carried(player),
		carry = self:Carry(player),
		crop = self:Chosen(player),
		crops = Crops.unlocked(p.level or 1),
		golden = golden,
		well = Upgrades.stat(p.owned or {}, "water", 0) > 0,
	})
end

-- What PLANT plants: their pick, if they have it, else the best crop their level has
function FarmService:Chosen(player)
	local p = profileOf(player)
	if not p then
		return "strawberry"
	end
	local pick = p.settings.crop
	if pick and Crops[pick] and Crops[pick].level <= (p.level or 1) then
		return pick
	end
	return Crops.best(p.level or 1)
end

local function show(player, n)
	local p = profileOf(player)
	local tile = FarmService:Tiles(player)[n]
	local plot = plots:Plot(player)
	if not p or not tile or not plot then
		return
	end
	local t = tileState(p, n)
	phases[player] = phases[player] or {}
	local ph = t and phaseOf(t) or nil
	FarmBuilder.crop(plot, tile, t and t.crop or nil, ph, t and t.golden)
	FarmBuilder.water(tile, t ~= nil and t.watered == true and ph ~= 3)
	phases[player][n] = ph or false
end

function FarmService:BuildTiles(player)
	local p = profileOf(player)
	local plot = plots:Plot(player)
	local refs = plots:Refs(player)
	if not p or not plot or not refs then
		return
	end
	for n = 1, soilCount(p) do
		if not refs.tiles[n] then
			FarmBuilder.tile(plot, refs, n)
			show(player, n)
		end
	end
end

local function near(player, n, reach)
	local tile = FarmService:Tiles(player)[n]
	return tile ~= nil and plots:Near(player, tile, reach)
end

function FarmService:Plant(player, n, key)
	local p = profileOf(player)
	if not p or type(n) ~= "number" or n < 1 or n > soilCount(p) or n % 1 ~= 0 then
		return false, "tile"
	end
	if tileState(p, n) then
		return false, "busy"
	end
	key = key or self:Chosen(player)
	local c = Crops[key]
	if not c or c.level > (p.level or 1) then
		return false, "locked"
	end
	local sprinkler = Upgrades.stat(p.owned or {}, "sprinkler", 0) > 0
	local need = c.grow * (sprinkler and Crops.WATER_CUT or 1)
	-- (the golden roll happens now, so the field shows a golden crop while it grows)
	local golden = math.random() < Crops.GOLDEN_CHANCE + Upgrades.stat(p.owned or {}, "golden", 0)
	p.soil[tostring(n)] = { crop = key, at = now(), need = need, watered = sprinkler, golden = golden }
	p.stats.planted = (p.stats.planted or 0) + 1
	p.stats[key .. "s"] = (p.stats[key .. "s"] or 0) + 1
	show(player, n)
	return true
end

function FarmService:Water(player, n)
	local p = profileOf(player)
	if not p or Upgrades.stat(p.owned or {}, "water", 0) <= 0 then
		return false, "nowell"
	end
	local t = tileState(p, n)
	if not t or t.watered or phaseOf(t) == 3 then
		return false, "dry"
	end
	local left = t.need - (now() - t.at)
	t.need -= left * Crops.WATER_CUT
	t.watered = true
	p.stats.watered = (p.stats.watered or 0) + 1
	show(player, n)
	return true
end

function FarmService:Harvest(player, n)
	local p = profileOf(player)
	local t = p and tileState(p, n)
	if not t or phaseOf(t) ~= 3 then
		return false, "unripe"
	end
	if self:Carried(player) >= self:Carry(player) then
		return false, "full"
	end
	local c = Crops[t.crop]
	local golden = t.golden == true
	local bag = (golden and "*" or "") .. t.crop
	p.storage[bag] = (p.storage[bag] or 0) + 1
	p.stats.harvested = (p.stats.harvested or 0) + 1
	if c.regrow then
		t.at, t.watered = now(), false
		t.need = c.grow
		t.golden = math.random() < Crops.GOLDEN_CHANCE + Upgrades.stat(p.owned or {}, "golden", 0)
	else
		p.soil[tostring(n)] = nil
	end
	economy:AddXP(player, c.xp, "harvest")
	show(player, n)
	return true, golden
end

function FarmService:Act(player)
	local p = profileOf(player)
	if not p then
		return nil, 0
	end
	local count = soilCount(p)
	local list = {}
	for n = 1, count do
		if near(player, n, self.REACH) then
			table.insert(list, n)
		end
	end
	if #list == 0 then
		return nil, 0
	end
	local done, full = 0, false
	for _, n in list do
		if self:Ripe(player, n) then
			local ok, why = self:Harvest(player, n)
			if ok then
				done += 1
			elseif why == "full" then
				full = true
			end
		end
	end
	if done > 0 or full then
		if full then
			Net.fire(player, "Toast", "Your basket is full! Sell at the farm stand", "info")
		end
		self:Push(player)
		self.Changed:Fire(player, "harvest")
		return "harvest", done
	end
	for _, n in list do
		if not tileState(p, n) and self:Plant(player, n) then
			done += 1
		end
	end
	if done > 0 then
		self:Push(player)
		self.Changed:Fire(player, "plant")
		return "plant", done
	end
	for _, n in list do
		if self:Water(player, n) then
			done += 1
		end
	end
	if done > 0 then
		self:Push(player)
		self.Changed:Fire(player, "water")
		return "water", done
	end
	return nil, 0
end

function FarmService:Sell(player)
	local p = profileOf(player)
	if not p or self:Carried(player) == 0 then
		return 0
	end
	local price = 1 + Upgrades.stat(p.owned or {}, "price", 0)
	local total, n = 0, 0
	for bag, count in p.storage do
		local golden = string.sub(bag, 1, 1) == "*"
		local c = Crops[golden and string.sub(bag, 2) or bag]
		if c then
			total += c.value * count * (golden and Crops.GOLDEN_VALUE or 1)
			n += count
		end
	end
	table.clear(p.storage)
	total = math.floor(total * price + 0.5)
	p.stats.sold = (p.stats.sold or 0) + n
	economy:Add(player, total, "sell")
	economy:AddXP(player, math.max(1, math.floor(n / 2)), "sell")
	Net.fire(player, "Toast", `Sold {n} for {total} Cash!`, "good")
	if analytics then
		pcall(analytics.event, player, "sell", { n = n, cash = total })
	end
	self:Push(player)
	self.Changed:Fire(player, "sell")
	return total
end

function FarmService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	analytics = registry.AnalyticsService
	Net.on("Farm", function(player, what, a, b)
		if what == "act" then
			self:Act(player)
		elseif what == "crop" then
			local p = profileOf(player)
			if p and type(a) == "string" and Crops[a] and Crops[a].level <= (p.level or 1) then
				p.settings.crop = a
				self:Push(player)
			end
		elseif (what == "plant" or what == "harvest" or what == "water") and type(a) == "number" then
			if not near(player, a, self.TAP_REACH) then
				return
			end
			local ok
			if what == "plant" then
				ok = self:Plant(player, a, type(b) == "string" and b or nil)
			elseif what == "harvest" then
				ok = self:Harvest(player, a)
			else
				ok = self:Water(player, a)
			end
			if ok then
				self:Push(player)
				self.Changed:Fire(player, what)
			end
		end
	end)
	economy.LevelUp:Connect(function(player)
		self:Push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		phases[player] = nil
		selling[player] = nil
	end)
end

function FarmService:OnPlayerReady(player)
	self:BuildTiles(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function FarmService:_tick()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		local refs = plots:Refs(player)
		if not p or not refs then
			continue
		end
		-- the models follow the timers
		local seen = phases[player] or {}
		for n in refs.tiles do
			local t = tileState(p, n)
			local ph = t and phaseOf(t) or false
			if seen[n] ~= ph then
				show(player, n)
				if ph == 3 then
					self:Push(player) -- (ripe: the client's button and the guide move on)
					self.Changed:Fire(player, "ripe")
				end
			end
		end
		-- the stand's pad
		if refs.standPad and plots:Near(player, refs.standPad, self.SELL_REACH) then
			if not selling[player] then
				selling[player] = true
				if self:Carried(player) > 0 then
					self:Sell(player)
				else
					Net.fire(player, "Toast", "Nothing to sell yet: harvest your crops first", "info")
				end
			end
		else
			selling[player] = nil
		end
	end
end

function FarmService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[FarmService] tick failed: " .. tostring(err))
		end
	end
end

return FarmService

--[[
The soil and what grows in it (master plan §3, §5). A plot has Upgrades.stat(owned, "soil", START_SOIL) tiles; each
tile is empty or growing one crop (profile.soil[n] = { crop, at, need, watered, golden }): `at` is when it was
planted (the server clock, so timers run while the player is away), `need` the seconds it takes (watering cuts what's
left by Crops.WATER_CUT). Ripe when the time's up; the model on the tile shows four phases.

  ACT   Net "Farm" ("act") from the big action button: everything within REACH of them that can be done, best first:
        harvest every ripe tile, else plant every empty one (their chosen crop, or the best they have), else tend, else water
        every growing one not watered yet (once they own the well)
  TEND  between planting and harvesting, ACT tends every growing crop not tended yet (once each): it grows
        TEND_CUT faster from there and pays TEND_PAY of its price on the spot
  tile  Net "Farm" ("plant" | "harvest" | "water", n) for one tile within TAP_REACH
  crop  Net "Farm" ("crop", key) picks what PLANT plants (unlocked crops only)
  sell  standing on the stand's pad sells everything carried (Upgrades.stat "price" on top)

Carrying: up to Upgrades.stat(owned, "carry", START_CARRY) crops (profile.storage); a full basket says so.
Net "Farm" to the owner: { tiles = { [n] = { crop, at, need, watered, golden } }, now, soil, carried, carry, crop,
crops, golden } whenever it changes.

  FarmService:Tiles(player)                -> the live tile parts (n -> Part)
  FarmService:Plant(player, n, key?, machine?) -> ok, why   (machine: the tractor's, no golden seeds)
  FarmService:Harvest(player, n) -> ok, why
  FarmService:Water(player, n) -> ok, why
  FarmService:Tend(player, n) -> ok, paid  once a crop: TEND_CUT off what's left, TEND_PAY of its price paid
  FarmService:Act(player) -> what ("harvest" | "plant" | "water" | "tend" | nil), how many
  FarmService:Sell(player, quiet?) -> Cash paid   (quiet: the conveyor's, which keeps what FarmService.hold(player)
                                           returns, { [crop] = n }: what the orders need)
  FarmService:Worth(player, bag?) -> Cash, goods, products   what the basket (or a bag like it) would sell for
  FarmService.intake(player) -> true   (set by WarehouseService) the conveyor brings the basket to the warehouse
                                           instead of the stand
  FarmService:Stow(player, key, n) -> how many fit     goods into the basket (eggs, milk...)
  FarmService:Take(player, n) -> ok                   n crops out of the basket (feeding)
  FarmService:Machines(player, profile)              the tractor and the conveyor (each tick)
  FarmService:Carried(player) / :Carry(player)
  FarmService:Ripe(player, n) / :Phase(player, n)
  FarmService:BuildTiles(player)           (after soil is bought) the tiles the plot has now
  FarmService:Push(player)
  FarmService.Changed (player, what)       "plant" | "harvest" | "water" | "sell"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Franchise = require(ReplicatedStorage.Shared.Data.Franchise)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local Format = require(ReplicatedStorage.Shared.Format)
local Stand = require(ReplicatedStorage.Shared.Data.Stand)

local FarmService = {
	Name = "FarmService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService" },
	Changed = Signal.new("FarmService.Changed"),
	REACH = 11, -- studs from a tile's middle that ACT reaches
	TAP_REACH = 16,
	TICK = 0.25,
	SELL_REACH = 4.5,
	TEND_CUT = 0.4, -- a tend takes this share off what's left to grow
	TEND_PAY = 0.5, -- and pays this share of the crop's price, there and then
}

local data, economy, plots, analytics
local phases = {} -- [player] = { [n] = the phase the model shows }
local selling = {} -- [player] = true while they stand on the pad (one sale per visit)
local ripens = {} -- [player] = the soonest ripening a Changed is waiting for
local machineAt = {} -- [player] = { tractor = t, conveyor = t }: when each machine last ran

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
	return p and Upgrades.stat(p.owned or {}, "carry", Upgrades.START_CARRY) + Franchise.bonus(p, "carry") or 0
end

function FarmService:Carried(player)
	local p = profileOf(player)
	local n = 0
	for _, v in p and p.storage or {} do
		n += v
	end
	return n
end

-- Put goods in the basket (an animal's products): as many as fit; returns how many went in
function FarmService:Stow(player, key, n)
	local p = profileOf(player)
	if not p then
		return 0
	end
	local room = math.max(0, self:Carry(player) - self:Carried(player))
	local put = math.min(room, n)
	if put > 0 then
		p.storage[key] = (p.storage[key] or 0) + put
	end
	return put
end

-- Take n crops (not products, not golden) out of the basket, cheapest first (feeding the animals); false if short
function FarmService:Take(player, n)
	local p = profileOf(player)
	if not p then
		return false
	end
	local have = 0
	for key, count in p.storage do
		if Crops[key] then
			have += count
		end
	end
	if have < n then
		return false
	end
	local keys = {}
	for key in p.storage do
		if Crops[key] then
			table.insert(keys, key)
		end
	end
	table.sort(keys, function(a, b)
		return Crops[a].value < Crops[b].value
	end)
	for _, key in keys do
		local take = math.min(n, p.storage[key])
		p.storage[key] -= take
		if p.storage[key] <= 0 then
			p.storage[key] = nil
		end
		n -= take
		if n <= 0 then
			break
		end
	end
	return true
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
				and {
					crop = t.crop,
					at = t.at,
					need = t.need,
					watered = t.watered == true,
					golden = t.golden == true,
					tended = t.tended == true,
				}
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
	-- (the guide moves on the moment something ripens: HARVEST, not TEND)
	local soonest
	for _, t in tiles do
		if t then
			local left = t.need - (now() - t.at)
			if left > 0 and (not soonest or left < soonest) then
				soonest = left
			end
		end
	end
	if soonest then
		local at = now() + soonest
		if not ripens[player] or ripens[player] < now() or at < ripens[player] - 0.05 then
			ripens[player] = at
			task.delay(soonest + 0.05, function()
				if ripens[player] == at and player.Parent then
					ripens[player] = nil
					self.Changed:Fire(player, "ripe")
					self:Push(player)
				end
			end)
		end
	end
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

-- Every crop growing ripe now (the shop's Instant Harvest and Ripen Everything): how many
function FarmService:RipenAll(player)
	local p = profileOf(player)
	if not p then
		return 0
	end
	local n = 0
	for i = 1, soilCount(p) do
		local t = tileState(p, i)
		if t and phaseOf(t) < 3 then
			t.at = now() - t.need
			n += 1
			show(player, i)
		end
	end
	self:Push(player)
	return n
end

local function near(player, n, reach)
	local tile = FarmService:Tiles(player)[n]
	return tile ~= nil and plots:Near(player, tile, reach)
end

function FarmService:Plant(player, n, key, machine)
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
	-- (the chickens make everything grow faster, the cows the fruit)
	local speed = 1
		+ Animals.boost(p, "grow", now())
		+ (c.type == "fruit" and Animals.boost(p, "fruitGrow", now()) or 0)
		+ Upgrades.stat(p.owned or {}, "grow", 0)
		+ Franchise.bonus(p, "growth")
	local need = c.grow * (sprinkler and Crops.WATER_CUT or 1) / speed / (Crops.starter(p.level))
	-- (the golden roll happens now, so the field shows a golden crop while it grows)
	local golden = false
	if (p.goldenSeeds or 0) > 0 and not machine then
		-- (a golden seed from the calendar or the shop goes first: in their own planting, not the tractor's)
		p.goldenSeeds -= 1
		golden = true
	else
		golden = math.random() < FarmService.goldenChance(p)
	end
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

function FarmService:Tend(player, n)
	local p = profileOf(player)
	local t = p and tileState(p, n)
	if not t or t.tended or phaseOf(t) == 3 then
		return false, "no"
	end
	local left = t.need - (now() - t.at)
	t.need -= math.max(left, 0) * self.TEND_CUT
	t.tended = true
	local c = Crops[t.crop]
	local _, starter = Crops.starter(p.level)
	local paid =
		math.max(1, math.floor(c.value * starter * self.TEND_PAY * (t.golden and Crops.GOLDEN_VALUE or 1) + 0.5))
	economy:Add(player, paid, "tend")
	p.stats.tended = (p.stats.tended or 0) + 1
	show(player, n)
	return true, paid
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
		t.golden = math.random() < FarmService.goldenChance(p)
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
		if self:Tend(player, n) then
			done += 1
		end
	end
	if done > 0 then
		self:Push(player)
		self.Changed:Fire(player, "tend")
		return "tend", done
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

function FarmService.goldenChance(p)
	return Crops.GOLDEN_CHANCE + Upgrades.stat(p.owned or {}, "golden", 0) + Animals.boost(p, "golden", now())
end

-- What the basket is worth at the stand: the crops (golden ones 10x; the pigs lift the vegetables) and the animals'
-- products, all times the stand's price
function FarmService:Worth(player, bag)
	local p = profileOf(player)
	if not p then
		return 0, 0, 0
	end
	bag = bag or p.storage
	local price = 1 + Upgrades.stat(p.owned or {}, "price", 0) + Stand.bonus(p.level)
	local veg = 1 + Animals.boost(p, "vegPrice", now())
	local _, starter = Crops.starter(p.level)
	local total, n, products = 0, 0, 0
	for item, count in bag do
		local golden = string.sub(item, 1, 1) == "*"
		local key = golden and string.sub(item, 2) or item
		local c = Crops[key]
		local product = not c and Animals.product(key)
		if c then
			total += c.value * starter * count * (golden and Crops.GOLDEN_VALUE or 1) * (c.type == "veg" and veg or 1)
			n += count
		elseif product then
			total += product.value * count
			n += count
			products += count
		end
	end
	return math.floor(total * price + 0.5), n, products
end

function FarmService:Sell(player, quiet)
	local p = profileOf(player)
	if not p or self:Carried(player) == 0 then
		return 0
	end
	-- (the conveyor leaves what the open orders still need: FarmService.hold, set by OrderService)
	local kept = {}
	if quiet and self.hold then
		for key, want in self.hold(player) or {} do
			local k = math.min(want, p.storage[key] or 0)
			if k > 0 then
				kept[key] = k
				p.storage[key] -= k
				if p.storage[key] <= 0 then
					p.storage[key] = nil
				end
			end
		end
	end
	local total, n, products = self:Worth(player)
	table.clear(p.storage)
	for key, k in kept do
		p.storage[key] = k
	end
	if n == 0 then
		return 0
	end
	p.stats.sold = (p.stats.sold or 0) + n
	p.stats.soldProducts = (p.stats.soldProducts or 0) + products
	economy:Add(player, total, "sell")
	economy:AddXP(player, math.max(1, math.floor(n / 2)), "sell")
	if not quiet then
		Net.fire(player, "Toast", `Sold {n} for {Format.cash(total)}!`, "good")
	end
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
	economy.LevelUp:Connect(function(player, level)
		self:Push(player)
		local before = Stand.tier(level - 1)
		if self:Stand(player) > before then
			local t = Stand.TIERS[Stand.tier(level)]
			Net.fire(
				player,
				"Toast",
				`Your stand grew: {t.name}! +{math.floor(t.bonus * 100 + 0.5)}% on every sale`,
				"good"
			)
		end
	end)
	-- (forget them when they leave, or when their plot comes down for a rebuild: a franchise)
	local function forget(player)
		phases[player] = nil
		selling[player] = nil
		machineAt[player] = nil
		ripens[player] = nil
	end
	Players.PlayerRemoving:Connect(forget)
	registry.PlotService.Released:Connect(forget)
end

-- The stand's building for their level (Data/Stand): rebuilt when it goes up a tier
function FarmService:Stand(player)
	local p = profileOf(player)
	local plot = plots:Plot(player)
	local tier = Stand.tier(p and p.level or 1)
	if plot then
		FarmBuilder.standTier(plot, tier)
	end
	return tier
end

function FarmService:OnPlayerReady(player)
	self:BuildTiles(player)
	self:Stand(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

-- The tractor and the conveyor: every so often (the sheep make them quicker) the tractor harvests what's ripe and
-- plants again; the conveyor collects from the pens, feeds the animals, takes the basket to the stand and sells it
function FarmService:Machines(player, p)
	local t = now()
	local m = machineAt[player]
	if not m then
		m = { tractor = t, conveyor = t }
		machineAt[player] = m
	end
	local quick = 1 + Animals.boost(p, "machine", t)
	local tractor = Upgrades.stat(p.owned or {}, "autoharvest", nil)
	-- (TractorService drives it round the fields when it's running: FarmService.tractorDriven)
	if tractor and not self.tractorDriven and t - m.tractor >= tractor / quick then
		m.tractor = t
		local harvested, planted = 0, 0
		for n in self:Tiles(player) do
			if self:Ripe(player, n) and self:Harvest(player, n) then
				harvested += 1
			end
			if not tileState(p, n) and self:Plant(player, n, nil, true) then
				planted += 1
			end
		end
		if harvested + planted > 0 then
			self:Push(player)
			self.Changed:Fire(player, "tractor")
		end
	end
	local conveyor = Upgrades.stat(p.owned or {}, "autosell", nil)
	if conveyor and t - m.conveyor >= conveyor / quick then
		m.conveyor = t
		-- (on the way it calls at the pens: collects what's waiting, feeds the hungry: FarmService.belt, set by
		-- AnimalService)
		if self.belt then
			self.belt(player)
		end
		if self:Carried(player) > 0 and not (self.intake and self.intake(player)) then
			self:Sell(player, true)
		end
	end
end

function FarmService:_tick()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		local refs = plots:Refs(player)
		if not p or not refs then
			continue
		end
		self:Machines(player, p)
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

--[[
The crops (master plan §1, §5): tiles in the fields you own, each growing one crop at a time. Plant by tapping an
empty tile (or PLANT ALL); harvest by tapping a ripe one, walking over it, or with a machine (AutomationService).
Harvested units go into the business's stock; a full stock area stops the harvest (the crops wait, ripe, on their
tiles: nothing is lost, and the storage bottleneck is there to see).

Growth runs on os.time, so what was planted keeps growing while they're away.

  CropService:Tiles(player)        every tile id you own, in route order (field by field, row by row)
  CropService:Plant(player, id)    ok, why
  CropService:Harvest(player, id, by)   units harvested (0: not ripe, storage full)
  CropService:Ripe(player, id)
  CropService:Summary(player)      { tiles, planted, empty, ripe, perMinute (units the field grows a minute) }
  CropService:GrowthMult(player)
  CropService:Golden(player)       the golden crop's tile now (nil: none); a tap pays GOLDEN_MULT x its price
  CropService:TapGolden(player, id)   the cash paid (0: not golden)
  CropService:Push(player)
  CropService.Changed (player, what)   "plant" | "harvest" | "chosen" | "fields"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local CropService = {
	Name = "CropService",
	Dependencies = { "PlayerDataService", "BusinessService" },
	Changed = Signal.new("CropService.Changed"),
	STARTER_TILES = 4,
	GOLDEN_EVERY = { 35, 55 }, -- seconds between golden crops
	GOLDEN_LIFE = 25, -- seconds one stays before it fades
	GOLDEN_MULT = 20, -- a golden crop pays this many times its sale price, at once
}

local data, business, analytics, territory
local pushDue = {}
local toldFull = {} -- [player] = when the "storage full" toast last went
local golden = {} -- [player] = { id, untilT } the golden crop showing now
local nextGolden = {} -- [player] = when the next one appears
local economy

function CropService:GrowthMult(player)
	local p = data:Get(player)
	return 1 + Upgrades.stat(p and p.owned or {}, "growth", 0) + (p and Animals.boost(p, "grow", os.time()) or 0)
end

-- The tiles owned: field1 grows 4 at a time with "tiles"; the other fields come whole
function CropService:Tiles(player)
	local p = data:Get(player)
	local out = {}
	if not p then
		return out
	end
	local n1 = math.min(Layout.FIELDS.field1.tiles, self.STARTER_TILES + 4 * (p.owned.tiles or 0))
	for n = 1, n1 do
		table.insert(out, Layout.tileId("field1", n))
	end
	for _, key in { "field2", "field3", "field4" } do
		if (p.owned[key] or 0) > 0 then
			for n = 1, Layout.FIELDS[key].tiles do
				table.insert(out, Layout.tileId(key, n))
			end
		end
	end
	return out
end

function CropService:Owns(player, id)
	local p = data:Get(player)
	if not p then
		return false
	end
	local key, n = Layout.parseTile(id)
	if not key or not n or n < 1 or n > Layout.FIELDS[key].tiles then
		return false
	end
	if key == "field1" then
		return n <= self.STARTER_TILES + 4 * (p.owned.tiles or 0)
	end
	return (p.owned[key] or 0) > 0
end

function CropService:Unlocked(player, cropKey)
	local p = data:Get(player)
	local c = Crops[cropKey]
	if not p or not c then
		return false
	end
	return c.unlock == nil or (p.owned[c.unlock] or 0) > 0
end

function CropService:Ripe(player, id)
	local p = data:Get(player)
	local t = p and p.tiles[id]
	if not t or not Crops[t.crop] then
		return false
	end
	return os.time() - t.at >= Crops[t.crop].grow / self:GrowthMult(player)
end

function CropService:Choose(player, cropKey)
	local p = data:Get(player)
	if not p or not self:Unlocked(player, cropKey) then
		return false
	end
	p.chosen = cropKey
	pushDue[player] = true
	self.Changed:Fire(player, "chosen")
	return true
end

function CropService:Plant(player, id, cropKey)
	local p = data:Get(player)
	if not p then
		return false, "no profile"
	end
	if not self:Owns(player, id) then
		return false, "not yours"
	end
	if p.tiles[id] then
		return false, "planted"
	end
	cropKey = cropKey or p.chosen
	if not self:Unlocked(player, cropKey) then
		cropKey = "strawberry"
	end
	p.tiles[id] = { crop = cropKey, at = os.time() }
	p.stats.planted = (p.stats.planted or 0) + 1
	pushDue[player] = true
	if analytics then
		pcall(analytics.event, player, "plant", { crop = cropKey })
	end
	self.Changed:Fire(player, "plant")
	return true
end

function CropService:PlantAll(player)
	local n = 0
	for _, id in self:Tiles(player) do
		if self:Plant(player, id) then
			n += 1
		end
	end
	return n
end

-- The golden crop: a planted tile that shines for a while; a tap pays GOLDEN_MULT times its price at once
function CropService:Golden(player)
	local g = golden[player]
	if g and os.clock() < g.untilT then
		return g.id
	end
	return nil
end

function CropService:IsGolden(player, id)
	return self:Golden(player) == id
end

function CropService:GoldenValue(player, id)
	local p = data:Get(player)
	local t = p and p.tiles[id]
	if not t or not Crops[t.crop] then
		return 0
	end
	local mult = Upgrades.priceMult(p.owned) * (1 + Animals.boost(p, "price", os.time()))
	return math.floor(Crops[t.crop].value * mult * self.GOLDEN_MULT * (economy and economy:Multiplier(player) or 1))
end

function CropService:TapGolden(player, id)
	if not self:IsGolden(player, id) then
		return 0
	end
	local p = data:Get(player)
	local cash = self:GoldenValue(player, id)
	golden[player] = nil
	local now = os.clock()
	nextGolden[player] = now + math.random(self.GOLDEN_EVERY[1], self.GOLDEN_EVERY[2])
	p.stats.golden = (p.stats.golden or 0) + 1
	local key, n = Layout.parseTile(id)
	local x, z = Layout.tilePos(key, n)
	local at = territory and territory:Territory(player)
	economy:Add(player, cash, "golden", at and Layout.toWorld(at.index, x, z, 3) or nil)
	Net.fire(player, "Toast", `⭐ Golden crop! +{Format.cash(cash)}`, "good")
	Net.fire(player, "Golden", { tile = id, cash = cash, x = x, z = z })
	pushDue[player] = true
	return cash
end

-- A new golden crop now and then (once the first harvest is in): a random planted tile
function CropService:GoldenTick(player)
	local p = data:Get(player)
	if not p or (p.stats.harvested or 0) < 3 then
		return
	end
	local now = os.clock()
	local g = golden[player]
	if g and now >= g.untilT then
		golden[player] = nil
		pushDue[player] = true
	end
	if golden[player] then
		return
	end
	nextGolden[player] = nextGolden[player] or now + 20
	if now < nextGolden[player] then
		return
	end
	local planted = {}
	for _, id in self:Tiles(player) do
		if p.tiles[id] then
			table.insert(planted, id)
		end
	end
	if #planted == 0 then
		return
	end
	golden[player] = { id = planted[math.random(1, #planted)], untilT = now + self.GOLDEN_LIFE }
	nextGolden[player] = now + self.GOLDEN_LIFE + math.random(self.GOLDEN_EVERY[1], self.GOLDEN_EVERY[2])
	pushDue[player] = true
end

-- by: "hand" | "walk" | "machine"
function CropService:Harvest(player, id, by)
	local p = data:Get(player)
	if not p or not self:Ripe(player, id) then
		return 0
	end
	local t = p.tiles[id]
	local crop = Crops[t.crop]
	if not business:Store(player, t.crop, 1) then
		local now = os.clock()
		if by ~= "machine" and now - (toldFull[player] or -10) > 4 then
			toldFull[player] = now
			Net.fire(player, "Toast", "Storage is full! Sell faster or buy more storage.", "bad")
		end
		return 0
	end
	p.stats.harvested = (p.stats.harvested or 0) + 1
	if (p.owned.seeder or 0) > 0 then
		-- replanted at once, with the crop chosen now (switching crops is one tap on the bar)
		local next_ = self:Unlocked(player, p.chosen) and p.chosen or t.crop
		p.tiles[id] = { crop = next_, at = os.time() }
	else
		p.tiles[id] = nil
	end
	pushDue[player] = true
	local key, n = Layout.parseTile(id)
	local x, z = Layout.tilePos(key, n)
	Net.fire(player, "Harvested", { tile = id, crop = t.crop, n = 1, by = by or "hand", x = x, z = z })
	if analytics then
		pcall(analytics.event, player, "harvest", { crop = t.crop, by = by })
	end
	self.Changed:Fire(player, "harvest")
	_ = crop
	return 1
end

function CropService:RipeList(player)
	local out = {}
	for _, id in self:Tiles(player) do
		if self:Ripe(player, id) then
			table.insert(out, id)
		end
	end
	return out
end

function CropService:Summary(player)
	local p = data:Get(player)
	local s = { tiles = 0, planted = 0, empty = 0, ripe = 0, perMinute = 0, valuePerMinute = 0 }
	if not p then
		return s
	end
	local mult = self:GrowthMult(player)
	for _, id in self:Tiles(player) do
		s.tiles += 1
		local t = p.tiles[id]
		if t and Crops[t.crop] then
			s.planted += 1
			local c = Crops[t.crop]
			s.perMinute += 60 / c.grow * mult
			s.valuePerMinute += 60 / c.grow * mult * c.value
			if os.time() - t.at >= c.grow / mult then
				s.ripe += 1
			end
		else
			s.empty += 1
		end
	end
	return s
end

function CropService:Push(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local tiles = {}
	for _, id in self:Tiles(player) do
		local t = p.tiles[id]
		tiles[id] = t and { crop = t.crop, at = t.at } or false
	end
	local unlocked = {}
	for _, key in Crops.LIST do
		if self:Unlocked(player, key) then
			table.insert(unlocked, key)
		end
	end
	Net.fire(player, "Crops", {
		chosen = p.chosen,
		seeder = (p.owned.seeder or 0) > 0,
		growth = self:GrowthMult(player),
		tiles = tiles,
		unlocked = unlocked,
		golden = self:Golden(player),
		goldenValue = self:Golden(player) and self:GoldenValue(player, self:Golden(player)) or nil,
		serverTime = os.time(),
	})
end

function CropService:Init(registry)
	data = registry.PlayerDataService
	business = registry.BusinessService
	analytics = registry.AnalyticsService
	economy = registry.EconomyService
	territory = registry.TerritoryService
	Net.on("Crop", function(player, what, arg)
		if what == "plant" and type(arg) == "string" then
			self:Plant(player, arg)
		elseif what == "harvest" and type(arg) == "string" then
			if self:TapGolden(player, arg) == 0 then
				self:Harvest(player, arg, "hand")
			end
		elseif what == "choose" and type(arg) == "string" then
			self:Choose(player, arg)
		elseif what == "plantAll" then
			self:PlantAll(player)
		end
	end)
	registry.UpgradeService.Applied:Connect(function(player, key)
		local p = data:Get(player)
		local e = Upgrades[key] and Upgrades[key].effect or {}
		if p and (e.tiles or e.field or e.seeder) and (p.owned.seeder or 0) > 0 then
			self:PlantAll(player) -- (the seeder plants new land too)
		end
		pushDue[player] = true
		self.Changed:Fire(player, "fields")
	end)
	Players.PlayerRemoving:Connect(function(player)
		pushDue[player] = nil
		toldFull[player] = nil
		golden[player], nextGolden[player] = nil, nil
	end)
end

function CropService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function CropService:Start()
	while true do
		task.wait(0.25)
		for _, player in Players:GetPlayers() do
			pcall(self.GoldenTick, self, player)
			if pushDue[player] then
				pushDue[player] = nil
				pcall(self.Push, self, player)
			end
		end
	end
end

return CropService

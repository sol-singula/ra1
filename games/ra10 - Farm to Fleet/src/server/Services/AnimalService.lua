--[[
The animals (master plan §6, Data/Animals): each pen the plot buys (an upgrade of kind "animal") gets its animal,
which lives there (outside the warehouse, always), makes its product and gives the farm its boost.

  the pad   standing on a pen's pad (at its gate) collects what's ready into the basket and, if they're hungry,
            feeds them (Animals.FEED_CROPS crops from the basket); the pen's panel opens on their screen
  feed      Net "Animal" ("feed", key): the same feeding, from the panel
  upgrade   Net "Animal" ("upgrade", key) at the pen: Cash for the next level (Animals.upgradeCost), up to
            Animals.MAX_LEVEL: a bigger boost, faster products, more animals in the pen, a ribbon at 5, a bell at 10
  making    a product every Animals[key].every seconds (faster with level; half as fast while hungry), up to
            Animals.READY_CAP waiting
  the belt  once the farm has the conveyor, each of its runs collects every pen and feeds the hungry (AnimalService:Belt),
            then it sells the lot
  the horse speeds up walking (Animals.boost "speed") once there's a stable

profile.animals[key] = { level, fedAt, ready, madeAt }. Net "Animal" to the owner: { pens = { [key] = { level,
fed, fedLeft, ready, cost, maxed, boost } }, at = the pen they're standing at (or nil) } whenever it changes.

  AnimalService:Pens(player)          { [key] = { pad, folder } } the pens on their plot
  AnimalService:Feed(player, key) -> ok, why ("full" | "crops" | "none")
  AnimalService:Collect(player, key) -> how many
  AnimalService:Belt(player) -> collected, fed      the conveyor's call at the pens
  AnimalService:Upgrade(player, key) -> ok, why ("max" | "cash" | "none")
  AnimalService:Push(player, at?)
  AnimalService.Changed (player, key, what)   "feed" | "collect" | "upgrade" | "new"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local FarmBuilder = require(ReplicatedStorage.Shared.World.FarmBuilder)
local Net = require(ReplicatedStorage.Shared.Net)
local PlotLayout = require(ReplicatedStorage.Shared.World.PlotLayout)
local Signal = require(ReplicatedStorage.Shared.Signal)

local AnimalService = {
	Name = "AnimalService",
	Dependencies = { "PlayerDataService", "EconomyService", "PlotService", "FarmService", "UpgradeService" },
	Changed = Signal.new("AnimalService.Changed"),
	REACH = 4,
	TICK = 0.5,
	WALK = 24,
}

local data, economy, plots, farm, upgrades, analytics
local pens = {} -- [player] = { [key] = { pad, folder, herd = Folder } }
local standing = {} -- [player] = the pen key they're on

local function now()
	return workspace:GetServerTimeNow()
end

local function stateOf(p, key)
	p.animals = p.animals or {}
	return p.animals[key]
end

function AnimalService:Pens(player)
	return pens[player] or {}
end

local BOOST_WORDS = {
	grow = "crops grow +%d%% faster",
	fruitGrow = "fruit grows +%d%% faster",
	vegPrice = "vegetables sell +%d%%",
	machine = "machines +%d%% faster",
	orders = "orders pay +%d%%",
	speed = "you walk +%d%% faster",
}

local function boostText(key, st, t)
	local a = Animals[key]
	local k = Animals.fed(st, t) and 1 or Animals.HUNGRY
	return string.format(BOOST_WORDS[a.boost.kind] or "+%d%%", math.floor(a.boost.per * st.level * k * 100 + 0.5))
end

function AnimalService:Push(player, at)
	local p = data:Get(player)
	if not p then
		return
	end
	local t = now()
	local out = {}
	for key in self:Pens(player) do
		local st = stateOf(p, key)
		if st then
			out[key] = {
				level = st.level,
				fed = Animals.fed(st, t),
				fedLeft = math.max(0, math.floor(Animals.FED_SECONDS - (t - (st.fedAt or 0)))),
				ready = st.ready or 0,
				cost = st.level < Animals.MAX_LEVEL and Animals.upgradeCost(key, st.level) or nil,
				maxed = st.level >= Animals.MAX_LEVEL,
				boost = boostText(key, st, t),
				product = Animals[key].productName,
			}
		end
	end
	Net.fire(player, "Animal", { pens = out, at = at or standing[player] })
end

-- The animals in a pen: Animals.count(level) of them, spread over the pen's open half, ready for the client to walk
local function herd(player, key)
	local pen = pens[player] and pens[player][key]
	local p = data:Get(player)
	local plot = plots:Plot(player)
	if not pen or not p or not plot then
		return
	end
	local st = stateOf(p, key)
	if pen.herd then
		pen.herd:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Herd"
	folder.Parent = pen.folder
	pen.herd = folder
	local c = PlotLayout.SPOTS.pens[key]
	if not c then
		return
	end
	local W, D = PlotLayout.PEN.X, PlotLayout.PEN.Z
	local lo = PlotLayout.toWorld(plot.index, c.X - W / 2 + 4, c.Z - D / 2 + 4, 0)
	local hi = PlotLayout.toWorld(plot.index, c.X + W / 2 - 4, c.Z + D / 2 - 14, 0)
	local mn = Vector3.new(math.min(lo.X, hi.X), 0.25, math.min(lo.Z, hi.Z))
	local mx = Vector3.new(math.max(lo.X, hi.X), 0.25, math.max(lo.Z, hi.Z))
	local r = Random.new(player.UserId + #key)
	for i = 1, Animals.count(st.level) do
		local at = Vector3.new(r:NextNumber(mn.X, mx.X), 0.25, r:NextNumber(mn.Z, mx.Z))
		local m = FarmBuilder.animal(folder, key, at, st.level, r:NextNumber(0, math.pi * 2))
		m:SetAttribute("PenMin", mn)
		m:SetAttribute("PenMax", mx)
		m:SetAttribute("Index", i)
	end
end

local function addPen(player, key)
	local plot = plots:Plot(player)
	local p = data:Get(player)
	if not plot or not p then
		return
	end
	local a = Animals[key]
	local folder = a and plot.items:FindFirstChild(a.pen)
	local pad = folder and folder:FindFirstChild("PenPad", true)
	if not pad then
		return
	end
	pens[player] = pens[player] or {}
	pens[player][key] = { pad = pad, folder = folder }
	if not stateOf(p, key) then
		-- (they arrive hungry: the first visit to the pad teaches feeding)
		p.animals[key] = { level = 1, fedAt = 0, ready = 0, madeAt = now() }
		AnimalService.Changed:Fire(player, key, "new")
	end
	herd(player, key)
end

function AnimalService:Feed(player, key)
	local p = data:Get(player)
	local st = p and stateOf(p, key)
	if not st then
		return false, "none"
	end
	if Animals.fed(st, now()) and now() - (st.fedAt or 0) < Animals.FED_SECONDS * 0.75 then
		return false, "full"
	end
	if not farm:Take(player, Animals.FEED_CROPS) then
		return false, "crops"
	end
	st.fedAt = now()
	p.stats.fed = (p.stats.fed or 0) + 1
	farm:Push(player)
	self.Changed:Fire(player, key, "feed")
	return true
end

-- Every animal fed, no crops needed (the shop's Feed Everyone): how many
-- The conveyor's call at the pens: everything waiting into the basket, the hungry fed
function AnimalService:Belt(player)
	local p = data:Get(player)
	if not p then
		return 0, 0
	end
	local got, fed = 0, 0
	for _, key in Animals.LIST do
		if stateOf(p, key) then
			got += self:Collect(player, key)
			local st = stateOf(p, key)
			if not Animals.fed(st, now()) and self:Feed(player, key) then
				fed += 1
			end
		end
	end
	return got, fed
end

function AnimalService:FeedAll(player)
	local p = data:Get(player)
	if not p then
		return 0
	end
	local n = 0
	for key in p.animals or {} do
		local st = stateOf(p, key)
		if st then
			st.fedAt = now()
			n += 1
			self.Changed:Fire(player, key, "feed")
		end
	end
	return n
end

function AnimalService:Collect(player, key)
	local p = data:Get(player)
	local st = p and stateOf(p, key)
	local a = Animals[key]
	if not st or not a.product or (st.ready or 0) <= 0 then
		return 0
	end
	local put = farm:Stow(player, a.product, st.ready)
	if put > 0 then
		st.ready -= put
		p.stats.collected = (p.stats.collected or 0) + put
		p.stats[a.product .. "s"] = (p.stats[a.product .. "s"] or 0) + put
		economy:AddXP(player, put, "collect")
		farm:Push(player)
		self.Changed:Fire(player, key, "collect")
	end
	return put
end

function AnimalService:Upgrade(player, key)
	local p = data:Get(player)
	local st = p and stateOf(p, key)
	if not st then
		return false, "none"
	end
	if st.level >= Animals.MAX_LEVEL then
		return false, "max"
	end
	if not economy:Spend(player, Animals.upgradeCost(key, st.level)) then
		return false, "cash"
	end
	st.level += 1
	economy:AddXP(player, 10 * st.level, "animal")
	herd(player, key)
	Net.fire(player, "Toast", `{string.upper(Animals[key].name)} LEVEL {st.level}!`, "good")
	if analytics then
		pcall(analytics.event, player, "animal", { key = key, level = st.level })
	end
	self.Changed:Fire(player, key, "upgrade")
	self:Push(player)
	return true
end

-- The horse: walking speed (and back to normal without one)
local function walk(player)
	local p = data:Get(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if p and hum then
		hum.WalkSpeed = AnimalService.WALK * (1 + Animals.boost(p, "speed", now()))
	end
end

function AnimalService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	plots = registry.PlotService
	farm = registry.FarmService
	upgrades = registry.UpgradeService
	analytics = registry.AnalyticsService
	farm.belt = function(player)
		self:Belt(player)
	end
	upgrades.Applied:Connect(function(player, u)
		if u.kind == "animal" then
			addPen(player, u.value)
			self:Push(player)
		end
	end)
	Net.on("Animal", function(player, what, key)
		if type(key) ~= "string" or not Animals[key] then
			return
		end
		local pen = self:Pens(player)[key]
		if not pen or not plots:Near(player, pen.pad, self.REACH + 4) then
			return
		end
		if what == "feed" then
			local ok, why = self:Feed(player, key)
			if not ok and why == "crops" then
				Net.fire(player, "Toast", `Bring {Animals.FEED_CROPS} crops in your basket to feed them`, "info")
			elseif not ok and why == "full" then
				Net.fire(player, "Toast", "They're full! Come back later", "info")
			end
			self:Push(player)
		elseif what == "upgrade" then
			local ok, why = self:Upgrade(player, key)
			if not ok and why == "cash" then
				local p = data:Get(player)
				local short = Animals.upgradeCost(key, stateOf(p, key).level) - math.floor(p.cash)
				Net.fire(player, "Toast", `Need {short} more Cash`, "info")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pens[player] = nil
		standing[player] = nil
	end)
	plots.Released:Connect(function(player)
		pens[player] = nil
	end)
end

function AnimalService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
	player.CharacterAdded:Connect(function()
		task.defer(walk, player)
	end)
	walk(player)
end

function AnimalService:_tick(dt)
	local t = now()
	for _, player in Players:GetPlayers() do
		local p = data:Get(player)
		local mine = pens[player]
		if not p or not mine then
			continue
		end
		local changed = false
		for key, pen in mine do
			local st = stateOf(p, key)
			local a = Animals[key]
			-- making products
			if st and a.product and (st.ready or 0) < Animals.READY_CAP then
				local every = a.every / (1 + 0.1 * (st.level - 1)) / (Animals.fed(st, t) and 1 or Animals.HUNGRY)
				st.madeAt = st.madeAt or t
				while t - st.madeAt >= every and (st.ready or 0) < Animals.READY_CAP do
					st.madeAt += every
					st.ready = (st.ready or 0) + 1
					changed = true
				end
			elseif st then
				st.madeAt = t
			end
			-- the pad
			local on = plots:Near(player, pen.pad, self.REACH)
			if on and standing[player] ~= key then
				standing[player] = key
				local got = self:Collect(player, key)
				if got > 0 then
					Net.fire(player, "Toast", `+{got} {a.productName}!`, "good")
				end
				if not Animals.fed(st, t) then
					local ok = self:Feed(player, key)
					if ok then
						Net.fire(player, "Toast", `Fed your {string.lower(a.name)}s!`, "good")
					else
						Net.fire(
							player,
							"Toast",
							`They're hungry: bring {Animals.FEED_CROPS} crops to feed them`,
							"info"
						)
					end
				end
				changed = true
			elseif not on and standing[player] == key then
				standing[player] = nil
				changed = true
			end
		end
		if changed then
			self:Push(player)
		end
		walk(player)
	end
	_ = dt
end

function AnimalService:Start()
	while true do
		local dt = task.wait(self.TICK)
		local ok, err = pcall(self._tick, self, dt)
		if not ok then
			warn("[AnimalService] tick failed: " .. tostring(err))
		end
	end
end

return AnimalService

--[[
The animals (master plan §6, Data/Animals): each pen the plot buys (an upgrade of kind "animal") gets its animals,
which live there and give the whole farm a boost that grows with their level. They make nothing to sell: the boost
is the point.

  the pad   standing on a pen's pad (at its gate) opens the pen's panel; hungry animals get fed by walking up
  feed      Net "Animal" ("feed", key): FEED is free; fed animals give the whole boost for Animals.FED_SECONDS,
            hungry ones half of it
  tend      Net "Animal" ("tend", key): a pat: they're HAPPY (the boost doubled) for Animals.HAPPY_SECONDS, once
            every Animals.TEND_GAP
  upgrade   Net "Animal" ("upgrade", key) at the pen: Cash for the next level (Animals.upgradeCost): a bigger boost
            and more animals in the pen; there's no top level
  the horse speeds up walking (Animals.boost "speed") once there's a stable

profile.animals[key] = { level, fedAt, tendedAt }. Net "Animal" to the owner: { pens = { [key] = { level, fed,
fedLeft, happy, happyLeft, tendAt, cost, boost, word } }, at = the pen they're standing at (or nil) } whenever it changes.

  AnimalService:Pens(player)          { [key] = { pad, folder } } the pens on their plot
  AnimalService:Feed(player, key) -> ok, why ("full" | "none")
  AnimalService:Tend(player, key) -> ok, why ("soon" | "none")
  AnimalService:Upgrade(player, key) -> ok, why ("cash" | "none")
  AnimalService:FeedAll(player) -> how many   (the shop's Happy Farm feeds and tends them all)
  AnimalService:Push(player, at?)
  AnimalService.Changed (player, key, what)   "feed" | "tend" | "upgrade" | "new"
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Format = require(ReplicatedStorage.Shared.Format)
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
	grow = "crops grow %d%% faster",
	fruitGrow = "fruit grows %d%% faster",
	vegPrice = "vegetables sell for %d%% more",
	machine = "machines go %d%% faster",
	orders = "orders pay %d%% more",
	speed = "you walk %d%% faster",
}

local function boostText(key, st, t)
	local a = Animals[key]
	local k = (Animals.fed(st, t) and 1 or Animals.HUNGRY) * (Animals.happy(st, t) and Animals.HAPPY_MULT or 1)
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
				happy = Animals.happy(st, t),
				happyLeft = math.max(0, math.ceil(Animals.HAPPY_SECONDS - (t - (st.tendedAt or 0)))),
				tendAt = (st.tendedAt or 0) > 0 and st.tendedAt + Animals.TEND_GAP or 0, -- (server time it can be tended again)
				cost = Animals.upgradeCost(key, st.level),
				boost = boostText(key, st, t),
				word = Animals[key].word,
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
		-- (they arrive hungry: the first visit to the pad feeds them, free)
		p.animals[key] = { level = 1, fedAt = 0, tendedAt = 0 }
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
	if Animals.fed(st, now()) and now() - (st.fedAt or 0) < Animals.FED_SECONDS * 0.5 then
		return false, "full"
	end
	st.fedAt = now()
	p.stats.fed = (p.stats.fed or 0) + 1
	self.Changed:Fire(player, key, "feed")
	return true
end

-- TEND at the pen: a pat, and they're happy (the boost doubled) for a while
function AnimalService:Tend(player, key)
	local p = data:Get(player)
	local st = p and stateOf(p, key)
	if not st then
		return false, "none"
	end
	local t = now()
	if (st.tendedAt or 0) > 0 and t - st.tendedAt < Animals.TEND_GAP then
		return false, "soon"
	end
	st.tendedAt = t
	p.stats.tendedAnimals = (p.stats.tendedAnimals or 0) + 1
	economy:AddXP(player, 2 * st.level, "tend")
	self.Changed:Fire(player, key, "tend")
	farm:Push(player)
	return true
end

-- Every animal fed and happy (the shop's Happy Farm): how many
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
			st.tendedAt = now()
			n += 1
			self.Changed:Fire(player, key, "feed")
		end
	end
	self:Push(player)
	return n
end

function AnimalService:Upgrade(player, key)
	local p = data:Get(player)
	local st = p and stateOf(p, key)
	if not st then
		return false, "none"
	end
	if not economy:Spend(player, Animals.upgradeCost(key, st.level)) then
		return false, "cash"
	end
	st.level += 1
	economy:AddXP(player, 10 * st.level, "animal")
	herd(player, key)
	Net.fire(player, "Toast", `{string.upper(Animals[key].name)}S LEVEL {st.level}!`, "good")
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
	if p and hum and not (farm.Driving and farm.Driving(player)) then
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
			if ok then
				Net.fire(player, "Toast", `Fed your {string.lower(Animals[key].name)}s! Full boost`, "good")
			elseif why == "full" then
				Net.fire(player, "Toast", "They're full! Feed them again later", "info")
			end
			self:Push(player)
		elseif what == "tend" then
			local ok, why = self:Tend(player, key)
			if ok then
				Net.fire(
					player,
					"Toast",
					`Your {string.lower(Animals[key].name)}s are HAPPY: boost x2 for a minute!`,
					"good"
				)
			elseif why == "soon" then
				Net.fire(player, "Toast", "They're still happy! Pat them again in a bit", "info")
			end
			self:Push(player)
		elseif what == "upgrade" then
			local ok, why = self:Upgrade(player, key)
			if not ok and why == "cash" then
				local p = data:Get(player)
				local short = Animals.upgradeCost(key, stateOf(p, key).level) - math.floor(p.cash)
				Net.fire(player, "Toast", `Need {Format.cash(short)} more`, "info")
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
			local on = plots:Near(player, pen.pad, self.REACH)
			if on and standing[player] ~= key then
				standing[player] = key
				if st and not Animals.fed(st, t) and self:Feed(player, key) then
					Net.fire(player, "Toast", `Fed your {string.lower(a.name)}s!`, "good")
				end
				changed = true
			elseif not on and standing[player] == key then
				standing[player] = nil
				changed = true
			end
			-- (a happy spell ending repaints the panel)
			if st and st.tendedAt and st.tendedAt > 0 and t - st.tendedAt >= Animals.HAPPY_SECONDS then
				if not st.sadSaid then
					st.sadSaid = true
					changed = true
				end
			elseif st and st.sadSaid then
				st.sadSaid = nil
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

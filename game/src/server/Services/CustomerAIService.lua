-- Customer spawning, SPCV proxies, state machine, patience and anger (GDD §27.8.6, canon C11).
-- Each customer is an invisible anchored proxy part owned by the server; every client builds the visible body
-- for it locally (Client/Controllers/CustomerController). Movement follows fixed waypoints in the greybox layout.
--
-- States: ENTER → QUEUE/ORDER (at the counter) → TO_SEAT → WAIT_FOOD → EAT → LEAVE
--         with CHASE (anger level 5), DIZZY (Huff Points ran out) and storm-outs along the way.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Personalities = require(ReplicatedStorage.Shared.Data.Personalities)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

local CustomerAIService = {
	Name = "CustomerAIService",
	Dependencies = {
		"PlayerDataService",
		"ProgressionService",
		"RestaurantService",
		"OrderService",
		"CookingService",
		"CombatService",
		"RepairService",
	},
}

local progression, restaurantSvc, orders, cooking, combat, repair
local nextId = 0
local FLOORS = Constants.ANGER_LEVEL_FLOORS
local THROW_COLORS = { Color3.fromRGB(255, 75, 62), Color3.fromRGB(255, 197, 49), Color3.fromRGB(120, 200, 80) }
local CHASE_SPEED = { TANK = 8, CHARGER = 14 }
local ACTIVE = { QUEUE = true, ORDER = true, TO_SEAT = true, WAIT_FOOD = true, CHASE = true } -- states that can misbehave

local function now()
	return workspace:GetServerTimeNow()
end

local function popup(position, text, color)
	Net.fireAll("Popup", position + Vector3.new(0, 4, 0), text, color or Color3.fromRGB(255, 246, 224))
end

local function ownerHrp(r)
	local character = r.owner.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Setup ---------------------------------------------------------------------------------------------------
function CustomerAIService:_setState(c, s)
	c.state = s
	c.stateAt = now()
	c.proxy:SetAttribute("State", s)
	local p = c.prompt
	if s == "ORDER" then
		p.ActionText, p.Enabled = "Take order", true
	elseif s == "WAIT_FOOD" or s == "CHASE" or s == "TO_SEAT" then
		p.ActionText, p.Enabled = "Serve", true
	else
		p.Enabled = false
	end
end

function CustomerAIService:_setPath(c, points, speed)
	c.path = points
	c.pathIndex = 1
	c.speed = speed or Constants.WALK_SPEED_NPC
end

local function pickPersonality(r, rng)
	local pool, total = {}, 0
	for _, p in Personalities do
		if p.tier <= r.tierIndex then
			table.insert(pool, p)
			total += p.weight
		end
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	local roll = rng:NextNumber() * total
	for _, p in pool do
		roll -= p.weight
		if roll <= 0 then
			return p
		end
	end
	return pool[#pool]
end

function CustomerAIService:_freeSeat(r)
	for _, seat in r.layout.seats do
		if not r.ai.seatTaken[seat.index] and repair:IsUsable(seat.part) and repair:IsUsable(seat.tablePart) then
			return seat
		end
	end
	return nil
end

function CustomerAIService:_spawn(r)
	local seat = self:_freeSeat(r)
	if not seat or #r.ai.line >= 4 then
		return
	end
	nextId += 1
	local seed = math.random(1, 1073741823)
	local rng = Random.new(seed)
	local personality = pickPersonality(r, rng)

	local proxy = Instance.new("Part")
	proxy.Name = "Customer" .. nextId
	proxy.Size = Vector3.new(2, 5, 2)
	proxy.Transparency = 1
	proxy.Anchored = true
	proxy.CanCollide = false
	proxy.CanTouch = false
	proxy.CFrame = CFrame.new(r.layout.way.spawn)
	proxy:SetAttribute("CustomerId", nextId)
	proxy:SetAttribute("OwnerUserId", r.owner.UserId)
	proxy:SetAttribute("Personality", personality.id)
	proxy:SetAttribute("Seed", seed)
	proxy:SetAttribute("Anger", 0)
	proxy:SetAttribute("AngerLevel", 0)
	proxy:SetAttribute("Patience", 1)
	proxy:SetAttribute("Huff", personality.huff)
	proxy:SetAttribute("HuffMax", personality.huff)

	local pp = Instance.new("ProximityPrompt")
	pp.ObjectText = personality.name
	pp.MaxActivationDistance = Constants.CUSTOMER_RANGE
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = proxy

	local c = {
		id = nextId,
		r = r,
		personality = personality,
		rng = rng,
		proxy = proxy,
		prompt = pp,
		pos = r.layout.way.spawn,
		seat = seat,
		anger = 0,
		level = 0,
		passedRoll = {},
		huff = personality.huff,
		nextThrowAt = 0,
		nextHitAt = 0,
		nextSmashAt = 0,
		staggerUntil = 0,
		calmImmuneUntil = 0,
		lastPatience = 1,
	}
	r.ai.seatTaken[seat.index] = c
	r.ai.customers[c.id] = c
	r.customerCount = (r.customerCount or 0) + 1
	proxy.Parent = r.layout.model.Customers
	CollectionService:AddTag(proxy, "MMR_Customer")

	pp.Triggered:Connect(function(player)
		if player ~= r.owner then
			Net.fire(player, "Toast", "This customer is waiting for the owner.", "bad")
			return
		end
		if c.state == "ORDER" then
			self:_takeOrder(c, player)
		elseif c.state == "WAIT_FOOD" or c.state == "CHASE" or c.state == "TO_SEAT" then
			self:_serve(c, player)
		end
	end)

	table.insert(r.ai.line, c)
	self:_setState(c, "ENTER")
	self:_setPath(c, { r.layout.way.door, r.layout.way.aisle, self:_lineSpot(r, #r.ai.line) })
end

function CustomerAIService:_lineSpot(r, index)
	return index == 1 and r.layout.way.order or r.layout.way.queue[math.min(index - 1, #r.layout.way.queue)]
end

-- Re-path everyone in line after someone leaves it.
function CustomerAIService:_shuffleLine(r)
	for i, c in r.ai.line do
		local spot = self:_lineSpot(r, i)
		if c.state == "QUEUE" or c.state == "ORDER" then
			self:_setState(c, "ENTER")
		end
		if c.state == "ENTER" then
			local path = c.path and c.pathIndex <= #c.path and table.clone(c.path) or {}
			if #path > 0 then
				path[#path] = spot
			else
				path = { spot }
			end
			self:_setPath(c, path)
		end
	end
end

function CustomerAIService:_leaveLine(c)
	local line = c.r.ai.line
	local i = table.find(line, c)
	if i then
		table.remove(line, i)
		self:_shuffleLine(c.r)
	end
end

-- Interactions --------------------------------------------------------------------------------------------
function CustomerAIService:_takeOrder(c, player)
	local p = c.personality
	c.order = orders:Generate(player, p, c.rng)
	local sumD = 0
	for _, item in c.order.items do
		sumD += Recipes.byId[item.recipeId].difficulty
	end
	c.patience = Formulas.patience(#c.order.items, sumD, p.patience, progression:Stat(player, "CHARM"))
	c.orderTakenAt = now()
	c.proxy:SetAttribute("Order", orders:Describe(c.order))
	self:_leaveLine(c)
	self:_setState(c, "TO_SEAT")
	self:_setPath(c, { c.seat.approach.Position, c.seat.cf.Position })
end

function CustomerAIService:_serve(c, player)
	local dish = cooking:Top(player)
	if not dish or dish.kind ~= "DISH" then
		Net.fire(player, "Toast", "Bring them a finished dish from the Assembly Counter or Drink Dispenser.", "info")
		return
	end
	local index, accuracy = orders:Match(c.order, dish)
	if not index then
		self:_addAnger(c, Constants.ANGER_WRONG_DISH * c.personality.sens)
		popup(c.pos, "WRONG ORDER?!", Color3.fromRGB(255, 75, 62))
		return
	end
	cooking:Pop(player)
	local item = c.order.items[index]
	item.served = true
	item.accuracy = accuracy
	item.quality = dish.quality
	item.cook = dish.cook
	item.servedAt = now()
	c.proxy:SetAttribute("Order", orders:Describe(c.order))
	for _, it in c.order.items do
		if not it.served then
			popup(c.pos, "Yum! And the rest?", Color3.fromRGB(46, 196, 182))
			return
		end
	end
	-- fully served
	local summary = orders:Settle(player, c)
	c.proxy:SetAttribute("Mood", summary.mood)
	popup(c.pos, `+{summary.net} MB`, Color3.fromRGB(255, 197, 49))
	if c.level <= 2 and summary.satisfaction >= 90 then
		self:_setAnger(c, 0)
	end
	c.eatUntil = now() + Constants.EAT_SECONDS
	self:_setState(c, "EAT")
	self:_setPath(c, { c.seat.cf.Position })
end

-- Anger ---------------------------------------------------------------------------------------------------
function CustomerAIService:_setAnger(c, value)
	c.anger = math.clamp(value, 0, 100)
	c.level = math.min(Formulas.angerLevel(c.anger, FLOORS), 5)
	c.proxy:SetAttribute("Anger", math.floor(c.anger))
	c.proxy:SetAttribute("AngerLevel", c.level)
end

function CustomerAIService:_addAnger(c, amount)
	if c.state == "LEAVE" or c.state == "DIZZY" or c.state == "EAT" then
		return
	end
	local target = math.clamp(c.anger + amount, 0, 100)
	local newLevel = math.min(Formulas.angerLevel(target, FLOORS), 5) -- level 6 chaos is out of MVP scope
	for lvl = c.level + 1, newLevel do
		if lvl >= 3 and not c.passedRoll[lvl] then
			local chance = Formulas.escalationChance(c.personality.angerP, progression:Stat(c.r.owner, "CHARM"))
			if c.rng:NextNumber() < chance then
				c.passedRoll[lvl] = true
			elseif c.rng:NextNumber() < 0.5 then
				self:_stormOut(c)
				return
			else
				target = FLOORS[lvl + 1] - 1 -- sulks just below the next level
				break
			end
		end
	end
	local before = c.level
	self:_setAnger(c, target)
	if c.level > before then
		local text = ({ "Hmph.", "Excuse me?!", "FOOD FIGHT!", "SMASH!", "THAT'S IT!" })[c.level]
		popup(c.pos, text, Color3.fromRGB(255, 140, 30))
	end
end

function CustomerAIService:_stormOut(c)
	popup(c.pos, "I'M LEAVING!", Color3.fromRGB(255, 75, 62))
	orders:StormOut(c.r.owner)
	self:_leave(c)
end

function CustomerAIService:_leave(c)
	self:_leaveLine(c)
	self:_setState(c, "LEAVE")
	local w = c.r.layout.way
	local path = {}
	if c.seat and (c.pos - c.seat.cf.Position).Magnitude < 12 then
		table.insert(path, c.seat.approach.Position)
	end
	for _, p in { w.aisle, w.door, w.spawn } do
		table.insert(path, p)
	end
	self:_setPath(c, path)
end

function CustomerAIService:_remove(c)
	local r = c.r
	r.ai.customers[c.id] = nil
	if c.seat and r.ai.seatTaken[c.seat.index] == c then
		r.ai.seatTaken[c.seat.index] = nil
	end
	r.customerCount = math.max(0, (r.customerCount or 1) - 1)
	c.proxy:Destroy()
end

-- Combat hooks (called by CombatService) ---------------------------------------------------------------
function CustomerAIService:InRestaurant(r)
	local list = {}
	if r and r.ai then
		for _, c in r.ai.customers do
			if c.state ~= "LEAVE" and c.state ~= "DIZZY" then
				table.insert(list, c)
			end
		end
	end
	return list
end

function CustomerAIService:Hit(c, damage, _player, label)
	if c.state == "LEAVE" or c.state == "DIZZY" then
		return
	end
	c.huff = math.max(0, c.huff - damage)
	c.proxy:SetAttribute("Huff", math.ceil(c.huff))
	c.staggerUntil = math.max(c.staggerUntil, now() + 0.3)
	popup(c.pos, label and `{label} {math.ceil(damage)}` or tostring(math.ceil(damage)), Color3.fromRGB(255, 255, 255))
	if c.level < 3 then
		self:_addAnger(c, 30 * c.personality.sens) -- bopping a calm customer is rude
		if c.state == "LEAVE" then
			return
		end
	end
	if c.huff <= 0 then
		self:_setState(c, "DIZZY")
		c.dizzyUntil = now() + Constants.DIZZY_SECONDS
		popup(c.pos, "@_@ dizzy", Color3.fromRGB(161, 92, 255))
	end
end

function CustomerAIService:Stagger(c, seconds)
	c.staggerUntil = math.max(c.staggerUntil, now() + seconds)
end

function CustomerAIService:NearestAngry(r, position, range)
	local best, bestDist
	for _, c in self:InRestaurant(r) do
		local d = (c.pos - position).Magnitude
		if c.anger > 0 and d <= range and (not best or d < bestDist) then
			best, bestDist = c, d
		end
	end
	return best
end

function CustomerAIService:Calm(c, player, charm)
	if now() < c.calmImmuneUntil then
		Net.fire(player, "Toast", "They need a moment before you try that again.", "info")
		return
	end
	if c.level >= 5 and c.huff > c.personality.huff * 0.5 then
		Net.fire(player, "Toast", "Too worked up! Wear them down first.", "bad")
		return
	end
	local value = c.anger - Formulas.calmAmount(charm)
	if c.level <= 4 and c.level > 0 then
		value = math.min(value, FLOORS[c.level + 1] - 1) -- drops at least one level
	end
	self:_setAnger(c, value)
	c.calmImmuneUntil = now() + Constants.ABILITIES.ABL_006.immune
	popup(c.pos, "♥ calmer ♥", Color3.fromRGB(255, 150, 200))
end

function CustomerAIService:HitByFood(position, thrower)
	for _, r in restaurantSvc:All() do
		for _, c in self:InRestaurant(r) do
			if c ~= thrower and (c.pos - position).Magnitude <= Constants.THROWN_FOOD_HIT_RADIUS then
				popup(c.pos, "SPLAT!", Color3.fromRGB(255, 75, 62))
				self:_addAnger(c, Constants.ANGER_HIT_BY_FOOD * c.personality.sens)
			end
		end
	end
end

-- Tick ----------------------------------------------------------------------------------------------------
function CustomerAIService:_move(c, dt)
	if not c.path or c.pathIndex > #c.path then
		return true
	end
	local target = c.path[c.pathIndex]
	local offset = target - c.pos
	local dist = offset.Magnitude
	local stepLen = c.speed * dt
	if dist <= stepLen then
		c.pos = target
		c.pathIndex += 1
	else
		c.pos += offset.Unit * stepLen
	end
	if dist > 0.05 then
		c.proxy.CFrame = CFrame.lookAt(c.pos, c.pos + offset * Vector3.new(1, 0, 1))
	end
	return c.pathIndex > #c.path
end

function CustomerAIService:_patienceTick(c, dt)
	local t = now()
	local elapsed, limit
	if c.state == "QUEUE" or c.state == "ORDER" then
		elapsed = t - (c.waitStart or t)
		limit = Constants.ORDER_WAIT_SECONDS
			* c.personality.patience
			* Formulas.patienceMult(progression:Stat(c.r.owner, "CHARM"))
	elseif c.state == "TO_SEAT" or c.state == "WAIT_FOOD" or c.state == "CHASE" then
		elapsed = t - c.orderTakenAt
		limit = c.patience
	else
		return
	end
	local remaining = math.clamp(1 - elapsed / limit, 0, 1)
	if math.abs(remaining - c.lastPatience) >= 0.02 then
		c.lastPatience = remaining
		c.proxy:SetAttribute("Patience", remaining)
	end
	if remaining <= 0 then
		self:_addAnger(c, Constants.ANGER_RISE_PER_SECOND * dt)
	end
	-- nobody stays furious forever: a maxed-out customer who is ignored storms out
	if c.anger >= 100 then
		c.maxedAt = c.maxedAt or t
		if t - c.maxedAt >= Constants.RAGE_QUIT_SECONDS and c.state ~= "LEAVE" then
			self:_stormOut(c)
		end
	else
		c.maxedAt = nil
	end
end

function CustomerAIService:_behaviour(c, dt)
	local r = c.r
	local t = now()
	if c.level < 3 or not ACTIVE[c.state] or t < c.staggerUntil or combat:IsKO(r.owner) then
		return
	end
	local style = c.personality.style
	local hrp = ownerHrp(r)
	-- INSTIGATOR: yells, raising the anger of everyone nearby
	if style == "INSTIGATOR" then
		for _, other in self:InRestaurant(r) do
			if other ~= c and (other.pos - c.pos).Magnitude < 15 then
				self:_addAnger(other, 2 * dt)
			end
		end
	end
	-- level 5: fight the player (customers who already ordered); waiting-in-line customers storm out instead
	if c.level >= 5 and style ~= "INSTIGATOR" then
		if c.state == "WAIT_FOOD" or c.state == "TO_SEAT" then
			self:_setState(c, "CHASE")
		elseif c.state == "QUEUE" or c.state == "ORDER" then
			self:_stormOut(c)
			return
		end
	end
	if c.state == "CHASE" then
		if hrp then
			local goal = Vector3.new(hrp.Position.X, c.pos.Y, hrp.Position.Z)
			if (goal - c.pos).Magnitude > 3.5 then
				self:_setPath(c, { goal }, CHASE_SPEED[style] or Constants.CHASE_SPEED_NPC)
			else
				c.path = nil
				if t >= c.nextHitAt then
					c.nextHitAt = t + Constants.NPC_MELEE_INTERVAL
					popup(c.pos, "BONK!", Color3.fromRGB(255, 140, 30))
					combat:DamagePlayer(r.owner, Constants.NPC_MELEE_DAMAGE * c.personality.dmg, c)
				end
			end
		end
		return
	end
	-- level 4: smash the furniture at their seat
	if c.level >= 4 and c.state == "WAIT_FOOD" and t >= c.nextSmashAt then
		c.nextSmashAt = t + 3
		repair:Damage(c.seat.tablePart, Constants.SMASH_DAMAGE)
		popup(c.pos, "SMASH!", Color3.fromRGB(255, 140, 30))
	end
	-- level 3+: throw food at the owner
	if hrp and t >= c.nextThrowAt and (hrp.Position - c.pos).Magnitude < 45 then
		c.nextThrowAt = t + Constants.NPC_THROW_INTERVAL * (style == "TANK" and 1.5 or 1)
		combat:ThrowFood(
			c.pos + Vector3.new(0, 2, 0),
			r.owner,
			c.personality.dmg,
			THROW_COLORS[c.rng:NextInteger(1, #THROW_COLORS)],
			c
		)
	end
end

function CustomerAIService:_tickCustomer(c, dt)
	local t = now()
	local s = c.state
	if s == "DIZZY" then
		if t >= c.dizzyUntil then
			local pay = orders:Apology(c.r.owner, c)
			popup(c.pos, `Sorry... +{pay} MB`, Color3.fromRGB(255, 197, 49))
			self:_setAnger(c, 0)
			self:_leave(c)
		end
		return
	end
	local arrived = t >= c.staggerUntil and self:_move(c, dt)
	if s == "ENTER" and arrived then
		c.waitStart = c.waitStart or t
		local first = c.r.ai.line[1] == c
		self:_setState(c, first and "ORDER" or "QUEUE")
		c.proxy.CFrame = CFrame.lookAt(c.pos, c.pos - c.r.layout.root.LookVector)
	elseif s == "TO_SEAT" and arrived then
		self:_setState(c, "WAIT_FOOD")
		c.proxy.CFrame = c.seat.cf
	elseif s == "CHASE" and c.level < 5 then
		self:_setState(c, "TO_SEAT") -- calmed down: back to the seat
		self:_setPath(c, { c.seat.approach.Position, c.seat.cf.Position })
	elseif s == "EAT" and t >= c.eatUntil then
		self:_leave(c)
	elseif s == "LEAVE" and arrived then
		self:_remove(c)
		return
	end
	self:_patienceTick(c, dt)
	self:_behaviour(c, dt)
end

function CustomerAIService:_tickRestaurant(r, dt)
	local ai = r.ai
	local t = now()
	if t >= ai.nextSpawnAt then
		local demand =
			Formulas.demandPerHour(r.tier.demand, restaurantSvc:Stars(r.owner), restaurantSvc:Atmosphere(r.owner))
		ai.nextSpawnAt = t + 3600 / (demand * Constants.DEMAND_SCALE) * (0.75 + math.random() * 0.5)
		if r.owner.Character and not combat:IsKO(r.owner) then
			self:_spawn(r)
		end
	end
	for _, c in ai.customers do
		self:_tickCustomer(c, dt)
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------------
function CustomerAIService:Init(registry)
	progression = registry.ProgressionService
	restaurantSvc = registry.RestaurantService
	orders = registry.OrderService
	cooking = registry.CookingService
	combat = registry.CombatService
	repair = registry.RepairService
	combat:SetCustomerProvider(self)

	restaurantSvc.Built:Connect(function(_, r)
		local folder = Instance.new("Folder")
		folder.Name = "Customers"
		folder.Parent = r.layout.model
		r.ai = { customers = {}, line = {}, seatTaken = {}, nextSpawnAt = now() + Constants.FIRST_CUSTOMER_DELAY }
		r.customerCount = 0
	end)
	restaurantSvc.Removing:Connect(function(_, r)
		if r.ai then
			for _, c in r.ai.customers do
				c.proxy:Destroy()
			end
			r.ai = nil
		end
		r.customerCount = 0
	end)
	combat.KnockedOut:Connect(function(player, source)
		local r = restaurantSvc:Get(player)
		for _, c in self:InRestaurant(r) do
			if c == source or c.state == "CHASE" then
				popup(c.pos, "♪ victory dance ♪", Color3.fromRGB(161, 92, 255))
				orders:StormOut(player) -- leaves without paying
				self:_leave(c)
			end
		end
	end)
end

function CustomerAIService:Start()
	local last = os.clock()
	while true do
		task.wait(Constants.NPC_TICK)
		local t = os.clock()
		local dt = math.min(t - last, 0.25)
		last = t
		for _, r in restaurantSvc:All() do
			if r.ai then
				local ok, err = xpcall(self._tickRestaurant, debug.traceback, self, r, dt)
				if not ok then
					warn(`[CustomerAIService] tick failed: {err}`)
				end
			end
		end
	end
end

return CustomerAIService

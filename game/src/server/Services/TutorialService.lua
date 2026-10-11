-- First-session tutorial: one patient customer orders a Basic Burger and the player is walked through every step,
-- with the next thing to use highlighted (GDD §32, QST_TUT_001-012 condensed). Normal customers start arriving
-- once the burger is served. Progress is checked from game state, so doing steps out of order never gets stuck.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"RestaurantService",
		"CookingService",
		"CustomerAIService",
		"MutationService",
	},
}

local data, economy, restaurantSvc, cooking, customers
local active = {} -- [player] = { step, customer, doneAt }

-- the tutorial order: one plain Basic Burger
local function newOrder()
	return { items = { { recipeId = "RCP_BRG_001", omit = {}, served = false } } }
end

-- helpers over CookingService:Snapshot()
local function holding(snap, id, state)
	for _, item in snap.carry do
		if item.kind == "ING" and item.id == id and (not state or item.state == state) then
			return true
		end
	end
	return false
end
local function holdingDish(snap)
	for _, item in snap.carry do
		if item.kind == "DISH" and item.recipeId == "RCP_BRG_001" then
			return true
		end
	end
	return false
end
local function onBoard(snap, key)
	for _, contents in snap.boards do
		if contents[key] then
			return true
		end
	end
	return false
end
local function cookingNow(snap, id)
	for _, h in snap.heat do
		if h.id == id then
			return true
		end
	end
	return false
end
local function served(t)
	return t.customer and t.customer.order and t.customer.order.items[1].served
end

local function stations(r)
	return r.layout.stations
end

-- For "get X, prep it, add it" steps: point at whichever station comes next for that ingredient.
local function ingredientTarget(snap, r, id, prep)
	if holding(snap, id, prep) or (not prep and holding(snap, id)) then
		return stations(r).STN_ASSEMBLY:FindFirstChild("Board1")
	elseif prep == "CHOPPED" and holding(snap, id, "RAW") then
		return stations(r).STN_CUT
	end
	return stations(r).STN_PANTRY
end

local STEPS = {
	{
		text = "Welcome, chef! Pick your first mutation. It's free.",
		done = function(_, profile)
			return profile.mutations.equipped ~= nil
		end,
	},
	{
		text = "Your first customer is at the counter. Walk over and press E to take their order.",
		target = function(_, _, t)
			return t.customer and t.customer.proxy
		end,
		done = function(_, _, t)
			return t.customer and t.customer.order ~= nil
		end,
	},
	{
		text = "They want a Basic Burger. Go to the Pantry (back wall) and take a Beefy Puck Patty.",
		target = function(_, r)
			return stations(r).STN_PANTRY
		end,
		done = function(snap)
			return holding(snap, "ING_BEEF_PATTY")
				or cookingNow(snap, "ING_BEEF_PATTY")
				or onBoard(snap, "ING_BEEF_PATTY|GRILLED")
		end,
	},
	{
		text = "Put the patty on the Grill: stand at the Grill and press E.",
		target = function(_, r)
			return stations(r).STN_GRILL
		end,
		done = function(snap)
			return cookingNow(snap, "ING_BEEF_PATTY")
				or holding(snap, "ING_BEEF_PATTY", "GRILLED")
				or onBoard(snap, "ING_BEEF_PATTY|GRILLED")
		end,
	},
	{
		text = "Watch the bar over the patty. When it says PERFECT (green), press E to take it off.",
		target = function(_, r)
			return stations(r).STN_GRILL
		end,
		done = function(snap)
			return holding(snap, "ING_BEEF_PATTY", "GRILLED") or onBoard(snap, "ING_BEEF_PATTY|GRILLED")
		end,
	},
	{
		text = "Put the patty on Board 1 of the Assembly Counter (the island in the middle).",
		target = function(_, r)
			return stations(r).STN_ASSEMBLY:FindFirstChild("Board1")
		end,
		done = function(snap)
			return onBoard(snap, "ING_BEEF_PATTY|GRILLED")
		end,
	},
	{
		text = "Now a bun: take a Squishy Sesame Bun from the Pantry and add it to the board.",
		target = function(snap, r)
			return ingredientTarget(snap, r, "ING_BUN", nil)
		end,
		done = function(snap)
			return onBoard(snap, "ING_BUN|RAW")
		end,
	},
	{
		text = "Take a Pickle Spear, chop it at the Cutting Board (tap in the green), then add it to the board.",
		target = function(snap, r)
			return ingredientTarget(snap, r, "ING_PICKLE", "CHOPPED")
		end,
		done = function(snap)
			return onBoard(snap, "ING_PICKLE|CHOPPED")
		end,
	},
	{
		text = "Same with Lettuce: Pantry, then Cutting Board, then the board.",
		target = function(snap, r)
			return ingredientTarget(snap, r, "ING_LETTUCE", "CHOPPED")
		end,
		done = function(snap)
			return onBoard(snap, "ING_LETTUCE|CHOPPED")
		end,
	},
	{
		text = "Last one: Ketchup from the Pantry, straight onto the board.",
		target = function(snap, r)
			return ingredientTarget(snap, r, "ING_KETCHUP", nil)
		end,
		done = function(snap)
			return onBoard(snap, "ING_KETCHUP|RAW")
		end,
	},
	{
		text = 'The board now says "Plate Basic Burger". Press E on it to pick up the finished burger.',
		target = function(_, r)
			return stations(r).STN_ASSEMBLY:FindFirstChild("Board1")
		end,
		done = function(snap, _, t)
			return holdingDish(snap) or served(t)
		end,
	},
	{
		text = "Take the burger to your customer (they're sitting in the dining room) and press E to serve it.",
		target = function(_, _, t)
			return t.customer and t.customer.proxy
		end,
		done = function(_, _, t)
			return served(t)
		end,
	},
	{
		text = "You're open for business! Orders show on the tickets at the top, and the recipe card says what each one needs.",
		done = function(_, _, t)
			return os.clock() - (t.stepAt or 0) > 10
		end,
	},
}

function TutorialService:_send(player, t)
	local step = STEPS[t.step]
	local r = restaurantSvc:Get(player)
	if not step or not r then
		Net.fire(player, "Tutorial", false)
		return
	end
	local snap = cooking:Snapshot(player)
	local target = step.target and step.target(snap, r, t) or nil
	if t.sentStep ~= t.step or t.sentTarget ~= target then
		t.sentStep, t.sentTarget = t.step, target
		Net.fire(player, "Tutorial", { step = t.step, total = #STEPS, text = step.text, target = target })
	end
end

function TutorialService:_finish(player, skipped)
	local profile = data:Get(player)
	local t = active[player]
	active[player] = nil
	if profile then
		profile.tutorialDone = true
	end
	local r = restaurantSvc:Get(player)
	if r then
		r.tutorialActive = false
	end
	if t and t.customer and t.customer.order == nil and t.customer.state ~= "LEAVE" then
		customers:_leave(t.customer) -- a skipped tutorial lets its customer go home
	end
	Net.fire(player, "Tutorial", false)
	if not skipped then
		economy:Grant(player, "MB", 25, "tutorial")
		Net.fire(player, "Toast", "Tutorial complete! +25 MB to get you started.", "good")
	end
end

function TutorialService:_tick(player, t)
	local profile = data:Get(player)
	local r = restaurantSvc:Get(player)
	if not profile or not r then
		return
	end
	-- the scripted customer arrives once the mutation is picked
	if t.step >= 2 and (not t.customer or not t.customer.proxy.Parent) and not served(t) then
		if r.ai then
			t.customer = customers:SpawnScripted(r, { personality = "PER_013", order = newOrder() })
		end
	end
	local snap = cooking:Snapshot(player)
	while STEPS[t.step] and STEPS[t.step].done(snap, profile, t) do
		t.step += 1
		t.stepAt = os.clock()
	end
	if not STEPS[t.step] then
		self:_finish(player, false)
		return
	end
	self:_send(player, t)
end

function TutorialService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	restaurantSvc = registry.RestaurantService
	cooking = registry.CookingService
	customers = registry.CustomerAIService

	Net.on("SkipTutorial", function(player)
		if active[player] then
			self:_finish(player, true)
		end
	end)
	data.ClientReady:Connect(function(player)
		local t = active[player]
		if t then
			t.sentStep = nil
			self:_send(player, t)
		end
	end)
	restaurantSvc.Built:Connect(function(player, r)
		if active[player] then
			r.tutorialActive = true
		end
	end)
end

function TutorialService:OnPlayerReady(player, profile)
	if profile.tutorialDone or profile.lifetime.served > 0 then
		profile.tutorialDone = true
		return
	end
	active[player] = { step = 1, stepAt = os.clock() }
	local r = restaurantSvc:Get(player)
	if r then
		r.tutorialActive = true
	end
end

function TutorialService:OnPlayerLeaving(player)
	active[player] = nil
end

function TutorialService:Start()
	while true do
		task.wait(0.25)
		for player, t in active do
			local ok, err = pcall(self._tick, self, player, t)
			if not ok then
				warn(`[TutorialService] {err}`)
			end
		end
	end
end

return TutorialService

-- Station state machines, timers, quality scoring and carrying (GDD §27.8.5, canon C7/C8).
-- Stations in the MVP: Pantry, Cutting Board, Grill (2 slots), Fryer (1 basket), Drink Dispenser,
-- Assembly Counter (2 boards, doubles as plating at TIER_01-02) and Trash.
-- All outcomes are decided here on the server; clients only draw prompts, rings and progress bars.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Ingredients = require(ReplicatedStorage.Shared.Data.Ingredients)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

local CookingService = {
	Name = "CookingService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"ProgressionService",
		"MutationService",
		"RestaurantService",
	},
}

local data, economy, progression, mutations, restaurantSvc
local carry = {} -- [player] = { item, ... } (last = top)
local pending = {} -- [player] = { mode = "pantry" | "drink", options = {...}, r = restaurant }
local chopping = {} -- [player] = { r, startAt, period, taps, scores, lastTap }
local pouring = {} -- [player] = { r, startAt, seconds, recipeId }
local wasteDebt = {} -- [player] = fractional MB owed for thrown-away food

local HEAT = { STN_GRILL = "grill", STN_FRYER = "fry" }
local HEAT_STATE = { STN_GRILL = "GRILLED", STN_FRYER = "FRIED" }

local function now()
	return workspace:GetServerTimeNow()
end

local function toast(player, text, kind)
	Net.fire(player, "Toast", text, kind or "info")
end

local function itemName(item)
	if item.kind == "DISH" then
		return item.label
	end
	return Ingredients[item.id].name
end

local function itemColor(item)
	if item.kind == "DISH" then
		return item.color
	end
	local c = Ingredients[item.id].color
	if item.grade == "BURNED" then
		return c:Lerp(Color3.new(0.1, 0.08, 0.06), 0.7)
	elseif item.grade == "RUINED" then
		return Color3.fromRGB(30, 26, 24)
	elseif item.state == "GRILLED" or item.state == "FRIED" then
		return c:Lerp(Color3.fromRGB(150, 90, 40), 0.45)
	end
	return c
end

local function itemDetail(item)
	if item.kind == "DISH" then
		return item.drink and item.grade or `Quality {math.floor(item.quality * 100)} %`
	end
	if item.grade and item.grade ~= "PERFECT" then
		return `{item.state} · {item.grade}`
	end
	return item.grade == "PERFECT" and `{item.state} · PERFECT` or item.state
end

-- One-line "what next" hint for the HUD, based on the top carried item.
local function nextStep(item)
	if not item then
		return "Grab ingredients from the Pantry, or take an order at the counter."
	elseif item.kind == "DISH" then
		return `Serve the {item.label} to the customer who ordered it.`
	elseif item.grade == "RUINED" then
		return "That's charcoal. Throw it in the Trash."
	end
	local row = Ingredients[item.id]
	if item.state == "RAW" and row.chop then
		return "Chop it at the Cutting Board (or stack it raw if a recipe wants it raw)."
	elseif item.state == "RAW" and row.grill then
		return "Cook it on the Grill."
	elseif item.state == "RAW" and row.fry then
		return "Fry it in the Fryer."
	end
	return "Stack it on an Assembly Counter board."
end

local function capacity(player)
	return math.min(Constants.CARRY_BASE + mutations:CarryBonus(player), Constants.CARRY_MAX)
end

-- Carry -------------------------------------------------------------------------------------------------------
function CookingService:_syncCarry(player)
	local list = carry[player] or {}
	local views = {}
	for _, item in list do
		table.insert(
			views,
			{ name = itemName(item), detail = itemDetail(item), color = itemColor(item), kind = item.kind }
		)
	end
	Net.fire(player, "Carry", views, capacity(player), nextStep(list[#list]))

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	local old = character:FindFirstChild("Carried")
	if old then
		old:Destroy()
	end
	if #list == 0 then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "Carried"
	local function piece(size, cf, color, shape)
		local p = Instance.new("Part")
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Shape = shape
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = cf
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = p
		w.Parent = p
		p.Parent = folder
	end
	for i, item in list do
		local cf = hrp.CFrame * CFrame.new(0, 0.2 + (i - 1) * 1.0, -1.6)
		local flat = CFrame.Angles(0, 0, math.rad(90)) -- Roblox cylinders run along X; turn them into discs
		if item.kind == "DISH" then
			piece(Vector3.new(0.15, 2.2, 2.2), cf * flat, Color3.fromRGB(250, 250, 250), Enum.PartType.Cylinder) -- plate
			piece(Vector3.new(1.3, 1.3, 1.3), cf * CFrame.new(0, 0.55, 0), itemColor(item), Enum.PartType.Ball)
		else
			piece(Vector3.new(0.45, 1.3, 1.3), cf * flat, itemColor(item), Enum.PartType.Cylinder)
		end
	end
	folder.Parent = character
end

function CookingService:Top(player)
	local list = carry[player]
	return list and list[#list] or nil
end

function CookingService:Pop(player)
	local list = carry[player]
	local item = list and table.remove(list)
	self:_syncCarry(player)
	return item
end

function CookingService:Give(player, item)
	local list = carry[player]
	if not list or #list >= capacity(player) then
		return false
	end
	table.insert(list, item)
	self:_syncCarry(player)
	return true
end

function CookingService:HandsFree(player)
	local list = carry[player]
	return list ~= nil and #list < capacity(player)
end

-- Helpers -----------------------------------------------------------------------------------------------------
local function near(player, part, extra)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil
		and (hrp.Position - part.Position).Magnitude
			<= Constants.STATION_RANGE + (extra or 2) + part.Size.Magnitude / 2
end

local function prompt(parent, action, object, key, hold)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.KeyboardKeyCode = key or Enum.KeyCode.E
	pp.GamepadKeyCode = key == Enum.KeyCode.F and Enum.KeyCode.ButtonY or Enum.KeyCode.ButtonX
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = Constants.STATION_RANGE
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
end

local function ownerOnly(r, player)
	if player ~= r.owner then
		toast(player, "This isn't your kitchen!", "bad")
		return false
	end
	return true
end

-- Food on a station: a round disc (patties, buns and toppings all read as burger layers).
local function itemVisual(parent, item, cf, size)
	size = size or Vector3.new(1.4, 0.4, 1.4)
	local p = Instance.new("Part")
	p.Name = "Item"
	p.Anchored = true
	p.CanCollide = false
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(size.Y, math.min(size.X, size.Z), math.min(size.X, size.Z))
	p.Color = itemColor(item)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = parent
	return p
end

local function wasteCost(item)
	if item.kind == "DISH" then
		if item.drink then
			return Recipes.byId[item.recipeId].cost
		end
		local total = 0
		for key, count in item.contents do
			local id = string.split(key, "|")[1]
			total += Ingredients[id].cost * count
		end
		return total
	end
	return Ingredients[item.id].cost
end

function CookingService:_chargeWaste(player, item)
	wasteDebt[player] = (wasteDebt[player] or 0)
		+ wasteCost(item) * Formulas.ingredientCostMult(progression:Stat(player, "EFFICIENCY"))
	local whole = math.floor(wasteDebt[player])
	if whole >= 1 then
		local charged = economy:ChargeUpTo(player, "MB", whole, "waste")
		wasteDebt[player] -= whole
		if charged > 0 then
			toast(player, `Wasted food cost {charged} MB.`, "bad")
		end
	end
end

-- Stations ----------------------------------------------------------------------------------------------------
function CookingService:_wire(r)
	local st = r.layout.stations
	local c = {
		cut = { item = nil },
		heat = {
			STN_GRILL = { slots = { {}, {} }, fire = false },
			STN_FRYER = { slots = { {} }, fire = false },
		},
		boards = {
			{ contents = {}, scores = {}, cook = {}, visuals = {} },
			{ contents = {}, scores = {}, cook = {}, visuals = {} },
		},
	}
	r.cooking = c

	-- Pantry
	prompt(st.STN_PANTRY.PrimaryPart, "Take", "Pantry").Triggered:Connect(function(player)
		if not ownerOnly(r, player) then
			return
		end
		if not self:HandsFree(player) then
			toast(player, "Your hands are full.", "bad")
			return
		end
		local options, seen = {}, {}
		for _, recipe in restaurantSvc:MenuRecipes(player) do
			for _, part in recipe.parts do
				if not seen[part[1]] then
					seen[part[1]] = true
					table.insert(options, part[1])
				end
			end
		end
		pending[player] = { mode = "pantry", options = options, r = r, part = st.STN_PANTRY.PrimaryPart }
		Net.fire(player, "PantryOpen", { mode = "pantry", options = options })
	end)

	-- Cutting board
	local cutBase = st.STN_CUT.PrimaryPart
	local cutPrompt = prompt(cutBase, "Chop", "Cutting Board")
	c.cut.prompt = cutPrompt
	cutPrompt.Triggered:Connect(function(player)
		if not ownerOnly(r, player) then
			return
		end
		self:_useCutBoard(player, r)
	end)

	-- Grill and fryer
	for stationId in HEAT do
		local base = st[stationId].PrimaryPart
		local heat = c.heat[stationId]
		heat.top = st[stationId]:FindFirstChild("Top")
		heat.prompt = prompt(base, "Use", stationId == "STN_GRILL" and "Grill" or "Fryer")
		heat.prompt.Triggered:Connect(function(player)
			if not ownerOnly(r, player) then
				return
			end
			self:_useHeat(player, r, stationId)
		end)
	end

	-- Drink dispenser
	prompt(st.STN_DRINK.PrimaryPart, "Pour", "Drink Dispenser").Triggered:Connect(function(player)
		if not ownerOnly(r, player) then
			return
		end
		if not self:HandsFree(player) then
			toast(player, "Your hands are full.", "bad")
			return
		end
		local drinks = {}
		for _, recipe in restaurantSvc:MenuRecipes(player) do
			if recipe.drink then
				table.insert(drinks, recipe.id)
			end
		end
		if #drinks == 0 then
			toast(player, "No drinks on your menu.", "bad")
		elseif #drinks == 1 then
			self:_startPour(player, r, drinks[1])
		else
			pending[player] = { mode = "drink", options = drinks, r = r, part = st.STN_DRINK.PrimaryPart }
			Net.fire(player, "PantryOpen", { mode = "drink", options = drinks })
		end
	end)

	-- Assembly boards
	for i = 1, 2 do
		local boardPart = st.STN_ASSEMBLY:FindFirstChild("Board" .. i)
		c.boards[i].part = boardPart
		local use = prompt(boardPart, "Add", `Board {i}`)
		c.boards[i].prompt = use
		use.Triggered:Connect(function(player)
			if not ownerOnly(r, player) then
				return
			end
			self:_useBoard(player, r, i)
		end)
		local clear = prompt(boardPart, "Clear board", `Board {i}`, Enum.KeyCode.F, 0.8)
		clear.Enabled = false
		c.boards[i].clearPrompt = clear
		clear.Triggered:Connect(function(player)
			if not ownerOnly(r, player) then
				return
			end
			self:_clearBoard(player, r, i, true)
		end)
	end

	-- Trash
	prompt(st.STN_TRASH.PrimaryPart, "Throw away", "Trash").Triggered:Connect(function(player)
		if not ownerOnly(r, player) then
			return
		end
		local item = self:Pop(player)
		if item then
			self:_chargeWaste(player, item)
		end
	end)
end

function CookingService:_useCutBoard(player, r)
	local cut = r.cooking.cut
	if chopping[player] then
		return
	end
	if cut.item and cut.item.state == "CHOPPED" then
		-- a finished piece was left on the board earlier
		if self:Give(player, cut.item) then
			cut.item = nil
			cut.visual:Destroy()
			cut.visual = nil
		else
			toast(player, "Your hands are full.", "bad")
		end
		return
	end
	if not cut.item then
		local top = self:Top(player)
		if not top or top.kind ~= "ING" then
			toast(player, "Bring a vegetable or ham to chop.", "info")
			return
		end
		if not Ingredients[top.id].chop or top.state ~= "RAW" then
			toast(player, `{Ingredients[top.id].name} doesn't need chopping.`, "bad")
			return
		end
		cut.item = self:Pop(player)
		cut.scores = {}
		cut.visual = itemVisual(
			r.layout.model,
			cut.item,
			r.layout.stations.STN_CUT.Top.Slot1.WorldCFrame * CFrame.new(0, 0.3, 0)
		)
	end
	-- start or resume the chopping rhythm
	local period = Constants.CHOP_RING_PERIOD * Formulas.cookTimeMult(progression:Stat(player, "COOK_SPD"))
	local session = { r = r, startAt = now(), period = period, lastTap = 0 }
	chopping[player] = session
	Net.fire(player, "ChopStart", {
		startAt = session.startAt,
		period = period,
		taps = Constants.CHOP_TAPS,
		done = #cut.scores,
		ingredient = Ingredients[cut.item.id].name,
	})
end

function CookingService:_chopTap(player)
	local session = chopping[player]
	if not session then
		return
	end
	local r = session.r
	local cut = r.cooking.cut
	local t = now()
	if not cut.item or not near(player, r.layout.stations.STN_CUT.PrimaryPart) then
		chopping[player] = nil
		Net.fire(player, "ChopEnd")
		return
	end
	if t - session.lastTap < Constants.CHOP_MIN_TAP_GAP then
		return
	end
	session.lastTap = t
	local phase = ((t - session.startAt) % session.period) / session.period
	local score = Formulas.chopTapScore(phase)
	table.insert(cut.scores, score)
	Net.fire(player, "ChopProgress", #cut.scores, score)
	if #cut.scores >= Constants.CHOP_TAPS then
		local item = cut.item
		item.state = "CHOPPED"
		item.score = Formulas.mean(cut.scores)
		item.grade = item.score >= 0.95 and "PERFECT" or (item.score >= 0.75 and "GOOD" or "OK")
		cut.item = nil
		if cut.visual then
			cut.visual:Destroy()
			cut.visual = nil
		end
		chopping[player] = nil
		Net.fire(player, "ChopEnd")
		if not self:Give(player, item) then
			-- hands filled up meanwhile: leave the chopped piece on the board
			cut.item = item
			cut.scores = table.create(Constants.CHOP_TAPS, item.score)
			cut.visual = itemVisual(
				r.layout.model,
				item,
				r.layout.stations.STN_CUT.Top.Slot1.WorldCFrame * CFrame.new(0, 0.3, 0)
			)
		end
	end
end

function CookingService:_useHeat(player, r, stationId)
	local heat = r.cooking.heat[stationId]
	if heat.fire then
		heat.fire = false
		for _, s in heat.slots do
			if s.visual then
				s.visual:Destroy()
			end
			table.clear(s)
		end
		self:_setFire(r, stationId, false)
		self:_refreshHeatPrompt(r, stationId)
		toast(player, "Fire's out. Phew!", "good")
		return
	end
	local top = self:Top(player)
	local kind = HEAT[stationId]
	if
		top
		and top.kind == "ING"
		and Ingredients[top.id][kind]
		and top.state ~= HEAT_STATE[stationId]
		and top.grade ~= "RUINED"
	then
		for i, s in heat.slots do
			if not s.item then
				local item = self:Pop(player)
				local cookQlt = progression:Stat(player, "COOK_QLT")
				s.item = item
				s.startAt = now()
				s.tReady = Ingredients[item.id][kind] * Formulas.cookTimeMult(progression:Stat(player, "COOK_SPD"))
				s.window = Constants.PERFECT_WINDOW * Formulas.perfectWindowMult(cookQlt)
				s.burnAfter = Constants.BURN_AFTER_READY * Formulas.burnDelayMult(cookQlt)
				local slotAtt = heat.top:FindFirstChild("Slot" .. i)
				s.visual = itemVisual(
					r.layout.model,
					item,
					slotAtt.WorldCFrame * CFrame.new(0, 0.25, 0),
					Vector3.new(1.6, 0.4, 1.6)
				)
				s.visual:SetAttribute("StartAt", s.startAt)
				s.visual:SetAttribute("TReady", s.tReady)
				s.visual:SetAttribute("Window", s.window)
				s.visual:SetAttribute("BurnAfter", s.burnAfter)
				s.visual:SetAttribute("FireAfter", Constants.FIRE_AFTER_BURN)
				CollectionService:AddTag(s.visual, "MMR_Cooking")
				self:_refreshHeatPrompt(r, stationId)
				return
			end
		end
		toast(player, "No free space here.", "bad")
		return
	end
	-- take the most-cooked item out
	local best, bestElapsed
	for _, s in heat.slots do
		if s.item and (not best or now() - s.startAt > bestElapsed) then
			best, bestElapsed = s, now() - s.startAt
		end
	end
	if not best then
		if top then
			toast(player, `That can't go on the {stationId == "STN_GRILL" and "grill" or "fryer"}.`, "bad")
		else
			toast(
				player,
				stationId == "STN_GRILL" and "Grill a patty, hot dog or bread slice." or "Fry a potato or an onion.",
				"info"
			)
		end
		return
	end
	if not self:HandsFree(player) then
		toast(player, "Your hands are full.", "bad")
		return
	end
	local grade, score =
		Formulas.heatGrade(bestElapsed, best.tReady, best.window, best.burnAfter, Constants.FIRE_AFTER_BURN)
	local item = best.item
	item.state = HEAT_STATE[stationId]
	item.grade = grade
	item.score = score
	item.heat = true
	best.visual:Destroy()
	table.clear(best)
	self:Give(player, item)
	self:_refreshHeatPrompt(r, stationId)
end

function CookingService:_refreshHeatPrompt(r, stationId)
	local heat = r.cooking.heat[stationId]
	if heat.fire then
		heat.prompt.ActionText = "Put out fire"
		heat.prompt.HoldDuration = Constants.EXTINGUISH_HOLD
	else
		local any = false
		for _, s in heat.slots do
			any = any or s.item ~= nil
		end
		heat.prompt.ActionText = any and "Use / Take" or "Use"
		heat.prompt.HoldDuration = 0
	end
end

function CookingService:_heatTick(r)
	for stationId, heat in r.cooking.heat do
		if not heat.fire then
			for _, s in heat.slots do
				if s.item then
					local elapsed = now() - s.startAt
					local grade, _, fire =
						Formulas.heatGrade(elapsed, s.tReady, s.window, s.burnAfter, Constants.FIRE_AFTER_BURN)
					if fire then
						heat.fire = true
						Net.fire(
							r.owner,
							"Toast",
							`{stationId == "STN_GRILL" and "GRILL" or "FRYER"} ON FIRE! Hold the prompt to put it out.`,
							"bad"
						)
						self:_setFire(r, stationId, true)
						self:_refreshHeatPrompt(r, stationId)
						break
					end
					local shown = { state = HEAT_STATE[stationId], grade = grade, id = s.item.id, kind = "ING" }
					s.visual.Color = itemColor(shown)
				end
			end
		end
	end
end

function CookingService:_setFire(r, stationId, on)
	local base = r.layout.stations[stationId].PrimaryPart
	local fire = base:FindFirstChild("Fire")
	if on and not fire then
		fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 12
		fire.Parent = base
	elseif not on and fire then
		fire:Destroy()
	end
end

function CookingService:_startPour(player, r, recipeId)
	local seconds = Constants.POUR_SECONDS * Formulas.cookTimeMult(progression:Stat(player, "COOK_SPD"))
	pouring[player] = { r = r, startAt = now(), seconds = seconds, recipeId = recipeId }
	Net.fire(player, "PourStart", {
		startAt = pouring[player].startAt,
		seconds = seconds,
		recipe = Recipes.byId[recipeId].name,
		maxFill = Constants.POUR_MAX_FILL,
	})
end

function CookingService:_stopPour(player)
	local p = pouring[player]
	if not p then
		return
	end
	pouring[player] = nil
	Net.fire(player, "PourEnd")
	local fill = math.min((now() - p.startAt) / p.seconds, Constants.POUR_MAX_FILL)
	local grade, score = Formulas.pourGrade(fill)
	local recipe = Recipes.byId[p.recipeId]
	local dish = {
		kind = "DISH",
		drink = true,
		recipeId = recipe.id,
		label = recipe.name,
		contents = {},
		omitted = {},
		quality = score,
		cook = 1,
		grade = grade,
		color = recipe.color,
	}
	if not self:Give(player, dish) then
		toast(player, "Your hands are full.", "bad")
		return
	end
	toast(player, `{recipe.name}: {grade}`, score >= 0.8 and "good" or "bad")
end

local function boardKey(item)
	return item.id .. "|" .. item.state
end

function CookingService:_drawBoard(r, i)
	local b = r.cooking.boards[i]
	for _, v in b.visuals do
		v:Destroy()
	end
	table.clear(b.visuals)
	local base = b.part.Stack.WorldCFrame
	local h = 0
	for _, entry in b.order or {} do
		local v = itemVisual(r.layout.model, entry, base * CFrame.new(0, 0.15 + h, 0), Vector3.new(2.4, 0.3, 2.4))
		table.insert(b.visuals, v)
		h += 0.32
	end
	local any = next(b.contents) ~= nil
	b.part:SetAttribute("Contents", HttpService:JSONEncode(b.contents)) -- read by the client's recipe card
	b.clearPrompt.Enabled = any
	if any then
		local match = Formulas.bestMatch(restaurantSvc:MenuRecipes(r.owner), b.contents)
		b.prompt.ActionText = match and `Add / Plate {match.name}` or "Add"
	else
		b.prompt.ActionText = "Add"
	end
end

function CookingService:_useBoard(player, r, i)
	local b = r.cooking.boards[i]
	local top = self:Top(player)
	if top and top.kind == "ING" then
		if top.grade == "RUINED" then
			toast(player, "That's charcoal now. Trash it.", "bad")
			return
		end
		local item = self:Pop(player)
		local key = boardKey(item)
		b.contents[key] = (b.contents[key] or 0) + 1
		table.insert(b.scores, item.score or 1)
		if item.heat then
			table.insert(b.cook, item.score)
		end
		b.order = b.order or {}
		table.insert(b.order, item)
		self:_drawBoard(r, i)
		return
	end
	if next(b.contents) == nil then
		toast(player, "Stack ingredients here to build a dish.", "info")
		return
	end
	if not self:HandsFree(player) then
		toast(player, "Your hands are full.", "bad")
		return
	end
	local recipe, omitted = Formulas.bestMatch(restaurantSvc:MenuRecipes(player), b.contents)
	if not recipe then
		toast(player, "That doesn't make any dish on your menu yet.", "bad")
		return
	end
	local dish = {
		kind = "DISH",
		recipeId = recipe.id,
		label = #omitted > 0 and `{recipe.name} (custom)` or recipe.name,
		contents = table.clone(b.contents),
		omitted = omitted,
		quality = Formulas.mean(b.scores),
		cook = Formulas.mean(b.cook),
		color = Color3.fromRGB(255, 255, 255):Lerp(itemColor(b.order[1]), 0.5),
	}
	self:Give(player, dish)
	self:_clearBoard(player, r, i, false)
end

function CookingService:_clearBoard(player, r, i, charge)
	local b = r.cooking.boards[i]
	if charge and next(b.contents) ~= nil then
		self:_chargeWaste(player, { kind = "DISH", contents = b.contents })
	end
	b.contents = {}
	b.scores = {}
	b.cook = {}
	b.order = {}
	self:_drawBoard(r, i)
end

-- Lifecycle ---------------------------------------------------------------------------------------------------
function CookingService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	progression = registry.ProgressionService
	mutations = registry.MutationService
	restaurantSvc = registry.RestaurantService

	restaurantSvc.Built:Connect(function(player, r)
		carry[player] = carry[player] or {}
		self:_wire(r)
		self:_syncCarry(player)
	end)
	restaurantSvc.Removing:Connect(function(player)
		chopping[player] = nil
		pouring[player] = nil
		pending[player] = nil
	end)
	mutations.Equipped:Connect(function(player)
		self:_syncCarry(player)
	end)
	data.ClientReady:Connect(function(player)
		self:_syncCarry(player)
	end)

	Net.on("PantryPick", function(player, id)
		local p = pending[player]
		pending[player] = nil
		if not p or typeof(id) ~= "string" or not table.find(p.options, id) or not near(player, p.part) then
			return
		end
		if p.mode == "pantry" then
			if self:Give(player, { kind = "ING", id = id, state = "RAW", score = 1 }) then
				return
			end
			toast(player, "Your hands are full.", "bad")
		elseif p.mode == "drink" then
			self:_startPour(player, p.r, id)
		end
	end)
	Net.on("ChopTap", function(player)
		self:_chopTap(player)
	end)
	Net.on("ChopCancel", function(player)
		if chopping[player] then
			chopping[player] = nil
			Net.fire(player, "ChopEnd")
		end
	end)
	Net.on("PourStop", function(player)
		self:_stopPour(player)
	end)
end

-- What the player is doing right now, for the tutorial: carried items, board contents and what's cooking.
function CookingService:Snapshot(player)
	local r = restaurantSvc:Get(player)
	local snap = { carry = carry[player] or {}, boards = {}, heat = {} }
	if r and r.cooking then
		for i, b in r.cooking.boards do
			snap.boards[i] = b.contents
		end
		for stationId, heat in r.cooking.heat do
			for _, s in heat.slots do
				if s.item then
					table.insert(snap.heat, { station = stationId, id = s.item.id })
				end
			end
		end
	end
	return snap
end

function CookingService:Start()
	while true do
		task.wait(0.25)
		for _, r in restaurantSvc:All() do
			if r.cooking then
				self:_heatTick(r)
			end
		end
		for player, p in pouring do
			if (now() - p.startAt) / p.seconds >= Constants.POUR_MAX_FILL then
				self:_stopPour(player) -- overflowed
			end
		end
	end
end

function CookingService:OnPlayerReady(player)
	-- a reset character loses the carried-item models; rebuild them
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		self:_syncCarry(player)
	end)
end

function CookingService:OnPlayerLeaving(player)
	carry[player] = nil
	chopping[player] = nil
	pouring[player] = nil
	pending[player] = nil
	wasteDebt[player] = nil
end

return CookingService

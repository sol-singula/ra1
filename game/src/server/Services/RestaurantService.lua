-- Plot assignment, building the restaurant, tier upgrades, menu and reputation (GDD §27.8.2).
-- MVP: the restaurant is built directly on the player's Restaurant Row plot instead of an instanced interior.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local RestaurantBuilder = require(ServerScriptService.Server.World.RestaurantBuilder)

local RestaurantService = {
	Name = "RestaurantService",
	Dependencies = { "PlayerDataService", "EconomyService", "ProgressionService" },
	Built = Signal.new("RestaurantService.Built"), -- (player, restaurant) on first build and after an upgrade
	Removing = Signal.new("RestaurantService.Removing"), -- (player, restaurant)
}

local data, economy, progression
local restaurants = {} -- [player] = restaurant
local plotOwner = {} -- [plotIndex] = player

local function tierIndex(profile)
	return Progression.TierById[profile.tier].index
end

function RestaurantService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	progression = registry.ProgressionService

	Net.on("SetMenu", function(player, list)
		self:_setMenu(player, list)
	end)
	Net.on("UpgradeTier", function(player)
		self:_upgrade(player)
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	progression.LevelChanged:Connect(function(player)
		self:Push(player) -- newly unlocked recipes and tier eligibility
	end)
end

function RestaurantService:OnPlayerReady(player, profile)
	local plot
	for i = 1, Constants.MAX_PLAYERS do
		if not plotOwner[i] then
			plot = i
			break
		end
	end
	if not plot then
		player:Kick("This street is full. Please join another server.")
		return
	end
	plotOwner[plot] = player
	local r = {
		owner = player,
		plotIndex = plot,
		tierIndex = tierIndex(profile),
	}
	restaurants[player] = r
	self:_build(r)

	player.CharacterAdded:Connect(function(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if hrp and restaurants[player] then
			task.wait() -- let the default spawn finish before moving the character
			character:PivotTo(restaurants[player].layout.kitchenSpawn)
		end
	end)
	if player.Character then
		player.Character:PivotTo(r.layout.kitchenSpawn)
	end
	self:Push(player)
end

function RestaurantService:_build(r)
	if r.layout then
		self.Removing:Fire(r.owner, r)
		r.layout.model:Destroy()
	end
	r.layout = RestaurantBuilder.build(r.owner, r.plotIndex, r.tierIndex)
	r.tier = Progression.Tiers[r.tierIndex]
	r.layout.setMenu(self:MenuRecipes(r.owner))
	self.Built:Fire(r.owner, r)
end

function RestaurantService:OnPlayerLeaving(player)
	local r = restaurants[player]
	if not r then
		return
	end
	self.Removing:Fire(player, r)
	r.layout.model:Destroy()
	plotOwner[r.plotIndex] = nil
	restaurants[player] = nil
end

function RestaurantService:Get(player)
	return restaurants[player]
end

-- Which restaurant (if any) a world position is inside; used to scope interactions to one plot.
function RestaurantService:At(position)
	for _, r in restaurants do
		local localPos = r.layout.root:PointToObjectSpace(position)
		if math.abs(localPos.X) <= 32 and localPos.Z <= 26 and localPos.Z >= -36 then
			return r
		end
	end
	return nil
end

function RestaurantService:All()
	return restaurants
end

function RestaurantService:Atmosphere(player)
	local r = restaurants[player]
	return r and (Constants.BASE_ATMOSPHERE[r.tier.id] or 30) or 0
end

function RestaurantService:Stars(player)
	local profile = data:Get(player)
	return profile and profile.stars or Constants.START_STARS
end

-- [C11.4] Reputation after a customer leaves; storm-outs cost an extra 0.03 stars.
function RestaurantService:RecordCustomer(player, satisfaction, stormedOut)
	local profile = data:Get(player)
	if not profile then
		return
	end
	profile.stars = Formulas.updateStars(profile.stars, satisfaction)
	if stormedOut then
		profile.stars = math.max(1, profile.stars - Constants.STORM_OUT_STARS)
	end
	data:Push(player, { stars = profile.stars })
end

function RestaurantService:MenuRecipes(player)
	local profile = data:Get(player)
	local list = {}
	if profile then
		for _, id in profile.menu do
			table.insert(list, Recipes.byId[id])
		end
	end
	return list
end

function RestaurantService:_setMenu(player, list)
	local profile = data:Get(player)
	local r = restaurants[player]
	if not profile or not r or typeof(list) ~= "table" then
		return
	end
	local clean, seen = {}, {}
	for _, id in list do
		local recipe = typeof(id) == "string" and Recipes.byId[id]
		if recipe and not seen[id] and recipe.unlock <= profile.level then
			seen[id] = true
			table.insert(clean, id)
		end
	end
	if #clean == 0 or #clean > r.tier.menu then
		Net.fire(player, "Toast", `Pick between 1 and {r.tier.menu} dishes for your menu.`, "bad")
		return
	end
	profile.menu = clean
	r.layout.setMenu(self:MenuRecipes(player))
	self:Push(player)
	Net.fire(player, "Toast", "Menu updated.", "good")
end

function RestaurantService:_upgrade(player)
	local profile = data:Get(player)
	local r = restaurants[player]
	if not profile or not r then
		return
	end
	local nextTier = Progression.Tiers[r.tierIndex + 1]
	if not nextTier then
		Net.fire(player, "Toast", "That's the biggest restaurant in this build.", "info")
		return
	end
	if profile.level < nextTier.level then
		Net.fire(player, "Toast", `Reach level {nextTier.level} to upgrade.`, "bad")
		return
	end
	if r.customerCount and r.customerCount > 0 then
		Net.fire(player, "Toast", "Finish serving your customers first.", "bad")
		return
	end
	if not economy:Spend(player, "MB", nextTier.cost, "tier_upgrade") then
		Net.fire(player, "Toast", `You need {nextTier.cost} MB.`, "bad")
		return
	end
	profile.tier = nextTier.id
	r.tierIndex = nextTier.index
	self:_build(r)
	if player.Character then
		player.Character:PivotTo(r.layout.kitchenSpawn)
	end
	self:Push(player)
	Net.fire(player, "Toast", `Welcome to the {nextTier.name}!`, "good")
end

function RestaurantService:Push(player)
	local profile = data:Get(player)
	local r = restaurants[player]
	if not profile or not r then
		return
	end
	local nextTier = Progression.Tiers[r.tierIndex + 1]
	data:Push(player, {
		tier = r.tier.id,
		tierName = r.tier.name,
		seats = r.tier.seats,
		menuSlots = r.tier.menu,
		menu = profile.menu,
		stars = profile.stars,
		nextTier = nextTier and {
			name = nextTier.name,
			cost = nextTier.cost,
			level = nextTier.level,
			seats = nextTier.seats,
			menu = nextTier.menu,
		} or false,
	})
end

return RestaurantService

-- Scavenging: the piles at each stop, the field bag, and banking.
--   Piles (World/StopBuilder nodes) get a hold-to-collect prompt when the stop appears. Material piles and the
--   blueprint are per player: everyone can take each one once, so a crew never fights over a pile. Fuel cans are the
--   crew's: whoever grabs one, it's gone for everyone, and it goes into the train's tank when it's brought back.
--   Everything you pick up goes into your field bag (Formulas.bagCapacity). The bag is "banked" the moment you're
--   back inside the train: materials and blueprints go to your storage (saved), fuel to the tank. If the train
--   leaves without you, the bag is lost (RecoveryService calls LoseBag); you're warned before that can happen.
-- The server checks every pickup: the doors are open, you're close enough, you haven't taken it, it fits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ResourceService = {
	Name = "ResourceService",
	Dependencies = { "PlayerDataService", "ExpeditionService" },
	Collected = Signal.new("ResourceService.Collected"), -- (player, kind, amount, far)
	Banked = Signal.new("ResourceService.Banked"), -- (player, items {kind = n}, blueprints {key = n})
	Lost = Signal.new("ResourceService.Lost"), -- (player, count)
	BagFull = Signal.new("ResourceService.BagFull"), -- (player)
}

local data, expedition
local nodes = {} -- [nodeId] = { model, kind, amount, root, far, fuel = bool }
local taken = {} -- [player] = { [nodeId] = true } (material piles and blueprints)
local fuelTaken = {} -- [nodeId] = true
local bags = {} -- [player] = { items = { wood = n, ... }, plans = { key = n } }
local nextId = 0

local function emptyBag()
	return { items = {}, plans = {} }
end

local function bagOf(player)
	bags[player] = bags[player] or emptyBag()
	return bags[player]
end

function ResourceService:BagCount(player)
	local bag = bags[player]
	if not bag then
		return 0
	end
	local n = Formulas.count(bag.items)
	for _, v in bag.plans do
		n += v
	end
	return n
end

function ResourceService:Capacity(player)
	local profile = data:Get(player)
	return Formulas.bagCapacity(profile and profile.cabin.built)
end

function ResourceService:Bag(player)
	return bagOf(player)
end

function ResourceService:PushBag(player)
	local bag = bagOf(player)
	Net.fire(
		player,
		"Bag",
		{ items = bag.items, plans = bag.plans, count = self:BagCount(player), cap = self:Capacity(player) }
	)
end

-- Piles ------------------------------------------------------------------------------------------------------------------
local OBJECT = {
	wood = "Wood",
	scrap = "Scrap",
	parts = "Parts",
	cloth = "Cloth",
	fuel = "Fuel can",
	blueprint = "Blueprint",
}

function ResourceService:_setup(_stop, model)
	nodes = {}
	fuelTaken = {}
	for p in taken do
		taken[p] = {}
	end
	-- keep as many fuel cans as the crew needs, spread over the spots
	local fuelSpots = {}
	for _, m in model:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Node") == "fuel" then
			table.insert(fuelSpots, m)
		end
	end
	table.sort(fuelSpots, function(a, b)
		return (a:GetAttribute("FuelSpot") or 0) < (b:GetAttribute("FuelSpot") or 0)
	end)
	local keep = Formulas.fuelCans(#Players:GetPlayers())
	for i, m in fuelSpots do
		-- the first three are near the platform; the rest are kept in order
		if i > keep then
			m:Destroy()
		end
	end
	for _, m in model:GetDescendants() do
		if m:IsA("Model") and m:GetAttribute("Node") and m.Parent then
			nextId += 1
			local id = "n" .. nextId
			local kind = m:GetAttribute("Node")
			local root = m.PrimaryPart
			if root then
				m:SetAttribute("NodeId", id)
				local amount = m:GetAttribute("Amount") or 1
				nodes[id] = {
					model = m,
					kind = kind,
					amount = amount,
					root = root,
					far = m:GetAttribute("Far") == true,
					fuel = kind == "fuel",
				}
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Prompt_node"
				prompt.ActionText = kind == "blueprint" and "Take" or "Collect"
				prompt.ObjectText = kind == "blueprint" and "Blueprint"
					or (amount > 1 and `{OBJECT[kind]} ×{amount}` or OBJECT[kind])
				prompt.HoldDuration = kind == "blueprint" and 1.6 or Constants.COLLECT_HOLD
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = root
				prompt:SetAttribute("NodeId", id)
				prompt.Triggered:Connect(function(player)
					self:Collect(player, id)
				end)
			end
		end
	end
	Net.fireAll("Nodes", { reset = true })
end

function ResourceService:Node(id)
	return nodes[id]
end

function ResourceService:Nodes()
	return nodes
end

function ResourceService:Collect(player, id)
	local node = nodes[id]
	local profile = data:Get(player)
	if not node or not profile or not node.model.Parent then
		return false, "gone"
	end
	if not expedition:IsAtStop() or expedition:InRecovery(player) then
		return false, "closed"
	end
	local pos = expedition:Position(player)
	if not pos or (pos - node.root.Position).Magnitude > Constants.COLLECT_RANGE then
		return false, "far"
	end
	taken[player] = taken[player] or {}
	if node.fuel then
		if fuelTaken[id] then
			return false, "taken"
		end
	elseif taken[player][id] then
		return false, "taken"
	end
	local amount = node.kind == "blueprint" and 1 or node.amount
	-- specialist bonuses
	local bonus = {}
	local spec = profile.cabin.built.specialist and profile.cabin.variants.specialist
	if spec == "mechanic" and node.kind == "scrap" and math.random() < 0.35 then
		bonus.parts = 1
	elseif spec == "botanist" and (node.kind == "wood" or node.kind == "cloth") and math.random() < 0.35 then
		bonus[node.kind] = 1
	end
	local room = self:Capacity(player) - self:BagCount(player)
	if room < amount then
		Net.fire(player, "Toast", "Your bag is full! Get back on the train to bank it.", "bad")
		self.BagFull:Fire(player)
		return false, "full"
	end
	local bag = bagOf(player)
	if node.kind == "blueprint" then
		local key = Formulas.blueprintFor(
			expedition:State().stop or { plans = { "map" } },
			profile.blueprints,
			profile.cabin.built
		)
		bag.plans[key] = (bag.plans[key] or 0) + 1
		Net.fire(
			player,
			"Popup",
			node.root.Position + Vector3.new(0, 4, 0),
			`+1 {Resources.BLUEPRINTS[key].icon} {Resources.BLUEPRINTS[key].name}`,
			Color3.fromRGB(140, 190, 255)
		)
		Net.fire(player, "Toast", `Found: {Resources.BLUEPRINTS[key].name}! Bank it on the train.`, "good")
	else
		bag.items[node.kind] = (bag.items[node.kind] or 0) + amount
		local icon = node.kind == "fuel" and Resources.FUEL.icon or Resources.byKey[node.kind].icon
		local text = `+{amount} {icon}`
		for k, v in bonus do
			if self:BagCount(player) < self:Capacity(player) then
				bag.items[k] = (bag.items[k] or 0) + v
				text ..= `  +{v} {Resources.byKey[k].icon}`
			end
		end
		Net.fire(player, "Popup", node.root.Position + Vector3.new(0, 4, 0), text, Color3.fromRGB(255, 230, 160))
	end
	if node.fuel then
		fuelTaken[id] = true
		Net.fireAll("Nodes", { taken = { id }, shared = true })
		task.delay(0.2, function()
			if node.model.Parent then
				node.model:Destroy()
			end
		end)
	else
		taken[player][id] = true
		Net.fire(player, "Nodes", { taken = { id } })
	end
	profile.stats.collected += amount
	Net.fire(player, "Sfx", "pickup", node.root.Position)
	self:PushBag(player)
	self.Collected:Fire(player, node.kind, amount, node.far)
	return true, amount
end

-- Banking ------------------------------------------------------------------------------------------------------------------
function ResourceService:Bank(player)
	local bag = bags[player]
	local profile = data:Get(player)
	if not bag or not profile or self:BagCount(player) == 0 then
		return false
	end
	local parts = {}
	local items, plans = bag.items, bag.plans
	for _, key in Resources.MATERIALS do
		local n = items[key]
		if n and n > 0 then
			profile.storage[key] = (profile.storage[key] or 0) + n
			table.insert(parts, `+{n} {Resources.byKey[key].icon}`)
		end
	end
	local fuel = items.fuel or 0
	if fuel > 0 then
		expedition:AddFuel(player, fuel * Constants.FUEL_PER_CAN)
		profile.stats.fuel += fuel
		table.insert(parts, `+{fuel} {Resources.FUEL.icon} to the tank`)
	end
	for key, n in plans do
		profile.blueprints[key] = (profile.blueprints[key] or 0) + n
		profile.stats.blueprints += n
		expedition:Note(player, "blueprints", n)
		table.insert(parts, `+{n} {Resources.BLUEPRINTS[key].icon}`)
	end
	profile.stats.banked += self:BagCount(player)
	bags[player] = emptyBag()
	data:Push(player, { storage = profile.storage, blueprints = profile.blueprints })
	Net.fire(player, "Toast", "Banked: " .. table.concat(parts, "  "), "good")
	Net.fire(player, "Sfx", "bank")
	self:PushBag(player)
	self.Banked:Fire(player, items, plans)
	return true
end

-- Left behind: the bag is gone.
function ResourceService:LoseBag(player)
	local n = self:BagCount(player)
	if n > 0 then
		local profile = data:Get(player)
		if profile then
			profile.stats.lost += n
		end
		self.Lost:Fire(player, n)
	end
	bags[player] = emptyBag()
	self:PushBag(player)
	return n
end

function ResourceService:Init(registry)
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	expedition.Arrived:Connect(function(stop, model)
		self:_setup(stop, model)
	end)
	expedition.Departed:Connect(function()
		nodes = {}
		fuelTaken = {}
		for p in taken do
			taken[p] = {}
		end
		Net.fireAll("Nodes", { reset = true })
	end)
	data.ClientReady:Connect(function(player)
		self:PushBag(player)
		local list = {}
		for id in taken[player] or {} do
			table.insert(list, id)
		end
		for id in fuelTaken do
			table.insert(list, id)
		end
		if #list > 0 then
			Net.fire(player, "Nodes", { taken = list })
		end
	end)
end

function ResourceService:OnPlayerReady(player)
	taken[player] = {}
	bags[player] = emptyBag()
	self:PushBag(player)
end

function ResourceService:OnPlayerLeaving(player)
	taken[player] = nil
	bags[player] = nil
end

function ResourceService:Start()
	while true do
		task.wait(0.25)
		for player, bag in bags do
			if player.Parent and (next(bag.items) or next(bag.plans)) then
				local pos = expedition:Position(player)
				if pos and Layout.inTrain(pos) and not expedition:InRecovery(player) then
					self:Bank(player)
				end
			end
		end
	end
end

return ResourceService

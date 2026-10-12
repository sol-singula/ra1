-- Pets and eggs. The Egg Machine in the Hub sells eggs for gems (odds shown; players whose policy restricts paid
-- random items don't see them). A pet floats beside you (the client moves it) and adds damage and forge luck.
-- One pet out at a time, two with the Pet Slot pass.
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local Scenery = require(script.Parent.Parent.World.Scenery)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local PetService = {
	Name = "PetService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	Hatched = Signal.new("PetService.Hatched"), -- (player, pet, eggKey)
}

local data, economy
local models = {} -- [player] = { [uid] = model }
local canRandom = {} -- [player] = true/false
local rng = Random.new()
local folder

local function buildPet(pet, uid, player)
	local model = Instance.new("Model")
	model.Name = "Pet_" .. pet.id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CastShadow = false
	root.Material = Enum.Material.SmoothPlastic
	root.Color = pet.color
	if pet.shape == "ball" then
		root.Shape = Enum.PartType.Ball
		root.Size = Vector3.new(1.6, 1.6, 1.6)
	elseif pet.shape == "box" then
		root.Size = Vector3.new(1.5, 1.3, 1.5)
	else
		root.Size = Vector3.new(1.3, 1.3, 1.3)
		root.CFrame = CFrame.Angles(0.5, 0.5, 0.5)
		root.Material = Enum.Material.Neon
	end
	root.Parent = model
	model.PrimaryPart = root
	-- eyes
	for _, side in { -1, 1 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Size = Vector3.new(0.3, 0.3, 0.1)
		eye.Color = Color3.fromRGB(255, 255, 255)
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.CFrame = root.CFrame * CFrame.new(side * 0.3, 0.15, -0.75)
		eye.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = eye
		w.Parent = eye
	end
	if pet.rarity == "Legend" or pet.rarity == "Secret" then
		local light = Instance.new("PointLight")
		light.Color = pet.color
		light.Range = 8
		light.Parent = root
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(pet.color)
		e.Rate = 3
		e.Size = NumberSequence.new(0.3, 0)
		e.Lifetime = NumberRange.new(0.5, 0.9)
		e.Parent = root
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(110, 24)
	gui.StudsOffset = Vector3.new(0, 1.4, 0)
	gui.MaxDistance = 40
	gui.LightInfluence = 0
	gui.Parent = root
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextStrokeTransparency = 0
	t.TextColor3 = Pets.RarityColor[pet.rarity]
	t.Text = pet.name
	t.Parent = gui
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Uid", uid)
	model:SetAttribute("PetId", pet.id)
	return model
end

function PetService:Slots(player)
	return economy:HasPass(player, "PETSLOT") and 2 or 1
end

-- The bonuses from the pets you have out.
function PetService:Bonus(player)
	local profile = data:Get(player)
	local dmg, luck = 0, 0
	for _, uid in profile and profile.petsOut or {} do
		for _, p in profile.pets do
			if p.uid == uid then
				local pet = Pets.byId[p.id]
				if pet then
					dmg += pet.dmg
					luck += pet.luck
				end
			end
		end
	end
	return dmg, luck
end

function PetService:View(player)
	local profile = data:Get(player)
	local list = {}
	for _, p in profile.pets do
		local pet = Pets.byId[p.id]
		if pet then
			table.insert(list, {
				uid = p.uid,
				id = p.id,
				name = pet.name,
				rarity = pet.rarity,
				dmg = pet.dmg,
				luck = pet.luck,
				out = table.find(profile.petsOut, p.uid) ~= nil,
			})
		end
	end
	local eggs = {}
	for _, e in Pets.Eggs do
		local odds = {}
		for _, row in e.odds do
			table.insert(odds, `{row[1]}: {row[2]}%`)
		end
		table.insert(eggs, { key = e.key, name = e.name, gems = e.gems, emoji = e.emoji, odds = odds })
	end
	local dmg, luck = self:Bonus(player)
	return {
		pets = list,
		eggs = eggs,
		slots = self:Slots(player),
		canRandom = canRandom[player] ~= false,
		bonusDmg = dmg,
		bonusLuck = luck,
	}
end

function PetService:Push(player)
	if data:Get(player) then
		data:Push(player, { petView = self:View(player) })
	end
end

function PetService:_sync(player)
	local profile = data:Get(player)
	models[player] = models[player] or {}
	local keep = {}
	for i, uid in profile.petsOut do
		keep[uid] = true
		if not models[player][uid] then
			for _, p in profile.pets do
				if p.uid == uid then
					local model = buildPet(Pets.byId[p.id], uid, player)
					model:SetAttribute("Slot", i)
					model.Parent = folder
					models[player][uid] = model
				end
			end
		end
	end
	for uid, model in table.clone(models[player]) do
		if not keep[uid] then
			model:Destroy()
			models[player][uid] = nil
		end
	end
end

function PetService:Grant(player, pet, how)
	local profile = data:Get(player)
	if not profile then
		return nil
	end
	local rec = { uid = profile.nextUid, id = pet.id }
	profile.nextUid += 1
	table.insert(profile.pets, rec)
	if #profile.petsOut < self:Slots(player) then
		table.insert(profile.petsOut, rec.uid)
		self:_sync(player)
	end
	self:Push(player)
	self.Hatched:Fire(player, pet, how)
	return rec
end

function PetService:BuyEgg(player, key)
	local egg = Pets.eggByKey[key]
	local profile = data:Get(player)
	if not egg or not profile then
		return false
	end
	if canRandom[player] == false then
		Net.fire(player, "Toast", "Eggs aren't allowed on your account.", "bad")
		return false
	end
	if not economy:SpendGems(player, egg.gems) then
		Net.fire(player, "Toast", `You need {egg.gems} gems. Raids and quests pay gems!`, "bad")
		return false
	end
	local rarity = Formulas.pickOdds(egg.odds, rng:NextNumber(), 1)
	local pool = {}
	for _, p in Pets.list do
		if p.rarity == rarity then
			table.insert(pool, p)
		end
	end
	local pet = pool[rng:NextInteger(1, #pool)]
	self:Grant(player, pet, key)
	Net.fire(
		player,
		"Alert",
		`{egg.emoji} HATCHED: {pet.name} ({pet.rarity})! +{math.floor(pet.dmg * 100)}% damage`,
		Pets.RarityColor[pet.rarity]
	)
	Net.fire(player, "Sfx", "hatch")
	if rarity == "Legend" or rarity == "Secret" then
		Net.fireAll("Announce", `🥚 {player.DisplayName} hatched a {rarity} {pet.name}!`, Pets.RarityColor[rarity])
	end
	return true
end

function PetService:Equip(player, uid, out)
	local profile = data:Get(player)
	if not profile then
		return
	end
	local i = table.find(profile.petsOut, uid)
	if out and not i then
		local owned = false
		for _, p in profile.pets do
			owned = owned or p.uid == uid
		end
		if not owned then
			return
		end
		if #profile.petsOut >= self:Slots(player) then
			table.remove(profile.petsOut, 1) -- the oldest goes back in the bag
		end
		table.insert(profile.petsOut, uid)
	elseif not out and i then
		table.remove(profile.petsOut, i)
	end
	self:_sync(player)
	self:Push(player)
end

function PetService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	Net.on("BuyEgg", function(player, key)
		if type(key) == "string" then
			self:BuyEgg(player, key)
		end
	end)
	Net.on("EquipPet", function(player, uid, out)
		if type(uid) == "number" then
			self:Equip(player, uid, out ~= false)
		end
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
	economy.PassesChanged:Connect(function(player)
		self:Push(player)
	end)
	-- the Egg Machine in the Hub: a glowing egg on a stand with a prompt
	local hub = WorldBuilder.layout.hub.model
	local pos = Vector3.new(16, 0, -16)
	Scenery.part({
		Name = "EggStand",
		Size = Vector3.new(5, 1.5, 5),
		CFrame = CFrame.new(pos + Vector3.new(0, 0.75, 0)),
		Color = Color3.fromRGB(90, 90, 120),
		Parent = hub,
	})
	local egg = Scenery.ball(
		hub,
		"EggMachine",
		pos + Vector3.new(0, 3.6, 0),
		3.6,
		Color3.fromRGB(255, 200, 240),
		Enum.Material.Neon,
		{ CanCollide = false }
	)
	egg:SetAttribute("TurnSpeed", 0.6)
	egg:SetAttribute("Bob", 0.3)
	game:GetService("CollectionService"):AddTag(egg, "Turn")
	local sign = Scenery.sign(egg, 12, 4, Vector3.new(0, 3.5, 0), {
		{
			text = "🥚 EGG MACHINE",
			h = 0.55,
			y = 0,
			font = Enum.Font.LuckiestGuy,
			color = Color3.fromRGB(255, 200, 240),
		},
		{ text = "Pets from eggs, for gems", h = 0.45, y = 0.55 },
	}, 90)
	sign.Size = UDim2.fromOffset(170, 52)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt_eggs"
	prompt.ActionText = "Open the Egg Machine"
	prompt.ObjectText = "EGGS"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg
	_ = Constants
end

function PetService:OnPlayerReady(player, profile)
	profile.pets = profile.pets or {}
	profile.petsOut = profile.petsOut or {}
	task.spawn(function()
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		canRandom[player] = not ok or info.ArePaidRandomItemsRestricted ~= true
		if player.Parent then
			self:Push(player)
		end
	end)
	local function spawned()
		task.defer(function()
			if player.Parent then
				self:_sync(player)
			end
		end)
	end
	player.CharacterAdded:Connect(spawned)
	spawned()
end

function PetService:OnPlayerLeaving(player)
	for _, model in models[player] or {} do
		model:Destroy()
	end
	models[player] = nil
	canRandom[player] = nil
end

return PetService

-- Mutation ownership and equipping, reduced to the tutorial's first-mutation choice (GDD §27.8.8, QST_TUT_010).
-- The equipped part adds stats, a passive and one active ability; MorphBuilder attaches its greybox model.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local MorphBuilder = require(ReplicatedStorage.Shared.MorphBuilder)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)

local MutationService = {
	Name = "MutationService",
	Dependencies = { "PlayerDataService" },
	Equipped = Signal.new("MutationService.Equipped"), -- (player, mutationId?)
}

local data

local function equippedRow(profile)
	local id = profile and profile.mutations.equipped
	return id and Progression.Mutations[id] or nil
end

function MutationService:Init(registry)
	data = registry.PlayerDataService

	Net.on("ChooseMutation", function(player, mutationId)
		local profile = data:Get(player)
		if not profile or typeof(mutationId) ~= "string" then
			return
		end
		if next(profile.mutations.owned) ~= nil or not table.find(Progression.TutorialChoices, mutationId) then
			return -- the free tutorial pick happens once
		end
		profile.mutations.owned[mutationId] = 1
		profile.mutations.equipped = mutationId
		self:_apply(player)
		Net.fire(player, "Toast", `You grew a {Progression.Mutations[mutationId].name}!`, "good")
	end)

	data.ClientReady:Connect(function(player)
		self:_offerChoice(player)
		self:_push(player)
	end)
end

function MutationService:OnPlayerReady(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		MorphBuilder.attachMutation(character, equippedRow(data:Get(player)))
	end)
	if player.Character then
		MorphBuilder.attachMutation(player.Character, equippedRow(data:Get(player)))
	end
	self:_offerChoice(player)
	self:_push(player)
end

function MutationService:_offerChoice(player)
	local profile = data:Get(player)
	if profile and next(profile.mutations.owned) == nil then
		Net.fire(player, "ChooseMutation", Progression.TutorialChoices)
	end
end

function MutationService:_push(player)
	local row = equippedRow(data:Get(player))
	data:Push(player, { mutation = row and row.id or false, ability = row and row.ability or false })
end

function MutationService:_apply(player)
	local row = equippedRow(data:Get(player))
	if player.Character then
		MorphBuilder.attachMutation(player.Character, row)
	end
	self:_push(player)
	self.Equipped:Fire(player, row and row.id)
end

-- Stat bonuses from equipped parts: { [statCode] = number }.
function MutationService:StatBonus(player)
	local row = equippedRow(data:Get(player))
	return row and row.stats or {}
end

function MutationService:CarryBonus(player)
	local row = equippedRow(data:Get(player))
	return row and row.carryBonus or 0
end

function MutationService:RepairBonus(player)
	local row = equippedRow(data:Get(player))
	return row and row.repairBonus or 0
end

function MutationService:Ability(player)
	local row = equippedRow(data:Get(player))
	return row and row.ability or nil
end

return MutationService

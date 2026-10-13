-- Crates: the Coin Crate (coins) and the Key Crate (a crate key; keys are sold for Robux and dropped by quests,
-- gifts and the season). Each shows its exact odds. Players whose account restricts paid random items can't
-- open the Key Crate (PolicyService), and the client hides it for them.
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local CrateService = {
	Name = "CrateService",
	Dependencies = { "PlayerDataService", "EconomyService", "LoadoutService" },
	Opened = Signal.new("CrateService.Opened"), -- (player, crateKey, skinId)
}

local data, economy, loadout
local canPaid = {} -- [player] = false if paid random items are restricted
local rng = Random.new()

function CrateService:CanPaid(player)
	return canPaid[player] ~= false
end

function CrateService:Open(player, key)
	local crate = Cosmetics.crateByKey[key]
	if not crate or not data:Get(player) then
		return nil
	end
	if crate.paid and not self:CanPaid(player) then
		Net.fire(player, "Toast", "Key crates aren't available on your account.", "bad")
		return nil
	end
	if crate.coins then
		if not economy:SpendCoins(player, crate.coins) then
			Net.fire(player, "Toast", `You need {crate.coins} coins. Pop more players!`, "bad")
			return nil
		end
	elseif not economy:SpendKeys(player, crate.keys) then
		Net.fire(player, "Toast", "You need a crate key. Quests, gifts and the Store have them!", "bad")
		return nil
	end
	local id = Formulas.rollCrate(rng, key)
	loadout:GrantSkin(player, id, "crate")
	local skin = Cosmetics.skinById[id]
	Net.fire(player, "Crate", { crate = key, skin = id })
	Net.fire(player, "Sfx", (skin.rarity == "Legend" or skin.rarity == "Secret") and "win" or "crate")
	if skin.rarity == "Legend" or skin.rarity == "Secret" then
		Net.fireAll(
			"Announce",
			`🎁 {player.DisplayName} opened a {skin.rarity} {skin.name} skin!`,
			Cosmetics.RarityColor[skin.rarity]
		)
	end
	self.Opened:Fire(player, key, id)
	return id
end

function CrateService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	loadout = registry.LoadoutService
	Net.on("OpenCrate", function(player, key)
		if type(key) == "string" then
			self:Open(player, key)
		end
	end)
	data.ClientReady:Connect(function(player)
		data:Push(player, { canPaidRandom = self:CanPaid(player) })
	end)
end

function CrateService:OnPlayerReady(player)
	task.spawn(function()
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		canPaid[player] = not ok or info.ArePaidRandomItemsRestricted ~= true
		if player.Parent then
			data:Push(player, { canPaidRandom = canPaid[player] })
		end
	end)
end

function CrateService:OnPlayerLeaving(player)
	canPaid[player] = nil
end

return CrateService

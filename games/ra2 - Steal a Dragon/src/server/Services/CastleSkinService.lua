-- Castle skins (Data/CastleSkins.lua): Robux products bought in the Shop's CASTLES tab. Owned skins are saved in
-- profile.castleSkins; the one you wear (profile.castleSkin) restyles your castle while you're in the server, and
-- your castle goes back to normal when you leave (another player gets that base).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CastleSkins = require(ReplicatedStorage.Shared.Data.CastleSkins)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local CastleSkinService = {
	Name = "CastleSkinService",
	Dependencies = { "PlayerDataService", "BaseService", "ShopService" },
	Changed = Signal.new("CastleSkinService.Changed"), -- (player, key or nil)
}

local data, baseService, shop

function CastleSkinService:Push(player)
	local profile = data:Get(player)
	if profile then
		data:Push(player, { castleSkins = profile.castleSkins, castleSkin = profile.castleSkin or false })
	end
end

function CastleSkinService:Apply(player)
	local profile = data:Get(player)
	local base = baseService:Get(player)
	if not profile or not base then
		return
	end
	WorldBuilder.applyCastleSkin(base.world, profile.castleSkin and CastleSkins.byKey[profile.castleSkin] or nil)
end

-- A skin was bought (ShopService.Grant): it's yours, and you wear it right away.
function CastleSkinService:Give(player, key)
	local profile = data:Get(player)
	local skin = CastleSkins.byKey[key]
	if not profile or not skin then
		return false
	end
	profile.castleSkins[key] = true
	self:Equip(player, key)
	Net.fire(player, "Alert", `{skin.icon} Your castle is now the {skin.name}!`, Color3.fromRGB(255, 205, 50))
	return true
end

-- Wear an owned skin, or "NONE" for the normal castle.
function CastleSkinService:Equip(player, key)
	local profile = data:Get(player)
	if not profile or type(key) ~= "string" then
		return false
	end
	if key == "NONE" then
		profile.castleSkin = nil
	elseif CastleSkins.byKey[key] and profile.castleSkins[key] then
		profile.castleSkin = key
	else
		return false
	end
	self:Apply(player)
	self:Push(player)
	self.Changed:Fire(player, profile.castleSkin)
	return true
end

function CastleSkinService:Init(registry)
	data = registry.PlayerDataService
	baseService = registry.BaseService
	shop = registry.ShopService
	Net.on("BuyCastleSkin", function(player, key)
		local skin = type(key) == "string" and CastleSkins.byKey[key]
		local profile = data:Get(player)
		if not skin or not profile then
			return
		end
		if profile.castleSkins[key] then
			self:Equip(player, key)
		else
			shop:PromptProduct(player, skin.product)
		end
	end)
	Net.on("EquipCastleSkin", function(player, key)
		self:Equip(player, key)
	end)
	data.ClientReady:Connect(function(player)
		self:Push(player)
	end)
end

function CastleSkinService:OnPlayerReady(player, profile)
	profile.castleSkins = profile.castleSkins or {}
	self:Apply(player)
	self:Push(player)
end

function CastleSkinService:OnPlayerLeaving(player)
	local base = baseService:Get(player)
	if base then
		WorldBuilder.applyCastleSkin(base.world, nil)
	end
end

return CastleSkinService

--[[
What a player owns from the Catalog (§7).

A pass is owned when any of these holds:
  - live game-pass ownership: UserOwnsGamePassAsync on join (pcall, 3 tries, cached for the session), or a
    PromptGamePassPurchaseFinished(true) this session (grantLive)
  - profile.passes[key]: a gift
  - key is extraRow, and the player owns the Starter Bundle
A cosmetic is owned when cosmetics.owned[key] is set, or it is in meta.bundleGrants and the Starter Bundle is owned.

  Purchase.owns(player, key) -> boolean
  Purchase.loadPasses(player)       the join-time ownership read (yields)
  Purchase.grantLive(player, key)
  Purchase.forget(player)
  Purchase.passKeyFor(passId) -> key?
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.Services.DataService)

local Purchase = {}

local TRIES = 3

local live = setmetatable({}, { __mode = "k" }) -- [player] = { [passKey] = true }

local function liveOwns(player, key)
	local t = live[player]
	return t ~= nil and t[key] == true
end

local function bundleOwned(player, profile)
	return liveOwns(player, "starterBundle") or profile.passes.starterBundle == true
end

function Purchase.owns(player, key)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local Catalog = Config.Catalog
	if Catalog.passes[key] then
		if liveOwns(player, key) or profile.passes[key] == true then
			return true
		end
		return key == "extraRow" and bundleOwned(player, profile)
	end
	if profile.cosmetics.owned[key] then
		return true
	end
	local grants = profile.meta.bundleGrants
	return grants ~= nil and table.find(grants, key) ~= nil and bundleOwned(player, profile)
end

function Purchase.loadPasses(player)
	local MarketplaceService = game:GetService("MarketplaceService")
	local t = live[player] or {}
	live[player] = t
	for key, pass in Config.Catalog.passes do
		if pass.id ~= 0 then
			for _ = 1, TRIES do
				local ok, owned = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok then
					t[key] = owned == true or nil
					break
				end
			end
		end
	end
end

function Purchase.grantLive(player, key)
	live[player] = live[player] or {}
	live[player][key] = true
end

function Purchase.forget(player)
	live[player] = nil
end

function Purchase.passKeyFor(passId)
	for key, pass in Config.Catalog.passes do
		if pass.id ~= 0 and pass.id == passId then
			return key
		end
	end
	return nil
end

return Purchase

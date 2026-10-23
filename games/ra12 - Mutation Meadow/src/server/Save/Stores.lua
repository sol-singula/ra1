--[[
The DataStores, under the names in Config.Save / Config.Leaderboard.

  Stores.init()             opens the stores; on failure (an unpublished place, or Studio with API access off)
                            switches to memory-only: a red error in the output, and nothing is ever written
  Stores.memoryOnly         true when there are no DataStores
  Stores.key(userId)        "u_<userId>", the key for a player's profile and their gift queue
  Stores.profiles()         MM_Profiles_v1 (nil when memory-only)
  Stores.gifts()            MM_Gifts_v1 (nil when memory-only)
  Stores.weekly(updateId)   the OrderedDataStore MM_Top_<updateId> (M8; nil when memory-only)
  Stores.budget()           the UpdateAsync request budget left
]]
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Stores = { memoryOnly = false }

local profiles, gifts

function Stores.init()
	local ok, err = pcall(function()
		profiles = DataStoreService:GetDataStore(Config.Save.profileStore)
		gifts = DataStoreService:GetDataStore(Config.Save.giftStore)
	end)
	-- In Studio with API access off, opening a store works but every request fails: probe once
	if ok and RunService:IsStudio() then
		ok, err = pcall(function()
			profiles:GetAsync("_probe")
		end)
	end
	if not ok then
		Stores.memoryOnly = true
		profiles, gifts = nil, nil
		task.spawn(error, `[DataService] DataStores unavailable, running memory-only: nothing will save ({err})`)
	end
	return not Stores.memoryOnly
end

function Stores.key(userId)
	return Config.Save.keyPrefix .. tostring(userId)
end

function Stores.profiles()
	return profiles
end

function Stores.gifts()
	return gifts
end

function Stores.weekly(updateId)
	if Stores.memoryOnly then
		return nil
	end
	return DataStoreService:GetOrderedDataStore(Config.Leaderboard.storePrefix .. updateId)
end

function Stores.budget()
	return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
end

return Stores

-- Is this server the Bonk Arena? Yes when it's the arena place (Constants.ARENA_PLACE_ID), or a reserved server of
-- the main place that a lobby portal opened for the arena (its private server id is in the ARENA_MAP map).
-- Tests set workspace attribute ArenaTest.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local ArenaMode = {}

function ArenaMode.detect()
	if workspace:GetAttribute("ArenaTest") then
		return true
	end
	if Constants.ARENA_PLACE_ID ~= 0 and game.PlaceId == Constants.ARENA_PLACE_ID then
		return true
	end
	local ok, reserved = pcall(function()
		return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
	end)
	if ok and reserved then
		for _ = 1, 3 do
			local got, entry = pcall(function()
				return MemoryStoreService:GetSortedMap(Constants.ARENA_MAP):GetAsync(game.PrivateServerId)
			end)
			if got then
				return entry ~= nil
			end
			task.wait(1)
		end
	end
	return false
end

return ArenaMode

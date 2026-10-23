--[[
Checks the remote handlers run before acting (§2 NetService). Each returns true / a value when the call may go on.

  Guards.loaded(player)                    the player's profile is loaded
  Guards.tileActive(profile, tileId)       the tile exists at the profile's plot level ("extra1".."extra8" need the
                                           Extra Plot Row)
  Guards.ownsTile(player, tileId, ownerId?)   the tile is on the player's own plot (ownerId, when given, is
                                           whose plot the payload names) and active for their level.
                                           TODO M4: also check the plot PlotService assigned this player
  Guards.ownsItem(profile, guid, userId)   the item exists, belongs to userId and is not locked
  Guards.sameServer(userId)                that player if they are on this server, else nil
  Guards.near(player, pos, studs)          the player's character is within studs of pos
  Guards.RANGE                             { tile, stand, sunflower, patch } in studs, from Config.Net
  Guards.dev(player)                       DevConfig.isAllowed(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.Parent.Services.DataService)
local DevConfig = require(script.Parent.Parent.DevConfig)

local Guards = {}

Guards.RANGE = {
	tile = Config.Net.tileRangeStuds,
	stand = Config.Net.standRangeStuds,
	sunflower = Config.Net.sunflowerRangeStuds,
	patch = Config.Net.patchRangeStuds,
}

local GRID = 8 -- tile ids are row-major in an 8x8 grid

function Guards.loaded(player)
	return DataService.check(player) == true
end

function Guards.tileActive(profile, tileId)
	if type(tileId) ~= "string" then
		return false
	end
	local extra = tileId:match("^extra([1-8])$")
	if extra then
		return profile.passes.extraRow == true and tonumber(extra) <= Config.Catalog.passes.extraRow.tiles
	end
	local n = tonumber(tileId:match("^([1-9]%d?)$"))
	if not n or n > GRID * GRID then
		return false
	end
	local size = Config.Upgrades.plotSize[profile.plotLevel]
	if not size then
		return false
	end
	local col, row = (n - 1) % GRID + 1, (n - 1) // GRID + 1
	return col <= size[1] and row <= size[2]
end

function Guards.ownsTile(player, tileId, ownerId)
	if ownerId ~= nil and ownerId ~= player.UserId then
		return false
	end
	local profile = DataService.get(player)
	return profile ~= nil and Guards.tileActive(profile, tileId)
end

function Guards.ownsItem(profile, guid, userId)
	local item = profile and profile.items[guid]
	return item ~= nil and item.owner == userId and not item.locked
end

function Guards.sameServer(userId)
	return Players:GetPlayerByUserId(userId)
end

function Guards.near(player, pos, studs)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	return (root.Position - pos).Magnitude <= studs
end

function Guards.dev(player)
	return DevConfig.isAllowed(player)
end

return Guards

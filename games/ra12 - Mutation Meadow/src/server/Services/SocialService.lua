--[[
Help-watering and the friend boost (§2 SocialService; likes, visits and gifts arrive later).

Help-water (Plot:water with another player's ownerId, routed here by FarmService): the owner's growing crop skips
Config.Social.helpCut of its remaining time (not the owner's can), and both players get helpCoinsPerLevel x their
own plot level. Limits: helpsPerDay per helper (profile.social, UTC day), and each crop (ownerId:tile:plantedAt)
once per helpSameCropSec.

Friend boost: on every join and leave each player's friends in the server are recounted (IsFriendsWith, cached):
min(friendBoostEach x friends, friendBoostMax).

  SocialService.helpWater(helper, ownerId, tileId) -> ok, code
  SocialService.friendBoost(player)
  SocialService.friendsInServer(player)
  SocialService.Helped(helper, owner, tileId)        for quests (M8)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Growth)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local Guards = require(script.Parent.Parent.Net.Guards)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)

local SocialService = {
	Helped = Signal.new(),
}

local friendCache = {} -- ["lowId:highId"] = boolean
local friends = setmetatable({}, { __mode = "k" }) -- [player] = count in server
local helpedAt = {} -- ["ownerId:tile:plantedAt"] = time

local function pairKey(a, b)
	local x, y = math.min(a, b), math.max(a, b)
	return x .. ":" .. y
end

local function isFriends(a, b)
	local key = pairKey(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, result = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		if not ok then
			return false -- not cached: try again on the next recount
		end
		friendCache[key] = result == true
	end
	return friendCache[key]
end

local function recount(leaving)
	local everyone = {}
	for _, p in Players:GetPlayers() do
		if p ~= leaving then
			table.insert(everyone, p)
		end
	end
	for _, p in everyone do
		local n = 0
		for _, other in everyone do
			if other ~= p and isFriends(p, other) then
				n += 1
			end
		end
		friends[p] = n
	end
	if leaving then
		friends[leaving] = nil
	end
end

function SocialService.friendsInServer(player)
	return friends[player] or 0
end

function SocialService.friendBoost(player)
	return Growth.friendBoost(SocialService.friendsInServer(player))
end

local function resetDay(profile, day)
	if profile.social.day ~= day then
		profile.social.day = day
		profile.social.helps = 0
		profile.social.itemGifts = 0
		profile.social.liked = {}
	end
end

function SocialService.helpWater(helper, ownerId, tileId)
	local owner = Guards.sameServer(ownerId)
	if not owner or owner == helper then
		return false, "no_owner"
	end
	local helperProfile, ownerProfile = DataService.get(helper), DataService.get(owner)
	if not helperProfile or not ownerProfile then
		return false, "not_loaded"
	end
	local tile = ownerProfile.tiles[tileId]
	if not tile or Growth.ripe(tile) then
		return false, "not_growing"
	end
	local part = PlotService.tilePart(owner, tileId)
	if not part or not Guards.near(helper, part.Position, Guards.RANGE.tile) then
		return false, "too_far"
	end
	local now = Clock.now()
	resetDay(helperProfile, Clock.utcDay(now))
	if helperProfile.social.helps >= Config.Social.helpsPerDay then
		return false, "help_cap"
	end
	local key = `{ownerId}:{tileId}:{tile.plantedAt}`
	if helpedAt[key] and now - helpedAt[key] < Config.Social.helpSameCropSec then
		return false, "help_cooldown"
	end

	Growth.boostRemaining(tile, Config.Social.helpCut)
	helpedAt[key] = now
	helperProfile.social.helps += 1
	NetService.change(helper, { "social" }, helperProfile.social)
	NetService.change(owner, { "tiles", tileId }, tile)
	InventoryService.addCoins(helper, Config.Social.helpCoinsPerLevel * helperProfile.plotLevel, "help")
	InventoryService.addCoins(owner, Config.Social.helpCoinsPerLevel * ownerProfile.plotLevel, "helped")
	SocialService.Helped:Fire(helper, owner, tileId)
	return true
end

function SocialService:Start()
	Players.PlayerRemoving:Connect(recount)
end

function SocialService:OnPlayerLoaded()
	recount()
end

function SocialService:OnPlayerLeaving(player)
	recount(player)
end

-- forget old help keys now and then (they only matter for helpSameCropSec)
function SocialService.prune(now)
	for key, at in helpedAt do
		if now - at >= Config.Social.helpSameCropSec then
			helpedAt[key] = nil
		end
	end
end

return SocialService

--[[
Help-watering, the friend boost, free item and crop gifts, likes, visits and garden names (§2 SocialService).

Help-water (Plot:water with another player's ownerId, routed here by FarmService): the owner's growing crop skips
Config.Social.helpCut of its remaining time (not the owner's can), and both players get helpCoinsPerLevel x their
own plot level. Limits: helpsPerDay per helper (profile.social, UTC day), and each crop (ownerId:tile:plantedAt)
once per helpSameCropSec.

Friend boost: on every join and leave each player's friends in the server are recounted (IsFriendsWith, cached):
min(friendBoostEach x friends, friendBoostMax).

Gift:offer {targetId, item} | {targetId, crop, qty} (free, same server): the target is here and loaded, the giver
has given fewer than itemGiftsPerDay today; an item must be owned and unlocked with a free Backpack slot on the
receiver, crops need that many in the basket and room in the receiver's basket. The item is locked (crops leave
the basket), outbox[giftId] is written and saved, then GiftOffer { giftId, fromId, fromName, seed, muts?, qty?,
expiresAt } goes to the receiver. Gift:respond {giftId, accept} from the receiver: accept saves the receiver with the
item first (ItemModel.transfer), then clears the giver's outbox (item_gifted); decline, Gift:cancel from the giver
and expiry after giftOfferSec unlock and clear (gift_declined). On load each outbox entry is settled from the
receiver's stored profile: they have the item (or the giftId in giftsIn, for crops) -> it leaves the giver;
otherwise it unlocks. Robux items never move player to player.

Social:like {ownerId}: once per farm per UTC day (social.liked); the owner's social.likesReceived + 1, shown on their
plot sign (attribute Likes). Social:visit {friendId}: a friend here -> your character goes to their plot; a friend
in another server of this place (GetFriendsOnline) -> TeleportAsync with their ServerInstanceId. Visiting is
read-only (nobody can plant or harvest a plot they don't own).

Settings:gardenName {name}: TextService:FilterStringAsync, then GetNonChatStringForBroadcastAsync (pcall); on any
failure "<DisplayName>'s Garden". Shown on the mailbox (attribute GardenName).

  SocialService.helpWater(helper, ownerId, tileId) -> ok, code
  SocialService.offer(player, payload, profile) / respond(...) / cancel(...)   the Gift remote handlers
  SocialService.settleOutbox(player, profile)
  SocialService.like / visit / setGardenName     the Social and Settings remote handlers
  SocialService.offers()                         the open offers (tests)
  SocialService.friendBoost(player)
  SocialService.friendsInServer(player)
  SocialService.Helped(helper, owner, tileId)        for quests (M8)
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Growth)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local Guards = require(script.Parent.Parent.Net.Guards)
local InventoryService = require(script.Parent.InventoryService)
local ItemModel = require(script.Parent.Parent.Items.ItemModel)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local Stores = require(script.Parent.Parent.Save.Stores)
local Telemetry = require(script.Parent.Parent.Telemetry)

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

---------------------------------------------------------------------------------------------------------------
-- free item and crop gifts

local offers = {} -- [giftId] = { from = player, to = player, expiresAt }

function SocialService.offers()
	return offers
end

local function today()
	return Clock.utcDay(Clock.now())
end

local function itemsChanged(player, profile)
	NetService.change(player, { "items" }, profile.items)
	NetService.change(player, { "outbox" }, profile.outbox)
end

-- puts an open offer back with the giver (unlock / crops back to the basket) and clears it
local function unwind(giver, profile, giftId)
	local entry = profile.outbox[giftId]
	if not entry then
		return
	end
	if entry.guid and profile.items[entry.guid] then
		profile.items[entry.guid].locked = false
	elseif entry.crop then
		profile.basket[entry.crop] = (profile.basket[entry.crop] or 0) + entry.qty
		NetService.change(giver, { "basket" }, profile.basket)
	end
	profile.outbox[giftId] = nil
	itemsChanged(giver, profile)
end

local function close(giftId, reason)
	local offer = offers[giftId]
	if not offer then
		return
	end
	offers[giftId] = nil
	local profile = DataService.get(offer.from)
	if profile then
		unwind(offer.from, profile, giftId)
		DataService.save(offer.from, "gift_declined")
	end
	Telemetry.log(offer.from, "gift_declined", { giftId = giftId, reason = reason })
	NetService.toast(
		offer.from,
		"giftDeclined",
		if reason == "expired" then "Your gift wasn't taken." else "Gift declined."
	)
end

function SocialService.offer(player, payload, profile)
	local target = Guards.sameServer(payload.targetId)
	if not target or target == player then
		return false, "no_target"
	end
	local toProfile = DataService.get(target)
	if not toProfile then
		return false, "not_loaded"
	end
	resetDay(profile, today())
	if profile.social.itemGifts >= Config.Social.itemGiftsPerDay then
		return false, "gift_cap"
	end
	local entry
	local data = { fromId = player.UserId, fromName = player.DisplayName }
	if payload.item then
		local guid = payload.item
		if not Guards.ownsItem(profile, guid, player.UserId) then
			return false, "ownership"
		end
		if InventoryService.itemCount(toProfile) >= InventoryService.backpackCap(toProfile) then
			return false, "receiver_full"
		end
		local item = profile.items[guid]
		item.locked = true
		entry = { guid = guid, toId = target.UserId, at = Clock.now() }
		data.seed, data.muts = item.seed, item.muts
	else
		local crop, qty = payload.crop, payload.qty
		if (profile.basket[crop] or 0) < qty then
			return false, "not_enough"
		end
		if InventoryService.basketCount(toProfile) + qty > Config.Inventory.basketCap then
			return false, "receiver_full"
		end
		profile.basket[crop] -= qty
		if profile.basket[crop] == 0 then
			profile.basket[crop] = nil
		end
		NetService.change(player, { "basket" }, profile.basket)
		entry = { crop = crop, qty = qty, toId = target.UserId, at = Clock.now() }
		data.seed, data.qty = crop, qty
	end
	local giftId = HttpService:GenerateGUID(false)
	profile.outbox[giftId] = entry
	itemsChanged(player, profile)
	if not DataService.save(player, "gift_offer"):await() then
		unwind(player, profile, giftId)
		return false, "save_failed"
	end
	local expiresAt = Clock.now() + Config.Social.giftOfferSec
	offers[giftId] = { from = player, to = target, expiresAt = expiresAt }
	data.giftId, data.expiresAt = giftId, expiresAt
	NetService.fire(target, "GiftOffer", data)
	task.delay(Config.Social.giftOfferSec, function()
		if offers[giftId] then
			close(giftId, "expired")
		end
	end)
	return true
end

local function accept(giftId, offer)
	local giver, receiver = offer.from, offer.to
	local fromP, toP = DataService.get(giver), DataService.get(receiver)
	local entry = fromP and fromP.outbox[giftId]
	if not entry or not toP then
		return false, "gone"
	end
	if entry.guid then
		local item = fromP.items[entry.guid]
		if not item then
			return false, "gone"
		end
		if InventoryService.itemCount(toP) >= InventoryService.backpackCap(toP) then
			return false, "receiver_full"
		end
		item.locked = false
		local ok, code = ItemModel.transfer(fromP, toP, entry.guid, receiver.UserId, giver.UserId)
		if not ok then
			item.locked = true
			return false, code
		end
	else
		if InventoryService.basketCount(toP) + entry.qty > Config.Inventory.basketCap then
			return false, "receiver_full"
		end
		toP.basket[entry.crop] = (toP.basket[entry.crop] or 0) + entry.qty
	end
	table.insert(toP.giftsIn, giftId)
	while #toP.giftsIn > Config.Save.giftsInKeep do
		table.remove(toP.giftsIn, 1)
	end
	-- the receiver's save lands first: after it, the item can only belong to the receiver
	if not DataService.save(receiver, "gift_in"):await() then
		if entry.guid then
			ItemModel.transfer(toP, fromP, entry.guid, giver.UserId, receiver.UserId)
			fromP.items[entry.guid].locked = true
		else
			toP.basket[entry.crop] -= entry.qty
		end
		table.remove(toP.giftsIn, table.find(toP.giftsIn, giftId))
		return false, "save_failed"
	end
	offers[giftId] = nil
	fromP.outbox[giftId] = nil
	fromP.social.itemGifts += 1
	itemsChanged(giver, fromP)
	NetService.change(giver, { "social" }, fromP.social)
	NetService.change(receiver, { "items" }, toP.items)
	NetService.change(receiver, { "basket" }, toP.basket)
	DataService.save(giver, "gift_out")
	InventoryService.renderPedestals(giver)
	Telemetry.log(giver, "item_gifted", { giftId = giftId, toId = receiver.UserId, crop = entry.crop, qty = entry.qty })
	NetService.toast(giver, "giftAccepted", `{receiver.DisplayName} took your gift!`)
	return true
end

function SocialService.respond(player, payload)
	local offer = offers[payload.giftId]
	if not offer or offer.to ~= player then
		return false, "no_offer"
	end
	if not payload.accept then
		close(payload.giftId, "declined")
		return true
	end
	return accept(payload.giftId, offer)
end

function SocialService.cancel(player, payload)
	local offer = offers[payload.giftId]
	if not offer or offer.from ~= player then
		return false, "no_offer"
	end
	close(payload.giftId, "cancelled")
	return true
end

-- on load: each outbox entry left by a crash is settled from the receiver's stored profile
function SocialService.settleOutbox(player, profile)
	if next(profile.outbox) == nil then
		return
	end
	for _, entry in profile.outbox do
		local item = entry.guid and profile.items[entry.guid]
		if item then
			item.locked = true -- until it is settled
		end
	end
	local store = Stores.profiles()
	for giftId, entry in table.clone(profile.outbox) do
		local ok, stored = true, nil
		if store then
			ok, stored = pcall(function()
				return store:GetAsync(Stores.key(entry.toId))
			end)
		end
		if ok then
			local landed = stored ~= nil
				and (
					(entry.guid and stored.items and stored.items[entry.guid] ~= nil)
					or (stored.giftsIn and table.find(stored.giftsIn, giftId) ~= nil)
				)
			if landed then
				if entry.guid then
					profile.items[entry.guid] = nil
					ItemModel.registry[entry.guid] = nil
				end
				profile.outbox[giftId] = nil
				itemsChanged(player, profile)
			else
				unwind(player, profile, giftId)
			end
		end
	end
	InventoryService.renderPedestals(player)
end

---------------------------------------------------------------------------------------------------------------
-- likes, visits, garden names

local function showLikes(owner, profile)
	local sign = PlotService.signPart(owner)
	if sign then
		sign:SetAttribute("Likes", profile.social.likesReceived)
	end
end

function SocialService.like(player, payload, profile)
	local owner = Guards.sameServer(payload.ownerId)
	local ownerProfile = owner and DataService.get(owner)
	if not ownerProfile or owner == player then
		return false, "no_owner"
	end
	resetDay(profile, today())
	local key = tostring(payload.ownerId)
	if (profile.social.liked[key] or 0) >= Config.Social.likesPerFarmPerDay then
		return false, "liked_today"
	end
	profile.social.liked[key] = (profile.social.liked[key] or 0) + 1
	ownerProfile.social.likesReceived += 1
	NetService.change(player, { "social" }, profile.social)
	NetService.change(owner, { "social" }, ownerProfile.social)
	showLikes(owner, ownerProfile)
	return true
end

local function plotSpot(owner)
	local sign = PlotService.signPart(owner)
	local plot = PlotService.plotOf(owner)
	if sign then
		return sign.Position + Vector3.new(0, 3, -Config.Social.visitOffsetStuds)
	end
	return plot and plot:GetPivot().Position + Vector3.new(0, 3, 0)
end

function SocialService.visit(player, payload)
	local friendId = payload.friendId
	local here = Guards.sameServer(friendId)
	if here then
		if here == player or not isFriends(player, here) then
			return false, "not_friend"
		end
		local spot = plotSpot(here)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not spot or not root then
			return false, "no_plot"
		end
		player.Character:PivotTo(CFrame.new(spot))
		Telemetry.log(player, "visit", { friendId = friendId, where = "server" })
		return true
	end
	local ok, online = pcall(function()
		return player:GetFriendsOnline()
	end)
	if not ok then
		return false, "friends_failed"
	end
	for _, f in online do
		if f.VisitorId == friendId and f.PlaceId == game.PlaceId and f.GameId then
			local options = Instance.new("TeleportOptions")
			options.ServerInstanceId = f.GameId
			local sent = pcall(function()
				TeleportService:TeleportAsync(game.PlaceId, { player }, options)
			end)
			Telemetry.log(player, "visit", { friendId = friendId, where = "teleport", ok = sent })
			return sent, if sent then nil else "teleport_failed"
		end
	end
	return false, "not_here"
end

function SocialService.filterName(player, name)
	local ok, text = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(text) == "string" and text ~= "" then
		return text
	end
	return string.format(Config.Social.gardenNameFallback, player.DisplayName)
end

local function showName(player, name)
	local plot = PlotService.plotOf(player)
	local mailbox = plot and plot:FindFirstChild("Mailbox")
	if mailbox and name then
		mailbox:SetAttribute("GardenName", name)
	end
end

function SocialService.setGardenName(player, payload, profile)
	local name = SocialService.filterName(player, payload.name)
	profile.settings.gardenName = name
	NetService.change(player, { "settings" }, profile.settings)
	showName(player, name)
	return true
end

function SocialService:Init()
	NetService.on("Gift", "offer", nil, SocialService.offer)
	NetService.on("Gift", "respond", nil, SocialService.respond)
	NetService.on("Gift", "cancel", nil, SocialService.cancel)
	NetService.on("Social", "like", nil, SocialService.like)
	NetService.on("Social", "visit", nil, SocialService.visit)
	NetService.on("Settings", "gardenName", nil, SocialService.setGardenName)
end

function SocialService:Start()
	Players.PlayerRemoving:Connect(recount)
end

function SocialService:OnPlayerLoaded(player, profile)
	recount()
	showLikes(player, profile)
	showName(player, profile.settings.gardenName)
	SocialService.settleOutbox(player, profile)
end

function SocialService:OnPlayerLeaving(player)
	recount(player)
	-- open offers either way close: the giver's lock comes off, or the receiver's offer goes away
	for giftId, offer in table.clone(offers) do
		if offer.from == player or offer.to == player then
			close(giftId, "left")
		end
	end
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

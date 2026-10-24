--[[
Robux purchases (§7): game passes, the two boost products, the cosmetic products and the gift products. Nothing
sold is random, and no handler touches the Mutations, Weather or Restock config (no paid luck, tests/Policy).

Purchase:prompt {key, tile?, friendId?} validates, then calls PromptGamePassPurchase or PromptProductPurchase:
  a pass        refused when owned; the Starter Bundle also when Extra Plot Row is owned or Bundle.resolve hides it
  instantGrow   refused with nothing growing. The tile (or the crop with the longest time left) is held for 60 s.
                A banked credit (meta.growCredits) is spent instead of prompting.
  growAll       refused with nothing growing
  a cosmetic    refused when owned
  gift_<key>    the friend must pass IsFriendsWith; refused when they are in this server and own it already. The
                target gets its own slot in meta.pendingGifts (a list of { key, friendId, at }, oldest first, at
                most PENDING_GIFTS_MAX: a full list drops its oldest) and is saved before the prompt. A prompt
                closed without buying (PromptProductPurchaseFinished false) frees the newest slot for that key.
                A save from before this still holding meta.pendingGift moves it into the list.

Receipts (Receipts.process: saved with the PurchaseId, rolled back on any error):
  instantGrow   ripens the held tile if it is still growing, else the crop with the longest time left; with nothing
                growing at receipt time, meta.growCredits += 1
  growAll       every growing crop on the plot and the extra bed ripens
  a cosmetic    cosmetics.owned[key] = true
  gift_<key>    takes the oldest slot for that key (none: an error, so it never grants without a target); the
                friend in this server gets it now (and is saved); otherwise GiftQueue.enqueue
Each grant logs purchase { key, robux }.

Game passes grant live on PromptGamePassPurchaseFinished(true): Extra Plot Row shows its bed at once, the Starter
Bundle runs Bundle.grant. Player attributes tell clients what the store needs: Pass_<key> (owned), BundleOffer
(JSON { grants, value }, nil when hidden), Subscriber, and Cosmetics (the owned cosmetic keys, comma-separated, so
a friend's Gift tab can hide what they already have).

  PurchaseService.prompt(player, payload, profile)     the remote handler (tests)
  PurchaseService.HANDLERS                             [productKey] = receipt handler
  PurchaseService.applyPass(player, key)
  PurchaseService.refresh(player)                      re-sends the store attributes
  PurchaseService.PENDING_SEC / PENDING_GIFTS_MAX
  PurchaseService.giftSlots(profile)                   meta.pendingGifts (moving an old meta.pendingGift in)
]]
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Growth = require(ReplicatedStorage.Shared.Growth)

local Bundle = require(script.Parent.Parent.Purchase.Bundle)
local Cosmetics = require(script.Parent.Parent.Purchase.Cosmetics)
local DataService = require(script.Parent.DataService)
local FarmService = require(script.Parent.FarmService)
local GiftQueue = require(script.Parent.Parent.Save.GiftQueue)
local NetService = require(script.Parent.NetService)
local PlotService = require(script.Parent.PlotService)
local PolicyGate = require(script.Parent.PolicyGate)
local Purchase = require(script.Parent.Parent.Purchase)
local Receipts = require(script.Parent.Parent.Save.Receipts)
local Telemetry = require(script.Parent.Parent.Telemetry)

local PurchaseService = {}

PurchaseService.PENDING_SEC = 60
PurchaseService.PENDING_GIFTS_MAX = 10

local pendingGrow = setmetatable({}, { __mode = "k" }) -- [player] = { tile, at }

local function itemOf(key)
	local C = Config.Catalog
	return C.passes[key] or C.products[key] or C.cosmetics[key] or C.gifts[key]
end

local function logPurchase(player, key)
	local item = itemOf(key)
	Telemetry.log(player, "purchase", { key = key, robux = item and item.robux or 0 })
end

---------------------------------------------------------------------------------------------------------------
-- growing crops

local function growing(profile)
	local out = {}
	for id, tile in profile.tiles do
		if not Growth.ripe(tile) then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

local function longest(profile)
	local best, left
	for _, id in growing(profile) do
		local tile = profile.tiles[id]
		local l = Growth.growSec(tile) - tile.grown
		if not best or l > left then
			best, left = id, l
		end
	end
	return best
end

local function ripen(player, profile, id)
	local tile = profile.tiles[id]
	tile.grown = Growth.growSec(tile)
	NetService.change(player, { "tiles", id }, tile)
	FarmService.render(player, id)
end

---------------------------------------------------------------------------------------------------------------
-- the store attributes

function PurchaseService.refresh(player)
	for key in Config.Catalog.passes do
		player:SetAttribute("Pass_" .. key, Purchase.owns(player, key) or nil)
	end
	local offer = Bundle.resolve(player)
	player:SetAttribute("BundleOffer", offer and HttpService:JSONEncode(offer) or nil)
	player:SetAttribute("Subscriber", PolicyGate.hasSubscription(player) or nil)
	local owned = {}
	for key in Config.Catalog.cosmetics do
		if Purchase.owns(player, key) then
			table.insert(owned, key)
		end
	end
	table.sort(owned)
	player:SetAttribute("Cosmetics", table.concat(owned, ","))
end

function PurchaseService.applyPass(player, key)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	if key == "starterBundle" then
		Bundle.grant(player, profile)
		NetService.change(player, { "cosmetics" }, profile.cosmetics)
		NetService.change(player, { "meta" }, profile.meta)
	end
	if key == "extraRow" or key == "starterBundle" then
		PlotService.refresh(player)
	end
	Cosmetics.render(player)
	PurchaseService.refresh(player)
end

---------------------------------------------------------------------------------------------------------------
-- prompts

local function friendOf(player, friendId)
	if type(friendId) ~= "number" or friendId == player.UserId then
		return false
	end
	local ok, yes = pcall(function()
		return player:IsFriendsWith(friendId)
	end)
	return ok and yes == true
end

local function promptPass(player, key, pass)
	if Purchase.owns(player, key) then
		return false, "owned"
	end
	if key == "starterBundle" and not Bundle.resolve(player) then
		return false, "hidden"
	end
	if pass.id == 0 then
		return false, "not_created"
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
	return true
end

local function promptProduct(player, item)
	if item.id == 0 then
		return false, "not_created"
	end
	MarketplaceService:PromptProductPurchase(player, item.id)
	return true
end

local function promptGrow(player, key, item, payload, profile)
	local list = growing(profile)
	if #list == 0 then
		return false, "nothing_growing"
	end
	if key == "growAll" then
		return promptProduct(player, item)
	end
	local tile = payload.tile
	if not (tile and profile.tiles[tile] and not Growth.ripe(profile.tiles[tile])) then
		tile = longest(profile)
	end
	if profile.meta.growCredits > 0 then
		profile.meta.growCredits -= 1
		ripen(player, profile, tile)
		NetService.change(player, { "meta" }, profile.meta)
		return true, "credit"
	end
	pendingGrow[player] = { tile = tile, at = Clock.now() }
	return promptProduct(player, item)
end

function PurchaseService.giftSlots(profile)
	local meta = profile.meta
	meta.pendingGifts = meta.pendingGifts or {}
	if meta.pendingGift then
		table.insert(meta.pendingGifts, 1, meta.pendingGift)
		meta.pendingGift = nil
	end
	return meta.pendingGifts
end

local function promptGift(player, key, gift, payload, profile)
	local friendId = payload.friendId
	if not friendOf(player, friendId) then
		return false, "not_friend"
	end
	local friend = Players:GetPlayerByUserId(friendId)
	if friend and Purchase.owns(friend, gift.of) then
		return false, "owned"
	end
	if gift.id == 0 then
		return false, "not_created"
	end
	local slots = PurchaseService.giftSlots(profile)
	table.insert(slots, { key = key, friendId = friendId, at = Clock.now() })
	while #slots > PurchaseService.PENDING_GIFTS_MAX do
		table.remove(slots, 1)
	end
	if not DataService.save(player, "pendingGift"):await() then
		return false, "save_failed"
	end
	MarketplaceService:PromptProductPurchase(player, gift.id)
	return true
end

function PurchaseService.prompt(player, payload, profile)
	local key = payload.key
	local C = Config.Catalog
	if C.passes[key] then
		return promptPass(player, key, C.passes[key])
	elseif C.products[key] then
		return promptGrow(player, key, C.products[key], payload, profile)
	elseif C.cosmetics[key] then
		if Purchase.owns(player, key) then
			return false, "owned"
		end
		return promptProduct(player, C.cosmetics[key])
	elseif C.gifts[key] then
		return promptGift(player, key, C.gifts[key], payload, profile)
	end
	return false, "unknown"
end

---------------------------------------------------------------------------------------------------------------
-- receipt handlers

local HANDLERS = {}
PurchaseService.HANDLERS = HANDLERS

function HANDLERS.instantGrow(player, profile)
	local held = pendingGrow[player]
	pendingGrow[player] = nil
	local tile
	if held and Clock.now() - held.at <= PurchaseService.PENDING_SEC then
		local t = profile.tiles[held.tile]
		if t and not Growth.ripe(t) then
			tile = held.tile
		end
	end
	tile = tile or longest(profile)
	if tile then
		ripen(player, profile, tile)
	else
		profile.meta.growCredits += 1
		NetService.change(player, { "meta" }, profile.meta)
	end
	logPurchase(player, "instantGrow")
end

function HANDLERS.growAll(player, profile)
	for _, id in growing(profile) do
		ripen(player, profile, id)
	end
	logPurchase(player, "growAll")
end

for key in Config.Catalog.cosmetics do
	HANDLERS[key] = function(player, profile)
		profile.cosmetics.owned[key] = true
		NetService.change(player, { "cosmetics" }, profile.cosmetics)
		PurchaseService.refresh(player)
		logPurchase(player, key)
	end
end

local function giverName(player)
	return player.DisplayName
end

local function landGift(friend, key, fromName)
	local item = Config.Catalog.passes[key] or Config.Catalog.cosmetics[key]
	NetService.toast(
		friend,
		"gift",
		string.format(Config.Catalog.giftToast, fromName, item and item.name or key),
		{ key = key, from = fromName, button = Config.Catalog.giftBackButton }
	)
	if Config.Catalog.passes[key] then
		PurchaseService.applyPass(friend, key)
	end
	local profile = DataService.get(friend)
	if profile then
		NetService.change(friend, { "cosmetics" }, profile.cosmetics)
		NetService.change(friend, { "passes" }, profile.passes)
	end
	PurchaseService.refresh(friend)
end

for giftKey, gift in Config.Catalog.gifts do
	HANDLERS[giftKey] = function(player, profile, receipt)
		local slots = PurchaseService.giftSlots(profile)
		local slot
		for i, s in slots do
			if s.key == giftKey then
				slot = i
				break
			end
		end
		if not slot then
			error(`no pending target for {giftKey}`)
		end
		local pending = slots[slot]
		local friend = Players:GetPlayerByUserId(pending.friendId)
		local friendProfile = friend and DataService.get(friend)
		if friendProfile then
			if not table.find(friendProfile.giftsIn, receipt.PurchaseId) then
				GiftQueue.apply(friendProfile, gift.of)
				table.insert(friendProfile.giftsIn, receipt.PurchaseId)
				while #friendProfile.giftsIn > Config.Save.giftsInKeep do
					table.remove(friendProfile.giftsIn, 1)
				end
				DataService.save(friend, "gift")
				landGift(friend, gift.of, giverName(player))
			end
		else
			local queued = GiftQueue.enqueue(pending.friendId, {
				purchaseId = receipt.PurchaseId,
				key = gift.of,
				fromId = player.UserId,
				at = Clock.now(),
			})
			if not queued then
				error("the gift queue refused it")
			end
		end
		table.remove(slots, slot)
		logPurchase(player, giftKey)
	end
end

---------------------------------------------------------------------------------------------------------------

function PurchaseService:Init()
	MarketplaceService.ProcessReceipt = function(receipt)
		return Receipts.process(receipt, HANDLERS)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = purchased and Purchase.passKeyFor(passId)
		if key then
			Purchase.grantLive(player, key)
			logPurchase(player, key)
			PurchaseService.applyPass(player, key)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		local player = if typeof(userId) == "Instance" then userId else Players:GetPlayerByUserId(userId)
		local profile = player and not purchased and DataService.get(player)
		if not profile then
			return
		end
		local slots = PurchaseService.giftSlots(profile)
		for i = #slots, 1, -1 do
			local gift = Config.Catalog.gifts[slots[i].key]
			if gift and gift.id == productId then
				table.remove(slots, i) -- closed without buying: free the newest slot for it
				return
			end
		end
	end)
	GiftQueue.Applied:Connect(function(player, key, fromId)
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(fromId)
		end)
		landGift(player, key, if ok then name else "A friend")
	end)
	NetService.on("Purchase", "prompt", nil, PurchaseService.prompt)
	NetService.on("Cosmetic", "equip", nil, Cosmetics.equip)
end

function PurchaseService:OnPlayerLoaded(player, profile)
	Purchase.loadPasses(player)
	if Purchase.owns(player, "starterBundle") then
		Bundle.grant(player, profile)
		NetService.change(player, { "cosmetics" }, profile.cosmetics)
	end
	PlotService.refresh(player)
	PurchaseService.refresh(player)
	Cosmetics.render(player)
	player.CharacterAdded:Connect(function()
		task.defer(Cosmetics.render, player)
	end)
end

function PurchaseService:OnPlayerLeaving(player)
	Purchase.forget(player)
	pendingGrow[player] = nil
end

return PurchaseService

--[[
Robux gifts waiting for their recipient, in MM_Gifts_v1 under "u_<recipientId>" as
{ gifts = { { purchaseId, key, fromId, at } } } (at most Config.Save.giftQueueMax).

  GiftQueue.enqueue(recipientId, gift) -> boolean   appends unless that purchaseId is already queued (true either
                                       way); false when the store fails, the queue is full or there are no stores
  GiftQueue.drain(player, profile)     on Loaded: applies every queued gift not yet in profile.giftsIn, saves the
                                       profile, and only once that save lands removes the applied gifts from the
                                       queue. A crash in between leaves them queued, and giftsIn stops a second grant.
  GiftQueue.apply(profile, key)        grants one gift: a pass key sets passes[key], a cosmetic sets
                                       cosmetics.owned[key]
  GiftQueue.Applied(player, key, fromId)   after drain applied one (PurchaseService toasts and redraws)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)
local SaveQueue = require(script.Parent.SaveQueue)
local Stores = require(script.Parent.Stores)

local GiftQueue = {
	Applied = Signal.new(),
}

function GiftQueue.enqueue(recipientId, gift)
	local store = Stores.gifts()
	if not store then
		return false
	end
	local full = false
	local ok, err = pcall(function()
		store:UpdateAsync(Stores.key(recipientId), function(old)
			full = false
			old = old or {}
			old.gifts = old.gifts or {}
			for _, g in old.gifts do
				if g.purchaseId == gift.purchaseId then
					return nil -- already queued
				end
			end
			if #old.gifts >= Config.Save.giftQueueMax then
				full = true
				return nil
			end
			table.insert(
				old.gifts,
				{ purchaseId = gift.purchaseId, key = gift.key, fromId = gift.fromId, at = gift.at }
			)
			return old
		end)
	end)
	if not ok then
		warn(`[GiftQueue] enqueue for {recipientId} failed: {err}`)
		return false
	end
	if full then
		warn(`[GiftQueue] queue for {recipientId} is full`)
	end
	return not full
end

function GiftQueue.apply(profile, key)
	if Config.Catalog.passes[key] then
		profile.passes[key] = true
	elseif Config.Catalog.cosmetics[key] then
		profile.cosmetics.owned[key] = true
	else
		warn(`[GiftQueue] unknown gift key {key}`)
		return false
	end
	return true
end

function GiftQueue.drain(player, profile)
	local store = Stores.gifts()
	if not store then
		return false
	end
	local key = Stores.key(player.UserId)
	local ok, data = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok then
		warn(`[GiftQueue] read for {player.UserId} failed: {data}`)
		return false
	end
	if not data or not data.gifts or #data.gifts == 0 then
		return true
	end

	local applied = 0
	local fresh = {}
	for _, gift in data.gifts do
		if not table.find(profile.giftsIn, gift.purchaseId) then
			GiftQueue.apply(profile, gift.key)
			table.insert(profile.giftsIn, gift.purchaseId)
			while #profile.giftsIn > Config.Save.giftsInKeep do
				table.remove(profile.giftsIn, 1)
			end
			applied += 1
			table.insert(fresh, gift)
		end
	end
	for _, gift in fresh do
		GiftQueue.Applied:Fire(player, gift.key, gift.fromId)
	end
	if applied > 0 and not SaveQueue.request(key, "gifts"):await() then
		return false -- the queue keeps them; giftsIn decides on the next join
	end

	local removed, err = pcall(function()
		store:UpdateAsync(key, function(old)
			if not old or not old.gifts then
				return nil
			end
			local keep = {}
			for _, gift in old.gifts do
				if not table.find(profile.giftsIn, gift.purchaseId) then
					table.insert(keep, gift)
				end
			end
			if #keep == #old.gifts then
				return nil
			end
			old.gifts = keep
			return old
		end)
	end)
	if not removed then
		warn(`[GiftQueue] clearing the queue for {player.UserId} failed: {err}`)
	end
	return removed
end

return GiftQueue

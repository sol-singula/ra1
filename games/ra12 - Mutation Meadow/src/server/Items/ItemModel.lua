--[[
Kept crops ("items"): each has a server-made GUID, an owner and a lock, so items can move between players
without ever being in two places.

  ItemModel.registry                    [guid] = userId for every item of every loaded player on this server
  ItemModel.mint(profile, userId, seed, muts)        -> guid, item (server only)
  ItemModel.transfer(fromP, toP, guid, toId, fromId?) -> true | false, reason; the item must be unlocked and owned
                                        by the sender (fromId when given, and the registry when it knows the guid)
  ItemModel.validate(profile, userId)   on load: drops every item that fails a check (returns { guid, reason }
                                        for each), then recomputes locks (locked = on a pedestal) and clears
                                        pedestal slots whose item is gone
  ItemModel.register / unregister(profile, userId)   adds / removes a loaded profile's items in the registry
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local NetSchema = require(ReplicatedStorage.Shared.NetSchema)

local ItemModel = {}

ItemModel.GUID_PATTERN = NetSchema.GUID_PATTERN
ItemModel.registry = {}

function ItemModel.mint(profile, userId, seed, muts)
	assert(RunService:IsServer(), "ItemModel.mint is server-only")
	assert(Config.Seeds[seed], `ItemModel.mint: unknown seed {seed}`)
	local guid = HttpService:GenerateGUID(false)
	local item = {
		seed = seed,
		muts = { wet = muts and muts.wet or nil, golden = muts and muts.golden or nil },
		foundAt = Clock.now(),
		foundBy = userId,
		owner = userId,
		locked = false,
	}
	profile.items[guid] = item
	ItemModel.registry[guid] = userId
	return guid, item
end

function ItemModel.transfer(fromP, toP, guid, toId, fromId)
	local item = fromP.items[guid]
	if not item then
		return false, "missing"
	end
	if item.locked then
		return false, "locked"
	end
	if fromId ~= nil and item.owner ~= fromId then
		return false, "wrong_owner"
	end
	local known = ItemModel.registry[guid]
	if known ~= nil and known ~= item.owner then
		return false, "wrong_owner"
	end
	if item.owner == toId then
		return false, "same_owner"
	end
	if toP.items[guid] ~= nil then
		return false, "exists"
	end
	fromP.items[guid] = nil
	item.giftedBy = item.owner
	item.owner = toId
	toP.items[guid] = item
	if known ~= nil then
		ItemModel.registry[guid] = toId
	end
	return true
end

local function check(guid, item, userId)
	if type(guid) ~= "string" or not guid:match(ItemModel.GUID_PATTERN) then
		return "bad_guid"
	end
	if type(item) ~= "table" or item.owner ~= userId then
		return "wrong_owner"
	end
	if type(item.seed) ~= "string" or Config.Seeds[item.seed] == nil then
		return "bad_seed"
	end
	local holder = ItemModel.registry[guid]
	if holder ~= nil and holder ~= userId then
		return "dupe_guid"
	end
	return nil
end

function ItemModel.validate(profile, userId)
	local dropped = {}
	for guid, item in profile.items do
		local reason = check(guid, item, userId)
		if reason then
			table.insert(dropped, { guid = guid, reason = reason })
		end
	end
	for _, d in dropped do
		profile.items[d.guid] = nil
		warn(`[ItemModel] dropped item {d.guid} of {userId}: {d.reason}`)
	end
	-- a pending-gift lock never survives a restart (M9 resolves the outbox); only pedestals lock
	for _, item in profile.items do
		item.locked = false
	end
	for slot, guid in table.clone(profile.pedestals) do
		local item = profile.items[guid]
		if item then
			item.locked = true
		else
			profile.pedestals[slot] = nil
		end
	end
	return dropped
end

function ItemModel.register(profile, userId)
	for guid in profile.items do
		ItemModel.registry[guid] = userId
	end
end

function ItemModel.unregister(profile, userId)
	for guid in profile.items do
		if ItemModel.registry[guid] == userId then
			ItemModel.registry[guid] = nil
		end
	end
end

return ItemModel

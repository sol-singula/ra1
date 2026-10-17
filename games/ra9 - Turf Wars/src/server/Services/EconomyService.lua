--[[
The wallet and the bought things: Shards (◆), the cosmetics bought or claimed (profile.owned), and the Robux
receipts already granted (so a receipt is never granted twice). Only data: the services that call it push the
profile to the client after (ShopService, ProgressService).

  EconomyService:Shards(player)
  EconomyService:Add(player, n, why)        earned or bought; returns the new balance
  EconomyService:Spend(player, n) -> ok     never below zero
  EconomyService:Give(player, key) -> new   a cosmetic into profile.owned
  EconomyService:Receipt(player, id) -> seen   remembers a receipt id; true if it was already granted
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Signal = require(ReplicatedStorage.Shared.Signal)

local EconomyService = {
	Name = "EconomyService",
	Dependencies = { "PlayerDataService" },
	Changed = Signal.new("EconomyService.Changed"), -- (player, shards, delta, why)
}

local data
local RECEIPTS_KEPT = 100

function EconomyService:Shards(player)
	local p = data:Get(player)
	return p and p.shards or 0
end

function EconomyService:Add(player, n, why)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n <= 0 then
		return p and p.shards or 0
	end
	n = math.floor(n)
	p.shards = (p.shards or 0) + n
	p.stats.shardsEarned = (p.stats.shardsEarned or 0) + n
	self.Changed:Fire(player, p.shards, n, why)
	-- (the +N on their screen, flying into the Shards counter)
	Net.fire(player, "Earned", { amount = n, why = why, total = p.shards })
	return p.shards
end

function EconomyService:Spend(player, n)
	local p = data:Get(player)
	if not p or type(n) ~= "number" or n < 0 or (p.shards or 0) < n then
		return false
	end
	p.shards -= n
	p.stats.shardsSpent = (p.stats.shardsSpent or 0) + n
	self.Changed:Fire(player, p.shards, -n, "spend")
	return true
end

function EconomyService:Give(player, key)
	local p = data:Get(player)
	if not p then
		return false
	end
	p.owned = p.owned or {}
	if p.owned[key] then
		return false
	end
	p.owned[key] = true
	return true
end

function EconomyService:Receipt(player, id)
	local p = data:Get(player)
	if not p then
		return false
	end
	p.receipts = p.receipts or {}
	if table.find(p.receipts, id) then
		return true
	end
	table.insert(p.receipts, id)
	while #p.receipts > RECEIPTS_KEPT do
		table.remove(p.receipts, 1)
	end
	return false
end

function EconomyService:Init(registry)
	data = registry.PlayerDataService
end

return EconomyService

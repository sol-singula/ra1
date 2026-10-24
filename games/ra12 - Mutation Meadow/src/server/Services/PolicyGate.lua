--[[
Per-player PolicyService rules (§8). GetPolicyInfoForPlayerAsync on join in a pcall (3 tries), cached for the
session. On failure, or before the read lands, the most restrictive policy applies. ArePaidRandomItemsRestricted is
logged; nothing paid is random, so it changes nothing today. v1 has no external links.

hasSubscription covers the doc's "HasRobloxSubscription", which is not a verified API: one pcall-wrapped read that
is false on any error. True lets the player equip the subscriber can (Config.Catalog.subscriberPerk).

  PolicyGate.RESTRICTIVE
  PolicyGate.get(player) -> policy
  PolicyGate.load(player)            the join-time read (yields)
  PolicyGate.hasSubscription(player) -> boolean
]]
local PolicyService = game:GetService("PolicyService")

local Telemetry = require(script.Parent.Parent.Telemetry)

local PolicyGate = {}

local TRIES = 3

PolicyGate.RESTRICTIVE = table.freeze({
	ArePaidRandomItemsRestricted = true,
	IsPaidItemTradingAllowed = false,
	AllowedExternalLinkReferences = table.freeze({}),
})

local cache = setmetatable({}, { __mode = "k" })

function PolicyGate.load(player)
	for _ = 1, TRIES do
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		if ok and type(info) == "table" then
			cache[player] = info
			Telemetry.log(player, "policy", { paidRandomRestricted = info.ArePaidRandomItemsRestricted == true })
			return info
		end
	end
	cache[player] = PolicyGate.RESTRICTIVE
	Telemetry.log(player, "policy", { paidRandomRestricted = true, failed = true })
	return PolicyGate.RESTRICTIVE
end

function PolicyGate.get(player)
	return cache[player] or PolicyGate.RESTRICTIVE
end

-- the unverified read: swap the body once Roblox documents the real API
function PolicyGate.subscriptionCheck(player)
	return player.HasRobloxSubscription == true
end

function PolicyGate.hasSubscription(player)
	local ok, result = pcall(PolicyGate.subscriptionCheck, player)
	return ok and result == true
end

function PolicyGate:OnPlayerLoaded(player)
	PolicyGate.load(player)
end

return PolicyGate

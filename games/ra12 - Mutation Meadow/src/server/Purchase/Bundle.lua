--[[
The Starter Bundle (§7, with the Personal Marketing hide rule): Extra Plot Row plus Pumpkin Watering Can and Sprout
Buddy. It is hidden only when the player owns Extra Plot Row. A cosmetic grant the player already owns is swapped
for an unowned substitute (Config.Catalog.passes.starterBundle.substitutes): the cheapest one worth at least as
much (equal value first, ties in list order), owned grants taken from the most valuable down. With no substitute
left for an owned grant the bundle is hidden, so it never grants less than its listed value.

The bundle is a game pass, so grant() is its receipt path: on PromptGamePassPurchaseFinished(true) and on every join
while it is owned. The first grant saves the resolved list in meta.bundleGrants; later joins re-grant from it, so
substitutions never shift.

  Bundle.resolveWith(owns) -> { grants, value } | nil      pure: owns(key) -> boolean says what is owned
  Bundle.resolve(player)   -> { grants, value } | nil      nil = hidden
  Bundle.valueOf(key)      the Robux value of a grant (a pass or a cosmetic)
  Bundle.grant(player, profile) -> grants
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Purchase = require(script.Parent)

local Bundle = {}

function Bundle.valueOf(key)
	local item = Config.Catalog.passes[key] or Config.Catalog.cosmetics[key]
	return item and item.robux or 0
end

-- ignoreHide: resolve even when Extra Plot Row is owned (a bundle bought outside the game)
function Bundle.resolveWith(owns, ignoreHide)
	local cfg = Config.Catalog.passes.starterBundle
	if not ignoreHide and owns(cfg.hideIfOwns) then
		return nil
	end
	local grants = table.clone(cfg.grants)
	local taken = {}
	local owned = {}
	for i, key in grants do
		if Config.Catalog.cosmetics[key] and owns(key) then
			table.insert(owned, i)
		else
			taken[key] = true
		end
	end
	table.sort(owned, function(a, b)
		local va, vb = Bundle.valueOf(grants[a]), Bundle.valueOf(grants[b])
		if va ~= vb then
			return va > vb
		end
		return a < b
	end)
	for _, i in owned do
		local need = Bundle.valueOf(grants[i])
		local best
		for _, sub in cfg.substitutes do
			local v = Bundle.valueOf(sub)
			if not taken[sub] and not owns(sub) and v >= need and (not best or v < Bundle.valueOf(best)) then
				best = sub
			end
		end
		if not best then
			if ignoreHide then
				taken[grants[i]] = true -- nothing left to swap in: keep it (already owned, so a no-op)
				continue
			end
			return nil
		end
		taken[best] = true
		grants[i] = best
	end
	local value = 0
	for _, key in grants do
		value += Bundle.valueOf(key)
	end
	return { grants = grants, value = value }
end

function Bundle.resolve(player, ignoreHide)
	return Bundle.resolveWith(function(key)
		return Purchase.owns(player, key)
	end, ignoreHide)
end

function Bundle.grant(player, profile)
	if profile.meta.bundleGrants == nil then
		local resolved = Bundle.resolve(player, true)
		profile.meta.bundleGrants = resolved.grants
	end
	for _, key in profile.meta.bundleGrants do
		if Config.Catalog.cosmetics[key] then
			profile.cosmetics.owned[key] = true
		end
	end
	return profile.meta.bundleGrants
end

return Bundle

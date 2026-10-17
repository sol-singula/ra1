--[[
The lobby's Crate (CrateService rolls, CrateController shows it): one spin for Shards (Shop.CRATE.shards) or for
Robux (Shop.CRATE, a developer product, as often as you like), and out comes a random cosmetic from the pool: every
shop cosmetic that's a sword skin, a bow, a trail, a kill effect or a banner (never a title, never a Robux-only
one). The odds are by rarity and published on the crate. While the pool holds something you don't own you never
get a duplicate (the rarity is rolled over the rarities you still have something to win in, at the same odds
between them); once you own it all a spin gives back half its Shards. Cosmetic, all of it (master plan §1).

  Crate.ANCHOR            where it stands in the lobby (LobbyBuilder's crate stand), Crate.STAND its stand's height
  Crate.pool              every key in it         Crate.byRarity[r]   the pool's keys of that rarity
  Crate.roll(rng, owns)   -> key, dup             rng: a Random; owns(key) -> bool
  Crate.refund()          the Shards back for a duplicate
  Crate.oddsLine()        "COMMON 55% · RARE 30% · EPIC 12% · LEGENDARY 3%"
]]
local Cosmetics = require(script.Parent.Cosmetics)
local Shop = require(script.Parent.Shop)

local Crate = {}

Crate.ANCHOR = Vector3.new(60, 0, 60) -- (the lobby's crate stand: a raised stand with a CRATE sign)
Crate.STAND = 2 -- studs: the stand's top, where the crate sits
Crate.PRICE = Shop.CRATE.shards
Crate.PRODUCT = Shop.CRATE
Crate.ODDS = { common = 55, rare = 30, epic = 12, legendary = 3 } -- (per 100)
Crate.REFUND = 0.5 -- of the Shards price, back for a duplicate
Crate.KINDS = { "sword", "skin", "trail", "effect", "banner" }

Crate.pool = {}
Crate.byRarity = {}
for _, r in Cosmetics.RARITIES do
	Crate.byRarity[r] = {}
end
for _, kind in Crate.KINDS do
	for _, it in Cosmetics.list do
		if it.source == "shop" and it.kind == kind then
			table.insert(Crate.pool, it.key)
			table.insert(Crate.byRarity[it.rarity], it.key)
		end
	end
end

function Crate.refund()
	return math.floor(Crate.PRICE * Crate.REFUND)
end

function Crate.oddsLine()
	local parts = {}
	for _, r in Cosmetics.RARITIES do
		table.insert(parts, `{string.upper(r)} {Crate.ODDS[r]}%`)
	end
	return table.concat(parts, " · ")
end

-- A rarity at the odds, among those in `open` (nil: all of them)
local function rarity(rng, open)
	local total = 0
	for _, r in Cosmetics.RARITIES do
		if not open or open[r] then
			total += Crate.ODDS[r]
		end
	end
	local x = rng:NextNumber() * total
	local last
	for _, r in Cosmetics.RARITIES do
		if not open or open[r] then
			last = r
			x -= Crate.ODDS[r]
			if x <= 0 then
				return r
			end
		end
	end
	return last
end

function Crate.roll(rng, owns)
	local open, any = {}, false
	for _, r in Cosmetics.RARITIES do
		local list = {}
		for _, k in Crate.byRarity[r] do
			if not (owns and owns(k)) then
				table.insert(list, k)
			end
		end
		if #list > 0 then
			open[r] = list
			any = true
		end
	end
	if not any then
		-- (it's all theirs: a duplicate at the plain odds)
		local list = Crate.byRarity[rarity(rng, nil)]
		return list[rng:NextInteger(1, #list)], true
	end
	local list = open[rarity(rng, open)]
	return list[rng:NextInteger(1, #list)], false
end

return Crate

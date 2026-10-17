--[[
Free gifts to get new players into the shop (the end of every match, as the end screen): until they've bought
something (any Robux purchase, or a Shards buy in the shop), each match they played ends with a free cosmetic from
the shop's pool (Data/Cosmetics source "shop", never a Robux-only one), NOT worn: the card's EQUIP IT opens the
locker on it, so they learn where it lives and how to wear it.

  The kinds go round: trail, kill effect, bow, banner, skipping a kind they've already worn a gift of. Cheaper ones
  first (common, rare), an epic now and then (the 3rd and the 5th). Up to Constants.GIFT_MAX, and it stops once
  they've worn a gift of each of trail, effect and bow, or bought anything.
  After the gifts, until they've bought: a first-buy offer each match instead (GiftService:Offer: the day's 70% off
  deal, the TNT, the Starter Pack, in turn).
  After they've bought: a "NEW IN THE SHOP" end card Constants.GIFT_NUDGES more times, then nothing.

The first live match ever (never the tutorial's practice) ends differently, once: instead of the end card the shop
opens by itself on today's deal and the TNT, pointing at the Shards that match paid (Net "Gift" { firstShop = true,
shards }: PanelController.firstMatch). The free gifts start from the next match. FeedbackService holds its question
that time, so nothing lands on the shop.

Kept in the profile (profile.gifts): n (given), keys (what), wore ({ [kind] = true }), bought, nudges, firstShop
(the first match's shop shown).

  GiftService:Give(player)        -> the item given (or nil); sends Net "Gift"
  GiftService:Done(player)        -> true when no more gifts come
  GiftService:FirstShopDue(player) -> true when this match's end is their first live one (the shop, not a card)
  GiftService.Gifted              (player, item, n)
  GiftService.Worn                (player, kind, key) a gift worn from the locker
  GiftService.FirstShop           (player, shards) the first match's shop opened for them
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local GiftService = {
	Name = "GiftService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = {
		"PlayerDataService",
		"ProgressService",
		"ShopService",
		"MatchService",
		"TeamService",
		"EconomyService",
	},
	Gifted = Signal.new("GiftService.Gifted"),
	Worn = Signal.new("GiftService.Worn"),
	FirstShop = Signal.new("GiftService.FirstShop"),
}

local data, progress, shop, match, teams, economy
local paid = {} -- [player] = the Shards this match has paid them (what the first match's shop points at)
local PAID = { kill = true, headshot = true, match = true, win = true, mvp = true } -- (EconomyService's whys a match pays)

local ORDER = { "trail", "effect", "skin", "banner" }
local NEEDED = { "trail", "effect", "skin" } -- (worn one of each: they've learnt the locker)

local function giftsOf(player)
	local p = data:Get(player)
	if not p then
		return nil, nil
	end
	p.gifts = p.gifts or {}
	local g = p.gifts
	g.n = g.n or 0
	g.keys = g.keys or {}
	g.wore = g.wore or {}
	g.nudges = g.nudges or 0
	g.firstShop = g.firstShop == true
	return g, p
end

local function bought(p, g)
	return g.bought == true or (p.stats and (p.stats.robux or 0) > 0) or p.starter == true
end

function GiftService:Done(player)
	local g, p = giftsOf(player)
	if not g then
		return true
	end
	if bought(p, g) or g.n >= Constants.GIFT_MAX then
		return true
	end
	for _, k in NEEDED do
		if not g.wore[k] then
			return false
		end
	end
	return true
end

-- Their first live match just ended (its stats are in: it's the only match counted) and its shop hasn't been shown
-- yet. Never in the practice (the tutorial's has no team and no stats; nor while they're back in it).
function GiftService:FirstShopDue(player)
	local g, p = giftsOf(player)
	if not g or g.firstShop or player:GetAttribute("Practice") == true then
		return false
	end
	return p.stats ~= nil and p.stats.matches == 1
end

-- The kind for the n-th gift: round the order from n, the first not worn yet
local function kindFor(g)
	for i = 0, #ORDER - 1 do
		local k = ORDER[(g.n + i) % #ORDER + 1]
		if not g.wore[k] then
			return k
		end
	end
	return ORDER[g.n % #ORDER + 1]
end

-- A shop item of this kind they don't have: commons and rares, an epic on the 3rd and 5th gift
local function pick(player, p, g, kind)
	local epic = g.n == 2 or g.n == 4
	local want = epic and { epic = true } or { common = true, rare = true }
	local pool, fallback = {}, {}
	for _, it in Cosmetics.list do
		if it.source == "shop" and it.kind == kind and not Locker.owns(p, it.key) then
			if want[it.rarity] then
				table.insert(pool, it)
			elseif it.rarity ~= "legendary" then
				table.insert(fallback, it)
			end
		end
	end
	if #pool == 0 then
		pool = fallback
	end
	if #pool == 0 then
		return nil
	end
	local rng = Random.new(player.UserId * 31 + g.n)
	return pool[rng:NextInteger(1, #pool)]
end

-- The end screen's first-buy offer, round the ones that apply: the day's deal (while its hour runs), the TNT (not
-- bought yet), the Starter Pack (not bought yet). g.offers counts them. nil when none apply.
function GiftService:Offer(player, g)
	local p = data:Get(player)
	local list = {}
	if type(player:GetAttribute("Deal")) == "string" then
		table.insert(
			list,
			{ offer = "deal", key = player:GetAttribute("Deal"), ends = player:GetAttribute("DealEnds") }
		)
	end
	if player:GetAttribute("OwnsTNT") ~= true then
		table.insert(list, { offer = "tnt", key = "tnt" })
	end
	if p and not p.starter then
		table.insert(list, { offer = "starter", key = "starter" })
	end
	if #list == 0 then
		return nil
	end
	g.offers = (g.offers or 0) + 1
	return list[(g.offers - 1) % #list + 1]
end

function GiftService:Give(player)
	local g, p = giftsOf(player)
	if not g then
		return nil
	end
	if self:FirstShopDue(player) then
		-- (the first match: the shop instead of the end card, once; the gifts start next match)
		g.firstShop = true
		local shards = paid[player] or 0
		Net.fire(player, "Gift", { firstShop = true, shards = shards })
		self.FirstShop:Fire(player, shards)
		return nil
	end
	if bought(p, g) then
		if g.nudges < Constants.GIFT_NUDGES then
			g.nudges += 1
			Net.fire(player, "Gift", { nudge = true })
		end
		return nil
	end
	if self:Done(player) then
		-- (no more free ones and nothing bought yet: a first-buy offer instead, a different one each match)
		local offer = self:Offer(player, g)
		if offer then
			Net.fire(player, "Gift", offer)
		end
		return nil
	end
	local kind = kindFor(g)
	local it = pick(player, p, g, kind)
	if not it then
		-- (nothing left of that kind: try the others)
		for _, k in ORDER do
			it = pick(player, p, g, k)
			if it then
				break
			end
		end
	end
	if not it then
		return nil
	end
	p.owned = p.owned or {}
	p.owned[it.key] = true
	g.n += 1
	table.insert(g.keys, it.key)
	Net.fire(player, "Gift", {
		key = it.key,
		kind = it.kind,
		name = it.name,
		rarity = it.rarity,
		count = g.n,
		of = Constants.GIFT_MAX,
	})
	progress:Push(player)
	self.Gifted:Fire(player, it, g.n)
	return it
end

function GiftService:Init(registry)
	data = registry.PlayerDataService
	progress = registry.ProgressService
	shop = registry.ShopService
	match = registry.MatchService
	teams = registry.TeamService
	economy = registry.EconomyService
	-- (what the match pays, its knockouts and its end: the first match's shop says how many Shards they just earned;
	-- the practice's knockouts don't count)
	economy.Changed:Connect(function(player, _, delta, why)
		if PAID[why] and delta > 0 and player:GetAttribute("Practice") ~= true then
			paid[player] = (paid[player] or 0) + delta
		end
	end)
	match.Started:Connect(function()
		table.clear(paid)
	end)
	Players.PlayerRemoving:Connect(function(player)
		paid[player] = nil
	end)
	-- (anything bought: no more gifts)
	shop.Bought:Connect(function(player)
		local g = giftsOf(player)
		if g then
			g.bought = true
		end
	end)
	-- (a gift worn from the locker: that kind's learnt)
	progress.Equipped:Connect(function(player, kind, key)
		local g = giftsOf(player)
		if g and table.find(g.keys, key) and not g.wore[kind] then
			g.wore[kind] = true
			self.Worn:Fire(player, kind, key)
		end
	end)
	-- (each match's end: everyone who played it, once the results card has had its time)
	match.Ended:Connect(function()
		local list = {}
		for _, p in Players:GetPlayers() do
			if teams:Team(p) ~= nil then
				table.insert(list, p)
			end
		end
		task.delay(Constants.GIFT_DELAY, function()
			for _, p in list do
				if p.Parent then
					pcall(self.Give, self, p)
				end
			end
		end)
	end)
end

return GiftService

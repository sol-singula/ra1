-- The Trade Plaza: 12 stalls on the north wing. Put one of your blasters on a stall with a gem price; anyone can
-- buy it with gems. The seller gets the gems minus a 10% tax (our cut), the blaster moves to the buyer's bag.
-- A listed blaster leaves your bag until you take it back; when you leave the server it comes back to you.
-- Players who may not trade paid random items (PolicyService) can't list or buy. Every sale is logged.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TradeService = {
	Name = "TradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "BlasterService" },
	Sold = Signal.new("TradeService.Sold"), -- (seller, buyer, rec, gems, tax)
	stalls = {}, -- [index] = { seller, rec, price, listedAt }
}

local data, economy, blasters
local canTrade = {} -- [player] = true/false from PolicyService
local layout

local function findRec(profile, uid)
	for i, rec in profile.blasters do
		if rec.uid == uid then
			return rec, i
		end
	end
	return nil
end

function TradeService:CanTrade(player)
	return canTrade[player] ~= false
end

-- What every client sees: the stalls and what's on them.
function TradeService:View()
	local list = {}
	for i = 1, WorldBuilder.STALLS do
		local s = self.stalls[i]
		list[i] = s
				and {
					seller = s.seller.DisplayName,
					sellerId = s.seller.UserId,
					name = Formulas.blasterName(s.rec),
					stars = Formulas.rollStars(s.rec),
					rarity = s.rec.rarity,
					damage = Formulas.blasterDamage(s.rec),
					price = s.price,
				}
			or false
	end
	return list
end

function TradeService:PushAll()
	Net.fireAll("Profile", { stalls = self:View() })
end

local function draw(i)
	local stall = layout.stalls[i]
	local s = TradeService.stalls[i]
	if s then
		stall.lines[1].Text = Formulas.blasterName(s.rec) .. " " .. Formulas.rollStars(s.rec)
		stall.lines[1].TextColor3 = Blasters.byRarity[s.rec.rarity].color
		stall.lines[2].Text = `💎 {s.price} gems`
		stall.lines[3].Text = `by {s.seller.DisplayName}`
		stall.prompt.ActionText = "Buy for " .. s.price .. " gems"
	else
		stall.lines[1].Text = "EMPTY STALL"
		stall.lines[1].TextColor3 = Color3.fromRGB(220, 220, 230)
		stall.lines[2].Text = "Put a blaster here"
		stall.lines[3].Text = ""
		stall.prompt.ActionText = "Use stall"
	end
end

function TradeService:List(player, index, uid, price)
	local profile = data:Get(player)
	if not profile or not layout.stalls[index] then
		return false
	end
	if not self:CanTrade(player) then
		Net.fire(player, "Toast", "Trading isn't allowed on your account.", "bad")
		return false
	end
	if self.stalls[index] then
		Net.fire(player, "Toast", "That stall is taken. Find an empty one!", "bad")
		return false
	end
	if not table.find(Constants.STALL_PRICES, price) then
		return false
	end
	local rec, i = findRec(profile, uid)
	if not rec then
		return false
	end
	if #profile.blasters <= 1 then
		Net.fire(player, "Toast", "You need at least one blaster to keep!", "bad")
		return false
	end
	if rec.rarity == "Ultra" then
		Net.fire(player, "Toast", "Ultra blasters can't be sold. They're yours!", "info")
		return false
	end
	-- one stall per player
	for _, s in self.stalls do
		if s.seller == player then
			Net.fire(player, "Toast", "You already have a stall. Take that blaster back first.", "bad")
			return false
		end
	end
	table.remove(profile.blasters, i)
	if profile.equipped == uid then
		local best = blasters:Best(player)
		profile.equipped = best and best.uid
		blasters:_rebuildTool(player)
	end
	blasters:Push(player)
	self.stalls[index] = { seller = player, rec = rec, price = price, listedAt = os.time() }
	draw(index)
	self:PushAll()
	Net.fire(player, "Toast", `On the stall: {Formulas.blasterName(rec)} for {price} gems`, "good")
	Net.fire(player, "Sfx", "coin")
	return true
end

function TradeService:Unlist(player, index)
	local s = self.stalls[index]
	if not s or s.seller ~= player then
		return false
	end
	local profile = data:Get(player)
	if not profile then
		return false
	end
	self.stalls[index] = nil
	table.insert(profile.blasters, s.rec)
	if not profile.equipped then
		profile.equipped = s.rec.uid
		blasters:_rebuildTool(player)
	end
	blasters:Push(player)
	draw(index)
	self:PushAll()
	Net.fire(player, "Toast", "Back in your bag.", "info")
	return true
end

function TradeService:Buy(buyer, index)
	local s = self.stalls[index]
	local profile = data:Get(buyer)
	if not s or not profile then
		return false
	end
	if s.seller == buyer then
		return self:Unlist(buyer, index)
	end
	if not self:CanTrade(buyer) then
		Net.fire(buyer, "Toast", "Trading isn't allowed on your account.", "bad")
		return false
	end
	if #profile.blasters >= Constants.MAX_BLASTERS then
		Net.fire(buyer, "Toast", "Your bag is full!", "bad")
		return false
	end
	if not economy:SpendGems(buyer, s.price) then
		Net.fire(buyer, "Toast", `You need {s.price} gems. Raids and quests pay gems!`, "bad")
		return false
	end
	self.stalls[index] = nil
	local tax = math.floor(s.price * Constants.TRADE_TAX + 0.5)
	local toSeller = s.price - tax
	economy:AddGems(s.seller, toSeller, false)
	local rec = blasters:Grant(
		buyer,
		{ rarity = s.rec.rarity, planet = s.rec.planet, roll = s.rec.roll, lv = s.rec.lv },
		"trade"
	)
	draw(index)
	self:PushAll()
	Net.fire(
		buyer,
		"Alert",
		`🛒 Bought {Formulas.blasterName(rec)} {Formulas.rollStars(rec)}!`,
		Color3.fromRGB(120, 220, 255)
	)
	Net.fire(
		s.seller,
		"Alert",
		`💎 {buyer.DisplayName} bought your {Formulas.blasterName(rec)}: +{toSeller} gems`,
		Color3.fromRGB(120, 220, 255)
	)
	Net.fire(buyer, "Sfx", "buy")
	Net.fire(s.seller, "Sfx", "coin")
	Net.fireAll(
		"Announce",
		`🏪 {buyer.DisplayName} bought {s.seller.DisplayName}'s {Formulas.blasterName(rec)} for {s.price} gems`,
		Color3.fromRGB(120, 220, 255)
	)
	self.Sold:Fire(s.seller, buyer, rec, s.price, tax)
	return true
end

function TradeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	blasters = registry.BlasterService
	layout = WorldBuilder.layout
	Net.on("ListStall", function(player, index, uid, price)
		if type(index) == "number" and type(uid) == "number" and type(price) == "number" then
			self:List(player, index, uid, price)
		end
	end)
	Net.on("Unlist", function(player, index)
		if type(index) == "number" then
			self:Unlist(player, index)
		end
	end)
	Net.on("BuyStall", function(player, index)
		if type(index) == "number" then
			self:Buy(player, index)
		end
	end)
	data.ClientReady:Connect(function(player)
		data:Push(player, { stalls = self:View(), canTrade = self:CanTrade(player) })
	end)
	for i = 1, WorldBuilder.STALLS do
		draw(i)
	end
end

function TradeService:OnPlayerReady(player)
	task.spawn(function()
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		canTrade[player] = not ok or info.IsPaidItemTradingAllowed ~= false
		if player.Parent then
			data:Push(player, { canTrade = canTrade[player] })
		end
	end)
end

function TradeService:OnPlayerLeaving(player)
	for i, s in self.stalls do
		if s.seller == player then
			local profile = data:Get(player)
			if profile then
				table.insert(profile.blasters, s.rec)
			end
			self.stalls[i] = nil
			draw(i)
		end
	end
	canTrade[player] = nil
	self:PushAll()
	_ = Players
end

return TradeService

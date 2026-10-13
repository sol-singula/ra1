-- The Trade Plaza: 8 stalls along the south of the lobby. Put a skin on a stall with a coin price; anyone can buy
-- it with coins. The seller gets the coins minus a 10% tax, the skin moves to the buyer. A listed skin leaves your
-- bag until you take it back; if you leave the server it comes back to you. Players who may not trade paid random
-- items (PolicyService) can't list or buy. Prize skins can't be sold.
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local TradeService = {
	Name = "TradeService",
	Dependencies = { "PlayerDataService", "EconomyService", "LoadoutService" },
	Sold = Signal.new("TradeService.Sold"), -- (seller, buyer, skinId, coins, tax)
	stalls = {}, -- [index] = { seller, rec, price }
}

local data, economy, loadout
local canTrade = {}

function TradeService:CanTrade(player)
	return canTrade[player] ~= false
end

function TradeService:View()
	local list = {}
	for i = 1, WorldBuilder.STALLS do
		local s = self.stalls[i]
		list[i] = s and { seller = s.seller.DisplayName, sellerId = s.seller.UserId, skin = s.rec.id, price = s.price }
			or false
	end
	return list
end

function TradeService:PushAll()
	Net.fireAll("Profile", { stalls = self:View() })
end

local function draw(i)
	local stall = WorldBuilder.layout.stalls[i]
	local s = TradeService.stalls[i]
	if s then
		local skin = Cosmetics.skinById[s.rec.id]
		stall.lines[1].Text = (skin and skin.name or s.rec.id) .. " skin"
		stall.lines[1].TextColor3 = skin and Cosmetics.RarityColor[skin.rarity] or Color3.fromRGB(255, 255, 255)
		stall.lines[2].Text = `💰 {Format.num(s.price)}`
		stall.lines[3].Text = `by {s.seller.DisplayName}`
		stall.prompt.ActionText = "Buy for " .. Format.num(s.price)
	else
		stall.lines[1].Text = "EMPTY STALL"
		stall.lines[1].TextColor3 = Color3.fromRGB(220, 220, 230)
		stall.lines[2].Text = "Put a skin here"
		stall.lines[3].Text = ""
		stall.prompt.ActionText = "Use stall"
	end
end

function TradeService:List(player, index, uid, price)
	local profile = data:Get(player)
	if not profile or not WorldBuilder.layout.stalls[index] then
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
	for _, s in self.stalls do
		if s.seller == player then
			Net.fire(player, "Toast", "You already have a stall. Take that skin back first.", "bad")
			return false
		end
	end
	local rec
	for _, s in profile.skins do
		if s.uid == uid then
			rec = s
		end
	end
	if not rec then
		return false
	end
	local skin = Cosmetics.skinById[rec.id]
	if skin and skin.source == "prize" then
		Net.fire(player, "Toast", "Prize skins are yours for ever. They can't be sold!", "info")
		return false
	end
	loadout:TakeSkin(player, uid)
	self.stalls[index] = { seller = player, rec = rec, price = price }
	draw(index)
	self:PushAll()
	Net.fire(player, "Toast", `On the stall for {Format.num(price)} coins!`, "good")
	return true
end

function TradeService:Unlist(player, index)
	local s = self.stalls[index]
	if not s or s.seller ~= player then
		return false
	end
	self.stalls[index] = nil
	loadout:GrantSkin(player, s.rec.id, "unlist")
	draw(index)
	self:PushAll()
	Net.fire(player, "Toast", "Back in your bag.", "info")
	return true
end

function TradeService:Buy(buyer, index)
	local s = self.stalls[index]
	if not s or not data:Get(buyer) then
		return false
	end
	if s.seller == buyer then
		return self:Unlist(buyer, index)
	end
	if not self:CanTrade(buyer) then
		Net.fire(buyer, "Toast", "Trading isn't allowed on your account.", "bad")
		return false
	end
	if not economy:SpendCoins(buyer, s.price) then
		Net.fire(buyer, "Toast", `You need {Format.num(s.price)} coins.`, "bad")
		return false
	end
	self.stalls[index] = nil
	local tax = math.floor(s.price * Constants.TRADE_TAX + 0.5)
	economy:AddCoins(s.seller, s.price - tax, false)
	loadout:GrantSkin(buyer, s.rec.id, "trade")
	draw(index)
	self:PushAll()
	local skin = Cosmetics.skinById[s.rec.id]
	local name = skin and skin.name or s.rec.id
	Net.fire(buyer, "Alert", `🛒 You bought the {name} skin!`, Color3.fromRGB(120, 220, 255))
	Net.fire(
		s.seller,
		"Alert",
		`💰 {buyer.DisplayName} bought your {name}: +{Format.num(s.price - tax)} coins`,
		Color3.fromRGB(120, 220, 255)
	)
	Net.fire(buyer, "Sfx", "buy")
	Net.fire(s.seller, "Sfx", "coin")
	self.Sold:Fire(s.seller, buyer, s.rec.id, s.price, tax)
	return true
end

function TradeService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	loadout = registry.LoadoutService
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

function TradeService:OnPlayerLeaving(player, profile)
	for i, s in self.stalls do
		if s.seller == player then
			if profile then
				table.insert(profile.skins, s.rec)
			end
			self.stalls[i] = nil
			draw(i)
		end
	end
	canTrade[player] = nil
	self:PushAll()
end

return TradeService

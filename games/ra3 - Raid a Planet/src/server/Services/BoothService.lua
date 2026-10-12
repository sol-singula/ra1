-- Booth Street: 16 booths on the south wing. Claim one and show one of your own avatar items (a shirt, pants,
-- a hat, an accessory...) with a short message. Other players press the booth to buy it through Roblox's own
-- purchase prompt; Roblox pays the creator and gives this game its in-experience commission. Messages go through
-- the text filter. The Booth Rank pass puts you in the front booths (1 to 4, by the bridge).
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local BoothService = {
	Name = "BoothService",
	Dependencies = { "PlayerDataService", "EconomyService" },
	Shown = Signal.new("BoothService.Shown"), -- (player, assetId, name)
	Prompted = Signal.new("BoothService.Prompted"), -- (buyer, owner, assetId)
	booths = {}, -- [index] = { owner, assetId, name, price, message }
}

local data, economy
local layout
local FRONT = 4

local function draw(i)
	local booth = layout.booths[i]
	local b = BoothService.booths[i]
	if b and b.assetId then
		booth.lines[1].Text = b.name
		booth.lines[1].TextColor3 = Color3.fromRGB(255, 200, 240)
		booth.lines[2].Text = `R$ {b.price} · by {b.owner.DisplayName}`
		booth.lines[3].Text = b.message or ""
		booth.prompt.ActionText = "Buy for R$ " .. b.price
	elseif b then
		booth.lines[1].Text = b.owner.DisplayName .. "'s booth"
		booth.lines[1].TextColor3 = Color3.fromRGB(255, 200, 240)
		booth.lines[2].Text = "Setting up..."
		booth.lines[3].Text = ""
		booth.prompt.ActionText = "Use booth"
	else
		booth.lines[1].Text = "EMPTY BOOTH"
		booth.lines[1].TextColor3 = Color3.fromRGB(220, 220, 230)
		booth.lines[2].Text = "Claim it: show your clothes"
		booth.lines[3].Text = ""
		booth.prompt.ActionText = "Use booth"
	end
end

function BoothService:View()
	local list = {}
	for i = 1, WorldBuilder.BOOTHS do
		local b = self.booths[i]
		list[i] = b
				and {
					owner = b.owner.DisplayName,
					ownerId = b.owner.UserId,
					assetId = b.assetId,
					name = b.name,
					price = b.price,
					message = b.message,
				}
			or false
	end
	return list
end

function BoothService:PushAll()
	Net.fireAll("Profile", { booths = self:View() })
end

function BoothService:BoothOf(player)
	for i, b in self.booths do
		if b.owner == player then
			return i, b
		end
	end
	return nil
end

function BoothService:Claim(player, index)
	if not layout.booths[index] then
		return false
	end
	if self:BoothOf(player) then
		Net.fire(player, "Toast", "You already have a booth!", "bad")
		return false
	end
	if self.booths[index] then
		Net.fire(player, "Toast", "That booth is taken.", "bad")
		return false
	end
	if index <= FRONT and not economy:HasPass(player, "BOOTHRANK") then
		Net.fire(player, "Toast", "The front booths need the Booth Rank pass.", "info")
		return false
	end
	self.booths[index] = { owner = player }
	draw(index)
	self:PushAll()
	Net.fire(player, "Toast", "Your booth! Now put an item on it.", "good")
	return true
end

function BoothService:Leave(player, index)
	local b = self.booths[index]
	if not b or b.owner ~= player then
		return false
	end
	self.booths[index] = nil
	draw(index)
	self:PushAll()
	return true
end

-- Set the item: must be one of the player's own avatar items.
function BoothService:Set(player, index, assetId, message)
	local b = self.booths[index]
	if not b or b.owner ~= player then
		return false
	end
	local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, assetId)
	if not ok or not info then
		Net.fire(player, "Toast", "Hmm, that item ID doesn't work. Check it and try again.", "bad")
		return false
	end
	if not Constants.BOOTH_ASSET_TYPES[info.AssetTypeId] then
		Net.fire(player, "Toast", "Only clothes and accessories go on booths.", "bad")
		return false
	end
	local creator = info.Creator or {}
	if creator.Id ~= player.UserId then
		Net.fire(player, "Toast", "You can only show items you made.", "bad")
		return false
	end
	local clean = ""
	if type(message) == "string" and #message > 0 then
		message = string.sub(message, 1, Constants.BOOTH_MESSAGE_MAX)
		local okF, result = pcall(function()
			return TextService:FilterStringAsync(message, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		clean = okF and result or ""
	end
	b.assetId = assetId
	b.name = info.Name or ("Item " .. assetId)
	b.price = info.PriceInRobux or 0
	b.message = clean
	draw(index)
	self:PushAll()
	Net.fire(player, "Toast", `Your booth shows {b.name}!`, "good")
	Net.fire(player, "Sfx", "buy")
	self.Shown:Fire(player, assetId, b.name)
	return true
end

function BoothService:Buy(buyer, index)
	local b = self.booths[index]
	if not b or not b.assetId then
		return false
	end
	if b.owner == buyer then
		Net.fire(buyer, "Toast", "That's your own booth!", "info")
		return false
	end
	pcall(MarketplaceService.PromptPurchase, MarketplaceService, buyer, b.assetId)
	self.Prompted:Fire(buyer, b.owner, b.assetId)
	return true
end

function BoothService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	layout = WorldBuilder.layout
	Net.on("ClaimBooth", function(player, index)
		if type(index) == "number" then
			self:Claim(player, index)
		end
	end)
	Net.on("SetBooth", function(player, index, assetId, message)
		if type(index) == "number" and type(assetId) == "number" and assetId > 0 then
			self:Set(player, index, math.floor(assetId), message)
		end
	end)
	Net.on("LeaveBooth", function(player, index)
		if type(index) == "number" then
			self:Leave(player, index)
		end
	end)
	Net.on("BuyBooth", function(player, index)
		if type(index) == "number" then
			self:Buy(player, index)
		end
	end)
	data.ClientReady:Connect(function(player)
		data:Push(player, { booths = self:View() })
	end)
	for i = 1, WorldBuilder.BOOTHS do
		draw(i)
	end
end

function BoothService:OnPlayerLeaving(player)
	local i = self:BoothOf(player)
	if i then
		self.booths[i] = nil
		draw(i)
		self:PushAll()
	end
end

return BoothService

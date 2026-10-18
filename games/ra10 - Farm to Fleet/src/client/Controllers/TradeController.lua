--[[
Deals with the neighbours on screen (TradeService): a small card at the top right. An offer ("Ben has 80
Strawberries for your order: $1,200") with BUY and an X; a request from someone who wants yours ("Ava wants 80
Strawberries: $1,200") with SELL and NO. It goes when it's answered, done or gone.

  TradeController.state()   the card's deal, or nil
  TradeController.refs
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local TradeController = { Name = "TradeController", Order = 48 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
TradeController.refs = refs
local deal = nil

function TradeController.state()
	return deal
end

local function paint()
	refs.card.Visible = deal ~= nil
	if not deal then
		return
	end
	local what = `{Format.num(deal.n)} {deal.name}`
	if deal.kind == "offer" then
		refs.title.Text = "BUY FROM A NEIGHBOUR"
		refs.text.Text = `{deal.from} has {what} for your order: {Format.cash(deal.price)}`
		refs.yes.Text = "BUY"
		refs.no.Text = "X"
	else
		refs.title.Text = "SOMEONE WANTS YOURS"
		refs.text.Text = `{deal.from} wants {what}: {Format.cash(deal.price)}`
		refs.yes.Text = "SELL"
		refs.no.Text = "NO"
	end
	refs.yes.Active = not deal.asked
	refs.yes.BackgroundColor3 = deal.asked and Color3.fromRGB(160, 160, 160) or C.good
end

function TradeController:init()
	local gui = Theme.screen("Trade", 9, player:WaitForChild("PlayerGui"))
	local card = Theme.card({
		Name = "Deal",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 120),
		Size = UDim2.fromOffset(300, 132),
		Visible = false,
		Parent = gui,
	})
	Theme.compact(card, 0.8)
	refs.card = card
	refs.title = Theme.text({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		fit = 16,
		Parent = card,
	})
	refs.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 42),
		fit = 16,
		Parent = card,
	})
	refs.yes = Theme.button({
		Name = "Yes",
		Text = "BUY",
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -86, 0, 42),
		BackgroundColor3 = C.good,
		Parent = card,
	})
	refs.no = Theme.button({
		Name = "No",
		Text = "X",
		Position = UDim2.new(1, -66, 0, 80),
		Size = UDim2.fromOffset(54, 42),
		BackgroundColor3 = C.red,
		Parent = card,
	})
	refs.yes.Modal, refs.no.Modal = true, true
	refs.yes.Activated:Connect(function()
		if not deal or deal.asked then
			return
		end
		if deal.kind == "offer" then
			Net.send("Trade", "buy", deal.id)
			deal.asked = true
			paint()
		else
			Net.send("Trade", "sell", deal.id)
			deal = nil
			paint()
		end
	end)
	refs.no.Activated:Connect(function()
		if not deal then
			return
		end
		Net.send("Trade", deal.kind == "offer" and "skip" or "no", deal.id)
		deal = nil
		paint()
	end)
	Net.listen("Trade", function(msg)
		if type(msg) ~= "table" then
			return
		end
		if msg.kind == "offer" or msg.kind == "request" then
			deal = msg
		elseif deal and deal.id == msg.id then
			deal = nil
		end
		paint()
	end)
	paint()
end

return TradeController

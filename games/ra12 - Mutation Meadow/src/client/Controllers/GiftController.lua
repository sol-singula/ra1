--[[
Free gifts between players in this server, and Robux gifts arriving.

Giving: GiftController.pick({ item = guid } | { crop, qty }) opens "GiveGift" with everyone else in the server; a
tap sends Gift:offer {targetId, ...}. The Backpack's Gift button and the basket open it.
Receiving: GiftOffer { giftId, fromName, seed, muts?, qty?, expiresAt } shows "GiftOffer" with Accept / Decline
(Gift:respond); it closes by itself when the offer runs out.
A Robux gift landing (Toast kind "gift") shows the toast with its "Gift back" button, which opens the Store's Gift a
friend tab on the giver.

  GiftController.pick(what) / offer() / current()
  GiftController.offerText(data)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI)

local GiftController = {}

local controllers
local picker, incoming
local open -- the offer on screen

function GiftController.current()
	return open
end

function GiftController.offerText(data)
	local seed = Config.Seeds[data.seed] and Config.Seeds[data.seed].name or data.seed
	if data.qty then
		return `{data.fromName} wants to give you {data.qty} {seed}`
	end
	return `{data.fromName} wants to give you a {MutationMath.label(data.muts or {})} {seed}`
end

function GiftController.pick(what)
	picker.clear()
	local others = 0
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			others += 1
			UI.button(picker.body, "🎁 " .. p.DisplayName, function()
				local payload = { targetId = p.UserId }
				for k, v in what do
					payload[k] = v
				end
				Net.request("Gift", "offer", payload)
				picker.close()
			end, { Name = "To_" .. p.UserId })
		end
	end
	if others == 0 then
		UI.label(picker.body, "Nobody else is here yet.", { Name = "Nobody" })
	end
	picker.open()
end

local function respond(accept)
	if open then
		Net.request("Gift", "respond", { giftId = open.giftId, accept = accept })
	end
	open = nil
	incoming.close()
end

function GiftController.offer(data)
	open = data
	incoming.clear()
	UI.label(
		incoming.body,
		GiftController.offerText(data),
		{ Name = "Text", TextWrapped = true, Size = UDim2.new(1, 0, 0, 60) }
	)
	UI.button(incoming.body, "Accept", function()
		respond(true)
	end, { Name = "Accept" })
	UI.button(incoming.body, "Decline", function()
		respond(false)
	end, { Name = "Decline", BackgroundColor3 = UI.COLORS.grey })
	incoming.open()
	local giftId = data.giftId
	task.delay(math.max(0, (data.expiresAt or Clock.now()) - Clock.now()), function()
		if open and open.giftId == giftId then
			open = nil
			incoming.close()
		end
	end)
end

local function giftLanded(t)
	local hud = controllers.HudController
	local fromId
	for _, p in Players:GetPlayers() do
		if p.DisplayName == (t.data and t.data.from) then
			fromId = p.UserId
		end
	end
	hud.toast(t.text, {
		(t.data and t.data.button) or Config.Catalog.giftBackButton,
		function()
			if fromId then
				controllers.StoreController.giftTo(fromId)
			else
				controllers.StoreController.open("Gift")
			end
		end,
	})
end

function GiftController:Init(all)
	controllers = all
end

function GiftController:Start()
	picker = UI.modal("GiveGift", "Give a gift")
	picker.card.Size = UDim2.fromOffset(400, 460)
	incoming = UI.modal("GiftOffer", "A gift for you!")
	incoming.card.Size = UDim2.fromOffset(420, 320)
	Net.on("GiftOffer", function(data)
		if type(data) == "table" and data.giftId then
			GiftController.offer(data)
		end
	end)
	Net.on("Toast", function(t)
		if type(t) == "table" and t.kind == "gift" and type(t.text) == "string" then
			giftLanded(t)
		end
	end)
end

return GiftController

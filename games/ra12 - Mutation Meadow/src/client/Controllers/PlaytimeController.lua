--[[
Playtime gifts: 3 boxes (5, 10 and 20 minutes played today), each claimable once a day. The HUD gift button bounces
while one is ready. Played time counts on from the last playtime the server sent.

  PlaytimeController.open() / close() / isOpen() / fill()
  PlaytimeController.sec(now?)      played seconds today (estimated between server updates)
  PlaytimeController.ready()        the index of a ready, unclaimed gift (or nil)
  PlaytimeController.giftText(gift)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local PlaytimeController = {}

local controllers
local modal
local base, baseAt = 0, 0 -- playtime.sec as last received, and when

local function pt()
	return ClientState.get("playtime")
end

function PlaytimeController.sec(now)
	now = now or Clock.now()
	local p = pt()
	if not p or p.day ~= Clock.utcDay(now) then
		return math.max(0, now - math.max(baseAt, Clock.utcDay(now) * 86400))
	end
	return base + (now - baseAt)
end

local function claimed(i)
	local p = pt()
	return p ~= nil and p.day == Clock.utcDay(Clock.now()) and p.claimed[tostring(i)] == true
end

function PlaytimeController.ready()
	local sec = PlaytimeController.sec()
	for i, gift in Config.Playtime do
		if sec >= gift.atSec and not claimed(i) then
			return i
		end
	end
	return nil
end

function PlaytimeController.giftText(gift)
	local level = ClientState.get("plotLevel") or 1
	local parts = {}
	if gift.coinsPerLevelSq then
		table.insert(parts, `🪙 {UI.money(gift.coinsPerLevelSq * level ^ 2)}`)
	end
	if gift.topTierSeeds then
		table.insert(parts, `{gift.topTierSeeds} best seed{if gift.topTierSeeds > 1 then "s" else ""}`)
	end
	return table.concat(parts, " + ")
end

function PlaytimeController.fill()
	modal.clear()
	local sec = PlaytimeController.sec()
	for i, gift in Config.Playtime do
		local box = UI.frame(modal.body, { Name = "Gift_" .. i, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 84) })
		UI.label(box, `🎁 {gift.atSec // 60} min: {PlaytimeController.giftText(gift)}`, {
			Name = "Text",
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -140, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local status = UI.label(box, "", {
			Name = "Status",
			Position = UDim2.fromOffset(8, 44),
			Size = UDim2.new(1, -140, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		if claimed(i) then
			status.Text = "✓ Claimed today"
			status.TextColor3 = UI.COLORS.green
		elseif sec >= gift.atSec then
			status.Text = "Ready!"
			UI.button(box, "Claim", function()
				Net.request("Playtime", "claim", { index = i })
			end, {
				Name = "Claim",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 52),
			})
		else
			status.Text = "in " .. UI.duration(gift.atSec - sec)
		end
	end
end

function PlaytimeController.open()
	PlaytimeController.fill()
	modal.open()
end

function PlaytimeController.close()
	modal.close()
end

function PlaytimeController.isOpen()
	return modal.isOpen()
end

local function giftButton()
	local hud = controllers.HudController
	return hud.rewards and hud.rewards:FindFirstChild("Gift")
end

function PlaytimeController:Init(all)
	controllers = all
end

function PlaytimeController:Start()
	modal = UI.modal("Playtime", "Playtime Gifts")
	modal.card.Size = UDim2.fromOffset(460, 360)
	local function received()
		local p = pt()
		base, baseAt = p and p.sec or 0, Clock.now()
	end
	ClientState.Changed:Connect(function(roots)
		if roots == nil or roots.playtime then
			received()
			if modal.isOpen() then
				PlaytimeController.fill()
			end
		end
	end)
	received()
	local t, acc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local button = giftButton()
		if not button then
			return
		end
		t += dt
		acc += dt
		if acc >= 1 then
			acc = 0
			button:SetAttribute("Bouncing", PlaytimeController.ready() ~= nil)
			if modal.isOpen() then
				PlaytimeController.fill()
			end
		end
		button.Rotation = if button:GetAttribute("Bouncing") then math.sin(t * 8) * 8 else 0
	end)
end

return PlaytimeController

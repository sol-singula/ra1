--[[
"While you were away" (Net "Away", OfflineService): the first thing a returning player sees. A card in the middle:
how long they were gone, the Cash the farm made meanwhile (counting up), whether it hit the cap (and how long the
cap is), and what's waiting: ripe tiles, the day's calendar reward. COLLECT closes it (the Cash is
already theirs); the calendar opens after it if the day's reward waits.

  AwayController.refs   the card's pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)

local AwayController = { Name = "AwayController", Order = 46 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
AwayController.refs = refs

local function long(seconds)
	if seconds >= 86400 then
		local d = seconds // 86400
		return `{d} day{d == 1 and "" or "s"}`
	end
	return Format.time(seconds)
end

local function show(m)
	refs.gone.Text = `You were away for {long(m.seconds or 0)}`
	local waiting = {}
	if (m.ripe or 0) > 0 then
		table.insert(waiting, `🌾 {m.ripe} crops ripe`)
	end
	if type(m.calendar) == "table" then
		table.insert(waiting, `📅 day {m.calendar.day} reward`)
	end
	refs.waiting.Text = #waiting > 0 and ("Waiting for you: " .. table.concat(waiting, " · ")) or ""
	refs.cap.Text = m.capped and `Your farm works {m.hours or 4} h while you're away: come back sooner for more!`
		or (
			m.earned > 0 and "Your machines kept working."
			or "Build the tractor and shop helper to earn while you're away."
		)
	refs.card.Visible = true
	Theme.pop(refs.card)
	-- (count the Cash up)
	local target, t0 = m.earned or 0, os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / 1.2)
		refs.earned.Text = "+" .. Format.commas(math.floor(target * k))
		if k >= 1 or not refs.card.Visible then
			conn:Disconnect()
		end
	end)
end

function AwayController:init()
	local gui = Theme.screen("Away", 25, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	refs.card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 270),
		Visible = false,
		Parent = gui,
	})
	Theme.cardHeader(refs.card, "WELCOME BACK!", 46, Color3.fromRGB(60, 150, 80))
	refs.gone = Theme.text({
		Name = "Gone",
		Text = "",
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 18,
		Parent = refs.card,
	})
	refs.earned = Theme.text({
		Name = "Earned",
		Text = "+0",
		Font = Theme.Display,
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(40, 150, 60),
		fit = 44,
		Parent = refs.card,
	})
	refs.cap = Theme.text({
		Name = "Cap",
		Text = "",
		Position = UDim2.fromOffset(16, 138),
		Size = UDim2.new(1, -32, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 15,
		Parent = refs.card,
	})
	refs.waiting = Theme.text({
		Name = "Waiting",
		Text = "",
		Position = UDim2.fromOffset(16, 176),
		Size = UDim2.new(1, -32, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.ink,
		fit = 15,
		Parent = refs.card,
	})
	refs.collect = Theme.button({
		Name = "Collect",
		Text = "COLLECT",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(200, 48),
		Parent = refs.card,
	})
	refs.collect.Activated:Connect(function()
		Bus.Tap:Fire("away_collect")
		refs.card.Visible = false
	end)
	Layout.modal("away", refs.card)
	Net.listen("Away", function(m)
		if type(m) == "table" then
			show(m)
		end
	end)
end

return AwayController

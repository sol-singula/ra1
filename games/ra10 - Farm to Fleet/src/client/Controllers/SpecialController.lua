--[[
A Special Order on screen (master plan §13.3): a gold banner under the guide's card while one is on: SPECIAL ORDER,
what it is and who for, what's packed of what, the clock counting down (red in the last minute), and the pay in
Cash and Gems; "on the express truck" once it's packed. It pulses while it's waiting. Net "Special" fills it.

  SpecialController.state()   the last Net "Special"
  SpecialController.refs      the banner's pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Orders = require(ReplicatedStorage.Shared.Data.Orders)
local Theme = require(script.Parent.Parent.UI.Theme)

local SpecialController = { Name = "SpecialController", Order = 47 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = {}
SpecialController.refs = refs
local state = { none = true }
local got = 0
local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(235, 50, 45)

function SpecialController.state()
	return state
end

local function itemsText(s)
	local parts = {}
	local keys = {}
	for key in s.items or {} do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local golden = string.sub(key, 1, 1) == "*"
		local name = Orders.itemName(golden and string.sub(key, 2) or key)
		table.insert(parts, `{golden and "Golden " or ""}{name} {(s.packed and s.packed[key]) or 0}/{s.items[key]}`)
	end
	return table.concat(parts, " · ")
end

local function paint()
	local on = state.none ~= true and state.items ~= nil
	refs.banner.Visible = on
	if not on then
		return
	end
	local now = (state.now or 0) + (os.clock() - got)
	refs.title.Text = `SPECIAL ORDER · {state.name} for {state.who}`
	refs.items.Text = itemsText(state)
	refs.pay.Text = `{Format.num(state.reward or 0)} + {state.gems or 0}💎`
	if state.state == "shipping" then
		refs.clock.Text = "On the express truck!"
		refs.clock.TextColor3 = C.good
	else
		local left = math.max(0, math.floor((state.ends or now) - now))
		refs.clock.Text = Format.time(left) .. " left"
		refs.clock.TextColor3 = left < 60 and RED or C.ink
	end
end

function SpecialController:init()
	local gui = Theme.screen("Special", 9, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	refs.banner = Theme.card({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.fromOffset(500, 66),
		BackgroundColor3 = GOLD,
		Visible = false,
		Parent = gui,
	})
	refs.title = Theme.text({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -150, 0, 26),
		Font = Theme.Display,
		fit = 20,
		Parent = refs.banner,
	})
	refs.pay = Theme.text({
		Name = "Pay",
		Text = "",
		Position = UDim2.new(1, -136, 0, 4),
		Size = UDim2.fromOffset(124, 26),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(30, 110, 50),
		fit = 20,
		Parent = refs.banner,
	})
	refs.items = Theme.text({
		Name = "Items",
		Text = "",
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -150, 0, 24),
		fit = 16,
		Parent = refs.banner,
	})
	refs.clock = Theme.text({
		Name = "Clock",
		Text = "",
		Position = UDim2.new(1, -136, 0, 34),
		Size = UDim2.fromOffset(124, 24),
		Font = Theme.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		fit = 16,
		Parent = refs.banner,
	})
	Net.listen("Special", function(m)
		if type(m) ~= "table" then
			return
		end
		state = m
		got = os.clock()
		paint()
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if refs.banner.Visible then
			paint()
			-- (a slow pulse while it waits to be packed)
			local k = state.state == "open" and (math.sin(os.clock() * 4) + 1) / 2 or 0
			refs.banner.BackgroundColor3 = GOLD:Lerp(Color3.fromRGB(255, 235, 140), k * 0.6)
		end
	end)
end

return SpecialController

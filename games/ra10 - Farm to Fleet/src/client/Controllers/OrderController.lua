--[[
The order board on screen (master plan §7, §8): once the packing shed stands, a panel on the right lists the open
orders (who, what they want packed of what, the time left, the pay) and what each one is doing (packing, waiting for
a truck, on the road, the next customer coming), with a skip on open ones (Net "Order" "skip"); under them, today's
three contracts and their progress. Net "Orders" fills it; the timers count down here between updates.

  OrderController.state()   the last Net "Orders"
  OrderController.refs      the panel's pieces (tests)
  OrderController.status(slot, now) -> the words a slot's status line shows
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Orders = require(ReplicatedStorage.Shared.Data.Orders)
local Theme = require(script.Parent.Parent.UI.Theme)

local OrderController = { Name = "OrderController", Order = 45, ROW = 66 }

local C = Theme.Color
local player = Players.LocalPlayer
local refs = { rows = {}, contracts = {} }
OrderController.refs = refs
local state = {}
local got = 0 -- os.clock() when the last Net "Orders" came (the timers run from its `now`)

function OrderController.state()
	return state
end

local function serverNow()
	return (state.now or 0) + (os.clock() - got)
end

local function itemsText(slot)
	local keys = {}
	for key in slot.items or {} do
		table.insert(keys, key)
	end
	table.sort(keys)
	local parts = {}
	for _, key in keys do
		table.insert(parts, `{Orders.itemName(key)} {(slot.packed and slot.packed[key]) or 0}/{slot.items[key]}`)
	end
	return table.concat(parts, " · ")
end

function OrderController.status(slot, now)
	if slot.state == "open" then
		return `Pack it! {Format.time(math.max(0, math.floor((slot.ends or now) - now)))} left`, C.white
	elseif slot.state == "ready" then
		return "Packed: waiting for a truck", C.good
	elseif slot.state == "shipping" then
		local back = math.max(0, math.ceil((slot.at or now) + (slot.length or 0) - now))
		return `On the road: paid in {Format.time(back)}`, Color3.fromRGB(120, 200, 255)
	end
	return `Next customer in {Format.time(math.max(0, math.ceil((slot.at or now) - now)))}`, C.grey
end

local function row(i)
	local frame = Theme.new("Frame", {
		Name = "Order" .. i,
		Position = UDim2.fromOffset(8, 40 + (i - 1) * (OrderController.ROW + 6)),
		Size = UDim2.new(1, -16, 0, OrderController.ROW),
		BackgroundColor3 = Color3.fromRGB(44, 48, 56),
		BorderSizePixel = 0,
		Parent = refs.panel,
	}, { Theme.corner(6) })
	local r = { frame = frame }
	r.who = Theme.text({
		Name = "Who",
		Text = "",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -110, 0, 20),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 17,
		Parent = frame,
	})
	r.pay = Theme.text({
		Name = "Pay",
		Text = "",
		Position = UDim2.new(1, -104, 0, 4),
		Size = UDim2.fromOffset(72, 20),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		TextXAlignment = Enum.TextXAlignment.Right,
		fit = 16,
		Parent = frame,
	})
	r.items = Theme.text({
		Name = "Items",
		Text = "",
		Position = UDim2.fromOffset(8, 25),
		Size = UDim2.new(1, -16, 0, 18),
		TextColor3 = Color3.fromRGB(230, 230, 220),
		fit = 14,
		Parent = frame,
	})
	r.status = Theme.text({
		Name = "Status",
		Text = "",
		Position = UDim2.fromOffset(8, 44),
		Size = UDim2.new(1, -16, 0, 18),
		fit = 14,
		Parent = frame,
	})
	r.skip = Theme.button({
		Name = "Skip",
		Text = "✕",
		Position = UDim2.new(1, -28, 0, 4),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Color3.fromRGB(90, 94, 104),
		Parent = frame,
	})
	r.skip.Activated:Connect(function()
		Net.send("Order", "skip", i)
	end)
	refs.rows[i] = r
	return r
end

local function paint()
	local slots = state.slots or {}
	local shown = state.open == true and #slots > 0
	refs.panel.Visible = shown
	if not shown then
		return
	end
	local now = serverNow()
	for i = 1, math.max(#slots, #refs.rows) do
		local r = refs.rows[i] or (slots[i] and row(i))
		local slot = slots[i]
		if r then
			r.frame.Visible = slot ~= nil
			if slot then
				local hasOrder = slot.items ~= nil and slot.state ~= "wait"
				r.who.Text = hasOrder and ((slot.big and "BIG! " or "") .. (slot.who or "")) or "Order board"
				r.who.TextColor3 = slot.big and C.mustard or C.white
				r.pay.Text = hasOrder and (Format.num(slot.reward or 0) .. (slot.gems and ` +{slot.gems}💎` or ""))
					or ""
				r.items.Text = hasOrder and itemsText(slot) or ""
				local words, color = OrderController.status(slot, now)
				r.status.Text = words
				r.status.TextColor3 = color
				r.skip.Visible = slot.state == "open"
			end
		end
	end
	-- today's contracts, under the orders
	local top = 40 + #slots * (OrderController.ROW + 6) + 4
	refs.today.Position = UDim2.fromOffset(10, top)
	local list = state.contracts or {}
	for i = 1, 3 do
		local line = refs.contracts[i]
		local c = list[i]
		line.Position = UDim2.fromOffset(10, top + 24 + (i - 1) * 22)
		line.Visible = c ~= nil
		if c then
			line.Text = (c.done and "✔ " or "○ ") .. `{c.text}  {math.max(0, c.have or 0)}/{c.n}`
			line.TextColor3 = c.done and C.good or C.white
		end
	end
	refs.today.Text = `TODAY'S CONTRACTS · new in {Format.time(math.max(0, math.floor(state.dayLeft or 0)))}`
	refs.panel.Size = UDim2.fromOffset(300, top + 24 + 3 * 22 + 8)
end

function OrderController:init()
	local gui = Theme.screen("Orders", 7, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	refs.panel = Theme.slab({
		Name = "Panel",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 70),
		Size = UDim2.fromOffset(300, 260),
		Visible = false,
		Parent = gui,
	})
	refs.title = Theme.text({
		Name = "Title",
		Text = "ORDERS",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 28),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		fit = 22,
		Parent = refs.panel,
	})
	refs.today = Theme.text({
		Name = "Today",
		Text = "TODAY'S CONTRACTS",
		Position = UDim2.fromOffset(10, 200),
		Size = UDim2.new(1, -20, 0, 20),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		fit = 14,
		Parent = refs.panel,
	})
	for i = 1, 3 do
		refs.contracts[i] = Theme.text({
			Name = "Contract" .. i,
			Text = "",
			Position = UDim2.fromOffset(10, 224 + (i - 1) * 22),
			Size = UDim2.new(1, -20, 0, 20),
			TextColor3 = C.white,
			fit = 14,
			Parent = refs.panel,
		})
	end
	Net.listen("Orders", function(m)
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
		if acc >= 0.5 then
			acc = 0
			if refs.panel.Visible then
				paint()
			end
		end
	end)
end

return OrderController

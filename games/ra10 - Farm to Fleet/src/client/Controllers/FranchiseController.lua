--[[
The FRANCHISE panel (Net "Franchise", FranchiseService; master plan §13.5). The left: where you farm now, the
Stars a sale would bring (from this run's Cash), what stays and what goes, and FRANCHISE (pressed twice: the
second press is the "are you sure"). The right: the perks, each with its level and a BUY for Stars.

  FranchiseController.refs   the panel's pieces (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)

local FranchiseController = { Name = "FranchiseController", Order = 50 }

local C = Theme.Color
local refs = { perks = {} }
FranchiseController.refs = refs
local GOLD = Color3.fromRGB(235, 175, 30)
local state = {}
local armed = false

local function paint()
	local m = state
	refs.region.Text = `⭐ Franchise {m.level or 0} · {m.region or "Orchard Valley"}`
	refs.stars.Text = `{m.stars or 0} Stars to spend · {m.total or 0} ever (+{math.floor(
		((m.mult or 1) - 1) * 100 + 0.5
	)}% on everything shipped)`
	refs.earn.Text = m.open
			and `Sell now for ⭐ {m.earn or 1} Stars\n(this farm earned {Format.num(m.earned or 0)} Cash)`
		or "Build the Market Hall to franchise your company"
	refs.sell.Visible = m.open == true
	refs.sell.Text = armed and `SURE? MOVE TO {string.upper(m.nextRegion or "")}` or "FRANCHISE!"
	refs.sell.BackgroundColor3 = armed and C.red or GOLD
	for i, row in refs.perks do
		local perk = m.perks and m.perks[i]
		row.frame.Visible = perk ~= nil
		if perk then
			row.key = perk.key
			row.name.Text = `{perk.name} {perk.level}/{perk.max}`
			row.text.Text = perk.text
			row.buy.Text = perk.cost and `⭐ {perk.cost}` or "MAX"
			row.buy.BackgroundColor3 = perk.cost and (m.stars or 0) >= perk.cost and C.good
				or Color3.fromRGB(150, 150, 150)
		end
	end
end

function FranchiseController:init()
	local panel = Panel.new("franchise", "FRANCHISE", GOLD, Vector2.new(760, 430))
	refs.panel = panel
	local body = panel.body
	refs.region = Theme.text({
		Name = "Region",
		Text = "",
		Font = Theme.Display,
		Size = UDim2.new(0.45, 0, 0, 28),
		fit = 20,
		Parent = body,
	})
	refs.stars = Theme.text({
		Name = "Stars",
		Text = "",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(0.45, 0, 0, 40),
		fit = 15,
		Parent = body,
	})
	refs.earn = Theme.text({
		Name = "Earn",
		Text = "",
		Font = Theme.Display,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(0.45, 0, 0, 56),
		TextColor3 = Color3.fromRGB(170, 110, 10),
		fit = 20,
		Parent = body,
	})
	Theme.text({
		Name = "Rules",
		Text = "Sell your company for Stars and start a new farm in a richer region.\n"
			.. "GOES: Cash, buildings, stages, the warehouse, the vans.\n"
			.. "STAYS: Gems, your farm level, animal levels, golden seeds, the calendar, every record.",
		Position = UDim2.fromOffset(0, 142),
		Size = UDim2.new(0.45, 0, 0, 120),
		TextYAlignment = Enum.TextYAlignment.Top,
		fit = 14,
		Parent = body,
	})
	refs.sell = Theme.button({
		Name = "Sell",
		Text = "FRANCHISE!",
		BackgroundColor3 = GOLD,
		Position = UDim2.fromOffset(0, 290),
		Size = UDim2.new(0.45, 0, 0, 52),
		Visible = false,
		Parent = body,
	})
	refs.sell.Activated:Connect(function()
		if not armed then
			armed = true
			paint()
			task.delay(4, function()
				armed = false
				paint()
			end)
			return
		end
		armed = false
		Bus.Tap:Fire("franchise_sell")
		Net.send("Franchise", "sell")
		Bus.Panel:Fire(nil)
	end)
	for i = 1, 6 do
		local frame = Theme.card({
			Name = "Perk" .. i,
			Position = UDim2.new(0.48, 0, 0, (i - 1) * 58),
			Size = UDim2.new(0.52, 0, 0, 52),
			Visible = false,
			Parent = body,
		})
		local row = { frame = frame }
		row.name = Theme.text({
			Name = "Name",
			Text = "",
			Font = Theme.Display,
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(0.72, -8, 0, 22),
			fit = 16,
			Parent = frame,
		})
		row.text = Theme.text({
			Name = "Text",
			Text = "",
			Position = UDim2.fromOffset(8, 26),
			Size = UDim2.new(0.72, -8, 0, 20),
			fit = 13,
			Parent = frame,
		})
		row.buy = Theme.button({
			Name = "Buy",
			Text = "",
			BackgroundColor3 = C.good,
			Position = UDim2.new(0.72, 0, 0, 6),
			Size = UDim2.new(0.28, -8, 1, -12),
			Parent = frame,
		})
		row.buy.Activated:Connect(function()
			if row.key then
				Bus.Tap:Fire("franchise_perk")
				Net.send("Franchise", "perk", row.key)
			end
		end)
		refs.perks[i] = row
	end
	panel.onOpen = function()
		armed = false
		Net.send("Franchise", "open")
	end
	Net.listen("Franchise", function(m)
		if type(m) == "table" then
			state = m
			paint()
		end
	end)
end

return FranchiseController

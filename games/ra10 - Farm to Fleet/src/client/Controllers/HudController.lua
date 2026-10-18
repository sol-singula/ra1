--[[
The always-on screen (phone first: big, high-contrast, in the farm's colours).

  top left     your Cash (a green coin) and Gems, the basket under them (carried / how much you can carry), the
               the BARN under that (what it keeps, each with how many the orders keep) and the
               BOOSTS your animals give the farm right now
  top centre   FARM LEVEL n and its XP bar
  centre       the toasts (Net "Toast"), a "+N" when Cash comes in (Net "Earned")

  HudController.refs   the pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = { Name = "HudController", Order = 10 }

local C = Theme.Color
local P = Constants.PALETTE
local CASH = Color3.fromRGB(70, 200, 90)
local player = Players.LocalPlayer
local refs = {}
HudController.refs = refs
local toastToken

local function toast(text, kind)
	local t = refs.toast
	if not t then
		return
	end
	t.Text = text
	t.TextColor3 = kind == "bad" and C.red or (kind == "good" and C.good or C.white)
	t.Visible = true
	local token = {}
	toastToken = token
	task.delay(3.2, function()
		if toastToken == token then
			t.Visible = false
		end
	end)
end
HudController.toast = toast

local function paint()
	local p = Store.get("profile")
	if p then
		refs.cash.Text = "$" .. Theme.commas(p.cash or 0)
		refs.gems.Text = Theme.commas(p.gems or 0)
		refs.levelText.Text = `FARM LEVEL {p.level or 1}`
		local k = (p.need or 0) > 0 and (p.into or 0) / p.need or 0
		refs.levelFill.Size = UDim2.fromScale(math.clamp(k, 0.03, 1), 1)
		refs.xp.Text = `{p.into or 0} / {p.need or 0} XP`
	end
	local f = Store.get("farm")
	if f then
		-- (the basket: until the barn keeps the crops)
		refs.basket.Visible = not f.stockCap
		refs.basket.Text = `🧺 {f.carried or 0} / {f.carry or 0}`
		refs.basket.TextColor3 = (f.carried or 0) >= (f.carry or 1) and C.mustard or C.white
	end
	-- the stock: biggest first, each with what the orders keep
	local rows = {}
	for key, n in f and f.stock or {} do
		if n > 0 then
			table.insert(rows, { key = key, n = n, kept = f.reserved and f.reserved[key] or 0 })
		end
	end
	table.sort(rows, function(a, b)
		return a.n > b.n
	end)
	refs.stock.Visible = #rows > 0
	local total = 0
	for _, r in rows do
		total += r.n
	end
	local cap = f and f.stockCap
	local where = f and f.stockCap and (f.barn and not (f.crops and #f.crops > 0) and "BARN" or "WAREHOUSE") or "CROPS"
	refs.stockTitle.Text = cap and `{where} {Format.num(total)} / {Format.num(cap)}{total >= cap and "  FULL!" or ""}`
		or where
	refs.stockTitle.TextColor3 = cap and total >= cap and C.red or C.mustard
	for i, row in refs.stockRows do
		local r = rows[i]
		row.frame.Visible = r ~= nil
		if r then
			local golden = string.sub(r.key, 1, 1) == "*"
			local key = golden and string.sub(r.key, 2) or r.key
			local c = Crops[key]
			row.dot.BackgroundColor3 = golden and P.sunflower or (c and c.color or Color3.fromRGB(250, 245, 230))
			row.name.Text = (golden and "Golden " or "") .. (c and c.name or key)
			row.count.Text = r.kept > 0 and `{Format.num(r.n)}  ({Format.num(r.kept)} for orders)` or Format.num(r.n)
			row.count.TextColor3 = r.kept > 0 and C.mustard or C.white
		end
	end
	refs.stock.Size = UDim2.fromOffset(250, 30 + math.min(#rows, #refs.stockRows) * 22)
	-- the boosts: one line an animal
	local pens = Store.get("animals")
	local lines = {}
	for _, key in Animals.LIST do
		local pen = pens and pens.pens and pens.pens[key]
		if pen and pen.boost then
			table.insert(
				lines,
				(pen.fed and "" or "(hungry) ")
					.. Animals[key].name
					.. "s: "
					.. pen.boost
					.. (pen.happy and " (happy x2)" or "")
			)
		end
	end
	refs.boosts.Visible = #lines > 0
	refs.boosts.Text = "BOOSTS\n" .. table.concat(lines, "\n")
	refs.boosts.Size = UDim2.fromOffset(250, 24 + #lines * 20)
	refs.boosts.Position = UDim2.fromOffset(12, 92 + (refs.stock.Visible and refs.stock.Size.Y.Offset + 8 or 0))
end

function HudController:init()
	local gui = Theme.screen("Hud", 5, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local money = Theme.slab({
		Name = "Cash",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(170, 46),
		Parent = gui,
	})
	Theme.new("Frame", {
		Name = "Coin",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = CASH,
		BorderSizePixel = 0,
		Parent = money,
	}, { Theme.corner("round"), Theme.stroke(2) })
	refs.cash = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(44, 5),
		Size = UDim2.new(1, -52, 1, -10),
		Font = Theme.Display,
		TextColor3 = CASH,
		fit = 26,
		Parent = money,
	})
	local gems = Theme.slab({
		Name = "Gems",
		Position = UDim2.fromOffset(190, 12),
		Size = UDim2.fromOffset(110, 46),
		Parent = gui,
	})
	Theme.gem(gems, 22, { Name = "Gem", Position = UDim2.fromOffset(10, 12) })
	refs.gems = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(40, 5),
		Size = UDim2.new(1, -48, 1, -10),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 24,
		Parent = gems,
	})
	refs.basket = Theme.text({
		Name = "Basket",
		Text = "🧺 0 / 20",
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.fromOffset(170, 26),
		Font = Theme.Display,
		TextColor3 = C.white,
		outline = 2,
		fit = 20,
		Parent = gui,
	})

	-- the stock
	local stock = Theme.slab({
		Name = "Stock",
		Position = UDim2.fromOffset(12, 92),
		Size = UDim2.fromOffset(250, 30),
		Visible = false,
		Parent = gui,
	})
	refs.stock = stock
	refs.stockTitle = Theme.text({
		Name = "Title",
		Text = "STOCK",
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 22),
		Font = Theme.Display,
		TextColor3 = C.mustard,
		fit = 16,
		Parent = stock,
	})
	refs.stockRows = {}
	for i = 1, 8 do
		local frame = Theme.new("Frame", {
			Name = "Row" .. i,
			Position = UDim2.fromOffset(10, 26 + (i - 1) * 22),
			Size = UDim2.new(1, -20, 0, 20),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = stock,
		})
		local dot = Theme.new("Frame", {
			Name = "Dot",
			Position = UDim2.fromOffset(0, 4),
			Size = UDim2.fromOffset(12, 12),
			BorderSizePixel = 0,
			Parent = frame,
		}, { Theme.corner("round") })
		local name = Theme.text({
			Name = "Name",
			Text = "",
			Position = UDim2.fromOffset(18, 0),
			Size = UDim2.new(0.5, -18, 1, 0),
			TextColor3 = C.white,
			fit = 14,
			Parent = frame,
		})
		local count = Theme.text({
			Name = "Count",
			Text = "",
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.white,
			fit = 14,
			Parent = frame,
		})
		refs.stockRows[i] = { frame = frame, dot = dot, name = name, count = count }
	end
	-- the animals' boosts
	refs.boosts = Theme.text({
		Name = "Boosts",
		Text = "",
		Position = UDim2.fromOffset(12, 92),
		Size = UDim2.fromOffset(250, 24),
		TextColor3 = Color3.fromRGB(150, 240, 140),
		outline = 2,
		fit = 15,
		Visible = false,
		Parent = gui,
	})

	local bar, fill = Theme.bar({
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(300, 30),
		Parent = gui,
	}, P.sunflower)
	refs.levelBar, refs.levelFill = bar, fill
	refs.levelText = Theme.text({
		Name = "Words",
		Text = "FARM LEVEL 1",
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(0.6, -10, 1, -4),
		Font = Theme.Display,
		TextColor3 = C.white,
		outline = 2,
		fit = 18,
		ZIndex = 3,
		Parent = bar,
	})
	refs.xp = Theme.text({
		Name = "XP",
		Text = "",
		Position = UDim2.new(0.6, 0, 0, 2),
		Size = UDim2.new(0.4, -10, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.white,
		outline = 2,
		fit = 14,
		ZIndex = 3,
		Parent = bar,
	})

	refs.toast = Theme.text({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(560, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		outline = 2,
		fit = 20,
		Visible = false,
		Parent = gui,
	})
	Theme.compact(refs.toast, 0.7)
	refs.earned = Theme.text({
		Name = "Earned",
		Text = "",
		Position = UDim2.fromOffset(190, 62),
		Size = UDim2.fromOffset(160, 26),
		Font = Theme.Display,
		TextColor3 = CASH,
		outline = 2,
		fit = 22,
		Visible = false,
		Parent = gui,
	})

	paint()
	Store.Changed:Connect(function(partial)
		if partial.profile or partial.farm or partial.animals then
			paint()
		end
	end)
	Net.listen("Toast", toast)
	local earnedToken
	Net.listen("Earned", function(e)
		if type(e) ~= "table" or e.currency ~= "cash" then
			return
		end
		refs.earned.Text = `+{Format.cash(e.amount or 0)}`
		refs.earned.Visible = true
		local token = {}
		earnedToken = token
		task.delay(1.6, function()
			if earnedToken == token then
				refs.earned.Visible = false
			end
		end)
	end)
end

return HudController

--[[
The match's end screen for players who haven't bought anything yet (GiftService): "YOU WON A FREE TRAIL!" A card
flips over to show the gift (its 3D picture, name and rarity) in a burst of sparkles over spinning rays in the
rarity's colour, with a big EQUIP IT that opens the locker on it (PanelController.showItem: a gold ring and a hand
on the card, scrolled to it) and a smaller LATER. Under it a tease of one of the Robux-only legends (Shop.PREMIUM).
FREE GIFT n OF 6 at the top. After they've bought something it's a short "NEW IN THE SHOP" card instead (OPEN SHOP).

It waits behind the shop panel if that's open, and closes itself when the next game's fight starts.

  GiftController.show(g)     g: Net "Gift"'s table -> the screen
  GiftController.equip()     EQUIP IT (or OPEN SHOP): the locker on the gift
  GiftController.later()     LATER
  GiftController.current()   the gift shown (or nil), the screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Icons = require(script.Parent.Parent.UI.Icons)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)
local PanelController = require(script.Parent.PanelController)

local GiftController = { Name = "GiftController", Order = 52 }

local C = Theme.Color
local GOLD = Icons.GOLD
local RARITY = { common = "COMMON", rare = "RARE", epic = "EPIC", legendary = "LEGENDARY" }
local RARITY_COLOR = {
	common = Color3.fromRGB(140, 142, 150),
	rare = Color3.fromRGB(35, 110, 245),
	epic = Color3.fromRGB(150, 90, 240),
	legendary = Color3.fromRGB(240, 160, 20),
}
local KIND_WORD = { trail = "TRAIL", effect = "KILL EFFECT", skin = "BOW", banner = "BANNER", title = "TITLE" }
local EQUIP_SIZE = Vector2.new(300, 60)

-- The first-buy offers (GiftService:Offer, once the free gifts are done): what each says, its price (and old price)
local OFFERS = {
	deal = {
		top = "⚡ TODAY ONLY · 1 HOUR ⚡",
		title = function(it)
			return `{math.floor(Shop.DEAL.off * 100 + 0.5)}% OFF {string.upper(it.name)}!`
		end,
		price = function(g)
			local d = Shop.products[g.key]
			return d.robux, d.was
		end,
		line = function(_, was)
			return `was {Format.robux(was)}  ·  yours forever`
		end,
	},
	tnt = {
		top = "🧨 YOUR FIRST UPGRADE 🧨",
		title = function()
			local off = Shop.off(Shop.TNT)
			return off and `TNT · PERMANENT · {off}% OFF` or "TNT · PERMANENT"
		end,
		price = function()
			return Shop.TNT.robux, Shop.TNT.was
		end,
		line = function(_, was)
			return was and `was {Format.robux(was)}  ·  throw one every 3s, forever` or "throw one every 3s, forever"
		end,
		picture = function(props)
			return Icons.weapon("tnt", Store.team() or "red", props)
		end,
	},
	starter = {
		top = "🎁 ONE TIME ONLY 🎁",
		title = function()
			local off = Shop.off(Shop.STARTER)
			return off and `STARTER PACK · {off}% OFF` or "STARTER PACK"
		end,
		price = function()
			return Shop.STARTER.robux, Shop.STARTER.was
		end,
		line = function(_, was)
			local what = Shop.STARTER.desc:gsub("◆", "Shards")
			return was and `{what}  ·  was {Format.robux(was)}` or what
		end,
		picture = function(props)
			return Icons.gift(Store.team() or "red", props)
		end,
	},
}

local player = Players.LocalPlayer
local gui
local screen -- the end screen up now
local shown -- its gift table
local stepper -- its animation
local waiting -- a gift that came while the shop panel was open

local function close()
	if stepper then
		stepper:Disconnect()
		stepper = nil
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
	shown = nil
end

local function text(props)
	props.TextColor3 = props.TextColor3 or C.ink
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	return Theme.text(props)
end

local function bigButton(parent, name, label, y, w, h, gold, fn)
	local b = Theme.new("TextButton", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = gold and GOLD or C.white,
		Text = label,
		Font = Theme.Display,
		TextSize = gold and 24 or 14,
		TextColor3 = C.ink,
		AutoButtonColor = true,
		Modal = true,
		ZIndex = 5,
		Parent = parent,
	}, { Theme.corner(8), Theme.stroke(gold and 3 or 2, C.ink) })
	b.Activated:Connect(fn)
	return b
end

function GiftController.equip()
	if not shown then
		return false
	end
	local key = shown.key
	close()
	if key then
		PanelController.showItem(key)
	else
		PanelController.open("shop")
	end
	return true
end

-- An offer's BUY: the Robux prompt for it, the screen out of the way
function GiftController.buy()
	if not (shown and shown.offer) then
		return false
	end
	local key = shown.key
	close()
	Net.send("Buy", "robux", key)
	return true
end

function GiftController.later()
	if not shown then
		return false
	end
	close()
	return true
end

-- The prize: face down, flipping over to its picture, name and rarity
local function prize(card, it, color)
	local flip = Theme.new("Frame", {
		Name = "Prize",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(0, 190),
		BackgroundColor3 = color,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = card,
	}, { Theme.corner(10), Theme.stroke(3, C.ink) })
	local pic = Icons.cosmetic(it, Store.team(), {
		Name = "Picture",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -48),
		BackgroundColor3 = C.white,
		ZIndex = 4,
	})
	pic.Parent = flip
	text({
		Name = "Name",
		Text = string.upper(it.name),
		Position = UDim2.new(0, 6, 1, -38),
		Size = UDim2.new(1, -12, 0, 22),
		fit = 18,
		TextColor3 = C.white,
		Font = Theme.Display,
		ZIndex = 4,
		Parent = flip,
	})
	text({
		Name = "Rarity",
		Text = RARITY[it.rarity] or "",
		Position = UDim2.new(0, 6, 1, -16),
		Size = UDim2.new(1, -12, 0, 12),
		TextSize = 11,
		TextColor3 = C.white,
		Font = Theme.Display,
		ZIndex = 4,
		Parent = flip,
	})
	return flip
end

-- Sparkles that fly out when the prize lands
local function sparkles(card)
	local burst = {}
	for i = 1, 18 do
		local sp = Theme.new("TextLabel", {
			Name = "Sparkle" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 175),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Text = i % 3 == 0 and "⭐" or "✨",
			TextSize = 18,
			TextTransparency = 1,
			ZIndex = 6,
			Parent = card,
		})
		local a = (i / 18) * math.pi * 2
		table.insert(burst, { sp = sp, dx = math.cos(a), dy = math.sin(a) })
	end
	return burst
end

function GiftController.show(g)
	close()
	if type(g) ~= "table" then
		return nil
	end
	local offer = g.offer and OFFERS[g.offer] and g
	local it
	if offer then
		local d = Shop.products[g.key]
		it = d and d.cosmetic and Cosmetics.get(d.cosmetic)
		if g.offer == "deal" and not it then
			return nil
		end
	else
		it = g.key and Cosmetics.get(g.key)
		if not g.nudge and not it then
			return nil
		end
	end
	shown = g
	local color = it and RARITY_COLOR[it.rarity] or GOLD
	screen = Theme.new("Frame", {
		Name = "GiftScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.35,
		Active = true,
		Parent = gui,
	})
	screen.Visible = not Layout.panel()
	Layout.modal("gift", screen) -- (the mouse comes free of first person while it's up, so the buttons can be clicked)
	-- the rays behind the card, turning
	local rays = Theme.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	for i = 1, 12 do
		Theme.new("Frame", {
			Name = "Ray" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(22, 900),
			Rotation = i * 15,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			Parent = rays,
		})
	end
	local card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(460, g.nudge and 250 or (offer and 420 or 430)),
		BackgroundColor3 = C.white,
		ZIndex = 2,
		Parent = screen,
	})
	local edge = card:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = color
		edge.Thickness = 4
	end
	local burst = {}
	local tick -- (the deal's countdown, stepped below)
	if offer then
		local o = OFFERS[g.offer]
		local price, was = o.price(g)
		text({
			Name = "Count",
			Text = o.top,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = 13,
			TextColor3 = C.red,
			Font = Theme.Display,
			ZIndex = 3,
			Parent = card,
		})
		text({
			Name = "Title",
			Text = o.title(it, g),
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 0, 40),
			fit = 28,
			Font = Theme.Display,
			ZIndex = 3,
			Parent = card,
		})
		if it then
			prize(card, it, color)
		else
			local box = Theme.new("Frame", {
				Name = "Prize",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 80),
				Size = UDim2.fromOffset(0, 190),
				BackgroundColor3 = GOLD,
				ClipsDescendants = true,
				ZIndex = 3,
				Parent = card,
			}, { Theme.corner(10), Theme.stroke(3, C.ink) })
			o.picture({
				Name = "Picture",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 1, -16),
				BackgroundColor3 = C.white,
				ZIndex = 4,
				Parent = box,
			})
		end
		burst = sparkles(card)
		local line = text({
			Name = "Line",
			Text = o.line(g, was),
			Position = UDim2.fromOffset(10, 274),
			Size = UDim2.new(1, -20, 0, 20),
			fit = 15,
			TextColor3 = C.red,
			Font = Theme.Display,
			ZIndex = 3,
			Parent = card,
		})
		if g.offer == "deal" and tonumber(g.ends) then
			tick = function()
				local left = tonumber(g.ends) - workspace:GetServerTimeNow()
				line.Text = left > 0 and `{o.line(g, was)}  ·  ENDS IN {PanelController.clock(left)}` or "DEAL OVER"
			end
			tick()
		end
		bigButton(
			card,
			"Equip",
			`BUY  {Format.robux(price)}`,
			300,
			EQUIP_SIZE.X,
			EQUIP_SIZE.Y,
			true,
			GiftController.buy
		)
		bigButton(card, "Later", "LATER", 370, 140, 30, false, GiftController.later)
	elseif g.nudge then
		text({
			Name = "Title",
			Text = "✨ NEW IN THE SHOP ✨",
			Position = UDim2.fromOffset(10, 24),
			Size = UDim2.new(1, -20, 0, 40),
			TextSize = 30,
			Font = Theme.Display,
			ZIndex = 3,
			Parent = card,
		})
		text({
			Name = "Line",
			Text = "Today's items just changed. Go see what's there!",
			Position = UDim2.fromOffset(20, 76),
			Size = UDim2.new(1, -40, 0, 40),
			fit = 16,
			TextColor3 = C.muted,
			ZIndex = 3,
			Parent = card,
		})
		bigButton(card, "Equip", "🛒 OPEN SHOP", 128, EQUIP_SIZE.X, EQUIP_SIZE.Y, true, GiftController.equip)
		bigButton(card, "Later", "LATER", 198, 140, 34, false, GiftController.later)
	else
		text({
			Name = "Count",
			Text = `FREE GIFT {g.count or 1} OF {g.of or 6}`,
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.new(1, -20, 0, 18),
			TextSize = 13,
			TextColor3 = C.muted,
			Font = Theme.Display,
			ZIndex = 3,
			Parent = card,
		})
		text({
			Name = "Title",
			Text = `🎁 YOU WON A FREE {KIND_WORD[it.kind] or "ITEM"}!`,
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 0, 40),
			fit = 30,
			Font = Theme.Display,
			ZIndex = 3,
			Parent = card,
		})
		prize(card, it, color)
		burst = sparkles(card)
		bigButton(card, "Equip", "✨ EQUIP IT", 284, EQUIP_SIZE.X, EQUIP_SIZE.Y, true, GiftController.equip)
		bigButton(card, "Later", "LATER", 352, 140, 30, false, GiftController.later)
		-- a tease: one of the Robux-only legends, a different one each gift
		local prem = Shop.PREMIUM[((g.count or 1) - 1) % math.max(1, #Shop.PREMIUM) + 1]
		if prem then
			local tease = Theme.new("TextButton", {
				Name = "Tease",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 390),
				Size = UDim2.fromOffset(420, 28),
				BackgroundTransparency = 1,
				Text = `or get ⚡ {string.upper(prem.name)}: {Format.robux(prem.robux)}`,
				Font = Theme.Display,
				TextSize = 13,
				TextColor3 = GOLD,
				Modal = true,
				ZIndex = 5,
				Parent = card,
			}, { Theme.textStroke(1.5, C.ink) })
			tease.Activated:Connect(function()
				Net.send("Buy", "robux", prem.key)
			end)
		end
	end
	Theme.pop(card)
	-- the moving bits: the rays turn, the prize flips over (0.25..0.6 s), the sparkles fly, EQUIP IT throbs
	local t0 = os.clock()
	local flipBox = card:FindFirstChild("Prize")
	local equipButton = card:FindFirstChild("Equip")
	stepper = RunService.RenderStepped:Connect(function()
		if not screen then
			return
		end
		local t = os.clock() - t0
		rays.Rotation = t * 18
		if tick then
			tick()
		end
		if flipBox then
			local k = math.clamp((t - 0.25) / 0.35, 0, 1)
			flipBox.Size = UDim2.fromOffset(240 * (1 - (1 - k) ^ 3), 190)
		end
		local b = math.clamp((t - 0.6) / 0.9, 0, 1)
		for _, s in burst do
			local d = 30 + b * 170
			s.sp.Position = UDim2.new(0.5, s.dx * d, 0, 175 + s.dy * d * 0.7)
			s.sp.TextTransparency = (b <= 0 or b >= 1) and 1 or b * 0.9
			s.sp.Rotation = b * 180
		end
		if equipButton then
			local p = 1 + 0.05 * math.sin(t * 5)
			equipButton.Size = UDim2.fromOffset(EQUIP_SIZE.X * p, EQUIP_SIZE.Y * p)
		end
	end)
	return screen
end

function GiftController.current()
	return shown, screen
end

function GiftController:init()
	gui = Theme.screen("Gift", 24, player:WaitForChild("PlayerGui"))
	Net.listen("Gift", function(g)
		if Layout.panel() then
			waiting = g -- (shown once the shop panel's closed)
		else
			GiftController.show(g)
		end
	end)
	Layout.onPanel(function(open)
		if screen then
			screen.Visible = not open
		elseif not open and waiting then
			local g = waiting
			waiting = nil
			GiftController.show(g)
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.match and partial.match.phase == "fight" and screen then
			close() -- (the next game's fight: the end screen's had its time)
		end
	end)
end

return GiftController

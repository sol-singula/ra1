-- Pop-up panels: Forge (start a forge, see the odds, take blasters out), Bag (your blasters: hold, power up,
-- sell), Shop (passes and gems), and the Forged reveal card. One panel at a time, sized for a phone.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blasters = require(ReplicatedStorage.Shared.Data.Blasters)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local HudController = require(script.Parent.HudController)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local PanelController = { Name = "PanelController", Order = 20 }

local gui, dim, card, titleLabel, body, header
local current, currentArg
local builders = {}
local forgePlanet -- planet key picked in the Forge panel
local forgeReceived

local HEADER_COLORS = {
	Forge = C.orange,
	Bag = C.purple,
	Shop = C.mustard,
	Forged = C.good,
	Quests = C.sky,
	Stall = C.teal,
	Booth = C.pink,
	Pets = C.pink,
	Eggs = C.pink,
}
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local stallPrice = 25 -- the gem price picked in the Stall panel

local function clearBody()
	for _, c in body:GetChildren() do
		if not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

function PanelController.close()
	current = nil
	dim.Visible = false
	ContextActionService:UnbindAction("ClosePanel")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

function PanelController.open(name, arg)
	if current == name and not arg then
		PanelController.close()
		return
	end
	current = name
	currentArg = arg
	dim.Visible = true
	header.BackgroundColor3 = HEADER_COLORS[name] or C.purple
	clearBody()
	builders[name](arg)
	dim.BackgroundTransparency = 1
	Theme.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
	Theme.pop(card)
	ContextActionService:BindActionAtPriority("ClosePanel", function(_, state)
		if state == Enum.UserInputState.Begin then
			PanelController.close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
end

local function refreshOpen()
	if current and current ~= "Forged" then
		clearBody()
		builders[current](currentArg)
	end
end

local function line(text, props)
	local t = Theme.text({
		Text = text,
		TextSize = 20,
		TextScaled = false,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
	for k, v in props or {} do
		t[k] = v
	end
	return t
end

local function headline(text, size, color)
	return Theme.title({
		Text = text,
		TextSize = size or 28,
		TextScaled = false,
		TextColor3 = color or C.white,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = body,
	})
end

local function list(padding)
	new("UIListLayout", {
		Padding = UDim.new(0, padding or 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})
end

-- A row card with a title on the left and buttons on the right.
local function row(name, color, order)
	local r = new("Frame", {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 74),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = body,
	}, { Theme.corner(14), Theme.stroke(3), Theme.gloss(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 205, 205)) })
	return r
end

local function rowButton(parent, name, text, color, x, w, onClick)
	local b = Theme.button({
		Name = name,
		Text = text,
		BackgroundColor3 = color,
		TextSize = 17,
		TextScaled = false,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(w or 110, 44),
		Position = UDim2.new(1, x, 0.5, 0),
		Parent = parent,
	})
	b.Activated:Connect(onClick)
	return b
end

-- Forge -------------------------------------------------------------------------------------------------------
builders.Forge = function()
	titleLabel.Text = "⚒️ THE FORGE"
	list(8)
	local s = Store.state
	local f = s.forge
	local unlocked = s.unlocked or 1
	if not Planets.byKey[forgePlanet] or Planets.indexOf[forgePlanet] > unlocked then
		forgePlanet = Planets.list[unlocked].key
	end
	local planet = Planets.byKey[forgePlanet]
	-- planet picker: which ore to use
	local picker = new(
		"Frame",
		{ Name = "Picker", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = body }
	)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = picker,
	})
	for i = 1, unlocked do
		local p = Planets.list[i]
		local b = Theme.button({
			Name = "Pick" .. p.key,
			Text = p.emoji .. " " .. p.name,
			BackgroundColor3 = p.key == forgePlanet and p.color or C.muted,
			TextSize = 16,
			TextScaled = false,
			Size = UDim2.fromOffset(104, 36),
			Parent = picker,
		})
		b.Activated:Connect(function()
			forgePlanet = p.key
			refreshOpen()
		end)
	end
	line(
		`You have 🪨 {Format.num(s.ore and s.ore[forgePlanet] or 0)} {planet.ore}`,
		{ TextColor3 = C.muted, LayoutOrder = 2 }
	)
	if f and f.luck then
		line(`🍀 LUCK ELIXIR on: {Format.time(f.luckLeft)} of better rolls`, { TextColor3 = C.good, LayoutOrder = 3 })
	end
	-- the slots: what's cooking
	local since = forgeReceived and os.clock() - forgeReceived or 0
	for i, slot in f and f.slots or {} do
		local r = row("Slot" .. i, C.slate, 10 + i)
		if slot and slot ~= false then
			local sp = Planets.byKey[slot.planet]
			local left = math.max(0, slot.left - since)
			Theme.title({
				Text = left > 0 and `{sp.emoji} {slot.tier} forge: {Format.time(left)}` or `✅ READY!`,
				TextSize = 22,
				TextScaled = false,
				Size = UDim2.new(1, -250, 1, 0),
				Position = UDim2.fromOffset(14, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			if left > 0 then
				rowButton(
					r,
					"FinishNow",
					`⏩ NOW R$ {slot.finishNow or Constants.FINISH_NOW_MIN}`,
					C.purple,
					-10,
					150,
					function()
						Net.send("FinishNow", i)
					end
				)
			else
				rowButton(r, "Claim", "🎁 TAKE OUT", C.good, -10, 150, function()
					Net.send("ClaimForge", i)
				end)
			end
		else
			Theme.title({
				Text = "Empty slot: pick a forge below",
				TextSize = 20,
				TextScaled = false,
				TextColor3 = C.muted,
				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.fromOffset(14, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
		end
	end
	-- the three forges
	for i, t in f and f.tiers or {} do
		local r = row("Tier_" .. t.key, planet.color, 20 + i)
		Theme.title({
			Text = `{t.emoji} {t.name}`,
			TextSize = 22,
			TextScaled = false,
			Size = UDim2.new(1, -250, 0, 32),
			Position = UDim2.fromOffset(14, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.text({
			Text = `🪨 {t.ore} ore · ⏱️ {Format.time(t.seconds)}`,
			TextSize = 17,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.5,
			Size = UDim2.new(1, -250, 0, 24),
			Position = UDim2.fromOffset(14, 40),
			Parent = r,
		})
		rowButton(r, "Odds", "ℹ️ Odds", C.sky, -124, 90, function()
			HudController.toast(`{t.name} odds: ` .. table.concat(t.odds, " · "), "info")
		end)
		rowButton(r, "Start", "FORGE!", C.good, -10, 106, function()
			Net.send("Forge", t.key, forgePlanet)
		end)
	end
	line(
		"Every forge shows its exact odds. Tap ℹ️ Odds.",
		{ TextColor3 = C.muted, TextSize = 16, LayoutOrder = 40 }
	)
end

-- Bag ---------------------------------------------------------------------------------------------------------
builders.Bag = function()
	titleLabel.Text = "🎒 MY BLASTERS"
	list(8)
	local s = Store.state
	local items = s.blasters or {}
	line(`{#items} / {s.maxBlasters or Constants.MAX_BLASTERS} blasters`, { TextColor3 = C.muted, LayoutOrder = 0 })
	for i, b in items do
		local rarity = Blasters.byRarity[b.rarity]
		local held = s.equipped == b.uid
		local r = row("Blaster" .. b.uid, rarity.color, i)
		Theme.title({
			Text = `{held and "👉 " or ""}{b.name} {b.stars}`,
			TextSize = 20,
			TextScaled = false,
			Size = UDim2.new(1, -330, 0, 30),
			Position = UDim2.fromOffset(12, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.text({
			Text = `{b.rarity} · 💥 {Format.num(b.damage)} · Power {b.lv}`,
			TextSize = 16,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.5,
			Size = UDim2.new(1, -330, 0, 22),
			Position = UDim2.fromOffset(12, 40),
			Parent = r,
		})
		rowButton(r, "Sell", `💰 {Format.num(b.sell)}`, C.red, -10, 96, function()
			Net.send("Sell", b.uid)
		end)
		rowButton(
			r,
			"PowerUp",
			b.powerUp and `⬆️ {Format.num(b.powerUp)}` or "⬆️ MAX",
			C.sky,
			-112,
			110,
			function()
				Net.send("PowerUp", b.uid)
			end
		)
		if not held then
			rowButton(r, "Hold", "HOLD", C.good, -228, 84, function()
				Net.send("Equip", b.uid)
			end)
		end
		-- reroll a stat for gems
		local rr = new("Frame", {
			Name = "Reroll" .. b.uid,
			LayoutOrder = i,
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundTransparency = 1,
			Parent = body,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = rr,
		})
		for _, stat in Constants.ROLL_STATS do
			local g = b.roll[stat]
			local btn = Theme.button({
				Name = "Reroll_" .. stat,
				Text = `{Blasters.StatEmoji[stat]} {string.upper(g)} 🎲{Constants.REROLL_GEMS}💎`,
				BackgroundColor3 = g == "god" and C.mustard or (g == "shiny" and C.sky or C.muted),
				TextSize = 14,
				TextScaled = false,
				Size = UDim2.fromOffset(140, 34),
				Parent = rr,
			})
			btn.Activated:Connect(function()
				Net.send("Reroll", b.uid, stat)
			end)
		end
	end
end

-- Quests and the daily gift --------------------------------------------------------------------------------------
builders.Quests = function()
	titleLabel.Text = "📜 DAILY QUESTS"
	list(8)
	local s = Store.state
	local d = s.daily
	if d then
		local r = row("Daily", d.canClaim and C.pink or C.muted, 0)
		Theme.title({
			Text = d.canClaim and `🎁 Day {d.nextDay} gift: {d.gift}`
				or `🎁 Day {d.streak} claimed · next in {Format.time(d.secondsToNext)}`,
			TextSize = 20,
			TextScaled = false,
			Size = UDim2.new(1, -160, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		if d.canClaim then
			rowButton(r, "Claim", "CLAIM!", C.good, -10, 130, function()
				Net.send("ClaimDaily")
			end)
		end
	end
	line("Three new quests every day. Each one pays gems. 💎", { TextColor3 = C.muted, LayoutOrder = 1 })
	for i, q in s.quests or {} do
		local r = row("Quest" .. i, q.done and C.muted or C.sky, 10 + i)
		Theme.title({
			Text = (q.done and "✅ " or "") .. q.text,
			TextSize = 21,
			TextScaled = false,
			Size = UDim2.new(1, -150, 0, 32),
			Position = UDim2.fromOffset(12, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		local bar, fill = Theme.bar(
			{ Name = "Bar", Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(12, 44), Parent = r },
			C.good
		)
		fill.Size = UDim2.new(math.clamp(q.progress / q.target, 0, 1), 0, 1, 0)
		Theme.title({
			Text = `{q.progress} / {q.target}`,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			outline = 1.5,
			ZIndex = 3,
			Parent = bar,
		})
		Theme.title({
			Text = `+{q.gems} 💎`,
			TextSize = 24,
			TextScaled = false,
			TextColor3 = Color3.fromRGB(150, 230, 255),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(120, 40),
			Position = UDim2.new(1, -10, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
	end
end

-- Shop --------------------------------------------------------------------------------------------------------
builders.Shop = function()
	titleLabel.Text = "🛒 SHOP"
	list(8)
	local s = Store.state
	for i, p in Shop.Passes do
		local owned = (s.passes or {})[p.key]
		local r = row("Pass" .. p.key, owned and C.muted or C.purple, i)
		Theme.title({
			Text = p.name,
			TextSize = 22,
			TextScaled = false,
			Size = UDim2.new(1, -170, 0, 32),
			Position = UDim2.fromOffset(14, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.text({
			Text = p.desc,
			TextSize = 16,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.5,
			Size = UDim2.new(1, -170, 0, 22),
			Position = UDim2.fromOffset(14, 40),
			Parent = r,
		})
		rowButton(r, "Buy", owned and "OWNED" or `R$ {p.price}`, owned and C.muted or C.good, -10, 130, function()
			if not owned then
				Net.send("Purchase", "pass", p.key)
			end
		end)
	end
	for i, p in Shop.Products do
		local r = row("Product" .. p.key, C.sky, 20 + i)
		Theme.title({
			Text = p.name,
			TextSize = 22,
			TextScaled = false,
			Size = UDim2.new(1, -170, 0, 32),
			Position = UDim2.fromOffset(14, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.text({
			Text = p.desc or `{p.gems} gems`,
			TextSize = 16,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.5,
			Size = UDim2.new(1, -170, 0, 22),
			Position = UDim2.fromOffset(14, 40),
			Parent = r,
		})
		rowButton(r, "Buy", `R$ {p.price}`, C.good, -10, 130, function()
			Net.send("Purchase", "product", p.key)
		end)
	end
end

-- Pets and eggs --------------------------------------------------------------------------------------------------------
builders.Pets = function()
	titleLabel.Text = "🐾 MY PETS"
	list(8)
	local v = Store.state.petView or { pets = {}, slots = 1 }
	line(
		`{#v.pets} pets · {v.slots} out at a time · +{math.floor((v.bonusDmg or 0) * 100)}% damage, +{math.floor(
			(v.bonusLuck or 0) * 100
		)}% luck`,
		{ TextColor3 = C.muted, LayoutOrder = 0 }
	)
	local eggs = Theme.button({
		Name = "OpenEggs",
		Text = "🥚 GET EGGS",
		BackgroundColor3 = C.pink,
		Size = UDim2.fromOffset(240, 50),
		round = true,
		LayoutOrder = 1,
		Parent = body,
	})
	eggs.Activated:Connect(function()
		PanelController.open("Eggs")
	end)
	for i, p in v.pets do
		local r = row("Pet" .. p.uid, Pets.RarityColor[p.rarity] or C.muted, 10 + i)
		Theme.title({
			Text = `{p.out and "👉 " or ""}{p.name}`,
			TextSize = 20,
			TextScaled = false,
			Size = UDim2.new(1, -150, 0, 30),
			Position = UDim2.fromOffset(12, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.text({
			Text = `{p.rarity} · +{math.floor(p.dmg * 100)}% damage · +{math.floor(p.luck * 100)}% luck`,
			TextSize = 16,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.5,
			Size = UDim2.new(1, -150, 0, 22),
			Position = UDim2.fromOffset(12, 40),
			Parent = r,
		})
		rowButton(r, "Toggle", p.out and "PUT AWAY" or "TAKE OUT", p.out and C.orange or C.good, -10, 130, function()
			Net.send("EquipPet", p.uid, not p.out)
		end)
	end
end

builders.Eggs = function()
	titleLabel.Text = "🥚 EGG MACHINE"
	list(8)
	local v = Store.state.petView or { eggs = {} }
	if v.canRandom == false then
		line("Eggs aren't allowed on your account.", { TextColor3 = C.red })
		return
	end
	line(
		`You have 💎 {Format.num(Store.state.gems or 0)}. Every egg shows its odds.`,
		{ TextColor3 = C.muted, LayoutOrder = 0 }
	)
	for i, e in v.eggs or {} do
		local r = row("Egg" .. e.key, C.pink, 10 + i)
		Theme.title({
			Text = `{e.emoji} {e.name}`,
			TextSize = 22,
			TextScaled = false,
			Size = UDim2.new(1, -250, 0, 32),
			Position = UDim2.fromOffset(14, 4),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		Theme.text({
			Text = table.concat(e.odds, " · "),
			TextSize = 15,
			TextScaled = false,
			TextColor3 = C.white,
			outline = 1.5,
			Size = UDim2.new(1, -250, 0, 24),
			Position = UDim2.fromOffset(14, 40),
			Parent = r,
		})
		rowButton(r, "Odds", "ℹ️ Odds", C.sky, -124, 90, function()
			HudController.toast(`{e.name} odds: ` .. table.concat(e.odds, " · "), "info")
		end)
		rowButton(r, "Buy", `💎 {e.gems}`, C.good, -10, 106, function()
			Net.send("BuyEgg", e.key)
		end)
	end
end

-- Trade Plaza stall -------------------------------------------------------------------------------------------------
builders.Stall = function(index)
	local s = Store.state
	local stall = (s.stalls or {})[index]
	titleLabel.Text = `🏪 STALL {index}`
	list(8)
	if s.canTrade == false then
		line("Trading isn't allowed on your account.", { TextColor3 = C.red })
		return
	end
	if stall and stall ~= false then
		local mine = stall.sellerId == player.UserId
		local rarity = Blasters.byRarity[stall.rarity]
		headline(`{stall.name} {stall.stars}`, 30, rarity and rarity.color or C.white)
		line(`{stall.rarity} · 💥 {Format.num(stall.damage)} damage · by {stall.seller}`, { TextColor3 = C.muted })
		headline(`💎 {stall.price} gems`, 34, Color3.fromRGB(150, 230, 255))
		local b = Theme.button({
			Name = mine and "TakeBack" or "BuyStall",
			Text = mine and "TAKE IT BACK" or `BUY for {stall.price} 💎`,
			BackgroundColor3 = mine and C.orange or C.good,
			Size = UDim2.fromOffset(300, 60),
			round = true,
			Parent = body,
		})
		b.Activated:Connect(function()
			Net.send(mine and "Unlist" or "BuyStall", index)
			PanelController.close()
		end)
		if not mine then
			line(
				`You have 💎 {Format.num(s.gems or 0)}. The seller gets {math.floor(
					stall.price * (1 - Constants.TRADE_TAX) + 0.5
				)} (10% goes to the Plaza).`,
				{ TextColor3 = C.muted, TextSize = 16 }
			)
		end
		return
	end
	line(
		"Pick a blaster and a gem price. Buyers pay you in gems (minus 10%).",
		{ TextColor3 = C.muted, LayoutOrder = 0 }
	)
	local picker = new(
		"Frame",
		{ Name = "Prices", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 1, Parent = body }
	)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = picker,
	})
	for _, price in Constants.STALL_PRICES do
		local pb = Theme.button({
			Name = "Price" .. price,
			Text = `💎{price}`,
			BackgroundColor3 = price == stallPrice and C.teal or C.muted,
			TextSize = 15,
			TextScaled = false,
			Size = UDim2.fromOffset(66, 36),
			Parent = picker,
		})
		pb.Activated:Connect(function()
			stallPrice = price
			refreshOpen()
		end)
	end
	for i, b in s.blasters or {} do
		if b.rarity ~= "Ultra" then
			local rarity = Blasters.byRarity[b.rarity]
			local r = row("Sell" .. b.uid, rarity.color, 10 + i)
			Theme.title({
				Text = `{b.name} {b.stars}`,
				TextSize = 20,
				TextScaled = false,
				Size = UDim2.new(1, -170, 0, 30),
				Position = UDim2.fromOffset(12, 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = r,
			})
			Theme.text({
				Text = `{b.rarity} · 💥 {Format.num(b.damage)}`,
				TextSize = 16,
				TextScaled = false,
				TextColor3 = C.white,
				outline = 1.5,
				Size = UDim2.new(1, -170, 0, 22),
				Position = UDim2.fromOffset(12, 40),
				Parent = r,
			})
			rowButton(r, "List", `SELL 💎{stallPrice}`, C.good, -10, 150, function()
				Net.send("ListStall", index, b.uid, stallPrice)
				PanelController.close()
			end)
		end
	end
end

-- Booth Street booth -------------------------------------------------------------------------------------------------
builders.Booth = function(index)
	local s = Store.state
	local booth = (s.booths or {})[index]
	titleLabel.Text = `🛍️ BOOTH {index}`
	list(8)
	local mine = booth and booth ~= false and booth.ownerId == player.UserId
	if booth and booth ~= false and not mine then
		headline(booth.name or (booth.owner .. "'s booth"), 28, C.white)
		if booth.assetId then
			line(booth.message or "", { TextColor3 = C.muted })
			headline(`R$ {booth.price}`, 34, C.good)
			local b = Theme.button({
				Name = "BuyBooth",
				Text = `BUY for R$ {booth.price}`,
				BackgroundColor3 = C.good,
				Size = UDim2.fromOffset(300, 60),
				round = true,
				Parent = body,
			})
			b.Activated:Connect(function()
				Net.send("BuyBooth", index)
				PanelController.close()
			end)
			line(`Made by {booth.owner}. Roblox's own buy window opens next.`, { TextColor3 = C.muted, TextSize = 16 })
		else
			line(`{booth.owner} is setting up.`, { TextColor3 = C.muted })
		end
		return
	end
	if not mine then
		line(
			"Claim this booth to show one of your own clothes or accessories. Other players can buy it here!",
			{ TextColor3 = C.muted }
		)
		local b = Theme.button({
			Name = "ClaimBooth",
			Text = "CLAIM THIS BOOTH",
			BackgroundColor3 = C.pink,
			Size = UDim2.fromOffset(320, 60),
			round = true,
			Parent = body,
		})
		b.Activated:Connect(function()
			Net.send("ClaimBooth", index)
		end)
		if index <= 4 then
			line("Front booths (1 to 4) need the Booth Rank pass.", { TextColor3 = C.muted, TextSize = 16 })
		end
		return
	end
	line(
		"Your booth! Paste the ID of a shirt, pants, hat or accessory YOU made, and a short message.",
		{ TextColor3 = C.muted }
	)
	local idBox = new("TextBox", {
		Name = "AssetId",
		PlaceholderText = "Item ID (numbers)",
		Text = booth.assetId and tostring(booth.assetId) or "",
		Font = Theme.Body,
		TextSize = 22,
		TextColor3 = C.ink,
		BackgroundColor3 = C.white,
		Size = UDim2.fromOffset(420, 46),
		ClearTextOnFocus = false,
		Parent = body,
	}, { Theme.corner(12), Theme.stroke(3) })
	local msgBox = new("TextBox", {
		Name = "Message",
		PlaceholderText = "Your message (optional)",
		Text = booth.message or "",
		Font = Theme.Body,
		TextSize = 20,
		TextColor3 = C.ink,
		BackgroundColor3 = C.white,
		Size = UDim2.fromOffset(420, 46),
		ClearTextOnFocus = false,
		Parent = body,
	}, { Theme.corner(12), Theme.stroke(3) })
	local setB = Theme.button({
		Name = "SetBooth",
		Text = "SHOW IT!",
		BackgroundColor3 = C.good,
		Size = UDim2.fromOffset(260, 56),
		round = true,
		Parent = body,
	})
	setB.Activated:Connect(function()
		local id = tonumber(string.match(idBox.Text or "", "%d+"))
		if id then
			Net.send("SetBooth", index, id, msgBox.Text)
		else
			HudController.toast("Type the item's ID number first.", "bad")
		end
	end)
	if booth.assetId then
		line(`Showing: {booth.name} · R$ {booth.price}`, { TextColor3 = C.good })
	end
	local leave = Theme.button({
		Name = "LeaveBooth",
		Text = "Give the booth up",
		BackgroundColor3 = C.red,
		TextSize = 18,
		TextScaled = false,
		Size = UDim2.fromOffset(240, 44),
		round = true,
		Parent = body,
	})
	leave.Activated:Connect(function()
		Net.send("LeaveBooth", index)
		PanelController.close()
	end)
end

-- Forged reveal -------------------------------------------------------------------------------------------------
builders.Forged = function(b)
	titleLabel.Text = "⚒️ YOU FORGED..."
	list(10)
	local rarity = Blasters.byRarity[b.rarity]
	headline(string.upper(b.rarity), 30, rarity.color)
	headline(`{b.name} {b.stars}`, 34)
	for _, stat in Constants.ROLL_STATS do
		local g = b.roll[stat]
		line(
			`{Blasters.StatEmoji[stat]} {Blasters.StatName[stat]}: {string.upper(g)}`,
			{ TextColor3 = Blasters.GradeColor[g], TextSize = 22 }
		)
	end
	line(`💥 {Format.num(b.damage)} damage`, { TextColor3 = C.white, TextSize = 24 })
	local ok = Theme.button({
		Name = "Ok",
		Text = "NICE!",
		BackgroundColor3 = C.good,
		Size = UDim2.fromOffset(220, 56),
		round = true,
		Parent = body,
	})
	ok.Activated:Connect(PanelController.close)
end

function PanelController:init()
	gui = Theme.screen("Panels", 5, player:WaitForChild("PlayerGui"))
	dim = new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	dim.Activated:Connect(PanelController.close)
	card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(620, 470),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = dim,
	})
	header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = C.purple,
		BorderSizePixel = 0,
		Parent = card,
	}, { Theme.corner(18), Theme.gloss() })
	titleLabel = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -80, 1, -12),
		Position = UDim2.fromOffset(20, 6),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "✕",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(50, 50),
		Position = UDim2.new(1, 8, 0, -8),
		round = true,
		Parent = card,
	})
	close.Activated:Connect(PanelController.close)
	body = new("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 76),
		Size = UDim2.new(1, -28, 1, -88),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = card,
	}, { new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }) })
	HudController.openPanel = PanelController.open
	Store.Changed:Connect(function(partial)
		if partial.forge ~= nil then
			forgeReceived = os.clock()
		end
		if
			current
			and (
				partial.forge
				or partial.blasters
				or partial.ore
				or partial.passes
				or partial.unlocked
				or partial.quests
				or partial.daily
				or partial.stalls
				or partial.booths
				or partial.petView
				or partial.gems
				or partial.equipped ~= nil
			)
		then
			refreshOpen()
		end
	end)
	Net.listen("Forged", function(b)
		PanelController.open("Forged", b)
	end)
	-- the Forge's prompt in the Hub opens the panel
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(prompt)
			if prompt.Name == "Prompt_forge" then
				PanelController.open("Forge")
			elseif prompt.Name == "Prompt_stall" then
				PanelController.open("Stall", tonumber(string.match(prompt.ObjectText, "%d+")))
			elseif prompt.Name == "Prompt_booth" then
				PanelController.open("Booth", tonumber(string.match(prompt.ObjectText, "%d+")))
			elseif prompt.Name == "Prompt_eggs" then
				PanelController.open("Eggs")
			end
		end)
	end)
	-- the forge timers tick while the panel is open
	task.spawn(function()
		while true do
			task.wait(1)
			if current == "Forge" then
				refreshOpen()
			end
		end
	end)
end

return PanelController

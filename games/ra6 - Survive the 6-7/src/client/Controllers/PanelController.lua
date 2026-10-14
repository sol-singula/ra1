--[[
The panels (master plan §6: the inventory must be clear and fast to manage; §9: progress you can see; §12: friends
first). One open at a time, big tap targets, closes with X, Escape or B:

  BAG          the hotbar, the backpack and your equipment: tap a slot to see the item, tap another to move or
               swap it; USE / EQUIP / DROP. The inventory rules, in one line each.
  CRAFT        opens at a station (the workbench, the anvil, the cookpot, the campfire): what it can make, what each
               costs (counting the camp chest), locked recipes and the tier they need
  CHEST        the camp's storage chest: take things out, put things in, PUT ALL resources
  CAMP         the camp's tier, what the next one needs, UPGRADE
  ME           your level, your starting kit, perks, weapon mastery, looks and titles, your records
  BOOK         the bestiary (every monster you've met, its tells you've read), items found, findings visited,
               Kermy's diary, achievements
  TOP          the leaderboards: eight categories, friends first, then everyone
  FRIENDS      friends playing now and how their run is going; join them, find a new run, start a private one
  MORE         settings (music, screen shake, effects), how to play, invite friends
And the cards that pop up: the end of a run (RESULTS), "Do you like the game?", notifications.
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Camp = require(ReplicatedStorage.Shared.Data.Camp)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Enemies = require(ReplicatedStorage.Shared.Data.Enemies)
local Findings = require(ReplicatedStorage.Shared.Data.Findings)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local NotifyController = require(script.Parent.NotifyController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local PanelController = { Name = "PanelController", Order = 12 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local open -- { name, frame, body, refresh, arg }
local picked -- the inventory slot picked (to move)
local cards = {}

local function rarity(item)
	return item and Items.RARITY[item.rarity] or Items.RARITY.common
end

-- Building blocks ------------------------------------------------------------------------------------------------------------------
function PanelController.close()
	if open then
		open.frame:Destroy()
		open = nil
	end
	picked = nil
end

local function panel(name, title, w, h)
	PanelController.close()
	local frame = Theme.card({
		Name = "Panel_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(w or 780, h or 470),
		Parent = gui,
	})
	local head = new("Frame", {
		Name = "Head",
		BackgroundColor3 = C.slate,
		Size = UDim2.new(1, 0, 0, 52),
		Parent = frame,
	}, { Theme.corner(18) })
	new("Frame", {
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -16),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = head,
	})
	Theme.title({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -100, 1, -12),
		Position = UDim2.fromOffset(18, 6),
		outline = 3,
		Parent = head,
	})
	local x = Theme.button({
		Name = "Close",
		Text = "✕",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(44, 40),
		Parent = head,
	})
	Theme.keyHint(x, "Esc", "B")
	x.Activated:Connect(PanelController.close)
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 60),
		Size = UDim2.new(1, -28, 1, -72),
		Parent = frame,
	})
	Theme.pop(frame)
	open = { name = name, frame = frame, body = body }
	pcall(function()
		GuiService.SelectedObject = x
	end)
	return body, frame
end

local function scroller(parent, props)
	local s = new("ScrollingFrame", {
		Name = props.Name or "List",
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.muted,
		Parent = parent,
	})
	if props.grid then
		new("UIGridLayout", {
			CellSize = props.grid,
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = s,
		})
	else
		new(
			"UIListLayout",
			{ Padding = UDim.new(0, props.gap or 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s }
		)
	end
	return s
end

local function rowFrame(parent, h, order, color)
	local r = new("Frame", {
		Name = "Row",
		LayoutOrder = order or 0,
		BackgroundColor3 = color or Color3.fromRGB(240, 230, 210),
		Size = UDim2.new(1, -10, 0, h or 54),
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2) })
	return r
end

local function label(parent, text, props)
	props = props or {}
	props.Text = text
	props.Parent = parent
	props.TextColor3 = props.TextColor3 or C.ink
	return Theme.text(props)
end

local function tabs(parent, list, selected, onPick)
	local bar =
		new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = parent })
	local w = 1 / #list
	for i, t in list do
		local b = Theme.button({
			Name = "Tab_" .. t.key,
			Text = t.label,
			BackgroundColor3 = t.key == selected and C.mustard or C.white,
			dark = t.key ~= selected,
			Size = UDim2.new(w, -6, 1, 0),
			Position = UDim2.new((i - 1) * w, 0, 0, 0),
			Parent = bar,
		})
		b.Activated:Connect(function()
			onPick(t.key)
		end)
	end
	return bar
end

local function itemCell(parent, slotId, slot, order, onClick)
	local item = slot and Items.get(slot.key)
	local r = rarity(item)
	local b = new("TextButton", {
		Name = "Slot_" .. slotId,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order or 0,
		BackgroundColor3 = item and Theme.darken(r.color, 0.5) or Color3.fromRGB(70, 70, 90),
		Size = UDim2.fromOffset(62, 62),
		Parent = parent,
	}, { Theme.corner(12) })
	local stroke =
		Theme.stroke(picked == slotId and 5 or 3, picked == slotId and C.mustard or (item and r.color or C.ink))
	stroke.Parent = b
	Theme.text({
		Name = "Icon",
		Text = item and item.icon or "",
		Size = UDim2.new(1, -8, 1, -16),
		Position = UDim2.fromOffset(4, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = b,
	})
	Theme.title({
		Name = "Count",
		Text = (slot and slot.n > 1) and tostring(slot.n) or "",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromOffset(40, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		outline = 2,
		Parent = b,
	})
	b.Activated:Connect(function()
		onClick(slotId, slot)
	end)
	return b
end

local function countOf(key)
	local n = 0
	for _, s in Store.get("inv").slots do
		if s.key == key then
			n += s.n
		end
	end
	return n
end

local function available(key)
	return countOf(key) + ((Store.get("storage") or {})[key] or 0)
end

-- What something costs, one chip per material: its icon, its name and have/need (green once you have enough).
local function costChips(parent, cost, pos)
	local x = 0
	local keys = {}
	for k in cost do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in keys do
		local item = Items.get(k)
		local have = available(k)
		local ok = have >= cost[k]
		local chip =
			label(parent, `{item and item.icon or ""} {item and item.name or k} {math.min(have, cost[k])}/{cost[k]}`, {
				Name = "Cost_" .. k,
				Position = UDim2.new(pos.X.Scale, pos.X.Offset + x, pos.Y.Scale, pos.Y.Offset),
				Size = UDim2.fromOffset(150, 22),
				TextSize = 15,
				TextColor3 = ok and Color3.fromRGB(30, 130, 60) or C.red,
				Font = Theme.Display,
			})
		chip:SetAttribute("Have", have)
		chip:SetAttribute("Need", cost[k])
		x += 152
	end
end

-- BAG ----------------------------------------------------------------------------------------------------------------------------------------------
local function inventoryPanel()
	local body = panel("inventory", "🎒 YOUR STUFF", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local inv = Store.get("inv")
		local left =
			new("Frame", { Name = "Slots", BackgroundTransparency = 1, Size = UDim2.new(0.62, 0, 1, 0), Parent = body })
		local right = new("Frame", {
			Name = "Detail",
			BackgroundTransparency = 1,
			Position = UDim2.new(0.64, 0, 0, 0),
			Size = UDim2.new(0.36, 0, 1, 0),
			Parent = body,
		})
		local function click(slotId, slot)
			if picked and picked ~= slotId then
				Net.send("Move", picked, slotId)
				Bus.Tap:Fire("inv_move")
				picked = nil
			else
				picked = slotId
			end
			refresh()
			_ = slot
		end
		label(left, "HOTBAR", { Size = UDim2.new(1, 0, 0, 18), Font = Theme.Display })
		local hot = new("Frame", {
			Name = "Hotbar",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 66),
			Parent = left,
		})
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = hot })
		for i = 1, Constants.HOTBAR do
			itemCell(hot, "h" .. i, inv.slots["h" .. i], i, click)
		end
		label(
			left,
			`BACKPACK ({inv.capacity or 12} slots)`,
			{ Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Display }
		)
		local pack = scroller(left, {
			Name = "Backpack",
			Position = UDim2.fromOffset(0, 112),
			Size = UDim2.new(1, 0, 1, -200),
			grid = UDim2.fromOffset(62, 62),
		})
		for i = 1, inv.capacity or 12 do
			itemCell(pack, "b" .. i, inv.slots["b" .. i], i, click)
		end
		label(left, "WEARING", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -66),
			Size = UDim2.new(1, 0, 0, 18),
			Font = Theme.Display,
		})
		local gear = new("Frame", {
			Name = "Gear",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 64),
			Parent = left,
		})
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = gear })
		for i, id in { "armor", "pack", "charm" } do
			local cell = itemCell(gear, id, inv.slots[id], i, click)
			if not inv.slots[id] then
				cell.Icon.Text = id == "armor" and "🦺" or id == "pack" and "🎒" or "🍀"
				cell.Icon.TextTransparency = 0.6
			end
		end
		-- the picked item
		local slot = picked and inv.slots[picked]
		local item = slot and Items.get(slot.key)
		if item then
			local r = rarity(item)
			Theme.text({
				Name = "Big",
				Text = item.icon,
				Size = UDim2.new(1, 0, 0, 60),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = right,
			})
			label(right, item.name, {
				Name = "ItemName",
				Position = UDim2.fromOffset(0, 62),
				Size = UDim2.new(1, 0, 0, 28),
				Font = Theme.Display,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			label(right, string.upper(r.name), {
				Name = "Rarity",
				Position = UDim2.fromOffset(0, 90),
				Size = UDim2.new(1, 0, 0, 18),
				TextColor3 = Theme.darken(r.color, 0.15),
				Font = Theme.Display,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local stats = {}
			if item.dmg then
				table.insert(stats, `⚔️ {item.dmg} damage · {math.floor(1 / item.cd * 10) / 10}/s`)
			end
			if item.heal then
				table.insert(stats, `💚 heals {item.heal}`)
			end
			if item.armor then
				table.insert(stats, `🦺 {math.floor(item.armor * 100)}% off every hit`)
			end
			if item.slots then
				table.insert(stats, `🎒 +{item.slots} slots`)
			end
			label(right, item.desc .. (#stats > 0 and ("\n" .. table.concat(stats, "\n")) or ""), {
				Name = "Desc",
				Position = UDim2.fromOffset(0, 112),
				Size = UDim2.new(1, 0, 0, 110),
				TextSize = 16,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			local y = 230
			local function act(name, text, color, fn)
				local b = Theme.button({
					Name = name,
					Text = text,
					BackgroundColor3 = color,
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.new(1, 0, 0, 44),
					Parent = right,
				})
				b.Activated:Connect(fn)
				y += 50
			end
			if item.kind == "food" or item.kind == "support" or item.key == "ranger_map" then
				act("Use", item.kind == "food" and "🍽️ EAT" or "✨ USE", C.good, function()
					Net.send("Use", picked)
				end)
			end
			if Items.isEquipment(item) then
				act(
					"Equip",
					(picked == "armor" or picked == "pack" or picked == "charm") and "TAKE OFF" or "🧥 WEAR",
					C.sky,
					function()
						Net.send("Move", picked, "equip")
						picked = nil
					end
				)
			end
			act("Drop", "⬇️ DROP", C.red, function()
				Net.send("Drop", picked, slot.n)
				picked = nil
			end)
		else
			label(
				right,
				"Tap an item to see it. Tap another slot to move it there.\n\n• What you carry belongs to this run.\n• Go down and bleed out: your pack drops where you fell.\n• Leave mid-run: your things wait by the fire.\n• Everything you find is saved in your collection forever.",
				{
					Name = "Rules",
					Size = UDim2.new(1, 0, 1, 0),
					TextSize = 16,
					TextYAlignment = Enum.TextYAlignment.Top,
				}
			)
		end
	end
	open.refresh = refresh
	refresh()
end

-- CRAFT ----------------------------------------------------------------------------------------------------------------------------------------------
local function craftPanel(station)
	local st = Recipes.STATIONS[station] or Recipes.STATIONS.workbench
	local body = panel("craft", `{st.icon} {string.upper(st.name)}`, 760, 470)
	open.arg = station
	local function refresh()
		body:ClearAllChildren()
		local camp = Store.get("camp") or {}
		local tier = camp.tier or 1
		label(
			body,
			"Materials come from your backpack first, then the camp chest.",
			{ Size = UDim2.new(1, 0, 0, 20), TextSize = 16 }
		)
		local list = scroller(body, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26) })
		for i, r in Recipes.byStation[station] or {} do
			local item = Items.get(r.item)
			local row = rowFrame(list, 62, i, r.tier > tier and Color3.fromRGB(210, 205, 200) or nil)
			Theme.text({
				Text = item.icon,
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.fromOffset(50, 50),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = row,
			})
			label(row, item.name .. (r.count > 1 and (" ×" .. r.count) or ""), {
				Position = UDim2.fromOffset(64, 6),
				Size = UDim2.fromOffset(250, 24),
				Font = Theme.Display,
				TextColor3 = Theme.darken(rarity(item).color, 0.3),
			})
			if r.tier > tier then
				label(
					row,
					`🔒 Needs {Camp.TIERS[r.tier].name}`,
					{ Position = UDim2.fromOffset(64, 32), Size = UDim2.fromOffset(300, 22), TextColor3 = C.muted }
				)
			else
				costChips(row, r.cost, UDim2.fromOffset(64, 32))
			end
			local can = r.tier <= tier
			for k, n in r.cost do
				if available(k) < n then
					can = false
				end
			end
			local b = Theme.button({
				Name = "Craft_" .. r.item,
				Text = "MAKE",
				BackgroundColor3 = can and C.good or C.muted,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(110, 44),
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Craft", r.id)
				Bus.Tap:Fire("craft_" .. r.item)
			end)
		end
	end
	open.refresh = refresh
	refresh()
end

-- CHEST -----------------------------------------------------------------------------------------------------------------------------------------------
local function chestPanel()
	local body = panel("storage", "🧰 THE CAMP CHEST", 780, 470)
	local function refresh()
		body:ClearAllChildren()
		local storage = Store.get("storage") or {}
		local inv = Store.get("inv")
		label(
			body,
			"IN THE CHEST (safe if you go down; stations use it)",
			{ Size = UDim2.new(0.5, -6, 0, 20), Font = Theme.Display, TextSize = 15 }
		)
		label(body, "YOURS", {
			Position = UDim2.new(0.5, 6, 0, 0),
			Size = UDim2.new(0.5, -6, 0, 20),
			Font = Theme.Display,
			TextSize = 15,
		})
		local left =
			scroller(body, { Name = "Chest", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(0.5, -6, 1, -76) })
		local right =
			scroller(body, { Name = "Mine", Position = UDim2.new(0.5, 6, 0, 24), Size = UDim2.new(0.5, -6, 1, -76) })
		local keys = {}
		for k in storage do
			table.insert(keys, k)
		end
		table.sort(keys)
		for i, k in keys do
			local item = Items.get(k)
			local row = rowFrame(left, 46, i)
			label(
				row,
				`{item.icon} {item.name} ×{storage[k]}`,
				{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -110, 1, -8), Font = Theme.Display }
			)
			local b = Theme.button({
				Name = "Take_" .. k,
				Text = "TAKE",
				BackgroundColor3 = C.sky,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(90, 36),
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Store", "take", k, storage[k])
			end)
		end
		local order = 0
		for id, s in inv.slots do
			order += 1
			local item = Items.get(s.key)
			if item then
				local row = rowFrame(right, 46, order)
				label(
					row,
					`{item.icon} {item.name} ×{s.n}`,
					{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -110, 1, -8), Font = Theme.Display }
				)
				local b = Theme.button({
					Name = "Put_" .. id,
					Text = "PUT",
					BackgroundColor3 = C.orange,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Size = UDim2.fromOffset(90, 36),
					Parent = row,
				})
				b.Activated:Connect(function()
					Net.send("Store", "put", id, s.n)
				end)
			end
		end
		local all = Theme.button({
			Name = "PutAll",
			Text = "📦 PUT ALL RESOURCES IN",
			BackgroundColor3 = C.good,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(340, 44),
			Parent = body,
		})
		all.Activated:Connect(function()
			Net.send("Store", "all")
		end)
	end
	open.refresh = refresh
	refresh()
end

-- CAMP -------------------------------------------------------------------------------------------------------------------------------------------------
local function campPanel()
	local body = panel("camp", "🏕️ THE CAMP", 720, 450)
	local function refresh()
		body:ClearAllChildren()
		local camp = Store.get("camp") or {}
		label(
			body,
			`{camp.tierName or "The Campsite"} · tier {camp.tier or 1} of 4`,
			{ Size = UDim2.new(1, 0, 0, 30), Font = Theme.Display }
		)
		local nxt = camp.next
		if not nxt then
			label(
				body,
				"The camp is a Stronghold! Raise the Totem of the Seventh Night and stock up for Mega Kermy.",
				{ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 60), TextSize = 18 }
			)
			return
		end
		label(body, `NEXT: {nxt.name}`, {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 26),
			Font = Theme.Display,
			TextColor3 = C.orange,
		})
		label(body, nxt.desc, { Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 40), TextSize = 16 })
		local y = 112
		label(
			body,
			"First build:",
			{ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Display }
		)
		y += 24
		local ready = true
		for key, r in nxt.requires or {} do
			local def = Camp.STRUCTURES[key]
			local name = key == "stone_wall" and "Stone walls" or (def and def.name or key)
			local ok = (r.have or 0) >= (r.need or 0)
			ready = ready and ok
			label(body, `{ok and "✅" or "⬜"} {name}: {r.have or 0}/{r.need or 0}`, {
				Position = UDim2.fromOffset(10, y),
				Size = UDim2.new(1, -10, 0, 22),
				TextColor3 = ok and Color3.fromRGB(30, 130, 60) or C.ink,
			})
			y += 24
		end
		label(
			body,
			"Then pay:",
			{ Position = UDim2.fromOffset(0, y + 4), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Display }
		)
		costChips(body, nxt.cost or {}, UDim2.fromOffset(10, y + 28))
		for k, n in nxt.cost or {} do
			if available(k) < n then
				ready = false
			end
		end
		local b = Theme.button({
			Name = "Upgrade",
			Text = "⬆️ UPGRADE THE CAMP",
			BackgroundColor3 = ready and C.good or C.muted,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(320, 48),
			Parent = body,
		})
		b.Activated:Connect(function()
			Net.send("Camp", "upgrade")
			Bus.Tap:Fire("camp_upgrade")
		end)
	end
	open.refresh = refresh
	refresh()
end

-- ME --------------------------------------------------------------------------------------------------------------------------------------------------
local progressTab = "level"
local function progressPanel()
	local body = panel("progress", "⭐ YOU", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local p = Store.get("profile")
		if not p then
			label(body, "Loading...", { Size = UDim2.new(1, 0, 0, 30) })
			return
		end
		tabs(
			body,
			{
				{ key = "level", label = "LEVEL" },
				{ key = "kit", label = "KIT" },
				{ key = "perks", label = "PERKS" },
				{ key = "mastery", label = "MASTERY" },
				{ key = "looks", label = "LOOKS" },
			},
			progressTab,
			function(k)
				progressTab = k
				refresh()
			end
		)
		local area = new("Frame", {
			Name = "Area",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 1, -48),
			Parent = body,
		})
		if progressTab == "level" then
			label(area, `LEVEL {p.level}`, { Size = UDim2.new(1, 0, 0, 34), Font = Theme.Display })
			local bar, fill = Theme.bar(
				{ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 22), Parent = area },
				C.mustard
			)
			fill.Size = UDim2.fromScale(math.clamp((p.xpInto or 0) / math.max(1, p.xpNeed or 1), 0, 1), 1)
			Theme.title({
				Text = `{p.xpInto or 0} / {p.xpNeed or 0} XP`,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				outline = 2,
				ZIndex = 3,
				Parent = bar,
			})
			local r, s = p.records or {}, p.stats or {}
			local d = Constants.DIFFICULTIES[r.bestDifficulty or 0]
			local lines = {
				`🏆 Runs won: {s.wins or 0} of {s.runs or 0}`,
				`💀 Best difficulty won: {d and d.name or "none yet"}`,
				`⏱️ Fastest win: {(r.fastestWin or 0) > 0 and Formulas.clock(r.fastestWin) or "-"}`,
				`🌙 Nights survived: {r.nights or 0} (furthest: night {r.bestNight or 0})`,
				`⚔️ Monsters defeated: {r.monsters or 0} · 🐸 Kermy knocked out: {s.kermyKO or 0}`,
				`🤝 Teammates revived: {r.rescues or 0}`,
				`🔎 Discovery score: {r.discoveryScore or 0}`,
				`🔓 Difficulties unlocked: {p.unlocked or 1} of {#Constants.DIFFICULTIES}`,
			}
			label(area, table.concat(lines, "\n"), {
				Position = UDim2.fromOffset(0, 74),
				Size = UDim2.new(1, 0, 1, -74),
				TextSize = 18,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
		elseif progressTab == "kit" then
			label(
				area,
				"What you start each run with (choices, not power):",
				{ Size = UDim2.new(1, 0, 0, 20), TextSize = 16 }
			)
			local list = scroller(area, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24) })
			for i, k in Progression.KITS do
				local can = p.kits and p.kits[k.key]
				local row = rowFrame(list, 56, i, p.kit == k.key and Color3.fromRGB(255, 236, 170) or nil)
				label(
					row,
					`{k.icon} {k.name}`,
					{ Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(240, 24), Font = Theme.Display }
				)
				label(row, can and k.desc or `🔒 Level {k.level}`, {
					Position = UDim2.fromOffset(10, 28),
					Size = UDim2.new(1, -150, 0, 22),
					TextSize = 15,
					TextColor3 = can and C.ink or C.muted,
				})
				if can and p.kit ~= k.key then
					local b = Theme.button({
						Name = "Kit_" .. k.key,
						Text = "PICK",
						BackgroundColor3 = C.good,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(100, 40),
						Parent = row,
					})
					b.Activated:Connect(function()
						Net.send("Loadout", k.key)
					end)
				elseif p.kit == k.key then
					label(row, "✅ PICKED", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(110, 30),
						Font = Theme.Display,
						TextXAlignment = Enum.TextXAlignment.Right,
					})
				end
			end
		elseif progressTab == "perks" then
			label(
				area,
				`Perk slots: {#(p.perks or {})}/{p.perkSlots or 1} (more as you level up)`,
				{ Size = UDim2.new(1, 0, 0, 22), Font = Theme.Display }
			)
			local list = scroller(area, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26) })
			for i, perk in Progression.PERKS do
				local can = p.perksOpen and p.perksOpen[perk.key]
				local slot = table.find(p.perks or {}, perk.key)
				local row = rowFrame(list, 56, i, slot and Color3.fromRGB(255, 236, 170) or nil)
				label(
					row,
					`{perk.icon} {perk.name}`,
					{ Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(240, 24), Font = Theme.Display }
				)
				label(row, can and perk.desc or `🔒 Level {perk.level}`, {
					Position = UDim2.fromOffset(10, 28),
					Size = UDim2.new(1, -150, 0, 22),
					TextSize = 15,
					TextColor3 = can and C.ink or C.muted,
				})
				if can then
					local b = Theme.button({
						Name = "Perk_" .. perk.key,
						Text = slot and "REMOVE" or "EQUIP",
						BackgroundColor3 = slot and C.red or C.good,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(110, 40),
						Parent = row,
					})
					b.Activated:Connect(function()
						if slot then
							Net.send("Perk", slot, false)
						else
							local idx = math.min(#(p.perks or {}) + 1, p.perkSlots or 1)
							Net.send("Perk", idx, perk.key)
						end
					end)
				end
			end
		elseif progressTab == "mastery" then
			local list = scroller(area, { Size = UDim2.fromScale(1, 1) })
			for i, class in { "axe", "club", "spear", "bow", "trap", "support" } do
				local m = p.mastery and p.mastery[class] or { level = 1, frac = 0 }
				local spec = Progression.SPECIALS[class]
				local row = rowFrame(list, 62, i)
				label(
					row,
					`{string.upper(class)}  ·  LEVEL {m.level}`,
					{ Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(260, 24), Font = Theme.Display }
				)
				local bar, fill = Theme.bar(
					{ Position = UDim2.fromOffset(10, 34), Size = UDim2.fromOffset(250, 14), Parent = row },
					C.orange
				)
				fill.Size = UDim2.fromScale(m.level >= 10 and 1 or math.clamp(m.frac or 0, 0, 1), 1)
				_ = bar
				label(
					row,
					spec and ((m.level >= 3 and "✨ " or "🔒 Mastery 3: ") .. spec.name .. " · " .. spec.desc) or "",
					{
						Position = UDim2.fromOffset(280, 4),
						Size = UDim2.new(1, -290, 1, -8),
						TextSize = 15,
						TextColor3 = m.level >= 3 and C.ink or C.muted,
					}
				)
			end
		elseif progressTab == "looks" then
			local list = scroller(area, { Size = UDim2.fromScale(1, 1) })
			local order = 0
			for _, l in Progression.LOOKS do
				order += 1
				local owned = p.looks and p.looks.owned and p.looks.owned[l.key]
				local worn = p.looks and p.looks.equipped and p.looks.equipped[l.slot] == l.key
				local row = rowFrame(list, 50, order, worn and Color3.fromRGB(255, 236, 170) or nil)
				label(
					row,
					`{l.icon} {l.name}`,
					{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 24), Font = Theme.Display }
				)
				label(
					row,
					owned and string.upper(l.slot)
						or (l.level and `🔒 Level {l.level}` or "🔒 " .. (l.how or "Earn it")),
					{
						Position = UDim2.fromOffset(10, 26),
						Size = UDim2.new(1, -150, 0, 20),
						TextSize = 14,
						TextColor3 = C.muted,
					}
				)
				if owned then
					local b = Theme.button({
						Name = "Look_" .. l.key,
						Text = worn and "TAKE OFF" or "WEAR",
						BackgroundColor3 = worn and C.red or C.sky,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(110, 38),
						Parent = row,
					})
					b.Activated:Connect(function()
						Net.send("Wear", l.slot, (not worn) and l.key or false)
					end)
				end
			end
			for _, t in Progression.TITLES do
				order += 1
				local owned = p.titles and p.titles.owned and p.titles.owned[t.key]
				if owned then
					local worn = p.titles.equipped == t.key
					local row = rowFrame(list, 44, order, worn and Color3.fromRGB(255, 236, 170) or nil)
					label(
						row,
						`🏷️ "{t.name}"`,
						{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 1, -8), Font = Theme.Display }
					)
					if not worn then
						local b = Theme.button({
							Name = "Title_" .. t.key,
							Text = "SHOW",
							BackgroundColor3 = C.purple,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -8, 0.5, 0),
							Size = UDim2.fromOffset(110, 34),
							Parent = row,
						})
						b.Activated:Connect(function()
							Net.send("Wear", "title", t.key)
						end)
					end
				end
			end
		end
	end
	open.refresh = refresh
	refresh()
end

-- BOOK --------------------------------------------------------------------------------------------------------------------------------------------------
local bookTab = "monsters"
local function bookPanel()
	local body = panel("bestiary", "📖 THE BOOK", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local p = Store.get("profile") or {}
		tabs(
			body,
			{
				{ key = "monsters", label = "MONSTERS" },
				{ key = "items", label = "ITEMS" },
				{ key = "findings", label = "PLACES" },
				{ key = "diary", label = "DIARY" },
				{ key = "achievements", label = "AWARDS" },
			},
			bookTab,
			function(k)
				bookTab = k
				refresh()
			end
		)
		local area = new("Frame", {
			Name = "Area",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 1, -48),
			Parent = body,
		})
		if bookTab == "monsters" then
			local list = scroller(area, { Size = UDim2.fromScale(1, 1) })
			for i, e in Enemies.list do
				local b = p.bestiary and p.bestiary[e.key]
				local seen = b and b.seen
				local tips, learned = {}, 0
				for tip, text in e.tips or {} do
					local got = b and b.tells and (b.tells[tip] or 0) > 0
					if got then
						learned += 1
					end
					table.insert(tips, (got and "✅ " or "⬜ ") .. (seen and text or "???"))
				end
				local row = rowFrame(list, 40 + #tips * 22, i)
				label(
					row,
					seen and `{e.icon} {e.name} · {e.role}` or "❓ ???",
					{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -170, 0, 24), Font = Theme.Display }
				)
				label(
					row,
					seen
							and `⚔️ {b.defeated or 0} beaten{(b.golden or 0) > 0 and ` · ✨ {b.golden} golden` or ""} · 📘 {learned}/{#tips}`
						or "Not met yet",
					{
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -10, 0, 6),
						Size = UDim2.fromOffset(240, 20),
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Right,
					}
				)
				label(row, table.concat(tips, "\n"), {
					Position = UDim2.fromOffset(16, 30),
					Size = UDim2.new(1, -26, 0, #tips * 22),
					TextSize = 14,
					TextYAlignment = Enum.TextYAlignment.Top,
				})
			end
		elseif bookTab == "items" then
			local found = p.collection and p.collection.items or {}
			local n = 0
			for _ in found do
				n += 1
			end
			label(area, `{n} of {#Items.list} items found`, { Size = UDim2.new(1, 0, 0, 22), Font = Theme.Display })
			local grid = scroller(
				area,
				{ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), grid = UDim2.fromOffset(62, 62) }
			)
			for i, item in Items.list do
				local got = found[item.key]
				local cell = new("Frame", {
					Name = item.key,
					LayoutOrder = i,
					BackgroundColor3 = got and Theme.darken(rarity(item).color, 0.45) or Color3.fromRGB(70, 70, 90),
					Parent = grid,
				}, { Theme.corner(10), Theme.stroke(2, got and rarity(item).color or C.ink) })
				Theme.text({
					Text = got and item.icon or "?",
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = C.white,
					Parent = cell,
				})
			end
		elseif bookTab == "findings" then
			local visited = p.collection and p.collection.findings or {}
			local list = scroller(area, { Size = UDim2.fromScale(1, 1) })
			for i, f in Findings.list do
				local times = visited[f.key]
				local row = rowFrame(list, 48, i)
				label(
					row,
					times and `{f.icon} {f.name}` or "❓ ???",
					{ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -150, 0, 24), Font = Theme.Display }
				)
				label(row, times and f.desc or "Somewhere in the forest...", {
					Position = UDim2.fromOffset(10, 24),
					Size = UDim2.new(1, -150, 0, 20),
					TextSize = 14,
					TextColor3 = C.muted,
				})
				label(row, times and `visited ×{times}` or "", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(120, 22),
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
		elseif bookTab == "diary" then
			local pages = p.collection and p.collection.pages or {}
			local list = scroller(area, { Size = UDim2.fromScale(1, 1) })
			for i, text in Findings.PAGES do
				local got = pages[i] or pages[tostring(i)]
				local row = rowFrame(list, 56, i, Color3.fromRGB(250, 240, 214))
				label(row, got and `📜 Page {i}: "{text}"` or `📜 Page {i}: (lost somewhere in the forest)`, {
					Position = UDim2.fromOffset(10, 4),
					Size = UDim2.new(1, -20, 1, -8),
					TextSize = 16,
					TextColor3 = got and C.ink or C.muted,
				})
			end
		else
			local got = p.achievements or {}
			local list = scroller(area, { Size = UDim2.fromScale(1, 1) })
			local done = 0
			for i, a in Progression.ACHIEVEMENTS do
				local has = got[a.key] ~= nil
				if has then
					done += 1
				end
				local row = rowFrame(list, 46, has and i or i + 100, has and Color3.fromRGB(255, 236, 170) or nil)
				label(
					row,
					`{has and a.icon or "🔒"} {a.name}`,
					{ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(0.45, 0, 1, -4), Font = Theme.Display }
				)
				label(
					row,
					a.desc,
					{ Position = UDim2.new(0.45, 0, 0, 2), Size = UDim2.new(0.55, -10, 1, -4), TextSize = 14 }
				)
			end
			_ = done
		end
	end
	open.refresh = refresh
	refresh()
end

-- TOP ----------------------------------------------------------------------------------------------------------------------------------------------------
local boardKey = Progression.BOARDS[1].key
local function boardValue(board, v)
	if not v then
		return "-"
	end
	if board.format == "difficulty" then
		local d = Constants.DIFFICULTIES[v]
		return d and d.name or tostring(v)
	elseif board.format == "time" then
		return Formulas.clock(v)
	end
	return tostring(v)
end

local function boardsPanel()
	local body = panel("boards", "🏆 LEADERBOARDS", 840, 480)
	local function refresh()
		body:ClearAllChildren()
		local side = scroller(body, { Name = "Categories", Size = UDim2.new(0.3, -6, 1, 0), gap = 4 })
		for i, b in Progression.BOARDS do
			local btn = Theme.button({
				Name = "Board_" .. b.key,
				LayoutOrder = i,
				Text = b.icon .. " " .. b.name,
				BackgroundColor3 = b.key == boardKey and C.mustard or C.white,
				dark = b.key ~= boardKey,
				Size = UDim2.new(1, -8, 0, 44),
				TextSize = 15,
				Parent = side,
			})
			btn.Activated:Connect(function()
				boardKey = b.key
				Net.send("Board", b.key)
				refresh()
			end)
		end
		local board = Progression.boardByKey[boardKey]
		local view = Store.get("board")
		if not view or view.category ~= boardKey then
			label(body, "Loading...", { Position = UDim2.new(0.3, 6, 0, 0), Size = UDim2.new(0.7, -6, 0, 30) })
			return
		end
		local function column(x, title, rows)
			label(
				body,
				title,
				{ Position = UDim2.new(x, 6, 0, 0), Size = UDim2.new(0.35, -12, 0, 24), Font = Theme.Display }
			)
			local list =
				scroller(body, { Position = UDim2.new(x, 6, 0, 28), Size = UDim2.new(0.35, -12, 1, -28), gap = 4 })
			for i, r in rows do
				local row = rowFrame(
					list,
					38,
					i,
					r.you and Color3.fromRGB(255, 236, 170) or (r.friend and Color3.fromRGB(214, 240, 214) or nil)
				)
				label(row, `{r.rank and ("#" .. r.rank) or "-"}  {r.name}{r.here and " 🟢" or ""}`, {
					Position = UDim2.fromOffset(8, 2),
					Size = UDim2.new(0.66, -8, 1, -4),
					Font = Theme.Display,
					TextSize = 15,
				})
				label(row, boardValue(board, r.value), {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 2),
					Size = UDim2.new(0.34, 0, 1, -4),
					TextXAlignment = Enum.TextXAlignment.Right,
					Font = Theme.Display,
					TextSize = 15,
				})
			end
			if #rows == 0 then
				label(list, "Nobody yet!", { Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted })
			end
		end
		column(0.3, `👥 FRIENDS{view.loading and (" (" .. view.loading .. " loading)") or ""}`, view.friends or {})
		column(0.65, "🌍 EVERYONE", view.global or {})
	end
	open.refresh = refresh
	Net.send("Board", boardKey)
	refresh()
end

-- FRIENDS ----------------------------------------------------------------------------------------------------------------------------------------------
local friendStatus = ""
local function friendsPanel()
	local body = panel("friends", "👥 FRIENDS", 780, 470)
	local friends = {} -- { userId, name, jobId }
	local function refresh()
		body:ClearAllChildren()
		label(
			body,
			friendStatus ~= "" and friendStatus or "Friends playing Survive the 6-7 right now:",
			{ Size = UDim2.new(1, 0, 0, 24), Font = Theme.Display, TextSize = 16 }
		)
		local list = scroller(body, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -90) })
		local views = {}
		for _, v in Store.get("friends") or {} do
			views[v.userId] = v
		end
		for i, f in friends do
			local v = views[f.userId] or {}
			local row = rowFrame(list, 50, i)
			local status
			if v.here then
				status = "🟢 In this server"
			elseif v.unknown or not v.phase then
				status = "In a run"
			else
				local where = v.phase == "boss" and "fighting Mega Kermy"
					or (
						v.open and "day 1, the roster's open!"
						or (v.night and v.night > 0 and `night {v.night}` or `day {v.day or 1}`)
					)
				status =
					`{where} · {v.crew or "?"}/{v.max or 6}{v.full and " (full)" or ""}{v.private and " · private" or ""}`
			end
			label(
				row,
				f.name,
				{ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(0.4, 0, 1, -4), Font = Theme.Display }
			)
			label(
				row,
				status,
				{ Position = UDim2.new(0.4, 0, 0, 2), Size = UDim2.new(0.6, -140, 1, -4), TextSize = 15 }
			)
			if not v.here then
				local b = Theme.button({
					Name = "Join_" .. f.userId,
					Text = "JOIN",
					BackgroundColor3 = C.good,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromOffset(110, 38),
					Parent = row,
				})
				b.Activated:Connect(function()
					Net.send("JoinFriend", f.userId, f.name)
					Bus.Tap:Fire("join_friend")
				end)
			end
		end
		if #friends == 0 then
			label(
				list,
				"No friends playing right now. Invite some!",
				{ Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted }
			)
		end
		local function bottom(name, text, color, x, fn)
			local b = Theme.button({
				Name = name,
				Text = text,
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(x, 4, 1, 0),
				Size = UDim2.new(0.25, -8, 0, 48),
				TextSize = 16,
				Parent = body,
			})
			b.Activated:Connect(fn)
		end
		bottom("NewRun", "🔎 NEW RUN", C.good, 0, function()
			Net.send("FriendAction", "newrun")
		end)
		bottom("Private", "🔒 PRIVATE RUN", C.purple, 0.25, function()
			Net.send("FriendAction", "private")
		end)
		bottom("Invite", "✉️ INVITE", C.sky, 0.5, function()
			pcall(function()
				game:GetService("SocialService"):PromptGameInvite(player)
			end)
		end)
		bottom("Refresh", "🔄 REFRESH", C.orange, 0.75, function()
			PanelController.loadFriends(friends, refresh)
		end)
	end
	open.refresh = refresh
	PanelController.loadFriends(friends, refresh)
	refresh()
end

-- Friends online in this game (only the client can ask Roblox), then ask the server how their runs are going.
function PanelController.loadFriends(out, done)
	task.spawn(function()
		local ok, list = pcall(function()
			return player:GetFriendsOnline(50)
		end)
		table.clear(out)
		local ask = {}
		for _, f in ok and list or {} do
			if f.PlaceId == game.PlaceId or f.GameId == game.GameId then
				table.insert(out, { userId = f.VisitorId, name = f.DisplayName or f.UserName, jobId = f.GameId })
				table.insert(ask, { userId = f.VisitorId, jobId = f.GameId })
			end
		end
		Net.send("Friends", ask)
		if done then
			done()
		end
	end)
end

local function onFriendResult(r)
	if type(r) ~= "table" then
		return
	end
	local name = r.name or "your friend"
	if r.kind == "teleporting" then
		friendStatus = `✈️ Going to {name}...`
	elseif r.kind == "full" then
		friendStatus = `{name}'s server is full.`
		local card = PanelController.card(
			"full",
			`{name}'s server is full`,
			`Wait for a spot (we'll try every {r.every or 15} s), or start a run of your own.`,
			{
				{
					text = "⏳ WAIT FOR A SPOT",
					color = C.good,
					fn = function()
						Net.send("FriendAction", "retry")
					end,
				},
				{
					text = "🔒 PRIVATE RUN",
					color = C.purple,
					fn = function()
						Net.send("FriendAction", "private")
					end,
				},
			}
		)
		_ = card
	elseif r.kind == "waiting" then
		friendStatus = `⏳ Waiting for a spot with {name} (try {r.tries or 0}/{r.max or 8})`
	elseif r.kind == "failed" then
		friendStatus = r.text or "Couldn't join."
	elseif r.kind == "gone" then
		friendStatus = `{name} isn't in a run any more.`
	elseif r.kind == "here" then
		friendStatus = `{name} is right here in this server!`
	elseif r.kind == "rejoin" then
		local where = r.phase == "boss" and "the fight with Mega Kermy"
			or (r.night and r.night > 0 and `night {r.night}` or `day {r.day or 1}`)
		PanelController.card(
			"rejoin",
			"Go back to your run?",
			`Your team is on {where} ({r.crew or "?"}/{r.max or 6}).`,
			{
				{
					text = "↩️ REJOIN",
					color = C.good,
					fn = function()
						Net.send("FriendAction", "rejoin")
					end,
				},
				{
					text = "STAY HERE",
					color = C.slate,
					fn = function()
						Net.send("FriendAction", "cancel")
					end,
				},
			}
		)
	end
	if open and open.name == "friends" and open.refresh then
		open.refresh()
	end
end

-- MORE ---------------------------------------------------------------------------------------------------------------------------------------------------
local function settingsPanel()
	local body = panel("settings", "⚙️ MORE", 720, 460)
	local function refresh()
		body:ClearAllChildren()
		local s = Store.get("settings") or {}
		local y = 0
		for _, opt in
			{
				{ key = "music", label = "🎵 Music" },
				{ key = "shake", label = "📳 Screen shake" },
				{ key = "fx", label = "✨ Effects" },
			}
		do
			local on = s[opt.key] ~= false
			label(
				body,
				opt.label,
				{ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(300, 40), Font = Theme.Display }
			)
			local b = Theme.button({
				Name = "Toggle_" .. opt.key,
				Text = on and "ON" or "OFF",
				BackgroundColor3 = on and C.good or C.muted,
				Position = UDim2.fromOffset(300, y),
				Size = UDim2.fromOffset(110, 40),
				Parent = body,
			})
			b.Activated:Connect(function()
				s[opt.key] = not on
				Net.send("Settings", opt.key, not on)
				refresh()
			end)
			y += 48
		end
		-- emotes (H does the 6-7 on a keyboard)
		label(
			body,
			"😄 Emotes",
			{ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(160, 40), Font = Theme.Display }
		)
		for i, e in { { "67", "🙌 THE 6-7" }, { "wave", "👋 WAVE" }, { "dance", "💃 DANCE" } } do
			local b = Theme.button({
				Name = "Emote_" .. e[1],
				Text = e[2],
				BackgroundColor3 = i == 1 and C.mustard or C.sky,
				Position = UDim2.fromOffset(160 + (i - 1) * 166, y),
				Size = UDim2.fromOffset(158, 40),
				TextSize = 16,
				Parent = body,
			})
			b.Activated:Connect(function()
				Net.send("Emote", e[1])
				Bus.Tap:Fire("emote_" .. e[1])
				PanelController.close()
			end)
		end
		y += 48
		label(
			body,
			"HOW TO PLAY\n• Survive six nights in the forest, then beat Mega Kermy on the seventh.\n• By day: chop trees, open crates, explore, build up the camp.\n• At night: stay near the fire. Watch for the tells (a red line or circle) and DODGE.\n• Kermy yells SIX... SEVEN! before he lunges: roll sideways.\n• Revive teammates who go down. Ghosts come back at dawn.",
			{
				Position = UDim2.fromOffset(0, y + 6),
				Size = UDim2.new(1, 0, 1, -(y + 6)),
				TextSize = 16,
				TextYAlignment = Enum.TextYAlignment.Top,
			}
		)
	end
	open.refresh = refresh
	refresh()
end

-- Cards: results, feedback, notify, offers --------------------------------------------------------------------------------------------------------------------
function PanelController.card(name, title, text, buttons)
	if cards[name] then
		cards[name]:Destroy()
	end
	local card = Theme.card({
		Name = "Card_" .. name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(480, 200),
		ZIndex = 40,
		Parent = gui,
	})
	cards[name] = card
	Theme.title({
		Name = "Title",
		Text = title,
		TextColor3 = C.ink,
		outline = false,
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = card,
	})
	label(card, text or "", {
		Name = "Text",
		Position = UDim2.fromOffset(16, 48),
		Size = UDim2.new(1, -32, 0, 70),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local w = 1 / math.max(1, #buttons)
	for i, b in buttons do
		local btn = Theme.button({
			Name = "Btn" .. i,
			Text = b.text,
			BackgroundColor3 = b.color or C.good,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((i - 1) * w, 12, 1, -12),
			Size = UDim2.new(w, -24, 0, 48),
			TextSize = 16,
			Parent = card,
		})
		btn.Activated:Connect(function()
			if b.fn then
				b.fn()
			end
			if not b.keep then
				card:Destroy()
				if cards[name] == card then
					cards[name] = nil
				end
			end
		end)
	end
	Theme.pop(card)
	return card
end

local function showResults(r)
	if type(r) ~= "table" then
		return
	end
	PanelController.close()
	local body, frame =
		panel("results", r.won and "🏆 YOU SURVIVED THE 6-7!" or "💀 THE FOREST WINS THIS TIME", 820, 480)
	frame.Head.BackgroundColor3 = r.won and Color3.fromRGB(60, 150, 70) or Color3.fromRGB(140, 50, 50)
	local d = Constants.DIFFICULTIES[r.difficulty or 1]
	label(
		body,
		`🌙 {r.nights or 0}/7 nights · ⏱️ {Formulas.clock(r.seconds or 0)} · 💀 {d and d.name or "Normal"}`,
		{ Size = UDim2.new(1, 0, 0, 26), Font = Theme.Display, TextXAlignment = Enum.TextXAlignment.Center }
	)
	local list = scroller(body, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(0.55, -6, 1, -32), gap = 4 })
	for i, t in r.team or {} do
		local row = rowFrame(list, 38, i, t.userId == player.UserId and Color3.fromRGB(255, 236, 170) or nil)
		label(
			row,
			`{t.name}`,
			{ Position = UDim2.fromOffset(8, 2), Size = UDim2.new(0.4, 0, 1, -4), Font = Theme.Display, TextSize = 15 }
		)
		label(row, `⚔️{t.kills or 0}  🤝{t.revives or 0}  🛠️{t.built or 0}  🔎{t.found or 0}`, {
			Position = UDim2.new(0.4, 0, 0, 2),
			Size = UDim2.new(0.6, -8, 1, -4),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	local right = new("Frame", {
		Name = "You",
		BackgroundTransparency = 1,
		Position = UDim2.new(0.55, 6, 0, 32),
		Size = UDim2.new(0.45, -6, 1, -32),
		Parent = body,
	})
	local you = r.you or {}
	label(
		right,
		`+{you.xp or 0} XP · LEVEL {you.level or 1}{(you.levelsGained or 0) > 0 and " ⬆️" or ""}`,
		{ Size = UDim2.new(1, 0, 0, 26), Font = Theme.Display, TextColor3 = Color3.fromRGB(180, 120, 20) }
	)
	local bar, fill =
		Theme.bar({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 16), Parent = right }, C.mustard)
	fill.Size = UDim2.fromScale(math.clamp((you.xpInto or 0) / math.max(1, you.xpNeed or 1), 0, 1), 1)
	_ = bar
	local lines = {}
	for _, m in r.mvps or {} do
		table.insert(lines, `{m.label}: {m.name} ({m.value})`)
	end
	for _, u in you.unlocks or {} do
		local news = u.news or u.text or u.name
		if type(news) == "string" and news ~= "" then
			table.insert(lines, "🔓 " .. news)
		end
	end
	label(right, table.concat(lines, "\n"), {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -110),
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	label(right, `A new run starts in {r.nextIn or Constants.RESULTS_SECONDS} seconds`, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -50),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextColor3 = C.muted,
	})
	local b = Theme.button({
		Name = "Okay",
		Text = "👍 OKAY",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = right,
	})
	b.Activated:Connect(PanelController.close)
end

local function onAsk(a)
	if type(a) ~= "table" then
		return
	end
	if a.kind == "feedback" then
		local chosen = {}
		local card = PanelController.card(
			"feedback",
			"Do you like Survive the 6-7?",
			"Tell us! It helps us make the game better.",
			{
				{
					text = "👍 YES!",
					color = C.good,
					fn = function()
						Net.send("Feedback", true, nil, nil)
					end,
				},
				{
					text = "👎 NOT REALLY",
					color = C.red,
					keep = true,
					fn = function()
						local c = cards.feedback
						if not c then
							return
						end
						c.Size = UDim2.fromOffset(560, 300)
						c.Text.Text = "What's wrong? (tap any)"
						for _, b in c:GetChildren() do
							if b.Name == "Btn1" or b.Name == "Btn2" then
								b:Destroy()
							end
						end
						for i, r in Constants.DISLIKE_REASONS do
							local btn = Theme.button({
								Name = "Reason_" .. r[1],
								Text = r[2] .. " " .. r[3],
								BackgroundColor3 = C.white,
								dark = true,
								Size = UDim2.fromOffset(170, 40),
								Position = UDim2.fromOffset(
									14 + ((i - 1) % 3) * 178,
									110 + math.floor((i - 1) / 3) * 46
								),
								TextSize = 14,
								Parent = c,
							})
							btn.Activated:Connect(function()
								chosen[r[1]] = not chosen[r[1]]
								btn.BackgroundColor3 = chosen[r[1]] and C.mustard or C.white
							end)
						end
						local send = Theme.button({
							Name = "Send",
							Text = "SEND",
							BackgroundColor3 = C.good,
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.new(0.5, 0, 1, -12),
							Size = UDim2.fromOffset(200, 44),
							Parent = c,
						})
						send.Activated:Connect(function()
							local list = {}
							for k, on in chosen do
								if on then
									table.insert(list, k)
								end
							end
							Net.send("Feedback", false, nil, list)
							c:Destroy()
							cards.feedback = nil
						end)
					end,
				},
			}
		)
		_ = card
	elseif a.kind == "thanks" then
		PanelController.card(
			"thanks",
			"Thank you! 💚",
			a.like and "Glad you're having fun. See you at the campfire!" or "Thanks for telling us. We're on it.",
			{ { text = "OK", color = C.good } }
		)
	elseif a.kind == "notify" and NotifyController.canAsk() then
		Net.send("Notify", "shown")
		PanelController.card(
			"notify",
			"Get told about updates?",
			"New monsters, new findings, events. We'll let you know.",
			{
				{
					text = "🔔 YES",
					color = C.good,
					fn = function()
						NotifyController.prompt()
					end,
				},
				{
					text = "NOT NOW",
					color = C.slate,
					fn = function()
						Net.send("Notify", "off")
					end,
				},
			}
		)
	end
end

-- Opening ---------------------------------------------------------------------------------------------------------------------------------------------------
local OPENERS = {
	inventory = inventoryPanel,
	craft = craftPanel,
	storage = chestPanel,
	camp = campPanel,
	progress = progressPanel,
	bestiary = bookPanel,
	collection = function()
		bookTab = "items"
		bookPanel()
	end,
	achievements = function()
		bookTab = "achievements"
		bookPanel()
	end,
	boards = boardsPanel,
	friends = friendsPanel,
	settings = settingsPanel,
}

function PanelController.openPanel(name, arg)
	if open and open.name == name and arg == nil then
		PanelController.close()
		return
	end
	local fn = OPENERS[name]
	if fn then
		fn(arg)
		pcall(Net.send, "Viewed", name)
	end
end

function PanelController.current()
	return open and open.name or nil
end

function PanelController:init()
	gui = Theme.screen("Panels", 8, player:WaitForChild("PlayerGui"))
	Bus.Open:Connect(PanelController.openPanel)
	Bus.Close:Connect(PanelController.close)
	Net.listen("Results", showResults)
	Net.listen("Ask", onAsk)
	Net.listen("FriendResult", onFriendResult)
	Store.Changed:Connect(function(partial)
		if not open or not open.refresh then
			return
		end
		local n = open.name
		if
			(partial.inv and (n == "inventory" or n == "craft" or n == "storage" or n == "camp"))
			or (partial.storage and (n == "craft" or n == "storage" or n == "camp"))
			or (partial.camp and (n == "craft" or n == "camp" or n == "storage"))
			or (partial.profile and (n == "progress" or n == "bestiary"))
			or (partial.board and n == "boards")
			or (partial.friends and n == "friends")
			or (partial.settings and n == "settings")
		then
			open.refresh()
		end
	end)
	-- stations and the chest open their panels
	player:GetAttributeChangedSignal("StationAt"):Connect(function()
		local station = player:GetAttribute("Station")
		if type(station) == "string" then
			PanelController.openPanel("craft", station)
		end
	end)
	player:GetAttributeChangedSignal("ChestAt"):Connect(function()
		PanelController.openPanel("storage", true)
	end)
	player:GetAttributeChangedSignal("BoardAt"):Connect(function()
		PanelController.openPanel("camp", true)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB and open then
			if open then
				PanelController.close()
			end
		end
	end)
end

-- (tests)
PanelController.cards = cards

return PanelController

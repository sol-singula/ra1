--[[
The panels (master plan §4: readable costs; §5: the raft's tier is a goal you can see; §6: progress you can
see). One open at a time, big tap targets, closes with X, Escape or B:

  BUILD     every piece by section, its cost (have/need, green when you can afford it), what locks it (a tier, a
            blueprint); tap PLACE and BuildController takes over. DEMOLISH too.
  BAG       the hotbar and the bag: tap a slot to see the item, tap another to move or swap it; USE / DROP;
            RESEARCH an artifact at the Research Station
  CRAFT     opens at a station: what it makes, what each costs, MAKE; the Research Station's points and the
            next milestone; the Decorative Workshop's dyes
  MAP       the destinations: the ones you have charts for (distance, danger, what's there, SAIL), the ones you
            don't (how to find them); SAIL HOME at an island
  RAFT      the tier, what the next one needs, speed and cargo, the colours, who may visit, DEMOLISH
  BOOK      the discovery journal: islands, creatures, fish, artifacts, events, notes
  ME        level, titles and flags, achievements, stats
  TOP       the leaderboards: six categories, friends first, then everyone
  FRIENDS   rafts in this server you can row over to; friends in other servers and their rafts; join, private
  MORE      settings (music, screen shake, effects), how to play, invite friends
And the cards that pop up: "Do you like the game?", notifications, friends' servers.
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Creatures = require(ReplicatedStorage.Shared.Data.Creatures)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
local Voyages = require(ReplicatedStorage.Shared.Data.Voyages)
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
local picked
local cards = {}
local bookTab = "islands"
local boardTab = "tier"
local friendStatus = ""

local function rarity(item)
	return item and Items.RARITY[item.rarity] or Items.RARITY.common
end

-- Building blocks ---------------------------------------------------------------------------------------------------
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
	local head = new(
		"Frame",
		{ Name = "Head", BackgroundColor3 = C.slate, Size = UDim2.new(1, 0, 0, 52), Parent = frame },
		{ Theme.corner(18) }
	)
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
	open = { name = name, frame = frame, body = body, head = head }
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
	return new("Frame", {
		Name = "Row",
		LayoutOrder = order or 0,
		BackgroundColor3 = color or Color3.fromRGB(240, 230, 210),
		Size = UDim2.new(1, -10, 0, h or 54),
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2) })
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
			TextSize = 15,
			Parent = bar,
		})
		b.Activated:Connect(function()
			onPick(t.key)
		end)
	end
	return bar
end

local function countOf(key)
	local n = 0
	for _, s in (Store.get("inv") or { slots = {} }).slots do
		if s.key == key then
			n += s.n
		end
	end
	return n
end

-- What something costs, one chip per material: icon, name, have/need (green once you have enough).
local function costChips(parent, cost, pos, width)
	local x = 0
	local keys = {}
	for k in cost do
		table.insert(keys, k)
	end
	table.sort(keys)
	local all = true
	for _, k in keys do
		local item = Items.get(k)
		local have = countOf(k)
		local ok = have >= cost[k]
		all = all and ok
		local chip =
			label(parent, `{item and item.icon or ""} {item and item.name or k} {math.min(have, cost[k])}/{cost[k]}`, {
				Name = "Cost_" .. k,
				Position = UDim2.new(pos.X.Scale, pos.X.Offset + x, pos.Y.Scale, pos.Y.Offset),
				Size = UDim2.fromOffset(width or 150, 22),
				TextSize = 14,
				TextColor3 = ok and Color3.fromRGB(30, 130, 60) or C.red,
				Font = Theme.Display,
			})
		chip:SetAttribute("Have", have)
		chip:SetAttribute("Need", cost[k])
		x += (width or 150) + 2
	end
	return all
end

local function sendViewed(name)
	pcall(Net.send, "Viewed", name)
end

-- BUILD -------------------------------------------------------------------------------------------------------------------
local SECTIONS = {
	{
		"STRUCTURE",
		function(p)
			return p.structural or p.key == "railing" or p.key == "ladder" or p.key == "wall" or p.key == "roof"
		end,
	},
	{
		"STATIONS",
		function(p)
			return p.station ~= nil
		end,
	},
	{
		"SYSTEMS",
		function(p)
			return not p.decor
				and not p.station
				and not p.structural
				and p.key ~= "railing"
				and p.key ~= "ladder"
				and p.key ~= "wall"
				and p.key ~= "roof"
		end,
	},
	{
		"DECORATION",
		function(p)
			return p.decor == true
		end,
	},
}

local function buildPanel()
	local body = panel("build", "🔨 BUILD", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local raft = Store.get("raft") or { tier = 1, tiles = 0, max = 12 }
		local profile = Store.get("profile") or { blueprints = {} }
		label(
			body,
			`{raft.tierName or "Driftwood Platform"} · {raft.tiles or 0}/{raft.max or 12} tiles. Tap PLACE, then tap a spot on your raft.`,
			{
				Size = UDim2.new(1, -130, 0, 22),
				TextSize = 15,
			}
		)
		local demolish = Theme.button({
			Name = "Demolish",
			Text = "💥 DEMOLISH",
			BackgroundColor3 = C.red,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, -4),
			Size = UDim2.fromOffset(126, 32),
			TextSize = 14,
			Parent = body,
		})
		demolish.Activated:Connect(function()
			Bus.Place:Fire("demolish")
			Bus.Tap:Fire("demolish_mode")
			PanelController.close()
		end)
		local list = scroller(body, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30) })
		local order = 0
		for _, section in SECTIONS do
			order += 1
			label(list, section[1], {
				LayoutOrder = order,
				Size = UDim2.new(1, 0, 0, 22),
				Font = Theme.Display,
				TextSize = 16,
				TextColor3 = C.muted,
			})
			for _, def in Pieces.list do
				if not section[2](def) then
					continue
				end
				order += 1
				local locked
				if def.blueprint and not profile.blueprints[def.key] then
					locked = "📜 Needs its blueprint (crates, islands, research)"
				elseif def.tier > (raft.tier or 1) then
					local t = Pieces.TIERS[def.tier]
					locked = `🔒 Needs tier {def.tier}: {t and t.name or ""}`
				elseif def.decor and def.tier >= 2 and not (raft.stations and raft.stations.decor) then
					locked = "🔒 Needs the Decorative Workshop"
				end
				local row = rowFrame(list, 62, order, locked and Color3.fromRGB(215, 210, 205) or nil)
				row.Name = "Piece_" .. def.key
				Theme.text({
					Text = def.icon,
					Position = UDim2.fromOffset(8, 6),
					Size = UDim2.fromOffset(50, 50),
					TextXAlignment = Enum.TextXAlignment.Center,
					Parent = row,
				})
				label(row, def.name, {
					Position = UDim2.fromOffset(64, 4),
					Size = UDim2.fromOffset(300, 22),
					Font = Theme.Display,
					TextSize = 17,
				})
				label(row, def.desc or "", {
					Position = UDim2.fromOffset(370, 6),
					Size = UDim2.new(1, -500, 0, 20),
					TextSize = 13,
					TextColor3 = C.muted,
				})
				local can = not locked
				if locked then
					label(row, locked, {
						Position = UDim2.fromOffset(64, 30),
						Size = UDim2.fromOffset(500, 22),
						TextSize = 14,
						TextColor3 = C.muted,
					})
				else
					can = costChips(row, def.cost, UDim2.fromOffset(64, 32), 140)
				end
				local b = Theme.button({
					Name = "Place",
					Text = locked and "LOCKED" or "PLACE",
					BackgroundColor3 = can and C.good or C.muted,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(104, 42),
					TextSize = 15,
					Parent = row,
				})
				b.Activated:Connect(function()
					if locked then
						return
					end
					Bus.Place:Fire(def.key)
					Bus.Tap:Fire("pick_" .. def.key)
					PanelController.close()
				end)
			end
		end
	end
	open.refresh = refresh
	refresh()
end

-- BAG -----------------------------------------------------------------------------------------------------------------------
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

local function describe(slot)
	local item = slot and Items.get(slot.key)
	if not item then
		return "Tap an item to see it. Tap another slot to move it there."
	end
	local extra = ""
	if slot.data and slot.data.dest and Voyages.get(slot.data.dest) then
		extra = ` · to {Voyages.get(slot.data.dest).name}`
	elseif slot.data and slot.data.key then
		local def = Pieces.get(slot.data.key) or Recipes.get(slot.data.key)
		local name = def and (def.name or (def.item and Items.get(def.item).name)) or slot.data.key
		extra = ` · {name}`
	end
	return `{item.icon} {item.name}{extra} ({rarity(item).name}): {item.desc or ""}`
end

local function inventoryPanel()
	local body = panel("inventory", "🎒 YOUR BAG", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local inv = Store.get("inv") or { slots = {}, capacity = 16 }
		if picked and not inv.slots[picked] then
			picked = nil -- (used up or dropped)
		end
		label(
			body,
			"HOTBAR (tap or 1-6 to hold)",
			{ Size = UDim2.new(1, 0, 0, 20), Font = Theme.Display, TextSize = 14, TextColor3 = C.muted }
		)
		local hot = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 66),
			Parent = body,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = hot,
		})
		local function onClick(slotId, slot)
			if picked and picked ~= slotId then
				Net.send("Move", picked, slotId)
				picked = nil
				Bus.Tap:Fire("move_item")
			elseif slot then
				picked = picked == slotId and nil or slotId
			else
				picked = nil
			end
			refresh()
		end
		for i = 1, Constants.HOTBAR do
			itemCell(hot, "h" .. i, inv.slots["h" .. i], i, onClick)
		end
		label(body, `BAG · {inv.capacity or 16} slots (more with storage boxes and tiers)`, {
			Position = UDim2.fromOffset(0, 92),
			Size = UDim2.new(1, 0, 0, 20),
			Font = Theme.Display,
			TextSize = 14,
			TextColor3 = C.muted,
		})
		local grid = scroller(
			body,
			{ Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 1, -200), grid = UDim2.fromOffset(62, 62) }
		)
		for i = 1, inv.capacity or 16 do
			itemCell(grid, "b" .. i, inv.slots["b" .. i], i, onClick)
		end
		local info = new("Frame", {
			Name = "Info",
			BackgroundColor3 = Color3.fromRGB(240, 230, 210),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 78),
			Parent = body,
		}, { Theme.corner(12), Theme.stroke(2) })
		local slot = picked and inv.slots[picked]
		label(
			info,
			describe(slot),
			{ Name = "Text", Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -250, 1, -12), TextSize = 15 }
		)
		if slot then
			local item = Items.get(slot.key)
			local x = -8
			local function btn(name, text, color, fn)
				local b = Theme.button({
					Name = name,
					Text = text,
					BackgroundColor3 = color,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, x, 0.5, 0),
					Size = UDim2.fromOffset(100, 40),
					TextSize = 14,
					Parent = info,
				})
				b.Activated:Connect(fn)
				x -= 106
			end
			btn("Drop", "DROP", C.red, function()
				Net.send("Drop", picked, 1)
				Bus.Tap:Fire("drop")
			end)
			if item.food or item.kind == "chart" or item.kind == "blueprint" or item.key == "supply_crate" then
				btn(
					"Use",
					item.food and "EAT"
						or item.kind == "blueprint" and "LEARN"
						or item.kind == "chart" and "READ"
						or "OPEN",
					C.good,
					function()
						Net.send("Use", picked)
						Bus.Tap:Fire("use_" .. item.key)
					end
				)
			end
			if item.research then
				btn("Research", "RESEARCH", C.purple, function()
					Net.send("Research", picked)
					Bus.Tap:Fire("research")
				end)
			end
		end
		if (inv.finds or 0) > 0 then
			label(
				body,
				`🎒 {inv.finds} finds aboard: half float off if you go down away from your dock. Sail home to keep them.`,
				{
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, -82),
					Size = UDim2.new(1, 0, 0, 18),
					TextSize = 13,
					TextColor3 = C.red,
				}
			)
		end
	end
	open.refresh = refresh
	refresh()
end

-- CRAFT -----------------------------------------------------------------------------------------------------------------------
local function craftPanel(station)
	local st = Recipes.STATIONS[station] or Recipes.STATIONS.workbench
	local body = panel("craft", `{st.icon} {string.upper(st.name)}`, 780, 470)
	open.arg = station
	local function refresh()
		body:ClearAllChildren()
		local profile = Store.get("profile") or { blueprints = {}, colours = {}, decks = {}, research = { points = 0 } }
		local y = 0
		if station == "research" then
			local nextM = profile.research and profile.research.next
			label(
				body,
				`📚 Research: {profile.research and profile.research.points or 0} points. {nextM and `Next blueprint at {nextM.points}: {nextM.name}.` or "Every milestone researched!"} Artifacts in your bag:`,
				{ Size = UDim2.new(1, 0, 0, 40), TextSize = 15 }
			)
			y = 44
			local list = scroller(body, { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 1, -y) })
			local any = false
			for id, slot in (Store.get("inv") or { slots = {} }).slots do
				local item = Items.get(slot.key)
				if item and item.research then
					any = true
					local row = rowFrame(list, 56, 1)
					row.Name = "Artifact_" .. id
					label(
						row,
						`{item.icon} {item.name} ×{slot.n} · +{Constants.RESEARCH_PER_ARTIFACT[item.research] or 10} each`,
						{
							Position = UDim2.fromOffset(10, 4),
							Size = UDim2.new(1, -140, 1, -8),
							Font = Theme.Display,
							TextSize = 16,
						}
					)
					local b = Theme.button({
						Name = "Research_" .. id,
						Text = "RESEARCH",
						BackgroundColor3 = C.purple,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(120, 40),
						TextSize = 14,
						Parent = row,
					})
					b.Activated:Connect(function()
						Net.send("Research", id)
						Bus.Tap:Fire("research")
					end)
				end
			end
			if not any then
				label(
					list,
					"No artifacts yet. Wrecks, ruins and lockers hold them.",
					{ Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted }
				)
			end
			return
		end
		label(
			body,
			station == "decor" and "Dyes for your sails, banners, flags and deck (paint them in the RAFT panel)."
				or "Materials come from your bag.",
			{ Size = UDim2.new(1, 0, 0, 20), TextSize = 15 }
		)
		local list = scroller(body, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26) })
		for i, r in Recipes.byStation[station] or {} do
			local item = r.item and Items.get(r.item)
			local name = r.name or (item and item.name) or r.id
			local icon = r.icon or (item and item.icon) or "🛠️"
			local locked
			if r.blueprint and not profile.blueprints[r.id] then
				locked = "📜 Needs its blueprint"
			elseif
				r.unlock
				and (
					(r.unlock.kind == "color" and profile.colours and profile.colours[r.unlock.key])
					or (r.unlock.kind == "deck" and profile.decks and profile.decks[r.unlock.key])
				)
			then
				locked = "✅ You have this"
			end
			local row = rowFrame(list, 62, i, locked and Color3.fromRGB(215, 210, 205) or nil)
			row.Name = "Recipe_" .. r.id
			Theme.text({
				Text = icon,
				Position = UDim2.fromOffset(8, 6),
				Size = UDim2.fromOffset(50, 50),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = row,
			})
			label(row, name .. (r.count > 1 and (" ×" .. r.count) or ""), {
				Position = UDim2.fromOffset(64, 4),
				Size = UDim2.fromOffset(250, 24),
				Font = Theme.Display,
				TextSize = 17,
				TextColor3 = item and Theme.darken(rarity(item).color, 0.3) or C.ink,
			})
			label(row, item and item.desc or "", {
				Position = UDim2.fromOffset(320, 6),
				Size = UDim2.new(1, -450, 0, 20),
				TextSize = 13,
				TextColor3 = C.muted,
			})
			local can
			if locked then
				label(row, locked, {
					Position = UDim2.fromOffset(64, 32),
					Size = UDim2.fromOffset(300, 22),
					TextSize = 14,
					TextColor3 = C.muted,
				})
				can = false
			else
				can = costChips(row, r.cost, UDim2.fromOffset(64, 32), 140)
			end
			local b = Theme.button({
				Name = "Make_" .. r.id,
				Text = "MAKE",
				BackgroundColor3 = can and C.good or C.muted,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(104, 42),
				TextSize = 15,
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Craft", r.id)
				Bus.Tap:Fire("craft_" .. r.id)
			end)
		end
	end
	open.refresh = refresh
	refresh()
end

-- MAP -------------------------------------------------------------------------------------------------------------------------
local HOW = {
	crate = "Charts in supply crates",
	bottle = "A message in a bottle",
	nest = "Spotted from a crow's nest",
	guide = "A note on Palm Key",
	logbook = "Read a captain's logbook",
	idol = "A carved idol knows the way",
	research = "Research",
}

local function mapPanel()
	local body = panel("map", "🗺️ THE OCEAN", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local profile = Store.get("profile") or { known = {}, visited = {} }
		local raft = Store.get("raft") or { tier = 1, speed = 1 }
		local v = Store.get("voyage") or { state = "docked" }
		local allowed = Constants.DANGER_BY_TIER[raft.tier or 1] or 1
		local status
		if v.state == "docked" then
			status = raft.helm and "Docked. Pick a destination and SAIL." or "Docked. Build a Helm to set sail."
		elseif v.state == "island" then
			status = `At {v.name}. Sail home when you're done.`
		else
			status = v.state == "home" and "Sailing home..." or `Sailing to {v.name}...`
		end
		label(body, status, { Size = UDim2.new(1, -160, 0, 24), Font = Theme.Display, TextSize = 16 })
		if v.state == "island" then
			local home = Theme.button({
				Name = "Home",
				Text = "⛵ SAIL HOME",
				BackgroundColor3 = C.good,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, -4),
				Size = UDim2.fromOffset(150, 34),
				TextSize = 14,
				Parent = body,
			})
			home.Activated:Connect(function()
				Net.send("Sail", "home")
				Bus.Tap:Fire("sail_home")
				PanelController.close()
			end)
		end
		local list = scroller(body, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30) })
		for i, d in Voyages.list do
			local known = d.known or (profile.known and profile.known[d.key])
			local row = rowFrame(list, 70, i, known and nil or Color3.fromRGB(215, 210, 205))
			row.Name = "Dest_" .. d.key
			Theme.text({
				Text = known and d.icon or "❓",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(54, 54),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = row,
			})
			if known then
				local secs = Formulas.voyageSeconds(d.distance, raft.speed or 1)
				local visited = profile.visited and profile.visited[d.key]
				label(row, `{d.name}{visited and " ✓" or ""}`, {
					Position = UDim2.fromOffset(68, 4),
					Size = UDim2.fromOffset(300, 24),
					Font = Theme.Display,
					TextSize = 17,
				})
				label(
					row,
					`{string.rep("💀", d.danger)} · {math.floor(secs)}s away · {d.desc}`,
					{ Position = UDim2.fromOffset(68, 28), Size = UDim2.new(1, -230, 0, 20), TextSize = 13 }
				)
				local resources = {}
				for _, r in d.resources do
					local it = Items.get(r)
					table.insert(resources, it and it.icon or r)
				end
				label(row, `There: {table.concat(resources, " ")} · {d.landmark}`, {
					Position = UDim2.fromOffset(68, 48),
					Size = UDim2.new(1, -230, 0, 18),
					TextSize = 12,
					TextColor3 = C.muted,
				})
				local can = v.state == "docked"
					and raft.helm
					and d.danger <= allowed
					and (
						d.distance <= 2
						or (raft.stations and true)
							and (function()
								for _, p in raft.pieces or {} do
									if p.key == "nav_table" and not p.broken then
										return true
									end
								end
								return false
							end)()
					)
				local why = not raft.helm and "Needs a Helm"
					or d.danger > allowed and `Needs tier {table.find(Constants.DANGER_BY_TIER, d.danger) or 6}`
					or (not can and d.distance > 2) and "Needs a Navigation Table"
					or nil
				local b = Theme.button({
					Name = "Sail_" .. d.key,
					Text = why or "SAIL",
					BackgroundColor3 = can and C.good or C.muted,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(150, 42),
					TextSize = 13,
					Parent = row,
				})
				b.Activated:Connect(function()
					if can then
						Net.send("Sail", d.key)
						Bus.Tap:Fire("sail_" .. d.key)
						PanelController.close()
					end
				end)
			else
				label(row, "???", {
					Position = UDim2.fromOffset(68, 4),
					Size = UDim2.fromOffset(300, 24),
					Font = Theme.Display,
					TextSize = 17,
					TextColor3 = C.muted,
				})
				label(row, `{string.rep("💀", d.danger)} · {HOW[d.found] or "Somewhere out there"}`, {
					Position = UDim2.fromOffset(68, 30),
					Size = UDim2.new(1, -100, 0, 20),
					TextSize = 13,
					TextColor3 = C.muted,
				})
			end
		end
	end
	open.refresh = refresh
	refresh()
end

-- RAFT -----------------------------------------------------------------------------------------------------------------------
local function raftPanel()
	local body = panel("raft", "⛵ YOUR RAFT", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local raft = Store.get("raft") or { tier = 1, needs = {}, colours = {} }
		local profile = Store.get("profile") or { colours = {}, decks = {}, flags = {}, permit = "friends" }
		local t = Pieces.TIERS[raft.tier or 1]
		local list = scroller(body, { Size = UDim2.fromScale(1, 1), gap = 8 })
		local head = rowFrame(list, 70, 1, Color3.fromRGB(255, 240, 200))
		label(
			head,
			`{t and t.icon or "⛵"} TIER {raft.tier or 1}: {raft.tierName or ""}`,
			{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Font = Theme.Display, TextSize = 18 }
		)
		label(
			head,
			`{t and t.desc or ""} · {raft.tiles or 0}/{raft.max or 12} tiles · speed {raft.speed or 1}x · {raft.cargo or 16} slots{raft.broken and raft.broken > 0 and ` · 💥 {raft.broken} broken: hammer them` or ""}`,
			{ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 34), TextSize = 13 }
		)
		if raft.needs then
			local n = #raft.needs
			local box = rowFrame(list, 30 + n * 22, 2)
			label(box, `NEXT: {raft.nextTier or ""}`, {
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(1, -20, 0, 22),
				Font = Theme.Display,
				TextSize = 15,
			})
			for i, need in raft.needs do
				label(box, `{need.done and "✅" or "⬜"} {need.text} ({need.have}/{need.need})`, {
					Name = "Need_" .. i,
					Position = UDim2.fromOffset(16, 26 + (i - 1) * 22),
					Size = UDim2.new(1, -30, 0, 20),
					TextSize = 14,
					TextColor3 = need.done and Color3.fromRGB(30, 130, 60) or C.ink,
				})
			end
		end
		-- colours
		local function paintRow(order, kind, title, options, ownedOf)
			local row = rowFrame(list, 62, order)
			label(row, title, {
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.fromOffset(200, 22),
				Font = Theme.Display,
				TextSize = 15,
			})
			local x = 10
			for _, o in options do
				local owned = ownedOf(o.key)
				local current = raft.colours and raft.colours[kind] == o.key
				local b = Theme.button({
					Name = `Paint_{kind}_{o.key}`,
					Text = o.name,
					BackgroundColor3 = o.color or (owned and C.white or C.muted),
					dark = not o.color,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, x, 1, -4),
					Size = UDim2.fromOffset(94, 30),
					TextSize = 12,
					Parent = row,
				})
				if current then
					b.UIStroke.Color = C.mustard
					b.UIStroke.Thickness = 4
				end
				if not owned then
					b.Text = "🔒 " .. o.name
				end
				b.Activated:Connect(function()
					if owned then
						Net.send("Paint", kind, o.key)
						Bus.Tap:Fire("paint_" .. kind)
					end
				end)
				x += 98
			end
		end
		local colours = {}
		for key, c in Progression.COLORS do
			table.insert(colours, { key = key, name = c.name, color = c.color, free = c.free })
		end
		table.sort(colours, function(a, b)
			return (a.free and 0 or 1) < (b.free and 0 or 1) or (a.free == b.free and a.name < b.name)
		end)
		local function ownsColour(key)
			return Progression.COLORS[key].free or (profile.colours and profile.colours[key])
		end
		paintRow(3, "sail", "⛵ SAIL", colours, ownsColour)
		paintRow(4, "banner", "🎏 BANNERS AND BUNK", colours, ownsColour)
		paintRow(5, "flag", "🚩 FLAG", colours, ownsColour)
		local decks = {}
		for key, d in Progression.DECKS do
			table.insert(decks, { key = key, name = d.name, free = d.free })
		end
		table.sort(decks, function(a, b)
			return a.name < b.name
		end)
		paintRow(6, "deck", "🟫 DECK", decks, function(key)
			return Progression.DECKS[key].free or (profile.decks and profile.decks[key])
		end)
		local flags = {}
		for _, f in Progression.FLAGS do
			table.insert(flags, { key = f.key, name = f.name })
		end
		paintRow(7, "pattern", "🏴 FLAG PATTERN", flags, function(key)
			for _, f in Progression.FLAGS do
				if f.key == key then
					return f.free or (profile.flags and profile.flags[key])
				end
			end
			return false
		end)
		-- visitors
		local row = rowFrame(list, 62, 8)
		label(row, "👥 WHO MAY ROW OVER", {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.fromOffset(300, 22),
			Font = Theme.Display,
			TextSize = 15,
		})
		for i, mode in { "friends", "anyone", "nobody" } do
			local b = Theme.button({
				Name = "Permit_" .. mode,
				Text = string.upper(mode),
				BackgroundColor3 = profile.permit == mode and C.mustard or C.white,
				dark = profile.permit ~= mode,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10 + (i - 1) * 110, 1, -4),
				Size = UDim2.fromOffset(104, 30),
				TextSize = 13,
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Permit", mode)
				Bus.Tap:Fire("permit_" .. mode)
			end)
		end
		local d = Theme.button({
			Name = "Demolish",
			Text = "💥 DEMOLISH A PIECE",
			BackgroundColor3 = C.red,
			LayoutOrder = 9,
			Size = UDim2.new(1, -10, 0, 40),
			TextSize = 15,
			Parent = list,
		})
		d.Activated:Connect(function()
			Bus.Place:Fire("demolish")
			PanelController.close()
		end)
	end
	open.refresh = refresh
	refresh()
end

-- BOOK -----------------------------------------------------------------------------------------------------------------------
local BOOK_TABS = {
	{ key = "islands", label = "🏝️ PLACES" },
	{ key = "creatures", label = "🐾 CREATURES" },
	{ key = "fish", label = "🐟 FISH" },
	{ key = "artifacts", label = "🏺 ARTIFACTS" },
	{ key = "events", label = "🌊 AT SEA" },
	{ key = "notes", label = "📝 NOTES" },
}

local function bookPanel()
	local body = panel("book", "📔 THE JOURNAL", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local journal = Store.get("journal") or {}
		tabs(body, BOOK_TABS, bookTab, function(k)
			bookTab = k
			refresh()
		end)
		local list = scroller(body, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46) })
		local entries = journal[bookTab] or {}
		local order = 0
		local function row(found, icon, name, desc, n)
			order += 1
			local r = rowFrame(list, 52, order, found and nil or Color3.fromRGB(215, 210, 205))
			Theme.text({
				Text = found and icon or "❓",
				Position = UDim2.fromOffset(8, 4),
				Size = UDim2.fromOffset(44, 44),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = r,
			})
			label(r, found and name or "???", {
				Position = UDim2.fromOffset(60, 4),
				Size = UDim2.fromOffset(300, 22),
				Font = Theme.Display,
				TextSize = 16,
				TextColor3 = found and C.ink or C.muted,
			})
			label(r, found and desc or "Not met yet.", {
				Position = UDim2.fromOffset(60, 27),
				Size = UDim2.new(1, -140, 0, 22),
				TextSize = 13,
				TextColor3 = C.muted,
			})
			if found and n then
				label(r, `×{n}`, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -10, 0, 14),
					Size = UDim2.fromOffset(60, 24),
					Font = Theme.Display,
					TextSize = 15,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
		end
		if bookTab == "islands" then
			for _, d in Voyages.list do
				local e = entries[d.key]
				row(e ~= nil, d.icon, d.name, `{d.desc} {d.landmark}`, e and e.n)
			end
		elseif bookTab == "creatures" then
			for _, c in Creatures.list do
				local e = entries[c.key]
				row(e ~= nil, c.icon, c.name, `{c.desc} Tip: {c.tip}`, e and e.n)
			end
		elseif bookTab == "fish" then
			for _, f in Creatures.FISH do
				if not f.junk then
					local e = entries[f.key]
					row(
						e ~= nil,
						f.icon,
						f.name,
						`{Items.RARITY[f.rarity].name}{f.where and (" · " .. f.where .. " waters") or ""}{f.night and " · at night" or ""}`,
						e and e.n
					)
				end
			end
		elseif bookTab == "artifacts" then
			for _, it in Items.list do
				if it.kind == "artifact" then
					local e = entries[it.key]
					row(
						e ~= nil,
						it.icon,
						it.name,
						`{it.desc} Worth {Constants.RESEARCH_PER_ARTIFACT[it.research] or 10} research.`,
						e and e.n
					)
				end
			end
		elseif bookTab == "events" then
			for _, ev in Voyages.EVENTS do
				local e = entries[ev.key]
				row(e ~= nil, ev.icon, ev.name, ev.desc, e and e.n)
			end
		else
			local any = false
			for key, e in entries do
				any = true
				local d = Voyages.get(key)
				row(true, d and d.icon or "📝", d and d.name or key, e.text or "", nil)
			end
			if not any then
				label(
					list,
					"Look at the landmarks on the islands: their stories go here.",
					{ Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted }
				)
			end
		end
	end
	open.refresh = refresh
	refresh()
end

-- ME ---------------------------------------------------------------------------------------------------------------------------
local function mePanel()
	local body = panel("me", "👤 " .. string.upper(player.DisplayName), 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local profile = Store.get("profile")
		if not profile then
			label(body, "Loading...", { Size = UDim2.new(1, 0, 0, 30) })
			return
		end
		local list = scroller(body, { Size = UDim2.fromScale(1, 1), gap = 8 })
		local head = rowFrame(list, 60, 1, Color3.fromRGB(255, 240, 200))
		label(
			head,
			`LEVEL {profile.level} · {profile.into}/{profile.need} XP to the next · {profile.xpSession or 0} XP this session`,
			{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 24), Font = Theme.Display, TextSize = 16 }
		)
		local bar, fill = Theme.bar({ Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 14) }, C.mustard)
		bar.Parent = head
		fill.Size = UDim2.fromScale(math.clamp((profile.into or 0) / math.max(1, profile.need or 1), 0, 1), 1)
		-- titles
		local tr = rowFrame(list, 62, 2)
		label(tr, "TITLE", {
			Position = UDim2.fromOffset(10, 4),
			Size = UDim2.fromOffset(200, 22),
			Font = Theme.Display,
			TextSize = 15,
		})
		local x = 10
		for _, t in Progression.TITLES do
			local owned = table.find(profile.titles or {}, t.key) ~= nil
			local b = Theme.button({
				Name = "Title_" .. t.key,
				Text = owned and t.name or `🔒 {t.level and ("Lv " .. t.level) or "?"}`,
				BackgroundColor3 = profile.title == t.key and C.mustard or (owned and C.white or C.muted),
				dark = profile.title ~= t.key,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, x, 1, -4),
				Size = UDim2.fromOffset(124, 30),
				TextSize = 12,
				Parent = tr,
			})
			b.Activated:Connect(function()
				if owned then
					Net.send("Settings", "title", t.key)
				end
			end)
			x += 128
		end
		-- achievements
		local done = 0
		for _ in profile.achievements or {} do
			done += 1
		end
		label(list, `ACHIEVEMENTS · {done}/{#Progression.ACHIEVEMENTS}`, {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 22),
			Font = Theme.Display,
			TextSize = 15,
			TextColor3 = C.muted,
		})
		for i, a in Progression.ACHIEVEMENTS do
			local got = profile.achievements and profile.achievements[a.key]
			local r = rowFrame(list, 44, 10 + i, got and Color3.fromRGB(230, 245, 225) or Color3.fromRGB(225, 222, 215))
			r.Name = "Ach_" .. a.key
			local have = a.stat and (profile.stats and profile.stats[a.stat] or 0) or nil
			label(
				r,
				`{got and a.icon or "🔒"} {a.name}: {a.desc}{(not got and have) and ` ({math.min(have, a.goal)}/{a.goal})` or ""}`,
				{
					Position = UDim2.fromOffset(10, 4),
					Size = UDim2.new(1, -20, 1, -8),
					TextSize = 14,
					TextColor3 = got and C.ink or C.muted,
				}
			)
		end
		local st = profile.stats or {}
		local statsRow = rowFrame(list, 70, 100)
		label(
			statsRow,
			`🔗 {st.debris or 0} hooked · 🔨 {st.built or 0} built · 🛠️ {st.crafted or 0} crafted · ⛵ {st.voyages or 0} voyages · 🎣 {st.fish or 0} fish · 📔 {profile.journalCount or 0} journal entries · ⛈️ {st.storms or 0} storms · 💀 {st.deaths or 0} downs · 🐲 {st.leviathans or 0} leviathans`,
			{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), TextSize = 14 }
		)
	end
	open.refresh = refresh
	refresh()
end

-- TOP ---------------------------------------------------------------------------------------------------------------------------
local function boardsPanel()
	local body = panel("boards", "🏆 LEADERBOARDS", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		local list = {}
		for _, b in Progression.BOARDS do
			table.insert(list, { key = b.key, label = b.icon .. " " .. b.name })
		end
		tabs(body, list, boardTab, function(k)
			boardTab = k
			Net.send("Board", k)
			refresh()
		end)
		local board = Store.get("board")
		local def = Progression.boardByKey[boardTab]
		local function column(x, title, rows, loading)
			local frame = new("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(x, 0, 0, 48),
				Size = UDim2.new(0.5, -6, 1, -48),
				Parent = body,
			})
			label(
				frame,
				title,
				{ Size = UDim2.new(1, 0, 0, 22), Font = Theme.Display, TextSize = 15, TextColor3 = C.muted }
			)
			local l = scroller(frame, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), gap = 4 })
			for i, r in rows or {} do
				local row = rowFrame(l, 34, i, r.you and Color3.fromRGB(255, 240, 200) or nil)
				label(row, `#{r.rank or "-"} {r.name or "?"}{r.here and " 🟢" or ""}`, {
					Position = UDim2.fromOffset(8, 2),
					Size = UDim2.new(0.7, 0, 1, -4),
					TextSize = 14,
					Font = Theme.Display,
				})
				label(row, `{r.value or "-"}{def and def.unit or ""}`, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 2),
					Size = UDim2.new(0.3, 0, 1, -4),
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Right,
				})
			end
			if not rows or #rows == 0 then
				label(
					l,
					loading and "Loading..." or "Nobody yet.",
					{ Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted }
				)
			end
		end
		if board and board.category == boardTab then
			column(0, "FRIENDS" .. (board.loading and " (loading...)" or ""), board.friends, board.loading)
			column(0.5, "EVERYONE", board.global, false)
		else
			label(
				body,
				"Loading...",
				{ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 30), TextColor3 = C.muted }
			)
		end
	end
	open.refresh = refresh
	Net.send("Board", boardTab)
	refresh()
end

-- FRIENDS ---------------------------------------------------------------------------------------------------------------------
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

local function friendsPanel()
	local body = panel("friends", "👥 FRIENDS", 820, 480)
	local friends = {}
	local function refresh()
		body:ClearAllChildren()
		local data = Store.get("friends") or {}
		local me = Store.get("me") or {}
		label(
			body,
			friendStatus ~= "" and friendStatus or "Rafts in this server: row over and look around.",
			{ Size = UDim2.new(1, 0, 0, 22), Font = Theme.Display, TextSize = 15 }
		)
		local list = scroller(body, { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -86) })
		local order = 0
		for _, r in data.rafts or {} do
			order += 1
			local row = rowFrame(list, 50, order)
			row.Name = "Row_" .. r.userId
			local t = Pieces.TIERS[r.tier or 1]
			label(row, `{r.name}{r.friend and " 💚" or ""}`, {
				Position = UDim2.fromOffset(10, 2),
				Size = UDim2.new(0.35, 0, 1, -4),
				Font = Theme.Display,
				TextSize = 15,
			})
			label(
				row,
				`{t and t.icon or "⛵"} {t and t.name or ""} · {r.tiles} tiles · {r.permit == "nobody" and "no visitors" or r.permit == "friends" and "friends only" or "anyone welcome"}`,
				{ Position = UDim2.new(0.35, 0, 0, 2), Size = UDim2.new(0.65, -140, 1, -4), TextSize = 13 }
			)
			local here = me.visiting == r.userId
			local b = Theme.button({
				Name = (here and "Home_" or "Over_") .. r.userId,
				Text = here and "ROW HOME" or (r.allowed and "ROW OVER" or "🔒"),
				BackgroundColor3 = here and C.orange or (r.allowed and C.good or C.muted),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 38),
				TextSize = 13,
				Parent = row,
			})
			b.Activated:Connect(function()
				if here then
					Net.send("Visit", false)
				elseif r.allowed then
					Net.send("Visit", r.userId)
					Bus.Tap:Fire("row_over")
					PanelController.close()
				end
			end)
		end
		order += 1
		label(list, "FRIENDS IN OTHER SERVERS", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 22),
			Font = Theme.Display,
			TextSize = 14,
			TextColor3 = C.muted,
		})
		local views = {}
		for _, v in data.friends or {} do
			views[v.userId] = v
		end
		for _, f in friends do
			local v = views[f.userId] or {}
			if v.here then
				continue
			end
			order += 1
			local row = rowFrame(list, 50, order)
			local t = Pieces.TIERS[v.tier or 1]
			local status = v.unknown and "Playing"
				or `{t and t.name or "a raft"} · {v.crew or "?"}/{v.max or 6}{v.full and " (full)" or ""}{v.private and " · private" or ""}`
			label(row, f.name, {
				Position = UDim2.fromOffset(10, 2),
				Size = UDim2.new(0.4, 0, 1, -4),
				Font = Theme.Display,
				TextSize = 15,
			})
			label(
				row,
				status,
				{ Position = UDim2.new(0.4, 0, 0, 2), Size = UDim2.new(0.6, -140, 1, -4), TextSize = 13 }
			)
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
		if #friends == 0 then
			order += 1
			label(
				list,
				"No friends sailing right now. Invite some!",
				{ LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.muted }
			)
		end
		local function bottom(name, text, color, x, fn)
			local b = Theme.button({
				Name = name,
				Text = text,
				BackgroundColor3 = color,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(x, 4, 1, 0),
				Size = UDim2.new(1 / 3, -8, 0, 48),
				TextSize = 15,
				Parent = body,
			})
			b.Activated:Connect(fn)
		end
		bottom("Private", "🔒 PRIVATE OCEAN", C.purple, 0, function()
			Net.send("FriendAction", "private")
		end)
		bottom("Invite", "✉️ INVITE", C.sky, 1 / 3, function()
			pcall(function()
				game:GetService("SocialService"):PromptGameInvite(player)
			end)
		end)
		bottom("Refresh", "🔄 REFRESH", C.orange, 2 / 3, function()
			PanelController.loadFriends(friends, refresh)
		end)
	end
	open.refresh = refresh
	PanelController.loadFriends(friends, refresh)
	refresh()
end

-- MORE -------------------------------------------------------------------------------------------------------------------------
local HOW_TO = {
	"🔗 Hook what floats past: aim at it and tap ACT. Nets catch it for you.",
	"🔨 BUILD tiles beside your raft, then stations and systems on them.",
	"🛠️ Stand at a station to craft. Costs are shown as have/need.",
	"🎚️ Build a Helm, open the MAP and SAIL. Things happen on the way.",
	"🏝️ Islands rise beside your raft: chop, mine, search, look, then sail home.",
	"💀 Go down away from your dock and half your finds float off as a bag. Hook it back.",
	"⛵ Tiers come from what the raft can do. The RAFT panel shows the next one.",
}

local function settingsPanel()
	local body = panel("settings", "⚙️ MORE", 780, 470)
	local function refresh()
		body:ClearAllChildren()
		local s = Store.get("settings") or {}
		local list = scroller(body, { Size = UDim2.fromScale(1, 1), gap = 8 })
		local row = rowFrame(list, 60, 1)
		local function toggle(name, text, key, x)
			local on = s[key] ~= false
			local b = Theme.button({
				Name = "Toggle_" .. key,
				Text = `{text}: {on and "ON" or "OFF"}`,
				BackgroundColor3 = on and C.good or C.muted,
				Position = UDim2.fromOffset(x, 10),
				Size = UDim2.fromOffset(220, 40),
				TextSize = 15,
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Settings", key, not on)
				local st = Store.get("settings") or {}
				st[key] = not on
				Store.Changed:Fire({ settings = st })
			end)
			_ = name
		end
		toggle("Music", "🎵 Music", "music", 10)
		toggle("Shake", "📳 Screen shake", "shake", 240)
		toggle("Fx", "✨ Effects", "fx", 470)
		label(list, "HOW TO PLAY", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 22),
			Font = Theme.Display,
			TextSize = 15,
			TextColor3 = C.muted,
		})
		for i, line in HOW_TO do
			label(list, line, { LayoutOrder = 2 + i, Size = UDim2.new(1, -10, 0, 24), TextSize = 14 })
		end
		local invite = Theme.button({
			Name = "Invite",
			Text = "✉️ INVITE FRIENDS",
			BackgroundColor3 = C.sky,
			LayoutOrder = 20,
			Size = UDim2.new(1, -10, 0, 44),
			TextSize = 15,
			Parent = list,
		})
		invite.Activated:Connect(function()
			pcall(function()
				game:GetService("SocialService"):PromptGameInvite(player)
			end)
		end)
	end
	open.refresh = refresh
	refresh()
end

-- Cards ---------------------------------------------------------------------------------------------------------------------------
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

local function onFriendResult(r)
	if type(r) ~= "table" then
		return
	end
	local name = r.name or "your friend"
	if r.kind == "teleporting" then
		friendStatus = `✈️ Going to {name}...`
	elseif r.kind == "full" then
		friendStatus = `{name}'s server is full.`
		PanelController.card(
			"full",
			`{name}'s server is full`,
			`Wait for a spot (we'll try every {r.every or 20} s), or start an ocean of your own.`,
			{
				{
					text = "⏳ WAIT",
					color = C.sky,
					fn = function()
						Net.send("FriendAction", "retry")
					end,
				},
				{
					text = "🔒 PRIVATE",
					color = C.purple,
					fn = function()
						Net.send("FriendAction", "private")
					end,
				},
				{
					text = "CANCEL",
					color = C.slate,
					fn = function()
						Net.send("FriendAction", "cancel")
					end,
				},
			}
		)
	elseif r.kind == "waiting" then
		friendStatus = `⏳ Waiting for a spot on {name}'s server ({r.tries or 0}/{r.max or 6})...`
	elseif r.kind == "here" then
		friendStatus = `{name} is in this server! Row over from the list.`
	elseif r.kind == "gone" then
		friendStatus = `{name} isn't sailing any more.`
	elseif r.kind == "failed" then
		friendStatus = r.text or "That didn't work."
		if r.stillFull then
			PanelController.card("stillfull", "Still full", r.text, {
				{
					text = "🔒 PRIVATE",
					color = C.purple,
					fn = function()
						Net.send("FriendAction", "private")
					end,
				},
				{ text = "OK", color = C.slate },
			})
		end
	end
	if open and open.name == "friends" and open.refresh then
		open.refresh()
	end
end

local function onAsk(a)
	if type(a) ~= "table" then
		return
	end
	if a.kind == "feedback" then
		local chosen = {}
		PanelController.card(
			"feedback",
			"Do you like The Endless Voyage?",
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
								Name = "Reason_" .. r.key,
								Text = r.text,
								BackgroundColor3 = C.white,
								dark = true,
								Size = UDim2.fromOffset(170, 40),
								Position = UDim2.fromOffset(
									14 + ((i - 1) % 3) * 178,
									110 + math.floor((i - 1) / 3) * 46
								),
								TextSize = 13,
								Parent = c,
							})
							btn.Activated:Connect(function()
								chosen[r.key] = not chosen[r.key]
								btn.BackgroundColor3 = chosen[r.key] and C.mustard or C.white
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
	elseif a.kind == "thanks" then
		PanelController.card(
			"thanks",
			"Thank you! 💚",
			a.like and "Glad you're having fun. Fair winds!" or "Thanks for telling us. We're on it.",
			{ { text = "OK", color = C.good } }
		)
	elseif a.kind == "notify" and NotifyController.canAsk() then
		Net.send("Notify", "shown")
		PanelController.card(
			"notify",
			"Get told about updates?",
			"New islands, new creatures, events. We'll let you know.",
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

-- Opening ---------------------------------------------------------------------------------------------------------------------------
local OPENERS = {
	build = buildPanel,
	inventory = inventoryPanel,
	craft = craftPanel,
	map = mapPanel,
	raft = raftPanel,
	book = bookPanel,
	me = mePanel,
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
		sendViewed(name)
	end
end

function PanelController.current()
	return open and open.name or nil
end

function PanelController:init()
	gui = Theme.screen("Panels", 8, player:WaitForChild("PlayerGui"))
	Bus.Open:Connect(PanelController.openPanel)
	Bus.Close:Connect(PanelController.close)
	Net.listen("Ask", onAsk)
	Net.listen("FriendResult", onFriendResult)
	Store.Changed:Connect(function(partial)
		if not open or not open.refresh then
			return
		end
		local n = open.name
		if
			(partial.inv and (n == "inventory" or n == "craft" or n == "build"))
			or (partial.raft and (n == "raft" or n == "build" or n == "map"))
			or (partial.profile and (n == "me" or n == "raft" or n == "map" or n == "build" or n == "craft"))
			or (partial.journal and n == "book")
			or (partial.board and n == "boards")
			or (partial.friends and n == "friends")
			or (partial.me and n == "friends")
			or (partial.voyage and n == "map")
			or (partial.settings and n == "settings")
		then
			open.refresh()
		end
	end)
	-- the raft's prompts open their panels
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
			if who ~= player then
				return
			end
			local kind = prompt:GetAttribute("Kind")
			if kind == "station" then
				PanelController.openPanel("craft", prompt:GetAttribute("Station"))
			elseif kind == "helm" then
				PanelController.openPanel("map", true)
			end
		end)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) and open then
			PanelController.close()
		end
	end)
end

-- (tests)
PanelController.cards = cards

return PanelController

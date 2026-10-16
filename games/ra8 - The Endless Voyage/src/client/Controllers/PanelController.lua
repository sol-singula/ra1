--[[
The panels (master plan §4: readable costs; §5: the raft's tier is a goal you can see; §6: progress you can
see). One open at a time, big tap targets, closes with X, Escape or B:

  BUILD     every piece by section, its cost (have/need, green when you can afford it), what locks it (a tier, a
            blueprint); tap PLACE and BuildController takes over. REMOVE too.
  BAG       the hotbar and the bag: drag an item to another slot (or tap one, then the other) to move or swap it;
            tap or hover one to see it: its picture, what it does, its numbers; USE / HOLD / DROP; RESEARCH an
            artifact at the Research Station
  CRAFT     opens at a station: what it makes, what each costs, MAKE; the Research Station's points and the
            next milestone; the Decorative Workshop's dyes
  MAP       the destinations: the ones you have charts for (distance, danger, what's there, SAIL), the ones you
            don't (how to find them); SAIL HOME at an island
  RAFT      the tier, what the next one needs, speed and cargo, the colours, who may visit, REMOVE
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
local Icons = require(script.Parent.Parent.UI.Icons)
local Layout = require(script.Parent.Parent.UI.Layout)

local PanelController = { Name = "PanelController", Order = 12 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local open -- { name, frame, body, refresh, arg, cells }
local picked
local drag -- { from, slot, start (Vector2), moved, ghost } an item being dragged in the bag
local hover -- the bag slot under the mouse (keyboard players): its details show without picking it
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
		pcall(function()
			GuiService.SelectedObject = nil
		end)
	end
	picked = nil
	hover = nil
	if drag and drag.ghost then
		drag.ghost:Destroy()
	end
	drag = nil
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
	-- (only a gamepad gets the selection cursor: on a keyboard it would trap the arrow keys and Escape)
	if Theme.inputKind() == "gamepad" then
		pcall(function()
			GuiService.SelectedObject = x
		end)
	end
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

-- What something costs, one chip per material: icon, name, what you have / what it needs (12/4 when you have 12),
-- green once you have enough.
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
		local shown = have > 999 and "999+" or tostring(have)
		local chip = label(parent, `{item and item.icon or ""} {item and item.name or k} {shown}/{cost[k]}`, {
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

-- The piece the guide wants built: the step's piece, the NEXT goal's QUICK piece, else the raft's first
-- recommendation.
local STEP_PIECE = { tile = "floor", bench = "workbench", net = "net", helm = "helm" }
local function wantedPiece(arg)
	if type(arg) == "string" and Pieces.get(arg) then
		return arg
	end
	local g = Store.get("tutorial")
	if type(g) == "table" then
		if g.quick then
			return g.quick
		elseif STEP_PIECE[g.key] then
			return STEP_PIECE[g.key]
		end
	end
	local raft = Store.get("raft")
	local rec = raft and raft.recommend and raft.recommend[1]
	return rec and rec.key or nil
end
PanelController.wantedPiece = wantedPiece

local RAIL = 132 -- the category rail on the left
local HEADER_H, ROW_H, GAP = 22, 62, 6

local function buildPanel(arg)
	local body = panel("build", "🔨 BUILD", 860, 480)
	local scrollTo -- the canvas Y of the wanted row (once, when the panel opens)
	local function refresh()
		body:ClearAllChildren()
		local raft = Store.get("raft") or { tier = 1, tiles = 0, max = 12 }
		local profile = Store.get("profile") or { blueprints = {} }
		label(
			body,
			`{raft.tierName or "Driftwood Platform"} · {raft.tiles or 0} floors. Tap PLACE, then tap a spot on your raft.`,
			{
				Size = UDim2.new(1, -130, 0, 22),
				TextSize = 15,
			}
		)
		local demolish = Theme.button({
			Name = "Demolish",
			Text = "♻️ REMOVE",
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
		local list =
			scroller(body, { Position = UDim2.fromOffset(RAIL + 8, 30), Size = UDim2.new(1, -RAIL - 8, 1, -30) })
		local rail = new("Frame", {
			Name = "Categories",
			BackgroundColor3 = Color3.fromRGB(226, 214, 190),
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(0, RAIL, 1, -30),
			Parent = body,
		}, {
			Theme.corner(12),
			new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			new("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		})
		local wanted = wantedPiece(arg)
		local tops, catTabs = {}, {}
		local y = 0
		local order = 0
		for si, section in SECTIONS do
			order += 1
			tops[si] = y
			y += HEADER_H + GAP
			local tab = Theme.button({
				Name = "Cat_" .. section[1],
				Text = section[1],
				LayoutOrder = si,
				BackgroundColor3 = C.slate,
				Size = UDim2.new(1, 0, 0, 40),
				TextSize = 13,
				Parent = rail,
			})
			catTabs[si] = tab
			tab.Activated:Connect(function()
				list.CanvasPosition = Vector2.new(0, tops[si])
				Bus.Tap:Fire("build_cat")
			end)
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
				if def.key == wanted and not scrollTo then
					scrollTo = math.max(0, y - HEADER_H - GAP)
				end
				y += ROW_H + GAP
				local locked
				if def.blueprint and not profile.blueprints[def.key] then
					locked = "📜 Needs its blueprint (crates, islands, research)"
				elseif def.tier > (raft.tier or 1) then
					locked = Formulas.lockedText(def, raft)
				elseif def.decor and def.tier >= 2 and not (raft.stations and raft.stations.decor) then
					locked = "🔒 Needs the Decorative Workshop"
				end
				local row = rowFrame(list, ROW_H, order, locked and Color3.fromRGB(215, 210, 205) or nil)
				row.Name = "Piece_" .. def.key
				if def.key == wanted then
					-- what the guide wants: gold, tagged, and scrolled to
					row.BackgroundColor3 = Color3.fromRGB(255, 236, 160)
					local stroke = row:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Color = C.mustard
						stroke.Thickness = 4
					end
					row:SetAttribute("Wanted", true)
					label(row, "⭐ NEXT", {
						Name = "Next",
						Position = UDim2.new(1, -230, 0, 4),
						Size = UDim2.fromOffset(110, 20),
						Font = Theme.Display,
						TextSize = 15,
						TextColor3 = C.orange,
					})
				end
				local pic = new("Frame", {
					Name = "Picture",
					BackgroundColor3 = Color3.fromRGB(70, 110, 160),
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.fromOffset(50, 50),
					Parent = row,
				}, { Theme.corner(10) })
				if not Icons.piece(pic, def.key, { inset = 2, colours = raft.colours }) then
					Theme.text({
						Text = def.icon,
						Size = UDim2.fromScale(1, 1),
						TextXAlignment = Enum.TextXAlignment.Center,
						Parent = pic,
					})
				end
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
				if not locked then
					-- 📌 puts this piece in your hotbar as a build shortcut
					local pin = Theme.button({
						Name = "Pin",
						Text = "📌",
						BackgroundColor3 = C.sky,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -122, 0.5, 0),
						Size = UDim2.fromOffset(42, 42),
						TextSize = 18,
						Parent = row,
					})
					pin.Activated:Connect(function()
						Net.send("Pin", def.key)
						Bus.Tap:Fire("pin_" .. def.key)
					end)
				end
			end
		end
		-- the rail follows the scroll: the section you're in is lit
		local function lit()
			local cp = list.CanvasPosition
			local at = (cp and cp.Y or 0) + 8
			local cur = 1
			for si, top in tops do
				if top <= at then
					cur = si
				end
			end
			for si, tab in catTabs do
				tab.BackgroundColor3 = si == cur and C.mustard or C.slate
			end
		end
		list:GetPropertyChangedSignal("CanvasPosition"):Connect(lit)
		if scrollTo and scrollTo >= 0 then
			list.CanvasPosition = Vector2.new(0, scrollTo)
			scrollTo = -1 -- (once: a refresh keeps where you scrolled)
		elseif open and open.buildScroll then
			list.CanvasPosition = open.buildScroll
		end
		list:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
			if open then
				open.buildScroll = list.CanvasPosition
			end
		end)
		lit()
	end
	open.refresh = refresh
	refresh()
end

-- BAG -----------------------------------------------------------------------------------------------------------------------
local CELL = 62
local BUFF_NAME = { hearty = "Hearty (tougher)", swift = "Swift (faster)", lucky = "Lucky (better casts)" }
local suppressUntil = 0 -- a tap right after a drag is not a tap

-- A picture of the item in a cell: its own model, or the emoji if it can't be drawn.
local function itemPicture(parent, item, inset, zIndex)
	local drawn = item and Icons.item(parent, item.key, { inset = inset or 4, zIndex = zIndex or 1 })
	if item and not drawn then
		Theme.text({
			Name = "Icon",
			Text = item.icon or "",
			Size = UDim2.new(1, -8, 1, -16),
			Position = UDim2.fromOffset(4, 4),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = parent,
		})
	end
end

-- The item's numbers, in words.
local function statLines(item, slot)
	local lines = {}
	local t = item.tool
	if t and t.rod then
		table.insert(lines, `🎣 Casts {t.rod.range} studs · reels in ×{t.rod.pull}`)
		local extra = (t.rod.rare or 0) > 0 and ` · rare fish +{math.floor(t.rod.rare * 100)}%` or ""
		table.insert(lines, `🐟 Bites ×{t.rod.speed} as fast{extra}`)
		if (t.rod.double or 0) > 0 then
			table.insert(lines, `Two pieces at once {math.floor(t.rod.double * 100)}% of the time`)
		end
		if t.rod.salvage then
			table.insert(lines, "Its claw finds metal and pearls in the debris")
		end
	elseif t and (t.axe or t.pick or t.pry) then
		local spec = t.axe or t.pick or t.pry
		local what = t.axe and "palms and trees" or t.pick and "rocks and ore" or "wrecks' salvage"
		table.insert(lines, `💪 Power ×{spec.power} on {what}`)
	elseif t and t.hammer then
		table.insert(lines, `🔨 Repairs {t.hammer.repair} health a hit (1 wood each)`)
	end
	if item.light then
		table.insert(lines, `💡 Lights {item.light.range} studs around you`)
	end
	if item.weapon then
		local wpn = item.weapon
		table.insert(
			lines,
			`⚔️ Damage {wpn.dmg} · reach {wpn.range}{wpn.thrown and " · thrown, it comes back" or ""}`
		)
	end
	if item.food then
		local buff = item.food.buff
		local more = buff and ` · {BUFF_NAME[buff.key] or buff.key} for {math.floor(buff.seconds / 60)} min` or ""
		table.insert(lines, `❤️ Heals {item.food.heal}{more}`)
	end
	if item.research then
		table.insert(
			lines,
			`📚 Worth {Constants.RESEARCH_PER_ARTIFACT[item.research] or 10} research at the Research Station`
		)
	end
	if slot and slot.data then
		if slot.data.dest and Voyages.get(slot.data.dest) then
			table.insert(lines, `🗺️ Marks {Voyages.get(slot.data.dest).name} on your map`)
		end
		if slot.data.key then
			local def = Pieces.get(slot.data.key) or Recipes.get(slot.data.key)
			local name = def and (def.name or (def.item and Items.get(def.item) and Items.get(def.item).name))
				or slot.data.key
			table.insert(lines, `📜 Teaches: {name}`)
		end
	end
	if item.kind == "resource" and (item.stack or 1) > 1 then
		table.insert(lines, `Stacks to {item.stack} a slot`)
	end
	return lines
end

local function itemCell(parent, slotId, slot, order, onClick, onEnter, onLeave)
	local item = slot and Items.get(slot.key)
	local r = rarity(item)
	local b = new("TextButton", {
		Name = "Slot_" .. slotId,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order or 0,
		BackgroundColor3 = item and Theme.darken(r.color, 0.5) or Color3.fromRGB(70, 70, 90),
		Size = UDim2.fromOffset(CELL, CELL),
		Parent = parent,
	}, { Theme.corner(12) })
	local base = item and r.color or C.ink
	local stroke = Theme.stroke(picked == slotId and 5 or 3, picked == slotId and C.mustard or base)
	stroke:SetAttribute("Base", base)
	stroke.Parent = b
	itemPicture(b, item, 4, 1)
	Theme.title({
		Name = "Count",
		Text = (slot and slot.n > 1) and tostring(slot.n) or "",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromOffset(40, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		outline = 2,
		Parent = b,
	})
	b.Activated:Connect(function()
		if os.clock() < suppressUntil then
			return
		end
		onClick(slotId, slot)
	end)
	b.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if slot and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			drag =
				{ from = slotId, slot = slot, start = Vector2.new(input.Position.X, input.Position.Y), moved = false }
		end
	end)
	if onEnter then
		b.MouseEnter:Connect(function()
			onEnter(slotId)
		end)
		b.MouseLeave:Connect(function()
			onLeave(slotId)
		end)
	end
	return b
end

-- Where the pointer is, in the GUI's pixels (the same space as AbsolutePosition).
local function pointer(input)
	if input and input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local ok, pos = pcall(UserInputService.GetMouseLocation, UserInputService)
	if not ok or typeof(pos) ~= "Vector2" then
		return input and Vector2.new(input.Position.X, input.Position.Y) or Vector2.zero
	end
	local inset = Vector2.zero
	pcall(function()
		inset = GuiService:GetGuiInset()
	end)
	return pos - inset
end

local function inside(obj, pos)
	local p, sz = obj.AbsolutePosition, obj.AbsoluteSize
	if typeof(p) ~= "Vector2" or typeof(sz) ~= "Vector2" then
		return false
	end
	return pos.X >= p.X and pos.Y >= p.Y and pos.X <= p.X + sz.X and pos.Y <= p.Y + sz.Y
end

-- The slot under the pointer: a cell of the open bag, or a slot of the HUD's hotbar.
local function slotUnder(pos)
	if open and open.cells then
		for id, cell in open.cells do
			if cell.Parent and inside(cell, pos) then
				return id
			end
		end
	end
	local pg = player:FindFirstChild("PlayerGui")
	local hud = pg and pg:FindFirstChild("Hud")
	local bar = hud and hud:FindFirstChild("Hotbar")
	for i = 1, Constants.HOTBAR do
		local b = bar and bar:FindFirstChild("Slot" .. i)
		if b and inside(b, pos) then
			return "h" .. i
		end
	end
	return nil
end

-- Move (or swap) what is in one slot to another.
function PanelController.dropOn(from, to)
	if from and to and from ~= to then
		Net.send("Move", from, to)
		Bus.Tap:Fire("move_item")
	end
	picked = nil
	if open and open.refresh then
		open.refresh()
	end
end

local function dragMove(input)
	if not drag or not open then
		return
	end
	local pos = pointer(input)
	if not drag.moved then
		if (pos - drag.start).Magnitude < 10 then
			return
		end
		drag.moved = true
		picked = nil
		local item = Items.get(drag.slot.key)
		local ghost = new("Frame", {
			Name = "DragGhost",
			BackgroundColor3 = Theme.darken(rarity(item).color, 0.4),
			BackgroundTransparency = 0.15,
			Size = UDim2.fromOffset(CELL, CELL),
			ZIndex = 40,
			Parent = gui,
		}, { Theme.corner(12), Theme.stroke(4, C.mustard) })
		itemPicture(ghost, item, 4, 41)
		drag.ghost = ghost
	end
	local k = 1
	local origin = Vector2.zero
	pcall(function()
		k = gui.Scale.Scale or 1
		origin = gui.AbsolutePosition or Vector2.zero
	end)
	drag.ghost.Position = UDim2.fromOffset((pos.X - origin.X) / k - CELL / 2, (pos.Y - origin.Y) / k - CELL / 2)
	-- the slot under the ghost lights up
	local under = slotUnder(pos)
	if open.cells then
		for id, cell in open.cells do
			local stroke = cell:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = id == under and C.mustard or stroke:GetAttribute("Base") or stroke.Color
				stroke.Thickness = id == under and 5 or 3
			end
		end
	end
end

local function dragEnd(input)
	local d = drag
	drag = nil
	if not d then
		return
	end
	if d.ghost then
		d.ghost:Destroy()
	end
	if not d.moved then
		return
	end
	suppressUntil = os.clock() + 0.3
	local to = slotUnder(pointer(input))
	if to then
		PanelController.dropOn(d.from, to)
	elseif open and open.refresh then
		open.refresh()
	end
end

-- The card on the right: the picture, the name, what it does, its numbers, the buttons.
local function detailsCard(parent, inv, slotId)
	local old = parent:FindFirstChild("Details")
	if old then
		old:Destroy()
	end
	local card = new("Frame", {
		Name = "Details",
		BackgroundColor3 = Color3.fromRGB(240, 230, 210),
		Position = UDim2.new(1, -268, 0, 0),
		Size = UDim2.new(0, 268, 1, 0),
		Parent = parent,
	}, { Theme.corner(14), Theme.stroke(2) })
	local slot = slotId and inv.slots[slotId]
	local item = slot and Items.get(slot.key)
	if not item then
		label(
			card,
			"Tap an item to see it.\n\nDrag it to another slot to move it (or tap one slot, then the other).\n\nThe hotbar is what you can hold: tap a slot or press 1-6.",
			{
				Name = "Text",
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 1, -24),
				TextSize = 15,
				TextColor3 = C.muted,
				TextYAlignment = Enum.TextYAlignment.Top,
			}
		)
		return card
	end
	local r = rarity(item)
	local pic = new("Frame", {
		Name = "Picture",
		BackgroundColor3 = Theme.darken(r.color, 0.5),
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(96, 96),
		Parent = card,
	}, { Theme.corner(14), Theme.stroke(3, r.color) })
	itemPicture(pic, item, 6, 1)
	label(card, item.name, {
		Name = "ItemName",
		Position = UDim2.fromOffset(114, 10),
		Size = UDim2.new(1, -124, 0, 44),
		Font = Theme.Display,
		TextSize = 18,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	label(card, `{r.name} {item.kind}{slot.n > 1 and ` · ×{slot.n}` or ""}`, {
		Name = "Kind",
		Position = UDim2.fromOffset(114, 56),
		Size = UDim2.new(1, -124, 0, 18),
		TextSize = 13,
		TextColor3 = Theme.darken(r.color, 0.35),
	})
	label(card, string.sub(slotId, 1, 1) == "h" and "In your hotbar" or "In your bag", {
		Name = "Where",
		Position = UDim2.fromOffset(114, 76),
		Size = UDim2.new(1, -124, 0, 18),
		TextSize = 13,
		TextColor3 = C.muted,
	})
	local y = 114
	label(card, item.desc or "", {
		Name = "Desc",
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -24, 0, 40),
		TextSize = 14,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	y += 44
	for i, line in statLines(item, slot) do
		label(card, line, {
			Name = "Stat" .. i,
			Position = UDim2.fromOffset(12, y),
			Size = UDim2.new(1, -24, 0, 34),
			TextSize = 13,
			TextColor3 = Color3.fromRGB(60, 70, 110),
			TextYAlignment = Enum.TextYAlignment.Top,
		})
		y += 30
	end
	-- the buttons, two to a row at the bottom
	local buttons = {}
	local function btn(name, text, color, fn)
		table.insert(buttons, { name = name, text = text, color = color, fn = fn })
	end
	if item.food or item.kind == "chart" or item.kind == "blueprint" or item.key == "supply_crate" then
		btn(
			"Use",
			item.food and "EAT" or item.kind == "blueprint" and "LEARN" or item.kind == "chart" and "READ" or "OPEN",
			C.good,
			function()
				Net.send("Use", slotId)
				Bus.Tap:Fire("use_" .. item.key)
			end
		)
	end
	if item.research then
		btn("Research", "RESEARCH", C.purple, function()
			Net.send("Research", slotId)
			Bus.Tap:Fire("research")
		end)
	end
	if string.sub(slotId, 1, 1) == "b" then
		btn("Hold", "HOLD", C.sky, function()
			-- to an empty hotbar slot, else the selected one (swapping what's there)
			local to = "h" .. tostring(inv.selected or 1)
			for i = 1, Constants.HOTBAR do
				if not inv.slots["h" .. i] then
					to = "h" .. i
					break
				end
			end
			PanelController.dropOn(slotId, to)
			Bus.Tap:Fire("hold_item")
		end)
	else
		btn("Hold", "TO BAG", C.sky, function()
			for i = 1, inv.capacity or 16 do
				if not inv.slots["b" .. i] then
					PanelController.dropOn(slotId, "b" .. i)
					return
				end
			end
			Bus.Tap:Fire("bag_full")
		end)
	end
	btn("Drop", "DROP", C.red, function()
		Net.send("Drop", slotId, 1)
		Bus.Tap:Fire("drop")
	end)
	local rows = math.ceil(#buttons / 2)
	for i, spec in buttons do
		local row = (i - 1) // 2
		local col = (i - 1) % 2
		local wide = (#buttons % 2 == 1) and i == #buttons
		local b = Theme.button({
			Name = spec.name,
			Text = spec.text,
			BackgroundColor3 = spec.color,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10 + col * 126, 1, -10 - (rows - 1 - row) * 46),
			Size = UDim2.fromOffset(wide and 248 or 120, 40),
			TextSize = 14,
			Parent = card,
		})
		b.Activated:Connect(spec.fn)
	end
	return card
end

local function inventoryPanel()
	local body = panel("inventory", "🎒 YOUR BAG", 820, 480)
	local function refresh()
		body:ClearAllChildren()
		open.cells = {}
		local inv = Store.get("inv") or { slots = {}, capacity = 16 }
		if picked and not inv.slots[picked] then
			picked = nil -- (used up or dropped)
		end
		if hover and not inv.slots[hover] then
			hover = nil
		end
		local left = new("Frame", {
			Name = "Left",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -280, 1, 0),
			Parent = body,
		})
		label(left, "HOTBAR (what you can hold: tap a slot or press 1-6)", {
			Size = UDim2.new(1, 0, 0, 20),
			Font = Theme.Display,
			TextSize = 14,
			TextColor3 = C.muted,
		})
		local hot = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, 66),
			Parent = left,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = hot,
		})
		local function showDetails()
			detailsCard(body, inv, hover or picked)
		end
		local function onClick(slotId, slot)
			if picked and picked ~= slotId then
				PanelController.dropOn(picked, slotId)
				return
			elseif slot then
				picked = picked == slotId and nil or slotId
			else
				picked = nil
			end
			refresh()
		end
		local function onEnter(slotId)
			if drag or Theme.inputKind() ~= "keyboard" then
				return
			end
			hover = slotId
			local cell = open.cells[slotId]
			local stroke = cell and cell:FindFirstChildOfClass("UIStroke")
			if stroke and picked ~= slotId then
				stroke.Color = C.white
				stroke.Thickness = 5
			end
			showDetails()
		end
		local function onLeave(slotId)
			if hover ~= slotId then
				return
			end
			hover = nil
			local cell = open.cells[slotId]
			local stroke = cell and cell:FindFirstChildOfClass("UIStroke")
			if stroke and picked ~= slotId then
				stroke.Color = stroke:GetAttribute("Base") or stroke.Color
				stroke.Thickness = 3
			end
			showDetails()
		end
		for i = 1, Constants.HOTBAR do
			local id = "h" .. i
			open.cells[id] = itemCell(hot, id, inv.slots[id], i, onClick, onEnter, onLeave)
		end
		label(left, `BAG · {inv.capacity or 16} slots (more with storage boxes and tiers) · drag to move`, {
			Position = UDim2.fromOffset(0, 92),
			Size = UDim2.new(1, 0, 0, 20),
			Font = Theme.Display,
			TextSize = 14,
			TextColor3 = C.muted,
		})
		local finds = (inv.finds or 0) > 0
		local grid = scroller(left, {
			Position = UDim2.fromOffset(0, 114),
			Size = UDim2.new(1, 0, 1, finds and -138 or -114),
			grid = UDim2.fromOffset(CELL, CELL),
		})
		for i = 1, inv.capacity or 16 do
			local id = "b" .. i
			open.cells[id] = itemCell(grid, id, inv.slots[id], i, onClick, onEnter, onLeave)
		end
		if finds then
			label(
				left,
				`🎒 {inv.finds} finds aboard: half float off if you go down on a trip. Leave the island and finish the trip to keep them.`,
				{
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 20),
					TextSize = 13,
					TextColor3 = C.red,
				}
			)
		end
		showDetails()
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
			local pic = new("Frame", {
				Name = "Picture",
				BackgroundColor3 = item and Theme.darken(rarity(item).color, 0.5) or C.slate,
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(50, 50),
				Parent = row,
			}, { Theme.corner(10) })
			if not (item and Icons.item(pic, item.key, { inset = 3 })) then
				Theme.text({
					Text = icon,
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
					Parent = pic,
				})
			end
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
		local speed = raft.speed or 1
		local drive = speed >= 4 and "💨 Engine ×4" or speed >= 2 and "⛵ Sail ×2" or "🚣 Paddling ×1"
		local nextDrive = speed >= 4 and ""
			or speed >= 2 and " · an Engine makes it ×4 (once your raft is an Expedition Vessel)"
			or " · a Big Sail makes it ×2, an Engine ×4 (when your raft is bigger)"
		if v.state == "docked" then
			status = (
				raft.helm and "Out at sea. Pick a place and tap SAIL." or "Out at sea. Build a Helm to sail somewhere."
			) .. ` {drive}{nextDrive}`
		elseif v.state == "island" then
			if v.stayEnds then
				local left = math.max(0, math.floor((v.stayEnds or 0) - workspace:GetServerTimeNow()))
				status = `At {v.name}. No anchor: the current pulls you away in {left // 60}:{string.format(
					"%02d",
					left % 60
				)}. An Anchor keeps you parked there as long as you like.`
			else
				status = `⚓ Anchored at {v.name}. Tap LEAVE ISLAND when you're done.`
			end
		else
			status = (v.state == "home" and "Leaving the island..." or `Sailing to {v.name}...`) .. ` {drive}`
		end
		label(body, status, { Size = UDim2.new(1, -160, 0, 44), TextSize = 14, TextWrapped = true })
		if v.state == "island" then
			local home = Theme.button({
				Name = "Home",
				Text = "⛵ LEAVE ISLAND",
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
			`{t and t.icon or "⛵"} YOUR RAFT: {string.upper(raft.tierName or "")} (size {raft.tier or 1} of 6)`,
			{ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Font = Theme.Display, TextSize = 18 }
		)
		label(
			head,
			`{t and t.desc or ""} · {raft.tiles or 0} floors · speed {raft.speed or 1}x · {raft.cargo or 16} slots{raft.broken and raft.broken > 0 and ` · 💥 {raft.broken} broken: hammer them` or ""}`,
			{ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 34), TextSize = 13 }
		)
		if raft.needs then
			local n = #raft.needs
			local box = rowFrame(list, 30 + n * 22, 2)
			label(box, `TO GROW INTO A {string.upper(raft.nextTier or "")}, BUILD:`, {
				Position = UDim2.fromOffset(10, 4),
				Size = UDim2.new(1, -20, 0, 22),
				Font = Theme.Display,
				TextSize = 15,
			})
			for i, need in raft.needs do
				label(
					box,
					`{need.done and "✅" or "⬜"} {need.text}{need.need > 1 and ` ({need.have}/{need.need})` or ""}`,
					{
						Name = "Need_" .. i,
						Position = UDim2.fromOffset(16, 26 + (i - 1) * 22),
						Size = UDim2.new(1, -30, 0, 20),
						TextSize = 14,
						TextColor3 = need.done and Color3.fromRGB(30, 130, 60) or C.ink,
					}
				)
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
		local d = Theme.button({
			Name = "Demolish",
			Text = "♻️ REMOVE A PIECE (WHOLE COST BACK)",
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
			`🎣 {st.debris or 0} reeled in · 🔨 {st.built or 0} built · 🛠️ {st.crafted or 0} crafted · ⛵ {st.voyages or 0} voyages · 🎣 {st.fish or 0} fish · 📔 {profile.journalCount or 0} journal entries · ⛈️ {st.storms or 0} storms · 💀 {st.deaths or 0} downs · 🐲 {st.leviathans or 0} leviathans`,
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
		label(
			body,
			friendStatus ~= "" and friendStatus or "Rafts in this server: tap VISIT to look around them.",
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
				`{t and t.icon or "⛵"} {t and t.name or ""} · {r.tiles} floors`,
				{ Position = UDim2.new(0.35, 0, 0, 2), Size = UDim2.new(0.65, -140, 1, -4), TextSize = 13 }
			)
			local b = Theme.button({
				Name = "Visit_" .. r.userId,
				Text = "👀 VISIT",
				BackgroundColor3 = C.sky,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 38),
				TextSize = 13,
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Visit", r.userId)
				Bus.Tap:Fire("visit")
				PanelController.close()
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
	"🎣 Cast at what floats past: aim at it and tap ACT, it reels in. Cast at open water to fish. Nets catch for you.",
	"🔨 BUILD tiles beside your raft, then stations and systems on them.",
	"🛠️ Stand at a station to craft. Costs are shown as have/need.",
	"☸️ Build a Helm, open the MAP and SAIL. Things happen on the way.",
	"🏝️ Islands rise beside your raft: chop, mine, search, look, then LEAVE ISLAND on the MAP.",
	"💀 Go down away from your dock and half your finds float off as a bag. Cast at it to reel it back.",
	"⛵ Your raft grows bigger when you build what it asks for. Tap RAFT to see what.",
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
			Bus.Menu:Fire("invite")
		end)
		local menu = Theme.button({
			Name = "OpenMenu",
			Text = "🏝️ MY WORLD MENU (invite, visit, start over)",
			BackgroundColor3 = C.good,
			LayoutOrder = 21,
			Size = UDim2.new(1, -10, 0, 44),
			TextSize = 15,
			Parent = list,
		})
		menu.Activated:Connect(function()
			PanelController.close()
			Bus.Menu:Fire()
		end)
	end
	open.refresh = refresh
	refresh()
end

-- VISIT: look at anyone's raft (players here, your friends, the biggest rafts) --------------------------------------------------
local visitTab = "here"
local visitRows = {} -- [kind] = rows
local function visitPanel(arg)
	local body = panel("visit", "👀 VISIT A RAFT", 820, 480)
	if type(arg) == "string" then
		visitTab = arg
	end
	local function refresh()
		body:ClearAllChildren()
		tabs(
			body,
			{
				{ key = "here", label = "IN THIS SERVER" },
				{ key = "friends", label = "FRIENDS" },
				{ key = "top", label = "🏆 BIGGEST RAFTS" },
			},
			visitTab,
			function(k)
				visitTab = k
				Net.send("VisitList", k)
				refresh()
			end
		)
		label(body, "Look around anyone's raft. You can't touch or take anything, it's just for looking!", {
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = 14,
			TextColor3 = C.muted,
		})
		local list = scroller(body, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70) })
		local rows = visitRows[visitTab]
		if not rows then
			label(list, "Looking...", { Size = UDim2.new(1, 0, 0, 30), TextSize = 15 })
			return
		end
		if #rows == 0 then
			label(
				list,
				visitTab == "here" and "Nobody else is here right now. Try FRIENDS or BIGGEST RAFTS!"
					or visitTab == "friends" and "No friends found yet. Invite some from ⚙️ MORE!"
					or "The leaderboard is still loading. Try again in a moment.",
				{ Size = UDim2.new(1, 0, 0, 40), TextSize = 15 }
			)
			return
		end
		for i, r in rows do
			local row = rowFrame(list, 52, i)
			row.Name = "VisitRow_" .. tostring(r.userId)
			local t = r.tier and Pieces.TIERS[r.tier]
			label(row, `{r.rank and ("#" .. r.rank .. "  ") or ""}{r.name or "?"}{r.online and "  🟢" or ""}`, {
				Position = UDim2.fromOffset(12, 4),
				Size = UDim2.new(0.45, 0, 1, -8),
				Font = Theme.Display,
				TextSize = 16,
			})
			label(
				row,
				r.tiles and `{t and t.icon or "⛵"} {t and t.name or ""} · {r.tiles} floors`
					or r.value and `🟫 {r.value} floors`
					or "",
				{ Position = UDim2.new(0.45, 0, 0, 4), Size = UDim2.new(0.55, -140, 1, -8), TextSize = 14 }
			)
			local b = Theme.button({
				Name = "Visit_" .. tostring(r.userId),
				Text = "👀 VISIT",
				BackgroundColor3 = C.sky,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 40),
				TextSize = 14,
				Parent = row,
			})
			b.Activated:Connect(function()
				Net.send("Visit", r.userId)
				Bus.Tap:Fire("visit_" .. visitTab)
				PanelController.close()
			end)
		end
	end
	open.refresh = refresh
	Net.send("VisitList", visitTab)
	refresh()
end
PanelController.visitRows = visitRows

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
	Layout.modal(name, card)
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
	visit = visitPanel,
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

-- The bag slot that is picked (tapped) in the BAG panel, or nil.
function PanelController.picked()
	return open and open.name == "inventory" and picked or nil
end

function PanelController:init()
	gui = Theme.screen("Panels", 8, player:WaitForChild("PlayerGui"))
	-- dragging in the bag: the pointer moves, the ghost follows; it lifts, the item drops where it is
	pcall(function()
		UserInputService.InputChanged:Connect(function(input)
			local kind = input.UserInputType
			if drag and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
				dragMove(input)
			end
		end)
	end)
	UserInputService.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if drag and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
			dragEnd(input)
		end
	end)
	Bus.Open:Connect(PanelController.openPanel)
	Bus.Close:Connect(PanelController.close)
	Net.listen("Ask", onAsk)
	Net.listen("VisitList", function(v)
		if type(v) == "table" and type(v.rows) == "table" then
			visitRows[v.kind or "here"] = v.rows
			if open and open.name == "visit" and open.refresh then
				open.refresh()
			end
		end
	end)
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

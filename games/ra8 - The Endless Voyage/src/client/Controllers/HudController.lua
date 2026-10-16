--[[
The HUD (master plan §4: phone first, one clear thing at a time, no text walls):

  top middle    the voyage: DOCKED · plot 3 / SAILING TO PALM KEY 0:21 (a bar fills) / LAND HO / SAILING HOME, the
                event under way, the day's clock, a storm warning
  top left      you: name, title, level; health; buffs; the finds you're carrying while away from your dock
  top right     the menu (MAP, RAFT, BOOK, ME, TOP, FRIENDS, MORE) and the raft's line: tier · tiles · next tier
  bottom        the hotbar: six slots, tap or 1-6 to hold, rarity colours, counts; the BAG button
  middle        alerts (LAND HO!), callouts (sharks!), toasts, unlock cards (level up, blueprints, discoveries)
  overlays      red edges when you're hit; YOU WENT DOWN; the rowboat's fade; the visiting banner with ROW HOME;
                REEL! when a fish bites
The action buttons are InputController's, the panels PanelController's, the guide's arrow TutorialController's.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Progression = require(ReplicatedStorage.Shared.Data.Progression)
local InputController = require(script.Parent.InputController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)
local Icons = require(script.Parent.Parent.UI.Icons)
local Layout = require(script.Parent.Parent.UI.Layout)

local HudController = { Name = "HudController", Order = 10 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}

local function rarityColor(item)
	return Items.rarityColor(item and item.rarity)
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function mmss(s)
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The voyage and the clock -----------------------------------------------------------------------------------------
local function buildClock()
	local slab = Theme.slab({
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(400, 66),
		Parent = gui,
	})
	refs.clock = slab
	refs.voyage = Theme.title({
		Name = "Voyage",
		Text = "🏠 DOCKED",
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = slab,
	})
	refs.sub = Theme.text({
		Name = "Sub",
		Text = "",
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 32),
		TextSize = 15,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = slab,
	})
	refs.voyageBar, refs.voyageFill = Theme.bar({
		Name = "Progress",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -24, 0, 8),
		Visible = false,
		Parent = slab,
	}, C.sky)
end

local function updateClock()
	local v = Store.get("voyage") or { state = "docked" }
	local me = Store.get("me") or {}
	local phase = Store.phase()
	local progress, length = Store.phaseProgress()
	local clock = length > 0 and Formulas.clockTime(phase, progress * length) or 9
	local h = math.floor(clock) % 24
	local m = math.floor((clock - math.floor(clock)) * 60)
	local timeText = `{phase == "night" and "🌙" or "☀️"} {h}:{string.format("%02d", m)}`
	local storm = Store.storm()
	local t = serverNow()
	local text, sub
	if v.state == "sailing" then
		local left = (v.ends or t) - t
		text = `⛵ TO {string.upper(v.name or "")} · {mmss(left)}`
		refs.voyageBar.Visible = true
		local total = (v.ends or t) - (v.started or t)
		refs.voyageFill.Size = UDim2.fromScale(total > 0 and math.clamp(1 - left / total, 0, 1) or 0, 1)
	elseif v.state == "home" then
		local left = (v.ends or t) - t
		text = `⛵ LEAVING THE ISLAND · {mmss(left)}`
		refs.voyageBar.Visible = true
		local total = (v.ends or t) - (v.started or t)
		refs.voyageFill.Size = UDim2.fromScale(total > 0 and math.clamp(1 - left / total, 0, 1) or 0, 1)
	elseif v.state == "island" then
		if v.stayEnds then
			text = `{v.icon or "🏝️"} {string.upper(v.name or "")} · 🌊 {mmss(v.stayEnds - t)}`
		else
			text = `{v.icon or "🏝️"} {string.upper(v.name or "")} · ⚓`
		end
		refs.voyageBar.Visible = false
	else
		text = me.visiting and `⛵ VISITING · PLOT {me.plot or "?"}` or `🌊 AT SEA · SPOT {me.home or "?"}`
		refs.voyageBar.Visible = false
	end
	if v.event and v.event.ends and v.event.ends > t then
		sub = `{v.event.icon or ""} {v.event.name or ""} · {timeText}`
	elseif storm then
		sub = `⛈️ STORM · hammer what breaks · {timeText}`
	elseif v.state == "island" then
		sub = v.stayEnds and `No anchor: the current pulls you away soon · {timeText}`
			or `Anchored · LEAVE ISLAND on the MAP when done · {timeText}`
	else
		sub = timeText
	end
	refs.voyage.Text = text
	refs.sub.Text = sub
	refs.clock.BackgroundColor3 = storm and Color3.fromRGB(90, 40, 60) or C.slate
end

-- You --------------------------------------------------------------------------------------------------------------------
local function buildMe()
	local slab =
		Theme.slab({ Name = "Me", Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(270, 92), Parent = gui })
	refs.meSlab = slab
	refs.meName = Theme.title({
		Name = "Name",
		Text = player.DisplayName,
		Size = UDim2.new(1, -90, 0, 24),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slab,
	})
	refs.level = Theme.title({
		Name = "Level",
		Text = "LV 1",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(80, 24),
		Position = UDim2.new(1, -10, 0, 4),
		TextColor3 = C.mustard,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = slab,
	})
	refs.title = Theme.text({
		Name = "Title",
		Text = "Castaway",
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.fromOffset(10, 28),
		TextSize = 13,
		TextColor3 = C.mustard,
		outline = 1.5,
		Parent = slab,
	})
	local hpBar, hpFill =
		Theme.bar({ Name = "Hp", Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 0, 16) }, C.good)
	hpBar.Parent = slab
	refs.hpFill = hpFill
	refs.hpText = Theme.title({
		Name = "HpText",
		Text = "100",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		outline = 1.5,
		ZIndex = 3,
		Parent = hpBar,
	})
	refs.buffs = Theme.text({
		Name = "Buffs",
		Text = "",
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 68),
		TextSize = 13,
		TextColor3 = C.white,
		outline = 1.5,
		Parent = slab,
	})
	-- visiting: the banner with ROW HOME
	local visit = Theme.slab({
		Name = "Visiting",
		Position = UDim2.fromOffset(10, 106),
		Size = UDim2.fromOffset(270, 40),
		BackgroundColor3 = Color3.fromRGB(40, 90, 130),
		Visible = false,
		Parent = gui,
	})
	refs.visit = visit
	refs.visitText = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -110, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		outline = 2,
		Parent = visit,
	})
end

local function updateMe()
	local me = Store.get("me") or {}
	local profile = Store.get("profile")
	local inv = Store.get("inv") or {}
	local hp, maxHp = me.hp or 100, me.maxHp or 100
	refs.hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	refs.hpFill.BackgroundColor3 = hp / maxHp < 0.3 and C.red or hp / maxHp < 0.6 and C.orange or C.good
	refs.hpText.Text = `{math.floor(hp)} / {maxHp}`
	if profile then
		refs.level.Text = `LV {profile.level or 1}`
		local title = "Castaway"
		for _, t in Progression.TITLES do
			if t.key == profile.title then
				title = t.name
			end
		end
		refs.title.Text = title
	end
	local parts = {}
	for key, left in me.buffs or {} do
		table.insert(parts, `{key == "hearty" and "💪" or key == "swift" and "💨" or "🍀"} {left}s`)
	end
	if (inv.finds or 0) > 0 then
		table.insert(parts, `🎒 {inv.finds} finds aboard`)
	end
	refs.buffs.Text = table.concat(parts, "  ")
	refs.visit.Visible = me.visiting ~= nil
	if me.visiting then
		refs.visitText.Text = `On {me.visitingName or "a friend"}'s raft`
	end
end

-- The menu and the raft's line ---------------------------------------------------------------------------------------
local MENU = {
	{ "map", "🗺️", "MAP", C.sky },
	{ "raft", "⛵", "RAFT", C.mustard },
	{ "book", "📔", "BOOK", C.purple },
	{ "me", "👤", "ME", C.teal },
	{ "boards", "🏆", "TOP", C.orange },
	{ "friends", "👥", "FRIENDS", C.good },
	{ "visit", "👀", "VISIT", C.sky },
	{ "settings", "⚙️", "MORE", C.slate },
}

local function buildRight()
	refs.menu = {}
	for i, m in MENU do
		local row = (i - 1) // 4
		local col = (i - 1) % 4
		local b, dot = Theme.iconButton({
			Name = "Menu_" .. m[1],
			icon = m[2],
			label = m[3],
			color = m[4],
			Size = UDim2.fromOffset(58, 58),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10 - (3 - col) * 64, 0, 8 + row * 66),
			Parent = gui,
		})
		b.Activated:Connect(function()
			Bus.Open:Fire(m[1])
			Bus.Tap:Fire("menu_" .. m[1])
		end)
		refs.menu[m[1]] = { button = b, dot = dot }
	end
	local slab = Theme.slab({
		Name = "RaftLine",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 142),
		Size = UDim2.fromOffset(250, 48),
		Parent = gui,
	})
	refs.raftLine = Theme.title({
		Name = "Tier",
		Text = "",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 3),
		TextXAlignment = Enum.TextXAlignment.Right,
		outline = 2,
		Parent = slab,
	})
	refs.raftNext = Theme.text({
		Name = "Next",
		Text = "",
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 26),
		TextSize = 13,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		outline = 1.5,
		Parent = slab,
	})
	refs.raftSlab = slab
end

local function updateRight()
	local raft = Store.get("raft") or {}
	local t = Pieces.TIERS[raft.tier or 1]
	refs.raftLine.Text =
		`{t and t.icon or "⛵"} {raft.tierName or (t and t.name) or ""} · {raft.size or raft.tiles or 0} pieces`
	local needs = raft.needs
	if needs then
		local done, total = 0, #needs
		for _, n in needs do
			if n.done then
				done += 1
			end
		end
		local grow = Formulas.growText(needs)
		refs.raftNext.Text = raft.broken and raft.broken > 0 and `💥 {raft.broken} broken: fix with the 🔨`
			or grow and `⬆️ To grow: {grow}`
			or `⬆️ Ready to grow ({done}/{total})`
	else
		refs.raftNext.Text = raft.broken and raft.broken > 0 and `💥 {raft.broken} broken` or "The top of the line."
	end
	refs.raftSlab.BackgroundColor3 = raft.broken and raft.broken > 0 and Color3.fromRGB(110, 50, 50) or C.slate
	local profile = Store.get("profile")
	if profile and refs.menu.raft then
		refs.menu.raft.dot.Visible = needs ~= nil
			and (function()
				for _, n in needs do
					if not n.done then
						return false
					end
				end
				return true
			end)()
	end
end

-- The hotbar -------------------------------------------------------------------------------------------------------
local function buildHotbar()
	local bar = new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -40, 1, -10),
		Size = UDim2.fromOffset(Constants.HOTBAR * 66 + 70, 64),
		Parent = gui,
	})
	refs.hotbar = bar
	refs.slots = {}
	for i = 1, Constants.HOTBAR do
		local b = new("TextButton", {
			Name = "Slot" .. i,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.slate,
			BackgroundTransparency = 0.15,
			Size = UDim2.fromOffset(60, 60),
			Position = UDim2.fromOffset((i - 1) * 66, 2),
			Parent = bar,
		}, { Theme.corner(12) })
		local stroke = Theme.stroke(3)
		stroke.Parent = b
		local icon = Theme.text({
			Name = "Icon",
			Text = "",
			Size = UDim2.new(1, -8, 1, -16),
			Position = UDim2.fromOffset(4, 4),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		local count = Theme.title({
			Name = "Count",
			Text = "",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -2),
			Size = UDim2.fromOffset(40, 18),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
			outline = 2,
			Parent = b,
		})
		local key = Theme.title({
			Name = "Key",
			Text = tostring(i),
			Position = UDim2.fromOffset(4, 1),
			Size = UDim2.fromOffset(16, 16),
			TextColor3 = C.muted:Lerp(C.white, 0.4),
			ZIndex = 3,
			outline = 1.5,
			Parent = b,
		})
		b.Activated:Connect(function()
			InputController.select(i)
		end)
		refs.slots[i] = { button = b, stroke = stroke, icon = icon, count = count, key = key }
	end
	local bag = Theme.button({
		Name = "Bag",
		Text = "🎒",
		BackgroundColor3 = C.orange,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(Constants.HOTBAR * 66 + 6, 2),
		Parent = bar,
	})
	Theme.keyHint(bag, "Tab", "Y")
	bag.Activated:Connect(function()
		Bus.Open:Fire("inventory")
		Bus.Tap:Fire("bag")
	end)
end

local function updateHotbar()
	local inv = Store.get("inv") or { slots = {} }
	local keyboard = Theme.inputKind() == "keyboard"
	for i, s in refs.slots do
		local slot = inv.slots["h" .. i]
		local item = slot and Items.get(slot.key)
		-- the item's own model as the picture (the emoji only if it can't be drawn)
		local key = item and item.key or nil
		local pinned = key == "pin" and slot.data and slot.data.piece or nil
		local iconKey = pinned and ("pin:" .. pinned) or key
		if s.iconKey ~= iconKey then
			s.iconKey = iconKey
			Icons.clear(s.button)
			local drawn
			if pinned then
				drawn = Icons.piece(s.button, pinned, { inset = 5 })
				local def = Pieces.get(pinned)
				s.icon.Text = drawn and "📌" or (def and def.icon or "📌")
			else
				drawn = key and Icons.item(s.button, key, { inset = 5 })
				s.icon.Text = (item and not drawn) and item.icon or ""
			end
		end
		s.count.Text = (slot and slot.n > 1) and tostring(slot.n) or ""
		local selected = (inv.selected or 1) == i
		s.stroke.Color = selected and C.mustard or (item and rarityColor(item) or C.ink)
		s.stroke.Thickness = selected and 5 or 3
		s.button.BackgroundColor3 = item and Theme.darken(rarityColor(item), 0.55) or C.slate
		s.button.Size = selected and UDim2.fromOffset(64, 64) or UDim2.fromOffset(60, 60)
		s.button.Position = UDim2.fromOffset((i - 1) * 66 - (selected and 2 or 0), selected and 0 or 2)
		s.key.Visible = keyboard
	end
	refs.hotbar.Visible = Store.alive()
end

-- What you have, at a glance -------------------------------------------------------------------------------------------
-- The bottom left: a chip for each main resource (what drifts by: wood, scrap, rope, cloth, metal) with how many are
-- in the bag, always there, and a row above for the island ones you're carrying (palms, stone, ore...), the most
-- first. Not a button: touches pass through to the thumbstick under it.
local MAIN = { "wood", "scrap", "rope", "cloth", "metal" }
local MORE = 5 -- island resources shown at most
local CHIP_W = 64

local function chip(parent, key, i)
	local it = Items.get(key)
	local c = new("Frame", {
		Name = "Res_" .. key,
		BackgroundColor3 = C.slate,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset((i - 1) * (CHIP_W + 4), 0),
		Size = UDim2.fromOffset(CHIP_W, 30),
		Parent = parent,
	}, { Theme.corner(10), Theme.stroke(2, C.ink) })
	-- the item's own picture (the same one as in the bag), the emoji only if it can't be drawn
	local pic = new("Frame", {
		Name = "Pic",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.fromOffset(26, 26),
		Parent = c,
	})
	if not (it and Icons.item(pic, key, { inset = 0 })) then
		Theme.text({
			Name = "Icon",
			Text = it and it.icon or "",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = pic,
		})
	end
	local n = Theme.title({
		Name = "Count",
		Text = "0",
		Position = UDim2.fromOffset(28, 4),
		Size = UDim2.new(1, -32, 0, 22),
		TextSize = 17,
		outline = 2,
		Parent = c,
	})
	return c, n
end

local function buildResources()
	local box = new("Frame", {
		Name = "Resources",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(#MAIN * (CHIP_W + 4) - 4, 30),
		Parent = gui,
	})
	refs.resources = box
	refs.resChips = {}
	for i, key in MAIN do
		local c, n = chip(box, key, i)
		refs.resChips[key] = { frame = c, count = n }
	end
	-- the island row sits just above (its own frame, so the strip stays one row when it's empty)
	refs.resMore = new("Frame", {
		Name = "ResourcesMore",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 1, -44),
		Size = UDim2.fromOffset(MORE * (CHIP_W + 4) - 4, 30),
		Visible = false,
		Parent = gui,
	})
end

local function updateResources()
	local inv = Store.get("inv") or { slots = {} }
	local have = {}
	for _, s in inv.slots or {} do
		if type(s) == "table" and s.key then
			have[s.key] = (have[s.key] or 0) + (s.n or 0)
		end
	end
	for key, r in refs.resChips do
		local n = have[key] or 0
		r.count.Text = n >= 1000 and `{math.floor(n / 100) / 10}k` or tostring(n)
		r.frame.BackgroundTransparency = n > 0 and 0.2 or 0.5
	end
	-- the island resources you hold, the most first
	local main = {}
	for _, key in MAIN do
		main[key] = true
	end
	local more = {}
	for key, n in have do
		local it = Items.get(key)
		if n > 0 and not main[key] and it and it.kind == "resource" then
			table.insert(more, { key = key, n = n })
		end
	end
	table.sort(more, function(a, b)
		return a.n > b.n or (a.n == b.n and a.key < b.key)
	end)
	local shown = {}
	for i = 1, math.min(MORE, #more) do
		shown[i] = more[i].key
	end
	local sig = table.concat(shown, ",")
	if refs.resMoreSig ~= sig then
		refs.resMoreSig = sig
		refs.resMore:ClearAllChildren()
		refs.resMoreChips = {}
		for i, key in shown do
			local _, n = chip(refs.resMore, key, i)
			refs.resMoreChips[key] = n
		end
		refs.resMore.Size = UDim2.fromOffset(math.max(1, #shown) * (CHIP_W + 4) - 4, 30)
	end
	for key, n in refs.resMoreChips or {} do
		n.Text = tostring(have[key] or 0)
	end
	local alive = Store.alive()
	refs.resources.Visible = alive
	refs.resMore.Visible = alive and #shown > 0
end
HudController.updateResources = updateResources

-- Messages ----------------------------------------------------------------------------------------------------------------
-- A free row in a stack of short-lived messages: the lowest one nobody's in, after dropping the oldest while all
-- `rows` are taken (so a message never lands on another).
local function freeRow(stack, rows)
	for i = #stack, 1, -1 do
		if not stack[i].Parent then
			table.remove(stack, i)
		end
	end
	while #stack >= rows do
		local old = table.remove(stack, 1)
		old:Destroy()
	end
	local used = {}
	for _, m in stack do
		used[m:GetAttribute("Row")] = true
	end
	local row = 0
	while used[row] do
		row += 1
	end
	return row
end

local toasts = {}
function HudController.toast(text, kind)
	if type(text) ~= "string" then
		return
	end
	local color = kind == "bad" and C.red or kind == "good" and C.good or C.slate
	-- two rows above the hotbar, left of the action buttons; one while a card asks something (its bottom edge
	-- stays clear)
	local row = freeRow(toasts, Layout.modalOpen() and 1 or 2)
	local label = Theme.slab({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -40, 1, -88 - row * 44),
		Size = UDim2.fromOffset(520, 38),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		round = true,
		Parent = gui,
	})
	label:SetAttribute("Row", row)
	table.insert(toasts, label)
	Theme.title({
		Text = text,
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = label,
	})
	Theme.pop(label)
	task.delay(3.4, function()
		label:Destroy()
	end)
end

function HudController.alert(text, color, seconds)
	if type(text) ~= "string" then
		return
	end
	if Layout.modalOpen() then
		-- a card is asking something in the middle of the screen: say it on the bottom row instead
		HudController.toast(text, "info")
		return
	end
	if refs.alert then
		refs.alert:Destroy()
	end
	-- (under the guide's card, clear of the unlock cards down the right)
	local label = Theme.title({
		Name = "Alert",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 240),
		Size = UDim2.fromOffset(600, 66),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = typeof(color) == "Color3" and color or C.mustard,
		outline = 4,
		ZIndex = 20,
		Parent = gui,
	})
	refs.alert = label
	Theme.pop(label)
	task.delay(type(seconds) == "number" and seconds or 2.6, function()
		if refs.alert == label then
			label:Destroy()
			refs.alert = nil
		end
	end)
end

local CALLOUT_COLOR = { bad = C.red, good = C.good, info = C.slate }
function HudController.callout(text, kind)
	if type(text) ~= "string" then
		return
	end
	if Layout.modalOpen() then
		HudController.toast(text, kind)
		return
	end
	if refs.callout then
		refs.callout:Destroy()
	end
	local slab = Theme.slab({
		Name = "Callout",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(600, 42),
		BackgroundColor3 = CALLOUT_COLOR[kind] or C.slate,
		BackgroundTransparency = 0.05,
		round = true,
		Parent = gui,
	})
	Theme.title({
		Text = text,
		Size = UDim2.new(1, -24, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = slab,
	})
	refs.callout = slab
	Theme.pop(slab)
	task.delay(4.5, function()
		if refs.callout == slab then
			slab:Destroy()
			refs.callout = nil
		end
	end)
end

-- Unlock cards: level ups, blueprints, charts, discoveries, tiers, achievements, dyes (three at a time, down the
-- right under the raft's card).
local unlocks = {}
function HudController.unlock(u)
	if type(u) ~= "table" then
		return
	end
	local text, color
	if u.kind == "level" then
		text = `⬆️ LEVEL {u.level}`
			.. (#(u.unlocked or {}) > 0 and (" · " .. table.concat(u.unlocked, ", ")) or "")
		color = C.mustard
	elseif u.kind == "achievement" then
		text = `{u.icon or "🏆"} {u.name}`
		color = C.purple
	elseif u.kind == "blueprint" then
		text = `📜 Blueprint: {u.name}`
		color = C.good
	elseif u.kind == "chart" then
		text = `🗺️ Chart: {u.name}`
		color = C.sky
	elseif u.kind == "discovery" then
		text = `{u.icon or "📔"} Journal: {u.name}`
		color = C.sky
	elseif u.kind == "tier" then
		text = `{u.icon or "⛵"} {u.name}!`
		color = C.orange
	elseif u.kind == "colour" then
		text = `{u.icon or "🎨"} {u.name}`
		color = C.pink
	else
		text = u.name or u.text or ""
		color = C.good
	end
	if text == "" then
		return
	end
	-- (as many rows as fit above JUMP and RUN, whose tops sit 254 above the bottom: two on a phone held sideways)
	local rows = math.clamp(math.floor((Theme.canvas().Y - 254 - 200 - 54) / 60) + 1, 1, 3)
	local row = freeRow(unlocks, rows)
	local card = Theme.slab({
		Name = "Unlock",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 200 + row * 60),
		Size = UDim2.fromOffset(300, 54),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	Theme.title({
		Text = text,
		Size = UDim2.new(1, -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		outline = 2,
		Parent = card,
	})
	card:SetAttribute("Row", row)
	table.insert(unlocks, card)
	Theme.pop(card)
	task.delay(4.5, function()
		card:Destroy()
	end)
end

-- Overlays -----------------------------------------------------------------------------------------------------------------
local function buildOverlays()
	refs.vignette = new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.red,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 30,
		Parent = gui,
	})
	refs.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 31,
		Parent = gui,
	})
	refs.fade = new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 32,
		Parent = gui,
	})
	refs.fadeText = Theme.title({
		Name = "Text",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		ZIndex = 33,
		Parent = refs.fade,
	})
	for _, d in refs.fadeText:GetChildren() do
		if d:IsA("UIStroke") then
			d.Transparency = 1 -- (hidden with the letters until a fade shows them)
		end
	end
	local down = Theme.slab({
		Name = "Down",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 90),
		BackgroundColor3 = Color3.fromRGB(90, 30, 40),
		Visible = false,
		ZIndex = 25,
		Parent = gui,
	})
	refs.down = down
	Theme.title({
		Text = "YOU WENT DOWN",
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.red,
		Parent = down,
	})
	refs.downHint = Theme.text({
		Name = "Hint",
		Text = "",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 50),
		TextSize = 16,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = down,
	})
end

local function hurt(info)
	refs.vignette.BackgroundTransparency = 0.55
	Theme.tween(refs.vignette, 0.6, { BackgroundTransparency = 1 })
	_ = info
end

local function flash(color, seconds)
	refs.flash.BackgroundColor3 = typeof(color) == "Color3" and color or C.white
	refs.flash.BackgroundTransparency = 0.3
	Theme.tween(refs.flash, seconds or 0.6, { BackgroundTransparency = 1 })
end

-- A fade to black and back ("Resting..."): the words fade with their outline, and once it's over they're cleared
-- and the overlay hidden, so nothing is left on screen (the newest fade wins if two overlap).
local fadeToken = 0
local function fade(seconds, text, snap)
	seconds = type(seconds) == "number" and seconds or 1
	fadeToken += 1
	local token = fadeToken
	refs.fadeText.Text = type(text) == "string" and text or ""
	refs.fade.Visible = true
	if snap then
		-- a cut: black at once (arriving at an island: it's there when the screen opens again)
		refs.fade.BackgroundTransparency = 0
		Theme.fadeText(refs.fadeText, 0.2, 0)
	else
		Theme.tween(refs.fade, seconds * 0.4, { BackgroundTransparency = 0 })
		Theme.fadeText(refs.fadeText, seconds * 0.4, 0)
	end
	task.delay(seconds * 0.6, function()
		if token ~= fadeToken then
			return
		end
		Theme.tween(refs.fade, seconds * 0.4, { BackgroundTransparency = 1 })
		Theme.fadeText(refs.fadeText, seconds * 0.4, 1)
		task.delay(seconds * 0.4 + 0.05, function()
			if token == fadeToken then
				refs.fade.BackgroundTransparency = 1
				refs.fadeText.TextTransparency = 1
				refs.fadeText.Text = ""
				refs.fade.Visible = false
			end
		end)
	end)
end
HudController.fade = fade

local function updateOverlays()
	local me = Store.get("me") or {}
	refs.down.Visible = me.dead == true
	if me.dead then
		refs.downHint.Text = `Back on your raft in {me.respawnIn or 0}...`
	end
end

local function onFish(f)
	if type(f) ~= "table" then
		return
	end
	if f.state == "bite" then
		HudController.alert("🐟 REEL! (ACT)", C.good, f.window or 1.1)
	elseif f.state == "away" then
		HudController.toast("🎣 It got away. Cast again!", "info")
	elseif f.state == "caught" and f.name then
		HudController.alert(`{f.icon or "🐟"} {string.upper(f.name)}!`, Items.rarityColor(f.rarity), 2)
	end
end

-- Into the water: a word about swimming back (once a dip).
local lastWhere
local function onWhere(me)
	local where = me and me.where
	if where == "water" and lastWhere ~= "water" then
		HudController.callout("🏊 You're in the water. Swim back and jump up onto the raft!", "info")
	end
	lastWhere = where
end

function HudController:init()
	gui = Theme.screen("Hud", 2, player:WaitForChild("PlayerGui"))
	buildOverlays()
	buildClock()
	buildMe()
	buildRight()
	buildHotbar()
	buildResources()
	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", HudController.alert)
	Net.listen("Callout", HudController.callout)
	Net.listen("Unlock", HudController.unlock)
	Net.listen("Hurt", hurt)
	Net.listen("Fade", fade)
	Net.listen("Fish", onFish)
	Bus.Flash:Connect(flash)
	Store.Changed:Connect(function(partial)
		if partial.me then
			onWhere(partial.me)
		end
		if partial.inv then
			updateHotbar()
			updateResources()
			updateMe()
		elseif partial.me or partial.profile then
			updateMe()
			updateOverlays()
		elseif partial.raft then
			updateRight()
		elseif partial.voyage or partial.weather then
			updateClock()
		end
	end)
	local acc = 1
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			updateClock()
			updateMe()
			updateRight()
			updateHotbar()
			updateResources()
			updateOverlays()
		end
	end)
end

-- (tests)
HudController.refs = refs

return HudController

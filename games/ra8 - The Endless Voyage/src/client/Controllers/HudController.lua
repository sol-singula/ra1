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

local HudController = { Name = "HudController", Order = 10 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}
local toastY = 0

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
		text = `🏠 SAILING HOME · {mmss(left)}`
		refs.voyageBar.Visible = true
		local total = (v.ends or t) - (v.started or t)
		refs.voyageFill.Size = UDim2.fromScale(total > 0 and math.clamp(1 - left / total, 0, 1) or 0, 1)
	elseif v.state == "island" then
		text = `{v.icon or "🏝️"} {string.upper(v.name or "")}`
		refs.voyageBar.Visible = false
	else
		text = me.visiting and `⛵ VISITING · PLOT {me.plot or "?"}` or `🏠 DOCKED · PLOT {me.home or "?"}`
		refs.voyageBar.Visible = false
	end
	if v.event and v.event.ends and v.event.ends > t then
		sub = `{v.event.icon or ""} {v.event.name or ""} · {timeText}`
	elseif storm then
		sub = `⛈️ STORM · hammer what breaks · {timeText}`
	elseif v.state == "island" then
		sub = `Sail home from the helm · {timeText}`
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
	local home = Theme.button({
		Name = "RowHome",
		Text = "ROW HOME",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(96, 30),
		TextSize = 14,
		Parent = visit,
	})
	home.Activated:Connect(function()
		Net.send("Visit", false)
		Bus.Tap:Fire("row_home")
	end)
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
		`{t and t.icon or "⛵"} {raft.tierName or (t and t.name) or ""} · {raft.tiles or 0}/{raft.max or 12} tiles`
	local needs = raft.needs
	if needs then
		local done, total = 0, #needs
		for _, n in needs do
			if n.done then
				done += 1
			end
		end
		refs.raftNext.Text =
			`Next: {raft.nextTier or ""} {done}/{total}{raft.broken and raft.broken > 0 and ` · 💥 {raft.broken} broken` or ""}`
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
		if s.iconKey ~= key then
			s.iconKey = key
			Icons.clear(s.button)
			local drawn = key and Icons.item(s.button, key, { inset = 5 })
			s.icon.Text = (item and not drawn) and item.icon or ""
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

-- Messages ----------------------------------------------------------------------------------------------------------------
function HudController.toast(text, kind)
	if type(text) ~= "string" then
		return
	end
	local color = kind == "bad" and C.red or kind == "good" and C.good or C.slate
	local label = Theme.slab({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -88 - toastY),
		Size = UDim2.fromOffset(520, 38),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		round = true,
		Parent = gui,
	})
	Theme.title({
		Text = text,
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = label,
	})
	toastY = (toastY + 44) % 132
	Theme.pop(label)
	task.delay(3.4, function()
		label:Destroy()
	end)
end

function HudController.alert(text, color, seconds)
	if type(text) ~= "string" then
		return
	end
	if refs.alert then
		refs.alert:Destroy()
	end
	local label = Theme.title({
		Name = "Alert",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 0),
		Size = UDim2.fromOffset(800, 70),
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

-- Unlock cards: level ups, blueprints, charts, discoveries, tiers, achievements, dyes.
local cardY = 0
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
	local card = Theme.slab({
		Name = "Unlock",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 200 + cardY),
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
	cardY = (cardY + 60) % 180
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

local function fade(seconds, text)
	seconds = type(seconds) == "number" and seconds or 1
	refs.fadeText.Text = type(text) == "string" and text or ""
	Theme.tween(refs.fade, seconds * 0.4, { BackgroundTransparency = 0 })
	Theme.tween(refs.fadeText, seconds * 0.4, { TextTransparency = 0 })
	task.delay(seconds * 0.6, function()
		Theme.tween(refs.fade, seconds * 0.4, { BackgroundTransparency = 1 })
		Theme.tween(refs.fadeText, seconds * 0.4, { TextTransparency = 1 })
	end)
end

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

function HudController:init()
	gui = Theme.screen("Hud", 2, player:WaitForChild("PlayerGui"))
	buildOverlays()
	buildClock()
	buildMe()
	buildRight()
	buildHotbar()
	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", HudController.alert)
	Net.listen("Callout", HudController.callout)
	Net.listen("Unlock", HudController.unlock)
	Net.listen("Hurt", hurt)
	Net.listen("Fade", fade)
	Net.listen("Fish", onFish)
	Bus.Flash:Connect(flash)
	Store.Changed:Connect(function(partial)
		if partial.inv then
			updateHotbar()
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
			updateOverlays()
		end
	end)
end

-- (tests)
HudController.refs = refs

return HudController

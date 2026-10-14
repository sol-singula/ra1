--[[
The HUD (master plan §11: phone first, readable at a glance, no text walls; §12: one primary objective at a time,
the compass shows where things are):

  top middle    the clock: DAY 2 · 1:23 / NIGHT 3 · 0:45, the run's progress through 7 days, the night's event and the
                difficulty; the compass under it (the camp, findings you know, downed teammates, pings, Mega Kermy)
  top left      you: health, stamina, buffs, armor; your teammates under you (health, down, ghost)
  top right     the menu buttons, the objective (and up to two optional ones), the camp's tier and the fire
  bottom        the hotbar: six slots, tap or 1-6 to hold, rarity colours, counts, a torch's fuel; the BAG button
  middle        alerts (NIGHT 3), callouts (Kermy is hunting!), toasts, unlock cards (level up, achievements, finds)
  overlays      red edges when you're hit or low; DOWN (bleeding out, crawl to the fire); GHOST (out until dawn,
                watching a teammate); WAITING (a run is underway: find a new one, friends, watch)
  Mega Kermy    his health bar, his phase, WEAK! while he's stuck
The action buttons are InputController's, the panels PanelController's, the guide's arrow TutorialController's.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local InputController = require(script.Parent.InputController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = { Name = "HudController", Order = 10 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}
local pings = {} -- { key, icon, pos, untilT }
local spectating -- the userId the camera follows while you're out

local PHASES = {
	idle = { icon = "⏳", label = "STARTING", color = C.teal },
	day = { icon = "☀️", label = "DAY", color = C.mustard },
	dusk = { icon = "🌆", label = "DUSK", color = C.orange },
	night = { icon = "🌙", label = "NIGHT", color = Color3.fromRGB(150, 180, 255) },
	dawn = { icon = "🌅", label = "DAWN", color = Color3.fromRGB(255, 190, 140) },
	boss = { icon = "👹", label = "NIGHT 7", color = Color3.fromRGB(150, 255, 110) },
	results = { icon = "🏁", label = "RUN OVER", color = C.purple },
}
local STATUS_ICON = { alive = "", downed = "🆘", ghost = "👻", waiting = "⏳" }

local function rarityColor(item)
	return item and Items.RARITY[item.rarity] and Items.RARITY[item.rarity].color or C.muted
end

-- Top middle: the clock and the compass ----------------------------------------------------------------------------------
local function buildClock()
	local slab = Theme.slab({
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(360, 80),
		Parent = gui,
	})
	refs.phase = Theme.title({
		Name = "Phase",
		Text = "",
		Size = UDim2.new(1, -20, 0, 34),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = slab,
	})
	refs.sub = Theme.text({
		Name = "Sub",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 38),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = slab,
	})
	-- the run: seven days and six nights in a row of pips
	local row = new("Frame", {
		Name = "Run",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -40, 0, 12),
		Position = UDim2.fromOffset(20, 60),
		Parent = slab,
	})
	refs.pips = {}
	for k = 1, 13 do
		local day = k % 2 == 1
		local pip = new("Frame", {
			Name = "Pip" .. k,
			BackgroundColor3 = day and C.mustard or Color3.fromRGB(70, 90, 160),
			BackgroundTransparency = 0.6,
			Size = UDim2.new(1 / 13, -3, 1, 0),
			Position = UDim2.new((k - 1) / 13, 0, 0, 0),
			Parent = row,
		}, { Theme.corner("round") })
		if k == 13 then
			pip.BackgroundColor3 = Color3.fromRGB(150, 255, 110)
		end
		refs.pips[k] = pip
	end
	refs.chip = Theme.text({
		Name = "Chip",
		Text = "",
		TextColor3 = C.white,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(1, 8, 0, 6),
		Size = UDim2.fromOffset(150, 22),
		Font = Theme.Display,
		outline = 2,
		Parent = slab,
	})
	-- the compass
	local compass = Theme.slab({
		Name = "Compass",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(460, 30),
		BackgroundTransparency = 0.35,
		round = true,
		Parent = gui,
	})
	compass.ClipsDescendants = true
	refs.compass = compass
	refs.compassMarks = {}
	new("Frame", {
		Name = "Center",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 2, 0, 8),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = compass,
	})
end

local function runPip()
	local phase = Store.phase()
	local day = workspace:GetAttribute("Day") or 0
	if phase == "day" or phase == "dusk" then
		return day * 2 - 1
	elseif phase == "night" or phase == "dawn" or phase == "boss" then
		return math.min(13, (workspace:GetAttribute("Night") or 0) * 2)
	elseif phase == "results" then
		return 14
	end
	return 0
end

local function updateClock()
	local phase = Store.phase()
	local spec = PHASES[phase] or PHASES.idle
	local left = Store.timeLeft()
	local t = left and Formulas.clock(left) or ""
	local day = workspace:GetAttribute("Day") or 0
	local night = workspace:GetAttribute("Night") or 0
	local label = spec.label
	if phase == "day" then
		label = "DAY " .. day
	elseif phase == "night" then
		label = "NIGHT " .. night
	end
	local waiting = not Store.inRun() and phase ~= "results"
	if waiting and phase ~= "idle" then
		refs.phase.Text = "⏳ NEXT RUN SOON"
		refs.phase.TextColor3 = C.teal
	else
		refs.phase.Text = spec.icon .. " " .. label .. (left and phase ~= "dawn" and ("  ·  " .. t) or "")
		refs.phase.TextColor3 = spec.color
	end
	local event = workspace:GetAttribute("Event")
	local sub
	if waiting and phase ~= "idle" then
		sub = phase == "boss" and "This run is fighting Mega Kermy"
			or (night > 0 and `This run is on night {night}` or `This run is on day {day}`)
	elseif phase == "day" then
		sub = day >= 7 and "The 7th night is coming... get ready" or `Night {day} of 6 is coming`
	elseif phase == "dusk" then
		sub = "Get back to camp!"
	elseif phase == "night" then
		sub = (event and event ~= "" and Constants.EVENTS[event]) and Constants.EVENTS[event].name
			or "Survive until dawn"
	elseif phase == "dawn" then
		sub = `You survived night {night}!`
	elseif phase == "boss" then
		sub = "Beat Mega Kermy before dawn!"
	elseif phase == "results" then
		sub = left and `A new run in {t}` or ""
	else
		sub = "Getting the camp ready..."
	end
	refs.sub.Text = sub
	local cur = runPip()
	for k, pip in refs.pips do
		pip.BackgroundTransparency = k < cur and 0.1 or (k == cur and 0 or 0.65)
		pip.Size = k == cur and UDim2.new(1 / 13, -1, 1, 4) or UDim2.new(1 / 13, -3, 1, 0)
	end
	local d = workspace:GetAttribute("Difficulty") or 1
	local dname = Constants.DIFFICULTIES[d] and Constants.DIFFICULTIES[d].name or "Normal"
	refs.chip.Text = d > 1 and ("💀 " .. dname) or ""
end

-- The compass: markers along a strip, from where the camera looks.
local function compassMarkers()
	local list = {}
	local obj = Store.get("objective")
	for _, m in obj and obj.markers or {} do
		table.insert(list, m)
	end
	local now = os.clock()
	for i = #pings, 1, -1 do
		local p = pings[i]
		if now > p.untilT then
			table.remove(pings, i)
		else
			table.insert(
				list,
				{ key = "ping" .. i, icon = p.icon, pos = p.pos, urgent = p.key == "help" or p.key == "kermy" }
			)
		end
	end
	return list
end

local function updateCompass()
	local cam = workspace.CurrentCamera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position or (cam and cam.CFrame.Position) or Vector3.zero
	local look = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	local heading = math.atan2(look.X, -look.Z)
	local used = {}
	local function mark(key, text, angle, color, size)
		local rel = (angle - heading + math.pi) % (math.pi * 2) - math.pi
		local x = 0.5 + rel / math.pi
		if x < -0.05 or x > 1.05 then
			return
		end
		local label = refs.compassMarks[key]
		if not label then
			label = Theme.title({
				Name = "Mark_" .. key,
				Text = "",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(70, 26),
				TextXAlignment = Enum.TextXAlignment.Center,
				outline = 2,
				Parent = refs.compass,
			})
			refs.compassMarks[key] = label
		end
		label.Text = text
		label.TextColor3 = color or C.white
		label.Size = UDim2.fromOffset(70, size or 22)
		label.Position = UDim2.fromScale(math.clamp(x, 0.03, 0.97), 0.5)
		label.Visible = true
		used[key] = true
	end
	for i, dirName in { "N", "E", "S", "W" } do
		mark("dir" .. i, dirName, (i - 1) * math.pi / 2, C.muted:Lerp(C.white, 0.5), 18)
	end
	for _, m in compassMarkers() do
		if typeof(m.pos) == "Vector3" then
			local d = m.pos - origin
			local flat = Vector3.new(d.X, 0, d.Z)
			if flat.Magnitude > 4 then
				local angle = math.atan2(flat.X, -flat.Z)
				local meters = math.floor(flat.Magnitude * 0.28)
				mark(
					m.key,
					(m.icon or "•") .. (meters >= 5 and (" " .. meters .. "m") or ""),
					angle,
					m.urgent and C.red or (m.found == false and C.muted or C.white),
					m.urgent and 24 or 20
				)
			end
		end
	end
	for key, label in refs.compassMarks do
		if not used[key] then
			label.Visible = false
		end
	end
end

-- Top left: you and your team ---------------------------------------------------------------------------------------------------------
local function buildMe()
	local slab = Theme.slab({
		Name = "Me",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(250, 96),
		Parent = gui,
	})
	refs.meName = Theme.title({
		Name = "Who",
		Text = player.DisplayName,
		Size = UDim2.new(1, -70, 0, 22),
		Position = UDim2.fromOffset(10, 4),
		outline = 2,
		Parent = slab,
	})
	refs.level = Theme.title({
		Name = "Level",
		Text = "LV 1",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(64, 22),
		Position = UDim2.new(1, -8, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.mustard,
		outline = 2,
		Parent = slab,
	})
	local hpBar, hpFill = Theme.bar(
		{ Name = "Health", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 30), Parent = slab },
		C.good
	)
	refs.hpFill = hpFill
	refs.hpText = Theme.title({
		Name = "HpText",
		Text = "100",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 2,
		ZIndex = 3,
		Parent = hpBar,
	})
	local stBar, stFill = Theme.bar(
		{ Name = "StaminaBar", Size = UDim2.new(1, -20, 0, 10), Position = UDim2.fromOffset(10, 56), Parent = slab },
		C.mustard
	)
	refs.stFill = stFill
	_ = stBar
	refs.buffs = Theme.text({
		Name = "Buffs",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 72),
		outline = 1.5,
		Parent = slab,
	})
	refs.team = new("Frame", {
		Name = "Team",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 110),
		Size = UDim2.fromOffset(230, 200),
		Parent = gui,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = refs.team })
	refs.teamRows = {}
end

local function updateMe()
	local me = Store.get("me") or {}
	local hp, maxHp = me.hp or 0, math.max(1, me.maxHp or 100)
	refs.hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	refs.hpFill.BackgroundColor3 = hp / maxHp > 0.5 and C.good or (hp / maxHp > 0.25 and C.orange or C.red)
	refs.hpText.Text = me.status == "downed" and "DOWN" or (me.status == "ghost" and "GHOST" or tostring(hp))
	refs.stFill.Size = UDim2.fromScale(math.clamp((me.stamina or 0) / math.max(1, me.staminaMax or 100), 0, 1), 1)
	local parts = {}
	for k, secs in me.buffs or {} do
		table.insert(
			parts,
			(k == "speed" and "⚡" or k == "shield" and "🛡️" or k == "regen" and "💚" or "✨") .. secs .. "s"
		)
	end
	if (me.armor or 0) > 0 then
		table.insert(parts, "🦺" .. math.floor(me.armor * 100) .. "%")
	end
	if workspace:GetAttribute("Blessing") then
		table.insert(parts, "🗿")
	end
	refs.buffs.Text = table.concat(parts, "  ")
	local profile = Store.get("profile")
	refs.level.Text = "LV " .. tostring(profile and profile.level or 1)
	-- the team
	local seen = {}
	for i, t in Store.get("team") or {} do
		if t.userId ~= player.UserId then
			seen[t.userId] = true
			local row = refs.teamRows[t.userId]
			if not row then
				local slab = Theme.slab({
					Name = "Mate" .. t.userId,
					Size = UDim2.fromOffset(220, 30),
					BackgroundTransparency = 0.3,
					Parent = refs.team,
				})
				local name = Theme.title({
					Name = "Who",
					Text = t.name,
					Size = UDim2.new(0.5, -6, 1, -6),
					Position = UDim2.fromOffset(8, 3),
					outline = 1.5,
					Parent = slab,
				})
				local bar, fill = Theme.bar(
					{ Size = UDim2.new(0.42, 0, 0, 10), Position = UDim2.new(0.5, 0, 0.5, -5), Parent = slab },
					C.good
				)
				local status = Theme.title({
					Name = "Status",
					Text = "",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -4, 0.5, 0),
					Size = UDim2.fromOffset(28, 24),
					TextXAlignment = Enum.TextXAlignment.Right,
					outline = 1.5,
					Parent = slab,
				})
				row = { slab = slab, name = name, bar = bar, fill = fill, status = status }
				refs.teamRows[t.userId] = row
			end
			row.slab.LayoutOrder = i
			row.fill.Size = UDim2.fromScale(math.clamp((t.hp or 0) / math.max(1, t.maxHp or 100), 0, 1), 1)
			row.fill.BackgroundColor3 = t.status == "downed" and C.red or C.good
			local icon = STATUS_ICON[t.status] or ""
			if t.status == "downed" and t.bleedUntil then
				icon = "🆘" .. math.max(0, math.ceil(t.bleedUntil - workspace:GetServerTimeNow()))
			end
			row.status.Text = icon
			row.name.TextColor3 = t.status == "alive" and C.white or C.muted
		end
	end
	for userId, row in refs.teamRows do
		if not seen[userId] then
			row.slab:Destroy()
			refs.teamRows[userId] = nil
		end
	end
end

-- Top right: the menu, the objective, the camp -----------------------------------------------------------------------------------------------
local MENU = {
	{ key = "inventory", icon = "🎒", label = "BAG", color = C.orange },
	{ key = "progress", icon = "⭐", label = "ME", color = C.mustard },
	{ key = "bestiary", icon = "📖", label = "BOOK", color = C.purple },
	{ key = "boards", icon = "🏆", label = "TOP", color = C.sky },
	{ key = "friends", icon = "👥", label = "FRIENDS", color = C.good },
	{ key = "settings", icon = "⚙️", label = "MORE", color = C.muted },
}

local function buildRight()
	local row = new("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(6 * 56, 56),
		Parent = gui,
	})
	refs.menu = {}
	for i, m in MENU do
		local b, dot = Theme.iconButton({
			Name = "Menu_" .. m.key,
			icon = m.icon,
			label = m.label,
			color = m.color,
			Size = UDim2.fromOffset(50, 50),
			Position = UDim2.fromOffset((i - 1) * 56, 0),
			Parent = row,
		})
		b.Activated:Connect(function()
			Bus.Tap:Fire("menu_" .. m.key)
			Bus.Open:Fire(m.key)
		end)
		refs.menu[m.key] = { button = b, dot = dot }
	end
	local slab = Theme.slab({
		Name = "Objective",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 70),
		Size = UDim2.fromOffset(300, 118),
		Parent = gui,
	})
	refs.objective = slab
	refs.primary = Theme.title({
		Name = "Primary",
		Text = "",
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 4),
		TextColor3 = C.mustard,
		outline = 2,
		Parent = slab,
	})
	refs.optional = Theme.text({
		Name = "Optional",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.fromOffset(8, 50),
		outline = 1.5,
		Parent = slab,
	})
	refs.campLine = Theme.text({
		Name = "Camp",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(0.55, -8, 0, 18),
		Position = UDim2.fromOffset(8, 92),
		Font = Theme.Display,
		outline = 1.5,
		Parent = slab,
	})
	local fuelBar, fuelFill = Theme.bar(
		{ Name = "Fuel", Size = UDim2.new(0.45, -14, 0, 14), Position = UDim2.new(0.55, 4, 0, 94), Parent = slab },
		C.fire
	)
	refs.fuelFill = fuelFill
	refs.fuelText = Theme.title({
		Name = "FuelText",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		ZIndex = 3,
		Parent = fuelBar,
	})
end

local function updateRight()
	local obj = Store.get("objective")
	if obj and obj.primary then
		refs.primary.Text = (obj.primary.guide and "👉 " or "🎯 ") .. (obj.primary.text or "")
		local lines = {}
		for _, o in obj.optional or {} do
			table.insert(lines, "• " .. o.text)
		end
		refs.optional.Text = table.concat(lines, "\n")
	end
	local camp = Store.get("camp") or {}
	refs.campLine.Text = "🏕️ " .. (camp.tierName or "The Campsite")
	local fuel, fuelMax = camp.fuel or 0, math.max(1, camp.fuelMax or 100)
	refs.fuelFill.Size = UDim2.fromScale(math.clamp(fuel / fuelMax, 0, 1), 1)
	refs.fuelFill.BackgroundColor3 = camp.lit == false and C.muted or (fuel / fuelMax < 0.25 and C.red or C.fire)
	refs.fuelText.Text = camp.lit == false and "🔥 OUT!" or ("🔥 " .. math.floor(fuel / fuelMax * 100) .. "%")
	refs.objective.Visible = Store.inRun()
	local profile = Store.get("profile")
	if refs.menu.progress then
		refs.menu.progress.dot.Visible = profile ~= nil and (#(profile.perks or {}) < (profile.perkSlots or 0))
	end
end

-- Bottom: the hotbar ------------------------------------------------------------------------------------------------------------------------
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
			outline = 2,
			Parent = b,
		})
		local key = Theme.title({
			Name = "Key",
			Text = tostring(i),
			Position = UDim2.fromOffset(4, 1),
			Size = UDim2.fromOffset(16, 16),
			TextColor3 = C.muted:Lerp(C.white, 0.4),
			outline = 1.5,
			Parent = b,
		})
		local fuelBar, fuelFill = Theme.bar({
			Name = "Burn",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, -14, 0, 5),
			Visible = false,
			Parent = b,
		}, C.fire)
		b.Activated:Connect(function()
			InputController.select(i)
		end)
		refs.slots[i] = {
			button = b,
			stroke = stroke,
			icon = icon,
			count = count,
			key = key,
			fuelBar = fuelBar,
			fuelFill = fuelFill,
		}
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
	end)
end

local function updateHotbar()
	local inv = Store.get("inv") or { slots = {} }
	local keyboard = Theme.inputKind() == "keyboard"
	for i, s in refs.slots do
		local slot = inv.slots["h" .. i]
		local item = slot and Items.get(slot.key)
		s.icon.Text = item and item.icon or ""
		s.count.Text = (slot and slot.n > 1) and tostring(slot.n) or ""
		local selected = (inv.selected or 1) == i
		s.stroke.Color = selected and C.mustard or (item and rarityColor(item) or C.ink)
		s.stroke.Thickness = selected and 5 or 3
		s.button.BackgroundColor3 = item and Theme.darken(rarityColor(item), 0.55) or C.slate
		s.button.Size = selected and UDim2.fromOffset(64, 64) or UDim2.fromOffset(60, 60)
		s.button.Position = UDim2.fromOffset((i - 1) * 66 - (selected and 2 or 0), selected and 0 or 2)
		s.key.Visible = keyboard
		if item and item.burn and slot.fuel then
			s.fuelBar.Visible = true
			s.fuelFill.Size = UDim2.fromScale(math.clamp(slot.fuel / item.burn, 0, 1), 1)
		else
			s.fuelBar.Visible = false
		end
	end
	refs.hotbar.Visible = Store.inRun() and (Store.status() == "alive" or Store.status() == "downed")
end

-- Mega Kermy's bar ---------------------------------------------------------------------------------------------------------------------------
local function buildBoss()
	local slab = Theme.slab({
		Name = "Boss",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(520, 46),
		BackgroundColor3 = Color3.fromRGB(40, 60, 36),
		Visible = false,
		Parent = gui,
	})
	refs.boss = slab
	refs.bossName = Theme.title({
		Name = "Who",
		Text = "👹 MEGA KERMY",
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 2),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Color3.fromRGB(170, 255, 120),
		outline = 2,
		Parent = slab,
	})
	local bar, fill = Theme.bar(
		{ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 22), Parent = slab },
		Color3.fromRGB(130, 220, 80)
	)
	refs.bossFill = fill
	for _, f in { 0.66, 0.33 } do
		new("Frame", {
			Name = "Tick",
			Position = UDim2.new(f, -1, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = C.ink,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = bar,
		})
	end
	refs.bossTag = Theme.title({
		Name = "Tag",
		Text = "",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 10, 0.5, 0),
		Size = UDim2.fromOffset(140, 30),
		TextColor3 = C.mustard,
		outline = 2.5,
		Parent = slab,
	})
end

local function updateBoss()
	local b = Store.get("boss")
	refs.boss.Visible = type(b) == "table" and Store.phase() == "boss"
	if type(b) ~= "table" then
		return
	end
	refs.bossFill.Size = UDim2.fromScale(math.clamp(b.hp / math.max(1, b.maxHp), 0, 1), 1)
	refs.bossFill.BackgroundColor3 = b.weak and C.mustard or (b.enraged and C.red or Color3.fromRGB(130, 220, 80))
	refs.bossTag.Text = b.weak and "💫 WEAK!" or (b.enraged and "😡 ENRAGED" or "")
	refs.bossName.Text = "👹 MEGA KERMY" .. (b.phase and b.phase > 1 and ("  ·  PHASE " .. b.phase) or "")
end

-- Messages -----------------------------------------------------------------------------------------------------------------------------------
local toastY = 0
function HudController.toast(text, kind)
	if type(text) ~= "string" then
		return
	end
	local color = kind == "bad" and C.red or kind == "good" and C.good or C.slate
	local label = Theme.slab({
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -88 - toastY),
		Size = UDim2.fromOffset(460, 38),
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
	task.delay(3.2, function()
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
		Position = UDim2.new(0.5, 0, 0.38, 0),
		Size = UDim2.fromOffset(760, 70),
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
		Position = UDim2.new(0.5, 0, 0, 180),
		Size = UDim2.fromOffset(560, 42),
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
	task.delay(4, function()
		if refs.callout == slab then
			slab:Destroy()
			refs.callout = nil
		end
	end)
end

-- Unlock cards: level ups, achievements, discoveries, mastery, looks.
local cardY = 0
function HudController.unlock(u)
	if type(u) ~= "table" then
		return
	end
	local text = u.news or u.text or u.name or ""
	if type(text) ~= "string" or text == "" then
		return
	end
	local color = u.kind == "level" and C.mustard
		or u.kind == "achievement" and C.purple
		or u.kind == "discovery" and C.sky
		or u.kind == "mastery" and C.orange
		or C.good
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

-- Overlays: down, ghost, waiting ---------------------------------------------------------------------------------------------------------------
local function buildOverlays()
	refs.vignette = new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.red,
		BackgroundTransparency = 1,
		ZIndex = 0,
		Active = false,
		Parent = gui,
	})
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, 0.8),
			NumberSequenceKeypoint.new(0.75, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = refs.vignette,
	})
	refs.flash = new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Active = false,
		Parent = gui,
	})
	-- down
	local down = Theme.slab({
		Name = "Down",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(440, 96),
		BackgroundColor3 = Color3.fromRGB(110, 26, 30),
		Visible = false,
		Parent = gui,
	})
	refs.down = down
	Theme.title({
		Name = "Title",
		Text = "🆘 YOU'RE DOWN!",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 4),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		outline = 3,
		Parent = down,
	})
	refs.downHint = Theme.text({
		Name = "Hint",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = down,
	})
	local bleed, bleedFill = Theme.bar(
		{ Name = "Bleed", Size = UDim2.new(1, -40, 0, 16), Position = UDim2.fromOffset(20, 64), Parent = down },
		C.red
	)
	refs.bleedFill = bleedFill
	_ = bleed
	-- ghost / waiting / watching
	local out = Theme.slab({
		Name = "Out",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(560, 120),
		Visible = false,
		Parent = gui,
	})
	refs.out = out
	refs.outTitle = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.fromOffset(10, 6),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 3,
		Parent = out,
	})
	refs.outHint = Theme.text({
		Name = "Hint",
		Text = "",
		TextColor3 = C.white,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(10, 38),
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = 1.5,
		Parent = out,
	})
	local function outButton(name, text, color, x, w, fn)
		local b = Theme.button({
			Name = name,
			Text = text,
			BackgroundColor3 = color,
			Size = UDim2.fromOffset(w, 44),
			Position = UDim2.fromOffset(x, 66),
			Parent = out,
		})
		b.Activated:Connect(fn)
		return b
	end
	refs.prevWatch = outButton("Prev", "◀", C.slate, 14, 54, function()
		HudController.cycleWatch(-1)
	end)
	refs.newRun = outButton("NewRun", "🔎 FIND A NEW RUN", C.good, 78, 200, function()
		Net.send("FriendAction", "newrun")
		Bus.Tap:Fire("newrun")
	end)
	refs.friendsBtn = outButton("Friends", "👥 FRIENDS", C.sky, 286, 140, function()
		Bus.Open:Fire("friends")
	end)
	refs.nextWatch = outButton("Next", "▶", C.slate, 492, 54, function()
		HudController.cycleWatch(1)
	end)
end

-- Watching a teammate while you're out.
function HudController.cycleWatch(step)
	local list = {}
	for _, t in Store.get("team") or {} do
		if t.userId ~= player.UserId and t.status == "alive" then
			table.insert(list, t.userId)
		end
	end
	if #list == 0 then
		spectating = nil
		return
	end
	local idx = table.find(list, spectating) or 0
	idx = ((idx - 1 + (step or 1)) % #list) + 1
	spectating = list[idx]
end

local function updateCamera()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local status = Store.status()
	local out = status == "ghost" or status == "waiting" or not player.Character
	if out then
		local target = spectating and Players:GetPlayerByUserId(spectating)
		local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if not hum then
			HudController.cycleWatch(1)
			target = spectating and Players:GetPlayerByUserId(spectating)
			hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		end
		if hum and cam.CameraSubject ~= hum then
			cam.CameraSubject = hum
		end
	else
		local mine = player.Character:FindFirstChildOfClass("Humanoid")
		if mine and cam.CameraSubject ~= mine then
			cam.CameraSubject = mine
		end
	end
end

local function updateOverlays()
	local me = Store.get("me") or {}
	local status = me.status
	local now = workspace:GetServerTimeNow()
	refs.down.Visible = status == "downed"
	if status == "downed" then
		local left = me.bleedUntil and math.max(0, me.bleedUntil - now) or 0
		local d = Constants.DIFFICULTIES[workspace:GetAttribute("Difficulty") or 1]
		refs.bleedFill.Size = UDim2.fromScale(math.clamp(left / (d and d.bleed or 30), 0, 1), 1)
		if (me.fireRevive or 0) > 0 then
			refs.downHint.Text =
				`🔥 Warming up by the fire... {math.ceil(Constants.FIRE_REVIVE_SECONDS - me.fireRevive)}s`
		elseif d and d.fireRevive then
			refs.downHint.Text = `Crawl into the campfire's light, or wait for a teammate ({math.ceil(left)}s)`
		else
			refs.downHint.Text = `Hold on! A teammate has to revive you ({math.ceil(left)}s)`
		end
	end
	local inRun = Store.inRun()
	local phase = Store.phase()
	local waiting = (status == "waiting" or not inRun) and phase ~= "idle" and phase ~= "results"
	local ghost = status == "ghost"
	refs.out.Visible = waiting or ghost
	if ghost then
		refs.outTitle.Text = "👻 YOU'RE OUT UNTIL DAWN"
		refs.outTitle.TextColor3 = Color3.fromRGB(190, 210, 255)
		local who = spectating and Players:GetPlayerByUserId(spectating)
		refs.outHint.Text = Store.isNight()
				and ((who and ("Watching " .. who.DisplayName) or "Cheer your team on!") .. " · Your pack is where you fell")
			or "Back on your feet in a moment..."
		refs.newRun.Visible = false
		refs.friendsBtn.Visible = false
	elseif waiting then
		refs.outTitle.Text = "⏳ A RUN IS UNDERWAY"
		refs.outTitle.TextColor3 = C.teal
		local night = workspace:GetAttribute("Night") or 0
		refs.outHint.Text = (night > 0 and `It's night {night}.` or "The roster is full.")
			.. " You'll be in the next run, or find one starting now!"
		refs.newRun.Visible = true
		refs.friendsBtn.Visible = true
	end
	refs.prevWatch.Visible = (waiting or ghost)
	refs.nextWatch.Visible = (waiting or ghost)
	-- red edges when low
	if status == "alive" and (me.hp or 100) < (me.maxHp or 100) * 0.3 then
		local pulse = 0.72 + math.sin(os.clock() * 5) * 0.08
		if refs.vignette.BackgroundTransparency > pulse then
			refs.vignette.BackgroundTransparency = pulse
		end
	end
end

-- Pings at the edge of the compass, and in the world (FxController draws the pillar).
local function onPing(ping)
	if type(ping) == "table" and typeof(ping.position) == "Vector3" then
		table.insert(pings, {
			key = ping.key,
			icon = ping.icon or "📍",
			pos = ping.position,
			untilT = os.clock() + Constants.PING_SECONDS,
		})
		if ping.from and ping.from ~= player.DisplayName then
			HudController.toast(
				`{ping.icon or "📢"} {ping.from}: {ping.text or ""}`,
				ping.key == "kermy" and "bad" or "info"
			)
		end
	end
end

function HudController:init()
	gui = Theme.screen("Hud", 2, player:WaitForChild("PlayerGui"))
	buildOverlays()
	buildClock()
	buildMe()
	buildRight()
	buildHotbar()
	buildBoss()
	Net.listen("Toast", HudController.toast)
	Net.listen("Alert", HudController.alert)
	Net.listen("Callout", HudController.callout)
	Net.listen("Unlock", HudController.unlock)
	Net.listen("Hurt", hurt)
	Net.listen("Ping", onPing)
	Bus.Flash:Connect(flash)
	Store.Changed:Connect(function(partial)
		if partial.inv then
			updateHotbar()
		elseif partial.me or partial.team then
			updateMe()
		elseif partial.objective or partial.camp or partial.profile then
			updateRight()
		elseif partial.boss then
			updateBoss()
		end
	end)
	local acc = 1
	RunService.RenderStepped:Connect(function(dt)
		updateCompass()
		acc += dt
		if acc >= 0.25 then
			acc = 0
			updateClock()
			updateMe()
			updateRight()
			updateHotbar()
			updateBoss()
			updateOverlays()
			updateCamera()
		end
	end)
end

-- (tests)
HudController.refs = refs

return HudController

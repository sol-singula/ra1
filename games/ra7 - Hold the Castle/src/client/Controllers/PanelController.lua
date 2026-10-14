--[[
The panels behind the menu buttons and the boards in the world (master plan §16 to §19):

  SHOP      looks by slot (dwarf armor, beards, monster skins, weapon looks, build effects, emotes, win poses,
            castle flags) and titles. Tap one to see it on a turning 3D model; buy with coins, wear what you
            own. Looks only: nothing here makes anyone stronger. Titles are earned by playing, never bought.
            The LOOKS SHOP sign in the hangout opens it too.
  TASKS     the daily gift (keep the streak), today's three tasks, the weekly task, your stats and job levels
  FRIENDS   friends online in Hold the Castle and how their match is going; JOIN takes you to their exact server
  MORE      settings (effects, screen shake, music), your emotes, how to play, how to report someone
  JOBS      the Job Board (its prompt opens it): the five dwarf jobs, what each one does, your level in each.
            Monsters pick from the picker (HudController) instead.
Plus the small cards: server full / waiting / rejoin, "Do you like the game?" and the update-alerts offer.
]]
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Costumes = require(ReplicatedStorage.Shared.World.Costumes)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local Looks = require(ReplicatedStorage.Shared.Data.Looks)
local Net = require(ReplicatedStorage.Shared.Net)
local PieceModels = require(ReplicatedStorage.Shared.World.PieceModels)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local PanelController = { Name = "PanelController", Order = 35 }

local gui, panel, titleLabel, tabsRow, body, side
local current -- the open panel's name
local tab = {} -- [panel] = the open tab
local selected = {} -- [slot] = the look tapped in the shop (shown in the preview)
local friendsList = {} -- { { userId, name, display, jobId } } from GetFriendsOnline
local friendStatus = {} -- [userId] = status from the server
local dialog
local preview -- { viewport, camera, npc, model, key, clock }

local function hud()
	return require(script.Parent.HudController)
end

local function profile()
	return Store.get("profile")
end

-- Little helpers --------------------------------------------------------------------------------------------------
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function listLayout(parent, dir, pad, align)
	return new("UIListLayout", {
		FillDirection = dir == "x" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, pad or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = dir == "x" and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

-- A white rounded row inside the cream panel.
local function row(parent, height, props)
	props = props or {}
	local f = new("Frame", {
		Name = props.Name or "Row",
		Size = UDim2.new(1, -8, 0, height or 0),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		BackgroundColor3 = props.color or C.white,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2.5) })
	if props.pad ~= false then
		Theme.padding(8).Parent = f
	end
	return f
end

local function label(parent, text, size, props)
	props = props or {}
	return Theme.text({
		Name = props.Name or "Label",
		Text = text,
		Size = props.Size or UDim2.new(1, 0, 0, 0),
		Position = props.Position,
		AutomaticSize = props.Size and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		TextSize = size or 16,
		TextColor3 = props.color or C.ink,
		Font = props.font,
		RichText = props.rich,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		TextYAlignment = props.valign,
		LayoutOrder = props.order or nextOrder(),
		Parent = parent,
	})
end

local function heading(parent, text, color)
	return Theme.title({
		Name = "Heading",
		Text = text,
		Size = UDim2.new(1, -8, 0, 26),
		TextColor3 = color or C.mustard,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
end

local function progressBar(parent, frac, color, text, props)
	props = props or {}
	local bar, fill = Theme.bar({
		Name = props.Name or "Progress",
		Size = props.Size or UDim2.new(1, 0, 0, 18),
		Position = props.Position,
		LayoutOrder = nextOrder(),
		Parent = parent,
	}, color or C.good)
	fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	if text then
		Theme.text({
			Name = "Text",
			Text = text,
			Font = Theme.Display,
			TextColor3 = C.white,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			outline = 1.5,
			ZIndex = 3,
			Parent = bar,
		})
	end
	return bar, fill
end

-- The frame -------------------------------------------------------------------------------------------------------
local function buildFrame()
	gui = Theme.screen("Panels", 20, player:WaitForChild("PlayerGui"))
	panel = Theme.card({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 8),
		Size = UDim2.fromOffset(780, 452),
		Visible = false,
		Parent = gui,
	})
	titleLabel = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -90, 0, 38),
		Position = UDim2.fromOffset(18, 8),
		TextColor3 = C.mustard,
		Parent = panel,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "✖",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(52, 42),
		Parent = panel,
	})
	close.Activated:Connect(function()
		PanelController.close()
	end)
	tabsRow = new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	listLayout(tabsRow, "x", 4)
	body = new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(12, 94),
		Size = UDim2.new(1, -24, 1, -104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.ink,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	-- the shop's 3D preview (right side)
	side = new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 94),
		Size = UDim2.new(0, 220, 1, -104),
		BackgroundColor3 = Color3.fromRGB(196, 228, 255),
		BorderSizePixel = 0,
		Visible = false,
		Parent = panel,
	}, { Theme.corner(14), Theme.stroke(2.5) })
end

local function clearBody()
	for _, c in body:GetChildren() do
		if not c:IsA("UIScale") then
			c:Destroy()
		end
	end
	order = 0
end

local function setTabs(list, active, onPick)
	for _, c in tabsRow:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	tabsRow.Visible = list ~= nil
	body.Position = UDim2.fromOffset(12, list and 94 or 56)
	body.Size = UDim2.new(1, -24, 1, list and -104 or -66)
	if not list then
		return
	end
	local w = math.floor((756 - (#list - 1) * 4) / #list)
	for i, t in list do
		local on = t.key == active
		local b = Theme.button({
			Name = "Tab_" .. t.key,
			Text = t.text,
			BackgroundColor3 = on and C.mustard or C.white,
			dark = not on,
			Size = UDim2.fromOffset(w, 34),
			LayoutOrder = i,
			Parent = tabsRow,
		})
		b.Activated:Connect(function()
			onPick(t.key)
		end)
	end
end

-- The 3D preview in the shop ----------------------------------------------------------------------------------------
local function clearPreview()
	if preview then
		preview.viewport:Destroy()
		preview = nil
	end
end

local function equippedLook()
	local p = profile()
	local eq = p and p.looks and p.looks.equipped or {}
	return {
		armor = Looks.byKey[eq.armor or Looks.default.armor],
		beard = Looks.byKey[eq.beard or Looks.default.beard],
		weapon = Looks.byKey[eq.weapon or Looks.default.weapon],
		skin = Looks.byKey[eq.skin or Looks.default.skin],
		flag = Looks.byKey[eq.flag or Looks.default.flag],
		job = p and p.dwarfJob or Jobs.DEFAULT_DWARF,
	}
end

local function showPreview(slot, item)
	local key = slot .. ":" .. (item and item.key or "")
	if preview and preview.key == key then
		return
	end
	clearPreview()
	local viewport = new("ViewportFrame", {
		Name = "Preview",
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 185),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
		Parent = side,
	})
	local camera = new("Camera", { FieldOfView = 34, Parent = viewport })
	viewport.CurrentCamera = camera
	local look = equippedLook()
	preview = { viewport = viewport, camera = camera, key = key, clock = 0, slot = slot }
	if slot == "flag" then
		local cf = CFrame.new(0, 0, 0)
		local ok, model = pcall(PieceModels.build, "flag", cf, { flag = item or look.flag })
		if ok and model then
			model.Parent = viewport
			preview.model = model
		end
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 9, -24), Vector3.new(0, 7, 0))
		return
	end
	local npc
	if slot == "skin" then
		npc = Costumes.npc("grunt", { skin = item or look.skin }, viewport)
	else
		if item and (slot == "armor" or slot == "beard" or slot == "weapon") then
			look[slot] = item
		end
		npc = Costumes.npc("dwarf", look, viewport)
	end
	preview.npc = npc
	Costumes.place(npc, CFrame.new(), {})
	local h = 6.4 * npc.scale
	camera.CFrame = CFrame.lookAt(Vector3.new(0, h * 0.62, -h * 2.05), Vector3.new(0, h * 0.45, 0))
end

local function stepPreview(dt)
	if not preview or not preview.npc then
		if preview and preview.model and preview.model.PrimaryPart then
			preview.clock += dt
			preview.model:PivotTo(CFrame.Angles(0, math.sin(preview.clock * 0.8) * 0.5, 0))
		end
		return
	end
	preview.clock += dt
	local t = preview.clock
	local pose = {}
	local slot = preview.slot
	if slot == "emote" or slot == "pose" then
		pose.cheer = t
	elseif slot == "weapon" or slot == "buildFx" then
		pose.swing = (t % 1.2) / 0.8 <= 1 and (t % 1.2) / 0.8 or nil
	end
	local spin = Theme.reducedMotion() and 0.4 or math.sin(t * 0.7) * 0.9
	Costumes.place(preview.npc, CFrame.Angles(0, spin, 0), pose)
end

-- SHOP --------------------------------------------------------------------------------------------------------------
local SHOP_TABS = {
	{ key = "armor", text = "🪖 Armor" },
	{ key = "beard", text = "🧔 Beard" },
	{ key = "skin", text = "👹 Skin" },
	{ key = "weapon", text = "🔨 Tool" },
	{ key = "buildFx", text = "✨ Build" },
	{ key = "emote", text = "💃 Emote" },
	{ key = "pose", text = "🏆 Pose" },
	{ key = "flag", text = "🚩 Flag" },
	{ key = "title", text = "🏷️ Titles" },
}
local ITEM_ICON = {
	wave = "👋",
	cheer = "🙌",
	laugh = "😂",
	flex = "💪",
	dance = "🕺",
	hammerUp = "🔨",
	bow = "🙇",
	jump = "🦘",
	bigRoar = "🦖",
	dust = "💨",
	hearts = "💖",
	sparkles = "🌟",
	confetti = "🎉",
	lightning = "⚡",
}
local SLOT_LINE = {
	armor = "What your dwarf wears.",
	beard = "Every dwarf needs one.",
	skin = "Your monster's colours.",
	weapon = "The look of your hammer, pick and bow.",
	buildFx = "What pops out when you hammer.",
	emote = "Press H (or MORE) to do your emote.",
	pose = "Your pose when your side wins.",
	flag = "Your colours on the banners you build.",
}

local function swatch(parent, item, slot)
	local holder = new("Frame", {
		Name = "Swatch",
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(0.5, -32, 0, 8),
		BackgroundColor3 = item.main or C.paper,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner("round"), Theme.stroke(2.5) })
	if ITEM_ICON[item.key] or not item.main then
		holder.BackgroundColor3 = item.main and Theme.lighten(item.main, 0.55) or C.paper
		Theme.text({
			Text = ITEM_ICON[item.key] or (Looks.slots[1].key == slot and "🪖" or "👹"),
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})
	elseif item.trim then
		new("Frame", {
			Name = "Trim",
			Size = UDim2.fromScale(0.45, 0.45),
			Position = UDim2.fromScale(0.55, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = item.trim,
			BorderSizePixel = 0,
			Parent = holder,
		}, { Theme.corner("round"), Theme.stroke(2) })
	end
	if item.rainbow then
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Looks.RAINBOW[1]),
				ColorSequenceKeypoint.new(0.33, Looks.RAINBOW[3]),
				ColorSequenceKeypoint.new(0.66, Looks.RAINBOW[5]),
				ColorSequenceKeypoint.new(1, Looks.RAINBOW[6]),
			}),
			Rotation = 45,
			Parent = holder,
		})
	end
	if item.glow then
		holder.UIStroke.Color = item.glow
		holder.UIStroke.Thickness = 4
	end
	return holder
end

local function renderTitles(p)
	local owned = p.titles and p.titles.owned or {}
	local worn = p.titles and p.titles.equipped
	label(body, "Titles show over your head and on the results screen. Earn them by playing.", 15, { color = C.muted })
	for _, t in Looks.titles do
		local r = row(body, 62, { Name = "Title_" .. t.key, pad = false })
		Theme.title({
			Text = t.name,
			Size = UDim2.new(1, -170, 0, 26),
			Position = UDim2.fromOffset(12, 6),
			TextColor3 = owned[t.key] and C.mustard or C.muted,
			outline = 2,
			Parent = r,
		})
		Theme.text({
			Text = t.line,
			TextSize = 14,
			Size = UDim2.new(1, -170, 0, 20),
			Position = UDim2.fromOffset(12, 34),
			Parent = r,
		})
		if owned[t.key] then
			local isWorn = worn == t.key
			local b = Theme.button({
				Name = "Wear",
				Text = isWorn and "WORN ✔" or "WEAR",
				BackgroundColor3 = isWorn and C.good or C.sky,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(140, 40),
				Parent = r,
			})
			b.Activated:Connect(function()
				if not isWorn then
					Net.send("Equip", "title", t.key)
				end
			end)
		elseif t.stat then
			local have = p.stats and p.stats[t.stat] or 0
			progressBar(r, have / t.goal, C.sky, `{math.min(have, t.goal)} / {t.goal}`, {
				Size = UDim2.fromOffset(140, 22),
				Position = UDim2.new(1, -150, 0.5, -11),
			})
		end
	end
end

local function renderShop()
	titleLabel.Text = "🛒 LOOKS SHOP"
	local p = profile()
	local slot = tab.shop or "armor"
	setTabs(SHOP_TABS, slot, function(k)
		tab.shop = k
		PanelController.refresh()
	end)
	if not p then
		label(body, "Loading…", 16)
		return
	end
	local coinsRow = row(body, 40, { Name = "Coins", color = C.paper })
	Theme.title({
		Text = `🪙 {p.coins} coins`,
		Size = UDim2.new(0.5, 0, 1, 0),
		TextColor3 = C.mustard,
		outline = 2,
		Parent = coinsRow,
	})
	Theme.text({
		Text = slot == "title" and "Earned, never bought" or SLOT_LINE[slot] or "",
		TextSize = 14,
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.muted,
		Parent = coinsRow,
	})
	if slot == "title" then
		side.Visible = false
		body.Size = UDim2.new(1, -24, 1, -104)
		clearPreview()
		renderTitles(p)
		return
	end
	-- items on the left, the preview on the right
	side.Visible = true
	body.Size = UDim2.new(1, -258, 1, -104)
	local grid = new("Frame", {
		Name = "Grid",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = body,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(118, 150),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local owned = p.looks and p.looks.owned or {}
	local worn = p.looks and p.looks.equipped and p.looks.equipped[slot] or Looks.default[slot]
	local pick = selected[slot] or Looks.byKey[worn]
	for i, item in Looks.bySlot[slot] or {} do
		local isOwned = owned[item.key] or item.price == 0
		local isWorn = worn == item.key
		local card = new("TextButton", {
			Name = "Item_" .. item.key,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = grid,
		}, { Theme.corner(14), Theme.stroke(pick == item and 4 or 2.5, pick == item and C.mustard or C.ink) })
		swatch(card, item, slot)
		Theme.text({
			Text = item.name,
			Font = Theme.Display,
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 76),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		local canAfford = p.coins >= item.price
		local b = Theme.button({
			Name = "Action",
			Text = isWorn and "WORN ✔" or isOwned and "WEAR" or `🪙 {item.price}`,
			BackgroundColor3 = isWorn and C.good or isOwned and C.sky or canAfford and C.mustard or C.muted,
			Size = UDim2.new(1, -12, 0, 36),
			Position = UDim2.new(0, 6, 1, -42),
			Parent = card,
		})
		card.Activated:Connect(function()
			selected[slot] = item
			showPreview(slot, item)
			PanelController.refresh()
		end)
		b.Activated:Connect(function()
			selected[slot] = item
			showPreview(slot, item)
			if isWorn then
				return
			elseif isOwned then
				Bus.Tap:Fire("wear_" .. item.key)
				Net.send("Equip", slot, item.key)
			elseif Theme.busy(b, 1) then
				Bus.Tap:Fire("buy_" .. item.key)
				Net.send("Buy", item.key)
			end
		end)
	end
	showPreview(slot, pick)
end

-- TASKS -------------------------------------------------------------------------------------------------------------
local STAT_LINES = {
	{ "matches", "🎮 Matches" },
	{ "dwarfWins", "🛡️ Holds won" },
	{ "monsterWins", "👹 Castles taken" },
	{ "built", "🔨 Pieces built" },
	{ "beaten", "⚔️ Monsters beaten" },
	{ "dwarvesBeaten", "🧔 Dwarves beaten" },
	{ "mined", "⛏️ Materials mined" },
	{ "healed", "💚 Health healed" },
	{ "gates", "🚪 Gates broken" },
}

local function taskRow(t, weekly)
	local r = row(body, 66, { Name = (weekly and "Weekly_" or "Task_") .. t.key, pad = false })
	Theme.text({
		Text = (t.done and "✔ " or "") .. t.line,
		Font = Theme.Display,
		Size = UDim2.new(1, -150, 0, 26),
		Position = UDim2.fromOffset(12, 6),
		TextColor3 = t.done and C.good or C.ink,
		Parent = r,
	})
	progressBar(r, t.progress / math.max(1, t.goal), t.done and C.good or C.sky, `{t.progress} / {t.goal}`, {
		Size = UDim2.new(1, -170, 0, 20),
		Position = UDim2.fromOffset(12, 38),
	})
	Theme.title({
		Text = `🪙 {t.coins}`,
		Size = UDim2.fromOffset(120, 34),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = t.done and C.muted or C.mustard,
		outline = 2,
		Parent = r,
	})
end

local function renderTasks()
	titleLabel.Text = "📋 TASKS"
	setTabs(nil)
	side.Visible = false
	local p = profile()
	if not p then
		label(body, "Loading…", 16)
		return
	end
	-- the daily gift
	local g = p.gift or {}
	local giftRow =
		row(body, 74, { Name = "Gift", color = g.ready and Color3.fromRGB(255, 240, 190) or C.white, pad = false })
	Theme.text({ Text = "🎁", Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 9), Parent = giftRow })
	Theme.title({
		Text = g.ready and "YOUR DAILY GIFT IS READY!" or "DAILY GIFT",
		Size = UDim2.new(1, -250, 0, 28),
		Position = UDim2.fromOffset(74, 8),
		TextColor3 = C.mustard,
		outline = 2,
		Parent = giftRow,
	})
	Theme.text({
		Text = g.ready and `Claim 🪙 {g.next or 0}. Come back every day to keep your streak!`
			or `Day {g.streak or 0} streak. Come back tomorrow for 🪙 {g.next or 0}.`,
		TextSize = 14,
		Size = UDim2.new(1, -250, 0, 30),
		Position = UDim2.fromOffset(74, 38),
		Parent = giftRow,
	})
	local claim = Theme.button({
		Name = "Claim",
		Text = g.ready and "CLAIM" or "CLAIMED ✔",
		BackgroundColor3 = g.ready and C.good or C.muted,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 46),
		Parent = giftRow,
	})
	claim.Activated:Connect(function()
		if g.ready and Theme.busy(claim, 2) then
			Bus.Tap:Fire("gift")
			Net.send("ClaimGift")
		end
	end)
	heading(body, "TODAY")
	for _, t in p.tasks or {} do
		taskRow(t, false)
	end
	if p.weekly then
		heading(body, "THIS WEEK", C.purple)
		taskRow(p.weekly, true)
	end
	-- stats
	heading(body, "YOUR STATS", C.sky)
	local grid = new("Frame", {
		Name = "Stats",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = body,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(244, 40),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local stats = p.stats or {}
	local function stat(i, text, value)
		local f = new("Frame", {
			Name = "Stat",
			BackgroundColor3 = C.white,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = grid,
		}, { Theme.corner(10), Theme.stroke(2) })
		Theme.text({
			Text = text,
			TextSize = 15,
			Size = UDim2.new(0.68, -8, 1, 0),
			Position = UDim2.fromOffset(8, 0),
			Parent = f,
		})
		Theme.text({
			Text = value,
			Font = Theme.Display,
			TextSize = 18,
			Size = UDim2.new(0.32, -8, 1, 0),
			Position = UDim2.fromScale(0.68, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = f,
		})
	end
	stat(0, "⏱️ Longest hold", Formulas.clock(stats.bestHold or 0))
	for i, s in STAT_LINES do
		stat(i, s[2], tostring(math.floor(stats[s[1]] or 0)))
	end
	-- job levels
	heading(body, "JOB LEVELS", C.orange)
	local jobsRow = new("Frame", {
		Name = "JobLevels",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = body,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(146, 40),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = jobsRow,
	})
	local levels = p.jobLevels or {}
	local all = {}
	for _, j in Jobs.dwarf do
		table.insert(all, j)
	end
	for _, j in Jobs.monster do
		table.insert(all, j)
	end
	for i, j in all do
		local f = new("Frame", {
			Name = "Job_" .. j.key,
			BackgroundColor3 = j.team == "monster" and Color3.fromRGB(226, 246, 200) or C.white,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = jobsRow,
		}, { Theme.corner(10), Theme.stroke(2) })
		Theme.text({
			Text = `{j.icon} {j.name}  Lv {levels[j.key] or 1}`,
			Font = Theme.Display,
			TextSize = 15,
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.fromOffset(6, 0),
			Parent = f,
		})
	end
end

-- JOBS (the dwarf Job Board) ------------------------------------------------------------------------------------------
local function renderJobs()
	titleLabel.Text = "🪧 JOB BOARD"
	setTabs(nil)
	side.Visible = false
	local p = profile()
	local me = Store.get("me") or {}
	local phase = Store.phase()
	local locked = phase == "plague" or phase == "fight" or phase == "laststand"
	label(
		body,
		locked and "Jobs are locked once the plague comes. Pick again next match!"
			or "Pick what you do best. No job is the best: each one is good at one thing.",
		15,
		{ color = locked and C.red or C.muted }
	)
	local holder = new("Frame", {
		Name = "Jobs",
		Size = UDim2.new(1, -8, 0, 300),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = body,
	})
	listLayout(holder, "x", 8)
	local levels = p and p.jobLevels or {}
	for i, j in Jobs.dwarf do
		local mine = me.job == j.key
		local card = new("Frame", {
			Name = "Job_" .. j.key,
			Size = UDim2.fromOffset(144, 296),
			BackgroundColor3 = mine and Color3.fromRGB(214, 246, 214) or C.white,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = holder,
		}, { Theme.corner(14), Theme.stroke(mine and 4 or 2.5, mine and C.good or C.ink) })
		Theme.text({
			Text = j.icon,
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 6),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		Theme.text({
			Text = j.name:upper(),
			Font = Theme.Display,
			Size = UDim2.new(1, -8, 0, 24),
			Position = UDim2.fromOffset(4, 54),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		Theme.text({
			Text = `Lv {levels[j.key] or 1} · ❤️ {j.hp}`,
			TextSize = 13,
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 78),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.muted,
			Parent = card,
		})
		Theme.text({
			Text = j.line,
			TextSize = 13,
			Size = UDim2.new(1, -12, 0, 52),
			Position = UDim2.fromOffset(6, 98),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		Theme.text({
			Text = `{j.special.icon} {j.special.name}`,
			Font = Theme.Display,
			TextSize = 14,
			Size = UDim2.new(1, -8, 0, 20),
			Position = UDim2.fromOffset(4, 152),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.purple,
			Parent = card,
		})
		Theme.text({
			Text = j.special.line or "",
			TextSize = 12,
			Size = UDim2.new(1, -12, 0, 46),
			Position = UDim2.fromOffset(6, 172),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		Theme.text({
			Text = "⭐ " .. (j.trait or ""),
			TextSize = 12,
			Size = UDim2.new(1, -12, 0, 30),
			Position = UDim2.fromOffset(6, 218),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = C.orange,
			Parent = card,
		})
		local b = Theme.button({
			Name = "Pick",
			Text = mine and "KEEP ✔" or "PICK",
			BackgroundColor3 = locked and C.muted or mine and C.good or C.mustard,
			Size = UDim2.new(1, -12, 0, 38),
			Position = UDim2.new(0, 6, 1, -44),
			Parent = card,
		})
		b.Activated:Connect(function()
			if locked then
				hud().toast("Jobs are locked once the plague comes.", "bad")
				return
			end
			Bus.Tap:Fire("job_" .. j.key)
			Net.send("Job", j.key)
			PanelController.close()
		end)
	end
end

-- FRIENDS -----------------------------------------------------------------------------------------------------------
local PHASE_WORD = {
	intermission = "in the hangout",
	build = "building the castle",
	plague = "the plague is here",
	fight = "fighting",
	laststand = "the LAST STAND",
	ended = "finishing a match",
}

local function statusText(f)
	local s = friendStatus[f.userId]
	if Players:GetPlayerByUserId(f.userId) then
		return "In this server", C.good
	end
	if not s then
		return "Checking their match…", C.muted
	end
	if s.unknown then
		return "In Hold the Castle", C.ink
	end
	local word = PHASE_WORD[s.phase] or "in a match"
	if s.phase == "fight" and s.shrine then
		word = `fighting at shrine {s.shrine}`
	end
	local held = (s.phase == "fight" or s.phase == "laststand") and s.held and ` · held {Formulas.clock(s.held)}` or ""
	local crew = ` · {s.crew or "?"}/{s.max or Constants.MAX_PLAYERS} players`
	if s.full then
		return `Server full{crew}`, C.orange
	end
	return string.upper(string.sub(word, 1, 1))
		.. string.sub(word, 2)
		.. held
		.. crew
		.. (s.private and " · 🔒 private" or ""),
		C.ink
end

local function renderFriends()
	titleLabel.Text = "👋 FRIENDS"
	setTabs(nil)
	side.Visible = false
	local top = row(body, 60, { Name = "Invite", color = C.paper, pad = false })
	Theme.text({
		Text = "Castles are better with friends! Invite them, or join a friend's match below: you go to their exact server.",
		TextSize = 14,
		Size = UDim2.new(1, -200, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		Parent = top,
	})
	local invite = Theme.button({
		Name = "InviteButton",
		Text = "INVITE",
		BackgroundColor3 = C.pink,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(170, 44),
		Parent = top,
	})
	invite.Activated:Connect(function()
		Bus.Tap:Fire("invite")
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end)
	if #friendsList == 0 then
		label(body, "None of your friends are in Hold the Castle right now. Invite them!", 16, { color = C.muted })
		return
	end
	for _, f in friendsList do
		local r = row(body, 60, { Name = "Friend_" .. f.userId, pad = false })
		new("ImageLabel", {
			Name = "Avatar",
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = C.paper,
			Image = `rbxthumb://type=AvatarHeadShot&id={f.userId}&w=48&h=48`,
			Parent = r,
		}, { Theme.corner("round"), Theme.stroke(2) })
		Theme.text({
			Text = f.display or f.name or "?",
			Font = Theme.Display,
			Position = UDim2.fromOffset(62, 6),
			Size = UDim2.new(1, -200, 0, 24),
			Parent = r,
		})
		local text, color = statusText(f)
		Theme.text({
			Name = "Status",
			Text = text,
			Position = UDim2.fromOffset(62, 32),
			Size = UDim2.new(1, -200, 0, 20),
			TextSize = 13,
			TextColor3 = color,
			Parent = r,
		})
		local here = Players:GetPlayerByUserId(f.userId) ~= nil
		local s = friendStatus[f.userId]
		local b = Theme.button({
			Name = "Join",
			Text = here and "HERE" or (s and s.full) and "FULL" or "JOIN",
			BackgroundColor3 = here and C.muted or (s and s.full) and C.orange or C.good,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(120, 42),
			Parent = r,
		})
		b.Activated:Connect(function()
			if not here and Theme.busy(b, 2) then
				Bus.Tap:Fire("join_friend")
				Net.send("JoinFriend", f.userId, f.display or f.name)
			end
		end)
	end
end

-- Ask Roblox for friends online in this game, then the server for how their matches are going.
function PanelController.refreshFriends()
	task.spawn(function()
		local ok, list = pcall(function()
			return player:GetFriendsOnline(50)
		end)
		local out, ask = {}, {}
		if ok and type(list) == "table" then
			for _, f in list do
				local id = f.VisitorId or f.UserId
				if id and f.PlaceId == game.PlaceId then
					table.insert(
						out,
						{ userId = id, name = f.UserName, display = f.DisplayName or f.UserName, jobId = f.GameId }
					)
					table.insert(ask, { userId = id, jobId = f.GameId })
				end
			end
		end
		friendsList = out
		if #ask > 0 then
			Net.send("Friends", ask)
		end
		if current == "friends" then
			PanelController.refresh()
		end
	end)
end

-- MORE (settings, emotes, how to play) -------------------------------------------------------------------------------
local SETTINGS = {
	{ "fx", "✨ Effects", "Sparks, dust and flying rocks." },
	{ "shake", "📳 Screen shake", "When big hits land near you." },
	{ "music", "🎵 Music", "Happy while you build, drums in the fight." },
}
local HOW_TO = {
	"⛏️ Dig rocks and trees, then hammer the glowing blueprints to build the castle.",
	"☠️ When the plague comes, about 1 in 4 dwarves turn into monsters. Dwarves who fall turn too.",
	"⛩️ Stand near a shrine: if monsters outnumber dwarves there, it drains. Three shrines, one last stand.",
	"🛡️ Dwarves win if a shrine still stands when the clock runs out.",
	"👹 Monsters win by taking the last shrine or beating every dwarf.",
}

local function renderMore()
	titleLabel.Text = "⚙️ MORE"
	setTabs(nil)
	side.Visible = false
	local settings = Store.get("settings") or {}
	heading(body, "SETTINGS")
	for _, s in SETTINGS do
		local on = settings[s[1]] ~= false
		local r = row(body, 56, { Name = "Setting_" .. s[1], pad = false })
		Theme.text({
			Text = s[2],
			Font = Theme.Display,
			Size = UDim2.new(1, -150, 0, 26),
			Position = UDim2.fromOffset(12, 4),
			Parent = r,
		})
		Theme.text({
			Text = s[3],
			TextSize = 13,
			TextColor3 = C.muted,
			Size = UDim2.new(1, -150, 0, 18),
			Position = UDim2.fromOffset(12, 30),
			Parent = r,
		})
		local b = Theme.button({
			Name = "Toggle",
			Text = on and "ON" or "OFF",
			BackgroundColor3 = on and C.good or C.muted,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 40),
			Parent = r,
		})
		b.Activated:Connect(function()
			local value = not on
			-- feels instant; the server saves it and sends the profile back
			local copy = table.clone(Store.get("settings") or {})
			copy[s[1]] = value
			Store.state.settings = copy
			Store.Changed:Fire({ settings = copy })
			Net.send("Settings", s[1], value)
			PanelController.refresh()
		end)
	end
	-- emotes you own
	local p = profile()
	heading(body, "EMOTES", C.pink)
	local emotes = new("Frame", {
		Name = "Emotes",
		Size = UDim2.new(1, -8, 0, 48),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
		Parent = body,
	})
	listLayout(emotes, "x", 8)
	local owned = p and p.looks and p.looks.owned or {}
	for i, item in Looks.bySlot.emote or {} do
		local has = owned[item.key] or item.price == 0
		local b = Theme.button({
			Name = "Emote_" .. item.key,
			Text = `{ITEM_ICON[item.key] or "💃"} {item.name}`,
			BackgroundColor3 = has and C.pink or C.muted,
			Size = UDim2.fromOffset(140, 44),
			LayoutOrder = i,
			Parent = emotes,
		})
		b.Activated:Connect(function()
			if has then
				Bus.Tap:Fire("emote_" .. item.key)
				Net.send("Emote", item.key)
				PanelController.close()
			else
				tab.shop = "emote"
				PanelController.open("shop")
			end
		end)
	end
	heading(body, "HOW TO PLAY", C.sky)
	for _, line in HOW_TO do
		label(body, line, 15)
	end
	heading(body, "STAY SAFE", C.red)
	label(
		body,
		"Someone being mean or cheating? Open the Roblox menu (top left), pick Report, and choose them. Every fight is checked by the server, and cheaters are kicked.",
		14,
		{ color = C.muted }
	)
end

local RENDER =
	{ shop = renderShop, tasks = renderTasks, friends = renderFriends, settings = renderMore, jobs = renderJobs }
PanelController.RENDER = RENDER

function PanelController.refresh()
	if not current then
		return
	end
	local y = body.CanvasPosition
	clearBody()
	RENDER[current]()
	body.CanvasPosition = y
end

function PanelController.open(name)
	if not RENDER[name] then
		return
	end
	local same = current == name
	current = name
	panel.Visible = true
	if not same then
		Theme.pop(panel)
		body.CanvasPosition = Vector2.new(0, 0)
		Net.send("Viewed", name)
	end
	if name ~= "shop" then
		clearPreview()
	end
	if name == "friends" then
		PanelController.refreshFriends()
	end
	PanelController.refresh()
end

function PanelController.close()
	current = nil
	panel.Visible = false
	side.Visible = false
	clearPreview()
end

function PanelController.toggle(name)
	if current == name then
		PanelController.close()
	else
		PanelController.open(name)
	end
end

function PanelController.current()
	return current
end

-- Small cards: server full, waiting, rejoin, feedback, update alerts --------------------------------------------------
local function closeDialog()
	if dialog then
		dialog:Destroy()
		dialog = nil
	end
end
PanelController.closeDialog = closeDialog

local function card(name, title, text, buttons)
	closeDialog()
	dialog = Theme.card({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 30,
		Parent = gui,
	})
	Theme.padding(16).Parent = dialog
	listLayout(dialog, "y", 8)
	Theme.title({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = C.mustard,
		ZIndex = 31,
		LayoutOrder = 1,
		Parent = dialog,
	})
	Theme.text({
		Name = "Text",
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 16,
		ZIndex = 31,
		LayoutOrder = 2,
		Parent = dialog,
	})
	for i, b in buttons do
		local btn = Theme.button({
			Name = b.name or ("Button" .. i),
			Text = b.text,
			BackgroundColor3 = b.secondary and C.white or b.color or C.good,
			dark = b.secondary,
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 31,
			LayoutOrder = 2 + i,
			Parent = dialog,
		})
		btn.Activated:Connect(function()
			if b.keep ~= true then
				closeDialog()
			end
			b.fn()
		end)
	end
	Theme.pop(dialog)
	return dialog
end
PanelController.card = card

local function fullCard(r)
	card(
		"ServerFull",
		"SERVER FULL",
		`{r.name or "Your friend"}'s server has no free spots right now. What would you like to do?`,
		{
			{
				name = "Wait",
				text = "Wait for a spot",
				fn = function()
					Net.send("FriendAction", "retry")
				end,
			},
			{
				name = "Another",
				text = "Join another friend",
				secondary = true,
				fn = function()
					Net.send("FriendAction", "cancel")
					PanelController.open("friends")
				end,
			},
			{
				name = "Private",
				text = "Start a private match",
				secondary = true,
				fn = function()
					Net.send("FriendAction", "new")
				end,
			},
			{
				name = "Cancel",
				text = "Stay here",
				secondary = true,
				fn = function()
					Net.send("FriendAction", "cancel")
				end,
			},
		}
	)
end

local function onFriendResult(r)
	if type(r) ~= "table" then
		return
	end
	local name = r.name or "your friend"
	if r.kind == "teleporting" then
		closeDialog()
		hud().toast(r.new and "Starting a private match…" or `Joining {name}…`, "info")
	elseif r.kind == "full" then
		fullCard(r)
	elseif r.kind == "waiting" then
		card(
			"Waiting",
			"WAITING FOR A SPOT",
			`{name}'s server is still full. We'll try again in {r.wait or Constants.FRIEND_RETRY_SECONDS} s (try {(r.tries or 0) + 1} of {r.max or Constants.FRIEND_RETRY_TRIES}). This isn't a queue: if a spot opens, you'll get it if you're quick.`,
			{
				{
					name = "Cancel",
					text = "Stop waiting",
					secondary = true,
					fn = function()
						Net.send("FriendAction", "cancel")
					end,
				},
			}
		)
	elseif r.kind == "failed" then
		if r.stillFull then
			card("StillFull", "STILL FULL", r.text or "", {
				{
					name = "Another",
					text = "Join another friend",
					fn = function()
						PanelController.open("friends")
					end,
				},
				{
					name = "Private",
					text = "Start a private match",
					secondary = true,
					fn = function()
						Net.send("FriendAction", "new")
					end,
				},
				{ name = "Cancel", text = "Stay here", secondary = true, fn = function() end },
			})
		else
			closeDialog()
			hud().toast(r.text or "Couldn't join that match.", "bad")
		end
	elseif r.kind == "gone" then
		closeDialog()
		hud().toast(`{name} isn't in a match right now.`, "info")
	elseif r.kind == "here" then
		local team = r.team == "dwarf" and " (a dwarf)" or r.team == "monster" and " (a monster)" or ""
		hud().toast(`{name} is in this server{team}!`, "good")
	elseif r.kind == "rejoin" then
		local word = PHASE_WORD[r.phase] or "still going"
		card(
			"Rejoin",
			"YOUR MATCH IS STILL GOING",
			`It's {word} (shrine {r.shrine or 1}, {r.crew or "?"}/{r.max or Constants.MAX_PLAYERS} players). Go back?`,
			{
				{
					name = "Rejoin",
					text = "Rejoin my match",
					fn = function()
						Net.send("FriendAction", "rejoin")
					end,
				},
				{
					name = "Stay",
					text = "Stay here",
					secondary = true,
					fn = function()
						Net.send("FriendAction", "cancel")
					end,
				},
			}
		)
	end
end

-- "Do you like the game?"
local function feedbackCard()
	closeDialog()
	local like
	local reasons = {}
	local c = card("Feedback", "DO YOU LIKE THE GAME?", "Tell us honestly: it helps us make the castle better.", {})
	local thumbs = new("Frame", {
		Name = "Thumbs",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 31,
		Parent = c,
	})
	listLayout(thumbs, "x", 10, Enum.HorizontalAlignment.Center)
	local extra = new("Frame", {
		Name = "Extra",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 4,
		ZIndex = 31,
		Parent = c,
	})
	listLayout(extra, "y", 6)
	local reasonRow = new("Frame", {
		Name = "Reasons",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		LayoutOrder = 1,
		ZIndex = 31,
		Parent = extra,
	})
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(208, 36),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = reasonRow,
	})
	for i, r in Constants.DISLIKE_REASONS do
		local b = Theme.button({
			Name = "Reason_" .. r[1],
			Text = `{r[2]} {r[3]}`,
			BackgroundColor3 = C.white,
			dark = true,
			TextSize = 14,
			LayoutOrder = i,
			ZIndex = 31,
			Parent = reasonRow,
		})
		b.Activated:Connect(function()
			reasons[r[1]] = not reasons[r[1]] or nil
			b.BackgroundColor3 = reasons[r[1]] and C.mustard or C.white
			b.Text = `{r[2]} {r[3]}` .. (reasons[r[1]] and " ✔" or "")
		end)
	end
	local box = new("TextBox", {
		Name = "Text",
		PlaceholderText = "What should we add? (optional)",
		Text = "",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = C.white,
		TextColor3 = C.ink,
		PlaceholderColor3 = C.muted,
		Font = Theme.Body,
		TextSize = 15,
		TextWrapped = true,
		LayoutOrder = 2,
		ZIndex = 31,
		Parent = extra,
	}, { Theme.corner(10), Theme.stroke(2) })
	local send = Theme.button({
		Name = "Send",
		Text = "SEND",
		BackgroundColor3 = C.good,
		Size = UDim2.new(1, 0, 0, 44),
		LayoutOrder = 3,
		ZIndex = 31,
		Parent = extra,
	})
	for _, t in { { true, "👍 Yes!" }, { false, "👎 Not really" } } do
		local b = Theme.button({
			Name = t[1] and "Like" or "Dislike",
			Text = t[2],
			BackgroundColor3 = t[1] and C.good or C.white,
			dark = not t[1],
			Size = UDim2.fromOffset(190, 48),
			ZIndex = 31,
			Parent = thumbs,
		})
		b.Activated:Connect(function()
			like = t[1]
			extra.Visible = true
			reasonRow.Visible = not like
		end)
	end
	send.Activated:Connect(function()
		if like == nil then
			return
		end
		local list = {}
		for k in reasons do
			table.insert(list, k)
		end
		Net.send("Feedback", like, box.Text, list)
		closeDialog()
	end)
	local later = Theme.button({
		Name = "Later",
		Text = "Not now",
		BackgroundColor3 = C.white,
		dark = true,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 9,
		ZIndex = 31,
		Parent = c,
	})
	later.Activated:Connect(closeDialog)
end

local function onAsk(a)
	if type(a) ~= "table" then
		return
	end
	local Notify = require(script.Parent.NotifyController)
	if a.kind == "feedback" then
		feedbackCard()
	elseif a.kind == "thanks" then
		local offer = Notify.canAsk()
		local buttons = {}
		if offer then
			table.insert(buttons, {
				name = "Notify",
				text = "Tell me about updates",
				fn = function()
					Net.send("Notify", "shown")
					Notify.prompt()
				end,
			})
		end
		table.insert(buttons, { name = "Ok", text = "OK", secondary = offer, fn = function() end })
		card(
			"Thanks",
			"THANK YOU!",
			a.like and "Glad you're having fun holding the castle! 🏰"
				or "Thanks for telling us. We read every answer.",
			buttons
		)
	elseif a.kind == "notify" then
		if Notify.canAsk() then
			card(
				"Notify",
				"NEW MONSTERS ARE COMING",
				"Want a heads-up when we add new jobs, monsters and castle pieces?",
				{
					{
						name = "Yes",
						text = "Yes, tell me",
						fn = function()
							Net.send("Notify", "shown")
							Notify.prompt()
						end,
					},
					{ name = "No", text = "Not now", secondary = true, fn = function() end },
				}
			)
		end
	end
end

-- Job Boards only work for dwarves before the plague: hide their prompts otherwise.
local function updatePrompts()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local phase = Store.phase()
	local on = Store.team() == "dwarf" and phase ~= "plague" and phase ~= "fight" and phase ~= "laststand"
	for _, d in map:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "JobPrompt" then
			d.Enabled = on
		end
	end
end

function PanelController:init()
	buildFrame()
	Bus.Open:Connect(function(name)
		if RENDER[name] then
			PanelController.toggle(name)
		end
	end)
	Bus.Close:Connect(PanelController.close)
	Bus.BuildMode:Connect(function(on)
		if on then
			PanelController.close()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "JobPrompt" then
			if Store.team() == "monster" then
				Bus.Open:Fire("picker")
			else
				PanelController.open("jobs")
			end
		elseif prompt.Name == "ShopPrompt" then
			PanelController.open("shop")
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.me or partial.match then
			updatePrompts()
		end
		if not current then
			return
		end
		local wants = {
			shop = partial.profile,
			tasks = partial.profile,
			settings = partial.profile,
			jobs = partial.profile or partial.me or partial.match,
		}
		if wants[current] then
			PanelController.refresh()
		end
	end)
	Net.listen("Friends", function(list)
		for _, s in list or {} do
			friendStatus[s.userId] = s
		end
		if current == "friends" then
			PanelController.refresh()
		end
	end)
	Net.listen("FriendResult", onFriendResult)
	Net.listen("Ask", onAsk)
	RunService.RenderStepped:Connect(function(dt)
		if current == "shop" then
			stepPreview(dt)
		end
	end)
end

-- (tests)
PanelController.onFriendResult = onFriendResult
PanelController.onAsk = onAsk
function PanelController.body()
	return body
end
function PanelController.previewNpc()
	return preview and (preview.npc or preview.model)
end

return PanelController

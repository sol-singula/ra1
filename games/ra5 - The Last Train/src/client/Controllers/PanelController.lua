-- The panels (one open at a time, big touch targets, everything on one screen):
--   BUILD    your cabin: the colour swatches, the next upgrade (with a see-through preview of it in your cabin),
--            then every upgrade with what it does, what it costs against what you have, and why it can't be built
--            yet (needs / plans / materials). Built items with looks (the finish, the specialist path) change for
--            free. The workbench's salvage lives here too.
--   TRAIN    the crew's fuel and the two upgrades: what the next stage does and needs, and +1 / +5 / ALL buttons
--            to give from your own storage. Giving is a choice: nobody is ranked on it.
--   FRIENDS  your friends in this game and how their trains are doing; JOIN goes to that exact train. Train Full
--            offers Wait for a Spot, Join Another Friend or Start a New Expedition. Plus INVITE.
--   HALL     the Hall of Records: the best journeys with their crews, the eligibility rule, and your own.
-- And the small cards: Train Full / waiting for a spot / rejoin your train, and "Do you like the game?".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local CabinBuilder = require(ReplicatedStorage.Shared.World.CabinBuilder)
local CabinItems = require(ReplicatedStorage.Shared.Data.CabinItems)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Resources = require(ReplicatedStorage.Shared.Data.Resources)
local Stops = require(ReplicatedStorage.Shared.Data.Stops)
local TrainUpgrades = require(ReplicatedStorage.Shared.Data.TrainUpgrades)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local PanelController = { Name = "PanelController", Order = 30 }

local gui, panel, titleLabel, body
local current -- the open panel's name
local opts = {} -- the open panel's options (focus rank, selected variants...)
local ghostFolder
local friendsList = {} -- { { userId, name, display, jobId } } from GetFriendsOnline
local friendStatus = {} -- [userId] = status from the server
local dialog

local KIND_TEXT = { functional = "FUNCTIONAL", cosmetic = "COSMETIC", storage = "STORAGE", display = "DISPLAY" }
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function dateText(t)
	if type(t) ~= "number" then
		return ""
	end
	local d = os.date("!*t", t)
	return `{d.day} {MONTHS[d.month]} {d.year}`
end

local function hud()
	return require(script.Parent.HudController)
end

-- Little helpers for rows --------------------------------------------------------------------------------------
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function row(parent, height, props)
	props = props or {}
	local f = Theme.slab({
		Name = props.Name or "Row",
		Size = UDim2.new(1, -6, 0, height or 0),
		AutomaticSize = height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
		BackgroundColor3 = props.color or C.panel2,
		BackgroundTransparency = props.transparency or 0.25,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	f.UIStroke.Transparency = props.edge or 0.65
	Theme.padding(10, 8).Parent = f
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
		TextSize = size or 14,
		TextColor3 = props.color or C.cream,
		Font = props.font,
		RichText = props.rich,
		TextXAlignment = props.align or Enum.TextXAlignment.Left,
		LayoutOrder = props.order or nextOrder(),
		Parent = parent,
	})
end

local function heading(parent, text, props)
	props = props or {}
	return Theme.title({
		Name = props.Name or "Heading",
		Text = text,
		Size = UDim2.new(1, 0, 0, props.height or 20),
		TextColor3 = props.color or C.amber,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
end

-- "🔩 3/4" chips: have/need for each cost entry (✔ when you have enough, so it's not colour alone).
local function costChips(cost, storage, plans, blueprints)
	local parts = {}
	for _, key in Resources.MATERIALS do
		local need = cost[key]
		if need then
			local have = storage[key] or 0
			local ok = have >= need
			table.insert(
				parts,
				`<font color="{ok and "#76D680" or "#F2604C"}">{Resources.byKey[key].icon} {math.min(have, need)}/{need}{ok and " ✔" or ""}</font>`
			)
		end
	end
	if plans then
		local bp = Resources.BLUEPRINTS[plans]
		local ok = (blueprints[plans] or 0) > 0
		table.insert(
			parts,
			`<font color="{ok and "#76D680" or "#78ACFF"}">{bp.icon} {bp.name}{ok and " ✔" or " (find at a stop)"}</font>`
		)
	end
	return table.concat(parts, "   ")
end

-- Where the materials are: the stops rich in this one (so "not enough" says where to look).
local function whereToFind(cost, storage)
	for _, key in Resources.MATERIALS do
		local need = cost[key]
		if need and (storage[key] or 0) < need then
			local places = {}
			for _, s in Stops.list do
				if table.find(s.rich, key) then
					table.insert(places, s.name)
				end
			end
			return `{Resources.byKey[key].icon} {Resources.byKey[key].name}: lots at {table.concat(places, ", ")}`
		end
	end
	return nil
end

-- The ghost preview of an item in your own cabin.
local function clearGhost()
	if ghostFolder then
		ghostFolder:ClearAllChildren()
	end
end

local function showGhost(key, variant)
	clearGhost()
	local index = Store.state.cabinIndex or player:GetAttribute("Cabin")
	local cabin = index and Layout.cabins[index]
	if not cabin or not key then
		return
	end
	if not ghostFolder then
		ghostFolder = new("Folder", { Name = "CabinGhost", Parent = workspace })
	end
	local built = Store.state.cabin and Store.state.cabin.built or {}
	if built[key] then
		return
	end
	pcall(CabinBuilder.item, ghostFolder, cabin.cf, key, { ghost = true, variant = variant })
end
PanelController.showGhost = showGhost

-- The panel frame ------------------------------------------------------------------------------------------------
local function buildFrame()
	gui = Theme.screen("Panels", 20, player:WaitForChild("PlayerGui"))
	panel = Theme.slab({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Size = UDim2.fromOffset(660, 420),
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.06,
		Visible = false,
		Parent = gui,
	})
	titleLabel = Theme.title({
		Name = "Title",
		Text = "",
		Size = UDim2.new(1, -80, 0, 30),
		Position = UDim2.fromOffset(16, 10),
		TextColor3 = C.amber,
		Parent = panel,
	})
	local close = Theme.button({
		Name = "Close",
		Text = "✕",
		secondary = true,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(44, 36),
		Parent = panel,
	})
	close.Activated:Connect(function()
		PanelController.close()
	end)
	body = new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.edge,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel,
	})
	Theme.list("y", 8).Parent = body
end

local function clearBody()
	for _, c in body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	order = 0
end

-- BUILD ------------------------------------------------------------------------------------------------------------
local function buildItemRow(item, built, storage, blueprints, featured)
	local isBuilt = built[item.key] == true
	local ok, why = Formulas.canBuild(item, built, storage, blueprints)
	local r = row(
		body,
		nil,
		{ Name = "Item_" .. item.key, color = featured and C.panel or C.panel2, edge = featured and 0.1 or 0.65 }
	)
	r:SetAttribute("Item", item.key)
	Theme.list("y", 4).Parent = r
	local head = new(
		"Frame",
		{ Name = "Head", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1, Parent = r }
	)
	Theme.title({
		Text = `{item.step}. {item.name}`,
		Size = UDim2.new(1, -120, 1, 0),
		TextColor3 = isBuilt and C.good or C.cream,
		Parent = head,
	})
	Theme.text({
		Text = (isBuilt and "BUILT ✔  · " or "") .. KIND_TEXT[item.kind],
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 160, 1, 0),
		TextSize = 11,
		TextColor3 = isBuilt and C.good or C.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Bold,
		Parent = head,
	})
	label(r, item.benefit, 13, { color = C.muted, order = 2 })
	if item.variants then
		local currentLook = Store.state.cabin and Store.state.cabin.variants and Store.state.cabin.variants[item.key]
		local chosen = opts.variants and opts.variants[item.key] or currentLook or item.variants[1].key
		local vrow = new("Frame", {
			Name = "Variants",
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = r,
		})
		Theme.list("x", 6).Parent = vrow
		for i, v in item.variants do
			local selected = (isBuilt and currentLook == v.key) or (not isBuilt and chosen == v.key)
			local b = Theme.button({
				Name = "Variant_" .. v.key,
				Text = v.name .. (selected and " ✔" or ""),
				secondary = not selected,
				Size = UDim2.fromOffset(math.max(96, #v.name * 9 + 30), 30),
				LayoutOrder = i,
				Parent = vrow,
			})
			b.Activated:Connect(function()
				if isBuilt then
					Net.send("Build", item.key, v.key) -- changing the look is free
				else
					opts.variants = opts.variants or {}
					opts.variants[item.key] = v.key
					showGhost(item.key, v.key)
					PanelController.refresh()
				end
			end)
		end
		if item.key == "specialist" then
			for _, v in item.variants do
				if v.key == chosen then
					label(r, `{v.name}: {v.text}`, 12, { color = C.blue, order = 4 })
				end
			end
		end
	end
	if not isBuilt then
		label(r, costChips(item.cost, storage, item.plans, blueprints), 14, { rich = true, order = 5 })
		local foot = new(
			"Frame",
			{ Name = "Foot", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = 6, Parent = r }
		)
		local text, enabled
		if ok then
			text, enabled = "Build", true
		elseif why == "needs" then
			text = `Build {CabinItems.byKey[item.needs].short} first`
		elseif why == "plans" then
			text = "Needs plans"
		else
			text = "Not enough materials"
		end
		local b = Theme.button({
			Name = "Build",
			Text = text,
			secondary = not enabled,
			Size = UDim2.fromOffset(enabled and 160 or 230, 36),
			Parent = foot,
		})
		b.Active = enabled == true
		if enabled then
			b.Activated:Connect(function()
				if Theme.busy(b, 1) then
					Net.send("Build", item.key, opts.variants and opts.variants[item.key] or nil)
				end
			end)
		end
		local preview = Theme.button({
			Name = "Preview",
			Text = "👁 Preview",
			secondary = true,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(120, 36),
			Parent = foot,
		})
		preview.Activated:Connect(function()
			showGhost(item.key, opts.variants and opts.variants[item.key] or nil)
			hud().toast(`Preview: the blue outline in your cabin shows the {item.short}.`, "info")
		end)
		if not ok and why == "materials" then
			local hint = whereToFind(item.cost, storage)
			if hint then
				label(r, hint, 12, { color = C.muted, order = 7 })
			end
		end
	end
	return r
end

local function renderBuild()
	local cabin = Store.state.cabin or { built = {}, variants = {} }
	local built = cabin.built or {}
	local storage = Store.state.storage or {}
	local blueprints = Store.state.blueprints or {}
	local index = Store.state.cabinIndex or player:GetAttribute("Cabin") or "?"
	titleLabel.Text =
		string.upper(`My cabin · No. {index} · {Formulas.cabinCount(built)}/{#CabinItems.list} upgrades`)
	-- what you have
	local have = {}
	for _, key in Resources.MATERIALS do
		table.insert(have, `{Resources.byKey[key].icon} {storage[key] or 0}`)
	end
	for key, n in blueprints do
		if n > 0 then
			table.insert(have, `{Resources.BLUEPRINTS[key].icon} ×{n}`)
		end
	end
	label(body, "You have:  " .. table.concat(have, "   "), 15)
	-- the colour (free)
	local colors = row(body, nil, { Name = "Colors" })
	Theme.list("y", 6).Parent = colors
	Theme.title({
		Text = "Cabin colour (free)",
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = C.amber,
		LayoutOrder = 1,
		Parent = colors,
	})
	local swatches = new("Frame", {
		Name = "Swatches",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = colors,
	})
	Theme.list("x", 8).Parent = swatches
	for i, c in CabinItems.COLORS do
		local selected = cabin.color == c.key
		local b = Theme.button({
			Name = "Color_" .. c.key,
			Text = c.name .. (selected and " ✔" or ""),
			BackgroundColor3 = c.color,
			TextColor3 = C.white,
			Size = UDim2.fromOffset(92, 46),
			LayoutOrder = i,
			Parent = swatches,
		})
		Theme.textStroke(1.5, 0.3).Parent = b
		if selected then
			b.UIStroke.Color = C.white
			b.UIStroke.Thickness = 3
			b.UIStroke.Transparency = 0
		end
		b.Activated:Connect(function()
			Net.send("SetColor", c.key)
		end)
	end
	-- the next upgrade first
	local nextItem = Formulas.nextCabinItem(built)
	if nextItem then
		heading(body, "Next upgrade")
		buildItemRow(nextItem, built, storage, blueprints, true)
		if current == "build" and not opts.ghostShown then
			opts.ghostShown = true
			showGhost(nextItem.key, opts.variants and opts.variants[nextItem.key] or nil)
		end
	else
		heading(body, "Every upgrade built! Your cabin is complete. ✔", { color = C.good })
	end
	-- the workbench's salvage
	if built.workbench then
		local s = row(body, nil, { Name = "Salvage" })
		Theme.list("x", 10).Parent = s
		Theme.text({
			Text = `Workbench salvage: {Constants.SALVAGE_SCRAP} 🔩 → 1 ⚙️`,
			Size = UDim2.new(1, -150, 0, 36),
			TextSize = 14,
			LayoutOrder = 1,
			Parent = s,
		})
		local b = Theme.button({
			Name = "SalvageButton",
			Text = "Salvage",
			Size = UDim2.fromOffset(130, 36),
			LayoutOrder = 2,
			Parent = s,
		})
		b.Activated:Connect(function()
			Net.send("Salvage")
		end)
	end
	heading(body, "All upgrades")
	for _, item in CabinItems.list do
		if item ~= nextItem then
			buildItemRow(item, built, storage, blueprints, false)
		end
	end
end

-- TRAIN ------------------------------------------------------------------------------------------------------------
local function giveButton(parent, text, key, resource, amount, enabled, i)
	local b = Theme.button({
		Name = "Give_" .. resource .. "_" .. tostring(amount),
		Text = text,
		secondary = not enabled,
		Size = UDim2.fromOffset(64, 32),
		LayoutOrder = i,
		Parent = parent,
	})
	b.Active = enabled
	if enabled then
		b.Activated:Connect(function()
			Net.send("Deposit", key, resource, amount)
		end)
	end
	return b
end

local function renderTrain()
	local tv = Store.state.train or {}
	local e = Store.state.expedition or {}
	local storage = Store.state.storage or {}
	local blueprints = Store.state.blueprints or {}
	titleLabel.Text = "THE TRAIN · CREW UPGRADES"
	local fuel = row(body, nil, { Name = "Fuel" })
	Theme.list("y", 3).Parent = fuel
	local low = (tv.fuel or e.fuel or 0) + 1e-6 < (tv.cost or e.cost or 0)
	Theme.title({
		Text = `⛽ Fuel {tv.fuel or e.fuel or 0} · next trip needs {tv.cost or e.cost or "?"}`
			.. (low and " · LOW!" or ""),
		Size = UDim2.new(1, 0, 0, 20),
		TextColor3 = low and C.fuel or C.amber,
		LayoutOrder = 1,
		Parent = fuel,
	})
	label(
		fuel,
		"Fuel belongs to the whole crew: bring fuel cans back from the stops. If there isn't enough to leave a stop, the journey ends there.",
		12,
		{ color = C.muted, order = 2 }
	)
	label(
		body,
		"Your materials are yours: build your cabin with them, or give some here so the whole crew goes farther. Upgrades last for this journey.",
		13,
		{ color = C.cream }
	)
	local views = {}
	for _, u in tv.upgrades or {} do
		views[u.key] = u
	end
	for _, def in TrainUpgrades.list do
		local u = views[def.key] or { stage = 0, total = #def.stages, given = {} }
		local stageN = u.stage or 0
		local nextStage = def.stages[stageN + 1]
		local r = row(body, nil, { Name = "Upgrade_" .. def.key, color = C.panel, edge = 0.3 })
		Theme.list("y", 5).Parent = r
		Theme.title({
			Text = `{def.icon} {def.name} · {stageN}/{#def.stages}` .. (nextStage and "" or " · complete ✔"),
			Size = UDim2.new(1, 0, 0, 22),
			TextColor3 = nextStage and C.cream or C.good,
			LayoutOrder = 1,
			Parent = r,
		})
		label(r, def.text, 12, { color = C.muted, order = 2 })
		if nextStage then
			label(r, `Next: {nextStage.name}. {nextStage.effect}`, 13, { color = C.amber, order = 3 })
			local given = u.given or {}
			local i = 3
			for _, res in Resources.MATERIALS do
				local need = nextStage.cost[res]
				if need then
					i += 1
					local have = storage[res] or 0
					local gave = given[res] or 0
					local left = math.max(0, need - gave)
					local line = new("Frame", {
						Name = "Res_" .. res,
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundTransparency = 1,
						LayoutOrder = i,
						Parent = r,
					})
					Theme.text({
						Text = `{Resources.byKey[res].icon} {Resources.byKey[res].name}  {gave}/{need}{left == 0 and " ✔" or ""}   ·   you have {have}`,
						Size = UDim2.new(1, -220, 1, 0),
						TextSize = 14,
						TextColor3 = left == 0 and C.good or C.cream,
						Parent = line,
					})
					local btns = new("Frame", {
						Name = "Buttons",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(212, 34),
						BackgroundTransparency = 1,
						Parent = line,
					})
					Theme.list("x", 6).Parent = btns
					local can = left > 0 and have > 0
					giveButton(btns, "+1", def.key, res, 1, can, 1)
					giveButton(btns, "+5", def.key, res, 5, can and have >= 2, 2)
					giveButton(btns, "All", def.key, res, math.min(have, left), can, 3)
				end
			end
			if nextStage.plans then
				local bp = Resources.BLUEPRINTS[nextStage.plans]
				local done = given.plans == true
				local have = blueprints[nextStage.plans] or 0
				local line = new("Frame", {
					Name = "Plans",
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundTransparency = 1,
					LayoutOrder = 20,
					Parent = r,
				})
				Theme.text({
					Text = `{bp.icon} {bp.name}  {done and "1/1 ✔" or "0/1"}   ·   you have {have}`,
					Size = UDim2.new(1, -100, 1, 0),
					TextSize = 14,
					TextColor3 = done and C.good or C.blue,
					Parent = line,
				})
				local b = Theme.button({
					Name = "GivePlans",
					Text = "Give",
					secondary = done or have == 0,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(90, 32),
					Parent = line,
				})
				b.Active = not done and have > 0
				if not done and have > 0 then
					b.Activated:Connect(function()
						Net.send("Deposit", def.key, "plans", 1)
					end)
				end
			end
		end
	end
end

-- FRIENDS ------------------------------------------------------------------------------------------------------
local PHASE_WORD = {
	lobby = "at the station",
	departing = "leaving a stop",
	traveling = "on the line",
	arriving = "arriving at a stop",
	scavenging = "at a stop",
	warning = "about to leave a stop",
	ended = "heading home",
}

local function statusText(f)
	local s = friendStatus[f.userId]
	if Players:GetPlayerByUserId(f.userId) then
		return "On this train", C.good
	end
	if not s then
		return "Checking their train…", C.muted
	end
	if s.unknown then
		return "In The Last Train", C.cream
	end
	if s.full then
		return `Train full ({s.crew}/{s.max}) · {s.km} km`, C.warn
	end
	return `{string.upper(string.sub(PHASE_WORD[s.phase] or "on a train", 1, 1))}{string.sub(
		PHASE_WORD[s.phase] or "on a train",
		2
	)} · {s.km} km · {s.crew}/{s.max} aboard`,
		C.cream
end

local function renderFriends()
	titleLabel.Text = "FRIENDS · JOIN THEIR TRAIN"
	local top = row(body, nil, { Name = "Invite" })
	Theme.list("x", 10).Parent = top
	Theme.text({
		Text = "Trains are better with friends. Invite them, or join a friend's train below: you go to their exact train.",
		Size = UDim2.new(1, -170, 0, 40),
		TextSize = 13,
		LayoutOrder = 1,
		Parent = top,
	})
	local invite = Theme.button({
		Name = "InviteButton",
		Text = "Invite friends",
		Size = UDim2.fromOffset(150, 40),
		LayoutOrder = 2,
		Parent = top,
	})
	invite.Activated:Connect(function()
		pcall(SocialService.PromptGameInvite, SocialService, player)
	end)
	if #friendsList == 0 then
		label(body, "None of your friends are on The Last Train right now. Invite them!", 14, { color = C.muted })
		return
	end
	for _, f in friendsList do
		local r = row(body, 54, { Name = "Friend_" .. f.userId })
		new("ImageLabel", {
			Name = "Avatar",
			Size = UDim2.fromOffset(38, 38),
			BackgroundColor3 = C.ink,
			Image = `rbxthumb://type=AvatarHeadShot&id={f.userId}&w=48&h=48`,
			Parent = r,
		}, { Theme.corner("round") })
		Theme.title({
			Text = f.display or f.name or "?",
			Position = UDim2.fromOffset(48, 0),
			Size = UDim2.new(1, -170, 0, 20),
			Parent = r,
		})
		local text, color = statusText(f)
		Theme.text({
			Name = "Status",
			Text = text,
			Position = UDim2.fromOffset(48, 20),
			Size = UDim2.new(1, -170, 0, 18),
			TextSize = 12,
			TextColor3 = color,
			Parent = r,
		})
		local here = Players:GetPlayerByUserId(f.userId) ~= nil
		local s = friendStatus[f.userId]
		local b = Theme.button({
			Name = "Join",
			Text = here and "Here" or (s and s.full) and "Full" or "Join",
			secondary = here,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(100, 36),
			Parent = r,
		})
		b.Activated:Connect(function()
			if not here and Theme.busy(b, 2) then
				Net.send("JoinFriend", f.userId, f.display or f.name)
			end
		end)
	end
end

-- Ask Roblox for friends online in this game, then the server for how their trains are doing.
function PanelController.refreshFriends()
	task.spawn(function()
		local ok, list = pcall(function()
			return player:GetFriendsOnline(50)
		end)
		local out, ask = {}, {}
		if ok and type(list) == "table" then
			for _, f in list do
				local id = f.VisitorId or f.UserId
				if id and (f.PlaceId == game.PlaceId or f.LocationType == 4 and f.PlaceId == game.PlaceId) then
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

-- HALL ------------------------------------------------------------------------------------------------------------
local RECOGNITION = {
	{ "fuel", "⛽ most fuel brought back" },
	{ "materials", "⚙️ most given to the train" },
	{ "blueprints", "📜 blueprints found" },
	{ "recovered", "🧭 found the way back" },
}

local function trainText(t)
	t = t or {}
	local parts = {}
	if (t.engine or 0) > 0 then
		table.insert(parts, `🔥 Overhaul {({ "I", "II", "III" })[t.engine] or t.engine}`)
	end
	if (t.lamp or 0) >= 2 then
		table.insert(parts, "🔦 Radio Mast")
	elseif (t.lamp or 0) == 1 then
		table.insert(parts, "🔦 Searchlight")
	end
	return #parts > 0 and table.concat(parts, " · ") or "a plain train"
end

local function renderHall()
	local hall = Store.state.hall or { records = {} }
	titleLabel.Text = "HALL OF RECORDS"
	label(body, (hall.rule or "") .. " The record belongs to the whole crew.", 12, { color = C.muted })
	if #hall.records == 0 then
		label(body, "No records yet. Be the first crew on the wall!", 15)
	end
	for _, rec in hall.records do
		local focused = opts.rank == rec.rank
		local r = row(
			body,
			nil,
			{ Name = "Record_" .. rec.rank, color = focused and C.panel or C.panel2, edge = focused and 0 or 0.6 }
		)
		Theme.list("y", 3).Parent = r
		Theme.title({
			Text = `{rec.rank == 1 and "🏆" or "#" .. rec.rank}  {string.format("%.1f", rec.km or 0)} km`
				.. (rec.live and " · still on the line" or ""),
			Size = UDim2.new(1, 0, 0, 24),
			TextColor3 = rec.rank == 1 and C.amber or C.cream,
			LayoutOrder = 1,
			Parent = r,
		})
		local mins = math.floor((rec.seconds or 0) / 60)
		label(
			r,
			`Expedition #{rec.code} · {dateText(rec.at)} · {rec.stops or 0} stops · {mins >= 60 and (math.floor(
				mins / 60
			) .. "h " .. (mins % 60) .. "m") or (mins .. " min")} · {trainText(rec.train)}`,
			12,
			{ color = C.muted, order = 2 }
		)
		local names = {}
		for _, m in rec.crew or {} do
			table.insert(names, m.name)
		end
		if (rec.crewCount or 0) > #names then
			table.insert(names, `+{rec.crewCount - #names} more`)
		end
		label(
			r,
			`Crew: {table.concat(names, ", ")}` .. ((rec.helpers or 0) > 0 and ` · and {rec.helpers} helpers` or ""),
			13,
			{ order = 3 }
		)
		local recog = {}
		for _, k in RECOGNITION do
			local v = rec.recognition and rec.recognition[k[1]]
			if v then
				table.insert(recog, `{k[2]}: {v.name} ({v.amount})`)
			end
		end
		if #recog > 0 then
			label(r, table.concat(recog, "   ·   "), 12, { color = C.amber, order = 4 })
		end
		if focused and rec.route then
			local route = {}
			for _, key in rec.route do
				local s = Stops.byKey[key]
				table.insert(route, s and s.name or key)
			end
			label(r, "Route: " .. table.concat(route, " → "), 12, { color = C.muted, order = 5 })
		end
	end
	heading(body, "Your journeys")
	label(body, `Best distance: {Store.state.best or 0} km`, 14)
	for _, j in Store.state.records or {} do
		if type(j) == "table" then
			label(body, `#{j.code} · {j.km} km · {j.stops} stops · {dateText(j.at)}`, 13, { color = C.muted })
		end
	end
end

-- Open / close -------------------------------------------------------------------------------------------------
local RENDER = { build = renderBuild, train = renderTrain, friends = renderFriends, hall = renderHall }

function PanelController.refresh()
	if not current then
		return
	end
	local y = body.CanvasPosition
	clearBody()
	RENDER[current]()
	body.CanvasPosition = y
end

function PanelController.open(name, o)
	if not RENDER[name] then
		return
	end
	local same = current == name
	current = name
	opts = same and opts or {}
	for k, v in o or {} do
		opts[k] = v
	end
	panel.Visible = true
	if not same then
		Theme.pop(panel)
		body.CanvasPosition = Vector2.new(0, 0)
		Net.send("Viewed", name)
	end
	if name ~= "build" then
		clearGhost()
	end
	if name == "friends" then
		PanelController.refreshFriends()
	end
	PanelController.refresh()
	-- scroll to a focused record
	if name == "hall" and opts.rank then
		task.defer(function()
			local r = body:FindFirstChild("Record_" .. opts.rank)
			if r and r.AbsolutePosition and body.AbsolutePosition then
				body.CanvasPosition = Vector2.new(
					0,
					math.max(0, r.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y - 10)
				)
			end
		end)
	end
end

function PanelController.close()
	current = nil
	opts = {}
	panel.Visible = false
	clearGhost()
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

-- Small cards: Train Full, waiting, rejoin, feedback --------------------------------------------------------------
local function closeDialog()
	if dialog then
		dialog:Destroy()
		dialog = nil
	end
end
PanelController.closeDialog = closeDialog

local function card(name, title, text, buttons)
	closeDialog()
	dialog = Theme.slab({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.ink,
		BackgroundTransparency = 0.04,
		ZIndex = 30,
		Parent = gui,
	})
	Theme.padding(16, 14).Parent = dialog
	Theme.list("y", 8).Parent = dialog
	Theme.title({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, 0, 0, 28),
		TextColor3 = C.amber,
		ZIndex = 31,
		LayoutOrder = 1,
		Parent = dialog,
	})
	Theme.text({
		Name = "Text",
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		ZIndex = 31,
		LayoutOrder = 2,
		Parent = dialog,
	})
	for i, b in buttons do
		local btn = Theme.button({
			Name = b.name or ("Button" .. i),
			Text = b.text,
			secondary = b.secondary,
			Size = UDim2.new(1, 0, 0, 40),
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
		"TrainFull",
		"Train full",
		`{r.name or "Your friend"}'s train has no free seats right now. What would you like to do?`,
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
				name = "New",
				text = "Start a new expedition",
				secondary = true,
				fn = function()
					Net.send("FriendAction", "new")
				end,
			},
			{
				name = "Cancel",
				text = "Stay on this train",
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
		hud().toast(r.new and "Starting a new expedition…" or `Joining {name}'s train…`, "info")
	elseif r.kind == "full" then
		fullCard(r)
	elseif r.kind == "waiting" then
		card(
			"Waiting",
			"Waiting for a spot",
			`{name}'s train is still full. We'll try again in {r.wait or Constants.FRIEND_RETRY_SECONDS} s (try {(r.tries or 0) + 1} of {r.max or Constants.FRIEND_RETRY_TRIES}). This isn't a queue: if a seat opens, you'll get it if you're quick.`,
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
			card("StillFull", "Still full", r.text or "", {
				{
					name = "Another",
					text = "Join another friend",
					fn = function()
						PanelController.open("friends")
					end,
				},
				{
					name = "New",
					text = "Start a new expedition",
					secondary = true,
					fn = function()
						Net.send("FriendAction", "new")
					end,
				},
				{ name = "Cancel", text = "Stay here", secondary = true, fn = function() end },
			})
		else
			closeDialog()
			hud().toast(r.text or "Couldn't join that train.", "bad")
		end
	elseif r.kind == "gone" then
		closeDialog()
		hud().toast(`{name} isn't on a train right now.`, "info")
	elseif r.kind == "here" then
		hud().toast(`{name} is on this train!` .. (r.cabin and ` Cabin {r.cabin}.` or ""), "good")
	elseif r.kind == "rejoin" then
		card(
			"Rejoin",
			"Your train is still going",
			`Expedition #{r.code or "?"} is on the line ({r.km or 0} km, {r.crew or "?"}/{r.max or Constants.MAX_PLAYERS} aboard). Go back to it?`,
			{
				{
					name = "Rejoin",
					text = "Rejoin my train",
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
	local c = card("Feedback", "Do you like the game?", "Tell us honestly: it helps us make the train better.", {})
	local row1 = new("Frame", {
		Name = "Thumbs",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		ZIndex = 31,
		Parent = c,
	})
	Theme.list("x", 10, Enum.HorizontalAlignment.Center).Parent = row1
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
	Theme.list("y", 6).Parent = extra
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
		CellSize = UDim2.fromOffset(200, 34),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = reasonRow,
	})
	for i, r in Constants.DISLIKE_REASONS do
		local b = Theme.button({
			Name = "Reason_" .. r[1],
			Text = `{r[2]} {r[3]}`,
			secondary = true,
			TextSize = 13,
			LayoutOrder = i,
			ZIndex = 31,
			Parent = reasonRow,
		})
		b.Activated:Connect(function()
			reasons[r[1]] = not reasons[r[1]] or nil
			b.Text = string.upper(`{r[2]} {r[3]}`) .. (reasons[r[1]] and " ✔" or "")
		end)
	end
	local box = new("TextBox", {
		Name = "Text",
		PlaceholderText = "What should we add? (optional)",
		Text = "",
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.panel2,
		TextColor3 = C.cream,
		PlaceholderColor3 = C.muted,
		Font = Theme.Body,
		TextSize = 14,
		TextWrapped = true,
		LayoutOrder = 2,
		ZIndex = 31,
		Parent = extra,
	}, { Theme.corner(8) })
	local send = Theme.button({
		Name = "Send",
		Text = "Send",
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 3,
		ZIndex = 31,
		Parent = extra,
	})
	for _, t in { { true, "👍 Yes!" }, { false, "👎 Not really" } } do
		local b = Theme.button({
			Name = t[1] and "Like" or "Dislike",
			Text = t[2],
			secondary = not t[1],
			Size = UDim2.fromOffset(180, 46),
			ZIndex = 31,
			Parent = row1,
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
		secondary = true,
		Size = UDim2.new(1, 0, 0, 34),
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
		card(
			"Thanks",
			"Thank you!",
			a.like and "Glad you're enjoying the journey. 🚂" or "Thanks for telling us. We read every answer.",
			{
				offer and {
					name = "Notify",
					text = "Tell me about updates",
					fn = function()
						Net.send("Notify", "shown")
						Notify.prompt()
					end,
				} or nil,
				{ name = "Ok", text = "OK", secondary = offer, fn = function() end },
			}
		)
	elseif a.kind == "notify" then
		if Notify.canAsk() then
			card("Notify", "New stops are coming", "Want a heads-up when we add new regions and upgrades?", {
				{
					name = "Yes",
					text = "Yes, tell me",
					fn = function()
						Net.send("Notify", "shown")
						Notify.prompt()
					end,
				},
				{ name = "No", text = "Not now", secondary = true, fn = function() end },
			})
		end
	end
end

function PanelController:init()
	buildFrame()
	Store.Changed:Connect(function(partial)
		if not current then
			return
		end
		local wants = {
			build = partial.cabin or partial.storage or partial.blueprints or partial.cabinIndex,
			train = partial.train or partial.storage or partial.blueprints or partial.expedition,
			hall = partial.hall or partial.best or partial.records,
		}
		if wants[current] then
			if current == "build" and partial.cabin then
				opts.ghostShown = nil -- the next upgrade changed: show its preview
			end
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
	-- keyboard shortcuts
	pcall(function()
		local ContextActionService = game:GetService("ContextActionService")
		ContextActionService:BindAction("LT_Build", function(_, state)
			if state == Enum.UserInputState.Begin then
				PanelController.toggle("build")
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.B)
		ContextActionService:BindAction("LT_Train", function(_, state)
			if state == Enum.UserInputState.Begin then
				PanelController.toggle("train")
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.T)
		ContextActionService:BindAction("LT_Cabin", function(_, state)
			if state == Enum.UserInputState.Begin then
				Net.send("GoCabin")
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.C)
	end)
	_ = Layout
end

return PanelController
